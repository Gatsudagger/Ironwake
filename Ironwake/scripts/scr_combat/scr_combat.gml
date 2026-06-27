// =============================================================================
// scr_combat.gml
// Turn-based combat engine for Ironwake.
//
// Turn flow:
//   1. combat_init()          - build sorted combatant queue
//   2. combat_next_turn()     - advance queue, restore energy, tick resources
//   3. Per-action:
//        combat_roll_hit()    - determine if attack lands
//        combat_roll_crit()   - determine crit type and quality
//        combat_resolve_damage() - apply mitigation, return final value
//        combat_apply_damage()   - subtract from HP
//   4. combat_is_defeated()   - check individual combatant
//   5. combat_check_victory() - check win/loss condition for full combat
//
// Class IDs (mirrors scr_stats): 0 = Arcanist, 1 = Bloodwarden, 2 = Shadowstrider
// Damage types: 0 = physical, 1 = elemental, 2 = drain, 3 = blood (INT-scaled, bypasses armor)
// Crit types:   0 = power (STR), 1 = precision (DEX), 2 = arcane (INT), 3 = effect (WIS)
// =============================================================================

// ---------------------------------------------------------------------------
// combat_init(combatant_array)
// Receives an array of combatant structs.
//
// Expected fields per combatant struct:
//   is_player   bool   - true for player-controlled combatant
//   class_id    int    - 0/1/2 (player only; enemies can omit)
//   stats       struct - output of stats_init(); must include DEX, WIS, STR, INT
//   HP          real   - current hit points
//   max_HP      real
//   armor       real   - flat physical damage reduction
//   el_resist   real   - flat elemental damage reduction
//   dodge       real   - subtracted from attacker hit chance
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
            case 0: // Arcanist - Souls
                c.souls     = 0;
                c.souls_max = 10;
                break;
            case 1: // Bloodwarden - Blood
                c.blood     = 0;
                c.blood_max = 10;
                break;
            case 2: // Shadowstrider - Preparation
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
// ---------------------------------------------------------------------------
// DIMINISHING-RETURNS STAT CURVES (Viability/stat rebalance).
// Linear stat scaling let DEX run accuracy to +114 and dodge/crit to ~76 - every
// attack auto-hit/auto-dodged/auto-crit. These asymptotic curves give smooth
// diminishing returns that PLATEAU toward a cap: value = cap * stat / (stat + half).
// Single source of truth - used by BOTH stats_derive (display) and the combat rolls
// below, so the stat sheet and actual behaviour always match. See SYSTEMS_VIABILITY_PASS.md.
// ---------------------------------------------------------------------------
function stat_curve(stat, cap, half) {
    if (stat <= 0) return 0;
    return cap * stat / (stat + half);
}
function stat_accuracy(dex) { return stat_curve(dex, 10, 18); }   // MINOR: ~+3 @8, +7 @38, ->10. Gear/traits/runes carry real accuracy.
function stat_dodge(dex)    { return stat_curve(dex, 30, 22); }   // ~8 @8, 19 @38, ->30 (tamer)
// Crit CHANCE contributed by the governing stat, by crit_type (matches combat_roll_crit).
function stat_crit_chance(stats, crit_type) {
    switch (crit_type) {
        case 0: return stat_curve(stats.STR, 40, 16);       // Power     (STR)
        case 1: return stat_curve(stats.DEX, 45, 18);       // Precision (DEX)
        case 2: return stat_curve(stats.INT, 38, 20);       // Arcane    (INT)
        case 3: return 5 + stat_curve(stats.WIS, 35, 16);   // Effect    (WIS) - keeps +5 base
    }
    return 0;
}

// combat_roll_hit(attacker_acc, defender_dodge, guaranteed)
// TWO-STAGE roll so the log can distinguish a MISS (attacker's accuracy failed) from a
// DODGE (defender evaded a hit that would have landed), and so Dodge is a literal %.
//   Stage 1: attacker_acc% to land at all  (clamp 5..99). Fail -> "miss".
//   Stage 2: defender_dodge% to evade      (clamp 0..90). Pass -> "dodge".
// Returns "hit" | "miss" | "dodge".
function combat_roll_hit(attacker_acc, defender_dodge, guaranteed) {
    if (guaranteed) return "hit";

    var _acc = clamp(attacker_acc, 5, 99);
    if (irandom(99) >= _acc) return "miss";          // attacker failed to connect

    var _dodge = clamp(defender_dodge, 0, 90);
    if (_dodge > 0 && irandom(99) < _dodge) return "dodge"; // defender slipped it

    return "hit";
}

