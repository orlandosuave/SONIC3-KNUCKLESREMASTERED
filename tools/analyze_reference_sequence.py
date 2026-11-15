"""Summarize consecutive local captures, retaining exact upload/scroll evidence."""
import argparse
import gzip
import json
import os
from pathlib import Path
import struct
from inspect_reference_state import CORE_HASH, VRAM_OFFSET, state_vram


def changed_units(before, after, unit):
    if len(before) != len(after) or len(before) % unit:
        raise ValueError("Comparison buffers must have equal, unit-aligned lengths")
    return [i//unit for i in range(0, len(before), unit) if before[i:i+unit] != after[i:i+unit]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    args = parser.parse_args()
    if not args.run or not all(c.isalnum() or c in "-_" for c in args.run):
        parser.error("Invalid run name")
    root = Path(os.environ["LOCALAPPDATA"]) / "S3KRemastered/research/reference" / args.run
    manifest = json.loads((root / "capture.json").read_text())
    if manifest["core_sha256"] != CORE_HASH:
        raise ValueError("Unsupported core profile")
    frames = []
    previous_frame, previous_after = None, None
    for sample in manifest["captures"]:
        tick = sample["frame"]
        files = [root / f"state-{side}-{tick:05}.bin.gz" for side in ("before", "after")]
        if not all(p.exists() for p in files):
            continue
        before, after = [gzip.decompress(p.read_bytes()) for p in files]
        ram = (root / f"before-{tick:05}.bin").read_bytes()
        ram_after = (root / f"ram-{tick:05}.bin").read_bytes()
        vb, va = state_vram(before, ram), state_vram(after, ram_after)
        word = lambda address: struct.unpack_from("<H", ram, address)[0]
        bg_cells = changed_units(vb[0xE000:0xF000], va[0xE000:0xF000], 2)
        fg_cells = changed_units(vb[0xC000:0xD000], va[0xC000:0xD000], 2)
        color_base = VRAM_OFFSET+65536
        row = {"frame": tick, "camera": [word(0xEE80), word(0xEE84)],
               "background_y": word(0xEE90), "player_mode": word(0xFF08),
               "water_screen_y": word(0xF646)-word(0xEE84),
               "module_source": (word(0xFF64)<<16)|word(0xFF66),
               "module_destination": word(0xFF68),
               "changed_art_tiles": changed_units(vb[:0xC000], va[:0xC000], 32),
               "changed_fg_cells": fg_cells, "changed_bg_cells": bg_cells,
               "bg_writes": [[i, struct.unpack_from(">H", vb, 0xE000+i*2)[0],
                              struct.unpack_from(">H", va, 0xE000+i*2)[0]] for i in bg_cells],
               "changed_cram_entries": changed_units(before[color_base:color_base+128], after[color_base:color_base+128], 2),
               "hscroll_after": list(struct.unpack_from(">448h", va, 0xF000)),
               "vsram_after_hex": after[color_base+128:color_base+256].hex(),
               "vdp_registers_after_hex": after[color_base+256:color_base+288].hex(),
               "dma_queue_before_hex": ram[0xFB00:0xFC00].hex(),
               "consecutive_state_matches": previous_after == before if previous_frame == tick-1 else None}
        frames.append(row)
        previous_frame, previous_after = tick, after
    result = {"run": args.run, "dense_frames": len(frames),
              "state_continuity_failures": sum(r["consecutive_state_matches"] is False for r in frames),
              "visible_water_frames": sum(r["water_screen_y"] < 224 for r in frames),
              "frames_with_bg_updates": sum(bool(r["changed_bg_cells"]) for r in frames),
              "frames": frames,
              "limits": "Before/after snapshots reveal changed bytes, not every intermediate VDP write or within-scanline timing. CRAM is core-native encoding."}
    (root / "sequence-analysis.json").write_text(json.dumps(result, indent=2))
    print(json.dumps({k:v for k,v in result.items() if k != "frames"}, indent=2))


if __name__ == "__main__":
    main()
