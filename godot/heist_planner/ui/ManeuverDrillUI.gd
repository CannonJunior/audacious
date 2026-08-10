class_name ManeuverDrillUI
extends Control
## Interactive drill interface for a single ManeuverNode. The player inputs
## three accuracy values (position, timing, noise) representing how well they
## executed the maneuver. PracticeScorer grades the attempt and records it.

signal drill_completed(record: PracticeRecord)

const AMBER:     Color = Color(1.0,  0.420, 0.0,  1.0)
const TEXT_MAIN: Color = Color(0.85, 0.85,  0.88, 1.0)
const TEXT_DIM:  Color = Color(0.55, 0.55,  0.60, 1.0)
const GOOD_COL:  Color = Color(0.15, 1.0,   0.30, 1.0)
const WARN_COL:  Color = Color(0.90, 0.70,  0.10, 1.0)
const BAD_COL:   Color = Color(1.0,  0.20,  0.08, 1.0)

@onready var _node_name_lbl:   Label        = %DrillNodeName
@onready var _node_type_lbl:   Label        = %DrillNodeType
@onready var _timing_info:     Label        = %DrillTimingInfo
@onready var _pos_slider:      HSlider      = %PositionSlider
@onready var _timing_slider:   HSlider      = %TimingSlider
@onready var _noise_slider:    HSlider      = %NoiseSlider
@onready var _pos_lbl:         Label        = %PositionValue
@onready var _timing_lbl:      Label        = %TimingValue
@onready var _noise_lbl:       Label        = %NoiseValue
@onready var _feedback_box:    VBoxContainer = %FeedbackBox
@onready var _feedback_lbl:    Label        = %FeedbackLabel
@onready var _ai_analysis_lbl: Label        = %AiAnalysisLabel
@onready var _btn_submit:      Button       = %BtnSubmitDrill
@onready var _btn_retry:       Button       = %BtnRetryDrill
@onready var _result_area:     Control      = %DrillResultArea

var _current_node: ManeuverNode = null

# ── Public ────────────────────────────────────────────────────────────────────

func load_node(node: ManeuverNode) -> void:
	_current_node = node
	_node_name_lbl.text = node.label.to_upper()
	_node_type_lbl.text = ManeuverNode.ManeuverType.keys()[node.maneuver_type]
	_timing_info.text = "Window: %.0fs  |  Duration: %.0fs  |  Margin: %.1fs" % [
		node.timing_window_seconds, node.estimated_duration_seconds, node.timing_margin()
	]
	var stars := node.mastery_stars()
	_node_type_lbl.add_theme_color_override("font_color",
		AMBER if stars >= 3 else WARN_COL if stars >= 1 else TEXT_DIM
	)
	_pos_slider.value = 0.8
	_timing_slider.value = 0.8
	_noise_slider.value = 0.8
	_update_slider_labels()
	_result_area.visible = false
	_btn_retry.visible = false
	_btn_submit.visible = true
	_feedback_box.visible = false

# ── Internal ──────────────────────────────────────────────────────────────────

func _update_slider_labels() -> void:
	_pos_lbl.text    = "%d%%" % roundi(_pos_slider.value    * 100.0)
	_timing_lbl.text = "%d%%" % roundi(_timing_slider.value * 100.0)
	_noise_lbl.text  = "%d%%" % roundi(_noise_slider.value  * 100.0)

	_pos_lbl.add_theme_color_override("font_color",    _accuracy_color(_pos_slider.value))
	_timing_lbl.add_theme_color_override("font_color", _accuracy_color(_timing_slider.value))
	_noise_lbl.add_theme_color_override("font_color",  _accuracy_color(_noise_slider.value))

func _accuracy_color(v: float) -> Color:
	if v >= 0.85: return GOOD_COL
	if v >= 0.65: return WARN_COL
	return BAD_COL

func _submit_drill() -> void:
	if not _current_node:
		return
	var feedback := PracticeScorer.score_attempt(
		_current_node,
		_pos_slider.value,
		_timing_slider.value,
		_noise_slider.value,
		Time.get_ticks_msec() / 1000.0
	)
	_show_result(feedback)
	drill_completed.emit(feedback.record)

func _show_result(feedback: PracticeScorer.PracticeFeedback) -> void:
	_btn_submit.visible = false
	_result_area.visible = true
	_feedback_box.visible = true
	_btn_retry.visible = true

	var col: Color
	match feedback.overall_label:
		"CLEAN":    col = GOOD_COL
		"GOOD":     col = WARN_COL
		_:          col = BAD_COL

	_feedback_lbl.text = feedback.overall_label
	_feedback_lbl.add_theme_color_override("font_color", col)

	var detail := PackedStringArray()
	if feedback.position_feedback != "":
		detail.append(feedback.position_feedback)
	if feedback.timing_feedback != "":
		detail.append(feedback.timing_feedback)
	if feedback.noise_feedback != "":
		detail.append(feedback.noise_feedback)

	_ai_analysis_lbl.text = feedback.ai_analysis if feedback.ai_analysis != "" else " · ".join(detail)
	_ai_analysis_lbl.add_theme_color_override("font_color", AMBER if feedback.overall_label == "CLEAN" else TEXT_DIM)

# ── Handlers ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_btn_submit.pressed.connect(_submit_drill)
	_btn_retry.pressed.connect(func():
		_result_area.visible = false
		_btn_retry.visible = false
		_feedback_box.visible = false
		_btn_submit.visible = true
	)
	_pos_slider.value_changed.connect(func(_v): _update_slider_labels())
	_timing_slider.value_changed.connect(func(_v): _update_slider_labels())
	_noise_slider.value_changed.connect(func(_v): _update_slider_labels())
	for slider: HSlider in [_pos_slider, _timing_slider, _noise_slider]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
