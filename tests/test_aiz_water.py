import sys
import struct
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from aiz_scroll import water_line_offsets


class WaterTests(unittest.TestCase):
    def test_boundary_and_opposite_source_scroll_sign(self):
        rom = bytearray(0x240000)
        struct.pack_into(">14H", rom, 0x23B258, 0x7FFF, *([0]*13))
        struct.pack_into(">288h", rom, 0x23A170, *([1]*288))
        struct.pack_into(">288h", rom, 0x23A3B0, *([-2]*288))
        model = {"background_y": 100, "scroll_words": {8: 20}}
        fg, bg = water_line_offsets(rom, model, 300, 200, 420, 0xFFFF)
        self.assertEqual(fg[:220], [300]*220)
        self.assertEqual(bg[:220], [20]*220)
        self.assertEqual(fg[220:], [299]*4)
        self.assertEqual(bg[220:], [22]*4)
        fg, bg = water_line_offsets(rom, model, 300, 200, 424, 0)
        self.assertEqual((fg, bg), ([300]*224, [20]*224))
        with self.assertRaises(ValueError):
            water_line_offsets(rom, model, 300, 200, 199, 0)


if __name__ == "__main__":
    unittest.main()
