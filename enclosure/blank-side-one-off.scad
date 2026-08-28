// blank-side-one-off -- blank endcap + front wall + shelf + panel + top,
// widened 4mm to mate with the ALREADY-PRINTED, out-of-spec pot-side.
//
// ONE-OFF, 2026-08-27. This is NOT the shippable geometry -- that is
// blank-side-final.scad, and the two are identical except for
// oneoff_growth below. This exists so the pot-side piece printed from
// chromacade-pot-side-thinner.scad (the one with wall=3) is not scrap: it
// is 2mm over-wide at its exterior AND its back+bottom strips run 2mm too
// far toward +X, so the correct blank-side interferes with it by 1.85mm and
// will not close. Pairing this piece with that print gives a second working
// box out of the four prints instead of three prints and a bin.
//
// PRINT PAIRING -- keep these straight, the halves are not interchangeable:
//   box 1: pot-side-final.scad  + blank-side-final.scad   (correct, 191.58mm)
//   box 2: the existing bad pot print + blank-side-one-off.scad (195.58mm)
// Mixing them across boxes reintroduces exactly the interference this
// solves. Label both physical pieces of box 2 before they leave the bed.
//
// FINAL, 2026-08-27. Supersedes chromacade-blank-side.scad,
// -embossed.scad and -thinner.scad (all retired). Prints as the mate to
// pot-side-final.scad. Carries the refined joystick mounting: two ramped
// ribs under the board instead of four cantilevered posts (see
// joystick_rib() below) -- support-free, ~8h instead of ~12h. Adds the
// seam-gap assertions below.
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

// The whole one-off change: +4mm of case width, +2mm at EACH end, applied
// through case_w so every X-referenced feature moves with it and nothing
// centered has to be touched.
//
// Why 2mm per end, derived from the bad print's own (broken) constants
// rather than from a caliper:
//   - Its endcap got NO relief (wall-wall_thin = 0 at wall=3), so its
//     exterior face is at -97.79 and its interior face at -97.79+3 =
//     -94.79, 2mm further out than the correct -92.79.
//   - Its edge_x = 97.79-3-0.15 = +94.64, so its back+bottom strips reach
//     2mm further toward +X than the correct +92.64.
// This piece therefore needs its mating edge at -94.64 (not -92.64) and its
// own endcap interior face at +94.79 (not +92.79) -- +2mm on both ends,
// which is what case_w+4 produces automatically:
//     edge_x            = -99.79 + 5 + 0.15 = -94.64   (gap 0.15 to -94.79)
//     endcap interior   =  99.79 - 5        =  94.79   (gap 0.15 to +94.64)
//     exterior, relieved=  99.79 - 2        =  97.79
//
// WHAT DOES NOT MOVE, and this is the point: every cutout is positioned on
// an absolute X centered on 0 -- the seven note keys (i*19.05), both
// speaker grilles (+/-spk_cx), the OLED, the LED, both encoders, the
// rocker, the joystick and its ribs (joy_x). Growing case_w symmetrically
// leaves all of them exactly where the validated prints have them; the 4mm
// lands entirely in the two 2mm slivers of wall added at the ends. spk_cx
// is deliberately NOT re-derived (it is anchored to a boss X that moves
// 2mm outward here) -- leaving it puts the grille 2mm further from that
// boss, which only adds clearance, and keeps the speakers centered as
// asked.
//
// The interior gains 4mm of width. Nothing is fitted to interior width
// (the Pi stack is on pot-side's floor, centered; the shelf hardware is
// centered), so this is free space, not a fit change.
oneoff_growth = 4;
case_w = 7.7   * in2mm + oneoff_growth; // 7in + 10%, +4mm for the bad pot mate
case_d = 4.95  * in2mm; // 4.5in + 10%
wall   = 5;

// EXPERIMENTAL variant (2026-08-24), this file only -- see
// pot-side-final.scad's matching comment for the full
// rationale. Applied to this piece's own endcap ONLY, not strips() (which
// is front+shelf+panel+top here, not back+bottom) -- those stay at the
// full wall thickness deliberately: the MX switch engagement trench
// (hardware_cutouts(), "leaves exactly 1.5mm front wall for clips") is
// cut as a hardcoded 3.5mm depth, not wall-relative, so thinning the
// panel/front wall would silently ruin that clip fit. Only this piece's
// +X endcap gets thinner here, matching pot-side-thinner.scad's own -X
// endcap treatment. Unlike pot-side, no mount boss is anchored to this
// piece's own endcap (blank_side_mount_bosses() all sit at edge_x, this
// piece's OTHER end, near pot-side) -- confirmed no boss-disconnection
// issue the way pot-side-thinner.scad hit, matching that its render
// stayed at Volumes:2 with no anchor changes needed here.
wall_thin = 3;

front_h = 1.925 * in2mm; // 1.75in + 10%
shelf_d = 60; // 2026-08-22: increased from 1.875in+25% (47.625mm) to fit
               // the joystick with a reserved 20mm front clearance zone
               // plus the 27mm stick hole centered in the remaining 40mm
               // (see joy_reserved_front/joy_y_offset below). Shifts
               // case_h (derived from this via the p0-p5 chain) from
               // 104.915 to 106.637 -- must stay in sync across every
               // file that redeclares this constant.
shelf_a = 8;
panel_l = 2.75  * in2mm; // 2.5in + 10%
panel_a = 45;

// REVERTED 2026-08-22 back to the original two-single-driver-speaker
// design -- the 2026-08-19 dual-cone housing (98x43x20mm, one housing,
// two 35mm cones at spk_cone_offset=22.5) didn't fit in the printed
// enclosure; going back to the speaker that was already the plan before
// that detour (see hardware/speaker specs -- 70x31mm plate, oval driver,
// 17mm deep, MEASURED against the real part).
//
// Grille length + position CORRECTED 2026-08-24 -- caliper-measured
// against the real speaker: the cone basket is NOT centered in the
// 70mm plate. It runs from 12mm (wire-lead end) to 52mm (18mm short of
// the far end), a real 40mm span, not the 38.1mm (1.5") round-number
// guess this used before. The wire-lead end mounts facing outward
// (toward each speaker's nearest case endcap/mount-boss cluster,
// confirmed live) -- so each grille's OUTER edge (the one nearer its
// boss) is anchored 12mm in from that boss's taper, not centered on a
// symmetric spk_cx like before.
//
// Right speaker's boss reference: chromacade-pot-side.scad's own
// edge_x (92.64) minus boss_body+boss_ramp (14+10=24) = 68.64, the X
// where that boss's 45-taper actually meets the front wall's interior
// face (mirrors this file's own left-side front_bottom/front_top boss
// at -68.64 -- see own_mount_boss_centers). Outer edge = 68.64-12 =
// 56.64; inner edge = 56.64-40 = 16.64; center = 36.64. Mirrored for
// the left speaker. Spacing is no longer a clean 90mm (was spk_cx=45,
// symmetric) -- it's asymmetric per speaker now, hence spk_cx moving
// from a spacing constant to each grille's own center.
//
// NOT yet physically test-printed against the real part at this new
// position/size -- verify with a test-mk2.scad-style coupon before
// trusting this over a full case print, same as every other hole
// dimension in this project.
spk_grille_w = 1.0 * in2mm;  // 25.4mm = 1" -- unchanged, no measurement given for this axis
spk_grille_h = 40;           // was 1.5in2mm (38.1mm) guess; now the real 70-12-18 cone-basket length
spk_cx       = 36.64;        // was 45 (symmetric); see derivation above

// Full mounting-plate footprint, for depth-clearance checking only (not
// what gets cut) -- MEASURED, hardware/speaker specs. Speaker's own long
// axis (70mm) runs along the case's width (X) once rotated 90° to sit
// landscape, matching the grille's own rotation; short axis (31mm) runs
// vertically (Z); 17mm reaches back into the case (Y) from the front
// wall's interior face.
spk_plate_w = 70;
spk_plate_h = 31;
spk_plate_depth = 17;

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
// This piece (blank-side) owns 4 mounts (was 5 until 2026-08-19 -- the
// shelf/panel joint mount was removed, see own_mount_boss_centers below) —
// near the front wall's bottom and top, the panel/top joint, and the
// top/back joint — each a pilot bore into this piece's own material,
// starting right at this piece's edge nearest pot-side. Pot-side owns 4
// more (2 bottom, 2 back); this piece just gets clearance holes through
// its endcap for those.
//
// Sized for M3 screws: 2.5mm self-tapping pilot, 3.4mm clearance — see
// chromacade-pot-side.scad's matching comment for the boss rationale (bare
// wall material alone only gives ~1mm on each side of the bore, thin
// enough to risk cracking at these edge-adjacent points, which need to
// survive a toddler pushing the case off a table onto a hard floor).
pilot_d   = 2.5;
clear_d   = 3.4;
engage    = 15;
// Shrunk 12/14 -> 10/10, EXPERIMENTAL-file change 2026-08-24 (direct
// instruction, matching pot-side-final.scad's same change).
// boss_ramp unchanged at 10. Doesn't affect front_bottom, which already
// has its own w=8/body=8/ramp=0 override, unrelated to this constant.
boss_w    = 10;
boss_body = 10;
boss_ramp = 10;

