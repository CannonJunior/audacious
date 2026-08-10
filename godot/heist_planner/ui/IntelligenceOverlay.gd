class_name IntelligenceOverlay
extends Control
## Blueprint-style floor plan view with confidence-based fog of war.
## Confirmed areas render fully; probable at 70%; rumored at 30%; unknown as dark fog.
##
## Floor plan geometry is stored per-HeistTarget. When a target has no geometry
## authored, this panel renders a structured intel summary instead.

const BLUEPRINT_BG: Color = Color(0.051, 0.102, 0.180, 1.0)
const LINE_FULL:    Color = Color(0.90,  0.95,  1.00,  1.0)
const LINE_PROB:    Color = Color(0.90,  0.95,  1.00,  0.65)
const LINE_RUMOR:   Color = Color(0.90,  0.95,  1.00,  0.30)
const LINE_UNKNOWN: Color = Color(0.30,  0.40,  0.50,  0.25)
const AMBER:        Color = Color(1.0,   0.420, 0.0,   1.0)
const TEXT_DIM:     Color = Color(0.55,  0.55,  0.60,  1.0)
const TEXT_MAIN:    Color = Color(0.85,  0.85,  0.88,  1.0)

# Authored floor plan data per target (Vector2 polygon arrays keyed by region_id).
# Populated when target geometry is created in the editor.
# Format: { region_id: StringName → { "poly": PackedVector2Array, "label": String,
#           "confidence": IntelEntry.Confidence } }
var _regions: Dictionary = {}

var _target: HeistTarget = null
var _draw_mode: bool = false  # true = actual geometry; false = text summary

@onready var _text_summary: VBoxContainer = %TextSummary

# ── Public ────────────────────────────────────────────────────────────────────

func load_target(target: HeistTarget) -> void:
	_target = target
	_regions.clear()
	_draw_mode = false

	# TODO: load floor plan geometry from target resource when authored
	# For now, always use text summary mode
	_text_summary.visible = true
	_populate_text_summary()
	queue_redraw()

## Register floor plan geometry for a target (called from content authoring tools).
func register_geometry(target_id: StringName, regions: Dictionary) -> void:
	if _target and _target.target_id == target_id:
		_regions = regions
		_draw_mode = not regions.is_empty()
		_text_summary.visible = not _draw_mode
		queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _draw_mode:
		return

	draw_rect(Rect2(Vector2.ZERO, size), BLUEPRINT_BG)

	for region_id: StringName in _regions.keys():
		var region: Dictionary = _regions[region_id]
		var poly: PackedVector2Array = region.get("poly", PackedVector2Array())
		if poly.size() < 3:
			continue
		var confidence: IntelEntry.Confidence = region.get("confidence", IntelEntry.Confidence.UNKNOWN)
		var line_color := _confidence_line_color(confidence)
		draw_polygon(poly, PackedColorArray([Color(line_color, 0.08)]))
		for i: int in range(poly.size()):
			draw_line(poly[i], poly[(i + 1) % poly.size()], line_color, 1.0)

		if region.has("label") and confidence >= IntelEntry.Confidence.PROBABLE:
			var center := Vector2.ZERO
			for pt: Vector2 in poly:
				center += pt
			center /= poly.size()
			draw_string(ThemeDB.fallback_font, center, region.label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 9, line_color)

# ── Text summary (fallback when no geometry) ──────────────────────────────────

func _populate_text_summary() -> void:
	for child in _text_summary.get_children():
		child.queue_free()
	if not _target:
		return

	# Group intel by a rough spatial category
	var entry_groups: Dictionary = {
		"ENTRY POINTS": [],
		"INTERIOR":     [],
		"SECURITY":     [],
		"OBJECTIVE":    [],
	}

	for entry: IntelEntry in _target.intel_entries:
		var key := "INTERIOR"
		if "entry" in entry.field_id or "access" in entry.field_id or "door" in entry.field_id:
			key = "ENTRY POINTS"
		elif "guard" in entry.field_id or "camera" in entry.field_id or "alarm" in entry.field_id or "security" in entry.field_id:
			key = "SECURITY"
		elif "objective" in entry.field_id or "target" in entry.field_id or "storage" in entry.field_id:
			key = "OBJECTIVE"
		entry_groups[key].append(entry)

	for group_name: String in entry_groups.keys():
		var entries: Array = entry_groups[group_name]
		if entries.is_empty():
			continue

		var group_lbl := Label.new()
		group_lbl.text = group_name
		group_lbl.add_theme_font_size_override("font_size", 9)
		group_lbl.add_theme_color_override("font_color", AMBER)
		_text_summary.add_child(group_lbl)

		for entry: IntelEntry in entries:
			_text_summary.add_child(_make_intel_line(entry))

		var sep := HSeparator.new()
		sep.add_theme_color_override("color", Color(0.18, 0.18, 0.22, 1.0))
		_text_summary.add_child(sep)

func _make_intel_line(entry: IntelEntry) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 6 }

	var badge := Label.new()
	badge.text = entry.confidence_label()
	badge.custom_minimum_size = Vector2(80, 0)
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", _confidence_text_color(entry.confidence))
	row.add_child(badge)

	var content := Label.new()
	content.text = entry.content if entry.confidence != IntelEntry.Confidence.UNKNOWN else "No data"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_font_size_override("font_size", 10)
	content.add_theme_color_override("font_color", TEXT_MAIN if entry.confidence >= IntelEntry.Confidence.PROBABLE else TEXT_DIM)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(content)

	return row

# ── Helpers ───────────────────────────────────────────────────────────────────

func _confidence_line_color(conf: IntelEntry.Confidence) -> Color:
	match conf:
		IntelEntry.Confidence.CONFIRMED: return LINE_FULL
		IntelEntry.Confidence.PROBABLE:  return LINE_PROB
		IntelEntry.Confidence.RUMORED:   return LINE_RUMOR
	return LINE_UNKNOWN

func _confidence_text_color(conf: IntelEntry.Confidence) -> Color:
	match conf:
		IntelEntry.Confidence.CONFIRMED: return Color(0.15, 1.0,  0.30, 1.0)
		IntelEntry.Confidence.PROBABLE:  return Color(0.90, 0.70, 0.10, 1.0)
		IntelEntry.Confidence.RUMORED:   return Color(0.70, 0.50, 0.10, 1.0)
	return Color(0.40, 0.40, 0.44, 1.0)
