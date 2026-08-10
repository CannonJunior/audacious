extends Node
## Planning-phase AI partner logic. Handles route stress simulation, approach
## suggestions, RARE transport constraint checks, and passive suit-gap monitoring.
##
## The AIAgent autoload handles runtime narration and autonomy level.
## This autoload handles the planning intelligence that feeds the planner UI.
## Keep the two concerns separate.

const STRESS_SIM_RUNS: int = 1000

const _ManeuverFeasibilityChecker = preload("res://heist_planner/core/ManeuverFeasibilityChecker.gd")
const _ApproachValidator          = preload("res://heist_planner/core/ApproachValidator.gd")

# ── Route stress analysis ─────────────────────────────────────────────────────

class NodeStressResult:
	var node_id: StringName = &""
	var success_rate: float = 0.0
	var primary_failure_mode: String = ""
	var suggestions: Array[String] = []

class RouteStressReport:
	var route_id: StringName = &""
	var node_results: Array[NodeStressResult] = []
	var weakest_node_id: StringName = &""
	var overall_success_rate: float = 0.0

## Probabilistic stress simulation: runs STRESS_SIM_RUNS iterations of the route
## and returns per-node success rates and failure mode analysis.
func stress_simulate(route, capability_tags: Array) -> RouteStressReport:  ## route: MissionRoute
	var report := RouteStressReport.new()
	report.route_id = route.route_id

	var node_successes: Dictionary = {}
	for node in route.nodes:  ## node: ManeuverNode
		node_successes[node.node_id] = 0

	var overall_successes := 0

	for _run: int in range(STRESS_SIM_RUNS):
		var run_ok := true
		var cumulative_delay := 0.0

		for node in route.nodes:  ## node: ManeuverNode
			var cap_ok := true
			for cap: String in node.required_capabilities:
				if cap not in capability_tags:
					cap_ok = false
					break

			var timing_margin: float = node.timing_margin()
			var delay_penalty: float = clampf(cumulative_delay / maxf(timing_margin, 0.1), 0.0, 1.0)
			var base_chance: float = (1.0 - node.ghost_risk) * (1.0 - delay_penalty) if cap_ok else 0.0
			var succeeded: bool = randf() < base_chance

			if succeeded:
				node_successes[node.node_id] += 1
			else:
				cumulative_delay += node.estimated_duration_seconds * 0.5
				run_ok = false

		if run_ok:
			overall_successes += 1

	for node in route.nodes:  ## node: ManeuverNode
		var result := NodeStressResult.new()
		result.node_id = node.node_id
		result.success_rate = float(node_successes.get(node.node_id, 0)) / float(STRESS_SIM_RUNS)
		result.primary_failure_mode = _failure_mode(node, result.success_rate, capability_tags)
		result.suggestions = _suggestions(node, result.success_rate, capability_tags)
		report.node_results.append(result)

	report.overall_success_rate = float(overall_successes) / float(STRESS_SIM_RUNS)

	var weakest_rate := 1.0
	for result: NodeStressResult in report.node_results:
		if result.success_rate < weakest_rate:
			weakest_rate = result.success_rate
			report.weakest_node_id = result.node_id

	return report

# ── Approach suggestions ──────────────────────────────────────────────────────

class ApproachSuggestion:
	var approach = null  ## ApproachOption
	var ghost_probability: float = 0.0
	var rationale: String = ""

## Rank viable approach options by ghost probability. Best option first.
func suggest_approaches(
	target,              ## HeistTarget
	capability_tags: Array,
	cargo = null         ## CargoProfile
) -> Array[ApproachSuggestion]:
	var viable := _ApproachValidator.get_viable_approaches(target, capability_tags, cargo)
	var suggestions: Array[ApproachSuggestion] = []
	for opt in viable:  ## opt: ApproachOption
		var s := ApproachSuggestion.new()
		s.approach = opt
		s.ghost_probability = 1.0 - opt.ghost_risk
		s.rationale = _approach_rationale(opt)
		suggestions.append(s)
	suggestions.sort_custom(func(a: ApproachSuggestion, b: ApproachSuggestion) -> bool:
		return a.ghost_probability > b.ghost_probability
	)
	return suggestions

# ── RARE transport checks ─────────────────────────────────────────────────────

## Check whether carrying a RARE component creates infeasible nodes in a route.
## Returns a list of human-readable issue strings.
func check_rare_transport(route, rare) -> Array[String]:  ## route: MissionRoute, rare: RareComponent
	var issues: Array[String] = []
	var cargo = rare.build_cargo_profile()
	var feasibility: Dictionary = _ManeuverFeasibilityChecker.check_route(route, [], cargo, true)
	for node_id: StringName in feasibility.keys():
		var f = feasibility[node_id]  ## ManeuverFeasibilityChecker.NodeFeasibility
		if not f.is_feasible:
			var detail: String = " ".join(f.rare_issues) if not f.rare_issues.is_empty() else f.cargo_issue
			issues.append("Node %s — %s" % [node_id, detail])
	return issues

# ── Passive gap monitoring ────────────────────────────────────────────────────

## Identify nodes where the player keeps failing. Uses practice_records.
## Returns nodes with mastery < threshold across all planned routes.
func identify_persistent_weak_nodes(routes: Dictionary, mastery_threshold: int = 3) -> Array:
	var weak: Array = []
	for target_id: StringName in routes.keys():
		var route = routes[target_id]  ## MissionRoute
		for node in route.nodes:  ## node: ManeuverNode
			if node.mastery_stars() < mastery_threshold and not node.practice_records.is_empty():
				weak.append({ "target_id": target_id, "node": node })
	return weak

# ── Internal ──────────────────────────────────────────────────────────────────

func _failure_mode(node, success_rate: float, capability_tags: Array) -> String:  ## node: ManeuverNode
	if success_rate >= 0.80:
		return ""
	for cap: String in node.required_capabilities:
		if cap not in capability_tags:
			return "Missing capability '%s' — node is infeasible" % cap
	if node.timing_margin() < 1.0:
		return "Timing margin %.1fs — any delay from prior nodes causes failure" % node.timing_margin()
	if node.ghost_risk > 0.6:
		return "High exposure probability at this geometry — consider alternate approach"
	return "Cascade risk from earlier nodes in the route"

func _suggestions(node, success_rate: float, capability_tags: Array) -> Array[String]:  ## node: ManeuverNode
	var out: Array[String] = []
	if success_rate >= 0.80:
		return out
	for cap: String in node.required_capabilities:
		if cap not in capability_tags:
			out.append("Equip '%s' or choose an approach that avoids this node" % cap)
	if node.timing_margin() < 1.5:
		out.append("A: Reduce node duration (different movement technique)")
		out.append("B: Extend the window by dedicating one AI task slot to looping the relevant camera")
		out.append("C: Redesign exit from the prior node to arrive %.1fs earlier" % (1.5 - node.timing_margin()))
	return out

func _approach_rationale(opt) -> String:  ## opt: ApproachOption
	if opt.ghost_risk < 0.25:
		return "Low exposure — recommended for ghost run"
	if opt.ghost_risk < 0.50:
		return "Moderate exposure — viable with good timing discipline"
	return "High exposure — use only if alternatives unavailable"
