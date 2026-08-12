## SuitViewer3D — manages the 3D suit display inside the workshop SubViewport.
## Attach to the root Node3D of the suit's 3D sub-scene.
##
## Surface mapping (mesh_surface_indices on SuitPartResource) must be filled in
## by inspecting mesh surface names in the Godot editor after first run:
##   1. Add a breakpoint after _find_mesh_instances to print node/surface names.
##   2. Note which surface index maps to each body region.
##   3. Set mesh_surface_indices on each SuitPartResource .tres accordingly.
class_name SuitViewer3D
extends Node3D

const SUIT_SCENE_PATH := "res://assets/suit/iron_man.glb"
const SHADER_PATH     := "res://suit_workshop/shaders/suit_surface.gdshader"

const TEXTURE_SETS: Dictionary = {
	"Body_01": {
		"albedo":   "res://assets/suit/textures/T_1034501_Body_01_D.png",
		"normal":   "res://assets/suit/textures/T_1034501_Body_01_N.png",
		"orm":      "res://assets/suit/textures/T_1034501_Body_01_ORM.png",
		"emissive": "res://assets/suit/textures/T_1034501_Body_01_04_E.png",
		"specular": "res://assets/suit/textures/T_1034501_Body_01_S.png",
	},
	"Body_02": {
		"albedo":   "res://assets/suit/textures/T_1034501_Body_02_D.png",
		"normal":   "res://assets/suit/textures/T_1034501_Body_02_N.png",
		"orm":      "res://assets/suit/textures/T_1034501_Body_02_ORM.png",
		"emissive": "res://assets/suit/textures/T_1034501_Body_02_E.png",
		"specular": "res://assets/suit/textures/T_1034501_Body_02_S.png",
	},
	"Equip_01": {
		"albedo":   "res://assets/suit/textures/T_1034501_Equip_01_D.png",
		"normal":   "res://assets/suit/textures/T_1034501_Equip_01_N.png",
		"orm":      "res://assets/suit/textures/T_1034501_Equip_01_ORM.png",
		"emissive": "res://assets/suit/textures/T_1034501_Equip_01_S.png",
		"specular": "res://assets/suit/textures/T_1034501_Equip_01_S.png",
	},
	"Equip_02": {
		"albedo":   "res://assets/suit/textures/T_1034501_Equip_02_D.png",
		"normal":   "res://assets/suit/textures/T_1034501_Equip_02_N.png",
		"orm":      "res://assets/suit/textures/T_1034501_Equip_02_ORM.png",
		"emissive": "res://assets/suit/textures/T_1034501_Equip_02_E.png",
		"specular": "res://assets/suit/textures/T_1034501_Equip_02_S.png",
	},
	"Equip_03": {
		"albedo":   "res://assets/suit/textures/T_1034501_Equip_03_D.png",
		"normal":   "res://assets/suit/textures/T_1034501_Equip_03_N.png",
		"orm":      "res://assets/suit/textures/T_1034501_Equip_03_ORM.png",
		"emissive": "res://assets/suit/textures/T_1034501_Equip_03_E.png",
		"specular": "res://assets/suit/textures/T_1034501_Equip_03_S.png",
	},
	"Equip_04": {
		"albedo":   "res://assets/suit/textures/T_1034501_Equip_04_D.png",
		"normal":   "res://assets/suit/textures/T_1034501_Equip_04_N.png",
		"orm":      "res://assets/suit/textures/T_1034501_Equip_04_ORM.png",
		"emissive": "res://assets/suit/textures/T_1034501_Equip_04_E.png",
		"specular": "res://assets/suit/textures/T_1034501_Equip_04_S.png",
	},
	"Head": {
		"albedo":   "res://assets/suit/textures/T_1034501_Head_D.png",
		"normal":   "res://assets/suit/textures/T_1034501_Head_N.png",
		"orm":      "res://assets/suit/textures/T_1034501_Head_ORM.png",
		"emissive": "res://assets/suit/textures/T_1034501_Head_E2.png",
		"specular": "res://assets/suit/textures/T_1034501_Head_S.png",
	},
}

