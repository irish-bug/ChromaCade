// =============================================================================
// ChromaCade — Toddler Synth Case
// Parametric OpenSCAD model  v2
//
// Changes in v2:
//   - Shelf tilt geometry implemented as a polyhedron (flat bottom, tilted top)
//     Back edge rises SHELF_D*tan(SHELF_TILT) ≈ 6.7mm relative to front edge
//   - Panel base position updated to SHELF_BACK_TOP_Z (tilted shelf back-top)
//   - Shelf cutouts extended to clear the full tilted shelf height
//   - Bottom access bay added for battery / SD-card service
//   - battery_bay_cover() module added as a separate printable part
//   - battery_bay_tab_divots() cut matching capture recesses into bay lip
//
// Based on:  case-design.md, control-layout.md, hardware-bom.md,
//            design-philosophy.md
// Workflow:  OpenSCAD (parametric structure) → Tinkercad (aesthetic tweaks)
// Printer:   8"×8"×8" bed — all dims intentionally well within that limit
// Units:     millimetres throughout (1" ≈ 25.4 mm)
// =============================================================================

$fn = 64;   // drop to 16 for fast preview, raise to 128 before final STL export

// =============================================================================
// GLOBAL PARAMETERS  (change here — whole model follows)
// =============================================================================

W           = 177.8;   // overall width  ≈ 7"
DEPTH       = 165.1;   // overall depth  ≈ 6.5"
T           = 4.0;     // wall thickness — chunky over compact (3–4 mm+)

FRONT_H     = 76.2;    // front wall height ≈ 3"
FOOT_EXT    = 20.0;    // stability foot extension forward of front wall

SHELF_D     = 50.8;    // shelf depth ≈ 2"
SHELF_TILT  = 7.5;     // shelf forward tilt (degrees) — back rises, front stays level

PANEL_ANGLE = 45.0;    // main panel angle from vertical
PANEL_LEN   = 63.5;    // panel face length along slope ≈ 2.5"
PANEL_RISE  = PANEL_LEN * sin(PANEL_ANGLE);
PANEL_RUN   = PANEL_LEN * cos(PANEL_ANGLE);

BASE_H      = T;       // base slab thickness = one wall thickness
X           = 0.5;     // Boolean extra margin (keeps difference() clean)

// =============================================================================
// COMPONENT DIMENSIONS
// =============================================================================

MX_PITCH        = 19.05;          // standard MX switch pitch
MX_HOLE         = 14.0;           // standard MX plate cutout (square)
MX_COUNT        = 7;              // note buttons A–G
MX_SPAN         = (MX_COUNT - 1) * MX_PITCH;

OLED_W          = 27.0;           // OLED PCB width (for LED-ring offset calculation)
OLED_CUTOUT_W   = 26.0;           // viewable window width
OLED_CUTOUT_H   = 14.0;           // viewable window height

LED_RING_OD     = 37.0;           // WS2812 7-LED ring outer diameter

ENC_BUSHING_D   = 7.0;            // EC11 encoder shaft/bushing hole
ROCKER_D        = 12.0;           // XINYIELE round rocker switch hole
JOY_HOLE_D      = 30.0;           // KY-023 thumb-cap passthrough

POT_HOLE_D      = 7.0;            // Fender 500K pot shaft hole
PWR_SW_W        = 12.0;           // power switch body width
PWR_SW_H        = 8.0;            // power switch body height

SPK_GRILLE_W    = 50.0;
SPK_GRILLE_H    = 50.0;
HEX_HOLE_D      = 5.0;            // < 6mm — toddler fingers cannot poke through
HEX_SPACING     = 7.5;            // hex-hole centre-to-centre

USBC_W          = 9.5;
USBC_H          = 3.5;

// Pi Zero 2W mounting hole pattern (58mm × 23mm)
PI_HOLE_D       = 2.7;            // M2.5 clearance
PI_STANDOFF_H   = 5.0;
PI_STANDOFF_OD  = 6.0;
PI_HOLE_OFFSETS = [[0,0],[58,0],[0,23],[58,23]];

// Perfboard standoffs
PERF_W          = 100.0;
PERF_D          = 80.0;
PERF_HOLE_D     = 2.7;
PERF_STANDOFF_H = 5.0;
PERF_STANDOFF_OD= 6.0;

// Battery bay access panel (bottom of case)
BAY_W        = 80.0;   // bay opening width — fits LiPo (≈55×35mm) + wiring
BAY_D        = 55.0;   // bay opening depth
BAY_LIP      = 3.0;    // cover plate overlap beyond the opening (each side)
BAY_POCKET_H = 1.5;    // depth of bottom recess the cover plate sits in
BAY_CLR      = 0.2;    // clearance between cover and pocket (each side)
NOTCH_W      = 14.0;   // pry-notch width on cover edge
NOTCH_D      = 2.5;    // pry-notch depth

