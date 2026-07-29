// Skill type constants
#macro SKILL_TYPE_PHYSICAL  0
#macro SKILL_TYPE_ELEMENTAL 1
#macro SKILL_TYPE_BUFF      2
#macro SKILL_TYPE_DEBUFF    3

/// @desc Populates global.skill_data with all creature skill definitions.
///       Call once after scr_creature_data_init().
function scr_creature_skills_init() {
	global.skill_data = array_create(15);

	// --- Harehound (indices 0-2) ---
	global.skill_data[0] = {
		name:        "Tackle",
		description: "A fierce full-body charge that knocks the target back.",
		type:        SKILL_TYPE_PHYSICAL,
		stamina_cost: 15,
		cooldown:    120,   // frames (2 sec at 60fps)
		power:       1.2,   // multiplier on strength
		icon_index:  0,
	};
	global.skill_data[1] = {
		name:        "Pack Howl",
		description: "A rallying cry that briefly boosts willpower.",
		type:        SKILL_TYPE_BUFF,
		stamina_cost: 20,
		cooldown:    300,
		power:       1.0,
		icon_index:  1,
	};
	global.skill_data[2] = {
		name:        "Feral Dash",
		description: "A blinding burst of speed — strikes twice in quick succession.",
		type:        SKILL_TYPE_PHYSICAL,
		stamina_cost: 25,
		cooldown:    180,
		power:       0.8,   // hits twice
		icon_index:  2,
	};

	// --- Amphibi (indices 3-5) ---
	global.skill_data[3] = {
		name:        "Acid Spit",
		description: "Launches a glob of corrosive acid that weakens defense.",
		type:        SKILL_TYPE_ELEMENTAL,
		stamina_cost: 20,
		cooldown:    150,
		power:       1.0,
		icon_index:  16,
	};
	global.skill_data[4] = {
		name:        "Camouflage",
		description: "Blends into the surroundings, increasing evasion.",
		type:        SKILL_TYPE_BUFF,
		stamina_cost: 15,
		cooldown:    360,
		power:       1.0,
		icon_index:  17,
	};
	global.skill_data[5] = {
		name:        "Leap Strike",
		description: "Springs forward and crashes down with full body weight.",
		type:        SKILL_TYPE_PHYSICAL,
		stamina_cost: 22,
		cooldown:    160,
		power:       1.4,
		icon_index:  18,
	};

	// --- Bouldeer (indices 6-8) ---
	global.skill_data[6] = {
		name:        "Stone Charge",
		description: "Lowers head and barrels forward like a rolling boulder.",
		type:        SKILL_TYPE_PHYSICAL,
		stamina_cost: 20,
		cooldown:    150,
		power:       1.5,
		icon_index:  32,
	};
	global.skill_data[7] = {
		name:        "Iron Hide",
		description: "Toughens the hide, greatly increasing defense.",
		type:        SKILL_TYPE_BUFF,
		stamina_cost: 18,
		cooldown:    300,
		power:       1.0,
		icon_index:  33,
	};
	global.skill_data[8] = {
		name:        "Tremor",
		description: "Stamps the ground, sending a shockwave that stuns nearby foes.",
		type:        SKILL_TYPE_ELEMENTAL,
		stamina_cost: 30,
		cooldown:    240,
		power:       1.1,
		icon_index:  34,
	};

	// --- Salapent (indices 9-11) ---
	global.skill_data[9] = {
		name:        "Venom Bite",
		description: "Injects venom that deals damage over time.",
		type:        SKILL_TYPE_DEBUFF,
		stamina_cost: 18,
		cooldown:    120,
		power:       0.6,   // per tick
		icon_index:  48,
	};
	global.skill_data[10] = {
		name:        "Slither",
		description: "Weaves with liquid grace, briefly becoming impossible to hit.",
		type:        SKILL_TYPE_BUFF,
		stamina_cost: 12,
		cooldown:    200,
		power:       1.0,
		icon_index:  49,
	};
	global.skill_data[11] = {
		name:        "Tail Whip",
		description: "A sweeping tail strike that hits all enemies in front.",
		type:        SKILL_TYPE_PHYSICAL,
		stamina_cost: 20,
		cooldown:    130,
		power:       1.1,
		icon_index:  50,
	};

	// --- Raptowl (indices 12-14) ---
	global.skill_data[12] = {
		name:        "Talon Strike",
		description: "Razor-sharp talons slash with precision and speed.",
		type:        SKILL_TYPE_PHYSICAL,
		stamina_cost: 16,
		cooldown:    90,
		power:       1.3,
		icon_index:  64,
	};
	global.skill_data[13] = {
		name:        "Wind Gust",
		description: "Beats powerful wings to push enemies back with a blast of air.",
		type:        SKILL_TYPE_ELEMENTAL,
		stamina_cost: 22,
		cooldown:    180,
		power:       0.9,
		icon_index:  65,
	};
	global.skill_data[14] = {
		name:        "Night Vision",
		description: "Heightens senses in darkness, increasing dexterity.",
		type:        SKILL_TYPE_BUFF,
		stamina_cost: 10,
		cooldown:    400,
		power:       1.0,
		icon_index:  66,
	};
}

/// @desc Returns the base power of a skill scaled by the relevant creature stat.
/// @param {real} creature_id   A CREATURE enum value
/// @param {real} skill_index   Index into global.skill_data
/// @returns {real}
function scr_skill_get_power(creature_id, skill_index) {
	var skill   = global.skill_data[skill_index];
	var cdata   = global.creature_data[creature_id];
	var stat    = 0;
	switch (skill.type) {
		case SKILL_TYPE_PHYSICAL:   stat = cdata.strength;  break;
		case SKILL_TYPE_ELEMENTAL:  stat = cdata.intellect; break;
		case SKILL_TYPE_BUFF:       stat = cdata.willpower; break;
		case SKILL_TYPE_DEBUFF:     stat = cdata.dexterity; break;
	}
	return skill.power * (stat / 50);
}
