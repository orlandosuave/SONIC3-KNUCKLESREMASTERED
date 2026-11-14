# Project Roadmap and Stage Tracker

This file is the stage-level source of truth for the project. It lives in the GitHub repository, so each status change is recorded in the commit history. Detailed product requirements remain in [PROJECT_SCOPE.md](PROJECT_SCOPE.md); technical reference findings are in [REFERENCE_ANALYSIS.md](REFERENCE_ANALYSIS.md).

## Current stage

**Stage 1 — ROM intake and data feasibility spike** is in progress. Stage 0 is complete. The first candidate combined image has been inspected locally; work now covers a narrow, explicit intake profile before any asset decoding begins.

## Stage overview

| Stage | Name | Status | Depends on |
|---|---|---|---|
| 0 | Scope and project foundation | Complete | — |
| 1 | Compatible ROM intake and data feasibility | In progress | Stage 0 |
| 2 | 60 Hz movement and collision prototype | Not started | Stage 0; can run alongside Stage 1 |
| 3 | Native 32:9 camera and display foundation | Not started | Stage 2 |
| 4 | First complete vertical slice | Not started | Stages 1–3 |
| 5 | SMB1R-style editor, packs, and replay modes | Not started | Stable runtime and level format |
| 6 | Full Sonic 3 & Knuckles campaign | Not started | Stage 4 and campaign data format; can overlap Stage 5 |
| 7 | Release candidate, compatibility, and packaging | Not started | Stages 5 and 6 |

## Stage definitions

### Stage 0 — Scope and project foundation · Complete

**Goal:** agree on what we are building and establish a reproducible project/repository foundation.

- [x] Define full S3&K campaign, user-provided ROM, 60 FPS, and native 32:9 goals.
- [x] Analyze SMB1R's ROM-to-local-assets workflow and A.I.R.'s release approach.
- [x] Set the project to Godot 4.7 and record the standard GDScript build target.
- [x] Keep ROMs and generated game data out of the public repository.

**Exit criteria:** project scope and reference analysis are documented, the engine target is declared, and the repository is linked to GitHub.

### Stage 1 — Compatible ROM intake and data feasibility spike · In progress

**Goal:** establish a repeatable pipeline that reads a user-provided Sonic 3 & Knuckles ROM and turns the game data needed by our remaster into local resources for the Godot runtime. This phase proves a small end-to-end slice; it does not decode the entire campaign.

The ROM is the source for the original game's visual and level data. The project will build its own runtime and gameplay systems around imported data; it will not run the ROM as an emulator. ROM bytes and generated content remain on the user's machine.

Detailed work packages and acceptance checks are in [Phase 1 plan](PHASE_1_PLAN.md). Summary:

- [x] **1A — Identify the first input profile:** document the supplied image's container, internal layout, region fields, size, and SHA-256 fingerprint.
- [x] **1B — Implement an intake inspector:** reusable validation for raw `.md` and single-image `.zip` inputs, with specific errors.
- [ ] **1C — Add the intake experience:** initial screen is implemented in `scenes/main.tscn` and `scripts/ui/import_screen.gd`; Godot-run acceptance with valid/invalid files is pending.
- [ ] **1D — Map the ROM data:** identify the source structures and decoding steps for a small visual and level-data proof set.
- [ ] **1E — Decode and load the proof set:** player sprite/animation, zone graphics/palette, and a compact level layout shown in Godot.
- [ ] **1F — Make local imports repeatable:** versioned cache manifest, source/output hashes, validation, and safe rebuild behavior.
- [ ] **1G — Confirm boundaries and handoff:** no ROM execution; imported data feeds our own runtime; document compatibility and known gaps.

**Exit criteria:** the user can select the known input; the importer reports compatibility and creates a local, versioned cache; the cache's player, zone, and level proof data load in Godot; invalid inputs produce understandable errors; repeat imports are deterministic; the ROM/cache stay out of the Git checkout; the format notes are sufficient to plan campaign-scale extraction.

**Input provided:** the project owner supplied a combined image privately for local analysis. Never commit or attach ROM/generated game data.

### Stage 2 — 60 Hz movement and collision prototype

**Goal:** establish responsive classic Sonic movement with simulation behavior that does not vary with rendering rate.

- [ ] Fix the simulation contract at 60 updates per second.
- [ ] Implement acceleration, friction, braking, top speed, jumping, slopes, rolling, and inertia.
- [ ] Implement ground, wall, and ceiling collision plus airborne transitions.
- [ ] Add rings, damage, ring loss/recollection, death, and checkpoint reset.
- [ ] Add debug readouts for speed, movement state, collision contacts, and simulation/render timing.

