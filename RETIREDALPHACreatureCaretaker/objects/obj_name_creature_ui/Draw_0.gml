draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var W = room_width;   // 1366
var H = room_height;  // 768

// Background
draw_set_colour(make_colour_rgb(10, 10, 28));
draw_rectangle(0, 0, W, H, false);

// ── Left side: creature portrait ──────────────────────────────────────────────
var _spr   = portrait_sprites[creature_species];
var _sw    = sprite_get_width(_spr);
var _sh    = sprite_get_height(_spr);
var _scale = min(420.0 / _sw, 480.0 / _sh);
var _pdx   = 320 - (_sw * _scale) * 0.5;
var _pdy   = H * 0.5 - (_sh * _scale) * 0.5;
draw_sprite_ext(_spr, 0, _pdx, _pdy, _scale, _scale, 0, c_white, 1);

// Species name below portrait
draw_set_halign(fa_center);
draw_set_colour(make_colour_rgb(160, 180, 255));
draw_text_transformed(320, _pdy + _sh * _scale + 16,
    global.creature_data[creature_species].name, 1.4, 1.4, 0);

// Vertical divider
draw_set_colour(make_colour_rgb(45, 45, 88));
draw_rectangle(640, 80, 642, H - 80, false);

// ── Right side: naming panel ───────────────────────────────────────────────────
scr_draw_panel(panel_x, panel_y, panel_w, panel_h);

// Panel title
draw_set_halign(fa_center);
draw_set_colour(make_colour_rgb(255, 215, 0));
draw_text_transformed(panel_x + panel_w * 0.5, panel_y + 24,
    "Name Your Creature", 1.8, 1.8, 0);

// Divider under title
draw_set_colour(make_colour_rgb(55, 55, 100));
draw_rectangle(panel_x + 20, panel_y + 62, panel_x + panel_w - 20, panel_y + 64, false);

// Input label
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(180, 180, 220));
draw_text_transformed(panel_x + 30, panel_y + 90, "Enter a name:", 1.1, 1.1, 0);

// Input box
var _bx = panel_x + 30;
var _by = panel_y + 128;
var _bw = panel_w - 60;
var _bh = 48;

draw_set_colour(make_colour_rgb(12, 12, 32));
draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, false);
draw_set_colour(make_colour_rgb(80, 80, 160));
draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, true);

// Text + blinking cursor
var _cursor_char = (cursor_timer < 30) ? "|" : " ";
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(240, 240, 255));
draw_text_transformed(_bx + 10, _by + 10, input_name + _cursor_char, 1.3, 1.3, 0);

// Character count (bottom-right of box)
draw_set_halign(fa_right);
draw_set_colour(make_colour_rgb(75, 75, 115));
draw_text_transformed(_bx + _bw, _by + _bh + 6,
    string(string_length(input_name)) + " / " + string(max_length), 1, 1, 0);

// Confirm button
scr_draw_pixel_button(btn_cx - btn_w * 0.5, btn_cy - btn_h * 0.5, btn_w, btn_h,
                      "CONFIRM", btn_hovered, 1.3);

// Hint
draw_set_halign(fa_center);
draw_set_colour(make_colour_rgb(70, 70, 110));
draw_text_transformed(panel_x + panel_w * 0.5, panel_y + panel_h - 22,
    "[ Enter ] Confirm  —  leave blank for a random name", 1, 1, 0);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
