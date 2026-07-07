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

    // Petra's rotating PREMIUM pet feed: one of the premium pool, changes each run.
    var _feed_pool = pet_feed_premium_pool();
    global.petra_feed_premium = _feed_pool[irandom(array_length(_feed_pool) - 1)].id;

    // Dorn: stock scales with the HIGHEST awakening unlocked (permanent meta growth).
    // Items are fully rolled (affixes), so his gear stays relevant past floor 1.
    // do_discover=false - shop items are only codex-revealed when actually bought.
    global.dorn_stock = [];
    var _dorn_awk     = highest_awakening_unlocked();
    var _dorn_weights = drop_weights("dorn", _dorn_awk);
    var _dorn_count   = 3 + (_dorn_awk >= 2 ? 1 : 0) + (_dorn_awk >= 4 ? 1 : 0)
                      + (affinity_at_least("dorn", 3) ? 1 : 0);   // Companion perk: +1 stock slot
    var _dorn_disc    = affinity_discount_mult("dorn");           // Friend perk: 10% off (baked at restock)
    repeat (_dorn_count) {
        var _di     = drop_equipment(_dorn_weights, false);
        // Rare/Epic+ gear is a premium buy - roughly double the markup so a strong
        // piece is a real gold sink, not a cheap upgrade. (Task: Dorn rare/epic cost)
        var _dmarkup = (_di.rarity >= 2) ? 3.2 : 1.6;
        var _dprice  = max(1, floor(_di.gold_value * _dmarkup * _dorn_disc));
        array_push(global.dorn_stock, { item: _di, price: _dprice, sold: false });
    }
    // Dorn Lover perk (Master's Pick): he always holds back something Rare or better.
    if (affinity_at_least("dorn", 4)) {
        var _has_rare = false;
        for (var _ds = 0; _ds < array_length(global.dorn_stock); _ds++)
            if (global.dorn_stock[_ds].item.rarity >= 2) { _has_rare = true; break; }
        if (!_has_rare) {
            repeat (12) {   // bounded re-rolls; weights make rare+ likely well within this
                var _dp = drop_equipment(_dorn_weights, false);
                if (_dp.rarity >= 2) {
                    var _dpp = max(1, floor(_dp.gold_value * 3.2 * _dorn_disc));
                    global.dorn_stock[0] = { item: _dp, price: _dpp, sold: false };
                    break;
                }
            }
        }
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
    global.run_found_pets = [];   // run-scoped "creatures found" strip (equipment Found column)
    global.run_count++;
    global.last_run_result = result;
    global.last_run_gold   = global.current_run_gold;
    global.last_run_kills  = global.current_run_kills;

    // Tavern board requests (BOARD_REQUESTS_SPEC.md): score run-scoped proofs
    // (haul) BEFORE the expiry countdown, then age + refill the board.
    board_run_scoring(result);
    board_run_end();
    kb_tourney_run_end();   // High Table cadence (dice v2): every 5th completed run

    // Phase 2 pets: the ACTIVE pet banks Stage growth for completing this run and may
    // EVOLVE (completing a run is the gate feed alone can't open; clear > extract >
    // death). Surfaced on the next hub visit via the pet notice. (PETS_DESIGN.md §5)
    var _pet_evo = pet_run_complete(result);
    if (_pet_evo != undefined && variable_global_exists("pet_find_notice")) {
        var _evo_msg = _pet_evo.name + " grew into a " + pet_stage_name(_pet_evo.stage) + "!";
        global.pet_find_notice = (global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _evo_msg) : _evo_msg;
    }
    // A READY pet that was NOT the active companion banks nothing - say so on the
    // hub return instead of leaving the player wondering why nothing evolved.
    if (result >= 0 && variable_global_exists("pet_roster") && variable_global_exists("pet_find_notice")) {
        var _act_p = pet_active();
        for (var _rni = 0; _rni < array_length(global.pet_roster); _rni++) {
            var _rnp = global.pet_roster[_rni];
            if (_rnp.is_egg || _rnp == _act_p) continue;
            if (_rnp.stage < pet_max_stage() && pet_growth_ready(_rnp) && _rnp.stage != PET_STAGE_ADULT) {
                var _rn_msg = _rnp.name + " was ready to evolve but stayed behind - equip it as your companion (dungeon gate > Companion) and complete a run.";
                global.pet_find_notice = (global.pet_find_notice != "")
                    ? (global.pet_find_notice + "   " + _rn_msg) : _rn_msg;
                break;   // one reminder is enough
            }
        }
    }
    // Injury / permadeath / recovery for the carried pet (§8). Surfaced on hub return.
    var _pet_inj = pet_on_run_end(result);
    if (_pet_inj != "" && variable_global_exists("pet_find_notice")) {
        global.pet_find_notice = (global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _pet_inj) : _pet_inj;
    }
    // Corruption progress: a survived run feeds a pushed pet toward fulfillment (§7).
    var _pet_corr = pet_corruption_on_run_end(result);
    if (_pet_corr != "" && variable_global_exists("pet_find_notice")) {
        global.pet_find_notice = (global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _pet_corr) : _pet_corr;
    }

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
                // Bonus gold reward scales with ascendance tier (table shared with
                // the dungeon-select AWAKENING EFFECTS panel via awaken_clear_gold_bonus)
                add_gold(awaken_clear_gold_bonus(global.selected_ascendance));
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
        dungeon:            (variable_global_exists("selected_dungeon") ? global.selected_dungeon : ""),
        perm_points_earned: _perm_earned,
        items_found:        []
    };
    if (variable_global_exists("run_history")) {
        array_push(global.run_history, _run_record);
    }

    global.current_run_gold    = 0;
    global.current_run_kills   = 0;
    global.run_current_hp      = 0;
    global.run_borrowed_ability = "";   // Borrowed Memory is run-scoped (expression #6)
    global.run_borrowed_class   = "";
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
    global.pending_fire_stacks = 0;    // dungeon floor passives don't carry across runs
    global.pending_ap_penalty  = 0;
    potion_buffs_clear();              // Goldfinger / Faerie's Tear end with the run (incl. death)
    affinity_reset_run_gain();         // clear the per-run affinity grind cap (NOT score/tier)
    // Phase 4a affinity perks that recharge per run:
    global.sable_free_brew   = affinity_at_least("sable", 4);   // Lover: first brew after a run is free
    global.bairc_mend_pending = affinity_at_least("bairc", 3);  // Companion: he mends 1 injury tier at the hub
    // Phase 4b gifts: the one-per-run latch resets; trinkets found this run are
    // EXTRACTION-GATED - a survived run banks them, death loses them (M 2026-07-03).
    global.gift_given = false;
    var _rtk = run_trinkets();
    if (array_length(_rtk) > 0) {
        if (result >= 0) {
            for (var _rt = 0; _rt < array_length(_rtk); _rt++) array_push(gift_trinkets(), _rtk[_rt]);
        } else if (variable_global_exists("pet_find_notice")) {
            var _tk0 = gift_trinket_get(_rtk[0]);
            var _tk_msg = "The " + ((_tk0 != undefined) ? _tk0.name : "gift") + " was lost with you.";
            global.pet_find_notice = (global.pet_find_notice != "")
                ? (global.pet_find_notice + "   " + _tk_msg) : _tk_msg;
        }
        global.run_trinkets = [];
    }

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

// Chance (0..1) for the affix to apply its setup status on a qualifying hit. (Task 12)
// Previously the status landed on EVERY weapon hit, which made an uncommon weapon's
// rider out-value some abilities (a guaranteed DoT each swing). It is now a modest,
// rarity-scaled PROC; the flat elemental damage above still applies on every hit.
function elem_affix_status_chance(rarity) {
    switch (rarity) {
        case 1: return 0.10;   // Uncommon
        case 2: return 0.15;   // Rare
        case 3: return 0.20;   // Epic
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
        element:       _element,
        dmg:           elem_affix_damage(rarity),
        status_kind:   _fam.status_kind,
        status_value:  _fam.status_value,
        status_dur:    _fam.status_dur,
        status_chance: elem_affix_status_chance(rarity),
        prefix:        _fam.prefix,
        suffix:        _fam.suffix,
    };
}

// make_elem_affix(element, rarity) - build a specific elemental affix (for
// hand-authored demo/loot weapons rather than a random roll).
function make_elem_affix(element, rarity) {
    var _fam = elem_affix_family(element);
    if (_fam == undefined) return undefined;
    return {
        element:       element,
        dmg:           elem_affix_damage(rarity),
        status_kind:   _fam.status_kind,
        status_value:  _fam.status_value,
        status_dur:    _fam.status_dur,
        status_chance: elem_affix_status_chance(rarity),
        prefix:        _fam.prefix,
        suffix:        _fam.suffix,
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
        element:       _e.element,
        dmg:           _e.dmg,
        status_kind:   _e.status_kind,
        status_value:  _e.status_value,
        status_dur:    _e.status_dur,
        status_chance: variable_struct_exists(_e, "status_chance") ? _e.status_chance : 0.10,
        prefix:        _e.prefix,
        suffix:        _e.suffix,
    };
}

// elem_affix_describe(elem, slot) - one-line tooltip/codex text for an elemental
// affix. The flat damage is a WEAPON-attack rider (not a spell-damage bonus) that
// fires on hits of the weapon's own reach class; the setup status is a chance proc.
// `slot` ("weapon"/"ranged_weapon") names the reach so the text reads clearly. (Task 12)
function elem_affix_describe(elem, slot = "") {
    if (elem == undefined) return "";
    var _reach = (slot == "ranged_weapon") ? "ranged" : ((slot == "weapon") ? "melee" : "weapon");
    var _chance = variable_struct_exists(elem, "status_chance") ? elem.status_chance : 0.10;
    var _pct    = string(round(_chance * 100));
    var _dur    = string(elem.status_dur);
    var _st = "";
    switch (elem.status_kind) {
        case "dot":        _st = _pct + "% chance to apply Burn (" + string(elem.status_value) + " dmg/turn, " + _dur + "t)"; break;
        case "weaken":     _st = _pct + "% chance to Chill (foe -" + string(round(elem.status_value * 100)) + "% dmg, " + _dur + "t)"; break;
        case "vulnerable": _st = _pct + "% chance to Shock (foe +" + string(elem.status_value) + " dmg/hit, " + _dur + "t)"; break;
    }
    return "+" + string(elem.dmg) + " " + school_label(elem_element_name(elem.element)) + " dmg on " + _reach + " hit. (" + _st + ")";
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
    // Sable's exotic find-buff potions apply out of combat too (drink between floors).
    if (_et == "gold_find_pot") { potion_drink_gold(item.effect_value);  return true; }
    if (_et == "loot_find_pot") { potion_drink_loot(item.effect_value);  return true; }
    return false;
}

