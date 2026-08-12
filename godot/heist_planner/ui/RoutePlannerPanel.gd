class_name RoutePlannerPanel
extends Control
## Route planning panel. Left: 3D city SubViewport (placeholder until city geometry
## exists). Right: node list editor where the player places and configures
## ManeuverNodes. Bottom: timeline and AI partner analysis.

const AMBER:      Color = Color(1.0,   0.420, 0.0,  1.0)
const TEXT_MAIN:  Color = Color(0.85,  0.85,  0.88, 1.0)
const TEXT_DIM:   Color = Color(0.55,  0.55,  0.60, 1.0)
const FEASIBLE:   Color = Color(0.15,  1.0,   0.30, 1.0)
const INFEASIBLE: Color = Color(1.0,   0.20,  0.08, 1.0)
const RARE_SHIMM: Color = Color(0.85,  0.75,  1.0,  1.0)

signal route_saved(route: MissionRoute)
signal practice_requested()

@onready var _approach_label:   Label              = %ApproachLabel
@onready var _node_list:        VBoxContainer      = %NodeList
@onready var _evasion_section:  Control            = %EvasionSection
@onready var _evasion_node_list:VBoxContainer      = %EvasionNodeList
@onready var _timeline_bar:     TimelineBar        = %TimelineBar
@onready var _ai_panel:         AIPartnerPanel     = %AIPartnerPanel
@onready var _city_viewport:    CitySceneViewport  = %CitySceneViewport
@onready var _route_renderer:   RouteLineRenderer  = %RouteLineRenderer
@onready var _node_editor:      ManeuverNodeEditor = %ManeuverNodeEditor
@onready var _btn_add_node:     Button             = %BtnAddNode
@onready var _btn_save:         Button             = %BtnSaveRoute
@onready var _btn_practice:     Button             = %BtnPractice
@onready var _btn_run_sim:      Button             = %BtnRunSim
@onready var _cargo_warning:    Label              = %CargoWarning
@onready var _rare_warning:     Label              = %RareWarning

var _target: HeistTarget = null
var _route: MissionRoute = null
var _capability_tags: Array = []
var _feasibility: Dictionary = {}     # node_id → NodeFeasibility
var _selected_node: ManeuverNode = null

# ── Public ────────────────────────────────────────────────────────────────────

func load_target(target: HeistTarget, route: MissionRoute, capability_tags: Array) -> void:
	_target = target
	_route = route
	_capability_tags = capability_tags
	_selected_node = null
	_approach_label.text = "APPROACH: %s" % (route.approach_id if route.approach_id != &"" else "NONE SELECTED")
	_recheck_feasibility()
	_refresh_node_list()
	_refresh_evasion()
	_timeline_bar.load_route(route)
	_route_renderer.load_route(route)
	_node_editor.visible = false
	_ai_panel.clear()

func set_carrying_rare(rare: RareComponent) -> void:
	_recheck_feasibility(rare)
	_refresh_node_list()
	_route_renderer.load_route(_route, rare != null)
	var issues := AIPartnerAdvisor.check_rare_transport(_route, rare)
	_rare_warning.visible = not issues.is_empty()
	_rare_warning.text = "RARE TRANSPORT: " + " | ".join(issues)

# ── Internal ──────────────────────────────────────────────────────────────────

func _recheck_feasibility(rare: RareComponent = null) -> void:
	if not _route:
		_feasibility = {}
		return
	var cargo: CargoProfile = rare.build_cargo_profile() if rare else null
	var carrying := rare != null
	_feasibility = ManeuverFeasibilityChecker.check_route(_route, _capability_tags, cargo, carrying)

func _refresh_node_list() -> void:
	for child in _node_list.get_children():
		child.queue_free()
	if not _route:
		return
	for i: int in range(_route.nodes.size()):
		var node := _route.nodes[i]
		var feasibility: ManeuverFeasibilityChecker.NodeFeasibility = _feasibility.get(node.node_id)
		_node_list.add_child(_make_node_card(node, i, feasibility))

func _refresh_evasion() -> void:
	_evasion_section.visible = _route != null and _route.evasion != null
	if not _route or not _route.evasion:
		return
	for child in _evasion_node_list.get_children():
		child.queue_free()
	for node: ManeuverNode in _route.evasion.evasion_nodes:
		var f: ManeuverFeasibilityChecker.NodeFeasibility = _feasibility.get(node.node_id)
		_evasion_node_list.add_child(_make_node_card(node, -1, f))

