import pytest

from song_editor_server import (
    render_user_song_file,
    save_user_song,
    slugify,
    validate_score,
)


def test_slugify_basic():
    assert slugify("My Song") == "my-song"


def test_slugify_strips_punctuation():
    assert slugify("My Song!") == "my-song"


def test_slugify_collapses_whitespace():
    assert slugify("  My    Song  ") == "my-song"


def test_slugify_normalizes_accents():
    assert slugify("Frère Jacques") == "frere-jacques"


def test_slugify_rejects_nothing_left():
    with pytest.raises(ValueError):
        slugify("!!!")


def test_validate_score_accepts_clean_list():
    score = [("C4", 1), (None, 0.5), ("F#5", 2)]
    assert validate_score(score) == [("C4", 1), (None, 0.5), ("F#5", 2)]


def test_validate_score_rejects_empty():
    with pytest.raises(ValueError):
        validate_score([])


def test_validate_score_rejects_bad_note_name():
    with pytest.raises(ValueError):
        validate_score([("H9", 1)])


def test_validate_score_rejects_zero_duration():
    with pytest.raises(ValueError):
        validate_score([("C4", 0)])


def test_validate_score_rejects_negative_duration():
    with pytest.raises(ValueError):
        validate_score([("C4", -1)])


def test_validate_score_rejects_non_pair_entry():
    with pytest.raises(ValueError):
        validate_score([("C4", 1, "extra")])


def test_validate_score_rejects_bool_duration():
    # bool is a subclass of int in Python -- True/False would otherwise
    # silently pass an isinstance(duration, (int, float)) check.
    with pytest.raises(ValueError):
        validate_score([("C4", True)])


def test_validate_score_accepts_chord():
    score = [(["C4", "E4", "G4"], 1)]
    assert validate_score(score) == [(["C4", "E4", "G4"], 1)]


def test_validate_score_rejects_single_note_chord_list():
    with pytest.raises(ValueError):
        validate_score([(["C4"], 1)])


def test_validate_score_rejects_oversized_chord():
    with pytest.raises(ValueError):
        validate_score([(["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"], 1)])


def test_validate_score_rejects_chord_with_bad_note_name():
    with pytest.raises(ValueError):
        validate_score([(["C4", "H4"], 1)])


def test_validate_score_rejects_chord_with_duplicate_letter():
    # C4+C5 collapse to the same letter -- ChromaCadeAudio.playing is
    # keyed by letter, so this would silently drop a note at playback,
    # not actually sound as a chord.
    with pytest.raises(ValueError):
        validate_score([(["C4", "C5", "E4"], 1)])


def test_validate_score_rejects_non_string_in_chord():
    with pytest.raises(ValueError):
        validate_score([(["C4", 4], 1)])


def test_render_user_song_file_format():
    content = render_user_song_file("Example Song", [("G4", 1), (None, 0.5)])
    assert content == (
        "NAME = 'Example Song'\n"
        "\n"
        "SCORE = [\n"
        "    ('G4', 1),\n"
        "    (None, 0.5),\n"
        "]\n"
    )


def test_render_user_song_file_is_valid_python(tmp_path):
    content = render_user_song_file("Test", [("C4", 1)])
    module_path = tmp_path / "rendered.py"
    module_path.write_text(content)
    namespace = {}
    exec(compile(content, str(module_path), "exec"), namespace)
    assert namespace["NAME"] == "Test"
    assert namespace["SCORE"] == [("C4", 1)]


def test_save_user_song_writes_file(tmp_path):
    path = save_user_song("My Test Song", [("C4", 1), ("D4", 1)], directory=tmp_path)
    assert path == tmp_path / "my-test-song.py"
    assert path.exists()
    namespace = {}
    exec(compile(path.read_text(), str(path), "exec"), namespace)
    assert namespace["NAME"] == "My Test Song"
    assert namespace["SCORE"] == [("C4", 1), ("D4", 1)]


def test_save_user_song_refuses_to_overwrite(tmp_path):
    save_user_song("Dup", [("C4", 1)], directory=tmp_path)
    with pytest.raises(FileExistsError):
        save_user_song("Dup", [("D4", 1)], directory=tmp_path)


def test_save_user_song_creates_directory(tmp_path):
    directory = tmp_path / "does-not-exist-yet"
    save_user_song("New", [("C4", 1)], directory=directory)
    assert (directory / "new.py").exists()


def test_save_user_song_rejects_empty_name(tmp_path):
    with pytest.raises(ValueError):
        save_user_song("", [("C4", 1)], directory=tmp_path)


def test_save_user_song_rejects_whitespace_only_name(tmp_path):
    with pytest.raises(ValueError):
        save_user_song("   ", [("C4", 1)], directory=tmp_path)
