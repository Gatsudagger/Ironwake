// =============================================================================
// scr_stats.gml
// Core stat definitions, class presets, and derived value calculations.
// Also houses global economy helpers (add_gold, end_run) so they are
// available from any object without requiring obj_game_controller's scope.
//
// Six base stats: STR, DEX, CON, INT, WIS, CHA
// Class IDs: 0 = Arcanist, 1 = Bloodwarden, 2 = Shadowstrider
// =============================================================================


// ---------------------------------------------------------------------------
// restock_shops()
// Regenerates Petra's special offer and Dorn's rotating gear list.
// Called at the end of end_run() and once at startup (after loot tables init).
// ---------------------------------------------------------------------------
function restock_shops() {
    // Petra special: 50% chance to stock one random elite consumable, qty 1-2
    global.petra_stock_special = undefined;
    global.petra_special_qty   = 0;
    if (irandom(99) < 50) {
        global.petra_stock_special = roll_consumable(global.consumables_elite);
        global.petra_special_qty   = 1 + irandom(1);
    }

    // Dorn: stock scales with the HIGHEST awakening unlocked (permanent meta growth).
    // Items are fully rolled (affixes), so his gear stays relevant past floor 1.
    // do_discover=false - shop items are only codex-revealed when actually bought.
    global.dorn_stock = [];
    var _dorn_awk     = highest_awakening_unlocked();
    var _dorn_weights = drop_weights("dorn", _dorn_awk);
    var _dorn_count   = 3 + (_dorn_awk >= 2 ? 1 : 0) + (_dorn_awk >= 4 ? 1 : 0);
    repeat (_dorn_count) {
        var _di     = drop_equipment(_dorn_weights, false);
        var _dprice = max(1, floor(_di.gold_value * 1.6));
        array_push(global.dorn_stock, { item: _di, price: _dprice, sold: false });
    }
}

// ---------------------------------------------------------------------------
// xp_threshold(level)
// Returns the cumulative XP required to reach `level` (not the delta).
// Level cap is 15.
// ---------------------------------------------------------------------------
function xp_threshold(level) {
    var _table = [0, 30, 60, 100, 150, 220, 300, 400, 520, 660, 820, 1000, 1200, 1420, 1660, 1920];
    if (level < 0)                    return _table[0];
    if (level >= array_length(_table)) return _table[array_length(_table) - 1];
    return _table[level];
}

// ---------------------------------------------------------------------------
// grant_xp(amount)
// Adds XP to global.run_xp and levels up while the threshold is met.
// Awards one pending_stat_point per level gained. Returns levels gained.
// ---------------------------------------------------------------------------
function grant_xp(amount) {
    if (!variable_global_exists("run_xp"))              return 0;
    if (!variable_global_exists("pending_stat_points")) return 0;

    global.run_xp += amount;
    var _gained = 0;

    while (global.run_level < 15
           && global.run_xp >= xp_threshold(global.run_level + 1)) {
        global.run_level++;
        global.pending_stat_points++;
        _gained++;
    }

    // Ratchet the persistent highest level ever reached (gates char_level abilities)
    if (variable_global_exists("highest_run_level")
        && global.run_level > global.highest_run_level) {
        global.highest_run_level = global.run_level;
    }

    // (Salvager & Chain Caster no longer auto-unlock by level - bought from Vex.)

    return _gained;
}

// ---------------------------------------------------------------------------
// add_gold(amount)
// Adds gold to both the lifetime pool and the current-run tracker.
// Always call this instead of writing global.gold directly so the per-run
// total stays accurate.
// ---------------------------------------------------------------------------
function add_gold(amount) {
    // Scavenger trait: +15% gold from all sources (scaled by Vex trait potency)
    if (trait_active("Scavenger")) {
        amount = ceil(amount * (1 + 0.15 * trait_potency_mult("Scavenger")));
    }
    // Gear "gold_find" affix (e.g. "of Greed"/"Lucky", +N%): boosts found gold.
    // apply_equipment_stats sums it across base stat + affixes + gear runes; a
    // throwaway struct is passed because we only need the returned gold_find total.
    var _gear_gf = apply_equipment_stats({}).gold_find;
    if (_gear_gf > 0) amount = ceil(amount * (1 + _gear_gf / 100));
    // Charisma: gold-find bonus on all earned gold (add_gold is the found-gold path;
    // item sells write global.gold directly and are intentionally unaffected).
    var _gf = cha_gold_find();
    if (_gf > 0) amount = ceil(amount * (1 + _gf));
    global.gold             += amount;
    global.current_run_gold += amount;
}

// =============================================================================
// CHARISMA - vendor discount + gold find. CHA is the "social" stat: it lowers
// NPC prices and raises gold earned. (Secret high-CHA shop is a future hook.)
// =============================================================================

// Effective Charisma = base allocation + run XP bonuses + permanent meta bonuses.
function player_effective_cha() {
    if (!variable_global_exists("chosen_stats")) return 0;
    var _cha = global.chosen_stats.CHA;
    if (variable_global_exists("run_stat_bonuses") && variable_struct_exists(global.run_stat_bonuses, "CHA")) _cha += global.run_stat_bonuses.CHA;
    if (variable_global_exists("perm_cha_bonus")) _cha += global.perm_cha_bonus;
    return max(0, _cha);
}

// Vendor discount fraction - 1.5% off per CHA point, capped at 30%.
function cha_discount() { return clamp(player_effective_cha() * 0.015, 0, 0.30); }

// Apply the CHA discount to a base gold price (min 1). Used at every NPC gold cost.
function cha_price(base_gold) { return max(1, round(base_gold * (1 - cha_discount()))); }

// Gold-find fraction - 1% more earned gold per CHA point, capped at 30%.
function cha_gold_find() { return clamp(player_effective_cha() * 0.01, 0, 0.30); }

// ---------------------------------------------------------------------------
// trainer_find_rare_item()
// Returns the lowest-rarity, lowest-value Rare-or-better (rarity >= 2) item held
// in the hub stash or carried pack - the one Vex will accept in trade for a stat
// upgrade. Player-friendly: never auto-picks a higher-rarity item over a Rare.
// Returns a { source, idx, item, rarity, value } struct, or undefined if none.
//   source 0 = global.equipment_stash, source 1 = global.carried_items
// ---------------------------------------------------------------------------
// trainer_find_item(min_rarity)
// Lowest-rarity, lowest-value trade item of at least min_rarity, across the stash
// and carried pack. Player-friendly: never auto-picks a higher-rarity item when a
// just-qualifying one exists. Rarity scale: 0 common,1 uncommon,2 rare,3 epic,4 legendary.
function trainer_find_item(min_rarity) {
    var _best = undefined;
    for (var _s = 0; _s < 2; _s++) {
        var _arr = (_s == 0) ? global.equipment_stash : global.carried_items;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _it = _arr[_i];
            if (!is_struct(_it)) continue;
            var _rar = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
            if (_rar < min_rarity) continue;
            var _val = variable_struct_exists(_it, "gold_value") ? _it.gold_value : 0;
            if (_best == undefined
                || _rar < _best.rarity
                || (_rar == _best.rarity && _val < _best.value)) {
                _best = { source: _s, idx: _i, item: _it, rarity: _rar, value: _val };
            }
        }
    }
    return _best;
}

// trainer_has_item(min_rarity) - true when a qualifying trade item exists.
function trainer_has_item(min_rarity) {
    return (trainer_find_item(min_rarity) != undefined);
}

// trainer_consume_item(min_rarity) - removes the item chosen by trainer_find_item()
// and returns its name, or "" if none qualified.
function trainer_consume_item(min_rarity) {
    var _f = trainer_find_item(min_rarity);
    if (_f == undefined) return "";
    var _name = variable_struct_exists(_f.item, "name") ? _f.item.name : "item";
    if (_f.source == 0) array_delete(global.equipment_stash, _f.idx, 1);
    else                array_delete(global.carried_items,   _f.idx, 1);
    return _name;
}

// Back-compat wrappers (Rare+ = min_rarity 2) - used by the Stats tab.
function trainer_find_rare_item()    { return trainer_find_item(2); }
function trainer_has_rare_item()     { return trainer_has_item(2); }
function trainer_consume_rare_item() { return trainer_consume_item(2); }

// ---------------------------------------------------------------------------
// end_run(result)
// Called when a run concludes. Snapshots run totals into last_run_* for the
// hub summary, updates lifetime progression, and resets per-run accumulators.
//
// result: 1 = victory, -1 = defeat
//
// On victory, gold is already in global.gold via add_gold() - no double-add.
// On defeat, gold earned this run is clawed back; floor at 0.
// ---------------------------------------------------------------------------
function end_run(result) {
    var _perm_earned = 0;
    var _end_level   = 1;
    if (variable_global_exists("run_level")) {
        _end_level = global.run_level;
    }
    global.run_count++;
    global.last_run_result = result;
    global.last_run_gold   = global.current_run_gold;
    global.last_run_kills  = global.current_run_kills;

    // Reset Last Stand for the next run (consumed at most once per run in combat)
    if (variable_global_exists("last_stand_used")) global.last_stand_used = false;

    if (result == 1) {
        // Victory - award hub unlock, record best floor, move carried items to safe stash
        global.hub_unlocks++;
        global.best_floor = max(global.best_floor, global.current_floor);
        for (var _ci = 0; _ci < array_length(global.carried_items); _ci++) {
            array_push(global.equipment_stash, global.carried_items[_ci]);
        }
        global.carried_items = [];
        global.last_run_mercy_item = "";
        // Consumables persist - player keeps unused potions

        // Ascendance auto-ratchet - full dungeon clear only (floor 3+). The permanent-
        // point conversion moved below so extract/retreat pay out too (see end of fn).
        if (global.current_floor >= 3) {
            // (Lucky Find now bought from Vex, not auto-unlocked on full clear.)

            // Ascendance auto-ratchet: unlock the next tier on a clear at/above current max
            if (variable_global_exists("selected_dungeon") && variable_global_exists("dungeon_ascendance_unlocked")
                && variable_global_exists("dungeon_clears") && variable_global_exists("selected_ascendance")) {
                var _dung_key = global.selected_dungeon;
                var _cur_max  = variable_struct_get(global.dungeon_ascendance_unlocked, _dung_key);
                var _clears   = variable_struct_get(global.dungeon_clears, _dung_key) + 1;
                variable_struct_set(global.dungeon_clears, _dung_key, _clears);
                if (variable_global_exists("dungeon_clears_total")) global.dungeon_clears_total++;
                if (global.selected_ascendance >= _cur_max && _cur_max < 5) {
                    var _new_max = min(5, _cur_max + 1);
                    variable_struct_set(global.dungeon_ascendance_unlocked, _dung_key, _new_max);
                }
                // Bonus gold reward scales with ascendance tier
                var _asc_gold_table = [0, 50, 100, 150, 200, 300];
                var _asc_gold_bonus = _asc_gold_table[global.selected_ascendance];
                add_gold(_asc_gold_bonus);
                // Scale run gold by 15% per ascendance tier (already added via add_gold during run)
                // - this bonus is on top, applied as a flat completion bonus
            }
        }

    } else if (result == 0) {
        // Extraction - keep all gold, update best floor, move carried items to safe stash
        global.best_floor = max(global.best_floor, global.current_floor);
        for (var _ci = 0; _ci < array_length(global.carried_items); _ci++) {
            array_push(global.equipment_stash, global.carried_items[_ci]);
        }
        global.carried_items = [];
        global.last_run_mercy_item = "";
        // Consumables persist

    } else {
        // Defeat - keep 25% of run gold as mercy, lose the rest
        var _mercy_gold = floor(global.current_run_gold * 0.25);
        var _lost_gold  = global.current_run_gold - _mercy_gold;
        global.gold = max(0, global.gold - _lost_gold);
        global.last_run_mercy_gold = _mercy_gold;

        // Secure items first (trait feature - inert while secure_slots == 0)
        for (var _si = 0; _si < global.secure_slots && _si < array_length(global.secured_items); _si++) {
            var _idx = global.secured_items[_si];
            if (_idx >= 0 && _idx < array_length(global.carried_items)) {
                array_push(global.equipment_stash, global.carried_items[_idx]);
            }
        }

        // Build the at-risk pool: all carried items + all consumables
        var _at_risk = [];
        for (var _ai = 0; _ai < array_length(global.carried_items); _ai++) {
            array_push(_at_risk, { item: global.carried_items[_ai], is_consumable: false });
        }
        for (var _ai = 0; _ai < array_length(global.consumable_inventory); _ai++) {
            array_push(_at_risk, { item: global.consumable_inventory[_ai], is_consumable: true });
        }

        // Salvage items on death - Salvager trait keeps 2 random items instead of 1
        global.last_run_mercy_item  = "";
        global.consumable_inventory = [];
        var _salvage_count = trait_active("Salvager") ? 2 : 1;
        if (array_length(_at_risk) > 0) {
            var _used_idxs = [];
            var _pool_sz   = array_length(_at_risk);
            for (var _sc = 0; _sc < _salvage_count; _sc++) {
                if (array_length(_used_idxs) >= _pool_sz) break;
                var _pick  = irandom(_pool_sz - 1);
                var _tries = 0;
                while (_tries < 20) {
                    var _dup = false;
                    for (var _di = 0; _di < array_length(_used_idxs); _di++) {
                        if (_used_idxs[_di] == _pick) { _dup = true; break; }
                    }
                    if (!_dup) break;
                    _pick = irandom(_pool_sz - 1);
                    _tries++;
                }
                array_push(_used_idxs, _pick);
                var _sv = _at_risk[_pick];
                if (_sc == 0) global.last_run_mercy_item = _sv.item.name;
                if (_sv.is_consumable) {
                    array_push(global.consumable_inventory, _sv.item);
                } else {
                    array_push(global.equipment_stash, _sv.item);
                }
            }
        }

        global.carried_items = [];
        global.secured_items = [];
    }

    // Permanent-point conversion - any SAFE return to the hub (full clear OR
    // extract/retreat) converts run level into permanent points: L5/10/15 -> 1/2/3.
    // Defeat (result -1) earns none. (Design: "Extract also pays out".)
    if (result != -1 && variable_global_exists("run_level")) {
        if      (global.run_level >= 15) _perm_earned = 3;
        else if (global.run_level >= 10) _perm_earned = 2;
        else if (global.run_level >= 5)  _perm_earned = 1;
        global.pending_perm_points += _perm_earned;
    }

    // Store perm points earned so the hub summary can display it
    global.last_run_perm_points = _perm_earned;

    // Append run record before zeroing accumulators so gold/kills are still live
    var _gold_kept_val = global.current_run_gold;
    if (result == -1) {
        _gold_kept_val = floor(global.current_run_gold * 0.25);
    }
    var _run_record = {
        run_number:         global.run_count,
        result:             result,
        gold_earned:        global.current_run_gold,
        gold_kept:          _gold_kept_val,
        kills:              global.current_run_kills,
        floor_reached:      global.current_floor,
        end_level:          _end_level,
        ascendance:         (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0),
        perm_points_earned: _perm_earned,
        items_found:        []
    };
    if (variable_global_exists("run_history")) {
        array_push(global.run_history, _run_record);
    }

    global.current_run_gold    = 0;
    global.current_run_kills   = 0;
    global.run_current_hp      = 0;
    global.run_souls           = 0;
    global.run_blood           = 0;
    global.run_preparation     = 0;
    global.run_items_found     = [];
    // consumable_inventory is managed per-result above for defeat;
    // for victory/extract it is left intact so potions carry forward.
    global.current_floor       = 1;
    global.floor_rooms_cleared = [];
    global.run_boons           = [];   // boons last one run only - clear for the next
    global.run_curses          = [];   // curses also last one run only (devil's bargain)

    // §6 variety: re-roll the floor seed for the NEXT run. Previously run_seed was
    // set once per session (obj_floor_controller Create) and never changed, so every
    // run built the IDENTICAL floors - a primary cause of "floors are often identical."
    // Forcing floor_map_floor stale guarantees the next floor 1 regenerates from the
    // new seed. Also reset the per-run no-repeat event tracker.
    global.run_seed             = irandom(99999) + 1;
    global.floor_map_floor      = -1;
    global.events_seen_this_run = [];

    global.just_cleared_boss   = false;
    global.just_cleared_room   = false;  // defensive: floor controller Create clears this, but reset here too
    global.current_room_index  = 0;      // defensive: floor controller Step sets this on entry, but reset here too

    // Reset per-run XP state
    global.run_xp              = 0;
    global.run_level           = 1;
    global.pending_stat_points = 0;
    global.run_stat_bonuses    = { STR: 0, DEX: 0, CON: 0, INT: 0, WIS: 0, CHA: 0 };

    // Restock shops for the next visit
    restock_shops();

    // Reset loadout confirmation so the player re-confirms next hub visit
    if (instance_exists(obj_game_controller)) {
        instance_find(obj_game_controller, 0).loadout_confirmed = false;
    }

    // Traits no longer auto-unlock at dungeon-clear milestones - they are bought
    // from Vex (Traits tab) for gold + a rarity-matched item. See SYSTEMS_VEX_REWORK.md.

    save_game();
}

// ---------------------------------------------------------------------------
// discover_item(item_name)
// Records an item name as discovered. Called on drop and on shop purchase.
// ---------------------------------------------------------------------------
function discover_item(item_name) {
    if (!variable_global_exists("items_discovered")) global.items_discovered = [];
    for (var _di = 0; _di < array_length(global.items_discovered); _di++) {
        if (global.items_discovered[_di] == item_name) return;
    }
    array_push(global.items_discovered, item_name);
}

// item_base_name(item) - the codex identity of an item. Affixes mutate `name`
// (e.g. "Iron Sword" -> "Sharp Iron Sword of the Bear"), so discovery must key on
// the immutable `base_name` to match the base loot-table entry in the codex.
function item_base_name(item) {
    if (is_struct(item) && variable_struct_exists(item, "base_name")) return item.base_name;
    if (is_struct(item) && variable_struct_exists(item, "name"))      return item.name;
    return "";
}

// item_stat_archetype(stat_name) - one-line "what this stat does for you" used by
// the generic item description. Covers the six core stats + affix-only stats.
function item_stat_archetype(stat_name) {
    switch (stat_name) {
        case "STR": return "raw physical power";
        case "DEX": return "precision and evasion";
        case "CON": return "endurance and survivability";
        case "INT": return "arcane and elemental might";
        case "WIS": return "status effects and focus";
        case "CHA": return "presence - prices and gold find";
        case "bonus_max_hp": return "extra health";
        case "crit_flat":    return "critical strike chance";
        case "dodge_flat":   return "evasion";
        case "gold_find":    return "gold found";
    }
    return "general utility";
}

// item_slot_noun(slot) - readable noun for a slot, used in generic descriptions.
function item_slot_noun(slot) {
    switch (slot) {
        case "weapon":  return "weapon";
        case "offhand": return "offhand";
        case "helm":    return "piece of headgear";
        case "chest":   return "set of body armor";
        case "gloves":  return "pair of handwear";
        case "boots":   return "pair of footwear";
        case "amulet":  return "amulet";
        case "ring":    return "ring";
    }
    return "piece of equipment";
}

// item_generic_desc(item) - auto-generated reference description from slot + primary
// stat. Used for every non-legendary item (legendaries show hand-written `lore`).
function item_generic_desc(item) {
    var _slot = variable_struct_exists(item, "slot")      ? item.slot      : "";
    var _stat = variable_struct_exists(item, "stat_name") ? item.stat_name : "";
    var _rar  = variable_struct_exists(item, "rarity")    ? item.rarity    : 0;
    return "A " + item_rarity_name(_rar) + " " + item_slot_noun(_slot)
         + " that rewards " + item_stat_archetype(_stat) + ".";
}

// item_affix_count_range(rarity) - [min, max] affixes a base of this rarity can roll.
// Mirrors drop_equipment: Common 0 - Uncommon 1 - Rare 1-2 - (Epic 2, from a rare base).
function item_affix_count_range(rarity) {
    switch (rarity) {
        case 0: return [0, 0];
        case 1: return [1, 1];
        case 2: return [1, 2];
        case 3: return [2, 2];
        case 4: return [1, 1];   // legendaries carry one fixed affix
    }
    return [0, 0];
}

// item_stat_ranges_text(base_item) - player-facing reference for how an item can roll.
// Base primary stat is fixed; affixes are the RNG. Scoped to the tiers a base can appear
// at (a Rare base also drops as Epic; an Uncommon base only as Uncommon, etc.).
function item_stat_ranges_text(base_item) {
    var _rar  = variable_struct_exists(base_item, "rarity")     ? base_item.rarity     : 0;
    var _sv   = variable_struct_exists(base_item, "stat_value") ? base_item.stat_value : 0;
    var _sn   = variable_struct_exists(base_item, "stat_name")  ? base_item.stat_name  : "";
    var _slot = variable_struct_exists(base_item, "slot")       ? base_item.slot       : "";
    var _has_unique = variable_struct_exists(base_item, "unique_effect") && base_item.unique_effect != "";
    var _txt  = _sn + " +" + string(_sv) + " (fixed base)";

    // Weapons also carry flat reach-gated damage - show it so the codex reflects the
    // weapon-roles system (melee vs ranged, 1H vs 2H).
    if (_slot == "weapon" || _slot == "ranged_weapon") {
        var _wd    = variable_struct_exists(base_item, "weapon_damage") ? base_item.weapon_damage : weapon_base_damage(_rar);
        var _reach = (_slot == "weapon") ? "melee" : "ranged";
        var _hands = (variable_struct_exists(base_item, "two_handed") && base_item.two_handed) ? "2H" : "1H";
        _txt = "Weapon dmg +" + string(_wd) + " (" + _reach + ", " + _hands + ")\n" + _txt;
    }

    if (_rar == 4) {
        _txt += "\nLegendary: fixed affix + unique effect (does not re-roll).";
        return _txt;
    }
    if (_rar == 0) {
        // A Common can still carry an intrinsic unique effect (e.g. class-starter
        // weapons) - distinguish that from a rolled affix so it doesn't read as a bug.
        _txt += _has_unique
            ? "\nCommon: no random affixes - its unique effect is built in."
            : "\nCommon: no affixes - what you see is what you get.";
        return _txt;
    }

    // Affix magnitudes from the pool: stat affixes +1/+2/+3, with bigger utility rolls.
    _txt += "\nAffixes roll at drop (random which + how many):";
    if (_rar == 1) {
        _txt += "\n  Uncommon: 1 affix  (+1 stat, or +5 HP / +3% crit-dodge-gold)";
    } else if (_rar == 2) {
        _txt += "\n  Rare: 1-2 affixes  (+2 stat, or +10 HP / +5%)";
        _txt += "\n  Epic: 2 affixes    (+3 stat, or +15 HP / +8%)";
    }
    return _txt;
}

