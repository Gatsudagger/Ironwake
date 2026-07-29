var _gc = obj_game_controller;
if (!instance_exists(_gc)) exit;
var _c = creature;
if (!is_struct(_c)) exit;

var _has_bs = variable_instance_exists(_gc, "biome_bonus_state");
var _bs     = _has_bs ? _gc.biome_bonus_state : undefined;

// Full-screen panel
scr_draw_panel(0, 0, 1366, 768);

draw_set_font(-1);

// ── Header ──────────────────────────────────────────────────────────────────
draw_set_halign(fa_center);
draw_set_valign(fa_top);

draw_set_colour(make_colour_rgb(255, 220, 100));
draw_text_transformed(683, 24, _c.name, 2.2, 2.2, 0);

draw_set_colour(make_colour_rgb(180, 180, 255));
draw_text_transformed(683, 66, global.creature_data[_c.species].name, 1.4, 1.4, 0);

draw_set_colour(make_colour_rgb(140, 200, 160));
draw_text_transformed(460, 96, "Gen " + string(_c.generation), 1.1, 1.1, 0);
draw_set_colour(make_colour_rgb(255, 160, 200));
draw_text_transformed(906, 96, "Bond: " + string(_c.bond), 1.1, 1.1, 0);

draw_set_colour(make_colour_rgb(60, 60, 120));
draw_rectangle(40, 118, 1326, 120, false);

// ── Stat Bars ───────────────────────────────────────────────────────────────
var _stat_keys   = [STAT_STRENGTH, STAT_AGILITY, STAT_DEXTERITY, STAT_STAMINA,
                    STAT_INTELLECT, STAT_WILLPOWER, STAT_DEFENSE, STAT_VITALITY];
var _stat_labels = ["STR", "AGI", "DEX", "STA", "INT", "WIL", "DEF", "VIT"];
var _base_keys   = ["base_strength", "base_agility", "base_dexterity", "base_stamina",
                    "base_intellect", "base_willpower", "base_defense", "base_vitality"];

var _bar_x   = 145;
var _bar_w   = 400;
var _bar_h   = 22;
var _label_x = 136;
var _val_x   = 555;
var _row_h   = 56;
var _start_y = 132;

for (var _i = 0; _i < 8; _i++) {
    var _sy    = _start_y + _i * _row_h;
    var _skey  = _stat_keys[_i];
    var _col   = scr_get_stat_colour(_skey);
    var _base  = variable_struct_get(_c, _base_keys[_i]);
    var _raw_b = (!is_undefined(_bs)) ? _bs.bonuses[$ _skey] : undefined;
    var _bonus = is_undefined(_raw_b) ? 0 : _raw_b;
    var _eff   = _base + _bonus;

    // Label
    draw_set_halign(fa_right);
    draw_set_colour(_col);
    draw_text_transformed(_label_x, _sy + 8, _stat_labels[_i], 1.1, 1.1, 0);

    // Bar background
    draw_set_colour(make_colour_rgb(20, 20, 46));
    draw_rectangle(_bar_x, _sy, _bar_x + _bar_w, _sy + _bar_h, false);

    // Base fill
    draw_set_colour(_col);
    draw_rectangle(_bar_x, _sy, _bar_x + (_base / 100.0) * _bar_w, _sy + _bar_h, false);

    // Bonus fill (yellow, stacked after base)
    if (_bonus > 0) {
        var _bx_start = _bar_x + (_base / 100.0) * _bar_w;
        var _bx_end   = _bar_x + (_eff  / 100.0) * _bar_w;
        draw_set_colour(make_colour_rgb(255, 245, 80));
        draw_rectangle(_bx_start, _sy, _bx_end, _sy + _bar_h, false);
    }

    // Bar border
    draw_set_colour(make_colour_rgb(44, 44, 80));
    draw_rectangle(_bar_x, _sy, _bar_x + _bar_w, _sy + _bar_h, true);

    // Value text: base   or   base + bonus = eff
    draw_set_halign(fa_left);
    draw_set_colour(make_colour_rgb(210, 210, 255));
    var _vstr = (_bonus > 0)
        ? (string(_base) + " + " + string(_bonus) + " = " + string(_eff))
        : string(_eff);
    draw_text_transformed(_val_x, _sy + 8, _vstr, 1, 1, 0);
}

// ── Bottom info ──────────────────────────────────────────────────────────────
draw_set_colour(make_colour_rgb(60, 60, 120));
draw_rectangle(40, 580, 1326, 582, false);

draw_set_halign(fa_left);

// Biome
var _biome_str;
if (_c.biome < 0) {
    _biome_str = "No Biome";
    draw_set_colour(make_colour_rgb(110, 110, 160));
} else {
    _biome_str = scr_biome_get_data(_c.biome).name;
    draw_set_colour(make_colour_rgb(100, 180, 220));
}
draw_text_transformed(50, 594, "Biome:  " + _biome_str, 1.2, 1.2, 0);

// Age
draw_set_colour(make_colour_rgb(160, 210, 160));
draw_text_transformed(420, 594, "Age:  " + string(_c.age_days) + " days", 1.2, 1.2, 0);

// Back button
scr_draw_pixel_button(btn_bx, btn_by, btn_bw, btn_bh, "< Back", btn_hover, 1.1);

// Escape hint
draw_set_halign(fa_center);
draw_set_colour(make_colour_rgb(70, 70, 120));
draw_text_transformed(683, 730, "[ Esc ] Back", 1, 1, 0);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_white);
