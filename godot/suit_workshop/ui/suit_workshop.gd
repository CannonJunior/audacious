class_name SuitWorkshop
extends Control

const SLOT_LABELS: Dictionary = {
	SuitPartResource.Slot.CHASSIS:         "CHASSIS",
	SuitPartResource.Slot.POWER_CORE:      "POWER CORE",
	SuitPartResource.Slot.THRUSTER_PACK:   "THRUSTERS",
	SuitPartResource.Slot.ACTUATOR_SUITE:  "ACTUATORS",
	SuitPartResource.Slot.SENSOR_ARRAY:    "SENSORS",
	SuitPartResource.Slot.ARMOR_HEAD:      "ARMOR – HEAD",
	SuitPartResource.Slot.ARMOR_TORSO:     "ARMOR – TORSO",
	SuitPartResource.Slot.ARMOR_LEFT_ARM:  "ARMOR – L ARM",
	SuitPartResource.Slot.ARMOR_RIGHT_ARM: "ARMOR – R ARM",
	SuitPartResource.Slot.ARMOR_LEFT_LEG:  "ARMOR – L LEG",
	SuitPartResource.Slot.ARMOR_RIGHT_LEG: "ARMOR – R LEG",
	SuitPartResource.Slot.WEAPON_PRIMARY:  "WEAPON – PRIMARY",
	SuitPartResource.Slot.WEAPON_SECONDARY:"WEAPON – SECONDARY",
}

@onready var _viewer:           SuitViewer3D         = %SuitViewer3D
@onready var _slots_grid:       GridContainer        = %SlotsGrid
@onready var _bar_speed:        StatBarUI            = %BarSpeed
@onready var _bar_boost:        StatBarUI            = %BarBoost
@onready var _bar_armor:        StatBarUI            = %BarArmor
@onready var _bar_load:         StatBarUI            = %BarLoad
@onready var _flight_label:     Label                = %FlightLabel
@onready var _warnings_box:     VBoxContainer        = %WarningsBox
@onready var _viewport_ctr:     SubViewportContainer = %ViewportContainer
@onready var _primary_picker:   ColorPickerButton    = %PrimaryPicker
@onready var _secondary_picker: ColorPickerButton    = %SecondaryPicker
@onready var _accent_picker:    ColorPickerButton    = %AccentPicker

var _config:      SuitConfiguration = null
var _slot_uis:    Dictionary        = {}   # SuitPartResource.Slot → ComponentSlotUI
var _active_slot: int               = -1
var _part_picker: PartPicker        = null


func _ready() -> void:
	_build_slot_grid()
	_viewport_ctr.gui_input.connect(_on_viewport_input)
	EventBus.configuration_changed.connect(_on_configuration_changed)

	_primary_picker.color_changed.connect(func(c): _on_color_changed())
	_secondary_picker.color_changed.connect(func(c): _on_color_changed())
	_accent_picker.color_changed.connect(func(c): _on_color_changed())

	var picker_scene: PackedScene = preload("res://suit_workshop/scenes/PartPicker.tscn")
	_part_picker = picker_scene.instantiate() as PartPicker
	add_child(_part_picker)
	_part_picker.part_picked.connect(_on_part_picked)

	visible = false


func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event.is_action_pressed("open_garage"):
		visible = not visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_mission_board"):
		var ops := get_parent().get_node_or_null("OperationsCenter")
		if ops:
			ops.visible = not ops.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ops.visible else Input.MOUSE_MODE_CAPTURED
		else:
			push_error("SuitWorkshop: OperationsCenter not found in HUD — check console for load errors")
		get_viewport().set_input_as_handled()


# ── Public API ────────────────────────────────────────────────────────────────

func load_configuration(cfg: SuitConfiguration) -> void:
	_config = cfg
	_refresh_all()


# ── Internal: build UI ────────────────────────────────────────────────────────

func _build_slot_grid() -> void:
	var slot_scene := preload("res://suit_workshop/scenes/ComponentSlot.tscn")
	for slot: SuitPartResource.Slot in SLOT_LABELS:
		var slot_ui: ComponentSlotUI = slot_scene.instantiate()
		_slots_grid.add_child(slot_ui)
		slot_ui.configure(slot, SLOT_LABELS[slot])
		slot_ui.slot_selected.connect(_on_slot_selected)
		slot_ui.slot_change_requested.connect(_on_slot_change_requested)
		slot_ui.slot_clear_requested.connect(_on_slot_clear_requested)
		_slot_uis[slot as int] = slot_ui


