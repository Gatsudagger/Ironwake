// =============================================================================
// scr_combat.gml
// Turn-based combat engine for Ironwake.
//
// Turn flow:
//   1. combat_init()          — build sorted combatant queue
//   2. combat_next_turn()     — advance queue, restore energy, tick resources
//   3. Per-action:
//        combat_roll_hit()    — determine if attack lands
//        combat_roll_crit()   — determine crit type and quality
//        combat_resolve_damage() — apply mitigation, return final value
//        combat_apply_damage()   — subtract from HP
//   4. combat_is_defeated()   — check individual combatant
//   5. combat_check_victory() — check win/loss condition for full combat
//
// Class IDs (mirrors scr_stats): 0 = Arcanist, 1 = Bloodwarden, 2 = Shadowstrider
// Damage types: 0 = physical, 1 = elemental, 2 = drain
// Crit types:   0 = power (STR), 1 = precision (DEX), 2 = arcane (INT), 3 = effect (WIS)
// =============================================================================

// ---------------------------------------------------------------------------
// combat_init(combatant_array)
// Receives an array of combatant structs.
//
// Expected fields per combatant struct:
//   is_player   bool   — true for player-controlled combatant
//   class_id    int    — 0/1/2 (player only; enemies can omit)
//   stats       struct — output of stats_init(); must include DEX, WIS, STR, INT
//   HP          real   — current hit points
//   max_HP      real
//   armor       real   — flat physical damage reduction
//   el_resist   real   — flat elemental damage reduction
//   dodge       real   — subtracted from attacker hit chance
//
// Returns a combat_state struct used by all subsequent functions.
// ---------------------------------------------------------------------------
function combat_init(combatant_array) {
    var count = array_length(combatant_array);

    // Sort by DEX descending; break ties with WIS descending.
    // Insertion sort is fine for the small combatant counts typical in a roguelite.
    var sorted = array_create(count);
    array_copy(sorted, 0, combatant_array, 0, count);

    for (var i = 1; i < count; i++) {
        var key = sorted[i];
        var j   = i - 1;
        while (j >= 0) {
            var cmp_dex = sorted[j].stats.DEX - key.stats.DEX;
            var cmp_wis = sorted[j].stats.WIS - key.stats.WIS;
            // Advance j if the slot ahead has lower priority than key
            if (cmp_dex < 0 || (cmp_dex == 0 && cmp_wis < 0)) {
                sorted[j + 1] = sorted[j];
                j--;
            } else {
                break;
            }
        }
        sorted[j + 1] = key;
    }

    // Initialise secondary resources based on class
    for (var i = 0; i < count; i++) {
        var c = sorted[i];
        if (!c.is_player) continue;

        switch (c.class_id) {
            case 0: // Arcanist — Souls
                c.souls     = 0;
                c.souls_max = 10;
                break;
            case 1: // Bloodwarden — Blood
                c.blood     = 0;
                c.blood_max = 10;
                break;
            case 2: // Shadowstrider — Preparation
                c.preparation     = 0;
                c.preparation_max = 10;
                c.trap_active     = false;
                break;
        }
    }

    return {
        combatants:   sorted,          // initiative-ordered array
        turn_index:   0,               // index of the combatant currently acting
        round:        1,               // increments each time the queue wraps
        active:       sorted[0],       // convenience reference to current actor
    };
}

// ---------------------------------------------------------------------------
// combat_next_turn(combat_state)
// Advances to the next combatant in initiative order.
// Restores energy to 3, increments round counter when the queue wraps.
// Handles Shadowstrider Preparation generation.
// Returns the updated combat_state (same reference).
// ---------------------------------------------------------------------------
function combat_next_turn(combat_state) {
    var count = array_length(combat_state.combatants);

    combat_state.turn_index++;
    if (combat_state.turn_index >= count) {
        combat_state.turn_index = 0;
        combat_state.round++;
    }

    var actor = combat_state.combatants[combat_state.turn_index];
    combat_state.active = actor;

    // Fully restore energy at the start of each turn
    actor.energy = 3;

    // Shadowstrider gains 1 Preparation at turn start when no trap is active
    if (actor.is_player && actor.class_id == 2) {
        if (!actor.trap_active) {
            actor.preparation = min(actor.preparation + 1, actor.preparation_max);
        }
    }

    return combat_state;
}

