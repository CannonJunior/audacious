extends Node
## Central signal hub. All cross-system communication flows through here.
## Systems never call each other directly — they emit and listen to signals.
##
## Signal parameters are intentionally untyped for user-defined class_names.
## Autoloads compile before the class cache is finalised; typed params would
## fail on first-run of a new project. Comments document the expected types.

# ── Suit & Loadout ────────────────────────────────────────────────────────────

signal configuration_changed(new_config)      ## SuitConfiguration
signal suit_stats_updated(new_stats)          ## SuitStats
signal part_equipped(slot, part)              ## slot: SuitPartResource.Slot, part: SuitPartResource
signal part_unequipped(slot)                  ## SuitPartResource.Slot

# ── Power & Gas Routing ───────────────────────────────────────────────────────

## routes: Dictionary { module_id: StringName -> allocation: float (0.0–1.0) }
signal power_routes_changed(routes: Dictionary)
signal gas_routes_changed(routes: Dictionary)

# ── Movement & Physics ────────────────────────────────────────────────────────

signal suit_state_changed(new_state: StringName, position: Vector3)
signal suit_landed(position: Vector3, thermal_output: float)
signal suit_launched(position: Vector3)
signal boost_activated(direction: Vector3)
signal boost_depleted()
signal rapid_descent_activated(position: Vector3)
signal speed_changed(meters_per_second: float)

# ── Heat & Infrastructure ─────────────────────────────────────────────────────

signal thermal_event(position: Vector3, suit_output: float, structure_tolerance: float)
signal refuel_started(point_id: StringName)
signal refuel_completed(point_id: StringName)
signal rearm_completed(point_id: StringName)
signal infrastructure_compromised(point_id: StringName)
signal infrastructure_destroyed(point_id: StringName)

# ── Combat ────────────────────────────────────────────────────────────────────

signal target_acquired(target_id: StringName)
signal target_lost()
signal weapon_fired(weapon_id: StringName, origin: Vector3, direction: Vector3)
signal damage_dealt(target_id: StringName, amount: float, damage_type: StringName)
signal damage_received(amount: float, source_id: StringName)
signal armor_depleted()
signal enemy_suit_destroyed(suit_id: StringName, faction: int)

# ── Mission ───────────────────────────────────────────────────────────────────

signal mission_started(blueprint_id: StringName)
signal objective_completed(objective_id: StringName)
signal objective_failed(objective_id: StringName)
signal mission_completed(mission_id: StringName)
signal mission_failed(mission_id: StringName, reason: StringName)
signal handoff_completed(component_id: StringName, location: Vector3)
signal item_acquired(item_id: StringName)
signal item_lost(item_id: StringName)

# ── Intel & Planning ──────────────────────────────────────────────────────────

signal intel_discovered(intel)               ## IntelRecord
signal intel_expired(intel_id: StringName)
signal plan_submitted(plan)                  ## MissionPlan
signal plan_validated(is_valid: bool, warnings: Array)

# ── World State & Factions ────────────────────────────────────────────────────

signal faction_alert_changed(faction: int, chunk: Vector2i, new_level: float)
signal territory_changed(chunk: Vector2i, old_faction: int, new_faction: int)
signal safe_house_burned(point_id: StringName)
signal surveillance_threshold_crossed(new_level: float)

# ── AI Agent ──────────────────────────────────────────────────────────────────

signal agent_line_requested(line_key: StringName, context: Dictionary)
signal agent_plan_generated(plan)            ## MissionPlan
signal agent_warning(warning_key: StringName)
signal agent_autonomy_changed(new_level: int)

# ── Network ───────────────────────────────────────────────────────────────────

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal session_started()
signal session_ended()

# ── Heist Planner — Intel & Heat ─────────────────────────────────────────────

signal heist_target_heat_changed(target_id: StringName, new_heat: float)
signal heist_target_intel_updated(target_id: StringName)

# ── Heist Planner — Routes & Practice ────────────────────────────────────────

signal mission_route_saved(route_id: StringName)
signal practice_session_completed(route_id: StringName, node_id: StringName)

# ── Heist Planner — RARE Assembly ────────────────────────────────────────────

signal rare_component_acquired(component_id: StringName, from_target_id: StringName)
signal rare_component_damaged(component_id: StringName)
signal object_manifest_progress_changed(progress: float)

# ── Heist Planner — Upgrade Board ────────────────────────────────────────────

signal upgrade_opportunity_discovered(upgrade_id: StringName)
signal upgrade_opportunity_state_changed(upgrade_id: StringName, new_state: int)
signal upgrade_chain_step_completed(chain_id: StringName, step: int)
signal upgrade_chain_completed(chain_id: StringName)

# ── Heist Planner — Recommendations ──────────────────────────────────────────

signal recommendation_list_updated(recommendations: Array)

# ── Chat ─────────────────────────────────────────────────────────────────────

signal chat_message_received(sender_id: String, message: String)
signal ollama_response_received(message: String, model: String)
signal ollama_models_loaded(models: Array)
signal ollama_error(error: String)

# ── Game State ────────────────────────────────────────────────────────────────

signal game_mode_changed(new_mode: StringName)
signal loading_started(scene_path: String)
signal loading_completed()
signal pause_toggled(is_paused: bool)
