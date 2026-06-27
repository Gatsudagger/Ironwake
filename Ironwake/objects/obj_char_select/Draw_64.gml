// =============================================================================
// obj_char_select - Draw GUI event
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
var _panel_w   = 516;
var _panel_h   = 615;
var _panel_gap = 36;
var _panel_y   = 174;
var _panel_x0  = (GUI_W - (3 * _panel_w + 2 * _panel_gap)) / 2; // = 150


// -----------------------------------------------------------------------------
// 1. BACKGROUND
// -----------------------------------------------------------------------------
draw_set_color(make_color_rgb(18, 18, 28));
draw_rectangle(0, 0, GUI_W, GUI_H, false);


// -----------------------------------------------------------------------------
// 2. TITLE
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// "IRONWAKE" - fake bold via shadow
draw_set_font(fnt_ui_title);
draw_set_color(make_color_rgb(40, 80, 120));
draw_text(962, 62, "IRONWAKE");
draw_set_color(make_color_rgb(120, 190, 255));
draw_text(960, 60, "IRONWAKE");

// Subtitle
draw_set_font(fnt_ui);
draw_set_color(c_gray);
draw_text(960, 123, "Choose Your Class");


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
    draw_set_font(fnt_ui);
    if (_is_sel) {
        draw_set_color(make_color_rgb(40, 90, 130));
        draw_text(_px + _panel_w / 2 + 2, _py + 24 + 2, class_names[_i]);
        draw_set_color(make_color_rgb(120, 200, 255));
    } else {
        draw_set_color(make_color_rgb(140, 150, 160));
    }
    draw_text(_px + _panel_w / 2, _py + 24, class_names[_i]);

    // --- Class sprite preview (between name and description) ---
    // IMPORTANT: these PixelLab sprites have a TOP-LEFT origin (xorigin/yorigin = 0
    // in the .yy), so draw_sprite_ext at (x,y) puts the CORNER there. To centre a
    // sprite on a point we offset by half its scaled size (sprite_get_width/height
    // works for any sprite regardless of origin, and adapts to 92 vs 96 px art).
    var _spr    = _class_sprites[_i];
    var _spr_cx = _px + _panel_w / 2;
    if (_is_sel) {
        // Gender selector: both class sprites side by side (Male / Female), the
        // chosen one lit in a highlight cell and the other dimmed, with a label
        // under each. The "Q / E: Gender" hint lives in the bottom instruction bar,
        // so nothing else is crammed into the panel here.
        var _fnames = ["spr_arcanist_f", "spr_bloodwarden_f", "spr_shadowstrider_f"];
        var _fspr   = asset_get_index(_fnames[_i]);
        var _m_on   = (selected_gender == "m");
        var _gtarget = 150;                 // target DISPLAY height - normalises male
                                            // (92px) and female (104-108px) to one size
        var _cellhw = 87;                   // highlight cell half-size
        var _gy     = _py + 147;            // sprite centre line
        var _mx     = _spr_cx - 105;        // male option centre
        var _fx     = _spr_cx + 105;        // female option centre

        // Highlight cell behind the chosen option (fill + border)
        var _selx = _m_on ? _mx : _fx;
        draw_set_color(make_color_rgb(34, 48, 72));
        draw_rectangle(_selx - _cellhw, _gy - _cellhw, _selx + _cellhw, _gy + _cellhw, false);
        draw_set_color(make_color_rgb(255, 220, 120));
        draw_rectangle(_selx - _cellhw, _gy - _cellhw, _selx + _cellhw, _gy + _cellhw, true);

        // Male sprite - scaled to the target height (so different canvas sizes match)
        // and centred via top-left origin compensation. The unselected gender stays
        // clearly visible (dimmed only slightly) so you can compare both.
        var _msc = _gtarget / sprite_get_height(_spr);
        var _msw = sprite_get_width(_spr)  * _msc;
        var _msh = sprite_get_height(_spr) * _msc;
        draw_sprite_ext(_spr, 0, _mx - _msw / 2, _gy - _msh / 2, _msc, _msc, 0, c_white, _m_on ? 1.0 : 0.62);

        // Female sprite - graceful placeholder if the art hasn't been imported yet
        if (_fspr != -1 && sprite_exists(_fspr)) {
            var _fsc = _gtarget / sprite_get_height(_fspr);
            var _fsw = sprite_get_width(_fspr)  * _fsc;
            var _fsh = sprite_get_height(_fspr) * _fsc;
            draw_sprite_ext(_fspr, 0, _fx - _fsw / 2, _gy - _fsh / 2, _fsc, _fsc, 0, c_white, _m_on ? 0.62 : 1.0);
        } else {
            draw_set_color(make_color_rgb(40, 46, 62));
            draw_rectangle(_fx - _cellhw + 6, _gy - _cellhw + 6, _fx + _cellhw - 6, _gy + _cellhw - 6, false);
            draw_set_halign(fa_center); draw_set_valign(fa_middle);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(140, 150, 170));
            draw_text(_fx, _gy - 12, "Female");
            draw_set_color(make_color_rgb(90, 100, 120));
            draw_text(_fx, _gy + 18, "(loading)");
        }

        // Labels under each option
        draw_set_halign(fa_center); draw_set_valign(fa_top);
        draw_set_font(fnt_ui_small);
        draw_set_color(_m_on ? make_color_rgb(255, 220, 120) : make_color_rgb(120, 125, 140));
        draw_text(_mx, _gy + _cellhw + 12, "Male");
        draw_set_color(_m_on ? make_color_rgb(120, 125, 140) : make_color_rgb(255, 220, 120));
        draw_text(_fx, _gy + _cellhw + 12, "Female");
    } else {
        // Single preview, centred and enlarged - scaled to a target display height
        var _ucy = _py + 156;
        var _usc = 192 / sprite_get_height(_spr);
        var _usw = sprite_get_width(_spr)  * _usc;
        var _ush = sprite_get_height(_spr) * _usc;
        draw_sprite_ext(_spr, 0, _spr_cx - _usw / 2, _ucy - _ush / 2, _usc, _usc, 0, c_white, 0.55);
    }

    // --- Class description ---
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(160, 165, 175));
    draw_text_ext(_px + 21, _py + 282, class_descriptions[_i], -1, _panel_w - 42);

    // --- Stat block ---
    // Show working_stats for the selected class, preset for the others
    var _display_stats = (_is_sel) ? working_stats : _class_stats[_i];
    var _cx            = _px + _panel_w / 2;

    var _stat_block_y  = _py + 408;
    var _stat_line_h   = 30;

    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
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
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(80, 160, 220));
        draw_text(_cx, _py + _panel_h - 27, "[ SELECTED ]");
    }
}

