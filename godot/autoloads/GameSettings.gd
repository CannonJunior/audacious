extends Node
## Persistent user preferences. Saved to user://settings.cfg.
## Call apply_all() after changing values to push them to the engine.

signal settings_applied

# ── Display ───────────────────────────────────────────────────────────────────

## 0 = Windowed  1 = Borderless Fullscreen  2 = Exclusive Fullscreen
var window_mode: int   = 0
## 0 = Disabled  1 = Enabled  2 = Adaptive
var vsync_mode:  int   = 1
## 0 = Unlimited  else = exact cap in Hz
var fps_cap:     int   = 0
## 0.5–1.0 multiplied against native resolution
var render_scale: float = 1.0

# ── Graphics ──────────────────────────────────────────────────────────────────

## 0 = Off  1 = 2×  2 = 4×  3 = 8×
var msaa:              int   = 0
## 0 = Low  1 = Medium  2 = High  3 = Ultra
var shadow_quality:    int   = 2
var ambient_occlusion: bool  = true
## 0.0 = off
var motion_blur:       float = 0.0
var depth_of_field:    bool  = false

# ── Audio ─────────────────────────────────────────────────────────────────────

var master_volume:       float = 1.0
var sfx_volume:          float = 1.0
var music_volume:        float = 0.7
var agent_voice_volume:  float = 1.0
var suit_ambient_volume: float = 0.8
var spatial_audio:       bool  = true

# ── Controls ──────────────────────────────────────────────────────────────────

var mouse_sensitivity:       float = 0.3
var vertical_sensitivity:    float = 1.0   # multiplier on top of mouse_sensitivity
var invert_y:                bool  = false
var aim_sensitivity:         float = 0.5
var controller_sensitivity:  float = 0.5
var controller_vibration:    bool  = true
var toggle_sprint:           bool  = false
var toggle_hover:            bool  = false
## Base field of view in degrees; CameraRig lerps from this during speed bursts.
var camera_fov:              float = 75.0

# ── Gameplay ──────────────────────────────────────────────────────────────────

## 0 = Scout  1 = Operative  2 = Ghost  3 = Phantom
var difficulty:          int   = 1
## 0 = Off  1 = Low  2 = High
var aim_assist:          int   = 1
var auto_pickup_loot:    bool  = false
## true = hold to interact, false = tap
var loot_interact_hold:  bool  = true
var show_damage_numbers: bool  = true
var subtitles:           bool  = true
## 0 = Small  1 = Medium  2 = Large
var subtitle_size:       int   = 1
## AIAgent.AutonomyLevel int: 0 = GUIDED
var default_agent_autonomy: int = 0

# ── HUD ───────────────────────────────────────────────────────────────────────

var hud_scale:                 float = 1.0
var show_minimap:              bool  = true
var show_compass:              bool  = true
var show_damage_indicator:     bool  = true
var always_show_thermal:       bool  = false
var thermal_warning_threshold: float = 0.7
## Suit instrument broadcast rate in Hz: 5.0 / 10.0 / 20.0
var suit_readout_hz:           float = 20.0

# ── Accessibility ─────────────────────────────────────────────────────────────

## 0 = Off  1 = Deuteranopia  2 = Protanopia  3 = Tritanopia
var colorblind_mode:   int   = 0
var high_contrast_hud: bool  = false
## 0.0 = no shake  1.0 = full shake
var camera_shake:      float = 1.0
var screen_flash:      bool  = true
## 0 = Small  1 = Medium  2 = Large
var font_size:         int   = 1

# ── Developer (stripped in release) ──────────────────────────────────────────

var dev_show_chunk_bounds: bool = false
var dev_show_thermal_map:  bool = false
var dev_infinite_boost:    bool = false

# ─────────────────────────────────────────────────────────────────────────────

const _SAVE_PATH := "user://settings.cfg"

func _ready() -> void:
	_load()
	apply_all()


func apply_all() -> void:
	apply_display()
	apply_graphics()
	apply_audio()
	settings_applied.emit()


func apply_display() -> void:
	match window_mode:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	match vsync_mode:
		0: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		1: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		2: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
	Engine.max_fps = fps_cap


