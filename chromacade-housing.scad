// ChromaCade Synthesizer - Main Housing
$fn = 60;

// --- Global Dimensions ---
in2mm = 25.4;
case_w = 7    * in2mm;
case_d = 4.5  * in2mm;
wall   = 5;

front_h = 1.75 * in2mm;
shelf_d = 1.5  * in2mm;
shelf_a = 8;
panel_l = 2.5  * in2mm;
panel_a = 45;

spk_grille_w = 65;
spk_grille_h = 30;
spk_cx       = 45;

p0 = [0, 0];
p1 = [case_d, 0];
p2 = [case_d, front_h];
p3 = [case_d - shelf_d*cos(shelf_a), front_h + shelf_d*sin(shelf_a)];
p4 = [p3[0] - panel_l*cos(panel_a), p3[1] + panel_l*sin(panel_a)];
p5 = [0, p4[1]];

case_h = p4[1];

boss_x     = case_w/2 - wall - 5;
boss_z_top = case_h - wall - 15;
boss_z_bot = wall + 15;
boss_len   = 10;

// --- Assembly ---
difference() {
    main_chassis();
    hardware_cutouts();
}

module main_chassis() {
    difference() {
        color("ivory")
        rotate([90, 0, 90])
        linear_extrude(case_w, center=true)
        outer_profile();

        rotate([90, 0, 90])
        linear_extrude(case_w - (wall * 2), center=true)
        offset(delta = -wall) outer_profile();

        back_hole();
    }

    translate([boss_x, wall, 0]) {
        translate([0, 0, boss_z_top]) rotate([-90, 0, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot]) rotate([-90, 0, 0]) mounting_boss(boss_len);
    }
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
        cylinder(h=len+2, d=3, center=false);
    }
}

module hardware_cutouts() {
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        for (sx = [-spk_cx, spk_cx]) {
            translate([sx, 0, 0]) {
                cube([spk_grille_w, spk_grille_h, wall*4], center=true);
                for (cx = [-(spk_grille_w/2 + 4), (spk_grille_w/2 + 4)]) {
                    for (cy = [-(spk_grille_h/2 + 4), (spk_grille_h/2 + 4)]) {
                        translate([cx, cy, 2])
                        cylinder(h=wall*2, d=2, center=false);
                    }
                }
            }
        }
    }

    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        translate([-65, -2, 0]) cylinder(h=wall*4, d=30, center=true);
        translate([-35, 0, 0]) cylinder(h=wall*4, d=7,  center=true);
        translate([45, 0, 0]) cylinder(h=wall*4, d=7,  center=true);
        translate([70, 0, 0]) cylinder(h=wall*4, d=20.32, center=true);

        // EC11 encoder bushing countersinks — interior face, 1mm deep, clears threads
        translate([-35, 0, -(wall - 0.5)]) cube([14.3, 14.3, 1], center=true);
        translate([ 45, 0, -(wall - 0.5)]) cube([14.3, 14.3, 1], center=true);
    }

    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        for (i = [-3:3]) {
            translate([i * 19.05, 15, 0])
            cube([14.3, 14.3, wall*4], center=true);
        }
        
        // MX switch engagement trench — interior face, 3.5mm deep, leaves exactly 1.5mm front wall for clips
        translate([0, 15, -3.25])
        cube([140, 20, 3.5], center=true);

        translate([-60, -15, 0]) cube([28, 15, wall*4], center=true);
        
        // OLED back countersink — interior face, 2mm deep; adjust 30x30 to match your PCB
        translate([-60, -15, -(wall - 1)])
        cube([30, 30, 2], center=true);

        translate([65, -15, 0]) cylinder(h=wall*4, d=24, center=true);
        
        // LED back recess — interior face, 1mm deep (d=28 allows ring to sit flush)
        translate([65, -15, -(wall - 0.5)])
        cylinder(h=1, d=28, center=true);
    }

    translate([-case_w/2, case_d/3, case_h/1.5])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=8, center=true);
}
