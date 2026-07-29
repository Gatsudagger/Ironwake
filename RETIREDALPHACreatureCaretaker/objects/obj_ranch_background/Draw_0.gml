var _cam_x = camera_get_view_x(view_camera[0]);
var _cam_y = camera_get_view_y(view_camera[0]);
var _vw    = camera_get_view_width(view_camera[0]);
var _vh    = camera_get_view_height(view_camera[0]);
scr_draw_ranch_sky(obj_game_controller.biome_id, _cam_x, _cam_y, _vw, _vh);
