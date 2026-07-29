enum TASK_TYPE {
	TRAIN_STR,
	TRAIN_AGI,
	TRAIN_DEX,
	TRAIN_STA,
	TRAIN_INT,
	TRAIN_WIL,
	REST,
	FORAGE,
	COUNT,
}

/// @desc Populates global.task_data[] with definitions for all task types.
///       Call once at game start after scr_creature_data_init().
function scr_task_data_init() {
	global.task_data = array_create(TASK_TYPE.COUNT);

	global.task_data[TASK_TYPE.TRAIN_STR] = {
		name:             "Strength Training",
		description:      "Heavy lifting and resistance work to build raw power.",
		stamina_cost:     25,
		duration_minutes: 120,
		stat_rewarded:    STAT_STRENGTH,
		stat_gain:        2,
		phase_allowed:    ["Morning", "Midday"],
	};

	global.task_data[TASK_TYPE.TRAIN_AGI] = {
		name:             "Agility Drills",
		description:      "Speed circuits and evasion training to sharpen reaction time.",
		stamina_cost:     20,
		duration_minutes: 90,
		stat_rewarded:    STAT_AGILITY,
		stat_gain:        2,
		phase_allowed:    ["Morning", "Midday"],
	};

	global.task_data[TASK_TYPE.TRAIN_DEX] = {
		name:             "Precision Work",
		description:      "Fine-motor exercises and accuracy drills.",
		stamina_cost:     15,
		duration_minutes: 90,
		stat_rewarded:    STAT_DEXTERITY,
		stat_gain:        2,
		phase_allowed:    ["Morning", "Midday", "Evening"],
	};

	global.task_data[TASK_TYPE.TRAIN_STA] = {
		name:             "Endurance Run",
		description:      "A long-distance run at dawn to push stamina limits.",
		stamina_cost:     30,
		duration_minutes: 150,
		stat_rewarded:    STAT_STAMINA,
		stat_gain:        1,
		phase_allowed:    ["Morning"],
	};

	global.task_data[TASK_TYPE.TRAIN_INT] = {
		name:             "Study Session",
		description:      "Puzzle solving and pattern recognition to exercise the mind.",
		stamina_cost:     10,
		duration_minutes: 120,
		stat_rewarded:    STAT_INTELLECT,
		stat_gain:        2,
		phase_allowed:    ["any"],
	};

	global.task_data[TASK_TYPE.TRAIN_WIL] = {
		name:             "Meditation",
		description:      "Quiet focus in the evening calm to build mental fortitude.",
		stamina_cost:     5,
		duration_minutes: 60,
		stat_rewarded:    STAT_WILLPOWER,
		stat_gain:        2,
		phase_allowed:    ["Evening", "Night"],
	};

	global.task_data[TASK_TYPE.REST] = {
		name:             "Rest",
		description:      "Recover stamina with a period of undisturbed rest.",
		stamina_cost:     0,
		duration_minutes: 60,
		stat_rewarded:    "",
		stat_gain:        0,
		phase_allowed:    ["any"],
	};

	global.task_data[TASK_TYPE.FORAGE] = {
		name:             "Forage",
		description:      "Search the surrounding area for useful materials.",
		stamina_cost:     15,
		duration_minutes: 90,
		stat_rewarded:    "",
		stat_gain:        0,
		phase_allowed:    ["Morning", "Midday"],
	};
}

/// @desc Returns the task definition struct for a given TASK_TYPE.
/// @param {real} task_type   A TASK_TYPE enum value
/// @returns {Struct}
function scr_task_get_data(task_type) {
	return global.task_data[task_type];
}

/// @desc Returns true if the creature has enough stamina AND the current phase
///       allows this task type.
/// @param {Struct} creature_struct
/// @param {real}   task_type   A TASK_TYPE enum value
/// @returns {bool}
function scr_task_is_available(creature_struct, task_type) {
	var _td          = global.task_data[task_type];
	var _actual_cost = _td.stamina_cost * scr_time_stamina_cost_mult();
	if (creature_struct.current_stamina < _actual_cost) return false;
	return _phase_is_allowed(_td.phase_allowed);
}

