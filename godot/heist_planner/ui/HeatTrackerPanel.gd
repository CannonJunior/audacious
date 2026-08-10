class_name HeatTrackerPanel
extends PanelContainer
## Left-sidebar panel. Shows per-target heat levels and city-wide alert state.
## Red is semantic here — the only place in the heist planner UI where red appears.

const TEXT_DIM:    Color = Color(0.55, 0.55, 0.60, 1.0)
const TEXT_MAIN:   Color = Color(0.85, 0.85, 0.88, 1.0)
const HEAT_NONE:   Color = Color(0.25, 0.30, 0.35, 1.0)
const HEAT_LOW:    Color = Color(0.30, 0.80, 0.40, 1.0)
const HEAT_ELEV:   Color = Color(0.90, 0.70, 0.10, 1.0)
const HEAT_HIGH:   Color = Color(1.00, 0.45, 0.05, 1.0)
const HEAT_HOT:    Color = Color(1.00, 0.15, 0.08, 1.0)

@onready var _heat_list:      VBoxContainer = %HeatList
@onready var _city_label:     Label         = %CityAlertLabel
@onready var _empty_label:    Label         = %EmptyLabel

# ── Public ────────────────────────────────────────────────────────────────────

func refresh() -> void:
	for child in _heat_list.get_children():
		child.queue_free()

	var hot_targets := HeatSystem.get_hot_targets()
	_empty_label.visible = hot_targets.is_empty()

	for entry: Dictionary in hot_targets:
		var target := GameRegistry.get_heist_target(entry.target_id)
		var display_name := target.display_name if target else entry.target_id
		_heat_list.add_child(_make_heat_row(display_name, entry.target_id, entry.heat))

	# City-wide alert (WorldStateManager faction alerts aggregated)
	var city_max := 0.0
	for faction: int in WorldStateManager.faction_states.keys():
		var state: WorldStateManager.FactionState = WorldStateManager.faction_states[faction]
		city_max = maxf(city_max, state.alert_level)

	_city_label.text = "CITY-WIDE: %s" % _tier_label_from_heat(city_max)
	_city_label.add_theme_color_override("font_color", _heat_color(city_max))

# ── Internal ──────────────────────────────────────────────────────────────────

func _make_heat_row(display_name: String, target_id: StringName, heat: float) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 6 }

	var name_lbl := Label.new()
	name_lbl.text = display_name.left(22)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", TEXT_MAIN)
	row.add_child(name_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(60, 10)
	bar.value = heat * 100.0
	bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = _heat_color(heat)
	style.corner_radius_top_left     = 2
	style.corner_radius_top_right    = 2
	style.corner_radius_bottom_left  = 2
	style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", style)
	row.add_child(bar)

	var tier_lbl := Label.new()
	tier_lbl.text = HeatSystem.get_heat_tier(target_id).to_upper()
	tier_lbl.custom_minimum_size = Vector2(56, 0)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tier_lbl.add_theme_font_size_override("font_size", 9)
	tier_lbl.add_theme_color_override("font_color", _heat_color(heat))
	row.add_child(tier_lbl)

	return row

func _heat_color(heat: float) -> Color:
	if heat <= 0.0:                             return HEAT_NONE
	if heat < HeatSystem.THRESHOLD_LOW:         return HEAT_LOW
	if heat < HeatSystem.THRESHOLD_ELEVATED:    return HEAT_ELEV
	if heat < HeatSystem.THRESHOLD_HIGH:        return HEAT_HIGH
	return HEAT_HOT

func _tier_label_from_heat(heat: float) -> String:
	if heat <= 0.0:                             return "NOMINAL"
	if heat < HeatSystem.THRESHOLD_LOW:         return "LOW"
	if heat < HeatSystem.THRESHOLD_ELEVATED:    return "ELEVATED"
	if heat < HeatSystem.THRESHOLD_HIGH:        return "HIGH"
	return "HOT"
