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

Power Off / Reboot -- added 2026-08-16, requested to give a proper
software shutdown option instead of only the physical power switch.
Deliberately NOT a single click from the mode list: selecting either
drops into a "confirm" stage (Yes/No, defaulting to No) before
anything actually happens. A toddler idly wandering through the menu
and clicking through it would land on "No" and cancel, not execute --
a second, deliberate rotate-then-click is required to actually power
off or reboot. Same "hold/confirm on purpose" spirit as the menu
gesture itself being two-handed, just implemented as an extra menu
step here instead of a hardware hold, since this reuses the existing
rotate/select machinery rather than adding new hold-duration
detection to hardware_poller.py.
"""

MODES = ["Explore", "Tutor", "Simon", "Power Off", "Reboot"]
CONFIRM_OPTIONS = ["No", "Yes"]  # "No" first/default -- see module docstring
SYSTEM_ACTIONS = {"Power Off": "poweroff", "Reboot": "reboot"}


def _grouped_with_headers(items, in_advanced_group, notes_header, advanced_header):
    """Splits `items` into two groups by in_advanced_group(item), and
    interleaves two non-selectable header entries -- but only if BOTH
    groups are non-empty. If everything (or nothing) is in the
    advanced group, there's nothing to usefully separate, so this
    returns a plain flat list instead -- no header clutter for a
    Tutor song list that doesn't have any chord songs yet, which is
    the common case until someone actually composes one.

    Returns a list of (display_text, item_or_None) pairs -- None marks
    a header, never selectable (see Menu.rotate()'s "song" stage,
    which skips over these so its index can never land on one)."""
    plain = [item for item in items if not in_advanced_group(item)]
    advanced = [item for item in items if in_advanced_group(item)]
    if not plain or not advanced:
        return [(item, item) for item in items]
    entries = [(notes_header, None)]
    entries += [(item, item) for item in plain]
    entries.append((advanced_header, None))
    entries += [(item, item) for item in advanced]
    return entries


def _first_selectable(display):
    for i, (_text, item) in enumerate(display):
        if item is not None:
            return i
    raise ValueError("display has no selectable items")  # unreachable given Menu's own non-empty check


class Menu:
    def __init__(self, songs, simon_sources, chord_songs=frozenset()):
        """chord_songs: names (a subset of `songs`) that should be
        grouped under a "-- Chord songs --" header, separate from
        everything else under "-- Notes only --" -- added 2026-09-02,
        direct instruction, so a song needing multiple buttons held
        together reads as visually distinct from an ordinary one
        before a child/parent picks it. Optional and defaults to
        empty so every existing caller (and every existing test) keeps
        working unchanged -- an empty/all set collapses to the same
        flat list Menu has always shown, see _grouped_with_headers()."""
        if not songs:
            raise ValueError("songs must be non-empty")
        if not simon_sources:
            raise ValueError("simon_sources must be non-empty")
        self.songs = list(songs)
        self.simon_sources = list(simon_sources)
        self._song_display = _grouped_with_headers(
            self.songs, lambda s: s in chord_songs, "-- Notes only --", "-- Chord songs --"
        )
        self.active = False
        self.stage = "mode"  # "mode" | "song" | "simon" | "confirm"
        self.mode_index = 0
        self.song_index = _first_selectable(self._song_display)
        self.simon_index = 0
        self.confirm_index = 0
        self.confirm_label = None
        self.confirm_action = None

    def enter(self):
        """Always resets to the top of the menu (mode-select stage) --
        so a fresh entry never leaves the child stuck deep in a song
        list (or mid-way through a Power Off/Reboot confirmation) left
        over from a previous visit."""
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
        return self._song_display[self.song_index][1]

    @property
    def highlighted_simon_source(self):
        return self.simon_sources[self.simon_index]

    @property
    def highlighted_confirm_option(self):
        return CONFIRM_OPTIONS[self.confirm_index]

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
            # One step at a time (not a single modulo jump by delta),
            # each step skipping over any non-selectable header entry
            # (see _grouped_with_headers()) -- so song_index can never
            # land on one, however many steps a single rotate() covers.
            n = len(self._song_display)
            step = 1 if delta >= 0 else -1
            index = self.song_index
            for _ in range(abs(delta)):
                index = (index + step) % n
                while self._song_display[index][1] is None:
                    index = (index + step) % n
            self.song_index = index
        elif self.stage == "simon":
            self.simon_index = (self.simon_index + delta) % len(self.simon_sources)
        else:
            self.confirm_index = (self.confirm_index + delta) % len(CONFIRM_OPTIONS)

    def select(self):
        """Confirms the highlighted option (font button short-click).
        Returns None if still navigating, or a result tuple describing
        what to do: ("play",), ("tutor", song_name),
        ("simon", source_name), or ("system", "poweroff"|"reboot").
        Caller is responsible for actually acting on the result and
        calling exit() -- this class doesn't know about audio/tutor/
        simon sessions/subprocess calls/etc."""
        if not self.active:
            return None
        if self.stage == "mode":
            mode = self.highlighted_mode
            if mode == "Explore":
                return ("play",)  # internal result identifier unchanged, only the display name is "Explore" now
            if mode == "Tutor":
                self.stage = "song"
                self.song_index = _first_selectable(self._song_display)
                return None
            if mode == "Simon":
                self.stage = "simon"
                self.simon_index = 0
                return None
            # "Power Off" / "Reboot" -- see module docstring for why
            # this goes to a confirm stage instead of acting immediately.
            self.confirm_label = mode
            self.confirm_action = SYSTEM_ACTIONS[mode]
            self.confirm_index = 0
            self.stage = "confirm"
            return None
        if self.stage == "song":
            return ("tutor", self.highlighted_song)
        if self.stage == "simon":
            return ("simon", self.highlighted_simon_source)
        # "confirm"
        if self.highlighted_confirm_option == "Yes":
            return ("system", self.confirm_action)
        self.stage = "mode"
        return None

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
            # Display text, not self.songs directly -- includes the
            # "-- Notes only --"/"-- Chord songs --" header lines when
            # there's a real split to show (see _grouped_with_headers()).
            song_display_texts = [text for text, _item in self._song_display]
            header, items, index = "Select song:", song_display_texts, self.song_index
        elif self.stage == "simon":
            header, items, index = "Select sequence:", self.simon_sources, self.simon_index
        else:
            header, items, index = f"{self.confirm_label}?", CONFIRM_OPTIONS, self.confirm_index

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
