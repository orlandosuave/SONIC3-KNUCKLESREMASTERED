# SMB1R and Sonic 3 A.I.R. Reference Analysis

**Purpose:** translate the reference projects into an implementation plan for our full-campaign, 60 FPS, native-32:9 Sonic 3 & Knuckles project. This document describes their public source and documentation; it is not a recommendation to copy their code or assets.

## Executive finding

SMB1R is the better product-structure model for this project. Its key pattern is a Godot game that recreates the original gameplay, requires a compatible user ROM, validates it, and locally generates a base asset pack from ROM graphics. It then adds its own campaign scenes, level editor, custom level packs, custom characters, resource packs, and game modes.

Sonic 3 A.I.R. is the stronger Sonic-specific behavior and release-quality reference. It already provides widescreen, frame-rate/display options, an extensive mod system, and substantial platform packaging. Its release notes show continuing ultrawide-specific boss fixes and continuous refinement of mod import, rendering stability, and platform builds. We should not frame our differentiator as “A.I.R. has no widescreen or mods.” The gap is SMB1R-style built-in editing/custom-content workflows plus explicitly designed native 32:9 support.

## How SMB1R handles the supplied ROM

The source separates **game runtime** from **ROM-derived assets**:

1. **Intake:** `RomVerifier.gd` accepts a command-line ROM path, a local `.nes` next to the executable, drag-and-drop, or a file picker. It rejects archive files and unknown/corrupt inputs.
2. **Revision check:** it hashes the ROM payload (after the 16-byte iNES header) against an allowlist of two supported hashes. A filename alone does not identify a supported ROM.
3. **Local source copy:** after validation, it copies the file to the user's app-data configuration folder, not into a game level or editor scene.
4. **Asset generation:** `RomResourceGenerator.gd` reads the iNES header to locate CHR ROM, then `RomAssetRipper.gd` decodes NES 2-bit graphics tiles. A project-owned sprite list, tile-index JSON, and palette metadata tell the ripper which decoded tiles form each sprite.
5. **Generated pack:** the importer writes the reconstructed PNGs and versioned `BaseAssets` pack to app data. Re-verification can regenerate that cache after a source or importer change.
6. **Game logic and levels:** the README describes the game as recreated from the ground up. Campaign level scenes and the level editor/level-pack system are part of the project; the ROM is not run as an emulator to supply frame-by-frame gameplay.

Useful source references:

- [SMB1R README](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/README.md) — ROM required, project features, and its statement about original assets.
- [ROM verifier](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/Scripts/UI/RomVerifier.gd) — accepted hashes, input methods, error handling, and local copy.
- [ROM asset ripper](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/Scripts/Classes/RomAssetRipper.gd) and [resource generator](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/Scripts/UI/RomResourceGenerator.gd) — tile decoding and cache generation.
- [Global configuration](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/Scripts/Classes/Singletons/Global.gd) — app-data paths, ROM cache names, resolution presets, and game modes.
- [Level loader](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/Scripts/Parts/LevelLoader.gd) and [level class](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/Scripts/Classes/LevelClass.gd) — custom-level decoding and campaign scene progression.

### What transfers to our ROM flow

- On first launch, request a user-supplied compatible **combined Sonic 3 & Knuckles ROM**.
- Validate by file structure, size, and known content hashes; show the detected region/revision and give a useful error for unsupported variants.
- Read the input without modifying it. Generate versioned local data in the platform's user-data directory, never in the public Git checkout.
- Keep source maps from ROM offsets/structures to named sprites, tiles, palettes, animations, and level data in our own documented metadata.
- Make the importer repeatable and recoverable: source changes or schema-version changes trigger a clean cache rebuild.
- Keep playable behavior in our own runtime. ROM selection is the source-data gate, not a promise that the ROM grants or proves a user's legal rights.

## What changes for Sonic 3 & Knuckles

The SMB1R parser cannot be ported directly. Its ROM format is NES/iNES, with CHR graphics organized as simple 16-byte 2-bit tiles. Sonic 3 & Knuckles is a Mega Drive cartridge image with different graphics, palette, compression, and level structures.

The Sonic Retro disassembly describes S3&K as having modular Kosinski decompression for real-time art, a redesigned level drawing system, separate zone data, lock-on Sonic 3 data, and event-driven behavior tied to code in specific levels. It also warns that parts of the disassembly remain unidentified and are better used for research unless the reader understands the assembly. This means a “read the ROM and instantly get the whole game” importer is not a realistic first milestone.

Recommended split:

