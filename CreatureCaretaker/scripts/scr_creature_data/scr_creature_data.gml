// Creature IDs
enum SPECIES {
	HAREHOUND,
	AMPHIBI,
	BOULDEER,
	SALAPENT,
	RAPTOWL,
	THORNBACK,
	GLOWMOTH,
	COUNT
}

// Stat names match struct keys — use scr_creature_get_stat() with these strings
#macro STAT_STRENGTH   "strength"
#macro STAT_AGILITY    "agility"
#macro STAT_DEXTERITY  "dexterity"
#macro STAT_STAMINA    "stamina"
#macro STAT_INTELLECT  "intellect"
#macro STAT_WILLPOWER  "willpower"
#macro STAT_DEFENSE    "defense"
#macro STAT_HEALTH     "health"

// Walk sprite direction indices (used by obj_creature)
#macro WALK_DOWN  0
#macro WALK_UP    1
#macro WALK_LEFT  2
#macro WALK_RIGHT 3
#macro WALK_DL    4
#macro WALK_DR    5
#macro WALK_UL    6
#macro WALK_UR    7

/// @desc Populates global.creature_data with base stats for all creatures.
///       Call once at game start before accessing any creature data.
function scr_creature_data_init() {
	global.creature_data = array_create(SPECIES.COUNT);

	global.creature_data[SPECIES.HAREHOUND] = {
		name:      "Harehound",
		sprite:    spr_creature_harehound,
		walk_sprites: [
			spr_walk_harehound_down,   // 0 down
			spr_walk_harehound_up,     // 1 up
			spr_walk_harehound_left,   // 2 left
			spr_walk_harehound_right,  // 3 right
			spr_walk_harehound_left,   // 4 dl → left
			spr_walk_harehound_right,  // 5 dr → right
			spr_walk_harehound_left,   // 6 ul → left
			spr_walk_harehound_right,  // 7 ur → right
		],
		strength:  80,
		agility:   75,
		dexterity: 60,
		stamina:   80,
		intellect: 55,
		willpower: 78,
		defense:   30,
		health:    65,
		skills:    [0, 1, 2],
	};

	global.creature_data[SPECIES.AMPHIBI] = {
		name:      "Amphibi",
		sprite:    spr_creature_amphibi,
		walk_sprites: [
			spr_walk_amphibi_down,
			spr_walk_amphibi_up,
			spr_walk_amphibi_left,
			spr_walk_amphibi_right,
			spr_walk_amphibi_dl,
			spr_walk_amphibi_dr,
			spr_walk_amphibi_ul,
			spr_walk_amphibi_ur,
		],
		strength:  30,
		agility:   55,
		dexterity: 75,
		stamina:   55,
		intellect: 80,
		willpower: 35,
		defense:   30,
		health:    35,
		skills:    [3, 4, 5],
	};

	global.creature_data[SPECIES.BOULDEER] = {
		name:      "Bouldeer",
		sprite:    spr_creature_bouldeer,
		walk_sprites: [
			spr_walk_bouldeer_down,
			spr_walk_bouldeer_up,
			spr_walk_bouldeer_left,
			spr_walk_bouldeer_right,
			spr_walk_bouldeer_dl,
			spr_walk_bouldeer_dr,
			spr_walk_bouldeer_ul,
			spr_walk_bouldeer_ur,
		],
		strength:  85,
		agility:   50,
		dexterity: 55,
		stamina:   55,
		intellect: 55,
		willpower: 60,
		defense:   90,
		health:    60,
		skills:    [6, 7, 8],
	};

	global.creature_data[SPECIES.SALAPENT] = {
		name:      "Salapent",
		sprite:    spr_creature_salapent,
		walk_sprites: [
			spr_walk_salapent_down,
			spr_walk_salapent_up,
			spr_walk_salapent_left,
			spr_walk_salapent_right,
			spr_walk_salapent_dl,
			spr_walk_salapent_dr,
			spr_walk_salapent_ul,
			spr_walk_salapent_ur,
		],
		strength:  30,
		agility:   80,
		dexterity: 78,
		stamina:   58,
		intellect: 75,
		willpower: 55,
		defense:   30,
		health:    55,
		skills:    [9, 10, 11],
	};

	global.creature_data[SPECIES.RAPTOWL] = {
		name:      "Raptowl",
		sprite:    spr_creature_raptowl,
		walk_sprites: [
			spr_walk_raptowl_down,
			spr_walk_raptowl_up,
			spr_walk_raptowl_left,
			spr_walk_raptowl_right,
			spr_walk_raptowl_dl,
			spr_walk_raptowl_dr,
			spr_walk_raptowl_ul,
			spr_walk_raptowl_ur,
		],
		strength:  65,
		agility:   85,
		dexterity: 82,
		stamina:   50,
		intellect: 60,
		willpower: 65,
		defense:   25,
		health:    45,
		skills:    [12, 13, 14],
	};

	global.creature_data[SPECIES.THORNBACK] = {
		name:      "Thornback",
		sprite:    spr_portrait_thornback,
		walk_sprites: [
			spr_walk_thornback_down,   // 0 down
			spr_walk_thornback_up,     // 1 up
			spr_walk_thornback_left,   // 2 left
			spr_walk_thornback_right,  // 3 right
			spr_walk_thornback_down,   // 4 dl → down
			spr_walk_thornback_down,   // 5 dr → down
			spr_walk_thornback_right,  // 6 ul → right
			spr_walk_thornback_left,   // 7 ur → left
		],
		strength:  85,
		agility:   30,
		dexterity: 45,
		stamina:   70,
		intellect: 40,
		willpower: 65,
		defense:   90,
		health:    75,
		skills:    [0, 1, 2],
	};

	global.creature_data[SPECIES.GLOWMOTH] = {
		name:      "Glowmoth",
		sprite:    spr_portrait_glowmoth,
		walk_sprites: [
			spr_walk_glowmoth_down,   // 0 down
			spr_walk_glowmoth_up,     // 1 up
			spr_walk_glowmoth_left,   // 2 left
			spr_walk_glowmoth_right,  // 3 right
			spr_walk_glowmoth_left,   // 4 dl → left
			spr_walk_glowmoth_right,  // 5 dr → right
			spr_walk_glowmoth_left,   // 6 ul → left
			spr_walk_glowmoth_right,  // 7 ur → right
		],
		strength:  25,
		agility:   80,
		dexterity: 70,
		stamina:   50,
		intellect: 90,
		willpower: 72,
		defense:   22,
		health:    42,
		skills:    [0, 1, 2],
	};
}