edge_x = -case_w/2 + wall + edge_clearance; // this piece's edge nearest pot-side

// Square boss (true boss_w x boss_w cross-section throughout -- "the same
// square cylinder" for all 4 mounts, per direct instruction 2026-08-19) --
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
// w/body/ramp default to the shared boss_w/boss_body/boss_ramp constants
// so every existing call is unaffected -- added 2026-08-24 so front_bottom
// specifically could shrink to a smaller cube (see blank_side_mount_bosses()
// below) without touching the other 3 mounts, which stay at the standard
// size. ramp=0 skips the taper entirely (plain cube, no hull()) rather than
// emitting a degenerate zero-length hull -- used for front_bottom, which no
// longer needs a support-free taper since this piece already generates
// support trees nearby for the joystick's mounting legs (2026-08-24).
module flat_mount_boss(pos, thick_axis, wall_z=-wall, wall_y=-wall, w=boss_w, body=boss_body, ramp=boss_ramp) {
    if (thick_axis == "z") {
        translate([edge_x, pos - w/2, wall_z - w])
        cube([body, w, w]);

        if (ramp > 0)
        hull() {
            translate([edge_x + body - 0.01, pos - w/2, wall_z - w])
            cube([0.01, w, w]);

            translate([edge_x + body + ramp - 0.01, pos - w/2, wall_z - 0.01])
            cube([0.01, w, 0.01]);
        }
    } else {
        translate([edge_x, wall_y - w, pos - w/2])
        cube([body, w, w]);

        if (ramp > 0)
        hull() {
            translate([edge_x + body - 0.01, wall_y - w, pos - w/2])
            cube([0.01, w, w]);

            translate([edge_x + body + ramp - 0.01, wall_y - 0.01, pos - w/2])
            cube([0.01, 0.01, w]);
        }
    }
}

// panel_top sits at the panel/top JOINT, not cleanly on either adjacent
// segment -- per direct instruction, uses the PANEL's own angle (panel_a,
// 45°) rather than the top segment's (flat) or a hand-picked joint
// compromise. (A second mount, shelf_panel, used to share this module too
// -- removed 2026-08-19, see own_mount_boss_centers' comment; kept as its
// own module rather than folding back into flat_mount_boss() in case
// another tilted-joint mount is ever needed.) Reuses flat_mount_boss()'s
// "z" case UNROTATED (flush at local z=-wall, the panel's own interior
// surface, matching hardware_cutouts()'s panel-local frame exactly) -- the
// wrapping rotate()+translate() here is copied from hardware_cutouts()'s
// own panel block, so this lands in the identical local frame as the
// OLED/encoder/LED cutouts already placed there.
//
// pos_y is LOCAL y within that rotated frame, NOT the target's global Y --
// 15 (the current call, see blank_side_mount_bosses() below) matches the
// MX note-key row's own local y exactly ("in line with the note keys").
// z is fixed at the module's own default (flush at local z=-wall=-5,
// extending to z=-17) -- a boss_w=12 boss centered in that range (z=-11)
// comfortably clears both the note keys (y=15, no local-y overlap with
// the OLED's y=[-20.5,-5.5]) and the panel's own interior surface.
module panel_mount_boss(pos_y) {
    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0])
    flat_mount_boss(pos_y, "z");
}

