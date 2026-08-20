// ChromaCade - Joystick (KY-023) mounting boss development, in isolation
//
// Pulled out of chromacade-blank-side.scad 2026-08-19 per direct feedback
// on the first printed test: straight-up-and-down bosses (see git history,
// joystick_mount_bosses() before this date) got in the way of the
// joystick's own range of motion, two of the four didn't have enough
// material to fully encase their screws (would break under real toddler
// use), and -- found independently while redesigning -- weren't actually
// support-free to print despite being built with a hull()-based taper.
// Work on the boss shape HERE, in isolation, until it's right, then port
// the final joy_boss_* constants/modules back into
// chromacade-blank-side.scad's joystick_mount_bosses()/
// joystick_mount_pilot_holes() (and chromacade-fit-check.scad's mirrored
// copy) to replace the removed originals.
//
// WHY THE ORIGINAL RAMP DIDN'T ACTUALLY WORK (read before changing the
// taper logic below): chromacade-blank-side.scad prints with its own +X
// endcap face-down on the bed -- print-vertical = global X, and BLANK-SIDE
// SPECIFICALLY builds toward -X as printing proceeds (own_mount_boss()'s
// comment: bosses there extend "toward +X, this piece's own bed/endcap
// side"). The shelf's local frame only rotates about the GLOBAL X axis
// (rotate([-shelf_a,0,0])), so local X *is* global X unchanged -- tapering
// a shape uniformly along *local Z* (as the first joystick boss attempt
// did, via a plain linear_extrude of a 2D wedge) doesn't taper it along
// the axis that actually matters for printability at all. A boss needs to
// go from a THIN, X-shifted sliver (printed early/near the bed, high X)
// to its FULL true-position cross-section (printed late, low X) --
// exactly like square_boss()'s and own_mount_boss()'s existing ramps in
// the real files, just adapted to a shape whose main body is a hole-
// clipped wedge instead of a plain rectangle/cube.
//
// THE DESIGN HERE: two separate pieces per boss, matching square_boss()'s
// own pattern exactly (see that module's comments in
// chromacade-pot-side.scad for the original technique this is adapted
// from):
//   1. MAIN BODY -- the full hole-clipped wedge (joy_boss_wedge_2d()),
//      full height, at the board's TRUE, unshifted hole position. This is
//      what actually gives hole clearance (material only ever exists
//      outside r_inner = the stick hole's own radius + a small gap) and
//      wall thickness around the pilot bore. This piece must stay exactly
//      where the real board's screw hole is -- it's not negotiable, the
//      board is real hardware.
//   2. RAMP -- a separate, narrower taper (ramp_w wide, not the wedge's
//      full width) added on beyond the wedge's own edge, hull()'d between
//      a thin FULL-HEIGHT slice (right at the wedge's own edge) and a
//      thin ZERO-HEIGHT slice further out (ramp_x, toward +X). This is
//      what makes it print-safe -- height only ever tapers between two
//      THIN (0.01mm in X) slices, so it can't accidentally bridge back
//      over the wedge's own concave hole-clipped boundary the way hulling
//      two full-width shapes together risks doing (confirmed by testing
//      that broken version first -- see git history if curious).
//
// HOW TO USE
//   - PART = "ASSEMBLY" shows all 4 bosses + the stick hole together, no
//     surrounding plate (for a quick look, not for printing directly).
//   - PART = "SINGLE" isolates one boss (see single_which below) for a
//     close look.
//   - PART = "PRINTABLE" is the actual print-ready coupon -- a small slab
//     of "shelf" material with the stick hole + all 4 bosses, ALREADY
//     rotated so the ramp direction points straight down. Slice this
//     directly, no manual reorientation needed (unlike ASSEMBLY/SINGLE).
//     This replaces the old test-mk2.scad plate B, which was removed
//     2026-08-19 since its flat-plate convention doesn't fit this design's
//     print-orientation requirement (see the warning below).
//   - PRINT ORIENTATION WARNING (for ASSEMBLY/SINGLE only -- PRINTABLE
//     already handles this): this file's own local coordinate frame does
//     NOT match how OpenSCAD's default camera/build plate looks --
//     +X here is deliberately the ramp/taper direction, matching
//     blank-side's real -X-toward-bed print direction (see the long
//     comment above). If you slice this in isolation, orient it so
//     GLOBAL +X points DOWN toward the print bed (i.e. rotate the whole
//     assembly -90 about Y in your slicer) to see the same support
//     behavior the real embedded print will have. Don't just print it
//     "as viewed" without doing that rotation -- it'll look support-free
//     in a naive orientation and then need support once actually embedded.
$fn = 60;

/* [Render Selection] */
PART = "ASSEMBLY";
// [ASSEMBLY, SINGLE, PRINTABLE]
single_which = 0; // 0-3, only used when PART="SINGLE" -- see joy_positions below

wall = 5; // matches case wall thickness

// --- Real hardware measurements (2026-08-18/19, see chromacade-blank-side.scad) ---
joy_stick_d = 27;   // UNDER TEST -- current best guess, see test-mk2.scad plate B
hole_dx     = 9;    // board hole +/-9mm left-right, both pairs
front_dy    = 14;   // front pair (toward speaker wall), 14mm off joystick center
back_dy     = -12.5; // back pair (toward device center), 12.5mm off center
boss_h      = 12;   // MEASURED-derived standoff height (matches the board+header stack)

// --- Boss shape parameters -- THIS is what you're iterating on ---
hole_r          = joy_stick_d / 2;
r_inner_gap     = 0.2;  // gap beyond the hole edge before boss material starts
r_inner         = hole_r + r_inner_gap;
r_outer         = 19;   // main body's outer reach (absolute radius from hole center) --
                         // 21 caused a real bug (3 disconnected volumes) in the
                         // ORIGINAL straight-extrude version on the full shell; not
                         // re-verified against this new ramped construction yet --
                         // start retesting from a safely-smaller value.
