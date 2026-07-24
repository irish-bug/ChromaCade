#!/usr/bin/env python3
"""
ChromaCade -- generic melody player.

Plays a sequence of (note, duration) pairs through FluidSynth, reusing
the engine/gain settings confirmed working in fluidsynth_test.py. Not
tied to any specific song -- fill in MELODY below with whatever notes
you want to hear, read off your own sheet music.

Notes can be MIDI numbers (60 = middle C) or plain note names like
"C4", "F#4", "Bb3". Duration is in beats; --tempo sets beats per minute.

Prerequisites: same as fluidsynth_test.py
    sudo apt install fluidsynth fluid-soundfont-gm
    pip3 install pyfluidsynth --break-system-packages

Usage:
    python3 play_melody.py
    python3 play_melody.py --device plughw:1,0 --tempo 100 --program 0
"""

import argparse
import re
import sys
import time

try:
    import fluidsynth
except ImportError:
    print("Missing dependency. Install with:")
    print("    pip3 install pyfluidsynth --break-system-packages")
    sys.exit(1)

SOUNDFONT_PATH = "/usr/share/sounds/sf2/FluidR3_GM.sf2"

# --- Fill this in yourself: list of (note, duration_in_beats) ---
# note = MIDI number (60=middle C) or name like "F4", "C#5", "Bb3"
# duration = length in beats (1.0 = quarter note at the given tempo)
MELODY = [
    ("C4", 1.0),
    ("D4", 1.0),
    ("E4", 1.0),
    ("C4", 1.0),
]
# ------------------------------------------------------------------

NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note_to_midi(note):
    if isinstance(note, int):
        return note
    m = re.match(r"^([A-Ga-g])(#|b)?(-?\d+)$", note.strip())
    if not m:
        raise ValueError(f"Can't parse note name: {note!r} (expected e.g. 'C4', 'F#3', 'Bb5')")
    letter, accidental, octave = m.groups()
    semitone = NOTE_NAMES[letter.upper()]
    if accidental == "#":
        semitone += 1
    elif accidental == "b":
        semitone -= 1
    return (int(octave) + 1) * 12 + semitone


def main():
    parser = argparse.ArgumentParser(description="ChromaCade generic melody player")
    parser.add_argument("--device", default=None, help="ALSA device, e.g. plughw:1,0")
    parser.add_argument("--program", type=int, default=0, help="GM program number 0-127 (default 0 = Acoustic Grand Piano)")
    parser.add_argument("--tempo", type=float, default=120.0, help="beats per minute (default 120)")
    parser.add_argument("--gain", type=float, default=3.0, help="synth.gain (default 3.0)")
    args = parser.parse_args()

    seconds_per_beat = 60.0 / args.tempo

    fs = fluidsynth.Synth()
    fs.setting("audio.driver", "alsa")
    fs.setting("synth.gain", args.gain)
    if args.device:
        fs.setting("audio.alsa.device", args.device)
    fs.start()

    try:
        sfid = fs.sfload(SOUNDFONT_PATH)
    except Exception:
        sfid = -1
    if sfid == -1:
        print(f"ERROR: couldn't load soundfont at {SOUNDFONT_PATH}")
        fs.delete()
        sys.exit(1)

    fs.program_select(0, sfid, 0, args.program)
    print(f"Playing {len(MELODY)} notes at {args.tempo} BPM...")

    for note, duration in MELODY:
        midi_note = note_to_midi(note)
        fs.noteon(0, midi_note, 100)
        time.sleep(duration * seconds_per_beat)
        fs.noteoff(0, midi_note)

    time.sleep(0.5)
    fs.delete()
    print("Done.")


if __name__ == "__main__":
    main()
