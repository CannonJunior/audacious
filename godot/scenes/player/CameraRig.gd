class_name CameraRig
extends Node3D
## Third-person camera with SpringArm collision avoidance, mouse look,
## and speed-sensitive FOV. Uses top_level=true so parent (SuitBody)
## transforms are ignored; follows via global_position lerp in _process.

const MovementController = preload("res://systems/movement/MovementController.gd")
const SuitStats = preload("res://data/SuitStats.gd")

const FOLLOW_SPEED   := 10.0
const PITCH_MIN_DEG  := -70.0
const PITCH_MAX_DEG  :=  60.0
const FOV_DEFAULT    := 75.0
const FOV_SPRINT     := 85.0
const FOV_FLIGHT     := 90.0
const FOV_LERP_SPEED := 6.0

var _yaw: float   = 0.0
var _pitch: float = 0.0
var _suit  # SuitBody, set in _ready
var _current_fov: float = FOV_DEFAULT

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	_suit = get_parent()
	global_position = _suit.global_position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := GameSettings.mouse_sensitivity * 0.1
		_yaw  -= event.relative.x * sens
		var pitch_delta: float = event.relative.y * sens
		if GameSettings.invert_y:
			pitch_delta = -pitch_delta
		_pitch = clampf(_pitch + pitch_delta, deg_to_rad(PITCH_MIN_DEG), deg_to_rad(PITCH_MAX_DEG))

	elif event.is_action_pressed("pause"):
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED
		)

func _process(delta: float) -> void:
	# Soft-follow the suit's world position
	global_position = global_position.lerp(_suit.global_position, FOLLOW_SPEED * delta)

	# Apply look rotation (yaw on this node, pitch on spring arm pivot)
	rotation.y = _yaw
	spring_arm.rotation.x = _pitch

	# Speed-sensitive FOV
	var speed: float = _suit.velocity.length()
	var target_fov := FOV_DEFAULT
	if _suit.movement_controller.current_state == MovementController.State.FLIGHT:
		target_fov = lerpf(FOV_DEFAULT, FOV_FLIGHT, clampf(speed / SuitStats.MAX_BOOST_SPEED, 0.0, 1.0))
	elif speed > SuitStats.MAX_GROUND_SPEED * 1.2:
		target_fov = FOV_SPRINT
	_current_fov = lerpf(_current_fov, target_fov, FOV_LERP_SPEED * delta)
	camera.fov = _current_fov

## Returns a Basis rotated only around Y (yaw) for horizontal movement calculations.
func get_horizontal_basis() -> Basis:
	return Basis(Vector3.UP, _yaw)

## Returns pitch in radians. Positive = looking down.
func get_pitch() -> float:
	return _pitch
