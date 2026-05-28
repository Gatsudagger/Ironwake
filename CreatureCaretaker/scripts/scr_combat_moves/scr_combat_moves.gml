// ── Enums ──────────────────────────────────────────────────────────────────────

enum MOVE_TYPE {
	MELEE,
	PROJECTILE,
	BUFF,
	DEBUFF,
	COUNT,
}

enum STATUS {
	NONE,
	KNOCKBACK,
	SLOW,
	STUN,
	POISON,
	COUNT,
}

// ── Init ───────────────────────────────────────────────────────────────────────

/// @desc Populates global.combat_moves[SPECIES.*] with 3-move arrays.
///       Also initialises the global.combat_state template struct.
///       Call once at game start after scr_creature_data_init().
///
///       Cooldown / duration fields are stored in STEPS (seconds × 60).
///       base_damage: flat damage before stat contribution.
///       stat_mod:    fraction of scr_effective_stat(stat_key) added to damage.
function scr_combat_moves_init() {

	global.combat_moves = array_create(SPECIES.COUNT);

	// ── HAREHOUND ──────────────────────────────────────────────────────────────
	global.combat_moves[SPECIES.HAREHOUND] = [
		// Lunge — short forward burst, knockback
		{
			name:                 "Lunge",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_STRENGTH,
			base_damage:          15,
			stat_mod:             0.20,
			cooldown_secs:        90,
			status_effect:        STATUS.KNOCKBACK,
			status_duration_secs: 18,
			governing_stat:       "",
			base_effect:          0,
			range_px:             80,
			dash_speed:           8,
		},
		// Jaw Snap — very short range, no effect
		{
			name:                 "Jaw Snap",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_STRENGTH,
			base_damage:          10,
			stat_mod:             0.15,
			cooldown_secs:        48,
			status_effect:        STATUS.NONE,
			status_duration_secs: 0,
			governing_stat:       "",
			base_effect:          0,
			range_px:             40,
			dash_speed:           0,
		},
		// Howl — self buff, +20% STR base for 5s base, WIL governed
		{
			name:                 "Howl",
			type:                 MOVE_TYPE.BUFF,
			stat_key:             "",
			base_damage:          0,
			stat_mod:             0,
			cooldown_secs:        480,
			status_effect:        STATUS.NONE,
			status_duration_secs: 300,
			governing_stat:       STAT_WILLPOWER,
			base_effect:          0.20,
			range_px:             0,
			dash_speed:           0,
		},
	];

	// ── AMPHIBI ────────────────────────────────────────────────────────────────
	global.combat_moves[SPECIES.AMPHIBI] = [
		// Shock Bolt — long-range projectile, slows 1s base
		{
			name:                 "Shock Bolt",
			type:                 MOVE_TYPE.PROJECTILE,
			stat_key:             STAT_INTELLECT,
			base_damage:          12,
			stat_mod:             0.22,
			cooldown_secs:        72,
			status_effect:        STATUS.SLOW,
			status_duration_secs: 60,
			governing_stat:       STAT_INTELLECT,
			base_effect:          0,
			range_px:             300,
			dash_speed:           0,
		},
		// Static Field — small radius melee, stuns 0.5s base
		{
			name:                 "Static Field",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_INTELLECT,
			base_damage:          8,
			stat_mod:             0.18,
			cooldown_secs:        120,
			status_effect:        STATUS.STUN,
			status_duration_secs: 30,
			governing_stat:       STAT_INTELLECT,
			base_effect:          0,
			range_px:             60,
			dash_speed:           0,
		},
		// Overcharge — self buff, next hit 2x damage
		{
			name:                 "Overcharge",
			type:                 MOVE_TYPE.BUFF,
			stat_key:             "",
			base_damage:          0,
			stat_mod:             0,
			cooldown_secs:        600,
			status_effect:        STATUS.NONE,
			status_duration_secs: 0,
			governing_stat:       STAT_WILLPOWER,
			base_effect:          2.0,
			range_px:             0,
			dash_speed:           0,
		},
	];

	// ── BOULDEER ───────────────────────────────────────────────────────────────
	global.combat_moves[SPECIES.BOULDEER] = [
		// Bone Charge — medium dash, high damage, slow startup, knockback
		{
			name:                 "Bone Charge",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_STRENGTH,
			base_damage:          20,
			stat_mod:             0.25,
			cooldown_secs:        180,
			status_effect:        STATUS.KNOCKBACK,
			status_duration_secs: 18,
			governing_stat:       "",
			base_effect:          0,
			range_px:             120,
			dash_speed:           6,
		},
		// Headbutt — very short, knockback
		{
			name:                 "Headbutt",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_STRENGTH,
			base_damage:          14,
			stat_mod:             0.20,
			cooldown_secs:        90,
			status_effect:        STATUS.KNOCKBACK,
			status_duration_secs: 12,
			governing_stat:       "",
			base_effect:          0,
			range_px:             40,
			dash_speed:           0,
		},
		// Iron Shell — self buff, DEF x2 base for 4s base
		{
			name:                 "Iron Shell",
			type:                 MOVE_TYPE.BUFF,
			stat_key:             "",
			base_damage:          0,
			stat_mod:             0,
			cooldown_secs:        720,
			status_effect:        STATUS.NONE,
			status_duration_secs: 240,
			governing_stat:       STAT_WILLPOWER,
			base_effect:          2.0,
			range_px:             0,
			dash_speed:           0,
		},
	];

	// ── SALAPENT ───────────────────────────────────────────────────────────────
	global.combat_moves[SPECIES.SALAPENT] = [
		// Venom Spit — medium-range projectile, poison DoT
		{
			name:                 "Venom Spit",
			type:                 MOVE_TYPE.PROJECTILE,
			stat_key:             STAT_DEXTERITY,
			base_damage:          8,
			stat_mod:             0.18,
			cooldown_secs:        60,
			status_effect:        STATUS.POISON,
			status_duration_secs: 180,
			governing_stat:       STAT_INTELLECT,
			base_effect:          0,
			range_px:             200,
			dash_speed:           0,
		},
		// Six-Claw Slash — short, very fast
		{
			name:                 "Six-Claw Slash",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_AGILITY,
			base_damage:          11,
			stat_mod:             0.20,
			cooldown_secs:        42,
			status_effect:        STATUS.NONE,
			status_duration_secs: 0,
			governing_stat:       "",
			base_effect:          0,
			range_px:             50,
			dash_speed:           0,
		},
		// Slither Strike — dash through enemy
		{
			name:                 "Slither Strike",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_AGILITY,
			base_damage:          13,
			stat_mod:             0.22,
			cooldown_secs:        120,
			status_effect:        STATUS.NONE,
			status_duration_secs: 0,
			governing_stat:       "",
			base_effect:          0,
			range_px:             100,
			dash_speed:           10,
		},
	];

	// ── RAPTOWL ────────────────────────────────────────────────────────────────
	global.combat_moves[SPECIES.RAPTOWL] = [
		// Dive Bomb — diagonal dash, high damage, knockback
		{
			name:                 "Dive Bomb",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_AGILITY,
			base_damage:          18,
			stat_mod:             0.28,
			cooldown_secs:        240,
			status_effect:        STATUS.KNOCKBACK,
			status_duration_secs: 18,
			governing_stat:       "",
			base_effect:          0,
			range_px:             110,
			dash_speed:           12,
		},
		// Talon Swipe — short, fast, precise
		{
			name:                 "Talon Swipe",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_DEXTERITY,
			base_damage:          10,
			stat_mod:             0.18,
			cooldown_secs:        48,
			status_effect:        STATUS.NONE,
			status_duration_secs: 0,
			governing_stat:       "",
			base_effect:          0,
			range_px:             55,
			dash_speed:           0,
		},
		// Screech — medium-radius debuff, -30% AGI base for 3s base
		{
			name:                 "Screech",
			type:                 MOVE_TYPE.DEBUFF,
			stat_key:             "",
			base_damage:          0,
			stat_mod:             0,
			cooldown_secs:        480,
			status_effect:        STATUS.NONE,
			status_duration_secs: 180,
			governing_stat:       STAT_INTELLECT,
			base_effect:          0.30,
			range_px:             150,
			dash_speed:           0,
		},
	];

	// ── THORNBACK ──────────────────────────────────────────────────────────────
	global.combat_moves[SPECIES.THORNBACK] = [
		// Shell Slam — defense-scaled melee, knockback
		{
			name:                 "Shell Slam",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_DEFENSE,
			base_damage:          18,
			stat_mod:             0.22,
			cooldown_secs:        120,
			status_effect:        STATUS.KNOCKBACK,
			status_duration_secs: 18,
			governing_stat:       "",
			base_effect:          0,
			range_px:             50,
			dash_speed:           0,
		},
		// Spike Roll — defense-scaled melee, no effect, faster cooldown
		{
			name:                 "Spike Roll",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_DEFENSE,
			base_damage:          14,
			stat_mod:             0.18,
			cooldown_secs:        72,
			status_effect:        STATUS.NONE,
			status_duration_secs: 0,
			governing_stat:       "",
			base_effect:          0,
			range_px:             40,
			dash_speed:           0,
		},
		// Iron Fortress — self buff, WIL governed
		{
			name:                 "Iron Fortress",
			type:                 MOVE_TYPE.BUFF,
			stat_key:             "",
			base_damage:          0,
			stat_mod:             0,
			cooldown_secs:        720,
			status_effect:        STATUS.NONE,
			status_duration_secs: 300,
			governing_stat:       STAT_WILLPOWER,
			base_effect:          2.5,
			range_px:             0,
			dash_speed:           0,
		},
	];

	// ── GLOWMOTH ───────────────────────────────────────────────────────────────
	global.combat_moves[SPECIES.GLOWMOTH] = [
		// Glimmer Pulse — long-range INT projectile, slows on hit
		{
			name:                 "Glimmer Pulse",
			type:                 MOVE_TYPE.PROJECTILE,
			stat_key:             STAT_INTELLECT,
			base_damage:          12,
			stat_mod:             0.24,
			cooldown_secs:        72,
			status_effect:        STATUS.SLOW,
			status_duration_secs: 60,
			governing_stat:       STAT_INTELLECT,
			base_effect:          0,
			range_px:             220,
			dash_speed:           0,
		},
		// Wing Dust — close melee, DEX-scaled, brief slow
		{
			name:                 "Wing Dust",
			type:                 MOVE_TYPE.MELEE,
			stat_key:             STAT_DEXTERITY,
			base_damage:          9,
			stat_mod:             0.16,
			cooldown_secs:        48,
			status_effect:        STATUS.SLOW,
			status_duration_secs: 30,
			governing_stat:       "",
			base_effect:          0,
			range_px:             45,
			dash_speed:           0,
		},
		// Moonveil — self buff, WIL governed
		{
			name:                 "Moonveil",
			type:                 MOVE_TYPE.BUFF,
			stat_key:             "",
			base_damage:          0,
			stat_mod:             0,
			cooldown_secs:        600,
			status_effect:        STATUS.NONE,
			status_duration_secs: 240,
			governing_stat:       STAT_WILLPOWER,
			base_effect:          0.25,
			range_px:             0,
			dash_speed:           0,
		},
	];

	// ── Combat state template ──────────────────────────────────────────────────
	global.combat_state = {
		active:            false,
		player_creature:   undefined,
		enemy_creature:    undefined,
		biome_id:          -1,
		result:            "",
		damage_dealt:      0,
		damage_taken:      0,
		xp_earned:         0,
		trait_acquired:    "",
		is_wild_encounter: false,
	};
}

