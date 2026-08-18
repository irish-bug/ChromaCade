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

// Small deliberate gap between the two pieces' strip walls and the other
// piece's endcap — see chromacade-pot-side.scad's matching comment. Defined
// here (not down by strips()) because edge_x below needs it — a forward
// reference makes OpenSCAD warn "Ignoring unknown variable" and silently
// drop every mount hole positioned from it.
edge_clearance = 0.15;

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
//
// Sized for M3 screws: 2.5mm self-tapping pilot, 3.4mm clearance — see
// chromacade-pot-side.scad's matching comment for the boss rationale (bare
// wall material alone only gives ~1mm on each side of the bore, thin
// enough to risk cracking at these edge-adjacent points, which need to
// survive a toddler pushing the case off a table onto a hard floor).
pilot_d   = 2.5;
clear_d   = 3.4;
engage    = 15;
boss_w    = 12;
boss_body = 14;
boss_ramp = 10;

edge_x = -case_w/2 + wall + edge_clearance; // this piece's edge nearest pot-side

// Reinforcing boss around each pilot bore, same rationale/taper as
// chromacade-pot-side.scad's square_boss() (45° toward +X, this piece's
// own bed side — NOT -X like pot-side's version: blank-side's own
// territory, and its own endcap/bed side, is in the +X direction from
// edge_x, which sits near pot-side at negative X. Copying pot-side's -X
// direction here extends the boss straight into pot-side's endcap instead
// of into this piece's own material — caught via the interference check as
// a large, very much non-empty overlap, not the usual small sliver).
//
// Takes the boss's own (Y,Z) center directly rather than a flush-face +
// position pair, since only 3 of these 5 mounts sit on an axis-aligned
// wall (front wall: flush at Y=case_d; top segment: flush at Z=case_h) —
// the other 2 (shelf/panel and panel/top joints) sit on tilted segments
// (8° and 45°), where a properly surface-flush boss would need a
// per-segment local frame; centered symmetrically on the mount point
// instead (simpler, lower-risk — the mount point is already inset toward
// the interior of the wall's own material, so a generous symmetric cube
// still lands solidly in real material even without matching the local
// tilt exactly).
module own_mount_boss(y_c, z_c) {
    translate([edge_x, y_c - boss_w/2, z_c - boss_w/2])
    cube([boss_body, boss_w, boss_w]);

    translate([edge_x + boss_body, y_c, z_c])
    rotate([0, 90, 0])
    linear_extrude(height=boss_ramp, scale=0)
    square([boss_w, boss_w], center=true);
}

// This piece's own 5 mount/boss centers (Y,Z) — must stay identical to
// chromacade-pot-side.scad's blank_side_mount_yz (regenerate both together
// if the dimension constants above change). front_bottom/front_top flush
// at Y=case_d (front wall's own exterior); top_back flush at Z=case_h (top
// segment's own exterior); shelf_panel/panel_top centered on their segment
// point (see own_mount_boss() above for why).
//
// front_bottom's Z and top_back's Y are NOT the original wall-inset points
// (which were Z=7.33 and Y=4.38, 15% along their segment from p1/p5) —
// pot-side's bottom/back strips extend almost the full case width (nearly
// to this piece's own edge_x), so a boss that close to the p1/p5 corner
// dips into pot-side's strip territory (Z<5 for the bottom strip, Y<5 for
// the back strip). Shifted to 14 on each, clearing wall(5) + boss_w/2(6)
// with a few mm of margin — confirmed via the interference check.
own_mount_boss_centers = [
    [case_d - boss_w/2, 14],
    [case_d - boss_w/2, 41.56],
    [85.29, 52.05],
    [34.82, 95.74],
    [14, case_h - boss_w/2],
];

// Pot-side's 4 mount positions (Y,Z) — must match its pot_side_mounts().
// The first two (bottom-strip, Z=wall/2) didn't actually match until
// 2026-08-18 -- pot-side's bores had drifted to boss_w/2 when its
// reinforcing bosses were added, a real 3.5mm misalignment from these
// values, found and fixed alongside a visual issue (those same bosses'
// full boss_w height stuck up above the bottom strip's own rim). These
// values themselves were already correct and didn't need to change.
pot_side_mount_yz = [
    [100, wall/2],
    [30, wall/2],
    [wall/2, 85],
    [wall/2, 20],
];

module blank_side_mount_bosses() {
    for (yz = own_mount_boss_centers) {
        own_mount_boss(yz[0], yz[1]);
    }
}

module blank_side_mounts() {
    for (yz = own_mount_boss_centers) {
        // Bore centered on the boss, not the bare-wall own_mount_yz point.
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
        blank_side_mount_bosses();
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
// (see edge_clearance, defined near the top of this file).
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