// ---------------------------------------------------------------------------
// combat_roll_crit(attacker_stats, ability_base_crit, crit_type)
// Determines if a crit fires and, if so, returns the crit result struct.
//
// Crit types:
//   0 - Power     (STR): chance = base + STR*1.5,  multiplier 1.6x
//   1 - Precision (DEX): chance = base + DEX*2,    multiplier 1.35x
//   2 - Arcane    (INT): chance = base + INT*1,    multiplier 1.25x + 2 elemental stacks
//   3 - Effect    (WIS): chance = 5 + WIS*1.5,     improves status quality (no damage mult)
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

    // Stat contribution uses the shared diminishing-returns curve (stat_crit_chance);
    // type 3 (Effect/WIS) already bakes in its +5 base, so don't add ability_base_crit there.
    var chance;
    if (crit_type == 3) chance = stat_crit_chance(attacker_stats, 3);
    else                chance = ability_base_crit + stat_crit_chance(attacker_stats, crit_type);
    // "of Ruin" affix: flat crit bonus stored on the stats struct by apply_equipment_stats
    if (variable_struct_exists(attacker_stats, "crit_bonus")) {
        chance += attacker_stats.crit_bonus;
    }

    if (irandom(99) >= chance) return result; // no crit

    result.critted = true;

    switch (crit_type) {
        case 0: // Power - raw damage spike
            result.multiplier = 1.6;
            break;
        case 1: // Precision - moderate multiplier
            result.multiplier = 1.35;
            break;
        case 2: // Arcane - smaller multiplier but adds elemental stacks
            result.multiplier      = 1.25;
            result.bonus_el_stacks = 2;
            break;
        case 3: // Effect - no damage bonus; improves applied status quality
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
//   0 - Physical: reduced by target_armor
//   1 - Elemental: reduced by target_el_resist
//   2 - Drain: bypasses all mitigation
//   3 - Blood: bypasses armor; flat bonus added by caller via INT scaling
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
        case 2: // Drain - no mitigation
            final_damage = base_damage;
            break;
        case 3: // Blood - bypasses armor, scales with INT via caller
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
//   * Consumes one charge (target.untargetable_turns--).
//   * Appends an "attack avoided" line to combat_log.
//   * When charges hit 0, clears is_untargetable and appends an expiry line.
//   * Returns true  -> caller should skip damage resolution for this hit.
//   * Returns false -> target is not blinking; caller proceeds normally.
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
    array_push(combat_log, _tname + " blinks - the attack passes through!");

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
// awaken_enemy_acc_bonus()
// Flat accuracy points added to every enemy hit roll, scaling with the run's
// Awakening tier. Stops stacked DODGE/DEX from trivializing high Awakenings -
// at A4/A5 even an evasion build gets hit. Added to _enemy_acc in combat.
// ---------------------------------------------------------------------------
function awaken_enemy_acc_bonus() {
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    var _tbl = [0, 0, 5, 10, 18, 28];
    _asc = clamp(_asc, 0, array_length(_tbl) - 1);
    return _tbl[_asc];
}

// awaken_enemy_heal_mult() - enemy healing scales with Awakening (mirrors the dmg
// curve). At high tiers, self-healing foes punish slow damage and reward burst /
// anti-heal (mortality) / consumables. See SYSTEMS_VIABILITY_PASS.md (P6c).
function awaken_enemy_heal_mult() {
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    var _tbl = [1.0, 1.15, 1.35, 1.6, 1.9, 2.3];
    _asc = clamp(_asc, 0, array_length(_tbl) - 1);
    return _tbl[_asc];
}

// ---------------------------------------------------------------------------
// combat_evasion_chance(target)
// Dodge CHANCE (0-100) for the active-evasion abilities Blink / Shadow Step.
// These used to be guaranteed; now they roll. Base 50% + WIS*2, capped 85%.
// Stun halves the chance (weakened evasion - you can't reliably slip a hit
// while stunned). Call once per incoming attack the window covers.
// ---------------------------------------------------------------------------
function combat_evasion_chance(target) {
    var _wis = (variable_struct_exists(target, "stats") && variable_struct_exists(target.stats, "WIS"))
               ? target.stats.WIS : 0;
    var _ch = clamp(50 + _wis * 2, 0, 85);
    if (combat_has_status(target, "stun")) _ch = floor(_ch * 0.5);
    return _ch;
}

// ---------------------------------------------------------------------------
// combat_apply_start_traits(player)
// Call at combat start after the player struct and secondary resources are
// fully built. Applies all trait effects that modify starting combat state.
//   Thick Skin     - +10% max HP (and current HP, capped at new max)
//   Crimson Reserve- +20 Blood at combat start (Bloodwarden only)
//   Phantom Step   - sets phantom_step_active flag; consumed on first hit
// ---------------------------------------------------------------------------
function combat_apply_start_traits(player) {
    // Thick Skin: +10% maximum HP (scaled by Vex trait potency)
    if (trait_active("Thick Skin")) {
        var _bonus = floor(player.max_HP * 0.10 * trait_potency_mult("Thick Skin"));
        player.max_HP += _bonus;
        player.HP      = min(player.HP + _bonus, player.max_HP);
    }

    // Crimson Reserve: Bloodwarden only - start combat with +20 Blood
    if (player.class_id == 1 && variable_struct_exists(player, "blood")
        && trait_active("Crimson Reserve")) {
        player.blood = min(player.blood_max, player.blood + 20);
    }

    // Phantom Step: first enemy attack each combat auto-misses
    // phantom_step_active is consumed by combat_check_phantom_step()
    player.phantom_step_active = trait_active("Phantom Step");

    // Ley Tap: +1 bonus AP at combat start (Arcanist only)
    if (player.class_id == 0 && trait_active("Ley Tap")) {
        player.AP += 1;
    }

    // Iron Will: first status effect applied to the player this combat is absorbed
    player.iron_will_active = trait_active("Iron Will");

    // Battle Hardened: apply accumulated permanent HP bonus
    if (variable_global_exists("perm_hp_battle_hardened") && global.perm_hp_battle_hardened > 0) {
        player.max_HP += global.perm_hp_battle_hardened;
        player.HP      = min(player.HP + global.perm_hp_battle_hardened, player.max_HP);
    }

    // Shadow Meld: initialize per-combat dodge bonus tracker
    player.shadow_meld_bonus = 0;

    // Aspect-rune flagship per-combat flags (Quickcast / Echo).
    player.rune_first_spell_used = false;   // Quickcast: first spell each combat costs -1 AP
    player.rune_first_aoe_used   = false;   // Echo: first AoE each combat echoes for 50%

    // Aegis boon: begin each combat with a shield.
    if (boon_active("aegis")) {
        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
        player.shield_hp += boon_value("aegis");
    }
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
        "Phantom Step - the first enemy attack misses automatically!");
    return true;
}

