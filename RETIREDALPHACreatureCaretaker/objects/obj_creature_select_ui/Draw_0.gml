draw_set_font(-1);

// Background
draw_set_colour(make_colour_rgb(8, 12, 22));
draw_rectangle(0, 0, room_width, room_height, false);

// Header
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(200, 180, 255));
draw_text_transformed(room_width / 2, 54, "Choose Your Starter Creature", 2, 2, 0);

var _card_cols = [
    make_colour_rgb(120, 60,  20),   // Harehound  — warm amber/brown
    make_colour_rgb(20,  80,  120),  // Amphibi    — electric blue
    make_colour_rgb(70,  70,  75),   // Bouldeer   — stone grey
    make_colour_rgb(20,  100, 60),   // Salapent   — emerald green
    make_colour_rgb(50,  20,  80),   // Raptowl    — deep purple
    make_colour_rgb(35,  50,  25),   // Thornback  — dark olive
    make_colour_rgb(55,  20,  80),   // Glowmoth   — deep violet
];
var _portrait_sprs = [
    spr_portrait_harehound, spr_portrait_amphibi,   spr_portrait_bouldeer,
    spr_portrait_salapent,  spr_portrait_raptowl,   spr_portrait_thornback,
    spr_portrait_glowmoth,
];

for (var _i = 0; _i < 5; _i++) {
    var _ci   = _i + scroll_offset;
    var _cd   = global.creature_data[_ci];
    var _cx   = cards_x0 + _i * (card_w + card_gap);
    var _sel  = (_ci == selected_creature);
    var _icol = icon_col[_ci];

    // Card base — solid creature colour
    draw_set_colour(_card_cols[_ci]);
    draw_rectangle(_cx, cards_y, _cx + card_w, cards_y + card_h, false);
    draw_set_colour(make_colour_rgb(90, 90, 140));
    draw_rectangle(_cx, cards_y, _cx + card_w, cards_y + card_h, true);

    // Selected highlight border
    if (_sel) {
        draw_set_colour(_icol);
        draw_rectangle(_cx - 2, cards_y - 2, _cx + card_w + 2, cards_y + card_h + 2, true);
    }

    // Portrait sprite — centered in upper card area, scaled 2.5x (170x170 px)
    var _spr_cx = _cx + card_w / 2;
    draw_sprite_ext(_portrait_sprs[_ci], 0, _spr_cx, cards_y + 56, 2.5, 2.5, 0, c_white, 1);

    // Creature name
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_colour(make_colour_rgb(220, 220, 255));
    draw_text_transformed(_spr_cx, cards_y + 115, _cd.name, 1, 1, 0);

    // Description lines
    var _desc = creature_desc[_ci];
    draw_set_colour(make_colour_rgb(155, 150, 195));
    for (var _d = 0; _d < 3; _d++) {
        draw_text_transformed(_spr_cx, cards_y + 138 + _d * 20, _desc[_d], 1, 1, 0);
    }

    // Separator
    draw_set_colour(_icol);
    draw_set_alpha(0.4);
    draw_rectangle(_cx + 10, cards_y + 205, _cx + card_w - 10, cards_y + 207, false);
    draw_set_alpha(1);

    // Stat bars
    var _bar_x  = _cx + 12;
    var _bar_w  = card_w - 24;
    var _bar_h  = 8;
    var _bar_y0 = cards_y + 215;
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

// Left scroll arrow — visible when not at start
if (scroll_offset > 0) {
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_colour(make_colour_rgb(200, 180, 255));
    draw_text_transformed(cards_x0 - 28, cards_y + card_h / 2, "<", 3, 3, 0);
}

// Right scroll arrow — visible when not at end
if (scroll_offset < scroll_max) {
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_colour(make_colour_rgb(200, 180, 255));
    draw_text_transformed(cards_x0 + 5 * card_w + 4 * card_gap + 28, cards_y + card_h / 2, ">", 3, 3, 0);
}

// Choose button
draw_set_halign(fa_center);
scr_draw_pixel_button(btn_cx - btn_w / 2, btn_cy - btn_h / 2, btn_w, btn_h,
                      "CHOOSE CREATURE", btn_hovered, 2);

draw_set_alpha(1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_white);
