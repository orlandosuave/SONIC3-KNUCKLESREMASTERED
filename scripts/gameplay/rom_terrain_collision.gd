class_name RomTerrainCollision
extends RefCounted

## Downward original-coordinate floor probes. No Godot physics-shape substitute.
## Wall/ceiling probes, object support and player integration are separate work.
const Terrain = preload("res://scripts/rom/rom_terrain_decoder.gd")


static func _height(bundle: Dictionary, point: Vector2i, path: int, angle: int) -> Dictionary:
	var foreground: Variant = bundle.get("foreground")
	if not foreground is Dictionary:
		return {"ok": false, "error": "Invalid foreground collision layout."}
	var layer: Dictionary = foreground
	if not layer.has("width_chunks") or not layer.has("height_chunks"):
		return {"ok": false, "error": "Missing collision layout dimensions."}
	if not layer["width_chunks"] is int or not layer["height_chunks"] is int or layer["width_chunks"] <= 0 or layer["height_chunks"] <= 0:
		return {"ok": false, "error": "Invalid collision layout dimensions."}
	if point.x < 0 or point.y < 0 or point.x >= int(layer["width_chunks"]) * 128 or point.y >= int(layer["height_chunks"]) * 128:
		return {"ok": false, "error": "Probe outside validated layout bounds."}
	var rows: Variant = layer.get("rows")
	if not rows is Array:
		return {"ok": false, "error": "Invalid collision layout rows."}
	var row_index: int = point.y / 128
	if row_index >= rows.size():
		return {"ok": false, "error": "Missing collision layout row."}
	var selected_row: Variant = rows[row_index]
	if not selected_row is PackedByteArray:
		return {"ok": false, "error": "Invalid collision layout row."}
	var row: PackedByteArray = selected_row
	var column_index: int = point.x / 128
	if column_index >= row.size():
		return {"ok": false, "error": "Missing collision layout column."}
	var chunk_id: int = row[column_index]
	var offset := chunk_id * 128 + ((point.y % 128) / 16 * 8 + (point.x % 128) / 16) * 2
	var chunk_data: Variant = bundle.get("chunks")
	if not chunk_data is PackedByteArray:
		return {"ok": false, "error": "Invalid collision chunks."}
	var chunks: PackedByteArray = chunk_data
	if offset + 2 > chunks.size():
		return {"ok": false, "error": "Missing collision chunk."}
	var entry := Terrain.word(chunks, offset)
	var block_id := entry & 1023
	var result := {"ok": true, "height": 0, "angle": angle, "block_id": block_id}
	if block_id == 0 or not (entry & (1 << (12 + path * 2))):
		return result
	var selected_indexes: Variant = bundle.get("collision_primary" if path == 0 else "collision_secondary")
	if not selected_indexes is PackedByteArray:
		return {"ok": false, "error": "Invalid selected collision indexes."}
	var indexes: PackedByteArray = selected_indexes
	if block_id >= indexes.size():
		return {"ok": false, "error": "Missing collision index."}
	var shape: int = indexes[block_id]
	if shape == 0:
		return result
	var angle_data: Variant = bundle.get("angles")
	if not angle_data is PackedByteArray:
		return {"ok": false, "error": "Invalid collision angles."}
	var angles: PackedByteArray = angle_data
	if shape >= angles.size():
		return {"ok": false, "error": "Missing collision angle."}
	var column := point.x & 15
	angle = int(angles[shape])
	if entry & 1024:
		column = 15 - column
		angle = -angle
	if entry & 2048:
		angle = -angle - 128
	var height: int = bundle["heights"][shape * 16 + column]
	if height >= 128:
		height -= 256
	if entry & 2048:
		height = -height
	result["height"] = height
	result["angle"] = angle & 255
	return result


static func _neighbor(bundle: Dictionary, point: Vector2i, path: int, angle: int) -> Dictionary:
	var result := _height(bundle, point, path, angle)
	if not result["ok"]:
		return result
	var height: int = result["height"]
	var local_y := point.y & 15
	var distance := 15 - local_y
	if height > 0:
		distance -= height
	elif height < 0 and height + local_y < 0:
		distance = -local_y - 1
	result["distance"] = distance
	return result


static func find_floor(bundle: Dictionary, point: Vector2i, path: int = 0, initial_angle: int = 0) -> Dictionary:
	if path not in [0, 1] or not bundle.get("ok", false):
		return {"ok": false, "error": "Invalid terrain collision path."}
	var result := _height(bundle, point, path, initial_angle)
	if not result["ok"]:
		return result
	var height: int = result["height"]
	var local_y := point.y & 15
	if height == 0 or (height < 0 and height + local_y >= 0):
		result = _neighbor(bundle, point + Vector2i(0, 16), path, result["angle"])
		if result["ok"]:
			result["distance"] += 16
	elif height == 16 or height < 0:
		result = _neighbor(bundle, point - Vector2i(0, 16), path, result["angle"])
		if result["ok"]:
			result["distance"] -= 16
	else:
		result["distance"] = 15 - local_y - height
	return result
