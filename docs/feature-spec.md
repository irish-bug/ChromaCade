# Feature Spec — Toddler Synth

## Normal play mode
- Polyphonic: any combination of the 7 note buttons can be held simultaneously (direct GPIO wiring, no matrix/ghosting)
- Flat/natural/sharp switch and octave encoder apply globally to whatever's currently held — not per-note
- Pitch-bend joystick modifies the pitch of all held notes live, snaps back to zero on release
- Font/voice encoder cycles through available timbres/voices (wraps around)
- LED ring shows a unified color reflecting the current note's base hue (shifted for accidental) — see Color System below for the harder design problem here
- OLED shows live status: note+accidental (large), font name, base frequency + signed bend offset in Hz, volume % — see control-layout.md for exact format
- Software volume ceiling: even at max pot position, output should never exceed a level appropriate for a small room. This is a deliberate ceiling independent of the physical pot's range.

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
- **Simon Says / memory mode:** classic escalating-sequence memory game — plays a growing sequence, child must reproduce it from memory. Better suited for an older child or as the toddler grows into it. Lower priority to build first.

**Candidate song library** (simple melodies playable entirely with natural notes, no accidentals needed): Twinkle Twinkle Little Star, Hot Cross Buns, Mary Had a Little Lamb, Ode to Joy.

**Wrong-press behavior:** leaning toward "gently don't advance, keep the current note's cue lit" for the tutor mode (toddler-friendly, non-punitive). Simon mode would more traditionally reset/game-over on a wrong press, since that's the point of a memory game.

**OLED role during the mode:** likely song title + current note being asked for + a progress indicator (e.g. "3 of 7") — not finalized.

See control-layout.md for the menu entry/exit/navigation interaction grammar (font-encoder-hold + A/G long-press combo).

## Not in scope (by design)
- Per-note accidentals within a chord (the global switch is a deliberate simplification)
- Scales, modes, tempo, sequencing beyond the song-tutor feature
- True stereo imaging (both amps get the same mono signal, just for volume/coverage, not panning)
