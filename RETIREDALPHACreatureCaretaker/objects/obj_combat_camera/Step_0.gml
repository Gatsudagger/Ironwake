if (global.shake_duration > 0) {
	global.shake_duration--;
	var _ox = random_range(-global.shake_intensity, global.shake_intensity);
	var _oy = random_range(-global.shake_intensity, global.shake_intensity);
	camera_set_view_pos(cam, base_x + _ox, base_y + _oy);
} else {
	camera_set_view_pos(cam, base_x, base_y);
	global.shake_intensity = 0;
}
