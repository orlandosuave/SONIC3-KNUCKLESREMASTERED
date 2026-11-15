class_name RomTerrainDecoder
extends RefCounted

## Original-coordinate terrain data. No engine objects, cache writes or emulation.
const Decoder = preload("res://scripts/rom/rom_data_decoder.gd")
const Inspector = preload("res://scripts/rom/rom_inspector.gd")

# Helper to extract data based on source
static func get_data_source(rom_input: PackedByteArray, override_data: Dictionary) -> PackedByteArray:
	if override_data != null and override_data.has("data"):
		return override_data.data
	return rom_input

static func word(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])

static func decode_layout(data: PackedByteArray) -> Dictionary:
	if data.size() < 136 or data.size() > 4096:
		return {"ok": false, "error": "Layout must fit its original RAM span."}
	var result := {"ok": true}
	for layer in range(2):
		var width := word(data, layer * 2)
		var height := word(data, 4 + layer * 2)
		if width < 1 or width > 3960 or height < 1 or height > 32:
			return {"ok": false, "error": "Invalid layout dimensions."}
		var rows: Array[PackedByteArray] = []
		for row in range(height):
			var offset := word(data, 8 + row * 4 + layer * 2) - 32768
			if offset < 136 or offset + width > data.size():
				return {"ok": false, "error": "Layout row points outside its payload."}
			rows.append(data.slice(offset, offset + width))
		result["foreground" if layer == 0 else "background"] = {
			"width_chunks": width, "height_chunks": height, "rows": rows}
	return result

static func decode_aiz_main(rom: PackedByteArray, data_source_override: Dictionary = {}) -> Dictionary:
	var data_source = get_data_source(rom, data_source_override)

	if data_source.size() != Inspector.SUPPORTED_SIZE:
		return {"ok": false, "error": "Terrain requires the supported ROM profile."}
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(data_source)
	if hash_context.finish().hex_encode() != Inspector.SUPPORTED_SHA256:
		return {"ok": false, "error": "Terrain ROM fingerprint mismatch."}
	var result := decode_layout(data_source.slice(0x281420, 0x281420 + 2124))
	if not result["ok"]:
		return result
	var blocks := PackedByteArray()
	for resource in [[0x3A374A, 512], [0x3A458A, 4320], [0x3ABC40, 14736]]:
		var decoded := Decoder.decode_kosinski(data_source.slice(resource[0], resource[0] + resource[1]))
		if not decoded["ok"]:
			return decoded
		if resource[0] == 0x3ABC40:
			result["chunks"] = decoded["data"]
		else:
			blocks.append_array(decoded["data"])
	result["blocks"] = blocks
	var tiles := PackedByteArray()
	for resource in [[0x3A566A, 3602], [0x3A944E, 10226]]:
		var decoded := Decoder.decode_moduled_kosinski(data_source.slice(resource[0], resource[0] + resource[1]))
		if not decoded["ok"]:
			return decoded
		tiles.append_array(decoded["data"])
	result["tiles"] = tiles
	var palette := data_source.slice(0x28C234, 0x28C254)
	palette.append_array(data_source.slice(0x28C374, 0x28C3D4))
	result["palette"] = palette
	result["collision_primary"] = PackedByteArray()
	result["collision_secondary"] = PackedByteArray()
	for i in range(768):
		result["collision_primary"].append(data_source[0x274761 + i * 2])
		result["collision_secondary"].append(data_source[0x274D61 + i * 2])
	result["heights"] = data_source.slice(0x96100, 0x97100)
	result["rotated_heights"] = data_source.slice(0x97100, 0x98100)
	result["angles"] = data_source.slice(0x96000, 0x96100)
	result["schema_version"] = 1
	result["variant"] = "aiz_main_static"
	return result

static func sample_pixel(bundle: Dictionary, layer_name: String, position: Vector2i) -> Dictionary:
	if not bundle.get("ok", false) or not bundle.has(layer_name):
		return {"ok": false, "error": "Missing decoded terrain layer."}
	var layer: Dictionary = bundle[layer_name]
	if position.x < 0 or position.y < 0 or position.x >= int(layer["width_chunks"]) * 128 or position.y >= int(layer["height_chunks"]) * 128:
		return {"ok": false, "error": "Terrain sample outside layout."}
	var row: PackedByteArray = layer["rows"][position.y / 128]
	var chunk_id: int = row[position.x / 128]
	var chunks: PackedByteArray = bundle["chunks"]
	var chunk_offset := chunk_id * 128 + ((position.y % 128) / 16 * 8 + (position.x % 128) / 16) * 2
	if chunk_offset + 2 > chunks.size():
		return {"ok": false, "error": "Missing chunk definition."}
	var chunk_word := word(chunks, chunk_offset)
	var block_id := chunk_word & 1023
	var bx := position.x % 16
	var by := position.y % 16
	if chunk_word & 1024:
		bx = 15 - bx
	if chunk_word & 2048:
		by = 15 - by
	var blocks: PackedByteArray = bundle["blocks"]
	var block_offset := block_id * 8 + (by / 8 * 2 + bx / 8) * 2
	if block_offset + 2 > blocks.size():
		return {"ok": false, "error": "Missing block definition."}
	var tile_word := word(blocks, block_offset)
	var tx := bx % 8
	var ty := by % 8
	if tile_word & 2048:
		tx = 7 - tx
	if tile_word & 4096:
		ty = 7 - ty
	var tiles: PackedByteArray = bundle["tiles"]
	var tile_offset := (tile_word & 2047) * 32 + ty * 4 + tx / 2
	if tile_offset >= tiles.size():
		return {"ok": false, "error": "Required tile upload is not present in this static state."}
	var color := (int(tiles[tile_offset]) >> (4 if tx % 2 == 0 else 0)) & 15
	return {"ok": true, "palette_index": ((tile_word >> 13) & 3) * 16 + color,
		"transparent": color == 0, "priority": bool(tile_word & 32768),
		"block_id": block_id, "solidity": (chunk_word >> 12) & 15}

static func render_region(bundle: Dictionary, layer_name: String, region: Rect2i) -> Dictionary:
	if region.size.x <= 0 or region.size.y <= 0 or region.size.x > 2048 or region.size.y > 2048:
		return {"ok": false, "error": "Invalid terrain preview dimensions."}
	var palette := Decoder.decode_palette_4bpp(bundle["palette"])
	if not palette["ok"]:
		return palette
	var image := Image.create(region.size.x, region.size.y, false, Image.FORMAT_RGBA8)
	for y in range(region.size.y):
		for x in range(region.size.x):
			var pixel := sample_pixel(bundle, layer_name, region.position + Vector2i(x, y))
			if not pixel["ok"]:
				return pixel
			var color: Color = palette["colors"][pixel["palette_index"]]
			if pixel["transparent"]:
				color.a = 0.0
			image.set_pixel(x, y, color)
	return {"ok": true, "image": image}
