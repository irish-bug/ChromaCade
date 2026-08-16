"""
ChromaCade -- LED ring: per-note color.

NOTE_COLORS is the tuned, hardware-confirmed RGB set from
color-palette.md's LED ring section -- bold/saturated values chosen
live against the real WS2812 ring, not the pastel keycap hex (LEDs are
additive light, not reflective plastic, so the same hex that looks
right on a keycap reads as washed-out white when emitted directly --
see color-palette.md for the full story).

Chord-blend behavior (what to show when multiple notes are held) is
explicitly deferred -- see feature-spec.md's Color system section and
open-questions.md. Current behavior here is the simplest placeholder,
not a design decision: show whichever held note was pressed most
recently, clear when nothing's held.
"""

import board
import neopixel

NOTE_COLORS = {
    # C/D confusion flagged live 2026-08-15. First attempt added a
    # blue tint to C to cool it away from orange -- overcorrected,
    # flagged live as now reading too close to B/pink instead (blue
    # pushes red toward magenta fast, even in small amounts). Reverted
    # C to pure (255,0,0) and fixed it from the other side instead: D
    # was only 45/255 (18%) green, barely past red at all, more
    # "red-orange" than orange. Bumped to 100/255 (~39%), closer to
    # the midpoint between C's 0 and E's 170 -- a clearer, more
    # distinct orange, further from both red and E's yellow-orange.
    "C": (255, 0, 0),
    "D": (255, 100, 0),
    "E": (255, 170, 0),
    "F": (0, 200, 0),
    "G": (0, 100, 255),
    "A": (60, 0, 255),
    "B": (255, 20, 147),
}

RING_PIXEL_COUNT = 7


class LedRing:
    def __init__(self, brightness=0.3):
        self.pixels = neopixel.NeoPixel(
            board.D12,
            RING_PIXEL_COUNT,
            brightness=brightness,
            auto_write=False,
            pixel_order=neopixel.GRB,
        )

    def fill(self, color):
        """Arbitrary-color fill, not tied to NOTE_COLORS -- for things
        like tutor_mode.py's completion celebration flash, which isn't
        a note cue."""
        self.pixels.fill(color)
        self.pixels.show()

    def show(self, letter):
        self.fill(NOTE_COLORS[letter])

    def clear(self):
        self.fill((0, 0, 0))
