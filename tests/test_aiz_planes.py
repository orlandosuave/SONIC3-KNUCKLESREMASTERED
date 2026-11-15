import struct
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from aiz_plane_history import apply_plane_commands


class PlaneTests(unittest.TestCase):
    def test_rows_columns_and_retained_cells(self):
        vram = bytearray([0xAA])*65536
        row = struct.pack(">7H", 0xC000, 0, 1, 2, 3, 4, 0)
        self.assertEqual(apply_plane_commands(vram, row), 4)
        self.assertEqual(struct.unpack_from(">2H", vram, 0xC000), (1, 2))
        self.assertEqual(struct.unpack_from(">2H", vram, 0xC080), (3, 4))
        self.assertEqual(vram[0xC004:0xC006], b"\xAA\xAA")
        column = struct.pack(">7H", 0xE000, 0x8000, 5, 6, 7, 8, 0)
        apply_plane_commands(vram, column)
        self.assertEqual(struct.unpack_from(">2H", vram, 0xE000), (5, 7))
        self.assertEqual(struct.unpack_from(">2H", vram, 0xE080), (6, 8))
        with self.assertRaises(ValueError):
            apply_plane_commands(vram, row[:-2])
        with self.assertRaises(ValueError):
            apply_plane_commands(vram, struct.pack(">7H", 0x1000, 0, 1, 2, 3, 4, 0))


if __name__ == "__main__":
    unittest.main()
