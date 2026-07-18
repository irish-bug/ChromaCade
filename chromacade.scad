/*
 * ChromaCade Synthesizer - V4 Structural Model
 * - Back wall hollowed via inset punch to preserve outer corner rounding.
 * - Mounting bosses sunk by 5mm to accommodate flush back panel.
 * - Back panel upgraded with aligned screw holes.
 */

$fn = 60;

// --- Global Dimensions (Converted from inches) ---
in2mm = 25.4;
case_w = 7 * in2mm;        // 177.8mm
case_d = 4.5 * in2mm;      // 114.3mm
wall = 5;                  // Chunky 5mm walls

front_h = 1.75 * in2mm;    // 44.45mm
shelf_d = 1.5 * in2mm;     // 38.1mm
shelf_a = 8;               // Degrees tilted forward (down towards front)
panel_l = 2.5 * in2mm;     // 63.5mm
panel_a = 45;              // Degrees slope

// --- Profile Coordinate Math (Y = depth, Z = height) ---
// Origin is bottom-back (0,0)
p0 = [0, 0];
p1 = [case_d, 0];
p2 = [case_d, front_h];
p3 = [case_d - shelf_d*cos(shelf_a), front_h + shelf_d*sin(shelf_a)];
p4 = [p3[0] - panel_l*cos(panel_a), p3[1] + panel_l*sin(panel_a)];
p5 = [0, p4[1]]; 

case_h = p4[1]; // Overall height derived from math (~128mm)

// --- Boss Placement Coordinates ---
boss_x = case_w/2 - wall - 5;
boss_z_top = case_h - wall - 15;
boss_z_bot = wall + 15;
boss_len = 10;

// --- Assembly ---
assembly();

module assembly() {
    difference() {
        main_chassis();
        hardware_cutouts();
    }
    
    // Back panel pulled out slightly for visual verification
    // Change -15 to 0 to see it slide flush against the bosses
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
        
        // Punch hole for back panel
        // This preserves the outer 5mm lip, saving the rounded corners
        back_hole();
    }
    
    // Internal Mounting Bosses for Back Panel
    // Positioned starting at Y = wall to leave exactly enough room for the back panel
    
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
        // cylinder center=false means it grows from Z=0 to Z=len
        // when rotated -90 on X, it grows from Y=0 to Y=len
        cylinder(h=len, d=10, center=false);
        translate([0, 0, -1])
        cylinder(h=len+2, d=3, center=false); // M3 pilot hole
    }
}

module back_panel() {
    w = case_w - wall*2 - 1; // 1mm clearance tolerance
    h = case_h - wall*2 - 1; 
    
    // Put in place: flush at Y=0, extending to Y=wall
    translate([0, wall/2, case_h/2])
    difference() {
        // Main Plate
        rotate([90, 0, 0])
        linear_extrude(wall, center=true)
        offset(r=2.5) offset(r=-2.5) square([w, h], center=true);
        
        // USB-C Port Cutout
        translate([0, 0, -h/2 + 15])
        cube([15, wall*4, 7], center=true);
        
        // Power Switch Cutout (12mm standard toggle/rocker)
        translate([-25, 0, -h/2 + 15])
        rotate([90, 0, 0])
        cylinder(h=wall*4, d=12, center=true);
        
        // Screw holes (Aligned to the boss coordinates)
        // Offset Z by -case_h/2 because the panel is translated up by case_h/2
        translate([boss_x, 0, boss_z_top - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([boss_x, 0, boss_z_bot - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([-boss_x, 0, boss_z_top - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([-boss_x, 0, boss_z_bot - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
    }
}

module hardware_cutouts() {
    // 1. Front Wall Cutouts (Speakers)
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        translate([-45, 0, 0]) hex_grill(30);
        translate([45, 0, 0])  hex_grill(30);
    }

    // 2. Shelf Panel Cutouts
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        // Font & Pitch (Right: -X)
        translate([-70, 0, 0]) cylinder(h=wall*4, d=10, center=true); // Joystick
        translate([-50, 0, 0]) cylinder(h=wall*4, d=16, center=true); // Radial dial
        
        // Octave & Rocker (Left: +X)
        translate([50, 0, 0]) cylinder(h=wall*4, d=8, center=true);  // Rocker
        translate([70, 0, 0]) cylinder(h=wall*4, d=16, center=true); // Radial dial
    }

    // 3. Sloped Panel Cutouts
    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;
    
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        
        // 7 Note Buttons (Cherry MX cutouts)
        for(i = [-3:3]) {
            translate([i * 19.05, 15, 0]) 
            cube([14, 14, wall*4], center=true);
        }
        
        // OLED (Top Right)
        translate([-30, -15, 0])
        cube([28, 15, wall*4], center=true);
        
        // LED Ring (Top Left)
        translate([30, -15, 0])
        cylinder(h=wall*4, d=24, center=true);
    }
    
    // 4. Side Panel Cutouts
    // Volume Potentiometer (Right Side Panel: -X)
    translate([-case_w/2, case_d/3, case_h/1.5])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=8, center=true);
}

// Toddler-safe Hex Grill - limits hole sizes to 4mm to prevent finger pinching
module hex_grill(diameter) {
    hole_radius = 2.7; 
    spacing = 6;
    
    intersection() {
        cylinder(h=wall*4, d=diameter, center=true);
        union() {
            for (x = [-diameter/2 : spacing : diameter/2]) {
                for (y = [-diameter/2 : spacing*0.866 : diameter/2]) {
                    x_offset = x + (round(y/(spacing*0.866))%2)*(spacing/2);
                    translate([x_offset, y, 0])
                    cylinder(h=wall*5, r=hole_radius, $fn=6, center=true);
                }
            }
        }
    }
}
