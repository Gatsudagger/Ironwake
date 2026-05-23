draw_set_font(-1);

// Background
draw_set_colour(make_colour_rgb(8, 12, 22));
draw_rectangle(0, 0, room_width, room_height, false);

// Header
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(200, 180, 255));
draw_text_transformed(room_width / 2, 54, "Choose Your Starter Creature", 2, 2, 0);

for (var _i = 0; _i < CREATURE.COUNT; _i++) {
    var _cd   = global.creature_data[_i];
    var _cx   = cards_x0 + _i * (card_w + card_gap);
    var _sel  = (_i == selected_creature);
    var _icol = icon_col[_i];

    // Card base
    scr_draw_panel(_cx, cards_y, card_w, card_h);

    // Selected highlight border
    if (_sel) {
        draw_set_colour(_icol);
        draw_rectangle(_cx - 2, cards_y - 2, _cx + card_w + 2, cards_y + card_h + 2, true);
    }

    // Creature sprite centered in upper card area
    var _spr    = _cd.sprite;
    var _spr_cx = _cx + card_w / 2;
    var _spr_cy = cards_y + 52;
    draw_sprite_ext(_spr, 0, _spr_cx, _spr_cy, 1, 1, 0, _icol, 1);

    // Creature name
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_colour(make_colour_rgb(220, 220, 255));
    draw_text_transformed(_spr_cx, cards_y + 102, _cd.name, 1, 1, 0);

    // Description lines
    var _desc = creature_desc[_i];
    draw_set_colour(make_colour_rgb(155, 150, 195));
    for (var _d = 0; _d < 3; _d++) {
        draw_text_transformed(_spr_cx, cards_y + 126 + _d * 20, _desc[_d], 1, 1, 0);
    }

    // Separator
    draw_set_colour(_icol);
    draw_set_alpha(0.4);
    draw_rectangle(_cx + 10, cards_y + 192, _cx + card_w - 10, cards_y + 194, false);
    draw_set_alpha(1);

    // Stat bars
    var _bar_x  = _cx + 12;
    var _bar_w  = card_w - 24;
    var _bar_h  = 8;
    var _bar_y0 = cards_y + 202;
    for (var _s = 0; _s < array_length(stat_keys); _s++) {
        var _val  = _cd[$ stat_keys[_s]];
        var _frac = _val / 100;
        var _by   = _bar_y0 + _s * 18;

        // Label
        draw_set_halign(fa_left);
        draw_set_colour(make_colour_rgb(130, 130, 170));
        draw_text_transformed(_bar_x, _by + _bar_h / 2, stat_labels[_s], 1, 1, 0);

        // Background trough
        draw_set_colour(make_colour_rgb(30, 30, 55));
        draw_rectangle(_bar_x + 28, _by, _bar_x + _bar_w, _by + _bar_h, false);

        // Filled portion
        draw_set_colour(stat_col[_s]);
        draw_rectangle(_bar_x + 28, _by, _bar_x + 28 + round(_frac * (_bar_w - 28)), _by + _bar_h, false);
    }
}

// Choose button
draw_set_halign(fa_center);
scr_draw_pixel_button(btn_cx - btn_w / 2, btn_cy - btn_h / 2, btn_w, btn_h,
                      "CHOOSE CREATURE", btn_hovered, 2);

draw_set_alpha(1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_white);
