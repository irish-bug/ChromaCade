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
// 17mm deep, MEASURED against the real part). Two of these, same
// spk_cx=45 spacing (90mm apart) as the original design -- that spacing
// was already established and never itself the problem.
//
// Grille is a portrait stadium (pill) matched exactly to the cone area,
// not the full 70x31mm mounting plate (the plate's own extent matters
// for depth clearance -- see the speaker-body clearance check in
// hardware_cutouts() below -- not for the visible grille cut, which only
// needs to expose the actual driver); rotated 90° at the cut site to sit
// landscape on the (landscape) front wall enclosure.
spk_grille_w = 1.0 * in2mm;  // 25.4mm = 1"   (stadium width  = cone width)
spk_grille_h = 1.5 * in2mm;  // 38.1mm = 1.5" (stadium height = cone height)
spk_cx       = 45;

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
boss_w    = 12;
boss_body = 14;
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
own_mount_boss_centers = [
    [114.73, 12],
    [114.73, 42],
    [44.447, 63.556],
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
// real wall_y/wall_z); panel_top goes through panel_mount_boss() (local
// frame, rotated) instead -- see both modules' own comments. shelf_panel
// removed 2026-08-19 (see own_mount_boss_centers' comment).
module blank_side_mount_bosses() {
    flat_mount_boss(own_mount_boss_centers[0][1], "y", wall_y=case_d-wall); // front_bottom
    flat_mount_boss(own_mount_boss_centers[1][1], "y", wall_y=case_d-wall); // front_top
    panel_mount_boss(15); // panel_top (tilted joint, panel's own frame, local y=15 -- in line with the note keys)
    flat_mount_boss(own_mount_boss_centers[3][0], "z", wall_z=case_h-wall); // top_back
}

module blank_side_mounts() {
    for (yz = own_mount_boss_centers) {
        // Bore centered on the boss, not the bare-wall own_mount_yz point.
        translate([edge_x, yz[0], yz[1]]) rotate([0, 90, 0]) cylinder(h=engage, d=pilot_d);
    }
}

// Gap-blocking bridges -- flagged 2026-08-20/21 as a toddler-safety
// issue, not just a cosmetic seam: the 0.15mm edge_clearance gap between
// this piece's strips and the OTHER piece's endcap (see edge_clearance's
// own comment for why the gap exists at all) is a straight-through slot
// running exterior-to-interior. Confirmed via the real-geometry
// interference check (translating this piece's actual rendered geometry
// toward pot-side and re-checking, not hand-derived coordinates): real
// margin against pot-side's actual, already-printed geometry is under
// 1mm at BOTH seam ends, not the ~3mm first (wrongly) claimed.
//
// pot-side is already printed and can't change, so this piece has to
// close the gap alone. Only front_bottom's and top_back's zones are
// covered here -- the front-wall/top-segment seam continues past these
// two localized bridges (matching the two zones actually flagged live,
// where blank-side's strips meet pot-side's endcap near the p1/p5
// corners), not the WHOLE seam length or the separate back-wall/bottom-
// floor seam near this piece's own endcap (a different, independently-
// found gap -- not yet fixed, flagged separately, not in scope here).
//
// Three real bugs found getting this design right, each caught by the
// real-geometry interference check before committing to a print rather
// than by reasoning alone -- worth keeping the history, this is not a
// simple shape:
//   1. First attempt reached toward pot-side but INSET from the wall
//      surface, on the assumption pot-side's endcap is a hollow wall-
//      profile shape with clear space behind it. Checked shell_solid()'s
//      actual definition instead of continuing to assume -- it's a
//      difference() between the full-case_w outer profile and the SAME
//      profile inset by wall, extruded only case_w-2*wall (centered), so
//      the inner cavity stops `wall` short of BOTH ends -- the endcap
//      zone is SOLID across its whole profile, not hollow. No clear
//      interior space to reach into at that X range at all.
//   2. Second attempt went OUTSIDE the wall surface instead (correct
//      general direction) but used one flat rectangle whose near edge
//      dipped a couple mm INTO the wall, across its FULL X-range, to
//      physically anchor to this piece's own material. Collided anyway,
//      for two independent reasons: outer_profile()'s offset(r=6)
//      offset(r=-6) corner rounding pulls the true wall surface INWARD
//      approaching the p1/p5 corners (confirmed empirically: front
//      wall's real Y drops from 125.73 at Z=6 down to ~124 by Z=2), AND
//      pot-side's endcap is solid clear through its own X range (see
//      bug 1) -- so any point below the true wall surface is inside
//      pot-side's material for X in [-97.79,-92.79], corner or not.
//   3. Fixed by splitting each bridge into two pieces: an anchor,
//      confined to X well clear of pot-side's real edge, which is the
//      only part allowed to dip below the wall surface; and a bridge
//      piece, which crosses into pot-side's X range but never dips below
//      the true surface (Y=case_d or Z=case_h exactly) regardless of X.
//      First version of the split still failed ("Simple: no", non-
//      manifold) because the two pieces only shared a single edge/face,
//      not a real volume -- CSG union needs genuine 3D overlap, not a
//      touch. Fixed by giving them real overlap in both X and Y-or-Z.
gap_bridge_x_far   = -99; // ~1.2mm past pot-side's endcap outer face (-97.79)
gap_bridge_x_near  = -87; // bridge's near edge, well into this piece's own
                           // territory -- safe this far in since the
                           // bridge never dips below the true wall surface
gap_bridge_proud   = 3;   // how far past the true wall surface it stands
gap_anchor_x_far   = -90; // anchor's far edge -- clear of pot-side's real
                           // edge (-92.79) by 2.79mm
gap_anchor_x_near  = -85; // matches nothing in particular, just comfortably
                           // within this piece's own solid front-wall/top area
// Overlap between the two pieces: X=[-90,-87] (3mm, anchor_x_far to
// bridge_x_near) and Y-or-Z=[case_d or case_h, +1] (1mm, anchor reaches
// 1mm past the surface where bridge already lives) -- real volume, not
// a shared face.

module gap_lip_front_bottom() {
    // Anchor: dips into the wall (Y=[124.5, case_d+1]) but only across
    // X=[-90,-85], entirely this piece's own territory.
    translate([(gap_anchor_x_near + gap_anchor_x_far)/2, (124.5 + case_d + 1)/2, 18])
    cube([gap_anchor_x_near - gap_anchor_x_far, (case_d + 1) - 124.5, 20], center=true);
    // Bridge: crosses to pot-side's side (X to -99) but stays at or
    // above the true wall surface (Y>=case_d) the whole way.
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

// Sphere radius (27mm diameter, matching joy_stick_d), centered on the
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

// Plain vertical cylinders -- no taper/wedge. Matches exactly what was
// physically printed and confirmed to fit (a4f6a10); the two abandoned
// intermediate redesigns both added print-support machinery this post
// shape never actually needed (see joystick-mount-dev.scad).
module joystick_mount_bosses() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, joy_y_offset, 0])
    for (p = joystick_boss_xy())
        translate([p[0], p[1], -wall - joy_boss_h])
        cylinder(h = joy_boss_h + 0.5, d = joy_boss_d);
}

module joystick_mount_pilot_holes() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, joy_y_offset, 0])
    for (p = joystick_boss_xy())
        translate([p[0], p[1], -wall - joy_boss_h - 0.5])
        cylinder(h = joy_boss_h + 1, d = joy_pilot_d);
}

module joystick_gimbal_clearance() {
    shelf_my = (p2[0] + p3[0]) / 2;
    shelf_mz = (p2[1] + p3[1]) / 2;
    translate([0, shelf_my, shelf_mz])
    rotate([-shelf_a, 0, 0])
    translate([joy_x, joy_y_offset, -wall/2])
    sphere(r = joy_gimbal_r);
}

// --- Assembly ---
difference() {
    union() {
        endcap(1);
        strips();
        blank_side_mount_bosses();
        joystick_mount_bosses();
        gap_lip_front_bottom();
        gap_lip_top_back();
    }
    hardware_cutouts();
    joystick_mount_pilot_holes();
    joystick_gimbal_clearance();
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
