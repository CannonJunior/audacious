class_name SuitLegIK
extends Node
## SESSION B — Two-bone leg IK with foot-planting step system.
##
## Only active in GROUNDED state. In AIRBORNE/FLIGHT the legs hold a trailing
## relaxed pose (no IK solve — just clear bone pose overrides).
##
## ── IK chain (from bone audit) ────────────────────────────────────────────────
##   Left:  thigh_l (a = 0.4686 m) → calf_l (b = 0.4975 m) → foot_l
##   Right: thigh_r (a = 0.4686 m) → calf_r (b = 0.4975 m) → foot_r
##   Total reach: 0.9661 m
##
## ── Two-bone IK math ──────────────────────────────────────────────────────────
##   Given: hip world position H, foot target T, bone lengths a (thigh), b (calf)
##   d = |H − T| clamped to (|a−b| + ε, a+b − ε) to avoid degenerate solve
##   cos_knee = (d² − a² − b²) / (2ab)           ← law of cosines
##   knee_angle = acos(cos_knee)
##   cos_thigh  = (a² + d² − b²) / (2ad)
##   thigh_angle = acos(cos_thigh)
##   Place knee using pole vector (knee_pole = hip + forward*0.3 + up*0.1):
##     knee_dir = (T − H).cross(knee_pole − H).cross(T − H).normalized()
##     knee_world = H + (T−H).normalized()*a*cos(thigh_angle) + knee_dir*a*sin(thigh_angle)
##   Compute thigh rotation: from bone's rest-pose direction to (knee_world − H).
##   Compute calf rotation:  from bone's rest-pose direction to (T − knee_world).
##   Apply via _skeleton.set_bone_pose_rotation(idx, Quaternion(from, to)).
##
## ── Step system ───────────────────────────────────────────────────────────────
##   Each foot has a planted world position (_planted_l, _planted_r) and a state
##   (PLANTED or STEPPING). Each frame:
##     1. Raycast from hip_world + stride_offset downward (max 2 m) to find ground.
##     2. Desired foot position = ray hit point (or hip_world + stride_offset + down*leg_reach).
##     3. If distance(desired, planted) > step_threshold OR planted is below ground:
##        trigger a step on that foot — only if the OTHER foot is PLANTED.
##     4. Stepping foot: lerp planted toward desired over STEP_DURATION seconds,
##        adding a sin-curve upward arc of STEP_HEIGHT metres at midpoint.
##   Feet alternate strictly: right steps → left must be planted, and vice versa.
##
##   STEP_THRESHOLD: 0.25 m at walk, scales up with speed so fast movement doesn't
##                   produce constant micro-steps. At FLIGHT speeds abandon leg IK.
##   STEP_DURATION:  0.18 s base, reduce at higher speeds (min 0.10 s).
##   STEP_HEIGHT:    0.10 m arc.
##
## ── Pelvis world position ─────────────────────────────────────────────────────
##   Use _skeleton.global_transform * _skeleton.get_bone_global_pose(_bi["pelvis"])
##   to get the pelvis world transform. Do NOT assume a fixed Y offset from SuitBody
##   origin — the actual offset is unconfirmed and this approach is robust to it.
##
## ── Pole vector direction (needs in-engine validation) ────────────────────────
##   Assumed: knee_pole = pelvis_world + facing_dir * 0.3 + Vector3.UP * 0.1
##   If the knee bends the wrong way on first test, negate the cross product in
##   the IK solve or flip the pole vector sign.
##
## ── Raycast ───────────────────────────────────────────────────────────────────
##   Use _suit.get_world_3d().direct_space_state for PhysicsRayQueryParameters3D.
##   Exclude _suit.get_rid() from the query so the capsule doesn't self-intersect.

enum FootState { PLANTED, STEPPING }

const THIGH_LEN       := 0.4686   ## metres, confirmed from GLB bind pose
const CALF_LEN        := 0.4975   ## metres, confirmed from GLB bind pose
const LEG_REACH       := THIGH_LEN + CALF_LEN   ## 0.9661 m
const STEP_HEIGHT     := 0.10     ## metres, upward arc mid-step
const STEP_DURATION   := 0.18     ## seconds, base duration
const STEP_THRESHOLD  := 0.25     ## metres, foot drift before triggering a step

