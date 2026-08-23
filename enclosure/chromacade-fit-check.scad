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
//   - blank-side's own 4 mount bosses (was 5 until 2026-08-19 -- the
//     shelf/panel joint mount was removed) are now correct: positions
//     match pot-side's blank_side_mount_yz exactly, and all 4 use the
//     same square-cylinder boss technique, wall-anchored, as pot-side's
//     square_boss(). See that file's comments for the earlier history if
//     it comes up (a position-drift bug, a wrong-anchor/wrong-shape bug,
//     and a mount-count/position revision were all found and fixed the
//     same day).
$fn = 60;

/* [Render Selection] */
PART = "ASSEMBLY";
// [ASSEMBLY, BLANK_SIDE, POT_SIDE,
//  POT, OLED, LED_RING, LED_STRIP, PI4_STACK,
//  ROCKER_SWITCH, OCTAVE_ENCODER, FONT_ENCODER, JOYSTICK, NOTE_SWITCHES,
//  SPEAKER_HOUSING]

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
shelf_d = 60; // 2026-08-22: increased from 1.875in+25% (47.625mm), see
               // chromacade-blank-side.scad for the reasoning (joystick
               // repositioning, joy_reserved_front/joy_y_offset).
shelf_a = 8;
panel_l = 2.75  * in2mm; // 2.5in + 10%
panel_a = 45;

spk_cone_d      = 35;
spk_cone_offset = 22.5;

// Both shelf encoders shifted -7mm along the shelf (toward the back, away
// from the front wall) 2026-08-19 -- their bodies were colliding with the
// new single speaker housing by ~1.7mm at pos_y=0; -7mm clears it with
// 5.27mm to spare (>= the 5mm minimum specified). Shared by
// blank_hardware_cutouts() and encoder_mockup() below -- must be a
// top-level constant, not declared inside hardware_cutouts()'s own block,
// or encoder_mockup() can't see it.
enc_pos_y = -7;

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
POT_CAN_D     = 24;    // MEASURED 2026-08-20 -- was 16 (ESTIMATE), significantly
                        // bigger than assumed; this drove a real position fix,
                        // see chromacade-pot-side.scad's hardware_cutouts()
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
// and interior body size MEASURED against the real part 2026-08-18 -- the
// hole is confirmed correct as already cut; the body is a full 40mm-deep
// cylinder (factory wire leads included in that reach) unless the leads
// get desoldered and rewired directly by hand, which is a last resort,
// not the default plan -- don't shrink this to "just the switch" depth.
ROCKER_HOLE_D   = 20.5; // MEASURED: confirmed correct as already cut (corrected 2026-08-19, was briefly set to 20 exact then reverted)
ROCKER_FLANGE_D = 32; // ESTIMATE: cap/flange OD beyond the hole
ROCKER_BODY_D   = 20; // MEASURED
ROCKER_BODY_H   = 40; // MEASURED (factory wire leads included)

// EC11 rotary encoder w/ push-button (octave + font, same part both
// places). Bushing diameter and body footprint MEASURED against the real
// part 2026-08-18 -- body (15x12mm) is slightly WIDER than the existing
// 14.3x14.3mm back countersink in chromacade-blank-side.scad's
// hardware_cutouts(), so that countersink pocket likely needs to grow to
// actually clear it. Flagged here, not fixed -- not part of this pass.
ENC_BODY_W    = 15;   // MEASURED
ENC_BODY_H    = 12;   // MEASURED
ENC_BODY_D    = 10;   // MEASURED: body depth behind the panel
ENC_BUSHING_D = 7;    // MEASURED (matches the cut hole)
ENC_SHAFT_H   = 15;   // ESTIMATE: shaft length beyond the bushing (knob not modeled)
ENC_PIN_LEN   = 5;    // ESTIMATE: 5-pin header stub length

