# Open Questions — Toddler Synth

Living list of decisions not yet finalized. Move items out of this file (into the relevant spec doc) once resolved.

## Color / LED system
- **Hue arc for the 7 letters:** how wide an arc to compress ROYGBIV into so common chords blend into vivid rather than muddy colors. Candidate range discussed: ~180–250° of the wheel. Needs prototyping — write a script that computes blended colors for common triads against candidate hue assignments and visually evaluate before committing.
- **Chord color behavior:** when multiple notes are held, does the ring show a blended average of all held notes' hues, the most-recently-pressed note's hue, or a priority order (lowest/highest note wins)?
- **Physical button color vs. ring color mapping:** the sourced rainbow keycaps (Elacgap, 8 usable colors) are "distinct but not strictly ROYGBIV" — need to finalize which physical cap color maps to which letter, ideally matching the compressed hue-arc scheme once that's settled. Candidate hex values are recorded in `color-palette.md`, but the letter assignment itself and the blend-test validation are still undone.
- **Interior backlighting strip behavior:** planned (see `decision-log.md`) but undesigned — what does the interior strip actually do during normal play vs. Tutor mode vs. Simon mode? Candidate ideas floated: whole-case celebration pulse on correct Simon sequence, a progress-style fill during Tutor mode, distinct from (not duplicating) the ring's per-note color cue. Strip length/LED count also not chosen yet, which affects what patterns are even feasible.

## Menu / Simon-Learn mode
- **Menu structure:** nested (top-level = mode selection, then a song list within Tutor/Simon) vs. a single flat list mixing modes and songs together
- **Input behavior while menu is active:** do the A/G buttons stop playing notes entirely while the menu is open, since they're also the menu-exit/enter combo notes? (Current thinking: yes, menu takes over input entirely, but not fully decided.)
- **Visual feedback for entering/exiting the mode:** ring pulse/fade, OLED switching to a menu view, or both?
- **Song selection mechanism:** confirmed to use the font encoder to cycle once in the menu — but is there a preview (e.g. plays a snippet) before selecting?

## Firmware/software architecture
- Font-encoder push-button is overloaded (modifier-hold during play, short-click during menu) — needs an explicit state machine; not yet designed
- Exact refresh rate for the OLED live-updating pitch-bend readout (suggested ~10–20Hz as a starting point, not tested)

## Audio hardware
- **Amp GAIN pin now wired directly to GND (12dB) as of 2026-07-20 — still not as loud as wanted.** Started floating (9dB, chip default); moved to GND after a deliberate loudness check (`note_test.py`'s `AMPLITUDE` bumped to 0.9) still wasn't loud enough on its own. Next candidate: a 100kΩ resistor from GAIN to GND instead (15dB, max per datasheet) — not yet tried, pending confirming a 100kΩ resistor is on hand. If 15dB still isn't sufficient, the plan is to revisit amp/speaker hardware selection rather than keep pushing software gain.

## Hardware / case
- Final case dimensions are working estimates from trigonometry, not yet validated against actual component footprints (encoder bushing clearance, joystick module mounting depth, button+cap stack height, LiPo cell thickness). Confirm once parts are physically in hand and before finalizing the OpenSCAD model.
- Speaker firing direction/grille placement finalized (front wall) but exact grille hole pattern/size not yet modeled
- **Speaker-vs-shelf clearance fix, needed before the next print** (see decision-log.md "Case geometry" for the full writeup): right speaker's physical depth collides with the right-side shelf cluster (joystick especially, at shelf x=-65). Unit #1 worked around it by trimming the speaker by hand — not a CAD fix. Next print needs: (1) an actual caliper depth measurement of the speaker, (2) a decision between repositioning the joystick's shelf x-position, locally recessing the shelf underside, or increasing shelf depth. Left side (rocker/octave encoder) had a milder version of the same issue, worked around with a sideways rocker orientation + trimmed encoder mounting corners.
- Whether the case needs a lid/access panel for battery replacement or SD card access down the line — not yet discussed

## Future / stretch
- Second unit as a Raspberry Pi Pico build (cheaper, instant-on, better battery life) — shelved for now, would require rewriting the audio engine without `pygame.mixer`'s easy polyphony
- Arcade-style trackball as an alternate/additional control — shelved as too expensive for one part, revisit if a "premium" unit is ever built
