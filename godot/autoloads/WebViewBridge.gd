extends Node
## Bridges GDScript and an embedded web page rendered by webview_server.py.
## Uses TCPServer + WebSocketPeer.accept_stream() — the correct Godot 4 pattern
## for accepting browser WebSocket connections.
##
## Usage:
##   WebViewBridge.register_item("My Label", {"key": "value"})
##   WebViewBridge.push_items()        # send current list to the web page
##   WebViewBridge.send_click(x, y)    # forward a click into the web page

signal item_selected(index: int, item: Dictionary)
signal items_changed(items: Array)
signal connection_changed(is_connected: bool)

const WS_PORT   := 9787
const HTTP_PORT := 8787

var _items: Array      = []
var _tcp:   TCPServer  = TCPServer.new()
var _peers: Dictionary = {}   # id(int) -> WebSocketPeer
var _next_id: int      = 0
var _open_count: int   = 0

# ── Panel UI (direct node manipulation — bypasses script-attachment issues) ───

const _C_CYAN := Color(0.0,   1.0,   0.8,   1.0)
const _C_RED  := Color(1.0,   0.251, 0.251, 1.0)
const _C_DIM  := Color(0.333, 0.333, 0.333, 1.0)
const _C_AMB  := Color(1.0,   0.627, 0.0,   1.0)

var _ui_panel:          Control  = null
var _ui_status:         Label    = null
var _ui_list:           ItemList = null
var _panel_dragging:    bool     = false
var _panel_drag_offset: Vector2  = Vector2.ZERO
var _ever_connected:    bool     = false

# ── Flight instruments ────────────────────────────────────────────────────────

var _suit_body:     Node  = null
var _move_ctrl:     Node  = null
var _flight_state:  Node  = null
var _suit_visuals:  Node  = null   # SuitModelVisuals — provides lean/bank angles
var _cached_stats:  Dictionary = {}
var _flight_timer:  float = 0.0
const _FLIGHT_HZ   := 20.0

var _fp_panel:    Control = null
var _fp_mode:     Label   = null
var _fp_speed:    Label   = null
var _fp_vspeed:   Label   = null
var _fp_altitude: Label   = null
var _fp_heading:  Label   = null
var _fp_energy:   Label   = null
var _fp_load:     Label   = null
var _fp_therm:    Label   = null
var _fp_dragging:    bool    = false
var _fp_drag_offset: Vector2 = Vector2.ZERO

# ── Attitude gyro panel ───────────────────────────────────────────────────────

var _gp_panel:    Control = null
var _gp_dial:     Node    = null   # AttitudeGyroDial — graphical draw node
var _gp_readout:  Label   = null   # small P/B text in header
var _gp_dragging:    bool    = false
var _gp_drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	OS.execute("fuser", ["-k", "%d/tcp" % WS_PORT])
	var script := ProjectSettings.globalize_path("res://web_view/webview_server.py")
	OS.create_process("python3", [script])
	var err := _tcp.listen(WS_PORT)
	if err != OK:
		push_error("WebViewBridge: TCPServer failed on port %d (%s)" % [WS_PORT, error_string(err)])
		set_process(false)
	EventBus.suit_stats_updated.connect(_on_suit_stats_updated)


func _exit_tree() -> void:
	for peer in _peers.values():
		(peer as WebSocketPeer).close()
	_tcp.stop()