// ---------------------------------------------------------------------------
// EXOTIC FIND-BUFF POTIONS (Sable) - Goldfinger Elixir (+gold drops) & Faerie's
// Tear (+loot drop chance). Their effect lasts until 2 BOSSES are slain (~2 floors),
// NOT a whole run, so high-difficulty players must bring another to cover floor 3+.
// Not stackable (drinking just refreshes the 2-boss window + magnitude); cleared on
// death and run-end. Counters decrement in floor_clear_credit (one per boss-clear).
// ---------------------------------------------------------------------------
function potion_drink_gold(pct_points) {
    global.gold_potion_bosses = 2;                 // refresh window (not stackable)
    global.gold_potion_mult   = pct_points / 100;  // e.g. 7 -> 0.07
}
function potion_drink_loot(pct_points) {
    global.loot_potion_bosses = 2;
    global.loot_potion_pts    = pct_points;        // added to drop-% thresholds (e.g. +8)
}
// Gold-drop multiplier from the Goldfinger Elixir (1.0 = inactive).
function potion_gold_mult() {
    return (variable_global_exists("gold_potion_bosses") && global.gold_potion_bosses > 0)
        ? (1 + global.gold_potion_mult) : 1;
}
// Extra equipment-drop chance (percentage points) from Faerie's Tear (0 = inactive).
function potion_loot_bonus_pts() {
    return (variable_global_exists("loot_potion_bosses") && global.loot_potion_bosses > 0)
        ? global.loot_potion_pts : 0;
}
// Tick on each boss-clear (called from floor_clear_credit).
function potion_buffs_on_boss_clear() {
    if (variable_global_exists("gold_potion_bosses") && global.gold_potion_bosses > 0) global.gold_potion_bosses -= 1;
    if (variable_global_exists("loot_potion_bosses") && global.loot_potion_bosses > 0) global.loot_potion_bosses -= 1;
}
// Clear both buffs (run-end / death / load).
function potion_buffs_clear() {
    global.gold_potion_bosses = 0;
    global.loot_potion_bosses = 0;
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
// The tick respects the Settings "Menu Tick" toggle (global.ui_tick_enabled).
function nav_tick() {
    if (!variable_global_exists("ui_tick_enabled") || global.ui_tick_enabled) play_sfx_var("snd_ui_move", -1);
}
function nav_up()    { var _a = key_nav(vk_up);    var _b = key_nav(ord("W")); if (_a || _b) nav_tick(); return _a || _b; }
function nav_down()  { var _a = key_nav(vk_down);  var _b = key_nav(ord("S")); if (_a || _b) nav_tick(); return _a || _b; }
function nav_left()  { var _a = key_nav(vk_left);  var _b = key_nav(ord("A")); if (_a || _b) nav_tick(); return _a || _b; }
function nav_right() { var _a = key_nav(vk_right); var _b = key_nav(ord("D")); if (_a || _b) nav_tick(); return _a || _b; }

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
// equip_found_list(sort_mode) - the player's PACK (carried_items) as a browsable list
// for the Equipment tab's right-hand "found items" column. Returns [{item, idx}] where
// idx is the index into global.carried_items (rebuilt each frame, so it survives equips).
// sort_mode 0 = rarity (high->low, then name); 1 = type/slot (then rarity).
function equip_found_list(sort_mode) {
    var _out = [];
    // Hub-only: gear deposited to the equipment stash also appears here, so found items
    // that were auto-deposited on return stay browsable/equippable (matches the per-slot
    // picker, which pulls stash + pack). During a run only the carried pack exists.
    // Each entry tags its source so the equip action removes from the right array.
    var _in_hub = (room == rm_hub || room == rm_character_select);
    if (_in_hub && variable_global_exists("equipment_stash")) {
        for (var _s = 0; _s < array_length(global.equipment_stash); _s++) {
            array_push(_out, { item: global.equipment_stash[_s], idx: _s, src: 0 });   // 0 = stash
        }
    }
    if (variable_global_exists("carried_items")) {
        for (var _i = 0; _i < array_length(global.carried_items); _i++) {
            array_push(_out, { item: global.carried_items[_i], idx: _i, src: 1 });      // 1 = pack
        }
    }
    if (sort_mode == 1) {
        array_sort(_out, function(a, b) {
            var _as = variable_struct_exists(a.item, "slot") ? a.item.slot : "";
            var _bs = variable_struct_exists(b.item, "slot") ? b.item.slot : "";
            if (_as < _bs) return -1;
            if (_as > _bs) return 1;
            return b.item.rarity - a.item.rarity;
        });
    } else {
        array_sort(_out, function(a, b) {
            if (a.item.rarity != b.item.rarity) return b.item.rarity - a.item.rarity;
            if (a.item.name < b.item.name) return -1;
            if (a.item.name > b.item.name) return 1;
            return 0;
        });
    }
    return _out;
}

// equip_target_inv_for_slot(slot) - the inventory index an item of this slot type equips
// into. Rings prefer an OPEN ring position (7 then 9), else Ring 1. -1 = no valid slot.
function equip_target_inv_for_slot(slot) {
    switch (slot) {
        case "weapon":        return 0;
        case "offhand":       return 1;
        case "helm":          return 2;
        case "chest":         return 3;
        case "gloves":        return 4;
        case "boots":         return 5;
        case "amulet":        return 6;
        case "ranged_weapon": return 8;
        case "ring":
            if (variable_global_exists("inventory")) {
                if (global.inventory[7] == undefined) return 7;
                if (array_length(global.inventory) > 9 && global.inventory[9] == undefined) return 9;
            }
            return 7;
    }
    return -1;
}

function return_offhand_to_pack(in_hub) {
    if (!variable_global_exists("inventory")) return;
    if (array_length(global.inventory) <= 1) return;
    var _off = global.inventory[1];
    if (_off == undefined) return;
    global.inventory[1] = undefined;
    if (in_hub) array_push(global.equipment_stash, _off);
    else        array_push(global.carried_items, _off);
}

// Return any equipped inventory slot's item to the pack (stash in hub, carried mid-run).
function return_inv_slot_to_pack(idx, in_hub) {
    if (!variable_global_exists("inventory")) return;
    if (array_length(global.inventory) <= idx) return;
    var _it = global.inventory[idx];
    if (_it == undefined) return;
    global.inventory[idx] = undefined;
    if (in_hub) array_push(global.equipment_stash, _it);
    else        array_push(global.carried_items, _it);
}

// --- Caster two-hander (staff) special case (Task 10) -------------------------
// A staff (a 2H weapon tagged caster_2h, equipped in the RANGED slot 8) occupies
// both hands but still permits a focus/tome offhand - just NOT a shield - and forbids
// a melee weapon. Other 2H weapons (greatsword/longbow) fully lock the offhand as before.
function item_is_caster_2h(item) {
    if (item == undefined || !is_struct(item)) return false;
    return item_is_two_handed(item)
        && variable_struct_exists(item, "caster_2h") && item.caster_2h;
}

// True if the ranged slot (8) holds a caster 2H staff.
function caster_staff_equipped() {
    if (!variable_global_exists("inventory")) return false;
    return (array_length(global.inventory) > 8) && item_is_caster_2h(global.inventory[8]);
}

// True if a NON-caster 2H weapon (greatsword/longbow) is equipped - these still
// HARD-LOCK the offhand. The caster staff does not.
function hard_two_handed_equipped() {
    if (!variable_global_exists("inventory")) return false;
    var _len = array_length(global.inventory);
    if (_len > 0 && item_is_two_handed(global.inventory[0]) && !item_is_caster_2h(global.inventory[0])) return true;
    if (_len > 8 && item_is_two_handed(global.inventory[8]) && !item_is_caster_2h(global.inventory[8])) return true;
    return false;
}

// Is `item` a shield-type offhand? Shields are the defensive offhands (CON primary
// or carrying an armor affix); caster focuses / totems / orbs are not. A staff
// forbids shields but allows focuses.
function item_is_shield_offhand(item) {
    if (item == undefined || !is_struct(item)) return false;
    if (variable_struct_exists(item, "slot") && item.slot != "offhand") return false;
    if (variable_struct_exists(item, "offhand_kind")) return item.offhand_kind == "shield";
    if (variable_struct_exists(item, "stat_name") && item.stat_name == "CON") return true;
    if (variable_struct_exists(item, "affixes")) {
        for (var _a = 0; _a < array_length(item.affixes); _a++) {
            var _af = item.affixes[_a];
            if (variable_struct_exists(_af, "stat_name") && _af.stat_name == "armor") return true;
        }
    }
    return false;
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
// Legendary gear can be FOUND early (the thrill of a lucky drop) but can't be
// USED until the character has enough permanent (meta) levels - this keeps a
// +loot-tier shrine roll on A0 from handing out an immediately game-breaking
// legendary. (Task 6)
#macro LEGENDARY_EQUIP_PERM_LEVEL 4

function equip_stat_block_reason(item) {
    if (is_struct(item) && variable_struct_exists(item, "rarity") && item.rarity >= 4
        && player_permanent_level() < LEGENDARY_EQUIP_PERM_LEVEL) {
        return item.name + " requires Level " + string(LEGENDARY_EQUIP_PERM_LEVEL) + " (permanent) to equip.";
    }
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

    // When a HARD 2H weapon (greatsword/longbow) is equipped the offhand slot (1) is
    // locked - ignore it entirely. A caster staff does NOT lock the offhand: its
    // focus/tome offhand still contributes stats. (Task 10)
    var _offhand_locked = hard_two_handed_equipped();

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
    // Faerie's Tear potion + active Boon pet: extra equipment-drop chance (percentage points).
    var _loot_pot = potion_loot_bonus_pts() + pet_active_boon_loot_pts() + pet_active_lck_loot_pts() + pet_active_splash_loot_pts() + pet_active_egg_bonus("loot");

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
    if (_dust_gain > 0) _dust_gain = round(_dust_gain * (1 + pet_active_egg_bonus("dust")));   // Dust egg
    if (_dust_gain > 0) global.rune_dust += _dust_gain;

    // Combined log fragment appended to whatever gear/consumable also dropped.
    var _rune_suffix = "";
    if (_rune_drop != "") _rune_suffix += "  +  " + _rune_drop;
    if (_dust_gain > 0)   _rune_suffix += "  +  " + string(_dust_gain) + " Dust";

    if (enemy_type == "standard") {
        // Consumable drop chance tapers off with awakening (10% - 1%/tier, min 5%)
        // so higher tiers lean on boons/shops instead of drowning in heals.
        var _cons_chance = max(5, 10 - _drop_asc);
        // (Lucky Find reworked, audit §6: now a 20% chance consumables aren't consumed
        //  on use - the old +5% drop bonus here is gone.)
        if (!curse_blocks_consumables() && irandom(99) < _cons_chance) {   // Famine curse: no consumable drops
            var _c = roll_consumable_weighted(global.consumables_standard);
            array_push(global.run_items_found, _c);
            var _fit = consumable_award(_c);
            return _c.name + " [Consumable]" + (_fit ? "" : " (PACK FULL)") + _rune_suffix;
        }
        // 4% equipment drop (+ Faerie's Tear bonus) - rarity weights scale with awakening.
        if (irandom(99) < 4 + _loot_pot) {
            var _item = drop_equipment(drop_weights("standard", _drop_asc));
            array_push(global.run_items_found, _item);
            array_push(global.carried_items, _item);
            discover_item(item_base_name(_item));
            return _item.name + " [" + item_rarity_name(_item.rarity) + "]" + _rune_suffix;
        }

    } else if (enemy_type == "elite") {
        // Awakening taper (60% - 4%/tier, min 40%).
        var _elite_cons_chance = max(40, 60 - _drop_asc * 4);
        if (!curse_blocks_consumables() && irandom(99) < _elite_cons_chance) {   // Famine curse: no consumable drops
            var _c = roll_consumable_weighted(global.consumables_elite);
            array_push(global.run_items_found, _c);
            var _fit = consumable_award(_c);
            return _c.name + " [Consumable]" + (_fit ? "" : " (PACK FULL)") + _rune_suffix;
        }
        // 28% equipment drop (+ Faerie's Tear bonus) - rarity weights scale with awakening.
        if (irandom(99) < 28 + _loot_pot) {
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
// rune_inventory_sort() - sort the unsocketed rune pool alphabetically by name, then
// by tier (ascending). Covers BOTH gear and aspect runes (they share global.rune_inventory),
// so every list that reads it (Maren socket/aspect tabs, Sable salvage) shows a stable
// alphabetical order instead of drop-order. Called whenever Maren/Sable opens (the only
// places the pool is shown); the array is sorted in place so index-based socket/salvage
// operations stay correct.
function rune_inventory_sort() {
    if (!variable_global_exists("rune_inventory") || !is_array(global.rune_inventory)) return;
    if (array_length(global.rune_inventory) < 2) return;
    array_sort(global.rune_inventory, function(a, b) {
        var _ad = rune_get(a.id); var _bd = rune_get(b.id);
        var _an = (_ad != undefined) ? _ad.name : a.id;
        var _bn = (_bd != undefined) ? _bd.name : b.id;
        if (_an < _bn) return -1;
        if (_an > _bn) return 1;
        return a.tier - b.tier;
    });
}

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
    // Walk slots in the equipment tab's VISUAL order (equip_display_order, which puts
    // Ring 2 before the ranged weapon) rather than raw inventory index order, so the
    // socket-gear list mirrors exactly what the player sees on the equipment screen
    // instead of looking like an equip-time order. (Task: socket list order)
    var _order = equip_display_order();
    for (var _p = 0; _p < array_length(_order); _p++) {
        var _i = _order[_p];
        if (_i < 0 || _i >= array_length(global.inventory)) continue;
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
    quest_tick("socket_rune", "", 1);   // Phase 4a quest objective (Maren "Proof of Craft")
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
    quest_tick("socket_rune", "", 1);   // Phase 4a quest objective (Maren "Proof of Craft")
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
// Maren affinity perk: fee halved at Friend, waived at Companion (maren_fee_mult).
function rune_socket_cost() { return floor(30 * maren_fee_mult()); }

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
    if (affinity_at_least("sable", 2)) _dust = round(_dust * 1.10);   // Friend perk: +10% dust
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
    if (affinity_at_least("sable", 2)) _dust = round(_dust * 1.10);   // Friend perk: +10% dust
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
        // Exotic find-buff potions - effect lasts until 2 bosses are slain (~2 floors),
        // NOT stackable, cleared on death. See potion_* in this file.
        { id:"goldfinger", name:"Goldfinger Elixir", effect:"gold_find_pot", value:7, desc:"Gold drops +7% until 2 bosses are slain",       gold_val:65, dust:30, gold:cha_price(45) },
        { id:"faerie",     name:"Faerie's Tear",     effect:"loot_find_pot", value:8, desc:"Loot drop chance +8% until 2 bosses are slain", gold_val:65, dust:35, gold:cha_price(50) },
        // Devil Wine (design 2026-07-04): the RELIABLE escape. Drunk from the floor
        // map [G]: permanently lose 3 random stat points, extract with all run loot.
        // The Genie Lamp (rare elite/boss drop) is the free version of this bargain.
        { id:"devil_wine", name:"Devil Wine", effect:"escape_wine", value:0, desc:"Drink on the floor map [G]: PERMANENTLY lose 3 random stat points and extract to camp with all your loot", gold_val:400, dust:50, gold:cha_price(1200) },
    ];
    // (Sable Companion perk applies below via the catalog wrapper.)
}
// Catalog with the Companion-perk discount applied (single source for display + charge).
function sable_brew_catalog_priced() {
    var _c = sable_brew_catalog();
    var _m = sable_cost_mult();
    if (_m < 1.0) {
        for (var _i = 0; _i < array_length(_c); _i++) {
            _c[_i].gold = floor(_c[_i].gold * _m);
            _c[_i].dust = floor(_c[_i].dust * _m);
        }
    }
    return _c;
}
function sable_brew_get(id) {
    var _c = sable_brew_catalog_priced();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}
// Brew a potion by id. "" on success else reason (slot cap / gold / dust).
function sable_brew(id) {
    var _b = sable_brew_get(id);
    if (_b == undefined) return "Unknown recipe.";
    if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
    // Sable Lover perk (Private Reserve): the first brew after each run is on the house.
    var _free = affinity_at_least("sable", 4)
        && variable_global_exists("sable_free_brew") && global.sable_free_brew;
    if (!_free) {
        if (global.gold < _b.gold) return "Need " + string(_b.gold) + "g.";
        if (!variable_global_exists("rune_dust") || global.rune_dust < _b.dust) return "Need " + string(_b.dust) + " dust.";
        global.gold      -= _b.gold;
        global.rune_dust -= _b.dust;
    } else {
        global.sable_free_brew = false;
    }
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
        // Higher tier: fuse 3 elites into their master form (only effects with a real
        // step up). Targets live in global.consumables_master (sable_elite_template).
        { from:"Greater Healing Salve", to:"Master Healing Draught" },
        { from:"Warden's Tonic",        to:"Phoenix Tonic" },
    ];
}
function sable_upgrade_cost() {
    var _m = sable_cost_mult();   // Sable Companion perk: -20%
    return { gold: floor(cha_price(20) * _m), dust: floor(10 * _m) };
}

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
    // Higher-tier (elite->master) upgrade targets live in their own list.
    if (variable_global_exists("consumables_master")) {
        for (var _i = 0; _i < array_length(global.consumables_master); _i++)
            if (global.consumables_master[_i].name == name) return global.consumables_master[_i];
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
    var _vprice = floor(_sk.gold * affinity_discount_mult("vael"));   // Friend perk: 15% off
    if (global.gold < _vprice) return "Need " + string(_vprice) + "g.";
    global.gold -= _vprice;
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
// VAEL - SPELL TINTS (expression #4, EXPRESSION_IDEAS.md). Purchased palettes that
// recolor a school everywhere school_color() is consulted (combat-log school words
// and their numbers, ability-detail accents, loadout school text) plus a blended
// cast-VFX tint in combat. Pure cosmetics; a late-game gold sink for Vael.
// Owned tint ids live in global.unlocked_tints; the equipped tint per school lives
// in global.school_tints (struct school -> tint id, absent/"default" = base color).
// =============================================================================

// Two palettes per school. `color` fully replaces school_color(school) while equipped.
function vael_tint_catalog() {
    return [
        { id:"fire_ghost",   school:"fire",   name:"Ghostflame",      color:make_color_rgb(110, 230, 150), gold:250, desc:"Fire that burns green and cold - grave-light made weapon." },
        { id:"fire_white",   school:"fire",   name:"Whitehot",        color:make_color_rgb(210, 230, 255), gold:300, desc:"Heat past color. The forge's last word." },
        { id:"frost_black",  school:"frost",  name:"Black Ice",       color:make_color_rgb(110, 115, 220), gold:250, desc:"The deep dark of a lake that never thaws." },
        { id:"frost_aurora", school:"frost",  name:"Aurora",          color:make_color_rgb( 95, 230, 190), gold:300, desc:"Cold that dances the way the north sky does." },
        { id:"shock_void",   school:"shock",  name:"Voidspark",       color:make_color_rgb(200, 150, 255), gold:250, desc:"Lightning struck through somewhere emptier." },
        { id:"shock_storm",  school:"shock",  name:"Stormglow",       color:make_color_rgb( 90, 220, 235), gold:300, desc:"The sea-storm's teeth, bottled." },
        { id:"arcane_rose",  school:"arcane", name:"Roseweave",       color:make_color_rgb(235, 120, 180), gold:250, desc:"Spellwork with a silk lining." },
        { id:"arcane_gilt",  school:"arcane", name:"Gilded Art",      color:make_color_rgb(235, 190,  90), gold:300, desc:"Magic that spends like money." },
        { id:"blood_ichor",  school:"blood",  name:"Black Ichor",     color:make_color_rgb(170,  45, 105), gold:250, desc:"What runs in the veins of older things." },
        { id:"blood_ember",  school:"blood",  name:"Burning Blood",   color:make_color_rgb(240, 110,  70), gold:300, desc:"Fever given an edge." },
        { id:"void_pale",    school:"void",   name:"Hungering Pale",  color:make_color_rgb(215, 215, 235), gold:250, desc:"The void seen from inside. It is not black." },
        { id:"void_nebula",  school:"void",   name:"Nebula",          color:make_color_rgb(225, 110, 235), gold:300, desc:"Starving dark, dressed for the occasion." },
        { id:"shadow_moon",  school:"shadow", name:"Moonlit",         color:make_color_rgb(170, 195, 240), gold:250, desc:"Shadows cast by a kinder light." },
        { id:"shadow_ember", school:"shadow", name:"Embershade",      color:make_color_rgb(205, 140,  95), gold:300, desc:"Dark warmed at a dying fire." },
        { id:"poison_bloom", school:"poison", name:"Plaguebloom",     color:make_color_rgb(215, 220,  90), gold:250, desc:"Sickness in flower." },
        { id:"poison_abyss", school:"poison", name:"Abyssal Rot",     color:make_color_rgb( 85, 190, 215), gold:300, desc:"What festers where light gives up." },
    ];
}

function vael_tint_get(id) {
    var _c = vael_tint_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}

function vael_tint_owned(id) {
    if (!variable_global_exists("unlocked_tints")) return false;
    for (var _i = 0; _i < array_length(global.unlocked_tints); _i++)
        if (global.unlocked_tints[_i] == id) return true;
    return false;
}

// The tint id equipped for a school ("default" = base palette).
function school_tint_id(school) {
    if (!variable_global_exists("school_tints")) return "default";
    if (!variable_struct_exists(global.school_tints, school)) return "default";
    return variable_struct_get(global.school_tints, school);
}

// Buy a tint with gold (auto-equips for its school). "" on success else reason.
function vael_buy_tint(id) {
    var _t = vael_tint_get(id);
    if (_t == undefined) return "Unknown tint.";
    if (vael_tint_owned(id)) return "Already owned.";
    var _price = floor(_t.gold * affinity_discount_mult("vael"));   // Friend perk: 15% off
    if (global.gold < _price) return "Need " + string(_price) + "g.";
    global.gold -= _price;
    if (!variable_global_exists("unlocked_tints")) global.unlocked_tints = [];
    array_push(global.unlocked_tints, id);
    if (!variable_global_exists("school_tints")) global.school_tints = {};
    variable_struct_set(global.school_tints, _t.school, id);   // auto-equip
    save_game();
    return "";
}

// Equip an owned tint for its school, or pass "default" + a school to revert. "" or reason.
function vael_equip_tint(id, school = "") {
    if (!variable_global_exists("school_tints")) global.school_tints = {};
    if (id == "default") {
        if (school != "") variable_struct_set(global.school_tints, school, "default");
        save_game();
        return "";
    }
    var _t = vael_tint_get(id);
    if (_t == undefined) return "Unknown tint.";
    if (!vael_tint_owned(id)) return "Not owned.";
    variable_struct_set(global.school_tints, _t.school, id);
    save_game();
    return "";
}

// Blend color for cast VFX: the equipped tint's color, or c_white (no tint) on the
// default palette so untinted VFX render exactly as authored.
function school_vfx_blend(school) {
    if (school == "") return c_white;
    var _tid = school_tint_id(school);
    if (_tid == "default") return c_white;
    var _t = vael_tint_get(_tid);
    return (_t == undefined) ? c_white : _t.color;
}

// =============================================================================
// EPITHETS (expression #5, EXPRESSION_IDEAS.md). One equippable earned title,
// shown on the character menu header, the run-history screen and the combat
// result screen. Unlocks are LIVE checks against what the game already tracks
// (run history, clears, pets, affinity, permanent level) - nothing new is
// recorded, so every milestone rewards retroactively. Equipped id persists in
// global.player_epithet ("" = untitled); once equipped it stays yours even if
// the underlying state later changes (a lost pet doesn't strip the title).
// =============================================================================

function epithet_catalog() {
    return [
        { id:"gravebreaker", name:"the Gravebreaker",    req:"Clear a full dungeon" },
        { id:"survivor",     name:"the Survivor",        req:"Finish 25 runs" },
        { id:"deathless",    name:"the Deathless",       req:"10 full clears without a death between them" },
        { id:"vaultbreaker", name:"Vaultbreaker",        req:"Full-clear the Ashen Vault at A5" },
        { id:"flamewalker",  name:"Flamewalker",         req:"Full-clear the Scorched Depths at A5" },
        { id:"tombwarden",   name:"Tombwarden",          req:"Full-clear the Tundra Tomb at A5" },
        { id:"soulbound",    name:"the Soul-bound",      req:"Raise a pet to Soul-bound (Bond 18)" },
        { id:"awakener",     name:"the Awakener",        req:"Raise a pet to the Awakened stage" },
        { id:"beloved",      name:"the Beloved",         req:"Reach Lover with someone in Ironwake" },
        { id:"slayer",       name:"Slayer of Hundreds",  req:"500 lifetime kills" },
        { id:"goldhand",     name:"the Goldhanded",      req:"Earn 10,000 lifetime gold in the dungeons" },
        { id:"legend",       name:"the Legend",          req:"Reach permanent level 10" },
    ];
}

function epithet_get(id) {
    var _c = epithet_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}

// Live milestone check. Run-history-based checks guard missing fields (records
// written before a field existed simply don't count toward it).
function epithet_unlocked(id) {
    var _hist = variable_global_exists("run_history") ? global.run_history : [];
    var _hn   = array_length(_hist);
    switch (id) {
        case "gravebreaker":
            return variable_global_exists("dungeon_clears_total") && global.dungeon_clears_total >= 1;
        case "survivor":
            return variable_global_exists("run_count") && global.run_count >= 25;
        case "deathless": {
            // 10 full clears with no death between them (extractions don't break the run).
            var _streak = 0;
            for (var _i = 0; _i < _hn; _i++) {
                if (_hist[_i].result == 1)       _streak++;
                else if (_hist[_i].result == -1) _streak = 0;
                if (_streak >= 10) return true;
            }
            return false;
        }
        case "vaultbreaker": return epithet_a5_clear("ashen_vault");
        case "flamewalker":  return epithet_a5_clear("scorched_depths");
        case "tombwarden":   return epithet_a5_clear("tundra_tomb");
        case "soulbound": {
            var _r = pet_roster();
            for (var _i = 0; _i < array_length(_r); _i++)
                if (!_r[_i].is_egg && pet_bond(_r[_i]) >= 18) return true;
            return false;
        }
        case "awakener": {
            var _r2 = pet_roster();
            for (var _i = 0; _i < array_length(_r2); _i++)
                if (!_r2[_i].is_egg && _r2[_i].stage >= PET_STAGE_AWAKENED) return true;
            return false;
        }
        case "beloved":
            return affinity_count_at_tier(4) >= 1;
        case "slayer": {
            var _k = 0;
            for (var _i = 0; _i < _hn; _i++) _k += _hist[_i].kills;
            return _k >= 500;
        }
        case "goldhand": {
            var _g = 0;
            for (var _i = 0; _i < _hn; _i++) _g += _hist[_i].gold_earned;
            return _g >= 10000;
        }
        case "legend":
            return player_permanent_level() >= 10;
    }
    return false;
}

// A victorious A5 full clear of one dungeon anywhere in the run history. The
// `dungeon` field was added to run records 2026-07-04; older records lack it
// and can't count (they also predate anyone clearing A5, so nothing is lost).
function epithet_a5_clear(dungeon_key) {
    if (!variable_global_exists("run_history")) return false;
    for (var _i = 0; _i < array_length(global.run_history); _i++) {
        var _r = global.run_history[_i];
        if (variable_struct_exists(_r, "dungeon") && _r.dungeon == dungeon_key
            && _r.result == 1 && _r.ascendance >= 5 && _r.floor_reached >= 3) return true;
    }
    return false;
}

// Display name of the equipped epithet ("" when untitled / unknown id).
function player_epithet_text() {
    if (!variable_global_exists("player_epithet") || global.player_epithet == "") return "";
    var _e = epithet_get(global.player_epithet);
    return (_e == undefined) ? "" : _e.name;
}

// Cycle to the next unlocked epithet (T on the character menu Stats tab). The
// ring is [untitled] -> each unlocked catalog entry in order -> back. Returns
// the new display text ("Untitled" when cleared) for the caller's notification.
function epithet_cycle() {
    var _cat = epithet_catalog();
    var _ring = [""];
    for (var _i = 0; _i < array_length(_cat); _i++)
        if (epithet_unlocked(_cat[_i].id)) array_push(_ring, _cat[_i].id);
    var _cur = variable_global_exists("player_epithet") ? global.player_epithet : "";
    var _at  = 0;
    for (var _j = 0; _j < array_length(_ring); _j++) if (_ring[_j] == _cur) { _at = _j; break; }
    global.player_epithet = _ring[(_at + 1) mod array_length(_ring)];
    // Saves are hub-gated (see scr_save notes): the char menu also opens mid-run,
    // and save_game() would bank in-run state. Elsewhere the pick rides the next
    // hub save; the title itself is already applied for this session either way.
    if (instance_exists(obj_hub_controller)) save_game();
    return (global.player_epithet == "") ? "Untitled" : player_epithet_text();
}

// How many epithets are currently earned (for the picker hint).
function epithet_unlocked_count() {
    var _cat = epithet_catalog();
    var _n = 0;
    for (var _i = 0; _i < array_length(_cat); _i++) if (epithet_unlocked(_cat[_i].id)) _n++;
    return _n;
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
// NPC AFFINITY (thin track - Phase 0.5). Per-NPC hidden score -> discrete tiers,
// fed by function-use drip. NO gifts / gate-quests / neglect-decay yet (Phase 4).
// global.npc_affinity = { <id>: { score, tier, gate_ready, run_gain } } keyed by
// stable string ids. Meta-persistent (survives across runs, saved per slot); only
// run_gain resets each run (end_run). Tiers: 0 Stranger 1 Acquaintance 2 Friend
// 3 Companion 4 Lover. See AFFINITY_THIN_SPEC.md / NPC_Affinity_System_Design.md.
// =============================================================================

// Stable NPC ids (index-independent so roster growth - e.g. Bairc - can't shift keys).
function affinity_npc_ids() {
    return ["dorn", "sable", "maren", "vex", "petra", "vael", "bairc"];   // bairc wired Phase 4a
}

// Cumulative score needed to REACH each tier (index = tier). TUNABLE.
function affinity_thresholds() { return [0, 15, 45, 100, 180]; }

// Per-run soft cap on grindable (function-use) gain per NPC. TUNABLE.
// (Bumped 10 -> 30 on 2026-06-29 so a session of buying can actually cross a tier;
// also better matches the intended ~Friend-in-2-runs pacing.)
function affinity_run_soft_cap()  { return 30; }

// Scarcity caps (thin track = hard blocks; soft-demotion deferred to Phase 4).
function affinity_max_lovers()     { return 1; }
function affinity_max_companions() { return 2; }

// Tier display name for a tier index.
function affinity_tier_name_for(tier) {
    switch (tier) {
        case 0: return "Stranger";
        case 1: return "Acquaintance";
        case 2: return "Friend";
        case 3: return "Companion";
        case 4: return "Lover";
    }
    return "Stranger";
}

// Build a fresh zeroed affinity struct for every current NPC id.
function affinity_fresh() {
    var _a = {};
    var _ids = affinity_npc_ids();
    for (var _i = 0; _i < array_length(_ids); _i++) {
        variable_struct_set(_a, _ids[_i], { score: 0, tier: 0, gate_ready: false, run_gain: 0 });
    }
    return _a;
}

// Guarantee global.npc_affinity exists with a complete entry for every NPC id.
// Idempotent; backfills missing fields (schema drift / old saves). Returns the struct.
function affinity_ensure() {
    if (!variable_global_exists("npc_affinity") || !is_struct(global.npc_affinity)) {
        global.npc_affinity = affinity_fresh();
        return global.npc_affinity;
    }
    var _ids = affinity_npc_ids();
    for (var _i = 0; _i < array_length(_ids); _i++) {
        var _id = _ids[_i];
        if (!variable_struct_exists(global.npc_affinity, _id) || !is_struct(variable_struct_get(global.npc_affinity, _id))) {
            variable_struct_set(global.npc_affinity, _id, { score: 0, tier: 0, gate_ready: false, run_gain: 0 });
        } else {
            var _e = variable_struct_get(global.npc_affinity, _id);
            if (!variable_struct_exists(_e, "score"))      _e.score      = 0;
            if (!variable_struct_exists(_e, "tier"))       _e.tier       = 0;
            if (!variable_struct_exists(_e, "gate_ready")) _e.gate_ready = false;
            if (!variable_struct_exists(_e, "run_gain"))   _e.run_gain   = 0;
        }
    }
    return global.npc_affinity;
}

// Fetch an NPC's affinity entry (ensures the struct first). undefined on bad id.
function affinity_entry(id) {
    affinity_ensure();
    if (!variable_struct_exists(global.npc_affinity, id)) return undefined;
    return variable_struct_get(global.npc_affinity, id);
}

// --- Read API (features query these, never the raw struct) -----------------
function affinity_tier(id) {
    var _e = affinity_entry(id);
    return (_e == undefined) ? 0 : _e.tier;
}
function affinity_at_least(id, tier) { return affinity_tier(id) >= tier; }
function affinity_tier_name(id)      { return affinity_tier_name_for(affinity_tier(id)); }

// How many NPCs currently sit at exactly the given tier (scarcity-cap checks).
function affinity_count_at_tier(tier) {
    affinity_ensure();
    var _n = 0;
    var _ids = affinity_npc_ids();
    for (var _i = 0; _i < array_length(_ids); _i++) {
        if (variable_struct_get(global.npc_affinity, _ids[_i]).tier == tier) _n++;
    }
    return _n;
}

// Progress fraction (0..1) from the current tier toward the next gate. 1.0 at Lover.
// Drives the UI bar; the raw score is intentionally never surfaced (diegetic).
function affinity_progress_frac(id) {
    var _e = affinity_entry(id);
    if (_e == undefined) return 0;
    var _th = affinity_thresholds();
    if (_e.tier >= array_length(_th) - 1) return 1.0;
    var _lo = _th[_e.tier];
    var _hi = _th[_e.tier + 1];
    if (_hi <= _lo) return 1.0;
    return clamp((_e.score - _lo) / (_hi - _lo), 0, 1);
}

// True when this NPC has reached the next gate and awaits the deepen-bond confirm.
// Computed LIVE from score (robust to any score change, not just affinity_add), and
// applies the frictionless Stranger->Acquaintance auto-cross on the way. tier 0 never
// reports "ready" (it auto-crosses); Lover (max) never reports ready.
function affinity_gate_ready(id) {
    var _e = affinity_entry(id);
    if (_e == undefined) return false;
    var _th = affinity_thresholds();
    if (_e.tier == 0 && _e.score >= _th[1]) { _e.tier = 1; global.heart_pending = 1; }   // auto-cross on-ramp, live
    if (_e.tier < 1 || _e.tier >= array_length(_th) - 1) return false;
    return _e.score >= _th[_e.tier + 1];
}

// --- Earning + gates -------------------------------------------------------

// Recompute gate_ready from score; auto-cross the frictionless Stranger->Acquaintance
// gate (tier 0->1 needs no confirm). Friend+/Lover gates set gate_ready for the
// one-click deepen-bond confirm.
function affinity_refresh_gate(id) {
    var _e = affinity_entry(id);
    if (_e == undefined) return;
    var _th = affinity_thresholds();
    if (_e.tier >= array_length(_th) - 1) { _e.gate_ready = false; return; }   // maxed (Lover)

    if (_e.score >= _th[_e.tier + 1]) {
        if (_e.tier == 0) {
            _e.tier = 1;                 // Stranger -> Acquaintance: auto, no confirm
            global.heart_pending = 1;    // tier-up heart burst (blue)
            _e.gate_ready = false;
            journal_badge_npc(id);       // Journal: relationship moved (Phase 4a)
            ledger_add(id, "milestone", "We're past nodding terms now - acquaintances.");
            affinity_refresh_gate(id);   // score may already clear the next gate
        } else {
            if (!_e.gate_ready) journal_badge_npc(id);   // newly ready -> badge once
            _e.gate_ready = true;        // awaits the deepen-bond confirm
        }
    } else {
        _e.gate_ready = false;
    }
}

// Add function-use drip to an NPC. Honours the per-run soft cap, updates score, and
// refreshes the gate. Phase 0.5: drip is the ONLY score source. Save is handled by
// the caller (drip rides the hub's existing post-transaction save).
function affinity_add(id, amount) {
    var _e = affinity_entry(id);
    if (_e == undefined || amount <= 0) return;
    npc_actor_play_action();   // the open NPC's sprite reacts to the transaction
    var _room = affinity_run_soft_cap() - _e.run_gain;
    if (_room <= 0) return;             // this NPC already capped this run
    var _gain = min(amount, _room);
    _e.score    += _gain;
    _e.run_gain += _gain;
    _e.idle_clears = 0;   // 4c neglect: any function-use is attention paid
    affinity_refresh_gate(id);
    quest_tick("use_function", id, 1);   // quest objective: N interactions with this NPC
}

// [B] Deepen at a ready gate (4c: routes through the GATE QUEST, PHASE4C_SPEC.md).
//   quest available -> starts it (this IS the player-elected pursue for Lover);
//   quest active    -> progress reminder;
//   quest done      -> free one-click recross (re-climb after neglect/demotion -
//                      neglect never re-quests; slot demotion resets the quest so
//                      that path DOES land in "available" again).
// Returns "" when the tier actually crossed, else a message for the notification
// line (starting a quest is a message, not a cross).
function affinity_try_advance(id) {
    var _e = affinity_entry(id);
    if (_e == undefined)         return "Unknown.";
    if (!affinity_gate_ready(id)) return "Not ready.";   // live check (also applies auto-cross)
    var _target = _e.tier + 1;

    var _gnames = ["", "", "friend", "companion", "lover"];
    var _qid = "gate_" + id + "_" + _gnames[_target];
    var _qs  = quest_state(_qid);
    if (_qs == undefined || _qs.status == "done") {
        // No authored gate quest (future NPCs) or already cleared once: cross free.
        affinity_gate_cross(id, _target);
        return "";
    }
    var _qd = quest_def(_qid);
    if (_qs.status == "active") {
        return "\"" + _qd.name + "\" is underway - " + _qd.objective + ".";
    }
    quest_start(_qid);
    ledger_add(id, "quest", "They asked something of you first: \"" + _qd.name + "\".");
    return npc_display_name(id) + " asks: " + _qd.objective + "   (\"" + _qd.name + "\" - on the board & Journal)";
}

// Cross a tier NOW (gate-quest turn-in, done-quest recross, or future-NPC fallback).
// Applies the 4c scarcity side effects instead of hard blocks: a 3rd Companion
// slot-demotes the lowest existing Companion (re-quest required); a 2nd Lover is
// BETRAYAL - the old Lover drops to soured Acquaintance and must be re-courted.
function affinity_gate_cross(id, target) {
    var _e = affinity_entry(id);
    if (_e == undefined) return;
    if (target == 3) affinity_slot_demote_for(id);
    if (target == 4) affinity_betrayal_for(id);
    if (_e.tier < target) _e.tier = target;
    global.heart_pending = target;      // tier-up heart burst (blue tiers 1-3, red Lover)
    journal_badge_npc(id);
    ledger_add(id, "milestone", "We grew closer - " + affinity_tier_name_for(target) + " now.");
    affinity_refresh_gate(id);          // re-evaluate (score may reach the next gate)
}

// Reset a gate quest so it must be re-cleared (slot demotion / betrayal only).
function quest_reset_gate(id) {
    var _s = quest_state(id);
    if (_s == undefined) return;
    _s.status   = "available";
    _s.progress = 0;
}

// A 3rd Companion incoming: demote the lowest-score OTHER Companion to Friend and
// reset their Companion gate quest (the §5 "teeth"). No-op below the cap.
function affinity_slot_demote_for(new_id) {
    var _ids = affinity_npc_ids();
    var _others = [];
    for (var _i = 0; _i < array_length(_ids); _i++) {
        if (_ids[_i] == new_id) continue;
        var _o = affinity_entry(_ids[_i]);
        if (_o != undefined && _o.tier == 3) array_push(_others, _ids[_i]);
    }
    if (array_length(_others) < affinity_max_companions()) return;
    var _low = _others[0];
    for (var _j = 1; _j < array_length(_others); _j++) {
        if (affinity_entry(_others[_j]).score < affinity_entry(_low).score) _low = _others[_j];
    }
    var _le = affinity_entry(_low);
    _le.tier = 2;
    quest_reset_gate("gate_" + _low + "_companion");
    affinity_refresh_gate(_low);
    ledger_add(_low, "milestone", "You committed to another. Things cooled between you - Friend again.");
    journal_badge_npc(_low);
    var _dmsg = npc_display_name(_low) + " steps back to make room - Companion no more.";
    if (variable_global_exists("pet_find_notice")) {
        global.pet_find_notice = (global.pet_find_notice != "") ? (global.pet_find_notice + "   " + _dmsg) : _dmsg;
    }
}

// Per-NPC betrayal severity band (4c color pass; PHASE4C_SPEC §5). How hard a
// jilted Lover falls:
//   "harsh"    - pride burns: Acquaintance with NOTHING kept (score 0, full re-court).
//   "standard" - soured Acquaintance at the tier floor, full re-court (the v1 curve).
//   "soft"     - hurt, not hateful: the Friendship survives (Friend floor); only the
//                Companion and Lover gates must be re-earned.
function affinity_betrayal_severity(id) {
    switch (id) {
        case "vael": case "sable":  return "harsh";
        case "maren": case "bairc": return "soft";
    }
    return "standard";   // dorn / vex / petra
}

// Voice-matched heartbreak text (4c color pass): ledger entry (second person, matches
// the milestone style) + hub notice (third person, one line). Fallback for future NPCs.
function affinity_betrayal_lines(id) {
    switch (id) {
        case "dorn":  return { ledger: "You chose another. He went back to the anvil and let the hammer answer for him.",
                               notice: "Dorn says nothing. The forge just rings louder than it needs to." };
        case "sable": return { ledger: "You chose another. She smiled like a sealed vial - something saved in it for later.",
                               notice: "Sable's smile no longer reaches her eyes. \"Strangers, then, darling.\"" };
        case "maren": return { ledger: "You chose another. She set down the graver, quiet - the runes had already told her.",
                               notice: "Maren keeps her voice level. The friendship holds; the rest is closed." };
        case "vex":   return { ledger: "You chose another. He called it a lesson and, for once, took his own advice.",
                               notice: "Vex nods once, like a match conceded. Training continues. Nothing else does." };
        case "petra": return { ledger: "You chose another. Every price between you went back up, and so did she.",
                               notice: "Petra quotes you the stranger's rate now - with interest." };
        case "vael":  return { ledger: "You chose another. She looked at you like a piece she had badly overpaid for.",
                               notice: "Vael has decided you were never her taste. The sittings are over." };
        case "bairc": return { ledger: "You chose another. He didn't shout. He just went back to the pens, and didn't ask you to follow.",
                               notice: "Bairc keeps to the pens now. The creatures still like you. He needs time." };
    }
    return { ledger: "You chose another. Something in them closes for good measure.",
             notice: npc_display_name(id) + "'s heart breaks - you are strangers with history now." };
}

// A 2nd Lover incoming: betrayal. How far the old Lover falls depends on who they
// are (affinity_betrayal_severity):
//   harsh    - tier 1 at score 0, ALL gate quests reset (full re-court from nothing)
//   standard - tier 1 at the Acquaintance floor, ALL gate quests reset
//   soft     - tier 2 at the Friend floor; only the Companion/Lover gates reset
function affinity_betrayal_for(new_id) {
    var _ids = affinity_npc_ids();
    for (var _i = 0; _i < array_length(_ids); _i++) {
        if (_ids[_i] == new_id) continue;
        var _o = affinity_entry(_ids[_i]);
        if (_o == undefined || _o.tier != 4) continue;
        var _sev = affinity_betrayal_severity(_ids[_i]);
        if (_sev == "soft") {
            _o.tier  = 2;
            _o.score = affinity_thresholds()[2];
        } else {
            _o.tier  = 1;
            _o.score = (_sev == "harsh") ? 0 : affinity_thresholds()[1];
            quest_reset_gate("gate_" + _ids[_i] + "_friend");
        }
        _o.gate_ready = false;
        quest_reset_gate("gate_" + _ids[_i] + "_companion");
        quest_reset_gate("gate_" + _ids[_i] + "_lover");
        var _lines = affinity_betrayal_lines(_ids[_i]);
        ledger_add(_ids[_i], "milestone", _lines.ledger);
        journal_badge_npc(_ids[_i]);
        audio_play_sound(snd_sting_heartbreak, 1, false);   // a music box winding down
        if (variable_global_exists("pet_find_notice")) {
            global.pet_find_notice = (global.pet_find_notice != "") ? (global.pet_find_notice + "   " + _lines.notice) : _lines.notice;
        }
    }
}

// Neglect decay (4c, design §6): ticked once per floor-clear. 6 idle clears of
// grace per NPC, then -2 score per further clear. Hitting zero costs exactly one
// tier ("drifting apart"). Companion+ is frozen - commitment doesn't rot. Neglect
// NEVER resets a gate quest; re-climbing is points-only (the done quest recrosses
// free via affinity_try_advance).
function affinity_neglect_tick() {
    if (!variable_global_exists("npc_affinity") || !is_struct(global.npc_affinity)) return;
    var _ids = affinity_npc_ids();
    for (var _i = 0; _i < array_length(_ids); _i++) {
        var _e = affinity_entry(_ids[_i]);
        if (_e == undefined) continue;
        if (!variable_struct_exists(_e, "idle_clears")) _e.idle_clears = 0;   // migrate old saves
        if (_e.tier >= 3) { _e.idle_clears = 0; continue; }   // Companion & Lover are safe
        _e.idle_clears += 1;
        if (_e.idle_clears > 6 && _e.score > 0) {
            _e.score = max(0, _e.score - 2);
            if (_e.score == 0 && _e.tier > 0) {
                _e.tier -= 1;
                ledger_add(_ids[_i], "milestone", "Too long a stranger - you've drifted apart.");
                journal_badge_npc(_ids[_i]);
            }
            affinity_refresh_gate(_ids[_i]);
        }
    }
}

// Reset the per-run grind cap for every NPC (NOT score/tier). Called from end_run.
function affinity_reset_run_gain() {
    if (!variable_global_exists("npc_affinity") || !is_struct(global.npc_affinity)) return;
    var _ids = affinity_npc_ids();
    for (var _i = 0; _i < array_length(_ids); _i++) {
        if (variable_struct_exists(global.npc_affinity, _ids[_i])) {
            variable_struct_get(global.npc_affinity, _ids[_i]).run_gain = 0;
        }
    }
}

// =============================================================================
// PHASE 4a - QUEST DATA LAYER + JOURNAL (PHASE4A_SPEC.md). The quest layer is the
// plumbing the Journal surfaces; gate quests swap in at 4c (gates stay one-click).
// State model: quest DEFINITIONS live in quest_catalog() (code-authored); only
// {id, status, progress} persists per save (global.quests). Objective templates:
// clear_floors / kill_family / boss_kill / pet_stage / socket_rune / use_function.
// =============================================================================

// The authored quest set. 4a ships 3 placeholder starter hunts to prove the loop.
function quest_catalog() {
    return [
        { id:"hunt_dorn_floors", kind:"hunt", npc:"dorn", name:"The Warden's Due",
          obj_type:"clear_floors", obj_target:3, obj_param:"",
          reward:{ gold:150, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Vault won't clear itself. Bring me proof you've been below - three floors' worth - and I'll make it worth your time.\"",
          objective:"Clear 3 dungeon floors" },
        { id:"hunt_bairc_adolescent", kind:"hunt", npc:"bairc", name:"A Good Start",
          obj_type:"pet_stage", obj_target:PET_STAGE_ADOLESCENT, obj_param:"",
          reward:{ gold:0, feed:"prime", feed_n:2, rune_id:"", rune_tier:0 },
          flavor:"\"...raise one. Just to Adolescent. You'll see why I do this.\"",
          objective:"Raise any creature to Adolescent" },
        { id:"hunt_maren_sockets", kind:"hunt", npc:"maren", name:"Proof of Craft",
          obj_type:"socket_rune", obj_target:2, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"vitality", rune_tier:1 },
          flavor:"\"Runes remember the hands that set them. Set two, and I'll trust yours with something better.\"",
          objective:"Socket 2 runes with Maren" },

        // =====================================================================
        // AFFINITY GATE QUESTS (Phase 4c, PHASE4C_SPEC.md). kind:"gate" +
        // gate_tier 2/3/4 = Friend/Companion/Lover. Hidden until the NPC's score
        // has the gate READY (quest_visible); turning in crosses the tier via
        // affinity_gate_cross - the relationship IS the reward (reward struct
        // stays zeroed). No reward = no farm; each is one-time per climb.
        // =====================================================================
        // --- Dorn (Blacksmith) ---
        { id:"gate_dorn_friend", kind:"gate", gate_tier:2, npc:"dorn", name:"Working Steel",
          obj_type:"use_function", obj_target:3, obj_param:"dorn",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Buy, sell, sharpen - doesn't matter which. Show me you're a regular, not a tourist.\"",
          objective:"Do business with Dorn 3 times" },
        { id:"gate_dorn_companion", kind:"gate", gate_tier:3, npc:"dorn", name:"Boss-Forged",
          obj_type:"boss_kill", obj_target:2, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"My steel's been down there with you. Fell two of the deep's masters and we're partners, not customers.\"",
          objective:"Slay 2 bosses" },
        { id:"gate_dorn_lover", kind:"gate", gate_tier:4, npc:"dorn", name:"The Quenching",
          obj_type:"clear_floors", obj_target:6, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Six floors. Come back whole every time, and I'll show you what I keep in the back of the forge.\"",
          objective:"Clear 6 dungeon floors" },
        // --- Sable (Alchemist) ---
        { id:"gate_sable_friend", kind:"gate", gate_tier:2, npc:"sable", name:"Field Reagents",
          obj_type:"kill_family", obj_target:8, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Everything that dies down there is an ingredient, darling. Go make me some ingredients.\"",
          objective:"Slay 8 foes" },
        { id:"gate_sable_companion", kind:"gate", gate_tier:3, npc:"sable", name:"Repeat Customer",
          obj_type:"use_function", obj_target:5, obj_param:"sable",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Five more visits. Not for the gold - I just like watching you pretend you came for the potions.\"",
          objective:"Use Sable's services 5 times" },
        { id:"gate_sable_lover", kind:"gate", gate_tier:4, npc:"sable", name:"The Slow Poison",
          obj_type:"boss_kill", obj_target:3, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Three floor-lords' worth of ichor. It's for something personal. So are you.\"",
          objective:"Slay 3 bosses" },
        // --- Maren (Runesmith) ---
        { id:"gate_maren_friend", kind:"gate", gate_tier:2, npc:"maren", name:"First Setting",
          obj_type:"socket_rune", obj_target:1, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Set one with me. Watch what your hands do when they mean it.\"",
          objective:"Socket a rune with Maren" },
        { id:"gate_maren_companion", kind:"gate", gate_tier:3, npc:"maren", name:"Steady Hands",
          obj_type:"socket_rune", obj_target:3, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Three more settings. Runes remember. So do I.\"",
          objective:"Socket 3 runes with Maren" },
        { id:"gate_maren_lover", kind:"gate", gate_tier:4, npc:"maren", name:"What the Runes Say",
          obj_type:"boss_kill", obj_target:2, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"The deep lords carry old script in their bones. Bring me two readings... and come back. That part matters more.\"",
          objective:"Slay 2 bosses" },
        // --- Vex (Trainer) ---
        { id:"gate_vex_friend", kind:"gate", gate_tier:2, npc:"vex", name:"Student's Dues",
          obj_type:"use_function", obj_target:3, obj_param:"vex",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Train with me three times. Talent I can't teach. Showing up, I can insist on.\"",
          objective:"Train with Vex 3 times" },
        { id:"gate_vex_companion", kind:"gate", gate_tier:3, npc:"vex", name:"Proof of Practice",
          obj_type:"kill_family", obj_target:10, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Ten foes, no excuses. I don't bond with theory.\"",
          objective:"Slay 10 foes" },
        { id:"gate_vex_lover", kind:"gate", gate_tier:4, npc:"vex", name:"The Last Lesson",
          obj_type:"clear_floors", obj_target:6, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Six floors. When there's nothing left I can teach you... there's something I've been meaning to say.\"",
          objective:"Clear 6 dungeon floors" },
        // --- Petra (Treasure Trader) ---
        { id:"gate_petra_friend", kind:"gate", gate_tier:2, npc:"petra", name:"Good Custom",
          obj_type:"use_function", obj_target:3, obj_param:"petra",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Trade with me thrice and I'll stop quoting you the stranger's rate. In more ways than one.\"",
          objective:"Trade with Petra 3 times" },
        { id:"gate_petra_companion", kind:"gate", gate_tier:3, npc:"petra", name:"A Trader's Eye",
          obj_type:"gift_good", obj_target:2, obj_param:"petra",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Anyone can buy. Show me you know what I'd actually WANT - twice.\"",
          objective:"Give Petra 2 gifts she likes or loves" },
        { id:"gate_petra_lover", kind:"gate", gate_tier:4, npc:"petra", name:"First Pick",
          obj_type:"boss_kill", obj_target:2, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"The best finds sit behind the worst doors. Open two of them for me and everything I have is yours first.\"",
          objective:"Slay 2 bosses" },
        // --- Vael (Aesthete) ---
        { id:"gate_vael_friend", kind:"gate", gate_tier:2, npc:"vael", name:"An Eye for It",
          obj_type:"use_function", obj_target:2, obj_param:"vael",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Let me dress you twice. The dark stares back - give it something worth staring at.\"",
          objective:"Use Vael's services twice" },
        { id:"gate_vael_companion", kind:"gate", gate_tier:3, npc:"vael", name:"Curated Taste",
          obj_type:"gift_good", obj_target:2, obj_param:"vael",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Bring me two things I don't hate. It is a higher bar than you think.\"",
          objective:"Give Vael 2 gifts she likes or loves" },
        { id:"gate_vael_lover", kind:"gate", gate_tier:4, npc:"vael", name:"The Unveiling",
          obj_type:"clear_floors", obj_target:5, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Five floors, and come back with the dark still in your eyes. I want to paint it. Among other things.\"",
          objective:"Clear 5 dungeon floors" },
        // --- Bairc (Creature Keeper) ---
        { id:"gate_bairc_friend", kind:"gate", gate_tier:2, npc:"bairc", name:"Small Kindnesses",
          obj_type:"use_function", obj_target:3, obj_param:"bairc",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"...you keep coming back. The creatures notice. Three more visits and, well. I notice too.\"",
          objective:"Tend creatures with Bairc 3 times" },
        { id:"gate_bairc_companion", kind:"gate", gate_tier:3, npc:"bairc", name:"Raised Right",
          obj_type:"pet_stage", obj_target:PET_STAGE_ADULT, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Raise one all the way. Anyone can pity a hatchling - staying is the thing.\"",
          objective:"Raise any creature to Adult" },
        { id:"gate_bairc_lover", kind:"gate", gate_tier:4, npc:"bairc", name:"Come Home Safe",
          obj_type:"boss_kill", obj_target:2, obj_param:"",
          reward:{ gold:0, feed:"", feed_n:0, rune_id:"", rune_tier:0 },
          flavor:"\"Two of the deep's worst. Not for proof. I just... need to know the dark gives you back.\"",
          objective:"Slay 2 bosses" },
    ];
}

// A quest def is a gate quest when kind == "gate" (4c). Small helper - several
// surfaces branch on it.
function quest_is_gate(d) {
    return (d != undefined) && variable_struct_exists(d, "kind") && d.kind == "gate";
}

// Visibility filter (4c): hunts always show; a gate quest hides until its NPC has
// banked the points (gate READY) and sits exactly one tier below the gate - then
// it appears on the board/Journal as the key to the next tier. Active/done gates
// always show (progress + history).
function quest_visible(id) {
    var _d = quest_def(id);
    if (_d == undefined) return false;
    if (!quest_is_gate(_d)) return true;
    var _s = quest_state(id);
    if (_s != undefined && _s.status != "available") return true;
    var _e = affinity_entry(_d.npc);
    if (_e == undefined) return false;
    return affinity_gate_ready(_d.npc) && (_e.tier + 1 == _d.gate_tier);
}

function quest_def(id) {
    var _c = quest_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return board_request_def(id);   // procedural board requests (BOARD_REQUESTS_SPEC.md)
}

// Guarantee global.quests holds one state row per catalog entry (append-migrates when
// the catalog grows; orphaned rows from removed quests are left inert). Idempotent.
function quest_state_ensure() {
    if (!variable_global_exists("quests") || !is_array(global.quests)) global.quests = [];
    var _c = quest_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        var _found = false;
        for (var _j = 0; _j < array_length(global.quests); _j++)
            if (global.quests[_j].id == _c[_i].id) { _found = true; break; }
        if (!_found) array_push(global.quests, { id:_c[_i].id, status:"available", progress:0 });
    }
    return global.quests;
}

function quest_state(id) {
    var _q = quest_state_ensure();
    for (var _i = 0; _i < array_length(_q); _i++) if (_q[_i].id == id) return _q[_i];
    return undefined;
}

// True when an ACTIVE quest has met its target (awaiting hub turn-in).
function quest_is_complete(id) {
    var _s = quest_state(id); var _d = quest_def(id);
    if (_s == undefined || _d == undefined) return false;
    return _s.status == "active" && _s.progress >= _d.obj_target;
}

// Advance every ACTIVE quest matching this objective type (+ param, when the quest
// specifies one). pet_stage is level-reached (max), the rest are counters (sum).
// Newly-completed quests badge their Journal entry + queue a hub notice.
function quest_tick(obj_type, param, amount) {
    var _q = quest_state_ensure();
    for (var _i = 0; _i < array_length(_q); _i++) {
        var _s = _q[_i];
        if (_s.status != "active") continue;
        var _d = quest_def(_s.id);
        if (_d == undefined || _d.obj_type != obj_type) continue;
        if (_d.obj_param != "" && _d.obj_param != param) continue;
        var _was = _s.progress;
        if (obj_type == "pet_stage") _s.progress = max(_s.progress, min(amount, _d.obj_target));
        else                         _s.progress = min(_d.obj_target, _s.progress + amount);
        if (_s.progress != _was) {
            journal_badge_quest(_s.id);
            if (_s.progress >= _d.obj_target && variable_global_exists("pet_find_notice")) {
                var _qmsg = "Request complete: " + _d.name + " - report to the tavern board.";
                global.pet_find_notice = (global.pet_find_notice != "")
                    ? (global.pet_find_notice + "   " + _qmsg) : _qmsg;
            }
        }
    }
}

// Start an AVAILABLE quest. Hub-only (caller enforces the room). "" ok / reason.
function quest_start(id) {
    var _s = quest_state(id);
    if (_s == undefined)          return "Unknown quest.";
    if (_s.status == "active")    return "Already underway.";
    if (_s.status == "done")      return "Already done.";
    _s.status = "active";
    journal_badge_quest(id);
    return "";
}

// Turn in a completed quest at the hub: grants the reward, logs the ledger entry.
// "" ok / reason. Caller saves.
function quest_turn_in(id) {
    var _s = quest_state(id); var _d = quest_def(id);
    if (_s == undefined || _d == undefined) return "Unknown quest.";
    if (_s.status != "active")              return "Not underway.";
    if (_s.progress < _d.obj_target)        return "Not finished yet.";
    _s.status = "done";
    // Gate quests (4c): turning in crosses the tier - THAT is the reward. The
    // material-reward path below is skipped (gate rewards are authored zeroed).
    if (quest_is_gate(_d)) {
        affinity_gate_cross(_d.npc, _d.gate_tier);
        ledger_add(_d.npc, "quest", "You did what they asked - \"" + _d.name + "\".");
        journal_badge_quest(id);
        return "";
    }
    var _r = _d.reward;
    var _parts = [];
    if (_r.gold > 0) { global.gold += _r.gold; array_push(_parts, string(_r.gold) + "g"); }
    if (_r.feed != "" && _r.feed_n > 0) {
        var _fd = pet_feed_get(_r.feed);
        variable_struct_set(pet_feed_pouch(), _r.feed, pet_feed_pouch_count(_r.feed) + _r.feed_n);
        array_push(_parts, string(_r.feed_n) + "x " + ((_fd != undefined) ? _fd.name : _r.feed));
    }
    if (_r.rune_id != "" && _r.rune_tier > 0) {
        if (!variable_global_exists("rune_inventory")) global.rune_inventory = [];
        var _rn = rune_make(_r.rune_id, _r.rune_tier);
        array_push(global.rune_inventory, _rn);
        array_push(_parts, _rn.name + " rune");
    }
    // Board-request extras (BOARD_REQUESTS_SPEC.md): dust / item roll / Reforge Chit.
    if (variable_struct_exists(_r, "dust") && _r.dust > 0) {
        if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
        global.rune_dust += _r.dust;
        array_push(_parts, string(_r.dust) + " rune dust");
    }
    if (variable_struct_exists(_r, "item") && _r.item) {
        var _bi = drop_equipment(drop_weights("vault", highest_awakening_unlocked()));
        array_push(global.equipment_stash, _bi);
        array_push(_parts, _bi.name + " (stashed)");
    }
    if (variable_struct_exists(_r, "chit") && _r.chit > 0) {
        board_requests_ensure();
        global.reforge_chits += _r.chit;
        array_push(_parts, string(_r.chit) + " Reforge Chit (Dorn honors these)");
    }
    var _rtxt = "their thanks";
    if (array_length(_parts) > 0) {
        _rtxt = _parts[0];
        for (var _pi = 1; _pi < array_length(_parts); _pi++) _rtxt += ", " + _parts[_pi];
    }
    ledger_add(_d.npc, "quest", "Finished \"" + _d.name + "\" - earned " + _rtxt + ".");
    journal_badge_npc(_d.npc);
    journal_badge_quest(id);
    // Board requests are ephemeral: the fulfilled notice comes down entirely
    // (def + state row removed; the run-end refill re-stocks the slot).
    if (quest_is_board(_d)) board_retire(id);
    return "";
}

// Quests grouped for the Journal Quests tab: {active:[], available:[], done:[]} of ids.
function quest_groups() {
    var _q = quest_state_ensure();
    var _g = { active: [], available: [], done: [] };
    for (var _i = 0; _i < array_length(_q); _i++) {
        var _s = _q[_i];
        if (quest_def(_s.id) == undefined) continue;   // orphaned row
        if (!quest_visible(_s.id)) continue;           // 4c: gate quests hide until ready
        if      (_s.status == "active")    array_push(_g.active, _s.id);
        else if (_s.status == "available") array_push(_g.available, _s.id);
        else                               array_push(_g.done, _s.id);
    }
    return _g;
}
// The NPC's turn-in-ready / startable quest for the hub-panel [Q] affordance.
function quest_for_npc(npc_id) {
    var _q = quest_state_ensure();
    var _avail = "";
    for (var _i = 0; _i < array_length(_q); _i++) {
        var _d = quest_def(_q[_i].id);
        if (_d == undefined || _d.npc != npc_id) continue;
        if (!quest_visible(_q[_i].id)) continue;                     // 4c: hidden gates don't prompt
        if (quest_is_complete(_q[_i].id)) return _q[_i].id;          // turn-in beats start
        if (_q[_i].status == "available" && _avail == "") _avail = _q[_i].id;
    }
    return _avail;
}

// --- Journal badges (dirty flags; cleared when the player VIEWS the entry) ---------
function journal_badges() {
    if (!variable_global_exists("journal_badges") || !is_struct(global.journal_badges))
        global.journal_badges = { npcs: {}, quests: {} };
    return global.journal_badges;
}
function journal_badge_npc(id)      { variable_struct_set(journal_badges().npcs, id, true); }
function journal_badge_quest(id)    { variable_struct_set(journal_badges().quests, id, true); }
function journal_npc_badged(id)     { var _b = journal_badges().npcs;   return variable_struct_exists(_b, id)   && variable_struct_get(_b, id); }
function journal_quest_badged(id)   { var _b = journal_badges().quests; return variable_struct_exists(_b, id) && variable_struct_get(_b, id); }
function journal_clear_npc(id)      { variable_struct_set(journal_badges().npcs, id, false); }
function journal_clear_quest(id)    { variable_struct_set(journal_badges().quests, id, false); }
function journal_any_badge() {
    var _b = journal_badges();
    var _nk = variable_struct_get_names(_b.npcs);
    for (var _i = 0; _i < array_length(_nk); _i++) if (variable_struct_get(_b.npcs, _nk[_i])) return true;
    var _qk = variable_struct_get_names(_b.quests);
    for (var _j = 0; _j < array_length(_qk); _j++) if (variable_struct_get(_b.quests, _qk[_j])) return true;
    return false;
}

// --- Interaction ledger (per-NPC journal sections; 4a logs tier crossings + quest
// turn-ins, gifts append in 4b). Entries: { kind, text, run } newest LAST. ----------
function npc_ledger(id) {
    if (!variable_global_exists("npc_ledger") || !is_struct(global.npc_ledger)) global.npc_ledger = {};
    if (!variable_struct_exists(global.npc_ledger, id)) variable_struct_set(global.npc_ledger, id, []);
    return variable_struct_get(global.npc_ledger, id);
}
function ledger_add(id, kind, text) {
    var _l = npc_ledger(id);
    array_push(_l, { kind: kind, text: text, run: variable_global_exists("run_count") ? global.run_count : 0 });
    if (array_length(_l) > 30) array_delete(_l, 0, array_length(_l) - 30);   // keep it bounded
}

// --- Journal display helpers -------------------------------------------------------
function npc_display_name(id) {
    switch (id) {
        case "dorn":  return "Dorn";
        case "sable": return "Sable";
        case "maren": return "Maren";
        case "vex":   return "Vex";
        case "petra": return "Petra";
        case "vael":  return "Vael";
        case "bairc": return "Bairc";
    }
    return id;
}
// Longer in-voice journal blurb per NPC (the profile pane's lore paragraph).
function journal_npc_blurb(id) {
    switch (id) {
        case "dorn":  return "The blacksmith. Speaks in grunts and prices, but every piece he sells has outlived its last three owners. He respects people who come back from below.";
        case "sable": return "The alchemist. Cheerfully melts treasure into dust and dust into miracles. I suspect she'd salvage me if I stood still long enough.";
        case "maren": return "The runesmith. Face half-wrapped, eyes that read your gear before you speak. The runes hum differently when she touches them.";
        case "vex":   return "The trainer. Blindfolded, and still counts every mistake in my footwork. Pays out strength for coin, and doesn't flatter.";
        case "petra": return "The merchant. Knows what everything is worth, including favors. Her ledger has pages she shows no one - yet.";
        case "vael":  return "The aesthete. Needles in her hair and opinions about my silhouette. Says the way you look coming out of the dark matters more than what you carried up.";
        case "bairc": return "The creature keeper. The town keeps its distance from him; the creatures don't. He remembers every animal anyone has ever brought him.";
    }
    return "";
}
// True when this NPC counts as MET for the Journal list.
function journal_npc_met(id) {
    if (id == "bairc") return bairc_active();
    var _e = affinity_entry(id);
    return (_e != undefined) && (_e.score > 0 || _e.tier > 0);
}
// Met NPC ids in roster order (the Relationships tab's left list).
function journal_met_ids() {
    var _out = []; var _ids = affinity_npc_ids();
    for (var _i = 0; _i < array_length(_ids); _i++)
        if (journal_npc_met(_ids[_i])) array_push(_out, _ids[_i]);
    return _out;
}
// Quest ids flattened in display order: Active, then Available, then Completed
// (the Quests tab's left list; mirror this order in the draw).
function journal_quest_rows() {
    var _g = quest_groups();
    var _out = [];
    for (var _a = 0; _a < array_length(_g.active); _a++)    array_push(_out, _g.active[_a]);
    for (var _v = 0; _v < array_length(_g.available); _v++) array_push(_out, _g.available[_v]);
    for (var _d = 0; _d < array_length(_g.done); _d++)      array_push(_out, _g.done[_d]);
    return _out;
}

// Rows for the TAVERN BOARD only: active + available. Fulfilled requests come off
// the board (M 2026-07-04 - same-screen completed rows got messy); the Journal's
// Quests tab keeps the full ledger including its Completed group.
function tavern_board_rows() {
    board_bootstrap();   // first-open stock for new chars + pre-board saves
    var _g = quest_groups();
    var _out = [];
    for (var _a = 0; _a < array_length(_g.active); _a++)    array_push(_out, _g.active[_a]);
    for (var _v = 0; _v < array_length(_g.available); _v++) array_push(_out, _g.available[_v]);
    return _out;
}

// One-time stock: a board that has never generated anything (fresh character or
// pre-board save) fills to capacity the first time it is looked at. Afterwards
// the refresh clock is run-end only (board_run_end).
function board_bootstrap() {
    board_requests_ensure();
    if (global.board_seq == 0 && array_length(global.board_requests) == 0) board_refill();
}

// =============================================================================
// TAVERN BOARD REQUESTS (procedural; BOARD_REQUESTS_SPEC.md). RNG-rolled jobs
// posted alongside the authored catalog. Their definitions are GENERATED and
// therefore PERSISTED (global.board_requests + global.board_seq), unlike the
// code-authored quest_catalog(); quest_def() consults both. State rows share
// global.quests (pushed at generation, removed at retirement) so saves stay
// lean. Board size scales with the highest unlocked Awakening; requests expire
// on a run-count clock (end_run -> board_run_end). Board requests are ephemeral:
// no Journal Completed history - the notice comes down.
// =============================================================================

function board_requests_ensure() {
    if (!variable_global_exists("board_requests") || !is_array(global.board_requests)) global.board_requests = [];
    if (!variable_global_exists("board_seq")      || !is_real(global.board_seq))       global.board_seq = 0;
    if (!variable_global_exists("reforge_chits")  || !is_real(global.reforge_chits))   global.reforge_chits = 0;
    // v2: paid rerolls (cost doubles per use, resets when the board ages at run end)
    // and the rotating SPECIAL posting (every 5 runs, boosted challenge request).
    if (!variable_global_exists("board_rerolls_used")      || !is_real(global.board_rerolls_used))      global.board_rerolls_used = 0;
    if (!variable_global_exists("board_special_countdown") || !is_real(global.board_special_countdown)) global.board_special_countdown = 5;
    return global.board_requests;
}

// True for the rotating special posting (older-save defs lack the field).
function board_is_special(d) {
    return (d != undefined) && variable_struct_exists(d, "special") && d.special;
}

// v2 paid reroll: replace one POSTED (untaken) request with a fresh roll.
// 30g, doubling per use within one board age-cycle (30/60/120...).
function board_reroll_cost() {
    board_requests_ensure();
    return 30 * power(2, global.board_rerolls_used);
}
function board_reroll(id) {
    var _b = board_requests_ensure();
    var _d = board_request_def(id);
    if (_d == undefined || !quest_is_board(_d)) return "Only the board's own postings can be rerolled.";
    if (board_is_special(_d))                   return "The special posting stands - the town insists.";
    var _s = quest_state(id);
    if (_s == undefined || _s.status != "available") return "You've already taken that job - see it through or let it rot.";
    var _cost = board_reroll_cost();
    if (global.gold < _cost) return "Not enough gold - the barkeep wants " + string(_cost) + "g to re-pin the slot.";
    global.gold -= _cost;
    global.board_rerolls_used += 1;
    // Preserve the slot's urgency so the A5 always-one-urgent guarantee survives.
    var _was_urgent   = _d.urgent;
    var _old_template = _d.template;   // captured BEFORE retirement - the new roll must differ
    board_retire(id);
    var _new = board_generate_request(_was_urgent, _old_template);
    array_push(global.board_requests, _new);
    array_push(global.quests, { id:_new.id, status:"available", progress:0 });
    return "Re-pinned for " + string(_cost) + "g: \"" + _new.name + "\" - " + _new.objective
        + ". (next reroll " + string(board_reroll_cost()) + "g)";
}

// Board capacity: the town posts more work as your Awakenings prove you can take it.
function board_slot_count() {
    var _a = highest_awakening_unlocked();
    return 2 + ((_a >= 1) ? 1 : 0) + ((_a >= 3) ? 1 : 0) + ((_a >= 5) ? 1 : 0);
}

function board_request_def(id) {
    var _b = board_requests_ensure();
    for (var _i = 0; _i < array_length(_b); _i++) if (_b[_i].id == id) return _b[_i];
    return undefined;
}

function quest_is_board(d) {
    return (d != undefined) && variable_struct_exists(d, "kind") && d.kind == "board";
}

function board_has_urgent() {
    var _b = board_requests_ensure();
    for (var _i = 0; _i < array_length(_b); _i++) if (_b[_i].urgent) return true;
    return false;
}

// Remove a board request's shared state row (retirement / expiry).
function board_state_remove(id) {
    if (!variable_global_exists("quests") || !is_array(global.quests)) return;
    var _keep = [];
    for (var _i = 0; _i < array_length(global.quests); _i++)
        if (global.quests[_i].id != id) array_push(_keep, global.quests[_i]);
    global.quests = _keep;
}

// Retire a board request entirely (turn-in): def off the board, state row gone.
function board_retire(id) {
    var _b = board_requests_ensure();
    var _keep = [];
    for (var _i = 0; _i < array_length(_b); _i++) if (_b[_i].id != id) array_push(_keep, _b[_i]);
    global.board_requests = _keep;
    board_state_remove(id);
}

// Family display bits for cull requests (families = enemy_sound_family buckets).
function board_cull_families() {
    return [
        { fam:"wraith",    label:"the Restless",    kind:"wraith-kind" },
        { fam:"construct", label:"the Stoneborn",   kind:"construct" },
        { fam:"beast",     label:"the Deep Beasts", kind:"beast" },
        { fam:"fire",      label:"the Cinderkin",   kind:"fire-touched" },
        { fam:"ice",       label:"the Pale Shards", kind:"frost-touched" },
        { fam:"undead",    label:"the Hollow-born", kind:"undead" },
    ];
}

// Build one rolled request def (sans id). All numbers scale with the highest
// unlocked Awakening; see BOARD_REQUESTS_SPEC.md §4 for the tuning table.
function board_build_template(t, a, scale, urgent) {
    var _gold = 0, _dust = 0, _chit = 0;
    var _npc = "vex", _name = "", _obj_type = "", _obj_target = 1, _obj_param = "", _objective = "", _flavor = "";
    switch (t) {
        case "cull": {
            var _fams = board_cull_families();
            var _f = _fams[irandom(array_length(_fams) - 1)];
            var _n = 6 + 2 * a;
            _gold = round(60 * scale);
            var _cp = ["vex", "dorn", "sable"]; _npc = _cp[irandom(2)];
            _name = "Cull " + _f.label;
            _obj_type = "kill_family"; _obj_target = _n; _obj_param = _f.fam;
            _objective = "Slay " + string(_n) + " " + _f.kind + " foes";
            _flavor = "\"They are getting bold down there. Thin them.\"";
        } break;
        case "depth": {
            var _k = irandom(a);
            var _n = 2 + min(a, 2);
            // Urgent postings expire after ONE run and a run is 3 floors - an
            // urgent 4-floor ask is literally impossible (M hit one, 2026-07-07).
            if (urgent) _n = min(_n, 3);
            _gold = round(80 * scale); _dust = 4 + 2 * a;
            var _dp = ["petra", "vael", "maren"]; _npc = _dp[irandom(2)];
            _name = "Depth Proof";
            _obj_type = "clear_floors_at"; _obj_target = _n; _obj_param = string(_k);
            _objective = "Clear " + string(_n) + " floors" + ((_k > 0) ? (" at Awakening " + string(_k) + "+") : "")
                + ((_n > 3) ? " (progress carries between runs)" : "");   // a run is 3 floors - say so when the ask exceeds one run
            _flavor = "\"Proof of depth, on the seal's terms. The town pays for certainty.\"";
        } break;
        case "bounty": {
            var _k = irandom(a);
            var _n = 1 + irandom(1);
            _gold = round(110 * scale); _dust = 6 + 2 * a;
            var _bp = ["dorn", "petra"]; _npc = _bp[irandom(1)];
            _name = "Floor-Lord Bounty";
            _obj_type = "boss_kill_at"; _obj_target = _n; _obj_param = string(_k);
            _objective = "Slay " + string(_n) + ((_n == 1) ? " boss" : " bosses") + ((_k > 0) ? (" at Awakening " + string(_k) + "+") : "");
            _flavor = "\"The floor-lords hold what the town needs. Collect.\"";
        } break;
        case "haul": {
            var _g = 150 * (1 + a);
            _gold = round(90 * scale);
            _npc = "petra";
            _name = "A Heavy Purse";
            _obj_type = "run_haul"; _obj_target = 1; _obj_param = string(_g);
            _objective = "End a run carrying " + string(_g) + "+ gold";
            _flavor = "\"Come back rich for once. It does the town good to see it.\"";
        } break;
        case "craft": {
            var _n = 2 + min(a, 2);
            _gold = round(70 * scale); _dust = 3 + a;
            _npc = "maren";
            _name = "Settings Wanted";
            _obj_type = "socket_rune"; _obj_target = _n; _obj_param = "";
            _objective = "Socket " + string(_n) + " runes with Maren";
            _flavor = "\"Work for steady hands. The runes will know if you rush.\"";
        } break;
        case "flawless": {
            var _n = 1 + min(a, 1);
            _gold = round(80 * scale); _chit = 1;
            _npc = "vex";
            _name = "Untouched";
            _obj_type = "flawless_fight"; _obj_target = _n; _obj_param = "";
            _objective = "Win " + string(_n) + ((_n == 1) ? " fight" : " fights") + " taking no damage";
            _flavor = "\"Win without bleeding. If you can't, don't sign.\"";
        } break;
        case "swift": {
            var _tn = max(4, 7 - ceil(a / 2));
            _gold = round(90 * scale); _chit = 1;
            var _sp = ["vex", "dorn"]; _npc = _sp[irandom(1)];
            _name = "Swift Execution";
            _obj_type = "boss_swift"; _obj_target = 1; _obj_param = string(_tn);
            _objective = "Slay a boss in " + string(_tn) + " turns or fewer";
            _flavor = "\"The longer a floor-lord stands, the more it learns. Be quick.\"";
        } break;
        case "clean": {
            _gold = round(70 * scale); _chit = 1;
            _npc = "sable";
            _name = "On Your Own Feet";
            _obj_type = "clean_fight"; _obj_target = 3; _obj_param = "";
            _objective = "Win 3 fights without using consumables";
            _flavor = "\"No bottles, darling. Just you and your hands.\"";
        } break;
    }
    // Item roll: urgent always; otherwise 25% on non-challenge (non-chit) templates.
    var _item = urgent || (_chit == 0 && irandom(99) < 25);
    if (urgent) _gold *= 2;
    return {
        id:"", kind:"board", template:t, urgent:urgent, special:false, expires:(urgent ? 1 : 3),
        npc:_npc, name:_name, obj_type:_obj_type, obj_target:_obj_target, obj_param:_obj_param,
        reward:{ gold:_gold, feed:"", feed_n:0, rune_id:"", rune_tier:0, dust:_dust, item:_item, chit:_chit },
        flavor:_flavor, objective:_objective
    };
}

// v2 SPECIAL posting (every 5 runs): always a challenge template, boosted rewards
// (x1.5 gold, guaranteed item roll on top of its Reforge Chit), 2-run lifespan.
// Rides ABOVE board capacity (refill ignores it) and can't be rerolled.
function board_generate_special() {
    board_requests_ensure();
    var _a     = highest_awakening_unlocked();
    var _scale = 1 + 0.5 * _a;
    var _pool  = ["flawless", "swift", "clean"];
    var _d     = board_build_template(_pool[irandom(array_length(_pool) - 1)], _a, _scale, false);
    _d.special      = true;
    _d.expires      = 2;
    _d.reward.gold  = round(_d.reward.gold * 1.5);
    _d.reward.item  = true;
    global.board_seq += 1;
    _d.id = "board_" + string(global.board_seq);
    return _d;
}

// Roll one request, avoiding a template+param already posted (8 tries, then accept).
// avoid_template: hard-excluded from the roll pool - a REROLL must never hand back
// the template it just replaced (paying gold for the same job is self-defeating).
function board_generate_request(urgent, avoid_template = "") {
    board_requests_ensure();
    var _a     = highest_awakening_unlocked();
    var _scale = 1 + 0.5 * _a;
    var _pool  = ["cull", "cull", "depth", "bounty", "haul", "craft", "flawless", "swift", "clean"];
    if (avoid_template != "") {
        var _fpool = [];
        for (var _fi = 0; _fi < array_length(_pool); _fi++)
            if (_pool[_fi] != avoid_template) array_push(_fpool, _pool[_fi]);
        if (array_length(_fpool) > 0) _pool = _fpool;
    }
    var _def   = undefined;
    for (var _try = 0; _try < 8; _try++) {
        var _t = _pool[irandom(array_length(_pool) - 1)];
        var _cand = board_build_template(_t, _a, _scale, urgent);
        var _dupe = false;
        for (var _i = 0; _i < array_length(global.board_requests); _i++) {
            var _e = global.board_requests[_i];
            if (_e.template == _cand.template && _e.obj_param == _cand.obj_param) { _dupe = true; break; }
        }
        _def = _cand;
        if (!_dupe) break;
    }
    global.board_seq += 1;
    _def.id = "board_" + string(global.board_seq);
    return _def;
}

// Fill empty slots up to capacity. The A5 fifth slot keeps one urgent offer
// posted; from A2+ each normal refill has a 15% urgent chance. Idempotent -
// safe to call at load (older-save migration) and after retirement.
function board_refill() {
    var _b   = board_requests_ensure();
    var _a   = highest_awakening_unlocked();
    var _cap = board_slot_count();
    // The SPECIAL posting rides above capacity - don't let it starve a normal slot.
    var _normal_count = 0;
    for (var _nc = 0; _nc < array_length(_b); _nc++) if (!board_is_special(_b[_nc])) _normal_count++;
    while (_normal_count < _cap) {
        _normal_count++;
        var _urgent = false;
        // A5 guarantee: the LAST normal slot filled becomes urgent when none is posted.
        if (_a >= 5 && !board_has_urgent() && _normal_count == _cap) _urgent = true;
        else if (_a >= 2 && irandom(99) < 15) _urgent = true;
        var _d = board_generate_request(_urgent);
        array_push(_b, _d);
        array_push(global.quests, { id:_d.id, status:"available", progress:0 });
    }
}

// Run-scoped scoring, called from end_run BEFORE the expiry countdown so a
// request fulfilled by this very run doesn't rot at the same moment. Death
// forfeits run-scoped proofs (a haul needs a walk-out).
function board_run_scoring(result) {
    var _b = board_requests_ensure();
    if (result < 0) return;
    for (var _i = 0; _i < array_length(_b); _i++) {
        var _d = _b[_i];
        if (_d.obj_type == "run_haul" && global.current_run_gold >= real(_d.obj_param)) {
            quest_tick("run_haul", _d.obj_param, 1);
        }
    }
}

// Run-end lifecycle: fulfilled requests never rot; everything else counts down,
// taken or not. Expired notes come off the board (with a notice if the player
// had taken one), then the board refills to capacity.
function board_run_end() {
    var _b = board_requests_ensure();
    var _keep = [];
    for (var _i = 0; _i < array_length(_b); _i++) {
        var _d = _b[_i];
        var _s = quest_state(_d.id);
        var _fulfilled = (_s != undefined && _s.status == "active" && _s.progress >= _d.obj_target);
        if (!_fulfilled) _d.expires -= 1;
        if (_d.expires <= 0 && !_fulfilled) {
            if (_s != undefined && _s.status == "active" && variable_global_exists("pet_find_notice")) {
                var _xmsg = "The request \"" + _d.name + "\" expired - the notice came down.";
                global.pet_find_notice = (global.pet_find_notice != "") ? (global.pet_find_notice + "   " + _xmsg) : _xmsg;
            }
            board_state_remove(_d.id);
            continue;
        }
        array_push(_keep, _d);
    }
    global.board_requests = _keep;
    // v2: reroll cost ladder resets as the board ages; the SPECIAL posting lands
    // every 5th run (challenge template, boosted rewards, 2-run lifespan).
    global.board_rerolls_used = 0;
    global.board_special_countdown -= 1;
    if (global.board_special_countdown <= 0) {
        global.board_special_countdown = 5;
        // Never stack two specials (a 2-run special can straddle a 5-run boundary
        // only if countdown drift ever occurs - cheap guard).
        var _has_special = false;
        for (var _sp = 0; _sp < array_length(global.board_requests); _sp++)
            if (board_is_special(global.board_requests[_sp])) { _has_special = true; break; }
        if (!_has_special) {
            var _spd = board_generate_special();
            array_push(global.board_requests, _spd);
            array_push(global.quests, { id:_spd.id, status:"available", progress:0 });
            if (variable_global_exists("pet_find_notice")) {
                var _spmsg = "A sealed SPECIAL posting hangs on the tavern board: \"" + _spd.name + "\".";
                global.pet_find_notice = (global.pet_find_notice != "") ? (global.pet_find_notice + "   " + _spmsg) : _spmsg;
            }
        }
    }
    board_refill();
}

// =============================================================================
// PHASE 4b - GIFTS (PHASE4B_SPEC.md). One deliberate gift per run: [F] at the hub
// NPC row opens the item picker (purpose "gift") over EVERYTHING giftable - gear,
// consumables, runes, pet feed, and the 7 signature TRINKETS (rare boss drops,
// extraction-gated). Tastes are per-NPC CATEGORY tables; giving reveals the cell
// in the Journal's taste grid. Bad gifts genuinely hurt.
// =============================================================================

// Category of a giftable: "weapons" / "armor" / "jewelry" / "potions" / "runes" / "feed".
function gift_item_category(it) {
    if (!is_struct(it)) return "armor";
    var _slot = variable_struct_exists(it, "slot") ? it.slot : "";
    if (_slot == "weapon" || _slot == "ranged")  return "weapons";
    if (_slot == "ring"   || _slot == "amulet")  return "jewelry";
    return "armor";   // chest / helm / gloves / boots / offhand
}

// The 5-band taste table (spec §3, M-approved). Anything unlisted is Neutral.
function gift_taste(npc_id, cat) {
    switch (npc_id) {
        case "dorn":
            if (cat == "weapons") return "loved";
            if (cat == "armor")   return "liked";
            if (cat == "potions") return "disliked";
            if (cat == "feed")    return "hated";
            break;
        case "sable":
            if (cat == "potions") return "loved";
            if (cat == "runes")   return "liked";
            if (cat == "armor")   return "disliked";
            if (cat == "weapons") return "hated";
            break;
        case "maren":
            if (cat == "runes")   return "loved";
            if (cat == "jewelry") return "liked";
            if (cat == "potions") return "disliked";
            if (cat == "feed")    return "hated";
            break;
        case "vex":
            if (cat == "armor")   return "loved";
            if (cat == "weapons") return "liked";
            if (cat == "jewelry") return "disliked";
            if (cat == "feed")    return "hated";
            break;
        case "petra":
            if (cat == "jewelry") return "loved";
            if (cat == "weapons") return "liked";
            if (cat == "feed")    return "disliked";
            if (cat == "runes")   return "hated";
            break;
        case "vael":
            if (cat == "jewelry") return "loved";
            if (cat == "armor")   return "liked";
            if (cat == "runes")   return "disliked";
            if (cat == "feed")    return "hated";
            break;
        case "bairc":
            if (cat == "feed")    return "loved";
            if (cat == "potions") return "liked";
            if (cat == "jewelry") return "disliked";
            if (cat == "weapons") return "hated";
            break;
    }
    return "neutral";
}
function gift_band_value(band) {
    switch (band) {
        case "loved":    return 10;
        case "liked":    return 5;
        case "disliked": return -5;
        case "hated":    return -10;
    }
    return 1;   // neutral
}

// --- Signature trinkets (spec §4): rare boss drops, +25 (bypass-cap) to THEIR NPC,
// polite +1 to anyone else. Extraction-gated: found ones ride global.run_trinkets
// and only bank into global.gift_trinkets on a survived run. -----------------------
function gift_trinket_catalog() {
    return [
        { id:"meteoric_ingot",  name:"Meteoric Ingot",         npc:"dorn",  flavor:"star-metal Dorn has only ever read about" },
        { id:"grimoire_page",   name:"Sealed Grimoire Page",   npc:"sable", flavor:"a recipe in a dead alchemist's hand" },
        { id:"singing_rune",    name:"Singing Runestone",      npc:"maren", flavor:"a rune that hums, faintly off-key" },
        { id:"champion_wraps",  name:"Champion's Hand-Wraps",  npc:"vex",   flavor:"worn by someone who never lost" },
        { id:"appraisal_lens",  name:"Flawless Appraisal Lens",npc:"petra", flavor:"it shows the true price of anything" },
        { id:"duskweave_bolt",  name:"Bolt of Duskweave",      npc:"vael",  flavor:"cloth that drinks the light" },
        { id:"egg_shard",       name:"Orphaned Egg Shard",     npc:"bairc", flavor:"still warm, long after it should be" },
    ];
}
function gift_trinket_get(id) {
    var _c = gift_trinket_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}
function gift_trinkets() {   // OWNED (banked) trinket ids
    if (!variable_global_exists("gift_trinkets") || !is_array(global.gift_trinkets)) global.gift_trinkets = [];
    return global.gift_trinkets;
}
function run_trinkets() {    // found THIS run; banked or lost at end_run
    if (!variable_global_exists("run_trinkets") || !is_array(global.run_trinkets)) global.run_trinkets = [];
    return global.run_trinkets;
}
// Boss-clear roll (3%, TUNABLE): a random trinket joins the run pouch. Returns the
// catalog entry for the caller's combat-log line, or undefined.
function gift_try_boss_trinket() {
    if (irandom(99) >= 3) return undefined;
    var _c = gift_trinket_catalog();
    var _tk = _c[irandom(array_length(_c) - 1)];
    array_push(run_trinkets(), _tk.id);
    return _tk;
}

// --- Taste discovery (the Journal grid): a given gift permanently reveals that
// NPC x category cell; tiers add free hints (Acquaintance -> Loved, Friend -> Hated).
function npc_tastes_known() {
    if (!variable_global_exists("npc_tastes_known") || !is_struct(global.npc_tastes_known)) global.npc_tastes_known = {};
    return global.npc_tastes_known;
}
function gift_reveal(npc_id, cat) {
    var _k = npc_tastes_known();
    if (!variable_struct_exists(_k, npc_id)) variable_struct_set(_k, npc_id, {});
    variable_struct_set(variable_struct_get(_k, npc_id), cat, true);
}
function gift_taste_known(npc_id, cat) {
    var _k = npc_tastes_known();
    if (variable_struct_exists(_k, npc_id)
        && variable_struct_exists(variable_struct_get(_k, npc_id), cat)) return true;
    var _band = gift_taste(npc_id, cat);
    if (_band == "loved" && affinity_at_least(npc_id, 1)) return true;   // Acquaintance hint
    if (_band == "hated" && affinity_at_least(npc_id, 2)) return true;   // Friend hint
    return false;
}

// --- Reaction lines (7 NPCs x 5 bands, hand-authored) -------------------------------
function gift_reaction_line(npc_id, band) {
    switch (npc_id) {
        case "dorn": switch (band) {
            case "loved":    return "Dorn turns it over twice. \"Now THAT'S steel. I'll remember this.\"";
            case "liked":    return "\"Solid work. I can respect it.\"";
            case "neutral":  return "Dorn grunts. It disappears under the counter.";
            case "disliked": return "\"What am I meant to do with this? Drink it?\"";
            case "hated":    return "\"...is this ANIMAL FEED?\" He doesn't look up for a while.";
        } break;
        case "sable": switch (band) {
            case "loved":    return "Sable uncorks it on the spot. \"Oh, you GET me.\"";
            case "liked":    return "\"Ooh - I can melt this into something wonderful.\"";
            case "neutral":  return "\"Aw. Thoughtful-ish!\"";
            case "disliked": return "\"It's very... heavy. And metal. Thank you?\"";
            case "hated":    return "Sable holds the weapon like a dead rat. \"Why.\"";
        } break;
        case "maren": switch (band) {
            case "loved":    return "Maren goes very still. \"It sings. You heard it too, didn't you?\"";
            case "liked":    return "\"Fine settings. The stones will like living here.\"";
            case "neutral":  return "Maren nods once. High praise, probably.";
            case "disliked": return "\"I don't drink while I work. I'm always working.\"";
            case "hated":    return "Her eyes say you have made a terrible mistake.";
        } break;
        case "vex": switch (band) {
            case "loved":    return "Vex runs a thumb along the plate. \"Protect the body. You listened.\"";
            case "liked":    return "\"Balanced. Someone could do damage with this.\"";
            case "neutral":  return "\"Hm.\" He pockets it without ceremony.";
            case "disliked": return "\"Sparkle is for people who want to be seen. I don't.\"";
            case "hated":    return "\"I am BLINDFOLDED, not a stable.\"";
        } break;
        case "petra": switch (band) {
            case "loved":    return "Petra's eyes light up like a ledger balancing. \"Darling, you shouldn't have. Do it again sometime.\"";
            case "liked":    return "\"Mm, this would fetch a pretty price. Mine now.\"";
            case "neutral":  return "\"How sweet.\" It's already been appraised.";
            case "disliked": return "\"It smells like a barn, sweetheart.\"";
            case "hated":    return "\"Rocks. You brought me rocks I can't even SELL.\"";
        } break;
        case "vael": switch (band) {
            case "loved":    return "Vael drapes it against the light. \"Finally. Someone with EYES.\"";
            case "liked":    return "\"Good lines. I can work with good lines.\"";
            case "neutral":  return "\"It's... functional.\" The word costs her something.";
            case "disliked": return "\"A rock. You brought the aesthete a rock.\"";
            case "hated":    return "Vael refuses to touch it. \"Take it OUTSIDE.\"";
        } break;
        case "bairc": switch (band) {
            case "loved":    return "Bairc says nothing, but the creatures crowd the fence to watch him smile.";
            case "liked":    return "\"...they get sick, sometimes. This helps. Thank you.\"";
            case "neutral":  return "Bairc accepts it with both hands, carefully.";
            case "disliked": return "\"I have no use for shining things.\" He gives it to a magpie.";
            case "hated":    return "Bairc looks at the weapon, then at you, longer.";
        } break;
    }
    return "It is accepted.";
}
// Short ledger tag per band (the journal note beside what you gave).
function gift_band_tag(band) {
    switch (band) {
        case "loved":    return "they loved it";
        case "liked":    return "they liked it";
        case "disliked": return "they didn't care for it";
        case "hated":    return "they hated it";
    }
    return "polite thanks";
}

// --- Candidates for the gift picker: gear (stash 0 / pack 1), consumables (10),
// unsocketed runes (11), feed pouch (12, idx = pouch id string), trinkets (13, idx
// into gift_trinkets). Each carries gcat for the taste lookup. Trinkets list first.
function gift_candidates() {
    var _out = [];
    var _tks = gift_trinkets();
    for (var _t = 0; _t < array_length(_tks); _t++) {
        var _tk = gift_trinket_get(_tks[_t]);
        if (_tk != undefined) array_push(_out, { source:13, idx:_t, item:_tk, label:_tk.name + "  [Gift]", rarity:4, value:0, gcat:"trinket" });
    }
    if (variable_global_exists("pet_feed_pouch")) {
        var _fk = variable_struct_get_names(pet_feed_pouch());
        for (var _f = 0; _f < array_length(_fk); _f++) {
            if (pet_feed_pouch_count(_fk[_f]) <= 0) continue;
            var _fd = pet_feed_get(_fk[_f]);
            if (_fd != undefined) array_push(_out, { source:12, idx:0, item:_fk[_f], label:_fd.name + "  (feed)", rarity:0, value:_fd.gold, gcat:"feed" });
        }
    }
    if (variable_global_exists("consumable_inventory")) {
        for (var _c = 0; _c < array_length(global.consumable_inventory); _c++) {
            var _cn = global.consumable_inventory[_c];
            array_push(_out, { source:10, idx:_c, item:_cn, label:_cn.name + "  (potion)", rarity:0, value:variable_struct_exists(_cn, "gold_value") ? _cn.gold_value : 0, gcat:"potions" });
        }
    }
    if (variable_global_exists("rune_inventory")) {
        for (var _r = 0; _r < array_length(global.rune_inventory); _r++) {
            var _rn = global.rune_inventory[_r];
            array_push(_out, { source:11, idx:_r, item:_rn, label:_rn.name + " " + rune_tier_roman(_rn.tier) + "  (rune)", rarity:_rn.tier - 1, value:0, gcat:"runes" });
        }
    }
    for (var _s = 0; _s < 2; _s++) {
        var _arr = (_s == 0) ? global.equipment_stash : global.carried_items;
        if (!is_array(_arr)) continue;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _it = _arr[_i];
            if (!is_struct(_it)) continue;
            array_push(_out, { source:_s, idx:_i, item:_it,
                label:(variable_struct_exists(_it, "name") ? _it.name : "item"),
                rarity:variable_struct_exists(_it, "rarity") ? _it.rarity : 0,
                value:variable_struct_exists(_it, "gold_value") ? _it.gold_value : 0,
                gcat:gift_item_category(_it) });
        }
    }
    return _out;
}

// Remove a gift candidate from its source pool (the gift-purpose counterpart of
// item_picker_remove_selected, which only knows the two gear arrays).
function gift_remove_candidate(c) {
    switch (c.source) {
        case 0: case 1:
            var _arr = (c.source == 0) ? global.equipment_stash : global.carried_items;
            for (var _i = 0; _i < array_length(_arr); _i++)
                if (_arr[_i] == c.item) { array_delete(_arr, _i, 1); return true; }
            return false;
        case 10:
            for (var _j = 0; _j < array_length(global.consumable_inventory); _j++)
                if (global.consumable_inventory[_j] == c.item) { array_delete(global.consumable_inventory, _j, 1); return true; }
            return false;
        case 11:
            for (var _k = 0; _k < array_length(global.rune_inventory); _k++)
                if (global.rune_inventory[_k] == c.item) { array_delete(global.rune_inventory, _k, 1); return true; }
            return false;
        case 12:
            if (pet_feed_pouch_count(c.item) > 0) {
                variable_struct_set(pet_feed_pouch(), c.item, pet_feed_pouch_count(c.item) - 1);
                return true;
            }
            return false;
        case 13:
            var _tks = gift_trinkets();
            for (var _m = 0; _m < array_length(_tks); _m++)
                if (_tks[_m] == c.item.id) { array_delete(_tks, _m, 1); return true; }
            return false;
    }
    return false;
}

// Resolve a confirmed gift: band + delta, affinity (bad gifts always land; good ones
// ride the soft cap except a matched trinket, which bypasses like a quest chunk),
// discovery, ledger, the one-per-run latch. Returns the reaction line.
function gift_give(npc_id, c) {
    var _e = affinity_entry(npc_id);
    if (_e == undefined) return "";
    var _band, _delta;
    if (c.source == 13) {
        if (c.item.npc == npc_id) { _band = "loved"; _delta = 25; }
        else                      { _band = "neutral"; _delta = 1; }
    } else {
        _band  = gift_taste(npc_id, c.gcat);
        _delta = gift_band_value(_band);
        if (_delta > 0) _delta += max(0, c.rarity);   // rarity sweetener: +1 per tier above Common
        gift_reveal(npc_id, c.gcat);
    }
    if (_delta >= 0) {
        if (c.source == 13 && _delta > 1) {           // matched trinket: bypass the soft cap
            _e.score += _delta;
            npc_actor_play_action();
            affinity_refresh_gate(npc_id);
        } else {
            affinity_add(npc_id, _delta);
        }
    } else {
        _e.score = max(0, _e.score + _delta);         // bad gifts always hurt (no cap)
        affinity_refresh_gate(npc_id);
    }
    global.gift_given = true;
    _e.idle_clears = 0;   // 4c neglect: a gift is attention paid (even a bad one)
    ledger_add(npc_id, "gift", "Gave " + c.label + " - " + gift_band_tag(_band) + ".");
    journal_badge_npc(npc_id);
    // Result POPUP (Phase 4b UX, M): reaction + bond delta + live tier/progress.
    // Dismiss handled in obj_game_controller Step; drawn by ui_draw_gift_popup.
    global.gift_popup = { npc: npc_id, line: gift_reaction_line(npc_id, _band), delta: _delta, band: _band };
    // Gate-quest objective (4c): a Loved/Liked gift to this NPC counts.
    if (_band == "loved" || _band == "liked") quest_tick("gift_good", npc_id, 1);
    return global.gift_popup.line;
}

// Open the gift picker for the NPC whose engagement window is up (Phase 4b UX:
// gifts are given in person, not from the hub list). "" ok / reason for the
// caller's notification line.
function gift_try_open(npc_id, npc_label) {
    if (variable_global_exists("gift_given") && global.gift_given)
        return "You've already given a gift - bring another after your next run.";
    var _c = gift_candidates();
    if (array_length(_c) == 0) return "You have nothing to give.";
    item_picker_open("gift", { npc: npc_id, npc_name: npc_label }, _c);
    return "";
}

// --- Phase 4a perk read helpers (PHASE4A_SPEC.md §5, M-approved) --------------------
// Generic Friend-discount multiplier (Dorn gear / Vex upgrades 10%, Vael skins 15%).
function affinity_discount_mult(id) {
    if (!affinity_at_least(id, 2)) return 1.0;
    return (id == "vael") ? 0.85 : 0.90;
}
// Bairc Stranger early-warmth: pet-feed lines at Petra cost 10% less once he's awake.
function bairc_feed_price_mult() { return bairc_active() ? 0.90 : 1.0; }
// Bairc Friend: +1 stable capacity. (Replaces raw PET_STABLE_CAPACITY reads.)
function pet_stable_capacity() { return PET_STABLE_CAPACITY + (affinity_at_least("bairc", 2) ? 1 : 0); }
// Sable Companion: brews/upgrades cost 20% less (gold AND dust).
function sable_cost_mult() { return affinity_at_least("sable", 3) ? 0.80 : 1.0; }
// Maren: socket fee halved at Friend, waived at Companion.
function maren_fee_mult() {
    if (affinity_at_least("maren", 3)) return 0;
    if (affinity_at_least("maren", 2)) return 0.5;
    return 1.0;
}
// Vex Friend: 10% off his gold prices (applied on top of the CHA discount).
function vex_price(g) { return floor(g * affinity_discount_mult("vex")); }
// Vex Companion: a potency rank sacrifices 4 stat points instead of 5.
function vex_potency_points() { return affinity_at_least("vex", 3) ? 4 : 5; }

// =============================================================================
// PETRA TREASURE TRADER (Phase 1). Async gear-laundering: give 3 same-tier items,
// earn 1 of the next tier up by clearing floors. Builds the two SHARED primitives
// both Petra and Pets use: the floor-clear banking hook (floor_clear_credit) and the
// cross-run persistent order (global.petra_order, NOT reset in end_run, saved per
// slot). See PETRA_TT_PHASE1_SPEC.md. v1 = exact cut line (single order, Lever A
// only, no Legendary-input branch). Rarity 0..4 = Common..Legendary.
// =============================================================================

// The 4-rung trade ladder. cost_floors = floor-clears required (banked across runs);
// req_awk = each credited floor must be at/above this Awakening; gold charged at
// placement (sunk on cancel); dust = optional Lever A roll-bias cost. All TUNABLE.
function petra_ladder() {
    return [
        { in_rarity: 0, out_rarity: 1, cost_floors: 1, req_awk: 0, gold: 25,  dust: 5  },
        { in_rarity: 1, out_rarity: 2, cost_floors: 3, req_awk: 0, gold: 75,  dust: 10 },
        { in_rarity: 2, out_rarity: 3, cost_floors: 6, req_awk: 2, gold: 200, dust: 20 },
        { in_rarity: 3, out_rarity: 4, cost_floors: 6, req_awk: 3, gold: 500, dust: 40 },
    ];
}
function petra_ladder_for(in_rarity) {
    var _l = petra_ladder();
    for (var _i = 0; _i < array_length(_l); _i++) if (_l[_i].in_rarity == in_rarity) return _l[_i];
    return undefined;
}

function petra_order_active() {
    return variable_global_exists("petra_order") && is_struct(global.petra_order);
}

// --- Affinity-derived perks (read the thin-affinity API) -------------------
// Friend (>=2): -10% on Petra gold costs (trade fee + her consumable shop).
function petra_gold_mult()          { return affinity_at_least("petra", 2) ? 0.90 : 1.0; }
// Companion (>=3): faster delivery - shave 1 floor off the cost (min 1).
function petra_delivery_reduction() { return affinity_at_least("petra", 3) ? 1 : 0; }
// Cancel-recovery band [min,max] by Petra tier (Stranger..Friend 0-1, Companion 1-2, Lover 2-3).
function petra_cancel_band() {
    var _t = affinity_tier("petra");
    if (_t >= 4) return [2, 3];
    if (_t >= 3) return [1, 2];
    return [0, 1];
}

// --- Stash helpers ---------------------------------------------------------
function petra_item_value(item) {
    return (is_struct(item) && variable_struct_exists(item, "gold_value")) ? item.gold_value : 0;
}
function petra_stash_count_of_rarity(r) {
    if (!variable_global_exists("equipment_stash")) return 0;
    var _n = 0;
    for (var _i = 0; _i < array_length(global.equipment_stash); _i++) {
        var _it = global.equipment_stash[_i];
        if (is_struct(_it) && variable_struct_exists(_it, "rarity") && _it.rarity == r) _n++;
    }
    return _n;
}
// Consume specific stash items by index. Deletes high-index-first so the remaining
// target indices stay valid during removal.
function petra_consume_indices(indices) {
    var _sorted = [];
    for (var _i = 0; _i < array_length(indices); _i++) array_push(_sorted, indices[_i]);
    array_sort(_sorted, false);   // descending
    for (var _i = 0; _i < array_length(_sorted); _i++) {
        var _ix = _sorted[_i];
        if (_ix >= 0 && _ix < array_length(global.equipment_stash)) array_delete(global.equipment_stash, _ix, 1);
    }
}

// --- Output generation -----------------------------------------------------
// A "quality score" for comparing two candidate outputs (Lever A take-higher-of-two).
function petra_item_quality(item) {
    var _q = 0;
    if (is_struct(item) && variable_struct_exists(item, "affixes")) {
        for (var _i = 0; _i < array_length(item.affixes); _i++) _q += item.affixes[_i].stat_value;
        _q += array_length(item.affixes) * 0.1;   // tiebreak toward more affixes
    }
    return _q;
}
// Roll ONE item of an exact rarity with affixes (mirrors drop_equipment's non-legendary
// path, but forces the rarity - no Prospector bump, no tier drift).
function petra_roll_one(rarity) {
    var _tbl;
    if (rarity <= 0)      _tbl = global.loot_table_common;
    else if (rarity == 1) _tbl = global.loot_table_uncommon;
    else                  _tbl = global.loot_table_rare;   // rare + epic share rare bases
    var _item = clone_item(_tbl[irandom(array_length(_tbl) - 1)]);
    _item.rarity = rarity;
    var _ac = 0;
    if (rarity == 1)      _ac = 1;
    else if (rarity == 2) _ac = (irandom(1) == 0) ? 1 : 2;
    else if (rarity == 3) _ac = 2;
    if (_ac > 0) apply_affixes_to_item(_item, roll_affixes(rarity, _ac, [_item.stat_name], _item.slot, _item.base_name));
    var _be = (variable_struct_exists(_item, "elem_affix") && _item.elem_affix != undefined);
    if ((_item.slot == "weapon" || _item.slot == "ranged_weapon") && !_be) {
        apply_elemental_affix_to_item(_item, roll_elemental_affix(rarity));
    }
    return _item;
}
// Make the trade output. Legendary = a hand-authored unique. Lever A (dust_bias)
// rolls twice and keeps the higher-quality result.
function petra_make_item(rarity, dust_bias) {
    if (rarity == 4 && variable_global_exists("loot_table_legendary")
        && array_length(global.loot_table_legendary) > 0) {
        return clone_item(global.loot_table_legendary[irandom(array_length(global.loot_table_legendary) - 1)]);
    }
    var _best = petra_roll_one(rarity);
    if (dust_bias) {
        var _alt = petra_roll_one(rarity);
        if (petra_item_quality(_alt) > petra_item_quality(_best)) _best = _alt;
    }
    return _best;
}
// A clean base item of a rarity (no affixes) - what a cancel recovers.
function petra_base_item(rarity) {
    if (rarity >= 4 && variable_global_exists("loot_table_legendary") && array_length(global.loot_table_legendary) > 0) {
        return clone_item(global.loot_table_legendary[irandom(array_length(global.loot_table_legendary) - 1)]);
    }
    var _tbl;
    if (rarity <= 0)      _tbl = global.loot_table_common;
    else if (rarity == 1) _tbl = global.loot_table_uncommon;
    else                  _tbl = global.loot_table_rare;
    var _it = clone_item(_tbl[irandom(array_length(_tbl) - 1)]);
    _it.rarity = rarity;
    return _it;
}

// --- Order lifecycle: place / cancel / collect -----------------------------
// Returns "" on success, else a reason string for the UI.
// Place an order from 3 PLAYER-CHOSEN stash items (array of stash indices). Validates
// exactly-3 + all same tier. Returns "" on success else a reason string.
function petra_place_order(indices, dust_bias) {
    if (petra_order_active())        return "Collect your current order first.";
    if (array_length(indices) != 3)  return "Choose exactly 3 items.";

    var _rar = -1;
    for (var _i = 0; _i < 3; _i++) {
        var _ix = indices[_i];
        if (_ix < 0 || _ix >= array_length(global.equipment_stash)) return "Invalid selection.";
        var _it = global.equipment_stash[_ix];
        if (!is_struct(_it) || !variable_struct_exists(_it, "rarity")) return "Invalid item.";
        if (_rar == -1) _rar = _it.rarity;
        else if (_it.rarity != _rar) return "All 3 items must be the same tier.";
    }

    var _rung = petra_ladder_for(_rar);
    if (_rung == undefined) return item_rarity_name(_rar) + " items can't be traded up.";

    var _gold_cost = floor(_rung.gold * petra_gold_mult());
    var _dust_cost = dust_bias ? _rung.dust : 0;
    if (global.gold < _gold_cost) return "Need " + string(_gold_cost) + "g.";
    if (dust_bias && (!variable_global_exists("rune_dust") || global.rune_dust < _dust_cost))
        return "Need " + string(_dust_cost) + " dust for the roll-bias.";

    // Consume the chosen items + costs (gold is sunk; affixes on inputs are destroyed).
    petra_consume_indices(indices);
    global.gold -= _gold_cost;
    if (dust_bias) global.rune_dust -= _dust_cost;

    global.petra_order = {
        input_tier:      _rar,
        output_tier:     _rung.out_rarity,
        req_awakening:   _rung.req_awk,
        cost_floors:     max(1, _rung.cost_floors - petra_delivery_reduction()),
        progress_floors: 0,
        dust_bias:       dust_bias,
        status:          "in_progress",
    };
    affinity_add("petra", 4);   // placing an order is the deepest Petra interaction
    if (room == rm_hub || room == rm_character_select) save_game();
    return "";
}

function petra_cancel_order() {
    if (!petra_order_active()) return "No order to cancel.";
    var _in = global.petra_order.input_tier;
    var _band    = petra_cancel_band();
    var _recover = min(3, irandom_range(_band[0], _band[1]));
    for (var _i = 0; _i < _recover; _i++) array_push(global.equipment_stash, petra_base_item(_in));
    global.petra_order = undefined;
    if (room == rm_hub || room == rm_character_select) save_game();
    return "Order cancelled. Recovered " + string(_recover) + " item" + (_recover == 1 ? "" : "s")
        + ". (Gold not refunded.)";
}

function petra_collect() {
    if (!petra_order_active())              return "Nothing to collect.";
    if (global.petra_order.status != "ready") return "Your order isn't ready yet.";
    var _out  = global.petra_order.output_tier;
    var _bias = global.petra_order.dust_bias;
    var _item = petra_make_item(_out, _bias);
    array_push(global.equipment_stash, _item);
    discover_item(item_base_name(_item));
    global.petra_order = undefined;
    if (room == rm_hub || room == rm_character_select) save_game();
    return "Collected a " + item_rarity_name(_out) + " item: " + _item.name + "!";
}

// One-line order status for the UI.
function petra_order_status_text() {
    if (!petra_order_active()) return "No active order.";
    var _o = global.petra_order;
    if (_o.status == "ready") return "READY - a " + item_rarity_name(_o.output_tier) + " awaits collection.";
    var _awk = (_o.req_awakening > 0) ? ("   (floors must be A" + string(_o.req_awakening) + "+)") : "";
    return item_rarity_name(_o.input_tier) + " -> " + item_rarity_name(_o.output_tier)
        + "    " + string(_o.progress_floors) + " / " + string(_o.cost_floors) + " floors" + _awk
        + (_o.dust_bias ? "    [roll-biased]" : "");
}

// SHARED PRIMITIVE: credit one cleared floor toward time-gated systems. Called once
// per boss-clear (from obj_combat_controller) with the run's Awakening. Banks
// immediately so extract AND death keep already-cleared floors. Phase 2 pets hook here too.
function floor_clear_credit(awk) {
    if (petra_order_active() && global.petra_order.status == "in_progress") {
        if (awk >= global.petra_order.req_awakening) {
            global.petra_order.progress_floors += 1;
            if (global.petra_order.progress_floors >= global.petra_order.cost_floors) {
                global.petra_order.status = "ready";
            }
        }
    }
    // Tick down the exotic find-buff potions (Goldfinger / Faerie's Tear): one boss slain.
    potion_buffs_on_boss_clear();
    // Phase 4a quests: a boss-clear is one cleared floor + one boss kill.
    quest_tick("clear_floors", "", 1);
    quest_tick("boss_kill", "", 1);
    // Board depth/bounty templates (BOARD_REQUESTS_SPEC.md §5): "at Awakening >= K"
    // defs store obj_param = string(K); tick every K this run's awakening satisfies.
    for (var _bk = 0; _bk <= clamp(awk, 0, 5); _bk++) {
        quest_tick("clear_floors_at", string(_bk), 1);
        quest_tick("boss_kill_at",    string(_bk), 1);
    }
    // Phase 4c: neglect decay ticks on the same clock (6 idle floor-clears of grace).
    affinity_neglect_tick();
    // Note: pet Stage growth is banked per-RUN (at end_run via pet_run_complete), not
    // per-floor - "complete a run" is the gate (design §5), so nothing pet-Stage here.
}

// =============================================================================
// KNUCKLEBONES (expression #1, EXPRESSION_IDEAS.md). The tavern dice game,
// Cult-of-the-Lamb rules: two 3x3 boards, alternate placing a rolled d6 into one
// of your three columns; equal dice in a column MULTIPLY (each counts value x
// count); placing a die destroys all matching dice in the opponent's same
// column; first full board ends it, higher total wins. Opponent = one hub NPC
// per game (rotates with run_count), each with a placement personality. Small
// gold stakes; a win pays double and warms the NPC (+2 affinity drip).
// Opened with [K] at the Tavern Requests board (gc.kb_open / gc.kb).
// =============================================================================

function kb_new_game(foe_id) {
    return {
        foe: foe_id, stake: 25, phase: "stake",   // stake -> play -> over
        mine: [[0,0,0],[0,0,0],[0,0,0]],          // [col][slot], 0 = empty
        foes: [[0,0,0],[0,0,0],[0,0,0]],
        die: irandom(5) + 1, foe_die: 0,
        my_turn: true, cursor: 0, foe_timer: 0,
        help: false,   // rules overlay (H; auto-opens on the very first sit-down)
        result: "", msg: ""
    };
}

function kb_col_count(board, c) {
    var _n = 0;
    for (var _i = 0; _i < 3; _i++) if (board[c][_i] > 0) _n++;
    return _n;
}

// Column score: each distinct value v with n copies scores v * n * n.
function kb_col_score(board, c) {
    var _s = 0;
    for (var _v = 1; _v <= 6; _v++) {
        var _n = 0;
        for (var _i = 0; _i < 3; _i++) if (board[c][_i] == _v) _n++;
        _s += _v * _n * _n;
    }
    return _s;
}

function kb_total(board) {
    return kb_col_score(board, 0) + kb_col_score(board, 1) + kb_col_score(board, 2);
}

function kb_board_full(board) {
    for (var _c = 0; _c < 3; _c++) if (kb_col_count(board, _c) < 3) return false;
    return true;
}

function kb_place(board, c, v) {
    for (var _i = 0; _i < 3; _i++) if (board[c][_i] == 0) { board[c][_i] = v; return; }
}

// Remove every die of value v from column c, compacting survivors downward.
function kb_destroy(board, c, v) {
    var _keep = [];
    for (var _i = 0; _i < 3; _i++) if (board[c][_i] > 0 && board[c][_i] != v) array_push(_keep, board[c][_i]);
    for (var _j = 0; _j < 3; _j++) board[c][_j] = (_j < array_length(_keep)) ? _keep[_j] : 0;
}

// AI column pick. Every candidate is scored gain + wD*destroyed - wR*self-dup
// risk; the weights ARE the personality (Dorn plays safe, Vex is pure value,
// Maren hunts demolitions, Bairc fears reprisal, Vael keeps it pretty-random).
// Sable's charm-cheat happens at roll time (best of two dice), not here.
function kb_ai_pick(g) {
    var _wD = 1.0, _wR = 0.0, _jit = 0;
    switch (g.foe) {
        case "dorn":  _wD = 0.5; _wR = 1.0; break;
        case "vex":   _wD = 1.0; _wR = 0.0; break;
        case "sable": _wD = 1.0; _wR = 0.2; break;
        case "petra": _wD = 1.2; _wR = 0.0; break;
        case "maren": _wD = 2.0; _wR = 0.0; break;
        case "vael":  _wD = 0.5; _wR = 0.0; _jit = 6; break;
        case "bairc": _wD = 0.3; _wR = 1.5; break;
    }
    var _best = -1, _best_s = -99999;
    for (var _c = 0; _c < 3; _c++) {
        if (kb_col_count(g.foes, _c) >= 3) continue;
        // Simulate the placement on a COPY of the column (never touch the live board).
        var _gain = 0;
        var _sim = [g.foes[_c][0], g.foes[_c][1], g.foes[_c][2]];
        var _before2 = kb_col_score(g.foes, _c);
        for (var _i = 0; _i < 3; _i++) if (_sim[_i] == 0) { _sim[_i] = g.foe_die; break; }
        var _after2 = 0;
        for (var _v = 1; _v <= 6; _v++) {
            var _n = 0;
            for (var _k = 0; _k < 3; _k++) if (_sim[_k] == _v) _n++;
            _after2 += _v * _n * _n;
        }
        _gain = _after2 - _before2;
        // Damage done: player's dice of this value in the same column vanish.
        var _destroyed = 0, _pn = 0;
        for (var _p = 0; _p < 3; _p++) if (g.mine[_c][_p] == g.foe_die) _pn++;
        _destroyed = g.foe_die * _pn * _pn;
        // Risk: duplicates in the AI's own column invite the same demolition.
        var _dup = 0;
        for (var _d = 0; _d < 3; _d++) if (_sim[_d] == g.foe_die) _dup++;
        var _risk = (_dup >= 2) ? g.foe_die * _dup : 0;
        var _score = _gain + _wD * _destroyed - _wR * _risk + ((_jit > 0) ? irandom(_jit) : 0);
        if (_score > _best_s) { _best_s = _score; _best = _c; }
    }
    return _best;
}

// =============================================================================
// HIGH TABLE TOURNAMENT (dice expression v2, M-approved 2026-07-06): every 5th
// completed run the tavern sets the High Table. 100g buy-in, three opponents
// back-to-back; win all three for the 400g pot plus a curiosity (an unowned
// signature trinket, or +100g when the collection is complete). A tie replays
// the same opponent; a loss or concession forfeits the buy-in. The invitation
// WAITS once set - it doesn't expire, and the 5-run clock only restarts after
// the bracket is actually played.
// =============================================================================

function kb_tourney_buyin() { return 100; }
function kb_tourney_pot()   { return 400; }

function kb_tourney_ensure() {
    if (!variable_global_exists("kb_tourney_countdown") || !is_real(global.kb_tourney_countdown)) global.kb_tourney_countdown = 5;
    if (!variable_global_exists("kb_tourney_ready")) global.kb_tourney_ready = false;
}

// Run-end tick (called from end_run beside board_run_end).
function kb_tourney_run_end() {
    kb_tourney_ensure();
    if (global.kb_tourney_ready) return;   // the table stands set until someone sits
    global.kb_tourney_countdown -= 1;
    if (global.kb_tourney_countdown <= 0) {
        global.kb_tourney_countdown = 5;
        global.kb_tourney_ready = true;
        if (variable_global_exists("pet_find_notice")) {
            var _htmsg = "The HIGH TABLE is set at the tavern - three opponents, one pot. ([T] at the board)";
            global.pet_find_notice = (global.pet_find_notice != "") ? (global.pet_find_notice + "   " + _htmsg) : _htmsg;
        }
    }
}

// Three distinct opponents drawn from the table regulars.
function kb_tourney_roll_opponents() {
    var _ids = affinity_npc_ids();
    // Fisher-Yates on a copy, take the first three.
    var _pool = [];
    for (var _i = 0; _i < array_length(_ids); _i++) array_push(_pool, _ids[_i]);
    for (var _j = array_length(_pool) - 1; _j > 0; _j--) {
        var _k = irandom(_j);
        var _t = _pool[_j]; _pool[_j] = _pool[_k]; _pool[_k] = _t;
    }
    return [_pool[0], _pool[1], _pool[2]];
}

// Championship curiosity: a random UNOWNED signature trinket (banked directly -
// won at the hub, no extraction needed), or +100g if the set is complete.
// Returns the summary fragment for the victory message.
function kb_tourney_prize_roll() {
    var _cat = gift_trinket_catalog();
    var _owned = gift_trinkets();
    var _open = [];
    for (var _i = 0; _i < array_length(_cat); _i++) {
        var _own = false;
        for (var _o = 0; _o < array_length(_owned); _o++) if (_owned[_o] == _cat[_i].id) { _own = true; break; }
        if (!_own) array_push(_open, _cat[_i]);
    }
    if (array_length(_open) > 0) {
        var _pick = _open[irandom(array_length(_open) - 1)];
        array_push(gift_trinkets(), _pick.id);
        return "the " + _pick.name;
    }
    global.gold += 100;
    return "another 100g (your curiosity shelf is full)";
}

// One in-character table line per opponent (drawn under their name).
function kb_foe_line(id) {
    switch (id) {
        case "dorn":  return "Plays it like he forges - no wasted heat.";
        case "sable": return "Shuffles the dice a touch too skillfully.";
        case "maren": return "Places each die like it's being socketed.";
        case "vex":   return "Never bluffs. Never has to.";
        case "petra": return "Treats every roll like a negotiation.";
        case "vael":  return "Cares how the board LOOKS, somehow wins anyway.";
        case "bairc": return "Apologizes when he takes your dice.";
    }
    return "";
}
// See PETS_DESIGN.md. Feed/growth, evolution, the Companion Gate tab and all combat
// are LATER slices; their fields are reserved here so saves stay forward-compatible.
// Naming: PET_STAGE_AWAKENED (4) is deliberately distinct from global.awakening_level
// (difficulty) - never display them adjacent (design §10).
// =============================================================================
#macro PET_STAGE_BABY       0
#macro PET_STAGE_ADOLESCENT 1
#macro PET_STAGE_YOUNGADULT 2
#macro PET_STAGE_ADULT      3
#macro PET_STAGE_AWAKENED   4

#macro PET_ARCH_BOON      0
#macro PET_ARCH_COMBATANT 1
#macro PET_ARCH_GUARDIAN  2

function pet_archetype_name(a) {
    switch (a) {
        case PET_ARCH_BOON:      return "Fortune";
        case PET_ARCH_COMBATANT: return "Warrior";
        case PET_ARCH_GUARDIAN:  return "Guardian";
    }
    return "Unknown";
}

function pet_archetype_blurb(a) {
    switch (a) {
        case PET_ARCH_BOON:      return "Grants passive boons (gold / loot / stats). Never fights.";
        case PET_ARCH_COMBATANT: return "Takes its own turn in combat once grown. Fights beside you.";
        case PET_ARCH_GUARDIAN:  return "Passively shields and heals you in combat. Never attacks.";
    }
    return "";
}

function pet_stage_name(s) {
    switch (s) {
        case PET_STAGE_BABY:       return "Baby";
        case PET_STAGE_ADOLESCENT: return "Adolescent";
        case PET_STAGE_YOUNGADULT: return "Young Adult";
        case PET_STAGE_ADULT:      return "Adult";
        case PET_STAGE_AWAKENED:   return "Awakened";
    }
    return "?";
}

// Growth points needed to fill the bar for `stage` and become READY to evolve.
// Feed adds growth instantly; an active run adds a baseline. The bar can be FILLED by
// feed alone, but only an active-run completion CROSSES it (design §5). (TBD - playtest.)
function pet_growth_needed(stage) {
    switch (stage) {
        case PET_STAGE_BABY:       return 4;
        case PET_STAGE_ADOLESCENT: return 6;
        case PET_STAGE_YOUNGADULT: return 9;
        case PET_STAGE_ADULT:      return 12;   // -> Awakened (crossing further gated, see pet_awaken_gate_ok)
    }
    return 0;
}

// The highest stage a pet can reach. Awakened (4) shipped 2026-07-03: crossing it
// takes MORE than a full bar - see pet_awaken_gate_ok (full clear at A5, Soul-bound).
function pet_max_stage() { return PET_STAGE_AWAKENED; }

// =============================================================================
// PET COMBAT STANCES (expression #3, EXPRESSION_IDEAS.md). A per-pet behavioral
// dial for the archetypes that act in combat, set with [B] on the Gate's
// Companion tab. Stored as pet.stance (roster saves wholesale, so it persists;
// pets from older saves default to the first stance). Fortune pets have none.
//   Warrior:  aggressive (default strike) / guarded (-50% strike, 25% chance to
//             intercept 35% of blows on you) / assist (strikes YOUR target and
//             leaves it Exposed - Pack Tactics rider)
//   Guardian: balanced (heal <70% else ward) / mender (heal first) /
//             warder (ward first) / cleanser (strip your newest debuff first)
// =============================================================================

function pet_stance_list(pet) {
    if (!is_struct(pet) || pet.is_egg) return [];
    if (pet.archetype == PET_ARCH_COMBATANT) return ["aggressive", "guarded", "assist"];
    if (pet.archetype == PET_ARCH_GUARDIAN)  return ["balanced", "mender", "warder", "cleanser"];
    return [];
}

// The pet's current stance, validated against its archetype's list ("" = none).
function pet_stance(pet) {
    var _l = pet_stance_list(pet);
    if (array_length(_l) == 0) return "";
    if (!variable_struct_exists(pet, "stance") || pet.stance == "") return _l[0];
    for (var _i = 0; _i < array_length(_l); _i++) if (_l[_i] == pet.stance) return pet.stance;
    return _l[0];
}

// Cycle to the next stance; returns the new id ("" when the pet has no stances).
function pet_stance_cycle(pet) {
    var _l = pet_stance_list(pet);
    if (array_length(_l) == 0) return "";
    var _cur = pet_stance(pet);
    var _at  = 0;
    for (var _i = 0; _i < array_length(_l); _i++) if (_l[_i] == _cur) { _at = _i; break; }
    pet.stance = _l[(_at + 1) mod array_length(_l)];
    return pet.stance;
}

function pet_stance_label(id) {
    switch (id) {
        case "aggressive": return "Aggressive";
        case "guarded":    return "Guarded";
        case "assist":     return "Assist";
        case "balanced":   return "Balanced";
        case "mender":     return "Mender";
        case "warder":     return "Warder";
        case "cleanser":   return "Cleanser";
    }
    return "";
}

function pet_stance_desc(id) {
    switch (id) {
        case "aggressive": return "Strikes the weakest foe at full power.";
        case "guarded":    return "Half strike damage; 25% chance to intercept part of blows aimed at you.";
        case "assist":     return "Strikes YOUR target and leaves it Exposed (Pack Tactics).";
        case "balanced":   return "Heals you when hurt, wards you when healthy.";
        case "mender":     return "Always tends your wounds first.";
        case "warder":     return "Always raises a ward.";
        case "cleanser":   return "Strips your newest affliction before anything else.";
    }
    return "";
}

// Adult -> Awakened crossing gate (design 2026-07-03): beyond the full growth bar, the
// evolution run itself must be a FULL CLEAR (result 1) at Awakening 5 with the pet
// Soul-bound (Bond tier 3, 18 bond). Pets Awaken THROUGH the Awakening - the lore made
// mechanical. Bar-full Adults sit READY indefinitely until a qualifying run crosses them.
function pet_awaken_gate_ok(pet, result) {
    if (result != 1) return false;                                   // full clear only
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    return (_asc >= 5) && (pet_bond_tier(pet) >= 3);
}
// One-line requirement text for UI hints (Bairc feed message, run-end notice).
function pet_awaken_requirements_text() {
    return "full-clear a dungeon at Awakening A5 with it active and Soul-bound";
}

// True when the growth bar is full - the pet is READY but still needs an active run to cross.
function pet_growth_ready(pet) {
    if (!is_struct(pet) || pet.is_egg || pet.stage >= pet_max_stage()) return false;
    return pet.growth >= pet_growth_needed(pet.stage);
}

// --- FEED (design §12): feed is now BOUGHT AS ITEMS from Petra (gold) into a feed pouch,
// then APPLIED to a pet at Bairc (no gold there). 3 basic tiers are always in Petra's stock;
// one PREMIUM feed rotates each run (rolled in restock_shops) and carries a small perk. ---
// perk: "none" | "mend" (heals 1 injury tier) | "purge" (cures a pushing corruption).
function pet_feed_catalog() {   // the 3 always-stocked basics
    return [
        { id:"scraps", name:"Table Scraps",     growth:1, gold:12, perk:"none", blurb:"barely a meal, but it counts" },
        { id:"forage", name:"Forager's Bundle", growth:2, gold:30, perk:"none", blurb:"roots, grubs and dried meat" },
        { id:"prime",  name:"Prime Cut",        growth:4, gold:70, perk:"none", blurb:"the good stuff - it eats well today" },
    ];
}
// Rotating premium feeds - one is stocked per run (global.petra_feed_premium id).
function pet_feed_premium_pool() {
    return [
        { id:"mending_mash", name:"Mending Mash",  growth:3, gold:95,  perk:"mend",  blurb:"knits a wounded creature back together (heals one injury)" },
        { id:"purgeroot",    name:"Purgeroot Loaf", growth:3, gold:110, perk:"purge", blurb:"bitter root that quiets a corrupting hunger (cures a Pushing pet)" },
        { id:"hearty_roast", name:"Hearty Roast",  growth:6, gold:130, perk:"none",  blurb:"a feast - the fastest growth gold can buy" },
    ];
}
// Species-preferred feed (design §5): one hand-authored favorite per species. Hidden until
// a pet of that species reaches Bond tier 1 (Trusting), then Petra stocks it WHILE you keep
// a living (hatched) pet of the species. It is the growth ceiling - nothing feeds a creature
// faster - and no other species will touch it (species-locked in pet_feed_apply).
function pet_feed_preferred_catalog() {
    return [
        { id:"pref_luna_moth",   species:"luna_moth",   name:"Moonpetal Nectar",    growth:7, gold:100, perk:"none", blurb:"gathered at full dark - luna moths drink nothing sweeter" },
        { id:"pref_bone_stag",   species:"bone_stag",   name:"Marrowgrass Bale",    growth:7, gold:100, perk:"none", blurb:"pale grass grown on graves - bone stags graze it to the root" },
        { id:"pref_saber_hound", species:"saber_hound", name:"Blooded Haunch",      growth:7, gold:100, perk:"none", blurb:"still warm - a saber hound's eyes go wide for it" },
        { id:"pref_gloomtoad",   species:"gloomtoad",   name:"Mirefly Clutch",      growth:7, gold:100, perk:"none", blurb:"glowing eggs skimmed off the mire - a gloomtoad delicacy" },
        { id:"pref_wyrmling",    species:"wyrmling",    name:"Ember-Charred Heart", growth:7, gold:100, perk:"none", blurb:"seared black outside, red within - wyrmlings remember fire" },
        { id:"pref_nightowl",    species:"nightowl",    name:"Twilight Vole",       growth:7, gold:100, perk:"none", blurb:"caught at dusk - the only hour a nightowl deigns to hunt" },
        { id:"pref_bonehound",   species:"bonehound",   name:"Grave-Marrow Bone",   growth:7, gold:100, perk:"none", blurb:"old bone, older marrow - a bonehound gnaws it for days" },
        { id:"pref_hollow_pup",  species:"hollow_pup",  name:"Hearthmilk Sop",      growth:7, gold:100, perk:"none", blurb:"warm bread in sweet milk - it makes the hollow eyes shine" },
        // Boss-signature species (every species has a favorite - design §5).
        { id:"pref_vaultling",       species:"vaultling",       name:"Runedust Gravel",     growth:7, gold:100, perk:"none", blurb:"crushed ward-stone - it chews the glow right out of it" },
        { id:"pref_marrow_adder",    species:"marrow_adder",    name:"Gilded Knucklebones", growth:7, gold:100, perk:"none", blurb:"dice cut from a king's hand - it swallows them crown-first" },
        { id:"pref_gaolwyrm",        species:"gaolwyrm",        name:"Iron Key Shavings",   growth:7, gold:100, perk:"none", blurb:"filed from old prison locks - it gnaws the wards clean off" },
        { id:"pref_cinder_newt",     species:"cinder_newt",     name:"Smoldercoal Grubs",   growth:7, gold:100, perk:"none", blurb:"grubs roasted alive in their own shells, still smoking" },
        { id:"pref_magma_leech",     species:"magma_leech",     name:"Slagheart Ore",       growth:7, gold:100, perk:"none", blurb:"a lump of forge-slag, warm at the core - it drinks the heat" },
        { id:"pref_golemite",        species:"golemite",        name:"Emberstone Chips",    growth:7, gold:100, perk:"none", blurb:"chips of colossus stone, cracked to glowing - kin eating kin" },
        { id:"pref_rimefox",         species:"rimefox",         name:"Frostbitten Hare",    growth:7, gold:100, perk:"none", blurb:"taken by the cold mid-leap - a rimefox eats nothing warmer" },
        { id:"pref_crypt_bat",       species:"crypt_bat",       name:"Tombmoth Wings",      growth:7, gold:100, perk:"none", blurb:"dry as parchment - they crunch in the dark for hours" },
        { id:"pref_hoarfrost_drake", species:"hoarfrost_drake", name:"Glacier-Chilled Roe", growth:7, gold:100, perk:"none", blurb:"fish eggs frozen solid - it savors them one crystal at a time" },
    ];
}
// The preferred-feed def for a species (undefined if none authored).
function pet_feed_preferred_for(species_id) {
    var _c = pet_feed_preferred_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].species == species_id) return _c[_i];
    return undefined;
}

// The premium feed currently in Petra's stock (falls back to the first if unrolled).
function pet_feed_current_premium() {
    var _pool = pet_feed_premium_pool();
    if (variable_global_exists("petra_feed_premium")) {
        for (var _i = 0; _i < array_length(_pool); _i++)
            if (_pool[_i].id == global.petra_feed_premium) return _pool[_i];
    }
    return _pool[0];
}
// Icon sprite for a feed id (spr_pet_feed_<id>), or -1 if not imported yet.
function pet_feed_icon(id) {
    return asset_get_index("spr_pet_feed_" + id);
}

// Resolve any feed def by id (basics + full premium pool + species-preferred).
function pet_feed_get(id) {
    var _b = pet_feed_catalog();
    for (var _i = 0; _i < array_length(_b); _i++) if (_b[_i].id == id) return _b[_i];
    var _p = pet_feed_premium_pool();
    for (var _j = 0; _j < array_length(_p); _j++) if (_p[_j].id == id) return _p[_j];
    var _pf = pet_feed_preferred_catalog();
    for (var _k = 0; _k < array_length(_pf); _k++) if (_pf[_k].id == id) return _pf[_k];
    return undefined;
}
// The feeds Petra sells right now: 3 basics + the current rotating premium + every
// DISCOVERED species favorite whose species still has a living pet in the roster.
// (Petra's buy list is windowed, so extra rows scroll rather than overflow.)
function pet_feed_shop_list() {
    var _list = pet_feed_catalog();
    array_push(_list, pet_feed_current_premium());
    var _pc = pet_feed_preferred_catalog();
    for (var _i = 0; _i < array_length(_pc); _i++) {
        if (!pet_pref_is_discovered(_pc[_i].species)) continue;
        var _r = pet_roster(); var _own = false;
        for (var _j = 0; _j < array_length(_r); _j++)
            if (is_struct(_r[_j]) && !_r[_j].is_egg && _r[_j].species == _pc[_i].species) { _own = true; break; }
        if (_own) array_push(_list, _pc[_i]);
    }
    return _list;
}

// --- Feed pouch: owned feed items (struct keyed by feed id -> count). Persisted in save. ---
function pet_feed_pouch() {
    if (!variable_global_exists("pet_feed_pouch") || !is_struct(global.pet_feed_pouch)) global.pet_feed_pouch = {};
    return global.pet_feed_pouch;
}
function pet_feed_pouch_count(id) {
    var _p = pet_feed_pouch();
    return variable_struct_exists(_p, id) ? variable_struct_get(_p, id) : 0;
}
function pet_feed_pouch_add(id, n) {
    variable_struct_set(pet_feed_pouch(), id, pet_feed_pouch_count(id) + n);
}
function pet_feed_pouch_total() {
    var _p = pet_feed_pouch(); var _k = variable_struct_get_names(_p); var _t = 0;
    for (var _i = 0; _i < array_length(_k); _i++) _t += variable_struct_get(_p, _k[_i]);
    return _t;
}
// Feeds the player currently OWNS (count > 0), for the Bairc apply menu.
function pet_feed_owned_list() {
    var _all = pet_feed_shop_list();   // canonical order (basics then premium then favorites)
    // include any owned feed not in current shop stock (a premium bought last run, or a
    // species favorite whose last pet has since left the roster)
    var _pool = pet_feed_premium_pool();
    var _pref = pet_feed_preferred_catalog();
    for (var _pi = 0; _pi < array_length(_pref); _pi++) array_push(_pool, _pref[_pi]);
    for (var _i = 0; _i < array_length(_pool); _i++) {
        var _found = false;
        for (var _j = 0; _j < array_length(_all); _j++) if (_all[_j].id == _pool[_i].id) { _found = true; break; }
        if (!_found) array_push(_all, _pool[_i]);
    }
    var _out = [];
    for (var _k = 0; _k < array_length(_all); _k++)
        if (pet_feed_pouch_count(_all[_k].id) > 0) array_push(_out, _all[_k]);
    return _out;
}

// --- Stable soft-cap (design §6, numbers agreed 2026-07-03): Bairc comfortably keeps
// PET_STABLE_CAPACITY stabled creatures (the ACTIVE companion is exempt; eggs count).
// Past that his attention spreads thin and feed loses potency on STABLED pets only:
// 75% / 50% / 25% (floor) at +1 / +2 / +3-or-more over. Donation is the release valve -
// dropping back to capacity restores full potency. No hard cap, no gold upkeep.
#macro PET_STABLE_CAPACITY 8

function pet_stabled_count() {
    var _n = pet_count();
    if (variable_global_exists("active_pet") && global.active_pet >= 0 && global.active_pet < _n) _n -= 1;
    return _n;
}
function pet_stable_overflow() {
    return max(0, pet_stabled_count() - pet_stable_capacity());   // capacity incl. Bairc Friend perk
}
// Crowding multiplier for feed applied to THIS pet (the active companion always eats
// at 100% - it lives at your side, not in the stable).
function pet_feed_crowd_mult(pet) {
    if (is_struct(pet) && pet_active() == pet) return 1.0;
    if (affinity_at_least("bairc", 4)) return 1.0;   // Lover perk: his full attention - crowding never bites
    switch (pet_stable_overflow()) {
        case 0: return 1.0;
        case 1: return 0.75;
        case 2: return 0.5;
    }
    return 0.25;
}
// The growth a feed item would actually grant this pet right now (min 1 - never wasted).
function pet_feed_effective_growth(pet, f) {
    return max(1, round(f.growth * pet_feed_crowd_mult(pet)));
}

// Apply an owned feed (by id) to a pet - spends one from the pouch (no gold). Fills growth
// toward (clamped at) the next-stage threshold; feed makes a pet READY but never crosses on
// its own. Premium perks fire here; crowding (soft cap above) shrinks the growth granted.
// Returns "" on success, else an error message.
function pet_feed_apply(pet, feed_id) {
    if (!is_struct(pet) || pet.is_egg)   return "An egg can't be fed - hatch it first.";
    if (pet.stage >= pet_max_stage())     return pet.name + " is fully grown.";
    if (pet_growth_ready(pet)) {
        // Adults need the Awakened gate, not just any run - say so at the feed trough.
        if (pet.stage == PET_STAGE_ADULT)
            return pet.name + "'s growth is FULL - to Awaken it, " + pet_awaken_requirements_text() + ".";
        return pet.name + "'s growth is FULL - feed can't help further. Complete a run with it active to evolve.";
    }
    var _f = pet_feed_get(feed_id);
    if (_f == undefined)                  return "";
    if (pet_feed_pouch_count(feed_id) <= 0) return "You have no " + _f.name + " - buy some from Petra.";
    // Species favorites are exactly that - no other creature will touch them.
    if (variable_struct_exists(_f, "species") && _f.species != pet.species)
        return "Only a " + pet_species_get(_f.species).name + " will eat that.";
    variable_struct_set(pet_feed_pouch(), feed_id, pet_feed_pouch_count(feed_id) - 1);
    var _need  = pet_growth_needed(pet.stage);
    pet.growth = min(_need, pet.growth + pet_feed_effective_growth(pet, _f));
    // Premium perk.
    if (_f.perk == "mend" && pet.injured > 0) {
        pet.injured = max(0, pet.injured - 1);
    } else if (_f.perk == "purge" && pet_corr_state(pet) == "pushing") {
        pet_corruption_cure(pet);
    }
    return "";
}

// The full ordered Petra BUY list, shared by the input handler and the draw so their row
// indices never drift: 4 standard consumables, an optional limited special, then the pet
// feeds (3 basics + rotating premium). Each entry: {kind:"consum"/"feed", it, price, special}.
function petra_buy_list() {
    var _list = [];
    for (var _i = 0; _i < 4; _i++) {
        var _c = global.consumables_standard[_i];
        array_push(_list, { kind:"consum", it:_c, price:cha_price(floor(_c.gold_value * 1.5)), special:false });
    }
    if (global.petra_stock_special != undefined && global.petra_special_qty > 0) {
        var _s = global.petra_stock_special;
        array_push(_list, { kind:"consum", it:_s, price:cha_price(floor(_s.gold_value * 2)), special:true });
    }
    var _feeds = pet_feed_shop_list();
    for (var _f = 0; _f < array_length(_feeds); _f++) {
        var _fd = _feeds[_f];
        // Bairc Stranger perk (early warmth): feed costs 10% less once he's awake.
        array_push(_list, { kind:"feed", it:_fd, price:floor(cha_price(_fd.gold) * bairc_feed_price_mult()), special:false });
    }
    return _list;
}

// Run completion advances the ACTIVE pet's growth and CROSSES a full bar (the gate that
// feed alone can't open, design §5). result: 1 clear / 0 extract / -1 death. Clear gives
// the most baseline, extract less, death none. Returns the pet if it EVOLVED, else undefined.
function pet_run_complete(result) {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return undefined;
    var _gain = (result == 1) ? 2 : ((result == 0) ? 1 : 0);   // clear / extract / death
    if (_gain <= 0) return undefined;                          // a death banks no growth (or bond)
    // Bond banks the same raw amount (before egg boosts) and keeps rising after Adult -
    // §5 Axis 3. Milestone crossings surface on the next hub visit like evolutions do.
    var _bond_msg = pet_bond_gain(_p, _gain);
    if (_bond_msg != "" && variable_global_exists("pet_find_notice")) {
        global.pet_find_notice = (global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _bond_msg) : _bond_msg;
    }
    if (_p.stage >= pet_max_stage()) return undefined;         // fully grown: bond only
    _gain += pet_active_egg_bonus("growth");                   // Ley egg: matures faster
    _p.growth += _gain;
    if (_p.growth >= pet_growth_needed(_p.stage)) {
        // Adult -> Awakened is harder than a full bar: the crossing run must ALSO pass
        // pet_awaken_gate_ok (full clear @ A5, Soul-bound). Hold at READY and say why.
        if (_p.stage == PET_STAGE_ADULT && !pet_awaken_gate_ok(_p, result)) {
            _p.growth = pet_growth_needed(_p.stage);
            if (variable_global_exists("pet_find_notice")) {
                var _gate_msg = _p.name + " strains toward its final form - "
                    + pet_awaken_requirements_text() + " to Awaken it.";
                global.pet_find_notice = (global.pet_find_notice != "")
                    ? (global.pet_find_notice + "   " + _gate_msg) : _gate_msg;
            }
            return undefined;
        }
        _p.stage += 1;
        _p.growth = 0;
        if (_p.stage == PET_STAGE_ADULT) {
            // Raised pets CHOOSE their capstone at Bairc (flagged pending, no effect until
            // picked); found/wild creatures auto-roll one on the spot. See pet_capstone_*.
            if (_p.raised) _p.capstone_pending = true;
            else           pet_assign_capstone(_p);
        }
        if (_p.stage == PET_STAGE_AWAKENED) {
            // Same pick/roll split for the Awakened SPLASH (one off-archetype effect).
            if (_p.raised) _p.splash_pending = true;
            else           pet_assign_splash(_p);
        }
        quest_tick("pet_stage", "", _p.stage);                 // Phase 4a quest objective
        return _p;                                             // evolved this run
    }
    return undefined;
}

// 3-STAGE authored art (redesigned creature species): each species has baby, youngadult
// and adult frames (+ egg). Adolescent reuses the baby frame slightly enlarged; awakened
// reuses the adult frame. So growth reads across 4 stages with 3 authored frames/species.
// pet_sprite_key(pet) -> "egg" | "baby" | "youngadult" | "adult" for the frame to draw.
function pet_sprite_key(pet) {
    if (!is_struct(pet) || pet.is_egg) return "egg";
    if (pet.stage >= PET_STAGE_ADULT)      return "adult";        // adult (3) + awakened (4)
    if (pet.stage >= PET_STAGE_YOUNGADULT) return "youngadult";   // young adult (2)
    return "baby";                                                 // baby (0) + adolescent (1)
}

// Subtle scale multiplier that sells the adolescent in-between on the reused baby frame.
// (Young adult and adult now have their own authored frames, so they sit at true size.)
function pet_stage_scale(pet) {
    if (!is_struct(pet) || pet.is_egg) return 1.0;
    switch (pet.stage) {
        case PET_STAGE_BABY:       return 1.00;   // baby frame, true size
        case PET_STAGE_ADOLESCENT: return 1.25;   // baby frame, larger
        case PET_STAGE_YOUNGADULT: return 1.00;   // young-adult frame, own art
        case PET_STAGE_ADULT:      return 1.00;   // adult frame, full size
    }
    return 1.0;
}

// Resolve a pet's display sprite index (newest-art-wins, graceful fallback so the loop
// works before art exists): species key frame (spr_pet_<species>_<key>) -> species base
// (spr_pet_<species>) -> shared egg (spr_pet_egg) -> -1 (caller draws a placeholder).
// NOTE: when pet art is imported, these string-only refs MUST be added to
// global.__sprite_includes or the compiler strips them (see dungeon_bg_sprite note).
// dir: facing key for directional art - "s" (south, the default the station shows) or
// "e" (east, the combat-facing). Resolution prefers the directional animated sprite,
// then south, then the current no-direction static sprite, so single-frame art keeps
// working until the animated south/east frames are imported. (8-dir + idle-anim convention)
function pet_sprite(pet, dir = "s") {
    if (!is_struct(pet)) return -1;
    var _key  = pet_sprite_key(pet);
    var _base = "spr_pet_" + pet.species + "_" + _key;
    var _cands = [_base + "_" + dir, _base + "_s", _base];   // directional -> south -> legacy static
    for (var _i = 0; _i < array_length(_cands); _i++) {
        var _a = asset_get_index(_cands[_i]);
        if (_a >= 0) return _a;
    }
    // Requested key not authored yet -> walk down to the nearest older frame that exists
    // (adult -> youngadult -> baby), so a legacy species missing a middle frame still draws.
    var _fallbacks = [];
    if (_key == "adult")           _fallbacks = ["youngadult", "baby"];
    else if (_key == "youngadult") _fallbacks = ["adult", "baby"];   // prefer older look, else adult
    for (var _f = 0; _f < array_length(_fallbacks); _f++) {
        var _kbase = "spr_pet_" + pet.species + "_" + _fallbacks[_f];
        var _cb = [_kbase + "_" + dir, _kbase + "_s", _kbase];
        for (var _j = 0; _j < array_length(_cb); _j++) {
            var _ab = asset_get_index(_cb[_j]);
            if (_ab >= 0) return _ab;
        }
    }
    if (pet.is_egg) {
        // Prefer the typed egg art over the shared egg; borrow a close typed egg for any
        // expansion type whose own art hasn't been imported yet (never spoil the species).
        if (variable_struct_exists(pet, "egg_type") && pet.egg_type != "") {
            var _te = asset_get_index("spr_pet_egg_" + pet.egg_type);
            if (_te >= 0) return _te;
            var _fb = pet_egg_art_fallback(pet.egg_type);
            if (_fb != "") {
                var _fbi = asset_get_index("spr_pet_egg_" + _fb);
                if (_fbi >= 0) return _fbi;
            }
        }
        var _eg = asset_get_index("spr_pet_egg");
        if (_eg >= 0) return _eg;
    }
    return asset_get_index("spr_pet_" + pet.species);
}

// Current looping idle frame for a sprite, derived from the global clock so the station
// (and later combat) can play a multi-frame idle without an owning instance. Single-frame
// sprites return 0, so this is safe before animated art exists. ~8 fps loop.
function pet_anim_frame(spr) {
    if (spr < 0) return 0;
    var _n = sprite_get_number(spr);
    if (_n <= 1) return 0;
    return (current_time div 120) mod _n;
}

// --- Boon archetype passives (Pets Phase 3) ----------------------------------
// Only a BOON-archetype active pet grants these economy boons, and only once grown
// (design §4: Baby none, Adolescent 1 minor boon, Young Adult a 2nd, Adult strong).
// gold = outgoing multiplier %, loot = extra equipment-drop percentage POINTS (matches
// the Faerie's Tear unit). 0 for non-boon / egg / baby. (Values TBD - balance pass.)
function pet_boon_gold_pct_for(stage) {
    switch (stage) {
        case PET_STAGE_ADOLESCENT: return 0.05;
        case PET_STAGE_YOUNGADULT: return 0.08;
        case PET_STAGE_ADULT:      return 0.12;
        case PET_STAGE_AWAKENED:   return 0.15;   // final rung (TBD - balance)
    }
    return 0;
}
function pet_boon_loot_pts_for(stage) {
    switch (stage) {
        case PET_STAGE_YOUNGADULT: return 3;   // the 2nd boon unlocks at Young Adult
        case PET_STAGE_ADULT:      return 5;
        case PET_STAGE_AWAKENED:   return 6;   // final rung (TBD - balance)
    }
    return 0;
}
function pet_active_boon_gold_pct() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || _p.archetype != PET_ARCH_BOON) return 0;
    var _base = pet_boon_gold_pct_for(_p.stage) + pet_kit_mods(_p).gold;   // base + named kit (prospector/windfall)
    var _v = _base * pet_injury_mult(_p.injured) * pet_corruption_mult(_p) * pet_stat_mult(_p, "lck") * pet_bond_mult(_p);   // LCK stat + Soul-bound
    if (pet_is_fulfilled(_p)) _v += 0.05;   // grand boon: a big second helping of gold
    return _v;
}
function pet_active_boon_loot_pts() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || _p.archetype != PET_ARCH_BOON) return 0;
    var _base = pet_boon_loot_pts_for(_p.stage) + pet_kit_mods(_p).loot;   // base + named kit (lucky/treasure sense)
    var _v = _base * pet_injury_mult(_p.injured) * pet_corruption_mult(_p) * pet_stat_mult(_p, "lck") * pet_bond_mult(_p);   // LCK stat + Soul-bound
    if (pet_is_fulfilled(_p)) _v += 3;       // grand boon: extra loot find
    return round(_v);
}

