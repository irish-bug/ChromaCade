#!/usr/bin/env python3
"""
ChromaCade -- unified app: normal play, the mode/song menu, and Tutor
mode, all in ONE persistent process. Written 2026-08-15 to replace
manually running play.py or tutor_mode.py --song X separately -- this
is what should actually run on the device day to day.

Why one process, not three: FluidSynth's soundfont load is ~6.8s
(open-questions.md), so tearing ChromaCadeAudio down and rebuilding it
on every mode switch would make switching feel broken. Instead
ChromaCadeAudio/HardwarePoller/LedRing/LedStrip/OledDisplay are all
built ONCE here and stay alive for the whole session; switching modes
just changes how the SAME poller callbacks are interpreted, via the
app["state"] dispatch below ("play" | "menu" | "tutor_demo" |
"tutor_active"). play.py and tutor_mode.py are left as-is (not
deleted) -- they're still useful standalone dev/test tools that bypass
the menu entirely, and tutor_mode.py's play_demo()/celebrate()/
miss_feedback()/TUTOR_PROGRAM are reused here directly rather than
duplicated.

Menu gesture (control-layout.md, corrected 2026-08-15 -- see
hardware_poller.py's docstring for the full why): hold BOTH encoder
push-buttons, then long-press C (exit) or B (enter) for ~1.5s. Cycle
options: turn the font encoder (menu takes over that control's normal
job while a menu is open). Select: short click of the font button.
Nested menu (mode, then song within Tutor) -- see menu.py.

ASSUMPTIONS / JUDGMENT CALLS MADE WITHOUT ASKING (flagged per-topic
inline below too, this is the summary):
  - Menu structure is nested (mode select, then song list), not flat --
    open-questions.md left this undecided; nested fits a 4-line OLED.
  - "Modes" = Play and Tutor only. Simon Says isn't in the menu -- no
    game logic for it exists anywhere yet, unlike Tutor.
  - No song preview/snippet before selecting -- select() starts the
    song immediately.
  - Entering the menu (or exiting it, or exiting an active Tutor
    session) always fully resets state -- e.g. re-triggering the enter
    gesture while already in the menu snaps back to the mode-select
    top level rather than preserving deep navigation.
  - Finishing a Tutor song (after the celebration) returns to Play
    mode, not back into the menu's song list.
  - During the ~10s Tutor demo playback, the WHOLE control panel is
    unresponsive (not just note buttons) -- this runs as a blocking
    call inside a button-callback thread, same style already used by
    celebrate()/miss_feedback() elsewhere in this codebase, and it's
    what tutor_mode.py's original (poller-doesn't-exist-yet-during-
    demo) design already did in spirit. A background thread would be
    more responsive but adds another thread calling into FluidSynth
    concurrently -- exactly the class of bug that caused the Ctrl+C
    segfault fixed earlier this session. Kept it simple/blocking.
  - OLED refresh for continuous streams (pitch-bend, volume) is
    throttled to ~15Hz (OLED_THROTTLE_SECONDS) -- open-questions.md
    flagged this as unresolved ("suggested 10-20Hz, not tested"); 15Hz
    is the middle of that range, not independently benchmarked here.
  - Tutor mode temporarily switches to Toy Piano (tutor_mode.py's
    TUTOR_PROGRAM) and restores whatever font/voice was active before,
    on both normal completion and an early exit.

Needs sudo -- same as play.py/tutor_mode.py (LED ring/strip PWM/DMA).

Usage:
    sudo python3 chromacade.py

Ctrl+C to quit.
"""

import time
from signal import pause

from audio_engine import FONTS, MAX_BEND_SEMITONES, ChromaCadeAudio, bent_letter, midi_note, midi_to_freq
from hardware_poller import HardwarePoller
from led_ring import LedRing
from led_strip import LedStrip
from menu import Menu
from oled_display import OledDisplay
from tutor_mode import DEFAULT_TEMPO, TUTOR_PROGRAM, celebrate, miss_feedback, play_demo
from tutor_songs import SCORES, SONGS, TutorSession

