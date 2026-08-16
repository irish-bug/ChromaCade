"""
ChromaCade -- mode/song/sequence menu: pure, hardware-free navigation
state.

Implements control-layout.md's "Menu / mode interaction grammar" and
resolves open-questions.md's "nested vs. flat" menu-structure question
in favor of nested (mode select, then a song/sequence list within
Tutor/Simon) -- chosen because a 5-line 128x64 OLED can't usefully
show a long flat list mixing modes and songs/sequences together, and
nested was the first-listed candidate in that doc.

Split from chromacade.py the same way octave_gesture.py/tutor_songs.py
are split from their hardware-touching callers -- this class only
tracks state and answers "what should happen next given this input,"
no GPIO/OLED/audio calls. See test_menu.py.

Also resolves open-questions.md's "does the menu have a song preview"
question: no, not in this version -- select() starts the song/Simon
game immediately, no snippet playback before confirming.
"""

MODES = ["Explore", "Tutor", "Simon"]  # "Play" renamed 2026-08-16 -- see parental web page


class Menu:
    def __init__(self, songs, simon_sources):
        if not songs:
            raise ValueError("songs must be non-empty")
        if not simon_sources:
            raise ValueError("simon_sources must be non-empty")
        self.songs = list(songs)
        self.simon_sources = list(simon_sources)
        self.active = False
        self.stage = "mode"  # "mode" | "song" | "simon" -- only meaningful while active
        self.mode_index = 0
        self.song_index = 0
        self.simon_index = 0

    def enter(self):
        """Always resets to the top of the menu (mode-select stage) --
        even if re-entering while already active, so on_menu_enter
        firing twice in a row (e.g. a slightly sloppy gesture release/
        re-hold) doesn't leave the child stuck deep in a song list."""
        self.active = True
        self.stage = "mode"
        self.mode_index = 0

    def exit(self):
        self.active = False

    @property
    def highlighted_mode(self):
        return MODES[self.mode_index]

    @property
    def highlighted_song(self):
        return self.songs[self.song_index]

    @property
    def highlighted_simon_source(self):
        return self.simon_sources[self.simon_index]

    def rotate(self, delta):
        """delta is +-1 (or any int), matching on_font_change's
        existing convention. No-op while inactive -- callers shouldn't
        route rotation here unless the menu is actually open, but this
        guards against it anyway."""
        if not self.active:
            return
        if self.stage == "mode":
            self.mode_index = (self.mode_index + delta) % len(MODES)
        elif self.stage == "song":
            self.song_index = (self.song_index + delta) % len(self.songs)
        else:
            self.simon_index = (self.simon_index + delta) % len(self.simon_sources)

    def select(self):
        """Confirms the highlighted option (font button short-click).
        Returns None if still navigating (e.g. moved from mode-select
        into song-select), or a result tuple describing what to do:
        ("play",), ("tutor", song_name), or ("simon", source_name).
        Caller is responsible for actually acting on the result and
        calling exit() -- this class doesn't know about audio/tutor/
        simon sessions/etc."""
        if not self.active:
            return None
        if self.stage == "mode":
            if self.highlighted_mode == "Explore":
                return ("play",)  # internal result identifier unchanged, only the display name is "Explore" now
            if self.highlighted_mode == "Tutor":
                self.stage = "song"
                self.song_index = 0
                return None
            self.stage = "simon"
            self.simon_index = 0
            return None
        if self.stage == "song":
            return ("tutor", self.highlighted_song)
        return ("simon", self.highlighted_simon_source)

    def display_lines(self, max_lines=5):
        """Plain text lines for the OLED to render verbatim -- kept
        here (not in oled_display.py) so the *content* is testable
        without touching Pillow/hardware. oled_display.py owns pixel
        placement/fonts, not word choice.

        max_lines default (5) matches oled_display.py's actual
        capacity (HEIGHT // LINE_HEIGHT) -- kept as a plain int here
        rather than importing that constant, since menu.py must stay
        importable without Pillow/board/hardware libs (see
        test_menu.py, which runs with no hardware present at all).
        Keep these two "5"s in sync by hand if either changes.

        Scrolls to keep the highlighted item visible -- confirmed live
        2026-08-15 that returning every item unconditionally silently
        truncated the song list on-screen once it grew past what fits
        (5 songs + a header line is 6 lines, only 5 render), which
        looked like a missing song rather than a display bug."""
        if not self.active:
            return []
        if self.stage == "mode":
            header, items, index = "Select mode:", MODES, self.mode_index
        elif self.stage == "song":
            header, items, index = "Select song:", self.songs, self.song_index
        else:
            header, items, index = "Select sequence:", self.simon_sources, self.simon_index

        visible_count = max_lines - 1  # header takes one line
        if len(items) <= visible_count:
            window_start = 0
        else:
            window_start = min(max(0, index - visible_count // 2), len(items) - visible_count)
        window = items[window_start : window_start + visible_count]

        lines = [header]
        for i, item in enumerate(window, start=window_start):
            marker = ">" if i == index else " "
            lines.append(f"{marker} {item}")
        return lines
