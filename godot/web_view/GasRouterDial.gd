extends Control
## Gas manifold display — branch-level pressure routing.
## 4 branch hexes in a 2×2 grid; drag to set pressure via arc angle.
## Double-click a hex to toggle between 0 and full pressure.
## Drive by calling update_state(branches, tank_pressure).

const CAT_COLORS := {
	"directional": Color(0.251, 0.659, 0.878),
	"attitude":    Color(0.000, 0.831, 0.667),
	"maneuver":    Color(1.000, 0.627, 0.251),
	"environ":     Color(0.439, 0.784, 0.439),
}

const HEX_R := 52.0

## 2×2 hex-grid arrangement; order matches GasRouter.BRANCHES.
const CAT_OFFSETS: Array[Vector2] = [
	Vector2(-45.0, -78.0),   # directional — upper-left
	Vector2( 45.0, -78.0),   # attitude    — upper-right
	Vector2(-45.0,  78.0),   # maneuver    — lower-left
	Vector2( 45.0,  78.0),   # environ     — lower-right
]

signal routes_changed(routes: Dictionary)

var _branches:      Array = []
var _tank_pressure: float = 1.0
var _hover_idx:     int   = -1
var _drag_idx:      int   = -1


func _ready() -> void:
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)


func update_state(branches: Array, tank_pressure: float) -> void:
	if _drag_idx >= 0:
		return
	_branches      = branches.duplicate(true)
	_tank_pressure = tank_pressure
	queue_redraw()


func _process(_delta: float) -> void:
	if _drag_idx >= 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_emit_routes()
		_drag_idx = -1
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var idx := _hit_hex(event.position)
			if idx >= 0:
				if event.double_click:
					_toggle_hex(idx)
					_emit_routes()
					queue_redraw()
				else:
					_drag_idx = idx
					_apply_mouse(event.position)
					queue_redraw()
				get_viewport().set_input_as_handled()
		else:
			if _drag_idx >= 0:
				_emit_routes()
				_drag_idx = -1
				queue_redraw()
	elif event is InputEventMouseMotion:
		var prev_hover := _hover_idx
		if _drag_idx >= 0:
			_apply_mouse(event.position)
			queue_redraw()
			get_viewport().set_input_as_handled()
		else:
			_hover_idx = _hit_hex(event.position)
			if _hover_idx != prev_hover:
				queue_redraw()


func _layout() -> Dictionary:
	var s: float  = minf(size.x / 238.0, size.y / 304.0)
	var ox: float = (size.x - 238.0 * s) * 0.5
	var oy: float = (size.y - 304.0 * s) * 0.5
	return {"s": s, "cx": ox + 119.0 * s, "cy": oy + 152.0 * s}


func _hex_center(i: int, cx: float, cy: float, s: float) -> Vector2:
	var off := CAT_OFFSETS[i]
	return Vector2(cx + off.x * s, cy + off.y * s)


func _hit_hex(local: Vector2) -> int:
	var L      := _layout()
	var s: float  = L["s"]
	var cx: float = L["cx"]
	var cy: float = L["cy"]
	var hex_r := HEX_R * s
	for i in range(_branches.size()):
		if local.distance_to(_hex_center(i, cx, cy, s)) <= hex_r:
			return i
	return -1


func _arc_frac(local: Vector2, idx: int) -> float:
	const ARC_START := -PI * 0.5
	var L      := _layout()
	var s: float  = L["s"]
	var cx: float = L["cx"]
	var cy: float = L["cy"]
	var hc    := _hex_center(idx, cx, cy, s)
	var angle := atan2(local.y - hc.y, local.x - hc.x)
	var rel: float = fmod(angle - ARC_START + TAU * 10.0, TAU)
	return clampf(rel / TAU, 0.0, 1.0)


func _apply_mouse(local: Vector2) -> void:
	if _drag_idx < 0 or _drag_idx >= _branches.size():
		return
	(_branches[_drag_idx] as Dictionary)["allocated"] = _arc_frac(local, _drag_idx)


func _toggle_hex(idx: int) -> void:
	if idx < 0 or idx >= _branches.size():
		return
	var b := _branches[idx] as Dictionary
	b["allocated"] = 0.0 if float(b.get("allocated", 0.0)) > 0.0 else 1.0


