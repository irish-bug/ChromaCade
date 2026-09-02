"use strict";

/* ChromaCade -- Add Your Own Song composer, phase 1 (typing/click/
 * drag-and-drop entry + save). See song_editor_server.py's docstring
 * for the phases NOT built here (device-as-peripheral input, preview
 * through the real instrument) -- this file only ever produces a
 * `score` array and POSTs it to /api/songs; it never plays sound or
 * talks to the device.
 *
 * Internal note shape: {letter: "C".."B" or null (rest), octave,
 * accidental (-1/0/1), duration (beats)}. octave/accidental are
 * meaningless (and unused) on a rest, kept only so the shape is
 * uniform. Converted to the wire format ([note_name_or_null,
 * duration] pairs, matching tutor_songs.py's SCORE exactly) only at
 * save time, via noteName()/toScore() below.
 */

const LETTERS = ["C", "D", "E", "F", "G", "A", "B"];
// Lane display order top-to-bottom: high to low, pitch-increases-upward
// like real staff notation, Rest lane last (lowest) since it isn't a
// pitch at all.
const LANE_ORDER = ["B", "A", "G", "F", "E", "D", "C", ""];
// Two different symbol sets on purpose: ACCIDENTAL_SYMBOL is what's
// shown on screen (proper flat/sharp glyphs, easier to read at a
// glance); ACCIDENTAL_WIRE is what actually goes into the note name
// sent to the backend, which must match tutor_songs.py's
// parse_note_name() regex exactly (plain ASCII "#"/"b") -- confirmed
// live that the unicode glyphs make parse_note_name() raise, this
// isn't just theoretical.
const ACCIDENTAL_SYMBOL = { "-1": "♭", "0": "", "1": "♯" };
const ACCIDENTAL_WIRE = { "-1": "b", "0": "", "1": "#" };
const MIN_OCTAVE = 0;
const MAX_OCTAVE = 8; // matches the real instrument's C0-C8 range, see index.html
const PX_PER_BEAT = 48;

let notes = [];
let pen = { octave: 4, accidental: 0, duration: 1 };
let selectedIndex = null;

// --- Chords, added 2026-09-02 -- see song_editor_server.py's
// validate_score() for the wire format this exports to: a chord is
// [[name1, name2, ...], duration], 2-7 notes at distinct letters
// (ChromaCadeAudio can only hold one instance of each of the 7
// letters sounding at once, hence the 7 cap). A note's chordId links
// it to the other members of its chord (null for an ordinary note);
// members are always kept contiguous in `notes` so beatOffsets()/
// toScore() can group them by a simple adjacency scan rather than
// needing a separate index structure.
const MAX_CHORD_SIZE = 7;
let chordMode = false;
let activeChordId = null;
let nextChordId = 1;

function noteName(note) {
  if (note.letter === null) return null;
  return `${note.letter}${ACCIDENTAL_WIRE[String(note.accidental)]}${note.octave}`;
}

// Runs `notes` as a sequence of groups -- a lone ordinary note is its
// own group of size 1, a chord is every contiguous note sharing the
// same non-null chordId. Shared by beatOffsets() (where each group
// occupies one beat position) and toScore() (where each group becomes
// one score entry) so the two can never disagree about grouping.
function noteGroups() {
  const groups = [];
  let i = 0;
  while (i < notes.length) {
    const id = notes[i].chordId;
    let j = i + 1;
    if (id !== null) {
      while (j < notes.length && notes[j].chordId === id) j++;
    }
    groups.push(notes.slice(i, j));
    i = j;
  }
  return groups;
}

function toScore() {
  return noteGroups().map((group) => {
    if (group.length > 1) {
      return [group.map(noteName), group[0].duration];
    }
    return [noteName(group[0]), group[0].duration];
  });
}

function clampOctave(o) {
  return Math.min(MAX_OCTAVE, Math.max(MIN_OCTAVE, o));
}

function makeNote(letter, overridePen) {
  const p = overridePen || pen;
  if (letter === null || letter === "") {
    return { letter: null, octave: null, accidental: 0, duration: p.duration, chordId: null };
  }
  return { letter, octave: p.octave, accidental: p.accidental, duration: p.duration, chordId: null };
}

function insertNote(index, letter) {
  notes.splice(index, 0, makeNote(letter));
  selectedIndex = null;
  render();
}

function appendNote(letter) {
  insertNote(notes.length, letter);
}

