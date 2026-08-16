extends Control

signal heist_planner_requested
signal suit_workshop_requested
signal lobby_requested

const C_PANEL  := Color(0.071, 0.078, 0.106)
const C_BORDER := Color(0.0,   0.78,  0.60,  0.55)
const C_CYAN   := Color(0.0,   1.0,   0.8)
const C_AMB    := Color(1.0,   0.627, 0.0)
const C_RED    := Color(1.0,   0.251, 0.251)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_PANEL
	panel_style.border_width_left   = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = C_BORDER
	panel_style.content_margin_left   = 36
	panel_style.content_margin_right  = 36
	panel_style.content_margin_top    = 36
	panel_style.content_margin_bottom = 36
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", C_CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_sep())

	var resume_btn := _make_button("RESUME", C_CYAN)
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	var heist_btn := _make_button("HEIST PLANNER", C_AMB)
	heist_btn.pressed.connect(func() -> void:
		close()
		heist_planner_requested.emit())
	vbox.add_child(heist_btn)

	var workshop_btn := _make_button("SUIT WORKSHOP", C_AMB)
	workshop_btn.pressed.connect(func() -> void:
		close()
		suit_workshop_requested.emit())
	vbox.add_child(workshop_btn)

	vbox.add_child(_make_sep())

	var lobby_btn := _make_button("EXIT TO LOBBY", C_RED)
	lobby_btn.pressed.connect(func() -> void:
		close()
		lobby_requested.emit())
	vbox.add_child(lobby_btn)

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		_on_resume()
		get_viewport().set_input_as_handled()

func _on_resume() -> void:
	close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 50)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r, color.g, color.b, 0.08)
	normal.border_width_left   = 2
	normal.border_width_right  = 2
	normal.border_width_top    = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(color.r, color.g, color.b, 0.5)
	normal.content_margin_left   = 16
	normal.content_margin_right  = 16
	normal.content_margin_top    = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r, color.g, color.b, 0.18)
	hover.border_color = color
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style := hover.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(color.r, color.g, color.b, 0.28)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",         color)
	btn.add_theme_color_override("font_hover_color",   color)
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_font_size_override("font_size", 15)
	return btn

func _make_sep() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = Color(0.0, 1.0, 0.8, 0.18)
	sep.custom_minimum_size = Vector2(0, 1)
	return sep
