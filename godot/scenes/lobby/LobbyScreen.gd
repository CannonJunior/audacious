extends Control
## Main menu lobby. Builds its entire UI in GDScript so the settings
## panel rows can be generated from data without a massive .tscn.

const GAME_SCENE := "res://scenes/world/TestLevel.tscn"

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BG        := Color(0.047, 0.051, 0.071)
const C_PANEL     := Color(0.071, 0.078, 0.106)
const C_BORDER    := Color(0.0,   0.78,  0.60,  0.55)
const C_CYAN      := Color(0.0,   1.0,   0.8)
const C_AMB       := Color(1.0,   0.627, 0.0)
const C_RED       := Color(1.0,   0.251, 0.251)
const C_TEXT      := Color(0.82,  0.88,  0.90)
const C_DIM       := Color(0.38,  0.42,  0.45)
const C_SEP       := Color(0.0,   1.0,   0.8,   0.18)

# ── State ─────────────────────────────────────────────────────────────────────

var _settings_panel: Control = null
var _pending:        Dictionary = {}

var _is_hosting:       bool  = false
var _connected_peers:  int   = 0
var _ip_edit:          LineEdit = null
var _net_status_lbl:   Label    = null
var _net_peer_lbl:     Label    = null
var _local_ip_lbl:     Label    = null
var _start_net_btn:    Button   = null
var _host_btn:         Button   = null
var _join_btn:         Button   = null

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_lobby()
	_build_settings_panel()
	EventBus.peer_connected.connect(_on_net_peer_connected)
	EventBus.peer_disconnected.connect(_on_net_peer_disconnected)


# ── Background ────────────────────────────────────────────────────────────────

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var grid := _ScanlineGrid.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)


# ── Lobby layout ──────────────────────────────────────────────────────────────

func _build_lobby() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left",   80)
	root.add_theme_constant_override("margin_top",    0)
	root.add_theme_constant_override("margin_right",  80)
	root.add_theme_constant_override("margin_bottom", 0)
	add_child(root)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 60)
	root.add_child(hbox)

	# Left column — title + solo buttons
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_theme_constant_override("separation", 0)
	hbox.add_child(left)

	var top_gap := Control.new()
	top_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(top_gap)

	var title := Label.new()
	title.text = "AUDACIOUS"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", C_CYAN)
	left.add_child(title)

	var sub := Label.new()
	sub.text = "CITY OPERATIONS  //  SUIT WARFARE"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", C_DIM)
	left.add_child(sub)

	var title_sep := _make_hsep()
	title_sep.custom_minimum_size.y = 36
	left.add_child(title_sep)

	var btn_group := VBoxContainer.new()
	btn_group.add_theme_constant_override("separation", 10)
	left.add_child(btn_group)

	var start_btn := _make_lobby_button("START SOLO", C_CYAN)
	start_btn.pressed.connect(_on_start_pressed)
	btn_group.add_child(start_btn)

	var settings_btn := _make_lobby_button("SETTINGS", C_TEXT)
	settings_btn.pressed.connect(_on_settings_pressed)
	btn_group.add_child(settings_btn)

	var quit_btn := _make_lobby_button("QUIT", C_DIM)
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_group.add_child(quit_btn)

	var bottom_gap := Control.new()
	bottom_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(bottom_gap)

	var ver := Label.new()
	ver.text = "BUILD 0.1  //  PHASE 0"
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", C_DIM)
	ver.custom_minimum_size.y = 40
	ver.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	left.add_child(ver)

	# Right column — co-op panel
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	hbox.add_child(right)

	var right_top_gap := Control.new()
	right_top_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_top_gap)

	_build_coop_panel(right)

	var right_bottom_gap := Control.new()
	right_bottom_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_bottom_gap)