func apply_graphics() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match msaa:
		0: vp.msaa_3d = Viewport.MSAA_DISABLED
		1: vp.msaa_3d = Viewport.MSAA_2X
		2: vp.msaa_3d = Viewport.MSAA_4X
		3: vp.msaa_3d = Viewport.MSAA_8X


func apply_audio() -> void:
	_set_bus("Master",      master_volume)
	_set_bus("SFX",         sfx_volume)
	_set_bus("Music",       music_volume)
	_set_bus("AgentVoice",  agent_voice_volume)
	_set_bus("SuitAmbient", suit_ambient_volume)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display",       "window_mode",              window_mode)
	cfg.set_value("display",       "vsync_mode",               vsync_mode)
	cfg.set_value("display",       "fps_cap",                  fps_cap)
	cfg.set_value("display",       "render_scale",             render_scale)
	cfg.set_value("graphics",      "msaa",                     msaa)
	cfg.set_value("graphics",      "shadow_quality",           shadow_quality)
	cfg.set_value("graphics",      "ambient_occlusion",        ambient_occlusion)
	cfg.set_value("graphics",      "motion_blur",              motion_blur)
	cfg.set_value("graphics",      "depth_of_field",           depth_of_field)
	cfg.set_value("audio",         "master_volume",            master_volume)
	cfg.set_value("audio",         "sfx_volume",               sfx_volume)
	cfg.set_value("audio",         "music_volume",             music_volume)
	cfg.set_value("audio",         "agent_voice_volume",       agent_voice_volume)
	cfg.set_value("audio",         "suit_ambient_volume",      suit_ambient_volume)
	cfg.set_value("audio",         "spatial_audio",            spatial_audio)
	cfg.set_value("controls",      "mouse_sensitivity",        mouse_sensitivity)
	cfg.set_value("controls",      "vertical_sensitivity",     vertical_sensitivity)
	cfg.set_value("controls",      "invert_y",                 invert_y)
	cfg.set_value("controls",      "aim_sensitivity",          aim_sensitivity)
	cfg.set_value("controls",      "controller_sensitivity",   controller_sensitivity)
	cfg.set_value("controls",      "controller_vibration",     controller_vibration)
	cfg.set_value("controls",      "toggle_sprint",            toggle_sprint)
	cfg.set_value("controls",      "toggle_hover",             toggle_hover)
	cfg.set_value("controls",      "camera_fov",               camera_fov)
	cfg.set_value("gameplay",      "difficulty",               difficulty)
	cfg.set_value("gameplay",      "aim_assist",               aim_assist)
	cfg.set_value("gameplay",      "auto_pickup_loot",         auto_pickup_loot)
	cfg.set_value("gameplay",      "loot_interact_hold",       loot_interact_hold)
	cfg.set_value("gameplay",      "show_damage_numbers",      show_damage_numbers)
	cfg.set_value("gameplay",      "subtitles",                subtitles)
	cfg.set_value("gameplay",      "subtitle_size",            subtitle_size)
	cfg.set_value("gameplay",      "default_agent_autonomy",   default_agent_autonomy)
	cfg.set_value("hud",           "hud_scale",                hud_scale)
	cfg.set_value("hud",           "show_minimap",             show_minimap)
	cfg.set_value("hud",           "show_compass",             show_compass)
	cfg.set_value("hud",           "show_damage_indicator",    show_damage_indicator)
	cfg.set_value("hud",           "always_show_thermal",      always_show_thermal)
	cfg.set_value("hud",           "thermal_warning_threshold",thermal_warning_threshold)
	cfg.set_value("hud",           "suit_readout_hz",          suit_readout_hz)
	cfg.set_value("accessibility", "colorblind_mode",          colorblind_mode)
	cfg.set_value("accessibility", "high_contrast_hud",        high_contrast_hud)
	cfg.set_value("accessibility", "camera_shake",             camera_shake)
	cfg.set_value("accessibility", "screen_flash",             screen_flash)
	cfg.set_value("accessibility", "font_size",                font_size)
	cfg.save(_SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	window_mode              = cfg.get_value("display",       "window_mode",              window_mode)
	vsync_mode               = cfg.get_value("display",       "vsync_mode",               vsync_mode)
	fps_cap                  = cfg.get_value("display",       "fps_cap",                  fps_cap)
	render_scale             = cfg.get_value("display",       "render_scale",             render_scale)
	msaa                     = cfg.get_value("graphics",      "msaa",                     msaa)
	shadow_quality           = cfg.get_value("graphics",      "shadow_quality",           shadow_quality)
	ambient_occlusion        = cfg.get_value("graphics",      "ambient_occlusion",        ambient_occlusion)
	motion_blur              = cfg.get_value("graphics",      "motion_blur",              motion_blur)
	depth_of_field           = cfg.get_value("graphics",      "depth_of_field",           depth_of_field)
	master_volume            = cfg.get_value("audio",         "master_volume",            master_volume)
	sfx_volume               = cfg.get_value("audio",         "sfx_volume",               sfx_volume)
	music_volume             = cfg.get_value("audio",         "music_volume",             music_volume)
	agent_voice_volume       = cfg.get_value("audio",         "agent_voice_volume",       agent_voice_volume)
	suit_ambient_volume      = cfg.get_value("audio",         "suit_ambient_volume",      suit_ambient_volume)
	spatial_audio            = cfg.get_value("audio",         "spatial_audio",            spatial_audio)
	mouse_sensitivity        = cfg.get_value("controls",      "mouse_sensitivity",        mouse_sensitivity)
	vertical_sensitivity     = cfg.get_value("controls",      "vertical_sensitivity",     vertical_sensitivity)
	invert_y                 = cfg.get_value("controls",      "invert_y",                 invert_y)
	aim_sensitivity          = cfg.get_value("controls",      "aim_sensitivity",          aim_sensitivity)
	controller_sensitivity   = cfg.get_value("controls",      "controller_sensitivity",   controller_sensitivity)
	controller_vibration     = cfg.get_value("controls",      "controller_vibration",     controller_vibration)
	toggle_sprint            = cfg.get_value("controls",      "toggle_sprint",            toggle_sprint)
	toggle_hover             = cfg.get_value("controls",      "toggle_hover",             toggle_hover)
	camera_fov               = cfg.get_value("controls",      "camera_fov",               camera_fov)
	difficulty               = cfg.get_value("gameplay",      "difficulty",               difficulty)
	aim_assist               = cfg.get_value("gameplay",      "aim_assist",               aim_assist)
	auto_pickup_loot         = cfg.get_value("gameplay",      "auto_pickup_loot",         auto_pickup_loot)
	loot_interact_hold       = cfg.get_value("gameplay",      "loot_interact_hold",       loot_interact_hold)
	show_damage_numbers      = cfg.get_value("gameplay",      "show_damage_numbers",      show_damage_numbers)
	subtitles                = cfg.get_value("gameplay",      "subtitles",                subtitles)
	subtitle_size            = cfg.get_value("gameplay",      "subtitle_size",            subtitle_size)
	default_agent_autonomy   = cfg.get_value("gameplay",      "default_agent_autonomy",   default_agent_autonomy)
	hud_scale                = cfg.get_value("hud",           "hud_scale",                hud_scale)
	show_minimap             = cfg.get_value("hud",           "show_minimap",             show_minimap)
	show_compass             = cfg.get_value("hud",           "show_compass",             show_compass)
	show_damage_indicator    = cfg.get_value("hud",           "show_damage_indicator",    show_damage_indicator)
	always_show_thermal      = cfg.get_value("hud",           "always_show_thermal",      always_show_thermal)
	thermal_warning_threshold= cfg.get_value("hud",           "thermal_warning_threshold",thermal_warning_threshold)
	suit_readout_hz          = cfg.get_value("hud",           "suit_readout_hz",          suit_readout_hz)
	colorblind_mode          = cfg.get_value("accessibility", "colorblind_mode",          colorblind_mode)
	high_contrast_hud        = cfg.get_value("accessibility", "high_contrast_hud",        high_contrast_hud)
	camera_shake             = cfg.get_value("accessibility", "camera_shake",             camera_shake)
	screen_flash             = cfg.get_value("accessibility", "screen_flash",             screen_flash)
	font_size                = cfg.get_value("accessibility", "font_size",                font_size)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
