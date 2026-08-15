## GPIO pin assignments (Pi Zero 2 W, BCM numbering)

Locked in against the current BOM. Bus/protocol-fixed pins were assigned first (I2C, I2S), since those can't move; everything else was assigned from the remaining free GPIO.

### Fixed by protocol
| Function | Pin(s) | Notes |
|---|---|---|
| I2C bus (SDA/SCL) | GPIO2, GPIO3 | Shared by ADS1115 (volume pot + joystick axis) and OLED, different addresses |
| I2S (BCLK, LRCLK, DOUT) | GPIO18, GPIO19, GPIO21 | Single MAX98357A amp now drives both speakers as of 2026-07-28 (second amp removed from the build — see `decision-log.md`); same I2S stream as before |

### ADS1115 (single chip per unit — see hardware-bom.md)
| Function | Connection | Notes |
|---|---|---|
| ADDR | GND | Sets I2C address 0x48 (default). Don't tie to VDD/SDA/SCL — those give 0x49/0x4A/0x4B, only needed if a second ADS1115 is ever added to the same bus. |
| A0 | KY-023 joystick axis output | Joystick module's VCC/GND at 3.3V/GND; only one axis wired (pitch bend is single-axis). Matches `hardware_poller.py`'s `joystick_chan = AnalogIn(ads, ADS.P0)` — the library's `P0`/`P1` constants are just names for physical A0/A1, not a separate channel numbering. **Confirmed 2026-07-29 via bring-up test: raw voltage direction is inverted from desired pitch-bend direction** (pushing forward decreases voltage, pulling back increases voltage) — as-wired, not worth re-wiring for. Desired behavior is forward = sharp, back = flat, so whichever code eventually converts this reading into a bend amount should invert around center (e.g. `bend = center_voltage - voltage`, not `voltage - center_voltage`) — same shape of gotcha as the A1 volume pot's inversion below. |
| A1 | Fender 500K volume pot wiper | Pot's outer two legs across 3.3V/GND. Matches `hardware_poller.py`'s `volume_chan = AnalogIn(ads, ADS.P1)`. **Confirmed 2026-07-22 via bring-up test: raw voltage direction is inverted from desired volume direction** (clockwise turn decreases voltage) — as-wired, not worth re-wiring for. Whichever code eventually converts this reading into a volume level should invert the normalization (e.g. `volume = 1.0 - (voltage / 3.3)`, not `voltage / 3.3`) rather than assuming raw voltage tracks volume directly. |
| VDD | 3.3V (physical pin 1 or 17) | |
| GND | any Pi GND | |

### OLED (SSD1306, shares the I2C bus)
| Function | Connection |
|---|---|
| SDA | GPIO2 (physical pin 3) — same node as the ADS1115's SDA |
| SCL | GPIO3 (physical pin 5) — same node as the ADS1115's SCL |
| VCC | 3.3V (physical pin 1 or 17) |
| GND | any Pi GND |

Address is typically 0x3C, different chip family from the ADS1115's 0x48 — no collision expected, confirm with `sudo i2cdetect -y 1` once both are wired.

### WS2812 LED ring
| Function | Pin | Notes |
|---|---|---|
| Data (DIN) | GPIO12 | PWM0 alt function. **Not GPIO18** — that's claimed by I2S BCLK, a common conflict with the default `rpi_ws281x` example code. Confirm your library call targets GPIO12 explicitly. |
| 5V | Pi 5V rail | |
| GND | any Pi GND | |

Ring boards typically break out 6 pads (an input triad — DIN/5V/GND — and an output triad — DOUT/5V/GND — for daisy-chaining another ring/strip downstream). This build's ring is confirmed **Jewel-style** (6 outer LEDs + 1 center, not 7 evenly spaced around a circle — bring-up test 2026-07-21 showed the chain walking the 6 outer positions then lighting the center pixel last). **As of 2026-07-28, the ring is a standalone 7-pixel chain** — the output triad is unwired and has no planned use. See "WS2812 LED interior strip" below for why the strip isn't chained off it.

Logic-level note: WS2812 data is normally driven at ~5V logic, while the Pi's GPIO is 3.3V — technically under spec for a 5V-powered chain. In practice a short chain like this (7 LEDs, short wire run) very often works driven directly with no level shifter, especially on newer WS2812B-clone chips. Try direct first; if the first LED shows wrong/flickery color while the rest look correct, that's the classic symptom, and the standard fix is a logic-level shifter (e.g. 74AHCT125) between GPIO12 and DIN. **Resolved 2026-07-28: confirmed working driven directly, no level shifter needed.** The ring had shown multi-color corruption on the old combined 23-pixel chain even after resoldering the DIN joint, which looked ring-specific at the time — but running it standalone on its own GPIO12 chain (`led_ring_test.py --target ring`) came back clean. In hindsight the corruption was a combined-chain-length issue, not a ring-specific defect; splitting ring and strip onto independent GPIO12/GPIO13 chains was the actual fix.

