import sys
from pathlib import Path
import struct
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from aiz_scroll import normal_scroll, intro_scroll, line_offsets


class ScrollTests(unittest.TestCase):
    def test_normal_scales_and_phase(self):
        model = normal_scroll(0x1320, 225, 0)
        self.assertEqual(model["background_y"], 112)
        self.assertEqual(model["scroll_words"][0x30], 14)
        self.assertEqual(model["scroll_words"][0x36], 20)
        self.assertEqual(model["next_phase"], 0x2000)
        self.assertEqual(normal_scroll(0x1300, 0, 0x10000)["scroll_words"][8], 6)

    def test_intro_boundary_and_negative_event_override(self):
        self.assertEqual(set(intro_scroll(0xB00, 0)["scroll_words"].values()), {0x580})
        self.assertEqual(intro_scroll(100, 42, 0xFFFE)["scroll_words"][0x28], -1)
        self.assertEqual(intro_scroll(100, 42, 0xFFFE)["draw_bands"][0], 0)
        self.assertEqual(normal_scroll(0x12FF, 0)["scroll_words"][0x14], -1)

    def test_band_expansion_and_per_line_section(self):
        image = bytearray(0x23B258+28)
        struct.pack_into(">14H", image, 0x23B258, 2, 0x8003, 0x7FFF, *([0]*11))
        model = {"background_y": 1, "scroll_words": {8: 10, 10: 20, 12: 30, 14: 40, 16: 50}}
        self.assertEqual(line_offsets(image, model, height=5), [10, 20, 30, 40, 50])


if __name__ == "__main__":
    unittest.main()
