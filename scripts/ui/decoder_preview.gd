extends Control

const Decoder = preload("res://scripts/rom/rom_data_decoder.gd")
const Inspector = preload("res://scripts/rom/rom_inspector.gd")
const Terrain = preload("res://scripts/rom/rom_terrain_decoder.gd")
const Collision = preload("res://scripts/gameplay/rom_terrain_collision.gd")
const TextureImporter = preload("res://scripts/rom/rom_texture_importer.gd")
const Player = preload("res://scripts/gameplay/player_controller.gd")
const Camera = preload("res://scripts/gameplay/prototype_camera.gd")
const AIZ_REGION := Rect2i(6816, 888, 576, 162)
const ROUTE_FIRST_X := 6880
const ROUTE_LAST_X := 7264

var _menu_background: ColorRect
var _menu_frame: Control
var _aiz_dialog: FileDialog
var _aiz_status: Label
var _aiz_world: Node2D
var _aiz_player: PrototypePlayer
var _aiz_camera: Camera2D
var _aiz_hud: CanvasLayer
var _aiz_hud_label: Label
var _aiz_ground: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("101827")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_menu_background = background

	var frame := preload("res://scripts/ui/menu_frame.gd").new()
	add_child(frame)
	_menu_frame = frame

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("162235")
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 28
	panel_style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", panel_style)
	frame.mount_panel(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)

	var heading := Label.new()
	heading.text = "ROM graphics decoder preview"
	heading.add_theme_font_size_override("font_size", 28)
	content.add_child(heading)

	var explanation := Label.new()
	explanation.text = "Synthetic fixture · This preview is generated from test bytes, not extracted from your ROM. It demonstrates the 4bpp tile and Genesis palette decoder."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)

	var decoded_tiles: Dictionary = Decoder.decode_4bpp_tiles(_make_tile_fixture())
	var decoded_palette: Dictionary = Decoder.decode_palette_4bpp(_make_palette_fixture())
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	if not decoded_tiles.get("ok", false):
		status.text = "Tile decoder error: %s" % decoded_tiles.get("error", "unknown error")
		status.modulate = Color("ff9c94")
	elif not decoded_palette.get("ok", false):
		status.text = "Palette decoder error: %s" % decoded_palette.get("error", "unknown error")
		status.modulate = Color("ff9c94")
	else:
		var composed: Dictionary = Decoder.compose_tile_image(
			decoded_tiles["tiles"], 4, decoded_palette["colors"]
		)
		if not composed.get("ok", false):
			status.text = "Image composition error: %s" % composed.get("error", "unknown error")
			status.modulate = Color("ff9c94")
		else:
			status.text = "Decoded %d synthetic tiles and %d palette colors into a %d × %d pixel atlas." % [
				decoded_tiles["tile_count"], decoded_palette["color_count"], composed["width"], composed["height"]
			]
			status.modulate = Color("9be2b2")
			var preview := TextureRect.new()
			preview.texture = ImageTexture.create_from_image(composed["image"])
			preview.custom_minimum_size = Vector2(512, 128)
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_SCALE
			preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			content.add_child(preview)

	var aiz_button := Button.new()
	aiz_button.text = "Open ROM-derived Angel Island playable slice…"
	aiz_button.pressed.connect(_choose_aiz_source)
	content.add_child(aiz_button)
	_aiz_status = Label.new()
	_aiz_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aiz_status.text = "Uses your own supported .md/.zip; local cached graphics, actual AIZ tiles and collision samples. No ROM is copied into the project."
	content.add_child(_aiz_status)
	_aiz_dialog = FileDialog.new()
	_aiz_dialog.title = "Select your local supported Sonic 3 & Knuckles ROM"
	_aiz_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_aiz_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_aiz_dialog.add_filter("*.md", "Mega Drive ROM")
	_aiz_dialog.add_filter("*.zip", "ROM ZIP archive")
	_aiz_dialog.file_selected.connect(_load_aiz_slice)
	add_child(_aiz_dialog)

	var back_button := Button.new()
	back_button.text = "Back to ROM intake"
	back_button.pressed.connect(_return_to_intake)
	content.add_child(back_button)


func _make_tile_fixture() -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(4 * 32)
	for tile_index in range(4):
		for y in range(8):
			for x in range(8):
				var color_index := _fixture_pixel(tile_index, x, y)
				var row_offset := tile_index * 32 + y * 4
				for plane in range(4):
					if ((color_index >> plane) & 1) != 0:
						result[row_offset + plane] |= 1 << (7 - x)
	return result


