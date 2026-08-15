extends Control
## Gas manifold diagram display.
## Ports gas_router.html canvas directly to Godot _draw().
## Vertical manifold pipe with valve nodes branching left/right/below.
## Drive by calling update_state(modules, tank_pressure).

const CAT_COLORS := {
	"directional": Color(0.251, 0.659, 0.878),  # #40a8e0 blue
	"attitude":    Color(0.000, 0.831, 0.667),  # #00d4aa teal
	"maneuver":    Color(1.000, 0.627, 0.251),  # #ffa040 orange
	"environ":     Color(0.439, 0.784, 0.439),  # #70c870 green
}

# Reference canvas size matching gas_router.html
const REF_W := 540.0
const REF_H := 510.0

# Valve positions from VALVE_POSITIONS in gas_router.html
const VALVE_POS: Array[Vector2] = [
	Vector2(100, 150), Vector2(100, 220), Vector2(100, 290), Vector2(100, 360),  # directional
	Vector2(440, 150), Vector2(440, 220), Vector2(440, 290), Vector2(440, 360),  # attitude
	Vector2( 90, 445), Vector2(160, 470), Vector2(230, 488),                      # maneuver
	Vector2(380, 470), Vector2(450, 445),                                          # environ
]

const MANIFOLD_X      := 270.0
const MANIFOLD_TOP    :=  90.0
const MANIFOLD_BOTTOM := 440.0
const VALVE_R         :=  28.0  # valve body radius (VALVE_HIT_R - 4)

signal routes_changed(routes: Dictionary)

var _modules:          Array = []
var _tank_pressure:    float = 1.0
var _hover_idx:        int   = -1
var _drag_idx:         int   = -1
var _drag_start_y:     float = 0.0
var _drag_start_alloc: float = 0.0

func _ready() -> void:
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)

func update_state(modules: Array, tank_pressure: float) -> void:
	if _drag_idx >= 0:
		return
	_modules       = modules.duplicate(true)
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
			var idx := _hit_valve(event.position)
			if idx >= 0:
				if event.double_click:
					_toggle_valve(idx)
					_emit_routes()
					queue_redraw()
				else:
					_drag_idx = idx
					_drag_start_y = event.position.y
					_drag_start_alloc = float((_modules[idx] as Dictionary).get("allocated", 0.0))
				get_viewport().set_input_as_handled()
		else:
			if _drag_idx >= 0:
				_emit_routes()
				_drag_idx = -1
				queue_redraw()
	elif event is InputEventMouseMotion:
		var prev_hover := _hover_idx
		if _drag_idx >= 0:
			_apply_drag(event.position.y)
			queue_redraw()
			get_viewport().set_input_as_handled()
		else:
			_hover_idx = _hit_valve(event.position)
			if _hover_idx != prev_hover:
				queue_redraw()

func _gas_layout() -> Dictionary:
	var s: float  = minf(size.x / REF_W, size.y / REF_H)
	var ox: float = (size.x - REF_W * s) * 0.5
	var oy: float = (size.y - REF_H * s) * 0.5
	return {"s": s, "ox": ox, "oy": oy}

func _hit_valve(local: Vector2) -> int:
	var L      := _gas_layout()
	var s: float  = L["s"]
	var ox: float = L["ox"]
	var oy: float = L["oy"]
	var vr := VALVE_R * s
	for i in range(mini(_modules.size(), VALVE_POS.size())):
		var vp := _p(ox, oy, s, VALVE_POS[i].x, VALVE_POS[i].y)
		if local.distance_to(vp) <= vr:
			return i
	return -1

func _apply_drag(current_y: float) -> void:
	if _drag_idx < 0 or _drag_idx >= _modules.size():
		return
	var delta := (_drag_start_y - current_y) / 100.0
	var new_alloc := snappedf(clampf(_drag_start_alloc + delta, 0.0, 1.0), 0.05)
	(_modules[_drag_idx] as Dictionary)["allocated"] = new_alloc

func _toggle_valve(idx: int) -> void:
	if idx < 0 or idx >= _modules.size():
		return
	var m := _modules[idx] as Dictionary
	if float(m.get("allocated", 0.0)) > 0.0:
		m["allocated"] = 0.0
	else:
		m["allocated"] = float(m.get("flow_rate", 1.0))

func _emit_routes() -> void:
	var routes := {}
	for m in _modules:
		var id = (m as Dictionary).get("id", "")
		if id != "":
			routes[id] = (m as Dictionary).get("allocated", 0.0)
	routes_changed.emit(routes)

