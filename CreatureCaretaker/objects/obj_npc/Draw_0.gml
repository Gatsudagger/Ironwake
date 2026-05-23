var bob   = moving ? sin(walk_t * 0.21) * 2 : 0;
var leg_l = moving ? sin(walk_t * 0.21) * 5 : 0;
var px = x;
var py = y;

// Shadow
draw_set_colour(make_colour_rgb(0, 0, 0));
draw_set_alpha(0.18);
draw_ellipse(px - 9, py + 17, px + 9, py + 23, false);
draw_set_alpha(1.0);

// Legs
draw_set_colour(pants_col);
draw_rectangle(px - 8,  py + 11 + bob, px - 2,  py + 24 + bob + leg_l, false);
draw_rectangle(px + 2,  py + 11 + bob, px + 8,  py + 24 + bob - leg_l, false);

// Body
draw_set_colour(shirt_col);
draw_rectangle(px - 9, py - 9 + bob, px + 9, py + 13 + bob, false);

// Arms
draw_set_colour(skin_col);
draw_rectangle(px - 14, py - 7 + bob, px - 9,  py + 9 + bob - leg_l, false);
draw_rectangle(px + 9,  py - 7 + bob, px + 14, py + 9 + bob + leg_l, false);

// Head
draw_set_colour(skin_col);
draw_rectangle(px - 8, py - 26 + bob, px + 8, py - 10 + bob, false);

// Hair
draw_set_colour(hair_col);
switch (hair_style) {
    case 0: // Short
        draw_rectangle(px - 9, py - 29 + bob, px + 9, py - 23 + bob, false);
        draw_rectangle(px - 9, py - 26 + bob, px - 6, py - 19 + bob, false);
        draw_rectangle(px + 6,  py - 26 + bob, px + 9, py - 19 + bob, false);
        break;
    case 1: // Long
        draw_rectangle(px - 9, py - 29 + bob, px + 9, py - 23 + bob, false);
        draw_rectangle(px - 11, py - 26 + bob, px - 7, py + 6 + bob, false);
        draw_rectangle(px + 7,  py - 26 + bob, px + 11, py + 6 + bob, false);
        break;
    case 2: // Bun
        draw_rectangle(px - 9, py - 29 + bob, px + 9, py - 23 + bob, false);
        draw_circle(px, py - 33 + bob, 5, false);
        break;
}

// Eyes (direction-aware)
draw_set_colour(make_colour_rgb(35, 25, 15));
switch (facing) {
    case 0: // Down
        draw_rectangle(px - 5, py - 22 + bob, px - 3, py - 19 + bob, false);
        draw_rectangle(px + 3, py - 22 + bob, px + 5, py - 19 + bob, false);
        draw_set_colour(make_colour_rgb(200, 200, 240));
        draw_rectangle(px - 5, py - 22 + bob, px - 3, py - 20 + bob, false);
        draw_rectangle(px + 3, py - 22 + bob, px + 5, py - 20 + bob, false);
        break;
    case 1: // Up — back of head
        break;
    case 2: // Left
        draw_rectangle(px - 6, py - 22 + bob, px - 4, py - 19 + bob, false);
        draw_set_colour(make_colour_rgb(200, 200, 240));
        draw_rectangle(px - 6, py - 22 + bob, px - 4, py - 20 + bob, false);
        break;
    case 3: // Right
        draw_rectangle(px + 4, py - 22 + bob, px + 6, py - 19 + bob, false);
        draw_set_colour(make_colour_rgb(200, 200, 240));
        draw_rectangle(px + 4, py - 22 + bob, px + 6, py - 20 + bob, false);
        break;
}

// Name tag
draw_set_font(-1);
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_colour(make_colour_rgb(230, 218, 180));
draw_set_alpha(0.82);
draw_text_transformed(px, py - 31 + bob, npc_name, 0.8, 0.8, 0);
draw_set_alpha(1.0);

// Talk hint
if (near_player) {
    draw_set_colour(make_colour_rgb(255, 255, 200));
    draw_set_alpha(0.9);
    draw_text_transformed(px, py - 42 + bob, "[E] Talk", 1, 1, 0);
    draw_set_alpha(1.0);
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