// --- Pet stats (Pets §5): three weak, archetype-tied stats that modestly modify their
// matching ability's effectiveness. Derived from archetype + stage + a stable per-creature
// "talent" (0..2, hashed from uid) so NO new saved fields are needed and old pets Just Work.
//   PWR -> Combatant strike damage   SPR -> Guardian heal/shield   LCK -> Boon gold/loot
#macro PET_STAT_COEFF 0.03   // effectiveness gain per stat point (very weak, TBD-balance)

// The archetype's primary (governing) stat key.
function pet_stat_primary(archetype) {
    switch (archetype) {
        case PET_ARCH_COMBATANT: return "pow";
        case PET_ARCH_GUARDIAN:  return "spr";
        case PET_ARCH_BOON:      return "lck";
    }
    return "";
}
// Stable 0..2 talent offset per (creature, stat), hashed from the creature's uid so every
// creature differs a little without storing anything.
function pet_stat_talent(pet, which) {
    var _u = (is_struct(pet) && variable_struct_exists(pet, "uid")) ? pet.uid : 0;
    var _k = (which == "pow") ? 1 : ((which == "spr") ? 2 : 3);
    return ((_u * 31 + _k * 7) mod 3);
}
// A creature's current value for a stat (weak; primary grows +1/stage, secondaries +1 per 2).
// A Devoted bond (tier 2) adds +1 to the governing stat - loyalty made numeric.
// SIGNATURE pets (boss eggs) add +1 per 2 Awakening at acquisition to the governing stat
// (ceil: +1 at A1-2, +2 at A3-4, +3 at A5) - the §3.1 Awakening-scaled ceiling.
// The point-source breakdown is its own function (the stat hover tooltip itemises it);
// pet_stat just sums it so the two can never disagree.
function pet_stat_breakdown(pet, which) {
    var _bd = { base:0, stage:0, talent:0, bond:0, signature:0 };
    if (!is_struct(pet)) return _bd;
    var _stage  = pet.is_egg ? 0 : pet.stage;
    var _is_pri = (which == pet_stat_primary(pet.archetype));
    _bd.base   = _is_pri ? 3 : 1;
    _bd.stage  = _is_pri ? _stage : (_stage div 2);
    _bd.talent = pet_stat_talent(pet, which);
    if (_is_pri && pet_bond_tier(pet) >= 2) _bd.bond = 1;   // Devoted bond bonus
    if (_is_pri && pet_is_signature(pet)) {
        var _awk = variable_struct_exists(pet, "awk_at_acquire") ? pet.awk_at_acquire : 0;
        _bd.signature = ceil(_awk / 2);
    }
    return _bd;
}
function pet_stat(pet, which) {
    if (!is_struct(pet)) return 0;
    var _bd = pet_stat_breakdown(pet, which);
    return _bd.base + _bd.stage + _bd.talent + _bd.bond + _bd.signature;
}
// The effectiveness multiplier a stat grants (1.0 for eggs).
function pet_stat_mult(pet, which) {
    if (!is_struct(pet) || pet.is_egg) return 1.0;
    return 1.0 + pet_stat(pet, which) * PET_STAT_COEFF;
}
// Active creature's stat multiplier (1.0 if none / egg).
function pet_active_stat_mult(which) {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 1.0;
    return pet_stat_mult(_p, which);
}
function pet_stat_name(which) {
    switch (which) { case "pow": return "PWR"; case "spr": return "SPR"; case "lck": return "LCK"; }
    return "";
}

