// ChromaCade Synthesizer - Main Housing (wordmark-embossed variant)
// Same as chromacade-housing.scad, plus a raised "ChromaCade" wordmark on the
// panel exterior, centered in the gap between the OLED and LED ring. Kept as
// a separate standalone file rather than a toggle in chromacade-housing.scad,
// matching this repo's file-per-variant convention (see decision-log.md).
// Requires the Comfortaa font (Debian/Ubuntu: `sudo apt install fonts-comfortaa`) —
// falls back to a default system font if missing, which will look different.
$fn = 60;

// --- Global Dimensions ---
in2mm = 25.4;
case_w = 7    * in2mm;
case_d = 4.5  * in2mm;
wall   = 5;

front_h = 1.75 * in2mm;
shelf_d = 1.5  * in2mm;
shelf_a = 8;
panel_l = 2.5  * in2mm;
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

boss_x     = case_w/2 - wall - 5;
boss_z_top = case_h - wall - 15;
boss_z_bot = wall + 15;
boss_len   = 10;

// Center top/bottom bosses (back-panel anti-bowing support). Unlike boss_z_top/
// boss_z_bot above, these aren't inset for X-flush contact with a side wall —
// there's no side wall at x=0. Instead they're offset 5mm in from the ceiling/
// floor's inner surface so the *square* boss (see mounting_boss) sits Z-flush
// against the ceiling/floor. (A previous attempt reused boss_z_top/boss_z_bot
// unchanged at x=0, which touched nothing on any side — floating, unprintable.)
boss_z_top_ctr = case_h - wall - 5;
boss_z_bot_ctr = wall + 5;

