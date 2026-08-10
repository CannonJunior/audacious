class_name PracticeModeController
extends Control
## Wraps ManeuverDrillUI and orchestrates practice sessions for a route.
## Emits session_completed when the player finishes or quits a drill run.

signal session_completed(records: Array)

const AMBER:     Color = Color(1.0,  0.420, 0.0,  1.0)
const TEXT_MAIN: Color = Color(0.85, 0.85,  0.88, 1.0)
const TEXT_DIM:  Color = Color(0.55, 0.55,  0.60, 1.0)
const GOOD_COL:  Color = Color(0.15, 1.0,   0.30, 1.0)
const BAD_COL:   Color = Color(1.0,  0.20,  0.08, 1.0)

@onready var _route_label:      Label             = %RouteLabel
@onready var _node_progress:    Label             = %NodeProgressLabel
@onready var _drill_ui:         ManeuverDrillUI   = %ManeuverDrillUI
@onready var _session_summary:  VBoxContainer     = %SessionSummary
@onready var _summary_list:     VBoxContainer     = %SummaryList
@onready var _btn_start:        Button            = %BtnStartSession
@onready var _btn_next:         Button            = %BtnNextNode
@onready var _btn_finish:       Button            = %BtnFinishSession

var _route: MissionRoute = null
var _capability_tags: Array = []
var _current_node_index: int = 0
var _session_records: Array = []  # Array[PracticeRecord]

# ── Public ────────────────────────────────────────────────────────────────────

func load_route(route: MissionRoute, capability_tags: Array) -> void:
	_route = route
	_capability_tags = capability_tags
	_current_node_index = 0
	_session_records.clear()
	_route_label.text = "PRACTICE: %s" % route.route_id
	_session_summary.visible = false
	_drill_ui.visible = false
	_btn_start.visible = true
	_btn_next.visible = false
	_btn_finish.visible = false
	_update_progress_label()

# ── Internal ──────────────────────────────────────────────────────────────────

func _update_progress_label() -> void:
	if not _route:
		_node_progress.text = ""
		return
	_node_progress.text = "Node %d / %d" % [_current_node_index + 1, _route.nodes.size()]

func _start_session() -> void:
	if not _route or _route.nodes.is_empty():
		return
	_current_node_index = 0
	_session_records.clear()
	_btn_start.visible = false
	_session_summary.visible = false
	_drill_ui.visible = true
	_btn_next.visible = false
	_btn_finish.visible = false
	_load_current_node()

func _load_current_node() -> void:
	if _current_node_index >= _route.nodes.size():
		_finish_session()
		return
	var node: ManeuverNode = _route.nodes[_current_node_index]
	_drill_ui.load_node(node)
	_update_progress_label()

func _finish_session() -> void:
	_drill_ui.visible = false
	_btn_next.visible = false
	_btn_finish.visible = false
	_session_summary.visible = true
	_populate_summary()
	session_completed.emit(_session_records)

func _populate_summary() -> void:
	for child in _summary_list.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "SESSION COMPLETE"
	header.add_theme_color_override("font_color", AMBER)
	header.add_theme_font_size_override("font_size", 12)
	_summary_list.add_child(header)

	for i: int in range(_route.nodes.size()):
		var node: ManeuverNode = _route.nodes[i]
		var record: PracticeRecord = _session_records[i] if i < _session_records.size() else null
		_summary_list.add_child(_make_summary_row(node, record))

	# Recommend weakest node for extra practice
	var weak := _route.get_weak_nodes()
	if not weak.is_empty():
		var rec_lbl := Label.new()
		rec_lbl.text = "Focus: %s needs more practice." % weak[0].label
		rec_lbl.add_theme_color_override("font_color", AMBER)
		rec_lbl.add_theme_font_size_override("font_size", 9)
		rec_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_summary_list.add_child(rec_lbl)

	_btn_start.text = "PRACTICE AGAIN"
	_btn_start.visible = true

func _make_summary_row(node: ManeuverNode, record: PracticeRecord) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 8 }

	var name_lbl := Label.new()
	name_lbl.text = node.label
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", TEXT_MAIN)
	row.add_child(name_lbl)

	var stars := node.mastery_stars()
	var star_lbl := Label.new()
	star_lbl.text = "★".repeat(stars) + "☆".repeat(5 - stars)
	star_lbl.add_theme_color_override("font_color", AMBER if stars > 0 else TEXT_DIM)
	star_lbl.add_theme_font_size_override("font_size", 10)
	row.add_child(star_lbl)

	if record:
		var score_lbl := Label.new()
		var score := roundi(record.overall_score() * 100.0)
		score_lbl.text = "%d%%" % score
		score_lbl.custom_minimum_size = Vector2(36, 0)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_lbl.add_theme_font_size_override("font_size", 10)
		score_lbl.add_theme_color_override("font_color", GOOD_COL if score >= 80 else BAD_COL)
		row.add_child(score_lbl)

	return row

# ── Handlers ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_btn_start.pressed.connect(_start_session)
	_btn_next.pressed.connect(_on_next_node)
	_btn_finish.pressed.connect(_finish_session)
	_drill_ui.drill_completed.connect(_on_drill_completed)

func _on_drill_completed(record: PracticeRecord) -> void:
	_session_records.append(record)
	if _current_node_index >= _route.nodes.size() - 1:
		_btn_next.visible = false
		_btn_finish.visible = true
	else:
		_btn_next.visible = true
		_btn_finish.visible = false

func _on_next_node() -> void:
	_current_node_index += 1
	_btn_next.visible = false
	_load_current_node()
