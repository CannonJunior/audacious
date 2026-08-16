class_name SuitLegIK
extends Node
## SESSION B — Two-bone leg IK with foot-planting step system.
##
## Only active in GROUNDED state. In AIRBORNE/FLIGHT the legs hold their last
## IK-solved pose (no solve — no bone writes).
##
## ── IK chain (from bone audit) ────────────────────────────────────────────────
##   Left:  thigh_l (a = 0.4686 m) → calf_l (b = 0.4975 m) → foot_l
##   Right: thigh_r (a = 0.4686 m) → calf_r (b = 0.4975 m) → foot_r
##   Total reach: 0.9661 m
##
## ── Two-bone IK math ──────────────────────────────────────────────────────────
##   Given: hip world position H, foot target T, bone lengths a (thigh), b (calf)
##   d = |H − T| clamped to (|a−b| + ε, a+b − ε) to avoid degenerate solve
##   cos_thigh  = (a² + d² − b²) / (2ad)
##   thigh_angle = acos(cos_thigh)
##   Place knee using pole vector (hip + rest_thigh_dir_world * 0.5):
##     knee_dir = (T − H).cross(knee_pole − H).cross(T − H).normalized()
##     knee_world = H + (T−H).normalized()*a*cos(thigh_angle) + knee_dir*a*sin(thigh_angle)
##   Thigh rotation: Quaternion(rest_fwd, dir_local) * rest_basis_quat
##   Calf  rotation: Quaternion(rest_fwd, dir_local) * rest_basis_quat
##   Applied via set_bone_pose_rotation in parent-local space.
##
## ── Bone forward axis assumption ──────────────────────────────────────────────
##   UE skeletons extend bones along local +X. If knees bend the wrong direction
##   on first test, swap Vector3.RIGHT → Vector3.UP here and in _set_ik_rotation.
##
## ── Step system ───────────────────────────────────────────────────────────────
##   Each foot has a planted world position and a FootState (PLANTED / STEPPING).
##   Steps alternate strictly. Desired position found via downward raycast.
##   STEP_THRESHOLD: 0.20 m base, scales with speed.
##   STEP_DURATION:  0.18 s base, scales down with speed (min 0.10 s).
##   STEP_HEIGHT:    0.22 m arc.

enum FootState { PLANTED, STEPPING }

const THIGH_LEN      := 0.4686   ## metres, confirmed from GLB bind pose
const CALF_LEN       := 0.4975   ## metres, confirmed from GLB bind pose
const LEG_REACH      := THIGH_LEN + CALF_LEN   ## 0.9661 m
# Hip world Y ≈ 1.154m when standing; LEG_REACH = 0.9661m. Targeting floor directly
# puts the hip 19cm beyond max reach — IK clamps to full extension every frame, making
# walking visually identical to flying. Raising the ankle target by FOOT_HEIGHT keeps
# the effective vertical at ~0.904m, producing a ~21° knee bend at rest.
const FOOT_HEIGHT    := 0.25     ## metres, ankle target above floor surface
const STEP_HEIGHT    := 0.22     ## metres, upward arc mid-step
const STEP_DURATION  := 0.18     ## seconds, base duration
const STEP_THRESHOLD := 0.20     ## metres, foot drift before triggering a step
const HIP_TILT_DEG    := 3.0    ## degrees, pelvis lateral tilt as weight shifts per step
const HIP_TILT_LERP   := 6.0   ## smoothing rate for weight-transfer tilt
const STANDING_SPEED  := 0.5   ## m/s — matches MovementController STANDING threshold

var _skeleton:  Skeleton3D       = null
var _bi:        Dictionary       = {}
var _suit:      CharacterBody3D  = null

var _planted_l:   Vector3   = Vector3.ZERO
var _planted_r:   Vector3   = Vector3.ZERO
var _state_l:     FootState = FootState.PLANTED
var _state_r:     FootState = FootState.PLANTED
var _step_t_l:    float     = 0.0
var _step_t_r:    float     = 0.0
var _step_from_l: Vector3   = Vector3.ZERO
var _step_from_r: Vector3   = Vector3.ZERO
var _step_to_l:   Vector3   = Vector3.ZERO
var _step_to_r:   Vector3   = Vector3.ZERO
var _prev_grounded: bool    = false

## 0.0 = weight on left foot, 0.5 = neutral, 1.0 = weight on right foot.
## Read by SuitModelVisuals after tick() and injected into ctx as "gait_weight".
var gait_weight_right: float = 0.5

var _pelvis_rest_rot: Quaternion = Quaternion.IDENTITY