- **Importer:** identify supported ROM revisions and extract/decode the data we explicitly support.
- **Game runtime:** independently implement movement, objects, collisions, camera, bosses, special stages, transitions, and timing in Godot.
- **Campaign data:** store decoded/converted level layouts and resource references in a versioned internal format. Implement hard-coded scripted events as named data/events or runtime logic; do not expect raw ROM bytes to automatically define portable game behavior.
- **Creator tools:** build an editor on top of that internal level format, with test-play and exportable packs, following SMB1R's product model.

Research reference: [Sonic 3 / Sonic & Knuckles disassembly README](https://github.com/sonicretro/skdisasm/blob/master/README.md), especially its directory structure, `Sonic3_Complete` description, lock-on data, compression, and event-system notes.

## SMB1R's aspect-ratio implementation and our 32:9 target

SMB1R's project configuration uses a small fixed internal viewport. Its resolution settings include familiar pixel-art sizes and a final “expand” option; `WindowChanger.gd` switches Godot's content scale aspect to `EXPAND` for that option and otherwise uses `KEEP`. `CameraHandler.gd` reads the visible viewport width when calculating camera limits. This is a useful pattern for adapting camera limits to the actual viewport, but it does not by itself establish 32:9 as a fully authored or verified design target.

Sonic 3 A.I.R. already supports widescreen and its release history includes an ultrawide fix for the Death Egg Zone final boss. That is evidence that extreme aspect ratios affect encounter framing and must be addressed per level/boss, not only in a display setting.

Our 32:9 definition should therefore include:

- A live viewport whose visible horizontal world area actually expands to 32:9; no stretching or forced 16:9 crop.
- Camera bounds and look-ahead based on current view dimensions, with authored camera clamps available for bosses/cutscenes.
- Hazard, enemy, and boss trigger rules independent of assumptions about screen edges.
- HUD safe-area anchors and menus verified at 16:9, 21:9, and 32:9.
- A fixed 60 Hz simulation, with rendering/VSync capped or synchronized to 60 FPS by default. Faster display refresh must not make Sonic move faster.
- A stated 32:9 reference resolution for performance acceptance; hardware limits still apply at 5120×1440.

Useful source references:

- [SMB1R project settings](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/project.godot)
- [SMB1R window and frame-limit settings](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/Scripts/UI/WindowChanger.gd)
- [SMB1R camera handler](https://github.com/JHDev2006/Super-Mario-Bros.-Remastered-Public/blob/main/Scripts/Parts/CameraHandler.gd)
- [Sonic 3 A.I.R. releases](https://github.com/Eukaryot/sonic3air/releases)

## What A.I.R.'s releases teach us

The linked release page separates stable updates from test builds and ships platform-specific packages. The [stable 26.03.28 release](https://github.com/Eukaryot/sonic3air/releases/tag/v26.03.28.0-stable) calls out renderer-stutter fixes, a file browser for importing mod ZIPs, and mod-development tools. A [26.07.12 test release](https://github.com/Eukaryot/sonic3air/releases/tag/v26.07.12.1-test) notes ultrawide fixes in the Death Egg Zone final boss and a drop of 32-bit Windows support. The [26.08.15 test release](https://github.com/Eukaryot/sonic3air/releases/tag/v26.08.15.0-test) contains more bug fixes and script-modding improvements.

For this project, borrow the release discipline:

- Publish versioned Windows packages first, then add Linux/macOS packages after validation.
- Keep experimental preview builds separate from stable releases.
- Write release notes under clear headings (gameplay, display/performance, editor/modding, compatibility).
- Treat each display-specific boss/cutscene bug as a real compatibility issue with a reproducible test case.
- Include a local file browser/import flow for user ROMs and creator packs; make invalid files recoverable without reinstalling.

The release page also confirms that A.I.R. continues to add quality improvements on top of its existing widescreen and mod support. Our project should be judged by specific deliverables—full S3&K campaign, built-in editor/custom content, 60 FPS behavior, and first-class 32:9—not by a blanket claim that A.I.R. lacks those capabilities.

## Recommended first technical milestone

Build a vertical “ROM-to-playable-room” slice before committing to the full-campaign importer:

1. Specify and document one supported combined ROM revision.
2. Implement drag/drop and file-picker intake, hash/header validation, and clear unsupported-ROM messaging.
3. Produce a local cache manifest with source hash, importer version, and generated-data version; prove that no ROM/cache files are staged by Git.
4. Decode one player sprite set, one tileset/palette set, and one compact level layout.
5. Load that converted data in a Godot test room with a fixed 60 Hz movement simulation.
6. Run the same room at 16:9 and 32:9 and confirm camera bounds, trigger behavior, HUD placement, and 60 FPS on the documented baseline hardware.

Only after this succeeds should we scale the conversion tables and event logic across every zone, route, boss, special stage, and ending in the full campaign.
