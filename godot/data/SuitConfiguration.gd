class_name SuitConfiguration
extends Resource
## The player's current suit loadout. Holds one SuitPartResource per slot.
## Call get_stats() to obtain computed SuitStats; stats are cached and
## invalidated automatically when parts change.

const SuitStats = preload("res://data/SuitStats.gd")
const SuitPartResource = preload("res://data/SuitPartResource.gd")

@export var preset_id: StringName   # used by GameRegistry for named presets
@export var display_name: String

## Slot → SuitPartResource. Key is SuitPartResource.Slot (int).
@export var equipped_parts: Dictionary = {}

# ── Color customization ───────────────────────────────────────────────────────

@export var color_primary: Color   = Color(0.15, 0.60, 0.90)
@export var color_secondary: Color = Color(0.12, 0.12, 0.14)
@export var color_accent: Color    = Color(0.00, 0.90, 0.80)

func set_colors(primary: Color, secondary: Color, accent: Color) -> void:
	color_primary   = primary
	color_secondary = secondary
	color_accent    = accent
	EventBus.configuration_changed.emit(self)

# ── Internal ──────────────────────────────────────────────────────────────────

var _cached_stats: SuitStats = null

# ── Part management ───────────────────────────────────────────────────────────

func equip(slot: SuitPartResource.Slot, part: SuitPartResource) -> void:
	equipped_parts[slot] = part
	_cached_stats = null
	EventBus.part_equipped.emit(slot, part)
	EventBus.configuration_changed.emit(self)

func unequip(slot: SuitPartResource.Slot) -> void:
	equipped_parts.erase(slot)
	_cached_stats = null
	EventBus.part_unequipped.emit(slot)
	EventBus.configuration_changed.emit(self)

func get_part(slot: SuitPartResource.Slot) -> SuitPartResource:
	return equipped_parts.get(slot as int)

func has_part(slot: SuitPartResource.Slot) -> bool:
	return (slot as int) in equipped_parts

# ── Stats aggregation ─────────────────────────────────────────────────────────

func get_stats() -> SuitStats:
	if _cached_stats == null:
		_cached_stats = _compute_stats()
	return _cached_stats

func _compute_stats() -> SuitStats:
	var stats := SuitStats.new()

	var chassis := get_part(SuitPartResource.Slot.CHASSIS)
	var thrusters := get_part(SuitPartResource.Slot.THRUSTER_PACK)
	var actuators := get_part(SuitPartResource.Slot.ACTUATOR_SUITE)

	var capacity := chassis.systems_capacity if chassis else 1.0
	var total_load := 0.0
	for part: SuitPartResource in equipped_parts.values():
		total_load += part.systems_load

	stats.load_ratio = total_load / capacity if capacity > 0.0 else INF
	stats.is_overloaded = stats.load_ratio > 1.0

	# Clamp t to [0,1] for curve evaluation; overloaded suits use t=1.0
	var t := clampf(stats.load_ratio, 0.0, 1.0)

	var tf := thrusters.thrust_factor if thrusters else 1.0
	var af := actuators.actuator_factor if actuators else 1.0

	stats.boost_speed = lerp(SuitStats.MAX_BOOST_SPEED, SuitStats.MIN_BOOST_SPEED, t) * tf
	# MAX_HOVER_DURATION is INF; lerp(INF, 0, t) produces NaN — branch instead
	if t <= 0.0:
		stats.hover_duration = INF
	else:
		stats.hover_duration = lerp(60.0, 0.0, t) * tf
	stats.ground_sprint_speed = lerp(SuitStats.MAX_GROUND_SPEED, SuitStats.MIN_GROUND_SPEED, t) * af
	stats.jump_height = lerp(SuitStats.MAX_JUMP_HEIGHT, SuitStats.MIN_JUMP_HEIGHT, t) * af

	# Flight ceiling drops steeply after 0.4 load — meaningful cliff where weapons start
	if t < 0.4:
		stats.max_flight_altitude = INF
		stats.flight_available = true
	elif t < 1.0:
		var remap_t := (t - 0.4) / 0.6
		stats.max_flight_altitude = lerp(500.0, 50.0, remap_t)
		stats.flight_available = true
	else:
		stats.max_flight_altitude = 0.0
		stats.flight_available = false

	# Armor: additive sum across all parts
	for part: SuitPartResource in equipped_parts.values():
		stats.armor_points += part.armor_points
		stats.damage_bonus += part.damage_bonus

	# Thermal output: load_ratio × chassis thermal coefficient
	var thermal_coeff := chassis.thermal_coefficient if chassis else 1.0
	stats.thermal_output = stats.load_ratio * thermal_coeff

	return stats
