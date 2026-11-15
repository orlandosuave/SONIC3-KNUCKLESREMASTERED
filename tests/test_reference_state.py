import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from inspect_reference_state import state_vram, VRAM_OFFSET
from analyze_reference_sequence import changed_units


class StateTests(unittest.TestCase):
    def test_changed_units_preserve_indices(self):
        self.assertEqual(changed_units(b"abcdefgh", b"abcXefYh", 2), [1, 3])
        self.assertEqual(changed_units(b"abcd", b"abcd", 2), [])
        with self.assertRaises(ValueError):
            changed_units(b"abc", b"abc", 2)
        with self.assertRaises(ValueError):
            changed_units(b"abcd", b"ab", 2)

    def test_profile_ram_identity_and_word_order(self):
        state = bytearray(VRAM_OFFSET+65536)
        state[:16] = b"GENPLUS-GX 1.7.6"
        state[VRAM_OFFSET:VRAM_OFFSET+2] = b"\x34\x12"
        self.assertEqual(state_vram(state, bytes(65536))[:2], b"\x12\x34")
        with self.assertRaises(ValueError):
            state_vram(state, bytes([1])*65536)
        with self.assertRaises(ValueError):
            state_vram(state[:VRAM_OFFSET], bytes(65536))


if __name__ == "__main__":
    unittest.main()