OLED_THROTTLE_SECONDS = 1 / 15  # see module docstring's assumptions list
TUTOR_FONT_INDEX = next(i for i, (program, _name) in enumerate(FONTS) if program == TUTOR_PROGRAM)
ACCIDENTAL_SYMBOLS = {-1: "b", 0: "", 1: "#"}


def main():
    audio = ChromaCadeAudio()  # Organ default -- normal play's voice, unchanged from play.py
    ring = LedRing()
    strip = LedStrip()
    oled = OledDisplay()
    menu = Menu(list(SONGS.keys()))

    app = {"state": "play"}  # "play" | "menu" | "tutor_demo" | "tutor_active"
    held = []
    play_state = {"bend": 0.0, "shown": None, "shown_base": None, "volume_percent": 0.0}
    tutor = {"session": None, "song_name": None, "saved_font_index": None}
    oled_throttle = {"t": 0.0}

    def update_ring():
        """Normal-play ring behavior -- verbatim from play.py."""
        if not held:
            ring.clear()
            play_state["shown"] = None
            play_state["shown_base"] = None
            return
        base = held[-1]
        letter = bent_letter(base, play_state["bend"])
        if letter != play_state["shown"]:
            if play_state["shown"] is not None and base == play_state["shown_base"]:
                print(f"COLOR   {play_state['shown']} -> {letter} (bend crossed the halfway point)")
            ring.show(letter)
            play_state["shown"] = letter
        play_state["shown_base"] = base

    def update_play_oled(force=False):
        now = time.monotonic()
        if not force and now - oled_throttle["t"] < OLED_THROTTLE_SECONDS:
            return
        oled_throttle["t"] = now
        if held:
            base = held[-1]
            letter = bent_letter(base, play_state["bend"])
            note_label = f"{letter}{ACCIDENTAL_SYMBOLS[audio.accidental]}{audio.octave}"
            base_midi = midi_note(base, audio.octave, audio.accidental)
            base_freq = midi_to_freq(base_midi)
            bent_freq = midi_to_freq(base_midi + play_state["bend"] * MAX_BEND_SEMITONES)
            bend_hz = bent_freq - base_freq
        else:
            note_label, base_freq, bend_hz = "--", 0.0, 0.0
        oled.show_play(note_label, audio.font_name, base_freq, bend_hz, play_state["volume_percent"])

    def restore_font():
        if tutor["saved_font_index"] is not None:
            audio.font_change(tutor["saved_font_index"] - audio.font_index)
            tutor["saved_font_index"] = None

    def stop_active_tutor():
        """Abort whatever Tutor progress exists -- no celebration, this
        is an interruption not a completion. Safe to call even if
        nothing's running."""
        restore_font()
        tutor["session"] = None
        tutor["song_name"] = None
        ring.clear()
        strip.clear()

    def show_tutor_target():
        session = tutor["session"]
        if session.is_complete():
            print(f"DONE    {tutor['song_name']} complete!")
            ring.clear()
            oled.show_lines(["Great job!", tutor["song_name"]])
            celebrate(ring, strip)
            restore_font()
            tutor["session"] = None
            tutor["song_name"] = None
            app["state"] = "play"
            update_play_oled(force=True)
        else:
            print(f"CUE     {session.target}")
            ring.show(session.target)
            oled.show_lines(["Match the color:", session.target])

    def start_tutor(song_name):
        tutor["saved_font_index"] = audio.font_index
        audio.font_change(TUTOR_FONT_INDEX - audio.font_index)
        tutor["song_name"] = song_name
        app["state"] = "tutor_demo"
        oled.show_lines(["Get ready...", song_name])
        seconds_per_beat = 60.0 / DEFAULT_TEMPO
        play_demo(audio, ring, SCORES[song_name], seconds_per_beat, oled=oled)
        tutor["session"] = TutorSession(SONGS[song_name])
        app["state"] = "tutor_active"
        show_tutor_target()

    def note_on(letter):
        state = app["state"]
        if state == "play":
            print(f"PRESS   {letter}")
            audio.note_on(letter)
            held.append(letter)
            update_ring()
            update_play_oled(force=True)
        elif state == "tutor_active":
            session = tutor["session"]
            audio.note_on(letter)
            if session.press(letter):
                print(f"MATCH   {letter}")
                show_tutor_target()
            else:
                print(f"MISS    {letter} (wanted {session.target})")
                miss_feedback(strip, session.target)
        # "menu" / "tutor_demo": no-op, menu/demo own input entirely

    def note_off(letter):
        state = app["state"]
        if state == "play":
            print(f"release {letter}")
            audio.note_off(letter)
            if letter in held:
                held.remove(letter)
            update_ring()
            update_play_oled(force=True)
        elif state == "tutor_active":
            audio.note_off(letter)

    def octave_change(delta):
        if app["state"] in ("play", "tutor_active"):
            audio.octave_change(delta)
            print(f"OCTAVE  {'+1' if delta > 0 else '-1'} -> now {audio.octave}")
            if app["state"] == "play":
                update_play_oled(force=True)

    def accidental_change(accidental):
        if app["state"] in ("play", "tutor_active"):
            audio.accidental_change(accidental)
            label = {-1: "FLAT", 0: "NATURAL", 1: "SHARP"}[accidental]
            print(f"ROCKER  {label}")
            if app["state"] == "play":
                update_play_oled(force=True)

    def pitch_bend(bend_fraction):
        if app["state"] == "play":
            audio.set_pitch_bend(bend_fraction)
            play_state["bend"] = bend_fraction
            update_ring()
            update_play_oled()
        elif app["state"] == "tutor_active":
            audio.set_pitch_bend(bend_fraction)

    def volume_change(volume_fraction):
        if app["state"] in ("play", "tutor_active"):
            audio.set_volume(volume_fraction)
            play_state["volume_percent"] = volume_fraction * 100
            if app["state"] == "play":
                update_play_oled()

    def font_change(delta):
        if app["state"] == "menu":
            menu.rotate(delta)
            oled.show_lines(menu.display_lines())
        elif app["state"] in ("play", "tutor_active"):
            audio.font_change(delta)
            print(f"FONT    -> {audio.font_name}")
            if app["state"] == "play":
                update_play_oled(force=True)

    def font_click():
        if app["state"] != "menu":
            return
        result = menu.select()
        if result is None:
            oled.show_lines(menu.display_lines())
        elif result == ("play",):
            menu.exit()
            app["state"] = "play"
            update_play_oled(force=True)
        else:
            _, song_name = result
            menu.exit()
            start_tutor(song_name)

    def menu_enter():
        if app["state"] in ("tutor_demo", "tutor_active"):
            stop_active_tutor()
        app["state"] = "menu"
        menu.enter()
        ring.clear()
        oled.show_lines(menu.display_lines())
        print("MENU    entered")

    def menu_exit():
        state = app["state"]
        if state == "menu":
            menu.exit()
            app["state"] = "play"
            update_play_oled(force=True)
            print("MENU    exited -> play")
        elif state in ("tutor_demo", "tutor_active"):
            stop_active_tutor()
            app["state"] = "play"
            update_play_oled(force=True)
            print("MENU    exited tutor -> play")
        # "play": nothing to exit, no-op

    # Must stay referenced for the life of the program -- see play.py's
    # identical note on this (garbage-collected poller silently kills
    # the buttons).
    poller = HardwarePoller(
        on_note_on=note_on,
        on_note_off=note_off,
        on_octave_change=octave_change,
        on_accidental_change=accidental_change,
        on_pitch_bend=pitch_bend,
        on_volume_change=volume_change,
        on_font_change=font_change,
        on_font_click=font_click,
        on_menu_enter=menu_enter,
        on_menu_exit=menu_exit,
    )

    print("ChromaCade is live. Ctrl+C to quit.")
    update_play_oled(force=True)
    try:
        pause()
    except KeyboardInterrupt:
        pass
    finally:
        # Same shutdown order as play.py/tutor_mode.py, same reason:
        # stop the background poller before freeing FluidSynth or it
        # can segfault on a use-after-free.
        poller.stop()
        ring.clear()
        strip.clear()
        oled.clear()
        audio.quit()
        print("\nDone.")


if __name__ == "__main__":
    main()
