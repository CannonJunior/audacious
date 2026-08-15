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

var _items:      Array      = []
var _item_nodes: Array      = []   # parallel to _items — Node or null per entry
var _tcp:        TCPServer  = TCPServer.new()
var _peers: Dictionary = {}   # id(int) -> WebSocketPeer
var _next_id: int      = 0
var _open_count: int      = 0
var _selected_index: int  = -1

# ── Panel UI (direct node manipulation — bypasses script-attachment issues) ───

const _C_CYAN := Color(0.0,   1.0,   0.8,   1.0)
const _C_RED  := Color(1.0,   0.251, 0.251, 1.0)
const _C_DIM  := Color(0.333, 0.333, 0.333, 1.0)
const _C_AMB  := Color(1.0,   0.627, 0.0,   1.0)

# Maximum thermal_output at which thermal_norm saturates to 1.0.
# Equal to the highest chassis thermal_coefficient in SuitPartResource.
const _THERMAL_MAX_OUTPUT := 3.0

var _ui_panel:          Control     = null
var _ui_status:         Label       = null
var _ui_list:           ItemList    = null
var _ui_toggle:         Button      = null
var _inline_preview:    TextureRect = null
var _inline_sep:        Control     = null
var _preview_integrated: bool       = false
var _panel_dragging:    bool        = false
var _panel_drag_offset: Vector2     = Vector2.ZERO
var _ever_connected:    bool        = false

var _dp_panel:       Control     = null
var _dp_label:       Label       = null
var _dp_preview:     TextureRect = null
var _dp_dragging:    bool        = false
var _dp_drag_offset: Vector2     = Vector2.ZERO

# ── Flight instruments ────────────────────────────────────────────────────────

var _suit_body:            Node  = null
var _move_ctrl:            Node  = null
var _flight_state:         Node  = null
var _suit_visuals:         Node  = null   # SuitModelVisuals — provides lean/bank angles
var _cached_stats:         Dictionary = {}
var _flight_timer:         float = 0.0
var _all_suit_nodes_found: bool  = false
var _flight_panels_bound:  bool  = false
const _FLIGHT_HZ           := 20.0

# ── Node preview SubViewport ──────────────────────────────────────────────────

var _detail_viewport: SubViewport = null
var _detail_camera:   Camera3D    = null
var _detail_root:     Node3D      = null

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

# ── Power / gas router state ──────────────────────────────────────────────────

var _power_modules:  Array      = []
var _power_capacity: float      = 100.0
var _power_routes:   Dictionary = {}

var _gas_modules:  Array      = []
var _gas_pressure: float      = 1.0
var _gas_routes:   Dictionary = {}

# ── Power router panel ───────────────────────────────────────────────────────

var _pr_panel:       Control = null
var _pr_dial:        Node    = null
var _pr_dragging:    bool    = false
var _pr_drag_offset: Vector2 = Vector2.ZERO

# ── Gas router panel ──────────────────────────────────────────────────────────

var _gr_panel:       Control = null
var _gr_dial:        Node    = null
var _gr_dragging:    bool    = false
var _gr_drag_offset: Vector2 = Vector2.ZERO

# ── Attitude gyro panel ───────────────────────────────────────────────────────

var _gp_panel:    Control = null
var _gp_dial:     Node    = null   # AttitudeGyroDial — graphical draw node
var _gp_readout:  Label   = null   # small P/B text in header
var _gp_dragging:    bool    = false
var _gp_drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	OS.execute("pkill", ["-f", "webview_server.py"])
	OS.execute("fuser", ["-k", "%d/tcp" % WS_PORT])
	var script := ProjectSettings.globalize_path("res://web_view/webview_server.py")
	OS.create_process("python3", [script, "600", "800", str(HTTP_PORT)])
	var err := _tcp.listen(WS_PORT)
	if err != OK:
		push_error("WebViewBridge: TCPServer failed on port %d (%s)" % [WS_PORT, error_string(err)])
		set_process(false)
	EventBus.suit_stats_updated.connect(_on_suit_stats_updated)


