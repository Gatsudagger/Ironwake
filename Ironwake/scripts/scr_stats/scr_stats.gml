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

    // Dorn: 3 commons always; 40% chance 1 uncommon; 15% chance 1 rare
    global.dorn_stock = [];
    repeat (3) {
        var _c = global.loot_table_common[irandom(array_length(global.loot_table_common) - 1)];
        array_push(global.dorn_stock, { item: _c, price: floor(_c.gold_value * 1.5), sold: false });
    }
    if (irandom(99) < 40) {
        var _u = global.loot_table_uncommon[irandom(array_length(global.loot_table_uncommon) - 1)];
        array_push(global.dorn_stock, { item: _u, price: _u.gold_value * 2, sold: false });
    }
    if (irandom(99) < 15) {
        var _r = global.loot_table_rare[irandom(array_length(global.loot_table_rare) - 1)];
        array_push(global.dorn_stock, { item: _r, price: _r.gold_value * 2, sold: false });
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

    // Unlock Salvager when run level first reaches 5
    if (_gained > 0 && global.run_level >= 5
        && variable_global_exists("traits_unlocked")
        && !global.traits_unlocked.salvager) {
        global.traits_unlocked.salvager = true;
        if (instance_exists(obj_game_controller)) {
            var _gc_xp = instance_find(obj_game_controller, 0);
            _gc_xp.trait_notif_msg   = "TRAIT UNLOCKED: Salvager";
            _gc_xp.trait_notif_timer = 180;
        }
    }

    return _gained;
}

// ---------------------------------------------------------------------------
// add_gold(amount)
// Adds gold to both the lifetime pool and the current-run tracker.
// Always call this instead of writing global.gold directly so the per-run
// total stays accurate.
// ---------------------------------------------------------------------------
function add_gold(amount) {
    // Scavenger trait: +15% gold from all sources
    if (trait_active("Scavenger")) {
        amount = ceil(amount * 1.15);
    }
    global.gold             += amount;
    global.current_run_gold += amount;
}

// ---------------------------------------------------------------------------
// end_run(result)
// Called when a run concludes. Snapshots run totals into last_run_* for the
// hub summary, updates lifetime progression, and resets per-run accumulators.
//
// result: 1 = victory, -1 = defeat
//
// On victory, gold is already in global.gold via add_gold() — no double-add.
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

    if (result == 1) {
        // Victory — award hub unlock, record best floor, move carried items to safe stash
        global.hub_unlocks++;
        global.best_floor = max(global.best_floor, global.current_floor);
        for (var _ci = 0; _ci < array_length(global.carried_items); _ci++) {
            array_push(global.equipment_stash, global.carried_items[_ci]);
        }
        global.carried_items = [];
        global.last_run_mercy_item = "";
        // Consumables persist — player keeps unused potions

        // Permanent point conversion — only on full dungeon clear (floor 3+)
        if (global.current_floor >= 3) {
            if (variable_global_exists("run_level")) {
                if (global.run_level >= 15) {
                    _perm_earned = 3;
                } else if (global.run_level >= 10) {
                    _perm_earned = 2;
                } else if (global.run_level >= 5) {
                    _perm_earned = 1;
                }
                global.pending_perm_points += _perm_earned;
            }
            // Unlock Lucky Find on first full clear
            if (variable_global_exists("traits_unlocked") && !global.traits_unlocked.lucky_find) {
                global.traits_unlocked.lucky_find = true;
                if (instance_exists(obj_game_controller)) {
                    var _gc_lf = instance_find(obj_game_controller, 0);
                    _gc_lf.trait_notif_msg   = "TRAIT UNLOCKED: Lucky Find";
                    _gc_lf.trait_notif_timer = 180;
                }
            }
        }

    } else if (result == 0) {
        // Extraction — keep all gold, update best floor, move carried items to safe stash
        global.best_floor = max(global.best_floor, global.current_floor);
        for (var _ci = 0; _ci < array_length(global.carried_items); _ci++) {
            array_push(global.equipment_stash, global.carried_items[_ci]);
        }
        global.carried_items = [];
        global.last_run_mercy_item = "";
        // Consumables persist

    } else {
        // Defeat — keep 25% of run gold as mercy, lose the rest
        var _mercy_gold = floor(global.current_run_gold * 0.25);
        var _lost_gold  = global.current_run_gold - _mercy_gold;
        global.gold = max(0, global.gold - _lost_gold);
        global.last_run_mercy_gold = _mercy_gold;

        // Secure items first (trait feature — inert while secure_slots == 0)
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

        // Salvage items on death — Salvager trait keeps 2 random items instead of 1
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
}