// ---------------------------------------------------------------------------
// weapon_base_damage(rarity)
// Default flat weapon damage by rarity for weapon-slot items (melee + ranged).
// This is the reach-gated number (SYSTEMS_WEAPON_ROLES.md §B): it feeds only the
// abilities of the weapon's reach class, separate from any global +stat the weapon
// also carries. First-pass / tunable.
// ---------------------------------------------------------------------------
function weapon_base_damage(rarity) {
    switch (rarity) {
        case 0: return 3;    // Common
        case 1: return 5;    // Uncommon
        case 2: return 8;    // Rare
        case 3: return 11;   // Epic
        case 4: return 12;   // Legendary
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Elemental affix (SYSTEMS_WEAPON_ROLES.md §C). A weapon may carry ONE elemental
// affix: on a damaging ability of the weapon's REACH class it adds a small
// elemental hit AND applies that element's setup status, which feeds the
// detonation reactions (SYSTEMS_VIABILITY_PASS.md). The weapon's SLOT decides
// reach (no melee/ranged variant of the affix). Piggyback model (Option A):
//   burn  -> kind "dot"        (small fire DoT)            -> reaction +40% crit
//   frost -> kind "weaken"     (enemy attacks -10%)        -> reaction +30% shatter
//   shock -> kind "vulnerable" (target +N dmg taken/hit)   -> reaction shock arc
// so each status reuses already-wired passive reads, while its `element` tag
// drives the reaction + the distinct icon/VFX.
//
// elem_affix struct on the item:
//   { element, dmg, status_kind, status_value, status_dur, prefix, suffix }
// ---------------------------------------------------------------------------

// The three elemental affix families: naming + the setup status each applies.
function elem_affix_family(element) {
    switch (element) {
        case "burn":  return { prefix: "Flaming",       suffix: "of Embers", status_kind: "dot",        status_value: 3,    status_dur: 2 };
        case "frost": return { prefix: "Frostbound",    suffix: "of Frost",  status_kind: "weaken",     status_value: 0.10, status_dur: 2 };
        case "shock": return { prefix: "Storm-touched", suffix: "of Storms", status_kind: "vulnerable", status_value: 3,    status_dur: 2 };
    }
    return undefined;
}

// Flat elemental damage the affix adds, by item rarity (uncommon/rare/epic).
function elem_affix_damage(rarity) {
    switch (rarity) {
        case 1: return 2;   // Uncommon
        case 2: return 4;   // Rare
        case 3: return 6;   // Epic
    }
    return 0;
}

// elem_element_name(element) - display word for an element key.
function elem_element_name(element) {
    switch (element) {
        case "burn":  return "fire";
        case "frost": return "frost";
        case "shock": return "shock";
    }
    return element;
}

// dungeon_bias_school() - the current dungeon's elemental identity, used to lightly
// bias loot toward thematically matching gear (a fire dungeon drops more Fire gear,
// etc.). "" = no bias. Matches global.school_affix_pool school ids.
function dungeon_bias_school() {
    var _d = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "";
    switch (_d) {
        case "scorched_depths": return "fire";
        case "tundra_tomb":     return "frost";
        case "ashen_vault":     return "void";   // ashen/wraith vault theme
    }
    return "";
}

// dungeon_bias_element() - the weapon elemental-affix element (burn/frost/shock)
// favored by the current dungeon, or "" if the dungeon has no matching element.
function dungeon_bias_element() {
    switch (dungeon_bias_school()) {
        case "fire":  return "burn";
        case "frost": return "frost";
        case "shock": return "shock";
    }
    return "";   // void/neutral dungeons: no matching weapon elemental affix
}

// roll_elemental_affix(rarity) - returns an elem_affix struct for a weapon of the
// given rarity, or undefined if none rolled. Only uncommon/rare/epic roll, ~40%
// chance (a notable but not guaranteed roll). The element is biased toward the
// current dungeon's element (fire dungeon -> more burn weapons, etc.).
function roll_elemental_affix(rarity) {
    if (rarity < 1 || rarity > 3) return undefined;   // common/legendary: no rolled elem affix
    if (irandom(99) >= 40) return undefined;          // ~40% chance
    var _elements = ["burn", "frost", "shock"];
    var _bias     = dungeon_bias_element();
    var _element;
    if (_bias != "" && irandom(99) < 60) {
        _element = _bias;                              // dungeon-themed ~60% of rolls
    } else {
        _element = _elements[irandom(2)];
    }
    var _fam      = elem_affix_family(_element);
    if (_fam == undefined) return undefined;
    return {
        element:      _element,
        dmg:          elem_affix_damage(rarity),
        status_kind:  _fam.status_kind,
        status_value: _fam.status_value,
        status_dur:   _fam.status_dur,
        prefix:       _fam.prefix,
        suffix:       _fam.suffix,
    };
}

// make_elem_affix(element, rarity) - build a specific elemental affix (for
// hand-authored demo/loot weapons rather than a random roll).
function make_elem_affix(element, rarity) {
    var _fam = elem_affix_family(element);
    if (_fam == undefined) return undefined;
    return {
        element:      element,
        dmg:          elem_affix_damage(rarity),
        status_kind:  _fam.status_kind,
        status_value: _fam.status_value,
        status_dur:   _fam.status_dur,
        prefix:       _fam.prefix,
        suffix:       _fam.suffix,
    };
}

// apply_elemental_affix_to_item(item, elem) - store the affix, fold its name in
// (prefix form, or suffix form if a stat affix already prefixed the name), and
// bump gold value.
function apply_elemental_affix_to_item(item, elem) {
    if (elem == undefined) return;
    item.elem_affix = elem;
    var _has_prefix = (variable_struct_exists(item, "affixes") && array_length(item.affixes) >= 2);
    if (_has_prefix) item.name = item.name + " " + elem.suffix;
    else             item.name = elem.prefix + " " + item.name;
    item.gold_value = round(item.gold_value * 1.25);
}

// _clone_elem_affix(src) - deep-copy an item's elem_affix so a clone never shares
// the struct with its source (returns undefined when there is none).
function _clone_elem_affix(src) {
    if (!variable_struct_exists(src, "elem_affix") || src.elem_affix == undefined) return undefined;
    var _e = src.elem_affix;
    return {
        element:      _e.element,
        dmg:          _e.dmg,
        status_kind:  _e.status_kind,
        status_value: _e.status_value,
        status_dur:   _e.status_dur,
        prefix:       _e.prefix,
        suffix:       _e.suffix,
    };
}

// elem_affix_describe(elem) - one-line tooltip/codex text for an elemental affix.
function elem_affix_describe(elem) {
    if (elem == undefined) return "";
    var _st = "";
    switch (elem.status_kind) {
        case "dot":        _st = "applies Burn (" + string(elem.status_value) + " dmg/turn)"; break;
        case "weaken":     _st = "applies Chill (foe deals -" + string(round(elem.status_value * 100)) + "% dmg)"; break;
        case "vulnerable": _st = "applies Shock (foe takes +" + string(elem.status_value) + " dmg/hit)"; break;
    }
    return "+" + string(elem.dmg) + " " + elem_element_name(elem.element) + " dmg on hit, " + _st;
}

// create_item(name, slot, rarity, stat_name, stat_value, effect_desc, gold_value)
// Returns an equipment item struct. Rarity: 0=common, 1=uncommon, 2=rare,
// 3=epic, 4=legendary.
// ---------------------------------------------------------------------------
function create_item(name, slot, rarity, stat_name, stat_value, effect_desc, gold_value) {
    // Weapon-slot items get a flat, reach-gated weapon_damage; all other gear = 0.
    var _wpn_dmg = (slot == "weapon" || slot == "ranged_weapon") ? weapon_base_damage(rarity) : 0;
    return {
        name:          name,
        base_name:     name,   // immutable identity for the codex (affixes mutate `name`)
        item_category: "equipment",
        slot:          slot,
        rarity:        rarity,
        stat_name:     stat_name,
        stat_value:    stat_value,
        weapon_damage: _wpn_dmg,                          // flat reach-gated damage (weapons only)
        two_handed:    false,                             // 2H weapons lock the offhand slot (set post-create)
        elem_affix:    undefined,                         // elemental affix (SYSTEMS_WEAPON_ROLES.md §C); set post-create
        effect_desc:   effect_desc,
        gold_value:    gold_value,
        socket_count:  rune_sockets_for_rarity(rarity),   // rune sockets by rarity
        runes:         []                                  // socketed gear runes
    };
}

// ---------------------------------------------------------------------------
// item_rarity_name(rarity)
// Returns the display string for a rarity integer.
// ---------------------------------------------------------------------------
function item_rarity_name(rarity) {
    switch (rarity) {
        case 0: return "Common";
        case 1: return "Uncommon";
        case 2: return "Rare";
        case 3: return "Epic";
        case 4: return "Legendary";
    }
    return "Common";
}

// ---------------------------------------------------------------------------
// item_rarity_color(rarity)
// Returns a draw color for a rarity integer.
// ---------------------------------------------------------------------------
function item_rarity_color(rarity) {
    switch (rarity) {
        case 0: return c_white;                            // Common   - white
        case 1: return make_color_rgb(100, 200, 100);     // Uncommon - green
        case 2: return make_color_rgb(80, 140, 255);      // Rare     - blue
        case 3: return make_color_rgb(180, 80, 255);      // Epic     - purple
        case 4: return make_color_rgb(255, 160, 30);      // Legendary - orange
    }
    return c_white;
}

// ---------------------------------------------------------------------------
// create_consumable(name, effect_type, effect_value, description, gold_value)
// Returns a consumable item struct for inventory and drop systems.
// ---------------------------------------------------------------------------
function create_consumable(name, effect_type, effect_value, description, gold_value) {
    return {
        name:          name,
        item_category: "consumable",
        effect_type:   effect_type,
        effect_value:  effect_value,
        description:   description,
        gold_value:    gold_value
    };
}

// ---------------------------------------------------------------------------
// out_of_combat_max_hp() - the player's max HP outside combat, mirroring the
// read-only stats view the character menu builds (base stats + equipment + run
// XP bonuses + permanent meta bonuses). Used to cap heals applied on the hub /
// floor map where there is no combat player object to read max_HP from.
// ---------------------------------------------------------------------------
function out_of_combat_max_hp() {
    if (!variable_global_exists("chosen_stats") || is_undefined(global.chosen_stats)) return 1;
    var _b  = global.chosen_stats;
    var _sv = {
        class_id: _b.class_id, class_name: _b.class_name,
        STR: _b.STR, DEX: _b.DEX, CON: _b.CON, INT: _b.INT, WIS: _b.WIS, CHA: _b.CHA,
        free_points: _b.free_points,
    };
    var _bonus = apply_equipment_stats(_sv);
    if (variable_global_exists("run_stat_bonuses")) {
        _sv.STR += global.run_stat_bonuses.STR; _sv.DEX += global.run_stat_bonuses.DEX;
        _sv.CON += global.run_stat_bonuses.CON; _sv.INT += global.run_stat_bonuses.INT;
        _sv.WIS += global.run_stat_bonuses.WIS; _sv.CHA += global.run_stat_bonuses.CHA;
    }
    if (variable_global_exists("perm_str_bonus")) {
        _sv.STR += global.perm_str_bonus; _sv.DEX += global.perm_dex_bonus;
        _sv.CON += global.perm_con_bonus; _sv.INT += global.perm_int_bonus;
        _sv.WIS += global.perm_wis_bonus; _sv.CHA += global.perm_cha_bonus;
    }
    var _max = stats_derive(_sv).HP + _bonus.bonus_max_hp;

    // Static trait max-HP multiplier (Thick Skin) - applied FIRST, exactly as
    // obj_combat_controller/Create_0 folds it in before the boon/curse mults, so
    // the floor/hub readout matches the in-fight max.
    var _tm = trait_maxhp_mult();
    if (_tm != 1.0) _max = max(1, round(_max * _tm));

    // Apply the SAME run boon/curse max-HP multipliers combat does (Ironhide/Glass
    // Cannon, then Frail/Ruin/Devil's Pact), each rounded in sequence exactly as
    // obj_combat_controller/Create_0 - otherwise the floor/hub HP readout disagrees
    // with the in-fight bar and can even clamp the shown current HP too low.
    var _bm = boon_maxhp_mult();
    if (_bm != 1.0) _max = max(1, round(_max * _bm));
    var _cm = curse_maxhp_mult();
    if (_cm != 1.0) _max = max(1, round(_max * _cm));
    return _max;
}

// ---------------------------------------------------------------------------
// out_of_combat_dmg_derived() - the damage-bonus view used to PREVIEW ability
// damage in the character menu when no combat player exists. Rebuilds the
// equipment-adjusted stats (same assembly as out_of_combat_max_hp) and returns a
// struct shaped like player.derived's damage fields, so combat_estimate_hit() can
// estimate "current damage with equipment" out of combat too.
// ---------------------------------------------------------------------------
function out_of_combat_dmg_derived() {
    var _empty = { phys_dmg_bonus: 0, elem_dmg_bonus: 0, cha_dmg_bonus: 0,
                   melee_dmg_bonus: 0, ranged_dmg_bonus: 0 };
    if (!variable_global_exists("chosen_stats") || is_undefined(global.chosen_stats)) return _empty;
    var _b  = global.chosen_stats;
    var _sv = {
        class_id: _b.class_id, class_name: _b.class_name,
        STR: _b.STR, DEX: _b.DEX, CON: _b.CON, INT: _b.INT, WIS: _b.WIS, CHA: _b.CHA,
        free_points: _b.free_points,
    };
    var _bonus = apply_equipment_stats(_sv);   // mutates _sv stats, returns equip bonus
    if (variable_global_exists("run_stat_bonuses")) {
        _sv.STR += global.run_stat_bonuses.STR; _sv.DEX += global.run_stat_bonuses.DEX;
        _sv.CON += global.run_stat_bonuses.CON; _sv.INT += global.run_stat_bonuses.INT;
        _sv.WIS += global.run_stat_bonuses.WIS; _sv.CHA += global.run_stat_bonuses.CHA;
    }
    if (variable_global_exists("perm_str_bonus")) {
        _sv.STR += global.perm_str_bonus; _sv.DEX += global.perm_dex_bonus;
        _sv.CON += global.perm_con_bonus; _sv.INT += global.perm_int_bonus;
        _sv.WIS += global.perm_wis_bonus; _sv.CHA += global.perm_cha_bonus;
    }
    var _d = stats_derive(_sv);
    return {
        phys_dmg_bonus:   _d.phys_dmg_bonus,
        elem_dmg_bonus:   _d.elem_dmg_bonus,
        cha_dmg_bonus:    _d.cha_dmg_bonus,
        melee_dmg_bonus:  variable_struct_exists(_bonus, "melee_dmg_bonus")  ? _bonus.melee_dmg_bonus  : 0,
        ranged_dmg_bonus: variable_struct_exists(_bonus, "ranged_dmg_bonus") ? _bonus.ranged_dmg_bonus : 0,
    };
}

// ---------------------------------------------------------------------------
// consumable_use_out_of_combat(item) - apply a consumable when NO combat is
// active (hub / floor map). Returns true if it was used (caller should remove
// it), false if it has no effect here so the item is NOT wasted. Only direct
// heals work out of combat; AP/cleanse/shield/heal-over-time need combat turns.
// ---------------------------------------------------------------------------
function consumable_use_out_of_combat(item) {
    var _et = variable_struct_exists(item, "effect_type") ? item.effect_type : "";
    if (_et == "heal") {
        var _max = out_of_combat_max_hp();
        if (!variable_global_exists("run_current_hp") || global.run_current_hp <= 0) {
            global.run_current_hp = _max;
        }
        global.run_current_hp = min(_max, global.run_current_hp + item.effect_value);
        return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// create_weapon(name, rarity, stat_name, stat_value, effect_desc, gold_value, class_req)
// Convenience wrapper around create_item that also sets the class_req field.
// class_req: -1=any, 0=Arcanist, 1=Bloodwarden, 2=Shadowstrider.
// ---------------------------------------------------------------------------
function create_weapon(name, rarity, stat_name, stat_value, effect_desc, gold_value, class_req) {
    var _w = create_item(name, "weapon", rarity, stat_name, stat_value, effect_desc, gold_value);
    _w.class_req = class_req;
    return _w;
}

// ---------------------------------------------------------------------------
// clone_item(src)
// Returns a deep copy of an item struct with a fresh, empty affixes array.
// Existing affixes on src (e.g. legendaries) are copied entry-by-entry.
// Always call this before adding affixes to a drop so templates are never mutated.
// ---------------------------------------------------------------------------
function clone_item(src) {
    var _c = {
        name:          src.name,
        base_name:     variable_struct_exists(src, "base_name") ? src.base_name : src.name,
        item_category: "equipment",
        slot:          src.slot,
        rarity:        src.rarity,
        stat_name:     src.stat_name,
        stat_value:    src.stat_value,
        weapon_damage: variable_struct_exists(src, "weapon_damage") ? src.weapon_damage : 0,
        two_handed:    variable_struct_exists(src, "two_handed")    ? src.two_handed    : false,
        elem_affix:    _clone_elem_affix(src),
        effect_desc:   src.effect_desc,
        gold_value:    src.gold_value,
        class_req:     variable_struct_exists(src, "class_req")     ? src.class_req     : -1,
        unique_effect: variable_struct_exists(src, "unique_effect") ? src.unique_effect : "",
        unique_desc:   variable_struct_exists(src, "unique_desc")   ? src.unique_desc   : "",
        lore:          variable_struct_exists(src, "lore")          ? src.lore          : "",
        affixes:       [],
        socket_count:  variable_struct_exists(src, "socket_count")  ? src.socket_count  : rune_sockets_for_rarity(src.rarity),
        runes:         [],
    };
    if (variable_struct_exists(src, "affixes")) {
        for (var _i = 0; _i < array_length(src.affixes); _i++) {
            var _af = src.affixes[_i];
            array_push(_c.affixes, {
                suffix:     variable_struct_exists(_af, "suffix") ? _af.suffix : "",
                prefix:     variable_struct_exists(_af, "prefix") ? _af.prefix : "",
                stat_name:  _af.stat_name,
                stat_value: _af.stat_value,
            });
        }
    }
    // Deep-copy socketed runes so the clone never shares rune structs with src.
    if (variable_struct_exists(src, "runes")) {
        for (var _ri = 0; _ri < array_length(src.runes); _ri++) {
            var _sr = src.runes[_ri];
            array_push(_c.runes, rune_make(_sr.id, _sr.tier));
        }
    }
    return _c;
}

// ---------------------------------------------------------------------------
// school_affix_value(rarity) - flat "+X <school> damage" magnitude by item
// rarity for a ROLLED school affix (SYSTEMS_ELEMENT_SCHOOLS.md §C/§F1):
// uncommon +1, rare +2-4 (cap 4), epic +5-6. Common/legendary never roll one.
// ---------------------------------------------------------------------------
function school_affix_value(rarity) {
    switch (rarity) {
        case 1: return 1;                    // uncommon
        case 2: return irandom_range(2, 4);  // rare (cap 4)
        case 3: return irandom_range(5, 6);  // epic
    }
    return 0;
}

// ---------------------------------------------------------------------------
// slot_is_caster_affix(slot, base_name) - true if this item is a "caster slot"
// eligible for rolled school-damage affixes: amulet, ring, or a FOCUS-TYPE
// offhand (orb/wand/focus/etc.). Shields and other offhands are excluded so
// they never roll "+spell damage".
// ---------------------------------------------------------------------------
function slot_is_caster_affix(slot, base_name) {
    if (slot == "amulet" || slot == "ring") return true;
    if (slot == "offhand") {
        var _bn = string_lower(base_name);
        var _kw = ["focus", "orb", "wand", "scepter", "tome", "idol", "sigil", "grimoire"];
        for (var _i = 0; _i < array_length(_kw); _i++) {
            if (string_pos(_kw[_i], _bn) > 0) return true;
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// roll_affixes(rarity, count, exclude_stat_names, slot, base_name)
// Returns an array of affix structs chosen from global.affix_pool.
// No duplicate stat_names. exclude_stat_names prevents doubling the base stat.
// rarity: 1=uncommon, 2=rare, 3=epic (determines magnitude).
// On caster slots (slot/base_name eligible per slot_is_caster_affix), each affix
// slot has SCHOOL_AFFIX_CHANCE% to roll a flat school-damage affix from
// global.school_affix_pool instead of a stat affix. Dedup keys on stat_name, so
// two DIFFERENT schools can appear on a 2-affix item but never two of the same.
// ---------------------------------------------------------------------------
function roll_affixes(rarity, count, exclude_stat_names, slot = "", base_name = "") {
    if (!variable_global_exists("affix_pool")) return [];
    var _pool    = global.affix_pool;
    var _result  = [];
    var _used    = [];
    for (var _ei = 0; _ei < array_length(exclude_stat_names); _ei++) {
        array_push(_used, exclude_stat_names[_ei]);
    }

    // Caster gear may swap a stat affix for a flat school-damage affix per slot.
    var SCHOOL_AFFIX_CHANCE = 40;   // % chance per affix slot (tunable)
    var _school_pool = (variable_global_exists("school_affix_pool")
                        && slot_is_caster_affix(slot, base_name))
                       ? global.school_affix_pool : [];

    var _tries = 0;
    while (array_length(_result) < count && _tries < 60) {
        _tries++;
        var _dup = false;

        // School affix branch (caster slots only). The school is biased toward the
        // current dungeon's school (fire dungeon -> more Fire-damage caster gear).
        if (array_length(_school_pool) > 0 && irandom(99) < SCHOOL_AFFIX_CHANCE) {
            var _sf = _school_pool[irandom(array_length(_school_pool) - 1)];
            var _bias_school = dungeon_bias_school();
            if (_bias_school != "" && irandom(99) < 55) {
                for (var _bsi = 0; _bsi < array_length(_school_pool); _bsi++) {
                    if (_school_pool[_bsi].school == _bias_school) { _sf = _school_pool[_bsi]; break; }
                }
            }
            for (var _di = 0; _di < array_length(_used); _di++) {
                if (_used[_di] == _sf.stat_name) { _dup = true; break; }
            }
            if (_dup) continue;
            var _sval = school_affix_value(rarity);
            if (_sval <= 0) continue;
            array_push(_used, _sf.stat_name);
            array_push(_result, {
                suffix:     _sf.suffix,
                prefix:     _sf.prefix,
                stat_name:  _sf.stat_name,
                stat_value: _sval,
            });
            continue;
        }

        // Standard stat affix.
        var _idx = irandom(array_length(_pool) - 1);
        var _af  = _pool[_idx];
        for (var _di = 0; _di < array_length(_used); _di++) {
            if (_used[_di] == _af.stat_name) { _dup = true; break; }
        }
        if (_dup) continue;
        array_push(_used, _af.stat_name);

        var _val;
        if (rarity == 1)      _val = _af.u_val;
        else if (rarity == 2) _val = _af.r_val;
        else                  _val = _af.e_val;

        array_push(_result, {
            suffix:     _af.suffix,
            prefix:     _af.prefix,
            stat_name:  _af.stat_name,
            stat_value: _val,
        });
    }
    return _result;
}

// ---------------------------------------------------------------------------
// apply_affixes_to_item(item, affixes)
// Pushes affixes onto item.affixes, updates item.name with prefix/suffix, and
// adjusts gold_value (+20% per affix, rounded).
// ---------------------------------------------------------------------------
function apply_affixes_to_item(item, affixes) {
    var _count = array_length(affixes);
    if (_count == 0) return;

    for (var _i = 0; _i < _count; _i++) {
        array_push(item.affixes, affixes[_i]);
    }

    // Name: 1 affix -> append suffix; 2 affixes -> prefix + name + last suffix
    if (_count == 1) {
        item.name = item.name + " " + affixes[0].suffix;
    } else {
        item.name = affixes[0].prefix + " " + item.name + " " + affixes[_count - 1].suffix;
    }

    // +20% gold_value per affix
    item.gold_value = round(item.gold_value * power(1.2, _count));
}

// ---------------------------------------------------------------------------
// highest_awakening_unlocked()
// Returns the maximum ascendance/awakening tier unlocked across ALL dungeons.
// Used by the shop (Dorn) to permanently grow with meta progression.
// ---------------------------------------------------------------------------
function highest_awakening_unlocked() {
    var _max_awk = 0;
    if (variable_global_exists("dungeon_ascendance_unlocked")) {
        var _names = variable_struct_get_names(global.dungeon_ascendance_unlocked);
        for (var _i = 0; _i < array_length(_names); _i++) {
            _max_awk = max(_max_awk, variable_struct_get(global.dungeon_ascendance_unlocked, _names[_i]));
        }
    }
    return _max_awk;
}

// ---------------------------------------------------------------------------
// drop_weights(source, asc)
// Returns rarity weights [common%, uncommon%, rare%, epic%, legendary%] for a
// drop SOURCE, scaled by awakening tier `asc` (0..5). Each source lerps from an
// A0 baseline (common-heavy; rares/legendaries very rare) to an A5 ceiling.
// Higher awakening = better loot. Premium sources (reliquary) keep no common floor.
// Source names: "standard", "elite", "boss", "chest", "vault", "reliquary", "dorn".
// ---------------------------------------------------------------------------
function drop_weights(source, asc) {
    asc = clamp(asc, 0, 5);
    var _a0, _a5;
    switch (source) {
        case "standard":  _a0 = [90,  9,  1,  0, 0]; _a5 = [45, 33, 17,  5, 0]; break;
        case "elite":     _a0 = [72, 23,  5,  0, 0]; _a5 = [22, 38, 28, 10, 2]; break;
        case "boss":      _a0 = [33, 42, 21,  3, 1]; _a5 = [ 6, 28, 38, 22, 6]; break;
        case "chest":     _a0 = [80, 17,  3,  0, 0]; _a5 = [33, 37, 22,  7, 1]; break;
        case "vault":     _a0 = [70, 24,  5,  1, 0]; _a5 = [25, 38, 26,  9, 2]; break;
        case "reliquary": _a0 = [ 0, 60, 32,  7, 1]; _a5 = [ 0, 25, 40, 28, 7]; break;
        case "dorn":      _a0 = [55, 38,  7,  0, 0]; _a5 = [10, 35, 35, 18, 2]; break;
        default:          _a0 = [90,  9,  1,  0, 0]; _a5 = [45, 33, 17,  5, 0]; break;
    }
    var _t = asc / 5;
    var _w = array_create(5, 0);
    var _sum = 0;
    // Lerp the upper four tiers; common (index 0) absorbs the remainder so the
    // weights always sum to 100 regardless of rounding.
    for (var _i = 1; _i < 5; _i++) {
        _w[_i] = round(lerp(_a0[_i], _a5[_i], _t));
        _sum += _w[_i];
    }
    _w[0] = max(0, 100 - _sum);
    // Premium sources have no common floor: route the leftover into uncommon.
    if (_a0[0] == 0 && _a5[0] == 0) {
        _w[1] += _w[0];
        _w[0]  = 0;
    }
    return _w;
}

// ---------------------------------------------------------------------------
// drop_equipment(rarity_weights, do_discover)
// Full drop pipeline: pick rarity, clone a base item, roll and apply affixes.
// rarity_weights: [common%, uncommon%, rare%, epic%, legendary%]
// Common=0 affixes, uncommon=1, rare=1-2 (50/50), epic=2, legendary=fixed.
// do_discover (default true): record the item in the codex. Shop stock passes
// false so items are only discovered when actually bought.
// ---------------------------------------------------------------------------
function drop_equipment(rarity_weights, do_discover = true) {
    if (!variable_global_exists("loot_table_common")
        || !variable_global_exists("loot_table_uncommon")
        || !variable_global_exists("loot_table_rare")) {
        return clone_item(create_item("Ashen Blade", "weapon", 0, "STR", 2, "", 15));
    }

    var _roll = irandom(99);
    var _cum  = 0;
    var _rarity = 0;
    var _len = array_length(rarity_weights);
    for (var _r = 0; _r < _len; _r++) {
        _cum += rarity_weights[_r];
        if (_roll < _cum) { _rarity = _r; break; }
    }

    // Prospector trait: loot rolls one quality tier better (capped at Legendary)
    if (trait_active("Prospector") && _rarity < 4) _rarity++;

    // Legendaries - return clone with pre-set affixes and unique fields
    if (_rarity == 4 && variable_global_exists("loot_table_legendary")
        && array_length(global.loot_table_legendary) > 0) {
        var _leg_tbl = global.loot_table_legendary;
        var _leg_item = clone_item(_leg_tbl[irandom(array_length(_leg_tbl) - 1)]);
        if (do_discover) discover_item(item_base_name(_leg_item));
        return _leg_item;
    }

    // Base table selection: epic draws from rare table, then gets extra affixes
    var _base_tbl;
    if (_rarity <= 0)      _base_tbl = global.loot_table_common;
    else if (_rarity == 1) _base_tbl = global.loot_table_uncommon;
    else                   _base_tbl = global.loot_table_rare;

    var _base = _base_tbl[irandom(array_length(_base_tbl) - 1)];
    var _item = clone_item(_base);

    // Override rarity for epic
    var _eff_rarity = (_rarity == 3) ? 3 : _rarity;
    if (_rarity == 3) _item.rarity = 3;

    // Affix count by rarity
    var _affix_count = 0;
    if (_eff_rarity == 1)      _affix_count = 1;
    else if (_eff_rarity == 2) _affix_count = (irandom(1) == 0) ? 1 : 2;
    else if (_eff_rarity == 3) _affix_count = 2;

    if (_affix_count > 0) {
        var _affixes = roll_affixes(_eff_rarity, _affix_count, [_item.stat_name], _item.slot, _item.base_name);
        apply_affixes_to_item(_item, _affixes);
    }

    // Elemental affix: weapons may also carry one (small elemental damage + a setup
    // status), independent of the stat affixes (SYSTEMS_WEAPON_ROLES.md §C). Skip if
    // the base already carries one (hand-authored elemental weapons) so it isn't
    // doubled up or overwritten.
    var _base_has_elem = (variable_struct_exists(_item, "elem_affix") && _item.elem_affix != undefined);
    if ((_item.slot == "weapon" || _item.slot == "ranged_weapon") && !_base_has_elem) {
        apply_elemental_affix_to_item(_item, roll_elemental_affix(_eff_rarity));
    }

    // Sockets follow the FINAL rarity (epic was bumped from a rare base above).
    _item.socket_count = rune_sockets_for_rarity(_item.rarity);

    if (do_discover) discover_item(item_base_name(_item));
    return _item;
}

// ---------------------------------------------------------------------------
// consumables_grouped()
// A DISPLAY view of global.consumable_inventory that collapses identical items
// (same name) into one row, so menus show "Smelling Salts  x5" instead of five
// separate rows. The underlying array is NOT changed - it still holds 5 real
// entries (so array_length is the true count for inventory caps). Each group is
// { item, count, first_index }; `first_index` is the lowest array position, i.e.
// the instance a menu should consume when the player uses that row.
// ---------------------------------------------------------------------------
function consumables_grouped() {
    var _inv = variable_global_exists("consumable_inventory") ? global.consumable_inventory : [];
    var _groups   = [];
    var _index_of = {};   // item name -> its slot in _groups
    for (var _i = 0; _i < array_length(_inv); _i++) {
        var _it  = _inv[_i];
        var _key = _it.name;
        if (variable_struct_exists(_index_of, _key)) {
            _groups[variable_struct_get(_index_of, _key)].count++;
        } else {
            variable_struct_set(_index_of, _key, array_length(_groups));
            array_push(_groups, { item: _it, count: 1, first_index: _i });
        }
    }
    return _groups;
}

// consumable_group_label(group) - "Name" or "Name  xN" for the grouped menus.
function consumable_group_label(group) {
    return group.item.name + (group.count > 1 ? "   x" + string(group.count) : "");
}

// ---------------------------------------------------------------------------
// CONSUMABLE PACK CARRY CAP
// The run pack (global.consumable_inventory) holds a limited number of
// consumables. Base 10; the universal Pack Rat trait raises it +5 per tier
// (base equip = +5, then +5 per potency tier, capped at +15) -> 10/15/20/25.
// Overflow auto-deposits to the stash at run start; mid-run pickups past the
// cap go through a discard prompt (see global.consumable_overflow).
// ---------------------------------------------------------------------------
function consumable_carry_cap() {
    var _cap = 10;
    if (trait_active("Pack Rat")) {
        // +5 for owning it, +5 per potency tier, total bonus capped at +15.
        var _bonus = 5 + 5 * min(trait_potency_tier("Pack Rat"), 2);
        _cap += _bonus;
    }
    return _cap;
}

// consumable_pack_full() - true when the run pack is at/over its carry cap.
function consumable_pack_full() {
    if (!variable_global_exists("consumable_inventory")) return false;
    return array_length(global.consumable_inventory) >= consumable_carry_cap();
}

// consumable_award(item) - mid-run pickup router. Adds to the pack when there's
// room; otherwise queues the item in global.consumable_overflow for the post-
// combat discard prompt and returns false (caller can tag its log line).
function consumable_award(item) {
    if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
    if (!variable_global_exists("consumable_overflow"))  global.consumable_overflow  = [];
    if (array_length(global.consumable_inventory) < consumable_carry_cap()) {
        array_push(global.consumable_inventory, item);
        return true;
    }
    array_push(global.consumable_overflow, item);
    return false;
}

// consumable_enforce_cap_to_stash() - trims the pack down to the carry cap,
// pushing any excess into the consumable stash (oldest-first stays carried).
// Called at run start so a pack overstuffed in the hub is normalized, and on
// return so nothing is ever stuck over-cap.
function consumable_enforce_cap_to_stash() {
    if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
    if (!variable_global_exists("consumable_stash"))     global.consumable_stash     = [];
    var _cap = consumable_carry_cap();
    while (array_length(global.consumable_inventory) > _cap) {
        var _last = array_length(global.consumable_inventory) - 1;
        array_push(global.consumable_stash, global.consumable_inventory[_last]);
        array_delete(global.consumable_inventory, _last, 1);
    }
}

// ---------------------------------------------------------------------------
// MENU NAVIGATION - hold-to-repeat input
// key_nav(key) returns true on the initial press AND, while the key stays held,
// repeats on a fixed cadence after a short initial delay. This gives every menu
// "hold to keep moving" without each site tracking its own timer. nav_up/down/
// left/right fold the WASD + arrow pairs together. Pair with wrap-around cursor
// math (mod) at the call site for full QoL navigation.
// ---------------------------------------------------------------------------
function key_nav(_key) {
    if (!variable_global_exists("nav_timers")) global.nav_timers = {};
    var _k = string(_key);
    if (keyboard_check_pressed(_key)) {
        variable_struct_set(global.nav_timers, _k, 0);
        return true;
    }
    if (keyboard_check(_key)) {
        var _t = (variable_struct_exists(global.nav_timers, _k)
                  ? variable_struct_get(global.nav_timers, _k) : 0) + 1;
        variable_struct_set(global.nav_timers, _k, _t);
        var _initial_delay = 22;   // ~0.37s held before auto-repeat kicks in
        var _repeat_every  = 5;     // then one step every 5 frames (~12/sec)
        return (_t >= _initial_delay && ((_t - _initial_delay) mod _repeat_every) == 0);
    }
    variable_struct_set(global.nav_timers, _k, 0);
    return false;
}
function nav_up()    { var _a = key_nav(vk_up);    var _b = key_nav(ord("W")); return _a || _b; }
function nav_down()  { var _a = key_nav(vk_down);  var _b = key_nav(ord("S")); return _a || _b; }
function nav_left()  { var _a = key_nav(vk_left);  var _b = key_nav(ord("A")); return _a || _b; }
function nav_right() { var _a = key_nav(vk_right); var _b = key_nav(ord("D")); return _a || _b; }

// wrap_index(i, n) - cursor wrap so top<->bottom (and left<->right) cycle.
function wrap_index(i, n) {
    if (n <= 0) return 0;
    return ((i mod n) + n) mod n;
}

// ---------------------------------------------------------------------------
// CONSUMABLE OVERFLOW DISCARD PROMPT
// When the pack is full mid-run and another consumable is picked up, the new
// item is queued in global.consumable_overflow. This modal resolves the queue
// one item at a time: pick a held consumable to discard (and take the new one),
// or leave the new one behind. Shared by the combat and floor controllers.
// ---------------------------------------------------------------------------
function consumable_overflow_pending() {
    return variable_global_exists("consumable_overflow")
        && array_length(global.consumable_overflow) > 0;
}

// Resolve input for the overflow modal. Returns true while still open.
function consumable_overflow_step() {
    if (!consumable_overflow_pending()) return false;
    if (!variable_global_exists("consumable_overflow_cursor")) global.consumable_overflow_cursor = 0;

    var _groups = consumables_grouped();
    var _options = array_length(_groups) + 1;   // +1 = "Leave it behind"
    var _cur = global.consumable_overflow_cursor;

    if (nav_up())   _cur = wrap_index(_cur - 1, _options);
    if (nav_down()) _cur = wrap_index(_cur + 1, _options);
    global.consumable_overflow_cursor = _cur;

    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
        var _new = global.consumable_overflow[0];
        if (_cur < array_length(_groups)) {
            // Discard one of the chosen held consumable, take the new one.
            var _idx = _groups[_cur].first_index;
            array_delete(global.consumable_inventory, _idx, 1);
            array_push(global.consumable_inventory, _new);
        }
        // else: "Leave it behind" - the new item is simply dropped.
        array_delete(global.consumable_overflow, 0, 1);
        global.consumable_overflow_cursor = 0;
    }
    return consumable_overflow_pending();
}

// ---------------------------------------------------------------------------
// equip_slot_index(slot_name)
// Maps a lowercase slot name to its index in global.inventory[0..9].
// Returns -1 for unknown names.
// ---------------------------------------------------------------------------
function equip_slot_index(slot_name) {
    switch (slot_name) {
        case "weapon":        return 0;   // melee weapon
        case "offhand":       return 1;
        case "helm":          return 2;
        case "chest":         return 3;
        case "gloves":        return 4;
        case "boots":         return 5;
        case "amulet":        return 6;
        case "ring":          return 7;   // Ring 1 (rings keep slot "ring"; Ring 2 is idx 9)
        case "ranged_weapon": return 8;   // appended (SYSTEMS_WEAPON_ROLES.md §A)
        case "ring2":         return 9;   // Ring 2 - second ring POSITION (accepts "ring" items)
        default:              return -1;
    }
}

// Number of equip positions in global.inventory (0..EQUIP_SLOT_COUNT-1).
#macro EQUIP_SLOT_COUNT 10

// equip_display_order() - the VISUAL top-to-bottom order of equip positions in
// the Equipment tab, as inventory indices. Ring 2 (inv idx 9) is pulled up to sit
// directly under Ring 1 (idx 7); the ranged weapon (idx 8) follows. The stored
// inventory indices are UNCHANGED (no save migration) - only the display order.
function equip_display_order() {
    return [0, 1, 2, 3, 4, 5, 6, 7, 9, 8];
}

// equip_display_to_inv(pos) - map a visual list row (0..9) to its inventory index.
function equip_display_to_inv(pos) {
    var _o = equip_display_order();
    if (pos < 0 || pos >= array_length(_o)) return pos;
    return _o[pos];
}

// equip_position_item_slot(idx) - the item `.slot` type each equip POSITION accepts.
// Ring 2 (idx 9) is a second ring position, so it accepts items whose slot is "ring".
// Used by the equip picker to filter which pack/stash items can go in a position.
function equip_position_item_slot(idx) {
    switch (idx) {
        case 0: return "weapon";
        case 1: return "offhand";
        case 2: return "helm";
        case 3: return "chest";
        case 4: return "gloves";
        case 5: return "boots";
        case 6: return "amulet";
        case 7: return "ring";
        case 8: return "ranged_weapon";
        case 9: return "ring";          // Ring 2 accepts the same item type as Ring 1
        default: return "";
    }
}

// comparison_target_index(item) - which equipped POSITION to compare a hovered item
// against. Same as equip_slot_index for single-slot items, but for rings (two
// positions, 7 + 9) it targets the slot the player would actually fill: the ring
// position currently selected in the equipment tab, else the first EMPTY ring slot
// (so the panel shows the true gain), else Ring 1. Returns -1 for non-equipment.
function comparison_target_index(item) {
    if (!is_struct(item) || !variable_struct_exists(item, "slot")) return -1;
    var _idx = equip_slot_index(item.slot);
    if (item.slot == "ring" && variable_global_exists("inventory")) {
        if (instance_exists(obj_game_controller)) {
            var _sel = instance_find(obj_game_controller, 0).equip_slot_selected;
            if (_sel == 7 || _sel == 9) return _sel;   // honor the targeted ring position
        }
        if (array_length(global.inventory) > 7 && global.inventory[7] == undefined) return 7;
        if (array_length(global.inventory) > 9 && global.inventory[9] == undefined) return 9;
        return 7;
    }
    return _idx;
}

// ---------------------------------------------------------------------------
// apply_equipment_stats(stats_struct)
// Applies all equipped items' stat bonuses to stats_struct IN PLACE.
// "armor" and "el_resist" bonuses are NOT applied to stats_struct (they are
// separate combat fields); they are accumulated and returned as a struct.
// Always call on a COPY of chosen_stats - never the global itself.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Two-handed weapon helpers (SYSTEMS_WEAPON_ROLES.md §D).
// A 2H weapon - equipped in the melee slot (0) OR the ranged slot (8) - locks
// the single offhand slot (index 1): the offhand auto-returns to the pack on
// equip, can't be re-equipped while a 2H is held, and is ignored by stat
// accumulation. You MAY run 2H in both weapon slots (offhand stays locked).
// ---------------------------------------------------------------------------
function item_is_two_handed(item) {
    if (item == undefined) return false;
    return variable_struct_exists(item, "two_handed") && item.two_handed;
}

// Backfill weapon-role fields on items deserialized from older saves (pre-Stage-1
// weapon_damage / pre-Stage-2 two_handed). Without this an equipped weapon saved
// before the field existed shows no "+N dmg (1H)" line. Safe to call on any item.
function item_migrate_weapon_fields(it) {
    if (it == undefined || !is_struct(it)) return;
    if (!variable_struct_exists(it, "slot")) return;
    if (it.slot == "weapon" || it.slot == "ranged_weapon") {
        if (!variable_struct_exists(it, "weapon_damage") || it.weapon_damage == 0) {
            var _rar = variable_struct_exists(it, "rarity") ? it.rarity : 0;
            it.weapon_damage = weapon_base_damage(_rar);
        }
    }
    if (!variable_struct_exists(it, "two_handed")) it.two_handed = false;
}

// True if either equipped weapon (melee idx 0 or ranged idx 8) is two-handed.
function two_handed_equipped() {
    if (!variable_global_exists("inventory")) return false;
    var _len = array_length(global.inventory);
    if (_len > 0 && item_is_two_handed(global.inventory[0])) return true;
    if (_len > 8 && item_is_two_handed(global.inventory[8])) return true;
    return false;
}

// Move the equipped offhand (slot 1) back to the pack - stash in the hub,
// carried items mid-run. Called when a 2H weapon is equipped so the offhand
// empties. No-op if the offhand is already empty.
function return_offhand_to_pack(in_hub) {
    if (!variable_global_exists("inventory")) return;
    if (array_length(global.inventory) <= 1) return;
    var _off = global.inventory[1];
    if (_off == undefined) return;
    global.inventory[1] = undefined;
    if (in_hub) array_push(global.equipment_stash, _off);
    else        array_push(global.carried_items, _off);
}

// ---------------------------------------------------------------------------
// Gear stat requirements (SYSTEMS_WEAPON_ROLES.md §D3). Reinforces class identity:
// a low-STR Arcanist can't swing heavy plate / a greatsword, etc. Implemented as a
// COMPUTED requirement derived from slot + weapon family + rarity (no per-item
// fields / save migration; auto-applies to all existing and future gear). An
// explicit req_stat/req_value on an item overrides the computed value. Only Rare+
// gear gates, so the early game stays open. Hard block at equip (M's call).
// ---------------------------------------------------------------------------

// req_stat_curve(rarity) - required stat value by rarity (Rare+ only).
function req_stat_curve(rarity) {
    switch (rarity) {
        case 2: return 12;   // Rare
        case 3: return 14;   // Epic
        case 4: return 16;   // Legendary
    }
    return 0;
}

// weapon_required_stat(item) - which stat a weapon demands, by family keyword.
// bows/daggers -> DEX, focus/wand/scepter/staff -> INT, the rest (sword/axe/mace/
// greatsword/spear...) -> STR. Reads base_name so affix words don't mislead it.
function weapon_required_stat(item) {
    var _n = string_lower(variable_struct_exists(item, "base_name") ? item.base_name
            : (variable_struct_exists(item, "name") ? item.name : ""));
    if (string_pos("bow", _n) > 0)    return "DEX";
    if (string_pos("wand", _n) > 0 || string_pos("focus", _n) > 0 || string_pos("scepter", _n) > 0
        || string_pos("staff", _n) > 0 || string_pos("rod", _n) > 0) return "INT";
    if (string_pos("sickle", _n) > 0 || string_pos("dagger", _n) > 0 || string_pos("knife", _n) > 0
        || string_pos("blade", _n) > 0 || string_pos("serpent", _n) > 0 || string_pos("reach", _n) > 0) return "DEX";
    return "STR";
}

// item_stat_requirement(item) - returns { stat, value } the wearer must meet, or
// { stat:"", value:0 } for none.
function item_stat_requirement(item) {
    var _none = { stat: "", value: 0 };
    if (!is_struct(item)) return _none;
    // Explicit per-item override wins.
    if (variable_struct_exists(item, "req_stat") && is_string(item.req_stat) && item.req_stat != ""
        && variable_struct_exists(item, "req_value") && item.req_value > 0) {
        return { stat: item.req_stat, value: item.req_value };
    }
    var _rar = variable_struct_exists(item, "rarity") ? item.rarity : 0;
    if (_rar < 2) return _none;   // Common/Uncommon: no requirement
    var _slot = variable_struct_exists(item, "slot") ? item.slot : "";
    var _val  = req_stat_curve(_rar);
    if (_val <= 0) return _none;
    if (_slot == "weapon" || _slot == "ranged_weapon") {
        return { stat: weapon_required_stat(item), value: _val };
    }
    if (_slot == "chest" || _slot == "helm") {
        // Heavy armor (STR/CON-based) demands that stat; light armor is unrestricted.
        var _sn = variable_struct_exists(item, "stat_name") ? item.stat_name : "";
        if (_sn == "STR" || _sn == "CON") return { stat: _sn, value: _val };
    }
    return _none;
}

// player_base_stat(stat_name) - the wearer's effective innate stat outside combat:
// char-create base + permanent (Vex) bonus + in-run growth. Excludes EQUIPMENT
// bonuses so requirements never depend on equip order (no bootstrap paradox).
function player_base_stat(stat_name) {
    if (!variable_global_exists("chosen_stats") || is_undefined(global.chosen_stats)) return 0;
    var _v = variable_struct_get(global.chosen_stats, stat_name);
    if (is_undefined(_v)) _v = 0;
    if (variable_global_exists("run_stat_bonuses") && is_struct(global.run_stat_bonuses)) {
        var _r = variable_struct_get(global.run_stat_bonuses, stat_name);
        if (!is_undefined(_r)) _v += _r;
    }
    var _perm_map = { STR: "perm_str_bonus", DEX: "perm_dex_bonus", CON: "perm_con_bonus",
                      INT: "perm_int_bonus", WIS: "perm_wis_bonus", CHA: "perm_cha_bonus" };
    var _pg = variable_struct_get(_perm_map, stat_name);
    if (!is_undefined(_pg) && variable_global_exists(_pg)) _v += variable_global_get(_pg);
    return _v;
}

// player_permanent_level() - the character's PERMANENT (meta) level: 1 + every
// permanent point ever earned. Each permanent point (earned on a safe return,
// run level 5/10/15 -> 1/2/3) is a permanent level-up, whether it's already been
// spent into a perm_<stat>_bonus or is still pending. So this = 1 + (points spent)
// + (points unspent), which equals 1 + lifetime points earned. Separate from
// global.run_level (the per-dive level that resets to 1 each run). Display only -
// it does NOT change run start level or any balance (M's call). See run history's
// "Lifetime Perm Points" readout for the same earned total.
function player_permanent_level() {
    var _lv = 1;
    var _keys = ["perm_str_bonus", "perm_dex_bonus", "perm_con_bonus",
                 "perm_int_bonus", "perm_wis_bonus", "perm_cha_bonus"];
    for (var _i = 0; _i < array_length(_keys); _i++) {
        if (variable_global_exists(_keys[_i])) _lv += variable_global_get(_keys[_i]);
    }
    if (variable_global_exists("pending_perm_points")) _lv += global.pending_perm_points;
    return _lv;
}

// equip_stat_block_reason(item) - "" if the wearer meets the item's stat
// requirement (or it has none), else a "<Item> requires N STR." message. Used by
// the equip paths to HARD-BLOCK an equip and by the tooltip to flag it.
function equip_stat_block_reason(item) {
    var _req = item_stat_requirement(item);
    if (_req.value <= 0 || _req.stat == "") return "";
    if (player_base_stat(_req.stat) >= _req.value) return "";
    return item.name + " requires " + string(_req.value) + " " + _req.stat + ".";
}

function apply_equipment_stats(stats_struct) {
    // Extended bonus struct: armor/el_resist (old), plus affix-driven special fields.
    // bonus_max_hp  - flat HP added directly to player.max_HP after derive
    // crit_flat     - % added to all crit rolls (stored in stats_struct.crit_bonus)
    // dodge_flat    - flat added to player.dodge
    // gold_find     - % gold find bonus; consumed by add_gold() on the found-gold path
    // melee_dmg_bonus / ranged_dmg_bonus - reach-gated flat weapon damage. NOT applied to
    // stats_struct; summed into the cast resolver's _dmg per the ability's reach class
    // (SYSTEMS_WEAPON_ROLES.md §B). Melee weapon -> melee abilities, ranged weapon -> ranged.
    var _bonus = { armor: 0, el_resist: 0, bonus_max_hp: 0, crit_flat: 0, dodge_flat: 0, gold_find: 0,
                   melee_dmg_bonus: 0, ranged_dmg_bonus: 0,
                   melee_elem: undefined, ranged_elem: undefined,
                   // Flat "+X <school> damage" accumulator (SYSTEMS_ELEMENT_SCHOOLS.md §C).
                   // Keyed by the 8 schools; _equip_apply_stat routes "school_<name>" affixes
                   // here, combat Create copies it onto player.derived.school_dmg.
                   school_dmg: school_dmg_empty() };
    if (!variable_global_exists("inventory")) return _bonus;

    // When a 2H weapon is equipped the offhand slot (1) is locked - ignore it
    // entirely (belt-and-suspenders; the equip path already empties it).
    var _offhand_locked = two_handed_equipped();

    for (var _i = 0; _i < array_length(global.inventory); _i++) {
        if (_i == 1 && _offhand_locked) continue;
        var _it = global.inventory[_i];
        if (_it == undefined) continue;

        // Reach-gated weapon damage routes by the item's own slot, not its stat.
        var _wd = variable_struct_exists(_it, "weapon_damage") ? _it.weapon_damage : 0;
        if (_wd != 0) {
            if (_it.slot == "weapon")             _bonus.melee_dmg_bonus  += _wd;
            else if (_it.slot == "ranged_weapon") _bonus.ranged_dmg_bonus += _wd;
        }

        // Reach-gated elemental affix (one melee + one ranged weapon at most).
        var _ea = variable_struct_exists(_it, "elem_affix") ? _it.elem_affix : undefined;
        if (_ea != undefined) {
            if (_it.slot == "weapon")             _bonus.melee_elem  = _ea;
            else if (_it.slot == "ranged_weapon") _bonus.ranged_elem = _ea;
        }

        _equip_apply_stat(stats_struct, _bonus, _it.stat_name, _it.stat_value);

        // Apply affixes stored on the item (from drop_equipment or legendary fixed affixes)
        if (variable_struct_exists(_it, "affixes")) {
            for (var _a = 0; _a < array_length(_it.affixes); _a++) {
                var _af = _it.affixes[_a];
                _equip_apply_stat(stats_struct, _bonus, _af.stat_name, _af.stat_value);
            }
        }

        // Apply socketed GEAR runes (Aspect runes are handled separately in combat).
        if (variable_struct_exists(_it, "runes")) {
            for (var _r = 0; _r < array_length(_it.runes); _r++) {
                var _rn   = _it.runes[_r];
                var _rdef = rune_get(_rn.id);
                if (_rdef != undefined && _rdef.domain == "gear") {
                    _equip_apply_stat(stats_struct, _bonus, _rdef.stat_name, rune_value(_rn));
                }
            }
        }
    }
    return _bonus;
}

// school_dmg_empty() - fresh accumulator struct keyed by the 8 element schools,
// all zeroed. Single source of the school key set (SYSTEMS_ELEMENT_SCHOOLS.md §C).
function school_dmg_empty() {
    var _s = {};
    var _list = ability_school_list();
    for (var _i = 0; _i < array_length(_list); _i++) variable_struct_set(_s, _list[_i], 0);
    return _s;
}

// Internal helper - routes a stat_name/stat_value pair to the correct target.
function _equip_apply_stat(stats_struct, bonus, stat_name, stat_value) {
    if (stat_name == "armor")        { bonus.armor        += stat_value; }
    else if (stat_name == "el_resist")   { bonus.el_resist   += stat_value; }
    else if (stat_name == "bonus_max_hp"){ bonus.bonus_max_hp += stat_value; }
    else if (stat_name == "crit_flat")   { bonus.crit_flat   += stat_value; }
    else if (stat_name == "dodge_flat")  { bonus.dodge_flat  += stat_value; }
    else if (stat_name == "gold_find")   { bonus.gold_find   += stat_value; }
    // "school_<name>" -> flat school-damage accumulator (only known schools).
    else if (string_copy(stat_name, 1, 7) == "school_") {
        var _sk = string_copy(stat_name, 8, string_length(stat_name) - 7);
        if (variable_struct_exists(bonus.school_dmg, _sk)) {
            variable_struct_set(bonus.school_dmg, _sk, variable_struct_get(bonus.school_dmg, _sk) + stat_value);
        }
    }
    else {
        var _cur = variable_struct_get(stats_struct, stat_name);
        if (!is_undefined(_cur)) {
            variable_struct_set(stats_struct, stat_name, _cur + stat_value);
        }
    }
}

// ---------------------------------------------------------------------------
// roll_equipment(rarity_weights)
// Rolls a random item from the global loot tables weighted by rarity.
// rarity_weights = [common%, uncommon%, rare%] (must sum to 100 or less;
// remainder falls through to the last non-empty table).
// ---------------------------------------------------------------------------
// roll_equipment: used by restock_shops() for base (no-affix) shop items only.
// For dungeon drops, use drop_equipment() which handles affix rolling.
function roll_equipment(rarity_weights) {
    if (!variable_global_exists("loot_table_common")
        || !variable_global_exists("loot_table_uncommon")
        || !variable_global_exists("loot_table_rare")) {
        return create_item("Ashen Blade", "weapon", 0, "STR", 2, "+2 STR", 15);
    }
    var _roll = irandom(99);
    var _cum  = 0;
    var _tables = [
        global.loot_table_common,
        global.loot_table_uncommon,
        global.loot_table_rare,
        global.loot_table_rare,    // index 3 = epic: uses rare base table
    ];
    for (var _r = 0; _r < array_length(rarity_weights); _r++) {
        _cum += rarity_weights[_r];
        if (_roll < _cum) {
            var _ti = min(_r, array_length(_tables) - 1);
            return _tables[_ti][irandom(array_length(_tables[_ti]) - 1)];
        }
    }
    return global.loot_table_common[0];
}

// ---------------------------------------------------------------------------
// roll_consumable(pool)
// Returns a random consumable from the given pool array.
// ---------------------------------------------------------------------------
function roll_consumable(pool) {
    return pool[irandom(array_length(pool) - 1)];
}

// ---------------------------------------------------------------------------
// roll_consumable_weighted(pool)
// Like roll_consumable but down-weights healing so drops stop flooding with
// salves. Heal / heal-over-time items get weight 1; every other (utility)
// consumable gets weight 3. Used by DROP sources only - uniform roll_consumable
// is kept for shop stock where the player chooses what to buy.
// ---------------------------------------------------------------------------
function roll_consumable_weighted(pool) {
    var _n = array_length(pool);
    if (_n == 0) return undefined;
    var _weights = array_create(_n, 0);
    var _total   = 0;
    for (var _i = 0; _i < _n; _i++) {
        var _et = variable_struct_exists(pool[_i], "effect_type") ? pool[_i].effect_type : "";
        _weights[_i] = (_et == "heal" || _et == "heal_dot") ? 1 : 3;
        _total += _weights[_i];
    }
    if (_total <= 0) return pool[irandom(_n - 1)];
    var _roll = irandom(_total - 1);
    var _cum  = 0;
    for (var _i = 0; _i < _n; _i++) {
        _cum += _weights[_i];
        if (_roll < _cum) return pool[_i];
    }
    return pool[_n - 1];
}

// ---------------------------------------------------------------------------
// floor_room_enterable(rooms, idx)
// True when the room can be entered RIGHT NOW: not cleared, and either an entry
// node or reached via a cleared parent whose branch hasn't been abandoned
// (sibling-lock - once you take one child, the others lock). Shared by the floor
// map's enter check and its render so the two never disagree.
// ---------------------------------------------------------------------------
function floor_room_enterable(rooms, idx) {
    var _room = rooms[idx];
    if (_room.cleared) return false;
    if (array_length(_room.parents) == 0) return true;
    for (var _pi = 0; _pi < array_length(_room.parents); _pi++) {
        var _par = rooms[_room.parents[_pi]];
        if (!_par.cleared) continue;
        var _sib_taken = false;
        for (var _ci = 0; _ci < array_length(_par.children); _ci++) {
            var _sib = _par.children[_ci];
            if (_sib != idx && rooms[_sib].cleared) { _sib_taken = true; break; }
        }
        if (!_sib_taken) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// floor_compute_reachable(rooms)
// Returns a bool[] - true for rooms still reachable from the current frontier.
// A branch you didn't take (and everything past it) becomes unreachable, so the
// map can grey those out. Single forward pass: room ids are topologically sorted
// (a parent's id is always lower than its children's).
// ---------------------------------------------------------------------------
function floor_compute_reachable(rooms) {
    var _n = array_length(rooms);
    var _reach = array_create(_n, false);
    for (var _i = 0; _i < _n; _i++) {
        if (array_length(rooms[_i].parents) == 0) _reach[_i] = true; // entry node
    }
    for (var _i = 0; _i < _n; _i++) {
        if (!_reach[_i]) continue;
        var _r = rooms[_i];
        // Has this room already had one of its children taken (branch committed)?
        var _child_taken = false;
        if (_r.cleared) {
            for (var _c = 0; _c < array_length(_r.children); _c++) {
                if (rooms[_r.children[_c]].cleared) { _child_taken = true; break; }
            }
        }
        for (var _c = 0; _c < array_length(_r.children); _c++) {
            var _cid = _r.children[_c];
            // Edge is open unless this room is cleared AND a different child was taken.
            var _open = (!_r.cleared) || (!_child_taken) || rooms[_cid].cleared;
            if (_open) _reach[_cid] = true;
        }
    }
    return _reach;
}

// ---------------------------------------------------------------------------
// handle_enemy_drops(enemy_type)
// Rolls drops for a defeated enemy, pushes results into global inventories,
// and returns a log string describing what dropped ("" if nothing dropped).
// ---------------------------------------------------------------------------
function handle_enemy_drops(enemy_type) {
    if (!variable_global_exists("run_items_found"))      global.run_items_found      = [];
    if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];

    if (!variable_global_exists("carried_items")) global.carried_items = [];
    if (!variable_global_exists("rune_inventory")) global.rune_inventory = [];
    if (!variable_global_exists("rune_dust"))      global.rune_dust      = 0;

    // Drop rarity scales with the awakening tier of the current run, plus any
    // loot-tier bonus from active curses (devil's bargain - better loot for risk).
    var _drop_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) + curse_loot_asc_bonus();

    // Rune drops (additive to gear/consumable). Standard: none. Elite: ~6% Tier I.
    // Boss: guaranteed, with a 20% chance to be Tier II. Tier III is craft-only.
    var _rune_drop = "";   // log fragment, e.g. "Vitality I [Rune]"  ("" = none)
    var _rune_chance = 0;
    var _rune_t2     = 0;
    if (enemy_type == "elite")     { _rune_chance = 6;   }
    else if (enemy_type == "boss") { _rune_chance = 100; _rune_t2 = 20; }
    if (irandom(99) < _rune_chance) {
        var _rt = (_rune_t2 > 0 && irandom(99) < _rune_t2) ? 2 : 1;
        var _rn = rune_random(_rt);
        array_push(global.rune_inventory, _rn);
        _rune_drop = _rn.name + " " + rune_tier_roman(_rn.tier) + " [Rune]";
    }

    // Dust trickle (Phase 2 faucet): elite/boss passively grant a little rune dust.
    // Stays in as a secondary faucet once Sable salvage (Phase 3) becomes primary.
    var _dust_gain = 0;
    if (enemy_type == "elite")     _dust_gain = 2;
    else if (enemy_type == "boss") _dust_gain = 6;
    if (_dust_gain > 0 && boon_active("runic")) _dust_gain = round(_dust_gain * (1 + boon_value("runic")));
    if (_dust_gain > 0) _dust_gain = round(_dust_gain * curse_dust_mult());   // curse rune-dust reward
    if (_dust_gain > 0) global.rune_dust += _dust_gain;

    // Combined log fragment appended to whatever gear/consumable also dropped.
    var _rune_suffix = "";
    if (_rune_drop != "") _rune_suffix += "  +  " + _rune_drop;
    if (_dust_gain > 0)   _rune_suffix += "  +  " + string(_dust_gain) + " Dust";

    if (enemy_type == "standard") {
        // Consumable drop chance tapers off with awakening (10% - 1%/tier, min 5%)
        // so higher tiers lean on boons/shops instead of drowning in heals.
        var _cons_chance = max(5, 10 - _drop_asc);
        if (trait_active("Lucky Find")) _cons_chance += 5;   // Lucky Find: +5%
        if (!curse_blocks_consumables() && irandom(99) < _cons_chance) {   // Famine curse: no consumable drops
            var _c = roll_consumable_weighted(global.consumables_standard);
            array_push(global.run_items_found, _c);
            var _fit = consumable_award(_c);
            return _c.name + " [Consumable]" + (_fit ? "" : " (PACK FULL)") + _rune_suffix;
        }
        // 4% equipment drop - rarity weights scale with awakening (drop_weights).
        if (irandom(99) < 4) {
            var _item = drop_equipment(drop_weights("standard", _drop_asc));
            array_push(global.run_items_found, _item);
            array_push(global.carried_items, _item);
            discover_item(item_base_name(_item));
            return _item.name + " [" + item_rarity_name(_item.rarity) + "]" + _rune_suffix;
        }

    } else if (enemy_type == "elite") {
        // Awakening taper (60% - 4%/tier, min 40%) + Lucky Find +5%.
        var _elite_cons_chance = max(40, 60 - _drop_asc * 4);
        if (trait_active("Lucky Find")) _elite_cons_chance += 5;
        if (!curse_blocks_consumables() && irandom(99) < _elite_cons_chance) {   // Famine curse: no consumable drops
            var _c = roll_consumable_weighted(global.consumables_elite);
            array_push(global.run_items_found, _c);
            var _fit = consumable_award(_c);
            return _c.name + " [Consumable]" + (_fit ? "" : " (PACK FULL)") + _rune_suffix;
        }
        // 28% equipment drop - rarity weights scale with awakening (drop_weights).
        if (irandom(99) < 28) {
            var _item = drop_equipment(drop_weights("elite", _drop_asc));
            array_push(global.run_items_found, _item);
            array_push(global.carried_items, _item);
            discover_item(item_base_name(_item));
            return _item.name + " [" + item_rarity_name(_item.rarity) + "]" + _rune_suffix;
        }

    } else if (enemy_type == "boss") {
        // Guaranteed equipment - rarity weights scale with awakening (drop_weights).
        var _item = drop_equipment(drop_weights("boss", _drop_asc));
        array_push(global.run_items_found, _item);
        array_push(global.carried_items, _item);
        discover_item(item_base_name(_item));
        var _result = _item.name + " [" + item_rarity_name(_item.rarity) + "]";
        // 50% bonus consumable (suppressed by the Famine curse)
        if (!curse_blocks_consumables() && irandom(99) < 50) {
            var _c = roll_consumable_weighted(global.consumables_elite);
            array_push(global.run_items_found, _c);
            var _fit = consumable_award(_c);
            _result += " + " + _c.name + (_fit ? "" : " (PACK FULL)");
        }
        return _result + _rune_suffix;
    }

    // Nothing else dropped - still report a rune / dust if any (e.g. lone elite rune).
    // Strip the leading "  +  " separator from the combined suffix.
    if (_rune_suffix != "") return string_copy(_rune_suffix, 6, string_length(_rune_suffix) - 5);
    return "";
}

// ---------------------------------------------------------------------------
// Class preset base stat tables (before 4 free points are allocated).
// Each entry: [STR, DEX, CON, INT, WIS, CHA]
// ---------------------------------------------------------------------------
global.class_presets = [
    // 0 - Arcanist
    { name: "Arcanist",     STR: 3, DEX: 4, CON: 4, INT: 9, WIS: 6, CHA: 5 },
    // 1 - Bloodwarden
    { name: "Bloodwarden",  STR: 6, DEX: 3, CON: 8, INT: 4, WIS: 5, CHA: 4 },
    // 2 - Shadowstrider
    { name: "Shadowstrider",STR: 4, DEX: 9, CON: 6, INT: 4, WIS: 5, CHA: 6 },
];

// ---------------------------------------------------------------------------
// stats_init(class_id)
// Returns a new stat struct populated with the preset values for class_id.
// The caller is responsible for applying the 4 free points afterward.
// ---------------------------------------------------------------------------
function stats_init(class_id) {
    var preset = global.class_presets[class_id];

    var s = {
        class_id:   class_id,
        class_name: preset.name,

        // Base stats
        STR: preset.STR,
        DEX: preset.DEX,
        CON: preset.CON,
        INT: preset.INT,
        WIS: preset.WIS,
        CHA: preset.CHA,

        // Free points remaining to spend during character creation
        free_points: 4,
    };

    return s;
}

// ---------------------------------------------------------------------------
// stats_derive(stat_struct)
// Reads base stats from stat_struct and returns a new struct containing all
// derived combat and resource values.
// ---------------------------------------------------------------------------
function stats_derive(stat_struct) {
    var STR = stat_struct.STR;
    var DEX = stat_struct.DEX;
    var CON = stat_struct.CON;
    var INT = stat_struct.INT;
    var WIS = stat_struct.WIS;
    var CHA = stat_struct.CHA;

    return {
        HP:              10 + (CON * 3),
        // Diminishing-returns curves (shared with the combat rolls in scr_combat) so the
        // stat sheet matches actual behaviour and high stats plateau instead of running away.
        ACC_modifier:    round(stat_accuracy(DEX)),
        DODGE:           round(stat_dodge(DEX)),

        STR_crit_chance: round(stat_crit_chance(stat_struct, 0)),
        DEX_crit_chance: round(stat_crit_chance(stat_struct, 1)),
        INT_crit_chance: round(stat_crit_chance(stat_struct, 2)),
        WIS_crit_chance: round(stat_crit_chance(stat_struct, 3)),

        spell_slots:     max(1, INT),

        phys_dmg_bonus:     floor(STR * 0.5),
        elem_dmg_bonus:     floor(INT * 0.4),
        dot_dmg_bonus:      floor(WIS * 0.3),
        cha_dmg_bonus:      floor(CHA * 0.3),
        phys_dmg_reduction: STR * 0.25,
    };
}

// ---------------------------------------------------------------------------
// stats_apply_points(stat_struct, stat_name, points)
// Adds `points` to the named stat on stat_struct, consuming from free_points
// if any remain. Returns the modified struct (same reference).
//
// stat_name must be one of: "STR", "DEX", "CON", "INT", "WIS", "CHA"
// points    may be negative to remove previously assigned free points.
// ---------------------------------------------------------------------------
function stats_apply_points(stat_struct, stat_name, points) {
    // Validate stat name
    var valid_stats = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
    var is_valid = false;
    for (var i = 0; i < array_length(valid_stats); i++) {
        if (valid_stats[i] == stat_name) {
            is_valid = true;
            break;
        }
    }
    if (!is_valid) {
        show_debug_message("stats_apply_points: unknown stat '" + stat_name + "'");
        return stat_struct;
    }

    // When spending positive points, deduct from the free pool
    if (points > 0) {
        var available = stat_struct.free_points;
        if (points > available) {
            show_debug_message("stats_apply_points: not enough free points ("
                + string(available) + " remaining, " + string(points) + " requested)");
            points = available; // spend only what is available
        }
        stat_struct.free_points -= points;
    } else if (points < 0) {
        // Refunding points - restore them to the free pool
        // Clamp so a stat never drops below its class preset floor
        var preset    = global.class_presets[stat_struct.class_id];
        var floor_val = variable_struct_get(preset, stat_name);
        var current   = variable_struct_get(stat_struct, stat_name);
        var refund    = min(-points, current - floor_val); // can't go below preset
        points        = -refund;
        stat_struct.free_points += refund;
    }

    // Apply the clamped delta
    var current_val = variable_struct_get(stat_struct, stat_name);
    variable_struct_set(stat_struct, stat_name, current_val + points);

    return stat_struct;
}

// =============================================================================
// RUNE SYSTEM - Phase 1 (Foundation + Gear runes). See SYSTEMS_RUNES.md.
// Gear runes socket into gear (item.runes) and feed apply_equipment_stats.
// Aspect runes socket into character Aspect slots; their combat effects are
// wired in Phase 2 (catalog entries are defined now so the data is stable).
// =============================================================================

// Sockets a piece of gear has, by rarity (0 Common .. 4 Legendary).
function rune_sockets_for_rarity(rarity) {
    switch (rarity) {
        case 0: return 0;   // Common
        case 1: return 1;   // Uncommon
        case 2: return 1;   // Rare
        case 3: return 2;   // Epic
        case 4: return 3;   // Legendary
    }
    return 0;
}

// Master rune catalog. tier (1..3) indexes `vals` for the magnitude.
//   domain "gear"   -> stat_name routes through _equip_apply_stat.
//   domain "aspect" -> `aspect` key names the combat hook (Phase 2).
// `blurb` uses "#" as the magnitude placeholder for rune_describe.
function rune_catalog() {
    return [
        // ---- GEAR RUNES ----
        { id:"vitality",   name:"Vitality",   domain:"gear",   stat_name:"bonus_max_hp", vals:[15,35,70], blurb:"+# Max HP" },
        { id:"might",      name:"Might",      domain:"gear",   stat_name:"STR",          vals:[1,2,4],    blurb:"+# STR" },
        { id:"finesse",    name:"Finesse",    domain:"gear",   stat_name:"DEX",          vals:[1,2,4],    blurb:"+# DEX" },
        { id:"fortitude",  name:"Fortitude",  domain:"gear",   stat_name:"CON",          vals:[1,2,4],    blurb:"+# CON" },
        { id:"insight",    name:"Insight",    domain:"gear",   stat_name:"INT",          vals:[1,2,4],    blurb:"+# INT" },
        { id:"keen",       name:"Keen",       domain:"gear",   stat_name:"crit_flat",    vals:[3,6,12],   blurb:"+#% Crit chance" },
        { id:"warding",    name:"Warding",    domain:"gear",   stat_name:"el_resist",    vals:[5,10,18],  blurb:"+#% Elemental resist" },
        { id:"evasion",    name:"Evasion",    domain:"gear",   stat_name:"dodge_flat",   vals:[2,4,8],    blurb:"+# Dodge" },
        // ---- ASPECT RUNES (combat effects wired in Phase 2) ----
        { id:"ember",      name:"Ember",      domain:"aspect", aspect:"dtype_dmg",   dtype:1, vals:[10,18,30], blurb:"+#% Elemental damage" },
        { id:"serration",  name:"Serration",  domain:"aspect", aspect:"attack_dmg",           vals:[10,18,30], blurb:"+#% Physical attack damage" },
        { id:"hemorrhage", name:"Hemorrhage", domain:"aspect", aspect:"dtype_dmg",   dtype:3, vals:[12,20,34], blurb:"+#% Blood damage" },
        { id:"hunter",     name:"Hunter",     domain:"aspect", aspect:"ranged_acc",           vals:[8,14,22],  blurb:"+#% Ranged accuracy" },
        { id:"bulwark",    name:"Bulwark",    domain:"aspect", aspect:"melee_shield",         vals:[2,4,7],    blurb:"Melee attack hits grant # shield" },
        { id:"leech",      name:"Leech",      domain:"aspect", aspect:"drain_heal",           vals:[20,35,60], blurb:"Drain abilities heal +#% more" },
        { id:"surge",      name:"Surge",      domain:"aspect", aspect:"spell_crit",           vals:[4,8,14],   blurb:"+#% Spell crit chance" },
        { id:"anchor",     name:"Anchor",     domain:"aspect", aspect:"melee_weaken",         vals:[1,1,2],    blurb:"Melee attacks Weaken (# turns)" },
        { id:"quickcast",  name:"Quickcast",  domain:"aspect", aspect:"first_spell_ap", tier3_only:true, vals:[0,0,1], blurb:"First spell each combat costs -1 AP" },
        { id:"echo",       name:"Echo",       domain:"aspect", aspect:"first_aoe_echo", tier3_only:true, vals:[0,0,1], blurb:"First AoE each combat applies its rider at full duration" },
    ];
}

// Look up a catalog definition by id (undefined if unknown).
function rune_get(id) {
    var _cat = rune_catalog();
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (_cat[_i].id == id) return _cat[_i];
    }
    return undefined;
}

// The magnitude of a specific rune instance ({id, tier}).
function rune_value(rune) {
    var _def = rune_get(rune.id);
    if (_def == undefined) return 0;
    var _t = clamp(rune.tier, 1, 3);
    return _def.vals[_t - 1];
}

// Build a rune instance struct from an id + tier.
function rune_make(id, tier) {
    var _def = rune_get(id);
    return {
        id:     id,
        name:   (_def != undefined) ? _def.name   : id,
        domain: (_def != undefined) ? _def.domain : "gear",
        tier:   clamp(tier, 1, 3),
    };
}

// Tier number -> roman numeral for display.
function rune_tier_roman(t) {
    switch (t) { case 1: return "I"; case 2: return "II"; case 3: return "III"; }
    return string(t);
}

// Full human-readable line, e.g. "Vitality II - +35 Max HP".
function rune_describe(rune) {
    var _def = rune_get(rune.id);
    if (_def == undefined) return rune.name;
    var _blurb = string_replace_all(_def.blurb, "#", string(rune_value(rune)));
    return _def.name + " " + rune_tier_roman(rune.tier) + " - " + _blurb;
}

// Rune name + tier only, e.g. "Vitality II" (the "name" line, like an item name).
function rune_title(rune) {
    var _def = rune_get(rune.id);
    var _nm  = (_def != undefined) ? _def.name : rune.name;
    return _nm + " " + rune_tier_roman(rune.tier);
}

// Rune stat-effect only, e.g. "+35 Max HP" (the "stat" line, like an item's stat str).
function rune_effect(rune) {
    var _def = rune_get(rune.id);
    if (_def == undefined) return "";
    return string_replace_all(_def.blurb, "#", string(rune_value(rune)));
}

// Thematic gem color for a rune (drives the code-drawn fallback gem + name tint).
function rune_glyph_color(id) {
    switch (id) {
        case "might":      case "serration":  return make_color_rgb(210,  80,  70);  // red
        case "hemorrhage": case "leech":      return make_color_rgb(180,  40,  60);  // crimson
        case "ember":                         return make_color_rgb(235, 130,  50);  // ember orange
        case "vitality":   case "fortitude":  case "bulwark": return make_color_rgb(220, 160, 70); // amber
        case "finesse":    case "hunter":     case "evasion": return make_color_rgb(90, 205, 110); // green
        case "keen":                          return make_color_rgb(240, 215,  90);  // gold
        case "warding":                       return make_color_rgb(70, 200, 190);   // teal
        case "insight":    case "surge":      case "quickcast": case "echo": return make_color_rgb(110, 170, 240); // arcane blue
        case "anchor":                        return make_color_rgb(150, 155, 175);  // steel
    }
    return make_color_rgb(160, 200, 240);
}

// Sprite icon for a rune (gem/glyph). Returns a sprite id, or -1 if its art isn't
// imported yet (the UI then draws a code-gem fallback). Resolved by rune id so the
// table activates automatically once the spr_icon_rune_* assets exist in the IDE.
function rune_icon_sprite(id) {
    var _nm = "spr_icon_rune_" + id;
    if (asset_get_index(_nm) != -1 && asset_get_type(_nm) == asset_sprite) return asset_get_index(_nm);
    return -1;
}

// A random droppable rune at the given tier (excludes tier3-only flagships,
// which are craft / legendary-drop only). Returns a rune instance struct.
function rune_random(tier) {
    var _cat  = rune_catalog();
    var _pool = [];
    for (var _i = 0; _i < array_length(_cat); _i++) {
        var _d = _cat[_i];
        if (variable_struct_exists(_d, "tier3_only") && _d.tier3_only) continue;
        array_push(_pool, _d.id);
    }
    if (array_length(_pool) == 0) return rune_make("vitality", tier);
    // Elemental dungeons lean toward elemental-themed runes (Ember = +elemental
    // damage, Warding = +elemental resist). Runes aren't per-element, so this is
    // the closest thematic bias available.
    if (dungeon_bias_element() != "" && irandom(99) < 35) {
        var _themed = ["ember", "warding"];
        return rune_make(_themed[irandom(array_length(_themed) - 1)], tier);
    }
    return rune_make(_pool[irandom(array_length(_pool) - 1)], tier);
}

// Ensure an item carries socket fields (legacy items from pre-rune saves may lack them).
function item_ensure_sockets(it) {
    if (it == undefined) return;
    if (!variable_struct_exists(it, "socket_count")) it.socket_count = rune_sockets_for_rarity(it.rarity);
    if (!variable_struct_exists(it, "runes"))        it.runes        = [];
}

// Equipped-item slot indices (0-7) that have at least one rune socket.
function maren_socketable_slots() {
    var _out = [];
    if (!variable_global_exists("inventory")) return _out;
    for (var _i = 0; _i < array_length(global.inventory); _i++) {
        var _it = global.inventory[_i];
        if (_it == undefined) continue;
        var _sc = variable_struct_exists(_it, "socket_count") ? _it.socket_count : rune_sockets_for_rarity(_it.rarity);
        if (_sc > 0) array_push(_out, _i);
    }
    return _out;
}

// Indices into global.rune_inventory of runes in a given domain ("gear" / "aspect").
function rune_inventory_indices(domain) {
    var _out = [];
    if (!variable_global_exists("rune_inventory")) return _out;
    for (var _i = 0; _i < array_length(global.rune_inventory); _i++) {
        var _def = rune_get(global.rune_inventory[_i].id);
        if (_def != undefined && _def.domain == domain) array_push(_out, _i);
    }
    return _out;
}

// Socket a gear rune (by rune_inventory index) into an equipped item's next open
// socket. Runes are stored densely; open sockets = socket_count - array_length(runes).
// Returns true on success.
function maren_socket_rune(slot_index, rune_inv_index) {
    if (slot_index < 0 || slot_index >= array_length(global.inventory)) return false;
    var _it = global.inventory[slot_index];
    item_ensure_sockets(_it);
    if (array_length(_it.runes) >= _it.socket_count) return false;   // no open socket
    var _rn = global.rune_inventory[rune_inv_index];
    array_push(_it.runes, rune_make(_rn.id, _rn.tier));
    array_delete(global.rune_inventory, rune_inv_index, 1);
    save_game();
    return true;
}

// Remove a socketed rune (by dense index) from an item, returning it to inventory.
function maren_unsocket_rune(slot_index, rune_index) {
    if (slot_index < 0 || slot_index >= array_length(global.inventory)) return false;
    var _it = global.inventory[slot_index];
    item_ensure_sockets(_it);
    if (rune_index < 0 || rune_index >= array_length(_it.runes)) return false;
    var _rn = _it.runes[rune_index];
    array_push(global.rune_inventory, rune_make(_rn.id, _rn.tier));
    array_delete(_it.runes, rune_index, 1);
    save_game();
    return true;
}

// =============================================================================
// RUNE SYSTEM - Phase 2 (Aspect runes). See SYSTEMS_RUNES.md §5, §10.
// Aspect runes socket into character Aspect slots (global.aspect_runes, stored
// densely). Their combat effects are queried each resolution via the helpers
// below - there is no per-combat state for the 8 standard aspects. The two
// flagship runes (quickcast/echo) are tier3-only and wired in Phase 3 when they
// become obtainable.
// =============================================================================

// Sum of the tier-scaled value of every socketed Aspect rune whose `aspect` key
// matches, optionally filtered by damage type. (Quickcast/Echo use rune_aspect_socketed.)
function rune_aspect_value(aspect_key, dtype_filter) {
    if (!variable_global_exists("aspect_runes")) return 0;
    var _t = 0;
    for (var _i = 0; _i < array_length(global.aspect_runes); _i++) {
        var _rn  = global.aspect_runes[_i];
        var _def = rune_get(_rn.id);
        if (_def == undefined || _def.domain != "aspect") continue;
        if (_def.aspect != aspect_key) continue;
        if (dtype_filter != undefined) {
            if (!variable_struct_exists(_def, "dtype") || _def.dtype != dtype_filter) continue;
        }
        _t += rune_value(_rn);
    }
    return _t;
}

// True if an aspect rune with the given id is socketed (for Quickcast/Echo flags, Phase 3).
function rune_aspect_socketed(id) {
    if (!variable_global_exists("aspect_runes")) return false;
    for (var _i = 0; _i < array_length(global.aspect_runes); _i++) {
        if (global.aspect_runes[_i].id == id) return true;
    }
    return false;
}

// --- Combat-facing aspect queries (combat passes the ability struct) ---------

// Outgoing-damage % bonus (fraction, e.g. 0.10) for an ability:
//   Ember = elemental (dtype 1), Hemorrhage = blood (dtype 3),
//   Serration = physical attacks (dtype 0).
function rune_aspect_damage_pct(ab) {
    var _dtype = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
    var _pct   = rune_aspect_value("dtype_dmg", _dtype);   // Ember/Hemorrhage (dtype-keyed)
    if (_dtype == 0) _pct += rune_aspect_value("attack_dmg", undefined);  // Serration
    return _pct / 100;
}

// Flat accuracy points for ranged actions (Hunter).
function rune_aspect_ranged_acc(ab) {
    var _ac = ability_attack_class(ab);
    if (_ac == "ranged_attack" || _ac == "ranged_spell") return rune_aspect_value("ranged_acc", undefined);
    return 0;
}

// Flat crit % for spell actions (Surge).
function rune_aspect_spell_crit(ab) {
    if (ability_class_is_spell(ability_attack_class(ab))) return rune_aspect_value("spell_crit", undefined);
    return 0;
}

// % extra healing (fraction) for drain abilities (dtype 2 -> Leech).
function rune_aspect_drain_heal_pct(ab) {
    var _dtype = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
    if (_dtype == 2) return rune_aspect_value("drain_heal", undefined) / 100;
    return 0;
}

// Flat shield granted when a melee attack lands (Bulwark).
function rune_aspect_melee_shield(ab) {
    if (ability_attack_class(ab) == "melee_attack") return rune_aspect_value("melee_shield", undefined);
    return 0;
}

// Weaken duration (turns) applied when a melee attack lands (Anchor). 0 = none.
function rune_aspect_melee_weaken_turns(ab) {
    if (ability_attack_class(ab) == "melee_attack") return rune_aspect_value("melee_weaken", undefined);
    return 0;
}

// --- Aspect-slot management (Maren) ------------------------------------------

function aspect_slot_cap() { return 4; }

// Cost {gold, dust} to unlock the NEXT aspect slot (escalating). 2->3, then 3->4.
function aspect_slot_unlock_cost() {
    var _have = variable_global_exists("aspect_slots") ? global.aspect_slots : 2;
    if (_have <= 2) return { gold: cha_price(200), dust: 15 };
    return { gold: cha_price(400), dust: 35 };
}

// Socket an aspect rune (by rune_inventory index) into the next open Aspect slot.
// Returns true on success.
function maren_aspect_socket(rune_inv_index) {
    if (!variable_global_exists("aspect_runes")) global.aspect_runes = [];
    if (!variable_global_exists("aspect_slots")) global.aspect_slots = 2;
    if (array_length(global.aspect_runes) >= global.aspect_slots) return false;   // no open slot
    if (rune_inv_index < 0 || rune_inv_index >= array_length(global.rune_inventory)) return false;
    var _rn  = global.rune_inventory[rune_inv_index];
    var _def = rune_get(_rn.id);
    if (_def == undefined || _def.domain != "aspect") return false;
    array_push(global.aspect_runes, rune_make(_rn.id, _rn.tier));
    array_delete(global.rune_inventory, rune_inv_index, 1);
    save_game();
    return true;
}

// Remove a socketed aspect rune (by dense slot index), returning it to inventory.
function maren_aspect_unsocket(slot_index) {
    if (!variable_global_exists("aspect_runes")) return false;
    if (slot_index < 0 || slot_index >= array_length(global.aspect_runes)) return false;
    var _rn = global.aspect_runes[slot_index];
    array_push(global.rune_inventory, rune_make(_rn.id, _rn.tier));
    array_delete(global.aspect_runes, slot_index, 1);
    save_game();
    return true;
}

// Try to unlock +1 aspect slot (gold + dust). Returns "" on success, else a reason.
function maren_unlock_aspect_slot() {
    if (!variable_global_exists("aspect_slots")) global.aspect_slots = 2;
    if (global.aspect_slots >= aspect_slot_cap()) return "Aspect slots already maxed.";
    var _cost = aspect_slot_unlock_cost();
    if (global.gold < _cost.gold) return "Need " + string(_cost.gold) + "g.";
    if (!variable_global_exists("rune_dust") || global.rune_dust < _cost.dust) return "Need " + string(_cost.dust) + " dust.";
    global.gold        -= _cost.gold;
    global.rune_dust   -= _cost.dust;
    global.aspect_slots += 1;
    save_game();
    return "";
}

// =============================================================================
// RUNE SYSTEM - Phase 3 (Maren's Forge: Combine / Split / Craft Flagship).
// See SYSTEMS_RUNES.md §6. Combine 3 identical -> 1 next tier; Split 1 -> one tier
// lower + dust refund; Craft Flagship -> a tier-III Quickcast/Echo for gold+dust.
// =============================================================================

// Combinable groups: distinct {id, tier, count, name} present 3+ times, tier < 3.
function rune_combine_groups() {
    var _out = [];
    if (!variable_global_exists("rune_inventory")) return _out;
    var _seen = [];
    for (var _i = 0; _i < array_length(global.rune_inventory); _i++) {
        var _r = global.rune_inventory[_i];
        if (_r.tier >= 3) continue;
        var _key = _r.id + "|" + string(_r.tier);
        var _dup = false;
        for (var _k = 0; _k < array_length(_seen); _k++) { if (_seen[_k] == _key) { _dup = true; break; } }
        if (_dup) continue;
        array_push(_seen, _key);
        var _cnt = 0;
        for (var _j = 0; _j < array_length(global.rune_inventory); _j++) {
            if (global.rune_inventory[_j].id == _r.id && global.rune_inventory[_j].tier == _r.tier) _cnt++;
        }
        if (_cnt >= 3) array_push(_out, { id: _r.id, tier: _r.tier, count: _cnt, name: _r.name });
    }
    return _out;
}

// Combine cost {gold, dust} by source tier (1->2 vs 2->3). Gold is CHA-discounted.
function rune_combine_cost(tier) {
    if (tier <= 1) return { gold: cha_price(50),  dust: 10 };
    return { gold: cha_price(150), dust: 30 };
}

// Combine 3x (id, tier) -> 1x (id, tier+1), paying gold+dust. "" on success else reason.
function maren_combine_rune(id, tier) {
    if (tier >= 3) return "Already max tier.";
    var _cost = rune_combine_cost(tier);
    if (global.gold < _cost.gold) return "Need " + string(_cost.gold) + "g.";
    if (!variable_global_exists("rune_dust") || global.rune_dust < _cost.dust) return "Need " + string(_cost.dust) + " dust.";
    var _idxs = [];
    for (var _i = 0; _i < array_length(global.rune_inventory); _i++) {
        var _r = global.rune_inventory[_i];
        if (_r.id == id && _r.tier == tier) array_push(_idxs, _i);
    }
    if (array_length(_idxs) < 3) return "Need 3 identical runes.";
    // Delete the 3 copies highest-index-first so earlier indices stay valid.
    array_delete(global.rune_inventory, _idxs[2], 1);
    array_delete(global.rune_inventory, _idxs[1], 1);
    array_delete(global.rune_inventory, _idxs[0], 1);
    global.gold      -= _cost.gold;
    global.rune_dust -= _cost.dust;
    array_push(global.rune_inventory, rune_make(id, tier + 1));
    save_game();
    return "";
}

// Flat gold charged to socket OR unsocket a rune (small service fee). Unlike the
// forge costs this is a fixed 30g, not CHA-discounted, so the prompt is predictable.
function rune_socket_cost() { return 30; }

// Split cost (gold only - split RETURNS dust). Gold is CHA-discounted.
function rune_split_cost() { return { gold: cha_price(20) }; }

// Dust refunded when splitting a tier-N rune (≈ half the combine dust that built it;
// tier-I scrap returns a small flat amount and no lower-tier rune).
function rune_split_dust(tier) {
    if (tier >= 3) return 15;
    if (tier == 2) return 5;
    return 3;
}

// Split a rune (by inventory index): tier N -> tier N-1 + dust; tier I -> dust only.
function maren_split_rune(rune_inv_index) {
    if (rune_inv_index < 0 || rune_inv_index >= array_length(global.rune_inventory)) return "Invalid rune.";
    var _cost = rune_split_cost();
    if (global.gold < _cost.gold) return "Need " + string(_cost.gold) + "g.";
    if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
    var _r = global.rune_inventory[rune_inv_index];
    var _dust_back = rune_split_dust(_r.tier);
    array_delete(global.rune_inventory, rune_inv_index, 1);
    global.gold      -= _cost.gold;
    global.rune_dust += _dust_back;
    if (_r.tier > 1) array_push(global.rune_inventory, rune_make(_r.id, _r.tier - 1));
    save_game();
    return "";
}

// Flagship (tier3_only) rune ids, and the craft cost to forge one directly.
function rune_flagship_ids()  { return ["quickcast", "echo"]; }
function flagship_craft_cost() { return { gold: cha_price(300), dust: 60 }; }

// Craft a tier-III flagship rune for gold+dust. "" on success else reason.
function maren_craft_flagship(id) {
    var _def = rune_get(id);
    if (_def == undefined || !variable_struct_exists(_def, "tier3_only") || !_def.tier3_only) return "Not a flagship rune.";
    var _cost = flagship_craft_cost();
    if (global.gold < _cost.gold) return "Need " + string(_cost.gold) + "g.";
    if (!variable_global_exists("rune_dust") || global.rune_dust < _cost.dust) return "Need " + string(_cost.dust) + " dust.";
    global.gold      -= _cost.gold;
    global.rune_dust -= _cost.dust;
    array_push(global.rune_inventory, rune_make(id, 3));
    save_game();
    return "";
}

// =============================================================================
// SABLE THE ALCHEMIST - Salvage (dust faucet) / Brew / Upgrade. See SYSTEMS_SABLE.md.
// Shares global.rune_dust with Maren. Salvage is the primary dust faucet.
// =============================================================================

// --- Salvage rates ---
function sable_salvage_gear_dust(rarity) {
    switch (rarity) {
        case 0: return 1; case 1: return 2; case 2: return 5; case 3: return 10; case 4: return 20;
    }
    return 1;
}
function sable_salvage_rune_dust(tier) {
    if (tier >= 3) return 40;
    if (tier == 2) return 16;
    return 6;
}

// Combined list of UNEQUIPPED gear (carried pack + hub stash) with source tags.
function sable_salvageable_gear() {
    var _out = [];
    if (variable_global_exists("carried_items")) {
        for (var _i = 0; _i < array_length(global.carried_items); _i++)
            array_push(_out, { source: "carried", index: _i, item: global.carried_items[_i] });
    }
    if (variable_global_exists("equipment_stash")) {
        for (var _i = 0; _i < array_length(global.equipment_stash); _i++)
            array_push(_out, { source: "stash", index: _i, item: global.equipment_stash[_i] });
    }
    return _out;
}

// Salvage a gear entry by its index in sable_salvageable_gear(). Returns dust gained, or -1.
function sable_salvage_gear_at(combined_index) {
    var _list = sable_salvageable_gear();
    if (combined_index < 0 || combined_index >= array_length(_list)) return -1;
    var _e    = _list[combined_index];
    var _dust = sable_salvage_gear_dust(_e.item.rarity);
    if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
    global.rune_dust += _dust;
    if (_e.source == "carried") array_delete(global.carried_items, _e.index, 1);
    else                        array_delete(global.equipment_stash, _e.index, 1);
    save_game();
    return _dust;
}

// Salvage an unsocketed rune by inventory index (fully scrapped). Returns dust, or -1.
function sable_salvage_rune_at(rune_inv_index) {
    if (!variable_global_exists("rune_inventory")) return -1;
    if (rune_inv_index < 0 || rune_inv_index >= array_length(global.rune_inventory)) return -1;
    var _r    = global.rune_inventory[rune_inv_index];
    var _dust = sable_salvage_rune_dust(_r.tier);
    if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
    global.rune_dust += _dust;
    array_delete(global.rune_inventory, rune_inv_index, 1);
    save_game();
    return _dust;
}

// --- Brew (alchemy-exclusive consumables) ---
function sable_brew_catalog() {
    return [
        { id:"aegis",   name:"Aegis Draught",          effect:"shield",      value:30, desc:"Gain a 30-point shield",            gold_val:40, dust:25, gold:cha_price(30) },
        { id:"master",  name:"Master Healing Draught", effect:"heal",        value:90, desc:"Restore 90 HP",                     gold_val:70, dust:30, gold:cha_price(40) },
        { id:"phoenix", name:"Phoenix Tonic",          effect:"heal_dot",    value:15, desc:"Restore 15 HP per turn for 3 turns",gold_val:60, dust:35, gold:cha_price(40) },
        { id:"philter", name:"Cleansing Philter",      effect:"cleanse_all", value:0,  desc:"Clear all negative effects",        gold_val:50, dust:20, gold:cha_price(25) },
        { id:"ley",     name:"Ley Battery",            effect:"resource_ap", value:3,  desc:"Restore +3 of your class resource and +1 AP (free to use)", gold_val:55, dust:30, gold:cha_price(35) },
    ];
}
function sable_brew_get(id) {
    var _c = sable_brew_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}
// Brew a potion by id. "" on success else reason (slot cap / gold / dust).
function sable_brew(id) {
    var _b = sable_brew_get(id);
    if (_b == undefined) return "Unknown recipe.";
    if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
    if (global.gold < _b.gold) return "Need " + string(_b.gold) + "g.";
    if (!variable_global_exists("rune_dust") || global.rune_dust < _b.dust) return "Need " + string(_b.dust) + " dust.";
    global.gold      -= _b.gold;
    global.rune_dust -= _b.dust;
    array_push(global.consumable_inventory, create_consumable(_b.name, _b.effect, _b.value, _b.desc, _b.gold_val));
    save_game();
    return "";
}

// --- Upgrade (fuse 3 standard consumables -> elite) ---
function sable_upgrade_map() {
    return [
        { from:"Healing Salve",  to:"Greater Healing Salve" },
        { from:"Energy Tonic",   to:"Adrenaline Vial" },
        { from:"Antidote",       to:"Purification Draught" },
        { from:"Smelling Salts", to:"Purification Draught" },
    ];
}
function sable_upgrade_cost() { return { gold: cha_price(20), dust: 10 }; }

// Standard consumables held 3+ times that have an upgrade target. [{from,to,count}].
function sable_upgrade_groups() {
    var _out = [];
    if (!variable_global_exists("consumable_inventory")) return _out;
    var _map = sable_upgrade_map();
    for (var _m = 0; _m < array_length(_map); _m++) {
        var _cnt = 0;
        for (var _i = 0; _i < array_length(global.consumable_inventory); _i++)
            if (global.consumable_inventory[_i].name == _map[_m].from) _cnt++;
        if (_cnt >= 3) array_push(_out, { from: _map[_m].from, to: _map[_m].to, count: _cnt });
    }
    return _out;
}

// Find the elite consumable template by name (the upgrade output).
function sable_elite_template(name) {
    if (variable_global_exists("consumables_elite")) {
        for (var _i = 0; _i < array_length(global.consumables_elite); _i++)
            if (global.consumables_elite[_i].name == name) return global.consumables_elite[_i];
    }
    return undefined;
}

// Upgrade 3x a standard consumable into its elite version. "" on success else reason.
function sable_upgrade(from_name) {
    var _to = "";
    var _map = sable_upgrade_map();
    for (var _m = 0; _m < array_length(_map); _m++) if (_map[_m].from == from_name) { _to = _map[_m].to; break; }
    if (_to == "") return "No upgrade for that potion.";
    var _cost = sable_upgrade_cost();
    if (global.gold < _cost.gold) return "Need " + string(_cost.gold) + "g.";
    if (!variable_global_exists("rune_dust") || global.rune_dust < _cost.dust) return "Need " + string(_cost.dust) + " dust.";
    // Gather 3 source indices.
    var _idxs = [];
    for (var _i = 0; _i < array_length(global.consumable_inventory); _i++)
        if (global.consumable_inventory[_i].name == from_name) array_push(_idxs, _i);
    if (array_length(_idxs) < 3) return "Need 3 identical potions.";
    var _tmpl = sable_elite_template(_to);
    if (_tmpl == undefined) return "Upgrade target unavailable.";
    // Remove 3 (highest index first) then add the elite.
    array_delete(global.consumable_inventory, _idxs[2], 1);
    array_delete(global.consumable_inventory, _idxs[1], 1);
    array_delete(global.consumable_inventory, _idxs[0], 1);
    global.gold      -= _cost.gold;
    global.rune_dust -= _cost.dust;
    array_push(global.consumable_inventory,
        create_consumable(_tmpl.name, _tmpl.effect_type, _tmpl.effect_value, _tmpl.description, _tmpl.gold_value));
    save_game();
    return "";
}

// =============================================================================
// VAEL THE AESTHETE - transmog / skins. See SYSTEMS_VAEL.md.
// v1 = full sprite-replacement skins for the combat player sprite, bought with
// gold. Registry stores a `sprite` per skin (undefined = class default look) so
// future per-item visual layers can extend the same `vael_skin_catalog()` shape.
// =============================================================================

// Skin registry. `sprite` undefined -> the class's natural look (no override).
// New skins reference art by NAME via asset_get_index so the catalog compiles before
// the sprite resources exist (resolves to -1 until imported; draws guard for that).
// Fields: req = milestone gate id ("" = ungated); gender = cosmetic tag ("" / "m" / "f").
function vael_skin_catalog() {
    return [
        { id:"default", name:"Default (Class Look)", sprite:undefined,                          gold:0,    desc:"Your class's natural appearance.",            req:"",       gender:"" },
        // --- Ungated (buy anytime) ---
        { id:"ashen",   name:"Ashen Revenant",  sprite:asset_get_index("spr_skin_ashen"),     gold:250,  desc:"A gaunt revenant wreathed in ash-grey rags.",  req:"",       gender:"m" },
        { id:"ember",   name:"Emberforged",     sprite:asset_get_index("spr_skin_ember"),     gold:250,  desc:"Molten plate that glows with an inner fire.",  req:"",       gender:"m" },
        { id:"tide",    name:"Tideborn",        sprite:asset_get_index("spr_skin_tide"),      gold:250,  desc:"Robes that flow like deep water.",             req:"",       gender:"f" },
        { id:"wanderer",name:"Wanderer's Garb", sprite:asset_get_index("spr_skin_wanderer"),  gold:250,  desc:"A travel-worn cloak from a hundred roads.",    req:"",       gender:"m" },
        { id:"hearth",  name:"Hearthguard",     sprite:asset_get_index("spr_skin_hearth"),    gold:300,  desc:"Warm banded leather, fire-tested.",            req:"",       gender:"f" },
        { id:"duskhide",name:"Duskhide",        sprite:asset_get_index("spr_skin_duskhide"),  gold:320,  desc:"Dark, supple rogue's leathers.",               req:"",       gender:"m" },
        { id:"pilgrim", name:"Pilgrim's Shroud",sprite:asset_get_index("spr_skin_pilgrim"),   gold:360,  desc:"The hooded robe of a wandering ascetic.",      req:"",       gender:"f" },
        { id:"ironscale",name:"Ironscale",      sprite:asset_get_index("spr_skin_ironscale"), gold:400,  desc:"Riveted scale, dented from old wars.",         req:"",       gender:"m" },
        // --- First full dungeon clear ---
        { id:"gravewalker",name:"Gravewalker",  sprite:asset_get_index("spr_skin_gravewalker"),gold:420, desc:"Plate caked in the dirt of a hundred graves.", req:"clear1", gender:"m" },
        { id:"bloodsworn", name:"Bloodsworn",   sprite:asset_get_index("spr_skin_bloodsworn"), gold:480, desc:"A crimson warsuit sworn in blood.",            req:"clear1", gender:"f" },
        { id:"cryptlight", name:"Cryptlight",   sprite:asset_get_index("spr_skin_cryptlight"), gold:550, desc:"The lantern-bearer's tattered wraps.",         req:"clear1", gender:"m" },
        // --- Clear an A1 dungeon ---
        { id:"frostbit", name:"Frostbitten",    sprite:asset_get_index("spr_skin_frostbit"),  gold:600,  desc:"Mail rimed with everlasting frost.",           req:"awk1",   gender:"f" },
        { id:"cinderclad",name:"Cinderclad",    sprite:asset_get_index("spr_skin_cinderclad"),gold:680,  desc:"Charred warplate still warm to the touch.",    req:"awk1",   gender:"m" },
        { id:"mirewalker",name:"Mirewalker",    sprite:asset_get_index("spr_skin_mirewalker"),gold:750,  desc:"Bog-shrouded hide that drips and reeks.",      req:"awk1",   gender:"m" },
        // --- Clear an A2 dungeon ---
        { id:"stormcall",name:"Stormcaller",    sprite:asset_get_index("spr_skin_stormcall"), gold:820,  desc:"Robes crackling with caged lightning.",        req:"awk2",   gender:"f" },
        { id:"bonechoir",name:"Bonechoir",      sprite:asset_get_index("spr_skin_bonechoir"), gold:900,  desc:"Armor bound from the singing dead.",           req:"awk2",   gender:"m" },
        { id:"veilbind", name:"Veilbinder",     sprite:asset_get_index("spr_skin_veilbind"),  gold:1000, desc:"A shadow-mage's shroud of woven dark.",        req:"awk2",   gender:"f" },
        // --- Clear an A3 dungeon ---
        { id:"goldwrought",name:"Goldwrought",  sprite:asset_get_index("spr_skin_goldwrought"),gold:1150,desc:"Regalia beaten from dungeon gold.",            req:"awk3",   gender:"f" },
        { id:"voidtouch",name:"Voidtouched",    sprite:asset_get_index("spr_skin_voidtouch"), gold:1250, desc:"Dark plate eaten through by stars.",            req:"awk3",   gender:"m" },
        { id:"sanguine", name:"Sanguine Regalia",sprite:asset_get_index("spr_skin_sanguine"), gold:1400, desc:"The blood-dark finery of a vampire lord.",     req:"awk3",   gender:"f" },
        // --- Clear an A4 dungeon ---
        { id:"dawnbreak",name:"Dawnbreaker",    sprite:asset_get_index("spr_skin_dawnbreak"), gold:1550, desc:"Radiant crusader plate that never dims.",      req:"awk4",   gender:"m" },
        { id:"doomherald",name:"Doomherald",    sprite:asset_get_index("spr_skin_doomherald"),gold:1750, desc:"The apocalyptic raiment of a warlord.",        req:"awk4",   gender:"m" },
        { id:"sovereign",name:"Eternal Sovereign",sprite:asset_get_index("spr_skin_sovereign"),gold:2000,desc:"Crown regalia worn beyond death itself.",      req:"awk4",   gender:"f" },
    ];
}

// True if the skin's milestone gate is met (ungated skins are always unlocked).
function vael_skin_unlocked(skin) {
    if (!variable_struct_exists(skin, "req") || skin.req == "") return true;
    switch (skin.req) {
        case "clear1": return (variable_global_exists("dungeon_clears_total") && global.dungeon_clears_total >= 1);
        case "awk1":   return (highest_awakening_unlocked() >= 2);
        case "awk2":   return (highest_awakening_unlocked() >= 3);
        case "awk3":   return (highest_awakening_unlocked() >= 4);
        case "awk4":   return (highest_awakening_unlocked() >= 5);
    }
    return true;
}

// Human-readable unlock requirement for a locked skin ("" if ungated/met).
function vael_skin_req_text(skin) {
    if (!variable_struct_exists(skin, "req")) return "";
    switch (skin.req) {
        case "clear1": return "Clear a full dungeon";
        case "awk1":   return "Clear an A1 dungeon";
        case "awk2":   return "Clear an A2 dungeon";
        case "awk3":   return "Clear an A3 dungeon";
        case "awk4":   return "Clear an A4 dungeon";
    }
    return "";
}

function vael_skin_get(id) {
    var _c = vael_skin_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}

// True if the skin is owned (default is always owned).
function vael_skin_owned(id) {
    if (id == "default") return true;
    if (!variable_global_exists("unlocked_skins")) return false;
    for (var _i = 0; _i < array_length(global.unlocked_skins); _i++)
        if (global.unlocked_skins[_i] == id) return true;
    return false;
}

// Buy a skin with gold (auto-equips on purchase). "" on success else reason.
function vael_buy_skin(id) {
    var _sk = vael_skin_get(id);
    if (_sk == undefined) return "Unknown skin.";
    if (vael_skin_owned(id)) return "Already owned.";
    if (!vael_skin_unlocked(_sk)) return "Locked - " + vael_skin_req_text(_sk);
    if (global.gold < _sk.gold) return "Need " + string(_sk.gold) + "g.";
    global.gold -= _sk.gold;
    if (!variable_global_exists("unlocked_skins")) global.unlocked_skins = [];
    array_push(global.unlocked_skins, id);
    global.player_skin = id;   // auto-equip
    save_game();
    return "";
}

// Equip an owned skin. "" on success else reason.
function vael_select_skin(id) {
    if (!vael_skin_owned(id)) return "Not owned.";
    global.player_skin = id;
    save_game();
    return "";
}

// The sprite to draw for the player in combat: active skin override, else the
// gender-appropriate class default. Guards missing skin/female sprites (-1) so it
// never errors before the art is imported.
function player_combat_sprite(class_id) {
    var _ci     = clamp(class_id, 0, 2);
    var _male   = [spr_arcanist, spr_bloodwarden, spr_shadowstrider];
    var _default = _male[_ci];

    // Female default look (cosmetic gender axis). Falls back to male if art absent.
    var _gender = (variable_global_exists("player_gender") ? global.player_gender : "m");
    if (_gender == "f") {
        var _fnames = ["spr_arcanist_f", "spr_bloodwarden_f", "spr_shadowstrider_f"];
        var _fid = asset_get_index(_fnames[_ci]);
        if (_fid != -1 && sprite_exists(_fid)) _default = _fid;
    }

    if (!variable_global_exists("player_skin") || global.player_skin == "default") return _default;
    var _sk = vael_skin_get(global.player_skin);
    if (_sk == undefined || _sk.sprite == undefined || _sk.sprite == -1 || !sprite_exists(_sk.sprite)) return _default;
    return _sk.sprite;
}

// Frame index to draw for a player/skin sprite: 8-directional sprites use east=frame 1
// (facing right toward enemies); single-frame side-view skins use frame 0. Lets the
// catalog hold 1-frame skins now and full 8-dir sprites later with no draw changes.
function player_sprite_frame(spr) {
    if (spr == -1 || !sprite_exists(spr)) return 0;
    return (sprite_get_number(spr) >= 8) ? 1 : 0;
}

// =============================================================================
// BOONS - run-scoped modifiers bought with TRIBUTE (gold / dust / item) at dungeon
// Shrine rooms. See SYSTEMS_BOONS.md. global.run_boons holds active boon ids and is
// reset every run (in end_run). Effects are queried via boon_active / boon_value.
// =============================================================================

function boon_catalog() {
    return [
        { id:"bloodlust",   name:"Bloodlust",     desc:"+15% damage dealt",                   cost:120, value:0.15 },
        { id:"ironhide",    name:"Ironhide",      desc:"+20% max HP",                          cost:120, value:0.20 },
        { id:"duelist",     name:"Duelist",       desc:"+10% crit chance",                     cost:120, value:10 },
        { id:"vampirism",   name:"Vampirism",     desc:"Heal 5 HP on each kill",               cost:140, value:5 },
        { id:"warding",     name:"Warding",       desc:"Take 12% less damage",                 cost:140, value:0.12 },
        { id:"greed",       name:"Greed",         desc:"+50% gold from kills",                 cost:80,  value:0.50 },
        { id:"runic",       name:"Runic Affinity",desc:"+50% rune dust from kills",            cost:80,  value:0.50 },
        { id:"executioner", name:"Executioner",   desc:"+25% damage to enemies below 30% HP",  cost:140, value:0.25 },
        { id:"aegis",       name:"Aegis",         desc:"Start each combat with a 15 shield",   cost:120, value:15 },
        { id:"glasscannon", name:"Glass Cannon",  desc:"+30% damage, -15% max HP",             cost:160, value:0.30 },
    ];
}

function boon_get(id) {
    var _c = boon_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}

function boon_active(id) {
    if (!variable_global_exists("run_boons")) return false;
    for (var _i = 0; _i < array_length(global.run_boons); _i++) if (global.run_boons[_i] == id) return true;
    return false;
}

function boon_value(id) {
    if (!boon_active(id)) return 0;
    var _b = boon_get(id);
    return (_b != undefined) ? _b.value : 0;
}

// Outgoing-damage multiplier from boons (Bloodlust + Glass Cannon, + Executioner
// when the target is below 30% HP). target_hp_frac in 0..1.
function boon_damage_mult(target_hp_frac) {
    var _m = 1.0;
    if (boon_active("bloodlust"))   _m += boon_value("bloodlust");
    if (boon_active("glasscannon")) _m += boon_value("glasscannon");
    if (boon_active("executioner") && target_hp_frac <= 0.30) _m += boon_value("executioner");
    return _m;
}

// Incoming-damage multiplier from boons (Warding).
function boon_incoming_mult() {
    return boon_active("warding") ? (1.0 - boon_value("warding")) : 1.0;
}

// Max-HP multiplier from boons (Ironhide +20%, Glass Cannon -15%).
function boon_maxhp_mult() {
    var _m = 1.0;
    if (boon_active("ironhide"))    _m += 0.20;
    if (boon_active("glasscannon")) _m -= 0.15;
    return _m;
}

function boon_grant(id) {
    if (!variable_global_exists("run_boons")) global.run_boons = [];
    if (!boon_active(id)) array_push(global.run_boons, id);
    save_game();
}

// --- Tribute ---------------------------------------------------------------
// Dust is worth 3 tribute points each; an item's worth scales by rarity.
function boon_dust_cost(cost) { return ceil(cost / 3); }
function item_tribute_value(rarity) {
    switch (rarity) { case 0: return 20; case 1: return 40; case 2: return 80; case 3: return 140; case 4: return 240; }
    return 20;
}

// Lowest-value unequipped item whose tribute worth covers `cost`. Returns
// {source, index, item} or undefined. (Auto-picked so the shrine needs no item picker.)
function boon_item_tribute_pick(cost) {
    var _best = undefined; var _best_val = 999999;
    if (variable_global_exists("carried_items")) {
        for (var _i = 0; _i < array_length(global.carried_items); _i++) {
            var _v = item_tribute_value(global.carried_items[_i].rarity);
            if (_v >= cost && _v < _best_val) { _best_val = _v; _best = { source:"carried", index:_i, item:global.carried_items[_i] }; }
        }
    }
    if (variable_global_exists("equipment_stash")) {
        for (var _i = 0; _i < array_length(global.equipment_stash); _i++) {
            var _v = item_tribute_value(global.equipment_stash[_i].rarity);
            if (_v >= cost && _v < _best_val) { _best_val = _v; _best = { source:"stash", index:_i, item:global.equipment_stash[_i] }; }
        }
    }
    return _best;
}

// Roll up to 3 distinct boons the player doesn't already own, for a shrine offer.
function boon_offer_roll() {
    var _cat = boon_catalog();
    var _pool = [];
    for (var _i = 0; _i < array_length(_cat); _i++) if (!boon_active(_cat[_i].id)) array_push(_pool, _cat[_i].id);
    // Fisher-Yates partial shuffle
    for (var _i = array_length(_pool) - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _t = _pool[_i]; _pool[_i] = _pool[_j]; _pool[_j] = _t;
    }
    var _out = [];
    for (var _i = 0; _i < min(3, array_length(_pool)); _i++) array_push(_out, _pool[_i]);
    return _out;
}

// Pay tribute for a boon. method "gold" / "dust" / "item". "" on success else reason.
function boon_pay(id, method) {
    var _b = boon_get(id);
    if (_b == undefined) return "Unknown boon.";
    if (boon_active(id)) return "Already claimed.";
    if (method == "gold") {
        if (global.gold < _b.cost) return "Need " + string(_b.cost) + "g.";
        global.gold -= _b.cost;
        boon_grant(id);
        return "";
    } else if (method == "dust") {
        var _dc = boon_dust_cost(_b.cost);
        if (!variable_global_exists("rune_dust") || global.rune_dust < _dc) return "Need " + string(_dc) + " dust.";
        global.rune_dust -= _dc;
        boon_grant(id);
        return "";
    } else if (method == "item") {
        var _pick = boon_item_tribute_pick(_b.cost);
        if (_pick == undefined) return "No item valuable enough to sacrifice.";
        if (_pick.source == "carried") array_delete(global.carried_items, _pick.index, 1);
        else                           array_delete(global.equipment_stash, _pick.index, 1);
        boon_grant(id);
        return "";
    }
    return "Invalid tribute.";
}

// =============================================================================
// CURSES - "Devil's Bargain". The inverse of boons: accept a run-long PENALTY in
// exchange for a run-long REWARD boost (better loot + more gold/dust). No up-front
// cost - the price is the added difficulty. Offered at Curse altars (a Shrine room
// rolls as either a Blessing altar = boons, or a Curse altar = curses). Free to
// stack; locked once accepted; reset every run (in end_run). See SYSTEMS_CURSES.md.
// global.run_curses holds active curse ids; effects are queried via curse_active.
// =============================================================================

function curse_catalog() {
    // tier:   1 = always offered, 2 = needs awakening >=2, 3 = needs awakening >=4
    // loot:   tiers ADDED to the awakening fed into drop_weights (better loot)
    // gold:   additive gold-find multiplier (e.g. 0.40 = +40%)
    // dust:   additive rune-dust multiplier
    return [
        { id:"frail",      name:"Frail",        tier:1, desc:"-20% max HP",                          reward:"+40% gold found",                          loot:0, gold:0.40, dust:0.00 },
        { id:"famine",     name:"Famine",       tier:1, desc:"No consumable drops this run",         reward:"+60% rune dust",                           loot:0, gold:0.00, dust:0.60 },
        { id:"exposed",    name:"Exposed",      tier:1, desc:"Take +15% damage",                      reward:"Loot rarity +1 tier",                      loot:1, gold:0.00, dust:0.00 },
        { id:"bloodprice", name:"Blood Price",  tier:2, desc:"Lose 4 HP at the start of each turn",   reward:"+50% gold & rune dust",                    loot:0, gold:0.50, dust:0.50 },
        { id:"savagery",   name:"Savagery",     tier:2, desc:"Enemies deal +20% damage",             reward:"Loot rarity +1 tier, +25% gold",           loot:1, gold:0.25, dust:0.00 },
        { id:"withered",   name:"Withered",     tier:2, desc:"-50% healing received",                reward:"Loot rarity +1 tier",                      loot:1, gold:0.00, dust:0.00 },
        { id:"doom",       name:"Doom",         tier:3, desc:"Enemies have +25% HP and +15% damage", reward:"Loot rarity +2 tiers",                     loot:2, gold:0.00, dust:0.00 },
        { id:"damnation",  name:"Damnation",    tier:3, desc:"Start each combat at 65% HP",          reward:"Loot rarity +2 tiers, +40% gold",          loot:2, gold:0.40, dust:0.00 },
        { id:"ruin",       name:"Ruin",         tier:3, desc:"-30% max HP and +10% damage taken",    reward:"Loot rarity +2 tiers, +50% rune dust",     loot:2, gold:0.00, dust:0.50 },
        { id:"devilspact", name:"Devil's Pact", tier:3, desc:"Enemies +20% damage; you -15% max HP", reward:"Loot +2 tiers; bonus drop from every elite & boss", loot:2, gold:0.00, dust:0.00 },
    ];
}

function curse_get(id) {
    var _c = curse_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}

function curse_active(id) {
    if (!variable_global_exists("run_curses")) return false;
    for (var _i = 0; _i < array_length(global.run_curses); _i++) if (global.run_curses[_i] == id) return true;
    return false;
}

function curse_grant(id) {
    if (!variable_global_exists("run_curses")) global.run_curses = [];
    if (!curse_active(id)) array_push(global.run_curses, id);
    save_game();
}

// Higher-tier curses unlock with meta progression (matches the skin gate idiom).
function curse_tier_available(tier) {
    if (tier <= 1) return true;
    var _awk = highest_awakening_unlocked();
    if (tier == 2) return _awk >= 2;
    return _awk >= 4;   // tier 3
}

// Accept a curse for free (the difficulty IS the cost). "" on success else reason.
function curse_accept(id) {
    var _c = curse_get(id);
    if (_c == undefined) return "Unknown curse.";
    if (curse_active(id)) return "Already bound.";
    if (!curse_tier_available(_c.tier)) return "Not yet attainable.";
    curse_grant(id);
    return "";
}

// Roll up to 3 distinct, tier-available curses the player doesn't already carry.
function curse_offer_roll() {
    var _cat = curse_catalog();
    var _pool = [];
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (curse_active(_cat[_i].id)) continue;
        if (!curse_tier_available(_cat[_i].tier)) continue;
        array_push(_pool, _cat[_i].id);
    }
    // Fisher-Yates partial shuffle
    for (var _i = array_length(_pool) - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _t = _pool[_i]; _pool[_i] = _pool[_j]; _pool[_j] = _t;
    }
    var _out = [];
    for (var _i = 0; _i < min(3, array_length(_pool)); _i++) array_push(_out, _pool[_i]);
    return _out;
}

// --- Penalty multipliers (parallel the boon_* hooks) -----------------------
// Max-HP multiplier from curses (Frail -20%, Ruin -30%, Devil's Pact -15%).
function curse_maxhp_mult() {
    var _m = 1.0;
    if (curse_active("frail"))      _m -= 0.20;
    if (curse_active("ruin"))       _m -= 0.30;
    if (curse_active("devilspact")) _m -= 0.15;
    return max(0.20, _m);   // never reduce below 20% so the run stays playable
}

// Incoming-damage multiplier from curses (Exposed +15%, Ruin +10%).
function curse_incoming_mult() {
    var _m = 1.0;
    if (curse_active("exposed")) _m += 0.15;
    if (curse_active("ruin"))    _m += 0.10;
    return _m;
}

// Enemy max-HP multiplier (Doom +25%).
function curse_enemy_hp_mult() {
    return curse_active("doom") ? 1.25 : 1.0;
}

// Enemy outgoing-damage multiplier (Savagery +20%, Doom +15%, Devil's Pact +20%).
function curse_enemy_damage_mult() {
    var _m = 1.0;
    if (curse_active("savagery"))   _m += 0.20;
    if (curse_active("doom"))       _m += 0.15;
    if (curse_active("devilspact")) _m += 0.20;
    return _m;
}

// --- Reward multipliers ----------------------------------------------------
// Loot-tier bonus added to the awakening fed into drop_weights (sums all curses).
function curse_loot_asc_bonus() {
    if (!variable_global_exists("run_curses")) return 0;
    var _b = 0;
    var _cat = curse_catalog();
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (curse_active(_cat[_i].id)) _b += _cat[_i].loot;
    }
    return _b;
}

// Gold-find multiplier from curses (additive, 1.0 = no change).
function curse_gold_mult() {
    if (!variable_global_exists("run_curses")) return 1.0;
    var _m = 1.0;
    var _cat = curse_catalog();
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (curse_active(_cat[_i].id)) _m += _cat[_i].gold;
    }
    return _m;
}

// Rune-dust multiplier from curses (additive, 1.0 = no change).
function curse_dust_mult() {
    if (!variable_global_exists("run_curses")) return 1.0;
    var _m = 1.0;
    var _cat = curse_catalog();
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (curse_active(_cat[_i].id)) _m += _cat[_i].dust;
    }
    return _m;
}

// --- Misc penalty queries --------------------------------------------------
function curse_blocks_consumables()   { return curse_active("famine"); }                 // Famine
function curse_heal_mult()            { return curse_active("withered") ? 0.50 : 1.0; }  // Withered -50% healing
function curse_combat_start_hp_frac() { return curse_active("damnation") ? 0.65 : 1.0; } // Damnation
function curse_turn_hp_drain()        { return curse_active("bloodprice") ? 4 : 0; }     // Blood Price
function curse_has_bonus_drops()      { return curse_active("devilspact"); }             // Devil's Pact

// =============================================================================
// ONBOARDING - contextual coach-marks. The first time the player reaches each key
// surface (hub / loadout / combat / Vex / shrine / ...), a one-time dismissable tip
// box teaches it, then never shows again. See SYSTEMS_ONBOARDING.md. Gated by
// global.tutorial_seen (per-tip flags, saved) + global.tutorial_enabled (toggle).
// global.tutorial_active = the id currently being shown ("" = none).
// =============================================================================

function tutorial_catalog() {
    return [
        { id:"hub",        title:"The Ironwake Camp",   body:"This is your hub between runs. Visit the camp's merchants and trainers, manage gear and abilities, then approach the dungeon gate to descend. Anything you bank here carries between runs." },
        { id:"loadout",    title:"Prepare to Descend",  body:"Before each run, equip your gear and choose which abilities and traits to bring. You can only take a limited set into the dungeon, so build around how you want to fight." },
        { id:"ascendance", title:"Awakening Tiers",     body:"Higher Awakening tiers make enemies tougher but drop better, rarer loot. Raise the tier when you want more risk for more reward - start low and work up." },
        { id:"combat_ap",  title:"Action Points (AP)",  body:"Each turn you have 3 AP. Abilities cost AP to use; a basic attack is free. Spend your AP wisely, then end your turn to let the enemy act." },
        { id:"targeting",  title:"Choosing a Target",   body:"When several foes are present, Tab or click to pick who you hit. The glowing rune beneath an enemy marks your current target." },
        { id:"inspect",    title:"Inspect Your Foes",   body:"Mouse over an enemy (or its health bar) to inspect it. You'll see whether it fights at Melee or Ranged and with Phys or Spell - and which controls stop it: Root halts melee, Silence stops spells, Stun stops anything. Ranged foes ignore Root, so a trap won't keep them off you." },
        { id:"vex",        title:"Vex the Trainer",     body:"Vex teaches new abilities and traits for gold (and the occasional item). Learn abilities here, then slot them on the loadout screen before a run." },
        { id:"shrine",     title:"Altars",              body:"A shrine is an altar. A Blessing altar sells boons for tribute; a Cursed altar lets you take on a curse - a run-long penalty - in exchange for far better spoils. Choose how greedy you dare to be." },
    ];
}

function tutorial_get(id) {
    var _c = tutorial_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}

function tutorial_seen_has(id) {
    if (!variable_global_exists("tutorial_seen")) return false;
    return variable_struct_exists(global.tutorial_seen, id) && global.tutorial_seen[$ id];
}

function tutorial_mark_seen(id) {
    if (!variable_global_exists("tutorial_seen")) global.tutorial_seen = {};
    global.tutorial_seen[$ id] = true;
    save_game();
}

// Try to raise a tip. Returns true if it became the active tip (so callers can react,
// e.g. open into a paused state). seen is marked on DISMISS, not here, so an
// interrupted show re-shows next time.
function tutorial_try_show(id) {
    if (variable_global_exists("tutorial_enabled") && !global.tutorial_enabled) return false;
    if (tutorial_seen_has(id)) return false;
    if (tutorial_get(id) == undefined) return false;
    if (variable_global_exists("tutorial_active") && global.tutorial_active != "") return false; // one at a time
    global.tutorial_active = id;
    return true;
}

function tutorial_is_active() {
    return variable_global_exists("tutorial_active") && global.tutorial_active != "";
}

// Dismiss the active tip (mark it seen). Call from the shared input intercept.
function tutorial_dismiss() {
    if (!tutorial_is_active()) return;
    tutorial_mark_seen(global.tutorial_active);
    global.tutorial_active = "";
}

// Re-show every tip (Settings "Reset tutorial").
function tutorial_reset_all() {
    global.tutorial_seen = {};
    if (variable_global_exists("tutorial_active")) global.tutorial_active = "";
    save_game();
}

// =============================================================================
// SHARED ITEM-SACRIFICE PICKER  (see SYSTEMS_ITEM_PICKER.md)
// A single modal that lets the player SELECT exactly which item to give up and
// CONFIRM before it's destroyed. Replaces the old "auto-pick the least valuable
// qualifying item" behavior that silently consumed gear. Used by Vex (stat &
// trait trades) and the Shrine (item tribute). State lives in global.item_picker
// (initialized in obj_game_controller Create). Drawn by ui_draw_item_picker().
// =============================================================================

// Open the picker. purpose drives the resolve + prompt; context is purpose data;
// candidates is the selectable list (see the candidate builders below).
function item_picker_open(purpose, context, candidates) {
    var _p = global.item_picker;
    _p.open             = true;
    _p.purpose          = purpose;
    _p.context          = context;
    _p.candidates       = candidates;
    _p.cursor           = 0;
    _p.scroll           = 0;
    _p.confirm          = false;
    _p.resolved_purpose = "";
    _p.result_msg       = "";
}

function item_picker_close() {
    var _p = global.item_picker;
    _p.open       = false;
    _p.confirm    = false;
    _p.candidates = [];
}

// Every held item (stash + pack) of at least min_rarity, sorted least-valuable
// first (so the default cursor lands on the "safe" choice) but ALL selectable.
// source 0 = global.equipment_stash, 1 = global.carried_items.
function item_picker_candidates_by_rarity(min_rarity) {
    var _out = [];
    // Stash is HUB-ONLY - mid-run (Shrine/event) it isn't reachable, so only the
    // carried pack may be sacrificed. (Vex/Sable run this in the hub -> stash allowed.)
    var _in_hub = (room == rm_hub || room == rm_character_select);
    for (var _s = 0; _s < 2; _s++) {
        if (_s == 0 && !_in_hub) continue;
        var _arr = (_s == 0) ? global.equipment_stash : global.carried_items;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _it = _arr[_i];
            if (!is_struct(_it)) continue;
            var _rar = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
            if (_rar < min_rarity) continue;
            var _val = variable_struct_exists(_it, "gold_value") ? _it.gold_value : 0;
            var _nm  = variable_struct_exists(_it, "name") ? _it.name : "item";
            array_push(_out, { source:_s, idx:_i, item:_it, label:_nm, rarity:_rar, value:_val });
        }
    }
    array_sort(_out, function(a, b) {
        if (a.rarity != b.rarity) return a.rarity - b.rarity;
        return a.value - b.value;
    });
    return _out;
}

