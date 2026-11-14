extends Control

const RomInspector = preload("res://scripts/rom/rom_inspector.gd")
const RomTextureImporter = preload("res://scripts/rom/rom_texture_importer.gd")
const CACHE_ROOT := "user://imports"

var _file_dialog: FileDialog
var _clear_dialog: ConfirmationDialog
var _result_label: Label
var _selected_label: Label
var _cache_label: Label
var _inspect_button: Button
var _texture_button: Button
var _texture_preview: TextureRect
var _texture_status: Label
var _selected_path := ""
var _last_result: Dictionary = {}


func _ready() -> void:
	_build_ui()
	get_window().files_dropped.connect(_on_files_dropped)
	_refresh_cache_status()


func _on_files_dropped(dropped: PackedStringArray) -> void:
	if dropped.size() == 1:
		_select_path(dropped[0])
	elif dropped.size() > 1:
		_show_error("Drop one ROM file or ZIP archive at a time.")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101827")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("162235")
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 26
	panel_style.content_margin_right = 26
	panel_style.content_margin_top = 26
	panel_style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	var title := Label.new()
	title.text = "Sonic 3 & Knuckles Remastered"
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Select your combined ROM to check whether it matches the supported profile."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)

	var drop_area := PanelContainer.new()
	drop_area.custom_minimum_size = Vector2(0, 92)
	var drop_style := StyleBoxFlat.new()
	drop_style.bg_color = Color("19263a")
	drop_style.border_color = Color("415b7b")
	drop_style.set_border_width_all(1)
	drop_style.set_corner_radius_all(8)
	drop_area.add_theme_stylebox_override("panel", drop_style)
	content.add_child(drop_area)
	var drop_label := Label.new()
	drop_label.text = "Drop one .md ROM or .zip archive here"
	drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drop_area.add_child(drop_label)

	_selected_label = Label.new()
	_selected_label.text = "No file selected"
	_selected_label.modulate = Color("b7c4d6")
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_selected_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	var choose_button := Button.new()
	choose_button.text = "Choose ROM…"
	choose_button.pressed.connect(_open_file_picker)
	actions.add_child(choose_button)
	_inspect_button = Button.new()
	_inspect_button.text = "Check compatibility"
	_inspect_button.disabled = true
	_inspect_button.pressed.connect(_inspect_selected)
	actions.add_child(_inspect_button)
	var preview_button := Button.new()
	preview_button.text = "Open decoder preview"
	preview_button.pressed.connect(_open_decoder_preview)
	actions.add_child(preview_button)
	var import_actions := HBoxContainer.new()
	content.add_child(import_actions)
	_texture_button = Button.new()
	_texture_button.text = "Build AIZ texture proof"
	_texture_button.disabled = true
	_texture_button.pressed.connect(_build_aiz_texture_proof)
	import_actions.add_child(_texture_button)

	_result_label = Label.new()
	_result_label.text = "Check a supported ROM to enable a real AIZ Act 1 texture preview. Generated images stay in the local cache."
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.custom_minimum_size = Vector2(0, 52)
	content.add_child(_result_label)
	_texture_status = Label.new()
	_texture_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texture_status.visible = false
	content.add_child(_texture_status)
	_texture_preview = TextureRect.new()
	_texture_preview.custom_minimum_size = Vector2(0, 256)
	_texture_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_texture_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_preview.visible = false
	content.add_child(_texture_preview)

	var separator := HSeparator.new()
	content.add_child(separator)

	var local_title := Label.new()
	local_title.text = "Local generated data"
	local_title.add_theme_font_size_override("font_size", 18)
	content.add_child(local_title)

	_cache_label = Label.new()
	_cache_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_cache_label)

	var local_actions := HBoxContainer.new()
	local_actions.add_theme_constant_override("separation", 10)
	content.add_child(local_actions)
	var open_folder := Button.new()
	open_folder.text = "Show data folder"
	open_folder.pressed.connect(_open_cache_folder)
	local_actions.add_child(open_folder)
	var clear_button := Button.new()
	clear_button.text = "Clear generated cache…"
	clear_button.pressed.connect(_confirm_clear_cache)
	local_actions.add_child(clear_button)

	_file_dialog = FileDialog.new()
	_file_dialog.title = "Select a combined Sonic 3 & Knuckles ROM"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.md", "Mega Drive ROM")
	_file_dialog.add_filter("*.zip", "ZIP archive")
	_file_dialog.file_selected.connect(_select_path)
	add_child(_file_dialog)

	_clear_dialog = ConfirmationDialog.new()
	_clear_dialog.title = "Clear generated data?"
	_clear_dialog.dialog_text = "This removes generated files under this game's user data/imports folder. It does not touch your selected ROM."
	_clear_dialog.confirmed.connect(_clear_cache)
	add_child(_clear_dialog)


