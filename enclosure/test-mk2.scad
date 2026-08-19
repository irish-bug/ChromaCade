/*
 * ChromaCade — Mk 2 Component Fit Test Plates
 *
 * Tests only the cutouts revised since test-component-holes.scad.
 * Print all 5 before committing to the full case print.
 *
 * Plate   Component           What changed / what to check
 * ─────────────────────────────────────────────────────────────────────────────
 *   A     EC11 encoder        ø7mm through + 13×13mm back countersink (~1.5mm deep)
 *                             Check: bushing seats flush, nut threads catch in pocket
 *   B     KY-023 joystick     ø26.5mm stick hole (was ø28, before the mounting
 *                             bosses existed) + 4 mounting bosses (12mm tall,
 *                             ø6mm, ø2.5mm pilot) at the real board's 4 corner
 *                             holes -- MEASURED 2026-08-18, see
 *                             chromacade-blank-side.scad's joystick_boss_xy()
 *                             Check: thumb cap clears, full range of motion, no
 *                             rubbing, AND that the board's real corner holes
 *                             actually land on the 4 printed bosses -- the two
 *                             bosses nearest center are close enough to the
 *                             hole edge that they may print thin/undercut,
 *                             confirm they're solid before trusting this
 *   C     WS2812 LED ring     ø24mm front aperture + ø28mm back recess 1mm deep
 *                             Check: LED circle fully visible; PCB sits in recess, glue gap ~1.3mm
 *   D     0.96" OLED          28×15mm front window (2mm off-center) + 30×30mm back
 *                             countersink (~1.5mm deep)
 *                             Check: viewable area fully open; module PCB drops into pocket squarely
 *   E     Speaker grille      1"×1.5" portrait stadium, toddler-safe ø5.4mm hex holes
 *                             Check: pattern looks clean, overall shape correct
 *
 * Print orientation: BACK FACE UP (countersinks and recesses face up toward you).
 * Insert parts from the underside to test fit and thread engagement.
 *
 * Bed footprint (PART="ALL"): ~138mm × 105mm — fits an 8"×8" bed with margin.
 * Set PART below to print just one plate instead of all 5 -- e.g. "B" for a
 * fast joystick-only iteration.
 */

/* [Render Selection] */
PART = "ALL";
// [ALL, A, B, C, D, E]

$fn = 60;

wall   = 5;      // matches case wall thickness
in2mm  = 25.4;

// ─── A: EC11 Rotary Encoder ───────────────────────────────────────────────────
module test_encoder_mk2() {
    pw = 40; ph = 40;
    difference() {
        linear_extrude(wall) square([pw, ph], center=true);
        // M7 bushing through-hole — enters from bottom (front of panel)
        translate([0, 0, wall/2])
            cylinder(h=wall*3, d=7, center=true);
        // Back countersink — 13×13mm, centered on the back face (~1.5mm effective depth)
        translate([0, 0, wall])
            cube([13, 13, 3], center=true);
    }
}

// ─── B: KY-023 Joystick ───────────────────────────────────────────────────────
// Stick hole under active test (26.5mm, see header) plus the 4 real mounting
// bosses -- board is 26x33mm, front pair (toward the speaker wall) 14mm off
// center, back pair 12.5mm off center, both pairs +/-9mm left-right. Boss
// positions/sizes MUST stay in sync with chromacade-blank-side.scad's
// joystick_boss_xy()/joy_boss_h/joy_boss_d/joy_pilot_d.
module test_joystick_mk2() {
    pw = 40; ph = 40;
    hole_d  = 26.5; // UNDER TEST -- see header note
    boss_h  = 12;
    boss_d  = 6;    // ESTIMATE
    pilot_d = 2.5;  // ESTIMATE -- confirm the board's actual screw size
    hole_dx = 9;
    front_dy = 14;
    back_dy  = -12.5;
    boss_xy = [
        [-hole_dx, front_dy], [hole_dx, front_dy],
        [-hole_dx, back_dy],  [hole_dx, back_dy],
    ];

    difference() {
        union() {
            difference() {
                linear_extrude(wall) square([pw, ph], center=true);
                translate([0, 0, wall/2])
                    cylinder(h=wall*3, d=hole_d, center=true);
            }
            for (p = boss_xy)
                translate([p[0], p[1], wall])
                    cylinder(h = boss_h, d = boss_d);
        }
        for (p = boss_xy)
            translate([p[0], p[1], wall - 0.5])
                cylinder(h = boss_h + 1, d = pilot_d);
    }
}

// ─── C: WS2812 7-LED Ring ─────────────────────────────────────────────────────
module test_led_ring_mk2() {
    pw = 40; ph = 40;
    difference() {
        linear_extrude(wall) square([pw, ph], center=true);
        // Front aperture — d=24 exposes full 23mm LED circle (0.5mm margin)
        translate([0, 0, wall/2])
            cylinder(h=wall*3, d=24, center=true);
        // Back recess — d=28, 1mm deep; PCB ~25.4mm glues in with ~1.3mm gap
        translate([0, 0, wall - 0.5])
            cylinder(h=1, d=28, center=true);
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
        // Back countersink — 30×30mm, centered on the back face (~1.5mm effective depth)
        translate([0, 0, wall])
            cube([30, 30, 3], center=true);
    }
}

// ─── E: Speaker Grille ────────────────────────────────────────────────────────
module test_speaker_mk2() {
    gw = 1.0 * in2mm;   // 25.4mm — stadium width
    gh = 1.5 * in2mm;   // 38.1mm — stadium height
    pw = gw + 10;       // 35.4mm — plate width
    ph = gh + 20;       // 58.1mm — plate height (margin around the grille)

    difference() {
        linear_extrude(wall) square([pw, ph], center=true);
        translate([0, 0, wall/2])
            stadium_hex_grill_cut(gw, gh);
    }
}

// Stadium hex grill cutter — mirrors chromacade.scad, used inside difference().
module stadium_hex_grill_cut(gw, gh) {
    r          = gw / 2;
    cap_offset = (gh - gw) / 2;
    hole_radius = 2.7;
    spacing    = 6;

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

// ─── Layout ───────────────────────────────────────────────────────────────────
//  Row 0 (Y=0):     A Encoder    B Joystick    C LED Ring
//  Row 1 (below):   D OLED       E Speaker

pitch_sm = 40 + 6;  // 46mm between 40mm-plate centres

// Row 1 Y: gap from bottom edge of row 0 plates (±20mm) to top of row 1 plates
row1_y = -(20 + 6 + 58.1/2);  // −55.05mm — driven by tallest row-1 plate (speaker)

if (PART == "ALL") {
    translate([0,           0,       0]) test_encoder_mk2();
    translate([pitch_sm,    0,       0]) test_joystick_mk2();
    translate([pitch_sm*2,  0,       0]) test_led_ring_mk2();
    translate([0,           row1_y,  0]) test_oled_mk2();
    translate([50,          row1_y,  0]) test_speaker_mk2();
}
else if (PART == "A") test_encoder_mk2();
else if (PART == "B") test_joystick_mk2();
else if (PART == "C") test_led_ring_mk2();
else if (PART == "D") test_oled_mk2();
else if (PART == "E") test_speaker_mk2();
