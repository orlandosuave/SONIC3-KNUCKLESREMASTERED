extends SceneTree


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var source_path := ""
	if not arguments.is_empty():
		source_path = arguments[0]
	else:
		for argument in OS.get_cmdline_args():
			if argument.get_extension().to_lower() in ["md", "zip"]:
				source_path = argument
				break
	if source_path.is_empty():
		print("Local AIZ import check skipped. Pass a supported .md or .zip path after -- to run it.")
		quit(0)
		return
	var inspector = load("res://scripts/rom/rom_inspector.gd")
	var importer = load("res://scripts/rom/rom_texture_importer.gd")
	var profile: Dictionary = inspector.inspect_file(source_path)
	assert(profile.get("ok", false), str(profile.get("error", "profile check failed")))
	var first: Dictionary = importer.import_aiz_intro(profile["image_bytes"])
	assert(first.get("ok", false), str(first.get("error", "initial import failed")))
	assert(first["primary_tiles"] == 190 and first["secondary_tiles"] == 787)
	var manifest_path := ProjectSettings.globalize_path(first["manifest_path"])
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	assert(manifest_file != null)
	var original_manifest := manifest_file.get_buffer(manifest_file.get_length())
	manifest_file.close()
	var manifest_text := original_manifest.get_string_from_utf8()
	assert(not manifest_text.contains(source_path) and not manifest_text.contains(source_path.get_file()))
	var second: Dictionary = importer.import_aiz_intro(profile["image_bytes"])
	assert(second.get("ok", false) and second.get("cache_hit", false), "second import should use a validated cache")
	var cached_primary := FileAccess.open(ProjectSettings.globalize_path(second["primary_path"]), FileAccess.WRITE)
	assert(cached_primary != null)
	cached_primary.store_buffer(PackedByteArray([0x42]))
	cached_primary.close()
	var rebuilt: Dictionary = importer.import_aiz_intro(profile["image_bytes"])
	assert(rebuilt.get("ok", false) and not rebuilt.get("cache_hit", true), "damaged cache should be rebuilt")
	var recovered: Dictionary = importer.import_aiz_intro(profile["image_bytes"])
	assert(recovered.get("ok", false) and recovered.get("cache_hit", false), "rebuilt cache should validate on reuse")
	var rebuilt_manifest := FileAccess.open(ProjectSettings.globalize_path(recovered["manifest_path"]), FileAccess.READ)
	assert(rebuilt_manifest != null)
	var final_manifest := rebuilt_manifest.get_buffer(rebuilt_manifest.get_length())
	rebuilt_manifest.close()
	assert(final_manifest == original_manifest, "manifest and output hashes should be deterministic")
	await _check_import_screen(source_path)
	print("Local AIZ import checks passed: profile validation, import UI success/rejection, manifest, cache reuse, corruption recovery, and deterministic output.")
	quit(0)


func _check_import_screen(source_path: String) -> void:
	var screen: Variant = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	screen._select_path(source_path)
	screen._inspect_selected()
	assert(screen._last_result.get("ok", false), "valid ROM should enable the import action")
	assert(not screen._texture_button.disabled)
	assert(not screen._terrain_button.disabled)
	screen._build_aiz_terrain_preview()
	await process_frame
	assert(screen._texture_preview.texture.get_size() == Vector2(320, 224))
	assert(screen._texture_status.text.contains("Static foreground"))
	screen._build_aiz_texture_proof()
	await process_frame
	assert(screen._texture_preview.texture != null, "valid ROM should display the real tile atlas")
	var invalid_path := "user://local_import_screen_wrong_size.md"
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	assert(invalid_file != null)
	invalid_file.store_buffer(PackedByteArray([0x41, 0x42]))
	invalid_file.close()
	screen._select_path(ProjectSettings.globalize_path(invalid_path))
	screen._inspect_selected()
	assert(not screen._last_result.get("ok", false), "wrong-sized ROM should be rejected in the screen")
	assert(screen._terrain_button.disabled)
	assert(screen._texture_button.disabled, "rejected ROM must not enable the import action")
	assert(str(screen._result_label.text).contains("expected 4 MiB"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	screen.queue_free()
