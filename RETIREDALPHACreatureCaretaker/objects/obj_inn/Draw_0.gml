var wx = x - hw;
var wy = y - wh;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.22);
draw_ellipse(x - hw, y + 2, x + hw, y + 14, false);
draw_set_alpha(1.0);

// Walls
draw_set_colour(make_colour_rgb(212, 188, 140));
draw_rectangle(wx, wy, wx + hw * 2, y, false);

// Timber frame
draw_set_colour(make_colour_rgb(92, 60, 26));
draw_rectangle(wx,               wy, wx + 5,      y, false);
draw_rectangle(wx + hw * 2 - 5,  wy, wx + hw * 2, y, false);
draw_rectangle(wx, wy + 30, wx + hw * 2, wy + 34, false);
for (var ti = 0; ti < 3; ti++) {
    var tx = wx + 22 + ti * (hw * 2 - 44) / 2;
    draw_rectangle(tx - 2, wy, tx + 2, wy + 30, false);
}

// Roof
draw_set_colour(make_colour_rgb(72, 38, 16));
draw_triangle(wx - 14, wy, wx + hw * 2 + 14, wy, x, wy - roof_h, false);

// Chimney
draw_set_colour(make_colour_rgb(98, 82, 68));
draw_rectangle(x + hw / 2 - 9, wy - roof_h - 18, x + hw / 2 + 9, wy - 6, false);
draw_set_colour(make_colour_rgb(48, 42, 38));
draw_rectangle(x + hw / 2 - 11, wy - roof_h - 20, x + hw / 2 + 11, wy - roof_h - 16, false);
// Smoke
draw_set_alpha(0.32 + 0.12 * sin(current_time * 0.005));
draw_set_colour(make_colour_rgb(195, 190, 185));
draw_circle(x + hw / 2,     wy - roof_h - 28, 7, false);
draw_circle(x + hw / 2 + 4, wy - roof_h - 36, 5, false);
draw_set_alpha(1.0);

// Door
draw_set_colour(make_colour_rgb(72, 46, 20));
draw_rectangle(x - 13, wy + wh - 32, x + 13, y, false);
draw_set_colour(make_colour_rgb(112, 78, 40));
draw_rectangle(x - 13, wy + wh - 32, x + 13, y, true);
draw_set_colour(make_colour_rgb(195, 158, 82));
draw_circle(x + 8, wy + wh - 18, 2, false);

// Windows — warm lamplight
draw_set_colour(make_colour_rgb(255, 228, 120));
draw_rectangle(wx + 14, wy + 36, wx + 38, wy + 52, false);
draw_rectangle(wx + hw * 2 - 38, wy + 36, wx + hw * 2 - 14, wy + 52, false);
draw_set_colour(make_colour_rgb(78, 132, 172));
draw_rectangle(wx + 14, wy + 36, wx + 38, wy + 52, true);
draw_rectangle(wx + hw * 2 - 38, wy + 36, wx + hw * 2 - 14, wy + 52, true);

// Lanterns
var lamp_y = wy + 22;
draw_set_colour(make_colour_rgb(198, 158, 58));
draw_rectangle(wx + 4,           lamp_y,     wx + 13,          lamp_y + 14, false);
draw_rectangle(wx + hw * 2 - 13, lamp_y,     wx + hw * 2 - 4,  lamp_y + 14, false);
draw_set_colour(make_colour_rgb(255, 202, 78));
draw_set_alpha(0.48 + 0.18 * sin(current_time * 0.006));
draw_circle(wx + 8,          lamp_y + 7, 10, false);
draw_circle(wx + hw * 2 - 8, lamp_y + 7, 10, false);
draw_set_alpha(1.0);

// Sign
draw_set_colour(make_colour_rgb(128, 86, 38));
draw_rectangle(x - 54, wy - roof_h + 4, x + 54, wy - roof_h + 20, false);
draw_set_colour(make_colour_rgb(76, 46, 18));
draw_rectangle(x - 54, wy - roof_h + 4, x + 54, wy - roof_h + 20, true);
draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(242, 218, 132));
draw_text_transformed(x, wy - roof_h + 12, "THE SLEEPING FOX", 0.82, 0.82, 0);

// Interact hint
if (near_player) {
    draw_set_colour(make_colour_rgb(255, 255, 200));
    draw_set_alpha(0.88);
    draw_text_transformed(x, wy - roof_h - 6, "[E] Rest at the Inn  (+35% STA, +8h)", 1, 1, 0);
    draw_set_alpha(1.0);
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
