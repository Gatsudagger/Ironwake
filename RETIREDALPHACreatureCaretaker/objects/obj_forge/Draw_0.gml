var wx = x - hw;
var wy = y - wh;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.2);
draw_ellipse(x - hw * 0.85, y + 2, x + hw * 0.85, y + 10, false);
draw_set_alpha(1.0);

// Stone walls
draw_set_colour(make_colour_rgb(102, 95, 85));
draw_rectangle(wx, wy, wx + hw * 2, y, false);
// Stone block pattern
draw_set_colour(make_colour_rgb(82, 76, 66));
var bw = (hw * 2 - 8) / 3;
var bh = (wh - 6) / 3;
for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
        draw_rectangle(
            wx + 4 + col * bw,
            wy + 6 + row * bh,
            wx + 4 + col * bw + bw - 3,
            wy + 6 + row * bh + bh - 3,
            true);
    }
}

// Slate roof
draw_set_colour(make_colour_rgb(52, 48, 44));
draw_triangle(wx - 8, wy, wx + hw * 2 + 8, wy, x, wy - roof_h, false);

// Chimney
draw_set_colour(make_colour_rgb(85, 78, 68));
draw_rectangle(x - 11, wy - roof_h - 22, x + 11, wy, false);
draw_set_colour(make_colour_rgb(48, 42, 36));
draw_rectangle(x - 13, wy - roof_h - 24, x + 13, wy - roof_h - 20, false);
// Ember glow at chimney top
draw_set_alpha(0.55 + 0.22 * sin(current_time * 0.011));
draw_set_colour(make_colour_rgb(222, 98, 18));
draw_rectangle(x - 9, wy - roof_h - 21, x + 9, wy - roof_h - 13, false);
draw_set_alpha(1.0);
// Smoke
draw_set_colour(make_colour_rgb(158, 152, 146));
draw_set_alpha(0.38 + 0.14 * sin(current_time * 0.007));
draw_circle(x,     wy - roof_h - 32, 8, false);
draw_circle(x + 5, wy - roof_h - 42, 5, false);
draw_set_alpha(1.0);

// Heavy door
draw_set_colour(make_colour_rgb(48, 46, 42));
draw_rectangle(x - 15, wy + wh - 30, x + 15, y, false);
draw_set_colour(make_colour_rgb(78, 75, 70));
draw_rectangle(x - 15, wy + wh - 30, x + 15, y, true);
// Forge glow through door crack
draw_set_alpha(0.48 + 0.22 * sin(current_time * 0.015));
draw_set_colour(make_colour_rgb(255, 128, 18));
draw_rectangle(x - 5, wy + wh - 26, x + 5, y - 2, false);
draw_set_alpha(1.0);

// Anvil outside left
var ax = wx - 20;
draw_set_colour(make_colour_rgb(68, 65, 62));
draw_rectangle(ax,     y - 16, ax + 22, y - 9, false);
draw_rectangle(ax + 4, y - 9,  ax + 18, y,     false);
draw_set_colour(make_colour_rgb(45, 42, 39));
draw_rectangle(ax, y - 16, ax + 22, y - 9, true);

// Label
draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(198, 178, 138));
draw_text_transformed(x, wy - roof_h - 8, "FORGE", 0.9, 0.9, 0);

// Interact hint
if (near_player) {
    draw_set_colour(make_colour_rgb(255, 255, 200));
    draw_set_alpha(0.88);
    draw_text_transformed(x, wy - roof_h - 22, "[E] Visit Forge", 1, 1, 0);
    draw_set_alpha(1.0);
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
