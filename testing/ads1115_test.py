#!/usr/bin/env python3
"""
ChromaCade — ADS1115 bring-up test (volume pot + joystick axis).

Tests the single ADS1115 this build uses (see gpio-pin-assignments.md —
one ADS1115 per unit, not two), wired as:

    VDD  -> 3.3V (Pi physical pin 1 or 17)
    GND  -> any Pi GND
    SDA  -> GPIO2 (physical pin 3)  -- shared bus with the OLED
    SCL  -> GPIO3 (physical pin 5)  -- shared bus with the OLED
    ADDR -> GND    -- gives I2C address 0x48 (default); no conflict with
                       the OLED's 0x3C/0x3D
    A0   -> KY-023 joystick axis output (module's VCC/GND at 3.3V/GND)
    A1   -> Fender 500K volume pot wiper (outer legs across 3.3V/GND)

Channel assignment matches hardware_poller.py's intent (joystick on
physical A0, volume pot on physical A1) -- his code spells channels as
ADS.P0/ADS.P1, but adafruit-circuitpython-ads1x15 3.0.5 (the version a
fresh `pip install` currently pulls) dropped those named constants in
favor of plain integers 0-3 for AnalogIn's positive_pin argument. His
code will hit the same AttributeError this script did if run against
this library version -- worth a heads-up if/when hardware_poller.py
actually gets run rather than just reviewed.

Prerequisites:
    pip3 install adafruit-circuitpython-ads1x15 --break-system-packages
    (pulls in adafruit-blinka, which provides `board`/`busio`)

Usage:
    python3 ads1115_test.py

Prints live raw counts + voltage for both channels a few times a second.
Turn the pot through its full range and swing the joystick to both
extremes and back to center while this runs -- both should visibly
respond. Ctrl+C to quit; prints a min/max/span summary per channel so a
flat/stuck channel (wiring issue) is obvious even if you weren't
watching closely.
"""

import sys
import time

try:
    import board
    import busio
    import adafruit_ads1x15.ads1115 as ADS
    from adafruit_ads1x15.analog_in import AnalogIn
except ImportError:
    print("Missing dependency. Install with:")
    print("    pip3 install adafruit-circuitpython-ads1x15 --break-system-packages")
    sys.exit(1)

POLL_INTERVAL = 0.2  # seconds
FLAT_SPAN_THRESHOLD = 0.3  # volts -- below this over the whole run, flag as likely stuck/unwired

CHANNELS = {
    "joy": ("Joystick axis (A0)", 0),
    "pot": ("Volume pot (A1)", 1),
}


def main():
    i2c = busio.I2C(board.SCL, board.SDA)

    try:
        ads = ADS.ADS1115(i2c, address=0x48)
    except Exception as e:
        print(f"ERROR: couldn't find an ADS1115 at address 0x48 ({e})")
        print("Check: ADDR pin tied to GND (not VDD/SDA/SCL), VDD/GND wired,")
        print("and SDA/SCL actually reaching GPIO2/GPIO3. Run")
        print("    sudo i2cdetect -y 1")
        print("to see what addresses actually respond on the bus.")
        sys.exit(1)

    ads.gain = 1  # +/-4.096V full-scale -- better resolution than the default
                  # +/-6.144V given the 3.3V supply these channels see

    readers = {key: AnalogIn(ads, chan) for key, (_, chan) in CHANNELS.items()}
    seen = {key: {"min": None, "max": None} for key in CHANNELS}

    print("ChromaCade ADS1115 test -- A0 (joystick axis) / A1 (volume pot)")
    print("=" * 70)
    print("Turn the pot through its full range; swing the joystick to both")
    print("extremes and let it re-center. Ctrl+C to quit and see a summary.")
    print("=" * 70)

    try:
        while True:
            parts = []
            for key, (label, _) in CHANNELS.items():
                v = readers[key].voltage
                lo, hi = seen[key]["min"], seen[key]["max"]
                seen[key]["min"] = v if lo is None else min(lo, v)
                seen[key]["max"] = v if hi is None else max(hi, v)
                parts.append(f"{label}: raw={readers[key].value:6d} {v:5.3f}V")
            print("  ".join(parts))
            time.sleep(POLL_INTERVAL)
    except KeyboardInterrupt:
        pass

    print("\n" + "=" * 70)
    for key, (label, _) in CHANNELS.items():
        lo, hi = seen[key]["min"], seen[key]["max"]
        if lo is None:
            print(f"{label}: no readings taken")
            continue
        span = hi - lo
        if span < FLAT_SPAN_THRESHOLD:
            verdict = (
                "FLAT -- check wiring (pot outer legs across 3.3V/GND, "
                "joystick VCC/GND, ADDR->GND for address 0x48)"
            )
        else:
            verdict = "responded across a real range"
        print(f"{label}: min={lo:.3f}V  max={hi:.3f}V  span={span:.3f}V   {verdict}")
    print("=" * 70)


if __name__ == "__main__":
    main()
