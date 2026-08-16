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

## GasRouter puff cadence: interval between bursts lerps from MAX (idle) to
## MIN (full branch pressure) — higher demand fires more frequent puffs
## instead of a brighter continuous stream, matching real RCS thruster fire.
const BACK_PULSE_MAX_INTERVAL := 0.55
const BACK_PULSE_MIN_INTERVAL := 0.10
const FOOT_PULSE_MAX_INTERVAL := 0.45
const FOOT_PULSE_MIN_INTERVAL := 0.08

# ── State ──────────────────────────────────────────────────────────────────────
var _skeleton: Skeleton3D = null
var _bi:       Dictionary = {}

var _back_angle:   float = 0.0
var _hand_angle:   float = 0.0

# Rest-pose rotation cache, keyed by BONE_NAMES key. set_bone_pose_rotation()
# sets the ABSOLUTE local pose rotation, not a delta from rest — every write
# below must be composed as (rest_rotation * delta_rotation) or it discards
# the bone's bind-pose bend entirely.
var _rest_rot: Dictionary = {}

const _DRIVEN_BONES := ["fx_back_l", "fx_back_r", "fx_hand_l", "fx_hand_r"]

# Transient override values for event-driven spikes (decay toward 0 each frame).
var _boost_spike:          float = 0.0   ## hand repulsor + chest beam spike on boost_activated
var _boot_spike:           float = 0.0   ## boot jet spike on suit_launched
var _rapid_descent_spike:  float = 0.0   ## back + foot burst on rapid_descent_activated

# Particle node references — assigned in setup().
var _p_back_l:    GPUParticles3D = null
var _p_back_r:    GPUParticles3D = null
var _p_hand_l:    GPUParticles3D = null
var _p_hand_r:    GPUParticles3D = null
var _p_foot_l:    GPUParticles3D = null
var _p_foot_r:    GPUParticles3D = null
var _p_chest:     GPUParticles3D = null

var _pulse_phase: float = 0.0   ## chest beam slow pulse

## Shared soft radial-falloff texture — without it each particle renders as a
## flat-colored quad with hard edges ("blocky"). Built once, reused by every
## emitter's draw pass.
var _dot_tex: GradientTexture2D = null

var _back_pulse_t: float = 0.0   ## countdown to next back-thruster puff
var _foot_pulse_t: float = 0.0   ## countdown to next boot-jet puff


func setup(skeleton: Skeleton3D, bi: Dictionary) -> void:
	_skeleton = skeleton
	_bi       = bi

	for key in _DRIVEN_BONES:
		var idx: int = _bi.get(key, -1)
		if idx >= 0:
			_rest_rot[key] = _skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()

	EventBus.boost_activated.connect(_on_boost_activated)
	EventBus.suit_launched.connect(_on_suit_launched)
	EventBus.rapid_descent_activated.connect(_on_rapid_descent_activated)

	_dot_tex = _make_dot_texture()

	# RCS gas puff: backward (+Z local), tight cone, cold pale-white burst —
	# distinct from PowerRouter's saturated energy colors (hand/chest below).
	_p_back_l = _make_emitter({
		"color": Color(0.88, 0.94, 1.0), "direction": Vector3(0, 0, 1),
		"spread": 8.0, "vel_min": 6.0, "vel_max": 9.5,
		"lifetime": 0.22, "amount": 40, "mesh_size": Vector2(0.035, 0.035),
		"explosiveness": 0.9,
	})
	_p_back_r = _make_emitter({
		"color": Color(0.88, 0.94, 1.0), "direction": Vector3(0, 0, 1),
		"spread": 8.0, "vel_min": 6.0, "vel_max": 9.5,
		"lifetime": 0.22, "amount": 40, "mesh_size": Vector2(0.035, 0.035),
		"explosiveness": 0.9,
	})

	# Repulsor beam: tight forward blue-white bolt out of the palm.
	_p_hand_l = _make_emitter({
		"color": Color(0.45, 0.8, 1.0), "direction": Vector3(0, 0, -1),
		"spread": 6.0, "vel_min": 8.0, "vel_max": 12.0,
		"lifetime": 0.25, "amount": 16, "mesh_size": Vector2(0.07, 0.07),
	})
	_p_hand_r = _make_emitter({
		"color": Color(0.45, 0.8, 1.0), "direction": Vector3(0, 0, -1),
		"spread": 6.0, "vel_min": 8.0, "vel_max": 12.0,
		"lifetime": 0.25, "amount": 16, "mesh_size": Vector2(0.07, 0.07),
	})

	# Boot RCS puffs: downward, tight cone, same cold pale-gas treatment as
	# the back thrusters so both GasRouter-driven emitters read as one family.
	_p_foot_l = _make_emitter({
		"color": Color(0.85, 0.92, 1.0), "direction": Vector3(0, -1, 0),
		"spread": 9.0, "vel_min": 5.5, "vel_max": 9.0,
		"lifetime": 0.20, "amount": 34, "mesh_size": Vector2(0.03, 0.03),
		"explosiveness": 0.9,
	})
	_p_foot_r = _make_emitter({
		"color": Color(0.85, 0.92, 1.0), "direction": Vector3(0, -1, 0),
		"spread": 9.0, "vel_min": 5.5, "vel_max": 9.0,
		"lifetime": 0.20, "amount": 34, "mesh_size": Vector2(0.03, 0.03),
		"explosiveness": 0.9,
	})

	# Chest beam: soft cyan-white glow puffs, near-omnidirectional, slow drift.
	_p_chest = _make_emitter({
		"color": Color(0.5, 0.9, 1.0), "direction": Vector3(0, 1, 0),
		"spread": 180.0, "vel_min": 0.4, "vel_max": 0.9,
		"lifetime": 0.6, "amount": 12, "mesh_size": Vector2(0.06, 0.06),
	})


