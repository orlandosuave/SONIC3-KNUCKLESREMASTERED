# Phase 4A — Angel Island content and fidelity audit

**2026-11-22 audio fidelity backlog:** The operator queued original-ROM music and SFX identification, private cache extraction, playback, driver priority/channel arbitration, gameplay/event cues, volume/pause logic and listening/reference verification. Local `skdisasm/Sound` includes Music/SFX/DAC disassembly research, but that is not proof that the supported-ROM audio playback works. None of the audio gate is accepted on the strength of the queued cards. The owner's 5120x1440 screenshot-relative scale requirement for Sonic, trees, checkpoints and objects is likewise an open visual acceptance gate. See [Audio and screenshot-scale queue plan](PHASE_4_AUDIO_AND_SCALE_QUEUE.md).

**Status: In progress, 2026-11-14.** Phase 4A began on `codex/phase-3-display`, based on `554fca9`. This is a research/implementation contract, not certification of a playable act. The working target is Angel Island Act 1, Sonic alone, fresh campaign state, in the supported combined S3&K profile. No special-stage exclusion or art/audio substitution has been approved.

## Evidence and confidence

**Owner clarification — 2026-11-14:** the supported ROM is the authoritative target for exact replication. All other sources are supplementary. If a wiki, guide, disassembly interpretation or later remaster disagrees with observed behavior of the supported ROM, resolve the discrepancy against that ROM; do not change gameplay to match the secondary source. Disassembly explains implementation but must be checked for revision/build differences. Modern presentation and convenience features must preserve original gameplay semantics; document their separate behavior explicitly. This clarification does not approve omissions, substitutions or fidelity exceptions.

- Supported image SHA-256: `fba0677fde9f76df93f3e98d6310d8af68b9847bde16e253d73cd4dd8134ed23`, 4 MiB. Rechecked locally on 2026-11-14; source opened read-only from the supplied ZIP.
- Local disassembly revision: `73de97c6b55055bcb8089c1d55d006b02136f163`. Paths and symbols below are relative to `local_reference/skdisasm`; line numbers identify this revision only.
- Combined-game configuration is `SonLVL INI Files/SonLVL.ini`, not `SonLVL - S3.ini`. The latter was useful for the tile proof but has different object/ring lists and global collision references.
- **Source-traced** means inspected reference source. **Byte-matched** means a complete reference resource matched the supplied image; duplicate matches do not establish which pointer is active. Neither means the runtime is implemented or reference traces have passed.
- Full resource matching ran locally using `local_reference/phase4_inventory.py`. The helper and binary inputs remain ignored. Repository documentation records metadata and findings, not extracted placements, graphics, audio or source code.
- No emulator capture, original-game playthrough, route-reachability verification, or new Godot gameplay test was performed for this audit.

## The act boundary is not the file boundary

The player-facing Act 1 spans **two internal maps**. `AIZ1BGE_Finish` switches `Current_zone_and_act` to 1, reloads the second map/solids and offsets player/camera coordinates during the fire transition. `AIZ2_SonicResize1` distinguishes this from player-facing Act 2 through `Apparent_zone_and_act`; `AIZ2_SonicResize2` creates `Obj_AIZMiniboss`. Its defeat path calls `Obj_EndSignControl`.

Therefore, importing only `Layout/1.bin` cannot deliver a complete Act 1. Include the necessary burned-forest portion of `Layout/2.bin`, its collision, art, objects and the actual miniboss/results. Do not add the later battleship/end-boss sequence merely because those resources share map 2. Determine the exact player-facing completion/handoff boundary through event tracing and a reference playthrough before declaring the content list complete.

| Sequence | Evidence in `sonic3k.asm` | Contract and remaining verification |
|---|---|---|
| Plane arrival and character introduction | `Obj_AIZPlaneIntro` (135529); `CutsceneKnux_AIZ1_Index` (128674) | Include required cinematic characters even though only Sonic is playable; verify fresh-game and checkpoint-skip branches |
| Intro terrain to main forest | `AIZ1_Resize` (38899), main art/block replacement (38954) | Preserve palette/art swaps and automatic saved start state; source saves a start/checkpoint during this transition, independent of placed starposts |
| Forest branches, water, tree/vines, hidden paths | `AIZ1_ScreenEvent` (104343), `Obj_AIZHollowTree` (43641), `DynamicWaterHeight_AIZ1` (8676) | Trace path/layer changes and dynamic chunk changes; map upper/lower/secret routes using local reconstruction and playthrough |
| Initial miniboss cutscene and ignition | placed object `$90`; `Obj_AIZMinibossCutscene` (136799) | Distinguish the scripted encounter from the later combat boss; verify damageability, control and cue timing |
| Fire and internal-map transition | `AIZ1_AIZ2_Transition` (104673), `AIZ1BGE_Finish` | Preserve resource swaps, temporary floor, coordinate remapping and state resets without a premature results screen |
| Burned forest through Act 1 combat | `AIZ2_SonicResize1/2` (39087 onward), `Obj_AIZMiniboss` (137287) | Include map-2 content reachable before Act 1 completion; exact placement subset still pending |
| Defeat, sign/results and next-act handoff | `loc_68C02` (137454), `Obj_EndSignControl` | Trace score, timer, sign behavior, apparent-act change and resume boundary; then show slice-complete destination |

