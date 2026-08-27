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

    // INITIATIVE V1 (08-13, M-locked): player initiative = 10 + DEX/2; enemies
    // carry a family speed (enemy_speed, scr_enemies). Sort descending; ties
    // break DEX then WIS descending (the old pure-DEX order survives as the
    // tiebreak). High-DEX players almost always open; slow bosses reliably
    // close the round; a stalker can genuinely jump a lead-footed Soulrender.
    for (var i = 0; i < count; i++) {
        var c0 = combatant_array[i];
        c0.initiative = c0.is_player ? (10 + c0.stats.DEX / 2) : enemy_speed(c0.name);
    }
    var sorted = array_create(count);
    array_copy(sorted, 0, combatant_array, 0, count);

    for (var i = 1; i < count; i++) {
        var key = sorted[i];
        var j   = i - 1;
        while (j >= 0) {
            var cmp_ini = sorted[j].initiative - key.initiative;
            var cmp_dex = sorted[j].stats.DEX - key.stats.DEX;
            var cmp_wis = sorted[j].stats.WIS - key.stats.WIS;
            // Advance j if the slot ahead has lower priority than key
            if (cmp_ini < 0 || (cmp_ini == 0 && (cmp_dex < 0 || (cmp_dex == 0 && cmp_wis < 0)))) {
                sorted[j + 1] = sorted[j];
                j--;
            } else {
                break;
            }
        }
        sorted[j + 1] = key;
    }

    // Deadweight (deepclaw signature move, 08-06): the swiftest foe takes the
    // load - it is re-sorted to the very bottom of the order for this combat.
    // The moved enemy is flagged so Create can log the line once the combat log
    // exists (this runs before it does).
    if (pet_active_sig_move("deadweight")) {
        var _dw_idx = -1;
        for (var i = 0; i < count; i++) {
            if (!sorted[i].is_player) { _dw_idx = i; break; }
        }
        if (_dw_idx >= 0 && _dw_idx < count - 1) {
            var _dw = sorted[_dw_idx];
            array_delete(sorted, _dw_idx, 1);
            array_push(sorted, _dw);
            _dw.sig_deadweight_moved = true;
        }
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
                c.trap_active     = false;   // legacy flag, kept for old save shapes
                c.traps            = [];     // deployed traps (08-08 rework)
                break;
        }
    }

    return {
        combatants:   sorted,          // initiative-ordered array
        turn_index:   0,               // index of the combatant currently acting
        round:        1,               // increments each time the queue wraps
        active:       sorted[0],       // convenience reference to current actor
        // Board challenge templates (BOARD_REQUESTS_SPEC.md §6): set during the
        // fight, read once at the victory block (flawless_fight / clean_fight).
        player_took_damage: false,
        used_consumable:    false,
    };
}

// ---------------------------------------------------------------------------
// combat_next_turn(combat_state)
// Advances to the next combatant in initiative order.
// Restores energy to 3, increments round counter when the queue wraps.
// Handles Shadowstrider Preparation generation.
// Returns the updated combat_state (same reference).
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// actor_turn_ap(actor)
// AP restored at the start of this actor's turn. Base 3 for everyone; the
// Bloodwarden Relentless trait (M 07-16) raises the player's base to 4.
// Single source of truth - the HUD pips and turn refill both read it.
// ---------------------------------------------------------------------------
function actor_turn_ap(actor) {
    if (actor.is_player && actor.class_id == 1 && trait_active("Relentless")) return 4;
    return 3;
}

