# Phase 3 — Camera and ultrawide display

**Status: Complete — prototype scope, 2026-11-14.** Started on `codex/phase-3-display`, from Phase 2 commit `b688d1e`.

## First deliverable

- Launch in a resizable 1600×450 window (32:9), as requested for testing in Godot. The logical framing still expands with the window aspect ratio. Restart the running game to apply the launch setting; Godot's embedded game panel can constrain its displayed size.
- Reuse the project's aspect-expanding canvas: 1280×720 at 16:9, 1680×720 at exact 21:9, and 2560×720 at 32:9. The 5120×1440 reference mode maps two physical pixels to one world unit. Vertical space and sprite proportions remain constant.
- Keep the Phase 2 world scale for this first pass. Fractional physical scaling (including 1920×1080 at 1.5×) is supported but is not a promise of uniform pixel-art texel sizes. Texture sharpness and art-density calibration are deferred to Phase 4, when gameplay art is integrated, per the project owner. They are not Phase 3 blockers.
- Move the camera out of the player hierarchy. Follow at a fixed physics cadence, with velocity-based look-ahead capped at 120 world units, bounded against the room, and snap after resize or checkpoint reset.
- Expose authored camera bounds for encounter/cutscene use. Regions smaller than the viewport are centered. The encounter fixture pairs this with screen-space masks that track camera transforms on resize, concealing the approach beyond the entrance and both sides of the locked arena.
- Center the HUD, help, and Back button within a configurable 1280-unit safe region. The existing intake menu uses a centered container.

## Trigger audit

The movement room's rings, hazard, checkpoint, and goal use world-space overlap/body-entry checks. None depends on camera visibility, screen edges, or render size. Scattered rings use physics-frame lifetime and collision. Wider visibility does not alter these activation conditions. The new encounter fixture activates at a world-space entrance, uses 120 physics ticks for its warning and 300 for its placeholder demonstration, and releases the camera and physical gates afterward. Campaign bosses, enemy spawners, and act transitions remain future content.

## Encounter staging fixture

Choose **Play encounter staging test** from the intake menu. Move right into the arena: the camera centers horizontally on the character, physical gates close, and a two-second warning precedes an original placeholder boss shape. After five seconds of demonstration, the gates open and the panoramic view returns; continue right to the goal. Press **R** to reset. Death/checkpoint reset also restores the concealed approach and clears the lock.

This fixture tests presentation and staging, not combat or ROM boss fidelity. The player remains controllable during the warning and demo. The staging camera tracks the character horizontally from spawn, through the encounter, and after release, without look-ahead or follow lag, while retaining fixed vertical framing. This fixture bypasses traversal camera edge clamping: at 32:9 the old left-edge clamp kept the approach stationary almost until arena entry. Ground markers and extended floor coverage make the scrolling visible. The movement prototype retains its bounded traversal camera. Side masks conceal everything outside the authored 1280-unit arena; near its edges, narrower displays show only the portion that fits around the centered player. Sprite scale and vertical play space remain unchanged. Live resizing recomputes the mask against the actual camera transform. The windowed 32:9 locked-arena render was captured and inspected; the project owner has since confirmed that camera following, multiple resolutions, hazards, and transitions worked in playtesting.

## Verification

Godot 4.7 headless checks passed at fixed render rates of 60 and 120:

```text
godot --headless --path . --fixed-fps 60 --script res://tests/gameplay/test_phase3.gd
godot --headless --path . --fixed-fps 120 --script res://tests/gameplay/test_phase3.gd
godot --headless --path . --fixed-fps 60 --script res://tests/gameplay/test_phase2.gd
godot --headless --path . --fixed-fps 120 --script res://tests/gameplay/test_phase2.gd
godot --headless --path . --fixed-fps 60 --script res://tests/gameplay/test_encounter.gd
godot --headless --path . --fixed-fps 120 --script res://tests/gameplay/test_encounter.gd
```

Phase 3 tests exercise actual viewport resizing at 1920×1080, 2520×1080 (exact 21:9), and 5120×1440; geometry tests cover safe-region placement, world edges, narrow authored bounds, look-ahead limits/direction, bounds release, and checkpoint reset. Encounter tests cover no activation before entry, exact cue/release tick boundaries, masking at all three aspects and during resize, physical collision with both gates, restart/death cleanup, and live player movement with rendered camera-center assertions at all three aspects. These functional tests are not performance benchmarks.

## Prototype closeout and follow-ups

- [x] Verify placeholder framing and aspect-aware scaling; texture sharpness and panoramic art calibration move to Phase 4 per the project owner (2026-11-14).
- [x] Add an encounter staging fixture with boss cues, camera clamps, side-reveal protection, world-space entry, timed release, and a world-space goal.
- [x] Playtest camera following, resolution changes, hazards, and transitions across multiple resolutions (project owner confirmation, 2026-11-14).
- [x] Accept prototype hazard behavior following the project owner’s explicit playtest confirmation. Additional automated matched-input comparisons remain optional regression coverage; they have not been run. Encounter tick boundaries are already covered.
- [x] Expose safe-region settings to players and verify menu/preview layout at each aspect ratio.
- [ ] Phase 4 follow-up: record a Windows hardware baseline and benchmark 60 FPS at 1920×1080 and 5120×1440. The owner reports good performance at 60 FPS; no formal benchmark is claimed.
- [x] Complete the camera/encounter prototype playable review (project owner confirmation, 2026-11-14); menu/settings playtesting also passed; formal performance baseline documentation carries into Phase 4.

Use **Play movement prototype** on the intake screen to try the camera and HUD changes. Phase 3 is closed at prototype scope following the owner’s confirmation that performance, aspect ratio, camera behavior, menus, and hazards work. Formal benchmarking and texture review carry into Phase 4.

Follow-camera verification now starts at spawn with all physics callbacks enabled and checks actual screen-center tracking during approach, demonstration, and exit at 16:9, 21:9, and 32:9 at 60/120 render FPS. A separate rendered 1600×450 run also confirmed the screen center follows the player throughout the approach and arena.

## HUD and menu settings

The intake menu and both prototypes now expose **HUD and menu placement** settings: centered 16:9, centered 21:9, or full-window width, plus an 8–64 logical-unit edge margin. In gameplay, use **HUD settings**, then **Close settings**. Changes apply immediately across the shared safe regions and persist in `user://display_settings.cfg`; **Restore default placement** restores centered 16:9 with margin 16. These settings do not change the gameplay viewport or camera. The settings panel does not pause simulation.

Intake and decoder menus use scrollable safe-region frames, so long import results and previews remain reachable. The central menu panel stays compact; choosing a wider safe region mainly spreads gameplay HUD controls and increases the menu's available scroll area.

`tests/gameplay/test_ui_settings.gd` passes for all three width modes, maximum margins, and all four screens at 1920×1080, 2520×1080, and 5120×1440. It checks live layout changes, persistence round trips, invalid preference handling, and long-result scrolling using a temporary settings file without overwriting player preferences. Rendered intake and in-game settings panels were inspected at the 1600×450 launch size. Run with `godot --headless --path . --fixed-fps 60 --script res://tests/gameplay/test_ui_settings.gd`.

Latest owner playtest confirmation: menus/settings work, gameplay runs at 60 FPS on the current setup, and the hazard check is accepted. This is user-reported performance, not a recorded benchmark at both reference resolutions.

Closeout: the project owner reconfirms that the game runs well and aspect ratio/camera locking work. This closes the prototype milestone; campaign boss fidelity and formal reference-resolution performance measurements are not claimed.