func _build_coop_panel(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color      = C_PANEL
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color  = C_BORDER
	style.content_margin_left   = 28
	style.content_margin_right  = 28
	style.content_margin_top    = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "CO-OP"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", C_CYAN)
	vbox.add_child(header)

	var header_sep := _make_hsep()
	vbox.add_child(header_sep)

	# HOST row
	_host_btn = _make_panel_button("HOST GAME", C_CYAN)
	_host_btn.pressed.connect(_on_host_pressed)
	vbox.add_child(_host_btn)

	# JOIN row — IP field + button side by side
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	vbox.add_child(join_row)

	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text  = "Host IP address"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_edit.custom_minimum_size.y = 40
	_style_line_edit(_ip_edit)
	join_row.add_child(_ip_edit)

	_join_btn = _make_panel_button("JOIN", C_AMB)
	_join_btn.custom_minimum_size.x = 90
	_join_btn.pressed.connect(_on_join_pressed)
	join_row.add_child(_join_btn)

	# Status area
	var status_sep := _make_hsep()
	vbox.add_child(status_sep)

	_net_status_lbl = Label.new()
	_net_status_lbl.text = "OFFLINE"
	_net_status_lbl.add_theme_font_size_override("font_size", 13)
	_net_status_lbl.add_theme_color_override("font_color", C_DIM)
	_net_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_net_status_lbl)

	_net_peer_lbl = Label.new()
	_net_peer_lbl.text = ""
	_net_peer_lbl.add_theme_font_size_override("font_size", 13)
	_net_peer_lbl.add_theme_color_override("font_color", C_TEXT)
	vbox.add_child(_net_peer_lbl)

	_local_ip_lbl = Label.new()
	_local_ip_lbl.text = ""
	_local_ip_lbl.add_theme_font_size_override("font_size", 11)
	_local_ip_lbl.add_theme_color_override("font_color", C_DIM)
	vbox.add_child(_local_ip_lbl)

	# START GAME button — host only
	var start_sep := _make_hsep()
	vbox.add_child(start_sep)

	_start_net_btn = _make_panel_button("START GAME", C_AMB)
	_start_net_btn.disabled = true
	_start_net_btn.pressed.connect(_on_start_net_pressed)
	vbox.add_child(_start_net_btn)


func _make_panel_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r, color.g, color.b, 0.08)
	normal.border_width_left   = 2
	normal.border_width_right  = 2
	normal.border_width_top    = 2
	normal.border_width_bottom = 2
	normal.border_color  = Color(color.r, color.g, color.b, 0.5)
	normal.content_margin_left   = 16
	normal.content_margin_right  = 16
	normal.content_margin_top    = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color    = Color(color.r, color.g, color.b, 0.18)
	hover.border_color = color
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style := hover.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(color.r, color.g, color.b, 0.28)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color    = Color(0.0, 0.0, 0.0, 0.0)
	disabled_style.border_color = Color(color.r, color.g, color.b, 0.18)
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",          color)
	btn.add_theme_color_override("font_hover_color",    color)
	btn.add_theme_color_override("font_pressed_color",  color)
	btn.add_theme_color_override("font_disabled_color", Color(color.r, color.g, color.b, 0.3))
	btn.add_theme_font_size_override("font_size", 14)
	return btn


func _style_line_edit(edit: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.065, 0.09)
	normal.border_width_left   = 1
	normal.border_width_right  = 1
	normal.border_width_top    = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.5)
	normal.content_margin_left   = 10
	normal.content_margin_right  = 10
	normal.content_margin_top    = 8
	normal.content_margin_bottom = 8
	edit.add_theme_stylebox_override("normal",  normal)
	var focus_style := normal.duplicate() as StyleBoxFlat
	focus_style.border_color = C_CYAN
	edit.add_theme_stylebox_override("focus", focus_style)
	edit.add_theme_color_override("font_color",             C_TEXT)
	edit.add_theme_color_override("font_placeholder_color", C_DIM)
	edit.add_theme_font_size_override("font_size", 13)


func _make_lobby_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 52)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var normal := StyleBoxFlat.new()
	normal.bg_color      = Color(0.0, 0.0, 0.0, 0.0)
	normal.border_width_left = 3
	normal.border_color  = color
	normal.content_margin_left  = 20
	normal.content_margin_top   = 12
	normal.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r, color.g, color.b, 0.12)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style := hover.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(color.r, color.g, color.b, 0.22)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",        color)
	btn.add_theme_color_override("font_hover_color",  color)
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_font_size_override("font_size", 18)
	return btn


