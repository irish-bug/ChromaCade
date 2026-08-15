"""
ChromaCade -- audio engine: note math + FluidSynth playback.

NOTE_SEMITONES and midi_note() are pure and hardware-free -- covered by
test_audio_engine.py, no soundfont or audio device needed. ChromaCadeAudio
wraps FluidSynth and needs real audio hardware to mean anything, so it's
not unit tested, same reasoning as hardware_poller.py's own docstring.

Current scope: fixed C4 octave, Acoustic Grand Piano (GM program 0), no
accidentals/pitch-bend/volume/font yet -- those land with their own
firmware items. octave and accidental are already plumbed through
midi_note() and ChromaCadeAudio's state so those items extend this
rather than rework it.
"""

try:
    import fluidsynth
except ImportError:
    fluidsynth = None

SOUNDFONT_PATH = "/usr/share/sounds/sf2/FluidR3_GM.sf2"

# Semitone offset from C, per letter -- physical button order is
# C-D-E-F-G-A-B (gpio-pin-assignments.md), not alphabetical.
NOTE_SEMITONES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi_note(letter, octave=4, accidental=0):
    """MIDI note number for a letter, given octave (C4=60, standard MIDI/SPN
    convention -- octave number increments at C, see feature-spec.md's Note
    range section) and accidental (-1=flat, 0=natural, 1=sharp)."""
    return 12 * (octave + 1) + NOTE_SEMITONES[letter] + accidental


# Confirmed range via live speaker sweep, feature-spec.md's Note range
# section: 8 full octaves, C0-C8. This is the system-level ceiling: it
# will likely need tightening once accidentals/pitch-bend need headroom
# past the selectable edges (see that section's headroom requirement) --
# not done yet, since neither is wired into the firmware yet.
OCTAVE_MIN = 0
OCTAVE_MAX = 8


def clamp_octave(octave, delta):
    return max(OCTAVE_MIN, min(OCTAVE_MAX, octave + delta))


class ChromaCadeAudio:
    def __init__(self, gain=4.5, program=0):
        if fluidsynth is None:
            raise ImportError(
                "pyfluidsynth not installed -- pip3 install pyfluidsynth --break-system-packages"
            )

        self.fs = fluidsynth.Synth()
        self.fs.setting("audio.driver", "alsa")
        self.fs.setting("synth.gain", gain)
        self.fs.start()

        sfid = self.fs.sfload(SOUNDFONT_PATH)
        # sfload() does NOT raise on failure -- returns -1. See
        # open-questions.md / fluidsynth_test.py for why this check matters.
        if sfid == -1:
            raise RuntimeError(f"Failed to load soundfont at {SOUNDFONT_PATH}")
        self.fs.program_select(0, sfid, 0, program)

        self.octave = 4
        self.accidental = 0
        self.playing = {}  # letter -> midi note currently sounding

    def note_on(self, letter):
        if letter in self.playing:
            self.note_off(letter)
        note = midi_note(letter, self.octave, self.accidental)
        self.fs.noteon(0, note, 100)
        self.playing[letter] = note

    def note_off(self, letter):
        if letter in self.playing:
            self.fs.noteoff(0, self.playing[letter])
            del self.playing[letter]

    def octave_change(self, delta):
        """Applies globally to whatever's currently held (feature-spec.md),
        not just future presses -- re-triggers held notes at the new
        octave so the pitch audibly shifts under a held finger."""
        self.octave = clamp_octave(self.octave, delta)
        for letter, old_note in list(self.playing.items()):
            self.fs.noteoff(0, old_note)
            new_note = midi_note(letter, self.octave, self.accidental)
            self.fs.noteon(0, new_note, 100)
            self.playing[letter] = new_note

    def quit(self):
        for letter in list(self.playing):
            self.note_off(letter)
        self.fs.delete()


if __name__ == "__main__":
    import time

    print("ChromaCade audio engine smoke test -- C major triad")
    audio = ChromaCadeAudio()
    for letter in ["C", "E", "G"]:
        audio.note_on(letter)
    time.sleep(2)
    for letter in ["C", "E", "G"]:
        audio.note_off(letter)
    time.sleep(0.5)
    audio.quit()
    print("Done.")
