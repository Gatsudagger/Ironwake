input_name = keyboard_string;
if (string_length(input_name) > 16) {
    input_name = string_copy(input_name, 1, 16);
    keyboard_string = input_name;
}

var _bx = btn_cx - btn_w / 2;
var _by = btn_cy - btn_h / 2;
btn_hovered = (mouse_x >= _bx && mouse_x <= _bx + btn_w
            && mouse_y >= _by && mouse_y <= _by + btn_h);

if (btn_hovered && mouse_check_button_pressed(mb_left)) {
    if (string_length(string_trim(input_name)) > 0) {
        obj_game_controller.player_name = input_name;
        room_goto(rm_biome_select);
    }
}