func _exit_tree() -> void:
	for peer in _peers.values():
		(peer as WebSocketPeer).close()
	_tcp.stop()
	OS.execute("pkill", ["-f", "webview_server.py"])


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

	# Poll every peer; collect closed ones for removal; count open ones in one pass.
	var remove: Array = []
	var open_count := 0
	for id in _peers:
		var peer := _peers[id] as WebSocketPeer
		peer.poll()
		var state := peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				_handle_message(peer.get_packet().get_string_from_utf8())
			open_count += 1
		elif state == WebSocketPeer.STATE_CLOSED:
			remove.append(id)
	for id in remove:
		_peers.erase(id)

	if open_count != _open_count:
		var prev  := _open_count
		_open_count = open_count
		print("WebViewBridge: open_count changed %d -> %d" % [prev, open_count])
		connection_changed.emit(open_count > 0)
		if open_count > prev:
			push_items.call_deferred()
			if _selected_index >= 0 and _selected_index < _items.size():
				_broadcast.call_deferred({"type": "item_selected", "index": _selected_index, "item": _items[_selected_index]})
			if _power_modules.size() > 0:
				_broadcast.call_deferred({"type": "power_state", "total_capacity": _power_capacity, "modules": _power_modules})
			if _gas_modules.size() > 0:
				_broadcast.call_deferred({"type": "gas_state", "tank_pressure": _gas_pressure, "modules": _gas_modules})
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
		_dp_dragging    = false
		_pr_dragging    = false
		_gr_dragging    = false
	elif event is InputEventMouseMotion:
		_do_drag(_ui_panel, _panel_dragging, _panel_drag_offset)
		_do_drag(_fp_panel, _fp_dragging,    _fp_drag_offset)
		_do_drag(_gp_panel, _gp_dragging,    _gp_drag_offset)
		_do_drag(_dp_panel, _dp_dragging,    _dp_drag_offset)
		_do_drag(_pr_panel, _pr_dragging,    _pr_drag_offset)
		_do_drag(_gr_panel, _gr_dragging,    _gr_drag_offset)


func _do_drag(panel: Control, dragging: bool, offset: Vector2) -> void:
	if not dragging or panel == null or not panel.visible:
		return
	var np := panel.get_global_mouse_position() - offset
	var vp := panel.get_viewport_rect().size
	panel.position = Vector2(clampf(np.x, 0.0, vp.x - panel.size.x),
	                         clampf(np.y, 0.0, vp.y - panel.size.y))


# ── Public API ────────────────────────────────────────────────────────────────

func register_item(label: String, data: Dictionary = {}, node: Node = null) -> void:
	_items.append({"label": label, "data": data})
	_item_nodes.append(node)


func clear_items() -> void:
	_items.clear()
	_item_nodes.clear()


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


func send_pointer(page: String, subtype: String, x: int, y: int) -> void:
	_broadcast({"type": "pointer", "page": page, "subtype": subtype, "x": x, "y": y})


func push_power_state(modules: Array, capacity: float) -> void:
	_power_modules  = modules.duplicate(true)
	_power_capacity = capacity
	_broadcast({"type": "power_state", "total_capacity": capacity, "modules": modules})
	_sync_pr_nodes(_power_modules, _power_capacity)


func push_gas_state(modules: Array, tank_pressure: float) -> void:
	_gas_modules  = modules.duplicate(true)
	_gas_pressure = tank_pressure
	_broadcast({"type": "gas_state", "tank_pressure": tank_pressure, "modules": modules})
	_sync_gr_nodes(_gas_modules, _gas_pressure)


func get_power_routes() -> Dictionary:
	return _power_routes.duplicate()


func get_gas_routes() -> Dictionary:
	return _gas_routes.duplicate()


# ── Internal ──────────────────────────────────────────────────────────────────

