class_name SuitThrusterVFX
extends Node
## SESSION A — Thruster particle VFX and thruster bone animation.
##
## Owns:
##   • Thruster bone deflection (back thrusters + hand repulsors) — WORKING,
##     migrated from the old SuitModelVisuals._animate_thrusters().
##   • Seven GPUParticles3D emitters positioned on FX bones each frame:
##       fx_back_l / fx_back_r  — exhaust plumes (GasRouter directional branch)
##       fx_hand_l / fx_hand_r  — repulsor beams (PowerRouter weapon bus)
##       fx_foot_l / fx_foot_r  — boot jets     (GasRouter maneuver branch)
##       chest_beam             — arc reactor glow (PowerRouter sensor+defense)
##
## Bone audit results (world positions in bind pose):
##   FX_BackFire_L/R  spine_05 children, at ≈(±0.12, 1.65, -0.17)
##   FX_Hand_L/R      hand_l/r children,  at ≈(±0.35, 0.95, 0)
##   FX_Ball_L/R      ball_l/r children,  at ≈(±0.26, 0.11, -0.07)
##   Chest_Beam       spine_05 child,     at ≈(0, 1.53, 0.15)
##
## WARNING — BoneAttachment3D does not auto-update for runtime-loaded GLBs.
## Position particles manually each frame:
##   particle.global_transform = _skeleton.global_transform *
##                               _skeleton.get_bone_global_pose(bone_idx)
##
## Data sources (read directly every frame — do NOT use the 2 Hz push_state):
##   GasRouter.get_branch_pressure("directional")  → back thrusters
##   GasRouter.get_branch_pressure("maneuver")      → boot jets
##   PowerRouter.get_category_allocation("weapon")  → hand repulsors
##   PowerRouter.get_category_allocation("sensor")  → chest beam (half weight)
##   PowerRouter.get_category_allocation("defense") → chest beam (half weight)
##
## Event hooks (connect in setup()):
##   EventBus.boost_activated  → spike hand repulsors + chest beam 1.0 → decay 4/s
##   EventBus.suit_launched    → spike boot jets 1.0 → decay 8/s

# ── Thruster bone tuning ───────────────────────────────────────────────────────
const THRUSTER_SMOOTH := 5.0
const MAX_BACK_ANGLE  := 45.0   ## degrees, back thruster pitch at full boost speed
const MAX_HAND_ANGLE  := 35.0   ## degrees, hand repulsor pitch at full boost speed
## Roll bias: max extra degrees added to the high side during active roll.
const MAX_ROLL_BIAS   := 8.0

# ── State ──────────────────────────────────────────────────────────────────────
var _skeleton: Skeleton3D = null
var _bi:       Dictionary = {}

var _back_angle:   float = 0.0
var _hand_angle:   float = 0.0

# Transient override values for event-driven spikes (decay toward 0 each frame).
var _boost_spike:  float = 0.0   ## hand repulsor + chest beam spike on boost_activated
var _boot_spike:   float = 0.0   ## boot jet spike on suit_launched

# Particle node references — assigned in setup() once particles are created.
# TODO (Session A): create and store GPUParticles3D here.
var _p_back_l:    GPUParticles3D = null
var _p_back_r:    GPUParticles3D = null
var _p_hand_l:    GPUParticles3D = null
var _p_hand_r:    GPUParticles3D = null
var _p_foot_l:    GPUParticles3D = null
var _p_foot_r:    GPUParticles3D = null
var _p_chest:     GPUParticles3D = null


func setup(skeleton: Skeleton3D, bi: Dictionary) -> void:
	_skeleton = skeleton
	_bi       = bi

	EventBus.boost_activated.connect(_on_boost_activated)
	EventBus.suit_launched.connect(_on_suit_launched)

	# TODO (Session A): create seven GPUParticles3D nodes, configure their
	# ParticleProcessMaterial (direction, spread, color, lifetime), and assign
	# to _p_back_l … _p_chest above. Add each with add_child().


