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

This is the ground truth for what each letter's physical button actually looks like.

## LED ring color assignment — resolved 2026-08-15
Tuned live against unit #1's actual WS2812 ring, **not** the keycap hex above. LEDs are additive-emission light sources, not reflective plastic — the pastel keycap hex values (all three channels high and close together) read as washed-out near-white once emitted as light rather than reflected off a surface, confirmed by directly testing them on the ring before settling on this set. Started from each letter's keycap color *family* (red, orange, etc.) and iterated bold, fully-saturated RGB values live on the hardware until each read clearly and unambiguously as its intended color.

| Letter | RGB | Hex | Hue |
|---|---|---|---|
| C | (255, 0, 0) | `#ff0000` | 0° |
| D | (255, 45, 0) | `#ff2d00` | 11° |
| E | (255, 170, 0) | `#ffaa00` | 40° |
| F | (0, 200, 0) | `#00c800` | 120° |
| G | (0, 100, 255) | `#0064ff` | 217° |
| A | (60, 0, 255) | `#3c00ff` | 254° |
| B | (255, 20, 147) | `#ff1493` | 328° |

Progresses monotonically around the hue wheel C through B with no backtracking, and the wrap from B (328°) back to C (0°/360°) is only 32° — one of the *smaller* gaps in the sequence (compare E→F's 80° or A→B's 74°), so the letter cycle visually "comes back around" to red at the octave boundary rather than jumping randomly. This validates the 7-letter set is coherent as a standalone rainbow — it does **not** resolve the separate hue-arc-compression/chord-blend question below, which is about how close hues need to be for multi-note chords to blend into color rather than mud, not whether the individual letters look good on their own.

The hue-arc compression and chord-blend validation described in `feature-spec.md`'s Color system section are still open (see `open-questions.md`) — both resolved assignments above are real inputs to that work, not a replacement for it.

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
