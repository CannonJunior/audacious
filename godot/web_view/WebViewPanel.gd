class_name WebViewPanel
extends Control

const C_ITEM_BG := Color(0.055, 0.055, 0.102, 1.0)
const C_SEL_BG  := Color(0.047, 0.102, 0.094, 1.0)
const C_ACCENT  := Color(1.0,   0.627, 0.0,   1.0)
const C_CYAN    := Color(0.0,   1.0,   0.8,   1.0)
const C_TEXT    := Color(0.847, 0.847, 0.878, 1.0)
const C_DETAIL  := Color(0.376, 0.376, 0.502, 1.0)

@onready var _item_list: VBoxContainer = %ItemList
@onready var _header:    ColorRect     = $VBox/Header
@onready var _close_btn: Button        = $VBox/Header/CloseBtn

var _dragging    := false
var _drag_offset := Vector2.ZERO
var _sel_index   := -1
var _rows        : Array[PanelContainer] = []


func _ready() -> void:
	_header.gui_input.connect(_on_header_input)
	_close_btn.pressed.connect(_on_close)
	_populate(WebViewBridge.get_items())
	WebViewBridge.items_changed.connect(_populate)


func _on_close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not _dragging or not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
	elif event is InputEventMouseMotion:
		var np := get_global_mouse_position() - _drag_offset
		var vp := get_viewport_rect().size
		position = Vector2(clampf(np.x, 0.0, vp.x - size.x),
		                   clampf(np.y, 0.0, vp.y - size.y))


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_drag_offset = get_global_mouse_position() - global_position


func _populate(items: Array) -> void:
	for child in _item_list.get_children():
		child.queue_free()
	_rows.clear()
	_sel_index = -1

	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "No items registered."
		lbl.add_theme_color_override("font_color", C_DETAIL)
		lbl.add_theme_font_size_override("font_size", 11)
		_item_list.add_child(lbl)
		return

	for i in items.size():
		var row: PanelContainer = _make_row(i, items[i])
		_rows.append(row)
		_item_list.add_child(row)


func _make_row(idx: int, item: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	_apply_row_style(row, false)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(inner)

	var label := Label.new()
	label.text = str(item.get("label", ""))
	label.add_theme_color_override("font_color", C_TEXT)
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	inner.add_child(label)

	var data: Dictionary = item.get("data", {})
	if not data.is_empty():
		var parts := PackedStringArray()
		for k in data:
			parts.append(str(k) + ": " + str(data[k]))
		var detail := Label.new()
		detail.text = "  ·  ".join(parts)
		detail.add_theme_color_override("font_color", C_DETAIL)
		detail.add_theme_font_size_override("font_size", 10)
		detail.mouse_filter = MOUSE_FILTER_IGNORE
		inner.add_child(detail)

	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select(idx)
	)
	return row


func _apply_row_style(row: PanelContainer, selected: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color              = C_SEL_BG if selected else C_ITEM_BG
	s.border_width_left     = 3
	s.border_color          = C_CYAN if selected else C_ACCENT
	s.content_margin_left   = 12
	s.content_margin_right  = 10
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", s)


func _select(idx: int) -> void:
	if _sel_index == idx:
		return
	_sel_index = idx
	for i in _rows.size():
		var row := _rows[i]
		_apply_row_style(row, i == idx)
		var inner := row.get_child(0) if row.get_child_count() > 0 else null
		if inner and inner.get_child_count() > 0:
			var lbl := inner.get_child(0) as Label
			if lbl:
				lbl.add_theme_color_override("font_color", C_CYAN if i == idx else C_TEXT)
	var all_items: Array = WebViewBridge.get_items()
	if idx < all_items.size():
		WebViewBridge.item_selected.emit(idx, all_items[idx])
