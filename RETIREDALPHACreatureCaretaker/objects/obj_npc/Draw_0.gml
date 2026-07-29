var _scale = 1.5;
var _sw    = 68 * _scale;
var _sh    = 68 * _scale;
var _bob   = moving ? sin(walk_t * 0.21) * 2 : 0;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.2);
draw_ellipse(x - _sw * 0.4, y + 3, x + _sw * 0.4, y + 9, false);
draw_set_alpha(1.0);

// Sprite — origin top-left, so offset to center-bottom at (x, y)
var _flip = (facing == 3) ? -1 : 1;   // mirror for right-facing
draw_sprite_ext(sprite_index, 0,
    x - _sw * 0.5 * _flip, y - _sh * 0.7 + _bob,
    _scale * _flip, _scale, 0, c_white, 1);

// Name tag
draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_colour(make_colour_rgb(230, 218, 180));
draw_set_alpha(0.85);
draw_text_transformed(x, y - _sh - 4 + _bob, npc_name, 0.85, 0.85, 0);
draw_set_alpha(1.0);

// Talk hint
if (near_player) {
    draw_set_colour(make_colour_rgb(255, 255, 200));
    draw_set_alpha(0.9);
    draw_text_transformed(x, y - _sh - 18 + _bob, "[E] Talk", 1, 1, 0);
    draw_set_alpha(1.0);
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
