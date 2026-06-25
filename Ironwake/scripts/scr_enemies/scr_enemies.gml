// =============================================================================
// scr_enemies.gml
// Enemy data structures and the Phase 1 Ashen Vault roster for Ironwake.
//
// Usage pattern:
//   1. Call enemy_clone(template) at the start of each encounter — never pass
//      a template directly into combat, or stat mutations will persist.
//   2. Pass the cloned struct as a combatant to combat_init() in scr_combat.
//   3. The combat engine must branch on mechanic_type each turn to trigger
//      special behaviour. See per-mechanic notes below.
//
// mechanic_type reference:
//   "none"         — no special behaviour
//   "double_strike"— enemy attacks twice per action; each hit uses mechanic_value
//                    as the per-hit damage. Combat engine: fire two hit rolls.
//   "phase_shift"  — enemy becomes untargetable for mechanic_value turns every
//                    mechanic_turns turns. Combat engine: set an untargetable flag.
//   "charge"       — pairs with telegraph; enemy winds up and delivers
//                    telegraph_damage on the telegraphed turn. No extra engine
//                    logic needed beyond the telegraph path.
//   "regen"        — enemy recovers mechanic_value HP at the start of its turn
//                    every mechanic_turns turns. Combat engine: call
//                    combat_apply_damage with negative damage (heal).
//   "death_burst"  — on defeat, enemy deals mechanic_value elemental damage to
//                    the player. Combat engine: check after combat_is_defeated().
//   "fortify"      — reduces incoming damage by (1 - mechanic_value) for one turn
//                    every mechanic_turns turns. Combat engine: apply multiplier
//                    before combat_resolve_damage.
//   "retribution"  — gains mechanic_value armor for 2 turns when hit by the same
//                    damage type twice in a row. Combat engine: track last_damage_type
//                    on the enemy struct and compare each hit.
// =============================================================================

// ---------------------------------------------------------------------------
// enemy_define(...)
// Returns a fully populated enemy template struct.
// Always clone with enemy_clone() before placing into combat.
// ---------------------------------------------------------------------------
function enemy_define(
    name,
    HP,
    damage,
    armor,
    el_resist,
    dodge,
    acc,
    xp_value,
    gold_min,
    gold_max,
    telegraph_turn,
    telegraph_damage,
    telegraph_message,
    mechanic_type,
    mechanic_value,
    mechanic_turns,
    abilities = []
) {
    return {
        name:              name,

        // Combat stats
        HP:                HP,
        max_HP:            HP,
        damage:            damage,
        armor:             armor,
        el_resist:         el_resist,
        dodge:             dodge,
        acc:               acc,

        // Rewards
        xp_value:          xp_value,
        gold_min:          gold_min,
        gold_max:          gold_max,

        // Combat system flags — combat_init reads these
        is_player:         false,
        class_id:          -1,
        energy:            3,

        // Telegraph — warns the player one turn before a big attack lands
        telegraph_turn:    telegraph_turn,     // fires every N turns (0 = never)
        telegraph_damage:  telegraph_damage,
        telegraph_message: telegraph_message,

        // Special mechanic — the combat engine checks mechanic_type each turn
        mechanic_type:     mechanic_type,
        mechanic_value:    mechanic_value,
        mechanic_turns:    mechanic_turns,

        // Special abilities (Difficulty Pass) — array of enemy_ability() structs.
        // The combat engine may use one per turn instead of the basic attack.
        abilities:         abilities,
        ability_cd:        [],     // runtime per-ability cooldown counters

        // Runtime state — populated by the combat engine, empty on the template
        status_effects:    [],

        // Defeated flag — set true by the combat engine, never true on a template
        is_defeated:       false,

        // Internal tracking used by retribution mechanic
        last_damage_type:  -1,
    };
}