/// @desc Returns the full base-stat struct for a species.
/// @param {real} species   A SPECIES enum value
/// @returns {Struct}
function scr_creature_get_data(species) {
	return global.creature_data[species];
}

/// @desc Returns a single base stat value for a species.
/// @param {real}   species   A SPECIES enum value
/// @param {string} stat      A STAT_* macro string (e.g. STAT_STRENGTH)
/// @returns {real}
function scr_creature_get_stat(species, stat) {
	return global.creature_data[species][$ stat];
}

/// @desc Returns the display name of a species.
/// @param {real} species   A SPECIES enum value
/// @returns {string}
function scr_creature_get_name(species) {
	return global.creature_data[species].name;
}

/// @desc Creates and returns a fully-populated creature instance struct.
///       Pulls base stats from global.creature_data; all bonus stats start at 0.
/// @param {real} species   A SPECIES enum value
/// @returns {Struct}
function scr_creature_create(species) {
	var _tmpl = global.creature_data[species];
	return {
		// Identity
		uid:              string(get_timer()) + string(species),
		species:          species,
		name:             "unnamed",
		generation:       1,
		age_days:         0,

		// Base stats — fixed at creation from species defaults
		base_strength:    _tmpl[$ STAT_STRENGTH],
		base_agility:     _tmpl[$ STAT_AGILITY],
		base_dexterity:   _tmpl[$ STAT_DEXTERITY],
		base_stamina:     _tmpl[$ STAT_STAMINA],
		base_intellect:   _tmpl[$ STAT_INTELLECT],
		base_willpower:   _tmpl[$ STAT_WILLPOWER],
		base_defense:     _tmpl[$ STAT_DEFENSE],
		base_health:      _tmpl[$ STAT_HEALTH],

		// Biome bonus stats — accumulated separately, start at 0
		bonus_strength:   0,
		bonus_agility:    0,
		bonus_dexterity:  0,
		bonus_stamina:    0,
		bonus_intellect:  0,
		bonus_willpower:  0,
		bonus_defense:    0,
		bonus_health:     0,

		// Current state
		current_stamina:  _tmpl[$ STAT_STAMINA],
		current_health:   _tmpl[$ STAT_HEALTH],
		biome:            -1,
		bond:             0,

		// Visual
		color_variant:    0,
		sprite_name:      "",

		// Lineage
		parent_a_uid:     "",
		parent_b_uid:     "",

		// Task state
		active_task:       -1,
		task_start_minute: 0,
		task_end_minute:   0,
		task_complete:     false,

		// Injury state (Section 13.7 — full implementation later)
		injury_type:        0,   // 0 = none
		injury_severity:    0,
		consecutive_faints: 0,
	};
}
