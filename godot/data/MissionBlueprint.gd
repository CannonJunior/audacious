class_name MissionBlueprint
extends Resource
## Static definition of a mission's requirements and parameters.
## Authored as .tres files in res://data/missions/.

enum MissionType {
	GETAWAY,              ## Tutorial: player already has the item, must extract
	RECON,                ## Gather intel; no engagement required
	SETUP,                ## Place infrastructure (rearm cache, safe house)
	PHYSICAL_THEFT,       ## Steal a tangible object from a location
	DATA_HEIST,           ## Extract digital data within a time window
	PERSONNEL_EXTRACTION, ## Non-lethal escort of a target to handoff
	SUPPLY_CHAIN_HIT,     ## Intercept a shipment in transit; aerial combat
}

# ── Identity ──────────────────────────────────────────────────────────────────

@export var mission_id: StringName
@export var display_name: String
@export var mission_type: MissionType = MissionType.GETAWAY

## Other mission_ids that must be completed before this one unlocks.
@export var prerequisite_mission_ids: Array[StringName] = []

# ── Intel requirements ────────────────────────────────────────────────────────

## IntelRecord.IntelType values that must exist in the database before
## the planning phase unlocks. Empty = no intel required (tutorial missions).
@export var required_intel_types: Array[int] = []

# ── Planning requirements ─────────────────────────────────────────────────────

@export var requires_ingress_planning: bool = true
@export var requires_egress_planning: bool = true
@export var requires_refuel_planning: bool = false
@export var requires_handoff_planning: bool = true

# ── Execution parameters ──────────────────────────────────────────────────────

@export var target_faction: int = 0  ## WorldStateManager.Faction.NONE
@export var target_chunk: Vector2i = Vector2i.ZERO
@export var time_limit_seconds: float = 0.0    # 0 = no limit
@export var recommended_max_load_ratio: float = 1.0

# ── Campaign integration ──────────────────────────────────────────────────────

## If non-empty, a successful handoff adds this component to MacGuffin progress.
@export var macguffin_component_id: StringName = &""

## How much this mission's successful completion raises the surveillance level.
@export var surveillance_increment: float = 1.0
