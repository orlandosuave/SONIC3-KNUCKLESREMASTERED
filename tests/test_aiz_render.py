import sys
from pathlib import Path
import unittest
import struct

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from render_aiz_preview import tile_image, palette, compose_planes, aiz1_animation_uploads
from PIL import Image


class RenderTests(unittest.TestCase):
    def test_animation_uses_previous_frame_and_script_stride(self):
        source = bytearray(0x29000)
        cursor = 0x28752
        for duration, entries in ((255, b"\x00\x09\x01\x03"),
                                  (3, b"\x00\x01"),
                                  (255, b"\x00\x07\x01\x05")):
            struct.pack_into(">IHBB", source, cursor, (duration << 24) | 0x100, 0x400, 2, 1)
            source[cursor+8:cursor+8+len(entries)] = entries
            cursor += 8+len(entries)
        source[0x100:0x120] = bytes([17])*32
        source[0x120:0x140] = bytes([34])*32
        uploads = aiz1_animation_uploads(source, [0x1502, 0x0901, 0x0102])
        self.assertEqual(uploads, [(32, bytes([34])*32), (32, bytes([17])*32),
                                   (32, bytes([34])*32)])
        with self.assertRaises(ValueError):
            aiz1_animation_uploads(source, [0, 1, 1])

    def test_priority_order_and_transparent_pixels(self):
        bg_low = Image.new("RGBA", (2, 1), (255, 0, 0, 255))
        fg_low = Image.new("RGBA", (2, 1), (0, 255, 0, 255))
        bg_high = Image.new("RGBA", (2, 1), (0, 0, 255, 255))
        fg_high = Image.new("RGBA", (2, 1))
        fg_high.putpixel((1, 0), (255, 255, 0, 255))
        result = compose_planes(bg_low, fg_low, bg_high, fg_high)
        self.assertEqual(result.getpixel((0, 0)), (0, 0, 255, 255))
        self.assertEqual(result.getpixel((1, 0)), (255, 255, 0, 255))
        with self.assertRaises(ValueError):
            compose_planes(bg_low, fg_low, bg_high, Image.new("RGBA", (1, 1)))
    def test_nibble_order_palette_line_and_transparency(self):
        colors = [(i, 0, 0) for i in range(64)]
        tile = tile_image(bytes([0x12, 0x03] + [0]*30), colors, 2)
        self.assertEqual(tile.getpixel((0, 0)), (33, 0, 0, 255))
        self.assertEqual(tile.getpixel((1, 0)), (34, 0, 0, 255))
        self.assertEqual(tile.getpixel((2, 0))[3], 0)
        self.assertEqual(tile.getpixel((3, 0)), (35, 0, 0, 255))

    def test_palette_combines_character_and_level_lines(self):
        source = bytearray(0x400000)
        source[0x28C234:0x28C236] = b"\x00\x0e"
        source[0x28C374:0x28C376] = b"\x0e\x00"
        colors = palette(source, "main")
        self.assertEqual(colors[0], (255, 0, 0))
        self.assertEqual(colors[16], (0, 0, 255))
        self.assertEqual(len(colors), 64)


if __name__ == "__main__":
    unittest.main()
