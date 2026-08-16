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
aplay /home/shane/ChromaCade/audio/zelda/OOT_Navi_Hello1.wav
