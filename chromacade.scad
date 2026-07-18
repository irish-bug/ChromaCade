/*
 * ChromaCade Synthesizer - V5 Structural Model
 * - Back wall hollowed via inset punch to preserve outer corner rounding.
 * - Mounting bosses sunk by 5mm to accommodate flush back panel.
 * - Back panel upgraded with aligned screw holes.
 *
 * BOM-verified cutout corrections (vs. original V4 paste):
 *   - MX switch holes:   14 → 14.3mm   (FDM tolerance, per three-key-test-mount.scad)
 *   - KY-023 joystick:   d=10 → d=28   (thumb cap ~27mm; d=30 printed, reduced 1mm radius)
 *   - XINYIELE rocker:   d=8  → d=20.5 (0.8" body; printed and confirmed snug fit)
 *   - EC11 encoders:     d=16 → d=7    (M7 bushing OD) + 14.3×14.3 back countersink 1mm deep
 *   - USB-C port:        10×4 → 14×10  (fits cable sheath; metal receptacle is 9.5×3.5mm)
 *   - Speaker grilles:   rect_hex_grill(65,30) → stadium_hex_grill(25.4, 38.1)
 *                        Portrait stadium (1"×1.5") matched to cone area, hex grid inside.
 *   - OLED:              28×15 front window kept; 30×30 back countersink 2mm deep added
 *                        (adjust 30×30 if your Hosyond PCB differs from ~27mm square)
 *   - LED ring:          d=24 front aperture (exposes full 23mm LED circle); d=28 back recess 1mm
 *                        deep (glue gap around ~25.4mm PCB; mounting holes plugged)
 */

$fn = 60;

// --- Global Dimensions (Converted from inches) ---
in2mm = 25.4;
case_w = 7    * in2mm;     // 177.8mm
case_d = 4.5  * in2mm;     // 114.3mm
wall   = 5;                // Chunky 5mm walls

front_h = 1.75 * in2mm;   // 44.45mm
shelf_d = 1.5  * in2mm;   // 38.1mm
shelf_a = 8;               // Degrees tilted forward (down towards front)
panel_l = 2.5  * in2mm;   // 63.5mm
panel_a = 45;              // Degrees slope

// Speaker enclosure & cone dims (measured, converted from inches)
// Enclosure: 1-3/8" × 2-3/4"  =  34.9mm × 69.9mm  (oriented landscape on front wall)
// Cone area: 1" × 1-1/2"      =  25.4mm × 38.1mm
// Grille is a portrait stadium (pill) matched exactly to the cone area.
spk_grille_w = 1.0 * in2mm;  // 25.4mm = 1"   (stadium width  = cone width)
spk_grille_h = 1.5 * in2mm;  // 38.1mm = 1.5" (stadium height = cone height)
spk_cx       = 45;   // speaker centre offset from case centreline (±45mm)

// --- Profile Coordinate Math (Y = depth, Z = height) ---
// Origin is bottom-back (0,0)
p0 = [0, 0];
p1 = [case_d, 0];
p2 = [case_d, front_h];
p3 = [case_d - shelf_d*cos(shelf_a), front_h + shelf_d*sin(shelf_a)];
p4 = [p3[0] - panel_l*cos(panel_a), p3[1] + panel_l*sin(panel_a)];
p5 = [0, p4[1]];

case_h = p4[1];  // Overall height derived from math (~128mm)

// --- Boss Placement Coordinates ---
boss_x     = case_w/2 - wall - 5;
boss_z_top = case_h - wall - 15;
boss_z_bot = wall + 15;
boss_len   = 10;

// --- Assembly ---
assembly();

module assembly() {
    difference() {
        main_chassis();
        hardware_cutouts();
    }

    // Back panel pulled out slightly for visual verification.
    // Change -15 to 0 to see it slide flush against the bosses.
    translate([0, -15, 0])
    color("darkslategrey")
    back_panel();
}

// --- Core Modules ---

module main_chassis() {
    difference() {
        // Outer Shell
        color("ivory")
        rotate([90, 0, 90])
        linear_extrude(case_w, center=true)
        outer_profile();

        // Inner Cavity (shrinks volume inward by 'wall' thickness)
        rotate([90, 0, 90])
        linear_extrude(case_w - (wall * 2), center=true)
        offset(delta = -wall) outer_profile();

        // Punch hole for back panel.
        // Preserves the outer 5mm lip, saving the rounded corners.
        back_hole();
    }

    // Internal Mounting Bosses for Back Panel.
    // Positioned starting at Y = wall to leave exactly enough room for the back panel.

    // Left side bosses (+X)
    translate([boss_x, wall, 0]) {
        translate([0, 0, boss_z_top]) rotate([-90, 0, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot]) rotate([-90, 0, 0]) mounting_boss(boss_len);
    }

    // Right side bosses (-X)
    translate([-boss_x, wall, 0]) {
        translate([0, 0, boss_z_top]) rotate([-90, 0, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot]) rotate([-90, 0, 0]) mounting_boss(boss_len);
    }
}

module outer_profile() {
    pts = [p0, p1, p2, p3, p4, p5];
    offset(r=6) offset(r=-6) polygon(pts);
}

module back_hole() {
    w = case_w - wall*2;
    h = case_h - wall*2;

    translate([0, 0, case_h/2])
    rotate([90, 0, 0])
    linear_extrude(wall * 3, center=true)
    offset(r=3) offset(r=-3) square([w, h], center=true);
}