// This piece's own 4 mount/boss centers (Y,Z) -- down from 5 as of
// 2026-08-19, per direct feedback after inspecting the corrected-shape
// render:
//   - shelf_panel (was [74,48]) REMOVED entirely -- described as "hanging
//     off in space," not landing on solid material worth reinforcing.
//     pot-side's blank_side_mount_yz drops the matching clearance hole.
//   - panel_top moved from [45,73] to [56.701,61.834] -- the old position
//     collided with the OLED cutout (confirmed: OLED's local y-span
//     [-20.5,-5.5] overlapped the boss's old local y=-1.170+/-6). New
//     position is local (y=15, z=-11) in the panel's own rotated frame --
//     y=15 matches the MX note-key row's own y ("in line with the note
//     keys", the same y hardware_cutouts() uses for the key cutouts),
//     z=-11 is simply centered in a boss_w=12 boss flush at the panel's
//     interior face (z=-wall=-5, so z-span [-17,-5], center -11) -- no
//     positional meaning to z beyond good margin. Verified no overlap
//     with the note keys themselves (nearest key's own X is >4mm clear of
//     this boss's X-reach) or the OLED (y-spans don't overlap: OLED
//     [-20.5,-5.5] vs boss [9,21]).
//   - front_bottom/front_top's Y moved from 110 to 114.73 -- confirmed via
//     direct feedback that the bore wasn't centered in the boss: a
//     boss_w=12 boss flush at the front wall's interior face
//     (case_d-wall=120.73) spans Y=[108.73,120.73], center 114.73, not
//     110 (which left only 1.27mm of material past the bore on the free
//     side). Z unchanged (12/42) -- verified this doesn't newly collide
//     with the speaker housing (housing's own Y-reach [100.73,120.73]
//     overlaps this boss's Y-range regardless of the exact Y chosen
//     within it, but the housing is centered at X=0 with only a 98mm
//     width -- X:[-49,49] -- while these bosses sit near edge_x, X
//     around -92 to -69, well clear in X either way).
//
// FLAGGED, NOT FIXED: front_top WILL collide with the joystick mounting
// posts once joystick-mount-dev.scad's design is ported back in (see the
// PAUSED note below) -- computed precisely, not guessed: the joystick's
// two post rows (front_dy=14, back_dy=-12.5 in the shelf's own local
// frame) reach global Z=[33.43,45.31] and Z=[37.11,49.00] respectively,
// i.e. together nearly the entire front wall's own usable Z extent
// [0,48.895] above Z~33 -- there's no simple Z-nudge for front_top (Z=42)
// that both clears this and stays meaningfully "near the top" of the
// wall. This needs an actual decision (move front_top somewhere off this
// wall entirely, or revisit the joystick posts' own reach) before the
// joystick gets ported back, not a small tweak here.
//
// Must stay identical to chromacade-pot-side.scad's blank_side_mount_yz
// (regenerate both together if the dimension constants above change) --
// that file is the authoritative source for these positions (pot-side's
// clearance holes were being deliberately repositioned for the new
// speaker housing; this array needs to track wherever that source of
// truth puts them, not the reverse). If you need to move one of these,
// change it in pot-side.scad first and copy the value here.
// panel_top's entry (index 2) is a STATIC snapshot of panel_mount_boss(15)'s
// real global position -- it is NOT a formula, so it goes stale whenever
// panel_my/panel_mz shift, which happens whenever shelf_d (or any other
// upstream dimension feeding the p0-p5 chain) changes. Exactly this
// happened 2026-08-22 (shelf_d 47.625->60): the boss itself, built fresh
// via panel_mount_boss(15) at render time, moved correctly to the new
// panel_my/panel_mz -- but this array's stale (56.701,61.834) didn't, so
// blank_side_mounts()'s pilot hole (which drills straight from this array,
// not through panel_mount_boss()'s own transform) kept cutting the OLD
// position, severing the boss from the wall (confirmed via connected-
// component analysis on the rendered mesh: the boss existed but floated
// as a disconnected 12-vertex island). Recomputed via the panel-local
// forward transform (Y = panel_my + y*cos(panel_a) + z*sin(panel_a),
// Z = panel_mz - y*sin(panel_a) + z*cos(panel_a), at local (y=15,z=-11)
// -- see the comment block above) rather than read off a render, so this
// stays reproducible. Still a static value, still goes stale on the next
// upstream dimension change -- recompute the same way if that happens
// again, don't assume it's still current.
// front_bottom's Y (index 0) updated 2026-08-24: 114.73 -> 116.73. This
// entry is a DERIVED center (wall_y - w/2, an asymmetric flush-to-wall
// boss, not a symmetric pos like pot-side's own bosses -- see
// square_boss()'s comment in chromacade-pot-side.scad for that
// distinction), so shrinking front_bottom's own w from boss_w(12) to 8
// (see blank_side_mount_bosses() below) moves its true center: was
// wall_y-6=114.73, now wall_y-4=116.73. Exactly the same "stale derived
// value" bug class as panel_top's entry below and every other case this
// file's comments already warn about -- caught here rather than repeated.
// Indices 1-3 updated 2026-08-24 for the boss_w 12->10 shrink (see that
// constant's own comment) -- same "derived center goes stale" class as
// index 0 above, just triggered by a different constant this time.
// front_top (index 1): wall_y-w/2 = 120.73-5 = 115.73 (was 114.73 at w=12).
// panel_top (index 2): boss_w feeds panel_mount_boss()'s local z (-wall-
// w/2, was -11 at w=12, now -10) -- re-derived by rendering
// panel_mount_boss(15) directly and reading its real bounding-box center
// (Y=45.154, Z=64.263) rather than redoing the trig by hand, same
// reproducibility reasoning as the original derivation, just via render
// instead of algebra this time.
// top_back (index 3): (case_h-wall)-w/2 = 101.637-5 = 96.637 (was
// literal 95 -- that value was already a bit imprecise even at the old
// w=12, per that boss's own comment history; corrected precisely here
// while touching it anyway).
own_mount_boss_centers = [
    [116.73, 12],
    [115.73, 42],
    [45.154, 64.263],
    [14, 96.637],
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
//
// First entry's Z updated 2026-08-24: wall+boss_w/2 (11) -> wall+4 (9) --
// pot-side's matching boss (pos=110) shrunk to an 8mm cube (its own
// pot_side_mount_bosses() comment has the derivation), which moves its
// Z-center from wall+boss_w/2 to wall+height/2=wall+4. Written as the
// literal 9, not wall+4, since this array otherwise mixes literal Z
// values (85, 20) with wall-relative expressions inconsistently already;
// matches pot-side.scad's own pilot-hole fix.
// CORRECTED 2026-08-27 -- these were wall-relative (9, 15, 15, 15) but
// pot-side's real bores are wall_thin-relative (7, 8, 8, 8). pot-side's
// bosses are anchored at z_start/y_start = wall_thin (its strips_relief()
// moved the interior surface there), and pot_side_mounts() drills centered
// in those bosses: wall_thin+4 for the 8mm cube at pos=110, wall_thin+
// boss_w/2 for the three 10mm ones. Indices 1-3 were off by 7mm -- the boss
// for pos=30 only spans Z 3..13, so a clearance hole at 15 sat entirely off
// the boss and no M3 could have passed (clear_d=3.4 gives +/-1.7mm of slop,
// not 7mm). Index 0 was off by 2mm, also fatal. Written as wall_thin-
// relative expressions, not literals, so they track pot-side-final.scad's
// own anchors instead of going stale the way this array's history keeps
// doing.
pot_side_mount_yz = [
    [110, wall_thin + 4],
    [30, wall_thin + boss_w/2],
    [wall_thin + boss_w/2, 85],
    [wall_thin + boss_w/2, 20],
];

// Dispatches per mount rather than a generic loop -- front_bottom/
// front_top/top_back flush directly against a global-frame wall (pass the
// real wall_y/wall_z); panel_top goes through panel_mount_boss() (local
// frame, rotated) instead -- see both modules' own comments. shelf_panel
// removed 2026-08-19 (see own_mount_boss_centers' comment).
module blank_side_mount_bosses() {
    // TAPER RESTORED 2026-08-26. This was shrunk to a plain 8mm cube with
    // ramp=0 on 2026-08-24, and the ONLY justification recorded for
    // dropping its taper was that "this piece already generates print
    // support nearby for the joystick's mounting legs regardless" -- i.e.
    // the taper was free to lose because supports were being paid for
    // anyway. As of today the joystick posts are gone (moved to
    // chromacade-joystick-bracket.scad, see joystick_bracket_pilot_holes()
    // below), so that premise is dead: this boss is now the piece's only
    // remaining unsupported overhang, and leaving ramp=0 would keep a
    // support tower alive for the sake of one 8mm cube -- defeating the
    // whole point of the bracket change.
    //
    // Kept at w=8/body=8 (does NOT go back to the standard 10/10): that
    // shrink was for the speaker layout, see spk_cx's own comment above,
    // and spk_grille geometry is still derived from boss_body+boss_ramp at
    // the STANDARD size for the right speaker. Only ramp comes back, at
    // the shared boss_ramp (10), matching pot-side's mirror-position boss,
    // which kept its taper for exactly this reason.
    flat_mount_boss(own_mount_boss_centers[0][1], "y", wall_y=case_d-wall, w=8, body=8, ramp=boss_ramp); // front_bottom
    flat_mount_boss(own_mount_boss_centers[1][1], "y", wall_y=case_d-wall); // front_top
    panel_mount_boss(15); // panel_top (tilted joint, panel's own frame, local y=15 -- in line with the note keys)
    flat_mount_boss(own_mount_boss_centers[3][0], "z", wall_z=case_h-wall); // top_back
}

module blank_side_mounts() {
    // front_bottom stays pulled out of the loop, but its depth changes with
    // the taper coming back (2026-08-26). It was h=7 because with ramp=0
    // the boss's material ended hard at 8mm and the shared `engage`=15
    // would have drilled 7mm out into open air. Now the boss reaches
    // body+ramp = 8+10 = 18mm again, so a deeper bore has real material
    // around it -- but only the first 8mm is full 8x8 cross-section; past
    // that it's inside the hull() taper, thinning toward a sliver, so
    // engage=15 would put the last few mm of thread in near-nothing.
    // h=11 instead: the full 8mm cube plus 3mm into the thick end of the
    // taper, where there's still ~5mm of cross-section around a 2.5mm
    // bore. Deliberately NOT the shared `engage` -- that constant is sized
    // for the standard 10/10 bosses, and this one is still the small 8mm
    // variant.
    translate([edge_x, own_mount_boss_centers[0][0], own_mount_boss_centers[0][1]])
    rotate([0, 90, 0]) cylinder(h=11, d=pilot_d);

    for (i = [1:3]) {
        yz = own_mount_boss_centers[i];
        // Bore centered on the boss, not the bare-wall own_mount_yz point.
        translate([edge_x, yz[0], yz[1]]) rotate([0, 90, 0]) cylinder(h=engage, d=pilot_d);
    }
}

// Gap-blocking bridges (front_bottom/top_back "gap lips") -- REMOVED
// 2026-08-22. Confirmed via direct visual inspection (not just the CSG
// interference check that had signed off on them) that they didn't
// actually close anything: the underlying window/gap where the two
// pieces don't meet along X (at the bottom-front and top-back) is still
// there, and the bridges themselves just floated nearby without solving
// it -- "not a successful solution," removed rather than kept as
// pointless geometry. The real problem (pot-side/blank-side not meeting
// across the full X width at either the bottom-front or top-back
// corner) is still open -- see git history for this block's previous
// content (three iterations, each verified against pot-side's real
// geometry, all insufficient) before attempting another fix here.

module blank_side_clearance_holes() {
    for (yz = pot_side_mount_yz) {
        translate([case_w/2 - wall/2, yz[0], yz[1]])
        rotate([0, 90, 0]) cylinder(h=wall + 10, d=clear_d, center=true);
    }
}

// Joystick (KY-023) mounting bosses + pilot holes + gimbal clearance --
// PORTED BACK 2026-08-19 from the validated design in
// enclosure/joystick-mount-dev.scad (see that file's own header for the
// full design history: two abandoned taper/wedge redesigns, before
// landing back on plain a4f6a10-style vertical posts -- exactly what was
// physically printed and confirmed to fit -- plus ONE new addition, a
// gimbal-clearance sphere, that the original printed version didn't have).
// Built in the shelf's own local frame -- same
// translate([0,shelf_my,shelf_mz])/rotate([-shelf_a,0,0]) hardware_cutouts()
// already uses for the stick hole and encoders -- then translate([joy_x,0,0])
// so the dev file's own local (0,0) origin (centered on the stick hole)
// lines up with the real stick hole's actual position. shelf_my/shelf_mz
// recomputed locally in each module rather than hoisted to a shared
// constant, matching this file's own established convention (see
// panel_mount_boss()).
//
// joy_x corrected 2026-08-18 from 70 to -65: confirmed in play position
// (facing the front of the case from outside) RIGHT is the -X direction
// here, and the joystick sits far right (paired with the font encoder at
// x=-35) -- the rocker (paired with the octave encoder at x=45) is the one
// at x=70, far left. Was backwards in the first pass.
joy_x       = -65; // matches the shelf's joystick stick-hole X position
joy_stick_d = 27;  // CONFIRMED 2026-08-19 -- no longer under test

// Depth (Y, front-to-back on the shelf) repositioning -- 2026-08-22,
// alongside the shelf_d increase to 60mm above. Reserves the first 20mm
// of the shelf (nearest the front wall) as a clearance zone nothing may
// intrude into, then centers the stick hole in the remaining depth.
// joy_y_offset is a formula off shelf_d, not a hardcoded number, so it
// stays correct if shelf_d changes again -- the existing code below
// already treats local Y=0 as the shelf's own geometric midpoint (via
// shelf_my/shelf_mz = the p2-p3 average), so this is expressed as an
// offset FROM that midpoint, not an absolute depth.
joy_reserved_front  = 20; // nothing may intrude into this zone, front edge (p2) inward
joy_depth_from_front = joy_reserved_front + (shelf_d - joy_reserved_front) / 2; // = 40 at shelf_d=60
// SIGN FIXED 2026-08-22, caught by re-deriving from scratch rather than
// trusting the first pass: joy_hole_front_dy=+14 means POSITIVE local Y
// is toward the front wall (smaller depth-from-front-edge), so
// depth_from_front = shelf_d/2 - local_Y, not local_Y - shelf_d/2 as the
// first version of this line computed (which moved the joystick TOWARD
// the front face -- the opposite of what was asked -- rather than back
// toward the panel).
joy_y_offset = shelf_d / 2 - joy_depth_from_front; // offset from shelf's own midpoint; negative = toward the back

// Real hardware measurements (2026-08-18/19) -- names match the original
// a4f6a10 commit that these bosses first shipped under, for continuity.
joy_hole_dx       = 9;    // board hole +/-9mm left-right, both pairs
joy_hole_front_dy = 14;   // front pair (toward speaker wall), 14mm off joystick center
joy_hole_back_dy  = -12.5; // back pair (toward device center), 12.5mm off center
joy_boss_h        = 12;   // MEASURED-derived standoff height (matches the board+header stack)
joy_boss_d        = 6;    // ESTIMATE -- same as the physically-printed original
joy_pilot_d       = 2.5;  // ESTIMATE -- confirm the board's actual screw size

// MEASURED topside masses on the KY-023 board -- 2026-08-27, caliper
// figures from the real part, replacing the 25mm cylinder that was here for
// one revision (an ESTIMATE, and wrong in both directions: it over-carved
// the rib middles right where the screw pads need material, and it was
// centered on a swing envelope rather than on the actual obstructions).
//
// All in the stick-centered board frame, same as joystick_boss_xy(). Z runs
// from the board plane (top face of the PCB, z = -wall - joy_boss_h) upward.
// The board's long axis is local Y: front edge +16.5 (toward the speaker),
// rear edge -17.5, so the 34mm length maps to Y and the reported
// "12mm to 22mm along the long side" band is Y = -5.5 .. +4.5 -- the same
// span measured from either end, which is a useful cross-check that the
// figure was read consistently.
//
// THE THREE MASSES:
//   1. The gimbal body -- a 16 x 16mm cube, 12mm tall, centered on the
//      stick. 12mm is the whole standoff: it reaches the shelf's interior
//      face exactly, so it is not a partial-height obstruction that a rib
//      could pass over. This is the one that matters, and it is the reason
//      the ribs fouled: their inner edges sat at +9 and -8.5, against this
//      cube's +8/-8 faces -- 1mm and 0.5mm of nominal gap, which is nothing
//      once the rotor arms and print tolerance are in it. That is what got
//      knife-trimmed on assembly.
//   2/3. Two masses on the board's long edges in the Y band above, outboard
//      of the cube: one reaching the full 12mm to the gimbal's underside,
//      one a push-button base about 10mm tall. Which side is which was not
//      recorded, so BOTH are modelled at the full 12mm -- conservative, and
//      it costs nothing here because this band is nowhere near either rib.
//      They run from the cube's own faces out to the board edges (+/-13.5).
//
// The "couple of other little outcroppings" are absorbed by joy_body_tol
// below rather than modelled. Anything standing more than that above these
// surfaces needs measuring and adding -- it will not be caught by a render.
joy_body_cube      = 16;   // MEASURED -- gimbal body, X and Y
joy_body_cube_h    = 12;   // MEASURED -- full standoff, reaches the shelf
joy_body_band_y0   = -5.5; // MEASURED -- "12mm" along the long axis
joy_body_band_y1   =  4.5; // MEASURED -- "22mm" along the long axis
joy_body_band_h    = 12;   // both long-edge masses, at the taller one's height
joy_body_tol       = 0.75; // slop + the unmodelled small outcroppings

// Total clearance carved around the cube is joy_body_tol PLUS the rib
// setback below, so the real gap to the measured mass is ~1.75mm, not 0.75.
// EXTENDED DOWNWARD 2026-08-27. These were bounded at the board plane,
// which described only where the masses END UP, not how they get there --
// a pocket the masses would have to already be inside. The board is
// installed by lifting it straight up from below (see the ASSEMBLY note
// above), so every mass sweeps the full height of the pocket on its way in
// and each clearance has to be an open channel from the shelf all the way
// down and out, not a closed recess. joy_body_drop carries them well past
// the board plane so the channel stays open no matter what is added under
// the shelf later -- there is nothing down there now, so this removes no
// material today and cannot fail to remove it tomorrow.
//
// Deliberately NOT swept along Y (the direction the board would slide in
// from the open back): the band is 28.5mm wide against the back rib's 24mm,
// so a Y sweep would sever that rib and take both of its screw pads with
// it. A vertical channel costs nothing; a horizontal one costs the mount.
joy_body_drop = 40;

module joystick_body_clearance() {
    c  = joy_body_cube/2 + joy_body_tol;
    z0 = -wall - joy_boss_h - joy_body_drop;

    translate([-c, -c, z0])
    cube([2*c, 2*c, joy_body_cube_h + joy_body_drop]);

    translate([-joy_pcb_w/2 - joy_body_tol,
               joy_body_band_y0 - joy_body_tol, z0])
    cube([joy_pcb_w + 2*joy_body_tol,
          (joy_body_band_y1 - joy_body_band_y0) + 2*joy_body_tol,
          joy_body_band_h + joy_body_drop]);
}

// Sphere radius (27mm diameter, matching joy_stick_d)// Sphere radius (27mm diameter, matching joy_stick_d), centered on the
// stick hole's own true center: (0,0) in the shelf-local XY (i.e. joy_x,0
// after the translate below), and half the shelf thickness down in Z
// (-wall/2) -- the center of the hole through the material, not the
// interior face. Carves into whichever boss material intrudes on the
// joystick's real gimbal swing below the shelf; touches nothing above the
// shelf since the stick hole cut already owns that space at the same
// 27mm diameter. See joystick-mount-dev.scad's header for the full
// reasoning and how this was numerically verified.
joy_gimbal_r = 13.5;

function joystick_boss_xy() = [
    [-joy_hole_dx, joy_hole_front_dy],
    [ joy_hole_dx, joy_hole_front_dy],
    [-joy_hole_dx, joy_hole_back_dy],
    [ joy_hole_dx, joy_hole_back_dy],
];

// POSTS REPLACED BY AN INTEGRAL PLINTH 2026-08-26 -- the support-time fix.
//
// joystick_mount_bosses() used to emit four plain d=6 x 12mm posts standing
// off the shelf's interior face. In this piece's print orientation (own +X
// endcap face-down on the bed, building toward -X, see file header) the
// shelf is a wall whose length runs along the BUILD axis, and those posts'
// axes lay perpendicular to it -- each a bare 12mm cantilever whose first
// layer appeared in mid-air at joy_x=-65, i.e. case_w/2 + 65 = 162.8mm of
// print height. Four support towers from the bed: the whole reason this
// piece took ~12h against pot-side's 5.5h, and most of the wasted PLA.
// Every other cantilever here was already support-free by construction
// (see flat_mount_boss()'s hull() taper and its 2026-08-19 rebuild note);
// the posts were the one exception, carried over unexamined from
// joystick-mount-dev.scad where they were validated for FIT, not for this
// orientation.
//
// Replaced by TWO PARALLEL RIBS hanging off the shelf's interior face down
// to the same board plane the post ends defined, carrying the same four
// pilot holes. A short-lived separate bracket part (2026-08-26,
// chromacade-joystick-bracket.scad, deleted) was tried first and rejected:
// an extra part, four extra screws, and only 3.5mm of thread into a 5mm
// shelf.
//
// FOOTPRINT is deliberately no wider than the OLD POSTS' OWN ENVELOPE:
// 3mm of pad around each hole, so the ribs' outermost material sits at
// joy_hole_front_dy+3 = +17 and joy_hole_back_dy-4 = -16.5, and local x
// runs +-(joy_hole_dx+3) = +-12. The front edge is what matters -- the
// left speaker's mounting plate spans X -68.64..+1.36 and reaches 17mm
// back from the front wall's interior face, and the joystick at X=-65 sits
// 3.6mm inside that span. At +17 the front rib's face clears the plate's
// rear-top corner by 2.46mm. A 5mm pad (+19) was drawn up and
// rejected: it cuts that to 0.46mm, which is inside print tolerance on a
// 195mm-tall part -- fine in CAD, fouling in plastic. Since the printed
// a4f6a10 posts already occupied exactly this envelope, the +17 figure is
// proven by a real build rather than only by arithmetic.
//
// What did NOT change: the 27mm stick hole (hardware_cutouts()), the four
// hole positions (joystick_boss_xy()), the 12mm standoff (joy_boss_h), the
// pilots (joystick_plinth_pilot_holes() below is the old
// joystick_mount_pilot_holes() verbatim, so screw engagement is identical),
// and joystick_gimbal_clearance().
//
// NOTE on the gimbal carve -- SUPERSEDED 2026-08-27, kept because its
// reasoning was right and its premise was wrong. It read: the sphere is
// r=13.5 centered on the stick hole, every screw sits at radius 15.4 (back)
// or 16.6 (front), both outside 13.5, so the carve only hollows the rib
// middles. All true, and still true of the sphere. What it missed is that
// the sphere is not the whole obstruction: the gimbal BODY between the PCB
// and the stick is straight-sided over the full 12mm standoff and the
// sphere tapers away from it, so the ribs stood proud into it low down and
// had to be knife-trimmed on first assembly. Now handled by the MEASURED
// masses in joystick_body_clearance() plus an explicit setback of both rib
// inner edges -- see joy_body_cube above. (A 25mm cylinder stood here for
// one revision as an estimate of that body; it was replaced by caliper
// figures, which showed the real cube is 16mm and the fouling was at the
// ribs' inner edges, not their middles.) The radius argument above still
// holds for the sphere itself: every bore is at radius 15.4mm or more, so
// the swing dome never reaches one.
//
// TWO PARALLEL RIBS, not a solid block (2026-08-26, direct instruction --
// the first pass here was one solid plinth and read as "a closed box
// extending from the lower part of the shelf"). Each rib runs along X,
// carries one screw pair, and gets its own +X ramp. Why this shape, beyond
// using less plastic:
//   - The middle is exactly where the gimbal sphere carves anyway, so a
//     solid block paid for material that gets cut straight back out.
//   - Ribs must run along X, NOT along Y. A rib at constant X spanning Y
//     would be a slab whose face is perpendicular to the build axis: one
//     large unsupported overhang. Running along X makes each rib a wall
//     whose plane contains the build axis, which needs support only at its
//     first layer -- and that is what the +X ramp is for.
//   - The open span between the ribs clears the board's rear header and
//     leaves the pocket visible during assembly.
//
// ASSEMBLY -- CORRECTED 2026-08-27, this was wrong and it is the reason the
// first build needed a knife. The board does NOT go through the 27mm stick
// hole (it is 27 x 34mm) and it goes in before the two halves are joined:
// this piece owns only the front wall, shelf, panel and top, so on its own
// the print is an open C with the bottom and back belonging to
// pot-side-final.scad.
//
// The previous note said the board "slides in flat at the board plane from
// the open back -- both ribs sit ABOVE that plane, so nothing obstructs the
// slide." That was true of a BARE board and false of the real one. The
// masses on its top face stand the full 12mm to the shelf (see
// joy_body_cube), so a flat slide drives them straight into the back rib,
// which hangs that same 12mm down across the whole path. The clearances
// carved for those masses described the final position only; there was no
// path into it. Fitting it anyway is what forced the ribs to be cut away.
//
// CORRECT ASSEMBLY, as of the pass-through slots (joystick_rib() below):
// the board slides in FLAT again, from the open back, and the topside masses
// pass through the 12 x 8mm slot in each rib rather than having to clear it.
// That is what the slots are for and it supersedes the vertical-lift plan
// that briefly stood here in between. Stick goes up through the 27mm hole as
// the board reaches position; the four screws then drive upward into the
// pads, which the slots deliberately leave intact at x = +/-9.
//
// The vertical route still works and is worth knowing as a fallback if a
// mass turns out to be taller than the slot's 8mm -- the rib gap is clear
// for it, which is the point of the setback on the rib inner edges:
//   - the gimbal cube (+/-8.75 grown) rises through the rib gap, which runs
//     -9.75 to +10.5 -- 1.0mm of side clearance at the back, 1.75mm front;
//   - the long-edge band spans Y -6.25..+5.25, where NO rib exists at all,
//     so its full 28.5mm width passes untouched;
//   - nothing sits below the board plane, and joy_body_drop keeps the
//     channels open through it regardless.
// The assertions further down enforce both of those clearances, so this
// path cannot silently close again. Knob goes on last, from outside.
//
joy_rib_dx       = joy_hole_dx + 3;          // +-12
// Front rib is asymmetric on purpose: 3mm ahead of its hole (the speaker
// limit derived above), 5mm behind it. Back rib is an even 4mm either side.
// INNER EDGES PULLED BACK 2026-08-27 (front +9 -> +10.5, back -8.5 ->
// -9.75) so both ribs sit clear of the measured gimbal cube instead of
// relying on a CSG carve to notch them. The cube's tolerance-grown faces
// are at +/-8.75, so the setback is 1.75mm (front) and 1.0mm (back) of air
// on top of joy_body_tol. Not symmetric because the two bores are not: the
// back pair is 12.5mm off center against the front pair's 14mm, so the back
// rib has 1.5mm less room to give. Both figures are the binding limit --
// each rib's inner edge is as far out as it can go while keeping 1.5mm of
// pad on the inboard side of its bore (see the assertions below), and no
// further, because narrowing a rib is losing the screw pad this whole
// structure exists to provide. The OUTER edges are unchanged: +17 is the
// speaker-plate limit derived above and -16.5 is the board's own rear
// screw margin.
joy_rib_front_y0 = joy_hole_front_dy - 3.5;  // +10.5
joy_rib_front_y1 = joy_hole_front_dy + 3;    // +17
joy_rib_back_y0  = joy_hole_back_dy  - 4;    // -16.5
joy_rib_back_y1  = joy_hole_back_dy  + 2.75; // -9.75

// Support-free ramp on the +X face of each rib, and ONLY that face. +X is
// the side already printed (endcap-down, building toward -X), so that is
// where a rib has to grow out of the shelf; the -X face is the last layer
// and is free.
//
// A full 45deg ramp would need 12mm of run for the 12mm drop, feathering
// out at X = joy_x+12+12 = -41. The front encoder is on the shelf at
// X=-35 with a 15x12x10mm body, so it occupies X -42.5..-27.5 -- the ramp
// tip would foul it by ~1.5mm. Chosen fix (direct instruction, of three
// options): ramp 9mm at 45deg covering 9mm of the drop, then let the last
// 3mm be a vertical step. The step lands at X = joy_x+21 = -44, clearing
// the encoder body by 1.5mm, and a 3mm unsupported step bridges cleanly --
// no support, full 3mm screw pad kept, encoder untouched. Do not lengthen
// joy_rib_ramp past 9 without re-checking that -42.5 encoder edge.
joy_rib_ramp = 9;
joy_rib_step = 3;

// One rib: full-depth body plus its own +X ramp. y0/y1 are local Y in the
// stick-centered frame. Both hull slices stay flush at the shelf's
// interior face (z=-wall) and only the free-side reach shrinks -- the same
// wall-anchored rule flat_mount_boss()'s own 2026-08-19 rebuild note
// spells out. A slice that floated off the wall would be the very overhang
// this exists to avoid.
// PASS-THROUGH SLOT, added 2026-08-27 per direct instruction: 12mm wide by
// 8mm tall, cut through the full thickness of each rib, starting 7mm from
// the rib's FLAT end (the -X end -- the ramp is on +X, so "flat end" is
// unambiguous). Local X therefore runs -joy_rib_dx + 7 = -5 to +7.
//
// This is the path the board's topside masses travel along. It changes the
// assembly back to a horizontal slide (see the ASSEMBLY note above, updated
// again): the masses pass THROUGH the ribs rather than needing to clear
// them, which is what the vertical-lift plan was working around.
//
// Vertically the slot is OPEN AT THE BOTTOM -- it runs from the board plane
// (z = -wall - joy_boss_h = -17) up 8mm to z = -9, leaving a 4mm web of rib
// at the top, attached to the shelf. That is the only useful reading of
// "8mm tall": a closed window with material below it would leave a lip at
// the board plane for a mass to catch on, and the lip would be an
// unsupported ledge in this print orientation besides. The 4mm web is what
// keeps each rib a single continuous piece across the slot.
//
// PRINT CONSEQUENCE, known and accepted: this piece builds +X endcap down,
// toward -X, so the slot's -X wall is material RETURNING after an 8mm gap
// with nothing behind it -- a one-layer droop over roughly 8 x 6.5mm on the
// slot's far edge. It cannot be chamfered away: a 45deg return needs 8mm of
// X run, and the screw bore sits 2.75mm away at x=-9, where the pad must
// keep its FULL 12mm height or the board no longer seats against the rib's
// bottom face. The droop is interior, cosmetic, and one layer deep; the
// alternative (starting the slot at the flat end, 0mm instead of 7mm)
// removes the step entirely but sacrifices that screw pad.
joy_slot_w         = 12;  // along X
joy_slot_h         = 8;   // along Z, up from the board plane
joy_slot_from_flat = 7;   // from the rib's flat (-X) end
joy_slot_x0        = -joy_rib_dx + joy_slot_from_flat;   // -5
joy_slot_x1        = joy_slot_x0 + joy_slot_w;           // +7

// SACRIFICIAL SUPPORT INSIDE THE SLOT -- added 2026-08-27. Modelled here
// rather than left to the slicer for one specific reason: the void below the
// slot's returning face is bounded on the print's NEAR side by the rib
// itself at x = +7, so a slicer asked to support that face builds a stubby
// column trapped inside the slot, in the exact 12 x 8mm passage the slot
// exists to provide, with no clean tool access to remove it. Two pins we
// place deliberately are easier to snip out than one blob the slicer
// improvises.
//
// HOW THEY WORK IN THIS ORIENTATION: layers advance +X -> -X, so each pin is
// simply a short column growing along the build direction, standing on the
// slot's near wall (solid rib at x >= +7). Columns along the build axis are
// the cheapest thing there is to print -- no overhang, no bridging. They
// stop 0.2mm short of the face they support (joy_slot_sup_gap), which is the
// standard support-interface trick: the drooping first layer sags that
// 0.2mm onto the pin and rests there without fusing to it.
//
// ANCHORED ONLY AT +X: each pin is fused to the near wall and free at the
// far end, so removal is one cut at the anchor, reachable from either side
// of the rib (the slot runs through the full thickness). Snip flush and the
// passage is clear.
//
// PLACEMENT: both pins sit in the LOWER half of the face -- z -16.5..-14.9
// and -14.0..-12.4. The top 3.4mm of the returning face is left unsupported
// on purpose: it hangs directly off the 4mm web, which is fused to the shelf
// along its whole length, so it barely droops. The low end is the part with
// nothing near it. Staying below z=-12 also keeps the pins clear of
// joystick_gimbal_clearance()'s sphere, which reaches down to z=-11.84 at
// the back rib's inner face -- a pin any higher would be sliced off at an
// angle by that carve and support nothing.
//
// SET joy_slot_support = false FOR THE PRODUCTION PART if you would rather
// take the one-layer droop than cut four pins.
joy_slot_support   = true;
joy_slot_sup_gap   = 0.2;   // air gap at the supported face -- do not fuse
joy_slot_sup_sq    = 1.6;   // pin cross-section, Z and Y
joy_slot_sup_z     = [-16.5, -14.0];

module joystick_rib(y0, y1) {
    w = y1 - y0;

    union() {
        difference() {
            union() {
                translate([-joy_rib_dx, y0, -wall - joy_boss_h])
                cube([2*joy_rib_dx, w, joy_boss_h]);

                hull() {
                    translate([joy_rib_dx - 0.01, y0, -wall - joy_boss_h])
                    cube([0.01, w, joy_boss_h]);

                    translate([joy_rib_dx + joy_rib_ramp - 0.01, y0, -wall - joy_rib_step])
                    cube([0.01, w, joy_rib_step]);
                }
            }

            // Through the full rib thickness (+/-1mm past each face) so the cut
            // is unambiguous rather than coincident-surface.
            translate([joy_slot_x0, y0 - 1, -wall - joy_boss_h - 0.5])
            cube([joy_slot_w, w + 2, joy_slot_h + 0.5]);
        }

        if (joy_slot_support)
        for (sz = joy_slot_sup_z)
            translate([joy_slot_x0 + joy_slot_sup_gap,
                       y0 + w/2 - joy_slot_sup_sq/2,
                       sz])
            cube([joy_slot_w - joy_slot_sup_gap, joy_slot_sup_sq, joy_slot_sup_sq]);
    }
}

module joystick_plinth() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, joy_y_offset, 0]) {
        joystick_rib(joy_rib_front_y0, joy_rib_front_y1);
        joystick_rib(joy_rib_back_y0,  joy_rib_back_y1);
    }
}

