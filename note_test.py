#!/usr/bin/env python3
"""
ChromaCade -- key-to-note integration test.

First real "press a key, hear a note" test tying the GPIO and audio
subsystems together. Uses pygame.mixer -- the locked audio engine
choice for the real build (see decision-log.md) -- rather than the raw
aplay approach in audio_test.py, since that's what the actual firmware
will use for polyphony.

Mapping (A minor triad):
    Key 1 (GPIO14, pin 8)  -> A4 (440.00 Hz)  -- root
    Key 2 (GPIO15, pin 10) -> C5 (523.25 Hz)  -- minor third
    Key 3 (GPIO25, pin 22) -> E5 (659.25 Hz)  -- perfect fifth
Hold all three together for the chord. Each note sustains while its
key is held and stops (short fadeout, no click) on release -- matching
the real design's "hold to sustain" behavior, not a one-shot pluck.

Prerequisites:
  - pygame installed:
        sudo apt install python3-pygame
    or  pip3 install pygame --break-system-packages
  - Amp #1 wired and confirmed working (audio_test.py already passed).
  - RECOMMENDED: point ALSA's default device at the hifiberry card so
    pygame doesn't need SDL device-name guessing. Create ~/.asoundrc:

        pcm.!default {
            type hw
            card 1
            device 0
        }
        ctl.!default {
            type hw
            card 1
        }

    Without this, pygame.mixer may default to the Pi's HDMI audio
    (card 0) instead -- same failure mode `aplay` hit earlier today,
    before we passed --device hw:1,0 explicitly. This script has no
    --device flag (pygame doesn't take a raw ALSA device string the
    way aplay does), so the .asoundrc fix is the reliable path here.

Usage:
    python3 note_test.py
"""

import array
import math
import time

import pygame
from gpiozero import Button

SAMPLE_RATE = 44100
AMPLITUDE = 0.9  # raised from 0.3 for a deliberate loudness check; GAIN pin wired to GND next as a result -- see "Audio hardware" in open-questions.md
RELEASE_FADE_MS = 15  # short fadeout on release to avoid a click

# BCM pin -> (note name, frequency Hz)
NOTES = {
    14: ("A4", 440.00),
    15: ("C5", 523.25),
    25: ("E5", 659.25),
}


def make_tone_sound(freq: float) -> "pygame.mixer.Sound":
    """Stereo tone buffer, looped seamlessly.

    Picks a whole number of cycles (~50ms worth) and a whole number of
    samples, then re-derives the exact frequency implied by that many
    cycles over that many samples -- a few hundredths of a Hz off
    nominal, inaudible, but it guarantees the waveform closes on an
    exact integer number of periods. Without this correction, rounding
    the sample count leaves a small phase mismatch at the loop
    boundary (audible as a faint tick every ~50ms while a key is held).
    """
    cycles = max(1, round(freq * 0.05))  # ~50ms buffer, whole cycles only
    n_samples = int(round(cycles * SAMPLE_RATE / freq))
    exact_freq = cycles * SAMPLE_RATE / n_samples
    buf = array.array("h")
    for i in range(n_samples):
        sample = int(AMPLITUDE * 32767 * math.sin(2 * math.pi * exact_freq * i / SAMPLE_RATE))
        buf.append(sample)  # left
        buf.append(sample)  # right
    return pygame.mixer.Sound(buffer=buf.tobytes())


def main():
    pygame.mixer.pre_init(frequency=SAMPLE_RATE, size=-16, channels=2, buffer=512)
    pygame.mixer.init()

    try:
        print(f"Mixer initialized: {pygame.mixer.get_init()}")
        names = list(pygame.mixer.get_sdl_audio_device_names(True))
        print(f"SDL sees these playback devices: {names}")
        print("(If this list doesn't clearly show the hifiberry card and")
        print(" you get silence below, set up ~/.asoundrc per the")
        print(" docstring at the top of this file.)")
    except Exception as e:
        print(f"(device introspection unavailable: {e})")

    print()
    print("ChromaCade key-to-note test -- A minor triad")
    print("=" * 60)
    for pin, (name, freq) in NOTES.items():
        print(f"  GPIO{pin:<3} -> {name} ({freq:.2f} Hz)")
    print("=" * 60)
    print("Hold a key for sustain, release to stop. Hold all three")
    print("together for the chord. Ctrl+C to quit.")
    print()

    sounds = {pin: make_tone_sound(freq) for pin, (_, freq) in NOTES.items()}
    channels = {pin: pygame.mixer.Channel(i) for i, pin in enumerate(NOTES)}
    buttons = []

    def make_press(pin, name):
        def _press():
            print(f"PRESS   {name}")
            channels[pin].play(sounds[pin], loops=-1)
        return _press

    def make_release(pin, name):
        def _release():
            print(f"release {name}")
            channels[pin].fadeout(RELEASE_FADE_MS)
        return _release

    for pin, (name, freq) in NOTES.items():
        btn = Button(pin, pull_up=True, bounce_time=0.02)
        btn.when_pressed = make_press(pin, name)
        btn.when_released = make_release(pin, name)
        buttons.append(btn)

    try:
        while True:
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\nExiting.")
        pygame.mixer.quit()


if __name__ == "__main__":
    main()
