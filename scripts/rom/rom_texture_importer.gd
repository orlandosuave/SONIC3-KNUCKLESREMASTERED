class_name RomTextureImporter
extends RefCounted

## Minimal real-ROM proof for AIZ Act 1 intro tile art. These fixed ranges are
## valid only for the exact profile fingerprint checked below.
const Decoder = preload("res://scripts/rom/rom_data_decoder.gd")
const TerrainDecoder = preload("res://scripts/rom/rom_terrain_decoder.gd")
const DECODER_VERSION := TerrainDecoder.DECODER_VERSION
const PROFILE_ID := "sk-s3-lockon-4m-sha256-fba0677f"
const SOURCE_SHA256 := "fba0677fde9f76df93f3e98d6310d8af68b9847bde16e253d73cd4dd8134ed23"
const SCHEMA_VERSION := 1
const IMPORTER_VERSION := 1
const CACHE_ROOT := "user://imports"
const PRIMARY_OFFSET := 0x3A566A
const PRIMARY_SIZE := 3602
const SECONDARY_OFFSET := 0x3A647C
const SECONDARY_SIZE := 12242
const INTRO_PALETTE_OFFSET := 0x28C314
const INTRO_PALETTE_SIZE := 96
const TILE_OUTPUT_LIMIT := 256 * 1024
const PRIMARY_ID := "tiles.aiz.act1.intro.primary"
const SECONDARY_ID := "tiles.aiz.act1.intro.secondary"
const PRIMARY_RELATIVE_PATH := "tiles/aiz_act1_intro_primary.png"
const SECONDARY_RELATIVE_PATH := "tiles/aiz_act1_intro_secondary.png"


static func import_aiz_intro(image_bytes: PackedByteArray) -> Dictionary:
	if image_bytes.size() != RomInspector.SUPPORTED_SIZE:
		return _failure("The texture proof requires the supported 4 MiB ROM image.")
	var source_hash := _hash_bytes(image_bytes)
	if source_hash != SOURCE_SHA256:
		return _failure("This image does not match the supported ROM profile for the AIZ texture proof.")
	var output_user_root := _cache_path()
	var output_absolute_root := ProjectSettings.globalize_path(output_user_root)
	var cached_result := _read_cache(output_absolute_root, output_user_root, source_hash)
	if cached_result.get("ok", false):
		cached_result["cache_hit"] = true
		return cached_result

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

	var parent_user_path := output_user_root.get_base_dir()
	var parent_absolute_path := ProjectSettings.globalize_path(parent_user_path)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(parent_absolute_path)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return _failure("Could not create the local generated-data folder.")
	var temporary_absolute_root := parent_absolute_path.path_join(".import-tmp-%d" % Time.get_ticks_usec())
	var temporary_user_root := output_user_root.get_base_dir().path_join(temporary_absolute_root.get_file())
	mkdir_error = DirAccess.make_dir_recursive_absolute(temporary_absolute_root)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		return _failure("Could not create a temporary import folder.")
	var temporary_tiles := temporary_absolute_root.path_join("tiles")
	mkdir_error = DirAccess.make_dir_recursive_absolute(temporary_tiles)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		_remove_tree(temporary_absolute_root)
		return _failure("Could not create the temporary tile folder.")
	var primary_absolute_path := temporary_absolute_root.path_join(PRIMARY_RELATIVE_PATH)
	var secondary_absolute_path := temporary_absolute_root.path_join(SECONDARY_RELATIVE_PATH)
	if atlases[0].save_png(primary_absolute_path) != OK or atlases[1].save_png(secondary_absolute_path) != OK:
		_remove_tree(temporary_absolute_root)
		return _failure("Could not save the generated AIZ texture previews.")
	var primary_hash := _hash_file(primary_absolute_path)
	var secondary_hash := _hash_file(secondary_absolute_path)
	if primary_hash.is_empty() or secondary_hash.is_empty():
		_remove_tree(temporary_absolute_root)
		return _failure("Could not fingerprint the generated texture previews.")
	var manifest := _make_manifest(source_hash, atlases, outputs, [primary_hash, secondary_hash])
	var manifest_file := FileAccess.open(temporary_absolute_root.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null:
		_remove_tree(temporary_absolute_root)
		return _failure("Could not write the generated-data manifest.")
	manifest_file.store_string(JSON.stringify(manifest, "\t") + "\n")
	manifest_file.close()
	var temporary_check := _read_cache(temporary_absolute_root, temporary_user_root, source_hash)
	if not temporary_check.get("ok", false):
		_remove_tree(temporary_absolute_root)
		return _failure("Generated texture cache did not pass manifest validation.")
	var publish_result := _publish_cache(temporary_absolute_root, output_absolute_root)
	if not publish_result.get("ok", false):
		_remove_tree(temporary_absolute_root)
		return _failure(str(publish_result.get("error", "Could not publish the generated texture cache.")))
	var result := _read_cache(output_absolute_root, output_user_root, source_hash)
	if not result.get("ok", false):
		return _failure("Published texture cache could not be reopened and verified.")
	result["cache_hit"] = false
	return result


## Reopen only fingerprint-verified local generated tiles; never load the ROM from cache.
static func load_aiz_intro_cache(expected_manifest_sha256: String = "") -> Dictionary:
	return _read_cache(ProjectSettings.globalize_path(_cache_path()), _cache_path(), SOURCE_SHA256, expected_manifest_sha256)


static func _cache_path() -> String:
	return CACHE_ROOT.path_join(PROFILE_ID).path_join(SOURCE_SHA256).path_join("%d-%d" % [SCHEMA_VERSION, IMPORTER_VERSION])


static func _make_manifest(source_hash: String, atlases: Array[Image], outputs: Array[Dictionary], file_hashes: Array[String]) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"importer_version": IMPORTER_VERSION,
		"decoder_version": DECODER_VERSION,
		"profile_id": PROFILE_ID,
		"source_sha256": source_hash,
		"resources": [
			{
				"id": PRIMARY_ID,
				"type": "image/png",
				"path": PRIMARY_RELATIVE_PATH,
				"sha256": file_hashes[0],
				"width": atlases[0].get_width(),
				"height": atlases[0].get_height(),
				"tile_count": outputs[0]["tiles"],
				"decoded_bytes": outputs[0]["bytes"],
			},
			{
				"id": SECONDARY_ID,
				"type": "image/png",
				"path": SECONDARY_RELATIVE_PATH,
				"sha256": file_hashes[1],
				"width": atlases[1].get_width(),
				"height": atlases[1].get_height(),
				"tile_count": outputs[1]["tiles"],
				"decoded_bytes": outputs[1]["bytes"],
			},
		],
	}


