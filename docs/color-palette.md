# Color Palette

## Letter-to-color assignment — resolved 2026-08-15
Measured directly from unit #1's actual physical keycaps (photo-sampled, median RGB over a small patch per cap — see git history for the source photo's date/context if ever needed). Physical button order left to right is **C→D→E→F→G→A→B**, matching the C-to-B octave-numbering convention decided in `feature-spec.md`'s Note range section, not alphabetical A-G.

| Letter | Hex | Color |
|---|---|---|
| C | `#ad2f44` | red |
| D | `#fda869` | orange |
| E | `#f0d678` | yellow |
| F | `#cae3ca` | mint green |
| G | `#7dbaf4` | blue |
| A | `#a495d6` | lavender |
| B | `#e9bec7` | pink |

This is the ground truth for what each letter's physical button actually looks like — the LED ring's per-note color should match or intentionally relate to this, not be independently invented. The hue-arc compression and chord-blend validation described in `feature-spec.md`'s Color system section are still open (see `open-questions.md`) — this resolved letter assignment is a real input to that work, not a replacement for it.

## Original candidate list (as given 2026-07-19)
Unordered, no letter assignment — superseded for the 7 in-use colors by the measured values above, kept here for provenance. Two of these were never used on a button (excluded as "not really rainbow" per `hardware-bom.md`'s note on the Elacgap set's 8 usable colors) — `#aed4dd` (pale blue/cyan, the one usable color with no letter) and the two non-rainbow ones below.

- `#b63844`
- `#f6a965`
- `#ecd160`
- `#b8e0cd`
- `#aed4dd`
- `#74b8e5`
- `#ae98d9`
- `#eebbc0`
- `#dedde2`

`#535353`
