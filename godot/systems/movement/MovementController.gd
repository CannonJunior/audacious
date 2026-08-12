class_name MovementController
extends Node
## State machine orchestrating all suit movement.
## Owns transitions; delegates per-frame physics to state child nodes.
## Gravity is applied exclusively inside each state — never here.

const SuitInputState = preload("res://network/SuitInputState.gd")
const GroundedState = preload("res://systems/movement/states/GroundedState.gd")
const AirborneState = preload("res://systems/movement/states/AirborneState.gd")
const FlightState = preload("res://systems/movement/states/FlightState.gd")

enum State { GROUNDED, AIRBORNE, FLIGHT }

const GRAVITY     := 9.8
const TURN_SPEED  := 2.62   # radians/s ≈ 150°/s

var current_state: State = State.GROUNDED

var _suit  # SuitBody, set in _ready
var _pending_input: SuitInputState = SuitInputState.new()

@onready var grounded_state: GroundedState = $GroundedState
@onready var airborne_state: AirborneState = $AirborneState
@onready var flight_state:   FlightState   = $FlightState

func _ready() -> void:
	_suit = get_parent()

## Called by SuitBody.apply_input() — stores input for consumption next tick.
func handle_input(state: SuitInputState) -> void:
	_pending_input = state

## Called from SuitBody._physics_process() before move_and_slide().
func tick(delta: float) -> void:
	var input := _pending_input
	_pending_input = SuitInputState.new()

	# Rotate the suit body before movement so wish_dir uses the updated facing.
	if input.turn_delta != 0.0:
		_suit.rotation.y += input.turn_delta * TURN_SPEED * delta

	_process_transitions(input, delta)

	match current_state:
		State.GROUNDED: grounded_state.tick(delta, input)
		State.AIRBORNE: airborne_state.tick(delta, input)
		State.FLIGHT:   flight_state.tick(delta, input)

func _process_transitions(input: SuitInputState, delta: float) -> void:
	var on_floor: bool = _suit.is_on_floor()
	var stats          = _suit.get_stats()

	match current_state:
		State.GROUNDED:
			if not on_floor:
				# Walked off a ledge — enter airborne without jump velocity
				_transition(State.AIRBORNE)
			elif input.boost_pressed:
				airborne_state.initiate_jump(stats)
				_transition(State.AIRBORNE)

		State.AIRBORNE:
			if on_floor:
				_on_land()
			elif stats.flight_available and input.boost_pressed:
				flight_state.enter(_suit.velocity)
				_transition(State.FLIGHT)
			else:
				_suit.velocity.y -= GRAVITY * delta

		State.FLIGHT:
			if on_floor:
				_on_land()
			elif not stats.flight_available:
				# Suit no longer supports flight (preset changed mid-air)
				_transition(State.AIRBORNE)
			elif flight_state.is_exhausted() and not input.boost_held:
				_transition(State.AIRBORNE)

func _transition(new_state: State) -> void:
	current_state = new_state
	EventBus.suit_state_changed.emit(State.keys()[new_state], _suit.global_position)

func _on_land() -> void:
	var stats = _suit.get_stats()
	_suit.velocity.y = 0.0
	_transition(State.GROUNDED)
	EventBus.suit_landed.emit(_suit.global_position, stats.thermal_output)
