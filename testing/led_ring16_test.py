#!/usr/bin/env python3
"""
ChromaCade -- candidate "NeoPixel Ring 16" bench test.

Not the project's decided ring/strip (see led_ring_test.py for those) --
this is a bench evaluation of a different, not-yet-committed 16-LED ring
being tried as a possible swap-in. Wire only 3 of its 6 pads for this
test: 5V, GND, and DIN. Leave the unlabeled pad and the "Power & Signal"
pad disconnected until their function is confirmed (e.g. via a
continuity check against the 4 known pads) -- guessing at those risks
frying the ring or a GPIO pin.

    DIN -> GPIO12, PHYSICAL PIN 32 (PWM0) -- NOT physical pin 12.
           Physical pin 12 is GPIO18, which this build's I2S audio
           (WM8960 HAT) already claims for BCLK -- see
           gpio-pin-assignments.md's WS2812 ring entry, which calls
           this out by name as "a common conflict with the default
           rpi_ws281x example code". GPIO12/pin 32 is the pin the
           project's real ring already uses successfully.
    VCC -> Pi 5V rail
    GND -> any Pi GND

Cycles 7 generic/textbook RGB values (not this project's tuned
docs/color-palette.md hexes -- see led_ring_test.py's history or
git blame on this file for those) -- red, orange, yellow, green, blue,
purple, pink, in that order. Just a plain color-rendering check for
this candidate ring, not a comparison against the project's actual
palette.

Prerequisites:
    pip3 install adafruit-circuitpython-neopixel --break-system-packages

Must be run with sudo -- WS2812 output on the Pi uses PWM/DMA hardware
that needs root access.

Usage:
    sudo python3 led_ring16_test.py
    sudo python3 led_ring16_test.py --num-pixels 16 --hold 1.5
    sudo python3 led_ring16_test.py --pixel-order RGB   # if colors look swapped
"""

import argparse
import sys
import time

try:
    import board
    import neopixel
except ImportError:
    print("Missing dependency. Install with:")
    print("    pip3 install adafruit-circuitpython-neopixel --break-system-packages")
    sys.exit(1)

# Generic/textbook RGB values -- full-saturation primaries for red/green/
# blue (matching led_ring_test.py's own COLOR_STEPS convention), standard
# CSS named-color values for orange/yellow/purple/pink.
COLORS = [
    ("red",    (255, 0, 0)),
    ("orange", (255, 165, 0)),
    ("yellow", (255, 255, 0)),
    ("green",  (0, 255, 0)),
    ("blue",   (0, 0, 255)),
    ("purple", (128, 0, 128)),
    ("pink",   (255, 192, 203)),
]


def main():
    parser = argparse.ArgumentParser(description="ChromaCade candidate 16-LED ring bench test")
    parser.add_argument("--pin", default="D12",
                         help="board pin attribute for DIN (default D12 = GPIO12 = physical pin 32)")
    parser.add_argument("--num-pixels", type=int, default=16,
                         help="pixel count (default 16, per the ring's name -- override if it's actually different)")
    parser.add_argument("--brightness", type=float, default=0.2,
                         help="0.0-1.0, conservative default to keep current draw low on the bench (default 0.2)")
    parser.add_argument("--hold", type=float, default=1.0,
                         help="seconds to hold each color (default 1.0)")
    parser.add_argument("--pixel-order", default="GRB", choices=["RGB", "GRB"],
                         help="most WS2812/WS2812B are GRB; try RGB if colors come out swapped (default GRB)")
    args = parser.parse_args()

    order = neopixel.GRB if args.pixel_order == "GRB" else neopixel.RGB

    try:
        pixel_pin = getattr(board, args.pin)
    except AttributeError:
        print(f"ERROR: board.{args.pin} not found -- check your adafruit-blinka install/platform detection.")
        sys.exit(1)

    try:
        pixels = neopixel.NeoPixel(
            pixel_pin, args.num_pixels, brightness=args.brightness,
            auto_write=False, pixel_order=order,
        )
    except PermissionError:
        print("ERROR: permission denied initializing the chain.")
        print("WS2812 output needs PWM/DMA hardware access -- run this with sudo:")
        print("    sudo python3 led_ring16_test.py")
        sys.exit(1)

    print(f"Candidate ring -- board.{args.pin}, {args.num_pixels} pixels, pixel_order={args.pixel_order}")
    print("If colors look swapped (e.g. red shows as green), re-run with --pixel-order RGB.")
    print("If the first pixel looks wrong/flickery while the rest are fine, that's the classic")
    print("3.3V-GPIO-driving-a-5V-chain symptom -- a logic-level shifter (74AHCT125) may be needed.")
    print()

    try:
        for name, rgb in COLORS:
            print(f"  {name:8s} {rgb}")
            pixels.fill(rgb)
            pixels.show()
            time.sleep(args.hold)
        print("Sequence complete.")
    except KeyboardInterrupt:
        print("\nInterrupted.")
    finally:
        pixels.fill((0, 0, 0))
        pixels.show()


if __name__ == "__main__":
    main()
