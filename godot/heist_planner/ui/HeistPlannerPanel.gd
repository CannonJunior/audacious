class_name HeistPlannerPanel
extends Control
## Main area panel. Shows the target dossier, available approaches, mission windows,
## and the risk assessment summary. Works for both main heists and sidequests.

const AMBER:       Color = Color(1.0,   0.420, 0.0,  1.0)
const BLUEPRINT:   Color = Color(0.051, 0.102, 0.180, 1.0)
const TEXT_MAIN:   Color = Color(0.85,  0.85,  0.88, 1.0)
const TEXT_DIM:    Color = Color(0.55,  0.55,  0.60, 1.0)
const CONFIRM_COL: Color = Color(0.15,  1.0,   0.30, 1.0)
const RUMOR_COL:   Color = Color(0.90,  0.70,  0.10, 1.0)
const UNKNOWN_COL: Color = Color(0.40,  0.40,  0.44, 1.0)
const RISK_HIGH:   Color = Color(1.0,   0.20,  0.08, 1.0)
const SIDEQUEST:   Color = Color(0.40,  0.65,  1.0,  1.0)

signal approach_confirmed(approach: ApproachOption)
signal recon_requested(target: HeistTarget)

@onready var _no_target_hint:     Control      = %NoTargetHint
@onready var _target_content:     Control      = %TargetContent
@onready var _target_name_lbl:    Label        = %TargetNameLabel
@onready var _sidequest_badge:    Label        = %SidequestBadge
@onready var _security_lbl:       Label        = %SecurityLabel
@onready var _heat_lbl:           Label        = %HeatLabel
@onready var _intel_list:         VBoxContainer = %IntelList
@onready var _approaches_list:    VBoxContainer = %ApproachesList
@onready var _windows_list:       VBoxContainer = %WindowsList
@onready var _risk_panel:         Control      = %RiskPanel
@onready var _intel_quality_bar:  ProgressBar  = %IntelQualityBar
@onready var _approach_conf_bar:  ProgressBar  = %ApproachConfBar
@onready var _window_conf_bar:    ProgressBar  = %WindowConfBar
@onready var _overall_risk_lbl:   Label        = %OverallRiskLabel
@onready var _recommendation_lbl: Label        = %RecommendationLabel
@onready var _btn_recon:          Button       = %BtnRecon
@onready var _btn_approach:       Button       = %BtnDesignApproach
@onready var _btn_execute_anyway: Button       = %BtnExecuteAnyway
@onready var _intel_overlay:      IntelligenceOverlay = %IntelligenceOverlay

var _target: HeistTarget = null
var _capability_tags: Array = []
var _selected_approach: ApproachOption = null

# ── Public ────────────────────────────────────────────────────────────────────

func load_target(target: HeistTarget, capability_tags: Array) -> void:
	_target = target
	_capability_tags = capability_tags
	_selected_approach = null
	_no_target_hint.visible = target == null
	_target_content.visible = target != null
	if target:
		_populate()

# ── Internal: populate ────────────────────────────────────────────────────────

func _populate() -> void:
	_target_name_lbl.text = _target.display_name.to_upper()
	_sidequest_badge.visible = _target.is_sidequest
	_sidequest_badge.text = "SIDEQUEST"
	_sidequest_badge.add_theme_color_override("font_color", SIDEQUEST)

	var effective_sec := HeatSystem.effective_security_level(_target)
	_security_lbl.text = "SECURITY: %s (%d/5)" % [_sec_label(effective_sec), effective_sec]
	_security_lbl.add_theme_color_override("font_color", _sec_color(effective_sec))

	var heat := HeatSystem.get_heat(_target.target_id)
	var tier := HeatSystem.get_heat_tier(_target.target_id)
	_heat_lbl.text = "HEAT: %s" % tier.to_upper()
	_heat_lbl.add_theme_color_override("font_color", _heat_tier_color(tier))

	_populate_intel()
	_populate_approaches()
	_populate_windows()
	_update_risk_assessment()
	_intel_overlay.load_target(_target)

func _populate_intel() -> void:
	for child in _intel_list.get_children():
		child.queue_free()
	for entry: IntelEntry in _target.intel_entries:
		_intel_list.add_child(_make_intel_row(entry))

