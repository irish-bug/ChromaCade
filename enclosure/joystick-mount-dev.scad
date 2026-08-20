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
// the final joy_boss_*/joy_gimbal_* constants and modules back into
// chromacade-blank-side.scad's joystick_mount_bosses()/
// joystick_mount_pilot_holes() (and chromacade-fit-check.scad's mirrored
// copy) to replace the removed originals.
//
// WHY THE ORIGINAL RAMP DIDN'T ACTUALLY WORK: chromacade-blank-side.scad
// prints with its own +X endcap face-down on the bed -- print-vertical =
// global X, and BLANK-SIDE SPECIFICALLY builds toward -X as printing
// proceeds (own_mount_boss()'s comment: bosses there extend "toward +X,
// this piece's own bed/endcap side"). The shelf's local frame only rotates
// about the GLOBAL X axis (rotate([-shelf_a,0,0])), so local X *is* global
// X unchanged -- tapering a shape uniformly along *local Z* (the first
// attempt) doesn't taper it along the axis that actually matters for
// printability at all. A boss needs to go from a THIN, X-shifted sliver
// (printed early/near the bed, high X) to its FULL true-position
// cross-section (printed late, low X) -- exactly like square_boss()'s and
// own_mount_boss()'s existing ramps in the real files.
//
// REDESIGNED AGAIN 2026-08-19 (second pass) -- the first ramped version
// (a hole-clipped wedge, r_inner..r_outer, angularly clipped per boss)
// fixed the print-support problem but, per direct feedback, still didn't
// remove any material from the joystick's actual moving space: clipping
// each boss against the flat 27mm hole radius only protects the visible
// stick opening, not the gimbal mechanism's real swept volume underneath
// the board, which isn't flat/cylindrical.
//
// THE DESIGN HERE:
//   1. Each boss is a SIMPLE post -- constant ramp_w x ramp_w
//      cross-section, no wedge/angular-clipping math at all -- built with
//      the exact same thin-slice hull() ramp technique as before (full
//      height at the board's TRUE pilot position, tapering to zero height
//      at a point shifted ramp_x toward +X for print support). No radial
//      shift, no hole-radius clipping -- the boss just reaches straight
//      from the true pilot position back to the shelf, angled only for
//      printability.
//   2. A SPHERE (joy_gimbal_clearance_dev(), diameter joy_gimbal_d)
//      centered on the stick hole's own center, subtracted from the whole
//      assembly, models the joystick's real gimbal swing far more
//      accurately than clipping against the flat hole ever could: at the
//      shelf surface it's slightly SMALLER than the stick hole itself (so
//      it removes nothing new above the shelf -- the existing hole cut
//      already reaches further there), but below the shelf its curved
//      surface reaches sideways into each post's inner corner (the side
//      facing the hole), exactly where the gimbal actually needs to swing
//      through. Verified numerically (see git history / commit message)
//      that this reaches every post's true-position end by 0.4-4.6mm and
//      partially reaches the shifted/ramped end for the two posts nearest
//      center (front-left, back-left) -- all four keep real material on
//      their outward (away-from-hole) side either way, which is what
//      actually carries the screw load; the side facing the hole was never
//      load-bearing.
//
// HOW TO USE
//   - PART = "ASSEMBLY" shows all 4 posts + the stick hole + the gimbal
//     sphere cut together, no surrounding plate (for a quick look, not for
//     printing directly).
//   - PART = "SINGLE" isolates one post (see single_which below) for a
//     close look.
//   - PART = "PRINTABLE" is the actual print-ready coupon -- a small slab
//     of "shelf" material with the stick hole + all 4 posts, ALREADY
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
pilot_d     = 2.5;  // ESTIMATE -- confirm the board's actual screw size

