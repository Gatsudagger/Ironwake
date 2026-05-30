if (!visible) exit;

var _gw = display_get_gui_width();
var _gh = display_get_gui_height();

// Dark overlay
draw_set_alpha(0.92);
draw_set_colour(make_colour_rgb(8, 8, 20));
draw_rectangle(0, 0, _gw, _gh, false);
draw_set_alpha(1);

// Outer panel border
draw_set_colour(make_colour_rgb(60, 60, 120));
draw_rectangle(20, 20, _gw-20, _gh-20, true);

// Tab bar at top
var _tab_w = (_gw - 40) / 5;
var _tab_h = 40;
for (var _i = 0; _i < 5; _i++) {
    var _tx = 20 + _i * _tab_w;
    var _ty = 20;
    var _selected = (_i == active_tab);
    draw_set_colour(_selected ? make_colour_rgb(60,80,160) : make_colour_rgb(20,20,50));
    draw_rectangle(_tx, _ty, _tx+_tab_w, _ty+_tab_h, false);
    draw_set_colour(_selected ? make_colour_rgb(100,140,255) : make_colour_rgb(60,60,120));
    draw_rectangle(_tx, _ty, _tx+_tab_w, _ty+_tab_h, true);
    draw_set_halign(fa_center);
    draw_set_colour(_selected ? c_white : make_colour_rgb(150,150,200));
    draw_text_transformed(_tx+_tab_w/2, _ty+12, tab_labels[_i], 1.1, 1.1, 0);
    // Click detection
    if (mouse_check_button_pressed(mb_left) &&
        display_mouse_get_x() > _tx && display_mouse_get_x() < _tx+_tab_w &&
        display_mouse_get_y() > _ty && display_mouse_get_y() < _ty+_tab_h) {
        active_tab = _i;
    }
}

var _content_y = 70;
var _content_h = _gh - 90;
var _mid_x = _gw / 2;

// ── TAB 0: PARTY ─────────────────────────────────────────────────────────────
if (active_tab == 0) {
    var _gc = obj_game_controller;
    draw_set_halign(fa_center);
    draw_set_colour(make_colour_rgb(200,180,255));
    draw_text_transformed(_mid_x, _content_y + 10, "Primary Party", 1.3, 1.3, 0);

    if (is_struct(_gc.starter_creature)) {
        var _c = _gc.starter_creature;
        var _cx = _mid_x;
        var _cy = _content_y + 50;

        var _cd = global.creature_data[_c.species];
        draw_sprite_ext(_cd.sprite, 0, _cx, _cy, 2.5, 2.5, 0, c_white, 1);

        draw_set_colour(make_colour_rgb(255,215,0));
        draw_text_transformed(_cx, _cy + 90, _c.name, 1.3, 1.3, 0);
        draw_set_colour(make_colour_rgb(180,180,255));
        draw_text_transformed(_cx, _cy + 115, _cd.name, 1.0, 1.0, 0);

        draw_set_colour(make_colour_rgb(120,255,120));
        draw_text_transformed(_cx, _cy + 138, "XP: " + string(_c.xp), 1.0, 1.0, 0);

        var _stats = [STAT_STRENGTH, STAT_AGILITY, STAT_DEXTERITY, STAT_STAMINA,
                      STAT_INTELLECT, STAT_WILLPOWER, STAT_DEFENSE, STAT_VITALITY];
        var _labels = ["STR","AGI","DEX","STA","INT","WIL","DEF","VIT"];
        var _bar_x = _mid_x - 200;
        var _bar_y = _cy + 165;
        var _bar_w = 400;
        var _bar_h = 14;
        var _bar_gap = 20;

        for (var _i = 0; _i < 8; _i++) {
            var _key = "base_" + _stats[_i];
            var _val = _c[$ _key];
            var _ratio = min(1, _val / 50);
            var _by = _bar_y + _i * _bar_gap;

            draw_set_halign(fa_left);
            draw_set_colour(make_colour_rgb(160,160,220));
            draw_text_transformed(_bar_x, _by, _labels[_i], 0.9, 0.9, 0);

            draw_set_colour(make_colour_rgb(30,30,60));
            draw_rectangle(_bar_x+35, _by+2, _bar_x+35+_bar_w, _by+_bar_h, false);
            draw_set_colour(scr_get_stat_colour(_stats[_i]));
            draw_rectangle(_bar_x+35, _by+2, _bar_x+35+round(_bar_w*_ratio), _by+_bar_h, false);
            draw_set_colour(c_white);
            draw_text_transformed(_bar_x+35+_bar_w+8, _by, string(_val), 0.9, 0.9, 0);
        }

        draw_set_halign(fa_center);
        draw_set_colour(make_colour_rgb(180,140,255));
        draw_text_transformed(_cx, _bar_y + 8*_bar_gap + 10, "Active Moves:", 1.0, 1.0, 0);
        var _moves = scr_combat_get_moves(_c.species);
        for (var _i = 0; _i < 3; _i++) {
            draw_set_colour(c_white);
            draw_text_transformed(_cx, _bar_y + 8*_bar_gap + 32 + _i*22, _moves[_i].name, 0.95, 0.95, 0);
        }
    } else {
        draw_set_colour(make_colour_rgb(150,150,200));
        draw_text_transformed(_mid_x, _content_y + 100, "No creature selected yet.", 1.1, 1.1, 0);
    }
}

