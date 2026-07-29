var mx = mouse_x;
var my = mouse_y;

// Carousel scroll — arrow keys or A/D
if (keyboard_check_pressed(vk_left)  || keyboard_check_pressed(ord("A"))) {
	scroll_offset = max(0, scroll_offset - 1);
}
if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"))) {
	scroll_offset = min(scroll_max, scroll_offset + 1);
}

// Carousel scroll — mouse click on arrow indicators
var _arrow_cy = cards_y + card_h / 2;
if (mouse_check_button_pressed(mb_left)) {
	var _lax = cards_x0 - 28;
	if (point_distance(mx, my, _lax, _arrow_cy) < 40) {
		scroll_offset = max(0, scroll_offset - 1);
	}
	var _rax = cards_x0 + 5 * card_w + 4 * card_gap + 28;
	if (point_distance(mx, my, _rax, _arrow_cy) < 40) {
		scroll_offset = min(scroll_max, scroll_offset + 1);
	}
}

// Card selection — map visible card position back to creature index via scroll_offset
for (var i = 0; i < 5; i++) {
	var cx = cards_x0 + i * (card_w + card_gap);
	if (mouse_check_button_pressed(mb_left)
	 && mx > cx && mx < cx + card_w
	 && my > cards_y && my < cards_y + card_h) {
		selected_creature = i + scroll_offset;
	}
}

// Choose button
btn_hovered = (mx > btn_cx - btn_w / 2 && mx < btn_cx + btn_w / 2
            && my > btn_cy - btn_h / 2 && my < btn_cy + btn_h / 2);

if (btn_hovered && mouse_check_button_pressed(mb_left)) {
	with (obj_game_controller) {
		starter_creature     = scr_creature_create(other.selected_creature);
		creature_roster      = [starter_creature];
		biome_bonus_state    = scr_biome_bonus_init(starter_creature.species, biome_id);
		creature_stamina_max = starter_creature.base_stamina;
		creature_stamina     = creature_stamina_max;
		scr_time_init();
	}
	room_goto(rm_name_creature);
}
