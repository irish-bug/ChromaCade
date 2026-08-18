// ChromaCade Synthesizer - Pot-side housing (volume-pot endcap + back + bottom)
//
// One of two printed pieces (see chromacade-blank-side(-embossed).scad for
// the other) — split 2026-08-17 so each piece has exactly one full side
// wall as its print-bed face, printed side-down to avoid the support
// material a 45°-angled panel would otherwise need. This piece owns the
// -X endcap (the side with the volume-pot hole), plus the back wall and
// the base/bottom.
//
// Built by partitioning the shared shell at the p1/p5 seam line (a half-
// plane mask in the (Y,Z) profile plane), not as independent inset cuts —
// the previous shell+L-bracket design cut the back and bottom openings
// separately, each inset by `wall` from every edge, which left an uncut
// rib of shell material at their shared corner (p0). A single partition
// can't produce that failure mode: every point is unambiguously on one
// side of the seam or the other, so there's no shared edge to leave a gap
// (or a rib) at. See docs/decision-log.md.
$fn = 60;

// --- Global Dimensions --- (must match chromacade-blank-side(-embossed).scad)
in2mm = 25.4;
case_w = 7.7   * in2mm; // 7in + 10%
case_d = 4.95  * in2mm; // 4.5in + 10%
wall   = 5;

front_h = 1.925 * in2mm; // 1.75in + 10%
shelf_d = 1.875 * in2mm; // 1.5in + 25% (controller shelf)
shelf_a = 8;
panel_l = 2.75  * in2mm; // 2.5in + 10%
panel_a = 45;

p0 = [0, 0];
p1 = [case_d, 0];
p2 = [case_d, front_h];
p3 = [case_d - shelf_d*cos(shelf_a), front_h + shelf_d*sin(shelf_a)];
p4 = [p3[0] - panel_l*cos(panel_a), p3[1] + panel_l*sin(panel_a)];
p5 = [0, p4[1]];

case_h = p4[1];

// Mounting bosses joining this piece to chromacade-blank-side(-embossed).scad
// at the p1 (bottom<->front) and p5 (back<->top) seams. All 6 bosses live on
// this piece; the blank-side piece just gets plain clearance through-holes
// (no matching pockets needed) — simpler than mirroring bosses on both
// pieces, at the cost of all the screw-retention material being here.
//
// Printed side-down (this piece's own -X endcap on the bed) to avoid the
// support a 45°-angled panel would need — see chromacade-blank-side.scad's
// header. Each boss's solid material stays fully within this piece's own
// (Y,Z) bounds (inset by boss_r + edge_clearance from the seam) so it can't
// collide with the other piece; only the bore (a hole, not solid) crosses
// the gap. Ramped 45° toward -X (this piece's own endcap/print-bed side)
// via a cone, rather than an abrupt step, so the boss itself prints without
// support in this orientation.
boss_r       = 5;
boss_bore_d  = 3.5;
boss_body_len = 14;
boss_ramp    = 8;
boss_x_positions = [-70, 0, 70];

module chamfered_boss(x0, y0, z0, axis) {
    translate([x0, y0, z0]) {
        rotate([0, -90, 0])
        cylinder(h=boss_ramp, r1=boss_r, r2=0);

        if (axis == "y")
            rotate([90, 0, 0]) cylinder(h=boss_body_len, r=boss_r);
        else
            rotate([180, 0, 0]) cylinder(h=boss_body_len, r=boss_r);
    }
}

module boss_bore(x0, y0, z0, axis, seam_coord) {
    // Explicitly spans from within the boss body (back_edge) out past the
    // seam (front_edge = seam_coord + margin) — the boss anchors are now
    // well back from the seam (see all_bosses()' comment), so a small fixed
    // length isn't enough; this reaches however far is actually needed.
    // center=true on the cylinder makes the rotate direction irrelevant
    // here (unlike the solid boss shapes, which do care about sign).
    anchor = (axis == "y") ? y0 : z0;
    back_edge = anchor - boss_body_len - 5;
    front_edge = seam_coord + 10;
    mid = (back_edge + front_edge) / 2;
    len = front_edge - back_edge;
    if (axis == "y")
        translate([x0, mid, z0]) rotate([90, 0, 0]) cylinder(h=len, d=boss_bore_d, center=true);
    else
        translate([x0, y0, mid]) rotate([180, 0, 0]) cylinder(h=len, d=boss_bore_d, center=true);
}

// Boss anchor positions: NOT simply "inset boss_r from the seam" — the
// p1-p5 seam is a diagonal line (in the Y,Z profile plane), so this piece's
// own strip material is already cut back well short of the seam corner at
// any Z (for the p1 boss) or Y (for the p5 boss) above/beyond a few mm. The
// anchor also has to clear the OTHER piece's full wall thickness, not just
// edge_clearance, since that piece's front wall / top segment occupies a
// real Y (or Z) range right at the seam, not just a hairline. Computed
// numerically (see PR description) against both constraints with a safety
// margin — don't shrink these back toward the seam without re-deriving.
module all_bosses() {
    y1 = 85; // p1 seam anchor (bottom side)
    z5 = 70; // p5 seam anchor (back side)
    for (x0 = boss_x_positions) {
        chamfered_boss(x0, y1, wall + boss_r, "y");
        chamfered_boss(x0, wall + boss_r, z5, "z");
    }
}