// ---------------------------------------------------------------------------
// combat_roll_hit(attacker_stats, ability_acc, target_dodge, guaranteed)
// Resolves whether an attack lands.
//
// hit_chance = ability_acc + (attacker DEX * 3) - target_dodge
// Clamped to [5, 95] percent unless guaranteed is true.
// Returns true if the attack hits.
// ---------------------------------------------------------------------------
function combat_roll_hit(attacker_stats, ability_acc, target_dodge, guaranteed) {
    if (guaranteed) return true;

    var hit_chance = ability_acc + (attacker_stats.DEX * 3) - target_dodge;
    hit_chance     = clamp(hit_chance, 5, 95);

    return (irandom(99) < hit_chance); // irandom(99) gives 0–99 inclusive
}

// ---------------------------------------------------------------------------
// combat_roll_crit(attacker_stats, ability_base_crit, crit_type)
// Determines if a crit fires and, if so, returns the crit result struct.
//
// Crit types:
//   0 — Power     (STR): chance = base + STR*1.5,  multiplier 1.6x
//   1 — Precision (DEX): chance = base + DEX*2,    multiplier 1.35x
//   2 — Arcane    (INT): chance = base + INT*1,    multiplier 1.25x + 2 elemental stacks
//   3 — Effect    (WIS): chance = 5 + WIS*1.5,     improves status quality (no damage mult)
//
// Returns a struct:
//   { critted: bool, multiplier: real, bonus_el_stacks: int, effect_quality: int }
// ---------------------------------------------------------------------------
function combat_roll_crit(attacker_stats, ability_base_crit, crit_type) {
    var result = {
        critted:         false,
        multiplier:      1.0,
        bonus_el_stacks: 0,
        effect_quality:  0,
    };

    var chance = 0;
    switch (crit_type) {
        case 0: chance = ability_base_crit + (attacker_stats.STR * 1.5); break; // Power
        case 1: chance = ability_base_crit + (attacker_stats.DEX * 2);   break; // Precision
        case 2: chance = ability_base_crit + (attacker_stats.INT * 1);   break; // Arcane
        case 3: chance = 5               + (attacker_stats.WIS * 1.5);  break; // Effect
    }
    // "of Ruin" affix: flat crit bonus stored on the stats struct by apply_equipment_stats
    if (variable_struct_exists(attacker_stats, "crit_bonus")) {
        chance += attacker_stats.crit_bonus;
    }

    if (irandom(99) >= chance) return result; // no crit

    result.critted = true;

    switch (crit_type) {
        case 0: // Power — raw damage spike
            result.multiplier = 1.6;
            break;
        case 1: // Precision — moderate multiplier
            result.multiplier = 1.35;
            break;
        case 2: // Arcane — smaller multiplier but adds elemental stacks
            result.multiplier      = 1.25;
            result.bonus_el_stacks = 2;
            break;
        case 3: // Effect — no damage bonus; improves applied status quality
            result.multiplier     = 1.0;
            result.effect_quality = 1; // caller interprets: 1 = upgraded status
            break;
    }

    return result;
}

// ---------------------------------------------------------------------------
// combat_resolve_damage(base_damage, damage_type, target_armor, target_el_resist)
// Applies mitigation and returns the final damage value (never below 0).
//
// Damage types:
//   0 — Physical: reduced by target_armor
//   1 — Elemental: reduced by target_el_resist
//   2 — Drain: bypasses all mitigation
//
// Note: percentage modifiers from gear/traits should be applied by the caller
// to the returned value, after this function runs.
// ---------------------------------------------------------------------------
function combat_resolve_damage(base_damage, damage_type, target_armor, target_el_resist) {
    var final_damage = base_damage;

    switch (damage_type) {
        case 0: // Physical
            final_damage = base_damage - target_armor;
            break;
        case 1: // Elemental
            final_damage = base_damage - target_el_resist;
            break;
        case 2: // Drain — no mitigation
            final_damage = base_damage;
            break;
    }

    return max(0, final_damage);
}

// ---------------------------------------------------------------------------
// combat_apply_damage(target_struct, damage)
// Subtracts damage from target HP, clamping at 0.
// Returns the actual damage dealt (accounting for the HP floor).
// ---------------------------------------------------------------------------
function combat_apply_damage(target_struct, damage) {
    var prev_hp         = target_struct.HP;
    target_struct.HP    = max(0, target_struct.HP - damage);
    var actual_dealt    = prev_hp - target_struct.HP;
    return actual_dealt;
}

