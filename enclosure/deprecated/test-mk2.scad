/*
 * ChromaCade — Mk 2 Component Fit Test Plates
 *
 * Tests only the cutouts revised since test-component-holes.scad.
 * Print all 3 before committing to the full case print.
 *
 * Plate   Component           What changed / what to check
 * ─────────────────────────────────────────────────────────────────────────────
 *   A     EC11 encoder        ø7mm through + 13×13mm back countersink (~3mm deep)
 *                             Check: bushing seats flush, nut threads catch in pocket
 *   C     WS2812 LED ring     ø24mm front aperture + ø28mm back recess (~3mm deep)
 *                             Check: LED circle fully visible; PCB sits in recess, glue gap ~1.3mm
 *   D     0.96" OLED          28×15mm front window (2mm off-center) + 30×30mm back
 *                             countersink (~3mm deep) -- all confirmed correct 2026-08-19
 *                             Check: viewable area fully open; module PCB drops into pocket squarely
 *
 * Plate B (KY-023 joystick mounting bosses) removed 2026-08-19 -- see the
 * comment above test_led_ring_mk2() below, it moved to its own isolated
 * file (enclosure/joystick-mount-dev.scad) since its print orientation
 * doesn't fit this file's flat-plate convention.
 *
 * Plate E (old single-cone stadium speaker grille) removed 2026-08-19 -- the
 * speaker design changed to a dual-cone housing with round grilles (see
 * chromacade-blank-side.scad's spk_cone_d/spk_cone_offset); the old stadium
 * shape no longer matches anything real. No replacement test plate yet.
 *
 * Print orientation: BACK FACE UP (countersinks and recesses face up toward you).
 * Insert parts from the underside to test fit and thread engagement.
 *
 * Bed footprint (PART="ALL"): ~86mm × 94mm — fits an 8"×8" bed with margin.
 * Set PART below to print just one plate instead of all 3.
 */

/* [Render Selection] */
PART = "ALL";
// [ALL, A, C, D]

$fn = 60;

wall   = 5;      // matches case wall thickness

// ─── A: EC11 Rotary Encoder ───────────────────────────────────────────────────
module test_encoder_mk2() {
    pw = 40; ph = 40;
    difference() {
        linear_extrude(wall) square([pw, ph], center=true);
        // M7 bushing through-hole — enters from bottom (front of panel)
        translate([0, 0, wall/2])
            cylinder(h=wall*3, d=7, center=true);
        // Back countersink — 13×13mm, centered on the back face (~3mm effective depth)
        translate([0, 0, wall])
            cube([13, 13, 6], center=true);
    }
}

// Plate B (KY-023 joystick mounting bosses) removed 2026-08-19 -- pulled
// into its own isolated file, enclosure/joystick-mount-dev.scad, per
// direct feedback that the straight-up-and-down bosses here got in the
// way of the joystick's range of motion, didn't have enough material
// around two of the four screws, and (found while redesigning) weren't
// actually support-free to print either. That file's ramp direction is
// tied to blank-side's real print-vertical axis in a way that doesn't fit
// this plate's flat, Z-thickness convention -- see its own header comment
// for why it needs a different print orientation than plates A/C/D below,
// and its own "PRINTABLE" mode for an actual print-ready coupon instead of
// trying to force this design back into a plate here.

// ─── C: WS2812 7-LED Ring ─────────────────────────────────────────────────────
module test_led_ring_mk2() {
    pw = 40; ph = 40;
    difference() {
        linear_extrude(wall) square([pw, ph], center=true);
        // Front aperture — d=24 exposes full 23mm LED circle (0.5mm margin)
        translate([0, 0, wall/2])
            cylinder(h=wall*3, d=24, center=true);
        // Back recess — d=28, centered on the back face (~3mm effective depth);
        // PCB ~25.4mm glues in with ~1.3mm gap
        translate([0, 0, wall])
            cylinder(h=6, d=28, center=true);
    }
}

// ─── D: 0.96" OLED Display ────────────────────────────────────────────────────
module test_oled_mk2() {
    pw = 44; ph = 44;
    difference() {
        linear_extrude(wall) square([pw, ph], center=true);
        // Front window — 28×15mm viewable area, offset 2mm off-center
        translate([0, 2, wall/2])
            cube([28, 15, wall*3], center=true);
        // Back countersink — 30×30mm, centered on the back face (~3mm effective depth)
        translate([0, 0, wall])
            cube([30, 30, 6], center=true);
    }
}

// ─── Layout ───────────────────────────────────────────────────────────────────
//  Row 0 (Y=0):     A Encoder    C LED Ring
//  Row 1 (below):   D OLED

pitch_sm = 40 + 6;  // 46mm between 40mm-plate centres

// Row 1 Y: gap from bottom edge of row 0 plates (A/C both 40mm -> half=20)
// to top of row 1 plates (D, 44mm tall -> half=22)
row1_y = -(20 + 6 + 22);  // −48mm

if (PART == "ALL") {
    translate([0,           0,       0]) test_encoder_mk2();
    translate([pitch_sm,    0,       0]) test_led_ring_mk2();
    translate([0,           row1_y,  0]) test_oled_mk2();
}
else if (PART == "A") test_encoder_mk2();
else if (PART == "C") test_led_ring_mk2();
else if (PART == "D") test_oled_mk2();
