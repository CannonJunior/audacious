extends Node
## Manages the suit's energy allocation across powered modules.
## Single source of truth for which modules are active and at what level.
## Broadcasts power_state to WebViewBridge on init and configuration change.
## Reacts to power_routes_changed (from WebViewBridge) and stores allocations.
##
## Capacity is expressed as a flat 100 (percent). When power cores grow to carry
## an energy_output stat in SuitPartResource, derive capacity from that instead.
##
## Other systems query state via get_allocation() / is_active().

const CAPACITY := 100.0

# ── Module catalog ────────────────────────────────────────────────────────────
# Order must match the ring layout in power_router.html (inner ring first, then outer).

const _CATALOG: Array[Dictionary] = [
	# Inner ring — sensors & support (low draw, always-on candidates)
	{ "id": &"threat_radar",     "label": "THREAT RADAR",    "category": "sensor",  "base_draw": 10, "min_draw": 5,  "desc": "360° hostile tracking. Updates every 0.5s." },
	{ "id": &"comms_boost",      "label": "COMMS BOOST",     "category": "support", "base_draw":  7, "min_draw": 3,  "desc": "Long-range encrypted uplink to handler." },
	{ "id": &"mag_lock",         "label": "MAG-LOCK SOLES",  "category": "support", "base_draw":  9, "min_draw": 9,  "desc": "Electromagnetic adhesion for vertical traversal." },
	{ "id": &"med_injector",     "label": "MED-INJECTOR",    "category": "support", "base_draw":  6, "min_draw": 6,  "desc": "Auto-response: adrenaline, clotting, blockers." },
	{ "id": &"acoustic_liner",   "label": "ACOUSTIC LINER",  "category": "stealth", "base_draw":  8, "min_draw": 8,  "desc": "Piezoelectric panels suppress servo noise." },
	{ "id": &"signal_intercept", "label": "SIGNAL INTERCEPT","category": "sensor",  "base_draw":  3, "min_draw": 0,  "desc": "Passive comms monitoring. Extremely low draw." },
	# Outer ring — weapons, stealth, defense, EW
	{ "id": &"optical_mesh",     "label": "OPTICAL MESH",    "category": "stealth", "base_draw": 40, "min_draw": 25, "desc": "Active photonic camouflage. Cannot sprint." },
	{ "id": &"railgun_cap",      "label": "RAILGUN CAP.",    "category": "weapon",  "base_draw": 35, "min_draw": 20, "desc": "Coil accelerator charge. Spikes during fire." },
	{ "id": &"target_lock",      "label": "TARGET LOCK",     "category": "sensor",  "base_draw": 14, "min_draw": 8,  "desc": "Precision targeting + lead indicators." },
	{ "id": &"ew_suite",         "label": "EW SUITE",        "category": "sensor",  "base_draw": 20, "min_draw": 12, "desc": "Jam comms, spoof sensors, hack networks." },
	{ "id": &"reflect_plating",  "label": "REFLECT PLATING", "category": "defense", "base_draw": 10, "min_draw": 10, "desc": "Deflects directed-energy weapons." },
	{ "id": &"sonic_lance",      "label": "SONIC LANCE",     "category": "weapon",  "base_draw": 18, "min_draw": 10, "desc": "Resonance weapon. Non-lethal at low power." },
	{ "id": &"plasma_torch",     "label": "PLASMA TORCH",    "category": "weapon",  "base_draw": 28, "min_draw": 15, "desc": "Sustained superheated plasma emitter." },
	{ "id": &"emp_vortex",       "label": "EMP VORTEX",      "category": "weapon",  "base_draw": 22, "min_draw": 22, "desc": "Single-burst EM pulse. 4s recharge." },
	{ "id": &"kinetic_barrier",  "label": "KINETIC BARRIER", "category": "defense", "base_draw": 30, "min_draw": 15, "desc": "Energy field absorbs ballistic impacts." },
	{ "id": &"point_defense",    "label": "POINT DEFENSE",   "category": "defense", "base_draw": 25, "min_draw": 15, "desc": "AI intercepts incoming missiles/grenades." },
	{ "id": &"thermal_shroud",   "label": "THERMAL SHROUD",  "category": "stealth", "base_draw": 15, "min_draw": 8,  "desc": "IR suppression against thermal cameras." },
	{ "id": &"em_damper",        "label": "EM DAMPER",       "category": "stealth", "base_draw": 12, "min_draw": 6,  "desc": "Suppresses suit EM emissions. Kills radar." },
]

# StringName → float (0.0–1.0); 1.0 = 100% of capacity allocated to this module
var _allocations:  Dictionary = {}
var _catalog_map:  Dictionary = {}   # StringName → catalog entry; built once in _ready()

func _ready() -> void:
	for entry: Dictionary in _CATALOG:
		_allocations[entry["id"]] = 0.0
		_catalog_map[entry["id"]] = entry
	EventBus.power_routes_changed.connect(_on_routes_changed)
	push_state()

# ── Public API ────────────────────────────────────────────────────────────────

## Returns allocation fraction (0.0–1.0). Multiply by CAPACITY for percent.
func get_allocation(module_id: StringName) -> float:
	return _allocations.get(module_id, 0.0)

## True when allocated percent meets the module's minimum power threshold.
func is_active(module_id: StringName) -> bool:
	var entry: Dictionary = _catalog_map.get(module_id, {})
	if entry.is_empty():
		return false
	return get_allocation(module_id) * CAPACITY >= float(entry["min_draw"])

## Total percentage currently allocated across all modules.
func total_load_pct() -> float:
	var total := 0.0
	for v: float in _allocations.values():
		total += v * CAPACITY
	return total

## Pushes the full module catalog and current allocations to the browser UI.
func push_state() -> void:
	var modules: Array = []
	for entry: Dictionary in _CATALOG:
		var alloc: float = _allocations.get(entry["id"], 0.0)
		modules.append({
			"id":        str(entry["id"]),
			"label":     entry["label"],
			"category":  entry["category"],
			"base_draw": entry["base_draw"],
			"min_draw":  entry["min_draw"],
			"desc":      entry["desc"],
			"allocated": alloc,
			"unlocked":  true,
		})
	WebViewBridge.push_power_state(modules, CAPACITY)

# ── Internal ──────────────────────────────────────────────────────────────────

func _on_routes_changed(routes: Dictionary) -> void:
	for id_str: String in routes:
		var sn := StringName(id_str)
		if _allocations.has(sn):
			_allocations[sn] = clampf(float(routes[id_str]), 0.0, 1.0)
