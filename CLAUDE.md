# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ChromaCade is a DIY musical learning instrument for toddlers, built around a Raspberry Pi 4B (unit #1 was a Pi Zero 2 W but is no longer available; unit #2, hostname `plinkplonk`, is the current build — see `docs/decision-log.md`'s "Platform / compute" section). It's a *teaching* instrument (note names, octave equivalence, sharp/flat-as-modification, chord color), not a performance instrument — every design/code decision should be judged against whether it helps a small child build musical intuition, not against flexibility or feature count.

The repo is organized by function:
- `docs/` — design/decision docs (philosophy, decision log, feature spec, color palette, open questions, team/task breakdown)
- `hardware/` — electronics-level docs (GPIO pin map, BOM, control layout)
- `enclosure/` — the OpenSCAD case model, its printable assets, and case-specific fit-test plates
- `testing/` — hardware bring-up/bench-test scripts and session test-plan docs, separate from the real application code below
- `audio/` — real, tracked assets and scripts: the boot chime (`boot_chime.sh`, `chromacade-boot-chime.service`), recorded Tutor/Simon feedback clips (`nopes/`, `yays/`, both git-tracked personal recordings), and `play_melody.py`. Not the audio *engine* — that's `audio_engine.py` at the repo root (see below); see `audio/README.md`.

The application/firmware code is written and real (see Repo state below) — `.github/workflows/tests.yml` runs `pytest` on every PR against a real, passing test suite, not in anticipation of one.

## Repo state (read this before assuming code doesn't exist — it does)

