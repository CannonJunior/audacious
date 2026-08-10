class_name ApproachOption
extends Resource
## One possible way to enter, traverse, and exit a target.
## A HeistTarget holds several; the player picks one for the route planner.

@export var approach_id: StringName = &""
@export var label: String = ""                   # e.g. "HVAC shaft (east roof)"

@export var entry_point_description: String = ""
@export var route_description: String = ""
@export var extraction_description: String = ""

## capability_tags that the suit must carry for this approach to be viable.
@export var required_capabilities: Array[String] = []

## Cargo constraints for this path. 0 = no restriction.
@export var max_cargo_clearance_m: float = 0.0  # tightest shaft clearance on the route
@export var max_cargo_mass_kg: float = 0.0

## Risk profile.
@export var ghost_risk: float = 0.5             # 0.0 = certain ghost, 1.0 = guaranteed detection
@export var recovery_risk: float = 0.5          # if detected, how hard is it to recover

@export var intel_confidence: IntelEntry.Confidence = IntelEntry.Confidence.UNKNOWN
@export var notes: String = ""
