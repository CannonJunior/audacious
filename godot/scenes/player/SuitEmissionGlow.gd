class_name SuitEmissionGlow
extends Node
## SESSION D — Power-state emission glow + event-driven one-shot impact reactions.
##
## ── Part 1: Emission glow ──────────────────────────────────────────────────────
##   The GLB's materials have emissiveFactor=[0,0,0] and no emissiveTexture set.
##   Eleven emission PNGs exist in res://assets/suit/textures/ but are unlinked.
##   This system loads them, duplicates the materials (MUST duplicate before
##   writing or you mutate a shared resource), assigns the textures, and then
##   drives emission_energy_multiplier each frame from PowerRouter allocations.
##
##   Surface → material name → emission texture path:
##     0  MI_1034501_Head      → T_1034501_Head_E2.png
##     1  MI_1034501_Body_01   → T_1034501_Body_01_02_E.png  (primary emission)
##     2  MI_1034501_Body_02   → T_1034501_Body_02_E.png
##     4  MI_1034501_Equip_04  → T_1034501_Equip_04_E.png
##     5  MI_1034501_Equip_03  → T_1034501_Equip_03_E.png
##     6  MI_1034501_Equip_02  → T_1034501_Equip_02_E.png
##   (surfaces 3, 7, 8, 9 have no corresponding emission texture)
##
##   Access pattern (do NOT use surface index as a hardcoded constant):
##     var mesh_nodes := suit_root.find_children("*","MeshInstance3D",true,false)
##     for mn in mesh_nodes:
##         for surf in mn.surface_get_material_count():
##             var mat := (mn as MeshInstance3D).get_active_material(surf)
##             if mat is StandardMaterial3D and mat.resource_name == "MI_...":
##                 var dup := mat.duplicate() as StandardMaterial3D
##                 dup.emission_enabled   = true
##                 dup.emission_texture   = load(TEXTURE_BASE + "_E.png")
##                 dup.emission_energy_multiplier = 0.0  # start dark
##                 (mn as MeshInstance3D).set_surface_override_material(surf, dup)
##                 _mats["head"] = dup   # store reference for per-frame update
##
##   CRITICAL: check `mat is StandardMaterial3D` before casting. If the GLB
##   importer produced a different type, skip that surface — don't crash.
##
##   Per-frame emission update (in tick()):
##     _mats["head"].emission_energy_multiplier =
##         PowerRouter.get_category_allocation("sensor") * 3.0 + _pulse
##     _mats["body"].emission_energy_multiplier =
##         (PowerRouter.total_load_pct() / 100.0) * 2.0 + _pulse
##     _mats["weapon_equip"].emission_energy_multiplier =
##         PowerRouter.get_category_allocation("weapon") * 2.5 + _pulse
##   where _pulse = 0.15 * sin(_pulse_phase) and _pulse_phase += 1.2 * TAU * delta.
##
## ── Part 2: Event-driven one-shot reactions ────────────────────────────────────
##   These drive the COORDINATOR's root lean values indirectly by adjusting
##   properties of _suit_root — NOT by touching bones. Because _suit_root is a
##   Node3D child of SuitModelVisuals (the coordinator), we access it via
##   get_parent()._suit_root.
##
##   Landing crunch:
##     On EventBus.suit_landed: set _crunch_override = clamp(fall_speed*0.8, 2, 15) deg.
##     Cache fall_speed each tick() from ctx["velocity"].y < -0.5.
##     In tick(): if _crunch_override > 0:
##         var root := get_parent()._suit_root as Node3D
##         root.rotation_degrees.x += _crunch_override  # spike forward
##         _crunch_override = maxf(0.0, _crunch_override - 60.0 * delta)  # decay ~0.25s
##     The coordinator's SMOOTH lerp brings lean_fwd back to velocity-based target.
##
##   Boost ignition lean-back:
##     On EventBus.boost_activated: set _boost_lean = -12.0 deg.
##     In tick(): same decay pattern but subtracts from root.rotation_degrees.x.
##     Decays at 30 deg/s → gone in 0.4 s.
##
##   Event connections (in setup()):
##     EventBus.suit_landed.connect(_on_suit_landed)
##     EventBus.boost_activated.connect(_on_boost_activated)