// Every held item whose tribute worth (item_tribute_value) covers `cost`.
function item_picker_candidates_by_tribute(cost) {
    var _out = [];
    // Stash is HUB-ONLY - the Shrine runs mid-run, so only the carried pack qualifies.
    var _in_hub = (room == rm_hub || room == rm_character_select);
    for (var _s = 0; _s < 2; _s++) {
        if (_s == 0 && !_in_hub) continue;
        var _arr = (_s == 0) ? global.equipment_stash : global.carried_items;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _it = _arr[_i];
            if (!is_struct(_it)) continue;
            var _rar = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
            if (item_tribute_value(_rar) < cost) continue;
            var _val = variable_struct_exists(_it, "gold_value") ? _it.gold_value : 0;
            var _nm  = variable_struct_exists(_it, "name") ? _it.name : "item";
            array_push(_out, { source:_s, idx:_i, item:_it, label:_nm, rarity:_rar, value:_val });
        }
    }
    array_sort(_out, function(a, b) {
        if (a.rarity != b.rarity) return a.rarity - b.rarity;
        return a.value - b.value;
    });
    return _out;
}

// --- Alchemical Rebirth (Sable tab 3) ----------------------------------------
// Every held class-specific item (class_req != -1) of uncommon+ rarity. Common
// is excluded - Cracked Focus is the only common class weapon, so there is no
// alternate class to reforge into at that tier.
function item_picker_candidates_class_specific() {
    var _out = [];
    // Stash is HUB-ONLY. (Sable's Alch Rebirth runs in the hub, so stash is allowed
    // there; the gate keeps the rule consistent if this is ever reused mid-run.)
    var _in_hub = (room == rm_hub || room == rm_character_select);
    for (var _s = 0; _s < 2; _s++) {
        if (_s == 0 && !_in_hub) continue;
        var _arr = (_s == 0) ? global.equipment_stash : global.carried_items;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _it = _arr[_i];
            if (!is_struct(_it)) continue;
            var _cr  = variable_struct_exists(_it, "class_req") ? _it.class_req : -1;
            var _rar = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
            if (_cr == -1 || _rar < 1) continue;
            var _val = variable_struct_exists(_it, "gold_value") ? _it.gold_value : 0;
            var _nm  = variable_struct_exists(_it, "name") ? _it.name : "item";
            array_push(_out, { source:_s, idx:_i, item:_it, label:_nm, rarity:_rar, value:_val });
        }
    }
    array_sort(_out, function(a, b) {
        if (a.rarity != b.rarity) return a.rarity - b.rarity;
        return a.value - b.value;
    });
    return _out;
}

