# Phase 1 — ROM Intake and Data Feasibility

Phase 1 proves the path from the user's Sonic 3 & Knuckles ROM to local game data used by the remaster. It is a focused feasibility slice, not a full-campaign extraction milestone.

## Product boundary

- The supplied ROM is the source of original game data for the remaster: graphics, palettes, animation data, layouts, object placements, and other structures as the importer supports them.
- The Godot project provides its own runtime, simulation, presentation, and game systems. Phase 1 does not execute the ROM as an emulator.
- The ROM and imported outputs stay in local user data and are never committed, attached to public issues, or included in public builds.
- The first profile is the exact locally inspected 4 MiB combined lock-on image described in [ROM_IMPORT_SPEC.md](ROM_IMPORT_SPEC.md). The implementation should allow adding more verified revisions/regions later; this first profile is a starting point, not the final compatibility policy.

## Work packages

## Delivery strategy

Deliver Phase 1 as a sequence of reviewable checkpoints. Each checkpoint must leave the project launchable and must keep ROM-derived bytes outside the repository.

1. **Make intake usable (1C):** add a startup screen that can validate an input and explain what happens next. Do not call extraction until the user chooses to continue.
2. **Prove one format at a time (1D):** document exact source ranges and decode recipes for the small AIZ tile/palette proof; keep unverified formats marked as unknown.
3. **Create the local data contract (1F):** define the manifest and cache layout so output generation has a stable contract.
4. **Build the small proof (1E):** import the AIZ tile art and palette into local cache and display the tile atlas through Godot.
5. **Close the handoff (1G):** record what the intake/import spike proves, its limitations, and the next content milestones. Only then mark Phase 1 complete.

The ordering allows the manifest design and format research to proceed in parallel, but output-producing decoders should not be treated as stable until the data contract is written. Work packages 1E and 1F may be implemented incrementally together after their interfaces are agreed.

## Phase-wide technical contract

- **Runtime boundary:** the importer validates and converts explicitly supported data. It does not interpret or execute 68000 code, emulate hardware, or use ROM code to drive gameplay.
- **Input boundary:** source is opened read-only. ZIP members are read in memory or streamed; the importer never extracts an archive beside the source or copies the ROM into the project.
- **Output boundary:** cache root is `user://imports/` (resolved by Godot to the per-user application data location). No absolute source path, source filename, source bytes, or decoded binary payload is written to JSON logs/manifests.
- **Failure boundary:** each stage returns a structured result with a stable error code and a plain-language message. An import failure must leave the previously published cache usable.
- **Determinism boundary:** identical profile, importer/schema versions, and source bytes produce byte-identical manifest metadata and outputs. Exclude timestamps, machine-specific paths, and nondeterministic resource ordering.
- **Compatibility boundary:** only profile IDs in the explicit allowlist are accepted. A matching title/header alone is not compatibility evidence. Adding a revision requires independent inspection and fixtures.
- **Repository boundary:** source ROMs and decoded game data are local user data. Repository fixtures may contain synthetic/minimal bytes and metadata needed to exercise parsers, but no ROM excerpts or reconstructed game art/layouts.

## Proposed import flow

`Select file → inspect container → validate profile → show result → user starts import → decode into temporary cache → validate outputs → publish manifest/cache → load proof scene`

The UI should make each transition visible. Before the user starts import, show only the profile and validation summary. During import, show a progress phase (not a misleading percentage if work is not measurable). On success, offer **Open proof scene** and **Show local data folder**; on failure, retain the previous valid cache and show a retryable explanation.

## Cache layout and data ownership

Use a profile/fingerprint/version keyed cache beneath `user://imports/`, with a temporary sibling during generation. The exact directory names are implementation details, but the stable logical groups should be:

```text
user://imports/<profile>/<source-hash>/<schema>-<importer-version>/
  manifest.json
  tiles/aiz_act1_intro_primary.png
  tiles/aiz_act1_intro_secondary.png
```

All paths stored in the manifest are relative to that cache root. The manifest indexes resource IDs, resource type, relative path, dimensions/counts where applicable, and SHA-256 of each generated file. Never serialize Godot absolute `user://` paths into the manifest.

## Proof-set scope

Keep the first proof set deliberately small and named in the format notes before implementation. It consists of:

- The AIZ Act 1 intro primary and secondary tile graphics.
- The associated intro palette decoded into Godot colors for a tile-atlas preview.
- A local manifest listing the two generated preview images and their hashes.

This proves the intake → verified profile → bounded decompression → image generation → local cache path. It does not include character animation mapping, level layout reconstruction, object behavior, collision physics, music/audio, boss scripts, special stages, or campaign routes. Move character and level reconstruction to the vertical-slice and full-campaign phases.