// KY-023 dual-axis analog joystick module. Board size and its 4 mounting-
// hole positions (relative to the joystick's own center) MEASURED against
// the real board 2026-08-18. Stick hole diameter CONFIRMED 2026-08-19 at
// 27mm (was 28mm on the original pre-boss print, then 26.5mm -- a tiny bit
// too small -- see chromacade-blank-side.scad). Mounting boss positions/
// sizes are defined down in the BLANK-SIDE section (joystick_boss_xy()
// etc.), shared by the real piece and this mockup.
JOY_PCB_W      = 26;   // MEASURED
JOY_PCB_H      = 33;   // MEASURED
JOY_PCB_T      = 1.6;  // ESTIMATE
JOY_STICK_D    = 27;   // CONFIRMED 2026-08-19
JOY_BALL_D     = 15;   // ESTIMATE: stick ball-cap diameter
JOY_STICK_H    = 20;   // ESTIMATE: stick height above the panel exterior
JOY_HEADER_LEN = 5;    // MEASURED: 4-pin header stub off the board's back

// MX note-key switches (7x, panel). Cutout is already correct and not
// changing here -- switches reach MX_SWITCH_DEPTH into the interior below
// the panel's back face, MEASURED 2026-08-18.
MX_SWITCH_DEPTH = 8; // MEASURED

// NEW dual-cone speaker housing (2026-08-18, resolved to ONE housing
// 2026-08-19) -- landscape housing, 20mm deep, 98x43mm footprint, with 2x
// 35mm cones inside, each centered 22.5mm off the housing's own center
// (i.e. 45mm apart), vertically centered on the 43mm dimension. MEASURED
// against the real part. Two separate housings (4 total cones) were
// considered and don't fit within the 8in print bed (would need
// case_w >= 206mm minimum, just to sit edge-to-edge with zero margin) --
// see docs/decision-log.md. This build uses ONE housing centered on the
// front wall (2 total cones), matching blank_hardware_cutouts()'s
// spk_cone_d/spk_cone_offset above.
SPK_HOUSING_W   = 98; // MEASURED
SPK_HOUSING_H   = 43; // MEASURED
SPK_HOUSING_D   = 20; // MEASURED
SPK_CONE_D      = 35; // MEASURED
SPK_CONE_OFFSET = 22.5; // MEASURED: each cone's offset from the housing center

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
module square_boss(x0, pos, thick_axis, z_start=0, height=boss_w, y_start=0) {
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
        translate([x0 - boss_body, y_start, pos - boss_w/2])
        cube([boss_body, height, boss_w]);

        hull() {
            translate([x0 - boss_body - 0.01, y_start, pos - boss_w/2])
            cube([0.01, height, boss_w]);

            translate([x0 - boss_body - boss_ramp, y_start, pos - boss_w/2])
            cube([0.01, 0.01, boss_w]);
        }
    }
}

// panel/top joint updated 2026-08-22 (56.701,61.834 -> 44.447,63.556) --
// see chromacade-blank-side.scad's own_mount_boss_centers comment; this
// entry is a static snapshot that goes stale whenever shelf_d (or any
// other p0-p5 upstream dimension) changes.
pot_blank_side_mount_yz = [
    [114.73, 12],
    [114.73, 42],
    [44.447, 63.556],
    [14, 95],
];

module pot_side_mount_bosses() {
    square_boss(pot_edge_x, 110, "z", z_start=wall, height=boss_w);
    square_boss(pot_edge_x, 30, "z", z_start=wall, height=boss_w);
    square_boss(pot_edge_x, 85, "y", y_start=wall, height=boss_w);
    square_boss(pot_edge_x, 20, "y", y_start=wall, height=boss_w);
}