// Rebirth cost by the sacrificed item's rarity -> { dust, gold }.
function alch_rebirth_cost(rarity) {
    if (rarity >= 3) return { dust: 10, gold: 500 };   // epic
    if (rarity == 2) return { dust: 6,  gold: 250 };   // rare
    return { dust: 3, gold: 120 };                     // uncommon
}

// Build a reborn item: a class-specific weapon of a DIFFERENT class, matching the
// sacrificed item's rarity, with rarity-appropriate affixes. Returns undefined if
// no alternate-class template exists. Mirrors drop_equipment's affix logic.
function alch_rebirth_make(old_item) {
    var _old_class = variable_struct_exists(old_item, "class_req") ? old_item.class_req : -1;
    var _r = variable_struct_exists(old_item, "rarity") ? old_item.rarity : 1;
    // Epic (3) draws from the rare templates, like drop_equipment.
    var _tbl = (_r <= 1) ? global.loot_table_uncommon : global.loot_table_rare;
    var _cands = [];
    for (var _i = 0; _i < array_length(_tbl); _i++) {
        var _b = _tbl[_i];
        if (variable_struct_exists(_b, "class_req") && _b.class_req != -1
            && _b.class_req != _old_class) {
            array_push(_cands, _b);
        }
    }
    if (array_length(_cands) == 0) return undefined;
    var _base = _cands[irandom(array_length(_cands) - 1)];
    var _item = clone_item(_base);
    _item.rarity = _r;
    var _ac = 0;
    if (_r == 1)      _ac = 1;
    else if (_r == 2) _ac = (irandom(1) == 0) ? 1 : 2;
    else if (_r >= 3) _ac = 2;
    if (_ac > 0) apply_affixes_to_item(_item, roll_affixes(min(_r, 3), _ac, [_item.stat_name]));
    _item.socket_count = rune_sockets_for_rarity(_item.rarity);
    return _item;
}

