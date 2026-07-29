depth = 1000;
result_pending = false;

global.shake_intensity = 0;
global.shake_duration  = 0;

function scr_screen_shake(intensity, duration) {
	global.shake_intensity = intensity;
	global.shake_duration  = duration;
}
result_delay   = 120;  // 2s pause before room transition
result_str     = "";

// Spawn combatants
instance_create_layer(150, 280, "Instances", obj_combat_player);
instance_create_layer(650, 280, "Instances", obj_combat_enemy);

/// @desc Ends combat, writes result back to global state, and returns to rm_ranch.
/// @param {string} result   "win", "lose", or "flee"
function scr_combat_end(result) {
	if (result_pending) exit;
	result_pending = true;
	result_str     = result;

	global.combat_state.result = result;
	global.combat_state.active = false;

	var _pc = global.combat_state.player_creature;
	var _ec = global.combat_state.enemy_creature;

	// Write post-combat vitality back to creature struct
	if (instance_exists(obj_combat_player)) {
		var _pi = obj_combat_player;
		_pc.current_health = max(0, floor(_pi.vitality / 5));
	}

	// XP calculation (spec §16.2)
	var _enemy_stat_sum = _ec.base_strength + _ec.base_agility + _ec.base_dexterity +
	    _ec.base_stamina + _ec.base_intellect + _ec.base_willpower +
	    _ec.base_defense + _ec.base_vitality;

	var _int_mult = 1 + (_pc.base_intellect / 200);
	var _base_xp  = 0;

	if (result == "win") {
		_base_xp = floor(_enemy_stat_sum / 20);
		if (instance_exists(obj_combat_player) && obj_combat_player.vitality < obj_combat_player.vitality_max * 0.20) {
			_base_xp += 10;
		}
	} else if (result == "lose") {
		_base_xp = 8;
	}

	var _bond_mult = scr_get_bond_xp_mult(_pc.bond);
	var _final_xp  = floor(_base_xp * _int_mult * _bond_mult);
	global.combat_state.xp_earned = _final_xp;
	_pc.xp += _final_xp;

	// Bond increment — capped at 50
	_pc.bond = min(50, _pc.bond + 1);
	global.combat_state.bond_after = _pc.bond;

	// Item drops
	global.combat_state.item_dropped_id   = -1;
	global.combat_state.item_dropped_tier = "";

	var _rand_common   = random(1);
	var _rand_uncommon = random(1);
	var _rand_rare     = random(1);

	if (result == "win" || result == "lose") {
		if (_rand_common < 0.10) {
			var _cid = irandom(1);
			scr_inventory_add(_cid, 1);
			global.combat_state.item_dropped_id   = _cid;
			global.combat_state.item_dropped_tier = "common";
		}
	}
	if (result == "win") {
		if (_rand_uncommon < 0.05) {
			var _uid = 2 + irandom(2);
			scr_inventory_add(_uid, 1);
			global.combat_state.item_dropped_id   = _uid;
			global.combat_state.item_dropped_tier = "uncommon";
		}
		if (_rand_rare < 0.01) {
			var _rid = 5 + irandom(7);
			scr_inventory_add(_rid, 1);
			global.combat_state.item_dropped_id   = _rid;
			global.combat_state.item_dropped_tier = "rare";
		}
	}

	// room_goto deferred — Step waits for Enter key then transitions
}
