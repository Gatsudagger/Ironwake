// =============================================================================
// obj_title_controller — Draw GUI
// =============================================================================

// Deep background
draw_set_color(make_color_rgb(6, 7, 12));
draw_rectangle(0, 0, 1280, 720, false);

// Atmospheric edge vignette
draw_set_alpha(0.35);
draw_set_color(c_black);
draw_rectangle(0,    0,   180,  720, false);
draw_rectangle(1100, 0,   1280, 720, false);
draw_rectangle(0,    0,   1280, 100, false);
draw_rectangle(0,    620, 1280, 720, false);
draw_set_alpha(1.0);

// -----------------------------------------------------------------------
// CUTSCENE PHASE
// -----------------------------------------------------------------------
if (phase == "cutscene") {
    var _num_panels = array_length(cutscene_panels);
    var _sep        = 32;   // line separation WITHIN a panel
    var _gap        = 22;   // extra space BETWEEN panels

    // Each panel is a multi-line string (\n). Measure real heights so a 3-line
    // panel can't overlap the next one, and center the whole block vertically.
    var _heights = array_create(_num_panels, 0);
    var _total_h = 0;
    for (var _i = 0; _i < _num_panels; _i++) {
        var _ln = string_count("\n", cutscene_panels[_i]) + 1;
        _heights[_i] = _ln * _sep;
        _total_h += _heights[_i] + (_i > 0 ? _gap : 0);
    }
    var _cy = 360 - _total_h * 0.5;

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_alpha(screen_alpha);

    // All completed panels — fully visible, advanced by each panel's real height
    for (var _i = 0; _i < panel_idx; _i++) {
        draw_set_color(c_black);
        draw_text_ext(641, _cy + 1, cutscene_panels[_i], _sep, 900);
        draw_set_color(make_color_rgb(205, 208, 220));
        draw_text_ext(640, _cy, cutscene_panels[_i], _sep, 900);
        _cy += _heights[_i] + _gap;
    }

    // Currently typing panel
    if (panel_idx < _num_panels) {
        var _visible = string_copy(cutscene_panels[panel_idx], 1, floor(typed_chars));
        draw_set_color(c_black);
        draw_text_ext(641, _cy + 1, _visible, _sep, 900);
        draw_set_color(make_color_rgb(205, 208, 220));
        draw_text_ext(640, _cy, _visible, _sep, 900);
    }

    draw_set_alpha(1.0);

    // Skip hint fades in after grace period
    if (skip_timer > skip_hold) {
        var _hint_a = min(0.55, (skip_timer - skip_hold) / 40.0);
        draw_set_alpha(_hint_a);
        draw_set_color(make_color_rgb(90, 95, 115));
        draw_text(640, 665, "Press any key to skip");
        draw_set_alpha(1.0);
    }

// -----------------------------------------------------------------------
// TITLE PHASE
// -----------------------------------------------------------------------
} else if (phase == "title") {

    // --- Logo ---
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_alpha(title_alpha);

    // Glow layer
    draw_set_alpha(title_alpha * 0.18);
    draw_set_color(make_color_rgb(60, 120, 200));
    draw_text_transformed(640, 200, "IRONWAKE", 3.7, 3.7, 0);

    // Shadow
    draw_set_alpha(title_alpha);
    draw_set_color(make_color_rgb(15, 40, 70));
    draw_text_transformed(644, 204, "IRONWAKE", 3.5, 3.5, 0);

    // Main title
    draw_set_color(make_color_rgb(130, 195, 255));
    draw_text_transformed(640, 200, "IRONWAKE", 3.5, 3.5, 0);

    // Subtitle
    draw_set_color(make_color_rgb(80, 92, 115));
    draw_text_transformed(640, 268, "A  R O G U E L I T E  D U N G E O N  C R A W L E R", 0.9, 0.9, 0);

    // Decorative line under subtitle
    draw_set_alpha(title_alpha * 0.4);
    draw_set_color(make_color_rgb(60, 100, 160));
    draw_rectangle(390, 285, 890, 287, false);
    draw_set_alpha(title_alpha);

    // --- Menu options ---
    draw_set_alpha(menu_alpha);

    // Check if any save exists to enable Load Game
    var _any_save = (slot_previews[0] != undefined
                  || slot_previews[1] != undefined
                  || slot_previews[2] != undefined);

    var _options = ["NEW GAME", "LOAD GAME"];
    for (var _i = 0; _i < 2; _i++) {
        var _oy     = 390 + _i * 62;
        var _is_sel = (_i == selected);
        var _avail  = (_i == 0) || _any_save;

        if (_is_sel && _avail) {
            if (blink < 30) {
                draw_set_alpha(menu_alpha * 0.12);
                draw_set_color(make_color_rgb(80, 140, 220));
                draw_rectangle(440, _oy - 22, 840, _oy + 22, false);
                draw_set_alpha(menu_alpha);
            }
            draw_set_color(make_color_rgb(130, 195, 255));
            draw_text_transformed(465, _oy, ">", 1.5, 1.5, 0);
        }

        draw_set_color(_avail ? c_white : make_color_rgb(55, 60, 78));
        draw_text_transformed(640, _oy, _options[_i], 1.5, 1.5, 0);

        if (_i == 1 && !_any_save) {
            draw_set_color(make_color_rgb(50, 55, 72));
            draw_text_transformed(640, _oy + 26, "no saves found", 0.85, 0.85, 0);
        }
    }

    if (can_input && blink < 42) {
        draw_set_color(make_color_rgb(100, 110, 135));
        draw_text(640, 545, "W/S: Navigate   Enter / Space: Select");
    }

    // Settings hint (always shown on the title screen)
    draw_set_color(make_color_rgb(90, 100, 125));
    draw_text(640, 690, "[ O ]  Settings");

    draw_set_alpha(1.0);

// -----------------------------------------------------------------------
// SLOT PICKER PHASE
// -----------------------------------------------------------------------
} else if (phase == "slot_picker") {

    // Background title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(130, 195, 255));
    draw_text_transformed(640, 80, slot_mode == "new_game" ? "SELECT SAVE SLOT — NEW GAME" : "SELECT SAVE SLOT — LOAD GAME", 1.1, 1.1, 0);
    draw_set_color(make_color_rgb(70, 80, 105));
    draw_text(640, 118, slot_mode == "new_game" ? "A/D to choose slot   Enter to confirm   Esc to go back" : "A/D to choose slot   Enter to load   Esc to go back");

    // Draw 3 slot cards
    var _card_w  = 340;
    var _card_h  = 220;
    var _card_y  = 220;
    var _gap     = 30;
    var _total_w = _card_w * 3 + _gap * 2;
    var _start_x = 640 - _total_w / 2;

    for (var _s = 0; _s < 3; _s++) {
        var _cx      = _start_x + _s * (_card_w + _gap);
        var _is_sel  = (_s == slot_selected);
        var _preview = slot_previews[_s];
        var _occupied = (_preview != undefined);
        var _locked  = (slot_mode == "load_game" && !_occupied);

        // Card background
        var _bg_col;
        if (_locked)       _bg_col = make_color_rgb(14, 15, 22);
        else if (_is_sel)  _bg_col = make_color_rgb(20, 34, 58);
        else               _bg_col = make_color_rgb(12, 16, 28);
        draw_set_alpha(_locked ? 0.4 : 1.0);
        draw_set_color(_bg_col);
        draw_rectangle(_cx, _card_y, _cx + _card_w, _card_y + _card_h, false);

        // Card border — rarity-glow on selected
        var _border_col;
        if (_locked)        _border_col = make_color_rgb(35, 38, 50);
        else if (_is_sel)   _border_col = make_color_rgb(130, 195, 255);
        else                _border_col = make_color_rgb(50, 60, 85);
        draw_set_color(_border_col);
        draw_rectangle(_cx, _card_y, _cx + _card_w, _card_y + _card_h, true);

        draw_set_alpha(_locked ? 0.3 : 1.0);

        // Slot number header bar
        draw_set_color(_is_sel ? make_color_rgb(35, 65, 110) : make_color_rgb(22, 28, 44));
        draw_rectangle(_cx, _card_y, _cx + _card_w, _card_y + 32, false);
        draw_set_halign(fa_center);
        draw_set_color(_locked ? make_color_rgb(55, 58, 70) : c_white);
        draw_text(_cx + _card_w / 2, _card_y + 8, "SAVE SLOT " + string(_s + 1));

        // Slot content
        var _mid = _cx + _card_w / 2;
        if (!_occupied) {
            draw_set_color(make_color_rgb(55, 65, 90));
            draw_text_transformed(_mid, _card_y + 120, "— Empty —", 1.1, 1.1, 0);
        } else {
            // Character name
            draw_set_color(make_color_rgb(180, 215, 255));
            draw_text_transformed(_mid, _card_y + 55, _preview.player_name, 1.2, 1.2, 0);
            // Stats
            draw_set_color(make_color_rgb(140, 155, 180));
            draw_text(_mid, _card_y + 90,  "Runs:   " + string(_preview.run_count));
            draw_text(_mid, _card_y + 112, "Gold:   " + string(_preview.gold) + "g");
            draw_text(_mid, _card_y + 134, "Clears: " + string(_preview.dungeon_clears_total));
            draw_text(_mid, _card_y + 156, "Best floor: " + string(_preview.best_floor));
        }

        // Overwrite warning on selected occupied slot in new_game mode
        if (_is_sel && slot_mode == "new_game" && _occupied) {
            var _warn_col = slot_confirm ? make_color_rgb(255, 100, 80) : make_color_rgb(220, 170, 50);
            draw_set_color(_warn_col);
            draw_text(_mid, _card_y + _card_h - 36,
                slot_confirm ? "Press Enter again to OVERWRITE" : "! Occupied — confirm to overwrite");
        }

        // "No save" hint on empty slot in load_game mode
        if (_is_sel && slot_mode == "load_game" && !_occupied) {
            draw_set_color(make_color_rgb(150, 80, 80));
            draw_text(_mid, _card_y + _card_h - 36, "No save data");
        }

        // Ornate gothic frame around each save plaque. Band 10 keeps the corner
        // ornaments inside the 30px inter-card gaps and clear of the title (y80/118
        // above) and the selection caret (y454 below). Locked cards dim to match.
        ui_draw_gothic_frame(_cx, _card_y, _cx + _card_w, _card_y + _card_h, 10, _locked ? 0.35 : 1.0);

        draw_set_alpha(1.0);
    }

    // Arrow caret under selected card
    var _arrow_x = _start_x + slot_selected * (_card_w + _gap) + _card_w / 2;
    if ((current_time mod 700) < 400) {
        draw_set_color(make_color_rgb(130, 195, 255));
        draw_text_transformed(_arrow_x, _card_y + _card_h + 14, "▲", 1.2, 1.2, 0);
    }

    draw_set_alpha(1.0);
}

// Audio settings overlay — drawn on top of everything when open
if (variable_global_exists("settings_open") && global.settings_open) {
    ui_draw_settings_overlay();
}

// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);
draw_set_color(c_white);
