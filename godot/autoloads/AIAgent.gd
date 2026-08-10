extends Node
## In-game planning companion. Guides the player through missions,
## suggests or auto-completes plans, and narrates tactical context.
##
## In the narrative: this is the handler. Do not surface that here.
## This script contains zero story logic — only planning mechanics.

enum AutonomyLevel {
	GUIDED,    ## Agent completes the full plan; player approves and deploys
	ASSISTED,  ## Agent suggests options; player makes final decisions
	MANUAL,    ## Agent is silent unless explicitly queried
}

var autonomy_level: AutonomyLevel:
	set(v):
		autonomy_level = v
		EventBus.agent_autonomy_changed.emit(v)

var _active_blueprint = null  ## MissionBlueprint

func _ready() -> void:
	autonomy_level = GameSettings.default_agent_autonomy as AutonomyLevel

# ── Public interface ──────────────────────────────────────────────────────────

## Called by MissionManager when a mission begins.
func begin_mission(blueprint) -> void:  ## blueprint: MissionBlueprint
	_active_blueprint = blueprint
	if autonomy_level == AutonomyLevel.GUIDED:
		_narrate(&"mission_start", { "mission_id": blueprint.mission_id })

## Request a contextual line from the agent. Context dict is mission-specific.
func request_line(line_key: StringName, context: Dictionary = {}) -> void:
	if autonomy_level == AutonomyLevel.MANUAL:
		return
	EventBus.agent_line_requested.emit(line_key, context)

## Generate a full MissionPlan from current world state and blueprint.
## Returns null if blueprint is null or insufficient intel is available.
func generate_plan(blueprint) -> Resource:  ## blueprint: MissionBlueprint → MissionPlan
	if not blueprint:
		return null
	var MissionPlanScript = load("res://data/MissionPlan.gd")
	var plan = MissionPlanScript.new()
	plan.mission_id = blueprint.mission_id
	plan.generated_by_agent = true
	plan.autonomy_level_at_creation = autonomy_level as int
	# Stubs: concrete logic added in Phase 8 (Planning Board)
	EventBus.agent_plan_generated.emit(plan)
	return plan

## Warn the player about a specific condition.
func warn(warning_key: StringName) -> void:
	EventBus.agent_warning.emit(warning_key)

# ── Reactive narration hooks ──────────────────────────────────────────────────

func _on_suit_landed(_position: Vector3, _thermal_output: float) -> void:
	if autonomy_level == AutonomyLevel.MANUAL:
		return

func _on_thermal_event(_position: Vector3, suit_output: float, tolerance: float) -> void:
	if suit_output > tolerance and autonomy_level != AutonomyLevel.MANUAL:
		request_line(&"thermal_overage", {
			"output": suit_output,
			"tolerance": tolerance,
		})

func _on_boost_depleted() -> void:
	request_line(&"boost_depleted", {})

func _setup_signal_connections() -> void:
	EventBus.suit_landed.connect(_on_suit_landed)
	EventBus.thermal_event.connect(_on_thermal_event)
	EventBus.boost_depleted.connect(_on_boost_depleted)

func _narrate(line_key: StringName, context: Dictionary) -> void:
	EventBus.agent_line_requested.emit(line_key, context)