## Checkpoint review artifacts

At each checkpoint, update the applicable document and leave a short review note in `docs/PHASE_1_PLAN.md` or a linked implementation note:

| Checkpoint | Reviewable evidence |
|---|---|
| 1C | Startup screen behavior, accepted/rejected input states, and cache location shown in UI |
| 1D | `ROM_FORMAT_NOTES.md` entries with source ranges, decoder steps, confidence, and fixture references |
| 1F | Manifest schema example using synthetic values, cache invalidation rules, and atomic publish behavior |
| 1E | Proof scene screenshot or capture plus resource index/hash listing (no extracted files committed) |
| 1G | Compatibility/gap summary and proposed next extraction increment |

Do not add screenshots containing decoded proprietary art to the repository. A local screenshot may be used during review if kept outside the checkout.

### 1A — Identify the first input profile · Complete

**Output:** [ROM_IMPORT_SPEC.md](ROM_IMPORT_SPEC.md), containing the ZIP/member layout, uncompressed size, per-image headers, region fields, and source fingerprint.

**Acceptance:** the exact supplied image can be distinguished from unsupported images using documented, reproducible metadata. Do not claim support for uninspected revisions based only on a similar filename or header.

### 1B — Implement an intake inspector · Complete

**Output:** `scripts/rom/rom_inspector.gd`, a reusable check for the supported raw `.md` file or ZIP form.

**Acceptance:** reports structured success data or a user-facing reason for failure; reads source data without modifying or extracting it; never writes source bytes to the checkout.

### 1C — Add the intake experience · Complete

**Tasks:**

- Add a startup/import screen with file picker and drag/drop support.
- Keep the existing inspector as the single validation authority; the UI should format its structured result rather than duplicate hash/header rules.
- Show detected image profile, size, and validation result before import proceeds.
- Explain wrong file type, archive ambiguity, wrong size, unsupported hash/profile, and unreadable file errors in plain language.
- Offer a local data folder under Godot `user://` and a way to inspect or clear generated cache without touching the source ROM.
- Make cache clearing explicit and scoped to this game's generated data; never offer a control that deletes or relocates a selected source ROM.
- Preserve the last valid import if a new selection is unsupported or an import fails.

**Acceptance:** a user can select or drop the provided ZIP and see a clear success result; invalid and ambiguous inputs fail without crashing or changing the source file.

**Checkpoint:** the screen in `scenes/main.tscn` and `scripts/ui/import_screen.gd` supports file selection/drop, inspector-backed validation, local data-folder access, explicit generated-cache clearing, and an AIZ tile-atlas import action. `test_local_aiz_import.gd` exercises the valid import and wrong-size rejection states through the screen logic.

### 1D — Map ROM data structures · Complete

**Tasks:**

- Create a format catalog for the proof set: ROM location, byte layout, compression/packing method, dimensions/counts, references, and decoder status.
- Record the source ranges, compressed lengths, output lengths, palette range, and tile packing for the AIZ Act 1 intro proof.
- Record the matching profile/revision constraint for those ranges.
- List character, level-layout, object, and event structures as future work without requiring their formats for Phase 1 completion.
- Record uncertain offsets/formats as hypotheses until checked against decoded output; avoid hard-coding unexplained offsets in gameplay code.
- For each structure, record endianness, pointer base, compression type, alignment, bounds checks, known references, and any assumptions about the selected profile.
- Define stable internal resource IDs and a minimal serialized representation before decoder output becomes a runtime dependency.

**Output:** [ROM_FORMAT_NOTES.md](ROM_FORMAT_NOTES.md) plus decoder fixtures/metadata that contain no ROM byte dumps or extracted proprietary assets.

**Acceptance:** the two AIZ tile resources and palette used by the proof have traceable ranges and documented decode steps; later game-data formats are clearly marked as not yet investigated.

**Checkpoint:** `ROM_FORMAT_NOTES.md` records the exact-profile AIZ Act 1 intro primary/secondary tile and palette ranges. KosinskiM output was checked against reference hashes, and packed-pixel decoding is covered by synthetic tests. Layout, palette-line assignment, and block/chunk schemas are still open, so this remains a partial format map.

**Decoder foundation:** `scripts/rom/rom_data_decoder.gd` provides bounded KosinskiM decompression, packed 4bpp tile unpacking, Genesis CRAM palette conversion, and tile-atlas image composition. Synthetic checks live in `tests/rom/test_rom_data_decoder.gd`. `scripts/rom/rom_texture_importer.gd` generates the AIZ Act 1 intro raw tile atlases under `user://` after profile validation. Character mappings and the level layout/block/chunk rendering remain open.