// --- UNIVERSAL stat roles (2026-07-03 rework): every stat matters on every creature,
// on top of the governing stat's type-gift scaling. Agreed numbers:
//   PWR - presence: the player takes -0.5%/pt damage while it is active (cap 8%).
//   SPR - hardy spirit: 5%/pt chance to resist gaining an injury tier (cap 50%).
//   LCK - fortune: +0.5%/pt gold and +0.3/pt loot find for ANY active creature.
function pet_active_pwr_guard() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    return min(0.08, pet_stat(_p, "pow") * 0.005);
}
function pet_spr_injury_resist(pet) {
    if (!is_struct(pet) || pet.is_egg) return 0;
    return min(50, pet_stat(pet, "spr") * 5);
}
function pet_active_lck_gold_pct() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    return pet_stat(_p, "lck") * 0.005;
}
function pet_active_lck_loot_pts() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    return pet_stat(_p, "lck") * 0.3;
}

// --- Bond / Loyalty (Pets §5 Axis 3): rises from carrying a pet ACTIVE through survived
// runs (clear +2 / extract +1, mirroring banked growth; a death banks nothing). Unlike
// growth it keeps rising after Adult, so a finished pet still deepens. Milestones pay off
// in discovery + a little power; all thresholds live in one catalog for tuning. ---------
function pet_bond(pet) {
    return (is_struct(pet) && variable_struct_exists(pet, "bond")) ? pet.bond : 0;
}
function pet_bond_milestones() {
    return [
        { at:4,  name:"Trusting"   },   // reveals the species' preferred feed (Petra stocks it)
        { at:10, name:"Devoted"    },   // +1 governing stat
        { at:18, name:"Soul-bound" },   // +5% to everything it does
    ];
}
// Bond tier 0..3 ("Wary" -> Trusting -> Devoted -> Soul-bound).
function pet_bond_tier(pet) {
    var _b = pet_bond(pet), _m = pet_bond_milestones(), _t = 0;
    for (var _i = 0; _i < array_length(_m); _i++) if (_b >= _m[_i].at) _t = _i + 1;
    return _t;
}
function pet_bond_tier_name(tier) {
    var _m = pet_bond_milestones();
    return (tier >= 1 && tier <= array_length(_m)) ? _m[tier - 1].name : "Wary";
}
// Bond needed for the NEXT tier, or -1 once Soul-bound (for the station's progress line).
function pet_bond_next_at(pet) {
    var _t = pet_bond_tier(pet), _m = pet_bond_milestones();
    return (_t >= array_length(_m)) ? -1 : _m[_t].at;
}
// Soul-bound: a +5% effectiveness multiplier on everything the pet does, applied at the
// same sites as injury/corruption mults (boon gold/loot + combat act amounts).
function pet_bond_mult(pet) { return (pet_bond_tier(pet) >= 3) ? 1.05 : 1.0; }

