// ChromaCade - Joystick (KY-023) mounting boss development, in isolation
//
// Pulled out of chromacade-blank-side.scad 2026-08-19 per direct feedback
// on the first printed test: straight-up-and-down bosses (see git history,
// commit a4f6a10, joystick_mount_bosses() before this date) got in the way
// of the joystick's own range of motion, two of the four didn't have
// enough material to fully encase their screws (would break under real
// toddler use). Work on the boss shape HERE, in isolation, until it's
// right, then port the final joy_boss_*/joy_gimbal_* constants and modules
// back into chromacade-blank-side.scad's joystick_mount_bosses()/
// joystick_mount_pilot_holes() (and chromacade-fit-check.scad's mirrored
// copy) to replace the removed originals.
//
// Two intermediate redesigns (a hull()-ramped wedge, then a plain
// constant-width post + an approximate 26mm-diameter sphere cut) were
// tried and abandoned in this file's history -- see git log if curious.
// Both added print-support/taper machinery the actual printed part never
// needed: the physically-printed a4f6a10 bosses are plain vertical
// cylinders that print fine standing straight up off the shelf plate, no
// ramp required.
//
// CURRENT DESIGN (2026-08-19, third pass) -- per direct instruction: go
// back to exactly what got printed (a4f6a10's plain d=6mm, h=12mm straight
// cylindrical bosses, no taper/wedge at all) and add ONE clean sphere cut,
// radius joy_gimbal_r = 13.5mm, centered precisely on the stick hole's own
// center -- meaning the true center of the cylindrical hole through the
// shelf material: (0, 0) in XY, and Z at HALF the shelf thickness
// (-wall/2), not the interior face. (An earlier attempt at this sphere
// cut, sphere-removed.stl, was hand-modeled imprecisely by eye as a
// conceptual sketch, not to be measured/reverse-engineered -- this is the
// precise version of that same idea.) The sphere models the joystick's
// real gimbal swing: at 27mm diameter it matches the stick hole's own
// diameter, so it carves a clean hemisphere-ish bite out of whichever
// boss material intrudes on the gimbal's actual swept volume below the
// shelf, without touching anything above the shelf (the stick hole cut
// already owns that space).
//
// HOW TO USE
//   - PART = "ASSEMBLY" shows all 4 posts + the stick hole + the gimbal
//     sphere cut together, no surrounding plate (for a quick look, not for
//     printing directly).
//   - PART = "SINGLE" isolates one post (see single_which below) for a
//     close look.
//   - PART = "PRINTABLE" is the print-ready coupon -- a small slab of
//     "shelf" material with the stick hole + all 4 posts, standing
//     straight up off the plate (no support needed, no reorientation
//     needed -- print exactly as previewed).
$fn = 60;

/* [Render Selection] */
PART = "ASSEMBLY";
// [ASSEMBLY, SINGLE, PRINTABLE]
single_which = 0; // 0-3, only used when PART="SINGLE" -- see joy_positions below

wall = 5; // matches case wall thickness

// --- Real hardware measurements (2026-08-18/19, see chromacade-blank-side.scad) ---
joy_stick_d = 27;   // CONFIRMED 2026-08-19 -- no longer under test
hole_dx     = 9;    // board hole +/-9mm left-right, both pairs
front_dy    = 14;   // front pair (toward speaker wall), 14mm off joystick center
back_dy     = -12.5; // back pair (toward device center), 12.5mm off center
boss_h      = 12;   // MEASURED-derived standoff height (matches the board+header stack)
pilot_d     = 2.5;  // ESTIMATE -- confirm the board's actual screw size

// --- Post shape -- back to exactly what was printed (a4f6a10): plain
// vertical cylinders, no taper/wedge ---
boss_d = 6; // ESTIMATE -- same as the physically-printed original

// --- Gimbal clearance ---
joy_gimbal_r = 13.5; // sphere radius (27mm diameter, matching joy_stick_d)
                      // centered on the stick hole's own true center: (0,0)
                      // in XY, and half the shelf thickness down in Z
                      // (-wall/2) -- the center of the hole through the
                      // material, not the interior face. Carves into
                      // whichever boss material intrudes on the joystick's
                      // real gimbal swing below the shelf; touches nothing
                      // above the shelf since the stick hole already owns
                      // that space at the same 27mm diameter.

joy_positions = [
    [-hole_dx, front_dy],
    [ hole_dx, front_dy],
    [-hole_dx, back_dy],
    [ hole_dx, back_dy],
];

// Plain vertical cylinder, exactly matching what was printed (a4f6a10).
module joy_boss_dev(cx, cy) {
    translate([cx, cy, -wall - boss_h])
    cylinder(h = boss_h + 0.5, d = boss_d);
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
    translate([0, 0, -wall/2])
    sphere(r = joy_gimbal_r);
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

// Print-ready coupon: a small slab of "shelf" material (plate_w x plate_h),
// with the stick hole + gimbal sphere + all 4 posts + pilot holes standing
// straight up -- no rotation needed, prints exactly as previewed, no
// support (each post is a plain vertical cylinder off a flat base). Sized
// to the posts' actual (now-symmetric, no ramp) X-spread: +/-hole_dx (9mm)
// plus ~4mm margin each side for the post's own half-width -> plate_w=44,
// centered at x=0. Y keeps front_dy/back_dy's natural (14 / -12.5)
// near-symmetric spread, also centered at y=0.
//
// Thickness is wall (5mm), NOT an arbitrary plate_t, and it spans z=0
// (exterior/stick-hole face) down to z=-wall (interior face, where the
// posts attach) -- matching the real shelf's actual wall thickness and
// position exactly. Getting this wrong (an earlier version used a
// mismatched 4mm-thick plate offset one full wall-thickness further in)
// made each boss's small 0.5mm CSG-safety overlap (see joy_boss_dev())
// visibly poke through the plate's own top surface -- a modeling artifact
// of the wrong-sized test plate, not something that happens on the real
// 5mm-thick shelf wall, where that same 0.5mm overlap stays buried 4.5mm
// short of the real exterior face. Confirmed by checking the plate here:
// with the correct thickness/position, nothing exceeds z=-wall+0.5, still
// comfortably short of z=0.
plate_w = 44; plate_h = 44;

module printable_dev() {
    difference() {
        union() {
            translate([-plate_w/2, -plate_h/2, -wall])
            cube([plate_w, plate_h, wall]);
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