module mounting_boss(len) {
    difference() {
        cylinder(h=len, d=10, center=false);
        translate([0, 0, -1])
        cylinder(h=len+2, d=3, center=false);  // M3 pilot hole
    }
}

module back_panel() {
    w = case_w - wall*2 - 1;  // 1mm clearance tolerance
    h = case_h - wall*2 - 1;

    // Put in place: flush at Y=0, extending to Y=wall
    translate([0, wall/2, case_h/2])
    difference() {
        // Main Plate
        rotate([90, 0, 0])
        linear_extrude(wall, center=true)
        offset(r=2.5) offset(r=-2.5) square([w, h], center=true);

        // USB-C Port Cutout — 14×10 fits cable sheath (metal receptacle is 9.5×3.5mm)
        translate([0, 0, -h/2 + 15])
        cube([14, wall*4, 10], center=true);

        // Power Switch Cutout (12mm standard toggle/rocker)
        translate([-25, 0, -h/2 + 15])
        rotate([90, 0, 0])
        cylinder(h=wall*4, d=12, center=true);

        // Screw holes (aligned to boss coordinates)
        // Offset Z by -case_h/2 because the panel is translated up by case_h/2
        translate([ boss_x, 0,  boss_z_top - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([ boss_x, 0,  boss_z_bot - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([-boss_x, 0,  boss_z_top - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([-boss_x, 0,  boss_z_bot - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
    }
}

module hardware_cutouts() {

    // 1. Front Wall Cutouts — Speakers
    // Portrait stadium (1"×1.5") matched to cone area. Hex grid inside.
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        translate([-spk_cx, 0, 0]) rotate([0, 0, 90]) stadium_hex_grill(spk_grille_w, spk_grille_h);
        translate([ spk_cx, 0, 0]) rotate([0, 0, 90]) stadium_hex_grill(spk_grille_w, spk_grille_h);
    }

    // 2. Shelf Panel Cutouts
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;

    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {

        // Font & Pitch cluster (Right side: -X)
        translate([-70, 0, 0]) cylinder(h=wall*4, d=28, center=true); // KY-023 joystick (d=28, centred)
        translate([-45, 0, 0]) cylinder(h=wall*4, d=7,  center=true); // EC11 font encoder (M7 bushing)

        // Octave & Rocker cluster (Left side: +X)
        translate([45, 0, 0]) cylinder(h=wall*4, d=7,   center=true); // EC11 octave encoder (M7 bushing)
        translate([70, 0, 0]) cylinder(h=wall*4, d=20.5, center=true); // XINYIELE rocker (0.8" = 20.5mm)

        // EC11 encoder bushing countersinks — interior face, 1mm deep, clears threads
        translate([-45, 0, -(wall - 0.5)]) cube([14.3, 14.3, 1], center=true);
        translate([ 45, 0, -(wall - 0.5)]) cube([14.3, 14.3, 1], center=true);
    }

    // 3. Sloped Panel Cutouts
    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;

    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {

        // 7 Note Buttons — Cherry MX plate cutouts
        // FIX: was 14mm flat — three-key-test-mount.scad proved 14.3mm needed for FDM
        //      clip engagement. Shrink toward 14.0 if switches sit loose on your printer.
        for (i = [-3:3]) {
            translate([i * 19.05, 15, 0])
            cube([14.3, 14.3, wall*4], center=true);
        }

        // OLED display window — Hosyond 0.96" 128×64 SSD1306
        translate([-60, -15, 0])
        cube([28, 15, wall*4], center=true);

        // OLED back countersink — interior face, 2mm deep; adjust 30×30 to match your PCB
        translate([-60, -15, -(wall - 1)])
        cube([30, 30, 2], center=true);

        // LED ring — d=24 exposes full 23mm LED circle (0.5mm margin each side).
        // Ring PCB is ~1" (25.4mm); mounting holes straddle d=24 edge — glue in place.
        translate([65, -15, 0])
        cylinder(h=wall*4, d=24, center=true);

        // LED ring back recess — interior face, 1mm deep; d=28 gives ~1.3mm glue gap
        translate([65, -15, -(wall - 0.5)])
        cylinder(h=1, d=28, center=true);
    }

    // 4. Side Panel Cutouts
    // Volume Potentiometer — Fender 500K (6mm D-shaft; 8mm hole gives easy clearance)
    translate([-case_w/2, case_d/3, case_h/1.5])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=8, center=true);
}

// --- Grill Modules ---

// Toddler-safe rectangular hex grill
// Hole diameter 5.4mm (radius 2.7mm) — under the 6mm toddler-safety limit.
// Use for rectangular speaker enclosures. gw = grille width, gh = grille height.
module rect_hex_grill(gw, gh) {
    hole_radius = 2.7;
    spacing     = 6;

    intersection() {
        cube([gw, gh, wall*4], center=true);
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

// Toddler-safe portrait stadium hex grill.
// gw = total width (= semicircle diameter); gh = total height.
// Two semicircular caps (r = gw/2) joined by a rectangle gh-gw tall.
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

// Original circular grill — kept for reference, not used in main assembly.
module hex_grill(diameter) {
    hole_radius = 2.7;
    spacing     = 6;

    intersection() {
        cylinder(h=wall*4, d=diameter, center=true);
        union() {
            for (x = [-diameter/2 : spacing : diameter/2]) {
                for (y = [-diameter/2 : spacing*0.866 : diameter/2]) {
                    x_offset = x + (round(y/(spacing*0.866)) % 2) * (spacing/2);
                    translate([x_offset, y, 0])
                    cylinder(h=wall*5, r=hole_radius, $fn=6, center=true);
                }
            }
        }
    }
}
