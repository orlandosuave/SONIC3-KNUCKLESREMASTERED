# Project Roadmap and Stage Tracker

This file is the stage-level source of truth for the project. It lives in the GitHub repository, so each status change is recorded in the commit history. Detailed product requirements remain in [PROJECT_SCOPE.md](PROJECT_SCOPE.md); technical reference findings are in [REFERENCE_ANALYSIS.md](REFERENCE_ANALYSIS.md).

## Current stage

**Stage 4 — First complete vertical slice** is in progress as of 2026-11-14, beginning with the [4A content/fidelity audit](PHASE_4_CONTENT_AUDIT.md) on `codex/phase-3-display`, based on `554fca9`. Stage 3 is complete at prototype scope; see [Phase 3 closeout](PHASE_3_PLAN.md). Formal performance benchmarking and texture/art review carry into Stage 4; exact ROM parity remains a documented follow-up.

## Stage overview

| Stage | Name | Status | Depends on |
|---|---|---|---|
| 0 | Scope and project foundation | Complete | — |
| 1 | Compatible ROM intake and data feasibility | Complete | Stage 0 |
| 2 | 60 Hz movement and collision prototype | Complete | Stage 0; can run alongside Stage 1 |
| 3 | Native 32:9 camera and display foundation | Complete (prototype scope) | Stage 2 |
| 4 | First complete vertical slice | In progress — 4A audit | Stages 1–3 |
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

### Stage 1 — Compatible ROM intake and data feasibility spike · Complete

**Goal:** establish a repeatable pipeline that reads a user-provided Sonic 3 & Knuckles ROM and turns the game data needed by our remaster into local resources for the Godot runtime. This phase proves a small end-to-end slice; it does not decode the entire campaign.

The ROM is the source for the original game's visual and level data. The project will build its own runtime and gameplay systems around imported data; it will not run the ROM as an emulator. ROM bytes and generated content remain on the user's machine. Character animation and level reconstruction are later content tasks, not Stage 1 exit requirements.

Detailed work packages and acceptance checks are in [Phase 1 plan](PHASE_1_PLAN.md). Summary:

- [x] **1A — Identify the first input profile:** document the supplied image's container, internal layout, region fields, size, and SHA-256 fingerprint.
- [x] **1B — Implement an intake inspector:** reusable validation for raw `.md` and single-image `.zip` inputs, with specific errors.
- [x] **1C — Add the intake experience:** file picker/drop, profile result, local data folder, cache clearing, and AIZ atlas action are implemented and exercised with valid/invalid inputs.
- [x] **1D — Map the ROM data:** document exact profile-specific AIZ tile and palette ranges and decoding steps for the small graphics proof.
- [x] **1E — Decode and load the proof set:** AIZ intro tile atlases are generated locally and previewed in Godot.
- [x] **1F — Make local imports repeatable:** versioned cache manifest, source/output hashes, validation, and safe rebuild behavior are implemented.
- [x] **1G — Confirm boundaries and handoff:** no ROM execution; imported data feeds our own runtime; compatibility and later content work are documented.

**Exit criteria:** met. The user can select the known input; the importer reports compatibility and creates a local, versioned cache with a validated manifest; the AIZ tile-art proof loads in Godot; invalid inputs produce understandable errors; repeat imports are deterministic; the ROM/cache stay out of the Git checkout; the format notes identify the verified slice and document later work.

**Verification:** `tests/rom/test_rom_data_decoder.gd`, `tests/rom/test_rom_inspector.gd`, and `tests/rom/test_local_aiz_import.gd` passed against Godot 4.7; the local integration check used the supplied ZIP. No ROM or generated texture data is tracked.

**Input provided:** the project owner supplied a combined image privately for local analysis. Never commit or attach ROM/generated game data.

### Stage 2 — 60 Hz movement and collision prototype · Complete

**Status:** Complete (prototype scope, 2026-11-14). See [Phase 2 plan](PHASE_2_PLAN.md). Delivered: a self-contained room and original placeholder player art, launched from the intake screen.

**Goal:** establish responsive classic Sonic movement with simulation behavior that does not vary with rendering rate.

- [x] Fix the simulation contract at 60 updates per second.
- [x] Implement reference-based acceleration, friction, braking, top speed, jumping, slopes, rolling, and inertia, informed by the local disassembly. Matched ROM frame traces remain a fidelity follow-up.
- [x] Implement ground collision and airborne transitions; add wall/ceiling contacts and slope test geometry.
- [x] Add rings, damage, ring loss/recollection, death, and checkpoint reset.
- [x] Add debug readouts for speed, movement state, collision contacts, and simulation/render timing.

