if (result_pending) {
	// Hide combatants so they don't overlap the results panel
	if (instance_exists(obj_combat_player)) obj_combat_player.visible = false;
	if (instance_exists(obj_combat_enemy))  obj_combat_enemy.visible  = false;
	if (instance_exists(obj_damage_number)) with (obj_damage_number) instance_destroy();
	if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
		room_goto(rm_ranch);
	}
	// Mouse click on Continue button
	var _btn_x = room_width / 2;
	var _btn_y = 490;
	if (mouse_check_button_pressed(mb_left) && point_distance(mouse_x, mouse_y, _btn_x, _btn_y) < 120) {
		room_goto(rm_ranch);
	}
	exit;
}

// Player dead → lose
if (instance_exists(obj_combat_player) && obj_combat_player.vitality <= 0) {
	scr_combat_end("lose");
	exit;
}

// Enemy dead → win
if (instance_exists(obj_combat_enemy) && obj_combat_enemy.vitality <= 0) {
	scr_combat_end("win");
	exit;
}

// Flee key
if (keyboard_check_pressed(vk_escape)) {
	scr_combat_end("flee");
}
