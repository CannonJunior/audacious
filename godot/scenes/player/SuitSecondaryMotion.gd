class_name SuitSecondaryMotion
extends Node
## SESSION C — Breathing, armor jiggle, head look-at, flight arm spread.
##
## All work is bone rotation only — no new nodes, no raycasts.
## Bones are set via _skeleton.set_bone_pose_rotation(idx, Quaternion).
## All rotations are in each bone's LOCAL space.
##
## ── System 1: Breathing (spine_02, spine_03) ──────────────────────────────────
##   A 0.45 Hz sine wave applies a local-X rotation of ±1.2° to spine_02 and
##   spine_03. Fade amplitude linearly to zero as hspeed approaches ref_speed,
##   so breathing vanishes at full sprint and hover bob handles flight idle.
##   amplitude = 1.2° * (1.0 − clamp(hspeed / ref_speed, 0, 1))
##
## ── System 2: Armor jiggle (six chest/shoulder/knee plates) ───────────────────
##   Six spring-damper instances, one per armor plate bone:
##     "chest_armor_l", "chest_armor_r"
##     "shoulder_armor_l", "shoulder_armor_r"
##     "knee_armor_l", "knee_armor_r"
##   Spring state per plate: displacement (float, degrees) + velocity (deg/s).
##   Each frame: velocity += (-STIFFNESS * displacement - DAMPING * velocity) * delta
##              displacement += velocity * delta
##   Apply displacement as a rotation around the plate's local X axis.
##   STIFFNESS = 80.0, DAMPING = 18.0
##
##   On EventBus.suit_landed: apply an impulse (velocity += impact_deg_per_s).
##     Scale impact by _last_fall_speed: impact = clamp(fall_speed * 6.0, 5.0, 40.0)
##   On large mid-air velocity changes (|vel_change| > 5 m/s): smaller impulse (15°/s).
##   Cache _last_fall_speed in tick() by monitoring ctx["velocity"].y < −0.5.
##
## ── System 3: Head look-at (neck_01 60%, head 40%) ────────────────────────────
##   Residual angle = angle between suit body forward and camera look direction.
##   Only the horizontal (yaw) and vertical (pitch) components are used.
##   neck_01 gets 60% of the clamped residual; head gets 40%.
##   Horizontal clamp: ±45°. Vertical clamp: ±25°.
##   Lerp speed: 6.0/s. Apply as local Y rotation (yaw) + local X rotation (pitch).
##   Camera reference: get_parent().get_parent().get_node_or_null("CameraRig")
##   Do NOT use the world camera direction — use the residual vs body forward so
##   the head doesn't double-rotate when the body is already facing the target.
##
##   FX_Head eye glow (no particles needed — the bone drives emission in SuitEmissionGlow):
##   No extra work here; emission glow uses the same bone index.
##
## ── System 4: Flight arm spread (clavicle_l, clavicle_r) ─────────────────────
##   In FLIGHT state: lerp clavicle_l local-Z rotation toward −15° (arm out).
##                    lerp clavicle_r local-Z rotation toward +15°.
##   In other states: lerp back to 0°.
##   Lerp speed: 3.0/s.
##   Apply via set_bone_pose_rotation using Quaternion(Vector3.FORWARD, deg_to_rad(±15°)).
##   Note: confirm the axis in-engine — if arms spread the wrong way negate the angle.
##
## ── Event connections (in setup()) ────────────────────────────────────────────
##   EventBus.suit_landed.connect(_on_suit_landed)

const BREATHE_FREQ    := 0.45   ## Hz
const BREATHE_AMP_DEG := 1.2    ## degrees, max amplitude at zero speed
const SPRING_STIFFNESS := 80.0
const SPRING_DAMPING   := 18.0
const ARM_SPREAD_DEG   := 15.0  ## degrees, clavicle spread in FLIGHT
const HEAD_LERP_SPEED  := 6.0
const ARM_LERP_SPEED   := 3.0
const ARM_SWING_DEG    := 25.0  ## degrees, max upperarm forward/back swing at full ground speed
const TORSO_TWIST_DEG  :=  6.0  ## degrees, upper-spine counter-rotation vs arms
const GAIT_LERP        := 12.0  ## arm-swing smoothing rate

var _skeleton: Skeleton3D = null
var _bi:       Dictionary = {}

# Breathing
var _breathe_phase: float = 0.0

# Armor jiggle — parallel arrays indexed by the six plate keys
const PLATE_KEYS := ["chest_armor_l","chest_armor_r",
					  "shoulder_armor_l","shoulder_armor_r",
					  "knee_armor_l","knee_armor_r"]
