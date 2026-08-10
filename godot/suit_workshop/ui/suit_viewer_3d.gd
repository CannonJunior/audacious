## SuitViewer3D — manages the 3D suit display inside the workshop SubViewport.
## Attach to the root Node3D of the suit's 3D sub-scene.
##
## Surface mapping (mesh_surface_indices on SuitPartResource) must be filled in
## after importing the FBX in the Godot editor:
##   1. Open the imported FBX scene.
##   2. Select the MeshInstance3D.
##   3. In the Inspector → Mesh → Surfaces, note which surface index corresponds
##      to each body region (body, legs, chest, arms, head, etc.).
##   4. Add mesh_surface_indices: Array[int] to SuitPartResource and set per .tres.
class_name SuitViewer3D
extends Node3D

const SUIT_SCENE_PATH := "res://assets/suit/Iron Man 2.fbx"
const SHADER_PATH     := "res://suit_workshop/shaders/suit_surface.gdshader"

const TEXTURE_SETS: Dictionary = {
	# surface_name_hint -> { albedo, normal, orm, emissive, specular }
	# These are matched against mesh surface names after import.
	# Fallback: applied by surface index order if names don't match.
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
		"emissive": "res://assets/suit/textures/T_1034501_Equip_01_S.png",  # use S as fallback
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
var _drag_start_x:   float      = 0.0
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
		var delta_x := event.position.x - _drag_start_x
		_model_y_rotation += delta_x * 0.01
		if _suit_root:
			_suit_root.rotation.y = _model_y_rotation
		_drag_start_x = event.position.x


# ── Internal ──────────────────────────────────────────────────────────────────

func _load_suit() -> void:
	var packed: PackedScene = load(SUIT_SCENE_PATH)
	if packed == null:
		push_error("[SuitViewer3D] Could not load suit model from: " + SUIT_SCENE_PATH)
		return

	_suit_root = packed.instantiate()
	add_child(_suit_root)

	# Centre the model
	_suit_root.position = Vector3.ZERO

	# Collect all MeshInstance3D nodes
	_find_mesh_instances(_suit_root, _mesh_instances)

	# Create and apply shader materials
	_build_materials()
	_is_loaded = true


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

		# Determine which texture set to use based on mesh / surface name.
		# Falls back to sequential assignment if names don't match.
		var tex_key: String = _resolve_texture_key(mi)

		for i in surface_count:
			var mat := ShaderMaterial.new()
			mat.shader = _shader
			_apply_textures(mat, tex_key)

			# Structural body surfaces use a fixed subtle colour
			if tex_key in ["Body_01", "Body_02"]:
				mat.set_shader_parameter("emissive_tint",     BODY_EMISSIVE_COLOR)
				mat.set_shader_parameter("emissive_strength", 0.6)
			else:
				mat.set_shader_parameter("emissive_tint",     EMPTY_SLOT_COLOR)
				mat.set_shader_parameter("is_empty_slot",     true)

			mi.set_surface_override_material(i, mat)
			mesh_mats.append(mat)

		_materials.append(mesh_mats)


func _resolve_texture_key(mi: MeshInstance3D) -> String:
	# Try to match the node name or mesh name to a known texture set.
	for key in TEXTURE_SETS.keys():
		if key.to_lower() in mi.name.to_lower():
			return key
		if mi.mesh and key.to_lower() in mi.mesh.resource_name.to_lower():
			return key
	# Default: first texture set
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


func _load_tex(mat: ShaderMaterial, param: String, path: String) -> void:
	if path.is_empty():
		return
	var tex: Texture2D = load(path)
	if tex:
		mat.set_shader_parameter(param, tex)
	else:
		push_warning("[SuitViewer3D] Texture not found: " + path)


func _get_mats_for_surfaces(surface_indices: Array) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	for mi_idx in _mesh_instances.size():
		var mi: MeshInstance3D = _mesh_instances[mi_idx]
		for surf_idx in surface_indices:
			if surf_idx < mi.get_surface_override_material_count():
				var mat = mi.get_surface_override_material(surf_idx)
				if mat is ShaderMaterial:
					result.append(mat)
	return result
