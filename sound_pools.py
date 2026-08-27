"""
ChromaCade -- nope/yay/prompt sound pools for Tutor/Simon feedback,
requested 2026-08-16 (nopes/yays), extended 2026-08-26 (prompts).
Recordings live in audio/nopes/, audio/yays/, and audio/prompts/
(repo root's audio/ dir), all tracked in git -- personal recordings,
not third-party copyrighted content like audio/zelda/'s Navi clips
(see .gitignore). Levels already tuned live on real hardware (peak-
normalized then compressed, see git history) -- this module doesn't
touch volume, just which file plays when.

Six pools, confirmed against the actual recorded files (nopes/: eheh,
nope, startover, tryagain, wahwah -- yays/: brrbrrbrrbrrr, goodjob,
nice, thatsright, youdidit, yuss -- prompts/: keepgoing, alldone):
  - Tutor error: any nopes/ file except startover.wav -- that phrase
    doesn't fit Tutor, which never actually resets/starts over, it
    just doesn't advance (feature-spec.md's "gently don't advance").
  - Simon mistake: exactly startover.wav / tryagain.wav, alternating
    -- Simon genuinely does start the round over on a miss.
  - Simon round-complete (a round, not the whole game): any yays/ file
    except the two reserved "big win" sounds below.
  - Big win (finishing a whole Tutor song OR a whole Simon
    source/game): brrbrrbrrbrrr.wav / youdidit.wav, alternating --
    ONE shared cycler between both modes' completion event (built
    once in chromacade.py, not tracked separately per mode), since the
    user specified the exact same pair/behavior for both.
  - Keep-going prompt: keepgoing.wav, played once when a finished
    Tutor song/Simon game offers "press green to keep going, red to
    stop" instead of dropping straight back to Play (requested
    2026-08-26). Only one recording, no variety needed -- still a
    (single-item) Cycler for interface consistency with every other
    pool chromacade.py calls .next() on.
  - All-done confirmation: alldone.wav, played once red is actually
    pressed to stop. Same single-item-Cycler reasoning as above.

Cycler is the only pure/testable piece here (see test_sound_pools.py)
-- picked over random.choice for every pool since the spec left most
of them unspecified either way ("iterate through the list or pick one
at random"), and cycling guarantees no back-to-back repeat and even
airtime across a pool, easier to reason about/verify than random.
_list_wav_files()/build_pools() are filesystem-dependent -- tested
against a tmp_path fixture instead of the real hardware-only
directories, so this module stays importable/testable without the
actual sound files present.
"""

import os
import subprocess

# Derived from this file's own location, not hardcoded to any one
# device/user's home directory -- found hardcoded to unit #1's builder
# path (/home/shane/ChromaCade) 2026-08-24, broke chromacade.py outright
# on plinkplonk (a different user, plink). Repo root is this file's own
# parent directory since sound_pools.py lives at the repo root alongside
# audio/.
_REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
NOPES_DIR = os.path.join(_REPO_ROOT, "audio", "nopes")
YAYS_DIR = os.path.join(_REPO_ROOT, "audio", "yays")
PROMPTS_DIR = os.path.join(_REPO_ROOT, "audio", "prompts")

STARTOVER_SOUND = "startover.wav"
TRY_AGAIN_SOUND = "tryagain.wav"
BIG_WIN_SOUNDS = ["brrbrrbrrbrrr.wav", "youdidit.wav"]
KEEP_GOING_SOUND = "keepgoing.wav"
ALL_DONE_SOUND = "alldone.wav"


class Cycler:
    """Cycles through a fixed list in order, wrapping around."""

    def __init__(self, items):
        if not items:
            raise ValueError("items must be non-empty")
        self.items = list(items)
        self.index = 0

    def next(self):
        item = self.items[self.index]
        self.index = (self.index + 1) % len(self.items)
        return item


def _list_wav_files(directory, exclude=()):
    exclude = set(exclude)
    return sorted(
        name
        for name in os.listdir(directory)
        if name.endswith(".wav") and name not in exclude
    )


def _require_file(path):
    """Like _list_wav_files, fails loudly (this time on a single named
    file rather than a whole directory) instead of letting build_pools()
    hand back a Cycler pointing at nothing -- see that function's own
    docstring for why silent-until-triggered isn't acceptable here."""
    if not os.path.isfile(path):
        raise FileNotFoundError(path)
    return path


def build_pools():
    """Scans NOPES_DIR/YAYS_DIR/PROMPTS_DIR and returns the six Cyclers
    (dict keyed by name), each holding full paths ready to hand to
    play_wav(). Fails loudly (FileNotFoundError/ValueError) if a
    directory or an expected named file is missing -- no silent
    fallback, a missing sound should be noticed immediately at
    startup, not discovered mid-game as silence."""
    tutor_error = Cycler(
        [os.path.join(NOPES_DIR, name) for name in _list_wav_files(NOPES_DIR, exclude={STARTOVER_SOUND})]
    )
    simon_mistake = Cycler([os.path.join(NOPES_DIR, STARTOVER_SOUND), os.path.join(NOPES_DIR, TRY_AGAIN_SOUND)])
    simon_round_complete = Cycler(
        [os.path.join(YAYS_DIR, name) for name in _list_wav_files(YAYS_DIR, exclude=set(BIG_WIN_SOUNDS))]
    )
    big_win = Cycler([os.path.join(YAYS_DIR, name) for name in BIG_WIN_SOUNDS])
    keep_going = Cycler([_require_file(os.path.join(PROMPTS_DIR, KEEP_GOING_SOUND))])
    all_done = Cycler([_require_file(os.path.join(PROMPTS_DIR, ALL_DONE_SOUND))])
    return {
        "tutor_error": tutor_error,
        "simon_mistake": simon_mistake,
        "simon_round_complete": simon_round_complete,
        "big_win": big_win,
        "keep_going": keep_going,
        "all_done": all_done,
    }


def play_wav(path):
    """Fire-and-forget via aplay through the dmix-backed default ALSA
    device -- see tutor_mode.py's original play_nope_sound() docstring
    (git history) for why no -D device override: ChromaCadeAudio holds
    that device open for the script's whole life, and dmix is what
    lets a second aplay process share it concurrently. stdout
    suppressed (aplay's "Playing WAVE..." line is noise), stderr left
    to surface -- suppressing it once already hid a real bug (the old
    NOPE_SOUND_PATH ~-expansion issue), not worth repeating."""
    subprocess.Popen(["aplay", path], stdout=subprocess.DEVNULL)
