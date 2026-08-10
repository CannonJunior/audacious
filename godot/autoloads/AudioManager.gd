extends Node
## Audio bus management and convenience playback helpers.
## Wires GameSettings volume sliders to AudioServer buses.

const BUS_MASTER  := "Master"
const BUS_SFX     := "SFX"
const BUS_MUSIC   := "Music"
const BUS_AGENT   := "AgentVoice"

func _ready() -> void:
	_apply_volumes()
	EventBus.game_mode_changed.connect(_on_game_mode_changed)

func _apply_volumes() -> void:
	_set_bus_volume(BUS_MASTER, GameSettings.master_volume)
	_set_bus_volume(BUS_SFX, GameSettings.sfx_volume)
	_set_bus_volume(BUS_MUSIC, GameSettings.music_volume)
	_set_bus_volume(BUS_AGENT, GameSettings.agent_voice_volume)

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _on_game_mode_changed(_mode: StringName) -> void:
	pass  # Placeholder: switch music tracks per mode
