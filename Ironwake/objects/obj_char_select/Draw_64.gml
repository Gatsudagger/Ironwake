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
draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);


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
draw_set_font(ui_font(fnt_ui));
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
    draw_set_font(ui_font(fnt_ui));
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
        // under each. The "G: Gender" hint lives in the bottom instruction bar,
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
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(140, 150, 170));
            draw_text(_fx, _gy - 12, "Female");
            draw_set_color(make_color_rgb(90, 100, 120));
            draw_text(_fx, _gy + 18, "(loading)");
        }

        // Labels under each option
        draw_set_halign(fa_center); draw_set_valign(fa_top);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(_m_on ? make_color_rgb(255, 220, 120) : make_color_rgb(120, 125, 140));
        draw_text(_mx, _gy + _cellhw + 12, "Male");
        draw_set_color(_m_on ? make_color_rgb(120, 125, 140) : make_color_rgb(255, 220, 120));
        draw_text(_fx, _gy + _cellhw + 12, "Female");

        // Touch (M 07-17): tap the male / female cell to pick that gender - the G
        // key has no tap target otherwise. Direct-set (not a G toggle) so tapping
        // the chosen side is a harmless no-op. This cell sits inside the selected
        // class panel, whose Step click-handler no-ops on the already-selected
        // class, so there's no double-action.
        if (mouse_check_button_pressed(mb_left)) {
            var _gmx = device_mouse_x_to_gui(0);
            var _gmy = device_mouse_y_to_gui(0);
            if (_gmy >= _gy - _cellhw && _gmy <= _gy + _cellhw) {
                if      (_gmx >= _mx - _cellhw && _gmx <= _mx + _cellhw) selected_gender = "m";
                else if (_gmx >= _fx - _cellhw && _gmx <= _fx + _cellhw) selected_gender = "f";
            }
        }
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
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(160, 165, 175));
    draw_text_ext(_px + 21, _py + 282, class_descriptions[_i], -1, _panel_w - 42);

    // --- Stat block ---
    // Show working_stats for the selected class, preset for the others
    var _display_stats = (_is_sel) ? working_stats : _class_stats[_i];
    var _cx            = _px + _panel_w / 2;

    var _stat_block_y  = _py + 408;
    var _stat_line_h   = 30;

    draw_set_halign(fa_center);
    draw_set_font(ui_font(fnt_ui_small));
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
        draw_set_font(ui_font(fnt_ui_small));
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
draw_set_font(ui_font(fnt_ui));
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
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color((_is_hlt) ? make_color_rgb(255, 220, 60) : make_color_rgb(160, 165, 175));
    draw_text(_bx + _box_w / 2, _box_y + 15, _stat_names[_s]);

    // Stat value - gap below label, centered in lower half
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(c_white);
    draw_text(_bx + _box_w / 2, _box_y + 48, string(_stat_v));
}

// Stat description for currently selected stat
var _stat_descs = [
    "Physical crit +1.5% per point",
    "+3 accuracy  +2 dodge  +2% crit per point  +turn priority",
    "+3 max HP per point",
    "Elemental crit +1% per point",
    "Effect & DOT crit +1.5% per point  (min 5%)",
    "Ability dmg  +gold find  cheaper NPC prices"
];
draw_set_font(ui_font(fnt_ui_small));
draw_set_color(make_color_rgb(200, 210, 230));
draw_text(_alloc_cx, _box_y + _box_h + 21, _stat_descs[selected_stat]);

// Allocation key hints below the stat boxes (keyboard/pad-speak - hidden on touch,
// where tapping a stat box adds the point directly)
draw_set_color(make_color_rgb(140, 145, 155));
if (input_device() == 2) {
    draw_text_outline(_alloc_cx, _box_y + _box_h + 51,
        "Tap a stat to add a point" + (free_points < 4 ? "   -   REMOVE takes one back" : ""));
} else {
    draw_text_outline(_alloc_cx, _box_y + _box_h + 51, (input_device() == 1)
        ? "A: Add point        LT: Remove point"
        : "Enter / Space: Add point        X: Remove point");
}


// -----------------------------------------------------------------------------
// 5. BOTTOM INSTRUCTION BAR
// Touch (8d, M 07-08): the continue affordance was an invisible bottom-bar tap
// zone - on touch it becomes a real CONFIRM button drawn inside the SAME zone
// the Step click handler already accepts (y 1005..1073), so no new input code.
// -----------------------------------------------------------------------------
var _inst_y = 1020;