// =============================================================================
// DERIVED POSITIONS  (recomputed whenever a parameter changes)
// =============================================================================

Y_FRONT_WALL    = FOOT_EXT;
Y_SHELF_FRONT   = Y_FRONT_WALL + T;
Y_SHELF_BACK    = Y_SHELF_FRONT + SHELF_D;
Y_BACK_WALL     = Y_SHELF_BACK + PANEL_RUN;

Z_BASE_TOP      = BASE_H;
Z_FRONT_WALL_TOP= Z_BASE_TOP + FRONT_H;
Z_SHELF_SURFACE = Z_FRONT_WALL_TOP;   // shelf bottom face = top of front wall

// ── v2: shelf tilt derived values ────────────────────────────────────────────
// The back edge of the shelf top face rises by SHELF_TILT_DZ relative to front.
SHELF_TILT_DZ   = SHELF_D * tan(SHELF_TILT);       // ≈ 6.7mm at 7.5°
SHELF_BACK_TOP_Z= Z_SHELF_SURFACE + T + SHELF_TILT_DZ;  // Z where panel base sits

// Back-wall height (now accounts for shelf-tilt contribution)
BACK_H          = FRONT_H + SHELF_TILT_DZ + PANEL_RISE;

// Pi board: near back wall inner face, centred in X
PI_X0           = (W - 58) / 2;
PI_Y0           = Y_BACK_WALL - 15;

// Perfboard: in shallow front cavity
PERF_X0         = (W - PERF_W) / 2;
PERF_Y0         = Y_SHELF_FRONT + 5;

// Battery bay: centred in X, under the rear interior cavity
BAY_X0          = (W - BAY_W) / 2;
BAY_Y0          = Y_SHELF_BACK + 15;   // 15mm clear of shelf/panel junction

// =============================================================================
// HELPER MODULES
// =============================================================================

module hex_hole(d, dp) {
    cylinder(h = dp, d = d / cos(30), $fn = 6);
}

module hex_grille(gw, gh, hole_d, spacing, depth) {
    rows     = floor(gh / spacing) + 2;
    cols     = floor(gw / (spacing * cos(30))) + 2;
    col_step = spacing * cos(30);
    translate([-gw/2, -gh/2, 0])
    for (r = [0 : rows]) {
        for (c = [0 : cols]) {
            cx = c * col_step;
            cy = r * spacing + (c % 2 == 0 ? 0 : spacing / 2);
            if (cx >= 0 && cx <= gw && cy >= 0 && cy <= gh)
                translate([cx, cy, 0])
                    hex_hole(hole_d, depth + 2*X);
        }
    }
}

module standoff(h, od, hole_d) {
    difference() {
        cylinder(h = h, d = od);
        cylinder(h = h + X, d = hole_d);
    }
}

// =============================================================================
// TILTED SHELF (v2)
//
// Polyhedron with a flat bottom face (at Z_SHELF_SURFACE) and a tilted top
// face.  Front-top stays at Z_SHELF_SURFACE + T; back-top rises by
// SHELF_TILT_DZ to Z_SHELF_SURFACE + T + SHELF_TILT_DZ = SHELF_BACK_TOP_Z.
//
// Face winding follows OpenSCAD convention: vertices listed CCW when viewed
// from the outward-facing side of each face.
// If the shelf shows inverted in F5 preview, flip the face lists — CSG
// booleans (F6) are unaffected by face orientation.
// =============================================================================

module tilted_shelf() {
    iw = W - 2*T;           // inner width between side walls
    dz = SHELF_TILT_DZ;     // back-top rise

    translate([T, Y_SHELF_FRONT, Z_SHELF_SURFACE])
    polyhedron(
        points = [
            // Bottom face — flat (local Z = 0)
            [0,   0,       0],   // 0  front-left  bottom
            [iw,  0,       0],   // 1  front-right bottom
            [iw,  SHELF_D, 0],   // 2  back-right  bottom
            [0,   SHELF_D, 0],   // 3  back-left   bottom
            // Top face — tilted (back is higher)
            [0,   0,       T],       // 4  front-left  top
            [iw,  0,       T],       // 5  front-right top
            [iw,  SHELF_D, T+dz],    // 6  back-right  top
            [0,   SHELF_D, T+dz]     // 7  back-left   top
        ],
        faces = [
            [0, 1, 2, 3],   // bottom  (outward = -Z)
            [7, 6, 5, 4],   // top     (outward ≈ +Z, tilted)
            [0, 4, 5, 1],   // front   (outward = -Y)
            [1, 5, 6, 2],   // right   (outward = +X)
            [2, 6, 7, 3],   // back    (outward = +Y)
            [3, 7, 4, 0]    // left    (outward = -X)
        ]
    );
}

