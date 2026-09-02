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
- **Pot-side** (`pot-side-final.scad`) — the side wall with the volume-pot hole, plus the back wall and the base/bottom.
- **Blank-side** (`blank-side-final.scad`) — the other (blank) side wall, plus the front wall, shelf, panel, and the top/ceiling segment above the panel.

**FINAL, 2026-08-27** — these two files supersede every earlier standalone variant (`chromacade-pot-side.scad`, `chromacade-blank-side.scad`, `-embossed.scad`, both `-thinner.scad` variants), all retired to `enclosure/deprecated/`. Don't resurrect the embossed wordmark variant's mount system as a reference — it predates the current mount design entirely (see "Fastening" below).

**Why split this way:** each piece ends up with exactly one full side wall as a flat face, which is printed face-down on the bed. In that orientation the whole piece is just an extrusion along the print's vertical axis (the case's width), so there's no overhang anywhere in the main structure — this is what eliminates the support material a 45°-angled panel would otherwise need, without changing the panel angle itself.

**Construction:** both pieces are carved from the *same* shared shell solid (outer profile minus a wall-inset inner profile) via `intersection()` with a half-plane mask split along the diagonal line between the profile's `p1` (bottom↔front corner) and `p5` (back↔top corner) points, plus a separate intersection for each piece's own endcap slab. Partitioning this way is what guarantees the two pieces can't overlap or leave a gap between them — the previous (superseded) shell+L-bracket design built the back and bottom openings as two independently-inset cuts, which left an uncut rib of material at their shared corner (see `docs/decision-log.md`). A small `edge_clearance` (0.15mm) keeps the two pieces' strip walls just short of touching the other piece's endcap exactly, and a `seam_margin` (3mm) retreats the diagonal mask line itself from its literal p1/p5 coordinates — both exist to avoid relying on exact-touching geometry, which produces either floating-point sliver artifacts or (in the mask's case) a real sliver of overlap where `outer_profile()`'s corner rounding doesn't pass through p1/p5 exactly. Verify any change to either value with an `intersection()` of both pieces' exported STLs — "Current top level object is empty" is the only acceptable result.

**Real failure this caught, the hard way:** a since-abandoned experiment (thinning `wall` from 5mm to 3mm to save print time/material) set the *structural* `wall` constant itself to 3 instead of a separate thinning parameter — this silently collapsed the endcap relief cut to zero (relief depth is `wall - wall_thin`) and drifted `edge_x` 2mm outward, overlapping the other piece's endcap. Nothing caught it before slicing; the printed part measured 195mm assembled against a correct 191.58mm. Both final files now open with a block of `assert()` calls (seam alignment, joystick clearance) that abort the OpenSCAD render outright if this class of drift recurs, rather than relying on the manual STL-intersection check remaining a habit forever. Run the manual check too after any change to the numbers those assertions cover — the assertions catch drift in the specific values they check, not everything the manual check would.

**Fastening:** the two pieces screw together from the sides (screws run along the case's width axis, X), not across the p1/p5 seam — an earlier attempt put mounting bosses on that diagonal seam, which put the screw entry point up to 6" from the boss, since a piece's own wall material is cut back well short of the seam corner at any real distance from the exact edge. **9 M3 mounts total:** pot-side owns 4 (2 on the bottom strip, 2 on the back strip, each near pot-side's edge facing blank-side); blank-side owns 5 (near the front wall's bottom and top, the shelf/panel joint, the panel/top joint, and the top/back joint, each near blank-side's edge facing pot-side). Whichever piece owns a mount gets a 2.5mm self-tapping pilot bore; the other piece gets a 3.4mm clearance hole through its endcap.

Each owned mount also gets a **square reinforcing boss** around its pilot bore, not just a bare hole in the strip's own material — bare `wall` (5mm) material only leaves ~1mm on each side of a centered bore, thin enough to risk cracking under screw torque or (more importantly) an edge-on drop impact, which is a real scenario for this product: it needs to survive a toddler pushing it off a table onto a hard floor, landing directly on one of these edges. The boss flushes with its own face's exterior surface where that face is axis-aligned (pot-side's bottom/back strips; blank-side's front wall and top segment) so there's no visible bump, and extends further into the interior; the 2 blank-side mounts on tilted segments (shelf at 8°, panel at 45°) use a simpler symmetric cube centered on the mount point rather than a properly surface-flush boss, which would need a per-segment local frame. Square, not round, cross-section — matches the *original* (pre-split) `mounting_boss()` module's rationale in `docs/decision-log.md`: a round boss against a flat wall only ever line-contacts it along a curve, where a square boss meets it on a full flush face. Like the mounting holes themselves, each boss is 45°-ramped toward its own piece's endcap/bed side, since it's a localized feature (not part of the uniform extrusion the rest of the shell relies on to be support-free in this print orientation).

Two of blank-side's 5 mount points (front-bottom, top-back) sit close enough to the p1/p5 corners that a boss there dips into pot-side's bottom/back strip territory — those strips run almost the full case width, nearly to blank-side's own edge. Both were shifted from their original 15%-along-segment position to clear pot-side's strip plus the boss's own half-width, confirmed via the interference check.

See `pot-side-final.scad`'s `pot_side_mounts()`/`pot_side_mount_bosses()`/`pot_side_clearance_holes()` and the matching set in `blank-side-final.scad`.

**Separately, `pot-side-final.scad` also mounts the Raspberry Pi board itself** via `pi_mount_bosses()`/`pi_mount_pilot_holes()` — 4 standoffs (`pi_boss_h`=5mm tall, sized for M2.5, 2.4mm self-tapping pilot) at the Pi's real mounting-hole pattern, with the board's screws driving straight down through it into each standoff from above. This is unrelated to the 9 case-joining M3 mounts above — it doesn't hold the two case pieces together, it holds the Pi board to the inside of pot-side.

**Joystick mount, redesigned as of the FINAL files:** the KY-023 joystick board mounts to two 45°-ramped ribs (`joystick_rib()`/`joystick_plinth()` in `blank-side-final.scad`) rather than the earlier four cantilevered support posts (`enclosure/deprecated/joystick-mount-dev.scad`) — support-free in this piece's print orientation, cutting print time roughly 8h vs. ~12h for the old posts. Each rib is slotted to pass the board through and, optionally, pinned for extra support during printing (`joy_slot_support` — set `false` for the production part if the one-layer droop without it is acceptable). A separate mockup of the KY-023's real board outline (measured 2026-08-26, the first time its actual edges — not just the hole pattern — were recorded) exists purely for eyeballing clearance against the speaker, not as printed geometry.

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
