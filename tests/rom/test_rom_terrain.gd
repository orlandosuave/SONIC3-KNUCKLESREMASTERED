extends SceneTree

const Terrain = preload("res://scripts/rom/rom_terrain_decoder.gd")
const Decoder = preload("res://scripts/rom/rom_data_decoder.gd")
const Inspector = preload("res://scripts/rom/rom_inspector.gd")
const Collision = preload("res://scripts/gameplay/rom_terrain_collision.gd")
const AizPreview = preload("res://scripts/ui/decoder_preview.gd")
const FollowCamera = preload("res://scripts/gameplay/prototype_camera.gd")
const TextureImporter = preload("res://scripts/rom/rom_texture_importer.gd")


func _initialize() -> void:
	var frame: Rect2i = AizPreview.AIZ_REGION
	assert(frame.size.x * 9 == frame.size.y * 32)
	assert(frame.has_point(Vector2i(AizPreview.ROUTE_FIRST_X, 1007)))
	assert(frame.has_point(Vector2i(AizPreview.ROUTE_LAST_X, 975)))
	var bounds := Rect2(frame.position, frame.size)
	var center := FollowCamera.bounded_center(Vector2(99999, 99999), Vector2(frame.size), bounds)
	assert(center == bounds.get_center())
	print("PASS: AIZ 32:9 framing bounds both flat and uphill ROM-sampled terrain")
	assert(AizPreview.TARGET_DISPLAY_SIZE == Vector2i(5120, 1440))
	assert(AizPreview.AIZ_REGION.size == Vector2i(2560, 720))
	assert(AizPreview._aiz_zoom_for_viewport(Vector2(5120, 1440)) == Vector2(2, 2))
	assert(AizPreview._aiz_zoom_for_viewport(Vector2(1600, 450)) == Vector2(0.625, 0.625))
	assert(Vector2(AizPreview.TARGET_DISPLAY_SIZE) == Vector2(AizPreview.AIZ_REGION.size) * AizPreview.WORLD_PIXEL_SCALE)
	print("PASS: 5120x1440 covers 2560x720 source world at 2x with no stretch")
	_test_tile_palette_flips_priority()
	assert(AizPreview.NEXT_ROUTE_FIRST_X == AizPreview.ROUTE_LAST_X)
	assert(AizPreview.NEXT_ROUTE_LAST_VERIFIED_X - AizPreview.NEXT_ROUTE_FIRST_X <= 256)
	assert(AizPreview.NEXT_ROUTE_LAST_VERIFIED_X == 7480)
	print("PASS: follow-up AIZ route stops before unsupported ground at x7488")
	assert(TextureImporter.DECODER_VERSION == Terrain.DECODER_VERSION)
	var manifest_meta := {
		"schema_version": TextureImporter.SCHEMA_VERSION,
		"importer_version": TextureImporter.IMPORTER_VERSION,
		"profile_id": TextureImporter.PROFILE_ID,
		"source_sha256": TextureImporter.SOURCE_SHA256,
		"decoder_version": TextureImporter.DECODER_VERSION,
	}
	var valid_meta: Dictionary = TextureImporter._verify_cache_provenance(manifest_meta, TextureImporter.SOURCE_SHA256)
	assert(valid_meta["ok"] and not valid_meta["legacy_decoder_version_inferred"])
	var bad_meta := manifest_meta.duplicate(true)
	bad_meta["profile_id"] = "unsupported-profile"
	assert(not TextureImporter._verify_cache_provenance(bad_meta, TextureImporter.SOURCE_SHA256)["ok"])
	bad_meta = manifest_meta.duplicate(true)
	bad_meta["source_sha256"] = "invalid-source"
	assert(not TextureImporter._verify_cache_provenance(bad_meta, TextureImporter.SOURCE_SHA256)["ok"])
	bad_meta = manifest_meta.duplicate(true)
	bad_meta["decoder_version"] = TextureImporter.DECODER_VERSION + 1
	assert(not TextureImporter._verify_cache_provenance(bad_meta, TextureImporter.SOURCE_SHA256)["ok"])
	bad_meta = manifest_meta.duplicate(true)
	bad_meta.erase("decoder_version")
	var legacy_meta: Dictionary = TextureImporter._verify_cache_provenance(bad_meta, TextureImporter.SOURCE_SHA256)
	assert(legacy_meta["ok"] and legacy_meta["legacy_decoder_version_inferred"])
	print("PASS: AIZ cache provenance rejects wrong profile, hash and decoder version")
	var collision_bundle := {
		"foreground": {"width_chunks": 1, "height_chunks": 1, "rows": [PackedByteArray([0])]},
		"chunks": PackedByteArray([0, 0])
	}
	var missing_chunks := collision_bundle.duplicate(true)
	missing_chunks.erase("chunks")
	assert(not Collision._height(missing_chunks, Vector2i.ZERO, 0, 0)["ok"])
	print("PASS: missing chunks returns ok:false")
	var wrong_buffer := collision_bundle.duplicate(true)
	wrong_buffer["chunks"] = [0, 0]
	assert(not Collision._height(wrong_buffer, Vector2i.ZERO, 0, 0)["ok"])
	print("PASS: wrong buffer type returns ok:false")
	var truncated := collision_bundle.duplicate(true)
	truncated["chunks"] = PackedByteArray([0])
	assert(not Collision._height(truncated, Vector2i.ZERO, 0, 0)["ok"])
	print("PASS: one-byte-short word returns ok:false")
	var last_word := collision_bundle.duplicate(true)
	last_word["chunks"] = PackedByteArray([0xff, 0xff, 0, 0])
	var complete := Collision._height(last_word, Vector2i(16, 0), 0, 0)
	assert(complete["ok"] and complete["block_id"] == 0)
	print("PASS: last complete word succeeds")
	var empty := Collision._height(collision_bundle, Vector2i.ZERO, 0, 0)
	assert(empty["ok"] and empty["height"] == 0 and empty["block_id"] == 0)
	print("PASS: empty block preserves height zero")
	var probe_chunks := PackedByteArray()
	probe_chunks.resize(128)
	var probe_bundle := {
		"ok": true, "foreground": {"width_chunks": 1, "height_chunks": 1, "rows": [PackedByteArray([0])]},
		"chunks": probe_chunks}
	for active_path in [0, 1]:
		var floor_probe := Collision.find_floor(probe_bundle, Vector2i(1, 1), active_path, 77)
		var wall_probe := Collision.find_right_wall(probe_bundle, Vector2i(1, 1), active_path, 77)
		assert(floor_probe["ok"] and floor_probe["distance"] == 30 and floor_probe["angle"] == 77)
		assert(wall_probe["ok"] and wall_probe["distance"] == 30 and wall_probe["angle"] == 77)
	print("PASS: valid floor and right-wall paths preserve neighbor distance and angle")
	for invalid_flag in [null, false, 0, 1, "true", [], {}]:
		var invalid_bundle := probe_bundle.duplicate(true)
		invalid_bundle["ok"] = invalid_flag
		var rejected_floor := Collision.find_floor(invalid_bundle, Vector2i(1, 1))
		var rejected_wall := Collision.find_right_wall(invalid_bundle, Vector2i(1, 1))
		assert(not rejected_floor["ok"] and rejected_floor.has("error"))
		assert(not rejected_wall["ok"] and rejected_wall.has("error"))
	var missing_flag := probe_bundle.duplicate(true)
	missing_flag.erase("ok")
	assert(not Collision.find_floor(missing_flag, Vector2i(1, 1))["ok"])
	assert(not Collision.find_right_wall(missing_flag, Vector2i(1, 1))["ok"])
	print("PASS: both public probes reject malformed, missing and false success flags")
	for invalid_path in [-1, 2]:
		var rejected_height := Collision._height(probe_bundle, Vector2i.ZERO, invalid_path, 0)
		assert(not rejected_height["ok"] and rejected_height.has("error"))
		assert(not Collision.find_floor(probe_bundle, Vector2i.ZERO, invalid_path)["ok"])
		assert(not Collision.find_right_wall(probe_bundle, Vector2i.ZERO, invalid_path)["ok"])
	print("PASS: internal and public floor/right-wall probes reject invalid collision paths")
	for invalid_wall_path in [-1, 2]:
		var rejected_wall_height := Collision._wall_height(probe_bundle, Vector2i.ZERO, invalid_wall_path, 0)
		assert(not rejected_wall_height["ok"] and rejected_wall_height.has("error"))
	print("PASS: private wall height rejects invalid paths without runtime errors")
	var positive_heights := PackedByteArray()
	positive_heights.resize(32)
	positive_heights[18] = 8
	var positive_rotated := PackedByteArray()
	positive_rotated.resize(32)
	positive_rotated[21] = 5
	probe_bundle["heights"] = positive_heights
	probe_bundle["rotated_heights"] = positive_rotated
	probe_bundle["angles"] = PackedByteArray([0, 32])
	probe_bundle["collision_primary"] = PackedByteArray([0, 1])
	probe_bundle["collision_secondary"] = PackedByteArray([0, 1])
	for expected in [{"word": 0x10, "path": 0}, {"word": 0x40, "path": 1}]:
		probe_chunks[0] = expected["word"]
		probe_chunks[1] = 1
		probe_bundle["chunks"] = probe_chunks
		var solid_floor := Collision.find_floor(probe_bundle, Vector2i(2, 5), expected["path"])
		assert(solid_floor["ok"] and solid_floor["height"] == 8 and solid_floor["distance"] == 2)
	for expected in [{"word": 0x20, "path": 0}, {"word": 0x80, "path": 1}]:
		probe_chunks[0] = expected["word"]
		probe_chunks[1] = 1
		probe_bundle["chunks"] = probe_chunks
		var solid_wall := Collision.find_right_wall(probe_bundle, Vector2i(2, 5), expected["path"])
		assert(solid_wall["ok"] and solid_wall["height"] == 5 and solid_wall["distance"] == 8)
	print("PASS: nonempty floor and right-wall geometry on both collision paths")
	# Follow-up to accepted probe verification 404a906 and independent review 16c8a12:
	# an unavailable index for the active path must not poison the other path.
	var missing_index_probe := probe_bundle.duplicate(true)
	missing_index_probe.erase("collision_primary")
	missing_index_probe["chunks"] = PackedByteArray([0x10, 1])
	var missing_floor_index := Collision._height(missing_index_probe, Vector2i(2, 5), 0, 11)
	assert(not missing_floor_index["ok"] and missing_floor_index.has("error"))
	missing_index_probe["chunks"] = PackedByteArray([0x40, 1])
	var valid_secondary_floor := Collision.find_floor(missing_index_probe, Vector2i(2, 5), 1)
	assert(valid_secondary_floor["ok"] and valid_secondary_floor["height"] == 8 and valid_secondary_floor["distance"] == 2)
	missing_index_probe["collision_primary"] = PackedByteArray([0, 1])
	missing_index_probe.erase("collision_secondary")
	missing_index_probe["chunks"] = PackedByteArray([0x80, 1])
	var missing_wall_index := Collision._wall_height(missing_index_probe, Vector2i(2, 5), 1, 11)
	assert(not missing_wall_index["ok"] and missing_wall_index.has("error"))
	missing_index_probe["chunks"] = PackedByteArray([0x20, 1])
	var valid_primary_wall := Collision.find_right_wall(missing_index_probe, Vector2i(2, 5), 0)
	assert(valid_primary_wall["ok"] and valid_primary_wall["height"] == 5 and valid_primary_wall["distance"] == 8)
	print("PASS: missing active-path indexes cannot suppress the other collision path")
	var wall_chunks := PackedByteArray()
	wall_chunks.resize(256)
	var rotated := PackedByteArray()
	rotated.resize(64)
	rotated[21] = 16
	rotated[37] = 5
	rotated[53] = 9
	var wall_bundle := {
		"ok": true, "foreground": {"width_chunks": 2, "height_chunks": 1, "rows": [PackedByteArray([0, 1])]},
		"chunks": wall_chunks, "collision_primary": PackedByteArray([0, 0, 2]),
		"collision_secondary": PackedByteArray([0, 0, 3]),
		"angles": PackedByteArray([0, 10, 40, 80]), "rotated_heights": rotated}
	wall_chunks[14] = 0x20
	wall_chunks[15] = 1
	wall_chunks[128] = 0x20
	wall_chunks[129] = 2
	wall_bundle["chunks"] = wall_chunks
	var seam := Collision.find_right_wall(wall_bundle, Vector2i(127, 5))
	assert(seam["ok"] and seam["distance"] == 11 and seam["height"] == 5)
	print("PASS: next chunk supplies right-wall contact")
	wall_chunks[14] = 0x20
	wall_chunks[15] = 2
	wall_chunks[128] = 0x20
	wall_chunks[129] = 1
	wall_bundle["chunks"] = wall_chunks
	wall_bundle["collision_primary"] = PackedByteArray([0, 1, 2])
	seam = Collision.find_right_wall(wall_bundle, Vector2i(128, 5))
	assert(seam["ok"] and seam["distance"] == -6 and seam["height"] == 5)
	print("PASS: previous chunk supplies right-wall overlap")
	wall_chunks[128] = 0xA0
	wall_chunks[129] = 2
	wall_bundle["chunks"] = wall_chunks
	var primary := Collision.find_right_wall(wall_bundle, Vector2i(128, 5), 0)
	var secondary := Collision.find_right_wall(wall_bundle, Vector2i(128, 5), 1)
	assert(primary["ok"] and secondary["ok"] and primary["distance"] == 10 and secondary["distance"] == 6)
	print("PASS: primary and secondary wall paths differ")
	seam = Collision.find_right_wall(wall_bundle, Vector2i(255, 5))
	assert(not seam["ok"] and seam.has("error"))
	print("PASS: outer wall layout boundary returns structured error")
	wall_chunks[128] = 0x80
	wall_bundle["chunks"] = wall_chunks
	var primary_off := Collision._wall_height(wall_bundle, Vector2i(128, 5), 0, 77)
	var secondary_on := Collision._wall_height(wall_bundle, Vector2i(128, 5), 1, 77)
	assert(primary_off["ok"] and primary_off["height"] == 0 and primary_off["angle"] == 77)
	assert(secondary_on["ok"] and secondary_on["height"] == 9 and secondary_on["angle"] == 80)
	wall_chunks[128] = 0x20
	wall_bundle["chunks"] = wall_chunks
	var primary_on := Collision._wall_height(wall_bundle, Vector2i(128, 5), 0, 77)
	var secondary_off := Collision._wall_height(wall_bundle, Vector2i(128, 5), 1, 77)
	assert(primary_on["ok"] and primary_on["height"] == 5 and primary_on["angle"] == 40)
	assert(secondary_off["ok"] and secondary_off["height"] == 0 and secondary_off["angle"] == 77)
	print("PASS: primary and secondary solidity bits remain independent")
	var flip_rows := PackedByteArray()
	flip_rows.resize(32)
	flip_rows[21] = 250
	flip_rows[26] = 9
	var flip_bundle := {
		"ok": true, "foreground": {"width_chunks": 1, "height_chunks": 1, "rows": [PackedByteArray([0])]},
		"chunks": PackedByteArray([0x20, 0x01]), "collision_primary": PackedByteArray([0, 1]),
		"angles": PackedByteArray([0, 250]), "rotated_heights": flip_rows}
	var flipped := Collision._wall_height(flip_bundle, Vector2i(2, 5), 0, 0)
	assert(flipped["ok"] and flipped["height"] == -6 and flipped["angle"] == 250)
	print("PASS: signed rotated right-wall height byte")
	flip_bundle["chunks"] = PackedByteArray([0x28, 0x01])
	flipped = Collision._wall_height(flip_bundle, Vector2i(2, 5), 0, 0)
	assert(flipped["ok"] and flipped["height"] == 9)
	print("PASS: Y flip selects nonuniform rotated row")
	assert(flipped["angle"] == 134)
	print("PASS: Y-flipped wall angle wraps to byte")
	flip_bundle["chunks"] = PackedByteArray([0x24, 0x01])
	flipped = Collision._wall_height(flip_bundle, Vector2i(2, 5), 0, 0)
	assert(flipped["ok"] and flipped["height"] == 6 and flipped["angle"] == 6)
	print("PASS: X flip negates signed right-wall height")
	flip_bundle["chunks"] = PackedByteArray([0x2C, 0x01])
	flipped = Collision._wall_height(flip_bundle, Vector2i(2, 5), 0, 0)
	assert(flipped["ok"] and flipped["height"] == -9 and flipped["angle"] == 122)
	print("PASS: combined X and Y wall flips maintain operation order")
	flip_bundle["chunks"] = PackedByteArray([0x10, 0x01])
	flipped = Collision._wall_height(flip_bundle, Vector2i(2, 5), 0, 99)
	assert(flipped["ok"] and flipped["height"] == 0 and flipped["angle"] == 99)
	print("PASS: floor-only collision bit remains ignored by wall probe")
	flip_rows[21] = 129
	flip_bundle["rotated_heights"] = flip_rows
	flip_bundle["chunks"] = PackedByteArray([0x24, 0x01])
	flipped = Collision._wall_height(flip_bundle, Vector2i(2, 5), 0, 0)
	assert(flipped["ok"] and flipped["height"] == 127 and flipped["angle"] == 6)
	print("PASS: X flip negates near-limit signed rotated byte")
	var stream := PackedByteArray([0x41, 0, 65, 255, 0, 0, 0])
	assert(Decoder.decode_kosinski(stream)["data"] == PackedByteArray([65, 65, 65]))
	for length in range(stream.size()):
		assert(not Decoder.decode_kosinski(stream.slice(0, length))["ok"])
	assert(not Decoder.decode_kosinski(stream, 2)["ok"])
	var layout := PackedByteArray()
	layout.resize(138)
	layout[1] = 1
	layout[3] = 1
	layout[5] = 1
	layout[7] = 1
	layout[8] = 0x80
	layout[9] = 0x88
	layout[10] = 0x80
	layout[11] = 0x89
	layout[136] = 4
	layout[137] = 9
	var decoded := Terrain.decode_layout(layout)
	assert(decoded["foreground"]["rows"][0][0] == 4)
	assert(decoded["background"]["rows"][0][0] == 9)
	layout[9] = 0x87
	assert(not Terrain.decode_layout(layout)["ok"])
	assert(not Terrain.decode_aiz_main(PackedByteArray())["ok"])
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() >= 2:
		var inspected := Inspector.inspect_file(arguments[0])
		assert(inspected["ok"])
		var bundle := Terrain.decode_aiz_main(inspected["image_bytes"])
		assert(bundle["ok"], str(bundle))
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arguments[1]))
		for resource in expected:
			if resource == "foreground_region":
				continue
			var context := HashingContext.new()
			context.start(HashingContext.HASH_SHA256)
			context.update(bundle[resource])
			assert(context.finish().hex_encode() == expected[resource], "Mismatch: " + resource)
		var preview := Terrain.render_region(bundle, "foreground", Rect2i(0x1995, 0x3B0, 320, 224))
		assert(preview["ok"], str(preview))
		var pixels := HashingContext.new()
		pixels.start(HashingContext.HASH_SHA256)
		pixels.update(preview["image"].get_data())
		assert(pixels.finish().hex_encode() == expected["foreground_region"], "Native terrain pixels mismatch")
		assert(preview["image"].save_png(arguments[1].get_base_dir().path_join("native-terrain.png")) == OK)
		print("Local native terrain: every resource hash and all 71,680 RGBA pixels match the independent Python decoder.")
	print("Native terrain synthetic checks passed.")
	quit(0)