// =============================================================================
// BATTERY BAY CUTOUTS (applied in top-level difference)
//
// Two-step cutout strategy:
//   1. Shallow pocket in the base's outer (bottom) face — the cover plate
//      sits in this pocket, flush with the underside of the case.
//   2. Full through-hole — gives access to the interior for battery / SD card.
// =============================================================================

module battery_bay_cutout() {
    // Pocket recess in base bottom: cover plate sits here
    translate([BAY_X0 - BAY_LIP, BAY_Y0 - BAY_LIP, -X])
        cube([BAY_W + 2*BAY_LIP, BAY_D + 2*BAY_LIP, BAY_POCKET_H + X]);

    // Through-hole: full base thickness
    translate([BAY_X0, BAY_Y0, -X])
        cube([BAY_W, BAY_D, BASE_H + 2*X]);
}

// Small capture divots in the pocket rim for the cover's retention nubs
// (cut in the same difference() pass as the bay)
module battery_bay_divots() {
    divot_d = 3.0;    // divot diameter
    divot_h = 1.2;    // divot depth into rim
    z_divot = BAY_POCKET_H / 2;  // centred in pocket depth

    // Two divots per long side (front and back rim of the pocket)
    for (side = [0, 1]) {
        dy = (side == 0) ? BAY_Y0 - BAY_LIP       // front rim outer edge
                         : BAY_Y0 + BAY_D + BAY_LIP - divot_h; // back rim outer edge
        for (dx = [BAY_X0 + BAY_W*0.25, BAY_X0 + BAY_W*0.75]) {
            translate([dx - divot_d/2, dy, -X + z_divot])
                cube([divot_d, divot_h + X, divot_d]);
        }
    }
}

// =============================================================================
// CASE SHELL
// =============================================================================

module case_shell() {
    union() {

        // ── Base slab — continuous, full depth ────────────────────────────────
        cube([W, DEPTH, BASE_H]);

        // ── Front wall ────────────────────────────────────────────────────────
        translate([0, Y_FRONT_WALL, BASE_H])
            cube([W, T, FRONT_H]);

        // ── Left side wall ────────────────────────────────────────────────────
        translate([0, Y_FRONT_WALL, BASE_H])
            cube([T, DEPTH - Y_FRONT_WALL, BACK_H]);

        // ── Right side wall ───────────────────────────────────────────────────
        translate([W - T, Y_FRONT_WALL, BASE_H])
            cube([T, DEPTH - Y_FRONT_WALL, BACK_H]);

        // ── Shelf — tilted parallelogram (v2) ────────────────────────────────
        tilted_shelf();

        // ── Main panel — 45° angled face ──────────────────────────────────────
        // Base now at SHELF_BACK_TOP_Z (elevated by the shelf tilt).
        translate([T, Y_SHELF_BACK, SHELF_BACK_TOP_Z])
            rotate([45, 0, 0])
                cube([W - 2*T, T, PANEL_LEN]);

        // ── Back wall ─────────────────────────────────────────────────────────
        translate([0, DEPTH - T, BASE_H])
            cube([W, T, BACK_H]);
    }
}

// =============================================================================
// CONTROL CUTOUTS
// =============================================================================

// ── Panel: 7 MX switches, OLED window, LED ring ───────────────────────────────
// Cutouts placed in panel-local coordinates (rotated 45°, origin at panel base).
// v2: panel origin Z = SHELF_BACK_TOP_Z (tilted shelf back-top).
module panel_cutouts() {
    inner_w = W - 2*T;

    translate([T, Y_SHELF_BACK, SHELF_BACK_TOP_Z])
    rotate([45, 0, 0]) {

        // 7 MX switch holes, horizontally centred on panel face
        mx_start_x = (inner_w - MX_SPAN) / 2;
        for (i = [0 : MX_COUNT - 1]) {
            translate([mx_start_x + i * MX_PITCH,
                       PANEL_LEN / 2 - MX_HOLE / 2,
                       -X])
                cube([MX_HOLE, MX_HOLE, T + 2*X]);
        }

        // OLED display window (positions are working estimates — confirm footprint)
        oled_x = inner_w / 2 + MX_SPAN / 2 + 10;
        oled_y = PANEL_LEN * 0.62;
        translate([oled_x - OLED_CUTOUT_W / 2, oled_y, -X])
            cube([OLED_CUTOUT_W, OLED_CUTOUT_H, T + 2*X]);

        // LED ring passthrough
        led_x = oled_x + OLED_W / 2 + LED_RING_OD / 2 + 5;
        led_y = oled_y + OLED_CUTOUT_H / 2;
        translate([led_x, led_y, -X])
            cylinder(h = T + 2*X, d = LED_RING_OD);
    }
}

