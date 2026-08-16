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
Designed to survive toddler mashing — every menu action requires a multi-control combo, since a plain long-press on a note button is not a safe gesture on its own (toddlers routinely hold single notes just to sustain the sound — see "Corrected 2026-08-15" below for why that matters).

- **Enter mode menu:** hold **both** encoder push-buttons (octave encoder's and font encoder's) **and** long-press the B note button (~1.5s)
- **Exit menu / back out (including exiting an active Tutor session entirely):** hold **both** encoder push-buttons **and** long-press the C note button (~1.5s)
- **Cycle through menu options:** turn the font encoder (menu takes over that control's normal job while a menu is open)
- **Select a highlighted option:** short click of the font encoder's push-button

C and B were chosen as the modifier-combo notes because they're the bookend letters under the current **C-D-E-F-G-A-B** physical labeling (lowest and highest) — the two edges of the button row, easy to locate without looking.

**Corrected 2026-08-15 — was originally A/G + font-button-only, implemented as C/B + both-encoder-buttons:** two separate issues, fixed together.
1. This section originally said "long-press G to enter, A to exit," reasoning that they were the two edge buttons — true under the *old* alphabetical A-G labeling, but the 2026-08-15 relabel to C-D-E-F-G-A-B moved the physical edges to C and B; A and G became interior buttons. Updated the letters to match, not the underlying "edge button" reasoning.
2. The original design paired the font button alone (as a held modifier) with the note-button long-press. In practice a note-button long-press isn't a rare, deliberate signal — a toddler sustaining a single held note *is* a long-press, all day, during completely normal play. Requiring **both** encoder push-buttons (not just the font one) closes that gap: they sit at opposite ends of the shelf (far left = octave, far right = font), so holding both down is inherently two-handed and not something normal note-sustaining play does incidentally.

This also resolves the octave encoder push-button's previously-unassigned function (see hardware-bom.md/open-questions.md history): it's now one of the two required holds for this gesture, not read for anything else yet.

**Note on implementation:** the font encoder's push-button is overloaded across two contexts — held-as-modifier (menu entry/exit, alongside the octave button) and short-click (menu selection). Implemented in `hardware_poller.py` via a press/release timestamp (short click) plus `Button.when_held` on the C/B note buttons checking both encoder buttons' state at that instant — see that module's docstring for the exact approach and its known imprecision (checks a point in time, not that all three were held continuously for the full duration).

**Resolved 2026-08-15 (was open):** A/C/B/G note buttons do *not* play notes while a menu is active — the menu takes over input entirely, confirmed as implemented in `chromacade.py`. Visual feedback: the OLED switches to a menu view (mode/song list, current selection marked), and the LED ring clears while a menu is open. Menu structure is nested (mode select, then a song list within Tutor) — see `menu.py`. No song preview/snippet plays before selecting.
