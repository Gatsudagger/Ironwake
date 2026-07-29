if (!instance_exists(target_obj)) {
	instance_destroy();
	exit;
}

// Move toward target
dir = point_direction(x, y, target_obj.x, target_obj.y - 30);
x  += lengthdir_x(spd, dir);
y  += lengthdir_y(spd, dir);
image_index = (image_index + image_speed) mod 6;

// Hit check
var _dist = point_distance(x, y, target_obj.x, target_obj.y - 30);
if (_dist < 20) {
	var _mv       = global.combat_moves[attacker_ref.species][move_index];
	var _raw_stat = attacker_ref[$ "base_" + _mv.stat_key];
	var _eff_stat = scr_effective_stat(_raw_stat);
	var _raw      = _mv.base_damage + (_eff_stat * _mv.stat_mod);
	var _eff_def  = scr_effective_stat(target_obj.creature.base_defense);
	var _def_ratio = _eff_def / (_eff_def + 50);
	var _dmg      = max(1, floor(_raw * (1 - _def_ratio) * nhm));
	with (target_obj) { vitality = max(0, vitality - _dmg); }
	target_obj.hit_flash = 12;
	if (target_obj == obj_combat_enemy)  global.combat_state.damage_dealt += _dmg;
	if (target_obj == obj_combat_player) global.combat_state.damage_taken += _dmg;
	var _dn = instance_create_layer(target_obj.x, target_obj.y - 40, "Instances", obj_damage_number);
	_dn.value = _dmg;
	_dn.col   = make_colour_rgb(255, 80, 80);

	// Status on hit
	if (_mv.status_effect == STATUS.SLOW) {
		var _pot = scr_combat_calc_potency(attacker_ref, move_index);
		with (target_obj) {
			slow_factor = 0.5;
			slow_dur    = round(_mv.status_duration_secs * _pot);
		}
	} else if (_mv.status_effect == STATUS.POISON) {
		var _pot = scr_combat_calc_potency(attacker_ref, move_index);
		with (target_obj) {
			poison_dur  = round(_mv.status_duration_secs * _pot);
			poison_tick = 0;
		}
	}

	instance_destroy();
}

// Despawn if offscreen
if (x < 0 || x > 800 || y < 0 || y > 600) instance_destroy();
