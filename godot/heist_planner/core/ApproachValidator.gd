class_name ApproachValidator
extends RefCounted
## Pure validation: checks whether a suit's current capabilities and cargo
## satisfy the requirements of an ApproachOption or individual ManeuverNode.
## No state — always call as static.

const ApproachOption = preload("res://heist_planner/resources/ApproachOption.gd")
const CargoProfile = preload("res://heist_planner/resources/CargoProfile.gd")
const HeistTarget = preload("res://heist_planner/resources/HeistTarget.gd")

class ValidationResult:
	var is_valid: bool = true
	var missing_capabilities: Array[String] = []
	var cargo_issues: Array[String] = []
	var warnings: Array[String] = []

## Check one ApproachOption against the suit's capability_tags and current cargo.
## capability_tags comes from SuitStatCalculator.SuitStats.capability_tags.
static func validate_approach(
	approach: ApproachOption,
	capability_tags: Array,
	cargo: CargoProfile = null
) -> ValidationResult:
	var result := ValidationResult.new()

	for required: String in approach.required_capabilities:
		if required not in capability_tags:
			result.is_valid = false
			result.missing_capabilities.append(required)

	if cargo != null:
		if approach.max_cargo_clearance_m > 0.0 and not cargo.fits_clearance(approach.max_cargo_clearance_m):
			result.is_valid = false
			result.cargo_issues.append(
				"Cargo needs %.2fm clearance; route allows %.2fm" \
				% [cargo.clearance_required, approach.max_cargo_clearance_m]
			)
		if approach.max_cargo_mass_kg > 0.0 and cargo.mass_kg > approach.max_cargo_mass_kg:
			result.warnings.append(
				"Cargo %.1f kg near route limit %.1f kg" \
				% [cargo.mass_kg, approach.max_cargo_mass_kg]
			)

	return result

## Filter a target's approach options to those viable with the given suit.
static func get_viable_approaches(
	target: HeistTarget,
	capability_tags: Array,
	cargo: CargoProfile = null
) -> Array[ApproachOption]:
	var viable: Array[ApproachOption] = []
	for approach: ApproachOption in target.approach_options:
		var result := validate_approach(approach, capability_tags, cargo)
		if result.is_valid:
			viable.append(approach)
	return viable

## Summarise what capabilities are needed across all approaches for a target.
static func all_required_capabilities(target: HeistTarget) -> Array[String]:
	var caps: Array[String] = []
	for approach: ApproachOption in target.approach_options:
		for cap: String in approach.required_capabilities:
			if cap not in caps:
				caps.append(cap)
	return caps
