#!/usr/bin/env python3
"""
ChromaCade -- SSD1306 OLED bring-up test.

Tests the 128x64 I2C OLED wired per gpio-pin-assignments.md (SDA->GPIO2/
pin3, SCL->GPIO3/pin5, VCC->3.3V, GND->any GND), confirmed present at
I2C address 0x3C via `sudo i2cdetect -y 1`.

Prerequisites:
    pip3 install adafruit-circuitpython-ssd1306 --break-system-packages

Usage:
    python3 oled_test.py
    python3 oled_test.py --text "hello chromacade" --hold 8

Draws a full-panel border rectangle plus text -- checking the whole
panel is alive, not just that the chip acks its I2C address (a dead/
dim/miswired panel can still show up in i2cdetect if the controller
chip itself responds). Holds it, then flashes a full-panel invert a
few times (toggles every pixel via a controller command rather than
redrawing, so it's a check independent of the text/rect drawing code),
then clears before exiting.
"""

import argparse
import sys
import time

try:
    import board
    import busio
    import adafruit_ssd1306
except ImportError:
    print("Missing dependency. Install with:")
    print("    pip3 install adafruit-circuitpython-ssd1306 --break-system-packages")
    sys.exit(1)

WIDTH = 128
HEIGHT = 64
I2C_ADDRESS = 0x3C


def main():
    parser = argparse.ArgumentParser(description="ChromaCade OLED test")
    parser.add_argument("--text", default="ChromaCade OK", help="text to display (default: 'ChromaCade OK')")
    parser.add_argument("--hold", type=float, default=5.0, help="seconds to hold the display before the invert flash (default 5.0)")
    args = parser.parse_args()

    i2c = busio.I2C(board.SCL, board.SDA)

    try:
        oled = adafruit_ssd1306.SSD1306_I2C(WIDTH, HEIGHT, i2c, addr=I2C_ADDRESS)
    except Exception as e:
        print(f"ERROR: couldn't initialize the OLED at address 0x{I2C_ADDRESS:02X} ({e})")
        print("Confirm `sudo i2cdetect -y 1` still shows 0x3c, and check VCC/GND wiring.")
        sys.exit(1)

    print("ChromaCade OLED test -- 128x64 SSD1306 @ 0x3C")
    print("=" * 60)

    oled.fill(0)
    oled.rect(0, 0, WIDTH, HEIGHT, 1)
    oled.text(args.text, 8, 28, 1)
    oled.show()
    print(f'Displaying: "{args.text}" with a full-panel border rectangle.')
    print("Confirm: border visible on all 4 edges (catches a partially")
    print("dead/miswired panel), text legible and not garbled/mirrored.")
    time.sleep(args.hold)

    print("Flashing full-panel invert 3x (checks every pixel can light, not just the drawn ones)...")
    for _ in range(3):
        oled.invert(True)
        time.sleep(0.3)
        oled.invert(False)
        time.sleep(0.3)

    oled.fill(0)
    oled.show()
    print("Display cleared. Done.")


if __name__ == "__main__":
    main()
