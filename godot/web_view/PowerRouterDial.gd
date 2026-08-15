extends Control
## Hex-ring power allocation display.
## Ports power_router.html canvas directly to Godot _draw().
## 6 inner hexes + 12 outer hexes arranged in two concentric rings.
## Drive by calling update_state(modules, capacity).

# Category colors matching power_router.html CAT_COLOR
const CAT_COLORS := {
	"weapon":  Color(1.000, 0.627, 0.000),
	"stealth": Color(0.667, 0.000, 1.000),
	"defense": Color(0.000, 1.000, 0.800),
	"sensor":  Color(0.000, 0.800, 0.267),
	"support": Color(0.502, 0.502, 0.565),
}

const INNER_N := 6
const OUTER_N := 12

signal routes_changed(routes: Dictionary)

var _modules:    Array = []
var _capacity:   float = 100.0
var _total:      float = 0.0
var _hover_idx:  int   = -1
var _drag_idx:   int   = -1

func _ready() -> void:
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)

func update_state(modules: Array, capacity: float) -> void:
	if _drag_idx >= 0:
		return
	_modules  = modules.duplicate(true)
	_capacity = capacity
	_total    = 0.0
	for m in _modules:
		_total += float(m.get("allocated", 0.0)) * float(m.get("base_draw", 0.0))
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
	var s: float  = minf(size.x / 560.0, size.y / 520.0)
	var ox: float = (size.x - 560.0 * s) * 0.5
	var oy: float = (size.y - 520.0 * s) * 0.5
	return {"s": s, "cx": ox + 280.0 * s, "cy": oy + 268.0 * s, "hex_r": 38.0 * s}

func _hit_hex(local: Vector2) -> int:
	var L      := _layout()
	var s: float     = L["s"]
	var cx: float    = L["cx"]
	var cy: float    = L["cy"]
	var hex_r: float = L["hex_r"]
	for i in range(_modules.size()):
		if local.distance_to(_hex_center(i, cx, cy, s)) <= hex_r:
			return i
	return -1

func _arc_frac(local: Vector2, idx: int) -> float:
	const ARC_START := -PI * 1.1
	var L      := _layout()
	var s: float  = L["s"]
	var cx: float = L["cx"]
	var cy: float = L["cy"]
	var hc    := _hex_center(idx, cx, cy, s)
	var angle := atan2(local.y - hc.y, local.x - hc.x)
	var rel: float = fmod(angle - ARC_START + TAU * 10.0, TAU)
	return clampf(rel / TAU, 0.0, 1.0)

func _apply_mouse(local: Vector2) -> void:
	if _drag_idx < 0 or _drag_idx >= _modules.size():
		return
	(_modules[_drag_idx] as Dictionary)["allocated"] = _arc_frac(local, _drag_idx)
	_total = 0.0
	for m in _modules:
		_total += float(m.get("allocated", 0.0)) * float(m.get("base_draw", 0.0))