## Placed-content inventory — first internal map

The combined-game `Object Pos/1.bin` matches at `0x1E44DA`: 924 bytes, comprising **153 six-byte placement records plus a six-byte terminator**. IDs below resolve through `Levels/Misc/Object pointers - SK Set 1.asm` and the combined SonLVL object definitions. These are all placements in that file, not a claim that each is Sonic-accessible. Preserve subtype/flip/path metadata during import; resolve reachability instead of deleting apparently unused placements.

| ID | Family | Records | Required behavior / package |
|---|---|---:|---|
| 01 | Monitors | 11 | Break/reward/respawn; subtypes 01,03,04,05,07,08; 4C/4D |
| 02 | Path swap | 13 | Collision/draw layer switching, direction/subtype rules; 4C/4D |
| 03 | Hollow tree | 1 | Scripted travel, camera/layer and chunk effects; 4C/4E |
| 04 | Collapsing platform | 4 | Contact/delay/fall/reload; 4D |
| 05 | Rocks | 9 | Breakability, solid behavior and fragments by subtype; 4D |
| 06 | Ride vine | 1 | Attach/travel/release and animation; 4C/4D |
| 07 | Springs | 12 | Orientation, force, input/state transitions; 4C/4D |
| 08 | Spikes | 7 | Orientation, damage/solid and subtype behavior; 4C/4D |
| 09 / 0A | Foreground tree / zipline peg | 1 / 1 | Draw priority and vine presentation; 4D/4G |
| 0C | Giant ride vine | 4 | Attachment, swing/travel/release; 4C/4D |
| 0E | Twisted ramp | 1 | Forced movement/rotation state and collision; 4C |
| 28 | Invisible block | 6 | Real collision despite absent visible art; 4C/4D |
| 2A / 2D | Cork floor / falling log | 1 / 1 | Break/fall/ride and reset rules; 4C/4D |
| 34 | Starpost | 1 | Subtype 02; save state and bonus portal; 4D/4F |
| 35 | Foreground plant | 64 | Subtypes, layering, underwater/foreground composition; 4G |
| 51 | Floating platforms | 3 | Movement/support/carry behavior; 4C/4D |
| 85 | Special-stage entry ring | 1 | Subtype 01; entry/return/persistence/reward; 4D/4F plus stage dependency |
| 8C / 8D / 8E | Bloominator / Rhinobot / Monkey Dude | 2 / 3 / 5 | Activation, attacks, damage, score, animation and respawn; 4D |
| 90 | Miniboss cutscene | 1 | Scripted ignition encounter, not final combat; 4E |

Monitor subtype definitions identify one speed-shoes, five ring, one flame-barrier, two invincibility, one aqua-barrier and one 1-Up monitor in the first map. Their presence establishes required behavior candidates; a route pass must confirm access. The whole second map contains 751 placement records, including thunder-barrier monitors, additional starposts/entry rings and other object families. **Do not treat those 751 records as the Act 1 workload**: isolate the pre-completion subset through event/route analysis first.

Static rings use a separate list. The matched first-map ring file is 422 bytes; ring-list sentinel/schema and count remain to be verified. Do not divide its file length by an assumed record size to declare a ring count.

## Required player states and external dependencies

### Direct-ROM census follow-up — 2026-11-14

The repository now includes `tools/audit_aiz_content.py`, a read-only, hash-pinned auditor accepting a local `.md` or ZIP. It reads the verified placement spans directly from the supported ROM and emits aggregate metadata only. Run `python tools/audit_aiz_content.py <local-ROM-or-ZIP-path>`; no reference checkout is required. It rejects a wrong profile, truncated records, missing terminators and trailing records after a terminator. `python -m unittest discover -s tests -p test_aiz_audit.py` passes three synthetic tests for these boundaries, preservation of record order/flags, and subtype counting. The actual supported ZIP also passed.

**Original ordering matters:** map 1 has no descending X steps; map 2 has four. Preserve file order and stable placement identity; never sort the imported records under an assumption that the original list is monotonic. This finding comes from the ROM bytes, not a guide or inferred ideal format. The source loader advances six bytes per record (`loc_1B7A2`) and consumes placement flags (`sub_1BA0C`); its behavior around these out-of-order entries needs a reference trace.

For research only, filtering map-2 placements to X below `0x1500` yields **196 candidate records**, including six ordinary monitors, six hidden monitors (`80`), one starpost, one giant ring, three Caterkiller Jr. placements, two disappearing floors and a collapsing-log bridge. Ordinary monitors in this filter include two ring, two flame, one thunder and one invincibility subtype. The threshold comes from the next resize milestone after the boss approach, not from a proven gameplay boundary. This filter includes other-character/inaccessible content and may omit objects activated beyond it; it must not become an importer crop or reachability claim.

