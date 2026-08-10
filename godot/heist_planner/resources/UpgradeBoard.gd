class_name UpgradeBoard
extends Resource
## Full upgrade tree state. The player's view of known, locked, and undiscovered
## suit upgrade opportunities. The "Metroid hook" — visible empty slots motivate
## exploration even when the upgrade source is unknown.

const UpgradeOpportunity = preload("res://heist_planner/resources/UpgradeOpportunity.gd")
const UpgradeChain = preload("res://heist_planner/resources/UpgradeChain.gd")

@export var opportunities: Array[UpgradeOpportunity] = []
@export var chains: Array[UpgradeChain] = []

## Total opportunities the player has ever discovered (including completed/lost).
@export var known_opportunity_count: int = 0

## Slots the player knows exist but hasn't found the source for.
@export var undiscovered_slot_count: int = 0

# ── Accessors ─────────────────────────────────────────────────────────────────

func get_opportunity(upgrade_id: StringName) -> UpgradeOpportunity:
	for opp: UpgradeOpportunity in opportunities:
		if opp.upgrade_id == upgrade_id:
			return opp
	return null

func get_chain(chain_id: StringName) -> UpgradeChain:
	for chain: UpgradeChain in chains:
		if chain.chain_id == chain_id:
			return chain
	return null

func get_available() -> Array[UpgradeOpportunity]:
	var out: Array[UpgradeOpportunity] = []
	for opp: UpgradeOpportunity in opportunities:
		if opp.is_available():
			out.append(opp)
	return out

func get_time_sensitive(current_game_time: float) -> Array[UpgradeOpportunity]:
	var out: Array[UpgradeOpportunity] = []
	for opp: UpgradeOpportunity in opportunities:
		if opp.is_available() and opp.is_time_limited():
			out.append(opp)
	out.sort_custom(func(a: UpgradeOpportunity, b: UpgradeOpportunity) -> bool:
		return a.hours_remaining(current_game_time) < b.hours_remaining(current_game_time)
	)
	return out

func get_villain_contested() -> Array[UpgradeOpportunity]:
	var out: Array[UpgradeOpportunity] = []
	for opp: UpgradeOpportunity in opportunities:
		if opp.is_available() and opp.villain_contested:
			out.append(opp)
	return out
