class_name SuitBody
extends CharacterBody3D
## The player's suited form. Physics body, movement entry point, and stat source.
## apply_input() is the single entry point for both human and AI agent input.

const SuitConfiguration  = preload("res://data/SuitConfiguration.gd")
const CameraRig          = preload("res://scenes/player/CameraRig.gd")
const MovementController = preload("res://systems/movement/MovementController.gd")
const FlightController   = preload("res://systems/movement/FlightController.gd")
const SuitInputState     = preload("res://network/SuitInputState.gd")
const SuitStats          = preload("res://data/SuitStats.gd")
const SuitPresets        = preload("res://data/SuitPresets.gd")

const SAVE_PATH := "user://suit_config.tres"

var configuration: SuitConfiguration
var camera_rig:    CameraRig          # assigned in _ready() to keep @onready sequence intact

@onready var movement_controller: MovementController = $MovementController
@onready var flight_controller:   FlightController   = $FlightController


func _ready() -> void:
	var cr := get_node_or_null("CameraRig")
	if cr is CameraRig:
		camera_rig = cr
	elif cr == null:
		push_error("SuitBody: no child named 'CameraRig' — children: %s" % [str(get_children().map(func(n): return n.name))])
	else:
		push_error("SuitBody: CameraRig child is %s (script=%s), expected CameraRig script" % [cr.get_class(), str(cr.get_script())])

	if ResourceLoader.exists(SAVE_PATH):
		configuration = ResourceLoader.load(SAVE_PATH) as SuitConfiguration
	if configuration == null:
		configuration = SuitPresets.scout()
	if configuration == null:
		push_error("SuitBody: configuration is null after fallback — SuitPresets.scout() failed")

	EventBus.configuration_changed.connect(_on_configuration_changed)
	# Deferred so SuitWorkshop (a sibling/child of HUD) has connected its listener first.
	call_deferred("_emit_initial_config")


func _emit_initial_config() -> void:
	if configuration == null:
		return
	EventBus.configuration_changed.emit(configuration)
	EventBus.suit_stats_updated.emit(configuration.get_stats())


func _physics_process(delta: float) -> void:
	# Server runs physics for all players. Clients only run their own.
	var nm := NetworkManager
	if nm != null and nm.mode != nm.NetMode.OFFLINE and not nm.is_server():
		if get_parent().get("player_id") != nm.local_player_id:
			return
	movement_controller.tick(delta)
	move_and_slide()
	EventBus.speed_changed.emit(Vector3(velocity.x, 0.0, velocity.z).length())


## Single input entry point — human InputManager and AI agent both call this.
func apply_input(state: SuitInputState) -> void:
	movement_controller.handle_input(state)


func get_stats() -> SuitStats:
	if configuration == null:
		push_error("SuitBody.get_stats: configuration is null")
		return SuitStats.new()
	return configuration.get_stats()


func set_configuration(config: SuitConfiguration) -> void:
	configuration = config
	EventBus.configuration_changed.emit(config)
	EventBus.suit_stats_updated.emit(config.get_stats())

## Apply a preset for in-session testing without writing it to the save file.
func apply_debug_preset(config: SuitConfiguration) -> void:
	_skip_next_save = true
	set_configuration(config)

var _skip_next_save: bool = false

func _on_configuration_changed(cfg: SuitConfiguration) -> void:
	configuration = cfg
	_apply_color_to_visuals(cfg)
	if _skip_next_save:
		_skip_next_save = false
		return
	ResourceSaver.save(cfg, SAVE_PATH)


func _apply_color_to_visuals(cfg: SuitConfiguration) -> void:
	var visuals: MeshInstance3D = $Visuals
	if visuals == null:
		return
	var mat: Material = visuals.material_override
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_color = cfg.color_primary
