# Phase 4: Screenshot-scale and original sound-driver integration
Date: 2026-11-22
Status: PLANNED AND QUEUED; NOT IMPLEMENTED OR VERIFIED.

## Scope and source of truth

The playable Angel Island Zone Act 1 slice must match the owner's 32:9 visual screenshot in relative scale while filling a 5120x1440 viewport with world art. Sonic, terrain, trees and palms, star posts/checkpoints, rings, sprites, and environmental objects must preserve their original relative proportions. The display may reveal more of the map horizontally; it must not make objects larger/smaller independently, stretch the background, fake tiles, or change original physics coordinates. The reference screenshot must be obtained as a task input and measured before a similarity gate can pass; no screenshot-derived dimensions are certified by this document.

Audio comes from the user's supported, locally supplied combined Sonic 3 & Knuckles ROM. The checked-in local reference disassembly has Z80 sound-driver research, 60 Music ASM entries, 171 SFX ASM entries and DAC sample references. This is a research inventory, NOT proof that all relevant sequences have been extracted from the exact supported ROM, that compatible audio can already be heard in Godot, or that the definitions can be redistributed.

**Do not commit/publish ROM bytes, decoded music/SFX/DAC samples, private captures or disassembly-owned content.** Source evidence and test summaries may be version-controlled. Keep generated audio and video in the configured private user cache.

## The source-faithful audio model

- Decode the supported ROM's music/SFX ID tables, tracks and voice definitions with checked pointers, format bounds, provenance and deterministic schema-versioned caching.
- Reconstruct FM synthesis (YM2612 semantics), PSG commands and DAC samples using a qualified implementation or documented equivalent local rendering route. Never call pre-rendered replacement recordings "original" without ROM-source verification.
- Implement driver-level timing at the existing fixed 60Hz gameplay tick. Preserve tempo, sequence loops, per-channel scheduling, SFX priority and override, music-channel restoration, fade/stop, and pause/resume semantics from verified original traces.
- Music events: title/menu, AIZ1, temporary jingles, invincibility/speed status, boss entry, death/retry, act clear, game over. Only trigger events actually present in the playable slice; unknown or absent event paths must stay marked as pending.
- SFX events: ring pickup, jump, roll/spin dash, ring spill/hit, checkpoint star post, water/splash, environment and boss cues. Trigger once per valid action/event; apply original channel arbitration so overlapped sounds remain intelligible and deterministic.
- Persist music and SFX volume controls separately from ROM caches and saves. Audio focus/device loss must not crash gameplay, restart every cue or change 60Hz simulation.
- Measure real end-to-end listening, mix peaks, loop offsets, tick/cue parity and interruption against private supported-ROM reference captures. Headless event tests cannot certify audible fidelity.

## Dependency-aware implementation bundles

Each named stage is five ledger entries: bounded implementation, independent verification, independent review, dormant failure recovery, follow-up. No acceptance without fresh isolated worktree, allowed-files check, Godot import and parser preflight, positive test sentinel, logs and hashes, real candidate commit, signed-off receipt, and branch push verification when appropriate.

1. `p4scale`: measure screenshot-relative geometry, verify 5120x1440 visual scale, preserve original coordinate system. Gates existing `p4wide-impl-01` via `p4scale-followup-01`.
2. `p4audmap`: supported-ROM sound IDs and Z80 driver behavior inventory. Starts after `p4wide-followup-01`; runs as an independent branch so a failed audio task cannot block `p4cam` and later visual work.
3. `p4auddecode`: local decoder and versioned private music/SFX/DAC cache.
4. `p4audplay`: working AIZ1 playback and representative ring/jump SFX from source-derived audio, with loop proof.
5. `p4auddriver`: scheduling, priority/voice stealing, fade, stop and pause semantics.
6. `p4audmusic`: cue transitions and jingles tied to actual scene/event states.
7. `p4audsfx`: exact triggers and precedence for player/ring/checkpoint actions.
8. `p4audworld`: AIZ water/ignition/boss environmental cue contracts; no prototype event taken as real boss implementation.
9. `p4audsettings`: volumes, pause/device recovery and persistent preferences.
10. `p4audqa`: private reference capture and trace comparison, audible QA, cache-failure and regression suite.

Task bundle: `D:\AI\SonicPhase4Queue\PHASE4_SCALE_AUDIO_20261122.json`
Queue ledger: `D:\AI\SonicPhase4Queue\queue.sqlite3`
Queue check: `python -B D:\AI\SonicPhase4Queue\queue.py validate`
Queue next: `python -B D:\AI\SonicPhase4Queue\queue.py next`
Backup: `D:\AI\SonicPhase4Queue\queue.sqlite3.before-scale-audio-20261122`

## Run discipline and limitations

- Do not modify the main checkout or prior failed worktrees. Preserve active Sonic tasks; only dispatch the dependency-ready card returned by queue.py.
- Only one coding model job at a time, under the existing GPU/queue ownership and local resource controls. No duplicate workers.
- The queue ledger reports `automatic_dispatch: false`; merely installing cards does not launch or restart a coding agent.
- Existing AIZ render/route/compare/playtest work remains ahead of these tasks. A dedicated earlier `aiz1-5120-display` card family may also run after render.
- The new soundtrack/audio runtime is not yet implemented. If FM/PSG/DAC synthesis, source extraction or reference matching is blocked, preserve evidence, activate scoped recovery and continue independent eligible visual tasks.
- Audio rights: a user-supplied ROM may be processed locally; do not assume it authorizes public redistribution of audio content.
