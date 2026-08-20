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

// NEW dual-cone speaker housing (2026-08-19) -- ONE 98x43x20mm housing,
// centered on the front wall, replacing the old two single-cone positions.
// Housing has 2x 35mm cones, each 22.5mm off the housing's own center
// (45mm apart total), vertically centered on the front wall -- MEASURED
// against the real part. Two separate housings (4 total cones) were
// considered and don't fit: even edge-to-edge with zero margin they'd
// need case_w >= 206mm, over the 203.2mm (8in) print bed limit -- see
// docs/decision-log.md. Each cone gets its own round grille (a
// stadium_hex_grill() with equal w/h degenerates to a circle, no rotation
// needed since it's now symmetric).
spk_cone_d      = 35;
spk_cone_offset = 22.5;

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

// Square boss (true boss_w x boss_w cross-section throughout -- "the same
// square cylinder" for all 5 mounts, per direct instruction 2026-08-19) --
// matches chromacade-pot-side.scad's square_boss() technique exactly: a
// flush cube glued directly onto the true wall surface, hull()'d out to a
// thin sliver for print-support-free tapering.
//
// REBUILT 2026-08-19, second pass -- the first version of this module had
// the taper's thin end anchored at the FREE (interior-facing) side instead
// of the WALL side, exactly backwards from pot-side's proven technique.
// pot-side's square_boss() keeps the wall-touching face (z_start, or y=0
// for its back strip) at a FIXED coordinate across both the full cube and
// both taper end-slices, and only shrinks the standoff reach on the free
// side -- so the taper's thinnest point still touches the wall (which is
// solid, present at every X-slice, since it's part of the uniform
// extrusion) and grows outward from there. The first version instead kept
// the FREE side fixed and shrank the wall-touching side down to a point
// floating in open interior air, touching nothing -- exactly the
// unsupported-overhang problem the taper exists to avoid, caught by direct
// inspection of the actual print orientation (this piece prints with its
// own +X endcap face-down, building toward -X -- see file header -- so the
// mount region near edge_x, far from that endcap, prints LATE; a taper
// that doesn't stay wall-anchued the whole time needs tall support
// reaching from the bed, adding hours to the print). Fixed here by keeping
// wall_y/wall_z (the true wall-flush coordinate) as the fixed anchor for
// both the cube and both taper slices, and by using this SAME module,
// wrapped in a rotate(), for shelf_panel/panel_top too (see
// panel_mount_boss() below) instead of a separate oversized CSG-clip
// module -- there is no case where this needs to be huge.
//
// wall_z/wall_y (NOT pos) is the wall-flush coordinate; default -wall
// matches the LOCAL convention used everywhere in hardware_cutouts()
// (z=0 exterior, z=-wall interior) so this module can be wrapped directly
// in a segment's own rotate()+translate() (see panel_mount_boss()) without
// passing anything extra. front_bottom/front_top/top_back instead pass the
// real GLOBAL flush coordinate (case_d-wall / case_h-wall) since they're
// called unrotated.
module flat_mount_boss(pos, thick_axis, wall_z=-wall, wall_y=-wall) {
    if (thick_axis == "z") {
        translate([edge_x, pos - boss_w/2, wall_z - boss_w])
        cube([boss_body, boss_w, boss_w]);

        hull() {
            translate([edge_x + boss_body - 0.01, pos - boss_w/2, wall_z - boss_w])
            cube([0.01, boss_w, boss_w]);

            translate([edge_x + boss_body + boss_ramp - 0.01, pos - boss_w/2, wall_z - 0.01])
            cube([0.01, boss_w, 0.01]);
        }
    } else {
        translate([edge_x, wall_y - boss_w, pos - boss_w/2])
        cube([boss_body, boss_w, boss_w]);

        hull() {
            translate([edge_x + boss_body - 0.01, wall_y - boss_w, pos - boss_w/2])
            cube([0.01, boss_w, boss_w]);

            translate([edge_x + boss_body + boss_ramp - 0.01, wall_y - 0.01, pos - boss_w/2])
            cube([0.01, 0.01, boss_w]);
        }
    }
}

