class_name FactionDefinition
extends Resource
## Static identity data for one faction. Authored as .tres in res://data/factions/.

@export var faction: int = 0  ## WorldStateManager.Faction.NONE
@export var display_name: String
@export var description: String

# ── Suit profile ──────────────────────────────────────────────────────────────

## Typical load_ratio range for this faction's suits (min, max).
@export var suit_load_range: Vector2 = Vector2(0.3, 0.8)

## Primary and secondary suit colors for this faction (for enemy suit spawning).
@export var suit_color_primary: Color   = Color.WHITE
@export var suit_color_secondary: Color = Color.DARK_GRAY
@export var suit_color_accent: Color    = Color.WHITE

# ── City presence ─────────────────────────────────────────────────────────────

## Chunks this faction dominates at game start (set in GameWorld scene or startup).
## Stored as a flat array of x,y pairs: [x0, y0, x1, y1, ...].
@export var starting_territory: PackedInt32Array = PackedInt32Array()

# ── Behavior ──────────────────────────────────────────────────────────────────

## Base alert response time in seconds when player is spotted.
@export var alert_response_time: float = 15.0

## If true, this faction attempts to capture rather than destroy.
@export var prefers_capture: bool = false
