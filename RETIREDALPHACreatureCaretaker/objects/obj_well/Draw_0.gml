var wx = x;
var wy = y;

// Ground shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.2);
draw_ellipse(wx - 22, wy + 2, wx + 22, wy + 11, false);
draw_set_alpha(1.0);

// Stone base ring
draw_set_colour(make_colour_rgb(118, 110, 96));
draw_circle(wx, wy - 4, 20, false);
draw_set_colour(make_colour_rgb(92, 85, 73));
draw_circle(wx, wy - 4, 20, true);
draw_circle(wx, wy - 4, 13, true);

// Stone blocks around rim
draw_set_colour(make_colour_rgb(138, 128, 110));
for (var i = 0; i < 6; i++) {
    var ang = i * 60;
    var sx  = wx + lengthdir_x(17, ang);
    var sy  = (wy - 4) + lengthdir_y(17, ang);
    draw_rectangle(sx - 3, sy - 2, sx + 3, sy + 2, false);
}

// Water inside
draw_set_colour(make_colour_rgb(52, 112, 172));
draw_circle(wx, wy - 4, 12, false);
draw_set_colour(make_colour_rgb(78, 148, 208));
draw_set_alpha(0.45);
draw_circle(wx - 4, wy - 6, 5, false);
draw_set_alpha(1.0);

// Wooden posts
draw_set_colour(make_colour_rgb(108, 76, 38));
draw_rectangle(wx - 18, wy - 42, wx - 12, wy - 4, false);
draw_rectangle(wx + 12,  wy - 42, wx + 18,  wy - 4, false);
// Crossbeam
draw_rectangle(wx - 22, wy - 42, wx + 22, wy - 36, false);

// Rope and bucket
draw_set_colour(make_colour_rgb(172, 142, 85));
draw_line(wx, wy - 38, wx + 6, wy - 20);
draw_set_colour(make_colour_rgb(92, 62, 32));
draw_rectangle(wx + 1, wy - 20, wx + 11, wy - 10, false);
draw_set_colour(make_colour_rgb(130, 95, 55));
draw_rectangle(wx + 1, wy - 20, wx + 11, wy - 10, true);

// Flowers around base
var flower_pos = [[-26, 4], [22, -4], [-20, -15], [25, 9], [-8, 13], [10, 15]];
for (var f = 0; f < 6; f++) {
    var fx = wx + flower_pos[f][0];
    var fy = wy + flower_pos[f][1];
    draw_set_colour(make_colour_rgb(78, 158, 58));
    draw_circle(fx, fy, 3, false);
    draw_set_colour(make_colour_rgb(248, 98, 118));
    draw_circle(fx, fy - 4, 3, false);
}

// Village name label
draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_colour(make_colour_rgb(232, 220, 188));
draw_set_alpha(0.9);
draw_text_transformed(wx, wy - 46, "~ Fernhaven ~", 1, 1, 0);
draw_set_alpha(1.0);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
