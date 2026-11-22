extends Control

const Decoder = preload("res://scripts/rom/rom_data_decoder.gd")
const Inspector = preload("res://scripts/rom/rom_inspector.gd")
const Terrain = preload("res://scripts/rom/rom_terrain_decoder.gd")
const Collision = preload("res://scripts/gameplay/rom_terrain_collision.gd")
const TextureImporter = preload("res://scripts/rom/rom_texture_importer.gd")
const Player = preload("res://scripts/gameplay/player_controller.gd")
const Camera = preload("res://scripts/gameplay/prototype_camera.gd")
# Pixel-perfect 32:9: 2560 x 720 source-world pixels at 2x = 5120 x 1440.
# The terrain must be rendered across this entire region; no 576-pixel crop zoom.
const TARGET_DISPLAY_SIZE := Vector2i(5120, 1440)
const WORLD_PIXEL_SCALE := 2.0
const AIZ_REGION := Rect2i(5760, 560, 2560, 720)
const AIZ_STRIP_WIDTH := 512
const ROUTE_FIRST_X := 6880
const ROUTE_LAST_X := 7264
# Local supported-ROM 8px ground scan verifies x7264..7480 at y975..978.
# x7488..7552 lacks primary-floor samples; never bridge that unknown gap.
# This is only the next bounded proposal, not an extended playable route.
const NEXT_ROUTE_FIRST_X := ROUTE_LAST_X
const NEXT_ROUTE_LAST_VERIFIED_X := 7480

var _menu_background: ColorRect
var _menu_frame: Control
var _aiz_dialog: FileDialog
var _aiz_status: Label
var _aiz_world: Node2D
var _aiz_player: PrototypePlayer
var _aiz_camera: Camera2D
var _aiz_hud: CanvasLayer
var _aiz_hud_label: Label
var _aiz_native_button: Button
var _aiz_restore_window_mode := -1
var _aiz_restore_window_screen := -1
var _aiz_restore_window_size := Vector2i.ZERO
var _aiz_ground: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	get_viewport().size_changed.connect(_update_aiz_frame)
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
	var background: Dictionary = _render_aiz_layer(bundle, "background")
	var foreground: Dictionary = _render_aiz_layer(bundle, "foreground")
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


# The original 2,048px render bound stays intact; compose five independently
# validated 512px source strips to render every visible 32:9 world pixel.
# Missing ROM assets fail the render rather than repeating or inventing tiles.
static func _render_aiz_layer(bundle: Dictionary, layer_name: String) -> Dictionary:
	var canvas := Image.create(AIZ_REGION.size.x, AIZ_REGION.size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	for offset in range(0, AIZ_REGION.size.x, AIZ_STRIP_WIDTH):
		var strip_size := Vector2i(mini(AIZ_STRIP_WIDTH, AIZ_REGION.size.x - offset), AIZ_REGION.size.y)
		var strip_region := Rect2i(AIZ_REGION.position + Vector2i(offset, 0), strip_size)
		var rendered: Dictionary = Terrain.render_region(bundle, layer_name, strip_region)
		if not rendered.get("ok", false):
			return {"ok": false, "error": "%s strip at x%d: %s" % [
				layer_name, strip_region.position.x, rendered.get("error", "unavailable tile")]}
		canvas.blit_rect(rendered["image"], Rect2i(Vector2i.ZERO, strip_size), Vector2i(offset, 0))
	return {"ok": true, "image": canvas, "strip_count": ceili(float(AIZ_REGION.size.x) / AIZ_STRIP_WIDTH)}


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
	_aiz_native_button = Button.new()
	_aiz_native_button.text = "Native 5120 x 1440"
	_aiz_native_button.tooltip_text = "Fullscreen only on a connected 5120 x 1440 display"
	_aiz_native_button.disabled = _native_ultrawide_screen() < 0
	overlay.add_child(_aiz_native_button)
	_aiz_native_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_aiz_native_button.offset_left = -374
	_aiz_native_button.offset_right = -174
	_aiz_native_button.offset_top = 12
	_aiz_native_button.offset_bottom = 48
	_aiz_native_button.pressed.connect(_enter_native_ultrawide)


# Fullscreen is never selected automatically on a smaller display, and no
# physical 5120x1440 claim is inferred from an offscreen framebuffer alone.
static func _is_native_ultrawide_screen(size: Vector2i) -> bool:
	return size == TARGET_DISPLAY_SIZE


func _native_ultrawide_screen() -> int:
	var current := get_window().current_screen
	if current >= 0 and current < DisplayServer.get_screen_count() and _is_native_ultrawide_screen(DisplayServer.screen_get_size(current)):
		return current
	for index in range(DisplayServer.get_screen_count()):
		if _is_native_ultrawide_screen(DisplayServer.screen_get_size(index)):
			return index
	return -1


func _enter_native_ultrawide() -> void:
	if _aiz_restore_window_mode >= 0:
		return
	var screen := _native_ultrawide_screen()
	if screen < 0:
		_aiz_error("A native 5120 x 1440 display is not connected. Keeping the current window mode.")
		return
	var window := get_window()
	_aiz_restore_window_mode = window.mode
	_aiz_restore_window_screen = window.current_screen
	_aiz_restore_window_size = window.size
	# Do not reset an already-windowed display just before requesting
	# fullscreen; that transition can asynchronously minimize the host.
	if window.current_screen != screen:
		if window.mode != Window.MODE_WINDOWED:
			window.mode = Window.MODE_WINDOWED
		window.current_screen = screen
		await get_tree().process_frame
		if _aiz_restore_window_mode < 0 or not is_instance_valid(_aiz_world):
			return
	window.mode = Window.MODE_FULLSCREEN
	await get_tree().process_frame
	await get_tree().process_frame
	if _aiz_restore_window_mode < 0 or not is_instance_valid(_aiz_world):
		return
	# On Windows the first transition may be superseded by a pending
	# minimize/windowed event; make at most one bounded retry.
	if window.mode != Window.MODE_FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN
		await get_tree().process_frame
	if window.mode != Window.MODE_FULLSCREEN or window.size != TARGET_DISPLAY_SIZE:
		_restore_aiz_window()
		_aiz_error("Native 5120 x 1440 fullscreen could not be activated. Window mode restored.")
		return
	_update_aiz_frame()


func _restore_aiz_window() -> void:
	if _aiz_restore_window_mode < 0:
		return
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.current_screen = _aiz_restore_window_screen
	window.size = _aiz_restore_window_size
	window.mode = _aiz_restore_window_mode
	_aiz_restore_window_mode = -1


# Scaling the viewport, not stretching Sonic or terrain: a 5120x1440
# window produces exactly two screen pixels per one world pixel.
static func _aiz_zoom_for_viewport(view_size: Vector2) -> Vector2:
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2.ONE
	var factor := minf(view_size.x / float(AIZ_REGION.size.x), view_size.y / float(AIZ_REGION.size.y))
	return Vector2.ONE * factor


func _update_aiz_frame() -> void:
	if not is_instance_valid(_aiz_camera):
		return
	_aiz_camera.zoom = _aiz_zoom_for_viewport(get_viewport_rect().size)
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
	_restore_aiz_window()
	if is_instance_valid(_aiz_world):
		_aiz_world.queue_free()
	if is_instance_valid(_aiz_hud):
		_aiz_hud.queue_free()
	_aiz_world = null
	_aiz_player = null
	_aiz_camera = null
	_aiz_hud = null
	_aiz_hud_label = null
	_aiz_native_button = null
	_menu_background.show()
	_menu_frame.show()
