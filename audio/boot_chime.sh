#!/bin/bash
# ChromaCade -- boot-ready chime.
# Plays once at boot to signal the device has finished starting up.
# Plays audio/prompts/plinkplonk_theme.wav -- ChromaCade's own theme,
# offline-rendered from the PlinkPlonk wordmark's confirmed melody
# (Toy Piano voice, see tutor_songs.py's "plink_the_plonks" entry for
# the same tune as a playable song). Replaces the earlier 3-way spoken-
# greeting cycle (hello/whats_up/lets_go.wav, added 2026-08-27) as of
# 2026-08-31 -- direct instruction, once the theme itself was confirmed
# on real hardware. Those three files are still git-tracked but no
# longer referenced by this script.
#
# History before that: was the Zelda Navi "Hello!" clip (audio/zelda/,
# gitignored third-party audio -- see grab_navi_sounds.sh/.gitignore's
# "copyrighted sound assets" note) -- switched 2026-08-26 to a single
# yays/yuss.wav after finding the Zelda clip only ever existed on unit
# #1 and was never carried over to plinkplonk or committed anywhere --
# this service failed every boot until that changed (confirmed via a
# real reboot, not just one manual run).

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

aplay "$script_dir/prompts/plinkplonk_theme.wav"
