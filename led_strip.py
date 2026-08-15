"""
ChromaCade -- LED interior strip: whole-case ambient/celebration
lighting, a separate physical chain from led_ring.py's per-note ring.

Independent 16-pixel WS2812 chain on GPIO13 (gpio-pin-assignments.md's
"WS2812 LED interior strip" section), confirmed working via
testing/led_ring_test.py's --target strip. Its long-term behavior
(a progress-style fill during Tutor mode, a whole-case pulse on a
correct Simon sequence, etc.) is still undesigned -- see
open-questions.md's Interior backlighting strip bullet. This is the
first real (non-test) use: a plain fill/clear primitive, same shape as
LedRing, so a caller can drive both chains the same way -- currently
tutor_mode.py's song-complete celebration flash.
"""

import board
import neopixel

STRIP_PIXEL_COUNT = 16


class LedStrip:
    def __init__(self, brightness=0.3):
        self.pixels = neopixel.NeoPixel(
            board.D13,
            STRIP_PIXEL_COUNT,
            brightness=brightness,
            auto_write=False,
            pixel_order=neopixel.GRB,
        )

    def fill(self, color):
        self.pixels.fill(color)
        self.pixels.show()

    def clear(self):
        self.fill((0, 0, 0))