// ── Accessors / helpers ────────────────────────────────────────────────────────

/// @desc Returns the 3-move array for a given species.
/// @param {real} species   A SPECIES enum value
/// @returns {Array}
function scr_combat_get_moves(species) {
	return global.combat_moves[species];
}

/// @desc Returns raw pre-defense damage for a move using diminishing-returns stat.
///       Returns 0 for buff/debuff moves (stat_key == "").
/// @param {Struct} attacker      Creature instance struct
/// @param {real}   move_index    0, 1, or 2
/// @returns {real}
function scr_combat_calc_damage(attacker, move_index) {
	var _move = global.combat_moves[attacker.species][move_index];
	if (_move.stat_key == "" || _move.base_damage == 0) return 0;
	var _raw_stat = attacker[$ "base_" + _move.stat_key];
	var _eff_stat = scr_effective_stat(_raw_stat);
	return _move.base_damage + (_eff_stat * _move.stat_mod);
}

/// @desc Returns the buff/debuff potency ratio for a move.
///       Formula: clamp(governing_stat / 50, 0.5, 1.8)
///       Returns 1.0 if the move has no governing stat.
/// @param {Struct} creature      Creature instance struct
/// @param {real}   move_index    0, 1, or 2
/// @returns {real}
function scr_combat_calc_potency(creature, move_index) {
	var _move = global.combat_moves[creature.species][move_index];
	if (_move.governing_stat == "") return 1.0;
	var _stat = creature[$ "base_" + _move.governing_stat];
	return clamp(_stat / 50.0, 0.5, 1.8);
}
