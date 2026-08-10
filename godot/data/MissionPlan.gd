class_name MissionPlan
extends Resource
## The player's (or AI agent's) logistics plan for a specific mission.
## Created in the planning phase; read during execution.

@export var mission_id: StringName
@export var suit_preset_id: StringName   # empty = custom configuration

# ── Logistics chain ───────────────────────────────────────────────────────────

@export var ingress_landing_zone: Vector3 = Vector3.ZERO
@export var egress_landing_zone: Vector3 = Vector3.ZERO
@export var refuel_waypoints: Array[Vector3] = []
@export var rearm_waypoints: Array[Vector3] = []
@export var handoff_point: Vector3 = Vector3.ZERO
@export var handoff_contact_id: StringName = &""

# ── Route planning ────────────────────────────────────────────────────────────

@export var primary_approach: Array[Vector3] = []
@export var backup_approach: Array[Vector3] = []
@export var primary_escape: Array[Vector3] = []
@export var backup_escape: Array[Vector3] = []

# ── Meta ──────────────────────────────────────────────────────────────────────

@export var generated_by_agent: bool = false
## 0=GUIDED, 1=ASSISTED, 2=MANUAL — mirrors AIAgent.AutonomyLevel
@export var autonomy_level_at_creation: int = 2
@export var plan_warnings: Array[String] = []   # populated by PlanningValidator
