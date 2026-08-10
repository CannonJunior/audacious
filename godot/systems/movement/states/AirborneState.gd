class_name AirborneState
extends Node
## Handles ballistic arc after jumping or falling off a ledge.
## Limited air-steering is available; gravity is applied by MovementController.

const SuitStats = preload("res://data/SuitStats.gd")
const SuitInputState = preload("res://network/SuitInputState.gd")

const AIR_CONTROL    := 0.07    # fraction of full ground control available mid-air
const FLIGHT_HOLD_THRESHOLD := 0.25  # seconds boost must be held before flight activates

var _suit  # SuitBody, set in _ready
var _boost_hold_timer: float = 0.0

func _ready() -> void:
	_suit = get_parent().get_parent()

## Called by MovementController when initiating a jump from the ground.
func initiate_jump(stats: SuitStats) -> void:
	# v₀ = √(2gh) derived from kinematics
	_suit.velocity.y = sqrt(2.0 * 9.8 * stats.jump_height)
	_boost_hold_timer = 0.0
	EventBus.suit_launched.emit(_suit.global_position)

## Returns true once the player has held boost long enough to enter flight intentionally.
func can_enter_flight() -> bool:
	return _boost_hold_timer >= FLIGHT_HOLD_THRESHOLD

func tick(delta: float, input: SuitInputState) -> void:
	# Track how long boost has been held for flight activation threshold
	if input.boost_held:
		_boost_hold_timer += delta
	else:
		_boost_hold_timer = 0.0

	var stats          = _suit.get_stats()
	var h_basis: Basis = _suit.camera_rig.get_horizontal_basis()

	# Limited horizontal steering in air
	if input.move_direction.length_squared() > 0.01:
		var wish_dir := h_basis * Vector3(input.move_direction.x, 0.0, -input.move_direction.y)
		wish_dir = wish_dir.normalized()
		var air_speed: float = stats.boost_speed * AIR_CONTROL
		_suit.velocity.x = lerpf(_suit.velocity.x, wish_dir.x * air_speed, 0.12)
		_suit.velocity.z = lerpf(_suit.velocity.z, wish_dir.z * air_speed, 0.12)
	# (Gravity applied by MovementController._process_transitions in AIRBORNE branch)
