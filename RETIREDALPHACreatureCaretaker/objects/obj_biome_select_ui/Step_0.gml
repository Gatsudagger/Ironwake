var _mx = mouse_x;
var _my = mouse_y;

for (var _i = 0; _i < BIOME.COUNT; _i++) {
    var _cx = cards_x0 + _i * (card_w + card_gap);
    if (mouse_check_button_pressed(mb_left)
     && _mx > _cx && _mx < _cx + card_w
     && _my > cards_y && _my < cards_y + card_h) {
        selected_biome = _i;
    }
}

btn_hovered = (_mx > btn_cx - btn_w / 2 && _mx < btn_cx + btn_w / 2
            && _my > btn_cy - btn_h / 2 && _my < btn_cy + btn_h / 2);

if (btn_hovered && mouse_check_button_pressed(mb_left)) {
    obj_game_controller.biome_id = selected_biome;
    var _ground_cols = [
        make_colour_rgb(180,190,200),
        make_colour_rgb(50, 110, 50),
        make_colour_rgb(20,  55, 20),
        make_colour_rgb(180,155, 85),
        make_colour_rgb(45,  40, 60),
    ];
    room_set_background_colour(rm_ranch, _ground_cols[obj_game_controller.biome_id], true);
    room_goto(rm_creature_select);
}