// Bank bond after a survived run and fire milestone payoffs. Returns a notice string when
// a milestone was crossed ("" otherwise). Tier-1 reveals the species' preferred feed;
// lore fragments queue for Bairc's next audience (sparse, one-time - design §10).
function pet_bond_gain(pet, amount) {
    if (!is_struct(pet) || pet.is_egg || amount <= 0) return "";
    var _t0 = pet_bond_tier(pet);
    pet.bond = pet_bond(pet) + amount;
    var _t1 = pet_bond_tier(pet);
    if (_t1 <= _t0) return "";
    var _msg = pet.name + "'s bond deepens - " + pet_bond_tier_name(_t1) + ".";
    if (_t1 >= 1 && _t0 < 1) {
        pet_pref_discover(pet.species);
        _msg += "  Petra now knows what it loves to eat.";
        bairc_lore_unlock("first_trusting");
    }
    if (_t1 >= 2 && _t0 < 2) { _msg += "  (+1 " + pet_stat_name(pet_stat_primary(pet.archetype)) + ")"; bairc_lore_unlock("first_devoted"); }
    if (_t1 >= 3 && _t0 < 3) { _msg += "  (+5% to all it does)"; bairc_lore_unlock("first_soulbound"); }
    return _msg;
}

// --- Preferred-feed discovery ledger (per SPECIES, not per pet): set at Bond tier 1,
// persisted in the save. Petra stocks a discovered species' favorite while you keep a
// living pet of that species. ---------------------------------------------------------
function pet_pref_discovered() {
    if (!variable_global_exists("pet_pref_discovered") || !is_struct(global.pet_pref_discovered)) global.pet_pref_discovered = {};
    return global.pet_pref_discovered;
}
function pet_pref_is_discovered(species_id) { return variable_struct_exists(pet_pref_discovered(), species_id); }
function pet_pref_discover(species_id)      { variable_struct_set(pet_pref_discovered(), species_id, true); }

