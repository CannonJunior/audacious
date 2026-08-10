class_name TestLevel
extends Node3D

func _ready() -> void:
	_setup_environment()
	_build_geometry()

func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.1, 0.4, 0.8)
	mat.sky_horizon_color = Color(0.6, 0.8, 1.0)
	mat.ground_horizon_color = Color(0.4, 0.3, 0.2)
	sky.sky_material = mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _build_geometry() -> void:
	# Ground
	_add_platform(Vector3(0, 0, 0), Vector3(200, 1, 200), Color(0.3, 0.3, 0.3))

	# Low platform — reachable by a single jump (~10 m)
	_add_platform(Vector3(20, 10, -10), Vector3(8, 1, 8), Color(0.2, 0.5, 0.2))

	# Mid platform — needs a boost-assisted jump or short flight
	_add_platform(Vector3(-20, 18, -15), Vector3(8, 1, 8), Color(0.5, 0.4, 0.1))

	# High platform — flight required for heavy/balanced, easy for scout
	_add_platform(Vector3(0, 35, -30), Vector3(10, 1, 10), Color(0.2, 0.2, 0.6))

	# Very high platform — stress-tests flight ceiling for balanced suit
	_add_platform(Vector3(30, 60, -20), Vector3(8, 1, 8), Color(0.6, 0.1, 0.1))

	# Wide gap platform — cross requires horizontal boost sprint
	_add_platform(Vector3(-40, 2, 0), Vector3(10, 1, 10), Color(0.4, 0.2, 0.5))
	_add_platform(Vector3(-70, 2, 0), Vector3(10, 1, 10), Color(0.4, 0.2, 0.5))

	# Ramp — tests slope traversal and launch angle
	_add_ramp(Vector3(10, 0, 20), Vector3(6, 4, 12), -20.0, Color(0.45, 0.35, 0.25))

	# Tall wall — tests bumper assist when flying straight at it
	_add_platform(Vector3(0, 15, -60), Vector3(30, 30, 2), Color(0.5, 0.5, 0.55))

	# Narrow canyon walls — forces bumper to steer the suit through
	_add_platform(Vector3(-5, 10, 40), Vector3(2, 20, 40), Color(0.55, 0.5, 0.5))
	_add_platform(Vector3(5, 10, 40), Vector3(2, 20, 40), Color(0.55, 0.5, 0.5))

func _add_platform(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	mesh_inst.mesh = mesh
	mesh_inst.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mesh_inst)

	add_child(body)

func _add_ramp(pos: Vector3, size: Vector3, pitch_deg: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.x = pitch_deg

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.surface_set_material(0, mat)
	mesh_inst.mesh = mesh
	mesh_inst.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mesh_inst)

	add_child(body)
