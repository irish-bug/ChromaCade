#!/usr/bin/env python3
"""
ChromaCade — MAX98357A amp bring-up tone test.

Run this AFTER:
  1. Amp #1 is wired: BCLK->GPIO18(pin12), LRC->GPIO19(pin35),
     DIN->GPIO21(pin40), GND->any Pi GND, VIN->5V. (Amp #2, whenever
     it's soldered, shares these same three pins -- no rewiring or
     config changes needed when you add it.)
  2. SD_MODE is resolved per chromacade-hardware-test-plan-2026-07-20.md
     (either the board's onboard pull-up, or your added 1M resistor to
     VIN) -- NOT wired to a GPIO, and NOT GPIO4 (that's note button A).
  3. /boot/firmware/config.txt has:
         dtparam=i2s=on
         dtoverlay=hifiberry-dac
     ...and you've rebooted since adding it.

Deliberately uses only the Python standard library (wave + math) and
shells out to `aplay` -- no pip installs needed on the bench, and it
isolates raw ALSA/hardware correctness before layering pygame.mixer
on top.

Usage:
    python3 audio_test.py
    python3 audio_test.py --freq 440 --seconds 2 --device hw:0,0
"""

import argparse
import math
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 44100
AMPLITUDE = 0.3  # conservative on purpose -- hardware smoke test, not a max-volume check


def check_aplay_available():
    if shutil.which("aplay") is None:
        print("ERROR: `aplay` not found. Install alsa-utils:")
        print("    sudo apt install alsa-utils")
        sys.exit(1)


def list_playback_devices():
    print("Detected playback devices (aplay -l):")
    print("-" * 60)
    try:
        result = subprocess.run(
            ["aplay", "-l"], capture_output=True, text=True, timeout=10
        )
        print(result.stdout.strip() or "(no output)")
        if "sndrpihifiberry" not in result.stdout and "hifiberry" not in result.stdout.lower():
            print()
            print("WARNING: no hifiberry-style card detected. If this is")
            print("your first boot since editing config.txt, confirm you")
            print("edited /boot/firmware/config.txt and rebooted. If the")
            print("card still doesn't show, that's an I2S wiring/overlay")
            print("issue -- fix that before chasing SD_MODE or speaker wiring.")
    except FileNotFoundError:
        print("ERROR: aplay not found even after which() check passed -- odd.")
        sys.exit(1)
    print("-" * 60)


def generate_tone_wav(path: Path, freq: float, seconds: float):
    """Stereo WAV, identical tone on both channels.

    Most Pi I2S DAC ALSA devices (hifiberry-dac included) are fixed at
    2-channel playback -- a mono WAV fed straight to the raw hw: device
    can fail on a channel-count mismatch. Writing stereo here sidesteps
    that regardless of which ALSA device ends up handling playback. The
    MAX98357A still does its own (Left+Right)/2 mono mix per SD_MODE, so
    this doesn't change what comes out of the speaker -- with one amp
    wired you'll hear it from that one speaker; add amp #2 later and
    both play the identical mix, same as before.
    """
    n_samples = int(SAMPLE_RATE * seconds)
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for i in range(n_samples):
            # short fade-in/out to avoid a click at start/end
            fade_len = int(SAMPLE_RATE * 0.02)
            if i < fade_len:
                env = i / fade_len
            elif i > n_samples - fade_len:
                env = (n_samples - i) / fade_len
            else:
                env = 1.0
            sample = AMPLITUDE * env * math.sin(2 * math.pi * freq * i / SAMPLE_RATE)
            packed = struct.pack("<h", int(sample * 32767))
            frames += packed * 2  # L, R -- identical
        wf.writeframes(bytes(frames))


def play_wav(path: Path, device: str | None):
    cmd = ["aplay"]
    if device:
        cmd += ["-D", device]
    cmd.append(str(path))
    print(f"Playing: {' '.join(cmd)}")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print()
        print("aplay exited non-zero. If the card showed up in `aplay -l`")
        print("but this failed, try passing --device explicitly, e.g.")
        print("    python3 audio_test.py --device hw:0,0")


def confirm_speakers():
    """Interactive pass/fail check -- meaningful now that amp #2 exists:
    both amps get identical mono content, so "which speaker(s) played"
    is the actual verification, not just whether aplay exited cleanly.
    """
    print()
    try:
        answer = input("Did you hear the tone from BOTH speakers? [y/n/one]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("(no input available -- skipping confirmation)")
        return
    if answer.startswith("y"):
        print("PASS -- both amps confirmed audible.")
    elif answer.startswith("o"):
        print("PARTIAL -- only one speaker heard. Since both amps share the same")
        print("BCLK/LRC/DIN pins (12/35/40), the shared bus is presumably fine --")
        print("check the silent amp's own SD_MODE resistor, VIN/GND, and speaker")
        print("wire polarity first.")
    else:
        print("FAIL -- no sound confirmed. Re-check `aplay -l` above, SD_MODE")
        print("voltage on each amp, and BCLK/LRC/DIN continuity to pins 12/35/40.")


def main():
    parser = argparse.ArgumentParser(description="ChromaCade amp tone test")
    parser.add_argument("--freq", type=float, default=440.0, help="tone frequency in Hz (default 440 = A4)")
    parser.add_argument("--seconds", type=float, default=1.5, help="tone duration in seconds")
    parser.add_argument("--device", type=str, default=None, help="ALSA device, e.g. hw:0,0 (default: system default)")
    parser.add_argument("--skip-list", action="store_true", help="skip the aplay -l device listing")
    parser.add_argument("--skip-confirm", action="store_true", help="skip the interactive both-speakers y/n check")
    args = parser.parse_args()

    check_aplay_available()

    if not args.skip_list:
        list_playback_devices()
        print()

    tone_path = Path("/tmp/chromacade_test_tone.wav")
    print(f"Generating {args.freq:.1f} Hz tone, {args.seconds}s, amplitude={AMPLITUDE} "
          f"(intentionally conservative -- this is a hardware smoke test, not a volume check)")
    generate_tone_wav(tone_path, args.freq, args.seconds)

    play_wav(tone_path, args.device)

    print()
    print("With both amps wired (they share BCLK/LRC/DIN -- pins 12/35/40),")
    print("expect the identical mono tone from both speakers at once.")
    print("If you get silence:")
    print("  1. Re-check `aplay -l` output above for the hifiberry card.")
    print("  2. Check SD_MODE voltage on the silent amp with a multimeter --")
    print("     should read ~0.16-0.77V (mono-mix band per datasheet).")
    print("  3. Re-check BCLK/LRC/DIN continuity to pins 12/35/40.")
    print("If you get a click/pop but no sustained tone, that's usually")
    print("SD_MODE sitting in the wrong voltage band rather than a data-line issue.")

    if not args.skip_confirm:
        confirm_speakers()


if __name__ == "__main__":
    main()