// Remove the currently-selected candidate from its source array and return its
// name. The game is frozen while the picker is open so the stored index is valid;
// we still match by struct identity as a defensive fallback.
function item_picker_remove_selected() {
    var _p = global.item_picker;
    if (_p.cursor < 0 || _p.cursor >= array_length(_p.candidates)) return "item";
    var _c   = _p.candidates[_p.cursor];
    var _arr = (_c.source == 0) ? global.equipment_stash : global.carried_items;
    if (_c.idx >= 0 && _c.idx < array_length(_arr) && _arr[_c.idx] == _c.item) {
        array_delete(_arr, _c.idx, 1);
        return _c.label;
    }
    for (var _s = 0; _s < 2; _s++) {
        var _a2 = (_s == 0) ? global.equipment_stash : global.carried_items;
        for (var _i = 0; _i < array_length(_a2); _i++) {
            if (_a2[_i] == _c.item) { array_delete(_a2, _i, 1); return _c.label; }
        }
    }
    return _c.label;
}

// Header prompt + confirm verb per purpose.
function item_picker_prompt() {
    switch (global.item_picker.purpose) {
        case "vex_trait": return "Choose an item to trade to Vex for this trait";
        case "vex_stat":  return "Choose an item to trade to Vex for the upgrade";
        case "shrine_boon": return "Choose an item to sacrifice at the shrine";
        case "alch_rebirth": return "Choose a class item to reforge (cost scales with rarity)";
    }
    return "Choose an item";
}
function item_picker_verb() {
    switch (global.item_picker.purpose) {
        case "shrine_boon":  return "Sacrifice";
        case "alch_rebirth": return "Reforge";
    }
    return "Trade away";
}

