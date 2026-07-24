#!/bin/bash
# ChromaCade -- boot-ready chime.
# Plays once at boot to signal the device has finished starting up.
# The .wav itself is gitignored (third-party audio, not committed) --
# see grab_navi_sounds.sh and .gitignore's "copyrighted sound assets" note.

sleep 5  # let ALSA/audio hardware finish initializing, same margin nektar-synth uses
aplay -D plughw:1,0 /home/shane/ChromaCade/audio/OOT_Navi_Hello1.wav
