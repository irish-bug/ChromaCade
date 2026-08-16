# Feature Spec — Toddler Synth

## Normal play mode
- Polyphonic: any combination of the 7 note buttons can be held simultaneously (direct GPIO wiring, no matrix/ghosting)
- Flat/natural/sharp switch and octave encoder apply globally to whatever's currently held — not per-note
- Pitch-bend joystick modifies the pitch of all held notes live, snaps back to zero on release
- Font/voice encoder cycles through available timbres/voices (wraps around)
- LED ring shows a unified color reflecting the current note's base hue (shifted for accidental) — see Color System below for the harder design problem here
- OLED shows live status: note+accidental (large), font name, base frequency + signed bend offset in Hz, volume % — see control-layout.md for exact format
- Software volume ceiling: even at max pot position, output should never exceed a level appropriate for a small room. This is a deliberate ceiling independent of the physical pot's range.

## Note range
Confirmed via live speaker test 2026-08-15 (a `fluidsynth_test.py`-style sweep, GM Acoustic Grand Piano, through the real WM8960/speaker hardware, not a simulation): **8 full octaves, C0 through C8 (MIDI 12–108), all sound acceptable** — audible, in-tune, and musically usable across the whole span. Below C0, quality drops noticeably (still audible, described as sounding "tired" — likely the speaker's bass limit and/or the ear's low-frequency sensitivity dropping off, not a hard cutoff). Didn't test above C8; the top octave (C7–C8) held up clean, just a bit quieter at the very top.

Octave numbering follows standard scientific pitch notation/MIDI convention — the octave number increments at C, not A. So the 7 letter buttons should be grouped **C, D, E, F, G, A, B per octave** for octave-equivalence teaching to match real music theory, not alphabetical A–G. Firmware/mapping decision only — the physical keycaps are color-coded (Elacgap rainbow set), not letter-printed, so this implies no hardware change.

**Per-instrument range/loudness varies, and that's fine — not a bug to engineer around.** Spot-checked 2026-08-15 with Tubular Bells and Acoustic Bass (GM 14/32) at the four range extremes (C0, C1, C7, C8): Tubular Bells held up clearly at all four, Acoustic Bass was inaudible at all four despite playing fine (if quieter than piano) at middle C. GM soundfont patches aren't loudness-normalized against each other — bass patches are conventionally mixed quieter to begin with, and that lower baseline drops below audible right where the "gets weaker at extreme registers" effect (see above) already eats into headroom piano had to spare. **Decided: no exhaustive per-instrument range testing needed.** A bass guitar realistically doesn't play a G7, a bell realistically doesn't have an F0 fundamental — an instrument voice having a narrower natural/comfortable range than the full C0–C8 is authentic to that instrument, not a defect, and arguably teaches something real (different instruments have different natural ranges) rather than something to hide. The 8-octave finding above is a system-level capability ceiling (confirmed instrument-agnostically via piano), not a promise every voice sounds equally full across all of it.

**Still wanted, separately: per-instrument loudness normalization within each voice's own comfortable range.** Not testing every instrument's outer range limits doesn't mean ignoring the loudness gap entirely — switching fonts mid-play (e.g. Piano → Acoustic Bass at the same held note) shouldn't produce a jarring volume jump just because GM patches aren't mixed to a common level. Needs a per-instrument gain/velocity table (or similar normalization step) in the eventual audio engine — not designed yet, just confirmed necessary by tonight's bells-vs-bass gap.

**Headroom requirement, not yet built:** the flat/sharp rocker and the joystick's continuous pitch-bend both need somewhere valid to land past the edges of whatever octave is currently selected — C + flat needs the previous octave's B, B + sharp needs the next octave's C, and pitch-bend needs continuous room beyond either extreme note. So the firmware's actual playable MIDI range needs a semitone-plus-bend-margin of headroom beyond both ends of the *selectable* range (C0–C8), not a hard stop at MIDI 12/108. Real headroom exists below C0 (down to MIDI 0/C-1, untested, but octave 0 was already confirmed acceptable-if-duller, so a little further down should be fine as brief bend/flat margin, not a home octave). Exact bend semitone budget still undecided — see `open-questions.md`.

## Color system (the harder design problem)
Each of the 7 letters gets a fixed base hue. Sharp shifts that hue warmer; flat shifts it cooler; octave maps to brightness, not hue. Straightforward for single notes. The open problem is chords:

**Goal:** when multiple notes are held (a chord), the LED ring should blend into a genuinely pleasant "color chord" — not a muddy/gray average.

**The constraint driving this:** blending colors from opposite sides of the hue wheel (true complementary hues) tends to average toward gray/brown, not a vivid new color. Blending hues that are close together (analogous colors) produces clean, vivid intermediate colors.

**Implication:** rather than spacing the 7 letters evenly across the full 360° hue wheel (true rainbow order), compress them into a narrower arc (a candidate range discussed: ~180–250°) so that even wide common chords (root/third/fifth triads) still land close enough together on the wheel to blend well.

