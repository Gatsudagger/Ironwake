if (instance_exists(obj_task_ui) && (obj_task_ui.show_tasks || obj_task_ui.show_stats)) exit;

if (instance_exists(obj_task_ui) && (obj_task_ui.show_tasks || obj_task_ui.show_stats)) exit;

var dx = 0, dy = 0;
if (keyboard_check(vk_left)  || keyboard_check(ord("A"))) { dx -= 1; facing = 2; }
if (keyboard_check(vk_right) || keyboard_check(ord("D"))) { dx += 1; facing = 3; }
if (keyboard_check(vk_up)    || keyboard_check(ord("W"))) { dy -= 1; facing = 1; }
if (keyboard_check(vk_down)  || keyboard_check(ord("S"))) { dy += 1; facing = 0; }

moving = (dx != 0 || dy != 0);
depth  = -round(y);
depth  = -round(y);

if (moving) {
	if (dx != 0 && dy != 0) { dx *= 0.707; dy *= 0.707; }
	x = clamp(x + dx * spd, 24, room_width  - 24);
	y = clamp(y + dy * spd, 24, room_height - 24);
	walk_t = (walk_t + 1) mod 30;
}

// Smooth lerp camera follow, clamped to room
var cam     = view_camera[0];
var vw      = camera_get_view_width(cam);
var vh      = camera_get_view_height(cam);
var tcx     = x - vw * 0.5;
var tcy     = y - vh * 0.5;
var ncx     = lerp(camera_get_view_x(cam), tcx, 0.12);
var ncy     = lerp(camera_get_view_y(cam), tcy, 0.12);
camera_set_view_pos(cam, clamp(ncx, 0, room_width - vw), clamp(ncy, 0, room_height - vh));

// F5 = manual save
if (keyboard_check_pressed(vk_f5)) {
	scr_save_game();
}