// Chord-aware placement -- routes every letter-placement path (palette
// click, keyboard typing, drag-drop) through here so "Build chord"
// behaves the same regardless of how a note gets added. A rest, or
// chord mode being off, always behaves exactly like appendNote() did
// before chords existed (and ends whatever chord was in progress -- a
// rest can't be part of a chord, it's silence, not a simultaneous
// note). While chord mode is on, each letter stacks onto the active
// chord group (started fresh on the first letter after toggling on)
// instead of advancing to a new beat position -- a letter already in
// the active chord is silently ignored rather than producing an
// invalid duplicate-letter chord (see song_editor_server.py's
// validate_score(), which rejects that).
function placeLetter(letter) {
  if (!chordMode || letter === null) {
    activeChordId = null;
    appendNote(letter);
    return;
  }
  if (activeChordId === null) {
    const note = makeNote(letter);
    note.chordId = nextChordId++;
    activeChordId = note.chordId;
    notes.push(note);
    selectedIndex = null;
    render();
    return;
  }
  const group = notes.filter((n) => n.chordId === activeChordId);
  if (group.length >= MAX_CHORD_SIZE) return; // ChromaCadeAudio can't hold more than 7 letters at once
  if (group.some((n) => n.letter === letter)) return; // already in this chord
  let insertAt = notes.length;
  for (let i = notes.length - 1; i >= 0; i--) {
    if (notes[i].chordId === activeChordId) {
      insertAt = i + 1;
      break;
    }
  }
  const note = makeNote(letter);
  note.chordId = activeChordId;
  notes.splice(insertAt, 0, note);
  selectedIndex = null;
  render();
}

function setChordMode(on) {
  chordMode = on;
  activeChordId = null; // toggling either way ends whatever chord was in progress
  const btn = document.getElementById("chord-btn");
  btn.setAttribute("aria-pressed", String(chordMode));
  btn.textContent = chordMode ? "Building chord… (click to finish)" : "Build chord";
  document.getElementById("chord-hint").style.display = chordMode ? "block" : "none";
}

function undoLast() {
  if (notes.length === 0) return;
  notes.pop();
  if (selectedIndex !== null && selectedIndex >= notes.length) selectedIndex = null;
  render();
}

// "Clear all" needs a confirm step -- it's destructive and easy to
// misclick right next to Undo -- but NOT window.confirm(): that's a
// native browser dialog, and this page also runs inside a sandboxed
// Artifact preview (see the "ChromaCade Composer" artifact) where
// sandboxed iframes silently block confirm()/alert()/prompt() unless
// allow-modals is set, returning false with no dialog ever shown at
// all -- confirmed live, this was reported as "the button doesn't
// work" because of exactly that. An in-page two-click arm/confirm
// instead: first click arms it (button relabels, clearArmed=true,
// times out back to normal after CLEAR_ARM_TIMEOUT_MS if not
// followed up), second click within that window actually clears. No
// native dialog anywhere, works identically in a sandboxed preview
// and the real page.
let clearArmed = false;
let clearArmTimer = null;
const CLEAR_ARM_TIMEOUT_MS = 3000;

function disarmClear() {
  clearArmed = false;
  if (clearArmTimer) {
    clearTimeout(clearArmTimer);
    clearArmTimer = null;
  }
  const btn = document.getElementById("clear-btn");
  btn.textContent = "Clear all";
  btn.classList.remove("armed");
}

function clearAll() {
  if (notes.length === 0) return;
  if (!clearArmed) {
    clearArmed = true;
    const btn = document.getElementById("clear-btn");
    btn.textContent = "Click again to clear";
    btn.classList.add("armed");
    clearArmTimer = setTimeout(disarmClear, CLEAR_ARM_TIMEOUT_MS);
    return;
  }
  disarmClear();
  notes = [];
  selectedIndex = null;
  if (chordMode) setChordMode(false);
  render();
}

// --- Position math: notes are laid out left-to-right by cumulative
// beat position, independent of which lane (letter) each lands in --
// this is what makes drag-drop-at-an-x-position and the piano-roll-
// style width-by-duration both work using one shared coordinate
// system across all 8 lanes.
function beatOffsets() {
  // One offset per note in `notes` (same order/length as that array,
  // so renderStaff()'s notes.forEach((note, i) => ...) can still index
  // straight into it) -- but every member of a chord group gets the
  // SAME offset, and the cursor only advances once per group (by the
  // group's own shared duration), not once per note.
  const offsets = [];
  let cursor = 0;
  for (const group of noteGroups()) {
    for (const _note of group) offsets.push(cursor);
    cursor += group[0].duration;
  }
  return { offsets, total: cursor };
}

function indexAtX(x) {
  const { offsets } = beatOffsets();
  for (let i = 0; i < notes.length; i++) {
    const start = offsets[i] * PX_PER_BEAT;
    const end = start + notes[i].duration * PX_PER_BEAT;
    if (x < (start + end) / 2) return i;
  }
  return notes.length;
}

// --- Rendering ---
function render() {
  renderStaff();
  renderPenControls();
  renderEditor();
  renderToolbar();
}

