extends Control

const Decoder = preload("res://scripts/rom/rom_data_decoder.gd")


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("101827")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

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
	center.add_child(panel)

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