## A legacy schema-1/1 manifest predates the explicit decoder version field;
## its version is inferred and flagged rather than silently represented as verified.
static func _verify_cache_provenance(manifest: Dictionary, source_hash: String) -> Dictionary:
	if typeof(manifest.get("schema_version")) not in [TYPE_INT, TYPE_FLOAT] or typeof(manifest.get("importer_version")) not in [TYPE_INT, TYPE_FLOAT]:
		return _failure("Texture cache has invalid schema or importer metadata.")
	if manifest["schema_version"] != SCHEMA_VERSION or manifest["importer_version"] != IMPORTER_VERSION:
		return _failure("Texture cache uses a different schema or importer version.")
	if manifest.get("profile_id") != PROFILE_ID or manifest.get("source_sha256") != source_hash or source_hash != SOURCE_SHA256:
		return _failure("Texture cache belongs to a different ROM profile.")
	var legacy_inference := not manifest.has("decoder_version")
	if not legacy_inference and (typeof(manifest["decoder_version"]) not in [TYPE_INT, TYPE_FLOAT] or manifest["decoder_version"] != DECODER_VERSION):
		return _failure("Texture cache decoder version mismatch.")
	return {"ok": true, "decoder_version": DECODER_VERSION, "legacy_decoder_version_inferred": legacy_inference}


