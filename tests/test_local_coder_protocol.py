import json
import tempfile
import subprocess
import unittest
from pathlib import Path

from tools.local_coder_protocol import (
    build_context_pack,
    make_escalation_packet,
    validate_receipt,
    validate_task,
)


class LocalCoderProtocolTests(unittest.TestCase):
    def test_context_pack_is_scoped_and_hashed(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw) / "repo"
            root.mkdir()
            (root / "docs").mkdir()
            (root / "docs/a.md").write_text("ROM authority\n", encoding="utf-8")
            task = {"task_id": "t1", "base_commit": "a" * 40, "goal": "test",
                    "allowed_files": ["docs/a.md"], "context": [{"path": "docs/a.md", "role": "scope"}],
                    "checks": ["python -m unittest"]}
            subprocess.run(["git", "init", str(root)], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "-c", "user.name=Protocol Test", "-c", "user.email=test@localhost", "commit", "-m", "fixture"], check=True, capture_output=True)
            task["base_commit"] = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
            (root / "docs/a.md").write_text("uncommitted change", encoding="utf-8")
            out = Path(raw) / "pack"
            pack = build_context_pack(task, root, out)
            self.assertEqual(pack["source_files"][0]["path"], "docs/a.md")
            self.assertTrue((out / "context-pack.json").is_file())
            self.assertEqual((out / "docs/a.md").read_text(encoding="utf-8"), "ROM authority\n")

    def test_receipt_rejects_out_of_scope_change(self):
        task = {"task_id": "t1", "base_commit": "a" * 40, "goal": "test",
                "allowed_files": ["a.py"], "context": ["a.py"], "checks": ["pytest"]}
        receipt = {"task_id": "t1", "base_commit": "a" * 40, "status": "verified",
                   "changed_files": ["b.py"], "checks": [], "limitations": []}
        self.assertIn("changed file outside allowlist", validate_receipt(receipt, task))

    def test_escalation_requires_blocked_status_and_owner_approval(self):
        task = {"task_id": "t1", "base_commit": "a" * 40}
        receipt = {"task_id": "t1", "status": "quarantined", "attempts": ["failed test"],
                   "changed_files": [], "checks": [], "limitations": ["unclear ROM behavior"]}
        with tempfile.TemporaryDirectory() as raw:
            packet = make_escalation_packet(task, receipt, "Repeated failure", Path(raw) / "e.json")
            self.assertTrue(packet["approval_required"])
            self.assertEqual(json.loads((Path(raw) / "e.json").read_text())["status"], "escalation_pending")

    def test_rejects_windows_and_context_escapes(self):
        base = {"task_id":"t", "base_commit":"a"*40, "goal":"test", "allowed_files":["a.py"], "context":["a.py"], "checks":["unit"]}
        for path in ["C:/outside.py", "C:relative.py", "../outside.py", "//server/share", "a:stream", "NUL", "folder/../a.py"]:
            with self.subTest(path=path):
                self.assertTrue(validate_task({**base, "allowed_files":[path]}))
                self.assertTrue(validate_task({**base, "context":[path]}))

    def test_rejects_unproven_acceptance(self):
        task = {"task_id":"t", "base_commit":"a"*40, "goal":"test", "allowed_files":["a.py"], "context":["a.py"], "checks":["unit"]}
        receipt = {"task_id":"t", "base_commit":"b"*40, "status":"accepted", "changed_files":[], "checks":[], "limitations":[]}
        errors = validate_receipt(receipt, task)
        self.assertIn("base_commit mismatch", errors)
        self.assertIn("required check failed or missing: unit", errors)
        self.assertIn("independent review required", errors)

    def test_malformed_types_fail_closed(self):
        self.assertTrue(validate_task({"allowed_files":None, "context":42, "checks":{}}))

if __name__ == "__main__":
    unittest.main()