draw_set_font(ui_font(fnt_ui_small));
if (input_device() == 2) {
    if (free_points > 0) {
        draw_set_color(c_yellow);
        draw_text(960, _inst_y + 12, "Allocate all points to continue");
    } else {
        draw_set_color(make_color_rgb(18, 40, 22));
        draw_rectangle(960 - 195, 1008, 960 + 195, 1071, false);
        draw_set_color(c_green);
        draw_rectangle(960 - 195, 1008, 960 + 195, 1071, true);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(c_white);
        draw_text(960, 1027, "CONFIRM");
    }
    // Touch (M 07-17): stat-point removal (X key) had no tap target - a misclick
    // during allocation couldn't be undone. This button removes one point from the
    // last-selected stat (fires the same X the keyboard uses). Shown once any point
    // is spent; sits left of the CONFIRM slot so they never overlap.
    if (free_points < 4) {
        var _rmx1 = 345, _rmy1 = 1008, _rmx2 = 605, _rmy2 = 1071;
        draw_set_color(make_color_rgb(46, 24, 24));
        draw_rectangle(_rmx1, _rmy1, _rmx2, _rmy2, false);
        draw_set_color(make_color_rgb(210, 120, 110));
        draw_rectangle(_rmx1, _rmy1, _rmx2, _rmy2, true);
        draw_set_font(ui_font(fnt_ui));
        draw_set_halign(fa_center); draw_set_valign(fa_middle);
        draw_set_color(c_white);
        draw_text((_rmx1 + _rmx2) / 2, (_rmy1 + _rmy2) / 2, "-  REMOVE");
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        if (touch_tapped(_rmx1, _rmy1, _rmx2, _rmy2)) touch_press(ord("X"));
    }
} else {
    // Navigation hint
    draw_set_color(make_color_rgb(130, 135, 145));
    draw_text_outline(960, _inst_y, "Q / E: Class    A / D: Stat    W / S: + / - Point    G: Gender    Enter / Space: Confirm");

    // Readiness prompt
    if (free_points > 0) {
        draw_set_color(c_yellow);
        draw_text(960, _inst_y + 33, "Allocate all points before confirming");
    } else {
        draw_set_color(c_green);
        draw_text(960, _inst_y + 33, "Ready!  Press Space to begin");
    }
}

// -----------------------------------------------------------------------------
// 6. NAME ENTRY OVERLAY
// Shown after Space is pressed with all points allocated.
// -----------------------------------------------------------------------------
if (naming_active) {
    // Android (8c): the OS keyboard covers the lower half of the screen - lift
    // the whole modal clear of it while it's up, and give touch an explicit
    // DONE button (M 07-07: the OSK hid the box + continue was ambiguous).
    var _ny_off = (variable_global_exists("osk_shown") && global.osk_shown) ? -270 : 0;

    // Dark overlay
    draw_set_alpha(0.88);
    draw_set_color(make_color_rgb(8, 10, 20));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(120, 190, 255));
    draw_text(960, 405 + _ny_off, "Name Your Hero");

    // Input box
    var _box_x = 585;
    var _box_y = 480 + _ny_off;
    var _box_w = 750;
    var _box_h = 78;

    draw_set_color(make_color_rgb(22, 28, 48));
    draw_rectangle(_box_x, _box_y, _box_x + _box_w, _box_y + _box_h, false);
    draw_set_color(make_color_rgb(80, 150, 220));
    draw_rectangle(_box_x, _box_y, _box_x + _box_w, _box_y + _box_h, true);

    // Typed text + blinking cursor
    var _cursor = ((current_time mod 1000) < 500) ? "|" : "";
    var _display_name = keyboard_string + _cursor;
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_text(_box_x + 21, _box_y + _box_h / 2, _display_name);

    // Empty-name warning (Step blocks confirm and arms this flash). Sits in the
    // gap between the title (ends ~y430) and the input box (top y480).
    if (naming_blocked_flash > 0) {
        draw_set_halign(fa_center);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(230, 150, 130));
        draw_text_outline(960, 453 + _ny_off, "Enter a name to continue");
    }

    // Hints (keyboard-speak - hidden on touch, where the DONE button sits here)
    draw_set_halign(fa_center);
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(130, 135, 145));
    if (input_device() != 2) draw_text_outline(960, 597 + _ny_off, "Enter to confirm       Escape to go back");
    // Deck/controller players have no physical keyboard - point at the Steam OSK
    // (STEAM_DECK_NOTES.md: the manual Steam+X path is the EA answer; the automatic
    // floating-keyboard call is a post-EA Steamworks-extension chunk).
    if (input_device() == 1) {
        draw_set_color(make_color_rgb(100, 110, 130));
        draw_text_outline(960, 636, "No keyboard? Steam + X opens the on-screen keyboard.");
    }
    // Touch: explicit DONE button (fires the same Enter path).
    if (input_device() == 2) {
        var _dbx1 = 960 - 165, _dby1 = _box_y + _box_h + 27;
        var _dbx2 = 960 + 165, _dby2 = _dby1 + 63;
        draw_set_color(make_color_rgb(20, 34, 58));
        draw_rectangle(_dbx1, _dby1, _dbx2, _dby2, false);
        draw_set_color(make_color_rgb(80, 160, 220));
        draw_rectangle(_dbx1, _dby1, _dbx2, _dby2, true);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(c_white);
        draw_text(960, (_dby1 + _dby2) / 2, "DONE");
        if (touch_tapped(_dbx1, _dby1, _dbx2, _dby2)) touch_press(vk_enter);
    }
}


