import pytest

from tutor_songs import (
    CHORD_SONGS,
    SCORES,
    SONGS,
    TutorSession,
    _letters_in,
    load_user_songs,
    parse_note_name,
    refresh_user_songs,
)


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
    derived = [_letters_in(note) for note, _ in SCORES[name] if note is not None]
    assert SONGS[name] == derived


def test_target_starts_at_first_note():
    session = TutorSession(["C", "D", "E"])
    assert session.target == {"C"}
    assert not session.is_complete()


def test_correct_press_advances():
    session = TutorSession(["C", "D", "E"])
    assert session.press({"C"}) is True
    assert session.target == {"D"}


def test_wrong_press_does_not_advance():
    session = TutorSession(["C", "D", "E"])
    assert session.press({"G"}) is False
    assert session.target == {"C"}


def test_completes_after_last_note():
    session = TutorSession(["C", "D"])
    session.press({"C"})
    session.press({"D"})
    assert session.is_complete()
    assert session.target is None


def test_press_after_complete_returns_false_and_stays_complete():
    session = TutorSession(["C"])
    session.press({"C"})
    assert session.press({"C"}) is False
    assert session.is_complete()


def test_reset_returns_to_first_note():
    session = TutorSession(["C", "D", "E"])
    session.press({"C"})
    session.press({"D"})
    session.reset()
    assert session.target == {"C"}
    assert not session.is_complete()


def test_repeated_notes_require_repeated_presses():
    # Hot Cross Buns' "CCCCC" run -- a wrong-note press in the middle of a
    # repeated run must not accidentally advance past more than one note.
    session = TutorSession(["C", "C", "C"])
    assert session.press({"C"}) is True
    assert session.press({"G"}) is False
    assert session.target == {"C"}
    assert session.press({"C"}) is True
    assert session.target == {"C"}


def test_empty_song_rejected():
    with pytest.raises(ValueError):
        TutorSession([])


@pytest.mark.parametrize("name", list(SONGS.keys()))
def test_bundled_songs_are_natural_notes_only(name):
    valid_letters = set("CDEFGAB")
    for step in SONGS[name]:
        assert step <= valid_letters


@pytest.mark.parametrize("name", list(SONGS.keys()))
def test_bundled_songs_are_playable_start_to_finish(name):
    session = TutorSession(SONGS[name])
    for step in SONGS[name]:
        assert session.press(step) is True
    assert session.is_complete()


def test_letters_in_rest_is_empty_set():
    assert _letters_in(None) == frozenset()


def test_letters_in_single_note():
    assert _letters_in("C4") == {"C"}


def test_letters_in_chord():
    assert _letters_in(["C4", "E4", "G4"]) == {"C", "E", "G"}


def test_chord_target_is_a_multi_letter_frozenset():
    session = TutorSession([frozenset({"C", "E", "G"})])
    assert session.target == {"C", "E", "G"}


def test_chord_requires_all_letters_held_together():
    session = TutorSession([frozenset({"C", "E", "G"})])
    assert session.press({"C", "E"}) is False  # missing G
    assert session.target == {"C", "E", "G"}
    assert session.press({"C", "E", "G"}) is True
    assert session.is_complete()


def test_chord_match_tolerates_extra_held_notes():
    # Superset match, not exact -- an extra stray note held alongside a
    # correct chord isn't penalized (same forgiving spirit as octave/
    # accidental-agnostic matching elsewhere in this module).
    session = TutorSession([frozenset({"C", "E"})])
    assert session.press({"C", "E", "A"}) is True


def test_score_with_chord_derives_multi_letter_song_step():
    score = [(["C4", "E4", "G4"], 1), ("D4", 1)]
    songs = [_letters_in(note) for note, _duration in score if note is not None]
    assert songs == [frozenset({"C", "E", "G"}), frozenset({"D"})]


def test_load_user_songs_missing_directory_returns_empty(tmp_path):
    scores, prompts = load_user_songs(tmp_path / "does-not-exist")
    assert scores == {}
    assert prompts == {}


def test_load_user_songs_empty_directory_returns_empty(tmp_path):
    scores, prompts = load_user_songs(tmp_path)
    assert scores == {}
    assert prompts == {}


def test_load_user_songs_reads_name_and_score(tmp_path):
    (tmp_path / "example.py").write_text(
        'NAME = "Example"\nSCORE = [("C4", 1), ("D4", 1)]\n'
    )
    scores, prompts = load_user_songs(tmp_path)
    assert scores == {"Example": [("C4", 1), ("D4", 1)]}
    assert prompts == {}


