class_name FlightState
extends Node
## Active powered flight. Delegates velocity computation to FlightController.
## Tracks hover energy — when exhausted and boost not held, falls back to airborne.

const FlightController = preload("res://systems/movement/FlightController.gd")
const SuitInputState = preload("res://network/SuitInputState.gd")

const ENERGY_DRAIN_BASE := 0.25  # energy fraction drained per second at load_ratio 0

var _suit           # SuitBody, set in _ready
var _flight_controller: FlightController
var _hover_energy: float = 1.0   # 0.0–1.0

func _ready() -> void:
	_suit              = get_parent().get_parent()
	_flight_controller = _suit.get_node("FlightController") as FlightController

## Called by MovementController when transitioning into this state.
func enter(current_velocity: Vector3) -> void:
	_hover_energy = 1.0
	EventBus.boost_activated.emit(current_velocity.normalized())

func is_exhausted() -> bool:
	return _hover_energy <= 0.0

func tick(delta: float, input: SuitInputState) -> void:
	var stats = _suit.get_stats()

	# Drain energy faster at higher load (heavier suits burn fuel sooner)
	var drain_rate: float = ENERGY_DRAIN_BASE * (1.0 + stats.load_ratio)
	if stats.hover_duration > 0.0 and not is_inf(stats.hover_duration):
		drain_rate = 1.0 / stats.hover_duration
	elif is_inf(stats.hover_duration):
		drain_rate = 0.0

	_hover_energy = clampf(_hover_energy - drain_rate * delta, 0.0, 1.0)

	_suit.velocity = _flight_controller.compute_flight_velocity(
		_suit.velocity, input, stats, _suit.camera_rig, delta
	)