// ── TAB 1: INVENTORY ─────────────────────────────────────────────────────────
if (active_tab == 1) {
    draw_set_halign(fa_center);
    draw_set_colour(make_colour_rgb(200,180,255));
    draw_text_transformed(_mid_x, _content_y + 10, "Inventory", 1.3, 1.3, 0);

    var _cols = 5;
    var _slot_w = 140;
    var _slot_h = 60;
    var _slot_gap = 10;
    var _start_x = _mid_x - (_cols * (_slot_w + _slot_gap)) / 2;
    var _start_y = _content_y + 50;
    var _tier_cols = [make_colour_rgb(180,180,180), make_colour_rgb(80,200,80), make_colour_rgb(255,215,0)];

    for (var _i = 0; _i < 20; _i++) {
        var _col = _i mod _cols;
        var _row = _i div _cols;
        var _sx = _start_x + _col * (_slot_w + _slot_gap);
        var _sy = _start_y + _row * (_slot_h + _slot_gap);

        draw_set_colour(make_colour_rgb(20,20,50));
        draw_rectangle(_sx, _sy, _sx+_slot_w, _sy+_slot_h, false);
        draw_set_colour(make_colour_rgb(50,50,100));
        draw_rectangle(_sx, _sy, _sx+_slot_w, _sy+_slot_h, true);

        if (_i < array_length(global.inventory)) {
            var _entry = global.inventory[_i];
            var _idata = global.item_data[_entry.item_id];
            draw_set_colour(_tier_cols[_idata.tier]);
            draw_rectangle(_sx, _sy, _sx+4, _sy+_slot_h, false);
            draw_set_halign(fa_left);
            draw_set_colour(c_white);
            draw_text_transformed(_sx+8, _sy+8, _idata.name, 0.85, 0.85, 0);
            draw_set_colour(make_colour_rgb(180,180,180));
            draw_text_transformed(_sx+8, _sy+28, "x" + string(_entry.quantity), 0.85, 0.85, 0);
        } else {
            draw_set_halign(fa_center);
            draw_set_colour(make_colour_rgb(40,40,80));
            draw_text_transformed(_sx+_slot_w/2, _sy+20, "empty", 0.8, 0.8, 0);
        }
    }
}

