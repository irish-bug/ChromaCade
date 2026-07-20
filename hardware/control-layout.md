# Control Layout — Toddler Synth

## Physical zones

**Main angled panel (45°):**
- 7 note buttons (MX switches, rainbow keycaps), left to right = low to high, letter names A–G
- OLED display (note name, font, frequency+bend, volume)
- WS2812 LED ring, mounted next to the OLED

**Shelf (flat, slight forward tilt, between front wall and angled panel):**
- **Far left:** octave encoder (EC11, detented, wraps 1→2→3→4→1) + flat/natural/sharp rocker switch (3-way, ON-OFF-ON), positioned together as the left-hand "setup" cluster
- **Far right:** font/voice encoder (EC11, detented, wraps through voice list) + pitch-bend joystick (KY-023, spring-centered, one axis), positioned together as the right-hand "live shaping" cluster

**Side panel:**
- Volume pot (Fender 500K) — deliberately less convenient than shelf/panel controls

**Front wall:**
- Two speaker grilles (small hex hole pattern, sized to keep toddler fingers out)

**Back wall:**
- USB-C charging port — out of reach during normal play
- Power switch (miniature snap-in rocker, 19.2×12.7mm panel cutout) — moved here from the side panel; same deliberate-friction reasoning, and grouping it with the charging port keeps both "parent-only" power-path controls out of reach during play

## Normal play behavior
- Direct GPIO wiring (no button matrix) — full chord support, no ghosting, any combination of the 7 note buttons can be held simultaneously
- Flat/natural/sharp switch is **global** — applies to all currently-held notes uniformly. A chord can be all-natural or all-modified, never mixed (e.g. no C–E–G♯ chords). This is an accepted, deliberate simplification (see design-philosophy.md).
- Octave applies globally too, via the octave encoder — not per-note
- Pitch-bend joystick affects all currently-held notes' pitch together, live, while held; snaps back to zero on release (spring-centered)
- LED ring shows a **unified color** for the whole ring (not per-note-position) — reflects the currently-played note's base hue, shifted warmer for sharp / cooler for flat. Chord color-blending behavior is an open question — see open-questions.md.
- OLED shows four lines, live-updating: note+accidental (large), font name, base frequency + signed pitch-bend offset in Hz (shown separately, not summed — e.g. "440 Hz +22 Hz" — to reinforce that bend modifies rather than replaces the note), volume percentage

## Menu / mode interaction grammar
Designed to survive toddler mashing — every menu action requires a two-handed modifier combo, since a plain long-press on a note button is not a safe gesture (toddlers routinely hold single notes just to sustain the sound).

- **Enter mode menu:** hold the font encoder's push-button **and** long-press the G note button (~1.5s)
- **Exit menu / back out (including exiting Simon/Learn mode entirely):** hold the font encoder's push-button **and** long-press the A note button (~1.5s)
- **Cycle through menu options:** turn the font encoder (after releasing its push-button)
- **Select a highlighted option:** short click of the font encoder's push-button

A and G were chosen as the modifier-combo notes because they're the bookend letters (lowest and highest) — the two edges of the button row, easy to locate without looking.

**Note on implementation:** the font encoder's push-button is now overloaded across three contexts — held-as-modifier (menu entry/exit), short-click (menu selection), and (previously) unused during normal play. Firmware needs a small state machine to disambiguate "held while another button is also down" from "quick click" unambiguously.

**Open questions on menu behavior** (see open-questions.md for full list): whether A/G still play notes while a menu is active (leaning toward no — menu takes over input entirely), what visual feedback signals menu entry/exit (ring pulse? OLED switch?), and whether the menu structure is nested (mode, then song) or a flat list.
