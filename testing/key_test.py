#!/usr/bin/env python3
"""
ChromaCade — 3-key test mount bring-up script.

Tests the Outemu Blue MX switches wired to GPIO14 (pin 8), GPIO15 (pin 10),
and GPIO25 (pin 22), with all grounds joined through a Wago to physical
pin 6 (GND).

Key 3 was originally wired to GPIO18 (pin 12), which collides with the
locked I2S BCLK pin. Moved to GPIO25 (pin 22), a clean spare untouched by
I2C/I2S/SPI — no more conflict, safe to run this test with the amps wired
and I2S enabled.

Usage:
    python3 key_test.py

Press Ctrl+C to quit. Prints one line per press/release, plus a running
per-key press count so you can sanity-check for double-triggers or dropped
presses (debounce/connection issues) over repeated presses.
"""

from datetime import datetime
from gpiozero import Button
from signal import pause

# BCM pin -> human label. These are test-mount pins only, NOT the final
# note-button assignments (those are GPIO4/17/27/22/10/9/11 per
# gpio-pin-assignments.md).
PINS = {
    14: "Key 1 (GPIO14, physical pin 8)",
    15: "Key 2 (GPIO15, physical pin 10)",
    25: "Key 3 (GPIO25, physical pin 22)",
}

# Debounce time in seconds. Start at 20ms; loosen (increase) if you see
# double-triggers on a clean single press, tighten (decrease) if fast
# repeated presses feel like they're getting eaten.
BOUNCE_TIME = 0.02

press_counts = {pin: 0 for pin in PINS}
held = set()


def timestamp():
    return datetime.now().strftime("%H:%M:%S.%f")[:-3]


def make_press_handler(pin, label):
    def on_press():
        press_counts[pin] += 1
        held.add(pin)
        held_labels = ", ".join(PINS[p] for p in sorted(held)) or "none"
        print(
            f"[{timestamp()}] PRESS   {label:<32} "
            f"count={press_counts[pin]:<4} held=({held_labels})"
        )

    return on_press


def make_release_handler(pin, label):
    def on_release():
        held.discard(pin)
        held_labels = ", ".join(PINS[p] for p in sorted(held)) or "none"
        print(
            f"[{timestamp()}] release {label:<32} "
            f"{'':<10} held=({held_labels})"
        )

    return on_release


def main():
    print("ChromaCade key test — GPIO14 / GPIO15 / GPIO25")
    print("=" * 60)
    print("Active-low, internal pull-ups enabled. Ctrl+C to quit.")
    print("Try: single presses on each key, then hold 2-3 together")
    print("to sanity-check chord support before wiring the real panel.")
    print("=" * 60)

    buttons = []
    for pin, label in PINS.items():
        btn = Button(pin, pull_up=True, bounce_time=BOUNCE_TIME)
        btn.when_pressed = make_press_handler(pin, label)
        btn.when_released = make_release_handler(pin, label)
        buttons.append(btn)

    try:
        pause()
    except KeyboardInterrupt:
        pass
    finally:
        print("\n" + "=" * 60)
        print("Press counts:")
        for pin, label in PINS.items():
            print(f"  {label:<32} {press_counts[pin]}")
        print("=" * 60)


if __name__ == "__main__":
    main()
