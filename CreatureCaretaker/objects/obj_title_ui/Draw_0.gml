draw_set_font(-1);
draw_set_alpha(title_alpha);

// Background — dark gradient from navy to deep purple
draw_set_colour(make_colour_rgb(8, 8, 22));
draw_rectangle(0, 0, room_width, room_height, false);
draw_set_colour(make_colour_rgb(16, 8, 32));
draw_rectangle(0, room_height * 0.45, room_width, room_height, false);

// Decorative accent bar below title area
draw_set_colour(make_colour_rgb(80, 40, 120));
draw_rectangle(60, 370, room_width - 60, 374, false);
draw_set_colour(make_colour_rgb(50, 20, 80));
draw_rectangle(60, 374, room_width - 60, 376, false);

// Title drop-shadow
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(55, 18, 95));
draw_text_transformed(room_width / 2 + 5, 235, "CREATURE CARETAKER", 4, 4, 0);

// Title
draw_set_colour(make_colour_rgb(255, 215, 0));
draw_text_transformed(room_width / 2, 230, "CREATURE CARETAKER", 4, 4, 0);

// Subtitle
draw_set_colour(make_colour_rgb(175, 145, 215));
draw_text_transformed(room_width / 2, 315, "~ A Fantasy Breeding RPG ~", 2, 2, 0);

// Version stamp
draw_set_halign(fa_right);
draw_set_valign(fa_bottom);
draw_set_colour(make_colour_rgb(70, 70, 100));
draw_text_transformed(room_width - 16, room_height - 12, "v0.1", 1, 1, 0);

// New Game button
scr_draw_pixel_button(btn_cx - btn_w / 2, btn_cy - btn_h / 2, btn_w, btn_h,
                      "NEW GAME", btn_hovered, 2);

draw_set_alpha(1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
