if (vitality <= 0) exit;
if (hit_flash > 0) hit_flash--;

// ── Status effects ─────────────────────────────────────────────────────────────
if (stun_dur > 0) {
	stun_dur--;
	exit;
}

if (slow_dur > 0) {
	slow_dur--;
	if (slow_dur == 0) slow_factor = 1.0;
}

if (poison_dur > 0) {
	poison_dur--;
	poison_tick++;
	if (poison_tick >= 60) {
		poison_tick = 0;
		vitality = max(0, vitality - 1);
	}
}

// ── Knockback ──────────────────────────────────────────────────────────────────
if (knockback_dur > 0) {
	knockback_dur--;
	x = clamp(x + knockback_vx, 40, 760);
	y = clamp(y + knockback_vy, 80, 440);
	exit;
}

// ── Buff timers ────────────────────────────────────────────────────────────────
for (var _i = array_length(active_buffs) - 1; _i >= 0; _i--) {
	active_buffs[_i].timer--;
	if (active_buffs[_i].timer <= 0) array_delete(active_buffs, _i, 1);
}

// ── Cooldowns ──────────────────────────────────────────────────────────────────
for (var _i = 0; _i < 3; _i++) {
	if (cooldown[_i] > 0) cooldown[_i]--;
}

// ── Stamina regen ──────────────────────────────────────────────────────────────
stamina_regen_timer++;
if (stamina_regen_timer >= 30) {
	stamina_regen_timer = 0;
	combat_stamina = min(combat_stamina_max, combat_stamina + 1);
}

// ── Chase player ───────────────────────────────────────────────────────────────
if (instance_exists(obj_combat_player)) {
	var _px   = obj_combat_player.x;
	var _py   = obj_combat_player.y;
	var _dist = point_distance(x, y, _px, _py);
	var _eff_spd = spd * slow_factor;

	if (_dist > 40) {
		var _dir = point_direction(x, y, _px, _py);
		x += lengthdir_x(_eff_spd, _dir);
		y += lengthdir_y(_eff_spd, _dir);
		x = clamp(x, 40, 760);
		y = clamp(y, 80, 440);

		var _adx = _px - x;
		var _ady = _py - y;
		if (abs(_adx) > abs(_ady)) facing = (_adx < 0) ? WALK_LEFT : WALK_RIGHT;
		else facing = (_ady < 0) ? WALK_UP : WALK_DOWN;

		anim_frame = (anim_frame + anim_speed) mod 4;
	} else {
		anim_frame = 0;
	}

	// ── AI move selection with telegraph phase ────────────────────────────────
	if (telegraphing) {
		telegraph_timer--;
		if (telegraph_timer <= 0) {
			telegraphing = false;
			var _emoves = scr_combat_get_moves(species);
			var _ecost  = scr_get_move_stamina_cost(_emoves[pending_move_index]);
			if (combat_stamina >= _ecost) {
				combat_stamina -= _ecost;
				scr_combat_use_move(id, obj_combat_player, pending_move_index);
			}
		}
	} else {
		ai_think_timer++;
		if (ai_think_timer >= ai_think_rate) {
			ai_think_timer = 0;
			var _avail = [];
			for (var _i = 0; _i < 3; _i++) {
				if (cooldown[_i] == 0) array_push(_avail, _i);
			}
			if (array_length(_avail) > 0) {
				var _choice = _avail[irandom(array_length(_avail) - 1)];
				var _emoves = scr_combat_get_moves(species);
				var _ecost  = scr_get_move_stamina_cost(_emoves[_choice]);
				if (combat_stamina >= _ecost) {
					pending_move_index = _choice;
					telegraphing       = true;
					telegraph_timer    = telegraph_duration;
				}
			}
		}
	}
}
