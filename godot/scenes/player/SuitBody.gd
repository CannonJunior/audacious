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
var camera_rig: CameraRig

@onready var movement_controller: MovementController = $MovementController
@onready var flight_controller:   FlightController   = $FlightController


func _ready() -> void:
	camera_rig = $CameraRig

	if ResourceLoader.exists(SAVE_PATH):
		configuration = ResourceLoader.load(SAVE_PATH) as SuitConfiguration
	if configuration == null:
		configuration = SuitPresets.scout()

	EventBus.configuration_changed.connect(_on_configuration_changed)
	# Deferred so SuitWorkshop (a sibling/child of HUD) has connected its listener first.
	call_deferred("_emit_initial_config")


func _emit_initial_config() -> void:
	EventBus.configuration_changed.emit(configuration)
	EventBus.suit_stats_updated.emit(configuration.get_stats())


func _physics_process(delta: float) -> void:
	movement_controller.tick(delta)
	move_and_slide()
	EventBus.speed_changed.emit(Vector3(velocity.x, 0.0, velocity.z).length())


## Single input entry point — human InputManager and AI agent both call this.
func apply_input(state: SuitInputState) -> void:
	movement_controller.handle_input(state)


func get_stats() -> SuitStats:
	return configuration.get_stats()


func set_configuration(config: SuitConfiguration) -> void:
	configuration = config
	EventBus.configuration_changed.emit(config)
	EventBus.suit_stats_updated.emit(config.get_stats())


func _on_configuration_changed(cfg: SuitConfiguration) -> void:
	configuration = cfg
	_apply_color_to_visuals(cfg)
	ResourceSaver.save(cfg, SAVE_PATH)


func _apply_color_to_visuals(cfg: SuitConfiguration) -> void:
	var visuals: MeshInstance3D = $Visuals
	if visuals == null:
		return
	var mat: Material = visuals.material_override
	if mat is StandardMaterial3D:
		(mat as StandardMaterial3D).albedo_color = cfg.color_primary
