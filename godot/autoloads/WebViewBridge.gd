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

var _ui_panel:          Control  = null
var _ui_status:         Label    = null
var _ui_list:           ItemList = null
var _panel_dragging:    bool     = false
var _panel_drag_offset: Vector2  = Vector2.ZERO
var _ever_connected:    bool     = false


func _ready() -> void:
	OS.execute("fuser", ["-k", "%d/tcp" % WS_PORT])
	var script := ProjectSettings.globalize_path("res://web_view/webview_server.py")
	OS.create_process("python3", [script])
	var err := _tcp.listen(WS_PORT)
	if err != OK:
		push_error("WebViewBridge: TCPServer failed on port %d (%s)" % [WS_PORT, error_string(err)])
		set_process(false)


func _exit_tree() -> void:
	for peer in _peers.values():
		(peer as WebSocketPeer).close()
	_tcp.stop()


func _process(_delta: float) -> void:
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


func _input(event: InputEvent) -> void:
	if not _panel_dragging or _ui_panel == null or not _ui_panel.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_panel_dragging = false
	elif event is InputEventMouseMotion:
		var np := _ui_panel.get_global_mouse_position() - _panel_drag_offset
		var vp := _ui_panel.get_viewport_rect().size
		_ui_panel.position = Vector2(clampf(np.x, 0.0, vp.x - _ui_panel.size.x),
		                             clampf(np.y, 0.0, vp.y - _ui_panel.size.y))


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


# ── Panel binding ─────────────────────────────────────────────────────────────

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