// Commit: remove the selected item, apply the purpose's effect, stash a one-shot
// result the owning controller reads for its notification + cleanup, then close.
function item_picker_resolve() {
    var _p    = global.item_picker;
    var _ctx  = _p.context;
    var _msg  = "";

    // Alchemical Rebirth needs the item's data + an affordability gate BEFORE removal,
    // so it never destroys the item when the player can't pay.
    if (_p.purpose == "alch_rebirth") {
        var _sel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                   ? _p.candidates[_p.cursor] : undefined;
        if (_sel == undefined) {
            _p.resolved_purpose = "alch_rebirth"; _p.result_msg = "Nothing to reforge.";
            item_picker_close(); return;
        }
        var _cost = alch_rebirth_cost(_sel.rarity);
        var _have_gold = variable_global_exists("gold") ? global.gold : 0;
        var _have_dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
        if (_have_gold < _cost.gold || _have_dust < _cost.dust) {
            _p.resolved_purpose = "alch_rebirth";
            _p.result_msg = "Not enough - need " + string(_cost.dust) + " dust + " + string(_cost.gold) + "g.";
            item_picker_close(); return;
        }
        var _new = alch_rebirth_make(_sel.item);
        if (_new == undefined) {
            _p.resolved_purpose = "alch_rebirth";
            _p.result_msg = "No alternate class item exists at that rarity.";
            item_picker_close(); return;
        }
        var _old_name = _sel.label;
        var _src      = _sel.source;
        item_picker_remove_selected();                 // consume the sacrificed item
        global.gold      -= _cost.gold;
        global.rune_dust -= _cost.dust;
        if (_src == 0) array_push(global.equipment_stash, _new);
        else           array_push(global.carried_items, _new);
        discover_item(item_base_name(_new));
        save_game();
        _p.resolved_purpose = "alch_rebirth";
        _p.result_msg = "Reforged " + _old_name + " into " + _new.name + "!";
        item_picker_close();
        return;
    }

    var _name = item_picker_remove_selected();
    switch (_p.purpose) {
        case "vex_trait":
            global.gold -= _ctx.gold;
            if (!variable_global_exists("traits_unlocked")) global.traits_unlocked = {};
            variable_struct_set(global.traits_unlocked, _ctx.effect_id, true);
            save_game();
            _msg = "Unlocked " + _ctx.trait_name + "!   (traded: " + _name + ")";
            break;
        case "vex_stat":
            global.gold -= _ctx.gold;
            variable_global_set(_ctx.stat_key, variable_global_get(_ctx.stat_key) + 1);
            save_game();
            _msg = "+1 permanent " + _ctx.stat_name + "   (traded: " + _name + ")";
            break;
        case "shrine_boon":
            boon_grant(_ctx.boon_id);
            var _bd = boon_get(_ctx.boon_id);
            _msg = "Claimed " + ((_bd != undefined) ? _bd.name : "boon") + "! The altar crumbles.   (traded: " + _name + ")";
            break;
    }
    _p.resolved_purpose = _p.purpose;
    _p.result_msg       = _msg;
    item_picker_close();
}