func _emit_routes() -> void:
	var routes := {}
	for m in _modules:
		var id = (m as Dictionary).get("id", "")
		if id != "":
			routes[id] = (m as Dictionary).get("allocated", 0.0)
	routes_changed.emit(routes)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _hex_pts(cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var a := PI / 6.0 + (PI / 3.0) * float(i)  # flat-top
		pts.append(Vector2(cx + r * cos(a), cy + r * sin(a)))
	return pts

func _hex_center(i: int, cx: float, cy: float, s: float) -> Vector2:
	var outer := i >= INNER_N
	var idx: float = float(i - INNER_N if outer else i)
	var n: float   = float(OUTER_N if outer else INNER_N)
	var r: float   = (200.0 if outer else 112.0) * s
	var a     := -PI / 2.0 + (TAU / n) * idx
	return Vector2(cx + r * cos(a), cy + r * sin(a))

func _fill(pts: PackedVector2Array, c: Color) -> void:
	var clrs := PackedColorArray()
	clrs.resize(pts.size())
	clrs.fill(c)
	draw_polygon(pts, clrs)

# ── Draw ──────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _modules.is_empty():
		return
	var font  := ThemeDB.fallback_font
	var s     := minf(size.x / 560.0, size.y / 520.0)
	var ox    := (size.x - 560.0 * s) * 0.5
	var oy    := (size.y - 520.0 * s) * 0.5
	var cx    := ox + 280.0 * s
	var cy    := oy + 268.0 * s
	var hex_r := 38.0 * s

	# Faint ring guides
	for r_base: float in [112.0, 200.0]:
		draw_arc(Vector2(cx, cy), r_base * s, 0, TAU, 80,
			Color(0.067, 0.067, 0.133), 0.8, true)

	# Hexes + spokes + arcs
	for i in range(_modules.size()):
		_draw_hex(i, cx, cy, s, hex_r, font, i == _hover_idx or i == _drag_idx)

	# Central load gauge
	_draw_core(cx, cy, s, font)


func _draw_hex(i: int, cx: float, cy: float, s: float, hex_r: float, font: Font, hov: bool = false) -> void:
	var m     := _modules[i] as Dictionary
	var hc    := _hex_center(i, cx, cy, s)
	var color := CAT_COLORS.get(m.get("category", "support"), CAT_COLORS["support"]) as Color
	var alloc := float(m.get("allocated", 0.0))  # 0–1 fraction of module's rated draw
	var frac  := clampf(alloc, 0.0, 1.0)
	var base_d := float(m.get("base_draw", 0.0))
	var min_d_w := float(m.get("min_draw", 0.0))
	var active := (alloc * base_d) >= min_d_w and alloc > 0.0

	# Spoke from center (only when allocated)
	if alloc > 0.0:
		draw_line(Vector2(cx, cy), hc,
			Color(color.r, color.g, color.b, 0.25 + frac * 0.3), 1.0 + frac * 3.0, true)

	# Hex fill
	var pts := _hex_pts(hc.x, hc.y, hex_r - 1.0)
	if active:
		_fill(pts, Color(color.r, color.g, color.b, 0.08 + frac * 0.18))
	else:
		_fill(pts, Color(0.047, 0.047, 0.094))

	# Hex border
	var b_pts := pts.duplicate()
	b_pts.append(pts[0])
	var border_a: float = 1.0 if (hov or active) else 0.18
	var border_w: float = 2.0 if hov else 1.0
	draw_polyline(b_pts, Color(color.r, color.g, color.b, border_a), border_w, true)

	# Outer glow when active
	if active:
		draw_arc(hc, hex_r + 3.0 * s, 0, TAU, 32,
			Color(color.r, color.g, color.b, 0.13), 3.0 * s, true)

	# Arc slider around hex
	var arc_r     := hex_r + 8.0 * s
	var arc_start := -PI * 1.1
	# Dark full-circle track
	draw_arc(hc, arc_r, 0, TAU, 64, Color(0.118, 0.118, 0.188), 3.0 * s, true)
	# Colored fill up to allocation point
	if alloc > 0.0:
		var arc_end: float = arc_start + frac * TAU
		var n_pts: int = max(2, int(64.0 * frac))
		draw_arc(hc, arc_r, arc_start, arc_end, n_pts, color, 3.0 * s, true)
		# Handle dot
		draw_circle(hc + Vector2(cos(arc_end), sin(arc_end)) * arc_r, 4.0 * s, color)
	# Min-draw threshold tick
	if min_d_w > 0.0 and base_d > 0.0:
		var min_frac := clampf(min_d_w / base_d, 0.0, 1.0)
		var min_a    := arc_start + min_frac * TAU
		var ti       := hc + Vector2(cos(min_a), sin(min_a)) * (arc_r - 5.0 * s)
		var to_      := hc + Vector2(cos(min_a), sin(min_a)) * (arc_r + 5.0 * s)
		draw_line(ti, to_, Color(0.9, 0.2, 0.2, 0.75), 1.5, true)

	# Label (split at first space → two lines like the HTML \n labels)
	var label := m.get("label", "?") as String
	var sp    := label.find(" ")
	var line1: String = label.substr(0, sp) if sp >= 0 else label
	var line2: String = label.substr(sp + 1) if sp >= 0 else ""
	var fs: int = max(6, int(8.0 * s))
	var lw    := hex_r * 1.7
	var lx    := hc.x - lw * 0.5
	var tc    := Color(color.r, color.g, color.b, 1.0) if active else \
	             Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 1.0)
	if line2.is_empty():
		draw_string(font, Vector2(lx, hc.y + float(fs) * 0.45), line1,
			HORIZONTAL_ALIGNMENT_CENTER, lw, fs, tc)
	else:
		draw_string(font, Vector2(lx, hc.y - float(fs) * 0.3), line1,
			HORIZONTAL_ALIGNMENT_CENTER, lw, fs, tc)
		draw_string(font, Vector2(lx, hc.y + float(fs) * 1.1), line2,
			HORIZONTAL_ALIGNMENT_CENTER, lw, fs, tc)

	# Allocation % below label when active
	if alloc > 0.0:
		var pct_c := Color(color.r, color.g, color.b, 1.0) if active else Color(0.9, 0.2, 0.2, 1.0)
		draw_string(font, Vector2(hc.x - 14.0, hc.y + hex_r * 0.48),
			"%d%%" % int(frac * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 28.0, fs, pct_c)


func _draw_core(cx: float, cy: float, s: float, font: Font) -> void:
	var use_ratio := clampf(_total / maxf(_capacity, 1.0), 0.0, 1.0)
	var over      := _total > _capacity
	var r         := 46.0 * s

	# Background ring stroke
	draw_arc(Vector2(cx, cy), r, 0, TAU, 64, Color(0.102, 0.102, 0.157), 8.0 * s, true)

	# Load fill arc
	var fill_c := Color(0.9, 0.2, 0.2) if over else \
	              (Color(1.0, 0.627, 0.0) if use_ratio > 0.8 else Color(0.0, 1.0, 0.8))
	if use_ratio > 0.0:
		draw_arc(Vector2(cx, cy), r, -PI * 0.5, -PI * 0.5 + use_ratio * TAU,
			max(2, int(64 * use_ratio)), fill_c, 6.0 * s, true)

	# Inner fill (hide arc ends)
	draw_circle(Vector2(cx, cy), r - 5.0 * s, Color(0.027, 0.027, 0.055))

	# Overload pulse ring
	if over:
		draw_arc(Vector2(cx, cy), r + 4.0 * s, 0, TAU, 64,
			Color(0.9, 0.2, 0.2, 0.35), 2.0 * s, true)

	# Center text
	var fs_big: int = max(10, int(14.0 * s))
	var fs_sml: int = max(6,  int(8.0  * s))
	var pct_s  := "%d%%" % int(use_ratio * 100.0)
	var tc     := Color(0.9, 0.2, 0.2) if over else Color(0.847, 0.847, 0.878)
	var tw     := float(fs_big) * float(len(pct_s)) * 0.65
	draw_string(font, Vector2(cx - tw * 0.5, cy + float(fs_big) * 0.35 - 6.0 * s),
		pct_s, HORIZONTAL_ALIGNMENT_CENTER, tw + 8.0, fs_big, tc)
	draw_string(font, Vector2(cx - 16.0 * s, cy + 12.0 * s),
		"LOAD", HORIZONTAL_ALIGNMENT_CENTER, 32.0 * s, fs_sml, Color(0.376, 0.376, 0.502))
