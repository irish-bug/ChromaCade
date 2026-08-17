"""
ChromaCade -- Tutor/follow-along mode: song data and hardware-free
sequencing logic.

Tutor mode (feature-spec.md's Simon / Learn mode section) has two
phases, both driven from the same song data (see tutor_mode.py):
  1. Demo playback -- the song plays once with real audio + the LED
     ring showing each note's color as it sounds (console print stands
     in for the OLED note-name readout until that's wired -- OLED is
     still its own undone firmware item, see play.py's docstring).
  2. Color-matching game -- the ring shows each note's color in turn
     and *waits* for the child to press the matching button before
     advancing, no penalty on a miss (TutorSession below).

SCORES is the source of truth: each song is a list of
(note_name, duration_in_beats) pairs. note_name uses the same
"C4"/"F#4"/"Bb3" scientific-pitch-notation style as
audio/play_melody.py's note_to_midi() (parsed the same way here, via
parse_note_name() below, just split into (letter, octave, accidental)
instead of a combined MIDI number -- that lets the demo phase drive
ChromaCadeAudio's letter-based note_on()/note_off() directly instead
of duplicating a second FluidSynth pipeline). None = rest. Duration is
in beats, independent of tempo -- tutor_mode.py's --tempo flag sets
the actual pace, same convention as play_melody.py.

SONGS (bare letter sequences, no octave/rhythm) is derived from SCORES
below, not hand-duplicated, so the demo and the matching game can't
drift apart. This is also *why* letter-only matching in TutorSession
is correct, not just simpler: the color cue represents the note's
pitch *class* (chroma), and octave equivalence is one of this
project's core teaching goals (see CLAUDE.md) -- pressing that color's
button in any octave should count as a match, not just the exact
octave the demo happened to play it in.

Confidence note, read before trusting this data: all six bundled
songs' *note* sequences were checked against a phrase-by-phrase
breakdown (see git history for this file). *Rhythm* confidence varies
-- Hot Cross Buns and Twinkle Twinkle Little Star use their real
phrase-accurate rhythm (both are about as universally known as
children's-song rhythm gets); Mary Had a Little Lamb, Ode to Joy, and
Frere Jacques use a flat quarter-note placeholder rhythm, not a
verified transcription. Happy Birthday's notes came directly from a
phrase-by-phrase breakdown (see _phrase() calls below); its rhythm is
the standard well-known 3/4 shape, not a placeholder, but hasn't been
demo-verified by ear yet either. Run tutor_mode.py's demo phase for
real and listen before trusting the placeholder/unverified ones --
same verify-on-real-hardware culture as the rest of this project, just
applied to song data instead of GPIO.
"""

import re

_NOTE_NAME_RE = re.compile(r"^([A-Ga-g])(#|b)?(-?\d+)$")


def parse_note_name(name):
    """'F#5' -> ('F', 5, 1); 'Bb3' -> ('B', 3, -1); 'C4' -> ('C', 4, 0).
    Accidental is -1/0/1 (flat/natural/sharp), matching audio_engine.py's
    convention (rocker_accidental() etc.), not a +-1 semitone int with a
    different sign convention."""
    m = _NOTE_NAME_RE.match(name.strip())
    if not m:
        raise ValueError(f"Can't parse note name: {name!r} (expected e.g. 'C4', 'F#5', 'Bb3')")
    letter, accidental_char, octave = m.groups()
    accidental = {"#": 1, "b": -1, None: 0}[accidental_char]
    return letter.upper(), int(octave), accidental


def _score(letters, octave, rhythm):
    """Zips a bare letter string with a fixed octave and a per-note
    rhythm list into (note_name, duration) pairs -- all five bundled
    songs are single-octave (no octave leaps), see module docstring."""
    notes = [f"{letter}{octave}" for letter in letters]
    if len(notes) != len(rhythm):
        raise ValueError(f"{len(notes)} notes but {len(rhythm)} durations")
    return list(zip(notes, rhythm))


def _phrase(note_names, rhythm):
    """Zips explicit note names (already carrying their own octave and,
    unlike _score() above, optionally an accidental -- e.g. 'Bb4') with
    a rhythm list. For songs that cross octaves, which _score()'s
    single-fixed-octave assumption can't express."""
    if len(note_names) != len(rhythm):
        raise ValueError(f"{len(note_names)} notes but {len(rhythm)} durations")
    return list(zip(note_names, rhythm))


# Real phrase-accurate rhythm -- see module docstring.
_HCB_PHRASE = [1, 1, 2]
_HOT_CROSS_BUNS_RHYTHM = _HCB_PHRASE + _HCB_PHRASE + [0.5] * 8 + _HCB_PHRASE

