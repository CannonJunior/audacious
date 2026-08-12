extends CanvasLayer
## Owns HUD-level keyboard input. Simple node with no sub-scene deps —
## guaranteed to receive _input() even if child panel scenes fail to load.

var _ops:        Node = null  # OperationsCenter; typed Node to avoid class-cache dep
var _web_panel:  Node = null  # WebViewPanel

func _ready() -> void:
	_ops = get_node_or_null("OperationsCenter")
	if _ops == null:
		var scene: PackedScene = ResourceLoader.load(
			"res://heist_planner/scenes/OperationsCenter.tscn")
		if scene:
			_ops = scene.instantiate()
			_ops.name = "OperationsCenter"
			add_child(_ops)
		else:
			push_error("HUDController: OperationsCenter.tscn failed to load")
	_web_panel = get_node_or_null("WebViewPanel")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_scene_inspector"):
		if _web_panel:
			var show: bool = not _web_panel.visible
			_web_panel.visible = show
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_mission_board"):
		if _ops:
			var show: bool = not _ops.visible
			if _ops.has_method("_set_visible"):
				_ops.call("_set_visible", show)
			else:
				_ops.visible = show
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
