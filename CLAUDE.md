# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ChromaCade is a DIY musical learning instrument for toddlers, built around a Raspberry Pi Zero 2 W. It's a *teaching* instrument (note names, octave equivalence, sharp/flat-as-modification, chord color), not a performance instrument — every design/code decision should be judged against whether it helps a small child build musical intuition, not against flexibility or feature count.

The repo is organized by function:
- `docs/` — design/decision docs (philosophy, decision log, feature spec, color palette, open questions, team/task breakdown)
- `hardware/` — electronics-level docs (GPIO pin map, BOM, control layout)
- `enclosure/` — the OpenSCAD case model, its printable assets, and case-specific fit-test plates
- `testing/` — hardware bring-up/bench-test scripts and session test-plan docs
- `audio/` — currently just a placeholder (see `audio/README.md`); the real audio engine is on a separate branch (`brian/core-audio-engine`, PR #1) pending review, not merged here yet

No application/firmware Python code exists yet (see Repo state below) — `.github/workflows/tests.yml` runs `pytest` on every PR in anticipation of that code landing.

## Repo state (read this before assuming code exists)

- The application/firmware code — the audio engine, color system, and menu state machine described in the design docs — is still unwritten. What exists under `testing/` (`note_buttons_test.py`, `audio_test.py`, `note_test.py`) is hardware bring-up/bench-test tooling from initial GPIO+amp validation (run manually on the Pi against real hardware), not the real app, and not `pytest`-discoverable — there's no `requirements.txt` or package structure yet for actual firmware.
- The only buildable artifacts today are the OpenSCAD case files in `enclosure/` and the exported `enclosure/chromacade-housing.stl`. `enclosure/printsettings` is a trimmed settings-diff from the Cura-generated G-code for an ELEGOO Neptune 3 Pro print (not the full ~80MB toolpath — GitHub rejects that size), not a portable slicer profile for other printers/materials.
- If asked to implement a software track (audio, color-chord blending, menu state machine), there is no existing code to extend — start fresh per the relevant spec doc in `docs/`/`hardware/`, and keep logic in plain, hardware-free/testable functions (GPIO/hardware calls should be a thin layer on top) so it fits the `pytest` CI gate in `CONTRIBUTING.md`.

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

**Tests**: no `pytest` suite exists yet — the scripts under `testing/` are manual hardware bring-up tools (require real GPIO/amp hardware, not CI-safe), not what CI runs. `pytest.ini` excludes `testing/` from collection so those scripts' `gpiozero`/`pygame` imports don't break CI on a runner with no hardware libs installed; the workflow also tolerates pytest's exit code 5 ("no tests collected") so CI can stay green with zero application tests, without masking real failures or collection errors. Once Python application code is added under a testable package, `pytest` (bare, no args) is what CI runs — see `.github/workflows/tests.yml`.

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
- **`docs/chromacade-overview-and-tasks.md`** / **`docs/task-breakdown.md`** — team structure and workstream split (hardware/case CAD is Shane's track; audio engine, display/color, and menu/Simon-mode are the software tracks).

`testing/chromacade-hardware-test-plan-2026-07-20.md` documents a specific bring-up session (3-key test mount + amp #1) rather than a standing spec doc — useful for wiring history, but check `hardware/gpio-pin-assignments.md` and `docs/decision-log.md` for what's actually current.

## Conventions worth preserving

- Dimensions in the `.scad` files mix inches (via `in2mm = 25.4`) for panel-level dimensions with millimeters for hardware cutout details — keep this pattern rather than converting everything to one unit.
- `wall = 5` (mm) is treated as a load-bearing constant across the `enclosure/` housing/back-panel/test files — it's referenced both for shell thickness and for computing cutout depths (e.g. countersink depths are expressed as `wall - x`). Changing it has ripple effects.
- MX switch cutouts require an exact ~1.5mm engagement layer thickness for the clips to snap — this is called out explicitly in `enclosure/test-component-holes.scad` as intentional; don't "fix" it to match general wall thickness.
