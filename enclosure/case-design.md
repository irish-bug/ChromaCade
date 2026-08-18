# Case Design — ChromaCade

## Overall shape: arcade-cabinet profile
Chosen because it naturally solves the problem of putting several control types at different, ergonomically-appropriate hand angles on one small device — flat-facing controls (speakers), a near-horizontal control surface (encoders, switch, joystick), and an angled display/note surface (buttons, OLED, LED ring), without forcing everything onto one flat plane.

## Cross-section, front to back
1. **Stability foot / base** — extends forward of the front wall specifically to resist tipping. Now part of the removable bottom+back piece (see below), not the main shell.
2. **Front wall** — short, vertical, ~3" tall. Holds the two speaker grilles. Part of the main shell.
3. **Shelf** — flat, with a slight tilt (5–10°, arcade-cabinet-style) rather than dead flat, to shed dust/spills and feel deliberate to reach for. Its front edge is flush with the front wall's outer face (no recess). Depth was extended (originally 1", grown to accommodate all 4 shelf controls with real spacing) as the main panel's control load shrank. Part of the main shell.
4. **Main panel** — angled at 45°, holds the 7 note buttons + OLED + LED ring only (toggle and font encoder were relocated to the shelf, which is what let this panel shrink). Panel width stays at 7" (buttons fit comfortably; see hardware-bom.md for the switch-pitch math). Part of the main shell.
5. **Back wall** — vertical, tall enough to close off the interior cavity created by the angled panel; height derives from front-wall height + shelf + the panel's vertical rise at 45°. Part of the removable bottom+back piece (see below) — houses the power-cable passthrough and the unpopulated fan vent.

## Two-piece split (changed 2026-08-17)
The case is now two printed pieces, not one:
- **Main shell** (`chromacade-housing-embossed.scad`, or the plain `chromacade-housing.scad`) — sides, front wall, shelf, and panel. Open at the bottom and the back.
- **Bottom+back bracket** (`chromacade-bottom-back.scad`, new) — the base/foot and the back wall combined into one removable, L-shaped piece: two flat wall-thick plates meeting at a 90° corner with a small fillet radius (avoids a sharp inside corner). Screws into 9 mounting bosses on the shell (6 around the back opening, 3 along the front edge of the bottom opening) — undo those screws and the whole floor+back lifts away, exposing the full interior.

This replaces two earlier designs in sequence: originally just the back was a separate screw-on plate (`chromacade-back-panel.scad`, now retired) with the base fused to the shell; unit #1 found that back-only access still left the interior too cramped for wiring (see `docs/open-questions.md`'s former "lid/access panel" entry, now resolved here). The current split gives full interior access for wiring/assembly, not just battery/SD swaps — accepted tradeoff: two pieces to align and screw together instead of one, and a visible seam around the bottom+back.

The bottom+back bracket's power-cable passthrough and fan-vent cutouts are carried over unchanged (position and size) from the old `chromacade-back-panel.scad`.

## Dimensions (updated 2026-08-17: scaled +10% overall, shelf +25%, for more interior room)
- Overall width: ~7.7" (7" + 10%)
- Overall depth: ~4.95" (4.5" + 10%)
- Panel length along the slope: ~2.75" (2.5" + 10%)
- Shelf depth: ~1.875" (1.5" + 25% — extra clearance for the 4-control shelf cluster specifically)
- Front wall height: ~1.925" (1.75" + 10%)
- Overall height: derived from the trig chain below (not set directly)

Hardware cutout sizes/positions (button spacing, encoder bushings, grille hole size, etc.) are **not** scaled — those match real component footprints regardless of overall case size. Only the six shape-defining constants above changed; recompute if any single dimension changes further, since they're all coupled via trigonometry on the 45° panel angle (rise = run = length × sin/cos 45°) plus stacked wall/shelf heights.

## Interior volume / component placement
The angled panel creates a triangular interior cavity, deepest near the back wall and tapering to nothing near the front foot. Plan to place the tallest/bulkiest components (LiPo battery, boards mounted on edge) near the back wall, and flatter components (ADS1115, wiring) in the shallower front part of the cavity.

## Printer & workflow
- Printer bed limit: 8"×8"×8" — current dimensions fit comfortably with margin
- Workflow: model the parametric structure (panel angle, hole grids, wall thickness, standoffs) in **OpenSCAD**, then bring into **Tinkercad** for visual fit-checking and rounding/aesthetic tweaks
- Design principle throughout: chunky/durable over compact (see design-philosophy.md) — err toward thicker walls, wider spacing, more generous mounting bosses whenever there's a choice

## Toddler-safety details to carry into the model
- Speaker grille holes: small hex pattern, sized so small fingers can't poke through (rule of thumb: under ~6mm), while still leaving enough open area for sound
- Colored keycaps/caps of any kind should be secured (friction-fit + glue, or requires a tool to remove) — a choking hazard if pry-off-able
- Buttons should have enough spacing that multi-touch/chord-mashing doesn't cause constant accidental presses

## Reference image
A GenAI mockup (Gemini "banana" model) was produced showing the case shape, rainbow button row, OLED display content, LED ring, and shelf control clusters correctly labeled (OCTAVE / accidental rocker on far left, FONT / PITCH joystick on far right). Useful as a shared visual reference for the build — worth keeping in the project files.
