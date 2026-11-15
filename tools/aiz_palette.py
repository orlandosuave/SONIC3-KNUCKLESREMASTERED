"""Normal AIZ1 ROM palette cycles; excludes fire, fades and underwater palettes."""
import struct


def cycle_step(timer, next_water, next_sparkle, sparkle_disabled=False):
    timer = (timer-1) & 0xFFFF
    if timer < 0x8000:
        return timer, next_water, next_sparkle, None
    active = (next_water & 0x18, None if sparkle_disabled else next_sparkle)
    return 7, (next_water+8) & 0xFFFF, (next_sparkle if sparkle_disabled else (next_sparkle+6) % 48), active


def normal_palette_words(rom, next_water, next_sparkle):
    """Resolve last uploaded colors from initialized, post-update counters.

    Counters remain captured inputs; palette colors themselves come from ROM.
    This reconstruction requires normal cycling with sparkle updates enabled.
    """
    if next_sparkle not in range(0, 48, 6) or next_water % 8:
        raise ValueError("Invalid normal AIZ1 palette counters")
    words = list(struct.unpack_from(">16H", rom, 0x28C234))
    words += struct.unpack_from(">48H", rom, 0x28C374)
    words[43:47] = struct.unpack_from(">4H", rom, 0x2AF6+((next_water-8) & 0x18))
    words[60:63] = struct.unpack_from(">3H", rom, 0x2BF6+((next_sparkle-6) % 48))
    return words


def water_scanline_palettes(rom, normal, hint_counter, height=224, transfer_counter=None):
    """AIZ1 HInt3 grouped writes, one group per scanline after the interrupt.

    Late interrupts truncate the ROM transfer list. Pixel-exact horizontal
    write timing still requires validation outside the sampled NTSC views.
    """
    water = struct.unpack_from(">64H", rom, 0xA8C9C)
    count = struct.unpack_from(">H", rom, 0x74E0)[0]+1
    # The VDP has latched the old counter, but the interrupt reads the RAM
    # counter again to limit transfers. Main-loop updates can change it first.
    limit_counter = hint_counter if transfer_counter is None else transfer_counter
    if limit_counter >= 200:
        count = max(0, count-(limit_counter-200))
    offsets = struct.unpack_from(f">{count}H", rom, 0x74E2) if count else ()
    colors, rows = list(normal), []
    for row in range(height):
        group = row-hint_counter-1
        if 0 <= group < len(offsets):
            first = offsets[group]//2
            colors[first:first+3] = water[first:first+3]
        rows.append(colors.copy())
    return rows
