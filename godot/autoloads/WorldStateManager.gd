extends Node
## Persistent city and campaign state. Saved between sessions.
## This is the ground truth for faction control, infrastructure, intel, and campaign progress.

const IntelRecord = preload("res://data/IntelRecord.gd")

enum Faction {
	NONE         = 0,
	MILITARY     = 1,   # Government Military
	INTELLIGENCE = 2,   # Government Intelligence Agency
	CORPORATION  = 3,   # Corporations
	CRIME        = 4,   # Crime Syndicates
	OSS          = 5,   # Open Source Syndicate (deferred — Act 2+)
}

enum InfraPointType { REFUEL, REARM, LANDING_PAD, SAFE_HOUSE }
enum InfraStatus    { ACTIVE, HOT, DESTROYED }

# ── Inner data records (non-Node, serializable) ───────────────────────────────

class FactionState:
	var faction: Faction
	var territory_chunks: Array = []        # Array[Vector2i]
	var alert_level: float = 0.0            # 0.0–1.0; decays over time
	var player_reputation: float = 0.0     # -1.0 hostile → 1.0 allied
	var known_player_infra: Array = []      # Array[StringName] — compromised points

class InfraPoint:
	var point_id: StringName
	var point_type: InfraPointType
	var location: Vector3
	var faction_control: Faction
	var thermal_capacity: float = 1.5      # ThermalTolerance.REINFORCED default
	var status: InfraStatus = InfraStatus.ACTIVE
	var last_used_time: float = 0.0
	var uses_remaining: int = -1            # -1 = unlimited

# ── State ─────────────────────────────────────────────────────────────────────

var faction_states: Dictionary = {}       # Faction -> FactionState
var infrastructure: Dictionary = {}       # StringName -> InfraPoint
var surveillance_level: float = 0.0       # 0.0–8.0; NEVER expose directly in UI
var intel_database: Array = []            # Array[IntelRecord]
var components_secured: Array = []        # Array[StringName] — MacGuffin pieces held
var components_handed_off: Array = []     # Array[StringName] — handed off (to enemy)
var campaign_flags: Dictionary = {}       # StringName -> bool
var game_time: float = 0.0               # in-game seconds elapsed

const SAVE_PATH := "user://world_state.cfg"
const ALERT_DECAY_RATE := 0.02           # per second when player not in chunk

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_init_faction_states()
	load_state()

func _process(delta: float) -> void:
	game_time += delta
	_decay_faction_alerts(delta)
	_expire_stale_intel()

# ── Faction ───────────────────────────────────────────────────────────────────

func get_faction_state(faction: Faction) -> FactionState:
	return faction_states.get(faction)

func get_dominant_faction(chunk: Vector2i) -> Faction:
	for faction: int in faction_states:
		var state: FactionState = faction_states[faction]
		if chunk in state.territory_chunks:
			return faction as Faction
	return Faction.NONE

func set_alert_level(faction: Faction, level: float) -> void:
	var state: FactionState = faction_states.get(faction)
	if not state:
		return
	var prev := state.alert_level
	state.alert_level = clampf(level, 0.0, 1.0)
	if not is_equal_approx(prev, state.alert_level):
		EventBus.faction_alert_changed.emit(faction, Vector2i.ZERO, state.alert_level)

func modify_reputation(faction: Faction, delta: float) -> void:
	var state: FactionState = faction_states.get(faction)
	if state:
		state.player_reputation = clampf(state.player_reputation + delta, -1.0, 1.0)

# ── Infrastructure ────────────────────────────────────────────────────────────

func register_infra_point(point: InfraPoint) -> void:
	infrastructure[point.point_id] = point

func get_infra_point(point_id: StringName) -> InfraPoint:
	return infrastructure.get(point_id)

func get_active_points_of_type(type: InfraPointType) -> Array:
	return infrastructure.values().filter(
		func(p: InfraPoint) -> bool: return p.point_type == type and p.status == InfraStatus.ACTIVE
	)

func compromise_infra_point(point_id: StringName) -> void:
	var point: InfraPoint = infrastructure.get(point_id)
	if not point:
		return
	point.status = InfraStatus.HOT
	EventBus.infrastructure_compromised.emit(point_id)
	if point.point_type == InfraPointType.SAFE_HOUSE:
		EventBus.safe_house_burned.emit(point_id)

