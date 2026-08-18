// ChromaCade Synthesizer - Blank-side housing (blank endcap + front + shelf + panel + top)
//
// One of two printed pieces (see chromacade-pot-side.scad for the other) —
// split 2026-08-17 so each piece has exactly one full side wall as its
// print-bed face, printed side-down to avoid the support material a
// 45°-angled panel would otherwise need. This piece owns the +X endcap
// (the side without the volume-pot hole), plus the front wall, shelf,
// panel, and the top/ceiling segment above the panel.
//
// Kept around only until the embossed variant's wordmark print is
// validated on real hardware — chromacade-blank-side-embossed.scad is the
// current, actively-developed model. See chromacade-pot-side.scad for the
// partition-construction rationale (avoids the stray-rib failure mode of
// independently-inset cuts).
$fn = 60;

// --- Global Dimensions --- (must match chromacade-pot-side.scad)
in2mm = 25.4;
case_w = 7.7   * in2mm; // 7in + 10%
case_d = 4.95  * in2mm; // 4.5in + 10%
wall   = 5;

front_h = 1.925 * in2mm; // 1.75in + 10%
shelf_d = 1.875 * in2mm; // 1.5in + 25% (controller shelf)
shelf_a = 8;
panel_l = 2.75  * in2mm; // 2.5in + 10%
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

// Mounting holes joining this piece to chromacade-pot-side.scad — screwed
// together from the sides (X axis), right at each piece's own edge; see
// that file's header comment for the full rationale (an earlier attempt
// bridging the diagonal p1/p5 seam needed ~6" screws).
//
// This piece (blank-side) owns 5 mounts — near the front wall's bottom and
// top, the shelf/panel joint, the panel/top joint, and the top/back joint —
// each a pilot bore into this piece's own material, starting right at this
// piece's edge nearest pot-side. Pot-side owns 4 more (2 bottom, 2 back);
// this piece just gets clearance holes through its endcap for those.
pilot_d = 3;
clear_d = 3.5;
engage  = 15;

edge_x = -case_w/2 + wall + edge_clearance; // this piece's edge nearest pot-side

// This piece's own 5 mount positions (Y,Z) — must stay identical to
// chromacade-pot-side.scad's blank_side_mount_yz (that file explains where
// these numbers come from). Regenerate both together if the dimension
// constants above change.
own_mount_yz = [
    [123.23, 7.33],
    [123.23, 41.56],
    [85.29, 52.05],
    [34.82, 95.74],
    [4.38, 102.41],
];

// Pot-side's 4 mount positions (Y,Z) — must match its pot_side_mounts().
pot_side_mount_yz = [
    [100, wall/2],
    [30, wall/2],
    [wall/2, 85],
    [wall/2, 20],
];

module blank_side_mounts() {
    for (yz = own_mount_yz) {
        translate([edge_x, yz[0], yz[1]]) rotate([0, 90, 0]) cylinder(h=engage, d=pilot_d);
    }
}

module blank_side_clearance_holes() {
    for (yz = pot_side_mount_yz) {
        translate([case_w/2 - wall/2, yz[0], yz[1]])
        rotate([0, 90, 0]) cylinder(h=wall + 10, d=clear_d, center=true);
    }
}

// --- Assembly ---
difference() {
    union() {
        endcap(1);
        strips();
    }
    hardware_cutouts();
    blank_side_mounts();
    blank_side_clearance_holes();
}

module outer_profile() {
    pts = [p0, p1, p2, p3, p4, p5];
    offset(r=6) offset(r=-6) polygon(pts);
}

module shell_solid() {
    difference() {
        rotate([90, 0, 90])
        linear_extrude(case_w, center=true)
        outer_profile();

        rotate([90, 0, 90])
        linear_extrude(case_w - (wall * 2), center=true)
        offset(delta = -wall) outer_profile();
    }
}

// Half-plane clip in the (Y,Z) profile plane, split along the p1-p5 seam
// line — see chromacade-pot-side.scad for the full derivation. side=-1
// keeps the front+shelf+panel+top half (away from p0).
module yz_half_plane(side) {
    seam = p5 - p1;
    perp = side * [-seam[1], seam[0]];
    perp_unit = perp / norm(perp);
    // Retreat the mask line a few mm from the exact p1-p5 line — see
    // chromacade-pot-side.scad's matching comment (outer_profile()'s
    // rounding doesn't pass through p1/p5 exactly, leaving a sliver of
    // near-touching material at a literal-coordinate mask cut).
    seam_margin = 3;
    p1m = p1 + perp_unit*seam_margin;
    p5m = p5 + perp_unit*seam_margin;
    big = 2000;
    pts = [p1m, p5m, p5m + perp_unit*big, p1m + perp_unit*big];
    rotate([90, 0, 90])
    linear_extrude(case_w, center=true)
    polygon(pts);
}

// Full-hexagon endcap slice, wall-thick, at this piece's own X extreme.
// side=1 -> endcap at X=+case_w/2 (blank side).
module endcap(side) {
    intersection() {
        shell_solid();
        translate([side * (case_w/2 - wall/2), case_d/2, case_h/2])
        cube([wall, case_d + 80, case_h + 80], center=true);
    }
}

// This piece's front+shelf+panel+top wall strips, spanning from its own
// endcap's outer face to just short of the OTHER piece's endcap inner face
// — pulled back by edge_clearance rather than touching it exactly. See
// chromacade-pot-side.scad's edge_clearance comment: an exact shared
// boundary plane produces razor-thin sliver artifacts in boolean
// intersection checks (pure floating-point noise, confirmed via the
// pot-side/blank-side interference check) and relies on unrealistic print
// tolerance anyway.
edge_clearance = 0.15;
module strips() {
    intersection() {
        shell_solid();
        yz_half_plane(-1); // front+shelf+panel+top side (away from p0)
        translate([(wall + edge_clearance)/2, case_d/2, case_h/2])
        cube([case_w - wall - edge_clearance, case_d + 80, case_h + 80], center=true);
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