// "ChromaCade" wordmark outline, embedded directly rather than import()-ed from
// ChromaCade-wordmark-paths.svg (kept in-repo as the source asset — regenerate
// this block from it if the wordmark design changes). Embedding keeps this file
// a true standalone single file needing no external file access at render time:
// import() requires OpenSCAD to read a second local file, which on at least one
// sandboxed/Snap install prompts for filesystem permission — easy to decline
// without realizing it's what's silently breaking the emboss. The source SVG's
// paths are already flattened to straight line segments (no curves), so this
// conversion is exact, not an approximation. One evenodd polygon per letter;
// letters with a counter (o/a/a/d/e) contribute an outer contour + a hole contour.
// Rotated 180 degrees from the raw SVG data (negate both X and Y) — not just a
// Y-flip. Verified against a camera aimed straight down the panel's own outward
// normal, cross-checked with the user's real-world description (LED ring on
// their left, OLED on their right, note buttons below this row): a plain
// Y-flip left the word upside down *and* reading backwards (OLED-to-LED).
// A full 180-degree rotation is required to get both letter-bottoms toward the
// note row and LED-to-OLED reading order while keeping letters non-mirrored.
wordmark_points = [
    [-261,103.5],[-271.5,104],[-277.5,106.5],[-282.5,111],[-282,114.5],[-280,116.5],[-277,117],[-272,113],[-267,111],[-259.5,111],[-251,114],[-246,117.5],[-238,127],[-235,135],[-235,145],[-237.5,150.5],[-241.5,154.5],[-245.5,156.5],[-255,157],[-267,151.5],[-270.5,151.5],[-272,154.5],[-270,158],[-258.5,163.5],[-254,164.5],[-242.5,164],[-235,160.5],[-230.5,156],[-228,151.5],[-226.5,146],[-226.5,138],[-228.5,130],[-232.5,122],[-241.5,112],[-251.5,106],[-261,103.5], // 'C' outer
    [-619,103.5],[-626.5,103.5],[-634.5,106],[-640,110.5],[-639.5,115],[-634.5,117],[-629,112.5],[-624.5,111],[-617,111],[-608,114.5],[-601,120],[-595.5,127.5],[-592.5,136.5],[-592.5,144],[-596.5,152],[-603.5,156.5],[-612.5,157],[-619,155],[-625,151.5],[-628.5,151.5],[-629.5,155.5],[-625.5,159.5],[-614.5,164],[-602.5,164.5],[-598.5,163.5],[-592,160],[-586,152],[-584,140.5],[-586.5,129.5],[-591,121],[-600,111.5],[-610.5,105.5],[-619,103.5], // 'h' outer
    [-759.5,103.5],[-765.5,105],[-767,107],[-767,110.5],[-762.5,114.5],[-754,116.5],[-747,145],[-742,154],[-734.5,160.5],[-727.5,163.5],[-717,164],[-709.5,160.5],[-705,153.5],[-704.5,145.5],[-706.5,138.5],[-712,130],[-722,123],[-730,121.5],[-736,122.5],[-743,127.5],[-749,106],[-751,104.5],[-759.5,103.5], // 'r' outer
    [-729,129.5],[-733.5,130],[-738,133.5],[-739.5,137.5],[-738.5,144.5],[-735,150.5],[-731,154],[-726,156],[-719.5,156],[-716.5,154.5],[-713.5,150],[-714.5,140.5],[-719,134],[-724.5,130.5],[-729,129.5], // 'r' hole
    [-674,121.5],[-683,123.5],[-686.5,126],[-690,131.5],[-690.5,142],[-686,160],[-682,164],[-678,162.5],[-677.5,158.5],[-668.5,163.5],[-656.5,163.5],[-651,160],[-647.5,153.5],[-647,147],[-649,139],[-652.5,133],[-658.5,127],[-664.5,123.5],[-674,121.5], // 'o' outer
    [-672,129.5],[-676,130],[-681,134],[-682,136.5],[-681,145],[-674.5,153.5],[-669,156],[-661,155.5],[-657,152],[-656,149],[-657,141],[-663.5,132.5],[-672,129.5], // 'o' hole
    [-790.5,121.5],[-797,122.5],[-803.5,127.5],[-805.5,134],[-804,144],[-800,146],[-772,146],[-771.5,150],[-773,153],[-778.5,157],[-784,157.5],[-796,153.5],[-797.5,154.5],[-798,157.5],[-795,160.5],[-785,164],[-777,164],[-772,162.5],[-766.5,158],[-764.5,154],[-764,145],[-765.5,139.5],[-769,133],[-775.5,126.5],[-782,123],[-790.5,121.5], // 'm' outer
    [-785.5,129.5],[-792,129.5],[-794,130.5],[-797,134.5],[-797,138.5],[-774.5,138.5],[-778.5,133],[-785.5,129.5], // 'm' hole
    [-306,104],[-308.5,105],[-309,109],[-305,125],[-306,125.5],[-313.5,122],[-320.5,121.5],[-328.5,124.5],[-332.5,130.5],[-332.5,140],[-327.5,160],[-323.5,164],[-321,164],[-319,160],[-324,141.5],[-324.5,135],[-322,131],[-317.5,129],[-310.5,129.5],[-303,135],[-295.5,161.5],[-292.5,164],[-290,164],[-288,162.5],[-288,159],[-300.5,109],[-303,105],[-306,104], // 'a' outer
    [-373,121.5],[-382,122.5],[-384,125],[-383.5,127],[-380.5,129.5],[-373.5,128.5],[-367.5,129.5],[-361.5,133.5],[-359.5,137],[-354,160.5],[-351.5,163.5],[-347.5,164],[-345.5,161],[-355,124],[-358,122],[-361,122],[-363.5,126],[-367,123.5],[-373,121.5], // 'C' outer
    [-414,121.5],[-423,122],[-430.5,126.5],[-434,133.5],[-433,145],[-429,153],[-421,160.5],[-412.5,164],[-401.5,164],[-396,161.5],[-391,155],[-390,151.5],[-391,141.5],[-395.5,132.5],[-401,127],[-407,123.5],[-414,121.5], // 'a' outer
    [-413.5,129.5],[-419.5,130],[-424,133.5],[-425,135.5],[-424,145.5],[-421.5,150],[-414,155.5],[-409.5,156.5],[-403.5,155.5],[-400.5,153],[-399,149.5],[-400,141],[-404.5,134],[-413.5,129.5], // 'a' hole
    [-473.5,121.5],[-480,122.5],[-485,127],[-491.5,123],[-498.5,121.5],[-505,122.5],[-509.5,126],[-511,130],[-511,136],[-505.5,158.5],[-502.5,163.5],[-499,164],[-496.5,161],[-502.5,138],[-502.5,132.5],[-498.5,129],[-491.5,130],[-486,135.5],[-479.5,161],[-478,163],[-473.5,164],[-471.5,162],[-477.5,136.5],[-477,132],[-473,129],[-467.5,129.5],[-462,133.5],[-459,140],[-453.5,162],[-450.5,164],[-446.5,163],[-446,160],[-455.5,124],[-460.5,122],[-464,125],[-468,122.5],[-473.5,121.5], // 'd' outer
    [-551.5,121.5],[-561.5,124],[-565.5,127.5],[-568,132.5],[-568.5,140.5],[-563.5,160.5],[-560,164],[-557.5,164],[-555.5,162.5],[-555,158.5],[-551,161.5],[-544,164],[-533,163],[-527.5,158.5],[-525,153],[-525,144.5],[-526.5,139.5],[-530.5,132.5],[-537.5,126],[-545,122.5],[-551.5,121.5], // 'e' outer
    [-548.5,129.5],[-554,130],[-558.5,133.5],[-559.5,136],[-558.5,145.5],[-556,150],[-550.5,154.5],[-544,156.5],[-538.5,155.5],[-534,150.5],[-533.5,145],[-534.5,141],[-540.5,133],[-548.5,129.5], // 'e' hole
];
wordmark_paths = [
    [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35], // 'C'
    [36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68], // 'h'
    [69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91], [92,93,94,95,96,97,98,99,100,101,102,103,104,105,106], // 'r'
    [107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125], [126,127,128,129,130,131,132,133,134,135,136,137,138], // 'o'
    [139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164], [165,166,167,168,169,170,171,172], // 'm'
    [173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200], // 'a'
    [201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219], // 'C'
    [220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236], [237,238,239,240,241,242,243,244,245,246,247,248,249,250], // 'a'
    [251,252,253,254,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,281,282,283,284,285,286,287], // 'd'
    [288,289,290,291,292,293,294,295,296,297,298,299,300,301,302,303,304,305,306,307,308], [309,310,311,312,313,314,315,316,317,318,319,320,321,322], // 'e'
];

