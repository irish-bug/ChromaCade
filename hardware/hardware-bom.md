# Hardware Bill of Materials — Toddler Synth

Quantities below are sized for a **4-unit build** unless noted. "Owned" means already in hand as of this writing; "Cart" means sourced/selected but not necessarily purchased yet — check current cart status before assuming.

## Compute & core
| Part | Notes | Status |
|---|---|---|
| Raspberry Pi Zero 2 W | One per unit | Owned (have "a Pi Zero or two") |
| microSD card | One per unit, for Pi boot | Owned |
| Jumper wires / Dupont terminal kit | General wiring | Owned |

First unit stays Pi Zero-based. A Pico or Teensy swap was considered (cheaper, instant-on, better battery life) but shelved for a possible later unit — not worth the audio-programming rework (losing `pygame.mixer` polyphony-for-free) given the LiPo already provides hours of runtime.

## Audio
| Part | Notes | Status |
|---|---|---|
| MAX98357A I2S 3W Class D amp | Mono. Originally one per speaker channel; as of 2026-07-28 unit #1 runs both speakers off a single amp instead (see `decision-log.md`) — second amp removed, kept as a spare | Owned (2-pack, 1 in use on unit #1) |
| 3W 8Ω speakers, JST-PH2.0 connector | DWEII brand | Owned (4x) |

Speaker JST-PH2.0 connectors won't plug into the MAX98357A's screw-terminal output — plan to strip/screw bare wire ends rather than expecting a plug-and-play connector match. 8Ω is within the amp's supported range (rated 4Ω+); expect roughly half the amp's 4Ω-rated power output at 8Ω, which is a fine match since the speakers themselves are only rated 3W anyway.

## Sensing / control electronics
| Part | Notes | Status |
|---|---|---|
| ADS1115 16-bit I2C ADC | 4-pack (Qoroos) — reads volume pot + joystick axis | Cart |
| EC11 rotary encoder w/ push-button, 5-pin | 6-pack (WWZMDiB) — need 2 per unit (octave, font) | Cart |
| KY-023 dual-axis analog joystick module | 6-pack — spring-centered, only one axis used, for pitch bend | Cart |
| Fender 500K pot | Reused from existing parts — volume only (pitch bend moved to joystick) | Owned (2x) |
| XINYIELE 3-way round rocker switch, ON-OFF-ON | 5-pack — flat/natural/sharp | Cart |

Fender pots are audio-taper (logarithmic), not linear — actually ideal for volume (matches perceived loudness), no correction needed.

## Display & lighting
| Part | Notes | Status |
|---|---|---|
| Hosyond 0.96" 128x64 SSD1306 I2C OLED | 5-pack — replaces original PiOLED plan, same driver/library, more resolution | Cart |
| WS2812 7-LED RGB ring | 5-pack — **Jewel-style layout** (6 outer LEDs + 1 center, not 7 evenly spaced around a circle — confirmed via bring-up test 2026-07-21, chain order walks the 6 outer positions then lights the center pixel last); unified color display near OLED (not per-button) | Cart |
| WS2812 strip (interior case backlighting) | **16 LEDs, chosen 2026-07-24** — combined with the 7-LED jewel ring, 23 total pixels on one chain, comfortably within the ~25-LED budget worked out at brightness 0.3 (see decision-log.md). Unit #1 is printed in translucent PLA, so an interior strip lights the whole case shell, not just the ring. Chains off the ring's spare OUT triad (same GPIO12 data line, no new GPIO — see `gpio-pin-assignments.md`). For Learn-mode/Simon-mode visual feedback plus general kid appeal. | Chosen, not yet sourced |

## Buttons (note keys)
| Part | Notes | Status |
|---|---|---|
| Outemu Blue clicky MX switches, 3-pin | 32-pack — need 28 (4 units × 7) + spares | Cart |
| Elacgap OEM Profile blank PBT keycaps, 1U, rainbow mix | 20-pack, likely need 2 packs for enough of each color across 4 units | Cart |

**Superseded:** originally sourced 12mm tactile buttons with 7-color caps (TWTADE) — too small, and 3 of the 7 colors were white/black/gray rather than usable rainbow colors. Returning these. MX switches at standard 19.05mm pitch keep the 7" panel width workable (7 switches ≈ 5.25" across).

## Power
| Part | Notes | Status |
|---|---|---|
| MakerHawk 3.7V 3000mAh LiPo battery, JST 1.25 | 4-pack — one per unit, spares for degradation over time | Cart |
| DWEII Type-C 5V/2A boost + charging + protection board | 10-pack — charges LiPo via USB-C, boosts to regulated 5V, has optional external keypad connection point usable for on/off switch | Cart |

Confirmed via labeled board photo: separate BAT+/BAT- pads (raw battery) vs. labeled 5V OUT +/- pads (regulated boost output) — wire the Pi to the OUT pads, not the battery pads directly. Do NOT use 4x AAA batteries (raw 4.8–6.4V, unregulated, outside Pi's safe input range in either direction) — this boost/charge board setup was chosen specifically to avoid that problem.

## Structural / prototyping
| Part | Notes | Status |
|---|---|---|
| 15×20cm (6"×8") double-sided perfboard | 2-pack (e.g. FOCMKEAS) — replaces original too-small 32-piece variety pack | Cart |

FR-4 perfboard can be cut to size with a score-and-snap technique (utility knife along a hole row, both sides, then snap over a table edge) or a fine-tooth saw/Dremel cutoff wheel. Wear a dust mask and eye protection — fiberglass dust is a lung/skin irritant. Trace the final layout in marker before cutting.

## 3D printing
- Printer bed limit: 8"×8"×8"
- Filament: standard PLA, no special color-spool investment needed now that keycaps are sourced pre-colored
- Workflow: OpenSCAD for parametric structure → Tinkercad for visual/fit refinement

## Sourcing notes
- Prefers Amazon for Prime shipping + easy returns; uses the Whole Foods drop-off + advance-credit trick to keep momentum while awaiting refunds on returned parts
- Multi-packs are intentional — most components already cover the full 4-unit run with spares baked in