// ---------------------------------------------------------------------------
// enemy_ability(name, kind, chance, cooldown, value, extra)
// Builds one enemy-ability struct. kind ∈ "spell" (typed damage) / "debuff" /
// "dot" (status on player) / "control" (stun/root/silence) / "heal" (self).
// `extra` (optional struct) may set: dtype (0-3), status_kind, turns, msg.
// ---------------------------------------------------------------------------
function enemy_ability(name, kind, chance, cooldown, value, extra) {
    var _a = { name: name, kind: kind, chance: chance, cooldown: cooldown,
               value: value, dtype: 0, status_kind: "", turns: 1, msg: "" };
    if (extra != undefined) {
        if (variable_struct_exists(extra, "dtype"))       _a.dtype = extra.dtype;
        if (variable_struct_exists(extra, "status_kind")) _a.status_kind = extra.status_kind;
        if (variable_struct_exists(extra, "turns"))       _a.turns = extra.turns;
        if (variable_struct_exists(extra, "msg"))         _a.msg = extra.msg;
    }
    return _a;
}

// ---------------------------------------------------------------------------
// enemy_pick_ability(actor)
// Ticks the actor's per-ability cooldowns, then returns one ready ability that
// procs this turn (random among those that pass their chance roll), or undefined
// to fall through to the basic attack. Lazily initialises ability_cd.
// ---------------------------------------------------------------------------
function enemy_pick_ability(actor) {
    if (!variable_struct_exists(actor, "abilities") || array_length(actor.abilities) == 0) return undefined;
    if (!variable_struct_exists(actor, "ability_cd") || array_length(actor.ability_cd) != array_length(actor.abilities)) {
        actor.ability_cd = array_create(array_length(actor.abilities), 0);
    }
    for (var _i = 0; _i < array_length(actor.ability_cd); _i++) {
        if (actor.ability_cd[_i] > 0) actor.ability_cd[_i]--;
    }
    var _ready = [];
    for (var _i = 0; _i < array_length(actor.abilities); _i++) {
        if (actor.ability_cd[_i] > 0) continue;
        var _ab = actor.abilities[_i];
        var _ch = variable_struct_exists(_ab, "chance") ? _ab.chance : 100;
        if (irandom(99) < _ch) array_push(_ready, _i);
    }
    if (array_length(_ready) == 0) return undefined;
    var _pick = _ready[irandom(array_length(_ready) - 1)];
    actor.ability_cd[_pick] = variable_struct_exists(actor.abilities[_pick], "cooldown") ? actor.abilities[_pick].cooldown : 3;
    return actor.abilities[_pick];
}

// ---------------------------------------------------------------------------
// boss_ability_set(floor, dungeon)
// Two scaling abilities every boss gets: a typed nuke + a sparingly-used control
// slam. Floor raises magnitudes. Keeps control rare (low chance, long cooldown).
// ---------------------------------------------------------------------------
function boss_ability_set(floor, dungeon) {
    var _fl = clamp(floor, 1, 3);
    var _nuke_dmg  = [14, 20, 28][_fl - 1];
    var _dtype     = (dungeon == "tundra_tomb") ? 1 : ((dungeon == "scorched_depths") ? 1 : 2); // elemental / drain
    var _nuke_name = (dungeon == "tundra_tomb") ? "Frozen Lance" : ((dungeon == "scorched_depths") ? "Molten Barrage" : "Soul Rend");
    return [
        enemy_ability(_nuke_name, "spell", 45, 2, _nuke_dmg, { dtype: _dtype, msg: "unleashes " + _nuke_name }),
        enemy_ability("Crushing Slam", "control", 30, 4, 0, { status_kind: "stun", turns: 1, msg: "slams the ground — you are stunned" }),
    ];
}