# ── Co-op handlers ────────────────────────────────────────────────────────────

func _on_host_pressed() -> void:
	var err := NetworkManager.host_enet()
	if err != OK:
		_net_status_lbl.text = "HOSTING FAILED (error %d)" % err
		return
	_is_hosting      = true
	_connected_peers = 0
	_host_btn.disabled = true
	_join_btn.disabled = true
	_ip_edit.editable  = false
	_start_net_btn.disabled = false
	var local_ip := _get_local_ip()
	_net_status_lbl.text = "HOSTING"
	_local_ip_lbl.text   = "Your IP: %s : %d" % [local_ip, NetworkManager.ENET_PORT]
	_net_peer_lbl.text   = "Waiting for players…"


func _on_join_pressed() -> void:
	var addr: String = _ip_edit.text.strip_edges()
	if addr.is_empty():
		addr = "127.0.0.1"
	var err := NetworkManager.join_enet(addr)
	if err != OK:
		_net_status_lbl.text = "JOIN FAILED (error %d)" % err
		return
	_is_hosting = false
	_host_btn.disabled = true
	_join_btn.disabled = true
	_ip_edit.editable  = false
	_start_net_btn.disabled = true
	_net_status_lbl.text = "Connecting to %s…" % addr
	_net_peer_lbl.text   = ""
	_local_ip_lbl.text   = ""


func _on_start_net_pressed() -> void:
	NetworkManager.load_game_scene.rpc(GAME_SCENE)


func _on_net_peer_connected(peer_id: int) -> void:
	_connected_peers += 1
	if _is_hosting:
		_net_status_lbl.text = "HOSTING"
		_net_peer_lbl.text   = "%d player%s connected" % [
			_connected_peers,
			"s" if _connected_peers != 1 else "",
		]
	else:
		_net_status_lbl.text = "CONNECTED"
		_net_peer_lbl.text   = "Waiting for host to start…"


func _on_net_peer_disconnected(peer_id: int) -> void:
	_connected_peers = max(0, _connected_peers - 1)
	if _is_hosting:
		_net_peer_lbl.text = "%d player%s connected" % [
			_connected_peers,
			"s" if _connected_peers != 1 else "",
		]
	else:
		_net_status_lbl.text = "DISCONNECTED"
		_net_peer_lbl.text   = ""
		_host_btn.disabled = false
		_join_btn.disabled = false
		_ip_edit.editable  = true


func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue  # skip IPv6
		if addr == "127.0.0.1":
			continue
		return addr
	return "127.0.0.1"


# ── Settings panel ────────────────────────────────────────────────────────────

func _build_settings_panel() -> void:
	var overlay := ColorRect.new()
	overlay.color          = Color(0.0, 0.0, 0.0, 0.72)
	overlay.visible        = false
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter   = Control.MOUSE_FILTER_STOP
	_settings_panel        = overlay
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(920, 680)
	panel.grow_horizontal  = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical    = Control.GROW_DIRECTION_BOTH
	var panel_style        := StyleBoxFlat.new()
	panel_style.bg_color   = C_PANEL
	panel_style.border_width_left   = 1
	panel_style.border_width_right  = 1
	panel_style.border_width_top    = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = C_BORDER
	panel_style.content_margin_left   = 0
	panel_style.content_margin_right  = 0
	panel_style.content_margin_top    = 0
	panel_style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	var header := _build_settings_header()
	vbox.add_child(header)

	vbox.add_child(_make_hsep())

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tabs(tabs)
	vbox.add_child(tabs)

	_add_settings_tab(tabs, "DISPLAY",       _build_display_tab)
	_add_settings_tab(tabs, "GRAPHICS",      _build_graphics_tab)
	_add_settings_tab(tabs, "AUDIO",         _build_audio_tab)
	_add_settings_tab(tabs, "CONTROLS",      _build_controls_tab)
	_add_settings_tab(tabs, "GAMEPLAY",      _build_gameplay_tab)
	_add_settings_tab(tabs, "HUD",           _build_hud_tab)
	_add_settings_tab(tabs, "ACCESSIBILITY", _build_accessibility_tab)

	vbox.add_child(_make_hsep())

	var footer := _build_settings_footer()
	vbox.add_child(footer)


