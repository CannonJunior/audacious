class_name MissionRoute
extends Resource
## The player's fully designed route for a specific target: primary nodes,
## transit segments between them, and an evasion addendum.

const ManeuverNode = preload("res://heist_planner/resources/ManeuverNode.gd")
const TransitSegment = preload("res://heist_planner/resources/TransitSegment.gd")
const EvasionAddendum = preload("res://heist_planner/resources/EvasionAddendum.gd")

enum DetectionRecord { NOT_RUN, GHOST, RECOVERED, FAILED }

@export var route_id: StringName = &""
@export var target_id: StringName = &""
@export var approach_id: StringName = &""       # which ApproachOption this implements

@export var nodes: Array[ManeuverNode] = []
@export var segments: Array[TransitSegment] = []
@export var evasion: EvasionAddendum = null

@export var detection_record: DetectionRecord = DetectionRecord.NOT_RUN
@export var last_practice_game_time: float = 0.0
@export var last_execution_game_time: float = 0.0

# ── Accessors ─────────────────────────────────────────────────────────────────

func get_node(node_id: StringName) -> ManeuverNode:
	for node: ManeuverNode in nodes:
		if node.node_id == node_id:
			return node
	return null

func get_segment(from_node_id: StringName) -> TransitSegment:
	for seg: TransitSegment in segments:
		if seg.from_node_id == from_node_id:
			return seg
	return null

## 0.0–1.0 fraction of nodes at ≥ 3 mastery stars.
func overall_mastery() -> float:
	if nodes.is_empty():
		return 0.0
	var proficient := 0
	for node: ManeuverNode in nodes:
		if node.mastery_stars() >= 3:
			proficient += 1
	return float(proficient) / float(nodes.size())

func get_weak_nodes() -> Array[ManeuverNode]:
	var weak: Array[ManeuverNode] = []
	for node: ManeuverNode in nodes:
		if node.mastery_stars() < 3:
			weak.append(node)
	return weak

func total_estimated_duration() -> float:
	var total := 0.0
	for node: ManeuverNode in nodes:
		total += node.estimated_duration_seconds
	return total
