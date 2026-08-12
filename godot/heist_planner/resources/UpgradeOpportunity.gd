class_name UpgradeOpportunity
extends Resource
## One available (or potentially available) suit upgrade, discovered through play.
## Sidequests use the same planning pipeline as main heists but yield suit capability
## rather than RARE components.

enum State { UNDISCOVERED, LOCKED, OPPORTUNITY, ACTIVE, COMPLETE, LOST }

@export var upgrade_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var discovery_source: String = ""   # how the player found this

# ── Chain position ────────────────────────────────────────────────────────────

@export var chain_id: StringName = &""      # empty if standalone
@export var chain_step: int = 0
@export var chain_total: int = 1

# ── Target ────────────────────────────────────────────────────────────────────

@export var target_id: StringName = &""     # HeistTarget to hit for this step

# ── State ─────────────────────────────────────────────────────────────────────

@export var state: State = State.UNDISCOVERED

# ── Time pressure ─────────────────────────────────────────────────────────────

@export var expiry_game_time: float = -1.0  # -1 = no limit; absolute WorldStateManager.game_time
@export var villain_contested: bool = false

# ── Cargo profile ─────────────────────────────────────────────────────────────

@export var cargo: CargoProfile = null

# ── Stat preview (populated by UpgradeBoardManager) ──────────────────────────

@export var preview_speed_delta: float = 0.0
@export var preview_stealth_delta: float = 0.0
@export var preview_mass_delta_kg: float = 0.0
@export var preview_endurance_delta: float = 0.0
@export var reward_component_id: StringName = &""
@export var grants_capability_tags: Array[String] = []

# ── Discovery trigger ─────────────────────────────────────────────────────────

## Intel field_id that, when hacked, surfaces this opportunity from UNDISCOVERED.
@export var discovery_trigger_field: StringName = &""

# ── Shortcuts for UI (alias the preview_* names) ──────────────────────────────

var delta_speed_modifier: float:
	get: return preview_speed_delta
var delta_stealth_modifier: float:
	get: return preview_stealth_delta
var delta_endurance_modifier: float:
	get: return preview_endurance_delta
var time_sensitive: bool:
	get: return is_time_limited()

# ── Accessors ─────────────────────────────────────────────────────────────────

func is_time_limited() -> bool:
	return expiry_game_time > 0.0

func hours_remaining(current_game_time: float = -1.0) -> float:
	if expiry_game_time <= 0.0:
		return -1.0
	var now: float = current_game_time if current_game_time >= 0.0 else WorldStateManager.game_time
	return (expiry_game_time - now) / 3600.0

func is_available() -> bool:
	return state == State.OPPORTUNITY or state == State.ACTIVE
