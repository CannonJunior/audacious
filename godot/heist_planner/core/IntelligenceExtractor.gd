class_name IntelligenceExtractor
extends RefCounted
## Post-mission pass over hacked data: surfaces new IntelEntry fields,
## discovers UpgradeOpportunity leads, and updates HeistTarget confidence.
## Called by MissionDebriefPanel / OperationsCenter after a completed run.

## Input: raw key-value pairs extracted from mission data packets.
## Output: updates target intel in-place and returns discovered opportunities.
static func process_hacked_data(
	raw_data: Dictionary,
	target: HeistTarget,
	board: UpgradeBoard
) -> Array[UpgradeOpportunity]:
	var discovered: Array[UpgradeOpportunity] = []

	for field_id: String in raw_data.keys():
		var value: String = str(raw_data[field_id])
		var entry := target.get_intel(field_id as StringName)
		if entry == null:
			entry = IntelEntry.new()
			entry.field_id = field_id as StringName
			entry.display_label = field_id.replace("_", " ").capitalize()

		# Hacked data is always at least PROBABLE; upgrade to CONFIRMED if re-confirmed
		var new_conf := IntelEntry.Confidence.PROBABLE
		if entry.confidence == IntelEntry.Confidence.PROBABLE:
			new_conf = IntelEntry.Confidence.CONFIRMED
		entry.confidence = new_conf
		entry.content = value
		entry.discovered_at = Time.get_ticks_msec() / 1000.0
		target.add_or_update_intel(entry)

		# Surface upgrade lead if data references upgrade-related keywords
		var lead := _check_upgrade_lead(field_id, value, board)
		if lead:
			discovered.append(lead)

	return discovered

## Elevate existing RUMORED intel to PROBABLE after a clean ghost run.
static func apply_ghost_intel_bonus(target: HeistTarget) -> void:
	for entry: IntelEntry in target.intel_entries:
		if entry.confidence == IntelEntry.Confidence.RUMORED:
			entry.confidence = IntelEntry.Confidence.PROBABLE

## Build IntelEntry list from a guard-log dump (list of Strings).
static func parse_guard_log(log_lines: Array[String], target: HeistTarget) -> void:
	var pattern_map := {
		"shift": "guard_shift_pattern",
		"rotation": "guard_rotation_schedule",
		"camera": "camera_coverage",
		"alarm": "alarm_trigger_zone",
		"storage": "objective_storage_location",
		"vault": "objective_storage_location",
	}
	for line: String in log_lines:
		var low := line.to_lower()
		for keyword: String in pattern_map.keys():
			if keyword in low:
				var fid: StringName = pattern_map[keyword] as StringName
				var entry := target.get_intel(fid)
				if entry == null or entry.confidence < IntelEntry.Confidence.PROBABLE:
					var new_entry := IntelEntry.new()
					new_entry.field_id = fid
					new_entry.display_label = fid.replace("_", " ").capitalize()
					new_entry.confidence = IntelEntry.Confidence.PROBABLE
					new_entry.content = line.left(120)
					new_entry.discovered_at = Time.get_ticks_msec() / 1000.0
					target.add_or_update_intel(new_entry)
				break

# ── Internal ──────────────────────────────────────────────────────────────────

static func _check_upgrade_lead(
	field_id: String,
	value: String,
	board: UpgradeBoard
) -> UpgradeOpportunity:
	# Look for existing undiscovered opportunities that list this field as a trigger
	for opp: UpgradeOpportunity in board.opportunities:
		if opp.state != UpgradeOpportunity.State.UNDISCOVERED:
			continue
		if opp.discovery_trigger_field == (field_id as StringName):
			var triggered := opp.duplicate() as UpgradeOpportunity
			triggered.state = UpgradeOpportunity.State.OPPORTUNITY
			return triggered
	return null
