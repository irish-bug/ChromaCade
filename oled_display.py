"""
ChromaCade -- OLED display: thin wrapper over the SSD1306, text only.

128x64 I2C SSD1306 @ 0x3C (gpio-pin-assignments.md), confirmed working
via testing/oled_test.py. Uses Pillow for drawing, not
adafruit_framebuf's built-in .text() -- same reason as oled_test.py:
that method needs a separate font5x8.bin bitmap file pip doesn't
bundle.

Line-based, not pixel-based -- callers (chromacade.py, and menu.py's
display_lines()) hand this a list of plain text lines top to bottom;
this module owns *how* those get rendered (font, spacing, truncation),
callers own *what* the words say. control-layout.md's normal-play OLED
spec (note+accidental large, then font/frequency+bend/volume) needs a
bigger-font first line -- show_play() below handles that specifically
rather than being fully generic, since normal play's layout is fixed
and known, unlike the menu's variable-length option lists.
"""

import os

import board
import busio
import adafruit_ssd1306
from PIL import Image, ImageDraw, ImageFont

WIDTH = 128
HEIGHT = 64
I2C_ADDRESS = 0x3C

LINE_HEIGHT = 12  # small-font line spacing, 5 lines fit in 64px with room to spare
MAX_CHARS_PER_LINE = 21  # Pillow's default bitmap font is ~6px wide, 128/6 ~= 21

# Per-device, NOT a shared constant -- found live 2026-08-28: merging
# plinkplonk into main and pulling to chromacade flipped chromacade's
# display upside down. The two units' panels are physically mounted
# 180 degrees opposite each other, so a single hardcoded value can
# never be right for both -- whichever device's fix landed in this
# file most recently silently breaks the other one the next time
# branches merge. This was already hit twice before this fix ("we had
# fixed it on chromacade and then had to fix on the plinkplonk"), just
# never generalized until now.
#
# Reads from the environment instead, set per-device in that device's
# own chromacade.service (Environment=CHROMACADE_OLED_ROTATION=...) --
# the exact same already-established per-device customization point
# ExecStart/WorkingDirectory already use, see that file's own
# comments, not a new mechanism. Defaults to 180 if unset -- that's
# plinkplonk's own orientation and this constant's value before this
# fix, so plinkplonk needs no service-file change; chromacade's
# chromacade.service sets it to 0 explicitly (see
# docs/device-rebuild-guide.md).
DISPLAY_ROTATION_DEGREES = int(os.environ.get("CHROMACADE_OLED_ROTATION", "180"))


class OledDisplay:
    def __init__(self):
        i2c = busio.I2C(board.SCL, board.SDA)
        self.oled = adafruit_ssd1306.SSD1306_I2C(WIDTH, HEIGHT, i2c, addr=I2C_ADDRESS)
        self.big_font = ImageFont.load_default(size=20)
        self.small_font = ImageFont.load_default()

    def _blank_image(self):
        image = Image.new("1", (WIDTH, HEIGHT))
        return image, ImageDraw.Draw(image)

    def _push(self, image):
        """Every real draw funnels through here so the physical-mount
        rotation (DISPLAY_ROTATION_DEGREES) only has to be applied in
        one place."""
        self.oled.image(image.rotate(DISPLAY_ROTATION_DEGREES))
        self.oled.show()

    def clear(self):
        self.oled.fill(0)
        self.oled.show()

    def show_lines(self, lines):
        """Plain small-font text, one line per row, top to bottom.
        Truncates lines that overflow the panel width/height rather
        than wrapping -- menu option names are short and known ahead
        of time (song titles), not arbitrary user text."""
        image, draw = self._blank_image()
        for i, line in enumerate(lines[: HEIGHT // LINE_HEIGHT]):
            draw.text((0, i * LINE_HEIGHT), line[:MAX_CHARS_PER_LINE], font=self.small_font, fill=255)
        self._push(image)

    def show_play(self, note_label, font_name, freq_hz, bend_hz, volume_percent):
        """Normal-play status, matching control-layout.md's spec: note
        name+accidental large, then font name / frequency+bend (shown
        separately, not summed, so bend reads as a modification not a
        replacement) / volume, one per line."""
        image, draw = self._blank_image()
        draw.text((0, 0), note_label, font=self.big_font, fill=255)
        bend_sign = "+" if bend_hz >= 0 else ""
        draw.text((0, 24), font_name, font=self.small_font, fill=255)
        draw.text((0, 36), f"{freq_hz:.0f} Hz {bend_sign}{bend_hz:.0f} Hz", font=self.small_font, fill=255)
        draw.text((0, 48), f"Vol {volume_percent:.0f}%", font=self.small_font, fill=255)
        self._push(image)
