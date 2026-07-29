// Dead — combat_manager handles room transition
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
var _stam_mult = scr_get_bond_stamina_mult(creature.bond);
if (stamina_regen_timer >= floor(30 / _stam_mult)) {
	stamina_regen_timer = 0;
	combat_stamina = min(combat_stamina_max, combat_stamina + 1);
}

// ── Movement ───────────────────────────────────────────────────────────────────
var _eff_spd = spd * slow_factor;
var _mv      = false;

if (keyboard_check(vk_left)  || keyboard_check(ord("A"))) { x -= _eff_spd; facing = WALK_LEFT;  _mv = true; }
if (keyboard_check(vk_right) || keyboard_check(ord("D"))) { x += _eff_spd; facing = WALK_RIGHT; _mv = true; }
if (keyboard_check(vk_up)    || keyboard_check(ord("W"))) { y -= _eff_spd; facing = WALK_UP;    _mv = true; }
if (keyboard_check(vk_down)  || keyboard_check(ord("S"))) { y += _eff_spd; facing = WALK_DOWN;  _mv = true; }

x = clamp(x, 40, 760);
y = clamp(y, 80, 440);

if (_mv) {
	anim_frame = (anim_frame + anim_speed) mod 4;
} else {
	anim_frame = 0;
}

// ── Move hotkeys ───────────────────────────────────────────────────────────────
var _pmoves = scr_combat_get_moves(species);
if (keyboard_check_pressed(ord("1")) && cooldown[0] == 0) {
	var _cost0 = scr_get_move_stamina_cost(_pmoves[0]);
	if (combat_stamina >= _cost0) { combat_stamina -= _cost0; scr_combat_use_move(id, obj_combat_enemy, 0); }
}
if (keyboard_check_pressed(ord("2")) && cooldown[1] == 0) {
	var _cost1 = scr_get_move_stamina_cost(_pmoves[1]);
	if (combat_stamina >= _cost1) { combat_stamina -= _cost1; scr_combat_use_move(id, obj_combat_enemy, 1); }
}
if (keyboard_check_pressed(ord("3")) && cooldown[2] == 0) {
	var _cost2 = scr_get_move_stamina_cost(_pmoves[2]);
	if (combat_stamina >= _cost2) { combat_stamina -= _cost2; scr_combat_use_move(id, obj_combat_enemy, 2); }
}

// ── Item hotkeys ───────────────────────────────────────────────────────────────
if (keyboard_check_pressed(ord("4"))) {
	var _islot0 = global.hotbar_items[0];
	if (_islot0 >= 0 && _islot0 < array_length(global.inventory)) scr_inventory_use(_islot0, id);
}
if (keyboard_check_pressed(ord("5"))) {
	var _islot1 = global.hotbar_items[1];
	if (_islot1 >= 0 && _islot1 < array_length(global.inventory)) scr_inventory_use(_islot1, id);
}
if (keyboard_check_pressed(ord("6"))) {
	var _islot2 = global.hotbar_items[2];
	if (_islot2 >= 0 && _islot2 < array_length(global.inventory)) scr_inventory_use(_islot2, id);
}
