// ChromaCade Synthesizer - Speaker Grille Inserts
$fn = 60;

wall = 5;
spk_grille_w = 65;
spk_grille_h = 30;

// Render two inserts flat on the bed
translate([0, 25, 0]) speaker_grille_insert();
translate([0, -25, 0]) speaker_grille_insert();

module speaker_grille_insert() {
    gw = spk_grille_w;
    gh = spk_grille_h;
    rim = 8;
    flange_t = 2;
    plug_t = wall;
    tol = 0.4;
    
    hole_radius = 2.7;
    spacing     = 6;

    difference() {
        union() {
            // Flange only extends on the left and right, flush with top/bottom
            translate([0, 0, flange_t/2]) cube([gw + rim*2, gh, flange_t], center=true);
            translate([0, 0, flange_t + plug_t/2]) cube([gw - tol, gh - tol, plug_t], center=true);
        }
        
        intersection() {
            translate([0, 0, (flange_t + plug_t)/2]) cube([gw - 4, gh - 4, (flange_t + plug_t)*3], center=true);
            union() {
                for (x = [-gw/2 : spacing : gw/2]) {
                    for (y = [-gh/2 : spacing*0.866 : gh/2]) {
                        x_offset = x + (round(y/(spacing*0.866)) % 2) * (spacing/2);
                        translate([x_offset, y, 0]) cylinder(h=(flange_t + plug_t)*4, r=hole_radius, $fn=6, center=true);
                    }
                }
            }
        }
        
        for (cx = [-(gw/2 + rim/2), (gw/2 + rim/2)]) {
            for (cy = [-10, 10]) {
                translate([cx, cy, 0]) cylinder(h=flange_t*4, d=2.5, center=true); 
            }
        }
    }
}
