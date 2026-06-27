// =============================================================================
// obj_title_controller - Draw GUI
// =============================================================================

// Deep background
draw_set_color(make_color_rgb(6, 7, 12));
draw_rectangle(0, 0, GUI_W, GUI_H, false);

// Atmospheric edge vignette
draw_set_alpha(0.35);
draw_set_color(c_black);
draw_rectangle(0,    0,    270,   GUI_H, false);
draw_rectangle(1650, 0,    GUI_W, GUI_H, false);
draw_rectangle(0,    0,    GUI_W, 150,   false);
draw_rectangle(0,    930,  GUI_W, GUI_H, false);
draw_set_alpha(1.0);

// -----------------------------------------------------------------------
// CUTSCENE PHASE
// -----------------------------------------------------------------------
if (phase == "cutscene") {
    draw_set_font(fnt_ui);
    var _num_panels = array_length(cutscene_panels);
    var _sep        = 48;   // line separation WITHIN a panel
    var _gap        = 33;   // extra space BETWEEN panels

    // Each panel is a multi-line string (\n). Measure real heights so a 3-line
    // panel can't overlap the next one, and center the whole block vertically.
    var _heights = array_create(_num_panels, 0);
    var _total_h = 0;
    for (var _i = 0; _i < _num_panels; _i++) {
        var _ln = string_count("\n", cutscene_panels[_i]) + 1;
        _heights[_i] = _ln * _sep;
        _total_h += _heights[_i] + (_i > 0 ? _gap : 0);
    }
    var _cy = GUI_CY - _total_h * 0.5;

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_alpha(screen_alpha);

    // All completed panels - fully visible, advanced by each panel's real height
    for (var _i = 0; _i < panel_idx; _i++) {
        draw_set_color(c_black);
        draw_text_ext(962, _cy + 2, cutscene_panels[_i], _sep, 1350);
        draw_set_color(make_color_rgb(205, 208, 220));
        draw_text_ext(960, _cy, cutscene_panels[_i], _sep, 1350);
        _cy += _heights[_i] + _gap;
    }

    // Currently typing panel
    if (panel_idx < _num_panels) {
        var _visible = string_copy(cutscene_panels[panel_idx], 1, floor(typed_chars));
        draw_set_color(c_black);
        draw_text_ext(962, _cy + 2, _visible, _sep, 1350);
        draw_set_color(make_color_rgb(205, 208, 220));
        draw_text_ext(960, _cy, _visible, _sep, 1350);
    }

    draw_set_alpha(1.0);

    // Skip hint fades in after grace period
    if (skip_timer > skip_hold) {
        var _hint_a = min(0.55, (skip_timer - skip_hold) / 40.0);
        draw_set_alpha(_hint_a);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(90, 95, 115));
        draw_text(960, 998, "Press any key to skip");
        draw_set_alpha(1.0);
    }
    draw_set_font(-1);

// -----------------------------------------------------------------------
// TITLE PHASE
// -----------------------------------------------------------------------
} else if (phase == "title") {

    // --- Logo ---
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui_title);
    draw_set_alpha(title_alpha);

    // Glow layer (color underlay)
    draw_set_alpha(title_alpha * 0.18);
    draw_set_color(make_color_rgb(60, 120, 200));
    draw_text(960, 300, "IRONWAKE");

    // Shadow
    draw_set_alpha(title_alpha);
    draw_set_color(make_color_rgb(15, 40, 70));
    draw_text(966, 306, "IRONWAKE");

    // Main title
    draw_set_color(make_color_rgb(130, 195, 255));
    draw_text(960, 300, "IRONWAKE");

    // Subtitle
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(80, 92, 115));
    draw_text(960, 402, "A  R O G U E L I T E  D U N G E O N  C R A W L E R");

    // Decorative line under subtitle
    draw_set_alpha(title_alpha * 0.4);
    draw_set_color(make_color_rgb(60, 100, 160));
    draw_rectangle(585, 428, 1335, 431, false);
    draw_set_alpha(title_alpha);

    // --- Menu options ---
    draw_set_alpha(menu_alpha);

    // Check if any save exists to enable Load Game
    var _any_save = (slot_previews[0] != undefined
                  || slot_previews[1] != undefined
                  || slot_previews[2] != undefined);

    var _options = ["NEW GAME", "LOAD GAME"];
    for (var _i = 0; _i < 2; _i++) {
        var _oy     = 585 + _i * 93;
        var _is_sel = (_i == selected);
        var _avail  = (_i == 0) || _any_save;

        if (_is_sel && _avail) {
            if (blink < 30) {
                draw_set_alpha(menu_alpha * 0.12);
                draw_set_color(make_color_rgb(80, 140, 220));
                draw_rectangle(660, _oy - 33, 1260, _oy + 33, false);
                draw_set_alpha(menu_alpha);
            }
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(130, 195, 255));
            draw_text(698, _oy, ">");
        }

        draw_set_font(fnt_ui);
        draw_set_color(_avail ? c_white : make_color_rgb(55, 60, 78));
        draw_text(960, _oy, _options[_i]);

        if (_i == 1 && !_any_save) {
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(50, 55, 72));
            draw_text(960, _oy + 39, "no saves found");
        }
    }

    if (can_input && blink < 42) {
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(100, 110, 135));
        draw_text_outline(960, 818, "W/S: Navigate   Enter / Space: Select");
    }

    // Settings hint (always shown on the title screen)
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(90, 100, 125));
    draw_text(960, 1035, "[ O ]  Settings");

    draw_set_alpha(1.0);
    draw_set_font(-1);

