"""Inspect the pinned local core's diagnostic state; never a runtime importer.

Layout reference: Genesis-Plus-GX b9c2316 core/state.c and core/vdp_ctrl.c.
Only the Windows x64 MD state profile used by capture_reference is supported.
"""
import argparse
import json
import os
from pathlib import Path
import struct

CORE_HASH = "87696b6f8d4952a1dbb7cb4f7608065736dcb38071862bc594d6d81a2ca53502"
VRAM_OFFSET = 16 + 65536 + 8192 + 1 + 4 + 16 + 1024


def state_vram(state, expected_ram):
    if len(expected_ram) != 65536 or state[:16] != b"GENPLUS-GX 1.7.6":
        raise ValueError("Unsupported reference state")
    if state[16:16+65536] != expected_ram or len(state) < VRAM_OFFSET+65536:
        raise ValueError("State RAM does not match the corresponding capture")
    raw = state[VRAM_OFFSET:VRAM_OFFSET+65536]
    return bytes(value for i in range(0, len(raw), 2) for value in (raw[i+1], raw[i]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True)
    parser.add_argument("--frame", type=int, default=2220)
    args = parser.parse_args()
    if not args.run or not all(c.isalnum() or c in "-_" for c in args.run):
        parser.error("Invalid run name")
    root = Path(os.environ["LOCALAPPDATA"]) / "S3KRemastered/research/reference" / args.run
    manifest = json.loads((root / "capture.json").read_text(encoding="utf-8"))
    if manifest["core_sha256"] != CORE_HASH:
        raise ValueError("Unsupported core build")
    ram = (root / f"before-{args.frame:05}.bin").read_bytes()
    vram = state_vram((root / f"state-after-{args.frame:05}.bin").read_bytes(),
                      (root / f"ram-{args.frame:05}.bin").read_bytes())
    word = lambda address: struct.unpack_from("<H", ram, address)[0]
    # Reproducible probe of the original Sonic+Tails frame-2220 discrepancy.
    x, y = word(0xEE80)+1, word(0xEE84)+155
    fg_address = 0xC000 + ((y//8)%32*64+(x//8)%64)*2
    bg_x = -struct.unpack_from(">h", vram, 0xF000+155*4+2)[0]+1
    bg_y = word(0xEE90)+155
    bg_address = 0xE000 + ((bg_y//8)%32*64+(bg_x//8)%64)*2
    result = {"frame": args.frame, "probe_screen_xy": [1, 155],
              "foreground_world_xy": [x, y], "background_source_xy": [bg_x, bg_y],
              "foreground_vram_word": hex(struct.unpack_from(">H", vram, fg_address)[0]),
              "background_vram_word": hex(struct.unpack_from(">H", vram, bg_address)[0]),
              "main_module_destination": hex(word(0xFF68)),
              "scope": "Diagnostic upload/nametable evidence, not independent frame reconstruction"}
    (root / f"state-inspection-{args.frame:05}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