### Completion and state contract — source-traced follow-up

These findings extend source inspection; they are not yet verified by an original-game frame trace:

1. `AIZ2_SonicResize2` narrows the camera vertically on approach and establishes the Sonic boss spawn/left clamp. `AIZ2_SonicResize3` later changes vertical bounds beyond X `0x1500`. Wide presentation must retain the original logical-camera trigger conditions.
2. The miniboss defeat path reaches `Obj_EndSignControl`, which schedules the sign, clears the boss flag and calls cleanup. `Obj_EndSign` supports a falling/bouncing sign and hidden-monitor interactions. Do not replace this with an immediate completion overlay.
3. `Obj_EndSignLanded` eventually locks input. `Obj_EndSignResults` waits for grounded Sonic, sets his ending pose and creates `Obj_LevelResults`.
4. `Obj_LevelResultsWait2` / `loc_2DD06` changes the apparent act to 1 only after the result objects finish, clears checkpoint and special/bonus-entry flags, then creates the next title card. This is the source-level player-facing Act 1 completion/handoff boundary. The internal map already changed during ignition.
5. `Obj_EndSignControlAwaitStart` restores player control after the end-sequence flag clears; `Obj_EndSignControlDoStart` waits for title-card completion before `Change_Act2Sizes`. The slice-complete UI must be an explicit outer-shell endpoint at the verified handoff, preserving earned results and outgoing state. Its exact insertion tick remains to be validated; do not cut off sign interactions or score tally.
6. `Restore_LevelMusic` selects using the apparent zone/act and handles invincibility. Returning from a detour or resuming in burned terrain must not choose Act 2 music merely because the internal map is 2.

Checkpoint data must distinguish internal and apparent act. `Save_Level_Data` explicitly retains both, checkpoint identity, player art/solid-path fields, rings/extra-life flags, timer, resize routine, camera state and water state. Position is established by its caller. Object respawn tables and event reconstruction require their separate lifecycle analysis; the save helper alone does not prove they are fully restored. Preserve the distinction between ordinary checkpoint death, special-stage return, bonus return and modern cold-launch Continue.

Bonus selection is source-traced more precisely: for combined-game starpost entry at 20 or more rings, the index is `floor((saved_rings - 20) / 15) mod 3`. The portal sets internal and apparent destination together, clears the active starpost, saves ring/extra-life and selected status state, and retains respawn bookkeeping. Required boundary cases include 19/20, 34/35, 49/50 and 64/65 rings. Actual destination identity and return behavior still require ROM validation.

- Movement: normal ground/air, braking, look up/duck, rolling, Spin Dash, jumps/roll-jumps, Insta-Shield, slopes/loops/path swaps and scripted ride states. Match frame order and subpixel arithmetic, not just constants.
- Combat/recovery: attack interactions, damage, ring scatter/recollection, hurt immunity, death, lives, game-over, score/extra-life rules, checkpoint and object reset.
- Environment: water exists in the source/configuration. Verify reachable underwater sections, buoyancy/gravity/speed changes, air/drowning, bubble behavior and barrier interactions rather than assuming a dry act.
- Power-ups: implement first-map monitor effects above; verify thunder-barrier and other effects in the map-2 subset. Fresh-state Super/Hyper eligibility requires a dependency analysis, not a blanket inclusion or omission based on the whole campaign roster.
- Special stages: a real `$85` entry is present. Verify Sonic reachability, stage-selection state, emerald/perfect/reward bookkeeping, return location, entry consumption and checkpoint interactions. Keep special-stage implementation as an explicit dependency until a slice exception is approved.
- Bonus stages: `Obj_StarPost` tests for at least 20 rings; `sub_2D3C8` and its portal-entry code select among three outcomes for the combined game using ring-count bands. Do not assume only the standalone Sonic 3 bonus game is reachable. Verify all possible destinations and return-state behavior for this slice.
- Cinematic Tails/Knuckles assets and behavior may be required without adding playable Tails/Knuckles routes.

## Coverage and implementation ledger

“None” means no implemented act system/evidence, not an absent original-game feature. Source inspection is not a gameplay pass.