// --- Bairc lore fragments (design §10): the past-lives reveal, surfaced one line at a
// time through Bairc when bond/donation firsts happen. Each key fires ONCE ever; queued
// lines show as his portrait dialogue the next time his garden is visited. -------------
function bairc_lore_lines() {
    return {
        first_trusting:  "It follows you without being asked now.\n\n...It did that for someone before, I think.",
        first_devoted:   "The way it watches you. I have seen that look before - in another life.\n\nSo has it.",
        first_soulbound: "Some bonds outlast the grave, stranger.\n\nThis one already has.",
        first_donation:  "I will watch over this one.\n\n...They all find their way back to my garden, in the end.",
    };
}
function bairc_lore_queue() {
    if (!variable_global_exists("bairc_lore_queue") || !is_array(global.bairc_lore_queue)) global.bairc_lore_queue = [];
    return global.bairc_lore_queue;
}
function bairc_lore_unlock(key) {
    if (!variable_global_exists("bairc_lore_seen") || !is_struct(global.bairc_lore_seen)) global.bairc_lore_seen = {};
    if (variable_struct_exists(global.bairc_lore_seen, key)) return;   // one-time, ever
    variable_struct_set(global.bairc_lore_seen, key, true);
    array_push(bairc_lore_queue(), key);
}

// One-line summary of what a pet grants at its current stage (for the station/HUD).
function pet_effect_text(pet) {
    if (!is_struct(pet) || pet.is_egg) return "";
    if (pet.injured >= 2) return "Injured - too hurt to act. Survive a run with it to heal.";
    if (pet.injured == 1) return "Injured (weakened). " + pet_effect_text_base(pet);
    return pet_effect_text_base(pet);
}
function pet_effect_text_base(pet) {
    switch (pet.archetype) {
        case PET_ARCH_BOON:
            var _lm = pet_stat_mult(pet, "lck");   // LCK modifies gold/loot
            var _g = round(pet_boon_gold_pct_for(pet.stage) * 100 * _lm);
            var _l = round(pet_boon_loot_pts_for(pet.stage) * _lm);
            if (_g <= 0 && _l <= 0) return "Too young to grant its gift yet.";
            var _s = "Fortune: ";
            if (_g > 0) _s += "+" + string(_g) + "% gold";
            if (_l > 0) _s += (_g > 0 ? ", " : "") + "+" + string(_l) + "% loot find";
            return _s;
        case PET_ARCH_COMBATANT:
            if (pet.stage < PET_STAGE_YOUNGADULT) return "Warrior: too young to fight (acts from Young Adult).";
            return "Warrior: strikes an enemy each turn for " + string(round((pet.stage >= PET_STAGE_ADULT ? 16 : 8) * pet_stat_mult(pet, "pow"))) + ".";
        case PET_ARCH_GUARDIAN:
            if (pet.stage < PET_STAGE_YOUNGADULT) return "Guardian: too young to protect (acts from Young Adult).";
            var _sm = pet_stat_mult(pet, "spr");   // SPR modifies heal/shield
            return "Guardian: each turn heals " + string(round((pet.stage >= PET_STAGE_ADULT ? 10 : 5) * _sm))
                 + " (if hurt) or shields " + string(round((pet.stage >= PET_STAGE_ADULT ? 12 : 7) * _sm)) + ".";
    }
    return "";
}

// Body text for the tagged-block UI: the archetype pill IS the tag, so the body drops
// the "Fortune:/Warrior:/Guardian:" prefix pet_effect_text bakes in (found mid-string too,
// so the injured variants stay intact).
function pet_effect_body(pet) {
    var _t = pet_effect_text(pet);
    var _prefixes = ["Fortune: ", "Warrior: ", "Guardian: "];
    for (var _i = 0; _i < array_length(_prefixes); _i++) {
        var _pp = string_pos(_prefixes[_i], _t);
        if (_pp > 0) _t = string_delete(_t, _pp, string_length(_prefixes[_i]));
    }
    return _t;
}

// --- Creature profile builders (Pets §5) --------------------------------------
// One-line egg-type passive descriptor for a hatched creature ("" if none). The egg boon
// is carried by the hatchling while it is your active companion.
function pet_egg_passive_text(pet) {
    if (!is_struct(pet) || pet.is_egg) return "";
    if (!variable_struct_exists(pet, "egg_type") || pet.egg_type == "") return "";
    var _et = pet_egg_type_get(pet.egg_type);
    return (_et == undefined) ? "" : _et.desc;
}

// PASSIVES / TRAITS list for the profile sheet: the egg-type boon, the archetype's economy
// boon (Boon pets - it is a standing passive, not an action), and every unlocked kit TRAIT.
// Each entry is { name, desc }. Empty for eggs.
function pet_passive_list(pet) {
    var _out = [];
    if (!is_struct(pet) || pet.is_egg) return _out;
    // Egg-type passive (kept after hatch).
    if (variable_struct_exists(pet, "egg_type") && pet.egg_type != "") {
        var _et = pet_egg_type_get(pet.egg_type);
        if (_et != undefined) array_push(_out, { name: _et.name + "  (egg gift)", desc: _et.desc });
    }
    // Boon archetype: the gold/loot boon is a passive (LCK-modified).
    if (pet.archetype == PET_ARCH_BOON) {
        var _lm = pet_stat_mult(pet, "lck");
        var _g = round(pet_boon_gold_pct_for(pet.stage) * 100 * _lm);
        var _l = round(pet_boon_loot_pts_for(pet.stage) * _lm);
        if (_g > 0 || _l > 0) {
            var _bd = "";
            if (_g > 0) _bd += "+" + string(_g) + "% gold";
            if (_l > 0) _bd += (_g > 0 ? ", " : "") + "+" + string(_l) + "% loot find";
            array_push(_out, { name: "Fortune's Favor", desc: _bd + " while it is your active companion." });
        }
    }
    // Kit traits (stage-gated).
    var _kit = pet_kit(pet);
    for (var _i = 0; _i < array_length(_kit); _i++)
        if (_kit[_i].kind == "Trait") array_push(_out, { name: _kit[_i].name, desc: _kit[_i].desc });
    return _out;
}

// ABILITIES list for the profile sheet: the archetype's per-turn combat action
// (Combatant / Guardian) plus every unlocked kit ABILITY (Stage-3 capstone). Boon pets have
// no combat action - their power is the passive above. Each entry { name, desc }.
function pet_ability_list(pet) {
    var _out = [];
    if (!is_struct(pet) || pet.is_egg) return _out;
    if (pet.archetype == PET_ARCH_COMBATANT) {
        var _cd  = round((pet.stage >= PET_STAGE_ADULT) ? 16 : 8) * pet_stat_mult(pet, "pow");   // mirrors combat_pet_act
        _cd = round(_cd);
        var _ct  = (pet.stage < PET_STAGE_YOUNGADULT)
            ? "Strikes an enemy each turn once it reaches Young Adult."
            : "Strikes the weakest living enemy each turn for " + string(_cd) + " damage.";
        array_push(_out, { name: "Strike", desc: _ct });
    } else if (pet.archetype == PET_ARCH_GUARDIAN) {
        var _sm = pet_stat_mult(pet, "spr");
        var _gh = round(((pet.stage >= PET_STAGE_ADULT) ? 10 : 5) * _sm);
        var _gs = round(((pet.stage >= PET_STAGE_ADULT) ? 12 : 7) * _sm);
        var _gt = (pet.stage < PET_STAGE_YOUNGADULT)
            ? "Guards you each turn once it reaches Young Adult."
            : "Each turn heals you " + string(_gh) + " (when hurt) or raises a " + string(_gs) + "-point shield.";
        array_push(_out, { name: "Guard", desc: _gt });
    }
    var _kit = pet_kit(pet);
    for (var _i = 0; _i < array_length(_kit); _i++)
        if (_kit[_i].kind == "Ability") array_push(_out, { name: _kit[_i].name, desc: _kit[_i].desc });
    return _out;
}

// --- Injury ladder & permadeath (Pets Phase 3, §8) ----------------------------
// Dying while CARRYING a pet injures THAT pet (M's scope). Injuries stack across deaths
// and WEAKEN the pet (worse each tier) until it stops acting, then permadeath at the top.
// A successful extract/clear with the pet active heals it back to full. (Threshold: M's
// "moderate".) injured tier 0 = healthy.
#macro PET_INJURY_DEATH 3   // injured >= this -> the pet is permanently lost

// Effectiveness multiplier for an injury tier: tier 1 weakened, tier 2 can't act.
function pet_injury_mult(tier) {
    if (tier <= 0) return 1.0;
    if (tier == 1) return 0.6;
    return 0.0;             // tier 2+ : injured too badly to act
}
function pet_active_injury_mult() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 1.0;
    return pet_injury_mult(_p.injured);
}

// Resolve the active pet's fate at run end. result: 1 clear / 0 extract / -1 death.
// Returns a one-line notice (injured / lost / recovered) for the hub, or "".
function pet_on_run_end(result) {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return "";
    if (result == -1) {
        // Universal SPR role: hardy spirit - a chance to shrug the injury off entirely.
        if (irandom(99) < pet_spr_injury_resist(_p))
            return _p.name + " shrugged off the fall, unharmed (hardy spirit).";
        _p.injured += 1;
        if (_p.injured >= PET_INJURY_DEATH) {
            var _lost = _p.name;
            array_delete(global.pet_roster, global.active_pet, 1);   // the carried pet is the active one
            global.active_pet = -1;
            return _lost + " succumbed to its injuries and is lost.";
        }
        return _p.name + " was hurt by your fall (injury " + string(_p.injured) + "/" + string(PET_INJURY_DEATH) + ").";
    }
    // Survived: the carried pet recovers fully.
    if (_p.injured > 0) { _p.injured = 0; return _p.name + " recovered from its injuries."; }
    return "";
}

// Short injury tag for list rows / detail ("" when healthy).
function pet_injury_tag(pet) {
    if (!is_struct(pet) || pet.injured <= 0) return "";
    if (pet.injured >= 2) return "  [INJURED - can't act]";
    return "  [injured]";
}

// --- Corruption (Pets Phase 3, §7) -------------------------------------------
// A corrupted pet starts PUSHING: it carries a curse-style debuff (player -20% max HP,
// -10% damage) but gains a PERMANENT +15% to its effect each completed run, fully
// corrupting after 3 runs (-> grand archetype ability, debuff gone). You may CURE it any
// time to lock in the gains so far and drop the debuff, but forfeit the grand ability.
// Safe getters tolerate older pets that predate these fields.
function pet_corr_state(pet) {
    if (!is_struct(pet) || !variable_struct_exists(pet, "corruption_state")) return "none";
    return pet.corruption_state;
}
function pet_corr_runs(pet) {
    if (!is_struct(pet) || !variable_struct_exists(pet, "corruption_runs")) return 0;
    return pet.corruption_runs;
}
function pet_corruption_mult(pet)  { return 1.0 + 0.15 * pet_corr_runs(pet); }   // permanent enhancement
function pet_is_fulfilled(pet)     { return pet_corr_state(pet) == "fulfilled"; }

