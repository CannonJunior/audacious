class_name RareComponent
extends Resource
## One component of the Reality-Anchor Resonance Engine (RARE).

const CargoProfile = preload("res://heist_planner/resources/CargoProfile.gd")
## Tracked by ObjectManifest. Multiple quantity may be required.

@export var component_id: StringName = &""
@export var display_name: String = ""
@export var rare_role: String = ""              # what it does in the RARE device

## Physical footprint for route planning.
@export var dimensions: Vector3 = Vector3.ZERO
@export var mass_kg: float = 0.0

@export var quantity_required: int = 1
@export var quantity_acquired: int = 0
@export var is_damaged: bool = false

## Which target to hit for this component.
@export var source_target_id: StringName = &""
@export var acquired_from_heist: StringName = &""   # populated on acquisition

# ── Transport physics anomalies ───────────────────────────────────────────────
# Active when carrying this component in the route planner and during execution.

## Gravity anomaly radius in meters. 0 = no anomaly.
@export var transport_gravity_anomaly_radius_m: float = 0.0
@export var transport_sensor_shimmer: bool = false
## capability_tags the component disables while being carried.
@export var transport_disables_capabilities: Array[String] = []

# ── State ─────────────────────────────────────────────────────────────────────

func is_acquired() -> bool:
	return quantity_acquired >= quantity_required

func progress_ratio() -> float:
	if quantity_required <= 0:
		return 1.0
	return clampf(float(quantity_acquired) / float(quantity_required), 0.0, 1.0)

func build_cargo_profile() -> CargoProfile:
	var profile := CargoProfile.new()
	profile.mass_kg = mass_kg
	profile.dimensions = dimensions
	if transport_gravity_anomaly_radius_m > 0.0:
		profile.clearance_required = transport_gravity_anomaly_radius_m * 2.0
	return profile