// ---------------------------------------------------------------------------
// combat_try_last_stand(player, combat_log)
// Last Stand trait: the first time the player would die in a run, survive at
// 1 HP instead. Consumed once per run (global.last_stand_used, reset in end_run).
// Returns true when the death was averted (HP set to 1); false otherwise - the
// caller should mark the player defeated only when this returns false.
// ---------------------------------------------------------------------------
function combat_try_last_stand(player, combat_log) {
    if (player.HP > 0) return false;
    if (!trait_active("Last Stand")) return false;
    if (variable_global_exists("last_stand_used") && global.last_stand_used) return false;

    player.HP = 1;
    if (variable_global_exists("last_stand_used")) global.last_stand_used = true;
    array_push(combat_log, "LAST STAND! You cling to life at 1 HP.");
    return true;
}

// =============================================================================
// STATUS LAYER - typed buffs/debuffs (AoE + status systems)
// Each entry pushed onto a combatant's status_effects[] carries a `kind`
// (dot / vulnerable / weaken / blind / mortality / stun / root). The aggregation
// helpers read all active statuses of a kind and return the combined modifier.
//   vulnerable - flat extra damage taken          (summed)
//   weaken     - % outgoing damage reduction        (max)
//   blind      - % accuracy reduction (0..1)         (max)
//   mortality  - % healing reduction (0..1)          (max)
//   stun/root/silence - control flags (stun=all, root=melee, silence=spell)
// `kind` falls back to effect_type for legacy statuses that predate this layer.
// =============================================================================

// kind of a single applied status struct (with backward-compatible fallback)
function combat_status_kind_of(se) {
    return variable_struct_exists(se, "kind") ? se.kind : se.effect_type;
}

// ability_status_kind(ability) - single source of truth mapping an ability to the
// status `kind` it applies. Re-tags the existing debuffs onto the typed layer.
function ability_status_kind(ability) {
    switch (ability.name) {
        case "Scorch":
            // Dedicated "firemark" kind: a per-hit TRUE FIRE rider (mitigated by the
            // target's el_resist), NOT the typeless `vulnerable` sum. Still detonates as
            // vulnerable (see combat_detonator_pick) so the Arcane Burst combo survives.
            return "firemark";
        case "Curse": case "Bonebreaker": case "Marked for Death":
            return "vulnerable";
        case "Marrow Crush": case "Crippling Shot":
            return "weaken";
        case "Smoke Bomb":
            return "blind";
        case "Plague Touch":
            return "mortality";
        case "Death Snare":
            return "stun";
        case "Bear Trap":
            return "root";
        case "Mana Sever":
            return "silence";   // "sever mana" - target can't take spell actions
    }
    if (ability.effect_type == "dot")    return "dot";
    if (ability.effect_type == "debuff") return "vulnerable";
    return ability.effect_type;
}

