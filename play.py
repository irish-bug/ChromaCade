#!/usr/bin/env python3
"""
ChromaCade -- play notes with the real button panel via FluidSynth,
LED ring lit per note, octave encoder / flat-sharp rocker / pitch-bend
joystick all shift whatever's held live.

Current scope: 7 note buttons, Acoustic Grand Piano, octave encoder
(debounced -- see octave_gesture.py), flat/sharp rocker, pitch-bend
joystick (+-0.5 semitone starting range -- see audio_engine.py's
MAX_BEND_SEMITONES), ring shows whichever held note was pressed most
recently -- a placeholder, not the real chord-blend behavior (see
led_ring.py). No volume/font/OLED yet -- those come with their own
firmware items.

Needs sudo -- the LED ring uses PWM/DMA hardware, same as
testing/led_ring_test.py.

Usage:
    sudo python3 play.py

Ctrl+C to quit.
"""

from signal import pause

from audio_engine import ChromaCadeAudio
from hardware_poller import HardwarePoller
from led_ring import LedRing


def main():
    audio = ChromaCadeAudio()
    ring = LedRing()
    held = []

    def note_on(letter):
        print(f"PRESS   {letter}")
        audio.note_on(letter)
        held.append(letter)
        ring.show(letter)

    def note_off(letter):
        print(f"release {letter}")
        audio.note_off(letter)
        if letter in held:
            held.remove(letter)
        ring.show(held[-1]) if held else ring.clear()

    def octave_change(delta):
        audio.octave_change(delta)
        print(f"OCTAVE  {'+1' if delta > 0 else '-1'} -> now {audio.octave}")

    def accidental_change(accidental):
        audio.accidental_change(accidental)
        label = {-1: "FLAT", 0: "NATURAL", 1: "SHARP"}[accidental]
        print(f"ROCKER  {label}")

    def pitch_bend(bend_fraction):
        # No print here -- this fires ~30x/sec (JOYSTICK_POLL_INTERVAL
        # in hardware_poller.py), unlike the other controls' discrete
        # events, so printing every tick would just flood the terminal.
        audio.set_pitch_bend(bend_fraction)

    # Must stay referenced for the life of the program -- if this gets
    # garbage collected, its gpiozero Button objects go with it and the
    # buttons silently stop working with no error (bit us once already).
    poller = HardwarePoller(
        on_note_on=note_on,
        on_note_off=note_off,
        on_octave_change=octave_change,
        on_accidental_change=accidental_change,
        on_pitch_bend=pitch_bend,
    )

    print("ChromaCade is live -- press the note buttons (C D E F G A B). Ctrl+C to quit.")
    try:
        pause()
    except KeyboardInterrupt:
        pass
    finally:
        ring.clear()
        audio.quit()
        print("\nDone.")


if __name__ == "__main__":
    main()
