if (instance_exists(obj_menu_screen) && obj_menu_screen.visible) exit;

// Only run the time system once setup is fully complete
if (starter_creature < 0 || biome_id < 0) exit;

scr_time_update();
if (is_struct(starter_creature) && starter_creature.active_task != -1) {
    show_debug_message("Checking task: end=" + string(starter_creature.task_end_minute) + " now=" + string(global.minutes_in_day));
}
if (is_struct(starter_creature)) scr_task_update(starter_creature);

// Trigger full stamina regen once per Night phase
if (scr_time_check_night_regen()) {
	creature_stamina = creature_stamina_max;
}

// Auto-save at the start of each new day
if (global.day_just_advanced) {
	global.day_just_advanced = false;
	scr_biome_growth_apply(biome_bonus_state);
	scr_save_game();
}

// TEMP: press T to test combat
if (keyboard_check_pressed(ord("T")) && is_struct(starter_creature) && room == rm_ranch) {
	var _enemy = scr_creature_create(SPECIES.RAPTOWL);
	_enemy.name = "Wild Raptowl";
	scr_combat_init(starter_creature, _enemy, biome_id);
}
