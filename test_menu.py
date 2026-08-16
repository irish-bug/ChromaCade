import pytest

from menu import MODES, Menu

SONGS = ["Hot Cross Buns", "Twinkle Twinkle Little Star"]
SIMON_SOURCES = ["Random", "Pi", "Hot Cross Buns"]


def test_starts_inactive():
    menu = Menu(SONGS, SIMON_SOURCES)
    assert not menu.active
    assert menu.display_lines() == []


def test_enter_activates_at_mode_stage():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    assert menu.active
    assert menu.stage == "mode"
    assert menu.highlighted_mode == MODES[0]


def test_exit_deactivates():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.exit()
    assert not menu.active


def test_rotate_wraps_mode_selection():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    assert MODES == ["Play", "Tutor", "Simon"]
    menu.rotate(1)
    assert menu.highlighted_mode == "Tutor"
    menu.rotate(1)
    assert menu.highlighted_mode == "Simon"
    menu.rotate(1)
    assert menu.highlighted_mode == "Play"  # wrapped


def test_rotate_before_entering_is_noop():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.rotate(1)
    assert menu.mode_index == 0


def test_select_play_returns_play_result():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    assert menu.highlighted_mode == "Play"
    result = menu.select()
    assert result == ("play",)


def test_select_tutor_advances_to_song_stage_without_a_result():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(1)  # -> "Tutor"
    result = menu.select()
    assert result is None
    assert menu.stage == "song"
    assert menu.highlighted_song == SONGS[0]


def test_select_song_returns_tutor_result():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(1)
    menu.select()  # enter song stage
    menu.rotate(1)
    result = menu.select()
    assert result == ("tutor", SONGS[1])


def test_rotate_wraps_song_selection():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(1)
    menu.select()
    menu.rotate(-1)
    assert menu.highlighted_song == SONGS[-1]  # wrapped backward


def test_select_simon_advances_to_simon_stage_without_a_result():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(2)  # -> "Simon"
    result = menu.select()
    assert result is None
    assert menu.stage == "simon"
    assert menu.highlighted_simon_source == SIMON_SOURCES[0]


def test_select_simon_source_returns_simon_result():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(2)
    menu.select()  # enter simon stage
    menu.rotate(1)
    result = menu.select()
    assert result == ("simon", SIMON_SOURCES[1])


def test_rotate_wraps_simon_selection():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(2)
    menu.select()
    menu.rotate(-1)
    assert menu.highlighted_simon_source == SIMON_SOURCES[-1]  # wrapped backward


def test_select_while_inactive_is_noop():
    menu = Menu(SONGS, SIMON_SOURCES)
    assert menu.select() is None


def test_reentering_resets_to_mode_stage():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(1)
    menu.select()  # now in song stage
    assert menu.stage == "song"
    menu.enter()  # re-enter (e.g. gesture fired again)
    assert menu.stage == "mode"
    assert menu.mode_index == 0


def test_display_lines_marks_highlighted_mode():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    lines = menu.display_lines()
    assert lines[0] == "Select mode:"
    assert lines[1].startswith(">")
    assert lines[2].startswith(" ")


def test_display_lines_marks_highlighted_song():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(1)
    menu.select()
    lines = menu.display_lines()
    assert lines[0] == "Select song:"
    assert lines[1].startswith(">")


def test_display_lines_marks_highlighted_simon_source():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(2)
    menu.select()
    lines = menu.display_lines()
    assert lines[0] == "Select sequence:"
    assert lines[1].startswith(">")


def test_empty_songs_rejected():
    with pytest.raises(ValueError):
        Menu([], SIMON_SOURCES)


def test_empty_simon_sources_rejected():
    with pytest.raises(ValueError):
        Menu(SONGS, [])


# Regression coverage for the truncated-song-list bug (2026-08-15): 5
# songs + a header line is 6 lines, but the OLED only renders 5 --
# display_lines() must scroll rather than silently drop the tail.
FIVE_SONGS = ["A", "B", "C", "D", "E"]


def test_display_lines_caps_at_max_lines():
    menu = Menu(FIVE_SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(1)
    menu.select()
    lines = menu.display_lines(max_lines=5)
    assert len(lines) <= 5


def test_display_lines_keeps_selection_visible_when_scrolled_to_the_end():
    menu = Menu(FIVE_SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(1)
    menu.select()
    for _ in range(len(FIVE_SONGS) - 1):
        menu.rotate(1)
    assert menu.highlighted_song == "E"
    lines = menu.display_lines(max_lines=5)
    assert any(line.startswith(">") and "E" in line for line in lines)


def test_display_lines_every_song_reachable_via_scroll():
    menu = Menu(FIVE_SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(1)
    menu.select()
    for song in FIVE_SONGS:
        lines = menu.display_lines(max_lines=5)
        assert any(line.startswith(">") and song in line for line in lines), (
            f"{song} not visible when highlighted: {lines}"
        )
        menu.rotate(1)


def test_display_lines_short_list_unaffected_by_scroll_logic():
    menu = Menu(SONGS, SIMON_SOURCES)  # only 2 songs, module-level fixture
    menu.enter()
    menu.rotate(1)
    menu.select()
    lines = menu.display_lines(max_lines=5)
    assert len(lines) == 1 + len(SONGS)  # header + both songs, nothing cut
