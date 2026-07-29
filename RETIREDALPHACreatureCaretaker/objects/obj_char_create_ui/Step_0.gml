// Name input
input_name = keyboard_string;
if (string_length(input_name) > 16) {
    input_name = string_copy(input_name, 1, 16);
    keyboard_string = input_name;
}

var _mx = mouse_x;
var _my = mouse_y;
var _clicked = mouse_check_button_pressed(mb_left);

// Shared layout constants (must match Draw_0)
var _rx      = 410;
var _row_h   = 44;
var _ry      = 80;
var _cx      = _rx + 70;
var _circ_r  = 14;
var _rpanel_r = room_width - 20;
var _mid     = (_rpanel_r + _rx + 70) / 2;

// Skip name row height
_ry += _row_h + 8;

// ROW 2: Skin Tone
var _skin_cy = _ry + _row_h / 2;
for (var _i = 0; _i < array_length(skin_cols); _i++) {
    if (_clicked && point_distance(_mx, _my, _cx + _i * 36, _skin_cy) < _circ_r + 4) {
        skin_sel = _i;
    }
}
_ry += _row_h;

// ROW 3: Eye Color
var _eye_cy = _ry + _row_h / 2;
for (var _i = 0; _i < array_length(eye_cols); _i++) {
    if (_clicked && point_distance(_mx, _my, _cx + _i * 36, _eye_cy) < _circ_r + 4) {
        eye_sel = _i;
    }
}
_ry += _row_h;

// ROW 4: Hair Color
var _hair_cy = _ry + _row_h / 2;
for (var _i = 0; _i < array_length(hair_cols); _i++) {
    if (_clicked && point_distance(_mx, _my, _cx + _i * 32, _hair_cy) < (_circ_r - 2) + 4) {
        hair_sel = _i;
    }
}
_ry += _row_h;

// ROW 5: Hair Style arrows
var _style_cy = _ry + _row_h / 2;
if (_clicked) {
    if (point_distance(_mx, _my, _mid - 80, _style_cy) < 16) {
        style_sel = (style_sel - 1 + array_length(style_names)) mod array_length(style_names);
    }
    if (point_distance(_mx, _my, _mid + 80, _style_cy) < 16) {
        style_sel = (style_sel + 1) mod array_length(style_names);
    }
}
_ry += _row_h;

// ROW 6: Body Type arrows
var _body_cy = _ry + _row_h / 2;
if (_clicked) {
    if (point_distance(_mx, _my, _mid - 80, _body_cy) < 16) {
        body_sel = (body_sel - 1 + array_length(body_names)) mod array_length(body_names);
    }
    if (point_distance(_mx, _my, _mid + 80, _body_cy) < 16) {
        body_sel = (body_sel + 1) mod array_length(body_names);
    }
}
_ry += _row_h;

// ROW 7: Shirt arrows
var _shirt_cy = _ry + _row_h / 2;
if (_clicked) {
    if (point_distance(_mx, _my, _mid - 80, _shirt_cy) < 16) {
        shirt_sel = (shirt_sel - 1 + array_length(shirt_names)) mod array_length(shirt_names);
    }
    if (point_distance(_mx, _my, _mid + 80, _shirt_cy) < 16) {
        shirt_sel = (shirt_sel + 1) mod array_length(shirt_names);
    }
}
_ry += _row_h;

// ROW 8: Pants arrows
var _pants_cy = _ry + _row_h / 2;
if (_clicked) {
    if (point_distance(_mx, _my, _mid - 80, _pants_cy) < 16) {
        pants_sel = (pants_sel - 1 + array_length(pants_names)) mod array_length(pants_names);
    }
    if (point_distance(_mx, _my, _mid + 80, _pants_cy) < 16) {
        pants_sel = (pants_sel + 1) mod array_length(pants_names);
    }
}
_ry += _row_h;

// ROW 9: Boots arrows
var _boots_cy = _ry + _row_h / 2;
if (_clicked) {
    if (point_distance(_mx, _my, _mid - 80, _boots_cy) < 16) {
        boots_sel = (boots_sel - 1 + array_length(boots_names)) mod array_length(boots_names);
    }
    if (point_distance(_mx, _my, _mid + 80, _boots_cy) < 16) {
        boots_sel = (boots_sel + 1) mod array_length(boots_names);
    }
}
_ry += _row_h + 4 + 6 + 26; // divider + header

// Item box arrows (right panel)
var _ibox_h  = 80;
var _ibox_cy = _ry + _ibox_h / 2;
if (_clicked) {
    if (point_distance(_mx, _my, _rx + 14, _ibox_cy) < 20) {
        item_sel = (item_sel - 1 + array_length(item_names)) mod array_length(item_names);
    }
    if (point_distance(_mx, _my, _rpanel_r - 14, _ibox_cy) < 20) {
        item_sel = (item_sel + 1) mod array_length(item_names);
    }
}

// Left panel item swatch arrows
var _lcx  = (30 + 380) / 2;
var _iswy = 440;
var _isw  = 40;
if (_clicked) {
    if (point_distance(_mx, _my, _lcx - _isw - 14, _iswy) < 18) {
        item_sel = (item_sel - 1 + array_length(item_names)) mod array_length(item_names);
    }
    if (point_distance(_mx, _my, _lcx + _isw + 14, _iswy) < 18) {
        item_sel = (item_sel + 1) mod array_length(item_names);
    }
}

// Continue button
var _bx = btn_cx - btn_w / 2;
var _by = btn_cy - btn_h / 2;
btn_hovered = (_mx >= _bx && _mx <= _bx + btn_w
            && _my >= _by && _my <= _by + btn_h);

if (btn_hovered && _clicked) {
    if (string_length(string_trim(input_name)) > 0) {
        obj_game_controller.player_name   = input_name;
        obj_game_controller.skin_tone     = skin_sel;
        obj_game_controller.hair_color    = hair_sel;
        obj_game_controller.hair_style    = style_sel;
        obj_game_controller.eye_color     = eye_sel;
        obj_game_controller.body_type     = body_sel;
        obj_game_controller.shirt_style   = shirt_sel;
        obj_game_controller.pants_style   = pants_sel;
        obj_game_controller.boots_style   = boots_sel;
        obj_game_controller.starting_item = item_sel;
        room_goto(rm_biome_select);
    }
}
