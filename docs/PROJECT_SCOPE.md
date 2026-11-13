# Project Scope

**Status:** Draft for review  
**Project:** Sonic 3 & Knuckles Remastered  
**Scope version:** 0.2

## 1. Product definition

Create an SMB1R-style PC game for Sonic 3 & Knuckles: a full-campaign remaster with a user-provided compatible ROM flow, a built-in level editor, custom characters, resource packs, and replay modes. Target 60 FPS gameplay and native 32:9 ultrawide support.

“Clone of SMB1R” means adopting its product structure and player/creator features. We will write our own Godot runtime, ROM importer, gameplay code, and tools. Sonic 3 A.I.R. is a reference for Sonic-specific behavior and remaster polish; it is not a code or asset source.

The selected ROM is input to a local validation and import pipeline. The game will not execute the ROM as an emulator. ROM files and extracted/generated game data stay in the user's local application-data directory and are excluded from this public repository and release packages. The repository contains the importer, original implementation, and tooling.

## 2. Product goals

1. Make momentum-based platforming feel responsive, readable, and consistent.
2. Deliver gameplay at a fixed 60 simulation updates per second and a stable 60 FPS rendering target.
3. Treat 32:9 as a native gameplay aspect ratio, with correct camera composition and no image stretching.
4. Provide an in-game level editor with test-play and portable level packs.
5. Make character and presentation customization accessible through documented data formats.
6. Provide replay modes and quality-of-life settings in the game itself.
7. Keep the codebase and content pipeline approachable for community contributions.

## 3. Target users and platform

- **Players:** fans of classic 2D platformers who want configurable presentation, controls, and replay modes.
- **Creators:** players who want to build and share levels, characters, or presentation packs without needing to modify engine code.
- **First platform:** Windows PC.
- **Later platform goal:** Linux and macOS desktop builds, subject to performance and export testing.
- **Input:** keyboard and common gamepads, with rebinding.

Console, mobile, and online multiplayer support are outside the initial scope.

## 4. Release boundaries

### 4.1 First playable prototype

The prototype starts by establishing the ROM and runtime foundations, then delivers a small, self-contained movement test level. It must establish:

- A file selection/drop flow for a user-supplied combined Sonic 3 & Knuckles ROM, with supported-revision detection and clear rejection of unknown/corrupt files.
- A read-only importer that extracts the first required graphics/data set to a versioned local cache outside the Git repository.
- A controllable player with acceleration, braking, jumping, slopes, rolling, collision, and damage recovery.
- Rings, a checkpoint, and a clear end-of-level trigger.
- A follow camera with configurable look-ahead.
- Resizable window rendering that preserves the image and adapts the visible world area through native 32:9.
- A fixed 60 Hz gameplay simulation with rendering capped/synchronized for a 60 FPS target.
- Keyboard and gamepad input.
- Debug controls for inspecting speed, collision, and camera behavior.

Placeholder art and sound are acceptable in this phase. The prototype is not a complete level editor or a release-ready campaign.

### 4.2 Vertical slice

The vertical slice is one polished, complete zone act that demonstrates the intended game quality from start to finish. It includes:

- A finished level, a checkpoint, a boss or set-piece encounter, and an act completion flow.
- Pause, options, controller remapping, save data, and return-to-menu behavior.
- A 16:9 composition and a 32:9 composition verified in actual gameplay.
- A first pass of sound, music, effects, menus, and accessibility settings.

### 4.3 First full release (1.0 target)

The initial full release is a single-player desktop game with:

- The complete combined Sonic 3 & Knuckles campaign: all primary zones and acts, character routes, bosses, special stages, bonus stages, transitions, and endings represented by the supported ROM version.
- A polished campaign flow with zone/act progression, checkpoints, save data, and endings.
- A compatible-ROM selector, validator, and local extraction/cache pipeline. The initial target is one supported combined S3&K ROM revision; additional regional/revision hashes follow only after their extracted data is verified.
- A 60 Hz fixed gameplay simulation and stable 60 FPS target, including campaign, special stages, and menus where applicable.
- Native aspect-aware rendering from 16:9 through 32:9, with 32:9 as a first-class, expanded gameplay view and a bounded-camera option for authored encounters.
- Sonic, Tails, and Knuckles as the initial complete character roster, using a documented, data-driven format. Additional characters can be added as compatible custom characters/packs.
- Time Attack and a small set of built-in challenge variants.
- An in-game level editor for placing supported terrain, objects, enemies, checkpoints, and goal events; instant test-play; validation; save/load; and import/export of level packs.
- Cosmetic/resource packs for supported art and audio replacements, with enable/disable controls and clear error reporting.
- Remappable keyboard/gamepad controls, display/audio options, and readable HUD layouts.
- Creator documentation and versioned level/pack formats.

An online level browser, online accounts, and automatic cloud distribution are not required for 1.0. Players can exchange exported packs as files.

## 5. 32:9 display requirements

