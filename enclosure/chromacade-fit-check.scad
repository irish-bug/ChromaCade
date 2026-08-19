// ChromaCade Synthesizer - Combined fit-check / mockup assembly
//
// Same methodology as grokwell-PiLC's pi_plc_rack.scad: one file, a PART
// selector at the top picks what gets rendered, ASSEMBLY previews
// everything together. Unlike that file, most PART options here are NOT
// printable -- they're simplified stand-in shapes (boxes/cylinders, no
// mechanical detail) for the controls/boards/speakers, sized off the best
// spec number available, so real hardware can be checked for clearance
// against the case and against each other before anything is finalized.
//
// HOW TO USE
//   - Set PART below to "ASSEMBLY" to see both real case pieces (rendered
//     translucent) with every mockup component placed where its matching
//     cutout actually is, or to one of BLANK_SIDE/POT_SIDE to view/export
//     just that real piece, or to a single mockup name to inspect one
//     component's placeholder geometry on its own (handy for holding a
//     caliper reading up against it).
//   - Only BLANK_SIDE and POT_SIDE are meant to ever be exported as an STL
//     and printed -- everything else here is a visual reference only, the
//     same way grokwell-PiLC's RAIL_REF is "draw it, don't print it."
//   - BLANK_SIDE/POT_SIDE are copies of chromacade-blank-side.scad /
//     chromacade-pot-side.scad's actual geometry, kept in sync by hand --
//     same deliberate copy-paste tradeoff as the rest of enclosure/ (see
//     CLAUDE.md). If you change a cutout or dimension in either standalone
//     file, mirror it here too, or this preview will lie about fit.
//   - Every mockup component's key dimensions are named constants in the
//     "MOCKUP COMPONENT DIMENSIONS" section below. Anything not measured
//     against the real part in hand is flagged ESTIMATE in a comment right
//     there -- update the constant once you've calipered the actual part,
//     which is the entire point of this file existing.
//   - blank-side's own 5 mount bosses are a known-stale placeholder right
//     now (own_mount_boss_centers in chromacade-blank-side.scad hasn't been
//     updated to match pot-side's corrected hole positions -- see that
//     file's comments and docs/decision-log.md). ASSEMBLY will show the two
//     pieces' mount points NOT lining up until that redesign happens; that's
//     expected, not a bug in this file, and doesn't affect the component
//     clearance checks this file is actually for.
$fn = 60;

/* [Render Selection] */
PART = "ASSEMBLY";
// [ASSEMBLY, BLANK_SIDE, POT_SIDE,
//  POT, OLED, LED_RING, LED_STRIP, PI4_STACK,
//  ROCKER_SWITCH, OCTAVE_ENCODER, FONT_ENCODER, JOYSTICK]

// ============================================================================
// GLOBAL DIMENSIONS -- must match chromacade-blank-side.scad and
// chromacade-pot-side.scad exactly (same profile, same shared-constant
// copy-paste convention as those two files -- see CLAUDE.md).
// ============================================================================
in2mm = 25.4;
case_w = 7.7   * in2mm; // 7in + 10%
case_d = 4.95  * in2mm; // 4.5in + 10%
wall   = 5;

front_h = 1.925 * in2mm; // 1.75in + 10%
shelf_d = 1.875 * in2mm; // 1.5in + 25% (controller shelf)
shelf_a = 8;
panel_l = 2.75  * in2mm; // 2.5in + 10%
panel_a = 45;

spk_grille_w = 1.0 * in2mm;
spk_grille_h = 1.5 * in2mm;
spk_cx       = 45;

p0 = [0, 0];
p1 = [case_d, 0];
p2 = [case_d, front_h];
p3 = [case_d - shelf_d*cos(shelf_a), front_h + shelf_d*sin(shelf_a)];
p4 = [p3[0] - panel_l*cos(panel_a), p3[1] + panel_l*sin(panel_a)];
p5 = [0, p4[1]];

case_h = p4[1];

shelf_my = (p2[0] + p3[0]) / 2;
shelf_mz = (p2[1] + p3[1]) / 2;
panel_my = (p3[0] + p4[0]) / 2;
panel_mz = (p3[1] + p4[1]) / 2;

edge_clearance = 0.15;

pilot_d   = 2.5;
clear_d   = 3.4;
engage    = 15;
boss_w    = 12;
boss_body = 14;
boss_ramp = 10;

