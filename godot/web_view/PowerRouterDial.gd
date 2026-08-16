extends Control
## Power bus display — category-level allocation routing.
## 5 category hexes tiled in a honeycomb cluster around the central load gauge.
## Arc gauge is drawn INSIDE each hex; drag anywhere on the hex to set allocation.
## Drive by calling update_state(categories, capacity).

const CAT_COLORS := {
	"weapon":  Color(1.000, 0.627, 0.000),
	"stealth": Color(0.667, 0.000, 1.000),
	"defense": Color(0.000, 1.000, 0.800),
	"sensor":  Color(0.000, 0.800, 0.267),
	"support": Color(0.502, 0.502, 0.565),
}

const HEX_R := 52.0   ## reference-pixel hex circumradius

## Tiled positions: 5 of the 6 pointy-top hex-grid neighbors at sqrt(3)*HEX_R
## from center. Order matches PowerRouter.CATEGORIES: weapon, stealth, defense,
## sensor, support. Gap is at the lower-left position.
const CAT_OFFSETS: Array[Vector2] = [
	Vector2(-45.0, -78.0),   # weapon  — upper-left
	Vector2( 45.0, -78.0),   # stealth — upper-right
	Vector2(-90.0,   0.0),   # defense — left
	Vector2( 90.0,   0.0),   # sensor  — right
	Vector2( 45.0,  78.0),   # support — lower-right
]

signal routes_changed(routes: Dictionary)

var _categories: Array = []
var _capacity:   float = 100.0
var _total:      float = 0.0
var _hover_idx:  int   = -1
var _drag_idx:   int   = -1


func _ready() -> void:
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)


func update_state(categories: Array, capacity: float) -> void:
	if _drag_idx >= 0:
		return
	_categories = categories.duplicate(true)
	_capacity   = capacity
	_total      = 0.0
	for c in _categories:
		_total += float(c.get("allocated", 0.0)) * capacity
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
	var s: float  = minf(size.x / 328.0, size.y / 304.0)
	var ox: float = (size.x - 328.0 * s) * 0.5
	var oy: float = (size.y - 304.0 * s) * 0.5
	return {"s": s, "cx": ox + 164.0 * s, "cy": oy + 152.0 * s}


func _hex_center(i: int, cx: float, cy: float, s: float) -> Vector2:
	var off := CAT_OFFSETS[i]
	return Vector2(cx + off.x * s, cy + off.y * s)


func _hit_hex(local: Vector2) -> int:
	var L      := _layout()
	var s: float  = L["s"]
	var cx: float = L["cx"]
	var cy: float = L["cy"]
	var hex_r := HEX_R * s
	for i in range(_categories.size()):
		if local.distance_to(_hex_center(i, cx, cy, s)) <= hex_r:
			return i
	return -1


func _arc_frac(local: Vector2, idx: int) -> float:
	# Arc starts at 12 o'clock (-PI/2) and fills clockwise.
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
	if _drag_idx < 0 or _drag_idx >= _categories.size():
		return
	(_categories[_drag_idx] as Dictionary)["allocated"] = _arc_frac(local, _drag_idx)
	_total = 0.0
	for c in _categories:
		_total += float(c.get("allocated", 0.0)) * _capacity


func _emit_routes() -> void:
	var routes := {}
	for c in _categories:
		var cat := (c as Dictionary).get("category", "") as String
		if cat != "":
			routes[cat] = (c as Dictionary).get("allocated", 0.0)
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
	if _categories.is_empty():
		return
	var font  := ThemeDB.fallback_font
	var L     := _layout()
	var s: float  = L["s"]
	var cx: float = L["cx"]
	var cy: float = L["cy"]
	var hex_r := HEX_R * s

	# Draw center core first (behind hexes)
	_draw_core(cx, cy, s, font)

	for i in range(_categories.size()):
		_draw_hex(i, cx, cy, s, hex_r, font, i == _hover_idx or i == _drag_idx)


