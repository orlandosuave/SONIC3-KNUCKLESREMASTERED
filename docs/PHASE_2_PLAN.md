# Phase 2 — Movement and Collision Prototype

Phase 2 establishes the project’s 60 Hz movement and collision loop in an original-content test room. The local Sonic 3 & Knuckles disassembly is the implementation reference for Sonic’s normal movement states; Godot collision geometry remains an approximation of the ROM’s tile collision sensors.

**Status: Complete — prototype scope, 2026-11-14.** The project owner reports successful playtesting and approves closure. Automated gameplay regressions pass at 60 and 120 fixed render FPS with 60 Hz simulation. Exact ROM parity is a follow-up, not a claim of this milestone.

## Implemented from the local disassembly

- **Normal ground movement:** `$600` max speed, `$00C` acceleration, `$080` braking/deceleration, plus slope resistance, converted from 8.8 fixed point at 60 Hz.
- **Jump:** `$680` impulse rotated by the floor angle; holding Jump preserves the arc, releasing it caps upward speed at `-$400`, and upward speed is capped at `-$FC0`.
- **Air state:** twice the ground acceleration for directional control, disabled for roll-jumps; Signed 8.8 `x_vel >> 5` peak drag applies only while rising at up to 4 px/frame; falling does not apply it. Same-direction air input preserves existing overspeed.
- **Roll:** Down enters duck below `$100` ground speed and starts a roll at or above it. Rolling coasts down at half the ground acceleration, applies `$20` braking only when input reverses direction, and uses the ROM's `$50` slope repel (full downhill, quarter-strength uphill). Horizontal roll speed clamps at `$1000`; matching-direction input does not accelerate rolling. Roll-jumps retain the roll-jump air-control lockout.
- **Slope responses:** At rest, normal slope resistance starts only when the ROM's `$0D` force threshold is reached. After collision, `Player_SlopeRepel` adds a 30-frame movement lock and downhill push on slow slopes, or transitions Sonic into the air past `$30` angle units. Godot slope stopping is disabled so slope-force-driven rolling can progress down the prototype's hills.
- **Player collision size:** 9×19 px standing, ducking, falling without a roll, and roll-jumping; 7×14 px for ground rolls and normal jumps. The prototype keeps feet aligned when resizing; exact ROM center/subpixel adjustments remain a collision fidelity gap.
- **Spin Dash:** while ducking, a Jump press starts charging; held Down maintains charge; later Jump presses add `$200` up to `$800`, with the ROM’s `$20`-based decay; releasing Down launches using the `$800..$C00` speed table and the player’s facing direction.
- **Collision and room loop:** floor, wall, and ceiling contacts are reported; rings, damage/invulnerability, scattered-ring recovery, checkpoints, falling reset, and a goal trigger are present. Physics runs at 60 Hz independently of render pacing.

The values and transitions above are traced in the local, Git-ignored `local_reference/skdisasm/sonic3k.asm`: `Sonic_Move`, `Sonic_RollSpeed`, `SonicKnux_Roll`, `Sonic_Jump`, `Sonic_JumpHeight`, `Sonic_ChgJumpDir`, and `SonicKnux_Spindash`. ROM physics uses integer fixed-point arithmetic; the Godot conversion retains the same nominal rates but can differ by subpixel rounding and by the collision solver.

## Fidelity follow-ups after prototype closeout

- Compare jump height, airtime, stopping distance, and acceleration against a reference capture at matched 60 Hz input timing.
- Verify slope transitions, wall/floor corner behavior, and collision at different render pacing.
- Replace Godot’s generic floor contacts with ROM-style multi-probe/tile-angle collision only if required by the next project phase; that is a larger engine-specific task than copying movement constants.

## ROM features not in this prototype

- Underwater gravity/jump values, speed-shoes/Super speed tables, and character-specific movement variants.
- Shield-specific midair actions, moving-object/platform inertia, convex-surface attachment, and complete loop/corkscrew angle handling.
- ROM tile collision probes and exact airborne floor/wall/ceiling resolution; this room still uses Godot collision shapes.
- Animation/state presentation such as skid turns, balancing, landing, and rolling effects.

The player controller is now ROM-informed rather than a short list of guessed movement constants. Phase 2 has passed the project owner’s playtest; it should not be described as bit-exact ROM physics until the collision and fixed-point differences have been compared in-game.

## Remaining-mechanics ROM audit

See [PHASE_2_ROM_AUDIT.md](PHASE_2_ROM_AUDIT.md) for source labels, corrected damage/ring/death/checkpoint behavior, executable regression coverage, and explicit fidelity gaps. Exact parity remains unverified; the current implementation retains Godot collision and a simplified test-room restart.