func _fixture_pixel(tile_index: int, x: int, y: int) -> int:
	match tile_index:
		0:
			return 1 if x == 0 or y == 0 or x == 7 or y == 7 else 0
		1:
			return 2 if (x + y) % 2 == 0 else 0
		2:
			return (x + y) % 8
		_:
			var dx := x - 3.5
			var dy := y - 3.5
			return 7 if dx * dx + dy * dy <= 12.25 else 0


func _make_palette_fixture() -> PackedByteArray:
	var result := PackedByteArray()
	for index in range(16):
		var red := index & 0x07
		var green := (index >> 1) & 0x07
		var blue := (index >> 2) & 0x07
		var word := (red << 1) | (green << 5) | (blue << 9)
		result.append((word >> 8) & 0xFF)
		result.append(word & 0xFF)
	return result


func _return_to_intake() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _choose_aiz_source() -> void:
	_aiz_dialog.popup_centered_ratio(0.8)


func _aiz_error(message: String) -> void:
	_aiz_status.text = "Angel Island: " + message
	_aiz_status.modulate = Color("ff9c94")
	push_warning("AIZ slice: " + message)


# Bounded source-ROM height samples form a visual polygon, not original sensor parity.
# Ceiling/left-wall contacts, path transitions, DMA/water and full-act G1/G2
# remain unverified; do not treat this demo as a faithful collision replay.
func _ground_from_rom(bundle: Dictionary) -> Dictionary:
	var points := PackedVector2Array()
	var flat_count := 0
	var slope_count := 0
	for x in range(ROUTE_FIRST_X, ROUTE_LAST_X + 1, 8):
		var surface_y := -1
		var surface_angle := -1
		for y in range(892, 1100, 8):
			var probe: Dictionary = Collision.find_floor(bundle, Vector2i(x, y), 0, 0)
			if not probe.get("ok", false) or int(probe.get("height", 0)) <= 0:
				continue
			var distance := int(probe.get("distance", 999))
			if absi(distance) > 16:
				continue
			var candidate := y + distance
			if surface_y < 0 or candidate < surface_y:
				surface_y = candidate
				surface_angle = int(probe.get("angle", 0))
		if surface_y < 0 or (not points.is_empty() and absf(float(surface_y) - points[-1].y) > 8.0):
			return {"ok": false, "error": "ROM collision samples have a gap or discontinuity on the selected route."}
		points.append(Vector2(x, surface_y))
		if surface_angle == 248:
			slope_count += 1
		elif surface_angle == 1 or surface_angle == 255:
			flat_count += 1
	if flat_count < 8 or slope_count < 8:
		return {"ok": false, "error": "The selected ROM route has no verified flat-to-slope transition."}
	return {"ok": true, "points": points, "flat_samples": flat_count, "slope_samples": slope_count}


