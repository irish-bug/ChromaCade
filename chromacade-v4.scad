/*
 * ChromaCade Synthesizer - V4 Structural Model
 * - Back wall hollowed via inset punch to preserve outer corner rounding.
 * - Mounting bosses sunk by 5mm to accommodate flush back panel.
 * - Back panel upgraded with aligned screw holes.
 *
 * BOM-verified cutout corrections (vs. original V4 paste):
 *   - MX switch holes:   14 → 14.3mm  (FDM tolerance, per three-key-test-mount.scad)
 *   - KY-023 joystick:   d=10 → d=30  (thumb cap is ~27mm — 10mm blocked the cap entirely)
 *   - XINYIELE rocker:   d=8  → d=12  (12mm round body per part spec)
 *   - EC11 encoders:     d=16 → d=7   (M7 bushing OD; 16mm left a sloppy 4.5mm gap)
 *   - USB-C port:        15×7 → 10×4  (standard USB-C receptacle is 9.5×3.5mm)
 *   - Speaker grilles:   circular hex_grill(30) → rect_hex_grill(65, 30)
 *                        Speakers are rectangular enclosures (69.9×34.9mm).
 *                        Grille sized to cone area (~38×25mm) + margin = 65×30mm.
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
// Grille covers cone + ~5mm margin each side  →  65mm wide × 30mm tall
spk_grille_w = 65;   // grille width  (cone 38.1 + ~13mm margin)
spk_grille_h = 30;   // grille height (cone 25.4 + ~5mm margin)
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

        // USB-C Port Cutout
        // FIX: was 15×7 — standard USB-C receptacle is 9.5×3.5mm; 10×4 gives 0.5mm margin
        translate([0, 0, -h/2 + 15])
        cube([10, wall*4, 4], center=true);

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
        // FIX: joystick was d=10 (blocked thumb cap — KY-023 cap is ~27mm); now d=30
        translate([-70, 0, 0]) cylinder(h=wall*4, d=30, center=true); // KY-023 joystick thumb cap
        // FIX: encoder was d=16 (too large — EC11 M7 bushing OD is 7mm); now d=7
        translate([-45, 0, 0]) cylinder(h=wall*4, d=7,  center=true); // EC11 font encoder (M7 bushing)

        // Octave & Rocker cluster (Left side: +X)
        // FIX: encoder was d=16; now d=7
        translate([45, 0, 0]) cylinder(h=wall*4, d=7,  center=true); // EC11 octave encoder (M7 bushing)
        // FIX: rocker corrected to 0.8" = 20.32mm (was d=8 in original, then wrong 12mm)
        translate([70, 0, 0]) cylinder(h=wall*4, d=20.32, center=true); // XINYIELE 3-way rocker (0.8" body)
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
        // Cutout sized to viewable area with small margin (26×14mm bezel fits within)
        translate([-60, -15, 0])
        cube([28, 15, wall*4], center=true);

        // LED Ring passthrough — WS2812 7-LED ring
        // d=24 matches ring inner diameter: halo visible, PCB rim hidden behind panel.
        // Increase to 38mm if you want the full ring face exposed.
        translate([65, -15, 0])
        cylinder(h=wall*4, d=24, center=true);
    }

    // 4. Side Panel Cutouts
    // Volume Potentiometer — Fender 500K (6mm D-shaft; 8mm hole gives easy clearance)
    translate([-case_w/2, case_d/3, case_h/1.5])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=8, center=true);
}

// --- Separate Printable Parts ---

// Toddler-safe flush-mount hex grille insert (Print 2x)
// Features a 5mm plug to sit flush with the exterior, and a 2mm flange to screw into the interior.
// Prints flange-down on the bed. No supports needed.
module speaker_grille_insert() {
    gw = spk_grille_w;
    gh = spk_grille_h;
    rim = 8;            // 8mm flange to fit a screw hole
    flange_t = 2;       // 2mm thick flange on the back
    plug_t = wall;      // 5mm thick plug goes through the wall to be flush with front
    tol = 0.4;          // Clearance tolerance for easy fit
    
    hole_radius = 2.7;
    spacing     = 6;

    difference() {
        union() {
            // Flange (Bottom layer against the bed)
            translate([0, 0, flange_t/2])
            cube([gw + rim*2, gh + rim*2, flange_t], center=true);
            
            // Plug (Grows up to poke through the case wall)
            translate([0, 0, flange_t + plug_t/2])
            cube([gw - tol, gh - tol, plug_t], center=true);
        }
        
        // Punch hex holes through the whole thing
        intersection() {
            translate([0, 0, (flange_t + plug_t)/2])
            cube([gw - 4, gh - 4, (flange_t + plug_t)*3], center=true); // Solid 2mm border
            union() {
                for (x = [-gw/2 : spacing : gw/2]) {
                    for (y = [-gh/2 : spacing*0.866 : gh/2]) {
                        x_offset = x + (round(y/(spacing*0.866)) % 2) * (spacing/2);
                        translate([x_offset, y, 0])
                        cylinder(h=(flange_t + plug_t)*4, r=hole_radius, $fn=6, center=true);
                    }
                }
            }
        }
        
        // 4 screw holes in the flange corners (d=2.5 for M2/M2.5/small wood screws)
        for (cx = [-(gw/2 + rim/2), (gw/2 + rim/2)]) {
            for (cy = [-(gh/2 + rim/2), (gh/2 + rim/2)]) {
                translate([cx, cy, 0])
                cylinder(h=flange_t*4, d=2.5, center=true); 
            }
        }
    }
}

// Optional: Render the inserts off to the side so they export with the case,
// or comment out assembly() and uncomment this to export just the grilles.
// translate([-spk_cx, -30, 0]) speaker_grille_insert();
// translate([ spk_cx, -30, 0]) speaker_grille_insert();
