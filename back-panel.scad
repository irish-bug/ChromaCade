include <chromacade-config.scad>

// Render flat on the bed for 3D printing
back_panel_flat();

// Flatten the assembled panel onto the bed
module back_panel_flat() {
    translate([0, 0, wall/2])
    rotate([-90, 0, 0])
    translate([0, -wall/2, -case_h/2])
    back_panel_assembled();
}

// Original assembled position
module back_panel_assembled() {
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
        // standard USB-C receptacle is 9.5×3.5mm; 10×4 gives 0.5mm margin
        translate([0, 0, -h/2 + 15])
        cube([10, wall*4, 4], center=true);

        // Power Switch Cutout (12mm standard toggle/rocker)
        translate([-25, 0, -h/2 + 15])
        rotate([90, 0, 0])
        cylinder(h=wall*4, d=12, center=true);

        // Screw holes (aligned to boss coordinates)
        translate([ boss_x, 0,  boss_z_top - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([ boss_x, 0,  boss_z_bot - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([-boss_x, 0,  boss_z_top - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
        translate([-boss_x, 0,  boss_z_bot - case_h/2]) rotate([90,0,0]) cylinder(h=wall*4, d=3.5, center=true);
    }
}
