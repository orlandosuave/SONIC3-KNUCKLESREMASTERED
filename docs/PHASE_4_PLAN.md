# Phase 4 — First complete vertical slice

**Status: In progress — 4A content/fidelity audit started 2026-11-14.** Started on `codex/phase-3-display`, based on `554fca9`. This plan expands Stage 4 of [the roadmap](ROADMAP.md) and preserves [the project's original-game fidelity requirement](PROJECT_SCOPE.md). See the [content audit and coverage ledger](PHASE_4_CONTENT_AUDIT.md). Gameplay implementation has not started; G0 remains open.

## Outcome and proposed boundary

**Authority confirmed by the owner (2026-11-14):** replicate the supported ROM exactly. Wikis, guides, disassembly and other games/remasters are supplementary research aids. Settle disagreements through the supported ROM's behavior; secondary references cannot authorize altered mechanics, missing content or substituted behavior.

Deliver one polished act from launch and local ROM import through playable introduction, traversal, original encounters, results, and a clean completion destination. A new player must be able to play with keyboard or gamepad, pause, change options, die/retry, quit/resume, and finish without developer tools.

**Planning default: Angel Island Zone Act 1, Sonic alone, using the currently supported combined ROM profile.** AIZ is the strongest starting point because the existing importer already verifies its intro tile art and palette. This is a proposed implementation boundary, not a claim that the owner has selected the route or that the act has already been decoded. Verify the exact route, entry sequence, encounters, and exit against that profile in 4A.

- Include the entire selected act's main progression and optional in-act routes, secrets, objects, and mechanics available to the selected character. Do not shorten the map to fit the prototype.
- Include the real act events and boss behavior established by the inventory. The Phase 3 timed encounter fixture is only a regression tool.
- Preserve original terrain, collision, gameplay timing, animation coverage, and event order. Presentation upgrades must not alter gameplay geometry or behavior.
- Other characters and later acts remain Phase 6 work. Build character/act identifiers into the data now, without building their full runtime or the Phase 5 editor.
- Special/bonus stages are currently assigned to Phase 6. Inventory every entry reachable from this act in 4A. Full fidelity closure requires implementing reachable dependencies or recording an explicit owner-approved vertical-slice exception. Do not silently disable entrances or substitute rewards. Any exception remains a Phase 6 requirement and must appear in closeout.
- End after the original act completion sequence at a clear slice-complete destination; record the next-act handoff state for Phase 6. Do not pretend the next act is playable.

Original imported art is the first integration baseline. HD treatment, panoramic composition, and allowed audio sources need a concrete review in this phase; this plan does not assume a full HD asset library already exists.

## Starting point and gaps

| Existing foundation | What Phase 4 still needs |
|---|---|
| Known-profile intake, bounded tile decoder, deterministic local atlas cache | Full act resource inventory, layout/block/chunk reconstruction, collision, objects, sprite mappings, animation and audio pipeline |
| 60 Hz normal-Sonic prototype with source-informed constants | ROM terrain probes, fixed-point/order validation, loops/layers/platforms, required moves and power-ups, life/score/world-state rules |
| Aspect-aware camera, safe-region settings, encounter masks | Original camera behavior and act-specific event/camera integration across all aspects |
| Damage, rings, checkpoint and reset in a test room | Full act persistence, object respawn rules, events, game-over and completion flow |
| Owner-reported good prototype performance | Recorded hardware and rendered benchmarks with the complete act at both reference resolutions |

The exactness gaps in [the Phase 2 audit](PHASE_2_ROM_AUDIT.md) are inputs to this phase, not waived requirements. The [Phase 3 closeout](PHASE_3_PLAN.md) also carries texture/art review and formal performance measurement here.

## Delivery sequence

Each gate produces something independently inspectable. Finish the smallest end-to-end deliverable before expanding to the whole act.

| Gate | Packages | Reviewable result | Required before proceeding |
|---|---|---|---|
| G0 — Scope and evidence map | 4A | Route inventory, fidelity checklist, resource map and decision log | Act boundary and all external-stage dependencies are explicit |
| G1 — First real playable terrain | 4B, initial 4C/4D | Launch from import into a small reconstructed section with Sonic art and real collision | Terrain/render scale agrees; no guessed collision or palette mapping |
| G2 — Entire act traversable | remaining 4C/4D, 4E | Whole act playable with required mechanics and original event/boss flow | All required routes reachable; death and event reset work |
| G3 — Complete player experience | 4F, 4G | Title-to-results flow, save/resume, controls, presentation and sound | No required placeholder or silent unsupported content |
| G4 — Accepted vertical slice | 4H | Tested build and evidence report | Fidelity, usability, visual and measured performance criteria pass |

Critical dependency chain: **inventory → validated local resources → real terrain/collision → act objects/events → reliable state restoration → final acceptance**. Presentation can be prototyped after G1; final art calibration must precede the final benchmark. Avoid dates until G1 establishes extraction and collision effort.

## 4A — Lock the content and fidelity contract

- [ ] Inventory the selected profile's act entry, terrain sections, branches, secrets, objects/subtypes, enemies, hazards, power-ups, scripted events, boss, results, and transition.
- [ ] Identify required Sonic states/actions, including shield abilities or environmental behavior wherever reachable. Record optional detours and dependencies on other stages explicitly.
- [ ] Trace each resource family to its component image, address conversion, source range/pointer, compression, bounds, record schema and verification method in [ROM format notes](ROM_FORMAT_NOTES.md).
- [x] Create an act coverage table with columns: content ID, source evidence, required behavior, importer status, runtime status, test/playtest evidence, remaining gap. See the Phase 4 content audit; route verification remains open.
- [x] Define reference capture procedure: supported profile, start state, tick-indexed inputs, expected position/subpixel/velocity/contact/state/event fields, and comparison rules. Keep ROM and derived captures local; commit synthetic fixtures and non-content test summaries only. Procedure documented; capture tooling and actual traces remain outstanding.
- [x] Record decisions on route, stage detours, art direction, soundtrack source, resume semantics and performance criteria. Separate confirmed decisions from planning defaults. Decision log established; unresolved choices are not approvals.

**Acceptance:** every required content family has a source/evidence path and an assigned package; no unknown dependency is hidden under “polish.” Unknown formats remain labeled unknown until verified. No source-code port or borrowed reference-project assets are assumed.

## 4B — Expand the importer into an act data pipeline

- [ ] Decode layout → chunks → blocks → tiles with verified flips, palette lines, priority, foreground/background layers and dimensions. Cover intro/main resource changes and later changes identified in 4A.
- [ ] Decode terrain heightmaps, angles, solidity and collision-path references separately from visible art.
- [ ] Decode object placement, subtypes, rings, start/checkpoint data and required resource references. Recreate executable event behavior in our own runtime; data extraction alone is not event implementation.
- [ ] Decode Sonic and required object/enemy/boss art, mappings, animation tables, palette changes and any frame-loading dependencies.
- [ ] Define a minimal versioned act bundle: profile/source identity, coordinate units, terrain layers, collision data, object IDs, resource IDs, event references and bounds. Keep engine object creation out of the raw decoders.
- [ ] Extend the manifest with schema/importer versions, source/output hashes and required-file validation. Build into staging, validate, then promote; interruption must not replace a valid cache with a partial one.
- [ ] Handle missing/corrupt/stale cache, changed source and unsupported resources with actionable errors. Save data and settings survive cache clearing/rebuilds.
- [ ] Test decoders using synthetic bounds/index/flip/attribute cases; perform local integration checks against the supported ROM. No ROM excerpt or generated art enters Git or release bundles.

**Acceptance:** a fresh local import deterministically reconstructs the act data and a correctly layered static preview; invalid bundles cannot enter gameplay. Record decoded counts/hashes and visual review evidence locally with a non-content summary in the repository.

## 4C — Make movement work on original terrain

- [ ] Establish ROM pixels/subpixels as the authoritative simulation coordinate system. Any presentation scale is an explicit conversion; do not retune gravity or speeds to fit larger art.
- [ ] Implement the required heightmap/angle probes, floor/wall/ceiling contact order, collision layers, slope attachment/detachment, loops and one-way/platform interactions found in the act.
- [ ] Validate fixed-point arithmetic, signed rounding, update ordering, jump clearance and transitions with matched-input reference traces. Document exact comparison fields; justify any visual-only tolerance separately.
- [ ] Complete the selected route's Sonic actions, shield/power-up effects and environmental states. Coverage follows 4A, not the prototype's supported-state list.
- [ ] Close applicable ring/damage/death gaps: shared counters, collision/pickup rules, respawn bookkeeping, camera-relative death behavior, score/lives and game-over.
- [ ] Preserve the existing prototype regression fixtures while adding synthetic terrain cases for actual failure risks. Test at 60 and 120 render pacing with 60 Hz physics.

**Acceptance:** reference traversal inputs produce the expected simulation state and contact transitions; the character can complete every selected-act terrain path without clipping, losing attachment incorrectly, or relying on polygon stand-ins. Source-informed constants alone do not pass this gate.

## 4D — Build the full act runtime and object lifecycle

- [ ] Load act bundles through a dedicated runtime, reusing proven services from `scripts/rom`, `scripts/gameplay` and `scripts/ui`. Keep the movement room and encounter fixture accessible as development tools.
- [ ] Separate responsibilities for act loading, terrain rendering/collision, object spawning, simulation state, event sequencing and presentation. Avoid growing `movement_prototype.gd` into the campaign runtime.
- [ ] Give placed objects stable identities and implement required interactions, hitboxes, rewards, animations and respawn/persistence rules.
- [ ] Audit activation, despawn and enemy behavior against original logical activation rules. Expanding the render viewport must not accelerate events or spawn logic; rendering visibility and simulation activation are separate concerns.
- [ ] Implement checkpoints and whole-act reset from explicit state, including applicable event flags, object bookkeeping, camera bounds, terrain/resource swaps and player status.
- [ ] Check high-speed traversal, backtracking, revisiting checkpoints and repeated deaths throughout the whole map.

**Acceptance:** the entire selected act loads from the local bundle and is traversable with its placed content. Repeated retries do not duplicate objects, retain stale encounter locks or lose required progression.

## 4E — Original events, boss and act completion

- [ ] Recreate the verified introduction and scripted world/palette/background changes using explicit, resettable event states.
- [ ] Implement the real encounter's activation, telegraphs, attacks, hit/damage rules, invulnerability, defeat and release timing. Include every required act encounter; a timer-only demonstration is insufficient.
- [ ] Integrate original camera staging with expanded exploration framing. Verify masks, physical boundaries and camera release during entry, death, retry and live resize.
- [ ] Implement original completion trigger, control handoff, tally/bonuses, music transitions and next-act handoff data, followed by the slice-complete screen.
- [ ] Exercise interruption at every event boundary: pause, death, restart, menu exit and restore.

**Acceptance:** event ordering and encounter outcomes match the documented reference, are deterministic at 60 Hz, and remain fair at 16:9, 21:9 and 32:9. The slice can be finished without debug commands.

## 4F — Player flow, input and persistent state

- [ ] Provide launch/import → title/start/continue → act → results → completion/menu flow, with clear loading and recovery states.
- [ ] Add a true pause menu, restart/checkpoint retry, options and return-to-menu. Pause gameplay timers and events consistently; UI remains operable and audio follows the documented pause rule.
- [ ] Support keyboard and common gamepads throughout gameplay and menus: remapping, sensible defaults, conflict handling, dead zones, prompts and disconnect/reconnect recovery.
- [ ] Store settings separately from saves and imported content. Extend the existing safe-region settings rather than replacing them with incompatible preferences.
- [ ] Define a versioned save record with profile/content identity, act/character, progression, lives/score and checkpoint/event state required by the chosen restore contract. Use validated atomic writes with recovery; corrupt/incompatible saves must not crash or silently overwrite valid progress.
- [ ] Planning default: Continue restores the last valid checkpoint/start, not an arbitrary mid-frame snapshot. Specify rings, elapsed time, lives, objects and event restoration independently from ordinary death/retry behavior; document this modern resume behavior clearly.
- [ ] Verify cold relaunch, interrupted write, cache rebuild, missing content, game-over, completed-slice save and controller disconnect while paused.
- [ ] Add readable instructions and first-pass accessibility controls for text/HUD readability, flashing or shake where present, and separate sound/music levels.

**Acceptance:** a first-time player can import, start, pause, configure input, retry, quit, relaunch and resume without developer help or loss of valid saved progress.

## 4G — Gameplay art, panoramic composition and audio

- [ ] Integrate complete required animation coverage with correct timing, origins, facing, palette and draw priority. Visual frames must not define gameplay hitboxes accidentally.
- [ ] Review imported-art scale before committing to the final logical framing. The Phase 3 1280×720/2560×720 canvas and 1.5× scale at 1080p were prototype choices, not a final pixel-sharpness solution.
- [ ] Compare practical pixel-scaling/presentation options at 1920×1080, 2520×1080 and 5120×1440, plus the 1600×450 development window. Record chosen world-to-art scale, filtering and fractional-scaling behavior.
- [ ] Review texture clarity, seams, background coverage, parallax, animation, foreground priority and panoramic density in actual gameplay. Use the owner's panoramic reference when available; record an outstanding reference review if it is unavailable.
- [ ] Define any HD treatment as a separate presentation layer over unchanged collision/units. Required HD deliverables must be explicitly listed before committing to them; imported art is not automatically an accepted final art treatment.
- [ ] Resolve original soundtrack/SFX reconstruction feasibility early: inventory sound data, playback/synthesis approach and permissible sources. Keep original ROM-derived audio local. Do not assume an audio hook equals working audio or that third-party recordings can be bundled.
- [ ] Implement gameplay cues, music changes, looping, interruption/resume, pause behavior, volume buses and menu feedback. Temporary audio may support development but cannot silently pass the final gate.

**Acceptance:** the owner reviews integrated gameplay textures and panoramic composition; all required audio cues play with correct event timing and acceptable playback quality. Record any explicitly accepted limitation instead of treating placeholders as finished content.

## 4H — Verification, performance and closeout

- [ ] Record Windows version, CPU, GPU, RAM, driver, display mode/refresh, renderer, Godot version, build revision and power/VSync settings.
- [ ] Benchmark an exported rendered build at **1920×1080 and 5120×1440**, using the same repeatable full-act route including busy object sections, resource changes, boss, damage/ring scatter and completion. Headless fixed-FPS tests are functional checks only.
- [ ] Proposed measurement protocol: warm up first, capture at least three full-act runs per reference resolution, record frame-time percentiles, missed 16.67 ms budgets, CPU/GPU timing where available, memory and visible stalls. Record cold import/loading separately; do not average loading into gameplay results.
- [ ] Before measurements, finalize the stable-60-FPS pass threshold and treatment of isolated OS/display interruptions. Suggested starting target: p99 gameplay frame time at or below 16.67 ms with no sustained gameplay slowdown; report outliers and repeatability rather than only average FPS.
- [ ] Run functional aspect checks at 16:9, 21:9 and 32:9, including resize during traversal, pause, boss and transition. Check simulation tick outcomes independently of render aspect/rate.
- [ ] Run meaningful importer, terrain, movement, object/event reset, save/input and existing Phase 2/3 regressions. Keep synthetic tests portable and distinguish local-ROM integration from repository-only tests.
- [ ] Conduct a fresh-user completion playtest and a clean-local-data import/recovery test. Preserve real player data when creating test profiles.
- [ ] Inspect tracked files and export contents for ROMs, generated game data and private reference captures.
- [ ] Write a closeout evidence report with coverage, measured results, owner review, remaining defects and explicit exceptions. Update roadmap/README statuses only after acceptance.

**Acceptance:** all final exit criteria below are supported by evidence, with no progression, save-loss, required-content, fidelity or performance blocker hidden in follow-up work.

## Risks and decision checkpoints

| Risk | Early action | Completion rule |
|---|---|---|
| Atlas proof is mistaken for a nearly complete importer | Prove a correctly layered, collidable section at G1 | No full-act build on guessed formats |
| Prototype physics cannot traverse original geometry | Establish probe/loop/reference tests before populating the full act | Correct simulation rather than altering original terrain |
| Optional paths bring major extra systems | Inventory stage entries and power-ups at G0 | Implement or obtain an explicit, documented slice exception |
| Original music needs a substantial playback subsystem | Feasibility spike during 4A/4B | Resolve before G3; placeholder hooks cannot close audio |
| Art scale changes invalidate framing/performance | Review imported terrain/player together at G1 | Freeze final presentation settings before G4 measurements |
| Wide views change object timing or expose events | Separate render bounds from logical activation and test early | Aspect ratio must not change reference gameplay outcomes |
| Resume restores only player position | Model event/object state before save integration | Checkpoint restores a coherent playable world |

## Final exit checklist

- [ ] The complete selected act and character route run from title/start to original completion and a clear slice endpoint.
- [ ] All required terrain, character frames, objects and event resources load through the validated local import path.
- [ ] Applicable Phase 2 fidelity gaps are closed with reference evidence; every remaining exception is explicitly recorded and accepted.
- [ ] Real encounters, optional in-act routes, checkpoints, death/retry, lives/game-over and completion behave as specified.
- [ ] Pause, options, remapping, gamepad recovery, return-to-menu and durable resume pass.
- [ ] Integrated art, readable HUD, music/SFX and panoramic composition pass review at the supported aspects.
- [ ] The documented Windows baseline passes the agreed 60 FPS measurements at both reference resolutions.
- [ ] A new player completes the slice without developer tools, and fresh import/recovery works.
- [ ] No ROM, extracted/generated proprietary assets or private reference captures are included in Git or distributable builds.

## First implementation task

Start with **4A plus the smallest G1 proof**: inventory the AIZ Act 1 Sonic route, verify the layout/block/chunk/collision chain for one representative section, and load it with a correctly mapped Sonic frame through the real import-to-play flow. Include flat ground, a slope and a layer/priority case so the proof tests the data model rather than just displaying a screenshot. Keep any full-route or audio unknowns visible in the coverage table. This task does not begin the full campaign, editor, or asset redesign.

## Current research checkpoint

Sonic-alone reference capture is operational and verified through original menu inputs. Fourteen selected dry-view frames match outside conservative sprite exclusions. Remaining reference-render work requires persistent background nametable/DMA history and visible-water effects; the scripted route has not completed the act. See the latest content-audit checkpoint and reference-capture instructions. G0 remains open; these diagnostics do not certify runtime terrain, collision, objects or full-route fidelity.