### 1E — Decode and load a proof set · Complete

**Tasks:**

- Decode the AIZ Act 1 intro primary and secondary tile art and the associated palette.
- Save two generated tile-atlas images under the local user cache and display the primary atlas in Godot.
- Keep the preview clearly labeled as a tile atlas, not a reconstructed level.
- Keep decoder code separate from UI and gameplay code; parsers should accept byte arrays plus explicit bounds and return typed data/errors.
- Reject out-of-range pointers, impossible dimensions/counts, truncated streams, and decompression overflow with actionable import errors.
- Provide a developer-only reimport action so parser changes can regenerate the proof set without clearing unrelated user data.
- Keep decoded output in local user data; do not check it into the repository.

**Acceptance:** the validated local ROM generates both documented AIZ tile atlases and displays the primary atlas in Godot; the output remains outside the repository.

**Current evidence:** the compatibility screen builds/displays the primary AIZ intro tile atlas and caches both atlases locally. KosinskiM outputs match reference hashes. Palette-line assignment in a rendered level is not part of this proof.

### 1F — Make local imports repeatable · Complete

**Tasks:**

- Define a versioned JSON cache manifest with schema version, importer version, profile ID, source SHA-256, output list, and output hashes.
- Key caches by source fingerprint and importer/schema version so changed ROMs or decoders cannot silently reuse stale output.
- Validate cached output on load and regenerate only when absent, stale, or corrupt.
- Write imports transactionally to a temporary local directory, then publish the completed cache so interrupted imports do not look successful.
- Keep absolute source paths, ROM bytes, and decoded game data out of the manifest and Git.
- Validate manifest schema and every indexed output's existence, size, and hash before the cache is considered usable.
- Publish by completing and validating a temporary cache first, then swapping it into place; retain/restore the previous cache if publication fails.
- Make cache cleanup list the resolved target before deletion and scope deletion strictly to this application's import root.

**Acceptance:** importing the same source twice yields the same manifest and output hashes; interrupted/corrupt caches are detected and safely rebuilt; Git status remains free of local ROM and cache files.

### 1G — Confirm boundaries and handoff · Complete

**Tasks:**

- Document which data the importer supplies and which behavior belongs to the remaster runtime.
- Record supported profile(s), known gaps, decoder limitations, and remaining investigation risks.
- Identify the next campaign extraction increments based on the format catalog.

**Acceptance:** the runtime boundary and remaining extraction work are clear; Phase 2 can start the movement prototype without depending on character animation or full-level extraction. Those resources are required later for the vertical slice and full-campaign phases.

## Phase exit checklist

- [x] Intake UI accepts the known supported input and reports unsupported/corrupt inputs clearly.
- [x] The local cache is versioned, validated, deterministic, recoverable, and excluded from Git.
- [x] AIZ primary/secondary tile art and palette decode from the ROM, generate atlases, and display in Godot.
- [x] The import path is documented well enough to add resources and verified ROM profiles incrementally.
- [x] No ROM execution, source ROM, generated game data, or local user paths are present in repository content/history from this phase.
- [x] Phase 1 findings and implementation checkpoint are committed to the project's GitHub repository.

**Phase 1 acceptance checks:** `test_rom_data_decoder.gd` covers synthetic tile/palette/KosinskiM inputs; `test_rom_inspector.gd` checks unsupported type/size/profile, corrupt ZIP, and ambiguous ZIP failures; `test_local_aiz_import.gd` validates the supplied profile, exercises import-screen success/rejection states, verifies generated resource hashes and manifest privacy, reuses the cache, repairs a corrupted output, and checks deterministic rebuilds. All checks passed with the supplied local ZIP. Generated atlases/manifest are in Godot `user://` data only.

**Handoff:** Phase 1 is complete. Character animation extraction, level-layout reconstruction, objects/events, and full-campaign resource coverage belong to the later vertical-slice and full-campaign stages in [ROADMAP.md](ROADMAP.md), not Phase 1 or the movement prototype.

## Explicitly deferred from Phase 1

- Full-campaign extraction or broad revision/region support.
- Gameplay implementation, emulator behavior, 68000 execution, or ROM patching.
- Character animation extraction, full level reconstruction, object/event mapping, audio, and scripted encounter recreation (vertical-slice/full-campaign phases).
- Public distribution of ROM-derived assets or caches.
- Editor, mod marketplace, general-purpose asset-pack format, save system, and release packaging.

These remain later-stage work unless the project scope is deliberately revised.