// ---------------------------------------------------------------------------
// enemy_is_ranged(name) / enemy_is_spellcaster(name)
// Combat classification (reach + kind) used by control effects: root stops only
// melee enemies, silence stops only spellcasters, stun stops all.
// See SYSTEMS_ATTACK_CLASS.md. Boss aliases aren't listed → default melee/attack.
// ---------------------------------------------------------------------------
function enemy_is_ranged(name) {
    switch (name) {
        case "Skeleton Archer": case "Lava Spitter": case "Frost Shard": case "Pale Archivist":
            return true;
    }
    return false;
}
function enemy_is_spellcaster(name) {
    switch (name) {
        case "Dungeon Wraith": case "Vault Wraith": case "Ash Wraith": case "Snowbound Wraith":
        case "Ice Specter":    case "Pale Archivist": case "Fire Drake":  case "Lava Spitter":
        case "Frost Shard":    case "Cinder Imp":     case "Infernal Revenant":
        case "Smoldering Revenant":
            return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// enemy_clone(enemy_template)
// Returns a shallow copy of the template with a fresh status_effects array
// and all runtime state reset to defaults.
// Always call this before passing an enemy into combat.
// ---------------------------------------------------------------------------
function enemy_clone(enemy_template) {
    var c = {};

    // Copy every field from the template
    var keys = variable_struct_get_names(enemy_template);
    for (var i = 0; i < array_length(keys); i++) {
        var k = keys[i];
        variable_struct_set(c, k, variable_struct_get(enemy_template, k));
    }

    // Reset runtime-only fields so template state never leaks into combat
    c.HP             = enemy_template.max_HP;
    c.energy         = 3;
    c.status_effects = [];    // fresh array — never share with the template
    c.is_defeated    = false;
    c.last_damage_type = -1;
    c.ability_cd     = [];    // fresh per-combat cooldown counters

    return c;
}

// ---------------------------------------------------------------------------
// enemy_get_attack_damage(enemy, turn_number)
// Returns the damage this enemy deals on the given turn.
//
// If turn_number is a non-zero multiple of telegraph_turn, the telegraphed
// (big) attack fires and returns telegraph_damage instead of base damage.
// Returns 0 if the enemy is already defeated.
//
// Note: double_strike enemies deal mechanic_value per hit × 2 — the combat
// engine handles the two separate hit rolls; this function returns the
// per-hit value via enemy.mechanic_value for that mechanic type.
// ---------------------------------------------------------------------------
function enemy_get_attack_damage(enemy, turn_number) {
    if (enemy.is_defeated) return 0;

    // Telegraphed attack fires on its scheduled turn
    if (enemy.telegraph_turn > 0 && (turn_number mod enemy.telegraph_turn) == 0) {
        return max(1, enemy.telegraph_damage + irandom(4) - 2);
    }

    return max(1, enemy.damage + irandom(4) - 2);
}

// ---------------------------------------------------------------------------
// enemy_should_telegraph(enemy, turn_number)
// Returns true when the CURRENT turn is the turn immediately BEFORE the
// telegraphed attack, so the UI can display telegraph_message as a warning.
// Returns false if the enemy never telegraphs or is defeated.
// ---------------------------------------------------------------------------
function enemy_should_telegraph(enemy, turn_number) {
    if (enemy.is_defeated)       return false;
    if (enemy.telegraph_turn <= 0) return false;

    // The big attack fires on multiples of telegraph_turn.
    // The warning fires on the turn before: (next_telegraph - 1).
    var next_telegraph = (floor(turn_number / enemy.telegraph_turn) + 1) * enemy.telegraph_turn;
    return (turn_number == next_telegraph - 1);
}

// =============================================================================
// PHASE 1: ASHEN VAULT ROSTER
// Templates — always pass through enemy_clone() before combat use.
// =============================================================================

// -----------------------------------------------------------------------------
// STANDARD MOBS
// Low HP, low rewards, appear in normal encounter rooms.
// -----------------------------------------------------------------------------
global.enemies_ashen_vault_standard = [

    // 0: Ashen Skeleton
    // Straightforward melee attacker. No mechanics — good for teaching
    // the core hit/damage loop to the player.
    enemy_define(
        "Ashen Skeleton",
        /*HP*/28, /*damage*/6,
        /*armor*/2, /*el_resist*/0, /*dodge*/4, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"none", /*value*/0, /*turns*/0
    ),

    // 1: Vault Crawler
    // Always attacks twice. Each hit uses mechanic_value (5) as damage,
    // so total output is up to 10 per turn if both land.
    // COMBAT ENGINE: when mechanic_type == "double_strike", fire two separate
    // combat_roll_hit() calls using mechanic_value as the per-hit base damage.
    enemy_define(
        "Vault Crawler",
        /*HP*/22, /*damage*/5,
        /*armor*/0, /*el_resist*/0, /*dodge*/6, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"double_strike", /*value*/5, /*turns*/0
    ),

    // 2: Dungeon Wraith
    // Phases out every 3 turns (untargetable for 1 turn).
    // High dodge makes it slippery even when targetable.
    // COMBAT ENGINE: track a phase_timer on the clone; when
    // (turn_number mod mechanic_turns) == 0 set untargetable for mechanic_value turns.
    enemy_define(
        "Dungeon Wraith",
        /*HP*/20, /*damage*/8,
        /*armor*/0, /*el_resist*/4, /*dodge*/8, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/3,
        /*abilities*/[
            enemy_ability("Soul Drain", "spell", 35, 2, 9, { dtype: 2, msg: "drains your essence" }),
            enemy_ability("Haunting Gaze", "debuff", 30, 3, 0.20, { status_kind: "blind", turns: 2, msg: "clouds your sight" }),
            enemy_ability("Spectral Mend", "heal", 30, 3, 12, { msg: "knits its tattered form back together" }),
        ]
    ),

    // 3: Skeleton Archer
    // Announces a 18-damage charged shot the turn before it fires.
    enemy_define(
        "Skeleton Archer",
        /*HP*/24, /*damage*/6,
        /*armor*/0, /*el_resist*/0, /*dodge*/4, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/3, /*telegraph_damage*/18,
        /*message*/"is preparing a mighty blow!",
        /*mechanic*/"charge", /*value*/0, /*turns*/0
    ),

    // 4: Grave Stalker
    // High dodge skirmisher — punishes players who repeat the same damage type.
    // Forces constant ability rotation to avoid giving it armor stacks.
    enemy_define(
        "Grave Stalker",
        /*HP*/20, /*damage*/7,
        /*armor*/0, /*el_resist*/2, /*dodge*/14, /*acc*/78,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"retribution", /*value*/5, /*turns*/0,
        /*abilities*/[
            enemy_ability("Rending Slash", "dot", 35, 3, 4, { turns: 3, msg: "opens a deep bleeding wound" }),
        ]
    ),

    // 5: Bone Colossus
    // Slow, armored bruiser. Fortifies every 3 turns, making it briefly
    // nearly immune. Hit hard in the window between fortify cycles.
    enemy_define(
        "Bone Colossus",
        /*HP*/38, /*damage*/9,
        /*armor*/7, /*el_resist*/0, /*dodge*/0, /*acc*/68,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"fortify", /*value*/0.4, /*turns*/3,
        /*abilities*/[
            enemy_ability("Bone Crush", "control", 22, 4, 0, { status_kind: "stun", turns: 1, msg: "smashes you to the ground — stunned" }),
            enemy_ability("Knit Bone", "heal", 28, 4, 10, { msg: "knits its shattered bones" }),
        ]
    ),

];

// -----------------------------------------------------------------------------
// ELITE ENEMIES
// Higher HP, higher rewards, appear in elite encounter rooms.
// Each has a meaningful mechanic that forces the player to adapt strategy.
// -----------------------------------------------------------------------------
global.enemies_ashen_vault_elite = [

    // 0: Stone Golem
    // Massive armor makes physical damage mostly useless; elemental is preferred.
    // Fortifies every 4 turns (50% damage reduction for that turn), on the same
    // cycle as its telegraph attack — the player must choose to attack through
    // the fortify or hold back.
    // COMBAT ENGINE: on turns where (turn_number mod mechanic_turns) == 0, apply
    // a 0.5× multiplier to all incoming damage before combat_resolve_damage().
    enemy_define(
        "Stone Golem",
        /*HP*/80, /*damage*/14,
        /*armor*/10, /*el_resist*/2, /*dodge*/2, /*acc*/70,
        /*xp*/35, /*gold_min*/25, /*gold_max*/40,
        /*telegraph_turn*/4, /*telegraph_damage*/22,
        /*message*/"is preparing a mighty blow!",
        /*mechanic*/"fortify", /*value*/0.5, /*turns*/4
    ),

    // 1: Vault Guardian
    // Punishes players who repeat the same damage type — after two consecutive
    // hits of the same type it gains 4 armor for 2 turns (retribution).
    // Forces the player to alternate damage types or switch to drain.
    // COMBAT ENGINE: after each hit, compare the incoming damage_type to
    // enemy.last_damage_type. If equal, add mechanic_value to armor for 2 turns
    // and reset last_damage_type. Always update last_damage_type after a hit.
    enemy_define(
        "Vault Guardian",
        /*HP*/70, /*damage*/16,
        /*armor*/6, /*el_resist*/6, /*dodge*/4, /*acc*/72,
        /*xp*/35, /*gold_min*/30, /*gold_max*/45,
        /*telegraph_turn*/4, /*telegraph_damage*/24,
        /*message*/"is preparing a mighty blow!",
        /*mechanic*/"retribution", /*value*/4, /*turns*/0
    ),

];

// =============================================================================
// SCORCHED DEPTHS — fire-themed dungeon, floors 1-3
// =============================================================================
global.enemies_scorched_depths_standard = [
    enemy_define(
        /*name*/"Cinder Imp",
        /*HP*/38, /*damage*/4, /*armor*/1, /*el_resist*/3, /*dodge*/5, /*acc*/72,
        /*xp*/12, /*gold_min*/3, /*gold_max*/8,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"double_strike", /*value*/4, /*turns*/0
    ),
    enemy_define(
        /*name*/"Magma Slug",
        /*HP*/55, /*damage*/6, /*armor*/4, /*el_resist*/5, /*dodge*/0, /*acc*/68,
        /*xp*/15, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"regen", /*value*/4, /*turns*/2
    ),
    enemy_define(
        /*name*/"Ash Wraith",
        /*HP*/42, /*damage*/8, /*armor*/0, /*el_resist*/8, /*dodge*/10, /*acc*/70,
        /*xp*/14, /*gold_min*/3, /*gold_max*/8,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/3
    ),
    enemy_define(
        /*name*/"Fire Drake",
        /*HP*/50, /*damage*/7, /*armor*/3, /*el_resist*/4, /*dodge*/3, /*acc*/74,
        /*xp*/16, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/3, /*telegraph_damage*/18,
        /*message*/"is drawing in a deep breath!",
        /*mechanic*/"charge", /*value*/0, /*turns*/0,
        /*abilities*/[
            enemy_ability("Cinder Breath", "spell", 35, 2, 12, { dtype: 1, msg: "breathes a gout of flame" }),
            enemy_ability("Searing Brand", "dot", 30, 3, 5, { turns: 3, msg: "sears you with lingering fire" }),
        ]
    ),

    // Lava Spitter — high acc ranged attacker, retribution punishes repeated elements
    enemy_define(
        /*name*/"Lava Spitter",
        /*HP*/30, /*damage*/8, /*armor*/0, /*el_resist*/6, /*dodge*/2, /*acc*/84,
        /*xp*/12, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"retribution", /*value*/4, /*turns*/0
    ),

    // Smoldering Revenant — regenerates and explodes on death; punishes slow kills
    enemy_define(
        /*name*/"Smoldering Revenant",
        /*HP*/36, /*damage*/6, /*armor*/1, /*el_resist*/5, /*dodge*/4, /*acc*/72,
        /*xp*/14, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"death_burst", /*value*/10, /*turns*/0,
        /*abilities*/[
            enemy_ability("Ember Mending", "heal", 30, 3, 10, { msg: "draws on the embers and mends" }),
        ]
    ),
];

global.enemies_scorched_depths_elite = [
    enemy_define(
        /*name*/"Cinder Golem",
        /*HP*/90, /*damage*/10, /*armor*/6, /*el_resist*/5, /*dodge*/0, /*acc*/72,
        /*xp*/30, /*gold_min*/15, /*gold_max*/25,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"fortify", /*value*/0.5, /*turns*/4
    ),
    enemy_define(
        /*name*/"Infernal Revenant",
        /*HP*/75, /*damage*/12, /*armor*/3, /*el_resist*/8, /*dodge*/5, /*acc*/74,
        /*xp*/28, /*gold_min*/14, /*gold_max*/22,
        /*telegraph_turn*/4, /*telegraph_damage*/20,
        /*message*/"is channeling hellfire!",
        /*mechanic*/"death_burst", /*value*/12, /*turns*/0
    ),
];

// =============================================================================
// TUNDRA TOMB — ice/undead dungeon, floors 1-3
// =============================================================================
global.enemies_tundra_tomb_standard = [
    enemy_define(
        /*name*/"Frost Shard",
        /*HP*/35, /*damage*/7, /*armor*/1, /*el_resist*/6, /*dodge*/8, /*acc*/72,
        /*xp*/13, /*gold_min*/3, /*gold_max*/8,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/3
    ),
    enemy_define(
        /*name*/"Glacial Lurker",
        /*HP*/44, /*damage*/5, /*armor*/2, /*el_resist*/4, /*dodge*/4, /*acc*/74,
        /*xp*/14, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"double_strike", /*value*/5, /*turns*/0
    ),
    enemy_define(
        /*name*/"Pale Archivist",
        /*HP*/40, /*damage*/6, /*armor*/1, /*el_resist*/5, /*dodge*/2, /*acc*/70,
        /*xp*/13, /*gold_min*/3, /*gold_max*/8,
        /*telegraph_turn*/3, /*telegraph_damage*/16,
        /*message*/"is inscribing a death rune!",
        /*mechanic*/"charge", /*value*/0, /*turns*/0,
        /*abilities*/[
            enemy_ability("Death Rune", "control", 25, 4, 0, { status_kind: "silence", turns: 2, msg: "binds your tongue — silenced" }),
            enemy_ability("Frost Bolt", "spell", 35, 2, 10, { dtype: 1, msg: "hurls a shard of ice" }),
            enemy_ability("Restorative Glyph", "heal", 35, 3, 16, { msg: "traces a restorative glyph and mends" }),
        ]
    ),
    enemy_define(
        /*name*/"Snowbound Wraith",
        /*HP*/48, /*damage*/7, /*armor*/0, /*el_resist*/9, /*dodge*/6, /*acc*/73,
        /*xp*/15, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"regen", /*value*/3, /*turns*/2
    ),

    // Ice Specter — phases out AND punishes repeated damage types; very slippery
    enemy_define(
        /*name*/"Ice Specter",
        /*HP*/28, /*damage*/8, /*armor*/0, /*el_resist*/10, /*dodge*/10, /*acc*/65,
        /*xp*/14, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/2,
        /*abilities*/[
            enemy_ability("Numbing Chill", "debuff", 35, 3, 0.20, { status_kind: "weaken", turns: 2, msg: "chills you to the bone — weakened" }),
        ]
    ),

    // Frozen Thrall — fortifies behind an icy shell, then telegraphs a crushing blow
    enemy_define(
        /*name*/"Frozen Thrall",
        /*HP*/40, /*damage*/7, /*armor*/5, /*el_resist*/4, /*dodge*/0, /*acc*/70,
        /*xp*/14, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/4, /*telegraph_damage*/19,
        /*message*/"is rearing back for a frozen slam!",
        /*mechanic*/"fortify", /*value*/0.45, /*turns*/4
    ),
];

global.enemies_tundra_tomb_elite = [
    enemy_define(
        /*name*/"Glacial Beast",
        /*HP*/85, /*damage*/11, /*armor*/5, /*el_resist*/6, /*dodge*/2, /*acc*/76,
        /*xp*/29, /*gold_min*/15, /*gold_max*/24,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"fortify", /*value*/0.5, /*turns*/4
    ),
    enemy_define(
        /*name*/"Frozen Sentinel",
        /*HP*/72, /*damage*/10, /*armor*/4, /*el_resist*/7, /*dodge*/3, /*acc*/74,
        /*xp*/27, /*gold_min*/14, /*gold_max*/22,
        /*telegraph_turn*/4, /*telegraph_damage*/18,
        /*message*/"is preparing a devastating strike!",
        /*mechanic*/"retribution", /*value*/4, /*turns*/0
    ),
];
