"""
ChromaCade -- audio engine: note math + FluidSynth playback.

NOTE_SEMITONES and midi_note() are pure and hardware-free -- covered by
test_audio_engine.py, no soundfont or audio device needed. ChromaCadeAudio
wraps FluidSynth and needs real audio hardware to mean anything, so it's
not unit tested, same reasoning as hardware_poller.py's own docstring.

Current scope: octave, accidental, pitch-bend, and volume are all
wired up (see their respective functions/methods below); font
switching isn't yet -- DEFAULT_PROGRAM is an interim fixed voice, not
a real default. Currently Church Organ, not Acoustic Grand Piano:
organ sustains at constant volume for as long as a note is held
(confirmed live 2026-08-15 against the piano's authentic
decay-even-while-held behavior), which makes it a better voice for
testing/evaluating every *other* control while they're still being
built. Once the curated font list and font-encoder switching land
(see open-questions.md), this stops mattering -- any voice will be
one encoder click away.
"""

try:
    import fluidsynth
except ImportError:
    fluidsynth = None

SOUNDFONT_PATH = "/usr/share/sounds/sf2/FluidR3_GM.sf2"

# MIDI velocity for every note -- there's no pressure/velocity-sensing
# input on this build (buttons are just on/off), so there's no
# expressiveness lost by always using max. Bumped from 100 to 127
# (max) 2026-08-15 to test whether it helps the piano patch's natural
# decay ring out longer/louder -- many multi-velocity-layer soundfonts
# trigger a different, more sustained sample at high velocity. If this
# doesn't meaningfully help, the fast decay is probably just authentic
# to how the Acoustic Grand Piano sample was recorded (a real piano
# note decays even while held -- the key just keeps the damper off the
# string), and a genuinely sustained voice (organ, pad) would be the
# real fix, not a velocity tweak.
NOTE_VELOCITY = 127

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


def rocker_accidental(flat_active, sharp_active):
    """Maps the 3-position rocker's raw (flat, sharp) throw state to an
    accidental value (-1=flat, 0=natural, 1=sharp). Both active at once
    is a wiring fault, not a real switch position (testing/rocker_test.py
    calls this out explicitly) -- falls back to natural rather than
    raising, since this needs to be safe to call from a GPIO callback."""
    if flat_active and sharp_active:
        return 0
    if flat_active:
        return -1
    if sharp_active:
        return 1
    return 0


def smooth(previous, new_value, alpha):
    """Exponential moving average. alpha closer to 1.0 tracks new
    values faster (less smoothing, less lag); closer to 0.0 smooths out
    more noise at the cost of more lag. Used to take the jitter out of
    the joystick's raw voltage reading -- confirmed live 2026-08-15 as
    feeling "jumpy" without this."""
    return alpha * new_value + (1 - alpha) * previous


# Joystick calibration -- measured via testing/ads1115_test.py's live
# sweep 2026-08-14: raw voltage spans ~0-3.3V (min=-0.005V, max=3.278V).
# Center is the ADC's theoretical midpoint (3.3/2); measured rest
# readings clustered close to it.
JOYSTICK_CENTER_VOLTAGE = 1.65
JOYSTICK_MAX_DEVIATION = 1.65


def joystick_bend_fraction(voltage):
    """Raw joystick voltage -> normalized bend, -1.0 (full flat) to 1.0
    (full sharp). Confirmed inverted as wired (gpio-pin-assignments.md):
    pushing forward reads as LOWER voltage, but forward should mean
    sharp/positive bend, so this is (center - voltage), not voltage
    itself."""
    fraction = (JOYSTICK_CENTER_VOLTAGE - voltage) / JOYSTICK_MAX_DEVIATION
    return max(-1.0, min(1.0, fraction))


# Confirmed from the installed pyfluidsynth's own Synth.pitch_bend()
# docstring: 2048 units = 1 semitone, valid range -8192..8191 (+-4
# semitones max -- more headroom than this needs).
PITCH_BEND_UNITS_PER_SEMITONE = 2048
PITCH_BEND_MIN = -8192
PITCH_BEND_MAX = 8191

# Started at 0.5 (bend approaches but never reaches the neighboring
# sharp/flat); bumped to the full range pyfluidsynth supports 2026-08-15
# to test how it feels. At this range a held note can bend all the way
# into being its neighbor -- see bent_letter() below, which is exactly
# why that matters for more than just pitch.
MAX_BEND_SEMITONES = 4.0


def pitch_bend_value(bend_fraction, max_semitones=MAX_BEND_SEMITONES):
    """Normalized bend (-1.0..1.0) -> the raw value Synth.pitch_bend()
    expects, clamped to its valid range."""
    val = round(bend_fraction * max_semitones * PITCH_BEND_UNITS_PER_SEMITONE)
    return max(PITCH_BEND_MIN, min(PITCH_BEND_MAX, val))


LETTER_ORDER = ["C", "D", "E", "F", "G", "A", "B"]