func _emit_routes() -> void:
	var routes := {}
	for b in _branches:
		var cat := (b as Dictionary).get("category", "") as String
		if cat != "":
			routes[cat] = (b as Dictionary).get("allocated", 0.0)
	routes_changed.emit(routes)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _hex_pts(cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var a := PI / 6.0 + (PI / 3.0) * float(i)   # pointy-top
		pts.append(Vector2(cx + r * cos(a), cy + r * sin(a)))
	return pts


func _fill(pts: PackedVector2Array, c: Color) -> void:
	var clrs := PackedColorArray()
	clrs.resize(pts.size())
	clrs.fill(c)
	draw_polygon(pts, clrs)


# ── Draw ──────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _branches.is_empty():
		return
	var font  := ThemeDB.fallback_font
	var L     := _layout()
	var s: float  = L["s"]
	var cx: float = L["cx"]
	var cy: float = L["cy"]

	_draw_tank_core(cx, cy, s, font)

	for i in range(_branches.size()):
		_draw_hex(i, cx, cy, s, font, i == _hover_idx or i == _drag_idx)


func _draw_hex(i: int, cx: float, cy: float, s: float, font: Font, hov: bool = false) -> void:
	var b     := _branches[i] as Dictionary
	var hc    := _hex_center(i, cx, cy, s)
	var color := CAT_COLORS.get(b.get("category", "directional"), CAT_COLORS["directional"]) as Color
	var alloc := float(b.get("allocated", 0.0))
	var min_p := float(b.get("min_pressure", 0.0))
	var frac  := clampf(alloc, 0.0, 1.0)
	var hex_r := HEX_R * s
	var active := alloc >= min_p and alloc > 0.0

	var mods := b.get("modules", []) as Array

	# ── Hex body ──────────────────────────────────────────────────────────────

	var pts := _hex_pts(hc.x, hc.y, hex_r - 1.0)
	_fill(pts, Color(color.r, color.g, color.b, 0.08 + frac * 0.16) if active \
	           else Color(0.039, 0.047, 0.078))

	var b_pts := pts.duplicate()
	b_pts.append(pts[0])
	var border_a: float = 1.0 if (hov or active) else 0.20
	var border_w: float = 2.0 if hov else 1.0
	draw_polyline(b_pts, Color(color.r, color.g, color.b, border_a), border_w, true)

	if hov:
		draw_arc(hc, hex_r + 2.0 * s, 0, TAU, 32,
			Color(color.r, color.g, color.b, 0.18), 1.5 * s, true)

	# ── Interior arc gauge ────────────────────────────────────────────────────

	const ARC_START := -PI * 0.5
	var arc_r := hex_r * 0.68
	var arc_w := 3.5 * s

	draw_arc(hc, arc_r, 0.0, TAU, 64, Color(0.06, 0.10, 0.14), arc_w, true)

	if frac > 0.0:
		var arc_end: float = ARC_START + frac * TAU
		var n_pts: int     = max(2, int(64.0 * frac))
		draw_arc(hc, arc_r, ARC_START, arc_end, n_pts, color, arc_w, true)
		draw_circle(hc + Vector2(cos(arc_end), sin(arc_end)) * arc_r, 3.0 * s, color)

	# Minimum pressure threshold tick
	if min_p > 0.0:
		var min_a: float = ARC_START + min_p * TAU
		var ti := hc + Vector2(cos(min_a), sin(min_a)) * (arc_r - 4.0 * s)
		var to_ := hc + Vector2(cos(min_a), sin(min_a)) * (arc_r + 4.0 * s)
		draw_line(ti, to_, Color(0.9, 0.2, 0.2, 0.75), 1.5, true)

	# ── Text inside the arc ring ───────────────────────────────────────────────

	var label := b.get("label", "") as String
	var fs: int    = max(6, int(8.0 * s))
	var fs_sm: int = max(5, int(6.5 * s))
	var lw    := arc_r * 1.7
	var lx    := hc.x - lw * 0.5
	var tc    := Color(color.r, color.g, color.b, 1.0) if active else \
	             Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)

	draw_string(font, Vector2(lx, hc.y - float(fs) * 0.1), label,
		HORIZONTAL_ALIGNMENT_CENTER, lw, fs, tc)

	if alloc > 0.0:
		var pct_c := Color(color.r, color.g, color.b, 0.85) if active \
		             else Color(0.85, 0.2, 0.2, 1.0)
		draw_string(font, Vector2(lx, hc.y + float(fs) * 1.15),
			"%d%%  %d mod" % [int(frac * 100.0), mods.size()],
			HORIZONTAL_ALIGNMENT_CENTER, lw, fs_sm, pct_c)


func _draw_tank_core(cx: float, cy: float, s: float, font: Font) -> void:
	var pct := clampf(_tank_pressure, 0.0, 1.0)
	var r   := 18.0 * s

	var pc := Color(0.9, 0.35, 0.35) if pct < 0.2 else \
	          (Color(0.251, 0.659, 0.878) if pct > 0.3 else Color(1.0, 0.627, 0.251))

	draw_arc(Vector2(cx, cy), r, 0, TAU, 48, Color(0.039, 0.094, 0.157), 5.0 * s, true)
	if pct > 0.0:
		draw_arc(Vector2(cx, cy), r, -PI * 0.5, -PI * 0.5 + pct * TAU,
			max(2, int(48.0 * pct)), pc, 4.0 * s, true)
	draw_circle(Vector2(cx, cy), r - 3.0 * s, Color(0.020, 0.047, 0.094))

	var fs_b: int = max(6, int(8.0 * s))
	var fs_s: int = max(4, int(5.5 * s))
	draw_string(font, Vector2(cx - 12.0 * s, cy + float(fs_b) * 0.35 - 3.0 * s),
		"%d%%" % int(pct * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 24.0 * s, fs_b,
		Color(0.502, 0.847, 1.000))
	draw_string(font, Vector2(cx - 8.0 * s, cy + 8.0 * s),
		"PSI", HORIZONTAL_ALIGNMENT_CENTER, 16.0 * s, fs_s, Color(0.165, 0.314, 0.439))
