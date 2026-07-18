// ChromaCade — Component Fit Test Plates
// Print all 6 before committing to the full case print.
// Arrange flat on bed; no supports needed.
// Total footprint: ~126mm × 82mm — fits any standard bed.
//
// Plate  Component               Hole
// ─────────────────────────────────────────────────────
//   A    Outemu MX switch        14.3 × 14.3mm square
//   B    KY-023 joystick         ø30mm circle
//   C    XINYIELE 3-way rocker   ø20.32mm circle
//   D    EC11 rotary encoder     ø7mm circle
//   E    USB-C port              10 × 4mm rectangle
//   F    Fender 500K pot         ø8mm circle
//   G    WS2812 7-LED ring       ø24mm circle
//   H    0.96" OLED display      28 × 15mm rectangle
//
// NOTE — plate A (MX) uses a 1.5mm engagement layer + 4mm frame.
// This is intentional — MX switch clips require exactly ~1.5mm plate
// thickness to snap and hold. Do NOT increase this to match wall thickness.
// Per three-key-test-mount.scad: shrink cutout toward 14.0mm if switches
// sit loose; grow toward 14.5mm if clips won't seat on your specific printer.

$fn = 60;

// --- Shared dimensions ---
wall       = 5;      // plate thickness for all non-MX plates (matches case wall)
plate_w    = 40;     // square plate footprint
plate_gap  = 6;      // gap between plates on the bed
row_pitch  = plate_w + plate_gap;   // 46mm centre-to-centre

// --- MX plate specifics (per proven test-mount geometry) ---
mx_eng_h   = 1.5;   // engagement layer  — do NOT change without re-testing clips
mx_frame_h = 4.0;   // chunky frame below — fine to increase for extra rigidity

// --- Label extrude height (raised text on top surface, slicer should support this) ---
lbl_h = 0.5;

// =============================================================================
// HELPER MODULES
// =============================================================================

// Round hole test plate
module test_round(label, hole_d, thick=wall) {
    difference() {
        union() {
            linear_extrude(thick)
                square([plate_w, plate_w], center=true);
            // Raised label
            translate([0, plate_w/2 - 7, thick])
            linear_extrude(lbl_h)
                text(label, size=5, halign="center", valign="center");
        }
        translate([0, 0, -1])
            cylinder(h=thick+2, d=hole_d);
    }
}

// Rectangular hole test plate
module test_rect(label, hole_w, hole_h, thick=wall) {
    difference() {
        union() {
            linear_extrude(thick)
                square([plate_w, plate_w], center=true);
            translate([0, plate_w/2 - 7, thick])
            linear_extrude(lbl_h)
                text(label, size=5, halign="center", valign="center");
        }
        translate([-hole_w/2, -hole_h/2, -1])
            cube([hole_w, hole_h, thick+2]);
    }
}

// MX switch test plate (special geometry — matches three-key-test-mount.scad)
module test_mx() {
    frame_inner = plate_w - wall*2;
    total_h     = mx_frame_h + mx_eng_h;

    difference() {
        union() {
            // Hollow perimeter frame (rigidity without blocking clip area)
            linear_extrude(mx_frame_h)
            difference() {
                square([plate_w, plate_w], center=true);
                square([frame_inner, frame_inner], center=true);
            }

            // Solid engagement layer on top — clips snap into this
            translate([0, 0, mx_frame_h])
            linear_extrude(mx_eng_h)
                square([plate_w, plate_w], center=true);

            // Raised label
            translate([0, plate_w/2 - 7, total_h])
            linear_extrude(lbl_h)
                text("MX", size=5, halign="center", valign="center");
        }

        // Switch cutout punched through the full stack
        translate([0, 0, -1])
        linear_extrude(total_h + 2)
            square([14.3, 14.3], center=true);
    }
}

// =============================================================================
// LAYOUT  —  3 rows × 3 columns, all flat on Z=0
// =============================================================================
//
//   [A: MX sw]   [B: Joystick]   [C: Rocker]
//   [D: Encoder] [E: USB-C]      [F: Pot]
//   [G: LED Rng] [H: OLED]

// Row 0
translate([0 * row_pitch,  0,  0]) test_mx();
translate([1 * row_pitch,  0,  0]) test_round("JOY",  30);    // B: KY-023 joystick
translate([2 * row_pitch,  0,  0]) test_round("RCKR", 20.32); // C: XINYIELE rocker (0.8" = 20.32mm)

// Row 1
translate([0 * row_pitch,  row_pitch,  0]) test_round("ENC",  7);   // D: EC11 encoder
translate([1 * row_pitch,  row_pitch,  0]) test_rect("USBC", 10, 4); // E: USB-C
translate([2 * row_pitch,  row_pitch,  0]) test_round("POT",  8);   // F: Fender 500K

// Row 2
translate([0 * row_pitch,  2 * row_pitch,  0]) test_round("LED",  24);    // G: WS2812 7-LED ring
translate([1 * row_pitch,  2 * row_pitch,  0]) test_rect("OLED", 28, 15); // H: 0.96" OLED display

// =============================================================================
// WHAT TO CHECK ON EACH PRINTED PLATE
// =============================================================================
// A (MX)    — Switch clips in without wobble. Firm hold, no rocking.
//             If too loose: reduce 14.3 → 14.1mm and reprint.
//             If clips won't fully seat: increase 14.3 → 14.5mm.
//
// B (JOY)   — KY-023 thumb cap passes fully through from behind.
//             Full range of joystick motion with no rubbing on the panel edge.
//             If tight: increase 30 → 31mm.
//
// C (RCKR)  — XINYIELE body drops through cleanly, retaining flange catches.
//             If too tight: increase 20.32 → 20.5mm.
//
// D (ENC)   — EC11 bushing passes through, nut tightens flush on panel face.
//             If bushing threads won't start: increase 7 → 7.2mm.
//
// E (USBC)  — USB-C plug inserts without forcing. Connector sits flush.
//             If tight: increase 10 → 10.5mm and/or 4 → 4.5mm independently.
//
// F (POT)   — Fender 500K bushing and shaft pass through. Nut tightens flush.
//             Same check as encoder; increase 8 → 8.5mm if bushing binds.
//
// G (LED)   — Ring fits within cutout, halo visible.
//             If you want the full ring face exposed, increase 24 → 38mm.
//             If too tight: increase 24 → 24.5mm.
//
// H (OLED)  — Viewable area is completely unobstructed.
//             If screen is blocked: increase 28 → 29mm or 15 → 16mm.
// =============================================================================