func _broadcast(obj: Dictionary) -> void:
	var buf := JSON.stringify(obj).to_utf8_buffer()
	for id in _peers:
		var peer := _peers[id] as WebSocketPeer
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			peer.send(buf)


func _select_item(idx: int) -> void:
	_selected_index = idx
	item_selected.emit(idx, _items[idx])
	_broadcast({"type": "item_selected", "index": idx, "item": _items[idx]})
	var node: Node = _item_nodes[idx] if idx < _item_nodes.size() else null
	if node != null and is_instance_valid(node):
		_capture_node_preview(node, _items[idx].get("label", ""))


func _setup_detail_viewport() -> void:
	if _detail_viewport != null:
		return
	_detail_viewport = SubViewport.new()
	_detail_viewport.name = "DetailViewport"
	_detail_viewport.size = Vector2i(640, 480)
	_detail_viewport.own_world_3d = true
	_detail_viewport.transparent_bg = true
	_detail_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_detail_viewport)

	var env_node := WorldEnvironment.new()
	var env      := Environment.new()
	env.background_mode    = Environment.BG_COLOR
	env.background_color   = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.55, 0.65, 0.75)
	env.ambient_light_energy = 0.9
	env_node.environment = env
	_detail_viewport.add_child(env_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 45.0, 0.0)
	light.light_energy = 1.2
	_detail_viewport.add_child(light)

	_detail_root = Node3D.new()
	_detail_viewport.add_child(_detail_root)

	_detail_camera = Camera3D.new()
	_detail_viewport.add_child(_detail_camera)


func _capture_node_preview(node: Node, label: String) -> void:
	if not (node is Node3D):
		return
	_setup_detail_viewport()

	# Clear previous isolated meshes.
	for child in _detail_root.get_children():
		_detail_root.remove_child(child)
		child.free()

	# Duplicate only MeshInstance3D descendants, placed relative to node origin.
	var node_inv := (node as Node3D).global_transform.inverse()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mi3d := mi as MeshInstance3D
		if mi3d.mesh == null:
			continue
		var dup := mi3d.duplicate() as MeshInstance3D
		dup.transform = node_inv * mi3d.global_transform
		_detail_root.add_child(dup)

	# Compute AABB in isolated world space.
	var aabb  := AABB()
	var first := true
	for child in _detail_root.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			continue
		var local_aabb: AABB = mi.transform * mi.get_aabb()
		aabb = local_aabb if first else aabb.merge(local_aabb)
		first = false

	if first:
		return

	var center := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 0.5)
	var offset := Vector3(1.0, 0.6, 1.0).normalized() * radius * 2.5
	_detail_camera.position = center + offset
	_detail_camera.look_at(center, Vector3.UP)

	_detail_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	_bind_dp()
	_sync_dp(label)

	var img := _detail_viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return
	var path := ProjectSettings.globalize_path("res://web_view/preview.png")
	img.save_png(path)
	_broadcast({"type": "preview_updated", "ts": Time.get_ticks_msec()})


func _handle_message(msg: String) -> void:
	var parsed = JSON.parse_string(msg)
	if not parsed is Dictionary:
		return
	match parsed.get("type"):
		"select":
			var idx := int(parsed.get("index", -1))
			if idx >= 0 and idx < _items.size():
				_select_item(idx)
		"power_route":
			var routes: Dictionary = parsed.get("routes", {})
			_power_routes = routes
			EventBus.power_routes_changed.emit(routes)
		"gas_route":
			var routes: Dictionary = parsed.get("routes", {})
			_gas_routes = routes
			EventBus.gas_routes_changed.emit(routes)


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

	_ui_toggle    = _ui_panel.find_child("ToggleBtn",        true, false) as Button
	_inline_sep   = _ui_panel.find_child("InlinePreviewSep", true, false) as Control
	_inline_preview = _ui_panel.find_child("InlinePreview",  true, false) as TextureRect
	if _ui_toggle:
		_ui_toggle.pressed.connect(_on_preview_toggle)

	var header := _ui_panel.find_child("Header", true, false) as ColorRect
	if header:
		header.gui_input.connect(_on_panel_header_input)

	if _ui_list:
		_ui_list.item_selected.connect(_on_panel_item_selected)

	_ui_panel.visibility_changed.connect(_on_inspector_visibility_changed)

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
	if _dp_panel:
		_dp_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_inspector_visibility_changed() -> void:
	if _ui_panel and not _ui_panel.visible:
		if _dp_panel:
			_dp_panel.visible = false
		if _inline_preview:
			_inline_preview.visible = false
		if _inline_sep:
			_inline_sep.visible = false