// KY-023 board outline -- MEASURED 2026-08-26, first time this has been
// recorded anywhere in the project (only the hole pattern and standoff
// height were, which is why nothing was checking the board's real edges
// against the speaker). NOT part of the model: a mockup for fit checking,
// in the style of chromacade-fit-check.scad's encoder_mockup(). Call it
// alongside the piece to eyeball interference.
//
// Origin is the stick hole's own center, same frame as joystick_boss_xy().
// The edge nearest the speaker is 2.5mm beyond the front hole centers, so
// front edge = joy_hole_front_dy + 2.5 = +16.5 -- BEHIND the front rib's
// +17 face, so the rib stays the part controlling speaker clearance, not
// the board. From there it runs 34mm back to -17.5, and the rear header
// adds 5mm to -22.5. The board is 27mm wide (+-13.5), i.e. 1.5mm wider
// than the ribs on each side -- that overhang is into free air.
//
// The header at -22.5 is 2.5mm past the shelf's own rear edge (shelf-local
// -32.5 vs the shelf ending at -30), which sounds like a collision and is
// not: it sits 12mm below the shelf and the panel rises away from p3 at
// 45deg, leaving ~10mm of clearance to the panel's interior face.
joy_pcb_w         = 27;
joy_pcb_front_dy  = 2.5;   // front edge, beyond the front hole centers
joy_pcb_l         = 34;
joy_pcb_t         = 1.6;   // ESTIMATE -- not measured, standard 1.6mm FR4
joy_pcb_header_l  = 5;
joy_pcb_header_w  = 13;    // ESTIMATE -- 5-pin 2.54mm header, confirm

