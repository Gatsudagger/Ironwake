#macro SAVE_FILE "cc_save.json"

function scr_save_game() {
	var gc = obj_game_controller;

	// Snapshot the roster — json_stringify handles arrays of structs natively
	var _roster = [];
	for (var i = 0; i < array_length(gc.creature_roster); i++) {
		array_push(_roster, gc.creature_roster[i]);
	}

	var data = {
		player_name:     gc.player_name,
		skin_tone:       gc.skin_tone,
		hair_color:      gc.hair_color,
		hair_style:      gc.hair_style,
		biome_id:        gc.biome_id,
		creature_roster: _roster,
		day_number:      global.day_number,
		minutes_in_day:  global.minutes_in_day,
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
		player_name  = data.player_name;
		skin_tone    = data.skin_tone;
		hair_color   = data.hair_color;
		hair_style   = data.hair_style;
		biome_id     = data.biome_id;

		// Rebuild roster — json_parse returns each entry as a struct already
		var _saved = data.creature_roster;
		creature_roster = [];
		for (var i = 0; i < array_length(_saved); i++) {
			array_push(creature_roster, _saved[i]);
		}
		global.creature_roster = creature_roster;

		starter_creature     = creature_roster[0];
		biome_bonus_state    = scr_biome_bonus_init(starter_creature.species, biome_id);
		creature_stamina_max = starter_creature.base_stamina;
		creature_stamina     = starter_creature.current_stamina;
	}

	scr_time_init();
	global.day_number     = data.day_number;
	global.minutes_in_day = data.minutes_in_day;
	show_debug_message("Game loaded — Day " + string(global.day_number));
	return true;
}
