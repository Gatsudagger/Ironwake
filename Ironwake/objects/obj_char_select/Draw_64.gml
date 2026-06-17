// =============================================================================
// obj_char_select — Draw GUI event
// Renders the full character selection screen.
// Draw order:
//   1. Background
//   2. Title
//   3. Class panels (three side by side)
//   4. Stat allocation row
//   5. Bottom instruction bar
// =============================================================================

// Lookup arrays used across multiple sections
var _stat_names    = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
var _class_stats   = [arcanist_stats, bloodwarden_stats, shadowstrider_stats];
var _class_sprites = [spr_arcanist, spr_bloodwarden, spr_shadowstrider];

// Panel layout constants
var _panel_w   = 280;
var _panel_h   = 410;
var _panel_gap = 20;
var _panel_y   = 120;
var _panel_x0  = (1280 - (3 * _panel_w + 2 * _panel_gap)) / 2; // = 200


// -----------------------------------------------------------------------------
// 1. BACKGROUND
// -----------------------------------------------------------------------------
draw_set_color(make_color_rgb(18, 18, 28));
draw_rectangle(0, 0, 1280, 720, false);


// -----------------------------------------------------------------------------
// 2. TITLE
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// "IRONWAKE" — fake bold via 1px shadow
draw_set_color(make_color_rgb(40, 80, 120));
draw_text_transformed(641, 41, "IRONWAKE", 2.5, 2.5, 0);
draw_set_color(make_color_rgb(120, 190, 255));
draw_text_transformed(640, 40, "IRONWAKE", 2.5, 2.5, 0);

// Subtitle
draw_set_color(c_gray);
draw_text(640, 82, "Choose Your Class");


// -----------------------------------------------------------------------------
// 3. CLASS PANELS
// -----------------------------------------------------------------------------
for (var _i = 0; _i < 3; _i++) {

    var _px      = _panel_x0 + _i * (_panel_w + _panel_gap);
    var _py      = _panel_y;
    var _is_sel  = (_i == selected_class);

    // --- Panel background ---
    if (_is_sel) {
        draw_set_color(make_color_rgb(30, 40, 60));
    } else {
        draw_set_color(make_color_rgb(20, 25, 35));
    }
    draw_rectangle(_px, _py, _px + _panel_w, _py + _panel_h, false);

    // --- Panel border ---
    if (_is_sel) {
        draw_set_color(make_color_rgb(80, 160, 220));
    } else {
        draw_set_color(c_gray);
    }
    draw_rectangle(_px, _py, _px + _panel_w, _py + _panel_h, true);

    // --- Class name ---
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    if (_is_sel) {
        draw_set_color(make_color_rgb(40, 90, 130));
        draw_text(_px + _panel_w / 2 + 1, _py + 16 + 1, class_names[_i]);
        draw_set_color(make_color_rgb(120, 200, 255));
    } else {
        draw_set_color(make_color_rgb(140, 150, 160));
    }
    draw_text(_px + _panel_w / 2, _py + 16, class_names[_i]);

    // --- Class sprite preview (between name and description) ---
    var _spr    = _class_sprites[_i];
    var _spr_cx = _px + _panel_w / 2;
    var _spr_cy = _py + 70;
    draw_sprite_ext(_spr, 0, _spr_cx, _spr_cy, 1.0, 1.0, 0, c_white, (_is_sel ? 1.0 : 0.5));

    // --- Class description ---
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(160, 165, 175));
    draw_text_ext(_px + 12, _py + 160, class_descriptions[_i], 20, _panel_w - 24);

    // --- Stat block ---
    // Show working_stats for the selected class, preset for the others
    var _display_stats = (_is_sel) ? working_stats : _class_stats[_i];
    var _cx            = _px + _panel_w / 2;

    var _stat_block_y  = _py + 265;
    var _stat_line_h   = 20;

    for (var _s = 0; _s < 6; _s++) {
        var _stat_val  = variable_struct_get(_display_stats, _stat_names[_s]);
        var _stat_text = _stat_names[_s] + ": " + string(_stat_val);

        // Highlight the selected stat row when this is the active panel
        if (_is_sel && _s == selected_stat) {
            draw_set_color(make_color_rgb(255, 220, 60));
        } else if (_is_sel) {
            draw_set_color(c_white);
        } else {
            draw_set_color(make_color_rgb(110, 115, 125));
        }

        draw_text(_cx, _stat_block_y + _s * _stat_line_h, _stat_text);
    }

    // --- "SELECTED" indicator at panel bottom ---
    if (_is_sel) {
        draw_set_color(make_color_rgb(80, 160, 220));
        draw_text(_cx, _py + _panel_h - 18, "[ SELECTED ]");
    }
}