# ── Internal: refresh ─────────────────────────────────────────────────────────

func _refresh_all() -> void:
	if _config == null:
		return
	_refresh_slots()
	_refresh_stats()
	_refresh_viewer()
	_refresh_color_pickers()


func _refresh_slots() -> void:
	for slot_int in _slot_uis:
		var ui: ComponentSlotUI = _slot_uis[slot_int]
		var part: SuitPartResource = _config.get_part(slot_int as SuitPartResource.Slot)
		if part:
			ui.populate(part)
		else:
			ui.clear_display()
		ui.set_selected(slot_int == _active_slot)


func _refresh_stats() -> void:
	if _config == null:
		return
	var s: SuitStats = _config.get_stats()

	_bar_speed.set_stat(s.ground_sprint_speed, SuitStats.MAX_GROUND_SPEED, "m/s")
	_bar_boost.set_stat(s.boost_speed,         SuitStats.MAX_BOOST_SPEED,  "m/s")
	_bar_armor.set_stat(s.armor_points,        200.0,                      "AP")
	_bar_load.set_stat(s.load_ratio,           1.0,                        "")

	if not s.flight_available:
		_flight_label.text = "FLIGHT: OVERLOADED"
		_flight_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif s.max_flight_altitude == INF:
		_flight_label.text = "FLIGHT: ∞ UNLIMITED"
		_flight_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
	else:
		_flight_label.text = "FLIGHT CEIL: %.0f m" % s.max_flight_altitude
		_flight_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

	_refresh_warnings(s)


func _refresh_viewer() -> void:
	if _viewer == null or not _viewer._is_loaded:
		return
	_viewer.clear_all_highlights()
	for slot_int in _slot_uis:
		var part: SuitPartResource = _config.get_part(slot_int as SuitPartResource.Slot) if _config else null
		var indices: Array = part.get("mesh_surface_indices") if part != null else []
		if indices == null:
			indices = []
		_viewer.set_slot_status(indices, part)
		if slot_int == _active_slot and part and not indices.is_empty():
			_viewer.set_slot_highlighted(indices, true)


func _refresh_color_pickers() -> void:
	if _config == null:
		return
	# Setting .color directly does NOT emit color_changed, so no infinite loop.
	_primary_picker.color   = _config.color_primary
	_secondary_picker.color = _config.color_secondary
	_accent_picker.color    = _config.color_accent


func _refresh_warnings(s: SuitStats) -> void:
	for child in _warnings_box.get_children():
		child.queue_free()

	var warnings: Array[String] = []
	if s.is_overloaded:
		warnings.append("SYSTEM OVERLOAD — flight disabled, performance degraded")
	if s.thermal_output > 2.0:
		warnings.append("HIGH THERMAL OUTPUT — landing impact risk")
	if s.load_ratio > 0.85 and s.load_ratio <= 1.0:
		warnings.append("Near capacity — flight ceiling reduced")

	for w: String in warnings:
		var lbl := Label.new()
		lbl.text          = "! " + w
		lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.0))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_warnings_box.add_child(lbl)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_configuration_changed(cfg: SuitConfiguration) -> void:
	_config = cfg
	_refresh_all()


func _on_color_changed() -> void:
	if _config == null:
		return
	_config.set_colors(
		_primary_picker.color,
		_secondary_picker.color,
		_accent_picker.color,
	)


func _on_slot_selected(slot: SuitPartResource.Slot) -> void:
	_active_slot = slot as int
	_refresh_slots()
	_refresh_viewer()


func _on_slot_change_requested(slot: SuitPartResource.Slot) -> void:
	_part_picker.open_for_slot(slot as int, SLOT_LABELS.get(slot, "COMPONENT"))


func _on_slot_clear_requested(slot: SuitPartResource.Slot) -> void:
	if _config:
		_config.unequip(slot)
		if _active_slot == slot as int:
			_active_slot = -1
		_refresh_all()


func _on_part_picked(slot: int, part: SuitPartResource) -> void:
	if _config:
		_active_slot = -1
		_config.equip(slot as SuitPartResource.Slot, part)  # emits configuration_changed → _refresh_all


func _on_viewport_input(event: InputEvent) -> void:
	if _viewer:
		_viewer.handle_mouse_input(event)
