class_name ComponentSlotUI
extends PanelContainer

signal slot_selected(slot: SuitPartResource.Slot)
signal slot_change_requested(slot: SuitPartResource.Slot)
signal slot_clear_requested(slot: SuitPartResource.Slot)

const COLOR_BORDER_SELECTED: Color = Color(1.0,  0.60, 0.0,  1.0)
const COLOR_BORDER_EMPTY:    Color = Color(0.25, 0.25, 0.28, 1.0)
const COLOR_BORDER_FILLED:   Color = Color(0.40, 0.40, 0.44, 1.0)
const COLOR_BG_SELECTED:     Color = Color(0.15, 0.12, 0.04, 1.0)
const COLOR_BG_DEFAULT:      Color = Color(0.07, 0.07, 0.09, 1.0)

var _slot: SuitPartResource.Slot = SuitPartResource.Slot.CHASSIS

@onready var _category_label:  Label       = %CategoryLabel
@onready var _component_label: Label       = %ComponentLabel
@onready var _condition_bar:   ProgressBar = %ConditionBar
@onready var _acq_label:       Label       = %AcqLabel
@onready var _change_btn:      Button      = %ChangeButton
@onready var _clear_btn:       Button      = %ClearButton

var _is_selected: bool = false
var _part: SuitPartResource = null


func _ready() -> void:
	_change_btn.pressed.connect(func(): slot_change_requested.emit(_slot))
	_clear_btn.pressed.connect(func(): slot_clear_requested.emit(_slot))
	gui_input.connect(_on_gui_input)
	_refresh()


func configure(p_slot: SuitPartResource.Slot, label: String) -> void:
	_slot = p_slot
	_category_label.text = label
	_refresh()


func populate(part: SuitPartResource) -> void:
	_part = part
	_refresh()


func clear_display() -> void:
	_part = null
	_refresh()


func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_selection_style()


func _refresh() -> void:
	if _part == null:
		_component_label.text  = "— Empty —"
		_condition_bar.visible = false
		_acq_label.visible     = false
		_clear_btn.disabled    = true
		_change_btn.text       = "INSTALL"
	else:
		_component_label.text  = _part.display_name
		_condition_bar.visible = true
		_condition_bar.value   = clampf(_part.systems_load * 100.0, 0.0, 100.0)
		_acq_label.visible     = false
		_clear_btn.disabled    = false
		_change_btn.text       = "SWAP"

	_apply_selection_style()


func _apply_selection_style() -> void:
	var style := StyleBoxFlat.new()
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4

	if _is_selected:
		style.border_color = COLOR_BORDER_SELECTED
		style.bg_color     = COLOR_BG_SELECTED
	elif _part != null:
		style.border_color = COLOR_BORDER_FILLED
		style.bg_color     = COLOR_BG_DEFAULT
	else:
		style.border_color = COLOR_BORDER_EMPTY
		style.bg_color     = COLOR_BG_DEFAULT

	add_theme_stylebox_override("panel", style)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		slot_selected.emit(_slot)