## Pose rotations captured at time zero (before any IK runs).
## Restored verbatim whenever the suit is STANDING.
var _bind_rot: Dictionary = {}

# Actual bone lengths measured from skeleton rest transforms at setup.
# get_bone_rest(calf).origin.length() == distance from thigh origin to calf origin == thigh length.
# get_bone_rest(foot).origin.length() == distance from calf  origin to foot origin == calf  length.
var _thigh_len_l: float = THIGH_LEN
var _thigh_len_r: float = THIGH_LEN
var _calf_len_l:  float = CALF_LEN
var _calf_len_r:  float = CALF_LEN


func setup(skeleton: Skeleton3D, bi: Dictionary, suit: CharacterBody3D) -> void:
	_skeleton = skeleton
	_bi       = bi
	_suit     = suit
	var bi_p: int = _bi.get("pelvis", -1)
	if bi_p >= 0:
		_pelvis_rest_rot = _skeleton.get_bone_rest(bi_p).basis.get_rotation_quaternion()
	var bi_cl: int = _bi.get("calf_l",  -1)
	var bi_cr: int = _bi.get("calf_r",  -1)
	var bi_fl: int = _bi.get("foot_l",  -1)
	var bi_fr: int = _bi.get("foot_r",  -1)
	if bi_cl >= 0: _thigh_len_l = _skeleton.get_bone_rest(bi_cl).origin.length()
	if bi_cr >= 0: _thigh_len_r = _skeleton.get_bone_rest(bi_cr).origin.length()
	if bi_fl >= 0: _calf_len_l  = _skeleton.get_bone_rest(bi_fl).origin.length()
	if bi_fr >= 0: _calf_len_r  = _skeleton.get_bone_rest(bi_fr).origin.length()
	for key in ["thigh_l", "calf_l", "thigh_r", "calf_r"]:
		var idx: int = _bi.get(key, -1)
		if idx >= 0:
			_bind_rot[key] = _skeleton.get_bone_pose_rotation(idx)