module joystick_board_mockup() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    pcb_y1 = joy_hole_front_dy + joy_pcb_front_dy;   // +16.5
    pcb_y0 = pcb_y1 - joy_pcb_l;                     // -17.5
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, joy_y_offset, 0]) {
        translate([-joy_pcb_w/2, pcb_y0, -wall - joy_boss_h - joy_pcb_t])
        cube([joy_pcb_w, joy_pcb_l, joy_pcb_t]);

        translate([-joy_pcb_header_w/2, pcb_y0 - joy_pcb_header_l, -wall - joy_boss_h - joy_pcb_t])
        cube([joy_pcb_header_w, joy_pcb_header_l, joy_pcb_t]);
    }
}

// Verbatim the old joystick_mount_pilot_holes() -- same origin, same
// depth, same diameter, so the board's screw engagement is byte-for-byte
// what the a4f6a10 print validated. Only the material around them changed.
module joystick_plinth_pilot_holes() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, joy_y_offset, 0])
    for (p = joystick_boss_xy())
        translate([p[0], p[1], -wall - joy_boss_h - 0.5])
        cylinder(h = joy_boss_h + 1, d = joy_pilot_d);
}

// Gimbal clearance: the swing dome (sphere, at the shelf) UNIONED with the
// measured static masses (joystick_body_clearance(), board plane up to the
// shelf's interior face -- see joy_body_cube above). Two different things,
// deliberately both: the sphere is the stick's own deflection envelope near
// the shelf, where it reaches wider than the 16mm body does, while the
// cube/band are the fixed obstructions lower down that the sphere tapers
// away from. Dropping either one reintroduces a real interference.
//
// The body clearance runs the FULL standoff and 0.5mm past the board plane
// at the bottom for a clean manifold cut -- nothing exists below that plane
// to protect, the board itself slides in flat underneath. With the ribs'
// inner edges now set back explicitly (see joy_rib_front_y0/back_y1), this
// carve should not be removing any rib material at all; it stays subtracted
// as a backstop, so a future edit that walks a rib back into the gimbal
// gets a hole rather than an interference.
module joystick_gimbal_clearance() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, joy_y_offset, 0]) {
        translate([0, 0, -wall/2])
        sphere(r = joy_gimbal_r);

