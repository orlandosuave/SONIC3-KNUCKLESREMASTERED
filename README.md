# Sonic 3 & Knuckles Remastered

An independent, original-content celebration of *Sonic 3 & Knuckles*, aiming to combine the responsive classic game feel and widescreen presentation of Sonic 3 A.I.R. with the built-in creation, customization, and replay systems that make Super Mario Bros. Remastered (SMB1R) a strong platform for players and creators.

This workspace is a blank starting point. This document records the product direction and a practical first milestone; it is not a claim that game code or assets already exist.

## Product direction

Build a polished Sonic platform game with a faithful-feeling core campaign, then make it easy to replay, customize, and create content without external tools. Treat SMB1R as a feature-set reference, not as a source of code, art, audio, level designs, or branding. Develop original assets and content, and only load game data that users are authorized to provide where applicable.

## Feature comparison

| Area | SMB1R reference | Sonic 3 A.I.R. baseline | Direction for this project |
|---|---|---|---|
| Core game | Multiple recreated SMB-family games, extra levels, and adjusted physics | Sonic 3 & Knuckles campaign with widescreen, gameplay fixes, and presentation options | A cohesive campaign with a well-tuned, configurable movement model and optional challenge rules |
| Modes and replay | Campaign, challenges, marathon variants, and other mode variations | Main campaign plus selectable characters and optional gameplay changes | Story campaign, time attack, boss rush, ring/score challenges, and remix rules built into the menus |
| Level creation | In-game editor and custom level / level-pack support | Modding can extend levels and scripts, but it is not centered on an approachable in-game level editor | An integrated editor with test-play, validation, checkpoints, events, and shareable level packs |
| Character customization | Character slots, animation/sound/appearance data, and resource packs | Playable character choices and a script-based mod ecosystem | Data-driven character kits and cosmetic packs, with clear compatibility rules; custom physics only through trusted game code/mods |
| Art and audio | Resource packs can replace game presentation | Mod support and display/audio options | Install, enable, preview, and disable content packs in-game; support per-pack dependencies and conflict messages |
| Resolution | Desktop display settings; ultrawide beyond 21:9 is not a defining capability | Built-in widescreen and aspect/scaling options; community mods expand the viewport | Native aspect-ratio-aware camera and UI, with 32:9 treated as a first-class viewport target |
| Community workflow | A broad user-content ecosystem and shareable level packs | Mature mod community and scripting documentation | Stable content format, creator documentation, versioned schemas, and import/export from day one of the editor milestone |

The central gap to close is not that A.I.R. lacks widescreen, modes, or modding. It already offers those foundations. The opportunity is to make player-made levels and remixable play modes a first-class, built-in workflow, and to make extreme ultrawide composition work without relying on community patches.

## Native 32:9 requirements

Treat 32:9 as a supported gameplay layout, not a stretched 16:9 image:

- Render to the actual viewport aspect ratio while preserving the game’s pixel-art sampling rules. Never stretch sprites or the playfield to fill the monitor.
- Let the camera reveal more of the level horizontally while keeping its vertical framing and movement physics stable. Add camera look-ahead and transition behavior suited to Sonic’s speed.
- Keep HUD and menus readable at 16:9 through 32:9. Anchor essential HUD elements in a central safe region; place optional information in configurable side regions.
- Author level events, hazards, enemies, and boss cues so they remain fair when visible earlier at wider ratios. Avoid spawning threats outside the camera only on the assumption of a fixed screen width.
- Test 16:9, 21:9, 32:9, windowed resizing, and ultrawide split layouts. Define a maximum gameplay view width if seeing farther would break encounters, while allowing black/illustrated side panels beyond that limit.
- Make the camera policy selectable for creators: expanded view, bounded view with side panels, and a legacy composition option.

32:9 at 1440 pixels tall is 5120×1440. Resolution independence and aspect-ratio correctness matter more than choosing one internal pixel resolution; scaling should be selected to avoid distortion and minimize uneven pixel sizes.

## Proposed roadmap

1. **Core prototype:** choose engine and data model; implement acceleration, deceleration, jumping, slopes, rolling, collision, rings, damage, death, and checkpoints with placeholder art.
2. **Camera and display:** configurable camera bounds/look-ahead, aspect-aware viewport, HUD safe areas, and 16:9/21:9/32:9 validation scenes.
3. **Playable slice:** one original zone with multiple acts, an act transition, a boss, save/checkpoint flow, and one complete character kit.
4. **Creator foundation:** level format, in-game tile/object editor, test-play, validation errors, and import/export of level packs.
5. **Replay and customization:** time attack, challenge modifiers, boss rush, character selection, cosmetic/resource packs, and documented extension hooks.
6. **Release readiness:** accessibility and controls options, localization-ready UI, performance passes, creator docs, and a clear original-content / user-provided-data policy.

## First playable acceptance criteria

- The player can complete a small original level using momentum-based movement, rings, a checkpoint, and a boss encounter.
- Gameplay timing and physics remain consistent at supported display resolutions and frame rates.
- 32:9 displays additional horizontal play space with correct camera behavior and no distortion, clipped HUD, or unfair off-screen event assumptions.
- A saved level can be reopened and test-played from the editor.

## Reference reading

- [SMB1R project overview and feature list](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public)
- [SMB1R wiki](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/wiki) — editor, custom characters, resource packs, and extension formats
- [Sonic 3 A.I.R. official site and manual](https://sonic3air.org/)
- [Sonic 3 A.I.R. source repository](https://github.com/Eukaryot/sonic3air)
