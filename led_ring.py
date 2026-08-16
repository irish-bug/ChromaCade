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
    # C nudged from pure (255,0,0) to a small blue tint 2026-08-15 --
    # flagged live as too close to D/orange without a direct
    # side-by-side comparison. (255,0,0) is already RGB-maximal red,
    # so there's no "more red" to add on that channel; a touch of blue
    # cools it toward true scarlet/crimson instead, since WS2812 red
    # channels often skew warm/orange on their own. Live-tune further
    # if this still isn't distinct enough from D.
    "C": (255, 0, 25),
    "D": (255, 45, 0),
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
