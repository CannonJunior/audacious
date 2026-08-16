extends Node
## Manages the suit's compressed-gas thruster allocation.
## Branch-manifold model: player routes tank pressure to 4 branches.
## Modules within a pressurized branch actuate on flight-computer demand.
## Broadcasts gas_state (4 branch dicts) to WebViewBridge at _PUSH_HZ.

const _DRAIN_TIME  := 120.0  ## seconds to drain full tank at 100% total branch pressure
const _REFILL_TIME := 60.0   ## seconds to refill empty tank at zero flow
const _PUSH_HZ     := 2.0

const BRANCHES: Array[String] = ["directional", "attitude", "maneuver", "environ"]

## Minimum pressure fraction (0–1) required to actuate any module in the branch.
const BRANCH_MIN: Dictionary = {
	"directional": 0.15,
	"attitude":    0.08,
	"maneuver":    0.12,
	"environ":     0.05,
}

const BRANCH_LABEL: Dictionary = {
	"directional": "DIRECTIONAL",
	"attitude":    "ATTITUDE",
	"maneuver":    "MANEUVER",
	"environ":     "ENVIRON",
}

## Module catalog — defines what each branch contains.
## flow_rate removed: modules within a branch actuate automatically; branch
## pressure controls the collective output, not individual valve positions.
const _CATALOG: Array[Dictionary] = [
	{ "id": &"shoulder_port", "label": "PORT SHOULDER",  "category": "directional", "desc": "Left lateral thrust. Sideways dodge and strafe." },
	{ "id": &"shoulder_star", "label": "STBD SHOULDER",  "category": "directional", "desc": "Right lateral thrust. Paired with port for crab-walk." },
	{ "id": &"dorsal_pack",   "label": "DORSAL JETS",    "category": "directional", "desc": "Rearward nozzles. Deceleration and landing flare." },
	{ "id": &"ventral_burst", "label": "VENTRAL BURST",  "category": "directional", "desc": "Chest-facing nozzles. Rapid backward push." },
	{ "id": &"roll_port",     "label": "ROLL PORT",      "category": "attitude",    "desc": "Counter-rotation vent. Prevents barrel roll leftward." },
	{ "id": &"roll_star",     "label": "ROLL STBD",      "category": "attitude",    "desc": "Counter-rotation vent. Prevents barrel roll rightward." },
	{ "id": &"pitch_ctrl",    "label": "PITCH CONTROL",  "category": "attitude",    "desc": "Nose-up/nose-down correction. Prevents tumbling." },
	{ "id": &"yaw_damper",    "label": "YAW DAMPER",     "category": "attitude",    "desc": "Anti-spin vent on spine. Stops body rotation." },
	{ "id": &"jump_damper",   "label": "JUMP DAMPENERS", "category": "maneuver",    "desc": "Leg nozzles cushion landing. Reduces thermal spike." },
	{ "id": &"wall_pushoff",  "label": "WALL PUSH-OFF",  "category": "maneuver",    "desc": "Chest/shoulder burst for parkour wall-kicks." },
	{ "id": &"corridor_dash", "label": "CORRIDOR DASH",  "category": "maneuver",    "desc": "Spine jets for 0.8s speed burst in tight spaces." },
	{ "id": &"terrain_anchor","label": "TERRAIN ANCHOR", "category": "environ",     "desc": "Downward vents keep suit pinned to sloped surfaces." },
	{ "id": &"dust_screen",   "label": "DUST SCREEN",    "category": "environ",     "desc": "Micro-pore gas cloud. Visual cover burst." },
]

## category → float (0.0–1.0 pressure fraction routed to that branch).
var _branch_pressure: Dictionary = {
	"directional": 0.0, "attitude": 0.0, "maneuver": 0.0, "environ": 0.0
}
var _catalog_map:  Dictionary = {}
var _tank_pressure: float     = 1.0
var _push_timer:    float     = 0.0
var _dirty:         bool      = true
var _branch_cache:  Array     = []


func _ready() -> void:
	for entry: Dictionary in _CATALOG:
		_catalog_map[entry["id"]] = entry
	EventBus.gas_routes_changed.connect(_on_routes_changed)
	push_state()


func _process(delta: float) -> void:
	_simulate_tank(delta)
	_push_timer += delta
	if _push_timer >= 1.0 / _PUSH_HZ:
		_push_timer = 0.0
		push_state()


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the branch pressure fraction for the branch containing module_id.
func get_allocation(module_id: StringName) -> float:
	var entry: Dictionary = _catalog_map.get(module_id, {})
	if entry.is_empty():
		return 0.0
	return _branch_pressure.get(entry["category"], 0.0)


## True when the module's branch pressure is at or above the branch minimum.
func is_active(module_id: StringName) -> bool:
	var entry: Dictionary = _catalog_map.get(module_id, {})
	if entry.is_empty():
		return false
	var cat: String = entry["category"]
	return _branch_pressure.get(cat, 0.0) >= float(BRANCH_MIN.get(cat, 1.0))


## Returns pressure fraction (0–1) for a branch directly.
func get_branch_pressure(category: String) -> float:
	return _branch_pressure.get(category, 0.0)


## True when a branch is pressurized at or above its minimum threshold.
func is_branch_active(category: String) -> bool:
	return _branch_pressure.get(category, 0.0) >= float(BRANCH_MIN.get(category, 1.0))


## Current tank pressure (0.0 = empty, 1.0 = full).
func get_tank_pressure() -> float:
	return _tank_pressure


## Pushes 4 branch-state dicts and tank pressure to WebViewBridge.
func push_state() -> void:
	if _dirty:
		_branch_cache.clear()
		for cat: String in BRANCHES:
			var mods: Array = []
			for entry: Dictionary in _CATALOG:
				if entry["category"] == cat:
					mods.append({
						"id":    str(entry["id"]),
						"label": entry["label"],
						"desc":  entry["desc"],
					})
			_branch_cache.append({
				"id":           cat,
				"label":        BRANCH_LABEL[cat],
				"category":     cat,
				"allocated":    _branch_pressure.get(cat, 0.0),
				"min_pressure": BRANCH_MIN.get(cat, 0.0),
				"modules":      mods,
			})
		_dirty = false
	WebViewBridge.push_gas_state(_branch_cache, _tank_pressure)


# ── Internal ──────────────────────────────────────────────────────────────────

func _simulate_tank(delta: float) -> void:
	var total_flow := 0.0
	for cat: String in BRANCHES:
		total_flow += _branch_pressure.get(cat, 0.0)
	if total_flow > 0.0:
		_tank_pressure = maxf(0.0, _tank_pressure - (total_flow / _DRAIN_TIME) * delta)
	else:
		_tank_pressure = minf(1.0, _tank_pressure + (1.0 / _REFILL_TIME) * delta)


func _on_routes_changed(routes: Dictionary) -> void:
	for cat: String in routes:
		if _branch_pressure.has(cat):
			_branch_pressure[cat] = clampf(float(routes[cat]), 0.0, 1.0)
	_dirty = true
