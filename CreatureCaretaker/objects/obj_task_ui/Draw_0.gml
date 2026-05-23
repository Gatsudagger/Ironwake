var cam = view_camera[0];
var vx  = camera_get_view_x(cam);
var vy  = camera_get_view_y(cam);
var vw  = camera_get_view_width(cam);
var vh  = camera_get_view_height(cam);

draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// ── Feedback message (fades out) ──────────────────────────────────────────────
if (feedback_timer > 0) {
	draw_set_alpha(min(1.0, feedback_timer / 30.0));
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(200, 255, 180));
	draw_text_transformed(vx + vw * 0.5, vy + vh * 0.33, feedback_msg, 1.5, 1.5, 0);
	draw_set_alpha(1.0);
	draw_set_halign(fa_left);
}

// ── Task Menu ─────────────────────────────────────────────────────────────────
if (show_tasks) {
	var gc  = obj_game_controller;
	var sta = gc.creature_stamina;
	var sta_max = gc.creature_stamina_max;

	var pw = 430;
	var ph = 300;
	var px = vx + vw * 0.5 - pw * 0.5;
	var py = vy + vh * 0.5 - ph * 0.5;

	draw_set_colour(make_colour_rgb(8, 8, 28));
	draw_set_alpha(0.93);
	draw_rectangle(px, py, px + pw, py + ph, false);
	draw_set_alpha(1.0);
	draw_set_colour(make_colour_rgb(80, 80, 155));
	draw_rectangle(px, py, px + pw, py + ph, true);

	// Header
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(255, 215, 0));
	draw_text_transformed(px + pw * 0.5, py + 18, "DAILY TASKS", 1.5, 1.5, 0);
	draw_set_colour(make_colour_rgb(55, 55, 110));
	draw_rectangle(px + 14, py + 40, px + pw - 14, py + 42, false);

	// Stamina counter (top-right)
	draw_set_halign(fa_right);
	draw_set_colour(make_colour_rgb(220, 155, 72));
	draw_text_transformed(px + pw - 14, py + 18,
		"STA  " + string(sta) + " / " + string(sta_max), 1, 1, 0);

	// Task rows
	for (var i = 0; i < array_length(task_names); i++) {
		var ty        = py + 50 + i * 74;
		var is_sel    = (i == selected);
		var cost      = task_costs[i];
		var can_afford = (sta >= cost || cost == 0);

		draw_set_colour(is_sel ? make_colour_rgb(38, 55, 95) : make_colour_rgb(16, 16, 38));
		draw_set_alpha(0.92);
		draw_rectangle(px + 14, ty, px + pw - 14, ty + 64, false);
		draw_set_alpha(1.0);
		draw_set_colour(is_sel ? make_colour_rgb(110, 155, 225) : make_colour_rgb(44, 44, 84));
		draw_rectangle(px + 14, ty, px + pw - 14, ty + 64, true);

		// Name
		draw_set_halign(fa_left);
		draw_set_colour(can_afford ? make_colour_rgb(232, 232, 255) : make_colour_rgb(110, 90, 90));
		draw_text_transformed(px + 24, ty + 12, task_names[i], 1.2, 1.2, 0);

		// Cost
		draw_set_halign(fa_right);
		var cost_col = make_colour_rgb(190, 60, 60);
		if (cost == 0)  cost_col = make_colour_rgb(100, 215, 100);
		else if (can_afford) cost_col = make_colour_rgb(220, 155, 72);
		draw_set_colour(cost_col);
		var cost_str = "-" + string(cost) + " STA";
		if (cost == 0) cost_str = "Free";
		draw_text_transformed(px + pw - 24, ty + 12, cost_str, 1, 1, 0);

		// Description
		draw_set_halign(fa_left);
		draw_set_colour(make_colour_rgb(115, 115, 172));
		draw_text_transformed(px + 24, ty + 40, task_descs[i], 1, 1, 0);
	}

	// Footer
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(70, 70, 120));
	draw_text_transformed(px + pw * 0.5, py + ph - 14,
		"↑↓ Navigate    Enter Confirm    Esc Close", 1, 1, 0);
}

