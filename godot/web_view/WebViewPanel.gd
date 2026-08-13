extends Control
# WebViewBridge drives this panel directly (find_child + signal connections).
# This script is intentionally minimal — status/items/interactions are all
# managed by WebViewBridge._bind_panel() since this script fails to execute
# due to an unresolved Godot scene-attachment issue.

func _ready() -> void:
	print("WebViewPanel: _ready called")