// -----------------------------------------------------------------------
// SLOT PICKER PHASE
// -----------------------------------------------------------------------
} else if (phase == "slot_picker") {

    // Background title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(130, 195, 255));
    draw_text(960, 120, slot_mode == "new_game" ? "SELECT SAVE SLOT - NEW GAME" : "SELECT SAVE SLOT - LOAD GAME");
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(70, 80, 105));
    draw_text_outline(960, 177, slot_mode == "new_game" ? "A/D to choose slot   Enter to confirm   Esc to go back" : "A/D to choose slot   Enter to load   Esc to go back");

    // Draw 3 slot cards
    var _card_w  = 510;
    var _card_h  = 330;
    var _card_y  = 330;
    var _gap     = 45;
    var _total_w = _card_w * 3 + _gap * 2;
    var _start_x = GUI_CX - _total_w / 2;

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

        // Card border - rarity-glow on selected
        var _border_col;
        if (_locked)        _border_col = make_color_rgb(35, 38, 50);
        else if (_is_sel)   _border_col = make_color_rgb(130, 195, 255);
        else                _border_col = make_color_rgb(50, 60, 85);
        draw_set_color(_border_col);
        draw_rectangle(_cx, _card_y, _cx + _card_w, _card_y + _card_h, true);

        draw_set_alpha(_locked ? 0.3 : 1.0);

        // Slot number header bar
        draw_set_color(_is_sel ? make_color_rgb(35, 65, 110) : make_color_rgb(22, 28, 44));
        draw_rectangle(_cx, _card_y, _cx + _card_w, _card_y + 48, false);
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(_locked ? make_color_rgb(55, 58, 70) : c_white);
        draw_text(_cx + _card_w / 2, _card_y + 12, "SAVE SLOT " + string(_s + 1));

        // Slot content
        var _mid = _cx + _card_w / 2;
        if (!_occupied) {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(55, 65, 90));
            draw_text(_mid, _card_y + 180, "- Empty -");
        } else {
            // Character name
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(180, 215, 255));
            draw_text(_mid, _card_y + 83, _preview.player_name);
            // Stats
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(140, 155, 180));
            draw_text(_mid, _card_y + 135, "Runs:   " + string(_preview.run_count));
            draw_text(_mid, _card_y + 168, "Gold:   " + string(_preview.gold) + "g");
            draw_text(_mid, _card_y + 201, "Clears: " + string(_preview.dungeon_clears_total));
            draw_text(_mid, _card_y + 234, "Best floor: " + string(_preview.best_floor));
        }

        // Overwrite warning on selected occupied slot in new_game mode
        if (_is_sel && slot_mode == "new_game" && _occupied) {
            draw_set_font(fnt_ui_small);
            var _warn_col = slot_confirm ? make_color_rgb(255, 100, 80) : make_color_rgb(220, 170, 50);
            draw_set_color(_warn_col);
            draw_text(_mid, _card_y + _card_h - 54,
                slot_confirm ? "Press Enter again to OVERWRITE" : "! Occupied - confirm to overwrite");
        }

        // "No save" hint on empty slot in load_game mode
        if (_is_sel && slot_mode == "load_game" && !_occupied) {
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(150, 80, 80));
            draw_text(_mid, _card_y + _card_h - 54, "No save data");
        }

        // Ornate gothic frame around each save plaque. Band 15 keeps the corner
        // ornaments inside the 45px inter-card gaps and clear of the title (y120/177
        // above) and the selection caret (y below). Locked cards dim to match.
        draw_set_font(-1);
        ui_draw_gothic_frame(_cx, _card_y, _cx + _card_w, _card_y + _card_h, 15, _locked ? 0.35 : 1.0);

        draw_set_alpha(1.0);
    }

    // Arrow caret under selected card
    var _arrow_x = _start_x + slot_selected * (_card_w + _gap) + _card_w / 2;
    if ((current_time mod 700) < 400) {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(130, 195, 255));
        draw_text(_arrow_x, _card_y + _card_h + 21, "^");
    }

    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// Audio settings overlay - drawn on top of everything when open
draw_set_font(-1);
if (variable_global_exists("settings_open") && global.settings_open) {
    ui_draw_settings_overlay();
}

// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);
draw_set_color(c_white);
draw_set_font(-1);
