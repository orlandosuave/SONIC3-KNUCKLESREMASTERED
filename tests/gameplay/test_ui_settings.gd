extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var preferences := root.get_node("UiPreferences")
	var original_mode: int = preferences.width_mode
	var original_margin: int = preferences.margin
	var path := "user://ui-settings-test-%d.cfg" % OS.get_process_id()
	check(preferences.apply_settings(1, 48, path) == OK, "Save settings")
	var loaded = load("res://scripts/ui/ui_preferences.gd").new()
	loaded.load_settings(path)
	check(loaded.width_mode == 1 and loaded.margin == 48, "Persisted preferences reload")
	var invalid := ConfigFile.new()
	invalid.set_value("ui", "width_mode", "invalid")
	invalid.set_value("ui", "margin", -500)
	invalid.save(path)
	loaded.load_settings(path)
	check(loaded.width_mode == 0 and loaded.margin == 8, "Invalid settings safely bounded")
	loaded.free()
	for resolution in [Vector2i(1920, 1080), Vector2i(2520, 1080), Vector2i(5120, 1440)]:
		root.size = resolution
		for mode in [0, 1, 2]:
			preferences.apply_settings(mode, 64, path)
			for scene in ["main", "decoder_preview", "movement_prototype", "encounter_prototype"]:
				var screen = load("res://scenes/%s.tscn" % scene).instantiate()
				root.add_child(screen)
				for frame in 4: await process_frame
				var safe: Control
				if scene == "main" or scene == "decoder_preview":
					safe = screen.get_child(1)
					var scroll: ScrollContainer = safe.get_node("MenuScroll")
					var panel: Control = scroll.get_child(0).get_child(0)
					check(panel.size.x <= scroll.size.x, "Menu width fits safe region: %s %s mode %s" % [scene, resolution, mode])
					if scene == "main":
						# A large import preview remains reachable through vertical scrolling.
						screen._texture_preview.visible = true
						screen._texture_status.visible = true
						screen._texture_status.text = "Imported data\n".repeat(30)
						for frame in 4: await process_frame
						check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Long import results scroll")
				else:
					# Find the shared safe region under the HUD CanvasLayer.
					for node in screen.get_children():
						if node is CanvasLayer:
							for child in node.get_children():
								if child.get_script() == load("res://scripts/ui/safe_region.gd"): safe = child
				check(safe != null, "Safe region present")
				if safe != null:
					var view: Vector2 = screen.get_viewport_rect().size
					check(safe.position.x >= 64 and safe.position.y == 64, "Edge margin applied")
					check((safe.position + safe.size).x <= view.x - 63.9, "Safe region contained")
					preferences.apply_settings(mode, 16, path)
					check(safe.position.y == 16, "Settings update live")
					preferences.apply_settings(mode, 64, path)
				screen.free()
	preferences.width_mode = original_mode
	preferences.margin = original_margin
	preferences.changed.emit()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("UI settings regression: %d failures" % failures)
	quit(1 if failures else 0)