func _populate_approaches() -> void:
	for child in _approaches_list.get_children():
		child.queue_free()
	for opt: ApproachOption in _target.approach_options:
		var result := ApproachValidator.validate_approach(opt, _capability_tags)
		_approaches_list.add_child(_make_approach_card(opt, result))
	_btn_approach.disabled = _selected_approach == null

func _populate_windows() -> void:
	for child in _windows_list.get_children():
		child.queue_free()
	var scored := MissionWindowEvaluator.rank_windows(_target.mission_windows)
	for score: MissionWindowEvaluator.WindowScore in scored:
		_windows_list.add_child(_make_window_row(score))

func _update_risk_assessment() -> void:
	var intel_q := _target.intel_quality()
	var window_q := MissionWindowEvaluator.best_window_quality(_target.mission_windows)
	var approach_q := 0.5 if _selected_approach != null else 0.0

	_set_risk_bar(_intel_quality_bar, intel_q)
	_set_risk_bar(_approach_conf_bar, approach_q)
	_set_risk_bar(_window_conf_bar, window_q)

	var overall := (intel_q + approach_q + window_q) / 3.0
	var label: String
	var col: Color
	if overall >= 0.70:
		label = "LOW";      col = CONFIRM_COL
	elif overall >= 0.45:
		label = "MODERATE"; col = RUMOR_COL
	elif overall >= 0.25:
		label = "HIGH";     col = RISK_HIGH
	else:
		label = "VERY HIGH"; col = RISK_HIGH

	_overall_risk_lbl.text = "OVERALL RISK:  %s" % label
	_overall_risk_lbl.add_theme_color_override("font_color", col)

	_recommendation_lbl.text = _build_recommendation(intel_q, window_q, _selected_approach)
	_btn_execute_anyway.visible = _selected_approach != null

# ── Row builders ──────────────────────────────────────────────────────────────

func _make_intel_row(entry: IntelEntry) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 8 }

	var badge := Label.new()
	badge.text = entry.confidence_label()
	badge.custom_minimum_size = Vector2(88, 0)
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", _confidence_color(entry.confidence))
	row.add_child(badge)

	var field_lbl := Label.new()
	field_lbl.text = entry.display_label
	field_lbl.custom_minimum_size = Vector2(130, 0)
	field_lbl.add_theme_font_size_override("font_size", 10)
	field_lbl.add_theme_color_override("font_color", TEXT_DIM)
	row.add_child(field_lbl)

	var content_lbl := Label.new()
	content_lbl.text = entry.content if entry.confidence != IntelEntry.Confidence.UNKNOWN else "—"
	content_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_lbl.add_theme_font_size_override("font_size", 10)
	content_lbl.add_theme_color_override("font_color", TEXT_MAIN if entry.confidence >= IntelEntry.Confidence.PROBABLE else TEXT_DIM)
	content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(content_lbl)

	return row

func _make_approach_card(opt: ApproachOption, result: ApproachValidator.ValidationResult) -> Control:
	var card := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.theme_override_constants = { "separation": 4 }
	card.add_child(inner)

	var header := HBoxContainer.new()
	var label_lbl := Label.new()
	label_lbl.text = opt.label
	label_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_lbl.add_theme_font_size_override("font_size", 11)
	label_lbl.add_theme_color_override("font_color", TEXT_MAIN if result.is_valid else TEXT_DIM)
	header.add_child(label_lbl)

	var status_lbl := Label.new()
	status_lbl.text = "VIABLE" if result.is_valid else "LOCKED"
	status_lbl.add_theme_font_size_override("font_size", 9)
	status_lbl.add_theme_color_override("font_color", CONFIRM_COL if result.is_valid else RISK_HIGH)
	header.add_child(status_lbl)
	inner.add_child(header)

	if not result.missing_capabilities.is_empty():
		var miss_lbl := Label.new()
		miss_lbl.text = "Requires: " + ", ".join(result.missing_capabilities)
		miss_lbl.add_theme_font_size_override("font_size", 9)
		miss_lbl.add_theme_color_override("font_color", RISK_HIGH)
		inner.add_child(miss_lbl)

	if not result.cargo_issues.is_empty():
		for issue: String in result.cargo_issues:
			var issue_lbl := Label.new()
			issue_lbl.text = issue
			issue_lbl.add_theme_font_size_override("font_size", 9)
			issue_lbl.add_theme_color_override("font_color", RUMOR_COL)
			inner.add_child(issue_lbl)

	var risk_row := HBoxContainer.new()
	var ghost_lbl := Label.new()
	ghost_lbl.text = "Ghost risk: %d%%  Recovery risk: %d%%" % [roundi(opt.ghost_risk * 100), roundi(opt.recovery_risk * 100)]
	ghost_lbl.add_theme_font_size_override("font_size", 9)
	ghost_lbl.add_theme_color_override("font_color", TEXT_DIM)
	ghost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	risk_row.add_child(ghost_lbl)

	if result.is_valid:
		var select_btn := Button.new()
		select_btn.text = "SELECT"
		select_btn.add_theme_font_size_override("font_size", 10)
		select_btn.pressed.connect(_on_approach_selected.bind(opt))
		risk_row.add_child(select_btn)
	inner.add_child(risk_row)

	# Highlight selected
	if _selected_approach != null and _selected_approach.approach_id == opt.approach_id:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(AMBER, 0.10)
		style.border_width_left = 2
		style.border_color = AMBER
		card.add_theme_stylebox_override("panel", style)

	return card

