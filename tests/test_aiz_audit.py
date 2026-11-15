"""Synthetic audit fixtures: no original game content."""
import importlib.util
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location(
    "aiz_audit", Path(__file__).resolve().parents[1] / "tools/audit_aiz_content.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class PlacementAuditTests(unittest.TestCase):
    def test_preserves_original_order_and_flags(self):
        records = [(100, 0xA010, 1, 5), (90, 0x4020, 2, 3)]
        data = b"".join(struct.pack(">HHBB", *r) for r in records)
        parsed = audit.parse_placements(data + b"\xff\xff\x00\x00\x00\x00")
        self.assertEqual(parsed, records)
        self.assertEqual(audit.census(parsed)["x_order_descents"], 1)

    def test_rejects_truncated_missing_and_early_terminators(self):
        record = struct.pack(">HHBB", 12, 34, 1, 3)
        end = b"\xff\xff\x00\x00\x00\x00"
        for invalid in (b"", record[:-1], record, end + record):
            with self.subTest(data_length=len(invalid)):
                with self.assertRaises(ValueError):
                    audit.parse_placements(invalid)

    def test_counts_monitor_subtypes_without_counting_other_objects(self):
        result = audit.census([(0, 0, 1, 5), (1, 0, 2, 5), (2, 0, 1, 5)])
        self.assertEqual(result["monitor_subtype_counts"], {"05": 2})
        self.assertEqual(result["record_count"], 3)


class KosinskiAuditTests(unittest.TestCase):
    def test_literals_and_overlapping_matches(self):
        for stream, expected in (
            (bytes((0x41, 0, 65, 255, 0, 0, 0)), b"AAA"),
            (bytes((0x15, 0, 65, 255, 249, 0, 0, 0)), b"AAAA"),
            (bytes((0x15, 0, 65, 255, 248, 3, 0, 0, 0)), b"AAAAA"),
        ):
            with self.subTest(stream=stream):
                data, consumed = audit.decode_kosinski(stream)
                self.assertEqual(data, expected)
                self.assertEqual(consumed, len(stream))

    def test_eager_descriptor_reload(self):
        stream = b"\xff\xff" + b"A" * 15 + b"\x02\x00A\x00\x00\x00"
        self.assertEqual(audit.decode_kosinski(stream)[0], b"A" * 16)

    def test_noop_and_trailing_alignment(self):
        stream = bytes((10, 0, 0, 0, 1, 0, 0, 0, 99))
        self.assertEqual(audit.decode_kosinski(stream), (b"", 8))

    def test_rejects_truncation_backreference_and_limits(self):
        good = bytes((0x41, 0, 65, 255, 0, 0, 0))
        for length in range(len(good)):
            with self.subTest(length=length):
                with self.assertRaises(ValueError):
                    audit.decode_kosinski(good[:length])
        with self.assertRaises(ValueError):
            audit.decode_kosinski(bytes((0, 0, 255)))
        with self.assertRaises(ValueError):
            audit.decode_kosinski(good, output_limit=2)
        with self.assertRaises(ValueError):
            audit.decode_kosinski(bytes((10, 0, 0, 0, 1, 0, 0, 0)), command_limit=1)


class AttributeAuditTests(unittest.TestCase):
    def test_moduled_size_and_truncation(self):
        stream = bytes((0x41, 0, 65, 255, 0, 0, 0))
        self.assertEqual(audit.decode_moduled_kosinski(b"\x00\x03" + stream)[0], b"AAA")
        for source in (b"", b"\x00\x00" + stream, b"\x00\x04" + stream,
                       b"\x00\x02" + stream):
            with self.assertRaises(ValueError):
                audit.decode_moduled_kosinski(source)

    def test_vram_upload_overwrites_only_its_destination(self):
        vram = {}
        audit.write_tile_range(vram, 2, bytes([1]*64), "initial")
        audit.write_tile_range(vram, 3, bytes([2]*32), "animation")
        self.assertEqual(vram[2], ("initial", bytes([1]*32)))
        self.assertEqual(vram[3], ("animation", bytes([2]*32)))
        self.assertEqual(len(vram), 2)
        for start, data in ((-1, bytes(32)), (2048, bytes(32)), (0, bytes(31))):
            with self.assertRaises(ValueError):
                audit.write_tile_range(vram, start, data, "bad")

    def test_tile_and_chunk_bitfields_are_distinct(self):
        tile = audit.tile_attributes(0xE923)
        self.assertEqual(tile, {"tile_id": 0x123, "flip_x": True, "flip_y": False,
                                "palette_line": 3, "priority": True})
        chunk = audit.chunk_attributes(0xA523)
        self.assertEqual(chunk["block_id"], 0x123)
        self.assertTrue(chunk["flip_x"])
        self.assertFalse(chunk["primary_top"])
        self.assertTrue(chunk["primary_sides_bottom"])
        self.assertFalse(chunk["secondary_top"])
        self.assertTrue(chunk["secondary_sides_bottom"])
        for decoder in (audit.tile_attributes, audit.chunk_attributes):
            for word in (-1, 0x10000):
                with self.assertRaises(ValueError):
                    decoder(word)

    def test_collision_uses_low_bytes_of_separate_paths(self):
        data = bytearray([0xEE] * 0xC00)
        data[1:0x600:2] = bytes([3] * 768)
        data[0x601:0xC00:2] = bytes([7] * 768)
        self.assertEqual(audit.parse_aiz_collision(data), (bytes([3] * 768), bytes([7] * 768)))
        for invalid in (data[:-1], data + b"x"):
            with self.assertRaises(ValueError):
                audit.parse_aiz_collision(invalid)


class LayoutAuditTests(unittest.TestCase):
    def test_rectangle_only_reports_intersecting_blocks(self):
        layer = {"width_chunks": 1, "height_chunks": 1, "rows": [bytes([0])]}
        chunks = bytearray(128)
        struct.pack_into(">H", chunks, 2, 3)
        self.assertEqual(audit.unresolved_blocks_in_rect(layer, chunks, 2, (0, 0, 16, 16)), [])
        self.assertEqual(audit.unresolved_blocks_in_rect(layer, chunks, 2, (15, 0, 17, 1)), [3])
        with self.assertRaises(ValueError):
            audit.unresolved_blocks_in_rect(layer, chunks, 2, (0, 0, 129, 16))

    def fixture(self):
        data = bytearray(0x8C)
        struct.pack_into(">4H", data, 0, 2, 2, 2, 1)
        # Two FG rows intentionally alias; BG is distinct.
        struct.pack_into(">4H", data, 8, 0x8088, 0x808A, 0x8088, 0)
        data[0x88:] = bytes((1, 2, 3, 4))
        return data

    def test_layer_interleave_and_shared_rows(self):
        layers = audit.parse_layout(self.fixture())
        self.assertEqual(layers["foreground"]["rows"], [bytes((1, 2))] * 2)
        self.assertEqual(layers["background"]["rows"], [bytes((3, 4))])
        self.assertEqual(audit.layout_summary(layers)["foreground"]["shared_row_pointers"], 1)

    def test_rejects_header_and_out_of_payload_pointers(self):
        for pointer in (0, 0x8080, 0x808B, 0xFFFF):
            with self.subTest(pointer=pointer):
                data = self.fixture()
                struct.pack_into(">H", data, 8, pointer)
                with self.assertRaises(ValueError):
                    audit.parse_layout(data)

    def test_rejects_bad_dimensions_and_truncated_layout(self):
        for word_offset, value in ((0, 0), (2, 4096), (4, 33), (6, 0)):
            data = self.fixture()
            struct.pack_into(">H", data, word_offset, value)
            with self.assertRaises(ValueError):
                audit.parse_layout(data)
        for data in (bytes(10), bytes(4097), self.fixture()[:-1]):
            with self.assertRaises(ValueError):
                audit.parse_layout(data)


if __name__ == "__main__":
    unittest.main()

class CollisionIndexStructureTests(unittest.TestCase):
    def test_two_paths_have_768_odd_offset_shape_indices_each(self):
        path_size = 1536
        synthetic = bytes(i % 256 for i in range(path_size * 2))
        self.assertEqual(len(synthetic), 3072)
        paths = (synthetic[:path_size], synthetic[path_size:])
        for path in paths:
            indices = path[1::2]
            self.assertEqual(len(indices), 768)
            self.assertEqual(indices[0], path[1])
            self.assertEqual(indices[-1], path[1535])


class CollisionShapeLookupTests(unittest.TestCase):
    def test_lookup_uses_separate_paths(self):
        data = bytearray(3072)
        data[1 + 2 * 767] = 17
        data[0x601 + 2 * 767] = 203
        paths = audit.parse_aiz_collision(bytes(data))
        self.assertEqual(audit.collision_shape_id(paths, 0, 767), 17)
        self.assertEqual(audit.collision_shape_id(paths, 1, 767), 203)

    def test_rejects_out_of_range_inputs(self):
        paths = (bytes(768), bytes(768))
        for path, block in ((-1, 0), (2, 0), (0, -1), (1, 768)):
            with self.subTest(path=path, block=block):
                with self.assertRaises(ValueError):
                    audit.collision_shape_id(paths, path, block)
        with self.assertRaises(ValueError):
            audit.collision_shape_id((bytes(767), bytes(768)), 0, 0)
