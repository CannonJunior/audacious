class_name MissionDebriefPanel
extends PanelContainer
## Post-execution debrief. Displays detection outcome, per-node performance,
## heat change, and the updated object manifest entry for the stolen/secured item.

const AMBER:     Color = Color(1.0,  0.420, 0.0,  1.0)
const TEXT_MAIN: Color = Color(0.85, 0.85,  0.88, 1.0)
const TEXT_DIM:  Color = Color(0.55, 0.55,  0.60, 1.0)
const GOOD_COL:  Color = Color(0.15, 1.0,   0.30, 1.0)
const WARN_COL:  Color = Color(0.90, 0.70,  0.10, 1.0)
const BAD_COL:   Color = Color(1.0,  0.20,  0.08, 1.0)

@onready var _outcome_lbl:     Label         = %OutcomeLabel
@onready var _heat_change_lbl: Label         = %HeatChangeLabel
@onready var _node_results:    VBoxContainer = %DebriefNodeList
@onready var _manifest_row:    Control       = %ManifestUpdateRow
@onready var _manifest_lbl:    Label         = %ManifestUpdateLabel
@onready var _recommendation:  Label         = %DebriefRecommendation
@onready var _btn_close:       Button        = %BtnCloseDebrief

signal debrief_closed()

# ── Public ────────────────────────────────────────────────────────────────────

## Call after a mission run completes.
## detection: MissionRoute.DetectionRecord enum value
## node_scores: Dictionary { node_id: StringName → float (0–1 success) }
## heat_delta: how much heat was added (may be 0 for ghost)
## acquired_component: RareComponent or null if this run secured it
func show_debrief(
	route: MissionRoute,
	detection: int,
	node_scores: Dictionary,
	heat_delta: float,
	acquired_component: RareComponent
) -> void:
	_outcome_lbl.text = _detection_label(detection)
	_outcome_lbl.add_theme_color_override("font_color", _detection_color(detection))

	if heat_delta > 0.0:
		_heat_change_lbl.text = "+%.0f%% HEAT" % (heat_delta * 100.0)
		_heat_change_lbl.add_theme_color_override("font_color", BAD_COL)
	else:
		_heat_change_lbl.text = "NO HEAT ADDED"
		_heat_change_lbl.add_theme_color_override("font_color", GOOD_COL)

	for child in _node_results.get_children():
		child.queue_free()
	for node: ManeuverNode in route.nodes:
		var score: float = node_scores.get(node.node_id, 0.0)
		_node_results.add_child(_make_node_row(node, score))

	if acquired_component:
		_manifest_row.visible = true
		_manifest_lbl.text = "ACQUIRED: %s" % acquired_component.component_id
		_manifest_lbl.add_theme_color_override("font_color", GOOD_COL)
	else:
		_manifest_row.visible = false

	_recommendation.text = _build_recommendation(detection, route)

# ── Internal ──────────────────────────────────────────────────────────────────

func _make_node_row(node: ManeuverNode, score: float) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 8 }

	var name_lbl := Label.new()
	name_lbl.text = node.label
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", TEXT_MAIN)
	row.add_child(name_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(80, 10)
	bar.value = score * 100.0
	bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = GOOD_COL if score >= 0.80 else WARN_COL if score >= 0.55 else BAD_COL
	style.corner_radius_top_left     = 2
	style.corner_radius_top_right    = 2
	style.corner_radius_bottom_left  = 2
	style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", style)
	row.add_child(bar)

	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % roundi(score * 100.0)
	pct_lbl.custom_minimum_size = Vector2(34, 0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct_lbl.add_theme_font_size_override("font_size", 10)
	pct_lbl.add_theme_color_override("font_color", GOOD_COL if score >= 0.80 else BAD_COL)
	row.add_child(pct_lbl)

	return row

func _detection_label(d: int) -> String:
	match d:
		MissionRoute.DetectionRecord.GHOST:     return "GHOST RUN — UNDETECTED"
		MissionRoute.DetectionRecord.RECOVERED: return "RECOVERED — ALERT SUPPRESSED"
		MissionRoute.DetectionRecord.FAILED:    return "DETECTED — MISSION BLOWN"
	return "NOT RUN"

func _detection_color(d: int) -> Color:
	match d:
		MissionRoute.DetectionRecord.GHOST:     return GOOD_COL
		MissionRoute.DetectionRecord.RECOVERED: return WARN_COL
		MissionRoute.DetectionRecord.FAILED:    return BAD_COL
	return TEXT_DIM

func _build_recommendation(detection: int, route: MissionRoute) -> String:
	if detection == MissionRoute.DetectionRecord.GHOST:
		return "Perfect execution. Route is proven — ready for the real run."
	if detection == MissionRoute.DetectionRecord.RECOVERED:
		var weak := route.get_weak_nodes()
		if not weak.is_empty():
			return "Alert triggered at %s. Practice this node to prevent recurrence." % weak[0].label
		return "Alert triggered but suppressed. Review timing margins before re-attempting."
	return "Mission detected. Allow heat to decay before re-engaging this target."

# ── Handlers ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_btn_close.pressed.connect(func(): debrief_closed.emit())
