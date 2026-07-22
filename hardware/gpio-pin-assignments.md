## GPIO pin assignments (Pi Zero 2 W, BCM numbering)

Locked in against the current BOM. Bus/protocol-fixed pins were assigned first (I2C, I2S), since those can't move; everything else was assigned from the remaining free GPIO.

### Fixed by protocol
| Function | Pin(s) | Notes |
|---|---|---|
| I2C bus (SDA/SCL) | GPIO2, GPIO3 | Shared by ADS1115 (volume pot + joystick axis) and OLED, different addresses |
| I2S (BCLK, LRCLK, DOUT) | GPIO18, GPIO19, GPIO21 | Shared by both MAX98357A amps (same stream, mono to both channels) |

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

Ring boards typically break out 6 pads (an input triad — DIN/5V/GND — and an output triad — DOUT/5V/GND — for daisy-chaining another ring/strip downstream). This build uses a single ring with nothing chained after it, so **only wire the input triad**; leave DOUT and its paired 5V/GND unconnected.

Logic-level note: WS2812 data is normally driven at ~5V logic, while the Pi's GPIO is 3.3V — technically under spec for a 5V-powered chain. In practice a short chain like this (7 LEDs, short wire run) very often works driven directly with no level shifter, especially on newer WS2812B-clone chips. Try direct first; if the first LED shows wrong/flickery color while the rest look correct, that's the classic symptom, and the standard fix is a logic-level shifter (e.g. 74AHCT125) between GPIO12 and DIN.

### Note buttons (7, direct GPIO, no matrix)
| Note | Pin |
|---|---|
| A | GPIO4 |
| B | GPIO17 |
| C | GPIO27 |
| D | GPIO22 |
| E | GPIO10 |
| F | GPIO9 |
| G | GPIO11 |

GPIO9/10/11 are the SPI MISO/MOSI/SCLK pins — unused here since nothing on this build needs SPI, safe to repurpose as plain GPIO.

### Octave encoder (EC11, shelf far left)
| Function | Pin |
|---|---|
| A (quadrature) | GPIO5 |
| B (quadrature) | GPIO6 |
| Common | GND |
| Push-button | GPIO13 |
| Push-button (other switch leg) | GND |

### Font encoder (EC11, shelf far right)
| Function | Pin |
|---|---|
| A (quadrature) | GPIO26 |
| B (quadrature) | GPIO16 |
| Common | GND |
| Push-button | GPIO20 |
| Push-button (other switch leg) | GND |

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
- Used: GPIO2,3,4,5,6,9,10,11,12,13,16,17,18,19,20,21,22,23,24,26,27 = **21 of 26 usable GPIO**
- Spare: GPIO7, GPIO8, GPIO14, GPIO15, GPIO25 (5 pins) — GPIO14/15 are UART TX/RX, reclaimable as plain GPIO if serial console is disabled in `raspi-config`, but leave as spares for now rather than assuming that
