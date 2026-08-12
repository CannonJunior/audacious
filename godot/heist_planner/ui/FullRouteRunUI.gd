class_name FullRouteRunUI
extends Control
## Simulates a complete route run including the evasion addendum.
## Tracks cumulative endurance draw and shows a ghost/recovered/failed outcome.
## Uses PracticeScorer for each node; power draw from node ghost_risk proxy.

signal run_completed(detection: int, node_scores: Dictionary)

const ENDURANCE_WARN: float = 0.25   # warn when endurance drops below this
const FAIL_THRESHOLD: float = 0.50   # node score below this = detection risk
const AMBER:     Color = Color(1.0,  0.420, 0.0,  1.0)
const TEXT_MAIN: Color = Color(0.85, 0.85,  0.88, 1.0)
const TEXT_DIM:  Color = Color(0.55, 0.55,  0.60, 1.0)
const GOOD_COL:  Color = Color(0.15, 1.0,   0.30, 1.0)
const WARN_COL:  Color = Color(0.90, 0.70,  0.10, 1.0)
const BAD_COL:   Color = Color(1.0,  0.20,  0.08, 1.0)

@onready var _route_label:      Label         = %FullRouteLabel
@onready var _endurance_bar:    ProgressBar   = %EnduranceBar
@onready var _endurance_lbl:    Label         = %EnduranceLabel
@onready var _power_warning:    Label         = %PowerWarning
@onready var _drill_ui:         ManeuverDrillUI = %FullDrillUI
@onready var _node_progress:    Label         = %FullNodeProgress
@onready var _result_list:      VBoxContainer = %FullResultList
@onready var _outcome_lbl:      Label         = %FullOutcomeLabel
@onready var _btn_start:        Button        = %BtnStartFullRun
@onready var _btn_finish:       Button        = %BtnFinishFullRun

var _route: MissionRoute = null
var _all_nodes: Array[ManeuverNode] = []  # main + evasion flattened
var _current_index: int = 0
var _node_scores: Dictionary = {}         # node_id → float
var _endurance: float = 1.0
var _base_endurance: float = 1.0

# ── Public ────────────────────────────────────────────────────────────────────

func load_route(route: MissionRoute, endurance_stat: float = 1.0) -> void:
	_route = route
	_base_endurance = clampf(endurance_stat, 0.1, 1.0)
	_endurance = _base_endurance
	_node_scores.clear()
	_all_nodes.clear()
	for node: ManeuverNode in route.nodes:
		_all_nodes.append(node)
	if route.evasion:
		for node: ManeuverNode in route.evasion.evasion_nodes:
			_all_nodes.append(node)

	_route_label.text = "FULL ROUTE RUN: %s" % route.route_id
	_current_index = 0
	_result_list.visible = false
	_outcome_lbl.visible = false
	_btn_start.visible = true
	_btn_finish.visible = false
	_drill_ui.visible = false
	_update_endurance_bar()
	_update_progress()

# ── Internal ──────────────────────────────────────────────────────────────────

func _start_run() -> void:
	_btn_start.visible = false
	_current_index = 0
	_endurance = _base_endurance
	_node_scores.clear()
	_drill_ui.visible = true
	_drill_ui.load_node(_all_nodes[0])
	_update_endurance_bar()
	_update_progress()

func _on_drill_completed(record: PracticeRecord) -> void:
	var node: ManeuverNode = _all_nodes[_current_index]
	var score := record.overall_score()
	_node_scores[node.node_id] = score

	# Endurance drains proportional to ghost_risk * duration weight
	var drain := node.ghost_risk * (node.estimated_duration_seconds / 20.0) * 0.5
	_endurance = maxf(0.0, _endurance - drain)
	_update_endurance_bar()

	_current_index += 1
	if _current_index >= _all_nodes.size():
		_finish_run()
		return

	_drill_ui.load_node(_all_nodes[_current_index])
	_update_progress()

