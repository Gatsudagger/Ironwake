/// @desc Fires a move from attacker toward target.
///       Handles melee hit, projectile spawn, buff, and debuff types.
/// @param {Id.Instance} attacker_obj   obj_combat_player or obj_combat_enemy
/// @param {Id.Instance} target_obj     opposing combatant instance
/// @param {real}        move_index     0, 1, or 2
function scr_combat_use_move(attacker_obj, target_obj, move_index) {
	with (attacker_obj) {
		var _mv    = global.combat_moves[species][move_index];
		var _cdata = creature;

		// Start cooldown
		cooldown[move_index] = _mv.cooldown_secs;

		// ── VFX ───────────────────────────────────────────────────────────────────
		{
			var _mn  = _mv.name;
			var _ang = instance_exists(target_obj)
			    ? point_direction(x, y, target_obj.x, target_obj.y) : 0;

			if (_mn == "Lunge" || _mn == "Bone Charge" || _mn == "Shell Slam") {
				scr_spawn_vfx(VFX_TYPE.DUST_PUFF, x, y, c_white, c_white, 30, 20, _ang);
			} else if (_mn == "Jaw Snap" || _mn == "Headbutt" || _mn == "Spike Roll") {
				if (instance_exists(target_obj))
				    scr_spawn_vfx(VFX_TYPE.IMPACT_CIRCLE, target_obj.x, target_obj.y, c_white, c_white, 25, 15, _ang);
			} else if (_mn == "Six-Claw Slash" || _mn == "Slither Strike" || _mn == "Talon Swipe" || _mn == "Dive Bomb" || _mn == "Wing Dust") {
				if (instance_exists(target_obj))
				    scr_spawn_vfx(VFX_TYPE.SLASH_LINES, target_obj.x, target_obj.y, c_white, c_white, 35, 18, _ang);
			} else if (_mn == "Howl") {
				scr_spawn_vfx(VFX_TYPE.RING_PULSE, x, y, make_colour_rgb(255, 150, 50), c_yellow, 60, 40, 0);
			} else if (_mn == "Overcharge") {
				scr_spawn_vfx(VFX_TYPE.GLOW_PULSE, x, y, make_colour_rgb(255, 240, 80), c_white, 50, 50, 0);
			} else if (_mn == "Iron Shell" || _mn == "Iron Fortress") {
				scr_spawn_vfx(VFX_TYPE.GLOW_PULSE, x, y, make_colour_rgb(150, 150, 220), c_white, 55, 50, 0);
			} else if (_mn == "Moonveil") {
				scr_spawn_vfx(VFX_TYPE.RING_PULSE, x, y, make_colour_rgb(180, 100, 255), make_colour_rgb(100, 50, 200), 65, 45, 0);
			} else if (_mn == "Screech") {
				if (instance_exists(target_obj))
				    scr_spawn_vfx(VFX_TYPE.RING_PULSE, target_obj.x, target_obj.y, make_colour_rgb(220, 80, 80), make_colour_rgb(180, 40, 40), 80, 50, 0);
			}
		}

		// ── BUFF ──────────────────────────────────────────────────────────────────
		if (_mv.type == MOVE_TYPE.BUFF) {
			var _pot      = scr_combat_calc_potency(_cdata, move_index);
			var _duration = round(_mv.status_duration_secs * _pot);
			array_push(active_buffs, {
				base_effect: _mv.base_effect,
				duration:    _duration,
				timer:       _duration,
				is_buff:     true,
			});
			// Overcharge: flag next-hit multiplier instead
			if (_mv.name == "Overcharge") {
				next_hit_mult = _mv.base_effect;
			}
			exit;
		}

		// ── DEBUFF ────────────────────────────────────────────────────────────────
		if (_mv.type == MOVE_TYPE.DEBUFF) {
			if (instance_exists(target_obj)) {
				var _pot         = scr_combat_calc_potency(_cdata, move_index);
				var _duration    = round(_mv.status_duration_secs * _pot);
				var _slow_amount = _mv.base_effect;
				with (target_obj) {
					slow_factor = 1.0 - _slow_amount;
					slow_dur    = _duration;
				}
			}
			exit;
		}

		// ── PROJECTILE ────────────────────────────────────────────────────────────
		if (_mv.type == MOVE_TYPE.PROJECTILE) {
			if (instance_exists(target_obj)) {
				var _proj = instance_create_layer(x, y - 30, "Instances", obj_combat_projectile);
				_proj.owner_obj    = id;
				_proj.target_obj   = target_obj;
				_proj.move_data    = _mv;
				_proj.move_index   = move_index;
				_proj.attacker_ref = _cdata;
				_proj.nhm          = next_hit_mult;
				next_hit_mult      = 1.0;
			}
			exit;
		}

		// ── MELEE (with optional dash) ─────────────────────────────────────────────
		if (instance_exists(target_obj)) {
			var _dist = point_distance(x, y, target_obj.x, target_obj.y);
			if (_dist <= _mv.range_px) {
				// Apply damage
				var _raw_stat = _cdata[$ "base_" + _mv.stat_key];
				var _eff_stat = scr_effective_stat(_raw_stat);
				var _raw      = _mv.base_damage + (_eff_stat * _mv.stat_mod);
				var _eff_def  = scr_effective_stat(target_obj.creature.base_defense);
				var _def_ratio = _eff_def / (_eff_def + 50);
				var _dmg      = max(1, floor(_raw * (1 - _def_ratio)));
				var _bond_dmg = scr_get_bond_damage_mult(_cdata.bond);
				_dmg = floor(_dmg * _bond_dmg);
				next_hit_mult = 1.0;
				with (target_obj) { vitality = max(0, vitality - _dmg); }
				target_obj.hit_flash = 12;
				scr_screen_shake(6, 8);
				if (target_obj == obj_combat_enemy)  global.combat_state.damage_dealt += _dmg;
				if (target_obj == obj_combat_player) global.combat_state.damage_taken += _dmg;
				var _dn      = instance_create_layer(target_obj.x, target_obj.y - 40, "Instances", obj_damage_number);
				_dn.value   = _dmg;
				_dn.is_crit = (_dmg >= 50);

				// Status effect
				if (_mv.status_effect == STATUS.KNOCKBACK) {
					var _dir = point_direction(target_obj.x, target_obj.y, x, y);
					with (target_obj) {
						knockback_vx  = lengthdir_x(6, _dir + 180);
						knockback_vy  = lengthdir_y(6, _dir + 180);
						knockback_dur = _mv.status_duration_secs;
					}
				} else if (_mv.status_effect == STATUS.STUN) {
					var _pot = scr_combat_calc_potency(_cdata, move_index);
					with (target_obj) { stun_dur = round(_mv.status_duration_secs * _pot); }
				} else if (_mv.status_effect == STATUS.POISON) {
					var _pot = scr_combat_calc_potency(_cdata, move_index);
					with (target_obj) {
						poison_dur  = round(_mv.status_duration_secs * _pot);
						poison_tick = 0;
					}
				}
			}

			// Dash toward target
			if (_mv.dash_speed > 0) {
				var _dir = point_direction(x, y, target_obj.x, target_obj.y);
				x = clamp(x + lengthdir_x(_mv.dash_speed, _dir), 20, 780);
				y = clamp(y + lengthdir_y(_mv.dash_speed, _dir), 60, 580);
			}
		}
	}
}
