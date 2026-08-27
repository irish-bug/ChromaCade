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
    # Replaced wholesale 2026-08-20 with values live-tuned via
    # testing/led_ring16_test.py's --rgb mode on a different physical
    # ring (a candidate 16-LED NeoPixel ring being bench-evaluated, not
    # adopted) -- see that file's git history for the tuning session.
    # First pass confirmed live on THIS ring/hardware the same day: ran
    # cleanly on chromacade (real GPIO12/PWM output, no errors) and a
    # second person (Sean) judged it a "huge improvement" over the
    # previous set with eyes on the device directly.
    #
    # Superseded again 2026-08-27, direct instruction: applies the
    # candidate ring's LATER, more complete tuning pass (all 7 colors
    # brought to a consistent max-channel-88 ceiling, not just purple's
    # own second-pass brightness fix) -- see testing/led_ring16_test.py's
    # own header comment for the full reasoning (lower intensity across
    # the board reads more distinct, not just a fix for individual
    # problem colors). Applied from the candidate-ring bench data
    # directly -- NOT yet re-confirmed with eyes on THIS ring the way
    # the first pass was; do that before treating this as fully settled
    # the way the first pass got to be.
    "C": (88, 0, 0),
    "D": (88, 15, 0),
    "E": (88, 55, 0),
    "F": (0, 88, 0),
    "G": (0, 0, 88),
    "A": (40, 0, 88),
    "B": (88, 0, 35),
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