module pot_side_mounts() {
    translate([pot_edge_x, 110, wall + boss_w/2]) rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    translate([pot_edge_x, 30, wall + boss_w/2])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    translate([pot_edge_x, wall + boss_w/2, 85])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
    translate([pot_edge_x, wall + boss_w/2, 20])  rotate([0, -90, 0]) cylinder(h=engage, d=pilot_d);
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

// Cooling fan cutout -- copy of chromacade-pot-side.scad's fan_cutout(),
// kept in sync by hand (see header note at the top of this file). See
// that file's comments for the full position derivation/history.
fan_y = 53;
fan_z = 35;
fan_grille_d     = 26;
fan_hole_spacing = 24;
fan_pilot_d      = 2.4;

module pot_fan_cutout() {
    translate([-case_w/2, fan_y, fan_z])
    rotate([0, 90, 0]) {
        stadium_hex_grill(fan_grille_d, fan_grille_d);
        for (dy = [-fan_hole_spacing/2, fan_hole_spacing/2])
            for (dz = [-fan_hole_spacing/2, fan_hole_spacing/2])
                translate([dy, dz, 0])
                cylinder(h=wall*4, d=fan_pilot_d, center=true);
    }
}

module pot_hardware_cutouts() {
    // Volume pot hole for the Fender 500K -- 3/8in (9.525mm) mounting
    // bushing. MOVED 2026-08-19/20, three times -- (case_d/4, case_h/3) to
    // (15, 48) to (18, 45) once the real 24mm can size (not the old 16mm
    // estimate) showed only 3mm of edge clearance at (15,48), then by hand
    // to the current (22, 65) for still more margin (10.00mm to the case
    // profile edge, still the best of the three positions tried). See
    // chromacade-pot-side.scad's hardware_cutouts() comment for the full
    // numbers.
    translate([-case_w/2, 22, 65])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=9.525, center=true);

    // Power cable passthrough intentionally omitted here (see
    // chromacade-pot-side.scad -- unit #2 goes straight to the LiPo/
    // boost-charge board; a cable passthrough will live on blank-side
    // instead if still needed).

    pot_fan_cutout();
}

// Raspberry Pi 4B mounting bosses -- copy of chromacade-pot-side.scad's own
// pi_mount_boss()/pi_mount_bosses()/pi_mount_pilot_holes(), kept in sync by
// hand (see header note at the top of this file). See that file's comment
// for the full measurement rationale (58x49mm official Pi4B hole spacing,
// 10mm minimum back-wall clearance).
pi_hole_dx        = 29;
pi_hole_dy        = 24.5;
pi_board_h        = 56;
pi_back_clearance = 15;
pi_cx             = 0;
pi_near_y         = wall + pi_back_clearance;
pi_cy             = pi_near_y + pi_board_h/2;
pi_boss_h    = 5;
pi_boss_w    = 6;
pi_boss_ramp = 6;
pi_pilot_d   = 2.4;

function pi_mount_xy() = [
    [pi_cx - pi_hole_dx, pi_cy - pi_hole_dy],
    [pi_cx + pi_hole_dx, pi_cy - pi_hole_dy],
    [pi_cx - pi_hole_dx, pi_cy + pi_hole_dy],
    [pi_cx + pi_hole_dx, pi_cy + pi_hole_dy],
];

module pi_mount_boss(cx, cy) {
    translate([cx - pi_boss_w/2, cy - pi_boss_w/2, wall])
    cube([pi_boss_w, pi_boss_w, pi_boss_h]);

    hull() {
        translate([cx - pi_boss_w/2 - 0.01, cy - pi_boss_w/2, wall])
        cube([0.01, pi_boss_w, pi_boss_h]);

        translate([cx - pi_boss_w/2 - pi_boss_ramp, cy - pi_boss_w/2, wall])
        cube([0.01, pi_boss_w, 0.01]);
    }
}

module pi_mount_bosses() {
    for (p = pi_mount_xy())
        pi_mount_boss(p[0], p[1]);
}

module pi_mount_pilot_holes() {
    for (p = pi_mount_xy())
        translate([p[0], p[1], wall - 0.5])
        cylinder(h = pi_boss_h + 1, d = pi_pilot_d);
}

module pot_side_piece() {
    difference() {
        union() {
            endcap(-1);
            pot_strips();
            pot_side_mount_bosses();
            pi_mount_bosses();
        }
        pot_hardware_cutouts();
        pot_side_mounts();
        pot_side_clearance_holes();
        pi_mount_pilot_holes();
    }
}

