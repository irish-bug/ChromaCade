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
boss_z_top_ctr = case_h - wall - 5;
boss_z_bot_ctr = wall + 5;

// --- Back Panel ---
w = case_w - wall*2 - 1;
h = case_h - wall*2 - 1;

difference() {
    linear_extrude(wall)
    offset(r=2.5) offset(r=-2.5) square([w, h], center=true);

    // Power cable passthrough — replaces the old USB-C charge-port cutout and
    // separate power-switch cutout (both removed 2026-08-15). Unit #1 is
    // skipping the LiPo/DWEII boost-charge board for now, powering via a
    // micro-USB cable routed straight through the back panel instead (see
    // decision-log.md's Power section) -- the cable has its own inline
    // switch, so no separate panel switch cutout is needed either.
    // 4mm dia -- measured against the actual cable (just over 3mm), confirmed
    // 2026-08-15. Same fit-confirmed status as the old 14x10/19.2x12.7 cutouts.
    power_cable_hole_d = 4;
    translate([0, -h/2 + 15, -1]) cylinder(h=wall*3, d=power_cable_hole_d, center=false);

    translate([ boss_x, boss_z_top - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
    translate([ boss_x, boss_z_bot - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
    translate([-boss_x, boss_z_top - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
    translate([-boss_x, boss_z_bot - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
    // Center top/bottom screws — match housing's center anti-bowing bosses
    translate([0, boss_z_top_ctr - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);
    translate([0, boss_z_bot_ctr - case_h/2, -1]) cylinder(h=wall*3, d=3.5, center=false);

    // Fan vent — 39mm square fan, corner mounting holes, confirmed 2026-08-15.
    // stadium_hex_grill(39, 39) degenerates to a 39mm-diameter circular
    // hex-grille (gw=gh means the two stadium end-caps land on top of each
    // other) -- appropriate here since the fan's actual moving air comes
    // from the circular blade sweep, not the square frame's corners; most
    // fan grilles are circular for exactly this reason. Same toddler-safe
    // hole size as the speaker grilles (hole_radius=2.7, 5.4mm), already
    // print-validated there.
    //
    // Mounting: 4x M3 clearance holes (3.5mm, matching this file's existing
    // boss-hole convention) at corners, 32mm x 32mm spacing -- measured
    // directly against the actual fan, confirmed 2026-08-15 (matches the
    // standard 40mm-fan-family pitch this 39mm-frame fan turned out to
    // share, as expected for 40mm-mount cross-compatibility).
    //
    // Position: centered horizontally, y=10 (upper-middle of the panel) --
    // clears the center-top boss (~y=37) and the power cable hole (~y=-27)
    // with margin either way. Easy to move if this isn't where you want it.
    fan_cx = 0;
    fan_cy = 10;
    fan_hole_spacing = 32;

    translate([fan_cx, fan_cy, 0])
    rotate([0, 0, 45]) stadium_hex_grill(39, 39);

    for (dx = [-fan_hole_spacing/2, fan_hole_spacing/2]) {
        for (dy = [-fan_hole_spacing/2, fan_hole_spacing/2]) {
            translate([fan_cx + dx, fan_cy + dy, -1])
            cylinder(h=wall*3, d=3.5, center=false);
        }
    }
}

// Hex-hole grille, portrait stadium (pill) shape -- copied verbatim from
// chromacade-housing-embossed.scad's speaker grille (same toddler-safe
// hole size, already print-validated there) rather than shared/included,
// matching this project's standalone-file convention (see CLAUDE.md).
// gw = total width (= semicircle diameter); gh = total height.
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
