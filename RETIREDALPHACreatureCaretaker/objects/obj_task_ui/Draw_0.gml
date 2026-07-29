var cam = view_camera[0];
var vx  = camera_get_view_x(cam);
var vy  = camera_get_view_y(cam);
var vw  = camera_get_view_width(cam);
var vh  = camera_get_view_height(cam);

draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var gc = obj_game_controller;
var _c = is_struct(gc.starter_creature) ? gc.starter_creature : undefined;

// ── Feedback message ──────────────────────────────────────────────────────────
if (feedback_timer > 0) {
	draw_set_alpha(min(1.0, feedback_timer / 30.0));
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(200, 255, 180));
	draw_text_transformed(vx + vw * 0.5, vy + vh * 0.33, feedback_msg, 1.5, 1.5, 0);
	draw_set_alpha(1.0);
	draw_set_halign(fa_left);
}

// ── Active task progress bar (persistent, top-right corner) ──────────────────
if (_c != undefined && _c.active_task != -1) {
	var _td   = scr_task_get_data(_c.active_task);
	var _dur  = _c.task_end_minute - _c.task_start_minute;
	var _prog = (_dur > 0)
		? clamp((global.minutes_in_day - _c.task_start_minute) / _dur, 0, 1)
		: 0;
	var _bw = 220;
	var _bh = 14;
	var _bx = vx + vw - _bw - 16;
	var _by = vy + 16;

	draw_set_halign(fa_right);
	draw_set_colour(make_colour_rgb(170, 210, 255));
	draw_text_transformed(_bx - 4, _by, "IN PROGRESS: " + string_upper(_td.name), 1, 1, 0);

	draw_set_colour(make_colour_rgb(20, 20, 46));
	draw_rectangle(_bx, _by + 16, _bx + _bw, _by + 16 + _bh, false);
	draw_set_colour(make_colour_rgb(80, 180, 120));
	draw_rectangle(_bx, _by + 16, _bx + _bw * _prog, _by + 16 + _bh, false);
	draw_set_colour(make_colour_rgb(60, 60, 100));
	draw_rectangle(_bx, _by + 16, _bx + _bw, _by + 16 + _bh, true);

	draw_set_halign(fa_left);
}

// ── Task menu ─────────────────────────────────────────────────────────────────
if (show_tasks) {
	var _sta     = (_c != undefined) ? _c.current_stamina : 0;
	var _sta_max = (_c != undefined) ? _c.base_stamina    : 0;

	menu_x = vx + vw * 0.5 - menu_w * 0.5;
	menu_y = vy + vh * 0.5 - menu_h * 0.5;
	var px = menu_x;
	var py = menu_y;
	var pw = menu_w;
	var ph = menu_h;

	scr_draw_panel(px, py, pw, ph);

	// Title
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(255, 215, 0));
	draw_text_transformed(px + pw * 0.5, py + 14, "ASSIGN TASK", 1.5, 1.5, 0);

	// Stamina counter (top-right of panel)
	draw_set_halign(fa_right);
	draw_set_colour(make_colour_rgb(220, 155, 72));
	draw_text_transformed(px + pw - 14, py + 14,
		"STA  " + string(_sta) + " / " + string(_sta_max), 1, 1, 0);

	// Divider
	draw_set_colour(make_colour_rgb(60, 60, 100));
	draw_rectangle(px + 14, py + 38, px + pw - 14, py + 40, false);

	// Task rows
	var _row_h = 40;
	var _row_y = py + 46;

	for (var _i = 0; _i < TASK_TYPE.COUNT; _i++) {
		var _td     = scr_task_get_data(_i);
		var _avail  = (_c != undefined) && scr_task_is_available(_c, _i)
		              && (_c.active_task == -1);
		var _is_sel = (_i == selected_task);

		// Row background
		draw_set_alpha(0.88);
		draw_set_colour(_is_sel
			? make_colour_rgb(38, 55, 95)
			: make_colour_rgb(16, 16, 38));
		draw_rectangle(px + 14, _row_y, px + pw - 14, _row_y + _row_h - 2, false);
		draw_set_alpha(1.0);
		draw_set_colour(_is_sel
			? make_colour_rgb(100, 145, 215)
			: make_colour_rgb(40, 40, 70));
		draw_rectangle(px + 14, _row_y, px + pw - 14, _row_y + _row_h - 2, true);

		// Selection arrow
		if (_is_sel) {
			draw_set_halign(fa_left);
			draw_set_colour(make_colour_rgb(255, 215, 0));
			draw_text_transformed(px + 18, _row_y + 11, ">", 1.2, 1.2, 0);
		}

		// Task name
		draw_set_halign(fa_left);
		var _name_col;
		if      (_is_sel)  _name_col = make_colour_rgb(255, 230, 80);
		else if (_avail)   _name_col = make_colour_rgb(220, 220, 255);
		else               _name_col = make_colour_rgb(90, 80, 80);
		draw_set_colour(_name_col);
		draw_text_transformed(px + 34, _row_y + 11, _td.name, 1.1, 1.1, 0);

		// Stamina cost + duration (right-aligned)
		draw_set_halign(fa_right);
		var _cost_str = (_td.stamina_cost == 0) ? "Free" : ("-" + string(_td.stamina_cost) + " STA");
		var _dur_str  = string(_td.duration_minutes) + "m";
		draw_set_colour(_avail
			? make_colour_rgb(180, 140, 60)
			: make_colour_rgb(75, 60, 55));
		draw_text_transformed(px + pw - 18, _row_y + 11,
			_cost_str + "  |  " + _dur_str, 1, 1, 0);

		_row_y += _row_h;
	}

	// Footer hint
	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(70, 70, 120));
	draw_text_transformed(px + pw * 0.5, py + ph - 14,
		"W/S Navigate    Enter Confirm    Esc Close", 1, 1, 0);
}