**To-do before committing:** write a small script that computes the blended color for common triads (major/minor, root position) against candidate hue-assignment schemes, and actually look at the results before locking in the mapping. Treat this as testable/iterable, not a guess.

**Also open:** what should the ring show when a chord is held — average/blend of all held notes' hues, most-recently-pressed note's hue, or some priority order (lowest/highest note)? Needs a decision once the blend-quality prototyping above is done.

## Simon / Learn mode (song teaching feature)
Two distinct sub-modes, both worth building eventually:

- **Tutor / follow-along mode:** the device lights the LED ring in the color of the next note in a song, and *waits* for the child to press the matching button before advancing. No memorization required — encouraging rather than testing. This is the primary mode for a toddler.
- **Simon Says / memory mode — implemented 2026-08-15, see `chromacade.py`/`simon_sequences.py`.** Classic escalating-sequence memory game — plays a growing sequence, child must reproduce it from memory, a wrong press resets to round 1 (unlike Tutor's no-penalty design — Simon is meant to test, not just teach). Three selectable sequence sources: a fully random sequence (classic Simon, never ends), a famous number's digits mapped to letters mod 7 (Pi/e/Golden Ratio bundled, e.g. pi's "3.14159" → F D G D A E), or one of the Tutor songs' real note sequences revealed incrementally. Number/song sources are finite — reaching the end triggers the same celebration as finishing a Tutor song. Not live-tested with real button presses as of this entry — see `chromacade.py`'s module docstring for what's guessed vs. verified.

**Candidate song library** — tiered by difficulty, expanded 2026-08-15 (see `open-questions.md` for the accidental-mechanic question below):

*Tier 1, all-natural notes (no accidentals), primary Tutor-mode target:*
- Hot Cross Buns — E D C \| E D C \| C C C C \| D D D D \| E D C (simplest possible, only 3 notes)
- Mary Had a Little Lamb — E D C D \| E E E \| D D D \| E G G \| E D C D \| E E E E \| D D E D \| C
- Twinkle Twinkle Little Star — C C G G \| A A G \| F F E E \| D D C \| G G F F \| E E D \| G G F F \| E E D \| C C G G \| A A G \| F F E E \| D D C
- Ode to Joy — E E F G \| G F E D \| C C D E \| E D D \| E E F G \| G F E D \| C C D E \| D C
- Row, Row, Row Your Boat — C C C D E \| E D E F G \| C' C' C' G G G E E E C C C \| G F E D C
- Frère Jacques (Are You Sleeping) — C D E C \| C D E C \| E F G \| E F G \| G A G F E C \| G A G F E C \| C G C \| C G C
- Three Blind Mice, London Bridge Is Falling Down, Old MacDonald Had a Farm, This Old Man — confirmed as natural-note nursery songs, note-for-note sequence not independently verified here; check against sheet music/a reference recording before hardcoding into `audio/play_melody.py`.

Worth surfacing in-app: Twinkle Twinkle, Baa Baa Black Sheep, and the Alphabet Song are the exact same melody — a "same notes, different words" moment reinforces the octave/note-identity teaching goal, not just trivia.

*Tier 2, still all-natural but wider range/bigger leaps — a difficulty step before accidentals:* Happy Birthday (octave leap on "dear ___", doubles as octave-equivalence reinforcement), Yankee Doodle, Amazing Grace (pentatonic, wide leaps).

*Tier 3, needs exactly one accidental — first candidate for whichever accidental mechanic gets decided in `open-questions.md`:* Für Elise's opening motif (Beethoven) — `E D# E D# E B D C A`. Unusually good fit: the whole hook is a half-step wobble between D and D#, which demonstrates what a sharp modifies rather than just naming it as a switch position.

**Wrong-press behavior:** leaning toward "gently don't advance, keep the current note's cue lit" for the tutor mode (toddler-friendly, non-punitive). Simon mode would more traditionally reset/game-over on a wrong press, since that's the point of a memory game.

**OLED role during the mode:** likely song title + current note being asked for + a progress indicator (e.g. "3 of 7") — not finalized.

**Interior case backlighting (planned):** unit #1's translucent PLA shell plus a planned interior NeoPixel strip (see `decision-log.md`, `hardware-bom.md`) opens up a second lighting channel beyond the ring's unified note-color — e.g. a whole-case glow/pulse for correct-sequence celebration in Simon mode, or a progress-style fill during Tutor mode, distinct from the ring's per-note color cue. Exact behavior not designed yet — see `open-questions.md`.

See control-layout.md for the menu entry/exit/navigation interaction grammar (font-encoder-hold + A/G long-press combo).

## Not in scope (by design)
- Per-note accidentals within a chord (the global switch is a deliberate simplification)
- Scales, modes, tempo, sequencing beyond the song-tutor feature
- True stereo imaging (both amps get the same mono signal, just for volume/coverage, not panning)
