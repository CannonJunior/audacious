class_name SuitPresets
## Hardcoded in-code presets for Phase 0 testing.
## Replace with authored .tres files in Phase 1 when GarageUI is built.
## Toggled via F1 / F2 / F3 in the test level.

const SuitConfiguration = preload("res://data/SuitConfiguration.gd")
const SuitPartResource = preload("res://data/SuitPartResource.gd")

static func scout() -> SuitConfiguration:
	var config := SuitConfiguration.new()
	config.preset_id = &"scout"
	config.display_name = "Scout"
	config.color_primary   = Color(0.15, 0.60, 0.90)
	config.color_accent    = Color(0.00, 0.90, 0.80)

	# Quiet Frame: capacity 0.67, thermal 0.18 — absent to passive sensors
	var chassis := _part(&"quiet_frame", SuitPartResource.Slot.CHASSIS)
	chassis.systems_capacity    = 0.67
	chassis.systems_load        = 0.0
	chassis.thermal_coefficient = 0.18
	config.equipped_parts[SuitPartResource.Slot.CHASSIS] = chassis

	var thrusters := _part(&"atmos_thrusters", SuitPartResource.Slot.THRUSTER_PACK)
	thrusters.systems_load  = 0.08
	thrusters.thrust_factor = 1.2
	config.equipped_parts[SuitPartResource.Slot.THRUSTER_PACK] = thrusters

	var actuators := _part(&"speed_actuators", SuitPartResource.Slot.ACTUATOR_SUITE)
	actuators.systems_load    = 0.06
	actuators.actuator_factor = 1.15
	config.equipped_parts[SuitPartResource.Slot.ACTUATOR_SUITE] = actuators

	# Total load: 0.14 / capacity 0.67 → load_ratio 0.209 → unlimited flight, near-zero thermal
	return config


static func balanced() -> SuitConfiguration:
	var config := SuitConfiguration.new()
	config.preset_id = &"balanced"
	config.display_name = "Balanced"
	config.color_primary   = Color(0.55, 0.30, 0.70)
	config.color_accent    = Color(1.00, 0.75, 0.10)

	# Flex Frame: capacity 0.88, thermal 0.75 — articulated, bends with the path
	var chassis := _part(&"flex_frame", SuitPartResource.Slot.CHASSIS)
	chassis.systems_capacity    = 0.88
	chassis.systems_load        = 0.0
	chassis.thermal_coefficient = 0.75
	config.equipped_parts[SuitPartResource.Slot.CHASSIS] = chassis

	var thrusters := _part(&"atmos_thrusters", SuitPartResource.Slot.THRUSTER_PACK)
	thrusters.systems_load  = 0.08
	thrusters.thrust_factor = 1.0
	config.equipped_parts[SuitPartResource.Slot.THRUSTER_PACK] = thrusters

	var actuators := _part(&"standard_actuators", SuitPartResource.Slot.ACTUATOR_SUITE)
	actuators.systems_load    = 0.06
	actuators.actuator_factor = 1.0
	config.equipped_parts[SuitPartResource.Slot.ACTUATOR_SUITE] = actuators

	var torso := _part(&"light_torso_armor", SuitPartResource.Slot.ARMOR_TORSO)
	torso.systems_load  = 0.10
	torso.armor_points  = 100.0
	config.equipped_parts[SuitPartResource.Slot.ARMOR_TORSO] = torso

	var weapon := _part(&"light_cannon", SuitPartResource.Slot.WEAPON_PRIMARY)
	weapon.systems_load = 0.18
	config.equipped_parts[SuitPartResource.Slot.WEAPON_PRIMARY] = weapon

	# Total load: 0.42 / capacity 0.88 → load_ratio 0.477 → flight ceiling ~320m, moderate thermal
	return config


static func heavy() -> SuitConfiguration:
	var config := SuitConfiguration.new()
	config.preset_id = &"heavy"
	config.display_name = "Heavy"
	config.color_primary   = Color(0.25, 0.25, 0.28)
	config.color_accent    = Color(0.85, 0.20, 0.10)

	# Load Frame: capacity 1.22, thermal 0.95 — structured to carry more
	var chassis := _part(&"load_frame", SuitPartResource.Slot.CHASSIS)
	chassis.systems_capacity    = 1.22
	chassis.systems_load        = 0.0
	chassis.thermal_coefficient = 0.95
	config.equipped_parts[SuitPartResource.Slot.CHASSIS] = chassis

	# No thruster pack — all budget on armor and weapons

	var actuators := _part(&"power_actuators", SuitPartResource.Slot.ACTUATOR_SUITE)
	actuators.systems_load    = 0.08
	actuators.actuator_factor = 0.7
	config.equipped_parts[SuitPartResource.Slot.ACTUATOR_SUITE] = actuators

	# Full armor suite — 6 plates × 0.17 each
	for slot: int in [
		SuitPartResource.Slot.ARMOR_HEAD,
		SuitPartResource.Slot.ARMOR_TORSO,
		SuitPartResource.Slot.ARMOR_LEFT_ARM,
		SuitPartResource.Slot.ARMOR_RIGHT_ARM,
		SuitPartResource.Slot.ARMOR_LEFT_LEG,
		SuitPartResource.Slot.ARMOR_RIGHT_LEG,
	]:
		var armor := _part(&"heavy_armor", slot as SuitPartResource.Slot)
		armor.systems_load = 0.17
		armor.armor_points = 200.0
		config.equipped_parts[slot] = armor

	var wp := _part(&"heavy_cannon", SuitPartResource.Slot.WEAPON_PRIMARY)
	wp.systems_load  = 0.20
	wp.damage_bonus  = 2.5
	config.equipped_parts[SuitPartResource.Slot.WEAPON_PRIMARY] = wp

	var ws := _part(&"shoulder_cannon", SuitPartResource.Slot.WEAPON_SECONDARY)
	ws.systems_load  = 0.20
	ws.damage_bonus  = 1.8
	config.equipped_parts[SuitPartResource.Slot.WEAPON_SECONDARY] = ws

	# Total load: 0.08 + (6 × 0.17) + 0.20 + 0.20 = 1.50 / capacity 1.22 → ratio 1.23 → overloaded
	return config


static func _part(id: StringName, slot: SuitPartResource.Slot) -> SuitPartResource:
	var p := SuitPartResource.new()
	p.part_id = id
	p.slot = slot
	return p
