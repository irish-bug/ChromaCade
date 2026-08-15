import pytest

from audio_engine import (
    NOTE_SEMITONES,
    clamp_octave,
    joystick_bend_fraction,
    midi_note,
    pitch_bend_value,
    rocker_accidental,
)


def test_note_semitones_covers_all_seven_letters():
    assert set(NOTE_SEMITONES.keys()) == {"C", "D", "E", "F", "G", "A", "B"}


def test_c4_is_midi_60():
    assert midi_note("C", octave=4) == 60


def test_a4_is_midi_69_the_440hz_reference():
    assert midi_note("A", octave=4) == 69


def test_all_seven_letters_at_octave_4():
    expected = {"C": 60, "D": 62, "E": 64, "F": 65, "G": 67, "A": 69, "B": 71}
    for letter, note in expected.items():
        assert midi_note(letter, octave=4) == note


def test_octave_shift_moves_by_twelve_semitones():
    assert midi_note("C", octave=5) - midi_note("C", octave=4) == 12
    assert midi_note("C", octave=3) - midi_note("C", octave=4) == -12


def test_sharp_raises_one_semitone():
    assert midi_note("C", octave=4, accidental=1) == midi_note("C", octave=4) + 1


def test_flat_lowers_one_semitone():
    assert midi_note("C", octave=4, accidental=-1) == midi_note("C", octave=4) - 1


def test_octave_0_and_8_match_the_confirmed_range():
    # feature-spec.md: 8 octaves, C0-C8, confirmed via live speaker sweep
    assert midi_note("C", octave=0) == 12
    assert midi_note("C", octave=8) == 108


def test_clamp_octave_moves_within_range():
    assert clamp_octave(4, 1) == 5
    assert clamp_octave(4, -1) == 3


def test_clamp_octave_stops_at_the_confirmed_floor_and_ceiling():
    assert clamp_octave(0, -1) == 0
    assert clamp_octave(8, 1) == 8


def test_clamp_octave_handles_a_runaway_gesture_in_one_step():
    # a whole burst of clicks still only ever moves one octave per
    # commit()ed gesture, but clamp_octave itself should be safe even
    # if called with a larger delta than that
    assert clamp_octave(0, -5) == 0
    assert clamp_octave(8, 5) == 8


def test_rocker_accidental_natural_when_neither_throw_active():
    assert rocker_accidental(flat_active=False, sharp_active=False) == 0


def test_rocker_accidental_flat_throw():
    assert rocker_accidental(flat_active=True, sharp_active=False) == -1


def test_rocker_accidental_sharp_throw():
    assert rocker_accidental(flat_active=False, sharp_active=True) == 1


def test_rocker_accidental_both_active_is_a_wiring_fault_falls_back_natural():
    assert rocker_accidental(flat_active=True, sharp_active=True) == 0


def test_joystick_bend_fraction_at_center_is_zero():
    assert joystick_bend_fraction(1.65) == pytest.approx(0.0, abs=0.01)


def test_joystick_bend_fraction_low_voltage_is_positive_sharp():
    # confirmed inverted as wired -- forward push reads as lower voltage
    # but should mean sharp/positive bend
    assert joystick_bend_fraction(0.0) == pytest.approx(1.0, abs=0.01)


def test_joystick_bend_fraction_high_voltage_is_negative_flat():
    assert joystick_bend_fraction(3.3) == pytest.approx(-1.0, abs=0.01)


def test_joystick_bend_fraction_clamped_past_measured_extremes():
    assert joystick_bend_fraction(-1.0) == 1.0
    assert joystick_bend_fraction(5.0) == -1.0


def test_pitch_bend_value_zero_at_center():
    assert pitch_bend_value(0.0) == 0


def test_pitch_bend_value_half_semitone_up_at_full_positive_bend():
    assert pitch_bend_value(1.0, max_semitones=0.5) == 1024


def test_pitch_bend_value_half_semitone_down_at_full_negative_bend():
    assert pitch_bend_value(-1.0, max_semitones=0.5) == -1024


def test_pitch_bend_value_clamped_to_valid_synth_range():
    assert pitch_bend_value(1.0, max_semitones=10) == 8191
    assert pitch_bend_value(-1.0, max_semitones=10) == -8192
