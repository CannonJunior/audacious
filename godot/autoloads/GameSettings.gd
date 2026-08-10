extends Node
## Persistent user preferences. Saved to user://settings.cfg.

# ── Display ───────────────────────────────────────────────────────────────────

var fullscreen: bool = false

# ── Audio ─────────────────────────────────────────────────────────────────────

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.7
var agent_voice_volume: float = 1.0

# ── Controls ──────────────────────────────────────────────────────────────────

var mouse_sensitivity: float = 0.3
var controller_sensitivity: float = 0.5
var invert_y: bool = false

# ── Gameplay ──────────────────────────────────────────────────────────────────

## Default autonomy level for AI agent planning (AIAgent.AutonomyLevel int).
var default_agent_autonomy: int = 0   # 0 = GUIDED

## Whether the thermal indicator is always shown or only on approach.
var always_show_thermal: bool = false

# ── Development toggles (stripped in release builds) ─────────────────────────

var dev_show_chunk_bounds: bool = false
var dev_show_thermal_map: bool = false
var dev_infinite_boost: bool = false

const _SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
	_load()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "agent_voice_volume", agent_voice_volume)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "controller_sensitivity", controller_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("gameplay", "default_agent_autonomy", default_agent_autonomy)
	cfg.set_value("gameplay", "always_show_thermal", always_show_thermal)
	cfg.save(_SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", false)
	master_volume = cfg.get_value("audio", "master_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	music_volume = cfg.get_value("audio", "music_volume", 0.7)
	agent_voice_volume = cfg.get_value("audio", "agent_voice_volume", 1.0)
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", 0.3)
	controller_sensitivity = cfg.get_value("controls", "controller_sensitivity", 0.5)
	invert_y = cfg.get_value("controls", "invert_y", false)
	default_agent_autonomy = cfg.get_value("gameplay", "default_agent_autonomy", 0)
	always_show_thermal = cfg.get_value("gameplay", "always_show_thermal", false)