pot_edge_x   = case_w/2 - wall - edge_clearance;   // pot-side's edge nearest blank-side
blank_edge_x = -case_w/2 + wall + edge_clearance;  // blank-side's edge nearest pot-side

// ============================================================================
// MOCKUP COMPONENT DIMENSIONS -- for VISUAL FIT-CHECK ONLY, not for printing.
// Every mockup module below is a simplified stand-in (bounding boxes /
// cylinders, no functional detail) sized off the best available spec
// number. Anything not independently MEASURED against the real part in
// hand is marked ESTIMATE -- correct these once you've calipered the
// actual hardware (docs/open-questions.md already flags this for the
// speaker; the same applies to everything else in this list now).
// ============================================================================

// Fender 500K pot -- standard full-size guitar pot. Bushing diameter
// MATCHES the d=9.525 (3/8in) hole already cut in chromacade-pot-side.scad's
// hardware_cutouts() -- that one's confirmed, not a guess.
POT_CAN_D     = 16;    // ESTIMATE: can diameter
POT_CAN_H     = 20;    // ESTIMATE: can depth
POT_BUSHING_D = 9.525; // MEASURED (matches the cut hole)
POT_BUSHING_H = 10;    // ESTIMATE: threaded bushing length
POT_SHAFT_D   = 6;     // ESTIMATE: shaft diameter
POT_SHAFT_H   = 15;    // ESTIMATE: shaft length beyond the bushing face (knob not modeled)
POT_LUG_LEN   = 8;     // ESTIMATE: solder lug stub length, for wiring clearance

// Hosyond 0.96in SSD1306 OLED. Window/pocket sizes below are the ones
// already cut in chromacade-blank-side.scad's hardware_cutouts() (28x15
// window, 30x30x2mm backside pocket) -- PCB/active-area numbers are
// ESTIMATEs for a common 0.96in SSD1306 board, verify against the actual
// Hosyond board once it's in hand.
OLED_PCB_W      = 27.3; // ESTIMATE
OLED_PCB_H      = 27.8; // ESTIMATE
OLED_PCB_T      = 1.6;  // ESTIMATE
OLED_ACTIVE_W   = 21.7; // ESTIMATE
OLED_ACTIVE_H   = 11.2; // ESTIMATE
OLED_HEADER_LEN = 8.5;  // ESTIMATE: pin header stack height behind the PCB

// WS2812 7-LED jewel ring. Diameter matches the d=24 window / d=28 backside
// recess already cut in chromacade-blank-side.scad.
LED_RING_D          = 24; // MEASURED (matches the cut hole/recess)
LED_RING_T          = 2;  // ESTIMATE: PCB thickness
LED_RING_HEADER_LEN = 6;  // ESTIMATE: in/out header stub

// WS2812 16-LED interior backlighting strip -- no matching cutout exists
// (it's not visible through a hole, just glued against the interior wall
// for the translucent shell to glow), so position/length here are
// illustrative only. Move LED_STRIP_LEN / the translate() in
// led_strip_mockup() once you've picked a real product and run.
LED_STRIP_LEN = 150; // ESTIMATE, sized to fit inside case_w with margin
LED_STRIP_W   = 10;  // ESTIMATE
LED_STRIP_T   = 2;   // ESTIMATE

// Raspberry Pi 4B + WM8960 audio HAT + breakout HAT, stacked on the GPIO
// header. Pi4 footprint/hole pattern is the official spec (reliable);
// HAT footprint/stack height are ESTIMATEs (standard HAT spec), verify
// against the actual WM8960 board -- some clones aren't full HAT-sized.
// Floor mounting position is illustrative only; no standoff bosses exist
// on the real bottom panel yet.
PI4_W        = 85; PI4_H = 56; PI4_T = 1.6; // MEASURED-class: official Pi4B spec
PI4_HOLE_DX  = 58; PI4_HOLE_DY = 49; PI4_HOLE_D = 2.9; // official mounting pattern
HAT_W        = 65; HAT_H = 56; HAT_T = 1.6; // ESTIMATE: standard HAT footprint
HAT_STACK_GAP = 8.5; // ESTIMATE: standard GPIO stacking header pitch
CABLE_BUNDLE_D = 6;  // ESTIMATE: rough wiring-bundle visual placeholder