// ── Stats overlay ─────────────────────────────────────────────────────────────
if (show_stats) {
	if (!is_struct(gc.starter_creature)) exit;
	var _c2 = gc.starter_creature;
	var ci  = _c2.species;
	var cd  = global.creature_data[ci];
	var bs  = gc.biome_bonus_state;

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
		var base  = _c2[$ "base_" + skeys[i]];
		var raw_b = bs.bonuses[$ skeys[i]];
		var bonus = is_undefined(raw_b) ? 0 : raw_b;
		var total = base + bonus;

		draw_set_halign(fa_right);
		draw_set_colour(scols[i]);
		draw_text_transformed(bar_lx - 6, sy + 10, slabels[i], 1, 1, 0);

		draw_set_colour(make_colour_rgb(20, 20, 46));
		draw_rectangle(bar_lx, sy, bar_lx + bar_w, sy + 20, false);

		draw_set_colour(scols[i]);
		draw_rectangle(bar_lx, sy, bar_lx + (base / 100.0) * bar_w, sy + 20, false);

		if (bonus > 0) {
			var b_start = bar_lx + (base  / 100.0) * bar_w;
			var b_end   = bar_lx + (total / 100.0) * bar_w;
			draw_set_colour(make_colour_rgb(255, 245, 80));
			draw_rectangle(b_start, sy, b_end, sy + 20, false);
		}

		draw_set_colour(make_colour_rgb(44, 44, 80));
		draw_rectangle(bar_lx, sy, bar_lx + bar_w, sy + 20, true);

		draw_set_halign(fa_left);
		draw_set_colour(make_colour_rgb(210, 210, 255));
		var vstr = string(total) + (bonus > 0 ? " (+" + string(bonus) + ")" : "");
		draw_text_transformed(val_x, sy + 10, vstr, 1, 1, 0);
	}

	draw_set_halign(fa_center);
	draw_set_colour(make_colour_rgb(100, 180, 220));
	draw_text_transformed(px + pw * 0.5, py + ph - 48, "Biome: " + scr_biome_get_name(gc.biome_id), 1, 1, 0);
	draw_set_colour(make_colour_rgb(200, 200, 80));
	draw_text_transformed(px + pw * 0.5, py + ph - 30, scr_biome_get_bonus_summary(bs), 1, 1, 0);
	draw_set_colour(make_colour_rgb(70, 70, 120));
	draw_text_transformed(px + pw * 0.5, py + ph - 12, "[ Tab ] Close    [ Enter ] Full Detail", 1, 1, 0);
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
