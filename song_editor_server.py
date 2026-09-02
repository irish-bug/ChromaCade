#!/usr/bin/env python3
"""
ChromaCade -- backend for the web-based song composer (Add Your Own
Song page, web/add-your-own-song.html), requested 2026-08-27/28.

Phase 1 of that feature: this module only handles turning a composed
note list into a real user-songs/ file -- POST /api/songs, save, done.
It deliberately does NOT touch chromacade.py, the device, or any audio
hardware; composing (typing/drag-and-drop) and saving both work over
plain HTTP with no device present, which is the whole point of
building this piece first while offline/traveling. Two later phases,
NOT built here (see docs/open-questions.md's "record your own song"
entry once this replaces it):
  - Previewing a composed song by actually playing it through
    chromacade.py's real audio/LED hardware.
  - Using the physical device as a live input peripheral (its note
    buttons/rocker/octave encoder streaming into this same composer),
    an alternative to typing/dragging, not a replacement for it.
Both of those need chromacade.py changes and a real device to verify
against, unlike this file.

Standard library only, no Flask/etc. -- this is one JSON POST
endpoint, not enough surface to justify a framework, and keeps this
consistent with the rest of the project's minimal-dependency stack
(see docs/device-rebuild-guide.md's package list, which doesn't
mention a web framework anywhere).

Binds 127.0.0.1 only -- Caddy (running on the same device, see
web/Caddyfile) reverse-proxies /api/* to this from the outside, this
process itself is never meant to be reachable directly. Browser
requests are same-origin (Caddy serves both the static page and the
proxied API under one origin), so no CORS handling is needed.

Save semantics: refuses to overwrite an existing user-songs/ file
(409) rather than silently replacing it the way tutor_songs.py's
load_user_songs() does for a NAME collision on import -- that "later
one silently wins" behavior is fine for a single developer hand-
placing files, but a parent typing a name into a web form deserves a
clear "that name's taken" instead of quietly losing a previous
recording. Editing/overwriting an existing song on purpose isn't
built yet -- out of scope for this first pass, easy to add a real
"overwrite?" confirmation later without changing this endpoint's
shape.
"""

import json
import re
import unicodedata
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from tutor_songs import USER_SONGS_DIR, parse_note_name

HOST = "127.0.0.1"
PORT = 8765

MAX_NAME_LENGTH = 60
MAX_SCORE_LENGTH = 500  # generous -- longest bundled song is nowhere close


def slugify(name):
    """'My Song!' -> 'my-song' -- filesystem-safe stem for the
    user-songs/<slug>.py file. NFKD-normalizes first so accented
    characters degrade to their closest ASCII letter (e.g. 'é' -> 'e')
    instead of being dropped outright, then strips anything left that
    isn't alphanumeric/space/hyphen, collapses whitespace to single
    hyphens, and lowercases. Raises ValueError on a name that has
    nothing left after that (e.g. all-emoji or all-punctuation) rather
    than silently producing an empty/meaningless filename."""
    normalized = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
    cleaned = re.sub(r"[^a-zA-Z0-9\s-]", "", normalized).strip()
    slug = re.sub(r"[\s-]+", "-", cleaned).lower()
    if not slug:
        raise ValueError(f"Name {name!r} has no usable characters for a filename")
    return slug


def validate_score(score):
    """Checks a composed note list is well-formed before it's ever
    written to disk: a non-empty list of [note_name_or_None, duration]
    pairs, each note_name parseable by tutor_songs.py's own
    parse_note_name() (so a bad note can never reach SCORE and break
    Tutor/Simon later), each duration a positive number. Raises
    ValueError with a specific, position-referencing message on the
    first problem found -- returns the score unchanged (as a list of
    tuples, matching SCORE's own type) if it's clean."""
    if not isinstance(score, list) or not score:
        raise ValueError("score must be a non-empty list")
    if len(score) > MAX_SCORE_LENGTH:
        raise ValueError(f"score has {len(score)} notes, over the {MAX_SCORE_LENGTH} limit")
    cleaned = []
    for i, entry in enumerate(score):
        if not isinstance(entry, (list, tuple)) or len(entry) != 2:
            raise ValueError(f"score[{i}] must be a [note_name, duration] pair, got {entry!r}")
        note_name, duration = entry
        if note_name is not None:
            if not isinstance(note_name, str):
                raise ValueError(f"score[{i}]: note_name must be a string or null, got {note_name!r}")
            parse_note_name(note_name)  # raises its own ValueError on a bad name
        if not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0:
            raise ValueError(f"score[{i}]: duration must be a positive number, got {duration!r}")
        cleaned.append((note_name, duration))
    return cleaned


def render_user_song_file(name, score):
    """Builds the exact .py file content user-songs/README.md
    documents -- NAME (str) and SCORE (list of (note_name, duration)
    tuples). repr() on each piece rather than manual string-building,
    so quoting/escaping in the name or any note name is always valid
    Python, not just valid for the specific characters tested by
    hand."""
    lines = [f"NAME = {name!r}", "", "SCORE = ["]
    for note_name, duration in score:
        lines.append(f"    ({note_name!r}, {duration!r}),")
    lines.append("]")
    lines.append("")
    return "\n".join(lines)


def save_user_song(name, score, directory=USER_SONGS_DIR):
    """Validates, renders, and writes a new user-songs/ file. Returns
    the path written. Raises ValueError (bad input -- caller maps this
    to 400) or FileExistsError (name collision -- caller maps this to
    409); doesn't catch either itself, so callers decide how to report
    them rather than this function guessing at HTTP semantics."""
    name = name.strip() if isinstance(name, str) else ""
    if not name:
        raise ValueError("name must be a non-empty string")
    if len(name) > MAX_NAME_LENGTH:
        raise ValueError(f"name is {len(name)} characters, over the {MAX_NAME_LENGTH} limit")
    cleaned_score = validate_score(score)
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{slugify(name)}.py"
    if path.exists():
        raise FileExistsError(f"A song already saved at {path.name} -- pick a different name")
    path.write_text(render_user_song_file(name, cleaned_score))
    return path


class _Handler(BaseHTTPRequestHandler):
    def _send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path != "/api/songs":
            self._send_json(404, {"ok": False, "error": "not found"})
            return
        length = int(self.headers.get("Content-Length", 0))
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
            path = save_user_song(payload.get("name"), payload.get("score"))
        except ValueError as e:
            self._send_json(400, {"ok": False, "error": str(e)})
        except FileExistsError as e:
            self._send_json(409, {"ok": False, "error": str(e)})
        except json.JSONDecodeError:
            self._send_json(400, {"ok": False, "error": "body must be JSON"})
        else:
            self._send_json(200, {"ok": True, "file": path.name})

    def log_message(self, format, *args):
        # Default logs to stderr with no prefix -- journald already
        # timestamps/tags every line by unit, this just avoids doubling
        # up on that.
        print(f"song_editor_server: {format % args}")


def main():
    server = ThreadingHTTPServer((HOST, PORT), _Handler)
    print(f"song_editor_server listening on {HOST}:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