def test_load_user_songs_prompts_are_optional(tmp_path):
    (tmp_path / "with_prompts.py").write_text(
        'NAME = "With Prompts"\n'
        'SCORE = [("C4", 1)]\n'
        'PROMPTS = {0: "OCTAVE UP!"}\n'
    )
    scores, prompts = load_user_songs(tmp_path)
    assert scores == {"With Prompts": [("C4", 1)]}
    assert prompts == {"With Prompts": {0: "OCTAVE UP!"}}


def test_load_user_songs_merges_multiple_files(tmp_path):
    (tmp_path / "a.py").write_text('NAME = "Song A"\nSCORE = [("C4", 1)]\n')
    (tmp_path / "b.py").write_text('NAME = "Song B"\nSCORE = [("D4", 1)]\n')
    scores, _ = load_user_songs(tmp_path)
    assert scores == {"Song A": [("C4", 1)], "Song B": [("D4", 1)]}


def test_load_user_songs_name_collision_last_sorted_file_wins(tmp_path):
    (tmp_path / "a_first.py").write_text('NAME = "Same Name"\nSCORE = [("C4", 1)]\n')
    (tmp_path / "b_second.py").write_text('NAME = "Same Name"\nSCORE = [("D4", 1)]\n')
    scores, _ = load_user_songs(tmp_path)
    assert scores == {"Same Name": [("D4", 1)]}


def test_user_songs_merge_into_songs_and_prompts(tmp_path):
    (tmp_path / "example.py").write_text(
        'NAME = "Merge Example"\n'
        'SCORE = [("C4", 1), (None, 1), ("D4", 1)]\n'
        'PROMPTS = {1: "OCTAVE UP!"}\n'
    )
    user_scores, user_prompts = load_user_songs(tmp_path)
    merged_scores = {**SCORES, **user_scores}
    merged_songs = {
        name: [_letters_in(note) for note, _duration in score if note is not None]
        for name, score in merged_scores.items()
    }
    assert merged_songs["Merge Example"] == [frozenset({"C"}), frozenset({"D"})]
    assert user_prompts["Merge Example"] == {1: "OCTAVE UP!"}


# --- refresh_user_songs(), added 2026-09-02 -- lets a long-running
# process (chromacade.service) pick up a song saved via the web
# composer without a restart. These mutate the REAL module-level
# SCORES/SONGS/CHORD_SONGS in place (that's the whole point -- see the
# function's own docstring), so every test below cleans up in a
# finally block rather than leaving a fake song polluting every other
# test that iterates SCORES.keys()/SONGS.keys() (the @pytest.mark.
# parametrize(..., list(SCORES.keys())) tests earlier in this file).


def test_refresh_user_songs_picks_up_new_song_in_place(tmp_path):
    (tmp_path / "fresh.py").write_text('NAME = "Refresh Test Song"\nSCORE = [(["C4", "E4"], 1)]\n')
    assert "Refresh Test Song" not in SCORES
    try:
        result = refresh_user_songs(tmp_path)
        # Same objects, mutated -- not a fresh dict/set the caller has
        # to go re-fetch. This is what lets chromacade.py's own
        # already-imported SCORES/SONGS/CHORD_SONGS see the update
        # immediately, with no re-import.
        assert result is SONGS
        assert "Refresh Test Song" in SCORES
        assert SONGS["Refresh Test Song"] == [frozenset({"C", "E"})]
        assert "Refresh Test Song" in CHORD_SONGS
    finally:
        SCORES.pop("Refresh Test Song", None)
        SONGS.pop("Refresh Test Song", None)
        CHORD_SONGS.discard("Refresh Test Song")


def test_refresh_user_songs_does_not_touch_bundled_songs(tmp_path):
    (tmp_path / "fresh.py").write_text('NAME = "Another Refresh Song"\nSCORE = [("C4", 1)]\n')
    bundled_before = {name: SCORES[name] for name in SCORES if name != "Another Refresh Song"}
    try:
        refresh_user_songs(tmp_path)
        for name, score in bundled_before.items():
            assert SCORES[name] == score
    finally:
        SCORES.pop("Another Refresh Song", None)
        SONGS.pop("Another Refresh Song", None)
        CHORD_SONGS.discard("Another Refresh Song")


def test_refresh_user_songs_is_safe_to_call_repeatedly(tmp_path):
    (tmp_path / "fresh.py").write_text('NAME = "Repeat Refresh Song"\nSCORE = [("D4", 1)]\n')
    try:
        refresh_user_songs(tmp_path)
        refresh_user_songs(tmp_path)  # same file, same NAME -- should just re-merge cleanly, not error/duplicate
        assert SCORES["Repeat Refresh Song"] == [("D4", 1)]
        assert SONGS["Repeat Refresh Song"] == [frozenset({"D"})]
    finally:
        SCORES.pop("Repeat Refresh Song", None)
        SONGS.pop("Repeat Refresh Song", None)
        CHORD_SONGS.discard("Repeat Refresh Song")
