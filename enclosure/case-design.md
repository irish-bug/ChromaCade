# Case Design — ChromaCade

## Overall shape: arcade-cabinet profile
Chosen because it naturally solves the problem of putting several control types at different, ergonomically-appropriate hand angles on one small device — flat-facing controls (speakers), a near-horizontal control surface (encoders, switch, joystick), and an angled display/note surface (buttons, OLED, LED ring), without forcing everything onto one flat plane.

## Cross-section, front to back
1. **Stability foot / base** — extends forward of the front wall specifically to resist tipping. Part of the pot-side piece (see below).
2. **Front wall** — short, vertical, ~3" tall. Holds the two speaker grilles. Part of the blank-side piece.
3. **Shelf** — flat, with a slight tilt (5–10°, arcade-cabinet-style) rather than dead flat, to shed dust/spills and feel deliberate to reach for. Its front edge is flush with the front wall's outer face (no recess). Depth was extended (originally 1", grown to accommodate all 4 shelf controls with real spacing) as the main panel's control load shrank. Part of the blank-side piece.
4. **Main panel** — angled at 45°, holds the 7 note buttons + OLED + LED ring only (toggle and font encoder were relocated to the shelf, which is what let this panel shrink). Panel width stays at 7" (buttons fit comfortably; see hardware-bom.md for the switch-pitch math). Part of the blank-side piece.
5. **Back wall** — vertical, tall enough to close off the interior cavity created by the angled panel; height derives from front-wall height + shelf + the panel's vertical rise at 45°. Part of the pot-side piece — houses the power-cable passthrough and the unpopulated fan vent.

## Two-piece split: pot-side / blank-side (redesigned 2026-08-17)
The case is two printed pieces, split by **which side wall each one owns** — not by which case segment (front/back/etc.) like earlier designs:
- **Pot-side** (`chromacade-pot-side.scad`) — the side wall with the volume-pot hole, plus the back wall and the base/bottom.
- **Blank-side** (`chromacade-blank-side.scad`, or the current `chromacade-blank-side-embossed.scad` with the wordmark) — the other (blank) side wall, plus the front wall, shelf, panel, and the top/ceiling segment above the panel.

**Why split this way:** each piece ends up with exactly one full side wall as a flat face, which is printed face-down on the bed. In that orientation the whole piece is just an extrusion along the print's vertical axis (the case's width), so there's no overhang anywhere in the main structure — this is what eliminates the support material a 45°-angled panel would otherwise need, without changing the panel angle itself.

**Construction:** both pieces are carved from the *same* shared shell solid (outer profile minus a wall-inset inner profile) via `intersection()` with a half-plane mask split along the diagonal line between the profile's `p1` (bottom↔front corner) and `p5` (back↔top corner) points, plus a separate intersection for each piece's own endcap slab. Partitioning this way is what guarantees the two pieces can't overlap or leave a gap between them — the previous (superseded) shell+L-bracket design built the back and bottom openings as two independently-inset cuts, which left an uncut rib of material at their shared corner (see `docs/decision-log.md`). A small `edge_clearance` (0.15mm) keeps the two pieces' strip walls just short of touching the other piece's endcap exactly, and a `seam_margin` (3mm) retreats the diagonal mask line itself from its literal p1/p5 coordinates — both exist to avoid relying on exact-touching geometry, which produces either floating-point sliver artifacts or (in the mask's case) a real sliver of overlap where `outer_profile()`'s corner rounding doesn't pass through p1/p5 exactly. Verify any change to either value with an `intersection()` of both pieces' exported STLs — "Current top level object is empty" is the only acceptable result.

**Fastening:** the two pieces screw together from the sides (screws run along the case's width axis, X), not across the p1/p5 seam — an earlier attempt put mounting bosses on that diagonal seam, which put the screw entry point up to 6" from the boss, since a piece's own wall material is cut back well short of the seam corner at any real distance from the exact edge. Screwing along X instead needs no added boss geometry: each piece's strips and endcap are already continuous, print-safe solid material (part of the uniform extrusion), so a bore straight into that existing material, right at the piece's own edge, gives a short, direct screw path. **9 mounts total:** pot-side owns 4 (2 on the bottom strip, 2 on the back strip, each near pot-side's edge facing blank-side); blank-side owns 5 (near the front wall's bottom and top, the shelf/panel joint, the panel/top joint, and the top/back joint, each near blank-side's edge facing pot-side). Whichever piece owns a mount gets a 3mm pilot bore (self-tapping screw engagement); the other piece gets a 3.5mm clearance hole through its endcap. See `chromacade-pot-side.scad`'s `pot_side_mounts()`/`pot_side_clearance_holes()` and the matching pair in the blank-side files.

This supersedes two earlier designs in sequence: originally just the back was a separate screw-on plate (`chromacade-back-panel.scad`) with the base fused to the shell; unit #1 found that back-only access still left the interior too cramped for wiring (see `docs/open-questions.md`'s former "lid/access panel" entry). A same-day redesign combined the base and back into one removable L-bracket (`chromacade-bottom-back.scad`) screwed onto a shell holding both side walls — this fixed the access problem but left a stray uncut rib where the two independent openings met, and didn't address print-orientation support material. Both are retired in favor of the pot-side/blank-side split above.

The pot-side piece's power-cable passthrough and fan-vent cutouts are carried over unchanged (position and size) from the original `chromacade-back-panel.scad`.

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
- **Print orientation: side wall down** for both pieces (each piece's own endcap face on the bed) — see the "Two-piece split" section above for why this avoids needing support for the 45°-angled panel.
- Workflow: model the parametric structure (panel angle, hole grids, wall thickness, standoffs) in **OpenSCAD**, then bring into **Tinkercad** for visual fit-checking and rounding/aesthetic tweaks
- Design principle throughout: chunky/durable over compact (see design-philosophy.md) — err toward thicker walls, wider spacing, more generous mounting bosses whenever there's a choice

## Toddler-safety details to carry into the model
- Speaker grille holes: small hex pattern, sized so small fingers can't poke through (rule of thumb: under ~6mm), while still leaving enough open area for sound
- Colored keycaps/caps of any kind should be secured (friction-fit + glue, or requires a tool to remove) — a choking hazard if pry-off-able
- Buttons should have enough spacing that multi-touch/chord-mashing doesn't cause constant accidental presses

## Reference image
A GenAI mockup (Gemini "banana" model) was produced showing the case shape, rainbow button row, OLED display content, LED ring, and shelf control clusters correctly labeled (OCTAVE / accidental rocker on far left, FONT / PITCH joystick on far right). Useful as a shared visual reference for the build — worth keeping in the project files.
