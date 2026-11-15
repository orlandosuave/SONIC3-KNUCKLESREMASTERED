"""Read-only, hash-pinned AIZ placement/layout audit; emits metadata, never ROM bytes."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct
from zipfile import ZipFile

PROFILE_HASH = "fba0677fde9f76df93f3e98d6310d8af68b9847bde16e253d73cd4dd8134ed23"
ROM_SIZE = 0x400000
PLACEMENTS = ((1, 0x1E44DA, 924), (2, 0x1E4876, 4512))
LAYOUTS = ((1, 0x281420, 2124), (2, 0x281C6C, 3430))
TERRAIN = (
    ("blocks_1_primary", 0x3A374A, 512, 8),
    ("blocks_1_intro", 0x3A394A, 3136, 8),
    ("blocks_1_main", 0x3A458A, 4320, 8),
    ("chunks_1", 0x3ABC40, 14736, 128),
    ("blocks_2_primary", 0x3B0052, 2208, 8),
    ("blocks_2_secondary", 0x3B08F2, 2688, 8),
    ("chunks_2", 0x3B51E8, 16400, 128),
)
TILE_RESOURCES = (
    ("tiles_1_primary", 0x3A566A, 3602),
    ("tiles_1_intro", 0x3A647C, 12242),
    ("tiles_1_main", 0x3A944E, 10226),
    ("tiles_1_fire", 0x3AF5D0, 2690),
    ("tiles_2_primary", 0x3B15D2, 8626),
    ("tiles_2_secondary", 0x3B3784, 4418),
)


def decode_moduled_kosinski(source):
    if len(source) < 4:
        raise ValueError("Truncated KosinskiM header")
    expected = int.from_bytes(source[:2], "big")
    if not expected:
        raise ValueError("Empty KosinskiM declaration")
    cursor, output = 2, bytearray()
    while len(output) < expected:
        module_size = min(4096, expected - len(output))
        module, consumed = decode_kosinski(source[cursor:], output_limit=module_size)
        if len(module) != module_size:
            raise ValueError("KosinskiM module output disagrees with declared size")
        output.extend(module)
        cursor += consumed
        if len(output) < expected:
            cursor = 2 + ((cursor - 2 + 15) & ~15)
            if cursor >= len(source):
                raise ValueError("Truncated KosinskiM module alignment")
    return bytes(output), cursor


def write_tile_range(vram, start_tile, data, owner):
    if not data or len(data) % 32 or start_tile < 0 or start_tile + len(data)//32 > 2048:
        raise ValueError("Invalid VRAM tile upload")
    for tile in range(len(data)//32):
        vram[start_tile + tile] = (owner, data[tile*32:(tile+1)*32])


def audit_graphics_states(image, decoded):
    tiles, resources = {}, []
    for name, offset, size in TILE_RESOURCES:
        data, consumed = decode_moduled_kosinski(image[offset:offset+size])
        if len(data) % 32:
            raise ValueError("Incomplete tile art")
        tiles[name] = data
        resources.append({"resource": name, "tile_count": len(data)//32,
                          "sha256": hashlib.sha256(data).hexdigest(),
                          "source_consumed": consumed})
    states = []
    for act, variant in ((1, "intro"), (1, "main"), (2, "secondary")):
        vram = {}
        primary = tiles[f"tiles_{act}_primary"]
        write_tile_range(vram, 0, primary, "primary")
        write_tile_range(vram, len(primary)//32, tiles[f"tiles_{act}_{variant}"], variant)
        blocks = decoded[f"blocks_{act}_primary"] + decoded[f"blocks_{act}_{variant}"]
        words = struct.unpack(f">{len(blocks)//2}H", blocks)
        referenced = {tile_attributes(w)["tile_id"] for w in words}
        missing = sorted(referenced - vram.keys())
        fire_missing = None
        if variant != "intro":
            # Explicit later-event state, not an assumption that fire is loaded at start.
            write_tile_range(vram, 0x500, tiles["tiles_1_fire"], "fire_overlay")
            fire_missing = sorted(referenced - vram.keys())
        states.append({"internal_map": act, "variant": variant,
                       "terrain_upload_tiles": len(primary)//32 + len(tiles[f"tiles_{act}_{variant}"])//32,
                       "unresolved_tile_ids": missing,
                       "unresolved_after_fire_upload": fire_missing,
                       "scope": "All loaded block words; base terrain uploads only, not final VRAM state"})
    return {"resources": resources, "base_states": states}


def decode_kosinski(source, output_limit=0x8000, command_limit=0x20000):
    """Bounded ordinary Kosinski stream (no module header or alignment)."""
    if not 1 <= output_limit <= 0x100000 or not 1 <= command_limit <= 0x200000:
        raise ValueError("Invalid Kosinski safety limits")
    cursor = 0
    descriptor = 0
    remaining = 0
    output = bytearray()

    def byte():
        nonlocal cursor
        if cursor >= len(source):
            raise ValueError("Truncated Kosinski stream")
        value = source[cursor]
        cursor += 1
        return value

    def refill():
        nonlocal descriptor, remaining
        descriptor = byte() | (byte() << 8)
        remaining = 16

    def bit():
        nonlocal descriptor, remaining
        if remaining == 0:
            refill()
        value = descriptor & 1
        descriptor >>= 1
        remaining -= 1
        # Next descriptor precedes the command payload at a bit boundary.
        if remaining == 0:
            refill()
        return value

    for _ in range(command_limit):
        if bit():
            if len(output) >= output_limit:
                raise ValueError("Kosinski output limit exceeded")
            output.append(byte())
            continue
        if bit():
            low, high = byte(), byte()
            distance = 8192 - (((high & 0xF8) << 5) | low)
            count = high & 7
            if count:
                count += 2
            else:
                count = byte()
                if count == 0:
                    return bytes(output), cursor
                if count == 1:
                    continue
                count += 1
        else:
            count = (bit() << 1) | bit()
            count += 2
            distance = 256 - byte()
        if distance > len(output):
            raise ValueError("Kosinski back-reference precedes output")
        if len(output) + count > output_limit:
            raise ValueError("Kosinski output limit exceeded")
        for _ in range(count):
            output.append(output[-distance])
    raise ValueError("Kosinski command limit exceeded")


def audit_terrain(image, layouts):
    decoded, summaries = {}, []
    for name, offset, size, record_size in TERRAIN:
        data, consumed = decode_kosinski(image[offset:offset + size])
        if not data or len(data) % record_size:
            raise ValueError(f"{name}: incomplete decoded records")
        decoded[name] = data
        summaries.append({"resource": name, "decoded_bytes": len(data),
                          "records": len(data) // record_size,
                          "source_consumed": consumed, "source_bytes": size,
                          "sha256": hashlib.sha256(data).hexdigest()})
    references = []
    for act, layers in layouts.items():
        chunks = decoded[f"chunks_{act}"]
        for name, layer in layers.items():
            ids = set(b"".join(layer["rows"]))
            if max(ids) >= len(chunks) // 128:
                raise ValueError(f"Map {act} {name}: chunk index outside decoded table")
        # Static table audit only; live chunk/layout mutation remains separate.
        words = struct.unpack(f">{len(chunks)//2}H", chunks)
        block_ids = {word & 0x3FF for word in words}
        variants = ("intro", "main") if act == 1 else ("secondary",)
        for variant in variants:
            primary = decoded[f"blocks_{act}_primary"]
            secondary = decoded[f"blocks_{act}_{variant}"]
            expected_base = 0x268 if act == 1 else 0xAB8
            if len(primary) != expected_base:
                raise ValueError("Primary block length disagrees with source replacement base")
            count = (len(primary) + len(secondary)) // 8
            unresolved = sorted(i for i in block_ids if i >= count)
            references.append({"internal_map": act, "variant": variant,
                               "block_count": count, "max_chunk_block_id": max(block_ids),
                               "out_of_loaded_range_count": len(unresolved),
                               "note": "Whole chunk table, including unused/dynamic areas; unresolved IDs require tracing"})
    attributes = {}
    for name, data in decoded.items():
        if name.startswith("blocks_"):
            words = struct.unpack(f">{len(data)//2}H", data)
            tiles = [tile_attributes(w) for w in words]
            attributes[name] = {
                "max_tile_id": max(t["tile_id"] for t in tiles),
                "palette_lines": sorted({t["palette_line"] for t in tiles}),
                "priority_words": sum(t["priority"] for t in tiles),
            }
    collision = []
    for act, offset in ((1, 0x274760), (2, 0x275360)):
        paths = parse_aiz_collision(image[offset:offset + 0xC00])
        chunks = decoded[f"chunks_{act}"]
        words = struct.unpack(f">{len(chunks)//2}H", chunks)
        max_block = max(chunk_attributes(w)["block_id"] for w in words)
        if max_block >= len(paths[0]):
            raise ValueError("Chunk block reference exceeds collision index table")
        collision.append({"internal_map": act, "indices_per_path": len(paths[0]),
                          "distinct_shapes_per_path": [len(set(p)) for p in paths],
                          "max_shape_per_path": [max(p) for p in paths]})
    intro_probes = [
        {"camera_x": x, "width": width, "top": 0x390, "height": 224,
         "unresolved_block_ids": unresolved_blocks_in_rect(
             layouts[1]["foreground"], decoded["chunks_1"], 600,
             (x, 0x390, x+width, 0x390+224))}
        for x in (0x1000, 0x1308, 0x13FF) for width in (320, 560, 800)
    ]
    return {"resources": summaries, "block_references": references,
            "intro_diagnostic_rectangles": intro_probes,
            "tile_attributes": attributes, "collision_indices": collision,
            "graphics": audit_graphics_states(image, decoded)}


def tile_attributes(word):
    if not 0 <= word <= 0xFFFF:
        raise ValueError("Tile attribute must be an unsigned word")
    return {"tile_id": word & 0x7FF, "flip_x": bool(word & 0x800),
            "flip_y": bool(word & 0x1000), "palette_line": (word >> 13) & 3,
            "priority": bool(word & 0x8000)}


def chunk_attributes(word):
    if not 0 <= word <= 0xFFFF:
        raise ValueError("Chunk attribute must be an unsigned word")
    return {"block_id": word & 0x3FF, "flip_x": bool(word & 0x400),
            "flip_y": bool(word & 0x800),
            "primary_top": bool(word & 0x1000), "primary_sides_bottom": bool(word & 0x2000),
            "secondary_top": bool(word & 0x4000), "secondary_sides_bottom": bool(word & 0x8000)}


def parse_aiz_collision(data):
    # SolidIndexes uses Solid_AIZn+1, then probes use block_id*2.
    # LoadSolids sets secondary base to primary+$600 for the S3 split format.
    if len(data) != 0xC00:
        raise ValueError("AIZ split collision table must contain exactly 3072 bytes")
    return (data[1:0x600:2], data[0x601:0xC00:2])

def collision_shape_id(paths, path_index, block_id):
    """Look up an S3 split-path collision shape without interpreting solidity."""
    if type(path_index) is not int or path_index not in (0, 1):
        raise ValueError("Collision path must be 0 or 1")
    if type(block_id) is not int or not 0 <= block_id < 768:
        raise ValueError("Collision block ID must be in [0, 767]")
    if len(paths) != 2 or any(len(path) != 768 for path in paths):
        raise ValueError("Expected two collision paths with 768 indices each")
    return paths[path_index][block_id]



def parse_layout(data):
    """Decode static S3K row tables; does not apply runtime layout mutations.

    Header: FG width, BG width, FG rows, BG rows (big endian words).
    32 interleaved FG/BG word pointers address the original RAM at 0x8000.
    Each row contains one-byte IDs for 128x128 chunks. Preserve shared rows.
    """
    if not 0x88 <= len(data) <= 0x1000:
        raise ValueError("Layout must fit the 4096-byte RAM span and include its row table")
    fg_width, bg_width, fg_height, bg_height = struct.unpack_from(">4H", data)
    layers = {}
    for layer, name, width, height in (
        (0, "foreground", fg_width, fg_height),
        (1, "background", bg_width, bg_height),
    ):
        if not 1 <= height <= 32 or not 1 <= width <= 0x1000 - 0x88:
            raise ValueError(f"Invalid {name} dimensions")
        rows, offsets = [], []
        for y in range(height):
            pointer = struct.unpack_from(">H", data, 8 + y * 4 + layer * 2)[0]
            offset = pointer - 0x8000
            if offset < 0x88 or offset + width > len(data):
                raise ValueError(f"{name} row {y} points outside the layout payload")
            offsets.append(offset)
            rows.append(data[offset:offset + width])
        layers[name] = {"width_chunks": width, "height_chunks": height,
                        "rows": rows, "row_offsets": offsets}
    return layers


def layout_summary(layers):
    result = {}
    for name, layer in layers.items():
        cells = b"".join(layer["rows"])
        result[name] = {
            "width_chunks": layer["width_chunks"],
            "height_chunks": layer["height_chunks"],
            "width_pixels": layer["width_chunks"] * 128,
            "height_pixels": layer["height_chunks"] * 128,
            "unique_chunk_ids": len(set(cells)),
            "max_chunk_id": max(cells),
            "shared_row_pointers": len(layer["rows"]) - len(set(layer["row_offsets"])),
            "decoded_rows_sha256": hashlib.sha256(cells).hexdigest(),
        }
    return result


def unresolved_blocks_in_rect(layer, chunks, block_count, rect):
    """Inspect a half-open world rectangle without inferring camera reachability."""
    left, top, right, bottom = rect
    if left < 0 or top < 0 or right <= left or bottom <= top:
        raise ValueError("Invalid coverage rectangle")
    if right > layer["width_chunks"]*128 or bottom > layer["height_chunks"]*128:
        raise ValueError("Coverage rectangle exceeds layout")
    missing = set()
    for by in range(top//16, (bottom+15)//16):
        for bx in range(left//16, (right+15)//16):
            chunk_id = layer["rows"][by//8][bx//8]
            offset = chunk_id*128 + ((by % 8)*8 + bx % 8)*2
            if offset + 2 > len(chunks):
                raise ValueError("Coverage chunk outside table")
            block_id = struct.unpack_from(">H", chunks, offset)[0] & 0x3FF
            if block_id >= block_count:
                missing.add(block_id)
    return sorted(missing)


def read_image(path):
    if path.suffix.lower() == ".zip":
        with ZipFile(path) as archive:
            candidates = [i for i in archive.infolist()
                          if not i.is_dir() and Path(i.filename).suffix.lower() == ".md"]
            if len(candidates) != 1:
                raise ValueError("ZIP must contain exactly one .md image")
            if candidates[0].file_size != ROM_SIZE:
                raise ValueError("Unexpected uncompressed ROM size")
            image = archive.read(candidates[0])
    else:
        if path.stat().st_size != ROM_SIZE:
            raise ValueError("Unexpected ROM size")
        image = path.read_bytes()
    if len(image) != ROM_SIZE or hashlib.sha256(image).hexdigest() != PROFILE_HASH:
        raise ValueError("Image is not the supported combined-ROM profile")
    return image


def parse_placements(data):
    """Keep Y/flag word opaque until its complete semantics are verified."""
    if not data or len(data) % 6:
        raise ValueError("Placement span must contain complete six-byte records")
    records = []
    for offset in range(0, len(data), 6):
        x, y_flags, object_id, subtype = struct.unpack_from(">HHBB", data, offset)
        if x == 0xFFFF:
            if offset != len(data) - 6:
                raise ValueError("Unexpected data after placement terminator")
            return records
        records.append((x, y_flags, object_id, subtype))
    raise ValueError("Missing placement terminator")


def census(records):
    return {
        "record_count": len(records),
        "x_order_descents": sum(records[i][0] < records[i-1][0]
                                for i in range(1, len(records))),
        "object_counts": dict(sorted(Counter(f"{r[2]:02X}" for r in records).items())),
        "monitor_subtype_counts": dict(sorted(Counter(
            f"{r[3]:02X}" for r in records if r[2] == 1).items())),
    }


def audit(image):
    results = []
    for act, offset, size in PLACEMENTS:
        records = parse_placements(image[offset:offset + size])
        result = {"internal_map": act, "offset": f"0x{offset:06X}",
                  "source_bytes": size, **census(records)}
        if act == 2:
            # Source resize milestone, NOT a verified route or loading boundary.
            result["candidate_x_below_0x1500"] = census(
                [r for r in records if r[0] < 0x1500])
            result["candidate_warning"] = (
                "Spatial research filter only; includes other-character/inaccessible "
                "placements and may exclude active objects beyond the cutoff. "
                "Do not use as an import or gameplay boundary.")
        results.append(result)
    parsed_layouts = {act: parse_layout(image[offset:offset + size])
                      for act, offset, size in LAYOUTS}
    layouts = [
        {"internal_map": act, "offset": f"0x{offset:06X}", "source_bytes": size,
         "layers": layout_summary(parsed_layouts[act])}
        for act, offset, size in LAYOUTS
    ]
    return {"profile_sha256": PROFILE_HASH, "maps": results, "layouts": layouts,
            "terrain": audit_terrain(image, parsed_layouts),
            "scope": "Static placements and layout rows; excludes dynamic objects and layout mutations"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="Supported local .md image or ZIP")
    args = parser.parse_args()
    try:
        print(json.dumps(audit(read_image(args.rom)), indent=2))
    except (ValueError, OSError) as error:
        parser.exit(1, f"Audit failed: {error}\n")


if __name__ == "__main__":
    main()