func tick(ctx: Dictionary) -> void:
	if not _skeleton:
		return

	var delta:      float                  = ctx["delta"]
	var hspeed:     float                  = ctx["hspeed"]
	var stats:      SuitStats              = ctx["stats"]
	var move_state: MovementController.State = ctx["move_state"]

	# ── Thruster bone deflection (migrated, working) ───────────────────────────
	_animate_thruster_bones(delta, hspeed, stats, move_state)

	# ── Decay event spikes ─────────────────────────────────────────────────────
	_boost_spike = maxf(0.0, _boost_spike - 4.0 * delta)
	_boot_spike  = maxf(0.0, _boot_spike  - 8.0 * delta)

	# TODO (Session A): position and drive particle emitters each frame.
	# Pattern for each emitter (example — back left):
	#
	#   if _p_back_l and _bi.get("fx_back_l", -1) >= 0:
	#       _p_back_l.global_transform = (
	#           _skeleton.global_transform *
	#           _skeleton.get_bone_global_pose(_bi["fx_back_l"])
	#       )
	#       var pressure := GasRouter.get_branch_pressure("directional")
	#       _p_back_l.amount_ratio = pressure  # or set emission_amount
	#
	# Back thrusters: active in FLIGHT state; asymmetric during roll.
	#   var roll_z := (get_parent().get_parent() as CharacterBody3D).rotation.z
	#   var bias   := clampf(roll_z / (PI * 0.5), -1.0, 1.0) * MAX_ROLL_BIAS
	#   (apply +bias to one side, -bias to the other)
	#
	# Hand repulsors: weapon bus + _boost_spike
	#   var w := PowerRouter.get_category_allocation("weapon")
	#   _p_hand_l.amount_ratio = clampf(w + _boost_spike, 0.0, 1.0)
	#
	# Boot jets: maneuver branch + _boot_spike, AIRBORNE state only
	#   if move_state == MovementController.State.AIRBORNE:
	#       var m := GasRouter.get_branch_pressure("maneuver")
	#       _p_foot_l.amount_ratio = clampf(m + _boot_spike, 0.0, 1.0)
	#   else:
	#       _p_foot_l.amount_ratio = 0.0
	#
	# Chest beam: (sensor + defense) / 2 + _boost_spike, slow pulse
	#   var s   := PowerRouter.get_category_allocation("sensor")
	#   var d   := PowerRouter.get_category_allocation("defense")
	#   var pulse := 0.15 * sin(_pulse_phase)  # _pulse_phase += 1.2 * TAU * delta
	#   _p_chest.amount_ratio = clampf((s + d) * 0.5 + pulse + _boost_spike, 0.0, 1.0)


# ── Private ────────────────────────────────────────────────────────────────────

func _animate_thruster_bones(delta: float, hspeed: float, stats: SuitStats,
		_move_state: MovementController.State) -> void:
	var speed_ratio := clampf(hspeed / maxf(stats.boost_speed, 1.0), 0.0, 1.0)

	_back_angle = lerpf(_back_angle, speed_ratio * MAX_BACK_ANGLE, THRUSTER_SMOOTH * delta)
	_hand_angle = lerpf(_hand_angle, speed_ratio * MAX_HAND_ANGLE, THRUSTER_SMOOTH * delta)

	var back_rot := Quaternion(Vector3.RIGHT, deg_to_rad(_back_angle))
	var hand_rot := Quaternion(Vector3.RIGHT, deg_to_rad(-_hand_angle))

	_set_bone_rot("fx_back_l", back_rot)
	_set_bone_rot("fx_back_r", back_rot)
	_set_bone_rot("fx_hand_l", hand_rot)
	_set_bone_rot("fx_hand_r", hand_rot)


func _set_bone_rot(key: String, rot: Quaternion) -> void:
	var idx: int = _bi.get(key, -1)
	if idx >= 0:
		_skeleton.set_bone_pose_rotation(idx, rot)


func _on_boost_activated(_direction: Vector3) -> void:
	_boost_spike = 1.0


func _on_suit_launched(_position: Vector3) -> void:
	_boot_spike = 1.0
