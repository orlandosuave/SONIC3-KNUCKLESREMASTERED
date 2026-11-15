"""Render local static ROM terrain planes for research, not a gameplay frame.

Requires Pillow. Generated assets always go under LOCALAPPDATA, outside Git.
"""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import struct

from PIL import Image, ImageDraw
import audit_aiz_content as audit


def palette(image, variant):
    offset = {"intro": 0x28C314, "main": 0x28C374, "burned": 0x28C3D4}[variant]
    data = image[0x28C234:0x28C234+32] + image[offset:offset+96]
    colors = []
    for word in struct.unpack(">64H", data):
        components = [(word >> shift) & 7 for shift in (1, 5, 9)]
        colors.append(tuple((v << 5) | (v << 2) | (v >> 1) for v in components))
    return colors


def tile_image(data, colors, line):
    result = Image.new("RGBA", (8, 8))
    pixels = []
    for packed in data:
        for index in (packed >> 4, packed & 15):
            pixels.append((*colors[line*16+index], 255 if index else 0))
    result.putdata(pixels)
    return result


def compose_planes(background_low, foreground_low, background_high, foreground_high):
    """Compose already camera-aligned planes; caller supplies original scroll transforms."""
    planes = (background_low, foreground_low, background_high, foreground_high)
    if len({p.size for p in planes}) != 1 or any(p.mode != "RGBA" for p in planes):
        raise ValueError("Aligned priority planes must have identical size and RGBA mode")
    result = Image.new("RGBA", foreground_low.size)
    for plane in planes:
        result = Image.alpha_composite(result, plane)
    return result


