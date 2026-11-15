# ROM Format Notes — Phase 1 Proof Set

**Phase 4 update (2026-11-14):** the historical proof below is followed by a new combined-game resource ledger. Only the original atlas proof is decoded/preview-verified; new byte matches are research evidence, not completed decoders. The combined-game configuration and object/ring resources supersede standalone-S3 candidates for Phase 4.

These notes establish a research map for the first proof set. The checked-in document contains no ROM bytes or extracted game assets. It uses the locally verified profile in [ROM_IMPORT_SPEC.md](ROM_IMPORT_SPEC.md) and public disassembly metadata as research references. The AIZ Act 1 intro tile ranges and KosinskiM output have now been checked against that exact image; layout, tile-to-palette selection, and tile placement are still unresolved.

## Profile and address model

| Field | Value |
|---|---|
| Accepted intake profile | `sk-s3-lockon-4m-sha256-fba0677f` |
| Image size | 0x400000 bytes |
| Component images | S&K at 0x000000–0x1FFFFF; Sonic 3 at 0x200000–0x3FFFFF |
| Address model for future readers | Component-local ROM offsets must be translated to combined-image offsets explicitly; never treat CPU addresses as file offsets without a documented mapping |
| Byte order | Mega Drive data structures are generally big-endian; verify per structure and document exceptions |
| Decoder status | Bounded KosinskiM decompression, packed 4bpp tile unpacking, Genesis CRAM conversion, and local AIZ tile-atlas cache proof implemented |

The intake hash pins one exact image. The two image headers establish the observed concatenation but do not establish every resource's component, address, or compression mode.

## Proof candidates

The first concrete level candidate is **Angel Island Zone Act 1**, starting with its intro layout. This keeps one zone and one act in view while also exposing that the intro and main section use different palette/tile sets.

| Resource ID (proposed) | Source metadata found in public project files | Encoding/representation indicated | Confidence and remaining work |
|---|---|---|---|
| `level.aiz.act1.intro.layout` | `SonLVL - S3.ini`: `Levels/AIZ/Layout/1.bin` | Separate layout file; exact cell encoding not established here | Medium: identify the loader/format definition, dimensions, pointer/source range in the accepted combined image, and layer conventions |
| `level.aiz.act1.tiles.intro.primary` | `SonLVL - S3.ini`: `Levels/AIZ/Tiles/Act 1 Primary.kosm` | KosinskiM compressed tile art, per INI `tilecmp` convention | Medium: verify compression implementation, decompressed length, tile count, and exact combined-ROM source range |
| `level.aiz.act1.tiles.intro.secondary` | `SonLVL - S3.ini`: `Levels/AIZ/Tiles/Act 1 Secondary.kosm` | KosinskiM compressed tile art | Medium: same checks as primary set |
| `level.aiz.act1.blocks.intro.primary` | `SonLVL - S3.ini`: `Levels/AIZ/Blocks/Act 1 Primary.kos` | Kosinski compressed block definitions | Low: block record width/height, tile attribute layout, and index rules need source verification |
| `level.aiz.act1.blocks.intro.secondary` | `SonLVL - S3.ini`: `Levels/AIZ/Blocks/Act 1 Secondary.kos` | Kosinski compressed block definitions | Low: same checks as primary set |
| `level.aiz.act1.chunks` | `SonLVL - S3.ini`: `Levels/AIZ/Chunks/Act 1.kos` | Kosinski compressed chunk definitions | Low: chunk dimensions, block references, flips, and palette/priority attributes need source verification |
| `palette.aiz.act1.intro` | `SonLVL - S3.ini`: `Levels/AIZ/Palettes/Intro.bin`, with Sonic/Tails palette `General/Sprites/Sonic/Palettes/SonicAndTails.bin` | Palette entries; Genesis CRAM color word format expected | Medium: exact color word conversion and palette composition must be checked against decoded preview |
| `player.sonic` | Disassembly tree places player data in `General/Sprites`; SonLVL configuration references Sonic palette | Art, mappings, animation tables, and palette are separate candidate structures | Low: choose a minimal idle/run/jump subset, then trace mapping/frame tables and art sources to exact profile offsets |
| `objects.aiz.act1.intro` | `SonLVL - S3.ini`: `Levels/AIZ/Object Pos/1-S3.bin` | Object placement records | Low: not required for the first static terrain preview; record format and references before using |

