"""Replay original plane-write commands into persistent reference nametables.

Captured commands are oracle inputs, not independently generated gameplay.
The model seeds once, then retains untouched cells across consecutive frames.
"""
import argparse
import gzip
import json
import os
from pathlib import Path
import struct
from inspect_reference_state import CORE_HASH, state_vram


def apply_plane_commands(vram, commands):
    if len(vram) != 65536:
        raise ValueError("Expected 64 KiB VRAM")
    cursor, writes = 0, 0
    while cursor+2 <= len(commands):
        destination = struct.unpack_from(">H", commands, cursor)[0]
        cursor += 2
        if destination == 0:
            return writes
        if cursor+2 > len(commands):
            raise ValueError("Truncated plane command")
        flags = struct.unpack_from(">H", commands, cursor)[0]
        cursor += 2
        count = (flags & 0x7FFF)+1
        if count > 32 or cursor+count*8 > len(commands):
            raise ValueError("Invalid plane command length")
        stride, second = (128, 2) if flags & 0x8000 else (2, 128)
        for offset in (0, second):
            address = destination+offset
            for _ in range(count*2):
                if not (0xC000 <= address < 0xD000 or 0xE000 <= address < 0xF000) or address & 1:
                    raise ValueError("Plane write outside expected nametables")
                vram[address:address+2] = commands[cursor:cursor+2]
                cursor += 2
                address += stride
                writes += 1
    raise ValueError("Missing plane command terminator")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", default="transition-dense-v1")
    args = parser.parse_args()
    if not args.run or not all(c.isalnum() or c in "-_" for c in args.run):
        parser.error("Invalid run name")
    root = Path(os.environ["LOCALAPPDATA"]) / "S3KRemastered/research/reference" / args.run
    manifest = json.loads((root / "capture.json").read_text())
    if manifest["core_sha256"] != CORE_HASH:
        raise ValueError("Unsupported reference core")
    checks, previous, vram = [], None, None
    for entry in manifest["captures"]:
        frame = entry["frame"]
        before_path = root / f"state-before-{frame:05}.bin.gz"
        if not before_path.exists():
            continue
        ram = (root / f"before-{frame:05}.bin").read_bytes()
        if previous != frame-1:
            vram = bytearray(state_vram(gzip.decompress(before_path.read_bytes()), ram))
        commands = ram[0xF100:0xF580]
        commands = bytes(v for i in range(0, len(commands), 2) for v in (commands[i+1], commands[i]))
        writes = apply_plane_commands(vram, commands)
        actual = state_vram(gzip.decompress((root / f"state-after-{frame:05}.bin.gz").read_bytes()),
                            (root / f"ram-{frame:05}.bin").read_bytes())
        expected_planes = vram[0xC000:0xD000]+vram[0xE000:0xF000]
        actual_planes = actual[0xC000:0xD000]+actual[0xE000:0xF000]
        differences = sum(expected_planes[i:i+2] != actual_planes[i:i+2] for i in range(0, 8192, 2))
        (root / f"planes-{frame:05}.bin").write_bytes(expected_planes)
        checks.append({"frame": frame, "word_writes": writes, "word_mismatches": differences,
                       "seeded": previous != frame-1})
        previous = frame
    result = {"frames": len(checks), "word_mismatches": sum(r["word_mismatches"] for r in checks),
              "checks": checks, "scope": "One captured seed per contiguous interval; captured ROM plane commands replayed thereafter"}
    (root / "plane-history-validation.json").write_text(json.dumps(result, indent=2))
    print(json.dumps({k:v for k,v in result.items() if k != "checks"}, indent=2))
    if not checks or result["word_mismatches"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
