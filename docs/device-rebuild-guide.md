# Device Rebuild Guide

How to go from a blank SD card to a working ChromaCade unit's software/OS environment. Written 2026-08-20 after auditing `plinkplonk` (unit #2, Pi 4B) directly — every command here was actually run and verified on that device, not guessed. Unit #1 (`chromacade`) was lost with no equivalent record (see `docs/decision-log.md`/project history), which is the whole reason this exists now.

**Scope: this is the software/OS side only.** Enclosure printing and hardware wiring are covered by `enclosure/`, `hardware/`, and `testing/` respectively. This doc assumes the physical board is already wired per `hardware/gpio-pin-assignments.md`.

**Intentionally excluded: `user-songs/`.** Per direct instruction — the actual song content in that directory (custom Tutor-mode songs, e.g. `ripple.py`, `sarias_song.py`) is per-device personal data, not part of the reproducible base system. `.gitignore` already encodes this (`user-songs/*` / `!user-songs/README.md`) — only the format documentation is tracked. A rebuild gets the *capability* to load user songs (`tutor_songs.py`'s `load_user_songs()`), not any specific device's existing songs; copy those over by hand if wanted, following `user-songs/README.md`'s format.

## 1. OS image

Raspberry Pi OS (Debian 13 "trixie" based), flashed via Raspberry Pi Imager with these settings:
- Hostname: `plinkplonk` (or whatever this unit's name is — see `CLAUDE.md`'s "Syncing the physical board" section for the current unit)
- Username: `plink`
- SSH: enabled, public-key auth — add the controlling machine's key to authorized_keys (Imager's own "configure SSH" step, or after first boot: `ssh-copy-id`/manually appending to `~/.ssh/authorized_keys`)
- Everything else (locale, timezone, WiFi country) is whatever the Imager profile has set — not project-specific, no need to match a specific value

Confirmed on `plinkplonk`: kernel `6.18.39+rpt-rpi-v8`, `plink` already lands in the right groups by default (`gpio`, `i2c`, `spi`, `audio`, `video`, `dialout`, `sudo`) — no manual `usermod` needed, this is standard Raspberry Pi Imager behavior for the primary user.

## 2. Repo checkout

Cloned early, before the steps below, since several of them reference files from the repo directly:

```bash
git clone https://github.com/irish-bug/ChromaCade.git ~/ChromaCade
cd ~/ChromaCade
git checkout plinkplonk   # or whatever branch is current -- check CLAUDE.md's
                          # "Syncing the physical board" section before assuming
```

## 3. Boot config — WM8960 Audio HAT