# Real phrase-accurate rhythm -- see module docstring.
_TWINKLE_RHYTHM = [1, 1, 1, 1, 1, 1, 2] * 6

# Happy Birthday's standard 3/4 rhythm: "Hap-py Birth-day to you" is
# eighth, eighth, quarter, quarter, quarter, half (6 syllables); the
# "dear ___" line has one extra syllable before the closing half note.
# Not yet phrase-checked against a live demo run like Hot Cross
# Buns/Twinkle above -- standard/well-known enough to be a reasonable
# placeholder, but listen via tutor_mode.py's demo phase before fully
# trusting it, same as this module's other unverified rhythms.
_HB_LINE_RHYTHM = [0.5, 0.5, 1, 1, 1, 2]
_HB_DEAR_LINE_RHYTHM = [0.5, 0.5, 1, 1, 1, 1, 2]

SCORES = {
    "Hot Cross Buns": _score("EDCEDCCCCCDDDDEDC", 4, _HOT_CROSS_BUNS_RHYTHM),
    "Mary Had a Little Lamb": _score(
        "EDCDEEEDDDEGGEDCDEEEEDDEDC", 4, [1] * 26  # placeholder rhythm
    ),
    "Twinkle Twinkle Little Star": _score(
        "CCGGAAGFFEEDDCGGFFEEDGGFFEEDCCGGAAGFFEEDDC", 4, _TWINKLE_RHYTHM
    ),
    "Ode to Joy": _score(
        "EEFGGFEDCCDEEDDEEFGGFEDCCDEDC", 4, [1] * 29  # placeholder rhythm
    ),
    "Frere Jacques": _score(
        "CDECCDECEFGEFGGAGFECGAGFECCGCCGC", 4, [1] * 32  # placeholder rhythm
    ),
    # Only bundled song that crosses octaves (C4 up to C5, "dear") or
    # uses an accidental (Bb4 in the closing line) -- see _phrase()
    # above vs. _score() for the existing single-octave songs.
    "Happy Birthday": (
        _phrase(["C4", "C4", "D4", "C4", "F4", "E4"], _HB_LINE_RHYTHM)
        + _phrase(["C4", "C4", "D4", "C4", "G4", "F4"], _HB_LINE_RHYTHM)
        + _phrase(["C4", "C4", "C5", "A4", "F4", "E4", "D4"], _HB_DEAR_LINE_RHYTHM)
        + _phrase(["Bb4", "Bb4", "A4", "F4", "G4", "F4"], _HB_LINE_RHYTHM)
    ),
}

# Bare letter sequences for the color-matching phase -- derived from
# SCORES (see module docstring for why octave/duration are dropped
# deliberately, and why deriving rather than hand-duplicating matters).
SONGS = {
    name: [parse_note_name(note)[0] for note, _duration in score if note is not None]
    for name, score in SCORES.items()
}

# Optional instructional prompts shown alongside the color-matching
# target in Tutor mode -- Simon mode (which also draws from SONGS as
# one of its sequence sources) stays plain note-matching with no
# prompts, see chromacade.py. Keyed by index into SONGS[song_name] (a
# specific *occurrence* of a letter, e.g. "this one C", not every C),
# not by letter -- most songs have no entry here and show nothing
# extra. Purely a teaching cue, not enforced: TutorSession.press()
# still matches on letter alone regardless of the child's actual
# octave/accidental, same forgiving, octave/accidental-agnostic
# matching as every other song (see module docstring above).
PROMPTS = {
    "Happy Birthday": {
        14: "OCTAVE UP!",
        15: "OCTAVE BACK DOWN!",
        19: "PLAY THIS FLAT!!",
        20: "PLAY THIS FLAT!!",
        21: "BACK TO NATURAL",
    },
}


class TutorSession:
    def __init__(self, song):
        if not song:
            raise ValueError("song must be a non-empty sequence of letters")
        self.song = list(song)
        self.index = 0

    @property
    def target(self):
        """The letter the child should press next, or None once the
        song is complete."""
        if self.is_complete():
            return None
        return self.song[self.index]

    def is_complete(self):
        return self.index >= len(self.song)

    def press(self, letter):
        """Register a note-button press. Returns True if it matched the
        current target and the sequence advanced, False otherwise (wrong
        note, or the song is already complete) -- caller decides what,
        if anything, to do differently on a miss (Tutor mode: nothing,
        just don't advance)."""
        if self.is_complete():
            return False
        if letter == self.song[self.index]:
            self.index += 1
            return True
        return False

    def reset(self):
        self.index = 0
