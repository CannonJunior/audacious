class_name PartPicker
extends PanelContainer
## Overlay panel for browsing and selecting a suit part for a given slot.
## Instantiated dynamically by SuitWorkshop; positioned above all other controls.

signal part_picked(slot: int, part)   ## part: SuitPartResource

@onready var _title:    Label           = %PickerTitle
@onready var _list:     VBoxContainer   = %PartList
@onready var _close:    Button          = %CloseButton

var _slot: int = -1


func _ready() -> void:
	_close.pressed.connect(func(): visible = false)
	visible = false


func open_for_slot(slot: int, label: String) -> void:
	_slot  = slot
	_title.text = label
	_populate()
	visible = true


func _populate() -> void:
	for child in _list.get_children():
		child.queue_free()

	var parts: Array = GameRegistry.get_parts_for_slot(_slot)
	if parts.is_empty():
		var lbl := Label.new()
		lbl.text = "No parts available for this slot."
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_list.add_child(lbl)
		return

	for part in parts:
		var btn := Button.new()
		btn.text          = part.display_name
		btn.alignment     = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text  = part.description
		btn.pressed.connect(func(): _pick(part))
		_list.add_child(btn)


func _pick(part) -> void:
	part_picked.emit(_slot, part)
	visible = false