var _spring_disp: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _spring_vel:  Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _last_fall_speed: float    = 0.0
var _prev_velocity:   Vector3  = Vector3.ZERO

# Head look-at
var _neck_yaw_cur:   float = 0.0
var _neck_pitch_cur: float = 0.0
var _head_yaw_cur:   float = 0.0
var _head_pitch_cur: float = 0.0

# Arm spread
var _arm_spread_cur: float = 0.0

# Walk / run arm swing
var _arm_swing_l: float = 0.0
var _arm_swing_r: float = 0.0

# Rest-pose rotation cache, keyed by BONE_NAMES key. set_bone_pose_rotation()
# sets the ABSOLUTE local pose rotation, not a delta from rest — every write
# below must be composed as (rest_rotation * delta_rotation) or it discards
# the bone's bind-pose bend entirely.
var _rest_rot: Dictionary = {}

const _DRIVEN_BONES := ["spine_02", "spine_03", "neck_01", "head",
						  "clavicle_l", "clavicle_r",
						  "upperarm_l", "upperarm_r"] + PLATE_KEYS


func setup(skeleton: Skeleton3D, bi: Dictionary) -> void:
	_skeleton = skeleton
	_bi       = bi
	for key in _DRIVEN_BONES:
		var idx: int = _bi.get(key, -1)
		if idx >= 0:
			_rest_rot[key] = _skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
	EventBus.suit_landed.connect(_on_suit_landed)


