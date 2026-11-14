class_name RomTextureImporter
extends RefCounted

## Minimal real-ROM proof for AIZ Act 1 intro tile art. Offsets were verified
## by matching complete disassembly resource ranges against the supported image.
const Decoder = preload("res://scripts/rom/rom_data_decoder.gd")
const PROFILE_FOLDER := "user://imports/sk-s3-lockon-4m-sha256-fba0677f"
const PRIMARY_OFFSET := 0x3A566A
const PRIMARY_SIZE := 3602
const SECONDARY_OFFSET := 0x3A647C
const SECONDARY_SIZE := 12242
const INTRO_PALETTE_OFFSET := 0x28C314
const INTRO_PALETTE_SIZE := 96
const TILE_OUTPUT_LIMIT := 256 * 1024


static func import_aiz_intro(image_bytes: PackedByteArray) -> Dictionary:
	if image_bytes.size() != RomInspector.SUPPORTED_SIZE:
		return _failure("The texture proof requires the supported 4 MiB ROM image.")
	var primary_stream := _slice(image_bytes, PRIMARY_OFFSET, PRIMARY_SIZE)
	var secondary_stream := _slice(image_bytes, SECONDARY_OFFSET, SECONDARY_SIZE)
	var palette_bytes := _slice(image_bytes, INTRO_PALETTE_OFFSET, INTRO_PALETTE_SIZE)
	if primary_stream.is_empty() or secondary_stream.is_empty() or palette_bytes.is_empty():
		return _failure("An AIZ texture source range is outside the selected image.")
	var palette_result: Dictionary = Decoder.decode_palette_4bpp(palette_bytes)
	if not palette_result.get("ok", false):
		return _failure(str(palette_result.get("error", "Could not decode AIZ palette.")))
	var palette: PackedColorArray = palette_result["colors"]
	var palette_line := PackedColorArray()
	for index in range(16):
		palette_line.append(palette[index])
	var atlases: Array[Image] = []
	var outputs: Array[Dictionary] = []
	for stream in [primary_stream, secondary_stream]:
		var decompressed: Dictionary = Decoder.decode_moduled_kosinski(stream, TILE_OUTPUT_LIMIT)
		if not decompressed.get("ok", false):
			return _failure(str(decompressed.get("error", "Could not decompress AIZ tile art.")))
		var decoded_tiles: Dictionary = Decoder.decode_4bpp_tiles(decompressed["data"])
		if not decoded_tiles.get("ok", false):
			return _failure(str(decoded_tiles.get("error", "Could not unpack AIZ tile art.")))
		var atlas_result: Dictionary = Decoder.compose_tile_image(decoded_tiles["tiles"], 16, palette_line)
		if not atlas_result.get("ok", false):
			return _failure(str(atlas_result.get("error", "Could not compose AIZ tile atlas.")))
		atlases.append(atlas_result["image"])
		outputs.append({"bytes": decompressed["output_size"], "tiles": decoded_tiles["tile_count"]})
	var folder_path := ProjectSettings.globalize_path(PROFILE_FOLDER)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(folder_path)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return _failure("Could not create the local generated-data folder.")
	var primary_path := PROFILE_FOLDER.path_join("aiz_act1_intro_primary.png")
	var secondary_path := PROFILE_FOLDER.path_join("aiz_act1_intro_secondary.png")
	var primary_save := atlases[0].save_png(ProjectSettings.globalize_path(primary_path))
	var secondary_save := atlases[1].save_png(ProjectSettings.globalize_path(secondary_path))
	if primary_save != OK or secondary_save != OK:
		return _failure("Could not save the generated AIZ texture previews.")
	return {
		"ok": true,
		"primary_image": atlases[0],
		"primary_path": primary_path,
		"secondary_path": secondary_path,
		"primary_tiles": outputs[0]["tiles"],
		"secondary_tiles": outputs[1]["tiles"],
		"primary_bytes": outputs[0]["bytes"],
		"secondary_bytes": outputs[1]["bytes"],
		"palette_line": 0,
	}


static func _slice(source: PackedByteArray, offset: int, count: int) -> PackedByteArray:
	if offset < 0 or count <= 0 or offset + count > source.size():
		return PackedByteArray()
	return source.slice(offset, offset + count)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