func _on_panel_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_panel_dragging = event.pressed
		if event.pressed and _ui_panel:
			_panel_drag_offset = _ui_panel.get_global_mouse_position() - _ui_panel.global_position


func _on_panel_item_selected(index: int) -> void:
	if index >= 0 and index < _items.size():
		_select_item(index)


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
	if _suit_body == null:
		_suit_body    = get_tree().get_root().find_child("SuitBody",           true, false)
	if _move_ctrl == null:
		_move_ctrl    = get_tree().get_root().find_child("MovementController", true, false)
	if _flight_state == null:
		_flight_state = get_tree().get_root().find_child("FlightState",        true, false)
	if _suit_visuals == null:
		_suit_visuals = get_tree().get_root().find_child("SuitModel",          true, false)


func _poll_flight() -> void:
	if not _all_suit_nodes_found:
		_find_suit_nodes()
		_all_suit_nodes_found = (_suit_body != null and _move_ctrl != null
				and _flight_state != null and _suit_visuals != null)
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
	var thermal_norm: float = clampf(thermal_raw / _THERMAL_MAX_OUTPUT, 0.0, 1.0)

	# Attitude gyro — body orientation only; flight path angle is not attitude
	var pitch_deg: float = rad_to_deg((_suit_body as Node3D).rotation.x)
	var bank_deg:  float = rad_to_deg((_suit_body as Node3D).rotation.z)

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

	if not _flight_panels_bound:
		_bind_fp()
		_bind_gp()
		_bind_pr()
		_bind_gr()
		_flight_panels_bound = (_fp_panel != null and _gp_panel != null
				and _pr_panel != null and _gr_panel != null)

	_sync_fp_nodes(flight_payload)
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


# ── Power router panel ───────────────────────────────────────────────────────

