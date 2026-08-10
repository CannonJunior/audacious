extends Node
## Manages the upgrade board: opportunity discovery, state transitions,
## window expiry, chain progression, and villain race resolution.

const SAVE_PATH: String = "user://upgrade_board.cfg"

const _UpgradeBoard       = preload("res://heist_planner/resources/UpgradeBoard.gd")
const _UpgradeOpportunity = preload("res://heist_planner/resources/UpgradeOpportunity.gd")
const _UpgradeChain       = preload("res://heist_planner/resources/UpgradeChain.gd")

var board = null  ## UpgradeBoard

func _ready() -> void:
	board = _UpgradeBoard.new()
	load_state()
	EventBus.mission_completed.connect(_on_mission_completed)

func _process(_delta: float) -> void:
	_check_expiry()

# ── Opportunity management ────────────────────────────────────────────────────

## Add a newly discovered opportunity to the board. No-ops if already known.
func discover_opportunity(opp) -> void:  ## opp: UpgradeOpportunity
	if board.get_opportunity(opp.upgrade_id):
		return
	if opp.state == _UpgradeOpportunity.State.UNDISCOVERED:
		opp.state = _UpgradeOpportunity.State.OPPORTUNITY
	board.opportunities.append(opp)
	board.known_opportunity_count += 1
	EventBus.upgrade_opportunity_discovered.emit(opp.upgrade_id)

func set_opportunity_state(upgrade_id: StringName, new_state: int) -> void:  ## new_state: UpgradeOpportunity.State
	var opp = board.get_opportunity(upgrade_id)
	if not opp or opp.state == new_state:
		return
	opp.state = new_state
	EventBus.upgrade_opportunity_state_changed.emit(upgrade_id, new_state as int)

## Mark a step complete. Advances the chain to the next step.
func complete_step(upgrade_id: StringName) -> void:
	var opp = board.get_opportunity(upgrade_id)
	if not opp:
		return
	set_opportunity_state(upgrade_id, _UpgradeOpportunity.State.COMPLETE)
	if opp.chain_id != &"":
		_advance_chain(opp.chain_id, opp.chain_step)

## The villain reached a contested target first — mark lost.
func villain_takes_target(upgrade_id: StringName) -> void:
	set_opportunity_state(upgrade_id, _UpgradeOpportunity.State.LOST)

func register_chain(chain) -> void:  ## chain: UpgradeChain
	if board.get_chain(chain.chain_id):
		return
	board.chains.append(chain)
	for step in chain.steps:  ## step: UpgradeOpportunity
		if not board.get_opportunity(step.upgrade_id):
			board.opportunities.append(step)

# ── Persistence ───────────────────────────────────────────────────────────────

func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("board", "known_count", board.known_opportunity_count)
	cfg.set_value("board", "undiscovered_slots", board.undiscovered_slot_count)
	for opp in board.opportunities:  ## opp: UpgradeOpportunity
		cfg.set_value("opportunities", opp.upgrade_id, opp.state as int)
	cfg.save(SAVE_PATH)

func load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	board.known_opportunity_count = cfg.get_value("board", "known_count", 0)
	board.undiscovered_slot_count = cfg.get_value("board", "undiscovered_slots", 0)
	if not cfg.has_section("opportunities"):
		return
	for key: String in cfg.get_section_keys("opportunities"):
		var opp = board.get_opportunity(key as StringName)
		if opp:
			opp.state = cfg.get_value("opportunities", key, opp.state as int)

# ── Internal ──────────────────────────────────────────────────────────────────

func _check_expiry() -> void:
	var t := WorldStateManager.game_time
	for opp in board.opportunities:  ## opp: UpgradeOpportunity
		if opp.state != _UpgradeOpportunity.State.OPPORTUNITY:
			continue
		if opp.expiry_game_time > 0.0 and t >= opp.expiry_game_time:
			set_opportunity_state(opp.upgrade_id, _UpgradeOpportunity.State.LOST)

func _advance_chain(chain_id: StringName, completed_step: int) -> void:
	var chain = board.get_chain(chain_id)
	if not chain:
		return
	EventBus.upgrade_chain_step_completed.emit(chain_id, completed_step)
	var next: int = completed_step + 1
	if next >= chain.steps.size():
		EventBus.upgrade_chain_completed.emit(chain_id)
		return
	var next_opp = chain.steps[next]
	set_opportunity_state(next_opp.upgrade_id, _UpgradeOpportunity.State.OPPORTUNITY)

func _on_mission_completed(_mission_id: StringName) -> void:
	pass
