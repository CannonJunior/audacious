class_name CameraRig
extends Node3D
## Third-person camera with SpringArm collision avoidance, mouse look,
## and speed-sensitive FOV. Uses top_level=true so parent (SuitBody)
## transforms are ignored; follows via global_position lerp in _process.

const MovementController = preload("res://systems/movement/MovementController.gd")
const SuitStats = preload("res://data/SuitStats.gd")

const FOLLOW_SPEED   := 10.0
const FOV_LERP_SPEED := 6.0
# FOV values are offsets/ratios relative to GameSettings.camera_fov.
const FOV_SPRINT_BONUS := 10.0   # added on top of base FOV while sprinting
const FOV_FLIGHT_BONUS := 15.0   # added on top of base FOV at max boost speed

# Fixed camera angle: slight downward look, positioned directly behind the suit.
# Negative pitch = camera above the suit looking down; below dive-bonus threshold (0.25 rad).
const FIXED_PITCH := -0.22   # radians ≈ 12.5° downward

# Z-reach of the spring arm (spring_length * cos(FIXED_PITCH) ≈ 5 * 0.976).
# Lag must stay below this so the suit never overtakes the camera.
const SPRING_Z_REACH := 4.5  # metres, conservative

var _suit  # SuitBody, set in _ready
var _current_fov: float = 75.0   # initialised from GameSettings in _ready

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	_suit = get_parent()
	global_position = _suit.global_position
	_current_fov = GameSettings.camera_fov
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	# Scale follow speed so the lag never exceeds the spring arm's backward reach.
	# At boost speed (60 m/s) the default FOLLOW_SPEED of 10 produces ~6 m of lag,
	# which lets the suit overtake the camera; clamping lag to SPRING_Z_REACH prevents this.
	var suit_speed: float  = _suit.velocity.length()
	var follow_speed: float = maxf(FOLLOW_SPEED, suit_speed / SPRING_Z_REACH * 1.2)
	global_position = global_position.lerp(_suit.global_position, minf(follow_speed * delta, 1.0))

	# Stay directly behind the suit — PI offset places the spring arm on the opposite
	# side of the suit's facing direction so the camera is always at the suit's back.
	rotation.y = _suit.rotation.y + PI
	spring_arm.rotation.x = FIXED_PITCH

	# Speed-sensitive FOV — offsets relative to user's chosen base FOV.
	var speed: float = _suit.velocity.length()
	var base_fov: float = GameSettings.camera_fov
	var target_fov := base_fov
	if _suit.movement_controller.current_state == MovementController.State.FLIGHT:
		target_fov = base_fov + lerpf(0.0, FOV_FLIGHT_BONUS, clampf(speed / SuitStats.MAX_BOOST_SPEED, 0.0, 1.0))
	elif speed > SuitStats.MAX_GROUND_SPEED * 1.2:
		target_fov = base_fov + FOV_SPRINT_BONUS
	_current_fov = lerpf(_current_fov, target_fov, FOV_LERP_SPEED * delta)
	camera.fov = _current_fov

## Horizontal basis aligned to the suit's own facing — used by movement states.
func get_horizontal_basis() -> Basis:
	return Basis(Vector3.UP, _suit.rotation.y)

## Returns fixed camera pitch. Positive = looking down (below dive-bonus threshold).
func get_pitch() -> float:
	return FIXED_PITCH