Add to `/boot/firmware/config.txt` (the rest of that file's contents are stock Raspberry Pi OS defaults — camera/display auto-detect, `vc4-kms-v3d`, etc. — leave those alone), and **change the Imager-default `dtparam=audio=on` to `off`**:

```
dtparam=i2c_arm=on
dtparam=i2s=on
dtparam=audio=off
dtoverlay=wm8960-soundcard
```

`dtparam=audio=off` disables the Pi's onboard PWM audio path (the physical headphone-jack output, `snd_bcm2835`/shows up as an aplay -l card named "Headphones") — Raspberry Pi Imager enables it by default, and this section didn't previously mention turning it back off. Not just unused dead weight: it claims the same PWM0/PWM1 hardware peripheral the LED ring (GPIO12) and strip (GPIO13) use for WS2812 data, a well-documented conflict class for Pi + NeoPixel projects (see `hardware/gpio-pin-assignments.md`'s "Onboard PWM audio conflict" entry — found and fixed on unit #1 back on 2026-08-12, but never made it into this doc when it was written for `plinkplonk`, so the conflict quietly came back on this device via the Imager's own default). **Found again 2026-08-21** on `plinkplonk` specifically because `aplay -l` still showed the onboard "Headphones" card despite this guide's other steps all being followed — fixed by editing `/boot/firmware/config.txt` and rebooting (a `sudo sed -i` one-liner works fine for just this line), confirmed via a real reboot: onboard card gone from `aplay -l`, `wm8960soundcard` still present and working, mixer settings (the "Left/Right Output Mixer PCM" switches from §6 below) survived the restart, no new `dmesg` errors.

Then reboot. Current Raspberry Pi OS (kernel 6.18.x) ships `wm8960-soundcard.dtbo` as a stock overlay — no vendor install script/DKMS module needed, despite what older WM8960 setup guides say. Verify: `aplay -l` should show `card N: wm8960soundcard` and should **not** show a "Headphones" card; `sudo i2cdetect -y 1` should show the codec responding at `0x1a`.

## 4. System packages (apt)

```bash
sudo apt update
sudo apt install -y \
    python3-pytest python3-gpiozero python3-pil python3-pygame \
    python3-smbus python3-smbus2 i2c-tools alsa-utils \
    fluidsynth fluid-soundfont-gm
```

All of these are Debian-packaged — no `pip`/PEP 668 fighting needed for this group. (`python3-pytest` pulls in `python3-iniconfig`/`python3-pluggy` automatically. `fluidsynth` pulls in `libfluidsynth3`, `qsynth`, and a `fluidsynth.service` user unit as its own dependencies — harmless, that service is the standalone fluidsynth daemon, a different usage pattern from `pyfluidsynth`'s in-process library use below, not something this project runs.) `fluid-soundfont-gm` installs the real ~140MB `FluidR3_GM.sf2` General MIDI soundfont `audio_engine.py` actually loads (see `docs/open-questions.md`'s FluidSynth entry for the full story) — `libfluidsynth3` alone (a transitive dependency of the Adafruit stack below) is NOT sufficient on its own, it's just the runtime library with no soundfont data.

**Found missing entirely from this section 2026-08-20/21** — `testing/fluidsynth_test.py` failed with `ModuleNotFoundError` on a `plinkplonk` that had otherwise followed this whole guide, because neither `fluidsynth`/`fluid-soundfont-gm` (apt) nor `pyfluidsynth` (pip, next section) were ever in this doc's own instructions, despite `docs/decision-log.md`'s 2026-08-15 entry establishing `pyfluidsynth` needs the same sudo-pip treatment as the Adafruit stack — that entry documented the *convention*, but nobody had gone back and added the actual install step here. Fixed by adding both here and in the pip section below.

## 5. Python packages (pip) — the Adafruit CircuitPython stack

Not available via apt. This device's Python (3.13.5) enforces PEP 668 ("externally-managed-environment"), so a plain `pip3 install` is refused — use `--break-system-packages` (standard, Adafruit's own documented approach for this exact class of device, not a hack specific to this project).

**Must be installed with `sudo`, not a plain per-user `pip3 install`** — `docs/decision-log.md`'s "pip-only packages" entry (2026-08-15) documented this exact convention after finding `pyfluidsynth`/ads1x15/ssd1306 installed for the user but invisible to root, and root is what actually needs these: `neopixel`/WS2812 driving needs root for PWM/DMA access, matching `chromacade.service` running as root. **This section's own command was found missing `sudo` on 2026-08-20** — plinkplonk had the full stack for the `plink` user but *none* of it for root, discovered only when `sudo python3 led_ring16_test.py` failed with `ModuleNotFoundError` despite this guide having been followed. The gap wasn't caught earlier because the verification command below also ran unprivileged, so it couldn't have caught it — fixed below along with the install command itself.

```bash
sudo pip3 install --break-system-packages \
    adafruit-blinka \
    adafruit-circuitpython-ads1x15 \
    adafruit-circuitpython-ssd1306 \
    adafruit-circuitpython-neopixel \
    pyfluidsynth
```

This provides `board`, `busio`, `neopixel`, `adafruit_ads1x15.*`, `adafruit_ssd1306` — needed for the ADS1115 (joystick analog read), the SSD1306 OLED, and the WS2812 LED ring/strip, respectively — plus `fluidsynth` (the Python binding `audio_engine.py` imports; not to be confused with the apt package of the same name in the previous section, which is the C library + soundfont it wraps). `fluidsynth` itself doesn't strictly need root the way `neopixel`'s PWM/DMA access does, but install it with the same `sudo` anyway — keeping root and the regular user's environments identical is the whole point of `docs/decision-log.md`'s convention, don't reintroduce a split between them for one package.