// --- Assembly ---
union() {
    difference() {
        main_chassis();
        hardware_cutouts();
    }
    wordmark_emboss();
}

module main_chassis() {
    difference() {
        color("ivory")
        rotate([90, 0, 90])
        linear_extrude(case_w, center=true)
        outer_profile();

        rotate([90, 0, 90])
        linear_extrude(case_w - (wall * 2), center=true)
        offset(delta = -wall) outer_profile();

        back_hole();
    }

    translate([boss_x, wall, 0]) {
        translate([0, 0, boss_z_top]) rotate([-90, 0, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot]) rotate([-90, 0, 0]) mounting_boss(boss_len);
    }
    translate([-boss_x, wall, 0]) {
        translate([0, 0, boss_z_top]) rotate([-90, 0, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot]) rotate([-90, 0, 0]) mounting_boss(boss_len);
    }
    translate([0, wall, 0]) {
        translate([0, 0, boss_z_top_ctr]) rotate([-90, 0, 0]) mounting_boss(boss_len);
        translate([0, 0, boss_z_bot_ctr]) rotate([-90, 0, 0]) mounting_boss(boss_len);
    }
}

module outer_profile() {
    pts = [p0, p1, p2, p3, p4, p5];
    offset(r=6) offset(r=-6) polygon(pts);
}

module back_hole() {
    w = case_w - wall*2;
    h = case_h - wall*2;
    translate([0, 0, case_h/2])
    rotate([90, 0, 0])
    linear_extrude(wall * 3, center=true)
    offset(r=3) offset(r=-3) square([w, h], center=true);
}

module mounting_boss(len) {
    // Square cross-section (not round) so the boss meets the side wall on a
    // flush 10x10mm face instead of being tangent to it along a single line —
    // a round boss here only ever line-contacts the flat wall, which is a weak
    // bond and a real risk of a barely-fused, snap-off connection when printed.
    difference() {
        translate([-5, -5, 0]) cube([10, 10, len]);
        translate([0, 0, -1])
        cylinder(h=len+2, d=3, center=false);
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

    translate([-case_w/2, case_d/3, case_h/1.5])
    rotate([0, 90, 0])
    cylinder(h=wall*4, d=8, center=true);
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

module wordmark_emboss() {
    // Raised "ChromaCade" wordmark on the panel exterior (local z=0 is the
    // outer face in this frame — see the interior-face recesses above, all
    // negative z), centered in the gap between the OLED cutout (x=-60, right
    // edge -46) and LED ring cutout (x=65, left edge 53): (-46+53)/2 = 3.5.
    // Uses the real traced bold-italic outline (wordmark_points/wordmark_paths
    // above, converted from ChromaCade-wordmark-paths.svg) rather than
    // reconstructing it via text() — an earlier text()-based version printed in
    // a plain, non-bold, non-italic font because Comfortaa wasn't installed on
    // the machine that actually rendered/sliced it. Embedded as literal polygon
    // data rather than import()-ing the SVG at render time, to keep this file
    // fully standalone (see the comment above wordmark_points for why).
    // Note: the source SVG has no glyph for the wordmark's music-note flourish —
    // still missing here.
    // The raw path data measures 579x61 units, center (516,134); scaled down to
    // fit the ~95mm-wide gap without reaching the note-button row above.
    emboss_h  = 1;
    embed     = 0.3; // sinks the letters' base 0.3mm into the wall so the union
                      // is a true volumetric overlap, not a coplanar face-touch
                      // (a flush z=0 base produced 10 near-disconnected letters —
                      // same failure mode as the tangent-boss bug, just for glyphs)
    src_w  = 579;
    src_cx = -516;
    src_cy = 134;
    s      = 84 / src_w;

    panel_my = (p3[0] + p4[0]) / 2;
    panel_mz = (p3[1] + p4[1]) / 2;
    translate([0, panel_my, panel_mz])
    rotate([-panel_a, 0, 0])
    translate([3.5, -15, -embed])
    linear_extrude(emboss_h + embed)
    scale([s, s, 1])
    translate([-src_cx, -src_cy, 0])
    polygon(points = wordmark_points, paths = wordmark_paths);
}
