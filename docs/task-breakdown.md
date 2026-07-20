# Task Breakdown — Toddler Synth Team Build

Three people: Shane (lead — hardware, embedded systems, project coordination), brother (software-inclined), dad from the nanny-share (software-inclined). Split below is organized by discipline/workstream rather than by unit, so people can specialize and parallelize. Treat this as a starting proposal — reassign once everyone's had a session or two and knows what they actually enjoy.

## 1. Hardware & Wiring — Shane
- Confirm final BOM against `hardware-bom.md`, place remaining orders / process returns
- Solder/wire unit #1's electronics: power chain (LiPo → boost/charge board → Pi), I2C bus (ADS1115 + OLED + LED ring share the same bus, different addresses), I2S amp ×2, GPIO for buttons/encoders/switch/joystick
- Bench-test each subsystem in isolation before full integration: power rail voltage check under load, I2C device scan (`i2cdetect`), button/switch continuity, amp output into a test speaker
- Physical assembly of unit #1 into the printed case

## 2. Case Design & 3D Printing — Shane
- Measure real component footprints once parts arrive (encoder bushing clearance, joystick module mounting depth, button+cap stack height, LiPo cell thickness, perfboard thickness)
- Build the parametric OpenSCAD model per `case-design.md` (panel angle, hole grids, wall thickness, standoffs)
- Refine/round in Tinkercad for fit and aesthetics
- Consider a small test print (single wall section or reduced-scale) to validate tolerances before committing to a full 6+ hour print
- Iterate based on fit issues once first print is in hand

## 3. Core Audio Engine — software track (assign to brother or dad)
- Python + `pygame.mixer` polyphonic playback for the 7 notes
- Sharp/flat handling via semitone-offset shifting (not note-renaming, to sidestep enharmonic naming edge cases — this was an early design decision)
- Octave shifting (global, applied to all held notes)
- Font/voice switching — multiple waveform or sample sets, cycled via the font encoder
- Pitch-bend joystick integration: read the ADS1115 channel, map to live frequency modulation of currently-held notes, spring back to zero on release
- Volume control with a software ceiling independent of the physical pot's range
- GPIO input polling loop for buttons/encoders/switch/joystick with debounce

**Good first task, self-contained, no hardware required:** stub out the note-playback architecture and pitch-bend math against a placeholder note table — testable on a laptop before any wiring exists.

## 4. Display & Color System — software track (assign to brother, dad, or Shane — smaller scope)
- OLED rendering: 4-line live status display per `feature-spec.md` (note+accidental large, font name, base Hz + signed bend offset, volume %)
- LED ring driver: base hue per note, warm shift for sharp / cool shift for flat, brightness mapped to octave
- **Color-chord blending prototype** (the open design question in `open-questions.md`): a standalone script — no hardware needed — that computes the blended RGB/HSV result for common major/minor triads against candidate hue-arc assignments (try compressing the 7 letters into ~180–250° of the wheel vs. full rainbow) and visually renders the results for comparison
- Finalize the hue-to-letter mapping once the blending prototype gives a good answer

**This is a great candidate for whoever wants to start before any hardware arrives** — it's pure color math and can be prototyped entirely on a laptop with a simple swatch-rendering script.

## 5. Menu & Simon/Learn Mode — software track (assign to brother or dad)
- State machine for the font-encoder-hold + long-press A/G menu entry/exit combo (see `control-layout.md` for the exact gesture grammar)
- Menu navigation: cycle via encoder turn, select via encoder click
- Tutor mode: sequence playback (light the ring in each note's color) + wait-for-correct-press-before-advancing logic
- Simon mode: escalating sequence + memory check + reset-on-wrong-press
- Song data: encode Twinkle Twinkle, Hot Cross Buns, Mary Had a Little Lamb, and Ode to Joy as simple note sequences
- OLED menu view (song title, current prompt, progress indicator)

## 6. Integration & Testing — all three, once hardware + software converge
- Full system bring-up on unit #1
- Latency check: button press to audible sound, target under ~50–100ms (anything slower will feel broken to a toddler mashing keys)
- Real-world testing for durability, comprehension, and engagement once a toddler is available to (gently) stress-test it
- Fix issues on unit #1 before replicating the build across units #2–4

## Suggested starting split
Tracks 3 (Core Audio Engine) and 5 (Menu/Simon-Learn Mode) are the two most independent, clearly-scoped software tracks — good candidates for the brother and the dad to pick between based on which sounds more interesting. Track 4 (Display & Color System) is smaller in scope and has a genuinely fun, hardware-free starting task (the color-blending prototype) that either of them could knock out early to get oriented, or that Shane could take since it ties closely into the LED wiring he'll already be doing. Tracks 1 and 2 (hardware wiring, case CAD) default to Shane given the hands-on/embedded background, unless either collaborator turns out to have relevant electronics or CAD experience worth tapping.