# Maps GLB primitive material names → TEXTURE_SETS key.
# Surface order confirmed by parsing iron_man.glb JSON chunk:
#   0=Head, 1=Body_01, 2=Body_02, 3=Equip_05, 4=Equip_04,
#   5=Equip_03, 6=Equip_02, 7=Equip_01, 8=Hide, 9=FloatingGun_02
const SURFACE_NAME_MAP: Dictionary = {
	"MI_1034501_Head":           "Head",
	"MI_1034501_Body_01":        "Body_01",
	"MI_1034501_Body_02":        "Body_02",
	"MI_1034001_Equip_05":       "Equip_04",  # no Equip_05 textures; reuse Equip_04
	"MI_1034501_Equip_04":       "Equip_04",
	"MI_1034501_Equip_03":       "Equip_03",
	"MI_1034501_Equip_02":       "Equip_02",
	"MI_1034501_Equip_01":       "Equip_01",
	"MI_1034501_FloatingGun_02": "Equip_01",  # weapon mount; reuse Equip_01
}
# "MI_Hide" is intentionally absent — hidden geo gets no material override.

const EMPTY_SLOT_COLOR:    Color = Color(0.25, 0.25, 0.28, 1.0)
const BODY_EMISSIVE_COLOR: Color = Color(0.08, 0.35, 0.55, 1.0)  # subtle blue — not a slot

# Auto-rotation
@export var auto_rotate_speed: float    = 0.3   # radians per second
@export var camera_distance:   float    = 2.8
@export var camera_height:     float    = 0.9

var _suit_root:      Node3D     = null
var _mesh_instances: Array      = []   # Array[MeshInstance3D]
var _materials:      Array      = []   # Array[Array[ShaderMaterial]] — per mesh, per surface
var _shader:         Shader     = null
var _is_loaded:      bool       = false
var _highlighted_surfaces: Dictionary = {}  # surface_material_key -> bool
var _auto_rotate:    bool       = true
var _drag_start_x:   float      = 0.0   # kept for InputEventMouseButton; orbit uses relative
var _is_dragging:    bool       = false
var _model_y_rotation:float     = 0.0


func _ready() -> void:
	_shader = load(SHADER_PATH)
	_load_suit()


func _process(delta: float) -> void:
	if _auto_rotate and not _is_dragging and _suit_root:
		_model_y_rotation += auto_rotate_speed * delta
		_suit_root.rotation.y = _model_y_rotation


# ── Public API ────────────────────────────────────────────────────────────────

## Set status emissive tint on all surfaces belonging to a suit slot.
## surface_indices: from SuitPartResource.mesh_surface_indices (meta)
## part: the SuitPartResource installed in this slot, or null for empty
func set_slot_status(surface_indices: Array, part: SuitPartResource) -> void:
	if not _is_loaded:
		return
	var is_empty := part == null
	var color: Color = EMPTY_SLOT_COLOR if is_empty else BODY_EMISSIVE_COLOR

	for mat in _get_mats_for_surfaces(surface_indices):
		mat.set_shader_parameter("emissive_tint", color)
		mat.set_shader_parameter("is_empty_slot", is_empty)


## Highlight surfaces for a selected slot — amber pulse.
func set_slot_highlighted(surface_indices: Array, highlighted: bool) -> void:
	if not _is_loaded:
		return
	for mat in _get_mats_for_surfaces(surface_indices):
		mat.set_shader_parameter("highlight_active", highlighted)


## Clear all highlights (called when selection changes).
func clear_all_highlights() -> void:
	for mi: MeshInstance3D in _mesh_instances:
		for i in mi.get_surface_override_material_count():
			var mat = mi.get_surface_override_material(i)
			if mat is ShaderMaterial:
				mat.set_shader_parameter("highlight_active", false)


# ── Input (mouse orbit) ───────────────────────────────────────────────────────

func handle_mouse_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if event.pressed:
				_drag_start_x = event.position.x
				_auto_rotate  = false
			else:
				_auto_rotate  = true  # resume after release
	elif event is InputEventMouseMotion and _is_dragging:
		var motion := event as InputEventMouseMotion
		_model_y_rotation += motion.relative.x * 0.01
		if _suit_root:
			_suit_root.rotation.y = _model_y_rotation


# ── Internal ──────────────────────────────────────────────────────────────────

func _load_suit() -> void:
	# GLTFDocument loads GLB at runtime without requiring an editor import pass.
	var doc   := GLTFDocument.new()
	var state := GLTFState.new()
	var path  := ProjectSettings.globalize_path(SUIT_SCENE_PATH)
	var err   := doc.append_from_file(path, state)
	if err != OK:
		push_error("[SuitViewer3D] Could not load suit model from: " + SUIT_SCENE_PATH)
		return

	_suit_root = doc.generate_scene(state)
	add_child(_suit_root)
	_suit_root.position = Vector3.ZERO

	_find_mesh_instances(_suit_root, _mesh_instances)
	_build_materials()
	_center_suit()
	_is_loaded = true