### WS2812 LED interior strip
| Function | Pin | Notes |
|---|---|---|
| Data (DIN) | GPIO13 | PWM1 alt function — a separate hardware PWM/DMA channel from the ring's GPIO12/PWM0, not a second pin on the same channel. Physical pin 33. |
| 5V | Pi 5V rail | |
| GND | any Pi GND | |

**Independent 16-pixel chain, not daisy-chained off the ring, as of 2026-07-28** — superseding the original plan (see `decision-log.md`) to chain ring-OUT → strip-IN on one GPIO12 line. Reasons: (1) diagnostic isolation while the ring/strip combined chain was showing corruption — splitting them lets each be tested and fixed independently rather than the strip's symptoms being entangled with (or caused by) whatever the ring's problem turns out to be; (2) shorter individual runs, which reduces signal-degradation distance on each chain. GPIO13 was available for this because the octave encoder's push-button — previously on GPIO13 — was moved to GPIO25 (see "Octave encoder" below); that button's click has no assigned function yet (`open-questions.md`), so it was a better fit to relocate than to leave a PWM-capable pin tied up on a plain digital read.

**Onboard PWM audio conflict — found and fixed 2026-08-12.** The Pi's onboard analog audio path (`dtparam=audio=on` in `/boot/firmware/config.txt`, backed by the `snd_bcm2835` kernel module) claims the same PWM0/PWM1 hardware peripheral that the ring (GPIO12) and strip (GPIO13) use for WS2812 data — a well-documented conflict class for Pi + NeoPixel projects, independent of whether a physical audio jack exists on the board. This build's actual audio output is entirely I2S (`dtoverlay=hifiberry-dac`, `dtparam=i2s=on`), so the onboard PWM audio path was unused dead weight. Set `dtparam=audio=off` and rebooted — board confirmed back up, HifiBerry DAC still shows correctly in `aplay -l`, and the PWM-audio ALSA card no longer registers. Suspected cause of a rhythmic playback stutter noticed during amp rewiring that session — **not yet re-confirmed with a live combined audio+LED playback test**, do that before treating this as fully resolved.

### Note buttons (7, direct GPIO, no matrix)
| Note | Pin |
|---|---|
| C | GPIO4 |
| D | GPIO17 |
| E | GPIO27 |
| F | GPIO22 |
| G | GPIO10 |
| A | GPIO9 |
| B | GPIO11 |

**Letters relabeled 2026-08-15 — physical wiring unchanged.** Originally labeled A-G in physical left-to-right order; relabeled C-D-E-F-G-A-B (same GPIO pins, same physical buttons) to match the C-to-B octave-numbering convention decided in `feature-spec.md`. Confirmed via live `note_buttons_test.py` run, pressed strictly left to right: GPIO4, GPIO17, GPIO27, GPIO22, GPIO10, GPIO9, GPIO11 in that physical order — now C, D, E, F, G, A, B respectively.

GPIO9/10/11 are the SPI MISO/MOSI/SCLK pins — unused here since nothing on this build needs SPI, safe to repurpose as plain GPIO.

**WM8960 Audio HAT shares GPIO17 with Note B — confirmed 2026-08-13.** The Waveshare WM8960's onboard tactile button is hardwired to GPIO17 on the board itself (per its published pinout), same pin as Note B. Confirmed via `note_buttons_test.py`: pressing the WM8960's own button registers as a B press. Purely two switches in parallel on the same net — no electrical conflict, driver doesn't touch GPIO17 at all (checked `wm8960-soundcard.dts`/`.c`, no reference). Functionally irrelevant since nothing intentionally presses the HAT's own button, but worth knowing during assembly — an accidental bump against it in the enclosure would read as a phantom B press.

### Octave encoder (EC11, shelf far left)
| Function | Pin |
|---|---|
| A (quadrature) | GPIO5 |
| B (quadrature) | GPIO6 |
| Common | GND |
| Push-button | GPIO8 |
| Push-button (other switch leg) | GND |

Moved from GPIO13 to GPIO25 on 2026-07-28 to free GPIO13 (PWM1) for the LED strip's own independent data line — see "WS2812 LED interior strip" above. **Then moved again, GPIO25 → GPIO8, confirmed working 2026-08-14.**

**Resolved: the switch was never dead.** It never registered on GPIO25 and was briefly treated as a dead switch (see `decision-log.md`), but that was traced to solder/desolder history on GPIO25's specific pad from the old 3-key test mount's "Key 3" — a plausible fault independent of the switch. Confirmed via `encoder_test.py --which octave --button-pin 8`: clean registration on GPIO8, a genuinely untouched spare (GPIO14/GPIO15 carry the same test-mount history as GPIO25 and were avoided for the same reason). GPIO8 is now the permanent assignment; GPIO25 is free again.

