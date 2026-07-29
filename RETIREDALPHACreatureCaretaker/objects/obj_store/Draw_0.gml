var wx = x - hw;
var wy = y - wh;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.2);
draw_ellipse(x - hw * 0.9, y + 2, x + hw * 0.9, y + 12, false);
draw_set_alpha(1.0);

// Walls
draw_set_colour(make_colour_rgb(198, 165, 108));
draw_rectangle(wx, wy, wx + hw * 2, y, false);

// Timber frame
draw_set_colour(make_colour_rgb(108, 72, 36));
draw_rectangle(wx,               wy, wx + 6,           y, false);
draw_rectangle(wx + hw * 2 - 6,  wy, wx + hw * 2,      y, false);
draw_rectangle(wx, wy + wh / 2 - 3, wx + hw * 2, wy + wh / 2 + 3, false);

// Roof
draw_set_colour(make_colour_rgb(102, 52, 24));
draw_triangle(wx - 12, wy, wx + hw * 2 + 12, wy, x, wy - roof_h, false);

// Awning
draw_set_colour(make_colour_rgb(152, 48, 34));
draw_rectangle(wx - 4, wy + 8, wx + hw * 2 + 4, wy + 20, false);

// Door
draw_set_colour(make_colour_rgb(68, 42, 18));
draw_rectangle(x - 11, wy + wh - 28, x + 11, y, false);
draw_set_colour(make_colour_rgb(108, 72, 36));
draw_rectangle(x - 11, wy + wh - 28, x + 11, y, true);

// Left window
draw_set_colour(make_colour_rgb(165, 215, 245));
draw_rectangle(wx + 12, wy + 24, wx + 36, wy + 42, false);
draw_set_colour(make_colour_rgb(78, 132, 172));
draw_rectangle(wx + 12, wy + 24, wx + 36, wy + 42, true);
draw_line(wx + 24, wy + 24, wx + 24, wy + 42);
draw_line(wx + 12, wy + 33, wx + 36, wy + 33);

// Right window
var rwx = wx + hw * 2 - 36;
draw_set_colour(make_colour_rgb(165, 215, 245));
draw_rectangle(rwx, wy + 24, rwx + 24, wy + 42, false);
draw_set_colour(make_colour_rgb(78, 132, 172));
draw_rectangle(rwx, wy + 24, rwx + 24, wy + 42, true);
draw_line(rwx + 12, wy + 24, rwx + 12, wy + 42);
draw_line(rwx,      wy + 33, rwx + 24, wy + 33);

// Sign
draw_set_colour(make_colour_rgb(142, 102, 52));
draw_rectangle(x - 42, wy - roof_h + 2, x + 42, wy - roof_h + 18, false);
draw_set_colour(make_colour_rgb(78, 52, 22));
draw_rectangle(x - 42, wy - roof_h + 2, x + 42, wy - roof_h + 18, true);
draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(242, 212, 142));
draw_text_transformed(x, wy - roof_h + 10, "MARKET", 0.9, 0.9, 0);

// Barrel (right side)
var bx = wx + hw * 2 + 8;
draw_set_colour(make_colour_rgb(128, 82, 42));
draw_circle(bx, y - 12, 9, false);
draw_set_colour(make_colour_rgb(88, 55, 22));
draw_circle(bx, y - 12, 9, true);
draw_line(bx - 7, y - 19, bx + 7, y - 19);
draw_line(bx - 8, y - 12, bx + 8, y - 12);
draw_line(bx - 7, y - 5,  bx + 7, y - 5);

// Interact hint
if (near_player) {
    draw_set_colour(make_colour_rgb(255, 255, 200));
    draw_set_alpha(0.88);
    draw_text_transformed(x, wy - roof_h - 6, "[E] Browse Market", 1, 1, 0);
    draw_set_alpha(1.0);
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