func _center_suit() -> void:
	var aabb := _combined_aabb()
	if aabb.size == Vector3.ZERO:
		return

	# Translate suit root so feet land at Y=0 and it's centered on X/Z.
	var c := aabb.get_center()
	_suit_root.position = Vector3(-c.x, -aabb.position.y, -c.z)

	# Camera: look at a point slightly above the suit's vertical center (head bias),
	# and pull back far enough for the full figure to fill ~75 % of frame height.
	var suit_height: float = aabb.size.y
	var look_y:      float = suit_height * 0.55
	var cam: Camera3D      = $Camera3D
	var half_fov:    float = deg_to_rad(cam.fov * 0.5)
	var dist:        float = (suit_height * 0.5) / (tan(half_fov) * 0.75)

	cam.position = Vector3(0.0, look_y, dist)
	cam.look_at(Vector3(0.0, look_y, 0.0), Vector3.UP)


func _combined_aabb() -> AABB:
	var combined := AABB()
	var first    := true
	for mi: MeshInstance3D in _mesh_instances:
		if mi.mesh == null:
			continue
		# Transform mesh AABB into suit_root's local space.
		var to_root: Transform3D = _suit_root.global_transform.affine_inverse() * mi.global_transform
		var a: AABB = to_root * mi.get_aabb()
		combined = a if first else combined.merge(a)
		first = false
	return combined


func _find_mesh_instances(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_mesh_instances(child, result)


func _build_materials() -> void:
	_materials.clear()
	for mi: MeshInstance3D in _mesh_instances:
		var mesh_mats: Array[ShaderMaterial] = []
		var surface_count: int = mi.get_surface_override_material_count()

		for i in surface_count:
			var surface_name: String = mi.mesh.surface_get_name(i) if mi.mesh else ""
			if surface_name.is_empty():
				# GLTFDocument may store name on the original material instead
				var orig := mi.mesh.surface_get_material(i)
				if orig:
					surface_name = orig.resource_name

			# Hidden geometry — leave the surface override unset
			if "Hide" in surface_name:
				mesh_mats.append(null)
				continue

			var tex_key: String = _resolve_tex_key_for_surface(surface_name)
			var mat := ShaderMaterial.new()
			mat.shader = _shader
			_apply_textures(mat, tex_key)

			if tex_key in ["Body_01", "Body_02"]:
				mat.set_shader_parameter("emissive_tint",     BODY_EMISSIVE_COLOR)
				mat.set_shader_parameter("emissive_strength", 0.6)
			else:
				mat.set_shader_parameter("emissive_tint",     EMPTY_SLOT_COLOR)
				mat.set_shader_parameter("is_empty_slot",     true)

			mi.set_surface_override_material(i, mat)
			mesh_mats.append(mat)

		_materials.append(mesh_mats)


func _resolve_tex_key_for_surface(surface_name: String) -> String:
	if SURFACE_NAME_MAP.has(surface_name):
		return SURFACE_NAME_MAP[surface_name]
	# Fallback: substring match against TEXTURE_SETS keys
	for key: String in TEXTURE_SETS.keys():
		if key.to_lower() in surface_name.to_lower():
			return key
	return TEXTURE_SETS.keys()[0]


func _apply_textures(mat: ShaderMaterial, tex_key: String) -> void:
	if not TEXTURE_SETS.has(tex_key):
		return
	var set: Dictionary = TEXTURE_SETS[tex_key]
	_load_tex(mat, "albedo_tex",   set.get("albedo",   ""))
	_load_tex(mat, "normal_tex",   set.get("normal",   ""))
	_load_tex(mat, "orm_tex",      set.get("orm",      ""))
	_load_tex(mat, "emissive_tex", set.get("emissive", ""))
	_load_tex(mat, "specular_tex", set.get("specular", ""))


func _load_tex(mat: ShaderMaterial, param: String, res_path: String) -> void:
	if res_path.is_empty():
		return
	# ResourceLoader.load() requires editor-generated .import files.
	# Read the PNG directly via Image so the editor never needs to run.
	var abs_path := ProjectSettings.globalize_path(res_path)
	var img := Image.load_from_file(abs_path)
	if img == null:
		push_warning("[SuitViewer3D] Texture not found: " + res_path)
		return
	mat.set_shader_parameter(param, ImageTexture.create_from_image(img))


func _get_mats_for_surfaces(surface_indices: Array) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	for mi: MeshInstance3D in _mesh_instances:
		for surf_idx: int in surface_indices:
			if surf_idx < mi.get_surface_override_material_count():
				var mat = mi.get_surface_override_material(surf_idx)
				if mat is ShaderMaterial:
					result.append(mat)
	return result