func _build_settings_header() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	hbox.add_child(margin)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", C_CYAN)
	margin.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(52, 52)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", C_DIM)
	close_btn.add_theme_color_override("font_hover_color", C_RED)
	close_btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	close_btn.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
	close_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	close_btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	close_btn.pressed.connect(_on_settings_close)
	hbox.add_child(close_btn)

	return hbox


func _build_settings_footer() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var reset_btn := _make_footer_button("RESET TO DEFAULTS", C_DIM)
	reset_btn.pressed.connect(_on_reset_defaults)
	hbox.add_child(reset_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var cancel_btn := _make_footer_button("CANCEL", C_DIM)
	cancel_btn.pressed.connect(_on_settings_close)
	hbox.add_child(cancel_btn)

	var apply_btn := _make_footer_button("APPLY & CLOSE", C_CYAN)
	apply_btn.pressed.connect(_on_apply_pressed)
	hbox.add_child(apply_btn)

	return margin


func _make_footer_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 38)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r, color.g, color.b, 0.10)
	normal.border_width_left   = 1
	normal.border_width_right  = 1
	normal.border_width_top    = 1
	normal.border_width_bottom = 1
	normal.border_color        = Color(color.r, color.g, color.b, 0.45)
	normal.content_margin_left   = 14
	normal.content_margin_right  = 14
	normal.content_margin_top    = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal",  normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color.r, color.g, color.b, 0.22)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",        color)
	btn.add_theme_color_override("font_hover_color",  color)
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_font_size_override("font_size", 13)
	return btn


func _style_tabs(tabs: TabContainer) -> void:
	var panel_empty := StyleBoxEmpty.new()
	panel_empty.content_margin_left   = 0
	panel_empty.content_margin_right  = 0
	panel_empty.content_margin_top    = 0
	panel_empty.content_margin_bottom = 0
	tabs.add_theme_stylebox_override("panel",         panel_empty)
	tabs.add_theme_stylebox_override("tab_selected",  _make_tab_style(true))
	tabs.add_theme_stylebox_override("tab_unselected",_make_tab_style(false))
	tabs.add_theme_stylebox_override("tab_hovered",   _make_tab_style(false, true))
	tabs.add_theme_color_override("font_selected_color",   C_CYAN)
	tabs.add_theme_color_override("font_unselected_color", C_DIM)
	tabs.add_theme_color_override("font_hovered_color",    C_TEXT)
	tabs.add_theme_font_size_override("font_size", 12)


func _make_tab_style(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_PANEL if selected else (Color(0.06, 0.065, 0.09) if hovered else Color(0.05, 0.054, 0.075))
	s.border_width_bottom = 2 if selected else 0
	s.border_color        = C_CYAN
	s.content_margin_left   = 16
	s.content_margin_right  = 16
	s.content_margin_top    = 10
	s.content_margin_bottom = 10
	return s


func _add_settings_tab(tabs: TabContainer, label: String, build_fn: Callable) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = label
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(vbox)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	margin.add_theme_constant_override("margin_top",    18)
	margin.add_theme_constant_override("margin_bottom", 18)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 2)
	margin.add_child(inner)

	build_fn.call(inner)


# ── Tab builders ──────────────────────────────────────────────────────────────

func _build_display_tab(c: VBoxContainer) -> void:
	_section(c, "WINDOW")
	_dropdown(c, "Window Mode",   "window_mode",  ["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"])
	_dropdown(c, "VSync",         "vsync_mode",   ["Disabled", "Enabled", "Adaptive"])
	_dropdown(c, "FPS Cap",       "fps_cap",       [0, 60, 120, 144, 240],
		func(v): return "Unlimited" if v == 0 else "%d Hz" % v)
	_slider(c,   "Render Scale",  "render_scale",  0.5, 1.0, 0.05, "%.0f%%",  func(v): return v * 100.0)


