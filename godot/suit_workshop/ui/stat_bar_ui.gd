## StatBarUI — one of the four suit performance bars (Speed / Stealth / Power / Endurance).
## Drop the StatBar.tscn into any VBoxContainer and call set_stat() to update.
class_name StatBarUI
extends HBoxContainer

const COLOR_GOOD:     Color = Color(0.15, 1.0,  0.30, 1.0)
const COLOR_WARN:     Color = Color(1.0,  0.70, 0.0,  1.0)
const COLOR_CRITICAL: Color = Color(1.0,  0.20, 0.08, 1.0)
const COLOR_DEFICIT:  Color = Color(0.6,  0.1,  0.8,  1.0)  # power deficit — purple

@export var label_text: String  = "STAT":
	set(v): label_text = v; _update_label()
@export var warn_threshold:     float = 0.35
@export var critical_threshold: float = 0.20
@export var show_raw_value:     bool  = false  # if true, shows a number instead of percent

@onready var _label:    Label        = %StatLabel
@onready var _bar:      ProgressBar  = %StatBar
@onready var _value_lbl:Label        = %ValueLabel

var _tween: Tween


func _ready() -> void:
	_update_label()


func set_stat(value: float, max_value: float = 1.0, unit: String = "%") -> void:
	var ratio: float = clampf(value / max_value, 0.0, 1.0)
	_animate_to(ratio)
	_update_color(ratio, value < 0.0)
	if show_raw_value:
		_value_lbl.text = "%.0f %s" % [value, unit]
	else:
		_value_lbl.text = "%d%%" % roundi(ratio * 100.0)


func _animate_to(ratio: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_bar, "value", ratio * 100.0, 0.35)


func _update_color(ratio: float, is_deficit: bool) -> void:
	var col: Color
	if is_deficit:
		col = COLOR_DEFICIT
	elif ratio <= critical_threshold:
		col = COLOR_CRITICAL
	elif ratio <= warn_threshold:
		col = COLOR_WARN
	else:
		col = COLOR_GOOD

	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.corner_radius_top_left     = 2
	style.corner_radius_top_right    = 2
	style.corner_radius_bottom_left  = 2
	style.corner_radius_bottom_right = 2
	_bar.add_theme_stylebox_override("fill", style)


func _update_label() -> void:
	if _label:
		_label.text = label_text
