extends Node3D

const SUIT_SCENE_PATH := "res://assets/suit/iron_man.glb"

func _ready() -> void:
	var doc   := GLTFDocument.new()
	var state := GLTFState.new()
	var path  := ProjectSettings.globalize_path(SUIT_SCENE_PATH)
	var err   := doc.append_from_file(path, state)
	if err != OK:
		push_error("[SuitModelVisuals] Could not load suit model: " + SUIT_SCENE_PATH)
		return

	var suit_root := doc.generate_scene(state)
	add_child(suit_root)

	# Hide the capsule placeholder now that the real model is loaded
	var placeholder := get_parent().get_node_or_null("Visuals")
	if placeholder:
		placeholder.visible = false
