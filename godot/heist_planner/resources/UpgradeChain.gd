class_name UpgradeChain
extends Resource
## A multi-step sidequest where each step uses the full planning pipeline.
## Completing all steps installs the chain's final component.
## Example: Ghost-Step Actuators (3 steps — prototype, firmware key, calibration run).

const UpgradeOpportunity = preload("res://heist_planner/resources/UpgradeOpportunity.gd")

@export var chain_id: StringName = &""
@export var display_name: String = ""
@export var steps: Array[UpgradeOpportunity] = []
@export var final_component_id: StringName = &""  # installed on chain completion

## True if the villain is competing for any step in this chain.
## Creates a race condition if they reach the contested step first.
@export var villain_race: bool = false

func current_step_index() -> int:
	for i: int in range(steps.size()):
		if steps[i].state != UpgradeOpportunity.State.COMPLETE:
			return i
	return steps.size()

func current_step() -> UpgradeOpportunity:
	var idx := current_step_index()
	if idx >= steps.size():
		return null
	return steps[idx]

func is_complete() -> bool:
	return current_step_index() >= steps.size()

func is_lost() -> bool:
	for step: UpgradeOpportunity in steps:
		if step.state == UpgradeOpportunity.State.LOST:
			return true
	return false
