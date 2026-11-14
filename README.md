# Sonic 3 & Knuckles Remastered

An SMB1R-style fan project for the complete Sonic 3 & Knuckles campaign. The goal is to pair 60 FPS classic platforming and native 32:9 support with a user-provided ROM import flow, built-in level creation, custom characters, resource packs, and replay modes.

The project now includes a standalone movement and collision prototype with original placeholder visuals. Launch the project, then choose **Play movement prototype** from the intake screen. The room runs on Godot's fixed 60 Hz physics tick and does not require a ROM.

Phase 2 is complete as a playable prototype. Exact ROM fidelity gaps are tracked in the [ROM audit](docs/PHASE_2_ROM_AUDIT.md). Phase 3 (native 32:9 camera and display) is next.

## Project documents

- [Project scope](docs/PROJECT_SCOPE.md) — goals, release boundaries, acceptance criteria, and open decisions
- [Roadmap and stage tracker](docs/ROADMAP.md) — stage statuses, dependencies, checklists, and exit criteria
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
