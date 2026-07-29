// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.18);
draw_ellipse(x - 40, y + 3, x + 40, y + 13, false);
draw_set_alpha(1.0);

// Sprite origin is center-bottom so (x, y) is the ground contact point
draw_sprite_ext(sprite_index, 0, x, y, 1.5, 1.5, 0, c_white, 1);
