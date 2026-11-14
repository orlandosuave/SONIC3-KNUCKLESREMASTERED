class_name RomInspector
extends RefCounted

## Validates the first locally inspected combined Sonic 3 & Knuckles image.
## Source bytes are read in memory and are never written by this class.

const SUPPORTED_SIZE := 4 * 1024 * 1024
const SEGMENT_SIZE := 2 * 1024 * 1024
const FIRST_HEADER_OFFSET := 0x100
const SECOND_HEADER_OFFSET := SEGMENT_SIZE + 0x100
const SUPPORTED_SHA256 := "fba0677fde9f76df93f3e98d6310d8af68b9847bde16e253d73cd4dd8134ed23"
const PROFILE_ID := "sk-s3-lockon-4m-sha256-fba0677f"


static func inspect_file(path: String) -> Dictionary:
	var extension := path.get_extension().to_lower()
	var image_bytes: PackedByteArray
	var source_kind := ""

	if extension == "md":
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _failure("Could not open the selected ROM file.")
		var file_size := file.get_length()
		if file_size != SUPPORTED_SIZE:
			file.close()
			return _failure("Unsupported ROM size: expected 4 MiB (4,194,304 bytes).")
		image_bytes = file.get_buffer(file_size)
		file.close()
		source_kind = "raw_md"
	elif extension == "zip":
		var zip_reader := ZIPReader.new()
		var open_error := zip_reader.open(path)
		if open_error != OK:
			return _failure("Could not read this ZIP archive.")
		var members: Array[String] = []
		for member_path in zip_reader.get_files():
			if not member_path.ends_with("/") and member_path.get_extension().to_lower() == "md":
				members.append(member_path)
		if members.size() != 1:
			zip_reader.close()
			return _failure("ZIP must contain exactly one .md ROM image.")
		image_bytes = zip_reader.read_file(members[0])
		zip_reader.close()
		source_kind = "zip"
	else:
		return _failure("Unsupported file type. Select a .md ROM or a .zip containing one .md image.")

	if image_bytes.size() != SUPPORTED_SIZE:
		return _failure("Unsupported ROM size: expected 4 MiB (4,194,304 bytes).")

	var hash_context := HashingContext.new()
	if hash_context.start(HashingContext.HASH_SHA256) != OK:
		return _failure("Could not calculate the ROM fingerprint.")
	if hash_context.update(image_bytes) != OK:
		return _failure("Could not calculate the ROM fingerprint.")
	var sha256 := hash_context.finish().hex_encode().to_lower()
	if sha256 != SUPPORTED_SHA256:
		return _failure("This image is not the currently supported, inspected 4 MiB lock-on profile.")

	var first_header := _read_header(image_bytes, FIRST_HEADER_OFFSET)
	var second_header := _read_header(image_bytes, SECOND_HEADER_OFFSET)
	if not first_header.get("signature_ok", false):
		return _failure("The first 2 MiB segment has no expected SEGA GENESIS header.")
	if not second_header.get("signature_ok", false):
		return _failure("The second 2 MiB segment has no expected SEGA GENESIS header.")
	if not str(first_header.get("title", "")).contains("SONIC & KNUCKLES"):
		return _failure("The first segment header does not identify Sonic & Knuckles.")
	if not str(second_header.get("title", "")).contains("SONIC THE") or not str(second_header.get("title", "")).contains("HEDGEHOG 3"):
		return _failure("The second segment header does not identify Sonic 3.")

	return {
		"ok": true,
		"profile_id": PROFILE_ID,
		"source_kind": source_kind,
		"byte_size": image_bytes.size(),
		"sha256": sha256,
		"layout": "two_consecutive_2mib_images",
		"image_bytes": image_bytes,
		"first_segment": first_header,
		"second_segment": second_header,
	}


static func _read_header(image_bytes: PackedByteArray, offset: int) -> Dictionary:
	var signature := _read_ascii(image_bytes, offset + 0x00, 0x10).strip_edges()
	var title := _read_ascii(image_bytes, offset + 0x20, 0x30).strip_edges()
	var product := _read_ascii(image_bytes, offset + 0x80, 0x0E).strip_edges()
	var region := _read_ascii(image_bytes, offset + 0xF0, 0x10).strip_edges()
	return {
		"signature_ok": signature == "SEGA GENESIS",
		"title": title,
		"product": product,
		"region": region,
	}


static func _read_ascii(bytes: PackedByteArray, offset: int, count: int) -> String:
	var result := ""
	for index in range(count):
		var value := bytes[offset + index]
		if value == 0:
			continue
		result += String.chr(value)
	return result


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