| Content ID | Source evidence | Required behavior | Importer | Runtime | Test/playtest evidence | Remaining gap / owner |
|---|---|---|---|---|---|---|
| AIZ1.terrain | matched layouts/blocks/chunks; `Load_Level` | Both internal-map portions, flips/layers | Tile atlas proof; static layout and ordinary Kosinski chunk/block decoding in research auditor | Prototype polygons | Ten audit tests; direct-ROM bounds checks; seven independent decoder hash matches | Attribute interpretation, intro resource-state references, reconstruction, live mutations, local view; 4B |
| AIZ1.solids | matched indices/heightmaps/angles; `LoadSolids` | Exact probes and paths | AIZ split low-byte path indices decoded in research auditor | Shape approximation; guarded synthetic floor/right-wall collision helpers, not player integration | Direct-ROM index bounds; source-informed terrain, floor, right-wall, seam and flip regressions (accepted receipts below) | Left-wall/ceiling contact, real player wiring, fixed-point/contact order, supported-ROM matched-input trace parity; 4B/4C |
| AIZ1.sonic | matched art; Sonic mappings/DPLC/animation sources | Full required state/animation chain | None | Placeholder art, partial mechanics | Phase 2 audit | Frame chain, actions, reference traces; 4B/4C/4G |
| AIZ1.objects | matched combined lists and object pointer set | All reachable placements/subtypes | None | Test-room objects only | Source census above | Map-2 subset, lifecycle and behaviors; 4B/4D |
| AIZ1.intro | plane/Knuckles routines | Correct start/control/music sequence | None | None | Source located | State branches, assets, capture; 4B/4E |
| AIZ1.fire | cutscene/background routines | Ignition, swaps, internal-map transition | Ranges matched, not decoded | None | Source-traced transition | Full sequence, interruption/reset; 4B/4E |
| AIZ1.boss | `Obj_AIZMiniboss` | Real combat and defeat/sign handoff | None | Timed fixture only | No campaign test | Attacks/hit timing/results; 4E |
| AIZ1.checkpoint | `Save_Level_Data`, starpost, automatic intro save | Coherent death and resume | None | Position/time prototype | Prototype only | Event/object/internal+apparent-act state; 4D/4F |
| AIZ1.detours | `$85`, starpost portal selection | Special/bonus entry, play and return | None | None | Placement/source evidence | Reachability, destinations, stage systems or explicit exception |
| AIZ1.presentation | water/deformation/palette/animated tiles | Accurate art and expanded framing | Intro atlas only | Phase 3 camera | Prototype aspect checks | Original camera/event coupling, art review; 4E/4G |
| AIZ1.audio | music IDs, event SFX calls | Playback, cues, loops, interruption | None | None | No audio validation | Data/driver inventory and local playback approach; 4B/4G |
| AIZ1.finish | end-sign controller and act variables | Results, save, next-act boundary | None | Prototype goal only | No campaign test | Complete call-chain trace and reference capture; 4E/4F |

## Reference-capture contract

1. Use the hash-pinned combined image, fresh Sonic-alone save, no emeralds, no cheats/debug mode, and the original 60 Hz region mode. Record emulator/version, region/refresh configuration, reference-source revision and capture tooling. Choose a validated local tracing tool before claiming evidence; none is selected yet.
2. Capture from a reproducible reset or locally stored reference state; record its identity/hash and every relevant initial field. For checkpoint/detour traces include internal act, apparent act, saved state, inventory, event flags and respawn bookkeeping.
3. Record controller bitmasks per simulation tick, including simultaneous button presses and press/hold/release distinctions. Fix a sampling boundary after the full gameplay update and before the next input; document any unavoidable reference/remaster alignment offset.
4. Compare raw integer position and subpixels, X/Y/ground velocity, angle, collision path, grounded/air/roll/hurt state, animation/frame/timer, input lock, rings/lives/score, game timer, power-up counters, checkpoint, logical camera, event states, boss HP/state and active-object identities. Missing fields are coverage gaps, not implicit passes.
5. Require exact equality for implemented deterministic simulation fields after alignment. Report the first divergent tick, inputs and preceding state. Visual/render interpolation is compared separately; do not widen physics tolerances to conceal collision differences.
6. Run identical tick inputs in the remaster at 60/120 render pacing and all supported aspects. Compare gameplay outcomes to the reference's logical camera/activation behavior; expanded rendering must not move event triggers forward.
7. Minimum cases: start/intro; flat movement/reversal/jumps; slope/loop/path swap; vine/tree; each reachable barrier and water; enemy hit/ring scatter; checkpoint/death; ignition and map switch; miniboss hit/defeat; results; each detour and return. Add high-speed/backtracking and interruptions at state boundaries.
8. Store ROM, state files, videos and raw derived traces outside tracked content. Commit only tool code/synthetic tests and non-content summaries stating profile/build, case, duration, field coverage, pass/fail and first-divergence explanation.

## Decision log

| Topic | Current decision/status | Revisit at |
|---|---|---|
| Work authorization | Owner requested starting Phase 4 item 1 (content/fidelity) | Active now |
| Act/character | Use AIZ Act 1 / Sonic alone as the plan's working default; no newly claimed explicit route selection | G0 review |
| Start state | Fresh campaign for first reference suite; alternate save/emerald states require explicit coverage | Route/dependency pass |
| Internal map 2 | Required dependency of player-facing Act 1, demonstrated by source | G1 data model |
| Detours | No approved exclusion; preserve as unresolved implementation dependencies | Before G0 closure |
| Art | Imported original art for integration; final HD treatment still open | G1 visual review |
| Audio | No approved substitute recordings; local original-data playback approach unproven | Early 4B/4G spike |
| Resume | Last-checkpoint/start is proposed modern behavior; ordinary death/bonus return follow their distinct original contracts | 4F specification |
| Performance | Both reference resolutions required; p99 target proposed, not accepted/measured | Before 4H |

