home_x = x;
home_y = y;
target_x = x;
target_y = y;
wander_timer = 0;
move_spd  = 0.5;
idle_bob_t = 0;
depth = -round(y);

var _c = obj_game_controller.starter_creature;
if (!is_struct(_c)) {
    sprite_index = spr_placeholder;
    image_speed  = 0;
    image_index  = 0;
    exit;
}
sprite_index = global.creature_data[_c.species].walk_sprites[WALK_DOWN];
image_speed  = 0;
image_index  = 0;
