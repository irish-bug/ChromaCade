# Case Design — ChromaCade

## Overall shape: arcade-cabinet profile
Chosen because it naturally solves the problem of putting several control types at different, ergonomically-appropriate hand angles on one small device — flat-facing controls (speakers), a near-horizontal control surface (encoders, switch, joystick), and an angled display/note surface (buttons, OLED, LED ring), without forcing everything onto one flat plane.

## Cross-section, front to back
1. **Stability foot** — the base extends forward of the front wall specifically to resist tipping. Given the case is otherwise fairly tall/chunky, err generous here.
2. **Front wall** — short, vertical, ~3" tall. Holds the two speaker grilles.
3. **Shelf** — flat, with a slight tilt (5–10°, arcade-cabinet-style) rather than dead flat, to shed dust/spills and feel deliberate to reach for. Its front edge is flush with the front wall's outer face (no recess). Depth was extended (originally 1", grown to accommodate all 4 shelf controls with real spacing) as the main panel's control load shrank.
4. **Main panel** — angled at 45°, holds the 7 note buttons + OLED + LED ring only (toggle and font encoder were relocated to the shelf, which is what let this panel shrink). Panel width stays at 7" (buttons fit comfortably; see hardware-bom.md for the switch-pitch math).
5. **Back wall** — vertical, tall enough to close off the interior cavity created by the angled panel; height derives from front-wall height + shelf + the panel's vertical rise at 45°. Houses/backs the charging port (back-mounted, out of reach during play).

**Base is continuous** — one unbroken slab running the full depth from the front foot, under the front wall, under the shelf, under the panel's footprint, to the back wall. This is both a stability requirement (single flat base is a stronger platform than a stepped one) and simpler to print as one piece.

## Rough dimensions (working numbers, not final — confirm against real component footprints before finalizing OpenSCAD)
- Overall width: ~7" (matches panel and shelf width)
- Overall depth: ~6.5"
- Overall height: ~5" (down from an earlier ~6.2" estimate, after the panel shrank)
- Panel length along the slope: ~2.5" (down from an initial 4", once toggle + font moved to the shelf)
- Shelf depth: ~2" (up from an initial 1", to fit both shelf control clusters with real spacing)
- Front wall height: ~3"

These numbers came from trigonometry on the 45° angle (rise = run = length × sin/cos 45°) plus stacking wall/shelf heights — recompute if any single dimension changes, since they're all coupled.

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
