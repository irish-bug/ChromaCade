"""
ChromaCade -- hardware polling layer, GPIO controls -> callbacks.

Current scope: note buttons (including the menu-gesture long-press on
the two edge buttons), both encoders' rotation and push-buttons, the
flat/sharp rocker, the pitch-bend joystick, and the volume pot.

Uses gpiozero throughout for digital controls, not raw RPi.GPIO --
proven reliable during this build's control bring-up
(note_buttons_test.py, encoder_test.py, rocker_test.py, all in
testing/). The joystick and volume pot are both analog, both on the
same ADS1115 over I2C (same setup as testing/ads1115_test.py), and
have no interrupt mechanism -- unlike everything else here, both are
read from a single shared background polling thread rather than event
callbacks. One thread, not two, deliberately: they're on the same I2C
bus, and I2C isn't safe for two threads to hit concurrently without a
lock, so both channels are read from the same loop each cycle instead.

Font encoder push-button (GPIO7) and octave encoder push-button
(GPIO8) are both wired now (2026-08-15) -- control-layout.md's menu
grammar: hold *both* encoder push-buttons together for ~1.5s, no note
button involved. This is a further-simplified version of an earlier
design that also required long-pressing an edge note button (C=exit,
B=enter) alongside the two encoder holds -- dropped 2026-08-16 as an
unnecessary extra step once both encoder push-buttons were already a
reliably rare, inherently two-handed signal on their own (one on each
end of the shelf, per control-layout.md). See chromacade.py for how
on_menu_toggle gets used, and control-layout.md for the gesture
writeup and its history (originally A/G + font-button-only, then
C/B + both-encoder-buttons, now both-encoder-buttons alone).

Not unit tested -- this logic needs real hardware to validate
meaningfully rather than mocking GPIO/I2C. audio_engine.py's note math
(including rocker_accidental(), joystick_bend_fraction(),
pot_volume_fraction(), and font_index_change()) and
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

from audio_engine import (
    joystick_bend_fraction,
    pot_volume_fraction,
    rocker_accidental,
    smooth,
)
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
OCTAVE_BTN_PIN = 8

# How long a gesture stays "active" (absorbing further clicks) after
# the last rotation before the next turn is allowed to fire again --
# see octave_gesture.py for why a whole burst of clicks only ever moves
# one octave. Doesn't gate responsiveness (that's instant, leading-edge)
# -- only gates how forgiving a single slow continuous turn is against
# accidentally re-firing partway through. Starting guess, tune live.
OCTAVE_GESTURE_PAUSE = 0.4

FLAT_PIN = 23
SHARP_PIN = 24

FONT_ENC_A = 26
FONT_ENC_B = 16
FONT_BTN_PIN = 7

# Menu toggle gesture -- see module docstring and control-layout.md.
# Both encoder push-buttons held together continuously for this long
# fires on_menu_toggle; releasing either before then cancels it.
MENU_GESTURE_HOLD_SECONDS = 1.5  # control-layout.md's "~1.5s"

# Short click of the font button alone (no long-press, no gesture)
# selects a highlighted menu option -- control-layout.md's "Select a
# highlighted option: short click of the font encoder's push-button".
# Comfortably below MENU_GESTURE_HOLD_SECONDS so a real gesture
# in-progress is never misread as a click on release.
FONT_CLICK_MAX_SECONDS = 0.5

ADS1115_ADDRESS = 0x48
# Plain ints, not ADS.P0/P1 -- see testing/ads1115_test.py for why
# (dropped in adafruit-circuitpython-ads1x15 3.0.5)
JOYSTICK_ADS_CHANNEL = 0
VOLUME_ADS_CHANNEL = 1

# How often to re-read the joystick and pot (shared loop, see module
# docstring). No interrupt mechanism for an analog value, so this
# trades I2C traffic against how smooth the bend/volume feels. Bumped
# 30Hz -> 50Hz 2026-08-15 after live testing felt "jumpy" -- tune
# further if it still feels laggy or jittery.
ADS1115_POLL_INTERVAL = 1 / 50

# Exponential-smoothing weight for the raw voltage readings (see
# audio_engine.smooth()) -- added 2026-08-15 alongside the poll-rate
# bump, same "felt jumpy" live feedback on the joystick. Reused as-is
# for the pot for now; tune independently if the pot ends up needing a
# different feel.
JOYSTICK_SMOOTHING_ALPHA = 0.4
VOLUME_SMOOTHING_ALPHA = 0.4


class HardwarePoller:
    def __init__(
        self,
        on_note_on,
        on_note_off,
        on_octave_change,
        on_accidental_change,
        on_pitch_bend,
        on_volume_change,
        on_font_change,
        on_font_click=None,
        on_menu_toggle=None,
    ):
        # New 2026-08-15, all optional/default-None so existing callers
        # (play.py, tutor_mode.py) don't need to change -- they just get
        # no menu-gesture/click behavior, same as before this existed.
        self.on_font_click = on_font_click
        self.on_menu_toggle = on_menu_toggle
        self._font_press_time = None
        self._menu_gesture_timer = None
        self._menu_gesture_lock = threading.Lock()

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

        # Octave encoder's own push-button -- previously wired for
        # rotation only (open-questions.md flagged its click as having
        # "no assigned function"). That's resolved now: it's one of the
        # two buttons in the menu-toggle gesture (see
        # _on_encoder_buttons_changed below and module docstring) --
        # not read for any other purpose yet.
        self.octave_button = Button(OCTAVE_BTN_PIN, pull_up=True, bounce_time=BOUNCE_TIME)
        self.octave_button.when_pressed = self._on_encoder_buttons_changed
        self.octave_button.when_released = self._on_encoder_buttons_changed

        # Font encoder's push-button -- previously entirely unwired.
        # Two behaviors: short click -> on_font_click (menu select), and
        # it's the other button in the menu-toggle gesture. Its own
        # press/release also feed _on_encoder_buttons_changed, which
        # runs the actual hold-timer for the gesture (see below) --
        # this handler pair just additionally tracks the press
        # timestamp for the separate short-click check.
        self.font_button = Button(FONT_BTN_PIN, pull_up=True, bounce_time=BOUNCE_TIME)
        self.font_button.when_pressed = self._on_font_button_pressed
        self.font_button.when_released = self._on_font_button_released

        self.on_accidental_change = on_accidental_change
        self.flat_button = Button(FLAT_PIN, pull_up=True, bounce_time=BOUNCE_TIME)
        self.sharp_button = Button(SHARP_PIN, pull_up=True, bounce_time=BOUNCE_TIME)
        for btn in (self.flat_button, self.sharp_button):
            btn.when_pressed = self._on_rocker_change
            btn.when_released = self._on_rocker_change

        self.on_pitch_bend = on_pitch_bend
        self.on_volume_change = on_volume_change
        i2c = busio.I2C(board.SCL, board.SDA)
        ads = ADS.ADS1115(i2c, address=ADS1115_ADDRESS)
        ads.gain = 1  # +/-4.096V full-scale, matches ads1115_test.py --
                      # better resolution than default +/-6.144V on this 3.3V supply
        self.joystick_chan = AnalogIn(ads, JOYSTICK_ADS_CHANNEL)
        self.volume_chan = AnalogIn(ads, VOLUME_ADS_CHANNEL)

        self._stop_event = threading.Event()
        self._ads1115_thread = threading.Thread(target=self._poll_ads1115, daemon=True)
        self._ads1115_thread.start()

        self.on_font_change = on_font_change
        self.font_encoder = RotaryEncoder(FONT_ENC_A, FONT_ENC_B, max_steps=0)
        # Same confirmed rotation inversion as the octave encoder
        # (gpio-pin-assignments.md) -- physical CW reads as CCW via
        # gpiozero and vice versa.
        self.font_encoder.when_rotated_clockwise = lambda: self.on_font_change(-1)
        self.font_encoder.when_rotated_counter_clockwise = lambda: self.on_font_change(1)

    @staticmethod
    def _bind(letter, callback):
        def handler():
            callback(letter)

        return handler

    def _on_encoder_buttons_changed(self):
        """Runs on every press/release of either encoder push-button.
        Starts a MENU_GESTURE_HOLD_SECONDS timer the moment both are
        simultaneously down, cancels it the moment either comes back up
        -- so on_menu_toggle only fires if both stayed held the whole
        time, not just at one checked instant. Lock-guarded because
        gpiozero calls each button's callbacks on its own thread, and
        the two buttons' events can land close enough together to race
        on _menu_gesture_timer otherwise."""
        with self._menu_gesture_lock:
            both_held = self.font_button.is_pressed and self.octave_button.is_pressed
            if both_held and self._menu_gesture_timer is None:
                self._menu_gesture_timer = threading.Timer(
                    MENU_GESTURE_HOLD_SECONDS, self._fire_menu_gesture
                )
                self._menu_gesture_timer.start()
            elif not both_held and self._menu_gesture_timer is not None:
                self._menu_gesture_timer.cancel()
                self._menu_gesture_timer = None

    def _fire_menu_gesture(self):
        with self._menu_gesture_lock:
            self._menu_gesture_timer = None
        if self.on_menu_toggle:
            self.on_menu_toggle()

    def _on_font_button_pressed(self):
        self._font_press_time = time.monotonic()
        self._on_encoder_buttons_changed()

    def _on_font_button_released(self):
        self._on_encoder_buttons_changed()
        if self._font_press_time is None:
            return
        held_seconds = time.monotonic() - self._font_press_time
        self._font_press_time = None
        if held_seconds < FONT_CLICK_MAX_SECONDS and self.on_font_click:
            self.on_font_click()

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

    def _poll_ads1115(self):
        smoothed_joy_voltage = self.joystick_chan.voltage
        smoothed_pot_voltage = self.volume_chan.voltage
        while not self._stop_event.is_set():
            smoothed_joy_voltage = smooth(
                smoothed_joy_voltage, self.joystick_chan.voltage, JOYSTICK_SMOOTHING_ALPHA
            )
            self.on_pitch_bend(joystick_bend_fraction(smoothed_joy_voltage))

            smoothed_pot_voltage = smooth(
                smoothed_pot_voltage, self.volume_chan.voltage, VOLUME_SMOOTHING_ALPHA
            )
            self.on_volume_change(pot_volume_fraction(smoothed_pot_voltage))

            time.sleep(ADS1115_POLL_INTERVAL)

    def stop(self):
        """Cleanly stops all background activity that calls into
        ChromaCadeAudio -- MUST be called and allowed to finish before
        ChromaCadeAudio.quit() (which frees the underlying FluidSynth C
        object). Without this, the polling thread or a pending
        octave-gesture timer can call into FluidSynth after that object
        is already freed -- a use-after-free that segfaults the whole
        process rather than raising a catchable Python error. Confirmed
        live 2026-08-15."""
        if self._octave_timer:
            self._octave_timer.cancel()
        self._stop_event.set()
        self._ads1115_thread.join()
