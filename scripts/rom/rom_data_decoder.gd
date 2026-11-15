class_name RomDataDecoder
extends RefCounted

## Small, bounded readers for uncompressed Mega Drive graphics data.
## Compression and ROM address resolution belong to separate stages.

const BYTES_PER_4BPP_TILE := 32
const TILE_WIDTH := 8
const TILE_HEIGHT := 8
const PIXELS_PER_BYTE := 2
const MAX_DECODED_TILES := 4096
const MAX_TILE_COLUMNS := 512
const MAX_KOSINSKI_OUTPUT_BYTES := 1024 * 1024


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
			var row_offset := tile_offset + y * (TILE_WIDTH / PIXELS_PER_BYTE)
			for pair_index in range(TILE_WIDTH / PIXELS_PER_BYTE):
				var packed_pixels := data[row_offset + pair_index]
				pixels[y * TILE_WIDTH + pair_index * 2] = (packed_pixels >> 4) & 0x0F
				pixels[y * TILE_WIDTH + pair_index * 2 + 1] = packed_pixels & 0x0F
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


## Decodes the size-prefixed, 16-byte-module Kosinski stream used for tile art.
## The decoder is bounded by both the declared output size and caller limit.
static func decode_moduled_kosinski(data: PackedByteArray, max_output_bytes: int = MAX_KOSINSKI_OUTPUT_BYTES) -> Dictionary:
	if data.size() < 4:
		return _failure("KosinskiM stream is too short to contain its size and first descriptor.")
	if max_output_bytes <= 0 or max_output_bytes > MAX_KOSINSKI_OUTPUT_BYTES:
		return _failure("KosinskiM output limit must be between 1 byte and 1 MiB.")
	var expected_size := (data[0] << 8) | data[1]
	if expected_size <= 0 or expected_size > max_output_bytes:
		return _failure("KosinskiM declared output size exceeds the configured limit.")
	var reader := {"source": data, "cursor": 2, "descriptor": 0, "bits_left": 0}
	var output := PackedByteArray()
	output.resize(expected_size)
	var written := 0
	var operations := 0
	var module_count := 0
	while written < expected_size:
		module_count += 1
		if module_count > 256:
			return _failure("KosinskiM exceeded the module safety limit.")
		var module_start := int(reader["cursor"])
		var module_output_start := written
		while true:
			operations += 1
			if operations > expected_size * 2:
				return _failure("KosinskiM exceeded the command safety limit.")
			var first_bit := _kosinski_pop_bit(reader)
			if not first_bit.get("ok", false):
				return _failure("KosinskiM control stream is truncated.")
			if first_bit["bit"] == 1:
				var literal := _kosinski_read_byte(reader)
				if not literal.get("ok", false):
					return _failure("KosinskiM literal is truncated.")
				if written >= expected_size:
					return _failure("KosinskiM output exceeds its declared size.")
				output[written] = literal["value"]
				written += 1
				continue
			var second_bit := _kosinski_pop_bit(reader)
			if not second_bit.get("ok", false):
				return _failure("KosinskiM control stream is truncated.")
			var count := 0
			var distance := 0
			if second_bit["bit"] == 1:
				var low_result := _kosinski_read_byte(reader)
				var high_result := _kosinski_read_byte(reader)
				if not low_result.get("ok", false) or not high_result.get("ok", false):
					return _failure("KosinskiM long match is truncated.")
				var low: int = low_result["value"]
				var high: int = high_result["value"]
				count = high & 7
				if count == 0:
					var count_result := _kosinski_read_byte(reader)
					if not count_result.get("ok", false):
						return _failure("KosinskiM extended match or terminator is truncated.")
					count = int(count_result["value"])
					if count == 0:
						break
					if count == 1:
						continue
					count += 1
				else:
					count += 2
				distance = 8192 - (((high & 0xF8) << 5) | low)
			else:
				var count_bit_a := _kosinski_pop_bit(reader)
				var count_bit_b := _kosinski_pop_bit(reader)
				var offset_result := _kosinski_read_byte(reader)
				if not count_bit_a.get("ok", false) or not count_bit_b.get("ok", false) or not offset_result.get("ok", false):
					return _failure("KosinskiM short match is truncated.")
				count = (int(count_bit_a["bit"]) << 1) | int(count_bit_b["bit"])
				count += 2
				distance = 256 - int(offset_result["value"])
			if distance <= 0 or distance > written:
				return _failure("KosinskiM match refers outside the decoded output (distance %d at byte %d)." % [distance, written])
			if written + count > expected_size:
				return _failure("KosinskiM match exceeds its declared output size.")
			for _copy_index in range(count):
				output[written] = output[written - distance]
				written += 1
		if written < expected_size:
			if written == module_output_start:
				return _failure("KosinskiM module ended without producing output.")
			var source_cursor := int(reader["cursor"])
			var module_end := (((source_cursor - 2) + 15) & ~15) + 2
			if module_end <= module_start or module_end > data.size():
				return _failure("KosinskiM module padding exceeds the source range.")
			reader["cursor"] = module_end
			reader["bits_left"] = 0
	return {"ok": true, "data": output, "output_size": expected_size, "source_consumed": reader["cursor"]}


