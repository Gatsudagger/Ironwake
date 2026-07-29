draw_set_font(-1);

// Background
draw_set_colour(make_colour_rgb(10, 10, 25));
draw_rectangle(0, 0, room_width, room_height, false);

// Title
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(200, 180, 255));
draw_text_transformed(room_width / 2, 30, "Create Your Character", 2, 2, 0);

// ── LEFT PANEL ────────────────────────────────────────────────────────────────
var _lx1 = 30;
var _lx2 = 380;
var _ly1 = 60;
var _ly2 = 620;
var _lcx = (_lx1 + _lx2) / 2;

draw_set_colour(make_colour_rgb(18, 18, 40));
draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
draw_set_colour(make_colour_rgb(60, 60, 120));
draw_rectangle(_lx1, _ly1, _lx2, _ly2, true);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(120, 115, 160));
draw_text_transformed(_lcx, _ly1 + 18, "Preview", 1, 1, 0);

draw_sprite_ext(spr_player, 0, _lcx, 390, 3, 3, 0, c_white, 1);

// Item badge
var _ic = item_cols[item_sel];
var _iswx = _lcx;
var _iswy = 455;
var _isw_w = 200;
var _isw_h = 70;

// Dark background
draw_set_colour(make_colour_rgb(12, 12, 30));
draw_set_alpha(0.92);
draw_rectangle(_iswx - _isw_w / 2, _iswy - _isw_h / 2, _iswx + _isw_w / 2, _iswy + _isw_h / 2, false);
draw_set_alpha(1);

// Colored border
draw_set_colour(_ic);
draw_rectangle(_iswx - _isw_w / 2, _iswy - _isw_h / 2, _iswx + _isw_w / 2, _iswy + _isw_h / 2, true);

// Item sprite (0.62× scale, right-aligned in badge, feet at badge bottom)
draw_sprite_ext(item_sprites[item_sel], 0, _iswx + 64, _iswy + _isw_h / 2 - 2, 0.62, 0.62, 0, c_white, 1);

// Item name and slot label (left-side of badge)
draw_set_halign(fa_left);
draw_set_valign(fa_middle);
draw_set_colour(c_white);
draw_text_transformed(_iswx - _isw_w / 2 + 8, _iswy - 10, item_names[item_sel], 0.85, 0.85, 0);
draw_set_colour(_ic);
draw_text_transformed(_iswx - _isw_w / 2 + 8, _iswy + 10, "[" + item_slots[item_sel] + "]", 0.78, 0.78, 0);

// Cycle arrows
draw_set_colour(make_colour_rgb(200, 200, 220));
draw_set_halign(fa_center);
draw_text_transformed(_iswx - _isw_w / 2 - 16, _iswy, "<", 1.3, 1.3, 0);
draw_text_transformed(_iswx + _isw_w / 2 + 16, _iswy, ">", 1.3, 1.3, 0);

// ── RIGHT PANEL ───────────────────────────────────────────────────────────────
var _rx   = 410;
var _row_h = 44;
var _ry   = 80;
var _circ_r = 14;
var _arrow_w = 22;

// Helper positions (right edge for arrows)
var _rpanel_r = room_width - 20;

// ROW 1: Name field
draw_set_halign(fa_left);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Name", 1, 1, 0);

var _fw = _rpanel_r - _rx - 60;
var _fh = 36;
var _fx = _rx + 60;
var _fy = _ry + (_row_h - _fh) / 2;
draw_set_colour(make_colour_rgb(20, 20, 40));
draw_rectangle(_fx, _fy, _fx + _fw, _fy + _fh, false);
draw_set_colour(make_colour_rgb(80, 80, 140));
draw_rectangle(_fx, _fy, _fx + _fw, _fy + _fh, true);
var _cursor = ((current_time div 500) mod 2 == 0) ? "|" : "";
draw_set_halign(fa_center);
draw_set_colour(make_colour_rgb(232, 232, 255));
draw_text_transformed(_fx + _fw / 2, _fy + _fh / 2, input_name + _cursor, 1, 1, 0);

