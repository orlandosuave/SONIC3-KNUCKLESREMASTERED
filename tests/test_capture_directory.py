"""Verify capture rejects overwrite before loading a ROM or emulator core."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class CaptureDirectoryTests(unittest.TestCase):
    def test_existing_run_is_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            run = Path(folder) / "S3KRemastered/research/reference/existing"
            run.mkdir(parents=True)
            sentinel = run / "capture.json"
            sentinel.write_text("original evidence")
            env = dict(os.environ, LOCALAPPDATA=folder)
            script = Path(__file__).resolve().parents[1] / "tools/capture_reference.py"
            result = subprocess.run([sys.executable, str(script), "missing-rom.bin", "--run", "existing"],
                                    env=env, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 2)
            self.assertIn("Run directory already exists", result.stderr)
            self.assertEqual(sentinel.read_text(), "original evidence")


if __name__ == "__main__": unittest.main()
