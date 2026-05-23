near_player = false;
if (instance_exists(obj_player)) {
	near_player = (point_distance(x, y, obj_player.x, obj_player.y) < interact_dist);
}

// Block while any UI is open
if (instance_exists(obj_task_ui)) {
	var ui = obj_task_ui;
	if (ui.show_tasks || ui.show_stats || ui.show_pause) exit;
}

// Don't fire E if the player is also near the creature
var near_creat = (instance_exists(obj_task_ui) && obj_task_ui.near_creature);

if (near_player && !near_creat && keyboard_check_pressed(ord("E"))) {
	var gc = obj_game_controller;

	// Advance 12 in-game hours
	global.minutes_in_day += 720;
	while (global.minutes_in_day >= TIME_MINS_PER_GAME_DAY) {
		global.minutes_in_day -= TIME_MINS_PER_GAME_DAY;
		global.day_number++;
		global.night_regen_done  = false;
		global.day_just_advanced = true;
	}
	global.time_phase = scr_time_get_phase();

	// Sleep restores 50% creature stamina
	gc.creature_stamina = min(gc.creature_stamina_max,
		gc.creature_stamina + round(gc.creature_stamina_max * 0.50));

	if (instance_exists(obj_task_ui)) {
		var cname = (gc.starter_creature >= 0) ? global.creature_data[gc.starter_creature].name : "Creature";
		obj_task_ui.feedback_msg   = "You slept. " + cname + " feels rested.";
		obj_task_ui.feedback_timer = 180;
	}
}
