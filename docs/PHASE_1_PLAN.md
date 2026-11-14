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
2. **Prove one format at a time (1D):** write down source ranges and decode recipes before writing decoders. Start with the smallest graphics/layout structures that can be displayed; record unknowns instead of silently guessing.
3. **Create the local data contract (1F):** define the manifest and cache layout before output generation so decoders target stable named resources.
4. **Build the vertical proof (1E):** import the minimum player, zone, and level data set and load it through normal Godot resources in a debug scene.
5. **Close the handoff (1G):** record what the slice proves, gaps, and the next extraction increments. Only then mark Stage 1 complete.

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
  player/...
  zones/<zone-id>/...
  levels/<level-id>/...
```

All paths stored in the manifest are relative to that cache root. The manifest indexes resource IDs, resource type, relative path, dimensions/counts where applicable, and SHA-256 of each generated file. Never serialize Godot absolute `user://` paths into the manifest.

## Proof-set scope

Keep the first proof set deliberately small and named in the format notes before implementation. It consists of:

- One playable character's minimum idle/run/jump visual frames, plus only the frame/animation mapping needed to preview them.
- One zone's minimum terrain tile graphics and palette needed for a faithful static palette preview.
- One compact level's tile/chunk layout and placement references needed to render a non-interactive map preview.

This proof does not include complete character animation coverage, object behavior, collision physics, music/audio, boss scripts, special stages, or every campaign route. The test scene may use placeholders for runtime behavior and should label imported data versus project-authored preview UI.

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

### 1C — Add the intake experience · In progress

**Tasks:**

- Add a startup/import screen with file picker and drag/drop support.
- Keep the existing inspector as the single validation authority; the UI should format its structured result rather than duplicate hash/header rules.
- Show detected image profile, size, and validation result before import proceeds.
- Explain wrong file type, archive ambiguity, wrong size, unsupported hash/profile, and unreadable file errors in plain language.
- Offer a local data folder under Godot `user://` and a way to inspect or clear generated cache without touching the source ROM.
- Make cache clearing explicit and scoped to this game's generated data; never offer a control that deletes or relocates a selected source ROM.
- Preserve the last valid import if a new selection is unsupported or an import fails.

**Acceptance:** a user can select or drop the provided ZIP and see a clear success result; invalid and ambiguous inputs fail without crashing or changing the source file.

**Checkpoint:** the first screen implementation is in `scenes/main.tscn` and `scripts/ui/import_screen.gd`. It includes file selection/drop, inspector-backed validation, local data folder access, and explicit generated-cache clearing. Interactive acceptance remains pending a Godot run with the supplied ROM and invalid-input examples; the import action is intentionally not wired until decoder/cache work exists.

### 1D — Map ROM data structures · Not started

**Tasks:**

- Create a format catalog for the proof set: ROM location, byte layout, compression/packing method, dimensions/counts, references, and decoder status.
- Identify one character's sprite/tile source and animation/frame mapping.
- Identify one zone's tile graphics and palette source.
- Identify one compact level's layout representation and object placement references.
- Record uncertain offsets/formats as hypotheses until checked against decoded output; avoid hard-coding unexplained offsets in gameplay code.
- For each structure, record endianness, pointer base, compression type, alignment, bounds checks, known references, and any assumptions about the selected profile.
- Define stable internal resource IDs and a minimal serialized representation before decoder output becomes a runtime dependency.

**Output:** a short `docs/ROM_FORMAT_NOTES.md` plus decoder fixtures/metadata that contain no ROM byte dumps or extracted proprietary assets.

**Acceptance:** each proof resource has a traceable ROM source range and a documented decode procedure; unresolved structures are clearly marked.

### 1E — Decode and load a proof set · Not started

**Tasks:**

- Decode one player's minimum useful sprite and animation set.
- Decode one zone's graphics and palette into Godot-ready local resources.
- Decode one compact level layout and the references needed to display its terrain/object placements.
- Load and preview these resources in a Godot proof scene using the project's data model.
- Keep decoder code separate from UI and gameplay code; parsers should accept byte arrays plus explicit bounds and return typed data/errors.
- Reject out-of-range pointers, impossible dimensions/counts, truncated streams, and decompression overflow with actionable import errors.
- Provide a developer-only reimport action so parser changes can regenerate the proof set without clearing unrelated user data.
- Keep decoded output in local user data; do not check it into the repository.

**Acceptance:** a developer can see the imported character frames, zone art with correct palette, and a level layout in Godot, all generated from the selected local ROM through the documented path.

### 1F — Make local imports repeatable · Not started

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

### 1G — Confirm boundaries and handoff · Not started

**Tasks:**

- Document which data the importer supplies and which behavior belongs to the remaster runtime.
- Record supported profile(s), known gaps, decoder limitations, and remaining investigation risks.
- Identify the next campaign extraction increments based on the format catalog.

**Acceptance:** the runtime consumes decoded data as resources and implements gameplay itself; the next phase can start movement work without depending on a full-campaign decoder.

## Phase exit checklist

- [ ] Intake UI accepts the known supported input and reports unsupported/corrupt inputs clearly.
- [ ] The local cache is versioned, validated, deterministic, recoverable, and excluded from Git.
- [ ] Character, zone, and compact-level proof resources decode from the ROM and display in Godot.
- [ ] The import path is documented well enough to add resources and verified ROM profiles incrementally.
- [ ] No ROM execution, source ROM, generated game data, or local user paths are present in repository content/history from this phase.
- [ ] Phase 1 findings and implementation checkpoint are committed to the project's GitHub repository.

## Explicitly deferred from Phase 1

- Full-campaign extraction or broad revision/region support.
- Gameplay implementation, emulator behavior, 68000 execution, or ROM patching.
- Reconstructing every animation, object, event, audio track, or scripted encounter.
- Public distribution of ROM-derived assets or caches.
- Editor, mod marketplace, general-purpose asset-pack format, save system, and release packaging.

These remain later-stage work unless the project scope is deliberately revised.
