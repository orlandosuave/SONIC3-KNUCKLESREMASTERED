extends SceneTree

const TEST_ROOT := "user://rom_inspector_test"
var failures := 0


func _initialize() -> void:
	var inspector = load("res://scripts/rom/rom_inspector.gd")
	var root_absolute := ProjectSettings.globalize_path(TEST_ROOT)
	DirAccess.make_dir_recursive_absolute(root_absolute)
	var unsupported_path := TEST_ROOT.path_join("not_a_rom.txt")
	_write_file(unsupported_path, PackedByteArray([0x41]))
	var unsupported: Dictionary = inspector.inspect_file(ProjectSettings.globalize_path(unsupported_path))
	_check(not unsupported.get("ok", false), "unsupported file type rejected")
	_check(str(unsupported.get("error", "")).contains("Unsupported file type"), "unsupported file type has a clear reason")
	var wrong_size_path := TEST_ROOT.path_join("wrong_size.md")
	_write_file(wrong_size_path, PackedByteArray([0x00, 0x01]))
	var wrong_size: Dictionary = inspector.inspect_file(ProjectSettings.globalize_path(wrong_size_path))
	_check(not wrong_size.get("ok", false), "wrong-sized ROM rejected")
	_check(str(wrong_size.get("error", "")).contains("expected 4 MiB"), "wrong size has a clear reason")
	var wrong_profile_path := TEST_ROOT.path_join("unsupported_profile.md")
	var invalid_image := PackedByteArray()
	invalid_image.resize(inspector.SUPPORTED_SIZE)
	_write_file(wrong_profile_path, invalid_image)
	var wrong_profile: Dictionary = inspector.inspect_file(ProjectSettings.globalize_path(wrong_profile_path))
	_check(not wrong_profile.get("ok", false), "unsupported full-size profile rejected")
	_check(str(wrong_profile.get("error", "")).contains("not the currently supported"), "unsupported profile has a clear reason")
	var corrupt_zip_path := TEST_ROOT.path_join("corrupt.zip")
	_write_file(corrupt_zip_path, PackedByteArray([0x4E, 0x4F, 0x54, 0x5A, 0x49, 0x50]))
	var corrupt_zip: Dictionary = inspector.inspect_file(ProjectSettings.globalize_path(corrupt_zip_path))
	_check(not corrupt_zip.get("ok", false), "corrupt ZIP rejected")
	_check(str(corrupt_zip.get("error", "")).contains("Could not read this ZIP"), "corrupt ZIP has a clear reason")
	var multiple_zip_path := TEST_ROOT.path_join("multiple_roms.zip")
	var zip_writer := ZIPPacker.new()
	_check(zip_writer.open(multiple_zip_path) == OK, "test ZIP opens")
	for member in ["one.md", "two.md"]:
		_check(zip_writer.start_file(member) == OK, "test ZIP member starts")
		_check(zip_writer.write_file(PackedByteArray([0x00])) == OK, "test ZIP member writes")
		_check(zip_writer.close_file() == OK, "test ZIP member closes")
	_check(zip_writer.close() == OK, "test ZIP closes")
	var ambiguous_zip: Dictionary = inspector.inspect_file(ProjectSettings.globalize_path(multiple_zip_path))
	_check(not ambiguous_zip.get("ok", false), "ambiguous ZIP rejected")
	_check(str(ambiguous_zip.get("error", "")).contains("exactly one .md"), "ambiguous ZIP has a clear reason")
	_remove_test_files(root_absolute)
	if failures == 0:
		print("ROM inspector rejection checks passed.")
		quit(0)
	else:
		push_error("ROM inspector checks failed: %d" % failures)
		quit(1)


func _write_file(user_path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(user_path, FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()


func _remove_test_files(root_absolute: String) -> void:
	var directory := DirAccess.open(root_absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and not directory.current_is_dir():
			DirAccess.remove_absolute(root_absolute.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(root_absolute)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("Check failed: %s" % description)
