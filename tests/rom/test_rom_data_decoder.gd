extends SceneTree

var Decoder
var failures := 0


func _initialize() -> void:
	Decoder = load("res://scripts/rom/rom_data_decoder.gd")
	assert(Decoder != null)
	_test_decodes_4bpp_pixels()
	_test_rejects_malformed_tile_data()
	_test_decodes_big_endian_palette()
	_test_rejects_malformed_palette_data()
	_test_composes_image_and_checks_palette_indices()
	if failures == 0:
		print("ROM data decoder checks passed.")
		quit(0)
	else:
		push_error("ROM data decoder checks failed: %d" % failures)
		quit(1)


func _test_decodes_4bpp_pixels() -> void:
	var tile := PackedByteArray()
	tile.resize(32)
	# Row 0: bitplanes form pixels 0,1,2,3,15,8,4,2.
	tile[0] = 0b10000000
	tile[1] = 0b01000000
	tile[2] = 0b00100000
	tile[3] = 0b00010000
	var decoded: Dictionary = Decoder.decode_4bpp_tiles(tile)
	_check(decoded.get("ok", false), "4bpp tile decode succeeds")
	_check(decoded.get("tile_count") == 1, "4bpp tile count")
	var pixels: PackedByteArray = decoded["tiles"][0]
	_check(pixels[0] == 1, "bitplane zero maps to index bit zero")
	_check(pixels[1] == 2, "bitplane one maps to index bit one")
	_check(pixels[2] == 4, "bitplane two maps to index bit two")
	_check(pixels[3] == 8, "bitplane three maps to index bit three")
	_check(pixels[4] == 0 and pixels[5] == 0 and pixels[6] == 0 and pixels[7] == 0, "unset tile bits decode to transparent index")


func _test_rejects_malformed_tile_data() -> void:
	var partial := PackedByteArray([0, 1, 2])
	_check(not Decoder.decode_4bpp_tiles(partial).get("ok", false), "partial tile rejected")
	var one_tile := PackedByteArray()
	one_tile.resize(32)
	_check(not Decoder.decode_4bpp_tiles(one_tile, 0).get("ok", false), "nonpositive tile limit rejected")
	_check(not Decoder.decode_4bpp_tiles(one_tile, 4097).get("ok", false), "oversized tile limit rejected")


func _test_decodes_big_endian_palette() -> void:
	# Genesis CRAM word 0x0EEE has full blue, green, and red 3-bit channels.
	var data := PackedByteArray([0x00, 0x00, 0x0E, 0xEE])
	var decoded: Dictionary = Decoder.decode_palette_4bpp(data)
	_check(decoded.get("ok", false), "palette decode succeeds")
	_check(decoded.get("color_count") == 2, "palette color count")
	var colors: PackedColorArray = decoded["colors"]
	_check(colors[0].is_equal_approx(Color(0, 0, 0, 1)), "zero CRAM word decodes to black")
	_check(colors[1].is_equal_approx(Color(1, 1, 1, 1)), "maximum CRAM channels decode to white")


func _test_rejects_malformed_palette_data() -> void:
	_check(not Decoder.decode_palette_4bpp(PackedByteArray()).get("ok", false), "empty palette rejected")
	_check(not Decoder.decode_palette_4bpp(PackedByteArray([0])).get("ok", false), "odd palette length rejected")
	_check(not Decoder.decode_palette_4bpp(PackedByteArray([0, 0]), 0).get("ok", false), "nonpositive palette limit rejected")


func _test_composes_image_and_checks_palette_indices() -> void:
	var data := PackedByteArray()
	data.resize(32)
	var decoded: Dictionary = Decoder.decode_4bpp_tiles(data)
	var colors := PackedColorArray([Color8(20, 40, 60, 255)])
	var result: Dictionary = Decoder.compose_tile_image(decoded["tiles"], 1, colors)
	_check(result.get("ok", false), "tile atlas image composition succeeds")
	_check(result.get("width") == 8 and result.get("height") == 8, "tile atlas dimensions")
	var invalid_tile := PackedByteArray()
	invalid_tile.resize(64)
	invalid_tile[0] = 15
	var invalid_tiles: Array[PackedByteArray] = [invalid_tile]
	_check(not Decoder.compose_tile_image(invalid_tiles, 1, colors).get("ok", false), "missing palette index rejected")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("Check failed: %s" % description)
