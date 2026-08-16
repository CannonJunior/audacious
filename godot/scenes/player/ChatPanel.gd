extends Control
## In-game chat panel. Anchored to the bottom-right corner of the viewport.
## Two tabs: SQUAD (multiplayer relay) and AI ADVISOR (local Ollama).

# ── Layout constants ──────────────────────────────────────────────────────────

const PANEL_W  := 440.0
const PANEL_H  := 520.0
const MARGIN   := 20.0

# ── Palette (matches LobbyScreen / PauseMenu) ─────────────────────────────────

const C_BG     := Color(0.047, 0.051, 0.071)
const C_PANEL  := Color(0.071, 0.078, 0.106)
const C_BORDER := Color(0.0,   0.78,  0.60,  0.55)
const C_CYAN   := Color(0.0,   1.0,   0.8)
const C_AMB    := Color(1.0,   0.627, 0.0)
const C_RED    := Color(1.0,   0.251, 0.251)
const C_TEXT   := Color(0.82,  0.88,  0.90)
const C_DIM    := Color(0.38,  0.42,  0.45)
const C_SEP    := Color(0.0,   1.0,   0.8,   0.18)

# ── Node references ───────────────────────────────────────────────────────────

var _squad_scroll: ScrollContainer
var _squad_vbox:   VBoxContainer
var _ai_scroll:    ScrollContainer
var _ai_vbox:      VBoxContainer
var _model_bar:    Control
var _model_option: OptionButton
var _input_field:  LineEdit
var _tab_squad:    Button
var _tab_ai:       Button

# ── State ─────────────────────────────────────────────────────────────────────

var _active_tab:   int   = 0
var _ai_context:   Array = []          # Ollama-format message history
var _thinking_row: Control = null      # "▪ ▪ ▪" placeholder while waiting

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	call_deferred("_do_layout")
	get_viewport().size_changed.connect(_do_layout)
	EventBus.chat_message_received.connect(_on_squad_message)
	EventBus.ollama_response_received.connect(_on_ai_response)
	EventBus.ollama_models_loaded.connect(_on_models_loaded)
	EventBus.ollama_error.connect(_on_ollama_error)
	OllamaClient.fetch_models()

func _do_layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	size     = Vector2(PANEL_W, PANEL_H)
	position = vp - Vector2(MARGIN + PANEL_W, MARGIN + PANEL_H)

func focus_input() -> void:
	_input_field.grab_focus()

func is_typing() -> bool:
	return _input_field != null and _input_field.has_focus()

# ── Input handling ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _input_field.has_focus():
		# ESC while typing: defocus (stay open for reading or re-focus)
		if event.is_action_pressed("pause"):
			_input_field.release_focus()
			get_viewport().set_input_as_handled()
		return
	# Panel visible, field not focused:
	# ESC or Y close the panel; Enter re-focuses the field.
	if event.is_action_pressed("pause") or event.is_action_pressed("open_chat"):
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_input_field.grab_focus()
		get_viewport().set_input_as_handled()

# ── UI construction ───────────────────────────────────────────────────────────

func _build() -> void:
	# Opaque panel background + border
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color            = Color(C_BG.r, C_BG.g, C_BG.b, 0.96)
	ps.border_width_left   = 2
	ps.border_width_right  = 2
	ps.border_width_top    = 2
	ps.border_width_bottom = 2
	ps.border_color        = C_BORDER
	ps.content_margin_left  = 0
	ps.content_margin_right = 0
	ps.content_margin_top    = 0
	ps.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	panel.add_child(layout)

	layout.add_child(_build_header())
	layout.add_child(_make_hsep())
	layout.add_child(_build_tab_bar())
	layout.add_child(_make_hsep())

	# Message area — tabs share the same slot, hidden/shown by _switch_tab
	var msg_wrapper := Control.new()
	msg_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(msg_wrapper)

	_squad_scroll = _make_scroll_container()
	_squad_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_squad_vbox = _make_msg_vbox()
	_squad_scroll.add_child(_squad_vbox)
	msg_wrapper.add_child(_squad_scroll)

	_ai_scroll = _make_scroll_container()
	_ai_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ai_vbox = _make_msg_vbox()
	_ai_scroll.add_child(_ai_vbox)
	msg_wrapper.add_child(_ai_scroll)

	# Model selector (AI tab only)
	_model_bar = _build_model_bar()
	layout.add_child(_model_bar)

	layout.add_child(_make_hsep())
	layout.add_child(_build_input_row())

	_switch_tab(0)

