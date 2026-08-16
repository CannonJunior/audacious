class_name Player
extends Node3D
## Root of the player scene. Exposes player_id for multiplayer identification.
## In network mode, disables camera and HUD on remote instances so only the
## local player's camera and HUD are active.

var player_id: String = "player_1"

func _ready() -> void:
	if NetworkManager.mode == NetworkManager.NetMode.OFFLINE:
		return
	var is_local := player_id == NetworkManager.local_player_id
	for cam: Camera3D in find_children("*", "Camera3D", true, false):
		cam.current = is_local
	for hud: CanvasLayer in find_children("*", "CanvasLayer", true, false):
		hud.visible = is_local
