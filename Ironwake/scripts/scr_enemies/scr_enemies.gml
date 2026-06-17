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
    mechanic_turns
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

        // Runtime state — populated by the combat engine, empty on the template
        status_effects:    [],

        // Defeated flag — set true by the combat engine, never true on a template
        is_defeated:       false,

        // Internal tracking used by retribution mechanic
        last_damage_type:  -1,
    };
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
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/3
    ),

    // 3: Skeleton Archer
    // Announces a 18-damage charged shot the turn before it fires.
    // The "charge" mechanic is handled purely via the telegraph path —
    // enemy_should_telegraph() returns true one turn early, UI shows the message,
    // then enemy_get_attack_damage() returns telegraph_damage on the fire turn.
    enemy_define(
        "Skeleton Archer",
        /*HP*/24, /*damage*/6,
        /*armor*/0, /*el_resist*/0, /*dodge*/4, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/3, /*telegraph_damage*/18,
        /*message*/"is preparing a mighty blow!",
        /*mechanic*/"charge", /*value*/0, /*turns*/0
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
