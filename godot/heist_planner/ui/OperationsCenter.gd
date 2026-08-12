class_name OperationsCenter
extends Control
## Root hub for all pre-mission planning. Opened with the "open_mission_board" input.
## Owns the manifest, active routes, and active suit capability tags.
## Coordinates navigation between the four planning phases.

# ── Color palette ─────────────────────────────────────────────────────────────
const BG:          Color = Color(0.039, 0.039, 0.059, 1.0)
const AMBER:       Color = Color(1.0,   0.420, 0.0,   1.0)
const TEXT_DIM:    Color = Color(0.55,  0.55,  0.60,  1.0)
const TEXT_MAIN:   Color = Color(0.85,  0.85,  0.88,  1.0)
const SEP_COLOR:   Color = Color(0.18,  0.18,  0.22,  1.0)

enum Tab { MANIFEST, DOSSIER, ROUTE, PRACTICE, DEBRIEF }

# ── Nodes ─────────────────────────────────────────────────────────────────────

@onready var _manifest_panel:  ObjectManifestPanel  = %ObjectManifestPanel
@onready var _heat_panel:      HeatTrackerPanel     = %HeatTrackerPanel
@onready var _dossier_panel:   HeistPlannerPanel    = %HeistPlannerPanel
@onready var _route_panel:     RoutePlannerPanel    = %RoutePlannerPanel
@onready var _practice_panel:  PracticeModeController = %PracticeModeController
@onready var _debrief_panel:   MissionDebriefPanel  = %MissionDebriefPanel
@onready var _upgrade_popup:   UpgradePreviewPopup   = %UpgradePreviewPopup
@onready var _rec_bar:         RecommendationBar     = %RecommendationBar

@onready var _btn_manifest:    Button = %BtnManifest
@onready var _btn_dossier:     Button = %BtnDossier
@onready var _btn_route:       Button = %BtnRoute
@onready var _btn_practice:    Button = %BtnPractice
@onready var _target_label:    Label  = %ActiveTargetLabel

# ── State ─────────────────────────────────────────────────────────────────────

var manifest: ObjectManifest = ObjectManifest.new()
var routes: Dictionary = {}              # StringName(target_id) → MissionRoute
var active_capability_tags: Array = []   # String[]; set from active suit

var _active_target: HeistTarget = null
var _active_panel: Tab = Tab.MANIFEST

const MANIFEST_SAVE = "user://object_manifest.tres"
const ROUTES_SAVE   = "user://mission_routes.cfg"

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_manifest()
	_load_routes()
	_connect_panels()
	_wire_nav_buttons()
	_switch_panel(Tab.MANIFEST)
	visible = false

	EventBus.heist_target_heat_changed.connect(_on_heat_changed)
	EventBus.rare_component_acquired.connect(_on_component_acquired)
	EventBus.recommendation_list_updated.connect(_on_recommendations_updated)



func _set_visible(show: bool) -> void:
	visible = show
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED
	if show:
		_refresh_manifest()
		_rebuild_recommendations()

# ── Public: target selection ──────────────────────────────────────────────────

func select_target(target: HeistTarget) -> void:
	_active_target = target
	_target_label.text = target.display_name if target else "No target selected"
	_btn_dossier.disabled = target == null
	_btn_route.disabled   = target == null
	_btn_practice.disabled = target == null or not routes.has(target.target_id)
	if target:
		_switch_panel(Tab.DOSSIER)

func select_target_by_id(target_id: StringName) -> void:
	select_target(GameRegistry.get_heist_target(target_id))

# ── Public: route management ──────────────────────────────────────────────────

func get_or_create_route(target_id: StringName) -> MissionRoute:
	if not routes.has(target_id):
		var r := MissionRoute.new()
		r.route_id = target_id
		r.target_id = target_id
		routes[target_id] = r
	return routes[target_id]

func save_route(route: MissionRoute) -> void:
	routes[route.target_id] = route
	EventBus.mission_route_saved.emit(route.route_id)
	_save_routes()
	_btn_practice.disabled = false

# ── Navigation ────────────────────────────────────────────────────────────────

func go_to_dossier() -> void:
	_switch_panel(Tab.DOSSIER)

func go_to_route() -> void:
	if _active_target:
		_route_panel.load_target(_active_target, get_or_create_route(_active_target.target_id), active_capability_tags)
	_switch_panel(Tab.ROUTE)

func go_to_practice() -> void:
	if _active_target and routes.has(_active_target.target_id):
		_practice_panel.load_route(routes[_active_target.target_id], active_capability_tags)
	_switch_panel(Tab.PRACTICE)

func show_debrief(route: MissionRoute, detection: int, node_scores: Dictionary, heat_delta: float, acquired: RareComponent) -> void:
	_debrief_panel.show_debrief(route, detection, node_scores, heat_delta, acquired)
	_switch_panel(Tab.DEBRIEF)

func show_upgrade_preview(opp: UpgradeOpportunity) -> void:
	_upgrade_popup.show_opportunity(opp)
	_upgrade_popup.visible = true

# ── Internal: panel switching ─────────────────────────────────────────────────

