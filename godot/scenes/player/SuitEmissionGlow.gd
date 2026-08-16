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
const GLOW_COLOR    := Color(1.0, 0.55, 0.16)   ## warm amber tint, shared by the
                                                 ## material glow and ember particles.

## Glow fades linearly to GLOW_FALLOFF_MIN by this distance (metres, bind pose)
## from the chest-socket bone. Surfaces past the radius still glow faintly
## rather than going fully dark.
const GLOW_FALLOFF_RADIUS := 1.3
const GLOW_FALLOFF_MIN    := 0.15

var _skeleton:  Skeleton3D = null
var _suit_root: Node3D     = null

# Duplicated material references keyed by role.
var _mats: Dictionary = {}   # "head", "body_01", "body_02", "equip_weapon", etc.

# Per-role distance falloff (0..1), keyed the same as _mats. Computed once in
# _setup_emission_materials() from actual mesh geometry — see _surface_centroid().
var _dist_factor: Dictionary = {}
var _chest_center: Vector3 = Vector3.ZERO

var _pulse_phase:    float = 0.0
var _crunch_override: float = 0.0
var _boost_lean:      float = 0.0
var _last_fall_speed: float = 0.0

# Ambient ember particles — spread across the torso to broaden the glow beyond
# the emissive-texture surfaces (see setup()/tick()).
var _p_ember:          GPUParticles3D = null
var _ember_anchor_bone: int           = -1


func setup(skeleton: Skeleton3D, suit_root: Node3D) -> void:
	_skeleton  = skeleton
	_suit_root = suit_root

	_setup_emission_materials()

	_ember_anchor_bone = _skeleton.find_bone("Chest_Socket")
	if _ember_anchor_bone < 0:
		_ember_anchor_bone = _skeleton.find_bone("spine_03")
	_p_ember = _make_ember_emitter()

	EventBus.suit_landed.connect(_on_suit_landed)
	EventBus.boost_activated.connect(_on_boost_activated)


func tick(ctx: Dictionary) -> void:
	var delta:    float   = ctx["delta"]
	var velocity: Vector3 = ctx["velocity"]

	if velocity.y < -0.5:
		_last_fall_speed = absf(velocity.y)

	# Advance pulse oscillator. Slower and shallower than before — a wide swing
	# reads as flickering rather than a soft glow.
	_pulse_phase = fmod(_pulse_phase + 0.7 * TAU * delta, TAU)
	var pulse    := 0.06 * sin(_pulse_phase)

	# sqrt() lifts the low end of the curve so the glow ramps in gently instead
	# of snapping bright, and the lowered clamp keeps peak brightness soft.
	# Each result is scaled by _dist_factor so surfaces farther from the chest
	# center glow proportionally less.
	if _mats.has("head"):
		_mats["head"].emission_energy_multiplier = clampf((sqrt(PowerRouter.get_category_allocation("sensor")) * 1.6 + pulse) * _dist_factor.get("head", 1.0), 0.0, 2.2)
	if _mats.has("body_01"):
		_mats["body_01"].emission_energy_multiplier = clampf((sqrt(PowerRouter.total_load_pct() / 100.0) * 1.4 + pulse) * _dist_factor.get("body_01", 1.0), 0.0, 2.2)
	if _mats.has("body_02"):
		_mats["body_02"].emission_energy_multiplier = clampf((sqrt(PowerRouter.total_load_pct() / 100.0) * 1.4 + pulse) * _dist_factor.get("body_02", 1.0), 0.0, 2.2)
	if _mats.has("equip_weapon"):
		_mats["equip_weapon"].emission_energy_multiplier = clampf((sqrt(PowerRouter.get_category_allocation("weapon")) * 1.5 + pulse) * _dist_factor.get("equip_weapon", 1.0), 0.0, 2.2)
	# Sensor/defense equipment plating — previously duplicated but never driven,
	# so the glow only covered head/body/weapon. Wiring these broadens coverage
	# to a larger area of the suit.
	if _mats.has("equip_sensor"):
		_mats["equip_sensor"].emission_energy_multiplier = clampf((sqrt(PowerRouter.get_category_allocation("sensor")) * 1.5 + pulse) * _dist_factor.get("equip_sensor", 1.0), 0.0, 2.2)
	if _mats.has("equip_def"):
		_mats["equip_def"].emission_energy_multiplier = clampf((sqrt(PowerRouter.get_category_allocation("defense")) * 1.5 + pulse) * _dist_factor.get("equip_def", 1.0), 0.0, 2.2)

	# Ambient ember particles — broadens the glow beyond the emissive-texture
	# surfaces into a soft cloud drifting off the torso.
	if _p_ember and _ember_anchor_bone >= 0:
		_p_ember.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_ember_anchor_bone)
		var load_frac := PowerRouter.total_load_pct() / 100.0
		_p_ember.amount_ratio = clampf(sqrt(load_frac) * 0.85 + pulse, 0.0, 1.0)

	# ── One-shot crunch / lean-back ─────────────────────────────────────────
	if _crunch_override > 0.0:
		var root := get_parent()._suit_root as Node3D
		root.rotation_degrees.x += _crunch_override
		_crunch_override = maxf(0.0, _crunch_override - 60.0 * delta)

	if _boost_lean < 0.0:
		var root := get_parent()._suit_root as Node3D
		root.rotation_degrees.x += _boost_lean
		_boost_lean = minf(0.0, _boost_lean + 30.0 * delta)


