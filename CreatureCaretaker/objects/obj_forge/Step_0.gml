near_player = instance_exists(obj_player) &&
    (point_distance(x, y, obj_player.x, obj_player.y) < interact_dist);

if (instance_exists(obj_task_ui)) {
    var ui = obj_task_ui;
    if (ui.show_tasks || ui.show_stats || ui.show_pause) exit;
}

if (near_player && keyboard_check_pressed(ord("E"))) {
    if (instance_exists(obj_task_ui)) {
        obj_task_ui.feedback_msg   = "Griff: \"Not open for business yet. Come back when you're stronger.\"";
        obj_task_ui.feedback_timer = 240;
    }
}
