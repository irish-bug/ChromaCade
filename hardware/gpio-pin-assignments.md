## GPIO pin assignments (Pi Zero 2 W, BCM numbering)

Locked in against the current BOM. Bus/protocol-fixed pins were assigned first (I2C, I2S), since those can't move; everything else was assigned from the remaining free GPIO.

### Fixed by protocol
| Function | Pin(s) | Notes |
|---|---|---|
| I2C bus (SDA/SCL) | GPIO2, GPIO3 | Shared by ADS1115 (volume pot + joystick axis) and OLED, different addresses |
| I2S (BCLK, LRCLK, DOUT) | GPIO18, GPIO19, GPIO21 | Shared by both MAX98357A amps (same stream, mono to both channels) |

### WS2812 LED ring
| Function | Pin | Notes |
|---|---|---|
| Data | GPIO12 | PWM0 alt function. **Not GPIO18** — that's claimed by I2S BCLK, a common conflict with the default `rpi_ws281x` example code. Confirm your library call targets GPIO12 explicitly. |

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
| Push-button | GPIO13 |

### Font encoder (EC11, shelf far right)
| Function | Pin |
|---|---|
| A (quadrature) | GPIO26 |
| B (quadrature) | GPIO16 |
| Push-button | GPIO20 |

### Flat/natural/sharp rocker (XINYIELE, ON-OFF-ON)
| Function | Pin |
|---|---|
| Throw 1 (flat) | GPIO23 |
| Throw 2 (sharp) | GPIO24 |

Wire each throw to ground through its own GPIO with internal pull-up enabled, active-low. Center (natural) position leaves both open — no wire needed for "natural" as a distinct signal, it's just the absence of either throw.

### Power switch
Not assigned a GPIO. The DWEII boost/charge board's keypad connection point handles on/off inline on the power path — no Pi GPIO involved unless a future soft-shutdown feature is added later.

### Budget
- Used: GPIO2,3,4,5,6,9,10,11,12,13,16,17,18,19,20,21,22,23,24,26,27 = **21 of 26 usable GPIO**
- Spare: GPIO7, GPIO8, GPIO14, GPIO15, GPIO25 (5 pins) — GPIO14/15 are UART TX/RX, reclaimable as plain GPIO if serial console is disabled in `raspi-config`, but leave as spares for now rather than assuming that
