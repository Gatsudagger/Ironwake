var cam = view_camera[0];
var vx  = camera_get_view_x(cam);
var vy  = camera_get_view_y(cam);
var vw  = camera_get_view_width(cam);
var vh  = camera_get_view_height(cam);

// ── Day / Night atmosphere tint ───────────────────────────────────────────────
var tint_col, tint_alpha;
switch (global.time_phase) {
	case TIME_PHASE.MORNING:
		tint_col   = make_colour_rgb(255, 248, 215);
		tint_alpha = 0.08;
		break;
	case TIME_PHASE.MIDDAY:
		tint_col   = make_colour_rgb(255, 240, 180);
		tint_alpha = 0.05;
		break;
	case TIME_PHASE.EVENING:
		tint_col   = make_colour_rgb(255, 140, 50);
		tint_alpha = 0.30;
		break;
	default: // NIGHT
		tint_col   = make_colour_rgb(20, 30, 90);
		tint_alpha = 0.58;
		break;
}
draw_set_alpha(tint_alpha);
draw_set_colour(tint_col);
draw_rectangle(vx, vy, vx + vw, vy + vh, false);
draw_set_alpha(1.0);

// ── HUD panel (top-left corner) ───────────────────────────────────────────────
var hx = vx + 12;
var hy = vy + 12;
var hw = 230;
var hh = 100;

draw_set_colour(make_colour_rgb(8, 8, 28));
draw_set_alpha(0.74);
draw_rectangle(hx, hy, hx + hw, hy + hh, false);
draw_set_alpha(1.0);
draw_set_colour(make_colour_rgb(70, 70, 130));
draw_rectangle(hx, hy, hx + hw, hy + hh, true);

// Time string
var total_mins  = floor(global.minutes_in_day);
var game_hour   = total_mins div 60;
var game_minute = total_mins mod 60;
var ampm        = (game_hour >= 12) ? "PM" : "AM";
var disp_hour   = game_hour mod 12;
if (disp_hour == 0) disp_hour = 12;
var min_str     = (game_minute < 10) ? ("0" + string(game_minute)) : string(game_minute);
var time_str    = string(disp_hour) + ":" + min_str + " " + ampm;

draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(255, 215, 0));
draw_text_transformed(hx + 10, hy + 20, time_str, 1.5, 1.5, 0);

// Day number
draw_set_colour(make_colour_rgb(170, 170, 220));
draw_text_transformed(hx + 10, hy + 46, "Day  " + string(global.day_number), 1, 1, 0);

// Phase label
var phase_labels = ["Night", "Morning", "Midday", "Evening"];
draw_set_halign(fa_right);
draw_set_colour(make_colour_rgb(120, 120, 175));
draw_text_transformed(hx + hw - 8, hy + 46, phase_labels[global.time_phase], 1, 1, 0);

// Player name
draw_set_colour(make_colour_rgb(140, 205, 255));
draw_text_transformed(hx + hw - 8, hy + 20, obj_game_controller.player_name, 1, 1, 0);

// Stamina bar
var gc  = obj_game_controller;
var sta = gc.creature_stamina;
var sta_max = gc.creature_stamina_max;
var sta_pct = (sta_max > 0) ? (sta / sta_max) : 0;
var bar_lx = hx + 10;
var bar_w  = hw - 20;
var bar_y  = hy + 74;

draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 160, 200));
var cname = (gc.starter_creature >= 0) ? global.creature_data[gc.starter_creature].name : "Creature";
draw_text_transformed(bar_lx, bar_y - 14, cname + "  STA", 1, 1, 0);
draw_set_halign(fa_right);
draw_set_colour(make_colour_rgb(130, 130, 180));
draw_text_transformed(hx + hw - 10, bar_y - 14, string(sta) + "/" + string(sta_max), 1, 1, 0);

draw_set_colour(make_colour_rgb(18, 18, 42));
draw_rectangle(bar_lx, bar_y, bar_lx + bar_w, bar_y + 12, false);

var bar_col;
if (sta_pct > 0.5)       bar_col = make_colour_rgb(60, 210, 90);
else if (sta_pct > 0.25) bar_col = make_colour_rgb(220, 160, 40);
else                     bar_col = make_colour_rgb(210, 55, 55);
draw_set_colour(bar_col);
draw_rectangle(bar_lx, bar_y, bar_lx + bar_w * sta_pct, bar_y + 12, false);
draw_set_colour(make_colour_rgb(50, 50, 90));
draw_rectangle(bar_lx, bar_y, bar_lx + bar_w, bar_y + 12, true);

draw_set_halign(fa_left);
draw_set_valign(fa_top);

// ── F5 save hint (bottom-right) ───────────────────────────────────────────────
draw_set_colour(make_colour_rgb(80, 80, 110));
draw_set_alpha(0.7);
draw_text_transformed(vx + vw - 130, vy + vh - 20, "F5 Save", 1, 1, 0);
draw_set_alpha(1.0);