func _load_aiz_slice(path: String) -> void:
	var inspected: Dictionary = Inspector.inspect_file(path)
	if not inspected.get("ok", false):
		_aiz_error(str(inspected.get("error", "Unsupported local ROM.")))
		return
	var cache: Dictionary = TextureImporter.load_aiz_intro_cache()
	if not cache.get("ok", false):
		cache = TextureImporter.import_aiz_intro(inspected["image_bytes"])
	if not cache.get("ok", false):
		_aiz_error(str(cache.get("error", "The validated AIZ texture cache cannot be read.")))
		return
	var bundle: Dictionary = Terrain.decode_aiz_main(inspected["image_bytes"])
	if not bundle.get("ok", false):
		_aiz_error(str(bundle.get("error", "Could not decode AIZ terrain.")))
		return
	var floor: Dictionary = _ground_from_rom(bundle)
	if not floor.get("ok", false):
		_aiz_error(str(floor.get("error", "No bounded collision route.")))
		return
	var background: Dictionary = Terrain.render_region(bundle, "background", AIZ_REGION)
	var foreground: Dictionary = Terrain.render_region(bundle, "foreground", AIZ_REGION)
	if not background.get("ok", false) or not foreground.get("ok", false):
		_aiz_error("ROM layout, chunk or tile references could not be rendered.")
		return
	if is_instance_valid(_aiz_world):
		_return_to_preview()
	_aiz_world = Node2D.new()
	_aiz_world.name = "LocalRomAngelIsland"
	add_child(_aiz_world)
	for layer in [background, foreground]:
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(layer["image"])
		sprite.position = Vector2(AIZ_REGION.position) + Vector2(AIZ_REGION.size) * 0.5
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -2 if layer == background else -1
		_aiz_world.add_child(sprite)
	_aiz_ground = floor["points"]
	var polygon := PackedVector2Array(_aiz_ground)
	polygon.append(Vector2(ROUTE_LAST_X, AIZ_REGION.end.y + 40))
	polygon.append(Vector2(ROUTE_FIRST_X, AIZ_REGION.end.y + 40))
	var ground_body := StaticBody2D.new()
	ground_body.name = "RomSampledCollision"
	ground_body.collision_layer = 1
	var ground_shape := CollisionPolygon2D.new()
	ground_shape.polygon = polygon
	ground_body.add_child(ground_shape)
	_aiz_world.add_child(ground_body)
	_aiz_player = Player.new()
	_aiz_player.name = "Sonic"
	_aiz_player.position = Vector2(6904, 1007)
	_aiz_player.checkpoint_position = _aiz_player.position
	_aiz_player.death_y = AIZ_REGION.end.y + 120
	_aiz_world.add_child(_aiz_player)
	var follow_camera = Camera.new()
	follow_camera.target = _aiz_player
	follow_camera.world_bounds = Rect2(AIZ_REGION.position, AIZ_REGION.size)
	follow_camera.follow_speed = 440.0
	_aiz_world.add_child(follow_camera)
	_aiz_camera = follow_camera
	_register_aiz_input("move_left", [KEY_LEFT, KEY_A])
	_register_aiz_input("move_right", [KEY_RIGHT, KEY_D])
	_register_aiz_input("jump", [KEY_SPACE, KEY_UP, KEY_Z])
	_register_aiz_input("roll", [KEY_DOWN, KEY_S, KEY_X])
	_build_aiz_hud()
	_menu_background.hide()
	_menu_frame.hide()
	_update_aiz_frame()
	_aiz_camera.make_current()
	print("AIZ_SLICE_READY profile=", inspected["profile_id"], " cache=", cache["manifest_path"],
		" flat=", floor["flat_samples"], " slope=", floor["slope_samples"], " region=", AIZ_REGION)


func _register_aiz_input(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _build_aiz_hud() -> void:
	_aiz_hud = CanvasLayer.new()
	_aiz_hud.layer = 4
	add_child(_aiz_hud)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aiz_hud.add_child(overlay)
	_aiz_hud_label = Label.new()
	_aiz_hud_label.position = Vector2(16, 12)
	_aiz_hud_label.add_theme_font_size_override("font_size", 17)
	_aiz_hud_label.add_theme_color_override("font_color", Color("f0fcff"))
	overlay.add_child(_aiz_hud_label)
	var back := Button.new()
	back.text = "Back to preview"
	overlay.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -160
	back.offset_right = -12
	back.offset_top = 12
	back.offset_bottom = 48
	back.pressed.connect(_return_to_preview)


func _update_aiz_frame() -> void:
	if not is_instance_valid(_aiz_camera):
		return
	var window_size := get_viewport_rect().size
	var factor := minf(window_size.x / float(AIZ_REGION.size.x), window_size.y / float(AIZ_REGION.size.y))
	_aiz_camera.zoom = Vector2.ONE * factor
	_aiz_camera.snap_to_target()


func _process(_delta: float) -> void:
	if not is_instance_valid(_aiz_player) or not is_instance_valid(_aiz_hud_label):
		return
	var status := "flat"
	if _aiz_player.global_position.x >= 7040:
		status = "slope / crest"
	_aiz_hud_label.text = "ANGEL ISLAND 1 · LOCAL ROM SLICE\nX %.0f  Y %.0f   Speed %.0f  %s\nMove A/D · Jump Space · Esc to exit\nROM art + sampled collision; original contact parity not proven" % [
		_aiz_player.global_position.x, _aiz_player.global_position.y, _aiz_player.velocity.x, status]


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_aiz_world) and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_preview()
		get_viewport().set_input_as_handled()


func _return_to_preview() -> void:
	if is_instance_valid(_aiz_world):
		_aiz_world.queue_free()
	if is_instance_valid(_aiz_hud):
		_aiz_hud.queue_free()
	_aiz_world = null
	_aiz_player = null
	_aiz_camera = null
	_aiz_hud = null
	_aiz_hud_label = null
	_menu_background.show()
	_menu_frame.show()