func _switch_panel(p: int) -> void:
	_active_panel = p
	if _dossier_panel:   _dossier_panel.visible  = p == Tab.DOSSIER
	if _route_panel:     _route_panel.visible    = p == Tab.ROUTE
	if _practice_panel:  _practice_panel.visible = p == Tab.PRACTICE
	if _debrief_panel:   _debrief_panel.visible  = p == Tab.DEBRIEF
	# MANIFEST panel is always visible in the left sidebar, not the main area

	if _btn_manifest: _btn_manifest.button_pressed = p == Tab.MANIFEST
	if _btn_dossier:  _btn_dossier.button_pressed  = p == Tab.DOSSIER
	if _btn_route:    _btn_route.button_pressed    = p == Tab.ROUTE
	if _btn_practice: _btn_practice.button_pressed = p == Tab.PRACTICE

	if p == Tab.DOSSIER and _active_target and _dossier_panel:
		_dossier_panel.load_target(_active_target, active_capability_tags)
	if p == Tab.ROUTE and _active_target and _route_panel:
		_route_panel.load_target(_active_target, get_or_create_route(_active_target.target_id), active_capability_tags)

# ── Internal: wiring ──────────────────────────────────────────────────────────

func _connect_panels() -> void:
	if _manifest_panel:
		_manifest_panel.target_selected.connect(select_target)
		_manifest_panel.upgrade_selected.connect(show_upgrade_preview)
	if _dossier_panel:
		_dossier_panel.approach_confirmed.connect(_on_approach_confirmed)
		_dossier_panel.recon_requested.connect(_on_recon_requested)
	if _route_panel:
		_route_panel.route_saved.connect(save_route)
		_route_panel.practice_requested.connect(go_to_practice)
	if _practice_panel:
		_practice_panel.session_completed.connect(_on_session_completed)
	if _debrief_panel:
		_debrief_panel.debrief_closed.connect(func(): _switch_panel(Tab.MANIFEST))
	if _upgrade_popup:
		_upgrade_popup.upgrade_committed.connect(_on_upgrade_committed)
		_upgrade_popup.upgrade_dismissed.connect(func(): _upgrade_popup.hide_popup())

func _wire_nav_buttons() -> void:
	_btn_manifest.pressed.connect(func(): _switch_panel(Tab.MANIFEST))
	_btn_dossier.pressed.connect(func(): _switch_panel(Tab.DOSSIER))
	_btn_route.pressed.connect(go_to_route)
	_btn_practice.pressed.connect(go_to_practice)
	var btn_close := get_node_or_null("%BtnClose")
	if btn_close:
		btn_close.pressed.connect(func(): _set_visible(false))

# ── Internal: signal handlers ─────────────────────────────────────────────────

func _on_approach_confirmed(approach: ApproachOption) -> void:
	if _active_target:
		var route := get_or_create_route(_active_target.target_id)
		route.approach_id = approach.approach_id
		_route_panel.load_target(_active_target, route, active_capability_tags)
	_switch_panel(Tab.ROUTE)

func _on_recon_requested(target: HeistTarget) -> void:
	# Recon is a lightweight mission — start it via QuestEngine with a generated blueprint
	if target:
		AIAgent.request_line(&"recon_briefing", { "target_id": target.target_id })

func _on_session_completed(_records: Array) -> void:
	_switch_panel(Tab.ROUTE)

func _on_upgrade_committed(_opp: UpgradeOpportunity) -> void:
	_refresh_manifest()
	_rebuild_recommendations()

func _on_heat_changed(_target_id: StringName, _heat: float) -> void:
	_heat_panel.refresh()

func _on_component_acquired(_component_id: StringName, _from_target_id: StringName) -> void:
	_refresh_manifest()
	_rebuild_recommendations()

func _on_recommendations_updated(recs: Array) -> void:
	_rec_bar.refresh(recs)

# ── Internal: data ────────────────────────────────────────────────────────────

func _refresh_manifest() -> void:
	if _manifest_panel: _manifest_panel.populate(manifest)
	if _heat_panel:     _heat_panel.refresh()

func _rebuild_recommendations() -> void:
	if UpgradeBoardManager.board == null:
		return
	RecommendationEngine.rebuild(manifest, UpgradeBoardManager.board, routes)

# ── Persistence ───────────────────────────────────────────────────────────────

func _load_manifest() -> void:
	if ResourceLoader.exists(MANIFEST_SAVE):
		var loaded := ResourceLoader.load(MANIFEST_SAVE)
		if loaded is ObjectManifest:
			manifest = loaded
	else:
		manifest = ObjectManifest.create_seed()
		ResourceSaver.save(manifest, MANIFEST_SAVE)
	_manifest_panel.populate(manifest)

func _load_routes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ROUTES_SAVE) != OK:
		return
	if not cfg.has_section("routes"):
		return
	for target_id: String in cfg.get_section_keys("routes"):
		var path: String = cfg.get_value("routes", target_id, "")
		if ResourceLoader.exists(path):
			var r := ResourceLoader.load(path)
			if r is MissionRoute:
				routes[target_id as StringName] = r

func _save_routes() -> void:
	var cfg := ConfigFile.new()
	for target_id: StringName in routes.keys():
		var r: MissionRoute = routes[target_id]
		var path := "user://route_%s.tres" % target_id
		ResourceSaver.save(r, path)
		cfg.set_value("routes", target_id, path)
	cfg.save(ROUTES_SAVE)
