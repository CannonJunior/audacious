extends Node3D

const SUIT_SCENE_PATH := "res://assets/suit/iron_man.glb"

# ── Tuning ────────────────────────────────────────────────────────────────────
const SMOOTH            := 7.0   # lerp speed for root lean/bank values
const MAX_FWD_LEAN      := 90.0  # degrees, forward/back pitch at full boost speed
const MAX_SIDE_LEAN     :=  8.0  # degrees, lateral tilt on strafe
const MAX_BANK          := 10.0  # degrees, roll added on yaw input
const BANK_FACTOR       := 25.0  # bank degrees per rad/s of yaw
const BOB_AMP           :=  0.04 # metres, walk bob vertical amplitude
const BOB_FREQ          :=  2.4  # Hz at full sprint speed
const HOVER_AMP         :=  0.05 # metres, flight idle vertical oscillation
const HOVER_FREQ        :=  0.65 # Hz

const THRUSTER_SMOOTH   := 5.0   # lerp speed for thruster angle
const MAX_BACK_ANGLE    := 45.0  # degrees, back thruster pitch at full boost speed
const MAX_HAND_ANGLE    := 35.0  # degrees, hand repulsor pitch at full boost speed

# ── State ─────────────────────────────────────────────────────────────────────
var _suit_root: Node3D    = null
var _skeleton: Skeleton3D = null

var _lean_fwd:       float = 0.0
var _lean_side:      float = 0.0
var _bank:           float = 0.0
var _bob_phase:      float = 0.0
var _prev_rot_y:     float = 0.0
var _back_angle:     float = 0.0  # current back thruster rotation (degrees)
var _hand_angle:     float = 0.0  # current hand repulsor rotation (degrees)

var _bone_back_l: int = -1
var _bone_back_r: int = -1
var _bone_hand_l: int = -1
var _bone_hand_r: int = -1

@onready var _suit: SuitBody               = get_parent()
@onready var _movement: MovementController = $"../MovementController"

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	var doc  := GLTFDocument.new()
	var gltf := GLTFState.new()
	var path := ProjectSettings.globalize_path(SUIT_SCENE_PATH)
	var err  := doc.append_from_file(path, gltf)
	if err != OK:
		push_error("[SuitModelVisuals] Could not load suit model: " + SUIT_SCENE_PATH)
		return

	_suit_root = doc.generate_scene(gltf)
	add_child(_suit_root)
	_setup_skeleton()

	var placeholder := get_parent().get_node_or_null("Visuals")
	if placeholder:
		placeholder.visible = false

	_prev_rot_y = _suit.rotation.y

func _process(delta: float) -> void:
	if not _suit_root or not _movement or delta <= 0.0:
		return
	_animate(delta)

# ── Setup ─────────────────────────────────────────────────────────────────────

func _setup_skeleton() -> void:
	var found := _suit_root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("[SuitModelVisuals] No Skeleton3D found in loaded model.")
		return
	_skeleton = found[0] as Skeleton3D

	_bone_back_l = _skeleton.find_bone("FX_BackFire_L")
	_bone_back_r = _skeleton.find_bone("FX_BackFire_R")
	_bone_hand_l = _skeleton.find_bone("FX_Hand_L")
	_bone_hand_r = _skeleton.find_bone("FX_Hand_R")

# ── Animation ─────────────────────────────────────────────────────────────────

