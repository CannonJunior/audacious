extends Control
## Graphical attitude gyro — direct port of fire_and_ice attitude_gyro.dart.
## Drive it by calling update_attitude(pitch_deg, bank_deg) each frame.
## pitch > 0 = nose up.  bank > 0 = roll left (strafe-lean convention).

const C_SKY    := Color(0.024, 0.059, 0.110)   # #060F1C
const C_GROUND := Color(0.106, 0.047, 0.0)     # #1B0C00
const C_HZ     := Color(0.867, 0.867, 0.867)   # #DDDDDD
const C_LADDER := Color(0.333, 0.467, 0.667)   # #5577AA
const C_WINGS  := Color(1.0,   0.667, 0.0)     # #FFAA00
const C_ARC    := Color(0.227, 0.290, 0.345)   # #3A4A58

# Geometry — matches gyro.html canvas exactly (240×185 px)
const PIX_PER_DEG := 4.2
const ARC_R       := 80.0
const WING_OUT    := 70.0
const WING_IN     := 16.0
const WING_DROP   := 11.0
const HW_MAJOR    := 52.0   # half-width of ±20° pitch lines
const HW_MINOR    := 34.0   # half-width of ±10°, ±30° pitch lines
const DOT_R       :=  4.0

var pitch: float = 0.0
var bank:  float = 0.0

func _ready() -> void:
	# Clip draw() output to this control's rect so the sky/ground fills don't bleed out.
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)

func update_attitude(p: float, b: float) -> void:
	pitch = p
	bank  = b
	queue_redraw()

func _draw() -> void:
	var cx := size.x / 2.0
	var cy := size.y / 2.0
	var pitch_px := pitch * PIX_PER_DEG
	var bank_rad := deg_to_rad(bank)

	# ── Rotating ball (sky / ground / pitch ladder) ───────────────────────────
	# Transform: rotate -bank_rad around (cx, cy+pitch_px) — same as the Dart
	# canvas.translate(cx, cy+pitchPx); canvas.rotate(-bankRad).
	draw_set_transform_matrix(Transform2D(-bank_rad, Vector2(cx, cy + pitch_px)))

	var fill := maxf(size.x, size.y) * 4.0
	draw_rect(Rect2(-fill, -fill, fill * 2.0, fill), C_SKY)
	draw_rect(Rect2(-fill, 0.0,   fill * 2.0, fill), C_GROUND)
	draw_line(Vector2(-fill, 0.0), Vector2(fill, 0.0), C_HZ, 1.5)

	for d in range(-30, 31, 10):
		if d == 0:
			continue
		var y  := float(-d) * PIX_PER_DEG
		var hw := HW_MAJOR if abs(d) == 20 else HW_MINOR
		draw_line(Vector2(-hw, y), Vector2(-5.0, y), C_LADDER, 1.0)
		draw_line(Vector2( 5.0, y), Vector2( hw, y), C_LADDER, 1.0)
		var tick := 4.0 if d > 0 else -4.0
		draw_line(Vector2(-hw, y), Vector2(-hw, y + tick), C_LADDER, 1.0)
		draw_line(Vector2( hw, y), Vector2( hw, y + tick), C_LADDER, 1.0)

	draw_set_transform_matrix(Transform2D.IDENTITY)

	# ── Fixed aircraft reference wings ────────────────────────────────────────
	draw_line(Vector2(cx - WING_OUT, cy), Vector2(cx - WING_IN, cy), C_WINGS, 2.2)
	draw_line(Vector2(cx - WING_IN,  cy), Vector2(cx - WING_IN, cy + WING_DROP), C_WINGS, 2.2)
	draw_line(Vector2(cx + WING_IN,  cy), Vector2(cx + WING_OUT, cy), C_WINGS, 2.2)
	draw_line(Vector2(cx + WING_IN,  cy), Vector2(cx + WING_IN, cy + WING_DROP), C_WINGS, 2.2)
	draw_circle(Vector2(cx, cy), DOT_R, C_WINGS)

	# ── Bank arc ──────────────────────────────────────────────────────────────
	# Flutter drawArc(startAngle=-PI*0.85, sweepAngle=PI*0.7) →
	# Godot draw_arc(start=-PI*0.85, end=-PI*0.15).
	draw_arc(Vector2(cx, cy), ARC_R, -PI * 0.85, -PI * 0.15, 64, C_ARC, 0.75)

	for d in [-60, -45, -30, -20, -10, 10, 20, 30, 45, 60]:
		var a     := -PI / 2.0 + deg_to_rad(float(d))
		var major: bool = abs(int(d)) % 30 == 0
		var inner := ARC_R - (14.0 if major else 8.0)
		draw_line(
			Vector2(cx + cos(a) * inner, cy + sin(a) * inner),
			Vector2(cx + cos(a) * ARC_R,  cy + sin(a) * ARC_R),
			C_ARC, 1.0 if major else 0.5
		)

	# ── Bank pointer triangle ──────────────────────────────────────────────────
	var pa   := -PI / 2.0 + bank_rad
	var tip  := Vector2(cx + cos(pa) * (ARC_R - 2.0), cy + sin(pa) * (ARC_R - 2.0))
	var perp := pa + PI / 2.0
	var back := pa + PI
	draw_colored_polygon(PackedVector2Array([
		tip,
		Vector2(tip.x + cos(perp) * 7.0 + cos(back) * 14.0,
		        tip.y + sin(perp) * 7.0 + sin(back) * 14.0),
		Vector2(tip.x - cos(perp) * 7.0 + cos(back) * 14.0,
		        tip.y - sin(perp) * 7.0 + sin(back) * 14.0),
	]), C_WINGS)
