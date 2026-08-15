#!/usr/bin/env python3
"""
ChromaCade -- WS2812 LED ring + interior strip bring-up test.

Ring and strip are wired as two independent chains, each on its own
GPIO/PWM channel -- not chained ring-OUT -> strip-IN on one line (that
plan was superseded 2026-07-28, see gpio-pin-assignments.md and
decision-log.md: splitting them isolates ring problems from strip
problems and shortens each individual run):

    Ring:  DIN -> GPIO12 (physical pin 32, PWM0), 7 pixels (Jewel-style)
    Strip: DIN -> GPIO13 (physical pin 33, PWM1), 16 pixels
    VCC (both) -> Pi 5V rail
    GND (both) -> any Pi GND

GPIO13 was freed for this by moving the octave encoder's push-button
to GPIO25 (see gpio-pin-assignments.md) -- that click has no assigned
function (open-questions.md), so the pin was a better fit for the
strip's own hardware-PWM channel than for a plain digital button read.

Prerequisites:
    pip3 install adafruit-circuitpython-neopixel --break-system-packages

Must be run with sudo -- WS2812 output on the Pi uses PWM/DMA hardware
that needs root access, unlike the plain gpiozero-based scripts
elsewhere in this testing/ folder.

Usage:
    sudo python3 led_ring_test.py                   # both, one after the other
    sudo python3 led_ring_test.py --target ring      # ring only
    sudo python3 led_ring_test.py --target strip     # strip only
    sudo python3 led_ring_test.py --brightness 0.1 --hold 1.5 --pixel-order RGB

For whichever target(s) are selected: runs solid red/green/blue/white
fills (one at a time, to catch a wrong color-channel order -- WS2812
chips are very commonly wired GRB, not RGB, which is what this
defaults to), then walks a single pixel through all positions in that
chain, so a dead or miswired individual LED is obvious rather than
masked by the others. Turns everything off on exit (Ctrl+C or normal
completion) rather than leaving it lit.
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

# name -> (label, board pin attribute, pixel count)
TARGETS = {
    "ring": ("Ring", "D12", 7),
    "strip": ("Strip", "D13", 16),
}

COLOR_STEPS = [
    ("red", (255, 0, 0)),
    ("green", (0, 255, 0)),
    ("blue", (0, 0, 255)),
    ("white", (255, 255, 255)),
]


def run_target(label, pin_name, num_pixels, brightness, hold, order):
    try:
        pixel_pin = getattr(board, pin_name)
    except AttributeError:
        print(f"ERROR: board.{pin_name} not found -- check your adafruit-blinka install/platform detection.")
        sys.exit(1)

    try:
        pixels = neopixel.NeoPixel(
            pixel_pin, num_pixels, brightness=brightness,
            auto_write=False, pixel_order=order,
        )
    except PermissionError:
        print("ERROR: permission denied initializing the chain.")
        print("WS2812 output needs PWM/DMA hardware access -- run this with sudo:")
        print("    sudo python3 led_ring_test.py")
        sys.exit(1)

    print(f"\n{'=' * 70}\n{label} -- board.{pin_name}, {num_pixels} pixels\n{'=' * 70}")

    try:
        print(f"-- Solid color fill (all {num_pixels} pixels) --")
        for color_name, rgb in COLOR_STEPS:
            print(f"  {color_name}: {rgb}")
            pixels.fill(rgb)
            pixels.show()
            time.sleep(hold)

        print("-- One-at-a-time walk (catches a dead/miswired individual LED) --")
        for i in range(num_pixels):
            pixels.fill((0, 0, 0))
            pixels[i] = (0, 150, 255)
            pixels.show()
            print(f"  pixel {i} lit -- confirm only this one is on")
            time.sleep(hold)

        print(f"{label} sequence complete.")
    finally:
        pixels.fill((0, 0, 0))
        pixels.show()


def main():
    parser = argparse.ArgumentParser(description="ChromaCade WS2812 ring + strip test")
    parser.add_argument("--target", default="both", choices=["ring", "strip", "both"],
                         help="which chain to test (default both, run one after the other)")
    parser.add_argument("--brightness", type=float, default=0.2,
                         help="0.0-1.0, conservative default to keep current draw low on the bench (default 0.2)")
    parser.add_argument("--hold", type=float, default=1.0,
                         help="seconds to hold each color/pixel step (default 1.0)")
    parser.add_argument("--pixel-order", default="GRB", choices=["RGB", "GRB"],
                         help="most WS2812/WS2812B are GRB; try RGB if colors come out swapped (default GRB)")
    args = parser.parse_args()

    order = neopixel.GRB if args.pixel_order == "GRB" else neopixel.RGB
    keys = list(TARGETS.keys()) if args.target == "both" else [args.target]

    print("ChromaCade LED test -- ring (GPIO12) and strip (GPIO13) are independent chains")
    print(f"pixel_order={args.pixel_order} brightness={args.brightness}")
    print("If colors look swapped (e.g. red shows as green), re-run with --pixel-order RGB.")
    print("If only the first pixel of a chain looks wrong/flickery while the rest are")
    print("fine, that's the classic 3.3V-GPIO-driving-a-5V-chain symptom noted in")
    print("gpio-pin-assignments.md -- a logic-level shifter (e.g. 74AHCT125) between")
    print("that chain's GPIO and DIN is the fix.")

    try:
        for key in keys:
            label, pin_name, num_pixels = TARGETS[key]
            run_target(label, pin_name, num_pixels, args.brightness, args.hold, order)
    except KeyboardInterrupt:
        print("\nInterrupted.")


if __name__ == "__main__":
    main()
