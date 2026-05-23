// Only run the time system once setup is fully complete
if (starter_creature < 0 || biome_id < 0) exit;

scr_time_update();

// Trigger full stamina regen once per Night phase
if (scr_time_check_night_regen()) {
	creature_stamina = creature_stamina_max;
}

// Auto-save at the start of each new day
if (global.day_just_advanced) {
	global.day_just_advanced = false;
	scr_save_game();
}