// Restore left-align for remaining sections
draw_set_halign(fa_center);
draw_set_valign(fa_middle);


// -----------------------------------------------------------------------------
// 4. STAT ALLOCATION ROW
// Displayed below the class panels - shows free points and the 6 stats.
// -----------------------------------------------------------------------------
var _alloc_y   = 810;
var _alloc_cx  = GUI_CX;

// "Free Points" label
draw_set_font(fnt_ui);
var _fp_color = (free_points > 0) ? make_color_rgb(255, 220, 60) : c_green;
draw_set_color(_fp_color);
draw_text(_alloc_cx, _alloc_y, "Free Points: " + string(free_points));

// Six stat boxes in a row centered on screen
var _box_w     = 120;
var _box_h     = 78;
var _box_gap   = 15;
var _row_total = 6 * _box_w + 5 * _box_gap;
var _row_x0    = (_alloc_cx) - (_row_total / 2);   // = 562.5
var _box_y     = _alloc_y + 33;

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

    // Stat label - top of box with padding
    draw_set_font(fnt_ui_small);
    draw_set_color((_is_hlt) ? make_color_rgb(255, 220, 60) : make_color_rgb(160, 165, 175));
    draw_text(_bx + _box_w / 2, _box_y + 15, _stat_names[_s]);

    // Stat value - gap below label, centered in lower half
    draw_set_font(fnt_ui);
    draw_set_color(c_white);
    draw_text(_bx + _box_w / 2, _box_y + 48, string(_stat_v));
}

// Stat description for currently selected stat
var _stat_descs = [
    "Physical crit +1.5% per point",
    "+3 accuracy  +2 dodge  +2% crit per point",
    "+3 max HP per point",
    "Elemental crit +1% per point",
    "Effect & DOT crit +1.5% per point  (min 5%)",
    "Ability dmg  +gold find  cheaper NPC prices"
];
draw_set_font(fnt_ui_small);
draw_set_color(make_color_rgb(200, 210, 230));
draw_text(_alloc_cx, _box_y + _box_h + 21, _stat_descs[selected_stat]);

// Allocation key hints below the stat boxes
draw_set_color(make_color_rgb(140, 145, 155));
draw_text(_alloc_cx, _box_y + _box_h + 51, "Enter / Space: Add point        X: Remove point");


