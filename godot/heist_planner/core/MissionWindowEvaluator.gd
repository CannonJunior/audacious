class_name MissionWindowEvaluator
extends RefCounted
## Converts raw MissionWindow data into ranked scores weighted by intel confidence.
## Low-confidence windows are discounted — a rumored window is a gamble, not a plan.

class WindowScore:
	var window_id: StringName = &""
	var effective_quality: float = 0.0  # raw quality × confidence weight
	var risk_label: String = ""
	var label: String = ""

## Score one window. Effective quality = quality * confidence_weight.
static func score_window(window: MissionWindow) -> WindowScore:
	var score := WindowScore.new()
	score.window_id = window.window_id
	score.label = window.label

	var confidence_weight: float
	match window.confidence:
		IntelEntry.Confidence.CONFIRMED:  confidence_weight = 1.00
		IntelEntry.Confidence.PROBABLE:   confidence_weight = 0.70
		IntelEntry.Confidence.RUMORED:    confidence_weight = 0.40
		_:                                confidence_weight = 0.10

	score.effective_quality = window.quality * confidence_weight

	if score.effective_quality >= 0.75:
		score.risk_label = "LOW"
	elif score.effective_quality >= 0.45:
		score.risk_label = "MODERATE"
	elif score.effective_quality >= 0.20:
		score.risk_label = "HIGH"
	else:
		score.risk_label = "VERY HIGH"

	return score

## Rank all windows for a target. Returns sorted Array[WindowScore] best-first.
static func rank_windows(windows: Array[MissionWindow]) -> Array[WindowScore]:
	var scores: Array[WindowScore] = []
	for w: MissionWindow in windows:
		scores.append(score_window(w))
	scores.sort_custom(func(a: WindowScore, b: WindowScore) -> bool:
		return a.effective_quality > b.effective_quality
	)
	return scores

## Best effective quality across all windows — used in the risk assessment summary.
static func best_window_quality(windows: Array[MissionWindow]) -> float:
	if windows.is_empty():
		return 0.0
	var scored := rank_windows(windows)
	return scored[0].effective_quality

## True if there is at least one confirmed-or-probable window with quality ≥ 0.5.
static func has_viable_window(windows: Array[MissionWindow]) -> bool:
	for w: MissionWindow in windows:
		var s := score_window(w)
		if s.effective_quality >= 0.5:
			return true
	return false
