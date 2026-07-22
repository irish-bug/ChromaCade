#!/usr/bin/env python3
"""
ChromaCade -- WS2812 LED ring bring-up test.

Tests the 7-LED WS2812 ring wired on its input side only (see
gpio-pin-assignments.md -- the output side is for daisy-chaining a
second ring/strip this build doesn't have):

    IN  (DIN) -> GPIO12 (physical pin 32)
    VCC       -> Pi 5V rail (can share the amps' VIN rail)
    GND       -> any Pi GND

Prerequisites:
    pip3 install adafruit-circuitpython-neopixel --break-system-packages

Must be run with sudo -- WS2812 output on the Pi uses PWM/DMA hardware
that needs root access, unlike the plain gpiozero-based scripts
elsewhere in this testing/ folder.

Usage:
    sudo python3 led_ring_test.py
    sudo python3 led_ring_test.py --brightness 0.1 --hold 1.5 --pixel-order RGB

Runs solid red/green/blue/white fills (one at a time, to catch a wrong
color-channel order -- WS2812 chips are very commonly wired GRB, not
RGB, which is what this defaults to), then walks a single pixel around
all 7 positions so a dead or miswired individual LED in the chain is
obvious rather than masked by the other 6. Turns the ring off on exit
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

NUM_PIXELS = 7
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
    args = parser.parse_args()

    order = neopixel.GRB if args.pixel_order == "GRB" else neopixel.RGB

    try:
        pixel_pin = getattr(board, DATA_PIN_NAME)
    except AttributeError:
        print(f"ERROR: board.{DATA_PIN_NAME} not found -- check your adafruit-blinka install/platform detection.")
        sys.exit(1)

    try:
        pixels = neopixel.NeoPixel(
            pixel_pin, NUM_PIXELS, brightness=args.brightness,
            auto_write=False, pixel_order=order,
        )
    except PermissionError:
        print("ERROR: permission denied initializing the ring.")
        print("WS2812 output needs PWM/DMA hardware access -- run this with sudo:")
        print("    sudo python3 led_ring_test.py")
        sys.exit(1)

    print("ChromaCade LED ring test -- GPIO12 (physical pin 32), 7 pixels")
    print("=" * 70)
    print(f"pixel_order={args.pixel_order} brightness={args.brightness}")
    print("If colors look swapped (e.g. red shows as green), re-run with")
    print("--pixel-order RGB. If only the first pixel looks wrong/flickery")
    print("while the rest are fine, that's the classic 3.3V-GPIO-driving-a-")
    print("5V-chain symptom noted in gpio-pin-assignments.md -- a logic-level")
    print("shifter (e.g. 74AHCT125) between GPIO12 and DIN is the fix.")
    print("=" * 70)

    try:
        print("\n-- Solid color fill (all 7 pixels) --")
        for name, rgb in COLOR_STEPS:
            print(f"  {name}: {rgb}")
            pixels.fill(rgb)
            pixels.show()
            time.sleep(args.hold)

        print("\n-- One-at-a-time walk (catches a dead/miswired individual LED) --")
        for i in range(NUM_PIXELS):
            pixels.fill((0, 0, 0))
            pixels[i] = (0, 150, 255)
            pixels.show()
            print(f"  pixel {i} lit -- confirm only this one is on")
            time.sleep(args.hold)

        print("\nSequence complete.")
    except KeyboardInterrupt:
        print("\nInterrupted.")
    finally:
        pixels.fill((0, 0, 0))
        pixels.show()
        print("Ring turned off.")


if __name__ == "__main__":
    main()
