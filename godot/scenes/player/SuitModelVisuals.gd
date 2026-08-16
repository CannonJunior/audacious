extends Node3D
## Coordinator for all suit visual animation.
## Loads the GLB, builds the bone index cache, applies root lean/bob each frame,
## then delegates to four subsystem nodes for specialised work.
## Each subsystem lives in its own .gd file — edit those, not this one.

const SUIT_SCENE_PATH := "res://assets/suit/iron_man.glb"

# Preloads guarantee the subsystem scripts are parsed before this file uses their
# types as annotations — class_name global registration order is undefined.
const _ThrusterVFX     = preload("res://scenes/player/SuitThrusterVFX.gd")
const _LegIK           = preload("res://scenes/player/SuitLegIK.gd")
const _SecondaryMotion = preload("res://scenes/player/SuitSecondaryMotion.gd")
const _EmissionGlow    = preload("res://scenes/player/SuitEmissionGlow.gd")

# ── Bone name map ─────────────────────────────────────────────────────────────
## Single point of coupling to the skeleton. If the model changes, update values
## here; all subsystems use the resolved _bi index dict, not raw strings.
const BONE_NAMES := {
	# Spine / torso
	"pelvis":   "pelvis",
	"spine_01": "spine_01",
	"spine_02": "spine_02",
	"spine_03": "spine_03",
	"spine_04": "spine_04",
	"spine_05": "spine_05",
	"neck_01":  "neck_01",
	"neck_02":  "neck_02",
	"head":     "head",
	# Arms
	"clavicle_l": "clavicle_l",
	"upperarm_l": "upperarm_l",
	"lowerarm_l": "lowerarm_l",
	"hand_l":     "hand_l",
	"clavicle_r": "clavicle_r",
	"upperarm_r": "upperarm_r",
	"lowerarm_r": "lowerarm_r",
	"hand_r":     "hand_r",
	# Legs
	"thigh_l": "thigh_l",
	"calf_l":  "calf_l",
	"foot_l":  "foot_l",
	"ball_l":  "ball_l",
	"thigh_r": "thigh_r",
	"calf_r":  "calf_r",
	"foot_r":  "foot_r",
	"ball_r":  "ball_r",
	# IK target bones (read-only reference; not driven by this system)
	"ik_foot_l":    "ik_foot_l",
	"ik_foot_r":    "ik_foot_r",
	"ik_foot_root": "ik_foot_root",
	# FX emission / thruster attachment points
	"fx_back_l":    "FX_BackFire_L",
	"fx_back_r":    "FX_BackFire_R",
	"fx_hand_l":    "FX_Hand_L",
	"fx_hand_r":    "FX_Hand_R",
	"fx_foot_l":    "FX_Ball_L",
	"fx_foot_r":    "FX_Ball_R",
	"fx_head":      "FX_Head",
	"fx_spine":     "FX_Spine_05",
	"chest_beam":   "Chest_Beam",
	"chest_socket": "Chest_Socket",
	# Weapon attachment sockets
	"weapon_r": "WeaponPoint",
	"weapon_l": "WeaponPoint_L",
	# Armor plate jiggle targets (six most prominent panels)
	"chest_armor_l":    "L_ChestArmor_A_01_Jnt",
	"chest_armor_r":    "R_ChestArmor_A_01_Jnt",
	"shoulder_armor_l": "L_Shoulder_Armor_1_Jnt",
	"shoulder_armor_r": "R_Shoulder_Armor_1_Jnt",
	"knee_armor_l":     "L_Knee_Armor_3_Jnt",
	"knee_armor_r":     "R_Knee_Armor_3_Jnt",
	# Floating weapon drone attachment points
	"float_gun_1": "FloatingGun1",
	"float_gun_2": "FloatingGun2",
	"float_gun_3": "FloatingGun3",
}

# ── Root lean / bob tuning ─────────────────────────────────────────────────────
const SMOOTH        := 7.0
const MAX_FWD_LEAN  := 90.0
const MAX_SIDE_LEAN :=  8.0
const MAX_BANK      := 10.0
const BANK_FACTOR   := 25.0
const BOB_AMP       :=  0.04
const BOB_FREQ      :=  2.4
const HOVER_AMP     :=  0.05
const HOVER_FREQ    :=  0.65
const GAIT_FREQ     :=  2.0    ## arm-swing cycles per second at full ground speed
const GAIT_REF_SPEED := 8.0   ## m/s — speed at which gait animation reaches 100% intensity

# ── State ──────────────────────────────────────────────────────────────────────
var _suit_root: Node3D     = null
var _skeleton:  Skeleton3D = null

## Bone index cache. Key = BONE_NAMES key (e.g. "thigh_l"), value = int index.
## -1 means the bone was not found in this model's skeleton.
var _bi := {}

var _lean_fwd:   float = 0.0
var _lean_side:  float = 0.0
var _bank:       float = 0.0
var _bob_phase:  float = 0.0
var _gait_phase: float = 0.0
var _prev_rot_y: float = 0.0

@onready var _suit:     SuitBody           = get_parent()
@onready var _movement: MovementController = $"../MovementController"

# Subsystem nodes — instantiated in _init_subsystems() after GLB load.
var _thruster_vfx:     _ThrusterVFX     = null
var _leg_ik:           _LegIK           = null
var _secondary_motion: _SecondaryMotion = null
var _emission_glow:    _EmissionGlow    = null


# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	var doc  := GLTFDocument.new()
	var gltf := GLTFState.new()
	var path := ProjectSettings.globalize_path(SUIT_SCENE_PATH)
	if doc.append_from_file(path, gltf) != OK:
		push_error("[SuitModelVisuals] Could not load: " + SUIT_SCENE_PATH)
		return

	_suit_root = doc.generate_scene(gltf)
	add_child(_suit_root)
	_setup_skeleton()

	# The GLB embeds an AnimationPlayer (animation/import=true in the .import file).
	# AnimationPlayer processes AFTER _process in Godot 4's frame pipeline, so it
	# overwrites every set_bone_pose_rotation call made by the procedural systems.
	# Disabling it here gives the procedural systems full ownership of the skeleton.
	for ap: AnimationPlayer in _suit_root.find_children("*", "AnimationPlayer", true, false):
		ap.active = false

	var placeholder := get_parent().get_node_or_null("Visuals")
	if placeholder:
		placeholder.visible = false

	_prev_rot_y = _suit.rotation.y
	_init_subsystems()


func _process(delta: float) -> void:
	if not _suit_root or not _movement or delta <= 0.0:
		return
	_animate(delta)


# ── Setup ──────────────────────────────────────────────────────────────────────

func _setup_skeleton() -> void:
	var found := _suit_root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("[SuitModelVisuals] No Skeleton3D found in loaded model.")
		return
	_skeleton = found[0] as Skeleton3D

	for key: String in BONE_NAMES:
		var idx := _skeleton.find_bone(BONE_NAMES[key])
		_bi[key] = idx
		if idx < 0:
			push_warning("[SuitModelVisuals] Bone not found: %s (%s)" % [key, BONE_NAMES[key]])


func _init_subsystems() -> void:
	_thruster_vfx = _ThrusterVFX.new()
	add_child(_thruster_vfx)
	_thruster_vfx.setup(_skeleton, _bi)

	_leg_ik = _LegIK.new()
	add_child(_leg_ik)
	_leg_ik.setup(_skeleton, _bi, _suit as CharacterBody3D)

	_secondary_motion = _SecondaryMotion.new()
	add_child(_secondary_motion)
	_secondary_motion.setup(_skeleton, _bi)

	_emission_glow = _EmissionGlow.new()
	add_child(_emission_glow)
	_emission_glow.setup(_skeleton, _suit_root)


# ── Animation ──────────────────────────────────────────────────────────────────

func _animate(delta: float) -> void:
	var vel       := _suit.velocity
	var stats     := _suit.get_stats()
	var ref_speed := maxf(stats.ground_sprint_speed, 1.0)
	var hspeed    := Vector2(vel.x, vel.z).length()
	var local_vel := _suit.global_transform.basis.inverse() * vel
	var yaw_rate  := (_suit.rotation.y - _prev_rot_y) / delta
	_prev_rot_y    = _suit.rotation.y

	var move_state := _movement.current_state

	# ── Forward / back lean (X rotation) ──────────────────────────────────────
	var fwd_ref    := maxf(stats.boost_speed, 1.0)
	var target_fwd := clampf(local_vel.z / fwd_ref * MAX_FWD_LEAN, -MAX_FWD_LEAN, MAX_FWD_LEAN)
	_lean_fwd       = lerpf(_lean_fwd, target_fwd, SMOOTH * delta)

	# ── Strafe lean (Z rotation) — suppressed while physically rolling ─────────
	# roll_suppress ramps from 0→1 as SuitBody.rotation.z goes 0→90°, so strafe
	# lean fades out before the two rotations compound visually.
	var roll_suppress := clampf(absf(_suit.rotation.z) / (PI * 0.5), 0.0, 1.0)
	var target_side   := clampf(
		-local_vel.x / ref_speed * MAX_SIDE_LEAN, -MAX_SIDE_LEAN, MAX_SIDE_LEAN)
	target_side        *= (1.0 - roll_suppress)
	_lean_side          = lerpf(_lean_side, target_side, SMOOTH * delta)

	# ── Turn bank (Y rotation) ─────────────────────────────────────────────────
	var target_bank := clampf(yaw_rate * BANK_FACTOR, -MAX_BANK, MAX_BANK)
	_bank            = lerpf(_bank, target_bank, SMOOTH * delta)

	# ── Vertical bob / hover (Y position) ─────────────────────────────────────
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

	# ── Apply root transforms ──────────────────────────────────────────────────
	_suit_root.rotation_degrees = Vector3(_lean_fwd, _bank, _lean_side)
	_suit_root.position.y = lerpf(_suit_root.position.y, target_y, 10.0 * delta)

	# ── Gait phase — advances with speed when grounded, shared by subsystems ──
	# GAIT_REF_SPEED (8 m/s) is the reference, not ground_sprint_speed (60–200 m/s).
	# Using sprint speed would make gait_intensity < 5% at typical movement speeds.
	var gait_intensity := 0.0
	if move_state == MovementController.State.GROUNDED:
		gait_intensity = clampf(hspeed / GAIT_REF_SPEED, 0.0, 1.0)
		_gait_phase = fmod(_gait_phase + gait_intensity * GAIT_FREQ * TAU * delta, TAU)

	# ── Build per-frame context and tick subsystems ────────────────────────────
	var ctx := {
		"delta":          delta,
		"velocity":       vel,
		"local_vel":      local_vel,
		"hspeed":         hspeed,
		"move_state":     move_state,
		"stats":          stats,
		"yaw_rate":       yaw_rate,
		"lean_fwd":       _lean_fwd,
		"gait_phase":     _gait_phase,
		"gait_intensity": gait_intensity,
	}

	if _thruster_vfx: _thruster_vfx.tick(ctx)
	if _leg_ik:
		_leg_ik.tick(ctx)
		ctx["gait_weight"] = _leg_ik.gait_weight_right
	if _secondary_motion: _secondary_motion.tick(ctx)
	if _emission_glow:    _emission_glow.tick(ctx)
