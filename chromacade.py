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
"tutor_active" | "simon_demo" | "simon_active"). play.py and
tutor_mode.py are left as-is (not deleted) -- they're still useful
standalone dev/test tools that bypass the menu entirely, and
tutor_mode.py's play_demo()/celebrate()/miss_feedback()/TUTOR_PROGRAM/
MISS_COLOR are reused here directly rather than duplicated. Sound
selection (which nope/yay clip plays when) comes from sound_pools.py's
build_pools() -- see that module's docstring for the four pools and
their rules.

Menu gesture (control-layout.md, simplified 2026-08-16 -- see
hardware_poller.py's docstring for the full why): hold BOTH encoder
push-buttons together for ~1.5s -- no note button involved. One
gesture toggles: opens the menu (from play, or from an active
Tutor/Simon session, stopping it first) or closes it (from the menu,
back to play). Cycle options: turn the font encoder (menu takes over
that control's normal job while a menu is open). Select: short click
of the font button.
Nested menu (mode, then song/sequence within Tutor/Simon) -- see
menu.py.

Simon Says (added 2026-08-15, feature-spec.md's Simon/Learn mode
section's second sub-mode): classic escalating-sequence memory game --
watch a growing sequence, reproduce it, wrong press resets (unlike
Tutor's no-penalty design; feature-spec.md explicitly leans toward
Simon resetting on a miss since it's meant to test, not just teach).
Three selectable sequence sources (SIMON_SOURCES below), all floated
by the user: "Random" (classic Simon, a fresh random letter appended
each round, never ends), a famous number (simon_sequences.py's
FAMOUS_NUMBERS, digits mapped to letters mod 7, e.g. pi's "3.14159" ->
F D G D A E), or one of the existing Tutor songs (its real note
sequence, revealed incrementally). Number/song sources are finite --
reaching the end is a real win (full celebration), not just an
arbitrarily-long round.

ASSUMPTIONS / JUDGMENT CALLS MADE WITHOUT ASKING (flagged per-topic
inline below too, this is the summary):
  - Menu structure is nested (mode select, then song/sequence list),
    not flat -- open-questions.md left this undecided; nested fits a
    5-line OLED.
  - No song/sequence preview before selecting -- select() starts
    immediately.
  - Entering the menu (or exiting it, or exiting an active Tutor/Simon
    session) always fully resets state -- e.g. re-triggering the enter
    gesture while already in the menu snaps back to the mode-select
    top level rather than preserving deep navigation.
  - Finishing a Tutor song or a Simon game (after the celebration)
    returns to Play mode, not back into the menu's list.
  - Starting a song/sequence from the menu (start_tutor()/
    start_simon(), triggered by the font button's short-click) still
    blocks the control panel for its initial demo/first-round playback
    -- same reasoning as before: simplest, and nothing else needs to
    interrupt that specific moment.
  - Everything note_on() can trigger during tutor_active/simon_active
    (miss feedback, round-complete/celebration, the next round's demo
    playback) now runs on a background thread instead of blocking
    inline -- changed 2026-08-16 after the menu exit gesture (hold
    both encoder buttons + long-press C) was confirmed unreliable
    live. Root cause: C/B are real notes too, so pressing one to start
    the exit gesture also fires a normal note_on() -> miss_feedback()
    (or a round-complete/celebration) call, which used to block
    inline for up to several seconds -- long enough to disrupt
    gpiozero's own hold-timer for that same button's when_held
    callback, since it runs through the same button object. Safe to
    background now: ChromaCadeAudio's RLock (added earlier this
    session for the concurrent-access heap corruption crash) already
    serializes FluidSynth access from any thread, so this isn't a new
    class of risk, just a new caller of an already-guarded resource.
    Not yet re-verified live (needs real button presses) -- see
    open-questions.md if this turns out not to be the whole story.
  - OLED refresh for continuous streams (pitch-bend, volume) is
    throttled to ~15Hz (OLED_THROTTLE_SECONDS) -- open-questions.md
    flagged this as unresolved ("suggested 10-20Hz, not tested"); 15Hz
    is the middle of that range, not independently benchmarked here.
  - Tutor/Simon both temporarily switch to Toy Piano
    (tutor_mode.py's TUTOR_PROGRAM, same repeated-note-blending
    reasoning as Tutor -- a number/song source can easily produce
    back-to-back identical letters) and restore whatever font/voice
    was active before, on both normal completion and an early exit.
    Octave is NOT saved/restored (same as Tutor already didn't) --
    both modes just fix it to 4 during play.
  - A wrong Simon press immediately (auto, no menu step) restarts
    round 1 of the SAME game/source rather than requiring the player
    to re-navigate the menu.
  - Simon's miss cue reuses Tutor's red strip flash + nope.wav, but
    WITHOUT tutor_mode.py's "flash the correct color after" step --
    revealing the answer would defeat a memory game's purpose.

Needs sudo -- same as play.py/tutor_mode.py (LED ring/strip PWM/DMA).

Usage:
    sudo python3 chromacade.py

Ctrl+C to quit.
"""

import subprocess
import threading
import time
from signal import pause

from audio_engine import FONTS, MAX_BEND_SEMITONES, ChromaCadeAudio, bent_letter, midi_note, midi_to_freq
from hardware_poller import HardwarePoller
from led_ring import LedRing
from led_strip import LedStrip
from menu import Menu
from oled_display import OledDisplay
from simon_sequences import FAMOUS_NUMBERS, SimonSession, pool_source, random_source, sequence_from_number
from sound_pools import build_pools, play_wav
from tutor_mode import (
    DEFAULT_TEMPO,
    MISS_COLOR,
    TUTOR_PROGRAM,
    celebrate,
    miss_feedback,
    play_demo,
)
from tutor_songs import SCORES, SONGS, TutorSession

OLED_THROTTLE_SECONDS = 1 / 15  # see module docstring's assumptions list
TUTOR_FONT_INDEX = next(i for i, (program, _name) in enumerate(FONTS) if program == TUTOR_PROGRAM)
ACCIDENTAL_SYMBOLS = {-1: "b", 0: "", 1: "#"}

SIMON_SOURCES = ["Random"] + list(FAMOUS_NUMBERS.keys()) + list(SONGS.keys())
SIMON_NOTE_SECONDS = 0.5
SIMON_GAP_SECONDS = 0.2
SIMON_MISS_FLASH_SECONDS = 0.15
SIMON_MISS_FLASH_COUNT = 2
SIMON_ROUND_COMPLETE_DELAY_SECONDS = 1.0  # pause before the next round starts, requested 2026-08-15


def resolve_simon_source(source_name):
    """source_name -> (next_letter, max_length) for SimonSession --
    see simon_sequences.py for what these mean."""
    if source_name == "Random":
        return random_source()
    if source_name in FAMOUS_NUMBERS:
        return pool_source(sequence_from_number(FAMOUS_NUMBERS[source_name]))
    return pool_source(SONGS[source_name])


def play_simon_sequence(audio, ring, sequence, oled=None):
    """Blocking playthrough of the current round's sequence-so-far --
    same blocking-call style as tutor_mode.py's play_demo(), see that
    module's docstring and this module's assumptions list for why.
    No SCORES-style rhythm data for Simon (song/number/random sources
    are all bare letters, no duration), so this just uses a fixed
    on/gap timing rather than DEFAULT_TEMPO-based beats."""
    audio.octave = 4
    for letter in sequence:
        ring.show(letter)
        if oled:
            oled.show_lines(["Watch..."])
        audio.note_on(letter)
        time.sleep(SIMON_NOTE_SECONDS)
        audio.note_off(letter)
        ring.clear()
        time.sleep(SIMON_GAP_SECONDS)


def main():
    audio = ChromaCadeAudio()  # Organ default -- normal play's voice, unchanged from play.py
    ring = LedRing()
    strip = LedStrip()
    oled = OledDisplay()
    menu = Menu(list(SONGS.keys()), SIMON_SOURCES)
    pools = build_pools()

    app = {"state": "play"}  # "play"|"menu"|"tutor_demo"|"tutor_active"|"simon_demo"|"simon_active"
    held = []
    play_state = {"bend": 0.0, "shown": None, "shown_base": None, "volume_percent": 0.0}
    tutor = {"session": None, "song_name": None, "saved_font_index": None}
    simon = {"session": None, "source_name": None, "saved_font_index": None}
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
        audio.all_notes_off()
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
            celebrate(ring, strip, pools["big_win"].next())
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

    def stop_active_simon():
        """Abort whatever Simon progress exists -- no celebration, this
        is an interruption not a completion. Safe to call even if
        nothing's running."""
        if simon["saved_font_index"] is not None:
            audio.font_change(simon["saved_font_index"] - audio.font_index)
            simon["saved_font_index"] = None
        audio.all_notes_off()
        simon["session"] = None
        simon["source_name"] = None
        ring.clear()
        strip.clear()

    def simon_miss_feedback():
        """Double-flash red, ring alternating with strip, plus a sound
        from the simon_mistake pool (startover.wav/tryagain.wav,
        alternating -- fixed 2026-08-16, was still hardcoded to the
        old single nope.wav until now) -- requested 2026-08-15 to
        replace the original strip-only single flash (borrowed from
        Tutor's miss_feedback()) with something more distinct for
        Simon's harder-edged "wrong, start over" moment. Deliberately
        doesn't flash the correct color after (unlike Tutor's cue) --
        revealing the answer would defeat a memory game's purpose."""
        play_wav(pools["simon_mistake"].next())
        for _ in range(SIMON_MISS_FLASH_COUNT):
            ring.fill(MISS_COLOR)
            time.sleep(SIMON_MISS_FLASH_SECONDS)
            ring.clear()
            time.sleep(SIMON_MISS_FLASH_SECONDS)
            strip.fill(MISS_COLOR)
            time.sleep(SIMON_MISS_FLASH_SECONDS)
            strip.clear()
            time.sleep(SIMON_MISS_FLASH_SECONDS)

    def finish_simon():
        session = simon["session"]
        print(f"SIMON   {simon['source_name']} fully memorized, {session.round_number} rounds!")
        oled.show_lines(["You memorized", "the whole thing!"])
        celebrate(ring, strip, pools["big_win"].next())
        if simon["saved_font_index"] is not None:
            audio.font_change(simon["saved_font_index"] - audio.font_index)
            simon["saved_font_index"] = None
        simon["session"] = None
        simon["source_name"] = None
        app["state"] = "play"
        update_play_oled(force=True)

    def play_simon_round():
        """Blocking: plays back the current round's sequence-so-far,
        then flips to "simon_active" and waits for input. Called both
        to start a game and after every correct round (and after a
        reset following a wrong press) -- see module docstring's
        assumptions list for why a miss auto-restarts immediately
        rather than needing a menu trip. all_notes_off() up front
        guards against the note that was just pressed to trigger this
        (still technically "on" until its button release fires,
        possibly delayed behind this very call) bleeding into the
        demo -- same class of fix as menu_enter()'s stuck-note bug."""
        audio.all_notes_off()
        app["state"] = "simon_demo"
        session = simon["session"]
        oled.show_lines([f"Round {session.round_number}", "Watch..."])
        play_simon_sequence(audio, ring, session.sequence, oled=oled)
        app["state"] = "simon_active"
        oled.show_lines([f"Round {session.round_number}", "Your turn!"])

    def start_simon(source_name):
        simon["saved_font_index"] = audio.font_index
        audio.font_change(TUTOR_FONT_INDEX - audio.font_index)
        simon["source_name"] = source_name
        next_letter, max_length = resolve_simon_source(source_name)
        simon["session"] = SimonSession(next_letter, max_length)
        play_simon_round()

    def _background(target, *args):
        """Runs target(*args) on its own daemon thread -- see note_on()
        below for why. Safe to call into audio/FluidSynth from here:
        ChromaCadeAudio's RLock (added 2026-08-16 for the concurrent-
        access crash fix) already serializes access from any thread,
        this isn't a new class of risk, just a new caller."""
        threading.Thread(target=target, args=args, daemon=True).start()

    def _simon_handle_wrong():
        simon_miss_feedback()
        simon["session"].reset()
        play_simon_round()

    def _simon_handle_round_complete(sound_path):
        play_wav(sound_path)
        # Requested 2026-08-15 -- a beat before the next round starts,
        # rather than snapping straight into it.
        time.sleep(SIMON_ROUND_COMPLETE_DELAY_SECONDS)
        play_simon_round()

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
                _background(show_tutor_target)
            else:
                print(f"MISS    {letter} (wanted {session.target})")
                _background(miss_feedback, strip, session.target, pools["tutor_error"].next())
        elif state == "simon_active":
            session = simon["session"]
            audio.note_on(letter)
            ring.show(letter)  # requested 2026-08-15 -- press feedback, same as Play/Tutor
            result = session.press(letter)
            if result == "wrong":
                print(f"SIMON   wrong (pressed {letter}, wanted {session.sequence[session.input_index]})")
                _background(_simon_handle_wrong)
            elif result == "continue":
                print(f"SIMON   {letter} ok")
            elif result == "round_complete":
                print(f"SIMON   round {session.round_number - 1} complete!")
                # Requested 2026-08-16 -- a yays/ sound (not the two
                # reserved "big win" ones, those are for finishing the
                # whole game -- see finish_simon()) for clearing a
                # round, not just the flash-only cue this had before.
                _background(_simon_handle_round_complete, pools["simon_round_complete"].next())
            elif result == "complete":
                _background(finish_simon)
        # "menu" / "tutor_demo" / "simon_demo": no-op, own input entirely

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
        elif state == "simon_active":
            audio.note_off(letter)
            # `state` was captured at the top of this call, so a
            # release delayed behind a blocking play_simon_round()
            # (started by this same press) will see whatever state is
            # current BY THEN, not "simon_active" -- naturally skips
            # this ring.clear() rather than clobbering the next
            # round's demo animation.
            ring.clear()

    def octave_change(delta):
        if app["state"] in ("play", "tutor_active", "simon_active"):
            audio.octave_change(delta)
            print(f"OCTAVE  {'+1' if delta > 0 else '-1'} -> now {audio.octave}")
            if app["state"] == "play":
                update_play_oled(force=True)

    def accidental_change(accidental):
        if app["state"] in ("play", "tutor_active", "simon_active"):
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
        elif app["state"] in ("tutor_active", "simon_active"):
            audio.set_pitch_bend(bend_fraction)

    def volume_change(volume_fraction):
        if app["state"] in ("play", "tutor_active", "simon_active"):
            audio.set_volume(volume_fraction)
            play_state["volume_percent"] = volume_fraction * 100
            if app["state"] == "play":
                update_play_oled()

    def font_change(delta):
        if app["state"] == "menu":
            menu.rotate(delta)
            oled.show_lines(menu.display_lines())
        elif app["state"] in ("play", "tutor_active", "simon_active"):
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
        elif result[0] == "tutor":
            _, song_name = result
            menu.exit()
            start_tutor(song_name)
        elif result[0] == "simon":
            _, source_name = result
            menu.exit()
            start_simon(source_name)
        else:
            _, action = result
            menu.exit()
            system_action(action)

    def menu_enter():
        if app["state"] in ("tutor_demo", "tutor_active"):
            stop_active_tutor()
        elif app["state"] in ("simon_demo", "simon_active"):
            stop_active_simon()
        # Any note(s) still held the instant the encoder-hold gesture
        # fires need an explicit note_off here: the state flip to
        # "menu" happens on the gesture's own timer, independent of
        # when those notes get released, and once in "menu" state
        # ordinary note releases are a deliberate no-op ("menu owns
        # input") -- so a held note/chord would otherwise stay stuck
        # sustaining, and stuck in `held` too, corrupting the ring/OLED
        # once back in Play. all_notes_off() + clearing `held` here
        # guarantees a clean slate on every entry into the menu.
        audio.all_notes_off()
        held.clear()
        play_state["shown"] = None
        play_state["shown_base"] = None
        app["state"] = "menu"
        menu.enter()
        ring.clear()
        oled.show_lines(menu.display_lines())
        print("MENU    entered")

    def menu_exit():
        menu.exit()
        app["state"] = "play"
        update_play_oled(force=True)
        print("MENU    exited -> play")

    def menu_toggle():
        """The menu-toggle gesture (hardware_poller.py's
        on_menu_toggle) always calls this -- one hold-both-encoders
        gesture, contextually opening the menu from anywhere else or
        closing it from the menu itself, rather than separate
        enter/exit gestures needing different note buttons."""
        if app["state"] == "menu":
            menu_exit()
        else:
            menu_enter()

    def system_action(action):
        """Power Off / Reboot -- only ever called after menu.py's
        confirm stage (Yes/No, defaulting to No), see that module's
        docstring for why the extra step exists. chromacade.service
        already runs as root, so no sudo prefix is needed. Doesn't try
        to gracefully tear down audio/poller itself first -- systemd's
        normal shutdown sequence sends this service SIGTERM as part of
        shutting the whole system down together, same as any other
        service on the box, no special handling needed here.

        Reboot needs no special final-message handling -- the OLED
        naturally gets overwritten once the service comes back up
        (update_play_oled(force=True) at startup). Power Off is
        different: confirmed live 2026-08-16 that "Shutting down..."
        just stays frozen on screen forever afterward, since an SSD1306
        keeps driving whatever's in its own onboard display memory as
        long as the chip itself still has power -- `shutdown -h now`
        halts the OS but doesn't cut power to the board (nothing does,
        without a power-management HAT), so nothing ever tells it to
        change. Whatever's shown right before the halt call is what
        stays, so the actual "safe to unplug" message has to be the
        LAST thing written, not the first."""
        print(f"SYSTEM  {'Shutting down...' if action == 'poweroff' else 'Restarting...'}")
        oled.show_lines(["Shutting down..." if action == "poweroff" else "Restarting..."])
        ring.clear()
        strip.clear()
        audio.all_notes_off()
        if action == "poweroff":
            time.sleep(2)  # let "Shutting down..." register before it changes
            oled.show_lines(["Powered off.", "Safe to unplug."])
            subprocess.run(["shutdown", "-h", "now"])
        else:
            subprocess.run(["reboot"])

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
        on_menu_toggle=menu_toggle,
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
