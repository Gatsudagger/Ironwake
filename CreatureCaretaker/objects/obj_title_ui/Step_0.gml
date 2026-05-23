title_alpha = min(1, title_alpha + fade_speed);

var mx = mouse_x;
var my = mouse_y;

btn_hovered = (mx > btn_cx - btn_w / 2 && mx < btn_cx + btn_w / 2
            && my > btn_cy - btn_h / 2 && my < btn_cy + btn_h / 2);

if (btn_hovered && mouse_check_button_pressed(mb_left)) {
	room_goto(rm_char_create);
}
