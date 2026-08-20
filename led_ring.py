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
    # testing/led_ring16_test.py's --rgb mode -- see that file's git
    # history for the tuning session. IMPORTANT CAVEAT: tuned against a
    # different physical ring (a candidate 16-LED NeoPixel ring being
    # bench-evaluated, not adopted -- see that ring's test script), not
    # this ring. Different WS2812 manufacturing batches can render the
    # same numeric RGB slightly differently, so these haven't been
    # re-confirmed live against *this* ring yet -- do that before
    # treating this set as final, the same way the previous set was
    # validated directly on this hardware (see git history prior to
    # this commit for that history, e.g. the C/D confusion fix from
    # 2026-08-15). Also fixes a pre-existing drift from
    # docs/color-palette.md's D value (255,45,0 there vs 255,100,0
    # here, from that same 2026-08-15 fix never having been copied back
    # to the doc) -- moot now that D's value is replaced outright, but
    # the doc is being updated alongside this file so the two don't
    # silently diverge again.
    "C": (255, 0, 0),
    "D": (255, 50, 0),
    "E": (125, 85, 0),
    "F": (0, 255, 0),
    "G": (0, 0, 255),
    "A": (10, 0, 24),
    "B": (255, 0, 100),
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