// ── Shelf: encoder holes, rocker, joystick ────────────────────────────────────
// v2: cutouts start below the shelf bottom face and extend past the highest
// point of the tilted top face, so all holes clear regardless of Y position.
module shelf_cutouts() {
    cut_z_bot = Z_SHELF_SURFACE - X;               // below shelf bottom
    cut_h     = T + SHELF_TILT_DZ + 2*X;           // through full tilted height

    shelf_y_mid = Y_SHELF_FRONT + SHELF_D / 2;

    // Left cluster: octave encoder (front-half), rocker switch (back-half)
    left_x = T + 20;
    translate([left_x, shelf_y_mid - 12, cut_z_bot])
        cylinder(h = cut_h, d = ENC_BUSHING_D);
    translate([left_x, shelf_y_mid + 12, cut_z_bot])
        cylinder(h = cut_h, d = ROCKER_D);

    // Right cluster: font encoder (front-half), joystick (back-half)
    right_x = W - T - 20;
    translate([right_x, shelf_y_mid - 12, cut_z_bot])
        cylinder(h = cut_h, d = ENC_BUSHING_D);
    translate([right_x, shelf_y_mid + 12, cut_z_bot])
        cylinder(h = cut_h, d = JOY_HOLE_D);
}

// ── Front wall: two speaker grilles (hex pattern) ─────────────────────────────
module front_wall_cutouts() {
    grille_z_centre = BASE_H + FRONT_H / 2;
    for (side = [0, 1]) {
        gx = (side == 0) ? W / 4 : 3 * W / 4;
        translate([gx, Y_FRONT_WALL - X, grille_z_centre])
            rotate([-90, 0, 0])
                hex_grille(SPK_GRILLE_W, SPK_GRILLE_H,
                           HEX_HOLE_D, HEX_SPACING, T + 2*X);
    }
}

// ── Side panel: volume pot + power switch (deliberate-friction placement) ──────
module side_panel_cutouts() {
    side_y     = Y_SHELF_BACK + PANEL_RUN / 2;
    side_z_pot = BASE_H + BACK_H * 0.72;
    side_z_sw  = side_z_pot - 28;

    translate([-X, side_y, side_z_pot])
        rotate([0, 90, 0])
            cylinder(h = T + 2*X, d = POT_HOLE_D);

    translate([-X, side_y - PWR_SW_W/2, side_z_sw - PWR_SW_H/2])
        cube([T + 2*X, PWR_SW_W, PWR_SW_H]);
}

// ── Back wall: USB-C port (low, out of reach during play) ─────────────────────
module back_wall_cutouts() {
    translate([W/2 - USBC_W/2, DEPTH - T - X, BASE_H + 10])
        cube([USBC_W, T + 2*X, USBC_H]);
}

// =============================================================================
// INTERIOR STANDOFFS
// =============================================================================

module interior_standoffs() {

    // Pi Zero 2W — near back wall, centred in X
    for (pt = PI_HOLE_OFFSETS) {
        translate([PI_X0 + pt[0], PI_Y0 + pt[1], BASE_H])
            standoff(PI_STANDOFF_H, PI_STANDOFF_OD, PI_HOLE_D);
    }

    // Perfboard — front portion of interior cavity
    for (px = [0, PERF_W]) {
        for (py = [0, PERF_D]) {
            translate([PERF_X0 + px, PERF_Y0 + py, BASE_H])
                standoff(PERF_STANDOFF_H, PERF_STANDOFF_OD, PERF_HOLE_D);
        }
    }
}

// =============================================================================
// BATTERY BAY COVER  (separate printable part)
//
// Print flat (cover face down, Z = cover thickness).  No supports required.
// The cover plate drops into the base pocket from outside (below the case),
// sitting flush with the underside once pressed in.
//
// Retention nubs (2mm tall, 3mm wide) on the front and back edges clip into
// matching divots in the pocket rim.  Press nubs inward with fingernails to
// release; a coin in the pry notch on the back edge also works.
//
// To print separately: comment out chromacade_case(), uncomment the
// battery_bay_cover() call at the bottom of this file.
// =============================================================================

