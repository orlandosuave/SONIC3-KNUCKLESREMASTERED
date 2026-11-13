# Project Scope

**Status:** Draft for review  
**Project:** Sonic 3 & Knuckles Remastered  
**Scope version:** 0.1

## 1. Product definition

Create an independent, PC-first Sonic 3 & Knuckles fan project that combines a polished classic Sonic play experience with the extensibility and built-in creator tools that make Super Mario Bros. Remastered (SMB1R) compelling. Sonic 3 A.I.R. is a reference for the remaster experience; SMB1R is a reference for level editing, customization, and replay systems.

The project will build its own engine layer and tools in Godot. References to those games describe product goals only. The project will use original work or game data and assets that the team has permission to use.

## 2. Product goals

1. Make momentum-based platforming feel responsive, readable, and consistent.
2. Treat 32:9 as a supported gameplay aspect ratio, with correct camera composition and no image stretching.
3. Provide an in-game level editor with test-play and portable level packs.
4. Make character and presentation customization accessible through documented data formats.
5. Provide replay modes and quality-of-life settings in the game itself.
6. Keep the codebase and content pipeline approachable for community contributions.

## 3. Target users and platform

- **Players:** fans of classic 2D platformers who want configurable presentation, controls, and replay modes.
- **Creators:** players who want to build and share levels, characters, or presentation packs without needing to modify engine code.
- **First platform:** Windows PC.
- **Later platform goal:** Linux and macOS desktop builds, subject to performance and export testing.
- **Input:** keyboard and common gamepads, with rebinding.

Console, mobile, and online multiplayer support are outside the initial scope.

## 4. Release boundaries

### 4.1 First playable prototype

The prototype is a small, self-contained movement test level. It must establish:

- A controllable player with acceleration, braking, jumping, slopes, rolling, collision, and damage recovery.
- Rings, a checkpoint, and a clear end-of-level trigger.
- A follow camera with configurable look-ahead.
- Resizable window rendering that preserves the image and adapts the visible world area.
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

- A complete, coherent campaign based on the project's agreed Sonic 3 & Knuckles scope.
- A polished campaign flow with zone/act progression, bosses, checkpoints, save data, and endings.
- Native aspect-aware rendering from 16:9 through 32:9, with bounded-camera and expanded-camera options where level design requires them.
- Character selection using a documented, data-driven character format. The launch roster is limited to characters that have complete, balanced, and properly authorized content.
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

## 6. Quality requirements

- Gameplay simulation uses a fixed update step so movement remains consistent across display refresh rates.
- The initial performance target is stable 60 frames per second on a documented Windows PC baseline at 1920×1080. Higher resolutions depend on available hardware.
- The game must handle window resize, pause/resume, controller disconnect/reconnect, and missing or invalid user packs without losing campaign saves.
- Editor content must be validated before play or export, with actionable error messages.
- Settings and saves must be stored separately from installed game files.

## 7. Explicitly out of scope for 1.0

- Online multiplayer, rollback netcode, matchmaking, or shared live editing.
- Console and mobile releases.
- A public hosted mod marketplace or online account system.
- Unrestricted native-code or script execution from downloaded packs.
- 3D gameplay or a broad multi-game retro collection.
- Reproducing SMB1R, Sonic 3 A.I.R., or another game's source code, art, audio, level files, or branding.
- Guaranteed support for every community mod or every arbitrary monitor resolution.

These may be reconsidered after the 1.0 desktop release, but they are not part of the initial commitment.

## 8. Milestones and exit criteria

| Milestone | Deliverable | Exit criteria |
|---|---|---|
| 0. Scope and foundation | Scope, engine project, input/display conventions | Scope decisions recorded; project opens and runs a placeholder scene |
| 1. Movement prototype | Test room and basic player controller | Core movement, rings, damage, checkpoint, and goal can be played end-to-end |
| 2. Camera and ultrawide | Camera rules and viewport handling | 16:9, 21:9, and 32:9 pass composition checks without stretched artwork or broken triggers |
| 3. Vertical slice | One finished act and boss/set piece | A new player can complete the act; save, options, audio, and controls work |
| 4. Creator alpha | Level format and in-game editor | Create, save, reopen, validate, and test-play a level; export/import a level pack |
| 5. Content and modes | Campaign, supported characters, challenges, packs | Release content meets the agreed 1.0 checklist and has creator documentation |
| 6. Release candidate | Performance, accessibility, compatibility, packaging | No known blocker bugs; clean install can play and load supported content |

## 9. Definition of done for 1.0

1. Every 1.0 feature listed in Section 4.3 is implemented or explicitly removed by a revised scope.
2. A fresh installation can launch, play, save, and resume the campaign without developer tools.
3. The campaign and menus have been checked at 16:9, 21:9, and 32:9.
4. A creator can make a level, test it, save it, reopen it, and share it as a pack.
5. Supported packs that are malformed or incompatible fail with a clear message and do not corrupt saves.
6. The repository contains build/run instructions, controls, creator documentation, and a record of third-party content permissions.

## 10. Open decisions

These decisions should be settled before the vertical slice is treated as a content commitment:

1. **Campaign target:** faithful reconstruction of the complete Sonic 3 & Knuckles campaign, a shorter remixed campaign, or a new campaign inspired by its mechanics and structure.
2. **Content source:** what assets or game data may be used and distributed, and what must remain user-provided.
3. **Launch roster:** which characters receive complete gameplay kits for 1.0.
4. **Art direction:** original pixel-art treatment, updated pixel art, or another original visual style.
5. **Release model:** private learning project, free fan project, or another distribution plan.
6. **32:9 camera ceiling:** whether 32:9 always expands gameplay view or allows some scenes to use side panels and a bounded view.

Until decided, development should use placeholder/original assets, one playable character, a single-player desktop target, and a 32:9 expanded-view mode with a bounded-camera fallback.

## 11. Reference projects

- [SMB1R project](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public) and [SMB1R wiki](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/wiki): level editor, custom characters, resource packs, and content formats.
- [Sonic 3 A.I.R. official site](https://sonic3air.org/) and [source repository](https://github.com/Eukaryot/sonic3air): remaster presentation, controls, and modding reference.