func _animate(delta: float) -> void:
	var vel       := _suit.velocity
	var stats     := _suit.get_stats()
	var ref_speed := maxf(stats.ground_sprint_speed, 1.0)
	var hspeed    := Vector2(vel.x, vel.z).length()

	# Velocity in the suit's local frame (X = right, -Z = forward)
	var local_vel := _suit.global_transform.basis.inverse() * vel

	# Yaw angular velocity from frame-to-frame rotation change
	var yaw_rate := (_suit.rotation.y - _prev_rot_y) / delta
	_prev_rot_y   = _suit.rotation.y

	var move_state := _movement.current_state

	# ── Forward / back lean (X rotation) ──────────────────────────────────
	# Normalize against boost_speed so pitch scales continuously up to full flight speed.
	# local_vel.z < 0 when moving forward → negative target = nose down = lean forward.
	var fwd_ref := maxf(stats.boost_speed, 1.0)
	var target_fwd := clampf(
		local_vel.z / fwd_ref * MAX_FWD_LEAN, -MAX_FWD_LEAN, MAX_FWD_LEAN)
	_lean_fwd = lerpf(_lean_fwd, target_fwd, SMOOTH * delta)

	# ── Strafe lean (Z rotation) ───────────────────────────────────────────
	# local_vel.x > 0 when strafing right → negative Z = tilt right
	var target_side := clampf(
		-local_vel.x / ref_speed * MAX_SIDE_LEAN, -MAX_SIDE_LEAN, MAX_SIDE_LEAN)
	_lean_side = lerpf(_lean_side, target_side, SMOOTH * delta)

	# ── Turn bank (Y rotation, distinct from strafe lean) ─────────────────
	var target_bank := clampf(yaw_rate * BANK_FACTOR, -MAX_BANK, MAX_BANK)
	_bank = lerpf(_bank, target_bank, SMOOTH * delta)

	# ── Vertical bob / hover (Y position) ─────────────────────────────────
	var target_y := 0.0
	match move_state:
		MovementController.State.GROUNDED:
			if hspeed > 1.0:
				var speed_ratio := hspeed / ref_speed
				_bob_phase = fmod(_bob_phase + delta * BOB_FREQ * speed_ratio * TAU, TAU)
				target_y   = sin(_bob_phase) * BOB_AMP * speed_ratio
			else:
				_bob_phase = 0.0
		MovementController.State.FLIGHT:
			_bob_phase = fmod(_bob_phase + delta * HOVER_FREQ * TAU, TAU)
			target_y   = sin(_bob_phase) * HOVER_AMP
		_:
			_bob_phase = 0.0

	# ── Thruster angles (skeleton bones) ──────────────────────────────────
	_animate_thrusters(delta, hspeed, stats)

	# ── Apply root transforms ──────────────────────────────────────────────
	_suit_root.rotation_degrees = Vector3(_lean_fwd, _bank, _lean_side)
	_suit_root.position.y = lerpf(_suit_root.position.y, target_y, 10.0 * delta)


func _animate_thrusters(delta: float, hspeed: float, stats: SuitStats) -> void:
	if not _skeleton:
		return

	# Speed ratio against boost_speed so thrusters reach max angle only at full flight speed.
	# Ground sprinting (~20 m/s) produces ~33 % deflection; full boost (60 m/s) gives 100 %.
	var speed_ratio := clampf(hspeed / maxf(stats.boost_speed, 1.0), 0.0, 1.0)

	var target_back := speed_ratio * MAX_BACK_ANGLE
	var target_hand := speed_ratio * MAX_HAND_ANGLE
	_back_angle = lerpf(_back_angle, target_back, THRUSTER_SMOOTH * delta)
	_hand_angle = lerpf(_hand_angle, target_hand, THRUSTER_SMOOTH * delta)

	# Back thrusters pitch around their local X axis.
	# Positive angle tilts the nozzle upward → exhaust points more rearward for forward thrust.
	# Negate if the nozzles tilt the wrong way in-engine.
	var back_rot := Quaternion(Vector3.RIGHT, deg_to_rad(_back_angle))
	if _bone_back_l >= 0:
		_skeleton.set_bone_pose_rotation(_bone_back_l, back_rot)
	if _bone_back_r >= 0:
		_skeleton.set_bone_pose_rotation(_bone_back_r, back_rot)

	# Hand repulsors pitch around their local X axis.
	# Negative angle tilts the palm face rearward so repulsor thrust points backward.
	# Negate or swap axis if the orientation differs in-engine.
	var hand_rot := Quaternion(Vector3.RIGHT, deg_to_rad(-_hand_angle))
	if _bone_hand_l >= 0:
		_skeleton.set_bone_pose_rotation(_bone_hand_l, hand_rot)
	if _bone_hand_r >= 0:
		_skeleton.set_bone_pose_rotation(_bone_hand_r, hand_rot)
