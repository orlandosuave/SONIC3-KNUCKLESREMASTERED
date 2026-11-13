# Sonic 3 & Knuckles Remastered

An SMB1R-style fan project for the complete Sonic 3 & Knuckles campaign. The goal is to pair 60 FPS classic platforming and native 32:9 support with a user-provided ROM import flow, built-in level creation, custom characters, resource packs, and replay modes.

This repository currently contains the project scope and a minimal Godot starter scene. It does not yet contain playable mechanics or game assets.

## Project documents

- [Project scope](docs/PROJECT_SCOPE.md) — goals, release boundaries, acceptance criteria, and open decisions
- [Reference analysis](docs/REFERENCE_ANALYSIS.md) — SMB1R's user-ROM pipeline, Sonic 3 A.I.R.'s release lessons, and the proposed Sonic architecture

## Current foundation

- Engine: Godot 4.x (provisional)
- First target: Windows PC; keep the project portable for later desktop builds
- Display target: correct aspect-aware rendering from 16:9 through native 32:9
- Gameplay target: fixed 60 Hz simulation and stable 60 FPS
- ROM handling: a compatible combined S3&K ROM is selected by the user and processed into local generated data; ROMs and generated game data stay out of Git and public release packages
- Content direction: original work and content the project has permission to use

See the scope document before adding major features so implementation stays aligned with the agreed first release.
