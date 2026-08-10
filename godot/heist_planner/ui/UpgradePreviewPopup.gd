class_name UpgradePreviewPopup
extends PanelContainer
## Modal overlay that shows a pending UpgradeOpportunity — stat deltas,
## cargo requirements, villain-contested warning, and time remaining.
## The player can commit (hand off to UpgradeBoardManager) or dismiss.

const AMBER:     Color = Color(1.0,  0.420, 0.0,  1.0)
const TEXT_MAIN: Color = Color(0.85, 0.85,  0.88, 1.0)
const TEXT_DIM:  Color = Color(0.55, 0.55,  0.60, 1.0)
const GOOD_COL:  Color = Color(0.15, 1.0,   0.30, 1.0)
const WARN_COL:  Color = Color(0.90, 0.70,  0.10, 1.0)
const BAD_COL:   Color = Color(1.0,  0.20,  0.08, 1.0)
const RARE_SHIMM: Color = Color(0.85, 0.75,  1.0,  1.0)

@onready var _title_lbl:       Label         = %UpgradeTitle
@onready var _chain_lbl:       Label         = %ChainLabel
@onready var _time_lbl:        Label         = %TimeRemainingLabel
@onready var _villain_warning: Label         = %VillainWarning
@onready var _stat_list:       VBoxContainer = %StatDeltaList
@onready var _cargo_info:      Label         = %CargoInfoLabel
@onready var _btn_commit:      Button        = %BtnCommitUpgrade
@onready var _btn_dismiss:     Button        = %BtnDismissUpgrade

signal upgrade_committed(opp: UpgradeOpportunity)
signal upgrade_dismissed()

var _current_opp: UpgradeOpportunity = null

# ── Public ────────────────────────────────────────────────────────────────────

func show_opportunity(opp: UpgradeOpportunity) -> void:
	_current_opp = opp
	_title_lbl.text = opp.upgrade_id
	_title_lbl.add_theme_color_override("font_color", AMBER)

	if opp.chain_id != &"":
		_chain_lbl.text = "Chain: %s  (step %d)" % [opp.chain_id, opp.chain_step + 1]
		_chain_lbl.visible = true
	else:
		_chain_lbl.visible = false

	var hrs := opp.hours_remaining()
	if hrs <= 0.0:
		_time_lbl.text = "EXPIRED"
		_time_lbl.add_theme_color_override("font_color", BAD_COL)
	elif opp.time_sensitive and hrs < 24.0:
		_time_lbl.text = "%.1f hrs remaining" % hrs
		_time_lbl.add_theme_color_override("font_color", BAD_COL)
	else:
		_time_lbl.text = "%.0f hrs remaining" % hrs
		_time_lbl.add_theme_color_override("font_color", WARN_COL if hrs < 72.0 else TEXT_DIM)

	_villain_warning.visible = opp.villain_contested
	if opp.villain_contested:
		_villain_warning.text = "CONTESTED — villain may acquire this first"
		_villain_warning.add_theme_color_override("font_color", BAD_COL)

	_populate_stat_deltas(opp)

	if opp.cargo != null:
		_cargo_info.visible = true
		_cargo_info.text = "Requires transport: %.1fkg, %.1fm clearance" % [
			opp.cargo.mass_kg, opp.cargo.clearance_required
		]
		_cargo_info.add_theme_color_override("font_color", RARE_SHIMM)
	else:
		_cargo_info.visible = false

	visible = true

func hide_popup() -> void:
	visible = false
	_current_opp = null

# ── Internal ──────────────────────────────────────────────────────────────────

func _populate_stat_deltas(opp: UpgradeOpportunity) -> void:
	for child in _stat_list.get_children():
		child.queue_free()

	_add_stat_row("Speed",    opp.delta_speed_modifier)
	_add_stat_row("Stealth",  opp.delta_stealth_modifier)
	_add_stat_row("Endurance", opp.delta_endurance_modifier)

	for tag: String in opp.grants_capability_tags:
		var lbl := Label.new()
		lbl.text = "+ capability: %s" % tag
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", GOOD_COL)
		_stat_list.add_child(lbl)

func _add_stat_row(label: String, delta: float) -> void:
	if absf(delta) < 0.001:
		return
	var row := HBoxContainer.new()
	row.theme_override_constants = { "separation": 8 }

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", TEXT_DIM)
	row.add_child(name_lbl)

	var delta_lbl := Label.new()
	delta_lbl.text = ("%+.2f" % delta)
	delta_lbl.add_theme_font_size_override("font_size", 10)
	delta_lbl.add_theme_color_override("font_color", GOOD_COL if delta > 0 else BAD_COL)
	row.add_child(delta_lbl)

	_stat_list.add_child(row)

# ── Handlers ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false
	_btn_commit.pressed.connect(_on_commit)
	_btn_dismiss.pressed.connect(_on_dismiss)

func _on_commit() -> void:
	if _current_opp:
		UpgradeBoardManager.complete_step(_current_opp.upgrade_id)
		upgrade_committed.emit(_current_opp)
	hide_popup()

func _on_dismiss() -> void:
	upgrade_dismissed.emit()
	hide_popup()
