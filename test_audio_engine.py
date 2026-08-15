from audio_engine import NOTE_SEMITONES, clamp_octave, midi_note


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
