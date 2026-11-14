extends "res://scripts/ui/safe_region.gd"
## Keep long import results reachable rather than growing beyond the window.
func mount_panel(panel: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "MenuScroll"
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	center.add_child(panel)
