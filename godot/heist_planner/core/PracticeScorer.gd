class_name PracticeScorer
extends RefCounted
## Scores practice attempts, writes PracticeRecords to the node, and generates
## the AI partner's physics-grounded feedback text.

class PracticeFeedback:
	var record: PracticeRecord = null
	var overall_label: String = ""     # "CLEAN" | "GOOD" | "MARGINAL" | "FAILED"
	var position_feedback: String = ""
	var timing_feedback: String = ""
	var noise_feedback: String = ""
	var ai_analysis: String = ""

## Score one practice attempt, appending the record to the node's history.
## Returns feedback with the AI partner's analysis text.
static func score_attempt(
	node: ManeuverNode,
	position_accuracy: float,
	timing_accuracy: float,
	noise_generated: float,
	current_game_time: float
) -> PracticeFeedback:
	var fb := PracticeFeedback.new()

	var record := PracticeRecord.new()
	record.position_accuracy = clampf(position_accuracy, 0.0, 1.0)
	record.timing_accuracy   = clampf(timing_accuracy,   0.0, 1.0)
	record.noise_generated   = clampf(noise_generated,   0.0, 1.0)
	record.timestamp         = current_game_time
	fb.record = record

	node.practice_records.append(record)

	if record.is_clean():
		fb.overall_label = "CLEAN"
	elif record.overall_score() >= 0.70:
		fb.overall_label = "GOOD"
	elif record.overall_score() >= 0.50:
		fb.overall_label = "MARGINAL"
	else:
		fb.overall_label = "FAILED"

	fb.position_feedback = _axis_feedback("Position accuracy", position_accuracy)
	fb.timing_feedback   = _axis_feedback("Timing accuracy",   timing_accuracy)
	fb.noise_feedback    = _axis_feedback("Noise threshold",   noise_generated)
	fb.ai_analysis       = _ai_analysis(node, record)

	EventBus.practice_session_completed.emit(
		&"",           # route_id — caller fills in if needed
		node.node_id
	)

	return fb

## Score a segment run: 2–5 consecutive nodes, detecting cascade failures.
## Returns Dictionary[StringName → {record, cascade_from: StringName, delay: float}]
static func score_segment(
	nodes: Array[ManeuverNode],
	records: Array[PracticeRecord],
	current_game_time: float
) -> Dictionary:
	var results: Dictionary = {}
	var cumulative_delay := 0.0

	for i: int in range(mini(nodes.size(), records.size())):
		var node := nodes[i]
		var record := records[i]
		record.timestamp = current_game_time
		node.practice_records.append(record)

		var cascade_from: StringName = &""
		if i > 0 and cumulative_delay > 0.5:
			cascade_from = nodes[i - 1].node_id

		# A missed timing window adds proportional delay to subsequent nodes
		var excess := maxf(0.0, node.estimated_duration_seconds - record.timing_accuracy * node.timing_window_seconds)
		cumulative_delay += excess

		results[node.node_id] = {
			"record": record,
			"cascade_from": cascade_from,
			"delay_accumulated": cumulative_delay,
		}

	return results

# ── Internal ──────────────────────────────────────────────────────────────────

static func _axis_feedback(axis: String, value: float) -> String:
	if value >= 0.90:  return "%s: excellent" % axis
	if value >= 0.75:  return "%s: good" % axis
	if value >= 0.55:  return "%s: marginal — needs work" % axis
	return "%s: poor" % axis

static func _ai_analysis(node: ManeuverNode, record: PracticeRecord) -> String:
	if record.timing_accuracy < 0.60:
		var late_seconds := (1.0 - record.timing_accuracy) * node.timing_window_seconds
		return "Launch %.1fs late relative to optimal. At this node's velocity, that's %.1fm of extra arc to compensate. Initiate the move as soon as the trigger condition clears." % [late_seconds, late_seconds * 8.0]
	if record.position_accuracy < 0.70:
		return "Landing position drifted — adjust entry angle to tighten the arc."
	if record.noise_generated < 0.70:
		var timing_note := "earlier — current timing is close" if record.timing_accuracy < 0.80 else "at current timing"
		return "Impact noise exceeds threshold. Engage dampeners %s before touchdown." % timing_note
	return "Performance within acceptable margins. Additional runs build consistency."
