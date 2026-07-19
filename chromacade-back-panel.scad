// ChromaCade Synthesizer - Back Panel
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

p3_z = front_h + shelf_d*sin(shelf_a);
case_h = p3_z + panel_l*sin(panel_a);

boss_x     = case_w/2 - wall - 5;
boss_z_top = case_h - wall - 15;
boss_z_bot = wall + 15;

// --- Back Panel ---
w = case_w - wall*2 - 1;
h = case_h - wall*2 - 1;

difference() {
    linear_extrude(wall)
    offset(r=2.5) offset(r=-2.5) square([w, h], center=true);

    // USB-C port — 14x10mm fits cable sheath (bare receptacle is 9.5x3.5mm)
    translate([0, -h/2 + 15, -1]) cube([14, 10, wall*3], center=true);
    // Power switch — snap-in miniature rocker, 0.756"x0.5" (19.2x12.7mm) panel cutout
    translate([-25, -h/2 + 15, -1]) cube([19.2, 12.7, wall*3], center=true);

    translate([ boss_x, boss_z_top - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
    translate([ boss_x, boss_z_bot - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
    translate([-boss_x, boss_z_top - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
    translate([-boss_x, boss_z_bot - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
}