// XINYIELE 3-way round rocker switch (flat/natural/sharp). Hole diameter
// matches the d=28 hole already cut on the shelf in
// chromacade-blank-side.scad -- UNVERIFIED against the real part (28mm is
// large for a round panel rocker; flag this for measurement specifically).
ROCKER_HOLE_D   = 28; // matches the cut hole -- verify against real part
ROCKER_FLANGE_D = 32; // ESTIMATE: cap/flange OD beyond the hole
ROCKER_BODY_D   = 22; // ESTIMATE: body diameter behind the panel
ROCKER_BODY_H   = 25; // ESTIMATE: body depth behind the panel incl. lugs

// EC11 rotary encoder w/ push-button (octave + font, same part both
// places). Bushing diameter matches the d=7 hole already cut; body
// footprint matches the 14.3x14.3 countersink with margin.
ENC_BODY_W    = 12.8; // ESTIMATE (fits inside the 14.3x14.3 countersink)
ENC_BODY_H    = 12.8; // ESTIMATE
ENC_BODY_D    = 13;   // ESTIMATE: metal can depth behind the panel
ENC_BUSHING_D = 7;    // MEASURED (matches the cut hole)
ENC_SHAFT_H   = 15;   // ESTIMATE: shaft length beyond the bushing (knob not modeled)
ENC_PIN_LEN   = 5;    // ESTIMATE: 5-pin header stub length

// KY-023 dual-axis analog joystick module. Stick hole matches the d=20.5
// hole already cut on the shelf.
JOY_PCB_W   = 27;   // ESTIMATE: common KY-023 module size
JOY_PCB_H   = 27;   // ESTIMATE
JOY_PCB_T   = 1.6;  // ESTIMATE
JOY_STICK_D = 20.5; // MEASURED (matches the cut hole)
JOY_BALL_D  = 15;   // ESTIMATE: stick ball-cap diameter
JOY_STICK_H = 20;   // ESTIMATE: stick height above the panel exterior

// ============================================================================
// SHARED PROFILE HELPERS -- identical between chromacade-blank-side.scad and
// chromacade-pot-side.scad, so defined once here rather than duplicated.
// ============================================================================
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

// Full-hexagon endcap slice, wall-thick, at one piece's own X extreme.
// side=-1 -> endcap at X=-case_w/2 (pot side); side=1 -> X=+case_w/2 (blank side).
module endcap(side) {
    intersection() {
        shell_solid();
        translate([side * (case_w/2 - wall/2), case_d/2, case_h/2])
        cube([wall, case_d + 80, case_h + 80], center=true);
    }
}

// Toddler-safe portrait stadium hex grill, shared by both pieces' speaker/
// fan-vent cutouts.
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

// ============================================================================
// POT-SIDE -- copy of chromacade-pot-side.scad's own geometry (see header
// note above about keeping this in sync by hand).
// ============================================================================
module square_boss(x0, pos, thick_axis, z_start=0, height=boss_w) {
    if (thick_axis == "z") {
        translate([x0 - boss_body, pos - boss_w/2, z_start])
        cube([boss_body, boss_w, height]);

        hull() {
            translate([x0 - boss_body - 0.01, pos - boss_w/2, z_start])
            cube([0.01, boss_w, height]);

            translate([x0 - boss_body - boss_ramp, pos - boss_w/2, z_start])
            cube([0.01, boss_w, 0.01]);
        }
    } else {
        translate([x0 - boss_body, 0, pos - boss_w/2])
        cube([boss_body, boss_w, boss_w]);

        hull() {
            translate([x0 - boss_body - 0.01, 0, pos - boss_w/2])
            cube([0.01, boss_w, boss_w]);

            translate([x0 - boss_body - boss_ramp, 0, pos - boss_w/2])
            cube([0.01, 0.01, boss_w]);
        }
    }
}

pot_blank_side_mount_yz = [
    [100, 12],
    [100, 42],
    [74, 48],
    [45, 73],
    [14, 95],
];

module pot_side_mount_bosses() {
    square_boss(pot_edge_x, 100, "z", z_start=wall, height=boss_w);
    square_boss(pot_edge_x, 30, "z", z_start=wall, height=boss_w);
    square_boss(pot_edge_x, 85, "y");
    square_boss(pot_edge_x, 20, "y");
}

module pot_side_mounts() {
    translate([pot_edge_x, 100, wall + boss_w/2]) rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    translate([pot_edge_x, 30, wall + boss_w/2])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    translate([pot_edge_x, boss_w/2, 85])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    translate([pot_edge_x, boss_w/2, 20])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
}