def bent_letter(letter, bend_fraction, max_semitones=MAX_BEND_SEMITONES):
    """Which letter a bent note is now closer to -- the actual bent
    pitch's nearest natural letter, wrapping across the octave. Most
    letter pairs are a full 2 semitones apart, but E-F and B-C are only
    1 semitone apart (the diatonic scale's two half-steps, the "no
    black key" pairs on a piano) -- so a modest bend crosses into
    neighbor territory on E or B while the same bend leaves C/D/F/G/A
    untouched. Deliberate, not a bug: real music theory showing up as
    an audible/visible asymmetry.

    Compares against the absolute bent pitch rather than only checking
    the immediate neighbor, since a large enough bend can cross more
    than one letter boundary -- e.g. G bent up the full 4 semitones
    lands exactly on B's pitch, past A, not just at it."""
    if bend_fraction == 0:
        return letter
    bend_semitones = bend_fraction * max_semitones
    target = (NOTE_SEMITONES[letter] + bend_semitones) % 12

    def circular_distance(pitch):
        diff = (pitch - target) % 12
        return min(diff, 12 - diff)

    # ties (exactly halfway between two letters) favor moving away
    # from the original letter, matching the old ">= halfway crosses"
    # rule this replaces
    return min(
        LETTER_ORDER,
        key=lambda l: (circular_distance(NOTE_SEMITONES[l]), l == letter),
    )


# Volume pot calibration -- same ADS1115, same 0-3.3V range as the
# joystick (testing/ads1115_test.py's live sweep). Confirmed inverted
# as wired (gpio-pin-assignments.md): clockwise turn reads as LOWER
# voltage, but clockwise should mean louder.
POT_MAX_VOLTAGE = 3.3


def pot_volume_fraction(voltage):
    """Raw pot voltage -> normalized volume, 0.0 (silent) to 1.0 (full
    clockwise turn)."""
    fraction = 1.0 - (voltage / POT_MAX_VOLTAGE)
    return max(0.0, min(1.0, fraction))


# Deliberate ceiling independent of the pot's own range (feature-spec.md
# Normal play mode): even at full clockwise turn, output should never
# exceed a level appropriate for a small room. Starting guess, tune live.
VOLUME_CEILING = 0.7

# Perceived loudness isn't linear with MIDI CC7 -- confirmed live
# 2026-08-15: a straight linear pot->volume mapping left the machine
# silent through roughly the lower two-thirds of the pot's travel,
# only becoming audible near the top (loudness perception is roughly
# logarithmic, so a linear control crams most of the audible range
# into a small slice of physical rotation). A gamma curve (< 1) gives
# low pot positions relatively more MIDI headroom than a linear
# mapping would, so audible change spreads more evenly across the
# whole turn. Starting guess (square root), tune live.
VOLUME_CURVE_GAMMA = 0.5


def volume_midi_value(volume_fraction, ceiling=VOLUME_CEILING, gamma=VOLUME_CURVE_GAMMA):
    """Normalized volume (0.0-1.0) -> the 0-127 value Synth.cc(chan, 7,
    val) (MIDI channel volume, confirmed from the installed
    pyfluidsynth's own docstring) expects, gamma-curved for perceived
    loudness and scaled by the safety ceiling."""
    curved = volume_fraction**gamma
    val = round(curved * ceiling * 127)
    return max(0, min(127, val))


# GM program 19, Church Organ -- interim default until real font
# switching exists (see module docstring for why organ specifically).
DEFAULT_PROGRAM = 19


class ChromaCadeAudio:
    def __init__(self, gain=4.5, program=DEFAULT_PROGRAM):
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
        self.fs.noteon(0, note, NOTE_VELOCITY)
        self.playing[letter] = note

    def note_off(self, letter):
        if letter in self.playing:
            self.fs.noteoff(0, self.playing[letter])
            del self.playing[letter]

    def _retrigger_held(self):
        """Re-fires everything currently held at the current
        octave/accidental -- shared by octave_change() and
        accidental_change(), both of which apply globally to whatever's
        held (feature-spec.md), not just future presses."""
        for letter, old_note in list(self.playing.items()):
            self.fs.noteoff(0, old_note)
            new_note = midi_note(letter, self.octave, self.accidental)
            self.fs.noteon(0, new_note, NOTE_VELOCITY)
            self.playing[letter] = new_note

    def octave_change(self, delta):
        self.octave = clamp_octave(self.octave, delta)
        self._retrigger_held()

    def accidental_change(self, accidental):
        self.accidental = accidental
        self._retrigger_held()

    def set_pitch_bend(self, bend_fraction):
        """MIDI pitch bend is inherently a whole-channel effect, not
        per-note -- since everything plays on channel 0, this already
        applies to whatever's currently held with no retrigger needed,
        same as the "applies globally" rule for octave/accidental."""
        self.fs.pitch_bend(0, pitch_bend_value(bend_fraction))

    def set_volume(self, volume_fraction):
        """MIDI channel volume (CC7) -- same whole-channel-effect
        reasoning as set_pitch_bend(), no retrigger needed."""
        self.fs.cc(0, 7, volume_midi_value(volume_fraction))

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