// ── TAB 2: EQUIPMENT ─────────────────────────────────────────────────────────
if (active_tab == 2) {
    draw_set_halign(fa_center);
    draw_set_colour(make_colour_rgb(200,180,255));
    draw_text_transformed(_mid_x, _content_y + 10, "Equipment", 1.3, 1.3, 0);

    var _slot_labels = ["Head", "Neck", "Chest", "Gloves", "Ring L", "Ring R", "Pants", "Boots"];
    var _slot_w = 180;
    var _slot_h = 44;
    var _slot_gap = 8;
    var _eq_x = _mid_x - _slot_w/2;
    var _eq_y = _content_y + 50;

    for (var _i = 0; _i < 8; _i++) {
        var _sy = _eq_y + _i * (_slot_h + _slot_gap);
        draw_set_colour(make_colour_rgb(20,20,50));
        draw_rectangle(_eq_x, _sy, _eq_x+_slot_w, _sy+_slot_h, false);
        draw_set_colour(make_colour_rgb(60,60,120));
        draw_rectangle(_eq_x, _sy, _eq_x+_slot_w, _sy+_slot_h, true);
        draw_set_halign(fa_left);
        draw_set_colour(make_colour_rgb(140,140,200));
        draw_text_transformed(_eq_x+8, _sy+8, _slot_labels[_i] + ":", 0.9, 0.9, 0);
        draw_set_colour(make_colour_rgb(80,80,120));
        draw_text_transformed(_eq_x+70, _sy+8, "[ empty ]", 0.9, 0.9, 0);
    }

    draw_set_halign(fa_center);
    draw_set_colour(make_colour_rgb(100,100,160));
    draw_text_transformed(_mid_x, _eq_y + 8*(_slot_h+_slot_gap) + 20,
        "Equipment system coming soon.", 0.95, 0.95, 0);
}

// ── TAB 3: RANCH ─────────────────────────────────────────────────────────────
if (active_tab == 3) {
    draw_set_halign(fa_center);
    draw_set_colour(make_colour_rgb(200,180,255));
    draw_text_transformed(_mid_x, _content_y + 10, "Ranch", 1.3, 1.3, 0);

    var _gc = obj_game_controller;
    draw_set_colour(make_colour_rgb(160,160,220));
    draw_text_transformed(_mid_x, _content_y + 50,
        "Biome: " + scr_biome_get_data(_gc.biome_id).name, 1.1, 1.1, 0);

    var _phase_names = ["Night", "Morning", "Midday", "Evening"];
    var _phase_str = _phase_names[global.time_phase];
    draw_set_colour(make_colour_rgb(120,200,120));
    draw_text_transformed(_mid_x, _content_y + 80,
        "Day " + string(global.day_number) + " — " + _phase_str, 1.0, 1.0, 0);

    draw_set_colour(make_colour_rgb(140,140,200));
    draw_text_transformed(_mid_x, _content_y + 130, "Barn (0/3 occupied)", 1.0, 1.0, 0);
    draw_set_colour(make_colour_rgb(80,80,120));
    draw_text_transformed(_mid_x, _content_y + 160, "Ranch management coming soon.", 0.95, 0.95, 0);
}

// ── TAB 4: SAVE/QUIT ─────────────────────────────────────────────────────────
if (active_tab == 4) {
    draw_set_halign(fa_center);
    draw_set_colour(make_colour_rgb(200,180,255));
    draw_text_transformed(_mid_x, _content_y + 10, "Save & Quit", 1.3, 1.3, 0);

    draw_set_colour(make_colour_rgb(120,200,120));
    draw_text_transformed(_mid_x, _content_y + 80, "[ S ] Save Game", 1.2, 1.2, 0);
    draw_set_colour(make_colour_rgb(200,80,80));
    draw_text_transformed(_mid_x, _content_y + 130, "[ Q ] Quit to Desktop", 1.2, 1.2, 0);
    draw_set_colour(make_colour_rgb(100,100,160));
    draw_text_transformed(_mid_x, _content_y + 200, "Press Escape to close menu", 0.9, 0.9, 0);
}

// Close hint
draw_set_halign(fa_center);
draw_set_colour(make_colour_rgb(80,80,120));
draw_text_transformed(_mid_x, _gh-30, "[ Escape ] Close    [ Q/E ] Switch Tab", 0.9, 0.9, 0);