- **The real app lives at the repo root, not under a package directory.** `chromacade.py` is the unified app (Play mode, the mode/song menu, Tutor mode, and Simon Says, all in one persistent process — this is what actually runs on the device day to day, see its own docstring for why one process not several) plus its supporting modules, also at the repo root: `audio_engine.py` (note math + FluidSynth playback), `hardware_poller.py` (GPIO → callbacks), `menu.py` (mode/song/sequence navigation), `tutor_mode.py`/`tutor_songs.py` (Tutor sub-mode + song data), `simon_sequences.py` (Simon Says sub-mode), `sound_pools.py` (nope/yay feedback clip selection), `led_ring.py`/`led_strip.py`, `oled_display.py`, `octave_gesture.py`. `play.py` (the original standalone play-notes script, predates `chromacade.py`) still exists too — kept intentionally as a standalone dev/test tool that bypasses the menu, not dead code; see its docstring and `chromacade.py`'s docstring for the relationship.
- **A real `pytest` suite exists and passes**: `test_audio_engine.py`, `test_menu.py`, `test_octave_gesture.py`, `test_simon_sequences.py`, `test_sound_pools.py`, `test_tutor_songs.py` (repo root, alongside the modules they test) — 165 tests as of 2026-08-20, run with a bare `pytest`. These cover the hardware-free logic each module deliberately isolates (note math, menu state transitions, song sequencing, etc.) — see e.g. `audio_engine.py`'s docstring for how it draws the line between what's unit-testable and what needs real hardware (`ChromaCadeAudio` wraps FluidSynth and isn't unit tested for that reason, same as `hardware_poller.py`).
- **`testing/` is a separate, different thing** — hardware bring-up/bench-test tooling (requires real GPIO/amp hardware, not CI-safe; `pytest.ini`'s `norecursedirs = testing` excludes it from collection for exactly that reason). Don't confuse it with the real application code above.
- **Still missing: no `requirements.txt` or package structure exists anywhere in this repo**, despite the real code depending on several third-party packages (FluidSynth bindings, gpiozero, the Adafruit CircuitPython/Blinka stack, Pillow, etc.). `docs/device-rebuild-guide.md` (as of 2026-08-20, on branch `plonk/device-rebuild-guide`, not yet merged to `main`) is currently the only record of the real dependency list — treat it as the source of truth for what to install until a real `requirements.txt` exists.
- The other buildable artifacts are the OpenSCAD case files in `enclosure/` and their exported STLs — see Architecture below for the current file set (`enclosure/` has had more churn than this file's Architecture section may reflect at any given moment; check `enclosure/*.scad`'s own headers and `docs/decision-log.md` if something looks inconsistent). `enclosure/printsettings` is a trimmed settings-diff from the Cura-generated G-code for an ELEGOO Neptune 3 Pro print (not the full ~80MB toolpath — GitHub rejects that size), not a portable slicer profile for other printers/materials.
- If asked to implement or extend a software track (audio, color-chord blending, menu state machine, Simon Says, etc.), **read the relevant module(s) above first, not just the design docs** — the design docs describe intent and rationale, the code is what's actually running and may have made judgment calls the docs don't mention (e.g. `chromacade.py`'s docstring has a whole "ASSUMPTIONS / JUDGMENT CALLS MADE WITHOUT ASKING" section). Keep new logic in the same pattern already established: plain, hardware-free/testable functions with GPIO/hardware calls as a thin layer on top, so it fits the `pytest` CI gate in `CONTRIBUTING.md`.

## Commands

**OpenSCAD** (installed at `/usr/bin/openscad`, v2021.01):
```bash
# Render the current housing (wordmark-embossed variant) to STL
openscad -o enclosure/chromacade-housing-embossed.stl enclosure/chromacade-housing-embossed.scad

# Render the plain (no-wordmark) housing, kept until the embossed print is validated
openscad -o enclosure/chromacade-housing.stl enclosure/chromacade-housing.scad

# Render a specific file (e.g. test plates, back panel, grille inserts) to check syntax/geometry
openscad -o /tmp/out.stl enclosure/chromacade-back-panel.scad
openscad -o /tmp/out.stl enclosure/test-mk2.scad

# Open the GUI preview for interactive iteration
openscad enclosure/chromacade-housing-embossed.scad
```
There's no build script — each `.scad` file under `enclosure/` is a standalone entry point (see Architecture below); render the specific file you're working on.

**Tests**: `pytest` (bare, no args) runs the real suite — 165 tests as of 2026-08-20, all passing, covering `chromacade.py`'s supporting modules (see Repo state above). The scripts under `testing/` are a separate thing: manual hardware bring-up tools (require real GPIO/amp hardware, not CI-safe), not what CI runs. `pytest.ini`'s `norecursedirs = testing` excludes that directory from collection so those scripts' `gpiozero`/`pygame` imports don't break CI on a runner with no hardware libs installed. `.github/workflows/tests.yml`'s `pytest || [ "$?" -eq 5 ]` fallback (exit 5 = "no tests collected") is now just a defensive no-op for the case collection ever legitimately drops to zero again — it's not the expected/normal outcome anymore, real tests collect and run on every PR.

## Branching & PR workflow

Main is protected. For every task: branch off `main` as `yourname/short-task-description`, commit there, open a PR into `main`. Keep PRs scoped to one task. See `CONTRIBUTING.md` for full details — this is a hard rule for this repo, not a suggestion.

## Syncing the physical board after a push

`chromacade` is an SSH host alias (see `~/.ssh/config`) for the physical Pi running this build; it has its own separate git checkout of this repo at `/home/shane/ChromaCade/`. After pushing commits to GitHub (a branch push, a merge, etc.), SSH there and `git pull` to keep that checkout in sync — but only if it's safe:
- Check `git status --short` on `chromacade` first — if the working tree there is dirty (e.g. uncommitted bench-test edits), stop and flag it rather than pulling over local changes.
- Confirm the branch checked out there is actually meant to track what was just pushed (`git status --branch` / `git rev-parse --abbrev-ref HEAD`) before assuming `git pull` is a no-op-safe fast-forward — don't assume it's on `main` or on whatever branch the push was to.

## Architecture: the OpenSCAD case model

The case is an **arcade-cabinet profile**: a 2D cross-section (front-to-back) is extruded across the case width, then hollowed out and cut with hardware openings. Each `.scad` file (all under `enclosure/`) is independently renderable (not `include`d by one another) — they share the same dimension constants by copy-paste, which is a known deliberate tradeoff, not an oversight (see git history: "Completely unlinked standalone files", "Revert to monolithic file with export toggles"). **When changing a shared dimension (`case_w`, `case_d`, `wall`, `front_h`, `shelf_d`, `shelf_a`, `panel_l`, `panel_a`), update it in every file that redeclares it** — currently `enclosure/chromacade-housing.scad`, `enclosure/chromacade-back-panel.scad`, and `enclosure/chromacade-housing-embossed.scad` all carry the full dimension block.

Files (all under `enclosure/`):
- `chromacade-housing.scad` — the main chassis: builds the 2D profile (`p0`..`p5`) from the dimension constants, extrudes it across `case_w`, shells it by `wall` thickness, cuts the back opening, adds corner/center mounting bosses, and cuts all hardware openings (speaker grilles, shelf controls, panel controls, side-panel hole) via `hardware_cutouts()`. Kept around only until the embossed variant's wordmark print is validated on real hardware — `chromacade-housing-embossed.scad` below is the current, actively-developed model.
- `chromacade-back-panel.scad` — the separate back cover plate that screws into the mounting bosses; recomputes the same profile geometry to derive its own outline and boss-hole positions.
- `chromacade-housing-embossed.scad` — **the current primary housing model.** Wordmark variant of the main housing: identical geometry plus a raised "ChromaCade" emboss on the panel exterior between the OLED and LED ring. Kept as a separate standalone file rather than a toggle, same rationale as the rest of this file split (see `docs/decision-log.md`). The letter outlines are embedded as literal polygon data (converted from `ChromaCade-wordmark-paths.svg`, kept in-repo as the source asset) rather than `import()`-ed at render time, so this file needs no external file access or fonts to render — an earlier `text()`-based emboss needed the Comfortaa font, which OpenSCAD couldn't reliably reproduce, hence the switch to traced polygon paths.
- `test-component-holes.scad` / `test-mk2.scad` — small multi-plate fit-test files for validating individual hardware cutout dimensions (encoder bushing, joystick, rocker switch, OLED, LED ring, MX switch clip depth, speaker grille) on real hardware *before* committing to a full-case print. `test-mk2.scad` supersedes the cutouts revised since `test-component-holes.scad` — check its header comment for which plates are newer. Print these when changing any hole dimension; don't assume a dimension is correct without a fit test noted in the file's comments or `docs/decision-log.md`.

The cross-section is built from six points (`p0`..`p5`) computed via trig off the angle/length constants (`shelf_a`, `panel_a`, `panel_l`, `shelf_d`, `front_h`) — front foot → vertical front wall → tilted shelf → 45°-angled main panel → vertical back wall. `case_h` is *derived* from this chain (it's `p4[1]`), not set directly — changing any upstream angle/length shifts the overall case height. `hardware_cutouts()` locates each control by re-deriving the same segment midpoints (e.g. `shelf_my`/`shelf_mz`, `panel_my`/`panel_mz`) and rotating into that segment's local frame before placing holes — this is how holes stay correctly positioned on sloped/angled faces as dimensions change.

## Design documents — read before changing the model or planning features

These aren't background reading; they encode already-made decisions. Check `docs/decision-log.md` before proposing something that sounds like an obvious simplification — many "obvious" alternatives (AAA batteries, a button matrix, per-button LEDs, a plain long-press menu gesture, MCP3008 over ADS1115, a `dtoverlay=max98357a` device-tree overlay, a Python venv, etc.) were already tried or considered and explicitly rejected for stated reasons.

- **`docs/design-philosophy.md`** — the evaluation lens (teaching > performance, chunky > compact, color-as-theory, parent-friction-by-design, two-handed workflow). Use this to judge whether a proposed change fits the project.
- **`docs/decision-log.md`** — rejected paths and why, across platform/compute, power, controls, LED/color, case geometry, menu/mode design, software setup, and sourcing. Read before re-suggesting an alternative approach.
- **`docs/feature-spec.md`** — normal play mode behavior, the color-chord blending problem (compress 7 letters into a narrow hue arc, ~180–250°, rather than full-rainbow spacing, since analogous hues blend cleanly but complementary hues wash to gray), and Simon/Learn mode (tutor vs. memory sub-modes).
- **`docs/color-palette.md`** — candidate hex values for the note key colors. Letter-to-color assignment and chord-blend validation are still open (see `docs/open-questions.md`).
- **`hardware/control-layout.md`** — physical control zones and the menu entry/exit gesture grammar (font-encoder-hold + long-press A/G, chosen specifically to be safe against toddler note-mashing).
- **`enclosure/case-design.md`** — the cross-section rationale and rough dimensions referenced by the `.scad` files above.
- **`hardware/gpio-pin-assignments.md`** — locked-in BCM pin map; note GPIO12 (not GPIO18) for the WS2812 ring data line, GPIO9/10/11 repurposed from unused SPI, and GPIO14/15/25 as the current bench-test-mount pins (not the final note-button pins).
- **`hardware/hardware-bom.md`** — sourced parts, quantities (sized for a 4-unit build), and known connector/fit mismatches (e.g. speaker JST connectors need bare-wire splicing to the amp's screw terminals).
- **`docs/open-questions.md`** — unresolved decisions (hue arc width, chord color priority, menu structure, case lid/access panel, amp GAIN pin tuning). Check here before assuming something is finalized; move items out of this file into the relevant spec doc once resolved, don't just answer them in code silently. Its "Future / stretch" section also holds next-build OS-imaging decisions deliberately deferred past unit #1 (full read-only root + overlay-fs for SD card corruption resistance, a dedicated non-root service user) — read those before imaging a new unit's SD card, and write the actual how-to there (and update this file to point at it) once that work happens, rather than doing it ad hoc.
- **`docs/chromacade-overview-and-tasks.md`** / **`docs/task-breakdown.md`** — the original team structure/workstream proposal (hardware/case CAD as Shane's track; audio engine, display/color, and menu/Simon-mode as the software tracks). Written before any of the software tracks existed — per Repo state above, all three are now substantially built, so treat these two docs as historical planning record, not an accurate map of what's still open. Check the real modules first for current status.

`testing/chromacade-hardware-test-plan-2026-07-20.md` documents a specific bring-up session (3-key test mount + amp #1) rather than a standing spec doc — useful for wiring history, but check `hardware/gpio-pin-assignments.md` and `docs/decision-log.md` for what's actually current.

## Conventions worth preserving

- Dimensions in the `.scad` files mix inches (via `in2mm = 25.4`) for panel-level dimensions with millimeters for hardware cutout details — keep this pattern rather than converting everything to one unit.
- `wall = 5` (mm) is treated as a load-bearing constant across the `enclosure/` housing/back-panel/test files — it's referenced both for shell thickness and for computing cutout depths (e.g. countersink depths are expressed as `wall - x`). Changing it has ripple effects.
- MX switch cutouts require an exact ~1.5mm engagement layer thickness for the clips to snap — this is called out explicitly in `enclosure/test-component-holes.scad` as intentional; don't "fix" it to match general wall thickness.
