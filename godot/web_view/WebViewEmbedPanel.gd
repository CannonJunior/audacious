extends Control
## Displays a WebKit2 off-screen HTML panel as a live texture and forwards
## Godot mouse events back to the page via WebViewBridge.send_pointer().
##
## The off-screen renderer (webview_server.py) exports frames as PNG files.
## This node polls the file's modification time each frame and reloads only
## when it has changed, keeping GPU uploads minimal.
##
## Coordinate mapping: Godot panel pixels are scaled to HTML page pixels using
## the loaded image dimensions, so the panel can be any display size.

## Absolute path to the PNG file exported by webview_server.py.
@export var frame_path: String = ""
## Must match the 'page' field expected by the HTML's injectPointer() handler.
@export var page_name:  String = ""

const _DEMAND_PATH := "/tmp/godot_webview_demand"

var _tex:          ImageTexture = ImageTexture.new()
var _last_mtime:   int  = 0
var _panel_drag:   bool = false
var _drag_offset:  Vector2 = Vector2.ZERO
var _embed_active: bool = false   # true while a left-button drag started in the embed rect
var _demand_timer: float = 0.0

@onready var _tex_rect: TextureRect = $VBox/EmbedRect
@onready var _header:   Control     = $VBox/Header

func _ready() -> void:
	_tex_rect.texture = _tex
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.gui_input.connect(_on_header_input)
	$VBox/Header/CloseBtn.pressed.connect(_on_close)

func _process(delta: float) -> void:
	if visible:
		_demand_timer += delta
		if _demand_timer >= 1.0:
			_demand_timer = 0.0
			var f := FileAccess.open(_DEMAND_PATH, FileAccess.WRITE)
			if f:
				f.store_string("")
				f.close()
	if frame_path.is_empty() or not FileAccess.file_exists(frame_path):
		return
	var mtime := FileAccess.get_modified_time(frame_path)
	if mtime == _last_mtime:
		return
	_last_mtime = mtime
	var img := Image.load_from_file(frame_path)
	if img:
		_tex.set_image(img)

func _input(event: InputEvent) -> void:
	# Panel dragging — continued in _input so motion works outside the header rect.
	if _panel_drag:
		if event is InputEventMouseButton and not event.pressed:
			_panel_drag = false
		elif event is InputEventMouseMotion:
			var np := get_global_mouse_position() - _drag_offset
			var vp := get_viewport_rect().size
			position = Vector2(
				clampf(np.x, 0.0, vp.x - size.x),
				clampf(np.y, 0.0, vp.y - size.y))
		return

	# Embed pointer forwarding.
	var embed_rect := _tex_rect.get_global_rect()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and embed_rect.has_point(event.global_position):
			_embed_active = true
			_forward_pointer("mousedown", event.global_position)
		elif not event.pressed and _embed_active:
			_embed_active = false
			_forward_pointer("mouseup", event.global_position)

	elif event is InputEventMouseMotion:
		var in_embed := embed_rect.has_point(event.global_position)
		if _embed_active or in_embed:
			_forward_pointer("mousemove", event.global_position)

func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_panel_drag  = true
			_drag_offset = get_global_mouse_position() - global_position

func _on_close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ── Helpers ───────────────────────────────────────────────────────────────────

func _forward_pointer(subtype: String, global_pos: Vector2) -> void:
	if _tex.get_width() == 0 or _tex.get_height() == 0 or page_name.is_empty():
		return
	var embed_rect := _tex_rect.get_global_rect()
	var rel        := global_pos - embed_rect.position
	var px := int(rel.x * float(_tex.get_width())  / embed_rect.size.x)
	var py := int(rel.y * float(_tex.get_height()) / embed_rect.size.y)
	WebViewBridge.send_pointer(page_name, subtype, px, py)
