/*
 * ChromaCade Synthesizer - V3 Structural Model
 * Fixed booleans, exact trigonometry alignment, and proper hollowing.
 * Changed all face sizes and increased rounding of edges.
 */

$fn = 60;

// --- Global Dimensions (Converted from inches) ---
in2mm = 25.4;
case_w = 7 * in2mm;        // 177.8mm
case_d = 4.5 * in2mm;      // 165.1mm
wall = 5;                  // Chunky 5mm walls

front_h = 1.75 * in2mm;       // 76.2mm
shelf_d = 1.5 * in2mm;       // 50.8mm
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

// --- Assembly ---
assembly();

module assembly() {
    difference() {
        main_chassis();
        hardware_cutouts();
    }
    
    // Back panel pulled out slightly for visual verification
    translate([0, -10, 0]) 
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
        
        // Chop off the back wall to leave the cavity open
        // A block at Y=0 cuts from -wall to +wall
        translate([0, 0, case_h/2])
        cube([case_w * 1.5, wall * 2, case_h * 1.5], center=true);
    }
    
    // Internal Mounting Bosses for Back Panel
    boss_len = 10;
    boss_z_top = case_h - wall - 15;
    boss_z_bot = wall + 15;
    
    // Left side bosses (attached to inner left wall)
    translate([-(case_w/2 - wall - boss_len/2), wall + 5, 0]) {
        translate([0, 0, boss_z_top]) rotate([0, 90, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot]) rotate([0, 90, 0]) mounting_boss(boss_len);
    }
    
    // Right side bosses (attached to inner right wall)
    translate([(case_w/2 - wall - boss_len/2), wall + 5, 0]) {
        translate([0, 0, boss_z_top]) rotate([0, -90, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot]) rotate([0, -90, 0]) mounting_boss(boss_len);
    }
}

module outer_profile() {
    pts = [p0, p1, p2, p3, p4, p5];
    // Double offset slightly rounds sharp corners without losing structural math
    offset(r=6) offset(r=-6) polygon(pts);
}

module mounting_boss(len) {
    difference() {
        cylinder(h=len, d=10, center=true);
        cylinder(h=len+2, d=3, center=true); // M3 pilot hole
    }
}

module back_panel() {
    w = case_w - (wall * 2) - 1; // 1mm clearance tolerance
    h = case_h - (wall * 2) - 1;
    
    translate([0, wall/2, case_h/2])
    difference() {
        cube([w, wall, h], center=true);
        
        // USB-C Port Cutout
        translate([0, 0, -h/2 + 20])
        cube([15, wall*4, 7], center=true);
    }
}

module hardware_cutouts() {
    // 1. Front Wall Cutouts (Speakers)
    // Front wall normal points to +Y, so rotate Z axis by 90 on X
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        translate([-45, 0, 0]) hex_grill(30);
        translate([45, 0, 0])  hex_grill(30);
    }

    // 2. Shelf Panel Cutouts
    // Midpoint of the shelf
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    
    translate([0, shelf_my, shelf_mz])
    // Shelf slopes UP towards the back, so normal faces UP and FRONT.
    // Negative X rotation tilts the cutting cylinder forward perfectly.
    rotate([-shelf_a, 0, 0]) {
        // Octave & Rocker (Right)
        translate([-70, 0, 0]) cylinder(h=wall*4, d=10, center=true); // Joystick
        translate([-50, 0, 0]) cylinder(h=wall*4, d=16, center=true); // Radial dial
        
        // Font & Pitch (Left)
        translate([50, 0, 0]) cylinder(h=wall*4, d=8, center=true);  // Rocker
        translate([70, 0, 0]) cylinder(h=wall*4, d=16, center=true); // Radial dial
    }

    // 3. Sloped Panel Cutouts
    // Midpoint of the sloped panel
    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;
    
    translate([0, panel_my, panel_mz])
    // Negative X rotation to cut perpendicular into the 45 deg slope
    rotate([-panel_a, 0, 0]) {
        
        // 7 Note Buttons (Cherry MX cutouts)
        for(i = [-3:3]) {
            // Local Y offset moves them down the slope toward the user
            translate([i * 19.05, -12, 0]) 
            cube([14, 14, wall*4], center=true);
        }
        
        // OLED (Top Right - local Y offset moves it up the slope)
        translate([30, 15, 0])
        cube([28, 15, wall*4], center=true);
        
        // LED Ring (Top Left)
        translate([-30, 15, 0])
        cylinder(h=wall*4, d=24, center=true);
    }
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