function combat_next_turn(combat_state) {
    var count = array_length(combat_state.combatants);

    // Relentless potency r2/r4 (POTENCY V2): unspent AP carries to the player's
    // next turn (1 at rank 2, 2 at rank 4). Banked as the player's turn ends.
    var _out = combat_state.active;
    if (is_struct(_out) && variable_struct_exists(_out, "is_player") && _out.is_player) {
        var _rl_r = trait_potency_r14("Relentless");
        var _rl_c = (_rl_r >= 4) ? 2 : ((_rl_r >= 2) ? 1 : 0);
        if (_rl_c > 0 && _out.class_id == 1) _out.relentless_carry = min(_out.energy, _rl_c);
        // Patient Strike (mire_heron innate, 08-06): remember whether this player
        // turn ended with its full AP untouched (compared to the recorded turn-start
        // allotment, so bonus-AP turns still read correctly). First turn of a combat
        // has no "last turn" - the flag starts absent and reads false at the crit roll.
        _out.spent_no_ap_last_turn = (variable_struct_exists(_out, "turn_start_energy")
                                      && _out.energy >= _out.turn_start_energy);
    }

    combat_state.turn_index++;
    if (combat_state.turn_index >= count) {
        combat_state.turn_index = 0;
        combat_state.round++;
    }

    var actor = combat_state.combatants[combat_state.turn_index];
    combat_state.active = actor;

    // Fully restore energy at the start of each turn (Relentless raises the
    // player's base to 4 - see actor_turn_ap).
    actor.energy = actor_turn_ap(actor);
    if (actor.is_player && variable_struct_exists(actor, "relentless_carry") && actor.relentless_carry > 0) {
        actor.energy += actor.relentless_carry;
        actor.relentless_carry = 0;
    }

    // Ley Tap TRANSCEND "Ley Torrent" (POTENCY V2): the bonus AP returns every
    // 3rd round (round 4, 7, 10... - round 1's came from combat start).
    if (actor.is_player && actor.class_id == 0 && trait_transcended("Ley Tap")
        && combat_state.round > 1 && ((combat_state.round - 1) mod 3) == 0) {
        actor.energy += 1;
    }

    // Galvanize (D§4, M-approved 07-09): a killing blow last turn banked +1 AP.
    if (actor.is_player && variable_struct_exists(actor, "galvanize_ap") && actor.galvanize_ap > 0) {
        actor.energy += actor.galvanize_ap;
        actor.galvanize_ap = 0;
    }

    // Tundra Tomb floor passive: the pending chill docks AP from the player's FIRST
    // turn of this combat (set in obj_combat_controller Create; never below 1 AP).
    if (actor.is_player && variable_struct_exists(actor, "chill_ap_penalty") && actor.chill_ap_penalty > 0) {
        actor.energy = max(1, actor.energy - actor.chill_ap_penalty);
        actor.chill_ap_penalty = 0;
    }

    // Shadowstrider gains 1 Preparation at turn start when NO trap is deployed.
    // This rule was meaningless while traps fired on cast (nothing ever persisted);
    // with deployed traps it becomes the class's core tension - an empty board
    // refills faster, so over-committing the board starves your Prep (08-08).
    if (actor.is_player && actor.class_id == 2) {
        var _tp_deployed = variable_struct_exists(actor, "traps") && is_array(actor.traps)
                           && array_length(actor.traps) > 0;
        if (!_tp_deployed) {
            actor.preparation = min(actor.preparation + 1, actor.preparation_max);
        }
        // Coiled Patience trunk node (P2, 08-05): starting a turn at max Prep
        // grants +1 AP. Checked AFTER the passive gain so a turn that fills the
        // tank counts - full readiness, rewarded.
        if (trunk_has("prep_max_ap") && actor.preparation >= actor.preparation_max) {
            actor.energy += 1;
        }
    }

    // Patient Strike bookkeeping: the turn's true starting allotment, recorded
    // AFTER every bonus/penalty above so the end-of-turn comparison is exact.
    if (actor.is_player) actor.turn_start_energy = actor.energy;

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
//   2 - Arcane    (INT): chance = base + INT*1,    multiplier 1.35x + 2 elemental stacks
//   3 - Effect    (WIS): chance = 5 + WIS*1.5,     improves status quality + 1.1x damage
// (Crit polish, batch A 08-26 M-locked: Arcane 1.25 -> 1.35 so INT casters get real
// value from crit gear; Effect crits now also carry a +10% damage tick so WIS crit
// affixes are never dead weight on damaging casts.)
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
    // Typed crit gear (07-31): STR/DEX (Power/Precision) rolls take phys crit,
    // INT/WIS (Arcane/Effect) rolls take spell crit. Enemies carry neither.
    if (crit_type <= 1) {
        if (variable_struct_exists(attacker_stats, "crit_phys_bonus"))  chance += attacker_stats.crit_phys_bonus;
    } else {
        if (variable_struct_exists(attacker_stats, "crit_spell_bonus")) chance += attacker_stats.crit_spell_bonus;
    }
    // Duelist's Iron Pin relic (08-11, #23): +15 crit while the fight is
    // HONEST - exactly one living enemy. Only player rolls reach here.
    if (legendary_worn("duel_pin") && instance_exists(obj_combat_controller)) {
        var _dp_cs = instance_find(obj_combat_controller, 0).combat_state;
        var _dp_n  = 0;
        for (var _dp_i = 0; _dp_i < array_length(_dp_cs.combatants); _dp_i++) {
            var _dp_e = _dp_cs.combatants[_dp_i];
            if (!_dp_e.is_player && !_dp_e.is_defeated) _dp_n++;
        }
        if (_dp_n == 1) chance += 15;
    }

    if (irandom(99) >= chance) return result; // no crit

    // Achievement counter (08-05 wiring): lifetime crits. Only player ability
    // rolls reach this function (enemies never call it), so no attacker gate.
    ach_counters_init();
    global.ach_counters.crits += 1;

    result.critted = true;

    switch (crit_type) {
        case 0: // Power - raw damage spike
            result.multiplier = 1.6;
            break;
        case 1: // Precision - moderate multiplier
            result.multiplier = 1.35;
            break;
        case 2: // Arcane - matches Precision's multiplier AND adds elemental stacks
            result.multiplier      = 1.35;   // batch A 08-26: was 1.25
            result.bonus_el_stacks = 2;
            break;
        case 3: // Effect - improves applied status quality + a modest damage tick
            result.multiplier     = 1.10;    // batch A 08-26: was 1.0 (pure utility)
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
// combat_enemy_slot_pos(idx) - the SINGLE source for where the idx-th living
// enemy stands and how big it draws. Flat: the shipped row, byte-identical.
// 2.5D v3 (M 08-13, Paper Mario staging): slot 0 is the BACK of the lane -
// highest on the floor plane, smallest - and each slot steps nearer, lower and
// bigger, drifting left toward the player. Draw sprites, attack-animation
// sources, projectile spawns and VFX centers all read THIS so they can never
// disagree about depth. y is the sprite TOP-LEFT (97px canvas), feet the
// ground line, cx/cy the visual center.
// ---------------------------------------------------------------------------
function combat_enemy_slot_pos(_idx) {
    var _s, _x, _y;
    if (combat_25d()) {
        // Round 5 (M: "they seem to always arrange in the same pattern... a
        // diagonal line with no sizing difference"). Two changes:
        //  1. FOUR layout patterns, one rolled per combat (stage_layout,
        //     stamped in Create) - encounters stop looking identical.
        //  2. COUNT-AWARE station picks: a 2-enemy fight takes one FAR and one
        //     NEAR station (never two mid ones), a 3-fight spans the full
        //     depth range - every encounter is guaranteed a big/small size
        //     contrast. Stations are stored far->near, and picks preserve
        //     that order, so draw order stays painter's order and near foes
        //     still overlap far ones.
        // Round 6: every NEAR station (feet >= 800) now sits LEFT of the
        // ability tooltip zone (x >= ~1395, y 655+) - M's Archivist stood dead
        // on top of the box. Mid-right stations keep their feet above it.
        // Round 10 (M shot: "you over did where enemies and allies are, its so
        // disorganized... way too all over the place and sloppy"). ORGANIZED
        // FORMATIONS, classic JRPG sides:
        //  - ALLIES hold the bottom-left wedge (player front at y726, pet
        //    tucked BEHIND-LEFT of him - see Draw_64; it had drifted into the
        //    middle of the field).
        //  - ENEMIES hold a clean RIGHT-SIDE wedge: every station x >= ~1015,
        //    every sprite bottoms out ABOVE the UI band (feet <= ~724, card
        //    top is y735) - nothing stands behind the log or the card
        //    anymore. Depth reads through scale (2.4 far -> 3.2 front) +
        //    feet height + shadows, not through scatter.
        //  - Rows still zigzag WITHIN the wedge and the 3-pick keeps the
        //    triangle, so fights don't stage identically - but always as one
        //    coherent opposing formation.
        // (M mid-round: "you're not making the enemy sprites small enough -
        // you're forcing them to be too big") - whole range shrunk: far ~1.9
        // (185px) -> front ~2.6 (252px). The player at ~385px is the near-
        // camera anchor; enemies read across the field, not in your face.
        // Round 12 (M: "enemies are now too big... FORCED PERSPECTIVE, it
        // really shouldnt be this dramatic"): subtle gradient - far ~165px to
        // front ~204px. Small enough that the 97px art stays clean (~2x).
        // Round 13 (M: "enemies are still too big"): another step down -
        // far ~145px to front ~180px, barely above native art size.
        // 08-16 (M: "forced perspective still a bit overtuned... doesn't make
        // sense why that slot is the biggest"): gradient flattened once more,
        // far ~151px to front ~167px (~10% spread). Depth now reads mostly
        // through feet height + shadows; SIZE is driven by the species' rank
        // (enemy_size_mult: Elite/Boss over trash), not by which slot it drew.
        // 08-18 (M shot "mobs overlapping on each other"): with the flat size gradient
        // the old near/far pairs 40-115px apart in x just read as clutter - every
        // layout now keeps >= 200px between ANY two station x's (sprites run ~110-150px
        // wide), still zigzagging feet 540-705 inside the right-side wedge (x >= 1000).
        static _t25_pat = [
            [[1660,545,1.56],[1200,608,1.61],[1430,662,1.67],[1000,700,1.72]],
            [[1300,540,1.56],[1700,615,1.62],[1050,648,1.66],[1500,702,1.72]],
            [[1700,552,1.57],[1080,600,1.60],[1480,660,1.67],[1280,702,1.72]],
            [[1500,548,1.56],[1080,618,1.61],[1700,665,1.67],[1290,700,1.71]]
        ];
        static _t25_pick = [ [2], [0,3], [0,1,3], [0,1,2,3] ];
        var _lay = 0;
        var _cnt = 4;
        if (instance_exists(obj_combat_controller)) {
            var _pcc = instance_find(obj_combat_controller, 0);
            if (variable_instance_exists(_pcc, "stage_layout")) _lay = _pcc.stage_layout;
            if (variable_instance_exists(_pcc, "combat_state") && is_struct(_pcc.combat_state))
                _cnt = array_length(combat_living_enemies(_pcc.combat_state));
        }
        var _pat = _t25_pat[clamp(_lay, 0, 3)];
        var _map = _t25_pick[clamp(_cnt, 1, 4) - 1];
        var _st;
        if (_idx < array_length(_map)) {
            _st = _pat[_map[_idx]];
            _s = _st[2]; _x = _st[0];
            _y = _st[1] - 97 * _s;
        } else {
            // Overflow (5th+): fan left along the near row, clamped clear of
            // the player's ground (x < ~470 would draw over the hero pair).
            _st = _pat[3];
            _s = _st[2];
            _x = max(470, _st[0] - (_idx - 3) * 150);
            _y = _st[1] - 97 * _s;
        }
        return { x: _x, y: _y, scale: _s, feet: _y + 97 * _s, cx: _x + 48.5 * _s, cy: _y + 48.5 * _s };
    }
    _s = 3;
    _x = 1665 - _idx * 174;
    _y = 225 + _idx * 36 + ((_idx % 2 == 0) ? -36 : 36);
    return { x: _x, y: _y, scale: _s, feet: _y + 291, cx: _x + 145.5, cy: _y + 145.5 };
}

// ---------------------------------------------------------------------------
// STAT RESISTS (M 08-16: "constitution should affect certain resists like
// poison and stun (very minor)... pepper this in for other stats like wisdom").
// Per stat POINT 0.5%, capped 15% - a nudge, not a wall:
//   CON -> Poison/Burn DoT damage taken (-%), and a chance to SHRUG a Stun
//   WIS -> chance to shrug Silence / Weaken
//   DEX -> chance to shrug Root
// combat_stat_resist_pct(c, key) returns the % (0..15) the combatant has for
// "dot" / "stun" / "silence" / "weaken" / "root"; anything else = 0.
// ---------------------------------------------------------------------------
function combat_stat_resist_pct(_c, _key) {
    if (!is_struct(_c) || !variable_struct_exists(_c, "stats")) return 0;
    var _s = _c.stats, _pts = 0;
    switch (_key) {
        case "dot": case "stun":       _pts = variable_struct_exists(_s, "CON") ? _s.CON : 0; break;
        case "silence": case "weaken": _pts = variable_struct_exists(_s, "WIS") ? _s.WIS : 0; break;
        case "root":                   _pts = variable_struct_exists(_s, "DEX") ? _s.DEX : 0; break;
        default: return 0;
    }
    return clamp(_pts * 0.5, 0, 15);
}

// ---------------------------------------------------------------------------
// combat_enemy_model(_ec, _map) - the sprite THIS combatant wears (M 08-16
// variety: species with several models - enemy_sprite_variants - draw a
// random one per foe, preferring a model no other LIVING same-name foe on the
// field already has). The pick is stamped as a variant INDEX (_ec.model_var)
// on first sight and resolved through the pool each call, so a resumed run or
// a re-ordered asset table can never point at the wrong sprite. Falls back to
// the map's primary; -1 when the species has no model at all.
// ---------------------------------------------------------------------------
function combat_enemy_model(_ec, _map) {
    if (!variable_struct_exists(_map, _ec.name)) return -1;
    var _pool = enemy_sprite_variants(_ec.name);
    var _n = array_length(_pool);
    if (_n <= 1) return variable_struct_get(_map, _ec.name);
    if (!variable_struct_exists(_ec, "model_var") || _ec.model_var < 0 || _ec.model_var >= _n) {
        // Awakening-tiered species (bosses like Malgrath) take a fixed model per tier.
        var _awk_m = enemy_model_for_awakening(_ec.name,
            variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
        if (_awk_m >= 0 && _awk_m < _n) { _ec.model_var = _awk_m; return _pool[_awk_m]; }
        var _used = [];
        if (instance_exists(obj_combat_controller)) {
            var _cc = instance_find(obj_combat_controller, 0);
            if (variable_instance_exists(_cc, "combat_state") && is_struct(_cc.combat_state)) {
                var _cs = _cc.combat_state.combatants;
                for (var _i = 0; _i < array_length(_cs); _i++) {
                    var _o = _cs[_i];
                    if (_o == _ec || _o.is_player || _o.is_defeated) continue;
                    if (_o.name == _ec.name && variable_struct_exists(_o, "model_var")) array_push(_used, _o.model_var);
                }
            }
        }
        var _free = [];
        for (var _k = 0; _k < _n; _k++) {
            var _taken = false;
            for (var _u = 0; _u < array_length(_used); _u++) if (_used[_u] == _k) { _taken = true; break; }
            if (!_taken) array_push(_free, _k);
        }
        _ec.model_var = (array_length(_free) > 0) ? _free[irandom(array_length(_free) - 1)] : irandom(_n - 1);
    }
    return _pool[_ec.model_var];
}

// ---------------------------------------------------------------------------
// sprite_true_bounds(spr) - MEASURED opaque-pixel bounds of frame 0, cached.
// (M 08-13: "the shadows are miles away from the sprites... fix immediately.")
// Every 2.5D anchoring bug traced back to trusting .yy bbox metadata, which
// lies for full-image bbox modes and stray semi-transparent pixels. This
// draws the frame once to a surface, scans the pixels (alpha > 24 counts, so
// faint strays are ignored), and caches {l,t,r,b,w,h} per sprite. One-time
// cost per sprite (~10-60k byte reads), then free.
// ---------------------------------------------------------------------------
function sprite_true_bounds(_spr) {
    if (!variable_global_exists("__true_bounds_cache")) global.__true_bounds_cache = {};
    var _key = string(_spr);
    if (variable_struct_exists(global.__true_bounds_cache, _key))
        return variable_struct_get(global.__true_bounds_cache, _key);
    var _w = sprite_get_width(_spr), _h = sprite_get_height(_spr);
    var _res = { l: 0, t: 0, r: _w - 1, b: _h - 1, w: _w, h: _h };   // fallback: full canvas
    var _sf = surface_create(_w, _h);
    if (surface_exists(_sf)) {
        surface_set_target(_sf);
        draw_clear_alpha(c_black, 0);
        draw_sprite_ext(_spr, 0, sprite_get_xoffset(_spr), sprite_get_yoffset(_spr), 1, 1, 0, c_white, 1);
        surface_reset_target();
        var _buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
        buffer_get_surface(_buf, _sf, 0);
        surface_free(_sf);
        var _l = _w, _t = _h, _r = -1, _b = -1;
        for (var _y = 0; _y < _h; _y++) {
            var _row = _y * _w;
            for (var _x = 0; _x < _w; _x++) {
                if (buffer_peek(_buf, (_row + _x) * 4 + 3, buffer_u8) > 24) {
                    if (_x < _l) _l = _x;
                    if (_x > _r) _r = _x;
                    if (_y < _t) _t = _y;
                    _b = _y;
                }
            }
        }
        buffer_delete(_buf);
        if (_r >= 0) _res = { l: _l, t: _t, r: _r, b: _b, w: _r - _l + 1, h: _b - _t + 1 };
    }
    variable_struct_set(global.__true_bounds_cache, _key, _res);
    return _res;
}

// ---------------------------------------------------------------------------
// combat_player_vfx_anchor(player) - TOP-LEFT anchor for a ~220px one-shot
// burst centred on the player's torso. Flat mode returns the shipped tuned
// literal (330,360) so nothing moves; 2.5D derives it from the live player
// anchor (x282+layout*14, visible feet on the y726 ground line, ~385px tall)
// so self-cast / incoming-hit VFX land ON the hero, not on the flat-mode spot
// (M 08-13: "VFX ... have appeared to be off target").
// ---------------------------------------------------------------------------
function combat_player_vfx_anchor(_player) {
    if (!combat_25d()) return { x: 330, y: 360 };
    // Round 12 (M: "VFX should be bound to player sprite location"): read the
    // live centre STAMPED by the combat Draw each frame - never re-derive.
    if (variable_global_exists("player_stage_cx")) {
        return { x: global.player_stage_cx - 110, y: global.player_stage_cy - 110 };
    }
    return { x: 330, y: 400 };   // first-frame fallback before any stamp
}

// ---------------------------------------------------------------------------
// combat_living_enemies(combat_state)
// Returns an array of the still-standing enemy combatants in turn order. The
// same ordering the HP-bar grid and selected_target index use.
// ---------------------------------------------------------------------------
function combat_living_enemies(combat_state) {
    var _out = [];
    if (!is_struct(combat_state) || !variable_struct_exists(combat_state, "combatants")) return _out;
    for (var _i = 0; _i < array_length(combat_state.combatants); _i++) {
        var _c = combat_state.combatants[_i];
        if (!_c.is_player && !_c.is_defeated) array_push(_out, _c);
    }
    return _out;
}

// ---------------------------------------------------------------------------
// combat_estimate_hit(ability, caster, target)
// APPROXIMATE single-hit damage preview for the "[Ability] -> ~X dmg" readout.
// Mirrors the main terms of the real cast (base + damage-type stat scaling,
// armor/resist mitigation, then the truly-flat weapon component) but deliberately
// omits situational riders - crit, detonations, boon/curse multipliers, AoE
// falloff - so it stays a stable "what it'll roughly land for" number. Returns
// -1 for pure-utility abilities (base_damage 0) which deal no direct damage.
// ---------------------------------------------------------------------------
function combat_estimate_hit(ability, caster, target) {
    if (!is_struct(ability) || !variable_struct_exists(ability, "base_damage")) return -1;
    if (ability.base_damage <= 0) return -1;

    var _dtype = variable_struct_exists(ability, "damage_type") ? ability.damage_type : 0;
    var _dmg   = ability.base_damage;
    // Real-target context (combat preview) vs bare-struct context (loadout tooltip):
    // every player/target-specific component below is gated on the structs actually
    // carrying the fields, so the tooltip caller ({derived:..}, {}) skips them all.
    var _live_tgt = is_struct(target) && variable_struct_exists(target, "HP");

    // Flat riders scale by printed AP cost (x1/x1.5/x2 at 1/2/3 AP, batch A
    // 08-26) - mirrored from the live cast block so the preview matches the hit.
    var _est_frm = ability_flat_rider_mult(ability);
    if (variable_struct_exists(caster, "derived")) {
        var _d = caster.derived;
        if (_dtype == 0)      _dmg += round((_d.phys_dmg_bonus + _d.cha_dmg_bonus) * _est_frm);
        else if (_dtype == 1) _dmg += round((_d.elem_dmg_bonus + _d.cha_dmg_bonus) * _est_frm);
        else if (_dtype == 2) _dmg += round(_d.cha_dmg_bonus * _est_frm);
        else if (_dtype == 3) _dmg += round((_d.elem_dmg_bonus + _d.cha_dmg_bonus) * _est_frm);
    }

    // --- Deterministic pre-crit riders (mirror obj_combat_controller cast order) ---
    if (ability.name == "Arcane Echo" && variable_struct_exists(caster, "souls"))
        _dmg += caster.souls * 4;
    if (ability.name == "Killing Spree" && _live_tgt && variable_struct_exists(target, "status_effects"))
        _dmg += array_length(target.status_effects) * 6;
    if (ability.name == "Flurry" && _live_tgt && variable_struct_exists(target, "status_effects"))
        _dmg += array_length(target.status_effects) * 3;
    if (ability.name == "Soul Nova" && variable_struct_exists(caster, "souls"))
        _dmg += min(caster.souls, 4) * 7;
    if (ability.name == "Soul Rend" && variable_struct_exists(caster, "souls"))
        _dmg += min(caster.souls, 2) * 8;
    // Vanish ambush: primed and this is a damaging cast -> +12 on the next strike.
    if (variable_struct_exists(caster, "vanish_bonus") && caster.vanish_bonus)
        _dmg += 12;
    // Assassinate execute: doubles vs a target under 30% HP (fully deterministic).
    if (ability.name == "Assassinate" && _live_tgt && target.max_HP > 0
        && (target.HP / target.max_HP) < 0.30)
        _dmg *= 2;
    // Weaken on the caster shrinks the outgoing hit.
    if (_live_tgt && variable_struct_exists(caster, "status_effects")) {
        var _est_wk = combat_status_max(caster, "weaken");
        if (_est_wk > 0) _dmg = max(1, round(_dmg * (1 - _est_wk)));
    }

    var _armor  = (is_struct(target) && variable_struct_exists(target, "armor"))     ? target.armor     : 0;
    var _resist = (is_struct(target) && variable_struct_exists(target, "el_resist")) ? target.el_resist : 0;
    var _final;
    if (ability.name == "Flurry") {
        // Three independently-mitigated strikes (armor bites each hit).
        _final = 3 * combat_resolve_damage(max(1, round(_dmg / 3)), _dtype, _armor, _resist);
    } else {
        _final = combat_resolve_damage(_dmg, _dtype, _armor, _resist);
    }

    // --- Post-mitigation flat riders the target is carrying ---
    if (_live_tgt && variable_struct_exists(target, "status_effects")) {
        _final += combat_status_total(target, "vulnerable") + combat_status_total(target, "hexed");
        var _est_fm = combat_status_total(target, "firemark");
        if (_est_fm > 0) _final += combat_resolve_damage(_est_fm, 1, _armor, _resist);
    }

    // --- Deterministic multipliers (player-caster only; guarded for tooltip callers) ---
    if (variable_struct_exists(caster, "class_id") && variable_struct_exists(caster, "HP")) {
        if (caster.class_id == 0 && trait_active("Arcane Surge")
            && variable_struct_exists(ability, "energy_cost") && ability.energy_cost >= 3)
            _final = floor(_final * (1 + 0.25 * trait_potency_mult("Arcane Surge")));
        // Soul Engine (D§4): mirror the +3/turn flat spell bonus in the preview.
        if (variable_struct_exists(caster, "soul_engine_active") && caster.soul_engine_active
            && ability_class_is_spell(ability_attack_class(ability))
            && instance_exists(obj_combat_controller)) {
            var _se_round = variable_struct_exists(caster, "soul_engine_round") ? caster.soul_engine_round : 0;
            _final += 3 * max(0, instance_find(obj_combat_controller, 0).combat_state.round - _se_round);
        }
        // Warpath (07-16): mirror the +2/turn flat physical/Blood bonus in the preview.
        if (variable_struct_exists(caster, "warpath_active") && caster.warpath_active
            && variable_struct_exists(ability, "damage_type")
            && (ability.damage_type == 0 || ability.damage_type == 3)
            && instance_exists(obj_combat_controller)) {
            var _wp_round = variable_struct_exists(caster, "warpath_round") ? caster.warpath_round : 0;
            var _wp_rate  = variable_struct_exists(caster, "warpath_rate")  ? caster.warpath_rate  : 2;   // Crescendo (P3)
            _final += _wp_rate * max(0, instance_find(obj_combat_controller, 0).combat_state.round - _wp_round);
        }
        // Compounding Dread (07-16): mirror the accumulated trap bonus in the preview.
        if (variable_struct_exists(caster, "dread_bonus") && caster.dread_bonus > 0
            && (ability.name == "Bear Trap" || ability.name == "Spike Trap" || ability.name == "Death Snare")) {
            _final += caster.dread_bonus;
        }
        if (caster.class_id == 1 && trait_active("Berserker Rage")
            && caster.HP <= floor(caster.max_HP * (trait_transcended("Berserker Rage") ? 0.60 : 0.40)))
            _final = floor(_final * (1 + 0.20 * trait_potency_mult("Berserker Rage")));
        // Last Stand fury + Expanded Arsenal potency ranks (POTENCY V2) - both
        // mirrored here so the hit-preview matches the real hit.
        if (variable_struct_exists(caster, "last_stand_fury") && caster.last_stand_fury > 0)
            _final = max(1, floor(_final * (1 + caster.last_stand_fury)));
        var _ea_est = trait_potency_r14("Expanded Arsenal");
        if (_ea_est > 0 && variable_struct_exists(caster, "is_player") && caster.is_player)
            _final = max(1, floor(_final * (1 + 0.02 * _ea_est)));
        if (trait_transcended("Scavenger") && global.gold >= 500
            && variable_struct_exists(caster, "is_player") && caster.is_player)
            _final = max(1, floor(_final * (1 + min(0.10, 0.01 * (global.gold div 500)))));
        var _lt_est = trait_potency_r14("Ley Tap");
        if (_lt_est > 0 && caster.class_id == 0 && instance_exists(obj_combat_controller)
            && instance_find(obj_combat_controller, 0).combat_state.round == 1
            && ability_class_is_spell(ability_attack_class(ability)))
            _final = max(1, floor(_final * (1 + 0.03 * _lt_est)));
    }
    var _est_aspect = rune_aspect_damage_pct(ability);
    if (_live_tgt && _est_aspect > 0) _final = round(_final * (1 + _est_aspect));
    if (_live_tgt) {
        var _est_thf = (target.max_HP > 0) ? (target.HP / target.max_HP) : 1;
        var _est_bm  = boon_damage_mult(_est_thf, caster);
        if (_est_bm != 1.0) _final = max(1, round(_final * _est_bm));
        var _est_corr = pet_corruption_player_dmg_mult();
        if (_est_corr != 1.0) _final = max(1, round(_final * _est_corr));
    }
    if (variable_struct_exists(caster, "spell_dmg_bonus") && caster.spell_dmg_bonus > 0
        && ability_class_is_spell(ability_attack_class(ability)))
        _final = max(1, round(_final * (1 + caster.spell_dmg_bonus)));

    // Truly-flat weapon / elemental-affix / school components (each mitigated the
    // same way the real cast resolves them, instead of the old raw add).
    if (variable_struct_exists(caster, "derived")) {
        var _ac = ability_attack_class(ability);
        var _est_wf = 0;
        if (ability_class_is_melee(_ac) && variable_struct_exists(caster.derived, "melee_dmg_bonus")) {
            _est_wf = caster.derived.melee_dmg_bonus;
            if (_live_tgt && variable_struct_exists(caster.derived, "melee_elem") && caster.derived.melee_elem != undefined
                && caster.derived.melee_elem.dmg > 0)
                _final += combat_resolve_damage(caster.derived.melee_elem.dmg, 1, _armor, _resist);
        } else if (ability_class_is_ranged(_ac) && variable_struct_exists(caster.derived, "ranged_dmg_bonus")) {
            _est_wf = caster.derived.ranged_dmg_bonus;
            if (_live_tgt && variable_struct_exists(caster.derived, "ranged_elem") && caster.derived.ranged_elem != undefined
                && caster.derived.ranged_elem.dmg > 0)
                _final += combat_resolve_damage(caster.derived.ranged_elem.dmg, 1, _armor, _resist);
        }
        if (_est_wf > 0) {
            _est_wf = round(_est_wf * _est_frm);   // AP-scaled flat rider (batch A)
            _final += _live_tgt ? combat_resolve_damage(_est_wf, 0, _armor, _resist) : _est_wf;
        }
        // School-damage gear affix for this ability's school.
        if (_live_tgt && variable_struct_exists(caster.derived, "school_dmg")) {
            var _est_sch = ability_school(ability);
            if (_est_sch != "" && variable_struct_exists(caster.derived.school_dmg, _est_sch)) {
                var _est_sb = variable_struct_get(caster.derived.school_dmg, _est_sch);
                if (_est_sb > 0) _final += combat_resolve_damage(round(_est_sb * _est_frm), _dtype, _armor, _resist);
            }
        }
    }

    return max(1, round(_final));
}

// ---------------------------------------------------------------------------
// combat_apply_damage(target_struct, damage)
// Subtracts damage from target HP, clamping at 0.
// Returns the actual damage dealt (accounting for the HP floor).
// ---------------------------------------------------------------------------
function combat_apply_damage(target_struct, damage) {
    // Universal pet PWR role: an active creature's presence unsettles foes - the player
    // takes -0.5%/pt PWR damage (cap 8%). Heals (negative damage) pass untouched.
    if (damage > 0 && variable_struct_exists(target_struct, "is_player") && target_struct.is_player) {
        var _guard = pet_active_pwr_guard();
        if (_guard > 0) damage = max(1, round(damage * (1 - _guard)));
    }
    // Marked for Death (D§3 rework, M-approved 07-09): a MARKED enemy below 50%
    // max HP takes +30% from ALL sources - hits, pet strikes and DoT ticks alike.
    // Hooked here because every damage path funnels through this sink.
    if (damage > 0 && variable_struct_exists(target_struct, "is_player") && !target_struct.is_player
        && variable_struct_exists(target_struct, "status_effects")
        && variable_struct_exists(target_struct, "max_HP") && target_struct.max_HP > 0
        && target_struct.HP < target_struct.max_HP * 0.5
        && combatant_has_status_kind(target_struct, "marked")) {
        damage = round(damage * 1.30);
    }
    // OVERWHELM (combo batch, M-approved 07-16): an enemy carrying 2+ DISTINCT
    // status kinds takes +15% damage from ALL sources (hits, pet strikes, DoT
    // ticks). Core rule - hooked here because every damage path funnels through
    // this sink, same as Marked. DoTs of different elements count separately.
    if (damage > 0 && variable_struct_exists(target_struct, "is_player") && !target_struct.is_player
        && combatant_distinct_status_kinds(target_struct) >= 2) {
        damage = round(damage * 1.15);
    }
    // Stoneshadow (golemite signature move, 08-05 pillar D): the FIRST blow that
    // would drop the player below HALF HP each combat breaks against the stone
    // shadow - damage halved. Hooked here because every damage path funnels
    // through this sink; the once-flag rides the per-combat player struct.
    if (damage > 0 && variable_struct_exists(target_struct, "is_player") && target_struct.is_player
        && variable_struct_exists(target_struct, "max_HP") && target_struct.max_HP > 0
        && target_struct.HP >= target_struct.max_HP * 0.50
        && target_struct.HP - damage < target_struct.max_HP * 0.50
        && !variable_struct_exists(target_struct, "sig_stone_done")
        && pet_active_sig_move("stoneshadow")) {
        target_struct.sig_stone_done = true;
        damage = max(1, ceil(damage * 0.5));
        if (instance_exists(obj_combat_controller)) {
            array_push(instance_find(obj_combat_controller, 0).combat_log,
                "[Companion] " + pet_active().name + "'s STONESHADOW takes half the blow!");
        }
    }
    // Standing Weight (cairn_bear innate, 08-06): the FIRST damage that reaches
    // the player each combat cannot drop them below 1 HP. The flag is consumed by
    // that first arrival whether or not it was lethal - the bear takes one blow.
    // Checked BEFORE Refuse the Grave so a saved blow never spends the Blood.
    if (damage > 0 && variable_struct_exists(target_struct, "is_player") && target_struct.is_player
        && !variable_struct_exists(target_struct, "innate_weight_done")
        && pet_active_innate("last_stand") > 0) {
        target_struct.innate_weight_done = true;
        if (target_struct.HP - damage < 1) {
            damage = max(0, target_struct.HP - 1);
            if (instance_exists(obj_combat_controller)) {
                array_push(instance_find(obj_combat_controller, 0).combat_log,
                    "[Companion] " + pet_active().name + "'s STANDING WEIGHT holds you at 1 HP!");
            }
        }
    }
    // Refuse the Grave trunk node (P2, 08-05): once per combat the Bloodwarden
    // survives a killing blow at 1 HP - it costs ALL held Blood (needs at least
    // 1). Checked AFTER Stoneshadow so a halved blow that is no longer lethal
    // never wastes the reserve.
    if (damage > 0 && variable_struct_exists(target_struct, "is_player") && target_struct.is_player
        && variable_struct_exists(target_struct, "class_id") && target_struct.class_id == 1
        && variable_struct_exists(target_struct, "blood") && target_struct.blood > 0
        && target_struct.HP - damage <= 0
        && !variable_struct_exists(target_struct, "trunk_grave_done")
        && trunk_has("blood_last_stand")) {
        target_struct.trunk_grave_done = true;
        damage = max(0, target_struct.HP - 1);
        target_struct.blood = 0;
        if (instance_exists(obj_combat_controller)) {
            array_push(instance_find(obj_combat_controller, 0).combat_log,
                "REFUSE THE GRAVE - every drop of Blood spent, and you are still standing (1 HP).");
        }
    }
    // ------------------------------------------------------------------------
    // DEPTH WARDEN hooks (08-13, DESIGN §4): each Warden bends this sink its
    // own way. warden_hook is stamped at spawn (obj_combat_controller Create).
    // ------------------------------------------------------------------------
    if (damage > 0 && variable_struct_exists(target_struct, "is_player") && !target_struct.is_player
        && variable_struct_exists(target_struct, "warden_hook")
        && instance_exists(obj_combat_controller)) {
        var _wh_cc = instance_find(obj_combat_controller, 0);
        switch (target_struct.warden_hook) {
            case "nothing":
                // Nothing In Particular: untargetable every other round - blows
                // on EVEN rounds pass through a dog-shaped absence.
                if ((_wh_cc.combat_state.round mod 2) == 0) {
                    array_push(_wh_cc.combat_log, "Your blow passes through NOTHING IN PARTICULAR.");
                    damage = 0;
                }
                break;
            case "arithmetic":
                // The Long Arithmetic: damage you deal is capped at your current
                // HP - the books must balance. All your sources count.
                if (damage > _wh_cc.player.HP) {
                    array_push(_wh_cc.combat_log, "THE LONG ARITHMETIC reconciles the sum - capped at "
                        + string(_wh_cc.player.HP) + " (your HP).");
                    damage = max(1, _wh_cc.player.HP);
                }
                break;
        }
        // The First Door: its opening shield (floors cleared) eats damage first.
        if (variable_struct_exists(target_struct, "shield_hp") && target_struct.shield_hp > 0 && damage > 0) {
            var _wd_ab = min(target_struct.shield_hp, damage);
            target_struct.shield_hp -= _wd_ab;
            damage -= _wd_ab;
            array_push(_wh_cc.combat_log, "THE FIRST DOOR holds - " + string(_wd_ab) + " breaks against it"
                + ((target_struct.shield_hp <= 0) ? " and the door swings WIDE." : " ("
                    + string(target_struct.shield_hp) + " remains)."));
        }
    }
    var prev_hp         = target_struct.HP;
    target_struct.HP    = max(0, target_struct.HP - damage);
    var actual_dealt    = prev_hp - target_struct.HP;
    // DEPTH WARDEN post-damage hooks: Sister Fathom records the excess and gives
    // it back to herself; the Weight of Ironwake shifts phases as it is worn down.
    if (actual_dealt > 0 && variable_struct_exists(target_struct, "is_player") && !target_struct.is_player
        && variable_struct_exists(target_struct, "warden_hook") && target_struct.HP > 0
        && instance_exists(obj_combat_controller)) {
        var _wp_cc = instance_find(obj_combat_controller, 0);
        if (target_struct.warden_hook == "fathom" && actual_dealt > 30) {
            var _sf_back = actual_dealt - 30;
            target_struct.HP = min(target_struct.max_HP, target_struct.HP + _sf_back);
            array_push(_wp_cc.combat_log, "SISTER FATHOM records the figure - and gives "
                + string(_sf_back) + " back to herself.");
        }
        if (target_struct.warden_hook == "weight" && variable_struct_exists(target_struct, "weight_phase")) {
            var _ww_frac = target_struct.HP / target_struct.max_HP;
            var _ww_next = (_ww_frac < 1/3) ? 3 : ((_ww_frac < 2/3) ? 2 : 1);
            if (_ww_next > target_struct.weight_phase) {
                target_struct.weight_phase = _ww_next;
                target_struct.damage = round(target_struct.damage * 1.25);
                target_struct.telegraph_damage = round(target_struct.telegraph_damage * 1.25);
                array_push(_wp_cc.combat_log, "THE WEIGHT SHIFTS - phase " + string(_ww_next)
                    + ". It is heavier than it was.");
            }
        }
    }
    // Blood Tithe blessing (Shrine V2, 07-29): bank 1 gold per HP the PLAYER
    // loses, any source (hits, spells, DoT ticks all funnel through this sink).
    // The pouch pays out in end_run on extraction; death forfeits it.
    if (actual_dealt > 0 && variable_struct_exists(target_struct, "is_player")
        && target_struct.is_player && boon_active("bloodtithe")) {
        if (!variable_global_exists("bloodtithe_bank")) global.bloodtithe_bank = 0;
        global.bloodtithe_bank += actual_dealt;
    }
    // Achievement accumulator (08-05 wiring): damage the player weathered this
    // run (ACH_ABSORB_500 via sync). Counts the damage ARRIVING at this sink -
    // shield-absorbed portions never reach here, a known v1 undercount (noted
    // in ACHIEVEMENTS_SPEC.md). Reset at run end.
    if (damage > 0 && variable_struct_exists(target_struct, "is_player") && target_struct.is_player) {
        if (!variable_global_exists("ach_run_absorbed")) global.ach_run_absorbed = 0;
        global.ach_run_absorbed += damage;
    }
    // Panic Response trunk node (P2, 08-05): a hit that leaves the Bloodwarden
    // below 30% max HP grants +2 Blood - the engine roars loudest when cornered.
    if (actual_dealt > 0 && variable_struct_exists(target_struct, "is_player") && target_struct.is_player
        && variable_struct_exists(target_struct, "class_id") && target_struct.class_id == 1
        && variable_struct_exists(target_struct, "blood")
        && variable_struct_exists(target_struct, "max_HP") && target_struct.max_HP > 0
        && target_struct.HP < target_struct.max_HP * 0.30
        && trunk_has("blood_low_gain")) {
        target_struct.blood = min(target_struct.blood_max, target_struct.blood + 2);
    }
    // Overflow trunk node (P2, 08-05): overkill on a killed enemy returns +1
    // extra Soul. All player damage paths (hits, DoTs, pets) funnel through this
    // sink, so "your kills" reads as any enemy death with damage to spare.
    if (damage > actual_dealt && target_struct.HP <= 0
        && variable_struct_exists(target_struct, "is_player") && !target_struct.is_player
        && prev_hp > 0
        && trunk_has("soul_overkill")
        && instance_exists(obj_combat_controller)) {
        var _ov_pl = instance_find(obj_combat_controller, 0).player;
        if (variable_struct_exists(_ov_pl, "souls")) {
            _ov_pl.souls = min(_ov_pl.souls_max, _ov_pl.souls + 1);
        }
    }
    // Echo Shriek (crypt_bat signature move, 08-01 pillar D): the FIRST time the
    // player falls below 40% max HP each combat, the shriek lays EVERY living
    // enemy Exposed. Hooked here because every damage path funnels through this
    // sink; the once-flag rides the per-combat player struct.
    if (actual_dealt > 0 && variable_struct_exists(target_struct, "is_player") && target_struct.is_player
        && variable_struct_exists(target_struct, "max_HP") && target_struct.max_HP > 0
        && target_struct.HP < target_struct.max_HP * 0.40
        && !variable_struct_exists(target_struct, "sig_shriek_done")
        && pet_active_sig_move("echo_shriek")
        && instance_exists(obj_combat_controller)) {
        target_struct.sig_shriek_done = true;
        var _es_cc = instance_find(obj_combat_controller, 0);
        var _es_n  = 0;
        for (var _es_i = 0; _es_i < array_length(_es_cc.combat_state.combatants); _es_i++) {
            var _es_c = _es_cc.combat_state.combatants[_es_i];
            if (_es_c.is_player || _es_c.is_defeated) continue;
            if (!variable_struct_exists(_es_c, "status_effects")) continue;
            array_push(_es_c.status_effects, {
                name:         "Echo Shriek",
                effect_type:  "debuff",
                kind:         "vulnerable",
                effect_value: 2,
                duration:     2,
                element:      "",
                source:       "pet"
            });
            _es_n++;
        }
        if (_es_n > 0) array_push(_es_cc.combat_log, "[Companion] " + pet_active().name + " SHRIEKS into the dark - every foe is laid Exposed!");
    }
    // Borrowed Light (lantern_wyrm signature move, 08-06): the FIRST time the
    // player falls below 50% max HP each combat, the lantern gives back 15% of
    // max HP. Same sink hook + once-flag idiom as Echo Shriek above.
    if (actual_dealt > 0 && variable_struct_exists(target_struct, "is_player") && target_struct.is_player
        && variable_struct_exists(target_struct, "max_HP") && target_struct.max_HP > 0
        && target_struct.HP > 0 && target_struct.HP < target_struct.max_HP * 0.50
        && !variable_struct_exists(target_struct, "sig_lantern_done")
        && pet_active_sig_move("borrowed_light")) {
        target_struct.sig_lantern_done = true;
        var _bl_amt = max(1, round(target_struct.max_HP * 0.15));
        target_struct.HP = min(target_struct.max_HP, target_struct.HP + _bl_amt);
        if (instance_exists(obj_combat_controller)) {
            array_push(instance_find(obj_combat_controller, 0).combat_log,
                "[Companion] " + pet_active().name + "'s BORROWED LIGHT gives back " + string(_bl_amt) + " HP!");
        }
    }
    // Carry the One (sum_moth signature move, 08-06): the FIRST overkill on a
    // killed enemy each combat carries over to the weakest living enemy. Hooked
    // here because this sink is the only place the overkill margin is known
    // (same reasoning as the Overflow trunk node above).
    if (damage > actual_dealt && target_struct.HP <= 0 && prev_hp > 0
        && variable_struct_exists(target_struct, "is_player") && !target_struct.is_player
        && pet_active_sig_move("carry_one")
        && instance_exists(obj_combat_controller)) {
        var _co_cc = instance_find(obj_combat_controller, 0);
        if (!variable_struct_exists(_co_cc.player, "sig_carry_done")) {
            var _co_spill = damage - actual_dealt;
            var _co_tgt = undefined;
            for (var _co_i = 0; _co_i < array_length(_co_cc.combat_state.combatants); _co_i++) {
                var _co_c = _co_cc.combat_state.combatants[_co_i];
                if (_co_c.is_player || _co_c.is_defeated || _co_c == target_struct || _co_c.HP <= 0) continue;
                if (_co_tgt == undefined || _co_c.HP < _co_tgt.HP) _co_tgt = _co_c;
            }
            if (_co_tgt != undefined) {
                _co_cc.player.sig_carry_done = true;
                array_push(_co_cc.combat_log, "[Companion] " + pet_active().name + " CARRIES THE ONE - "
                    + string(_co_spill) + " spills onto " + _co_tgt.name + "!");
                combat_apply_damage(_co_tgt, _co_spill);
                _co_tgt.hit_flash = max(_co_tgt.hit_flash, 8);
                if (_co_tgt.HP <= 0 && !_co_tgt.is_defeated) {
                    combat_on_enemy_defeated(_co_tgt, _co_cc.player, _co_cc.combat_log);
                }
            }
        }
    }
    return actual_dealt;
}

// Smoke Bomb self-cover (D§3 rework, M-approved 07-09): the smoke hides YOU too -
// +15 dodge while smoke_dodge_turns > 0 (set at cast, ticked down at your turn
// start). Folded into both enemy hit rolls (primary + double strike).
function combat_smoke_dodge(player) {
    return (variable_struct_exists(player, "smoke_dodge_turns") && player.smoke_dodge_turns > 0) ? 15 : 0;
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
// awaken_hp_mult(asc) / awaken_dmg_mult(asc)
// Enemy HP / damage multipliers per Awakening tier. SINGLE SOURCE OF TRUTH -
// used by both the combat spawn scaling (obj_combat_controller Create) and the
// dungeon-select AWAKENING EFFECTS panel, so the advertised numbers can never
// drift from what combat actually applies.
// ---------------------------------------------------------------------------
// awaken_endless_mult(asc) - A6+ compounding (SYSTEMS_ENDLESS.md §2): +12% per
// tier past 5, unbounded. The Descent feeds FRACTIONAL effective tiers
// (5 + floor*0.5) through the same curve - power() handles both.
function awaken_endless_mult(asc) {
    return (asc > 5) ? power(1.12, asc - 5) : 1.0;
}

function awaken_hp_mult(asc) {
    // A4/A5 top-end bumped (C1, M-approved 07-09) alongside the behavior ladder +
    // the new Awakening XP mult - the player curve rises with it.
    var _tbl = [1.00, 1.20, 1.45, 1.75, 2.20, 2.75];
    return _tbl[clamp(asc, 0, array_length(_tbl) - 1)] * awaken_endless_mult(asc);
}
function awaken_dmg_mult(asc) {
    var _tbl = [1.00, 1.15, 1.35, 1.60, 1.90, 2.45];
    return _tbl[clamp(asc, 0, array_length(_tbl) - 1)] * awaken_endless_mult(asc);
}

// awaken_clear_gold_bonus(asc) - flat gold paid on a full-run completion at this
// tier (end_run victory path + dungeon-select panel; same single-source rule).
function awaken_clear_gold_bonus(asc) {
    var _tbl = [0, 50, 100, 150, 200, 300];
    // A6+: +60 per endless tier on top of the A5 payout.
    if (asc > 5) return 300 + 60 * round(asc - 5);
    return _tbl[clamp(asc, 0, array_length(_tbl) - 1)];
}

// awaken_boss_enrage_mult(round) - A5 BOSS ENRAGE (BALANCE_NOTE C1, M-approved
// 07-09): in a BOSS encounter at Awakening 5, enemy damage gains +10% per round
// past round 6, so the fight can't be turtled forever. 1.0 everywhere else.
function awaken_boss_enrage_mult(round) {
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    if (_asc < 5) return 1.0;
    if (!variable_global_exists("next_enemy_type") || global.next_enemy_type != "boss") return 1.0;
    return 1.0 + 0.10 * max(0, round - 6);
}

// awaken_xp_mult(asc) - kill-XP multiplier by Awakening tier (BALANCE_NOTE C3,
// M-approved 07-09). Root cause of the "level 8 wall": enemies scaled to x2.55 HP
// at A5 but paid A0 XP, so run level (and the L5/10/15 perm-point rungs) fell ever
// further behind the difficulty. A thorough A5 clear now lands ~L11-12 (2 points);
// L15 stays a kill-everything trophy. Shown on the dungeon-select AWAKENING
// EFFECTS panel (same single-source rule as the tables above).
function awaken_xp_mult(asc = undefined) {
    var _asc = (asc != undefined) ? asc
        : (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
    var _tbl = [1.00, 1.15, 1.30, 1.50, 1.75, 2.00];
    // A6+: +8%/tier compounding on top of the A5 rate (matches the gold curve).
    var _endless = (_asc > 5) ? power(1.08, _asc - 5) : 1.0;
    return _tbl[clamp(_asc, 0, array_length(_tbl) - 1)] * _endless;
}

// ---------------------------------------------------------------------------
// awaken_enemy_acc_bonus()
// Flat accuracy points added to every enemy hit roll, scaling with the run's
// Awakening tier. Stops stacked DODGE/DEX from trivializing high Awakenings -
// at A4/A5 even an evasion build gets hit. Added to _enemy_acc in combat.
// ---------------------------------------------------------------------------
function awaken_enemy_acc_bonus(asc = undefined) {
    var _asc = (asc != undefined) ? asc
        : (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
    var _tbl = [0, 0, 5, 10, 18, 28];
    // A6+: +2 accuracy per endless tier (flat, so dodge stays viable-but-fading).
    var _end_acc = (_asc > 5) ? floor(2 * (_asc - 5)) : 0;
    _asc = clamp(_asc, 0, array_length(_tbl) - 1);
    return _tbl[_asc] + _end_acc;
}

// awaken_enemy_heal_mult() - enemy healing scales with Awakening (mirrors the dmg
// curve). At high tiers, self-healing foes punish slow damage and reward burst /
// anti-heal (mortality) / consumables. See SYSTEMS_VIABILITY_PASS.md (P6c).
function awaken_enemy_heal_mult(asc = undefined) {
    var _asc = (asc != undefined) ? asc
        : (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
    var _tbl = [1.0, 1.15, 1.35, 1.6, 1.9, 2.3];
    var _end_heal = awaken_endless_mult(_asc);
    _asc = clamp(_asc, 0, array_length(_tbl) - 1);
    return _tbl[_asc] * _end_heal;
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
//   Crimson Reserve- +20 Blood at combat start (Bloodwarden only)
//   Phantom Step   - sets phantom_step_active flag; consumed on first hit
// NOTE: Thick Skin is NOT here anymore - it is a STATIC +10% max HP folded into
// player.max_HP at creation (see obj_combat_controller/Create + trait_maxhp_mult),
// so it no longer acts as a per-combat heal that inflated HP each fight.
// ---------------------------------------------------------------------------
function combat_apply_start_traits(player) {
    // Crimson Reserve: Bloodwarden only - start combat with 4 Blood (of 10).
    // Audit fix 2026-07-03: was +20 vs a 10-cap bar, i.e. a mislabeled full bar.
    // POTENCY V2: ranks 2/4 start with 5/6; TRANSCEND "Overflow" raises the cap
    // by 4 and pours in the Blood carried from the previous combat (banked at
    // victory in obj_combat_controller).
    if (player.class_id == 1 && variable_struct_exists(player, "blood")
        && trait_active("Crimson Reserve")) {
        if (trait_transcended("Crimson Reserve")) {
            player.blood_max += 4;
            if (variable_global_exists("blood_carry") && global.blood_carry > 0) {
                player.blood = min(player.blood_max, player.blood + global.blood_carry);
                global.blood_carry = 0;
            }
        }
        var _cr_r = trait_potency_r14("Crimson Reserve");
        player.blood = min(player.blood_max, player.blood + 4 + (_cr_r >= 2 ? 1 : 0) + (_cr_r >= 4 ? 1 : 0));
    }

    // Phantom Step: first enemy attack each combat auto-misses
    // phantom_step_active is consumed by combat_check_phantom_step()
    // POTENCY V2: +2% flat dodge per rank; TRANSCEND "Afterimage" banks one
    // once-per-combat forced miss (consumed in the enemy swing roll).
    player.phantom_step_active = trait_active("Phantom Step");
    player.phantom_dodge       = 2 * trait_potency_r14("Phantom Step");
    player.afterimage_ready    = trait_transcended("Phantom Step");

    // Soul Siphon potency r2/r4 (POTENCY V2): +1 Soul at combat start each.
    if (player.class_id == 0 && variable_struct_exists(player, "souls") && trait_active("Soul Siphon")) {
        var _ss_r = trait_potency_r14("Soul Siphon");
        player.souls = min(player.souls_max, player.souls + (_ss_r >= 2 ? 1 : 0) + (_ss_r >= 4 ? 1 : 0));
    }

    // Ley Tap: +1 bonus AP at combat start (Arcanist only).
    // Bugfix 07-16: was `player.AP += 1` but the combat player struct's field is
    // `energy` (no AP field exists) - equipping Ley Tap crashed at combat start.
    if (player.class_id == 0 && trait_active("Ley Tap")) {
        player.energy += 1;
    }

    // Relentless (M 07-16): Bloodwarden's base AP is 4 - the struct is built with
    // energy: 3, so top up the FIRST turn here; combat_next_turn covers the rest.
    // TRANSCEND "Tireless" (POTENCY V2): turn 1 has 5 AP.
    if (player.class_id == 1 && trait_active("Relentless")) {
        player.energy = max(player.energy, 4);
        if (trait_transcended("Relentless")) player.energy += 1;
    }

    // Iron Will: first status effect applied to the player this combat is absorbed
    // POTENCY V2: ranks shorten later statuses (-10%/rank); TRANSCEND "Unshakable"
    // bans the absorbed status kind for the rest of the combat (kind recorded at
    // the absorb site in obj_combat_controller).
    player.iron_will_active = trait_active("Iron Will");
    player.iron_will_banned = "";

    // Expanded Arsenal TRANSCEND "Deep Reserves" (POTENCY V2): per-ability
    // first-cast -1 AP flags, fresh each combat (mirrors the web keystone flags).
    player.potency_first_casts = {};

    // Last Stand potency (POTENCY V2): fury damage bonus armed when it triggers.
    player.last_stand_fury = 0;

    // Battle Hardened: apply accumulated permanent HP bonus
    if (variable_global_exists("perm_hp_battle_hardened") && global.perm_hp_battle_hardened > 0) {
        player.max_HP += global.perm_hp_battle_hardened;
        player.HP      = min(player.HP + global.perm_hp_battle_hardened, player.max_HP);
    }

    // Second Wind run bonus (POTENCY V2): flat max-HP granted at the first rest,
    // mirrored from out_of_combat_max_hp so the in-fight bar agrees.
    if (variable_global_exists("run_bonus_max_hp") && global.run_bonus_max_hp > 0) {
        player.max_HP += global.run_bonus_max_hp;
        player.HP      = min(player.HP + global.run_bonus_max_hp, player.max_HP);
    }

    // Shadow Meld (audit §6 rework): after a dodge, the next attack is a guaranteed crit.
    player.shadow_meld_crit = false;

    // Aspect-rune flagship per-combat flags (Quickcast / Echo).
    player.rune_first_spell_used = false;   // Quickcast: first spell each combat costs -1 AP
    player.rune_first_aoe_used   = false;   // Echo: first AoE each combat echoes for 50%

    // Fully-corrupted companion betrayal (M-locked 08-15): ONE 10% roll per
    // combat, consumed by combat_pet_act (Warrior savages you / others refuse).
    var _fc_pet = pet_active();
    player.pet_betray_hit = (_fc_pet != undefined && !_fc_pet.is_egg
        && pet_is_fulfilled(_fc_pet) && irandom(99) < 10);

    // Talent-web Opening Gambit keystone: per-ability first-cast flags (fresh each combat).
    player.web_first_casts = {};

    // Aegis boon: begin each combat with a shield.
    if (boon_active("aegis")) {
        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
        player.shield_hp += boon_value("aegis");
    }

    // Bastion flagship rune (C6, M-approved 07-09): start each combat with a
    // standing ward (8 at tier III). Stacks with Aegis - both are chase content.
    var _bast = rune_aspect_value("start_shield", undefined);
    if (_bast > 0) {
        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
        player.shield_hp += _bast;
    }

    // --- Shrine Blessings V2 (07-29): per-combat blessing state ---------------
    player.second_skin_used = false;   // Second Skin: first hit each combat halved
    player.whet_echo_used   = false;   // Whetstone Echo: first damaging ability echoes 40%
    player.boon_cast_count  = 0;       // Third Wind: every 3rd cast this combat -1 AP
    global.feast_stacks     = 0;       // Feast of Crows: corpses this combat (dmg/armor stacks)

    // --- Talent-web P3 (07-29): per-combat bespoke-node state -----------------
    player.overdrive_used   = false;   // Adrenaline Rush "Overdrive": once per combat
    player.sharp_edges_value = 0;      // Iron Skin "Sharp Edges": armed at cast
    player.pact_shield = 0; player.pact_debt = 0;                  // Sanguine Pact "Blood Debt"
    player.pact_debt_armed = false; player.pact_debt_due = false;
    global.last_kill_round  = -1;      // Soul Harvest "Reaper's Tempo" round stamp
    // Soul Shield "Unbroken": the remnant banked at last victory carries in.
    if (variable_global_exists("unbroken_shield") && global.unbroken_shield > 0) {
        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
        player.shield_hp += global.unbroken_shield;
        global.unbroken_shield = 0;
    }
    // Gambler's Icon cooldown ledger: a proc last fight arms 2 resting fights
    // (proc -> rest -> rest -> eligible). Eligibility is read at the drop roll
    // (boon_gambler_tier_bonus) as gambler_cd == 0.
    if (!variable_global_exists("gambler_cd"))   global.gambler_cd   = 0;
    if (!variable_global_exists("gambler_proc")) global.gambler_proc = false;
    if (global.gambler_proc)        { global.gambler_cd = 2; global.gambler_proc = false; }
    else if (global.gambler_cd > 0) { global.gambler_cd -= 1; }
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
    // THE ASHEN DUELIST'S MERCY (DESIGN_DUELIST_CHALLENGE.md, M-locked 07-29):
    // in a duel his killing blow STOPS at 1 HP - the duel ends, he heals you to
    // room-entry HP, and it is NEVER a death: no gravestone, no Iron Vow life,
    // no once-per-run trait consumed. This is the single lethal gate, so every
    // damage source in the duel funnels through here. The Step_0 mercy block
    // sees duel_mercy_fired next frame and closes the fight.
    if (variable_global_exists("duel_active") && global.duel_active) {
        player.HP = 1;
        global.duel_mercy_fired = true;
        array_push(combat_log, "The blade stops a hair from your throat. The duel is over.");
        return true;
    }
    // UNDYING fires first (Bloodwarden cast, armed per-cast - spend it before the
    // once-per-run trait). Audit §6 build: on trigger you surge back to 25% max HP
    // and your defiance grants 3 Blood. This function is the single lethal gate,
    // so every damage source (attacks, spells, DoTs) passes through here.
    if (variable_struct_exists(player, "undying_active") && player.undying_active) {
        player.undying_active = false;
        player.HP = max(1, floor(player.max_HP * 0.25));
        if (variable_struct_exists(player, "blood")) {
            player.blood = min(player.blood_max, player.blood + 3);
        }
        array_push(combat_log, "UNDYING! Your blood refuses the wound - you surge back to " + string(player.HP) + " HP (+3 Blood).");
        return true;
    }
    // FATE'S COIN (Fortune capstone, C5 M-approved 07-09): once per combat, the
    // blow that would kill you leaves you at 1 HP. Fires BEFORE Last Stand so the
    // scarcer once-per-RUN trait is preserved; after Undying, which the player
    // armed deliberately with a cast. player struct is per-combat, so the used
    // flag resets naturally each fight.
    if (pet_active_has_fatecoin()
        && (!variable_struct_exists(player, "fatecoin_used") || !player.fatecoin_used)) {
        player.fatecoin_used = true;
        player.HP = 1;
        array_push(combat_log, "FATE'S COIN! Your companion's luck turns the blow - you cling on at 1 HP.");
        return true;
    }

    // Gravewalker Treads (07-28 legendary): once per RUN, walk out of the grave
    // at 1 HP. Fires after the deliberate/per-combat saves but BEFORE Last Stand,
    // so the trait's own once-per-run charge is preserved. global.gravewalker_used
    // resets in run_state_reset.
    if (variable_struct_exists(player, "leg_treads") && player.leg_treads
        && (!variable_global_exists("gravewalker_used") || !global.gravewalker_used)) {
        global.gravewalker_used = true;
        player.HP = 1;
        array_push(combat_log, "GRAVEWALKER TREADS! You have walked out of worse - 1 HP, still standing.");
        return true;
    }

    if (!trait_active("Last Stand")) return false;
    // TRANSCEND "Deathless" (POTENCY V2): once per FLOOR instead of once per
    // run - a use recorded on an earlier floor doesn't spend this floor's.
    var _ls_floor = variable_global_exists("current_floor") ? global.current_floor : 1;
    if (variable_global_exists("last_stand_used") && global.last_stand_used) {
        if (!trait_transcended("Last Stand")) return false;
        if (variable_global_exists("last_stand_floor") && global.last_stand_floor == _ls_floor) return false;
    }

    player.HP = 1;
    if (variable_global_exists("last_stand_used")) global.last_stand_used = true;
    global.last_stand_floor = _ls_floor;
    // POTENCY V2 ranks: defiance - +10% damage per rank for the rest of this combat.
    var _ls_r = trait_potency_r14("Last Stand");
    if (_ls_r > 0) {
        player.last_stand_fury = 0.10 * _ls_r;
        array_push(combat_log, "LAST STAND! You cling to life at 1 HP - fury sharpens your blows (+" + string(_ls_r * 10) + "% damage).");
    } else {
        array_push(combat_log, "LAST STAND! You cling to life at 1 HP.");
    }
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
    // Enemy-applied statuses can carry kind:"" (enemy_ability's status_kind
    // default) - treat empty the same as absent so they resolve by effect_type.
    if (variable_struct_exists(se, "kind") && se.kind != "") return se.kind;
    return se.effect_type;
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
        case "Curse":
            // Hexed (audit §6 rework): still +4 damage taken per hit (summed alongside
            // vulnerable in the damage chain), but ALSO doubles any detonation reaction
            // on the bearer and spreads +2 dmg-taken to all other enemies when one fires.
            return "hexed";
        case "Bonebreaker":
            return "vulnerable";
        case "Marked for Death":
            // D§3 rework (M-approved 07-09): the EXECUTE setup - was a flat
            // vulnerable clone. "marked" = +30% from all sources below 50% HP
            // (applied in combat_apply_damage).
            return "marked";
        case "Marrow Crush": case "Frost Shot":   // Frost Shot's own debuff is the Weaken; its 1-turn Chill is a bespoke rider (Step_0)
        case "Hoarfrost Lance":   // D§4 Chill: weaken-kind, frost element (shatters)
            return "weaken";
        case "Smoke Bomb":
            return "blind";
        case "Plague Touch":
            return "mortality";
        case "Death Snare":
            return "stun";
        case "Bear Trap":
            return "root";
        case "Gravewrack Grip":
            return "root";   // #26 melee kit - the guaranteed drain also holds them in place
        case "Mana Sever":
            return "silence";   // "sever mana" - target can't take spell actions
        case "Paralytic Pulse":
            return "stun";      // 08-17: per-enemy 40% roll happens in the cast block
        case "Call of the Void":
            return "void_random";   // 08-17: resolved to a random kind at apply time (cast block)
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
        // D§4: the Chill rides the existing frost element (Chilled display +
        // frost SHATTER detonation), applied as a weaken-kind status.
        case "Hoarfrost Lance": return "frost";
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

// combat_control_resist_try(target, kind) - ESCALATING CONTROL RESIST (M 07-28:
// a lvl-0 Shadowstrider perma-locked whole floors by re-casting Bear Trap every
// turn). The first control of a combat always sticks; each control that has
// already stuck to this enemy raises the next one's resist chance by 30 points
// (30% / 60% / 90%, capped there). ALL control kinds share the one counter, so
// alternating Root and Stun doesn't dodge the ramp. State lives on the enemy
// clone -> resets automatically every combat. Returns true if this application
// should FIZZLE (caller logs it; any damage part of the ability still lands).
function combat_control_resist_try(target, kind) {
    if (kind != "stun" && kind != "root" && kind != "silence") return false;
    if (!is_struct(target)) return false;
    if (variable_struct_exists(target, "is_player") && target.is_player) return false;
    if (!variable_struct_exists(target, "control_stuck_n")) target.control_stuck_n = 0;
    if (irandom(99) < min(90, 30 * target.control_stuck_n)) return true;
    target.control_stuck_n += 1;
    return false;
}

// combat_cleanse_one(c) - strip ONE hostile status from an enemy combatant:
// control first (stun > root > silence), then the newest player-sourced effect.
// Returns the removed status's display name, or "" if nothing to cleanse.
// (M 07-28 AI pass: A2+ enemy heals carry this as a rider - see the heal branch
// in obj_combat_controller Step - so perma-control has an in-fiction answer.)
// Mandate from Heaven (P4, M-approved 07-30): true while a player-sourced
// status is under heaven's seal and cannot be cleansed - 2 turns from
// application (3 Transcended). Unstamped = just applied = protected; the enemy
// status tick stamps applied_round on first sight. The control-resist ramp is
// deliberately NOT bypassed (resist is the enemy fighting through, not a cleanse).
function combat_status_mandate_protected(se) {
    if (!trait_active("Mandate from Heaven")) return false;
    if (!variable_struct_exists(se, "source") || se.source != "player") return false;
    var _n = trait_transcended("Mandate from Heaven") ? 3 : 2;
    if (!variable_struct_exists(se, "applied_round")) return true;
    if (!instance_exists(obj_combat_controller)) return true;
    return (instance_find(obj_combat_controller, 0).combat_state.round - se.applied_round) < _n;
}

// True when the combatant carries at least one Mandate-sealed status (for the
// "the mending fails" log line at the enemy-heal cleanse rider).
function combat_any_mandate_protected(c) {
    if (!variable_struct_exists(c, "status_effects")) return false;
    for (var _i = 0; _i < array_length(c.status_effects); _i++)
        if (combat_status_mandate_protected(c.status_effects[_i])) return true;
    return false;
}

function combat_cleanse_one(c) {
    if (!variable_struct_exists(c, "status_effects")) return "";
    var _pri = ["stun", "root", "silence"];
    for (var _p = 0; _p < array_length(_pri); _p++) {
        for (var _i = array_length(c.status_effects) - 1; _i >= 0; _i--) {
            var _se = c.status_effects[_i];
            if (combat_status_kind_of(_se) == _pri[_p]) {
                if (combat_status_mandate_protected(_se)) continue;   // P4: the seal holds
                var _nm = variable_struct_exists(_se, "name") ? _se.name : ("the " + _pri[_p]);
                array_delete(c.status_effects, _i, 1);
                return _nm;
            }
        }
    }
    for (var _i = array_length(c.status_effects) - 1; _i >= 0; _i--) {
        var _se = c.status_effects[_i];
        if (variable_struct_exists(_se, "source") && _se.source == "player") {
            if (combat_status_mandate_protected(_se)) continue;   // P4: the seal holds
            var _nm = variable_struct_exists(_se, "name") ? _se.name : "a lingering effect";
            array_delete(c.status_effects, _i, 1);
            return _nm;
        }
    }
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

// combatant_distinct_status_kinds(c) - number of DISTINCT status kinds the
// combatant carries, for the OVERWHELM rule (07-16): two bleed stacks = 1,
// bleed + chill = 2. DoTs are qualified by element (bleed/poison/void each
// count as their own kind); everything else counts by its `kind`.
function combatant_distinct_status_kinds(c) {
    if (!is_struct(c) || !variable_struct_exists(c, "status_effects")) return 0;
    var _seen = {};
    var _n = 0;
    for (var _i = 0; _i < array_length(c.status_effects); _i++) {
        var _s = c.status_effects[_i];
        var _k = combat_status_kind_of(_s);
        if (_k == "dot") _k = "dot:" + combat_status_element(_s);
        if (!variable_struct_exists(_seen, _k)) {
            variable_struct_set(_seen, _k, true);
            _n++;
        }
    }
    return _n;
}

// combat_reaction_preview(ab, caster, target) - the LEGIBILITY half of the combo
// system (07-16): what reaction would THIS ability trigger on THIS target right
// now? Returns { label, col } for the hit-preview chip / status-icon glow, or
// label "" when nothing would react. Mirrors the Step_0 reaction switch - keep
// the two in sync when the reaction table changes.
function combat_reaction_preview(ab, caster, target) {
    var _none = { label: "", col: c_white, idx: -1 };
    if (!is_struct(ab) || !ability_is_detonator(ab)) return _none;
    if (!variable_struct_exists(ab, "base_damage") || ab.base_damage <= 0) return _none;
    var _pick = combat_detonator_pick(target);
    if (_pick.key == "") return _none;
    var _hexed = (combat_status_total(target, "hexed") > 0);
    var _hx = _hexed ? 2 : 1;
    var _lbl = "";
    var _col = c_white;
    switch (_pick.key) {
        case "frost": case "root":
            _lbl = "SHATTER +" + string(30 * _hx) + "%"; _col = make_color_rgb(140, 210, 255); break;
        case "stun":
            _lbl = "CRIT!"; _col = c_yellow; break;
        case "burn":
            _lbl = "+" + string(40 * _hx) + "% crit"; _col = make_color_rgb(255, 150, 60); break;
        case "vulnerable":
            _lbl = "+" + string(12 * _hx) + " dmg"; _col = make_color_rgb(255, 200, 90); break;
        case "weaken":
            _lbl = "+" + string(15 * _hx) + "% dmg"; _col = make_color_rgb(210, 160, 255); break;
        case "bleed":
            // Sum remaining bleed ticks for the exact bonus.
            var _bt = 0;
            for (var _i = 0; _i < array_length(target.status_effects); _i++) {
                var _s = target.status_effects[_i];
                if (combat_status_kind_of(_s) == "dot" && combat_status_element(_s) == "bleed") {
                    _bt += variable_struct_exists(_s, "duration") ? _s.duration : 0;
                }
            }
            _lbl = "BURST +" + string(_bt * 5 * _hx); _col = make_color_rgb(235, 80, 80); break;
        case "poison":
            _lbl = "MORTALITY"; _col = make_color_rgb(150, 220, 90); break;
        case "void":
            _lbl = "+" + string(30 * _hx) + "% lifesteal"; _col = make_color_rgb(190, 120, 255); break;
        case "blind":
            _lbl = "CAN'T MISS"; _col = make_color_rgb(200, 200, 200); break;
        case "shock":
            _lbl = "ARC " + string(33 * _hx) + "%"; _col = make_color_rgb(120, 200, 255); break;
    }
    // Numeric labels above already carry the doubled hex values; flag the hex
    // itself only on the non-numeric ones so nothing reads as doubled twice.
    if (_lbl != "" && _hexed && (_pick.key == "stun" || _pick.key == "poison" || _pick.key == "blind")) _lbl += " (HEXED)";
    return { label: _lbl, col: _col, idx: _pick.idx };
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

// combat_detonator_keys_all(target) - EVERY distinct reaction key the target is
// carrying, in the same priority order combat_detonator_pick uses. Feeds the
// EVENT HORIZON cascade (M-locked 08-15): the ultimate fires one reaction per
// distinct status kind present, then strips the target bare.
function combat_detonator_keys_all(target) {
    var _out = [];
    if (!is_struct(target) || !variable_struct_exists(target, "status_effects")) return _out;
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
                case "vulnerable": _match = (_k == "vulnerable" || _k == "firemark"); break;
                case "bleed":      _match = (_k == "dot" && _el == "bleed"); break;
                case "poison":     _match = (_k == "dot" && _el == "poison"); break;
                case "void":       _match = (_k == "dot" && _el == "void"); break;
                case "weaken":     _match = (_k == "weaken"); break;
                case "blind":      _match = (_k == "blind"); break;
            }
            if (_match) { array_push(_out, _want); break; }
        }
    }
    return _out;
}

// Tiny membership helper for the cascade's key list.
function combat_keys_has(arr, k) {
    for (var _i = 0; _i < array_length(arr); _i++) if (arr[_i] == k) return true;
    return false;
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
        var _se_kind = combat_status_kind_of(_se);
        if (_se_kind == "dot") {
            // Ember Saint's Censer (07-28 legendary): the bearer's afflictions on
            // ENEMIES tick +2 harder (player-sourced DoTs only - never the ones
            // eating the player).
            var _es_bonus = 0;
            if (!variable_struct_exists(c, "is_player") || !c.is_player) {
                if (variable_struct_exists(_se, "source") && _se.source == "player"
                    && instance_exists(obj_combat_controller)) {
                    var _es_pl = instance_find(obj_combat_controller, 0).player;
                    if (variable_struct_exists(_es_pl, "leg_censer") && _es_pl.leg_censer) _es_bonus = 2;
                }
            }
            combat_apply_damage(c, _se.effect_value + _es_bonus);
            array_push(log, _cname + " takes " + string(_se.effect_value + _es_bonus) + " " + _se.name + " damage!"
                + (_es_bonus > 0 ? "  (Censer +2)" : ""));
            // Accelerating DoT (Entropy 07-16): each tick grows by `accel` (6/8/10/12).
            if (variable_struct_exists(_se, "accel") && _se.accel > 0) _se.effect_value += _se.accel;
        } else if (_se_kind == "regen") {
            // Heal-over-time (Warden's / Phoenix Tonic). Clamp to max HP; heals raw to
            // match the instant-heal consumable (no mortality reduction on player items).
            var _rmax  = variable_struct_exists(c, "max_HP") ? c.max_HP : c.HP;
            var _rheal = min(_rmax - c.HP, _se.effect_value);
            if (_rheal > 0) {
                c.HP += _rheal;
                array_push(log, _cname + " recovers " + string(_rheal) + " HP from " + _se.name + ".");
            }
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

// combat_status_is_debuff(se) - true for HARMFUL statuses (everything except the
// beneficial ones like regen). Used by the cleanse consumables so they never strip
// a player's own buff (e.g. a Warden's Tonic heal-over-time).
// combat_immune_sweep(combat_state, log, popups) - runs every combat Step frame:
// strips any status an enemy is family-immune to (enemy_immunities) the frame it
// lands, with an IMMUNE popup + log line. One central hook instead of guarding
// ~40 status push sites; nothing ticks between frames so it is effectively
// instant. Mortality is left alone (never on the immunity lists anyway).
function combat_immune_sweep(combat_state, log, popups) {
    if (!is_struct(combat_state) || !variable_struct_exists(combat_state, "combatants")) return;
    var _slot = 0;
    for (var _i = 0; _i < array_length(combat_state.combatants); _i++) {
        var _c = combat_state.combatants[_i];
        if (_c.is_player) continue;
        var _my_slot = _slot; _slot++;
        if (_c.is_defeated || array_length(_c.status_effects) == 0) continue;
        var _im = enemy_immunities(_c.name);
        if (array_length(_im) == 0) continue;
        for (var _s = array_length(_c.status_effects) - 1; _s >= 0; _s--) {
            var _se = _c.status_effects[_s];
            var _kind = combat_status_kind_of(_se);
            var _el   = combat_status_element(_se);
            // Fire DoTs are tagged "burn" (weapon-affix Burning, Forge Spark, dtype-1
            // ability DoTs) OR "fire" (Scorch / Sear) - one immunity covers both.
            if (_el == "burn") _el = "fire";
            for (var _k = 0; _k < array_length(_im); _k++) {
                if (_im[_k].kind != _kind) continue;
                if (_im[_k].element != "" && _im[_k].element != _el) continue;
                array_delete(_c.status_effects, _s, 1);
                var _nm = variable_struct_exists(_se, "name") ? string(_se.name) : _im[_k].label;
                array_push(log, _c.name + " is IMMUNE to " + _im[_k].label + " - " + _nm + " has no hold on it!");
                var _im_a = combat_enemy_anchor(_c, _my_slot);
                array_push(popups, { value: 0, text: "IMMUNE", x: _im_a.x, y: _im_a.y - 105,
                    timer: 45, col: make_color_rgb(190, 190, 205) });
                break;
            }
        }
    }
}

function combat_status_is_debuff(se) {
    switch (combat_status_kind_of(se)) {
        case "regen": return false;   // beneficial heal-over-time
    }
    return true;   // dot / vulnerable / weaken / blind / mortality / stun / root / silence / firemark
}

// combat_cleanse(c, mode) - removes statuses from c.status_effects and returns the
// count removed. mode: "dot" = every damage-over-time; "one" = the first debuff
// (Smelling Salts); "all" = every debuff (Purification Draught). Buffs are kept.
// Single source of truth for ALL cleanse consumables across every use path.
function combat_cleanse(c, mode) {
    if (!variable_struct_exists(c, "status_effects")) return 0;
    var _kept = [];
    var _removed = 0;
    for (var _i = 0; _i < array_length(c.status_effects); _i++) {
        var _se = c.status_effects[_i];
        var _take = false;
        if      (mode == "dot") _take = (combat_status_kind_of(_se) == "dot");
        else if (mode == "all") _take = combat_status_is_debuff(_se);
        else if (mode == "one") _take = (_removed == 0 && combat_status_is_debuff(_se));
        if (_take) _removed++; else array_push(_kept, _se);
    }
    c.status_effects = _kept;
    return _removed;
}

// combat_heal_after_mortality(c, amount) - scales a heal by the bearer's
// `mortality` debuff (-% healing received). Returns the reduced amount.
function combat_heal_after_mortality(c, amount) {
    // Hollowlight (Depth Warden, 08-13): for the first 2 rounds of its fight the
    // player's healing is INVERTED - the light it sheds is the exact colour of
    // relief, and everything it falls on gets worse. The mend lands as damage
    // and the heal itself returns 0.
    if (amount > 0 && variable_struct_exists(c, "is_player") && c.is_player
        && instance_exists(obj_combat_controller)) {
        var _hl_cc = instance_find(obj_combat_controller, 0);
        if (_hl_cc.combat_state.round <= 2) {
            for (var _hl_i = 0; _hl_i < array_length(_hl_cc.combat_state.combatants); _hl_i++) {
                var _hl_e = _hl_cc.combat_state.combatants[_hl_i];
                if (!_hl_e.is_player && !_hl_e.is_defeated
                    && variable_struct_exists(_hl_e, "warden_hook") && _hl_e.warden_hook == "hollowlight") {
                    var _hl_amt = max(1, floor(amount));
                    array_push(_hl_cc.combat_log, "HOLLOWLIGHT inverts the mend - " + string(_hl_amt)
                        + " HP runs the wrong way!");
                    combat_apply_damage(c, _hl_amt);
                    return 0;
                }
            }
        }
    }
    // Withered curse: -50% healing received (applies to the player only; enemies
    // don't carry curses). Stacks multiplicatively with the mortality debuff.
    if (variable_struct_exists(c, "is_player") && c.is_player && curse_heal_mult() != 1.0) {
        amount = amount * curse_heal_mult();
    }
    // Empty Comfort (hollow_pup innate, 08-01) / Guttering Light (tallow_moth,
    // 08-06 remap): +N% to all healing the player receives.
    if (variable_struct_exists(c, "is_player") && c.is_player && pet_active_innate("heal_recv") > 0) {
        amount = amount * (1 + pet_active_innate("heal_recv") / 100);
    }
    // Ebb (sluice_otter signature move, 08-06): the FIRST heal the player receives
    // each combat is doubled. Consumed only by a real heal (amount > 0); the
    // once-flag rides the per-combat player struct like the other sig moves.
    if (amount > 0 && variable_struct_exists(c, "is_player") && c.is_player
        && !variable_struct_exists(c, "sig_ebb_done")
        && pet_active_sig_move("ebb")) {
        c.sig_ebb_done = true;
        amount *= 2;
        if (instance_exists(obj_combat_controller)) {
            array_push(instance_find(obj_combat_controller, 0).combat_log,
                "[Companion] " + pet_active().name + "'s EBB returns the tide - the mend is DOUBLED!");
        }
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
// ---------------------------------------------------------------------------
// PLAYER ARMOR (M-locked 08-18: "we need to change how armor works"). The old
// chain SUBTRACTED base armor, then Iron Skin, then gear armor, then boon armor,
// then Clotted Armor - flat stacks that zeroed 5-8 damage mobs to the 1-dmg floor
// by Lv5. Now every armor source is ONE pool and reduces the hit by a
// PERCENTAGE with diminishing returns:
//     reduction = armor / (armor + 15), capped at 60%
//     armor 5 -> 25%   10 -> 40%   15 -> 50%   25 -> 62% -> 60%
// Iron Skin (damage_reduction) stays a FLAT cut - it is an ability, not armor.
// combat_player_armor_total / _pct are the single source; the stats page,
// glossary and inspect copy read them.
// ---------------------------------------------------------------------------
#macro PLAYER_ARMOR_K   15
#macro PLAYER_ARMOR_CAP 0.60
function combat_player_armor_total(player) {
    var _a = 0;
    if (variable_struct_exists(player, "armor"))       _a += player.armor;
    if (variable_struct_exists(player, "equip_armor")) _a += player.equip_armor;
    _a += boon_flat_armor();   // Ironhide / Feast of Crows
    // Clotted Armor (Bloodwarden trunk): +2 armor while holding 5+ Blood.
    if (variable_struct_exists(player, "blood") && player.blood >= 5
        && variable_struct_exists(player, "class_id") && player.class_id == 1 && trunk_has("blood_hp")) _a += 2;
    return max(0, _a);
}
function combat_player_armor_pct(player) {
    var _a = combat_player_armor_total(player);
    if (_a <= 0) return 0;
    return min(PLAYER_ARMOR_CAP, _a / (_a + PLAYER_ARMOR_K));
}
// Physical/elemental hit on the player through the armor pool: raw -> flat Iron
// Skin -> % armor (elemental hits use el_resist as the pool instead). Floor 1.
function combat_player_apply_armor(player, dmg, dtype) {
    var _d = dmg;
    if (variable_struct_exists(player, "damage_reduction")) _d = max(0, _d - player.damage_reduction);
    if (dtype == 1) {
        // Elemental: el_resist pool, same curve.
        var _er = (variable_struct_exists(player, "el_resist") ? player.el_resist : 0)
                + (variable_struct_exists(player, "equip_el_resist") ? player.equip_el_resist : 0);
        var _ep = (_er > 0) ? min(PLAYER_ARMOR_CAP, _er / (_er + PLAYER_ARMOR_K)) : 0;
        return max(1, round(_d * (1 - _ep)));
    }
    if (dtype == 2 || dtype == 3) return max(1, _d);   // drain / blood: unmitigated
    return max(1, round(_d * (1 - combat_player_armor_pct(player))));
}

function combat_mitigate_player(player, raw, dtype, log) {
    var _d = raw + combat_status_total(player, "vulnerable");
    _d = combat_player_apply_armor(player, _d, dtype);   // Iron Skin flat -> % armor pool (08-18)
    if (dtype == 0 && variable_struct_exists(player, "derived") && player.derived.phys_dmg_reduction > 0) {
        _d = max(1, ceil(_d * (1.0 - (player.derived.phys_dmg_reduction / 100.0))));
    }
    // Warding boon: flat % incoming-damage reduction.
    if (boon_active("warding")) _d = max(1, round(_d * boon_incoming_mult()));
    // Warding egg (Pets §3): active hatchling reduces incoming damage.
    if (pet_egg_ward_mult() != 1.0) _d = max(1, round(_d * pet_egg_ward_mult()));
    // Curse penalties (Exposed/Ruin): flat % incoming-damage increase.
    if (curse_incoming_mult() != 1.0) _d = max(1, round(_d * curse_incoming_mult()));
    // Second Skin blessing (Shrine V2): the first hit each combat is halved -
    // applied before the shield so the ward isn't spent on the waived half.
    _d = boon_second_skin_apply(player, _d, log);
    if (variable_struct_exists(player, "shield_hp") && player.shield_hp > 0 && _d > 0) {
        var _sa = min(player.shield_hp, _d);
        player.shield_hp -= _sa;
        // "Blood Debt" (P3): the pact share depletes here too; the caller (which
        // knows the attacker) resolves pact_debt_due after the damage lands.
        if (variable_struct_exists(player, "pact_shield") && player.pact_shield > 0) {
            player.pact_shield = max(0, player.pact_shield - _sa);
            if (player.shield_hp <= 0 && player.pact_debt_armed) player.pact_debt_due = true;
        }
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

// enemy_death_sound(name) - themed death sound for an enemy. All 7 family slots
// are imported (sound pass Batch 1), so the old per-family library fallbacks are
// gone - those legacy assets were retired in Batch 4 (unidentified licenses).
function enemy_death_sound(name) {
    play_enemy_sfx("snd_death_" + enemy_sound_family(name), -1);
}

// enemy_attack_sound(name) - themed attack/cast sound for an enemy's offensive action.
function enemy_attack_sound(name) {
    play_enemy_sfx("snd_attack_" + enemy_sound_family(name), -1);
}

// ability_sfx_school(ab) - resolve a magic SCHOOL for an ability's CAST sound, so
// elemental spells that all share damage_type 1 (fire/frost/shock/arcane/nature)
// stop playing the same snd_cast_elem. Returns a school suffix ("fire".."nature")
// for the known offensive spells, or "" to let play_ability_cast_sfx fall back to
// its damage_type routing (physical -> weapon vocal; drain -> void; blood -> blood).
// Keyed on the STABLE ENGLISH ability name (abilities have no id; the name is the
// identity used everywhere) so it survives localization. Schools are read straight
// from the abilities' own flavor descriptions ("15 Fire dmg", "38 Arcane dmg", ...).
function ability_sfx_school(ab) {
    if (!variable_struct_exists(ab, "name")) return "";
    switch (ab.name) {
        // FIRE
        case "Soulfire":        return "fire";
        case "Scorch":          return "fire";
        case "Blazing Palm":    return "fire";
        // FROST (Glacial Ward stays a defensive "ward" via the support branch)
        case "Frost Shot":      return "frost";
        case "Hoarfrost Lance": return "frost";
        case "Winter's Bite":   return "frost";
        // SHOCK
        case "Static Arc":      return "shock";
        case "Galvanize":       return "shock";
        // NATURE / poison
        case "Poison Dart":     return "nature";
        case "Plague Touch":    return "nature";
        // ARCANE (the arcane-typed elemental spells; snd_cast_arcane was rerolled)
        case "Arcane Burst":    return "arcane";
        case "Rift":            return "arcane";
        case "Soul Nova":       return "arcane";
        case "Soul Rend":       return "arcane";
        case "Arcane Echo":     return "arcane";
        case "Mana Sever":      return "arcane";
        case "Event Horizon":   return "void";   // 08-15 rework: was arcane Singularity
        case "Paralytic Pulse": return "arcane"; // 08-17 control pair
        case "Call of the Void": return "void";
    }
    return "";
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
        // Support cast - keyed to what it grants. All snd_cast_* slots imported
        // (Batch 1); the legacy library fallbacks were retired in Batch 4.
        switch (_etype) {
            case "heal":     play_sfx_var("snd_cast_heal",   -1); break; // bright twinkle
            case "shield":   play_sfx_var("snd_cast_shield", -1); break; // defensive ward
            case "resource": play_sfx_var("snd_cast_buff",   -1); break; // arcane gain
            case "debuff":   play_sfx_var("snd_cast_debuff", -1); break; // ominous
            default:         play_sfx_var("snd_cast_buff",   -1); break; // generic self-buff
        }
        return;
    }

    // Offensive cast. First try the ability's specific magic SCHOOL (fire/frost/shock/
    // arcane/nature) so elemental spells don't collapse onto one snd_cast_elem; only
    // if the ability isn't a recognized school do we fall back to damage_type texture.
    var _school = ability_sfx_school(ab);
    if (_school != "") {
        play_sfx_var("snd_cast_" + _school, -1);
        return;
    }

    // Offensive cast - texture by damage type (0 phys - 1 elem - 2 drain/void - 3 blood).
    switch (_dtype) {
        case 0:  play_player_vocal("snd_player_atk", -1); break;      // human weapon strike (gendered)
        case 1:  play_sfx_var("snd_cast_elem",  -1); break;           // elemental cast
        case 2:  play_sfx_var("snd_cast_void",  -1); break;           // dark whoosh
        case 3:  play_sfx_var("snd_cast_blood", -1);
                 audio_play_sound(snd_player_atk, 1, false); break;   // blood (squelch + strike impact)
        default: play_sfx_var("snd_cast_arcane", -1);                 // arcane / other
    }
    // Class flavor: the Bloodwarden grunts with effort on physical strikes.
    if (variable_struct_exists(caster, "class_id") && caster.class_id == 1 && _dtype == 0) {
        play_sfx_var("snd_player_grunt", -1);
    }
}

// combat_on_enemy_defeated(target, player, combat_log) - shared kill handler:
// gold, loot, XP, on-kill soul generation, and Heartstone Aegis. Called by both
// the single-target and AoE damage paths so kill rewards never diverge.
// (#17 resolved as WORKING AS INTENDED, M 07-09: a Soulfire killing blow pays
// its own +2 AND the on-kill class harvest's +2 - the stack is deliberate.)
// Grant N of the player's class secondary resource (Cascade-rune pattern).
// Talent-web rider support; logs with the given source label.
function combat_grant_secondary(player, n, label, combat_log) {
    if (variable_struct_exists(player, "souls")) {
        player.souls = min(player.souls_max, player.souls + n);
        array_push(combat_log, label + ": +" + string(n) + " Soul" + ((n == 1) ? "" : "s") + ".");
    } else if (variable_struct_exists(player, "blood")) {
        player.blood = min(player.blood_max, player.blood + n);
        array_push(combat_log, label + ": +" + string(n) + " Blood.");
    } else if (variable_struct_exists(player, "preparation")) {
        player.preparation = min(player.preparation_max, player.preparation + n);
        array_push(combat_log, label + ": +" + string(n) + " Preparation.");
    }
}

// Talent-web ON-CAST riders (bespoke nodes - Iron Bulwark / Blood Ward /
// Shadow Feint): shields and resource gifts that fire at cast commit
// regardless of targeting. Called from BOTH cast paths in the controller.
function ability_web_cast_riders(ab, player, combat_log) {
    var _sh = ability_web_rider_value(ab, "cast_shield", 0);
    if (_sh > 0) {
        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
        player.shield_hp += _sh;
        array_push(combat_log, "Talent: +" + string(_sh) + " shield.");
    }
    var _cs = ability_web_rider_value(ab, "cast_sec", 0);
    if (_cs > 0) combat_grant_secondary(player, _cs, "Talent", combat_log);
}

function combat_on_enemy_defeated(target, player, combat_log) {
    target.is_defeated = true;
    enemy_death_sound(target.name);
    array_push(combat_log, target.name + " defeated!");

    // DEPTH WARDEN falls (08-13, DESIGN §2.1): flat 4% scion roll, once-per-save
    // per species (the 07-31 signature rule) - Wardens recur forever on the
    // cadence, so the chase stays open until the scion is finally caught.
    if (variable_struct_exists(target, "warden_hook")) {
        var _ws_id = warden_scion(target.name);
        if (_ws_id != "" && irandom(99) < warden_scion_drop_chance()) {
            // 08-17: art-gated like boss eggs - a scion whose art is not finished falls back
            // to a generic egg and is NOT marked found (stays catchable once its art lands).
            var _ws_live  = pet_species_has_art(_ws_id);
            var _ws_owned = _ws_live
                && variable_global_exists("pet_sig_history")
                && is_struct(global.pet_sig_history)
                && variable_struct_exists(global.pet_sig_history, _ws_id);
            if (!_ws_owned) {
                if (_ws_live) {
                    if (!variable_global_exists("pet_sig_history") || !is_struct(global.pet_sig_history)) {
                        global.pet_sig_history = {};
                    }
                    global.pet_sig_history[$ _ws_id] = true;
                }
                var _ws_pet = pet_grant_from_source("egg_boss", _ws_live ? _ws_id : "");
                array_push(combat_log, "Something small survived the Warden - "
                    + ((_ws_pet != undefined && !_ws_pet.is_egg) ? _ws_pet.name : "an egg")
                    + " is yours. Visit Bairc.");
            }
        }
        // The Bottom: the intended end of the ladder (08-14: now the full
        // treatment - persisted flag, "the Bottom's Witness" epithet unlocks
        // off it, and a center-screen splash banner armed here, drawn topmost
        // in combat Draw).
        if (target.warden_hook == "bottom") {
            global.descent_bottom_cleared = true;
            array_push(combat_log, "THE BOTTOM YIELDS. There is nothing below you now but the way back up.");
            if (instance_exists(obj_combat_controller)) {
                instance_find(obj_combat_controller, 0).bottom_splash_timer = 300;
            }
        }
    }

    // 08-09: a boss/elite/duel kill gets an actual explosion instead of just
    // vanishing into the death-linger fade. Trash mobs deliberately do NOT -
    // if every kill detonates, none of them land. Position reuses the standing
    // spot Draw stamps (last_ex/last_ey, sprite top-left at 3x).
    var _bk_kind = variable_global_exists("next_enemy_type") ? global.next_enemy_type : "";
    if ((_bk_kind == "boss" || _bk_kind == "elite" || global.duel_active)
        && variable_struct_exists(target, "last_ex") && variable_struct_exists(target, "last_ey")
        && instance_exists(obj_combat_controller)) {
        var _bk_map = enemy_sprite_map();
        var _bk_spr = variable_struct_exists(_bk_map, target.name)
                    ? variable_struct_get(_bk_map, target.name) : -1;
        var _bk_w = (_bk_spr >= 0) ? sprite_get_width(_bk_spr)  * 3 : 180;
        var _bk_h = (_bk_spr >= 0) ? sprite_get_height(_bk_spr) * 3 : 180;
        var _bk_cc = instance_find(obj_combat_controller, 0);
        array_push(_bk_cc.vfx_bursts, { spr: spr_vfx_boom,
                                        x: target.last_ex + _bk_w * 0.5,
                                        y: target.last_ey + _bk_h * 0.5,
                                        timer: 30, timer_max: 30, school: "" });
    }

    // Nightgorge dark gift (08-04): the cursed metal drinks - heal N on kill,
    // reduced by Mortality like every other heal.
    var _dg_ng = dark_gift_total("heal_on_kill");
    if (_dg_ng > 0 && player.HP > 0 && player.HP < player.max_HP) {
        var _dg_heal = min(player.max_HP - player.HP, combat_heal_after_mortality(player, _dg_ng));
        if (_dg_heal > 0) {
            player.HP += _dg_heal;
            array_push(combat_log, "Nightgorge drinks the kill - +" + string(_dg_heal) + " HP.");
        }
    }

    // Stamp the round of the latest kill ("Reaper's Tempo" web node reads it -
    // Soul Harvest pays +1 when an enemy died this same round).
    if (instance_exists(obj_combat_controller)) {
        global.last_kill_round = instance_find(obj_combat_controller, 0).combat_state.round;
    }

    // Marrow Crown (marrow_adder signature move, 08-05 pillar D): when the FIRST
    // enemy falls each combat, the weakest living survivor's marrow cracks - it
    // takes 10% of its own max HP. The flag is set BEFORE any damage so a crown
    // kill recursing back through here can't re-trigger it.
    if (pet_active_sig_move("marrow_crown") && !variable_struct_exists(player, "sig_crown_done")
        && instance_exists(obj_combat_controller)) {
        player.sig_crown_done = true;
        var _mc_cc   = instance_find(obj_combat_controller, 0);
        var _mc_weak = undefined;
        for (var _mc_i = 0; _mc_i < array_length(_mc_cc.combat_state.combatants); _mc_i++) {
            var _mc_c = _mc_cc.combat_state.combatants[_mc_i];
            if (_mc_c.is_player || _mc_c.is_defeated || _mc_c == target) continue;
            if (_mc_weak == undefined || _mc_c.HP < _mc_weak.HP) _mc_weak = _mc_c;
        }
        if (_mc_weak != undefined) {
            var _mc_dmg = max(1, round(_mc_weak.max_HP * 0.10));
            _mc_weak.HP        = max(0, _mc_weak.HP - _mc_dmg);
            _mc_weak.hit_flash = max(_mc_weak.hit_flash, 6);
            array_push(combat_log, "[Companion] " + pet_active().name + "'s MARROW CROWN cracks " + _mc_weak.name + "'s bones (" + string(_mc_dmg) + " damage)!");
            if (_mc_weak.HP <= 0 && !_mc_weak.is_defeated) combat_on_enemy_defeated(_mc_weak, player, combat_log);
        }
    }

    // Last Words (duskraven innate, 08-01): +15 gold when an ELITE falls. The
    // elite is the FIRST enemy slot of an elite encounter; its escort adds pay
    // nothing. (DoT kills use the inline Step_0 path and skip this - v1 scope.)
    if (pet_active_innate("elite_gold") > 0
        && variable_global_exists("next_enemy_type") && global.next_enemy_type == "elite"
        && instance_exists(obj_combat_controller)) {
        var _lw_cs = instance_find(obj_combat_controller, 0).combat_state;
        for (var _lw_i = 0; _lw_i < array_length(_lw_cs.combatants); _lw_i++) {
            if (_lw_cs.combatants[_lw_i].is_player) continue;
            if (_lw_cs.combatants[_lw_i] == target) {
                add_gold(pet_active_innate("elite_gold"));
                array_push(combat_log, "[Companion] " + pet_active().name + " collects " + target.name
                    + "'s last words (+" + string(pet_active_innate("elite_gold")) + "g).");
            }
            break;   // only the first enemy slot is the elite
        }
    }

    // Feast of Crows blessing (Shrine V2, 07-29): each corpse crowns you - +8%
    // damage and +2 armor per stack until the combat ends (reset per combat).
    if (boon_active("feast")) {
        if (!variable_global_exists("feast_stacks")) global.feast_stacks = 0;
        global.feast_stacks += 1;
        array_push(combat_log, "Feast of Crows: the crown swells (+"
            + string(global.feast_stacks * 8) + "% damage, +" + string(global.feast_stacks * 2) + " armor).");
    }

    // Pyre's Favor blessing (Shrine V2, 07-29): the corpse's remaining afflictions
    // detonate - every unspent DoT tick (value x turns left) erupts as one blast
    // onto each other living enemy. DoT builds turn packs into chain reactions.
    if (boon_active("pyre") && variable_struct_exists(target, "status_effects")
        && instance_exists(obj_combat_controller)) {
        var _py_sum = 0;
        for (var _py_i = 0; _py_i < array_length(target.status_effects); _py_i++) {
            var _py_se = target.status_effects[_py_i];
            if (combat_status_kind_of(_py_se) != "dot") continue;
            var _py_dur = variable_struct_exists(_py_se, "duration") ? _py_se.duration : 0;
            _py_sum += max(0, _py_se.effect_value * _py_dur);
        }
        if (_py_sum > 0) {
            var _py_cs   = instance_find(obj_combat_controller, 0).combat_state;
            var _py_hits = [];
            for (var _py_j = 0; _py_j < array_length(_py_cs.combatants); _py_j++) {
                var _py_c = _py_cs.combatants[_py_j];
                if (!_py_c.is_player && !_py_c.is_defeated && _py_c != target) array_push(_py_hits, _py_c);
            }
            if (array_length(_py_hits) > 0) {
                array_push(combat_log, "PYRE'S FAVOR - " + target.name + "'s afflictions detonate for "
                    + string(_py_sum) + " to every other foe!");
                for (var _py_k = 0; _py_k < array_length(_py_hits); _py_k++) {
                    var _py_t = _py_hits[_py_k];
                    combat_apply_damage(_py_t, _py_sum);
                    _py_t.hit_flash = max(_py_t.hit_flash, 12);
                    if (_py_t.HP <= 0 && !_py_t.is_defeated) combat_on_enemy_defeated(_py_t, player, combat_log);
                }
            }
        }
    }

    // Sanguine Chalice (07-28 legendary): overkill damage (HP driven below 0)
    // returns to the bearer as healing, up to 15.
    if (variable_struct_exists(player, "leg_chalice") && player.leg_chalice && target.HP < 0) {
        var _sc_heal = min(20, -target.HP);   // cap 15 -> 20 (07-29 M buff pass)
        var _sc_real = min(player.max_HP - player.HP, _sc_heal);
        if (_sc_real > 0) {
            player.HP += _sc_real;
            array_push(combat_log, "Sanguine Chalice: the excess returns to you (+" + string(_sc_real) + " HP).");
        }
    }

    // Oathbreaker's Shard (07-28 legendary): each killing blow swells the run's
    // vitality - +1 max HP for the rest of the run, cap +20. Rides the
    // run_bonus_max_hp channel (Second Wind built it); counter resets with the run.
    if (variable_struct_exists(player, "leg_shard") && player.leg_shard) {
        if (!variable_global_exists("oathbreaker_hp")) global.oathbreaker_hp = 0;
        if (global.oathbreaker_hp < 20) {
            global.oathbreaker_hp   += 1;
            if (!variable_global_exists("run_bonus_max_hp")) global.run_bonus_max_hp = 0;
            global.run_bonus_max_hp += 1;
            player.max_HP += 1;
            player.HP     += 1;
            array_push(combat_log, "Oathbreaker's Shard drinks the ending (+1 max HP this run).");
        }
    }

    // Plaguebearer TRANSCEND "Patient Zero" (POTENCY V2): the corpse's player-
    // sourced DoTs jump fresh to a random living enemy.
    if (trait_transcended("Plaguebearer") && variable_struct_exists(target, "status_effects")
        && instance_exists(obj_combat_controller)) {
        var _pz_cs = instance_find(obj_combat_controller, 0).combat_state;
        var _pz_hosts = [];
        for (var _pz_i = 0; _pz_i < array_length(_pz_cs.combatants); _pz_i++) {
            var _pz_c = _pz_cs.combatants[_pz_i];
            if (!_pz_c.is_player && !_pz_c.is_defeated && _pz_c != target
                && variable_struct_exists(_pz_c, "status_effects")) array_push(_pz_hosts, _pz_c);
        }
        if (array_length(_pz_hosts) > 0) {
            var _pz_jumped = false;
            var _pz_host = _pz_hosts[irandom(array_length(_pz_hosts) - 1)];
            for (var _pz_s = 0; _pz_s < array_length(target.status_effects); _pz_s++) {
                var _pz_se = target.status_effects[_pz_s];
                if (combat_status_kind_of(_pz_se) != "dot") continue;
                if (!variable_struct_exists(_pz_se, "source") || _pz_se.source != "player") continue;
                array_push(_pz_host.status_effects, {
                    name:         _pz_se.name,
                    effect_type:  _pz_se.effect_type,
                    kind:         "dot",
                    effect_value: _pz_se.effect_value,
                    duration:     max(2, _pz_se.duration),
                    element:      variable_struct_exists(_pz_se, "element") ? _pz_se.element : "",
                    source:       "player"
                });
                _pz_jumped = true;
            }
            if (_pz_jumped) array_push(combat_log, "Patient Zero: the affliction leaps to " + _pz_host.name + "!");
        }
    }

    // IRONMAN resume (SYSTEMS_RUN_RESUME.md): every reward roll for this kill
    // (gold, drops, runes, Devil's Pact bonus) runs on a deterministic stream
    // keyed to run/floor/room/spawn-slot, so quitting at the loot screen and
    // re-fighting yields IDENTICAL rewards - no quit-scum re-rolls. The real
    // RNG stream is restored right after the reward block.
    var _lseed_saved = random_get_seed();
    random_set_seed(loot_room_seed(variable_struct_exists(target, "drop_slot") ? target.drop_slot : 0, 1));

    // Gold drop (Greed boon: +50%; curse gold-find reward stacks on top)
    var _gold_drop = irandom(target.gold_max - target.gold_min) + target.gold_min;
    if (boon_active("greed")) {
        _gold_drop = round(_gold_drop * (1 + boon_value("greed")));
        // Greed V2 (07-29): elite/boss kills also drop a bonus purse (+75g).
        var _gr_type = variable_global_exists("next_enemy_type") ? global.next_enemy_type : "standard";
        if (_gr_type == "elite" || _gr_type == "boss") {
            _gold_drop += 75;
            array_push(combat_log, "Greed: a heavy purse tumbles loose (+75g).");
        }
    }
    _gold_drop = round(_gold_drop * curse_gold_mult());
    _gold_drop = round(_gold_drop * potion_gold_mult());   // Goldfinger Elixir (+gold, 2-boss buff)
    _gold_drop = round(_gold_drop * (1 + pet_active_boon_gold_pct() + pet_active_lck_gold_pct() + pet_active_splash_gold_pct() + pet_active_egg_bonus("gold") + pet_active_innate("gold") / 100));   // Fortune pet gift + universal LCK + Gilded-Soul splash + Gilded-egg hatchling + Gemcrust innate (08-01)
    add_gold(_gold_drop);
    global.current_run_kills++;
    global.total_kills++;   // lifetime counter - was initialized/saved/shown but never incremented (hub always read 0)
    quest_tick("kill_family", enemy_sound_family(target.name), 1);   // Phase 4a quest objective
    array_push(combat_log, "Gained " + string(_gold_drop) + "g!");

    // Item / consumable drop
    var _drop_type = variable_global_exists("next_enemy_type") ? global.next_enemy_type : "standard";
    var _drop_result = handle_enemy_drops(_drop_type);
    if (_drop_result != "") array_push(combat_log, "Loot: " + _drop_result + "!");

    // Devil's Pact curse: a guaranteed bonus equipment drop from every elite & boss.
    if (curse_has_bonus_drops() && (_drop_type == "elite" || _drop_type == "boss")) {
        // Curse loot-tiers are a post-roll rarity bump now, not an awakening offset.
        var _bonus_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
        var _bonus_item = drop_equipment(drop_weights(_drop_type, _bonus_asc), true, curse_loot_tier_bonus_for(_drop_type));
        if (variable_global_exists("run_items_found")) array_push(global.run_items_found, _bonus_item);
        if (variable_global_exists("carried_items"))   array_push(global.carried_items, _bonus_item);
        discover_item(item_base_name(_bonus_item), _bonus_item.rarity);
        array_push(combat_log, "Devil's Pact: " + _bonus_item.name + " [" + item_rarity_name(_bonus_item.rarity) + "]!");
    }

    random_set_seed(_lseed_saved);   // reward block over - back to the live stream

    // XP grant (floor-scaled)
    var _xp_base  = variable_struct_exists(target, "xp_value") ? target.xp_value : 10;
    var _xp_floor = variable_global_exists("current_floor") ? global.current_floor : 1;
    var _xp_scale = (_xp_floor == 2) ? 1.25 : ((_xp_floor >= 3) ? 1.5 : 1.0);
    var _xp_amt   = round(_xp_base * _xp_scale * awaken_xp_mult() * (1 + pet_active_egg_bonus("xp")));   // floor + Awakening (C3) + Scholar's egg
    var _xp_lvls  = grant_xp(_xp_amt);
    array_push(combat_log, "Gained " + string(_xp_amt) + " XP!");
    if (_xp_lvls > 0) {
        audio_play_sound(snd_sting_levelup, 1, false);
        array_push(combat_log, "LEVEL UP! Now level " + string(global.run_level) + ".");
    }

    // On-kill soul generation (Arcanist class passive). Logged as "class passive" -
    // the old "Soul Harvest: gained 2 Souls." line collided with the castable ability
    // that is ALSO named Soul Harvest, so kill souls looked like a mystery double-fire
    // on top of Soulfire's own +2 (M 07-09).
    if (player.class_id == 0 && variable_struct_exists(player, "souls")) {
        // Soul Harvester trunk node (P2, 08-05): +1 extra Soul on killing blows.
        var _soul_gain = 2 + (trunk_has("soul_kill_bonus") ? 1 : 0);
        player.souls = min(player.souls_max, player.souls + _soul_gain);
        array_push(combat_log, "Arcanist passive: +" + string(_soul_gain) + " Souls on the kill.");
    }
    if (player.class_id == 0 && variable_struct_exists(player, "souls") && trait_active("Soul Siphon")) {
        player.souls = min(player.souls_max, player.souls + 1);
        array_push(combat_log, "Soul Siphon: +1 Soul.");
    }

    // Cascade flagship rune (C6, M-approved 07-09): killing blows refund 1 of the
    // class's secondary resource.
    if (rune_aspect_socketed("cascade")) {
        if (variable_struct_exists(player, "souls")) {
            player.souls = min(player.souls_max, player.souls + 1);
            array_push(combat_log, "Cascade rune: +1 Soul.");
        } else if (variable_struct_exists(player, "blood")) {
            player.blood = min(player.blood_max, player.blood + 1);
            array_push(combat_log, "Cascade rune: +1 Blood.");
        } else if (variable_struct_exists(player, "preparation")) {
            player.preparation = min(player.preparation_max, player.preparation + 1);
            array_push(combat_log, "Cascade rune: +1 Preparation.");
        }
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
        var _aegis_heal = min(6, player.max_HP - player.HP);   // 5 -> 6 (07-29 M buff pass)
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

// ---------------------------------------------------------------------------
// combat_pet_act(combat_state, player, combat_log, damage_popups)
// The active pet's combat turn (Pets Phase 3, lightweight hook). Resolves ONCE when the
// player ends their turn, BEFORE the enemies act (You -> Pet -> Enemies). Only Combatant
// and Guardian pets at Stage 2+ act; Boon pets just stand present. The log + popup arrays
// are passed by reference so the pet can announce itself. Returns true if it acted (the
// caller then adds a brief pause before enemies). Numbers are conservative + TBD-balance.
// ---------------------------------------------------------------------------
// PET MOVE POOLS (M-locked 08-17): each fighting archetype draws from a small pool
// and a priority AI picks the move - every pick is NAMED in the combat log and
// gets its own VFX so the player can tell them apart.
//   COMBATANT: Strike (default) / Rend (no bleed on target: 75% dmg + bleed 2t)
//              / Pounce (target under 35% HP: +50% dmg)
//   GUARDIAN:  Mend (you under 40% HP) / Cleanse (a harmful status on you)
//              / Snarl (an undebuffed foe: Weakened -15% 2t) / Ward (shield)
//              - Mender / Warder / Cleanser stances still bias the pick.
// Boon pets never fight (unchanged).
function pet_move_pool_text(pet) {
    if (!is_struct(pet)) return "";
    switch (pet.archetype) {
        case PET_ARCH_COMBATANT: return "Strike / Rend / Pounce";
        case PET_ARCH_GUARDIAN:  return "Mend / Cleanse / Snarl / Ward";
    }
    return "";
}
// Push a one-shot VFX burst at a stage point (pet moves), tolerant of no controller.
function combat_pet_vfx(_x, _y, _spr, _school, _scale = 1.0) {
    if (!instance_exists(obj_combat_controller)) return;
    var _cc = instance_find(obj_combat_controller, 0);
    if (!variable_instance_exists(_cc, "vfx_bursts")) return;
    array_push(_cc.vfx_bursts, { spr: _spr, x: _x, y: _y, timer: 22, timer_max: 22, school: _school, scale: _scale });
}
function combat_enemy_vfx_point(_c) {
    if (variable_struct_exists(_c, "last_ecx")) return { x: _c.last_ecx, y: _c.last_ecy };
    if (variable_struct_exists(_c, "last_ex"))  return { x: _c.last_ex + 145, y: _c.last_ey + 145 };
    return { x: 1500, y: 300 };
}
// Enemy popup/VFX ANCHOR in the main-hit convention (popups go at y - 105): the
// foe's stamped visual centre in 2.5D (default), else the flat-row slot formula.
// One helper so status/pet/DoT popups land on the creature, not the HP-bar grid.
function combat_enemy_anchor(_c, _slot) {
    if (combat_25d() && is_struct(_c) && variable_struct_exists(_c, "last_ecx")) return { x: _c.last_ecx, y: _c.last_ecy };
    return { x: 1620 + _slot * (-120), y: 233 + _slot * 105 };
}

function combat_pet_act(combat_state, player, combat_log, damage_popups) {
    // Ashen Duelist (M-locked): the duel is STRICTLY 1v1 - the companion sits out.
    if (variable_global_exists("duel_active") && global.duel_active) return false;
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || _p.stage < PET_STAGE_YOUNGADULT) return false;
    var _adult = (_p.stage >= PET_STAGE_ADULT);
    var _imult = pet_injury_mult(_p.injured);   // injury weakens (tier 1) or benches (tier 2+) the pet
    _imult *= pet_hunger_mult(_p);              // hungry -25%; STARVING = benched (07-08)
    if (_imult <= 0) return false;
    if (pet_hp(_p) <= 0) return false;          // #20: knocked out - benched until healed (run end / food)
    var _cmult     = pet_corruption_mult(_p) * pet_bond_mult(_p) * pet_quirk_mult(_p);   // corruption +15%/run + Soul-bound +5% (§5 Axis 3) + quirks (08-01 pillar C)
    var _fulfilled = pet_is_fulfilled(_p);       // fully corrupted -> grand archetype ability
    var _kit = pet_kit_mods(_p);                 // named-kit modifiers (traits/abilities, Pets §5)

    // FULLY CORRUPTED price (M-locked 08-15, 10%/combat): once per fight the
    // dark can pull the leash - a corrupted Warrior turns its strike on YOU,
    // any other archetype withholds its aid for the turn. Curing removes this
    // forever (the strength stays); the corruption_fulfilled tutorial reveals
    // it as the hidden surprise.
    if (_fulfilled) {
        if (!variable_struct_exists(player, "pet_betray_hit")) player.pet_betray_hit = false;
        if (player.pet_betray_hit) {
            player.pet_betray_hit = false;
            if (_p.archetype == PET_ARCH_COMBATANT) {
                var _bt = max(1, round((_adult ? 16 : 8) * 0.75));
                player.HP = max(1, player.HP - _bt);
                array_push(combat_log, "[Companion] The corruption TURNS - " + _p.name + " savages YOU for " + string(_bt) + "!");
                array_push(damage_popups, { value: _bt, x: 505, y: 545, timer: 50, col: make_color_rgb(205, 90, 220) });
            } else {
                array_push(combat_log, "[Companion] " + _p.name + "'s eyes go black - it withholds its aid this turn.");
            }
            return true;
        }
    }

    var _stance = pet_stance(_p);   // combat stance (expression #3), set at the Gate

    if (_p.archetype == PET_ARCH_COMBATANT) {
        var _base = max(1, round((_adult ? 16 : 8) * _imult * _cmult * pet_stat_mult(_p, "pow") * (1 + _kit.dmg + pet_active_egg_bonus("dmg"))));
        // Guarded stance trades striking power for the intercept chance (rolled in the
        // enemy-attack path in obj_combat_controller Step).
        if (_stance == "guarded") _base = max(1, round(_base * 0.5));
        var _exec = (_kit.execute > 0) ? (1 + _kit.execute) : 1;   // Executioner capstone vs low-HP foes
        // Executioner slay threshold (BALANCE_NOTE C4, M-approved 07-09): in a
        // non-elite / non-boss encounter, its strike outright slays a target left
        // below 15% max HP. Room type is the encounter-rank source of truth.
        var _slay_ok = (_kit.execute > 0)
            && (!variable_global_exists("next_enemy_type")
                || (global.next_enemy_type != "elite" && global.next_enemy_type != "boss"));

        if (_fulfilled) {
            // GRAND: corrupted cleave - strike EVERY living enemy.
            var _slot = 0, _any = false;
            for (var _i = 0; _i < array_length(combat_state.combatants); _i++) {
                var _c = combat_state.combatants[_i];
                if (_c.is_player || _c.is_defeated) continue;
                var _cmul = (_c.max_HP > 0 && _c.HP < _c.max_HP * 0.30) ? _exec : 1;
                var _cd = combat_resolve_damage(round(_base * _cmul), 0, _c.armor, _c.el_resist);
                if (_cd < 1) _cd = 1;
                combat_apply_damage(_c, _cd);
                // Executioner slay (C4): finish a still-standing target under 15%.
                if (_slay_ok && _c.HP > 0 && _c.max_HP > 0 && _c.HP < _c.max_HP * 0.15) {
                    combat_apply_damage(_c, _c.HP);
                    array_push(combat_log, "[Companion] Executioner - " + _c.name + " is slain outright!");
                }
                var _cd_a = combat_enemy_anchor(_c, _slot);
                array_push(damage_popups, { value: _cd, x: _cd_a.x, y: _cd_a.y - 105, timer: 50, col: make_color_rgb(190, 120, 220) });
                if (_c.HP <= 0) combat_on_enemy_defeated(_c, player, combat_log);
                _slot++; _any = true;
            }
            if (_any) {
                array_push(combat_log, "[Companion] " + _p.name + " erupts - corrupted cleave hits all foes for " + string(_base) + "!");
                global.pet_lunge_t0 = current_time;   // procedural lunge (combat draw)
            }
            return _any;
        }

        // Target: lowest-HP living enemy (helps secure kills) - or, in ASSIST stance,
        // the enemy the player currently has targeted (falls back to lowest-HP when
        // the selection can't be resolved, e.g. the target just died).
        var _best = undefined, _bslot = -1, _live = 0;
        for (var _bi = 0; _bi < array_length(combat_state.combatants); _bi++) {
            var _bc = combat_state.combatants[_bi];
            if (_bc.is_player || _bc.is_defeated) continue;
            if (_best == undefined || _bc.HP < _best.HP) { _best = _bc; _bslot = _live; }
            _live++;
        }
        if (_stance == "assist" && instance_exists(obj_combat_controller)) {
            var _acc  = instance_find(obj_combat_controller, 0);
            var _want = variable_instance_exists(_acc, "selected_target") ? _acc.selected_target : -1;
            var _ai = 0;
            for (var _asi = 0; _asi < array_length(combat_state.combatants); _asi++) {
                var _ac = combat_state.combatants[_asi];
                if (_ac.is_player || _ac.is_defeated) continue;
                if (_ai == _want) { _best = _ac; _bslot = _ai; break; }
                _ai++;
            }
        }
        if (_best == undefined) return false;
        var _emul = (_best.max_HP > 0 && _best.HP < _best.max_HP * 0.30) ? _exec : 1;
        // Opportunist capstone (C5, M-approved 07-09): the strike DETONATES a status
        // the target carries (consumed) for +35%. Simplified to the flat form - pets
        // don't roll crits, so crit-flavored reactions cash out as the bonus too.
        var _opp = 1;
        if (_kit.opportunist > 0) {
            var _od = combat_detonator_pick(_best);
            if (_od.idx >= 0) {
                array_delete(_best.status_effects, _od.idx, 1);
                _opp = 1 + _kit.opportunist;
                array_push(combat_log, "[Companion] Opportunist - it detonates the affliction!");
            }
        }
        // --- MOVE PICK (08-17 pools): Pounce on a fading foe, Rend an unbled one, else Strike ---
        var _mv = "Strike";
        if (_best.max_HP > 0 && _best.HP < _best.max_HP * 0.35) _mv = "Pounce";
        else {
            var _mv_bled = false;
            for (var _mvi = 0; _mvi < array_length(_best.status_effects); _mvi++) {
                var _mvse = _best.status_effects[_mvi];
                if (combat_status_kind_of(_mvse) == "dot" && combat_status_element(_mvse) == "bleed") { _mv_bled = true; break; }
            }
            // Bleed-immune families (constructs/spirits) never get a wasted Rend.
            var _mv_imm = enemy_immunities(_best.name);
            for (var _mvk = 0; _mvk < array_length(_mv_imm); _mvk++) if (_mv_imm[_mvk].label == "Bleed") _mv_bled = true;
            if (!_mv_bled) _mv = "Rend";
        }
        var _mv_mul = (_mv == "Pounce") ? 1.5 : ((_mv == "Rend") ? 0.75 : 1.0);
        var _dmg = combat_resolve_damage(round(_base * _emul * _opp * _mv_mul), 0, _best.armor, _best.el_resist);
        if (_dmg < 1) _dmg = 1;
        combat_apply_damage(_best, _dmg);
        var _mv_pt = combat_enemy_vfx_point(_best);
        if (_mv == "Rend") {
            var _rend_tick = max(1, round((_adult ? 3 : 2) * _cmult));
            array_push(_best.status_effects, { name: "Rend", effect_type: "dot", kind: "dot",
                effect_value: _rend_tick, duration: 2, element: "bleed", source: "pet" });
            array_push(combat_log, "[Companion] " + _p.name + " uses REND - tears " + _best.name + " for " + string(_dmg)
                + " and leaves it bleeding (" + string(_rend_tick) + "/turn, 2 turns)!");
            combat_pet_vfx(_mv_pt.x, _mv_pt.y, spr_vfx_blood, "blood", 1.2);
        } else if (_mv == "Pounce") {
            array_push(combat_log, "[Companion] " + _p.name + " uses POUNCE - falls on the fading " + _best.name + " for " + string(_dmg) + " (+50%)!");
            combat_pet_vfx(_mv_pt.x, _mv_pt.y, spr_vfx_slash, "", 1.4);
        } else {
            combat_pet_vfx(_mv_pt.x, _mv_pt.y, spr_vfx_impact, "", 1.0);
        }
        if (_stance == "assist" && _best.HP > 0) {
            // Pack Tactics rider: leave the shared target Exposed (+2 dmg/hit, 2 turns).
            // Refresh an existing mark instead of stacking a second copy.
            var _pt_found = false;
            for (var _pti = 0; _pti < array_length(_best.status_effects); _pti++) {
                if (_best.status_effects[_pti].name == "Pack Tactics") {
                    _best.status_effects[_pti].duration = 2;
                    _pt_found = true;
                    break;
                }
            }
            if (!_pt_found) {
                array_push(_best.status_effects, {
                    name:         "Pack Tactics",
                    effect_type:  "debuff",
                    kind:         "vulnerable",
                    effect_value: 2,
                    duration:     2,
                    element:      "",
                    source:       "pet"
                });
            }
            array_push(combat_log, "[Companion] " + _p.name + " harries " + _best.name + " with you for " + string(_dmg) + " - Pack Tactics (+2 dmg taken/hit)!");
        } else if (_mv == "Strike") {
            array_push(combat_log, "[Companion] " + _p.name + " uses STRIKE on " + _best.name + " for " + string(_dmg) + "!");
        }
        var _bp_a = combat_enemy_anchor(_best, _bslot);
        array_push(damage_popups, { value: _dmg, x: _bp_a.x, y: _bp_a.y - 105, timer: 50, col: make_color_rgb(150, 215, 150) });
        // Executioner slay (C4): finish a still-standing target under 15%.
        if (_slay_ok && _best.HP > 0 && _best.max_HP > 0 && _best.HP < _best.max_HP * 0.15) {
            combat_apply_damage(_best, _best.HP);
            array_push(combat_log, "[Companion] Executioner - " + _best.name + " is slain outright!");
        }
        if (_best.HP <= 0) combat_on_enemy_defeated(_best, player, combat_log);
        // Bloodscent capstone (C5): a BLEEDING target that survives the strike is
        // struck again at half power - the smell of blood drives it.
        if (_kit.bloodscent > 0 && _best.HP > 0 && !_best.is_defeated
            && variable_struct_exists(_best, "status_effects")) {
            var _bs_bleeding = false;
            for (var _bsi = 0; _bsi < array_length(_best.status_effects); _bsi++) {
                var _bse = _best.status_effects[_bsi];
                if (combat_status_kind_of(_bse) == "dot" && combat_status_element(_bse) == "bleed") { _bs_bleeding = true; break; }
            }
            if (_bs_bleeding) {
                var _bs_dmg = combat_resolve_damage(max(1, round(_base * _kit.bloodscent)), 0, _best.armor, _best.el_resist);
                if (_bs_dmg < 1) _bs_dmg = 1;
                combat_apply_damage(_best, _bs_dmg);
                array_push(combat_log, "[Companion] Bloodscent - it tears at the bleeding " + _best.name + " again for " + string(_bs_dmg) + "!");
                var _bs_a = combat_enemy_anchor(_best, _bslot);
                array_push(damage_popups, { value: _bs_dmg, x: _bs_a.x, y: _bs_a.y - 135, timer: 50, col: make_color_rgb(220, 120, 120) });
                if (_best.HP <= 0) combat_on_enemy_defeated(_best, player, combat_log);
            }
        }
        global.pet_lunge_t0 = current_time;   // procedural lunge (combat draw)
        return true;
    }

    if (_p.archetype == PET_ARCH_GUARDIAN) {
        // One per turn normally (heal if hurt, else ward); a fulfilled Guardian does BOTH.
        // (Awakened splash hooks live in combat_pet_echo_open / combat_pet_vigil_check.)
        var _egg_mend = pet_active_egg_bonus("mend");
        var _smult    = pet_stat_mult(_p, "spr");   // SPR stat modifies heal & shield
        var _heal_amt = max(1, round((_adult ? 10 : 5) * _imult * _cmult * _smult * (1 + _kit.heal + _egg_mend)));
        var _sh_amt   = max(1, round((_adult ? 12 : 7) * _imult * _cmult * _smult * (1 + _kit.shield + _egg_mend)));

        // CLEANSER stance: strip the newest affliction first - that IS the turn when
        // it finds one; otherwise fall through to the balanced heal/ward heuristic.
        if (_stance == "cleanser") {
            var _cl = combat_cleanse(player, "one");
            if (_cl > 0) {
                array_push(combat_log, "[Companion] " + _p.name + " draws the affliction out of you.");
                return true;
            }
        }

        // --- PRIORITY AI (M-locked 08-17), unless a do-both capstone/fulfilled path owns
        //     the turn: MEND if you are under 40% -> CLEANSE a harmful status -> SNARL an
        //     undebuffed foe (Weakened -15%, 2 turns) -> fall through to Ward/Mend heuristic.
        //     Mender / Warder stances skip Snarl (they asked for pure support).
        if (!_fulfilled && !_kit.both) {
            if (player.HP < player.max_HP * 0.40) {
                var _mb = player.HP;
                player.HP = min(player.max_HP, player.HP + _heal_amt);
                var _mg = player.HP - _mb;
                if (_mg > 0) {
                    array_push(combat_log, "[Companion] " + _p.name + " uses MEND - closes your wounds (+" + string(_mg) + " HP).");
                    array_push(damage_popups, { value: _mg, x: 475, y: 545, timer: 50, col: make_color_rgb(120, 220, 140) });
                    var _mpa = combat_player_vfx_anchor(player);
                    combat_pet_vfx(_mpa.x + 110, _mpa.y + 110, spr_vfx_heal, "", 1.2);
                    return true;
                }
            }
            if (_stance != "mender" && _stance != "warder") {
                var _has_harm = false;
                for (var _hhi = 0; _hhi < array_length(player.status_effects); _hhi++) {
                    if (combat_status_is_debuff(player.status_effects[_hhi])) { _has_harm = true; break; }
                }
                if (_has_harm) {
                    var _cl2 = combat_cleanse(player, "one");
                    if (_cl2 > 0) {
                        array_push(combat_log, "[Companion] " + _p.name + " uses CLEANSE - draws the affliction out of you.");
                        var _cpa = combat_player_vfx_anchor(player);
                        combat_pet_vfx(_cpa.x + 110, _cpa.y + 110, spr_vfx_buff, "", 1.1);
                        return true;
                    }
                }
                // Snarl: the first living foe carrying NO debuff.
                var _sn = undefined, _sn_slot = 0, _sn_li = 0;
                for (var _sni = 0; _sni < array_length(combat_state.combatants); _sni++) {
                    var _snc = combat_state.combatants[_sni];
                    if (_snc.is_player || _snc.is_defeated) continue;
                    var _snc_deb = false;
                    for (var _snj = 0; _snj < array_length(_snc.status_effects); _snj++) {
                        if (combat_status_is_debuff(_snc.status_effects[_snj])) { _snc_deb = true; break; }
                    }
                    if (!_snc_deb) { _sn = _snc; _sn_slot = _sn_li; break; }
                    _sn_li++;
                }
                if (_sn != undefined && player.HP >= player.max_HP * 0.70) {
                    array_push(_sn.status_effects, { name: "Snarl", effect_type: "debuff", kind: "weaken",
                        effect_value: 0.15, duration: 2, element: "", source: "pet" });
                    array_push(combat_log, "[Companion] " + _p.name + " uses SNARL - " + _sn.name + " is Weakened (-15% dmg, 2 turns)!");
                    var _sn_pt = combat_enemy_vfx_point(_sn);
                    combat_pet_vfx(_sn_pt.x, _sn_pt.y, spr_fx_debuff_violet, "", 1.2);
                    var _sn_a = combat_enemy_anchor(_sn, _sn_slot);
                    array_push(damage_popups, { value: 0, text: "WEAKENED", x: _sn_a.x, y: _sn_a.y - 105, timer: 40, col: make_color_rgb(200, 160, 230) });
                    return true;
                }
            }
        }
        // Guardian Angel capstone (_kit.both) also makes it heal AND shield, like fulfilled.
        var _do_heal   = _fulfilled || _kit.both || (player.HP < player.max_HP * 0.70);
        var _do_shield = _fulfilled || _kit.both || (player.HP >= player.max_HP * 0.70);
        // Mender/Warder stances override the 70% heuristic (never the do-both cases).
        if (!_fulfilled && !_kit.both) {
            if (_stance == "mender") {
                _do_heal   = (player.HP < player.max_HP);
                _do_shield = !_do_heal;   // ward when there is nothing to mend
            } else if (_stance == "warder") {
                _do_heal   = false;
                _do_shield = true;
            }
        }
        var _did = false;
        if (_do_heal) {
            var _before = player.HP;
            player.HP = min(player.max_HP, player.HP + _heal_amt);
            var _gain = player.HP - _before;
            if (_gain > 0) {
                array_push(combat_log, "[Companion] " + _p.name + " uses MEND - tends your wounds (+" + string(_gain) + " HP).");
                var _mpa2 = combat_player_vfx_anchor(player);
                combat_pet_vfx(_mpa2.x + 110, _mpa2.y + 110, spr_vfx_heal, "", 1.2);
                array_push(damage_popups, { value: _gain, x: 475, y: 545, timer: 50, col: make_color_rgb(120, 220, 140) });
                _did = true;
            }
            // Lifespring capstone (C5, M-approved 07-09): once per combat its heal
            // also washes away the newest affliction. The player struct is
            // per-combat, so the used flag resets each fight.
            if (_kit.lifespring
                && (!variable_struct_exists(player, "lifespring_used") || !player.lifespring_used)) {
                var _ls = combat_cleanse(player, "one");
                if (_ls > 0) {
                    player.lifespring_used = true;
                    array_push(combat_log, "[Companion] Lifespring - the affliction washes away with the wound.");
                    _did = true;
                }
            }
        }
        if (_do_shield) {
            player.shield_hp += _sh_amt;
            array_push(combat_log, "[Companion] " + _p.name + " raises a ward (+" + string(_sh_amt) + " shield).");
            array_push(damage_popups, { value: _sh_amt, x: 475, y: 600, timer: 50, col: make_color_rgb(120, 185, 235) });
            _did = true;
        }
        return _did;
    }

    return false;
}

// ---------------------------------------------------------------------------
// AWAKENED SPLASH combat hooks (Stage 4 crossover, design 2026-07-03)
// ---------------------------------------------------------------------------
// combat_pet_echo_open(combat_state, player, combat_log, damage_popups)
// Feral Echo (Warrior splash on a non-Warrior pet): as combat begins, the pet lashes
// out once at a random living enemy - a modest PWR-scaled strike. Called from the
// combat controller Create, after the log/popup arrays exist. Injury tier 2+ benches
// the pet (same rule as its turn); the strike never crits and carries no riders.
function combat_pet_echo_open(combat_state, player, combat_log, damage_popups) {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || _p.stage < PET_STAGE_AWAKENED) return false;
    var _kit = pet_kit_mods(_p);
    if (_kit.echo <= 0) return false;
    var _imult = pet_injury_mult(_p.injured);
    _imult *= pet_hunger_mult(_p);   // hungry -25%; STARVING = benched (07-08)
    if (_imult <= 0) return false;
    if (pet_hp(_p) <= 0) return false;   // #20: knocked out - benched
    // Pick a random living enemy (it lashes out, it doesn't aim).
    var _live = [], _slots = [];
    var _slot = 0;
    for (var _i = 0; _i < array_length(combat_state.combatants); _i++) {
        var _c = combat_state.combatants[_i];
        if (_c.is_player || _c.is_defeated) continue;
        array_push(_live, _c); array_push(_slots, _slot);
        _slot++;
    }
    if (array_length(_live) == 0) return false;
    var _pick = irandom(array_length(_live) - 1);
    var _t = _live[_pick];
    var _base = max(1, round(_kit.echo * _imult * pet_corruption_mult(_p) * pet_bond_mult(_p) * pet_stat_mult(_p, "pow")));
    var _dmg  = combat_resolve_damage(_base, 0, _t.armor, _t.el_resist);
    if (_dmg < 1) _dmg = 1;
    combat_apply_damage(_t, _dmg);
    array_push(combat_log, "[Companion] " + _p.name + "'s Feral Echo lashes " + _t.name + " for " + string(_dmg) + " as battle begins!");
    var _fe_a = combat_enemy_anchor(_t, _slots[_pick]);
    array_push(damage_popups, { value: _dmg, x: _fe_a.x, y: _fe_a.y - 105, timer: 50, col: make_color_rgb(255, 150, 110) });
    if (_t.HP <= 0) combat_on_enemy_defeated(_t, player, combat_log);
    global.pet_lunge_t0 = current_time;   // reuse the procedural lunge (combat draw)
    return true;
}

// combat_pet_vigil_check(player, combat_log, damage_popups)
// Vigil (Guardian splash on a non-Guardian pet): ONCE per combat, the first time the
// player is below 40% HP, the pet instantly raises an SPR-scaled ward. Polled each
// step by the combat controller (catches any damage source); global.pet_vigil_used
// is reset on combat entry.
function combat_pet_vigil_check(player, combat_log, damage_popups) {
    if (variable_global_exists("pet_vigil_used") && global.pet_vigil_used) return false;
    if (player.HP <= 0 || player.HP >= player.max_HP * 0.40) return false;
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || _p.stage < PET_STAGE_AWAKENED) return false;
    var _kit = pet_kit_mods(_p);
    if (_kit.vigil <= 0) return false;
    var _imult = pet_injury_mult(_p.injured);
    if (_imult <= 0) return false;
    if (pet_hp(_p) <= 0) return false;   // #20: knocked out - benched
    global.pet_vigil_used = true;
    var _sh = max(1, round(_kit.vigil * _imult * pet_corruption_mult(_p) * pet_bond_mult(_p) * pet_stat_mult(_p, "spr")));
    player.shield_hp += _sh;
    array_push(combat_log, "[Companion] " + _p.name + " keeps its Vigil - a ward flares around you (+" + string(_sh) + " shield).");
    array_push(damage_popups, { value: _sh, x: 475, y: 600, timer: 50, col: make_color_rgb(140, 190, 255) });
    return true;
}