// ---------------------------------------------------------------------------
// create_item(name, slot, rarity, stat_name, stat_value, effect_desc, gold_value)
// Returns an equipment item struct. Rarity: 0=common, 1=uncommon, 2=rare,
// 3=epic, 4=legendary.
// ---------------------------------------------------------------------------
function create_item(name, slot, rarity, stat_name, stat_value, effect_desc, gold_value) {
    return {
        name:          name,
        item_category: "equipment",
        slot:          slot,
        rarity:        rarity,
        stat_name:     stat_name,
        stat_value:    stat_value,
        effect_desc:   effect_desc,
        gold_value:    gold_value
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
        case 0: return c_white;                            // Common   — white
        case 1: return make_color_rgb(100, 200, 100);     // Uncommon — green
        case 2: return make_color_rgb(80, 140, 255);      // Rare     — blue
        case 3: return make_color_rgb(180, 80, 255);      // Epic     — purple
        case 4: return make_color_rgb(255, 160, 30);      // Legendary — orange
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
        item_category: "equipment",
        slot:          src.slot,
        rarity:        src.rarity,
        stat_name:     src.stat_name,
        stat_value:    src.stat_value,
        effect_desc:   src.effect_desc,
        gold_value:    src.gold_value,
        class_req:     variable_struct_exists(src, "class_req")     ? src.class_req     : -1,
        unique_effect: variable_struct_exists(src, "unique_effect") ? src.unique_effect : "",
        unique_desc:   variable_struct_exists(src, "unique_desc")   ? src.unique_desc   : "",
        affixes:       [],
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
    return _c;
}

// ---------------------------------------------------------------------------
// roll_affixes(rarity, count, exclude_stat_names)
// Returns an array of affix structs chosen from global.affix_pool.
// No duplicate stat_names. exclude_stat_names prevents doubling the base stat.
// rarity: 1=uncommon, 2=rare, 3=epic (determines magnitude).
// ---------------------------------------------------------------------------
function roll_affixes(rarity, count, exclude_stat_names) {
    if (!variable_global_exists("affix_pool")) return [];
    var _pool    = global.affix_pool;
    var _result  = [];
    var _used    = [];
    for (var _ei = 0; _ei < array_length(exclude_stat_names); _ei++) {
        array_push(_used, exclude_stat_names[_ei]);
    }

    var _tries = 0;
    while (array_length(_result) < count && _tries < 60) {
        _tries++;
        var _idx = irandom(array_length(_pool) - 1);
        var _af  = _pool[_idx];
        var _dup = false;
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
// Also rebuilds effect_desc to append affix stat descriptions.
// ---------------------------------------------------------------------------
function apply_affixes_to_item(item, affixes) {
    var _count = array_length(affixes);
    if (_count == 0) return;

    for (var _i = 0; _i < _count; _i++) {
        array_push(item.affixes, affixes[_i]);
    }

    // Name: 1 affix → append suffix; 2 affixes → prefix + name + last suffix
    if (_count == 1) {
        item.name = item.name + " " + affixes[0].suffix;
    } else {
        item.name = affixes[0].prefix + " " + item.name + " " + affixes[_count - 1].suffix;
    }

    // Append affix stats to effect_desc so all displays pick them up automatically
    for (var _i = 0; _i < _count; _i++) {
        var _af = affixes[_i];
        var _afdesc;
        if (_af.stat_name == "bonus_max_hp") {
            _afdesc = "+" + string(_af.stat_value) + " HP";
        } else if (_af.stat_name == "crit_flat") {
            _afdesc = "+" + string(_af.stat_value) + "% Crit";
        } else if (_af.stat_name == "dodge_flat") {
            _afdesc = "+" + string(_af.stat_value) + " Dodge";
        } else if (_af.stat_name == "gold_find") {
            _afdesc = "+" + string(_af.stat_value) + "% Gold";
        } else {
            _afdesc = "+" + string(_af.stat_value) + " " + _af.stat_name;
        }
        item.effect_desc += "  " + _afdesc;
    }

    // +20% gold_value per affix
    item.gold_value = round(item.gold_value * power(1.2, _count));
}

// ---------------------------------------------------------------------------
// drop_equipment(rarity_weights)
// Full drop pipeline: pick rarity, clone a base item, roll and apply affixes.
// rarity_weights: [common%, uncommon%, rare%, epic%, legendary%]
// Common=0 affixes, uncommon=1, rare=1-2 (50/50), epic=2, legendary=fixed.
// Shop stock calls roll_equipment() (no affixes) — this is for drops only.
// ---------------------------------------------------------------------------
function drop_equipment(rarity_weights) {
    if (!variable_global_exists("loot_table_common")
        || !variable_global_exists("loot_table_uncommon")
        || !variable_global_exists("loot_table_rare")) {
        return clone_item(create_item("Ashen Blade", "weapon", 0, "STR", 2, "+2 STR", 15));
    }

    var _roll = irandom(99);
    var _cum  = 0;
    var _rarity = 0;
    var _len = array_length(rarity_weights);
    for (var _r = 0; _r < _len; _r++) {
        _cum += rarity_weights[_r];
        if (_roll < _cum) { _rarity = _r; break; }
    }

    // Legendaries — return clone with pre-set affixes and unique fields
    if (_rarity == 4 && variable_global_exists("loot_table_legendary")
        && array_length(global.loot_table_legendary) > 0) {
        var _leg_tbl = global.loot_table_legendary;
        return clone_item(_leg_tbl[irandom(array_length(_leg_tbl) - 1)]);
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
        var _affixes = roll_affixes(_eff_rarity, _affix_count, [_item.stat_name]);
        apply_affixes_to_item(_item, _affixes);
    }

    return _item;
}

// ---------------------------------------------------------------------------
// equip_slot_index(slot_name)
// Maps a lowercase slot name to its index in global.inventory[0..7].
// Returns -1 for unknown names.
// ---------------------------------------------------------------------------
function equip_slot_index(slot_name) {
    switch (slot_name) {
        case "weapon":  return 0;
        case "offhand": return 1;
        case "helm":    return 2;
        case "chest":   return 3;
        case "gloves":  return 4;
        case "boots":   return 5;
        case "amulet":  return 6;
        case "ring":    return 7;
        default:        return -1;
    }
}

// ---------------------------------------------------------------------------
// apply_equipment_stats(stats_struct)
// Applies all equipped items' stat bonuses to stats_struct IN PLACE.
// "armor" and "el_resist" bonuses are NOT applied to stats_struct (they are
// separate combat fields); they are accumulated and returned as a struct.
// Always call on a COPY of chosen_stats — never the global itself.
// ---------------------------------------------------------------------------
function apply_equipment_stats(stats_struct) {
    // Extended bonus struct: armor/el_resist (old), plus affix-driven special fields.
    // bonus_max_hp  — flat HP added directly to player.max_HP after derive
    // crit_flat     — % added to all crit rolls (stored in stats_struct.crit_bonus)
    // dodge_flat    — flat added to player.dodge
    // gold_find     — % gold find bonus (display only; hook in add_gold for future use)
    var _bonus = { armor: 0, el_resist: 0, bonus_max_hp: 0, crit_flat: 0, dodge_flat: 0, gold_find: 0 };
    if (!variable_global_exists("inventory")) return _bonus;

    for (var _i = 0; _i < array_length(global.inventory); _i++) {
        var _it = global.inventory[_i];
        if (_it == undefined) continue;
        _equip_apply_stat(stats_struct, _bonus, _it.stat_name, _it.stat_value);

        // Apply affixes stored on the item (from drop_equipment or legendary fixed affixes)
        if (variable_struct_exists(_it, "affixes")) {
            for (var _a = 0; _a < array_length(_it.affixes); _a++) {
                var _af = _it.affixes[_a];
                _equip_apply_stat(stats_struct, _bonus, _af.stat_name, _af.stat_value);
            }
        }
    }
    return _bonus;
}

// Internal helper — routes a stat_name/stat_value pair to the correct target.
function _equip_apply_stat(stats_struct, bonus, stat_name, stat_value) {
    if (stat_name == "armor")        { bonus.armor        += stat_value; }
    else if (stat_name == "el_resist")   { bonus.el_resist   += stat_value; }
    else if (stat_name == "bonus_max_hp"){ bonus.bonus_max_hp += stat_value; }
    else if (stat_name == "crit_flat")   { bonus.crit_flat   += stat_value; }
    else if (stat_name == "dodge_flat")  { bonus.dodge_flat  += stat_value; }
    else if (stat_name == "gold_find")   { bonus.gold_find   += stat_value; }
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
// handle_enemy_drops(enemy_type)
// Rolls drops for a defeated enemy, pushes results into global inventories,
// and returns a log string describing what dropped ("" if nothing dropped).
// ---------------------------------------------------------------------------
function handle_enemy_drops(enemy_type) {
    if (!variable_global_exists("run_items_found"))      global.run_items_found      = [];
    if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];

    if (!variable_global_exists("carried_items")) global.carried_items = [];

    if (enemy_type == "standard") {
        // Lucky Find trait: +5% consumable drop chance (10% → 15%)
        var _cons_chance = trait_active("Lucky Find") ? 15 : 10;
        if (irandom(99) < _cons_chance) {
            var _c = roll_consumable(global.consumables_standard);
            array_push(global.run_items_found, _c);
            array_push(global.consumable_inventory, _c);
            return _c.name + " [Consumable]";
        }
        // 5% equipment drop: 70% common, 25% uncommon, 5% rare — affixes applied via drop_equipment
        if (irandom(99) < 5) {
            var _item = drop_equipment([70, 25, 5]);
            array_push(global.run_items_found, _item);
            array_push(global.carried_items, _item);
            return _item.name + " [" + item_rarity_name(_item.rarity) + "]";
        }

    } else if (enemy_type == "elite") {
        // Lucky Find trait: +5% consumable drop chance (60% → 65%)
        var _elite_cons_chance = trait_active("Lucky Find") ? 65 : 60;
        if (irandom(99) < _elite_cons_chance) {
            var _c = roll_consumable(global.consumables_elite);
            array_push(global.run_items_found, _c);
            array_push(global.consumable_inventory, _c);
            return _c.name + " [Consumable]";
        }
        // 40% equipment drop: 20% common, 45% uncommon, 30% rare, 5% epic
        if (irandom(99) < 40) {
            var _item = drop_equipment([20, 45, 30, 5]);
            array_push(global.run_items_found, _item);
            array_push(global.carried_items, _item);
            return _item.name + " [" + item_rarity_name(_item.rarity) + "]";
        }

    } else if (enemy_type == "boss") {
        // Guaranteed equipment: 0% common, 20% uncommon, 50% rare, 25% epic, 5% legendary
        var _item = drop_equipment([0, 20, 50, 25, 5]);
        array_push(global.run_items_found, _item);
        array_push(global.carried_items, _item);
        var _result = _item.name + " [" + item_rarity_name(_item.rarity) + "]";
        // 50% bonus consumable
        if (irandom(99) < 50) {
            var _c = roll_consumable(global.consumables_elite);
            array_push(global.run_items_found, _c);
            array_push(global.consumable_inventory, _c);
            _result += " + " + _c.name;
        }
        return _result;
    }

    return "";
}

// ---------------------------------------------------------------------------
// Class preset base stat tables (before 4 free points are allocated).
// Each entry: [STR, DEX, CON, INT, WIS, CHA]
// ---------------------------------------------------------------------------
global.class_presets = [
    // 0 — Arcanist
    { name: "Arcanist",     STR: 3, DEX: 4, CON: 4, INT: 9, WIS: 6, CHA: 5 },
    // 1 — Bloodwarden
    { name: "Bloodwarden",  STR: 6, DEX: 3, CON: 8, INT: 4, WIS: 5, CHA: 4 },
    // 2 — Shadowstrider
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
    // CHA is reserved for social/NPC systems; no derived combat value yet.

    return {
        // Maximum hit points — constitution is the primary driver
        HP:              10 + (CON * 4),

        // Flat accuracy bonus added to attack rolls
        ACC_modifier:    DEX * 3,

        // Flat dodge value subtracted from incoming hit chance
        DODGE:           DEX * 2,

        // Crit chances — each stat contributes differently
        // Physical builds favour STR; precision builds favour DEX; casters INT
        STR_crit_chance: STR * 1.5,
        DEX_crit_chance: DEX * 2,
        INT_crit_chance: INT * 1,

        // WIS crit always has a 5-point floor so all classes have some crit
        WIS_crit_chance: 5 + (WIS * 1.5),

        // Number of spell slots — INT-based, minimum 1 so non-mages can still
        // equip utility spells
        spell_slots:     max(1, INT),
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
        // Refunding points — restore them to the free pool
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
