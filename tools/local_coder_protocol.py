"""Portable task, context-pack, receipt, and escalation protocol for the local coder.

This module is intentionally model-agnostic. It does not launch agents, edit the
main checkout, merge, push, or make ROM-fidelity claims. It only validates and
materializes bounded work requests.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PureWindowsPath
import re
import subprocess
from typing import Any


PROTOCOL_VERSION = 1
TERMINAL_STATUSES = {"accepted", "rejected", "quarantined", "escalation_pending"}
ALLOWED_STATUSES = {"queued", "running", "review", "verified", *TERMINAL_STATUSES}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def safe_relative(value: Any) -> bool:
    if not isinstance(value, str) or not value or "\\" in value:
        return False
    win = PureWindowsPath(value)
    return not (win.drive or win.root or ":" in value or value.startswith("/")) and all(
        part not in ("", ".", "..") and not part.endswith((" ", "."))
        and not PureWindowsPath(part).is_reserved() for part in value.split("/"))


def validate_task(task: dict[str, Any]) -> list[str]:
    if not isinstance(task, dict): return ["task must be an object"]
    errors = []
    for key in ("task_id", "goal"):
        if not isinstance(task.get(key), str) or not task[key].strip(): errors.append(f"invalid:{key}")
    if not isinstance(task.get("base_commit"), str) or not re.fullmatch(r"[0-9a-f]{40}", task["base_commit"]):
        errors.append("base_commit must be a full Git SHA")
    allowed = task.get("allowed_files")
    if not isinstance(allowed, list) or not allowed or not all(safe_relative(p) for p in allowed):
        errors.append("allowed_files contains unsafe path or is empty")
    elif len({p.casefold() for p in allowed}) != len(allowed): errors.append("duplicate allowed path")
    context = task.get("context")
    if not isinstance(context, list) or not context:
        errors.append("context must be a non-empty list")
    else:
        paths = [x.get("path") if isinstance(x, dict) else x for x in context]
        if not all(safe_relative(p) for p in paths): errors.append("context contains unsafe path")
        elif any(p.casefold() == "context-pack.json" for p in paths): errors.append("reserved context pack path")
        elif len({p.casefold() for p in paths}) != len(paths): errors.append("duplicate context path")
    checks = task.get("checks")
    if not isinstance(checks, list) or not checks or not all(isinstance(c, str) and c.strip() for c in checks):
        errors.append("checks must contain required check IDs")
    elif len(set(checks)) != len(checks): errors.append("duplicate check ID")
    if not isinstance(task.get("status", "queued"), str) or task.get("status", "queued") not in ALLOWED_STATUSES:
        errors.append("invalid task status")
    return errors


def build_context_pack(task: dict[str, Any], repo_root: Path, output_dir: Path) -> dict[str, Any]:
    """Export pinned Git blobs, never mutable working files, into a new pack."""
    errors = validate_task(task)
    if errors: raise ValueError("invalid task: " + ", ".join(errors))
    root = repo_root.resolve(strict=True)
    def git(*args):
        return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.PIPE)
    pinned = git("rev-parse", task["base_commit"] + "^{commit}").decode().strip()
    if pinned != task["base_commit"]: raise ValueError("base commit mismatch")
    prepared = []
    for entry in task["context"]:
        rel = entry["path"] if isinstance(entry, dict) else entry
        resolved = (root / rel).resolve()
        if not resolved.is_relative_to(root): raise ValueError("context escapes repository")
        tree = git("ls-tree", pinned, "--", rel).decode().strip()
        if not tree or tree.split()[0] not in ("100644", "100755"):
            raise ValueError("Context must be a tracked regular file: " + rel)
        data = git("show", pinned + ":" + rel)
        prepared.append((rel, data, entry.get("role", "context") if isinstance(entry, dict) else "context"))
    destination = output_dir.resolve()
    if destination.is_relative_to(root): raise ValueError("Pack must be outside the source checkout")
    output_dir.mkdir(parents=True, exist_ok=False)
    files = []
    for rel, data, role in prepared:
        dst = output_dir / rel
        if not dst.resolve().is_relative_to(destination): raise ValueError("output escapes pack")
        dst.parent.mkdir(parents=True, exist_ok=True)
        with dst.open("xb") as stream: stream.write(data)
        files.append({"path": rel, "sha256": sha256_bytes(data), "bytes": len(data), "role": role})
    header = {"protocol_version": PROTOCOL_VERSION, "task": task, "source_files": files,
              "instructions": {"rom_authority": "ROM and captured evidence outrank assumptions.",
                               "no_completion_claims": "Tests passed is not reference parity.",
                               "escalation": "Pause for owner approval; no automatic escalation."}}
    (output_dir / "context-pack.json").write_text(json.dumps(header, indent=2) + "\n", encoding="utf-8")
    return header


def validate_receipt(receipt: dict[str, Any], task: dict[str, Any]) -> list[str]:
    errors = validate_task(task)
    if errors: return errors
    if not isinstance(receipt, dict): return errors + ["receipt must be an object"]
    for key in ("task_id", "base_commit", "status", "changed_files", "checks", "limitations"):
        if key not in receipt: errors.append(f"missing:{key}")
    if receipt.get("task_id") != task.get("task_id"): errors.append("task_id mismatch")
    if receipt.get("base_commit") != task.get("base_commit"): errors.append("base_commit mismatch")
    changed = receipt.get("changed_files")
    allowed = task.get("allowed_files") if isinstance(task.get("allowed_files"), list) else []
    if not isinstance(changed, list) or any(not safe_relative(p) or p not in allowed for p in changed):
        errors.append("changed file outside allowlist")
    status = receipt.get("status")
    if not isinstance(status, str) or status not in ALLOWED_STATUSES: errors.append("invalid receipt status")
    if not isinstance(receipt.get("limitations"), list): errors.append("limitations must be a list")
    checks = receipt.get("checks")
    if not isinstance(checks, list): errors.append("checks must be a list")
    if status in ("verified", "accepted"):
        by_id = {}
        for check in checks if isinstance(checks, list) else []:
            if not isinstance(check, dict) or not isinstance(check.get("id"), str):
                errors.append("invalid check receipt"); continue
            if check["id"] in by_id: errors.append("duplicate check receipt")
            by_id[check["id"]] = check
        for required in task.get("checks", []):
            check = by_id.get(required, {})
            if check.get("passed") is not True or type(check.get("exit_code")) is not int or check["exit_code"] != 0:
                errors.append("required check failed or missing: " + str(required))
            if not isinstance(check.get("evidence_sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", check["evidence_sha256"]):
                errors.append("missing evidence hash: " + str(required))
        if receipt.get("independent_review") != "passed": errors.append("independent review required")
    return errors


def make_escalation_packet(task: dict[str, Any], receipt: dict[str, Any], reason: str,
                           output_path: Path) -> dict[str, Any]:
    if receipt.get("status") not in {"rejected", "quarantined", "escalation_pending"}:
        raise ValueError("only blocked or failed work can escalate")
    packet = {
        "protocol_version": PROTOCOL_VERSION,
        "type": "human_escalation_request",
        "approval_required": True,
        "task_id": task["task_id"],
        "base_commit": task.get("base_commit"),
        "reason": reason,
        "attempts": receipt.get("attempts", []),
        "changed_files": receipt.get("changed_files", []),
        "checks": receipt.get("checks", []),
        "limitations": receipt.get("limitations", []),
        "question_for_codex": receipt.get("question_for_codex", "What is the smallest safe next step?"),
        "status": "escalation_pending",
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(packet, indent=2) + "\n", encoding="utf-8")
    return packet
