home_x = x;
home_y = y;
target_x = x;
target_y = y;
wander_timer = 0;
move_spd  = 0.5;
idle_bob_t = 0;
depth = -round(y);

var _ci = obj_game_controller.starter_creature;
if (_ci >= 0) {
    sprite_index = global.creature_data[_ci].walk_sprites[WALK_DOWN];
}
image_speed = 0;
image_index = 0;
