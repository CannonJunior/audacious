class_name MissionWindow
extends Resource
## A window of opportunity defined by guard rotations, shift changes, or events.

enum WindowType { MINIMUM_STAFFING, SHIFT_CHANGEOVER, SPECIAL_EVENT, CUSTOM }

@export var window_id: StringName = &""
@export var window_type: WindowType = WindowType.CUSTOM
@export var label: String = ""                  # e.g. "02:00–04:00  MINIMUM STAFFING"

## Time within a mission's in-game clock when this window opens/closes.
@export var game_time_start: float = 0.0        # in-game seconds from mission start
@export var game_time_end: float = 0.0

@export var quality: float = 0.5               # 0.0–1.0; higher = better conditions
@export var confidence: IntelEntry.Confidence = IntelEntry.Confidence.UNKNOWN
@export var notes: String = ""

func duration() -> float:
	return maxf(0.0, game_time_end - game_time_start)