func _make_dot_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient  = grad
	tex.width     = 32
	tex.height    = 32
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	return tex


func _make_emitter(cfg: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount        = cfg.get("amount", 20)
	p.lifetime      = cfg.get("lifetime", 0.4)
	p.local_coords  = false   ## emitted particles fly in world space, independent
	                          ## of the emitter's per-frame bone repositioning.
	p.amount_ratio  = 0.0
	p.emitting      = true
	## explosiveness bunches an emission cycle into a single burst instead of a
	## steady trickle — RCS gas puffs read as discrete clouds, not a flame jet.
	p.explosiveness = cfg.get("explosiveness", 0.0)

	var mat := ParticleProcessMaterial.new()
	mat.direction             = cfg["direction"]
	mat.spread                = cfg.get("spread", 15.0)
	mat.initial_velocity_min  = cfg.get("vel_min", 3.0)
	mat.initial_velocity_max  = cfg.get("vel_max", 6.0)
	mat.gravity               = Vector3.ZERO
	mat.scale_min             = 0.7
	mat.scale_max             = 1.3
	mat.color                 = cfg["color"]
	p.process_material = mat

	var mesh := QuadMesh.new()
	mesh.size = cfg.get("mesh_size", Vector2(0.1, 0.1))
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode                = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.billboard_mode            = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.albedo_color              = cfg["color"]
	draw_mat.albedo_texture            = _dot_tex
	mesh.material = draw_mat
	p.draw_pass_1 = mesh

	add_child(p)
	return p


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
	_boost_spike          = maxf(0.0, _boost_spike          - 4.0 * delta)
	_boot_spike           = maxf(0.0, _boot_spike           - 8.0 * delta)
	_rapid_descent_spike  = maxf(0.0, _rapid_descent_spike  - 3.0 * delta)

	# ── Position + drive particle emitters ─────────────────────────────────────
	_position_emitter(_p_back_l, "fx_back_l")
	_position_emitter(_p_back_r, "fx_back_r")
	_position_emitter(_p_hand_l, "fx_hand_l")
	_position_emitter(_p_hand_r, "fx_hand_r")
	_position_emitter(_p_foot_l, "fx_foot_l")
	_position_emitter(_p_foot_r, "fx_foot_r")
	_position_emitter(_p_chest,  "chest_beam")

	# Back thrusters: active in FLIGHT state; asymmetric during roll.
	# GasRouter branches fire as discrete puffs — cadence scales with demand
	# instead of brightening a continuous stream (see BACK_PULSE_* above).
	# Rapid descent spike fires full burst regardless of state (dorsal pack dumps all pressure).
	var back_ratio := 0.0
	if move_state == MovementController.State.FLIGHT:
		back_ratio = GasRouter.get_branch_pressure("directional")
	back_ratio = clampf(back_ratio + _rapid_descent_spike, 0.0, 1.0)
	var roll_z := 0.0
	var suit_body := get_parent().get_parent() as CharacterBody3D
	if suit_body:
		roll_z = suit_body.rotation.z
	var bias := clampf(roll_z / (PI * 0.5), -1.0, 1.0) * (MAX_ROLL_BIAS / 100.0)
	if _p_back_l: _p_back_l.amount_ratio = clampf(back_ratio + bias, 0.0, 1.0)
	if _p_back_r: _p_back_r.amount_ratio = clampf(back_ratio - bias, 0.0, 1.0)

	if back_ratio > 0.01:
		_back_pulse_t -= delta
		if _back_pulse_t <= 0.0:
			_back_pulse_t = lerpf(BACK_PULSE_MAX_INTERVAL, BACK_PULSE_MIN_INTERVAL, back_ratio)
			if _p_back_l: _p_back_l.restart()
			if _p_back_r: _p_back_r.restart()
	else:
		_back_pulse_t = 0.0

	# Hand repulsors: weapon bus + boost spike.
	var w := PowerRouter.get_category_allocation("weapon")
	var hand_ratio := clampf(w + _boost_spike, 0.0, 1.0)
	if _p_hand_l: _p_hand_l.amount_ratio = hand_ratio
	if _p_hand_r: _p_hand_r.amount_ratio = hand_ratio

	# Boot jets: maneuver branch + boot spike, AIRBORNE only. Same puff cadence
	# treatment as the back thrusters. Rapid descent also fires boot jets
	# (dorsal pack + foot vents together drive the dive).
	var foot_ratio := 0.0
	if move_state == MovementController.State.AIRBORNE:
		var m := GasRouter.get_branch_pressure("maneuver")
		foot_ratio = clampf(m + _boot_spike + _rapid_descent_spike, 0.0, 1.0)
	if _p_foot_l: _p_foot_l.amount_ratio = foot_ratio
	if _p_foot_r: _p_foot_r.amount_ratio = foot_ratio

	if foot_ratio > 0.01:
		_foot_pulse_t -= delta
		if _foot_pulse_t <= 0.0:
			_foot_pulse_t = lerpf(FOOT_PULSE_MAX_INTERVAL, FOOT_PULSE_MIN_INTERVAL, foot_ratio)
			if _p_foot_l: _p_foot_l.restart()
			if _p_foot_r: _p_foot_r.restart()
	else:
		_foot_pulse_t = 0.0

	# Chest beam: (sensor + defense) / 2 + boost spike, slow pulse.
	_pulse_phase = fmod(_pulse_phase + 1.2 * TAU * delta, TAU)
	var s := PowerRouter.get_category_allocation("sensor")
	var d := PowerRouter.get_category_allocation("defense")
	var pulse := 0.15 * sin(_pulse_phase)
	if _p_chest:
		_p_chest.amount_ratio = clampf((s + d) * 0.5 + pulse + _boost_spike, 0.0, 1.0)


func _position_emitter(p: GPUParticles3D, bone_key: String) -> void:
	if not p:
		return
	var idx: int = _bi.get(bone_key, -1)
	if idx < 0:
		return
	p.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(idx)


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


func _set_bone_rot(key: String, delta_rot: Quaternion) -> void:
	var idx: int = _bi.get(key, -1)
	if idx >= 0:
		var rest: Quaternion = _rest_rot.get(key, Quaternion.IDENTITY)
		_skeleton.set_bone_pose_rotation(idx, rest * delta_rot)


func _on_boost_activated(_direction: Vector3) -> void:
	_boost_spike = 1.0


func _on_suit_launched(_position: Vector3) -> void:
	_boot_spike = 1.0


func _on_rapid_descent_activated(_position: Vector3) -> void:
	_rapid_descent_spike = 1.0