The repository's SonLVL diagnostic log for loading AIZ Act 1 reports the layout as **uncompressed**, the tile files as **KosinskiM**, and the block/chunk files as **Kosinski**. The intro and main layout both point to `Layout/1.bin`; the intro uses `Intro.bin` palette data and intro tile sets, while the main area uses the main-level tile sets and palette. Treat them as distinct preview configurations over shared layout data, not as an assumption that the whole act has one tileset.

These filenames come from the research project's source tree, not from a ROM extraction. They are useful labels and lead-ins for investigation, not a substitute for verifying address tables against the accepted profile.

## Verified AIZ Act 1 intro tile proof

The ranges below were found by matching each complete public disassembly resource against the locally supplied image with profile SHA-256 `fba0677fde9f76df93f3e98d6310d8af68b9847bde16e253d73cd4dd8134ed23`. This verifies fixed ranges for that exact profile; it is not a general ROM scanner or a pointer-table implementation.

| Resource | Combined-image offset | Compressed/source bytes | Decoded bytes | Decoded SHA-256 | Status |
|---|---:|---:|---:|---|---|
| AIZ Act 1 intro primary tiles | `0x3A566A` | 3,602 | 6,080 | `6d3f88feb4377a1f9770e1b9cdf7cddbb0e0aa6cd25a24f9b7b92a6e0cf5320d` | Decoded and local atlas generated |
| AIZ Act 1 intro secondary tiles | `0x3A647C` | 12,242 | 25,184 | `b4bc2b52bc8ae49446fc5547d907ac2fdd656821435b5547684d34d0557d546f` | Decoded and local atlas generated |
| AIZ intro palette | `0x28C314` | 96 | 48 CRAM words | — | Decoded; preview currently uses palette line 0 pending layout mapping |

The two tile output hashes match output from the public KENSSharp KosinskiM reference decoder when run over the matched reference resources. The implementation has bounded source reads, a declared-output-size limit, a module limit, a command limit, and rejects invalid back-references or output-size mismatches. No compressed or decompressed ROM bytes are checked in.

Genesis tile pixels use packed nibbles: each byte stores the left pixel in its high nibble and the right pixel in its low nibble. The local proof writes `tiles/aiz_act1_intro_primary.png` and `tiles/aiz_act1_intro_secondary.png` under `user://imports/<profile>/<source-hash>/1-1/`; the deterministic manifest lists each file's dimensions, tile count, decoded byte count, and SHA-256. These generated files remain outside the repository. The current preview is a raw tile atlas, not a reconstructed level scene.

## Proposed decode chain

The initial static level preview needs the following dependency chain:

1. Read the chosen level's layout and resolve layout cell IDs.
2. Decode chunk records and resolve chunk references to blocks.
3. Decode block records and resolve their tile indices and attributes.
4. Decompress tile art with the verified KosinskiM reader and unpack 4bpp Mega Drive tile pixels.
5. Decode the AIZ intro palette and convert Genesis color words into Godot colors.
6. Compose a static map image from layout → chunks → blocks → tiles, applying horizontal/vertical flips and palette-line attributes.

For the character preview, first resolve Sonic's animation script to frame IDs, frame IDs to sprite mappings, mappings to tile indices, and tile indices to decoded art. Do not infer frame layout from an extracted sheet or hard-code a guessed offset in the runtime.

## Format record required before decoder implementation

For each structure, add a row or subsection with:

- Component image and exact file offset range in the accepted 4 MiB image.
- How the range was located (pointer table, fixed address, or verified public symbol).
- Pointer/address base and conversion to combined-image file offsets.
- Compression or packing details, including terminator behavior and maximum output bound.
- Record size, dimensions, count, endianness, and reference/index semantics.
- Validation checks and expected decoded length/count.
- A synthetic fixture identifier or test-vector generator; never commit a ROM excerpt.
- Status: hypothesis, source-traced, decoded, or preview-verified.

## Research references

