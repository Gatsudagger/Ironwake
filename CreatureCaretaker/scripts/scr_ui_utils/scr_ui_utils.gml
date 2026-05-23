/// @desc Returns the canonical colour for a given stat string (STAT_* macro).
function scr_get_stat_colour(stat) {
	switch (stat) {
		case STAT_STRENGTH:  return make_colour_rgb(220, 72,  72 );
		case STAT_AGILITY:   return make_colour_rgb(72,  210, 110);
		case STAT_DEXTERITY: return make_colour_rgb(72,  170, 220);
		case STAT_STAMINA:   return make_colour_rgb(220, 155, 72 );
		case STAT_INTELLECT: return make_colour_rgb(175, 72,  220);
		case STAT_WILLPOWER: return make_colour_rgb(220, 215, 72 );
		case STAT_DEFENSE:   return make_colour_rgb(130, 130, 200);
		case STAT_HEALTH:    return make_colour_rgb(220, 80,  80 );
	}
	return make_colour_rgb(150, 150, 150);
}

/// @desc Draw a standard pixel-art button. bx/by are the top-left corner.
function scr_draw_pixel_button(bx, by, bw, bh, label, is_hovered, txt_scale) {
	draw_set_colour(make_colour_rgb(0, 0, 0));
	draw_rectangle(bx + 3, by + 3, bx + bw + 3, by + bh + 3, false);
	draw_set_colour(is_hovered ? make_colour_rgb(90, 127, 160) : make_colour_rgb(61, 90, 128));
	draw_rectangle(bx, by, bx + bw, by + bh, false);
	draw_set_colour(make_colour_rgb(140, 180, 220));
	draw_rectangle(bx, by, bx + bw, by + bh, true);
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);
	draw_set_colour(make_colour_rgb(232, 232, 255));
	draw_text_transformed(bx + bw / 2, by + bh / 2, label, txt_scale, txt_scale, 0);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

/// @desc Draw a dark inset panel with a subtle border.
function scr_draw_panel(px, py, pw, ph) {
	draw_set_colour(make_colour_rgb(22, 22, 45));
	draw_rectangle(px, py, px + pw, py + ph, false);
	draw_set_colour(make_colour_rgb(90, 90, 140));
	draw_rectangle(px, py, px + pw, py + ph, true);
}

/// @desc Draw a top-down pixel-art character preview centered at (cx, cy).
/// hair_style: 0 = short, 1 = long, 2 = braids.
function scr_draw_character_preview(cx, cy, skin_col, hair_col, hair_style) {
	var bw = 180;
	var bh = 220;
	var bx = cx - bw / 2;
	var by = cy - bh / 2;

	draw_set_colour(make_colour_rgb(14, 14, 32));
	draw_rectangle(bx, by, bx + bw, by + bh, false);
	draw_set_colour(make_colour_rgb(70, 70, 120));
	draw_rectangle(bx, by, bx + bw, by + bh, true);

	// Body
	draw_set_colour(skin_col);
	draw_rectangle(cx - 24, cy - 10, cx + 24, cy + 38, false);

	// Head
	draw_set_colour(skin_col);
	draw_rectangle(cx - 20, cy - 60, cx + 20, cy - 12, false);

	// Arms
	draw_set_colour(skin_col);
	draw_rectangle(cx - 40, cy - 6, cx - 26, cy + 20, false);
	draw_rectangle(cx + 26, cy - 6, cx + 40, cy + 20, false);

	// Hair (drawn before eyes so eyes appear on top of any overlap)
	draw_set_colour(hair_col);
	switch (hair_style) {
		case 0: // Short — top band and small side tufts
			draw_rectangle(cx - 22, cy - 68, cx + 22, cy - 58, false);
			draw_rectangle(cx - 22, cy - 62, cx - 17, cy - 52, false);
			draw_rectangle(cx + 17,  cy - 62, cx + 22, cy - 52, false);
			break;
		case 1: // Long — top band plus flowing side panels
			draw_rectangle(cx - 22, cy - 68, cx + 22, cy - 58, false);
			draw_rectangle(cx - 26, cy - 62, cx - 18, cy + 24, false);
			draw_rectangle(cx + 18,  cy - 62, cx + 26, cy + 24, false);
			break;
		case 2: // Braids — top band plus alternating braid segments
			draw_rectangle(cx - 22, cy - 68, cx + 22, cy - 58, false);
			var bi = 0;
			repeat (6) {
				var alt = (bi & 1) * 4;
				draw_rectangle(cx - 28 + alt, cy - 60 + bi * 10, cx - 17 + alt, cy - 52 + bi * 10, false);
				draw_rectangle(cx + 17 - alt, cy - 60 + bi * 10, cx + 28 - alt, cy - 52 + bi * 10, false);
				bi++;
			}
			break;
	}

	// Eyes (drawn last so they sit on top of the head/hair)
	draw_set_colour(make_colour_rgb(35, 25, 15));
	draw_rectangle(cx - 12, cy - 50, cx - 6,  cy - 44, false);
	draw_rectangle(cx + 6,  cy - 50, cx + 12, cy - 44, false);

	// Eye shine
	draw_set_colour(make_colour_rgb(200, 200, 240));
	draw_rectangle(cx - 11, cy - 50, cx - 9, cy - 48, false);
	draw_rectangle(cx + 7,  cy - 50, cx + 9, cy - 48, false);

	// "PREVIEW" label
	draw_set_halign(fa_center);
	draw_set_valign(fa_bottom);
	draw_set_colour(make_colour_rgb(120, 120, 170));
	draw_text_transformed(cx, by + bh - 5, "PREVIEW", 1, 1, 0);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}
