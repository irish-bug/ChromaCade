# ChromaCade — Hardware Bring-Up Plan, July 20 2026

Scope: bring up the 3-key test mount electrically, then wire and bring up the two MAX98357A amps. Two things below are worth reading before you pick up the iron, because they touch pins your locked GPIO budget already spoke for.

## Conflict #1 (resolved): key 3 moved off GPIO18

Key 3 was originally wired to physical pin 12 (GPIO18), which collides with the locked I2S BCLK line — shared by both amps per `gpio-pin-assignments.md`. Rather than juggling connect/disconnect between the key test and the amp test, key 3's GPIO lead moved to **GPIO25 (physical pin 22)** — a clean spare, untouched by I2C, I2S, or SPI. Key test and amp test can now run in either order, or with both wired up simultaneously, with nothing to unplug in between.

Ground bus is unaffected — still the Wago to physical pin 6 (GND).

Current key wiring:

| Key | Pi physical pin | GPIO |
|---|---|---|
| Key 1 | 8 | GPIO14 |
| Key 2 | 10 | GPIO15 |
| Key 3 | 22 | GPIO25 |

## Conflict #2: don't let the amp's SD_MODE pin land on GPIO4

This one's easy to hit by accident if you follow a generic online wiring guide. The MAX98357A has an SD_MODE pin that's *not* just shutdown — its analog voltage level also selects mono-mix vs. left-only vs. right-only output. Most Raspberry Pi tutorials for this chip tell you to wire SD_MODE to a GPIO (GPIO4 by default) and use the `dtoverlay=max98357a` device-tree overlay, which drives that pin in software.

GPIO4 is your note button A. Wiring SD_MODE there — even just following a tutorial's default — would collide with a locked pin.

You don't actually need a GPIO for this at all. Per the datasheet, SD_MODE has an internal 100kΩ pulldown to ground. Leave it fully floating and the amp sits in permanent shutdown (silent). Adafruit's own breakout solves this with a single onboard 1MΩ resistor from SD_MODE to VIN — the divider against the internal 100kΩ pulldown lands SD_MODE around 0.45V at 5V VIN, which is squarely in the "(Left+Right)/2 mono mix" band (datasheet: 0.16–0.77V = mono mix, >1.4V = left only, 0.77–1.4V = right only, <0.16V = shutdown). That's exactly the "same stream to both amps" behavior your `feature-spec.md` already calls for — no channel-splitting needed since both amps should output identical mono content.

**Before soldering:** check whether your specific boards (BOM just says "2-pack," no brand confirmed) already have that resistor built in — look for a small SMD resistor near the SD_MODE pin, or just check whether SD_MODE is even broken out to its own pad vs. tied internally. If it's already handled on-board, leave that pin unconnected and move on. If it's not, add one 1MΩ resistor per board, bridging SD_MODE to VIN directly at the amp — a hand-soldered air-wire resistor is fine, this doesn't need to be pretty. This keeps the whole SD_MODE question off the GPIO budget entirely, consistent with your locked pin sheet, which never reserved a pin for it.

Software side: use `dtoverlay=hifiberry-dac` (generic I2S DAC overlay, no SD_MODE control), **not** `dtoverlay=max98357a` (which assumes GPIO4 unless you override `sdmode-pin=`, and you don't want to depend on remembering that override every time you touch config.txt).

## Also worth a 30-second check: GPIO14/15 and the serial console

GPIO14/15 are UART0 TX/RX. On a stock Raspberry Pi OS image the serial console is usually off by default, but it's worth confirming before you trust key-1/key-2 readings — if the console's still attached to those pins, you'll get login-shell noise instead of clean GPIO levels, which could look identical to a flaky Wago connection (something you already flagged as a risk with the Dupont leads). Check with `sudo raspi-config` → *Interface Options* → *Serial Port* → answer **No** to "login shell over serial" and **No** to "serial port hardware enabled" (you're not using UART for anything here), then reboot if you change anything.

---

## Step-by-step for today

**1. Key test**
- Confirm serial console is off (above).
- Tug-test each Wago connection — ground bus and all three GPIO leads — before trusting any reading.
- Run `key_test.py` (below). Press each key a few times, check clean single-press detection with no double-triggers or dropouts, then try two/three keys held together (this is your chord-support sanity check, even though these three GPIO aren't the final note pins).
- Note anything flaky — that's a mechanical/connection issue to chase before it gets buried under seven more keys later.

**2. Solder the amp(s)** (one MAX98357A soldered so far, per your message — second one whenever)
- Each MAX98357A: BCLK, LRC, DIN, GND, VIN pins get header pins; speaker+ / speaker− get the stripped bare-wire ends (confirmed already in your BOM notes — the JST-PH2.0 speaker connectors don't mate with the amp's screw terminals). Speaker wiring: red → the terminal silkscreened "+", the red/black wire → "−".
- Check/add the SD_MODE resistor per Conflict #2 above.

**3. Wire the amp(s) to the Pi** (if/when you solder the second amp, it lands on the *same three* Pi pins as the first — that's intentional, it's how one I2S bus feeds two amps with identical mono content)

| Amp pin | Pi physical pin | Pi GPIO |
|---|---|---|
| BCLK | 12 | GPIO18 |
| LRC (word select) | 35 | GPIO19 |
| DIN | 40 | GPIO21 |
| GND | 6, 9, 14, 20, 25, 30, 34, or 39 | GND |
| VIN | 2 or 4 | 5V |

Wire BCLK on amp #1 and amp #2 both to physical pin 12, same for LRC→35 and DIN→40. GND can go to any Pi ground pin, including reusing your existing Wago ground bus if that's convenient — it's all common ground regardless of which physical pin it lands on.

**Power note:** two 3W amps at full tilt can pull on the order of 1.2A combined at 5V, on top of whatever the Pi itself draws (250–500mA typical for a Zero 2 W under load). If you're bench-powering from a laptop USB port or a weak wall adapter rather than the DWEII 5V/2A boost board, keep initial volume low and watch for Pi brownouts (unexpected reboots, rainbow-square/low-voltage warnings) before assuming a software bug if something crashes.

**4. Enable I2S**
```
sudo nano /boot/firmware/config.txt
```
Add (under `[all]` or at the bottom):
```
dtparam=i2s=on
dtoverlay=hifiberry-dac
```
Save, reboot.

**5. Confirm the sound card is up**
```
aplay -l
```
You should see an entry like `card 0/1: sndrpihifiberry`. If it's not there, the overlay didn't load — check for typos in config.txt and confirm you edited `/boot/firmware/config.txt` (Bookworm moved it there; `/boot/config.txt` is just a symlink to the same file, either works).

**6. Run the tone test**
- Run `audio_test.py` (below). It generates a short sine tone with the Python standard library only (no pip installs needed on the bench) and plays it via `aplay`. You should hear it from both speakers simultaneously — that's expected and correct, not a wiring mistake, since both amps get the same mono stream by design.
- If `aplay -l` shows the card but you get silence, the SD_MODE pin is the first suspect (Conflict #2) — check continuity/voltage on that pin with a multimeter before re-checking the I2S data lines.

## Deferred to a later session
- Wiring the real 7 note buttons to their locked pins (GPIO4/17/27/22/10/9/11) — today's test mount pins (14/15/18) are intentionally not those, so nothing here needs to change when you build the full panel.
- `pygame.mixer` integration — today's audio test is a raw ALSA tone, deliberately, to isolate hardware correctness before adding a software mixer layer on top.