func _test_tile_palette_flips_priority() -> void:
	var chunks := PackedByteArray()
	chunks.resize(128)
	chunks[0] = 0
	chunks[1] = 1
	var blocks := PackedByteArray()
	blocks.resize(16)
	var tiles := PackedByteArray()
	tiles.resize(64)
	for y in range(8):
		for x in range(8):
			var color := (x + 2 * y) % 15 + 1
			var offset := 32 + y * 4 + x / 2
			if x % 2 == 0:
				tiles[offset] = (tiles[offset] & 0x0F) | (color << 4)
			else:
				tiles[offset] = (tiles[offset] & 0xF0) | color
	var palette := PackedByteArray()
	palette.resize(128)
	palette[33 * 2] = 0x00
	palette[33 * 2 + 1] = 0xE0
	palette[40 * 2] = 0x0E
	palette[40 * 2 + 1] = 0x00
	var bundle := {
		"ok": true,
		"foreground": {"width_chunks": 1, "height_chunks": 1, "rows": [PackedByteArray([0])]},
		"chunks": chunks,
		"blocks": blocks,
		"tiles": tiles,
		"palette": palette
	}
	for expected in [
		{"word": 0xC001, "color": 1},
		{"word": 0xC801, "color": 8},
		{"word": 0xD001, "color": 15},
		{"word": 0xD801, "color": 7}
	]:
		blocks[8] = int(expected["word"]) >> 8
		blocks[9] = int(expected["word"]) & 0xFF
		bundle["blocks"] = blocks
		var pixel: Dictionary = Terrain.sample_pixel(bundle, "foreground", Vector2i.ZERO)
		assert(pixel["ok"] and pixel["priority"] and not pixel["transparent"])
		assert(pixel["palette_index"] == 32 + expected["color"])
	var unflipped: Dictionary = Terrain.render_region(bundle, "foreground", Rect2i(0, 0, 8, 8))
	assert(unflipped["ok"] and unflipped["image"].get_width() == 8)
	print("PASS: palette 2, priority and all four tile flip modes preserve pixel indices")