// ---------------------------------------------------------------------------
// combat_check_blink(target, combat_log)
// Charge-based Blink resolution.  Call this BEFORE applying damage whenever
// an attack targets a combatant who has is_untargetable == true.
//
// Behaviour:
//   • Consumes one charge (target.untargetable_turns--).
//   • Appends an "attack avoided" line to combat_log.
//   • When charges hit 0, clears is_untargetable and appends an expiry line.
//   • Returns true  → caller should skip damage resolution for this hit.
//   • Returns false → target is not blinking; caller proceeds normally.
//
// The combat controller initialises untargetable_turns from Blink's
// effect_duration (currently 2) when the ability is cast.
// ---------------------------------------------------------------------------
function combat_check_blink(target, combat_log) {
    if (!target.is_untargetable) return false;

    target.untargetable_turns--;

    var _tname;
    if (variable_struct_exists(target, "name")) {
        _tname = target.name;
    } else {
        _tname = "Target";
    }
    array_push(combat_log, _tname + " blinks — the attack passes through!");

    if (target.untargetable_turns <= 0) {
        target.is_untargetable    = false;
        target.untargetable_turns = 0;
        array_push(combat_log, "Blink fades. " + _tname + " is vulnerable again.");
    } else {
        array_push(combat_log,
            "Blink: " + string(target.untargetable_turns) + " charge(s) remaining.");
    }

    return true;
}

// ---------------------------------------------------------------------------
// combat_apply_start_traits(player)
// Call at combat start after the player struct and secondary resources are
// fully built. Applies all trait effects that modify starting combat state.
//   Thick Skin     — +10% max HP (and current HP, capped at new max)
//   Crimson Reserve— +20 Blood at combat start (Bloodwarden only)
//   Phantom Step   — sets phantom_step_active flag; consumed on first hit
// ---------------------------------------------------------------------------
function combat_apply_start_traits(player) {
    // Thick Skin: +10% maximum HP
    if (trait_active("Thick Skin")) {
        var _bonus = floor(player.max_HP * 0.10);
        player.max_HP += _bonus;
        player.HP      = min(player.HP + _bonus, player.max_HP);
    }

    // Crimson Reserve: Bloodwarden only — start combat with +20 Blood
    if (player.class_id == 1 && variable_struct_exists(player, "blood")
        && trait_active("Crimson Reserve")) {
        player.blood = min(player.blood_max, player.blood + 20);
    }

    // Phantom Step: first enemy attack each combat auto-misses
    // phantom_step_active is consumed by combat_check_phantom_step()
    player.phantom_step_active = trait_active("Phantom Step");
}

// ---------------------------------------------------------------------------
// combat_check_phantom_step(player, combat_log)
// Call before resolving each enemy melee attack on the player.
// If the player has Phantom Step active, consumes the flag, logs the auto-miss,
// and returns true so the caller skips damage entirely.
// Returns false if the trait is not active or was already consumed this combat.
// ---------------------------------------------------------------------------
function combat_check_phantom_step(player, combat_log) {
    if (!variable_struct_exists(player, "phantom_step_active")) return false;
    if (!player.phantom_step_active) return false;

    player.phantom_step_active = false;
    array_push(combat_log,
        "Phantom Step — the first enemy attack misses automatically!");
    return true;
}

// ---------------------------------------------------------------------------
// combat_is_defeated(combatant_struct)
// Returns true when a combatant's HP has reached 0.
// ---------------------------------------------------------------------------
function combat_is_defeated(combatant_struct) {
    return (combatant_struct.HP <= 0);
}

// ---------------------------------------------------------------------------
// combat_check_victory(combat_state)
// Scans the combatant list and evaluates the outcome.
//
// Returns:
//    1  — all enemies defeated (player wins)
//   -1  — player combatant defeated (player loses)
//    0  — combat is still ongoing
// ---------------------------------------------------------------------------
function combat_check_victory(combat_state) {
    var any_player_alive = false;
    var any_enemy_alive  = false;

    var count = array_length(combat_state.combatants);
    for (var i = 0; i < count; i++) {
        var c = combat_state.combatants[i];
        if (combat_is_defeated(c)) continue;

        if (c.is_player) {
            any_player_alive = true;
        } else {
            any_enemy_alive = true;
        }
    }

    if (!any_player_alive) return -1; // player lost
    if (!any_enemy_alive)  return  1; // player won
    return 0;                         // ongoing
}
