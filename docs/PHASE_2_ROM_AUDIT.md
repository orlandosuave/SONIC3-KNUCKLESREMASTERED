# Phase 2 ROM behavior audit

Reference: local `local_reference/skdisasm/sonic3k.asm` and its sine table. This is a source comparison, not an emulator frame-trace comparison. ROM intake verification remains disabled for prototype work.

| Mechanic | ROM reference and result | Prototype status |
|---|---|---|
| Simulation | Movement rates expressed per 60 Hz update | Physics configured at 60 Hz; gameplay timer now counts physics ticks |
| Damage | `HurtCharacter`, `loc_10312`: X = +/-$200 away from hazard, Y = -$400 | Corrected direction and speed; separate hurt state blocks input |
| Hurt recovery | `loc_122D8`, `sub_12318`: move then add $30 gravity; stop on landing; set immunity to 120 | Implemented with Godot terrain contacts; timer held during hurt, starts after landing |
| Pickup lockout | `Test_Ring_Collisions`, `TouchResponse`: reject timer >=90 | Applied to stationary and scattered rings; overlaps rechecked each physics tick |
| Ring launch | `loc_1A67A`: max32, mirrored pairs, $288 angle sequence, two speed tiers | Implemented; sampled sine values truncated to integer before velocity scaling |
| Ring fall/bounce | `loc_1A75C`: move then add $18; floor penetration correction; -(Y-(Y>>2)) | Gravity and integer bounce response implemented; actual room geometry now stops rings going underground |
| Ring expiry | `ChangeRingFrame`: shared counter initialized255, decremented per frame | Individual 255-frame lifetime implemented; shared expiry and staggered removal remain differences |
| Death | `Kill_Character`: X0, Y-$700; `loc_123AA`: gravity; `loc_12432`:60-frame restart delay | Death arc ignores terrain, then waits60 ticks after crossing room death boundary |
| Checkpoint | `Save_Level_Data`, `Load_Starpost_Settings`: position/time saved; ordinary death clears rings | Position/time restored, ring count cleared, room rings rebuilt; full ROM world/camera state not represented |
| Spin Dash | High byte of charge indexes speed table | Corrected rounded index to truncated high-byte index |

## Validation

`tests/gameplay/test_phase2.gd` runs the real room physics and checks damage velocity, hurt input lock, hurt landing and immunity, pickup threshold, ring cap, death/restart, and ring ground bounce/expiry on flat ground and both slope directions. Runs pass with `--fixed-fps 60` and `--fixed-fps 120`; physics stays60 Hz. These are regression checks, not evidence of whole-game frame parity.

## Exactness gaps still open

- Player and ring terrain use Godot shapes instead of ROM tile heightmaps, angle bytes, sensor order, and integer position arithmetic. Full player movement therefore cannot yet be called exact.
- ROM rings check the floor on staggered eight-frame intervals, only while descending and visible. This implementation sweeps collisions every tick and also responds to walls/ceilings. ROM shared ring lifetime, sprite collision rectangles, and sparkle animation are not reproduced.
- Death boundary is the test room's configured `death_y`, not the ROM camera-relative threshold. Life count, game-over, fades, and level reload are absent.
- Checkpoints retain test-room position/time, not zone events, camera/water state, collision path, and persistent object bookkeeping. Static rings are reset for the room rather than through the original respawn tables.
- Full matched-input reference traces for acceleration, braking, jump arcs, slopes, and transitions remain required. Existing movement constants do not establish exact frame ordering or fixed-point parity.
- Underwater, shields, transformations, other characters, moving platforms, loops, and original animation/audio remain outside this normal-Sonic test-room slice.

Phase 2 prototype scope closed on 2026-11-14 following the project owner’s successful playtest and explicit approval. Exact ROM fidelity remains the target for follow-up work; the gaps above remain open and are not certified by prototype closure.

## Post-closeout slope correction

Walking slope regression reproduced unwanted downhill speed loss (180 px/s to about34 px/s while holding forward). The controller now retains scalar ground speed independently of Godot's post-slide velocity and preserves downhill momentum above normal running speed, following `ground_vel` and the input-speed checks in `Sonic_Move`. Uphill slope resistance is retained. `tests/gameplay/test_walking_slopes.gd` checks walking uphill/downhill in both directions on 0.4-grade terrain; it passes at 60 and 120 fixed render FPS with matching results. Existing Phase2 gameplay regressions also pass. This corrects artificial speed loss without claiming full ROM collision parity.

## Full implemented-mechanics review — 2026-11-14

Compared the normal-Sonic controller, ring spill, damage, restart/checkpoint loop, and current presentation boundaries with the local disassembly. No ROM intake verification or emulator trace capture was run. This review supersedes earlier claims that matching constants alone establishes matching behavior.

