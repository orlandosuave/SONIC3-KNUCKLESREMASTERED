"""Source-informed AIZ1 dry-background model; not a reference emulator.

Uses original coordinate units and signed fixed-width arithmetic. Water/fire,
DMA timing and source-plane drawing transformations are separate work.
"""
import struct


def signed(value, bits):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits-1)) else value


def normal_scroll(camera_x, camera_y, phase=0):
    step = signed(signed(camera_x - 0x1300, 16) << 16, 32) >> 5
    values = {}

    def put(offset, fixed):
        values[offset] = signed(signed(fixed, 32) >> 16, 16)

    for offset, factor in ((0x30, 14), (4, 16), (0x32, 16), (0x3A, 16),
                           (0x34, 18), (0x38, 18), (0x36, 20), (0x14, 1)):
        put(offset, step*factor)
    accumulator = step >> 1
    for offset in (0x12, 0x10, 0x0E, 0x0C, 0x0A, 8):
        accumulator = signed(accumulator + signed(phase, 32), 32)
        put(offset, accumulator)
        accumulator = signed(accumulator + step, 32)
    for i in range(13):
        put(0x16 + i*2, step + (i+1)*(step >> 3))
    return {"background_y": signed(camera_y, 16) >> 1,
            "scroll_words": values, "next_phase": (phase + 0x2000) & 0xFFFFFFFF}


def intro_scroll(camera_x, camera_y, event_x=0):
    selected = signed(event_x, 16) if signed(event_x, 16) < 0 else signed(camera_x, 16)
    half = selected >> 1
    if half >= 0x580:
        bands = [half]*37
    else:
        delta = signed((half - 0x580) << 16, 32)
        increment = delta >> 5
        bands = [half] + [signed((signed(delta+i*increment, 32) >> 16)+0x580, 16)
                         for i in range(1, 37)]
    return {"background_y": signed(camera_y, 16),
            "scroll_words": {0x28+i*2: value for i, value in enumerate(bands)},
            "draw_bands": [max(0, bands[i]) for i in [0, 1, 5, 9, 13, 17, 21, 25, 29, 33]]}


def line_offsets(image, model, intro=False, height=224):
    """Expand ROM band lengths; high-bit entries consume one word per scanline."""
    if not 1 <= height <= 1440:
        raise ValueError("Invalid scanline count")
    offset, count = (0x23B20A, 37) if intro else (0x23B258, 14)
    table = struct.unpack_from(f">{count}H", image, offset)
    start = model["background_y"]
    if start < 0:
        raise ValueError("Negative background rows need original wrap behavior")
    cursor, word_offset, result = 0, (0x28 if intro else 8), []
    for entry in table:
        length, varying = entry & 0x7FFF, bool(entry & 0x8000)
        lo, hi = max(start, cursor), min(start+height, cursor+length)
        for row in range(lo, hi):
            index = word_offset + (2*(row-cursor) if varying else 0)
            if index not in model["scroll_words"]:
                raise ValueError("Deformation table references an uninitialized scroll word")
            result.append(model["scroll_words"][index])
        cursor += length
        word_offset += 2*length if varying else 2
        if len(result) == height:
            return result
    raise ValueError("Deformation table does not cover requested scanlines")


def water_line_offsets(image, model, camera_x, camera_y, water_y, level_frame, height=224):
    """Return source X per scanline, including original AIZ1 water deltas.

    Table addresses are from the supported ROM's PC-relative LEA operands.
    This function models scroll only, not underwater palette switching.
    """
    background = line_offsets(image, model, height=height)
    foreground = [camera_x]*height
    surface = signed(water_y-camera_y, 16)
    if surface < 0:
        raise ValueError("Fully submerged camera needs separate entry-state validation")
    fg_phase = ((level_frame+water_y*2) & 0x7E)//2
    bg_phase = (((level_frame >> 1)+(surface+model["background_y"])*2) & 0x7E)//2
    for row in range(surface, height):
        fg_delta = struct.unpack_from(">h", image, 0x23A170+2*(fg_phase+row-surface))[0]
        bg_delta = struct.unpack_from(">h", image, 0x23A3B0+2*(bg_phase+row-surface))[0]
        foreground[row] = signed(camera_x-fg_delta, 16)
        background[row] = signed(background[row]-bg_delta, 16)
    return foreground, background