module pot_side_clearance_holes() {
    for (yz = pot_blank_side_mount_yz) {
        translate([-case_w/2 + wall/2, yz[0], yz[1]])
        rotate([0, 90, 0]) cylinder(h=wall + 10, d=clear_d, center=true);
    }
}

module pot_yz_half_plane(side) {
    seam = p5 - p1;
    perp = side * [-seam[1], seam[0]];
    perp_unit = perp / norm(perp);
    seam_margin = 1;
    p1m = p1 + perp_unit*seam_margin;
    p5m = p5 + perp_unit*seam_margin;
    big = 2000;
    pts = [p1m, p5m, p5m + perp_unit*big, p1m + perp_unit*big];
    rotate([90, 0, 90])
    linear_extrude(case_w, center=true)
    polygon(pts);
}

module pot_strips() {
    intersection() {
        shell_solid();
        pot_yz_half_plane(1); // back+bottom side (contains p0)
        translate([-(wall + edge_clearance)/2, case_d/2, case_h/2])
        cube([case_w - wall - edge_clearance, case_d + 80, case_h + 80], center=true);
    }
}

module pot_hardware_cutouts() {
    // Volume pot hole for the Fender 500K -- 3/8in (9.525mm) mounting bushing.
    translate([-case_w/2, case_d/4, case_h/3])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=9.525, center=true);

    // Power cable passthrough intentionally omitted here (see
    // chromacade-pot-side.scad -- unit #2 goes straight to the LiPo/
    // boost-charge board; a cable passthrough will live on blank-side
    // instead if still needed).

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

module pot_side_piece() {
    difference() {
        union() {
            endcap(-1);
            pot_strips();
            pot_side_mount_bosses();
        }
        pot_hardware_cutouts();
        pot_side_mounts();
        pot_side_clearance_holes();
    }
}

// ============================================================================
// BLANK-SIDE -- copy of chromacade-blank-side.scad's own geometry (see
// header note above about keeping this in sync by hand, and about the
// known-stale own_mount_boss_centers array pending a redesign).
// ============================================================================
module own_mount_boss(y_c, z_c) {
    margin = 15;
    intersection() {
        translate([blank_edge_x, y_c - margin, z_c - margin])
        cube([boss_body, margin * 2, margin * 2]);
        interior_void();
    }
    far_margin = 3;
    hull() {
        intersection() {
            translate([blank_edge_x + boss_body - 0.01, y_c - margin, z_c - margin])
            cube([0.01, margin * 2, margin * 2]);
            interior_void();
        }
        intersection() {
            translate([blank_edge_x + boss_body + boss_ramp - 0.01, y_c - far_margin, z_c - far_margin])
            cube([0.01, far_margin * 2, far_margin * 2]);
            interior_void();
        }
    }
}

module interior_void() {
    rotate([90, 0, 90])
    linear_extrude(case_w - (wall * 2), center=true)
    offset(delta = -wall) outer_profile();
}

own_mount_boss_centers = [
    [case_d - boss_w/2, 14],
    [case_d - boss_w/2, 41.56],
    [85.29, 52.05],
    [34.82, 95.74],
    [14, case_h - boss_w/2],
];

pot_side_mount_yz = [
    [100, wall + boss_w/2],
    [30, wall + boss_w/2],
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
        translate([blank_edge_x, yz[0], yz[1]]) rotate([0, 90, 0]) cylinder(h=engage, d=pilot_d);
    }
}

module blank_side_clearance_holes() {
    for (yz = pot_side_mount_yz) {
        translate([case_w/2 - wall/2, yz[0], yz[1]])
        rotate([0, 90, 0]) cylinder(h=wall + 10, d=clear_d, center=true);
    }
}

module blank_yz_half_plane(side) {
    seam = p5 - p1;
    perp = side * [-seam[1], seam[0]];
    perp_unit = perp / norm(perp);
    seam_margin = 3;
    p1m = p1 + perp_unit*seam_margin;
    p5m = p5 + perp_unit*seam_margin;
    big = 2000;
    pts = [p1m, p5m, p5m + perp_unit*big, p1m + perp_unit*big];
    rotate([90, 0, 90])
    linear_extrude(case_w, center=true)
    polygon(pts);
}

module blank_strips() {
    intersection() {
        shell_solid();
        blank_yz_half_plane(-1); // front+shelf+panel+top side (away from p0)
        translate([(wall + edge_clearance)/2, case_d/2, case_h/2])
        cube([case_w - wall - edge_clearance, case_d + 80, case_h + 80], center=true);
    }
}

