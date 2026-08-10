class_name TransitSegment
extends Resource
## Simple movement between two ManeuverNodes — sprinting, grappling, surface riding.
## The player defines the waypoints; physics simulation handles the path.

@export var segment_id: StringName = &""
@export var from_node_id: StringName = &""
@export var to_node_id: StringName = &""
@export var waypoints: Array[Vector3] = []
@export var notes: String = ""

func estimated_distance() -> float:
	if waypoints.size() < 2:
		return 0.0
	var total := 0.0
	for i: int in range(1, waypoints.size()):
		total += waypoints[i - 1].distance_to(waypoints[i])
	return total
