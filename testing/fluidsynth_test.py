#!/usr/bin/env python3
"""
ChromaCade -- FluidSynth engine smoke test.

Confirms FluidSynth can load the FluidR3_GM General MIDI soundfont and
play a note through this unit's existing ALSA audio path (the
hifiberry-dac overlay, the same output already confirmed working by
audio_test.py). This is a proof-of-concept step toward replacing
audio_engine.py's sine-wave stub with real GM instrument timbres for
the font/voice encoder -- informed by a separate project (nektar-synth)
already running fluidsynth this same way on identical Pi Zero 2W
hardware.

Prerequisites:
    sudo apt install fluidsynth fluid-soundfont-gm
    pip3 install pyfluidsynth --break-system-packages

(pyfluidsynth itself is pip-only on this OS -- confirmed not available
via apt on Debian trixie. fluidsynth and the soundfont ARE apt
packages, no pip needed for those.)

Usage:
    python3 fluidsynth_test.py
    python3 fluidsynth_test.py --device hw:0,0 --program 10 --note 60 --seconds 3

Plays a single note (default: GM program 0 = Acoustic Grand Piano,
MIDI note 60 = middle C) for a few seconds through the given ALSA
device, then stops cleanly. Pure hardware/software smoke test -- does
NOT touch audio_engine.py or hardware_poller.py, and isn't wired into
the GPIO polling loop. See docs/fontlist.txt-equivalent patch numbers
once picking a curated list (same technique as nektar-synth: run
`fluidsynth -i` then `inst 1` against the soundfont to get readable
names for every program number).
"""

import argparse
import sys
import time

try:
    import fluidsynth
except ImportError:
    print("Missing dependency. Install with:")
    print("    pip3 install pyfluidsynth --break-system-packages")
    print("(also requires the shared library: sudo apt install fluidsynth fluid-soundfont-gm)")
    sys.exit(1)

SOUNDFONT_PATH = "/usr/share/sounds/sf2/FluidR3_GM.sf2"


def main():
    parser = argparse.ArgumentParser(description="ChromaCade FluidSynth smoke test")
    parser.add_argument("--device", default=None, help="ALSA device, e.g. hw:0,0 (default: fluidsynth's own default)")
    parser.add_argument("--program", type=int, default=0, help="GM program number 0-127 (default 0 = Acoustic Grand Piano)")
    parser.add_argument("--note", type=int, default=60, help="MIDI note number (default 60 = middle C)")
    parser.add_argument("--seconds", type=float, default=2.0, help="how long to hold the note (default 2.0)")
    args = parser.parse_args()

    print("ChromaCade FluidSynth smoke test")
    print("=" * 60)

    fs = fluidsynth.Synth()
    fs.setting("audio.driver", "alsa")
    if args.device:
        fs.setting("audio.alsa.device", args.device)
    fs.start()

    try:
        sfid = fs.sfload(SOUNDFONT_PATH)
    except Exception as e:
        print(f"ERROR: couldn't load soundfont at {SOUNDFONT_PATH} ({e})")
        print("Confirm `fluid-soundfont-gm` is installed (apt) and that path is correct --")
        print("check with: dpkg -L fluid-soundfont-gm | grep sf2")
        sys.exit(1)

    fs.program_select(0, sfid, 0, args.program)
    print(f"Soundfont loaded. GM program {args.program}, playing note {args.note} for {args.seconds}s...")

    fs.noteon(0, args.note, 100)
    time.sleep(args.seconds)
    fs.noteoff(0, args.note)
    time.sleep(0.5)  # let the release tail finish before shutdown

    fs.delete()
    print("Done. If you heard a note, FluidSynth is confirmed working on this hardware.")
    print("If silent: re-check --device against `aplay -l`'s hifiberry card, same as audio_test.py.")


if __name__ == "__main__":
    main()
