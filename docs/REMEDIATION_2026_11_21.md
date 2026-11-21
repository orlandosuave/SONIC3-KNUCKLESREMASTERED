Sonic game and local coder — verified state, 2026-11-21
Scope
Phases 1–3 are prototype milestones: ROM intake, movement/collision sandbox, display/camera. Phase 4 remains in progress. The supplied ROM is the fidelity authority; passing synthetic tests does not establish exact ROM parity.
Implemented in this remediation
The local coder protocol validates pinned 40-character Git commits, safe Windows-relative allowlists, required checks and matching receipts. Context packs read committed Git blobs, reject symlink entries and reserved filenames, and never use mutable working files. Accepted receipts require check evidence hashes and an independent-review field. These are structural checks: the trusted runner must independently run checks and inspect diffs before acceptance.
Reference capture now uses a unique UTC run directory by default and refuses every existing run directory. Input traces and provenance remain in capture.json. Comparison commands must use the printed --run name. Existing historical captures are preserved.
Evidence
Six coder regression tests and 32 AIZ Python tests passed on November 21. The toolchain's separate lab gate passed, including 58 queue/lease regressions; candidate correctness and ROM parity are explicitly NOT_EVALUATED. Phoenix health failed separately. No new ROM capture or manual playtest was performed in this remediation.
Next acceptance gate
G1 is a small original-terrain playable section with flat ground, slope and path/layer case, through the real import flow. ROM terrain floor lookup is research infrastructure, not yet wired into the player. Wall/ceiling probes, loops, route completion, objects/events, audio and full-act parity remain open. Existing prototype scope must not be described as a completed remake.
Owning files
Game: C:\Users\orlan\OneDrive\Documents\ChatGPT\SONIC 3 & KNUCKLES REMASTERED. See docs/ROADMAP.md, PHASE_4_PLAN.md, PHASE_4_CONTENT_AUDIT.md, REFERENCE_CAPTURE.md and LOCAL_CODER_PROTOCOL.md. ROMs and generated reference data remain outside Git.