module blank_hardware_cutouts() {
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        translate([-spk_cx, 0, 0]) rotate([0, 0, 90]) stadium_hex_grill(spk_grille_w, spk_grille_h);
        translate([ spk_cx, 0, 0]) rotate([0, 0, 90]) stadium_hex_grill(spk_grille_w, spk_grille_h);
    }

    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        translate([-65, 0, 0]) cylinder(h=wall*4, d=28, center=true);
        translate([-35, 0, 0]) cylinder(h=wall*4, d=7,  center=true);
        translate([45, 0, 0]) cylinder(h=wall*4, d=7,  center=true);
        translate([70, 0, 0]) cylinder(h=wall*4, d=20.5, center=true);

        translate([-35, 0, -(wall - 0.5)]) cube([14.3, 14.3, 1], center=true);
        translate([ 45, 0, -(wall - 0.5)]) cube([14.3, 14.3, 1], center=true);
    }

    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        for (i = [-3:3]) {
            translate([i * 19.05, 15, 0])
            cube([14.3, 14.3, wall*4], center=true);
        }

        translate([0, 15, -3.25])
        cube([140, 20, 3.5], center=true);

        translate([-60, -15, 0]) cube([28, 15, wall*4], center=true);

        translate([-60, -15, -(wall - 1)])
        cube([30, 30, 2], center=true);

        translate([65, -15, 0]) cylinder(h=wall*4, d=24, center=true);

        translate([65, -15, -(wall - 0.5)])
        cylinder(h=1, d=28, center=true);
    }
}

module blank_side_piece() {
    difference() {
        union() {
            endcap(1);
            blank_strips();
            blank_side_mount_bosses();
        }
        blank_hardware_cutouts();
        blank_side_mounts();
        blank_side_clearance_holes();
    }
}

// ============================================================================
// MOCKUP COMPONENTS -- each placed at the exact coordinates of its matching
// cutout in blank_hardware_cutouts()/pot_hardware_cutouts() above, using the
// same translate()/rotate() so it lines up automatically if those cutout
// positions change. Interior is -z, exterior is +z in each control's local
// frame, following the sign convention already established by the real
// cutout comments (e.g. "interior face" countersinks sit at negative z).
// ============================================================================

module pot_mockup() {
    color("Silver")
    translate([-case_w/2, case_d/4, case_h/3])
    rotate([0, 90, 0]) {
        // shaft -- mostly outside the case; knob not modeled
        translate([0, 0, -POT_SHAFT_H]) cylinder(h = POT_SHAFT_H + 2, d = POT_SHAFT_D);
        // bushing -- crosses the wall
        translate([0, 0, -1]) cylinder(h = POT_BUSHING_H + 1, d = POT_BUSHING_D);
        // can/body -- fully inside the case
        translate([0, 0, POT_BUSHING_H]) cylinder(h = POT_CAN_H, d = POT_CAN_D);
        // 3 solder lugs
        for (a = [0, 120, 240])
            translate([0, 0, POT_BUSHING_H + POT_CAN_H])
                rotate([0, 0, a])
                    translate([POT_CAN_D/2 - 1, 0, 0])
                        cylinder(h = POT_LUG_LEN, d = 1.5);
    }
}

module oled_mockup() {
    color("MidnightBlue")
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        // glass/active area, right at the panel's exterior face
        translate([-60, -15, 0.5]) cube([OLED_ACTIVE_W, OLED_ACTIVE_H, 1], center=true);
        // PCB, behind the back countersink pocket, into the interior
        translate([-60, -15, -(wall + OLED_PCB_T/2)]) cube([OLED_PCB_W, OLED_PCB_H, OLED_PCB_T], center=true);
        // pin header stub, further into the interior
        translate([-60, -15 - OLED_PCB_H/2 + 3, -(wall + OLED_PCB_T + OLED_HEADER_LEN/2)])
            cube([10, 3, OLED_HEADER_LEN], center=true);
    }
}

module led_ring_mockup() {
    color("MediumOrchid")
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        translate([65, -15, -(wall - 0.5) - LED_RING_T/2]) cylinder(h = LED_RING_T, d = LED_RING_D, center = true);
        translate([65, -15, -(wall - 0.5) - LED_RING_T - LED_RING_HEADER_LEN/2])
            cube([6, 10, LED_RING_HEADER_LEN], center = true);
    }
}