// ============================================================================
// BLANK-SIDE -- copy of chromacade-blank-side.scad's own geometry (see
// header note above about keeping this in sync by hand). All 4 mounts use
// the same flat_mount_boss() square-cylinder technique now (2026-08-19) --
// front_bottom/front_top/top_back unrotated (flush against a global-frame
// wall), panel_top wrapped in the panel's own rotate() (panel_mount_boss())
// since it sits at a tilted joint -- see
// chromacade-blank-side.scad's fuller comments on both, kept brief here.
// ============================================================================
module flat_mount_boss(pos, thick_axis, wall_z=-wall, wall_y=-wall) {
    if (thick_axis == "z") {
        translate([blank_edge_x, pos - boss_w/2, wall_z - boss_w])
        cube([boss_body, boss_w, boss_w]);

        hull() {
            translate([blank_edge_x + boss_body - 0.01, pos - boss_w/2, wall_z - boss_w])
            cube([0.01, boss_w, boss_w]);

            translate([blank_edge_x + boss_body + boss_ramp - 0.01, pos - boss_w/2, wall_z - 0.01])
            cube([0.01, boss_w, 0.01]);
        }
    } else {
        translate([blank_edge_x, wall_y - boss_w, pos - boss_w/2])
        cube([boss_body, boss_w, boss_w]);

        hull() {
            translate([blank_edge_x + boss_body - 0.01, wall_y - boss_w, pos - boss_w/2])
            cube([0.01, boss_w, boss_w]);

            translate([blank_edge_x + boss_body + boss_ramp - 0.01, wall_y - 0.01, pos - boss_w/2])
            cube([0.01, 0.01, boss_w]);
        }
    }
}

module panel_mount_boss(pos_y) {
    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0])
    flat_mount_boss(pos_y, "z");
}

// panel_top updated 2026-08-22, same reasoning as pot_blank_side_mount_yz
// above and chromacade-blank-side.scad's own_mount_boss_centers.
own_mount_boss_centers = [
    [114.73, 12],
    [114.73, 42],
    [44.447, 63.556],
    [14, 95],
];

pot_side_mount_yz = [
    [110, wall + boss_w/2],
    [30, wall + boss_w/2],
    [wall + boss_w/2, 85],
    [wall + boss_w/2, 20],
];

module blank_side_mount_bosses() {
    flat_mount_boss(own_mount_boss_centers[0][1], "y", wall_y=case_d-wall); // front_bottom
    flat_mount_boss(own_mount_boss_centers[1][1], "y", wall_y=case_d-wall); // front_top
    panel_mount_boss(15); // panel_top (tilted joint, panel's own frame, local y=15 -- in line with the note keys)
    flat_mount_boss(own_mount_boss_centers[3][0], "z", wall_z=case_h-wall); // top_back
}

module blank_side_mounts() {
    for (yz = own_mount_boss_centers) {
        translate([blank_edge_x, yz[0], yz[1]]) rotate([0, 90, 0]) cylinder(h=engage, d=pilot_d);
    }
}

// Gap-blocking bridges -- mirrored from chromacade-blank-side.scad, see
// that file's own extensive comment for the full design history (three
// real bugs found and fixed via the real-geometry interference check
// before printing: solid-not-hollow endcap, corner rounding, edge-vs-
// volume overlap). Verified margin ~2mm against pot-side's real,
// already-printed geometry.
gap_bridge_x_far   = -99;
gap_bridge_x_near  = -87;
gap_bridge_proud   = 3;
gap_anchor_x_far   = -90;
gap_anchor_x_near  = -85;

module gap_lip_front_bottom() {
    translate([(gap_anchor_x_near + gap_anchor_x_far)/2, (124.5 + case_d + 1)/2, 18])
    cube([gap_anchor_x_near - gap_anchor_x_far, (case_d + 1) - 124.5, 20], center=true);
    translate([(gap_bridge_x_near + gap_bridge_x_far)/2, (case_d + case_d + gap_bridge_proud)/2, 18])
    cube([gap_bridge_x_near - gap_bridge_x_far, gap_bridge_proud, 20], center=true);
}

