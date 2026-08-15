#!/usr/bin/env python3
"""
ChromaCade -- Tutor/follow-along mode (feature-spec.md's Simon / Learn
mode section, the Tutor sub-mode specifically -- not Simon Says memory
mode, which isn't built yet). Two phases, both from tutor_songs.py's
SCORES/SONGS data (see that module's docstring for the data format and
why the demo and the game can't drift out of sync with each other):

  1. Demo playback -- the song plays once through FluidSynth with the
     LED ring showing each note's color as it sounds. Console print
     stands in for the OLED note-name readout (OLED isn't wired yet --
     its own undone firmware item, see play.py's docstring).
  2. Color-matching game -- the ring shows the next note's color and
     waits for the child to press the matching button before
     advancing; a wrong press doesn't penalize, it just doesn't
     advance (see TutorSession in tutor_songs.py).

The demo phase runs before HardwarePoller exists, deliberately -- it's
a blocking, timed sequence, and starting the poller only for phase 2
avoids note-button presses during the demo doing anything confusing
(no matching-game state exists yet at that point, so a press would
have nothing to check against). A curious kid mashing buttons during
the demo gets silence until it finishes, which is a real v1 tradeoff,
not an oversight -- flag if that's wrong.

v1 scope, deliberately narrow -- see open-questions.md's Menu /
Simon-Learn mode section for what's still undecided:
  - One hardcoded song per run (--song), no in-device song-selection UI
    (that's still an open menu-design question).
  - No menu-entry gesture integration -- run directly, same as play.py
    is run directly today (no menu system exists yet for normal play
    mode either).
  - Natural notes only -- all bundled songs are Tier 1 in
    feature-spec.md's Candidate song library (no accidentals), so the
    rocker/joystick-bend accidental mechanic from open-questions.md
    isn't needed yet and isn't implemented here.
  - During the matching-game phase, octave encoder / rocker / joystick
    / font encoder are still wired to their normal play.py behavior --
    a curious kid poking at them gets real audio/visual feedback -- but
    none of them affect the note-matching logic, only the 7 note
    buttons do.

Needs sudo -- same as play.py (LED ring PWM/DMA).

Usage:
    sudo python3 tutor_mode.py --song "Hot Cross Buns"
    sudo python3 tutor_mode.py --list
    sudo python3 tutor_mode.py --song "Twinkle Twinkle Little Star" --tempo 80

Ctrl+C to quit (works during either phase).
"""

import argparse
import sys
import time
from signal import pause

from audio_engine import ChromaCadeAudio, FONTS
from hardware_poller import HardwarePoller
from led_ring import LedRing
from tutor_songs import SCORES, SONGS, TutorSession, parse_note_name

DEFAULT_TEMPO = 90  # BPM -- slower than play_melody.py's 120 default, toddler-paced

# ChromaCadeAudio defaults to Organ (audio_engine.py's DEFAULT_PROGRAM),
# which has no decay -- repeated same-pitch notes with no gap between
# them (e.g. Hot Cross Buns' "C C C C" run) blend into what sounds like
# one continuous held note instead of distinct repeated presses. Toy
# Piano has a percussive attack/decay, so repeats stay audibly separate.
# Confirmed live 2026-08-15. Scoped to tutor_mode.py only -- play.py's
# default is a separate, general-play preference, not touched here.
TUTOR_PROGRAM = next(program for program, name in FONTS if name == "Toy Piano")


def play_demo(audio, ring, score, seconds_per_beat):
    """Blocking, timed playthrough of one song's SCORES entry -- see
    module docstring for why this runs before HardwarePoller exists."""
    for note_name, duration in score:
        if note_name is None:
            ring.clear()
            time.sleep(duration * seconds_per_beat)
            continue
        letter, octave, accidental = parse_note_name(note_name)
        audio.octave = octave
        audio.accidental = accidental
        print(f"NOTE    {note_name}")
        ring.show(letter)
        audio.note_on(letter)
        time.sleep(duration * seconds_per_beat)
        audio.note_off(letter)
    ring.clear()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--song", default="Hot Cross Buns", help="Song to play (see --list)"
    )
    parser.add_argument("--list", action="store_true", help="List available songs and exit")
    parser.add_argument(
        "--tempo", type=float, default=DEFAULT_TEMPO, help=f"beats per minute (default {DEFAULT_TEMPO})"
    )
    args = parser.parse_args()

    if args.list:
        for name in SONGS:
            print(name)
        return

    if args.song not in SCORES:
        print(f"Unknown song {args.song!r}. Use --list to see options.", file=sys.stderr)
        sys.exit(1)

    seconds_per_beat = 60.0 / args.tempo
    audio = ChromaCadeAudio(program=TUTOR_PROGRAM)
    ring = LedRing()

    try:
        print(f"ChromaCade Tutor mode -- {args.song}. Watch and listen first...")
        play_demo(audio, ring, SCORES[args.song], seconds_per_beat)

        print("Now you try! Match the color, in any octave. Ctrl+C to quit.")
        session = TutorSession(SONGS[args.song])

        def show_target():
            if session.is_complete():
                print(f"DONE    {args.song} complete!")
                ring.clear()
            else:
                print(f"CUE     {session.target}")
                ring.show(session.target)

        def note_on(letter):
            audio.note_on(letter)
            if session.press(letter):
                print(f"MATCH   {letter}")
                show_target()
            else:
                print(f"MISS    {letter} (wanted {session.target})")

        def note_off(letter):
            audio.note_off(letter)

        # Octave/rocker/joystick/font: pass straight through to normal
        # ChromaCadeAudio behavior, same as play.py -- none of these
        # touch TutorSession, only the 7 note buttons matter for
        # progression.
        def octave_change(delta):
            audio.octave_change(delta)

        def accidental_change(accidental):
            audio.accidental_change(accidental)

        def pitch_bend(bend_fraction):
            audio.set_pitch_bend(bend_fraction)

        def volume_change(volume_fraction):
            audio.set_volume(volume_fraction)

        def font_change(delta):
            audio.font_change(delta)

        # Must stay referenced for the life of the program -- see
        # play.py's identical note on this (garbage-collected poller
        # silently kills the buttons).
        poller = HardwarePoller(
            on_note_on=note_on,
            on_note_off=note_off,
            on_octave_change=octave_change,
            on_accidental_change=accidental_change,
            on_pitch_bend=pitch_bend,
            on_volume_change=volume_change,
            on_font_change=font_change,
        )

        show_target()
        try:
            pause()
        except KeyboardInterrupt:
            pass
        finally:
            # Same shutdown order as play.py, same reason: stop the
            # background poller before freeing FluidSynth or it can
            # segfault on a use-after-free.
            poller.stop()
    except KeyboardInterrupt:
        pass
    finally:
        ring.clear()
        audio.quit()
        print("\nDone.")


if __name__ == "__main__":
    main()
