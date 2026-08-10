class_name RouteTimingOptimizer
extends RefCounted
## Aligns maneuver node timing to the best available mission window and
## surfaces cascade risk from delay at any given node.

class NodeTimingAdjustment:
	var node_id: StringName = &""
	var proposed_start_seconds: float = 0.0  # from mission clock zero
	var margin_seconds: float = 0.0          # slack before this node becomes infeasible
	var overruns_window: bool = false
	var note: String = ""

## Given a route and its target's windows, assign optimal start times per node.
## Returns Array[NodeTimingAdjustment] in node order.
static func optimize(route: MissionRoute, windows: Array[MissionWindow]) -> Array[NodeTimingAdjustment]:
	var adjustments: Array[NodeTimingAdjustment] = []
	if route.nodes.is_empty():
		return adjustments

	var best_window := _best_window(windows)
	var window_start := 0.0
	var window_end := 9999.0
	var window_label := "unconfirmed"

	if best_window:
		window_start = best_window.game_time_start
		window_end   = best_window.game_time_end
		window_label = best_window.label

	var cursor := window_start
	for node: ManeuverNode in route.nodes:
		var adj := NodeTimingAdjustment.new()
		adj.node_id = node.node_id
		adj.proposed_start_seconds = cursor
		adj.margin_seconds = maxf(0.0, node.timing_window_seconds - node.estimated_duration_seconds)
		adj.overruns_window = (cursor + node.estimated_duration_seconds) > window_end
		adj.note = "Aligned to %s window" % window_label
		if adj.overruns_window:
			adj.note += " [WARNING: exceeds window — reduce prior node durations]"
		adjustments.append(adj)
		cursor += node.estimated_duration_seconds

	return adjustments

## Estimate how a delay at a given node propagates through subsequent nodes.
## Returns Dictionary[StringName → {delay_absorbed: float, excess: float}]
static func estimate_cascade(route: MissionRoute, node_index: int, delay_seconds: float) -> Dictionary:
	var affected: Dictionary = {}
	var remaining := delay_seconds

	for i: int in range(node_index + 1, route.nodes.size()):
		if remaining <= 0.0:
			break
		var node := route.nodes[i]
		var margin := node.timing_margin()
		if remaining > margin:
			affected[node.node_id] = {
				"delay_absorbed": margin,
				"excess": remaining - margin,
			}
			remaining -= margin
		else:
			affected[node.node_id] = {
				"delay_absorbed": remaining,
				"excess": 0.0,
			}
			remaining = 0.0

	return affected

static func _best_window(windows: Array[MissionWindow]) -> MissionWindow:
	var scored := MissionWindowEvaluator.rank_windows(windows)
	if scored.is_empty():
		return null
	var best_id: StringName = scored[0].window_id
	for w: MissionWindow in windows:
		if w.window_id == best_id:
			return w
	return null
