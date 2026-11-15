import struct
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from compare_aiz_reference import sprite_bounds


class SpriteBoundsTests(unittest.TestCase):
    def test_link_order_dimensions_and_offscreen_coordinates(self):
        ram = bytearray(65536)
        struct.pack_into("<4H", ram, 0xF800, 120, 0x0602, 0, 144)
        struct.pack_into("<4H", ram, 0xF810, 148, 0x0C00, 0, 124)
        self.assertEqual(sprite_bounds(ram), [(16, -8, 16, 24), (-4, 20, 32, 8)])

    def test_invalid_link_and_cycle_are_rejected(self):
        ram = bytearray(65536)
        struct.pack_into("<H", ram, 0xF802, 80)
        with self.assertRaises(ValueError):
            sprite_bounds(ram)
        struct.pack_into("<H", ram, 0xF802, 1)
        struct.pack_into("<H", ram, 0xF80A, 1)
        with self.assertRaises(ValueError):
            sprite_bounds(ram)


if __name__ == "__main__":
    unittest.main()
