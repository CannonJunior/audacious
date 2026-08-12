class_name SegmentRunUI
extends Control
## Runs a selected subset of nodes in sequence and shows cascade failure.
## If a node scores below the FAIL_THRESHOLD, all subsequent nodes in the
## segment are marked as cascade-failed without requiring player input.

signal segment_completed(records: Array)

const FAIL_THRESHOLD: float = 0.55
const AMBER:     Color = Color(1.0,  0.420, 0.0,  1.0)
const TEXT_MAIN: Color = Color(0.85, 0.85,  0.88, 1.0)
const TEXT_DIM:  Color = Color(0.55, 0.55,  0.60, 1.0)
const GOOD_COL:  Color = Color(0.15, 1.0,   0.30, 1.0)
const WARN_COL:  Color = Color(0.90, 0.70,  0.10, 1.0)
const BAD_COL:   Color = Color(1.0,  0.20,  0.08, 1.0)

@onready var _segment_label:  Label         = %SegmentLabel
@onready var _node_flow:      VBoxContainer = %SegmentNodeFlow
@onready var _drill_ui:       ManeuverDrillUI = %SegmentDrillUI
@onready var _result_list:    VBoxContainer = %SegmentResultList
@onready var _cascade_lbl:    Label         = %CascadeWarning
@onready var _btn_start:      Button        = %BtnStartSegment
@onready var _btn_finish:     Button        = %BtnFinishSegment

var _nodes: Array[ManeuverNode] = []
var _current_index: int = 0
var _records: Array = []       # PracticeRecord or null (cascade)
var _cascade_triggered: bool = false

# ── Public ────────────────────────────────────────────────────────────────────

## nodes: the subset of ManeuverNodes the player wants to chain.
func load_segment(nodes: Array[ManeuverNode], label: String = "") -> void:
	_nodes = nodes
	_current_index = 0
	_records.clear()
	_cascade_triggered = false
	_segment_label.text = "SEGMENT RUN: %s" % (label if label != "" else "%d nodes" % nodes.size())
	_result_list.visible = false
	_btn_start.visible = true
	_btn_finish.visible = false
	_cascade_lbl.visible = false
	_drill_ui.visible = false
	_rebuild_flow()

# ── Internal ──────────────────────────────────────────────────────────────────

func _rebuild_flow() -> void:
	for child in _node_flow.get_children():
		child.queue_free()
	for i: int in range(_nodes.size()):
		var lbl := Label.new()
		lbl.text = "[%d] %s" % [i + 1, _nodes[i].label]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color",
			AMBER if i == _current_index else TEXT_DIM
		)
		_node_flow.add_child(lbl)

func _start_segment() -> void:
	_btn_start.visible = false
	_current_index = 0
	_drill_ui.visible = true
	_drill_ui.load_node(_nodes[0])
	_rebuild_flow()

func _on_drill_completed(record: PracticeRecord) -> void:
	_records.append(record)

	if record.overall_score() < FAIL_THRESHOLD:
		_trigger_cascade()
		return

	_current_index += 1
	if _current_index >= _nodes.size():
		_finish()
		return

	_drill_ui.load_node(_nodes[_current_index])
	_rebuild_flow()

func _trigger_cascade() -> void:
	_cascade_triggered = true
	# Fill remaining nodes with null records (cascade)
	for i: int in range(_current_index + 1, _nodes.size()):
		_records.append(null)
	_cascade_lbl.visible = true
	_cascade_lbl.text = "CASCADE FAILURE at [%d] %s — remaining nodes aborted." % [
		_current_index + 1, _nodes[_current_index].label
	]
	_finish()

func _finish() -> void:
	_drill_ui.visible = false
	_result_list.visible = true
	for child in _result_list.get_children():
		child.queue_free()

	for i: int in range(_nodes.size()):
		var rec: PracticeRecord = _records[i] if i < _records.size() else null
		_result_list.add_child(_make_result_row(_nodes[i], rec, i))

	_btn_finish.visible = true
	segment_completed.emit(_records)

func _make_result_row(node: ManeuverNode, rec: PracticeRecord, index: int) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 8 }

	var idx_lbl := Label.new()
	idx_lbl.text = "[%d]" % (index + 1)
	idx_lbl.custom_minimum_size = Vector2(24, 0)
	idx_lbl.add_theme_font_size_override("font_size", 9)
	idx_lbl.add_theme_color_override("font_color", AMBER)
	row.add_child(idx_lbl)

	var name_lbl := Label.new()
	name_lbl.text = node.label
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", TEXT_MAIN if rec else TEXT_DIM)
	row.add_child(name_lbl)

	var score_lbl := Label.new()
	if rec == null:
		score_lbl.text = "CASCADE"
		score_lbl.add_theme_color_override("font_color", BAD_COL)
	else:
		var pct := roundi(rec.overall_score() * 100.0)
		score_lbl.text = "%d%%" % pct
		score_lbl.add_theme_color_override("font_color",
			GOOD_COL if pct >= 80 else WARN_COL if pct >= 55 else BAD_COL
		)
	score_lbl.custom_minimum_size = Vector2(56, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.add_theme_font_size_override("font_size", 10)
	row.add_child(score_lbl)

	return row

# ── Handlers ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_btn_start.pressed.connect(_start_segment)
	_btn_finish.pressed.connect(func():
		_result_list.visible = false
		_btn_finish.visible = false
		_btn_start.text = "RUN AGAIN"
		_btn_start.visible = true
		_current_index = 0
		_records.clear()
		_cascade_triggered = false
		_cascade_lbl.visible = false
		_rebuild_flow()
	)
	_drill_ui.drill_completed.connect(_on_drill_completed)
