var _gc = obj_game_controller;
if (!instance_exists(_gc)) exit;

var _creature_id = _gc.starter_creature;
if (_creature_id < 0) exit;

var _skills = global.creature_data[_creature_id].skills;

var _gui_w  = display_get_gui_width();
var _gui_h  = display_get_gui_height();
var _base_x = _gui_w / 2 - total_w / 2;
var _base_y = _gui_h - slot_size - 16;

for (var _slot = 0; _slot < 3; _slot++) {
    var _sx    = _base_x + _slot * (slot_size + slot_gap);
    var _sy    = _base_y;
    var _skill = global.skill_data[_skills[_slot]];
    var _cx    = _sx + slot_size / 2;

    // Slot background
    draw_set_color(c_black);
    draw_set_alpha(0.7);
    draw_rectangle(_sx, _sy, _sx + slot_size - 1, _sy + slot_size - 1, false);
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_rectangle(_sx, _sy, _sx + slot_size - 1, _sy + slot_size - 1, true);

    // Skill icon scaled from 32x32 spritesheet (16 icons per row)
    var _icol = _skill.icon_index mod 16;
    var _irow = _skill.icon_index div 16;
    draw_sprite_part_ext(spr_skill_icons, 0,
        _icol * 32, _irow * 32, 32, 32,
        _sx, _sy, icon_scale, icon_scale, c_white, 1);

    // Cooldown overlay — top-down fill proportional to remaining time
    if (skill_cooldowns[_slot] > 0) {
        var _frac = skill_cooldowns[_slot] / _skill.cooldown;
        draw_set_color(c_black);
        draw_set_alpha(0.55);
        draw_rectangle(_sx, _sy, _sx + slot_size - 1, _sy + round(_frac * slot_size) - 1, false);
        draw_set_alpha(1);

        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_font(-1);
        draw_text(_cx, _sy + slot_size / 2,
            string(ceil(skill_cooldowns[_slot] / fps_cache)));
    }

    // Key hint below slot
    draw_set_color(c_yellow);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_text(_cx, _sy + slot_size + 2, string(_slot + 1));

    // Stamina cost above slot
    draw_set_color(c_ltgray);
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    draw_text(_cx, _sy - 2, string(_skill.stamina_cost) + " SP");
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_set_alpha(1);
