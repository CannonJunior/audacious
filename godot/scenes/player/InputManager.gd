class_name InputManager
extends Node
## Reads Godot Input each physics frame and pushes SuitInputState to SuitBody.
## Sits before SuitBody in the Player scene tree so input is consumed before
## SuitBody._physics_process() runs in the same frame.
## Also handles debug preset hot-keys (F1 / F2 / F3).

const SuitPresets = preload("res://data/SuitPresets.gd")
const SuitInputState = preload("res://network/SuitInputState.gd")

@onready var _suit = $"../SuitBody"  # SuitBody

func _physics_process(_delta: float) -> void:
	# Debug preset switching — before building state so it takes effect this frame
	if Input.is_action_just_pressed("debug_preset_light"):
		_suit.set_configuration(SuitPresets.scout())
		print("[DEBUG] Preset: Scout  load=%.2f" % _suit.get_stats().load_ratio)
	elif Input.is_action_just_pressed("debug_preset_balanced"):
		_suit.set_configuration(SuitPresets.balanced())
		print("[DEBUG] Preset: Balanced  load=%.2f" % _suit.get_stats().load_ratio)
	elif Input.is_action_just_pressed("debug_preset_heavy"):
		_suit.set_configuration(SuitPresets.heavy())
		print("[DEBUG] Preset: Heavy  load=%.2f  flight=%s" % [
			_suit.get_stats().load_ratio,
			_suit.get_stats().flight_available,
		])

	var state := SuitInputState.new()

	# E+D together = roll right; Q+A together = roll left.
	# When a roll combo is active, suppress the individual strafe and turn inputs.
	var roll_right := Input.is_action_pressed("move_right") and Input.is_action_pressed("turn_right")
	var roll_left  := Input.is_action_pressed("move_left")  and Input.is_action_pressed("turn_left")

	if roll_right or roll_left:
		state.roll_delta = 1.0 if roll_right else -1.0
		state.move_direction = Vector2(
			0.0,
			Input.get_axis("move_forward", "move_back"),
		)
	else:
		# W/S = forward/back; Q/E = strafe; A/D = turn
		state.move_direction = Vector2(
			-Input.get_axis("move_left", "move_right"),  # Q/E strafe (negate: engine axis is flipped)
			Input.get_axis("move_forward", "move_back"),
		)
		state.turn_delta = -Input.get_axis("turn_left", "turn_right")

	state.land_pressed = Input.is_action_just_pressed("force_land")

	# Boost (Space): pressed = jump/burst, held = sustain flight
	state.boost_pressed  = Input.is_action_just_pressed("boost")
	state.boost_held     = Input.is_action_pressed("boost")
	state.boost_down_held = Input.is_action_pressed("boost_down")
	state.sprint_held    = Input.is_action_pressed("sprint")

	# Combat (Phase 5+, stubs for now so the struct is complete)
	state.fire_primary_pressed  = Input.is_action_just_pressed("fire_primary")
	state.fire_primary_held     = Input.is_action_pressed("fire_primary")
	state.fire_secondary_pressed = Input.is_action_just_pressed("fire_secondary")
	state.lock_on_pressed       = Input.is_action_just_pressed("lock_on")
	state.melee_pressed         = Input.is_action_just_pressed("melee")

	for i: int in range(1, 5):
		if Input.is_action_just_pressed("suit_ability_%d" % i):
			state.ability_slot = i
			break

	_suit.apply_input(state)
