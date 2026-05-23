// Appearance from controller
var gc    = obj_game_controller;
var si    = clamp(gc.skin_tone,  0, 4);
var hi    = clamp(gc.hair_color, 0, 5);
var style = gc.hair_style;
var sc    = skin_col_list[si];
var hc    = hair_col_list[hi];

// Walk bob and leg swing
var bob     = moving ? sin(walk_t * 0.21) * 2 : 0;
var leg_l   = moving ? sin(walk_t * 0.21) * 5 : 0;

var px = x;
var py = y;

// ── Shadow ────────────────────────────────────────────────────────────────────
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.22);
draw_ellipse(px - 10, py + 18, px + 10, py + 24, false);
draw_set_alpha(1.0);

// ── Legs ──────────────────────────────────────────────────────────────────────
draw_set_colour(make_colour_rgb(45, 50, 80));
draw_rectangle(px - 9,  py + 12 + bob, px - 2,  py + 26 + bob + leg_l, false);
draw_rectangle(px + 2,  py + 12 + bob, px + 9,  py + 26 + bob - leg_l, false);

// ── Body / shirt ──────────────────────────────────────────────────────────────
draw_set_colour(make_colour_rgb(55, 95, 155));
draw_rectangle(px - 10, py - 10 + bob, px + 10, py + 14 + bob, false);

// ── Arms ──────────────────────────────────────────────────────────────────────
draw_set_colour(sc);
draw_rectangle(px - 15, py - 8 + bob, px - 10, py + 10 + bob - leg_l, false);
draw_rectangle(px + 10, py - 8 + bob, px + 15, py + 10 + bob + leg_l, false);

// ── Head ──────────────────────────────────────────────────────────────────────
draw_set_colour(sc);
draw_rectangle(px - 9, py - 28 + bob, px + 9, py - 10 + bob, false);

// ── Hair ──────────────────────────────────────────────────────────────────────
draw_set_colour(hc);
switch (style) {
	case 0: // Short
		draw_rectangle(px - 10, py - 31 + bob, px + 10, py - 24 + bob, false);
		draw_rectangle(px - 10, py - 28 + bob, px - 7,  py - 20 + bob, false);
		draw_rectangle(px + 7,  py - 28 + bob, px + 10, py - 20 + bob, false);
		break;
	case 1: // Long
		draw_rectangle(px - 10, py - 31 + bob, px + 10, py - 24 + bob, false);
		draw_rectangle(px - 12, py - 28 + bob, px - 7,  py + 8  + bob, false);
		draw_rectangle(px + 7,  py - 28 + bob, px + 12, py + 8  + bob, false);
		break;
	case 2: // Braids — alternating bead segments
		draw_rectangle(px - 10, py - 31 + bob, px + 10, py - 24 + bob, false);
		for (var bi = 0; bi < 5; bi++) {
			var alt = (bi & 1) * 3;
			draw_rectangle(px - 14 + alt, py - 28 + bob + bi * 7, px - 7 + alt, py - 22 + bob + bi * 7, false);
			draw_rectangle(px + 7 - alt,  py - 28 + bob + bi * 7, px + 14 - alt, py - 22 + bob + bi * 7, false);
		}
		break;
}

// ── Eyes (direction-aware) ────────────────────────────────────────────────────
draw_set_colour(make_colour_rgb(35, 25, 15));
switch (facing) {
	case 0: // Down
		draw_rectangle(px - 6, py - 23 + bob, px - 3, py - 20 + bob, false);
		draw_rectangle(px + 3, py - 23 + bob, px + 6, py - 20 + bob, false);
		// Eye shine
		draw_set_colour(make_colour_rgb(200, 200, 240));
		draw_rectangle(px - 6, py - 23 + bob, px - 4, py - 21 + bob, false);
		draw_rectangle(px + 3, py - 23 + bob, px + 5, py - 21 + bob, false);
		break;
	case 1: // Up — back of head, no eyes
		break;
	case 2: // Left
		draw_rectangle(px - 7, py - 23 + bob, px - 4, py - 20 + bob, false);
		draw_set_colour(make_colour_rgb(200, 200, 240));
		draw_rectangle(px - 7, py - 23 + bob, px - 5, py - 21 + bob, false);
		break;
	case 3: // Right
		draw_rectangle(px + 4, py - 23 + bob, px + 7, py - 20 + bob, false);
		draw_set_colour(make_colour_rgb(200, 200, 240));
		draw_rectangle(px + 5, py - 23 + bob, px + 7, py - 21 + bob, false);
		break;
}