        joystick_body_clearance();
    }
}


// --- SEAM-GAP ASSERTIONS (added 2026-08-27) ---------------------------------
// Three places independently decide where this piece's material starts and
// stops along X, and nothing used to check that they agreed:
//
//   1. edge_x            -- the mating edge nearest the other piece; every
//                           mount boss and pilot bore is positioned from it.
//   2. strips()'s X-mask -- the clipping cube's own center/width.
//   3. endcap_relief()   -- the exterior slab removed for the thinner endcap.
//
// A single wrong constant in any one of them is invisible in a render (the
// piece still looks right on its own, still renders a clean manifold) and
// only shows up as a gap or an interference after ~6 hours of printing --
// which is exactly what happened to pot-side-final.scad, whose
// `wall` was 3 instead of 5: relief width collapsed to 0, edge_x moved 2mm
// outward, assembled case measured 195mm instead of 191.58mm.
//
// These are recomputed here from the SAME literal expressions the modules
// below use (deliberately duplicated, not factored out -- a shared helper
// would move in lockstep with a bad edit and check nothing) and compared.
// assert() aborts the render, so a mismatch can never reach a slicer.
seam_eps = 1e-6;

// Independent restatements of the three definitions:
seam_edge_x_def   = -case_w/2 + wall + edge_clearance;                    // edge_x
seam_strip_w      = case_w - wall - edge_clearance;         // strips()' mask width
seam_strip_cx     = (wall + edge_clearance)/2;        // strips()' mask center
seam_strip_inner  = seam_strip_cx - seam_strip_w/2;             // mating end
seam_strip_outer  = seam_strip_cx + seam_strip_w/2;             // exterior end
seam_relief_w     = wall - wall_thin;                       // endcap_relief() slab width
seam_relief_cx    = (case_w/2 - seam_relief_w/2);
seam_relief_inner = seam_relief_cx - seam_relief_w/2;
seam_relief_outer = seam_relief_cx + seam_relief_w/2;