# ── Surveillance ──────────────────────────────────────────────────────────────

func increment_surveillance(amount: float) -> void:
	var prev := floori(surveillance_level)
	surveillance_level = clampf(surveillance_level + amount, 0.0, 8.0)
	if floori(surveillance_level) > prev:
		EventBus.surveillance_threshold_crossed.emit(surveillance_level)

# ── Intel ─────────────────────────────────────────────────────────────────────

func add_intel(record) -> void:  ## record: IntelRecord
	intel_database.append(record)
	EventBus.intel_discovered.emit(record)

func get_fresh_intel(intel_type: int) -> Array:  ## intel_type: IntelRecord.IntelType
	return intel_database.filter(
		func(r) -> bool:
			return r.intel_type == intel_type and r.is_fresh(game_time)
	)

# ── MacGuffin ─────────────────────────────────────────────────────────────────

func secure_component(component_id: StringName) -> void:
	if component_id not in components_secured:
		components_secured.append(component_id)

func hand_off_component(component_id: StringName) -> void:
	components_secured.erase(component_id)
	if component_id not in components_handed_off:
		components_handed_off.append(component_id)

# ── Campaign flags ────────────────────────────────────────────────────────────

func set_flag(flag: StringName) -> void:
	campaign_flags[flag] = true

func has_flag(flag: StringName) -> bool:
	return campaign_flags.get(flag, false)

# ── Persistence ───────────────────────────────────────────────────────────────

func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("world", "surveillance_level", surveillance_level)
	cfg.set_value("world", "game_time", game_time)
	cfg.set_value("world", "components_secured", components_secured)
	cfg.set_value("world", "components_handed_off", components_handed_off)
	cfg.set_value("world", "campaign_flags", campaign_flags)
	var alert_levels := {}
	for faction: int in faction_states:
		var state: FactionState = faction_states[faction]
		alert_levels[faction] = {
			"alert": state.alert_level,
			"reputation": state.player_reputation,
		}
	cfg.set_value("factions", "states", alert_levels)
	cfg.save(SAVE_PATH)

func load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	surveillance_level = cfg.get_value("world", "surveillance_level", 0.0)
	game_time = cfg.get_value("world", "game_time", 0.0)
	components_secured = cfg.get_value("world", "components_secured", [])
	components_handed_off = cfg.get_value("world", "components_handed_off", [])
	campaign_flags = cfg.get_value("world", "campaign_flags", {})
	var alert_levels: Dictionary = cfg.get_value("factions", "states", {})
	for faction_key in alert_levels:
		var state: FactionState = faction_states.get(faction_key as Faction)
		if state:
			state.alert_level = alert_levels[faction_key].get("alert", 0.0)
			state.player_reputation = alert_levels[faction_key].get("reputation", 0.0)

func reset_state() -> void:
	surveillance_level = 0.0
	game_time = 0.0
	components_secured.clear()
	components_handed_off.clear()
	campaign_flags.clear()
	intel_database.clear()
	infrastructure.clear()
	_init_faction_states()

# ── Internal ──────────────────────────────────────────────────────────────────

func _init_faction_states() -> void:
	faction_states.clear()
	for faction: int in [Faction.MILITARY, Faction.INTELLIGENCE, Faction.CORPORATION, Faction.CRIME, Faction.OSS]:
		var state := FactionState.new()
		state.faction = faction as Faction
		faction_states[faction] = state

func _decay_faction_alerts(delta: float) -> void:
	for faction: int in faction_states:
		var state: FactionState = faction_states[faction]
		if state.alert_level > 0.0:
			set_alert_level(faction as Faction, state.alert_level - ALERT_DECAY_RATE * delta)

func _expire_stale_intel() -> void:
	var before := intel_database.size()
	intel_database = intel_database.filter(
		func(r) -> bool: return r.is_fresh(game_time)
	)
	# Emit expired signals for removed records (simplified — just track count)
	if intel_database.size() < before:
		pass  # TODO: emit per-record when IntelRecord tracks its own id
