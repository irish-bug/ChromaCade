#!/usr/bin/env python3
"""
ChromaCade -- final 7-note button panel bring-up test.

Tests the real note-button GPIO assignments (not the old 3-key test
mount's GPIO14/15/25, which that mount's bring-up script covered), per
gpio-pin-assignments.md:

    A -> GPIO4  (physical pin 7)
    B -> GPIO17 (physical pin 11)
    C -> GPIO27 (physical pin 13)
    D -> GPIO22 (physical pin 15)
    E -> GPIO10 (physical pin 19)  -- repurposed SPI MISO, safe (no SPI on this build)
    F -> GPIO9  (physical pin 21)  -- repurposed SPI MOSI
    G -> GPIO11 (physical pin 23)  -- repurposed SPI SCLK

Direct GPIO wiring, no matrix -- deliberate, see decision-log.md (a
matrix would ghost on chord combinations, which breaks chord support).
Each switch: one leg to its GPIO, the other leg to any common GND --
active-low, internal pull-up, no external resistor needed. Outemu Blue
MX switches per hardware-bom.md.

Usage:
    python3 note_buttons_test.py

Press Ctrl+C to quit. Prints one line per press/release plus a running
per-note press count, so double-triggers or dropped presses (debounce/
connection issues) are obvious over repeated presses. Try single
presses on each note first, then hold 2-3 together to sanity-check
chord support -- the whole reason this isn't a matrix.
"""

from datetime import datetime
from gpiozero import Button
from signal import pause

# Note -> BCM pin, in letter order (per gpio-pin-assignments.md)
NOTES = {
    "A": 4,
    "B": 17,
    "C": 27,
    "D": 22,
    "E": 10,
    "F": 9,
    "G": 11,
}
NOTE_ORDER = list(NOTES.keys())

# Debounce time in seconds. Start at 20ms; loosen (increase) if you see
# double-triggers on a clean single press, tighten (decrease) if fast
# repeated presses feel like they're getting eaten.
BOUNCE_TIME = 0.02

press_counts = {note: 0 for note in NOTES}
held = set()


def timestamp():
    return datetime.now().strftime("%H:%M:%S.%f")[:-3]


def held_str():
    return ", ".join(n for n in NOTE_ORDER if n in held) or "none"


def make_press_handler(note, pin):
    def on_press():
        press_counts[note] += 1
        held.add(note)
        print(
            f"[{timestamp()}] PRESS   {note} (GPIO{pin:<2}) "
            f"count={press_counts[note]:<4} held=({held_str()})"
        )

    return on_press


def make_release_handler(note, pin):
    def on_release():
        held.discard(note)
        print(
            f"[{timestamp()}] release {note} (GPIO{pin:<2}) "
            f"{'':<10} held=({held_str()})"
        )

    return on_release


def main():
    print("ChromaCade note-button panel test -- A B C D E F G")
    print("=" * 60)
    print("Active-low, internal pull-ups enabled. Ctrl+C to quit.")
    print("Try: single presses on each note, then hold 2-3 together")
    print("to sanity-check chord support.")
    print("=" * 60)

    buttons = []
    for note, pin in NOTES.items():
        btn = Button(pin, pull_up=True, bounce_time=BOUNCE_TIME)
        btn.when_pressed = make_press_handler(note, pin)
        btn.when_released = make_release_handler(note, pin)
        buttons.append(btn)

    try:
        pause()
    except KeyboardInterrupt:
        pass
    finally:
        print("\n" + "=" * 60)
        print("Press counts:")
        for note, pin in NOTES.items():
            print(f"  {note} (GPIO{pin:<2}) {press_counts[note]}")
        print("=" * 60)


if __name__ == "__main__":
    main()