def aiz1_animation_uploads(image, counters):
    """Resolve active frames from the ROM scripts and captured next-frame counters."""
    if len(counters) != 3:
        raise ValueError("AIZ1 requires three animation counters")
    cursor = 0x28752
    uploads = []
    for counter in counters:
        pointer, destination, count, tiles = struct.unpack_from(">IHBB", image, cursor)
        stride = 2 if pointer >> 24 >= 128 else 1
        next_frame = counter & 255
        if not 1 <= next_frame <= count:
            raise ValueError("Animation has no valid previously uploaded frame")
        source = (pointer & 0xFFFFFF) + image[cursor+8+(next_frame-1)*stride]*32
        data = image[source:source+tiles*32]
        if len(data) != tiles*32 or destination % 32:
            raise ValueError("Invalid animation upload")
        uploads.append((destination//32, data))
        cursor += 8 + ((count*stride+1) & ~1)
    return uploads


def render(image, variant, layer_name, priority=None, animation_uploads=(), captured_colors=None,
           main_upload_end=None, nametable=None):
    act, suffix = (2, "secondary") if variant == "burned" else (1, variant)
    decoded = {name: audit.decode_kosinski(image[offset:offset+size])[0]
               for name, offset, size, _ in audit.TERRAIN}
    art = {name: audit.decode_moduled_kosinski(image[offset:offset+size])[0]
           for name, offset, size in audit.TILE_RESOURCES}
    vram = {}
    primary = art[f"tiles_{act}_primary"]
    audit.write_tile_range(vram, 0, primary, "primary")
    secondary = art[f"tiles_{act}_{suffix}"]
    if main_upload_end is not None:
        if variant != "main" or main_upload_end % 32 or not len(primary) <= main_upload_end <= len(primary)+len(secondary):
            raise ValueError("Invalid main-art upload boundary")
        audit.write_tile_range(vram, len(primary)//32, art["tiles_1_intro"], "intro retained during upload")
        secondary = secondary[:main_upload_end-len(primary)]
    audit.write_tile_range(vram, len(primary)//32, secondary, suffix)
    if variant != "intro":
        audit.write_tile_range(vram, 0x500, art["tiles_1_fire"], "fire")
    for destination, data in animation_uploads:
        audit.write_tile_range(vram, destination, data, "captured animation")
    blocks = decoded[f"blocks_{act}_primary"] + decoded[f"blocks_{act}_{suffix}"]
    chunks = decoded[f"chunks_{act}"]
    _, offset, size = audit.LAYOUTS[act-1]
    layout = audit.parse_layout(image[offset:offset+size])[layer_name]
    colors = palette(image, variant) if captured_colors is None else captured_colors
    if len(colors) != 64:
        raise ValueError("Expected 64 palette colors")
    tile_cache, block_cache, chunk_cache = {}, {}, {}
    missing = Counter()

    def tile(word):
        if word not in tile_cache:
            attrs = audit.tile_attributes(word)
            if priority is not None and attrs["priority"] != priority:
                tile_cache[word] = Image.new("RGBA", (8, 8))
                return tile_cache[word]
            if attrs["tile_id"] not in vram:
                raise ValueError("Missing tile upload; refuse a substituted render")
            result = tile_image(vram[attrs["tile_id"]][1], colors, attrs["palette_line"])
            if attrs["flip_x"]:
                result = result.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if attrs["flip_y"]:
                result = result.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            tile_cache[word] = result
        return tile_cache[word]

    def block(word):
        if word not in block_cache:
            attrs = audit.chunk_attributes(word)
            start = attrs["block_id"] * 8
            if start + 8 > len(blocks):
                # Diagnostic marker only; never substitute this in runtime data.
                result = Image.new("RGBA", (16, 16), (255, 0, 255, 255))
                ImageDraw.Draw(result).line((0, 0, 15, 15), fill=(0, 0, 0, 255))
                missing[attrs["block_id"]] += 1
            else:
                result = Image.new("RGBA", (16, 16))
                for i, tile_word in enumerate(struct.unpack_from(">4H", blocks, start)):
                    result.paste(tile(tile_word), ((i % 2)*8, (i//2)*8))
            if attrs["flip_x"]:
                result = result.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if attrs["flip_y"]:
                result = result.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            block_cache[word] = result
        return block_cache[word]

    def chunk(index):
        if index not in chunk_cache:
            result = Image.new("RGBA", (128, 128))
            for i, word in enumerate(struct.unpack_from(">64H", chunks, index*128)):
                result.paste(block(word), ((i % 8)*16, (i//8)*16))
            chunk_cache[index] = result
        return chunk_cache[index]

    if nametable is not None:
        if len(nametable) != 4096:
            raise ValueError("Expected a 64 by 32 nametable")
        result = Image.new("RGBA", (512, 256))
        for i, word in enumerate(struct.unpack(">2048H", nametable)):
            result.paste(tile(word), ((i % 64)*8, (i//64)*8))
        return result, {"source": "persistent nametable", "size": result.size}
    result = Image.new("RGBA", (layout["width_chunks"]*128, layout["height_chunks"]*128))
    for y, row in enumerate(layout["rows"]):
        for x, index in enumerate(row):
            result.paste(chunk(index), (x*128, y*128))
    return result, {"variant": variant, "layer": layer_name, "priority_filter": priority,
                    "size": result.size, "missing_block_ids": sorted(missing),
                    "limitations": "Static plane; no scroll deformation, animated uploads, live mutations, objects or water palette. Priority retained in source words but planes not composited. Main includes later fire-art availability."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    args = parser.parse_args()
    image = audit.read_image(args.rom)
    output = Path(os.environ["LOCALAPPDATA"]) / "S3KRemastered" / "research" / "aiz-static"
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    sheet = Image.new("RGB", (1600, 900), (35, 35, 45))
    draw = ImageDraw.Draw(sheet)
    for i, variant in enumerate(("intro", "main", "burned")):
        plane, report = render(image, variant, "foreground")
        plane.save(output / f"{variant}-foreground.png")
        if variant == "main":
            plane.crop((0x1300, 0x300, 0x1700, 0x500)).save(output / "main-detail.png")
        overview = plane.copy()
        overview.thumbnail((1580, 230), Image.Resampling.NEAREST)
        sheet.paste(overview, (10, i*300+40), overview)
        draw.text((10, i*300+10), f"{variant}: static foreground; magenta = unresolved block", fill="white")
        reports.append(report)
        background, bg_report = render(image, variant, "background")
        background.save(output / f"{variant}-background.png")
        reports.append(bg_report)
    for priority in (False, True):
        plane, report = render(image, "main", "foreground", priority)
        plane.save(output / f"main-foreground-{'high' if priority else 'low'}.png")
        reports.append(report)
    sheet.save(output / "overview.png")
    (output / "report.json").write_text(json.dumps(reports, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output), "missing_block_counts":
                      {f"{r['variant']}/{r['layer']}/{r['priority_filter']}": len(r["missing_block_ids"])
                       for r in reports}}, indent=2))


if __name__ == "__main__":
    main()