var _skeleton:  Skeleton3D       = null
var _bi:        Dictionary       = {}
var _suit:      CharacterBody3D  = null

var _planted_l:   Vector3   = Vector3.ZERO
var _planted_r:   Vector3   = Vector3.ZERO
var _state_l:     FootState = FootState.PLANTED
var _state_r:     FootState = FootState.PLANTED
var _step_t_l:    float     = 0.0   ## step progress 0→1
var _step_t_r:    float     = 0.0
var _step_from_l: Vector3   = Vector3.ZERO   ## step start world pos
var _step_from_r: Vector3   = Vector3.ZERO
var _step_to_l:   Vector3   = Vector3.ZERO   ## step target world pos
var _step_to_r:   Vector3   = Vector3.ZERO


func setup(skeleton: Skeleton3D, bi: Dictionary, suit: CharacterBody3D) -> void:
	_skeleton = skeleton
	_bi       = bi
	_suit     = suit
	# Planted positions initialised on first tick once skeleton world pos is known.


func tick(_ctx: Dictionary) -> void:
	pass
	# TODO (Session B): implement the step system and IK solve.
	# Do not call _clear_leg_pose() here until the IK solve is also implemented —
	# setting IDENTITY pose on right-side bones whose rest orientation is non-trivial
	# will visually rotate the leg 180°. Touch no bones until the full solve is ready.
	# Extract from ctx: delta = ctx["delta"], hspeed = ctx["hspeed"]
	# Suggested order:
	#
	# 1. Get pelvis world transform:
	#      var pelvis_xform := _skeleton.global_transform *
	#                          _skeleton.get_bone_global_pose(_bi["pelvis"])
	#      var hip_world    := pelvis_xform.origin
	#      var facing_dir   := -_suit.global_transform.basis.z  # suit forward
	#
	# 2. Compute desired foot positions via raycast for each side:
	#      _desired_foot(hip_world, facing_dir, side_offset, is_left)
	#      → casts downward from (hip_world + side*offset + fwd*stride) max 2 m
	#      → returns hit.position or fallback at hip_world + down*(LEG_REACH*0.95)
	#
	# 3. On first tick (_planted_l == Vector3.ZERO), initialise planted positions
	#    to the desired foot positions immediately.
	#
	# 4. Advance stepping feet:
	#      _step_t_l += delta / max(STEP_DURATION * speed_scale, 0.10)
	#      if _step_t_l >= 1.0: _state_l = PLANTED; _planted_l = _step_to_l
	#      else: _planted_l = lerp(_step_from_l, _step_to_l, ease(_step_t_l, ...))
	#            + Vector3.UP * sin(_step_t_l * PI) * STEP_HEIGHT
	#
	# 5. Check if a new step should be triggered (only if other foot is PLANTED):
	#      var threshold := STEP_THRESHOLD * (1.0 + hspeed / 10.0)
	#      if _state_l == PLANTED and _state_r == PLANTED:
	#          if _planted_l.distance_to(desired_l) > threshold or desired_l_underground:
	#              _state_l = STEPPING; _step_t_l = 0.0
	#              _step_from_l = _planted_l; _step_to_l = desired_l
	#          elif _planted_r.distance_to(desired_r) > threshold ...:
	#              (same for right)
	#
	# 6. Solve IK for each leg and apply bone rotations:
	#      _solve_two_bone_ik("thigh_l","calf_l","foot_l", hip_world, _planted_l, facing_dir)
	#      _solve_two_bone_ik("thigh_r","calf_r","foot_r", hip_world, _planted_r, facing_dir)
	#
	# See class comment above for the IK math.


func _clear_leg_pose() -> void:
	for key in ["thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]:
		var idx: int = _bi.get(key, -1)
		if idx >= 0:
			_skeleton.set_bone_pose_rotation(idx, Quaternion.IDENTITY)