module gap_lip_top_back() {
    translate([(gap_anchor_x_near + gap_anchor_x_far)/2, 18, (103.5 + case_h + 1)/2])
    cube([gap_anchor_x_near - gap_anchor_x_far, 20, (case_h + 1) - 103.5], center=true);
    translate([(gap_bridge_x_near + gap_bridge_x_far)/2, 18, (case_h + case_h + gap_bridge_proud)/2])
    cube([gap_bridge_x_near - gap_bridge_x_far, 20, gap_bridge_proud], center=true);
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

// Cooling fan cutout, blank-side's endcap -- copy of
// chromacade-blank-side.scad's fan_cutout(), kept in sync by hand. Same
// fan_y/fan_z/etc. constants as pot_fan_cutout() above (defined once,
// shared by both endcaps here, matching the real production files' Y,Z
// values being identical on both pieces).
module blank_fan_cutout() {
    translate([case_w/2, fan_y, fan_z])
    rotate([0, 90, 0]) {
        stadium_hex_grill(fan_grille_d, fan_grille_d);
        for (dy = [-fan_hole_spacing/2, fan_hole_spacing/2])
            for (dz = [-fan_hole_spacing/2, fan_hole_spacing/2])
                translate([dy, dz, 0])
                cylinder(h=wall*4, d=fan_pilot_d, center=true);
    }
}

module blank_hardware_cutouts() {
    blank_fan_cutout();

    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        translate([-spk_cone_offset, 0, 0]) stadium_hex_grill(spk_cone_d, spk_cone_d);
        translate([ spk_cone_offset, 0, 0]) stadium_hex_grill(spk_cone_d, spk_cone_d);
    }

    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        // Joystick, far right in play position (-X here) -- see JOY_STICK_D
        translate([-65, 0, 0]) cylinder(h=wall*4, d=JOY_STICK_D, center=true);
        // Both encoders shifted -7mm along the shelf (toward the back) --
        // see chromacade-blank-side.scad for the full rationale (clears
        // the speaker housing collision, 5.27mm to spare).
        translate([-35, enc_pos_y, 0]) cylinder(h=wall*4, d=7,  center=true); // font encoder
        translate([45, enc_pos_y, 0]) cylinder(h=wall*4, d=7,  center=true);  // octave encoder
        // Rocker switch, far left in play position (+X here) -- MEASURED correct
        translate([70, 0, 0]) cylinder(h=wall*4, d=20.5, center=true);

        translate([-35, enc_pos_y, -wall]) cube([13, 13, 6], center=true); // font
        translate([ 45, enc_pos_y, -wall]) cube([13, 13, 6], center=true); // octave
    }

    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        for (i = [-3:3]) {
            translate([i * 19.05, 15, 0])
            cube([14.3, 14.3, wall*4], center=true);
        }

        translate([0, 15, -3.25])
        cube([140, 20, 3.5], center=true);

        translate([-60, -13, 0]) cube([28, 15, wall*4], center=true);

        translate([-60, -15, -wall])
        cube([30, 30, 6], center=true);

        translate([65, -15, 0]) cylinder(h=wall*4, d=24, center=true);

        translate([65, -15, -wall])
        cylinder(h=6, d=28, center=true);
    }
}

// Joystick (KY-023) mounting bosses + pilot holes + gimbal clearance --
// PORTED BACK 2026-08-19, matching chromacade-blank-side.scad exactly
// (see that file's comment for the full design history/rationale).
joy_x             = -65; // matches the shelf's joystick stick-hole X position
joy_hole_dx       = 9;
joy_hole_front_dy = 14;
joy_hole_back_dy  = -12.5;
joy_boss_h        = 12;
joy_boss_d        = 6;
joy_pilot_d       = 2.5;
joy_gimbal_r      = 13.5;

