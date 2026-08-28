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

## LED ring color assignment — replaced wholesale 2026-08-27 (previously 2026-08-20, originally resolved 2026-08-15)
Live-tuned via `testing/led_ring16_test.py`'s `--rgb` mode, then carried over into `led_ring.py`'s `NOTE_COLORS` (the actual code driving the real ring — this doc mirrors that file, not the other way around; keep them in sync if either changes). Tuned against a different physical ring (a candidate 16-LED NeoPixel ring being bench-evaluated, not adopted).

**Current set (2026-08-27, direct instruction) is the candidate ring's LATER, more complete tuning pass** — all 7 colors brought to a consistent max-channel-88 ceiling, not just individual problem colors rebalanced. Per `testing/led_ring16_test.py`'s own header: lower intensity across the board reads more distinct on this hardware, not only for the colors that looked wrong at full brightness — even red/green/blue, which looked fine alone, read more washed out than necessary until compared side by side with the dimmed set. **Not yet re-confirmed with eyes on the real note-button ring** the way the 2026-08-20 first pass was (that pass ran on chromacade directly, and Sean judged it "a huge improvement" watching the real hardware) — do that before treating this set as equally settled.

| Letter | RGB | Hex | Hue |
|---|---|---|---|
| C | (88, 0, 0) | `#580000` | 0° |
| D | (88, 15, 0) | `#580f00` | 10° |
| E | (88, 55, 0) | `#583700` | 38° |
| F | (0, 88, 0) | `#005800` | 120° |
| G | (0, 0, 88) | `#000058` | 240° |
| A | (40, 0, 88) | `#280058` | 267° |
| B | (88, 0, 35) | `#580023` | 336° |

**2026-08-20 first pass (superseded above, kept for provenance):** C (255,0,0), D (255,50,0)/12°, E (125,85,0)/41°, F (0,255,0), G (0,0,255), A (40,0,88)/267° after a same-day second pass brightened purple specifically (was (10,0,24), too dim relative to the rest per Sean watching the real ring), B (255,0,100). That set was confirmed live on chromacade's real ring (see above) -- the 2026-08-27 set changes every letter's exact channel values except A (which already matched the max-88 ceiling from its own second pass) while keeping each letter's hue close to where it was, per the table below.

Still progresses monotonically around the hue wheel C through B with no backtracking, and the wrap from B (336°) back to C (0°/360°) is 24°, still one of the smaller gaps (compare E→F's 82° or A→B's 69°) — so the letter cycle still "comes back around" to red at the octave boundary rather than jumping randomly. **F→G is still the standout gap at 120°** (a full third of the hue wheel, and clearly the largest — bigger than the next-largest, E→F's 82°, by a wide margin) — unchanged from the first pass, since F and G are both pure primaries (0,88,0)/(0,0,88) whose hue doesn't move when only the ceiling changes. Worth keeping in mind for the chord-blend work below, since F and G are hue-farther apart than any other adjacent pair by a large margin. This still validates the 7-letter set as a coherent standalone rainbow — it does **not** resolve the separate hue-arc-compression/chord-blend question below, which is about how close hues need to be for multi-note chords to blend into color rather than mud, not whether the individual letters look good on their own.

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
