class_name RomDataDecoder
extends RefCounted

## Small, bounded readers for uncompressed Mega Drive graphics data.
## Compression and ROM address resolution belong to separate stages.

const BYTES_PER_4BPP_TILE := 32
const TILE_WIDTH := 8
const TILE_HEIGHT := 8
const MAX_DECODED_TILES := 4096
const MAX_TILE_COLUMNS := 512


static func decode_4bpp_tiles(data: PackedByteArray, max_tiles: int = 4096) -> Dictionary:
	if max_tiles <= 0 or max_tiles > MAX_DECODED_TILES:
		return _failure("Tile limit must be between 1 and 4096.")
	if data.is_empty():
		return _failure("Tile data is empty.")
	if data.size() % BYTES_PER_4BPP_TILE != 0:
		return _failure("Tile data length must be a multiple of 32 bytes.")
	var tile_count := data.size() / BYTES_PER_4BPP_TILE
	if tile_count > max_tiles:
		return _failure("Tile data exceeds the configured tile limit.")

	var tiles: Array[PackedByteArray] = []
	for tile_index in range(tile_count):
		var pixels := PackedByteArray()
		pixels.resize(TILE_WIDTH * TILE_HEIGHT)
		var tile_offset := tile_index * BYTES_PER_4BPP_TILE
		for y in range(TILE_HEIGHT):
			var row_offset := tile_offset + y * 4
			for x in range(TILE_WIDTH):
				var color_index := 0
				# Each row stores one byte per bitplane; the most significant bit
				# is the leftmost pixel, and plane 0 is the low color-index bit.
				for plane in range(4):
					var plane_bit := (data[row_offset + plane] >> (7 - x)) & 1
					color_index |= plane_bit << plane
				pixels[y * TILE_WIDTH + x] = color_index
		tiles.append(pixels)
	return {"ok": true, "tile_count": tile_count, "tiles": tiles}


static func decode_palette_4bpp(data: PackedByteArray, max_colors: int = 256) -> Dictionary:
	if max_colors <= 0:
		return _failure("Palette limit must be positive.")
	if data.is_empty():
		return _failure("Palette data is empty.")
	if data.size() % 2 != 0:
		return _failure("Palette data length must contain complete 16-bit color words.")
	var color_count := data.size() / 2
	if color_count > max_colors:
		return _failure("Palette data exceeds the configured color limit.")

	var colors := PackedColorArray()
	for index in range(color_count):
		var word := (data[index * 2] << 8) | data[index * 2 + 1]
		var red := _expand_3bit((word >> 1) & 0x07)
		var green := _expand_3bit((word >> 5) & 0x07)
		var blue := _expand_3bit((word >> 9) & 0x07)
		colors.append(Color(red / 255.0, green / 255.0, blue / 255.0, 1.0))
	return {"ok": true, "color_count": color_count, "colors": colors}


static func compose_tile_image(tiles: Array[PackedByteArray], tile_columns: int, palette: PackedColorArray) -> Dictionary:
	if tiles.is_empty():
		return _failure("At least one decoded tile is required.")
	if tile_columns <= 0:
		return _failure("Tile columns must be positive.")
	if tile_columns > MAX_TILE_COLUMNS or tiles.size() > MAX_DECODED_TILES:
		return _failure("Tile atlas exceeds the configured size limit.")
	if palette.is_empty() or palette.size() > 16:
		return _failure("A palette of 1 to 16 colors is required.")
	for tile in tiles:
		if tile.size() != TILE_WIDTH * TILE_HEIGHT:
			return _failure("A decoded tile has an invalid pixel count.")
	var rows := int(ceil(float(tiles.size()) / float(tile_columns)))
	var image := Image.create(tile_columns * TILE_WIDTH, rows * TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	for tile_index in range(tiles.size()):
		var origin := Vector2i((tile_index % tile_columns) * TILE_WIDTH, int(tile_index / tile_columns) * TILE_HEIGHT)
		for y in range(TILE_HEIGHT):
			for x in range(TILE_WIDTH):
				var color_index := tiles[tile_index][y * TILE_WIDTH + x]
				if color_index >= palette.size():
					return _failure("Palette does not contain a referenced tile color index.")
				image.set_pixel(origin.x + x, origin.y + y, palette[color_index])
	return {"ok": true, "image": image, "width": image.get_width(), "height": image.get_height()}


static func _expand_3bit(value: int) -> int:
	return (value << 5) | (value << 2) | (value >> 1)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
