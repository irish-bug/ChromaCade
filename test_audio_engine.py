import os

os.environ.setdefault("SDL_AUDIODRIVER", "dummy")  # headless audio backend for pygame.mixer

import pytest

from audio_engine import ChromaCadeAudio

SEMITONE = 2 ** (1 / 12)

BASE_FREQS_OCTAVE_4 = {
    "A": 440.00,
    "B": 493.88,
    "C": 261.63,
    "D": 293.66,
    "E": 329.63,
    "F": 349.23,
    "G": 392.00,
}


@pytest.fixture
def audio():
    a = ChromaCadeAudio()
    yield a
    a.quit()


def test_base_frequencies_at_octave_4_natural(audio):
    for note, freq in BASE_FREQS_OCTAVE_4.items():
        assert audio.calculate_freq(note) == pytest.approx(freq, abs=0.01)


@pytest.mark.parametrize("octave,multiplier", [(4, 1.0), (5, 2.0), (3, 0.5), (6, 4.0)])
def test_octave_shift_doubles_or_halves_per_octave(audio, octave, multiplier):
    audio.set_octave(octave)
    assert audio.calculate_freq("A") == pytest.approx(440.00 * multiplier, rel=1e-6)


def test_sharp_raises_one_semitone(audio):
    audio.set_accidental(1)
    assert audio.calculate_freq("C") == pytest.approx(261.63 * SEMITONE, rel=1e-6)


def test_flat_lowers_one_semitone(audio):
    audio.set_accidental(-1)
    assert audio.calculate_freq("C") == pytest.approx(261.63 / SEMITONE, rel=1e-6)


def test_accidental_offset_clamped_to_valid_range(audio):
    audio.set_accidental(5)
    assert audio.accidental_offset == 1
    audio.set_accidental(-5)
    assert audio.accidental_offset == -1


def test_octave_and_accidental_shifts_combine(audio):
    audio.set_octave(5)
    audio.set_accidental(1)
    assert audio.calculate_freq("A") == pytest.approx(440.00 * 2.0 * SEMITONE, rel=1e-6)


def test_pitch_bend_zero_leaves_frequency_unchanged(audio):
    assert audio.apply_pitch_bend_math(440.0, 0.0) == pytest.approx(440.0)


def test_pitch_bend_up_two_semitones_at_max(audio):
    assert audio.apply_pitch_bend_math(440.0, 1.0) == pytest.approx(440.0 * SEMITONE**2, rel=1e-6)


def test_pitch_bend_down_two_semitones_at_min(audio):
    assert audio.apply_pitch_bend_math(440.0, -1.0) == pytest.approx(440.0 / SEMITONE**2, rel=1e-6)


def test_pitch_bend_value_clamped_to_valid_range(audio):
    audio.set_pitch_bend(5.0)
    assert audio.pitch_bend_val == 1.0
    audio.set_pitch_bend(-5.0)
    assert audio.pitch_bend_val == -1.0


def test_note_on_off_tracks_playing_channels(audio):
    assert "C" not in audio.playing_channels
    audio.note_on("C")
    assert "C" in audio.playing_channels
    audio.note_off("C")
    assert "C" not in audio.playing_channels


def test_note_on_while_already_playing_restarts_without_error(audio):
    audio.note_on("C")
    audio.note_on("C")  # note_on() calls note_off() internally first when already playing
    assert "C" in audio.playing_channels
