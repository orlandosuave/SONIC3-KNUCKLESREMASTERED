# Phase 1 — ROM Intake and Data Feasibility

Phase 1 proves the path from the user's Sonic 3 & Knuckles ROM to local game data used by the remaster. It is a focused feasibility slice, not a full-campaign extraction milestone.

## Product boundary

- The supplied ROM is the source of original game data for the remaster: graphics, palettes, animation data, layouts, object placements, and other structures as the importer supports them.
- The Godot project provides its own runtime, simulation, presentation, and game systems. Phase 1 does not execute the ROM as an emulator.
- The ROM and imported outputs stay in local user data and are never committed, attached to public issues, or included in public builds.
- The first profile is the exact locally inspected 4 MiB combined lock-on image described in [ROM_IMPORT_SPEC.md](ROM_IMPORT_SPEC.md). The implementation should allow adding more verified revisions/regions later; this first profile is a starting point, not the final compatibility policy.

## Work packages

### 1A — Identify the first input profile · Complete

**Output:** [ROM_IMPORT_SPEC.md](ROM_IMPORT_SPEC.md), containing the ZIP/member layout, uncompressed size, per-image headers, region fields, and source fingerprint.

**Acceptance:** the exact supplied image can be distinguished from unsupported images using documented, reproducible metadata. Do not claim support for uninspected revisions based only on a similar filename or header.

### 1B — Implement an intake inspector · Complete

**Output:** `scripts/rom/rom_inspector.gd`, a reusable check for the supported raw `.md` file or ZIP form.

**Acceptance:** reports structured success data or a user-facing reason for failure; reads source data without modifying or extracting it; never writes source bytes to the checkout.

### 1C — Add the intake experience · Not started

**Tasks:**

- Add a startup/import screen with file picker and drag/drop support.
- Show detected image profile, size, and validation result before import proceeds.
- Explain wrong file type, archive ambiguity, wrong size, unsupported hash/profile, and unreadable file errors in plain language.
- Offer a local data folder under Godot `user://` and a way to inspect or clear generated cache without touching the source ROM.

**Acceptance:** a user can select or drop the provided ZIP and see a clear success result; invalid and ambiguous inputs fail without crashing or changing the source file.

### 1D — Map ROM data structures · Not started

**Tasks:**

- Create a format catalog for the proof set: ROM location, byte layout, compression/packing method, dimensions/counts, references, and decoder status.
- Identify one character's sprite/tile source and animation/frame mapping.
- Identify one zone's tile graphics and palette source.
- Identify one compact level's layout representation and object placement references.
- Record uncertain offsets/formats as hypotheses until checked against decoded output; avoid hard-coding unexplained offsets in gameplay code.

**Output:** a short `docs/ROM_FORMAT_NOTES.md` plus decoder fixtures/metadata that contain no ROM byte dumps or extracted proprietary assets.

**Acceptance:** each proof resource has a traceable ROM source range and a documented decode procedure; unresolved structures are clearly marked.

### 1E — Decode and load a proof set · Not started

**Tasks:**

- Decode one player's minimum useful sprite and animation set.
- Decode one zone's graphics and palette into Godot-ready local resources.
- Decode one compact level layout and the references needed to display its terrain/object placements.
- Load and preview these resources in a Godot proof scene using the project's data model.
- Keep decoded output in local user data; do not check it into the repository.

**Acceptance:** a developer can see the imported character frames, zone art with correct palette, and a level layout in Godot, all generated from the selected local ROM through the documented path.

### 1F — Make local imports repeatable · Not started

**Tasks:**

- Define a versioned JSON cache manifest with schema version, importer version, profile ID, source SHA-256, output list, and output hashes.
- Key caches by source fingerprint and importer/schema version so changed ROMs or decoders cannot silently reuse stale output.
- Validate cached output on load and regenerate only when absent, stale, or corrupt.
- Write imports transactionally to a temporary local directory, then publish the completed cache so interrupted imports do not look successful.
- Keep absolute source paths, ROM bytes, and decoded game data out of the manifest and Git.

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