func _finish_run() -> void:
	_drill_ui.visible = false
	var detection := _determine_outcome()
	_show_results(detection)
	run_completed.emit(detection, _node_scores)

func _determine_outcome() -> int:
	# Count nodes that scored below FAIL_THRESHOLD
	var fail_count := 0
	for score: float in _node_scores.values():
		if score < FAIL_THRESHOLD:
			fail_count += 1
	if fail_count == 0 and _endurance > ENDURANCE_WARN:
		return MissionRoute.DetectionRecord.GHOST
	elif fail_count <= 1 or _endurance > 0.0:
		return MissionRoute.DetectionRecord.RECOVERED
	return MissionRoute.DetectionRecord.FAILED

func _show_results(detection: int) -> void:
	_result_list.visible = true
	for child in _result_list.get_children():
		child.queue_free()

	for node: ManeuverNode in _all_nodes:
		var score: float = _node_scores.get(node.node_id, 0.0)
		var row := HBoxContainer.new()
		row.theme_override_constants = { "separation": 8 }

		var name_lbl := Label.new()
		name_lbl.text = node.label
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", TEXT_MAIN)
		row.add_child(name_lbl)

		var pct_lbl := Label.new()
		var pct := roundi(score * 100.0)
		pct_lbl.text = "%d%%" % pct
		pct_lbl.custom_minimum_size = Vector2(36, 0)
		pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct_lbl.add_theme_font_size_override("font_size", 10)
		pct_lbl.add_theme_color_override("font_color",
			GOOD_COL if pct >= 80 else WARN_COL if pct >= 55 else BAD_COL
		)
		row.add_child(pct_lbl)
		_result_list.add_child(row)

	_outcome_lbl.visible = true
	match detection:
		MissionRoute.DetectionRecord.GHOST:
			_outcome_lbl.text = "GHOST — UNDETECTED"
			_outcome_lbl.add_theme_color_override("font_color", GOOD_COL)
		MissionRoute.DetectionRecord.RECOVERED:
			_outcome_lbl.text = "RECOVERED — alert suppressed"
			_outcome_lbl.add_theme_color_override("font_color", WARN_COL)
		_:
			_outcome_lbl.text = "DETECTED — mission blown"
			_outcome_lbl.add_theme_color_override("font_color", BAD_COL)

	_btn_finish.visible = true

func _update_endurance_bar() -> void:
	_endurance_bar.value = _endurance * 100.0
	_endurance_lbl.text = "%d%%" % roundi(_endurance * 100.0)
	var style := StyleBoxFlat.new()
	style.bg_color = GOOD_COL if _endurance > 0.5 else WARN_COL if _endurance > ENDURANCE_WARN else BAD_COL
	style.corner_radius_top_left     = 2
	style.corner_radius_top_right    = 2
	style.corner_radius_bottom_left  = 2
	style.corner_radius_bottom_right = 2
	_endurance_bar.add_theme_stylebox_override("fill", style)
	_power_warning.visible = _endurance <= ENDURANCE_WARN

func _update_progress() -> void:
	if _all_nodes.is_empty():
		_node_progress.text = ""
		return
	_node_progress.text = "Node %d / %d" % [_current_index + 1, _all_nodes.size()]

# ── Handlers ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_btn_start.pressed.connect(_start_run)
	_btn_finish.pressed.connect(func():
		_result_list.visible = false
		_outcome_lbl.visible = false
		_btn_finish.visible = false
		_btn_start.text = "RUN AGAIN"
		_btn_start.visible = true
		_endurance = _base_endurance
		_update_endurance_bar()
		_current_index = 0
		_node_scores.clear()
		_update_progress()
	)
	_drill_ui.drill_completed.connect(_on_drill_completed)
	_power_warning.text = "⚠ LOW ENDURANCE — detection risk rising"
	_power_warning.add_theme_color_override("font_color", BAD_COL)
	_power_warning.add_theme_font_size_override("font_size", 9)
