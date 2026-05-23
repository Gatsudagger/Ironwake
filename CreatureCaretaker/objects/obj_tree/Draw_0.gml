var tx = x;
var ty = y;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.14);
draw_ellipse(tx - 18, ty + 2, tx + 18, ty + 10, false);
draw_set_alpha(1.0);

switch (tree_type) {
    case 0: // Pine / fir
        draw_set_colour(make_colour_rgb(92, 62, 32));
        draw_rectangle(tx - 5, ty - 8, tx + 5, ty + 4, false);
        draw_set_colour(make_colour_rgb(38, 82, 38));
        draw_triangle(tx - 22, ty - 8,  tx + 22, ty - 8,  tx, ty - 50, false);
        draw_set_colour(make_colour_rgb(34, 72, 34));
        draw_triangle(tx - 17, ty - 22, tx + 17, ty - 22, tx, ty - 56, false);
        draw_set_colour(make_colour_rgb(30, 62, 30));
        draw_triangle(tx - 11, ty - 36, tx + 11, ty - 36, tx, ty - 60, false);
        break;

    case 1: // Broad oak
        draw_set_colour(make_colour_rgb(102, 70, 36));
        draw_rectangle(tx - 7, ty - 14, tx + 7, ty + 4, false);
        draw_rectangle(tx - 4, ty - 32, tx + 4, ty - 14, false);
        draw_set_colour(make_colour_rgb(34, 96, 34));
        draw_circle(tx,      ty - 44, 26, false);
        draw_set_colour(make_colour_rgb(42, 112, 42));
        draw_circle(tx - 14, ty - 40, 18, false);
        draw_circle(tx + 15, ty - 42, 16, false);
        draw_set_colour(make_colour_rgb(28, 82, 28));
        draw_circle(tx,      ty - 54, 14, false);
        break;

    case 2: // Small bush / young tree
        draw_set_colour(make_colour_rgb(85, 58, 28));
        draw_rectangle(tx - 4, ty - 4, tx + 4, ty + 4, false);
        draw_set_colour(make_colour_rgb(44, 105, 26));
        draw_circle(tx,      ty - 18, 15, false);
        draw_set_colour(make_colour_rgb(54, 125, 32));
        draw_circle(tx - 8,  ty - 16, 11, false);
        draw_circle(tx + 9,  ty - 15, 10, false);
        break;
}