_ry += _row_h + 8;

// ROW 2: Skin Tone
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Skin", 1, 1, 0);
var _cx = _rx + 70;
for (var _i = 0; _i < array_length(skin_cols); _i++) {
    draw_set_colour(skin_cols[_i]);
    draw_circle(_cx + _i * 36, _ry + _row_h / 2, _circ_r, false);
    if (_i == skin_sel) {
        draw_set_colour(make_colour_rgb(255, 255, 255));
        draw_circle(_cx + _i * 36, _ry + _row_h / 2, _circ_r + 2, true);
    }
}
_ry += _row_h;

// ROW 3: Eye Color
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Eyes", 1, 1, 0);
for (var _i = 0; _i < array_length(eye_cols); _i++) {
    draw_set_colour(eye_cols[_i]);
    draw_circle(_cx + _i * 36, _ry + _row_h / 2, _circ_r, false);
    if (_i == eye_sel) {
        draw_set_colour(make_colour_rgb(255, 255, 255));
        draw_circle(_cx + _i * 36, _ry + _row_h / 2, _circ_r + 2, true);
    }
}
_ry += _row_h;

// ROW 4: Hair Color
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Hair", 1, 1, 0);
for (var _i = 0; _i < array_length(hair_cols); _i++) {
    draw_set_colour(hair_cols[_i]);
    draw_circle(_cx + _i * 32, _ry + _row_h / 2, _circ_r - 2, false);
    if (_i == hair_sel) {
        draw_set_colour(make_colour_rgb(255, 255, 255));
        draw_circle(_cx + _i * 32, _ry + _row_h / 2, _circ_r, true);
    }
}
_ry += _row_h;

// ROW 5: Hair Style
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Style", 1, 1, 0);
var _mid = (_rpanel_r + _rx + 70) / 2;
draw_set_colour(make_colour_rgb(180, 180, 220));
draw_set_halign(fa_center);
draw_text_transformed(_mid - 80, _ry + _row_h / 2, "<", 1.2, 1.2, 0);
draw_text_transformed(_mid,      _ry + _row_h / 2, style_names[style_sel], 1, 1, 0);
draw_text_transformed(_mid + 80, _ry + _row_h / 2, ">", 1.2, 1.2, 0);
_ry += _row_h;

// ROW 6: Body Type
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Body", 1, 1, 0);
draw_set_colour(make_colour_rgb(180, 180, 220));
draw_set_halign(fa_center);
draw_text_transformed(_mid - 80, _ry + _row_h / 2, "<", 1.2, 1.2, 0);
draw_text_transformed(_mid,      _ry + _row_h / 2, body_names[body_sel], 1, 1, 0);
draw_text_transformed(_mid + 80, _ry + _row_h / 2, ">", 1.2, 1.2, 0);
_ry += _row_h;

// ROW 7: Shirt
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Shirt", 1, 1, 0);
draw_set_colour(make_colour_rgb(180, 180, 220));
draw_set_halign(fa_center);
draw_text_transformed(_mid - 80, _ry + _row_h / 2, "<", 1.2, 1.2, 0);
draw_text_transformed(_mid,      _ry + _row_h / 2, shirt_names[shirt_sel], 1, 1, 0);
draw_text_transformed(_mid + 80, _ry + _row_h / 2, ">", 1.2, 1.2, 0);
_ry += _row_h;

// ROW 8: Pants
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Pants", 1, 1, 0);
draw_set_colour(make_colour_rgb(180, 180, 220));
draw_set_halign(fa_center);
draw_text_transformed(_mid - 80, _ry + _row_h / 2, "<", 1.2, 1.2, 0);
draw_text_transformed(_mid,      _ry + _row_h / 2, pants_names[pants_sel], 1, 1, 0);
draw_text_transformed(_mid + 80, _ry + _row_h / 2, ">", 1.2, 1.2, 0);
_ry += _row_h;

