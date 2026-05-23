var hw     = 56;   // half wall width
var wh     = 44;   // wall height
var roof_h = 32;

var wx  = x - hw;
var wy  = y - wh;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.22);
draw_ellipse(x - hw * 0.8, y + 2, x + hw * 0.8, y + 10, false);
draw_set_alpha(1.0);

// Walls
draw_set_colour(make_colour_rgb(130, 95, 60));
draw_rectangle(wx, wy, wx + hw * 2, y, false);

// Roof
draw_set_colour(make_colour_rgb(88, 52, 32));
draw_triangle(wx - 10, wy, wx + hw * 2 + 10, wy, x, wy - roof_h, false);

// Door
draw_set_colour(make_colour_rgb(65, 38, 18));
draw_rectangle(x - 9, wy + wh - 24, x + 9, y, false);
draw_set_colour(make_colour_rgb(100, 65, 35));
draw_rectangle(x - 9, wy + wh - 24, x + 9, y, true);

// Window (left side)
draw_set_colour(make_colour_rgb(155, 205, 235));
draw_rectangle(wx + 10, wy + 8, wx + 26, wy + 22, false);
draw_set_colour(make_colour_rgb(80, 130, 170));
draw_rectangle(wx + 10, wy + 8, wx + 26, wy + 22, true);
draw_line(wx + 18, wy + 8, wx + 18, wy + 22);
draw_line(wx + 10, wy + 15, wx + 26, wy + 15);

// Label
draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_colour(make_colour_rgb(220, 200, 160));
draw_text_transformed(x, wy - roof_h - 6, "Your Hut", 1, 1, 0);

// Interact hint when player is nearby and no menu is open
if (instance_exists(obj_player)) {
	var dist    = point_distance(x, y, obj_player.x, obj_player.y);
	var ui_open = false;
	if (instance_exists(obj_task_ui)) {
		ui_open = (obj_task_ui.show_tasks || obj_task_ui.show_stats || obj_task_ui.show_pause);
	}
	if (dist < interact_dist && !ui_open) {
		draw_set_colour(make_colour_rgb(255, 255, 200));
		draw_set_alpha(0.88);
		draw_text_transformed(x, wy - roof_h - 22, "[E] Sleep  (12h, +50% STA)", 1, 1, 0);
		draw_set_alpha(1.0);
	}
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
