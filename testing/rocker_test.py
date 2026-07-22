#!/usr/bin/env python3
"""
ChromaCade -- flat/natural/sharp rocker switch bring-up test.

Tests the XINYIELE ON-OFF-ON rocker wired as:

    Common   -> GND
    Throw 1 (flat)  -> GPIO23 (physical pin 16)
    Throw 2 (sharp) -> GPIO24 (physical pin 18)

Identify Common/throw wires by continuity if not already done -- see
gpio-pin-assignments.md. Active-low, internal pull-ups enabled (same
convention as key_test.py) -- no external resistors needed.

Usage:
    python3 rocker_test.py

Prints the switch's current position (FLAT / NATURAL / SHARP) on every
change. Since this is mechanically a single-pole switch, FLAT and SHARP
should never read active at the same time -- if they ever do, that's a
wiring problem (e.g. a short between the two throws), not a real
switch state, and this script calls it out explicitly. Cycle through
all 3 positions a few times to confirm clean, chatter-free detection
before trusting the GPIO assignment. Ctrl+C to quit.
"""

from datetime import datetime
from gpiozero import Button
from signal import pause

FLAT_PIN = 23
SHARP_PIN = 24
BOUNCE_TIME = 0.02

transition_count = 0


def timestamp():
    return datetime.now().strftime("%H:%M:%S.%f")[:-3]


def report(flat, sharp):
    global transition_count
    transition_count += 1
    flat_on = flat.is_pressed
    sharp_on = sharp.is_pressed

    if flat_on and sharp_on:
        position = "WARNING: BOTH flat and sharp active -- check wiring (short between throws?)"
    elif flat_on:
        position = "FLAT"
    elif sharp_on:
        position = "SHARP"
    else:
        position = "NATURAL (center/off)"

    print(f"[{timestamp()}] #{transition_count:<4} {position}")


def main():
    print("ChromaCade rocker switch test -- GPIO23 (flat) / GPIO24 (sharp)")
    print("=" * 70)
    print("Active-low, internal pull-ups enabled. Ctrl+C to quit.")
    print("Cycle through FLAT / NATURAL / SHARP a few times -- each should")
    print("read cleanly with no chatter, and FLAT+SHARP should never both")
    print("show active at once.")
    print("=" * 70)

    flat = Button(FLAT_PIN, pull_up=True, bounce_time=BOUNCE_TIME)
    sharp = Button(SHARP_PIN, pull_up=True, bounce_time=BOUNCE_TIME)

    flat.when_pressed = lambda: report(flat, sharp)
    flat.when_released = lambda: report(flat, sharp)
    sharp.when_pressed = lambda: report(flat, sharp)
    sharp.when_released = lambda: report(flat, sharp)

    print(f"Starting position: {'FLAT' if flat.is_pressed else 'SHARP' if sharp.is_pressed else 'NATURAL (center/off)'}")

    try:
        pause()
    except KeyboardInterrupt:
        print(f"\nDone. {transition_count} transitions observed.")


if __name__ == "__main__":
    main()