function renderStaff() {
  const staffEl = document.getElementById("staff");
  staffEl.innerHTML = "";
  const tracks = {};
  for (const letter of LANE_ORDER) {
    const lane = document.createElement("div");
    lane.className = "lane" + (letter === "" ? " rest-lane" : "");
    const label = document.createElement("div");
    label.className = "lane-label";
    label.textContent = letter === "" ? "rest" : letter;
    if (letter !== "") label.style.background = `var(--${letter.toLowerCase()})`;
    const track = document.createElement("div");
    track.className = "lane-track";
    track.dataset.letter = letter;
    lane.appendChild(label);
    lane.appendChild(track);
    staffEl.appendChild(lane);
    tracks[letter] = track;
    track.addEventListener("dragover", (e) => e.preventDefault());
    track.addEventListener("drop", onDrop);
  }

  const { offsets, total } = beatOffsets();
  // Map each note index to its group (a chord's members, or a lone
  // note as its own group of 1) so rendering can tell a real chord
  // (size > 1 -- gets the .chorded outline + a "part of a chord"
  // tooltip) apart from an ordinary note or a leftover 1-member
  // "chord" (e.g. after deleting the rest of its group -- toScore()
  // already treats that as a plain note, rendering should read the
  // same way).
  const groupOf = [];
  noteGroups().forEach((group) => {
    for (const note of group) groupOf.push(group);
  });
  notes.forEach((note, i) => {
    const group = groupOf[i];
    const isChorded = group.length > 1;
    const token = document.createElement("div");
    token.className =
      "note-token" +
      (note.letter === null ? " rest-token" : "") +
      (i === selectedIndex ? " selected" : "") +
      (isChorded ? " chorded" : "");
    token.style.left = `${offsets[i] * PX_PER_BEAT}px`;
    token.style.width = `${Math.max(note.duration * PX_PER_BEAT - 4, 22)}px`;
    if (note.letter !== null) {
      token.style.background = `var(--${note.letter.toLowerCase()})`;
      token.textContent = `${ACCIDENTAL_SYMBOL[String(note.accidental)]}${note.letter}${note.octave}`;
    } else {
      token.textContent = "rest";
    }
    token.title = isChorded
      ? `Part of a chord: ${group.map((n) => n.letter).join("+")} -- click to edit`
      : `Note ${i + 1} of ${notes.length} -- click to edit`;
    token.addEventListener("click", () => selectNote(i));
    tracks[note.letter === null ? "" : note.letter].appendChild(token);
  });

  const width = Math.max(total * PX_PER_BEAT + 60, 320);
  document.querySelectorAll(".lane-track").forEach((t) => {
    t.style.minWidth = `${width}px`;
  });

  document.getElementById("note-count").textContent = `${notes.length} note${notes.length === 1 ? "" : "s"}`;
}

function onDrop(e) {
  e.preventDefault();
  const letter = e.dataTransfer.getData("text/letter");
  const resolvedLetter = letter === "" ? null : letter;
  if (chordMode) {
    // Chord mode ignores drop position -- every letter stacks onto
    // the active chord's shared beat position regardless of where on
    // the staff it was dropped, same as a palette click would.
    placeLetter(resolvedLetter);
    return;
  }
  insertNote(indexAtX(e.offsetX), resolvedLetter);
}

function renderPenControls() {
  document.getElementById("octave-value").textContent = pen.octave;
  document.querySelectorAll(".pen-row [data-accidental]").forEach((btn) => {
    btn.classList.toggle("active", Number(btn.dataset.accidental) === pen.accidental);
  });
}

function renderToolbar() {
  document.getElementById("undo-btn").disabled = notes.length === 0;
  document.getElementById("clear-btn").disabled = notes.length === 0;
  // Any render (a note added/edited/undone, not just Clear itself
  // completing) disarms an in-progress "click again to clear" --
  // otherwise the button can be left showing that label while it no
  // longer reflects a real pending confirmation, e.g. if Undo empties
  // the list while Clear is armed.
  if (clearArmed) disarmClear();
  const name = document.getElementById("song-name").value.trim();
  document.getElementById("save-btn").disabled = notes.length === 0 || name === "";
}

function selectNote(i) {
  selectedIndex = i;
  render();
}

function renderEditor() {
  const panel = document.getElementById("editor-panel");
  if (selectedIndex === null) {
    panel.classList.remove("open");
    return;
  }
  const note = notes[selectedIndex];
  const isRest = note.letter === null;
  panel.classList.add("open");
  document.getElementById("editor-position").textContent = `${selectedIndex + 1} of ${notes.length}`;
  document.getElementById("editor-octave-value").textContent = isRest ? "—" : note.octave;
  document.getElementById("editor-duration").value = note.duration;
  for (const id of ["editor-octave-down", "editor-octave-up", "editor-flat", "editor-natural", "editor-sharp"]) {
    document.getElementById(id).disabled = isRest;
  }
  document.getElementById("editor-flat").classList.toggle("active", !isRest && note.accidental === -1);
  document.getElementById("editor-natural").classList.toggle("active", !isRest && note.accidental === 0);
  document.getElementById("editor-sharp").classList.toggle("active", !isRest && note.accidental === 1);
}