func _process(delta: float) -> void:
	# Accept incoming TCP connections and upgrade them to WebSocket.
	while _tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		var err := ws.accept_stream(_tcp.take_connection())
		if err != OK:
			push_error("WebViewBridge: accept_stream failed (%s)" % error_string(err))
			continue
		_next_id += 1
		_peers[_next_id] = ws
		print("WebViewBridge: TCP connection accepted, peer id=%d" % _next_id)

	# Poll every peer; collect closed ones for removal.
	var remove: Array = []
	for id in _peers:
		var peer := _peers[id] as WebSocketPeer
		peer.poll()
		var state := peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				_handle_message(peer.get_packet().get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSED:
			remove.append(id)
	for id in remove:
		_peers.erase(id)

	# Count peers that are currently open and emit if the count changed.
	var open_count := 0
	for id in _peers:
		if (_peers[id] as WebSocketPeer).get_ready_state() == WebSocketPeer.STATE_OPEN:
			open_count += 1

	if open_count != _open_count:
		var prev  := _open_count
		_open_count = open_count
		print("WebViewBridge: open_count changed %d -> %d" % [prev, open_count])
		connection_changed.emit(open_count > 0)
		if open_count > prev:
			push_items.call_deferred()
		_bind_panel()
		_sync_panel_status()

	# Flight instruments + attitude gyro throttled at 20 Hz.
	_flight_timer += delta
	if _flight_timer >= 1.0 / _FLIGHT_HZ:
		_flight_timer = 0.0
		_poll_flight()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_panel_dragging = false
		_fp_dragging    = false
		_gp_dragging    = false
	elif event is InputEventMouseMotion:
		if _panel_dragging and _ui_panel != null and _ui_panel.visible:
			var np := _ui_panel.get_global_mouse_position() - _panel_drag_offset
			var vp := _ui_panel.get_viewport_rect().size
			_ui_panel.position = Vector2(clampf(np.x, 0.0, vp.x - _ui_panel.size.x),
			                             clampf(np.y, 0.0, vp.y - _ui_panel.size.y))
		if _fp_dragging and _fp_panel != null and _fp_panel.visible:
			var np := _fp_panel.get_global_mouse_position() - _fp_drag_offset
			var vp := _fp_panel.get_viewport_rect().size
			_fp_panel.position = Vector2(clampf(np.x, 0.0, vp.x - _fp_panel.size.x),
			                             clampf(np.y, 0.0, vp.y - _fp_panel.size.y))
		if _gp_dragging and _gp_panel != null and _gp_panel.visible:
			var np := _gp_panel.get_global_mouse_position() - _gp_drag_offset
			var vp := _gp_panel.get_viewport_rect().size
			_gp_panel.position = Vector2(clampf(np.x, 0.0, vp.x - _gp_panel.size.x),
			                             clampf(np.y, 0.0, vp.y - _gp_panel.size.y))


# ── Public API ────────────────────────────────────────────────────────────────

func register_item(label: String, data: Dictionary = {}) -> void:
	_items.append({"label": label, "data": data})


func clear_items() -> void:
	_items.clear()


func get_items() -> Array:
	return _items.duplicate()


func get_item_count() -> int:
	return _items.size()


func get_peer_count() -> int:
	return _open_count


func push_items() -> void:
	_broadcast({"type": "items", "data": _items})
	items_changed.emit(_items.duplicate())
	_bind_panel()
	_sync_panel_items()


func send_click(x: int, y: int) -> void:
	_broadcast({"type": "click", "x": x, "y": y})


# ── Internal ──────────────────────────────────────────────────────────────────

func _broadcast(obj: Dictionary) -> void:
	var buf := JSON.stringify(obj).to_utf8_buffer()
	for id in _peers:
		var peer := _peers[id] as WebSocketPeer
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			peer.send(buf)


func _handle_message(msg: String) -> void:
	var parsed = JSON.parse_string(msg)
	if not parsed is Dictionary:
		return
	match parsed.get("type"):
		"select":
			var idx := int(parsed.get("index", -1))
			if idx >= 0 and idx < _items.size():
				item_selected.emit(idx, _items[idx])


# ── Scene inspector panel ─────────────────────────────────────────────────────

func _bind_panel() -> void:
	if _ui_panel != null:
		return
	_ui_panel = get_tree().get_root().find_child("WebViewPanel", true, false) as Control
	if _ui_panel == null:
		return

	_ui_status = _ui_panel.find_child("Status",   true, false) as Label
	_ui_list   = _ui_panel.find_child("ItemList", true, false) as ItemList

	var close_btn := _ui_panel.find_child("CloseBtn", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(_on_panel_close)

	var header := _ui_panel.find_child("Header", true, false) as ColorRect
	if header:
		header.gui_input.connect(_on_panel_header_input)

	if _ui_list:
		_ui_list.item_selected.connect(_on_panel_item_selected)

	_sync_panel_status()
	_sync_panel_items()


func _sync_panel_status() -> void:
	if _ui_status == null:
		return
	if _open_count > 0:
		_ever_connected = true
		_ui_status.text = "CONNECTED"
		_ui_status.add_theme_color_override("font_color", _C_CYAN)
	elif _ever_connected:
		_ui_status.text = "DISCONNECTED — retrying in 2s…"
		_ui_status.add_theme_color_override("font_color", _C_RED)
	else:
		_ui_status.text = "CONNECTING…"
		_ui_status.add_theme_color_override("font_color", _C_DIM)


func _sync_panel_items() -> void:
	if _ui_list == null:
		return
	_ui_list.clear()
	if _items.is_empty():
		_ui_list.add_item("No items registered.")
		return
	for item in _items:
		var label: String = str(item.get("label", ""))
		var data: Dictionary = item.get("data", {})
		var text := label
		if not data.is_empty():
			var parts := PackedStringArray()
			for k in data:
				parts.append(str(k) + ": " + str(data[k]))
			text += "   " + "  ·  ".join(parts)
		_ui_list.add_item(text)


func _on_panel_close() -> void:
	if _ui_panel:
		_ui_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_panel_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_panel_dragging = event.pressed
		if event.pressed and _ui_panel:
			_panel_drag_offset = _ui_panel.get_global_mouse_position() - _ui_panel.global_position


func _on_panel_item_selected(index: int) -> void:
	if index >= 0 and index < _items.size():
		item_selected.emit(index, _items[index])


# ── Flight instruments ────────────────────────────────────────────────────────

func _on_suit_stats_updated(new_stats) -> void:
	_cached_stats = {
		"load_ratio":          new_stats.load_ratio,
		"boost_speed":         new_stats.boost_speed,
		"thermal_output":      new_stats.thermal_output,
		"max_flight_altitude": new_stats.max_flight_altitude,
		"flight_available":    new_stats.flight_available,
	}


func _find_suit_nodes() -> void:
	if _suit_body != null:
		return
	_suit_body    = get_tree().get_root().find_child("SuitBody",           true, false)
	_move_ctrl    = get_tree().get_root().find_child("MovementController", true, false)
	_flight_state = get_tree().get_root().find_child("FlightState",        true, false)
	_suit_visuals = get_tree().get_root().find_child("SuitModel",          true, false)


func _poll_flight() -> void:
	_find_suit_nodes()
	if _suit_body == null:
		return

	var vel:      Vector3 = _suit_body.velocity
	var pos:      Vector3 = (_suit_body as Node3D).global_position
	var hspeed:   float   = Vector2(vel.x, vel.z).length()
	var speed:    float   = hspeed
	var vspeed:   float   = vel.y
	var altitude: float   = pos.y
	var heading:  float   = fmod(rad_to_deg(-(_suit_body as Node3D).rotation.y) + 3600.0, 360.0)

	var mode_str := "GROUNDED"
	if _move_ctrl != null:
		match int(_move_ctrl.get("current_state")):
			1: mode_str = "AIRBORNE"
			2: mode_str = "FLIGHT"

	var hover_energy: float = 1.0
	if _flight_state != null:
		hover_energy = float(_flight_state.get("_hover_energy"))

	var load_ratio:   float = _cached_stats.get("load_ratio",    0.0)
	var thermal_raw:  float = _cached_stats.get("thermal_output", 0.0)
	var boost_speed:  float = _cached_stats.get("boost_speed",   60.0)
	var ceiling             = _cached_stats.get("max_flight_altitude", INF)
	var flight_avail: bool  = _cached_stats.get("flight_available", true)

	var ceiling_str := "∞" if is_inf(float(ceiling)) else "%.0f m" % float(ceiling)
	var thermal_norm: float = clampf(thermal_raw / 3.0, 0.0, 1.0)

	# Attitude gyro — pitch from flight path vector, bank from visual lean
	var pitch_deg: float = rad_to_deg(atan2(vel.y, maxf(hspeed, 0.01)))
	var bank_deg:  float = 0.0
	if _suit_visuals != null:
		bank_deg = float(_suit_visuals.get("_lean_side"))

	var flight_payload := {
		"type":         "flight_data",
		"speed":        snappedf(speed,        0.1),
		"vspeed":       snappedf(vspeed,       0.1),
		"altitude":     snappedf(altitude,     0.1),
		"heading":      snappedf(heading,      0.1),
		"x":            snappedf(pos.x,        0.1),
		"z":            snappedf(pos.z,        0.1),
		"mode":         mode_str,
		"hover_energy": snappedf(hover_energy, 0.01),
		"load_ratio":   snappedf(load_ratio,   0.01),
		"thermal":      snappedf(thermal_norm, 0.01),
		"boost_speed":  boost_speed,
		"ceiling":      ceiling_str,
		"flight_avail": flight_avail,
	}

	var gyro_payload := {
		"type":  "gyro_data",
		"pitch": snappedf(pitch_deg, 0.1),
		"bank":  snappedf(bank_deg,  0.1),
	}

	_broadcast(flight_payload)
	_broadcast(gyro_payload)

	_bind_fp()
	_sync_fp_nodes(flight_payload)

	_bind_gp()
	_sync_gp_nodes(pitch_deg, bank_deg)


func _bind_fp() -> void:
	if _fp_panel != null:
		return
	_fp_panel = get_tree().get_root().find_child("FlightInstrumentsPanel", true, false) as Control
	if _fp_panel == null:
		return

	_fp_mode     = _fp_panel.find_child("FIMode",     true, false) as Label
	_fp_speed    = _fp_panel.find_child("FISpeed",    true, false) as Label
	_fp_vspeed   = _fp_panel.find_child("FIVSpeed",   true, false) as Label
	_fp_altitude = _fp_panel.find_child("FIAltitude", true, false) as Label
	_fp_heading  = _fp_panel.find_child("FIHeading",  true, false) as Label
	_fp_energy   = _fp_panel.find_child("FIEnergy",   true, false) as Label
	_fp_load     = _fp_panel.find_child("FILoad",     true, false) as Label
	_fp_therm    = _fp_panel.find_child("FITherm",    true, false) as Label

	var close_btn := _fp_panel.find_child("FICloseBtn", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(_on_fp_close)

	var header := _fp_panel.find_child("FIHeader", true, false) as ColorRect
	if header:
		header.gui_input.connect(_on_fp_header_input)


func _sync_fp_nodes(d: Dictionary) -> void:
	if _fp_panel == null:
		return

	var mode: String = d.get("mode", "GROUNDED")
	if _fp_mode:
		_fp_mode.text = mode
		match mode:
			"FLIGHT":   _fp_mode.add_theme_color_override("font_color", _C_CYAN)
			"AIRBORNE": _fp_mode.add_theme_color_override("font_color", _C_AMB)
			_:          _fp_mode.add_theme_color_override("font_color", _C_DIM)

	if _fp_speed:
		_fp_speed.text = "%.1f m/s" % d.get("speed", 0.0)

	var vs: float = d.get("vspeed", 0.0)
	if _fp_vspeed:
		var arrow := "▲" if vs > 0.1 else ("▼" if vs < -0.1 else "—")
		_fp_vspeed.text = "%s %.1f m/s" % [arrow, absf(vs)]
		if vs > 0.1:
			_fp_vspeed.add_theme_color_override("font_color", _C_CYAN)
		elif vs < -0.1:
			_fp_vspeed.add_theme_color_override("font_color", _C_AMB)
		else:
			_fp_vspeed.add_theme_color_override("font_color", _C_DIM)

	if _fp_altitude:
		_fp_altitude.text = "%.1f m" % d.get("altitude", 0.0)

	if _fp_heading:
		var hdg: float = d.get("heading", 0.0)
		_fp_heading.text = "%.0f° %s" % [hdg, _cardinal(hdg)]

	var energy: float = d.get("hover_energy", 1.0)
	if _fp_energy:
		_fp_energy.text = "%.0f%%" % (energy * 100.0)
		if energy > 0.6:
			_fp_energy.add_theme_color_override("font_color", _C_CYAN)
		elif energy > 0.3:
			_fp_energy.add_theme_color_override("font_color", _C_AMB)
		else:
			_fp_energy.add_theme_color_override("font_color", _C_RED)

	var load: float = d.get("load_ratio", 0.0)
	if _fp_load:
		_fp_load.text = "%.0f%%" % (load * 100.0)
		if load < 0.5:
			_fp_load.add_theme_color_override("font_color", _C_CYAN)
		elif load < 0.8:
			_fp_load.add_theme_color_override("font_color", _C_AMB)
		else:
			_fp_load.add_theme_color_override("font_color", _C_RED)

	var therm: float = d.get("thermal", 0.0)
	if _fp_therm:
		_fp_therm.text = "%.0f%%" % (therm * 100.0)
		if therm < 0.4:
			_fp_therm.add_theme_color_override("font_color", _C_CYAN)
		elif therm < 0.7:
			_fp_therm.add_theme_color_override("font_color", _C_AMB)
		else:
			_fp_therm.add_theme_color_override("font_color", _C_RED)


func _cardinal(hdg: float) -> String:
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return dirs[int(fmod(hdg + 22.5, 360.0) / 45.0) % 8]


func _on_fp_close() -> void:
	if _fp_panel:
		_fp_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_fp_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_fp_dragging = event.pressed
		if event.pressed and _fp_panel:
			_fp_drag_offset = _fp_panel.get_global_mouse_position() - _fp_panel.global_position


# ── Attitude gyro ─────────────────────────────────────────────────────────────

func _bind_gp() -> void:
	if _gp_panel != null:
		return
	_gp_panel = get_tree().get_root().find_child("AttitudeGyroPanel", true, false) as Control
	if _gp_panel == null:
		return

	_gp_dial    = _gp_panel.find_child("AGDial",    true, false)
	_gp_readout = _gp_panel.find_child("AGReadout", true, false) as Label

	var close_btn := _gp_panel.find_child("AGCloseBtn", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(_on_gp_close)

	var header := _gp_panel.find_child("AGHeader", true, false) as ColorRect
	if header:
		header.gui_input.connect(_on_gp_header_input)


func _sync_gp_nodes(pitch: float, bank: float) -> void:
	if _gp_panel == null:
		return

	if _gp_dial and _gp_dial.has_method("update_attitude"):
		_gp_dial.call("update_attitude", pitch, bank)

	if _gp_readout:
		_gp_readout.text = "P:%+.0f°  B:%+.0f°" % [pitch, bank]


func _on_gp_close() -> void:
	if _gp_panel:
		_gp_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_gp_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_gp_dragging = event.pressed
		if event.pressed and _gp_panel:
			_gp_drag_offset = _gp_panel.get_global_mouse_position() - _gp_panel.global_position
