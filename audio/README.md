# audio/

Not the audio engine — that's `audio_engine.py`, at the repo root alongside `chromacade.py` and its other supporting modules (see top-level `CLAUDE.md`'s Repo state section). This directory holds audio-related assets and standalone scripts instead:

- `boot_chime.sh` / `chromacade-boot-chime.service` — the boot chime, a separate systemd unit from `chromacade.service` (repo root). Plays `prompts/plinkplonk_theme.wav` (ChromaCade's own theme, as of 2026-08-31) — replaced the earlier 3-way spoken-greeting cycle (`hello`/`whats_up`/`lets_go.wav`, added 2026-08-27); those files are still present but no longer referenced.
- `nopes/` / `yays/` / `prompts/` — recorded Tutor/Simon feedback clips (personal recordings, git-tracked). `sound_pools.py` (repo root) picks which file plays when; see its docstring for the six pools and their rules.
- `play_melody.py` — a standalone script, predates `chromacade.py`.

`brian/core-audio-engine` (PR #1, referenced by an earlier version of this file) was closed without merging — the real `audio_engine.py`/`hardware_poller.py` on `main` today came from a different, direct line of commits starting at `b218fad`, not from that branch. Don't go looking for it; there's nothing to merge from there.
