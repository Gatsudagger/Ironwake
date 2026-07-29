scr_draw_combat_background(global.combat_state.biome_id, room_width, room_height);

if (result_pending) {
	// Dark overlay
	draw_set_alpha(0.85);
	draw_set_colour(make_colour_rgb(8, 8, 20));
	draw_rectangle(0, 0, room_width, room_height, false);
	draw_set_alpha(1);

	var _cx = room_width / 2;
	var _cs = global.combat_state;

	// Result header
	draw_set_halign(fa_center);
	if (result_str == "win") {
		draw_set_colour(make_colour_rgb(255, 215, 0));
		draw_text_transformed(_cx, 120, "VICTORY!", 3.5, 3.5, 0);
	} else if (result_str == "lose") {
		draw_set_colour(make_colour_rgb(220, 60, 60));
		draw_text_transformed(_cx, 120, "DEFEATED", 3.5, 3.5, 0);
	} else {
		draw_set_colour(make_colour_rgb(180, 180, 255));
		draw_text_transformed(_cx, 120, "FLED", 3.5, 3.5, 0);
	}

	// Panel background — tall enough to cover bond row (430) and item row (475)
	scr_draw_panel(_cx - 240, 182, 480, 313);

	// Stats — labels left-aligned at _lx, values right-aligned at _rx
	draw_set_font(-1);
	var _lx = _cx - 210;
	var _rx = _cx + 210;

	// Creature name
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(255, 215, 0));
	draw_text_transformed(_cx, 200, _cs.player_creature.name, 1.3, 1.3, 0);

	// Damage Dealt
	draw_set_halign(fa_left);
	draw_set_colour(make_colour_rgb(180, 220, 255));
	draw_text_transformed(_lx, 250, "Damage Dealt", 1.1, 1.1, 0);
	draw_set_halign(fa_right);
	draw_set_colour(c_white);
	draw_text_transformed(_rx, 250, string(_cs.damage_dealt), 1.1, 1.1, 0);

	// Damage Taken
	draw_set_halign(fa_left);
	draw_set_colour(make_colour_rgb(180, 220, 255));
	draw_text_transformed(_lx, 295, "Damage Taken", 1.1, 1.1, 0);
	draw_set_halign(fa_right);
	draw_set_colour(c_white);
	draw_text_transformed(_rx, 295, string(_cs.damage_taken), 1.1, 1.1, 0);

	// XP Earned
	var _int_mult = 1 + (_cs.player_creature.base_intellect / 200);
	draw_set_halign(fa_left);
	draw_set_colour(make_colour_rgb(120, 255, 120));
	draw_text_transformed(_lx, 340, "XP Earned", 1.1, 1.1, 0);
	draw_set_halign(fa_right);
	draw_set_colour(make_colour_rgb(180, 255, 180));
	draw_text_transformed(_rx, 340, string(_cs.xp_earned) + "  (INT x" + string(round(_int_mult * 100) / 100) + ")", 1.1, 1.1, 0);

	// Total XP
	draw_set_halign(fa_left);
	draw_set_colour(make_colour_rgb(100, 200, 100));
	draw_text_transformed(_lx, 385, "Total XP", 1.1, 1.1, 0);
	draw_set_halign(fa_right);
	draw_set_colour(make_colour_rgb(150, 255, 150));
	draw_text_transformed(_rx, 385, string(_cs.player_creature.xp), 1.1, 1.1, 0);

	// Bond
	var _bond_after = global.combat_state.bond_after ?? 0;
	draw_set_halign(fa_left);
	draw_set_colour(make_colour_rgb(255, 180, 100));
	draw_text_transformed(_lx, 430, "Bond", 1.1, 1.1, 0);
	draw_set_halign(fa_right);
	draw_set_colour(make_colour_rgb(255, 200, 140));
	draw_text_transformed(_rx, 430, string(_bond_after) + "/50  (+1)", 1.1, 1.1, 0);

	// Item dropped (if any)
	if (variable_struct_exists(_cs, "item_dropped") && _cs.item_dropped != "") {
		draw_set_halign(fa_left);
		draw_set_colour(make_colour_rgb(200, 100, 255));
		draw_text_transformed(_lx, 475, "Item Found", 1.1, 1.1, 0);
		draw_set_halign(fa_right);
		draw_set_colour(make_colour_rgb(220, 160, 255));
		draw_text_transformed(_rx, 475, _cs.item_dropped, 1.1, 1.1, 0);
	}

	// Continue button
	var _btn_cx = room_width / 2;
	var _btn_cy = 520;
	var _btn_w  = 220;
	var _btn_h  = 44;
	var _hovering = point_distance(mouse_x, mouse_y, _btn_cx, _btn_cy) < 120;
	draw_set_colour(_hovering ? make_colour_rgb(80, 120, 200) : make_colour_rgb(40, 60, 120));
	draw_rectangle(_btn_cx - _btn_w / 2, _btn_cy - _btn_h / 2, _btn_cx + _btn_w / 2, _btn_cy + _btn_h / 2, false);
	draw_set_colour(make_colour_rgb(180, 200, 255));
	draw_rectangle(_btn_cx - _btn_w / 2, _btn_cy - _btn_h / 2, _btn_cx + _btn_w / 2, _btn_cy + _btn_h / 2, true);
	draw_set_halign(fa_center);
	draw_set_colour(c_white);
	draw_text_transformed(_btn_cx, _btn_cy, "CONTINUE  [ Enter / Click ]", 1.1, 1.1, 0);
}
