"""Compare AIZ scroll words and a static composed view with local core captures."""
import argparse
import json
import os
from pathlib import Path
import struct
from PIL import Image
from audit_aiz_content import read_image, PROFILE_HASH
from aiz_scroll import intro_scroll, normal_scroll, water_line_offsets, signed
from render_aiz_preview import render, compose_planes, aiz1_animation_uploads
from aiz_palette import normal_palette_words, water_scanline_palettes


def sprite_bounds(ram):
    """Decode linked H40 SAT bounds from word-swapped captured work RAM.

    Bounds deliberately include transparent/occluded sprite pixels. This is
    conservative exclusion, not a reconstruction of sprite visibility.
    """
    result, visited, index = [], set(), 0
    while True:
        if index >= 80 or index in visited:
            raise ValueError("Invalid captured sprite link chain")
        visited.add(index)
        y, size_link, tile, x = struct.unpack_from("<4H", ram, 0xF800+index*8)
        size = size_link >> 8
        result.append(((x & 0x1FF)-128, (y & 0x1FF)-128,
                       (((size >> 2) & 3)+1)*8, ((size & 3)+1)*8))
        index = size_link & 0x7F
        if index == 0:
            return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--frame", type=int, default=2220)
    parser.add_argument("--run", default="", help="Named capture directory under reference")
    parser.add_argument("--plane-history", action="store_true", help="Use validated captured-command plane replay")
    parser.add_argument("--region", action="append", default=[], metavar="X,Y,W,H",
                        help="Explicit terrain comparison rectangle; repeat as needed")
    args = parser.parse_args()
    root = Path(os.environ["LOCALAPPDATA"]) / "S3KRemastered/research/reference"
    if args.run:
        if not all(c.isalnum() or c in "-_" for c in args.run):
            parser.error("Invalid run name")
        root = root / args.run
    rom = read_image(args.rom)
    capture = json.loads((root / "capture.json").read_text(encoding="utf-8"))
    if capture["rom_sha256"] != PROFILE_HASH or capture["frames"] < args.frame:
        raise ValueError("Capture manifest does not match the requested comparison")
    captured_frames = {sample["frame"] for sample in capture["captures"]}
    if args.frame not in captured_frames:
        raise ValueError("Requested frame is not recorded in the capture manifest")
    checks = []
    for file in sorted(root.glob("ram-*.bin")):
        ram = file.read_bytes()
        word = lambda address: struct.unpack_from("<H", ram, address)[0]
        x, y, bg_y = word(0xEE80), word(0xEE84), word(0xEE90)
        # Restricted known AIZ boot/traversal capture window, not arbitrary save states.
        tick = int(file.stem.split("-")[1])
        if tick not in captured_frames or not 1740 <= tick <= 3600:
            continue
        intro = bg_y == y
        phase = ((word(0xA83C) << 16) | word(0xA83E)) - 0x2000
        model = intro_scroll(x, y, word(0xEEB6)) if intro else normal_scroll(x, y, phase)
        differences = [{"offset": offset, "expected": value,
                        "captured": signed(word(0xA800+offset), 16)}
                       for offset, value in model["scroll_words"].items()
                       if value != signed(word(0xA800+offset), 16)]
        checks.append({"frame": tick, "mode": "intro" if intro else "normal",
                       "words": len(model["scroll_words"]), "differences": differences,
                       "background_y_matches": model["background_y"] == bg_y})
    ram = (root / f"before-{args.frame:05}.bin").read_bytes()
    word = lambda address: struct.unpack_from("<H", ram, address)[0]
    x, y = word(0xEE80), word(0xEE84)
    phase = ((word(0xA83C)<<16) | word(0xA83E)) - 0x2000
    model = normal_scroll(x, y, phase)
    foreground_offsets, offsets = water_line_offsets(rom, model, x, y, word(0xF646), word(0xFE04))
    reference = Image.open(root / f"frame-{args.frame:05}.png").convert("RGBA")
    width, height = reference.size
    if height != 224:
        raise ValueError("This comparison expects a 224-line capture")
    water_screen_y = signed(word(0xF646), 16) - signed(y, 16)
    layers = {}
    counters = [word(address) for address in (0xF7F0, 0xF7F2, 0xF7F4)]
    uploads = aiz1_animation_uploads(rom, counters)
    queue_source = (word(0xFF64) << 16) | word(0xFF66)
    main_upload_end = word(0xFF68) if 0x3A944E <= queue_source < 0x3ABC40 else None
    if ram[0xF72E ^ 1] or ram[0xF650 ^ 1]:
        raise ValueError("Comparison requires normal AIZ1 palette cycling")
    palette_words = normal_palette_words(rom, word(0xF632), word(0xF652))
    captured_palette = struct.unpack_from("<64H", ram, 0xFC00)
    palette_differences = [i for i, (a, b) in enumerate(zip(palette_words, captured_palette)) if a != b]
    # Preserve palette indices through composition; equal RGB colors can
    # acquire different values during the staggered underwater CRAM writes.
    colors = [(index, 0, 0) for index in range(64)]
    plane_history = None
    if args.plane_history:
        validation = json.loads((root / "plane-history-validation.json").read_text())
        if validation["word_mismatches"] or not any(c["frame"] == args.frame for c in validation["checks"]):
            raise ValueError("Requested plane replay has not passed validation")
        plane_history = (root / f"planes-{args.frame:05}.bin").read_bytes()
        if len(plane_history) != 8192:
            raise ValueError("Invalid plane replay data")
    for plane_name in ("foreground", "background"):
        for priority in (False, True):
            start = 0 if plane_name == "foreground" else 4096
            nametable = plane_history[start:start+4096] if plane_history is not None else None
            plane, _ = render(rom, "main", plane_name, priority, uploads, colors, main_upload_end, nametable)
            if plane_name == "foreground":
                view = Image.new("RGBA", (width, height))
                for row, scroll in enumerate(foreground_offsets):
                    if plane_history is None:
                        view.paste(plane.crop((scroll, y+row, scroll+width, y+row+1)), (0, row))
                    else:
                        for col in range(width):
                            view.putpixel((col, row), plane.getpixel(((scroll+col)%512, (y+row)%256)))
            else:
                view = Image.new("RGBA", (width, height))
                for row, scroll in enumerate(offsets):
                    sy = (model["background_y"] + row) % plane.height
                    for col in range(width):
                        # AIZ1_BGDrawArray keeps the upper band at draw X=0.
                        # Its 32 blocks fill the 512-pixel nametable and repeat
                        # under scanline deformation; lower rows stream normally.
                        source_width = 512 if sy < 0x220 else plane.width
                        view.putpixel((col, row), plane.getpixel(((scroll+col) % source_width, sy)))
            layers[plane_name, priority] = view
    composed = compose_planes(layers["background", False], layers["foreground", False],
                              layers["background", True], layers["foreground", True])
    # Match this core's documented normal-mode 4-bit-even channel expansion
    # and the capture host's RGB565 decoding. This is a comparison transform,
    # not a claim that a hardware display has one universal RGB palette.
    levels = []
    for level in range(8):
        four = level*2
        r5 = (four << 1) | (four >> 3)
        g6 = (four << 2) | (four >> 2)
        packed = (r5 << 11) | (g6 << 5) | r5
        levels.append(Image.frombytes("RGB", (1, 1), struct.pack("<H", packed), "raw", "BGR;16").getpixel((0, 0)))
    ram_after = (root / f"ram-{args.frame:05}.bin").read_bytes()
    transfer_counter = struct.unpack_from("<H", ram_after, 0xF624)[0] & 255
    palettes = water_scanline_palettes(rom, palette_words, word(0xF624) & 255, height, transfer_counter)
    pixels = []
    for index, pixel in enumerate(composed.get_flattened_data()):
        value = palettes[index//width][pixel[0]]
        pixels.append(tuple(levels[(value >> shift) & 7][channel]
                            for channel, shift in enumerate((1, 5, 9)))+(255,))
    composed.putdata(pixels)
    composed.save(root / "reconstructed-static.png")
    panel = Image.new("RGBA", (width*2, height), (0, 0, 0, 255))
    panel.paste(reference, (0, 0))
    panel.paste(composed, (width, 0), composed)
    panel.resize((width*4, height*2), Image.Resampling.NEAREST).save(root / "comparison.png")
    errors = sum(a[:3] != b[:3] for a, b in zip(reference.get_flattened_data(), composed.get_flattened_data()))
    bounds = sprite_bounds(ram)
    excluded = set()
    for sx, sy, sw, sh in bounds:
        excluded.update((px, py) for py in range(max(0, sy), min(height, sy+sh))
                        for px in range(max(0, sx), min(width, sx+sw)))
    unmasked_errors = sum(reference.getpixel((px, py))[:3] != composed.getpixel((px, py))[:3]
                          for py in range(height) for px in range(width)
                          if (px, py) not in excluded)
    regions = []
    for specification in args.region:
        rx, ry, rw, rh = map(int, specification.split(","))
        if rx < 0 or ry < 0 or rw <= 0 or rh <= 0 or rx+rw > width or ry+rh > height:
            raise ValueError("Comparison region must be inside the captured frame")
        box = (rx, ry, rx+rw, ry+rh)
        count = sum(a[:3] != b[:3] for a, b in zip(
            reference.crop(box).get_flattened_data(), composed.crop(box).get_flattened_data()))
        regions.append({"rectangle": [rx, ry, rw, rh], "pixel_mismatches": count,
                        "pixel_count": rw*rh})
    result = {"scroll_samples": len(checks), "scroll_failures": sum(bool(c["differences"]) or not c["background_y_matches"] for c in checks),
              "checks": checks, "static_comparison_frame": args.frame,
              "pixel_mismatches": errors, "pixel_count": width*height,
              "animation_counters": counters,
              "main_art_upload_end": main_upload_end,
              "plane_source": "captured-command persistent replay" if args.plane_history else "independent ROM map sampling",
              "water_screen_y": water_screen_y,
              "water_scroll_modeled": True,
              "underwater_palette_model": "ROM three-color groups; scanline timing under validation",
              "palette_transfer_limit_source": "Post-run RAM H-int counter; pre-run counter sets the latched interrupt row",
              "palette_source": "ROM normal-cycle tables, indexed by captured next-frame counters",
              "palette_word_differences": palette_differences,
              "explicit_regions": regions,
              "outside_sprite_bounds": {"pixel_mismatches": unmasked_errors,
                                        "pixel_count": width*height-len(excluded),
                                        "excluded_pixel_count": len(excluded),
                                        "sprite_bounds": bounds,
                                        "method": "Conservative linked SAT rectangles from pre-run RAM; includes transparent and occluded pixels."},
              "limitations": "Model uses captured camera/animation/cycle counters and excludes sprite rectangles. Palette staging is under validation; plane replay, if selected, uses captured commands and a seed. Independent drawing-command generation, full DMA timing and live layout mutations remain open. Pixel mismatch is not a fidelity pass."}
    (root / "comparison-report.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    (root / f"comparison-report-{args.frame:05}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    summary = {k:v for k,v in result.items() if k != "checks"}
    summary["outside_sprite_bounds"] = {k:v for k,v in result["outside_sprite_bounds"].items() if k != "sprite_bounds"}
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
