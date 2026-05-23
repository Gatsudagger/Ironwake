// ─── Biome IDs ────────────────────────────────────────────────────────────────
enum BIOME {
	ALPINE_FOREST,
	TEMPERATE_FOREST,
	JUNGLE,
	OASIS,
	MOUNTAIN_VALLEY,
	COUNT
}

/// @desc Populate global.biome_data with rules for all five biomes.
///       Call once at game start (obj_game_controller Create event).
function scr_biome_data_init() {
	global.biome_data = array_create(BIOME.COUNT);

	// ── Alpine Forest ─────────────────────────────────────────────────────────
	// DEF + WIL  |  +1 per task-day  |  cap +15 per stat
	global.biome_data[BIOME.ALPINE_FOREST] = {
		name:         "Alpine Forest",
		icon:         "AF",
		desc:         ["Dense evergreen canopy", "and crisp mountain air", "harden body and mind."],
		stats:        [STAT_DEFENSE, STAT_WILLPOWER],
		rate_days:    1,
		cap_per_stat: 15,
		total_cap:    -1,    // -1 = no total cap
		accent:       make_colour_rgb(100, 162, 130),
	};

	// ── Temperate Forest ──────────────────────────────────────────────────────
	// All stats except Health  |  +1 per 3 task-days  |  cap +4 per stat, max +28 total
	global.biome_data[BIOME.TEMPERATE_FOREST] = {
		name:         "Temperate Forest",
		icon:         "TF",
		desc:         ["A balanced woodland that", "nurtures well-rounded", "growth in all areas."],
		stats:        [STAT_STRENGTH, STAT_AGILITY, STAT_DEXTERITY,
		               STAT_STAMINA, STAT_INTELLECT, STAT_WILLPOWER, STAT_DEFENSE],
		rate_days:    3,
		cap_per_stat: 4,
		total_cap:    28,
		accent:       make_colour_rgb(68, 148, 68),
	};

	// ── Jungle ────────────────────────────────────────────────────────────────
	// AGI + DEX  |  +1 per task-day  |  cap +15 per stat
	global.biome_data[BIOME.JUNGLE] = {
		name:         "Jungle",
		icon:         "JU",
		desc:         ["Tangled vines and dense", "canopy hone lightning", "speed and reflexes."],
		stats:        [STAT_AGILITY, STAT_DEXTERITY],
		rate_days:    1,
		cap_per_stat: 15,
		total_cap:    -1,
		accent:       make_colour_rgb(40, 178, 82),
	};

	// ── Oasis ─────────────────────────────────────────────────────────────────
	// STA + WIL  |  +1 per task-day  |  cap +15 per stat
	global.biome_data[BIOME.OASIS] = {
		name:         "Oasis",
		icon:         "OA",
		desc:         ["Life-giving waters and", "sheltered sands build", "endurance and resolve."],
		stats:        [STAT_STAMINA, STAT_WILLPOWER],
		rate_days:    1,
		cap_per_stat: 15,
		total_cap:    -1,
		accent:       make_colour_rgb(58, 188, 208),
	};

	// ── Mountain Valley ───────────────────────────────────────────────────────
	// STR + DEF  |  +1 per task-day  |  cap +15 per stat
	global.biome_data[BIOME.MOUNTAIN_VALLEY] = {
		name:         "Mountain Valley",
		icon:         "MV",
		desc:         ["Rugged peaks and thin", "air forge raw strength", "and iron-hard defense."],
		stats:        [STAT_STRENGTH, STAT_DEFENSE],
		rate_days:    1,
		cap_per_stat: 15,
		total_cap:    -1,
		accent:       make_colour_rgb(148, 118, 88),
	};
}

/// @desc Returns the display name of a biome.
function scr_biome_get_name(biome_id) {
	return global.biome_data[biome_id].name;
}

/// @desc Returns the full biome data struct.
function scr_biome_get_data(biome_id) {
	return global.biome_data[biome_id];
}

/// @desc Create a fresh bonus-tracking struct for a creature in a given biome.
///       Store the result in obj_game_controller.biome_bonus_state.
/// @param {real}   creature_id   CREATURE enum value
/// @param {real}   biome_id      BIOME enum value
/// @returns {Struct}
function scr_biome_bonus_init(creature_id, biome_id) {
	var biome   = global.biome_data[biome_id];
	var bonuses = {};
	var stats   = biome.stats;
	for (var i = 0; i < array_length(stats); i++) {
		bonuses[$ stats[i]] = 0;
	}
	return {
		creature_id:    creature_id,
		biome_id:       biome_id,
		bonuses:        bonuses,
		total_bonus:    0,
		last_bonus_day: 0,   // last global.day_number on which growth was processed
		task_day_count: 0,   // number of task-completion days recorded
	};
}

/// @desc Call after a creature completes any task.
///       Applies +1 to each boosted stat at most once per in-game day,
///       respecting the biome's rate, per-stat cap, and total cap.
/// @param {Struct} bonus_state   The struct from scr_biome_bonus_init
/// @returns {bool}  true if any stat increased
function scr_biome_growth_apply(bonus_state) {
	// One growth event per in-game day maximum
	if (bonus_state.last_bonus_day == global.day_number) return false;

	bonus_state.last_bonus_day = global.day_number;
	bonus_state.task_day_count++;

	var biome = global.biome_data[bonus_state.biome_id];

	// Rate gate: Temperate Forest only grows every 3 task-days
	if ((bonus_state.task_day_count mod biome.rate_days) != 0) return false;

	var grew  = false;
	var stats = biome.stats;
	for (var i = 0; i < array_length(stats); i++) {
		var skey = stats[i];
		var cur  = bonus_state.bonuses[$ skey];

		if (cur >= biome.cap_per_stat) continue;
		if (biome.total_cap > 0 && bonus_state.total_bonus >= biome.total_cap) continue;

		bonus_state.bonuses[$ skey]++;
		bonus_state.total_bonus++;
		grew = true;
	}
	return grew;
}

/// @desc Returns base + biome bonus for one stat.
///       Pass undefined for bonus_state to get the raw base value only.
/// @param {real}   creature_id
/// @param {string} stat          A STAT_* macro string
/// @param {Struct} bonus_state   From scr_biome_bonus_init, or undefined
/// @returns {real}
function scr_biome_get_effective_stat(creature_id, stat, bonus_state) {
	var base  = scr_creature_get_stat(creature_id, stat);
	if (is_undefined(bonus_state)) return base;
	var bonus = bonus_state.bonuses[$ stat];
	return base + (is_undefined(bonus) ? 0 : bonus);
}

/// @desc Returns a compact string listing all active bonuses, e.g. "DEF +3  WIL +2".
///       Returns "No bonuses yet" if nothing has been earned.
function scr_biome_get_bonus_summary(bonus_state) {
	var biome = global.biome_data[bonus_state.biome_id];
	var stats = biome.stats;
	var out   = "";
	for (var i = 0; i < array_length(stats); i++) {
		var skey = stats[i];
		var val  = bonus_state.bonuses[$ skey];
		if (!is_undefined(val) && val > 0) {
			out += string_copy(string_upper(skey), 1, 3) + " +" + string(val) + "  ";
		}
	}
	return (out == "") ? "No bonuses yet" : string_trim(out);
}