func _build_header() -> Control:
	var bar := ColorRect.new()
	bar.color = C_PANEL
	bar.custom_minimum_size.y = 38.0

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	bar.add_child(hbox)

	var pad_l := Control.new()
	pad_l.custom_minimum_size.x = 12.0
	hbox.add_child(pad_l)

	var title := Label.new()
	title.text = "▪  COMMUNICATIONS"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", C_CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(title)

	var close_btn := _make_icon_button("×")
	close_btn.pressed.connect(func() -> void:
		visible = false
		if not Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
	hbox.add_child(close_btn)

	var pad_r := Control.new()
	pad_r.custom_minimum_size.x = 4.0
	hbox.add_child(pad_r)

	return bar

func _build_tab_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 34.0
	bar.add_theme_constant_override("separation", 0)

	_tab_squad = _make_tab_button("SQUAD")
	_tab_squad.pressed.connect(func() -> void: _switch_tab(0))
	bar.add_child(_tab_squad)

	_tab_ai = _make_tab_button("AI ADVISOR")
	_tab_ai.pressed.connect(func() -> void: _switch_tab(1))
	bar.add_child(_tab_ai)

	return bar

func _build_model_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 32.0
	bar.add_theme_constant_override("separation", 8)

	var pad := Control.new()
	pad.custom_minimum_size.x = 12.0
	bar.add_child(pad)

	var lbl := Label.new()
	lbl.text = "MODEL"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_DIM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)

	_model_option = OptionButton.new()
	_model_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_option.add_theme_font_size_override("font_size", 12)
	_model_option.add_theme_color_override("font_color", C_TEXT)
	var opt_style := StyleBoxFlat.new()
	opt_style.bg_color    = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.06)
	opt_style.border_width_left   = 1
	opt_style.border_width_right  = 1
	opt_style.border_width_top    = 1
	opt_style.border_width_bottom = 1
	opt_style.border_color = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.35)
	_model_option.add_theme_stylebox_override("normal", opt_style)
	_model_option.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	_model_option.add_item("(connecting...)")
	_model_option.item_selected.connect(func(idx: int) -> void:
		OllamaClient.set_model(_model_option.get_item_text(idx))
	)
	bar.add_child(_model_option)

	var pad2 := Control.new()
	pad2.custom_minimum_size.x = 8.0
	bar.add_child(pad2)

	return bar

func _build_input_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 44.0
	row.add_theme_constant_override("separation", 0)

	var pad_l := Control.new()
	pad_l.custom_minimum_size.x = 10.0
	row.add_child(pad_l)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Type a message…"
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.add_theme_font_size_override("font_size", 13)
	_input_field.add_theme_color_override("font_color",             C_TEXT)
	_input_field.add_theme_color_override("font_placeholder_color", C_DIM)
	var le_normal := StyleBoxFlat.new()
	le_normal.bg_color    = Color(0.055, 0.060, 0.082)
	le_normal.border_width_left   = 1
	le_normal.border_width_right  = 1
	le_normal.border_width_top    = 1
	le_normal.border_width_bottom = 1
	le_normal.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.5)
	le_normal.content_margin_left   = 10
	le_normal.content_margin_right  = 10
	le_normal.content_margin_top    = 8
	le_normal.content_margin_bottom = 8
	_input_field.add_theme_stylebox_override("normal", le_normal)
	var le_focus := le_normal.duplicate() as StyleBoxFlat
	le_focus.border_color = C_CYAN
	_input_field.add_theme_stylebox_override("focus", le_focus)
	_input_field.text_submitted.connect(_on_submit)
	row.add_child(_input_field)

	var send_btn := Button.new()
	send_btn.text = "SEND"
	send_btn.custom_minimum_size = Vector2(58, 0)
	send_btn.add_theme_font_size_override("font_size", 12)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color     = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.10)
	sb_n.border_width_left   = 2
	sb_n.border_width_right  = 2
	sb_n.border_width_top    = 2
	sb_n.border_width_bottom = 2
	sb_n.border_color = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.5)
	sb_n.content_margin_left   = 10
	sb_n.content_margin_right  = 10
	sb_n.content_margin_top    = 8
	sb_n.content_margin_bottom = 8
	send_btn.add_theme_stylebox_override("normal", sb_n)
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color    = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.22)
	sb_h.border_color = C_CYAN
	send_btn.add_theme_stylebox_override("hover",   sb_h)
	send_btn.add_theme_stylebox_override("pressed", sb_h)
	send_btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	send_btn.add_theme_color_override("font_color",         C_CYAN)
	send_btn.add_theme_color_override("font_hover_color",   C_CYAN)
	send_btn.add_theme_color_override("font_pressed_color", C_CYAN)
	send_btn.pressed.connect(func() -> void: _on_submit(_input_field.text))
	row.add_child(send_btn)

	var pad_r := Control.new()
	pad_r.custom_minimum_size.x = 10.0
	row.add_child(pad_r)

	return row

# ── Tab switching ─────────────────────────────────────────────────────────────