// Illustrative only -- no matching cutout, see LED_STRIP_LEN comment above.
module led_strip_mockup() {
    color("Cyan")
    translate([-LED_STRIP_LEN/2, case_d - wall - LED_STRIP_T/2, front_h - 15])
        cube([LED_STRIP_LEN, LED_STRIP_T, LED_STRIP_W]);
}

// Illustrative floor position only -- no standoff bosses exist yet.
module pi4_stack_mockup() {
    translate([-PI4_W/2, 15, wall]) {
        color("ForestGreen") cube([PI4_W, PI4_H, PI4_T]);
        translate([(PI4_W - HAT_W)/2, (PI4_H - HAT_H)/2, HAT_STACK_GAP])
            color("DarkOrange") cube([HAT_W, HAT_H, HAT_T]);
        translate([(PI4_W - HAT_W)/2, (PI4_H - HAT_H)/2, HAT_STACK_GAP * 2])
            color("SteelBlue") cube([HAT_W, HAT_H, HAT_T]);
        // rough wiring-bundle placeholder, routed up toward the shelf controls
        color("DimGray")
        translate([PI4_W - 5, PI4_H/2, HAT_STACK_GAP * 2 + HAT_T])
            rotate([0, -60, 0])
                cylinder(h = 60, d = CABLE_BUNDLE_D);
    }
}

module rocker_mockup() {
    color("Crimson")
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        translate([-65, 0, 1]) cylinder(h = 2, d = ROCKER_FLANGE_D, center = true);
        translate([-65, 0, -ROCKER_BODY_H/2]) cylinder(h = ROCKER_BODY_H, d = ROCKER_BODY_D, center = true);
    }
}

// Shared by both octave (x=-35) and font (x=45) encoders -- same part.
module encoder_mockup(x, c = "Goldenrod") {
    color(c)
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        // shaft, poking outward -- knob not modeled
        translate([x, 0, 0]) cylinder(h = ENC_SHAFT_H, d = 4);
        // bushing, crossing the panel
        translate([x, 0, -wall]) cylinder(h = wall + 1, d = ENC_BUSHING_D);
        // body/can, fully inside the case
        translate([x - ENC_BODY_W/2, -ENC_BODY_H/2, -wall - ENC_BODY_D])
            cube([ENC_BODY_W, ENC_BODY_H, ENC_BODY_D]);
        // 5-pin header stub
        translate([x, 0, -wall - ENC_BODY_D - ENC_PIN_LEN])
            cube([8, 2, ENC_PIN_LEN], center = true);
    }
}

module joystick_mockup() {
    color("DarkSlateBlue")
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        jx = 70;
        // PCB, mounted just inside the shelf
        translate([jx - JOY_PCB_W/2, -JOY_PCB_H/2, -wall - JOY_PCB_T])
            cube([JOY_PCB_W, JOY_PCB_H, JOY_PCB_T]);
        // stick shaft, through the panel hole
        translate([jx, 0, -wall]) cylinder(h = wall + JOY_STICK_H, d = 6);
        // ball cap, above the panel exterior
        translate([jx, 0, JOY_STICK_H]) sphere(d = JOY_BALL_D);
    }
}

// ============================================================================
// ASSEMBLY (preview only) -- both real pieces rendered translucent so every
// mockup component is visible inside.
// ============================================================================
module assembly() {
    color([0.85, 0.9, 0.95, 0.25]) pot_side_piece();
    color([0.85, 0.9, 0.95, 0.25]) blank_side_piece();

    pot_mockup();
    oled_mockup();
    led_ring_mockup();
    led_strip_mockup();
    pi4_stack_mockup();
    rocker_mockup();
    encoder_mockup(-35, "Goldenrod");
    encoder_mockup(45, "DarkGoldenrod");
    joystick_mockup();
}

// ============================================================================
// RENDER SELECTOR
// ============================================================================
if (PART == "ASSEMBLY") assembly();
else if (PART == "BLANK_SIDE") blank_side_piece();
else if (PART == "POT_SIDE") pot_side_piece();

else if (PART == "POT") pot_mockup();
else if (PART == "OLED") oled_mockup();
else if (PART == "LED_RING") led_ring_mockup();
else if (PART == "LED_STRIP") led_strip_mockup();
else if (PART == "PI4_STACK") pi4_stack_mockup();
else if (PART == "ROCKER_SWITCH") rocker_mockup();
else if (PART == "OCTAVE_ENCODER") encoder_mockup(-35);
else if (PART == "FONT_ENCODER") encoder_mockup(45);
else if (PART == "JOYSTICK") joystick_mockup();
