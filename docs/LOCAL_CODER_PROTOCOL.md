# Local coder operating protocol

This project uses the local coder as a bounded subordinate worker. The supplied
ROM remains the fidelity authority. The local coder may implement and verify
small tasks, but it may not choose project direction, claim ROM parity, merge,
push, reset, clean, or modify the protected main checkout.

## Execution loop

1. A task is approved and pinned to a base commit.
2. `tools/local_coder_protocol.py` (or an equivalent runner) creates a context
   pack containing only declared files and mission constraints.
3. The coder runs in a disposable worktree with an allowlist.
4. The coder returns a structured receipt.
5. An independent reviewer and the declared Godot/Python/reference checks run.
6. The result is accepted, rejected, or quarantined.
7. After bounded retries, the task becomes `escalation_pending` and pauses.

## Escalation rule

Escalation to Codex is never automatic. A blocked task must produce a JSON
escalation packet and notify the owner. The owner explicitly approves sending
that packet to Codex. Until approval, no Codex invocation, merge, push, or scope
expansion is allowed.

Escalate for architecture, conflicting ROM evidence, repeated failed repairs,
multi-subsystem changes, gameplay route progression, parity claims, missing
source data, or any request affecting the main branch.

## Evidence vocabulary

`tests_passed` means the declared tests passed. `reference_parity_proven` means
independent ROM/reference evidence established parity. These are separate fields;
one must never be inferred from the other. `integration_eligible` is true only
after scope, review, and required checks pass.

## Implemented validation (2026-11-21)

Tasks require a full pinned Git commit, a bounded safe path list and nonempty
check IDs. Windows drive paths, traversal, duplicate paths, symlink Git entries
and reserved pack filenames are rejected. Context packs export committed blobs,
not mutable working files, to a new directory outside the source checkout.

Verified/accepted receipts must match the task and commit, report every required
check with exit code zero, an evidence SHA-256, and an independent review result.
This validator checks structure, not the truth of worker claims. The trusted
runner must independently execute checks, compare the actual diff to the
allowlist, hash its own logs and perform review before accepting work. A worker
receipt alone never authorizes merging or a parity claim. Regression command:
`python -B -m unittest discover -s tests -p test_local_coder_protocol.py`.
