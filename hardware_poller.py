"""
ChromaCade -- hardware polling layer, GPIO controls -> callbacks.

Current scope: note buttons only (C-D-E-F-G-A-B). Octave/font encoders,
the flat/sharp rocker, joystick, and volume pot will extend this as
their firmware items land -- see docs/open-questions.md and
feature-spec.md for what's still undecided about each control's
behavior before wiring it in here.

Uses gpiozero throughout, not raw RPi.GPIO -- proven reliable during
this build's control bring-up (note_buttons_test.py, encoder_test.py,
rocker_test.py, all in testing/).

Not unit tested -- this logic needs real buttons to validate
meaningfully rather than mocking GPIO. audio_engine.py's note math is
where the hardware-free, pytest-covered logic lives.
"""

from gpiozero import Button

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


class HardwarePoller:
    def __init__(self, on_note_on, on_note_off):
        self.buttons = {}
        for letter, pin in NOTE_PINS.items():
            btn = Button(pin, pull_up=True, bounce_time=BOUNCE_TIME)
            btn.when_pressed = self._bind(letter, on_note_on)
            btn.when_released = self._bind(letter, on_note_off)
            self.buttons[letter] = btn

    @staticmethod
    def _bind(letter, callback):
        def handler():
            callback(letter)

        return handler
