/*
 * ChromaCade Synthesizer - Main Housing
 * 
 * Version 6
 * - V6: Upgraded speaker grilles to stepped flush-mount printable inserts with 
 *       screw flanges and blind pilot holes on the interior of the case wall.
 *       (Designed to print upright with supports inside the case cavity).
 *       Split into multiple files (housing, config, back-panel, inserts).
 * - V5: Corrected XINYIELE rocker switch cutout to 0.8" (20.32mm).
 * - V4: Hollowed back wall for flush panel, sunken mounting bosses.
 *       Full BOM audit: corrected MX (14.3), joystick (d=30), encoder (d=7), USB-C (10x4).
 * - V2: Added shelf tilt geometry (8 degrees) and access lid.
 */

include <chromacade-config.scad>
use <back-panel.scad>
use <speaker-grille-insert.scad>

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
    back_panel_assembled();
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

module hardware_cutouts() {

    // 1. Front Wall Cutouts — Speakers (Stepped for flush inserts)
    // 65x30mm windows. Grilles are inserted from the inside to sit flush.
    // Includes blind pilot holes on the interior wall to screw the flange in.
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        for (sx = [-spk_cx, spk_cx]) {
            translate([sx, 0, 0]) {
                // Main window
                cube([spk_grille_w, spk_grille_h, wall*4], center=true);
                
                // Pilot holes for flange screws (starts 2mm from front face, extends inside)
                for (cx = [-(spk_grille_w/2 + 4), (spk_grille_w/2 + 4)]) {
                    for (cy = [-(spk_grille_h/2 + 4), (spk_grille_h/2 + 4)]) {
                        translate([cx, cy, 2])
                        cylinder(h=wall*2, d=2, center=false);
                    }
                }
            }
        }
    }

    // 2. Shelf Panel Cutouts
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;

    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {

        // Font & Pitch cluster (Right side: -X)
        translate([-70, 0, 0]) cylinder(h=wall*4, d=30, center=true); // KY-023 joystick thumb cap
        translate([-45, 0, 0]) cylinder(h=wall*4, d=7,  center=true); // EC11 font encoder (M7 bushing)

        // Octave & Rocker cluster (Left side: +X)
        translate([45, 0, 0]) cylinder(h=wall*4, d=7,  center=true); // EC11 octave encoder (M7 bushing)
        translate([70, 0, 0]) cylinder(h=wall*4, d=20.32, center=true); // XINYIELE 3-way rocker (0.8" body)
    }

    // 3. Sloped Panel Cutouts
    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;

    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {

        // 7 Note Buttons — Cherry MX plate cutouts
        // Shrink toward 14.0 if switches sit loose on your printer.
        for (i = [-3:3]) {
            translate([i * 19.05, 15, 0])
            cube([14.3, 14.3, wall*4], center=true);
        }

        // OLED display window — Hosyond 0.96" 128×64 SSD1306
        translate([-60, -15, 0])
        cube([28, 15, wall*4], center=true);

        // LED Ring passthrough — WS2812 7-LED ring
        translate([65, -15, 0])
        cylinder(h=wall*4, d=24, center=true);
    }

    // 4. Side Panel Cutouts
    // Volume Potentiometer — Fender 500K (6mm D-shaft; 8mm hole gives easy clearance)
    translate([-case_w/2, case_d/3, case_h/1.5])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=8, center=true);
}
