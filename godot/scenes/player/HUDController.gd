extends CanvasLayer
## Owns HUD-level keyboard input. Simple node with no sub-scene deps —
## guaranteed to receive _input() even if child panel scenes fail to load.

var _ops:          Node = null  # OperationsCenter; typed Node to avoid class-cache dep
var _web_panel:    Node = null  # WebViewPanel
var _flight_panel: Node = null  # FlightInstrumentsPanel
var _gyro_panel:   Node = null  # AttitudeGyroPanel
var _power_panel:  Node = null  # PowerRouterPanel
var _gas_panel:    Node = null  # GasRouterPanel

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
	_web_panel    = get_node_or_null("WebViewPanel")
	_flight_panel = get_node_or_null("FlightInstrumentsPanel")
	_gyro_panel   = get_node_or_null("AttitudeGyroPanel")
	_power_panel  = get_node_or_null("PowerRouterPanel")
	_gas_panel    = get_node_or_null("GasRouterPanel")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_scene_inspector"):
		_toggle_panel(_web_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_attitude_gyro"):
		_toggle_panel(_gyro_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_flight_instruments"):
		_toggle_panel(_flight_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_mission_board"):
		if _ops:
			var show: bool = not _ops.visible
			if _ops.has_method("_set_visible"):
				_ops.call("_set_visible", show)
			else:
				_toggle_panel(_ops)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_power_router"):
		_toggle_panel(_power_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_gas_router"):
		_toggle_panel(_gas_panel)
		get_viewport().set_input_as_handled()

func _toggle_panel(panel: Node) -> void:
	if panel == null:
		return
	var show: bool = not panel.visible
	panel.visible = show
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED
