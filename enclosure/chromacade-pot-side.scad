// ChromaCade Synthesizer - Pot-side housing (volume-pot endcap + back + bottom)
//
// One of two printed pieces (see chromacade-blank-side(-embossed).scad for
// the other) — split 2026-08-17 so each piece has exactly one full side
// wall as its print-bed face, printed side-down to avoid the support
// material a 45°-angled panel would otherwise need. This piece owns the
// -X endcap (the side with the volume-pot hole), plus the back wall and
// the base/bottom.
//
// Built by partitioning the shared shell at the p1/p5 seam line (a half-
// plane mask in the (Y,Z) profile plane), not as independent inset cuts —
// the previous shell+L-bracket design cut the back and bottom openings
// separately, each inset by `wall` from every edge, which left an uncut
// rib of shell material at their shared corner (p0). A single partition
// can't produce that failure mode: every point is unambiguously on one
// side of the seam or the other, so there's no shared edge to leave a gap
// (or a rib) at. See docs/decision-log.md.
$fn = 60;

// --- Global Dimensions --- (must match chromacade-blank-side(-embossed).scad)
in2mm = 25.4;
case_w = 7.7   * in2mm; // 7in + 10%
case_d = 4.95  * in2mm; // 4.5in + 10%
wall   = 5;

front_h = 1.925 * in2mm; // 1.75in + 10%
shelf_d = 1.875 * in2mm; // 1.5in + 25% (controller shelf)
shelf_a = 8;
panel_l = 2.75  * in2mm; // 2.5in + 10%
panel_a = 45;

p0 = [0, 0];
p1 = [case_d, 0];
p2 = [case_d, front_h];
p3 = [case_d - shelf_d*cos(shelf_a), front_h + shelf_d*sin(shelf_a)];
p4 = [p3[0] - panel_l*cos(panel_a), p3[1] + panel_l*sin(panel_a)];
p5 = [0, p4[1]];

case_h = p4[1];

// Small deliberate gap between the two pieces' strip walls and the other
// piece's endcap — an exact shared boundary plane produces razor-thin
// sliver artifacts in boolean intersection checks (pure floating-point
// noise, confirmed via the pot-side/blank-side interference check) and
// relies on unrealistic print tolerance anyway. Defined here (not down by
// strips(), where it conceptually belongs) because edge_x below needs it —
// OpenSCAD warns "Ignoring unknown variable" on a forward reference, which
// silently drops every mount hole positioned from it. Keep this above any
// use of edge_clearance/edge_x, not just above strips().
edge_clearance = 0.15;

// Mounting holes joining this piece to chromacade-blank-side(-embossed).scad
// — fastened from the SIDES (screws run along X), not across the diagonal
// p1/p5 seam (an earlier attempt put bosses there, ~6" from where the screw
// would actually enter, since a piece's own wall material is already cut
// back well short of the seam corner at any real distance from the exact
// edge — see docs/decision-log.md). Screwing along X instead needs no added
// boss geometry at all: each piece's strips and endcap are already
// continuous, print-safe solid material (part of the uniform extrusion), so
// a bore straight into that existing material, right at the piece's own
// edge, gives a short, direct screw path with plenty of engagement depth
// and nothing that needs a support-avoiding chamfer.
//
// This piece (pot-side) owns 4 mounts — 2 on the bottom strip, 2 on the
// back strip — each a pilot bore (screw threads into this piece's own
// plastic) starting right at this piece's edge nearest blank-side and
// reaching backward into solid material. Blank-side owns 4 more (was 5
// until 2026-08-19 -- the shelf/panel joint mount was removed, see
// blank_side_mount_yz below) — near the front wall's bottom and top, the
// panel/top joint, and the top/back joint — this piece just gets a plain
// clearance hole for those, through its endcap.
//
// Sized for M3 screws: 2.5mm self-tapping pilot (~0.83x nominal, standard
// for 3D-printed plastic), 3.4mm clearance (standard loose fit).
//
// Each owned mount gets a square reinforcing boss around its pilot bore —
// bare wall material alone (wall = 5mm) only leaves ~1mm on each side of
// the bore, thin enough to risk cracking under screw torque or a drop
// impact right at these edge-adjacent mount points (this design needs to
// survive a toddler pushing it off a table onto a hard floor, landing
// directly on an edge). The boss flushes with this face's own exterior
// surface (no visible bump) and extends boss_w further into the interior,
// giving the bore full radial coverage inside reinforced material instead
// of the bare 5mm wall. Square, not round, cross-section — a round boss
// against a flat wall only ever line-contacts it along a curve; square
// meets it on a full flush face, the same rationale the original (pre-split)
// mounting_boss() module used (see docs/decision-log.md).
pilot_d   = 2.5;
clear_d   = 3.4;
engage    = 15;  // pilot bore depth into solid material
boss_w    = 12;  // square boss cross-section (also the bore's radial center)
boss_body = 14;  // boss length along X, full cross-section
boss_ramp = 10;  // 45°-taper length beyond boss_body, toward this piece's own bed/endcap side

edge_x = case_w/2 - wall - edge_clearance; // this piece's edge nearest blank-side

// Square boss with a 45° taper toward -X (this piece's own endcap/bed
// side, since it prints side-down) so it doesn't need support in that
// orientation — a boss is a *localized* feature (not part of the uniform
// extrusion the rest of the shell relies on for being support-free), so
// without the taper it would be an abrupt, unsupported step as the print
// builds up through X. thick_axis picks which face this boss flushes with:
// "z" for a bottom-strip mount (flush at Z=0), "y" for a back-strip mount
// (flush at Y=0). `pos` is the position along the strip (Y for "z", Z for
// "y") — the bore's own translate() must use the same `pos` and the same
// boss_w/2 for its other coordinate, or the bore won't be centered in the
// reinforced material.
// z_start/height override the boss's Z-extent for thick_axis="z"; y_start/
// height do the same for thick_axis="y" (both default z_start=y_start=0,
// height=boss_w). Corrected 2026-08-18, second pass, for the "z" case --
// first attempt (height=wall, z_start=0) capped the boss at the bottom
// strip's own bare-wall thickness, which just made it coincide exactly
// with material that's already there (effectively no reinforcement at
// all, and visually "centered in"/embedded in the panel rather than a
// distinct standing feature). What's actually wanted: the boss's BOTTOM
// face flush with the bottom strip's own INTERIOR surface (z=wall, not
// z=0 -- z=0 is the exterior), standing up from there into the open
// interior by `height`.
//
// The "y" (back-strip) case had the exact same bug and went uncorrected
// until 2026-08-19 -- found by direct inspection: with y_start defaulting
// to 0, the boss (and its centered pilot bore) sat flush with the back
// wall's EXTERIOR surface and only reached boss_w (12mm) deep, instead of
// starting at the back wall's INTERIOR surface (y=wall) and reaching
// boss_w past THAT -- 5mm short of the bottom-strip bosses' actual
// standoff, and correspondingly too little material between the bore and
// the exterior back surface (bore center at only boss_w/2=6mm from the
// exterior, vs the bottom-strip bores' wall+boss_w/2=11mm). Same fix,
// same axis logic, rotated 90°: y_start=wall, height=boss_w.
module square_boss(x0, pos, thick_axis, z_start=0, height=boss_w, y_start=0) {
    if (thick_axis == "z") {
        translate([x0 - boss_body, pos - boss_w/2, z_start])
        cube([boss_body, boss_w, height]);

        // Wedge, not a pyramid -- corrected 2026-08-18, third pass. A
        // linear_extrude(scale=0) taper shrinks BOTH cross-section
        // dimensions to a single point, which isn't printable
        // support-free (it needs an overhang-avoiding slope down to
        // one surface, not a point floating in space). hull() between
        // the boss's own -X face (full Y/Z cross-section) and a thin
        // sliver pinned at z_start (this strip's own interior surface,
        // same value the main cube above starts from) keeps the bottom
        // flush throughout the taper and only collapses the height --
        // an actual ramp down to the bottom, printable face-down with
        // no support.
        hull() {
            translate([x0 - boss_body - 0.01, pos - boss_w/2, z_start])
            cube([0.01, boss_w, height]);

            translate([x0 - boss_body - boss_ramp, pos - boss_w/2, z_start])
            cube([0.01, boss_w, 0.01]);
        }
    } else {
        translate([x0 - boss_body, y_start, pos - boss_w/2])
        cube([boss_body, height, boss_w]);

        // Same wedge-not-pyramid correction, pinned at y_start (this
        // strip's own INTERIOR surface, matching the "z" case) instead
        // of the back wall's exterior -- a ramp down to the back, not a
        // point.
        hull() {
            translate([x0 - boss_body - 0.01, y_start, pos - boss_w/2])
            cube([0.01, height, boss_w]);

            translate([x0 - boss_body - boss_ramp, y_start, pos - boss_w/2])
            cube([0.01, 0.01, boss_w]);
        }
    }
}

// Blank-side's 4 mount positions (Y,Z) — down from 5 as of 2026-08-19, per
// direct feedback on the corrected-shape render (this is a mirror, not the
// source of truth -- see chromacade-blank-side.scad's own_mount_boss_centers
// for the full reasoning behind each change, kept in sync here by hand):
//   - shelf/panel joint mount REMOVED entirely ("hanging off in space").
//   - panel/top joint mount moved from [45,73] to [56.701,61.834] -- was
//     colliding with the OLED cutout; new position is in line with the MX
//     note-key row in the panel's own local frame.
//   - front wall bottom/top moved from Y=110 to Y=114.73 on both -- the
//     bore wasn't centered in its boss (only 1.27mm of material past it on
//     the free side); 114.73 is the true center of a boss_w=12 boss flush
//     at the front wall's interior face.
// Regenerate together if the dimension constants above change.
blank_side_mount_yz = [
    [114.73, 12],   // front wall, near bottom
    [114.73, 42],   // front wall, near top
    [56.701, 61.834], // panel/top joint
    [14, 95],       // top/back joint
];

// Raspberry Pi 4B mounting bosses (2026-08-19) -- standoffs on this piece's
// bottom floor for the Pi + WM8960 HAT + breakout HAT + active cooler
// stack. Official Pi4B mounting hole spacing, 58x49mm (matches the same
// widely-used spec as the grokwell-PiLC reference this project's
// fit-check file already follows) -- board's long edge (85mm) runs along
// X, short edge (56mm) along Y.
//
// Positioned near the back wall (low Y), with pi_back_clearance (10mm,
// the user's stated MINIMUM 2026-08-19) between the board's back-facing
// edge and the back wall's own interior face -- with both HATs and active
// cooling, the stack reaches ~53mm off a 5mm standoff, tall enough that
// this clearance was called out explicitly even though the back wall
// itself is a flat vertical plane here (doesn't narrow with height, this
// case profile has no overhang at this Y range up to well past 53mm).
// Comfortably clear of the shelf's own footprint (shelf begins Y=78.567;
// board's far edge lands at Y=71, ~7.5mm short of it) and centered in X,
// nowhere near either endcap (holes at X=+/-29, endcaps at X=+/-97.79).
pi_hole_dx        = 29;   // 58mm spacing / 2
pi_hole_dy        = 24.5; // 49mm spacing / 2
pi_board_h        = 56;   // short edge, along Y
pi_back_clearance = 15;   // MINIMUM per spec -- don't shrink this
pi_cx             = 0;
pi_near_y         = wall + pi_back_clearance;
pi_cy             = pi_near_y + pi_board_h/2;
pi_boss_h    = 5;   // standoff height -- matches the 5mm the 53mm stack height assumes
pi_boss_w    = 6;   // ESTIMATE: boss cross-section, sized for M2.5 (smaller than the
                     // 12mm case-joining boss_w -- this only needs to hold a light board)
pi_boss_ramp = 6;   // ESTIMATE: 45°-taper length toward -X (this piece's own bed side)
pi_pilot_d   = 2.4; // self-tapping pilot for M2.5, matches grokwell-PiLC's SCREW_PILOT_D

function pi_mount_xy() = [
    [pi_cx - pi_hole_dx, pi_cy - pi_hole_dy],
    [pi_cx + pi_hole_dx, pi_cy - pi_hole_dy],
    [pi_cx - pi_hole_dx, pi_cy + pi_hole_dy],
    [pi_cx + pi_hole_dx, pi_cy + pi_hole_dy],
];

// Standoff centered at (cx,cy) -- unlike square_boss() above (which
// anchors its "far" edge at a piece's own X boundary, for the
// case-joining screws), a Pi standoff's pilot needs to land exactly on
// the board's real hole position, so this centers the boss cross-section
// on (cx,cy) instead. Same wedge-not-pyramid technique as square_boss():
// hull() from the boss's own -X face (full cross-section) to a thin
// sliver pinned at z_start (this floor's own interior surface) -- ramps
// down to the bottom, printable face-down with no support, toward this
// piece's own bed/endcap side (-X), same direction as the case-joining
// bosses on this same floor.
module pi_mount_boss(cx, cy) {
    translate([cx - pi_boss_w/2, cy - pi_boss_w/2, wall])
    cube([pi_boss_w, pi_boss_w, pi_boss_h]);

