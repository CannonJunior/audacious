class_name ObjectManifestPanel
extends PanelContainer
## Left-sidebar panel. Shows RARE assembly progress and the list of components
## still needed. Clicking a component's source target selects it for planning.

const AMBER:      Color = Color(1.0,   0.420, 0.0,  1.0)
const TEXT_MAIN:  Color = Color(0.85,  0.85,  0.88, 1.0)
const TEXT_DIM:   Color = Color(0.55,  0.55,  0.60, 1.0)
const STATUS_OK:  Color = Color(0.15,  1.0,   0.30, 1.0)
const STATUS_BAD: Color = Color(0.60,  0.60,  0.65, 1.0)
const DMG_COLOR:  Color = Color(1.0,   0.55,  0.0,  1.0)

signal target_selected(target: HeistTarget)
signal upgrade_selected(opp: UpgradeOpportunity)

@onready var _object_label:     Label        = %ObjectLabel
@onready var _progress_bar:     ProgressBar  = %AssemblyProgress
@onready var _progress_label:   Label        = %ProgressLabel
@onready var _components_list:  VBoxContainer = %ComponentsList
@onready var _rec_section:      VBoxContainer = %RecommendationSection
@onready var _rec_list:         VBoxContainer = %RecommendationList

var _manifest: ObjectManifest = null

# ── Public ────────────────────────────────────────────────────────────────────

func populate(manifest: ObjectManifest) -> void:
	_manifest = manifest
	_object_label.text = manifest.object_name.to_upper()
	_refresh_progress()
	_refresh_components()

func refresh_recommendations(recs: Array) -> void:
	for child in _rec_list.get_children():
		child.queue_free()
	var shown := 0
	for rec: RecommendationEngine.Recommendation in recs:
		if shown >= 4:
			break
		_rec_list.add_child(_make_rec_row(rec))
		shown += 1
	_rec_section.visible = shown > 0

# ── Internal ──────────────────────────────────────────────────────────────────

func _refresh_progress() -> void:
	if not _manifest:
		return
	var pct := _manifest.assembly_progress()
	_progress_bar.value = pct * 100.0
	_progress_label.text = "%d%%" % roundi(pct * 100.0)

	var style := StyleBoxFlat.new()
	style.bg_color = AMBER if pct < 1.0 else STATUS_OK
	style.corner_radius_top_left     = 2
	style.corner_radius_top_right    = 2
	style.corner_radius_bottom_left  = 2
	style.corner_radius_bottom_right = 2
	_progress_bar.add_theme_stylebox_override("fill", style)

func _refresh_components() -> void:
	for child in _components_list.get_children():
		child.queue_free()
	if not _manifest:
		return
	for comp: RareComponent in _manifest.components:
		_components_list.add_child(_make_component_row(comp))

func _make_component_row(comp: RareComponent) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 6 }

	var status_lbl := Label.new()
	if comp.is_acquired() and not comp.is_damaged:
		status_lbl.text = "✓"
		status_lbl.add_theme_color_override("font_color", STATUS_OK)
	elif comp.is_damaged:
		status_lbl.text = "⚠"
		status_lbl.add_theme_color_override("font_color", DMG_COLOR)
	else:
		status_lbl.text = "✗"
		status_lbl.add_theme_color_override("font_color", STATUS_BAD)
	status_lbl.custom_minimum_size = Vector2(14, 0)
	status_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(status_lbl)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = comp.display_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", TEXT_MAIN)
	name_col.add_child(name_lbl)

	if comp.quantity_required > 1:
		var qty_lbl := Label.new()
		qty_lbl.text = "%d / %d" % [comp.quantity_acquired, comp.quantity_required]
		qty_lbl.add_theme_font_size_override("font_size", 9)
		qty_lbl.add_theme_color_override("font_color", TEXT_DIM)
		name_col.add_child(qty_lbl)

	row.add_child(name_col)

	if not comp.is_acquired() and comp.source_target_id != &"":
		var btn := Button.new()
		btn.text = "→"
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_component_target_pressed.bind(comp.source_target_id))
		row.add_child(btn)

	return row

func _make_rec_row(rec: RecommendationEngine.Recommendation) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 6 }

	var lbl := Label.new()
	lbl.text = rec.action_label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", AMBER if rec.time_sensitive else TEXT_DIM)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(lbl)

	if rec.target_id != &"":
		var btn := Button.new()
		btn.text = "GO"
		btn.add_theme_font_size_override("font_size", 10)
		btn.custom_minimum_size = Vector2(36, 0)
		btn.pressed.connect(_on_rec_go_pressed.bind(rec))
		row.add_child(btn)

	return row

func _on_component_target_pressed(target_id: StringName) -> void:
	var target := GameRegistry.get_heist_target(target_id)
	if target:
		target_selected.emit(target)

func _on_rec_go_pressed(rec: RecommendationEngine.Recommendation) -> void:
	if rec.upgrade_id != &"":
		var opp := UpgradeBoardManager.board.get_opportunity(rec.upgrade_id)
		if opp:
			upgrade_selected.emit(opp)
	elif rec.target_id != &"":
		_on_component_target_pressed(rec.target_id)
