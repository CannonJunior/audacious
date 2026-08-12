class_name GroundedState
extends Node
## Handles all on-floor movement: walking, sprinting, slope handling.

const SuitInputState = preload("res://network/SuitInputState.gd")

const FRICTION      := 14.0   # higher = snappier stops
const SPRINT_MULT   := 1.6    # sprint speed multiplier

var _suit  # SuitBody, set in _ready

func _ready() -> void:
	_suit = get_parent().get_parent()

func tick(delta: float, input: SuitInputState) -> void:
	var stats = _suit.get_stats()
	if _suit.camera_rig == null:
		return
	var h_basis: Basis = _suit.camera_rig.get_horizontal_basis()

	# Project WASD onto the camera's horizontal plane
	var wish_dir := Vector3.ZERO
	if input.move_direction.length_squared() > 0.01:
		wish_dir = h_basis * Vector3(input.move_direction.x, 0.0, -input.move_direction.y)
		wish_dir = wish_dir.normalized()

	var speed: float = stats.ground_sprint_speed
	if input.sprint_held:
		speed *= SPRINT_MULT

	var target: Vector3 = wish_dir * speed

	# Rapid deceleration toward target — feels responsive on the ground
	_suit.velocity.x = lerpf(_suit.velocity.x, target.x, FRICTION * delta)
	_suit.velocity.z = lerpf(_suit.velocity.z, target.z, FRICTION * delta)

	# Keep the character pressed onto slopes so is_on_floor() stays true
	if _suit.is_on_floor():
		_suit.velocity.y = 0.0
	else:
		# Brief drop after walking off a micro-ledge; MovementController handles full fall
		_suit.velocity.y -= 9.8 * delta
