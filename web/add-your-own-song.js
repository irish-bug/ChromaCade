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

function noteName(note) {
  if (note.letter === null) return null;
  return `${note.letter}${ACCIDENTAL_WIRE[String(note.accidental)]}${note.octave}`;
}

function toScore() {
  return notes.map((n) => [noteName(n), n.duration]);
}

function clampOctave(o) {
  return Math.min(MAX_OCTAVE, Math.max(MIN_OCTAVE, o));
}

function makeNote(letter, overridePen) {
  const p = overridePen || pen;
  if (letter === null || letter === "") {
    return { letter: null, octave: null, accidental: 0, duration: p.duration };
  }
  return { letter, octave: p.octave, accidental: p.accidental, duration: p.duration };
}

function insertNote(index, letter) {
  notes.splice(index, 0, makeNote(letter));
  selectedIndex = null;
  render();
}

function appendNote(letter) {
  insertNote(notes.length, letter);
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
  render();
}

// --- Position math: notes are laid out left-to-right by cumulative
// beat position, independent of which lane (letter) each lands in --
// this is what makes drag-drop-at-an-x-position and the piano-roll-
// style width-by-duration both work using one shared coordinate
// system across all 8 lanes.
function beatOffsets() {
  const offsets = [];
  let cursor = 0;
  for (const note of notes) {
    offsets.push(cursor);
    cursor += note.duration;
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
  notes.forEach((note, i) => {
    const token = document.createElement("div");
    token.className =
      "note-token" + (note.letter === null ? " rest-token" : "") + (i === selectedIndex ? " selected" : "");
    token.style.left = `${offsets[i] * PX_PER_BEAT}px`;
    token.style.width = `${Math.max(note.duration * PX_PER_BEAT - 4, 22)}px`;
    if (note.letter !== null) {
      token.style.background = `var(--${note.letter.toLowerCase()})`;
      token.textContent = `${ACCIDENTAL_SYMBOL[String(note.accidental)]}${note.letter}${note.octave}`;
    } else {
      token.textContent = "rest";
    }
    token.title = `Note ${i + 1} of ${notes.length} -- click to edit`;
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
  insertNote(indexAtX(e.offsetX), letter === "" ? null : letter);
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
    appendNote(letter);
  }
});

document.querySelectorAll(".palette button").forEach((btn) => {
  btn.addEventListener("click", () => appendNote(btn.dataset.letter === "" ? null : btn.dataset.letter));
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
  notes[selectedIndex].duration = v > 0 ? v : notes[selectedIndex].duration;
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