func _switch_tab(tab: int) -> void:
	_active_tab = tab
	_squad_scroll.visible = (tab == 0)
	_ai_scroll.visible    = (tab == 1)
	_model_bar.visible    = (tab == 1)
	_style_tab_button(_tab_squad, tab == 0)
	_style_tab_button(_tab_ai,   tab == 1)
	var active_scroll := _squad_scroll if tab == 0 else _ai_scroll
	_defer_scroll_bottom(active_scroll)

# ── Message rendering ─────────────────────────────────────────────────────────

func _on_squad_message(sender_id: String, message: String) -> void:
	var is_own := (sender_id == NetworkManager.local_player_id)
	var name_color := C_CYAN if is_own else Color(0.55, 0.85, 0.95)
	var display    := "You" if is_own else sender_id
	_append_msg(_squad_vbox, _squad_scroll, display, message, name_color)

func _on_ai_response(message: String, _model: String) -> void:
	_remove_thinking()
	_ai_context.append({"role": "assistant", "content": message})
	_append_msg(_ai_vbox, _ai_scroll, "AI", message, C_CYAN)

func _on_models_loaded(models: Array) -> void:
	_model_option.clear()
	if models.is_empty():
		_model_option.add_item("(none found)")
		return
	for m in models:
		_model_option.add_item(m)
	_model_option.selected = 0
	OllamaClient.set_model(_model_option.get_item_text(0))

func _on_ollama_error(error: String) -> void:
	_remove_thinking()
	_append_system_msg(_ai_vbox, _ai_scroll, "Error: " + error, C_RED)

func _on_submit(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	_input_field.clear()
	if _active_tab == 0:
		NetworkManager.chat_say(text)
	else:
		_ai_context.append({"role": "user", "content": text})
		_append_msg(_ai_vbox, _ai_scroll, "You", text, C_AMB)
		_show_thinking()
		if not OllamaClient.chat(_ai_context):
			_remove_thinking()
			_append_system_msg(_ai_vbox, _ai_scroll, "Ollama is busy — try again", C_DIM)

# ── Message entry helpers ─────────────────────────────────────────────────────

func _append_msg(vbox: VBoxContainer, scroll: ScrollContainer,
		sender: String, text: String, sender_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pad := Control.new()
	pad.custom_minimum_size.x = 10.0
	row.add_child(pad)

	var name_lbl := Label.new()
	name_lbl.text = sender.left(12)
	name_lbl.custom_minimum_size.x = 72.0
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", sender_color)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(name_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = text
	msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.add_theme_font_size_override("font_size", 13)
	msg_lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(msg_lbl)

	var pad2 := Control.new()
	pad2.custom_minimum_size.x = 10.0
	row.add_child(pad2)

	vbox.add_child(row)
	_trim_vbox(vbox)
	_defer_scroll_bottom(scroll)

func _append_system_msg(vbox: VBoxContainer, scroll: ScrollContainer,
		text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	vbox.add_child(lbl)
	_trim_vbox(vbox)
	_defer_scroll_bottom(scroll)

func _show_thinking() -> void:
	if _thinking_row != null:
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pad := Control.new()
	pad.custom_minimum_size.x = 10.0
	row.add_child(pad)

	var lbl := Label.new()
	lbl.text = "▪ ▪ ▪"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_DIM)
	row.add_child(lbl)

	_thinking_row = row
	_ai_vbox.add_child(_thinking_row)
	_defer_scroll_bottom(_ai_scroll)

func _remove_thinking() -> void:
	if _thinking_row != null:
		_thinking_row.queue_free()
		_thinking_row = null

func _trim_vbox(vbox: VBoxContainer, max_count: int = 120) -> void:
	while vbox.get_child_count() > max_count:
		vbox.get_child(0).queue_free()

func _defer_scroll_bottom(scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

# ── Widget factories ──────────────────────────────────────────────────────────

func _make_scroll_container() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return sc

func _make_msg_vbox() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	return vb

func _make_hsep() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = C_SEP
	sep.custom_minimum_size = Vector2(0, 1)
	return sep

func _make_tab_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 34.0
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _style_tab_button(btn: Button, active: bool) -> void:
	var color := C_CYAN if active else C_DIM
	var bg    := StyleBoxFlat.new()
	bg.bg_color    = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.10) if active else Color(0, 0, 0, 0)
	bg.border_width_bottom = 2
	bg.border_color = color
	bg.content_margin_left   = 12
	bg.content_margin_right  = 12
	bg.content_margin_top    = 6
	bg.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal",  bg)
	btn.add_theme_stylebox_override("hover",   bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_color_override("font_color",       color)
	btn.add_theme_color_override("font_hover_color", C_CYAN)

func _make_icon_button(icon_text: String) -> Button:
	var btn := Button.new()
	btn.text = icon_text
	btn.custom_minimum_size = Vector2(34, 34)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color",         C_DIM)
	btn.add_theme_color_override("font_hover_color",   C_RED)
	btn.add_theme_color_override("font_pressed_color", C_RED)
	btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	return btn
