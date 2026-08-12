extends Node
## Bridges GDScript and an embedded web page rendered by webview_server.py.
## Runs a WebSocket server so the page receives live scene data and click
## events; the Python process serves HTTP and exports PNG frames for Godot.
##
## Usage:
##   WebViewBridge.register_item("My Label", {"key": "value"})
##   WebViewBridge.push_items()        # send current list to the web page
##   WebViewBridge.send_click(x, y)    # forward a click into the web page

signal item_selected(index: int, item: Dictionary)
signal items_changed(items: Array)

const WS_PORT := 9787

var _items: Array = []
var _ws          := WebSocketMultiplayerPeer.new()


func _ready() -> void:
	var err := _ws.create_server(WS_PORT)
	if err != OK:
		push_error("WebViewBridge: WebSocket server failed on port %d (%s)" % [WS_PORT, error_string(err)])
		return
	_ws.peer_connected.connect(_on_peer_connected)


func _exit_tree() -> void:
	_ws.close()


func _process(_delta: float) -> void:
	_ws.poll()
	while _ws.get_available_packet_count() > 0:
		var _from := _ws.get_packet_peer()
		var raw   := _ws.get_packet()
		_handle_message(raw.get_string_from_utf8())


# ── Public API ────────────────────────────────────────────────────────────────

func register_item(label: String, data: Dictionary = {}) -> void:
	_items.append({"label": label, "data": data})


func clear_items() -> void:
	_items.clear()


func get_items() -> Array:
	return _items.duplicate()


func push_items() -> void:
	_broadcast({"type": "items", "data": _items})
	items_changed.emit(_items.duplicate())


func send_click(x: int, y: int) -> void:
	_broadcast({"type": "click", "x": x, "y": y})


# ── Internal ──────────────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	_send_to(id, {"type": "items", "data": _items})


func _broadcast(obj: Dictionary) -> void:
	var buf := JSON.stringify(obj).to_utf8_buffer()
	_ws.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_ws.put_packet(buf)


func _send_to(peer_id: int, obj: Dictionary) -> void:
	var buf := JSON.stringify(obj).to_utf8_buffer()
	_ws.set_target_peer(peer_id)
	_ws.put_packet(buf)


func _handle_message(msg: String) -> void:
	var parsed = JSON.parse_string(msg)
	if not parsed is Dictionary:
		return
	match parsed.get("type"):
		"select":
			var idx := int(parsed.get("index", -1))
			if idx >= 0 and idx < _items.size():
				item_selected.emit(idx, _items[idx])
