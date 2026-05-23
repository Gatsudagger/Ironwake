draw_set_font(-1);

// Background
draw_set_colour(make_colour_rgb(8, 12, 22));
draw_rectangle(0, 0, room_width, room_height, false);

// Header
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(200, 180, 255));
draw_text_transformed(room_width / 2, 54, "Choose Your Biome", 2, 2, 0);
draw_set_colour(make_colour_rgb(80, 70, 120));
draw_text_transformed(room_width / 2, 88, "Where will your creature train?", 1, 1, 0);

for (var _i = 0; _i < BIOME.COUNT; _i++) {
    var _bm   = global.biome_data[_i];
    var _cx   = cards_x0 + _i * (card_w + card_gap);
    var _sel  = (_i == selected_biome);

    // Card base
    scr_draw_panel(_cx, cards_y, card_w, card_h);

    // Selected highlight border
    if (_sel) {
        draw_set_colour(_bm.accent);
        draw_rectangle(_cx - 2, cards_y - 2, _cx + card_w + 2, cards_y + card_h + 2, true);
    }

    // Biome icon (large 2-letter abbreviation)
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_colour(_bm.accent);
    draw_text_transformed(_cx + card_w / 2, cards_y + 56, _bm.icon, 3, 3, 0);

    // Biome name
    draw_set_colour(make_colour_rgb(220, 220, 255));
    draw_text_transformed(_cx + card_w / 2, cards_y + 120, _bm.name, 1, 1, 0);

    // Description lines
    draw_set_colour(make_colour_rgb(160, 155, 195));
    for (var _d = 0; _d < 3; _d++) {
        draw_text_transformed(_cx + card_w / 2, cards_y + 156 + _d * 22, _bm.desc[_d], 1, 1, 0);
    }

    // Accent separator
    draw_set_colour(_bm.accent);
    draw_set_alpha(0.4);
    draw_rectangle(_cx + 14, cards_y + 224, _cx + card_w - 14, cards_y + 226, false);
    draw_set_alpha(1);

    // Boosted stats
    var _stats = _bm.stats;
    draw_set_colour(make_colour_rgb(130, 200, 130));
    var _sy = cards_y + 238;
    for (var _s = 0; _s < array_length(_stats); _s++) {
        var _sname = string_copy(string_upper(_stats[_s]), 1, 3);
        draw_text_transformed(_cx + card_w / 2, _sy + _s * 18, "+" + _sname, 1, 1, 0);
    }
}

// Choose button
scr_draw_pixel_button(btn_cx - btn_w / 2, btn_cy - btn_h / 2, btn_w, btn_h,
                      "SELECT BIOME", btn_hovered, 2);

draw_set_alpha(1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_white);