// True while the active pet is a corrupted pet still being PUSHED (carries the debuff).
function pet_corruption_pushing_active() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return false;
    return pet_corr_state(_p) == "pushing";
}
function pet_corruption_maxhp_mult()      { return pet_corruption_pushing_active() ? 0.80 : 1.0; }   // -20% max HP
function pet_corruption_player_dmg_mult() { return pet_corruption_pushing_active() ? 0.90 : 1.0; }   // -10% damage

// On a SURVIVED run the active pushed pet gains +15% (permanent) and, after 3, fully
// corrupts. Death doesn't advance it (injury handles death). Returns a notice or "".
function pet_corruption_on_run_end(result) {
    if (result == -1) return "";
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || pet_corr_state(_p) != "pushing") return "";
    _p.corruption_runs += 1;
    if (_p.corruption_runs >= 3) {
        _p.corruption_state = "fulfilled";
        return _p.name + " has FULLY CORRUPTED - its true power awakens!";
    }
    return _p.name + " feeds on the dark (corruption " + string(_p.corruption_runs) + "/3).";
}

// Cure a pushed pet: keep its gains, drop the debuff, forfeit the grand ability. "" if N/A.
function pet_corruption_cure(pet) {
    if (!is_struct(pet) || pet.is_egg || pet_corr_state(pet) != "pushing") return "";
    pet.corruption_state = "cured";
    return pet.name + " is purged - it keeps its dark strength, but the grand power is lost.";
}

function pet_corruption_tag(pet) {
    switch (pet_corr_state(pet)) {
        case "pushing":   return "  [CORRUPTING " + string(pet_corr_runs(pet)) + "/3]";
        case "cured":     return "  [purged]";
        case "fulfilled": return "  [FULLY CORRUPTED]";
    }
    return "";
}

// --- Pet KIT: named abilities & traits per archetype (Pets §5) ----------------
// Each archetype has stage-gated Traits (auto: 1 at Adolescent, +1 at Young Adult) plus
// a Stage-3 CAPSTONE chosen from a pool (raised pets pick; wild pets roll - see
// pet_assign_capstone). The kit is the NAMED layer over the archetype's base behavior and
// drives the Tab detail popup + small additive effect mods. (Values TBD - balance.)
function pet_kit_catalog() {
    return [
        // BOON
        { arch:PET_ARCH_BOON, id:"prospector", name:"Prospector",     kind:"Trait",   stage:1, effect:"gold", val:0.04, desc:"Sniffs out coin - +4% gold while it is your companion." },
        { arch:PET_ARCH_BOON, id:"lucky",      name:"Lucky Streak",   kind:"Trait",   stage:2, effect:"loot", val:2,    desc:"Fortune leans your way - +2% loot find while active." },
        { arch:PET_ARCH_BOON, id:"windfall",   name:"Windfall",       kind:"Ability", stage:3, effect:"gold", val:0.08, desc:"Capstone: a surge of fortune - a further +8% gold." },
        { arch:PET_ARCH_BOON, id:"treasure_sense", name:"Treasure Sense", kind:"Ability", stage:3, effect:"loot", val:4, desc:"Capstone: an unerring nose for loot - a further +4% loot find." },
        // COMBATANT
        { arch:PET_ARCH_COMBATANT, id:"vicious", name:"Vicious",      kind:"Trait",   stage:1, effect:"dmg", val:0.15, desc:"Goes for the throat - +15% to its attacks." },
        { arch:PET_ARCH_COMBATANT, id:"savage",  name:"Savage",       kind:"Trait",   stage:2, effect:"dmg", val:0.20, desc:"Tastes blood - a further +20% to its attacks." },
        { arch:PET_ARCH_COMBATANT, id:"rend",    name:"Rend",         kind:"Ability", stage:3, effect:"dmg", val:0.50, desc:"Capstone: brutal, tearing strikes - +50% attack damage." },
        { arch:PET_ARCH_COMBATANT, id:"executioner", name:"Executioner", kind:"Ability", stage:3, effect:"execute", val:0.40, desc:"Capstone: +40% damage to enemies below 30% HP - it finishes the wounded." },
        // GUARDIAN
        { arch:PET_ARCH_GUARDIAN, id:"devoted", name:"Devoted",       kind:"Trait",   stage:1, effect:"heal", val:0.25, desc:"Never leaves your side - +25% to its healing." },
        { arch:PET_ARCH_GUARDIAN, id:"warding", name:"Warding",       kind:"Trait",   stage:2, effect:"shield", val:0.25, desc:"Raises stronger wards - +25% to its shields." },
        { arch:PET_ARCH_GUARDIAN, id:"guardian_angel", name:"Guardian Angel", kind:"Ability", stage:3, effect:"both", val:0, desc:"Capstone: each turn it heals AND shields you, never just one." },
        { arch:PET_ARCH_GUARDIAN, id:"bulwark", name:"Bulwark",       kind:"Ability", stage:3, effect:"shield", val:0.50, desc:"Capstone: an immovable ward - +50% to its shields." },
        // AWAKENED SPLASH (stage 4, design 2026-07-03): the crossover layer. One signature
        // splash per archetype; an Awakened pet takes exactly ONE, and only from a
        // DIFFERENT archetype (pet_splash_pool) - a Warrior tastes Fortune, never more Warrior.
        { arch:PET_ARCH_BOON,      id:"gilded_soul", name:"Gilded Soul", kind:"Splash", stage:4, effect:"splash_fortune", val:0.06, val2:2, desc:"Awakened splash: a Fortune's touch - +6% gold and +2% loot find while active." },
        { arch:PET_ARCH_COMBATANT, id:"feral_echo",  name:"Feral Echo",  kind:"Splash", stage:4, effect:"splash_echo",    val:10,   desc:"Awakened splash: a Warrior's instinct - it lashes out as each combat begins." },
        { arch:PET_ARCH_GUARDIAN,  id:"vigil",       name:"Vigil",       kind:"Splash", stage:4, effect:"splash_vigil",   val:14,   desc:"Awakened splash: a Guardian's watch - once per combat, it shields you the first time you fall below 40% HP." },
    ];
}

function pet_kit_get(id) {
    var _c = pet_kit_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}

// The Stage-3 capstone pool for an archetype (entries the player picks / rolls from).
// stage == 3 exactly: the stage-4 SPLASH entries live in pet_splash_pool, not here.
function pet_archetype_capstones(arch) {
    var _c = pet_kit_catalog(); var _out = [];
    for (var _i = 0; _i < array_length(_c); _i++)
        if (_c[_i].arch == arch && _c[_i].stage == 3) array_push(_out, _c[_i]);
    return _out;
}

// The Awakened SPLASH pool for a pet's archetype: the stage-4 entries of the OTHER two
// archetypes (crossover is the point - its own archetype's splash is off the menu).
function pet_splash_pool(arch) {
    var _c = pet_kit_catalog(); var _out = [];
    for (var _i = 0; _i < array_length(_c); _i++)
        if (_c[_i].arch != arch && _c[_i].stage == 4) array_push(_out, _c[_i]);
    return _out;
}

// A pet's currently-unlocked kit: auto traits (stage <3, gated by stage) + the chosen
// Stage-3 capstone (kit_capstone) once Adult.
function pet_kit(pet) {
    var _out = [];
    if (!is_struct(pet) || pet.is_egg) return _out;
    var _c = pet_kit_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        var _e = _c[_i];
        if (_e.arch != pet.archetype) continue;
        if (_e.stage < 3 && pet.stage >= _e.stage) array_push(_out, _e);
    }
    if (pet.stage >= PET_STAGE_ADULT && variable_struct_exists(pet, "kit_capstone") && pet.kit_capstone != "") {
        var _cap = pet_kit_get(pet.kit_capstone);
        if (_cap != undefined) array_push(_out, _cap);
    }
    // Awakened SPLASH (stage 4): the one off-archetype effect, once chosen/rolled.
    if (pet.stage >= PET_STAGE_AWAKENED && variable_struct_exists(pet, "kit_splash") && pet.kit_splash != "") {
        var _spl = pet_kit_get(pet.kit_splash);
        if (_spl != undefined) array_push(_out, _spl);
    }
    return _out;
}

// Auto-roll a Stage-3 capstone (found/wild creatures). No-op if one is already set.
// Boss-egg (signature) pets hatch raised=true, so they take the pick path (curated kit,
// design §3.1) via pet_capstone_choose like any raised pet.
function pet_assign_capstone(pet) {
    if (!is_struct(pet)) return;
    if (variable_struct_exists(pet, "kit_capstone") && pet.kit_capstone != "") return;
    var _pool = pet_archetype_capstones(pet.archetype);
    if (array_length(_pool) > 0) pet.kit_capstone = _pool[irandom(array_length(_pool) - 1)].id;
    pet.capstone_locked  = true;
    pet.capstone_pending = false;
}

// --- Raised-pet capstone PICK (design: raised pets choose their Stage-3 gift at Bairc,
// permanent once locked; found creatures auto-roll). ------------------------------------
// Safe getters tolerate pets saved before these fields existed.
function pet_capstone_is_pending(pet) {
    return is_struct(pet) && variable_struct_exists(pet, "capstone_pending") && pet.capstone_pending;
}
function pet_capstone_is_locked(pet) {
    return is_struct(pet) && variable_struct_exists(pet, "capstone_locked") && pet.capstone_locked;
}

// True when the selected pet is a raised Adult still owing a capstone choice.
function pet_capstone_can_pick(pet) {
    if (!is_struct(pet) || pet.is_egg) return false;
    return pet.raised && pet.stage >= PET_STAGE_ADULT && pet_capstone_is_pending(pet);
}

// Lock in a raised pet's chosen capstone (by id). Permanent - guarded by can_pick.
function pet_capstone_choose(pet, capstone_id) {
    if (!pet_capstone_can_pick(pet)) return false;
    pet.kit_capstone     = capstone_id;
    pet.capstone_pending = false;
    pet.capstone_locked  = true;
    return true;
}

// One-time migration for saves made before the pick UI: a RAISED Adult that already has an
// auto-rolled capstone but was never "locked" by the new system gets that roll cleared and
// re-flagged pending, so it can choose once. Self-guarding (after clearing, kit_capstone is
// "" so it won't re-trigger); found pets and already-locked pets are untouched.
function pet_capstone_migrate_all() {
    var _r = pet_roster();
    for (var _i = 0; _i < array_length(_r); _i++) {
        var _p = _r[_i];
        if (is_struct(_p) && !_p.is_egg && _p.raised && _p.stage >= PET_STAGE_ADULT
            && !pet_capstone_is_locked(_p)
            && variable_struct_exists(_p, "kit_capstone") && _p.kit_capstone != "") {
            _p.kit_capstone     = "";
            _p.capstone_pending = true;
        }
    }
}

// Count of pets awaiting a capstone pick (for a Bairc badge / notice).
function pet_capstone_pending_count() {
    var _r = pet_roster(); var _n = 0;
    for (var _i = 0; _i < array_length(_r); _i++) if (pet_capstone_can_pick(_r[_i])) _n++;
    return _n;
}

// --- Awakened SPLASH pick (design 2026-07-03): raised pets choose their one off-archetype
// effect at Bairc, wild pets auto-roll - the same split as the Stage-3 capstone. Safe
// getters tolerate pets saved before these fields existed. ------------------------------
function pet_splash_is_pending(pet) {
    return is_struct(pet) && variable_struct_exists(pet, "splash_pending") && pet.splash_pending;
}
function pet_splash_is_locked(pet) {
    return is_struct(pet) && variable_struct_exists(pet, "splash_locked") && pet.splash_locked;
}

// True when the selected pet is a raised Awakened still owing its splash choice.
function pet_splash_can_pick(pet) {
    if (!is_struct(pet) || pet.is_egg) return false;
    return pet.raised && pet.stage >= PET_STAGE_AWAKENED && pet_splash_is_pending(pet);
}

// Lock in a raised pet's chosen splash (by id, validated against its pool). Permanent.
function pet_splash_choose(pet, splash_id) {
    if (!pet_splash_can_pick(pet)) return false;
    var _pool = pet_splash_pool(pet.archetype); var _ok = false;
    for (var _i = 0; _i < array_length(_pool); _i++) if (_pool[_i].id == splash_id) { _ok = true; break; }
    if (!_ok) return false;
    pet.kit_splash     = splash_id;
    pet.splash_pending = false;
    pet.splash_locked  = true;
    return true;
}

// Auto-roll a splash (found/wild creatures crossing to Awakened). No-op if already set.
function pet_assign_splash(pet) {
    if (!is_struct(pet)) return;
    if (variable_struct_exists(pet, "kit_splash") && pet.kit_splash != "") return;
    var _pool = pet_splash_pool(pet.archetype);
    if (array_length(_pool) > 0) pet.kit_splash = _pool[irandom(array_length(_pool) - 1)].id;
    pet.splash_locked  = true;
    pet.splash_pending = false;
}

// Count of pets awaiting a splash pick (Bairc badge / notice, mirrors capstone count).
function pet_splash_pending_count() {
    var _r = pet_roster(); var _n = 0;
    for (var _i = 0; _i < array_length(_r); _i++) if (pet_splash_can_pick(_r[_i])) _n++;
    return _n;
}

// Active pet's Gilded-Soul economy splash (flat, archetype-agnostic - a Warrior or
// Guardian carrying the Fortune splash). Added alongside the Boon/LCK bonuses at the
// gold and loot roll sites; zero for everyone else.
function pet_active_splash_gold_pct() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    return pet_kit_mods(_p).splash_gold;
}
function pet_active_splash_loot_pts() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    return pet_kit_mods(_p).splash_loot;
}

// Awakened aura tint (combat/hub draws): gold Fortune / red Warrior / blue Guardian,
// or -1 when the pet is not Awakened (callers skip the aura entirely).
function pet_aura_color(pet) {
    if (!is_struct(pet) || pet.is_egg || pet.stage < PET_STAGE_AWAKENED) return -1;
    switch (pet.archetype) {
        case PET_ARCH_COMBATANT: return make_color_rgb(255, 115, 90);
        case PET_ARCH_GUARDIAN:  return make_color_rgb(110, 170, 255);
    }
    return make_color_rgb(255, 205, 95);   // Fortune
}

// Aggregate the additive effect mods from a pet's unlocked kit.
function pet_kit_mods(pet) {
    var _m = { dmg:0, heal:0, shield:0, gold:0, loot:0, execute:0, both:false,
               splash_gold:0, splash_loot:0, echo:0, vigil:0 };
    var _k = pet_kit(pet);
    for (var _i = 0; _i < array_length(_k); _i++) {
        var _e = _k[_i];
        switch (_e.effect) {
            case "dmg":     _m.dmg     += _e.val; break;
            case "heal":    _m.heal    += _e.val; break;
            case "shield":  _m.shield  += _e.val; break;
            case "gold":    _m.gold    += _e.val; break;
            case "loot":    _m.loot    += _e.val; break;
            case "execute": _m.execute += _e.val; break;
            case "both":    _m.both     = true;   break;
            // Awakened splash keys - kept SEPARATE from gold/loot so the Boon-gated
            // economy path (pet_active_boon_*) never double-counts them.
            case "splash_fortune": _m.splash_gold += _e.val; _m.splash_loot += _e.val2; break;
            case "splash_echo":    _m.echo  += _e.val; break;
            case "splash_vigil":   _m.vigil += _e.val; break;
        }
    }
    return _m;
}

// GENERIC species catalog. Archetype is rolled SEPARATELY at acquisition (design §3), so a
// species is cosmetic + a sprite hook, NOT an archetype lock. Random rolls (events, shrines,
// curses, starter) draw ONLY from this list - boss-signature species live in their own
// catalog below and can never appear from a non-boss source.
function pet_species_catalog() {
    return [
        { id:"luna_moth",   name:"Luna Moth",   blurb:"a pale grub that dreams of moonlit wings" },
        { id:"bone_stag",   name:"Bone Stag",   blurb:"antlers rise like a cathedral of bone" },
        { id:"saber_hound", name:"Saber Hound", blurb:"born snarling, grows into the snarl" },
        { id:"gloomtoad",   name:"Gloomtoad",   blurb:"its stare draws thoughts into the mire" },
        { id:"wyrmling",    name:"Wyrmling",    blurb:"a hatchling that remembers being a dragon" },
        { id:"nightowl",    name:"Nightowl",    blurb:"keeps watch through the longest dark" },
        { id:"bonehound",   name:"Bonehound",   blurb:"loyal even past death" },
        { id:"hollow_pup",  name:"Hollow Pup",  blurb:"hollow-eyed, but its tail still wags" },
    ];
}

// SIGNATURE species - one per boss, found nowhere else (design §3.1). Keyed by the
// dungeon + floor of the boss whose egg drops it; `boss` is the display name for
// "kin of ..." UI lines. Only pet_try_boss_egg hands these out.
function pet_species_signature_catalog() {
    return [
        { id:"vaultling",       name:"Vaultling",       boss:"Vault Sentinel",       dungeon:"ashen_vault",     floor:1, blurb:"a rune-sealed stone beetle, still humming with the Vault's wards" },
        { id:"marrow_adder",    name:"Marrow Adder",    boss:"Bone Sovereign",       dungeon:"ashen_vault",     floor:2, blurb:"a serpent of linked vertebrae, wearing a crown far too small" },
        { id:"gaolwyrm",        name:"Gaolwyrm",        boss:"Malgrath the Warden",  dungeon:"ashen_vault",     floor:3, blurb:"a chain-wrapped lizard whose tail ends in a key" },
        { id:"cinder_newt",     name:"Cinder Newt",     boss:"Forge Tyrant",         dungeon:"scorched_depths", floor:1, blurb:"an ember-bellied salamander that naps in cooling coals" },
        { id:"magma_leech",     name:"Magma Leech",     boss:"Molten Revenant",      dungeon:"scorched_depths", floor:2, blurb:"it inches along, dripping slag that cools into pearls" },
        { id:"golemite",        name:"Golemite",        boss:"The Ashen Colossus",   dungeon:"scorched_depths", floor:3, blurb:"a fist-sized shard of the Colossus, still trying to be tall" },
        { id:"rimefox",         name:"Rimefox",         boss:"Glacial Warden",       dungeon:"tundra_tomb",     floor:1, blurb:"a frost-furred kit whose breath never melts" },
        { id:"crypt_bat",       name:"Crypt Bat",       boss:"Tomb Archon",          dungeon:"tundra_tomb",     floor:2, blurb:"tattered wings that never miss in the dark" },
        { id:"hoarfrost_drake", name:"Hoarfrost Drake", boss:"The Eternal Frost",    dungeon:"tundra_tomb",     floor:3, blurb:"an ice-scaled drakeling dreaming of the long winter" },
    ];
}

// The signature species a given boss drops ("" if the slot is unmapped - the egg then
// falls back to a generic species roll, so an unmapped boss can never break the drop).
function pet_boss_signature_species(dungeon, fl) {
    var _c = pet_species_signature_catalog();
    for (var _i = 0; _i < array_length(_c); _i++)
        if (_c[_i].dungeon == dungeon && _c[_i].floor == fl) return _c[_i].id;
    return "";
}

function pet_species_get(id) {
    var _c = pet_species_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    var _s = pet_species_signature_catalog();
    for (var _i = 0; _i < array_length(_s); _i++) if (_s[_i].id == id) return _s[_i];
    return { id:id, name:"Creature", blurb:"" };
}

function pet_species_random() {
    var _c = pet_species_catalog();
    return _c[irandom(array_length(_c) - 1)].id;
}

// Safe read of the player-named flag. Pets created before the naming feature lack the
// `named` field, so a raw `pet.named` read throws - always go through this.
function pet_named(pet) {
    return is_struct(pet) && variable_struct_exists(pet, "named") && pet.named;
}

// Safe read of the boss-signature flag (same early-save caveat as pet_named).
function pet_is_signature(pet) {
    return is_struct(pet) && variable_struct_exists(pet, "signature") && pet.signature;
}

// Save cleanup: pets from the retired humanoid species (the anthropomorphic "mothmen"
// dropped in the redesign, see [[feedback_pets_not_anthropomorphic]]) are remapped IN
// PLACE to a thematic new creature so their old art can never render. Keeps stage / bond /
// growth / progress; only rebrands the display name if the player never gave it a custom
// one. Idempotent - a no-op once no retired pets remain.
function pet_migrate_retired_species() {
    if (!variable_global_exists("pet_roster") || !is_array(global.pet_roster)) return;
    var _map = {
        cryptling:    "gloomtoad",
        graveling:    "bone_stag",
        ashling:      "wyrmling",
        wisplet:      "nightowl",
        carrion_moth: "luna_moth",
        gravewing:    "nightowl",
    };
    for (var _i = 0; _i < array_length(global.pet_roster); _i++) {
        var _p = global.pet_roster[_i];
        if (!is_struct(_p) || !variable_struct_exists(_p, "species")) continue;
        if (!variable_struct_exists(_p, "named"))     _p.named     = false;   // backfill pre-naming pets so raw reads never throw
        if (!variable_struct_exists(_p, "signature")) _p.signature = false;   // backfill pre-signature pets (scr_ui reads it raw)
        if (variable_struct_exists(_map, _p.species)) {
            _p.species = variable_struct_get(_map, _p.species);
            if (!variable_struct_exists(_p, "named") || !_p.named) {
                _p.name = pet_species_get(_p.species).name;   // was still the old default name
            }
        }
    }
}

// The creatures entrusted to Bairc over this save's whole history. Each entry keeps just
// enough to draw it wandering his garden: { species, name, stage }. Persisted in the save.
function bairc_donated() {
    if (!variable_global_exists("bairc_donated") || !is_array(global.bairc_donated)) global.bairc_donated = [];
    return global.bairc_donated;
}

// DONATE the pet at roster index _idx to Bairc (design §6: donation, not release - the
// creature is entrusted, not abandoned, and lives on visibly in his garden). Removes it
// from the roster, fixes the active-pet pointer for the index shift, and returns the
// creature's label for the notice ("" if the index was invalid). A donated EGG joins the
// garden too - Bairc hatches it in his own time (stage 0).
function pet_donate(_idx) {
    if (!variable_global_exists("pet_roster") || !is_array(global.pet_roster)) return "";
    if (_idx < 0 || _idx >= array_length(global.pet_roster)) return "";
    var _p    = global.pet_roster[_idx];
    var _labl = _p.is_egg ? (_p.name + " egg") : _p.name;
    array_push(bairc_donated(), {
        species: _p.species,
        name:    _p.name,
        stage:   _p.is_egg ? PET_STAGE_BABY : _p.stage,
    });
    bairc_lore_unlock("first_donation");
    array_delete(global.pet_roster, _idx, 1);
    if (variable_global_exists("active_pet")) {
        if      (global.active_pet == _idx) global.active_pet = -1;
        else if (global.active_pet >  _idx) global.active_pet -= 1;
    }
    return _labl;
}

// Build a pet/egg struct. archetype < 0 => roll one (revealed immediately, design §3).
// is_egg true => unhatched (hatches to Stage 0). `stage` applies to FOUND creatures.
function pet_make(species_id, source, archetype, stage, is_egg) {
    if (!variable_global_exists("pet_next_id")) global.pet_next_id = 1;
    var _arch = (archetype < 0) ? irandom(2) : archetype;
    var _awk  = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    var _sp   = pet_species_get(species_id);
    var _egg  = is_egg ? pet_egg_random() : "";   // eggs carry a random egg-type benefit (§3)
    return {
        uid:            global.pet_next_id++,
        species:        species_id,
        name:           _sp.name,                         // species name until the player names it
        named:          false,                            // has the player given it a custom name? (1st free, rename 20 dust)
        archetype:      _arch,
        source:         source,                          // egg_event/egg_shrine/egg_curse/egg_boss/found
        raised:         (string_pos("egg", source) > 0), // hatched egg = raised; found = not raised
        stage:          is_egg ? PET_STAGE_BABY : stage,
        growth:         0,                               // feed progress (later slice)
        stage_floors:   0,                               // banked active-run progress (later slice)
        bond:           0,                               // loyalty (later slice)
        injured:        0,                               // injury ladder tier (Phase 3)
        corrupted:      false,                           // is this a corrupted pet? (Phase 3 §7)
        corruption_runs:  0,                             // completed runs pushed (0..3); +15% effect each, permanent
        corruption_state: "none",                        // "none" / "pushing" / "cured" / "fulfilled"
        kit_capstone:   "",                              // Stage-3 capstone id (rolled wild / picked raised); see pet_kit_catalog
        capstone_pending: false,                         // RAISED pet reached Adult, awaiting the player's capstone pick at Bairc
        capstone_locked:  false,                         // capstone decided (rolled for found, chosen for raised) - never changes
        kit_splash:     "",                              // Stage-4 Awakened splash id (one off-archetype effect); see pet_splash_pool
        splash_pending: false,                           // RAISED pet Awakened, awaiting the player's splash pick at Bairc
        splash_locked:  false,                           // splash decided - never changes
        is_egg:         is_egg,
        egg_type:       _egg,                             // RNG egg-type benefit kept after hatch (§3)
        awk_at_acquire: _awk,
        signature:      (source == "egg_boss"),          // boss-egg => unique species + awk stat ceiling (§3.1)
        // sprite-state (animation shelved; fields reserved per design §6/§13)
        sprite_name:    "spr_pet_" + species_id,
        sprite_state:   "idle",
        sprite_frame:   0
    };
}

function pet_roster() {
    if (!variable_global_exists("pet_roster")) global.pet_roster = [];
    return global.pet_roster;
}
function pet_count() { return array_length(pet_roster()); }

// True once the player owns any pet/egg - Bairc wakes from his dormant "......" state.
function bairc_active() { return pet_count() > 0; }

function pet_active() {
    if (!variable_global_exists("active_pet")) return undefined;
    if (global.active_pet < 0 || global.active_pet >= pet_count()) return undefined;
    return global.pet_roster[global.active_pet];
}

// Add a pet/egg to the roster; returns it. The first pet ever owned auto-equips.
function pet_add(pet) {
    var _r = pet_roster();
    array_push(_r, pet);
    if (!variable_global_exists("active_pet")) global.active_pet = -1;
    if (global.active_pet < 0) global.active_pet = 0;
    return pet;
}

// Hatch an egg in-place into a Stage-0 baby (archetype was already rolled/revealed).
function pet_hatch(pet) {
    if (!is_struct(pet) || !pet.is_egg) return false;
    pet.is_egg = false;
    pet.stage  = PET_STAGE_BABY;
    return true;
}

// --- Full-screen hatch cutscene (Pets §3) -------------------------------------
// A modal shake -> crack -> reveal sequence launched from the Bairc Enter-on-egg
// action. State lives on obj_game_controller (see its Create). hatch_cutscene_step()
// runs from gc Step while hatch_active (owning all input); hatch_cutscene_draw()
// (scr_ui) renders it over the Bairc screen. pet_hatch() is applied at the reveal.
#macro HATCH_SHAKE_LEN  50   // frames of trembling before the shell cracks
#macro HATCH_CRACK_HOLD 7    // frames each crack-animation frame is held
#macro HATCH_REVEAL_MIN 36   // min frames of reveal before input can dismiss it

// The multi-frame crack animation for a pet's egg type (falls back to the static
// egg sprite when the animated art isn't authored yet). Cutscene-only.
function hatch_crack_sprite(pet) {
    if (is_struct(pet) && variable_struct_exists(pet, "egg_type") && pet.egg_type != "") {
        var _h = asset_get_index("spr_pet_egg_" + pet.egg_type + "_hatch");
        if (_h >= 0) return _h;
        var _fb = pet_egg_art_fallback(pet.egg_type);   // borrow a close type's crack anim
        if (_fb != "") {
            var _fbh = asset_get_index("spr_pet_egg_" + _fb + "_hatch");
            if (_fbh >= 0) return _fbh;
        }
    }
    return pet_sprite(pet, "s");
}

// Begin the hatch cutscene for an egg (no-op if it isn't an egg). Runs in gc scope.
function hatch_cutscene_start(pet) {
    if (!is_struct(pet) || !pet.is_egg) return;
    hatch_active = true;
    hatch_pet    = pet;
    hatch_phase  = 0;
    hatch_t      = 0;
    hatch_frame  = 0;
    hatch_done   = false;
}

// Advance the cutscene one step (called from gc Step while hatch_active). Runs in gc scope.
function hatch_cutscene_step() {
    hatch_t += 1;
    switch (hatch_phase) {
        case 0: // SHAKE - trembling shell, backdrop darkening
            if (hatch_t >= HATCH_SHAKE_LEN) { hatch_phase = 1; hatch_t = 0; hatch_frame = 0; }
            break;

        case 1: // CRACK - advance the hatch animation frame by frame
            var _hsp = hatch_crack_sprite(hatch_pet);
            var _n   = (_hsp >= 0) ? sprite_get_number(_hsp) : 1;
            if (hatch_t >= HATCH_CRACK_HOLD) {
                hatch_t = 0;
                hatch_frame += 1;
                if (hatch_frame >= _n) {
                    if (!hatch_done) {                    // shell broken -> hatch into a baby
                        pet_hatch(hatch_pet);
                        hatch_done = true;
                        audio_play_sound(snd_pet_hatch, 1, false);
                    }
                    hatch_phase = 2; hatch_t = 0;
                }
            }
            break;

        case 2: // REVEAL - baby scales in; wait for the player to dismiss (min hold first)
            if (hatch_t >= HATCH_REVEAL_MIN &&
                (keyboard_check_pressed(vk_enter)  || keyboard_check_pressed(vk_return)
              || keyboard_check_pressed(vk_space)  || keyboard_check_pressed(vk_escape))) {
                if (!hatch_done) { pet_hatch(hatch_pet); hatch_done = true; }
                bairc_notification = hatch_pet.name + " hatches - a "
                    + pet_archetype_name(hatch_pet.archetype) + " baby!";
                hatch_active = false;
                hatch_pet    = undefined;
                if (room == rm_hub || room == rm_character_select) save_game();
            }
            break;
    }
}

// True when an egg's contents are known (species/type visible, hatchable).
// Eggs found in the dungeon arrive UNIDENTIFIED - pay Bairc to identify them.
// Back-compat: eggs saved before this feature carry no flag and count as known.
function pet_egg_identified(pet) {
    if (!is_struct(pet) || !pet.is_egg) return true;
    return !variable_struct_exists(pet, "identified") || pet.identified;
}

// Gold cost to have Bairc identify an egg.
function pet_egg_identify_cost() { return cha_price(75); }