// ability_status_element(ability) - the elemental flavor tag stamped on a status
// when this ability applies it, used by the detonation reaction system. Most
// statuses are kind-based (vulnerable/weaken/stun...) and need no element (""); only
// DoTs and future fire/frost effects carry one. See SYSTEMS_VIABILITY_PASS.md.
function ability_status_element(ability) {
    switch (ability.name) {
        case "Scorch":        return "fire";   // firemark rider deals true fire damage
        case "Poison Dart":   return "poison";
        case "Gore Strike": case "Spike Trap": case "Serrated Bleed":
            return "bleed";
        case "Entropy":       return "void";
    }
    if (ability.effect_type == "dot") {
        switch (ability.damage_type) {
            case 1: return "burn";    // elemental DoT (future fire abilities)
            case 2: return "void";
            default: return "bleed";  // physical / blood DoT reads as bleed
        }
    }
    return "";
}

// elem_status_name(element) / elem_status_verb(element) - display name + log verb
// for the setup status an elemental weapon affix applies (SYSTEMS_WEAPON_ROLES.md
// §C). The name keyword ("Burn") also lets the icon/VFX resolver fall back cleanly.
function elem_status_name(element) {
    switch (element) {
        case "burn":  return "Burning";
        case "frost": return "Frostbite";
        case "shock": return "Shock";
    }
    return "Elemental";
}
function elem_status_verb(element) {
    switch (element) {
        case "burn":  return "set ablaze";
        case "frost": return "frozen";
        case "shock": return "shocked";
    }
    return "afflicted";
}

// combat_control_block_reason(combatant, attack_class)
// Returns "" if the combatant may take an action of the given attack_class this turn,
// else the reason it's blocked: "stunned" (any), "rooted" (melee classes), "silenced"
// (spell classes). See SYSTEMS_ATTACK_CLASS.md. attack_class "none" is never blocked.
function combat_control_block_reason(combatant, attack_class) {
    if (attack_class == "none") return "";
    if (combat_has_status(combatant, "stun")) return "stunned";
    var _melee = (attack_class == "melee_attack" || attack_class == "melee_spell");
    var _spell = (attack_class == "melee_spell" || attack_class == "ranged_spell");
    if (_melee && combat_has_status(combatant, "root"))    return "rooted";
    if (_spell && combat_has_status(combatant, "silence")) return "silenced";
    return "";
}

// combat_status_total(c, kind) - sum of effect_value across active statuses of kind.
function combat_status_total(c, kind) {
    if (!variable_struct_exists(c, "status_effects")) return 0;
    var _t = 0;
    for (var _i = 0; _i < array_length(c.status_effects); _i++) {
        var _se = c.status_effects[_i];
        if (combat_status_kind_of(_se) == kind) _t += _se.effect_value;
    }
    return _t;
}

// combat_status_max(c, kind) - largest effect_value of kind (for % modifiers,
// so stacking the same debuff doesn't compound).
function combat_status_max(c, kind) {
    if (!variable_struct_exists(c, "status_effects")) return 0;
    var _m = 0;
    for (var _i = 0; _i < array_length(c.status_effects); _i++) {
        var _se = c.status_effects[_i];
        if (combat_status_kind_of(_se) == kind) _m = max(_m, _se.effect_value);
    }
    return _m;
}

