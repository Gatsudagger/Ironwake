var gc  = obj_game_controller;
var ci  = gc.starter_creature;
var cd  = global.creature_data[ci];
var scale  = 1.5;
var draw_w = sprite_width  * scale;
var draw_h = sprite_height * scale;
var bob    = sin(idle_bob_t * 0.052) * 3;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.28);
draw_ellipse(x - draw_w * 0.36, y + 4, x + draw_w * 0.36, y + 10, false);
draw_set_alpha(1.0);

// Walk sprite — origin is center-bottom (34,68), so draw at (x, y+bob)
draw_sprite_ext(sprite_index, image_index, x, y + bob, scale, scale, 0, c_white, 1);

draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);

// Creature name label
draw_set_colour(make_colour_rgb(255, 220, 100));
draw_text_transformed(x, y - draw_h - 6 + bob, cd.name, 1, 1, 0);

// Interact hint when player is close and no menu is open
if (instance_exists(obj_task_ui) && instance_exists(obj_player)) {
	var dist = point_distance(x, y, obj_player.x, obj_player.y);
	if (dist < obj_task_ui.interact_dist && !obj_task_ui.show_tasks && !obj_task_ui.show_stats) {
		draw_set_colour(make_colour_rgb(255, 255, 200));
		draw_set_alpha(0.88);
		draw_text_transformed(x, y - draw_h - 22 + bob, "[E] Tasks    [Tab] Stats", 1, 1, 0);
		draw_set_alpha(1.0);
	}
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
