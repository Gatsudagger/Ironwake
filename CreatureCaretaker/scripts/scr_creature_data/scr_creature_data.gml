// Creature IDs
enum CREATURE {
	HAREHOUND,
	AMPHIBI,
	BOULDEER,
	SALAPENT,
	RAPTOWL,
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
	global.creature_data = array_create(CREATURE.COUNT);

	global.creature_data[CREATURE.HAREHOUND] = {
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

	global.creature_data[CREATURE.AMPHIBI] = {
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

	global.creature_data[CREATURE.BOULDEER] = {
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

	global.creature_data[CREATURE.SALAPENT] = {
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

	global.creature_data[CREATURE.RAPTOWL] = {
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
		strength:  55,
		agility:   82,
		dexterity: 85,
		stamina:   35,
		intellect: 80,
		willpower: 58,
		defense:   30,
		health:    35,
		skills:    [12, 13, 14],
	};
}

/// @desc Returns the full base-stat struct for a creature.
/// @param {real} creature_id   A CREATURE enum value
/// @returns {Struct}
function scr_creature_get_data(creature_id) {
	return global.creature_data[creature_id];
}

/// @desc Returns a single base stat value for a creature.
/// @param {real}   creature_id   A CREATURE enum value
/// @param {string} stat          A STAT_* macro string (e.g. STAT_STRENGTH)
/// @returns {real}
function scr_creature_get_stat(creature_id, stat) {
	return global.creature_data[creature_id][$ stat];
}

/// @desc Returns the display name of a creature.
/// @param {real} creature_id   A CREATURE enum value
/// @returns {string}
function scr_creature_get_name(creature_id) {
	return global.creature_data[creature_id].name;
}
