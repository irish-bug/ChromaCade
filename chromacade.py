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
"tutor_active" | "tutor_await_continue" | "simon_demo" |
"simon_active" | "simon_await_continue"). play.py and tutor_mode.py
are left as-is (not deleted) -- they're still useful standalone
dev/test tools that bypass the menu entirely, and tutor_mode.py's
play_demo()/celebrate()/miss_feedback()/TUTOR_PROGRAM/MISS_COLOR are
reused here directly rather than duplicated. Sound selection (which
nope/yay/prompt clip plays when) comes from sound_pools.py's
build_pools() -- see that module's docstring for the six pools and
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
    offers a keep-going/stop prompt (CONTINUE_LETTER/STOP_LETTER,
    added 2026-08-26 -- see that constant's own comment) rather than
    dropping straight to Play; choosing to stop returns to Play mode,
    not back into the menu's list, matching the original behavior.
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
  - Simon temporarily switches to Toy Piano (tutor_mode.py's
    TUTOR_PROGRAM -- a number/song source can easily produce
    back-to-back identical letters, and Toy Piano's clear attack keeps
    those distinguishable rather than blending into one held tone) and
    restores whatever font/voice was active before, on both normal
    completion and an early exit. Tutor does NOT do this (changed
    2026-08-17, by request) -- it plays in whichever font/voice was
    already selected when it started, same repeated-note-blending risk
    accepted as a tradeoff for letting the chosen instrument carry
    through. Octave is NOT saved/restored for either mode -- both just
    fix it to 4 during play.
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
from sound_pools import build_pools, play_wav, play_wav_sequence
from tutor_mode import (
    DEFAULT_TEMPO,
    MISS_COLOR,
    TUTOR_PROGRAM,
    celebrate,
    miss_feedback,
    play_demo,
)
from tutor_songs import PROMPTS, SCORES, SONGS, TutorSession, chord_cue_letter, target_label

OLED_THROTTLE_SECONDS = 1 / 15  # see module docstring's assumptions list
# Simon-only now (2026-08-17) -- Tutor plays in whichever font was
# already selected, see start_tutor()/module docstring's assumptions
# list for why the two modes diverge here.
TUTOR_FONT_INDEX = next(i for i, (program, _name) in enumerate(FONTS) if program == TUTOR_PROGRAM)
ACCIDENTAL_SYMBOLS = {-1: "b", 0: "", 1: "#"}

SIMON_SOURCES = ["Random"] + list(FAMOUS_NUMBERS.keys()) + list(SONGS.keys())
SIMON_NOTE_SECONDS = 0.5
SIMON_GAP_SECONDS = 0.2
SIMON_MISS_FLASH_SECONDS = 0.15
SIMON_MISS_FLASH_COUNT = 2
SIMON_ROUND_COMPLETE_DELAY_SECONDS = 1.0  # pause before the next round starts, requested 2026-08-15

# Continue/stop prompt after a full Tutor song or Simon game completes
# (not a Simon round -- see _simon_handle_round_complete for that),
# requested 2026-08-26: instead of always dropping straight back to
# Play, offer to keep going with the next song/sequence in the same
# mode without a parent needing to redo the menu-toggle gesture. C/F
# reused as-is (not new hardware) -- C is already red, F is already
# mint green (color-palette.md), so "red stops, green continues" reads
# correctly with zero new color-teaching conflict. Scoped to its own
# dedicated app state (like every other note-button repurposing in
# this file, e.g. the font button's menu-select overload) so this
# can't collide with C/F needing to be pressed as actual notes
# mid-song/mid-round -- this state only exists in the gap between one
# song ending and the next (if any) starting.
CONTINUE_LETTER = "F"  # green -- keep going with the next song/sequence
STOP_LETTER = "C"  # red -- done, back to Play
ALL_DONE_FLASH_SECONDS = 1.5  # how long "All done!" stays up before Play


def _next_in_cycle(items, current):
    """current's neighbor in items, wrapping around -- used to pick
    "the next song"/"the next sequence source" for the continue
    prompt. Falls back to returning current itself if it isn't found
    in items (shouldn't happen in practice) rather than raising --
    replaying the same one is a reasonable fallback, not a real error
    worth crashing over."""
    if current not in items:
        return current
    i = items.index(current)
    return items[(i + 1) % len(items)]


def resolve_simon_source(source_name):
    """source_name -> (next_letter, max_length) for SimonSession --
    see simon_sequences.py for what these mean."""
    if source_name == "Random":
        return random_source()
    if source_name in FAMOUS_NUMBERS:
        return pool_source(sequence_from_number(FAMOUS_NUMBERS[source_name]))
    return pool_source(SONGS[source_name])


def cue_ring_for(ring, step):
    """Shows a target step on the ring, via tutor_songs.py's
    chord_cue_letter() -- see that function's docstring for why this
    is a placeholder, not a settled chord-display design."""
    ring.show(chord_cue_letter(step))


def play_simon_sequence(audio, ring, sequence, oled=None):
    """Blocking playthrough of the current round's sequence-so-far --
    same blocking-call style as tutor_mode.py's play_demo(), see that
    module's docstring and this module's assumptions list for why.
    No SCORES-style rhythm data for Simon (song/number/random sources
    are all bare letters, no duration), so this just uses a fixed
    on/gap timing rather than DEFAULT_TEMPO-based beats.

    Each step is a frozenset of letters (size 1 for an ordinary note,
    more for a chord -- see simon_sequences.py/tutor_songs.py), not a
    bare letter -- a chord step strikes all its letters together (list
    order off the frozenset, so not a fixed order, but this project
    doesn't need sample-accurate simultaneity for it to read as a
    chord) and releases them together, same pattern as
    tutor_mode.py's play_demo()."""
    audio.octave = 4
    for step in sequence:
        letters = sorted(step)
        for letter in letters:
            ring.show(letter)  # last letter wins -- same placeholder as play_demo(), see that function's docstring
            audio.note_on(letter)
        if oled:
            oled.show_lines(["Watch..."])
        time.sleep(SIMON_NOTE_SECONDS)
        for letter in letters:
            audio.note_off(letter)
        ring.clear()
        time.sleep(SIMON_GAP_SECONDS)


def main():
    audio = ChromaCadeAudio()  # Toy Piano default (audio_engine.py's FONTS[0]) -- normal play's voice
    ring = LedRing()
    strip = LedStrip()
    oled = OledDisplay()
    menu = Menu(list(SONGS.keys()), SIMON_SOURCES)
    pools = build_pools()

    app = {"state": "play"}  # "play"|"menu"|"tutor_demo"|"tutor_active"|"simon_demo"|"simon_active"
    held = []
    # Separate from `held` above (play mode's own bookkeeping, feeds
    # update_ring()/update_play_oled()'s "most recently held" display
    # logic) -- this one exists purely so tutor_active/simon_active can
    # tell TutorSession.press()/SimonSession.press() the full set of
    # letters currently down, for chord matching (added 2026-09-02).
    # Kept independent rather than reusing `held` so chord-matching
    # bookkeeping can never leak into Play mode's own display state.
    matching_held = []
    play_state = {"bend": 0.0, "shown": None, "shown_base": None, "volume_percent": 0.0}
    tutor = {"session": None, "song_name": None}
    simon = {"session": None, "source_name": None, "saved_font_index": None}
    # Guards CONTINUE_LETTER/STOP_LETTER against being acted on WHILE
    # _offer_continue()'s voice announcement is still playing -- added
    # 2026-08-27, found live ("press red, it just goes back to Play and
    # doesn't say anything"). app["state"] flips to *_await_continue
    # BEFORE that announcement finishes (has to, see _offer_continue()'s
    # own docstring -- otherwise a press during it hits the stale
    # tutor_active/simon_active branch and crashes on a None session),
    # so a press landing DURING the announcement was already being acted
    # on immediately -- starting the next song, or firing
    # _stop_after_complete()'s own play_wav() -- while the announcement's
    # own aplay calls (via play_wav_sequence(), still running on its own
    # thread) were still in flight through the same shared dmix device.
    # Overlapping/competing aplay processes on the same clip is exactly
    # the kind of thing that can wash out into what sounds like nothing
    # played. Not ready until the announcement truly finishes; a press
    # during it is a clean no-op (like "menu"/"tutor_demo"/"simon_demo"
    # already are) rather than an accepted-but-garbled one.
    continue_ready = {"value": False}
    oled_throttle = {"t": 0.0}
    # Guards ring/oled hardware writes -- added 2026-08-24 alongside
    # note_on()/note_off() backgrounding their display update (see
    # _background(), _ring_worker(), and _oled_worker() below for why).
    # Neither NeoPixel.show() nor the SSD1306's I2C write is safe
    # against concurrent/interleaved calls, now that update_ring()/
    # update_play_oled() can run from more than one thread at once (the
    # two workers below, plus the ADS1115 poll thread's direct calls via
    # pitch_bend()/volume_change()) -- same underlying class of problem
    # ChromaCadeAudio's own RLock already guards for FluidSynth.
    #
    # TWO locks, not one shared -- split 2026-08-27, found live ("once
    # [the OLED] gets backed up the lag spills over into the LED ring").
    # ring.show() and the SSD1306 I2C write use completely different
    # hardware peripherals (WS2812 PWM/DMA vs I2C) and don't need to be
    # serialized against EACH OTHER, only against concurrent calls to
    # the SAME one -- a single shared lock meant _ring_worker() still had
    # to wait for _oled_worker() to release it before doing its own,
    # much faster write, even though the two Events below already run
    # them on independent threads. Since _request_display_refresh() sets
    # both Events together on every note press, this collision was
    # happening on nearly every press, not some rare edge case.
    _ring_lock = threading.Lock()
    _oled_lock = threading.Lock()
    # Two SEPARATE coalescing Events, not one shared -- 2026-08-27, found
    # live ("LEDs not keeping up") after the single-worker version below
    # (also added 2026-08-27, same day, superseded within the hour) still
    # lagged. Measured directly on plinkplonk: ring.show() ~1.3ms/call,
    # oled.show_play() ~179ms/call -- a single worker doing both in one
    # pass on one thread meant every ring update was stuck waiting behind
    # the ~140x-slower OLED write, capping the RING's effective refresh
    # rate at the OLED's ~5.5/sec instead of its own much faster ceiling.
    # Splitting into _ring_dirty/_oled_dirty with two independent workers
    # lets the ring coalesce-and-refresh on its own fast cadence,
    # completely decoupled from however long the OLED write takes.
    _ring_dirty = threading.Event()
    _oled_dirty = threading.Event()

    def update_ring():
        """Normal-play ring behavior -- verbatim from play.py."""
        with _ring_lock:
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
        with _oled_lock:
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

    def stop_active_tutor():
        """Abort whatever Tutor progress exists -- no celebration, this
        is an interruption not a completion. Safe to call even if
        nothing's running."""
        audio.all_notes_off()
        tutor["session"] = None
        tutor["song_name"] = None
        ring.clear()
        strip.clear()

    def _offer_continue(mode):
        """Shared by Tutor-song-complete and Simon-game-complete: shows
        the keep-going/stop prompt, announces BOTH choices by voice
        (requested 2026-08-26, so a listener knows both options exist
        before deciding, not just the one that happens to play first),
        and switches to the matching "<mode>_await_continue" state,
        where note_on() below interprets CONTINUE_LETTER/STOP_LETTER
        instead of playing notes. play_wav_sequence() (not two
        play_wav() calls) plays keep_going then all_done back to back,
        not overlapping -- see that function's own docstring.
        Deliberately does NOT clear tutor["song_name"]/
        simon["source_name"] here -- still needed if CONTINUE_LETTER
        gets pressed, both to know which mode to resume and to compute
        "the next one" via _next_in_cycle(). State flips to
        "<mode>_await_continue" BEFORE the (now blocking, since
        play_wav_sequence() waits for both clips) voice announcement,
        not after -- session was just set to None above, so any note
        press landing during the multi-second announcement needs to
        already be routed to the *_await_continue branch (a safe no-op
        for anything but CONTINUE_LETTER/STOP_LETTER) rather than the
        stale tutor_active/simon_active branch, which would call
        .press() on a None session and crash. continue_ready gates the
        SEPARATE question of whether to actually ACT on that letter yet
        -- see its own comment above for why a press during the
        announcement needs to be ignored, not just safely routed."""
        oled.show_lines(["KEEP GOING?", "PRESS GREEN", "ALL DONE?", "PRESS RED"])
        continue_ready["value"] = False
        app["state"] = f"{mode}_await_continue"
        play_wav_sequence([pools["keep_going"].next(), pools["all_done"].next()])
        continue_ready["value"] = True

    def _stop_after_complete():
        """STOP_LETTER press from either *_await_continue state --
        brief visual confirmation, then back to Play. No sound here --
        removed 2026-08-27, direct feedback: all_done.wav already
        played once as part of _offer_continue()'s upfront announcement
        ("they already pressed the red button" -- replaying the same
        clip again on the press that CHOSE that option is redundant,
        not a fresh confirmation. The OLED flash stays; only the audio
        was cut. Still backgrounded from note_on() below (see
        _background()'s own docstring) since this sleeps and would
        otherwise stall gpiozero's button-callback dispatch thread, the
        same class of bug as the pre-2026-08-24 chord-timing issue."""
        oled.show_lines(["ALL DONE!"])
        time.sleep(ALL_DONE_FLASH_SECONDS)
        tutor["song_name"] = None
        simon["source_name"] = None
        app["state"] = "play"
        update_play_oled(force=True)

    def _continue_tutor():
        start_tutor(_next_in_cycle(list(SONGS.keys()), tutor["song_name"]))

    def _continue_simon():
        start_simon(_next_in_cycle(SIMON_SOURCES, simon["source_name"]))

    def show_tutor_target():
        session = tutor["session"]
        if session.is_complete():
            print(f"DONE    {tutor['song_name']} complete!")
            ring.clear()
            oled.show_lines(["Great job!", tutor["song_name"]])
            celebrate(ring, strip, pools["big_win"].next())
            tutor["session"] = None
            _offer_continue("tutor")
        else:
            label = target_label(session.target)
            print(f"CUE     {label}")
            cue_ring_for(ring, session.target)
            lines = ["Match the color:", label]
            prompt = PROMPTS.get(tutor["song_name"], {}).get(session.index)
            if prompt:
                lines.append(prompt)
            oled.show_lines(lines)

    def start_tutor(song_name):
        # Cleared here too, not just menu_enter() -- _continue_tutor()
        # reaches this directly from tutor_await_continue, skipping
        # "menu" entirely, so a stray still-held note from finishing
        # the previous song could otherwise leak into this one's chord
        # matching.
        matching_held.clear()
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
        _offer_continue("simon")

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
        matching_held.clear()  # see start_tutor()'s identical comment -- _continue_simon() reaches here directly too
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

    def _request_display_refresh():
        """Called from note_on()/note_off()'s "play" branch -- flags
        both the ring and OLED workers rather than spawning a thread
        per call (see _ring_dirty/_oled_dirty's own comment above).
        Setting an already-set Event is a harmless no-op, which is
        exactly the coalescing this wants: N note events in a burst
        collapse into "at least one more refresh happens soon" on each
        worker, not N redundant ones. Deliberately sets both from one
        call (not two separately-named request functions) -- every
        current caller wants both updated; split them further only if
        a caller ever wants just one."""
        _ring_dirty.set()
        _oled_dirty.set()

    def _ring_worker():
        """Persistent thread that calls update_ring() -- started once,
        below, alongside the poller and _oled_worker(). Blocks on
        _ring_dirty rather than polling, so it's idle (no CPU, no
        NeoPixel traffic) whenever nothing's changed. Coalescing falls
        out of this loop shape for free: update_ring() reads LIVE state
        (`held`, `play_state`) rather than anything captured at request
        time, so no matter how many times _ring_dirty got set while
        this thread was busy, the next iteration renders whatever is
        CURRENTLY true in one pass. Split from OLED refreshes
        2026-08-27 specifically so this loop's own ~1.3ms-per-call
        NeoPixel writes never wait behind the OLED's ~179ms I2C writes
        -- see _ring_dirty's own comment for the measurements."""
        while True:
            _ring_dirty.wait()
            _ring_dirty.clear()
            update_ring()

    def _oled_worker():
        """Same idea as _ring_worker(), for update_play_oled(). Kept
        as its own thread/Event (not folded back into _ring_worker())
        specifically so its much slower I2C writes never throttle the
        ring's own refresh rate -- that coupling was the actual bug
        this whole 2026-08-27 change fixes."""
        while True:
            _oled_dirty.wait()
            _oled_dirty.clear()
            update_play_oled(force=True)

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
            # Deferred 2026-08-24 (then switched from a per-event thread
            # to _request_display_refresh()'s coalesced Events 2026-08-27,
            # see _ring_dirty/_oled_dirty's own comment) -- update_ring()/
            # update_play_oled() were blocking this same callback (and
            # therefore whatever gpiozero's pin factory serializes
            # button-event dispatch through) until their I2C/NeoPixel
            # writes finished, which measurably staggered chords:
            # audio.note_on() above already fires immediately either
            # way, but a held-up callback delayed the NEXT button's
            # press event from even being processed. Confirmed live --
            # 3-note chords played as a fast arpeggio instead of
            # together, worse on fast-decay voices. held.append() stays
            # synchronous/in-order above; only the display catch-up is
            # deferred.
            _request_display_refresh()
        elif state == "tutor_active":
            session = tutor["session"]
            audio.note_on(letter)
            if letter not in matching_held:
                matching_held.append(letter)
            matched_step = session.target  # capture before press() advances index
            if session.press(matching_held):
                print(f"MATCH   {target_label(matched_step)}")
                _background(show_tutor_target)
            else:
                print(f"MISS    {letter} (wanted {target_label(session.target)})")
                _background(miss_feedback, strip, session.target, pools["tutor_error"].next())
        elif state == "simon_active":
            session = simon["session"]
            audio.note_on(letter)
            ring.show(letter)  # requested 2026-08-15 -- press feedback, same as Play/Tutor
            if letter not in matching_held:
                matching_held.append(letter)
            result = session.press(matching_held)
            if result == "wrong":
                print(f"SIMON   wrong (pressed {letter}, wanted {target_label(session.sequence[session.input_index])})")
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
        elif state == "tutor_await_continue":
            if not continue_ready["value"]:
                pass  # announcement still playing -- see continue_ready's own comment
            elif letter == CONTINUE_LETTER:
                _continue_tutor()
            elif letter == STOP_LETTER:
                _background(_stop_after_complete)
        elif state == "simon_await_continue":
            if not continue_ready["value"]:
                pass  # announcement still playing -- see continue_ready's own comment
            elif letter == CONTINUE_LETTER:
                _continue_simon()
            elif letter == STOP_LETTER:
                _background(_stop_after_complete)
        # "menu" / "tutor_demo" / "simon_demo": no-op, own input entirely

    def note_off(letter):
        state = app["state"]
        if state == "play":
            print(f"release {letter}")
            audio.note_off(letter)
            if letter in held:
                held.remove(letter)
            _request_display_refresh()  # see note_on()'s comment above
        elif state == "tutor_active":
            audio.note_off(letter)
            if letter in matching_held:
                matching_held.remove(letter)
        elif state == "simon_active":
            audio.note_off(letter)
            if letter in matching_held:
                matching_held.remove(letter)
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
        # tutor_demo/simon_demo added 2026-08-26 -- found live, the pot
        # was a no-op during play_demo()/play_simon_sequence() (the
        # watch-the-song-play phase), same ChromaCadeAudio call as
        # tutor_active/simon_active so no new threading concern (the
        # RLock added for the concurrent-access crash fix already
        # serializes this against whatever play_demo() is doing on its
        # own thread). octave_change()/accidental_change()/pitch_bend()
        # have this same "*_active" but not "*_demo" gap -- not fixed
        # here since only the volume pot was actually reported broken,
        # but worth knowing it's not unique to volume if this comes up
        # again.
        if app["state"] in ("play", "tutor_active", "simon_active", "tutor_demo", "simon_demo"):
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
        # *_await_continue included alongside the actively-playing
        # states -- a parent using the menu gesture to jump straight to
        # a different song instead of pressing CONTINUE_LETTER/
        # STOP_LETTER should still get tutor["song_name"]/
        # simon["source_name"] cleared, same as any other interruption.
        if app["state"] in ("tutor_demo", "tutor_active", "tutor_await_continue"):
            stop_active_tutor()
        elif app["state"] in ("simon_demo", "simon_active", "simon_await_continue"):
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
        matching_held.clear()
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

    # Started once each, daemon (dies with the process, same as every
    # other _background() thread) -- see _ring_worker()/_oled_worker()'s
    # own docstrings for why these are two separate threads, not one.
    threading.Thread(target=_ring_worker, daemon=True).start()
    threading.Thread(target=_oled_worker, daemon=True).start()

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