func _open_file_picker() -> void:
	_file_dialog.popup_centered_ratio(0.72)


func _open_decoder_preview() -> void:
	get_tree().change_scene_to_file("res://scenes/decoder_preview.tscn")


func _select_path(path: String) -> void:
	_selected_path = path
	_last_result.clear()
	_texture_button.disabled = true
	_texture_preview.texture = null
	_texture_status.text = ""
	_texture_preview.visible = false
	_texture_status.visible = false
	_selected_label.text = "Selected: %s" % path.get_file()
	_inspect_button.disabled = false
	_result_label.text = "Ready to check this file. The source will be opened read-only."
	_result_label.modulate = Color("d6deea")


func _inspect_selected() -> void:
	if _selected_path.is_empty():
		return
	_last_result = RomInspector.inspect_file(_selected_path)
	if not _last_result.get("ok", false):
		_show_error(str(_last_result.get("error", "Could not validate this file.")))
		return
	var first: Dictionary = _last_result.get("first_segment", {})
	var second: Dictionary = _last_result.get("second_segment", {})
	_texture_button.disabled = false
	_result_label.text = "Compatible profile: %s\nSize: %s bytes\nSHA-256: %s\nDetected: %s / %s" % [
		_last_result.get("profile_id", "unknown"),
		_last_result.get("byte_size", 0),
		_last_result.get("sha256", ""),
		first.get("title", "first image"),
		second.get("title", "second image"),
	]
	_result_label.modulate = Color("9be2b2")


func _build_aiz_texture_proof() -> void:
	if not _last_result.get("ok", false):
		return
	var result: Dictionary = RomTextureImporter.import_aiz_intro(_last_result["image_bytes"])
	if not result.get("ok", false):
		_texture_status.text = str(result.get("error", "AIZ texture preview could not be generated."))
		_texture_status.modulate = Color("ff9c94")
		return
	_texture_preview.texture = ImageTexture.create_from_image(result["primary_image"])
	_texture_preview.visible = true
	_texture_status.visible = true
	_texture_status.text = "Real ROM texture preview · AIZ Act 1 intro · %d primary tiles and %d secondary tiles\nGenerated images saved under the local user data folder: %s and %s" % [
		result["primary_tiles"],
		result["secondary_tiles"],
		result["primary_path"],
		result["secondary_path"],
	]
	_texture_status.modulate = Color("9be2b2")
	_refresh_cache_status()


func _show_error(message: String) -> void:
	_last_result = {"ok": false, "error": message}
	_texture_button.disabled = true
	_texture_preview.texture = null
	_texture_preview.visible = false
	_texture_status.visible = false
	_result_label.text = message
	_result_label.modulate = Color("ff9c94")


func _refresh_cache_status() -> void:
	var absolute_root := ProjectSettings.globalize_path(CACHE_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		_cache_label.text = "Cache folder: %s\nIt contains generated data only." % absolute_root
	else:
		_cache_label.text = "No generated cache exists yet. Data will be stored under the game's user:// folder."


func _open_cache_folder() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_ROOT))
	if error != OK and error != ERR_ALREADY_EXISTS:
		_show_error("Could not create or open the local data folder.")
		return
	OS.shell_open(ProjectSettings.globalize_path(CACHE_ROOT))
	_refresh_cache_status()


func _confirm_clear_cache() -> void:
	_clear_dialog.popup_centered()


func _clear_cache() -> void:
	var absolute_root := ProjectSettings.globalize_path(CACHE_ROOT).simplify_path()
	var expected_parent := ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/") + "/"
	if not absolute_root.begins_with(expected_parent) or absolute_root == expected_parent.trim_suffix("/"):
		_show_error("Cache location check failed; no files were removed.")
		return
	if not DirAccess.dir_exists_absolute(absolute_root):
		_refresh_cache_status()
		return
	var error := _remove_directory_contents(absolute_root)
	if error != OK:
		_show_error("Could not clear all generated cache files. Some files may still be in use.")
	else:
		_result_label.text = "Generated cache cleared. Your source ROM was not changed."
		_result_label.modulate = Color("9be2b2")
	_refresh_cache_status()


func _remove_directory_contents(directory_path: String) -> Error:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child_path := (directory_path.path_join(entry)).simplify_path()
			if directory.current_is_dir():
				var nested_error := _remove_directory_contents(child_path)
				if nested_error != OK:
					directory.list_dir_end()
					return nested_error
				var remove_dir_error := DirAccess.remove_absolute(child_path)
				if remove_dir_error != OK:
					directory.list_dir_end()
					return remove_dir_error
			else:
				var remove_file_error := DirAccess.remove_absolute(child_path)
				if remove_file_error != OK:
					directory.list_dir_end()
					return remove_file_error
		entry = directory.get_next()
	directory.list_dir_end()
	return OK