// ROW 9: Boots
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(160, 155, 200));
draw_text_transformed(_rx, _ry + _row_h / 2, "Boots", 1, 1, 0);
draw_set_colour(make_colour_rgb(180, 180, 220));
draw_set_halign(fa_center);
draw_text_transformed(_mid - 80, _ry + _row_h / 2, "<", 1.2, 1.2, 0);
draw_text_transformed(_mid,      _ry + _row_h / 2, boots_names[boots_sel], 1, 1, 0);
draw_text_transformed(_mid + 80, _ry + _row_h / 2, ">", 1.2, 1.2, 0);
_ry += _row_h + 4;

// Section divider
draw_set_colour(make_colour_rgb(60, 60, 100));
draw_line(_rx, _ry, _rpanel_r, _ry);
_ry += 6;
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(200, 180, 255));
draw_text_transformed(_rx, _ry + 10, "Starting Item", 1.1, 1.1, 0);
_ry += 26;

// ITEM BOX
var _ibox_h = 90;
var _ibox_ic = item_cols[item_sel];
draw_set_colour(_ibox_ic);
draw_set_alpha(0.2);
draw_rectangle(_rx, _ry, _rpanel_r, _ry + _ibox_h, false);
draw_set_alpha(1.0);
draw_set_colour(_ibox_ic);
draw_rectangle(_rx, _ry, _rpanel_r, _ry + _ibox_h, true);

// Item sprite on the right side (0.65× scale, feet at box bottom, clear of arrow)
draw_sprite_ext(item_sprites[item_sel], 0, _rpanel_r - 52, _ry + _ibox_h - 2, 0.65, 0.65, 0, c_white, 1);

// Left/right arrows
var _ibcy = _ry + _ibox_h / 2;
draw_set_colour(make_colour_rgb(210, 210, 240));
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_text_transformed(_rx + 14, _ibcy, "<", 1.4, 1.4, 0);
draw_text_transformed(_rpanel_r - 14, _ibcy, ">", 1.4, 1.4, 0);

// Item name and slot (left-aligned, leaving room for sprite on right)
var _itx = _rx + 28;
draw_set_halign(fa_left);
draw_set_colour(make_colour_rgb(232, 232, 255));
draw_text_transformed(_itx, _ry + 16, item_names[item_sel], 1.0, 1.0, 0);
draw_set_colour(_ibox_ic);
draw_text_transformed(_itx, _ry + 32, "[" + item_slots[item_sel] + "]", 0.85, 0.85, 0);

// Description
draw_set_colour(make_colour_rgb(160, 160, 200));
var _desc_lines = string_split(item_descs[item_sel], "\n");
for (var _li = 0; _li < array_length(_desc_lines); _li++) {
    draw_text_transformed(_itx, _ry + 50 + _li * 16, _desc_lines[_li], 0.78, 0.78, 0);
}

_ry += _ibox_h + 12;

// ── CONTINUE button ───────────────────────────────────────────────────────────
var can_continue = string_length(string_trim(input_name)) > 0;
var _bx = btn_cx - btn_w / 2;
var _by = btn_cy - btn_h / 2;

draw_set_colour(make_colour_rgb(0, 0, 0));
draw_rectangle(_bx + 3, _by + 3, _bx + btn_w + 3, _by + btn_h + 3, false);
var _btn_col = can_continue
    ? (btn_hovered ? make_colour_rgb(90, 127, 160) : make_colour_rgb(61, 90, 128))
    : make_colour_rgb(36, 36, 56);
draw_set_colour(_btn_col);
draw_rectangle(_bx, _by, _bx + btn_w, _by + btn_h, false);
draw_set_colour(can_continue ? make_colour_rgb(140, 180, 220) : make_colour_rgb(60, 60, 90));
draw_rectangle(_bx, _by, _bx + btn_w, _by + btn_h, true);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(can_continue ? make_colour_rgb(232, 232, 255) : make_colour_rgb(90, 90, 120));
draw_text_transformed(btn_cx, btn_cy, "CONTINUE  ▶", 2, 2, 0);

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_colour(c_white);
