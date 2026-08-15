class_name GroundedState
extends Node
## Handles all on-floor movement: walking, sprinting, slope handling.
## Forward speed (W/S) accumulates with acceleration so it builds to max over time.
## Strafe (Q/E) remains snappy with an instant lateral target.

const SuitInputState = preload("res://network/SuitInputState.gd")

const ACCELERATION  := 50.0   # m/s² — reaches full speed in ~4 s
const BRAKE_DECEL   := 90.0   # m/s² — stops from full speed in ~2.2 s
const SPRINT_MULT   :=  1.6   # speed multiplier while sprint held
const STRAFE_SPEED  := 12.0   # m/s  — instant lateral target
const STRAFE_SMOOTH := 12.0   # lerp factor for strafe blending

var _fwd_speed: float = 0.0   # current forward speed in suit-facing direction (m/s)

var _suit  # SuitBody, set in _ready

func _ready() -> void:
	_suit = get_parent().get_parent()

func tick(delta: float, input: SuitInputState) -> void:
	var stats = _suit.get_stats()

	var max_spd: float = stats.ground_sprint_speed
	if input.sprint_held:
		max_spd *= SPRINT_MULT

	# W/S: accumulate forward speed; no input: brake to a stop.
	var fwd_input := -input.move_direction.y   # W = +1, S = -1
	if absf(fwd_input) > 0.01:
		_fwd_speed = clampf(_fwd_speed + fwd_input * ACCELERATION * delta, -max_spd * 0.5, max_spd)
	else:
		_fwd_speed = move_toward(_fwd_speed, 0.0, BRAKE_DECEL * delta)

	# Suit-local axes in the horizontal plane.
	var suit_node := _suit as Node3D
	var fwd_dir  := suit_node.global_transform.basis.z
	fwd_dir.y    = 0.0
	fwd_dir      = fwd_dir.normalized() if fwd_dir.length_squared() > 0.001 else Vector3.ZERO

	var side_dir := suit_node.global_transform.basis.x
	side_dir.y   = 0.0
	side_dir     = side_dir.normalized() if side_dir.length_squared() > 0.001 else Vector3.ZERO

	# Combine forward momentum with instant lateral strafe target.
	var h_target := fwd_dir * _fwd_speed + side_dir * (input.move_direction.x * STRAFE_SPEED)

	_suit.velocity.x = lerpf(_suit.velocity.x, h_target.x, STRAFE_SMOOTH * delta)
	_suit.velocity.z = lerpf(_suit.velocity.z, h_target.z, STRAFE_SMOOTH * delta)

	# Keep the character pressed onto slopes so is_on_floor() stays true.
	if _suit.is_on_floor():
		_suit.velocity.y = 0.0
	else:
		# Brief drop after walking off a micro-ledge; MovementController handles full fall.
		_suit.velocity.y -= 9.8 * delta
