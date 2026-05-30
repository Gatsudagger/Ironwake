var gc = obj_game_controller;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.22);
draw_ellipse(x - 12, y + 4, x + 12, y + 10, false);
draw_set_alpha(1.0);

// facing: 0=south 1=north 2=west 3=east
draw_sprite_ext(spr_player, facing, x, y, 1, 1, 0, c_white, 1);

// Name tag
draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_colour(make_colour_rgb(255, 240, 200));
draw_set_alpha(0.9);
draw_text_transformed(x, y - 96, gc.player_name, 0.85, 0.85, 0);
draw_set_alpha(1.0);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
