# ChromaCade — Project Overview & Task Breakdown

## What we're building
A DIY musical instrument for toddlers, built around a Raspberry Pi Zero 2 W. It's a teaching instrument, not a performance instrument — every design choice is judged on whether it helps a small child build real musical intuition (note names, octave equivalence, the sharp/flat relationship, chord color), not on how musically flexible or feature-rich it is.

A few things that shape the whole design:

- **7 letter-named buttons (A–G)**, not 12 chromatic keys, plus one global flat/natural/sharp switch — teaches that sharps/flats are modifications of a natural note, not separate notes.
- **Color as music theory, not decoration.** Each letter has a fixed base hue across all octaves (teaches octave equivalence). Sharp shifts a note's color warmer, flat shifts it cooler. Octave maps to brightness, not hue. There's an open design question around getting chord colors to blend into something genuinely pleasant ("color chords") — more on that below.
- **Chunky and durable over compact.** Generous spacing, thick walls, robust mounting — this is a toy that gets grabbed, dropped, and mashed.
- **Parent-friction by design.** Volume, power, and charging are placed to be a little inconvenient for a toddler to reach, so the toy doesn't get "forgotten" by an exhausted parent.
- **Two-handed play.** Left hand handles octave + sharp/flat (setup actions), right hand handles voice/font + pitch-bend (live shaping), both hands can reach the 7 note buttons in the center.

We're building 4 units total, starting with one full build (unit #1) to shake out issues before replicating.

## Team
Three people: Shane (lead — hardware, embedded systems, project coordination) and two software-inclined contributors with interest and some experience with raspberry pi or arduino type projects (Brian and Sean). The breakdown below is organized by workstream so people can specialize and parallelize. Treat it as a starting proposal — reassign once everyone's had a session or two and knows what they actually enjoy.

## The tracks

**1. Hardware & wiring** (Shane)
Finalizing the parts list, soldering/wiring unit #1 (power chain, I2C bus, amps, GPIO for all the controls), bench-testing each subsystem, physical assembly into the case.

**2. Case design & 3D printing** (Shane)
Measuring real component footprints, building a parametric OpenSCAD model, refining for fit and aesthetics, test prints, iterating on fit.

**3. Core audio engine** (software — open to either contributor)
Python + pygame.mixer for polyphonic playback of the 7 notes, sharp/flat handling via semitone shifting, octave shifting, font/voice switching, pitch-bend joystick integration, volume ceiling, GPIO input polling with debounce.
*Good first task, no hardware needed:* stub out note-playback architecture and pitch-bend math against a placeholder note table — fully testable on a laptop.

**4. Display & color system** (software — smaller scope, open to either contributor or Shane)
OLED status display (note, font, pitch, volume), LED ring driver mapping note→hue/warmth/brightness, and the **color-chord blending prototype** — a standalone, hardware-free script that tests different hue-arc assignments for how well major/minor triads blend into pleasant combined colors. This is a great starting task for someone who wants to begin before any hardware arrives.

**5. Menu & Simon/Learn mode** (software — open to either contributor)
State machine for entering/exiting a menu via an encoder-hold + long-press gesture, menu navigation, a tutor mode (plays a sequence, waits for correct button presses), a Simon-style memory game, and encoding a handful of simple songs (Twinkle Twinkle, Hot Cross Buns, Mary Had a Little Lamb, Ode to Joy).

**6. Integration & testing** (all three, once hardware + software converge)
Full system bring-up, latency checks (target under ~50-100ms button-to-sound), real-world toddler testing, fixing issues on unit #1 before replicating across units #2-4.

## Suggested starting split
Tracks 3 and 5 are the two most independent, clearly-scoped software tracks — good candidates for the two contributors to pick between based on what sounds more interesting. Track 4 is smaller and has a fun, hardware-free starting point (the color-blending prototype) either of them could knock out early to get oriented. Tracks 1 and 2 default to Shane given the hands-on/embedded background, unless either contributor has relevant electronics or CAD experience worth tapping.

## Next steps
Once you two have picked which track(s) you want to take, let Shane know — he'll share the specific design docs and specs you'll need for that track (control layout, GPIO pin assignments, feature spec, etc.).

Repo: https://github.com/irish-bug/ChromaCade — see `CONTRIBUTING.md` for the branch/PR workflow before you start.
