var _gc = obj_game_controller;
if (!instance_exists(_gc)) exit;

btn_hover = (mouse_x >= btn_bx && mouse_x <= btn_bx + btn_bw &&
             mouse_y >= btn_by && mouse_y <= btn_by + btn_bh);

if ((btn_hover && mouse_check_button_pressed(mb_left)) ||
     keyboard_check_pressed(vk_escape)) {
    room_goto(back_room);
}
