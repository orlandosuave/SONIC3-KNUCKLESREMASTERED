import sys
from pathlib import Path
import unittest
import struct

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from aiz_palette import cycle_step, water_scanline_palettes


class PaletteTests(unittest.TestCase):
    def test_latched_interrupt_and_live_transfer_limit(self):
        rom = bytearray(0xA8D1C)
        struct.pack_into(">64H", rom, 0xA8C9C, *range(64))
        struct.pack_into(">5H", rom, 0x74E0, 3, 2, 8, 14, 20)
        rows = water_scanline_palettes(rom, [999]*64, 219, transfer_counter=199)
        self.assertEqual(rows[219], [999]*64)
        self.assertEqual(rows[220][1:4], [1, 2, 3])
        self.assertEqual(rows[222][10], 999)
        self.assertEqual(rows[223][10:13], [10, 11, 12])
        self.assertEqual(water_scanline_palettes(rom, [999]*64, 219)[223], [999]*64)

    def test_eight_tick_interval_and_wrap(self):
        state = (0, 0xFFF8, 42)
        timer, water, sparkle, upload = cycle_step(*state)
        self.assertEqual((timer, water, sparkle, upload), (7, 0, 0, (24, 42)))
        for _ in range(7):
            timer, water, sparkle, upload = cycle_step(timer, water, sparkle)
            self.assertIsNone(upload)
        self.assertEqual(cycle_step(timer, water, sparkle), (7, 8, 6, (0, 0)))

    def test_disabled_sparkles_hold_counter(self):
        self.assertEqual(cycle_step(0, 8, 18, True), (7, 16, 18, (8, None)))


if __name__ == "__main__":
    unittest.main()
