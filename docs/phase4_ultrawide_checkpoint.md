# Phase 4 ultrawide terrain checkpoint — 2026-11-15

Worktree: agent/phase4-ultrawide-terrain (uncommitted; based on 3732585).

Changes: ROM terrain explorer uses 224-unit logical height with aspect-derived horizontal coverage; redraws on viewport resize, clamps its origin to layout dimensions, and avoids redundant rerender on unchanged viewport size. Terrain view rules and dedicated geometry/boundary tests added. Existing ROM-selection work copied from phase4-terrain-playable for isolation; do not overwrite original worktree.

Verified on Alienware_M15 with Godot 4.7: test_ultrawide_terrain.gd 0 failures; test_phase3.gd 0; test_rom_mechanics.gd 0; test_walking_slopes.gd 0; headless terrain scene launches without script errors; Python unittest discovery 34 tests OK. pytest is not installed in system Python; unittest is the working test runner. No actual ROM supplied to this headless test process; rendered ROM image, runtime FPS, player integration, and actual 5120x1440 GUI result remain unverified.

Next: test in GUI with user-provided ROM loaded via menu; profile render_region at 797x224 and scroll, verify alpha/background and seams. Integrate player controller + original collision path with terrain world coordinates, then test physics/encounter triggers independent of visible width. Avoid touching active codex-phase4-auto modifications and do not commit/push/merge.

## 2026-11-15 collision inspection integration
- Added ROM collision floor probe at center of Angel Island terrain explorer viewport.
- Godot terrain scene headless startup exit 0; geometry regression 0 failures; Phase 3 camera regression 0 failures.
- This is diagnostic integration, not a verified playable ROM terrain controller.
- Next: couple Sonic movement to ROM floor probes and implement reliable slopes/walls/ceilings; validate visually using a user-provided ROM without saving ROM data in Git.

## Playable integration attempt (2026-11-15)
- Added scripts/gameplay/rom_terrain_player.gd: initial keyboard-driven world-coordinate movement, jump/gravity, and ROM floor probe snap; placeholder Sonic visual.
- Wired player and horizontal-following camera into scripts/gameplay/aiz_terrain_explorer.gd. Shift+arrows pans manually; F toggles follow.
- New tests/gameplay/test_rom_traversal_smoke.gd preloads both scripts and validates airborne simulation.
- Verified Godot headless traversal smoke PASS; ultrawide geometry regression 0 failures; terrain scene startup exit 0.
- NOT VERIFIED: ROM-backed runtime, actual floor contact/slopes, visual playability, correct collision semantics or 32:9 performance. The standalone scene exits to menu without a loaded ROM.
- Next: exercise a ROM-backed session, verify floor probe contact and spawn, then tune original physics/camera; avoid merging parallel Codex player-controller edits.
- Blocker handling documented in docs/phase4_blocker_protocol.md.