func _build_graphics_tab(c: VBoxContainer) -> void:
	_section(c, "RENDERING")
	_dropdown(c, "Anti-Aliasing",      "msaa",           ["Off", "2×  MSAA", "4×  MSAA", "8×  MSAA"])
	_dropdown(c, "Shadow Quality",     "shadow_quality", ["Low", "Medium", "High", "Ultra"])
	_toggle(c,   "Ambient Occlusion",  "ambient_occlusion")
	_toggle(c,   "Depth of Field",     "depth_of_field")
	_section(c, "POST-PROCESSING")
	_slider(c,   "Motion Blur",        "motion_blur",     0.0, 1.0, 0.05, "%.0f%%", func(v): return v * 100.0)


func _build_audio_tab(c: VBoxContainer) -> void:
	_section(c, "VOLUME")
	_slider(c, "Master",       "master_volume",      0.0, 1.0, 0.01, "%.0f%%", func(v): return v * 100.0)
	_slider(c, "Sound Effects","sfx_volume",         0.0, 1.0, 0.01, "%.0f%%", func(v): return v * 100.0)
	_slider(c, "Music",        "music_volume",       0.0, 1.0, 0.01, "%.0f%%", func(v): return v * 100.0)
	_slider(c, "Agent Voice",  "agent_voice_volume", 0.0, 1.0, 0.01, "%.0f%%", func(v): return v * 100.0)
	_slider(c, "Suit Ambient", "suit_ambient_volume",0.0, 1.0, 0.01, "%.0f%%", func(v): return v * 100.0)
	_section(c, "AUDIO PROCESSING")
	_toggle(c, "Spatial Audio (HRTF)", "spatial_audio")


func _build_controls_tab(c: VBoxContainer) -> void:
	_section(c, "MOUSE")
	_slider(c,  "Mouse Sensitivity",   "mouse_sensitivity",     0.05, 2.0, 0.05, "%.2f")
	_slider(c,  "Vertical Multiplier", "vertical_sensitivity",  0.25, 2.0, 0.05, "%.2f")
	_toggle(c,  "Invert Y Axis",       "invert_y")
	_slider(c,  "Aim Sensitivity",     "aim_sensitivity",       0.05, 2.0, 0.05, "%.2f")
	_section(c, "CONTROLLER")
	_slider(c,  "Controller Sensitivity","controller_sensitivity",0.1, 2.0, 0.05,"%.2f")
	_toggle(c,  "Controller Vibration", "controller_vibration")
	_section(c, "CAMERA")
	_slider(c,  "Field of View",        "camera_fov",            60.0, 120.0, 1.0, "%.0f°")
	_section(c, "BEHAVIOR")
	_toggle(c,  "Toggle Sprint",  "toggle_sprint")
	_toggle(c,  "Toggle Hover",   "toggle_hover")


func _build_gameplay_tab(c: VBoxContainer) -> void:
	_section(c, "CHALLENGE")
	_dropdown(c, "Difficulty",    "difficulty",   ["Scout", "Operative", "Ghost", "Phantom"])
	_section(c, "COMBAT")
	_dropdown(c, "Aim Assist",    "aim_assist",   ["Off", "Low", "High"])
	_toggle(c,   "Show Damage Numbers", "show_damage_numbers")
	_section(c, "EXTRACTION")
	_toggle(c,   "Auto-Pickup Loot",    "auto_pickup_loot")
	_dropdown(c, "Loot Interaction",    "loot_interact_hold",
		[true, false],  func(v): return "Hold to Loot" if v else "Tap to Loot")
	_section(c, "NARRATIVE")
	_toggle(c,   "Subtitles",           "subtitles")
	_dropdown(c, "Subtitle Size",       "subtitle_size",        ["Small", "Medium", "Large"])
	_section(c, "AI PARTNER")
	_dropdown(c, "Agent Autonomy",      "default_agent_autonomy",["Guided", "Semi-Auto", "Full-Auto"])


