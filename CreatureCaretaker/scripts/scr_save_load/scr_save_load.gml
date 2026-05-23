#macro SAVE_FILE "cc_save.json"

function scr_save_game() {
	var gc = obj_game_controller;
	var data = {
		player_name:      gc.player_name,
		skin_tone:        gc.skin_tone,
		hair_color:       gc.hair_color,
		hair_style:       gc.hair_style,
		biome_id:         gc.biome_id,
		starter_creature: gc.starter_creature,
		creature_stamina: gc.creature_stamina,
		day_number:       global.day_number,
		minutes_in_day:   global.minutes_in_day,
	};
	var f = file_text_open_write(SAVE_FILE);
	file_text_write_string(f, json_stringify(data));
	file_text_close(f);
	show_debug_message("Game saved — Day " + string(global.day_number));
}

function scr_load_game() {
	if (!file_exists(SAVE_FILE)) return false;

	var f = file_text_open_read(SAVE_FILE);
	var raw = "";
	while (!file_text_eof(f)) {
		raw += file_text_readln(f);
	}
	file_text_close(f);
	if (raw == "") return false;

	var data = json_parse(raw);
	with (obj_game_controller) {
		player_name       = data.player_name;
		skin_tone         = data.skin_tone;
		hair_color        = data.hair_color;
		hair_style        = data.hair_style;
		biome_id          = data.biome_id;
		starter_creature  = data.starter_creature;
		creature_stamina  = data.creature_stamina;
		creature_roster   = [starter_creature];
		biome_bonus_state = scr_biome_bonus_init(starter_creature, biome_id);
		creature_stamina_max = scr_creature_get_stat(starter_creature, STAT_STAMINA);
	}

	scr_time_init();
	global.day_number     = data.day_number;
	global.minutes_in_day = data.minutes_in_day;
	show_debug_message("Game loaded — Day " + string(global.day_number));
	return true;
}
