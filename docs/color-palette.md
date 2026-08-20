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

## LED ring color assignment — replaced wholesale 2026-08-20 (originally resolved 2026-08-15)
Live-tuned via `testing/led_ring16_test.py`'s `--rgb` mode, then carried over into `led_ring.py`'s `NOTE_COLORS` (the actual code driving the real ring — this doc mirrors that file, not the other way around; keep them in sync if either changes). **Caveat carried over from `led_ring.py`'s comment: tuned against a different physical ring** (a candidate 16-LED NeoPixel ring being bench-evaluated, not adopted), not this project's actual decided ring — different WS2812 manufacturing batches can render the same numeric RGB slightly differently, so this set hasn't been re-confirmed live against the real ring the way the 2026-08-15 set was. Re-validate directly on hardware before treating it as final.

The 2026-08-15 set (tuned live against unit #1's actual WS2812 ring) is superseded below but its reasoning still applies: LEDs are additive-emission light sources, not reflective plastic — the pastel keycap hex values (all three channels high and close together) read as washed-out near-white once emitted as light rather than reflected off a surface. The same effect is what drove this new set away from generic/textbook RGB values too (e.g. green reads stronger than its numeric value on WS2812 hardware, so orange/yellow needed their green channel pulled well down, and purple needed far lower overall brightness, not just channel rebalancing, to avoid reading as pink).

| Letter | RGB | Hex | Hue |
|---|---|---|---|
| C | (255, 0, 0) | `#ff0000` | 0° |
| D | (255, 50, 0) | `#ff3200` | 12° |
| E | (125, 85, 0) | `#7d5500` | 41° |
| F | (0, 255, 0) | `#00ff00` | 120° |
| G | (0, 0, 255) | `#0000ff` | 240° |
| A | (10, 0, 24) | `#0a0018` | 265° |
| B | (255, 0, 100) | `#ff0064` | 336° |

Still progresses monotonically around the hue wheel C through B with no backtracking, and the wrap from B (336°) back to C (0°/360°) is 24°, still one of the smaller gaps (compare E→F's 79° or A→B's 71°) — so the letter cycle still "comes back around" to red at the octave boundary rather than jumping randomly. **F→G is now the standout gap at 120°** (a full third of the hue wheel, and clearly the largest — bigger than the next-largest, E→F's 79°, by a wide margin) — G moved from a green-tinted (0,100,255)/217° to a pure (0,0,255)/240°, while F stayed at 120° (its hue was already independent of the old value's exact green level, since R and B were both 0 either way). Worth keeping in mind for the chord-blend work below, since F and G are now hue-farther apart than any other adjacent pair by a large margin. This still validates the 7-letter set as a coherent standalone rainbow — it does **not** resolve the separate hue-arc-compression/chord-blend question below, which is about how close hues need to be for multi-note chords to blend into color rather than mud, not whether the individual letters look good on their own.

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
