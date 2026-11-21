# Local original-ROM capture and comparison

**Established 2026-11-14.** This is offline research tooling. The Godot runtime still imports data and implements its own game; it does not execute the ROM or load an emulator core.

## Local setup and provenance

The owner had no emulator installed. A portable Genesis Plus GX libretro core was downloaded from the [official Windows x64 build directory](https://buildbot.libretro.com/nightly/windows/x86_64/latest/), following [the core documentation](https://docs.libretro.com/library/genesis_plus_gx/). The host uses the [official libretro API](https://github.com/libretro/libretro-common/blob/master/include/libretro.h). No RetroArch installation or visible background window is required.

- Local core: `%LOCALAPPDATA%/S3KRemastered/research/reference/genesis_plus_gx_libretro.dll`.
- Reported version: `Genesis Plus GX v1.7.4 b9c2316`.
- Core SHA-256: `87696b6f8d4952a1dbb7cb4f7608065736dcb38071862bc594d6d81a2ca53502`.
- Input: the existing hash-pinned 4 MiB combined ROM; region reported by the core: NTSC.
- The supplied archive remains unchanged. A byte-identical private `.md` copy is created in the reference directory because the core needs a file path.
- Core binary, ROM copy, screenshots, RAM snapshots, downloaded API/source references and detailed traces stay in local application data. None is distributed or committed.

Use a trusted official core. The scripts do not download or execute a core automatically from an unverified URL. Current tooling expects the installed Windows DLL at the path above; a different build must be recorded and compared again.

## Reproduce

Requires Python and Pillow. From the project directory:

```text
python tools/capture_reference.py <supported-local-ROM-or-ZIP> --frames 3600 --run new-evidence-name
python tools/compare_aiz_reference.py <supported-local-ROM-or-ZIP> --frame 2220 --run new-evidence-name
python tools/compare_aiz_reference.py <supported-local-ROM-or-ZIP> --frame 2640 --run new-evidence-name
python -m unittest discover -s tests -p "test_aiz_*.py"
```

The capture host uses a fresh in-memory session, scripted Start inputs at ticks 300/600/900 and right/jump inputs after tick 1200. It records every input tick and captures every 60th frame, with both pre-run and post-run RAM. Audio is consumed without playback. `capture.json` records the core hash/version, ROM identity, options, region and sample list. This boot sequence reaches default Sonic-and-Tails gameplay; it is **not yet the planned Sonic-alone route suite**, a complete traversal, or an act-completion test. The screenshots visibly include Tails.

As of 2026-11-21, every capture uses a new directory. Omitting `--run` generates a UTC timestamp plus random suffix; an existing directory is rejected even for a non-dense capture. Use the printed run name with comparison tools. Older captures directly under the reference directory remain available with the comparison tool's default empty run. Comparison is deliberately limited to the documented 1740–3600-frame boot/traversal window; it is not a general arbitrary-save-state analyzer. Its intro/main classification is a window-specific heuristic based on background Y and requires tightening before wider use.

## Scroll model and measured result

`tools/aiz_scroll.py` implements the intro and normal dry-background calculations with signed 16/32-bit behavior. `line_offsets` expands the band's per-scanline sections from the tables in the supported ROM (`0x23B20A`, `0x23B258`). Evidence comes from the lock-on screen-event routines, `ApplyDeformation`, and actual emulator RAM.

In the installed core's memory interface, the captured 64 KiB work RAM is word-swapped: little-endian host words correspond to original CPU words. The comparison reads camera copies at `0xEE80/0xEE84`, background Y at `0xEE90`, intro override at `0xEEB6`, and scroll words at `0xA800`. Normal-mode phase is reconstructed from the captured post-update value minus its one-update increment.

**Result:** 32 eligible sampled snapshots (8 intro, 24 normal) have zero mismatches in all modeled scroll words and background Y. These are samples every 60 frames, not a claim that every simulated tick or every background mode has passed. The dry normal model's sample set spans the intro resource swap and early traversal. Water distortion, ignition/fire deformation and later-map deformation are not covered.

## Pixel comparison and discovered gaps

The displayed image corresponds to camera state preceding the current update in this capture setup. Comparing it against post-run camera RAM caused a spatial mismatch; the renderer now uses the saved pre-run state for pixel comparisons. For example, frame 2220's pre-run camera is `(0x147E, 0x38B)`, while post-run is `(0x1484, 0x390)`.

The independent static renderer uses a simple 3-bit-to-8-bit palette expansion. The installed core uses normal-mode even 4-bit channel levels converted to RGB565. `compare_aiz_reference.py` applies that documented core-specific output conversion for comparison only, based on [Genesis Plus GX's VDP renderer](https://github.com/libretro/Genesis-Plus-GX/blob/master/core/vdp_render.c). This is not a claim that an original analog display has one universal RGB mapping.

| Reference frame | Compared pixels | Mismatches after timing/color alignment |
|---|---:|---:|
| 2220 | 71680 | 7952 |
| 2640 | 71680 | 18313 |

These full-frame counts include HUD, title-card text, Sonic/Tails, enemies and other objects absent from the static renderer. **They are not fidelity passes or terrain-only accuracy scores.** Inspection of frame 2640 also exposes an absent canopy region and differing animated details, so missing sprites alone do not explain the result. The raw-plane/background transform and animated upload coverage need further work. Exact causal attribution requires masked/region-level comparisons and original live graphics-state tracing.

Reference captures were rerun with the same inputs and core; frame 2640's PNG hash was identical. This is a repeatability check on one image, not whole-run determinism certification. Twenty-one synthetic tests pass for the existing decoders, attributes, compositing and new signed scroll/band logic.

Next: resolve canopy/animated tile uploads and actual background drawing transforms; add water/fire modes; select Sonic alone reproducibly; compare carefully defined terrain regions and per-tick traces. Keep G0/G1 open until their own required evidence is met.

AIZ1 frame comparisons now apply ROM animation scripts at `0x28752` using captured next-frame counters (`F7F0/F7F2/F7F4`). Frame 2640 has 17,968 mismatches after this change (previously 18,313); frame 2220 remains 7,952. Background canopy alignment and DMA timing remain unresolved. The comparison still excludes object/HUD reconstruction and is not a fidelity pass.

Upper-background wrap correction: for normal AIZ1 rows below source Y `0x220`, sample X modulo 512 to reflect the fixed upper-band nametable draw. Frame 2640 now has 6,179 total mismatches. Run with `--frame 2640 --region 120,0,90,70 --region 80,160,240,64` to reproduce canopy (0/6,300) and lower-terrain (1,696/15,360) diagnostics. These explicit regions do not automatically exclude sprites in other frames.

The comparison now records `outside_sprite_bounds`: conservative linked sprite-table rectangles from pre-run RAM `F800` are excluded, including their transparent pixels. It also uses captured normal palette words at `FC00`, explicitly marked in the report. Frames 2640 and 2700 have zero differences outside those bounds (59,003 and 56,624 compared pixels respectively). Frame 2220 retains 309 differences. Palette-cycle logic and sprite/DMA timing remain independent validation work; this is not full-scene parity.

Normal AIZ1 comparison palettes now come from ROM tables `2AF6/2BF6` indexed by captured next-cycle counters, not captured RGB/palette words. All 64 words match in 24 snapshots (frames 2220..3600); independent 60-tick cycle advancement matches 23 consecutive intervals. The renderer still uses captured counter state as its starting point. Frame 2220's remaining 309 mismatches occupy X 1..56, Y 155..164 and remain unresolved.

## Named runs and graphics-state diagnostics

Preserve earlier captures with `--run sonic-alone --profile sonic-alone --frames 3600`. The input profile chooses Sonic alone through the ordinary menu; RAM `FF08=1` verifies the choice. Use the same `--run sonic-alone` with the comparison tool. `segment-summary.json` records 24 selected frames: 14 match outside sprite rectangles; ten enter currently unsupported visible water. The input trace has not completed the act.

For targeted graphics-memory inspection, capture with `--run graphics-state --frames 2220 --state-frame 2220`, then run `python tools/inspect_reference_state.py --run graphics-state --frame 2220`. Core state stays local. The inspector accepts only the pinned core build, checks the state signature and captured RAM identity, and handles its native word order. It is a research diagnostic, not a game dependency. State layout was checked against the core's [state serialization](https://raw.githubusercontent.com/libretro/Genesis-Plus-GX/b9c2316/core/state.c) and [VDP context serialization](https://raw.githubusercontent.com/libretro/Genesis-Plus-GX/b9c2316/core/vdp_ctrl.c).

The original frame-2220 background-table difference survives correct static art and palette reconstruction. Full fidelity requires incremental plane drawing/upload history. Comparisons additionally flag `unsupported_visible_water` when the waterline intersects the frame. These limitations must remain visible in any interpretation of pixel counts.

Dense captures and validated checkpoint/route experiments are now available; see [REFERENCE_DATASET.md](REFERENCE_DATASET.md). `capture_reference.py` supports repeatable `--dense FIRST:LAST` intervals, compressed states, validated checkpoint/frame pairs and recorded input overrides. `analyze_reference_sequence.py` writes local per-frame graphics/scroll/upload change reports. Uninterrupted boot captures remain authoritative when checkpoint replay has transient RAM differences.
