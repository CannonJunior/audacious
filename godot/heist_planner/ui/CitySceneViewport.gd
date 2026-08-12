class_name CitySceneViewport
extends SubViewportContainer
## Hosts the 3D city geometry viewer inside the Route Planner. Placeholder
## until actual city geometry is authored. Exposes camera orbit controls and
## a method to drop marker nodes at route node positions.

const PLACEHOLDER_BG: Color = Color(0.051, 0.102, 0.180, 1.0)

@onready var _viewport:     SubViewport = %CityViewport
@onready var _camera:       Camera3D    = %CityCamera
@onready var _markers_root: Node3D      = %MarkersRoot
@onready var _placeholder:  Label       = %PlaceholderLabel

var _orbit_angles: Vector2 = Vector2(deg_to_rad(-25.0), 0.0)
var _orbit_distance: float = 40.0
var _drag_active: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _has_geometry: bool = false

# ── Public ────────────────────────────────────────────────────────────────────

func clear_markers() -> void:
	for child in _markers_root.get_children():
		child.queue_free()

func add_marker(position_3d: Vector3, label: String, color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mesh_inst.mesh = sphere
	mesh_inst.position = position_3d

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy = 0.6
	mesh_inst.material_override = mat
	_markers_root.add_child(mesh_inst)

## Call when real geometry is loaded into the viewport via register_geometry().
func set_geometry_loaded(loaded: bool) -> void:
	_has_geometry = loaded
	_placeholder.visible = not loaded

# ── Camera orbit ──────────────────────────────────────────────────────────────

func _update_camera() -> void:
	var x := sin(_orbit_angles.y) * cos(_orbit_angles.x) * _orbit_distance
	var y := sin(_orbit_angles.x) * _orbit_distance
	var z := cos(_orbit_angles.y) * cos(_orbit_angles.x) * _orbit_distance
	_camera.position = Vector3(x, y, z)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

# ── Input ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag_active = mb.pressed
			_drag_start = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_distance = maxf(5.0, _orbit_distance - 3.0)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_distance = minf(150.0, _orbit_distance + 3.0)
			_update_camera()
	elif event is InputEventMouseMotion:
		if _drag_active:
			var motion := event as InputEventMouseMotion
			var delta := motion.position - _drag_start
			_drag_start = motion.position
			_orbit_angles.y -= delta.x * 0.005
			_orbit_angles.x = clampf(_orbit_angles.x - delta.y * 0.005,
				deg_to_rad(-80.0), deg_to_rad(-5.0))
			_update_camera()

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_viewport.use_own_world_3d = true
	_update_camera()

	# Minimal placeholder environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = PLACEHOLDER_BG
	_viewport.world_3d.environment = env

	_placeholder.visible = not _has_geometry
	_placeholder.text = "City geometry pending.\nRoute markers visible once geometry is authored."
