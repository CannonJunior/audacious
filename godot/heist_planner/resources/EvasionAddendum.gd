class_name EvasionAddendum
extends Resource
## The pre-planned chase sequence that branches off the primary route
## if discovery occurs. Designed around asymmetric advantages the suit
## has over pursuers — geometry they can't follow.

const ManeuverNode = preload("res://heist_planner/resources/ManeuverNode.gd")
const TransitSegment = preload("res://heist_planner/resources/TransitSegment.gd")

## The node in the primary route where the player commits to this path.
@export var separation_point_node_id: StringName = &""
@export var trigger_condition: String = "Any alarm activation"

@export var evasion_nodes: Array[ManeuverNode] = []
@export var evasion_segments: Array[TransitSegment] = []

## Tasks the AI partner executes during evasion (camera loops, vehicle intercept, etc.).
@export var ai_tasks: Array[String] = []

@export var ghost_impact_note: String = ""     # what detection means for the run
@export var recovery_risk_note: String = ""    # how hard recovery is from this addendum
