var _alpha = lifetime / 45;
var _sc    = is_crit ? 2.2 : 1.8;

// Color by damage amount
var _col;
if (value >= 50)      _col = make_colour_rgb(255, 50,  50);   // critical — red
else if (value >= 30) _col = make_colour_rgb(255, 130, 20);   // heavy — orange
else if (value >= 15) _col = make_colour_rgb(255, 215, 0);    // medium — yellow
else                  _col = c_white;                          // light — white

draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// Drop shadow
draw_set_alpha(_alpha * 0.65);
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_text_transformed(x + 2, y + 2, string(value), _sc, _sc, 0);

// Main number
draw_set_alpha(_alpha);
draw_set_colour(_col);
draw_text_transformed(x, y, string(value), _sc, _sc, 0);

// CRIT! label above number
if (is_crit) {
	draw_set_alpha(_alpha * 0.90);
	draw_set_colour(make_colour_rgb(0, 0, 0));
	draw_text_transformed(x + 1, y - 19, "CRIT!", 1.1, 1.1, 0);
	draw_set_alpha(_alpha);
	draw_set_colour(make_colour_rgb(255, 60, 60));
	draw_text_transformed(x, y - 20, "CRIT!", 1.1, 1.1, 0);
}

draw_set_alpha(1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
