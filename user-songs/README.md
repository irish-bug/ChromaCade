# Personal Tutor-mode songs

This directory is for songs you're fine playing on your own ChromaCade but don't
want published in this public repo — most commonly because it's someone else's
copyrighted composition. Playing it on your own instrument is fine; publishing
a transcription of it in a public GitHub repo is a different thing, and this
directory exists specifically to keep that line clean without any manual
git-stash juggling every time you switch branches or pull.

Everything in this directory except this README is `.gitignore`'d (see the
repo's `.gitignore`) — files placed here never get committed or pushed, on
purpose. `tutor_songs.py`'s `load_user_songs()` loads every `.py` file here at
import time and merges it into `SCORES`/`SONGS`/`PROMPTS`, so a song placed
here shows up in the Tutor song menu and as a Simon sequence source exactly
like a bundled song.

## File format

One song per `.py` file. Each file defines:

- `NAME` (str) — the display name, used as the dict key (e.g. `"Ripple"`). If
  it collides with another song's name (bundled or another user file, loaded
  in sorted-filename order), the later one silently wins — this is a personal,
  single-user convenience, not something with conflict handling.
- `SCORE` (list of `(note_name, duration)` tuples) — same format as this
  repo's own `tutor_songs.py` `SCORES` entries. `note_name` is scientific
  pitch notation (`"C4"`, `"F#5"`, `"Bb3"`) or `None` for a rest. `duration`
  is in beats, independent of tempo.
- `PROMPTS` (dict of `int -> str`, optional) — instructional text shown on the
  OLED during the color-matching phase at a specific note *index* (position in
  the letter-only, rest-stripped sequence — not the same indexing as `SCORE`,
  which still includes rests). Purely a teaching cue, never enforced — see
  `tutor_songs.py`'s module docstring for why matching stays letter-only
  regardless of octave/accidental.

Example (`user-songs/example.py`):

```python
NAME = "Example Song"

SCORE = [
    ("G4", 1),      # letter-only index 0
    ("A4", 1),      # letter-only index 1
    ("B4", 0.5),    # letter-only index 2
    (None, 0.5),    # rest -- doesn't get a letter-only index at all
    ("C5", 1),      # letter-only index 3 (NOT 4 -- the rest above isn't counted)
]

# PROMPTS is keyed by letter-only index (see the comments on SCORE
# above), not by position in SCORE. The rest at SCORE position 3
# doesn't count, so letter-only index 3 is actually C5 (SCORE
# position 4) -- this shows "OCTAVE UP!" when C5 becomes the target,
# not when the rest does (a rest is never a target, so a rest index
# would never show anyway, but the position 3 vs. 4 offset is the
# part that trips people up).
PROMPTS = {
    3: "OCTAVE UP!",
}
```

To find the right index for your own song: write out `SCORE`, cross out every rest, and count only what's left starting from 0 -- that position is what `PROMPTS` expects.
