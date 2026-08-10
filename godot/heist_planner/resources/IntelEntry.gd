class_name IntelEntry
extends Resource
## A single field of intelligence about a target, with a confidence rating.
## Multiple IntelEntry instances make up a HeistTarget's dossier.

enum Confidence { UNKNOWN, RUMORED, PROBABLE, CONFIRMED }

@export var field_id: StringName = &""        # e.g. &"guard_rotation"
@export var display_label: String = ""         # e.g. "Guard Rotation"
@export var confidence: Confidence = Confidence.UNKNOWN
@export var content: String = ""              # human-readable intelligence text
@export var source_id: StringName = &""       # who/what provided this
@export var discovered_at: float = 0.0        # WorldStateManager.game_time when found
@export var expires_at: float = 0.0           # 0.0 = never expires

func confidence_label() -> String:
	match confidence:
		Confidence.CONFIRMED:  return "[CONFIRMED]"
		Confidence.PROBABLE:   return "[PROBABLE]"
		Confidence.RUMORED:    return "[RUMORED]"
	return "[UNKNOWN]"

func is_fresh(current_time: float) -> bool:
	if expires_at <= 0.0:
		return true
	return current_time < expires_at
