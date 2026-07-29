var gc = obj_game_controller;
var _c = is_struct(gc.starter_creature) ? gc.starter_creature : undefined;

// ── Proximity to creature ─────────────────────────────────────────────────────
near_creature = false;
if (instance_exists(obj_creature) && instance_exists(obj_player)) {
	near_creature = (point_distance(obj_player.x, obj_player.y,
	                                obj_creature.x, obj_creature.y) < interact_dist);
}

// ── Feedback timer ────────────────────────────────────────────────────────────
if (feedback_timer > 0) feedback_timer--;

// ── Detect task completion (scr_task_update sets task_complete each Step) ─────
if (_c != undefined && _c.task_complete) {
	feedback_msg   = "Task Complete!";
	feedback_timer = 180;
	_c.task_complete = false;
}

// ── Menu toggles ──────────────────────────────────────────────────────────────
if (near_creature && !show_tasks && !show_stats && keyboard_check_pressed(ord("E"))) {
	show_tasks    = true;
	selected_task = 0;
}

if (keyboard_check_pressed(vk_tab)) {
	show_stats = !show_stats;
	show_tasks = false;
}

if (show_stats && keyboard_check_pressed(vk_enter)) {
	show_stats = false;
	room_goto(rm_creature_detail);
}

if (keyboard_check_pressed(vk_escape)) {
	show_tasks = false;
	show_stats = false;
}

// ── Task menu input ───────────────────────────────────────────────────────────
if (show_tasks) {
	if (keyboard_check_pressed(ord("W"))) {
		selected_task = (selected_task - 1 + TASK_TYPE.COUNT) mod TASK_TYPE.COUNT;
	}
	if (keyboard_check_pressed(ord("S"))) {
		selected_task = (selected_task + 1) mod TASK_TYPE.COUNT;
	}

	if (keyboard_check_pressed(vk_enter) && _c != undefined) {
		if (_c.active_task != -1) {
			feedback_msg   = "Already busy!";
			feedback_timer = 90;
		} else if (scr_task_start(_c, selected_task)) {
			show_tasks = false;
		} else {
			feedback_msg   = "Task unavailable.";
			feedback_timer = 90;
		}
	}
}