// The thinning must actually be a thinning. wall==wall_thin (the real bug)
// makes the relief a zero-width no-op; wall<wall_thin would grow the piece.
assert(wall > wall_thin,
    str("SEAM: wall (", wall, ") must exceed wall_thin (", wall_thin,
        ") -- a zero/negative relief means endcap_relief() removes nothing ",
        "and this piece prints ", wall - wall_thin, "mm over-wide per side."));

// 1 vs 2: the strips' mating end IS edge_x. If these part company, every
// mount boss sits at one X and the material it should be embedded in at
// another -- the class of error that leaves bosses as floating islands.
assert(abs(seam_strip_inner - edge_x) < seam_eps,
    str("SEAM: strips() X-mask mating end (", seam_strip_inner,
        ") != edge_x (", edge_x, ")"));
assert(abs(seam_edge_x_def - edge_x) < seam_eps,
    str("SEAM: edge_x (", edge_x, ") does not match its own definition (",
        seam_edge_x_def, ") -- a constant it depends on was changed."));

// 2 vs 3: the relief only bites the endcap+strips if the strips still reach
// the TRUE exterior face before the cut. This is what silently held on
// pot-side while the relief itself did nothing.
assert(abs(abs(seam_strip_outer) - case_w/2) < seam_eps,
    str("SEAM: strips() must reach the true exterior face (", case_w/2,
        ") pre-relief; reaches ", seam_strip_outer));
assert(abs(abs(seam_relief_outer) - case_w/2) < seam_eps,
    str("SEAM: endcap_relief() must start at the true exterior face (",
        case_w/2, "); starts at ", seam_relief_outer));

// 3 alone: the relief cuts OUTWARD only. Cutting past the endcap's interior
// face (case_w/2 - wall) is the direction the 2026-08-24 reversal fixed --
// it would move edge_x's reference surface and desync both pieces.
assert(abs(seam_relief_inner) > case_w/2 - wall + seam_eps,
    str("SEAM: endcap_relief() reaches ", seam_relief_inner,
        ", past the endcap's interior face (", (case_w/2 - wall),
        ") -- it must remove exterior material only."));

// Cross-file: both pieces shed (wall - wall_thin) from their own endcap, so
// the assembled width is case_w - 2*(wall - wall_thin). 191.58mm is the
// value the good blank-side half was printed against; the bad pot-side gave
// 195mm. Both finals must agree with it to 0.01mm.
// ONE-OFF: 195.58, not the 191.58 the matched pair is cut for. The bad pot
// print contributes a full un-relieved 97.79 half-width; this piece
// contributes case_w/2 - (wall-wall_thin) = 99.79 - 2 = 97.79.
case_w_assembled_expected = 195.58;
seam_assembled = case_w - 2*(wall - wall_thin);
assert(abs(seam_assembled - case_w_assembled_expected) < 0.01,
    str("SEAM: assembled case width would be ", seam_assembled,
        "mm, not the ", case_w_assembled_expected,
        "mm this one-off pairing is cut for."));

// ONE-OFF mating checks against the bad pot print's REAL geometry,
// recomputed here from that file's own broken constants (wall=3,
// wall_thin=3, edge_clearance=0.15) so this is reproducible rather than a
// pair of magic numbers. If either fails, this piece has drifted off the
// print it exists to mate with -- do not slice it.
oneoff_mate_case_w    = 7.7 * in2mm;              // the bad print's nominal
oneoff_mate_wall      = 3;                        // its wall (the bug)
oneoff_mate_relief    = 0;                        // wall - wall_thin = 0 there
oneoff_mate_strip_end = oneoff_mate_case_w/2 - oneoff_mate_wall - edge_clearance;  // +94.64
oneoff_mate_endcap_in = -(oneoff_mate_case_w/2 - oneoff_mate_wall);               // -94.79

assert(abs(abs(edge_x) - oneoff_mate_strip_end) < seam_eps,
    str("ONE-OFF: this piece's mating edge (", edge_x,
        ") must sit at the bad pot print's strip end (",
        -oneoff_mate_strip_end, ") -- off by ",
        abs(edge_x) - oneoff_mate_strip_end, "mm."));

assert(abs((case_w/2 - wall) - (oneoff_mate_strip_end + edge_clearance)) < seam_eps,
    str("ONE-OFF: this endcap's interior face (", case_w/2 - wall,
        ") must clear the bad pot print's strips (", oneoff_mate_strip_end,
        ") by edge_clearance."));

assert(abs((seam_strip_inner - edge_clearance) - oneoff_mate_endcap_in) < seam_eps,
    str("ONE-OFF: this piece's strips reach ", seam_strip_inner,
        "; the bad pot print's endcap interior face is at ",
        oneoff_mate_endcap_in, " -- must differ by edge_clearance only."));

assert(oneoff_mate_relief == 0,
    "ONE-OFF: this file assumes the mate got NO endcap relief. If that print was replaced, use blank-side-final.scad instead.");

// The deliberate mating gap is edge_clearance and nothing else -- this is
// the number that read 4mm cumulative on the printed pair.
seam_mating_gap = (case_w/2 - wall) - abs(seam_strip_inner);
assert(abs(seam_mating_gap - edge_clearance) < seam_eps,
    str("SEAM: mating gap to the other piece's endcap interior face is ",
        seam_mating_gap, "mm, not edge_clearance (", edge_clearance, "mm)."));
// ---------------------------------------------------------------------------


// --- JOYSTICK CLEARANCE / PAD ASSERTIONS (2026-08-27) ----------------------
// Two competing requirements meet at the ribs' inner edges, and the margin
// on the back rib is ~1mm, so neither is safe to eyeball after an edit:
//   - each rib must stand clear of the measured gimbal cube, or it fouls on
//     assembly (what actually happened, and got trimmed with a knife);
//   - each bore must keep real material on BOTH sides, or the pad splits.
// Moving an inner edge trades one against the other directly.
joy_pad_min  = 1.5;   // same minimum wall as the MX clip trench
joy_cube_min = 0.5;   // air between a rib's inner edge and the grown cube
joy_cube_face = joy_body_cube/2 + joy_body_tol;   // +/-8.75

assert(joy_rib_front_y0 - joy_cube_face >= joy_cube_min,
    str("JOYSTICK: front rib inner edge (", joy_rib_front_y0,
        ") clears the gimbal cube's grown face (", joy_cube_face,
        ") by only ", joy_rib_front_y0 - joy_cube_face, "mm."));
assert(-joy_rib_back_y1 - joy_cube_face >= joy_cube_min,
    str("JOYSTICK: back rib inner edge (", joy_rib_back_y1,
        ") clears the gimbal cube's grown face (", -joy_cube_face,
        ") by only ", -joy_rib_back_y1 - joy_cube_face, "mm."));

assert((joy_hole_front_dy - joy_pilot_d/2) - joy_rib_front_y0 >= joy_pad_min,
    str("JOYSTICK: front bore has only ",
        (joy_hole_front_dy - joy_pilot_d/2) - joy_rib_front_y0,
        "mm of pad inboard -- the rib's inner edge was pushed too far out."));
assert(joy_rib_front_y1 - (joy_hole_front_dy + joy_pilot_d/2) >= joy_pad_min,
    str("JOYSTICK: front bore has only ",
        joy_rib_front_y1 - (joy_hole_front_dy + joy_pilot_d/2),
        "mm of pad outboard (the +17 speaker limit caps this side)."));
assert(joy_rib_back_y1 - (joy_hole_back_dy + joy_pilot_d/2) >= joy_pad_min,
    str("JOYSTICK: back bore has only ",
        joy_rib_back_y1 - (joy_hole_back_dy + joy_pilot_d/2),
        "mm of pad inboard. This is the tightest dimension in the joystick ",
        "mounting -- the back bore is 12.5mm off center and the cube's face ",
        "is at 8.75mm, leaving 3.75mm total for a bore and two walls."));
assert((joy_hole_back_dy - joy_pilot_d/2) - joy_rib_back_y0 >= joy_pad_min,
    str("JOYSTICK: back bore has only ",
        (joy_hole_back_dy - joy_pilot_d/2) - joy_rib_back_y0,
        "mm of pad outboard."));

// The long-edge band must stay out of both ribs entirely -- it is mid-board
// and should never reach them; if it does, the Y mapping was misread.
assert(joy_body_band_y1 + joy_body_tol < joy_rib_front_y0,
    "JOYSTICK: long-edge mass band overlaps the front rib -- re-check the 12-22mm reading.");