// ── Stats Screen ──────────────────────────────────────────────────────────────
if (show_stats) {
	var gc = obj_game_controller;
	var ci = gc.starter_creature;
	var cd = global.creature_data[ci];
	var bs = gc.biome_bonus_state;

	var pw = 460;
	var ph = 430;
	var px = vx + vw * 0.5 - pw * 0.5;
	var py = vy + vh * 0.5 - ph * 0.5;

	draw_set_colour(make_colour_rgb(8, 8, 28));
	draw_set_alpha(0.94);
	draw_rectangle(px, py, px + pw, py + ph, false);
	draw_set_alpha(1.0);
	draw_set_colour(make_colour_rgb(80, 80, 155));
	draw_rectangle(px, py, px + pw, py + ph, true);

	// Header
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(255, 215, 0));
	draw_text_transformed(px + pw * 0.5, py + 18, cd.name + "  —  Stats", 1.5, 1.5, 0);
	draw_set_colour(make_colour_rgb(55, 55, 110));
	draw_rectangle(px + 14, py + 40, px + pw - 14, py + 42, false);

	var skeys   = ["strength","agility","dexterity","stamina","intellect","willpower","defense"];
	var slabels = ["STR","AGI","DEX","STA","INT","WIL","DEF"];
	var scols   = [
		make_colour_rgb(220, 72,  72 ),
		make_colour_rgb(72,  210, 110),
		make_colour_rgb(72,  170, 220),
		make_colour_rgb(220, 155, 72 ),
		make_colour_rgb(175, 72,  220),
		make_colour_rgb(220, 215, 72 ),
		make_colour_rgb(130, 130, 200),
	];

	var bar_lx = px + 74;
	var bar_w  = 256;
	var val_x  = bar_lx + bar_w + 8;

	for (var i = 0; i < array_length(skeys); i++) {
		var sy    = py + 50 + i * 48;
		var base  = cd[$ skeys[i]];
		var raw_b = bs.bonuses[$ skeys[i]];
		var bonus = is_undefined(raw_b) ? 0 : raw_b;
		var total = base + bonus;

		// Label
		draw_set_halign(fa_right);
		draw_set_colour(scols[i]);
		draw_text_transformed(bar_lx - 6, sy + 10, slabels[i], 1, 1, 0);

		// Bar background
		draw_set_colour(make_colour_rgb(20, 20, 46));
		draw_rectangle(bar_lx, sy, bar_lx + bar_w, sy + 20, false);

		// Base fill
		draw_set_colour(scols[i]);
		draw_rectangle(bar_lx, sy, bar_lx + (base / 100.0) * bar_w, sy + 20, false);

		// Bonus fill (yellow)
		if (bonus > 0) {
			var b_start = bar_lx + (base  / 100.0) * bar_w;
			var b_end   = bar_lx + (total / 100.0) * bar_w;
			draw_set_colour(make_colour_rgb(255, 245, 80));
			draw_rectangle(b_start, sy, b_end, sy + 20, false);
		}

		// Border
		draw_set_colour(make_colour_rgb(44, 44, 80));
		draw_rectangle(bar_lx, sy, bar_lx + bar_w, sy + 20, true);

		// Value
		draw_set_halign(fa_left);
		draw_set_colour(make_colour_rgb(210, 210, 255));
		var vstr = string(total) + (bonus > 0 ? " (+" + string(bonus) + ")" : "");
		draw_text_transformed(val_x, sy + 10, vstr, 1, 1, 0);
	}

	// Biome + bonus summary
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(100, 180, 220));
	draw_text_transformed(px + pw * 0.5, py + ph - 48, "Biome: " + scr_biome_get_name(gc.biome_id), 1, 1, 0);
	draw_set_colour(make_colour_rgb(200, 200, 80));
	draw_text_transformed(px + pw * 0.5, py + ph - 30, scr_biome_get_bonus_summary(bs), 1, 1, 0);
	draw_set_colour(make_colour_rgb(70, 70, 120));
	draw_text_transformed(px + pw * 0.5, py + ph - 12, "[ Tab ] Close", 1, 1, 0);
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