**Rotation direction inverted as wired — confirmed 2026-08-14.** Turning the shaft physically clockwise registers as CCW via `encoder_test.py` (and vice versa) — as-wired, not worth re-wiring for, same pattern as the volume pot and joystick axis inversions (see the ADS1115 section above). Whichever code eventually maps encoder steps to octave changes should invert the CW/CCW interpretation (or swap the GPIO5/GPIO6 argument order when constructing `RotaryEncoder`) rather than assuming a physical clockwise turn raises the octave.

### Font encoder (EC11, shelf far right)
| Function | Pin |
|---|---|
| A (quadrature) | GPIO26 |
| B (quadrature) | GPIO16 |
| Common | GND |
| Push-button | GPIO7 |
| Push-button (other switch leg) | GND |

**Moved off GPIO20 to GPIO7, confirmed working 2026-08-14.** GPIO20 was the originally documented pin, but it's permanently claimed by the I2S peripheral (`dtparam=i2s=on` puts GPIO20 in ALT0/PCM_DIN — confirmed via live `pinctrl`, not just a theoretical conflict) and can never function as a plain GPIO input while I2S audio is enabled, which it always will be on this build. That button would never have registered a press no matter how it was wired. GPIO7 is a clean, conflict-free spare — full rotation + button confirmed working there.

**Rotation direction inverted as wired — confirmed 2026-08-14.** Same as the octave encoder (see above): physical clockwise reads as CCW via `encoder_test.py` and vice versa. As-wired, not worth re-wiring for — invert in software when mapping steps to font/instrument selection.

Each bare EC11 has 5 pins whose physical layout can vary by manufacturer — don't trust a guessed silkscreen order. Identify by continuity (power off): 2 pins show continuity to each other *only* while the shaft is pressed — those are the pushbutton's two legs (either can go to the GPIO, the other to GND). Of the remaining 3, one (Common) shows continuity to the other two as you slowly rotate the shaft; those other two are A and B — which one is "A" vs "B" only affects direction sense, easy to flip in software during bring-up if backwards.

### Flat/natural/sharp rocker (XINYIELE, ON-OFF-ON)
| Function | Pin |
|---|---|
| Throw 1 (flat) | GPIO23 |
| Throw 2 (sharp) | GPIO24 |
| Common | GND |

Wire each throw to ground through its own GPIO with internal pull-up enabled, active-low. Center (natural) position leaves both open — no wire needed for "natural" as a distinct signal, it's just the absence of either throw. If the 3 terminals aren't obviously labeled, identify Common by continuity: hold the switch in each throw position and check which terminal stays connected to the middle terminal in both positions — that's Common, wire it to GND.

### Power switch
Not assigned a GPIO. The DWEII boost/charge board's keypad connection point handles on/off inline on the power path — no Pi GPIO involved unless a future soft-shutdown feature is added later.

### Budget
- Used: GPIO2,3,4,5,6,7,8,9,10,11,12,13,16,17,18,19,21,22,23,24,26,27 = **22 of 26 usable GPIO**
- Spare: GPIO14, GPIO15, GPIO25 (3 pins) — GPIO14/15 are UART TX/RX, reclaimable as plain GPIO if serial console is disabled in `raspi-config`, but leave as spares for now rather than assuming that. GPIO25 freed up 2026-08-14 when the octave button moved to GPIO8 (see "Octave encoder" above) — it's a clean spare going forward, but be aware it has prior solder history from the old 3-key test mount if a future fault ever needs explaining.
- **Not usable at all, don't assign here: GPIO20.** Permanently claimed by the I2S peripheral (`dtparam=i2s=on` → ALT0/PCM_DIN) on this build regardless of what's wired to it — confirmed via `pinctrl`, not theoretical. Was the font button's original (never-working) assignment; moved to GPIO7 2026-08-14. Excluded from both the used and spare counts above since it was never actually available.


J8:
   3V3  (1) (2)  5V    
 GPIO2  (3) (4)  5V    
 GPIO3  (5) (6)  GND   
 GPIO4  (7) (8)  GPIO14
   GND  (9) (10) GPIO15
GPIO17 (11) (12) GPIO18
GPIO27 (13) (14) GND   
GPIO22 (15) (16) GPIO23
   3V3 (17) (18) GPIO24
GPIO10 (19) (20) GND   
 GPIO9 (21) (22) GPIO25
GPIO11 (23) (24) GPIO8 
   GND (25) (26) GPIO7 
 GPIO0 (27) (28) GPIO1 
 GPIO5 (29) (30) GND   
 GPIO6 (31) (32) GPIO12
GPIO13 (33) (34) GND   
GPIO19 (35) (36) GPIO16
GPIO26 (37) (38) GPIO20
   GND (39) (40) GPIO21