# ── Private ────────────────────────────────────────────────────────────────────

const _ROLE_TEXTURE_MAP := {
	"Head":     ["head",         "T_1034501_Head_E2.png"],
	"Body_01":  ["body_01",      "T_1034501_Body_01_02_E.png"],
	"Body_02":  ["body_02",      "T_1034501_Body_02_E.png"],
	"Equip_04": ["equip_weapon", "T_1034501_Equip_04_E.png"],
	"Equip_03": ["equip_sensor", "T_1034501_Equip_03_E.png"],
	"Equip_02": ["equip_def",    "T_1034501_Equip_02_E.png"],
}


func _setup_emission_materials() -> void:
	if not _suit_root:
		return

	var chest_bone := _skeleton.find_bone("Chest_Socket")
	if chest_bone >= 0:
		_chest_center = (_skeleton.global_transform * _skeleton.get_bone_global_rest(chest_bone)).origin

	var mesh_nodes := _suit_root.find_children("*", "MeshInstance3D", true, false)
	for mn: MeshInstance3D in mesh_nodes:
		for surf in mn.get_surface_override_material_count():
			var mat := mn.get_active_material(surf)
			if not mat is StandardMaterial3D:
				continue
			for name_substr: String in _ROLE_TEXTURE_MAP:
				if not mat.resource_name.contains(name_substr):
					continue
				var role_key: String = _ROLE_TEXTURE_MAP[name_substr][0]
				var tex_file: String = _ROLE_TEXTURE_MAP[name_substr][1]
				var tex := _load_image_texture(TEXTURE_BASE + tex_file)
				var dup := mat.duplicate() as StandardMaterial3D
				dup.emission_enabled = true
				if tex:
					dup.emission_texture = tex
				dup.emission = GLOW_COLOR
				dup.emission_energy_multiplier = 0.0
				mn.set_surface_override_material(surf, dup)
				_mats[role_key] = dup

				# Distance falloff — measured from this surface's actual bind-pose
				# geometry to the chest center, not a guessed per-role constant.
				if chest_bone >= 0:
					var centroid_world := mn.global_transform * _surface_centroid(mn.mesh, surf)
					var dist := centroid_world.distance_to(_chest_center)
					_dist_factor[role_key] = clampf(1.0 - dist / GLOW_FALLOFF_RADIUS, GLOW_FALLOFF_MIN, 1.0)
				else:
					_dist_factor[role_key] = 1.0
				break


## Centroid of a surface's bind-pose vertices, in the mesh's local space.
func _surface_centroid(mesh: Mesh, surf: int) -> Vector3:
	var arrays := mesh.surface_get_arrays(surf)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for v in verts:
		sum += v
	return sum / verts.size()


func _make_ember_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount       = 70
	p.lifetime     = 1.3
	p.local_coords = false
	p.amount_ratio = 0.0
	p.emitting     = true

	var mat := ParticleProcessMaterial.new()
	mat.direction               = Vector3(0, 1, 0)
	mat.spread                  = 45.0
	mat.initial_velocity_min    = 0.05
	mat.initial_velocity_max    = 0.22
	mat.gravity                 = Vector3(0, 0.12, 0)   ## gentle heat-shimmer drift
	mat.scale_min                = 0.5
	mat.scale_max                = 1.4
	mat.color                    = GLOW_COLOR
	mat.emission_shape           = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents     = Vector3(0.30, 0.42, 0.20)   ## spans the torso — "larger area"
	p.process_material = mat

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.018, 0.018)   ## "smaller particles"
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode                = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency                = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode                  = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.billboard_mode              = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_mat.vertex_color_use_as_albedo  = true
	draw_mat.albedo_color                = GLOW_COLOR
	draw_mat.albedo_texture              = _make_dot_texture()   ## soft radial falloff
	mesh.material = draw_mat
	p.draw_pass_1 = mesh

	add_child(p)
	return p


## Soft radial-falloff dot — without it each particle renders as a hard-edged
## flat quad instead of a soft glow.
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


func _load_image_texture(res_path: String) -> ImageTexture:
	var abs_path := ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	if img.load(abs_path) != OK:
		push_warning("[SuitEmissionGlow] Could not load emission texture: " + res_path)
		return null
	return ImageTexture.create_from_image(img)


func _on_suit_landed(_position: Vector3, _thermal: float) -> void:
	_crunch_override = clampf(_last_fall_speed * 0.8, 2.0, 15.0)


func _on_boost_activated(_direction: Vector3) -> void:
	_boost_lean = -12.0