// shelf_panel and panel_top sit at the shelf/panel and panel/top JOINTS,
// not cleanly on either adjacent segment -- per direct instruction, both
// use the PANEL's own angle (panel_a, 45°) rather than the shelf's (8°) or
// a hand-picked joint compromise. Reuses flat_mount_boss()'s "z" case
// UNROTATED (flush at local z=-wall, the panel's own interior surface,
// matching hardware_cutouts()'s panel-local frame exactly) -- the wrapping
// rotate()+translate() here is copied from hardware_cutouts()'s own panel
// block, so this lands in the identical local frame as the OLED/encoder/
// LED cutouts already placed there.
//
// pos is LOCAL y within that rotated frame, NOT the target's global Y --
// found by inverting hardware_cutouts()' forward transform (Y = panel_my +
// y*cos(panel_a) + z*sin(panel_a), Z = panel_mz - y*sin(panel_a) +
// z*cos(panel_a)) for the real target (Y,Z) from own_mount_boss_centers
// below, since neither target sits exactly on the panel's own centerline
// (local z=0) -- verified numerically (not by hand) that both round-trip
// back to their exact target global (Y,Z), and that a standard boss_w=12
// boss flush at local z=-wall comfortably contains each target's local z
// (shelf_panel: z=-8.55, 3.55mm/8.45mm margin; panel_top: z=-11.38,
// 6.38mm/5.62mm margin -- both well inside [-17,-5]).
module panel_mount_boss(pos_y) {
    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0])
    flat_mount_boss(pos_y, "z");
}

// This piece's own 5 mount/boss centers (Y,Z) — must stay identical to
// chromacade-pot-side.scad's blank_side_mount_yz (regenerate both together
// if the dimension constants above change).
//
// CORRECTED 2026-08-19 -- despite both files' comments insisting on exact
// agreement, this array had drifted from pot-side's blank_side_mount_yz by
// as much as 22.74mm (panel_top) and was off on all 5 entries (found while
// investigating the "moved some mounts to adjust for new speakers" front-
// wall shift). own_mount_boss()'s own clip-against-interior_void()
// construction was never the problem -- it's general enough to flush
// correctly against a wall segment at any angle, flat or tilted, so this
// was purely stale position data, never actually caught because nothing
// checks the two arrays against each other automatically. Now copied
// directly from pot-side.scad's blank_side_mount_yz -- that file is the
// authoritative source for these 5 positions (pot-side's clearance holes
// were being deliberately repositioned for the new speaker housing; this
// array needs to track wherever that source of truth puts them, not the
// reverse). If you need to move one of these, change it in pot-side.scad
// first and copy the value here, not the other way around.
own_mount_boss_centers = [
    [110, 12],
    [110, 42],
    [74, 48],
    [45, 73],
    [14, 95],
];

// Pot-side's 4 mount positions (Y,Z) — must match its pot_side_mounts().
// The first two (bottom-strip) went through two corrections 2026-08-18:
// first wall/2 -> boss_w/2 (a real found-and-fixed mismatch, see git
// history), then boss_w/2 -> wall + boss_w/2 once pot-side's own boss
// placement was itself corrected (flush with the bottom strip's
// INTERIOR surface at z=wall, standing up boss_w from there -- not
// flush at the z=0 exterior, and not embedded across both). Keep this
// in sync with pot-side.scad's pot_side_mounts() -- it's the actual
// source of truth, this array just needs to match it.
//
// The last two (back-strip) had the same z=0-vs-z=wall bug, uncorrected
// until 2026-08-19: wall/2 -> wall + boss_w/2, matching pot-side's own
// square_boss()/pot_side_mounts() fix (its "y" case now starts at the
// back wall's INTERIOR surface, y_start=wall, same as the bottom-strip
// bosses rotated 90°, not the exterior).
//
// The first entry (100) went stale the same way own_mount_boss_centers
// did -- pot-side's "moved some mounts to adjust for new speakers" commit
// (2026-08-19) shifted that mount to 110 but only touched
// chromacade-pot-side.scad, not this mirror. Fixed alongside the
// own_mount_boss_centers correction above; same lesson -- nothing checks
// these arrays against their source of truth automatically, so a change
// in one file silently desyncs its mirror until someone notices by hand.
pot_side_mount_yz = [
    [110, wall + boss_w/2],
    [30, wall + boss_w/2],
    [wall + boss_w/2, 85],
    [wall + boss_w/2, 20],
];