// -----------------------------------------------------------------------------
// 7. PORTRAIT SELECTION OVERLAY
// Shown after name entry. Large center portrait + side thumbnails.
// -----------------------------------------------------------------------------
if (portrait_active) {
    // Curated creation pool (08-14): selected_portrait indexes portrait_pool
    // (3 per class+gender); the full 60 stay at Vael's portrait tab.
    var _portrait_count = max(1, array_length(portrait_pool));

    // Dark overlay
    draw_set_alpha(0.92);
    draw_set_color(make_color_rgb(8, 10, 20));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
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
    var _cur_spr = global.portrait_sprites[portrait_pool[clamp(selected_portrait, 0, _portrait_count - 1)]];
    draw_sprite_stretched(_cur_spr, 0, _main_x, _main_y, _main_w, _main_h);

    // Border around center portrait
    draw_set_color(make_color_rgb(80, 160, 220));
    draw_rectangle(_main_x - 3, _main_y - 3, _main_x + _main_w + 3, _main_y + _main_h + 3, true);
    ui_draw_gothic_frame(_main_x - 3, _main_y - 3, _main_x + _main_w + 3, _main_y + _main_h + 3, 36);   // ornate portrait frame

    // Side thumbnails (show prev and next at 240x240)
    var _thumb_w = 240;
    var _thumb_h = 240;
    var _thumb_y = _main_y + _main_h / 2 - _thumb_h / 2;

    var _prev_idx = portrait_pool[(selected_portrait - 1 + _portrait_count) mod _portrait_count];
    var _next_idx = portrait_pool[(selected_portrait + 1) mod _portrait_count];

    draw_set_alpha(0.5);
    draw_sprite_stretched(global.portrait_sprites[_prev_idx], 0, _main_x - _thumb_w - 36, _thumb_y, _thumb_w, _thumb_h);
    draw_sprite_stretched(global.portrait_sprites[_next_idx], 0, _main_x + _main_w + 36,  _thumb_y, _thumb_w, _thumb_h);
    draw_set_alpha(1.0);

    // Counter
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(160, 170, 190));
    draw_set_halign(fa_center);
    draw_text(960, _main_y + _main_h + 30, string(selected_portrait + 1) + " / " + string(_portrait_count));

    // Instructions (keyboard-speak - touch gets tap zones + a CONFIRM button)
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(130, 135, 145));
    if (input_device() != 2) draw_text_outline(960, _main_y + _main_h + 72, "A / D: Browse       Enter / Space: Confirm");
    // The other portraits aren't gone - Vael sells them (08-14 gating).
    draw_set_color(make_color_rgb(150, 125, 170));
    draw_text_outline(960, _main_y + _main_h + (input_device() == 2 ? 150 : 102),
        "Vael the Aesthete offers many more, back at camp.");

    // Touch (8c, M 07-07): tap a side thumbnail to page one portrait per tap;
    // explicit CONFIRM button below the counter continues to the hub.
    if (input_device() == 2) {
        if (touch_tapped(_main_x - _thumb_w - 60, _thumb_y - 24, _main_x - 12, _thumb_y + _thumb_h + 24)) {
            touch_press(ord("A"));
        } else if (touch_tapped(_main_x + _main_w + 12, _thumb_y - 24, _main_x + _main_w + _thumb_w + 60, _thumb_y + _thumb_h + 24)) {
            touch_press(ord("D"));
        }
        var _pbx1 = 960 - 165, _pby1 = _main_y + _main_h + 63;
        var _pbx2 = 960 + 165, _pby2 = _pby1 + 63;
        draw_set_color(make_color_rgb(20, 34, 58));
        draw_rectangle(_pbx1, _pby1, _pbx2, _pby2, false);
        draw_set_color(make_color_rgb(80, 160, 220));
        draw_rectangle(_pbx1, _pby1, _pbx2, _pby2, true);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(c_white);
        draw_text(960, (_pby1 + _pby2) / 2, "CONFIRM");
        if (touch_tapped(_pbx1, _pby1, _pbx2, _pby2)) touch_press(vk_enter);
    }
}