func _bind_pr() -> void:
	if _pr_panel != null:
		return
	_pr_panel = get_tree().get_root().find_child("PowerRouterPanel", true, false) as Control
	if _pr_panel == null:
		return

	_pr_dial = _pr_panel.find_child("PRDial", true, false)

	var close_btn := _pr_panel.find_child("CloseBtn", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(_on_pr_close)

	var header := _pr_panel.find_child("Header", true, false) as ColorRect
	if header:
		header.gui_input.connect(_on_pr_header_input)

	if _pr_dial and not _pr_dial.is_connected("routes_changed", _on_pr_routes_changed):
		_pr_dial.connect("routes_changed", _on_pr_routes_changed)

	if _power_modules.size() > 0:
		_sync_pr_nodes(_power_modules, _power_capacity)


func _sync_pr_nodes(modules: Array, capacity: float) -> void:
	if _pr_panel == null:
		return
	if _pr_dial and _pr_dial.has_method("update_state"):
		_pr_dial.call("update_state", modules, capacity)


func _on_pr_routes_changed(routes: Dictionary) -> void:
	_power_routes = routes
	EventBus.power_routes_changed.emit(routes)
	_broadcast({"type": "power_route", "routes": routes})


func _on_pr_close() -> void:
	if _pr_panel:
		_pr_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_pr_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pr_dragging = event.pressed
		if event.pressed and _pr_panel:
			_pr_drag_offset = _pr_panel.get_global_mouse_position() - _pr_panel.global_position


# ── Gas router panel ──────────────────────────────────────────────────────────

func _bind_gr() -> void:
	if _gr_panel != null:
		return
	_gr_panel = get_tree().get_root().find_child("GasRouterPanel", true, false) as Control
	if _gr_panel == null:
		return

	_gr_dial = _gr_panel.find_child("GRDial", true, false)

	var close_btn := _gr_panel.find_child("CloseBtn", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(_on_gr_close)

	var header := _gr_panel.find_child("Header", true, false) as ColorRect
	if header:
		header.gui_input.connect(_on_gr_header_input)

	if _gr_dial and not _gr_dial.is_connected("routes_changed", _on_gr_routes_changed):
		_gr_dial.connect("routes_changed", _on_gr_routes_changed)

	if _gas_modules.size() > 0:
		_sync_gr_nodes(_gas_modules, _gas_pressure)


func _sync_gr_nodes(modules: Array, tank_pressure: float) -> void:
	if _gr_panel == null:
		return
	if _gr_dial and _gr_dial.has_method("update_state"):
		_gr_dial.call("update_state", modules, tank_pressure)


func _on_gr_routes_changed(routes: Dictionary) -> void:
	_gas_routes = routes
	EventBus.gas_routes_changed.emit(routes)
	_broadcast({"type": "gas_route", "routes": routes})


func _on_gr_close() -> void:
	if _gr_panel:
		_gr_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_gr_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_gr_dragging = event.pressed
		if event.pressed and _gr_panel:
			_gr_drag_offset = _gr_panel.get_global_mouse_position() - _gr_panel.global_position


# ── Inspector detail panel ────────────────────────────────────────────────────

func _bind_dp() -> void:
	if _dp_panel != null:
		return
	_dp_panel = get_tree().get_root().find_child("InspectorDetailPanel", true, false) as Control
	if _dp_panel == null:
		return

	_dp_label   = _dp_panel.find_child("IDLabel",   true, false) as Label
	_dp_preview = _dp_panel.find_child("IDPreview", true, false) as TextureRect

	var close_btn := _dp_panel.find_child("IDCloseBtn", true, false) as Button
	if close_btn:
		close_btn.pressed.connect(_on_dp_close)

	var header := _dp_panel.find_child("IDHeader", true, false) as ColorRect
	if header:
		header.gui_input.connect(_on_dp_header_input)


func _sync_dp(label: String) -> void:
	if _preview_integrated:
		if _inline_preview and _detail_viewport:
			_inline_preview.texture = _detail_viewport.get_texture()
		if _inline_preview:
			_inline_preview.visible = true
		if _inline_sep:
			_inline_sep.visible = true
	else:
		if _dp_panel == null:
			return
		if _dp_label:
			_dp_label.text = label
		if _dp_preview and _detail_viewport:
			_dp_preview.texture = _detail_viewport.get_texture()
		_dp_panel.visible = true


func _on_preview_toggle() -> void:
	_preview_integrated = not _preview_integrated
	if _ui_toggle:
		_ui_toggle.text = "⊟" if _preview_integrated else "⊞"
	if _preview_integrated:
		if _dp_panel:
			_dp_panel.visible = false
		if _selected_index >= 0 and _detail_viewport:
			if _inline_preview:
				_inline_preview.texture = _detail_viewport.get_texture()
				_inline_preview.visible = true
			if _inline_sep:
				_inline_sep.visible = true
	else:
		if _inline_preview:
			_inline_preview.visible = false
		if _inline_sep:
			_inline_sep.visible = false
		if _selected_index >= 0 and _detail_viewport:
			_bind_dp()
			_sync_dp(_items[_selected_index].get("label", ""))


func _on_dp_close() -> void:
	if _dp_panel:
		_dp_panel.visible = false


func _on_dp_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dp_dragging = event.pressed
		if event.pressed and _dp_panel:
			_dp_drag_offset = _dp_panel.get_global_mouse_position() - _dp_panel.global_position
