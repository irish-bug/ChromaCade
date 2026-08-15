"""
ChromaCade -- hardware polling layer, GPIO controls -> callbacks.

Current scope: note buttons and the octave encoder. Font encoder, the
flat/sharp rocker, joystick, and volume pot will extend this as their
firmware items land -- see docs/open-questions.md and feature-spec.md
for what's still undecided about each control's behavior before wiring
it in here.

Uses gpiozero throughout, not raw RPi.GPIO -- proven reliable during
this build's control bring-up (note_buttons_test.py, encoder_test.py,
rocker_test.py, all in testing/).

Not unit tested -- this logic needs real buttons/encoders to validate
meaningfully rather than mocking GPIO. audio_engine.py's note math and
octave_gesture.py's debounce logic are where the hardware-free,
pytest-covered logic lives.
"""

import threading

from gpiozero import Button, RotaryEncoder

from octave_gesture import OctaveGesture

# Note -> BCM pin, physical left-to-right order (gpio-pin-assignments.md).
# Letters relabeled 2026-08-15 (was A-G in physical order, now C-D-E-F-G-A-B
# matching the octave convention) -- same pins, same physical buttons.
NOTE_PINS = {
    "C": 4,
    "D": 17,
    "E": 27,
    "F": 22,
    "G": 10,
    "A": 9,
    "B": 11,
}

BOUNCE_TIME = 0.02

OCTAVE_ENC_A = 5
OCTAVE_ENC_B = 6

# How long a gesture stays "active" (absorbing further clicks) after
# the last rotation before the next turn is allowed to fire again --
# see octave_gesture.py for why a whole burst of clicks only ever moves
# one octave. Doesn't gate responsiveness (that's instant, leading-edge)
# -- only gates how forgiving a single slow continuous turn is against
# accidentally re-firing partway through. Starting guess, tune live.
OCTAVE_GESTURE_PAUSE = 0.4


class HardwarePoller:
    def __init__(self, on_note_on, on_note_off, on_octave_change):
        self.buttons = {}
        for letter, pin in NOTE_PINS.items():
            btn = Button(pin, pull_up=True, bounce_time=BOUNCE_TIME)
            btn.when_pressed = self._bind(letter, on_note_on)
            btn.when_released = self._bind(letter, on_note_off)
            self.buttons[letter] = btn

        self.on_octave_change = on_octave_change
        self._octave_gesture = OctaveGesture()
        self._octave_timer = None

        self.octave_encoder = RotaryEncoder(OCTAVE_ENC_A, OCTAVE_ENC_B, max_steps=0)
        # Confirmed inverted as wired (gpio-pin-assignments.md): physical
        # CW reads as CCW via gpiozero and vice versa -- swap here so the
        # rest of the app only ever deals in physical/intended direction.
        self.octave_encoder.when_rotated_clockwise = lambda: self._record_rotation("ccw")
        self.octave_encoder.when_rotated_counter_clockwise = lambda: self._record_rotation("cw")

    @staticmethod
    def _bind(letter, callback):
        def handler():
            callback(letter)

        return handler

    def _record_rotation(self, direction):
        delta = self._octave_gesture.rotate(direction)
        if self._octave_timer:
            self._octave_timer.cancel()
        self._octave_timer = threading.Timer(OCTAVE_GESTURE_PAUSE, self._end_octave_gesture)
        self._octave_timer.start()
        if delta:
            self.on_octave_change(delta)

    def _end_octave_gesture(self):
        self._octave_gesture.reset()
