# Sonic 3 & Knuckles Remastered

An SMB1R-style fan project for the complete Sonic 3 & Knuckles campaign. The goal is to pair 60 FPS classic platforming and native 32:9 support with a user-provided ROM import flow, built-in level creation, custom characters, resource packs, and replay modes.

The project now includes a standalone movement and collision prototype with original placeholder visuals. Launch the project, then choose **Play movement prototype** from the intake screen. The room runs on Godot's fixed 60 Hz physics tick and does not require a ROM.

Choose **Play encounter staging test** to try the Phase 3 character-centered encounter camera and ultrawide side masks. Move right to enter, wait through the warning and placeholder boss demo, then continue to the goal. **R** restarts this test. It uses original placeholder visuals and has no boss attacks yet.

Phase 2 is complete as a playable prototype. Exact ROM fidelity gaps are tracked in the [ROM audit](docs/PHASE_2_ROM_AUDIT.md). Phase 3 (native 32:9 camera and display) is complete at prototype scope following successful owner playtests. See the [Phase 3 closeout](docs/PHASE_3_PLAN.md) for validation and follow-ups. Phase 4 is now in progress, starting with the [content and fidelity audit](docs/PHASE_4_CONTENT_AUDIT.md); the complete act is not yet playable.

## Project documents

- [Project scope](docs/PROJECT_SCOPE.md) — goals, release boundaries, acceptance criteria, and open decisions
- [Roadmap and stage tracker](docs/ROADMAP.md) — stage statuses, dependencies, checklists, and exit criteria
- [Phase 4 plan](docs/PHASE_4_PLAN.md) — complete-act work packages, delivery gates, fidelity dependencies, and acceptance checks
- [Original-ROM reference captures](docs/REFERENCE_CAPTURE.md) — local emulator tooling, scroll comparisons, measured visual gaps, and reproduction commands
- [Phase 2 plan](docs/PHASE_2_PLAN.md) — completed movement prototype, validation, and fidelity follow-ups
- [Phase 1 plan](docs/PHASE_1_PLAN.md) — ROM intake, decoding proof set, local cache, and detailed acceptance checks
- [Reference analysis](docs/REFERENCE_ANALYSIS.md) — SMB1R's user-ROM pipeline, Sonic 3 A.I.R.'s release lessons, and the proposed Sonic architecture
- [ROM intake profile](docs/ROM_IMPORT_SPEC.md) — inspected candidate image metadata and the initial local-only intake contract
- [ROM format notes](docs/ROM_FORMAT_NOTES.md) — Phase 1 proof-set structures, current confidence, and decoder status

## Current foundation

- Engine: Godot 4.7 stable, standard GDScript build
- First target: Windows PC; keep the project portable for later desktop builds
- Display target: correct aspect-aware rendering from 16:9 through native 32:9
- Gameplay target: fixed 60 Hz simulation and stable 60 FPS
- Prototype controls: A/D or arrow keys to move, Space/Up/Z to jump, Down/S or X to roll; hold Down and tap Space/Z to charge Spin Dash, then release Down
- ROM handling: a compatible combined S3&K ROM is selected by the user and processed into local generated data; ROMs and generated game data stay out of Git and public release packages
- Content direction: original work and content the project has permission to use

See the scope document before adding major features so implementation stays aligned with the agreed first release.

## Gameplay regression checks

Open `project.godot` in Godot 4.7 or run these commands with its executable on PATH:

```text
godot --headless --path . --fixed-fps 60 --script res://tests/gameplay/test_phase2.gd
godot --headless --path . --fixed-fps 120 --script res://tests/gameplay/test_phase2.gd
```

These tests require no ROM or imported assets.

HUD placement can be adjusted from the intake menu or **HUD settings** in either prototype. Choose centered 16:9, centered 21:9, or full-window placement and an edge margin. Changes save automatically; menus scroll when their contents exceed the available height.
