class_name ManeuverFeasibilityChecker
extends RefCounted
## Checks whether individual ManeuverNodes are feasible given the current suit
## configuration, cargo profile, and RARE transport state.
## Used by the route planner to flag infeasible nodes before execution.

const ManeuverNode = preload("res://heist_planner/resources/ManeuverNode.gd")
const CargoProfile = preload("res://heist_planner/resources/CargoProfile.gd")
const MissionRoute = preload("res://heist_planner/resources/MissionRoute.gd")

class NodeFeasibility:
	var node_id: StringName = &""
	var is_feasible: bool = true
	var missing_capabilities: Array[String] = []
	var cargo_issue: String = ""
	var rare_issues: Array[String] = []
	var warnings: Array[String] = []

## Check one node against suit, cargo, and RARE transport state.
## carrying_rare: true if the player will be carrying a RARE component at this node.
static func check_node(
	node: ManeuverNode,
	capability_tags: Array,
	cargo: CargoProfile = null,
	carrying_rare: bool = false
) -> NodeFeasibility:
	var result := NodeFeasibility.new()
	result.node_id = node.node_id

	for required: String in node.required_capabilities:
		if required not in capability_tags:
			result.is_feasible = false
			result.missing_capabilities.append(required)

	if cargo != null and node.max_cargo_clearance_m > 0.0:
		if not cargo.fits_clearance(node.max_cargo_clearance_m):
			result.is_feasible = false
			result.cargo_issue = "Cargo requires %.2fm clearance; node allows %.2fm" \
				% [cargo.clearance_required, node.max_cargo_clearance_m]

	if carrying_rare:
		if node.rare_gravity_field_radius_m > 0.0 and node.max_cargo_clearance_m > 0.0:
			var anomaly_diameter := node.rare_gravity_field_radius_m * 2.0
			if anomaly_diameter > node.max_cargo_clearance_m:
				result.is_feasible = false
				result.rare_issues.append(
					"Gravity anomaly (%.1fm radius) exceeds node clearance %.2fm" \
					% [node.rare_gravity_field_radius_m, node.max_cargo_clearance_m]
				)
		if node.rare_sensor_shimmer:
			result.warnings.append("RARE sensor shimmer active — camera-facing angles flagged")
		for disabled_cap: String in node.rare_disables_capabilities:
			if disabled_cap in node.required_capabilities:
				result.is_feasible = false
				result.rare_issues.append(
					"RARE disables '%s' which this node requires" % disabled_cap
				)

	if node.timing_margin() < 0.5:
		result.warnings.append(
			"Timing margin %.1fs — very thin; any delay cascades" % node.timing_margin()
		)

	return result

## Check every node in a route. Returns Dictionary[StringName → NodeFeasibility].
static func check_route(
	route: MissionRoute,
	capability_tags: Array,
	cargo: CargoProfile = null,
	carrying_rare: bool = false
) -> Dictionary:
	var results: Dictionary = {}
	for node: ManeuverNode in route.nodes:
		results[node.node_id] = check_node(node, capability_tags, cargo, carrying_rare)
	if route.evasion:
		for node: ManeuverNode in route.evasion.evasion_nodes:
			results[node.node_id] = check_node(node, capability_tags, null, false)
	return results

## Returns true if every node in the route is feasible.
static func is_route_feasible(
	route: MissionRoute,
	capability_tags: Array,
	cargo: CargoProfile = null,
	carrying_rare: bool = false
) -> bool:
	var results := check_route(route, capability_tags, cargo, carrying_rare)
	for node_id: StringName in results:
		var f: NodeFeasibility = results[node_id]
		if not f.is_feasible:
			return false
	return true