- [Sonic & Knuckles disassembly README](https://github.com/sonicretro/skdisasm) describes the `General`, `Levels`, and `Lockon S3` organization, KosinskiM use for realtime art, and the level drawing system.
- [SonLVL - S3.ini](https://github.com/sonicretro/skdisasm/blob/master/SonLVL%20INI%20Files/SonLVL%20-%20S3.ini) names AIZ Act 1 intro/main tiles, blocks, chunks, layout, palette, objects, and start-position assets.
- [SonPLN.ini](https://github.com/sonicretro/skdisasm/blob/master/SonLVL%20INI%20Files/SonPLN.ini) demonstrates that tile art, mapping data, palette data, dimensions, and compression labels are separate inputs in the research tooling.
- [SonLVL AIZ load diagnostic](https://github.com/sonicretro/SonLVL/issues/137) shows the tool's detected encodings for AIZ Act 1: KosinskiM tiles, Kosinski blocks/chunks, and uncompressed layout.

These references support the structure inventory and dependency chain. Only the listed AIZ tile/palette source ranges have been matched to the accepted profile so far; no disassembly code or extracted assets are imported into the game.

## Current status and next checks

- **Known:** the accepted image is two consecutive 2 MiB component images; AIZ intro primary and secondary tile ranges and palette range match complete reference resources; both KosinskiM outputs match independent reference hashes; packed 4bpp unpacking and atlas generation run in Godot.
- **Unknown:** tile palette-line assignment in the layout, layout dimensions/encoding and placement references, tile/block/chunk record schemas, and the complete Sonic frame chain.
- **Next:** finish the small texture preview UX and verify palette/layout mapping, then trace the compact AIZ layout into a static level view. Keep the scope to a proof slice; do not expand into a general ROM scanner.

## Phase 4A — Combined-game resource range ledger

Verified 2026-11-14 against the same supported SHA-256 above, with local disassembly revision `73de97c6b55055bcb8089c1d55d006b02136f163`. Complete local reference resources were searched in the supplied image read-only. Offsets below are combined-image file offsets; ranges are `[offset, offset + length)`. S&K occupies offsets below `0x200000`; S3 component-local offsets equal combined offsets minus `0x200000`. This does not by itself resolve CPU pointers or prove active runtime references.

The player-facing first act crosses to the second internal map during ignition. See [Phase 4 content audit](PHASE_4_CONTENT_AUDIT.md) for source evidence and scope. Configuration: `SonLVL INI Files/SonLVL.ini`; do not use the standalone `1-S3.bin` object/ring variants for this combined-game route.

Paths below are relative to `Levels/AIZ/` unless stated otherwise. Every listed row is **byte-matched**, not decoded, except the existing intro tile/palette proof.

| Resource | Combined offset | Source bytes | Encoding / remaining schema work |
|---|---:|---:|---|
| Tiles/Act 1 Primary.kosm | 0x3A566A | 3602 | KosinskiM; existing decoded proof |
| Tiles/Act 1 Secondary.kosm | 0x3A647C | 12242 | KosinskiM; existing decoded proof |
| Tiles/Act 1 Main Level.kosm | 0x3A944E | 10226 | KosinskiM; verify decoded count and destination tile base |
| Tiles/Act 1 Fire Overlay.kosm | 0x3AF5D0 | 2690 | KosinskiM; event-specific placement |
| Blocks/Act 1 Primary.kos | 0x3A374A | 512 | Kosinski; verify tile words, flips, palette, priority |
| Blocks/Act 1 Secondary.kos | 0x3A394A | 3136 | Kosinski; intro block destination/merge rules |
| Blocks/Act 1 Main Level.kos | 0x3A458A | 4320 | Kosinski; runtime replacement destination |
| Chunks/Act 1.kos | 0x3ABC40 | 14736 | Kosinski; verify block and collision attribute words |
| Layout/1.bin | 0x281420 | 2124 | Raw; dimensions, row-pointer bases, layers and bounds unresolved |
| Collision/1.bin | 0x274760 | 3072 | Raw; primary/secondary indexing must follow `LoadSolids`, not a generic interleaved assumption |
| Object Pos/1.bin | 0x1E44DA | 924 | Raw; 153 six-byte records + terminator; X/Y words + ID/subtype bytes; full Y flags/loader semantics still to trace |
| Ring Pos/1.bin | 0x1E5A16 | 422 | Raw; record/sentinel rules unresolved |
| Tiles/Act 2 Primary.kosm | 0x3B15D2 | 8626 | KosinskiM; required during fire transition |
| Tiles/Act 2 Secondary.kosm | 0x3B3784 | 4418 | KosinskiM; required during fire transition |
| Blocks/Act 2 Primary.kos | 0x3B0052 | 2208 | Kosinski; required during fire transition |
| Blocks/Act 2 Secondary.kos | 0x3B08F2 | 2688 | Kosinski; required during fire transition |
| Chunks/Act 2.kos | 0x3B51E8 | 16400 | Kosinski; required during fire transition |
| Layout/2.bin | 0x281C6C | 3430 | Raw; identify selected-act subset using event/route evidence |
| Collision/2.bin | 0x275360 | 3072 | Raw; verify path indexing and referenced shapes |
| Object Pos/2.bin | 0x1E4876 | 4512 | Raw; 751 six-byte records + terminator; only a subset belongs to player-facing Act 1 |
| Ring Pos/2.bin | 0x1E5BBC | 1230 | Raw; schema and selected-act subset unresolved |
| Animated Tiles/Act1 0.unc | 0x2A2940 | 2304 | Raw tile data; animation schedule/indices required |
| Animated Tiles/Act1 1.unc | 0x2A3240 | 960 | Raw tile data; animation schedule/indices required |
| Animated Tiles/Act2 0.unc | 0x2A3F00 | 2944 | Raw; applicability/timing in burned section to verify |
| Animated Tiles/Act2 1.unc | 0x2A3600 | 2304 | Raw; same |
| Animated Tiles/Act2 2.unc | 0x2A5680 | 512 | Raw; same |
| Animated Tiles/Act2 3.unc | 0x2A4A80 | 3072 | Raw; same |
| Animated Tiles/Act2 First Tree.unc | 0x2A5880 | 1120 | Raw; transition/background dependency to verify |
| Levels/Misc/Height Maps.bin | 0x096100 | 4096 | Raw; signed heights and probe selection to validate |
| Levels/Misc/Height Maps Rotated.bin | 0x097100 | 4096 | Raw; rotated probe indexing to validate |
| Levels/Misc/Angles.bin | 0x096000 | 256 | Raw; shape-to-angle lookup to validate |

Duplicate-match resources require pointer tracing before selecting an active copy:

| Resource | Matching offsets | Bytes | Remaining work |
|---|---|---:|---|
| Palettes/Intro.bin | 0x0A8B1C, 0x28C314 | 96 | Existing proof uses S3 copy; trace runtime palette loads |
| Palettes/Main.bin | 0x0A8B7C, 0x28C374 | 96 | Palette ownership and event loads |
| Palettes/Fire.bin | 0x0A8BDC, 0x28C3D4 | 96 | Fire transition loads |
| Palettes/Water.bin | 0x0A8C9C, 0x28C494 | 128 | Underwater composition and changes |
| Palettes/Act 2 Water.bin | 0x0A8D1C, 0x28C514 | 128 | Burned-section underwater applicability |
| Palettes/Miniboss.bin | 0x06917C, 0x247092 | 32 | Boss/cutscene palette ownership |
| General/Sprites/Sonic/Art/Sonic.unc | 0x100000, 0x300000 | 131296 | Mappings → DPLC → art chain; active copy |
| General/Sprites/Sonic/Palettes/SonicAndTails.bin | 0x0A8A3C, 0x28C234 | 64 | Full palette-file composition; config uses a subset |
| Start Location/Sonic/1.bin | 0x1E3C18, 0x1E3CD8, 0x25E018 | 4 | Short matches are weak evidence; resolve start-position table |

### Decoder contract still to complete

### Static layout schema verified — 2026-11-14

The research auditor now decodes both supported-ROM layout spans directly, with source interpretation checked against `sonic3k.constants.asm` (`Level_layout_header`/`Level_layout_main`) and `Find_Tile_FG` / `Find_Tile_BG`. This upgrades the two layout rows above from byte-matched/unknown schema to **static row decoding verified**, not rendered or gameplay-verified.

- Four big-endian header words give foreground width, background width, foreground height and background height in chunks.
- The header is followed by 32 interleaved foreground/background pairs of 16-bit row pointers, making a total header/table span of `0x88` bytes.
- Pointers address the original layout RAM beginning at low-word address `0x8000`; subtract that base to obtain offsets within the selected layout resource. They are not file offsets or offsets relative to the pointer field.
- Each active row has `width` one-byte chunk IDs. Each chunk spans 128×128 original pixels. Preserve shared row pointers; do not require rows to be disjoint or alter their order.
- The parser validates the complete table, active row counts (1–32), positive widths, the 4096-byte RAM cap and each row's payload span against the verified source resource. Unused row pointers are not dereferenced. This deliberately validates these AIZ resources, not all campaign variants.
- Decoding does not yet apply `Adjust_AIZ1Chunks`, `AIZ1_ScreenEvent`, `Adjust_AIZ2Layout` or other live modifications. Static dimensions are storage bounds, not camera or reachable-route bounds.

| Internal map/layer | Chunks (width × height) | Original pixel storage extent | Distinct chunk IDs |
|---|---|---|---:|
| 1 foreground | 97 × 13 | 12416 × 1664 | 190 |
| 1 background | 66 × 11 | 8448 × 1408 | 55 |
| 2 foreground | 153 × 21 | 19584 × 2688 | 241 |
| 2 background | 8 × 10 | 1024 × 1280 | 16 |

SHA-256 of concatenated active rows, in row order, from the supported ROM:

| Map/layer | Decoded row hash |
|---|---|
| 1 foreground | `c2c9126127b4b5506f668acfaf58416900f2c711fe012b3f1509c5f298e42c58` |
| 1 background | `fe00463dafb099e2663f75f0fd233a65154705f725feb142f46aaa9d3e6449f4` |
| 2 foreground | `a1028382a7220c7762336ef4a56fff6339221d48524817a6f691648eb9bb6ebe` |
| 2 background | `3116eb896edcebc18bb5b92a4d15f986c6376740e3f3f5ac387356d19447fa28` |

`tests/test_aiz_audit.py` now passes six synthetic tests, including layer interleaving, shared rows, invalid dimensions, pointer underflow/header references, pointer overrun and truncated/oversized layout rejection. Local integration decoded all four layers successfully. These hashes document this decoder's output; they are not an independent-renderer comparison. No layout bytes or generated images are tracked.

### Remaining decoder work

### Ordinary Kosinski and terrain references — 2026-11-14

`tools/audit_aiz_content.py` now implements bounded ordinary Kosinski decoding, separate from the existing module-based tile decoder. It handles literals, short/long/extended overlapping back-references, no-op and end commands, and eager descriptor refill. Source reads, output size and command count are bounded. It reports consumed length separately: verified resources may contain alignment bytes after the terminator.

All seven resources below decoded directly from the hash-pinned ROM. Output lengths and SHA-256 values independently match the local KENSSharp ordinary Kosinski decoder run on the complete reference resources previously byte-matched to this ROM. KENSSharp remains a local validation dependency; its code and generated data are not added to the game.

| Resource | Decoded bytes | Records | SHA-256 |
|---|---:|---:|---|
| Act 1 primary blocks | 616 | 77 | `c2adc6ac94a67c115be9dcebe7055ace7be07a34aaaf65e90aeeba542211a68b` |
| Act 1 intro secondary blocks | 4184 | 523 | `4fb3192dab8f3b3ebac5ed5f8ec544306f42d4487f4cdf4a0f8b1c7d6e77d8f7` |
| Act 1 main secondary blocks | 5360 | 670 | `5926124ecba344aee8f1fd1155f7921da44ee179ef98f2b7ffefacbce16be377` |
| Act 1 chunks | 32768 | 256 | `d987f328e30623fdc453289bed2d1879d10e240bdea07dd58830b0576a9b5992` |
| Act 2 primary blocks | 2744 | 343 | `1c28ac53a86fffadfccc0c5f200b9399241dfc1500ce43d939f60c8b8b1e2717` |
| Act 2 secondary blocks | 3304 | 413 | `bcae2465af05010a2f29da618dfdfec827159e98117a7d9c7f6b1769278a4f8d` |
| Act 2 chunks | 32768 | 256 | `a632497cb596a857ee9d429185efd94ea3c5540baa8267eb9ae82bdf13e11bd9` |

Chunks contain 64 big-endian block words (128 bytes); blocks contain four tile words (8 bytes). The source collision lookup masks block references with `0x3FF`. Every static foreground/background layout chunk ID fits its decoded 256-chunk table. Primary block byte lengths match the source replacement bases `0x268` and `0xAB8`. Primary plus main-map secondary provides 747 blocks for map 1 and 756 for map 2; every block ID in their complete chunk tables is in range.

The intro variant supplies only 600 blocks. Across the shared map-1 chunk table, 147 distinct block IDs exceed that loaded range. This is reported as an unresolved resource-state dependency, not repaired by padding or substituting tiles. Determine which chunks are visible/active before the swap and how original RAM is initialized before rendering the intro. Static table bounds alone do not prove runtime correctness.

Ten synthetic audit tests pass, including overlapping short/long/extended copies, descriptor rollover before payload, no-op/termination with alignment, truncated commands, invalid back-references and output/command limits. The supported-ROM integration passes. Tile-word attributes, collision-path attributes, palette/VRAM composition, live chunk mutations and rendering still need implementation/verification; these decoded tables are currently research tooling, not the Godot importer.

### Remaining integration work

### Tile, chunk and collision attributes — 2026-11-14

The research auditor now exposes separate tile-word and chunk-word readers; their bit fields are not interchangeable:

| Word | Index | Horizontal/vertical flip | Other attributes |
|---|---|---|---|
| Block's tile word | bits 0–10, tile ID | bits 11 / 12 | bits 13–14 palette line; bit 15 draw priority |
| Chunk's block word | bits 0–9, block ID | bits 10 / 11 | bits 12 / 13 primary top / sides-bottom solidity; bits 14 / 15 secondary top / sides-bottom solidity |

Evidence: `make_art_tile` in `sonic3k.macros.asm`, `Find_Tile_FG`, `sub_F264`, and the player probe routines selecting `top_solid_bit`/`lrb_solid_bit`. These readers preserve attributes; they do not yet implement flipped pixel composition or probe response.

**AIZ collision indexing:** `SolidIndexes` selects `Solid_AIZ1+1` / `Solid_AIZ2+1`, `LoadSolids` sets the secondary path base another `0x600` bytes later, and the probe reads at `block_id*2`. Consequently each 3072-byte resource contains two 1536-byte path spans, with **768 indices per path taken from odd byte offsets**. Do not read the high bytes, treat the entries as complete shape IDs, or use the S&K interleaved-path convention. Shape zero and solidity flags have additional probe semantics; index presence alone does not make a block solid.

Direct-ROM checks show 42/45 distinct primary/secondary shape IDs in map 1 and 68/71 in map 2. Both paths in both maps reach shape ID 255, within the matched 256-shape height/rotated-height/angle resources. Every decoded chunk block ID fits its collision path table. Heightmaps remain signed sample data whose flip/orientation and contact response must follow the original probes, not generic polygon conversion.

**Resource-state finding:** tile-word maxima are 187 for first-map primary blocks, 976 for intro secondary, 1400 for main secondary, 507 for second-map primary and 1400 for second-map secondary. Do not validate these solely against concatenated terrain tiles: PLC-loaded object art, animated tile destinations and event swaps also contribute to original VRAM state. All four palette lines occur in the map-1 secondary sets. A single-palette atlas cannot reconstruct these blocks faithfully.

`LevelLoadBlock` selects intro primary/secondary art and blocks with `PalID_AIZIntro`; the alternate Sonic/Tails intro load row selects the main secondary resources. `AIZ1_Resize` replaces blocks at byte offset `0x268` and tiles at tile index `0x0BE`; this is a stateful overwrite, not appending another complete tileset. `Adjust_AIZ1Chunks` returns without its initial chunk changes for Sonic; its initial modifications are Knuckles-specific. Later tree-event changes still apply separately. Verify the load-row selection and PLC/animated destinations before resolving intro references.

Validation: all 12 synthetic audit tests pass, including separate attribute masks and low-byte/split-path extraction using deliberately different values in the unused bytes and alternate path. Supported-ROM integration passes. No rendered comparison, complete VRAM composition or collision simulation parity is claimed.

### Graphics-state coverage — 2026-11-14

The auditor now decodes module-based Kosinski art and models bounded tile uploads with destination overwrite semantics. Six terrain/fire resources decode from the supported image; output hashes match the independent local KENSSharp decoder (the two intro matches were established earlier, the other four were checked in this pass).

| Resource | Tiles | Destination for relevant load | Decoded SHA-256 |
|---|---:|---|---|
| Act 1 primary | 190 | `0x000` | `6d3f88feb4377a1f9770e1b9cdf7cddbb0e0aa6cd25a24f9b7b92a6e0cf5320d` |
| Act 1 intro secondary | 787 | `0x0BE` | `b4bc2b52bc8ae49446fc5547d907ac2fdd656821435b5547684d34d0557d546f` |
| Act 1 main secondary | 585 | `0x0BE` | `3b2dc8cf9f2d14239b252ef8b85af93367230a0bde86c7de86835f96722bbbfe` |
| Fire overlay | 121 | `0x500` | `65c9c56ec42ed7f3f56a95daffca4e79c454c7eb9126bd547b80192366d662dd` |
| Act 2 primary | 508 | `0x000` | `0339f78f221215084dc25b15382271de2e56325b0cdd8e486a8f357c88d59429` |
| Act 2 secondary | 237 | `0x1FC` | `d02729c3fc4feeb48ff2a4fa8b2db7d375bb4124b413fe47281b7b82853cd0da` |

Every tile word in the loaded intro block set resolves using its 977 base terrain tiles. Every unresolved tile ID in the main/burned sets is in `0x500–0x578`, exactly the 121-tile fire overlay queued by `AIZ1_Resize`. Adding that explicit later-event upload leaves zero unresolved tile IDs in either set. This refines the earlier shared/object-art hypothesis: **these particular missing block references are fire art**, not evidence that arbitrary object PLC art must fill the holes. Other object graphics still need their own importer.

The coverage model evaluates base states and a separate fire-upload state. It does not claim fire art is present before its event, clear untouched VRAM on a swap, or emulate the original DMA timeline. The intro's unresolved *block IDs in the shared chunk table* are a separate issue and remain open; resolving tile words in loaded blocks does not resolve that issue.

Source load selection: `LoadLevelLoadBlock` and `LoadLevelLoadBlock2` use the intro row for initial Sonic/Tails mode with no last-starpost state, and the alternate main-resource row when that checkpoint state is present (or the character mode selects the alternate route). Primary art starts at byte zero; secondary starts at the primary resource's declared decoded byte length. Blocks likewise load consecutively. Later main/fire changes overwrite specific ranges.

Animation/state requirements traced from source, not yet implemented as a timed scheduler:

- `AnimateTiles_AIZ1` skips animation while `Boss_flag` is set and while `Dynamic_resize_routine` is zero. `AniPLC_AIZ1` targets tile ranges beginning `0x2E6`, `0x2F2`, `0x2FE`, with lengths 12, 12 and 6 tiles. Timing is per-entry, not a uniform assumed animation speed.
- `AniPLC_AIZ2` targets `0x0B3`, `0x0CA`, `0x0D6`, `0x0E2`, `0x0E6` with lengths 23, 12, 12, 4 and 24. Its first-tree branch, before logical camera X `0x1C0`, processes only the first animation group and uploads the 1120-byte first-tree resource at `0x0CA`; normal groups take over later. Boss state also suppresses this animation path.
- `PLC_0B` requests vine, rope, misc, falling-log, bubbles and cork-floor object graphics; `PLC_0C_0D` changes that collection for the later state. Those are separate Nemesis resources, not part of the six terrain-art streams decoded here.

Fourteen synthetic tests pass, including module-size/truncation rejection and uploads overwriting only their destination. Direct-ROM coverage and independent art hashes pass. Remaining graphics work: compose tile/block flips, palette/priority layers, correct view-dependent intro blocks, runtime layout mutations and timed animated uploads; then render and compare locally. Current coverage establishes resource availability, not pixel-perfect output or event timing.

### First local terrain render — 2026-11-14

`tools/render_aiz_preview.py` composes layout → chunks → blocks → tile pixels using palette-line selection, tile flips and whole-block flips. Tile color zero is transparent. The four tile words in a block are row-major; this agrees with the renderer's source word accesses in `sub_4EA4A`. Character palette line zero plus the selected intro/main/fire level palette forms the static 64-color palette.

Run `python tools/render_aiz_preview.py <local-ROM-or-ZIP-path>` with Pillow installed. Generated PNGs and the diagnostic report go only to `%LOCALAPPDATA%/S3KRemastered/research/aiz-static`, outside the checkout. It produces complete static foreground planes, an overview and a full-resolution main-terrain detail crop. Source bytes are read through the hash-pinned intake helper. No generated game artwork is tracked.

Main and burned foregrounds render with zero unresolved block IDs. The intro's full foreground references 110 unresolved distinct block IDs, marked visibly in magenta instead of silently replaced. This differs from the 147 out-of-range IDs across the complete chunk table because not every chunk-table entry is used by the foreground. Neither figure proves a visible gameplay defect: actual intro camera coverage/resource transitions still need verification.

Inspected the three-map overview and 1024×512 main-terrain detail at original scale. Grass contours, slope transitions, tree textures and waterfall columns compose coherently, with no obvious tile-order breakup in the inspected crop. This is a structural visual check, not a pixel-by-pixel comparison with an original-game capture.

Sixteen synthetic tests pass across the audit/render helpers. Added palette-line/nibble-order/transparency and palette-composition checks. Limits remain explicit: foreground only in the generated previews; no background scroll/deformation, foreground/background priority composition, water palette, objects, animated-frame scheduling or live layout/chunk mutations. The main preview includes later fire-art availability for whole-map diagnostics. No playable terrain or original-game frame parity is claimed.

### Intro coverage and priority-plane follow-up — 2026-11-14

Added a bounded rectangle-to-layout/chunk/block coverage query. The audit now reproduces nine diagnostic foreground checks at X `0x1000`, `0x1308`, `0x13FF`, each with widths 320, 560 and 800 original pixels, at Y `0x390` and height 224. All nine resolve within the 600-block intro set. X positions bracket source resize milestones; Y/width selections are diagnostic sampling assumptions, not recorded camera traces or the remaster's final framing. This does not certify the complete intro path, decompression-queue completion interval, or all ultrawide camera positions. It demonstrates why whole-map missing-ID counts cannot alone establish a visible intro failure.

The local renderer now exports background planes for all three resource variants and low/high-priority main foreground planes. Main and burned backgrounds have no unresolved block references. The intro background has 37 distinct unresolved IDs across its complete stored layout, requiring the same view/state analysis as its 110 foreground IDs. Inspected a main-background overview: stored background regions include sparse areas and separately arranged scenery; raw layout alignment is not a substitute for the original scrolling/deformation routines.

`compose_planes` composites already aligned low background → low foreground → high background → high foreground layers, preserving transparent pixels. It rejects mismatched dimensions/modes. It intentionally requires camera-aligned inputs and does not invent scroll offsets; full scene composition with Sonic/objects and priority is still pending. Priority filtering is performed before whole-block flips, keeping priority attached to its tile pixels.

Eighteen synthetic tests pass, including half-open rectangle intersection and priority ordering/transparency. Actual supported-ROM background/priority exports succeed. Generated assets remain outside the checkout. Next: derive actual background transforms and intro camera coverage from the original, then compare composed frames and implement live mutations; do not treat these static layers as proof of a playable route.

**Direct-ROM placement validation (2026-11-14):** `tools/audit_aiz_content.py` reproduces the 153/751 placement counts without reading the reference checkout. The hash-pinned second-map list has four descending X steps: original order must be retained, not sorted or rejected. Six-byte record bounds/termination and opaque flag preservation have synthetic regression coverage. This tool is a census, not the runtime importer; it does not yet certify all loader flag semantics or reachability.

`Load_Level` copies layout data to RAM; do not assume its fixed copy size equals the meaningful file size. Resolve header/row pointers and bound every referenced span to the correct source structure. `LoadSolids` distinguishes split S3 primary/secondary arrays from S&K interleaved data; selecting the wrong representation can produce plausible but incorrect collision.

Before implementing each decoder, record endianness/bit fields, exact pointer selection, dimensions/counts, terminator rules, decoded-output caps and cross-resource index checks. Add synthetic fixtures for truncated records, invalid pointers/indices, flip combinations and maximum bounds. The Phase 1 KosinskiM bounds remain reusable; ordinary Kosinski/block/chunk decoding is not yet delivered.

Sprite mapping/DPLC/animation tables, enemy/boss/cinematic art, sound-driver/music/SFX data and all event parameter families still need exact range/schema tracing. Source symbols in the content audit are research entry points, not substitutes for those missing records. No new decoded lengths/hashes or gameplay correctness are claimed by this ledger.