- Maintain correct sprite proportions at every supported aspect ratio; do not stretch the game image.
- Keep movement physics independent of display resolution and aspect ratio.
- Use the wider view to show more level space only where this preserves encounter fairness. Allow the camera to be bounded for tightly staged sections.
- Keep essential HUD elements in a configurable safe region. Optional information may use the extra side space.
- Ensure menus remain usable at 16:9, 21:9, and 32:9.
- Include 32:9 test scenes for hazards, bosses, transitions, and level boundaries so content does not rely on a fixed screen width.
- Treat 5120×1440 as a reference 32:9 mode, while supporting other 32:9 resolutions through aspect-aware rendering.
- Treat 60 FPS as the normal-speed reference for game simulation. VSync/frame pacing can display at 60; higher refresh displays may use interpolation without changing simulation speed.
- Verify gameplay geometry and enemy/boss cues at 32:9. Extra visibility must not let the player trigger encounter logic prematurely or make hazards unfairly visible only at the last moment.

## 6. Quality requirements

- Gameplay simulation runs at a fixed 60 updates per second; render pacing must not change speed, collisions, timers, or input response.
- The initial performance target is stable 60 frames per second on a documented Windows PC baseline at 1920×1080 and a defined reference 32:9 resolution. Higher resolutions depend on available hardware.
- The game must handle window resize, pause/resume, controller disconnect/reconnect, and missing or invalid user packs without losing campaign saves.
- The importer never edits the supplied ROM. It verifies known revisions, reports unsupported inputs, and rebuilds its local cache when the selected source or importer version changes.
- ROM files and generated proprietary game data never enter Git history or public release archives.
- Editor content must be validated before play or export, with actionable error messages.
- Settings and saves must be stored separately from installed game files.

## 7. Explicitly out of scope for 1.0

- Online multiplayer, rollback netcode, matchmaking, or shared live editing.
- Console and mobile releases.
- A public hosted mod marketplace or online account system.
- Unrestricted native-code or script execution from downloaded packs.
- 3D gameplay or a broad multi-game retro collection.
- Reproducing SMB1R or Sonic 3 A.I.R. source code, art, audio, level files, or branding.
- Guaranteed support for every community mod or every arbitrary monitor resolution.

These may be reconsidered after the 1.0 desktop release, but they are not part of the initial commitment.

## 8. Milestones and exit criteria

| Milestone | Deliverable | Exit criteria |
|---|---|---|
| 0. Scope and foundation | Scope, supported-ROM decision, engine project, data-separation policy | Project opens; repository rules exclude ROM/cache data; initial supported ROM format/revision is documented |
| 1. ROM import spike | ROM selector, hash/size/header validator, local cache | Known supported image is recognized; bad/unknown image is rejected; source remains unchanged |
| 2. Movement prototype | Test room and basic player controller | Core movement, rings, damage, checkpoint, and goal run at fixed 60 Hz |
| 3. Camera and ultrawide | Camera rules and viewport handling | 16:9, 21:9, and native 32:9 pass composition checks without stretched artwork or broken triggers |
| 4. Vertical slice | One finished act and boss/set piece using imported/local content | A new player can complete the act at 60 FPS; save, options, audio, and controls work |
| 5. Creator alpha | Level format, in-game editor, custom packs, and replay modes | Create, save, reopen, validate, and test-play a level; export/import a level pack |
| 6. Full campaign | All zones, character routes, bosses, special/bonus stages, and endings | Every campaign path reaches its intended ending and passes 60 FPS/32:9 checks |
| 7. Release candidate | Performance, accessibility, compatibility, packaging | Clean install imports a supported ROM, plays/saves the full game, and loads supported content |

## 9. Definition of done for 1.0

1. Every 1.0 feature listed in Section 4.3 is implemented or explicitly removed by a revised scope.
2. A fresh installation can launch, play, save, and resume the campaign without developer tools.
3. The campaign and menus have been checked at 16:9, 21:9, and 32:9.
4. A creator can make a level, test it, save it, reopen it, and share it as a pack.
5. Supported packs that are malformed or incompatible fail with a clear message and do not corrupt saves.
6. The repository contains build/run instructions, controls, creator documentation, and a record of third-party content permissions.

## 10. Confirmed decisions and remaining decisions

### Confirmed scope

- Full Sonic 3 & Knuckles campaign.
- 60 FPS gameplay target.
- Native 32:9 support.
- User supplies a compatible ROM to unlock/import the game content.
- SMB1R-style product structure, including an integrated editor, custom character/resource packs, and replay modes.

### Remaining implementation decisions

1. Exact ROM source, format, region, and revision for the first supported combined S3&K image.
2. Which ROM-derived data can be generated locally and how much campaign/event data must be recreated in our own runtime.
3. Art treatment and allowed soundtrack/audio sources.
4. The reference PC hardware and 32:9 resolution for the 60 FPS acceptance target.
5. Distribution plan and any required approvals for the fan project.

Until those implementation decisions are recorded, use one known ROM revision, keep all ROM-derived files outside the repository, use placeholder/original assets for the game UI, and implement 32:9 expanded view with authored camera bounds where needed.

## 11. Reference projects

- [SMB1R project](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public) and [SMB1R wiki](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/wiki): level editor, custom characters, resource packs, and content formats.
- [Sonic 3 A.I.R. official site](https://sonic3air.org/) and [source repository](https://github.com/Eukaryot/sonic3air): remaster presentation, controls, and modding reference.
- [Sonic 3 A.I.R. releases](https://github.com/Eukaryot/sonic3air/releases): stable/test packaging, platform builds, release notes, ultrawide fixes, and mod workflow improvements.
- [Sonic 3 / Sonic & Knuckles disassembly](https://github.com/sonicretro/skdisasm): technical research into zone data, decompression, lock-on content, and event-driven behavior.