// Dispatches per mount rather than a generic loop -- front_bottom/
// front_top/top_back flush directly against a global-frame wall (pass the
// real wall_y/wall_z); shelf_panel/panel_top go through panel_mount_boss()
// (local frame, rotated) instead -- see both modules' own comments.
module blank_side_mount_bosses() {
    flat_mount_boss(own_mount_boss_centers[0][1], "y", wall_y=case_d-wall); // front_bottom
    flat_mount_boss(own_mount_boss_centers[1][1], "y", wall_y=case_d-wall); // front_top
    panel_mount_boss(37.014); // shelf_panel (tilted joint, panel's own frame)
    panel_mount_boss(-1.170); // panel_top (tilted joint, panel's own frame)
    flat_mount_boss(own_mount_boss_centers[4][0], "z", wall_z=case_h-wall); // top_back
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

// Joystick (KY-023) mounting bosses -- PAUSED 2026-08-19, being redesigned
// in isolation in enclosure/joystick-mount-dev.scad. The straight-up
// cylindrical bosses previously here (see git history) got in the way of
// the joystick's own range of motion, two of the four didn't have enough
// material to fully encase their screws, and turned out not to actually
// be support-free to print either (their taper was along the shelf's own
// local Z, not blank-side's real print-vertical axis, global X -- see the
// dev file's header comment for the full explanation). Don't reintroduce
// mounting bosses here until the redesign in joystick-mount-dev.scad is
// validated -- port joy_boss_dev()/joy_pilot_hole_dev() (renamed back to
// joystick_mount_bosses()/joystick_mount_pilot_holes()) back in once it
// is, and update chromacade-fit-check.scad's mirrored copy to match.
//
// joy_x/joy_stick_d below are still live -- they're the stick hole itself
// (confirmed position, confirmed diameter), independent of the mounting
// bosses.
//
// joy_x corrected 2026-08-18 from 70 to -65: confirmed in play position
// (facing the front of the case from outside) RIGHT is the -X direction
// here, and the joystick sits far right (paired with the font encoder at
// x=-35) -- the rocker (paired with the octave encoder at x=45) is the one
// at x=70, far left. Was backwards in the first pass.
joy_x       = -65; // matches the shelf's joystick stick-hole X position
joy_stick_d = 27;  // CONFIRMED 2026-08-19 -- no longer under test

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
    // (no separate insert), one round grille per cone on the single
    // dual-cone housing (see spk_cone_d/spk_cone_offset above).
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        translate([-spk_cone_offset, 0, 0]) stadium_hex_grill(spk_cone_d, spk_cone_d);
        translate([ spk_cone_offset, 0, 0]) stadium_hex_grill(spk_cone_d, spk_cone_d);
    }

    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        // Joystick (far right in play position = negative X here, confirmed
        // 2026-08-18). 27mm CONFIRMED 2026-08-19 (was 28mm on the original
        // pre-boss print, then 26.5mm -- a tiny bit too small -- before
        // landing on 27mm). Corrected 2026-08-18: this hole (x=-65) was
        // previously mislabeled as the rocker's -- it's the joystick's, per
        // the same correction that moved joy_x below.
        translate([-65, 0, 0]) cylinder(h=wall*4, d=joy_stick_d, center=true);
        // Both encoders shifted -7mm along the shelf (toward the back,
        // away from the front wall) -- 2026-08-19, the encoder bodies
        // (15x12x10mm, reaching ENC_BODY_D=10mm behind the panel) were
        // colliding with the new single speaker housing by ~1.7mm at
        // pos_y=0. -7mm clears it with 5.27mm to spare (>= the 5mm
        // minimum specified) -- see chromacade-fit-check.scad's
        // encoder_mockup()/speaker_housing_mockup() for the check. Don't
        // shrink this margin without re-verifying against the housing.
        enc_pos_y = -7;
        translate([-35, enc_pos_y, 0]) cylinder(h=wall*4, d=7,  center=true); // font encoder
        translate([45, enc_pos_y, 0]) cylinder(h=wall*4, d=7,  center=true);  // octave encoder
        // Rocker switch (far left in play position = positive X here) --
        // MEASURED correct as-is, do not resize.
        translate([70, 0, 0]) cylinder(h=wall*4, d=20.5, center=true);

        // EC11 encoder bushing countersinks -- 13x13mm, centered on the
        // interior face (~3mm effective depth) -- MEASURED correct via
        // test-mk2.scad plate A, confirmed 2026-08-19 (was 14.3x14.3x1mm)
        translate([-35, enc_pos_y, -wall]) cube([13, 13, 6], center=true); // font
        translate([ 45, enc_pos_y, -wall]) cube([13, 13, 6], center=true); // octave
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

        // OLED viewing window, 2mm off-center -- MEASURED correct via
        // test-mk2.scad plate D, confirmed 2026-08-19
        translate([-60, -13, 0]) cube([28, 15, wall*4], center=true);

        // OLED back countersink — 30x30mm, centered on the interior face
        // (~3mm effective depth) -- MEASURED correct via test-mk2.scad
        // plate D, confirmed 2026-08-19 (was 30x30x2mm)
        translate([-60, -15, -wall])
        cube([30, 30, 6], center=true);

        translate([65, -15, 0]) cylinder(h=wall*4, d=24, center=true);

        // LED back recess — d=28, centered on the interior face (~3mm
        // effective depth) -- MEASURED correct via test-mk2.scad plate C,
        // confirmed 2026-08-19 (was d=28, 1mm deep)
        translate([65, -15, -wall])
        cylinder(h=6, d=28, center=true);
    }
}

// Toddler-safe hex-hole grill (stadium or, with gw=gh, round) — the
// hex-hole pattern itself was validated on the old test-mk2.scad plate E
// (removed 2026-08-19 once the speaker design changed to round grilles,
// see spk_cone_d/spk_cone_offset above); the pattern logic is unchanged.
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
