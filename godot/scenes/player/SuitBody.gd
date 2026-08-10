class_name SuitBody
extends CharacterBody3D
## The player's suited form. Physics body, movement entry point, and stat source.
## apply_input() is the single entry point for both human and AI agent input.

const SuitConfiguration = preload("res://data/SuitConfiguration.gd")
const CameraRig = preload("res://scenes/player/CameraRig.gd")
const MovementController = preload("res://systems/movement/MovementController.gd")
const FlightController = preload("res://systems/movement/FlightController.gd")
const SuitInputState = preload("res://network/SuitInputState.gd")
const SuitStats = preload("res://data/SuitStats.gd")
const SuitPresets = preload("res://data/SuitPresets.gd")

var configuration: SuitConfiguration

## Set during _ready() from the sibling CameraRig node.
var camera_rig: CameraRig

@onready var movement_controller: MovementController = $MovementController
@onready var flight_controller: FlightController = $FlightController

func _ready() -> void:
	camera_rig = $CameraRig
	configuration = SuitPresets.scout()
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
