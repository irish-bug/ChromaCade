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
    return [digit_to_letter(d) for d in digits_of(number_string)]


def pool_source(pool):
    """Fixed, finite sequence source (a song's letters, or a number's
    digit-mapped letters) -- returns (next_letter, max_length) for
    SimonSession. next_letter(index) just looks up the pool; the pool
    itself doesn't change, so this is fully deterministic/testable."""
    if not pool:
        raise ValueError("pool must be non-empty")

    def next_letter(index):
        return pool[index]

    return next_letter, len(pool)


def random_source(rng=None):
    """Infinite random sequence source -- returns (next_letter, None).
    rng is an injectable random.Random (or the random module itself)
    so tests can seed it; defaults to the real random module."""
    rng = rng if rng is not None else random

    def next_letter(_index):
        return rng.choice(LETTER_ORDER)

    return next_letter, None


class SimonSession:
    def __init__(self, next_letter, max_length=None):
        """next_letter: callable(index) -> letter, the letter to
        append when the sequence grows to length index+1. max_length:
        None for an endless (random) source, or an int for a finite
        (song/number) source -- once the sequence reaches max_length,
        the session marks itself complete instead of growing further."""
        self.next_letter = next_letter
        self.max_length = max_length
        self.sequence = []
        self.input_index = 0
        self.complete = False
        self._grow()

    def _grow(self):
        if self.max_length is not None and len(self.sequence) >= self.max_length:
            self.complete = True
            return
        self.sequence.append(self.next_letter(len(self.sequence)))

    @property
    def round_number(self):
        return len(self.sequence)

    def press(self, letter):
        """Returns one of:
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
        if letter != self.sequence[self.input_index]:
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
