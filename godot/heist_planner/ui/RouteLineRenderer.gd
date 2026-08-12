class_name RouteLineRenderer
extends Control
## 2D overlay drawn on top of the CitySceneViewport that shows route
## connections as projected screen-space lines. When city geometry is absent,
## draws a schematic node-graph instead.
## Updated by calling load_route(); redraws every time the route changes.

const AMBER:      Color = Color(1.0,  0.420, 0.0,  0.85)
const RARE_SHIM:  Color = Color(0.85, 0.75,  1.0,  0.80)
const DIM_LINE:   Color = Color(0.30, 0.40,  0.50, 0.50)
const GOOD_COL:   Color = Color(0.15, 1.0,   0.30, 0.80)
const BAD_COL:    Color = Color(1.0,  0.20,  0.08, 0.80)

const NODE_R:    float = 8.0
const EVASION_R: float = 6.0
const MARGIN:    float = 40.0

var _route: MissionRoute = null
var _carrying_rare: bool = false

# ── Public ────────────────────────────────────────────────────────────────────

func load_route(route: MissionRoute, carrying_rare: bool = false) -> void:
	_route = route
	_carrying_rare = carrying_rare
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _route or _route.nodes.is_empty():
		return

	var positions := _compute_layout()

	# Draw transit connections
	for i: int in range(positions.size() - 1):
		var col := RARE_SHIM if _carrying_rare else AMBER
		draw_line(positions[i], positions[i + 1], col, 2.0)
		_draw_arrow(positions[i], positions[i + 1], col)

	# Evasion branch
	if _route.evasion and not _route.evasion.evasion_nodes.is_empty():
		var sep_idx := _sep_index()
		if sep_idx >= 0 and sep_idx < positions.size():
			var ev_positions := _compute_evasion_layout(positions[sep_idx])
			draw_line(positions[sep_idx], ev_positions[0], DIM_LINE, 1.5)
			for i: int in range(ev_positions.size() - 1):
				draw_line(ev_positions[i], ev_positions[i + 1], RARE_SHIM, 1.5)
			for p: Vector2 in ev_positions:
				draw_circle(p, EVASION_R, Color(0.85, 0.75, 1.0, 0.30))
				draw_arc(p, EVASION_R, 0.0, TAU, 16, RARE_SHIM, 1.5)

	# Draw node circles
	for i: int in range(_route.nodes.size()):
		var node: ManeuverNode = _route.nodes[i]
		var p: Vector2 = positions[i]
		var stars := node.mastery_stars()
		var fill := Color(GOOD_COL, 0.20) if stars >= 3 else Color(AMBER, 0.15)
		var ring := GOOD_COL if stars >= 3 else AMBER if stars >= 1 else BAD_COL
		draw_circle(p, NODE_R, fill)
		draw_arc(p, NODE_R, 0.0, TAU, 24, ring, 2.0)

		var font := ThemeDB.fallback_font
		draw_string(font, p + Vector2(NODE_R + 4.0, 4.0),
			"[%d] %s" % [i + 1, node.label], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ring)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _compute_layout() -> Array:
	var n := _route.nodes.size()
	var usable_w := size.x - MARGIN * 2.0
	var positions: Array = []
	for i: int in range(n):
		var x := MARGIN + (float(i) / maxf(n - 1, 1)) * usable_w
		positions.append(Vector2(x, size.y * 0.45))
	return positions

func _compute_evasion_layout(branch_from: Vector2) -> Array:
	var ev_nodes := _route.evasion.evasion_nodes
	var positions: Array = []
	for i: int in range(ev_nodes.size()):
		var x := branch_from.x + float(i + 1) * 60.0
		positions.append(Vector2(x, branch_from.y + 40.0))
	return positions

func _sep_index() -> int:
	var sep_id := _route.evasion.separation_point_node_id
	for i: int in range(_route.nodes.size()):
		if _route.nodes[i].node_id == sep_id:
			return i
	return _route.nodes.size() - 1

func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var dir := (to - from).normalized()
	var mid := (from + to) * 0.5
	var perp := Vector2(-dir.y, dir.x) * 5.0
	draw_line(mid, mid - dir * 8.0 + perp, color, 1.5)
	draw_line(mid, mid - dir * 8.0 - perp, color, 1.5)