/// @desc Attempts to start a task for a creature.
///       Validates stamina and current phase. Deducts stamina and records task
///       start/end minutes on success.
/// @param {Struct} creature_struct
/// @param {real}   task_type   A TASK_TYPE enum value
/// @returns {bool}  true on success, false on failure
function scr_task_start(creature_struct, task_type) {
	var _td          = global.task_data[task_type];
	var _actual_cost = _td.stamina_cost * scr_time_stamina_cost_mult();

	if (creature_struct.current_stamina < _actual_cost) {
		show_debug_message("scr_task_start: not enough stamina ("
			+ string(creature_struct.current_stamina) + " / " + string(_actual_cost)
			+ " needed) for task: " + _td.name);
		return false;
	}

	if (!_phase_is_allowed(_td.phase_allowed)) {
		show_debug_message("scr_task_start: phase '" + scr_time_get_phase_name()
			+ "' not allowed for task: " + _td.name
			+ " (allowed: " + _phase_array_to_string(_td.phase_allowed) + ")");
		return false;
	}

	creature_struct.active_task        = task_type;
	creature_struct.task_start_minute  = global.minutes_in_day;
	creature_struct.task_end_minute    = global.minutes_in_day + _td.duration_minutes;
	creature_struct.current_stamina   -= _actual_cost;
	creature_struct.task_complete      = false;
	return true;
}

/// @desc Call every Step (from obj_game_controller) to check whether any active
///       task has completed and apply its reward.
/// @param {Struct} creature_struct
function scr_task_update(creature_struct) {
	if (creature_struct.active_task == -1) return;

	var _end = creature_struct.task_end_minute;
	var _now = global.minutes_in_day;

	if (_end >= TIME_MINS_PER_GAME_DAY) {
		// Task spans midnight. Complete only after minutes_in_day has wrapped past
		// the start time AND caught up to the adjusted end (end - 1440).
		// Works because max task duration (150 min) can never wrap more than once.
		var _wrapped = _end - TIME_MINS_PER_GAME_DAY;
		if (_now >= creature_struct.task_start_minute || _now < _wrapped) return;
	} else {
		if (_now < _end) return;
	}

	var _type = creature_struct.active_task;
	var _td   = global.task_data[_type];

	if (_td.stat_rewarded != "") {
		creature_struct[$ "base_" + _td.stat_rewarded] += _td.stat_gain;
		clamp_base_stats(creature_struct);
	}

	if (_type == TASK_TYPE.REST) {
		creature_struct.current_stamina = min(
			creature_struct.current_stamina + 20,
			creature_struct.base_stamina
		);
	}

	show_debug_message("Task complete: " + _td.name + " | INT now: " + string(creature_struct.base_intellect));

	creature_struct.active_task   = -1;
	creature_struct.task_complete = true;
}

// ── Internal helpers ──────────────────────────────────────────────────────────

/// @desc Returns true if the current phase name matches the allowed array.
///       Passes for ["any"] regardless of current phase.
function _phase_is_allowed(phase_allowed) {
	if (phase_allowed[0] == "any") return true;
	var _current = scr_time_get_phase_name();
	var _i = 0;
	repeat (array_length(phase_allowed)) {
		if (phase_allowed[_i] == _current) return true;
		_i++;
	}
	return false;
}

/// @desc Returns the phase_allowed array as a comma-separated string for debug output.
function _phase_array_to_string(phase_allowed) {
	var _s = "";
	var _i = 0;
	repeat (array_length(phase_allowed)) {
		if (_i > 0) _s += ", ";
		_s += phase_allowed[_i];
		_i++;
	}
	return _s;
}
