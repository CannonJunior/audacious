class_name CargoProfile
extends Resource
## Physical footprint of an extraction target. Applied as constraints in the
## route planner — narrow shafts, mass limits, and fragility affect node viability.

enum Fragility { NONE, MODERATE, HIGH }

@export var mass_kg: float = 0.0
@export var dimensions: Vector3 = Vector3.ZERO   # width, height, depth in meters
@export var clearance_required: float = 0.0       # minimum shaft/gap width in meters
@export var fragility: Fragility = Fragility.NONE

func fits_clearance(available_m: float) -> bool:
	if clearance_required <= 0.0:
		return true
	return available_m >= clearance_required

func largest_dimension() -> float:
	return maxf(maxf(dimensions.x, dimensions.y), dimensions.z)
