"""Offline libretro reference capture host; never part of the Godot runtime.

Requires a user-installed Genesis Plus GX core and Pillow. Uses only the
hash-pinned local ROM. Captures and RAM stay outside Git in LOCALAPPDATA.
"""
import argparse
import ctypes as C
import hashlib
import gzip
import json
import os
import re
from pathlib import Path
from PIL import Image
from audit_aiz_content import read_image, PROFILE_HASH


class Game(C.Structure):
    _fields_ = [("path", C.c_char_p), ("data", C.c_void_p), ("size", C.c_size_t), ("meta", C.c_char_p)]


class Variable(C.Structure):
    _fields_ = [("key", C.c_char_p), ("value", C.c_char_p)]


class SystemInfo(C.Structure):
    _fields_ = [("name", C.c_char_p), ("version", C.c_char_p), ("extensions", C.c_char_p),
                ("need_fullpath", C.c_bool), ("block_extract", C.c_bool)]


ENV = C.CFUNCTYPE(C.c_bool, C.c_uint, C.c_void_p)
VIDEO = C.CFUNCTYPE(None, C.c_void_p, C.c_uint, C.c_uint, C.c_size_t)
AUDIO = C.CFUNCTYPE(None, C.c_int16, C.c_int16)
BATCH = C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t)
POLL = C.CFUNCTYPE(None)
INPUT = C.CFUNCTYPE(C.c_int16, C.c_uint, C.c_uint, C.c_uint, C.c_uint)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--frames", type=int, default=1800)
    parser.add_argument("--run", default="", help="Separate capture directory name under reference")
    parser.add_argument("--state-frame", type=int, action="append", default=[], help="Save diagnostic core state before/after this frame")
    parser.add_argument("--profile", choices=("sonic-tails", "sonic-alone"), default="sonic-tails")
    parser.add_argument("--dense", action="append", default=[], metavar="FIRST:LAST",
                        help="Capture every frame and compressed before/after states in this inclusive interval")
    parser.add_argument("--resume-state", type=Path, help="Local checkpoint from this host")
    parser.add_argument("--resume-frame", type=int, help="One-based frame to execute next")
    parser.add_argument("--input-script", type=Path, help="JSON list of {first_tick,last_tick,buttons} overrides")
    args = parser.parse_args()
    if not 1 <= args.frames <= 18000:
        parser.error("frames must be 1..18000")
    dense = set()
    for interval in args.dense:
        first, last = map(int, interval.split(":"))
        if not 1 <= first <= last <= args.frames:
            parser.error("dense intervals must be inside 1..frames")
        dense.update(range(first, last+1))
    if bool(args.resume_state) != bool(args.resume_frame):
        parser.error("resume-state and resume-frame are required together")
    if args.resume_frame and not 1 <= args.resume_frame <= args.frames:
        parser.error("resume-frame must be inside 1..frames")
    if args.resume_state:
        match = re.fullmatch(r"state-(before|after)-(\d+)\.bin(?:\.gz)?", args.resume_state.name)
        if not match or args.resume_frame != int(match[2]) + (match[1] == "after"):
            parser.error("resume-frame must match the checkpoint's before/after frame")
    overrides = json.loads(args.input_script.read_text()) if args.input_script else []
    for item in overrides:
        if not 0 <= item["first_tick"] <= item["last_tick"] < args.frames or any(b not in range(16) for b in item["buttons"]):
            parser.error("Invalid input override")
    root = Path(os.environ["LOCALAPPDATA"]) / "S3KRemastered/research/reference"
    core_path = root / "genesis_plus_gx_libretro.dll"
    if args.run:
        if not all(c.isalnum() or c in "-_" for c in args.run):
            parser.error("run name must contain only letters, numbers, hyphens or underscores")
        root = root / args.run
    root.mkdir(parents=True, exist_ok=True)
    if (root / "capture.json").exists() and (dense or args.resume_state):
        parser.error("Use a new run name to preserve existing dense/checkpoint evidence")
    core = C.CDLL(str(core_path))
    info = SystemInfo()
    core.retro_get_system_info.argtypes = [C.POINTER(SystemInfo)]
    core.retro_get_system_info(C.byref(info))
    variables = {}
    strings = [str(root).encode()]
    pixel_format, frame, latest = 0, 0, None
    trace = []

    @ENV
    def environment(command, pointer):
        nonlocal pixel_format
        if command in (9, 31):
            C.cast(pointer, C.POINTER(C.c_char_p))[0] = strings[0]
            return True
        if command == 3:
            C.cast(pointer, C.POINTER(C.c_bool))[0] = True
            return True
        if command == 10:
            pixel_format = C.cast(pointer, C.POINTER(C.c_int))[0]
            return pixel_format in (0, 1, 2)
        if command == 52:
            C.cast(pointer, C.POINTER(C.c_uint))[0] = 0
            return True
        if command == 16:
            entries = C.cast(pointer, C.POINTER(Variable))
            i = 0
            while entries[i].key:
                value = entries[i].value.split(b"; ", 1)[-1].split(b"|")[0]
                variables[entries[i].key] = value
                i += 1
            return True
        if command == 15:
            variable = C.cast(pointer, C.POINTER(Variable))
            value = variables.get(variable[0].key)
            variable[0].value = value
            return value is not None
        if command == 17:
            C.cast(pointer, C.POINTER(C.c_bool))[0] = False
            return True
        if command in (11, 18, 32, 37):
            return True
        return False

    @VIDEO
    def video(data, width, height, pitch):
        nonlocal latest
        if not data:
            return
        raw = C.string_at(data, pitch*height)
        if pixel_format == 1:
            latest = Image.frombytes("RGB", (width, height), raw, "raw", "BGRX", pitch)
        else:
            mode = "BGR;16" if pixel_format == 2 else "BGR;15"
            latest = Image.frombytes("RGB", (width, height), raw, "raw", mode, pitch)

    @AUDIO
    def audio(left, right):
        pass

    @BATCH
    def batch(data, count):
        return count

    @POLL
    def poll():
        pass

    def buttons(tick):
        # Reproducible boot/menu input; record it, never imply a route-completion trace.
        pressed = set()
        if tick in (300, 600, 900):
            pressed.add(3)  # Start
        if args.profile == "sonic-alone" and tick == 780:
            pressed.add(4)  # Up selects Sonic alone in the no-save slot.
        if tick >= 1200:
            pressed.add(7)  # Right
            if tick % 120 < 30:
                pressed.add(0)  # Genesis B / jump
        for item in overrides:
            if item["first_tick"] <= tick <= item["last_tick"]:
                pressed = set(item["buttons"])
        return pressed

    @INPUT
    def input_state(port, device, index, ident):
        return int(port == 0 and ident in buttons(frame))

    for name, callback, signature in (
        ("environment", environment, ENV), ("video_refresh", video, VIDEO),
        ("audio_sample", audio, AUDIO), ("audio_sample_batch", batch, BATCH),
        ("input_poll", poll, POLL), ("input_state", input_state, INPUT),
    ):
        setter = getattr(core, "retro_set_"+name)
        setter.argtypes = [signature]
        setter(callback)
    core.retro_init()
    core.retro_set_controller_port_device.argtypes = [C.c_uint, C.c_uint]
    core.retro_set_controller_port_device(0, 1)
    rom_data = read_image(args.rom)
    local_rom = root / "reference.md"
    local_rom.write_bytes(rom_data)
    rom = C.create_string_buffer(rom_data)
    game = Game(str(local_rom).encode(), C.cast(rom, C.c_void_p), len(rom)-1, None)
    core.retro_load_game.argtypes = [C.POINTER(Game)]
    core.retro_load_game.restype = C.c_bool
    core.retro_get_memory_data.argtypes = [C.c_uint]
    core.retro_get_memory_data.restype = C.c_void_p
    core.retro_get_memory_size.argtypes = [C.c_uint]
    core.retro_get_memory_size.restype = C.c_size_t
    core.retro_serialize_size.restype = C.c_size_t
    core.retro_serialize.argtypes = [C.c_void_p, C.c_size_t]
    core.retro_serialize.restype = C.c_bool
    core.retro_unserialize.argtypes = [C.c_void_p, C.c_size_t]
    core.retro_unserialize.restype = C.c_bool
    if not core.retro_load_game(C.byref(game)):
        raise RuntimeError("Core rejected supported ROM")
    try:
        if args.resume_state:
            parent = json.loads((args.resume_state.parent / "capture.json").read_text())
            if parent["rom_sha256"] != PROFILE_HASH or parent["core_sha256"] != hashlib.sha256(core_path.read_bytes()).hexdigest():
                raise ValueError("Checkpoint core/ROM profile mismatch")
            raw = gzip.decompress(args.resume_state.read_bytes()) if args.resume_state.suffix == ".gz" else args.resume_state.read_bytes()
            buffer = C.create_string_buffer(raw)
            if not core.retro_unserialize(buffer, len(raw)):
                raise RuntimeError("Core rejected checkpoint")

        def save_state(prefix, tick):
            size = core.retro_serialize_size()
            buffer = C.create_string_buffer(size)
            if not size or not core.retro_serialize(buffer, size):
                raise RuntimeError("Core serialization failed")
            if tick in dense:
                (root / f"state-{prefix}-{tick:05}.bin.gz").write_bytes(gzip.compress(buffer.raw, compresslevel=1, mtime=0))
            else:
                (root / f"state-{prefix}-{tick:05}.bin").write_bytes(buffer.raw)

        start_tick = (args.resume_frame or 1)-1
        for frame in range(start_tick, args.frames):
            state_requested = frame+1 in args.state_frame or frame+1 in dense
            capture_requested = frame % 60 == 59 or state_requested
            if state_requested:
                save_state("before", frame+1)
            if capture_requested:
                address = core.retro_get_memory_data(2)
                size = core.retro_get_memory_size(2)
                if address and size:
                    (root / f"before-{frame+1:05}.bin").write_bytes(C.string_at(address, size))
                video_address = core.retro_get_memory_data(3)
                video_size = core.retro_get_memory_size(3)
                if video_address and video_size:
                    (root / f"vram-before-{frame+1:05}.bin").write_bytes(C.string_at(video_address, video_size))
            core.retro_run()
            if state_requested:
                save_state("after", frame+1)
            if capture_requested:
                size = core.retro_get_memory_size(2)
                address = core.retro_get_memory_data(2)
                ram = C.string_at(address, size) if address and size else b""
                if ram:
                    (root / f"ram-{frame+1:05}.bin").write_bytes(ram)
                if latest:
                    latest.save(root / f"frame-{frame+1:05}.png")
                trace.append({"frame": frame+1, "ram_size": size,
                              "video_ram_size": video_size,
                              "image_size": latest.size if latest else None})
        (root / "capture.json").write_text(json.dumps({
            "rom_sha256": PROFILE_HASH, "core_sha256": hashlib.sha256(core_path.read_bytes()).hexdigest(),
            "core_name": info.name.decode(), "core_version": info.version.decode(),
            "region": "NTSC" if core.retro_get_region() == 0 else "PAL",
            "frames": args.frames, "pixel_format": pixel_format,
            "input_profile": args.profile, "state_frames": args.state_frame,
            "dense_intervals": args.dense, "first_tick": start_tick,
            "resume_state": str(args.resume_state) if args.resume_state else None,
            "resume_state_sha256": hashlib.sha256(args.resume_state.read_bytes()).hexdigest() if args.resume_state else None,
            "input_overrides": overrides,
            "options": {k.decode(): v.decode() for k, v in variables.items()},
            "input": [{"tick": t, "buttons": sorted(buttons(t))} for t in range(start_tick, args.frames)],
            "captures": trace, "reference_only": True,
        }, indent=2), encoding="utf-8")
        print(json.dumps({"output": str(root), "captures": len(trace), "last_frame": args.frames}))
    finally:
        core.retro_unload_game()
        core.retro_deinit()


if __name__ == "__main__":
    main()
