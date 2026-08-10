class_name ManeuverNode
extends Resource
## A discrete moment in a route where a specific physical action is required.
## The route planner places these; the practice system scores them.

const PracticeRecord = preload("res://heist_planner/resources/PracticeRecord.gd")

enum ManeuverType { APPROACH, TRANSIT, EXTRACTION, EVASION }

@export var node_id: StringName = &""
@export var label: String = ""
@export var position: Vector3 = Vector3.ZERO        # world position in city scene

@export var maneuver_type: ManeuverType = ManeuverType.TRANSIT

# ── Entry / exit state ────────────────────────────────────────────────────────

@export var entry_position: Vector3 = Vector3.ZERO
@export var entry_velocity: Vector3 = Vector3.ZERO
@export var exit_position: Vector3 = Vector3.ZERO
@export var exit_velocity: Vector3 = Vector3.ZERO

# ── Timing ────────────────────────────────────────────────────────────────────

## Seconds available to begin this maneuver (e.g. camera blind window).
@export var timing_window_seconds: float = 5.0
@export var estimated_duration_seconds: float = 3.0

# ── Requirements ──────────────────────────────────────────────────────────────

## capability_tags the suit must carry for this node to be feasible.
@export var required_capabilities: Array[String] = []

## Minimum shaft/gap clearance needed at this node. 0 = no restriction.
@export var max_cargo_clearance_m: float = 0.0

# ── Risk ──────────────────────────────────────────────────────────────────────

@export var ghost_risk: float = 0.3             # 0.0–1.0; lower is safer
@export var recovery_note: String = ""

# ── RARE transport overlays ───────────────────────────────────────────────────
# These activate when the player is carrying a RARE component.

## Radius of the component's gravity anomaly field. 0 = no anomaly.
@export var rare_gravity_field_radius_m: float = 0.0
@export var rare_sensor_shimmer: bool = false
@export var rare_disables_capabilities: Array[String] = []

# ── Tactical context ──────────────────────────────────────────────────────────

@export var tactical_purpose: String = ""

# ── Practice history ──────────────────────────────────────────────────────────

@export var practice_records: Array[PracticeRecord] = []

func mastery_stars() -> int:
	var clean := 0
	for rec: PracticeRecord in practice_records:
		if rec.is_clean():
			clean += 1
	return mini(clean, 5)

func best_score() -> float:
	var best := 0.0
	for rec: PracticeRecord in practice_records:
		best = maxf(best, rec.overall_score())
	return best

func timing_margin() -> float:
	return timing_window_seconds - estimated_duration_seconds
