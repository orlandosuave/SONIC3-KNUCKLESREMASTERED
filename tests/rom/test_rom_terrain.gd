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
