"""
ChromaCade -- hardware polling layer, GPIO controls -> callbacks.

Current scope: note buttons, the octave encoder, the flat/sharp rocker,
and the pitch-bend joystick. Font encoder and volume pot will extend
this as their firmware items land -- see docs/open-questions.md and
feature-spec.md for what's still undecided about each control's
behavior before wiring it in here.

Uses gpiozero throughout for digital controls, not raw RPi.GPIO --
proven reliable during this build's control bring-up
(note_buttons_test.py, encoder_test.py, rocker_test.py, all in
testing/). The joystick is analog (via the ADS1115 over I2C, same
setup as testing/ads1115_test.py) and has no interrupt mechanism, so
unlike everything else here it's read via a background polling thread
rather than an event callback.

Not unit tested -- this logic needs real hardware to validate
meaningfully rather than mocking GPIO/I2C. audio_engine.py's note math
(including rocker_accidental() and joystick_bend_fraction()) and
octave_gesture.py's debounce logic are where the hardware-free,
pytest-covered logic lives.
"""

import threading
import time

import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn
from gpiozero import Button, RotaryEncoder

from audio_engine import joystick_bend_fraction, rocker_accidental, smooth
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

FLAT_PIN = 23
SHARP_PIN = 24

ADS1115_ADDRESS = 0x48
JOYSTICK_ADS_CHANNEL = 0  # plain int, not ADS.P0 -- see testing/ads1115_test.py
                          # for why (dropped in adafruit-circuitpython-ads1x15 3.0.5)

# How often to re-read the joystick. No interrupt mechanism for an
# analog value, so this trades I2C traffic against how smooth the bend
# feels. Bumped 30Hz -> 50Hz 2026-08-15 after live testing felt
# "jumpy" -- tune further if it still feels laggy or jittery.
JOYSTICK_POLL_INTERVAL = 1 / 50

# Exponential-smoothing weight for the raw voltage reading (see
# audio_engine.smooth()) -- added 2026-08-15 alongside the poll-rate
# bump, same "felt jumpy" live feedback. Lower = smoother but more lag,
# higher = more responsive but more jitter. Starting guess, tune live.
JOYSTICK_SMOOTHING_ALPHA = 0.4


class HardwarePoller:
    def __init__(
        self,
        on_note_on,
        on_note_off,
        on_octave_change,
        on_accidental_change,
        on_pitch_bend,
    ):
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

        self.on_accidental_change = on_accidental_change
        self.flat_button = Button(FLAT_PIN, pull_up=True, bounce_time=BOUNCE_TIME)
        self.sharp_button = Button(SHARP_PIN, pull_up=True, bounce_time=BOUNCE_TIME)
        for btn in (self.flat_button, self.sharp_button):
            btn.when_pressed = self._on_rocker_change
            btn.when_released = self._on_rocker_change

        self.on_pitch_bend = on_pitch_bend
        i2c = busio.I2C(board.SCL, board.SDA)
        ads = ADS.ADS1115(i2c, address=ADS1115_ADDRESS)
        ads.gain = 1  # +/-4.096V full-scale, matches ads1115_test.py --
                      # better resolution than default +/-6.144V on this 3.3V supply
        self.joystick_chan = AnalogIn(ads, JOYSTICK_ADS_CHANNEL)

        self._joystick_thread = threading.Thread(target=self._poll_joystick, daemon=True)
        self._joystick_thread.start()

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

    def _on_rocker_change(self):
        accidental = rocker_accidental(
            flat_active=self.flat_button.is_pressed,
            sharp_active=self.sharp_button.is_pressed,
        )
        self.on_accidental_change(accidental)

    def _poll_joystick(self):
        smoothed_voltage = self.joystick_chan.voltage
        while True:
            smoothed_voltage = smooth(
                smoothed_voltage, self.joystick_chan.voltage, JOYSTICK_SMOOTHING_ALPHA
            )
            bend = joystick_bend_fraction(smoothed_voltage)
            self.on_pitch_bend(bend)
            time.sleep(JOYSTICK_POLL_INTERVAL)
