var gc = obj_game_controller;

// Proximity to creature
near_creature = false;
if (instance_exists(obj_creature) && instance_exists(obj_player)) {
	near_creature = (point_distance(obj_player.x, obj_player.y,
	                                obj_creature.x, obj_creature.y) < interact_dist);
}

if (feedback_timer > 0) feedback_timer--;

// Open task menu
if (near_creature && !show_tasks && !show_stats && keyboard_check_pressed(ord("E"))) {
	show_tasks = true;
	selected   = 0;
}

// Toggle stats screen (works anywhere in ranch)
if (keyboard_check_pressed(vk_tab)) {
	show_stats = !show_stats;
	show_tasks = false;
}

// Close any open menu
if (keyboard_check_pressed(vk_escape)) {
	show_tasks = false;
	show_stats = false;
}

if (show_tasks) {
	var n = array_length(task_names);
	if (keyboard_check_pressed(vk_up))   selected = (selected - 1 + n) mod n;
	if (keyboard_check_pressed(vk_down)) selected = (selected + 1)     mod n;

	if (keyboard_check_pressed(vk_enter)) {
		var cost = task_costs[selected];
		if (gc.creature_stamina >= cost || cost == 0) {
			gc.creature_stamina = max(0, gc.creature_stamina - cost);

			switch (selected) {
				case 0: // Train — biome growth
					scr_biome_growth_apply(gc.biome_bonus_state);
					break;
				case 1: // Forage — small stamina restore
					gc.creature_stamina = min(gc.creature_stamina_max, gc.creature_stamina + 10);
					break;
				case 2: // Rest — restore 35% of max
					gc.creature_stamina = min(gc.creature_stamina_max,
						gc.creature_stamina + round(gc.creature_stamina_max * 0.35));
					break;
			}

			// Advance in-game time
			global.minutes_in_day += task_mins[selected];
			while (global.minutes_in_day >= TIME_MINS_PER_GAME_DAY) {
				global.minutes_in_day -= TIME_MINS_PER_GAME_DAY;
				global.day_number++;
				global.night_regen_done  = false;
				global.day_just_advanced = true;
			}
			global.time_phase = scr_time_get_phase();

			feedback_msg   = task_names[selected] + " complete!";
			feedback_timer = 150;
			show_tasks     = false;
		} else {
			feedback_msg   = "Not enough stamina!";
			feedback_timer = 90;
		}
	}
}
