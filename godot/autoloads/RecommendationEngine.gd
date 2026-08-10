extends Node
## Generates a prioritized recommendation list interleaving main heists and sidequests.
## The engine never instructs — it surfaces the calculation and lets the player decide.
##
## Call rebuild() after major state changes. Results are cached and emitted via EventBus.

class Recommendation:
	enum Category { MAIN, SIDEQUEST, PRACTICE, COOLDOWN }
	var category: Category = Category.MAIN
	var priority: int = 0              # higher = more urgent; used for sort
	var target_id: StringName = &""
	var upgrade_id: StringName = &""   # populated for SIDEQUEST
	var action_label: String = ""
	var urgency_note: String = ""
	var time_sensitive: bool = false
	var hours_remaining: float = -1.0  # -1 = no time pressure
	var villain_contested: bool = false

var _last_recommendations: Array[Recommendation] = []

# ── Public interface ──────────────────────────────────────────────────────────

## Rebuild and return the recommendation list. Emits recommendation_list_updated.
## routes: Dictionary[StringName → MissionRoute] keyed by target_id.
func rebuild(manifest, board, routes: Dictionary) -> Array[Recommendation]:  ## manifest: ObjectManifest, board: UpgradeBoard
	var recs: Array[Recommendation] = []
	var now := WorldStateManager.game_time

	# ── Main heists: unacquired RARE components ──────────────────────────────
	for comp in manifest.get_unacquired():  ## comp: RareComponent
		recs.append(_rec_for_component(comp, routes))

	# Damaged components need attention too
	for comp in manifest.get_damaged():  ## comp: RareComponent
		var rec := Recommendation.new()
		rec.category = Recommendation.Category.MAIN
		rec.target_id = comp.source_target_id
		rec.action_label = "REPAIR OR REPLACE → %s (damaged)" % comp.display_name
		rec.urgency_note = "Damaged component reduces RARE assembly viability"
		rec.priority = 4
		recs.append(rec)

	# ── Sidequests: villain-contested first, then time-sensitive, then normal ─
	for opp in board.get_villain_contested():  ## opp: UpgradeOpportunity
		recs.append(_rec_for_sidequest(opp, now, true))

	for opp in board.get_time_sensitive(now):  ## opp: UpgradeOpportunity
		if opp.villain_contested:
			continue  # already added
		recs.append(_rec_for_sidequest(opp, now, false))

	for opp in board.get_available():  ## opp: UpgradeOpportunity
		if opp.is_time_limited() or opp.villain_contested:
			continue  # already added
		var rec := Recommendation.new()
		rec.category = Recommendation.Category.SIDEQUEST
		rec.upgrade_id = opp.upgrade_id
		rec.target_id = opp.target_id
		rec.action_label = "VIEW DETAILS → %s" % opp.display_name
		rec.priority = 3
		recs.append(rec)

	_sort(recs, now)
	_last_recommendations = recs
	EventBus.recommendation_list_updated.emit(recs)
	return recs

func get_recommendations() -> Array[Recommendation]:
	return _last_recommendations

# ── Internal ──────────────────────────────────────────────────────────────────

func _rec_for_component(comp, routes: Dictionary) -> Recommendation:  ## comp: RareComponent
	var rec := Recommendation.new()
	rec.category = Recommendation.Category.MAIN
	rec.target_id = comp.source_target_id

	var heat_tier := HeatSystem.get_heat_tier(comp.source_target_id)
	var has_route := routes.has(comp.source_target_id)

	if heat_tier == &"hot":
		rec.action_label = "COOL DOWN %s — too hot to plan" % comp.display_name
		rec.urgency_note = "Heat must decay before windows open"
		rec.priority = 2
		rec.category = Recommendation.Category.COOLDOWN
	elif not has_route:
		rec.action_label = "PLAN RECON → %s" % comp.display_name
		rec.urgency_note = "No approach designed yet"
		rec.priority = 5
	else:
		var route = routes[comp.source_target_id]  ## MissionRoute
		var weak: Array = route.get_weak_nodes()
		if not weak.is_empty():
			rec.action_label = "PRACTICE NODE %s  →  then EXECUTE" % weak[0].label
			rec.urgency_note = "%d node(s) below mastery threshold" % weak.size()
			rec.priority = 6
			rec.category = Recommendation.Category.PRACTICE
		else:
			rec.action_label = "EXECUTE → %s" % comp.display_name
			rec.urgency_note = "Route designed, nodes mastered"
			rec.priority = 8

	return rec

func _rec_for_sidequest(opp, now: float, contested: bool) -> Recommendation:  ## opp: UpgradeOpportunity
	var rec := Recommendation.new()
	rec.category = Recommendation.Category.SIDEQUEST
	rec.upgrade_id = opp.upgrade_id
	rec.target_id = opp.target_id
	rec.villain_contested = contested
	rec.time_sensitive = opp.is_time_limited()
	rec.hours_remaining = opp.hours_remaining(now)

	if contested:
		rec.action_label = "PLAN SIDEQUEST — %s  ⚠ VILLAIN CONTESTED" % opp.display_name
		rec.urgency_note = "Villain may reach this target first — act immediately"
		rec.priority = 9
	elif opp.is_time_limited():
		rec.action_label = "PLAN SIDEQUEST — %s  (%.0fh remaining)" % [opp.display_name, rec.hours_remaining]
		rec.urgency_note = "Window closes soon"
		rec.priority = 7
	else:
		rec.action_label = "PLAN SIDEQUEST — %s" % opp.display_name
		rec.priority = 5

	return rec

func _sort(recs: Array[Recommendation], _now: float) -> void:
	recs.sort_custom(func(a: Recommendation, b: Recommendation) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		if a.time_sensitive != b.time_sensitive:
			return a.time_sensitive
		if a.hours_remaining > 0.0 and b.hours_remaining > 0.0:
			return a.hours_remaining < b.hours_remaining
		return false
	)
