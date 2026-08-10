class_name SuitPartResource
extends Resource
## Defines one interchangeable component of a suit.
## SuitConfiguration holds a set of these; SuitStats aggregates their values.

enum Slot {
	CHASSIS,
	POWER_CORE,
	THRUSTER_PACK,
	ACTUATOR_SUITE,
	SENSOR_ARRAY,
	ARMOR_HEAD,
	ARMOR_TORSO,
	ARMOR_LEFT_ARM,
	ARMOR_RIGHT_ARM,
	ARMOR_LEFT_LEG,
	ARMOR_RIGHT_LEG,
	WEAPON_PRIMARY,
	WEAPON_SECONDARY,
}

# ── Identity ──────────────────────────────────────────────────────────────────

@export var part_id: StringName
@export var display_name: String
@export var description: String
@export var slot: Slot

# ── Load System ───────────────────────────────────────────────────────────────

## Contribution to total systems load. A higher value reduces flight capability.
@export var systems_load: float = 0.0

## Only meaningful on CHASSIS slot: defines the suit's base load capacity.
## Ignored on all other slots.
@export var systems_capacity: float = 1.0

# ── Performance Modifiers (applied as multipliers to base curves) ─────────────

## Thruster Pack only: scales boost speed and hover duration derived from load_ratio.
@export var thrust_factor: float = 1.0

## Actuator Suite only: scales ground speed and jump height derived from load_ratio.
@export var actuator_factor: float = 1.0

## Chassis only: scales how much heat the suit radiates on landing.
@export var thermal_coefficient: float = 1.0

# ── Additive Stats (summed across all equipped parts) ────────────────────────

@export var armor_points: float = 0.0
@export var damage_bonus: float = 0.0

# ── Visual ────────────────────────────────────────────────────────────────────

## Path to the PackedScene containing the mesh for this part.
@export_file("*.tscn", "*.scn") var mesh_scene_path: String = ""

## Skeleton bone this part's scene root attaches to.
@export var socket_bone: StringName = &""

## Surface indices on the imported FBX mesh that light up when this slot is selected.
## Fill in after FBX import by inspecting Mesh → Surfaces in the editor Inspector.
@export var mesh_surface_indices: PackedInt32Array = []

# ── Faction Aesthetic (informational, not gameplay) ───────────────────────────

## Which faction typically produces this part. Purely cosmetic context.
@export var origin_faction: int = 0  ## WorldStateManager.Faction.NONE