function joystick_boss_xy() = [
    [-joy_hole_dx, joy_hole_front_dy],
    [ joy_hole_dx, joy_hole_front_dy],
    [-joy_hole_dx, joy_hole_back_dy],
    [ joy_hole_dx, joy_hole_back_dy],
];

module joystick_mount_bosses() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, 0, 0])
    for (p = joystick_boss_xy())
        translate([p[0], p[1], -wall - joy_boss_h])
        cylinder(h = joy_boss_h + 0.5, d = joy_boss_d);
}

module joystick_mount_pilot_holes() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, 0, 0])
    for (p = joystick_boss_xy())
        translate([p[0], p[1], -wall - joy_boss_h - 0.5])
        cylinder(h = joy_boss_h + 1, d = joy_pilot_d);
}

module joystick_gimbal_clearance() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, 0, -wall/2])
    sphere(r = joy_gimbal_r);
}

module blank_side_piece() {
    difference() {
        union() {
            endcap(1);
            blank_strips();
            blank_side_mount_bosses();
            joystick_mount_bosses();
            gap_lip_front_bottom();
            gap_lip_top_back();
        }
        blank_hardware_cutouts();
        blank_side_mounts();
        blank_side_clearance_holes();
        joystick_mount_pilot_holes();
        joystick_gimbal_clearance();
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
    translate([-case_w/2, 22, 65])
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

// Countersink pocket floor (where the PCB's front face rests) is now at
// z=-wall+3 (~3mm effective depth from the interior face at -wall),
// confirmed 2026-08-19 -- was -wall+2. Shared by oled_mockup() and
// led_ring_mockup() below.
pocket_floor_z = -wall + 3;

module oled_mockup() {
    color("MidnightBlue")
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        // glass/active area, right at the panel's exterior face
        translate([-60, -13, 0.5]) cube([OLED_ACTIVE_W, OLED_ACTIVE_H, 1], center=true);
        // PCB, front face resting on the countersink pocket floor
        translate([-60, -15, pocket_floor_z - OLED_PCB_T/2]) cube([OLED_PCB_W, OLED_PCB_H, OLED_PCB_T], center=true);
        // pin header stub, further into the interior
        translate([-60, -15 - OLED_PCB_H/2 + 3, pocket_floor_z - OLED_PCB_T - OLED_HEADER_LEN/2])
            cube([10, 3, OLED_HEADER_LEN], center=true);
    }
}

module led_ring_mockup() {
    color("MediumOrchid")
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        translate([65, -15, pocket_floor_z - LED_RING_T/2]) cylinder(h = LED_RING_T, d = LED_RING_D, center = true);
        translate([65, -15, pocket_floor_z - LED_RING_T - LED_RING_HEADER_LEN/2])
            cube([6, 10, LED_RING_HEADER_LEN], center = true);
    }
}

// Illustrative only -- no matching cutout, see LED_STRIP_LEN comment above.
module led_strip_mockup() {
    color("Cyan")
    translate([-LED_STRIP_LEN/2, case_d - wall - LED_STRIP_T/2, front_h - 15])
        cube([LED_STRIP_LEN, LED_STRIP_T, LED_STRIP_W]);
}

