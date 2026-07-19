# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ChromaCade is a DIY musical learning instrument for toddlers, built around a Raspberry Pi Zero 2 W. It's a *teaching* instrument (note names, octave equivalence, sharp/flat-as-modification, chord color), not a performance instrument — every design/code decision should be judged against whether it helps a small child build musical intuition, not against flexibility or feature count.

The repo currently holds **design documents and the OpenSCAD case model**. No Python/firmware source exists yet (see Repo state below) — `.github/workflows/tests.yml` runs `pytest` on every PR in anticipation of that code landing.

## Repo state (read this before assuming code exists)

- No `.py` files, no `requirements.txt` yet. The audio engine, color system, and menu state machine described in the design docs are all still unwritten.
- The only buildable artifacts today are the OpenSCAD case files and the exported `chromacade.stl`.
- If asked to implement a software track (audio, color-chord blending, menu state machine), there is no existing code to extend — start fresh per the relevant spec doc below, and keep logic in plain, hardware-free/testable functions (GPIO/hardware calls should be a thin layer on top) so it fits the `pytest` CI gate in `CONTRIBUTING.md`.

## Commands

**OpenSCAD** (installed at `/usr/bin/openscad`, v2021.01):
```bash
# Render the main housing to STL
openscad -o chromacade.stl chromacade-housing.scad

# Render a specific file (e.g. test plates, back panel, grille inserts) to check syntax/geometry
openscad -o /tmp/out.stl chromacade-back-panel.scad
openscad -o /tmp/out.stl test-mk2.scad

# Open the GUI preview for interactive iteration
openscad chromacade-housing.scad
```
There's no build script — each `.scad` file is a standalone entry point (see Architecture below); render the specific file you're working on.

**Tests**: no test suite exists yet. Once Python code is added under a testable package, `pytest` (bare, no args) is what CI runs — see `.github/workflows/tests.yml`.

## Branching & PR workflow

Main is protected. For every task: branch off `main` as `yourname/short-task-description`, commit there, open a PR into `main`. Keep PRs scoped to one task. See `CONTRIBUTING.md` for full details — this is a hard rule for this repo, not a suggestion.

## Architecture: the OpenSCAD case model

The case is an **arcade-cabinet profile**: a 2D cross-section (front-to-back) is extruded across the case width, then hollowed out and cut with hardware openings. Each `.scad` file is independently renderable (not `include`d by one another) — they share the same dimension constants by copy-paste, which is a known deliberate tradeoff, not an oversight (see git history: "Completely unlinked standalone files", "Revert to monolithic file with export toggles"). **When changing a shared dimension (`case_w`, `case_d`, `wall`, `front_h`, `shelf_d`, `shelf_a`, `panel_l`, `panel_a`), update it in every file that redeclares it** — currently `chromacade-housing.scad` and `chromacade-back-panel.scad` both carry the full dimension block.

Files:
- `chromacade-housing.scad` — the main chassis: builds the 2D profile (`p0`..`p5`) from the dimension constants, extrudes it across `case_w`, shells it by `wall` thickness, cuts the back opening, adds corner/center mounting bosses, and cuts all hardware openings (speaker grilles, shelf controls, panel controls, side-panel hole) via `hardware_cutouts()`.
- `chromacade-back-panel.scad` — the separate back cover plate that screws into the mounting bosses; recomputes the same profile geometry to derive its own outline and boss-hole positions.
- `chromacade-speaker-grilles.scad` — printable speaker grille inserts (hex-hole acoustic pattern sized toddler-safe, ~5.4mm) that friction/screw-fit into the housing's grille cutouts.
- `test-component-holes.scad` / `test-mk2.scad` — small multi-plate fit-test files for validating individual hardware cutout dimensions (encoder bushing, joystick, rocker switch, OLED, LED ring, MX switch clip depth, speaker grille) on real hardware *before* committing to a full-case print. `test-mk2.scad` supersedes the cutouts revised since `test-component-holes.scad` — check its header comment for which plates are newer. Print these when changing any hole dimension; don't assume a dimension is correct without a fit test noted in the file's comments or `decision-log.md`.

The cross-section is built from six points (`p0`..`p5`) computed via trig off the angle/length constants (`shelf_a`, `panel_a`, `panel_l`, `shelf_d`, `front_h`) — front foot → vertical front wall → tilted shelf → 45°-angled main panel → vertical back wall. `case_h` is *derived* from this chain (it's `p4[1]`), not set directly — changing any upstream angle/length shifts the overall case height. `hardware_cutouts()` locates each control by re-deriving the same segment midpoints (e.g. `shelf_my`/`shelf_mz`, `panel_my`/`panel_mz`) and rotating into that segment's local frame before placing holes — this is how holes stay correctly positioned on sloped/angled faces as dimensions change.

## Design documents — read before changing the model or planning features

These aren't background reading; they encode already-made decisions. Check `decision-log.md` before proposing something that sounds like an obvious simplification — many "obvious" alternatives (AAA batteries, a button matrix, per-button LEDs, a plain long-press menu gesture, MCP3008 over ADS1115, etc.) were already tried or considered and explicitly rejected for stated reasons.

- **`design-philosophy.md`** — the evaluation lens (teaching > performance, chunky > compact, color-as-theory, parent-friction-by-design, two-handed workflow). Use this to judge whether a proposed change fits the project.
- **`decision-log.md`** — rejected paths and why, across platform/compute, power, controls, LED/color, case geometry, menu/mode design, and sourcing. Read before re-suggesting an alternative approach.
- **`feature-spec.md`** — normal play mode behavior, the color-chord blending problem (compress 7 letters into a narrow hue arc, ~180–250°, rather than full-rainbow spacing, since analogous hues blend cleanly but complementary hues wash to gray), and Simon/Learn mode (tutor vs. memory sub-modes).
- **`control-layout.md`** — physical control zones and the menu entry/exit gesture grammar (font-encoder-hold + long-press A/G, chosen specifically to be safe against toddler note-mashing).
- **`case-design.md`** — the cross-section rationale and rough dimensions referenced by the `.scad` files above.
- **`gpio-pin-assignments.md`** — locked-in BCM pin map; note GPIO12 (not GPIO18) for the WS2812 ring data line, and GPIO9/10/11 repurposed from unused SPI.
- **`hardware-bom.md`** — sourced parts, quantities (sized for a 4-unit build), and known connector/fit mismatches (e.g. speaker JST connectors need bare-wire splicing to the amp's screw terminals).
- **`open-questions.md`** — unresolved decisions (hue arc width, chord color priority, menu structure, case lid/access panel). Check here before assuming something is finalized; move items out of this file into the relevant spec doc once resolved, don't just answer them in code silently.
- **`chromacade-overview-and-tasks.md`** / **`task-breakdown.md`** — team structure and workstream split (hardware/case CAD is Shane's track; audio engine, display/color, and menu/Simon-mode are the software tracks).

## Conventions worth preserving

- Dimensions in the `.scad` files mix inches (via `in2mm = 25.4`) for panel-level dimensions with millimeters for hardware cutout details — keep this pattern rather than converting everything to one unit.
- `wall = 5` (mm) is treated as a load-bearing constant across housing/back-panel/test files — it's referenced both for shell thickness and for computing cutout depths (e.g. countersink depths are expressed as `wall - x`). Changing it has ripple effects.
- MX switch cutouts require an exact ~1.5mm engagement layer thickness for the clips to snap — this is called out explicitly in `test-component-holes.scad` as intentional; don't "fix" it to match general wall thickness.
