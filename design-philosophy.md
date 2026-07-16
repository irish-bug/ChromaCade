# Design Philosophy — Toddler Synth

## Core identity
This is a **teaching instrument, not a performance instrument**. Every design decision gets evaluated against whether it helps a toddler build real musical intuition (note names, octave equivalence, the sharp/flat relationship, chord color) — not whether it maximizes musical flexibility or feature count. When a tradeoff comes up between "more capable" and "more legible to a small child," legibility wins.

This also means some deliberate limitations are *correct*, not compromises:
- 7 letter-named buttons (A–G) instead of 12 chromatic keys — teaches that sharps/flats are modifications of a natural, not separate notes
- One global flat/natural/sharp switch instead of per-note accidentals — chords can only be all-natural or all-modified, which is a real constraint on musicality but keeps the concept clean
- No polyphonic chord voicing complexity, no scales/modes, no tempo — none of that matters at this stage

## Chunky over compact
The device should never be optimized for minimal size. Bigger, sturdier, more spaced-out controls are correct even when a tighter layout is technically possible. This affects:
- Button/control spacing (generous gaps reduce accidental multi-touches)
- Wall thickness in the printed case (3–4mm+, not minimal)
- Standoffs and mounting bosses (robust, not delicate)
- Overall footprint — the 8×8×8" printer bound is generous headroom, not a target to approach

## Color as relationship, not decoration
Color coding throughout the device (button caps, LED ring) is meant to teach music theory, not just look nice:
- Each letter note has a fixed base hue, consistent across octaves — this teaches octave equivalence (a G in any octave is "G-colored")
- Sharp shifts a note's hue warmer; flat shifts it cooler — this teaches that accidentals are modifications of a base note, not different notes
- Octave maps to brightness/value, not hue — reinforces "same note family, different register"
- **Open design goal:** chord colors should blend into a genuinely pleasant combined color (a "color chord"), which requires compressing the 7 letters into a narrower hue arc rather than spreading them across the full 360° wheel (see open-questions.md). This is considered a key distinguisher between "toy" and "real comprehension tool."

## Parent-friction by design
Placement of certain controls is a deliberate usability lever aimed at parents, not just the child:
- Volume lives on the side panel — less convenient to reach than the front controls, discouraging constant cranking. A software volume ceiling backs this up regardless of pot position.
- Power switch is also side-mounted.
- Charging port is on the back wall — physically out of reach during normal play, so a toddler can't interrupt or fiddle with a plugged-in cable.
- The idea: excessive volume/frequent changes are the most likely reason a parent "forgets" to leave the toy out. Reducing friction-free access to the loudest, most disruptive controls protects the toy's long-term place in the household.

## Two-handed workflow, deliberately taught
The control layout is split so the child learns a left-hand/right-hand division of labor:
- **Left hand (shelf, far left):** octave encoder + flat/natural/sharp switch — "setup" actions, done before or between playing
- **Right hand (shelf, far right):** font/voice encoder + pitch-bend joystick — "live shaping" actions, done while notes are held
- **Center (panel):** the 7 note buttons themselves — the primary play surface, equally reachable by either hand

## Hands-on, documented, cost-conscious
Reflecting how this project is being run generally: prefer well-documented, sourceable parts over exotic ones; prefer autonomous/self-contained solutions (e.g. LiPo + integrated boost/charge board) over anything requiring external dependencies; keep a running account of *why* a decision was made, not just what was decided, so the reasoning survives across build sessions and collaborators.