assert(joy_body_band_y0 - joy_body_tol > joy_rib_back_y1,
    "JOYSTICK: long-edge mass band overlaps the back rib -- re-check the 12-22mm reading.");
// ---------------------------------------------------------------------------

// The insertion path is vertical, so the cube must fit through the rib gap
// as a channel, not merely rest inside it -- these two are the same
// inequality as the joy_cube_min pair above, restated as the ASSEMBLY note
// depends on them: if either rib inner edge ever moves inboard of the grown
// cube face, the board cannot be lifted into place at all, no matter what
// the carve does.
assert(joy_rib_front_y0 > joy_cube_face && -joy_rib_back_y1 > joy_cube_face,
    "JOYSTICK: rib gap is narrower than the gimbal cube -- the board cannot be lifted into position. See the ASSEMBLY note.");
assert(joy_body_band_y1 + joy_body_tol < joy_rib_front_y0
       && joy_body_band_y0 - joy_body_tol > joy_rib_back_y1,
    "JOYSTICK: the long-edge mass band is not clear of the ribs in Y, so its full width cannot pass vertically.");

// --- SLOT / BORE CLEARANCE (2026-08-27) ------------------------------------
// The slot's X span (-5 .. +7) is not symmetric about the rib, so its two
// ends are not equally clear of the two screw bores at x = +/-joy_hole_dx.
// These are echo()d rather than assert()ed on purpose: the 12mm/7mm figures
// are a direct instruction, and one of the two results is below the 1.5mm
// minimum used everywhere else in this file. Refusing to render would
// override that instruction; saying nothing would hide it.
joy_slot_gap_neg = (-joy_hole_dx + joy_pilot_d/2) - joy_slot_x0;  // -X bore -> slot
joy_slot_gap_pos = (joy_hole_dx - joy_pilot_d/2) - joy_slot_x1;   // +X bore -> slot
echo(str("SLOT: material between slot and -X bore = ", -joy_slot_gap_neg, "mm"));
echo(str("SLOT: material between slot and +X bore = ", joy_slot_gap_pos, "mm"));
if (joy_slot_gap_pos < joy_pad_min)
    echo(str("*** SLOT WARNING: only ", joy_slot_gap_pos,
             "mm between the slot's +X end and the +X screw bore (minimum ",
             "used elsewhere is ", joy_pad_min, "mm). Two fixes that keep ",
             "the slot's 12mm width and its stated purpose: start it 6mm ",
             "from the flat end instead of 7 (gives 1.75mm at BOTH ends), ",
             "or keep the 7mm start and narrow it to 11mm (1.75mm at the ",
             "+X end). Neither moves a screw."));
// ---------------------------------------------------------------------------

// --- Assembly ---
// FIXED 2026-08-25: the relief has to be subtracted from endcap(1) AND
// strips() together, not from endcap(1) alone. strips() spans X all the way
// out to +case_w/2 -- the true exterior face (see its own clipping cube) --
// so relieving only the endcap left the front/shelf/panel/top wall band
// standing 2mm proud of the newly recessed endcap face. From outside that
// reads as a triangular/wedge bite taken out of the endcap (the recess is
// bounded by the diagonal p1-p5 seam yz_half_plane() splits on) instead of
// a uniformly 3mm endcap. Fixed by unioning the two BEFORE the relief cut.
//
// This does NOT thin the strips: endcap_relief() is a full-Y/Z slab, so on
// strips() it only truncates their X *length* by (wall-wall_thin). The
// front/shelf/panel/top walls keep the full 5mm wall thickness and every
// hardware cutout stays exactly where it was (they're placed in each
// segment's own local frame, never in X). Unlike
// pot-side-final.scad there is deliberately no strips_relief()
// here -- see wall_thin's own comment above (the MX clip trench depth is
// hardcoded, not wall-relative).
//
// Consequence to know about: this piece's overall X footprint shrinks by
// (wall-wall_thin)=2mm, exterior face now at case_w/2-2. Everything
// interior-referenced (edge_x, edge_clearance, all 4 mount bosses, the
// joystick harness) is unchanged, and the fan/clearance-hole cutters are
// all long enough in X to still pass through the 3mm endcap -- verified
// against each cutter's own h and center, not assumed.
difference() {
    union() {
        difference() {
            union() {
                endcap(1);
                strips();
            }
            endcap_relief(1);
        }
        blank_side_mount_bosses();
        joystick_plinth();
    }
    hardware_cutouts();
    joystick_plinth_pilot_holes();
    joystick_gimbal_clearance();
    blank_side_mounts();
    blank_side_clearance_holes();
}

module outer_profile() {
    pts = [p0, p1, p2, p3, p4, p5];
    offset(r=6) offset(r=-6) polygon(pts);
}

// Shaves the innermost (wall-wall_thin) slice off the endcap's own
// X-depth -- see pot-side-final.scad's matching module for
// the full derivation, identical here just at side=1 (this piece's own
// +X endcap).
// REVERSED 2026-08-24, direct instruction: removes the OUTERMOST slice
// (nearest the true exterior surface) instead of the innermost one.
// Keeps the endcap's INTERIOR-facing surface exactly where the original,
// un-thinned design has it -- edge_x, every mount-boss's reach, and
// edge_clearance (the 0.15mm gap pot-side's boss is built around) all
// stay correctly aligned with real material, since none of that
// alignment logic changes. Only the exterior surface moves inward.
// Center = case_w/2 - (wall-wall_thin)/2 (was case_w/2-(wall+wall_thin)/2
// for the old, wrong-direction inner cut -- only the sign on the
// wall_thin term flips, same width removed either way).
module endcap_relief(side) {
    translate([side * (case_w/2 - (wall-wall_thin)/2), case_d/2, case_h/2])
    cube([wall - wall_thin, case_d + 80, case_h + 80], center=true);
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
    // seam_margin set to 0 2026-08-22, matching chromacade-pot-side.scad --
    // see that file's comment for the full reasoning (this piece's old
    // value, 3, and pot-side's old value, 1, had drifted apart and were
    // together the real cause of the bottom-front/top-back window, not
    // edge_clearance). Re-verify with the pot-side/blank-side interference
    // check before trusting this in a real print -- the original non-zero
    // margin existed because of a real, previously-confirmed corner-
    // rounding sliver issue, not for no reason.
    seam_margin = 0;
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

// Cooling fan cutout -- side-panel mounted (2026-08-19), one per endcap;
// see chromacade-pot-side.scad's matching fan_cutout() for the full
// rationale (replaces the old back-wall vent concept entirely, real part
// is a 30x30x7mm side fan per hardware-bom.md/enclosure/fan-dimensions.jpg)
// and exact position derivation, including why it's Y=53/Z=35 rather than
// the original Y=48/Z=30 target (centered on the Pi board and blowing
// across the active cooler, per direct instruction) -- that exact target
// would have mostly covered one of pot-side's OWN clearance holes on
// THIS endcap (only 3.3mm clear -- blocking screwdriver access to that
// screw, not just a thin-wall concern) and, symmetrically, one of
// blank-side's owned-mount holes on pot-side's endcap. Same Y,Z as
// pot-side's cutout for a straight cross-case draft, not offset --
// re-verified clear on THIS endcap specifically against pot-side's 4
// owned-mount clearance holes it carries (pot_side_mount_yz below), with
// >=10mm of real margin to each (searched, not guessed).
fan_y = 53;
fan_z = 35;
fan_grille_d     = 26;   // ESTIMATE -- see pot-side.scad's comment
fan_hole_spacing = 24;   // MEASURED, enclosure/fan-dimensions.jpg
fan_pilot_d      = 2.4;  // self-tapping for M2.5

module fan_cutout() {
    translate([case_w/2, fan_y, fan_z])
    rotate([0, 90, 0]) {
        stadium_hex_grill(fan_grille_d, fan_grille_d);
        for (dy = [-fan_hole_spacing/2, fan_hole_spacing/2])
            for (dz = [-fan_hole_spacing/2, fan_hole_spacing/2])
                translate([dy, dz, 0])
                cylinder(h=wall*4, d=fan_pilot_d, center=true);
    }
}

module hardware_cutouts() {
    fan_cutout();

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
        // Joystick (far right in play position = negative X here, confirmed
        // 2026-08-18). 27mm CONFIRMED 2026-08-19 (was 28mm on the original
        // pre-boss print, then 26.5mm -- a tiny bit too small -- before
        // landing on 27mm). Corrected 2026-08-18: this hole (x=-65) was
        // previously mislabeled as the rocker's -- it's the joystick's, per
        // the same correction that moved joy_x below. Now uses joy_x
        // directly instead of a second hardcoded -65 (the two had to stay
        // in sync by hand, exactly the kind of drift-prone duplication
        // this project keeps getting bitten by elsewhere). Y shifted by
        // joy_y_offset -- 2026-08-22, see joy_reserved_front above.
        translate([joy_x, joy_y_offset, 0]) cylinder(h=wall*4, d=joy_stick_d, center=true);
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
