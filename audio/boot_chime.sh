#!/bin/bash
# ChromaCade -- boot-ready chime.
# Plays once at boot to signal the device has finished starting up.
# Cycles through audio/prompts/{hello,whats_up,lets_go}.wav, one per
# boot -- requested 2026-08-27, a single fixed clip (yays/yuss.wav, the
# fix immediately before this one) felt repetitive. True cycling
# (remembers which one played last via a small state file under
# /var/lib/chromacade/, not this repo checkout -- mutable runtime state
# doesn't belong in a git working tree), not random.choice, matching
# this project's established preference (see sound_pools.py's Cycler
# docstring) for no back-to-back repeats and even airtime. Unlike
# Cycler, this can't just hold the index in memory -- this script is a
# fresh process every boot, not part of the long-running chromacade.py
# process -- so the index has to persist to disk between runs.
#
# Was the Zelda Navi "Hello!" clip (audio/zelda/, gitignored third-party
# audio -- see grab_navi_sounds.sh/.gitignore's "copyrighted sound assets"
# note) -- switched 2026-08-26 to a single yays/yuss.wav (already
# git-tracked) after finding the Zelda clip only ever existed on unit #1
# and was never carried over to plinkplonk or committed anywhere -- this
# service failed every boot until that changed (confirmed via a real
# reboot, not just one manual run).

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
prompts=("$script_dir/prompts/hello.wav" "$script_dir/prompts/whats_up.wav" "$script_dir/prompts/lets_go.wav")

# Writable by this service's own user (root -- see
# chromacade-boot-chime.service's User=) without touching the repo
# checkout. Index validated (plain non-negative int, in range) rather
# than trusted outright -- a corrupted/stale state file (e.g. left over
# from a smaller prompts list) falls back to index 0 instead of
# crashing this non-critical boot notification.
state_file="/var/lib/chromacade/boot_chime_index"
mkdir -p "$(dirname "$state_file")"

index=0
if [ -f "$state_file" ]; then
    saved="$(cat "$state_file")"
    if [[ "$saved" =~ ^[0-9]+$ ]] && [ "$saved" -lt "${#prompts[@]}" ]; then
        index="$saved"
    fi
fi

next_index=$(( (index + 1) % ${#prompts[@]} ))
echo "$next_index" > "$state_file"

aplay "${prompts[$index]}"