// Per-step input while the picker modal is open. Geometry mirrors
// ui_draw_item_picker(). Esc/right-click cancels (loses nothing).
function item_picker_step() {
    var _p = global.item_picker;
    var _n = array_length(_p.candidates);

    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)
        || mouse_check_button_pressed(mb_right)) {
        if (_p.confirm) _p.confirm = false;
        else            item_picker_close();
        return;
    }

    if (_n == 0) {   // nothing qualifies (shouldn't happen - caller pre-checks) - let any key close
        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
            || keyboard_check_pressed(vk_space)) item_picker_close();
        return;
    }

    if (nav_up())   { _p.cursor = wrap_index(_p.cursor - 1, _n); _p.confirm = false; }
    if (nav_down()) { _p.cursor = wrap_index(_p.cursor + 1, _n); _p.confirm = false; }

    // Mouse hover moves the cursor so the detail pane (full description) follows the
    // pointer. Gated on the mouse actually MOVING so it doesn't fight keyboard nav, and
    // skipped while the confirm bar is armed. Geometry mirrors ui_draw_item_picker().
    if (!_p.confirm) {
        var _hmx = device_mouse_x_to_gui(0);
        var _hmy = device_mouse_y_to_gui(0);
        var _moved = (!variable_struct_exists(_p, "hover_mx") || _hmx != _p.hover_mx || _hmy != _p.hover_my);
        _p.hover_mx = _hmx; _p.hover_my = _hmy;
        if (_moved) {
            var _hpx = 330, _hpy = 165;
            var _hlx0 = _hpx + 24, _hlx1 = _hpx + 606, _hly0 = _hpy + 129, _hrh = 57;
            var _hvis = min(8, _n);
            for (var _hr = 0; _hr < _hvis; _hr++) {
                var _hry = _hly0 + _hr * _hrh;
                if (_hmx >= _hlx0 && _hmx < _hlx1 && _hmy >= _hry && _hmy < _hry + 51) {
                    _p.cursor = clamp(_p.scroll + _hr, 0, _n - 1);
                    break;
                }
            }
        }
    }

    _p.cursor = clamp(_p.cursor, 0, _n - 1);
    _p.scroll = loadout_list_scroll(_p.cursor, _n, 8);

    var _act = (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
        || keyboard_check_pressed(vk_space));

    // Mouse: row select / re-click acts; clicking the armed confirm bar commits.
    if (mouse_check_button_pressed(mb_left)) {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        // Geometry MUST stay in sync with ui_draw_item_picker() (scr_ui).
        var _px = 330, _pw = 1260, _py = 165, _ph = 750;
        var _lx0 = _px + 24, _lx1 = _px + 606, _ly0 = _py + 129, _rh = 57;
        var _cby0 = _py + _ph - 114, _cby1 = _py + _ph - 60;
        if (_p.confirm) {
            if (_my >= _cby0 && _my < _cby1 && _mx >= _px + 30 && _mx < _px + _pw - 30) _act = true;
        } else {
            var _vis = min(8, _n);
            for (var _r = 0; _r < _vis; _r++) {
                var _ry = _ly0 + _r * _rh;
                if (_mx >= _lx0 && _mx < _lx1 && _my >= _ry && _my < _ry + 51) {
                    var _idx = _p.scroll + _r;
                    if (_idx == _p.cursor) _act = true;
                    else { _p.cursor = _idx; _p.confirm = false; }
                    break;
                }
            }
        }
    }

    if (_act) {
        if (!_p.confirm) _p.confirm = true;
        else            item_picker_resolve();
    }
}

// =============================================================================
// EVENT ROOMS - interactive, stat-gated risk/reward choice rooms.
// See SYSTEMS_EVENTS.md. The catalog is data-driven; a choice resolves to one
// outcome by "weighted" (fixed integer weights) or "check" (stat-scaled
// success/fail). Outcomes apply an `effects` struct. HP changes are DEFERRED to
// the next combat via pending_trap_damage / pending_rest_heal (reusing the
// trap/rest hooks - there is no persistent overworld HP bar).
// =============================================================================

// Effective character stat = base allocation + run XP bonuses (+ perm CHA bonus).
function player_effective_stat(stat_name) {
    if (stat_name == "CHA") return player_effective_cha();
    if (!variable_global_exists("chosen_stats")) return 0;
    var _v = variable_struct_get(global.chosen_stats, stat_name);
    if (is_undefined(_v)) _v = 0;
    if (variable_global_exists("run_stat_bonuses")
        && variable_struct_exists(global.run_stat_bonuses, stat_name)) {
        _v += variable_struct_get(global.run_stat_bonuses, stat_name);
    }
    return max(0, _v);
}

// Success% for a stat check: clamp(base + (stat - ref) * per, 10, 90).
function event_check_chance(stat_name, base_pct, per_point, ref) {
    var _s = player_effective_stat(stat_name);
    // Sense trait: a flat +5% to every stat-check's success odds (read of the room
    // tips the bet in your favor). Folded into the base before the curve + clamp.
    var _sense_bonus = trait_active("Sense") ? 5 : 0;
    return clamp(base_pct + _sense_bonus + (_s - ref) * per_point, 10, 90);
}

// event_effect_phrase(fx) - short plain-language summary of an effects struct,
// e.g. "+50g + gear", "-22 HP", "a BOON". Used in the mechanics line so players
// see what each outcome actually grants. "nothing" for an empty/undefined fx.
function event_effect_phrase(fx) {
    if (fx == undefined) return "nothing";
    var _p = [];
    if (variable_struct_exists(fx, "gold") && fx.gold != 0)
        array_push(_p, (fx.gold > 0 ? "+" : "") + string(fx.gold) + "g");
    if (variable_struct_exists(fx, "hp") && fx.hp != 0)
        array_push(_p, (fx.hp > 0 ? "+" : "") + string(fx.hp) + " HP");
    if (variable_struct_exists(fx, "item") && fx.item != "") {
        var _lbl = "gear";
        if (fx.item == "vault")          _lbl = "good gear";
        else if (fx.item == "reliquary") _lbl = "a relic";
        array_push(_p, _lbl);
    }
    if (variable_struct_exists(fx, "consumable") && fx.consumable != "")
        array_push(_p, "a potion");
    if (variable_struct_exists(fx, "dust") && fx.dust > 0)
        array_push(_p, "+" + string(fx.dust) + " dust");
    if (variable_struct_exists(fx, "rune") && fx.rune > 0)
        array_push(_p, "a rune");
    if (variable_struct_exists(fx, "boon") && fx.boon != "")
        array_push(_p, "a BOON");
    if (array_length(_p) == 0) return "nothing";
    var _s = "";
    for (var _i = 0; _i < array_length(_p); _i++) _s += (_i > 0 ? " + " : "") + _p[_i];
    return _s;
}

// event_choice_mechanics_text(choice) - the generated "mechanics" line shown under
// a choice's lore hint: cost/requirement prefix, then for a stat check the odds at
// the player's current stat plus win/lose outcomes, or for a weighted choice the
// per-outcome chances. Keeps the catalog lean (no hand-written odds text).
function event_choice_mechanics_text(choice) {
    var _prefix = "";
    if (variable_struct_exists(choice, "req_stat") && choice.req_stat != "" && choice.req_amount > 0)
        _prefix += "Needs " + choice.req_stat + " " + string(choice.req_amount) + ".  ";
    var _cost = event_choice_cost(choice);
    if (_cost > 0) _prefix += "Costs " + string(_cost) + "g.  ";

    if (choice.resolve == "check") {
        var _pct = event_check_chance(choice.check_stat, choice.check_base, choice.check_per, choice.check_ref);
        return _prefix + choice.check_stat + " check ~" + string(_pct) + "%"
             + "  -  Win: " + event_effect_phrase(choice.success.effects)
             + "  -  Lose: " + event_effect_phrase(choice.fail.effects);
    }

    // weighted
    var _outs = choice.outcomes;
    if (array_length(_outs) == 1)
        return _prefix + "Always: " + event_effect_phrase(_outs[0].effects);

    var _total = 0;
    for (var _i = 0; _i < array_length(_outs); _i++) _total += _outs[_i].weight;
    var _s = _prefix;
    for (var _i = 0; _i < array_length(_outs); _i++) {
        var _pc = (_total > 0) ? round(_outs[_i].weight * 100 / _total) : 0;
        _s += (_i > 0 ? "  -  " : "") + string(_pc) + "% " + event_effect_phrase(_outs[_i].effects);
    }
    return _s;
}

// Gold cost of a choice (0 if none). Choices flagged cha_cost get the CHA discount.
function event_choice_cost(choice) {
    var _c = variable_struct_exists(choice, "cost_gold") ? choice.cost_gold : 0;
    if (_c <= 0) return 0;
    if (variable_struct_exists(choice, "cha_cost") && choice.cha_cost) return cha_price(_c);
    return _c;
}

// A choice is unlocked if its stat gate is met AND its gold cost is affordable.
function event_choice_unlocked(choice) {
    if (variable_struct_exists(choice, "req_stat") && choice.req_stat != "") {
        if (player_effective_stat(choice.req_stat) < choice.req_amount) return false;
    }
    if (event_choice_cost(choice) > global.gold) return false;
    return true;
}

// First unlocked choice index (fallback 0) - used to place the cursor on open.
function event_first_unlocked(ev) {
    for (var _i = 0; _i < array_length(ev.choices); _i++) {
        if (event_choice_unlocked(ev.choices[_i])) return _i;
    }
    return 0;
}

// Resolve a confirmed choice to one outcome struct { text, effects }.
function event_resolve_choice(choice) {
    if (choice.resolve == "check") {
        var _pct = event_check_chance(choice.check_stat, choice.check_base, choice.check_per, choice.check_ref);
        return (irandom(99) < _pct) ? choice.success : choice.fail;
    }
    // weighted
    var _outs  = choice.outcomes;
    var _total = 0;
    for (var _i = 0; _i < array_length(_outs); _i++) _total += _outs[_i].weight;
    var _roll = irandom(max(0, _total - 1));
    var _cum  = 0;
    for (var _i = 0; _i < array_length(_outs); _i++) {
        _cum += _outs[_i].weight;
        if (_roll < _cum) return _outs[_i];
    }
    return _outs[array_length(_outs) - 1];
}

// Apply an effects struct and return a multi-line "rewards" summary for the
// result screen (concrete gains: gold, HP, item/consumable/dust/rune/boon names).
function event_apply_effects(fx) {
    if (fx == undefined) return "";
    var _asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) + curse_loot_asc_bonus();
    var _sum = [];

    // Gold
    if (variable_struct_exists(fx, "gold") && fx.gold != 0) {
        if (fx.gold > 0) { add_gold(fx.gold); array_push(_sum, "+" + string(fx.gold) + " gold"); }
        else { global.gold = max(0, global.gold - abs(fx.gold)); array_push(_sum, string(fx.gold) + " gold"); }
    }
    // HP (deferred to next combat)
    if (variable_struct_exists(fx, "hp") && fx.hp != 0) {
        if (fx.hp > 0) {
            if (!variable_global_exists("pending_rest_heal")) global.pending_rest_heal = 0;
            global.pending_rest_heal += fx.hp;
            array_push(_sum, "+" + string(fx.hp) + " HP (next combat)");
        } else {
            if (!variable_global_exists("pending_trap_damage")) global.pending_trap_damage = 0;
            global.pending_trap_damage += abs(fx.hp);
            array_push(_sum, string(fx.hp) + " HP (next combat)");
        }
    }
    // Equipment item - fx.item is a drop-source string ("chest"/"vault"/...)
    if (variable_struct_exists(fx, "item") && fx.item != "") {
        if (!variable_global_exists("run_items_found")) global.run_items_found = [];
        if (!variable_global_exists("carried_items"))   global.carried_items   = [];
        var _it = drop_equipment(drop_weights(fx.item, _asc));
        array_push(global.run_items_found, _it);
        array_push(global.carried_items, _it);
        array_push(_sum, _it.name + " [" + item_rarity_name(_it.rarity) + "]");
    }
    // Consumable - fx.consumable is a pool name "standard"/"elite"
    if (variable_struct_exists(fx, "consumable") && fx.consumable != "") {
        if (!variable_global_exists("run_items_found"))      global.run_items_found      = [];
        if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
        var _pool = (fx.consumable == "elite") ? global.consumables_elite : global.consumables_standard;
        var _c = roll_consumable_weighted(_pool);
        array_push(global.run_items_found, _c);
        var _fit = consumable_award(_c);
        array_push(_sum, _c.name + (_fit ? "" : " (pack full)"));
    }
    // Rune dust
    if (variable_struct_exists(fx, "dust") && fx.dust > 0) {
        if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
        global.rune_dust += fx.dust;
        array_push(_sum, "+" + string(fx.dust) + " Dust");
    }
    // Rune drop - fx.rune is a tier int
    if (variable_struct_exists(fx, "rune") && fx.rune > 0) {
        if (!variable_global_exists("rune_inventory")) global.rune_inventory = [];
        var _rn = rune_random(fx.rune);
        array_push(global.rune_inventory, _rn);
        array_push(_sum, _rn.name + " " + rune_tier_roman(_rn.tier) + " [Rune]");
    }
    // Boon (rare jackpot) - "random" picks an unowned boon, else a specific id
    if (variable_struct_exists(fx, "boon") && fx.boon != "") {
        var _bid = fx.boon;
        if (_bid == "random") {
            var _offers = boon_offer_roll();
            _bid = (array_length(_offers) > 0) ? _offers[0] : "";
        }
        if (_bid != "") {
            boon_grant(_bid);
            var _bd = boon_get(_bid);
            if (_bd != undefined) array_push(_sum, "BOON: " + _bd.name + "!");
        }
    }

    var _str = "";
    for (var _i = 0; _i < array_length(_sum); _i++) _str += (_i > 0 ? "\n" : "") + _sum[_i];
    return _str;
}

// Pick one random event from the catalog (roll-on-entry; not seed-critical).
// §6 variety: no-repeat within a run - events already shown this run are excluded
// until the whole catalog has been seen, then the seen-list resets. The tracker
// (global.events_seen_this_run) is reset per run in end_run().
function event_roll() {
    var _cat = event_catalog();
    var _n   = array_length(_cat);
    if (!variable_global_exists("events_seen_this_run")) global.events_seen_this_run = [];

    // Collect events not yet shown this run.
    var _avail = [];
    for (var _i = 0; _i < _n; _i++) {
        var _seen = false;
        for (var _j = 0; _j < array_length(global.events_seen_this_run); _j++) {
            if (global.events_seen_this_run[_j] == _cat[_i].id) { _seen = true; break; }
        }
        if (!_seen) array_push(_avail, _cat[_i]);
    }
    // Exhausted the catalog this run - refresh so events can repeat (still shuffled).
    if (array_length(_avail) == 0) {
        global.events_seen_this_run = [];
        _avail = _cat;
    }

    var _chosen = _avail[irandom(array_length(_avail) - 1)];
    array_push(global.events_seen_this_run, _chosen.id);
    return _chosen;
}