// --- Wiring ---
function isTypingInField() {
  const tag = document.activeElement && document.activeElement.tagName;
  return tag === "INPUT" || tag === "TEXTAREA";
}

document.addEventListener("keydown", (e) => {
  if (isTypingInField() || e.metaKey || e.ctrlKey || e.altKey) return;
  const letter = e.key.toUpperCase();
  if (LETTERS.includes(letter)) {
    e.preventDefault();
    placeLetter(letter);
  }
});

document.querySelectorAll(".palette button").forEach((btn) => {
  btn.addEventListener("click", () => placeLetter(btn.dataset.letter === "" ? null : btn.dataset.letter));
  btn.addEventListener("dragstart", (e) => {
    e.dataTransfer.setData("text/letter", btn.dataset.letter);
    e.dataTransfer.effectAllowed = "copy";
  });
});

document.getElementById("octave-down").addEventListener("click", () => {
  pen.octave = clampOctave(pen.octave - 1);
  render();
});
document.getElementById("octave-up").addEventListener("click", () => {
  pen.octave = clampOctave(pen.octave + 1);
  render();
});
document.querySelectorAll(".pen-row [data-accidental]").forEach((btn) => {
  btn.addEventListener("click", () => {
    pen.accidental = Number(btn.dataset.accidental);
    render();
  });
});
document.getElementById("duration-input").addEventListener("change", (e) => {
  const v = parseFloat(e.target.value);
  pen.duration = v > 0 ? v : 1;
  e.target.value = pen.duration;
});

document.getElementById("chord-btn").addEventListener("click", () => setChordMode(!chordMode));
document.getElementById("undo-btn").addEventListener("click", undoLast);
document.getElementById("clear-btn").addEventListener("click", clearAll);

document.getElementById("editor-octave-down").addEventListener("click", () => {
  const note = notes[selectedIndex];
  note.octave = clampOctave(note.octave - 1);
  render();
});
document.getElementById("editor-octave-up").addEventListener("click", () => {
  const note = notes[selectedIndex];
  note.octave = clampOctave(note.octave + 1);
  render();
});
document.getElementById("editor-flat").addEventListener("click", () => {
  notes[selectedIndex].accidental = -1;
  render();
});
document.getElementById("editor-natural").addEventListener("click", () => {
  notes[selectedIndex].accidental = 0;
  render();
});
document.getElementById("editor-sharp").addEventListener("click", () => {
  notes[selectedIndex].accidental = 1;
  render();
});
document.getElementById("editor-duration").addEventListener("change", (e) => {
  const v = parseFloat(e.target.value);
  const note = notes[selectedIndex];
  const newDuration = v > 0 ? v : note.duration;
  // A chord's members must share one duration -- toScore() reads only
  // the group's first member -- so editing any one member has to
  // update every sibling too, or the change would silently not apply
  // to what actually gets saved.
  if (note.chordId !== null) {
    for (const n of notes) {
      if (n.chordId === note.chordId) n.duration = newDuration;
    }
  } else {
    note.duration = newDuration;
  }
  render();
});
document.getElementById("editor-delete").addEventListener("click", () => {
  notes.splice(selectedIndex, 1);
  selectedIndex = null;
  render();
});
document.getElementById("editor-close").addEventListener("click", () => {
  selectedIndex = null;
  render();
});

document.getElementById("song-name").addEventListener("input", renderToolbar);

document.getElementById("save-btn").addEventListener("click", async () => {
  const name = document.getElementById("song-name").value.trim();
  const statusEl = document.getElementById("save-status");
  if (!name || notes.length === 0) return;
  statusEl.textContent = "Saving…";
  statusEl.className = "save-status";
  try {
    const res = await fetch("/api/songs", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, score: toScore() }),
    });
    let data;
    try {
      data = await res.json();
    } catch {
      data = { ok: false, error: `Unexpected response (HTTP ${res.status})` };
    }
    if (data.ok) {
      statusEl.textContent = `Saved! "${name}" is ready in Tutor and Simon.`;
      statusEl.className = "save-status ok";
    } else {
      statusEl.textContent = data.error || "Something went wrong.";
      statusEl.className = "save-status error";
    }
  } catch (err) {
    statusEl.textContent = "Couldn't reach the save service -- is ChromaCade online?";
    statusEl.className = "save-status error";
  }
});

render();
