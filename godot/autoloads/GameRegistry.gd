extends Node
## Loads and caches all static game data at startup.
## Parts, missions, factions, and presets are loaded from res://data/.
## All return types use Resource (not user class_names) so this autoload
## compiles before the class cache is finalised.

var parts: Dictionary = {}          # StringName → SuitPartResource
var presets: Dictionary = {}        # StringName → SuitConfiguration
var missions: Dictionary = {}       # StringName → MissionBlueprint
var factions: Dictionary = {}       # int (Faction) → FactionDefinition
var heist_targets: Dictionary = {}  # StringName → HeistTarget

func _ready() -> void:
	_load_dir("res://data/parts",         parts,         &"part_id")
	_load_dir("res://data/presets",       presets,       &"preset_id")
	_load_dir("res://data/missions",      missions,      &"mission_id")
	_load_dir("res://data/factions",      factions,      &"faction", true)
	_load_dir("res://data/heist_targets", heist_targets, &"target_id")

# ── Accessors ─────────────────────────────────────────────────────────────────

func get_part(id: StringName) -> Resource:
	return parts.get(id)

func get_parts_for_slot(slot: int) -> Array:
	return parts.values().filter(
		func(p) -> bool: return p.slot == slot
	)

func get_preset(id: StringName) -> Resource:
	return presets.get(id)

func get_mission(id: StringName) -> Resource:
	return missions.get(id)

func get_faction_def(faction: int) -> Resource:  ## faction: WorldStateManager.Faction
	return factions.get(faction)

func get_heist_target(id: StringName) -> Resource:
	return heist_targets.get(id)

func get_heist_targets_for_faction(faction: int) -> Array:
	return heist_targets.values().filter(
		func(t) -> bool: return t.target_faction == faction
	)

# ── Internal ──────────────────────────────────────────────────────────────────

func _load_dir(
	path: String,
	target: Dictionary,
	key_prop: StringName = &"",
	key_by_faction: bool = false,
) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path.path_join(file_name)
			var res: Resource = ResourceLoader.load(full_path)
			if res:
				if key_by_faction:
					var key = res.get("faction")
					if key != null:
						target[key as int] = res
				elif key_prop != &"":
					var key = res.get(key_prop)
					if key != null:
						target[key] = res
				elif res.has_meta("resource_id"):
					target[res.get_meta("resource_id") as StringName] = res
		elif dir.current_is_dir() and file_name != "." and file_name != "..":
			_load_dir(path.path_join(file_name), target, key_prop, key_by_faction)
		file_name = dir.get_next()
	dir.list_dir_end()