// Derived cover dimensions
BAY_COVER_W = BAY_W + 2*BAY_LIP - 2*BAY_CLR;    // fits pocket with clearance
BAY_COVER_D = BAY_D + 2*BAY_LIP - 2*BAY_CLR;
BAY_COVER_H = BAY_POCKET_H - 0.1;                // slightly under pocket depth

NUB_W       = 3.0;   // retention nub width  (matches divot width)
NUB_H       = 1.0;   // retention nub height (how far it sticks out from edge)
NUB_T       = 2.5;   // retention nub thickness (in Z, perpendicular to cover face)
NUB_OFFSET  = BAY_COVER_W * 0.25;   // nub X position from each end (25% / 75%)

module battery_bay_cover() {
    difference() {
        union() {
            // Main cover plate
            cube([BAY_COVER_W, BAY_COVER_D, BAY_COVER_H]);

            // Retention nubs on front edge (Y=0): two nubs
            for (nx = [NUB_OFFSET, BAY_COVER_W - NUB_OFFSET]) {
                translate([nx - NUB_W/2, -NUB_H, BAY_COVER_H/2 - NUB_T/2])
                    cube([NUB_W, NUB_H, NUB_T]);
            }

            // Retention nubs on back edge (Y=BAY_COVER_D): two nubs
            for (nx = [NUB_OFFSET, BAY_COVER_W - NUB_OFFSET]) {
                translate([nx - NUB_W/2, BAY_COVER_D, BAY_COVER_H/2 - NUB_T/2])
                    cube([NUB_W, NUB_H, NUB_T]);
            }
        }

        // Pry notch on back edge (use a coin or fingernail here to pop cover out)
        translate([BAY_COVER_W/2 - NOTCH_W/2, BAY_COVER_D - NOTCH_D, -X])
            cube([NOTCH_W, NOTCH_D + X, BAY_COVER_H + 2*X]);
    }
}

// =============================================================================
// TOP-LEVEL ASSEMBLY
// =============================================================================

module chromacade_case() {
    difference() {
        union() {
            case_shell();
            interior_standoffs();
        }
        // Surface cutouts
        panel_cutouts();
        shelf_cutouts();
        front_wall_cutouts();
        side_panel_cutouts();
        back_wall_cutouts();
        // Bottom access bay + cover capture divots
        battery_bay_cutout();
        battery_bay_divots();
    }
}

// =============================================================================
// RENDER
// To export the cover separately: comment out chromacade_case(), uncomment
// the battery_bay_cover() line (translate positions it clear of the case).
// =============================================================================

chromacade_case();

// translate([BAY_X0, BAY_Y0, -(BAY_COVER_H + 5)])
//     battery_bay_cover();

// =============================================================================
// REFINEMENT NOTES
// =============================================================================
// 1.  POLYHEDRON NORMALS: if the shelf looks transparent in F5 preview, the
//     face winding is inverted for your OpenSCAD version — flip the face lists
//     in tilted_shelf() (e.g. [0,1,2,3] → [3,2,1,0]).  F6 CSG render and STL
//     export are not affected by face orientation.
//
// 2.  PANEL SEAM: the panel's bottom edge meets the tilted shelf's back-top at
//     SHELF_BACK_TOP_Z.  In F5, inspect this junction; add a fillet in Tinkercad
//     if you want a smooth transition rather than a sharp crease.
//
// 3.  OLED / LED POSITIONS: oled_x, oled_y, led_x, led_y inside panel_cutouts()
//     are working estimates.  Measure the real PCB + bezel footprints and adjust
//     before slicing.
//
// 4.  BAY COVER FIT: BAY_CLR = 0.2mm each side is a starting point for a snug
//     friction fit.  If the cover binds, increase BAY_CLR.  If it rattles,
//     decrease it.  Print a test cover before committing to the full case print.
//
// 5.  NUB HEIGHT: NUB_H = 1.0mm.  If nubs don't click into divots, increase
//     NUB_H slightly (0.1mm steps).  If the cover is hard to remove, decrease.
//
// 6.  LIPO CLEARANCE: 3.7V 3000mAh cell ≈ 55×35×8mm.  Bay opening is 80×55mm
//     with full interior height above it — LiPo fits with room for harness.
//
// 7.  PI STANDOFF Y: PI_Y0 = Y_BACK_WALL - 15.  Confirm this clears the panel's
//     inner face in F5 before printing.  Increase the 15mm offset if needed.
//
// 8.  WALL THICKNESS: T=4mm minimum.  Consider T=5mm for unit #1 test print;
//     it's a toy, and extra rigidity is free.
//
// 9.  STL EXPORT: F6 full render, then File → Export as STL.  Set $fn=128 first.
// =============================================================================
