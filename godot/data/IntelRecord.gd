class_name IntelRecord
extends Resource
## A single piece of intelligence about the world.
## Stored in WorldStateManager.intel_database with a freshness timer.

enum IntelType {
	SECURITY_COMPOSITION,  ## Enemy suit types and count at a location
	PATROL_ROUTES,         ## Timing and paths of patrols
	BUILDING_THERMAL,      ## Thermal tolerance of a specific structure
	REFUEL_AVAILABILITY,   ## Status of a refuel point
	SAFE_HOUSE_STATUS,     ## Whether a safe house is active or compromised
	HANDOFF_CONTACT,       ## Status and location of a handoff contact
}

@export var intel_id: StringName
@export var intel_type: IntelType
@export var content: Dictionary      # payload; schema varies by intel_type
@export var source: StringName       # who/what provided this ("recon_scan", "contact_alpha")
@export var discovered_at: float     # WorldStateManager.game_time when found
@export var expires_at: float = 0.0  # 0.0 = never expires
@export var related_chunk: Vector2i  # which city chunk this intel pertains to

func is_fresh(current_time: float) -> bool:
	if expires_at <= 0.0:
		return true
	return current_time < expires_at