// -----------------------------------------------------------------------------
// RPG ORIGIN - background choice overlay (08-11, M design-locked). 12 cards in
// a 4x3 grid, each with its staging still (spr_origin_<id>; framed text card
// until the art imports), name and mechanical start. Selected card's flavor
// line reads in the footer. Cards hit-tested HERE (touch rule): tap selects,
// tap-again proceeds; Step consumes origin:pickN / origin:go.
// -----------------------------------------------------------------------------
if (origin_active) {
    draw_set_alpha(0.90);
    draw_set_color(make_color_rgb(8, 10, 20));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(120, 190, 255));
    draw_text(GUI_CX, 66, "Where Do You Come From?");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(160, 168, 185));
    draw_text(GUI_CX, 132, "Every wanderer carried something up to Ironwake. Choose what you carried.");

    var _og_cat = origin_catalog();
    var _og_n   = array_length(_og_cat);
    var _ogx = device_mouse_x_to_gui(0);
    var _ogy = device_mouse_y_to_gui(0);
    var _ogp = mouse_check_button_pressed(mb_left);

    // 4x3 grid, measured: cards 408x232, pitch 432/248 -> grid ends y908;
    // a 3-line start text ends y+226, 6px inside the card.
    for (var _o = 0; _o < _og_n; _o++) {
        var _oc  = _og_cat[_o];
        var _ocx = 108 + (_o mod 4) * 432;
        var _ocy = 180 + (_o div 4) * 248;
        var _ocw = 408, _och = 232;
        var _osel = (_o == selected_origin);

        draw_set_color(_osel ? make_color_rgb(26, 30, 44) : make_color_rgb(14, 16, 24));
        draw_rectangle(_ocx, _ocy, _ocx + _ocw, _ocy + _och, false);
        draw_set_color(_osel ? make_color_rgb(120, 190, 255) : make_color_rgb(50, 56, 75));
        draw_rectangle(_ocx, _ocy, _ocx + _ocw, _ocy + _och, true);
        if (_osel) draw_rectangle(_ocx + 3, _ocy + 3, _ocx + _ocw - 3, _ocy + _och - 3, true);

        // Staging still: aspect-contained into the card's upper band. Until the
        // art imports, a dim vignette keeps the card intentional, not broken.
        var _osp = origin_still(_oc.id);
        var _oix0 = _ocx + 8, _oiy0 = _ocy + 8, _oiw = _ocw - 16, _oih = 116;
        draw_set_color(make_color_rgb(10, 11, 17));
        draw_rectangle(_oix0, _oiy0, _oix0 + _oiw, _oiy0 + _oih, false);
        if (_osp >= 0) {
            var _osw = sprite_get_width(_osp), _osh = sprite_get_height(_osp);
            var _osc = min(_oiw / _osw, _oih / _osh);
            var _odw = _osw * _osc, _odh = _osh * _osc;
            draw_sprite_stretched(_osp, 0, _oix0 + (_oiw - _odw) * 0.5, _oiy0 + (_oih - _odh) * 0.5, _odw, _odh);
        } else {
            draw_set_color(make_color_rgb(34, 38, 54));
            draw_rectangle(_oix0 + 1, _oiy0 + 1, _oix0 + _oiw - 1, _oiy0 + _oih - 1, true);
        }

        draw_set_font(ui_font(fnt_ui));
        draw_set_color(_osel ? c_white : make_color_rgb(200, 206, 220));
        draw_text(_ocx + _ocw / 2, _ocy + 128, _oc.name);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(_osel ? make_color_rgb(210, 180, 110) : make_color_rgb(140, 148, 168));
        draw_text_ext(_ocx + _ocw / 2, _ocy + 160, _oc.start, 22, _ocw - 24);

        // Hit-test in Draw (touch rule): tap selects; tapping the selected card proceeds.
        if (_ogp && _ogx >= _ocx && _ogx < _ocx + _ocw && _ogy >= _ocy && _ogy < _ocy + _och) {
            input_inject(_osel ? "origin:go" : ("origin:pick" + string(_o)));
        }
    }

    // Footer: the selected origin's flavor line + key legend.
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(185, 175, 150));
    draw_text(GUI_CX, 936, "\"" + _og_cat[selected_origin].blurb + "\"");
    draw_set_color(make_color_rgb(140, 150, 175));
    ui_draw_key_legend(GUI_CX, 984, "A/D W/S: Select   Enter: Choose   Esc: Back");
}


