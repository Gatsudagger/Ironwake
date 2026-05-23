near_player = instance_exists(obj_player) &&
    (point_distance(x, y, obj_player.x, obj_player.y) < interact_dist);

if (instance_exists(obj_task_ui)) {
    var ui = obj_task_ui;
    if (ui.show_tasks || ui.show_stats || ui.show_pause) exit;
}

if (near_player && keyboard_check_pressed(ord("E"))) {
    // Rest at the inn — advance 8 hours, restore 35% creature stamina
    global.minutes_in_day += 480;
    while (global.minutes_in_day >= TIME_MINS_PER_GAME_DAY) {
        global.minutes_in_day -= TIME_MINS_PER_GAME_DAY;
        global.day_number++;
        global.night_regen_done  = false;
        global.day_just_advanced = true;
    }
    global.time_phase = scr_time_get_phase();

    var gc = obj_game_controller;
    gc.creature_stamina = min(gc.creature_stamina_max,
        gc.creature_stamina + round(gc.creature_stamina_max * 0.35));

    if (instance_exists(obj_task_ui)) {
        obj_task_ui.feedback_msg   = "You rested at The Sleeping Fox. Your creature feels refreshed.";
        obj_task_ui.feedback_timer = 210;
    }
}
