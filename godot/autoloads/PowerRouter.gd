extends Node
## Manages the suit's power bus allocation across 5 category buses.
## Player routes capacity to categories; modules within a powered category
## activate when the bus allocation meets their minimum draw threshold.
## Broadcasts power_state (5 category dicts) to WebViewBridge on change.

const CAPACITY := 100.0   ## total power in percentage points

const CATEGORIES: Array[String] = ["weapon", "stealth", "defense", "sensor", "support"]

const CATEGORY_LABEL: Dictionary = {
	"weapon":  "WEAPON",
	"stealth": "STEALTH",
	"defense": "DEFENSE",
	"sensor":  "SENSOR",
	"support": "SUPPORT",
}

## Module catalog — each module's min_draw (in % of CAPACITY) is the threshold
## at which it activates when its category bus is powered to that level.
const _CATALOG: Array[Dictionary] = [
	# weapon bus
	{ "id": &"railgun_cap",  "label": "RAILGUN CAP.",    "category": "weapon",  "min_draw": 20, "desc": "Coil accelerator charge. Spikes during fire." },
	{ "id": &"sonic_lance",  "label": "SONIC LANCE",     "category": "weapon",  "min_draw": 10, "desc": "Resonance weapon. Non-lethal at low power." },
	{ "id": &"plasma_torch", "label": "PLASMA TORCH",    "category": "weapon",  "min_draw": 15, "desc": "Sustained superheated plasma emitter." },
	{ "id": &"emp_vortex",   "label": "EMP VORTEX",      "category": "weapon",  "min_draw": 22, "desc": "Single-burst EM pulse. 4s recharge." },
	# stealth bus
	{ "id": &"optical_mesh",   "label": "OPTICAL MESH",   "category": "stealth", "min_draw": 25, "desc": "Active photonic camouflage. Cannot sprint." },
	{ "id": &"acoustic_liner", "label": "ACOUSTIC LINER", "category": "stealth", "min_draw":  8, "desc": "Piezoelectric panels suppress servo noise." },
	{ "id": &"thermal_shroud", "label": "THERMAL SHROUD", "category": "stealth", "min_draw":  8, "desc": "IR suppression against thermal cameras." },
	{ "id": &"em_damper",      "label": "EM DAMPER",      "category": "stealth", "min_draw":  6, "desc": "Suppresses suit EM emissions. Kills radar." },
	# defense bus
	{ "id": &"reflect_plating", "label": "REFLECT PLATING", "category": "defense", "min_draw": 10, "desc": "Deflects directed-energy weapons." },
	{ "id": &"kinetic_barrier", "label": "KINETIC BARRIER", "category": "defense", "min_draw": 15, "desc": "Energy field absorbs ballistic impacts." },
	{ "id": &"point_defense",   "label": "POINT DEFENSE",   "category": "defense", "min_draw": 15, "desc": "AI intercepts incoming missiles/grenades." },
	# sensor bus
	{ "id": &"threat_radar",     "label": "THREAT RADAR",    "category": "sensor", "min_draw":  5, "desc": "360° hostile tracking. Updates every 0.5s." },
	{ "id": &"target_lock",      "label": "TARGET LOCK",     "category": "sensor", "min_draw":  8, "desc": "Precision targeting + lead indicators." },
	{ "id": &"ew_suite",         "label": "EW SUITE",        "category": "sensor", "min_draw": 12, "desc": "Jam comms, spoof sensors, hack networks." },
	{ "id": &"signal_intercept", "label": "SIGNAL INTERCEPT","category": "sensor", "min_draw":  0, "desc": "Passive comms monitoring. Extremely low draw." },
	# support bus
	{ "id": &"comms_boost",  "label": "COMMS BOOST",    "category": "support", "min_draw": 3, "desc": "Long-range encrypted uplink to handler." },
	{ "id": &"mag_lock",     "label": "MAG-LOCK SOLES", "category": "support", "min_draw": 9, "desc": "Electromagnetic adhesion for vertical traversal." },
	{ "id": &"med_injector", "label": "MED-INJECTOR",   "category": "support", "min_draw": 6, "desc": "Auto-response: adrenaline, clotting, blockers." },
]

## category → float (0.0–1.0 fraction of CAPACITY allocated to that bus).
## 1.0 = 100 units. Sum across categories may exceed 1.0 (overload condition).
var _category_allocation: Dictionary = {
	"weapon": 0.0, "stealth": 0.0, "defense": 0.0, "sensor": 0.0, "support": 0.0
}
var _catalog_map: Dictionary = {}


func _ready() -> void:
	for entry: Dictionary in _CATALOG:
		_catalog_map[entry["id"]] = entry
	EventBus.power_routes_changed.connect(_on_routes_changed)
	push_state()


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the category bus allocation fraction for the bus containing module_id.
func get_allocation(module_id: StringName) -> float:
	var entry: Dictionary = _catalog_map.get(module_id, {})
	if entry.is_empty():
		return 0.0
	return _category_allocation.get(entry["category"], 0.0)


## True when the module's category bus is powered to at least its min_draw.
func is_active(module_id: StringName) -> bool:
	var entry: Dictionary = _catalog_map.get(module_id, {})
	if entry.is_empty():
		return false
	var alloc_units: float = _category_allocation.get(entry["category"], 0.0) * CAPACITY
	return alloc_units >= float(entry["min_draw"])


## Returns allocation fraction (0–1) for a category bus directly.
func get_category_allocation(category: String) -> float:
	return _category_allocation.get(category, 0.0)


## Total power draw in percentage points across all category buses.
func total_load_pct() -> float:
	var total := 0.0
	for cat: String in CATEGORIES:
		total += _category_allocation.get(cat, 0.0) * CAPACITY
	return total


## Pushes 5 category-state dicts to WebViewBridge.
func push_state() -> void:
	var cats: Array = []
	for cat: String in CATEGORIES:
		var alloc: float = _category_allocation.get(cat, 0.0)
		var alloc_units: float = alloc * CAPACITY
		var mods: Array = []
		for entry: Dictionary in _CATALOG:
			if entry["category"] == cat:
				mods.append({
					"id":       str(entry["id"]),
					"label":    entry["label"],
					"min_draw": entry["min_draw"],
					"desc":     entry["desc"],
					"active":   alloc_units >= float(entry["min_draw"]),
				})
		cats.append({
			"id":        cat,
			"label":     CATEGORY_LABEL[cat],
			"category":  cat,
			"allocated":  alloc,
			"modules":   mods,
		})
	WebViewBridge.push_power_state(cats, CAPACITY)


# ── Internal ──────────────────────────────────────────────────────────────────

func _on_routes_changed(routes: Dictionary) -> void:
	for cat: String in routes:
		if _category_allocation.has(cat):
			_category_allocation[cat] = clampf(float(routes[cat]), 0.0, 1.0)
	push_state()
