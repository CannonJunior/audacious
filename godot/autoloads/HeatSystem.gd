extends Node
## Per-target heat tracking. Distinct from WorldStateManager's per-faction alert level.
## Heat = how alerted a specific facility is to the player's recent activity.
## High heat means more guards, faster alarm response, shorter windows.

const SAVE_PATH: String = "user://heat_state.cfg"

## Heat decays slowly — designed to last several in-game sessions, not seconds.
const DECAY_RATE: float = 0.0001   # per game-second; 0→1.0 takes ~2.8 hours game-time

const THRESHOLD_LOW:      float = 0.25
const THRESHOLD_ELEVATED: float = 0.50
const THRESHOLD_HIGH:     float = 0.75

var _heat: Dictionary = {}   # StringName → float (0.0–1.0)

func _ready() -> void:
	load_state()
	EventBus.mission_completed.connect(_on_mission_completed)

func _process(delta: float) -> void:
	_decay_all(delta)

# ── Public interface ──────────────────────────────────────────────────────────

func get_heat(target_id: StringName) -> float:
	return _heat.get(target_id, 0.0)

func add_heat(target_id: StringName, amount: float) -> void:
	var prev := get_heat(target_id)
	var next := clampf(prev + amount, 0.0, 1.0)
	if is_equal_approx(prev, next):
		return
	_heat[target_id] = next
	EventBus.heist_target_heat_changed.emit(target_id, next)

func reduce_heat(target_id: StringName, amount: float) -> void:
	add_heat(target_id, -amount)

func get_heat_tier(target_id: StringName) -> StringName:
	var h := get_heat(target_id)
	if h <= 0.0:                return &"none"
	if h < THRESHOLD_LOW:       return &"low"
	if h < THRESHOLD_ELEVATED:  return &"elevated"
	if h < THRESHOLD_HIGH:      return &"high"
	return &"hot"

## Effective security level for a target (base + heat modifier). Clamped 1–5.
func effective_security_level(target) -> int:  ## target: HeistTarget
	var tier := get_heat_tier(target.target_id)
	var bonus: int
	match tier:
		&"hot":      bonus = 2
		&"high":     bonus = 1
		_:           bonus = 0
	return clampi(target.base_security_level + bonus, 1, 5)

## All targets with heat > 0, sorted highest heat first.
func get_hot_targets() -> Array:
	var entries: Array = []
	for id: StringName in _heat.keys():
		entries.append({ "target_id": id, "heat": _heat[id] })
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.heat > b.heat)
	return entries

# ── Persistence ───────────────────────────────────────────────────────────────

func save_state() -> void:
	var cfg := ConfigFile.new()
	for id: StringName in _heat.keys():
		cfg.set_value("heat", id, _heat[id])
	cfg.save(SAVE_PATH)

func load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if not cfg.has_section("heat"):
		return
	for key: String in cfg.get_section_keys("heat"):
		_heat[key as StringName] = cfg.get_value("heat", key, 0.0)

# ── Internal ──────────────────────────────────────────────────────────────────

func _on_mission_completed(_mission_id: StringName) -> void:
	# Specific heat amounts are applied by mission execution via add_heat().
	# This hook is reserved for future automatic heat adjustments.
	pass

func _decay_all(delta: float) -> void:
	for id: StringName in _heat.keys().duplicate():
		if not _heat.has(id):
			continue
		var current: float = _heat[id]
		var after := maxf(0.0, current - DECAY_RATE * delta)
		if after <= 0.0:
			_heat.erase(id)
			EventBus.heist_target_heat_changed.emit(id, 0.0)
		elif not is_equal_approx(after, current):
			_heat[id] = after
