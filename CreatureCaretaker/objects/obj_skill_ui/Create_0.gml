skill_cooldowns = array_create(3, 0);

slot_size  = 48;
slot_gap   = 8;
total_w    = 3 * slot_size + 2 * slot_gap;
icon_scale = slot_size / 32;  // spr_skill_icons frames are 32x32
fps_cache  = game_get_speed(gamespeed_fps);
key_codes  = [ord("1"), ord("2"), ord("3")];
