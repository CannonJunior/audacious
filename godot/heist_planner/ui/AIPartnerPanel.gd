class_name AIPartnerPanel
extends PanelContainer
## Shows the AI partner's route stress analysis, approach suggestions,
## and node-level failure mode breakdown.

const AMBER:      Color = Color(1.0,   0.420, 0.0,  1.0)
const TEXT_MAIN:  Color = Color(0.85,  0.85,  0.88, 1.0)
const TEXT_DIM:   Color = Color(0.55,  0.55,  0.60, 1.0)
const GOOD_COL:   Color = Color(0.15,  1.0,   0.30, 1.0)
const WARN_COL:   Color = Color(0.90,  0.70,  0.10, 1.0)
const BAD_COL:    Color = Color(1.0,   0.20,  0.08, 1.0)

@onready var _header_lbl:     Label         = %AIPartnerHeader
@onready var _content:        VBoxContainer = %AIContent
@onready var _idle_lbl:       Label         = %IdleLabel
@onready var _overall_lbl:    Label         = %OverallSuccessLabel
@onready var _node_results:   VBoxContainer = %NodeResultsList
@onready var _suggestions:    VBoxContainer = %SuggestionsList

# ── Public ────────────────────────────────────────────────────────────────────

func clear() -> void:
	_idle_lbl.visible = true
	_overall_lbl.visible = false
	_node_results.visible = false
	_suggestions.visible = false
	for child in _node_results.get_children():
		child.queue_free()
	for child in _suggestions.get_children():
		child.queue_free()

func show_stress_report(report: AIPartnerAdvisor.RouteStressReport) -> void:
	_idle_lbl.visible = false
	_overall_lbl.visible = true
	_node_results.visible = true
	_suggestions.visible = true

	var overall_pct := roundi(report.overall_success_rate * 100.0)
	_overall_lbl.text = "Route stress: %d%% overall success" % overall_pct
	_overall_lbl.add_theme_color_override("font_color",
		GOOD_COL if overall_pct >= 70 else WARN_COL if overall_pct >= 45 else BAD_COL
	)

	for child in _node_results.get_children():
		child.queue_free()
	for child in _suggestions.get_children():
		child.queue_free()

	for result: AIPartnerAdvisor.NodeStressResult in report.node_results:
		_node_results.add_child(_make_node_result_row(result, result.node_id == report.weakest_node_id))
		if not result.suggestions.is_empty() and result.node_id == report.weakest_node_id:
			for s: String in result.suggestions:
				var lbl := Label.new()
				lbl.text = "  → " + s
				lbl.add_theme_font_size_override("font_size", 9)
				lbl.add_theme_color_override("font_color", AMBER)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				_suggestions.add_child(lbl)

func show_approach_suggestions(suggestions: Array) -> void:
	_idle_lbl.visible = false
	_suggestions.visible = true
	for child in _suggestions.get_children():
		child.queue_free()
	for s: AIPartnerAdvisor.ApproachSuggestion in suggestions:
		_suggestions.add_child(_make_approach_suggestion(s))

# ── Row builders ──────────────────────────────────────────────────────────────

func _make_node_result_row(result: AIPartnerAdvisor.NodeStressResult, is_weakest: bool) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 6 }

	var id_lbl := Label.new()
	id_lbl.text = result.node_id
	id_lbl.custom_minimum_size = Vector2(90, 0)
	id_lbl.add_theme_font_size_override("font_size", 10)
	id_lbl.add_theme_color_override("font_color", BAD_COL if is_weakest else TEXT_DIM)
	row.add_child(id_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(80, 10)
	bar.value = result.success_rate * 100.0
	bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = GOOD_COL if result.success_rate >= 0.80 else WARN_COL if result.success_rate >= 0.55 else BAD_COL
	style.corner_radius_top_left     = 2
	style.corner_radius_top_right    = 2
	style.corner_radius_bottom_left  = 2
	style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", style)
	row.add_child(bar)

	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % roundi(result.success_rate * 100.0)
	pct_lbl.custom_minimum_size = Vector2(32, 0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct_lbl.add_theme_font_size_override("font_size", 10)
	pct_lbl.add_theme_color_override("font_color", GOOD_COL if result.success_rate >= 0.80 else BAD_COL)
	row.add_child(pct_lbl)

	if result.primary_failure_mode != "":
		var fail_lbl := Label.new()
		fail_lbl.text = "← " + result.primary_failure_mode
		fail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fail_lbl.add_theme_font_size_override("font_size", 9)
		fail_lbl.add_theme_color_override("font_color", BAD_COL)
		fail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(fail_lbl)

	return row

func _make_approach_suggestion(s: AIPartnerAdvisor.ApproachSuggestion) -> Control:
	var row := HBoxContainer.new()

	var prob_lbl := Label.new()
	prob_lbl.text = "%d%% ghost" % roundi(s.ghost_probability * 100.0)
	prob_lbl.custom_minimum_size = Vector2(80, 0)
	prob_lbl.add_theme_font_size_override("font_size", 10)
	prob_lbl.add_theme_color_override("font_color", GOOD_COL if s.ghost_probability >= 0.70 else WARN_COL)
	row.add_child(prob_lbl)

	var label_lbl := Label.new()
	label_lbl.text = s.approach.label
	label_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_lbl.add_theme_font_size_override("font_size", 10)
	label_lbl.add_theme_color_override("font_color", TEXT_MAIN)
	row.add_child(label_lbl)

	return row

func _ready() -> void:
	clear()
