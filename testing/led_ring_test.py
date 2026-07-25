#!/usr/bin/env python3
"""
ChromaCade -- WS2812 LED ring + interior strip bring-up test.

Tests the full 23-pixel chain: the 7-LED Jewel-style ring (pixels 0-6)
chained into the 16-LED interior strip (pixels 7-22), both riding the
ring's single GPIO12 data line -- the strip connects off the ring's
previously-unused OUT triad (see gpio-pin-assignments.md):

    Ring IN  (DIN) -> GPIO12 (physical pin 32)
    Ring OUT (DOUT) -> Strip IN (DIN)
    VCC (both)      -> Pi 5V rail (can share the amps' VIN rail)
    GND (both)      -> any Pi GND

Prerequisites:
    pip3 install adafruit-circuitpython-neopixel --break-system-packages

Must be run with sudo -- WS2812 output on the Pi uses PWM/DMA hardware
that needs root access, unlike the plain gpiozero-based scripts
elsewhere in this testing/ folder.

Usage:
    sudo python3 led_ring_test.py
    sudo python3 led_ring_test.py --brightness 0.1 --hold 1.5 --pixel-order RGB
    sudo python3 led_ring_test.py --num-pixels 7   # ring only, e.g. before the strip is wired

Runs solid red/green/blue/white fills across the whole chain (one at a
time, to catch a wrong color-channel order -- WS2812 chips are very
commonly wired GRB, not RGB, which is what this defaults to), then
walks a single pixel through all 23 positions (0-6 = ring, 7-22 =
strip) so a dead or miswired individual LED anywhere in the chain is
obvious rather than masked by the others. Turns everything off on exit
(Ctrl+C or normal completion) rather than leaving it lit.
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

RING_PIXELS = 7
STRIP_PIXELS = 16
NUM_PIXELS = RING_PIXELS + STRIP_PIXELS  # 23 total, one chain
DATA_PIN_NAME = "D12"  # board.D12 == BCM GPIO12 == physical pin 32

COLOR_STEPS = [
    ("red", (255, 0, 0)),
    ("green", (0, 255, 0)),
    ("blue", (0, 0, 255)),
    ("white", (255, 255, 255)),
]


def main():
    parser = argparse.ArgumentParser(description="ChromaCade WS2812 ring test")
    parser.add_argument("--brightness", type=float, default=0.2,
                         help="0.0-1.0, conservative default to keep current draw low on the bench (default 0.2)")
    parser.add_argument("--hold", type=float, default=1.0,
                         help="seconds to hold each color/pixel step (default 1.0)")
    parser.add_argument("--pixel-order", default="GRB", choices=["RGB", "GRB"],
                         help="most WS2812/WS2812B are GRB; try RGB if colors come out swapped (default GRB)")
    parser.add_argument("--num-pixels", type=int, default=NUM_PIXELS,
                         help=f"total chain length (default {NUM_PIXELS} = {RING_PIXELS}-pixel ring + {STRIP_PIXELS}-pixel strip; "
                              f"pass {RING_PIXELS} to test just the ring before the strip is wired)")
    args = parser.parse_args()

    order = neopixel.GRB if args.pixel_order == "GRB" else neopixel.RGB

    try:
        pixel_pin = getattr(board, DATA_PIN_NAME)
    except AttributeError:
        print(f"ERROR: board.{DATA_PIN_NAME} not found -- check your adafruit-blinka install/platform detection.")
        sys.exit(1)

    try:
        pixels = neopixel.NeoPixel(
            pixel_pin, args.num_pixels, brightness=args.brightness,
            auto_write=False, pixel_order=order,
        )
    except PermissionError:
        print("ERROR: permission denied initializing the chain.")
        print("WS2812 output needs PWM/DMA hardware access -- run this with sudo:")
        print("    sudo python3 led_ring_test.py")
        sys.exit(1)

    print(f"ChromaCade LED chain test -- GPIO12 (physical pin 32), {args.num_pixels} pixels")
    if args.num_pixels == NUM_PIXELS:
        print(f"(pixels 0-{RING_PIXELS - 1} = ring, {RING_PIXELS}-{NUM_PIXELS - 1} = strip)")
    print("=" * 70)
    print(f"pixel_order={args.pixel_order} brightness={args.brightness}")
    print("If colors look swapped (e.g. red shows as green), re-run with")
    print("--pixel-order RGB. If only the first pixel looks wrong/flickery")
    print("while the rest are fine, that's the classic 3.3V-GPIO-driving-a-")
    print("5V-chain symptom noted in gpio-pin-assignments.md -- a logic-level")
    print("shifter (e.g. 74AHCT125) between GPIO12 and DIN is the fix.")
    print("=" * 70)

    try:
        print(f"\n-- Solid color fill (all {args.num_pixels} pixels) --")
        for name, rgb in COLOR_STEPS:
            print(f"  {name}: {rgb}")
            pixels.fill(rgb)
            pixels.show()
            time.sleep(args.hold)

        print("\n-- One-at-a-time walk (catches a dead/miswired individual LED) --")
        for i in range(args.num_pixels):
            pixels.fill((0, 0, 0))
            pixels[i] = (0, 150, 255)
            pixels.show()
            where = "ring" if (args.num_pixels == NUM_PIXELS and i < RING_PIXELS) else \
                    "strip" if args.num_pixels == NUM_PIXELS else ""
            suffix = f" ({where})" if where else ""
            print(f"  pixel {i} lit{suffix} -- confirm only this one is on")
            time.sleep(args.hold)

        print("\nSequence complete.")
    except KeyboardInterrupt:
        print("\nInterrupted.")
    finally:
        pixels.fill((0, 0, 0))
        pixels.show()
        print("Chain turned off.")


if __name__ == "__main__":
    main()
