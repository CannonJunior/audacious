class_name ObjectManifest
extends Resource
## Tracks the player's progress assembling the Reality-Anchor Resonance Engine.
## This is the win condition and the driver of the target priority system.

const RareComponent = preload("res://heist_planner/resources/RareComponent.gd")

@export var object_name: String = "Reality-Anchor Resonance Engine"
@export var components: Array[RareComponent] = []

## Per-heist detection outcomes. mission_id → "ghost" | "recovered" | "failed"
@export var detection_aggregate: Dictionary = {}

# ── Progress ──────────────────────────────────────────────────────────────────

func assembly_progress() -> float:
	if components.is_empty():
		return 0.0
	var total := 0.0
	for comp: RareComponent in components:
		total += comp.progress_ratio()
	return total / float(components.size())

func is_complete() -> bool:
	for comp: RareComponent in components:
		if not comp.is_acquired() or comp.is_damaged:
			return false
	return not components.is_empty()

func get_component(component_id: StringName) -> RareComponent:
	for comp: RareComponent in components:
		if comp.component_id == component_id:
			return comp
	return null

func get_unacquired() -> Array[RareComponent]:
	var out: Array[RareComponent] = []
	for comp: RareComponent in components:
		if not comp.is_acquired():
			out.append(comp)
	return out

func get_damaged() -> Array[RareComponent]:
	var out: Array[RareComponent] = []
	for comp: RareComponent in components:
		if comp.is_acquired() and comp.is_damaged:
			out.append(comp)
	return out

# ── Acquisition ───────────────────────────────────────────────────────────────

func on_component_acquired(component_id: StringName, from_target_id: StringName) -> void:
	var comp := get_component(component_id)
	if not comp:
		return
	comp.quantity_acquired = mini(comp.quantity_acquired + 1, comp.quantity_required)
	comp.acquired_from_heist = from_target_id
	EventBus.rare_component_acquired.emit(component_id, from_target_id)
	EventBus.object_manifest_progress_changed.emit(assembly_progress())

func on_component_damaged(component_id: StringName) -> void:
	var comp := get_component(component_id)
	if not comp:
		return
	comp.is_damaged = true
	EventBus.rare_component_damaged.emit(component_id)

# ── Detection tracking ────────────────────────────────────────────────────────

func record_heist_detection(mission_id: StringName, result: StringName) -> void:
	detection_aggregate[mission_id] = result

func ghost_heist_count() -> int:
	var count := 0
	for id in detection_aggregate:
		if detection_aggregate[id] == &"ghost":
			count += 1
	return count

func clean_run_fraction() -> float:
	if detection_aggregate.is_empty():
		return 1.0
	return float(ghost_heist_count()) / float(detection_aggregate.size())