// Resting on the real pi_mount_bosses() standoffs (5mm), added 2026-08-19.
module pi4_stack_mockup() {
    color("Orange") pi_mount_bosses();
    translate([pi_cx - PI4_W/2, pi_near_y, wall + pi_boss_h]) {
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

// Far left in play position (+X here) -- corrected 2026-08-18 from x=-65.
module rocker_mockup() {
    color("Crimson")
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        translate([70, 0, 1]) cylinder(h = 2, d = ROCKER_FLANGE_D, center = true);
        translate([70, 0, -ROCKER_BODY_H/2]) cylinder(h = ROCKER_BODY_H, d = ROCKER_BODY_D, center = true);
    }
}

// Shared by both octave (x=45) and font (x=-35) encoders -- same part,
// corrected 2026-08-18 (was swapped). Shifted -7mm along the shelf
// (enc_pos_y, matching blank_hardware_cutouts() above) as of 2026-08-19
// to clear the speaker housing.
module encoder_mockup(x, c = "Goldenrod") {
    y = enc_pos_y;
    color(c)
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        // shaft, poking outward -- knob not modeled
        translate([x, y, 0]) cylinder(h = ENC_SHAFT_H, d = 4);
        // bushing, crossing the panel
        translate([x, y, -wall]) cylinder(h = wall + 1, d = ENC_BUSHING_D);
        // body/can, fully inside the case
        translate([x - ENC_BODY_W/2, y - ENC_BODY_H/2, -wall - ENC_BODY_D])
            cube([ENC_BODY_W, ENC_BODY_H, ENC_BODY_D]);
        // 5-pin header stub
        translate([x, y, -wall - ENC_BODY_D - ENC_PIN_LEN])
            cube([8, 2, ENC_PIN_LEN], center = true);
    }
}

// Mounting bosses paused (see comment above) -- board floats at the
// illustrative joy_boss_h height with nothing drawn holding it up yet.
module joystick_mockup() {
    color("DarkSlateBlue")
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0]) {
        // board's near (top) face rests at the illustrative standoff height
        board_z = -wall - joy_boss_h;
        board_cy = (joy_hole_front_dy + joy_hole_back_dy) / 2;

        // PCB, screwed to the boss tips
        translate([joy_x - JOY_PCB_W/2, board_cy - JOY_PCB_H/2, board_z - JOY_PCB_T])
            cube([JOY_PCB_W, JOY_PCB_H, JOY_PCB_T]);

        // 4-pin header, off the board's far (more-interior) face
        translate([joy_x - 4, board_cy - 1, board_z - JOY_PCB_T - JOY_HEADER_LEN])
            cube([8, 2, JOY_HEADER_LEN]);

        // stick shaft, from the board's near face up through the shelf hole
        translate([joy_x, 0, board_z]) cylinder(h = JOY_STICK_H - board_z, d = 6);
        // ball cap, above the shelf exterior
        translate([joy_x, 0, JOY_STICK_H]) sphere(d = JOY_BALL_D);
    }
}

module note_switches_mockup() {
    color("SlateGray")
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0]) {
        for (i = [-3:3])
            translate([i * 19.05, 15, -wall - MX_SWITCH_DEPTH/2])
                cube([14, 14, MX_SWITCH_DEPTH], center = true);
    }
}

// Front wall, rotate([90,0,0]) puts local +z toward the interior here
// (opposite sign convention from the shelf/panel frames above -- this is a
// different rotation). Single housing, centered on the front wall (cx=0),
// matching blank_hardware_cutouts()'s spk_cone_offset convention.
module speaker_housing_mockup(cx = 0) {
    color("SaddleBrown")
    translate([0, case_d, front_h/2])
    rotate([90, 0, 0]) {
        translate([cx - SPK_HOUSING_W/2, -SPK_HOUSING_H/2, wall])
            cube([SPK_HOUSING_W, SPK_HOUSING_H, SPK_HOUSING_D]);
        for (dx = [-SPK_CONE_OFFSET, SPK_CONE_OFFSET])
            translate([cx + dx, 0, wall - 2])
                cylinder(h = 2, d = SPK_CONE_D);
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
    encoder_mockup(45, "Goldenrod");
    encoder_mockup(-35, "DarkGoldenrod");
    joystick_mockup();
    note_switches_mockup();
    speaker_housing_mockup();
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
else if (PART == "OCTAVE_ENCODER") encoder_mockup(45);
else if (PART == "FONT_ENCODER") encoder_mockup(-35);
else if (PART == "JOYSTICK") joystick_mockup();
else if (PART == "NOTE_SWITCHES") note_switches_mockup();
else if (PART == "SPEAKER_HOUSING") speaker_housing_mockup();
