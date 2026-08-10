class_name PracticeRecord
extends Resource
## One scored practice attempt at a ManeuverNode.

@export var position_accuracy: float = 0.0   # 0.0–1.0
@export var timing_accuracy: float = 0.0     # 0.0–1.0
@export var noise_generated: float = 0.0     # 0.0–1.0; 1.0 = within threshold
@export var timestamp: float = 0.0           # WorldStateManager.game_time at attempt

func overall_score() -> float:
	return (position_accuracy + timing_accuracy + noise_generated) / 3.0

## A clean run: all three axes above their respective quality thresholds.
func is_clean() -> bool:
	return position_accuracy >= 0.85 and timing_accuracy >= 0.85 and noise_generated >= 0.75
