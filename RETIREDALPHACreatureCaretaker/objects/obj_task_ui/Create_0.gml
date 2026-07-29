depth = -10000;

show_tasks    = false;
show_stats    = false;
selected_task = 0;

// Build task reference list from global task data
task_list = array_create(TASK_TYPE.COUNT);
for (var _i = 0; _i < TASK_TYPE.COUNT; _i++) {
	task_list[_i] = scr_task_get_data(_i);
}

// Panel layout — menu_x/menu_y are recalculated each Draw from the camera
menu_w = 440;
menu_h = 400;
menu_x = 0;
menu_y = 0;

interact_dist = 150;
near_creature = false;
feedback_msg  = "";
feedback_timer = 0;
