// ChromaCade Synthesizer - Bottom + Back (removable L-bracket)
//
// Combines the base/floor and the back wall into one removable piece that
// screws into chromacade-housing(-embossed).scad's mounting bosses, per
// decision-log.md/open-questions.md: the enclosure was cramped enough during
// unit #1's wiring that back-only access wasn't enough — this piece gives
// full interior access (undo ~9 screws, the whole floor+back lifts away)
// for wiring/assembly, not just battery/SD swaps.
//
// Shape: two flat wall-thick plates meeting at 90°, with a small fillet at
// the inside corner (avoids a sharp reflex corner, matches this project's
// chunky/durable-over-compact philosophy). The bottom leg spans the case's
// full depth (case_d); the back leg spans the full height (case_h).
$fn = 60;

// --- Global Dimensions --- (must match chromacade-housing-embossed.scad)
in2mm = 25.4;
case_w = 7.7   * in2mm; // 7in + 10%
case_d = 4.95  * in2mm; // 4.5in + 10%
wall   = 5;

front_h = 1.925 * in2mm; // 1.75in + 10%
shelf_d = 1.875 * in2mm; // 1.5in + 25% (controller shelf)
shelf_a = 8;
panel_l = 2.75  * in2mm; // 2.5in + 10%
panel_a = 45;

p3_z = front_h + shelf_d*sin(shelf_a);
case_h = p3_z + panel_l*sin(panel_a);

boss_x     = case_w/2 - wall - 5;
boss_z_top = case_h - wall - 15;
boss_z_bot = wall + 15;
boss_z_top_ctr = case_h - wall - 5;
boss_z_bot_ctr = wall + 5;
boss_y_front     = case_d - wall - 15;
boss_y_front_ctr = case_d - wall - 5;

// Fillet radius at the inside corner where the two legs meet.
corner_fillet = 8;

// Plate width — fits inside the housing's side walls (case_w minus both
// wall thicknesses), same -1mm clearance convention the old back-panel used.
plate_w = case_w - wall*2 - 1;

// --- Assembly ---
difference() {
    bottom_back_profile();

    // Screw clearance holes, matching the housing's mounting_boss() positions
    // exactly (3.5mm clears an M3 screw's shaft, not its threads).
    for (bx = [boss_x, -boss_x]) {
        translate([bx, wall, boss_z_top]) rotate([-90, 0, 0]) cylinder(h=wall*3, d=3.5, center=true);
        translate([bx, wall, boss_z_bot]) rotate([-90, 0, 0]) cylinder(h=wall*3, d=3.5, center=true);
        translate([bx, boss_y_front, 0])  cylinder(h=wall*3, d=3.5, center=true);
    }
    translate([0, wall, boss_z_top_ctr]) rotate([-90, 0, 0]) cylinder(h=wall*3, d=3.5, center=true);
    translate([0, wall, boss_z_bot_ctr]) rotate([-90, 0, 0]) cylinder(h=wall*3, d=3.5, center=true);
    translate([0, boss_y_front_ctr, 0])  cylinder(h=wall*3, d=3.5, center=true);

    // Power cable passthrough — 4mm, carried over unchanged from the old
    // chromacade-back-panel.scad (retired). Position matches that file's own
    // local frame exactly: its local Y=-h_back/2+1.5 was centered on its own
    // plate height, which corresponds to Z=case_h/2 here.
    h_back  = case_h - wall*2 - 1;
    cable_z = case_h/2 + (-h_back/2 + 1.5);
    translate([-40, wall, cable_z]) rotate([-90, 0, 0]) cylinder(h=wall*3, d=4, center=true);

    // Fan vent — kept as unpopulated geometry, carried over unchanged from
    // chromacade-back-panel.scad (see decision-log.md: dropped from unit #1,
    // revisit for the next build — this redesign). 39mm hex grille + 4x M3
    // corner mounting holes, 32mm spacing; unscaled (real fan footprint).
    // fan_cy=10 in that file's own local frame -> Z=case_h/2+10 here.
    fan_cx = 0;
    fan_cz = case_h/2 + 10;
    fan_hole_spacing = 32;

    translate([fan_cx, wall, fan_cz])
    rotate([-90, 0, 0])
    rotate([0, 0, 45])
    stadium_hex_grill(39, 39);

    for (dx = [-fan_hole_spacing/2, fan_hole_spacing/2]) {
        for (dz = [-fan_hole_spacing/2, fan_hole_spacing/2]) {
            translate([fan_cx + dx, wall, fan_cz + dz])
            rotate([-90, 0, 0]) cylinder(h=wall*3, d=3.5, center=true);
        }
    }
}

// 2D L-profile in the (Y=depth, Z=height) plane, matching the housing's own
// axis convention: bottom leg along Y (Z: 0..wall), back leg along Z (Y:
// 0..wall), joined with a small fillet at the inside (concave) corner so the
// two legs don't meet at a sharp reflex angle.
module bottom_back_profile() {
    t  = wall;
    fr = corner_fillet;
    cy = t + fr;
    cz = t + fr;
    arc_pts = [ for (a = [270:-10:180]) [cy + fr*cos(a), cz + fr*sin(a)] ];

    pts = concat(
        [[0, 0], [case_d, 0], [case_d, t]],
        arc_pts,
        [[t, case_h], [0, case_h]]
    );

    // polygon(pts) lives in local (x=depth, y=height); linear_extrude runs
    // along local z (=width). rotate(120, [1,1,1]) is the cyclic permutation
    // (x,y,z)->(z,x,y), which maps local z->actual X (width, centered),
    // local x->actual Y (depth, 0..case_d), local y->actual Z (height,
    // 0..case_h) — i.e. exactly the housing's own axis convention, with no
    // sign flip, so the screw-hole/cutout coordinates below line up directly.
    rotate(a=120, v=[1,1,1])
    linear_extrude(plate_w, center=true)
    polygon(pts);
}

// Copied verbatim from chromacade-housing-embossed.scad's speaker grille /
// the old chromacade-back-panel.scad's fan vent (same toddler-safe hole
// size, already print-validated there) rather than shared/included, matching
// this project's standalone-file convention (see CLAUDE.md).
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