// The event catalog (13 events: 7 v1 + 6 §6 variety). Magnitudes scale by floor _fl (0..2).
function event_catalog() {
    var _fl = clamp(global.current_floor - 1, 0, 2);
    var _cat = [];

    // --- 1. Trapped Corridor (the reframed trap) ---------------------------
    var _tc_gold = [25, 40, 65];
    var _tc_fail = [14, 18, 24];
    var _tc_frc  = [8, 11, 15];
    array_push(_cat, {
        id: "trapped_corridor",
        title: "Trapped Corridor",
        body: "Floor plates click beneath the dust. A mechanism is primed somewhere in the dark.",
        color: make_color_rgb(180, 90, 210),
        choices: [
            { label: "Disarm the mechanism", hint: "DEX check - success: loot - failure: you take the hit",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "DEX", check_base: 55, check_per: 6, check_ref: 5,
              success: { text: "Steady hands. The trap goes slack and you pocket the bait.",
                         effects: { gold: _tc_gold[_fl], consumable: "standard" } },
              fail:    { text: "A wire snaps - darts hiss out of the wall.",
                         effects: { hp: -_tc_fail[_fl] } } },
            { label: "Force through", hint: "Take a guaranteed hit, grab the loot anyway",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You barrel through the spikes and snatch what's stashed here.",
                            effects: { hp: -_tc_frc[_fl], item: "chest" } } ] },
            { label: "Retreat", hint: "Leave it untouched - no risk, no reward",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You back out the way you came.", effects: {} } ] }
        ]
    });

    // --- 2. Mysterious Font ------------------------------------------------
    var _mf_heal = [20, 26, 34];
    var _mf_pois = [12, 16, 22];
    array_push(_cat, {
        id: "mysterious_font",
        title: "Mysterious Font",
        body: "A basin of dark water glimmers in the gloom. It smells of iron and old magic.",
        color: make_color_rgb(110, 200, 205),
        choices: [
            { label: "Drink deeply", hint: "CON check - restore HP, or be poisoned",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "CON", check_base: 50, check_per: 7, check_ref: 5,
              success: { text: "The water is cool and clean. Vitality floods back.",
                         effects: { hp: _mf_heal[_fl] } },
              fail:    { text: "It's fouled - your gut twists as it goes down.",
                         effects: { hp: -_mf_pois[_fl] } } },
            { label: "Fill a vial", hint: "Bottle some to carry out",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You decant the strange water for later.",
                            effects: { consumable: "standard" } } ] },
            { label: "Leave it", hint: "Some thirsts are best ignored",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You move on, parched but unharmed.", effects: {} } ] }
        ]
    });

    // --- 3. Wounded Wanderer (HP cost baked into both Tend outcomes) --------
    var _ww_gold = [30, 50, 80];
    var _ww_dust = [3, 4, 6];
    var _ww_cost = [10, 12, 16];
    var _ww_rob  = [45, 70, 110];
    array_push(_cat, {
        id: "wounded_wanderer",
        title: "Wounded Wanderer",
        body: "A ragged figure slumps against the wall, clutching a wound and a heavy satchel.",
        color: make_color_rgb(90, 200, 120),
        choices: [
            { label: "Tend their wounds", hint: "Spend some of your own vigor - they may repay you well",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [
                { weight: 70, text: "They recover, and press coin and dust into your hands.",
                  effects: { hp: -_ww_cost[_fl], gold: _ww_gold[_fl], dust: _ww_dust[_fl] } },
                { weight: 30, text: "They were no mere wanderer - a fragment of power passes to you.",
                  effects: { hp: -_ww_cost[_fl], boon: "random" } } ] },
            { label: "Rob them", hint: "Take the satchel and go",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You pry the satchel loose and leave them to the dark.",
                            effects: { gold: _ww_rob[_fl] } } ] },
            { label: "Walk on", hint: "Not your problem",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You step past without a word.", effects: {} } ] }
        ]
    });

    // --- 4. Gambler's Cache ------------------------------------------------
    var _gc_cost = [40, 60, 90];
    var _gc_fail = [12, 16, 22];
    array_push(_cat, {
        id: "gamblers_cache",
        title: "Gambler's Cache",
        body: "A locked strongbox sits on a pedestal, its mechanism crusted with old wax seals.",
        color: make_color_rgb(225, 195, 70),
        choices: [
            { label: "Pay to open", hint: "Buy the key from the slot - gamble on what's inside",
              cost_gold: _gc_cost[_fl], req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [
                { weight: 55, text: "The lock clicks. Decent gear inside.", effects: { item: "vault" } },
                { weight: 30, text: "A modest haul.",                        effects: { item: "chest" } },
                { weight: 12, text: "Jackpot - a relic of real worth!",      effects: { item: "reliquary" } },
                { weight: 3,  text: "Bound to the box was a lingering blessing.", effects: { boon: "random" } } ] },
            { label: "Pry it open", hint: "STR check - force the lid, or get bitten",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "STR", check_base: 45, check_per: 6, check_ref: 6,
              success: { text: "The lid splinters. You grab what's inside.", effects: { item: "chest" } },
              fail:    { text: "The lid snaps shut on your hand - and stays locked.",
                         effects: { hp: -_gc_fail[_fl] } } },
            { label: "Leave it", hint: "Walk away from the bet",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You leave the cache to the next fool.", effects: {} } ] }
        ]
    });

    // --- 5. Cursed Idol ----------------------------------------------------
    var _ci_gold = [50, 80, 120];
    var _ci_dmg  = [16, 22, 30];
    var _ci_dust = [5, 7, 10];
    array_push(_cat, {
        id: "cursed_idol",
        title: "Cursed Idol",
        body: "A squat idol leers from an alcove, a heap of offerings glittering at its feet.",
        color: make_color_rgb(210, 80, 80),
        choices: [
            { label: "Take the offering", hint: "Grab the gold and gear - if the idol allows it",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [
                { weight: 65, text: "You scoop up the hoard. The idol stays dark.",
                  effects: { gold: _ci_gold[_fl], item: "chest" } },
                { weight: 35, text: "The idol's eyes flare - power lashes out at you!",
                  effects: { hp: -_ci_dmg[_fl] } } ] },
            { label: "Pray before it", hint: "WIS check - earn its favor",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "WIS", check_base: 50, check_per: 7, check_ref: 5,
              success: { text: "The idol warms to your devotion.",
                         effects: { dust: _ci_dust[_fl], boon: "random" } },
              fail:    { text: "The idol is silent. You feel faintly foolish.", effects: {} } },
            { label: "Leave it", hint: "Don't tempt it",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You leave the idol and its bargains behind.", effects: {} } ] }
        ]
    });

    // --- 6. Merchant's Ghost (cha_cost choices get the CHA discount) --------
    var _mg_cost = [35, 55, 85];
    var _mg_dmg  = [6, 8, 10];
    array_push(_cat, {
        id: "merchants_ghost",
        title: "Merchant's Ghost",
        body: "A translucent peddler tips a spectral hat, wares shimmering on a phantom cart.",
        color: make_color_rgb(100, 160, 230),
        choices: [
            { label: "Haggle & buy", hint: "Pay for a piece of gear (CHA lowers the price)",
              cost_gold: _mg_cost[_fl], cha_cost: true, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "Coin changes hands. The gear is solid.",
                            effects: { item: "vault" } } ] },
            { label: "Intimidate", hint: "STR check - take the goods for free, or be lashed",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "STR", check_base: 40, check_per: 6, check_ref: 6,
              success: { text: "The ghost flinches and lets you take a piece - free.",
                         effects: { item: "vault" } },
              fail:    { text: "The ghost recoils, then lashes out with spectral cold.",
                         effects: { hp: -_mg_dmg[_fl] } } },
            { label: "Decline", hint: "Wave the peddler off",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "The cart fades back into the gloom.", effects: {} } ] }
        ]
    });

    // --- 7. Forked Omen ----------------------------------------------------
    var _fo_gold = [60, 90, 140];
    var _fo_dust = [4, 6, 9];
    var _fo_heal = [18, 24, 30];
    array_push(_cat, {
        id: "forked_omen",
        title: "Forked Omen",
        body: "Three paths split before you, each marked by a different sign scratched in soot.",
        color: make_color_rgb(150, 130, 230),
        choices: [
            { label: "Take the gold", hint: "The pragmatic road - coin in hand",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "The path ends at a forgotten purse.",
                            effects: { gold: _fo_gold[_fl] } } ] },
            { label: "Take the blessing", hint: "Chase the lucky sign - dust, a draught, maybe more",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [
                { weight: 80, text: "The sign rewards you with dust and a fine draught.",
                  effects: { dust: _fo_dust[_fl], consumable: "elite" } },
                { weight: 20, text: "The omen was true - a lasting blessing settles on you.",
                  effects: { boon: "random" } } ] },
            { label: "Heed the warning", hint: "Steel yourself before the next fight",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You rest behind cover, mending for what's ahead.",
                            effects: { hp: _fo_heal[_fl] } } ] }
        ]
    });

    // --- 8. Arcane Locus (INT check -> dust + rune) -------------------------
    var _al_dust = [4, 6, 9];
    var _al_fail = [12, 16, 22];
    array_push(_cat, {
        id: "arcane_locus",
        title: "Arcane Locus",
        body: "Veins of light crawl across a cracked sigil-stone, humming with unspent power.",
        color: make_color_rgb(150, 110, 235),
        choices: [
            { label: "Study the glyphs", hint: "INT check - decode the sigil for dust and a rune",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "INT", check_base: 50, check_per: 7, check_ref: 5,
              success: { text: "The pattern resolves. Power bleeds into your reserves.",
                         effects: { dust: _al_dust[_fl], rune: 1 } },
              fail:    { text: "The sigil flares and recoils, scorching you.",
                         effects: { hp: -_al_fail[_fl] } } },
            { label: "Channel raw power", hint: "Grab what you can - no finesse",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [
                { weight: 60, text: "Force yields a cache of gear.", effects: { item: "vault" } },
                { weight: 30, text: "The energy slips through your fingers.", effects: {} },
                { weight: 10, text: "A fragment of the sigil bonds to you.", effects: { boon: "random" } } ] },
            { label: "Leave it", hint: "Some power isn't worth the risk",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You let the locus hum on, untouched.", effects: {} } ] }
        ]
    });

    // --- 9. Collapsed Shrine (STR hard-gate + DEX check) -------------------
    var _cs_gold = [30, 50, 80];
    var _cs_dust = [4, 5, 7];
    var _cs_fail = [12, 16, 22];
    array_push(_cat, {
        id: "collapsed_shrine",
        title: "Collapsed Shrine",
        body: "A holy place, caved in long ago. Something glints beneath the fallen masonry.",
        color: make_color_rgb(170, 165, 150),
        choices: [
            { label: "Heave the rubble aside", hint: "Requires STR 8 - muscle the stone off the cache",
              cost_gold: 0, req_stat: "STR", req_amount: 8, resolve: "weighted",
              outcomes: [ { weight: 100, text: "Stone grinds aside. A reliquary lies beneath.",
                            effects: { item: "vault", gold: _cs_gold[_fl] } } ] },
            { label: "Squeeze through the gap", hint: "DEX check - slip in for supplies, or get pinned",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "DEX", check_base: 50, check_per: 6, check_ref: 5,
              success: { text: "You wriggle through and back out with arms full.",
                         effects: { consumable: "elite", dust: _cs_dust[_fl] } },
              fail:    { text: "A slab shifts and crushes down on you.",
                         effects: { hp: -_cs_fail[_fl] } } },
            { label: "Move on", hint: "Leave the dead their rest",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You leave the shrine to its silence.", effects: {} } ] }
        ]
    });

    // --- 10. Vagrant Oracle (CHA check + CHA-priced buy) -------------------
    var _vo_gold = [35, 55, 90];
    var _vo_dust = [3, 5, 7];
    array_push(_cat, {
        id: "vagrant_oracle",
        title: "Vagrant Oracle",
        body: "A blind seer rattles a cup of bones and beckons you closer with a crooked grin.",
        color: make_color_rgb(120, 170, 210),
        choices: [
            { label: "Charm a fortune from them", hint: "CHA check - sweet-talk a generous reading",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "CHA", check_base: 45, check_per: 6, check_ref: 5,
              success: { text: "Flattered, the oracle presses coin and dust on you.",
                         effects: { gold: _vo_gold[_fl], dust: _vo_dust[_fl] } },
              fail:    { text: "They scowl and turn the bones away.", effects: {} } },
            { label: "Cross their palm", hint: "Pay for a true reading (CHA lowers the price)",
              cost_gold: _vo_gold[_fl], cha_cost: true, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [
                { weight: 75, text: "The bones speak - and a fine draught is yours.",
                  effects: { consumable: "elite" } },
                { weight: 25, text: "A genuine omen settles over you.", effects: { boon: "random" } } ] },
            { label: "Walk past", hint: "You make your own fate",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "The bones rattle at your back.", effects: {} } ] }
        ]
    });

    // --- 11. Runed Anvil (STR / INT checks -> runes) -----------------------
    var _ra_fail = [10, 14, 18];
    var _ra_dust = [3, 4, 6];
    array_push(_cat, {
        id: "runed_anvil",
        title: "Runed Anvil",
        body: "A black anvil sits cold in the dark, its face crawling with half-formed runes.",
        color: make_color_rgb(210, 140, 70),
        choices: [
            { label: "Strike the anvil", hint: "STR check - hammer a potent rune loose",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "STR", check_base: 48, check_per: 6, check_ref: 6,
              success: { text: "The rune rings free, potent and whole.", effects: { rune: 2 } },
              fail:    { text: "The anvil rings back - the recoil bruises you.",
                         effects: { hp: -_ra_fail[_fl], dust: _ra_dust[_fl] } } },
            { label: "Read the runes", hint: "INT check - coax out a lesser rune and dust",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "INT", check_base: 52, check_per: 7, check_ref: 5,
              success: { text: "You trace the pattern and draw out its power.",
                         effects: { rune: 1, dust: _ra_dust[_fl] } },
              fail:    { text: "The runes blur and refuse to settle.", effects: {} } },
            { label: "Leave it cold", hint: "No spark, no risk",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You leave the anvil to the dark.", effects: {} } ] }
        ]
    });

    // --- 12. Starving Hound -----------------------------------------------
    var _sh_gold = [25, 40, 65];
    var _sh_bite = [10, 14, 20];
    array_push(_cat, {
        id: "starving_hound",
        title: "Starving Hound",
        body: "A gaunt hound watches from the shadows, ribs sharp, eyes wary but not yet hostile.",
        color: make_color_rgb(150, 130, 90),
        choices: [
            { label: "Feed it", hint: "Win it over - it may lead you somewhere",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [
                { weight: 65, text: "It trots ahead and noses out a hidden stash.",
                  effects: { gold: _sh_gold[_fl], item: "chest" } },
                { weight: 35, text: "It snatches the food and snaps at you.",
                  effects: { hp: -_sh_bite[_fl] } } ] },
            { label: "Hunt it", hint: "STR check - run it down for rations and coin",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "STR", check_base: 50, check_per: 6, check_ref: 6,
              success: { text: "You corner the beast - rations and a dropped purse.",
                         effects: { consumable: "standard", gold: _sh_gold[_fl] } },
              fail:    { text: "It's faster than it looks, and bites on the way past.",
                         effects: { hp: -_sh_bite[_fl] } } },
            { label: "Drive it off", hint: "Wave it away - no fuss",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "It slinks back into the dark.", effects: {} } ] }
        ]
    });

    // --- 13. Whispering Mirror (WIS check -> boon) -------------------------
    var _wm_gold = [20, 35, 55];
    var _wm_dust = [3, 5, 8];
    var _wm_fail = [12, 16, 22];
    array_push(_cat, {
        id: "whispering_mirror",
        title: "Whispering Mirror",
        body: "A tall mirror hangs unbroken in the ruin, its surface fogged with restless whispers.",
        color: make_color_rgb(190, 200, 210),
        choices: [
            { label: "Gaze into it", hint: "WIS check - meet the visions for a blessing",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "WIS", check_base: 48, check_per: 7, check_ref: 5,
              success: { text: "You hold the gaze, and something lends you its strength.",
                         effects: { boon: "random" } },
              fail:    { text: "The visions claw at you before you tear away.",
                         effects: { hp: -_wm_fail[_fl] } } },
            { label: "Smash it", hint: "Shatter it for the enchanted shards",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "Glass rains down - the shards hum with dust and coin.",
                            effects: { dust: _wm_dust[_fl], gold: _wm_gold[_fl] } } ] },
            { label: "Cover it", hint: "Drape it and leave the whispers behind",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You shroud the glass and move on.", effects: {} } ] }
        ]
    });

    return _cat;
}

// =============================================================================
// AUDIO / SOUND SETTINGS
// Two player-controlled volume categories: Music and SFX. There are no audio
// groups assigned in the IDE (those need .yy edits), so volume is applied per
// sound ASSET via audio_sound_gain - in GMS2 the asset's gain persists to
// future instances, so setting it once covers later plays of that sound.
// Volumes are 0..1, persisted in settings.ini (global, independent of save slots).
// Settings overlay is drawn by ui_draw_settings_overlay (scr_ui), driven title + hub.
// =============================================================================

// Looping tracks / ambience - controlled by the Music slider.
// IMPORTANT: only list sound assets that are actually played somewhere via
// audio_play_sound. Referencing a placeholder/empty sound resource (one with a
// .yy but no source audio, e.g. "Sounds") makes the build fail to convert it.
function audio_music_assets() {
    return [
        Viking_March, Rainy_Memories, MusicBox1, Game_Over,
        _2_dungeon_INITIAL, _2_dungeon_LOOP, _3_critical_LOOP,
        _14_BOSS_y_LOOP, _15_game_over_INITIAL,
    ];
}

// One-shot effects / UI stings - controlled by the SFX slider. (Only sounds
// that are actually played - see the note on audio_music_assets above.)
function audio_sfx_assets() {
    return [
        utility2, Check_1, Chimes__Ascending_, Success_2,
        spell1, Magic, attack1, grunt, teleport, die5, hurt,
    ];
}

// Ensure the volume globals + settings-overlay state exist (defaults on first boot),
// then load any saved values from settings.ini once per session. Settings live in a
// small ini independent of the per-slot save, so they persist even from the title.
function audio_settings_init() {
    if (!variable_global_exists("music_volume")) global.music_volume = 0.7;
    if (!variable_global_exists("sfx_volume"))   global.sfx_volume   = 0.8;
    if (!variable_global_exists("settings_open"))        global.settings_open        = false;
    if (!variable_global_exists("settings_cursor"))      global.settings_cursor      = 0;   // 0 Music, 1 SFX, 2 Fullscreen, 3 Tutorial, 4 Reset
    if (!variable_global_exists("settings_reset_flash")) global.settings_reset_flash = 0;
    if (!variable_global_exists("tutorial_enabled"))     global.tutorial_enabled     = true;

    if (!variable_global_exists("settings_loaded")) {
        global.settings_loaded = true;
        ini_open("settings.ini");
        global.music_volume     = clamp(ini_read_real("audio", "music", global.music_volume), 0, 1);
        global.sfx_volume       = clamp(ini_read_real("audio", "sfx",   global.sfx_volume),   0, 1);
        // Tutorial-tips preference lives here too so it persists from the title
        // (where no save slot is loaded). 1 = enabled (default), 0 = disabled.
        global.tutorial_enabled = (ini_read_real("ui", "tutorial_tips", 1) >= 0.5);
        ini_close();
    }
}

// Persist the current volumes to settings.ini.
function audio_settings_save() {
    ini_open("settings.ini");
    ini_write_real("audio", "music", global.music_volume);
    ini_write_real("audio", "sfx",   global.sfx_volume);
    ini_write_real("ui", "tutorial_tips",
        ((!variable_global_exists("tutorial_enabled")) || global.tutorial_enabled) ? 1 : 0);
    ini_close();
}

// Push the current volumes onto every categorized sound asset.
function audio_apply_volumes() {
    audio_settings_init();
    var _mv = clamp(global.music_volume, 0, 1);
    var _sv = clamp(global.sfx_volume,   0, 1);
    var _music = audio_music_assets();
    for (var _i = 0; _i < array_length(_music); _i++) audio_sound_gain(_music[_i], _mv, 0);
    var _sfx = audio_sfx_assets();
    for (var _i = 0; _i < array_length(_sfx); _i++) audio_sound_gain(_sfx[_i], _sv, 0);
}

// Adjust one category by delta (e.g. ±0.05), clamp, and re-apply immediately.
function audio_settings_adjust(which, delta) {
    audio_settings_init();
    if (which == 0) global.music_volume = clamp(global.music_volume + delta, 0, 1);
    else            global.sfx_volume   = clamp(global.sfx_volume   + delta, 0, 1);
    audio_apply_volumes();
}

// Shared input handler for the settings overlay. Call from a controller's Step
// while global.settings_open; returns true (so the caller can `exit` and block
// its own input). W/S pick a row, A/D or <-/-> adjust sliders / toggle fullscreen,
// Esc/O closes. Rows: 0 Music, 1 SFX, 2 Fullscreen, 3 Tutorial Tips, 4 Reset Tutorial.
function audio_settings_handle_input() {
    audio_settings_init();
    video_settings_init();

    // Tick down the "tutorial reset" confirmation flash (drawn by the overlay).
    if (variable_global_exists("settings_reset_flash") && global.settings_reset_flash > 0) {
        global.settings_reset_flash--;
    }

    // Rows: 0 Music, 1 SFX, 2 Fullscreen, 3 Tutorial Tips, 4 Reset Tutorial.
    if (nav_up())   global.settings_cursor = wrap_index(global.settings_cursor - 1, 5);
    if (nav_down()) global.settings_cursor = wrap_index(global.settings_cursor + 1, 5);
    global.settings_cursor = clamp(global.settings_cursor, 0, 4);

    var _left    = nav_left();
    var _right   = nav_right();
    var _confirm = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_return)
                || keyboard_check_pressed(vk_space);

    switch (global.settings_cursor) {
        case 0: // Music
            if (_left)  audio_settings_adjust(0, -0.05);
            if (_right) audio_settings_adjust(0,  0.05);
        break;
        case 1: // Sound Effects
            if (_left)  audio_settings_adjust(1, -0.05);
            if (_right) audio_settings_adjust(1,  0.05);
        break;
        case 2: // Fullscreen
            if (_left || _right || _confirm) video_toggle_fullscreen();
        break;
        case 3: // Tutorial Tips on/off
            if (_left || _right || _confirm) {
                if (!variable_global_exists("tutorial_enabled")) global.tutorial_enabled = true;
                global.tutorial_enabled = !global.tutorial_enabled;
                audio_settings_save();
            }
        break;
        case 4: // Reset Tutorial - clear seen flags so every tip shows again
            if (_left || _right || _confirm) {
                tutorial_reset_all();
                global.tutorial_enabled   = true;   // resetting implies you want the tips back
                global.settings_reset_flash = 120;
                audio_settings_save();
            }
        break;
    }

    // Esc / O always closes (Enter is reserved for the toggle/action rows above).
    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(ord("O"))) {
        global.settings_open = false;
        audio_settings_save();
    }
    return true;
}

// =============================================================================
// PAUSE / ESC MENU - Resume / Settings / Quit to Title. Available in the hub and
// during a run (floor map + combat). Input is handled here (shared); drawing is
// ui_draw_pause_menu() (scr_ui), called by each room controller. A controller
// opens it via pause_menu_open() on Esc when nothing else is open, and freezes
// itself by calling pause_menu_step() at the top of its Step (exit when true).
// =============================================================================
function pause_menu_open() {
    global.pause_open   = true;
    global.pause_cursor = 0;
}

// Returns true while the pause menu (or its Settings sub-screen) is capturing
// input, so the calling controller can `exit` and freeze the screen beneath it.
function pause_menu_step() {
    if (!variable_global_exists("pause_open"))   global.pause_open   = false;
    if (!variable_global_exists("pause_cursor")) global.pause_cursor = 0;

    // Settings sub-screen (opened from the pause menu) takes priority while open;
    // when it closes (Esc/O) we fall back to the pause menu, still open underneath.
    if (variable_global_exists("settings_open") && global.settings_open) {
        audio_settings_handle_input();
        return true;
    }

    if (!global.pause_open) return false;

    var _opt_count = 3;   // 0 Resume, 1 Settings, 2 Quit to Title
    if (nav_up())   global.pause_cursor--;
    if (nav_down()) global.pause_cursor++;
    global.pause_cursor = ((global.pause_cursor mod _opt_count) + _opt_count) mod _opt_count;

    // Mouse hover selects a row (geometry MUST match ui_draw_pause_menu).
    var _pmx = device_mouse_x_to_gui(0);
    var _pmy = device_mouse_y_to_gui(0);
    var _row_h = 84, _first_y = 468, _bx0 = 735, _bx1 = 1185;
    var _hover = -1;
    for (var _r = 0; _r < _opt_count; _r++) {
        var _ry = _first_y + _r * _row_h;
        if (_pmx >= _bx0 && _pmx <= _bx1 && _pmy >= _ry && _pmy <= _ry + 66) _hover = _r;
    }
    if (_hover != -1) global.pause_cursor = _hover;

    // Esc / Backspace resumes.
    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
        global.pause_open = false;
        return true;
    }

    var _confirm = keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
                 || keyboard_check_pressed(vk_space) || (mouse_check_button_pressed(mb_left) && _hover != -1);
    if (_confirm) {
        switch (global.pause_cursor) {
            case 0:  // Resume
                global.pause_open = false;
                break;
            case 1:  // Settings - opens over the pause menu, returns here on close
                audio_settings_init();
                global.settings_cursor = 0;
                global.settings_open   = true;
                break;
            case 2:  // Quit to Title
                global.pause_open = false;
                pause_quit_to_title();
                break;
        }
    }
    return true;
}

// Drop any open persistent-controller overlays and return to the title screen.
// Saves only from the hub (meta-progression is already banked there); a run in
// progress is simply abandoned, exactly like closing the game mid-run.
function pause_quit_to_title() {
    if (room == rm_hub && variable_global_exists("save_slot") && global.save_slot >= 0) {
        save_game();
    }

    if (instance_exists(obj_game_controller)) {
        var _gc = instance_find(obj_game_controller, 0);
        _gc.menu_open       = false;
        _gc.stash_mode_open = false;
        if (variable_instance_exists(_gc, "loadout_open"))        _gc.loadout_open        = false;
        if (variable_instance_exists(_gc, "trainer_open"))        _gc.trainer_open        = false;
        if (variable_instance_exists(_gc, "vael_open"))           _gc.vael_open           = false;
        if (variable_instance_exists(_gc, "sable_open"))          _gc.sable_open          = false;
        if (variable_instance_exists(_gc, "maren_open"))          _gc.maren_open          = false;
        if (variable_instance_exists(_gc, "level_alloc_open"))    _gc.level_alloc_open    = false;
        if (variable_instance_exists(_gc, "dungeon_select_open")) _gc.dungeon_select_open = false;
        if (variable_instance_exists(_gc, "shop_open"))           _gc.shop_open           = -1;
    }
    global.pause_open = false;
    if (variable_global_exists("settings_open")) global.settings_open = false;

    // Stop hub/dungeon music so it doesn't overlap the title theme (re-started in
    // obj_title_controller Create).
    audio_stop_all();
    room_goto(rm_title);
}

// =============================================================================
// VIDEO SETTINGS - fullscreen toggle, persisted in settings.ini ([video] section).
// Independent of save slots, like the audio settings. The GUI layer is locked at a
// native 1920x1080 (display_set_gui_size; SYSTEMS_RESOLUTION.md), mapped 1:1 to a
// 1080p display in fullscreen; all draw code uses 1920x1080 (GUI_W/GUI_H) coordinates.
// =============================================================================
function video_settings_init() {
    if (!variable_global_exists("fullscreen")) global.fullscreen = false;

    if (!variable_global_exists("video_loaded")) {
        global.video_loaded = true;
        ini_open("settings.ini");
        global.fullscreen = (ini_read_real("video", "fullscreen", 0) >= 0.5);
        ini_close();
    }
}

// Push the current fullscreen flag onto the actual window. When windowed, AUTO-FIT
// the window to native 1920x1080 (GUI_W/GUI_H), clamped down only when the physical
// display is smaller (sub-1080p monitors), then centered. On >=1080p displays this
// is true native density; on smaller ones GameMaker scales the GUI down to the window.
function video_apply() {
    video_settings_init();

    // HTML5 / itch.io: match the canvas to the ACTUAL browser / itch frame size so it
    // always fills it. GameMaker's "Keep aspect ratio" HTML5 scaling does NOT reliably
    // upscale a fixed canvas to a larger frame (a native 1920x1080 canvas just sat
    // top-left in a bigger fullscreen window), so we drive the size ourselves from
    // browser_width/height. The fixed 1920x1080 GUI layer (display_set_gui_size) is then
    // stretched by GM to fill the window. The frame size changes on fullscreen-launch /
    // window-resize, so obj_game_controller/Step_0 re-applies this every step too; this
    // call just avoids a one-frame flash at startup. Works in BOTH itch embed modes
    // (click-to-launch-fullscreen = whole window; embed-in-page = the inline viewport).
    if (os_browser != browser_not_a_browser) {
        window_set_fullscreen(global.fullscreen);
        var _bw = browser_width;
        var _bh = browser_height;
        if (_bw > 0 && _bh > 0) window_set_size(_bw, _bh);
        return;
    }

    window_set_fullscreen(global.fullscreen);
    if (!global.fullscreen) {
        var _win_w = min(GUI_W, display_get_width());
        var _win_h = min(GUI_H, display_get_height());
        window_set_size(_win_w, _win_h);
        window_center();
    }
}

// Flip fullscreen, persist it, and apply immediately. Safe to call from anywhere
// (F11 hotkey in the game controller, or the settings overlay).
function video_toggle_fullscreen() {
    video_settings_init();
    global.fullscreen = !global.fullscreen;
    ini_open("settings.ini");
    ini_write_real("video", "fullscreen", global.fullscreen ? 1 : 0);
    ini_close();
    video_apply();
}