**Full verification — run this exact command with `sudo`, not without.** A plain `python3 -c "..."` verification only proves the `plink` user's environment is correct; it says nothing about root's, which is the environment that actually matters here (`chromacade.service` and every WS2812 test script in `testing/` run as root). This is precisely how the 2026-08-20 gap slipped past this doc in the first place:
```bash
sudo python3 -c "import pytest, gpiozero, PIL, pygame, board, busio, neopixel, adafruit_ads1x15.ads1115, adafruit_ads1x15.analog_in, adafruit_ssd1306, fluidsynth"
```

There is still no `requirements.txt` anywhere in this repo (checked, doesn't exist) — this doc is currently the only record of the real dependency list. Worth turning this section into one at some point rather than relying on this doc staying in sync by hand.

## 6. Audio: `/etc/asound.conf` and mixer routing

The overlay alone (§3) is not sufficient — two more things are needed, found by trial on `plinkplonk` 2026-08-19/20:

**a) `/etc/asound.conf` does not exist by default.** Install the tracked template:

```bash
sudo cp ~/ChromaCade/audio/asound.conf /etc/asound.conf
```

`audio/asound.conf` in this repo is the live, verified file from `plinkplonk`, not a draft — its own header comments cover adapting it for a different DAC/audio HAT (card name, sample rate, period size, the mixer-routing step below) if this isn't a WM8960 unit.

**b) The WM8960 codec's own internal mixer routing defaults to OFF**, independent of `/etc/asound.conf` and independent of volume levels. Without this step, `speaker-test`/`aplay` report zero errors and *still produce no audible sound at all* — the digital path works, but the DAC signal never reaches the speaker amp stage. This is the single most likely thing to be missing/forgotten on a fresh setup, since nothing surfaces it as an error:

```bash
amixer -c wm8960soundcard sset 'Left Output Mixer PCM' on
amixer -c wm8960soundcard sset 'Right Output Mixer PCM' on
sudo alsactl store
```

`alsactl store` persists this to `/var/lib/alsa/asound.state`; `alsa-restore.service` (enabled by default on Raspberry Pi OS, confirmed active on `plinkplonk`) re-applies it automatically on every boot — no need to redo this after a reboot, only after a truly fresh setup.

**Verify actual audible sound**, not just clean command output:
```bash
speaker-test -D default -c 2 -t sine -f 440 -l 1
aplay <any .wav file>
```
Two concurrent `speaker-test`/`aplay` processes both playing without error confirms `dmix` sharing works too.

## 7. Sanity check everything above actually works

```bash
cd ~/ChromaCade
python3 -m pytest   # should be 165 passed (as of this writing) with zero
                     # hardware attached -- these are the pure-logic tests
```

## 8. Installing the systemd services

Both service files are tracked in this repo (root-level `chromacade.service` for the main app; `audio/chromacade-boot-chime.service` for the boot chime) but **neither is installed/enabled on `plinkplonk` yet** — this device is still at the bring-up stage, not running either unattended.

**`chromacade.service`'s `ExecStart`/`WorkingDirectory` paths are per-device** — as of 2026-08-20 they'd drifted to unit #1's builder-account path (`/home/shane/ChromaCade`) and needed fixing for unit #2's `/home/plink/ChromaCade`; check they still match whatever device/checkout you're actually installing on before enabling, since this will silently point at a nonexistent path otherwise. `User=root` is deliberate, not a leftover — needed for the LED ring/strip's PWM/DMA access (`neopixel`), see `docs/open-questions.md`'s "dedicated non-root user" entry for the still-open alternative.

```bash
sudo cp ~/ChromaCade/chromacade.service /etc/systemd/system/
sudo cp ~/ChromaCade/audio/chromacade-boot-chime.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now chromacade.service chromacade-boot-chime.service
```

Once enabled, `systemctl status chromacade.service` / `journalctl -u chromacade.service -f` are how to check it's actually running rather than assuming.

Separately, still open per `docs/open-questions.md`'s "Future / stretch" section: full read-only root + overlay-fs, and the dedicated non-root service user mentioned above. Do those *before* depending on this unit for unattended live use, not as part of a basic rebuild.