// Number of unhatched eggs currently held.
function pet_egg_count() {
    var _r = pet_roster(); var _n = 0;
    for (var _i = 0; _i < array_length(_r); _i++) if (_r[_i].is_egg) _n++;
    return _n;
}

// --- Acquisition --------------------------------------------------------------
// Grant a pet from a source ("egg_event"/"egg_shrine"/"egg_curse"/"egg_boss"). ~15%
// of non-boss sources yield a FOUND creature (already alive, Stage 1-2) instead of an
// egg (design §3.2) - rarer, no full raise-history. Returns the granted pet/egg.
function pet_grant_from_source(source, species_override = "") {
    var _species = (species_override != "") ? species_override : pet_species_random();
    var _pet;
    if (source != "egg_boss" && irandom(99) < 15) {
        _pet = pet_make(_species, "found", -1, 1 + irandom(1), false);   // found, Stage 1-2
    } else {
        _pet = pet_make(_species, source, -1, PET_STAGE_BABY, true);     // egg
    }
    // ~12% of finds arrive CORRUPTED (§7): they start PUSHING (carried debuff, but gains a
    // permanent +15% each completed run, fully corrupting after 3). You can cure anytime.
    if (irandom(99) < 12) { _pet.corrupted = true; _pet.corruption_state = "pushing"; }
    // Dungeon-found EGGS arrive unidentified - everything but the shell is "??"
    // until Bairc is paid to identify (design 2026-07-04). Found LIVE creatures
    // are self-evidently what they are.
    if (_pet.is_egg) _pet.identified = false;
    // Record for the run-scoped found strip in the equipment Found column - pets go
    // straight to Bairc, so this is the only in-run place the loot is visible.
    if (!variable_global_exists("run_found_pets")) global.run_found_pets = [];
    if (_pet.is_egg) {
        var _mys_lbl = pet_egg_label(_pet);
        array_push(global.run_found_pets, "Mysterious " + ((_mys_lbl != "") ? _mys_lbl : "Egg"));
    } else {
        array_push(global.run_found_pets, _pet.name);
    }
    return pet_add(_pet);
}

// True if a species has imported base art (so the starter never rolls an artless one).
function pet_species_has_art(species_id) {
    return asset_get_index("spr_pet_" + species_id + "_baby_s") >= 0
        || asset_get_index("spr_pet_" + species_id + "_baby") >= 0
        || asset_get_index("spr_pet_" + species_id) >= 0;
}

// The one-time STARTER egg, granted on the first Bairc talk. Random species (preferring
// ones with finished art) + random archetype, delivered as an EGG ready to hatch (doubles
// as the hatch tutorial). randomize() first so each SAVE SLOT rolls its own unique creature
// - no shared/duplicate spawns across save files.
function pet_grant_starter() {
    randomize();
    var _cat = pet_species_catalog();
    var _arted = [];
    for (var _i = 0; _i < array_length(_cat); _i++)
        if (pet_species_has_art(_cat[_i].id)) array_push(_arted, _cat[_i].id);
    var _species = (array_length(_arted) > 0) ? _arted[irandom(array_length(_arted) - 1)] : pet_species_random();
    return pet_add(pet_make(_species, "egg_starter", -1, PET_STAGE_BABY, true));   // is_egg = true
}

// --- Egg types (Pets §3): RNG egg design, each carrying a small permanent benefit that
// the HATCHLING keeps while it is your active companion. Egg type is independent of the
// creature inside (a surprise). 4 types for now (expandable). ----------------------------
function pet_egg_type_catalog() {
    return [
        { id:"gilded",  name:"Gilded Egg",   effect:"gold",   val:0.05, desc:"+5% gold while its hatchling is active." },
        { id:"fortune", name:"Fortune Egg",  effect:"loot",   val:5,    desc:"+5% loot find while its hatchling is active." },
        { id:"savage",  name:"Savage Egg",   effect:"dmg",    val:0.05, desc:"+5% pet damage (no effect on Guardian pets)." },
        { id:"tender",  name:"Tender Egg",   effect:"mend",   val:0.05, desc:"+5% pet heal & shield (no effect on Combatant pets)." },
        // Expansion slate (§3): six more surprise egg designs, each a small permanent perk
        // carried by the hatchling while it is your active companion.
        { id:"vital",   name:"Vital Egg",    effect:"vit",    val:0.08, desc:"+8% max HP while its hatchling is active." },
        { id:"ley",     name:"Ley Egg",      effect:"growth", val:1,    desc:"+1 growth each survived run (its hatchling matures faster)." },
        { id:"scholar", name:"Scholar's Egg",effect:"xp",     val:0.08, desc:"+8% XP while its hatchling is active." },
        { id:"dust",    name:"Dust Egg",     effect:"dust",   val:0.08, desc:"+8% rune dust while its hatchling is active." },
        { id:"warding", name:"Warding Egg",  effect:"ward",   val:0.06, desc:"-6% damage taken while its hatchling is active." },
        { id:"keen",    name:"Keen Egg",     effect:"crit",   val:5,    desc:"+5% crit chance while its hatchling is active." },
    ];
}
// Art fallback: until a new egg type's own sprite is imported, borrow a thematically
// close existing egg sprite so it still renders (never falls through to the hatchling
// species sprite, which would spoil the surprise). Maps id -> existing typed egg id.
function pet_egg_art_fallback(egg_type) {
    switch (egg_type) {
        case "vital":   return "tender";    // soft, nurturing
        case "ley":     return "gilded";    // arcane sheen
        case "scholar": return "fortune";   // ornate, studious
        case "dust":    return "gilded";    // mineral glint
        case "warding": return "savage";    // bony, armored
        case "keen":    return "savage";    // sharp, aggressive
    }
    return "";
}
function pet_egg_type_get(id) {
    var _c = pet_egg_type_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}
function pet_egg_random() {
    var _c = pet_egg_type_catalog();
    return _c[irandom(array_length(_c) - 1)].id;
}

// The active pet's egg benefit for a given kind ("gold"/"loot"/"dmg"/"mend"), honoring the
// archetype exclusions (damage egg skips Guardians; mend egg skips Combatants). 0 if none.
function pet_active_egg_bonus(kind) {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    if (!variable_struct_exists(_p, "egg_type") || _p.egg_type == "") return 0;
    var _et = pet_egg_type_get(_p.egg_type);
    if (_et == undefined || _et.effect != kind) return 0;
    if (kind == "dmg"  && _p.archetype == PET_ARCH_GUARDIAN)  return 0;
    if (kind == "mend" && _p.archetype == PET_ARCH_COMBATANT) return 0;
    return _et.val;
}

// Warding-egg incoming-damage multiplier for the active pet (1.0 if none). Mirrors the
// Warding boon's shape so combat can apply it at every player damage-mitigation site.
function pet_egg_ward_mult() {
    var _w = pet_active_egg_bonus("ward");
    return (_w > 0) ? (1.0 - _w) : 1.0;
}

// Display label for a pet's egg type ("" if none).
function pet_egg_label(pet) {
    if (!is_struct(pet) || !variable_struct_exists(pet, "egg_type") || pet.egg_type == "") return "";
    var _et = pet_egg_type_get(pet.egg_type);
    return (_et == undefined) ? "" : _et.name;
}

// Boss-clear pet roll. Rare even at max difficulty; odds rise with Awakening but never
// approach guaranteed (design §3.1). The egg carries the slain boss's SIGNATURE species
// (one per boss, found nowhere else); duplicates are allowed - a later, higher-Awakening
// kill yields a stronger copy of the same kin. Returns the granted pet, or undefined.
function pet_try_boss_egg(awk) {
    var _chance = min(14, 4 + awk);                      // 4% A0 +1%/awk -> 9% A5 (playtest-tuned from +2%/awk, M 2026-07-03)
    if (irandom(99) >= _chance) return undefined;
    var _dung  = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
    var _floor = variable_global_exists("current_floor")    ? global.current_floor    : 1;
    return pet_grant_from_source("egg_boss", pet_boss_signature_species(_dung, _floor));
}

// Grant a pet egg/creature from a Shrine (blessing) or Curse altar, appending a themed
// hub notice (surfaced on the next hub visit). source: "egg_shrine" / "egg_curse". Curse
// eggs skew corrupted (thematic). Returns the granted pet. Used by the floor shrine flow.
function pet_grant_altar_egg(source) {
    var _pe = pet_grant_from_source(source);
    if (source == "egg_curse" && !_pe.corrupted && irandom(99) < 40) {
        _pe.corrupted = true; _pe.corruption_state = "pushing";
    }
    var _msg;
    if (source == "egg_curse") {
        _msg = _pe.is_egg
            ? "A dark egg festers where the altar stood - visit Bairc."
            : ("A " + _pe.name + " slinks from the altar's shadow - visit Bairc.");
    } else {
        _msg = _pe.is_egg
            ? "The altar leaves behind an egg - visit Bairc."
            : ("A " + _pe.name + " emerges from the rubble - visit Bairc.");
    }
    if (variable_global_exists("pet_find_notice"))
        global.pet_find_notice = (global.pet_find_notice != "") ? (global.pet_find_notice + "   " + _msg) : _msg;
    return _pe;
}

// One-line label for a roster row: name, egg/stage, archetype, found tag.
function pet_row_label(pet) {
    if (!is_struct(pet)) return "";
    if (pet.is_egg) {
        var _el = pet_egg_label(pet);
        if (!pet_egg_identified(pet)) {
            return "Mysterious " + ((_el != "") ? _el : "Egg") + "  -  (?? - Bairc can identify)";
        }
        return pet.name + " Egg" + (_el != "" ? "  -  " + _el : "") + "  (" + pet_archetype_name(pet.archetype) + ")";
    }
    var _tag = pet.raised ? "" : "  (found)";
    return pet.name + "  -  " + pet_stage_name(pet.stage) + "  -  " + pet_archetype_name(pet.archetype) + _tag + pet_injury_tag(pet) + pet_corruption_tag(pet);
}

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
        { id:"intent",     title:"Enemy Intent",        body:"Every enemy telegraphs its next move on the chip above its health bar: red for an attack (with the rough damage you'd take), purple for a spell, green for a heal, amber for a status effect. Intents are honest - and if you Stun, Root or Silence a foe, its chip greys out: that move is cancelled." },
        { id:"inspect",    title:"Inspect Your Foes",   body:"Mouse over an enemy (or its health bar) to inspect it. You'll see whether it fights at Melee or Ranged and with Phys or Spell - and which controls stop it: Root halts melee, Silence stops spells, Stun stops anything. Ranged foes ignore Root, so a trap won't keep them off you." },
        { id:"vex",        title:"Vex the Trainer",     body:"Vex teaches new abilities and traits for gold (and the occasional item). Learn abilities here, then slot them on the loadout screen before a run." },
        { id:"shrine",     title:"Altars",              body:"A shrine is an altar. A Blessing altar sells boons for tribute; a Cursed altar lets you take on a curse - a run-long penalty - in exchange for far better spoils. Choose how greedy you dare to be." },
        { id:"gold_risk",  title:"Gold at Risk",        body:"Gold you FIND during a run is at risk - die and you lose most of it (a quarter is returned as mercy). Gold banked before the run is always safe at camp. The number in brackets on your HUD is what you're gambling: extract to keep it all." },
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
// PACK-ONLY by design: the Shrine is the only caller and it always runs mid-run, so
// the carried pack (source 1) is the sole valid tribute source - the hub stash must
// never be offered to the altar. (Task 8)
function item_picker_candidates_by_tribute(cost) {
    var _out = [];
    var _arr = global.carried_items;
    for (var _i = 0; _i < array_length(_arr); _i++) {
        var _it = _arr[_i];
        if (!is_struct(_it)) continue;
        var _rar = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
        if (item_tribute_value(_rar) < cost) continue;
        var _val = variable_struct_exists(_it, "gold_value") ? _it.gold_value : 0;
        var _nm  = variable_struct_exists(_it, "name") ? _it.name : "item";
        array_push(_out, { source:1, idx:_i, item:_it, label:_nm, rarity:_rar, value:_val });
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

// --- Reforge Chit (Dorn; BOARD_REQUESTS_SPEC.md §7) ---------------------------
// Every held item carrying rolled affixes (stash + pack; equipped gear must be
// unequipped first). The chit rerolls affixes IN PLACE - nothing is consumed.
function item_picker_candidates_affixed() {
    var _out = [];
    var _in_hub = (room == rm_hub || room == rm_character_select);
    for (var _s = 0; _s < 2; _s++) {
        if (_s == 0 && !_in_hub) continue;
        var _arr = (_s == 0) ? global.equipment_stash : global.carried_items;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _it = _arr[_i];
            if (!is_struct(_it)) continue;
            if (!variable_struct_exists(_it, "affixes") || array_length(_it.affixes) == 0) continue;
            // base_name is required to rebuild the display name cleanly (pre-codex
            // items lack it and would keep their old affixed name as the base).
            if (!variable_struct_exists(_it, "base_name")) continue;
            var _rar = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
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

// Reroll an item's affixes in place at its same rarity and affix count. Base
// stats, sockets and set runes are untouched - only the affix rows, the affixed
// display name, and the affixes' share of gold_value change. (Affix effects are
// read live from item.affixes, so a swap needs no stat unwinding.)
function chit_reforge_item(item) {
    if (!variable_struct_exists(item, "affixes")) return false;
    var _count = array_length(item.affixes);
    if (_count == 0) return false;
    var _bn = item_base_name(item);
    // Un-apply the old affixes' contributions (name + the +20%/affix value scale).
    item.gold_value = max(1, round(item.gold_value / power(1.2, _count)));
    item.affixes    = [];
    item.name       = _bn;
    var _r = variable_struct_exists(item, "rarity") ? item.rarity : 1;
    apply_affixes_to_item(item, roll_affixes(min(_r, 3), _count, [item.stat_name], item.slot, _bn));
    return true;
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
        case "chit_reforge": return "Choose an item - Dorn reworks its affixes (1 Reforge Chit)";
        case "gift": return "Choose a gift for " + (variable_struct_exists(global.item_picker.context, "npc_name")
            ? global.item_picker.context.npc_name : "them");
    }
    return "Choose an item";
}
function item_picker_verb() {
    switch (global.item_picker.purpose) {
        case "shrine_boon":  return "Sacrifice";
        case "alch_rebirth": return "Reforge";
        case "chit_reforge": return "Rework";
        case "gift":         return "Give";
    }
    return "Trade away";
}

// Commit: remove the selected item, apply the purpose's effect, stash a one-shot
// result the owning controller reads for its notification + cleanup, then close.
function item_picker_resolve() {
    var _p    = global.item_picker;
    var _ctx  = _p.context;
    var _msg  = "";

    // GIFT (Phase 4b): candidates span five pools, so removal is its own path
    // (gift_remove_candidate) - the shared remover below only knows the gear arrays.
    if (_p.purpose == "gift") {
        var _gsel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                    ? _p.candidates[_p.cursor] : undefined;
        if (_gsel == undefined) {
            _p.resolved_purpose = "gift"; _p.result_msg = "Nothing chosen.";
            item_picker_close(); return;
        }
        var _gnpc = _ctx.npc;
        if (!gift_remove_candidate(_gsel)) {
            _p.resolved_purpose = "gift"; _p.result_msg = "It seems to have gone missing.";
            item_picker_close(); return;
        }
        _p.resolved_purpose = "gift";
        _p.result_msg = gift_give(_gnpc, _gsel);
        save_game();
        item_picker_close();
        return;
    }

    // Reforge Chit (Dorn): the item is MODIFIED in place, never removed. The chit
    // is the whole cost; a failed reroll (no affixes) spends nothing.
    if (_p.purpose == "chit_reforge") {
        var _csel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                    ? _p.candidates[_p.cursor] : undefined;
        if (_csel == undefined) {
            _p.resolved_purpose = "chit_reforge"; _p.result_msg = "Nothing chosen.";
            item_picker_close(); return;
        }
        board_requests_ensure();
        if (global.reforge_chits < 1) {
            _p.resolved_purpose = "chit_reforge"; _p.result_msg = "No Reforge Chits - the tavern board pays them.";
            item_picker_close(); return;
        }
        var _old_cname = _csel.label;
        if (!chit_reforge_item(_csel.item)) {
            _p.resolved_purpose = "chit_reforge"; _p.result_msg = "That item has no affixes to rework.";
            item_picker_close(); return;
        }
        global.reforge_chits -= 1;
        save_game();
        _p.resolved_purpose = "chit_reforge";
        _p.result_msg = "Dorn reworks " + _old_cname + " into " + _csel.item.name + "!   ("
            + string(global.reforge_chits) + ((global.reforge_chits == 1) ? " chit" : " chits") + " left)";
        audio_play_sound(snd_forge, 1, false);
        item_picker_close();
        return;
    }

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
            audio_play_sound(snd_ui_error, 1, false);
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
        audio_play_sound(snd_confirm_major, 1, false);   // a rebirth deserves the chime
        item_picker_close();
        return;
    }

    var _name = item_picker_remove_selected();
    switch (_p.purpose) {
        case "vex_trait":
            global.gold -= _ctx.gold;
            if (!variable_global_exists("traits_unlocked")) global.traits_unlocked = {};
            variable_struct_set(global.traits_unlocked, _ctx.effect_id, true);
            affinity_add("vex", 2);   // function-use drip (trait unlock)
            save_game();
            _msg = "Unlocked " + _ctx.trait_name + "!   (traded: " + _name + ")";
            break;
        case "vex_stat":
            global.gold -= _ctx.gold;
            variable_global_set(_ctx.stat_key, variable_global_get(_ctx.stat_key) + 1);
            affinity_add("vex", 2);   // function-use drip (stat upgrade)
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
        var _lbl = "an item";
        if (fx.item == "vault")          _lbl = "rare gear";
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
    if (variable_struct_exists(fx, "memory") && fx.memory)
        array_push(_p, "a borrowed ability (this run)");
    if (variable_struct_exists(fx, "pet_egg") && fx.pet_egg != "")
        array_push(_p, "a creature");
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
    // The gold cost and stat requirement are already shown on the right side of each
    // choice row (and as the lock reason), so they are intentionally left OUT here -
    // this line is purely the OUTCOMES, written as clear labeled segments instead of
    // one run-on string. (Task 9)
    if (choice.resolve == "check") {
        var _pct = event_check_chance(choice.check_stat, choice.check_base, choice.check_per, choice.check_ref);
        return "Succeed (" + string(_pct) + "%): " + event_effect_phrase(choice.success.effects)
             + "        Fail: " + event_effect_phrase(choice.fail.effects);
    }

    // weighted
    var _outs = choice.outcomes;
    if (array_length(_outs) == 1)
        return "Guaranteed: " + event_effect_phrase(_outs[0].effects);

    var _total = 0;
    for (var _i = 0; _i < array_length(_outs); _i++) _total += _outs[_i].weight;
    var _s = "Odds:   ";
    for (var _i = 0; _i < array_length(_outs); _i++) {
        var _pc = (_total > 0) ? round(_outs[_i].weight * 100 / _total) : 0;
        _s += (_i > 0 ? "     /     " : "") + string(_pc) + "%  " + event_effect_phrase(_outs[_i].effects);
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
        if (fx.gold > 0) {
            add_gold(fx.gold);
            array_push(_sum, "+" + string(fx.gold) + " gold");
            audio_play_sound(snd_gold, 1, false);
            global.event_gold_gained = fx.gold;   // the floor controller reads this to spawn the coin burst
        }
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
    // Pet egg/creature (Phase 2) - fx.pet_egg is a source tag ("egg_event"/"egg_shrine"/
    // "egg_curse"). Lands in Bairc's stable; ~15% arrive as a found creature instead.
    if (variable_struct_exists(fx, "pet_egg") && fx.pet_egg != "") {
        var _pe = pet_grant_from_source(fx.pet_egg);
        array_push(_sum, _pe.is_egg ? (_pe.name + " egg") : ("a living " + _pe.name));
        global.pet_find_notice = _pe.is_egg
            ? ("You recovered a " + _pe.name + " egg - visit Bairc.")
            : ("A " + _pe.name + " follows you home - visit Bairc.");
    }
    // Borrowed Memory (expression #6) - a temporary other-class ability, this run only
    if (variable_struct_exists(fx, "memory") && fx.memory) {
        var _bm = borrowed_memory_grant();
        if (_bm != "") {
            array_push(_sum, "BORROWED MEMORY: " + _bm + " (" + global.run_borrowed_class + " - this run)");
        } else {
            array_push(_sum, "the memory slips away...");
        }
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

    // --- Abandoned Nest (Phase 2: an event-room pet-egg source) ------------
    array_push(_cat, {
        id: "abandoned_nest",
        title: "Abandoned Nest",
        body: "Beneath the curled skeleton of something large, a single egg rests - kept warm, somehow, long after its mother stopped moving.",
        color: make_color_rgb(150, 190, 150),
        choices: [
            { label: "Take the egg", hint: "Carry it home - Bairc can raise whatever hatches",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You cradle the egg and tuck it away. It is faintly warm.",
                            effects: { pet_egg: "egg_event" } } ] },
            { label: "Search the remains", hint: "Look past the egg for what its mother guarded",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 60, text: "Old bones, older gold.", effects: { gold: 45 } },
                          { weight: 40, text: "Tucked beneath a wing-bone, the egg comes with you anyway.",
                            effects: { pet_egg: "egg_event", gold: 20 } } ] },
            { label: "Leave it undisturbed", hint: "Some things should be left to rest",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You leave the nest to the dark.", effects: {} } ] }
        ]
    });

    // --- The Stranger's Memory (Borrowed Memories, expression #6) ----------
    // Grants a run-scoped ability from ANOTHER class's pool - the past-lives
    // lore hook. INT path is the safe read; the greedy path can bite.
    array_push(_cat, {
        id: "strangers_memory",
        title: "The Stranger's Memory",
        body: "A body long past naming sits against the wall, and something of what it knew still hangs in the air - a gesture, a word, a stance that was never yours.",
        color: make_color_rgb(150, 130, 220),
        choices: [
            { label: "Study the memory", hint: "INT check - success: borrow its ability this run - failure: it fades",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
              check_stat: "INT", check_base: 50, check_per: 6, check_ref: 5,
              success: { text: "The gesture settles into your hands as if they had always known it.",
                         effects: { memory: true } },
              fail:    { text: "You reach for it and it scatters like breath on glass.",
                         effects: { dust: 8 } } },
            { label: "Drink it in whole", hint: "No check - the memory takes something back",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 70, text: "It floods in - power, and the cold of a stranger's dying.",
                            effects: { memory: true, hp: -12 } },
                          { weight: 30, text: "Only the dying comes through.",
                            effects: { hp: -18, dust: 12 } } ] },
            { label: "Let the dead keep it", hint: "Walk away - no risk, no reward",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "You leave what remains of them intact.", effects: {} } ] }
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
        // Sound pass Batch 3 - ambience beds (M routed these under the Music
        // slider rather than a third slider, 07-07)
        snd_amb_rain, snd_amb_cave, snd_amb_torch,
    ];
}

// -----------------------------------------------------------------------------
// ROOM AMBIENCE LAYER (sound pass Batch 3)
// A quiet looping bed under the music: rain in the hub, cave air on dungeon
// floors, torch crackle at both. Each room controller's Create declares its
// FULL layer via ambience_set([...]) - anything left playing from the previous
// room that isn't in the new set gets stopped there, so the scattered
// audio_stop_sound sites for music never need to know about ambience.
// -----------------------------------------------------------------------------
function ambience_all_assets() {
    return [snd_amb_rain, snd_amb_cave, snd_amb_torch];
}

// _list: the ambience assets this room wants (may be empty). Already-playing
// members keep playing (no restart pop when hub <-> floor share the torch bed).
function ambience_set(_list) {
    var _all = ambience_all_assets();
    for (var _i = 0; _i < array_length(_all); _i++) {
        var _snd = _all[_i];
        var _want = false;
        for (var _j = 0; _j < array_length(_list); _j++) {
            if (_list[_j] == _snd) { _want = true; break; }
        }
        if (_want && !audio_is_playing(_snd)) audio_play_sound(_snd, 0, true);
        else if (!_want && audio_is_playing(_snd)) audio_stop_sound(_snd);
    }
}

// One-shot effects / UI stings - controlled by the SFX slider. (Only sounds
// that are actually played - see the note on audio_music_assets above.)
function audio_sfx_assets() {
    return [
        // (The pre-sound-pass library set - utility2/Check_1/spell1/hurt/etc. -
        // was retired in Batch 4: unidentified licenses, all uses rewired.)
        // Sound pass Batch 1 (SOUND_PASS_SPEC.md) - every import must be listed
        // here or it plays at full volume, ignoring the SFX slider.
        snd_ui_move, snd_ui_confirm, snd_ui_cancel, snd_ui_error,
        snd_ui_toggle_on, snd_ui_toggle_off,
        snd_dice_roll, snd_dice_roll_2, snd_dice_roll_3, snd_dice_shake,
        snd_dice_place, snd_dice_place_2, snd_kb_capture, snd_kb_payout, snd_kb_payout_2,
        snd_player_atk, snd_player_atk_2, snd_player_atk_3, snd_miss, snd_miss_2,
        snd_player_hurt, snd_player_hurt_2,
        snd_attack_undead, snd_death_undead, snd_attack_wraith, snd_death_wraith,
        snd_attack_construct, snd_death_construct, snd_attack_beast, snd_attack_beast_2,
        snd_death_beast, snd_attack_fire, snd_death_fire, snd_attack_ice, snd_death_ice,
        snd_attack_boss, snd_attack_boss_2, snd_death_boss,
        snd_cast_elem, snd_cast_elem_2, snd_cast_void, snd_cast_blood, snd_cast_blood_2,
        snd_cast_arcane, snd_cast_arcane_2, snd_cast_heal, snd_cast_shield,
        snd_cast_buff, snd_cast_buff_2, snd_cast_debuff,
        snd_sting_levelup, snd_sting_floor, snd_sting_victory, snd_sting_defeat,
        snd_sting_quest, snd_sting_mystery, snd_sting_heartbreak,
        snd_equip, snd_buy, snd_pet_hatch,
        snd_confirm_major, snd_npc_confirm, snd_sell,
        // Batch 2 - economy/items
        snd_gold, snd_potion, snd_forge, snd_rune_socket, snd_page, snd_chest, snd_gate,
        // Batch 4 - legacy-retirement replacements
        snd_player_grunt, snd_player_grunt_2, snd_move_whoosh,
    ];
}

// Ensure the volume globals + settings-overlay state exist (defaults on first boot),
// then load any saved values from settings.ini once per session. Settings live in a
// small ini independent of the per-slot save, so they persist even from the title.
function audio_settings_init() {
    if (!variable_global_exists("music_volume")) global.music_volume = 0.7;
    if (!variable_global_exists("sfx_volume"))   global.sfx_volume   = 0.8;
    if (!variable_global_exists("settings_open"))        global.settings_open        = false;
    if (!variable_global_exists("settings_cursor"))      global.settings_cursor      = 0;   // 0 Music, 1 SFX, 2 Menu Tick, 3 Fullscreen, 4 Tutorial, 5 Reset
    if (!variable_global_exists("settings_reset_flash")) global.settings_reset_flash = 0;
    if (!variable_global_exists("tutorial_enabled"))     global.tutorial_enabled     = true;
    if (!variable_global_exists("ui_tick_enabled"))      global.ui_tick_enabled      = true;   // the menu-nav glass ping

    if (!variable_global_exists("settings_loaded")) {
        global.settings_loaded = true;
        ini_open("settings.ini");
        global.music_volume     = clamp(ini_read_real("audio", "music", global.music_volume), 0, 1);
        global.sfx_volume       = clamp(ini_read_real("audio", "sfx",   global.sfx_volume),   0, 1);
        // Tutorial-tips preference lives here too so it persists from the title
        // (where no save slot is loaded). 1 = enabled (default), 0 = disabled.
        global.tutorial_enabled = (ini_read_real("ui", "tutorial_tips", 1) >= 0.5);
        global.ui_tick_enabled  = (ini_read_real("ui", "menu_tick", 1) >= 0.5);
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
    ini_write_real("ui", "menu_tick",
        ((!variable_global_exists("ui_tick_enabled")) || global.ui_tick_enabled) ? 1 : 0);
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
    // Per-asset trims (applied after the flat pass): sounds that master louder
    // than the rest of the bus. The nav ping fires constantly - keep it well
    // under the one-shot effects (M: "feels louder than other effects").
    audio_sound_gain(snd_ui_move, _sv * 0.45, 0);
    // Ambience beds sit well UNDER the music track, and the torch crackle is
    // a texture, not a sound you should notice. Tune here if F5 flags levels.
    audio_sound_gain(snd_amb_rain,  _mv * 0.50, 0);
    audio_sound_gain(snd_amb_cave,  _mv * 0.55, 0);
    audio_sound_gain(snd_amb_torch, _mv * 0.30, 0);
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

    // Rows: 0 Music, 1 SFX, 2 Menu Tick, 3 Fullscreen, 4 Tutorial Tips, 5 Reset Tutorial.
    if (nav_up())   global.settings_cursor = wrap_index(global.settings_cursor - 1, 6);
    if (nav_down()) global.settings_cursor = wrap_index(global.settings_cursor + 1, 6);
    global.settings_cursor = clamp(global.settings_cursor, 0, 5);

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
        case 2: // Menu Tick (the nav glass ping) on/off
            if (_left || _right || _confirm) {
                global.ui_tick_enabled = !global.ui_tick_enabled;
                // Turning it ON previews the tick itself; OFF gets the toggle thunk.
                audio_play_sound(global.ui_tick_enabled ? snd_ui_move : snd_ui_toggle_off, 1, false);
                audio_settings_save();
            }
        break;
        case 3: // Fullscreen
            if (_left || _right || _confirm) {
                video_toggle_fullscreen();
                audio_play_sound(window_get_fullscreen() ? snd_ui_toggle_on : snd_ui_toggle_off, 1, false);
            }
        break;
        case 4: // Tutorial Tips on/off
            if (_left || _right || _confirm) {
                if (!variable_global_exists("tutorial_enabled")) global.tutorial_enabled = true;
                global.tutorial_enabled = !global.tutorial_enabled;
                audio_play_sound(global.tutorial_enabled ? snd_ui_toggle_on : snd_ui_toggle_off, 1, false);
                audio_settings_save();
            }
        break;
        case 5: // Reset Tutorial - clear seen flags so every tip shows again
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
        audio_play_sound(snd_ui_cancel, 1, false);
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