func tick(ctx: Dictionary) -> void:
	if not _skeleton:
		return
	var move_state: MovementController.State = ctx["move_state"]
	if move_state != MovementController.State.GROUNDED:
		_prev_grounded = false
		return

	var delta:  float = ctx["delta"]
	var hspeed: float = ctx["hspeed"]

	# 1. Pelvis bone index (world transform computed after tilt is applied below).
	var bi_pelvis: int = _bi.get("pelvis", -1)
	if bi_pelvis < 0:
		return

	# 1b. Apply pelvis tilt — but NOT on the landing frame (_prev_grounded = false).
	# On first grounded tick the skeleton is still in its unmodified rest pose;
	# calling set_bone_pose_rotation before we read it (snap + IK) changes the
	# accumulated global poses of every descendant even when tilt = 0, which
	# shifts the foot-bone positions the snap reads and corrupts the IK reference frame.
	if _prev_grounded:
		var weight_target := 0.5
		if _state_r == FootState.STEPPING:
			weight_target = 0.0
		elif _state_l == FootState.STEPPING:
			weight_target = 1.0
		gait_weight_right = lerpf(gait_weight_right, weight_target, HIP_TILT_LERP * delta)
		var tilt := (gait_weight_right - 0.5) * 2.0 * deg_to_rad(HIP_TILT_DEG)
		if absf(tilt) > 0.0001:
			_skeleton.set_bone_pose_rotation(bi_pelvis,
				_pelvis_rest_rot * Quaternion(Vector3.FORWARD, tilt))
	else:
		gait_weight_right = 0.5

	var pelvis_global := _skeleton.global_transform * _skeleton.get_bone_global_pose(bi_pelvis)

	# Per-leg attachment points: each thigh bone starts at its own rest-offset
	# from the pelvis origin, so using pelvis.origin for both would give a wrong
	# hip-to-foot distance and push the IK past its reach on normal ground height.
	var bi_thigh_l: int = _bi.get("thigh_l", -1)
	var bi_thigh_r: int = _bi.get("thigh_r", -1)
	if bi_thigh_l < 0 or bi_thigh_r < 0:
		return
	var thigh_rest_l := _skeleton.get_bone_rest(bi_thigh_l)
	var thigh_rest_r := _skeleton.get_bone_rest(bi_thigh_r)
	var hip_l := pelvis_global.basis * thigh_rest_l.origin + pelvis_global.origin
	var hip_r := pelvis_global.basis * thigh_rest_r.origin + pelvis_global.origin
	# Each thigh's rest basis encodes the bind-pose knee direction; use it as
	# the pole so the IK bending plane matches the rest pose exactly.
	# axis_sign mirrors the primary axis on left bones (same as _solve_two_bone_ik).
	var knee_pole_l := (pelvis_global.basis * thigh_rest_l.basis * Vector3.LEFT).normalized()
	var knee_pole_r := (pelvis_global.basis * thigh_rest_r.basis * Vector3.RIGHT).normalized()

	var facing_dir := -_suit.global_transform.basis.z

	# 2. Desired foot positions via downward raycast from each thigh attachment point.
	var desired_l := _desired_foot(hip_l, facing_dir, Vector3.ZERO, hspeed)
	var desired_r := _desired_foot(hip_r, facing_dir, Vector3.ZERO, hspeed)

	# 3. Snap feet on first grounded tick (init) and on every landing.
	# Use the foot bones' current world X/Z so the IK starts at the rest-pose
	# angles (bones are at rest when coming from airborne — no IK writes).
	# Floor Y comes from the raycast so feet actually contact the ground.
	if not _prev_grounded:
		var bi_foot_l: int = _bi.get("foot_l", -1)
		var bi_foot_r: int = _bi.get("foot_r", -1)
		if bi_foot_l >= 0 and bi_foot_r >= 0:
			_planted_l = (_skeleton.global_transform * _skeleton.get_bone_global_pose(bi_foot_l)).origin
			_planted_r = (_skeleton.global_transform * _skeleton.get_bone_global_pose(bi_foot_r)).origin
		else:
			_planted_l = desired_l
			_planted_r = desired_r
		_state_l   = FootState.PLANTED
		_state_r   = FootState.PLANTED
		_prev_grounded = true

	# 3b. STANDING — restore the exact bind-pose rotations captured at startup.
	# Skips IK entirely; no math can be more accurate than the recorded truth.
	# Keep planted positions current so the step system has a clean starting point
	# the moment the suit begins moving.
	if hspeed < STANDING_SPEED:
		for key in ["thigh_l", "calf_l", "thigh_r", "calf_r"]:
			var idx: int = _bi.get(key, -1)
			if idx >= 0:
				_skeleton.set_bone_pose_rotation(idx, _bind_rot.get(key, Quaternion.IDENTITY))
		var bi_fl: int = _bi.get("foot_l", -1)
		var bi_fr: int = _bi.get("foot_r", -1)
		if bi_fl >= 0:
			_planted_l = (_skeleton.global_transform * _skeleton.get_bone_global_pose(bi_fl)).origin
		if bi_fr >= 0:
			_planted_r = (_skeleton.global_transform * _skeleton.get_bone_global_pose(bi_fr)).origin
		_state_l = FootState.PLANTED
		_state_r = FootState.PLANTED
		return

	# 4. Speed-scaled step timing.
	var step_dur  := maxf(STEP_DURATION * maxf(1.0 - hspeed * 0.02, 0.55), 0.10)
	var threshold := STEP_THRESHOLD * (1.0 + hspeed / 10.0)

	# Advance left foot step.
	if _state_l == FootState.STEPPING:
		_step_t_l = minf(_step_t_l + delta / step_dur, 1.0)
		if _step_t_l >= 1.0:
			_state_l   = FootState.PLANTED
			_planted_l = _step_to_l
		else:
			_planted_l = _step_from_l.lerp(_step_to_l, _step_t_l) \
				+ Vector3.UP * sin(_step_t_l * PI) * STEP_HEIGHT

	# Advance right foot step.
	if _state_r == FootState.STEPPING:
		_step_t_r = minf(_step_t_r + delta / step_dur, 1.0)
		if _step_t_r >= 1.0:
			_state_r   = FootState.PLANTED
			_planted_r = _step_to_r
		else:
			_planted_r = _step_from_r.lerp(_step_to_r, _step_t_r) \
				+ Vector3.UP * sin(_step_t_r * PI) * STEP_HEIGHT

	# 5. Trigger new steps — only when both feet are planted; step the farther one.
	if _state_l == FootState.PLANTED and _state_r == FootState.PLANTED:
		var dist_l := _planted_l.distance_to(desired_l)
		var dist_r := _planted_r.distance_to(desired_r)
		if dist_l >= dist_r and dist_l > threshold:
			_state_l     = FootState.STEPPING
			_step_t_l    = 0.0
			_step_from_l = _planted_l
			_step_to_l   = desired_l
		elif dist_r > dist_l and dist_r > threshold:
			_state_r     = FootState.STEPPING
			_step_t_r    = 0.0
			_step_from_r = _planted_r
			_step_to_r   = desired_r

	# 6. Solve IK for each leg.
	_solve_two_bone_ik("thigh_l", "calf_l", pelvis_global, hip_l, _planted_l, knee_pole_l, _thigh_len_l, _calf_len_l)
	_solve_two_bone_ik("thigh_r", "calf_r", pelvis_global, hip_r, _planted_r, knee_pole_r, _thigh_len_r, _calf_len_r)


