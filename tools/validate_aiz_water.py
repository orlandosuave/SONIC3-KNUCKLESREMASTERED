"""Validate modeled scanline scroll against local consecutive-frame VRAM captures."""
import argparse
import json
import os
from pathlib import Path
import struct
from audit_aiz_content import read_image, PROFILE_HASH
from aiz_scroll import normal_scroll, water_line_offsets, signed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--run", default="sonic-dense-v1")
    args = parser.parse_args()
    if not args.run or not all(c.isalnum() or c in "-_" for c in args.run):
        parser.error("Invalid run name")
    root = Path(os.environ["LOCALAPPDATA"]) / "S3KRemastered/research/reference" / args.run
    manifest = json.loads((root / "capture.json").read_text())
    if manifest["rom_sha256"] != PROFILE_HASH:
        raise ValueError("Unexpected ROM profile")
    rom = read_image(args.rom)
    sequence = json.loads((root / "sequence-analysis.json").read_text())
    checks = []
    for row in sequence["frames"]:
        if not 0 <= row["water_screen_y"] < 224:
            continue
        ram = (root / f"before-{row['frame']:05}.bin").read_bytes()
        word = lambda a: struct.unpack_from("<H", ram, a)[0]
        model = normal_scroll(word(0xEE80), word(0xEE84),
                              ((word(0xA83C)<<16)|word(0xA83E))-0x2000)
        fg, bg = water_line_offsets(rom, model, word(0xEE80), word(0xEE84), word(0xF646), word(0xFE04))
        expected = [signed(-value, 16) for pair in zip(fg, bg) for value in pair]
        differences = [i for i, (a, b) in enumerate(zip(expected, row["hscroll_after"])) if a != b]
        checks.append({"frame": row["frame"], "water_screen_y": row["water_screen_y"],
                       "word_differences": differences})
    report = {"frames": len(checks), "compared_words": len(checks)*448,
              "mismatched_words": sum(len(r["word_differences"]) for r in checks),
              "checks": checks, "scope": "Scanline scroll only; no underwater palette or full-scene fidelity claim"}
    (root / "water-scroll-validation.json").write_text(json.dumps(report, indent=2))
    print(json.dumps({k:v for k,v in report.items() if k != "checks"}, indent=2))
    if not checks or report["mismatched_words"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
