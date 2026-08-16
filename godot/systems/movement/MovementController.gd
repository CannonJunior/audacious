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
const ROLL_SPEED         := 2.09   # radians/s ≈ 120°/s
const ROLL_CORRECT_SPEED  := 0.52   # radians/s ≈  30°/s — gradual auto-level on force-land
const LAND_DESCENT_SPEED  := 20.0   # m/s downward applied on force-land
# Banked-turn rate: yaw contributed per second at 90° bank and full boost speed.
# At 60° bank (sin≈0.87) and max speed this produces ≈174°/s; at 90° bank ≈200°/s.
const BANK_TURN_RATE      := 3.49   # radians/s

var current_state: State = State.GROUNDED
var _correcting_roll: bool = false

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
	if input.roll_delta != 0.0:
		_correcting_roll = false
		_suit.rotation.z += input.roll_delta * ROLL_SPEED * delta
	elif _correcting_roll:
		_suit.rotation.z = move_toward(_suit.rotation.z, 0.0, _roll_correct_speed() * delta)
		if is_zero_approx(_suit.rotation.z):
			_correcting_roll = false

	# Banked turn: during flight, roll angle drives yaw proportional to horizontal speed.
	# Mirrors a coordinated aircraft turn — ω = BANK_TURN_RATE × sin(φ) × (v / v_max).
	# sign: positive rotation.z = bank right → yaw right = decrease rotation.y
	if current_state == State.FLIGHT and not is_zero_approx(_suit.rotation.z):
		var hspeed: float = Vector2(_suit.velocity.x, _suit.velocity.z).length()
		var boost_speed: float = maxf(_suit.get_stats().boost_speed, 1.0)
		var speed_ratio: float = clampf(hspeed / boost_speed, 0.0, 1.0)
		_suit.rotation.y -= sin(_suit.rotation.z) * BANK_TURN_RATE * speed_ratio * delta

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
			elif input.land_pressed or not stats.flight_available:
				if input.land_pressed:
					_correcting_roll = true
					_suit.velocity.y = -LAND_DESCENT_SPEED
				_transition(State.AIRBORNE)
			elif flight_state.is_exhausted() and not input.boost_held:
				_transition(State.AIRBORNE)

func _roll_correct_speed() -> float:
	# Cast a ray straight down to find how far the ground is.
	var space := (_suit as Node3D).get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		(_suit as Node3D).global_position,
		(_suit as Node3D).global_position + Vector3.DOWN * 500.0
	)
	query.exclude = [_suit.get_rid()]
	var hit := space.intersect_ray(query)
	var distance := 500.0
	if hit:
		distance = (_suit as Node3D).global_position.distance_to(hit.position)

	# Use downward speed to estimate time remaining before touchdown.
	var fall_speed := maxf(absf(_suit.velocity.y), 1.0)
	var time_to_land := distance / fall_speed

	# Speed needed to finish levelling exactly at landing, clamped to sane range.
	return clampf(absf(_suit.rotation.z) / maxf(time_to_land, 0.05), ROLL_CORRECT_SPEED, ROLL_SPEED)


func _transition(new_state: State) -> void:
	current_state = new_state
	EventBus.suit_state_changed.emit(State.keys()[new_state], _suit.global_position)

func _on_land() -> void:
	var stats = _suit.get_stats()
	_suit.velocity.y = 0.0
	_suit.rotation.z = 0.0
	_correcting_roll = false
	_transition(State.GROUNDED)
	EventBus.suit_landed.emit(_suit.global_position, stats.thermal_output)
