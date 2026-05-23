draw_set_font(-1);

// Background
draw_set_colour(make_colour_rgb(8, 12, 22));
draw_rectangle(0, 0, room_width, room_height, false);

// Header
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(200, 180, 255));
draw_text_transformed(room_width / 2, 100, "Create Your Character", 2, 2, 0);

// Name label
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(room_width / 2, 220, "Enter your name:", 1, 1, 0);

// Name input field box
var _fw = 400;
var _fh = 48;
var _fx = room_width / 2 - _fw / 2;
var _fy = 248;
draw_set_colour(make_colour_rgb(20, 20, 40));
draw_rectangle(_fx, _fy, _fx + _fw, _fy + _fh, false);
draw_set_colour(make_colour_rgb(80, 80, 140));
draw_rectangle(_fx, _fy, _fx + _fw, _fy + _fh, true);

// Typed name + blinking cursor
var _cursor = ((current_time div 500) mod 2 == 0) ? "|" : "";
draw_set_colour(make_colour_rgb(232, 232, 255));
draw_text_transformed(room_width / 2, _fy + _fh / 2, input_name + _cursor, 1, 1, 0);

// Hint
draw_set_colour(make_colour_rgb(80, 75, 110));
draw_text_transformed(room_width / 2, _fy + _fh + 22, "Max 16 characters", 1, 1, 0);

// ── Continue button ───────────────────────────────────────────────────────────
var can_continue = string_length(string_trim(input_name)) > 0;
var _bx = btn_cx - btn_w / 2;
var _by = btn_cy - btn_h / 2;

draw_set_colour(make_colour_rgb(0, 0, 0));
draw_rectangle(_bx + 3, _by + 3, _bx + btn_w + 3, _by + btn_h + 3, false);

var _btn_col = make_colour_rgb(61, 90, 128);
if (!can_continue) _btn_col = make_colour_rgb(36, 36, 56);
else if (btn_hovered) _btn_col = make_colour_rgb(90, 127, 160);
draw_set_colour(_btn_col);
draw_rectangle(_bx, _by, _bx + btn_w, _by + btn_h, false);
draw_set_colour(!can_continue ? make_colour_rgb(60, 60, 90) : make_colour_rgb(140, 180, 220));
draw_rectangle(_bx, _by, _bx + btn_w, _by + btn_h, true);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(!can_continue ? make_colour_rgb(90, 90, 120) : make_colour_rgb(232, 232, 255));
draw_text_transformed(btn_cx, btn_cy, "CONTINUE  ▶", 2, 2, 0);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_white);
