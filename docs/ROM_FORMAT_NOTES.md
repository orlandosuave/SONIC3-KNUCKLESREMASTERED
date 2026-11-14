# ROM Format Notes — Phase 1 Proof Set

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
