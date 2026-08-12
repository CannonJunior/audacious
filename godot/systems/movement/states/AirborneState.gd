class_name AirborneState
extends Node
## Handles ballistic arc after jumping or falling off a ledge.
## Limited air-steering is available; gravity is applied by MovementController.

const SuitStats = preload("res://data/SuitStats.gd")
const SuitInputState = preload("res://network/SuitInputState.gd")

const AIR_CONTROL    := 0.07    # fraction of full ground control available mid-air

var _suit  # SuitBody, set in _ready

func _ready() -> void:
	_suit = get_parent().get_parent()

## Called by MovementController when initiating a jump from the ground.
func initiate_jump(stats: SuitStats) -> void:
	# v₀ = √(2gh) derived from kinematics
	_suit.velocity.y = sqrt(2.0 * 9.8 * stats.jump_height)
	EventBus.suit_launched.emit(_suit.global_position)

func tick(delta: float, input: SuitInputState) -> void:
	var stats          = _suit.get_stats()
	if _suit.camera_rig == null:
		return
	var h_basis: Basis = _suit.camera_rig.get_horizontal_basis()

	# Limited horizontal steering in air — target speed is never less than current
	# speed so jumping doesn't kill momentum; only redirects it.
	if input.move_direction.length_squared() > 0.01:
		var wish_dir := h_basis * Vector3(input.move_direction.x, 0.0, -input.move_direction.y)
		wish_dir = wish_dir.normalized()
		var current_hspeed := Vector2(_suit.velocity.x, _suit.velocity.z).length()
		var air_speed: float = maxf(stats.boost_speed * AIR_CONTROL, current_hspeed)
		_suit.velocity.x = lerpf(_suit.velocity.x, wish_dir.x * air_speed, 0.12)
		_suit.velocity.z = lerpf(_suit.velocity.z, wish_dir.z * air_speed, 0.12)
	# (Gravity applied by MovementController._process_transitions in AIRBORNE branch)
