class_name RecommendationBar
extends HBoxContainer
## Thin horizontal bar at the top of the Operations Center. Shows the
## top-priority recommendation from RecommendationEngine and a count badge
## for additional items. Refreshes when recommendation_list_updated fires.

const AMBER:      Color = Color(1.0,   0.420, 0.0,  1.0)
const TEXT_MAIN:  Color = Color(0.85,  0.85,  0.88, 1.0)
const TEXT_DIM:   Color = Color(0.55,  0.55,  0.60, 1.0)
const URGENT_COL: Color = Color(1.0,   0.20,  0.08, 1.0)

@onready var _category_lbl:  Label  = %RecCategoryLabel
@onready var _action_lbl:    Label  = %RecActionLabel
@onready var _time_lbl:      Label  = %RecTimeLabel
@onready var _count_lbl:     Label  = %RecCountLabel
@onready var _villain_badge: Label  = %VillainBadge
@onready var _btn_view_all:  Button = %BtnViewAllRecs

signal view_all_pressed()

# ── Public ────────────────────────────────────────────────────────────────────

func refresh(recs: Array) -> void:
	if recs.is_empty():
		_category_lbl.text = "ADVISOR"
		_action_lbl.text = "No active recommendations."
		_action_lbl.add_theme_color_override("font_color", TEXT_DIM)
		_time_lbl.visible = false
		_villain_badge.visible = false
		_count_lbl.text = ""
		return

	var top = recs[0]

	_category_lbl.text = _cat_label(top.category)
	_category_lbl.add_theme_color_override("font_color",
		URGENT_COL if top.villain_contested else AMBER
	)

	_action_lbl.text = top.action_label
	_action_lbl.add_theme_color_override("font_color",
		URGENT_COL if top.villain_contested or (top.time_sensitive and top.hours_remaining < 12.0)
		else TEXT_MAIN
	)

	if top.time_sensitive and top.hours_remaining > 0.0:
		_time_lbl.visible = true
		_time_lbl.text = "%.0fh" % top.hours_remaining
		_time_lbl.add_theme_color_override("font_color",
			URGENT_COL if top.hours_remaining < 12.0 else AMBER
		)
	else:
		_time_lbl.visible = false

	_villain_badge.visible = top.villain_contested
	if top.villain_contested:
		_villain_badge.text = "VILLAIN RACING"
		_villain_badge.add_theme_color_override("font_color", URGENT_COL)

	if recs.size() > 1:
		_count_lbl.text = "+%d more" % (recs.size() - 1)
		_count_lbl.add_theme_color_override("font_color", TEXT_DIM)
	else:
		_count_lbl.text = ""

# ── Internal ──────────────────────────────────────────────────────────────────

func _cat_label(cat: int) -> String:
	match cat:
		RecommendationEngine.Recommendation.Category.MAIN:      return "MAIN JOB"
		RecommendationEngine.Recommendation.Category.SIDEQUEST: return "SIDEQUEST"
		RecommendationEngine.Recommendation.Category.PRACTICE:  return "PRACTICE"
		RecommendationEngine.Recommendation.Category.COOLDOWN:  return "COOLDOWN"
	return "ADVISOR"

# ── Handlers ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_btn_view_all.pressed.connect(func(): view_all_pressed.emit())
	EventBus.recommendation_list_updated.connect(
		func(recs: Array): refresh(recs)
	)