func _make_node_card(node: ManeuverNode, index: int, feasibility: ManeuverFeasibilityChecker.NodeFeasibility) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_node_card_clicked(node)
	)
	var inner := VBoxContainer.new()
	inner.theme_override_constants = { "separation": 3 }
	card.add_child(inner)

	# Header row
	var header := HBoxContainer.new()

	var num_lbl := Label.new()
	num_lbl.text = "[%d]" % (index + 1) if index >= 0 else "[E]"
	num_lbl.custom_minimum_size = Vector2(28, 0)
	num_lbl.add_theme_font_size_override("font_size", 9)
	num_lbl.add_theme_color_override("font_color", AMBER if index >= 0 else RARE_SHIMM)
	header.add_child(num_lbl)

	var type_lbl := Label.new()
	type_lbl.text = ManeuverNode.ManeuverType.keys()[node.maneuver_type]
	type_lbl.custom_minimum_size = Vector2(72, 0)
	type_lbl.add_theme_font_size_override("font_size", 9)
	type_lbl.add_theme_color_override("font_color", TEXT_DIM)
	header.add_child(type_lbl)

	var label_lbl := Label.new()
	label_lbl.text = node.label
	label_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_lbl.add_theme_font_size_override("font_size", 11)
	label_lbl.add_theme_color_override("font_color", TEXT_MAIN)
	header.add_child(label_lbl)

	# Mastery stars
	var stars_lbl := Label.new()
	var stars := node.mastery_stars()
	stars_lbl.text = "★".repeat(stars) + "☆".repeat(5 - stars)
	stars_lbl.add_theme_font_size_override("font_size", 10)
	stars_lbl.add_theme_color_override("font_color", AMBER if stars > 0 else TEXT_DIM)
	header.add_child(stars_lbl)

	# Feasibility indicator
	var ok_lbl := Label.new()
	if feasibility:
		ok_lbl.text = "OK" if feasibility.is_feasible else "!"
		ok_lbl.add_theme_color_override("font_color", FEASIBLE if feasibility.is_feasible else INFEASIBLE)
	header.add_child(ok_lbl)

	inner.add_child(header)

	# Issues
	if feasibility and not feasibility.is_feasible:
		var all_issues: Array[String] = []
		all_issues.append_array(feasibility.missing_capabilities)
		if feasibility.cargo_issue != "":
			all_issues.append(feasibility.cargo_issue)
		all_issues.append_array(feasibility.rare_issues)
		var issue_lbl := Label.new()
		issue_lbl.text = " · ".join(all_issues)
		issue_lbl.add_theme_font_size_override("font_size", 9)
		issue_lbl.add_theme_color_override("font_color", INFEASIBLE)
		issue_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		inner.add_child(issue_lbl)

	# Timing margin
	var timing_row := HBoxContainer.new()
	var margin_lbl := Label.new()
	margin_lbl.text = "Margin: %.1fs  |  Window: %.0fs  |  Duration: %.0fs" % [
		node.timing_margin(), node.timing_window_seconds, node.estimated_duration_seconds
	]
	margin_lbl.add_theme_font_size_override("font_size", 9)
	margin_lbl.add_theme_color_override("font_color", TEXT_DIM if node.timing_margin() >= 1.0 else Color(1.0, 0.55, 0.0, 1.0))
	timing_row.add_child(margin_lbl)

	# Warnings
	if feasibility and not feasibility.warnings.is_empty():
		var warn_lbl := Label.new()
		warn_lbl.text = "  ⚠ " + feasibility.warnings[0]
		warn_lbl.add_theme_font_size_override("font_size", 9)
		warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0, 1.0))
		timing_row.add_child(warn_lbl)

	inner.add_child(timing_row)

	return card

# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_node_card_clicked(node: ManeuverNode) -> void:
	_selected_node = node
	_node_editor.load_node(node)

func _ready() -> void:
	_btn_add_node.pressed.connect(_on_add_node)
	_btn_save.pressed.connect(_on_save)
	_btn_practice.pressed.connect(func(): practice_requested.emit())
	_btn_run_sim.pressed.connect(_on_run_simulation)
	_cargo_warning.visible = false
	_rare_warning.visible = false
	_node_editor.node_changed.connect(_on_node_edited)
	_node_editor.editor_closed.connect(func(): _selected_node = null)

func _on_node_edited(node: ManeuverNode) -> void:
	_recheck_feasibility()
	_refresh_node_list()
	_timeline_bar.load_route(_route)
	_route_renderer.load_route(_route)

func _on_add_node() -> void:
	if not _route:
		return
	var node := ManeuverNode.new()
	node.node_id = "node_%d" % _route.nodes.size()
	node.label = "Node %d" % (_route.nodes.size() + 1)
	node.maneuver_type = ManeuverNode.ManeuverType.TRANSIT
	node.timing_window_seconds = 5.0
	node.estimated_duration_seconds = 3.0
	_route.nodes.append(node)
	_recheck_feasibility()
	_refresh_node_list()
	_timeline_bar.load_route(_route)

func _on_save() -> void:
	if _route:
		route_saved.emit(_route)
		_btn_save.text = "SAVED ✓"
		get_tree().create_timer(1.5).timeout.connect(func(): _btn_save.text = "SAVE ROUTE")

func _on_run_simulation() -> void:
	if not _route:
		return
	var report := AIPartnerAdvisor.stress_simulate(_route, _capability_tags)
	_ai_panel.show_stress_report(report)