static func _kosinski_pop_bit(reader: Dictionary) -> Dictionary:
	if int(reader["bits_left"]) == 0:
		var source: PackedByteArray = reader["source"]
		var cursor := int(reader["cursor"])
		if cursor + 1 >= source.size():
			return {"ok": false}
		reader["descriptor"] = source[cursor] | (source[cursor + 1] << 8)
		reader["cursor"] = cursor + 2
		reader["bits_left"] = 16
	var descriptor := int(reader["descriptor"])
	var bit := descriptor & 1
	reader["descriptor"] = descriptor >> 1
	reader["bits_left"] = int(reader["bits_left"]) - 1
	# Kosinski fetches the next descriptor as soon as all current bits are consumed.
	if int(reader["bits_left"]) == 0:
		var source: PackedByteArray = reader["source"]
		var cursor := int(reader["cursor"])
		if cursor + 1 >= source.size():
			return {"ok": false}
		reader["descriptor"] = source[cursor] | (source[cursor + 1] << 8)
		reader["cursor"] = cursor + 2
		reader["bits_left"] = 16
	return {"ok": true, "bit": bit}


## Ordinary Kosinski streams have neither a size prefix nor module alignment.
static func decode_kosinski(data: PackedByteArray, limit: int = 32768) -> Dictionary:
	if limit < 1 or limit > MAX_KOSINSKI_OUTPUT_BYTES:
		return _failure("Invalid Kosinski output limit.")
	var reader := {"source": data, "cursor": 0, "descriptor": 0, "bits_left": 0}
	var output := PackedByteArray()
	for _operation in range(131072):
		var first := _kosinski_pop_bit(reader)
		if not first.get("ok", false):
			return _failure("Truncated Kosinski descriptor.")
		if first["bit"] == 1:
			var literal := _kosinski_read_byte(reader)
			if not literal.get("ok", false) or output.size() >= limit:
				return _failure("Invalid Kosinski literal or output limit.")
			output.append(int(literal["value"]))
			continue
		var second := _kosinski_pop_bit(reader)
		if not second.get("ok", false):
			return _failure("Truncated Kosinski match.")
		var count := 0
		var distance := 0
		if second["bit"] == 1:
			var low := _kosinski_read_byte(reader)
			var high := _kosinski_read_byte(reader)
			if not low.get("ok", false) or not high.get("ok", false):
				return _failure("Truncated Kosinski long match.")
			distance = 8192 - (((int(high["value"]) & 248) << 5) | int(low["value"]))
			count = int(high["value"]) & 7
			if count == 0:
				var extension := _kosinski_read_byte(reader)
				if not extension.get("ok", false):
					return _failure("Truncated Kosinski extension.")
				count = int(extension["value"])
				if count == 0:
					return {"ok": true, "data": output, "source_consumed": reader["cursor"]}
				if count == 1:
					continue
				count += 1
			else:
				count += 2
		else:
			var bit_a := _kosinski_pop_bit(reader)
			var bit_b := _kosinski_pop_bit(reader)
			var offset := _kosinski_read_byte(reader)
			if not bit_a.get("ok", false) or not bit_b.get("ok", false) or not offset.get("ok", false):
				return _failure("Truncated Kosinski short match.")
			count = (int(bit_a["bit"]) << 1) + int(bit_b["bit"]) + 2
			distance = 256 - int(offset["value"])
		if distance > output.size() or output.size() + count > limit:
			return _failure("Kosinski match outside output bounds.")
		for _copy in range(count):
			output.append(output[output.size() - distance])
	return _failure("Kosinski command limit exceeded.")


static func _kosinski_read_byte(reader: Dictionary) -> Dictionary:
	var source: PackedByteArray = reader["source"]
	var cursor := int(reader["cursor"])
	if cursor >= source.size():
		return {"ok": false}
	reader["cursor"] = cursor + 1
	return {"ok": true, "value": source[cursor]}


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