func _make_window_row(score: MissionWindowEvaluator.WindowScore) -> Control:
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 8 }

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(80, 10)
	bar.value = score.effective_quality * 100.0
	bar.show_percentage = false
	_set_risk_bar(bar, score.effective_quality)
	row.add_child(bar)

	var risk_lbl := Label.new()
	risk_lbl.text = score.risk_label
	risk_lbl.custom_minimum_size = Vector2(70, 0)
	risk_lbl.add_theme_font_size_override("font_size", 9)
	risk_lbl.add_theme_color_override("font_color", _quality_color(score.effective_quality))
	row.add_child(risk_lbl)

	var window_lbl := Label.new()
	window_lbl.text = score.label
	window_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_lbl.add_theme_font_size_override("font_size", 10)
	window_lbl.add_theme_color_override("font_color", TEXT_DIM)
	row.add_child(window_lbl)

	return row

# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_risk_bar(bar: ProgressBar, quality: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _quality_color(quality)
	style.corner_radius_top_left     = 2
	style.corner_radius_top_right    = 2
	style.corner_radius_bottom_left  = 2
	style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", style)
	bar.value = quality * 100.0

func _quality_color(q: float) -> Color:
	if q >= 0.70: return CONFIRM_COL
	if q >= 0.45: return RUMOR_COL
	return RISK_HIGH

func _confidence_color(conf: IntelEntry.Confidence) -> Color:
	match conf:
		IntelEntry.Confidence.CONFIRMED:  return CONFIRM_COL
		IntelEntry.Confidence.PROBABLE:   return RUMOR_COL
		IntelEntry.Confidence.RUMORED:    return Color(0.7, 0.5, 0.1, 1.0)
	return UNKNOWN_COL

func _heat_tier_color(tier: StringName) -> Color:
	match tier:
		&"none":     return TEXT_DIM
		&"low":      return CONFIRM_COL
		&"elevated": return RUMOR_COL
		&"high":     return Color(1.0, 0.45, 0.05, 1.0)
	return RISK_HIGH

func _sec_color(level: int) -> Color:
	if level <= 2: return CONFIRM_COL
	if level <= 3: return RUMOR_COL
	return RISK_HIGH

func _sec_label(level: int) -> String:
	match level:
		1: return "MINIMAL"
		2: return "LOW"
		3: return "MODERATE"
		4: return "HIGH"
	return "MAXIMUM"

func _build_recommendation(intel_q: float, window_q: float, approach: ApproachOption) -> String:
	if intel_q < 0.35:
		return "Intelligence quality is low. Recon before approach design."
	if approach == null:
		return "Select an approach to continue planning."
	if window_q < 0.40:
		return "Timing window data is weak. Confirm guard rotation before committing."
	return "Plan looks viable. Practice route nodes before execution."

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_approach_selected(opt: ApproachOption) -> void:
	_selected_approach = opt
	_populate_approaches()
	_update_risk_assessment()
	_btn_approach.disabled = false

func _ready() -> void:
	_no_target_hint.visible = true
	_target_content.visible = false
	_btn_recon.pressed.connect(func():
		if _target: recon_requested.emit(_target)
	)
	_btn_approach.pressed.connect(func():
		if _selected_approach: approach_confirmed.emit(_selected_approach)
	)
	_btn_execute_anyway.pressed.connect(func():
		if _selected_approach: approach_confirmed.emit(_selected_approach)
	)
