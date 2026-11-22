extends SceneTree

const Terrain = preload("res://scripts/rom/rom_terrain_decoder.gd")
const Decoder = preload("res://scripts/rom/rom_data_decoder.gd")
const Inspector = preload("res://scripts/rom/rom_inspector.gd")
const Collision = preload("res://scripts/gameplay/rom_terrain_collision.gd")


func _initialize() -> void:
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
	for invalid_flag in [null, false, 1, "true"]:
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
	print("PASS: internal floor height rejects invalid collision paths")
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
