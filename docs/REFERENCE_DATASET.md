# Consecutive-frame ROM reference dataset

All files are local under `%LOCALAPPDATA%/S3KRemastered/research/reference`.
ROM, extracted graphics, raw memory and checkpoints remain outside Git.
The supported ROM and pinned Genesis Plus GX core are recorded in each run's
`capture.json`, together with every input tick, options and checkpoint provenance.

## Collected runs

| Directory | Purpose | Dense interval (inclusive) |
| --- | --- | --- |
| `sonic-dense-v1` | Uninterrupted Sonic-alone intro and first visible water | 2160–2280, 2920–3100 |
| `transition-dense-v1` | Uninterrupted Sonic+Tails capture of the known transition discrepancy | 2160–2280 |
| `checkpoint-verification-v1` | Replay from the Sonic-alone frame-2220 checkpoint | 2220–2240 |
| `route-roll-v1` | Failed roll-through route experiment | 2990–3030 |
| `route-jump-v1` | Successful advance past the first traversal obstacle | Sparse, every 60 frames |
| `route-boot-v1` | Uninterrupted replay of the revised route, plus a checkpoint near the next obstacle | 3290–3310; explicit checkpoint at 3300 |

For each dense frame the host saves the PNG, before/after 64 KiB work RAM,
and gzip-compressed before/after full core states. States contain VRAM,
native CRAM, VSRAM and VDP registers; work RAM includes the game's DMA queue.
Frame numbers are one-based; recorded input ticks are zero-based.

## Analysis and limits

Run `python tools/analyze_reference_sequence.py --run sonic-dense-v1` or
`--run transition-dense-v1` to rebuild `sequence-analysis.json`. The report
lists changed art tiles and plane cells, old/new background-table words,
palette changes, all 224 foreground/background scroll pairs, VSRAM, VDP
registers, DMA queue bytes and module-source/destination state per frame.

- Sonic-alone: 302 dense frames, zero state-continuity failures, 50 frames
  with background-table changes, 39 frames with visible water.
- The first visible-water frame is 2999, at screen Y=219.
- Sonic+Tails: 121 dense frames, zero state-continuity failures, 20 frames
  with background-table changes. This retains the frame-2220 discrepancy.
- Checkpoint replay: all 21 PNGs match the uninterrupted run. Work RAM has
  transient differences before converging; `replay-validation.json` records
  every differing CPU address. Use uninterrupted boot captures as timing
  authority; do not claim byte-exact checkpoint replay.
- The revised route holds Right and pulses jump for 35 of every 45 ticks,
  beginning at tick 2919. It advances beyond the previous camera-X region
  around `1E00` to around `2200`. This is a partial route, not act completion.

Before/after snapshots identify changed memory, not every intermediate write
or its within-scanline timestamp. Water palette switching may require finer
instrumentation if these captures and original code cannot determine timing.
No renderer fidelity gate is closed by collecting this dataset.

## Reproduction

Use a new run name to preserve existing evidence. With the supported ROM as
the positional argument to `tools/capture_reference.py`:

```text
--frames 3100 --run NEW-RUN --profile sonic-alone --dense 2160:2280 --dense 2920:3100
```

For a checkpoint experiment, supply `--resume-state` with a local
`state-before-NNNNN.bin.gz`, `--resume-frame NNNNN`, and a new `--run`.
`--input-script` accepts a JSON list of inclusive zero-based intervals with
`first_tick`, `last_tick` and `buttons`. These replace the baseline buttons
inside each interval; later overlapping entries take precedence. Button IDs
used here are B/jump=0, Start=3, Up=4, Down=5 and Right=7. The exact overrides
are embedded in each output manifest, so route recordings are self-contained.

## Validation checkpoint

The revised input sequence was replayed from a fresh boot (`route-boot-v1`).
All 27 sparse comparison PNGs from frames 2940..4500 match the checkpoint
experiment. At frame 3300 the camera reaches X `21F6`; compressed before/after
checkpoints are preserved there. This verifies the input segment without
relying on the checkpoint loader's transient RAM differences.

The six dataset directories total approximately 194.5 MiB at collection.
`dense-dataset-index.json` records manifest SHA-256 values, file counts and
sizes. All 28 Python tests pass, and `git diff --check` passes. These changes
add research tooling and evidence; they do not change the game runtime.

## Water-scroll model validation

`python tools/validate_aiz_water.py <supported-ROM> --run sonic-dense-v1`
creates `water-scroll-validation.json`. The current model matches all 17,472
foreground/background scroll words over the 39 visible-water frames. This
validates deformation only: underwater palette staging and fully submerged
camera entry are not certified. The comparison renderer now uses these ROM
water deltas; frame 3600 drops from 1,804 to 59 non-sprite mismatches, all one
remaining palette color pair. `HInt3`'s staged palette transfers are the next
rendering requirement.
