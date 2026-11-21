# Phase 4 local microtask workflow

Updated 2026-11-21. The owner reports starting a web-chat-administered local coding session.

## Ownership and execution
Local Qwen codes, local Gemma reviews, and independent Godot checks validate. GPT web chat plus Desktop Commander administers dispatch and evidence review. Codex maintains and improves the system; Codex desktop is not required for execution. The local suite can use Codex CLI configured with --oss --local-provider ollama.

## Current batch
The local backlog at D:\AI\SonicPhase4Queue contains 24 dependency-ordered items: collision input guards, incremental right-wall sample/distance helpers, terrain input guards, synthetic regression coverage and evidence-ledger updates. This is a bounded contribution to Phase 4B/4C, not a breakdown or completion of the entire phase.

Target one function/helper in one file, usually 10–40 changed lines, 3–6 focused checks, <=6,000 estimated input tokens and at most three coding attempts. These conservative targets reflect existing runner limits and pilot evidence; adjust using observed results.

## Progress and evidence
At the documentation inspection, the ledger recorded 24 queued, zero accepted and zero blocked items. The session start is owner-reported; no new adapter qualification or completed task was independently established. Current progress belongs in local queue receipts, not inferred from this dated document.

queue.py is an operator ledger. The separate WebChatHandoff Python consumer does not automatically execute these Sonic tasks. Inspect the active session before preparing additional runners to avoid duplicate work.

Use isolated codex/ branches, exact task/source hashes, independent checks, bounded repairs and the shared GPU lease. Accepting a task requires reviewed evidence and candidate/base commits. Changes from different chains sharing a file need reconciliation and retesting before integration. Local acceptance is not a merge or push.

Continue independent runnable work while other items await review; stop when no runnable work remains and distinguish completion from blocking. No separate owner trigger is needed for each successful item.

ROM and derived assets remain local. Do not repeat full ROM verification for every microtask. Synthetic/source-informed tests do not establish exact ROM parity. This batch does not close G0/G1 or implement left/ceiling probes, player integration or a full act.

## Local operator entry points
- D:\AI\SonicPhase4Queue\START_HERE.md
- D:\AI\SonicPhase4Queue\SIZING.md
- D:\AI\SonicPhase4Queue\SESSION_STATUS.md
- D:\AI\WebChatHandoff\OPERATING_ROLES.md

The product scope remains in [Phase 4 plan](PHASE_4_PLAN.md); coverage remains in [content audit](PHASE_4_CONTENT_AUDIT.md).