static func _read_cache(absolute_root: String, user_root: String, source_hash: String, expected_manifest_sha256: String = "") -> Dictionary:
	var manifest_path := absolute_root.path_join("manifest.json")
	var actual_manifest_sha256 := _hash_file(manifest_path)
	if not expected_manifest_sha256.is_empty() and (expected_manifest_sha256.length() != 64 or actual_manifest_sha256 != expected_manifest_sha256):
		return _failure("Texture cache manifest fingerprint mismatch.")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if manifest_file == null:
		return _failure("Texture cache manifest is missing or unreadable.")
	var parsed := JSON.new()
	if parsed.parse(manifest_file.get_as_text()) != OK:
		manifest_file.close()
		return _failure("Texture cache manifest is malformed.")
	manifest_file.close()
	if not parsed.data is Dictionary:
		return _failure("Texture cache manifest has an invalid root value.")
	var manifest: Dictionary = parsed.data
	var provenance: Dictionary = _verify_cache_provenance(manifest, source_hash)
	if not provenance.get("ok", false):
		return provenance
	var resources: Variant = manifest.get("resources", null)
	if not resources is Array or resources.size() != 2:
		return _failure("Texture cache does not list both AIZ tile atlases.")
	var expected_ids := [PRIMARY_ID, SECONDARY_ID]
	var expected_paths := [PRIMARY_RELATIVE_PATH, SECONDARY_RELATIVE_PATH]
	var images: Array[Image] = []
	var verified: Array[Dictionary] = []
	for index in range(2):
		if not resources[index] is Dictionary:
			return _failure("Texture cache contains an invalid resource entry.")
		var resource: Dictionary = resources[index]
		if resource.get("id") != expected_ids[index] or resource.get("path") != expected_paths[index] or resource.get("type") != "image/png":
			return _failure("Texture cache resource index does not match the expected AIZ proof.")
		for number in ["width", "height", "tile_count", "decoded_bytes"]:
			if typeof(resource.get(number)) not in [TYPE_INT, TYPE_FLOAT] or float(resource[number]) <= 0.0 or float(resource[number]) != float(int(resource[number])):
				return _failure("Texture cache resource dimensions or tile metadata are invalid.")
		if int(resource["tile_count"]) * 32 != int(resource["decoded_bytes"]):
			return _failure("Texture cache resource tile count does not match decoded bytes.")
		var relative_path := str(resource["path"])
		if relative_path.is_absolute_path() or relative_path.contains(".."):
			return _failure("Texture cache contains an unsafe output path.")
		var absolute_path := absolute_root.path_join(relative_path)
		var expected_file_hash := str(resource.get("sha256", ""))
		if expected_file_hash.length() != 64 or _hash_file(absolute_path) != expected_file_hash:
			return _failure("A cached texture is missing or its fingerprint does not match.")
		var image := Image.load_from_file(absolute_path)
		if image.is_empty() or image.get_width() != int(resource.get("width", 0)) or image.get_height() != int(resource.get("height", 0)):
			return _failure("A cached texture has invalid image data or dimensions.")
		images.append(image)
		verified.append(resource)
	return {
		"ok": true,
		"primary_image": images[0],
		"primary_path": user_root.path_join(PRIMARY_RELATIVE_PATH),
		"secondary_path": user_root.path_join(SECONDARY_RELATIVE_PATH),
		"primary_tiles": verified[0]["tile_count"],
		"secondary_tiles": verified[1]["tile_count"],
		"primary_bytes": verified[0]["decoded_bytes"],
		"secondary_bytes": verified[1]["decoded_bytes"],
		"palette_line": 0,
		"manifest_path": user_root.path_join("manifest.json"),
		"manifest_sha256": actual_manifest_sha256,
		"profile_id": PROFILE_ID,
		"source_sha256": source_hash,
		"schema_version": SCHEMA_VERSION,
		"importer_version": IMPORTER_VERSION,
		"decoder_version": provenance["decoder_version"],
		"legacy_decoder_version_inferred": provenance["legacy_decoder_version_inferred"],
		"resource_manifest": verified.duplicate(true),
	}


static func _publish_cache(temporary_root: String, final_root: String) -> Dictionary:
	var parent := final_root.get_base_dir()
	var backup_root := parent.path_join(".import-backup-%d" % Time.get_ticks_usec())
	var has_previous := DirAccess.dir_exists_absolute(final_root)
	if has_previous:
		var backup_error := DirAccess.rename_absolute(final_root, backup_root)
		if backup_error != OK:
			return _failure("Could not safely stage the previous local cache.")
	var publish_error := DirAccess.rename_absolute(temporary_root, final_root)
	if publish_error != OK:
		if has_previous:
			DirAccess.rename_absolute(backup_root, final_root)
		return _failure("Could not publish the completed local cache.")
	if has_previous:
		var cleanup_error := _remove_tree(backup_root)
		if cleanup_error != OK:
			return _failure("The new texture cache was published, but the previous cache could not be fully removed.")
	return {"ok": true}


static func _remove_tree(absolute_root: String) -> Error:
	if not DirAccess.dir_exists_absolute(absolute_root):
		return OK
	var directory := DirAccess.open(absolute_root)
	if directory == null:
		return DirAccess.get_open_error()
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := absolute_root.path_join(entry)
			if directory.current_is_dir():
				var remove_error := _remove_tree(child)
				if remove_error != OK:
					directory.list_dir_end()
					return remove_error
			else:
				var remove_error := DirAccess.remove_absolute(child)
				if remove_error != OK:
					directory.list_dir_end()
					return remove_error
		entry = directory.get_next()
	directory.list_dir_end()
	var parent := absolute_root.get_base_dir()
	var directory_name := absolute_root.get_file()
	var parent_access := DirAccess.open(parent)
	if parent_access == null:
		return DirAccess.get_open_error()
	return parent_access.remove(directory_name)


static func _hash_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(data) != OK:
		return ""
	return context.finish().hex_encode().to_lower()


static func _hash_file(absolute_path: String) -> String:
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return ""
	var data := file.get_buffer(file.get_length())
	file.close()
	return _hash_bytes(data)


static func _slice(source: PackedByteArray, offset: int, count: int) -> PackedByteArray:
	if offset < 0 or count <= 0 or offset + count > source.size():
		return PackedByteArray()
	return source.slice(offset, offset + count)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