func tick(ctx: Dictionary) -> void:
	if not _skeleton:
		return

	var delta: float                      = ctx["delta"]
	var velocity: Vector3                 = ctx["velocity"]
	var hspeed: float                     = ctx["hspeed"]
	var stats: SuitStats                  = ctx["stats"]
	var move_state: MovementController.State = ctx["move_state"]

	# Cache fall speed for landing impulse scaling.
	if velocity.y < -0.5:
		_last_fall_speed = absf(velocity.y)

	# ── System 1: Breathing ───────────────────────────────────────────────────
	_breathe_phase = fmod(_breathe_phase + BREATHE_FREQ * TAU * delta, TAU)
	var ref_speed := maxf(stats.ground_sprint_speed, 1.0)
	# gait_intensity is computed in SuitModelVisuals using GAIT_REF_SPEED (8 m/s),
	# not ground_sprint_speed — using sprint speed made intensity < 5% at normal speeds.
	var gait_intensity: float = ctx.get("gait_intensity", 0.0)
	var amp := deg_to_rad(BREATHE_AMP_DEG) * (1.0 - gait_intensity)
	var breathe_rot := Quaternion(Vector3.RIGHT, sin(_breathe_phase) * amp)
	_set_bone_rot("spine_02", breathe_rot)
	# spine_03: compose breathing + torso counter-rotation to arm swing.
	var gait_phase: float = ctx.get("gait_phase", 0.0)
	var torso_twist := Quaternion(Vector3.UP,
		sin(gait_phase + PI) * deg_to_rad(TORSO_TWIST_DEG) * gait_intensity)
	_set_bone_rot("spine_03", breathe_rot * torso_twist)

	# ── System 2: Armor jiggle ────────────────────────────────────────────────
	# Compare the raw per-frame velocity delta (m/s), not delta/dt (m/s²) —
	# dividing by delta turns this into an acceleration check, which ordinary
	# gravity (~9.8 m/s²) trips every frame while airborne, causing continuous
	# spurious jiggle during any fall, including the initial spawn drop.
	var vel_change := (velocity - _prev_velocity).length()
	if vel_change > 5.0:
		_apply_jiggle_impulse(15.0)
	_prev_velocity = velocity

	for i in PLATE_KEYS.size():
		_spring_vel[i]  += (-SPRING_STIFFNESS * _spring_disp[i] - SPRING_DAMPING * _spring_vel[i]) * delta
		_spring_disp[i] += _spring_vel[i] * delta
		_set_bone_rot(PLATE_KEYS[i], Quaternion(Vector3.RIGHT, deg_to_rad(_spring_disp[i])))

	# ── System 3: Head look-at ────────────────────────────────────────────────
	# Residual is computed in the suit's local space so yaw/pitch fall out as a
	# proper angle-between rather than a raw vector subtraction (which only
	# approximates the angle for small offsets and doesn't map cleanly to the
	# suit's local Y/X rotation axes).
	#
	# Read the Camera3D LEAF node, not CameraRig itself: CameraRig.rotation.y is
	# deliberately set to suit.rotation.y + PI (CameraRig.gd) so the spring arm
	# plants the camera behind the suit. Camera3D has no counter-rotation, so it
	# inherits that 180° flip — using CameraRig's own basis.z as "forward" reads
	# the opposite of what's on screen. Camera3D's -Z is engine-guaranteed to be
	# the actual view direction regardless of how its ancestors are rigged.
	var suit_root := get_parent().get_parent() as Node3D
	var camera := suit_root.get_node_or_null("CameraRig/SpringArm3D/Camera3D") as Node3D
	var target_yaw := 0.0
	var target_pitch := 0.0
	if camera:
		var cam_fwd_world := camera.global_transform.basis.z
		var local_fwd := (suit_root.global_transform.basis.inverse() * cam_fwd_world).normalized()
		target_yaw   = clampf(atan2(local_fwd.x, -local_fwd.z), deg_to_rad(-45.0), deg_to_rad(45.0))
		target_pitch = clampf(asin(clampf(local_fwd.y, -1.0, 1.0)), deg_to_rad(-25.0), deg_to_rad(25.0))

	_neck_yaw_cur   = lerpf(_neck_yaw_cur,   target_yaw   * 0.6, HEAD_LERP_SPEED * delta)
	_neck_pitch_cur = lerpf(_neck_pitch_cur, target_pitch * 0.6, HEAD_LERP_SPEED * delta)
	_head_yaw_cur   = lerpf(_head_yaw_cur,   target_yaw   * 0.4, HEAD_LERP_SPEED * delta)
	_head_pitch_cur = lerpf(_head_pitch_cur, target_pitch * 0.4, HEAD_LERP_SPEED * delta)
	_set_bone_rot("neck_01", Quaternion(Vector3.UP, _neck_yaw_cur) *
	                         Quaternion(Vector3.RIGHT, _neck_pitch_cur))
	_set_bone_rot("head",    Quaternion(Vector3.UP, _head_yaw_cur) *
	                         Quaternion(Vector3.RIGHT, _head_pitch_cur))

	# ── System 4: Flight arm spread ───────────────────────────────────────────
	var target_spread := deg_to_rad(ARM_SPREAD_DEG) if move_state == MovementController.State.FLIGHT else 0.0
	_arm_spread_cur = lerpf(_arm_spread_cur, target_spread, ARM_LERP_SPEED * delta)
	_set_bone_rot("clavicle_l", Quaternion(Vector3.FORWARD, -_arm_spread_cur))
	_set_bone_rot("clavicle_r", Quaternion(Vector3.FORWARD,  _arm_spread_cur))

	# ── System 5: Walk / run arm swing ────────────────────────────────────────
	# Left arm forward when gait_phase ≈ 0, right arm forward at ≈ π (opposite legs).
	# Amplitude and phase rate both scale with speed, so slow walk → subtle swing
	# and sprint → full swing automatically.
	# Axis: RIGHT (local X) sweeps the arm through the sagittal plane — forward/back.
	# FORWARD on a hanging arm produces lateral swing, which is wrong here.
	# If arms swing the wrong direction, negate ARM_SWING_DEG.
	if move_state == MovementController.State.GROUNDED:
		var swing_amp := deg_to_rad(ARM_SWING_DEG) * gait_intensity
		_arm_swing_l = lerpf(_arm_swing_l,  sin(gait_phase) * swing_amp, GAIT_LERP * delta)
		_arm_swing_r = lerpf(_arm_swing_r, -sin(gait_phase) * swing_amp, GAIT_LERP * delta)
	else:
		_arm_swing_l = lerpf(_arm_swing_l, 0.0, GAIT_LERP * delta)
		_arm_swing_r = lerpf(_arm_swing_r, 0.0, GAIT_LERP * delta)
	_set_bone_rot("upperarm_l", Quaternion(Vector3.RIGHT, _arm_swing_l))
	_set_bone_rot("upperarm_r", Quaternion(Vector3.RIGHT, _arm_swing_r))


# ── Private ────────────────────────────────────────────────────────────────────

func _set_bone_rot(key: String, delta_rot: Quaternion) -> void:
	var idx: int = _bi.get(key, -1)
	if idx >= 0:
		var rest: Quaternion = _rest_rot.get(key, Quaternion.IDENTITY)
		_skeleton.set_bone_pose_rotation(idx, rest * delta_rot)


func _apply_jiggle_impulse(deg_per_s: float) -> void:
	for i in _spring_vel.size():
		_spring_vel[i] += deg_per_s


func _on_suit_landed(_position: Vector3, _thermal: float) -> void:
	var impact := clampf(_last_fall_speed * 6.0, 5.0, 40.0)
	_apply_jiggle_impulse(impact)