// -----------------------------------------------------------------------------
// THE IRON VOW - mode choice overlay (SYSTEMS_IRON_VOW.md). Drawn over the
// whole screen after portrait confirm. Cards are hit-tested HERE (touch rule):
// tap selects, tap-again / CHOOSE button proceeds; Step consumes the tags.
// -----------------------------------------------------------------------------
if (vow_active) {
    draw_set_alpha(0.86);
    draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(228, 205, 140));
    draw_text(GUI_CX, 96, "SWEAR A VOW?");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(160, 168, 185));
    draw_text(GUI_CX, 168, "How this story is allowed to end. The Vow cannot be changed later.");

    var _vow_names = ["STANDARD", "THE IRON VOW", "THE UNBROKEN VOW"];
    var _vow_sub   = ["The Ironwake you know.", "Three lives. Ever.", "One life. No mercy."];
    var _vow_body  = [
        "Defeat costs your unbanked haul,\nnever your character.\n\nThe full game, endlessly.",
        "Every defeat consumes a life.\nThe third death is FINAL -\nthe save is erased forever.\n\nFall triumphant and be named\nthe Thrice-Tempered.",
        "Your first death is your last.\nThe save is erased forever.\n\nFall triumphant and be named\nthe Unbroken.",
    ];
    var _vow_cols  = [make_color_rgb(130, 195, 255), make_color_rgb(220, 150, 90), make_color_rgb(220, 90, 80)];
    var _mvx = device_mouse_x_to_gui(0);
    var _mvy = device_mouse_y_to_gui(0);
    var _mvp = mouse_check_button_pressed(mb_left);
    for (var _v = 0; _v < 3; _v++) {
        var _vx = 150 + _v * 552;
        var _vy0 = 246, _vy1 = 810;
        var _vsel = (_v == selected_vow);
        draw_set_color(_vsel ? make_color_rgb(26, 30, 44) : make_color_rgb(14, 16, 24));
        draw_rectangle(_vx, _vy0, _vx + 516, _vy1, false);
        draw_set_color(_vsel ? _vow_cols[_v] : make_color_rgb(50, 56, 75));
        draw_rectangle(_vx, _vy0, _vx + 516, _vy1, true);
        if (_vsel) draw_rectangle(_vx + 5, _vy0 + 5, _vx + 511, _vy1 - 5, true);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(_vow_cols[_v]);
        draw_text(_vx + 258, _vy0 + 42, _vow_names[_v]);
        draw_set_color(make_color_rgb(210, 214, 228));
        draw_text(_vx + 258, _vy0 + 96, _vow_sub[_v]);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(165, 172, 190));
        draw_text_ext(_vx + 258, _vy0 + 168, _vow_body[_v], 34, 456);
        // Hit-test in Draw (touch rule): tap selects; tapping the selected card proceeds.
        if (_mvp && _mvx >= _vx && _mvx < _vx + 516 && _mvy >= _vy0 && _mvy < _vy1) {
            input_inject(_vsel ? "vow:go" : ("vow:pick" + string(_v)));
        }
    }

    // CHOOSE button + key legend
    var _vbx1 = GUI_CX - 165, _vby1 = 876, _vbx2 = GUI_CX + 165, _vby2 = 942;
    draw_set_color(make_color_rgb(20, 34, 58));
    draw_rectangle(_vbx1, _vby1, _vbx2, _vby2, false);
    draw_set_color(make_color_rgb(80, 160, 220));
    draw_rectangle(_vbx1, _vby1, _vbx2, _vby2, true);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(c_white);
    draw_set_valign(fa_middle);
    draw_text(GUI_CX, (_vby1 + _vby2) / 2, "CHOOSE");
    draw_set_valign(fa_top);
    if (_mvp && _mvx >= _vbx1 && _mvx < _vbx2 && _mvy >= _vby1 && _mvy < _vby2) input_inject("vow:go");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(140, 150, 175));
    ui_draw_key_legend(GUI_CX, 984, "A/D: Select   Enter: Choose   Esc: Back");

    // Vow confirm popup (checkout standing rule) - topmost, modal in Step.
    if (vow_confirm_open) {
        var _vcn = (selected_vow == 2) ? "THE UNBROKEN VOW" : "THE IRON VOW";
        var _vcb = (selected_vow == 2)
            ? "Swear it, and your FIRST death erases this character's save forever.\nOnly a gravestone will remain."
            : "Swear it, and every defeat consumes a life.\nYour THIRD death erases this character's save forever.\nOnly a gravestone will remain.";
        ui_draw_checkout_confirm(_vcn, _vcb, "vow:ok", "vow:cancel");
    }
}

// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);
draw_set_color(c_white);
draw_set_font(-1);

// Touch (8c): universal Back chip + simulated-key pump - always LAST (topmost).
ui_draw_touch_back();
ui_draw_touch_gamepad();   // on-screen d-pad in the left gutter (M 07-17)

// TOUCH CONTROLS INTRO (07-24) - drawn after the chip/d-pad so it tops both.
// Step exits while it's open; GOT IT persists [touch] intro_seen and closes.
if (touch_intro_open) {
    draw_set_alpha(0.72);
    draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);
    // Panel height is MEASURED from the wrapped text (the pinch line grew the
    // copy past the old fixed 570 box) so it can never collide with the button.
    var _ti_txt = "Play however feels best: TAP things directly, or use the on-screen D-PAD to move a cursor and confirm."
        + "\n\nHOLD an ability or creature to examine it."
        + "\n\nPINCH with two fingers any time to zoom the screen; pinch back down to reset."
        + "\n\nThe D-pad can be RESIZED or turned OFF any time via the SETTINGS chip at camp.";
    draw_set_font(ui_font(fnt_ui));
    var _ti_th = string_height_ext(_ti_txt, 45, 900);
    var _ti_ph = 132 + _ti_th + 36 + 63 + 66;   // title zone + text + gap + button + bottom pad
    var _tix1 = GUI_CX - 495, _tiy1 = GUI_CY - _ti_ph / 2;
    var _tix2 = GUI_CX + 495, _tiy2 = _tiy1 + _ti_ph;
    draw_set_color(make_color_rgb(14, 16, 24));
    draw_rectangle(_tix1, _tiy1, _tix2, _tiy2, false);
    ui_draw_gothic_frame(_tix1, _tiy1, _tix2, _tiy2, 24);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(228, 205, 140));
    draw_text(GUI_CX, _tiy1 + 42, "Touch Controls");
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(200, 208, 222));
    draw_text_ext(GUI_CX, _tiy1 + 132, _ti_txt, 45, 900);
    var _tib_x1 = GUI_CX - 165, _tib_y1 = _tiy2 - 129, _tib_x2 = GUI_CX + 165, _tib_y2 = _tiy2 - 66;
    draw_set_color(make_color_rgb(20, 34, 58));
    draw_rectangle(_tib_x1, _tib_y1, _tib_x2, _tib_y2, false);
    draw_set_color(make_color_rgb(80, 160, 220));
    draw_rectangle(_tib_x1, _tib_y1, _tib_x2, _tib_y2, true);
    draw_set_valign(fa_middle);
    draw_set_color(c_white);
    draw_text(GUI_CX, (_tib_y1 + _tib_y2) / 2, "GOT IT");
    draw_set_valign(fa_top);
    if (touch_tapped(_tib_x1, _tib_y1, _tib_x2, _tib_y2, true)) {
        touch_intro_open = false;
        ini_open("settings.ini");
        ini_write_real("touch", "intro_seen", 1);
        ini_close();
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_font(-1);
}
