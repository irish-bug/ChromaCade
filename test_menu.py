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
    assert MODES == ["Explore", "Tutor", "Simon", "Power Off", "Reboot"]
    menu.rotate(1)
    assert menu.highlighted_mode == "Tutor"
    menu.rotate(1)
    assert menu.highlighted_mode == "Simon"
    menu.rotate(1)
    assert menu.highlighted_mode == "Power Off"
    menu.rotate(1)
    assert menu.highlighted_mode == "Reboot"
    menu.rotate(1)
    assert menu.highlighted_mode == "Explore"  # wrapped


def test_rotate_before_entering_is_noop():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.rotate(1)
    assert menu.mode_index == 0


def test_select_play_returns_play_result():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    assert menu.highlighted_mode == "Explore"
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


# --- Chord songs: "-- Notes only --" / "-- Chord songs --" grouping,
# added 2026-09-02. chord_songs defaults to empty (every test above
# this point never passes it) specifically so those all keep proving
# the flat-list behavior is unchanged when there's nothing to
# separate -- see _grouped_with_headers()'s own docstring.

MIXED_SONGS = ["Hot Cross Buns", "Chord Song A", "Twinkle", "Chord Song B"]
MIXED_CHORD_SONGS = {"Chord Song A", "Chord Song B"}


def test_no_headers_when_chord_songs_empty():
    menu = Menu(SONGS, SIMON_SOURCES, chord_songs=frozenset())
    menu.enter()
    menu.rotate(1)
    menu.select()
    lines = menu.display_lines()
    assert not any(line.strip().startswith("--") for line in lines)


def test_no_headers_when_every_song_has_chords():
    # One group empty (nothing left to call "Notes only") -- same as
    # the empty case, nothing to usefully separate.
    menu = Menu(SONGS, SIMON_SOURCES, chord_songs=set(SONGS))
    menu.enter()
    menu.rotate(1)
    menu.select()
    lines = menu.display_lines()
    assert not any(line.strip().startswith("--") for line in lines)


def test_mixed_songs_get_both_headers():
    menu = Menu(MIXED_SONGS, SIMON_SOURCES, chord_songs=MIXED_CHORD_SONGS)
    menu.enter()
    menu.rotate(1)
    menu.select()
    texts = [text for text, _item in menu._song_display]
    assert "-- Notes only --" in texts
    assert "-- Chord songs --" in texts
    # Notes-only songs come first, chord songs after -- and each real
    # song still appears exactly once.
    notes_idx = texts.index("-- Notes only --")
    chords_idx = texts.index("-- Chord songs --")
    assert notes_idx < chords_idx
    assert set(MIXED_SONGS) - MIXED_CHORD_SONGS == {
        texts[i] for i in range(notes_idx + 1, chords_idx)
    }
    assert MIXED_CHORD_SONGS == set(texts[chords_idx + 1 :])


def test_entering_song_stage_lands_on_a_real_song_not_a_header():
    menu = Menu(MIXED_SONGS, SIMON_SOURCES, chord_songs=MIXED_CHORD_SONGS)
    menu.enter()
    menu.rotate(1)
    menu.select()
    assert menu.highlighted_song is not None
    assert not menu.highlighted_song.startswith("--")
    assert menu.highlighted_song not in MIXED_CHORD_SONGS  # first group is "Notes only"


def test_rotate_skips_over_header_lines():
    menu = Menu(MIXED_SONGS, SIMON_SOURCES, chord_songs=MIXED_CHORD_SONGS)
    menu.enter()
    menu.rotate(1)
    menu.select()
    seen = [menu.highlighted_song]
    for _ in range(len(MIXED_SONGS) - 1):
        menu.rotate(1)
        seen.append(menu.highlighted_song)
    assert None not in seen
    assert set(seen) == set(MIXED_SONGS)  # every real song visited, no header ever highlighted


