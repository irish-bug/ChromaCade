include <chromacade-config.scad>

// Render two inserts flat on the bed for 3D printing
translate([0, 25, 0]) speaker_grille_insert();
translate([0, -25, 0]) speaker_grille_insert();

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