# ── Draw ──────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _modules.is_empty():
		return
	var font := ThemeDB.fallback_font
	var s    := minf(size.x / REF_W, size.y / REF_H)
	var ox   := (size.x - REF_W * s) * 0.5
	var oy   := (size.y - REF_H * s) * 0.5

	_draw_grid(ox, oy, s)
	_draw_pipes(ox, oy, s)
	_draw_group_labels(ox, oy, s, font)
	for i in range(_modules.size()):
		_draw_valve(i, ox, oy, s, font, i == _hover_idx or i == _drag_idx)
	_draw_pressure_core(ox, oy, s, font)


func _p(ox: float, oy: float, s: float, x: float, y: float) -> Vector2:
	return Vector2(ox + x * s, oy + y * s)


func _draw_grid(ox: float, oy: float, s: float) -> void:
	var step := 20.0 * s
	var gc   := Color(0.039, 0.094, 0.157, 1.0)
	var x    := ox
	while x < ox + REF_W * s:
		draw_line(Vector2(x, oy), Vector2(x, oy + REF_H * s), gc, 0.5)
		x += step
	var y := oy
	while y < oy + REF_H * s:
		draw_line(Vector2(ox, y), Vector2(ox + REF_W * s, y), gc, 0.5)
		y += step


func _draw_pipes(ox: float, oy: float, s: float) -> void:
	var mx_top := _p(ox, oy, s, MANIFOLD_X, MANIFOLD_TOP)
	var mx_bot := _p(ox, oy, s, MANIFOLD_X, MANIFOLD_BOTTOM)

	# Main manifold — outer dark pipe
	draw_line(mx_top, mx_bot, Color(0.102, 0.227, 0.353), 10.0 * s, true)
	# Inner highlight
	draw_line(
		Vector2(mx_top.x, mx_top.y + 6.0 * s),
		Vector2(mx_bot.x, mx_bot.y - 6.0 * s),
		Color(0.165, 0.314, 0.439), 4.0 * s, true)

	# Branch pipes: manifold → each valve
	for i in range(_modules.size()):
		if i >= VALVE_POS.size():
			continue
		var m      := _modules[i] as Dictionary
		var color  := CAT_COLORS.get(m.get("category", "directional"), CAT_COLORS["directional"]) as Color
		var alloc  := float(m.get("allocated", 0.0))
		var min_f  := float(m.get("min_flow", 0.0))
		var active := alloc >= min_f and alloc > 0.0
		var vp     := VALVE_POS[i]
		var conn_y := clampf(vp.y, MANIFOLD_TOP, MANIFOLD_BOTTOM)
		var from_  := _p(ox, oy, s, MANIFOLD_X, conn_y)
		var to_    := _p(ox, oy, s, vp.x, vp.y)

		if active:
			draw_line(from_, to_, Color(color.r, color.g, color.b, 0.38), 3.0 * s, true)
		else:
			draw_dashed_line(from_, to_, Color(0.051, 0.118, 0.188), 2.0 * s, 8.0 * s, true, true)


func _draw_group_labels(ox: float, oy: float, s: float, font: Font) -> void:
	var fs: int = max(6, int(9.0 * s))
	var labels := [
		{ "text": "◀ DIRECTIONAL", "x":  80.0, "y": 108.0, "cat": "directional" },
		{ "text": "ATTITUDE ▶",    "x": 460.0, "y": 108.0, "cat": "attitude"    },
		{ "text": "◀ MANEUVER",    "x":  60.0, "y": 418.0, "cat": "maneuver"    },
		{ "text": "ENVIRON ▶",     "x": 460.0, "y": 418.0, "cat": "environ"     },
	]
	for lbl in labels:
		var color := CAT_COLORS.get(lbl["cat"], Color(0.5, 0.5, 0.5)) as Color
		var lp    := _p(ox, oy, s, float(lbl["x"]), float(lbl["y"]))
		var lw    := 110.0 * s
		draw_string(font, Vector2(lp.x - lw * 0.5, lp.y + float(fs) * 0.35),
			lbl["text"] as String, HORIZONTAL_ALIGNMENT_CENTER, lw, fs,
			Color(color.r, color.g, color.b, 0.55))


