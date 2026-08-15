#!/usr/bin/env python3
"""
ChromaCade -- play notes with the real button panel via FluidSynth,
LED ring lit per note, octave encoder / flat-sharp rocker / pitch-bend
joystick all shift whatever's held live. Bending far enough crosses
the ring's color to the neighboring letter (see audio_engine.py's
bent_letter() for why E/B cross with much less bend than the other
five letters -- E-F and B-C are the diatonic scale's two half-steps).

Current scope: 7 note buttons, font encoder cycling the curated voice
list (audio_engine.py's FONTS -- rotation only, its push-button is
deliberately unwired, see hardware_poller.py), octave encoder
(debounced -- see octave_gesture.py), flat/sharp rocker, pitch-bend
joystick (+-4 semitone range -- see audio_engine.py's
MAX_BEND_SEMITONES), volume pot (capped by VOLUME_CEILING regardless of
how far it's turned), ring shows whichever held note was pressed most
recently (bent toward its neighbor as above) -- a placeholder, not the
real chord-blend behavior (see led_ring.py). No OLED yet -- that's its
own firmware item.

Needs sudo -- the LED ring uses PWM/DMA hardware, same as
testing/led_ring_test.py.

Usage:
    sudo python3 play.py

Ctrl+C to quit.
"""

from signal import pause

from audio_engine import ChromaCadeAudio, bent_letter
from hardware_poller import HardwarePoller
from led_ring import LedRing


def main():
    audio = ChromaCadeAudio()
    ring = LedRing()
    held = []
    state = {"bend": 0.0, "shown": None}

    def update_ring():
        if not held:
            ring.clear()
            state["shown"] = None
            return
        letter = bent_letter(held[-1], state["bend"])
        if letter != state["shown"]:
            if state["shown"] is not None:
                print(f"COLOR   {state['shown']} -> {letter} (bend crossed the halfway point)")
            ring.show(letter)
            state["shown"] = letter

    def note_on(letter):
        print(f"PRESS   {letter}")
        audio.note_on(letter)
        held.append(letter)
        update_ring()

    def note_off(letter):
        print(f"release {letter}")
        audio.note_off(letter)
        if letter in held:
            held.remove(letter)
        update_ring()

    def octave_change(delta):
        audio.octave_change(delta)
        print(f"OCTAVE  {'+1' if delta > 0 else '-1'} -> now {audio.octave}")

    def accidental_change(accidental):
        audio.accidental_change(accidental)
        label = {-1: "FLAT", 0: "NATURAL", 1: "SHARP"}[accidental]
        print(f"ROCKER  {label}")

    def pitch_bend(bend_fraction):
        # No PRESS-style print here -- this fires ~50x/sec
        # (ADS1115_POLL_INTERVAL in hardware_poller.py), unlike the
        # other controls' discrete events. update_ring() only prints
        # when the displayed letter actually crosses over.
        audio.set_pitch_bend(bend_fraction)
        state["bend"] = bend_fraction
        update_ring()

    def volume_change(volume_fraction):
        # Same reasoning as pitch_bend -- fires continuously, no print.
        audio.set_volume(volume_fraction)

    def font_change(delta):
        audio.font_change(delta)
        print(f"FONT    -> {audio.font_name}")

    # Must stay referenced for the life of the program -- if this gets
    # garbage collected, its gpiozero Button objects go with it and the
    # buttons silently stop working with no error (bit us once already).
    poller = HardwarePoller(
        on_note_on=note_on,
        on_note_off=note_off,
        on_octave_change=octave_change,
        on_accidental_change=accidental_change,
        on_pitch_bend=pitch_bend,
        on_volume_change=volume_change,
        on_font_change=font_change,
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