module all_boss_bores() {
    y1 = 85;
    z5 = 70;
    for (x0 = boss_x_positions) {
        boss_bore(x0, y1, wall + boss_r, "y", case_d);
        boss_bore(x0, wall + boss_r, z5, "z", case_h);
    }
}

// --- Assembly ---
difference() {
    union() {
        endcap(-1);
        strips();
        all_bosses();
    }
    hardware_cutouts();
    all_boss_bores();
}

module outer_profile() {
    pts = [p0, p1, p2, p3, p4, p5];
    offset(r=6) offset(r=-6) polygon(pts);
}

// The full shell, unpartitioned — same construction as the pre-split
// design (shell = outer profile minus the wall-inset inner profile,
// extruded across case_w). Both pieces are carved from this same solid via
// intersection with different masks, which is what guarantees they can't
// overlap or leave a gap between them.
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
// line. side=1 keeps the p0 (back+bottom) half; side=-1 keeps the other
// (front+shelf+panel+top) half. Uses the same rotate([90,0,90])/
// linear_extrude(case_w) pattern as outer_profile()'s own extrusion in
// shell_solid(), so this mask aligns with it exactly — no separate axis-
// mapping derivation needed (that's what went wrong building the L-bracket
// last round: a fresh extrusion with hand-derived rotation, sign-flipped).
module yz_half_plane(side) {
    seam = p5 - p1;
    // Rotating seam +90° CCW ([-dy,dx]) points toward p0 for this profile's
    // specific shape (dx=p5x-p1x<0, dy=p5y-p1y>0 always here, so [-dy,dx]
    // has both components negative — i.e. toward the origin/p0 corner).
    // Verified numerically before writing this file. side=-1 flips it.
    perp = side * [-seam[1], seam[0]];
    perp_unit = perp / norm(perp);
    big = 2000;
    pts = [p1, p5, p5 + perp_unit*big, p1 + perp_unit*big];
    rotate([90, 0, 90])
    linear_extrude(case_w, center=true)
    polygon(pts);
}

// Full-hexagon endcap slice, wall-thick, at this piece's own X extreme.
// side=-1 -> endcap at X=-case_w/2 (pot side); side=1 -> X=+case_w/2.
module endcap(side) {
    intersection() {
        shell_solid();
        translate([side * (case_w/2 - wall/2), case_d/2, case_h/2])
        cube([wall, case_d + 80, case_h + 80], center=true);
    }
}

// This piece's back+bottom wall strips, spanning from its own endcap's
// outer face to just short of the OTHER piece's endcap inner face — pulled
// back by edge_clearance rather than touching it exactly. An exact shared
// boundary plane between the two pieces produces razor-thin sliver
// artifacts in boolean intersection checks (confirmed via the pot-side/
// blank-side interference check before this was added — pure floating-
// point noise, not a real overlap) and relies on unrealistic print
// tolerance anyway; a small deliberate gap avoids both.
edge_clearance = 0.15;
module strips() {
    intersection() {
        shell_solid();
        yz_half_plane(1); // back+bottom side (contains p0)
        translate([-(wall + edge_clearance)/2, case_d/2, case_h/2])
        cube([case_w - wall - edge_clearance, case_d + 80, case_h + 80], center=true);
    }
}

module hardware_cutouts() {
    // Volume pot hole for the Fender 500K -- needs its 3/8" (9.525mm)
    // mounting bushing, not a bare 8mm hole (regression; unit #1 was
    // hand-drilled out to fit -- fixed here so future prints don't need
    // that workaround).
    translate([-case_w/2, case_d/3, case_h/1.5])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=9.525, center=true);

    // Power cable passthrough — 4mm, carried over unchanged from the
    // retired chromacade-back-panel.scad / chromacade-bottom-back.scad.
    // Unit #1 is bring-up-powered via a micro-USB cable routed straight
    // through instead of the LiPo/boost-charge board (decision-log.md).
    h_back  = case_h - wall*2 - 1;
    cable_z = case_h/2 + (-h_back/2 + 1.5);
    translate([-40, wall, cable_z]) rotate([-90, 0, 0]) cylinder(h=wall*3, d=4, center=true);

    // Fan vent — kept as unpopulated geometry (decision-log.md: dropped
    // from unit #1, revisit for the next build). 39mm hex grille + 4x M3
    // corner mounting holes, 32mm spacing; unscaled (real fan footprint).
    // fan_cy=10 in the old back-panel file's own local frame -> Z=case_h/2+10 here.
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

// Copied verbatim from chromacade-blank-side(-embossed).scad's speaker
// grille (same toddler-safe hole size, already print-validated there)
// rather than shared/included, matching this project's standalone-file
// convention (see CLAUDE.md).
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