**Exit criteria:** a complete test room is playable at 60 rendered FPS; changing render pacing does not change movement, collision, or timers.

### Stage 3 — Native 32:9 camera and display foundation

**Goal:** make 32:9 an actual expanded gameplay view with the user's panoramic screenshot as a detail/composition reference, while preserving crisp pixel-art presentation, vertical play space, sprite proportions, and encounter fairness.

- [ ] Define pixel scaling and base framing from 16:9 through 32:9, calibrated against the 5120×1440 test mode and the supplied panoramic composition reference.
- [ ] Implement aspect-aware viewport expansion without stretching.
- [ ] Add camera look-ahead, bounds, and authored clamps for bosses/cutscenes.
- [ ] Place essential HUD/menu content in configurable safe regions.
- [ ] Audit spawn triggers, hazards, boss cues, and transitions for fixed-width assumptions.
- [ ] Choose a 32:9 reference resolution and PC hardware baseline for 60 FPS acceptance.

**Exit criteria:** traversal, hazards, a boss, transitions, and menus pass at 16:9, 21:9, and 32:9 without changing simulation timing.

### Stage 4 — First complete vertical slice

**Goal:** deliver one polished act from title/start through completion, proving the importer, movement, camera, and user experience together.

- [ ] Build one complete act with traversal, checkpoint, set piece/boss, and completion flow.
- [ ] Load proof data through the local import/cache path.
- [ ] Add pause/options, save/checkpoint behavior, gamepad controls, and return-to-menu.
- [ ] Add first-pass sound/music hooks and readable HUD.
- [ ] Validate at 16:9 and native 32:9.

**Exit criteria:** a new player can finish the act; restart/resume works; the documented baseline sustains 60 FPS.

### Stage 5 — SMB1R-style editor, packs, and replay modes

**Goal:** make creation, customization, and replay built-in workflows.

- [ ] In-game editor for supported terrain, objects, enemies, checkpoints, and events.
- [ ] Test-play, validation, undo/redo, save/load, and portable level-pack import/export.
- [ ] Data-driven custom character slots with supported animation/sound/parameter overrides.
- [ ] Resource packs for supported visuals/audio, with version checks and clear errors.
- [ ] Time Attack and the scoped challenge variants.
- [ ] Creator documentation, stable schemas, and original sample content.

**Exit criteria:** a creator can create, test, save, reopen, and exchange a valid level pack; supported characters and resource packs install/enable/disable cleanly.

### Stage 6 — Complete Sonic 3 & Knuckles campaign

**Goal:** implement the complete combined campaign for Sonic, Tails, and Knuckles.

- [ ] Create a versioned internal format for zone layouts, object placement, palette/resource references, events, and transitions.
- [ ] Implement every primary zone/act, character-route changes, bosses, and act transitions.
- [ ] Implement special stages, bonus stages, and intended ending paths.
- [ ] Complete Sonic, Tails, and Knuckles progression and save data.
- [ ] Verify all campaign paths at 60 Hz and native 32:9, with camera constraints where encounters require them.

**Exit criteria:** every intended character route and campaign path reaches its ending; no campaign-critical placeholder remains.

### Stage 7 — Release candidate, compatibility, and packaging

**Goal:** ship a reliable desktop build with the full campaign and creator workflows.

- [ ] Complete display/audio/input/accessibility options and settings persistence.
- [ ] Verify clean install, ROM import/recovery, saves, and content validation.
- [ ] Complete performance/bug passes at 1920×1080 and the chosen 32:9 reference resolution.
- [ ] Package Windows first; add Linux/macOS after platform validation.
- [ ] Separate preview builds from stable releases and publish structured release notes.
- [ ] Confirm no ROM/generated game data is present in Git history or release archives.
- [ ] Publish build/run instructions and third-party content acknowledgements.

**Exit criteria:** a clean install imports a supported user ROM, plays the complete campaign at target performance, and supports documented creator workflows without known blocker bugs.

## How we will keep this tracker current

1. Work on the next stage's smallest complete deliverable first.
2. When starting a stage, change its status to **In progress** and record the branch/commit in the update.
3. Keep implementation tasks as checkboxes under that stage; split work into separate GitHub issues once issue-write access is available.
4. Close a stage only when every exit criterion is met; record exceptions or scope changes here and in `PROJECT_SCOPE.md`.
5. Update the **Current stage** line and stage table in the same commit as each status change.
6. Use commit history and GitHub's compare view to review progress between stage checkpoints.