    hull() {
        translate([cx - pi_boss_w/2 - 0.01, cy - pi_boss_w/2, wall])
        cube([0.01, pi_boss_w, pi_boss_h]);

        translate([cx - pi_boss_w/2 - pi_boss_ramp, cy - pi_boss_w/2, wall])
        cube([0.01, pi_boss_w, 0.01]);
    }
}

module pi_mount_bosses() {
    for (p = pi_mount_xy())
        pi_mount_boss(p[0], p[1]);
}

// Pilot holes drilled straight down (Z axis) from the top of each boss --
// unlike the case-joining bores (which enter from the piece's own edge
// along X), the Pi board sits ON TOP of these standoffs, so its mounting
// screws drive straight down through the board into the boss beneath it.
module pi_mount_pilot_holes() {
    for (p = pi_mount_xy())
        translate([p[0], p[1], wall - 0.5])
        cylinder(h = pi_boss_h + 1, d = pi_pilot_d);
}

module pot_side_mount_bosses() {
    square_boss(edge_x, 110, "z", z_start=wall, height=boss_w);
    square_boss(edge_x, 30, "z", z_start=wall, height=boss_w);
    square_boss(edge_x, 85, "y", y_start=wall, height=boss_w);
    square_boss(edge_x, 20, "y", y_start=wall, height=boss_w);
}

module pot_side_mounts() {
    // Bottom-strip (z-axis) bores centered at wall + boss_w/2, matching
    // the boss above: flush with the bottom strip's own interior surface
    // (z=wall) at its bottom face, standing up boss_w into the interior
    // from there -- corrected 2026-08-18, second pass (see square_boss()
    // comment). NOT wall/2 -- that was this module's first-pass fix,
    // which just embedded the boss inside material that's already there.
    // chromacade-blank-side.scad's pot_side_mount_yz must be updated to
    // match this new Z value.
    translate([edge_x, 110, wall + boss_w/2]) rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    translate([edge_x, 30, wall + boss_w/2])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    //
    // Back-strip (y-axis) bores: same convention, corrected 2026-08-19 --
    // centered at wall + boss_w/2 from the back wall's exterior (y=0),
    // matching the bottom-strip bores' distance from THEIR exterior
    // exactly (both now 11mm), instead of the old boss_w/2=6mm, which
    // put the bore too close to the exterior back surface (not enough
    // material behind it to survive an edge-on drop). Keep
    // chromacade-blank-side.scad's pot_side_mount_yz in sync with this.
    translate([edge_x, wall + boss_w/2, 85])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    translate([edge_x, wall + boss_w/2, 20])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
}

module pot_side_clearance_holes() {
    for (yz = blank_side_mount_yz) {
        translate([-case_w/2 + wall/2, yz[0], yz[1]])
        rotate([0, 90, 0]) cylinder(h=wall + 10, d=clear_d, center=true);
    }
}

// --- Assembly ---
difference() {
    union() {
        endcap(-1);
        strips();
        pot_side_mount_bosses();
        pi_mount_bosses();
    }
    hardware_cutouts();
    pot_side_mounts();
    pot_side_clearance_holes();
    pi_mount_pilot_holes();
}

module outer_profile() {
    pts = [p0, p1, p2, p3, p4, p5];
    offset(r=6) offset(r=-6) polygon(pts);
}

// The full shell, unpartitioned — same construction as the pre-split
// design (shell = outer profile minus the wall-inset inner profile,
// extruded across case_w). Both pieces are carved from this same solid via
// intersection with different masks, which is what guarantees they can't
// overlap or leave a gap between them.
module shell_solid() {
    difference() {
        rotate([90, 0, 90])
        linear_extrude(case_w, center=true)
        outer_profile();

        rotate([90, 0, 90])
        linear_extrude(case_w - (wall * 2), center=true)
        offset(delta = -wall) outer_profile();
    }
}

