var mx = mouse_x;
var my = mouse_y;

// Card selection
for (var i = 0; i < CREATURE.COUNT; i++) {
	var cx = cards_x0 + i * (card_w + card_gap);
	if (mouse_check_button_pressed(mb_left)
	 && mx > cx && mx < cx + card_w
	 && my > cards_y && my < cards_y + card_h) {
		selected_creature = i;
	}
}

// Choose button
btn_hovered = (mx > btn_cx - btn_w / 2 && mx < btn_cx + btn_w / 2
            && my > btn_cy - btn_h / 2 && my < btn_cy + btn_h / 2);

if (btn_hovered && mouse_check_button_pressed(mb_left)) {
	with (obj_game_controller) {
		starter_creature     = other.selected_creature;
		creature_roster      = [starter_creature];
		biome_bonus_state    = scr_biome_bonus_init(starter_creature, biome_id);
		creature_stamina_max = scr_creature_get_stat(starter_creature, STAT_STAMINA);
		creature_stamina     = creature_stamina_max;
		scr_time_init();
	}
	room_goto(rm_ranch);
}