// --- Post shape parameters -- THIS is what you're iterating on ---
ramp_x = 8; // print-support taper run, toward +X (blank-side's own
            // bed/endcap side) -- 12mm boss_h over 8mm run is a ~56deg
            // overhang (not a full 45deg, but a large improvement over a
            // sheer 90deg cliff); widen if the print still needs support,
            // watch the font encoder at shelf x=-35 (only ~+30mm away in
            // this hole-centered frame) if you do
ramp_w = 8; // post cross-section, both ends -- sized for M2.5 (pilot_d
            // 2.5mm) wall thickness before the gimbal sphere carves in

// --- Gimbal clearance ---
joy_gimbal_d = 26; // sphere diameter -- models the joystick's real
                    // mechanical swing, centered on the stick hole's own
                    // center at the shelf surface (z=-wall). Deliberately
                    // smaller than joy_stick_d (27mm) so it removes
                    // nothing new above the shelf (the existing stick-hole
                    // cut already reaches further there) -- all its real
                    // effect is below the shelf, carving into whichever
                    // post material happens to intrude on the gimbal's
                    // actual swept volume.

joy_positions = [
    [-hole_dx, front_dy],
    [ hole_dx, front_dy],
    [-hole_dx, back_dy],
    [ hole_dx, back_dy],
];

// Simple post: thin X-slices at both ends (matching square_boss()'s own
// technique), height tapering from full (at the board's true pilot
// position) to zero (ramp_x further toward +X). No hole-radius clipping
// at all -- the gimbal sphere (below) is what actually keeps this clear
// of the joystick's moving parts, more accurately than any flat clip
// could.
module joy_boss_dev(cx, cy) {
    hull() {
        translate([cx - 0.005, cy - ramp_w/2, -wall - boss_h])
        cube([0.01, ramp_w, boss_h]);

        translate([cx + ramp_x - 0.005, cy - ramp_w/2, -wall - 0.01])
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

module joy_gimbal_clearance_dev() {
    translate([0, 0, -wall])
    sphere(d = joy_gimbal_d);
}

module assembly_dev() {
    difference() {
        union() {
            for (p = joy_positions)
                joy_boss_dev(p[0], p[1]);
        }
        joy_stick_hole_dev();
        joy_gimbal_clearance_dev();
        for (p = joy_positions)
            joy_pilot_hole_dev(p[0], p[1]);
    }
}

module single_dev(i) {
    p = joy_positions[i];
    difference() {
        joy_boss_dev(p[0], p[1]);
        joy_gimbal_clearance_dev();
        joy_pilot_hole_dev(p[0], p[1]);
    }
}

// Print-ready coupon: a small slab of "shelf" material (plate_w x plate_h,
// plate_t thick) at the shelf-surface reference (z=-wall), with the stick
// hole + gimbal sphere + all 4 posts + pilot holes, THEN rotated so the
// ramp direction (local +X, matching blank-side's real bed/endcap side)
// points straight down -- no manual slicer rotation needed, unlike a bare
// ASSEMBLY export. rotate([0,90,0]) maps local +X to new -Z (down):
// confirmed by direct derivation (rotation about Y by 90 deg sends
// (x,y,z) -> (z,y,-x), so a point at local x=X0>0 lands at new z=-X0, i.e.
// below the origin).
plate_w = 70; plate_h = 60; plate_t = 4;

module printable_dev() {
    rotate([0, 90, 0])
    difference() {
        union() {
            translate([-plate_w/2, -plate_h/2, -wall - plate_t])
            cube([plate_w, plate_h, plate_t]);
            assembly_dev();
        }
        // re-cut the stick/gimbal/pilot holes: assembly_dev()'s own
        // difference() already relieved the posts internally, but the
        // NEW plate (unioned in afterward) still needs its own overlapping
        // portion of each cut through it too.
        joy_stick_hole_dev();
        joy_gimbal_clearance_dev();
        for (p = joy_positions)
            joy_pilot_hole_dev(p[0], p[1]);
    }
}

if (PART == "ASSEMBLY") assembly_dev();
else if (PART == "PRINTABLE") printable_dev();
else if (PART == "SINGLE") single_dev(single_which);
