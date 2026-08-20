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

## 2. Boot config — WM8960 Audio HAT

Add to `/boot/firmware/config.txt` (the rest of that file's contents are stock Raspberry Pi OS defaults — camera/display auto-detect, `vc4-kms-v3d`, etc. — leave those alone):

```
dtparam=i2c_arm=on
dtparam=i2s=on
dtoverlay=wm8960-soundcard
```

Then reboot. Current Raspberry Pi OS (kernel 6.18.x) ships `wm8960-soundcard.dtbo` as a stock overlay — no vendor install script/DKMS module needed, despite what older WM8960 setup guides say. Verify: `aplay -l` should show `card N: wm8960soundcard`; `sudo i2cdetect -y 1` should show the codec responding at `0x1a`.

## 3. System packages (apt)

```bash
sudo apt update
sudo apt install -y \
    python3-pytest python3-gpiozero python3-pil python3-pygame \
    python3-smbus python3-smbus2 i2c-tools alsa-utils
```

All of these are Debian-packaged — no `pip`/PEP 668 fighting needed for this group. (`python3-pytest` pulls in `python3-iniconfig`/`python3-pluggy` automatically.)

## 4. Python packages (pip) — the Adafruit CircuitPython stack

Not available via apt. This device's Python (3.13.5) enforces PEP 668 ("externally-managed-environment"), so a plain `pip3 install` is refused — use `--break-system-packages` (standard, Adafruit's own documented approach for this exact class of device, not a hack specific to this project):

```bash
pip3 install --break-system-packages \
    adafruit-blinka \
    adafruit-circuitpython-ads1x15 \
    adafruit-circuitpython-ssd1306 \
    adafruit-circuitpython-neopixel
```

This provides `board`, `busio`, `neopixel`, `adafruit_ads1x15.*`, `adafruit_ssd1306` — needed for the ADS1115 (joystick analog read), the SSD1306 OLED, and the WS2812 LED ring/strip, respectively. `neopixel`/WS2812 driving needs root (PWM/DMA access) — matches `chromacade.service` running as root (see `docs/decision-log.md`).

**Full verification** (confirmed clean on `plinkplonk` after the above):
```bash
python3 -c "import pytest, gpiozero, PIL, pygame, board, busio, neopixel, adafruit_ads1x15.ads1115, adafruit_ads1x15.analog_in, adafruit_ssd1306"
```

There is still no `requirements.txt` anywhere in this repo (checked, doesn't exist) — this doc is currently the only record of the real dependency list. Worth turning this section into one at some point rather than relying on this doc staying in sync by hand.

## 5. Audio: `/etc/asound.conf` and mixer routing

The overlay alone (§2) is not sufficient — two more things are needed, found by trial on `plinkplonk` 2026-08-19/20:

**a) `/etc/asound.conf` does not exist by default** and must be created (`sudo`, then paste this exact content — this is the live, verified file from `plinkplonk`, not a draft):

```
# ChromaCade -- WM8960 Audio HAT default ALSA routing (plinkplonk, unit #2)
# System-wide (not ~/.asoundrc) so it applies under systemd services too --
# see docs/decision-log.md's ALSA-config convention. Named by card name
# (wm8960soundcard), not index, so it survives card-index shifts across
# reboots. dmix lets multiple processes (main app, boot chime, etc.) share
# the one hardware device; softvol gives a single "PCM" volume knob
# independent of this codec's many hardware mixer controls (Speaker,
# Headphone, Playback Volume, ...) -- amixer/alsamixer users should adjust
# the "PCM" simple control, not the WM8960's own "Speaker" control, for the
# default device's volume.

pcm.wm8960hw {
    type hw
    card wm8960soundcard
}

pcm.dmixer {
    type dmix
    ipc_key 1024
    ipc_perm 0666
    slave {
        pcm "wm8960hw"
        period_time 0
        period_size 1024
        buffer_size 8192
        rate 44100
        channels 2
    }
}

ctl.dmixer {
    type hw
    card wm8960soundcard
}

pcm.softvol {
    type softvol
    slave.pcm "dmixer"
    control.name "PCM"
    control.card wm8960soundcard
}

ctl.softvol {
    type hw
    card wm8960soundcard
}

pcm.!default {
    type plug
    slave.pcm "softvol"
}

ctl.!default {
    type hw
    card wm8960soundcard
}
```

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

## 6. Repo checkout

```bash
git clone https://github.com/irish-bug/ChromaCade.git ~/ChromaCade
cd ~/ChromaCade
git checkout plinkplonk   # or whatever branch is current -- check CLAUDE.md's
                          # "Syncing the physical board" section before assuming
```

**Sanity check everything above actually works:**
```bash
cd ~/ChromaCade
python3 -m pytest   # should be 165 passed (as of this writing) with zero
                     # hardware attached -- these are the pure-logic tests
```

## 7. Not yet done as of this writing (bring-up stage, not base-system gaps)

- `audio/chromacade-boot-chime.service` exists as a file in the repo but is not installed/enabled as a real systemd unit on `plinkplonk` yet (`sudo cp audio/chromacade-boot-chime.service /etc/systemd/system/ && sudo systemctl enable --now chromacade-boot-chime.service`, once ready).
- `chromacade.service` itself (the main app, running persistently) is not set up on `plinkplonk` yet either — unit #1's now-lost systemd unit is the reference for what this should look like (root, `Restart=on-failure`, see `docs/decision-log.md`/project history).
- Full read-only root + overlay-fs, and a dedicated non-root service user: both deliberately deferred, see `docs/open-questions.md`'s "Future / stretch" section — do those *before* depending on this unit for unattended live use, not as part of a basic rebuild.
