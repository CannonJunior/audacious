class_name TestLevel
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")

func _ready() -> void:
	_setup_environment()
	_build_geometry()
	_register_scene_items()
	_setup_multiplayer()

func _setup_multiplayer() -> void:
	if NetworkManager.mode == NetworkManager.NetMode.OFFLINE:
		return
	EventBus.peer_connected.connect(_on_peer_connected)
	if NetworkManager.is_server():
		# Spawn players for any peers that connected during the lobby phase.
		for peer_id: int in multiplayer.get_peers():
			var pid := NetworkManager.get_player_id_for_peer(peer_id)
			if not pid.is_empty():
				spawn_player.rpc(pid, Vector3(randf_range(-4.0, 4.0), 2.0, randf_range(-4.0, 4.0)))

func _physics_process(_delta: float) -> void:
	if NetworkManager.is_server() and NetworkManager.mode != NetworkManager.NetMode.OFFLINE:
		NetworkManager.apply_buffered_inputs(self)

## NetworkManager.apply_buffered_inputs() calls this to route input to the right SuitBody.
func get_suit_node(player_id: String) -> Node:
	for child in get_children():
		if child.get("player_id") == player_id:
			return child.get_node_or_null("SuitBody")
	return null

func _on_peer_connected(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	var player_id := NetworkManager.get_player_id_for_peer(peer_id)
	if not player_id.is_empty():
		spawn_player.rpc(player_id, Vector3(randf_range(-4.0, 4.0), 2.0, randf_range(-4.0, 4.0)))

## Server calls this (call_local) to synchronize player node creation across all peers.
@rpc("authority", "call_local", "reliable")
func spawn_player(player_id: String, pos: Vector3) -> void:
	if get_node_or_null(player_id):
		return
	var player := PLAYER_SCENE.instantiate() as Node3D
	player.name = player_id
	player.set("player_id", player_id)
	player.position = pos
	add_child(player)

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
	_add_platform("Ground",           Vector3(0, 0, 0),     Vector3(200, 1, 200), Color(0.3, 0.3, 0.3))
	_add_platform("Low Platform",     Vector3(20, 10, -10), Vector3(8, 1, 8),     Color(0.2, 0.5, 0.2))
	_add_platform("Mid Platform",     Vector3(-20, 18, -15),Vector3(8, 1, 8),     Color(0.5, 0.4, 0.1))
	_add_platform("High Platform",    Vector3(0, 35, -30),  Vector3(10, 1, 10),   Color(0.2, 0.2, 0.6))
	_add_platform("Very High",        Vector3(30, 60, -20), Vector3(8, 1, 8),     Color(0.6, 0.1, 0.1))
	_add_platform("Gap Platform A",   Vector3(-40, 2, 0),   Vector3(10, 1, 10),   Color(0.4, 0.2, 0.5))
	_add_platform("Gap Platform B",   Vector3(-70, 2, 0),   Vector3(10, 1, 10),   Color(0.4, 0.2, 0.5))
	_add_ramp(    "Ramp",             Vector3(10, 0, 20),   Vector3(6, 4, 12),    -20.0, Color(0.45, 0.35, 0.25))
	_add_platform("Tall Wall",        Vector3(0, 15, -60),  Vector3(30, 30, 2),   Color(0.5, 0.5, 0.55))
	_add_platform("Canyon Wall L",    Vector3(-5, 10, 40),  Vector3(2, 20, 40),   Color(0.55, 0.5, 0.5))
	_add_platform("Canyon Wall R",    Vector3(5, 10, 40),   Vector3(2, 20, 40),   Color(0.55, 0.5, 0.5))

func _register_scene_items() -> void:
	WebViewBridge.clear_items()
	for child in get_children():
		if child is Node3D:
			var p: Vector3 = (child as Node3D).global_position
			WebViewBridge.register_item(child.name, {
				"type": child.get_class(),
				"pos":  "%d, %d, %d" % [roundi(p.x), roundi(p.y), roundi(p.z)]
			}, child)
	WebViewBridge.push_items()

func _add_platform(obj_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name     = obj_name
	body.position = pos

	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size    = size
	col.shape     = shape
	col.position  = Vector3(0, size.y * 0.5, 0)
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh      := BoxMesh.new()
	mesh.size     = size
	var mat       := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.9
	mesh.surface_set_material(0, mat)
	mesh_inst.mesh     = mesh
	mesh_inst.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mesh_inst)

	add_child(body)

func _add_ramp(obj_name: String, pos: Vector3, size: Vector3, pitch_deg: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name              = obj_name
	body.position          = pos
	body.rotation_degrees.x = pitch_deg

	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size   = size
	col.shape    = shape
	col.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh      := BoxMesh.new()
	mesh.size     = size
	var mat       := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.85
	mesh.surface_set_material(0, mat)
	mesh_inst.mesh     = mesh
	mesh_inst.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mesh_inst)

	add_child(body)