const TEXTURE_BASE := "res://assets/suit/textures/"

var _skeleton:  Skeleton3D = null
var _suit_root: Node3D     = null

# Duplicated material references keyed by role.
var _mats: Dictionary = {}   # "head", "body_01", "body_02", "equip_weapon", etc.

var _pulse_phase:    float = 0.0
var _crunch_override: float = 0.0
var _boost_lean:      float = 0.0
var _last_fall_speed: float = 0.0


func setup(skeleton: Skeleton3D, suit_root: Node3D) -> void:
	_skeleton  = skeleton
	_suit_root = suit_root

	_setup_emission_materials()

	EventBus.suit_landed.connect(_on_suit_landed)
	EventBus.boost_activated.connect(_on_boost_activated)


func tick(ctx: Dictionary) -> void:
	var delta:    float   = ctx["delta"]
	var velocity: Vector3 = ctx["velocity"]

	if velocity.y < -0.5:
		_last_fall_speed = absf(velocity.y)

	# Advance pulse oscillator.
	_pulse_phase = fmod(_pulse_phase + 1.2 * TAU * delta, TAU)
	var pulse    := 0.15 * sin(_pulse_phase)

	# TODO (Session D): drive emission_energy_multiplier on each stored material.
	# Example:
	#   if _mats.has("head") and _mats["head"] is StandardMaterial3D:
	#       _mats["head"].emission_energy_multiplier =
	#           clampf(PowerRouter.get_category_allocation("sensor") * 3.0 + pulse, 0.0, 4.0)

	# ── One-shot crunch / lean-back ─────────────────────────────────────────
	# TODO (Session D): apply and decay _crunch_override and _boost_lean.
	# Example for landing crunch:
	#   if _crunch_override > 0.0:
	#       var root := get_parent()._suit_root as Node3D
	#       root.rotation_degrees.x += _crunch_override
	#       _crunch_override = maxf(0.0, _crunch_override - 60.0 * delta)
	#
	# Boost lean-back (negative = lean back):
	#   if _boost_lean < 0.0:
	#       var root := get_parent()._suit_root as Node3D
	#       root.rotation_degrees.x += _boost_lean
	#       _boost_lean = minf(0.0, _boost_lean + 30.0 * delta)


# ── Private ────────────────────────────────────────────────────────────────────

func _setup_emission_materials() -> void:
	if not _suit_root:
		return

	# TODO (Session D): discover MeshInstance3D children, duplicate materials,
	# assign emission textures, and populate _mats.
	#
	# Map of material name substring → role key → texture file:
	#   "Head"     → "head"         → TEXTURE_BASE + "T_1034501_Head_E2.png"
	#   "Body_01"  → "body_01"      → TEXTURE_BASE + "T_1034501_Body_01_02_E.png"
	#   "Body_02"  → "body_02"      → TEXTURE_BASE + "T_1034501_Body_02_E.png"
	#   "Equip_04" → "equip_weapon" → TEXTURE_BASE + "T_1034501_Equip_04_E.png"
	#   "Equip_03" → "equip_sensor" → TEXTURE_BASE + "T_1034501_Equip_03_E.png"
	#   "Equip_02" → "equip_def"    → TEXTURE_BASE + "T_1034501_Equip_02_E.png"
	#
	# Remember: MUST call mat.duplicate() before setting any property.
	# MUST check `mat is StandardMaterial3D` before casting.
	# Use set_surface_override_material() to write the duplicate back.
	pass


func _on_suit_landed(_position: Vector3, _thermal: float) -> void:
	_crunch_override = clampf(_last_fall_speed * 0.8, 2.0, 15.0)


func _on_boost_activated(_direction: Vector3) -> void:
	_boost_lean = -12.0
