extends Node
## Manages the suit's compressed-gas thruster allocation.
## Simulates tank drain under active flow and passive refill at rest.
## Broadcasts gas_state to WebViewBridge at _PUSH_HZ.
## Other systems query state via get_allocation() / is_active() / get_tank_pressure().

# ── Tuning constants ──────────────────────────────────────────────────────────

## Seconds to drain a full tank when all modules run at 100% allocation.
const _DRAIN_TIME  := 120.0
## Seconds to refill an empty tank with zero active flow.
const _REFILL_TIME := 60.0
## How often the browser receives a tank pressure update.
const _PUSH_HZ     := 2.0

# ── Module catalog ────────────────────────────────────────────────────────────
# flow_rate and min_flow are 0.0–1.0 fractions of the module's rated output.
# Positions in the manifold schematic are fixed in gas_router.html by index order.

const _CATALOG: Array[Dictionary] = [
	# Directional — left arm of manifold
	{ "id": &"shoulder_port", "label": "PORT SHOULDER",  "category": "directional", "flow_rate": 0.15, "min_flow": 0.15, "desc": "Left lateral thrust. Sideways dodge and strafe." },
	{ "id": &"shoulder_star", "label": "STBD SHOULDER",  "category": "directional", "flow_rate": 0.15, "min_flow": 0.15, "desc": "Right lateral thrust. Paired with port for crab-walk." },
	{ "id": &"dorsal_pack",   "label": "DORSAL JETS",    "category": "directional", "flow_rate": 0.20, "min_flow": 0.10, "desc": "Rearward nozzles. Deceleration and landing flare." },
	{ "id": &"ventral_burst", "label": "VENTRAL BURST",  "category": "directional", "flow_rate": 0.20, "min_flow": 0.20, "desc": "Chest-facing nozzles. Rapid backward push." },
	# Attitude — right arm of manifold
	{ "id": &"roll_port",     "label": "ROLL PORT",      "category": "attitude",    "flow_rate": 0.08, "min_flow": 0.08, "desc": "Counter-rotation vent. Prevents barrel roll leftward." },
	{ "id": &"roll_star",     "label": "ROLL STBD",      "category": "attitude",    "flow_rate": 0.08, "min_flow": 0.08, "desc": "Counter-rotation vent. Prevents barrel roll rightward." },
	{ "id": &"pitch_ctrl",    "label": "PITCH CONTROL",  "category": "attitude",    "flow_rate": 0.10, "min_flow": 0.05, "desc": "Nose-up/nose-down correction. Prevents tumbling." },
	{ "id": &"yaw_damper",    "label": "YAW DAMPER",     "category": "attitude",    "flow_rate": 0.07, "min_flow": 0.07, "desc": "Anti-spin vent on spine. Stops body rotation." },
	# Maneuver — lower left branches
	{ "id": &"jump_damper",   "label": "JUMP DAMPENERS", "category": "maneuver",    "flow_rate": 0.18, "min_flow": 0.18, "desc": "Leg nozzles cushion landing. Reduces thermal spike." },
	{ "id": &"wall_pushoff",  "label": "WALL PUSH-OFF",  "category": "maneuver",    "flow_rate": 0.12, "min_flow": 0.12, "desc": "Chest/shoulder burst for parkour wall-kicks." },
	{ "id": &"corridor_dash", "label": "CORRIDOR DASH",  "category": "maneuver",    "flow_rate": 0.22, "min_flow": 0.22, "desc": "Spine jets for 0.8s speed burst in tight spaces." },
	# Environmental — lower right branches
	{ "id": &"terrain_anchor","label": "TERRAIN ANCHOR", "category": "environ",     "flow_rate": 0.05, "min_flow": 0.05, "desc": "Downward vents keep suit pinned to sloped surfaces." },
	{ "id": &"dust_screen",   "label": "DUST SCREEN",    "category": "environ",     "flow_rate": 0.10, "min_flow": 0.10, "desc": "Micro-pore gas cloud. Visual cover burst." },
]

# StringName → float (0.0–1.0)
var _allocations:   Dictionary = {}
var _catalog_map:   Dictionary = {}   # StringName → catalog entry; built once in _ready()
var _tank_pressure: float      = 1.0
var _push_timer:    float      = 0.0
var _dirty:         bool       = true    # rebuild module cache before next push
var _module_cache:  Array      = []

func _ready() -> void:
	for entry: Dictionary in _CATALOG:
		_allocations[entry["id"]] = 0.0
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

## Returns allocation fraction (0.0–1.0).
func get_allocation(module_id: StringName) -> float:
	return _allocations.get(module_id, 0.0)

## True when allocation meets the module's minimum flow threshold.
func is_active(module_id: StringName) -> bool:
	var entry: Dictionary = _catalog_map.get(module_id, {})
	if entry.is_empty():
		return false
	return get_allocation(module_id) >= float(entry["min_flow"])

## Current tank pressure (0.0 = empty, 1.0 = full).
func get_tank_pressure() -> float:
	return _tank_pressure

## Pushes the full module catalog and current tank pressure to the browser UI.
func push_state() -> void:
	if _dirty:
		_module_cache.clear()
		for entry: Dictionary in _CATALOG:
			_module_cache.append({
				"id":        str(entry["id"]),
				"label":     entry["label"],
				"category":  entry["category"],
				"flow_rate": entry["flow_rate"],
				"min_flow":  entry["min_flow"],
				"desc":      entry["desc"],
				"allocated": _allocations.get(entry["id"], 0.0),
			})
		_dirty = false
	WebViewBridge.push_gas_state(_module_cache, _tank_pressure)

# ── Internal ──────────────────────────────────────────────────────────────────

func _simulate_tank(delta: float) -> void:
	# Total flow = sum of all allocations (each is 0–1 fraction of their rated rate).
	# A single module at full allocation contributes its flow_rate to total drain.
	var total_flow := 0.0
	for id: StringName in _allocations:
		total_flow += _allocations[id]

	if total_flow > 0.0:
		_tank_pressure = maxf(0.0, _tank_pressure - (total_flow / _DRAIN_TIME) * delta)
	else:
		_tank_pressure = minf(1.0, _tank_pressure + (1.0 / _REFILL_TIME) * delta)

func _on_routes_changed(routes: Dictionary) -> void:
	for id_str: String in routes:
		var sn := StringName(id_str)
		if _allocations.has(sn):
			_allocations[sn] = clampf(float(routes[id_str]), 0.0, 1.0)
	_dirty = true
