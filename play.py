#!/usr/bin/env python3
"""
ChromaCade -- play notes with the real button panel via FluidSynth.

Current scope: 7 note buttons, fixed C4 octave, Acoustic Grand Piano.
No accidentals/octave-shift/pitch-bend/volume/font yet -- those come
with their own firmware items.

Usage:
    python3 play.py

Ctrl+C to quit.
"""

from signal import pause

from audio_engine import ChromaCadeAudio
from hardware_poller import HardwarePoller


def main():
    audio = ChromaCadeAudio()

    def note_on(letter):
        print(f"PRESS   {letter}")
        audio.note_on(letter)

    def note_off(letter):
        print(f"release {letter}")
        audio.note_off(letter)

    # Must stay referenced for the life of the program -- if this gets
    # garbage collected, its gpiozero Button objects go with it and the
    # buttons silently stop working with no error (bit us once already).
    poller = HardwarePoller(on_note_on=note_on, on_note_off=note_off)

    print("ChromaCade is live -- press the note buttons (C D E F G A B). Ctrl+C to quit.")
    try:
        pause()
    except KeyboardInterrupt:
        pass
    finally:
        audio.quit()
        print("\nDone.")


if __name__ == "__main__":
    main()