func _build_hud_tab(c: VBoxContainer) -> void:
	_section(c, "LAYOUT")
	_slider(c,   "HUD Scale",           "hud_scale",              0.5,  2.0,  0.05, "%.0f%%", func(v): return v * 100.0)
	_section(c, "ELEMENTS")
	_toggle(c,   "Minimap",             "show_minimap")
	_toggle(c,   "Compass",             "show_compass")
	_toggle(c,   "Damage Direction Indicator", "show_damage_indicator")
	_section(c, "SUIT INSTRUMENTS")
	_toggle(c,   "Always Show Thermal", "always_show_thermal")
	_slider(c,   "Thermal Warning Threshold","thermal_warning_threshold",0.1, 1.0, 0.05, "%.0f%%",
		func(v): return v * 100.0)
	_dropdown(c, "Instrument Update Rate","suit_readout_hz",
		[5.0, 10.0, 20.0],  func(v): return "%.0f Hz" % v)


func _build_accessibility_tab(c: VBoxContainer) -> void:
	_section(c, "VISUAL")
	_dropdown(c, "Colorblind Mode",     "colorblind_mode",
		["Off", "Deuteranopia", "Protanopia", "Tritanopia"])
	_toggle(c,   "High Contrast HUD",   "high_contrast_hud")
	_section(c, "MOTION")
	_slider(c,   "Camera Shake",        "camera_shake",  0.0, 1.0, 0.05, "%.0f%%",
		func(v): return v * 100.0)
	_toggle(c,   "Screen Flash Effects","screen_flash")
	_section(c, "READABILITY")
	_dropdown(c, "UI Font Size",        "font_size",  ["Small", "Medium", "Large"])


# ── Row helpers ───────────────────────────────────────────────────────────────

func _section(parent: VBoxContainer, title: String) -> void:
	if parent.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 10
		parent.add_child(gap)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", C_CYAN)
	parent.add_child(lbl)

	var sep := ColorRect.new()
	sep.color              = C_SEP
	sep.custom_minimum_size = Vector2(0, 1)
	parent.add_child(sep)

	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 4
	parent.add_child(gap2)


func _slider(parent: VBoxContainer, label: String, key: String,
		min_v: float, max_v: float, step: float,
		fmt: String, transform: Callable = Callable()) -> void:
	var row := _make_row()
	parent.add_child(row)

	var lbl := _make_row_label(label)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step      = step
	slider.value     = float(GameSettings.get(key))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 220
	_style_slider(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size.x = 62
	val_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", C_CYAN)

	var _refresh_val := func(v: float) -> void:
		var display: float = v if not transform.is_valid() else transform.call(v)
		val_lbl.text = fmt % display
	_refresh_val.call(slider.value)

	slider.value_changed.connect(func(v: float) -> void:
		_pending[key] = v
		_refresh_val.call(v)
	)

	row.add_child(slider)
	row.add_child(val_lbl)


func _toggle(parent: VBoxContainer, label: String, key: String) -> void:
	var row := _make_row()
	parent.add_child(row)

	var lbl := _make_row_label(label)
	row.add_child(lbl)

	var check := CheckButton.new()
	check.button_pressed = bool(GameSettings.get(key))
	check.add_theme_color_override("font_color",         C_TEXT)
	check.add_theme_color_override("font_hover_color",   C_CYAN)
	check.add_theme_color_override("font_pressed_color", C_CYAN)
	check.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	check.toggled.connect(func(v: bool) -> void: _pending[key] = v)
	row.add_child(check)


func _dropdown(parent: VBoxContainer, label: String, key: String,
		options: Array, display_fn: Callable = Callable()) -> void:
	var row := _make_row()
	parent.add_child(row)

	var lbl := _make_row_label(label)
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.custom_minimum_size.x = 220
	_style_option_button(opt)

	var current_val = GameSettings.get(key)
	var selected_idx := 0
	# When options is a String array the setting stores the index, not the string.
	var index_based: bool = options.size() > 0 and options[0] is String

	for i: int in options.size():
		var v = options[i]
		var txt: String
		if display_fn.is_valid():
			txt = display_fn.call(v)
		elif v is String:
			txt = v
		else:
			txt = str(v)
		opt.add_item(txt, i)
		if index_based:
			if i == int(str(current_val)):
				selected_idx = i
		else:
			if v == type_convert(current_val, typeof(v)):
				selected_idx = i

	opt.selected = selected_idx

	opt.item_selected.connect(func(idx: int) -> void:
		_pending[key] = idx if index_based else options[idx]
	)
	row.add_child(opt)


func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 40
	row.add_theme_constant_override("separation", 12)
	return row


func _make_row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", C_TEXT)
	return lbl


func _make_hsep() -> Control:
	var sep := ColorRect.new()
	sep.color               = C_SEP
	sep.custom_minimum_size = Vector2(0, 1)
	return sep


# ── Slider style ──────────────────────────────────────────────────────────────

func _style_slider(slider: HSlider) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color         = C_CYAN
	grabber.border_width_left   = 0
	grabber.border_width_right  = 0
	grabber.border_width_top    = 0
	grabber.border_width_bottom = 0
	grabber.set_corner_radius_all(4)
	slider.add_theme_icon_override("grabber",       _icon_from_style(grabber, Vector2i(14, 14)))
	slider.add_theme_icon_override("grabber_highlight", _icon_from_style(grabber, Vector2i(14, 14)))

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.15, 0.17, 0.22)
	track.content_margin_top    = 3
	track.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider",   track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.45)
	fill.content_margin_top    = 3
	fill.content_margin_bottom = 3
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("focus",        StyleBoxEmpty.new())