## Remaining 4A work and gate status

### Web cross-check — 2026-11-14

The owner authorized wiki research. [Sonic Wiki Zone's Fire Breath article](https://sonic.fandom.com/wiki/Fire_Breath) supplies useful gameplay checks: the initial encounter cannot be defeated; its ignition missiles are harmless; the later Sonic/Tails fight alternates flamethrower attacks across the arena and takes six hits. It also identifies buried monitors revealed by the goal plate, and distinguishes original free movement during the first encounter from the control lock added in Sonic Origins. Treat these as reference-playtest cases, not certified tick-level implementation rules. The local `Obj_AIZMiniboss` initialization independently sets its collision property to six.

Add focused checks for initial-encounter damage versus invulnerability, flame-barrier protection versus body contact, continued player control during ignition, boss hit count/attack cycle, and goal-plate rewards. Verify each against the supported original combined ROM; do not import Origins-specific behavior.

The [Angel Island wiki page](https://sonic.fandom.com/wiki/Angel_Island_Zone) was discoverable but its full text was blocked. [Zone: 0's Angel Island guide](https://www.soniczone0.com/games/sonic3/angelisland/) was discoverable but returned a fetch error. They remain route-research leads, not evidence of a completed map review. No wiki/map imagery or other assets were downloaded into the project.

The content ledger, capture procedure and decision log are established. **G0 remains open.** Before calling 4A complete:

- [ ] Reconstruct enough map data to trace Sonic-accessible branches/secrets and isolate the map-2 portion before the actual Act 1 completion boundary.
- [ ] Resolve original resource pointers, duplicate-match ownership and bounded schemas; finish sprite/animation, event and audio families. See the range ledger in [ROM format notes](ROM_FORMAT_NOTES.md).
- [ ] Trace intro, boss, sign/results, special-stage and all bonus-stage return call chains; specify state transitions and exact coverage cases.
- [ ] Validate source findings against the supported image's gameplay, including its logical camera, start/skip cases, required player moves and water/power-up reachability.
- [ ] Resolve scope-changing decisions with the owner using the concrete dependency findings. Keep default choices and unresolved exceptions distinguishable from accepted scope.

The next useful implementation step is the bounded layout/block/chunk/collision decoder proof from G1, undertaken to close the route inventory gaps above; no act completion or fidelity claim follows from the current census.

**Layout progress (2026-11-14):** the bounded static layout parser is implemented in `tools/audit_aiz_content.py` and passes against both original resource spans. Foreground grids are 97×13 and 153×21 chunks; background grids are 66×11 and 8×10. The schema, validation and row hashes are documented in [ROM format notes](ROM_FORMAT_NOTES.md). The remaining chain is ordinary Kosinski chunk/block decoding → tile attributes and collision references → runtime map mutations → visual/route verification. This is research tooling toward G1, not a playable terrain milestone; 4A/G0 remain open.

**Terrain progress (2026-11-14):** ordinary Kosinski decoding now passes on all seven selected block/chunk resources, with output sizes/hashes independently matching KENSSharp. All static layout chunk references resolve; whole-table block references fit the main and burned-map resource sets. The smaller intro block set leaves 147 IDs in the shared chunk table outside its loaded range, requiring visibility/resource-state analysis before a faithful intro render. The next step is tile/collision attribute interpretation and resource-state composition, followed by runtime mutations and local visual/route verification. G0/G1 remain open; no gameplay parity or playability is claimed.

**Attribute progress (2026-11-14):** tile palette/priority/flips, chunk block/flip/solidity fields and the two AIZ collision-index paths are now decoded by research tooling. The exact path addressing uses low bytes at stride two and a `0x600` secondary offset, established from source pointers/probes and exercised on the supported ROM. Twelve synthetic tests pass. Tile references extend into shared VRAM destinations, so the next task is tracing PLC/animated tile loads and composing the correct resource state before rendering. The intro swap overwrites existing destinations; no missing references have been silently filled or normalized.

**Graphics-state progress (2026-11-14):** decoded six terrain/fire tile resources with independent hash agreement. The 121 missing main/burned block tile IDs are exactly the fire overlay at `0x500–0x578`; the explicit fire-upload state resolves them all. Loaded intro block tile references also resolve completely. Added destination-overwrite modeling and traced character/checkpoint resource selection plus boss/camera-conditioned animated tile loads. Fourteen synthetic tests pass. The next deliverable is local terrain composition and visual comparison, retaining explicit missing intro block handling and runtime-mutation limitations; full animation scheduling and gameplay parity remain open.

**Visual progress (2026-11-14):** `tools/render_aiz_preview.py` now renders local static foreground previews directly from the supported ROM, with palette lines, transparency, tile flips and block flips. Main and burned maps have zero unresolved blocks; the full intro foreground marks 110 distinct unresolved block IDs diagnostically. Inspected the overview and original-scale detail: terrain structure is coherent, but no original-frame comparison has been performed. Sixteen tests pass. Generated assets stay under local application data. Next: establish state/camera-correct intro coverage and background/priority composition, then verify dynamic terrain and collision against the original before calling routes playable or 4A complete.

**View/priority progress (2026-11-14):** nine bounded intro-transition foreground sample rectangles resolve within the intro block set, including diagnostic wider views. This is sampling, not full camera-trace acceptance. Background and high/low-priority exports now exist; main/burned background references resolve, while the full intro background has 37 unresolved distinct block IDs. Added a tested compositor for explicitly aligned priority planes; original scrolling/deformation alignment and sprite composition remain outstanding. Eighteen tests pass. 4A remains open pending actual route/reference-frame verification.

**Original-ROM comparison (2026-11-14):** a portable local reference core now runs the supplied image, separately from Godot. Added signed intro/main scroll modeling and direct captured-RAM comparison: all 32 eligible snapshots match modeled scroll words/background Y exactly. Actual frame comparisons revealed and corrected capture-camera timing and core-specific RGB output differences; residual mismatches include absent HUD/objects, canopy and animation. Twenty-one synthetic tests pass. See [reference capture procedure and evidence](REFERENCE_CAPTURE.md) for core provenance, reproducible commands, measured mismatches, default Sonic-and-Tails roster caveat and remaining work. Earlier statements that no captures were performed describe the initial audit; this follow-up supersedes them. The planned Sonic-alone suite and complete route validation remain outstanding.

### Captured AIZ1 animation uploads

The comparison renderer now reads the three animation scripts directly from the supported ROM at `0x28752`. Script headers contain duration/source, VRAM byte destination, frame count, and tile count. Negative durations select frame/duration pairs; other scripts use one byte per frame. Captured counters at RAM `F7F0`, `F7F2`, and `F7F4` contain the next frame index, so the previously uploaded frame is index minus one. Uninitialized counters are rejected rather than guessed.

The frame-2640 comparison improves from 18,313 to 17,968 mismatched pixels out of 71,680. Frame 2220 remains at 7,952. All 32 scroll snapshots still match and all 22 synthetic tests pass. These totals include omitted HUD and objects and are not fidelity scores. The canopy discrepancy, background draw alignment, DMA timing, terrain-only comparison regions, and Sonic-alone capture remain open. Phase 4A/G0 remains open; this research change does not alter gameplay.

### Upper-background wrapping correction

The AIZ1 normal background draw table splits at Y `0x220`. The upper band is drawn at X=0 into a 32-block (512-pixel) nametable and repeats under horizontal scanline deformation. Sampling the full layout width incorrectly read blank chunks beyond that region. The comparison now wraps upper-band source X at 512 pixels; lower rows retain streamed coordinates. The captured frame-2640 layout bytes match the ROM layout exactly, ruling out layout mutation for this observation.

Frame 2640 now has 6,179 mismatches (previously 17,968). An explicitly selected canopy rectangle `(120,0,90,70)` has **0 / 6,300** mismatches. Lower terrain rectangle `(80,160,240,64)` has **1,696 / 15,360**, so remaining errors cannot be attributed solely to omitted objects/HUD. Both rectangles use X,Y,width,height; they are manually selected diagnostic regions, not automatic sprite masks. The CLI accepts repeated `--region X,Y,W,H` arguments and records each result. All 22 synthetic tests pass; 32 captured scroll snapshots still match. Remaining work includes lower-terrain differences, DMA timing, additional frame validation, and Sonic-alone capture. G0 remains open.

### Sprite exclusion and captured palette diagnostics

Correction to the prior lower-terrain interpretation: foreground plants are sprite objects (`Obj_AIZForegroundPlant`), and the manually selected rectangle was not free of objects. The comparison now follows the linked H40 sprite table in captured pre-run RAM at `F800` and conservatively excludes each sprite rectangle, including transparent and occluded pixels. It rejects invalid links/cycles. This is not a sprite renderer or proof of terrain hidden inside those rectangles.

The remaining six frame-2640 differences outside those bounds were cycling palette colors. Passing the captured normal palette at `FC00` resolves them. This uses original emulator state; independent ROM palette-cycle implementation is still pending.

| Frame | Compared pixels outside sprite bounds | Mismatches | Excluded pixels |
| --- | ---: | ---: | ---: |
| 2220 | 59,585 | 309 | 12,095 |
| 2640 | 59,003 | 0 | 12,677 |
| 2700 | 56,624 | 0 | 15,056 |

Full-frame differences remain because sprite graphics are omitted. Frame 2220 remains unresolved, including possible sprite/DMA timing. All 24 synthetic tests pass; all 32 scroll snapshots still match. These are selected-frame diagnostics, not a full fidelity pass. Phase 4A/G0 remains open.

### Normal palette cycle modeled from ROM

`tools/aiz_palette.py` implements the normal AIZ1 eight-tick update interval, water-cycle index masking, sparkle-cycle wrapping, and disabled-sparkle counter hold. Colors come from supported-ROM tables `0x2AF6` and `0x2BF6`; the comparison resolves the last uploaded frame using captured counters `F632/F652`. It no longer uses captured palette colors as rendering input. Captured `FC00` words remain an independent comparison target. Fire/fades/underwater modes are outside this implementation; the comparison rejects fire-cycle and disabled-sparkle states.

Across all 24 pre-run snapshots from frame 2220 through 3600, all 64 modeled palette words match captured RAM. Advancing the cycle model 60 ticks matches the next snapshot's timer and both counters in all 23 intervals. Frame 2640 retains zero mismatches outside sprite bounds. All 26 synthetic tests pass.

Frame 2220's 309 residual pixels are localized to screen X 1..56, Y 155..164. Palette reconstruction does not explain that strip; sprite/upload timing and foreground drawing remain to be investigated. This is still selected-state research, not complete Phase 4A parity.

### Sonic-alone reference segment and implementation roadblock

The capture host now supports named local runs (`--run`) and an explicit `--profile sonic-alone`. The profile presses Up at tick 780 in the no-save menu before Start at tick 900. Captured `Player_mode` at `FF08` confirms value 1 at frames 1200, 2220, 2640 and 3600. No emulator RAM edits or save-state injection are used. The earlier Sonic+Tails run is preserved.

Compared all 24 sampled Sonic-alone frames from 2220 through 3600. **14 frames have zero mismatches outside conservative sprite bounds** (2220..2940 every 60 frames, plus 3060). All 24 palettes match. The ten nonzero frames have water beginning at screen Y=212; the current dry-plane model does not implement the lower twelve lines' water effects. Frame 3600 has 1,804 mismatches outside sprite bounds. Reports now explicitly mark visible water as unsupported. This is partial renderer evidence, not completion of terrain or route validation.

The original Sonic+Tails frame-2220 case is a separate persistent-background-table issue. Diagnostic core serialization, validated against matching captured RAM, confirms the visible background nametable word at screen `(1,155)` is `C099`; direct current-layout sampling at source `(192,608)` gives `78BB`. The foreground word agrees (`4043`). Layout, block and chunk RAM agree with ROM data. Main graphics upload is also in progress, with the next destination `27C0`; the renderer now preserves intro tiles beyond this boundary, but that alone does not resolve the 309 pixels. Exact transition rendering requires modeling incremental nametable updates and their upload timing. Do not patch the layout or hide these differences with a larger mask.

**Substantial next implementation step:** persistent original-plane drawing state, including row/column update queues, DMA boundaries, and water scanline/palette effects. The scripted route also oscillates near camera X `1DA4..1E36` rather than completing the act. It needs a route-aware input trace before progression, ignition, burned-map and completion evidence can close G0. No owner exception is implied or requested. Phase 4A remains open.

Validation: all 27 Python tests pass; `git diff --check` passes. Local artifacts are in `%LOCALAPPDATA%/S3KRemastered/research/reference/sonic-alone` (including `segment-summary.json`) and `graphics-state` (including `state-inspection-02220.json`). No game-runtime code changed in this research increment.

### Consecutive-frame evidence collected

See [the reference dataset](REFERENCE_DATASET.md) for run names, reproduction and limitations. Collected 302 uninterrupted Sonic-alone dense frames around intro/water and 121 uninterrupted Sonic+Tails frames around the known transition failure. All consecutive state boundaries match within each interval. Reports preserve changed art tiles, nametable cells, palette changes, scanline scroll pairs, VDP registers, VSRAM and DMA queues. The first visible-water frame is 2999 (screen Y=219).

Checkpoint replay reproduced 21/21 images, but transient RAM differences mean uninterrupted runs remain the timing authority. A revised jump input sequence cleared the first traversal obstacle; 27/27 sampled images match a fresh-boot replay. A new checkpoint exists near camera X `21F6` at frame 3300. The next obstacle and full-act route remain unfinished. All 28 Python tests pass; no runtime or gate status change.

### Water scanline deformation implemented

`aiz_scroll.water_line_offsets` now generates original AIZ1 foreground/background source coordinates below the waterline using ROM tables `23A170` and `23A3B0`. Table phases use the captured level-frame counter (`FE04`) and original water/background coordinates; no fitted per-frame offsets are used. The comparison renderer applies both sets of scanline offsets.

`python tools/validate_aiz_water.py <supported-ROM>` checks the dense dataset: **39 visible-water frames, 17,472 scroll words, zero differences** against uploaded VRAM scroll data. The independently rendered frame 3600 improves from 1,804 to 59 mismatches outside sprite bounds. All 59 remaining pixels share one normal-versus-water color difference. Original `HInt3` transfers water colors in three-entry groups with deliberate cycle delays, so exact palette staging needs a scanline-aware model. A whole-frame palette substitution is not an acceptable fix.

The comparison now separates modeled water scroll from unvalidated underwater palette behavior. Fully submerged camera entry remains explicitly unsupported. Persistent background nametable updates during the intro transition remain open. All 29 Python tests pass. No gameplay code or gate status changed.

### Phase 4C collision chunk-span synthetic review — 2026-11-21

The isolated Phase 4 queue accepted `p4c03-impl-01` at `f7ba9ac0043320cf65b07854e8fe3860e95d315f` and `p4c03-verify-01` at `98b8a357ad24df56dd6156a188b754f0343a3de0`. The actual terrain test (`tests/rom/test_rom_terrain.gd`) calls the production `RomTerrainCollision._height`, not a replacement decoder.

The persistent synthetic cases check: missing `chunks` returns `ok:false`; an incorrect chunks buffer type returns `ok:false`; a one-byte-short word returns `ok:false`; the final complete two-byte word at nonzero offset succeeds; and an empty block preserves height zero. The independent Godot collision oracle verifies the same behavioral boundaries, while the existing native terrain decoder synthetic regression remains green.

The two accepted task receipts at `D:/AI/SonicPhase4Queue/runs/p4c03-impl-01/chatgpt-01/acceptance-receipt.json` and `D:/AI/SonicPhase4Queue/runs/p4c03-verify-01/chatgpt-01/acceptance-receipt.json` contain SHA-256 checksums for the source, parser/regression/oracle logs, diffs and candidate commits. The review independently recalculated all seven evidence-file hashes for each receipt with zero mismatches. Both tasks report Godot 4.7 parser, terrain regression and independent oracle exit code 0 with required positive sentinels.

**Limit:** this is synthetic, source-informed collision-buffer coverage only. No original-ROM contact-probe trace parity has been established; Phase 4C and the G1/G2 fidelity gates remain open. A supported-ROM reference trace and matching runtime probes are still required before fidelity or gameplay-completion claims.

### Floor/right-wall contact coverage checkpoint — 2026-11-21

The accepted Phase 4 collision work guards the existing floor path, implements bounded right-wall height/neighbor helpers and persists nonuniform flip, seam and malformed-input regressions. Those are **source-informed synthetic** results; they do not demonstrate a wired player moving on imported AIZ terrain.

- **Accepted receipts:** `D:/AI/SonicPhase4Queue/runs/c11/chatgpt-01/acceptance-receipt.json` (right-wall seam regressions), `D:/AI/SonicPhase4Queue/runs/p4wallflip-impl-01/chatgpt-01/acceptance-receipt.json` (tile X/Y flips), and `D:/AI/SonicPhase4Queue/runs/p4probehard-recovery-01/chatgpt-01/acceptance-receipt.json` (replayed guarded floor/wall inputs after the Godot project-import recovery). Each records independent Godot checks, candidate commit and hashed evidence; the original failed collision-probe worktree is preserved.
- **Still unverified:** left-wall and ceiling probes, player contact ordering/attachment and path-layer transitions on real terrain, plus matched-input supported-ROM traces. No exact contact, physics or act-completion parity is claimed.
- **Next gate:** import and verify the supported local AIZ bundle, run Godot project import/class registration before gameplay regressions, then compare tick-indexed original-ROM floor/wall/ceiling/contact/player traces through flat ground, slope, seam and a layer transition. Keep G1 and G2 open until playable integrated evidence exists.

### Wall-flip and path-solidity review evidence — 2026-11-21

- **Implementation receipt:** `D:/AI/SonicPhase4Queue/runs/p4wallflip-impl-01/chatgpt-01/acceptance-receipt.json` verifies persisted X/Y flip, signed sample and angle cases, plus right-wall seam coverage; candidate `1673d6ca157feba117d8ca8c5f65ba0ac5141505`.
- **Verification receipt:** `D:/AI/SonicPhase4Queue/runs/p4wallflip-verify-01/chatgpt-01/acceptance-receipt.json` records a separate nonuniform four-flip oracle and a near-limit signed-byte regression; candidate `83ae4dd09591b03c113ea52d64c1c228b03f42f3`.
- **Review receipt:** `D:/AI/SonicPhase4Queue/runs/p4wallflip-review-01/chatgpt-01/acceptance-receipt.json` documents path-specific primary-only/secondary-only solidity discrimination and independent Godot checks; candidate `2001b680a85b3dbffd0a3506adaacffb3dcb4888`. Each receipt records file hashes and checker logs.
- **Open fidelity work:** all these checks use synthetic fixtures. Original-ROM matched-input contact traces, left-wall/ceiling directions, player integration, layer transitions and complete AIZ act traversal remain unverified. **G1 and G2 stay open**; no ROM trace parity or completion is claimed.