half_angle      = 12;   // degrees, wedge angular half-width -- covers the pilot
                         // (needs only ~5deg at this radius) with margin for alignment
pilot_d         = 2.5;  // ESTIMATE -- confirm the board's actual screw size
ramp_x          = 8;    // print-support taper run, toward +X (blank-side's own
                         // bed/endcap side) -- 12mm boss_h over 8mm run is a ~56deg
                         // overhang (not a full 45deg, but a large improvement over
                         // the original's 90deg sheer cliff); widen if the print
                         // still needs support, watch the font encoder at shelf
                         // x=-35 (only ~+30mm away in this hole-centered frame) if
                         // you do
ramp_w          = 8;    // ramp cross-section width -- doesn't need to match the
                         // wedge's own width, this piece only needs to be a
                         // printable transition, not extra strength

joy_positions = [
    [-hole_dx, front_dy],
    [ hole_dx, front_dy],
    [-hole_dx, back_dy],
    [ hole_dx, back_dy],
];

// 2D wedge, centered on the stick hole's own center (0,0) -- (cx,cy) only
// sets the angle (where the real screw sits); the radial footprint
// (r_inner..r_outer) is fixed regardless of the screw's actual distance
// from center, so material only ever exists outside r_inner -- no
// accidentally-thin crescents from a circle centered too close to the
// hole edge (what the ORIGINAL plain-cylinder bosses did).
module joy_boss_wedge_2d(cx, cy) {
    ang = atan2(cy, cx);
    big = r_outer + 5;
    intersection() {
        difference() {
            circle(r = r_outer);
            circle(r = r_inner);
        }
        polygon(points = [
            [0, 0],
            [big*cos(ang - half_angle), big*sin(ang - half_angle)],
            [big*cos(ang + half_angle), big*sin(ang + half_angle)],
        ]);
    }
}

module joy_boss_dev(cx, cy) {
    // MAIN BODY -- full wedge, full height, TRUE (unshifted) position.
    // This alone gives hole clearance and pilot wall thickness; it must
    // NOT move, since the real board's hole is fixed here.
    translate([0, 0, -wall - boss_h])
    linear_extrude(boss_h)
    joy_boss_wedge_2d(cx, cy);

    // RAMP -- thin X-slices at both ends (matching square_boss()'s own
    // technique exactly), height tapering from full (at the wedge's own
    // edge, r_mid along its center angle) to zero (ramp_x further toward
    // +X). Kept narrow (ramp_w) and thin-in-X (0.01) at BOTH ends
    // specifically so hull() can't bridge back over the wedge's own
    // concave hole-clipped boundary -- that's what broke the first
    // attempt (hull()-ing the FULL wedge shape against a shifted copy of
    // itself reintroduced material into the hole's clearance zone).
    ang = atan2(cy, cx);
    r_mid = (r_inner + r_outer) / 2;
    ex = r_mid * cos(ang);
    ey = r_mid * sin(ang);
    hull() {
        translate([ex - 0.01, ey - ramp_w/2, -wall - boss_h])
        cube([0.01, ramp_w, boss_h]);

        translate([ex + ramp_x, ey - ramp_w/2, -wall - 0.01])
        cube([0.01, ramp_w, 0.01]);
    }
}

module joy_pilot_hole_dev(cx, cy) {
    translate([cx, cy, -wall - boss_h - 0.5])
    cylinder(h = boss_h + 1, d = pilot_d);
}

module joy_stick_hole_dev() {
    translate([0, 0, 0])
    cylinder(h = wall*4, d = joy_stick_d, center = true);
}

module assembly_dev() {
    difference() {
        union() {
            for (p = joy_positions)
                joy_boss_dev(p[0], p[1]);
        }
        joy_stick_hole_dev();
        for (p = joy_positions)
            joy_pilot_hole_dev(p[0], p[1]);
    }
}

module single_dev(i) {
    p = joy_positions[i];
    difference() {
        joy_boss_dev(p[0], p[1]);
        joy_pilot_hole_dev(p[0], p[1]);
    }
}

// Print-ready coupon: a small slab of "shelf" material (plate_w x plate_h,
// plate_t thick) at the shelf-surface reference (z=-wall), with the stick
// hole + all 4 bosses + pilot holes, THEN rotated so the ramp direction
// (local +X, matching blank-side's real bed/endcap side) points straight
// down -- no manual slicer rotation needed, unlike a bare ASSEMBLY export.
// rotate([0,90,0]) maps local +X to new -Z (down): confirmed by direct
// derivation (rotation about Y by 90 deg sends (x,y,z) -> (z,y,-x), so a
// point at local x=X0>0 lands at new z=-X0, i.e. below the origin).
plate_w = 70; plate_h = 60; plate_t = 4;

module printable_dev() {
    rotate([0, 90, 0])
    difference() {
        union() {
            translate([-plate_w/2, -plate_h/2, -wall - plate_t])
            cube([plate_w, plate_h, plate_t]);
            assembly_dev();
        }
        // re-cut the stick + pilot holes: assembly_dev()'s own
        // difference() already relieved the bosses internally, but the
        // NEW plate (unioned in afterward) still needs its own overlapping
        // portion of each hole cut through it too.
        joy_stick_hole_dev();
        for (p = joy_positions)
            joy_pilot_hole_dev(p[0], p[1]);
    }
}

if (PART == "ASSEMBLY") assembly_dev();
else if (PART == "PRINTABLE") printable_dev();
else if (PART == "SINGLE") single_dev(single_which);