// Half-plane clip in the (Y,Z) profile plane, split along the p1-p5 seam
// line. side=1 keeps the p0 (back+bottom) half; side=-1 keeps the other
// (front+shelf+panel+top) half. Uses the same rotate([90,0,90])/
// linear_extrude(case_w) pattern as outer_profile()'s own extrusion in
// shell_solid(), so this mask aligns with it exactly — no separate axis-
// mapping derivation needed (that's what went wrong building the L-bracket
// last round: a fresh extrusion with hand-derived rotation, sign-flipped).
module yz_half_plane(side) {
    seam = p5 - p1;
    // Rotating seam +90° CCW ([-dy,dx]) points toward p0 for this profile's
    // specific shape (dx=p5x-p1x<0, dy=p5y-p1y>0 always here, so [-dy,dx]
    // has both components negative — i.e. toward the origin/p0 corner).
    // Verified numerically before writing this file. side=-1 flips it.
    perp = side * [-seam[1], seam[0]];
    perp_unit = perp / norm(perp);
    // Retreat the mask line a few mm from the exact p1-p5 line, into this
    // piece's own kept side. outer_profile()'s offset(r=6)/offset(r=-6)
    // rounding doesn't pass through p1/p5 exactly, so a mask cut at the
    // literal coordinates leaves a sliver of near-touching material where
    // the rounded wall surface and the straight mask line diverge near the
    // corner (found via the pot-side/blank-side interference check — small,
    // but non-empty). 3mm comfortably clears the 6mm rounding radius's
    // local effect.
    seam_margin = 1;
    p1m = p1 + perp_unit*seam_margin;
    p5m = p5 + perp_unit*seam_margin;
    big = 2000;
    pts = [p1m, p5m, p5m + perp_unit*big, p1m + perp_unit*big];
    rotate([90, 0, 90])
    linear_extrude(case_w, center=true)
    polygon(pts);
}

// Full-hexagon endcap slice, wall-thick, at this piece's own X extreme.
// side=-1 -> endcap at X=-case_w/2 (pot side); side=1 -> X=+case_w/2.
module endcap(side) {
    intersection() {
        shell_solid();
        translate([side * (case_w/2 - wall/2), case_d/2, case_h/2])
        cube([wall, case_d + 80, case_h + 80], center=true);
    }
}

// This piece's back+bottom wall strips, spanning from its own endcap's
// outer face to just short of the OTHER piece's endcap inner face (see
// edge_clearance, defined near the top of this file).
module strips() {
    intersection() {
        shell_solid();
        yz_half_plane(1); // back+bottom side (contains p0)
        translate([-(wall + edge_clearance)/2, case_d/2, case_h/2])
        cube([case_w - wall - edge_clearance, case_d + 80, case_h + 80], center=true);
    }
}

// Cooling fan cutout -- side-panel mounted (2026-08-19), one per endcap
// (this file's own -X endcap here; blank-side.scad's +X endcap gets the
// matching cutout at the same Y,Z for a straight cross-case draft over
// the Pi/HAT stack, rather than two fans on one wall recirculating
// locally). Replaces the old unpopulated 39mm/32mm-spacing back-wall
// vent entirely -- that was sized for a hypothetical fan that was never
// actually sourced; the real part (hardware-bom.md's "Cooling" section,
// spec logged commit 08a6143, dimensioned in enclosure/fan-dimensions.jpg)
// is a 30x30x7mm side-panel fan, M2.5 hardware, 24mm hole spacing --
// completely different size/mounting/location, not a resize of the old
// cutout.
//
// Position CORRECTED 2026-08-19/20, second pass -- per direct instruction,
// centered on the Pi board itself rather than pushed aside to dodge the
// volume-pot hole: target was Y=48 (midpoint between the Pi's own
// mounting holes, pi_cy +/- pi_hole_dy = 23.5 and 72.5) and Z=30 (blows
// straight across the top of the active cooler rather than past its
// edge). That exact target overlapped the volume-pot hole's original
// position (-3.2mm, a real collision) -- fixed by moving the pot hole
// (see hardware_cutouts() below) -- AND, checked while verifying that
// fix, would have mostly covered one of blank-side's owned-mount
// clearance holes on THIS endcap (only 3.3mm clear -- the fan's solid
// body would sit almost on top of the screw access, not just a thin-
// wall concern but blocking a screwdriver from ever reaching it) and,
// symmetrically, one of pot-side's OWN clearance holes on blank-side's
// endcap. Nudged the minimum amount that clears every mount-clearance
// hole on BOTH endcaps with >=10mm real margin (searched, not guessed):
// Y=53, Z=35 -- 5mm off the exact target in each direction, still
// centered on the Pi board and still blowing across the cooler in any
// practical sense.
fan_y = 53;
fan_z = 35;
fan_grille_d   = 26;   // ESTIMATE -- inside the fan's 30mm outer frame,
                        // clearing its corner screw bosses; not yet
                        // measured against the real fan's blade housing.
