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
    room_goto(rm_creature_select);
}
