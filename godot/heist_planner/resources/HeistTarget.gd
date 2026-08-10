class_name HeistTarget
extends Resource
## Static dossier for one heist target. Author as .tres in res://data/heist_targets/.
## Runtime state (heat, active route) lives in HeatSystem and the route dictionary,
## not here — this resource represents what is known, not the player's current plan.

const IntelEntry = preload("res://heist_planner/resources/IntelEntry.gd")
const ApproachOption = preload("res://heist_planner/resources/ApproachOption.gd")
const MissionWindow = preload("res://heist_planner/resources/MissionWindow.gd")
const CargoProfile = preload("res://heist_planner/resources/CargoProfile.gd")

@export var target_id: StringName = &""
@export var display_name: String = ""
@export var target_faction: int = 0  ## WorldStateManager.Faction.NONE
@export var target_chunk: Vector2i = Vector2i.ZERO   # city grid position
@export var base_security_level: int = 2             # 1–5; modified at runtime by heat
@export var is_sidequest: bool = false               # true = upgrade sidequest target

# ── Intelligence ──────────────────────────────────────────────────────────────

@export var intel_entries: Array[IntelEntry] = []

# ── Approach options ──────────────────────────────────────────────────────────

@export var approach_options: Array[ApproachOption] = []

# ── Mission windows ───────────────────────────────────────────────────────────

@export var mission_windows: Array[MissionWindow] = []

# ── Objective ─────────────────────────────────────────────────────────────────

## ID matching an ObjectManifest.RareComponent (or UpgradeOpportunity.upgrade_id for sidequests).
@export var objective_item_id: StringName = &""
@export var objective_display_name: String = ""
@export var objective_rare_role: String = ""  # empty for sidequests

# ── Intel management ──────────────────────────────────────────────────────────

func get_intel(field_id: StringName) -> IntelEntry:
	for entry: IntelEntry in intel_entries:
		if entry.field_id == field_id:
			return entry
	return null

func add_or_update_intel(entry: IntelEntry) -> void:
	for i: int in range(intel_entries.size()):
		if intel_entries[i].field_id == entry.field_id:
			intel_entries[i] = entry
			EventBus.heist_target_intel_updated.emit(target_id)
			return
	intel_entries.append(entry)
	EventBus.heist_target_intel_updated.emit(target_id)

func has_confirmed(field_id: StringName) -> bool:
	var entry := get_intel(field_id)
	return entry != null and entry.confidence == IntelEntry.Confidence.CONFIRMED

## Fraction of defined intel fields that are at least PROBABLE.
func intel_quality() -> float:
	if intel_entries.is_empty():
		return 0.0
	var known := 0
	for entry: IntelEntry in intel_entries:
		if entry.confidence >= IntelEntry.Confidence.PROBABLE:
			known += 1
	return float(known) / float(intel_entries.size())

# ── Approach filtering ────────────────────────────────────────────────────────

func get_viable_approaches(capability_tags: Array, cargo: CargoProfile = null) -> Array[ApproachOption]:
	var viable: Array[ApproachOption] = []
	for opt: ApproachOption in approach_options:
		var ok := true
		for cap: String in opt.required_capabilities:
			if cap not in capability_tags:
				ok = false
				break
		if ok and cargo != null and opt.max_cargo_clearance_m > 0.0:
			if not cargo.fits_clearance(opt.max_cargo_clearance_m):
				ok = false
		if ok:
			viable.append(opt)
	return viable

func get_fresh_windows(current_time: float) -> Array[MissionWindow]:
	return mission_windows  # windows don't expire; their intel confidence decays instead
