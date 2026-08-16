import pytest

from tutor_songs import SCORES, SONGS, TutorSession, parse_note_name


def test_parse_note_name_natural():
    assert parse_note_name("C4") == ("C", 4, 0)


def test_parse_note_name_sharp():
    assert parse_note_name("F#5") == ("F", 5, 1)


def test_parse_note_name_flat():
    assert parse_note_name("Bb3") == ("B", 3, -1)


def test_parse_note_name_rejects_garbage():
    with pytest.raises(ValueError):
        parse_note_name("H4")


@pytest.mark.parametrize("name", list(SCORES.keys()))
def test_scores_have_matching_note_and_duration_counts(name):
    notes, durations = zip(*SCORES[name])
    assert len(notes) == len(durations)
    assert all(d > 0 for d in durations)


@pytest.mark.parametrize("name", list(SCORES.keys()))
def test_songs_derived_from_scores_not_hand_duplicated(name):
    derived = [parse_note_name(note)[0] for note, _ in SCORES[name] if note is not None]
    assert SONGS[name] == derived


def test_target_starts_at_first_note():
    session = TutorSession(["C", "D", "E"])
    assert session.target == "C"
    assert not session.is_complete()


def test_correct_press_advances():
    session = TutorSession(["C", "D", "E"])
    assert session.press("C") is True
    assert session.target == "D"


def test_wrong_press_does_not_advance():
    session = TutorSession(["C", "D", "E"])
    assert session.press("G") is False
    assert session.target == "C"


def test_completes_after_last_note():
    session = TutorSession(["C", "D"])
    session.press("C")
    session.press("D")
    assert session.is_complete()
    assert session.target is None


def test_press_after_complete_returns_false_and_stays_complete():
    session = TutorSession(["C"])
    session.press("C")
    assert session.press("C") is False
    assert session.is_complete()


def test_reset_returns_to_first_note():
    session = TutorSession(["C", "D", "E"])
    session.press("C")
    session.press("D")
    session.reset()
    assert session.target == "C"
    assert not session.is_complete()


def test_repeated_notes_require_repeated_presses():
    # Hot Cross Buns' "CCCCC" run -- a wrong-note press in the middle of a
    # repeated run must not accidentally advance past more than one note.
    session = TutorSession(["C", "C", "C"])
    assert session.press("C") is True
    assert session.press("G") is False
    assert session.target == "C"
    assert session.press("C") is True
    assert session.target == "C"


def test_empty_song_rejected():
    with pytest.raises(ValueError):
        TutorSession([])


@pytest.mark.parametrize("name", list(SONGS.keys()))
def test_bundled_songs_are_natural_notes_only(name):
    valid_letters = set("CDEFGAB")
    assert set(SONGS[name]) <= valid_letters


@pytest.mark.parametrize("name", list(SONGS.keys()))
def test_bundled_songs_are_playable_start_to_finish(name):
    session = TutorSession(SONGS[name])
    for letter in SONGS[name]:
        assert session.press(letter) is True
    assert session.is_complete()
