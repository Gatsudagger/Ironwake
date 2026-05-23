// ─── Time phases ──────────────────────────────────────────────────────────────
enum TIME_PHASE {
	NIGHT,    // 12:00 AM – 6:00 AM  (minutes   0 – 359)
	MORNING,  //  6:00 AM – 12:00 PM (minutes 360 – 719)
	MIDDAY,   // 12:00 PM –  6:00 PM (minutes 720 – 1079)
	EVENING,  //  6:00 PM – 12:00 AM (minutes 1080 – 1439)
}

// Time scale:
//   1 real second = 6 in-game seconds
//   1 in-game minute = 10 real seconds
//   1 in-game day (1 440 min) = 14 400 real seconds = 4 real hours
#macro TIME_REAL_SECS_PER_GAME_MIN  10.0
#macro TIME_MINS_PER_GAME_DAY       1440

/// @desc Reset the time system to Day 1, 6:00 AM (Morning).
///       Call once after the player finishes all setup screens.
function scr_time_init() {
	global.day_number         = 1;
	global.minutes_in_day     = 360.0;    // 6:00 AM
	global.time_phase         = TIME_PHASE.MORNING;
	global.night_regen_done   = false;
	global.day_just_advanced  = false;
	global.phase_just_changed = false;
}

/// @desc Advance in-game time by the elapsed real time since the last step.
///       Call once per Step from obj_game_controller (persistent object).
function scr_time_update() {
	global.day_just_advanced  = false;
	global.phase_just_changed = false;

	// delta_time is microseconds; convert to in-game minutes
	global.minutes_in_day += delta_time / (TIME_REAL_SECS_PER_GAME_MIN * 1000000.0);

	if (global.minutes_in_day >= TIME_MINS_PER_GAME_DAY) {
		global.minutes_in_day   -= TIME_MINS_PER_GAME_DAY;
		global.day_number++;
		global.day_just_advanced = true;
		global.night_regen_done  = false;
	}

	var new_phase = scr_time_get_phase();
	if (new_phase != global.time_phase) {
		global.time_phase         = new_phase;
		global.phase_just_changed = true;
	}
}

/// @desc Returns the TIME_PHASE enum value for the current in-game time.
function scr_time_get_phase() {
	var m = global.minutes_in_day;
	if (m < 360)  return TIME_PHASE.NIGHT;
	if (m < 720)  return TIME_PHASE.MORNING;
	if (m < 1080) return TIME_PHASE.MIDDAY;
	return TIME_PHASE.EVENING;
}

/// @desc Returns the display name of the current time phase.
function scr_time_get_phase_name() {
	switch (global.time_phase) {
		case TIME_PHASE.NIGHT:   return "Night";
		case TIME_PHASE.MORNING: return "Morning";
		case TIME_PHASE.MIDDAY:  return "Midday";
		case TIME_PHASE.EVENING: return "Evening";
	}
	return "";
}

/// @desc Returns the current in-game hour (0–23).
function scr_time_get_hour() {
	return floor(global.minutes_in_day / 60);
}

/// @desc Returns the current in-game minute within the hour (0–59).
function scr_time_get_minute() {
	return floor(global.minutes_in_day mod 60);
}

/// @desc Returns the current time as a 12-hour string, e.g. "6:05 AM".
function scr_time_to_string() {
	var h  = scr_time_get_hour();
	var m  = scr_time_get_minute();
	var ap = (h >= 12) ? "PM" : "AM";
	var h12 = h mod 12;
	if (h12 == 0) h12 = 12;
	var ms = (m < 10) ? ("0" + string(m)) : string(m);
	return string(h12) + ":" + ms + " " + ap;
}

/// @desc Returns true if creature_id can be encountered in the wild right now.
///
///   Harehound — Morning only   (6 AM–12 PM)
///   Amphibi   — Midday only    (12 PM–6 PM)
///   Salapent  — Evening only   (6 PM–12 AM)
///   Raptowl   — Night only     (12 AM–6 AM)
///   Bouldeer  — Dawn & Dusk    (5:30–6:30 AM  and  5:30–6:30 PM)
function scr_time_creature_encounters(creature_id) {
	var m = global.minutes_in_day;
	switch (creature_id) {
		case CREATURE.HAREHOUND: return (m >= 360  && m < 720);
		case CREATURE.AMPHIBI:   return (m >= 720  && m < 1080);
		case CREATURE.SALAPENT:  return (m >= 1080 && m < 1440);
		case CREATURE.RAPTOWL:   return (m < 360);
		case CREATURE.BOULDEER:
			// Dawn  5:30–6:30 AM  = minutes 330–390
			// Dusk  5:30–6:30 PM  = minutes 1050–1110
			return ((m >= 330 && m < 390) || (m >= 1050 && m < 1110));
	}
	return false;
}

/// @desc Returns the stamina cost multiplier for tasks.
///       Night phase doubles all stamina costs (returns 2); all other phases return 1.
function scr_time_stamina_cost_mult() {
	return (global.time_phase == TIME_PHASE.NIGHT) ? 2 : 1;
}

/// @desc Call each Step (or on task completion) to trigger full stamina regen
///       at the start of Night. Returns true exactly once per Night phase.
function scr_time_check_night_regen() {
	if (global.time_phase == TIME_PHASE.NIGHT && !global.night_regen_done) {
		global.night_regen_done = true;
		return true;
	}
	return false;
}
