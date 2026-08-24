#!/usr/bin/env python3
"""
ChromaCade -- EC11 rotary encoder bring-up test (octave or font).

Tests one EC11 encoder's A/B quadrature signals and pushbutton, wired
per gpio-pin-assignments.md:

    Octave encoder: A->GPIO5(pin29)  B->GPIO6(pin31)  Button->GPIO8(pin24)
    Font encoder:   A->GPIO26(pin37) B->GPIO16(pin36) Button->GPIO7(pin26)
    (both: Common + button's other leg -> GND)

Both button pins were retested and moved here 2026-08-14 (see
decision-log.md's "octave encoder's push-button... was never dead"
entry) -- GPIO25 (octave's original pin) had solder-damage history
from the old 3-key test mount and never registered; GPIO20 (font's
original pin) is permanently claimed by the I2S peripheral and could
never register regardless of wiring. Neither is a valid retest target
anymore -- hardware_poller.py already uses GPIO8/GPIO7 for real. Use
--button-pin to test some other pin without editing this file, e.g.:

    python3 encoder_test.py --which octave --button-pin 14

Usage:
    python3 encoder_test.py --which octave [--button-pin N]
    python3 encoder_test.py --which font [--button-pin N]

Uses gpiozero's RotaryEncoder, which handles quadrature decoding and
debouncing internally -- prints CW/CCW plus a running step count on
every detent, and press/release for the pushbutton. Turn the shaft
through several detents in each direction: each click should register
exactly once (no double-counts, no skips), and direction should stay
consistent for a given physical turn direction. Ctrl+C to quit and see
a summary.
"""

import argparse
from datetime import datetime
from gpiozero import RotaryEncoder, Button
from signal import pause

PINS = {
    "octave": {"a": 5, "b": 6, "button": 8},
    "font": {"a": 26, "b": 16, "button": 7},
}

counts = {"CW": 0, "CCW": 0, "press": 0}


def timestamp():
    return datetime.now().strftime("%H:%M:%S.%f")[:-3]


def main():
    parser = argparse.ArgumentParser(description="ChromaCade EC11 encoder test")
    parser.add_argument("--which", required=True, choices=sorted(PINS.keys()), help="which encoder to test")
    parser.add_argument("--button-pin", type=int, default=None, help="override the button GPIO, e.g. for retesting on a different pin")
    args = parser.parse_args()

    pins = dict(PINS[args.which])
    if args.button_pin is not None:
        pins["button"] = args.button_pin
    print(f"ChromaCade encoder test -- {args.which} "
          f"(A=GPIO{pins['a']}, B=GPIO{pins['b']}, Button=GPIO{pins['button']})")
    print("=" * 70)
    print("Turn the shaft through several detents each direction -- each click")
    print("should register exactly once, direction should stay consistent.")
    print("Press the button a few times too. Ctrl+C to quit for a summary.")
    print("=" * 70)

    encoder = RotaryEncoder(pins["a"], pins["b"], max_steps=0)
    button = Button(pins["button"], pull_up=True, bounce_time=0.02)

    def on_clockwise():
        counts["CW"] += 1
        print(f"[{timestamp()}] ROTATE  CW   steps={encoder.steps:<5} (CW count={counts['CW']})")

    def on_counter_clockwise():
        counts["CCW"] += 1
        print(f"[{timestamp()}] ROTATE  CCW  steps={encoder.steps:<5} (CCW count={counts['CCW']})")

    def on_press():
        counts["press"] += 1
        print(f"[{timestamp()}] PRESS   button (count={counts['press']})")

    def on_release():
        print(f"[{timestamp()}] release button")

    encoder.when_rotated_clockwise = on_clockwise
    encoder.when_rotated_counter_clockwise = on_counter_clockwise
    button.when_pressed = on_press
    button.when_released = on_release

    try:
        pause()
    except KeyboardInterrupt:
        pass

    print("\n" + "=" * 70)
    print(f"CW clicks: {counts['CW']}   CCW clicks: {counts['CCW']}   "
          f"Button presses: {counts['press']}   Final raw steps: {encoder.steps}")
    print("=" * 70)


if __name__ == "__main__":
    main()