**Exit criteria:** a complete test room is playable at 60 rendered FPS; changing render pacing does not change movement, collision, or timers.

**Closeout evidence:** the project owner reports the room is working well and approves closure. `tests/gameplay/test_phase2.gd` passes at 60 and 120 fixed render FPS with 60 Hz physics, covering damage, hurt recovery, pickup timing, ring scatter/bounce/expiry, and death/checkpoint reset. These checks are not a full movement trace comparison or a performance benchmark.

**Accepted follow-ups:** exact tile sensors/fixed-point behavior, matched-input ROM traces, shared ring expiry, and full checkpoint/world-state fidelity remain tracked in [the ROM audit](PHASE_2_ROM_AUDIT.md). Prototype closure does not claim exact ROM parity.

### Stage 3 — Native 32:9 camera and display foundation · Complete

**Goal:** make 32:9 an actual expanded gameplay view with the user's panoramic screenshot as a detail/composition reference, while preserving crisp pixel-art presentation, vertical play space, sprite proportions, and encounter fairness.

- [x] Define base framing and aspect-aware scaling from 16:9 through 32:9, including the 5120×1440 test mode. Per owner scope clarification, texture sharpness and panoramic art calibration move to Stage 4 when gameplay textures are integrated.
- [x] Implement aspect-aware viewport expansion without stretching (actual viewport resize regression at 16:9, 21:9, and 32:9).
- [x] Add camera look-ahead, bounds, and authored clamps for bosses/cutscenes (original encounter fixture with side masks, warning cue, physical gates, and camera release; campaign fidelity remains later work).
- [x] Place essential HUD/menu content in configurable safe regions, with saved width/margin options, live HUD settings, and scrollable menus.
- [x] Audit the implemented prototype triggers, hazards, cues, and transitions for fixed-width assumptions; owner playtests pass. Campaign spawners and bosses remain later content.
- [x] Establish 5120×1440 as the 32:9 reference mode. Owner reports 60 FPS on the current setup; formal hardware baseline and benchmark measurements carry into Stage 4.

**Playtest update (2026-11-14):** the project owner confirms camera following works across multiple resolutions and reports hazards and transitions working too. This records prototype playtest acceptance; exact tested resolutions and measured timing were not supplied. The owner also confirms menus/settings work, reports 60 FPS on the current setup, and accepts the hazard check. Additional automated hazard comparisons are optional regression coverage. The formal hardware baseline and benchmarks at both reference resolutions remain unrecorded.

**Exit criteria:** traversal, hazards, a boss, transitions, and menus pass at 16:9, 21:9, and 32:9 without changing simulation timing.

**Closeout:** accepted at prototype scope on 2026-11-14. The boss is an original staging fixture, not campaign combat. Owner confirms aspect ratio, camera behavior, hazards, menus, and good performance. Automated camera/encounter checks cover all three aspect ratios. Formal performance measurement is deferred to Stage 4; this milestone does not claim a measured hardware baseline.

### Stage 4 — First complete vertical slice

**Goal:** deliver one polished act from title/start through completion, proving the importer, movement, camera, and user experience together.

**Status:** 4A research is in progress; gameplay implementation has not started. The [Phase 4 plan](PHASE_4_PLAN.md) defines eight work packages and five delivery gates. The [content audit](PHASE_4_CONTENT_AUDIT.md) records the combined-ROM resource matches, first-map object census, coverage ledger, reference-capture procedure and decision log. Player-facing AIZ Act 1 requires part of the second internal map; route reachability, full resource schemas and detour decisions remain open before G0 closes.

- [ ] Build one complete act with traversal, checkpoint, set piece/boss, and completion flow.
- [ ] Record the Windows hardware baseline and benchmark 60 FPS at 1920×1080 and 5120×1440 (carried from Stage 3 prototype closeout).
- [ ] Reconstruct the act's required level layout, collision, object placement, and original character frames/animations, then load them through the local import/cache path.
- [ ] Add pause/options, save/checkpoint behavior, gamepad controls, and return-to-menu.
- [ ] Add first-pass sound/music hooks and readable HUD.
- [ ] Review texture sharpness, pixel scaling, and panoramic art composition using integrated gameplay textures (deferred from Stage 3 by the project owner).
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
- [ ] Extract/reconstruct the character animation, level layout, object, event, and zone resource data needed for every original route and act.
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
