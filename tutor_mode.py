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
     advancing; a wrong press doesn't advance and doesn't stop the
     song, it just gets a strip-only cue (ring keeps holding the
     target color throughout, undisturbed) -- a red flash + nope.wav,
     then a flash of the correct color as a reminder (see
     miss_feedback()). See TutorSession in tutor_songs.py for the
     match/no-penalty-on-miss logic itself. Completing the song
     triggers a brief ring+strip celebration flash, then the script
     exits on its own -- no need for Ctrl+C. There's no menu/game UI
     layer to hand control back to (same "run directly" scope as
     everything else in this v1 list below), so "what happens after
     you finish" has to be this script's own job for now.

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

Ctrl+C to quit early (works during either phase) -- finishing the song
normally exits on its own, see module docstring.
"""

import argparse
import sys
import threading
import time

from audio_engine import ChromaCadeAudio, FONTS
from hardware_poller import HardwarePoller
from led_ring import LedRing, NOTE_COLORS
from led_strip import LedStrip
from sound_pools import build_pools, play_wav
from tutor_songs import SCORES, SONGS, TutorSession, chord_cue_letter, parse_note_name, target_label

DEFAULT_TEMPO = 90  # BPM -- slower than play_melody.py's 120 default, toddler-paced

# "You did it!" cue after a song completes -- both the ring and the
# interior strip flash through these together (not a chase/alternation
# between the two chains, just synchronized). Reuses colors already
# tuned live on this hardware (color-palette.md's F/E/B ring hues)
# rather than picking new untested ones. Tune live once seen for real.
CELEBRATION_COLORS = [(0, 200, 0), (255, 170, 0), (255, 20, 147)]  # green, gold, pink
CELEBRATION_FLASH_SECONDS = 0.25


def celebrate(ring, strip, sound_path=None):
    """sound_path optional (default None, silent) -- chromacade.py
    passes a "big win" sound from sound_pools.py's shared cycler;
    tutor_mode.py's own standalone main() below does too now (fixed
    2026-08-16, was previously always silent here)."""
    if sound_path:
        play_wav(sound_path)
    for color in CELEBRATION_COLORS:
        ring.fill(color)
        strip.fill(color)
        time.sleep(CELEBRATION_FLASH_SECONDS)
        ring.clear()
        strip.clear()
        time.sleep(CELEBRATION_FLASH_SECONDS)


# Wrong-key cue -- strip only, ring is deliberately untouched (it's the
# persistent target cue -- feature-spec.md's "gently don't advance,
# keep the current note's cue lit" -- so the ring should hold steady
# through a miss, not react to it). Red flash + a sound together, then
# a flash of the correct color as a "here's what you want" reminder.
MISS_COLOR = (255, 0, 0)
MISS_FLASH_SECONDS = 0.2


def miss_feedback(strip, target_step, sound_path):
    """sound_path is required (not optional/defaulted) -- forces every
    caller to be explicit about which sound plays, on purpose: this
    used to hardcode a single nope.wav (see git history for the old
    NOPE_SOUND_PATH/play_nope_sound()), which silently kept playing
    even after sound_pools.py's audio/nopes/ pool was built, since
    nothing here was ever updated to use it. Confirmed live 2026-08-16
    -- caller (chromacade.py, or this module's own main() below) is
    now required to pass sound_pools.build_pools()["tutor_error"]
    .next() explicitly instead.

    target_step: a frozenset of letters (see tutor_songs.py) -- a
    single letter for an ordinary note, more for a chord. Accepts a
    bare single-character string too (wrapped as its own frozenset),
    so existing single-letter callers don't need to change. For a
    chord, the reminder-color flash shows only the last letter
    (sorted) -- same placeholder status as chromacade.py's
    cue_ring_for()/play_demo()'s chord-strike display, not a real
    multi-color design (still open, see led_ring.py's docstring)."""
    if not isinstance(target_step, frozenset):
        target_step = frozenset({target_step})
    play_wav(sound_path)
    strip.fill(MISS_COLOR)
    time.sleep(MISS_FLASH_SECONDS)
    strip.clear()
    time.sleep(MISS_FLASH_SECONDS)
    strip.fill(NOTE_COLORS[chord_cue_letter(target_step)])
    time.sleep(MISS_FLASH_SECONDS)
    strip.clear()


# ChromaCadeAudio defaults to Organ (audio_engine.py's DEFAULT_PROGRAM),
# which has no decay -- repeated same-pitch notes with no gap between
# them (e.g. Hot Cross Buns' "C C C C" run) blend into what sounds like
# one continuous held note instead of distinct repeated presses. Toy
# Piano has a percussive attack/decay, so repeats stay audibly separate.
# Confirmed live 2026-08-15. Scoped to tutor_mode.py only -- play.py's
# default is a separate, general-play preference, not touched here.
TUTOR_PROGRAM = next(program for program, name in FONTS if name == "Toy Piano")


def play_demo(audio, ring, score, seconds_per_beat, oled=None):
    """Blocking, timed playthrough of one song's SCORES entry -- see
    module docstring for why this runs before HardwarePoller exists.
    oled is optional (default None, matching every other new-callback
    pattern in this codebase) -- tutor_mode.py itself never had an
    OLED to drive, chromacade.py passes a real one so the demo's note
    names show up there instead of only in the console print.

    note_field (the first item of each score entry) is None (rest), a
    single note name, or a CHORD -- a list of 2+ note names played
    together, added 2026-09-02 (see tutor_songs.py's module
    docstring). A chord's notes are struck in list order (not
    simultaneously in the strictest sense -- Python has no true
    concurrent note_on, and this project doesn't need sample-accurate
    simultaneity for it to read as a chord to a listener) and released
    together after the shared duration. Ring color for a chord reuses
    led_ring.py's existing placeholder for "multiple notes held"
    (most-recently-triggered wins, ring.show() called once per note in
    order) rather than inventing a second, divergent chord-display
    behavior -- that question is explicitly still open project-wide,
    see led_ring.py's own docstring and open-questions.md's "Chord
    color behavior" entry."""
    for note_name, duration in score:
        if note_name is None:
            ring.clear()
            if oled:
                oled.show_lines(["Listen..."])
            time.sleep(duration * seconds_per_beat)
            continue
        chord_notes = note_name if isinstance(note_name, list) else [note_name]
        letters = []
        for one_note in chord_notes:
            letter, octave, accidental = parse_note_name(one_note)
            audio.octave = octave
            audio.accidental = accidental
            letters.append(letter)
            ring.show(letter)
            audio.note_on(letter)
        label = "+".join(chord_notes)
        print(f"NOTE    {label}")
        if oled:
            oled.show_lines(["Listen...", label])
        time.sleep(duration * seconds_per_beat)
        for letter in letters:
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
    strip = LedStrip()
    pools = build_pools()

    try:
        print(f"ChromaCade Tutor mode -- {args.song}. Watch and listen first...")
        play_demo(audio, ring, SCORES[args.song], seconds_per_beat)

        print("Now you try! Match the color, in any octave. Ctrl+C to quit early.")
        session = TutorSession(SONGS[args.song])
        song_complete = threading.Event()

        matching_held = []  # currently-held letters, for chord matching -- see chromacade.py's own copy

        def show_target():
            if session.is_complete():
                print(f"DONE    {args.song} complete!")
                ring.clear()
                song_complete.set()
            else:
                print(f"CUE     {target_label(session.target)}")
                ring.show(chord_cue_letter(session.target))

        def note_on(letter):
            audio.note_on(letter)
            if letter not in matching_held:
                matching_held.append(letter)
            matched_step = session.target  # capture before press() advances index
            if session.press(matching_held):
                print(f"MATCH   {target_label(matched_step)}")
                show_target()
            else:
                print(f"MISS    {letter} (wanted {target_label(session.target)})")
                miss_feedback(strip, session.target, pools["tutor_error"].next())

        def note_off(letter):
            audio.note_off(letter)
            if letter in matching_held:
                matching_held.remove(letter)

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
            song_complete.wait()
        except KeyboardInterrupt:
            pass
        finally:
            # Same shutdown order as play.py, same reason: stop the
            # background poller before freeing FluidSynth or it can
            # segfault on a use-after-free.
            poller.stop()

        if session.is_complete():
            celebrate(ring, strip, pools["big_win"].next())
    except KeyboardInterrupt:
        pass
    finally:
        ring.clear()
        strip.clear()
        audio.quit()
        print("\nDone.")


if __name__ == "__main__":
    main()