// -----------------------------------------------------------------------------
// 5. BOTTOM INSTRUCTION BAR
// -----------------------------------------------------------------------------
var _inst_y = 1020;

// Navigation hint
draw_set_font(fnt_ui_small);
draw_set_color(make_color_rgb(130, 135, 145));
draw_text(960, _inst_y, "A / D: Class    Q / E: Gender    W / S: Stat    Enter / Space: Confirm");

// Readiness prompt
if (free_points > 0) {
    draw_set_color(c_yellow);
    draw_text(960, _inst_y + 33, "Allocate all points before confirming");
} else {
    draw_set_color(c_green);
    draw_text(960, _inst_y + 33, "Ready!  Press Space to begin");
}

// -----------------------------------------------------------------------------
// 6. NAME ENTRY OVERLAY
// Shown after Space is pressed with all points allocated.
// -----------------------------------------------------------------------------
if (naming_active) {
    // Dark overlay
    draw_set_alpha(0.88);
    draw_set_color(make_color_rgb(8, 10, 20));
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(120, 190, 255));
    draw_text(960, 405, "Name Your Hero");

    // Input box
    var _box_x = 585;
    var _box_y = 480;
    var _box_w = 750;
    var _box_h = 78;

    draw_set_color(make_color_rgb(22, 28, 48));
    draw_rectangle(_box_x, _box_y, _box_x + _box_w, _box_y + _box_h, false);
    draw_set_color(make_color_rgb(80, 150, 220));
    draw_rectangle(_box_x, _box_y, _box_x + _box_w, _box_y + _box_h, true);

    // Typed text + blinking cursor
    var _cursor = ((current_time mod 1000) < 500) ? "|" : "";
    var _display_name = keyboard_string + _cursor;
    draw_set_font(fnt_ui);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_text(_box_x + 21, _box_y + _box_h / 2, _display_name);

    // Hints
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(130, 135, 145));
    draw_text(960, 597, "Enter to confirm       Escape to go back");
}


// -----------------------------------------------------------------------------
// 7. PORTRAIT SELECTION OVERLAY
// Shown after name entry. Large center portrait + side thumbnails.
// -----------------------------------------------------------------------------
if (portrait_active) {
    var _portrait_count = array_length(global.portrait_sprites);

    // Dark overlay
    draw_set_alpha(0.92);
    draw_set_color(make_color_rgb(8, 10, 20));
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(120, 190, 255));
    draw_text(960, 90, "Choose Your Portrait");

    // Center portrait (large, 480x480)
    var _main_w = 480;
    var _main_h = 480;
    var _main_x = GUI_CX - _main_w / 2;
    var _main_y = 240;
    var _cur_spr = global.portrait_sprites[selected_portrait];
    draw_sprite_stretched(_cur_spr, 0, _main_x, _main_y, _main_w, _main_h);

    // Border around center portrait
    draw_set_color(make_color_rgb(80, 160, 220));
    draw_rectangle(_main_x - 3, _main_y - 3, _main_x + _main_w + 3, _main_y + _main_h + 3, true);
    ui_draw_gothic_frame(_main_x - 3, _main_y - 3, _main_x + _main_w + 3, _main_y + _main_h + 3, 36);   // ornate portrait frame

    // Side thumbnails (show prev and next at 240x240)
    var _thumb_w = 240;
    var _thumb_h = 240;
    var _thumb_y = _main_y + _main_h / 2 - _thumb_h / 2;

    var _prev_idx = (selected_portrait - 1 + _portrait_count) mod _portrait_count;
    var _next_idx = (selected_portrait + 1) mod _portrait_count;

    draw_set_alpha(0.5);
    draw_sprite_stretched(global.portrait_sprites[_prev_idx], 0, _main_x - _thumb_w - 36, _thumb_y, _thumb_w, _thumb_h);
    draw_sprite_stretched(global.portrait_sprites[_next_idx], 0, _main_x + _main_w + 36,  _thumb_y, _thumb_w, _thumb_h);
    draw_set_alpha(1.0);

    // Counter
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(160, 170, 190));
    draw_set_halign(fa_center);
    draw_text(960, _main_y + _main_h + 30, string(selected_portrait + 1) + " / " + string(_portrait_count));

    // Instructions
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(130, 135, 145));
    draw_text(960, _main_y + _main_h + 72, "A / D: Browse       Enter / Space: Confirm");
}


// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);
draw_set_color(c_white);
draw_set_font(-1);
