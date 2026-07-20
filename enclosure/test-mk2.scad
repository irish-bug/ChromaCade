/*
 * ChromaCade — Mk 2 Component Fit Test Plates
 *
 * Tests only the cutouts revised since test-component-holes.scad.
 * Print all 5 before committing to the full case print.
 *
 * Plate   Component           What changed / what to check
 * ─────────────────────────────────────────────────────────────────────────────
 *   A     EC11 encoder        ø7mm through + 14.3×14.3mm back countersink 1mm deep
 *                             Check: bushing seats flush, nut threads catch in pocket
 *   B     KY-023 joystick     ø28mm (was ø30)
 *                             Check: thumb cap clears, full range of motion, no rubbing
 *   C     WS2812 LED ring     ø24mm front aperture + ø28mm back recess 1mm deep
 *                             Check: LED circle fully visible; PCB sits in recess, glue gap ~1.3mm
 *   D     0.96" OLED          28×15mm front window + 30×30mm back countersink 2mm deep
 *                             Check: viewable area fully open; module PCB drops into pocket squarely
 *   E     Speaker grille      1"×1.5" portrait stadium, toddler-safe ø5.4mm hex holes
 *                             Check: pattern looks clean, overall shape correct
 *
 * Print orientation: BACK FACE UP (countersinks and recesses face up toward you).
 * Insert parts from the underside to test fit and thread engagement.
 *
 * Bed footprint: ~138mm × 105mm — fits an 8"×8" bed with margin.
 */

$fn = 60;

wall   = 5;      // matches case wall thickness
lbl_h  = 0.5;
in2mm  = 25.4;

// ─── Label helper ─────────────────────────────────────────────────────────────
module top_label(txt, pw, ph) {
    translate([0, ph/2 - 6, wall])
    linear_extrude(lbl_h)
        text(txt, size=5, halign="center", valign="center");
}

// ─── A: EC11 Rotary Encoder ───────────────────────────────────────────────────
module test_encoder_mk2() {
    pw = 40; ph = 40;
    difference() {
        union() {
            linear_extrude(wall) square([pw, ph], center=true);
            top_label("ENC", pw, ph);
        }
        // M7 bushing through-hole — enters from bottom (front of panel)
        translate([0, 0, wall/2])
            cylinder(h=wall*3, d=7, center=true);
        // Back countersink — 14.3×14.3mm, 1mm deep; nut threads into this pocket
        translate([0, 0, wall - 0.5])
            cube([14.3, 14.3, 1], center=true);
    }
}

// ─── B: KY-023 Joystick ───────────────────────────────────────────────────────
module test_joystick_mk2() {
    pw = 40; ph = 40;
    difference() {
        linear_extrude(wall) square([pw, ph], center=true);
        translate([0, 0, wall/2])
            cylinder(h=wall*3, d=28, center=true);
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
        // Front window — 28×15mm viewable area
        translate([0, 0, wall/2])
            cube([28, 15, wall*3], center=true);
        // Back countersink — 30×30mm, 2mm deep; module PCB drops in from above
        translate([0, 0, wall - 1])
            cube([30, 30, 2], center=true);
    }
}

// ─── E: Speaker Grille ────────────────────────────────────────────────────────
module test_speaker_mk2() {
    gw = 1.0 * in2mm;   // 25.4mm — stadium width
    gh = 1.5 * in2mm;   // 38.1mm — stadium height
    pw = gw + 10;       // 35.4mm — plate width
    ph = gh + 20;       // 58.1mm — plate height (extra room for label above grill)

    difference() {
        union() {
            linear_extrude(wall) square([pw, ph], center=true);
            top_label("SPK", pw, ph);
        }
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

translate([0,           0,       0]) test_encoder_mk2();
translate([pitch_sm,    0,       0]) test_joystick_mk2();
translate([pitch_sm*2,  0,       0]) test_led_ring_mk2();
translate([0,           row1_y,  0]) test_oled_mk2();
translate([50,          row1_y,  0]) test_speaker_mk2();
