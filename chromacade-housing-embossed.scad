// ChromaCade Synthesizer - Main Housing (wordmark-embossed variant)
// Same as chromacade-housing.scad, plus a raised "ChromaCade" wordmark on the
// panel exterior, centered in the gap between the OLED and LED ring. Kept as
// a separate standalone file rather than a toggle in chromacade-housing.scad,
// matching this repo's file-per-variant convention (see decision-log.md).
// Requires the Comfortaa font (Debian/Ubuntu: `sudo apt install fonts-comfortaa`) —
// falls back to a default system font if missing, which will look different.
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

// Grille is a portrait stadium (pill) matched exactly to the cone area;
// rotated 90° at the cut site to sit landscape on the (landscape) front wall enclosure.
spk_grille_w = 1.0 * in2mm;  // 25.4mm = 1"   (stadium width  = cone width)
spk_grille_h = 1.5 * in2mm;  // 38.1mm = 1.5" (stadium height = cone height)
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

// Center top/bottom bosses (back-panel anti-bowing support). Unlike boss_z_top/
// boss_z_bot above, these aren't inset for X-flush contact with a side wall —
// there's no side wall at x=0. Instead they're offset 5mm in from the ceiling/
// floor's inner surface so the *square* boss (see mounting_boss) sits Z-flush
// against the ceiling/floor. (A previous attempt reused boss_z_top/boss_z_bot
// unchanged at x=0, which touched nothing on any side — floating, unprintable.)
boss_z_top_ctr = case_h - wall - 5;
boss_z_bot_ctr = wall + 5;

// --- Assembly ---
union() {
    difference() {
        main_chassis();
        hardware_cutouts();
    }
    wordmark_emboss();
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
    translate([0, wall, 0]) {
        translate([0, 0, boss_z_top_ctr]) rotate([-90, 0, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot_ctr]) rotate([-90, 0, 0]) mounting_boss(boss_len);
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
    // Square cross-section (not round) so the boss meets the side wall on a
    // flush 10x10mm face instead of being tangent to it along a single line —
    // a round boss here only ever line-contacts the flat wall, which is a weak
    // bond and a real risk of a barely-fused, snap-off connection when printed.
    difference() {
        translate([-5, -5, 0]) cube([10, 10, len]);
        translate([0, 0, -1])
        cylinder(h=len+2, d=3, center=false);
    }
}

module hardware_cutouts() {
    // Speaker grilles — hex-hole pattern cut straight into the front wall
    // (no separate insert). Stadium shape is portrait-native in the module;
    // rotated 90° here so it sits landscape on the landscape enclosure.
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        translate([-spk_cx, 0, 0]) rotate([0, 0, 90]) stadium_hex_grill(spk_grille_w, spk_grille_h);
        translate([ spk_cx, 0, 0]) rotate([0, 0, 90]) stadium_hex_grill(spk_grille_w, spk_grille_h);
    }

    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        translate([-65, 0, 0]) cylinder(h=wall*4, d=28, center=true);
        translate([-35, 0, 0]) cylinder(h=wall*4, d=7,  center=true);
        translate([45, 0, 0]) cylinder(h=wall*4, d=7,  center=true);
        translate([70, 0, 0]) cylinder(h=wall*4, d=20.5, center=true);

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

// Toddler-safe portrait stadium hex grill — validated on test-mk2.scad's plate E.
// gw = total width (= semicircle diameter); gh = total height.
// Two semicircular caps (r = gw/2) joined by a rectangle gh-gw tall.
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

module wordmark_emboss() {
    // Raised "ChromaCade" wordmark on the panel exterior (local z=0 is the
    // outer face in this frame — see the interior-face recesses above, all
    // negative z), centered in the gap between the OLED cutout (x=-60, right
    // edge -46) and LED ring cutout (x=65, left edge 53): (-46+53)/2 = 3.5.
    // Imports the real traced bold-italic outline (ChromaCade-wordmark-paths.svg,
    // same directory) rather than reconstructing it via text() — an earlier
    // text()-based version printed in a plain, non-bold, non-italic font because
    // Comfortaa wasn't installed on the machine that actually rendered/sliced it.
    // Note: this SVG has no glyph for the source wordmark's music-note flourish —
    // still missing here, same as the text() version.
    // The imported paths measure ~204.3x21.5mm; scaled down to fit the ~95mm-wide
    // gap without reaching the note-button row above.
    emboss_h  = 1;
    embed     = 0.3; // sinks the letters' base 0.3mm into the wall so the union
                      // is a true volumetric overlap, not a coplanar face-touch
                      // (a flush z=0 base produced 10 near-disconnected letters —
                      // same failure mode as the tangent-boss bug, just for glyphs)
    svg_w  = 204.26;
    svg_cx = 182.03;
    svg_cy = 51.51; // bounding-box center, measured from an extruded STL export —
                     // *not* from SVG-export round-tripping, which silently negates
                     // Y on the way back out and cost an hour chasing a phantom bug
    s      = 84 / svg_w;

    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0])
    translate([3.5, -15, -embed])
    linear_extrude(emboss_h + embed)
    scale([s, s, 1])
    translate([-svg_cx, -svg_cy, 0])
    import("ChromaCade-wordmark-paths.svg");
}