def test_rotate_backward_wraps_past_headers_to_last_chord_song():
    menu = Menu(MIXED_SONGS, SIMON_SOURCES, chord_songs=MIXED_CHORD_SONGS)
    menu.enter()
    menu.rotate(1)
    menu.select()
    menu.rotate(-1)
    assert menu.highlighted_song == "Chord Song B"  # last item overall, wrapping backward from the first


def test_select_chord_song_after_navigating_past_header():
    menu = Menu(MIXED_SONGS, SIMON_SOURCES, chord_songs=MIXED_CHORD_SONGS)
    menu.enter()
    menu.rotate(1)
    menu.select()
    for _ in range(3):  # Hot Cross Buns -> Twinkle -> Chord Song A -> Chord Song B
        menu.rotate(1)
    result = menu.select()
    assert result == ("tutor", "Chord Song B")


def test_display_lines_headers_never_get_the_highlight_marker():
    menu = Menu(MIXED_SONGS, SIMON_SOURCES, chord_songs=MIXED_CHORD_SONGS)
    menu.enter()
    menu.rotate(1)
    menu.select()
    # Navigation order is grouped (notes-only songs first, in their
    # relative order, then chord songs), not MIXED_SONGS' own order --
    # see test_mixed_songs_get_both_headers.
    navigation_order = ["Hot Cross Buns", "Twinkle", "Chord Song A", "Chord Song B"]
    for song in navigation_order:
        lines = menu.display_lines(max_lines=10)
        marked = [line for line in lines if line.startswith(">")]
        assert len(marked) == 1
        assert song in marked[0]
        assert not marked[0].strip(">").strip().startswith("--")
        menu.rotate(1)


def test_display_lines_short_list_unaffected_by_scroll_logic():
    menu = Menu(SONGS, SIMON_SOURCES)  # only 2 songs, module-level fixture
    menu.enter()
    menu.rotate(1)
    menu.select()
    lines = menu.display_lines(max_lines=5)
    assert len(lines) == 1 + len(SONGS)  # header + both songs, nothing cut


# --- Power Off / Reboot confirm stage (added 2026-08-16) ---


def _menu_at_power_off():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(3)  # Explore -> Tutor -> Simon -> Power Off
    assert menu.highlighted_mode == "Power Off"
    return menu


def test_selecting_power_off_enters_confirm_stage_defaulting_to_no():
    menu = _menu_at_power_off()
    result = menu.select()
    assert result is None
    assert menu.stage == "confirm"
    assert menu.highlighted_confirm_option == "No"


def test_confirming_no_cancels_back_to_mode_stage():
    menu = _menu_at_power_off()
    menu.select()  # -> confirm, defaults to "No"
    result = menu.select()
    assert result is None
    assert menu.stage == "mode"


def test_confirming_yes_returns_system_poweroff_result():
    menu = _menu_at_power_off()
    menu.select()  # -> confirm
    menu.rotate(1)  # No -> Yes
    result = menu.select()
    assert result == ("system", "poweroff")


def test_reboot_confirm_flow_returns_system_reboot_result():
    menu = Menu(SONGS, SIMON_SOURCES)
    menu.enter()
    menu.rotate(4)  # -> Reboot
    assert menu.highlighted_mode == "Reboot"
    menu.select()  # -> confirm
    menu.rotate(1)  # No -> Yes
    result = menu.select()
    assert result == ("system", "reboot")


def test_confirm_stage_display_shows_action_and_options():
    menu = _menu_at_power_off()
    menu.select()
    lines = menu.display_lines()
    assert lines[0] == "Power Off?"
    assert lines[1] == "> No"
    assert lines[2] == "  Yes"


def test_reentering_menu_from_confirm_stage_resets_to_mode():
    menu = _menu_at_power_off()
    menu.select()  # -> confirm
    assert menu.stage == "confirm"
    menu.enter()  # gesture fired again mid-confirmation
    assert menu.stage == "mode"
    assert menu.mode_index == 0