# ── Private ────────────────────────────────────────────────────────────────────

func _desired_foot(hip_world: Vector3, facing_dir: Vector3,
		side_offset: Vector3, hspeed: float) -> Vector3:
	var stride    := facing_dir * clampf(hspeed * 0.08, 0.0, 0.25)
	var ray_from  := hip_world + side_offset + stride
	var space     := _suit.get_world_3d().direct_space_state
	var query     := PhysicsRayQueryParameters3D.create(
		ray_from, ray_from + Vector3.DOWN * 2.0)
	query.exclude = [_suit.get_rid()]
	var hit       := space.intersect_ray(query)
	var floor_y   := (hit["position"] as Vector3).y if hit else ray_from.y - 2.0
	return Vector3(ray_from.x, floor_y + FOOT_HEIGHT, ray_from.z)


func _solve_two_bone_ik(thigh_key: String, calf_key: String,
		pelvis_global: Transform3D, hip_world: Vector3,
		target: Vector3, knee_pole_dir: Vector3, a: float, b: float) -> void:
	var bi_thigh: int = _bi.get(thigh_key, -1)
	var bi_calf:  int = _bi.get(calf_key,  -1)
	if bi_thigh < 0 or bi_calf < 0:
		return

	# UE mirrors the primary bone axis on left-side bones: negate so the swing
	# goes the correct direction. Right side uses +X, left side uses -X.
	var axis_sign := -1.0 if thigh_key.ends_with("_l") else 1.0
	var eps := 0.001
	var d   := clampf(hip_world.distance_to(target), absf(a - b) + eps, a + b - eps)

	var cos_thigh   := clampf((a*a + d*d - b*b) / (2.0*a*d), -1.0, 1.0)
	var thigh_angle := acos(cos_thigh)

	# Knee world position via pole vector derived from the thigh's rest basis,
	# so the bending plane matches the bind pose exactly.
	var ht   := target - hip_world
	var ht_n := ht.normalized()
	var pole := hip_world + knee_pole_dir * 0.5
	var c1   := ht.cross(pole - hip_world)
	var knee_dir: Vector3
	if c1.length_squared() > 0.0001:
		knee_dir = c1.cross(ht).normalized()
	else:
		knee_dir = knee_pole_dir.cross(ht_n)
		if knee_dir.length_squared() < 0.0001:
			knee_dir = Vector3.FORWARD
		else:
			knee_dir = knee_dir.normalized()
	var knee_world := hip_world \
		+ ht_n * (a * cos(thigh_angle)) \
		+ knee_dir * (a * sin(thigh_angle))

	var thigh_rot := _ik_rotation(bi_thigh, axis_sign, pelvis_global.basis,
		(knee_world - hip_world).normalized())
	_skeleton.set_bone_pose_rotation(bi_thigh, thigh_rot)

	# Calf parent basis computed from thigh's fresh pose to avoid stale cache.
	var thigh_global_basis := pelvis_global.basis * Basis(thigh_rot)
	var calf_rot := _ik_rotation(bi_calf, axis_sign, thigh_global_basis,
		(target - knee_world).normalized())
	_skeleton.set_bone_pose_rotation(bi_calf, calf_rot)


func _ik_rotation(bone_idx: int, axis_sign: float, parent_basis: Basis,
		desired_dir_world: Vector3) -> Quaternion:
	var rest     := _skeleton.get_bone_rest(bone_idx)
	var rest_fwd := (rest.basis * (Vector3.RIGHT * axis_sign)).normalized()
	if rest_fwd.length_squared() < 0.0001:
		return rest.basis.get_rotation_quaternion()

	var desired_local := (parent_basis.inverse() * desired_dir_world).normalized()
	if desired_local.length_squared() < 0.0001:
		return rest.basis.get_rotation_quaternion()

	# Swing rest direction to desired; preserve twist by composing with rest quat.
	return Quaternion(rest_fwd, desired_local) * rest.basis.get_rotation_quaternion()


func _clear_leg_pose() -> void:
	for key in ["thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]:
		var idx: int = _bi.get(key, -1)
		if idx >= 0:
			_skeleton.set_bone_pose_rotation(idx, Quaternion.IDENTITY)