### Corrections applied

| Area | Source evidence | Correction |
|---|---|---|
| Air drag | `Sonic_JumpPeakDecelerate` uses unsigned comparison with -$400, then signed `asr.w #5` | Apply drag only for -4 <= Y < 0 px/frame; shift signed 8.8 X rather than rounded px/second. Falling no longer loses X to peak drag. |
| Air steering | `Sonic_ChgJumpDir` restores previous velocity when already beyond the input speed cap | Same-direction input preserves overspeed; opposite input still accelerates against it. |
| Ground/roll braking | `sub_113F6`, `sub_11482`, `sub_1161E`, `sub_11640` | Reversal uses +/-$80 crossing response, including signed crossing boundary; facing is retained during opposing ground braking. Input lock no longer adds friction while a direction is held. |
| Slow steep slopes | `Player_SlopeRepel` compares against $280 | Threshold corrected from600 to150 px/s (2.5 px/frame); signed slope-force multiplication now uses arithmetic shift. |
| Spin Dash | `loc_11C5E` branches to release before `loc_11D16` decay; `loc_11D5E` skips normal dispatch | Release retains charge and facing and does not run air/ground movement that tick. Charge taps/decay apply while Down remains held. |
| Jump dispatch | `Sonic_MdNormal`, `Sonic_MdRoll`, `Sonic_Jump` | Jump happens before ground acceleration/slope force and skips remaining ground movement on its takeoff tick. |
| Jump height | `Sonic_JumpHeight`, `Sonic_UpVelCap` | Track actual jumps separately from walking off edges; cap upward jump speed whenever Jump is unheld, rather than only on a release edge. Non-jump rise cap is separate. |
| Jump clearance | `Sonic_Jump` requires room >=6 | Added six-pixel shape sweep along floor normal. This is still a Godot approximation of the original probes. |
| Collision radii | `SonicKnux_Roll`, `Sonic_Jump`, `Sonic_RollJump` | Ducking and non-rolling falls retain standing dimensions; ordinary jumps are compact; roll-jumps restore default dimensions. |
| Falling/landing | `MoveSprite`, `loc_11F9C`, `loc_11FAE`, `loc_11FC2` | Removed unsupported 15 px/frame terminal fall cap. Landing uses X on shallow floors, half Y on moderate slopes, capped signed Y on steep slopes, instead of generic velocity projection. |

### Reviewed and retained

Normal acceleration $C, braking $80, maximum input speed $600, roll friction $6, roll braking $20, roll entry $100 and exit $80, jump impulse $680, normal gravity $38, damage/hurt gravity and velocities, 120-frame immunity, pickup lockout >=90, 32-ring spill cap, ring gravity $18 and integer bounce, and death impulse -$700 remain source-informed. Existing damage/ring/death/checkpoint tests pass. Geometry, ordering around contacts, and finite-width integer overflow are not certified as exact.

### Still missing or approximate

- ROM heightmaps, angle-table quantization, wall/ceiling/floor probe ordering, convex attachment/loops, and exact center/subpixel adjustments. Godot shape sweeps remain; jump clearance and landing detection inherit that limitation.
- Ring shared animation/expiry counter, every-eight-frame visible floor probes, exact pickup rectangles, sparkle animation, and floor-only collision response. Current rings also collide with walls/ceilings.
- Full checkpoint world state, lives/game-over, score and extra-life ring thresholds, ROM camera-relative death boundary, and level reload/fade behavior. The test room uses its own reset and goal trigger.
- Insta-Shield and elemental shield actions, underwater physics, speed shoes, Super/Hyper forms, Tails/Knuckles mechanics, moving platforms, and original animation/audio are not implemented in this slice.
- Current Phase3 camera is a custom ultrawide follow/look-ahead implementation, not the ROM camera's dead zones, look-up/down, or Spin Dash camera delay. It remains separate presentation work.
- Full fixed-point positions, exact sine table lookup, original simultaneous-button precedence, and matched-input emulator traces remain outstanding. Small left/right differences from signed arithmetic are expected; polygon contacts can add further differences.

### Regression evidence

`test_rom_mechanics.gd` checks signed drag, drag range, air overspeed, braking reversal, landing conversion, slope lock, collision sizes, jump release/impulse/takeoff timing, overhead clearance, and Spin Dash release. `test_walking_slopes.gd` covers both slope directions and both travel directions, plus roll-jump initiation on each. `test_phase2.gd` retains damage/ring/death coverage. All three pass at fixed60 and120 render FPS with60 Hz simulation; slope results match across both runs. These checks exercise the implemented corrections, not every absent ROM feature.
