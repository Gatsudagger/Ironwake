var _spr   = walk_sprites[facing];
var _frame = floor(anim_frame);
var _scale = 2.0;

// Shadow
draw_set_alpha(0.35);
draw_set_color(c_black);
draw_ellipse(x - 18, y - 4, x + 18, y + 4, false);
draw_set_alpha(1);

draw_sprite_ext(_spr, _frame, x, y, _scale, _scale, 0, c_white, 1);
if (hit_flash > 0) {
	draw_sprite_ext(_spr, _frame, x, y, _scale, _scale, 0, make_colour_rgb(255, 80, 80), 0.6);
}

if (poison_dur > 0) {
	draw_sprite_ext(_spr, _frame, x, y, _scale, _scale, 0, c_lime, 0.3);
}

// Status indicators
if (stun_dur > 0)   { draw_set_colour(make_colour_rgb(255, 220, 0));  draw_circle(x, y - 60, 8, false); }
if (slow_dur > 0)   { draw_set_colour(make_colour_rgb(80, 160, 255)); draw_circle(x, y - 60, 8, false); }
if (poison_dur > 0) { draw_set_colour(make_colour_rgb(180, 80, 255)); draw_circle(x, y - 60, 8, false); }

// Attack telegraph warning
if (telegraphing) {
	var _pulse = sin(telegraph_timer * 0.3) * 0.5 + 0.5;
	draw_set_colour(make_colour_rgb(255, 80, 80));
	draw_set_alpha(_pulse * 0.6);
	draw_circle(x, y - 30, 40, true);
	draw_set_alpha(1);
	draw_set_colour(make_colour_rgb(255, 180, 180));
	draw_set_halign(fa_center);
	draw_text_transformed(x, y - 75, "!", 2, 2, 0);
	draw_set_halign(fa_left);
}
