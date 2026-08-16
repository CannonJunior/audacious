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


func setup(skeleton: Skeleton3D, bi: Dictionary) -> void:
	_skeleton = skeleton
	_bi       = bi
	EventBus.suit_landed.connect(_on_suit_landed)


func tick(ctx: Dictionary) -> void:
	if not _skeleton:
		return

	var velocity: Vector3 = ctx["velocity"]
	# TODO (Session C): also extract delta, hspeed, stats, move_state from ctx.

	# Cache fall speed for landing impulse scaling.
	if velocity.y < -0.5:
		_last_fall_speed = absf(velocity.y)

	# TODO (Session C): implement the four systems below.

	# ── System 1: Breathing ───────────────────────────────────────────────────
	# _breathe_phase = fmod(_breathe_phase + BREATHE_FREQ * TAU * delta, TAU)
	# var ref_speed := maxf(stats.ground_sprint_speed, 1.0)
	# var amp := deg_to_rad(BREATHE_AMP_DEG) * (1.0 - clampf(hspeed / ref_speed, 0.0, 1.0))
	# var rot  := Quaternion(Vector3.RIGHT, sin(_breathe_phase) * amp)
	# _set_bone_rot("spine_02", rot)
	# _set_bone_rot("spine_03", rot)

	# ── System 2: Armor jiggle ────────────────────────────────────────────────
	# Detect hard velocity changes for mid-air impulse:
	# var vel_change := (velocity - _prev_velocity).length() / delta
	# if vel_change > 5.0:
	#     _apply_jiggle_impulse(15.0)
	# _prev_velocity = velocity
	#
	# for i in PLATE_KEYS.size():
	#     _spring_vel[i]  += (-SPRING_STIFFNESS * _spring_disp[i] - SPRING_DAMPING * _spring_vel[i]) * delta
	#     _spring_disp[i] += _spring_vel[i] * delta
	#     var idx: int = _bi.get(PLATE_KEYS[i], -1)
	#     if idx >= 0:
	#         _skeleton.set_bone_pose_rotation(idx,
	#             Quaternion(Vector3.RIGHT, deg_to_rad(_spring_disp[i])))

	# ── System 3: Head look-at ────────────────────────────────────────────────
	# var camera_rig := get_parent().get_parent().get_node_or_null("CameraRig")
	# if camera_rig:
	#     var cam_fwd   := -(camera_rig as Node3D).global_transform.basis.z
	#     var suit_fwd  := -(get_parent().get_parent() as Node3D).global_transform.basis.z
	#     var residual  := cam_fwd - suit_fwd
	#     var yaw   := clampf(residual.x, deg_to_rad(-45.0), deg_to_rad(45.0))
	#     var pitch := clampf(residual.y, deg_to_rad(-25.0), deg_to_rad(25.0))
	#     _neck_yaw_cur   = lerpf(_neck_yaw_cur,   yaw   * 0.6, HEAD_LERP_SPEED * delta)
	#     _neck_pitch_cur = lerpf(_neck_pitch_cur, pitch * 0.6, HEAD_LERP_SPEED * delta)
	#     _head_yaw_cur   = lerpf(_head_yaw_cur,   yaw   * 0.4, HEAD_LERP_SPEED * delta)
	#     _head_pitch_cur = lerpf(_head_pitch_cur, pitch * 0.4, HEAD_LERP_SPEED * delta)
	#     _set_bone_rot("neck_01", Quaternion(Vector3.UP, _neck_yaw_cur) *
	#                              Quaternion(Vector3.RIGHT, _neck_pitch_cur))
	#     _set_bone_rot("head",    Quaternion(Vector3.UP, _head_yaw_cur) *
	#                              Quaternion(Vector3.RIGHT, _head_pitch_cur))

	# ── System 4: Flight arm spread ───────────────────────────────────────────
	# var target_spread := deg_to_rad(ARM_SPREAD_DEG) if move_state == MovementController.State.FLIGHT else 0.0
	# _arm_spread_cur = lerpf(_arm_spread_cur, target_spread, ARM_LERP_SPEED * delta)
	# _set_bone_rot("clavicle_l", Quaternion(Vector3.FORWARD, -_arm_spread_cur))
	# _set_bone_rot("clavicle_r", Quaternion(Vector3.FORWARD,  _arm_spread_cur))


# ── Private ────────────────────────────────────────────────────────────────────

func _set_bone_rot(key: String, rot: Quaternion) -> void:
	var idx: int = _bi.get(key, -1)
	if idx >= 0:
		_skeleton.set_bone_pose_rotation(idx, rot)


func _apply_jiggle_impulse(deg_per_s: float) -> void:
	for i in _spring_vel.size():
		_spring_vel[i] += deg_per_s


func _on_suit_landed(_position: Vector3, _thermal: float) -> void:
	var impact := clampf(_last_fall_speed * 6.0, 5.0, 40.0)
	_apply_jiggle_impulse(impact)