func _draw_hex(i: int, cx: float, cy: float, s: float, hex_r: float, font: Font, hov: bool = false) -> void:
	var c     := _categories[i] as Dictionary
	var hc    := _hex_center(i, cx, cy, s)
	var color := CAT_COLORS.get(c.get("category", "support"), CAT_COLORS["support"]) as Color
	var alloc := float(c.get("allocated", 0.0))
	var frac  := clampf(alloc, 0.0, 1.0)

	var mods       := c.get("modules", []) as Array
	var any_active := false
	var active_count := 0
	for m in mods:
		if (m as Dictionary).get("active", false):
			any_active = true
			active_count += 1

	# ── Hex body ──────────────────────────────────────────────────────────────

	var pts := _hex_pts(hc.x, hc.y, hex_r - 1.0)
	_fill(pts, Color(color.r, color.g, color.b, 0.08 + frac * 0.16) if any_active \
	           else Color(0.047, 0.047, 0.094))

	var b_pts := pts.duplicate()
	b_pts.append(pts[0])
	var border_a: float = 1.0 if (hov or any_active) else 0.20
	var border_w: float = 2.0 if hov else 1.0
	draw_polyline(b_pts, Color(color.r, color.g, color.b, border_a), border_w, true)

	if hov:
		draw_arc(hc, hex_r + 2.0 * s, 0, TAU, 32,
			Color(color.r, color.g, color.b, 0.18), 1.5 * s, true)

	# ── Interior arc gauge ────────────────────────────────────────────────────
	# Positioned inside the hex at 0.68 × circumradius — well within the inradius.

	const ARC_START := -PI * 0.5   # 12 o'clock, fills clockwise
	var arc_r := hex_r * 0.68
	var arc_w := 3.5 * s

	# Dark full-circle track
	draw_arc(hc, arc_r, 0.0, TAU, 64, Color(0.08, 0.08, 0.14), arc_w, true)

	# Colored fill up to allocation
	if frac > 0.0:
		var arc_end: float = ARC_START + frac * TAU
		var n_pts: int     = max(2, int(64.0 * frac))
		draw_arc(hc, arc_r, ARC_START, arc_end, n_pts, color, arc_w, true)
		# Handle dot at end of fill
		draw_circle(hc + Vector2(cos(arc_end), sin(arc_end)) * arc_r, 3.0 * s, color)

	# ── Text inside the arc ring ───────────────────────────────────────────────

	var label := c.get("label", "") as String
	var fs: int    = max(6, int(8.0 * s))
	var fs_sm: int = max(5, int(6.5 * s))
	var lw    := arc_r * 1.7
	var lx    := hc.x - lw * 0.5
	var tc    := Color(color.r, color.g, color.b, 1.0) if any_active else \
	             Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)

	draw_string(font, Vector2(lx, hc.y - float(fs) * 0.1), label,
		HORIZONTAL_ALIGNMENT_CENTER, lw, fs, tc)

	if alloc > 0.0:
		var pct_c := Color(color.r, color.g, color.b, 0.85) if any_active \
		             else Color(0.85, 0.2, 0.2, 1.0)
		draw_string(font, Vector2(lx, hc.y + float(fs) * 1.15),
			"%d%%  %d/%d" % [int(frac * 100.0), active_count, mods.size()],
			HORIZONTAL_ALIGNMENT_CENTER, lw, fs_sm, pct_c)


func _draw_core(cx: float, cy: float, s: float, font: Font) -> void:
	# Smaller radius than before (36 vs 46) so tiled hexes don't overlap the gauge.
	var use_ratio := clampf(_total / maxf(_capacity, 1.0), 0.0, 1.0)
	var over      := _total > _capacity
	var r         := 36.0 * s

	draw_arc(Vector2(cx, cy), r, 0, TAU, 64, Color(0.102, 0.102, 0.157), 7.0 * s, true)

	var fill_c := Color(0.9, 0.2, 0.2) if over else \
	              (Color(1.0, 0.627, 0.0) if use_ratio > 0.8 else Color(0.0, 1.0, 0.8))
	if use_ratio > 0.0:
		draw_arc(Vector2(cx, cy), r, -PI * 0.5, -PI * 0.5 + use_ratio * TAU,
			max(2, int(64.0 * use_ratio)), fill_c, 5.0 * s, true)

	draw_circle(Vector2(cx, cy), r - 4.0 * s, Color(0.027, 0.027, 0.055))

	if over:
		draw_arc(Vector2(cx, cy), r + 3.0 * s, 0, TAU, 64,
			Color(0.9, 0.2, 0.2, 0.35), 1.5 * s, true)

	var fs_big: int = max(9,  int(12.0 * s))
	var fs_sml: int = max(5,  int(7.0  * s))
	var pct_s  := "%d%%" % int(use_ratio * 100.0)
	var tc     := Color(0.9, 0.2, 0.2) if over else Color(0.847, 0.847, 0.878)
	var tw     := float(fs_big) * float(len(pct_s)) * 0.65
	draw_string(font, Vector2(cx - tw * 0.5, cy + float(fs_big) * 0.35 - 5.0 * s),
		pct_s, HORIZONTAL_ALIGNMENT_CENTER, tw + 6.0, fs_big, tc)
	draw_string(font, Vector2(cx - 14.0 * s, cy + 10.0 * s),
		"LOAD", HORIZONTAL_ALIGNMENT_CENTER, 28.0 * s, fs_sml, Color(0.376, 0.376, 0.502))