func _draw_valve(i: int, ox: float, oy: float, s: float, font: Font, hov: bool = false) -> void:
	if i >= VALVE_POS.size() or i >= _modules.size():
		return
	var m      := _modules[i] as Dictionary
	var color  := CAT_COLORS.get(m.get("category", "directional"), CAT_COLORS["directional"]) as Color
	var alloc  := float(m.get("allocated", 0.0))
	var min_f  := float(m.get("min_flow", 0.0))
	var frac   := clampf(alloc, 0.0, 1.0)  # alloc is already 0–1 throttle fraction
	var active := alloc >= min_f and alloc > 0.0
	var vp     := _p(ox, oy, s, VALVE_POS[i].x, VALVE_POS[i].y)
	var vr     := VALVE_R * s

	# Valve body
	draw_circle(vp, vr, Color(0.039, 0.078, 0.094) if active else Color(0.024, 0.051, 0.094))
	var border_a: float = 1.0 if (hov or active) else 0.22
	var border_w: float = 2.5 * s if hov else 1.5 * s
	draw_arc(vp, vr, 0, TAU, 32, Color(color.r, color.g, color.b, border_a), border_w, true)

	# Inner fill proportional to allocation
	if active and frac > 0.0:
		draw_circle(vp, vr * frac * 0.8, Color(color.r, color.g, color.b, 0.2))

	# T-bar handle: vertical when closed (alloc=0), horizontal when fully open (alloc=rate)
	# handle_angle: -PI/2 (up/closed) → 0 (right/open) as frac goes 0→1
	var handle_a := -PI / 2.0 + frac * (PI / 2.0)
	var hl       := 14.0 * s
	var shaft_end := vp + Vector2(cos(handle_a), sin(handle_a)) * hl
	var hclr      := color if active else Color(0.165, 0.251, 0.376)
	draw_line(vp, shaft_end, hclr, 3.0 * s, true)
	# Crossbar
	var perp := handle_a + PI / 2.0
	var bl   := 8.0 * s
	draw_line(
		shaft_end - Vector2(cos(perp), sin(perp)) * bl,
		shaft_end + Vector2(cos(perp), sin(perp)) * bl,
		hclr, 3.0 * s, true)

	# Label below valve
	var label  := m.get("label", "?") as String
	var sp     := label.find(" ")
	var line1: String = label.substr(0, sp) if sp >= 0 else label
	var line2: String = label.substr(sp + 1) if sp >= 0 else ""
	var fs: int = max(5, int(7.0 * s))
	var lw      := 68.0 * s
	var lx      := vp.x - lw * 0.5
	var ly_base := vp.y + vr + 4.0 * s + float(fs)
	var tc     := Color(color.r, color.g, color.b, 1.0) if active else Color(0.165, 0.251, 0.376)
	draw_string(font, Vector2(lx, ly_base), line1, HORIZONTAL_ALIGNMENT_CENTER, lw, fs, tc)
	if not line2.is_empty():
		draw_string(font, Vector2(lx, ly_base + float(fs) * 1.2), line2,
			HORIZONTAL_ALIGNMENT_CENTER, lw, fs, tc)

	# Allocation % above valve
	if alloc > 0.0:
		var pct_c := Color(color.r, color.g, color.b, 1.0) if active else Color(0.9, 0.35, 0.35)
		draw_string(font, Vector2(vp.x - 14.0 * s, vp.y - vr - 4.0 * s),
			"%d%%" % int(frac * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 28.0 * s, fs, pct_c)


func _draw_pressure_core(ox: float, oy: float, s: float, font: Font) -> void:
	# Positioned at top of manifold (above the pipe, matching the HTML's CY = MANIFOLD_TOP - 32)
	var cx := ox + MANIFOLD_X * s
	var cy := oy + (MANIFOLD_TOP - 32.0) * s
	var r  := 28.0 * s

	var pct  := clampf(_tank_pressure, 0.0, 1.0)
	var over := false  # could check if total flow > tank_pressure
	var pc   := Color(0.9, 0.35, 0.35) if over else \
	            (Color(0.251, 0.659, 0.878) if pct > 0.3 else Color(1.0, 0.627, 0.251))

	# Background ring
	draw_arc(Vector2(cx, cy), r, 0, TAU, 48, Color(0.051, 0.118, 0.188), 8.0 * s, true)
	# Tank level arc
	draw_arc(Vector2(cx, cy), r, -PI * 0.5, -PI * 0.5 + pct * TAU,
		max(2, int(48 * pct)), pc, 6.0 * s, true)
	# Center fill
	draw_circle(Vector2(cx, cy), r - 5.0 * s, Color(0.031, 0.063, 0.118))

	# Percentage text
	var fs_b: int = max(8, int(11.0 * s))
	var fs_s: int = max(5, int(7.0  * s))
	draw_string(font, Vector2(cx - 16.0 * s, cy + float(fs_b) * 0.35 - 4.0 * s),
		"%d%%" % int(pct * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 32.0 * s, fs_b,
		Color(0.502, 0.847, 1.000))
	draw_string(font, Vector2(cx - 10.0 * s, cy + 10.0 * s),
		"PSI", HORIZONTAL_ALIGNMENT_CENTER, 20.0 * s, fs_s, Color(0.165, 0.314, 0.439))

	# "TANK" label below core
	draw_string(font, Vector2(cx - 16.0 * s, cy + r + 10.0 * s),
		"TANK", HORIZONTAL_ALIGNMENT_CENTER, 32.0 * s, fs_s, Color(0.165, 0.314, 0.439))
