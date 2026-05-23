for (var _i = 0; _i < 3; _i++) {
    if (skill_cooldowns[_i] > 0) skill_cooldowns[@ _i]--;
}

var _gc = obj_game_controller;
if (!instance_exists(_gc)) exit;

var _creature_id = _gc.starter_creature;
if (_creature_id < 0) exit;

var _skills = global.creature_data[_creature_id].skills;

// Keys 1/2/3 trigger skill slots 0/1/2
for (var _slot = 0; _slot < 3; _slot++) {
    if (keyboard_check_pressed(key_codes[_slot])) {
        if (skill_cooldowns[_slot] == 0) {
            var _sidx = _skills[_slot];
            var _skill = global.skill_data[_sidx];
            if (_gc.creature_stamina >= _skill.stamina_cost) {
                _gc.creature_stamina -= _skill.stamina_cost;
                skill_cooldowns[@ _slot] = _skill.cooldown;
            }
        }
    }
}
