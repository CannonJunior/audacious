extends Node
## Campaign arc management. Tracks mission unlocks, heist arc progress,
## and the MacGuffin technology assembly chain.

const MissionBlueprint = preload("res://data/MissionBlueprint.gd")

var active_mission_id: StringName = &""
var current_arc_index: int = 0           # which heist arc we're in
var completed_mission_ids: Array = []    # Array[StringName]

func _ready() -> void:
	pass

# ── Mission availability ───────────────────────────────────────────────────────

func is_mission_available(mission_id: StringName) -> bool:
	var blueprint: MissionBlueprint = GameRegistry.get_mission(mission_id)
	if not blueprint:
		return false
	if mission_id in completed_mission_ids:
		return false
	for req: StringName in blueprint.prerequisite_mission_ids:
		if req not in completed_mission_ids:
			return false
	return true

func get_available_missions() -> Array:
	return GameRegistry.missions.keys().filter(
		func(id: StringName) -> bool: return is_mission_available(id)
	)

# ── Mission lifecycle ─────────────────────────────────────────────────────────

func start_mission(mission_id: StringName) -> void:
	var blueprint: MissionBlueprint = GameRegistry.get_mission(mission_id)
	if not blueprint:
		push_error("QuestEngine: unknown mission '%s'" % mission_id)
		return
	active_mission_id = mission_id
	AIAgent.begin_mission(blueprint)
	EventBus.mission_started.emit(mission_id)

func complete_mission(mission_id: StringName) -> void:
	if mission_id not in completed_mission_ids:
		completed_mission_ids.append(mission_id)
	if mission_id == active_mission_id:
		active_mission_id = &""
	var blueprint: MissionBlueprint = GameRegistry.get_mission(mission_id)
	if blueprint and blueprint.surveillance_increment > 0.0:
		WorldStateManager.increment_surveillance(blueprint.surveillance_increment)
	EventBus.mission_completed.emit(mission_id)

func fail_mission(mission_id: StringName, reason: StringName) -> void:
	if mission_id == active_mission_id:
		active_mission_id = &""
	EventBus.mission_failed.emit(mission_id, reason)

# ── MacGuffin tracking ────────────────────────────────────────────────────────

func on_handoff_completed(component_id: StringName, location: Vector3) -> void:
	WorldStateManager.hand_off_component(component_id)
	EventBus.handoff_completed.emit(component_id, location)
