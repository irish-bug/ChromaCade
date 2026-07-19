// chromacade-config.scad
// Shared variables for ChromaCade modules

$fn = 60;

// --- Global Dimensions (Converted from inches) ---
in2mm = 25.4;
case_w = 7    * in2mm;     // 177.8mm
case_d = 4.5  * in2mm;     // 114.3mm
wall   = 5;                // Chunky 5mm walls

front_h = 1.75 * in2mm;   // 44.45mm
shelf_d = 1.5  * in2mm;   // 38.1mm
shelf_a = 8;               // Degrees tilted forward (down towards front)
panel_l = 2.5  * in2mm;   // 63.5mm
panel_a = 45;              // Degrees slope

// Speaker enclosure & cone dims
spk_grille_w = 65;   // grille width
spk_grille_h = 30;   // grille height
spk_cx       = 45;   // speaker centre offset from case centreline

// --- Profile Coordinate Math (Y = depth, Z = height) ---
// Origin is bottom-back (0,0)
p0 = [0, 0];
p1 = [case_d, 0];
p2 = [case_d, front_h];
p3 = [case_d - shelf_d*cos(shelf_a), front_h + shelf_d*sin(shelf_a)];
p4 = [p3[0] - panel_l*cos(panel_a), p3[1] + panel_l*sin(panel_a)];
p5 = [0, p4[1]];

case_h = p4[1];  // Overall height derived from math (~128mm)

// --- Boss Placement Coordinates ---
boss_x     = case_w/2 - wall - 5;
boss_z_top = case_h - wall - 15;
boss_z_bot = wall + 15;
boss_len   = 10;