// Restore left-align for remaining sections
draw_set_halign(fa_center);
draw_set_valign(fa_middle);


// -----------------------------------------------------------------------------
// 4. STAT ALLOCATION ROW
// Displayed below the class panels — shows free points and the 6 stats.
// -----------------------------------------------------------------------------
var _alloc_y   = 540;
var _alloc_cx  = 640;

// "Free Points" label
var _fp_color = (free_points > 0) ? make_color_rgb(255, 220, 60) : c_green;
draw_set_color(_fp_color);
draw_text(_alloc_cx, _alloc_y, "Free Points: " + string(free_points));

// Six stat boxes in a row centered on screen
var _box_w     = 80;
var _box_h     = 52;
var _box_gap   = 10;
var _row_total = 6 * _box_w + 5 * _box_gap;
var _row_x0    = (_alloc_cx) - (_row_total / 2);
var _box_y     = _alloc_y + 22;

for (var _s = 0; _s < 6; _s++) {
    var _bx      = _row_x0 + _s * (_box_w + _box_gap);
    var _is_hlt  = (_s == selected_stat);
    var _stat_v  = variable_struct_get(working_stats, _stat_names[_s]);

    // Box fill
    if (_is_hlt) {
        draw_set_color(make_color_rgb(50, 55, 80));
    } else {
        draw_set_color(make_color_rgb(25, 28, 42));
    }
    draw_rectangle(_bx, _box_y, _bx + _box_w, _box_y + _box_h, false);

    // Box border
    if (_is_hlt) {
        draw_set_color(make_color_rgb(255, 220, 60));
    } else {
        draw_set_color(c_gray);
    }
    draw_rectangle(_bx, _box_y, _bx + _box_w, _box_y + _box_h, true);

    // Stat label — top of box with padding
    draw_set_color((_is_hlt) ? make_color_rgb(255, 220, 60) : make_color_rgb(160, 165, 175));
    draw_text(_bx + _box_w / 2, _box_y + 10, _stat_names[_s]);

    // Stat value — 4px gap below label, centered in lower half
    draw_set_color(c_white);
    draw_text(_bx + _box_w / 2, _box_y + 10 + 18 + 4, string(_stat_v));
}

// Allocation key hints below the stat boxes
draw_set_color(make_color_rgb(140, 145, 155));
draw_text(_alloc_cx, _box_y + _box_h + 14, "Z / Enter: Add point        X: Remove point");


// -----------------------------------------------------------------------------
// 5. BOTTOM INSTRUCTION BAR
// -----------------------------------------------------------------------------
var _inst_y = 680;

// Navigation hint
draw_set_color(make_color_rgb(130, 135, 145));
draw_text(640, _inst_y, "A / D: Select Class       W / S: Select Stat       Space: Confirm");

// Readiness prompt
if (free_points > 0) {
    draw_set_color(c_yellow);
    draw_text(640, _inst_y + 22, "Allocate all points before confirming");
} else {
    draw_set_color(c_green);
    draw_text(640, _inst_y + 22, "Ready!  Press Space to begin");
}

// -----------------------------------------------------------------------------
// 6. NAME ENTRY OVERLAY
// Shown after Space is pressed with all points allocated.
// -----------------------------------------------------------------------------
if (naming_active) {
    // Dark overlay
    draw_set_alpha(0.88);
    draw_set_color(make_color_rgb(8, 10, 20));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(make_color_rgb(120, 190, 255));
    draw_text_transformed(640, 270, "Name Your Hero", 2.0, 2.0, 0);

    // Input box
    var _box_x = 390;
    var _box_y = 320;
    var _box_w = 500;
    var _box_h = 52;

    draw_set_color(make_color_rgb(22, 28, 48));
    draw_rectangle(_box_x, _box_y, _box_x + _box_w, _box_y + _box_h, false);
    draw_set_color(make_color_rgb(80, 150, 220));
    draw_rectangle(_box_x, _box_y, _box_x + _box_w, _box_y + _box_h, true);

    // Typed text + blinking cursor
    var _cursor = ((current_time mod 1000) < 500) ? "|" : "";
    var _display_name = keyboard_string + _cursor;
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_text(_box_x + 14, _box_y + _box_h / 2, _display_name);

    // Hints
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(130, 135, 145));
    draw_text(640, 398, "Enter to confirm       Escape to go back");
}


// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);
draw_set_color(c_white);