fan_hole_spacing = 24;  // MEASURED, enclosure/fan-dimensions.jpg
fan_pilot_d      = 2.4; // self-tapping for M2.5, matches pi_pilot_d below
                         // -- NOT the fan's own 3.5mm clearance holes
                         // (those are already in the fan itself, sized
                         // for the screw shaft to pass through freely;
                         // this side needs to grip the threads).

module fan_cutout() {
    translate([-case_w/2, fan_y, fan_z])
    rotate([0, 90, 0]) {
        stadium_hex_grill(fan_grille_d, fan_grille_d);
        for (dy = [-fan_hole_spacing/2, fan_hole_spacing/2])
            for (dz = [-fan_hole_spacing/2, fan_hole_spacing/2])
                translate([dy, dz, 0])
                cylinder(h=wall*4, d=fan_pilot_d, center=true);
    }
}

module hardware_cutouts() {
    // Volume pot hole for the Fender 500K -- needs its 3/8" (9.525mm)
    // mounting bushing, not a bare 8mm hole (regression; unit #1 was
    // hand-drilled out to fit -- fixed here so future prints don't need
    // that workaround).
    //
    // MOVED 2026-08-19/20 from the simple (case_d/4, case_h/3) fractional
    // placement, first to (15, 48) -- the fan cutout's new position
    // (centered on the Pi board, see fan_cutout() above) collided with
    // the old spot by -3.2mm, a real overlap, not a near-miss. That first
    // move only checked clearance against the 9.525mm bushing hole cut
    // here, not the pot's actual CAN body behind the panel (measured
    // 24mm diameter, well past the 16mm this project had been assuming --
    // see chromacade-fit-check.scad's POT_CAN_D) -- with the real can
    // size, (15,48) left only 3.00mm to the case profile edge, snug
    // enough that a print was already underway on it (left to finish,
    // not stopped -- positive clearance, not an overlap). MOVED AGAIN to
    // (18, 45) for the next print: a 4.24mm nudge that doubles the edge
    // clearance to 6.00mm, while keeping 8.00mm from the fan cutout and
    // 28.5mm from the nearest of blank-side's 4 owned-mount clearance
    // holes (all computed, not eyeballed). Still "side panel, deliberately
    // less convenient" per control-layout.md -- moving within the same
    // endcap doesn't change that.
    translate([-case_w/2, 18, 45])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=9.525, center=true);

    // Power cable passthrough — 4mm, carried over unchanged from the
    // retired chromacade-back-panel.scad / chromacade-bottom-back.scad.
    // Unit #1 is bring-up-powered via a micro-USB cable routed straight
    // through instead of the LiPo/boost-charge board (decision-log.md).
    //h_back  = case_h - wall*2 - 1;
    //cable_z = case_h/2 + (-h_back/2 + 1.5);
    //translate([-40, wall, cable_z]) rotate([-90, 0, 0]) cylinder(h=wall*3, d=4, center=true);

    fan_cutout();
}

// Copied verbatim from chromacade-blank-side(-embossed).scad's speaker
// grille (same toddler-safe hole size, already print-validated there)
// rather than shared/included, matching this project's standalone-file
// convention (see CLAUDE.md).
module stadium_hex_grill(gw, gh) {
    r          = gw / 2;
    cap_offset = (gh - gw) / 2;
    hole_radius = 2.7;
    spacing     = 6;

    intersection() {
        hull() {
            translate([0,  cap_offset, 0]) cylinder(h=wall*5, r=r, center=true);
            translate([0, -cap_offset, 0]) cylinder(h=wall*5, r=r, center=true);
        }
        union() {
            for (x = [-gw/2 : spacing : gw/2]) {
                for (y = [-gh/2 : spacing*0.866 : gh/2]) {
                    x_offset = x + (round(y/(spacing*0.866)) % 2) * (spacing/2);
                    translate([x_offset, y, 0])
                    cylinder(h=wall*5, r=hole_radius, $fn=6, center=true);
                }
            }
        }
    }
}
