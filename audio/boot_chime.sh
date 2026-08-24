#!/bin/bash
# ChromaCade -- boot-ready chime.
# Plays once at boot to signal the device has finished starting up.
# The .wav itself is gitignored (third-party audio, not committed) --
# see grab_navi_sounds.sh and .gitignore's "copyrighted sound assets" note.

sleep 5  # let ALSA/audio hardware finish initializing, same margin nektar-synth uses
# No -D plughw:1,0 (removed 2026-08-16) -- that's exclusive hardware
# access, and this service now starts around the same time as
# chromacade.service (added today), which holds the shared dmix-backed
# `default` PCM open for its whole life. Confirmed live: this failed
# every boot with "audio open error: Unknown error 524" (EBUSY) once
# both services existed. Same fix already applied to sound_pools.py's
# play_wav() for the exact same reason -- see that module's docstring.
#
# Path derived from this script's own location, not hardcoded to any one
# device/user's home directory -- found hardcoded to unit #1's builder
# path (/home/shane/ChromaCade) 2026-08-24, broke the boot chime outright
# on plinkplonk (a different user, plink). This script lives in audio/,
# one level below the repo root.
script_dir="$(cd "$(dirname "$0")" && pwd)"
aplay "$script_dir/zelda/OOT_Navi_Hello1.wav"
