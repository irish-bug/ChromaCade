"""
ChromaCade -- Simon Says (memory mode): sequence sources + hardware-
free session logic. Classic escalating-sequence memory game
(feature-spec.md's Simon/Learn mode section) -- plays a growing
sequence, child must reproduce it from memory, resets on a wrong press
(unlike Tutor mode's no-penalty design -- this one's meant to test,
Tutor's meant to teach).

Three sequence sources, all floated 2026-08-15:
  - A song (tutor_songs.SONGS) -- the growing sequence reveals more of
    a real melody each round.
  - A famous number (FAMOUS_NUMBERS) -- digits mapped to letters via
    digit_to_letter(), wrapping mod 7 (e.g. pi's "3.14159" -> F D G D
    A E: 3->F, 1->D, 4->G, 1->D, 5->A, 9 mod 7=2->E).
  - Fully random -- the classic Simon mechanic, a fresh random letter
    appended each round, no natural end.

Song/number sources are finite (SimonSession.complete becomes True once
exhausted, a genuine "you memorized the whole thing" win); random has
no max_length and no complete state -- see chromacade.py for how each
gets built via pool_source()/random_source().
"""

import random

from audio_engine import LETTER_ORDER

FAMOUS_NUMBERS = {
    # Three different lengths on purpose, requested 2026-08-27, so this
    # source has a difficulty ladder rather than three equally-long
    # games -- Golden Ratio shortest/easiest (10 digits), e medium (15),
    # Pi longest/hardest (unchanged from before, 21). Still arbitrary
    # cutoffs, not tied to anything (all three are irrational -- there's
    # no natural stopping point in the number itself, easy to extend or
    # shorten any of them further).
    "Pi": "3.14159265358979323846",
    "e": "2.71828182845904",
    "Golden Ratio": "1.618033988",
}


def digits_of(number_string):
    """'3.14159' -> [3, 1, 4, 1, 5, 9] -- strips the decimal point."""
    return [int(ch) for ch in number_string if ch.isdigit()]


def digit_to_letter(digit):
    """0=C, 1=D, ... 6=B, then wraps: 7=C, 8=D, 9=E."""
    return LETTER_ORDER[digit % len(LETTER_ORDER)]


def sequence_from_number(number_string):
    """Each digit becomes its own single-letter frozenset step, not a
    bare letter -- number sources never produce chords, but every
    SimonSession step is a frozenset regardless of source (see
    tutor_songs.py's SONGS docstring for the same convention there),
    so this project only ever has one shape to match against, not a
    single-note case and a separate chord case."""
    return [frozenset({digit_to_letter(d)}) for d in digits_of(number_string)]


def pool_source(pool):
    """Fixed, finite sequence source (a song's letter-sets, or a
    number's digit-mapped letters) -- returns (next_step, max_length)
    for SimonSession. next_step(index) just looks up the pool; the
    pool itself doesn't change, so this is fully deterministic/
    testable. Works unchanged for a song pool containing chord steps
    (multi-letter frozensets) -- this function never looks inside a
    step, just indexes into whatever pool it's given."""
    if not pool:
        raise ValueError("pool must be non-empty")

    def next_step(index):
        return pool[index]

    return next_step, len(pool)


def random_source(rng=None):
    """Infinite random sequence source -- returns (next_step, None).
    rng is an injectable random.Random (or the random module itself)
    so tests can seed it; defaults to the real random module. Always a
    single-letter frozenset -- the classic Simon mechanic is one new
    random note per round, not a random chord."""
    rng = rng if rng is not None else random

    def next_step(_index):
        return frozenset({rng.choice(LETTER_ORDER)})

    return next_step, None


class SimonSession:
    def __init__(self, next_step, max_length=None):
        """next_step: callable(index) -> frozenset of letters, the
        step to append when the sequence grows to length index+1 (size
        1 for an ordinary note, more for a chord -- every source
        (random/number/song) always returns a frozenset, see this
        module's source functions above). max_length: None for an
        endless (random) source, or an int for a finite (song/number)
        source -- once the sequence reaches max_length, the session
        marks itself complete instead of growing further."""
        self.next_step = next_step
        self.max_length = max_length
        self.sequence = []
        self.input_index = 0
        self.complete = False
        self._grow()

    def _grow(self):
        if self.max_length is not None and len(self.sequence) >= self.max_length:
            self.complete = True
            return
        step = self.next_step(len(self.sequence))
        # Wrap a bare letter as its own frozenset -- same leniency as
        # tutor_songs.py's TutorSession, so a source/test that hands
        # back a raw letter instead of going through this module's own
        # frozenset-producing sources still works correctly.
        self.sequence.append(step if isinstance(step, frozenset) else frozenset({step}))

    @property
    def round_number(self):
        return len(self.sequence)

    def press(self, held_letters):
        """held_letters: the full set of note letters currently held
        (see tutor_songs.py's TutorSession.press() for the same
        convention -- call again on every press while a chord is being
        built up). Matches via SUPERSET (held_letters must cover the
        current step's letters, extras tolerated), not exact equality
        -- same forgiving spirit as Tutor mode, just still resetting
        the whole round on a genuine miss (Simon tests recall, Tutor
        doesn't -- see module docstring). Returns one of:
        "wrong"            -- didn't match, caller should reset()
        "continue"         -- matched, more of this round's sequence
                               still to press
        "round_complete"   -- matched, finished reproducing this
                               round's full sequence, and it grew
        "complete"         -- matched, and the source is now exhausted
                               (finite source only) -- the whole game
                               is won, caller shouldn't call press()
                               again without reset()
        "already_complete" -- press() called after already complete
        """
        if self.complete:
            return "already_complete"
        if not self.sequence[self.input_index] <= frozenset(held_letters):
            return "wrong"
        self.input_index += 1
        if self.input_index < len(self.sequence):
            return "continue"
        self.input_index = 0
        self._grow()
        return "complete" if self.complete else "round_complete"

    def reset(self):
        self.complete = False
        self.sequence = []
        self.input_index = 0
        self._grow()