func _icon_from_style(style: StyleBoxFlat, size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(style.bg_color)
	return ImageTexture.create_from_image(img)


func _style_option_button(opt: OptionButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.11, 0.16)
	normal.border_width_left   = 1
	normal.border_width_right  = 1
	normal.border_width_top    = 1
	normal.border_width_bottom = 1
	normal.border_color        = Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.5)
	normal.content_margin_left   = 10
	normal.content_margin_right  = 30
	normal.content_margin_top    = 6
	normal.content_margin_bottom = 6
	opt.add_theme_stylebox_override("normal",  normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = C_BORDER
	opt.add_theme_stylebox_override("hover",   hover)
	opt.add_theme_stylebox_override("pressed", hover)
	opt.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	opt.add_theme_color_override("font_color",        C_TEXT)
	opt.add_theme_color_override("font_hover_color",  C_CYAN)
	opt.add_theme_color_override("font_pressed_color",C_CYAN)
	opt.add_theme_font_size_override("font_size", 13)


# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	_pending.clear()
	_settings_panel.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_close() -> void:
	_pending.clear()
	_settings_panel.visible = false


func _on_apply_pressed() -> void:
	for key: String in _pending:
		GameSettings.set(key, _pending[key])
	_pending.clear()
	GameSettings.apply_all()
	GameSettings.save_settings()
	_settings_panel.visible = false


func _on_reset_defaults() -> void:
	var fresh: Node = load("res://autoloads/GameSettings.gd").new()
	for prop in fresh.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var k: String = prop["name"]
			if k.begins_with("_"):
				continue
			GameSettings.set(k, fresh.get(k))
	fresh.free()
	GameSettings.apply_all()
	GameSettings.save_settings()
	_settings_panel.queue_free()
	_settings_panel = null
	_build_settings_panel()


# ── Scanline grid helper node ─────────────────────────────────────────────────

class _ScanlineGrid extends Control:
	func _draw() -> void:
		var step  := 48.0
		var color := Color(0.0, 1.0, 0.8, 0.025)
		var w     := size.x
		var h     := size.y
		var y     := 0.0
		while y < h:
			draw_line(Vector2(0, y), Vector2(w, y), color, 1.0)
			y += step
		var x := 0.0
		while x < w:
			draw_line(Vector2(x, 0), Vector2(x, h), color, 1.0)
			x += step * 3.0
