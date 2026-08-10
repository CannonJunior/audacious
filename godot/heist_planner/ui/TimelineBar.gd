class_name TimelineBar
extends Control
## Horizontal timeline that visualises each ManeuverNode as a proportional
## segment. Width = estimated_duration / total_duration. Color = mastery level.
## Redraws whenever load_route() is called.

const AMBER:      Color = Color(1.0,  0.420, 0.0,  1.0)
const TEXT_DIM:   Color = Color(0.55, 0.55,  0.60, 1.0)
const GOOD_COL:   Color = Color(0.15, 1.0,   0.30, 1.0)
const WARN_COL:   Color = Color(0.90, 0.70,  0.10, 1.0)
const BAD_COL:    Color = Color(1.0,  0.20,  0.08, 1.0)
const TRACK_BG:   Color = Color(0.08, 0.08,  0.11, 1.0)
const GAP:        float = 2.0
const LABEL_H:    float = 12.0
const BAR_H:      float = 14.0

var _route: MissionRoute = null

# ── Public ────────────────────────────────────────────────────────────────────

func load_route(route: MissionRoute) -> void:
	_route = route
	custom_minimum_size = Vector2(0.0, LABEL_H + GAP + BAR_H + 4.0)
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), TRACK_BG)
	if not _route or _route.nodes.is_empty():
		return

	var total := _route.total_estimated_duration()
	if total <= 0.0:
		return

	var usable_w := size.x - GAP * float(_route.nodes.size() - 1)
	var bar_y := LABEL_H + GAP
	var x := 0.0

	for i: int in range(_route.nodes.size()):
		var node: ManeuverNode = _route.nodes[i]
		var seg_w := (node.estimated_duration_seconds / total) * usable_w
		var col := _mastery_color(node.mastery_stars())

		# Segment bar
		draw_rect(Rect2(x, bar_y, seg_w, BAR_H), Color(col, 0.25))
		draw_rect(Rect2(x, bar_y, seg_w, BAR_H), col, false, 1.0)

		# Timing margin indicator: thin bright top edge if margin >= 1s
		if node.timing_margin() >= 1.0:
			draw_line(Vector2(x, bar_y), Vector2(x + seg_w, bar_y), Color(col, 0.7), 2.0)
		else:
			draw_line(Vector2(x, bar_y), Vector2(x + seg_w, bar_y), WARN_COL, 2.0)

		# Short label (capped to fit segment)
		var font := ThemeDB.fallback_font
		var label := "[%d]" % (i + 1)
		draw_string(font, Vector2(x + 3.0, LABEL_H - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT,
			seg_w - 4.0, 9, TEXT_DIM)

		x += seg_w + GAP

	# Evasion segment (if present) shown as shimmered extension
	if _route.evasion and not _route.evasion.evasion_nodes.is_empty():
		var ev_total := 0.0
		for en: ManeuverNode in _route.evasion.evasion_nodes:
			ev_total += en.estimated_duration_seconds
		if ev_total > 0.0:
			var ev_w := minf((ev_total / total) * usable_w, size.x - x)
			var ev_col := Color(0.85, 0.75, 1.0, 0.6)
			draw_rect(Rect2(x, bar_y, ev_w, BAR_H), Color(0.85, 0.75, 1.0, 0.12))
			draw_rect(Rect2(x, bar_y, ev_w, BAR_H), ev_col, false, 1.0)
			draw_string(ThemeDB.fallback_font, Vector2(x + 3.0, LABEL_H - 2.0),
				"[E]", HORIZONTAL_ALIGNMENT_LEFT, ev_w - 4.0, 9, ev_col)

func _mastery_color(stars: int) -> Color:
	if stars >= 4: return GOOD_COL
	if stars >= 2: return WARN_COL
	if stars >= 1: return AMBER
	return BAD_COL