// combat_has_status(c, kind) - true if any active status of kind is present.
function combat_has_status(c, kind) {
    if (!variable_struct_exists(c, "status_effects")) return false;
    for (var _i = 0; _i < array_length(c.status_effects); _i++) {
        if (combat_status_kind_of(c.status_effects[_i]) == kind) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// DETONATION REACTIONS (Viability Pass - see SYSTEMS_VIABILITY_PASS.md).
// A "detonator" ability (Snipe/Assassinate/Arcane Burst/Soul Nova/Rupture) reacts
// with the strongest status on the target: a status-specific effect, then (usually)
// the status is consumed. Statuses carry an `element` tag (poison/bleed/void/burn/
// frost) set at application; untagged/enemy statuses fall back to inference.
// ---------------------------------------------------------------------------
function combat_status_element(se) {
    if (is_struct(se) && variable_struct_exists(se, "element") && se.element != "") return se.element;
    // Fallback inference for untagged statuses (older saves / enemy-applied DoTs).
    var _k = (is_struct(se) && variable_struct_exists(se, "kind")) ? se.kind : "";
    if (_k == "dot") return "bleed";   // generic DoT defaults to bleed
    return "";
}

// combat_detonator_pick(target) - returns { key, idx } for the highest-priority
// reaction the target is currently carrying, or { key:"", idx:-1 } if none.
function combat_detonator_pick(target) {
    var _none = { key: "", idx: -1 };
    if (!is_struct(target) || !variable_struct_exists(target, "status_effects")) return _none;
    var _se = target.status_effects;
    var _order = ["stun", "frost", "root", "burn", "shock", "vulnerable", "bleed", "poison", "void", "weaken", "blind"];
    for (var _o = 0; _o < array_length(_order); _o++) {
        var _want = _order[_o];
        for (var _i = 0; _i < array_length(_se); _i++) {
            var _s  = _se[_i];
            var _k  = variable_struct_exists(_s, "kind") ? _s.kind : "";
            var _el = combat_status_element(_s);
            var _match = false;
            switch (_want) {
                case "stun":       _match = (_k == "stun"); break;
                case "frost":      _match = (_el == "frost"); break;
                case "root":       _match = (_k == "root"); break;
                case "burn":       _match = (_el == "burn"); break;
                case "shock":      _match = (_el == "shock"); break;
                case "vulnerable": _match = (_k == "vulnerable" || _k == "firemark"); break;  // Scorch's firemark detonates as Exposed (+12)
                case "bleed":      _match = (_k == "dot" && _el == "bleed"); break;
                case "poison":     _match = (_k == "dot" && _el == "poison"); break;
                case "void":       _match = (_k == "dot" && _el == "void"); break;
                case "weaken":     _match = (_k == "weaken"); break;
                case "blind":      _match = (_k == "blind"); break;
            }
            if (_match) return { key: _want, idx: _i };
        }
    }
    return _none;
}

// combat_tick_statuses(c, log) - generic per-turn tick: apply DoT damage and
// decrement every status' duration, dropping expired ones. Used for the PLAYER
// at turn start (enemies use the richer inline tick in Step_0 for kill/VFX).
function combat_tick_statuses(c, log) {
    if (!variable_struct_exists(c, "status_effects")) return;
    var _cname = variable_struct_exists(c, "name") ? c.name : "Target";
    var _keep = [];
    for (var _i = 0; _i < array_length(c.status_effects); _i++) {
        var _se = c.status_effects[_i];
        if (combat_status_kind_of(_se) == "dot") {
            combat_apply_damage(c, _se.effect_value);
            array_push(log, _cname + " takes " + string(_se.effect_value) + " " + _se.name + " damage!");
        }
        _se.duration--;
        if (_se.duration > 0) {
            array_push(_keep, _se);
        } else {
            array_push(log, _se.name + " wore off " + _cname + ".");
        }
    }
    c.status_effects = _keep;
}

// combat_heal_after_mortality(c, amount) - scales a heal by the bearer's
// `mortality` debuff (-% healing received). Returns the reduced amount.
function combat_heal_after_mortality(c, amount) {
    // Withered curse: -50% healing received (applies to the player only; enemies
    // don't carry curses). Stacks multiplicatively with the mortality debuff.
    if (variable_struct_exists(c, "is_player") && c.is_player && curse_heal_mult() != 1.0) {
        amount = amount * curse_heal_mult();
    }
    var _m = combat_status_max(c, "mortality");
    if (_m <= 0) return max(0, floor(amount));
    return max(0, floor(amount * (1 - _m)));
}

// combat_mitigate_player(player, raw, dtype, log) - runs the full player damage
// mitigation chain for an enemy ability hit (typed): resist/armor -> vulnerable ->
// flat reduction (Iron Skin) -> equip armor -> % physical reduction (physical only)
// -> Soul Shield absorption (mutates shield_hp, logs). Returns the final damage.
// Mirrors the inline basic-attack chain so enemy spells can't diverge from it.
function combat_mitigate_player(player, raw, dtype, log) {
    var _d = combat_resolve_damage(raw, dtype, player.armor, player.el_resist);
    _d += combat_status_total(player, "vulnerable");
    _d = max(0, _d - player.damage_reduction);
    _d = max(1, _d - player.equip_armor);
    if (dtype == 0 && variable_struct_exists(player, "derived") && player.derived.phys_dmg_reduction > 0) {
        _d = max(1, ceil(_d * (1.0 - (player.derived.phys_dmg_reduction / 100.0))));
    }
    // Warding boon: flat % incoming-damage reduction.
    if (boon_active("warding")) _d = max(1, round(_d * boon_incoming_mult()));
    // Curse penalties (Exposed/Ruin): flat % incoming-damage increase.
    if (curse_incoming_mult() != 1.0) _d = max(1, round(_d * curse_incoming_mult()));
    if (variable_struct_exists(player, "shield_hp") && player.shield_hp > 0 && _d > 0) {
        var _sa = min(player.shield_hp, _d);
        player.shield_hp -= _sa;
        _d -= _sa;
        array_push(log, "Soul Shield absorbs " + string(_sa) + " damage.");
    }
    return _d;
}

// combat_absorb_shield(c, dmg) - depletes a `shield_hp` pool (Soul Shield) before
// HP. Returns the damage remaining after absorption.
function combat_absorb_shield(c, dmg) {
    if (!variable_struct_exists(c, "shield_hp") || c.shield_hp <= 0) return dmg;
    var _absorb = min(c.shield_hp, dmg);
    c.shield_hp -= _absorb;
    return dmg - _absorb;
}

// =============================================================================
// ENEMY SFX - family-themed death/attack sounds (see SYSTEMS_ENEMY_SFX.md)
// Every enemy used to play the same human death yell (die5). These helpers map an
// enemy NAME -> a "sound family" by keyword, then play a family-specific sound.
// Each family has a PREFERRED sound name (a string, e.g. "snd_death_fire") resolved
// at runtime: if that audio asset exists it plays, otherwise we fall back to a
// best-fit sound from the existing library. So new audio the user adds in the IDE
// (named per the convention below) activates with NO code change - drop in
// snd_death_<family> / snd_attack_<family> and it's picked up automatically.
// Families: undead - wraith - construct - beast - fire - ice - boss.
// =============================================================================

// enemy_sound_family(name) - keyword-classify an enemy name into a sound family.
// First match wins (priority handles overlaps like "Smoldering Revenant" -> wraith).
function enemy_sound_family(name) {
    var _n = string_lower(name);
    if (string_pos("malgrath", _n) || string_pos("sovereign", _n) || string_pos("eternal frost", _n))
        return "boss";
    if (string_pos("wraith", _n) || string_pos("specter", _n) || string_pos("spectre", _n)
        || string_pos("revenant", _n) || string_pos("archivist", _n) || string_pos("ghost", _n))
        return "wraith";
    if (string_pos("golem", _n) || string_pos("colossus", _n) || string_pos("sentinel", _n)
        || string_pos("guardian", _n) || string_pos("stone", _n))
        return "construct";
    if (string_pos("imp", _n) || string_pos("drake", _n) || string_pos("slug", _n)
        || string_pos("crawler", _n) || string_pos("stalker", _n) || string_pos("lurker", _n)
        || string_pos("beast", _n))
        return "beast";
    if (string_pos("cinder", _n) || string_pos("magma", _n) || string_pos("lava", _n)
        || string_pos("ash", _n) || string_pos("infernal", _n) || string_pos("smolder", _n)
        || string_pos("ember", _n) || string_pos("flame", _n) || string_pos("fire", _n))
        return "fire";
    if (string_pos("frost", _n) || string_pos("ice", _n) || string_pos("glacial", _n)
        || string_pos("frozen", _n) || string_pos("snow", _n) || string_pos("pale", _n)
        || string_pos("shard", _n))
        return "ice";
    return "undead";
}

// play_sfx_var(base, fallback) - play a RANDOM existing variation of a string-named
// sound. Probes `base`, `base_2`, `base_3`; if any are imported it plays one at
// random (so repeated swings/casts don't sound identical), else the existing-library
// `fallback`. Pass fallback = -1 for "silence if not imported". Safe pre-strip: while
// no snd_* assets exist this always uses the fallback. New imported sounds must also
// be bare-listed in audio_sfx_assets() (scr_stats) or the build strips them.
function play_sfx_var(base, fallback) {
    var _names = [base, base + "_2", base + "_3"];
    var _cands = [];
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _s = asset_get_index(_names[_i]);
        if (_s != -1 && audio_exists(_s)) array_push(_cands, _s);
    }
    if (array_length(_cands) > 0) {
        audio_play_sound(_cands[irandom(array_length(_cands) - 1)], 1, false);
        return;
    }
    if (fallback != -1 && fallback != undefined) audio_play_sound(fallback, 1, false);
}

// play_player_vocal(base, fallback) - like play_sfx_var but prefers the FEMALE
// variant set (<base>_f, _f_2, _f_3) when the player's cosmetic gender is female, so
// a female character cries out / grunts differently. Falls back to the base set, then
// the library fallback. Use for the player's own voice (hurt/effort), not weapon FX.
function play_player_vocal(base, fallback) {
    if (variable_global_exists("player_gender") && global.player_gender == "f") {
        var _fnames = [base + "_f", base + "_f_2", base + "_f_3"];
        var _fcands = [];
        for (var _i = 0; _i < array_length(_fnames); _i++) {
            var _s = asset_get_index(_fnames[_i]);
            if (_s != -1 && audio_exists(_s)) array_push(_fcands, _s);
        }
        if (array_length(_fcands) > 0) {
            audio_play_sound(_fcands[irandom(array_length(_fcands) - 1)], 1, false);
            return;
        }
    }
    play_sfx_var(base, fallback);
}

// play_enemy_sfx(preferred_name, fallback_snd) - themed enemy sound with variation
// support (delegates to play_sfx_var). Safe pre-strip: uses fallback until imported.
function play_enemy_sfx(preferred_name, fallback_snd) {
    play_sfx_var(preferred_name, fallback_snd);
}

// enemy_death_sound(name) - themed death sound for an enemy.
function enemy_death_sound(name) {
    var _f = enemy_sound_family(name);
    var _fb;
    switch (_f) {
        case "wraith":    _fb = teleport; break;   // ethereal fade
        case "construct": _fb = grunt;    break;   // heavy crumble
        case "beast":     _fb = grunt;    break;   // animal grunt
        case "fire":      _fb = Magic;    break;   // sizzle/whoosh
        case "ice":       _fb = teleport; break;   // shatter-ish
        case "boss":      _fb = die5;     break;   // loud yell
        default:          _fb = die5;     break;   // undead
    }
    play_enemy_sfx("snd_death_" + _f, _fb);
}

// enemy_attack_sound(name) - themed attack/cast sound for an enemy's offensive action.
function enemy_attack_sound(name) {
    var _f = enemy_sound_family(name);
    var _fb;
    switch (_f) {
        case "wraith":    _fb = Magic;   break;
        case "construct": _fb = attack1; break;
        case "beast":     _fb = grunt;   break;
        case "fire":      _fb = Magic;   break;
        case "ice":       _fb = spell1;  break;
        case "boss":      _fb = grunt;   break;
        default:          _fb = attack1; break;   // undead
    }
    play_enemy_sfx("snd_attack_" + _f, _fb);
}

// play_ability_cast_sfx(ab, caster, is_offensive) - PLAYER cast audio keyed to the
// ABILITY (damage type + effect kind) instead of the caster's class, so a fireball and a
// shadowbolt sound different no matter who throws them. See SYSTEMS_COMBAT_FX.md.
// The specific asset picks are a first-draft best-guess (sounds weren't auditioned) -
// each is a single-line swap. Called from obj_combat_controller's offensive-hit + self-
// cast sites. Movement casts (Blink/Shadow Step) keep their own `teleport` cue upstream.
function play_ability_cast_sfx(ab, caster, is_offensive) {
    var _etype = variable_struct_exists(ab, "effect_type") ? ab.effect_type : "";
    var _dtype = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;

    if (!is_offensive) {
        // Support cast - keyed to what it grants. New snd_cast_* slots (Helton Yan
        // pack) with the old library sounds as fallbacks until imported.
        switch (_etype) {
            case "heal":     play_sfx_var("snd_cast_heal",   Magic);               break; // bright twinkle
            case "shield":   play_sfx_var("snd_cast_shield", Success_1__subtle_);  break; // defensive ward
            case "resource": play_sfx_var("snd_cast_buff",   utility2);            break; // arcane gain
            case "debuff":   play_sfx_var("snd_cast_debuff", Harp_2__Descending_); break; // ominous
            default:         play_sfx_var("snd_cast_buff",   utility2);            break; // generic self-buff
        }
        return;
    }

    // Offensive cast - texture by damage type (0 phys - 1 elem - 2 drain/void - 3 blood).
    switch (_dtype) {
        case 0:  play_player_vocal("snd_player_atk", attack1); break;         // human weapon strike (gendered)
        case 1:  play_sfx_var("snd_cast_elem",  spell1);  break;             // elemental cast
        case 2:  play_sfx_var("snd_cast_void",  Obscure); break;             // dark whoosh
        case 3:  play_sfx_var("snd_cast_blood", grunt);
                 audio_play_sound(attack1, 1, false); break;                 // blood (visceral)
        default: play_sfx_var("snd_cast_arcane", Strings_1);                 // arcane / other
    }
    // Class flavor: the Bloodwarden grunts with effort on physical strikes.
    if (variable_struct_exists(caster, "class_id") && caster.class_id == 1 && _dtype == 0) {
        audio_play_sound(grunt, 1, false);
    }
}

// combat_on_enemy_defeated(target, player, combat_log) - shared kill handler:
// gold, loot, XP, on-kill soul generation, and Heartstone Aegis. Called by both
// the single-target and AoE damage paths so kill rewards never diverge.
function combat_on_enemy_defeated(target, player, combat_log) {
    target.is_defeated = true;
    enemy_death_sound(target.name);
    array_push(combat_log, target.name + " defeated!");

    // Gold drop (Greed boon: +50%; curse gold-find reward stacks on top)
    var _gold_drop = irandom(target.gold_max - target.gold_min) + target.gold_min;
    if (boon_active("greed")) _gold_drop = round(_gold_drop * (1 + boon_value("greed")));
    _gold_drop = round(_gold_drop * curse_gold_mult());
    add_gold(_gold_drop);
    global.current_run_kills++;
    array_push(combat_log, "Gained " + string(_gold_drop) + "g!");

    // Item / consumable drop
    var _drop_type = variable_global_exists("next_enemy_type") ? global.next_enemy_type : "standard";
    var _drop_result = handle_enemy_drops(_drop_type);
    if (_drop_result != "") array_push(combat_log, "Loot: " + _drop_result + "!");

    // Devil's Pact curse: a guaranteed bonus equipment drop from every elite & boss.
    if (curse_has_bonus_drops() && (_drop_type == "elite" || _drop_type == "boss")) {
        var _bonus_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) + curse_loot_asc_bonus();
        var _bonus_item = drop_equipment(drop_weights(_drop_type, _bonus_asc));
        if (variable_global_exists("run_items_found")) array_push(global.run_items_found, _bonus_item);
        if (variable_global_exists("carried_items"))   array_push(global.carried_items, _bonus_item);
        discover_item(item_base_name(_bonus_item));
        array_push(combat_log, "Devil's Pact: " + _bonus_item.name + " [" + item_rarity_name(_bonus_item.rarity) + "]!");
    }

    // XP grant (floor-scaled)
    var _xp_base  = variable_struct_exists(target, "xp_value") ? target.xp_value : 10;
    var _xp_floor = variable_global_exists("current_floor") ? global.current_floor : 1;
    var _xp_scale = (_xp_floor == 2) ? 1.25 : ((_xp_floor >= 3) ? 1.5 : 1.0);
    var _xp_amt   = round(_xp_base * _xp_scale);
    var _xp_lvls  = grant_xp(_xp_amt);
    array_push(combat_log, "Gained " + string(_xp_amt) + " XP!");
    if (_xp_lvls > 0) {
        audio_play_sound(Chimes__Ascending_, 1, false);
        array_push(combat_log, "LEVEL UP! Now level " + string(global.run_level) + ".");
    }

    // On-kill soul generation (Arcanist)
    if (player.class_id == 0 && variable_struct_exists(player, "souls")) {
        player.souls = min(player.souls_max, player.souls + 2);
        array_push(combat_log, "Soul Harvest: gained 2 Souls.");
    }
    if (player.class_id == 0 && variable_struct_exists(player, "souls") && trait_active("Soul Siphon")) {
        player.souls = min(player.souls_max, player.souls + 1);
        array_push(combat_log, "Soul Siphon: +1 Soul.");
    }

    // Vampirism boon: heal a flat amount on each kill
    if (boon_active("vampirism")) {
        var _vh = min(boon_value("vampirism"), player.max_HP - player.HP);
        if (_vh > 0) {
            player.HP += _vh;
            array_push(combat_log, "Vampirism: +" + string(_vh) + " HP.");
        }
    }

    // Heartstone Aegis: heal 5 HP on enemy death
    if (variable_struct_exists(player, "heartstone_aegis") && player.heartstone_aegis) {
        var _aegis_heal = min(5, player.max_HP - player.HP);
        if (_aegis_heal > 0) {
            player.HP += _aegis_heal;
            array_push(combat_log, "Heartstone Aegis: +" + string(_aegis_heal) + " HP.");
        }
    }

    // Serpent's Reach (class weapon): killing an enemy refunds 1 AP.
    if (variable_struct_exists(player, "kill_ap_refund") && player.kill_ap_refund) {
        player.energy += 1;
        array_push(combat_log, "Serpent's Reach - kill restores 1 AP.");
    }
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
//    1  - all enemies defeated (player wins)
//   -1  - player combatant defeated (player loses)
//    0  - combat is still ongoing
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
