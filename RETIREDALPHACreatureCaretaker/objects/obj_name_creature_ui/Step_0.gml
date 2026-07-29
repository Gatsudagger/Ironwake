cursor_timer = (cursor_timer + 1) mod 60;

// Backspace — remove last character
if (keyboard_check_pressed(vk_backspace)) {
    if (string_length(input_name) > 0) {
        input_name = string_delete(input_name, string_length(input_name), 1);
    }
}

// Printable character input via keyboard_string
if (string_length(keyboard_string) > 0) {
    for (var _i = 1; _i <= string_length(keyboard_string); _i++) {
        var _ch   = string_char_at(keyboard_string, _i);
        var _code = ord(_ch);
        if (string_length(input_name) < max_length) {
            if ((_code >= 65 && _code <= 90)    // A-Z
             || (_code >= 97 && _code <= 122)   // a-z
             || (_code >= 48 && _code <= 57)) {  // 0-9
                input_name += _ch;
            }
        }
    }
    keyboard_string = "";
}

// Button hover
btn_hovered = (mouse_x > btn_cx - btn_w * 0.5 && mouse_x < btn_cx + btn_w * 0.5
            && mouse_y > btn_cy - btn_h * 0.5 && mouse_y < btn_cy + btn_h * 0.5);

// Confirm — Enter key or button click
var _confirm = keyboard_check_pressed(vk_return)
            || (btn_hovered && mouse_check_button_pressed(mb_left));

if (_confirm && !done) {
    done = true;
    var _final_name = input_name;
    if (_final_name == "") {
        _final_name = fantasy_names[irandom(array_length(fantasy_names) - 1)];
    }
    obj_game_controller.starter_creature.name = _final_name;
    room_goto(rm_ranch);
}
