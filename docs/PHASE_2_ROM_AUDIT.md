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
