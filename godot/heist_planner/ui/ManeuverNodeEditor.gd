class_name ManeuverNodeEditor
extends PanelContainer
## Inline editor for a single ManeuverNode. Appears below the node list when
## the player clicks a node card. Emits node_changed when any field is committed.

signal node_changed(node: ManeuverNode)
signal editor_closed()

const AMBER:     Color = Color(1.0,  0.420, 0.0,  1.0)
const TEXT_MAIN: Color = Color(0.85, 0.85,  0.88, 1.0)
const TEXT_DIM:  Color = Color(0.55, 0.55,  0.60, 1.0)
const WARN_COL:  Color = Color(0.90, 0.70,  0.10, 1.0)

@onready var _label_edit:       LineEdit    = %NodeLabelEdit
@onready var _type_option:      OptionButton = %NodeTypeOption
@onready var _window_spin:      SpinBox     = %TimingWindowSpin
@onready var _duration_spin:    SpinBox     = %EstDurationSpin
@onready var _ghost_risk_spin:  SpinBox     = %GhostRiskSpin
@onready var _caps_edit:        LineEdit    = %CapabilitiesEdit
@onready var _margin_lbl:       Label       = %MarginLabel
@onready var _btn_apply:        Button      = %BtnApplyNode
@onready var _btn_close:        Button      = %BtnCloseEditor

var _node: ManeuverNode = null

# ── Public ────────────────────────────────────────────────────────────────────

func load_node(node: ManeuverNode) -> void:
	_node = node
	_label_edit.text = node.label
	_type_option.selected = node.maneuver_type
	_window_spin.value = node.timing_window_seconds
	_duration_spin.value = node.estimated_duration_seconds
	_ghost_risk_spin.value = node.ghost_risk * 100.0
	_caps_edit.text = ", ".join(node.required_capabilities)
	_update_margin()
	visible = true

# ── Internal ──────────────────────────────────────────────────────────────────

func _update_margin() -> void:
	if not _node:
		return
	var margin := _window_spin.value - _duration_spin.value
	_margin_lbl.text = "Margin: %.1fs" % margin
	_margin_lbl.add_theme_color_override("font_color",
		TEXT_DIM if margin >= 1.0 else WARN_COL if margin >= 0.0 else Color(1.0, 0.2, 0.08, 1.0)
	)

func _apply() -> void:
	if not _node:
		return
	_node.label = _label_edit.text.strip_edges()
	_node.maneuver_type = _type_option.selected as ManeuverNode.ManeuverType
	_node.timing_window_seconds = _window_spin.value
	_node.estimated_duration_seconds = _duration_spin.value
	_node.ghost_risk = _ghost_risk_spin.value / 100.0
	_node.required_capabilities.clear()
	for cap in _caps_edit.text.split(","):
		var trimmed := cap.strip_edges()
		if trimmed != "":
			_node.required_capabilities.append(trimmed)
	node_changed.emit(_node)

# ── Handlers ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false
	_btn_apply.pressed.connect(_apply)
	_btn_close.pressed.connect(func():
		visible = false
		editor_closed.emit()
	)
	_window_spin.value_changed.connect(func(_v): _update_margin())
	_duration_spin.value_changed.connect(func(_v): _update_margin())

	for t: String in ManeuverNode.ManeuverType.keys():
		_type_option.add_item(t)

	_window_spin.min_value   = 1.0
	_window_spin.max_value   = 120.0
	_window_spin.step        = 0.5
	_duration_spin.min_value = 0.5
	_duration_spin.max_value = 60.0
	_duration_spin.step      = 0.5
	_ghost_risk_spin.min_value = 0.0
	_ghost_risk_spin.max_value = 100.0
	_ghost_risk_spin.step    = 1.0
	_ghost_risk_spin.suffix  = "%"
