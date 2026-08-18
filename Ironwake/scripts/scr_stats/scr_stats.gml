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
    // Caravan Contacts (Petra rank 1, M 08-15): her special shelf never runs
    // empty and carries double stock (was a 50% roll at qty 1-2).
    if (npc_rank("petra") >= 1 || irandom(99) < 50) {
        global.petra_stock_special = roll_consumable(global.consumables_elite);
        global.petra_special_qty   = (npc_rank("petra") >= 1) ? (2 + irandom(1)) : (1 + irandom(1));
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
                      + (affinity_at_least("dorn", 3) ? 1 : 0)    // Companion perk: +1 stock slot
                      + ((npc_rank("dorn") >= 1) ? 2 : 0);        // Widened Stall rank perk (08-15)
    var _dorn_disc    = affinity_discount_mult("dorn");           // Friend perk: 10% off (baked at restock)
    repeat (_dorn_count) {
        var _di     = drop_equipment(_dorn_weights, false);
        // Dorn sells decent wares, not finished ones (SYSTEMS_ITEM_PROGRESSION §1,
        // tuned 08-05; 08-18 nerf): his stock re-rolls quality 56-72 over the standard 45-70.
        item_quality_stamp(_di, 56, 72);   // 08-18 quality nerf (Dorn shop)
        // Rare/Epic+ gear is a premium buy - roughly double the markup so a strong
        // piece is a real gold sink, not a cheap upgrade. (Task: Dorn rare/epic cost)
        var _dmarkup = (_di.rarity >= 2) ? 3.2 : 1.6;
        var _dprice  = max(1, floor(_di.gold_value * _dmarkup * _dorn_disc));
        array_push(global.dorn_stock, { item: _di, price: _dprice, sold: false });
    }
    // Rare thrill (M 07-29): below A4 Dorn's weights hold NO legendaries, but a
    // 1-in-200 restock still sneaks one in - a jackpot, not an expectation.
    if (_dorn_awk < 4 && irandom(199) == 0 && array_length(global.dorn_stock) > 0) {
        var _dlj  = drop_equipment([0, 0, 0, 0, 100], false);
        item_quality_stamp(_dlj, 56, 72);   // shop-grade roll (08-05; 08-18 quality nerf)
        var _dljp = max(1, floor(_dlj.gold_value * 3.2 * _dorn_disc));
        global.dorn_stock[0] = { item: _dlj, price: _dljp, sold: false };
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
                    item_quality_stamp(_dp, 56, 72);   // shop-grade roll (08-05; 08-18 quality nerf)
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
    // Lucky Find (the NEW one, 07-08 identity split): +5% gold from all sources.
    // POTENCY V2: strength scales +10%/rank like the other numeric traits.
    if (trait_active("Lucky Find")) amount = ceil(amount * (1 + 0.05 * trait_potency_mult("Lucky Find")));
    // Mandate from Heaven potency R2-4 (P4, 08-01): +4%/rank gold find while a
    // Legendary is equipped - the heavens favor a ratified claim.
    if (trait_active("Mandate from Heaven") && player_has_legendary_equipped()) {
        var _mh_r = max(0, trait_potency_r14("Mandate from Heaven") - 1);
        if (_mh_r > 0) amount = ceil(amount * (1 + 0.04 * _mh_r));
    }
    // Beggar's Fortune (07-28 legendary): +25% found gold - shops tax it back
    // at +10% (beggar_price_mult in cha_price).
    if (legendary_worn("beggars_fortune")) amount = ceil(amount * 1.25);
    // Gear "gold_find" affix (e.g. "of Greed"/"Lucky", +N%): boosts found gold.
    // apply_equipment_stats sums it across base stat + affixes + gear runes; a
    // throwaway struct is passed because we only need the returned gold_find total.
    var _gear_gf = apply_equipment_stats({}).gold_find;
    if (_gear_gf > 0) amount = ceil(amount * (1 + _gear_gf / 100));
    // Charisma: gold-find bonus on all earned gold (add_gold is the found-gold path;
    // item sells write global.gold directly and are intentionally unaffected).
    var _gf = cha_gold_find();
    if (_gf > 0) amount = ceil(amount * (1 + _gf));
    // IN COLLECTIONS (Debtor origin, 08-11): the creditor garnishes a quarter
    // of everything earned, at the source, until the debt clears.
    amount = debt_garnish(amount);
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
// legendary_worn(effect_id) - is a legendary with this unique_effect currently
// EQUIPPED? Live scan of the worn slots (10 entries - cheap) so hub screens
// react the moment gear changes. Hub-side legendary hooks read this; combat
// hooks use the per-combat player flags instead.
function legendary_worn(effect_id) {
    if (!variable_global_exists("inventory")) return false;
    for (var _i = 0; _i < array_length(global.inventory); _i++) {
        var _it = global.inventory[_i];
        if (is_struct(_it) && variable_struct_exists(_it, "unique_effect")
            && _it.unique_effect == effect_id) return true;
    }
    return false;
}

// ANY legendary equipped (P4 Mandate ranks 2-4 read this - the heavens favor a
// ratified claim). Same equipped-scan as legendary_worn, keyed on rarity.
function player_has_legendary_equipped() {
    if (!variable_global_exists("inventory")) return false;
    for (var _i = 0; _i < array_length(global.inventory); _i++) {
        var _it = global.inventory[_i];
        if (is_struct(_it) && variable_struct_exists(_it, "rarity") && _it.rarity >= 4) return true;
    }
    return false;
}

// Hollow King's Signet (-15%) and Beggar's Fortune (+10% - its gold-find boon's
// tax) both bend every vendor price, on top of the Charisma discount.
function signet_price_mult() { return legendary_worn("hollow_kings_signet") ? 0.85 : 1.0; }
function beggar_price_mult() { return legendary_worn("beggars_fortune")     ? 1.10 : 1.0; }
function cha_price(base_gold) {
    return max(1, round(base_gold * (1 - cha_discount()) * signet_price_mult() * beggar_price_mult()
        * origin_price_mult()));   // Gutter Orphan origin: 5% off everywhere (08-11)
}

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
    // IRONMAN resume: the run is concluding by a REAL exit (clear, extract, or
    // death) - the checkpoint must not survive it. Deleted first so nothing
    // below can leave a resurrectable file behind. (SYSTEMS_RUN_RESUME.md)
    run_checkpoint_delete();
    global.run_extract_pending = false;

    var _perm_earned = 0;
    var _end_level   = 1;
    if (variable_global_exists("run_level")) {
        _end_level = global.run_level;
    }
    global.run_found_pets = [];   // run-scoped "creatures found" strip (equipment Found column)
    // Per-run station-rank charges re-arm here (M-locked 08-15): Maren's Deep
    // Socket and Vael's free portrait change are once PER RUN. The garden's
    // completed cairn spends its blessing here too - the stones topple while
    // you're below, ready to be stacked again.
    global.deep_socket_used   = false;
    global.vael_portrait_free = (npc_rank("vael") >= 2);
    global.garden_cairn       = 0;
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
    // Memories -> quirks (08-01, pillar C): the carried pet's history resolves.
    var _pet_qk = pet_quirk_resolve_run_end(result);
    if (_pet_qk != "" && variable_global_exists("pet_find_notice")) {
        global.pet_find_notice = (global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _pet_qk) : _pet_qk;
    }
    // Garden deepening (08-01): the donated residents grow too on a survived run.
    var _gdn_msg = bairc_garden_run_tick(result);
    if (_gdn_msg != "" && variable_global_exists("pet_find_notice")) {
        global.pet_find_notice = (global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _gdn_msg) : _gdn_msg;
    }
    // Hunger upkeep (07-08): the whole roster works up an appetite each run.
    // Runs AFTER pet_run_complete so its gates read pre-drain hunger; a pet that
    // just went hungry gets a heads-up before it starts underperforming.
    pet_hunger_run_tick();
    var _act_hp = pet_active();
    if (_act_hp != undefined && !_act_hp.is_egg && variable_global_exists("pet_find_notice")) {
        var _hst = pet_hunger_state(_act_hp);
        if (_hst == "hungry" || _hst == "starving") {
            var _hnote = (_hst == "starving")
                ? (_act_hp.name + " is STARVING - it will not act at all until fed at Bairc.")
                : (_act_hp.name + " is hungry - it fights at 3/4 strength and bonds with no one until fed.");
            global.pet_find_notice = (global.pet_find_notice != "")
                ? (global.pet_find_notice + "   " + _hnote) : _hnote;
        }
    }
    // Treats reset with the run (max 2 per run, pet_treats_left).
    global.pet_treats_run = 0;

    // Reset Last Stand for the next run (consumed at most once per run in combat)
    if (variable_global_exists("last_stand_used")) global.last_stand_used = false;

    // Banshee in a Bottle: carried bottles bank on any SURVIVED run (clear or
    // extract - "clear counts as the perfect extraction"). M 08-15: bottles
    // now SURVIVE DEATH too - they're rare enough that shattering them with
    // the haul felt punitive; a found song always makes it home.
    banshee_init();
    if (global.banshee_carried > 0) {
        global.banshee_banked += global.banshee_carried;
        var _bb_msg = (global.banshee_carried == 1)
            ? "The Banshee in a Bottle made it out with you - Maren can release its spirit."
            : string(global.banshee_carried) + " Banshees in Bottles made it out with you - Maren can release their spirits.";
        if (result < 0) _bb_msg = "Even in defeat, the corked bottle stayed whole - Maren can release its spirit.";
        if (variable_global_exists("pet_find_notice")) {
            global.pet_find_notice = (global.pet_find_notice != "")
                ? (global.pet_find_notice + "   " + _bb_msg) : _bb_msg;
        }
    }
    global.banshee_carried = 0;

    // ORIGINS (08-11): per-run grants re-arm for the next run, and the
    // Debtor's creditor collects at the camp gate (win or lose).
    global.origin_run_granted = false;
    var _debt_msg = debt_collect_run_end();
    if (_debt_msg != "" && variable_global_exists("pet_find_notice")) {
        global.pet_find_notice = (global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _debt_msg) : _debt_msg;
    }

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
                    // AWAKENING BOOST (SYSTEMS_ENDLESS.md §1): a FIRST-TIME tier
                    // clear also earns a popup pick - raise ONE other dungeon's
                    // awakening by +1 (cap A5). Shown on hub arrival.
                    global.awaken_boost_pending = true;
                    global.awaken_boost_from    = _dung_key;
                }
                // A6+ PROPAGATING UNLOCKS (SYSTEMS_ENDLESS.md §2, post-win only):
                // clearing the endless frontier in ANY dungeon opens the next
                // tier in ALL of them.
                if (variable_global_exists("ironwake_stands") && global.ironwake_stands
                    && global.selected_ascendance >= 5) {
                    if (!variable_global_exists("endless_awakening_unlocked")) global.endless_awakening_unlocked = 5;
                    if (global.selected_ascendance >= global.endless_awakening_unlocked) {
                        global.endless_awakening_unlocked = global.selected_ascendance + 1;
                    }
                }
                // Bonus gold reward scales with ascendance tier (table shared with
                // the dungeon-select AWAKENING EFFECTS panel via awaken_clear_gold_bonus)
                add_gold(awaken_clear_gold_bonus(global.selected_ascendance));
                // Scale run gold by 15% per ascendance tier (already added via add_gold during run)
                // - this bonus is on top, applied as a flat completion bonus

                // WIN STATE (WIN_STATE_SPEC.md): an Awakening-V full clear marks this
                // dungeon; the third mark arms the ending, which plays on hub arrival.
                if (global.selected_ascendance >= 5) {
                    if (!variable_global_exists("dungeon_a5_clears")) {
                        global.dungeon_a5_clears = { ashen_vault: false, scorched_depths: false, tundra_tomb: false };
                    }
                    variable_struct_set(global.dungeon_a5_clears, _dung_key, true);
                    if (!variable_global_exists("ironwake_stands")) global.ironwake_stands = false;
                    if (!global.ironwake_stands
                        && global.dungeon_a5_clears.ashen_vault
                        && global.dungeon_a5_clears.scorched_depths
                        && global.dungeon_a5_clears.tundra_tomb) {
                        global.ironwake_stands = true;
                        global.ending_pending  = true;
                        // THE IRON VOW (SYSTEMS_IRON_VOW.md): winning under a
                        // Vow grants its exclusive epithet (cosmetic prestige;
                        // changeable at Vael afterward like any epithet).
                        if (variable_global_exists("vow_mode") && global.vow_mode == 1) global.player_epithet = "the Thrice-Tempered";
                        if (variable_global_exists("vow_mode") && global.vow_mode == 2) global.player_epithet = "the Unbroken";
                    }
                }
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
        // POTENCY V2 ranks: keep 3 at rank 2, 4 at rank 4. (The TRANSCEND
        // "Nothing Wasted" - equipped items also survive - is honored at the
        // equipped-items death handler, not this carried-items pool.)
        var _sv_r = trait_potency_r14("Salvager");
        var _salvage_count = trait_active("Salvager") ? (2 + (_sv_r >= 2 ? 1 : 0) + (_sv_r >= 4 ? 1 : 0)) : 1;
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

        // DESCENT HARDCORE (SYSTEMS_ENDLESS.md §3): death in a hardcore descent
        // can also claim EQUIPPED gear. Severity 1 "Hardcore": one random
        // equipped slot. Severity 2 "Merciless": every equipped item 50/50.
        // Salvager's TRANSCEND "Nothing Wasted" (POTENCY V2) protects it all.
        if (variable_global_exists("descent_active") && global.descent_active
            && variable_global_exists("descent_hardcore") && global.descent_hardcore > 0
            && variable_global_exists("inventory")) {
            if (trait_transcended("Salvager")) {
                if (variable_global_exists("pet_find_notice"))
                    global.pet_find_notice = "Nothing Wasted: the dark took nothing you wore.";
            } else {
                var _hc_lost = "";
                if (global.descent_hardcore == 1) {
                    var _hc_slots = [];
                    for (var _hi = 0; _hi < array_length(global.inventory); _hi++) {
                        if (global.inventory[_hi] != undefined) array_push(_hc_slots, _hi);
                    }
                    if (array_length(_hc_slots) > 0) {
                        var _hs = _hc_slots[irandom(array_length(_hc_slots) - 1)];
                        _hc_lost = global.inventory[_hs].name;
                        global.inventory[_hs] = undefined;
                    }
                } else {
                    for (var _hi2 = 0; _hi2 < array_length(global.inventory); _hi2++) {
                        if (global.inventory[_hi2] == undefined) continue;
                        if (irandom(1) == 0) {
                            _hc_lost += ((_hc_lost != "") ? ", " : "") + global.inventory[_hi2].name;
                            global.inventory[_hi2] = undefined;
                        }
                    }
                }
                if (_hc_lost != "" && variable_global_exists("pet_find_notice")) {
                    global.pet_find_notice = "The Descent claimed what you wore: " + _hc_lost + ".";
                }
            }
        }

        global.carried_items = [];
        global.secured_items = [];
    }

    // THE DESCENT bookkeeping: record the deepest floor reached (any outcome),
    // then normalize the fractional effective tier back to A5 and stand down.
    if (variable_global_exists("descent_active") && global.descent_active) {
        if (!variable_global_exists("descent_best")) global.descent_best = 0;
        global.descent_best        = max(global.descent_best, global.current_floor);
        global.descent_active      = false;
        global.selected_ascendance = 5;
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

    // --- Steam achievements: run-outcome hooks (08-05 wiring). result: 1 full
    // clear / 0 extraction / -1 death. ---
    if (result == 1) {
        // Gatekeepers (first full clear per dungeon) + class mastery.
        var _ach_d = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "";
        if (_ach_d == "scorched_depths") ach_unlock("ACH_FC_DEPTHS");
        if (_ach_d == "tundra_tomb")     ach_unlock("ACH_FC_TOMB");
        if (_ach_d == "ashen_vault")     ach_unlock("ACH_FC_VAULT");
        switch (variable_global_exists("chosen_class") ? global.chosen_class : -1) {
            case 0: ach_unlock("ACH_CLR_ARCANIST"); break;
            case 1: ach_unlock("ACH_CLR_BLOOD");    break;
            case 2: ach_unlock("ACH_CLR_SHADOW");   break;
        }
        // Risk set: a WON run (full clear) carrying curses / under a Vow. "Mega
        // curse" reads as a tier-3 altar curse (Doom/Damnation/Ruin/Devil's Pact).
        var _ach_nc = variable_global_exists("run_curses") ? array_length(global.run_curses) : 0;
        if (_ach_nc >= 1) ach_unlock("ACH_PACT_BOUND");
        if (_ach_nc >= 3) ach_unlock("ACH_CURSES_3");
        for (var _aci = 0; _aci < _ach_nc; _aci++) {
            var _ac_def = curse_get(global.run_curses[_aci]);
            if (_ac_def != undefined && _ac_def.tier >= 3) { ach_unlock("ACH_MEGA_CURSE"); break; }
        }
        if (variable_global_exists("vow_mode") && global.vow_mode > 0) ach_unlock("ACH_IRON_VOW");
    }
    // Cauldron Roulette: drank a Chaotic Brew this run and lived to tell it.
    if (result >= 0 && variable_global_exists("ach_brew_run") && global.ach_brew_run) {
        ach_unlock("ACH_BREW");
    }
    global.ach_brew_run     = false;   // run-scoped flags reset for the next dive
    global.ach_run_absorbed = 0;

    global.current_run_gold    = 0;
    global.current_run_kills   = 0;
    global.run_current_hp      = 0;
    global.run_borrowed_ability = "";   // Borrowed Memory is run-scoped (expression #6)
    global.run_borrowed_class   = "";
    run_honing_clear();                 // Whetstone honing is run-scoped (07-17)
    global.run_souls           = 0;
    global.run_blood           = 0;
    global.run_preparation     = 0;
    global.run_items_found     = [];
    // consumable_inventory is managed per-result above for defeat;
    // for victory/extract it is left intact so potions carry forward.
    // Blood Tithe blessing (Shrine V2, 07-29): the pouch of pain-gold pays out on
    // a SURVIVED run (extract/clear); death forfeits it. Paid before the boon list
    // clears below so boon_active still sees it.
    if (variable_global_exists("bloodtithe_bank") && global.bloodtithe_bank > 0) {
        if (result >= 0 && boon_active("bloodtithe")) {
            add_gold(global.bloodtithe_bank);
            if (variable_global_exists("pet_find_notice")) {
                var _bt_msg = "Blood Tithe pays out: +" + string(global.bloodtithe_bank) + "g for the blood you spilled.";
                global.pet_find_notice = (global.pet_find_notice != "")
                    ? (global.pet_find_notice + "   " + _bt_msg) : _bt_msg;
            }
        }
        global.bloodtithe_bank = 0;
    }
    // Shrine V2 run-scoped counters die with the run.
    global.gambler_cd   = 0;
    global.gambler_proc = false;
    global.feast_stacks = 0;
    global.unbroken_shield = 0;   // Soul Shield "Unbroken" carryover ends with the run
    // Ashen Duelist run-scoped state (the lifetime ledger persists in the save).
    global.duel_offered_this_run = false;
    global.duel_launch           = false;
    global.duel_active           = false;

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
// discover_item(item_name, rarity)
// Records an item name as discovered. Called on drop and on shop purchase.
// CODEX PASS (07-29, M: "not a single epic item"): epics are RARE bases rolled
// up to rarity 3 at drop time, so name-only discovery could never show them.
// The optional rarity records the BEST rarity ever seen per base
// (global.items_discovered_best, saved) - the codex tints and labels from it.
// ---------------------------------------------------------------------------
function discover_item(item_name, rarity = -1) {
    if (!variable_global_exists("items_discovered")) global.items_discovered = [];
    if (!variable_global_exists("items_discovered_best") || !is_struct(global.items_discovered_best)) {
        global.items_discovered_best = {};
    }
    if (rarity >= 0) {
        var _prev = variable_struct_exists(global.items_discovered_best, item_name)
            ? variable_struct_get(global.items_discovered_best, item_name) : -1;
        if (rarity > _prev) variable_struct_set(global.items_discovered_best, item_name, rarity);
    }
    for (var _di = 0; _di < array_length(global.items_discovered); _di++) {
        if (global.items_discovered[_di] == item_name) return;
    }
    array_push(global.items_discovered, item_name);
}

// True when a base item name has been discovered (codex lookup).
function item_is_discovered(item_name) {
    if (!variable_global_exists("items_discovered")) return false;
    for (var _di = 0; _di < array_length(global.items_discovered); _di++) {
        if (global.items_discovered[_di] == item_name) return true;
    }
    return false;
}

// Best rarity this base has ever been SEEN at (drop/purchase), or its own base
// rarity when nothing better is recorded. Feeds the codex tint + "seen at" tag.
function item_discovered_best_rarity(base_item) {
    var _r = variable_struct_exists(base_item, "rarity") ? base_item.rarity : 0;
    if (variable_global_exists("items_discovered_best") && is_struct(global.items_discovered_best)
        && variable_struct_exists(global.items_discovered_best, base_item.name)) {
        _r = max(_r, variable_struct_get(global.items_discovered_best, base_item.name));
    }
    return _r;
}

// The codex's master list, in display order with SECTION HEADER rows:
// COMMON / UNCOMMON / RARE / EPIC / LEGENDARY / EARNED. SINGLE SOURCE for the
// journal tab, its Step nav and the discovered counter - the old gallery built
// this in four places and silently drifted (07-29 pass).
// EPIC SECTION (07-29 round 2, M: "it goes from rare to legendary... no
// purple"): epics have no loot table of their own - they are rare bases rolled
// to rarity 3 with 2 greater affixes - so each rare base gets a dedicated
// purple entry here, ??? until that base has been SEEN at epic
// (items_discovered_best ledger). Cached once: create_item rolls weapon damage
// at creation, so rebuilding the epic clones every frame would flicker.
function item_codex_master_list() {
    if (variable_global_exists("codex_master_cache") && is_array(global.codex_master_cache)
        && array_length(global.codex_master_cache) > 0) return global.codex_master_cache;
    var _out = [];
    if (variable_global_exists("loot_table_common")) {
        array_push(_out, { codex_header: true, title: "COMMON", name: "", slot: "", rarity: 0 });
        for (var _gi = 0; _gi < array_length(global.loot_table_common);   _gi++) array_push(_out, global.loot_table_common[_gi]);
    }
    if (variable_global_exists("loot_table_uncommon")) {
        array_push(_out, { codex_header: true, title: "UNCOMMON", name: "", slot: "", rarity: 1 });
        for (var _gi = 0; _gi < array_length(global.loot_table_uncommon); _gi++) array_push(_out, global.loot_table_uncommon[_gi]);
    }
    if (variable_global_exists("loot_table_rare")) {
        array_push(_out, { codex_header: true, title: "RARE", name: "", slot: "", rarity: 2 });
        for (var _gi = 0; _gi < array_length(global.loot_table_rare);     _gi++) array_push(_out, global.loot_table_rare[_gi]);
        // EPIC band: one purple entry per rare base, viewed at rarity 3.
        array_push(_out, { codex_header: true, title: "EPIC", name: "", slot: "", rarity: 3 });
        for (var _gi = 0; _gi < array_length(global.loot_table_rare);     _gi++) {
            var _ep = clone_item(global.loot_table_rare[_gi]);
            _ep.rarity       = 3;
            _ep.codex_epic   = true;
            _ep.socket_count = rune_sockets_for_rarity(3);
            array_push(_out, _ep);
        }
    }
    if (variable_global_exists("loot_table_legendary")) {
        array_push(_out, { codex_header: true, title: "LEGENDARY", name: "", slot: "", rarity: 4 });
        for (var _gi = 0; _gi < array_length(global.loot_table_legendary); _gi++) array_push(_out, global.loot_table_legendary[_gi]);
    }
    // Earned specials outside the drop pools - listed as ??? until found, so
    // the codex itself teases the hidden progression.
    array_push(_out, { codex_header: true, title: "EARNED", name: "", slot: "", rarity: 4 });
    if (!variable_global_exists("codex_ashen_blade")) global.codex_ashen_blade = duelist_make_ashen_blade();
    array_push(_out, global.codex_ashen_blade);
    // Only latch the cache once the loot tables actually existed - caching an
    // early/incomplete build would truncate the codex for the whole session.
    if (variable_global_exists("loot_table_common")) global.codex_master_cache = _out;
    return _out;
}

// True for the non-selectable section-title rows in the codex list.
function codex_entry_is_header(e) {
    return is_struct(e) && variable_struct_exists(e, "codex_header") && e.codex_header;
}

// Per-ROW discovery: base rows light up when the name has been seen at all;
// EPIC rows only when the base has been SEEN at epic (the best-rarity ledger -
// item_discovered_best_rarity can't be used here, it floors at the entry's own
// rarity which is already 3 on the epic clones).
function codex_entry_discovered(e) {
    if (codex_entry_is_header(e)) return false;
    if (variable_struct_exists(e, "codex_epic") && e.codex_epic) {
        if (variable_global_exists("items_discovered_best") && is_struct(global.items_discovered_best)
            && variable_struct_exists(global.items_discovered_best, e.name)) {
            return variable_struct_get(global.items_discovered_best, e.name) >= 3;
        }
        return false;
    }
    return item_is_discovered(e.name);
}

// Cursor move that hops over header rows (wraps like the other journal tabs).
function codex_nav_move(cur, dir, list) {
    var _n = array_length(list);
    if (_n <= 0) return 0;
    var _i = wrap_index(cur + dir, _n);
    var _g = 0;
    while (codex_entry_is_header(list[_i]) && _g < _n) { _i = wrap_index(_i + dir, _n); _g++; }
    return _i;
}

// Backfill the best-rarity ledger from everything the player currently OWNS
// (worn gear, hub stash, carried run loot). Pre-codex-pass saves only stored
// discovered NAMES, so epics found before 07-29 had no recorded rarity - this
// lights up any epic still in the player's possession the moment the save
// loads. (Epics found and sold before the pass are unrecoverable - nothing
// ever wrote their rarity down.)
function codex_backfill_owned() {
    var _pools = [];
    if (variable_global_exists("inventory")       && is_array(global.inventory))       array_push(_pools, global.inventory);
    if (variable_global_exists("equipment_stash") && is_array(global.equipment_stash)) array_push(_pools, global.equipment_stash);
    if (variable_global_exists("run_items_found") && is_array(global.run_items_found)) array_push(_pools, global.run_items_found);
    if (variable_global_exists("carried_items")   && is_array(global.carried_items))   array_push(_pools, global.carried_items);
    if (variable_global_exists("secured_items")   && is_array(global.secured_items))   array_push(_pools, global.secured_items);
    for (var _pi = 0; _pi < array_length(_pools); _pi++) {
        var _pool = _pools[_pi];
        for (var _ii = 0; _ii < array_length(_pool); _ii++) {
            var _it = _pool[_ii];
            if (is_struct(_it) && variable_struct_exists(_it, "item") && is_struct(_it.item)) _it = _it.item;
            if (is_struct(_it) && variable_struct_exists(_it, "rarity")) {
                discover_item(item_base_name(_it), _it.rarity);
            }
        }
    }
}

// veil_slot_fixup() - one-time save migration (07-30): Veil of the Patient Dark
// moved offhand -> helm. Saved item structs carry the stale slot baked in, and
// the equip flow places items by item.slot, so without this an old Veil would
// keep equipping into the offhand forever. Mutates in place (structs are
// references); if the fixed Veil was EQUIPPED next to another helm, the Veil
// steps down to the stash rather than double-occupying the slot.
function veil_slot_fixup() {
    var _pools = [];
    if (variable_global_exists("inventory")       && is_array(global.inventory))       array_push(_pools, global.inventory);
    if (variable_global_exists("equipment_stash") && is_array(global.equipment_stash)) array_push(_pools, global.equipment_stash);
    if (variable_global_exists("run_items_found") && is_array(global.run_items_found)) array_push(_pools, global.run_items_found);
    if (variable_global_exists("carried_items")   && is_array(global.carried_items))   array_push(_pools, global.carried_items);
    if (variable_global_exists("secured_items")   && is_array(global.secured_items))   array_push(_pools, global.secured_items);
    for (var _pi = 0; _pi < array_length(_pools); _pi++) {
        var _pool = _pools[_pi];
        for (var _ii = 0; _ii < array_length(_pool); _ii++) {
            var _it = _pool[_ii];
            if (is_struct(_it) && variable_struct_exists(_it, "item") && is_struct(_it.item)) _it = _it.item;
            if (is_struct(_it) && item_base_name(_it) == "Veil of the Patient Dark"
                && variable_struct_exists(_it, "slot") && _it.slot == "offhand") {
                _it.slot = "helm";
            }
        }
    }
    // Equipped-slot collision: two "helm" items in the equipped array means the
    // migrated Veil shares the slot with a real helm - stash the Veil.
    if (variable_global_exists("inventory") && is_array(global.inventory)
        && variable_global_exists("equipment_stash") && is_array(global.equipment_stash)) {
        var _helms = 0;
        for (var _hi = 0; _hi < array_length(global.inventory); _hi++) {
            var _hit = global.inventory[_hi];
            if (is_struct(_hit) && variable_struct_exists(_hit, "slot") && _hit.slot == "helm") _helms++;
        }
        if (_helms > 1) {
            for (var _vi = array_length(global.inventory) - 1; _vi >= 0; _vi--) {
                var _vit = global.inventory[_vi];
                if (is_struct(_vit) && item_base_name(_vit) == "Veil of the Patient Dark") {
                    array_delete(global.inventory, _vi, 1);
                    array_push(global.equipment_stash, _vit);
                    break;
                }
            }
        }
    }
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
        case "crit_spell":   return "spell critical chance";
        case "crit_phys":    return "physical critical chance";
        case "dodge_flat":   return "evasion";
        case "gold_find":    return "gold found";
    }
    return "general utility";
}

// item_slot_noun(slot) - readable noun for a slot, used in generic descriptions.
function item_slot_noun(slot) {
    switch (slot) {
        case "weapon":        return "melee weapon";
        case "ranged_weapon": return "ranged weapon";   // was missing -> "piece of equipment" (M 08-15 shot)
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

// item_slot_title(slot) - display-cased slot name for headers/breadcrumbs
// ("Melee Weapon"), where item_slot_noun's sentence form ("piece of headgear")
// reads as lowercase dev text (M 08-15 blueprint-wizard shot).
function item_slot_title(slot) {
    switch (slot) {
        case "weapon":        return "Melee Weapon";
        case "ranged_weapon": return "Ranged Weapon";
        case "offhand":       return "Offhand";
        case "helm":          return "Helm";
        case "chest":         return "Chest Armor";
        case "gloves":        return "Gloves";
        case "boots":         return "Boots";
        case "amulet":        return "Amulet";
        case "ring":          return "Ring";
    }
    return "Equipment";
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
        var _reach = (_slot == "weapon") ? "melee" : "ranged";
        var _hands = (variable_struct_exists(base_item, "two_handed") && base_item.two_handed) ? "2H" : "1H";
        // Hand-tuned budgets (2H, legendaries) show their fixed value; everything
        // else rolls from the rarity range, so the codex shows the range.
        var _wd_txt;
        if ((_hands == "2H") || _rar >= 4) {
            _wd_txt = "+" + string(variable_struct_exists(base_item, "weapon_damage") ? base_item.weapon_damage : weapon_damage_max(_rar));
        } else {
            _wd_txt = "+" + string(weapon_damage_min(_rar)) + "-" + string(weapon_damage_max(_rar));
        }
        _txt = "Weapon dmg " + _wd_txt + " (" + _reach + ", " + _hands + ")\n" + _txt;
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
    } else if (_rar == 3) {
        // The codex's dedicated EPIC entries (rare bases viewed at rarity 3).
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
// Rarity range bounds (2026-07-08 rework: flat damage ROLLS per item instead of a
// fixed value, so drops of one rarity differ - a high common roll can beat a low
// uncommon one; higher rarities compensate with affixes/sockets). 2026-07-09: Epic
// and Legendary widened to 8-12 / 10-15 so the top tiers pull ahead; a high damage
// roll inverse-lerp biases the item's OTHER rolled affixes toward their minimums
// at creation time (see item_affix_bias) - big stick = leaner trimmings.
function weapon_damage_min(rarity) {
    switch (rarity) {
        case 0: return 1;   case 1: return 2;   case 2: return 4;
        case 3: return 8;   case 4: return 10;
    }
    return 0;
}
function weapon_damage_max(rarity) {
    switch (rarity) {
        case 0: return 3;   case 1: return 5;   case 2: return 8;
        case 3: return 12;  case 4: return 15;
    }
    return 0;
}
function weapon_base_damage(rarity) {
    var _mn = weapon_damage_min(rarity);
    if (_mn <= 0) return 0;
    return irandom_range(_mn, weapon_damage_max(rarity));
}

// weapon_damage_bias_t(item) - where the item's flat-damage roll landed within
// its rarity range: 0 = min roll .. 1 = max roll. Non-weapons (and degenerate
// ranges) return 0. Feeds the creation-time affix bias: the hotter the damage
// roll, the closer the item's OTHER rolled affixes sit to their minimums, so a
// max-damage weapon pays for it with lean trimmings.
function weapon_damage_bias_t(item) {
    if (!is_struct(item) || !variable_struct_exists(item, "slot")) return 0;
    if (item.slot != "weapon" && item.slot != "ranged_weapon") return 0;
    var _mn = weapon_damage_min(item.rarity);
    var _mx = weapon_damage_max(item.rarity);
    if (_mn <= 0 || _mx <= _mn) return 0;
    var _d = variable_struct_exists(item, "weapon_damage") ? item.weapon_damage : _mn;
    return clamp((_d - _mn) / (_mx - _mn), 0, 1);
}

// weapon_roll_school() - random magical school for a caster ranged weapon's base
// damage, rolled ONCE per item at creation (wands/foci never deal phys; bows do).
function weapon_roll_school() {
    var _pool = ability_school_list();
    return _pool[irandom(array_length(_pool) - 1)];
}

// weapon_is_caster_ranged(item) - wand/focus/scepter/staff/rod in the ranged slot:
// the weapons whose base damage is school-typed. Keys off the same name families
// as the INT stat requirement so the two never disagree.
function weapon_is_caster_ranged(item) {
    if (!is_struct(item) || !variable_struct_exists(item, "slot")) return false;
    return (item.slot == "ranged_weapon" && weapon_required_stat(item) == "INT");
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
// bias_t: creation-time inverse-lerp from the weapon's damage roll - a hot roll
// halves the elemental rider at the extreme (same rule as stat affixes).
function roll_elemental_affix(rarity, bias_t = 0) {
    if (rarity < 1 || rarity > 3) return undefined;   // common/legendary: no rolled elem affix
    // M-locked 08-13 weapon rework: "too many weapons add elemental damage. it
    // should be more rare" - 40% -> 15%, an elemental weapon is now a FIND.
    if (irandom(99) >= 15) return undefined;
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
    var _edmg = elem_affix_damage(rarity);
    if (bias_t > 0) _edmg = max(1, round(lerp(_edmg, max(1, ceil(_edmg * 0.5)), bias_t)));
    return {
        element:       _element,
        dmg:           _edmg,
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

// affix_suffix_noun(suffix) - the meaningful noun in an "of X" affix suffix, with
// the leading "of "/"of the " stripped: "of the Void" -> "Void", "of Charm" ->
// "Charm". Used by the elemental name-fusion below (ITEM_NAMING_FUSION.md).
function affix_suffix_noun(suffix) {
    var _s = suffix;
    if (string_pos("of the ", _s) == 1)  _s = string_delete(_s, 1, 7);
    else if (string_pos("of ", _s) == 1) _s = string_delete(_s, 1, 3);
    return _s;
}

// item_fused_elem_suffix(elem, last_affix) - the FUSED "of ..." phrase used when a
// weapon's elemental rider lands on an item that already ends in a stat affix's
// "of {noun}". Instead of an awkward double "of X of Y" we compose one lore
// phrase (ITEM_NAMING_FUSION.md): a bespoke override for special element x stat
// pairs, else "of {elementAdjective} {statNoun}".
function item_fused_elem_suffix(elem, last_affix) {
    var _elem_key = elem.element;   // "burn" / "frost" / "shock"
    var _stat_key = variable_struct_exists(last_affix, "stat_name") ? last_affix.stat_name : "";

    // 1) Bespoke override for a specific element x stat combo.
    if (variable_global_exists("name_bespoke_pairs")) {
        var _bp = global.name_bespoke_pairs;
        for (var _i = 0; _i < array_length(_bp); _i++) {
            if (_bp[_i].elem == _elem_key && _bp[_i].stat == _stat_key) return _bp[_i].phrase;
        }
    }

    // 2) Composed "of {elementAdjective} {statNoun}". Adjective falls back to the
    //    element's own display prefix if no combine-adjective is registered.
    var _adj = elem.prefix;
    if (variable_global_exists("name_combine_adj")
        && variable_struct_exists(global.name_combine_adj, _elem_key)) {
        _adj = variable_struct_get(global.name_combine_adj, _elem_key);
    }
    return "of " + _adj + " " + affix_suffix_noun(last_affix.suffix);
}

// apply_elemental_affix_to_item(item, elem) - store the affix, fold its name in
// (prefix form, or FUSED suffix form if a stat affix already suffixed the name),
// and bump gold value.
function apply_elemental_affix_to_item(item, elem) {
    if (elem == undefined) return;
    item.elem_affix = elem;
    var _has_prefix = (variable_struct_exists(item, "affixes") && array_length(item.affixes) >= 2);
    if (_has_prefix) {
        // The item already ends in the last stat affix's "of {noun}". Fuse the two
        // into one lore phrase rather than stacking a second "of ..." (double-of).
        var _affs      = item.affixes;
        var _last      = _affs[array_length(_affs) - 1];
        var _stat_tail = " " + _last.suffix;                // e.g. " of Charm"
        var _nlen = string_length(item.name);
        var _tlen = string_length(_stat_tail);
        if (_nlen > _tlen && string_copy(item.name, _nlen - _tlen + 1, _tlen) == _stat_tail) {
            item.name = string_copy(item.name, 1, _nlen - _tlen) + " " + item_fused_elem_suffix(elem, _last);
        } else {
            // Tail not where expected (unexpected) - fall back to the plain append.
            item.name = item.name + " " + elem.suffix;
        }
    } else {
        item.name = elem.prefix + " " + item.name;
    }
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
        case "dot":        _st = _pct + "% chance of Burn (" + string(elem.status_value) + " dmg/turn, " + _dur + "t)"; break;
        case "weaken":     _st = _pct + "% chance of Chill (-" + string(round(elem.status_value * 100)) + "% dmg, " + _dur + "t)"; break;
        case "vulnerable": _st = _pct + "% chance of Shock (+" + string(elem.status_value) + " dmg/hit taken, " + _dur + "t)"; break;
    }
    // M-locked 08-13 weapon rework: the affix fires on WEAPON ACTIONS (Strike /
    // Weapon Strike / Weapon Shot) and Edge-Carried abilities - not every
    // ability of the reach class. The text says so. Reworded 08-15 (M shot:
    // "+4 Shock dmg on ranged weapon strikes. (15% chance to Shock (foe...))"
    // read as a nested-paren run-on beside the weapon's own damage line) -
    // one leading label, one level of parens.
    return "On " + _reach + " weapon strikes: +" + string(elem.dmg) + " "
         + school_label(elem_element_name(elem.element)) + " damage, " + _st + ".";
}

// create_item(name, slot, rarity, stat_name, stat_value, effect_desc, gold_value)
// Returns an equipment item struct. Rarity: 0=common, 1=uncommon, 2=rare,
// 3=epic, 4=legendary.
// ---------------------------------------------------------------------------
function create_item(name, slot, rarity, stat_name, stat_value, effect_desc, gold_value) {
    // Weapon-slot items get a flat, reach-gated weapon_damage (rolled from the
    // rarity's range at creation); all other gear = 0.
    var _wpn_dmg = (slot == "weapon" || slot == "ranged_weapon") ? weapon_base_damage(rarity) : 0;
    var _it = {
        name:          name,
        base_name:     name,   // immutable identity for the codex (affixes mutate `name`)
        item_category: "equipment",
        slot:          slot,
        rarity:        rarity,
        stat_name:     stat_name,
        stat_value:    stat_value,
        weapon_damage: _wpn_dmg,                          // flat reach-gated damage (weapons only)
        wpn_school:    "",                                // caster ranged weapons: school of the base damage
        two_handed:    false,                             // 2H weapons lock the offhand slot (set post-create)
        elem_affix:    undefined,                         // elemental affix (SYSTEMS_WEAPON_ROLES.md §C); set post-create
        effect_desc:   effect_desc,
        gold_value:    gold_value,
        socket_count:  rune_sockets_for_rarity(rarity),   // rune sockets by rarity
        runes:         []                                  // socketed gear runes
    };
    // Wands/foci/scepters/staves/rods deal their base damage as a MAGICAL school,
    // rolled once per item - never phys (bows keep phys).
    if (weapon_is_caster_ranged(_it)) _it.wpn_school = weapon_roll_school();
    return _it;
}

// ---------------------------------------------------------------------------
// item_rarity_name(rarity)
// Returns the display string for a rarity integer.
// ---------------------------------------------------------------------------
// True when this exact item instance is currently worn (global.inventory).
// GML struct comparison is by reference, so a stash clone with the same name
// can never false-positive. Used by NPC lists/pickers to tag worn gear
// (M 08-11: "equipped items should show EQUIPPED at any npc function").
function item_is_equipped(_it) {
    if (!is_struct(_it) || !variable_global_exists("inventory") || !is_array(global.inventory)) return false;
    for (var _i = 0; _i < array_length(global.inventory); _i++)
        if (global.inventory[_i] == _it) return true;
    return false;
}

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
    // Normalize: a fractional/real rarity (or anything non-numeric) must not fall
    // through the integer cases and silently draw a colored item white.
    var _r = is_real(rarity) ? round(rarity) : 0;
    switch (_r) {
        case 0: return c_white;                            // Common   - white
        case 1: return make_color_rgb(100, 200, 100);     // Uncommon - green
        case 2: return make_color_rgb(80, 140, 255);      // Rare     - blue
        case 3: return make_color_rgb(180, 80, 255);      // Epic     - purple
        case 4: return make_color_rgb(255, 160, 30);      // Legendary - orange
    }
    return c_white;
}

// ---------------------------------------------------------------------------
// loot_rarity_sound(rarity)
// The loot dopamine ladder (SOUND_ATMOSPHERE_SPEC.md section 1) - one musical
// stinger per rarity tier, scaled in grandeur. Haul rule (M, 07-14): the loot
// screen plays reveal ticks per row and ONE stinger - the best item's.
// (snd_loot_unique - the off-ladder relic motif - is reserved for guaranteed
// treasure sites: reliquary chests / Petra order claims.)
// ---------------------------------------------------------------------------
function loot_rarity_sound(rarity) {
    var _r = is_real(rarity) ? round(rarity) : 0;
    switch (_r) {
        case 1: return snd_loot_uncommon;
        case 2: return snd_loot_rare;
        case 3: return snd_loot_epic;
        case 4: return snd_loot_legendary;
    }
    return snd_loot_common;
}

// loot_item_sting(item, [relic]) - layer the dopamine stinger for an EQUIPMENT
// find over the chest foley (consumable finds keep just chest+gold). relic=true
// swaps a legendary's fanfare for the off-ladder music-box relic motif - used
// at reliquary chests, where a hand-authored legendary is "finding a story".
function loot_item_sting(item, relic = false) {
    if (!is_struct(item)) return;
    if (variable_struct_exists(item, "item_category") && item.item_category == "consumable") return;
    if (!variable_struct_exists(item, "rarity")) return;
    if (relic && round(item.rarity) >= 4) {
        audio_play_sound(snd_loot_unique, 1, false);
        return;
    }
    audio_play_sound(loot_rarity_sound(item.rarity), 1, false);
}

// ---------------------------------------------------------------------------
// create_consumable(name, effect_type, effect_value, description, gold_value)
// Returns a consumable item struct for inventory and drop systems.
// ---------------------------------------------------------------------------
function create_consumable(name, effect_type, effect_value, description, gold_value) {
    var _c = {
        name:          name,
        item_category: "consumable",
        effect_type:   effect_type,
        effect_value:  effect_value,
        description:   description,
        gold_value:    gold_value
    };
    // The Genie Lamp is a legendary-tier drop (~1.5% off elites/bosses) and should
    // READ like one: stamp legendary rarity so every rarity-aware name draw golds it
    // (M 07-09). Centralized here so all creation sites agree.
    if (name == "Genie Lamp") _c.rarity = 4;
    return _c;
}

// Name color for a consumable row: rarity-stamped specials (Genie Lamp = legendary
// gold) use their rarity color; everything else keeps the consumable cyan.
function ui_consumable_name_color(item) {
    if (is_struct(item) && variable_struct_exists(item, "rarity")) return item_rarity_color(item.rarity);
    return make_color_rgb(80, 200, 200);
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
    // Flat run-scoped max-HP bonus (Second Wind, POTENCY V2) - post-mults, the
    // same way combat_apply_start_traits adds its flat bonuses.
    if (variable_global_exists("run_bonus_max_hp")) _max += global.run_bonus_max_hp;
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
    if (_et == "valuable") return false;   // sell-only (08-17) - never consumed
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
    // CHAOTIC BREW (reworked 08-15): out of combat, the stamped mix applies
    // what it can - heals land on the persistent run HP, the find-buffs are
    // real, battle-only parts (wards/AP/regen) fizzle. The bite downside spills
    // gold here (no safe HP-loss channel outside combat). Legacy brews keep
    // the old 40-90 heal roll.
    if (_et == "chaotic") {
        var _ch_max = out_of_combat_max_hp();
        if (!variable_global_exists("run_current_hp") || global.run_current_hp <= 0) {
            global.run_current_hp = _ch_max;
        }
        if (variable_struct_exists(item, "mix")) {
            for (var _cbi = 0; _cbi < array_length(item.mix); _cbi++) {
                var _cbp = item.mix[_cbi];
                if (_cbp.effect_type == "heal" || _cbp.effect_type == "heal_dot") {
                    // Regen collapses to a flat 3-tick heal at camp.
                    var _cbh = (_cbp.effect_type == "heal") ? _cbp.effect_value : _cbp.effect_value * 3;
                    global.run_current_hp = min(_ch_max, global.run_current_hp + _cbh);
                } else if (_cbp.effect_type == "gold_find_pot") potion_drink_gold(_cbp.effect_value);
                else if (_cbp.effect_type == "loot_find_pot")   potion_drink_loot(_cbp.effect_value);
            }
            if (variable_struct_exists(item, "downside") && item.downside.kind == "bite") {
                // Sealed Reserve (Sable rank 2, M-locked 08-15): the camp spill
                // is halved too, matching the combat-site halving.
                global.gold = max(0, global.gold - ((npc_rank("sable") >= 2) ? 8 : 15));
            }
        } else {
            global.run_current_hp = min(_ch_max, global.run_current_hp + irandom_range(40, 90));
            if (irandom(99) < 35) global.gold = max(0, global.gold - 20);   // it curdles
        }
        return true;
    }
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
        wpn_school:    variable_struct_exists(src, "wpn_school")    ? src.wpn_school    : "",
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
    // Transform bookkeeping carries through a clone ONLY when present on the
    // source (presence-conditional - an ever-present req_stat/icon_seed would
    // change behavior for untouched items). M 08-04 bug: a paid RE-ATTUNE
    // (req_stat/req_value) was silently WIPED by cursed rebirth because the
    // clone dropped the override.
    if (variable_struct_exists(src, "req_stat"))    _c.req_stat    = src.req_stat;
    if (variable_struct_exists(src, "req_value"))   _c.req_value   = src.req_value;
    if (variable_struct_exists(src, "icon_seed"))   _c.icon_seed   = src.icon_seed;
    if (variable_struct_exists(src, "curse_count")) _c.curse_count = src.curse_count;
    if (variable_struct_exists(src, "cursed"))      _c.cursed      = src.cursed;
    if (variable_struct_exists(src, "splash_base")) _c.splash_base = src.splash_base;
    if (variable_struct_exists(src, "dark_gifts")) {
        _c.dark_gifts = [];
        for (var _dg = 0; _dg < array_length(src.dark_gifts); _dg++) array_push(_c.dark_gifts, src.dark_gifts[_dg]);
    }
    if (variable_struct_exists(src, "quality"))      _c.quality      = src.quality;
    if (variable_struct_exists(src, "quality_base")) _c.quality_base = src.quality_base;
    if (variable_struct_exists(src, "dormant")) _c.dormant = src.dormant;
    // Deep Socket (Maren rank 2, 08-15): the once-ever flag rides clones
    // presence-conditionally (socket_count above already carries the +1).
    if (variable_struct_exists(src, "deep_socketed")) _c.deep_socketed = src.deep_socketed;
    // Pattern Book bookkeeping (08-11): assigned art + craft-band metadata ride
    // clones the same presence-conditional way as icon_seed above.
    if (variable_struct_exists(src, "player_crafted")) _c.player_crafted = src.player_crafted;
    if (variable_struct_exists(src, "icon_as") && is_struct(src.icon_as)) {
        _c.icon_as = { name: src.icon_as.name, base_name: src.icon_as.base_name,
                       rarity: src.icon_as.rarity, slot: src.icon_as.slot };
        if (variable_struct_exists(src.icon_as, "icon_seed")) _c.icon_as.icon_seed = src.icon_as.icon_seed;
    }
    if (variable_struct_exists(src, "pb_craft") && is_struct(src.pb_craft)) {
        var _pbf = [];
        if (variable_struct_exists(src.pb_craft, "fams") && is_array(src.pb_craft.fams)) {
            for (var _pbi = 0; _pbi < array_length(src.pb_craft.fams); _pbi++) {
                array_push(_pbf, { stat_name: src.pb_craft.fams[_pbi].stat_name, tier: src.pb_craft.fams[_pbi].tier });
            }
        }
        _c.pb_craft = { rar: src.pb_craft.rar, base_stat: src.pb_craft.base_stat, fams: _pbf };
    }
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
    // Every caller clones a loot-table TEMPLATE, so weapons re-roll their flat
    // damage (and caster school) per clone - otherwise the template's single roll
    // would stamp every drop of that base identical. Hand-tuned budgets keep the
    // authored value: 2H weapons. (2026-07-09: legendaries now roll too - the
    // 10-15 legendary range only exists per-drop; their AUTHORED affixes are
    // fixed, so the damage-roll bias never touches them.)
    if ((_c.slot == "weapon" || _c.slot == "ranged_weapon") && !_c.two_handed) {
        _c.weapon_damage = weapon_base_damage(_c.rarity);
    }
    // Caster ranged weapons roll a fresh school per drop (the template's own
    // creation-time roll must not stamp every copy alike).
    if (weapon_is_caster_ranged(_c)) _c.wpn_school = weapon_roll_school();
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
// item_affix_exclusions(item) - the exclude list for rolling EXTRA affixes onto an
// item: its base stat PLUS every stat already present on an existing affix row.
// Pre-declared multi-stat items (Ember Ring's intrinsic "of Insight" +INT) were only
// excluding the base stat, so the roller could stack a second row of the same stat
// ("+2 INT  +1 INT" instead of one combined row - M 07-09 screenshot).
// ---------------------------------------------------------------------------
function item_affix_exclusions(item) {
    var _ex = [item.stat_name];
    if (variable_struct_exists(item, "affixes") && is_array(item.affixes)) {
        for (var _xi = 0; _xi < array_length(item.affixes); _xi++) {
            var _xr = item.affixes[_xi];
            if (is_struct(_xr) && variable_struct_exists(_xr, "stat_name")) array_push(_ex, _xr.stat_name);
        }
    }
    return _ex;
}

// ---------------------------------------------------------------------------
// item_merge_dup_affixes(item) - merge duplicate same-stat affix rows (values sum
// into the first row; rows without stat_name, e.g. elemental status affixes, pass
// through untouched). Run on loaded items so pre-fix saves with stacked rows read
// "+3 INT" instead of "+2 INT  +1 INT". Totals don't change - stat application
// always summed every row - this is display + affix-slot hygiene.
// ---------------------------------------------------------------------------
function item_merge_dup_affixes(item) {
    // LEGACY ITEM MIGRATIONS ride here too - this is the one sweep every loaded
    // item passes through (inventory / stash / carried / secured, scr_save).
    // 08-16: Vaultstone Wand 12% -> 5% (M: an uncommon +12% outperformed epics);
    // saved wands still carry the old id + text.
    if (is_struct(item) && variable_struct_exists(item, "unique_effect") && item.unique_effect == "class_spell_dmg"
        && variable_struct_exists(item, "base_name") && item.base_name == "Vaultstone Wand") {
        item.unique_effect = "class_spell_dmg_lesser";
        item.unique_desc   = "Spells deal +5% damage";
    }
    if (!is_struct(item) || !variable_struct_exists(item, "affixes") || !is_array(item.affixes)) return;
    var _out = [];
    for (var _mi = 0; _mi < array_length(item.affixes); _mi++) {
        var _row = item.affixes[_mi];
        var _merged = false;
        if (is_struct(_row) && variable_struct_exists(_row, "stat_name") && variable_struct_exists(_row, "stat_value")) {
            // Affix row duplicating the item's BASE stat folds into stat_value
            // (07-28: several authored legendaries shipped "+4 DEX  +2 DEX";
            // their table defs are fixed, this repairs copies already in saves).
            if (variable_struct_exists(item, "stat_name") && variable_struct_exists(item, "stat_value")
                && _row.stat_name == item.stat_name) {
                item.stat_value += _row.stat_value;
                continue;
            }
            for (var _mj = 0; _mj < array_length(_out); _mj++) {
                var _prev = _out[_mj];
                if (is_struct(_prev) && variable_struct_exists(_prev, "stat_name")
                    && _prev.stat_name == _row.stat_name && variable_struct_exists(_prev, "stat_value")) {
                    _prev.stat_value += _row.stat_value;
                    _merged = true;
                    break;
                }
            }
        }
        if (!_merged) array_push(_out, _row);
    }
    item.affixes = _out;
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
// bias_t (weapons only, from weapon_damage_bias_t): 0..1 inverse-lerp that pulls
// stat-affix values toward their floor (half value, min 1) as the weapon's flat
// damage roll approaches its rarity max. Caster slots are never weapon slots, so
// the school branch never sees a nonzero bias.
// ---------------------------------------------------------------------------
function roll_affixes(rarity, count, exclude_stat_names, slot = "", base_name = "", bias_t = 0) {
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
        // Creation-time inverse-lerp (weapons): a hot damage roll drags the affix
        // toward its floor - max roll = other affixes near min.
        if (bias_t > 0) _val = max(1, round(lerp(_val, max(1, ceil(_val * 0.5)), bias_t)));

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
// ---------------------------------------------------------------------------
// awaken_boost_options() - dungeons eligible for the Awakening Boost popup:
// every dungeon EXCEPT the one that earned it, below the A5 pre-win cap.
// Entries: { key, name, cur }.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// dungeon_max_ascendance(key) - the highest SELECTABLE Awakening for a dungeon.
// Pre-win: its own ladder unlock (0-5). Post-win (SYSTEMS_ENDLESS.md §2): the
// shared endless frontier applies everywhere (A6+ propagating unlocks).
// ---------------------------------------------------------------------------
function dungeon_max_ascendance(dkey) {
    var _u = variable_global_exists("dungeon_ascendance_unlocked")
        ? variable_struct_get(global.dungeon_ascendance_unlocked, dkey) : 0;
    if (variable_global_exists("ironwake_stands") && global.ironwake_stands) {
        var _e = variable_global_exists("endless_awakening_unlocked") ? global.endless_awakening_unlocked : 5;
        _u = max(_u, _e);
    }
    return _u;
}

function awaken_boost_options() {
    var _out = [];
    if (!variable_global_exists("dungeon_ascendance_unlocked")) return _out;
    var _keys  = ["ashen_vault", "scorched_depths", "tundra_tomb"];
    var _names = ["Ashen Vault", "Scorched Depths", "Tundra Tomb"];
    var _from  = variable_global_exists("awaken_boost_from") ? global.awaken_boost_from : "";
    for (var _i = 0; _i < 3; _i++) {
        if (_keys[_i] == _from) continue;
        var _u = variable_struct_get(global.dungeon_ascendance_unlocked, _keys[_i]);
        if (_u >= 5) continue;
        array_push(_out, { key: _keys[_i], name: _names[_i], cur: _u });
    }
    return _out;
}

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
// legendary_owned(base_name) - does the player already hold a copy of this
// legendary anywhere (worn slots, hub stash, carried pack)? Compared by BASE
// name so Depthforged tags/renames don't hide a duplicate. Feeds the
// dupe-protection reroll in drop_equipment (M 07-28).
function legendary_owned(base_name) {
    if (variable_global_exists("inventory")) {
        for (var _i = 0; _i < array_length(global.inventory); _i++) {
            var _it = global.inventory[_i];
            if (is_struct(_it) && item_base_name(_it) == base_name) return true;
        }
    }
    if (variable_global_exists("equipment_stash")) {
        for (var _i = 0; _i < array_length(global.equipment_stash); _i++) {
            var _it = global.equipment_stash[_i];
            if (is_struct(_it) && item_base_name(_it) == base_name) return true;
        }
    }
    if (variable_global_exists("carried_items")) {
        for (var _i = 0; _i < array_length(global.carried_items); _i++) {
            var _it = global.carried_items[_i];
            if (is_struct(_it) && item_base_name(_it) == base_name) return true;
        }
    }
    return false;
}

// LEGENDARY RECAST (M 07-28 legendary sinks): Dorn re-forges a legendary into a
// DIFFERENT one for gold. Mutates the struct IN PLACE so every container slot
// sees the recast item; rolls avoid the input always and owned copies softly.
function legendary_recast_cost() { return cha_price(500); }
function legendary_recast(item) {
    if (!variable_global_exists("loot_table_legendary")) return false;
    var _tbl = global.loot_table_legendary;
    if (array_length(_tbl) < 2) return false;
    var _cur  = item_base_name(item);
    var _pick = undefined;
    for (var _try = 0; _try < 8; _try++) {
        var _cand = _tbl[irandom(array_length(_tbl) - 1)];
        if (item_base_name(_cand) == _cur) continue;
        if (_try < 5 && legendary_owned(item_base_name(_cand))) continue;   // soft dupe-avoid
        _pick = _cand; break;
    }
    if (_pick == undefined) return false;
    var _new  = clone_item(_pick);
    var _keys = variable_struct_get_names(_new);
    for (var _k = 0; _k < array_length(_keys); _k++) {
        variable_struct_set(item, _keys[_k], variable_struct_get(_new, _keys[_k]));
    }
    var _ec = item_empower_context();
    item_empower(item, _ec.asc, _ec.df);   // A6+/Descent scaling like fresh drops
    discover_item(item_base_name(item), item.rarity);
    return true;
}

// =============================================================================
// THE LEGENDARY FORGE (M locked 07-28): three vendor components combine at
// Dorn's anvil into a CUSTOM legendary - the player picks the slot, one of 5
// forge-exclusive effects, and NAMES it. Components (saved):
//   forge_comp_frame - Dorn,  Mythril Frame:  400g + 1 Legendary Ingot
//   forge_comp_core  - Maren, Runeheart Core: 40 dust + a tier-III+ rune
//   forge_comp_quint - Sable, Quintessence:   200g + 3 DIFFERENT specialty brews (08-15)
// =============================================================================

function forge_components_ensure() {
    if (!variable_global_exists("forge_comp_frame")) global.forge_comp_frame = 0;
    if (!variable_global_exists("forge_comp_core"))  global.forge_comp_core  = 0;
    if (!variable_global_exists("forge_comp_quint")) global.forge_comp_quint = 0;
}
function forge_components_ready() {
    forge_components_ensure();
    return global.forge_comp_frame > 0 && global.forge_comp_core > 0 && global.forge_comp_quint > 0;
}
function forge_frame_cost() { return cha_price(400); }
function forge_quint_cost() { return cha_price(200); }

// The 5 forge-exclusive effects. Every id rides an EXISTING class-item channel
// (the equip scan in obj_combat_controller Create is generic over unique_effect
// strings), so all of them are real with zero new combat wiring.
function forge_effect_catalog() {
    return [
        { id: "class_start_shield", name: "Bulwark Heart",   desc: "Start every combat with a 12-point shield" },
        { id: "class_lifesteal",    name: "Thirsting Edge",  desc: "Your melee damage heals you for 10%" },
        { id: "class_crit",         name: "Killer's Eye",    desc: "+8% to all your critical rolls" },
        { id: "class_spell_dmg",    name: "Archon's Breath", desc: "Your spells deal +12% damage" },
        { id: "class_kill_ap",      name: "Reaper's Tempo",  desc: "Killing blows refund 1 AP" },
    ];
}
function forge_slot_list() {
    return ["weapon", "ranged_weapon", "offhand", "helm", "chest", "gloves", "boots", "amulet", "ring"];
}

// Pattern-craft CATEGORY flow (M 08-15: "weapons - armor - jewelry, then sub
// menus" instead of one flat slot list). Slot ids reference forge_slot_list;
// labels are AUTHORED (item_slot_noun has no name for ranged_weapon and fell
// back to "piece of equipment" - M's shot).
function pattern_craft_categories() {
    return [
        { label: "WEAPONS", desc: "Melee and ranged arms. These carry weapon damage.",
          slots: [ { id: "weapon",        label: "MELEE" },
                   { id: "ranged_weapon", label: "RANGED" } ] },
        { label: "ARMOR",   desc: "Chest, helm, gloves, boots and offhand.",
          slots: [ { id: "chest",   label: "CHEST" },
                   { id: "helm",    label: "HELM" },
                   { id: "gloves",  label: "GLOVES" },
                   { id: "boots",   label: "BOOTS" },
                   { id: "offhand", label: "OFFHAND" } ] },
        { label: "JEWELRY", desc: "Amulets and rings. The only slots that take caster blueprints.",
          slots: [ { id: "amulet", label: "AMULET" },
                   { id: "ring",   label: "RING" } ] },
    ];
}

// Runeheart Core candidates: rune_inventory INDICES of tier-III+ runes (the
// sacrifice pool for Maren's forge component).
function maren_core_candidates() {
    var _out = [];
    if (!variable_global_exists("rune_inventory")) return _out;
    for (var _i = 0; _i < array_length(global.rune_inventory); _i++) {
        if (global.rune_inventory[_i].tier >= 3) array_push(_out, _i);
    }
    return _out;
}

// Build the forged legendary. Components are NOT spent here - the caller spends
// them at commit so a failed build never eats materials.
function forge_build_item(_slot, _fx, _name) {
    var _statmap = { weapon: "STR", ranged_weapon: "DEX", offhand: "CON", helm: "INT",
                     chest: "CON", gloves: "DEX", boots: "CON", amulet: "WIS", ring: "CHA" };
    var _stat = variable_struct_exists(_statmap, _slot) ? variable_struct_get(_statmap, _slot) : "CON";
    var _it = create_item(_name, _slot, 4, _stat, 5,
        "forged at Dorn's anvil from three vendors' craft", 400);
    _it.class_req     = -1;
    _it.player_forged = true;
    ach_unlock("ACH_FORGE_LEGEND");   // achievement hook (08-05 wiring): single caller = the commit path
    // Boosted affixes: two epic-grade rolls at x1.25 - then the PLAYER'S name is
    // restored (apply_affixes_to_item decorates the name with prefix/suffix).
    apply_affixes_to_item(_it, roll_affixes(3, 2, item_affix_exclusions(_it), _slot, _name, 0));
    for (var _i = 0; _i < array_length(_it.affixes); _i++) {
        _it.affixes[_i].stat_value = ceil(_it.affixes[_i].stat_value * 1.25);
    }
    _it.name      = _name;
    _it.base_name = _name;
    _it.unique_effect = _fx.id;
    _it.unique_desc   = _fx.desc;
    _it.lore = "Forged in Ironwake by " + (variable_global_exists("player_name") ? global.player_name : "a wanderer")
        + " - frame by Dorn, core by Maren, quintessence by Sable. There is exactly one.";
    return _it;
}

// CURSED REBIRTH builder (M 07-28; first slice of the parked cursed-items
// feature): the sacrificed legendary returns with base stat / weapon damage /
// affixes boosted ~x1.5 AND one CURSE - a negative affix on a channel the
// equip math already handles, so every curse is real. Keeps its unique effect.
// =============================================================================
// ALCHEMICAL REASSEMBLAGE COSTS (M 08-04, SYSTEMS_ITEM_PROGRESSION.md §3).
// The ask scales x1.5 per curse already ON the offered item, and the gear
// reagent accepts EQUIVALENT bundles: 1 epic ~ 3 rares ~ 12 uncommons
// (unequipped stash+pack gear only), plus potions and gold every time.
// =============================================================================
function cursed_rebirth_fee(it) {
    var _n = (is_struct(it) && variable_struct_exists(it, "curse_count")) ? it.curse_count : 0;
    var _m = power(1.5, _n);
    return {
        feeds:     _n,
        gold:      cha_price(ceil(700 * _m)),
        potions:   ceil(2 * _m),
        epics:     ceil(1 * _m),
        rares:     ceil(3 * _m),
        uncommons: ceil(12 * _m)
    };
}

// Unequipped gear of one rarity across stash + pack, excluding the offering.
function cursed_rebirth_gear_of_rarity(rar, excl) {
    var _out = [];
    var _pools = [];
    if (variable_global_exists("equipment_stash") && is_array(global.equipment_stash)) array_push(_pools, global.equipment_stash);
    if (variable_global_exists("carried_items")   && is_array(global.carried_items))   array_push(_pools, global.carried_items);
    for (var _p = 0; _p < array_length(_pools); _p++) {
        var _arr = _pools[_p];
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _g = _arr[_i];
            if (_g == excl) continue;
            if (is_struct(_g) && variable_struct_exists(_g, "rarity") && _g.rarity == rar) array_push(_out, _g);
        }
    }
    return _out;
}

// ESSENCE math (M 08-05): the gear reagent is measured in essence points so
// bundles MIX freely - uncommon 1, rare 4, epic 12. The ask is fee.uncommons
// points, which lands on the exact same totals as the old rigid
// 1-epic / 3-rares / 12-uncommons ladder at every curse tier.
function reagent_pts(rar) {
    if (rar == 1) return 1;
    if (rar == 2) return 4;
    if (rar == 3) return 12;
    return 0;
}

// Total essence the player COULD offer (unequipped stash + pack, minus the
// offering itself). Affordability gate for the resolve + the fee preview.
function cursed_rebirth_pts_avail(excl) {
    var _pts = 0;
    for (var _r = 1; _r <= 3; _r++)
        _pts += array_length(cursed_rebirth_gear_of_rarity(_r, excl)) * reagent_pts(_r);
    return _pts;
}

// Remove one gear struct (by reference) from stash or pack.
function cursed_rebirth_burn_gear(g) {
    if (variable_global_exists("equipment_stash")) {
        for (var _i = 0; _i < array_length(global.equipment_stash); _i++)
            if (global.equipment_stash[_i] == g) { array_delete(global.equipment_stash, _i, 1); return true; }
    }
    if (variable_global_exists("carried_items")) {
        for (var _i = 0; _i < array_length(global.carried_items); _i++)
            if (global.carried_items[_i] == g) { array_delete(global.carried_items, _i, 1); return true; }
    }
    return false;
}

// =============================================================================
// REAGENT PICKER (M 08-05): "players must be able to select the items, or they
// will destroy items they want to keep" - gold value knows nothing about builds
// (a void-build's cheap void rares are exactly what junkiest-first would eat).
// Second modal stage after the offering is chosen: every eligible reagent (gear
// AND potions, both per M) listed with the junkiest/cheapest PRE-TICKED to meet
// the ask; any row toggles. Nothing burns until the armed confirm. State lives
// in global.reagent_picker (undefined = closed); stepped by reagent_picker_step()
// from gc Step, drawn by ui_draw_reagent_picker() (hub Draw_64 - Sable is
// hub-only).
// =============================================================================
function reagent_picker_open(target_cand) {
    var _fee  = cursed_rebirth_fee(target_cand.item);
    var _rows = [];
    // Gear rows: rarity asc then sell value asc, so the junk sits on top and
    // the pre-tick below marks exactly the least-precious block.
    for (var _r = 1; _r <= 3; _r++) {
        var _pool = cursed_rebirth_gear_of_rarity(_r, target_cand.item);
        var _sub = [];
        for (var _i = 0; _i < array_length(_pool); _i++) {
            var _g = _pool[_i];
            array_push(_sub, {
                kind: "gear", item: _g,
                label: variable_struct_exists(_g, "name") ? _g.name : "item",
                rarity: _r, pts: reagent_pts(_r),
                value: item_sell_value(_g), sel: false
            });
        }
        array_sort(_sub, function(a, b) { return a.value - b.value; });
        for (var _i = 0; _i < array_length(_sub); _i++) array_push(_rows, _sub[_i]);
    }
    var _gear_n = array_length(_rows);
    // Potion rows: cheapest first (manual-select per M - total control).
    var _psub = [];
    if (variable_global_exists("consumable_inventory") && is_array(global.consumable_inventory)) {
        for (var _i = 0; _i < array_length(global.consumable_inventory); _i++) {
            var _c = global.consumable_inventory[_i];
            if (!is_struct(_c)) continue;
            array_push(_psub, {
                kind: "potion", item: _c,
                label: variable_struct_exists(_c, "name") ? _c.name : "potion",
                rarity: -1, pts: 0,
                value: variable_struct_exists(_c, "gold_value") ? _c.gold_value : 0, sel: false
            });
        }
    }
    array_sort(_psub, function(a, b) { return a.value - b.value; });
    for (var _i = 0; _i < array_length(_psub); _i++) array_push(_rows, _psub[_i]);
    // Pre-tick the junkiest block that pays the ask - the old auto-burn's exact
    // picks, now just a suggestion the player can retick freely.
    var _need = _fee.uncommons;
    for (var _i = 0; _i < _gear_n && _need > 0; _i++) { _rows[_i].sel = true; _need -= _rows[_i].pts; }
    var _pneed = _fee.potions;
    for (var _i = _gear_n; _i < array_length(_rows) && _pneed > 0; _i++) { _rows[_i].sel = true; _pneed--; }
    global.reagent_picker = {
        purpose: "cursed_rebirth",
        target: target_cand, fee: _fee, goal: _fee.uncommons,
        rows: _rows, gear_n: _gear_n,
        cursor: 0, scroll: 0, confirm: false
    };
}

// MAREN AWAKEN variant (M 08-05: "all item selections are manual"): the forge's
// 2-epic fuel gets the same hand-pick treatment - epics-only rows, each worth
// 1 toward a goal of 2, no potion quota, dust shown alongside the gold.
function reagent_picker_open_awaken(target_cand) {
    var _rows = [];
    var _pool = cursed_rebirth_gear_of_rarity(3, target_cand.item);
    for (var _i = 0; _i < array_length(_pool); _i++) {
        var _g = _pool[_i];
        array_push(_rows, {
            kind: "gear", item: _g,
            label: variable_struct_exists(_g, "name") ? _g.name : "item",
            rarity: 3, pts: 1,
            value: item_sell_value(_g), sel: false
        });
    }
    array_sort(_rows, function(a, b) { return a.value - b.value; });
    for (var _i = 0; _i < min(2, array_length(_rows)); _i++) _rows[_i].sel = true;
    global.reagent_picker = {
        purpose: "maren_awaken",
        target: target_cand,
        fee: { feeds: 0, gold: 300, dust: 60, potions: 0 },
        goal: 2,
        rows: _rows, gear_n: array_length(_rows),
        cursor: 0, scroll: 0, confirm: false
    };
}

function reagent_picker_close() { global.reagent_picker = undefined; }

// Running tally of what's ticked: essence points, potion count, ask met.
function reagent_picker_tally() {
    var _p = global.reagent_picker;
    var _pts = 0, _pot = 0;
    for (var _i = 0; _i < array_length(_p.rows); _i++) {
        var _rw = _p.rows[_i];
        if (!_rw.sel) continue;
        if (_rw.kind == "gear") _pts += _rw.pts; else _pot++;
    }
    return { pts: _pts, pot: _pot, ok: (_pts >= _p.goal && _pot >= _p.fee.potions) };
}

// Input for the reagent stage. Cursor 0.._n-1 = rows (Enter/Space/click/tap
// TOGGLES), cursor _n = the SEAL bar (Enter arms, Enter again commits).
// Esc/right-click backs out of the arm, then cancels the whole exchange
// (nothing is lost). Geometry MUST match ui_draw_reagent_picker() (scr_ui).
function reagent_picker_step() {
    var _p = global.reagent_picker;
    if (_p == undefined) return;
    var _n = array_length(_p.rows);
    var _t = reagent_picker_tally();

    if (input_cancel() || input_back() || mouse_check_button_pressed(mb_right)) {
        if (_p.confirm) _p.confirm = false;
        else            reagent_picker_close();
        return;
    }

    if (nav_up())   { _p.cursor = wrap_index(_p.cursor - 1, _n + 1); _p.confirm = false; }
    if (nav_down()) { _p.cursor = wrap_index(_p.cursor + 1, _n + 1); _p.confirm = false; }
    if (mouse_wheel_up()   && _p.cursor > 0)  { _p.cursor--; _p.confirm = false; }
    if (mouse_wheel_down() && _p.cursor < _n) { _p.cursor++; _p.confirm = false; }
    _p.cursor = clamp(_p.cursor, 0, _n);
    if (_p.cursor < _n) _p.scroll = loadout_list_scroll(_p.cursor, _n, 8);

    var _act = (input_confirm() || input_confirm_alt());

    // Mouse/touch: row click toggles; SEAL bar click arms then commits.
    var _hit = -2;   // -2 = nothing, -1 = seal bar, else row index
    if (mouse_check_button_pressed(mb_left)) {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        var _px = 330, _py = 165, _pw = 1260, _ph = 750;
        var _lx0 = _px + 24, _lx1 = _px + 606, _ly0 = _py + 129, _rh = 57;
        var _cby0 = _py + _ph - 114, _cby1 = _py + _ph - 60;
        if (_my >= _cby0 && _my < _cby1 && _mx >= _px + 330 && _mx < _px + _pw - 330) _hit = -1;
        else if (!_p.confirm) {
            var _vis = min(8, _n);
            for (var _r = 0; _r < _vis; _r++) {
                var _ry = _ly0 + _r * _rh;
                if (_mx >= _lx0 && _mx < _lx1 && _my >= _ry && _my < _ry + 51) {
                    var _idx = _p.scroll + _r;
                    if (_idx < _n) _hit = _idx;
                    break;
                }
            }
        }
    }

    if (_hit >= 0) {
        _p.rows[_hit].sel = !_p.rows[_hit].sel;
        _p.cursor = _hit; _p.confirm = false;
        audio_play_sound(snd_page, 1, false);
        return;
    }
    if (_hit == -1) { _p.cursor = _n; _act = true; }

    if (_act) {
        if (_p.cursor < _n) {   // keyboard/pad toggle on the highlighted row
            _p.rows[_p.cursor].sel = !_p.rows[_p.cursor].sel;
            _p.confirm = false;
            audio_play_sound(snd_page, 1, false);
        } else {
            if (!_t.ok) { audio_play_sound(snd_ui_error, 1, false); return; }
            if (!_p.confirm)                            _p.confirm = true;
            else if (_p.purpose == "maren_awaken")      maren_awaken_commit();
            else                                        cursed_rebirth_commit();
        }
    }
}

// The exchange itself - burns EXACTLY the ticked rows + the gold + the
// offering, then runs the rebirth + ceremony. Mirrors the retired auto-burn
// resolve, minus the auto.
function cursed_rebirth_commit() {
    var _p = global.reagent_picker;
    if (_p == undefined) return;
    var _t = reagent_picker_tally();
    if (!_t.ok || global.gold < _p.fee.gold) { audio_play_sound(snd_ui_error, 1, false); return; }
    var _tgt = _p.target;
    var _new = cursed_rebirth_make(_tgt.item);
    cursed_rebirth_burn_gear(_tgt.item);   // the offering leaves stash or pack
    global.gold -= _p.fee.gold;
    var _gear_burned = 0, _pot_burned = 0;
    for (var _i = 0; _i < array_length(_p.rows); _i++) {
        var _rw = _p.rows[_i];
        if (!_rw.sel) continue;
        if (_rw.kind == "gear") { cursed_rebirth_burn_gear(_rw.item); _gear_burned++; }
        else {
            for (var _ci = 0; _ci < array_length(global.consumable_inventory); _ci++)
                if (global.consumable_inventory[_ci] == _rw.item) { array_delete(global.consumable_inventory, _ci, 1); break; }
            _pot_burned++;
        }
    }
    if (_tgt.source == 0) array_push(global.equipment_stash, _new);
    else                  array_push(global.carried_items, _new);
    discover_item(item_base_name(_new), _new.rarity);
    save_game();
    // Route the result line through the picker's one-shot so the Sable window
    // shows it exactly like the old flow did.
    global.item_picker.resolved_purpose = "cursed_rebirth";
    global.item_picker.result_msg = "The dark accepts... " + _new.name + " crawls back out.  (consumed: "
        + string(_gear_burned) + " gear, " + string(_pot_burned) + " potion" + ((_pot_burned == 1) ? "" : "s")
        + ", " + string(_p.fee.gold) + "g)";
    var _gcr = instance_find(obj_game_controller, 0);
    if (_gcr != noone) {
        _gcr.cursed_ritual_t    = 0;
        _gcr.cursed_ritual_item = _new;
        _gcr.cursed_ritual_prev = _tgt.item;
    } else {
        forge_result_open("CURSED REBIRTH", "The dark accepts the offering... and gives it back changed.",
            _new, _tgt.item, [], make_color_rgb(220, 90, 100));
    }
    ach_unlock("ACH_REBIRTH");   // achievement hook (08-05 wiring): a rebirth sealed
    audio_play_sound(snd_forge, 1, false);
    reagent_picker_close();
}

// Maren's forge lights with EXACTLY the ticked epics (M 08-05 - the old resolve
// auto-burned the 2 junkiest). Wakes the dormant legendary, itemizes the fuel.
function maren_awaken_commit() {
    var _p = global.reagent_picker;
    if (_p == undefined) return;
    var _t = reagent_picker_tally();
    if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
    if (!_t.ok || global.gold < _p.fee.gold || global.rune_dust < _p.fee.dust) {
        audio_play_sound(snd_ui_error, 1, false); return;
    }
    var _aw_it = _p.target.item;
    global.gold      -= _p.fee.gold;
    global.rune_dust -= _p.fee.dust;
    var _burned = [];
    for (var _i = 0; _i < array_length(_p.rows); _i++) {
        var _rw = _p.rows[_i];
        if (!_rw.sel) continue;
        cursed_rebirth_burn_gear(_rw.item);
        array_push(_burned, _rw.label);
    }
    // Snapshot BEFORE waking it - awakening is the single biggest stat jump in
    // the game (x0.55 -> x1.0 on every positive) and the player never got to see
    // it happen (M 08-08 before/after order).
    var _aw_was = item_shallow_copy(_aw_it);
    _aw_it.dormant = false;
    if (string_copy(_aw_it.name, 1, 8) == "Dormant ") _aw_it.name = string_delete(_aw_it.name, 1, 8);
    _aw_it.icon_seed = irandom(999983);   // it wakes wearing a new face
    save_game();
    global.item_picker.resolved_purpose = "maren_awaken";
    global.item_picker.result_msg = _aw_it.name + " AWAKENS.  (consumed: "
        + string(array_length(_burned)) + " epics, " + string(_p.fee.gold) + "g, "
        + string(_p.fee.dust) + " dust)";
    var _fr_lines = [];
    for (var _i = 0; _i < array_length(_burned); _i++) array_push(_fr_lines, "Burned:  " + _burned[_i]);
    array_push(_fr_lines, string(_p.fee.gold) + "g + " + string(_p.fee.dust) + " rune dust");
    forge_result_open("AWAKENING", "The legend remembers what it was.",
        _aw_it, _aw_was, _fr_lines, make_color_rgb(255, 205, 110));
    audio_play_sound(snd_confirm_major, 1, false);
    reagent_picker_close();
}

// =============================================================================
// DARK GIFTS (M 08-04): every 3rd curse, the reassemblage adds something NEW -
// a NAMED boon rolled blind from this catalog, magnitude rolled too. Names are
// combined-effect words in the item-name tradition (Emberwake, Bonelattice...).
// kind "affix" gifts ride the existing _equip_apply_stat plumbing untouched;
// kind "gift" entries live in item.dark_gifts and are read by combat hooks via
// dark_gift_total(). Duplicates can roll and stack - that's the chaos.
// =============================================================================
function dark_gift_catalog() {
    return [
        // School hearts - flat school damage (SYSTEMS_ELEMENT_SCHOOLS §C keys).
        { id:"emberwake",   name:"Emberwake",   kind:"affix", stat:"school_fire",   lo:4,  hi:9,  blurb:"+# Fire damage" },
        { id:"rimeheart",   name:"Rimeheart",   kind:"affix", stat:"school_frost",  lo:4,  hi:9,  blurb:"+# Frost damage" },
        { id:"stormlung",   name:"Stormlung",   kind:"affix", stat:"school_shock",  lo:4,  hi:9,  blurb:"+# Shock damage" },
        { id:"hollowlight", name:"Hollowlight", kind:"affix", stat:"school_arcane", lo:4,  hi:9,  blurb:"+# Arcane damage" },
        { id:"redthirst",   name:"Redthirst",   kind:"affix", stat:"school_blood",  lo:4,  hi:9,  blurb:"+# Blood damage" },
        { id:"voidmaw",     name:"Voidmaw",     kind:"affix", stat:"school_void",   lo:4,  hi:9,  blurb:"+# Void damage" },
        { id:"nightbloom",  name:"Nightbloom",  kind:"affix", stat:"school_shadow", lo:4,  hi:9,  blurb:"+# Shadow damage" },
        { id:"gravebloom",  name:"Gravebloom",  kind:"affix", stat:"school_poison", lo:4,  hi:9,  blurb:"+# Poison damage" },
        // Body gifts - existing affix keys.
        { id:"gravecoin",   name:"Gravecoin",   kind:"affix", stat:"gold_find",     lo:20, hi:40, blurb:"+#% Gold find" },
        { id:"mothstep",    name:"Mothstep",    kind:"affix", stat:"dodge_flat",    lo:4,  hi:8,  blurb:"+# Dodge" },
        { id:"palefang",    name:"Palefang",    kind:"affix", stat:"crit_flat",     lo:5,  hi:10, blurb:"+#% Crit (all attacks)" },
        { id:"oxblood",     name:"Oxblood",     kind:"affix", stat:"bonus_max_hp",  lo:15, hi:30, blurb:"+# Max HP" },
        { id:"ironmarrow",  name:"Ironmarrow",  kind:"affix", stat:"armor",         lo:2,  hi:4,  blurb:"+# Armor" },
        { id:"wardglass",   name:"Wardglass",   kind:"affix", stat:"el_resist",     lo:2,  hi:4,  blurb:"+# Elemental resist" },
        { id:"spellfang",   name:"Spellfang",   kind:"affix", stat:"crit_spell",    lo:8,  hi:14, blurb:"+#% Spell crit" },
        { id:"bonefang",    name:"Bonefang",    kind:"affix", stat:"crit_phys",     lo:8,  hi:14, blurb:"+#% Phys crit" },
        // Bespoke gifts - combat hooks read these via dark_gift_total().
        { id:"fifth_pulse", name:"Fifth Pulse", kind:"gift",  stat:"ap_pulse",      lo:1,  hi:1,  blurb:"+1 AP every 5th round" },
        { id:"nightgorge",  name:"Nightgorge",  kind:"gift",  stat:"heal_on_kill",  lo:2,  hi:4,  blurb:"heal # on kill" },
        { id:"bonelattice", name:"Bonelattice", kind:"gift",  stat:"shield_start",  lo:4,  hi:8,  blurb:"+# Soul Shield at combat start" },
    ];
}

// Total of one bespoke dark-gift stat across EQUIPPED gear (combat hooks call
// this; a hard-2H weapon locks the offhand out, same rule as equipment stats).
function dark_gift_total(key) {
    var _t = 0;
    if (!variable_global_exists("inventory")) return 0;
    var _off_locked = hard_two_handed_equipped();
    for (var _i = 0; _i < array_length(global.inventory); _i++) {
        if (_i == 1 && _off_locked) continue;
        var _it = global.inventory[_i];
        if (_it == undefined || !is_struct(_it) || !variable_struct_exists(_it, "dark_gifts")) continue;
        for (var _g = 0; _g < array_length(_it.dark_gifts); _g++)
            if (_it.dark_gifts[_g].stat == key) _t += _it.dark_gifts[_g].mag;
    }
    return _t;
}

function cursed_rebirth_make(src) {
    // 07-31 REBALANCE (M + GDD: "mega strength and mega weakness" - the old
    // x1.5 + one -12 HP affix was "pointless"): stats DOUBLE, and the curse is
    // a fight-altering wound. The curse never lands on the item's own primary
    // stat, so the boon can't be silently washed out.
    var _it = clone_item(src);
    var _bn = item_base_name(src);
    // Codex identity NEVER stacks (a thrice-fed crown is still one discovery) -
    // strip any prior brand before re-applying.
    if (string_copy(_bn, 1, 7) == "Cursed ") _bn = string_delete(_bn, 1, 7);
    _it.base_name   = "Cursed " + _bn;   // codex identity (discover_item)
    // Escalating-reassemblage bookkeeping (M 08-04): each feed is tracked so
    // the cost ladder can charge per curse already on the item.
    _it.curse_count = (variable_struct_exists(src, "curse_count") ? src.curse_count : 0) + 1;
    // Every feed also re-rolls the LOOK (M 08-04: emergent variants) - the
    // saved icon_seed shifts the variant hash to a fresh model each rebirth.
    _it.icon_seed = irandom(999983);
    _it.splash_base = _bn;               // reveal popup falls back to the original splash art
    _it.rarity      = 4;
    _it.cursed      = true;
    // RNG REASSEMBLAGE (M 08-04, replaces flat x2-everything - which also
    // re-doubled OLD curses into oblivion by feed 3): every feed rolls ONE
    // positive surge and ONE curse, both with wide ranges. God rolls exist,
    // busts exist, and a lucky early item can still be dragged down later -
    // the min-max prayer is the game. Old curses are NEVER re-scaled; they
    // accumulate at whatever bite they rolled.
    var _surge = 1.10 + random(1.30);   // x1.10 .. x2.40 on the item's positives
    if (variable_struct_exists(_it, "stat_value"))    _it.stat_value    = ceil(_it.stat_value * _surge);
    if (variable_struct_exists(_it, "weapon_damage") && _it.weapon_damage > 0) _it.weapon_damage = ceil(_it.weapon_damage * _surge);
    if (variable_struct_exists(_it, "affixes")) {
        for (var _i = 0; _i < array_length(_it.affixes); _i++) {
            // Negatives (old curses) never re-scale; dark-gift affixes stay at
            // their rolled value too (their unique_desc line names the number).
            if (_it.affixes[_i].stat_value > 0 && !variable_struct_exists(_it.affixes[_i], "gift"))
                _it.affixes[_i].stat_value = ceil(_it.affixes[_i].stat_value * _surge);
        }
    } else {
        _it.affixes = [];
    }
    var _curses = [
        { stat_name: "bonus_max_hp", stat_value: -30, suffix: "of Withering",    epithet: "Withered"   },
        { stat_name: "crit_flat",    stat_value: -12, suffix: "of Dulled Fate",  epithet: "Dulled"     },
        { stat_name: "dodge_flat",   stat_value: -12, suffix: "of Leaden Feet",  epithet: "Leaden"     },
        { stat_name: "gold_find",    stat_value: -40, suffix: "of the Beggared", epithet: "Beggared"   },
        { stat_name: "CON",          stat_value: -6,  suffix: "of Rot",          epithet: "Rotting"    },
        { stat_name: "WIS",          stat_value: -6,  suffix: "of Whispers",     epithet: "Whispering" },
        { stat_name: "STR",          stat_value: -6,  suffix: "of Palsy",        epithet: "Palsied"    },
        { stat_name: "INT",          stat_value: -6,  suffix: "of the Hollowed", epithet: "Hollowed"   },
    ];
    var _prim = variable_struct_exists(_it, "stat_name") ? _it.stat_name : "";
    var _c = _curses[irandom(array_length(_curses) - 1)];
    while (_c.stat_name == _prim) _c = _curses[irandom(array_length(_curses) - 1)];
    // Curse magnitude rolls too: 60%..160% of the table's base bite.
    var _cmag = 0.6 + random(1.0);
    array_push(_it.affixes, { suffix: _c.suffix, prefix: "", stat_name: _c.stat_name,
        stat_value: -max(1, ceil(abs(_c.stat_value) * _cmag)) });
    // DARK GIFT (M 08-04): every 3rd curse the dark adds something NEW - a
    // named boon rolled blind, magnitude rolled too. Affix-kind gifts join the
    // stat plumbing directly; bespoke gifts live in dark_gifts for the combat
    // hooks. The gift line is stamped into unique_desc so every detail pane,
    // forge reveal and loadout tooltip shows it by name.
    if (_it.curse_count mod 3 == 0) {
        var _dg_cat = dark_gift_catalog();
        var _dg  = _dg_cat[irandom(array_length(_dg_cat) - 1)];
        var _dgm = irandom_range(_dg.lo, _dg.hi);
        if (_dg.kind == "affix") {
            array_push(_it.affixes, { suffix: "", prefix: "", stat_name: _dg.stat, stat_value: _dgm, gift: true });
        } else {
            if (!variable_struct_exists(_it, "dark_gifts")) _it.dark_gifts = [];
            array_push(_it.dark_gifts, { id: _dg.id, stat: _dg.stat, mag: _dgm });
        }
        var _dg_line = "DARK GIFT - " + _dg.name + ": " + string_replace(_dg.blurb, "#", string(_dgm));
        _it.unique_desc = (variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "")
            ? (_it.unique_desc + "\n" + _dg_line) : _dg_line;
    }
    // The curse lives in the TITLE (M 07-31): "Cursed Crown of the Hollow King, Withered".
    // And it STACKS on purpose (M 08-04: the absurd grinded title IS the flex) -
    // re-feeding prefixes another "Cursed" onto the FULL previous name, so every
    // epithet earned stays in the title: "Cursed Cursed Crown ..., Withered, Rotting".
    // (The old code rebuilt from the base name and silently dropped past epithets.)
    _it.name = "Cursed " + src.name + ", " + _c.epithet;
    _it.gold_value = 250;
    _it.lore = "A legendary fed back to the dark. What crawled out is far stronger than what went in - and it kept something of yours in exchange.";
    return _it;
}

// Returns rarity weights [common%, uncommon%, rare%, epic%, legendary%] for a
// drop SOURCE, scaled by awakening tier `asc` (0..5). Each source lerps from an
// A0 baseline (common-heavy; rares/legendaries very rare) to an A5 ceiling.
// Higher awakening = better loot. Premium sources (reliquary) keep no common floor.
// Source names: "standard", "elite", "boss", "chest", "vault", "reliquary", "dorn".
// ---------------------------------------------------------------------------
function drop_weights(source, asc, true_asc = -1) {
    // true_asc = the character's REAL awakening when `asc` arrives inflated
    // (boss_drop_weights folds floors into it - the exact leak that handed M a
    // legendary at A2). The early-tier squeeze below keys on the real tier.
    var _ta = (true_asc < 0) ? asc : true_asc;
    asc = clamp(asc, 0, 5);
    var _a0, _a5;
    switch (source) {
        // A5 anchors steepened (BALANCE_NOTE C2, M-approved 07-09): high Awakening
        // pays in rarity - legendaries now exist outside bosses (2% mobs / 6% elites),
        // and an A5 standard mob is 36% rare-or-better (was 22%). A0 anchors and the
        // lerp are untouched, so every tier between scales smoothly.
        // A0 anchors trimmed 08-13 (M: "3 rares by floor 2 on a very first A0
        // run is way too much power creep"). Audit finding: loot weights are
        // DUNGEON-AGNOSTIC (Scorched/Tundra = Vault at equal awakening) - the
        // shower came from the reliquary (was 40% rare-or-better, guaranteed,
        // 1+ per floor-2/3) and the floor-1 boss (was 25% rare+). Boss rare
        // 21 -> 15, epic 3 -> 2, A0 legendary 1 -> 0 (floor folding still
        // grants deep-floor bosses their epic/legendary shot); reliquary rare
        // 32 -> 20, epic 7 -> 4, legendary 1 -> 0. A5 anchors untouched
        // (BALANCE_NOTE C2, M-approved 07-09), so high tiers pay as before.
        case "standard":  _a0 = [90,  9,  1,  0, 0]; _a5 = [28, 36, 24, 10, 2]; break;
        case "elite":     _a0 = [72, 23,  5,  0, 0]; _a5 = [10, 30, 34, 20, 6]; break;
        case "boss":      _a0 = [58, 33,  8,  1, 0]; _a5 = [ 0, 20, 38, 30, 12]; break;   // 08-18 A0 leans common (M)
        case "chest":     _a0 = [86, 12,  2,  0, 0]; _a5 = [20, 36, 28, 13, 3]; break;
        case "vault":     _a0 = [78, 18,  3,  1, 0]; _a5 = [12, 32, 32, 18, 6]; break;
        case "reliquary": _a0 = [25, 58, 15,  2, 0]; _a5 = [ 0, 25, 40, 28, 7]; break;
        case "dorn":      _a0 = [65, 30,  5,  0, 0]; _a5 = [10, 35, 35, 18, 2]; break;
        default:          _a0 = [90,  9,  1,  0, 0]; _a5 = [28, 36, 24, 10, 2]; break;
    }
    // LATE RAMP (M 08-16: "items scale up too fast, rares and epics too
    // quickly"): the A0->A5 lerp now runs on t^1.5, so the anchors stay
    // (M-approved) but the middle tiers sit closer to A0 - A1 reads at ~9%
    // of the way (was 20%), A2 ~25% (was 40%), A3 ~46% (was 60%), A4 ~72%
    // (was 80%), A5 unchanged.
    var _t = power(asc / 5, 1.5);
    var _w = array_create(5, 0);
    var _sum = 0;
    // Lerp the upper four tiers; common (index 0) absorbs the remainder so the
    // weights always sum to 100 regardless of rounding.
    for (var _i = 1; _i < 5; _i++) {
        _w[_i] = round(lerp(_a0[_i], _a5[_i], _t));
        _sum += _w[_i];
    }
    _w[0] = max(0, 100 - _sum);
    // Dorn's legendary shelf is END-GAME stock (M 07-29: a legendary for sale
    // right after A2 read as wrong - the linear lerp was granting ~1% per slot
    // from A2 up). Below A4 the weights hold none; restock_shops adds a
    // 1-in-200 jackpot roll instead.
    if (source == "dorn" && asc < 4 && _w[4] > 0) { _w[0] += _w[4]; _w[4] = 0; }
    // EARLY-TIER SQUEEZE (M-locked 08-15: "slow progression down... very very
    // low chance over a hard gate"). Below TRUE Awakening 3 the legendary
    // weight pours into epic, then an ~1-in-8 roll hands back a single point -
    // net ~0.125% per drop: the one lucky player still exists, barely. Below
    // TRUE Awakening 2 epics are halved into rare so A0-A1 chases rares.
    if (_ta < 3 && _w[4] > 0) {
        _w[3] += _w[4];
        _w[4]  = (irandom(7) == 0) ? 1 : 0;
    }
    if (_ta < 2 && _w[3] > 1) {
        var _sq = _w[3] div 2;
        _w[3] -= _sq;
        _w[2] += _sq;
    }
    // Premium sources have no common floor: route the leftover into uncommon.
    if (_a0[0] == 0 && _a5[0] == 0) {
        _w[1] += _w[0];
        _w[0]  = 0;
    }
    return _w;
}

// ---------------------------------------------------------------------------
// boss_drop_weights(asc, fl) - boss rarity weights with the FLOOR folded in
// (task #19): each floor past the first counts as one extra awakening tier on
// the lerp, then hard floors cut the bottom tiers entirely - a floor-2 boss
// never drops common, a floor-3 boss never drops below rare. Sits on top of the
// awakening lerp. (Curse loot-tiers are NOT in `asc` any more - they're applied
// as a post-roll rarity bump inside drop_equipment. See curse_loot_tier_bonus.)
// ---------------------------------------------------------------------------
function boss_drop_weights(asc, fl) {
    var _w = drop_weights("boss", asc + max(0, fl - 1), asc);   // true tier caps the squeeze
    if (fl >= 2) { _w[1] += _w[0]; _w[0] = 0; }   // hard floor: uncommon+
    if (fl >= 3) { _w[2] += _w[1]; _w[1] = 0; }   // hard floor: rare+
    return _w;
}

// ---------------------------------------------------------------------------
// drop_equipment(rarity_weights, do_discover, curse_tiers)
// Full drop pipeline: pick rarity, clone a base item, roll and apply affixes.
// rarity_weights: [common%, uncommon%, rare%, epic%, legendary%]
// Common=0 affixes, uncommon=1, rare=1-2 (50/50), epic=2, legendary=fixed.
// do_discover (default true): record the item in the codex. Shop stock passes
// false so items are only discovered when actually bought.
// ---------------------------------------------------------------------------
// curse_tiers: literal rarity levels ADDED after the roll (curse "Loot rarity +N
// tiers"). Opt-in per call site - run drops pass curse_loot_tier_bonus(), hub
// sources (Dorn's stock, vault previews) pass nothing so curses can never leak
// into shop inventory. See the bump below for why this is post-roll, not an
// awakening offset.
// Run call sites should get the curse component via curse_loot_tier_bonus_for(
// source) - below Awakening 2 only boss/vault/reliquary drops receive it.
// ---------------------------------------------------------------------------
// item_empower(item, eff_asc, depth_floor) - endless item-level scaling
// (SYSTEMS_ENDLESS.md): past effective Awakening 5 an item's numeric power
// grows +6%/tier compounding - primary stat, weapon damage, every affix
// magnitude. Descent drops also get the "Depthforged - Floor N" name tag
// (base_name stays untouched, so the codex identity is safe).
// ---------------------------------------------------------------------------
function item_empower(item, eff_asc, depth_floor = 0) {
    if (!is_struct(item) || eff_asc <= 5) return item;
    var _m = power(1.06, eff_asc - 5);
    if (variable_struct_exists(item, "stat_value") && item.stat_value > 0)
        item.stat_value = max(item.stat_value + 1, round(item.stat_value * _m));
    if (variable_struct_exists(item, "weapon_damage") && item.weapon_damage > 0)
        item.weapon_damage = max(item.weapon_damage + 1, round(item.weapon_damage * _m));
    if (variable_struct_exists(item, "affixes")) {
        for (var _emp_i = 0; _emp_i < array_length(item.affixes); _emp_i++) {
            var _emp_af = item.affixes[_emp_i];
            if (variable_struct_exists(_emp_af, "stat_value") && _emp_af.stat_value > 0)
                _emp_af.stat_value = max(_emp_af.stat_value + 1, round(_emp_af.stat_value * _m));
        }
    }
    item.item_level = eff_asc;
    if (depth_floor > 0) {
        item.depth_floor = depth_floor;
        item.name = item.name + "  [Depthforged - Floor " + string(depth_floor) + "]";
        item.gold_value = round(item.gold_value * _m);
    }
    return item;
}

// The effective tier + descent floor drop_equipment feeds item_empower with.
function item_empower_context() {
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    var _df  = (variable_global_exists("descent_active") && global.descent_active
                && variable_global_exists("descent_floor")) ? global.descent_floor : 0;
    return { asc: _asc, df: _df };
}

// =============================================================================
// TEMPERING + DORMANCY (M locked 08-04, SYSTEMS_ITEM_PROGRESSION.md §1-2).
// Every DROP rolls a QUALITY (45-70%, 08-18 nerf; was 60-85); Dorn TEMPERS it +10%/step to 100
// (gold + dust by rarity). Generic stat-legendaries drop DORMANT (~0.55x)
// until Maren AWAKENS them (300g + 60 dust + 2 epics); the named uniques
// (unique_effect) always drop TRUE. Missing fields read as quality-100 /
// not-dormant, so every pre-08-04 item is grandfathered whole. Scaling is
// applied at STAT-APPLICATION time (apply_equipment_stats) - the stored rolls
// never change, and ui_item_stat_str tags the state.
// =============================================================================
function item_quality_stamp(it, lo, hi) {
    if (is_struct(it)) {
        it.quality = irandom_range(lo, hi);
        // The rolled quality is the FINISH floor (M 08-11): the temper HP bonus
        // counts only points the smith adds above this, so a fresh drop carries
        // no bonus and the reveal happens at the anvil, not on the loot screen.
        it.quality_base = it.quality;
    }
}

// Effective multiplier on an item's POSITIVE stats: quality% x dormant 0.55.
function item_power_mult(it) {
    var _m = 1.0;
    if (is_struct(it) && variable_struct_exists(it, "quality")) _m *= clamp(it.quality, 1, 100) / 100;
    if (is_struct(it) && variable_struct_exists(it, "dormant") && it.dormant) _m *= 0.55;
    return _m;
}

// Positive values scale (floor 1); negatives (curses) are NEVER softened.
function item_scaled_val(v, pm) {
    return (v > 0 && pm < 1.0) ? max(1, round(v * pm)) : v;
}

// -----------------------------------------------------------------------------
// FINISH (M 08-08) - quality's OWN contribution, on top of the scaling above.
//
// Pure multiplicative quality is INVISIBLE on small items: item_scaled_val(1, 0.7)
// is max(1, round(0.7)) = 1, and so is item_scaled_val(1, 1.0). A "+1 DEX" ring
// therefore delivered exactly the same stats at 60% as at 100% - the player paid
// 40g + 5 dust a step for a number that mathematically could not move (M's temper
// report + screenshot). No multiplier can fix that: a 1-point roll has nothing to
// scale. So quality now also GRANTS something of its own.
//
// Finish = flat max HP per quality point TEMPERED above the drop roll
// (quality_base, M 08-11 - counting from the flat 60 floor let a fresh 82% drop
// show a "tempering bonus" it never earned, spoiling the reveal). Every temper
// step buys real points, so every purchase moves a real number on EVERY item.
// HP is the one bonus every slot can carry (armour is weight-class gated,
// damage is weapon-only), and it reads honestly: a finished piece holds
// together better.
// Dormant pieces give nothing until Maren wakes them; pre-08-04 gear has no
// quality field at all and is grandfathered whole, so it has no finish either.
// -----------------------------------------------------------------------------
// Quality POINTS tempered above the drop roll. Per-POINT rather than
// per-10%-step (M 08-08): the final step off an 85% roll is only 5 points, and
// under the old step model those 5 points paid nothing at all.
function item_finish_steps(it) {
    if (!is_struct(it) || !variable_struct_exists(it, "quality")) return 0;
    if (variable_struct_exists(it, "dormant") && it.dormant) return 0;
    // Points TEMPERED above the drop roll, not above the 60 floor (M 08-11: a
    // fresh 82% drop showed a "tempering bonus" it never earned). Items saved
    // before quality_base existed can't have rolled above 85, so min(quality,85)
    // reconstructs their roll exactly for untampered gear and only undercounts
    // pieces already tempered past 85.
    var _base = variable_struct_exists(it, "quality_base")
                ? it.quality_base : min(it.quality, 85);
    return clamp(it.quality - _base, 0, 40);
}

function item_finish_hp(it) {
    var _pts = item_finish_steps(it);
    if (_pts <= 0) return 0;
    var _r   = clamp((is_struct(it) && variable_struct_exists(it, "rarity")) ? it.rarity : 0, 0, 4);
    // Per point. Totals at a fully finished 100%: 4 / 6 / 8 / 12 / 16 HP
    // (08-16 M: "an epic gave me 16 HP from 8 in ONE temper... becoming a tank
    // on my mage" - was 8/12/20/32/48, an epic step paid +8; now +3).
    // A piece bought up from 60% therefore gains the WHOLE track, while one that
    // dropped at 90% only has a quarter of it left to buy - the gain scales with
    // the gap you closed, exactly like the cost does.
    var _per = [0.1, 0.15, 0.2, 0.3, 0.4];
    return max(1, round(_per[_r] * _pts));
}

// -----------------------------------------------------------------------------
// BEFORE / AFTER COMPARISON (M 08-08: "the before and after should popup as a
// side by side to see what improvements you just made").
//
// Crafts that MUTATE an item in place (temper, awaken, reforge, re-attune) have
// to snapshot it first, because the reveal popup runs after the mutation.
// item_shallow_copy is enough: the comparison only reads scalars and an array
// length, and a deep copy would needlessly duplicate rune/affix structs.
// -----------------------------------------------------------------------------
function item_shallow_copy(it) {
    if (!is_struct(it)) return it;
    var _c = {};
    var _n = variable_struct_get_names(it);
    for (var _i = 0; _i < array_length(_n); _i++)
        variable_struct_set(_c, _n[_i], variable_struct_get(it, _n[_i]));
    return _c;
}

function item_field_num(it, key, dflt) {
    if (!is_struct(it) || !variable_struct_exists(it, key)) return dflt;
    var _v = variable_struct_get(it, key);
    return is_real(_v) ? _v : dflt;
}

function item_field_str(it, key, dflt) {
    if (!is_struct(it) || !variable_struct_exists(it, key)) return dflt;
    var _v = variable_struct_get(it, key);
    return is_string(_v) ? _v : dflt;
}

// item_compare_rows(before, after) -> array of { label, a, b, better }
// Only fields present on ONE side or the other produce a row, so the table is
// never padded with irrelevant zeroes. Values are the EFFECTIVE (quality-scaled)
// numbers, not the stored rolls - the stored roll is exactly what was hiding the
// tempering problem from the player. better: 1 up, -1 down, 0 flat/incomparable.
function item_compare_rows(_a, _b) {
    var _rows = [];
    if (!is_struct(_a) || !is_struct(_b)) return _rows;
    var _pa = item_power_mult(_a), _pb = item_power_mult(_b);

    // Identity, only when the craft actually renamed or re-tiered the piece.
    var _na = item_field_str(_a, "name", ""), _nb = item_field_str(_b, "name", "");
    if (_na != _nb) array_push(_rows, { label:"Item", a:_na, b:_nb, better:0 });
    var _ra = item_field_num(_a, "rarity", 0), _rb = item_field_num(_b, "rarity", 0);
    if (_ra != _rb) array_push(_rows, { label:"Rarity", a:item_rarity_name(_ra), b:item_rarity_name(_rb), better:sign(_rb - _ra) });

    // Primary stat, EFFECTIVE - this is where quality scaling becomes visible.
    var _sa = item_field_str(_a, "stat_name", ""), _sb = item_field_str(_b, "stat_name", "");
    if (_sa != "" || _sb != "") {
        var _va = (_sa == "") ? 0 : item_scaled_val(item_field_num(_a, "stat_value", 0), _pa);
        var _vb = (_sb == "") ? 0 : item_scaled_val(item_field_num(_b, "stat_value", 0), _pb);
        if (_sa == _sb) {
            if (_va != 0 || _vb != 0)
                array_push(_rows, { label:_sb, a:"+" + string(_va), b:"+" + string(_vb), better:sign(_vb - _va) });
        } else {
            array_push(_rows, { label:"Stat",
                a:((_sa == "") ? "-" : ("+" + string(_va) + " " + _sa)),
                b:((_sb == "") ? "-" : ("+" + string(_vb) + " " + _sb)), better:0 });
        }
    }

    var _wa = item_scaled_val(item_field_num(_a, "weapon_damage", 0), _pa);
    var _wb = item_scaled_val(item_field_num(_b, "weapon_damage", 0), _pb);
    if (_wa > 0 || _wb > 0)
        array_push(_rows, { label:"Weapon dmg", a:"+" + string(_wa), b:"+" + string(_wb), better:sign(_wb - _wa) });

    var _aa = item_base_armor(_a), _ab = item_base_armor(_b);
    if (_aa > 0 || _ab > 0)
        array_push(_rows, { label:"Armor", a:"+" + string(_aa), b:"+" + string(_ab), better:sign(_ab - _aa) });
    var _ea = item_base_el_resist(_a), _eb = item_base_el_resist(_b);
    if (_ea > 0 || _eb > 0)
        array_push(_rows, { label:"Elem. Resist", a:"+" + string(_ea), b:"+" + string(_eb), better:sign(_eb - _ea) });

    var _fa = (variable_struct_exists(_a, "affixes") && is_array(_a.affixes)) ? array_length(_a.affixes) : 0;
    var _fb = (variable_struct_exists(_b, "affixes") && is_array(_b.affixes)) ? array_length(_b.affixes) : 0;
    if (_fa != _fb)
        array_push(_rows, { label:"Affixes", a:string(_fa), b:string(_fb), better:sign(_fb - _fa) });

    var _da = (variable_struct_exists(_a, "dormant") && _a.dormant);
    var _db = (variable_struct_exists(_b, "dormant") && _b.dormant);
    if (_da != _db)
        array_push(_rows, { label:"State", a:(_da ? "Dormant" : "Awake"), b:(_db ? "Dormant" : "Awake"), better:(_db ? -1 : 1) });

    // The tempering pair, last: Quality is the number the player bought, Finish
    // is the number it actually moved.
    if (variable_struct_exists(_a, "quality") || variable_struct_exists(_b, "quality")) {
        var _qa = item_field_num(_a, "quality", 100), _qb = item_field_num(_b, "quality", 100);
        array_push(_rows, { label:"Quality", a:string(_qa) + "%", b:string(_qb) + "%", better:sign(_qb - _qa) });
        var _ha = item_finish_hp(_a), _hb = item_finish_hp(_b);
        if (_ha > 0 || _hb > 0)
            array_push(_rows, { label:"Finish", a:"+" + string(_ha) + " HP", b:"+" + string(_hb) + " HP", better:sign(_hb - _ha) });
    }
    return _rows;
}

// -----------------------------------------------------------------------------
// TEMPER FEE - priced on the DEFICIT, not a flat step (M 08-08).
//
// The old fee was one flat charge per +10% regardless of rarity-appropriate value
// or how rough the piece was, which made tempering a common item actively
// irrational: "spending 40 gold on a common item will always be pointless".
//
// Now the whole thing scales with the gap to 100%:
//   - cost per POINT of quality, by rarity, so a common piece costs a few gold a
//     step and a legendary still costs real money
//   - a rough piece (60%) costs more to finish than a nearly-done one (90%)
//     because there is more of it to buy - but each point is the same price, so
//     nothing is ever a trap purchase
//   - dust only enters at epic/legendary; commons and uncommons are pure gold, so
//     early optimisation is never gated behind a scarce currency
//
// M's intent: less gear/power creep from churning new drops, more reason to
// invest in the common and uncommon gear already in your bag.
// -----------------------------------------------------------------------------
function temper_step_size() { return 10; }

// Gold per single POINT of quality, by rarity.
// Retuned 08-13 (M: "140g to gain 5hp on an epic item when an epic item
// outright costs about that makes no sense... rare and epic should have their
// prices brought down much more"). Commons/uncommons kept (M: priced
// correctly); rare 5 -> 2.5, epic 14 -> 6, legendary 34 -> 15 in proportion.
// Per +10% step that is: 6 / 15 / 25 / 60 / 150 gold.
function temper_gold_per_point(rarity) {
    var _g = [0.6, 1.5, 2.5, 6, 15];
    return _g[clamp(rarity, 0, 4)];
}

// Rune dust per point - epic+ only. Commons/uncommons cost gold alone.
// (Same 08-13 retune: epic 1.1 -> 0.7, legendary 2.6 -> 1.5 per point.)
function temper_dust_per_point(rarity) {
    var _d = [0, 0, 0, 0.7, 1.5];
    return _d[clamp(rarity, 0, 4)];
}

// Fee for the NEXT step on this item. The final step can be a partial one (an
// 85% piece steps 85 -> 95 -> 100, and that last one is 5 points, so it is
// charged for 5), which keeps the price honest at the top of the track.
function temper_fee(it) {
    var _r = clamp((is_struct(it) && variable_struct_exists(it, "rarity")) ? it.rarity : 0, 0, 4);
    var _q = clamp((is_struct(it) && variable_struct_exists(it, "quality")) ? it.quality : 100, 0, 100);
    var _pts = min(temper_step_size(), 100 - _q);
    if (_pts <= 0) return { gold: 0, dust: 0, points: 0 };
    return {
        gold:   max(1, round(temper_gold_per_point(_r) * _pts)),
        dust:   ((temper_dust_per_point(_r) > 0) ? max(1, round(temper_dust_per_point(_r) * _pts)) : 0),
        points: _pts
    };
}

// Total cost to carry a piece all the way to 100% - shown on the temper screen so
// the player can judge the whole investment, not just the next click.
function temper_fee_to_full(it) {
    var _r = clamp((is_struct(it) && variable_struct_exists(it, "rarity")) ? it.rarity : 0, 0, 4);
    var _q = clamp((is_struct(it) && variable_struct_exists(it, "quality")) ? it.quality : 100, 0, 100);
    var _pts = 100 - _q;
    if (_pts <= 0) return { gold: 0, dust: 0, points: 0 };
    return {
        gold:   max(1, round(temper_gold_per_point(_r) * _pts)),
        dust:   ((temper_dust_per_point(_r) > 0) ? max(1, round(temper_dust_per_point(_r) * _pts)) : 0),
        points: _pts
    };
}

// Picker candidates: gear below 100% quality (worn + stash + pack). Dormant
// items are excluded - awaken FIRST, then temper (one pipeline order).
function item_picker_candidates_temperable() {
    var _out = [];
    var _pools = [];
    if (variable_global_exists("inventory")       && is_array(global.inventory))       array_push(_pools, { a: global.inventory,       s: 0 });
    if (variable_global_exists("equipment_stash") && is_array(global.equipment_stash)) array_push(_pools, { a: global.equipment_stash, s: 0 });
    if (variable_global_exists("carried_items")   && is_array(global.carried_items))   array_push(_pools, { a: global.carried_items,   s: 1 });
    for (var _p = 0; _p < array_length(_pools); _p++) {
        var _arr = _pools[_p].a;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _g2 = _arr[_i];
            if (!is_struct(_g2) || !variable_struct_exists(_g2, "quality") || _g2.quality >= 100) continue;
            if (variable_struct_exists(_g2, "dormant") && _g2.dormant) continue;
            array_push(_out, { source: _pools[_p].s, idx: _i, item: _g2,
                label: _g2.name + "  (" + string(_g2.quality) + "%)",
                rarity: variable_struct_exists(_g2, "rarity") ? _g2.rarity : 0,
                value: variable_struct_exists(_g2, "gold_value") ? _g2.gold_value : 0 });
        }
    }
    return _out;
}

// Picker candidates: dormant legendaries (worn + stash + pack).
function item_picker_candidates_dormant() {
    var _out = [];
    var _pools = [];
    if (variable_global_exists("inventory")       && is_array(global.inventory))       array_push(_pools, { a: global.inventory,       s: 0 });
    if (variable_global_exists("equipment_stash") && is_array(global.equipment_stash)) array_push(_pools, { a: global.equipment_stash, s: 0 });
    if (variable_global_exists("carried_items")   && is_array(global.carried_items))   array_push(_pools, { a: global.carried_items,   s: 1 });
    for (var _p = 0; _p < array_length(_pools); _p++) {
        var _arr = _pools[_p].a;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _g2 = _arr[_i];
            if (!is_struct(_g2) || !variable_struct_exists(_g2, "dormant") || !_g2.dormant) continue;
            array_push(_out, { source: _pools[_p].s, idx: _i, item: _g2, label: _g2.name,
                rarity: variable_struct_exists(_g2, "rarity") ? _g2.rarity : 4,
                value: variable_struct_exists(_g2, "gold_value") ? _g2.gold_value : 0 });
        }
    }
    return _out;
}

function drop_equipment(rarity_weights, do_discover = true, curse_tiers = 0) {
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

    // LEGENDARY IS NEVER A BUMP (M 08-16: "legendaries still drop too fast
    // because of loot tier + augments... too easy to FORCE them"): every
    // post-roll bump below - Prospector, curse loot tiers, Gambler's Icon -
    // caps at EPIC. A legendary comes ONLY from the native weight roll (or the
    // authored boss/forge paths). Remember whether the roll itself was
    // legendary so the bumps can't lower it either.
    var _native_leg = (_rarity >= 4);
    // Prospector trait: loot rolls one quality tier better (capped at Epic).
    // POTENCY V2: +5%/rank chance the bump is TWO tiers; TRANSCEND "Motherlode":
    // combat loot can never roll common.
    // (legendary_owned lives just below drop_equipment's caller chain - see the
    // dupe-protection reroll in the legendary branch.)
    if (trait_active("Prospector") && _rarity < 3) {
        _rarity++;
        if (_rarity < 3 && irandom(99) < 5 * trait_potency_r14("Prospector")) _rarity++;
    }
    if (trait_transcended("Prospector") && _rarity == 0) _rarity = 1;

    // Curse loot tiers: a LITERAL rarity bump, matching the "Loot rarity +N tiers"
    // reward text (same idiom as Prospector above). This used to be added to the
    // awakening fed into drop_weights, which was wrong twice: at A0 the lerp starts
    // common-heavy so +2 left 65% commons (read as broken), and at A5 the
    // clamp(asc,0,5) in drop_weights ate the bonus entirely - Doom and Withered
    // became pure-downside curses with literally no reward at the tier they're
    // gated to. Post-roll bump is worth the same at every awakening. (07-20)
    // 08-16: capped at Epic - see _native_leg above.
    if (curse_tiers > 0 && _rarity < 3) _rarity = min(3, _rarity + curse_tiers);
    if (_native_leg) _rarity = 4;

    var _gate_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;

    // LEGENDARY AWAKENING GATE (M 07-28: TWO legendaries dropped on an A0 first
    // run off a +1 curse shrine - "+1 should mean RAREs at A0, not legendaries").
    // Below Awakening 2 nothing may roll OR be bumped to legendary: the ceiling
    // applies AFTER the native roll, Prospector and curse bumps, so those still
    // pay out - capped at Epic. The perm-level equip gate stays as the second
    // fence for A2+ lucky finds.
    if (_gate_asc < 2) _rarity = min(_rarity, 3);

    // Achievement hook (08-05 wiring): the first legendary DROP, dormant or true
    // (fires past the awakening gate above, so it is a real legendary roll).
    if (_rarity == 4) ach_unlock("ACH_FIRST_LEGEND");

    // Legendaries - return clone with pre-set affixes and unique fields
    if (_rarity == 4 && variable_global_exists("loot_table_legendary")
        && array_length(global.loot_table_legendary) > 0) {
        var _leg_tbl = global.loot_table_legendary;
        var _leg_pick = _leg_tbl[irandom(array_length(_leg_tbl) - 1)];
        // DUPE PROTECTION (M 07-27/28: "same Crown of the Hollow King 3x" -
        // curse loot-tier bumps funnel rolls into a small table): if a copy is
        // already owned ANYWHERE (worn / stash / carried), reroll once. Repeats
        // stay possible (two rolls can still collide) but stop being the norm.
        if (array_length(_leg_tbl) > 1 && legendary_owned(item_base_name(_leg_pick))) {
            _leg_pick = _leg_tbl[irandom(array_length(_leg_tbl) - 1)];
        }
        var _leg_item = clone_item(_leg_pick);
        var _leg_ec = item_empower_context();
        item_empower(_leg_item, _leg_ec.asc, _leg_ec.df);   // A6+/Descent scaling
        // Tempering + dormancy (08-04): every drop rolls quality, and generic
        // stat-legendaries wake up DORMANT - the named uniques stay true finds.
        item_quality_stamp(_leg_item, 50, 72);   // 08-18 quality nerf
        if (!variable_struct_exists(_leg_item, "unique_effect") || _leg_item.unique_effect == "") {
            _leg_item.dormant = true;
            _leg_item.name    = "Dormant " + _leg_item.name;
            _leg_item.lore    = "It fell asleep the day its first bearer died. Something legendary still turns over inside it - Maren would know how to wake it.";
            tutorial_try_show("dormant_leg");   // onboarding: first dormant find (M 08-04)
        }
        if (do_discover) discover_item(item_base_name(_leg_item), 4);
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

    // Inverse-lerp affix bias: the hotter this weapon's damage roll landed, the
    // leaner its rolled affixes (0 for non-weapons). Creation-time only.
    var _bias_t = weapon_damage_bias_t(_item);

    if (_affix_count > 0) {
        var _affixes = roll_affixes(_eff_rarity, _affix_count, item_affix_exclusions(_item), _item.slot, _item.base_name, _bias_t);
        apply_affixes_to_item(_item, _affixes);
    }

    // Elemental affix: weapons may also carry one (small elemental damage + a setup
    // status), independent of the stat affixes (SYSTEMS_WEAPON_ROLES.md §C). Skip if
    // the base already carries one (hand-authored elemental weapons) so it isn't
    // doubled up or overwritten.
    var _base_has_elem = (variable_struct_exists(_item, "elem_affix") && _item.elem_affix != undefined);
    if ((_item.slot == "weapon" || _item.slot == "ranged_weapon") && !_base_has_elem) {
        apply_elemental_affix_to_item(_item, roll_elemental_affix(_eff_rarity, _bias_t));
    }

    // Sockets follow the FINAL rarity (epic was bumped from a rare base above).
    _item.socket_count = rune_sockets_for_rarity(_item.rarity);

    // A6+/Descent item-level scaling (SYSTEMS_ENDLESS.md) - past effective
    // Awakening 5, numeric power compounds and Descent drops get depth-tagged.
    var _emp_ec = item_empower_context();
    item_empower(_item, _emp_ec.asc, _emp_ec.df);

    // Tempering (08-04): drops arrive rough - Maren finishes them.
    item_quality_stamp(_item, 45, 70);   // 08-18 (M): drops land ~30% weaker; Dorn's temper still climbs to 100

    if (do_discover) discover_item(item_base_name(_item), _item.rarity);
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
// Gamepad: pad_nav (scr_input) folds dpad + left stick in with the same
// hold-repeat cadence, so controllers inherit every menu's QoL nav for free.
function nav_up()    { var _a = key_nav(vk_up);    var _b = key_nav(ord("W")); var _c = pad_nav(gp_padu); if (_a || _b || _c) nav_tick(); return _a || _b || _c; }
function nav_down()  { var _a = key_nav(vk_down);  var _b = key_nav(ord("S")); var _c = pad_nav(gp_padd); if (_a || _b || _c) nav_tick(); return _a || _b || _c; }
function nav_left()  { var _a = key_nav(vk_left);  var _b = key_nav(ord("A")); var _c = pad_nav(gp_padl); if (_a || _b || _c) nav_tick(); return _a || _b || _c; }
function nav_right() { var _a = key_nav(vk_right); var _b = key_nav(ord("D")); var _c = pad_nav(gp_padr); if (_a || _b || _c) nav_tick(); return _a || _b || _c; }

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
// TWO-STEP (M 07-08 redesign): Enter ARMS a choice - the chosen unit moves into
// the DISCARDING panel on the right of the popup with an explicit "ONE of N"
// line - and a second Enter commits. Moving the cursor or Esc disarms without
// losing anything. Stacks were the fear: picking "Adrenaline Vial x4" never
// looked like it discarded one, so now the panel says exactly what is lost.
function consumable_overflow_step() {
    if (!consumable_overflow_pending()) return false;
    if (!variable_global_exists("consumable_overflow_cursor")) global.consumable_overflow_cursor = 0;
    if (!variable_global_exists("consumable_overflow_armed"))  global.consumable_overflow_armed  = -1;

    var _groups  = consumables_grouped();
    var _options = array_length(_groups) + 1;   // +1 = "Leave it behind"
    var _cur = global.consumable_overflow_cursor;

    if (nav_up())   { _cur = wrap_index(_cur - 1, _options); global.consumable_overflow_armed = -1; }
    if (nav_down()) { _cur = wrap_index(_cur + 1, _options); global.consumable_overflow_armed = -1; }
    global.consumable_overflow_cursor = _cur;

    if (input_cancel() || input_back()) global.consumable_overflow_armed = -1;

    if (input_confirm() || input_confirm_alt()) {
        if (global.consumable_overflow_armed != _cur) {
            global.consumable_overflow_armed = _cur;   // arm - the DISCARDING panel previews the loss
        } else {
            var _new = global.consumable_overflow[0];
            if (_cur < array_length(_groups)) {
                // Discard ONE of the chosen held consumable, take the new one.
                var _idx = _groups[_cur].first_index;
                array_delete(global.consumable_inventory, _idx, 1);
                array_push(global.consumable_inventory, _new);
            }
            // else: "Leave it behind" - the new item is simply dropped.
            array_delete(global.consumable_overflow, 0, 1);
            global.consumable_overflow_cursor = 0;
            global.consumable_overflow_armed  = -1;
        }
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
function item_migrate_weapon_fields(it, force_reroll = false) {
    if (it == undefined || !is_struct(it)) return;
    if (!variable_struct_exists(it, "slot")) return;
    if (it.slot == "weapon" || it.slot == "ranged_weapon") {
        var _rar = variable_struct_exists(it, "rarity") ? it.rarity : 0;
        var _missing = (!variable_struct_exists(it, "weapon_damage") || it.weapon_damage == 0);
        // force_reroll = the v2 save migration: pre-v2 weapons carry the old FIXED
        // flat damage - re-roll once into the rarity range. Hand-tuned budgets
        // (2H weapons, legendaries) keep their authored value.
        var _hand_tuned = (variable_struct_exists(it, "two_handed") && it.two_handed) || (_rar >= 4);
        if (_missing || (force_reroll && !_hand_tuned)) {
            it.weapon_damage = weapon_base_damage(_rar);
        }
        // Caster ranged weapons saved before wpn_school existed: roll their school.
        if (weapon_is_caster_ranged(it)
            && (!variable_struct_exists(it, "wpn_school") || it.wpn_school == "")) {
            it.wpn_school = weapon_roll_school();
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

// =============================================================================
// ARMOR WEIGHT CLASSES (M-approved 07-31, SYSTEMS_ARMOR_CLASSES.md).
// Class is DERIVED at read time (never stored - no save migration): base_name
// keywords first, primary-stat fallback. Baseline Armor / El Resist per slot x
// class x rarity, folded into apply_equipment_stats below.
// =============================================================================

// item_weight_class(item) -> "heavy" / "medium" / "cloth" / "" (not body armor).
function item_weight_class(item) {
    if (!is_struct(item)) return "";
    var _slot = variable_struct_exists(item, "slot") ? item.slot : "";
    if (_slot != "chest" && _slot != "helm" && _slot != "gloves" && _slot != "boots") return "";
    var _n = string_lower(variable_struct_exists(item, "base_name") ? item.base_name
            : (variable_struct_exists(item, "name") ? item.name : ""));
    var _heavy  = ["plate", "mail", "visor", "bulwark", "iron", "tower", "greaves"];
    var _medium = ["leather", "hide", "scale", "brigand", "chain"];
    var _cloth  = ["robe", "cloth", "hood", "wrap", "silk", "veil", "tatter"];
    for (var _i = 0; _i < array_length(_heavy);  _i++) if (string_pos(_heavy[_i],  _n) > 0) return "heavy";
    for (var _i = 0; _i < array_length(_medium); _i++) if (string_pos(_medium[_i], _n) > 0) return "medium";
    for (var _i = 0; _i < array_length(_cloth);  _i++) if (string_pos(_cloth[_i],  _n) > 0) return "cloth";
    var _sn = variable_struct_exists(item, "stat_name") ? item.stat_name : "";
    if (_sn == "STR" || _sn == "CON") return "heavy";
    if (_sn == "DEX")                 return "medium";
    return "cloth";   // INT / WIS / CHA / none
}

// item_base_armor(item) - baseline flat Armor from the weight-class table.
// Shields get their own baseline (stacks with any of-Warding affix).
function item_base_armor(item) {
    if (!is_struct(item)) return 0;
    var _rar = clamp(variable_struct_exists(item, "rarity") ? item.rarity : 0, 0, 4);
    if (item_is_shield_offhand(item)) {
        return [1, 2, 2, 3, 4][_rar];
    }
    var _wc = item_weight_class(item);
    if (_wc == "") return 0;
    var _slot = item.slot;
    if (_wc == "heavy") {
        if (_slot == "chest") return [1, 2, 2, 3, 4][_rar];
        if (_slot == "helm")  return [1, 1, 2, 2, 3][_rar];
        return [0, 1, 1, 1, 2][_rar];               // gloves / boots
    }
    if (_wc == "medium") {
        if (_slot == "chest") return [0, 1, 1, 2, 2][_rar];
        if (_slot == "helm")  return [0, 1, 1, 1, 2][_rar];
        return [0, 0, 1, 1, 1][_rar];               // gloves / boots
    }
    return 0;                                        // cloth pays with skin
}

// item_base_el_resist(item) - cloth compensation (M-approved): cloth chest/helm
// ward spells instead of blades. Uses the existing el_resist channel.
function item_base_el_resist(item) {
    if (!is_struct(item)) return 0;
    if (item_weight_class(item) != "cloth") return 0;
    var _slot = item.slot;
    if (_slot != "chest" && _slot != "helm") return 0;
    var _rar = clamp(variable_struct_exists(item, "rarity") ? item.rarity : 0, 0, 4);
    return [1, 1, 2, 2, 3][_rar];
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

// item_perm_level_req(item) - the PERMANENT-level gate an item carries (0 =
// none). Shown on the item card like a stat requirement (M 08-15: the gate
// was invisible until you TRIED to equip).
function item_perm_level_req(item) {
    if (is_struct(item) && variable_struct_exists(item, "rarity") && item.rarity >= 4) {
        return LEGENDARY_EQUIP_PERM_LEVEL;
    }
    return 0;
}

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

// Re-validate every equipped item against the stats you actually have NOW and
// auto-unequip failures to the stash. Mid-run stat gains satisfy the equip gate
// while they last, but back at camp they're gone - keeping the item equipped
// would let the gate be gamed permanently (M 07-08). Run at hub entry, where
// run_stat_bonuses are already cleared. Returns the unequipped items' names
// (the hub shows the "your temporary power has left you" notice when non-empty).
function equip_validate_stat_reqs() {
    var _dropped = [];
    if (!variable_global_exists("inventory")) return _dropped;
    for (var _i = 0; _i < array_length(global.inventory); _i++) {
        var _it = global.inventory[_i];
        if (_it == undefined) continue;
        if (equip_stat_block_reason(_it) != "") {
            global.inventory[_i] = undefined;
            if (!variable_global_exists("equipment_stash")) global.equipment_stash = [];
            array_push(global.equipment_stash, _it);
            array_push(_dropped, _it.name);
        }
    }
    return _dropped;
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
    var _bonus = { armor: 0, el_resist: 0, bonus_max_hp: 0, crit_flat: 0, crit_spell: 0, crit_phys: 0, dodge_flat: 0, gold_find: 0,
                   melee_dmg_bonus: 0, ranged_dmg_bonus: 0, ranged_school: "",
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

        // Tempering + dormancy (08-04): the item's POSITIVE contributions scale
        // by quality% (x0.55 more while dormant); stored rolls stay untouched.
        var _pm = item_power_mult(_it);

        // FINISH (08-08): quality's own flat contribution, so tempering always
        // moves a number even on a +1 item. See item_finish_hp().
        _bonus.bonus_max_hp += item_finish_hp(_it);

        // Reach-gated weapon damage routes by the item's own slot, not its stat.
        var _wd = variable_struct_exists(_it, "weapon_damage") ? _it.weapon_damage : 0;
        _wd = item_scaled_val(_wd, _pm);
        if (_wd != 0) {
            if (_it.slot == "weapon")             _bonus.melee_dmg_bonus  += _wd;
            else if (_it.slot == "ranged_weapon") {
                _bonus.ranged_dmg_bonus += _wd;
                // Caster ranged weapon: its flat damage is school-typed (wands
                // never deal phys) - combat reads this to resolve it as elemental.
                if (variable_struct_exists(_it, "wpn_school") && _it.wpn_school != "") {
                    _bonus.ranged_school = _it.wpn_school;
                }
            }
        }

        // Reach-gated elemental affix (one melee + one ranged weapon at most).
        var _ea = variable_struct_exists(_it, "elem_affix") ? _it.elem_affix : undefined;
        if (_ea != undefined) {
            if (_it.slot == "weapon")             _bonus.melee_elem  = _ea;
            else if (_it.slot == "ranged_weapon") _bonus.ranged_elem = _ea;
        }

        _equip_apply_stat(stats_struct, _bonus, _it.stat_name, item_scaled_val(_it.stat_value, _pm));

        // Apply affixes stored on the item (from drop_equipment or legendary fixed affixes)
        if (variable_struct_exists(_it, "affixes")) {
            for (var _a = 0; _a < array_length(_it.affixes); _a++) {
                var _af = _it.affixes[_a];
                _equip_apply_stat(stats_struct, _bonus, _af.stat_name, item_scaled_val(_af.stat_value, _pm));
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

        // Weight-class baseline Armor / El Resist (M-approved 07-31,
        // SYSTEMS_ARMOR_CLASSES.md) - derived from the item, on top of affixes.
        _bonus.armor     += item_base_armor(_it);
        _bonus.el_resist += item_base_el_resist(_it);
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
    else if (stat_name == "crit_spell")  { bonus.crit_spell  += stat_value; }   // spell-only crit (07-31)
    else if (stat_name == "crit_phys")   { bonus.crit_phys   += stat_value; }   // phys-only crit (07-31)
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
// consumable gets weight 3. The big-AP Adrenaline Vial also drops to weight 1
// (M 07-08: vials were piling up unused) while the humble Energy Tonic is
// FAVORED at weight 4. Used by DROP sources only - uniform roll_consumable
// is kept for shop stock where the player chooses what to buy.
// ---------------------------------------------------------------------------
function roll_consumable_weighted(pool) {
    var _n = array_length(pool);
    if (_n == 0) return undefined;
    var _weights = array_create(_n, 0);
    var _total   = 0;
    for (var _i = 0; _i < _n; _i++) {
        var _et = variable_struct_exists(pool[_i], "effect_type") ? pool[_i].effect_type : "";
        var _ev = variable_struct_exists(pool[_i], "effect_value") ? pool[_i].effect_value : 0;
        if (_et == "heal" || _et == "heal_dot")   _weights[_i] = 1;
        else if (_et == "energy" && _ev >= 3)     _weights[_i] = 1;   // Adrenaline Vial: rare
        else if (_et == "energy")                 _weights[_i] = 4;   // Energy Tonic: common
        else                                      _weights[_i] = 3;
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
// loot_room_seed(slot, salt)
// Deterministic RNG seed for a room's reward rolls (IRONMAN resume, M 07-28:
// quitting at the loot screen must not re-roll drops on the re-fight). Keyed
// by run + floor + room + the enemy's spawn slot, so kill ORDER can't reshuffle
// the outcomes either. Callers save random_get_seed() and restore it after.
// ---------------------------------------------------------------------------
function loot_room_seed(_slot, _salt) {
    var _rs = variable_global_exists("run_seed")           ? global.run_seed           : 1;
    var _fl = variable_global_exists("current_floor")      ? global.current_floor      : 1;
    var _ri = variable_global_exists("current_room_index") ? global.current_room_index : 0;
    return (_rs * 7919 + _fl * 613 + _ri * 53 + _slot * 17 + _salt) mod 2147483647;
}

// ---------------------------------------------------------------------------
// handle_enemy_drops(enemy_type)
// Rolls drops for a defeated enemy, pushes results into global inventories,
// and returns a log string describing what dropped ("" if nothing dropped).
// Callers that care about quit-scum determinism seed the RNG around this call
// via loot_room_seed (both combat kill paths do).
// ---------------------------------------------------------------------------
function handle_enemy_drops(enemy_type) {
    if (!variable_global_exists("run_items_found"))      global.run_items_found      = [];
    if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];

    if (!variable_global_exists("carried_items")) global.carried_items = [];
    if (!variable_global_exists("rune_inventory")) global.rune_inventory = [];
    if (!variable_global_exists("rune_dust"))      global.rune_dust      = 0;

    // Drop rarity scales with the awakening tier of the current run. Curse
    // loot-tiers are NOT folded in here any more - they're a post-roll rarity bump
    // passed to drop_equipment via curse_loot_tier_bonus_for(source). Keeping
    // them out also stops curses from silently shrinking _cons_chance below.
    var _drop_asc   = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
    // Faerie's Tear potion + active Boon pet: extra equipment-drop chance (percentage points).
    var _loot_pot = potion_loot_bonus_pts() + pet_active_boon_loot_pts() + pet_active_lck_loot_pts() + pet_active_splash_loot_pts() + pet_active_egg_bonus("loot");
    // Lucky Find trait (07-08 identity split): +5 loot-find points, same currency
    // as the pet/potion loot bonuses (added to the equipment drop chances below).
    if (trait_active("Lucky Find")) _loot_pot += 5;

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
    // Dungeon crafting REAGENTS (M-locked 08-17): the current dungeon's reagent -
    // elites 40% x1, bosses always x2. Fuel for Dorn's craft wizard.
    var _rg_n = 0;
    if (enemy_type == "elite" && irandom(99) < 40) _rg_n = 1;
    else if (enemy_type == "boss") _rg_n = 2;
    if (_rg_n > 0) {
        var _rg = reagent_for_current_dungeon();
        reagent_add(_rg.id, _rg_n);
        _rune_suffix += "  +  " + _rg.name + ((_rg_n > 1) ? (" x" + string(_rg_n)) : "") + " [Reagent]";
    }
    // VALUABLES (M 08-17): sell-only trinkets. Standard 3% / elite 8% / boss 15%.
    var _vl_ch = (enemy_type == "boss") ? 15 : ((enemy_type == "elite") ? 8 : 3);
    if (irandom(99) < _vl_ch) {
        var _vl = valuable_roll(enemy_type);
        array_push(global.run_items_found, _vl);
        consumable_award(_vl);
        _rune_suffix += "  +  " + _vl.name + " [Valuable]";
    }

    if (enemy_type == "standard") {
        // Consumable drop chance tapers off with awakening (10% - 1%/tier, min 5%)
        // so higher tiers lean on boons/shops instead of drowning in heals.
        var _cons_chance = max(4, 7 - _drop_asc);   // 08-18 (M): fewer potions (was 10, min 5)
        // (Lucky Find reworked, audit §6: now a 20% chance consumables aren't consumed
        //  on use - the old +5% drop bonus here is gone.)
        if (!curse_blocks_consumables() && irandom(99) < _cons_chance) {   // Famine curse: no consumable drops
            var _c = roll_consumable_weighted(global.consumables_standard);
            array_push(global.run_items_found, _c);
            // No "(PACK FULL)" here (M 08-15: the suffix flashed at the victory
            // moment and read as a popup interrupting itself) - the discard
            // modal at the END of the victory chain is the one communication.
            consumable_award(_c);
            return _c.name + " [Consumable]" + _rune_suffix;
        }
        // 4% equipment drop (+ Faerie's Tear bonus) - rarity weights scale with awakening.
        if (irandom(99) < 2 + _loot_pot) {   // 08-18 (M): standard mobs 4% -> 2% - elites/bosses are the reliable source
            var _gt = boon_gambler_tier_bonus();   // Gambler's Icon: fast fights roll +1 tier
            var _item = drop_equipment(drop_weights("standard", _drop_asc), true, curse_loot_tier_bonus_for("standard") + _gt);
            array_push(global.run_items_found, _item);
            array_push(global.carried_items, _item);
            discover_item(item_base_name(_item), _item.rarity);
            return _item.name + " [" + item_rarity_name(_item.rarity) + "]"
                + ((_gt > 0) ? "  (GAMBLER'S ICON!)" : "") + _rune_suffix;
        }

    } else if (enemy_type == "elite") {
        // M 07-29: elites ALWAYS pay equipment ("over nerfed... should have
        // some guaranteed loot even if just uncommon for lower awakenings").
        // The old either/or paid a lone potion 40-60% of the time and NOTHING
        // ~1 fight in 3. Now mirrors the boss branch: guaranteed item with an
        // UNCOMMON floor (the common weight pours up a tier), and the
        // consumable is a BONUS rider at the same 07-08-tuned taper - the
        // potion economy is unchanged, only the guarantee is new.
        var _ew = drop_weights("elite", _drop_asc);
        _ew[1] += _ew[0]; _ew[0] = 0;   // never common (M: "even if just uncommon")
        var _gt = boon_gambler_tier_bonus();   // Gambler's Icon: fast fights roll +1 tier
        var _item = drop_equipment(_ew, true, curse_loot_tier_bonus_for("elite") + _gt);
        array_push(global.run_items_found, _item);
        array_push(global.carried_items, _item);
        discover_item(item_base_name(_item), _item.rarity);
        var _e_result = _item.name + " [" + item_rarity_name(_item.rarity) + "]"
            + ((_gt > 0) ? "  (GAMBLER'S ICON!)" : "");
        // Bonus consumable rider (60% - 4%/tier, min 40%; Famine curse blocks).
        // Pool mix as before: at low tiers most rolls downgrade to the standard
        // pool (A0: 60% -> A5: 0%) so elite-tier potions are grown into.
        var _elite_cons_chance = max(30, 45 - _drop_asc * 3);   // 08-18: 45%->30% (was 60->40)
        if (!curse_blocks_consumables() && irandom(99) < _elite_cons_chance) {
            var _elite_std_mix = max(0, 60 - _drop_asc * 12);
            var _elite_pool = (irandom(99) < _elite_std_mix) ? global.consumables_standard : global.consumables_elite;
            var _c = roll_consumable_weighted(_elite_pool);
            array_push(global.run_items_found, _c);
            consumable_award(_c);   // pack-full flash removed (M 08-15) - the end-of-chain modal communicates it
            _e_result += " + " + _c.name;
        }
        return _e_result + _rune_suffix;

    } else if (enemy_type == "boss") {
        // Guaranteed equipment - rarity weights scale with awakening AND floor
        // (boss_drop_weights: F2 = uncommon+, F3 = rare+ hard floors).
        var _boss_fl = variable_global_exists("current_floor") ? global.current_floor : 1;
        var _gt = boon_gambler_tier_bonus();   // Gambler's Icon: fast fights roll +1 tier
        // THE WEIGHT OF IRONWAKE (Depth Warden, 08-13): the floor-25-cadence
        // Warden guarantees a Depthforged LEGENDARY (DESIGN §4) - the weights
        // collapse to legendary-only and the Descent's item_empower path tags it.
        var _boss_w = boss_drop_weights(_drop_asc, _boss_fl);
        if (variable_global_exists("warden_leg_due") && global.warden_leg_due) {
            global.warden_leg_due = false;
            _boss_w = [0, 0, 0, 0, 100];
        }
        var _item = drop_equipment(_boss_w, true, curse_loot_tier_bonus_for("boss") + _gt);
        array_push(global.run_items_found, _item);
        array_push(global.carried_items, _item);
        discover_item(item_base_name(_item), _item.rarity);
        var _result = _item.name + " [" + item_rarity_name(_item.rarity) + "]"
            + ((_gt > 0) ? "  (GAMBLER'S ICON!)" : "");
        // 50% bonus consumable (suppressed by the Famine curse). Same awakening
        // pool mix as elites, gentler (bosses stay a bit premium): A0 40% -> A5 0%.
        if (!curse_blocks_consumables() && irandom(99) < 50) {
            var _boss_std_mix = max(0, 40 - _drop_asc * 8);
            var _boss_pool = (irandom(99) < _boss_std_mix) ? global.consumables_standard : global.consumables_elite;
            var _c = roll_consumable_weighted(_boss_pool);
            array_push(global.run_items_found, _c);
            consumable_award(_c);   // pack-full flash removed (M 08-15) - the end-of-chain modal communicates it
            _result += " + " + _c.name;
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
        elem_dmg_bonus:     floor(INT * 0.3),   // 08-18 M: 0.4 -> 0.3 (A0 Arcanist over-tuned)
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
        // Vitality follows the 2x rule (#21, M-approved 07-08): exactly double
        // Fortitude's HP at every tier (CON = 3 HP each). Pure HP pays 2x because
        // Fortitude's CON also counts for armor/shield stat-gates and event checks.
        // (History: 15/35/70 -> stopgap 8/18/35 -> 6/12/24.)
        // Socketed runes read the catalog live, so existing saves adjust on load.
        { id:"vitality",   name:"Vitality",   domain:"gear",   stat_name:"bonus_max_hp", vals:[4,6,10],  blurb:"+# Max HP" },
        { id:"might",      name:"Might",      domain:"gear",   stat_name:"STR",          vals:[1,2,4],    blurb:"+# STR" },
        { id:"finesse",    name:"Finesse",    domain:"gear",   stat_name:"DEX",          vals:[1,2,4],    blurb:"+# DEX" },
        { id:"fortitude",  name:"Fortitude",  domain:"gear",   stat_name:"CON",          vals:[1,2,4],    blurb:"+# CON" },
        { id:"insight",    name:"Insight",    domain:"gear",   stat_name:"INT",          vals:[1,2,4],    blurb:"+# INT" },
        { id:"keen",       name:"Keen",       domain:"gear",   stat_name:"crit_phys",    vals:[1,2,4],    blurb:"+#% Physical crit chance" },   // 08-18 (M): phys-only, was all-crit 3/6/12
        { id:"warding",    name:"Warding",    domain:"gear",   stat_name:"el_resist",    vals:[5,10,18],  blurb:"+#% Elemental resist" },
        { id:"evasion",    name:"Evasion",    domain:"gear",   stat_name:"dodge_flat",   vals:[2,3,5],    blurb:"+# Dodge" },
        // ---- ASPECT RUNES (combat effects wired in Phase 2) ----
        // Per-school damage runes (M-locked 08-15: "Ember should be fire, not
        // all elemental"): one rune per element school at Hemorrhage's line,
        // keyed off ability_school(). Saved runes read the catalog live, so
        // pre-rework Ember instances become fire-only on load. AVATAR is the
        // deliberately-weak omni that covers every school at roughly half a
        // single-school rune's value. RUNE NERF (M 08-18: "instantly borderline
        // game breaking"): school 12/20/34 -> 3/6/9, Avatar 6/10/17 -> 2/4/6,
        // Serration 10/18/30 -> 4/6/10, Bulwark 2/4/7 -> 1/2/4, Leech 20/35/60
        // -> 10/20/30, Surge 4/8/14 -> 1/2/4, Keen 3/6/12 all-crit -> 1/2/4 PHYS
        // crit, Evasion 2/4/8 -> 2/3/5, Vitality 6/12/24 -> 4/6/10, Bastion 8 -> 15.
        // Saved runes read the catalog live, so every socketed rune retunes on load.
        { id:"ember",      name:"Ember",      domain:"aspect", aspect:"school_dmg", school:"fire",   vals:[3,6,9], blurb:"+#% Fire damage" },
        { id:"rime",       name:"Rime",       domain:"aspect", aspect:"school_dmg", school:"frost",  vals:[3,6,9], blurb:"+#% Frost damage" },
        { id:"tempest",    name:"Tempest",    domain:"aspect", aspect:"school_dmg", school:"shock",  vals:[3,6,9], blurb:"+#% Shock damage" },
        { id:"aether",     name:"Aether",     domain:"aspect", aspect:"school_dmg", school:"arcane", vals:[3,6,9], blurb:"+#% Arcane damage" },
        { id:"hemorrhage", name:"Hemorrhage", domain:"aspect", aspect:"school_dmg", school:"blood",  vals:[3,6,9], blurb:"+#% Blood damage" },
        { id:"abyss",      name:"Abyss",      domain:"aspect", aspect:"school_dmg", school:"void",   vals:[3,6,9], blurb:"+#% Void damage" },
        { id:"umbra",      name:"Umbra",      domain:"aspect", aspect:"school_dmg", school:"shadow", vals:[3,6,9], blurb:"+#% Shadow damage" },
        { id:"venom",      name:"Venom",      domain:"aspect", aspect:"school_dmg", school:"poison", vals:[3,6,9], blurb:"+#% Poison damage" },
        { id:"avatar",     name:"Avatar",     domain:"aspect", aspect:"school_dmg", school:"any",    vals:[2,4,6],  blurb:"+#% damage in EVERY element school" },
        { id:"serration",  name:"Serration",  domain:"aspect", aspect:"attack_dmg",                  vals:[4,6,10], blurb:"+#% Physical attack damage" },
        // Accuracy pair NERFED + SPLIT (M-locked 08-15: "nothing will ever miss
        // again with these over stacked" - was 8/14/22 covering all ranged).
        { id:"hunter",     name:"Hunter",     domain:"aspect", aspect:"ranged_acc",           vals:[2,3,4],    blurb:"+#% Ranged ATTACK accuracy (rune total caps at +12%)" },
        { id:"seer",       name:"Seer",       domain:"aspect", aspect:"spell_acc",            vals:[2,3,4],    blurb:"+#% Spell accuracy (rune total caps at +12%)" },
        { id:"bulwark",    name:"Bulwark",    domain:"aspect", aspect:"melee_shield",         vals:[1,2,4],    blurb:"Each melee attack HIT grants # shield (multi-hit strikes grant it per hit)" },
        { id:"leech",      name:"Leech",      domain:"aspect", aspect:"drain_heal",           vals:[10,20,30], blurb:"Drain abilities heal +#% more" },
        { id:"surge",      name:"Surge",      domain:"aspect", aspect:"spell_crit",           vals:[1,2,4],   blurb:"+#% Spell crit chance" },
        { id:"anchor",     name:"Anchor",     domain:"aspect", aspect:"melee_weaken",         vals:[1,1,2],    blurb:"Melee attacks Weaken (# turns)" },
        { id:"quickcast",  name:"Quickcast",  domain:"aspect", aspect:"first_spell_ap", tier3_only:true, vals:[0,0,1], blurb:"First spell each combat costs -1 AP" },
        // Echo blurb fixed 07-09 (C6): the MECHANIC was already the 50% damage echo -
        // only this text still described the old rider-duration behavior.
        { id:"echo",       name:"Echo",       domain:"aspect", aspect:"first_aoe_echo", tier3_only:true, vals:[0,0,1], blurb:"First AoE each combat ECHOES - every target takes 50% again" },
        // NEW tier-3 flagships (C6, M-approved 07-09) - progression-gated chase
        // recipes at Maren (flagship_unlock_text).
        { id:"cascade",    name:"Cascade",    domain:"aspect", aspect:"kill_refund",  tier3_only:true, vals:[0,0,1], blurb:"Your killing blows refund 1 Soul / Blood / Prep" },
        { id:"bastion",    name:"Bastion",    domain:"aspect", aspect:"start_shield", tier3_only:true, vals:[0,0,15], blurb:"Start each combat with # shield" },   // 08-18 (M): 8 read thin for a Tier III
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
    var _t = max(1, rune.tier);
    // Runic Affinity V2 (07-29): while the boon holds, socketed runes act 1 tier
    // higher, capped at V - runes already at V+ (endless combining) are untouched.
    if (_t < 5 && boon_active("runic")) _t += 1;
    if (_t <= 3) return _def.vals[_t - 1];
    // Endless tiers (IV+, post-win combining): compound +40% per tier past III
    // on the authored tier-III value; the max() guarantees at least +1 per tier
    // so small bases (+1/+2 runes) can't stall on rounding.
    return max(_def.vals[2] + (_t - 3), round(_def.vals[2] * power(1.4, _t - 3)));
}

// Build a rune instance struct from an id + tier. No upper clamp - tiers past
// III exist once endless combining unlocks (rune_combine_tier_cap).
function rune_make(id, tier) {
    var _def = rune_get(id);
    return {
        id:     id,
        name:   (_def != undefined) ? _def.name   : id,
        domain: (_def != undefined) ? _def.domain : "gear",
        tier:   max(1, tier),
    };
}

// Tier number -> roman numeral for display. Generic (IV, V, ... XIII, ...)
// because endless combining makes arbitrary tiers real.
function rune_tier_roman(t) {
    var _n = floor(t);
    if (_n <= 0 || _n > 3999) return string(t);
    var _vals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    var _syms = ["M","CM","D","CD","C","XC","L","XL","X","IX","V","IV","I"];
    var _out  = "";
    for (var _i = 0; _i < array_length(_vals); _i++) {
        while (_n >= _vals[_i]) { _out += _syms[_i]; _n -= _vals[_i]; }
    }
    return _out;
}

// Full human-readable line, e.g. "Vitality II - +12 Max HP".
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

// Rune stat-effect only, e.g. "+12 Max HP" (the "stat" line, like an item's stat str).
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
        // Per-school runes wear their school's canonical color (08-15 rework).
        case "rime":                          return school_base_color("frost");
        case "tempest":                       return school_base_color("shock");
        case "aether":                        return school_base_color("arcane");
        case "abyss":                         return school_base_color("void");
        case "umbra":                         return school_base_color("shadow");
        case "venom":                         return school_base_color("poison");
        case "avatar":                        return make_color_rgb(232, 228, 245);  // prismatic white
        case "vitality":   case "fortitude":  case "bulwark": return make_color_rgb(220, 160, 70); // amber
        case "finesse":    case "hunter":     case "evasion": return make_color_rgb(90, 205, 110); // green
        case "keen":                          return make_color_rgb(240, 215,  90);  // gold
        case "warding":                       return make_color_rgb(70, 200, 190);   // teal
        case "insight":    case "surge":      case "quickcast": case "echo":
        case "seer":                          return make_color_rgb(110, 170, 240); // arcane blue
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
    // Elemental dungeons lean toward their OWN school's rune (Ember in the
    // scorched depths, Abyss in the ashen vault...) at double weight, plus
    // Warding and the omni Avatar (per-school runes, M-locked 08-15).
    var _bsch = dungeon_bias_school();
    if (_bsch != "" && irandom(99) < 35) {
        var _themed = ["warding", "avatar"];
        for (var _j = 0; _j < array_length(_cat); _j++) {
            var _td = _cat[_j];
            if (variable_struct_exists(_td, "school") && _td.school == _bsch) {
                array_push(_themed, _td.id);
                array_push(_themed, _td.id);
                break;
            }
        }
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

// Sum of socketed per-school rune % for one school: the exact-school runes
// (Ember=fire, Rime=frost, ...) plus Avatar's every-school omni line.
function rune_aspect_school_value(school) {
    if (school == "" || !variable_global_exists("aspect_runes")) return 0;
    var _t = 0;
    for (var _i = 0; _i < array_length(global.aspect_runes); _i++) {
        var _rn  = global.aspect_runes[_i];
        var _def = rune_get(_rn.id);
        if (_def == undefined || _def.domain != "aspect") continue;
        if (_def.aspect != "school_dmg") continue;
        if (_def.school != "any" && _def.school != school) continue;
        _t += rune_value(_rn);
    }
    return _t;
}

// Outgoing-damage % bonus (fraction, e.g. 0.10) for an ability:
//   Per-school runes key off ability_school() (untagged dtype-1 abilities read
//   as arcane, dtype-2 void, dtype-3 blood - see ability_school), so Ember
//   boosts ONLY fire (M-locked 08-15); Avatar covers every school;
//   Serration = physical attacks (dtype 0).
function rune_aspect_damage_pct(ab) {
    var _dtype = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
    var _pct   = rune_aspect_school_value(ability_school(ab));
    if (_dtype == 0) _pct += rune_aspect_value("attack_dmg", undefined);  // Serration
    return _pct / 100;
}

// Flat accuracy points for ranged actions (Hunter).
#macro RUNE_ACC_CAP 12   // 08-17 (M-locked): Hunter / Seer rune accuracy each caps at +12% total
function rune_aspect_ranged_acc(ab) {
    // Split (M-locked 08-15): Hunter = ranged PHYSICAL attacks only; the new
    // Seer aspect covers spell accuracy (any spell class). Same entry point so
    // every accuracy consumer picks up both. Stacking audit (08-17): the runes
    // SUM (three rank-I Hunters = +6, three rank-III = +12) and the sum is
    // capped at RUNE_ACC_CAP per class - the cap is shown on the rune blurb,
    // the stats-page Accuracy hover and Maren's Runesmithing tip.
    var _ac = ability_attack_class(ab);
    if (_ac == "ranged_attack") return min(RUNE_ACC_CAP, rune_aspect_value("ranged_acc", undefined));
    if (ability_class_is_spell(_ac)) return min(RUNE_ACC_CAP, rune_aspect_value("spell_acc", undefined));
    return 0;
}
// Capped rune accuracy by class key ("ranged_acc" | "spell_acc") for UI readouts.
function rune_acc_total(aspect_key) {
    return min(RUNE_ACC_CAP, rune_aspect_value(aspect_key, undefined));
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

// Source-tier cap for combining. Base game: I/II combine up (III is the top).
// Past that (III -> IV -> V -> ...) unlocks with IRONWAKE STANDS - the same
// gate as A6+/the Descent (M locked 07-27), so the A0-A5 climb keeps the
// authored rune curve while post-win players can chase endless tiers.
function rune_combine_tier_cap() {
    return (variable_global_exists("ironwake_stands") && global.ironwake_stands) ? 9999 : 3;
}

// Combinable groups: distinct {id, tier, count, name} present 3+ times, below
// the current source-tier cap (see rune_combine_tier_cap).
function rune_combine_groups() {
    var _out = [];
    if (!variable_global_exists("rune_inventory")) return _out;
    var _seen = [];
    for (var _i = 0; _i < array_length(global.rune_inventory); _i++) {
        var _r = global.rune_inventory[_i];
        if (_r.tier >= rune_combine_tier_cap()) continue;
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

// Combine cost {gold, dust} by source tier. Gold is CHA-discounted. Endless
// tiers double per step from III->IV = 400g + 60 dust (M locked 07-27).
function rune_combine_cost(tier) {
    var _c;
    if (tier <= 1)      _c = { gold: cha_price(50),  dust: 10 };
    else if (tier == 2) _c = { gold: cha_price(150), dust: 30 };
    else {
        var _mult = power(2, tier - 3);
        _c = { gold: cha_price(400 * _mult), dust: 60 * _mult };
    }
    // Etching Bench (Maren rank 1, M-locked 08-15): 20% less dust.
    if (npc_rank("maren") >= 1) _c.dust = max(1, round(_c.dust * 0.80));
    return _c;
}

// Combine 3x (id, tier) -> 1x (id, tier+1), paying gold+dust. "" on success else reason.
function maren_combine_rune(id, tier) {
    if (tier >= rune_combine_tier_cap()) {
        return (rune_combine_tier_cap() <= 3)
            ? "Tier III is my limit... until Ironwake stands."
            : "Already max tier.";
    }
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
// tier-I scrap returns a small flat amount and no lower-tier rune). Endless tiers
// track their doubled combine dust (IV refunds 30, V refunds 60, ...).
function rune_split_dust(tier) {
    if (tier >= 4) return 30 * power(2, tier - 4);
    if (tier == 3) return 15;
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
function rune_flagship_ids()  { return ["quickcast", "echo", "cascade", "bastion"]; }
function flagship_craft_cost() { return { gold: cha_price(300), dust: 60 }; }

// Flagship unlock gates (C6, M-approved 07-09): the new recipes are chase
// content - locked rows show at Maren greyed with this text (Vex-unlock idiom).
// "" = unlocked. Quickcast/Echo stay available from the start.
function flagship_unlock_text(id) {
    // TEST LEVER (F8, gc Step): recipes read unlocked while the toggle is on.
    if (variable_global_exists("debug_unlock_all") && global.debug_unlock_all) return "";
    if (id == "cascade") {
        var _bk = variable_global_exists("total_boss_kills") ? global.total_boss_kills : 0;
        return (_bk >= 25) ? "" : ("Locked - slay 25 bosses (" + string(_bk) + "/25)");
    }
    if (id == "bastion") {
        // M ruling 07-10: 20 full clears was "immense" - lowered to 8 (24 floors
        // survived) on the same EXISTING persistent counter, history backfills.
        var _dc = variable_global_exists("dungeon_clears_total") ? global.dungeon_clears_total : 0;
        return (_dc >= 8) ? "" : ("Locked - complete 8 full clears (" + string(_dc) + "/8)");
    }
    return "";
}

// Craft a tier-III flagship rune for gold+dust. "" on success else reason.
function maren_craft_flagship(id) {
    var _def = rune_get(id);
    if (_def == undefined || !variable_struct_exists(_def, "tier3_only") || !_def.tier3_only) return "Not a flagship rune.";
    var _lock = flagship_unlock_text(id);
    if (_lock != "") return _lock;
    var _cost = flagship_craft_cost();
    if (global.gold < _cost.gold) return "Need " + string(_cost.gold) + "g.";
    if (!variable_global_exists("rune_dust") || global.rune_dust < _cost.dust) return "Need " + string(_cost.dust) + " dust.";
    global.gold      -= _cost.gold;
    global.rune_dust -= _cost.dust;
    array_push(global.rune_inventory, rune_make(id, 3));
    save_game();
    return "";
}

// ---------------------------------------------------------------------------
// shop_build_sell_list() - the sellable-item list for the shop SELL tab, SORTED:
// equipment first by rarity DESC (legendary -> common; stash before carried and
// build order break ties), then consumables in their original stash -> carried
// order. SINGLE SOURCE for both the Step action handler and the Draw renderer -
// they used to build parallel arrays independently, and any ordering drift would
// sell the wrong item. Returns { items, src, idx, tags }:
//   src  0=equipment_stash 1=consumable_stash 2=carried_items 3=consumable_inventory
//   idx  = index within the source array at build time (for the actual removal)
//   tags = "[STASH]" / "[CARRIED]" display tag per row
// ---------------------------------------------------------------------------
function shop_build_sell_list() {
    var _entries = [];
    for (var _i = 0; _i < array_length(global.equipment_stash); _i++)
        array_push(_entries, { it: global.equipment_stash[_i],      src: 0, idx: _i });
    for (var _i = 0; _i < array_length(global.consumable_stash); _i++)
        array_push(_entries, { it: global.consumable_stash[_i],     src: 1, idx: _i });
    for (var _i = 0; _i < array_length(global.carried_items); _i++)
        array_push(_entries, { it: global.carried_items[_i],        src: 2, idx: _i });
    for (var _i = 0; _i < array_length(global.consumable_inventory); _i++)
        array_push(_entries, { it: global.consumable_inventory[_i], src: 3, idx: _i });

    array_sort(_entries, function(_a, _b) {
        var _ae = variable_struct_exists(_a.it, "slot");
        var _be = variable_struct_exists(_b.it, "slot");
        if (_ae != _be) return _ae ? -1 : 1;   // equipment block above consumables
        if (_ae) {
            var _ar = variable_struct_exists(_a.it, "rarity") ? _a.it.rarity : 0;
            var _br = variable_struct_exists(_b.it, "rarity") ? _b.it.rarity : 0;
            if (_ar != _br) return _br - _ar;  // rarity DESC (M 07-09: sort for sell navigation)
        }
        if (_a.src != _b.src) return _a.src - _b.src;
        return _a.idx - _b.idx;
    });

    var _r = { items: [], src: [], idx: [], tags: [] };
    for (var _i = 0; _i < array_length(_entries); _i++) {
        var _e = _entries[_i];
        array_push(_r.items, _e.it);
        array_push(_r.src,   _e.src);
        array_push(_r.idx,   _e.idx);
        array_push(_r.tags,  (_e.src == 0 || _e.src == 1) ? "[STASH]" : "[CARRIED]");
    }
    return _r;
}

// =============================================================================
// SABLE THE ALCHEMIST - Salvage (dust faucet) / Brew / Upgrade. See SYSTEMS_SABLE.md.
// Shares global.rune_dust with Maren. Salvage is the primary dust faucet.
// =============================================================================

// --- Salvage rates ---
function sable_salvage_gear_dust(rarity) {
    switch (rarity) {
        case 0: return 1; case 1: return 3; case 2: return 12; case 3: return 30; case 4: return 75;
    }
    return 1;
}
function sable_salvage_rune_dust(tier) {
    if (tier >= 3) return 40 * power(2, tier - 3);   // endless tiers keep pace
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

// =============================================================================
// SABLE TRANSMUTE (M 07-27, distributed rune economy): melt any 3 SAME-TIER
// runes (mixed types welcome - this is the junk-singles drain) into ONE RANDOM
// rune of the NEXT tier. The gamble half of the leftover-rune sink; Petra's
// blueprint order is the planned half. Source tier obeys the same post-win cap
// as Maren's combine (rune_combine_tier_cap), so pre-win output tops out at III.
// =============================================================================

function sable_transmute_cost(tier) { return cha_price(60 * max(1, tier)); }

// Shared pool: every catalog rune id minus flagship recipes (those stay behind
// Maren's craft + their unlock gates). Sable's transmute rolls from it; Petra's
// blueprint chooser lists it.
function rune_blueprint_pool() {
    var _cat  = rune_catalog();
    var _bans = rune_flagship_ids();
    var _pool = [];
    for (var _i = 0; _i < array_length(_cat); _i++) {
        var _banned = false;
        for (var _b = 0; _b < array_length(_bans); _b++) {
            if (_bans[_b] == _cat[_i].id) { _banned = true; break; }
        }
        if (!_banned) array_push(_pool, _cat[_i].id);
    }
    return _pool;
}

function sable_transmute_roll_id() {
    var _pool = rune_blueprint_pool();
    return _pool[irandom(array_length(_pool) - 1)];
}

// Transmute the 3 rune_inventory indices in idx_array. "" on success (the new
// rune's title lands in the by-ref out struct), else the refusal reason.
function sable_transmute_runes(idx_array, out) {
    if (array_length(idx_array) != 3) return "Choose exactly 3 runes.";
    var _inv = global.rune_inventory;
    for (var _i = 0; _i < 3; _i++) {
        if (idx_array[_i] < 0 || idx_array[_i] >= array_length(_inv)) return "Choose exactly 3 runes.";
    }
    var _t = _inv[idx_array[0]].tier;
    if (_inv[idx_array[1]].tier != _t || _inv[idx_array[2]].tier != _t) return "All three must share a tier.";
    if (_t >= rune_combine_tier_cap()) {
        return (rune_combine_tier_cap() <= 3)
            ? "Tier III is the ceiling - until Ironwake stands."
            : "Already max tier.";
    }
    var _fee = sable_transmute_cost(_t);
    if (global.gold < _fee) return "Need " + string(_fee) + "g.";
    // Delete highest-index-first so the earlier indices stay valid.
    var _sorted = [idx_array[0], idx_array[1], idx_array[2]];
    array_sort(_sorted, false);
    array_delete(_inv, _sorted[0], 1);
    array_delete(_inv, _sorted[1], 1);
    array_delete(_inv, _sorted[2], 1);
    global.gold -= _fee;
    var _new = rune_make(sable_transmute_roll_id(), _t + 1);
    array_push(_inv, _new);
    out.title = rune_title(_new);
    out.rune  = _new;   // full struct for the result reveal card (M 08-15)
    save_game();
    return "";
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
        // --- Baseline brews (M 07-28: "sable should have a vast list... right now
        // we can only find tier 0 or buy them"). Names/effects mirror the drop
        // pools exactly (global.consumables_standard/elite) so icons + fusion
        // ladders already resolve. Cheap gold, token dust.
        { id:"salve",    name:"Healing Salve",         effect:"heal",           value:25, desc:"Restore 25 HP",                    gold_val:20, dust:2,  gold:cha_price(10) },
        { id:"tonic",    name:"Energy Tonic",          effect:"energy",         value:1,  desc:"Gain +1 AP this turn (free to use)", gold_val:15, dust:3,  gold:cha_price(12) },
        { id:"antidote", name:"Antidote",              effect:"cleanse_dot",    value:0,  desc:"Clear all active DoT effects",     gold_val:18, dust:2,  gold:cha_price(8) },
        { id:"salts",    name:"Smelling Salts",        effect:"cleanse_debuff", value:0,  desc:"Remove one active debuff",         gold_val:16, dust:2,  gold:cha_price(8) },
        { id:"gsalve",   name:"Greater Healing Salve", effect:"heal",           value:50, desc:"Restore 50 HP",                    gold_val:45, dust:10, gold:cha_price(22) },
        { id:"adren",    name:"Adrenaline Vial",       effect:"energy",         value:3,  desc:"Gain +3 AP this turn (free to use)", gold_val:55, dust:14, gold:cha_price(30) },
        { id:"purif",    name:"Purification Draught",  effect:"cleanse_all",    value:0,  desc:"Clear all negative effects",       gold_val:50, dust:10, gold:cha_price(24) },
        { id:"warden",   name:"Warden's Tonic",        effect:"heal_dot",       value:8,  desc:"Restore 8 HP per turn for 3 turns", gold_val:48, dust:12, gold:cha_price(26) },
        { id:"laegis",   name:"Lesser Aegis Draught",  effect:"shield",         value:15, desc:"Gain a 15-point shield",           gold_val:30, dust:10, gold:cha_price(16) },
        // --- Alchemy exclusives (her original list) ---
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
        // map [G]: permanently lose 2 random stat points, extract with all run loot.
        // (Toll was 3 at ship; M softened it 2026-07-08: "too strong of a loss".)
        // The Genie Lamp (rare elite/boss drop) is the free version of this bargain.
        { id:"devil_wine", name:"Devil Wine", effect:"escape_wine", value:0, desc:"Drink on the floor map [G]: PERMANENTLY lose 2 random stat points and extract to camp with all your loot", gold_val:400, dust:50, gold:cha_price(1200) },
    ];
    // (Sable Companion perk applies below via the catalog wrapper.)
}
// Catalog with the Companion-perk discount applied (single source for display + charge).
function sable_brew_catalog_priced() {
    var _c = sable_brew_catalog();
    // Second Cauldron (rank 1, M-locked 08-15): brews 10% cheaper, on top of
    // the Companion bond discount. Brews only - upgrades keep sable_cost_mult.
    var _m = sable_cost_mult() * ((npc_rank("sable") >= 1) ? 0.90 : 1.0);
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

// =============================================================================
// CHAOTIC BREW (M 07-28: "the potions combine if not matching may yield positive
// or negative results (like skyrim)... make it more experimental"). Fuse ANY 3
// potions - mismatched welcome - into one Chaotic Brew. Drinking it rolls a REAL
// effect on the spot (heal / shield / regen / AP / resource), sometimes with a
// sting. The junk-consumable drain beside the exact-match fusion ladder.
// =============================================================================

function sable_chaotic_cost() {
    var _m = sable_cost_mult();
    return { gold: floor(cha_price(12) * _m), dust: floor(5 * _m) };
}

// Combined potion pool - hub stash first, then the carried pouch, with source
// tags (M 08-11: "brew should have access to stash i shouldn't have to
// withdraw items into my inventory"). Sable is hub-only, so the stash is
// always reachable when this runs. Every pick-3 / fusion surface lists and
// consumes from THIS pool; combined indices are only valid against a pool
// built in the same frame (nothing else can mutate the inventories while
// Sable's screen is open).
function sable_potion_pool() {
    var _out = [];
    if (variable_global_exists("consumable_stash")) {
        for (var _i = 0; _i < array_length(global.consumable_stash); _i++)
            array_push(_out, { it: global.consumable_stash[_i], src: 0, idx: _i });
    }
    if (variable_global_exists("consumable_inventory")) {
        for (var _i = 0; _i < array_length(global.consumable_inventory); _i++)
            array_push(_out, { it: global.consumable_inventory[_i], src: 1, idx: _i });
    }
    return _out;
}

// Remove the pool entries at the given combined indices - per source,
// highest index first, so earlier indices stay valid.
function sable_potion_pool_delete(combined) {
    var _pool = sable_potion_pool();
    var _s0 = [], _s1 = [];
    for (var _i = 0; _i < array_length(combined); _i++) {
        var _e = _pool[combined[_i]];
        if (_e.src == 0) array_push(_s0, _e.idx); else array_push(_s1, _e.idx);
    }
    array_sort(_s0, false); array_sort(_s1, false);
    for (var _i = 0; _i < array_length(_s0); _i++) array_delete(global.consumable_stash, _s0[_i], 1);
    for (var _i = 0; _i < array_length(_s1); _i++) array_delete(global.consumable_inventory, _s1[_i], 1);
}

// Fuse 3 potions by their sable_potion_pool() combined indices (stash-aware
// since 08-11). "" on success else the reason.
function sable_chaotic_fuse(indices) {
    if (array_length(indices) != 3) return "Choose exactly 3 potions.";
    var _pool = sable_potion_pool();
    for (var _i = 0; _i < 3; _i++) {
        if (indices[_i] < 0 || indices[_i] >= array_length(_pool)) return "Choose exactly 3 potions.";
    }
    var _cost = sable_chaotic_cost();
    if (global.gold < _cost.gold) return "Need " + string(_cost.gold) + "g.";
    if (!variable_global_exists("rune_dust") || global.rune_dust < _cost.dust) return "Need " + string(_cost.dust) + " dust.";
    // Build the brew's REAL effects from the three bases (M-locked 08-15,
    // Skyrim-alchemy style): every base effect carried at 60% potency (rounded
    // up, min 1), plus ONE minor downside rolled NOW. Everything is stamped on
    // the item and readable in its description - no mystery roll at drink time.
    var _mix = [];
    var _mix_txt = "";
    for (var _mi = 0; _mi < 3; _mi++) {
        var _src = _pool[indices[_mi]].it;
        var _set = variable_struct_exists(_src, "effect_type") ? _src.effect_type : "";
        // Brew-in-brew and escape charms don't survive the cauldron.
        if (_set == "" || _set == "chaotic" || string_pos("escape", _set) == 1) continue;
        var _sv = variable_struct_exists(_src, "effect_value") ? _src.effect_value : 0;
        var _cv = max(1, ceil(_sv * 0.60));
        array_push(_mix, { effect_type: _set, effect_value: _cv });
        _mix_txt += ((_mix_txt == "") ? "" : "  /  ") + chaotic_mix_label(_set, _cv);
    }
    sable_potion_pool_delete(indices);
    global.gold      -= _cost.gold;
    global.rune_dust -= _cost.dust;
    var _down = chaotic_downside_roll();
    var _desc = ((_mix_txt == "") ? "Only dregs survived the cauldron." : ("Mix: " + _mix_txt + "."))
        + "  Dregs: " + _down.label + ".";
    var _brew = create_consumable("Chaotic Brew", "chaotic", 0, _desc, 35);
    _brew.mix      = _mix;
    _brew.downside = _down;
    array_push(global.consumable_inventory, _brew);
    save_game();
    return "";
}

// Short human label for one carried mix effect (brew descriptions + logs).
function chaotic_mix_label(_et, _v) {
    switch (_et) {
        case "heal":           return "Restore " + string(_v) + " HP";
        case "heal_dot":       return "Regen " + string(_v) + " HP/turn (3t)";
        case "shield":         return string(_v) + "-pt ward";
        case "energy":         return "+" + string(_v) + " AP";
        case "resource_ap":    return "+" + string(_v) + " resource, +1 AP";
        case "cleanse_dot":    return "Cleanse DoTs";
        case "cleanse_debuff": return "Cleanse a debuff";
        case "cleanse_all":    return "Cleanse everything";
        case "gold_find_pot":  return "+" + string(_v) + "% gold find (2 bosses)";
        case "loot_find_pot":  return "+" + string(_v) + "% loot chance (2 bosses)";
    }
    return "a strange residue";
}

// The brew's mandatory sting (M 08-15: "always a slight negative"), rolled at
// BREW time so the label warns the drinker before they commit.
function chaotic_downside_roll() {
    if (irandom(1) == 0) return { kind: "bite",     label: "it bites going down (8-15 damage in battle, 15g of spilled coin at camp)" };
    return                { kind: "sluggish", label: "it numbs the arm (-1 AP when drunk in battle)" };
}

// QUINTESSENCE (LEGENDARY FORGE component; RE-LOCKED 08-15): distill THREE
// DIFFERENT SPECIALTY brews + gold into Sable's share of the forge. "Any 3
// commons" read too cheap for a Legendary Forge part (M). Mirrors the chaotic
// fuse's consumption; yields no consumable - the component counter is the
// product.
function sable_quint_specialty() {
    return ["Aegis Draught", "Lesser Aegis Draught", "Master Healing Draught",
            "Phoenix Tonic", "Cleansing Philter", "Ley Battery",
            "Goldfinger Elixir", "Faerie's Tear"];
}
function sable_is_specialty_brew(_nm) {
    var _sp = sable_quint_specialty();
    for (var _i = 0; _i < array_length(_sp); _i++) if (_sp[_i] == _nm) return true;
    return false;
}
function sable_quintessence_distill(indices) {
    if (array_length(indices) != 3) return "Choose exactly 3 potions.";
    var _pool = sable_potion_pool();
    for (var _i = 0; _i < 3; _i++) {
        if (indices[_i] < 0 || indices[_i] >= array_length(_pool)) return "Choose exactly 3 potions.";
    }
    // Specialty + distinct gates (M-locked 08-15).
    var _names = [];
    for (var _i = 0; _i < 3; _i++) {
        var _qp = _pool[indices[_i]];
        var _qn = variable_struct_exists(_qp, "name") ? _qp.name : "";
        if (!sable_is_specialty_brew(_qn)) {
            return "Quintessence asks Sable's OWN craft - three different specialty brews.";
        }
        for (var _j = 0; _j < array_length(_names); _j++) {
            if (_names[_j] == _qn) return "Three DIFFERENT specialty brews - no repeats.";
        }
        array_push(_names, _qn);
    }
    var _fee = forge_quint_cost();
    if (global.gold < _fee) return "Need " + string(_fee) + "g.";
    sable_potion_pool_delete(indices);
    global.gold -= _fee;
    forge_components_ensure();
    global.forge_comp_quint += 1;
    save_game();
    return "";
}

// What a Chaotic Brew actually DOES, rolled at drink time. Every outcome routes
// through an EXISTING consumable effect channel (real, both in and out of
// combat); the optional sting is applied by the drink site (HP bite in combat,
// gold bite at camp - out-of-combat has no HP-loss channel).
function chaotic_brew_roll() {
    var _r = irandom(99);
    var _out;
    if      (_r < 22) _out = { effect_type:"heal",        value: irandom_range(40, 90), label:"mends flesh in a rush" };
    else if (_r < 42) _out = { effect_type:"shield",      value: irandom_range(20, 40), label:"hardens into a ward" };
    else if (_r < 62) _out = { effect_type:"heal_dot",    value: irandom_range(10, 18), label:"soaks in slowly" };
    else if (_r < 82) _out = { effect_type:"energy",      value: irandom_range(2, 4),   label:"crackles with vigor" };
    else              _out = { effect_type:"resource_ap", value: irandom_range(2, 4),   label:"sings with ley-light" };
    // The sting (~1 in 3): the payoff still lands, but the brew curdles and bites.
    _out.sting = (irandom(99) < 35);
    return _out;
}

// Standard consumables held 3+ times that have an upgrade target. [{from,to,count}].
function sable_upgrade_groups() {
    // 07-28 (M: "i wanted baseline potions combined into better versions" - the
    // ladder existed but a recipe only APPEARED once 3 copies were held, so it
    // was invisible): now EVERY recipe lists always, with the held count; rows
    // grey until fusable. Commit still requires 3 (sable_upgrade validates).
    var _out  = [];
    var _map  = sable_upgrade_map();
    var _pool = sable_potion_pool();   // stash + pouch (08-11)
    for (var _m = 0; _m < array_length(_map); _m++) {
        var _cnt = 0;
        for (var _i = 0; _i < array_length(_pool); _i++)
            if (_pool[_i].it.name == _map[_m].from) _cnt++;
        array_push(_out, { from: _map[_m].from, to: _map[_m].to, count: _cnt });
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
    // Gather 3 combined-pool indices (08-11: stash + pouch; the pool lists the
    // stash first, so stash copies are spent before carried ones).
    var _pool = sable_potion_pool();
    var _idxs = [];
    for (var _i = 0; _i < array_length(_pool); _i++)
        if (_pool[_i].it.name == from_name) array_push(_idxs, _i);
    if (array_length(_idxs) < 3) return "Need 3 identical potions.";
    var _tmpl = sable_elite_template(_to);
    if (_tmpl == undefined) return "Upgrade target unavailable.";
    sable_potion_pool_delete([_idxs[0], _idxs[1], _idxs[2]]);
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
        // --- Bloodwarden HD skins (08-14, M ruling: the pro-run knights ship
        //     as Vael-only CLASS skins - `cls` gates them to Bloodwarden. One
        //     diagonal frame serves every facing; single-frame skins are
        //     already first-class citizens (player_sprite_frame). ---
        { id:"bw_vanguard", name:"Crimson Vanguard", sprite:asset_get_index("spr_skin_bw_vanguard"), gold:600, desc:"The Warden's war-plate, re-struck in fine detail.", req:"", gender:"m", cls:1 },
        { id:"bw_winghelm", name:"Winghelm Warden",  sprite:asset_get_index("spr_skin_bw_winghelm"), gold:750, desc:"A winged helm above blood-dark plate.",             req:"", gender:"m", cls:1 },
    ];
}

// The catalog as the CURRENT character may browse it: class-locked skins
// (`cls` field) only show for that class, and class-locked entries whose art
// is not yet imported are hidden outright (no broken preview rows). Both the
// Vael list draw AND its Step mapping consume THIS - never index the raw
// catalog for the list, or clicks misroute (index coupling).
function vael_skin_catalog_visible() {
    var _all = vael_skin_catalog();
    var _cid = variable_global_exists("chosen_class") ? global.chosen_class : 0;
    var _out = [];
    for (var _i = 0; _i < array_length(_all); _i++) {
        var _sk = _all[_i];
        if (variable_struct_exists(_sk, "cls")) {
            if (_sk.cls != _cid) continue;
            if (_sk.sprite == undefined || _sk.sprite == -1 || !sprite_exists(_sk.sprite)) continue;
        }
        array_push(_out, _sk);
    }
    return _out;
}

// =============================================================================
// PORTRAIT CREATION POOL (08-14, M-locked): character creation offers only the
// 3 MOST-FITTING portraits per class+gender (M's confirmed picks, review round
// _for_review/portrait_gating_0814/SHEET_PICKS_v2). The FULL 60-portrait pool
// stays browsable/purchasable at Vael's portrait tab (100g) - that is the gate.
// Returns FLAT indices into global.portrait_sprites so global.chosen_portrait
// keeps its shipped meaning (saves unaffected). Falls back to the full pool if
// a sprite ever goes missing from the flat list.
// =============================================================================
function portrait_creation_pool(class_id, gender) {
    var _picks;
    if (class_id == 0)      _picks = (gender == "f") ? [spr_portrait_arc_f5,    spr_portrait_arc_f7,    spr_portrait_arc_f8]
                                                     : [spr_portrait_arc_m1,    spr_portrait_arc_m4,    spr_portrait_arc_m9];
    else if (class_id == 1) _picks = (gender == "f") ? [spr_portrait_blood_f10, spr_portrait_blood_f13, spr_portrait_blood_f6]
                                                     : [spr_portrait_blood_m3,  spr_portrait_blood_m4,  spr_portrait_blood_m8];
    else                    _picks = (gender == "f") ? [spr_portrait_shadow_f5, spr_portrait_shadow_f6, spr_portrait_shadow_f4]
                                                     : [spr_portrait_shadow_m1, spr_portrait_shadow_m4, spr_portrait_shadow_m8];
    var _out = [];
    for (var _i = 0; _i < array_length(_picks); _i++) {
        for (var _j = 0; _j < array_length(global.portrait_sprites); _j++) {
            if (global.portrait_sprites[_j] == _picks[_i]) { array_push(_out, _j); break; }
        }
    }
    if (array_length(_out) == 0) {
        for (var _k = 0; _k < array_length(global.portrait_sprites); _k++) array_push(_out, _k);
    }
    return _out;
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
// THE Vael cosmetic price: bond Friend discount + Atelier (rank 1, M-locked
// 08-15) 20% off tints and skins. Every display/charge site routes here.
function vael_cosmetic_price(g) {
    var _m = affinity_discount_mult("vael");
    if (npc_rank("vael") >= 1) _m *= 0.80;
    return floor(g * _m);
}
function vael_buy_skin(id) {
    var _sk = vael_skin_get(id);
    if (_sk == undefined) return "Unknown skin.";
    if (vael_skin_owned(id)) return "Already owned.";
    if (!vael_skin_unlocked(_sk)) return "Locked - " + vael_skin_req_text(_sk);
    var _vprice = vael_cosmetic_price(_sk.gold);   // Friend perk + Atelier rank
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
    // Class-locked skins (cls field, 08-14) never dress another class - a save
    // that somehow carries one across classes falls back to the natural look.
    if (variable_struct_exists(_sk, "cls") && _sk.cls != _ci) return _default;
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
    var _price = vael_cosmetic_price(_t.gold);   // Friend perk + Atelier rank
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

// school_vfx_sprite(base_spr, school) - which sprite the cast-impact VFX draws.
// image_blend MULTIPLIES, so tinting the authored (yellow-orange) Gigapack art
// barely reads - the yellow survives (07-14 report). An equipped Vael tint
// swaps to the grayscale twin (tools/make_vfx_grey_twins.py) so the blend
// becomes tint x white = the tint, at full luminance detail. Default tint
// keeps the authored art untouched.
function school_vfx_sprite(base_spr, school) {
    if (school == "" || school_tint_id(school) == "default") return base_spr;
    switch (base_spr) {
        case spr_vfx_impact: return spr_vfx_impact_grey;
        case spr_vfx_fire:   return spr_vfx_fire_grey;
        case spr_vfx_void:   return spr_vfx_void_grey;
        case spr_vfx_arcane: return spr_vfx_arcane_grey;
        // 08-14 sitting: the 5 classics - Vael tints were invisible on their
        // colored art (multiply over color) until these twins existed.
        case spr_vfx_frost:  return spr_vfx_frost_grey;
        case spr_vfx_shock:  return spr_vfx_shock_grey;
        case spr_vfx_blood:  return spr_vfx_blood_grey;
        case spr_vfx_shadow: return spr_vfx_shadow_grey;
        case spr_vfx_poison: return spr_vfx_poison_grey;
    }
    return base_spr;
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
        { id:"bottomed",     name:"the Bottom's Witness", req:"Defeat The Bottom (Descent floor 50)" },
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
        case "bottomed":
            return variable_global_exists("descent_bottom_cleared") && global.descent_bottom_cleared;
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

// SHRINE BLESSINGS V2 (07-29, DESIGN_SHRINE_BLESSINGS_V2.md): every entry carries
// kind ("plain" = the reworked classic pool / "creative" = the build-around pool)
// and a one-line flavor whisper shown for the highlighted offer. The shrine offer
// rolls 2 creative + 1 plain (boon_offer_roll).
function boon_catalog() {
    return [
        // --- Plain pool (all 10 classics kept; 6 got their one-line rework) ----
        { id:"bloodlust",   kind:"plain", name:"Bloodlust",     desc:"+15% damage, rising to +25% while below half HP",              cost:120, value:0.15,
          flavor:"It wants to see you bleeding when you swing." },
        { id:"ironhide",    kind:"plain", name:"Ironhide",      desc:"+20% max HP and +2 armor",                                     cost:120, value:0.20,
          flavor:"Skin like kettle-iron, and twice as stubborn." },
        { id:"duelist",     kind:"plain", name:"Duelist",       desc:"+10% crit chance, and your crits restore 1 class resource",    cost:120, value:10,
          flavor:"Every perfect cut pays for the next." },
        { id:"vampirism",   kind:"plain", name:"Vampirism",     desc:"Heal 5 HP on each kill",                                       cost:140, value:5,
          flavor:"The dead owe you. Collect." },
        { id:"warding",     kind:"plain", name:"Warding",       desc:"Take 12% less damage; hostile afflictions run 1 turn shorter", cost:140, value:0.12,
          flavor:"Poisons sour and blades slide half a finger wide." },
        { id:"greed",       kind:"plain", name:"Greed",         desc:"+50% gold from kills; elites and bosses drop a +75g purse",    cost:80,  value:0.50,
          flavor:"Champions carry the heaviest pockets." },
        { id:"runic",       kind:"plain", name:"Runic Affinity",desc:"+50% rune dust; your socketed runes act 1 tier higher (cap V)",cost:80,  value:0.50,
          flavor:"The old letters remember what they used to mean." },
        { id:"executioner", kind:"plain", name:"Executioner",   desc:"+25% damage to enemies below 30% HP",                          cost:140, value:0.25,
          flavor:"Finish what you start." },
        { id:"aegis",       kind:"plain", name:"Aegis",         desc:"Start each combat with a 15 shield",                           cost:120, value:15,
          flavor:"A borrowed shieldwall, one prayer wide." },
        { id:"glasscannon", kind:"plain", name:"Glass Cannon",  desc:"+30% damage, -15% max HP",                                     cost:160, value:0.30,
          flavor:"Burn brighter. Break easier. Choose anyway." },
        // --- Creative pool (8 build-arounds, M-locked 07-29) --------------------
        { id:"pyre",        kind:"creative", name:"Pyre's Favor",   desc:"Enemies you kill detonate: their afflictions erupt onto your other foes", cost:130, value:0,
          flavor:"Let every corpse be a lantern." },
        { id:"secondskin",  kind:"creative", name:"Second Skin",    desc:"The first hit you take each combat is halved",                            cost:110, value:0,
          flavor:"The altar keeps the first blow for itself." },
        { id:"gambler",     kind:"creative", name:"Gambler's Icon", desc:"Win a combat within 3 turns: its loot rolls 1 rarity higher, up to Epic (icon then rests 2 fights)", cost:140, value:0,
          flavor:"Fortune loves the quick and forgets the careful." },
        { id:"whetecho",    kind:"creative", name:"Whetstone Echo", desc:"Your first ability each combat echoes at 40% power",                      cost:150, value:0,
          flavor:"Strike once. The stone remembers twice." },
        { id:"bloodtithe",  kind:"creative", name:"Blood Tithe",    desc:"Bank 1 gold for every HP you lose; the pouch pays out on extraction",     cost:90,  value:0,
          flavor:"Pain, weighed and paid in silver." },
        { id:"thirdwind",   kind:"creative", name:"Third Wind",     desc:"Every 3rd ability you cast in a combat costs 1 less AP",                  cost:130, value:0,
          flavor:"One, two - and the third comes free as breath." },
        { id:"feast",       kind:"creative", name:"Feast of Crows", desc:"Each foe that falls in a fight: +8% damage and +2 armor until it ends",   cost:120, value:0,
          flavor:"The crows crown whoever feeds them." },
        { id:"silvertongue",kind:"creative", name:"Silvered Tongue",desc:"Every event room offers you one extra, honeyed way through",              cost:100, value:0,
          flavor:"Doors open for a voice that rings true." },
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
// when the target is below 30% HP). target_hp_frac in 0..1. `player` is optional
// (the combat player struct): with it, Bloodlust's V2 ramp reads the caster's own
// HP (+25% total below half). Feast of Crows stacks are global (per-combat).
function boon_damage_mult(target_hp_frac, player = undefined) {
    var _m = 1.0;
    if (boon_active("bloodlust")) {
        var _bl = boon_value("bloodlust");
        if (player != undefined && variable_struct_exists(player, "max_HP")
            && player.max_HP > 0 && player.HP < player.max_HP * 0.5) _bl = 0.25;
        _m += _bl;
    }
    if (boon_active("glasscannon")) _m += boon_value("glasscannon");
    if (boon_active("executioner") && target_hp_frac <= 0.30) _m += boon_value("executioner");
    // Feast of Crows: +8% per enemy that has died this combat (reset per combat).
    if (boon_active("feast") && variable_global_exists("feast_stacks") && global.feast_stacks > 0) {
        _m += 0.08 * global.feast_stacks;
    }
    return _m;
}

// Flat armor from boons, applied alongside player.equip_armor in every player
// mitigation chain (basic attack / double strike / combat_mitigate_player):
// Ironhide V2 grants +2; Feast of Crows adds +2 per corpse this combat.
function boon_flat_armor() {
    var _a = 0;
    if (boon_active("ironhide")) _a += 2;
    if (boon_active("feast") && variable_global_exists("feast_stacks")) _a += 2 * global.feast_stacks;
    return _a;
}

// Second Skin: the FIRST hit the player takes each combat is halved. Called at
// the end of each mitigation chain, right before the shield absorb. Consumes the
// per-combat flag (set in combat_apply_start_traits) only when it actually fires.
function boon_second_skin_apply(player, dmg, log) {
    if (dmg > 1 && boon_active("secondskin")
        && variable_struct_exists(player, "second_skin_used") && !player.second_skin_used) {
        player.second_skin_used = true;
        var _h = ceil(dmg / 2);
        array_push(log, "Second Skin turns the blow - " + string(dmg) + " becomes " + string(_h) + "!");
        return _h;
    }
    return dmg;
}

// Gambler's Icon: +1 loot rarity tier for drops rolled while the fight is still
// within 3 rounds, unless the icon is resting (2-fight cooldown after a proc -
// bookkeeping lives in combat_apply_start_traits). Marks the proc so the NEXT
// combat start arms the cooldown; same-fight drops all keep the bump.
function boon_gambler_tier_bonus() {
    if (!boon_active("gambler")) return 0;
    if (variable_global_exists("gambler_cd") && global.gambler_cd > 0) return 0;
    if (!instance_exists(obj_combat_controller)) return 0;
    var _cs = instance_find(obj_combat_controller, 0).combat_state;
    if (_cs == undefined || _cs.round > 3) return 0;
    global.gambler_proc = true;
    return 1;
}

// Shrine reroll (V2): (10 + 10 x awakening) dust, once per shrine.
function shrine_reroll_cost() {
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    return 10 + 10 * clamp(_asc, 0, 5);
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

// Lowest-value CARRIED item whose tribute worth covers `cost`. Returns
// {source, index, item} or undefined. Legacy auto-pick path - the shrine now
// routes through the item picker (item_picker_candidates_by_tribute), but keep
// this PACK-ONLY too: the hub stash must never feed a mid-run altar, and an
// equipped item (global.inventory) is never a candidate on any path.
function boon_item_tribute_pick(cost) {
    var _best = undefined; var _best_val = 999999;
    if (variable_global_exists("carried_items")) {
        for (var _i = 0; _i < array_length(global.carried_items); _i++) {
            var _v = item_tribute_value(global.carried_items[_i].rarity);
            if (_v >= cost && _v < _best_val) { _best_val = _v; _best = { source:"carried", index:_i, item:global.carried_items[_i] }; }
        }
    }
    return _best;
}

// Roll up to 3 distinct unowned boons for a shrine offer. V2 shape: 2 from the
// CREATIVE pool + 1 from the PLAIN pool; when a pool runs dry the other tops up.
function boon_offer_roll() {
    var _cat = boon_catalog();
    var _creative = [];
    var _plain    = [];
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (boon_active(_cat[_i].id)) continue;
        if (_cat[_i].kind == "creative") array_push(_creative, _cat[_i].id);
        else                             array_push(_plain,    _cat[_i].id);
    }
    // Fisher-Yates shuffle both pools.
    for (var _i = array_length(_creative) - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _t = _creative[_i]; _creative[_i] = _creative[_j]; _creative[_j] = _t;
    }
    for (var _i = array_length(_plain) - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _t = _plain[_i]; _plain[_i] = _plain[_j]; _plain[_j] = _t;
    }
    var _out = [];
    for (var _i = 0; _i < min(2, array_length(_creative)); _i++) array_push(_out, _creative[_i]);
    if (array_length(_plain) > 0) array_push(_out, _plain[0]);
    // Top up to 3 from whichever pool still has spares.
    var _ci = 2; var _pi = 1;
    while (array_length(_out) < 3 && (_ci < array_length(_creative) || _pi < array_length(_plain))) {
        if (_ci < array_length(_creative))   { array_push(_out, _creative[_ci]); _ci++; }
        else                                 { array_push(_out, _plain[_pi]);    _pi++; }
    }
    return _out;
}

// Pay tribute for a boon. method "gold" / "dust" / "item". "" on success else reason.
function boon_pay(id, method) {
    var _b = boon_get(id);
    if (_b == undefined) return "Unknown boon.";
    if (boon_active(id)) return "Already claimed.";
    // Sharp Eye pet capstone (C5): boons cost 15% less. Discounted ONCE here so
    // gold, the derived dust cost and the item-tribute tier all agree with the
    // shrine draw (which quotes shrine_boon_price too).
    var _cost = shrine_boon_price(_b.cost);
    if (method == "gold") {
        if (global.gold < _cost) return "Need " + string(_cost) + "g.";
        global.gold -= _cost;
        boon_grant(id);
        return "";
    } else if (method == "dust") {
        var _dc = boon_dust_cost(_cost);
        if (!variable_global_exists("rune_dust") || global.rune_dust < _dc) return "Need " + string(_dc) + " dust.";
        global.rune_dust -= _dc;
        boon_grant(id);
        return "";
    } else if (method == "item") {
        var _pick = boon_item_tribute_pick(_cost);
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

// Roll up to 3 distinct, tier-available curses the player doesn't already
// carry, dealt from the FULL shuffled pool - loot curses included freely.
// (07-29 REVERT of the 07-28 loot-scarcity deal (1-in-3 loot inclusion, max
// one per altar): it starved small pools down to 2 bland options and gutted
// the altar's drama - M: "i was wrong to take away multiple loot options per
// shrine, it added more decision making and hard choices. it should be
// exciting and powerful." Low-awakening loot power stays tempered where it
// matters: the below-A2 premium-source gate in curse_loot_tier_bonus_for,
// and cursed shrines themselves are the rarer 25% shrine roll.)
function curse_offer_roll() {
    var _cat  = curse_catalog();
    var _pool = [];
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (curse_active(_cat[_i].id)) continue;
        if (!curse_tier_available(_cat[_i].tier)) continue;
        array_push(_pool, _cat[_i].id);
    }
    // Fisher-Yates shuffle, deal the top 3.
    for (var _i = array_length(_pool) - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _t = _pool[_i]; _pool[_i] = _pool[_j]; _pool[_j] = _t;
    }
    var _out = [];
    for (var _i = 0; _i < array_length(_pool) && array_length(_out) < 3; _i++)
        array_push(_out, _pool[_i]);
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
// Loot RARITY-TIER bonus from active curses (sums all curses). Passed to
// drop_equipment as a post-roll rarity bump - NOT added to the awakening fed into
// drop_weights. The old name (curse_loot_asc_bonus) described the old, broken
// behaviour: as an awakening offset it did almost nothing at A0 and was eaten
// entirely by clamp(asc,0,5) at A5. Renamed 07-20 so the name can't mislead again.
function curse_loot_tier_bonus() {
    if (!variable_global_exists("run_curses")) return 0;
    var _b = 0;
    var _cat = curse_catalog();
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (curse_active(_cat[_i].id)) _b += _cat[_i].loot;
    }
    return _b;
}

// The bump a given drop SOURCE actually receives. Below Awakening 2 only boss
// and premium-chest drops (vault/reliquary) get curse loot tiers - M 07-28
// round 2: a floor-1 boss at 25% Epic was fine, but every mob and chest riding
// the same bump made "+1 tier" feel ever-present. At A2+ loot is scaled for it
// and the bump applies everywhere, as the reward text says. Trait bumps
// (Prospector, Treasure Hunter) are NOT curses and bypass this on purpose.
function curse_loot_tier_bonus_for(source) {
    var _b = curse_loot_tier_bonus();
    if (_b <= 0) return 0;
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    if (_asc >= 2) return _b;
    return (source == "boss" || source == "vault" || source == "reliquary") ? _b : 0;
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
// STATION-RANK checkout arming (08-17): shared by the hub carousel [U]/chip AND the
// in-screen [U] / pad L3 (M 08-17: the pad had no free hub button, so every NPC
// screen can arm the same checkout popup from inside). Returns "" or a refusal.
function npc_station_arm(npc_id) {
    if (!instance_exists(obj_hub_controller)) return "not at camp";
    var _hub = instance_find(obj_hub_controller, 0);
    var _ids = affinity_npc_ids();
    var _ix = -1;
    for (var _i = 0; _i < array_length(_ids); _i++) if (_ids[_i] == npc_id) _ix = _i;
    if (_ix < 0) return "unknown station";
    if (!_hub.npc_unlocked[_ix]) return "not unlocked";
    if (npc_rank(npc_id) >= 2)  return "already at the top rank";
    var _next = npc_rank(npc_id) + 1;
    var _c    = npc_rank_cost(_next);
    var _dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
    _hub.npc_upgrade_arm   = npc_id;
    _hub.npc_upgrade_title = string_upper(_hub.npc_names[_ix]) + "  -  STATION RANK " + string(_next);
    _hub.npc_upgrade_body  = npc_rank_perk_text(npc_id, _next)
        + "\n\nCost: " + string(_c.gold) + "g + " + string(_c.dust) + " dust"
        + "   (you have " + string(global.gold) + "g, " + string(_dust) + " dust)";
    audio_play_sound(snd_page, 1, false);
    return "";
}
// True while the station-rank checkout popup - OR its result / refusal bond
// dialog - is up (NPC screens stand down: both are hub-owned modals that can now
// sit over an open NPC screen, and the key/tap that dismisses them must not also
// reach the screen underneath).
function hub_checkout_up() {
    if (!instance_exists(obj_hub_controller)) return false;
    var _hub = instance_find(obj_hub_controller, 0);
    if (variable_instance_exists(_hub, "npc_upgrade_arm") && _hub.npc_upgrade_arm != "") return true;
    return variable_instance_exists(_hub, "bond_dialog_open") && _hub.bond_dialog_open;
}

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

// affinity_deepen_line(id, tier) - the friendly lore beat shown in the bond
// popup when a tier is crossed (M 08-15: "friendly lore text unless elevation
// to lover occurs"). Tier 4 = the Lover elevation gets its own line.
function affinity_deepen_line(id, tier) {
    var _lover = (tier >= 4);
    switch (id) {
        case "dorn":  return _lover
            ? "Dorn wipes the soot from his hands before he takes yours. \"Forge-warm,\" he mutters. \"Stay.\""
            : "Dorn says nothing - but the next blade he sets on the counter is turned handle-first, the way smiths only do for their own.";
        case "maren": return _lover
            ? "Maren pulls her facewrap down, and for once the runes can wait. \"Runes hold,\" she says. \"So do I.\""
            : "Maren traces a rune in the air between you. It hangs there a moment - a small warmth that was never for sale.";
        case "sable": return _lover
            ? "Sable's laugh loses its edge entirely. \"All my best poisons,\" she says, \"and you went and drank the honest one.\""
            : "Sable slides you a vial you didn't pay for. \"Careful,\" she smiles. \"That one's sweet.\"";
        case "vex":   return _lover
            ? "Vex squares your shoulders with both hands and doesn't let go. \"Guard up. Not against me.\""
            : "Vex nods once - a standing ovation, by Vex's measure. The sparring dummy stands reset for you before you ask.";
        case "petra": return _lover
            ? "Petra closes the ledger entirely. \"On the house,\" she says. \"All of it. Don't tell the house.\""
            : "Petra rounds your total down and calls it arithmetic. Her ledger says otherwise.";
        case "vael":  return _lover
            ? "Vael tilts your chin toward the firelight. \"There. My finest work yet.\""
            : "Vael studies you like a canvas half-finished. \"Better. The dark suits you.\"";
        case "bairc": return _lover
            ? "Bairc stands beside you at the garden fence a long while. \"They like you,\" he says at last. \"So do I, stranger. So do I.\""
            : "Bairc grunts and lets you feed the hatchlings yourself. From him, that is a vow.";
    }
    return "";
}

// =============================================================================
// NPC PROGRESSION (M-locked 08-15, "Both, layered"): each station carries
// INVESTMENT RANKS 0-2 bought with gold+dust ([U] on the hub carousel);
// a rank UNLOCKS a service, BOND tiers make that NPC cheaper on top
// (Friend 5% / Companion 10% / Lover 15%). Ranks persist in global.npc_ranks.
// =============================================================================
function npc_ranks_ensure() {
    if (!variable_global_exists("npc_ranks") || !is_struct(global.npc_ranks)) global.npc_ranks = {};
}
function npc_rank(id) {
    npc_ranks_ensure();
    return variable_struct_exists(global.npc_ranks, id) ? variable_struct_get(global.npc_ranks, id) : 0;
}
function npc_rank_cost(next) { return (next <= 1) ? { gold: 300, dust: 20 } : { gold: 900, dust: 60 }; }
function npc_rank_perk_text(id, rank) {
    switch (id + ":" + string(rank)) {
        case "dorn:1":  return "Widened Stall - Dorn stocks 2 more pieces";
        case "dorn:2":  return "Master Anvil - temper steps grant +12% quality";
        case "maren:1": return "Etching Bench - combining runes costs 20% less dust";
        case "maren:2": return "Deep Socket - once per run, +1 socket into an equipped piece ([D] at Socket Gear)";
        case "sable:1": return "Second Cauldron - her brews cost 10% less";
        case "sable:2": return "Sealed Reserve - Chaotic Brew downsides are HALVED";
        case "vex:1":   return "Sparring Yard - abilities and traits cost 10% less";
        case "vex:2":   return "Drill Regimen - your first purchase each visit is 25% off";
        case "petra:1": return "Second Ledger Line - run TWO trade orders at once; her special shelf never runs empty";
        case "petra:2": return "Favored Client - trades deliver 1 floor sooner at 75-95% quality; selling pays 10% more";
        case "vael:1":  return "Atelier - tints and skins cost 20% less";
        case "vael:2":  return "Private Gallery - one free portrait change each run";
        case "bairc:1": return "Warm Pens - hunger drains 30% slower, and his ledger opens: full stat breakdowns on hover";
        case "bairc:2": return "Night Garden - garden donations grow 50% faster";
    }
    return "";
}
// Hover quick-ref body for the carousel STATION chip (M 08-15: rank details are
// mouse-over only - the card itself stays as it was).
function npc_rank_card_tip(id) {
    var _r = npc_rank(id);
    var _s = "";
    for (var _i = 1; _i <= 2; _i++) {
        var _own = (_r >= _i);
        _s += (_own ? "Rank " + string(_i) + " (owned): " : "Rank " + string(_i) + ": ") + npc_rank_perk_text(id, _i);
        if (_i < 2) _s += "\n";
    }
    if (_r < 2) {
        var _c = npc_rank_cost(_r + 1);
        var _verb = (input_device() == 2) ? "Tap this chip" : "Press [U]";
        _s += "\n\n" + _verb + " to upgrade the station: " + string(_c.gold) + "g + " + string(_c.dust) + " dust.";
    } else {
        _s += "\n\nFully upgraded.";
    }
    _s += "\nBond tiers layer a discount on top: Friend 5% / Companion 10% / Lover 15%.";
    return _s;
}
function npc_rank_buy(id) {
    npc_ranks_ensure();
    var _r = npc_rank(id);
    if (_r >= 2) return "The station is fully upgraded.";
    var _c = npc_rank_cost(_r + 1);
    if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
    if (global.gold < _c.gold || global.rune_dust < _c.dust) {
        return "Needs " + string(_c.gold) + "g + " + string(_c.dust) + " dust.";
    }
    global.gold      -= _c.gold;
    global.rune_dust -= _c.dust;
    variable_struct_set(global.npc_ranks, id, _r + 1);
    save_game();
    return "";
}
// Bond-tier service discount layered on rank perks.
function npc_bond_discount(id) {
    var _t = affinity_tier(id);
    return (_t >= 4) ? 0.15 : ((_t >= 3) ? 0.10 : ((_t >= 2) ? 0.05 : 0));
}
// Rank+bond-aware price for an NPC's SERVICES (not base goods sale prices yet -
// per-vendor wiring lands site by site).
function npc_service_price(id, base) {
    var _m = 1 - npc_bond_discount(id);
    if (id == "sable" && npc_rank("sable") >= 1) _m *= 0.90;
    if (id == "vex"   && npc_rank("vex")   >= 1) _m *= 0.90;
    if (id == "vael"  && npc_rank("vael")  >= 1) _m *= 0.80;
    return max(1, floor(base * _m));
}


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
        // All-in-one turn-in (M 07-28): a FINISHED favor completes right here
        // at the NPC - no tavern-board round trip. quest_turn_in crosses the
        // gate itself (the board turn-in path still works as an alternative).
        if (_qs.progress >= _qd.obj_target) {
            var _ti = quest_turn_in(_qid);
            return _ti;   // "" = crossed
        }
        return "\"" + _qd.name + "\" is underway - " + _qd.objective
            + "  (" + string(min(_qs.progress, _qd.obj_target)) + "/" + string(_qd.obj_target)
            + ").\n\nCome back to me when it's done.";
    }
    quest_start(_qid);
    ledger_add(id, "quest", "They asked something of you first: \"" + _qd.name + "\".");
    return npc_display_name(id) + " asks: " + _qd.objective
        + "\n\n(\"" + _qd.name + "\" - tracked in your Journal. Return here when it's done.)";
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
        _o.betrayed   = true;   // permanent mark - the ending's absence beat reads this
        ach_unlock("ACH_REMEMBERS");   // achievement hook (08-05 wiring): a keeper betrayed
        quest_reset_gate("gate_" + _ids[_i] + "_companion");
        quest_reset_gate("gate_" + _ids[_i] + "_lover");
        var _lines = affinity_betrayal_lines(_ids[_i]);
        ledger_add(_ids[_i], "milestone", _lines.ledger);
        journal_badge_npc(_ids[_i]);
        audio_play_sound(snd_betrayal, 1, false);   // reversed sting + cold heartbeat thud (replaced the music box 07-14)
        if (variable_global_exists("pet_find_notice")) {
            global.pet_find_notice = (global.pet_find_notice != "") ? (global.pet_find_notice + "   " + _lines.notice) : _lines.notice;
        }
    }
}

// ---------------------------------------------------------------------------
// ENDING FAREWELLS (WIN_STATE_SPEC.md). One line per NPC, two voice bands:
// tier 1-2 (warm but at arm's length) vs tier 3-4 (intimate). Tier 0 and
// betrayed NPCs don't speak - their absence is its own beat.
// ---------------------------------------------------------------------------
function ending_farewell_line(id, tier) {
    var _hi = (tier >= 3);
    switch (id) {
        case "dorn":  return _hi
            ? "\"Whatever you carried down there, you carried us with it. The forge stays warm for you.\""
            : "Dorn folds his arms. \"Held together, did you. Good iron.\"";
        case "sable": return _hi
            ? "\"Come by the cauldron tonight. The good bottle - the label I don't show anyone.\""
            : "\"So the dark blinks first. I'd have bet on you. I did bet on you.\"";
        case "maren": return _hi
            ? "\"I set a piece of myself in you long ago. It held. It always held.\""
            : "Maren nods once. \"The runes read true. So did you.\"";
        case "vex":   return _hi
            ? "Vex looks away first. \"Best student I ever had. Don't make me say it twice.\""
            : "\"Hmph. Guess the drills stuck.\"";
        case "petra": return _hi
            ? "\"Every coin I counted, I was counting on you coming back. Welcome home.\""
            : "\"Free stock for the one who saved the town. Within reason.\"";
        case "vael":  return _hi
            ? "\"You are the finest work this town ever produced. I merely framed you.\""
            : "\"How dreadfully heroic. Whatever will I brood about now?\"";
        case "bairc": return _hi
            ? "\"Every story in this hall ends at the same table. Yours starts there tonight. Drinks are mine.\""
            : "\"There's a page in the codex I kept blank. It gets your name.\"";
    }
    return "";
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

// The NPC's ACTIVE gate quest ({def, state}) or undefined - the NPC-screen bond
// header shows its progress inline (C7, M-approved 07-09) so the player sees the
// favor they owe without opening the board or Journal.
function npc_active_gate_quest(npc_id) {
    var _c = quest_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        var _d = _c[_i];
        if (!quest_is_gate(_d) || _d.npc != npc_id) continue;
        var _s = quest_state(_d.id);
        if (_s != undefined && _s.status == "active") return { def: _d, state: _s };
    }
    return undefined;
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
                // Gate favors complete AT the NPC (M 07-28 all-in-one rework);
                // ordinary board requests still report to the board.
                var _qmsg = quest_is_gate(_d)
                    ? ("Favor complete: " + _d.name + " - return to " + npc_display_name(_d.npc) + ".")
                    : ("Request complete: " + _d.name + " - report to the tavern board.");
                global.pet_find_notice = (global.pet_find_notice != "")
                    ? (global.pet_find_notice + "   " + _qmsg) : _qmsg;
                audio_play_sound(snd_quest_ready, 1, false);   // soft parchment-and-bell ping (turn-in fanfare stays the board's)
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
        // Achievement hook (08-05 wiring): the LOVER gate is the questline's
        // final rung - crossing it is a keeper's word kept, start to finish.
        if (variable_struct_exists(_d, "gate_tier") && _d.gate_tier >= 4) ach_unlock("ACH_KEPT_WORD");
        return "";
    }
    // Achievement counter (08-05 wiring): an ordinary board request turned in
    // (ACH_BOARD_25 via sync).
    ach_counters_init();
    global.ach_counters.board_done += 1;
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
        var _ct = variable_struct_exists(_r, "chit_tier") ? clamp(_r.chit_tier, 0, 4) : 0;
        reforge_ingot_grant(_ct, _r.chit);
        tutorial_try_show("dorn_reforge");   // first ingot earned - explain reforge (M 07-17)
        array_push(_parts, string(_r.chit) + " " + item_rarity_name(_ct) + " Reforge Ingot" + ((_r.chit == 1) ? "" : "s") + " (Dorn honors these)");
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

// Clear badges whose entry no longer appears in any viewable list. Badges clear
// on VIEW (cursor on the row), so a badge on a quest that expired off the
// board/journal - or an NPC not yet in the met list - could never clear and left
// the J chip flashing with nothing visibly new. Run when the journal closes:
// anything still listed keeps its badge until its row is actually viewed.
function journal_badges_sweep_orphans() {
    var _b = journal_badges();
    var _met = journal_met_ids();
    var _nk = variable_struct_get_names(_b.npcs);
    for (var _i = 0; _i < array_length(_nk); _i++) {
        if (!variable_struct_get(_b.npcs, _nk[_i])) continue;
        var _found = false;
        for (var _j = 0; _j < array_length(_met); _j++) if (_met[_j] == _nk[_i]) { _found = true; break; }
        if (!_found) variable_struct_set(_b.npcs, _nk[_i], false);
    }
    var _rows = journal_quest_rows();
    var _qk = variable_struct_get_names(_b.quests);
    for (var _i = 0; _i < array_length(_qk); _i++) {
        if (!variable_struct_get(_b.quests, _qk[_i])) continue;
        var _found = false;
        for (var _j = 0; _j < array_length(_rows); _j++) if (_rows[_j] == _qk[_i]) { _found = true; break; }
        if (!_found) variable_struct_set(_b.quests, _qk[_i], false);
    }
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

// =============================================================================
// TIERED REFORGE INGOTS (M 07-17). global.reforge_ingots[0..4] = counts by rarity
// tier (0 Common .. 4 Legendary), replacing the old single global.reforge_chits.
// MECHANIC "tier-or-higher": an item of rarity N is reforged by spending the
// LOWEST-tier ingot whose tier >= N (higher ingots are universal; a lower ingot
// can't touch better gear). Board rewards drop ingots scaled to the request's
// Awakening. Old reforge_chits are intentionally NOT migrated (M: dropped).
// =============================================================================
function reforge_ingots_ensure() {
    if (!variable_global_exists("reforge_ingots") || !is_array(global.reforge_ingots)
        || array_length(global.reforge_ingots) != 5) {
        global.reforge_ingots = [0, 0, 0, 0, 0];
    }
    return global.reforge_ingots;
}
function reforge_ingot_grant(_tier, _n) {
    reforge_ingots_ensure();
    global.reforge_ingots[clamp(_tier, 0, 4)] += _n;
}
function reforge_ingot_total() {
    reforge_ingots_ensure();
    var _t = 0;
    for (var _i = 0; _i < 5; _i++) _t += global.reforge_ingots[_i];
    return _t;
}
// Lowest tier index with a spendable ingot for an item of the given rarity
// (tier >= rarity), or -1 if none qualifies.
function reforge_ingot_tier_for(_rarity) {
    reforge_ingots_ensure();
    for (var _i = clamp(_rarity, 0, 4); _i < 5; _i++) {
        if (global.reforge_ingots[_i] > 0) return _i;
    }
    return -1;
}
// Spend the lowest qualifying ingot; returns the tier spent, or -1 if none.
function reforge_ingot_spend(_rarity) {
    var _t = reforge_ingot_tier_for(_rarity);
    if (_t >= 0) global.reforge_ingots[_t] -= 1;
    return _t;
}
// Lowest ingot tier (0-3) holding 3 or more - the tier a FUSE would combine
// (3 -> 1 of the next tier up; Legendary ingots don't fuse). -1 = nothing to
// fuse. (M 07-29: once rerolling commons stops being worth the time, low-tier
// ingots' real role is fusing upward.)
function reforge_combine_tier() {
    reforge_ingots_ensure();
    for (var _t = 0; _t <= 3; _t++) if (global.reforge_ingots[_t] >= 3) return _t;
    return -1;
}
// Tier icon sprite (direct refs so the compiler keeps them - no string-strip risk).
function reforge_ingot_sprite(_tier) {
    switch (clamp(_tier, 0, 4)) {
        case 0: return spr_icon_reforge_ingot_common;
        case 1: return spr_icon_reforge_ingot_uncommon;
        case 2: return spr_icon_reforge_ingot_rare;
        case 3: return spr_icon_reforge_ingot_epic;
        case 4: return spr_icon_reforge_ingot_legendary;
    }
    return -1;
}
// Draw the held ingots as a compact "icon xN" stack (M 07-17: quick-glance hoard at
// Dorn and in the stash). Only tiers you hold show. Returns the drawn width so the
// caller can center/place it. Caller sets font; this sets its own colors.
function ui_draw_reforge_ingot_stack(_x, _y, _icon_sz) {
    reforge_ingots_ensure();
    var _cx = _x;
    draw_set_valign(fa_middle);
    draw_set_halign(fa_left);
    for (var _t = 0; _t < 5; _t++) {
        var _n = global.reforge_ingots[_t];
        if (_n <= 0) continue;
        var _spr = reforge_ingot_sprite(_t);
        if (_spr >= 0) draw_sprite_stretched(_spr, 0, _cx, _y - _icon_sz / 2, _icon_sz, _icon_sz);
        _cx += _icon_sz + 3;
        draw_set_color(item_rarity_color(_t));
        var _lbl = "x" + string(_n);
        draw_text(_cx, _y, _lbl);
        _cx += string_width(_lbl) + 18;
    }
    draw_set_valign(fa_top);
    return _cx - _x;
}

function board_requests_ensure() {
    if (!variable_global_exists("board_requests") || !is_array(global.board_requests)) global.board_requests = [];
    if (!variable_global_exists("board_seq")      || !is_real(global.board_seq))       global.board_seq = 0;
    reforge_ingots_ensure();
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
    var _gold = 0, _dust = 0, _chit = 0, _ctier = -1;
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
    // Ingot tier scales with the request's Awakening: early requests give low-tier
    // ingots, and tier-or-higher makes the high ones from harder content universal.
    if (_chit > 0) _ctier = clamp(a, 0, 4);
    return {
        id:"", kind:"board", template:t, urgent:urgent, special:false, expires:(urgent ? 1 : 3),
        npc:_npc, name:_name, obj_type:_obj_type, obj_target:_obj_target, obj_param:_obj_param,
        reward:{ gold:_gold, feed:"", feed_n:0, rune_id:"", rune_tier:0, dust:_dust, item:_item, chit:_chit, chit_tier:_ctier },
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
// kind "learn" = ability/trait unlocks (Sparring Yard rank-1 perk applies).
// Drill Regimen (rank 2): the FIRST purchase each visit is 25% off - the
// discount shows on every price tag until a buy consumes vex_visit_first
// (armed on trainer open in the hub Step, spent via vex_first_buy_consume).
function vex_price(g, kind = "") {
    var _m = affinity_discount_mult("vex");
    if (kind == "learn" && npc_rank("vex") >= 1) _m *= 0.90;
    if (npc_rank("vex") >= 2 && variable_global_exists("vex_visit_first") && global.vex_visit_first) _m *= 0.75;
    return floor(g * _m);
}
function vex_first_buy_consume() {
    if (variable_global_exists("vex_visit_first") && global.vex_visit_first) global.vex_visit_first = false;
}

// Vex permanent-stat pricing (M 08-11): the flat 200g + 1 Rare stacked too
// easily late-game. Gold now follows a gentle quadratic on stats already
// bought (200, 268, 344, 428, 520, 620, 728, ...) and the trade escalates:
// Rare for the first 6 buys, Epic for the next 6, Legendary from the 13th.
// Existing saves start the counter at 0 (perm bonuses also come from level-up
// allocation, so the count can't be reconstructed). Numbers await M's veto.
function vex_stat_buys()      { return variable_global_exists("vex_stat_buys") ? global.vex_stat_buys : 0; }
function vex_stat_base_cost() { var _n = vex_stat_buys(); return 200 + 60 * _n + 8 * _n * _n; }
function vex_stat_rarity_req(){ var _n = vex_stat_buys(); return (_n < 6) ? 2 : ((_n < 12) ? 3 : 4); }
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

// SECOND LEDGER LINE (M-locked 08-15, Petra station rank 1): orders live in the
// global.petra_orders ARRAY now - capacity 1, or 2 at rank 1+. Legacy saves
// carry a single global.petra_order struct; petra_orders_ensure() absorbs it,
// idempotently, before any reader touches the array.
function petra_orders_ensure() {
    if (!variable_global_exists("petra_orders") || !is_array(global.petra_orders)) {
        global.petra_orders = [];
    }
    if (variable_global_exists("petra_order") && is_struct(global.petra_order)) {
        array_push(global.petra_orders, global.petra_order);
        global.petra_order = undefined;
    }
}
function petra_order_capacity() { return (npc_rank("petra") >= 1) ? 2 : 1; }
function petra_order_can_place() {
    petra_orders_ensure();
    return array_length(global.petra_orders) < petra_order_capacity();
}
function petra_order_active() {
    petra_orders_ensure();
    return array_length(global.petra_orders) > 0;
}

// --- Affinity-derived perks (read the thin-affinity API) -------------------
// Friend (>=2): -10% on Petra gold costs (trade fee + her consumable shop).
function petra_gold_mult()          { return affinity_at_least("petra", 2) ? 0.90 : 1.0; }
// Companion (>=3): faster delivery - shave 1 floor off the cost (min 1).
function petra_delivery_reduction() {
    // Companion bond shaves 1 floor; Favored Client (rank 2, M-locked 08-15)
    // shaves another.
    return (affinity_at_least("petra", 3) ? 1 : 0) + ((npc_rank("petra") >= 2) ? 1 : 0);
}
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
    var _pb_t = weapon_damage_bias_t(_item);
    if (_ac > 0) apply_affixes_to_item(_item, roll_affixes(rarity, _ac, item_affix_exclusions(_item), _item.slot, _item.base_name, _pb_t));
    var _be = (variable_struct_exists(_item, "elem_affix") && _item.elem_affix != undefined);
    if ((_item.slot == "weapon" || _item.slot == "ranged_weapon") && !_be) {
        apply_elemental_affix_to_item(_item, roll_elemental_affix(rarity, _pb_t));
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
    // Favored Client (rank 2, M-locked 08-15): her caravan delivers FINISHED
    // work - the traded-up piece re-stamps at quality 75-95.
    if (npc_rank("petra") >= 2) item_quality_stamp(_best, 64, 84);   // 08-18 quality nerf
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
    if (!petra_order_can_place())
        return (petra_order_capacity() > 1)
            ? "Both ledger lines are full - collect or cancel an order first."
            : "Collect your current order first.";
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

    array_push(global.petra_orders, {
        input_tier:      _rar,
        output_tier:     _rung.out_rarity,
        req_awakening:   _rung.req_awk,
        cost_floors:     max(1, _rung.cost_floors - petra_delivery_reduction()),
        progress_floors: 0,
        dust_bias:       dust_bias,
        status:          "in_progress",
    });
    affinity_add("petra", 4);   // placing an order is the deepest Petra interaction
    if (room == rm_hub || room == rm_character_select) save_game();
    return "";
}

// --- Rune blueprint orders (M 07-27, distributed rune economy) --------------
// Trade 5 mixed SAME-TIER runes + a broker fee for a blueprint order that
// delivers ONE CHOSEN rune of that tier after clearing floors. The PLANNED half
// of the leftover-rune sink (Sable's transmute is the gamble half). Shares the
// single petra_order slot with gear trades via order.kind == "rune".
function petra_rune_order_gold(tier) { return floor(80 * max(1, tier) * petra_gold_mult()); }
function petra_rune_order_floors()   { return max(1, 3 - petra_delivery_reduction()); }

// Takes the ORDER STRUCT now (two-order refactor 08-15) - callers pass the
// entry they are rendering/resolving, not a global.
function petra_order_is_rune(_o) {
    return is_struct(_o) && variable_struct_exists(_o, "kind") && _o.kind == "rune";
}

function petra_start_rune_order(indices, result_id) {
    if (!petra_order_can_place())
        return (petra_order_capacity() > 1)
            ? "Both ledger lines are full - collect or cancel an order first."
            : "Collect your current order first.";
    if (array_length(indices) != 5) return "Choose exactly 5 runes.";
    var _inv = global.rune_inventory;
    var _t = -1;
    for (var _i = 0; _i < 5; _i++) {
        var _ix = indices[_i];
        if (_ix < 0 || _ix >= array_length(_inv)) return "Invalid selection.";
        if (_t == -1) _t = _inv[_ix].tier;
        else if (_inv[_ix].tier != _t) return "All 5 runes must share a tier.";
    }
    if (rune_get(result_id) == undefined) return "Invalid blueprint.";
    var _fee = petra_rune_order_gold(_t);
    if (global.gold < _fee) return "Need " + string(_fee) + "g.";
    // Consume the 5 (high-index-first so the remaining indices stay valid) + fee.
    var _sorted = [];
    for (var _i = 0; _i < 5; _i++) array_push(_sorted, indices[_i]);
    array_sort(_sorted, false);
    for (var _i = 0; _i < 5; _i++) array_delete(_inv, _sorted[_i], 1);
    global.gold -= _fee;
    array_push(global.petra_orders, {
        kind:            "rune",
        rune_id:         result_id,
        rune_tier:       _t,
        input_tier:      _t,     // legacy readers (tier displays) stay in range
        output_tier:     _t,
        req_awakening:   0,
        cost_floors:     petra_rune_order_floors(),
        progress_floors: 0,
        dust_bias:       false,
        status:          "in_progress",
    });
    affinity_add("petra", 4);   // placing an order is the deepest Petra interaction
    if (room == rm_hub || room == rm_character_select) save_game();
    return "";
}

// Cancel by index; -1 (default) = the NEWEST order. (Two-order refactor 08-15.)
function petra_cancel_order(_idx = -1) {
    if (!petra_order_active()) return "No order to cancel.";
    if (_idx < 0) _idx = array_length(global.petra_orders) - 1;
    if (_idx >= array_length(global.petra_orders)) return "No such order.";
    var _o = global.petra_orders[_idx];
    var _band    = petra_cancel_band();
    var _recover = min(3, irandom_range(_band[0], _band[1]));
    if (petra_order_is_rune(_o)) {
        // Rune blueprint: the 5 inputs were mixed and are gone - recover random
        // runes of the same tier instead (same band as gear).
        var _rt = _o.rune_tier;
        for (var _i = 0; _i < _recover; _i++)
            array_push(global.rune_inventory, rune_make(sable_transmute_roll_id(), _rt));
        array_delete(global.petra_orders, _idx, 1);
        if (room == rm_hub || room == rm_character_select) save_game();
        return "Order cancelled. Recovered " + string(_recover) + " rune" + (_recover == 1 ? "" : "s")
            + ". (Gold not refunded.)";
    }
    var _in = _o.input_tier;
    for (var _i = 0; _i < _recover; _i++) array_push(global.equipment_stash, petra_base_item(_in));
    array_delete(global.petra_orders, _idx, 1);
    if (room == rm_hub || room == rm_character_select) save_game();
    return "Order cancelled. Recovered " + string(_recover) + " item" + (_recover == 1 ? "" : "s")
        + ". (Gold not refunded.)";
}

// Collects the FIRST READY order. (Two-order refactor 08-15.)
function petra_collect() {
    if (!petra_order_active()) return "Nothing to collect.";
    var _idx = -1;
    for (var _i = 0; _i < array_length(global.petra_orders); _i++) {
        if (global.petra_orders[_i].status == "ready") { _idx = _i; break; }
    }
    if (_idx < 0) return "Your order isn't ready yet.";
    var _o = global.petra_orders[_idx];
    if (petra_order_is_rune(_o)) {
        var _rn = rune_make(_o.rune_id, _o.rune_tier);
        array_push(global.rune_inventory, _rn);
        // ORDER REVEAL (M 07-28): the collect opens an examine popup instead of
        // the yield vanishing into a stack - captured before the order clears.
        global.petra_reveal = { is_rune: true, rune: _rn, item: undefined,
            input_tier: _o.rune_tier, input_count: 5, dust_bias: false };
        array_delete(global.petra_orders, _idx, 1);
        if (room == rm_hub || room == rm_character_select) save_game();
        return "Collected the blueprint rune: " + rune_title(_rn) + "!";
    }
    var _out  = _o.output_tier;
    var _bias = _o.dust_bias;
    var _item = petra_make_item(_out, _bias);
    array_push(global.equipment_stash, _item);
    discover_item(item_base_name(_item), _item.rarity);
    // ORDER REVEAL (M 07-28): see the rune branch above.
    global.petra_reveal = { is_rune: false, rune: undefined, item: _item,
        input_tier: _o.input_tier, input_count: 3, dust_bias: _bias };
    array_delete(global.petra_orders, _idx, 1);
    if (room == rm_hub || room == rm_character_select) save_game();
    return "Collected a " + item_rarity_name(_out) + " item: " + _item.name + "!";
}

// One-line status for ONE order struct (drawn per ledger card / joined below).
function petra_order_line(_o) {
    if (!is_struct(_o)) return "";
    if (petra_order_is_rune(_o)) {
        var _bp = rune_get(_o.rune_id);
        var _bpn = ((_bp != undefined) ? _bp.name : _o.rune_id) + " " + rune_tier_roman(_o.rune_tier);
        if (_o.status == "ready") return "READY - the " + _bpn + " blueprint rune awaits collection.";
        return "Blueprint: " + _bpn + "    " + string(_o.progress_floors) + " / " + string(_o.cost_floors) + " floors";
    }
    if (_o.status == "ready") return "READY - a " + item_rarity_name(_o.output_tier) + " awaits collection.";
    var _awk = (_o.req_awakening > 0) ? ("   (floors must be A" + string(_o.req_awakening) + "+)") : "";
    return item_rarity_name(_o.input_tier) + " -> " + item_rarity_name(_o.output_tier)
        + "    " + string(_o.progress_floors) + " / " + string(_o.cost_floors) + " floors" + _awk
        + (_o.dust_bias ? "    [roll-biased]" : "");
}
// One-line order status for the UI (all lines joined).
function petra_order_status_text() {
    if (!petra_order_active()) return "No active order.";
    var _t = "";
    for (var _i = 0; _i < array_length(global.petra_orders); _i++) {
        _t += ((_i > 0) ? "    |    " : "") + petra_order_line(global.petra_orders[_i]);
    }
    return _t;
}

// SHARED PRIMITIVE: credit one cleared floor toward time-gated systems. Called once
// per boss-clear (from obj_combat_controller) with the run's Awakening. Banks
// immediately so extract AND death keep already-cleared floors. Phase 2 pets hook here too.
function floor_clear_credit(awk) {
    // Two-order refactor (08-15): EVERY in-progress order banks the clear
    // independently (each carries its own Awakening gate).
    if (petra_order_active()) {
        for (var _poi = 0; _poi < array_length(global.petra_orders); _poi++) {
            var _po = global.petra_orders[_poi];
            if (_po.status != "in_progress") continue;
            if (awk >= _po.req_awakening) {
                _po.progress_floors += 1;
                if (_po.progress_floors >= _po.cost_floors) _po.status = "ready";
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
    // Doubled 07-08 (hunger design): the bar filled far too fast - M sat at max
    // feed long before Awakening 5 was in reach.
    switch (stage) {
        case PET_STAGE_BABY:       return 8;
        case PET_STAGE_ADOLESCENT: return 12;
        case PET_STAGE_YOUNGADULT: return 18;
        case PET_STAGE_ADULT:      return 24;   // -> Awakened (crossing further gated, see pet_awaken_gate_ok)
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
        case "guarded":    return "Half strike damage; 25% chance to intercept part of blows aimed at you - the pet takes that damage (at 0 HP it is injured and benched for the run). Press G in combat to call it off / send it back in.";
        case "assist":     return "Strikes YOUR target and leaves it Exposed (Pack Tactics).";
        case "balanced":   return "Heals you when hurt, wards you when healthy.";
        case "mender":     return "Always tends your wounds first.";
        case "warder":     return "Always raises a ward.";
        case "cleanser":   return "Strips your newest affliction before anything else.";
    }
    return "";
}

// --- In-combat guard toggle (M 07-09, rides #20) -----------------------------
// A GUARDED-stance Combatant can be CALLED OFF mid-fight (G in combat) so its
// intercepts - which now cost its HP pool - don't grind it down every combat.
// Lazy flag on the pet; cleared at run end (pet_on_run_end), so the Gate stance
// choice stays the source of truth between runs. Its own strikes stay halved
// while guarded regardless - this only gates the intercept roll.
function pet_guard_off(pet) {
    if (!is_struct(pet)) return false;
    if (!variable_struct_exists(pet, "guard_off")) pet.guard_off = false;
    return pet.guard_off;
}
// Flip the flag; returns the NEW state (true = called off).
function pet_guard_toggle(pet) {
    if (!is_struct(pet)) return false;
    pet.guard_off = !pet_guard_off(pet);
    return pet.guard_off;
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

// --- HUNGER (M-approved design 2026-07-08): a 0-100 meter every living pet must
// keep filled. Food refills it (feeding = upkeep, not just growth); every run
// drains it (active companion -20, stabled -10). States: WELL-FED (70+) = run
// growth banks; PECKISH (30-69) = growth won't bank; HUNGRY (<30) = the pet acts
// at -25% and gains no bond; STARVING (0) = benched entirely until fed. Ending a
// run with a full belly (100) earns +1 bonus bond. Lazy default 100 = pets from
// older saves load fed (no migration). --------------------------------------
function pet_hunger(pet) {
    if (!is_struct(pet)) return 100;
    if (!variable_struct_exists(pet, "hunger")) pet.hunger = 100;
    return pet.hunger;
}
function pet_hunger_state(pet) {
    var _h = pet_hunger(pet);
    if (_h <= 0)  return "starving";
    if (_h < 30)  return "hungry";
    if (_h < 70)  return "peckish";
    return "fed";
}
function pet_hunger_state_label(pet) {
    switch (pet_hunger_state(pet)) {
        case "starving": return "STARVING";
        case "hungry":   return "Hungry";
        case "peckish":  return "Peckish";
    }
    return "Well-fed";
}
// Effectiveness multiplier from hunger. 0 = benched: fold into the injury-mult
// checks so a starving pet reuses the existing tier-2-injury benching paths.
function pet_hunger_mult(pet) {
    switch (pet_hunger_state(pet)) {
        case "starving": return 0;
        case "hungry":   return 0.75;
    }
    return 1.0;
}
// Run-end upkeep for the WHOLE roster: the active companion works up an appetite
// (-20), stabled pets graze lighter (-10). Called from end_run AFTER
// pet_run_complete, so the well-fed growth gate and the full-belly bond reward
// both read PRE-drain hunger.
function pet_hunger_run_tick() {
    var _r = pet_roster();
    var _act = pet_active();
    for (var _i = 0; _i < array_length(_r); _i++) {
        var _p = _r[_i];
        if (!is_struct(_p) || _p.is_egg) continue;
        pet_hunger(_p);   // ensure the field exists
        // Base drain RAISED 20/10 -> 28/14 (M-locked 08-15) so Bairc's
        // Warm Pens rank perk (30% slower, whole roster) feels real.
        var _drain = (_p == _act) ? 28 : 14;
        if (npc_rank("bairc") >= 1) _drain = round(_drain * 0.70);
        // Grateful Belly quirk (08-01, pillar C): hunger drains 25% slower.
        if (pet_quirk_has(_p, "grateful_belly")) _drain = round(_drain * 0.75);
        // Green Memory (witchwood_fawn innate, 08-06): while ACTIVE its hunger
        // decays 20% slower - the canopy remembers to feed its own.
        if (_p == _act && pet_active_innate("hunger_slow") > 0) {
            _drain = round(_drain * (1 - pet_active_innate("hunger_slow") / 100));
        }
        _p.hunger = max(0, _p.hunger - _drain);
    }
}

// --- TREATS (07-08): bond-only delicacies, separate from food. Capped at 2 per
// run (global.pet_treats_run, reset in end_run) so affection is earned at the
// margin, never bulk-bought. Ride the feed pouch/shop plumbing (bond field > 0
// marks a treat; pet_feed_apply branches on it).
// FAVORED treats (M-locked 08-17): six delicacies each favored by a handful of
// species. A favored treat gives +2 bond instead of +1 (pet_treat_bond_for). Petra
// stocks the two generic treats always, plus every favored treat one of your LIVING
// pets loves (pet_feed_shop_list). The Bairc feed rows tag them with a heart.
function pet_treat_catalog() {
    return [
        { id:"treat_honey",  name:"Honeycomb Treat", growth:0, bond:1, gold:45, perk:"none", favored:[], blurb:"sticky, sweet, utterly beloved (+1 bond, 2 treats per run)" },
        { id:"treat_marrow", name:"Candied Marrow",  growth:0, bond:1, gold:45, perk:"none", favored:[], blurb:"a butcher's secret delicacy (+1 bond, 2 treats per run)" },
        { id:"treat_ember_nut",   name:"Ember Chestnut",   growth:0, bond:1, gold:60, perk:"none",
          favored:["ember_ram", "pyre_bison", "cinder_newt", "magma_leech", "wyrmling", "stormkirin"],
          blurb:"roasted in a forge coal until it cracks - the fire-blooded go wild for it (+2 bond if favored)" },
        { id:"treat_grave_lily",  name:"Grave-Lily Sugar", growth:0, bond:1, gold:60, perk:"none",
          favored:["bone_stag", "bonehound", "gravefox", "cairn_bear", "gravemask", "barrow_mole", "vaultling", "crypt_bat"],
          blurb:"pale petals candied in tomb-honey - the grave-born lick the paper clean (+2 bond if favored)" },
        { id:"treat_moon_moth",   name:"Moonpetal Wafer",  growth:0, bond:1, gold:60, perk:"none",
          favored:["luna_moth", "nightowl", "wispfox", "tallow_moth", "sum_moth", "flicker_finch"],
          blurb:"a wafer that only shows its shimmer by moonlight - night-fliers adore it (+2 bond if favored)" },
        { id:"treat_brine_jerky", name:"Brine Jerky",      growth:0, bond:1, gold:60, perk:"none",
          favored:["gloomtoad", "sluice_otter", "glass_eel", "drowned_lamp", "paleswimmer", "leviathan_calf", "chorister_fry", "mire_heron"],
          blurb:"salt-cured eel from the flooded galleries - the wet-born gulp it whole (+2 bond if favored)" },
        { id:"treat_frost_root",  name:"Frost-Root Chew",  growth:0, bond:1, gold:60, perk:"none",
          favored:["saber_hound", "hollow_pup", "frostmarten", "snowmaw", "permafrost_toad", "icewing_skua", "salt_hare", "wing_hare"],
          blurb:"a hard tundra root that numbs the gums - the cold-country beasts chew for hours (+2 bond if favored)" },
        { id:"treat_iron_grub",   name:"Iron Grub",        growth:0, bond:1, gold:60, perk:"none",
          favored:["rust_vole", "gravel_tick", "pressure_snail", "bristleback", "honeymaw", "bark_hound", "canopy_shrew", "tallykeep"],
          blurb:"a fat grub that lives in old ore - crunchy, metallic, irresistible to the diggers and gnawers (+2 bond if favored)" },
    ];
}
// True if this treat is one of the pet's FAVORED delicacies.
function pet_treat_is_favored(treat, pet) {
    if (!is_struct(treat) || !is_struct(pet) || !variable_struct_exists(treat, "favored")) return false;
    for (var _i = 0; _i < array_length(treat.favored); _i++) if (treat.favored[_i] == pet.species) return true;
    return false;
}
// Bond a treat grants THIS pet (+2 favored, else the treat's base +1).
function pet_treat_bond_for(treat, pet) {
    if (!is_struct(treat) || !variable_struct_exists(treat, "bond")) return 0;
    return pet_treat_is_favored(treat, pet) ? (treat.bond + 1) : treat.bond;
}
// Names of the favored treats for a species (heart tag on the species line / codex).
function pet_treat_favorites_text(species_id) {
    var _t = pet_treat_catalog(), _out = "";
    for (var _i = 0; _i < array_length(_t); _i++) {
        if (!variable_struct_exists(_t[_i], "favored")) continue;
        for (var _j = 0; _j < array_length(_t[_i].favored); _j++) {
            if (_t[_i].favored[_j] == species_id) { _out += ((_out != "") ? ", " : "") + _t[_i].name; break; }
        }
    }
    return _out;
}
function pet_treats_left() {
    if (!variable_global_exists("pet_treats_run")) global.pet_treats_run = 0;
    // Beast-Whisperer origin (08-11): 3 treats per run instead of 2.
    var _cap = origin_is("whisperer") ? 3 : 2;
    return max(0, _cap - global.pet_treats_run);
}

// --- FEED (design §12): feed is now BOUGHT AS ITEMS from Petra (gold) into a feed pouch,
// then APPLIED to a pet at Bairc (no gold there). 3 basic tiers are always in Petra's stock;
// one PREMIUM feed rotates each run (rolled in restock_shops) and carries a small perk. ---
// perk: "none" | "mend" (heals 1 injury tier) | "purge" (cures a pushing corruption).
// Repriced 07-08 with the hunger system: higher tiers are now slightly MORE
// gold-efficient per growth (cheap spam was strictly optimal before).
function pet_feed_catalog() {   // the 3 always-stocked basics
    return [
        { id:"scraps", name:"Table Scraps",     growth:1, gold:14, perk:"none", blurb:"barely a meal, but it counts" },
        { id:"forage", name:"Forager's Bundle", growth:2, gold:26, perk:"none", blurb:"roots, grubs and dried meat" },
        { id:"prime",  name:"Prime Cut",        growth:4, gold:48, perk:"none", blurb:"the good stuff - it eats well today" },
    ];
}
// Rotating premium feeds - one is stocked per run (global.petra_feed_premium id).
function pet_feed_premium_pool() {
    return [
        { id:"mending_mash", name:"Mending Mash",  growth:3, gold:95,  perk:"mend",  blurb:"knits a wounded creature back together (heals one injury)" },
        { id:"purgeroot",    name:"Purgeroot Loaf", growth:3, gold:110, perk:"purge", blurb:"bitter root that quiets a corrupting hunger (cures a CORRUPTED pet)" },
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
        // 07-31 expansion slate (M-approved) - one favorite per new species.
        { id:"pref_duskraven",        species:"duskraven",        name:"Gallowseed Handful",  growth:7, gold:100, perk:"none", blurb:"seeds from the hanging tree - it caws thanks in borrowed voices" },
        { id:"pref_pale_widow",       species:"pale_widow",       name:"Silk-Wrapped Fly",    growth:7, gold:100, perk:"none", blurb:"a delicacy bound in its own thread - it unwraps it slowly" },
        { id:"pref_shellback",        species:"shellback",        name:"Cave-Moss Wedge",     growth:7, gold:100, perk:"none", blurb:"slow food for a slow eater - it naps mid-bite" },
        { id:"pref_thorn_boar",       species:"thorn_boar",       name:"Bramble Truffle",     growth:7, gold:100, perk:"none", blurb:"dug from under thorn roots - it eats the spikes first" },
        { id:"pref_glimmer_slime",    species:"glimmer_slime",    name:"Cracked Geode",       growth:7, gold:100, perk:"none", blurb:"it dissolves the stone and keeps the sparkle" },
        { id:"pref_sporeling",        species:"sporeling",        name:"Rotwood Chips",       growth:7, gold:100, perk:"none", blurb:"damp and half-mulched - it burrows in before eating" },
        { id:"pref_voidkit",          species:"voidkit",          name:"Starlit Minnow",      growth:7, gold:100, perk:"none", blurb:"a fish that never saw the sun - it bats it around first" },
        { id:"pref_ironshell_beetle", species:"ironshell_beetle", name:"Rust Flakes",         growth:7, gold:100, perk:"none", blurb:"scraped from old armor - it eats its greens" },
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
    var _i = asset_get_index("spr_pet_feed_" + id);
    // 08-17 favored treats ship without bespoke icons yet (icon batch pending M's
    // approval) - borrow the honeycomb treat art rather than draw an empty row.
    if (_i < 0 && string_pos("treat_", id) == 1) _i = asset_get_index("spr_pet_feed_treat_honey");
    // 08-18 icon audit: eight species-preferred foods still have no bespoke icon and
    // drew an EMPTY slot. Borrow the closest shipped food art by what the food IS
    // (seeds -> forage, fly -> mirefly clutch, ore -> slagheart, fish -> brine eel...)
    // until their own icons are generated + approved.
    if (_i < 0 && string_pos("pref_", id) == 1) {
        var _fb = "";
        switch (id) {
            case "pref_duskraven":        _fb = "spr_pet_feed_forage";            break;   // Gallowseed Handful
            case "pref_pale_widow":       _fb = "spr_pet_feed_pref_gloomtoad";    break;   // Silk-Wrapped Fly
            case "pref_shellback":        _fb = "spr_pet_feed_pref_bone_stag";    break;   // Cave-Moss Wedge
            case "pref_thorn_boar":       _fb = "spr_pet_feed_treat_ember_nut";   break;   // Bramble Truffle
            case "pref_glimmer_slime":    _fb = "spr_pet_feed_pref_magma_leech";  break;   // Cracked Geode
            case "pref_sporeling":        _fb = "spr_pet_feed_pref_golemite";     break;   // Rotwood Chips
            case "pref_voidkit":          _fb = "spr_pet_feed_treat_brine_jerky"; break;   // Starlit Minnow
            case "pref_ironshell_beetle": _fb = "spr_pet_feed_pref_gaolwyrm";     break;   // Rust Flakes
            default:                      _fb = "spr_pet_feed_prime";             break;
        }
        _i = asset_get_index(_fb);
    }
    return _i;
}

// Resolve any feed def by id (basics + full premium pool + species-preferred + treats).
function pet_feed_get(id) {
    var _b = pet_feed_catalog();
    for (var _i = 0; _i < array_length(_b); _i++) if (_b[_i].id == id) return _b[_i];
    var _p = pet_feed_premium_pool();
    for (var _j = 0; _j < array_length(_p); _j++) if (_p[_j].id == id) return _p[_j];
    var _pf = pet_feed_preferred_catalog();
    for (var _k = 0; _k < array_length(_pf); _k++) if (_pf[_k].id == id) return _pf[_k];
    var _tr = pet_treat_catalog();
    for (var _t = 0; _t < array_length(_tr); _t++) if (_tr[_t].id == id) return _tr[_t];
    return undefined;
}
// The feeds Petra sells right now: 3 basics + the current rotating premium + every
// DISCOVERED species favorite whose species still has a living pet in the roster.
// (Petra's buy list is windowed, so extra rows scroll rather than overflow.)
function pet_feed_shop_list() {
    var _list = pet_feed_catalog();
    array_push(_list, pet_feed_current_premium());
    // Treats (07-08): the two generic ones always stocked, bond-only, 2 usable per
    // run. FAVORED treats (08-17) are stocked only while a LIVING pet of a species
    // that loves them is in the roster - Petra shelves what your creatures want.
    var _tcat = pet_treat_catalog();
    var _tr_roster = pet_roster();
    for (var _tc = 0; _tc < array_length(_tcat); _tc++) {
        var _tdef = _tcat[_tc];
        if (!variable_struct_exists(_tdef, "favored") || array_length(_tdef.favored) == 0) { array_push(_list, _tdef); continue; }
        var _t_own = false;
        for (var _tj = 0; _tj < array_length(_tr_roster) && !_t_own; _tj++) {
            var _tp = _tr_roster[_tj];
            if (is_struct(_tp) && !_tp.is_egg && pet_treat_is_favored(_tdef, _tp)) _t_own = true;
        }
        if (_t_own) array_push(_list, _tdef);
    }
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
    var _trs = pet_treat_catalog();   // a favored treat bought before its pet left the roster
    for (var _ti = 0; _ti < array_length(_trs); _ti++) array_push(_pool, _trs[_ti]);
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
// The garden BLESSING (08-01, pillar A) boosts every feed: +1%/2 residents, cap +10%.
function pet_feed_effective_growth(pet, f) {
    return max(1, round(f.growth * pet_feed_crowd_mult(pet) * (1 + bairc_garden_blessing_pct() / 100)));
}

// Apply an owned feed (by id) to a pet - spends one from the pouch (no gold). Fills growth
// toward (clamped at) the next-stage threshold; feed makes a pet READY but never crosses on
// its own. Premium perks fire here; crowding (soft cap above) shrinks the growth granted.
// Returns "" on success, else an error message.
function pet_feed_apply(pet, feed_id) {
    if (!is_struct(pet) || pet.is_egg)   return "An egg can't be fed - hatch it first.";
    var _f = pet_feed_get(feed_id);
    if (_f == undefined)                  return "";
    if (pet_feed_pouch_count(feed_id) <= 0) return "You have no " + _f.name + " - buy some from Petra.";

    // TREATS (07-08): bond only, 2 per run - affection can't be bulk-bought.
    if (variable_struct_exists(_f, "bond") && _f.bond > 0) {
        if (pet_treats_left() <= 0) return "No more treats this run - " + pet.name + " has been spoiled enough.";
        variable_struct_set(pet_feed_pouch(), feed_id, pet_feed_pouch_count(feed_id) - 1);
        global.pet_treats_run = (variable_global_exists("pet_treats_run") ? global.pet_treats_run : 0) + 1;
        var _tmsg = pet_bond_gain(pet, pet_treat_bond_for(_f, pet));   // favored = +2 (08-17)
        if (pet_treat_is_favored(_f, pet)) _tmsg = pet.name + " ADORES the " + _f.name + "!" + ((_tmsg != "") ? ("  " + _tmsg) : "");
        if (_tmsg != "" && variable_global_exists("pet_find_notice")) {
            global.pet_find_notice = (global.pet_find_notice != "")
                ? (global.pet_find_notice + "   " + _tmsg) : _tmsg;
        }
        return "";
    }

    // Species favorites are exactly that - no other creature will touch them.
    if (variable_struct_exists(_f, "species") && _f.species != pet.species)
        return "Only a " + pet_species_get(_f.species).name + " will eat that.";

    // FOOD = upkeep first, growth second (hunger design 07-08). A pet with a full
    // growth bar - or fully grown - still eats while its belly isn't full; only a
    // WELL-FED pet with nothing left to grow refuses the meal.
    var _grow_ok = (pet.stage < pet_max_stage()) && !pet_growth_ready(pet);
    var _hungry  = (pet_hunger(pet) < 100);
    var _hurt    = (pet_hp(pet) < pet_max_hp(pet));   // #20: a wounded pet always eats
    if (!_grow_ok && !_hungry && !_hurt) {
        if (pet.stage >= pet_max_stage()) return pet.name + " is fully grown and well-fed.";
        if (pet.stage == PET_STAGE_ADULT)
            return pet.name + " is well-fed and its growth is FULL - to Awaken it, " + pet_awaken_requirements_text() + ".";
        return pet.name + " is well-fed and its growth is FULL - complete a run with it active to evolve.";
    }
    variable_struct_set(pet_feed_pouch(), feed_id, pet_feed_pouch_count(feed_id) - 1);
    // Grateful Belly memory (08-01, pillar C): a STARVING creature remembers who
    // fed it - three such meals earn the quirk. Read pre-meal, before the restore.
    if (pet_hunger_state(pet) == "starving" && pet_mem_bump(pet, "mem_starve_feeds") >= 3) {
        var _gb_msg = pet_quirk_add(pet, "grateful_belly", "", "was fed three times at the edge of starving");
        if (_gb_msg != "" && variable_global_exists("pet_find_notice")) {
            global.pet_find_notice = (global.pet_find_notice != "")
                ? (global.pet_find_notice + "   " + _gb_msg) : _gb_msg;
        }
    }
    // Hunger restore scales with the meal's heft (scraps +20 ... favorites +80).
    pet_hunger(pet);
    pet.hunger = min(100, pet.hunger + 10 + _f.growth * 10);
    // A meal also nurses the HP pool back to full (#20: heals between runs + via food).
    pet_heal_full(pet);
    if (_grow_ok) {
        var _need  = pet_growth_needed(pet.stage);
        pet.growth = min(_need, pet.growth + pet_feed_effective_growth(pet, _f));
    }
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
    // HUNGER gates (07-08): read PRE-drain (pet_hunger_run_tick runs after this).
    // A hungry pet (<30) bonds with no one; a FULL belly (100) at run's end earns
    // +1 bonus bond; growth only banks while WELL-FED (70+).
    var _hstate   = pet_hunger_state(_p);
    var _bond_amt = _gain + ((pet_hunger(_p) >= 100) ? 1 : 0);
    if (_hstate == "hungry" || _hstate == "starving") _bond_amt = 0;
    // Bond banks the same raw amount (before egg boosts) and keeps rising after Adult -
    // §5 Axis 3. Milestone crossings surface on the next hub visit like evolutions do.
    var _bond_msg = (_bond_amt > 0) ? pet_bond_gain(_p, _bond_amt) : "";
    if (_bond_msg != "" && variable_global_exists("pet_find_notice")) {
        global.pet_find_notice = (global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _bond_msg) : _bond_msg;
    }
    if (_p.stage >= pet_max_stage()) return undefined;         // fully grown: bond only
    if (_hstate != "fed") {
        // Growth needs a WELL-FED companion (70+). Say so on the hub return.
        if (variable_global_exists("pet_find_notice")) {
            var _hgm = _p.name + " was too hungry to grow from this run - keep it Well-fed (70+) at Bairc.";
            global.pet_find_notice = (global.pet_find_notice != "")
                ? (global.pet_find_notice + "   " + _hgm) : _hgm;
        }
        return undefined;
    }
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
        // Journal form reveal (M 08-13): this species has now been SEEN at this
        // stage - the Creatures tab may show the form.
        if (variable_struct_exists(_p, "species")) compendium_stage_stamp(_p.species, _p.stage);
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
            audio_play_sound(snd_awakened_cross, 1, false);   // the wing moment: rising swell into one deep bell
        }
        quest_tick("pet_stage", "", _p.stage);                 // Phase 4a quest objective
        return _p;                                             // evolved this run
    }
    return undefined;
}

// Staged authored art (redesigned creature species): each species has baby, youngadult
// and adult frames (+ egg). Adolescent reuses the baby frame slightly enlarged. AWAKENED
// (08-13, DESIGN_WORLD_EXPANSION_0806.md §6) asks for its own "awakened" frame -
// escalate ONE axis, keep the silhouette - and falls back to adult art + the aura tint
// until that art lands, so the pass ships in waves exactly like pet_species_has_art().
// pet_sprite_key(pet) -> "egg" | "baby" | "youngadult" | "adult" | "awakened".
function pet_sprite_key(pet) {
    if (!is_struct(pet) || pet.is_egg) return "egg";
    if (pet.stage >= PET_STAGE_AWAKENED)   return "awakened";     // awakened (4) - art-gated
    if (pet.stage >= PET_STAGE_ADULT)      return "adult";        // adult (3)
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

// pet_sprite_fit(spr, cx, feet_y, target_h, max_w) - placement for drawing a pet
// sprite so its VISIBLE content (the sprite bbox, not the padded canvas) stands
// target_h tall, feet at feet_y, centered on cx (#16: species art carries wildly
// different canvas padding - bonehound was 20x43 art on a 144px canvas, so
// canvas-fit sites drew it at a third of a luna moth's size). max_w > 0 caps the
// visible width so wide quadrupeds can't bleed out of list boxes. Returns
// { scale, x, y } for draw_sprite_ext (x/y already account for the origin).
// Requires the true content bboxes written by tools/fix_pet_sprite_bboxes.py.
// PET_FIT_MAX_UP (M 08-18: "the image seems scaled up / zoomed in"): fitting every
// creature to the SAME height meant a 37px-tall still (the 64px FF-density species)
// drew at 4-5x while a 106px animated adult drew at 1.4x - same layout, wildly
// different pixel size. Upscale is now capped at bonehound-baby density (46px -> 150
// = 3.25x, M's reference), so low-res art draws SMALLER in the frame instead of chunky.
// Downscales are never touched; small boxes (stable rows, garden strolls) sit under
// the cap anyway.
#macro PET_FIT_MAX_UP 3.25
function pet_sprite_fit(spr, cx, feet_y, target_h, max_w = -1) {
    var _bl = sprite_get_bbox_left(spr),  _bt = sprite_get_bbox_top(spr);
    var _br = sprite_get_bbox_right(spr), _bb = sprite_get_bbox_bottom(spr);
    var _vw = max(1, _br - _bl + 1), _vh = max(1, _bb - _bt + 1);
    var _s  = target_h / _vh;
    if (max_w > 0) _s = min(_s, max_w / _vw);
    _s = min(_s, PET_FIT_MAX_UP);
    var _ox = sprite_get_xoffset(spr), _oy = sprite_get_yoffset(spr);
    return {
        scale: _s,
        x: cx     - ((_bl + _br + 1) * 0.5 - _ox) * _s,
        y: feet_y - ((_bb + 1) - _oy) * _s,
    };
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
    if (_key == "awakened")        _fallbacks = ["adult", "youngadult", "baby"];   // §6.2: mandatory fallback
    else if (_key == "adult")      _fallbacks = ["youngadult", "baby"];
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
    // Default 120 ms/frame (~8 fps). A sprite authored with an explicit faster playback
    // speed (fps > 8, e.g. the cairn bear adult breath loop at 20 fps) is honoured so
    // hand-built fluid loops don't get slowed to the shared cadence.
    var _ms = 120;
    if (sprite_get_speed_type(spr) == spritespeed_framespersecond) {
        var _fps = sprite_get_speed(spr);
        if (_fps > 8) _ms = 1000 / _fps;
    }
    return (current_time div _ms) mod _n;
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
    var _v = _base * pet_injury_mult(_p.injured) * pet_corruption_mult(_p) * pet_stat_mult(_p, "lck") * pet_bond_mult(_p) * pet_hunger_mult(_p);   // LCK stat + Soul-bound + hunger (07-08)
    if (pet_is_fulfilled(_p)) _v += 0.05;   // grand boon: a big second helping of gold
    return _v;
}
function pet_active_boon_loot_pts() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || _p.archetype != PET_ARCH_BOON) return 0;
    var _base = pet_boon_loot_pts_for(_p.stage) + pet_kit_mods(_p).loot;   // base + named kit (lucky/treasure sense)
    var _v = _base * pet_injury_mult(_p.injured) * pet_corruption_mult(_p) * pet_stat_mult(_p, "lck") * pet_bond_mult(_p) * pet_hunger_mult(_p);   // LCK stat + Soul-bound + hunger (07-08)
    if (pet_is_fulfilled(_p)) _v += 3;       // grand boon: extra loot find
    return round(_v);
}

// --- C5 kit hooks for the ACTIVE pet (M-approved 07-09) -----------------------
// Charmed: flat % added to ALL the player's crit rolls, LCK-scaled + care-modified.
function pet_active_kit_crit() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    var _c = pet_kit_mods(_p).crit;
    if (_c <= 0) return 0;
    return _c * pet_injury_mult(_p.injured) * pet_corruption_mult(_p) * pet_stat_mult(_p, "lck") * pet_hunger_mult(_p);
}
// Fate's Coin: once-per-combat lethal save (checked in combat_try_last_stand).
function pet_active_has_fatecoin() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || pet_hp(_p) <= 0 || pet_injury_mult(_p.injured) <= 0) return false;
    return pet_kit_mods(_p).fatecoin;
}
// Sharp Eye: flat % added to event stat-check odds (0 when absent).
function pet_active_sharpeye() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg || pet_injury_mult(_p.injured) <= 0) return 0;
    return pet_kit_mods(_p).sharpeye;
}

// --- Species INNATES (08-01, PETS_RESEARCH_0801.md pillar B, M-approved) ------
// One small always-on named passive per GENERIC species (~half a capstone) so
// species is identity, not a skin. Signature (boss) species carry a MOVE
// instead (pillar D) - they return undefined here. fx ids are consumed at the
// effect sites via pet_active_innate.
function pet_species_innate(species_id) {
    switch (species_id) {
        case "luna_moth":        return { name:"Lunar Grace",    fx:"crit_spell", val:3,  desc:"+3% Spell Crit while it is your companion." };
        case "bone_stag":        return { name:"Cathedral Calm", fx:"armor",      val:1,  desc:"+1 Armor while it is your companion." };
        case "saber_hound":      return { name:"Pack Snarl",     fx:"crit_phys",  val:2,  desc:"+2% Phys Crit while it is your companion." };
        case "gloomtoad":        return { name:"Mire Stare",     fx:"mire",       val:10, desc:"The first enemy attack on you each combat deals 10% less." };
        case "wyrmling":         return { name:"Ember Memory",   fx:"fire",       val:3,  desc:"Your Fire-school abilities strike for +3 bonus Fire damage." };
        case "nightowl":         return { name:"Long Watch",     fx:"event",      val:5,  desc:"+5% success on event stat-checks." };
        case "bonehound":        return { name:"Grave Loyal",    fx:"bond",       val:25, desc:"Its bond grows 25% faster." };
        case "hollow_pup":       return { name:"Empty Comfort",  fx:"heal_recv",  val:5,  desc:"+5% to all healing you receive." };
        case "duskraven":        return { name:"Last Words",     fx:"elite_gold", val:15, desc:"It collects last words - +15 gold whenever an ELITE dies." };
        case "pale_widow":       return { name:"Venom Thread",   fx:"dot_turns",  val:1,  desc:"Your Bleed and Poison last 1 extra turn." };
        case "shellback":        return { name:"Runeshell",      fx:"armor_res",  val:1,  desc:"+1 Armor and +1 Elem. Resist while it is your companion." };
        case "thorn_boar":       return { name:"Bramble Hide",   fx:"thorns",     val:2,  desc:"Enemies that strike you take 2 damage back." };
        case "glimmer_slime":    return { name:"Gemcrust",       fx:"gold",       val:4,  desc:"+4% gold find while it is your companion." };
        case "sporeling":        return { name:"Spore Cloud",    fx:"spore",      val:5,  desc:"Enemies that strike you have a 5% chance to be Poisoned." };
        case "voidkit":          return { name:"Slip Between",   fx:"slip",       val:10, desc:"The first blow aimed at you each combat has a 10% chance to miss." };
        case "ironshell_beetle": return { name:"Riveted Plate",  fx:"armor",      val:2,  desc:"+2 Armor while it is your companion." };
        // --- 08-06 expansion innates (DESIGN_WORLD_EXPANSION_0806.md §1) ----------
        // fx ids marked NEW below need a read site; the rest reuse existing hooks.
        case "cairn_bear":     return { name:"Standing Weight", fx:"last_stand",   val:1,  desc:"The first hit of a combat cannot drop you below 1 HP." };
        case "ember_ram":      return { name:"Banked Heat",     fx:"first_fire",   val:3,  desc:"Your first attack each combat deals +3 bonus Fire damage." };
        case "salt_hare":      return { name:"Bolt",            fx:"floor_ap",     val:1,  desc:"+1 starting AP in the first combat of each floor." };
        case "mire_heron":     return { name:"Patient Strike",  fx:"patient_crit", val:4,  desc:"+4% Phys Crit if you spent no AP last turn." };
        case "gravel_tick":    return { name:"Cling",           fx:"dot_turns",    val:1,  desc:"Your Bleed and Poison last 1 extra turn." };
        case "ashjaw_lynx":    return { name:"Heat Sense",      fx:"vs_burning",   val:5,  desc:"+5% damage to Burning enemies." };
        case "glass_eel":      return { name:"Slipstream",      fx:"el_resist",    val:1,  desc:"+1 Elem. Resist while it is your companion." };
        case "chapel_bat":     return { name:"Vespers",         fx:"room_heal",    val:2,  desc:"Heal 2 HP whenever you clear a combat room." };
        case "barrow_mole":    return { name:"Turned Earth",    fx:"cache_find",   val:6,  desc:"+6% chance of an extra item from floor caches." };
        case "tallow_moth":    return { name:"Guttering Light", fx:"heal_recv",    val:20, desc:"Its glow deepens every mend - +20% to all healing you receive." };
        case "gravemask":      return { name:"Grave Goods",     fx:"cache_find",   val:8,  desc:"+8% chance of an extra item from floor caches." };
        case "bristleback":    return { name:"Unmoved",         fx:"thorns",       val:3,  desc:"Enemies that strike you take 3 damage back." };
        case "wispfox":        return { name:"Lure",            fx:"first_fire",   val:4,  desc:"Your first attack each combat deals +4 bonus Fire damage." };
        case "gravefox":       return { name:"Claimed Crown",   fx:"gold",         val:6,  desc:"+6% gold find while it is your companion." };
        // Ice biome (08-08). Existing fx ids only - these read at live sites today.
        case "frostmarten":    return { name:"Under-Ice",       fx:"slip",         val:10, desc:"The first blow aimed at you each combat has a 10% chance to miss." };
        case "snowmaw":        return { name:"Drift Ambush",    fx:"crit_phys",    val:4,  desc:"+4% Phys Crit while it is your companion." };
        case "permafrost_toad":return { name:"Slow Thaw",       fx:"dot_halve",    val:1,  desc:"The first Burn or Poison applied to you each combat is halved." };
        case "icewing_skua":   return { name:"Scavenger's Eye", fx:"gold",         val:5,  desc:"+5% gold find while it is your companion." };
        case "pyre_bison":     return { name:"Bankfire",        fx:"fire",         val:4,  desc:"Your Fire-school abilities strike for +4 bonus Fire damage." };
        case "crypt_gryphon":  return { name:"Old Vigil",       fx:"armor_res",    val:2,  desc:"+2 Armor and +2 Elem. Resist while it is your companion." };
        case "threehunger":    return { name:"Three Appetites", fx:"crit_phys",    val:4,  desc:"+4% Phys Crit while it is your companion." };
        case "wing_hare":      return { name:"Unremarkable",    fx:"slip",         val:12, desc:"The first blow aimed at you each combat has a 12% chance to miss." };
        case "stormkirin":     return { name:"Charged Air",     fx:"crit_spell",   val:5,  desc:"+5% Spell Crit while it is your companion." };
        case "lockjaw_turtle": return { name:"Set Jaw",         fx:"bleed_dmg",    val:1,  desc:"Your Bleeds deal +1 damage per tick." };
        case "drowned_lamp":   return { name:"Wet Light",       fx:"event",        val:6,  desc:"+6% success on event stat-checks." };
        case "honeymaw":       return { name:"Sweet Tooth",     fx:"heal_recv",    val:8,  desc:"+8% to all healing you receive." };
        case "bark_hound":     return { name:"Weathered",       fx:"dot_halve",    val:1,  desc:"The first Burn or Poison applied to you each combat is halved." };
        case "canopy_shrew":   return { name:"Overhead",        fx:"crit_low",     val:3,  desc:"+3% Phys Crit against enemies below half HP." };
        case "witchwood_fawn": return { name:"Green Memory",    fx:"hunger_slow",  val:20, desc:"Your companion's hunger decays 20% slower." };
        case "pressure_snail": return { name:"Deep Shell",      fx:"armor",        val:2,  desc:"+2 Armor while it is your companion." };
        case "flicker_finch":  return { name:"Flicker",         fx:"slip",         val:8,  desc:"The first blow aimed at you each combat has an 8% chance to miss." };
        case "rust_vole":      return { name:"Scavenged Ore",   fx:"elite_gold",   val:10, desc:"It picks the iron clean - +10 gold whenever an ELITE dies." };
        case "paleswimmer":    return { name:"Undertow",        fx:"undertow",     val:8,  desc:"Enemies that strike you have an 8% chance to be Weakened for 1 turn." };
    }
    return undefined;
}

// The ACTIVE companion's innate value for an effect id (0 when absent). Innates
// are always-on while the creature is carried and hatched - deliberately NOT
// injury/hunger-gated (they are what the creature IS, not what it does).
function pet_active_innate(fx) {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    var _in = pet_species_innate(_p.species);
    // Understudy (mimicling sig move, 08-06): it performs the LAST creature you
    // had active - its effective innate is that species' innate. The previous-
    // species ledger is stamped at combat start (obj_combat_controller Create)
    // and persists in the save. Falls through to its own innate with no history.
    if (_p.species == "mimicling" && pet_active_sig_move("understudy")
        && variable_global_exists("pet_prev_species") && global.pet_prev_species != "") {
        var _mi = pet_species_innate(global.pet_prev_species);
        if (_mi != undefined) _in = _mi;
    }
    if (_in == undefined) return 0;
    if (_in.fx == fx) return _in.val;
    if (_in.fx == "armor_res" && (fx == "armor" || fx == "el_resist")) return _in.val;   // Runeshell plates both
    return 0;
}

// --- SIGNATURE MOVES (08-01, PETS_RESEARCH_0801.md pillar D, M-approved) ------
// Each boss species carries ONE loud once-per-combat auto ability echoing its
// boss - the real payoff of a once-per-save signature egg. Tundra trio built
// 08-01; the remaining six built 08-05 (all nine live).
function pet_species_sig_move(species_id) {
    switch (species_id) {
        case "rimefox":         return { name:"Still Breath",  fx:"still_breath", desc:"Once per combat: the first enemy to act draws breath in the cold - -25% damage for 2 turns." };
        case "crypt_bat":       return { name:"Echo Shriek",   fx:"echo_shriek",  desc:"Once per combat: the first time you fall below 40% HP, its shriek lays EVERY enemy Exposed." };
        case "hoarfrost_drake": return { name:"Long Winter",   fx:"long_winter",  desc:"Once per combat: an elite or boss's first action freezes in its throat - delayed one turn." };
        case "vaultling":       return { name:"Warden's Seal", fx:"wardens_seal", desc:"Once per combat: the first enemy ABILITY that would hit you breaks against the seal - negated outright." };
        case "marrow_adder":    return { name:"Marrow Crown",  fx:"marrow_crown", desc:"Once per combat: when the first enemy falls, the weakest survivor's marrow cracks - 10% of its max HP." };
        case "gaolwyrm":        return { name:"Gaol Chains",   fx:"gaol_chains",  desc:"Once per combat: the first ability an elite or boss readies against you is chained away - stunned 1 turn." };
        case "cinder_newt":     return { name:"Forge Spark",   fx:"forge_spark",  desc:"Once per combat: your first attack also sets the target Burning." };
        case "magma_leech":     return { name:"Slagpearl",     fx:"slagpearl",    desc:"Every combat victory it sweats out a cooling slagpearl - +8 gold." };
        case "golemite":        return { name:"Stoneshadow",   fx:"stoneshadow",  desc:"Once per combat: the first blow that would drop you below half HP is halved by its stone shadow." };
        // --- 08-06: Depth Warden scions (DESIGN_WORLD_EXPANSION_0806.md §2.1) -----
        case "doorling":        return { name:"Held Open",     fx:"held_open",    desc:"Once per combat: it holds the way open - you take no damage from the first enemy to act." };
        case "fathom_squid":    return { name:"Ink Fathom",    fx:"ink_fathom",   desc:"Once per combat: the first enemy to target you loses its turn to the dark." };
        case "tallykeep":       return { name:"Reckoning",     fx:"reckoning",    desc:"Every 3rd ability you cast deals +20% damage - it is keeping count." };
        case "lantern_wyrm":    return { name:"Borrowed Light", fx:"borrowed_light", desc:"Once per combat: the first time you fall below 50% HP, its lantern gives back 15% of your max HP." };
        case "deepclaw":        return { name:"Deadweight",    fx:"deadweight",   desc:"The load settles on the swiftest foe - it acts LAST this combat." };
        case "sum_moth":        return { name:"Carry the One", fx:"carry_one",    desc:"Once per combat: your first overkill damage carries over to another enemy." };
        case "null_hound":      return { name:"Nothing Follows", fx:"nothing_follows", desc:"Once per combat: the first debuff applied to you is erased before it lands." };
        case "mimicling":       return { name:"Understudy",    fx:"understudy",   desc:"It copies the innate of the last creature you had active." };
        case "griefwisp":       return { name:"Abdication",    fx:"abdication",   desc:"Once per combat: the first elite or boss ability costs that enemy its next turn." };
        // --- 08-06: new biome scions (§3.1 Drowned Reach, §3.2 Hollow Canopy) -----
        case "sluice_otter":    return { name:"Ebb",           fx:"ebb",          desc:"Once per combat: the first heal you receive is doubled." };
        case "chorister_fry":   return { name:"Descant",       fx:"descant",      desc:"Once per combat: the first summon an enemy calls arrives at 1 HP." };
        case "leviathan_calf":  return { name:"Something Larger", fx:"something_larger", desc:"Once per combat: the first enemy to strike you takes 25% of its own max HP." };
        case "graftling":       return { name:"Take Root",     fx:"take_root",    desc:"Once per combat: the first enemy add arrives Rooted." };
        case "thornlet":        return { name:"Bramble Wall",  fx:"bramble_wall", desc:"Once per combat: the first enemy attack on you is stopped outright." };
        case "whispervine":     return { name:"Held Breath",   fx:"held_breath",  desc:"Once per combat: the first cast that stun, root or silence would block slips through anyway." };
    }
    return undefined;
}

// True when the ACTIVE companion carries this move AND is fit to act (moves are
// actions - injury, KO and starvation bench them; duels sit the companion out).
function pet_active_sig_move(fx) {
    if (variable_global_exists("duel_active") && global.duel_active) return false;
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return false;
    if (pet_injury_mult(_p.injured) <= 0 || pet_hp(_p) <= 0 || pet_hunger_mult(_p) <= 0) return false;
    var _sm = pet_species_sig_move(_p.species);
    return (_sm != undefined && _sm.fx == fx);
}
// Single price source for the shrine draw AND the payment handler.
// V2 (07-29): the catalog's base cost is scaled by the run's Awakening tier
// (0.40x at A0 up to 1.15x at A5) so early shrines are a real purchase, then
// Sharp Eye's -15% pet discount applies on top. Dust/item tribute derive from
// the scaled figure as before (boon_dust_cost / item_tribute_value).
function shrine_boon_price(base_cost) {
    var _asc   = variable_global_exists("selected_ascendance") ? clamp(global.selected_ascendance, 0, 5) : 0;
    var _curve = [0.40, 0.55, 0.70, 0.85, 1.00, 1.15];
    var _c     = max(1, round(base_cost * _curve[_asc]));
    return (pet_active_sharpeye() > 0) ? max(1, round(_c * 0.85)) : _c;
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
    // Ashen Duelist: "no pets, no gods, no debts" - the passive guard sits out too.
    if (variable_global_exists("duel_active") && global.duel_active) return 0;
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    return min(0.08, pet_stat(_p, "pow") * 0.005) * pet_hunger_mult(_p);   // hunger (07-08)
}
function pet_spr_injury_resist(pet) {
    if (!is_struct(pet) || pet.is_egg) return 0;
    return min(50, pet_stat(pet, "spr") * 5);
}
function pet_active_lck_gold_pct() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    return pet_stat(_p, "lck") * 0.005 * pet_hunger_mult(_p);   // hunger (07-08)
}
function pet_active_lck_loot_pts() {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    return pet_stat(_p, "lck") * 0.3 * pet_hunger_mult(_p);   // hunger (07-08)
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
    // Grave Loyal (bonehound innate, 08-01): its bond grows 25% faster.
    var _inn_b = pet_species_innate(pet.species);
    if (_inn_b != undefined && _inn_b.fx == "bond") amount = max(1, round(amount * (1 + _inn_b.val / 100)));
    // Beast-Whisperer origin (08-11): all bonds grow 25% faster (stacks with innates).
    if (origin_is("whisperer")) amount = max(1, round(amount * 1.25));
    var _t0 = pet_bond_tier(pet);
    pet.bond = pet_bond(pet) + amount;
    var _t1 = pet_bond_tier(pet);
    if (_t1 <= _t0) return "";
    ach_unlock("ACH_ACQUAINTED");   // achievement hook (08-05 wiring): first bond tier-up
    audio_play_sound(snd_bond_up, 1, false);   // warm two-note motif on a tier crossing
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
        first_loss:      "Set no more flowers than this stone can carry, stranger.\n\nIt is not gone. Nothing that was loved here is ever gone.",
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
    // Sentence-case after the prefix strip (M 08-15: "strikes an enemy each
    // turn..." rendered lowercase under GRANTS).
    if (_t != "") _t = string_upper(string_char_at(_t, 1)) + string_delete(_t, 1, 1);
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
    // Species INNATE first (08-01, pillar B): what this creature IS.
    var _inn = pet_species_innate(pet.species);
    if (_inn != undefined) array_push(_out, { name: _inn.name + "  (innate)", desc: _inn.desc });
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
    for (var _i = 0; _i < array_length(_kit); _i++) {
        if (_kit[_i].kind == "Trait") {
            array_push(_out, { name: _kit[_i].name, desc: _kit[_i].desc });
        } else if (_kit[_i].kind == "Splash") {
            // The Awakened splash (kind "Splash") fell through BOTH the Trait and
            // Ability filters, so a chosen Stage-4 gift showed NOWHERE (M 07-09,
            // awakened hollow pup). It's a passive - list it here, labeled.
            array_push(_out, { name: _kit[_i].name + "  (Awakened gift)", desc: _kit[_i].desc });
        }
    }
    // Quirks (08-01, pillar C): what it has LIVED - listed last, story attached.
    var _qk = pet_quirk_list(pet);
    for (var _qi = 0; _qi < array_length(_qk); _qi++) array_push(_out, _qk[_qi]);
    return _out;
}

// ABILITIES list for the profile sheet: the archetype's per-turn combat action
// (Combatant / Guardian) plus every unlocked kit ABILITY (Stage-3 capstone). Boon pets have
// no combat action - their power is the passive above. Each entry { name, desc }.
function pet_ability_list(pet) {
    var _out = [];
    if (!is_struct(pet) || pet.is_egg) return _out;
    // Signature MOVE first (08-01, pillar D): the boss kin's inheritance.
    var _sgm = pet_species_sig_move(pet.species);
    if (_sgm != undefined) array_push(_out, { name: _sgm.name + "  (signature)", desc: _sgm.desc });
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

// --- Pet HP pool (task #20) ---------------------------------------------------
// Intercepting a blow (guarded stance) now DAMAGES the pet instead of being free.
// Stage-scaled pool; stored as DAMAGE TAKEN (hp_dmg, lazy 0) so a stage-up grows
// the pool without touching every evolution site. 0 HP = knocked out: the pet
// gains an injury tier (existing ladder = benched rest of run) and its pool
// refills between runs (pet_on_run_end) or when fed (pet_feed_apply).
function pet_max_hp(pet) {
    if (!is_struct(pet)) return 12;
    switch (pet.stage) {
        case PET_STAGE_BABY:       return 12;
        case PET_STAGE_ADOLESCENT: return 18;
        case PET_STAGE_YOUNGADULT: return 26;
    }
    return 36;   // adult + awakened
}
function pet_hp(pet) {
    if (!is_struct(pet)) return 0;
    if (!variable_struct_exists(pet, "hp_dmg")) pet.hp_dmg = 0;
    return clamp(pet_max_hp(pet) - pet.hp_dmg, 0, pet_max_hp(pet));
}
// Apply damage to the pet's pool. Returns true when THIS hit knocked it out.
function pet_take_damage(pet, amount) {
    if (!is_struct(pet) || amount <= 0) return false;
    var _was_up = pet_hp(pet) > 0;   // lazy-inits hp_dmg
    pet.hp_dmg = min(pet.hp_dmg + amount, pet_max_hp(pet));
    return _was_up && pet_hp(pet) <= 0;
}
function pet_heal_full(pet) {
    if (is_struct(pet)) pet.hp_dmg = 0;
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
    pet_heal_full(_p);     // the HP pool (#20) always refills between runs
    _p.guard_off = false;  // called-off guard resumes next run (Gate stance rules)
    if (result == -1) {
        // Universal SPR role: hardy spirit - a chance to shrug the injury off entirely.
        if (irandom(99) < pet_spr_injury_resist(_p))
            return _p.name + " shrugged off the fall, unharmed (hardy spirit).";
        _p.injured += 1;
        if (_p.injured >= PET_INJURY_DEATH) {
            var _lost = _p.name;
            // Garden deepening (08-01): the lost creature gets a memorial stone
            // in Bairc's garden instead of a silent delete.
            array_push(bairc_memorials(), { name: _lost, species: _p.species });
            bairc_lore_unlock("first_loss");
            array_delete(global.pet_roster, global.active_pet, 1);   // the carried pet is the active one
            global.active_pet = -1;
            return _lost + " succumbed to its injuries and is lost. A stone waits in Bairc's garden.";
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
    ach_unlock("ACH_PET_CURE");
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

// --- MEMORIES -> QUIRKS (08-01, PETS_RESEARCH_0801.md pillar C, M-approved) ---
// A pet's run history writes named QUIRKS onto it: max 2 per pet, first-earned
// lock, one dungeon-flavored quirk per dungeon. Counters live as lazy fields on
// the pet struct (pets save wholesale, so old pets Just Work). Effects apply in
// combat through pet_quirk_mult (rides combat_pet_act's _cmult), plus bespoke
// hooks (Deathdodger at the intercept-KO site, Grateful Belly in hunger drain).

function dungeon_display_name(dkey) {
    switch (dkey) {
        case "ashen_vault":     return "Ashen Vault";
        case "scorched_depths": return "Scorched Depths";
        case "tundra_tomb":     return "Tundra Tomb";
        // 08-06 world expansion (DESIGN_WORLD_EXPANSION_0806.md §3) + the Descent.
        case "drowned_reach":   return "Drowned Reach";
        case "hollow_canopy":   return "Hollow Canopy";
        case "stormcrag":       return "Stormcrag";
        case "descent":         return "The Descent";
    }
    return dkey;
}

function pet_quirks(pet) {
    if (!is_struct(pet)) return [];
    if (!variable_struct_exists(pet, "quirks") || !is_array(pet.quirks)) pet.quirks = [];
    return pet.quirks;
}
function pet_quirk_count(pet) { return array_length(pet_quirks(pet)); }
function pet_quirk_has(pet, id) {
    var _q = pet_quirks(pet);
    for (var _i = 0; _i < array_length(_q); _i++) if (_q[_i].id == id) return true;
    return false;
}
function pet_quirk_has_dungeon(pet, dungeon) {
    var _q = pet_quirks(pet);
    for (var _i = 0; _i < array_length(_q); _i++)
        if (variable_struct_exists(_q[_i], "dungeon") && _q[_i].dungeon == dungeon && _q[_i].dungeon != "") return true;
    return false;
}

function pet_quirk_label(id, dungeon) {
    var _dl = (dungeon != "") ? dungeon_display_name(dungeon) : "";
    switch (id) {
        case "vengeful":       return "Vengeful (" + _dl + ")";
        case "flinches":       return "Flinches (" + _dl + ")";
        case "master":         return "Master of the " + _dl;
        case "curse_eater":    return "Curse-Eater";
        case "deathdodger":    return "Deathdodger";
        case "grateful_belly": return "Grateful Belly";
        case "boss_blooded":   return "Boss-Blooded";
    }
    return id;
}
function pet_quirk_desc(id) {
    switch (id) {
        case "vengeful":       return "+10% to everything it does there - it remembers.";
        case "flinches":       return "-10% to everything it does there - it remembers too well.";
        case "master":         return "+5% to everything it does there.";
        case "curse_eater":    return "+5% to everything it does while any curse rides you.";
        case "deathdodger":    return "Once per run it shrugs off the blow that would fell it (left at 1 HP).";
        case "grateful_belly": return "Its hunger drains 25% slower.";
        case "boss_blooded":   return "+3% to everything it does against elites and bosses.";
    }
    return "";
}

// Grant a quirk. Enforces the cap (2), duplicate ids, and dungeon exclusivity
// (first dungeon-quirk earned per dungeon wins). Returns the notice ("" if not granted).
function pet_quirk_add(pet, id, dungeon, story) {
    if (!is_struct(pet) || pet_quirk_count(pet) >= 2) return "";
    if (pet_quirk_has(pet, id)) return "";
    if (dungeon != "" && pet_quirk_has_dungeon(pet, dungeon)) return "";
    array_push(pet_quirks(pet), { id: id, dungeon: dungeon, story: story });
    return pet.name + " develops a QUIRK - " + pet_quirk_label(id, dungeon) + ((story != "") ? (" (" + story + ").") : ".");
}

// The sheet list: [{name, desc}] with the story line attached.
function pet_quirk_list(pet) {
    var _out = [];
    if (!is_struct(pet) || pet.is_egg) return _out;
    var _q = pet_quirks(pet);
    for (var _i = 0; _i < array_length(_q); _i++) {
        var _e = _q[_i];
        // Boss-Blooded ships with NO story line (M 08-18: "stood with you at a boss's
        // first fall" read as an origin claim on a starter-egg pet); older saves that
        // stored it drop it too.
        var _story = (_e.id == "boss_blooded") ? "" : _e.story;
        array_push(_out, { name: pet_quirk_label(_e.id, _e.dungeon) + "  (quirk)",
                           desc: pet_quirk_desc(_e.id) + ((_story != "") ? ("  It " + _story + ".") : "") });
    }
    return _out;
}

// Context multiplier for everything the pet does in combat (rides _cmult in
// combat_pet_act, so strikes, heals and shields all feel the memory).
function pet_quirk_mult(pet) {
    var _m = 1.0;
    var _q = pet_quirks(pet);
    if (array_length(_q) == 0) return _m;
    var _dung   = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "";
    var _rank   = variable_global_exists("next_enemy_type")  ? global.next_enemy_type  : "";
    var _cursed = variable_global_exists("run_curses") && is_array(global.run_curses) && array_length(global.run_curses) > 0;
    for (var _i = 0; _i < array_length(_q); _i++) {
        switch (_q[_i].id) {
            case "vengeful":     if (_q[_i].dungeon == _dung) _m *= 1.10; break;
            case "flinches":     if (_q[_i].dungeon == _dung) _m *= 0.90; break;
            case "master":       if (_q[_i].dungeon == _dung) _m *= 1.05; break;
            case "curse_eater":  if (_cursed) _m *= 1.05; break;
            case "boss_blooded": if (_rank == "elite" || _rank == "boss") _m *= 1.03; break;
        }
    }
    return _m;
}

// Lazy memory counters. pet_mem_bump: plain counter; _dungeon variant keys a
// struct by the CURRENT run's dungeon. Both return the new count.
function pet_mem_bump(pet, key) {
    if (!is_struct(pet)) return 0;
    if (!variable_struct_exists(pet, key)) variable_struct_set(pet, key, 0);
    variable_struct_set(pet, key, variable_struct_get(pet, key) + 1);
    return variable_struct_get(pet, key);
}
function pet_mem_bump_dungeon(pet, key) {
    if (!is_struct(pet)) return 0;
    var _dung = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "";
    if (_dung == "") return 0;
    if (!variable_struct_exists(pet, key) || !is_struct(variable_struct_get(pet, key))) variable_struct_set(pet, key, {});
    var _s = variable_struct_get(pet, key);
    var _n = (variable_struct_exists(_s, _dung) ? variable_struct_get(_s, _dung) : 0) + 1;
    variable_struct_set(_s, _dung, _n);
    return _n;
}

// Run-end quirk resolution for the carried pet: thresholds -> grants, with the
// notice for the hub. Called from end_run after injuries/corruption resolve
// (a permadead pet is already gone - pet_active() is then undefined and we skip).
function pet_quirk_resolve_run_end(result) {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return "";
    var _dung = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "";
    var _dl   = dungeon_display_name(_dung);
    var _msgs = "";
    // #1 KO'd twice in this dungeon -> Vengeful vs Flinches, odds weighted by
    // bond (tier 2+ = 70% Vengeful: trust turns fear into fury).
    if (_dung != "" && variable_struct_exists(_p, "mem_ko") && is_struct(_p.mem_ko)
        && variable_struct_exists(_p.mem_ko, _dung) && variable_struct_get(_p.mem_ko, _dung) >= 2
        && !pet_quirk_has_dungeon(_p, _dung)) {
        var _id1 = (irandom(99) < ((pet_bond_tier(_p) >= 2) ? 70 : 40)) ? "vengeful" : "flinches";
        var _m1  = pet_quirk_add(_p, _id1, _dung, "was knocked out twice in the " + _dl);
        if (_m1 != "") _msgs += _m1;
    }
    // #2 three FULL CLEARS of a dungeon while carried -> Master of it.
    if (result == 1 && _dung != "" && pet_mem_bump_dungeon(_p, "mem_clears") >= 3) {
        var _m2 = pet_quirk_add(_p, "master", _dung, "cleared the " + _dl + " three times at your side");
        if (_m2 != "") _msgs += (_msgs != "" ? "   " : "") + _m2;
    }
    // #3 carried through 5 cursed runs -> Curse-Eater.
    if (result >= 0 && variable_global_exists("run_curses") && is_array(global.run_curses)
        && array_length(global.run_curses) > 0
        && pet_mem_bump(_p, "mem_curse_runs") >= 5) {
        var _m3 = pet_quirk_add(_p, "curse_eater", "", "was carried through five cursed runs");
        if (_m3 != "") _msgs += (_msgs != "" ? "   " : "") + _m3;
    }
    // #4 hit 0 HP but the run survived -> Deathdodger.
    if (result >= 0 && variable_struct_exists(_p, "mem_ko_this_run") && _p.mem_ko_this_run) {
        var _m4 = pet_quirk_add(_p, "deathdodger", "", "went down fighting, and came home anyway");
        if (_m4 != "") _msgs += (_msgs != "" ? "   " : "") + _m4;
    }
    if (variable_struct_exists(_p, "mem_ko_this_run")) _p.mem_ko_this_run = false;
    return _msgs;
}

// --- Pet KIT: named abilities & traits per archetype (Pets §5) ----------------
// Each archetype has stage-gated Traits (auto: 1 at Adolescent, +1 at Young Adult) plus
// a Stage-3 CAPSTONE chosen from a pool (raised pets pick; wild pets roll - see
// pet_assign_capstone). The kit is the NAMED layer over the archetype's base behavior and
// drives the Tab detail popup + small additive effect mods. (Values TBD - balance.)
function pet_kit_catalog() {
    return [
        // BOON (C5 M-approved 07-09: Fortune gets table presence - Charmed stage-2
        // crit aura + two new capstone options beside the economy pair)
        { arch:PET_ARCH_BOON, id:"prospector", name:"Prospector",     kind:"Trait",   stage:1, effect:"gold", val:0.04, desc:"Sniffs out coin - +4% gold while it is your companion." },
        { arch:PET_ARCH_BOON, id:"lucky",      name:"Lucky Streak",   kind:"Trait",   stage:2, effect:"loot", val:2,    desc:"Fortune leans your way - +2% loot find while active." },
        { arch:PET_ARCH_BOON, id:"charmed",    name:"Charmed",        kind:"Trait",   stage:2, effect:"crit", val:3,    desc:"Luck rides your blade - +3% to ALL your critical rolls while it is active (grows with its LCK)." },
        { arch:PET_ARCH_BOON, id:"windfall",   name:"Windfall",       kind:"Ability", stage:3, effect:"gold", val:0.08, desc:"A surge of fortune - a further +8% gold." },
        { arch:PET_ARCH_BOON, id:"treasure_sense", name:"Treasure Sense", kind:"Ability", stage:3, effect:"loot", val:4, desc:"An unerring nose for loot - a further +4% loot find." },
        { arch:PET_ARCH_BOON, id:"fate_coin",  name:"Fate's Coin",    kind:"Ability", stage:3, effect:"fatecoin", val:0, desc:"Once per combat, a blow that would kill you leaves you at 1 HP instead." },
        { arch:PET_ARCH_BOON, id:"sharp_eye",  name:"Sharp Eye",      kind:"Ability", stage:3, effect:"sharpeye", val:10, desc:"It sees the angles - event stat-checks +10% success, shrine boons cost 15% less." },
        // COMBATANT (C5: +2 capstone options; C4: Executioner reworked - was a
        // strictly-worse Rend at +40% conditional vs +50% flat)
        { arch:PET_ARCH_COMBATANT, id:"vicious", name:"Vicious",      kind:"Trait",   stage:1, effect:"dmg", val:0.15, desc:"Goes for the throat - +15% to its attacks." },
        { arch:PET_ARCH_COMBATANT, id:"savage",  name:"Savage",       kind:"Trait",   stage:2, effect:"dmg", val:0.20, desc:"Tastes blood - a further +20% to its attacks." },
        { arch:PET_ARCH_COMBATANT, id:"rend",    name:"Rend",         kind:"Ability", stage:3, effect:"dmg", val:0.50, desc:"Brutal, tearing strikes - +50% attack damage." },
        { arch:PET_ARCH_COMBATANT, id:"executioner", name:"Executioner", kind:"Ability", stage:3, effect:"execute", val:1.00, desc:"+100% damage to enemies below 30% HP - and its strike SLAYS outright a lesser foe below 15% (not elites or bosses)." },
        { arch:PET_ARCH_COMBATANT, id:"opportunist", name:"Opportunist", kind:"Ability", stage:3, effect:"opportunist", val:0.35, desc:"Its strike DETONATES a status the target carries (consumed) for +35% damage - a second detonator on your side." },
        { arch:PET_ARCH_COMBATANT, id:"bloodscent",  name:"Bloodscent",  kind:"Ability", stage:3, effect:"bloodscent", val:0.50, desc:"The smell of blood drives it - against a BLEEDING target it strikes twice (second hit at half power)." },
        // GUARDIAN (C5: +2 capstone options)
        { arch:PET_ARCH_GUARDIAN, id:"devoted", name:"Devoted",       kind:"Trait",   stage:1, effect:"heal", val:0.25, desc:"Never leaves your side - +25% to its healing." },
        { arch:PET_ARCH_GUARDIAN, id:"warding", name:"Warding",       kind:"Trait",   stage:2, effect:"shield", val:0.25, desc:"Raises stronger wards - +25% to its shields." },
        { arch:PET_ARCH_GUARDIAN, id:"guardian_angel", name:"Guardian Angel", kind:"Ability", stage:3, effect:"both", val:0, desc:"Each turn it heals AND shields you, never just one." },
        { arch:PET_ARCH_GUARDIAN, id:"bulwark", name:"Bulwark",       kind:"Ability", stage:3, effect:"shield", val:0.50, desc:"An immovable ward - +50% to its shields." },
        { arch:PET_ARCH_GUARDIAN, id:"bodyguard",  name:"Bodyguard",  kind:"Ability", stage:3, effect:"bodyguard", val:0, desc:"It throws itself between you and harm - 40% chance to intercept part of any blow, in any stance (it shrugs off a tenth of what it catches)." },
        { arch:PET_ARCH_GUARDIAN, id:"lifespring", name:"Lifespring", kind:"Ability", stage:3, effect:"lifespring", val:0, desc:"Once per combat, its heal also washes away your newest affliction." },
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

// Display text for a pet's chosen/rolled Awakened splash: "Name - desc", or ""
// until it has one. Surfaces the Stage-4 gift on the companion loadout card and
// the Tab detail popup (M 07-09: once chosen, the splash showed NOWHERE).
function pet_splash_text(pet) {
    if (!is_struct(pet) || pet.is_egg) return "";
    if (!variable_struct_exists(pet, "kit_splash") || pet.kit_splash == "") return "";
    var _k = pet_kit_get(pet.kit_splash);
    if (_k == undefined) return "";
    return _k.name + " - " + _k.desc;
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
               crit:0, fatecoin:false, sharpeye:0, opportunist:0, bloodscent:0,
               bodyguard:false, lifespring:false,
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
            // C5 kit additions (M-approved 07-09)
            case "crit":        _m.crit        += _e.val; break;   // Charmed: +% to all player crit rolls (LCK-scaled at apply)
            case "fatecoin":    _m.fatecoin     = true;   break;   // Fate's Coin: once/combat lethal save at 1 HP
            case "sharpeye":    _m.sharpeye    += _e.val; break;   // Sharp Eye: +% event checks; shrine boons -15%
            case "opportunist": _m.opportunist += _e.val; break;   // Opportunist: strike detonates a carried status
            case "bloodscent":  _m.bloodscent  += _e.val; break;   // Bloodscent: second strike vs bleeding targets
            case "bodyguard":   _m.bodyguard    = true;   break;   // Bodyguard: intercept 25%->40%, pet takes it at 0.90x (M 07-10)
            case "lifespring":  _m.lifespring   = true;   break;   // Lifespring: heal also cleanses, once/combat
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
        // 07-31 expansion slate (M-approved). Art lands in batches - species
        // without sprites never roll (pet_species_random is art-gated).
        { id:"duskraven",        name:"Duskraven",        blurb:"a tattered crow that collects last words" },
        { id:"pale_widow",       name:"Pale Widow",       blurb:"a bone-white spider that spins in silence" },
        { id:"shellback",        name:"Shellback",        blurb:"a tortoise carved with runes nobody wrote" },
        { id:"thorn_boar",       name:"Thorn Boar",       blurb:"a piglet bristling with living brambles" },
        { id:"glimmer_slime",    name:"Glimmer Slime",    blurb:"an ooze studded with swallowed gemstones" },
        { id:"sporeling",        name:"Sporeling",        blurb:"a waddling toadstool that hums in the damp" },
        { id:"voidkit",          name:"Voidkit",          blurb:"a kitten cut from the night between stars" },
        { id:"ironshell_beetle", name:"Ironshell Beetle", blurb:"a beetle born wearing riveted plate" },
        // --- 08-06 world-expansion slate (DESIGN_WORLD_EXPANSION_0806.md §1) -------
        // Art-gated like the 07-31 wave: these never roll until their sprites land.
        { id:"cairn_bear",     name:"Cairn Bear",     blurb:"a cub that sleeps under stacked stones and wakes heavier" },
        { id:"ember_ram",      name:"Ember Ram",      blurb:"horns that glow like coals banked overnight" },
        { id:"salt_hare",      name:"Salt Hare",      blurb:"quick, twitchy, tastes of the flats it crossed" },
        { id:"mire_heron",     name:"Mire Heron",     blurb:"stands still so long the water forgets it" },
        { id:"gravel_tick",    name:"Gravel Tick",    blurb:"a pebble that turns out to have legs" },
        { id:"ashjaw_lynx",    name:"Ashjaw Lynx",    blurb:"soot-furred, hunts by the heat of you" },
        { id:"glass_eel",      name:"Glass Eel",      blurb:"transparent but for a thread of silver spine" },
        { id:"chapel_bat",     name:"Chapel Bat",     blurb:"roosts where prayers were loudest" },
        { id:"barrow_mole",    name:"Barrow Mole",    blurb:"digs toward things that should stay buried" },
        { id:"tallow_moth",    name:"Tallow Moth",    blurb:"fat, slow, drawn to the last candle" },
        // Badgers + foxes (M 08-06: roster had neither)
        { id:"gravemask",      name:"Gravemask",      blurb:"it always comes up holding something that was buried" },
        { id:"bristleback",    name:"Bristleback",    blurb:"small, scarred, and entirely unwilling to move" },
        { id:"wispfox",        name:"Wispfox",        blurb:"it leads you somewhere and does not look back" },
        { id:"gravefox",       name:"Gravefox",       blurb:"it dug up a crown and has decided the crown is its" },
        // Ice biome (M 08-07: "we have at least a few fire types for ember vaults,
        // generate a few ice ones") - art imported 08-08, wired 08-08.
        { id:"frostmarten",    name:"Frostmarten",    blurb:"it hunts under the ice and comes up somewhere else" },
        { id:"snowmaw",        name:"Snowmaw",        blurb:"a drift with an appetite, and you are standing on it" },
        { id:"permafrost_toad",name:"Permafrost Toad",blurb:"froze solid some winter and never fully agreed to thaw" },
        { id:"icewing_skua",   name:"Icewing Skua",   blurb:"it does not hunt, it waits for you to drop something" },
        // Fantasy hybrids (M 08-06: "we want hybrid made-up stuff as well")
        { id:"pyre_bison",     name:"Pyre Bison",     blurb:"snow has never once settled on its back" },
        { id:"crypt_gryphon",  name:"Crypt Gryphon",  blurb:"it perches on stone the way a statue would" },
        { id:"threehunger",    name:"Threehunger",    blurb:"three heads, three appetites, one body to argue in" },
        { id:"wing_hare",      name:"Wing Hare",      blurb:"it considers the antlers entirely unremarkable" },
        { id:"stormkirin",     name:"Stormkirin",     blurb:"the air near it is always about to happen" },
        // Biome residents - Drowned Reach (§3.1) + Hollow Canopy (§3.2)
        { id:"lockjaw_turtle", name:"Lockjaw Turtle", blurb:"it has decided about you already" },
        { id:"drowned_lamp",   name:"Drowned Lamp",   blurb:"a fish carrying a light no water puts out" },
        { id:"honeymaw",       name:"Honeymaw",       blurb:"the bees have long since stopped objecting" },
        { id:"bark_hound",     name:"Bark Hound",     blurb:"an ordinary dog wearing an extraordinary coat" },
        { id:"canopy_shrew",   name:"Canopy Shrew",   blurb:"small, furious, extremely high up" },
        { id:"witchwood_fawn", name:"Witchwood Fawn", blurb:"born from a tree that remembered being a deer" },
        // Descent generals (§2.2) - these only appear via Descent sources
        { id:"pressure_snail", name:"Pressure Snail", blurb:"its shell is denser than it has any right to be" },
        { id:"flicker_finch",  name:"Flicker Finch",  blurb:"it is only ever mostly here" },
        { id:"rust_vole",      name:"Rust Vole",      blurb:"eats iron, leaves the good bits" },
        { id:"paleswimmer",    name:"Paleswimmer",    blurb:"eyeless, and it does not react to you at all" },
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
        // --- 08-06: DEPTH WARDEN scions (DESIGN_WORLD_EXPANSION_0806.md §2.1) -----
        // Universal rule: every boss has a scion. Wardens live in the Descent, so
        // dungeon = "descent" and `floor` is the Warden's five-floor cadence slot.
        // pet_boss_signature_species() matches on dungeon+floor, so these never
        // collide with the dungeon trios above.
        { id:"doorling",       name:"Doorkeeper's Cat", boss:"The First Door",          dungeon:"descent", floor:5,  blurb:"it never left its post, and the door never left it" },
        { id:"fathom_squid",   name:"Fathom Squid",     boss:"Sister Fathom",           dungeon:"descent", floor:10, blurb:"it has never seen light and does not miss it" },
        { id:"tallykeep",      name:"Tallykeep",        boss:"The Tally",               dungeon:"descent", floor:15, blurb:"it counts on toes it does not have" },
        { id:"lantern_wyrm",   name:"Lantern Wyrm",     boss:"Hollowlight",             dungeon:"descent", floor:20, blurb:"the light on its head is not its own" },
        { id:"deepclaw",       name:"Deepclaw",         boss:"The Weight of Ironwake",  dungeon:"descent", floor:25, blurb:"it carries a floor of the Descent on its back" },
        { id:"sum_moth",       name:"Sum Moth",         boss:"The Long Arithmetic",     dungeon:"descent", floor:30, blurb:"its wings show a number that keeps changing" },
        { id:"null_hound",     name:"Null Hound",       boss:"Nothing In Particular",   dungeon:"descent", floor:35, blurb:"a dog-shaped absence that heels anyway" },
        { id:"mimicling",      name:"Mimicling",        boss:"The Understudy",          dungeon:"descent", floor:40, blurb:"it is doing an impression of your last companion" },
        { id:"griefwisp",      name:"Griefwisp",        boss:"The Hollow Crown",        dungeon:"descent", floor:45, blurb:"it carries a crown far too big for it" },
        // --- 08-06: new biome scions (§3.1 Drowned Reach, §3.2 Hollow Canopy) -----
        { id:"sluice_otter",   name:"Sluice Otter",     boss:"The Tidewright",          dungeon:"drowned_reach", floor:1, blurb:"it lived in the lock-works and still wears one" },
        { id:"chorister_fry",  name:"Chorister Fry",    boss:"Choirmother of the Deep", dungeon:"drowned_reach", floor:2, blurb:"it hums the part it was taught" },
        { id:"leviathan_calf", name:"Leviathan Calf",   boss:"Leviathan Below",         dungeon:"drowned_reach", floor:3, blurb:"enormous, eventually" },
        { id:"graftling",      name:"Graftling",        boss:"The Grafted Stag",        dungeon:"hollow_canopy", floor:1, blurb:"antlers already, and it is very small" },
        { id:"thornlet",       name:"Thornlet",         boss:"Mother Bramble",          dungeon:"hollow_canopy", floor:2, blurb:"it hugs, and you bleed a little" },
        { id:"whispervine",    name:"Whispervine",      boss:"The Green Silence",       dungeon:"hollow_canopy", floor:3, blurb:"a serpent of living vine that has never made a sound" },
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
    // Art-gated (07-31): species whose sprites haven't been imported yet never
    // roll from any source (starter already filtered; this covers altar eggs,
    // board rewards and every other generic grant).
    var _ok = [];
    for (var _i = 0; _i < array_length(_c); _i++)
        if (pet_species_has_art(_c[_i].id)) array_push(_ok, _c[_i].id);
    if (array_length(_ok) == 0) return _c[irandom(array_length(_c) - 1)].id;
    return _ok[irandom(array_length(_ok) - 1)];
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

// --- Garden deepening (08-01, PETS_RESEARCH_0801.md pillar A, M-approved) ----
// Memorial stones: pets lost to the injury ladder rest in the garden forever.
function bairc_memorials() {
    if (!variable_global_exists("bairc_memorials") || !is_array(global.bairc_memorials)) global.bairc_memorials = [];
    return global.bairc_memorials;
}

// Donated creatures KEEP GROWING: 1 tick per SURVIVED run (extract or clear),
// hatch/stage-up at 2 ticks for a baby then 3 per stage after (~8 runs
// egg->adult). The garden caps at Adult - only carried creatures Awaken.
// Returns a one-line hub notice the first time something stages up ("" else).
function bairc_garden_run_tick(result) {
    if (result < 0) return "";
    var _d = bairc_donated();
    var _grown = "";
    for (var _i = 0; _i < array_length(_d); _i++) {
        var _r = _d[_i];
        if (!is_struct(_r)) continue;
        if (!variable_struct_exists(_r, "gg")) _r.gg = 0;   // lazy: old saves' residents start growing now
        if (_r.stage >= PET_STAGE_ADULT) continue;
        _r.gg += 1;
        var _need = (_r.stage == PET_STAGE_BABY) ? 2 : 3;
        if (_r.gg >= _need) {
            _r.stage += 1;
            _r.gg = 0;
            // Garden growth reveals journal forms too (M 08-13).
            if (variable_struct_exists(_r, "species")) compendium_stage_stamp(_r.species, _r.stage);
            if (_grown == "") _grown = _r.name + " has grown into a " + pet_stage_name(_r.stage) + " in Bairc's garden.";
        }
    }
    return _grown;
}

// The garden tends back: +1% feed growth value per 2 residents, cap +10%.
// Night Garden (Bairc rank 2, M-locked 08-15): the residents' blessing works
// 50% harder - same donations, 1.5x the growth bonus (cap rises to +15%).
// A COMPLETED CAIRN (garden scene, 5 stones) adds a flat +3% until the next
// run (garden_cairn resets in end_run).
function bairc_garden_blessing_pct() {
    var _p = min(10, array_length(bairc_donated()) div 2);
    if (npc_rank("bairc") >= 2) _p = _p * 1.5;
    if (variable_global_exists("garden_cairn") && global.garden_cairn >= 5) _p += 3;
    return _p;
}

// =============================================================================
// BAIRC'S GARDEN - the explorable grounds (M design-locked 08-15 late session).
// A full-screen overlay SCENE entered from Bairc's station ([V] / GARDEN chip):
// a 4800px-wide night garden the camera wanders across (A/D, arrows, or drag).
// The entrusted creatures live here visibly; four small activities (daily
// forage sparkles, the zen cairn, petting, the koi pond) and 8 purchasable
// ornament plots (Mewgenics-style decoration, chao-garden warmth) give it life.
// Pure code-drawn set dressing - no sprite assets needed beyond the pets that
// already exist. Scene draw: ui_draw_garden_scene (scr_ui); input: gc Step
// garden block; state persists in the save (garden_decor / garden_cairn /
// forage day-ledger).
// =============================================================================

function garden_world_w() { return 4800; }

function garden_ensure() {
    if (!variable_global_exists("garden_decor") || !is_struct(global.garden_decor))  global.garden_decor = {};
    if (!variable_global_exists("garden_cairn"))                                     global.garden_cairn = 0;
    if (!variable_global_exists("garden_forage_seed"))                               global.garden_forage_seed = -1;
    if (!variable_global_exists("garden_forage_taken") || !is_array(global.garden_forage_taken)) global.garden_forage_taken = [];
    // The forage "day" is the run counter: a new run reseeds three fresh spots.
    var _rc = variable_global_exists("run_count") ? global.run_count : 0;
    if (global.garden_forage_seed != _rc) {
        global.garden_forage_seed  = _rc;
        global.garden_forage_taken = [];
    }
}

// The 8 fixed ornament plots (world coords; y is the standing baseline).
function garden_decor_anchors() {
    return [
        { x: 560,  y: 930 }, { x: 860,  y: 778 }, { x: 1650, y: 782 }, { x: 2050, y: 940 },
        { x: 2350, y: 778 }, { x: 3050, y: 928 }, { x: 3450, y: 782 }, { x: 3850, y: 932 },
    ];
}

// Ornament catalog - dark-fantasy zen set dressing, one of each may be placed.
function garden_decor_catalog() {
    return [
        { id:"lantern", name:"Stone Lantern",    gold:120, dust:10, blurb:"A warm ember behind carved slate." },
        { id:"gate",    name:"Spirit Gate",      gold:200, dust:20, blurb:"A weathered arch the dead pass under kindly." },
        { id:"basin",   name:"Moon Basin",       gold:100, dust:10, blurb:"Still water that holds the moon in place." },
        { id:"bloom",   name:"Nightbloom Patch", gold:80,  dust:5,  blurb:"Flowers that only open for the dark." },
        { id:"ward",    name:"Moss Ward",        gold:150, dust:15, blurb:"A small stone spirit, green with years." },
        { id:"chimes",  name:"Bone Chimes",      gold:120, dust:10, blurb:"They only sound when nothing is wrong." },
        { id:"wheel",   name:"Pond Wheel",       gold:180, dust:15, blurb:"A slow feeder wheel - the koi grow bold." },
        { id:"jar",     name:"Firefly Jar",      gold:60,  dust:5,  blurb:"Someone always leaves the lid loose." },
    ];
}
function garden_decor_get(id) {
    var _c = garden_decor_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}
// Ornament placed at anchor i ("" = empty plot).
function garden_decor_at(i) {
    garden_ensure();
    var _k = "a" + string(i);
    return variable_struct_exists(global.garden_decor, _k) ? variable_struct_get(global.garden_decor, _k) : "";
}
// Is this ornament already placed anywhere? (One of each.)
function garden_decor_placed(id) {
    for (var _i = 0; _i < array_length(garden_decor_anchors()); _i++) {
        if (garden_decor_at(_i) == id) return true;
    }
    return false;
}
// Buy + set the ornament into an EMPTY plot. "" on success else the reason.
function garden_decor_place(anchor_idx, id) {
    garden_ensure();
    var _d = garden_decor_get(id);
    if (_d == undefined) return "Unknown ornament.";
    if (garden_decor_placed(id)) return "That ornament already stands in the garden.";
    if (anchor_idx < 0 || anchor_idx >= array_length(garden_decor_anchors())) return "No such plot.";
    if (garden_decor_at(anchor_idx) != "") return "That plot is taken.";
    if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
    if (global.gold < _d.gold || global.rune_dust < _d.dust) {
        return "Needs " + string(_d.gold) + "g + " + string(_d.dust) + " dust.";
    }
    global.gold      -= _d.gold;
    global.rune_dust -= _d.dust;
    variable_struct_set(global.garden_decor, "a" + string(anchor_idx), id);
    affinity_add("bairc", 2);   // tending his garden warms him (function-use drip)
    if (room == rm_hub || room == rm_character_select) save_game();
    return "";
}

// Today's 3 forage spots (seeded by run_count; taken flags from the ledger).
function garden_forage_spots() {
    garden_ensure();
    var _out = [];
    for (var _i = 0; _i < 3; _i++) {
        var _h  = frac(sin((global.garden_forage_seed * 7  + _i) * 127.1) * 43758.5453);
        var _h2 = frac(sin((global.garden_forage_seed * 13 + _i) * 311.7) * 12543.853);
        var _taken = false;
        for (var _j = 0; _j < array_length(global.garden_forage_taken); _j++) {
            if (global.garden_forage_taken[_j] == _i) { _taken = true; break; }
        }
        array_push(_out, { idx: _i, x: 380 + _h * (garden_world_w() - 760),
                           y: (_h2 < 0.5) ? 800 : 952, taken: _taken });
    }
    return _out;
}
// Claim a spot: small dust / gold / a creature treat. Returns the notice line.
function garden_forage_take(i) {
    garden_ensure();
    for (var _j = 0; _j < array_length(global.garden_forage_taken); _j++) {
        if (global.garden_forage_taken[_j] == i) return "";
    }
    array_push(global.garden_forage_taken, i);
    var _msg;
    var _roll = irandom(99);
    if (_roll < 40) {
        var _fd = 6 + irandom(8);
        if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
        global.rune_dust += _fd;
        _msg = "Something glitters in the moss - +" + string(_fd) + " rune dust.";
    } else if (_roll < 80) {
        var _fg = 20 + irandom(25);
        global.gold += _fg;
        _msg = "A dropped purse, half-buried - +" + string(_fg) + "g.";
    } else {
        var _fc = pet_feed_catalog();
        var _ff = _fc[irandom(array_length(_fc) - 1)];
        pet_feed_pouch_add(_ff.id, 1);
        _msg = "Wild pickings - +1 " + _ff.name + " for the pouch.";
    }
    if (room == rm_hub || room == rm_character_select) save_game();
    return _msg;
}

// Place the next cairn stone. Returns the notice line ("" = nothing happened).
function garden_cairn_place() {
    garden_ensure();
    if (global.garden_cairn >= 5) return "The cairn holds. Let it stand.";
    global.garden_cairn += 1;
    if (global.garden_cairn >= 5) {
        if (room == rm_hub || room == rm_character_select) save_game();
        return "The fifth stone settles. The garden breathes easier (+3% growth until your next run).";
    }
    if (room == rm_hub || room == rm_character_select) save_game();
    return "Stone " + string(global.garden_cairn) + " of 5 balances...";
}

// A petted resident's reaction line (authored, hashed stable per name).
function garden_pet_line(_name) {
    var _lines = [
        " leans into your hand.",
        " makes a sound like a rusted hinge, happily.",
        " goes very still, then very wiggly.",
        " remembers you. It absolutely remembers you.",
        " accepts this tribute as its due.",
        " blinks slowly. High praise, here.",
    ];
    var _h = 0;
    for (var _i = 1; _i <= string_length(_name); _i++) _h += string_ord_at(_name, _i);
    return _name + _lines[_h mod array_length(_lines)];
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
    ach_record_hatch(pet);        // lifetime species/scion sets (achievements)
    achievements_sync();
    return true;
}

// --- Full-screen hatch cutscene (Pets §3) -------------------------------------
// A modal shake -> crack -> reveal sequence launched from the Bairc Enter-on-egg
// action. State lives on obj_game_controller (see its Create). hatch_cutscene_step()
// runs from gc Step while hatch_active (owning all input); hatch_cutscene_draw()
// (scr_ui) renders it over the Bairc screen. pet_hatch() is applied at the reveal.
#macro HATCH_SHAKE_LEN  110  // frames of trembling before the shell cracks
                             // (M 07-16: 50 -> 110 so the Zelda-chest-style rising
                             // build has room to swell before the crack lands)
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
    audio_play_sound(snd_egg_stir, 1, false);   // shell wobble + tap from inside (SHAKE phase)
    // M 07-16 (Zelda-chest hatch): rising musical build under the whole tremble+crack,
    // timed to crest right as the shell breaks (see HATCH_SHAKE_LEN).
    audio_play_sound(snd_hatch_build, 1, false);
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
                        audio_play_sound(snd_hatch_burst, 1, false);   // crack + warm chime bloom layered over
                        audio_play_sound(snd_hatch_fanfare, 1, false); // M 07-16: the triumphant "got it!" resolve the build climbs into
                    }
                    hatch_phase = 2; hatch_t = 0;
                }
            }
            break;

        case 2: // REVEAL - baby scales in; wait for the player to dismiss (min hold first)
            // (touch, 8d: a tap dismisses too - the reveal was Enter/Esc-only)
            if (hatch_t >= HATCH_REVEAL_MIN &&
                (input_confirm() || input_confirm_alt() || input_cancel()
                 || (mouse_check_button_pressed(mb_left)))) {
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
    // ~8% of finds arrive CORRUPTED (§7; 12 -> 8, M 08-18): they start PUSHING (carried
    // debuff, but gains a permanent +15% each completed run, fully corrupting after 3).
    // You can cure anytime.
    if (irandom(99) < 8) { _pet.corrupted = true; _pet.corruption_state = "pushing"; }
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
    // FIND BANNER (M 08-18): every pet/egg grant announces itself, whatever the source
    // (boss egg, Warden survivor, shrine/curse altar, event) - the log line alone was
    // missed ("I have no idea when I got this young adult").
    if (_pet.is_egg) {
        var _fb_lbl = pet_egg_label(_pet);
        find_banner_push("egg", "Mysterious " + ((_fb_lbl != "") ? _fb_lbl : "Egg"),
            "Something alive waits inside - Bairc can identify and raise it.", pet_sprite(_pet));
    } else {
        find_banner_push(_pet.corrupted ? "corrupted" : "pet",
            _pet.name + "  (" + pet_stage_name(_pet.stage) + ")",
            (_pet.corrupted ? "It carries a CORRUPTION - Bairc can cure it. " : "It follows you home, already loyal - ")
            + "Waiting in Bairc's stable.", pet_sprite(_pet));
    }
    return pet_add(_pet);
}

// True if a species has COMPLETE art, so rolls / starter / boss eggs / compendium never
// expose one with missing art. Bar (M 08-17): all THREE visual stages exist - baby,
// youngadult, adult - as south sprites (east falls back to south in pet_sprite, so a
// single facing is fine). Static stills COUNT (idle animation can land later); a species
// missing any stage does not. Pets already in a save keep drawing: pet_sprite() is unchanged.
function pet_species_has_art(species_id) {
    var _stages = ["baby", "youngadult", "adult"];
    for (var _i = 0; _i < array_length(_stages); _i++) {
        var _k = "spr_pet_" + species_id + "_" + _stages[_i];
        if (asset_get_index(_k + "_s") < 0 && asset_get_index(_k) < 0) return false;
    }
    return true;
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

    // M 08-13: the extra-egg start twice produced two of the SAME species and
    // the SAME role. Starter grants now dodge anything already in the roster -
    // species always (bounded reroll), and role too whenever one is still free
    // - so "start with an extra egg" is guaranteed to mean two DIFFERENT pets.
    var _have_species = {};
    var _have_arch    = [false, false, false];
    if (variable_global_exists("pet_roster") && is_array(global.pet_roster)) {
        for (var _r = 0; _r < array_length(global.pet_roster); _r++) {
            var _rp = global.pet_roster[_r];
            if (!is_struct(_rp)) continue;
            if (variable_struct_exists(_rp, "species"))   variable_struct_set(_have_species, _rp.species, true);
            if (variable_struct_exists(_rp, "archetype")) _have_arch[clamp(_rp.archetype, 0, 2)] = true;
        }
    }
    var _tries = 0;
    while (_tries < 60 && array_length(_arted) > 1
        && variable_struct_exists(_have_species, _species)) {
        _species = _arted[irandom(array_length(_arted) - 1)];
        _tries++;
    }
    var _arch = irandom(2);
    if (_have_arch[0] || _have_arch[1] || _have_arch[2]) {
        var _free = [];
        for (var _a = 0; _a < 3; _a++) if (!_have_arch[_a]) array_push(_free, _a);
        if (array_length(_free) > 0) _arch = _free[irandom(array_length(_free) - 1)];
    }
    return pet_add(pet_make(_species, "egg_starter", _arch, PET_STAGE_BABY, true));   // is_egg = true
}

// --- Egg types (Pets §3): RNG egg design, each carrying a small permanent benefit that
// the HATCHLING keeps while it is your active companion. Egg type is independent of the
// creature inside (a surprise). 4 types for now (expandable). ----------------------------
function pet_egg_type_catalog() {
    return [
        { id:"gilded",  name:"Gilded Egg",   effect:"gold",   val:0.05, desc:"+5% gold while its hatchling is active." },
        { id:"fortune", name:"Fortune Egg",  effect:"loot",   val:5,    desc:"+5% loot find while its hatchling is active." },
        // Descs corrected 08-13 (M screenshot: a Tender Egg on a FORTUNE pet
        // claimed +5% heal & shield, but the bonus only reads in the Guardian
        // branch - "no effect on Combatant" hid that Fortune got nothing too).
        { id:"savage",  name:"Savage Egg",   effect:"dmg",    val:0.05, desc:"+5% pet damage (Warrior; Guardians get +5% heal & shield, Fortune pets +5% gold)." },
        { id:"tender",  name:"Tender Egg",   effect:"mend",   val:0.05, desc:"+5% pet heal & shield (Guardian; Warriors get +5% damage, Fortune pets +5% gold)." },
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
// ROLE-AWARE egg gifts (M-locked 08-17): a Savage/Tender egg whose bonus can't
// apply to the hatchling's role CONVERTS instead of doing nothing - a Fortune/Boon
// pet turns either into +5% gold find, a Warrior turns Tender into +5% damage, a
// Guardian turns Savage into +5% heal & shield. Returns { effect, val, desc, note }.
function pet_egg_effect_for(pet) {
    if (!is_struct(pet) || !variable_struct_exists(pet, "egg_type") || pet.egg_type == "") return undefined;
    var _et = pet_egg_type_get(pet.egg_type);
    if (_et == undefined) return undefined;
    var _eff = _et.effect, _val = _et.val, _desc = _et.desc, _note = "";
    if (_eff == "dmg" || _eff == "mend") {
        if (pet.archetype == PET_ARCH_BOON) {
            _eff = "gold"; _val = 0.05; _desc = "+5% gold while its hatchling is active."; _note = "converted for a Fortune-role pet";
        } else if (_eff == "dmg" && pet.archetype == PET_ARCH_GUARDIAN) {
            _eff = "mend"; _val = 0.05; _desc = "+5% pet heal & shield."; _note = "converted for a Guardian";
        } else if (_eff == "mend" && pet.archetype == PET_ARCH_COMBATANT) {
            _eff = "dmg"; _val = 0.05; _desc = "+5% pet damage."; _note = "converted for a Warrior";
        }
    }
    return { effect: _eff, val: _val, desc: _desc, note: _note };
}
function pet_active_egg_bonus(kind) {
    var _p = pet_active();
    if (_p == undefined || _p.is_egg) return 0;
    var _ee = pet_egg_effect_for(_p);
    if (_ee == undefined || _ee.effect != kind) return 0;
    return _ee.val;
}

// Warding-egg incoming-damage multiplier for the active pet (1.0 if none). Mirrors the
// Warding boon's shape so combat can apply it at every player damage-mitigation site.
function pet_egg_ward_mult() {
    // Ashen Duelist: the hatchling's ward waits outside the hall with the rest.
    if (variable_global_exists("duel_active") && global.duel_active) return 1.0;
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
    var _dung  = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
    var _floor = variable_global_exists("current_floor")    ? global.current_floor    : 1;
    var _sig   = pet_boss_signature_species(_dung, _floor);
    // 08-17: a signature whose art is not finished (pet_species_has_art) counts as unmapped -
    // the boss still drops an egg (generic, art-gated roll) but the scion is NOT marked found,
    // so it stays catchable once its art lands.
    if (_sig != "" && !pet_species_has_art(_sig)) _sig = "";
    // ONCE PER SAVE (M 07-31: repeat drops made signatures "feel common and
    // meaningless"): each boss's signature kin can be found exactly once per
    // save file. First-kill chance raised so it stays chaseable; after that,
    // the boss never rolls again. History persists in the save; on old saves
    // it seeds lazily from the roster + Bairc's garden.
    if (_sig != "") {
        if (!variable_global_exists("pet_sig_history") || !is_struct(global.pet_sig_history)) {
            global.pet_sig_history = {};
            var _seed = [];
            if (variable_global_exists("pet_roster") && is_array(global.pet_roster))
                _seed = array_concat(_seed, global.pet_roster);
            if (variable_global_exists("bairc_donated") && is_array(global.bairc_donated))
                _seed = array_concat(_seed, global.bairc_donated);
            var _sigcat = pet_species_signature_catalog();
            for (var _i = 0; _i < array_length(_seed); _i++) {
                if (!is_struct(_seed[_i]) || !variable_struct_exists(_seed[_i], "species")) continue;
                for (var _j = 0; _j < array_length(_sigcat); _j++)
                    if (_sigcat[_j].id == _seed[_i].species) global.pet_sig_history[$ _seed[_i].species] = true;
            }
        }
        if (variable_struct_exists(global.pet_sig_history, _sig)) return undefined;
    }
    var _chance = min(20, 10 + awk * 2);   // 10% A0 +2%/awk -> 20% A5 (07-31 once-per-save rework)
    if (irandom(99) >= _chance) return undefined;
    if (_sig != "") global.pet_sig_history[$ _sig] = true;
    return pet_grant_from_source("egg_boss", _sig);
}

// Grant a pet egg/creature from a Shrine (blessing) or Curse altar, appending a themed
// hub notice (surfaced on the next hub visit). source: "egg_shrine" / "egg_curse". Curse
// eggs skew corrupted (thematic). Returns the granted pet. Used by the floor shrine flow.
function pet_grant_altar_egg(source) {
    var _pe = pet_grant_from_source(source);
    if (source == "egg_curse" && !_pe.corrupted && irandom(99) < 40) {
        _pe.corrupted = true; _pe.corruption_state = "pushing";
        // The FIND banner was queued inside pet_grant_from_source before this flip -
        // retag the newest queued entry so it announces the corruption.
        if (variable_global_exists("find_queue") && array_length(global.find_queue) > 0 && !_pe.is_egg) {
            var _fq = global.find_queue[array_length(global.find_queue) - 1];
            _fq.kind = "corrupted";
            _fq.sub  = "It carries a CORRUPTION - Bairc can cure it. Waiting in Bairc's stable.";
        }
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
        { id:"loadout",    title:"Prepare to Descend",  body:"Before each run, equip your gear and choose which abilities and traits to bring. You can only take a limited set into the dungeon, so build around how you want to fight. Note the THREE TABS at the top - ABILITIES, TRAITS and COMPANION are picked separately, and it's easy to descend having forgotten your traits. Check all three before you commit." },
        { id:"ascendance", title:"Awakening Tiers",     body:"Higher Awakening tiers make enemies tougher but drop better, rarer loot. Raise the tier when you want more risk for more reward - start low and work up." },
        { id:"combat_ap",  title:"Action Points (AP)",  body:"Each turn you have 3 AP (4 with the Bloodwarden Relentless trait). Abilities cost AP to use; a basic attack is free. Spend your AP wisely, then end your turn to let the enemy act." },
        { id:"targeting",  title:"Choosing a Target",   body:"When several foes are present, Tab or click to pick who you hit. The glowing rune beneath an enemy marks your current target." },
        { id:"intent",     title:"Enemy Intent",        body:"Every enemy telegraphs its next move on the chip above its health bar: red for an attack (with the rough damage you'd take), purple for a spell, green for a heal, amber for a status effect. Intents are honest - and if you Stun, Root or Silence a foe, its chip greys out: that move is cancelled." },
        { id:"inspect",    title:"Inspect Your Foes",   body:"Mouse over an enemy (or its health bar) to inspect it. You'll see whether it fights at Melee or Ranged and with Phys or Spell - and which controls stop it: Root halts melee, Silence stops spells, Stun stops anything. Ranged foes ignore Root, so a trap won't keep them off you. Some families are IMMUNE to a status outright (undead shrug Poison, golems Bleed and Stun, spirits Root and Bleed, fire-kin Burn, frost-kin Chill) - the inspect box and the Bestiary list it." },
        { id:"weakness",   title:"Exposed Weaknesses",  body:"The small colored GEM beside an enemy's intent chip is the school it is WEAK to - Fire, Frost, Shock or Arcane. Hit it with a matching-school ability for +30% damage, and the FIRST weakness strike on each enemy refunds 1 AP. Carrying one off-school ability can pay for itself every fight." },
        { id:"vex",        title:"Vex the Trainer",     body:"Vex teaches new abilities and traits for gold (and the occasional item). Learn abilities here, then slot them on the loadout screen before a run." },
        { id:"shrine",     title:"Altars",              body:"A shrine is an altar. A Blessing altar sells boons for tribute - prices scale with your Awakening, and once per shrine [R] rerolls the offer for rune dust. A Cursed altar lets you take on a curse - a run-long penalty - in exchange for far better spoils. Loot-tier rewards lift drops as far as EPIC; a Legendary is never forced, only found. Choose how greedy you dare to be." },
        { id:"gold_risk",  title:"Gold at Risk",        body:"Gold you FIND during a run is at risk - die and you lose most of it (a quarter is returned as mercy). Gold banked before the run is always safe at camp. The number in brackets on your HUD is what you're gambling: extract to keep it all." },
        { id:"escape_item", title:"A Way Out",          body:"You carry an escape item. On the floor map, press G (or tap the LAMP / WINE button) to use it: the Genie Lamp whisks you back to camp with ALL your loot, free. Devil Wine does the same - but drains 2 random stat points. WARNING: the Wine's toll is PERMANENT - those points are gone from your hero on every future run, not just this one. Cash out a greedy run before the dungeon takes it back." },
        { id:"garden_scene", title:"Bairc's Garden",   body:"This is where your creatures live between runs. Look around: hold A / D or the arrow keys, DRAG with the mouse, swipe on touch, or push the left stick on a pad. Tap a creature (or press [E]) to pet it, [1]-[3] to toss crumbs, set a stone or forage, and [B] opens the ornament shop. The garden is early - big things are coming for decorating it." },
        { id:"origin_egg",  title:"Something Stirs",    body:"The egg you stumbled upon in your travels stirs - perhaps someone here can help with that. Bairc the beast-warden can identify and hatch it: find him on the camp carousel and set the egg under his care. A raised creature fights beside you, or blesses your runs." },
        { id:"bond_gates",  title:"Growing Closer",     body:"Someone in camp has warmed to you - their bond has reached a GATE. Crossing a gate now takes a FAVOR: talk to them and take on their gate quest (it appears on the tavern board and in your Journal). Finish it and the friendship deepens, unlocking their next perk. Mind your bonds: friendships DECAY if neglected, and only a few can hold the deepest tiers - deepening one may demote another." },
        { id:"maren_forge", title:"Rough Steel",       body:"Items drop UNFINISHED. The QUALITY tag shows how much of an item's true power it delivers right now.\nDorn's TEMPER tab raises that by +10% per step, for gold and rune dust. Each step also adds a little bonus max HP.\nA raw legendary barely beats a finished epic - always worth tempering what you love." },
        { id:"rune_caps",  title:"Aspect Runes Stack - to a Point", body:"Aspect runes socketed here ADD UP: three Hunter runes give three times the ranged accuracy. But each accuracy family is CAPPED - Hunter (ranged attacks) and Seer (spells) each stop at +12% total, so past that a fourth rune is wasted. The cap is printed on the rune and on the Accuracy line of your STATS page." },
        { id:"dormant_leg", title:"A Sleeping Legend", body:"You found a DORMANT legendary. It fell asleep when its last bearer died - it carries only a shadow of its true strength for now. Take it to Maren's AWAKEN craft (Runesmithing tab): 300g, 60 rune dust and two epics fed to the fire will wake it. Only the storied named legendaries are ever found awake." },
        { id:"dorn_reforge", title:"Reforge Ingots",   body:"You earned a REFORGE INGOT.\nSpend it at Dorn's to REROLL the affixes on a piece of unequipped gear - same item, fresh random stats.\nIngots are tiered by rarity. A higher-tier ingot works on anything at its tier or below.\nSMELTING gear at Dorn's pays an ingot back, so nothing is ever wasted." },
        { id:"legendary_forge", title:"Dorn's Forge",   body:"Two crafts live at this anvil.\nREWORK: spend a REFORGE INGOT of the item's tier or higher to reroll its affixes. Three ingots of one tier FUSE into one of the next.\nTHE LEGENDARY FORGE: gather three parts - Dorn's MYTHRIL FRAME, Maren's RUNEHEART CORE, and Sable's QUINTESSENCE - then return here to forge, and NAME, a legendary that exists nowhere else." },
        // First talent point earned mid-run (M 08-08). The web system was
        // invisible until you happened to open the loadout and notice a badge -
        // this fires once, in the fight where the first point lands, and its whole
        // job is to tell you the mechanic exists and to invite experimenting.
        // Traps became a board state on 08-08 - deploying one no longer does
        // anything visible on the turn you spend, so the first deploy has to
        // explain that the payoff is coming and what decides whether it lands.
        { id:"traps_deployed", title:"The Floor Is Yours", body:"That trap is SET, not thrown - it sits between you and them and waits. It springs on the first enemy action that matches it: a melee swing, a ranged shot, a spell, or anything at all. A trap that BLOCKS cancels the attack outright and eats their turn. Watch the enemy intent gems and set the trap that answers what they are about to do - a correct read is worth far more than the damage. You hold two traps at once, and your Preparation only refills while the board is EMPTY." },
        { id:"talent_first", title:"Mastery",           body:"You have cast that ability enough times to MASTER it - it just earned its first TALENT POINT. Back at camp, open the loadout screen: every ability has its own web of talents, and points are woven there to change how it works. Abilities earn points at 10, 30, 60 and 100 lifetime casts, so the ones you actually USE are the ones that deepen. Experiment - some talents are a subtle nudge, others rewrite the ability completely. Your Abilities tab tracks every ability under TALENTS." },
        { id:"corruption_101", title:"Corruption",      body:"A creature in your care is CORRUPTED. The bargain: while it pushes (3 survived runs as your active companion), YOU pay -20% max HP and -10% damage. Each pushed run adds a PERMANENT +15% to its passive gift. You may CURE it at Bairc's any time - the gains earned so far are kept, the burden lifts, but its grand power is forfeit. See it through all 3 runs and it fully corrupts: its gift is 45% stronger forever, the burden ends, and it earns a grand boon. The full table lives in the Compendium under Companions." },
        // The hidden price of full corruption (M-locked 08-15): deliberately
        // NOT mentioned in corruption_101 - it fires as a surprise reveal the
        // first time a pet fulfills.
        { id:"corruption_fulfilled", title:"What the Dark Keeps", body:"Your companion has FULLY CORRUPTED. Its gift is 45% stronger forever, its grand power is awake - and something else came through with it.\nThe dark holds a thread of its leash now: in any fight, there is a small chance (1 in 10) the corruption TURNS - a corrupted Warrior will savage YOU instead of the enemy, and any other companion may simply refuse to help while its eyes go black.\nBairc can still CURE it - the strength stays, the grand power is lost, and the thread is severed. Or keep the power, and live with what watches through it." },
        // Pattern Book (08-11): fires on the reforge tab once the Legendary
        // Forge coach-mark has been seen (one tutorial at a time).
        // NPC PROGRESSION (M 08-15): fires on the first camp arrival AFTER a run,
        // once the hub tip has had its turn - the STATION chip is on every card.
        { id:"station_ranks", title:"Station Ranks", body:"Every camp station can be INVESTED in - separately from friendship. On the carousel, each NPC's card wears a small STATION chip in its top-right corner: two pips, two ranks.\nRank 1 costs 300g + 20 rune dust, rank 2 costs 900g + 60 dust, and each rank unlocks a permanent service or bonus - Dorn stocks more and tempers hotter, Maren's combines ask less dust and she learns the DEEP SOCKET, Sable's brews come cheaper, Petra runs TWO trade orders at once, Bairc's pens slow hunger, and so on.\nHover the chip to read the exact perks, then press [U] or tap the chip to buy. Bond tiers stack their own discount on top: Friend 5%, Companion 10%, Lover 15%." },
        { id:"pattern_book", title:"The Pattern Book", body:"Dorn keeps a PATTERN BOOK.\nSMELT [T] destroys unequipped gear. You get a REFORGE INGOT of its tier, and Dorn STUDIES one affix from the piece - you pick which.\nONE study lets you craft that affix at UNCOMMON. 3 studies unlock RARE work, 6 unlock EPIC - and rarer fodder teaches faster (an Epic piece counts as 3 studies fresh).\nCRAFT [N] then builds an item to YOUR design - type, slot, quality, stats, affixes, art and name. Deeper study rolls better numbers, and unused affix slots BOOST the affixes you do take.\nBrowse the book any time with [B]." },
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

// shop_sell_price(item, npc_id) - the SELL-tab payout, ONE formula for the Step
// (what is paid) and the list draw (what is shown): 40% of gold_value (rarity
// fallback), legendaries x3 with a 1200 floor (M 08-04), +5%/affinity tier,
// Petra Trade Ledger rank 2 +10%. VALUABLES (08-17) have no buy price - their
// authored gold_value IS the payout, then the same affinity/rank sweeteners.
function shop_sell_price(item, npc_id) {
    var _gv = 0;
    if (is_struct(item) && variable_struct_exists(item, "gold_value")) _gv = item.gold_value;
    var _valuable = is_struct(item) && variable_struct_exists(item, "effect_type") && item.effect_type == "valuable" && _gv > 0;
    if (_gv == 0 && is_struct(item) && variable_struct_exists(item, "rarity")) {
        if (item.rarity == 0)      _gv = 15;
        else if (item.rarity == 1) _gv = 32;
        else if (item.rarity == 2) _gv = 82;
        else if (item.rarity == 3) _gv = 200;
        else                       _gv = 400;
    }
    var _base;
    if (_valuable) {
        _base = _gv;
    } else {
        if (is_struct(item) && variable_struct_exists(item, "rarity") && item.rarity == 4) _gv = max(_gv * 3, 1200);
        _base = _gv * 0.4;
    }
    var _tier = affinity_tier(npc_id);
    return max(1, floor(_base * (1 + 0.05 * _tier) * ((npc_rank("petra") >= 2) ? 1.10 : 1.0)));
}

// item_sell_value(item) - what a vendor pays for this item BEFORE affinity
// sweeteners: 40% of gold_value, with the shop's same rarity fallback ladder.
// Sacrifice pickers show THIS as the item's gold figure, so "what am I giving
// up" reads in the currency the player would actually get at Dorn/Petra
// (M 07-08: the picker showed full gold_value, which matches no real number).
function item_sell_value(item) {
    var _gv = 0;
    var _r  = (is_struct(item) && variable_struct_exists(item, "rarity")) ? clamp(item.rarity, 0, 4) : 0;
    var _base = [15, 32, 82, 200, 400];
    if (is_struct(item) && variable_struct_exists(item, "gold_value")) _gv = item.gold_value;
    // VALUABLES (08-17): sell-only trinkets with no buy price - the authored gold_value
    // IS the payout (40 / 120 / 320 / 750 / 1600). The 40% resale cut + rarity bands
    // below are for gear/consumables that were bought or found; applied here they
    // squashed a "steep gold" locket to 11g.
    if (is_struct(item) && variable_struct_exists(item, "effect_type") && item.effect_type == "valuable" && _gv > 0) return _gv;
    if (_gv == 0) _gv = _base[_r];
    // 08-11 (M: "why do some rares sell for more than epics?"): authored
    // per-item gold_values predate the rarity economy and could invert tiers.
    // Sell prices now live in strict per-rarity BANDS - floor is the tier's
    // baseline, cap is one under the next tier's floor - so ordering is
    // guaranteed while authored variance still matters inside the band.
    var _sell = floor(_gv * 0.4);
    var _lo   = floor(_base[_r] * 0.4);
    var _hi   = (_r < 4) ? floor(_base[_r + 1] * 0.4) - 1 : 100000;
    return clamp(_sell, max(1, _lo), _hi);
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
            var _val = item_sell_value(_it);
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
        var _val = item_sell_value(_it);
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

// --- Attunement Rebirth (Sable tab 3, M 07-29) -------------------------------
// Re-set an item's stat REQUIREMENT to a random OTHER stat (same value - the
// rarity curve). Gold-only and repeatable: a gamble you chase until the req
// suits the class that actually wants the item (M's Bloodwarden vs a 12-DEX
// Ashkeeper blade). Writes the explicit req_stat/req_value override that
// item_stat_requirement() honors above the computed default.
function statreq_rebirth_cost(rarity) {
    if (rarity >= 4) return cha_price(300);
    if (rarity >= 3) return cha_price(180);
    return cha_price(100);
}
function statreq_rebirth_pool() { return ["STR", "DEX", "INT", "CON"]; }
// Every held (unequipped) item that carries a stat requirement.
function item_picker_candidates_statreq() {
    var _out = [];
    var _in_hub = (room == rm_hub || room == rm_character_select);
    for (var _s = 0; _s < 2; _s++) {
        if (_s == 0 && !_in_hub) continue;
        var _arr = (_s == 0) ? global.equipment_stash : global.carried_items;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _it = _arr[_i];
            if (!is_struct(_it)) continue;
            var _rq = item_stat_requirement(_it);
            if (_rq.stat == "") continue;
            var _rar = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
            var _val = variable_struct_exists(_it, "gold_value") ? _it.gold_value : 0;
            var _nm  = variable_struct_exists(_it, "name") ? _it.name : "item";
            array_push(_out, { source:_s, idx:_i, item:_it,
                label:_nm + "  (asks " + _rq.stat + " " + string(_rq.value) + ")",
                rarity:_rar, value:_val });
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
    // Reforge re-CREATES the affix rows, so the weapon's damage-roll bias applies
    // here too - otherwise reforging a max-roll weapon would sidestep the tradeoff.
    apply_affixes_to_item(item, roll_affixes(min(_r, 3), _count, item_affix_exclusions(item), item.slot, _bn, weapon_damage_bias_t(item)));
    ach_unlock("ACH_REFORGED");   // achievement hook (08-05 wiring): a successful reforge
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
    if (_ac > 0) apply_affixes_to_item(_item, roll_affixes(min(_r, 3), _ac, item_affix_exclusions(_item), _item.slot, item_base_name(_item), weapon_damage_bias_t(_item)));
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
        case "chit_reforge": return "Choose an item - Dorn reworks its affixes (1 Reforge Ingot)";
        case "gift": return "Choose a gift for " + (variable_struct_exists(global.item_picker.context, "npc_name")
            ? global.item_picker.context.npc_name : "them");
        case "cartographer": return "Cartographer's Cut - choose which find to keep";
        case "courier": return "The courier waits - send a find home ("
            + string(variable_struct_exists(global.item_picker.context, "left")
                ? global.item_picker.context.left : 1) + " send"
            + ((variable_struct_exists(global.item_picker.context, "left")
                && global.item_picker.context.left == 1) ? "" : "s") + " left, Esc keeps carrying)";
        case "vex_potency": return "Offer an Epic or better item - "
            + (variable_struct_exists(global.item_picker.context, "trait_name")
                ? global.item_picker.context.trait_name : "the trait") + " will TRANSCEND";
        case "maren_sunder":   return "Choose a legendary to SUNDER - it becomes a Legendary Ingot + 50 dust + a tier-III rune";
        case "maren_temper":   return "Choose gear to TEMPER - Maren works it +10% toward its true potential";
        case "maren_awaken":   return "Choose a DORMANT legendary to AWAKEN (300g + 60 dust + 2 epics)";
        case "cursed_rebirth": return "An Inequivalent Exchange... feed a legendary to the dark";
        case "statreq_rebirth": return "Choose an item to RE-ATTUNE - its stat requirement re-sets to a random other stat";
        case "pb_smelt": return "Choose gear to SMELT (" + string(pattern_smelt_fee()) + "g) - destroyed for an ingot, a blueprint study and its art";
    }
    return "Choose an item";
}
function item_picker_verb() {
    switch (global.item_picker.purpose) {
        case "shrine_boon":  return "Sacrifice";
        case "alch_rebirth": return "Reforge";
        case "chit_reforge": return "Rework";
        case "gift":         return "Give";
        case "cartographer": return "Keep";
        case "courier":      return "Send home";
        case "vex_potency":  return "Offer";
        case "maren_sunder":   return "Sunder";
        case "maren_temper":   return "Temper";
        case "maren_awaken":   return "Awaken";
        case "cursed_rebirth": return "Sacrifice";
        case "statreq_rebirth": return "Re-attune";
        case "pb_smelt":       return "Smelt";
    }
    return "Trade away";
}

// Commit: remove the selected item, apply the purpose's effect, stash a one-shot
// result the owning controller reads for its notification + cleanup, then close.
function item_picker_resolve() {
    var _p    = global.item_picker;
    var _ctx  = _p.context;
    var _msg  = "";

    // CARTOGRAPHER'S CUT (POTENCY V2): nothing is removed - the player is
    // CHOOSING which fresh treasure find to keep. The floor controller grants
    // context.chosen when it consumes the one-shot.
    // PATTERN BOOK SMELT (08-11): nothing is removed HERE - the picker hands the
    // chosen item to Dorn's study popup (choose which affix family to learn from
    // it); destruction + fees happen at that popup's commit so backing out is free.
    if (_p.purpose == "pb_smelt") {
        var _pb_sel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                      ? _p.candidates[_p.cursor].item : undefined;
        _ctx.chosen         = _pb_sel;
        _p.resolved_purpose = "pb_smelt";
        _p.result_msg       = "";
        item_picker_close();
        return;
    }

    if (_p.purpose == "cartographer" || _p.purpose == "courier") {
        // Neither purpose removes anything here - the floor controller moves the
        // chosen item when it consumes the one-shot.
        var _cc_sel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                      ? _p.candidates[_p.cursor].item : undefined;
        var _cc_purpose = _p.purpose;
        _ctx.chosen         = _cc_sel;
        _p.resolved_purpose = _cc_purpose;
        _p.result_msg       = (_cc_sel != undefined)
            ? (((_cc_purpose == "courier") ? "Sent home: " : "Kept: ") + _cc_sel.name) : "";
        item_picker_close();
        return;
    }

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
        // Tier-or-higher: the item's rarity needs an ingot of that tier or better.
        var _rf_rar  = variable_struct_exists(_csel.item, "rarity") ? clamp(_csel.item.rarity, 0, 4) : 0;
        var _rf_tier = reforge_ingot_tier_for(_rf_rar);
        if (_rf_tier < 0) {
            _p.resolved_purpose = "chit_reforge";
            _p.result_msg = "No " + item_rarity_name(_rf_rar) + "-tier (or higher) Reforge Ingot - smelting and the tavern board pay them.";
            item_picker_close(); return;
        }
        var _old_cname = _csel.label;
        var _rf_prev   = clone_item(_csel.item);   // pre-rework snapshot for the reveal
        if (!chit_reforge_item(_csel.item)) {
            _p.resolved_purpose = "chit_reforge"; _p.result_msg = "That item has no affixes to rework.";
            item_picker_close(); return;
        }
        var _rf_spent = reforge_ingot_spend(_rf_rar);
        save_game();
        _p.resolved_purpose = "chit_reforge";
        _p.result_msg = "Dorn reworks " + _old_cname + " into " + _csel.item.name + "!   (spent a "
            + item_rarity_name(_rf_spent) + " ingot)";
        forge_result_open("DORN'S REWORK", "The hammer falls - the metal remembers new shapes.",
            _csel.item, _rf_prev,
            ["Spent a " + item_rarity_name(_rf_spent) + " Reforge Ingot"],
            make_color_rgb(228, 160, 90));
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
        discover_item(item_base_name(_new), _new.rarity);
        save_game();
        _p.resolved_purpose = "alch_rebirth";
        _p.result_msg = "Reforged " + _old_name + " into " + _new.name + "!";
        forge_result_open("CLASS REBIRTH", "Melted down... and remade for other hands.",
            _new, _sel.item, [], make_color_rgb(190, 220, 195));
        audio_play_sound(snd_confirm_major, 1, false);   // a rebirth deserves the chime
        item_picker_close();
        return;
    }

    // ATTUNEMENT REBIRTH (M 07-29): nothing is destroyed - the chosen item's
    // stat requirement re-sets to a random OTHER stat at the same value. Random,
    // so chasing a specific stat may take several pulls (the intended gamble).
    if (_p.purpose == "statreq_rebirth") {
        var _sq_sel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                      ? _p.candidates[_p.cursor] : undefined;
        if (_sq_sel == undefined) {
            _p.resolved_purpose = "statreq_rebirth"; _p.result_msg = "Nothing chosen.";
            item_picker_close(); return;
        }
        var _sq_it = _sq_sel.item;
        var _sq_rq = item_stat_requirement(_sq_it);
        if (_sq_rq.stat == "") {
            _p.resolved_purpose = "statreq_rebirth"; _p.result_msg = "That item asks nothing of its wearer.";
            item_picker_close(); return;
        }
        var _sq_fee = statreq_rebirth_cost(variable_struct_exists(_sq_it, "rarity") ? _sq_it.rarity : 2);
        if (global.gold < _sq_fee) {
            _p.resolved_purpose = "statreq_rebirth";
            _p.result_msg = "Not enough - re-attuning asks " + string(_sq_fee) + "g.";
            audio_play_sound(snd_ui_error, 1, false);
            item_picker_close(); return;
        }
        var _sq_pool = statreq_rebirth_pool();
        var _sq_opts = [];
        for (var _sq_i = 0; _sq_i < array_length(_sq_pool); _sq_i++) {
            if (_sq_pool[_sq_i] != _sq_rq.stat) array_push(_sq_opts, _sq_pool[_sq_i]);
        }
        var _sq_new = _sq_opts[irandom(array_length(_sq_opts) - 1)];
        global.gold -= _sq_fee;
        _sq_it.req_stat  = _sq_new;
        _sq_it.req_value = _sq_rq.value;
        // 08-04 (M): remaking an item re-rolls its LOOK - the saved icon_seed
        // shifts the variant hash (ui_icon_item_key) to a fresh model.
        _sq_it.icon_seed = irandom(999983);
        save_game();
        _p.resolved_purpose = "statreq_rebirth";
        _p.result_msg = _sq_it.name + " re-attunes - it now asks " + _sq_new + " " + string(_sq_rq.value) + ".";
        forge_result_open("ATTUNEMENT REBIRTH", "The item re-learns whose hands it answers.",
            _sq_it, undefined,
            ["Now asks:  " + _sq_new + " " + string(_sq_rq.value),
             "Asked before:  " + _sq_rq.stat + " " + string(_sq_rq.value)],
            make_color_rgb(160, 200, 235));
        audio_play_sound(snd_confirm_major, 1, false);
        item_picker_close();
        return;
    }

    // MAREN TEMPER (08-04 tempering, SYSTEMS_ITEM_PROGRESSION §1): +10% quality
    // toward 100, gold + dust by rarity. The item is MUTATED in place (like
    // re-attune) - nothing is removed.
    if (_p.purpose == "maren_temper") {
        var _tp_sel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                      ? _p.candidates[_p.cursor] : undefined;
        if (_tp_sel == undefined) {
            _p.resolved_purpose = "maren_temper"; _p.result_msg = "Nothing chosen.";
            item_picker_close(); return;
        }
        var _tp_it  = _tp_sel.item;
        var _tp_fee = temper_fee(_tp_it);
        if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
        if (global.gold < _tp_fee.gold || global.rune_dust < _tp_fee.dust) {
            _p.resolved_purpose = "maren_temper";
            _p.result_msg = "Tempering asks " + string(_tp_fee.gold) + "g + " + string(_tp_fee.dust) + " dust.";
            audio_play_sound(snd_ui_error, 1, false);
            item_picker_close(); return;
        }
        global.gold      -= _tp_fee.gold;
        global.rune_dust -= _tp_fee.dust;
        // Snapshot BEFORE the mutation - the reveal popup runs after it (M 08-08).
        var _tp_was = item_shallow_copy(_tp_it);
        _tp_it.quality = min(100, (variable_struct_exists(_tp_it, "quality") ? _tp_it.quality : 100) + 10);
        // No icon_seed re-roll here (M 08-11): tempering never changes a piece's look.
        save_game();
        _p.resolved_purpose = "maren_temper";
        _p.result_msg = _tp_it.name + " tempered to " + string(_tp_it.quality) + "%"
            + ((_tp_it.quality >= 100) ? " - FINISHED." : ".");
        forge_result_open("TEMPERED", (_tp_it.quality >= 100)
                ? "The metal finally sings its whole note."
                : "Closer to what it was always meant to be.",
            _tp_it, _tp_was, [],
            make_color_rgb(200, 170, 110));
        audio_play_sound(snd_forge, 1, false);
        item_picker_close();
        return;
    }

    // MAREN AWAKEN (08-04 dormant legendaries, §2): 300g + 60 dust + 2 epics
    // wake a dormant legendary to its true strength.
    if (_p.purpose == "maren_awaken") {
        var _aw_sel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                      ? _p.candidates[_p.cursor] : undefined;
        if (_aw_sel == undefined) {
            _p.resolved_purpose = "maren_awaken"; _p.result_msg = "Nothing chosen.";
            item_picker_close(); return;
        }
        var _aw_it  = _aw_sel.item;
        var _aw_eps = cursed_rebirth_gear_of_rarity(3, _aw_it);
        if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
        if (global.gold < 300 || global.rune_dust < 60 || array_length(_aw_eps) < 2) {
            _p.resolved_purpose = "maren_awaken";
            _p.result_msg = "Awakening asks 300g + 60 dust + 2 epics to burn in the forge.";
            audio_play_sound(snd_ui_error, 1, false);
            item_picker_close(); return;
        }
        // REAGENT STAGE (M 08-05: "all item selections are manual"): nothing
        // burns here - the player picks exactly which epics fuel the forge on
        // the next screen. The awakening happens in maren_awaken_commit().
        reagent_picker_open_awaken(_aw_sel);
        audio_play_sound(snd_page, 1, false);
        item_picker_close();
        return;
    }

    // MAREN SUNDER (M 07-28 legendary sinks): split a legendary into parts -
    // 1 Legendary Reforge Ingot + 50 rune dust + a random tier-III rune.
    if (_p.purpose == "maren_sunder") {
        var _ms_sel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                      ? _p.candidates[_p.cursor] : undefined;
        if (_ms_sel == undefined) {
            _p.resolved_purpose = "maren_sunder"; _p.result_msg = "Nothing chosen.";
            item_picker_close(); return;
        }
        var _ms_name = _ms_sel.label;
        item_picker_remove_selected();
        reforge_ingots_ensure();
        global.reforge_ingots[4] += 1;
        if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
        global.rune_dust += 50;
        var _ms_rn = rune_make(sable_transmute_roll_id(), 3);
        array_push(global.rune_inventory, _ms_rn);
        save_game();
        _p.resolved_purpose = "maren_sunder";
        _p.result_msg = "Sundered " + _ms_name + " - a Legendary Ingot, 50 dust and " + rune_title(_ms_rn) + " remain.";
        forge_result_open("SUNDERED", _ms_name + " breaks along its oldest seam.",
            undefined, undefined,
            ["+1 Legendary Reforge Ingot", "+50 Rune Dust", "+  " + rune_title(_ms_rn)],
            make_color_rgb(150, 110, 220));
        audio_play_sound(snd_confirm_major, 1, false);
        item_picker_close();
        return;
    }

    // SABLE CURSED REBIRTH (M 07-28 legendary sinks; first slice of the parked
    // cursed-items feature): the legendary returns STRONGER, but branded with a
    // real curse. Gate: 300g fee, checked before anything is destroyed.
    if (_p.purpose == "cursed_rebirth") {
        var _cr_sel = (_p.cursor >= 0 && _p.cursor < array_length(_p.candidates))
                      ? _p.candidates[_p.cursor] : undefined;
        if (_cr_sel == undefined) {
            _p.resolved_purpose = "cursed_rebirth"; _p.result_msg = "Nothing chosen.";
            item_picker_close(); return;
        }
        // Escalating reassemblage (M 08-04): gold + potions + gear essence, all
        // scaling x1.5 per curse already on the offering. The detail pane
        // previews this exact ask before the picker's confirm arms.
        var _cr_fee = cursed_rebirth_fee(_cr_sel.item);
        var _cr_pts = cursed_rebirth_pts_avail(_cr_sel.item);
        var _cr_pn  = (variable_global_exists("consumable_inventory") && is_array(global.consumable_inventory))
                      ? array_length(global.consumable_inventory) : 0;
        if (global.gold < _cr_fee.gold || _cr_pts < _cr_fee.uncommons || _cr_pn < _cr_fee.potions) {
            _p.resolved_purpose = "cursed_rebirth";
            _p.result_msg = "Not enough - the dark asks " + string(_cr_fee.gold) + "g + "
                + string(_cr_fee.potions) + " potions + " + string(_cr_fee.epics) + " epic"
                + ((_cr_fee.epics == 1) ? "" : "s") + " (or " + string(_cr_fee.rares) + " rares / "
                + string(_cr_fee.uncommons) + " uncommons, mixed freely).";
            audio_play_sound(snd_ui_error, 1, false);
            item_picker_close(); return;
        }
        // REAGENT STAGE (M 08-05): nothing burns here - the player picks exactly
        // which gear + potions feed the dark on the next screen. The rebirth
        // itself happens in cursed_rebirth_commit().
        reagent_picker_open(_cr_sel);
        audio_play_sound(snd_page, 1, false);
        item_picker_close();
        return;
    }

    var _name = item_picker_remove_selected();
    switch (_p.purpose) {
        case "vex_trait":
            global.gold -= _ctx.gold;
            vex_first_buy_consume();   // Drill Regimen: first buy each visit
            if (!variable_global_exists("traits_unlocked")) global.traits_unlocked = {};
            variable_struct_set(global.traits_unlocked, _ctx.effect_id, true);
            affinity_add("vex", 2);   // function-use drip (trait unlock)
            save_game();
            _msg = "Unlocked " + _ctx.trait_name + "!   (traded: " + _name + ")";
            break;
        case "vex_potency":
            // POTENCY V2 rank 5: the Transcend offering - one Epic+ item.
            if (!variable_global_exists("trait_potency")) global.trait_potency = {};
            variable_struct_set(global.trait_potency, _ctx.trait_name, 5);
            affinity_add("vex", 2);   // function-use drip (transcendence)
            save_game();
            _msg = _ctx.trait_name + " TRANSCENDS - " + _ctx.tname + "!   (offered: " + _name + ")";
            audio_play_sound(snd_confirm_major, 1, false);
            break;
        case "vex_stat":
            global.gold -= _ctx.gold;
            vex_first_buy_consume();   // Drill Regimen: first buy each visit
            variable_global_set(_ctx.stat_key, variable_global_get(_ctx.stat_key) + 1);
            global.vex_stat_buys = vex_stat_buys() + 1;   // drives the price ladder
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

    if (input_cancel() || input_back()
        || mouse_check_button_pressed(mb_right)) {
        if (_p.confirm) _p.confirm = false;
        else            item_picker_close();
        return;
    }

    if (_n == 0) {   // nothing qualifies (shouldn't happen - caller pre-checks) - let any key close
        if (input_confirm() || input_confirm_alt()) item_picker_close();
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

    var _act = (input_confirm() || input_confirm_alt());

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
// success/fail). Outcomes apply an `effects` struct. HP changes apply LIVE to
// run_current_hp (M 07-28) - the floor HUD reads it, so both heals and damage
// show the moment they land; damage floors at 1 (events can't kill outright).
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
    // POTENCY V2 ranks: +3% per rank on top of the base 5.
    var _sense_bonus = trait_active("Sense") ? (5 + 3 * trait_potency_r14("Sense")) : 0;
    // Sharp Eye pet capstone (C5): a further +10% - it sees the angles.
    // Long Watch (nightowl innate, 08-01): +5% on the same channel.
    return clamp(base_pct + _sense_bonus + pet_active_sharpeye() + pet_active_innate("event") + (_s - ref) * per_point, 10, 90);
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
    // Curse loot-tiers are a post-roll rarity bump now, not an awakening offset
    // (applied per-source via curse_loot_tier_bonus_for at the item roll below).
    var _asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
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
    // HP - both directions apply immediately (the floor HUD reads
    // run_current_hp; deferred changes read as broken/invisible - M 07-28).
    if (variable_struct_exists(fx, "hp") && fx.hp != 0) {
        if (fx.hp > 0) {
            var _ev_max = out_of_combat_max_hp();
            if (!variable_global_exists("run_current_hp") || global.run_current_hp <= 0) global.run_current_hp = _ev_max;
            var _ev_before = global.run_current_hp;
            global.run_current_hp = min(_ev_max, global.run_current_hp + fx.hp);
            array_push(_sum, "+" + string(global.run_current_hp - _ev_before) + " HP");
        } else {
            // M 07-28: damage lands LIVE like heals do - the floor HUD drops on
            // the spot with a hurt grunt + map shake (floor controller reads
            // event_hp_hit). Same floor-at-1 rule the old next-combat consume
            // used (combat Create), so events still can't kill outright.
            var _ev_dmax = out_of_combat_max_hp();
            if (!variable_global_exists("run_current_hp") || global.run_current_hp <= 0) global.run_current_hp = _ev_dmax;
            var _ev_dbefore = global.run_current_hp;
            global.run_current_hp = max(1, global.run_current_hp - abs(fx.hp));
            var _ev_dtaken = _ev_dbefore - global.run_current_hp;
            array_push(_sum, "-" + string(_ev_dtaken) + " HP");
            global.event_hp_hit = _ev_dtaken;   // floor controller: grunt + shake + floating -N
        }
    }
    // Equipment item - fx.item is a drop-source string ("chest"/"vault"/...)
    if (variable_struct_exists(fx, "item") && fx.item != "") {
        if (!variable_global_exists("run_items_found")) global.run_items_found = [];
        if (!variable_global_exists("carried_items"))   global.carried_items   = [];
        var _ev_w = drop_weights(fx.item, _asc);
        // Optional rarity floor (fx.item_min, rarity index): an event that CHARGES
        // for gear or promises a tier must deliver at least that tier regardless of
        // awakening - 79g for a 70%-common roll read as a scam (M 07-08). Weights
        // below the floor pour into the floor tier.
        if (variable_struct_exists(fx, "item_min") && fx.item_min > 0) {
            var _ev_spill = 0;
            for (var _ewi = 0; _ewi < fx.item_min; _ewi++) { _ev_spill += _ev_w[_ewi]; _ev_w[_ewi] = 0; }
            _ev_w[fx.item_min] += _ev_spill;
        }
        var _it = drop_equipment(_ev_w, true, curse_loot_tier_bonus_for(fx.item));
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
        // [COMPANION] tag (08-18): the result panel tints + enlarges tagged lines so a
        // pet find can't hide in the prose (M: "no idea when I got this young adult").
        array_push(_sum, "[COMPANION] " + (_pe.is_egg
            ? ("A mysterious egg - " + _pe.name + " - waits at Bairc's")
            : ("A living " + _pe.name + " (" + pet_stage_name(_pe.stage) + ")"
               + (_pe.corrupted ? ", CORRUPTED," : "") + " follows you to Bairc's")));
        var _pe_msg = _pe.is_egg
            ? ("You recovered a " + _pe.name + " egg - visit Bairc.")
            : ("A " + _pe.name + " follows you home - visit Bairc.");
        // APPEND (08-18): a second find in the same run used to overwrite the first.
        global.pet_find_notice = (variable_global_exists("pet_find_notice") && global.pet_find_notice != "")
            ? (global.pet_find_notice + "   " + _pe_msg) : _pe_msg;
        // M 07-28 spectacle: the floor controller fires the sparkle celebration
        // + sting off this one-shot so the find can't slip by unnoticed.
        global.event_pet_found = _pe;
    }
    // Borrowed Memory (expression #6; 07-16 combo batch: now a pick-1-of-3 DRAFT -
    // the offer is stashed here and the floor controller opens the choice screen
    // right after this event's result closes).
    if (variable_struct_exists(fx, "memory") && fx.memory) {
        var _bm_offer = borrowed_memory_offer(3);
        if (array_length(_bm_offer) > 0) {
            global.borrowed_offer = _bm_offer;
            array_push(_sum, "BORROWED MEMORIES stir - choose one to keep (this run)");
        } else {
            array_push(_sum, "the memory slips away...");
        }
    }
    // Borrowed Memory draft pick (the second screen's choice lands here).
    if (variable_struct_exists(fx, "memory_pick") && fx.memory_pick != "") {
        global.run_borrowed_ability = fx.memory_pick;
        global.run_borrowed_class   = variable_struct_exists(fx, "memory_pick_class") ? fx.memory_pick_class : "";
        array_push(_sum, "BORROWED MEMORY: " + fx.memory_pick + " (" + global.run_borrowed_class + " - this run)");
    }
    // The Ashen Duelist: arm the duel - the floor controller launches the 1v1
    // combat when this event's result screen closes.
    if (variable_struct_exists(fx, "duel") && fx.duel) {
        global.duel_launch = true;
        array_push(_sum, "THE DUEL BEGINS  -  PAR: " + string(duel_turn_par()) + " TURNS");
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
    // Merchant's Ghost popup shop (M-locked 08-15): builds the spectral stock;
    // the floor controller opens the shop overlay when this result closes
    // (borrowed-memory pattern).
    if (variable_struct_exists(fx, "ghost_shop") && fx.ghost_shop) {
        ghost_shop_build_stock();
        array_push(_sum, "The cart unfolds - shelves that were not there a breath ago...");
    }
    // Carried sickness (Wounded Wanderer, M 08-14): fx.sicken = poison dmg/turn
    // the player carries into the NEXT fight (applied in obj_combat_controller
    // Create via global.pending_sickness, 3 turns).
    if (variable_struct_exists(fx, "sicken") && fx.sicken > 0) {
        global.pending_sickness = fx.sicken;
        array_push(_sum, "You feel feverish - you will start your next fight POISONED");
    }

    var _str = "";
    for (var _i = 0; _i < array_length(_sum); _i++) _str += (_i > 0 ? "\n" : "") + _sum[_i];
    return _str;
}

// =============================================================================
// MERCHANT'S GHOST SHOP (M-locked 08-15). Stock = rare+ loot rolled ONE tier
// above the current awakening, a decent chance of a hand-authored GHOST
// EXCLUSIVE (found nowhere else), and strong runes. Prices carry a haunted
// discount vs Dorn (x2.4 vs his x3.2). global.ghost_stock rows:
//   { kind:"item"|"rune", item|rune, price, sold }
// =============================================================================
function ghost_exclusive_catalog(_asc) {
    // Awakening-banded authored pieces, stamped ghost_exclusive.
    var _band = (_asc >= 4) ? 2 : ((_asc >= 2) ? 1 : 0);
    var _out = [];
    // create_item() ships no affixes array - every ghost piece carries one
    // authored affix, so give each its array first (08-16 crash: ".affixes not
    // set" the first time the ghost opened his shop).
    if (_band == 0) {
        var _g1 = create_item("Lantern-Keeper's Cowl", "helm", 2, "WIS", 4,
            "a hood that remembers every toll road it ever walked", 90);
        _g1.affixes = [{ suffix: "of Greed", prefix: "Waxlit", stat_name: "gold_find", stat_value: 8 }];
        array_push(_out, _g1);
        var _g2 = create_item("Coin-Weighted Knuckles", "gloves", 2, "STR", 4,
            "the peddler settled more than one debt by hand", 90);
        _g2.affixes = [{ suffix: "of Ruin", prefix: "Weighted", stat_name: "crit_flat", stat_value: 2 }];
        array_push(_out, _g2);
    } else if (_band == 1) {
        var _g3 = create_item("Ghostlight Buckler", "offhand", 2, "CON", 5,
            "it glows faintly where the last owner's hand should be", 130);
        _g3.affixes = [{ suffix: "of Slipping", prefix: "Ghostlit", stat_name: "dodge_flat", stat_value: 3 }];
        array_push(_out, _g3);
        var _g4 = create_item("The Peddler's Last Ring", "ring", 3, "CHA", 5,
            "sold a hundred times, returned a hundred and one", 210);
        _g4.affixes = [{ suffix: "of the Hollow Sale", prefix: "Returned", stat_name: "gold_find", stat_value: 10 }];
        array_push(_out, _g4);
    } else {
        var _g5 = create_item("Cart-Axle Maul", "weapon", 3, "STR", 6,
            "the axle of the cart that never stops arriving", 260);
        _g5.weapon_damage = weapon_base_damage(3);
        _g5.two_handed    = true;
        _g5.affixes = [{ suffix: "of Ruin", prefix: "Axle-Forged", stat_name: "crit_flat", stat_value: 3 }];
        array_push(_out, _g5);
        var _g6 = create_item("Receipt of the Unpaid Debt", "amulet", 3, "INT", 6,
            "someone, somewhere, still owes - and the amulet remembers", 260);
        _g6.affixes = [{ suffix: "of Greed", prefix: "Countersigned", stat_name: "gold_find", stat_value: 12 }];
        array_push(_out, _g6);
    }
    for (var _i = 0; _i < array_length(_out); _i++) {
        var _gi = _out[_i];
        _gi.base_name       = _gi.name;
        _gi.class_req       = -1;
        _gi.ghost_exclusive = true;
        _gi.socket_count    = rune_sockets_for_rarity(_gi.rarity);
        item_quality_stamp(_gi, 58, 78);   // 08-18 quality nerf (ghost exclusives)
    }
    return _out;
}

function ghost_shop_build_stock() {
    var _asc  = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    var _rows = [];
    // 3 rolled pieces, rare floor (M 08-18 retune: the stall used to roll ALL
    // three from one awakening above with the full legendary weight - at A4/A5
    // that read as a legendary vending machine). Now: two at your CURRENT
    // awakening + ONE from the tier above, and legendaries stay a rare surprise
    // (weight capped at 2%, the rest folds into epic).
    for (var _gr = 0; _gr < 3; _gr++) {
        var _gw = drop_weights("reliquary", (_gr == 2) ? min(5, _asc + 1) : _asc, _asc);
        var _spill = _gw[0] + _gw[1];
        _gw[0] = 0; _gw[1] = 0; _gw[2] += _spill;    // rare+ only
        var _leg = min(_gw[4], 2);
        _gw[3] += _gw[4] - _leg; _gw[4] = _leg;      // legendary <= 2%
        var _it = drop_equipment(_gw, false);
        item_quality_stamp(_it, 52, 74);   // 08-18 quality nerf (ghost)
        array_push(_rows, { kind: "item", item: _it,
            price: max(1, floor(_it.gold_value * 2.4)), sold: false });
    }
    // ALWAYS one hand-authored ghost-exclusive from the awakening band (M 08-18:
    // "more hand authored epics and rares as at least 1 item").
    var _ex = ghost_exclusive_catalog(_asc);
    if (array_length(_ex) > 0) {
        var _pick = _ex[irandom(array_length(_ex) - 1)];
        array_push(_rows, { kind: "item", item: _pick,
            price: max(1, floor(_pick.gold_value * 2.4)), sold: false });
    }
    // 2 runes: Tier II (160g). Tier III is otherwise craft-only at Maren, so the
    // ghost only carries ONE - from awakening 5 - at 1000g (M 08-18).
    for (var _gk = 0; _gk < 2; _gk++) {
        var _rt = (_asc >= 5 && _gk == 0) ? 3 : 2;
        var _rn = rune_make(rune_random(_rt).id, _rt);
        array_push(_rows, { kind: "rune", rune: _rn,
            price: (_rt >= 3) ? 1000 : 160, sold: false });
    }
    global.ghost_stock = _rows;
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

    // THE ASHEN DUELIST (DESIGN_DUELIST_CHALLENGE.md): a hidden ~8% override on
    // the event roll - never floor 1, at most once per run. No map icon, no
    // catalog entry: every meeting is a surprise.
    if (!variable_global_exists("duel_offered_this_run")) global.duel_offered_this_run = false;
    // F10 test lever (gc Step): forces this event to be the duel and bypasses
    // the once-per-run gate so win + loss are testable in a single run.
    var _force_duel = variable_global_exists("debug_force_duel") && global.debug_force_duel;
    if (global.current_floor >= 2
        && (_force_duel || (!global.duel_offered_this_run && irandom(99) < 8))) {
        if (_force_duel) global.debug_force_duel = false;
        global.duel_offered_this_run = true;
        _chosen = duelist_event();
    }

    // Silvered Tongue blessing (Shrine V2, 07-29): every event offers one extra,
    // honeyed way through - a CHA-checked coax appended as a 4th row (every event
    // authors exactly 3; four rows end at y930, still clear of the footer).
    // The Ashen Duelist is exempt - "blades only" brooks no honeyed third way.
    if (boon_active("silvertongue") && _chosen.id != "ashen_duelist" && array_length(_chosen.choices) <= 3) {
        var _st_fl    = clamp(global.current_floor - 1, 0, 2);
        var _st_golds = [35, 55, 85];
        var _st_dusts = [4, 6, 9];
        var _st_gold  = _st_golds[_st_fl];
        var _st_dust  = _st_dusts[_st_fl];
        array_push(_chosen.choices, {
            label: "Invoke the Silvered Tongue", hint: "CHA check - your blessed voice coaxes a parting gift from the moment",
            cost_gold: 0, req_stat: "", req_amount: 0, resolve: "check",
            check_stat: "CHA", check_base: 55, check_per: 6, check_ref: 5,
            success: { text: "The words land like struck silver. Something is pressed into your hands before the moment closes.",
                       effects: { gold: _st_gold, dust: _st_dust } },
            fail:    { text: "The silver rings false this once. The moment closes politely, and empty.",
                       effects: {} } });
    }
    return _chosen;
}

// =============================================================================
// THE ASHEN DUELIST (DESIGN_DUELIST_CHALLENGE.md, M-locked 07-29). A recurring
// rival: strict 1v1 with a turn PAR, graded rewards, a token ladder (Duelist
// Arts at Vex), and a mercy loss - his killing blow stops at 1 HP, he heals you
// to room-entry HP, and it is NEVER a death (Iron Vow safe). He grows +10% per
// lifetime duel fought (global.duelist_encounters, meta-persistent) and never
// retires. Rolled as a hidden event override (see event_roll).
// =============================================================================

// Turn PAR by awakening tier (M-locked): A0-A1: 7, A2-A3: 6, A4-A5: 5.
function duel_turn_par() {
    var _asc = variable_global_exists("selected_ascendance") ? clamp(global.selected_ascendance, 0, 5) : 0;
    if (_asc >= 4) return 5;
    if (_asc >= 2) return 6;
    return 7;
}

// The challenge event struct (not in the catalog - event_roll overrides with it).
function duelist_event() {
    var _enc = variable_global_exists("duelist_encounters") ? global.duelist_encounters : 0;
    var _body = (_enc == 0)
        ? "A figure waits in the empty hall, blade drawn and lowered. Ash-grey coat, unhurried eyes. \"Blades only. No pets, no gods, no debts. Beat me before the " + string(duel_turn_par()) + "th bell and take what I carry.\""
        : ((_enc >= 5)
            ? "The Ashen Duelist again - of course. The salute is almost warm now. \"You again. Good. I've been practicing.\""
            : "The Ashen Duelist waits, blade already drawn. \"So the stories keep growing. Show me they aren't short by half.\"");
    return {
        id: "ashen_duelist",
        title: "The Ashen Duelist",
        body: _body,
        color: make_color_rgb(205, 125, 95),
        choices: [
            { label: "Accept the duel", hint: "A strict 1v1 - your companion sits out. Beat the PAR of " + string(duel_turn_par()) + " turns for his finest prize",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100,
                  text: "He salutes, and the hall goes quiet as a held breath. \"Begin.\"",
                  effects: { duel: true } } ] },
            { label: "Decline with a nod", hint: "He bears no grudge - walk away freely",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100,
                  text: "He returns the nod and steps back into the gloom. \"Another bell, then.\"",
                  effects: {} } ] }
        ]
    };
}

// The Ashen Blade - the Duelist's own sword, handed over with the 3rd token.
// Built here at the grant site only; it lives in NO drop pool. Sent straight to
// the stash so a later death this run can never take it back.
function duelist_make_ashen_blade() {
    var _b = create_item("The Ashen Blade", "weapon", 4, "DEX", 5,
        "his own sword, worn to a whisper of grey", 400);
    _b.class_req     = -1;
    _b.affixes       = [{ suffix: "of the Answer", prefix: "Ashen", stat_name: "crit_flat", stat_value: 2 }];
    _b.unique_effect = "ashen_blade";
    _b.unique_desc   = "After you dodge or riposte, your next ability costs 1 less AP";
    _b.lore = "He carried it through every duel he never lost, and handed it over the day someone finally deserved it. The edge is patient - it learned long ago that the reply matters more than the first word.";
    return _b;
}

// DUELING RELICS ladder (M design-locked 08-11, backlog #23): unique drops at
// total duel WINS 1 / 3 / 5 - ANY grade counts, unlike the GOLD-only token
// ARTS ladder above. Granted at the duel-victory frame, sent to the stash.
function duelist_relic_for_win(_w) {
    if (_w == 1) {
        var _r = create_item("Duelist's Iron Pin", "amulet", 3, "DEX", 4,
            "worn where a second would stand", 200);
        _r.class_req     = -1;
        _r.affixes       = [];
        _r.unique_effect = "duel_pin";
        _r.unique_desc   = "+15% crit chance while exactly one enemy stands";
        _r.lore = "The pin that held his cloak through a hundred single combats. It only wakes when the fight is honest: one blade, one answer.";
        return _r;
    }
    if (_w == 3) {
        var _r2 = create_item("Ashen Parry Dagger", "offhand", 3, "DEX", 5,
            "it answers before you do", 260);
        _r2.class_req     = -1;
        _r2.affixes       = [{ suffix: "of Shadows", prefix: "Ghost", stat_name: "dodge_flat", stat_value: 4 }];
        _r2.unique_effect = "duel_parry";
        _r2.unique_desc   = "Melee blows that hit you are answered for 8 damage";
        _r2.lore = "His off-hand tutor, retired into yours. It has heard every opening line a sword can offer and grown bored of all of them.";
        return _r2;
    }
    if (_w == 5) {
        var _r3 = create_item("Widowmaker's Point", "weapon", 4, "DEX", 6,
            "the conversation ends here", 400);
        _r3.class_req     = -1;
        _r3.affixes       = [{ suffix: "of Ruin", prefix: "Runed", stat_name: "crit_flat", stat_value: 2 }];
        _r3.unique_effect = "duel_widow";
        _r3.unique_desc   = "+40% damage to enemies below 25% HP";
        _r3.lore = "Five duels he lost to you, and on the fifth he brought this - and lost anyway. It knows exactly one thing: how a fight that is already decided should end.";
        return _r3;
    }
    return undefined;
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

    // --- 3. Wounded Wanderer (M 08-14 rework: the risk of tending is CATCHING
    // their sickness - you start the next fight poisoned - not a flat HP toll) --
    var _ww_gold = [30, 50, 80];
    var _ww_dust = [3, 4, 6];
    var _ww_sick = [3, 4, 5];   // poison dmg/turn carried into the next fight
    var _ww_rob  = [45, 70, 110];
    array_push(_cat, {
        id: "wounded_wanderer",
        title: "Wounded Wanderer",
        body: "A ragged figure slumps against the wall, clutching a wound and a heavy satchel.",
        color: make_color_rgb(90, 200, 120),
        choices: [
            { label: "Tend their wounds", hint: "They may repay you well - but you might catch what they have",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [
                { weight: 50, text: "They recover, and press coin and dust into your hands.",
                  effects: { gold: _ww_gold[_fl], dust: _ww_dust[_fl] } },
                { weight: 20, text: "They were no mere wanderer - a fragment of power passes to you.",
                  effects: { boon: "random" } },
                { weight: 30, text: "They recover and pay you - but by nightfall their fever has found you too.",
                  effects: { gold: _ww_gold[_fl], dust: _ww_dust[_fl], sicken: _ww_sick[_fl] } } ] },
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

    // --- 6. Merchant's Ghost (M-locked 08-15 rework, retuned 08-18: a POPUP SHOP
    // of rare wares - two rolls at your awakening + one above, legendaries capped
    // at 2%, ALWAYS one ghost-exclusive, Tier II runes (one Tier III from A5) -
    // hand-authored pieces, and strong runes; browse and buy as you like) ----
    array_push(_cat, {
        id: "merchants_ghost",
        title: "Merchant's Ghost",
        body: "A translucent peddler tips a spectral hat, wares shimmering on a phantom cart.",
        color: make_color_rgb(100, 160, 230),
        choices: [
            { label: "Browse the wares", hint: "The dead keep the best stock - and haunted prices",
              cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
              outcomes: [ { weight: 100, text: "The peddler sweeps a sheet from the cart with a flourish only bones can manage.",
                            effects: { ghost_shop: true } } ] },
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
                            effects: { item: "vault", item_min: 2, gold: _cs_gold[_fl] } } ] },
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
        // Atmosphere pass sections 2-3 (SOUND_ATMOSPHERE_SPEC.md, 07-14): per-
        // dungeon beds + title bed + hub station loops, all under Music.
        snd_amb_ashen, snd_amb_scorched, snd_amb_tundra, snd_amb_title,
        snd_amb_forge, snd_amb_cauldron, snd_amb_garden, snd_amb_tavern,
        // Banshee-unlocked jukebox tracks (BANSHEE_BOTTLE_SPEC.md, 07-15;
        // hub_3/4/5 = Hearthlight / Moth & Lantern / The Wake, dungeon_2/3 =
        // Blood and Iron / Kingsfall - all M-approved 07-16).
        snd_music_hub_1, snd_music_hub_2, snd_music_dungeon_1,
        snd_music_hub_3, snd_music_hub_4, snd_music_hub_5,
        snd_music_dungeon_2, snd_music_dungeon_3,
        snd_music_dungeon_4,   // Nocturne (gothic piano, M-approved 07-17)
        snd_music_hub_6,       // Tempest Road (07-17, dual-pool)
        mus_garden_zen,        // "Stillwater" - Bairc's Garden default loop (M-approved 08-15)
        // Garden pool banshee unlocks + the gothic-opera dungeon piece (all
        // M-approved 08-15 from auditioned samples).
        mus_garden_shire,      // "Greenhollow"
        mus_garden_hook,       // "Tidesong"
        mus_garden_retro,      // "Garden of Ages"
        mus_dungeon_opera,     // "The Black Aria" (dungeon pool)
    ];
}

// =============================================================================
// BANSHEE IN A BOTTLE - unlockable music tracks (BANSHEE_BOTTLE_SPEC.md, 07-15)
// A very rare run find: guaranteed on each dungeon's FINAL boss (first kill per
// save) + a small chest-site chance. Rides the run (die = lost, extract/clear =
// banked); Maren's Spirits tab releases one for a random not-yet-owned track,
// or a Rune Dust bounty once every track is owned. Selected tracks replace the
// default hub / dungeon music via the Settings selectors (per-save).
// =============================================================================

// The track catalog is code-side truth; saves store track IDS only. pool gates
// which Settings selector row a track appears under ("hub" / "dungeon").
function music_track_catalog() {
    return [
        { id: "hub_rainlight", name: "Rainlight",     pool: "hub",     snd: snd_music_hub_1 },
        { id: "hub_emberside", name: "Emberside",     pool: "hub",     snd: snd_music_hub_2 },
        { id: "dun_longdark",  name: "The Long Dark", pool: "dungeon", snd: snd_music_dungeon_1 },
        // M-approved from the 07-16 sample rounds. Fulls generated with explicit
        // evolving-section structure per M ("diversity and variance within the
        // song so the listener doesn't tire"). GraveDancer concept = parked.
        { id: "hub_hearthlight", name: "Hearthlight",    pool: "hub",     snd: snd_music_hub_3 },
        { id: "hub_mothlantern", name: "Moth & Lantern", pool: "hub",     snd: snd_music_hub_4 },
        { id: "dun_bloodiron",   name: "Blood and Iron", pool: "dungeon", snd: snd_music_dungeon_2 },
        { id: "dun_kingsfall",   name: "Kingsfall",      pool: "dungeon", snd: snd_music_dungeon_3 },
        { id: "hub_thewake",     name: "The Wake",       pool: "hub",     snd: snd_music_hub_5 },
        // 07-17: M's gothic-virtuoso piano ask ("somber but many notes, at times
        // fast tempo, Castlevania") - approved from sample, dungeon pool.
        { id: "dun_nocturne",    name: "Nocturne",       pool: "dungeon", snd: snd_music_dungeon_4 },
        // 07-17: Tempest Road = swirling minor-key waltz x flamenco desert
        // (Zelda storms/valley homage). M ruled it pool "both": one unlock,
        // selectable as hub AND dungeon music. (Its sibling Drums of the Deep
        // was cut entirely - "boring and monotonous".)
        { id: "hub_tempestroad", name: "Tempest Road",    pool: "both",    snd: snd_music_hub_6 },
        // GARDEN pool (08-15, M: "all songs are banshee bottles"): unlocked by
        // released spirits like every other track, selected via the garden's
        // [M] chip. The garden's DEFAULT ("Stillwater", mus_garden_zen) lives
        // outside the catalog, like Rainy_Memories does for the hub.
        { id: "gar_greenhollow",  name: "Greenhollow",    pool: "garden",  snd: mus_garden_shire },
        { id: "gar_tidesong",     name: "Tidesong",       pool: "garden",  snd: mus_garden_hook },
        { id: "gar_gardenofages", name: "Garden of Ages", pool: "garden",  snd: mus_garden_retro },
        // The gothic-opera battle piece (M-approved 08-15) joins the DUNGEON
        // pool as an unlockable.
        { id: "dun_blackaria",    name: "The Black Aria", pool: "dungeon", snd: mus_dungeon_opera },
    ];
}

// Ensure every banshee/jukebox global exists (tolerant defaults for old saves
// and the title screen, where no slot is loaded yet).
function banshee_init() {
    if (!variable_global_exists("banshee_carried"))    global.banshee_carried    = 0;   // run-scoped, never saved
    if (!variable_global_exists("banshee_banked"))     global.banshee_banked     = 0;   // stash-side, saved
    if (!variable_global_exists("banshee_boss_drops")) global.banshee_boss_drops = {};  // dungeon_key -> true once granted
    if (!variable_global_exists("music_unlocked"))     global.music_unlocked     = [];  // array of catalog ids
    if (!variable_global_exists("music_sel_hub"))      global.music_sel_hub      = "";  // "" = default track
    if (!variable_global_exists("music_sel_dungeon"))  global.music_sel_dungeon  = "";
    if (!variable_global_exists("music_sel_garden"))   global.music_sel_garden   = "";  // garden scene (08-15)
}

function music_track_by_id(track_id) {
    var _c = music_track_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        if (_c[_i].id == track_id) return _c[_i];
    }
    return undefined;
}

function music_track_owned(track_id) {
    banshee_init();
    // TEST LEVER (F8, gc Step): every track reads owned while the toggle is on.
    if (variable_global_exists("debug_unlock_all") && global.debug_unlock_all) return true;
    // (M 08-15 second ruling: garden tracks are banshee unlocks like every
    // other song - the earlier always-owned exception is gone. The garden's
    // DEFAULT, Stillwater, lives outside the catalog like Rainy_Memories.)
    for (var _i = 0; _i < array_length(global.music_unlocked); _i++) {
        if (global.music_unlocked[_i] == track_id) return true;
    }
    return false;
}

// True when a track belongs to the given pool. pool "both" tracks (M 07-17,
// Tempest Road) count for hub AND dungeon - one unlock covers both selectors
// (but never the garden pool, which is its own commissioned set).
function music_pool_match(track_pool, pool) {
    return (track_pool == pool) || (track_pool == "both" && pool != "garden");
}

// Unlocked catalog entries for one pool, catalog order (drives the selector rows).
function music_pool_unlocked(pool) {
    banshee_init();
    var _out = [];
    var _c = music_track_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        if (music_pool_match(_c[_i].pool, pool) && music_track_owned(_c[_i].id)) array_push(_out, _c[_i]);
    }
    return _out;
}

// The selected catalog entry for a pool, or undefined for the default music.
// Validates ownership so a stale/foreign selection can never silence the game.
function music_selected_track(pool) {
    banshee_init();
    var _sel = (pool == "hub") ? global.music_sel_hub
             : ((pool == "garden") ? global.music_sel_garden : global.music_sel_dungeon);
    if (_sel == "") return undefined;
    var _t = music_track_by_id(_sel);
    if (_t == undefined || !music_pool_match(_t.pool, pool) || !music_track_owned(_sel)) {
        if (pool == "hub")         global.music_sel_hub     = "";
        else if (pool == "garden") global.music_sel_garden  = "";
        else                       global.music_sel_dungeon = "";
        return undefined;
    }
    return _t;
}

// The sound asset the GARDEN scene should loop (selection or Stillwater).
function music_garden_snd() {
    var _t = music_selected_track("garden");
    return (_t == undefined) ? mus_garden_zen : _t.snd;
}
// Stop every garden-pool track (default included - it IS in the pool).
function music_garden_stop() {
    audio_stop_sound(mus_garden_zen);
    var _c = music_track_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        if (music_pool_match(_c[_i].pool, "garden")) audio_stop_sound(_c[_i].snd);
    }
}

// The sound asset the hub should loop (selection or the Rainy_Memories default).
function music_hub_snd() {
    var _t = music_selected_track("hub");
    return (_t == undefined) ? Rainy_Memories : _t.snd;
}

// Stop whatever hub music is playing - default AND every hub-pool track - so
// the scattered leave-hub stop sites never need to know about the catalog.
function music_hub_stop() {
    audio_stop_sound(Rainy_Memories);
    var _c = music_track_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        if (music_pool_match(_c[_i].pool, "hub")) audio_stop_sound(_c[_i].snd);
    }
}

// Stop all dungeon-floor music (default intro/loop pair + custom tracks).
function music_dungeon_stop() {
    audio_stop_sound(_2_dungeon_INITIAL);
    audio_stop_sound(_2_dungeon_LOOP);
    var _c = music_track_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        if (music_pool_match(_c[_i].pool, "dungeon")) audio_stop_sound(_c[_i].snd);
    }
}

// Live-apply after a Settings selector change: restart the relevant music only
// if it is playing RIGHT NOW (hub room / dungeon floor). Elsewhere the change
// simply takes effect on the next room entry.
function music_selection_apply(pool) {
    if (pool == "garden") {
        // Live-swap only while actually standing in the garden scene.
        if (instance_exists(obj_game_controller)) {
            var _ga_gc = instance_find(obj_game_controller, 0);
            if (variable_instance_exists(_ga_gc, "garden_open") && _ga_gc.garden_open) {
                music_garden_stop();
                audio_play_sound(music_garden_snd(), 1, true);
                audio_apply_volumes();
            }
        }
        return;
    }
    if (pool == "hub" && room == rm_hub) {
        music_hub_stop();
        audio_play_sound(music_hub_snd(), 1, true);
    } else if (pool == "dungeon" && room == rm_dungeon_floor) {
        music_dungeon_stop();
        var _t = music_selected_track("dungeon");
        if (_t != undefined) {
            audio_play_sound(_t.snd, 1, true);
            if (instance_exists(obj_floor_controller)) instance_find(obj_floor_controller, 0).dungeon_music_looping = true;
        } else {
            // Back to the default pair: skip the intro mid-floor, just loop.
            audio_play_sound(_2_dungeon_LOOP, 1, true);
            if (instance_exists(obj_floor_controller)) instance_find(obj_floor_controller, 0).dungeon_music_looping = true;
        }
    }
}

// Settings selector: cycle a pool's selection by dir (+1/-1) through
// [Default, ...unlocked tracks in catalog order]. Returns true if it changed
// (false when the pool has nothing unlocked yet - the row is inert).
function music_selection_cycle(pool, dir) {
    var _pool = music_pool_unlocked(pool);
    var _n = array_length(_pool);
    if (_n == 0) return false;
    var _cur = music_selected_track(pool);
    var _idx = 0;   // 0 = Default, 1.._n = _pool[_idx-1]
    if (_cur != undefined) {
        for (var _i = 0; _i < _n; _i++) if (_pool[_i].id == _cur.id) { _idx = _i + 1; break; }
    }
    _idx = wrap_index(_idx + dir, _n + 1);
    var _new_id = (_idx == 0) ? "" : _pool[_idx - 1].id;
    if (pool == "hub")         global.music_sel_hub     = _new_id;
    else if (pool == "garden") global.music_sel_garden  = _new_id;
    else                       global.music_sel_dungeon = _new_id;
    music_selection_apply(pool);
    return true;
}

// Chest-site roll (treasure/vault/reliquary): ~4%, nudged by the active pet's
// LCK loot bonus, capped well under "expected". Increments the carried count -
// the bottle rides the run from here (end_run ALWAYS banks it - M 08-15:
// bottles survive death; they're too rare to shatter with the haul).
function banshee_chest_try() {
    banshee_init();
    // M 08-15: 4% -> 6% base, LCK feeds it +1% per 3 points (was per 5).
    // Cap raised 8 -> 12 to keep the same luck headroom over the new base.
    var _chance = min(12, 6 + floor(pet_active_lck_loot_pts() / 3));
    if (irandom(99) >= _chance) return false;
    global.banshee_carried++;
    find_banner_push("banshee", "Banshee in a Bottle",
        "A corked bottle, faintly wailing - Maren can free the song at camp.", asset_get_index("spr_icon_banshee_bottle"));
    return true;
}

// Maren release: consume one banked bottle, roll a random NOT-yet-owned track
// (both pools, equal weight). Returns { kind:"track", track } on an unlock or
// { kind:"dust", amount } once every track is owned (the 25-dust bounty).
function banshee_release_roll() {
    banshee_init();
    if (global.banshee_banked <= 0) return undefined;
    global.banshee_banked--;
    var _locked = [];
    var _c = music_track_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        if (!music_track_owned(_c[_i].id)) array_push(_locked, _c[_i]);
    }
    if (array_length(_locked) == 0) {
        var _bounty = 25;
        global.rune_dust += _bounty;
        return { kind: "dust", amount: _bounty };
    }
    var _t = _locked[irandom(array_length(_locked) - 1)];
    array_push(global.music_unlocked, _t.id);
    return { kind: "track", track: _t };
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
    return [snd_amb_rain, snd_amb_cave, snd_amb_torch,
            snd_amb_ashen, snd_amb_scorched, snd_amb_tundra, snd_amb_title,
            // Hub station loops are Step-driven (hub_station_ambience_update),
            // but they live in this list so room-change ambience_set calls
            // sweep them up if a station flag somehow survives a transition.
            snd_amb_forge, snd_amb_cauldron, snd_amb_garden, snd_amb_tavern];
}

// Which ambience bed the selected dungeon breathes (spec section 2). The old
// shared snd_amb_cave bed is retired - each dungeon has its own air.
function dungeon_ambience_bed() {
    var _d = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
    switch (_d) {
        case "scorched_depths": return snd_amb_scorched;
        case "tundra_tomb":     return snd_amb_tundra;
        default:                return snd_amb_ashen;
    }
}

// HUB STATION FLAVOR (spec section 3): a short quiet loop while that NPC screen
// is open. Called from obj_game_controller's Step TOP (before any modal exit)
// so the *_open instance flags are in scope every frame; loops self-stop the
// frame a screen closes, and room-change ambience_set calls are the backstop.
function hub_station_ambience_update() {
    var _hub = (room == rm_hub || room == rm_character_select);
    var _want_forge    = _hub && (shop_open == 1);   // Dorn only - Petra's stall gets no loop
    var _want_cauldron = _hub && sable_open;
    var _want_garden   = _hub && (bairc_open || bairc_intro_open);
    var _want_tavern   = _hub && (tavern_board_open
        || (variable_instance_exists(id, "kb_open") && kb_open));   // board + Knucklebones/High Table
    var _loops = [[snd_amb_forge, _want_forge], [snd_amb_cauldron, _want_cauldron],
                  [snd_amb_garden, _want_garden], [snd_amb_tavern, _want_tavern]];
    for (var _i = 0; _i < array_length(_loops); _i++) {
        var _snd = _loops[_i][0];
        var _want = _loops[_i][1];
        if (_want && !audio_is_playing(_snd)) audio_play_sound(_snd, 0, true);
        else if (!_want && audio_is_playing(_snd)) audio_stop_sound(_snd);
    }
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
        // Loot dopamine suite (SOUND_ATMOSPHERE_SPEC.md section 1, 07-14)
        snd_loot_common, snd_loot_uncommon, snd_loot_rare, snd_loot_epic,
        snd_loot_legendary, snd_loot_unique, snd_loot_reveal, snd_loot_reveal_2,
        snd_dice_roll, snd_dice_roll_2, snd_dice_roll_3, snd_dice_shake,
        snd_dice_place, snd_dice_place_2, snd_kb_capture, snd_kb_payout, snd_kb_payout_2,
        snd_player_atk, snd_player_atk_2, snd_player_atk_3, snd_miss, snd_miss_2,
        snd_player_hurt, snd_player_hurt_2,
        snd_attack_undead, snd_death_undead, snd_attack_wraith, snd_death_wraith,
        snd_attack_construct, snd_death_construct, snd_attack_beast, snd_attack_beast_2,
        snd_death_beast, snd_attack_fire, snd_death_fire, snd_attack_ice, snd_death_ice,
        snd_attack_boss, snd_attack_boss_2, snd_death_boss,
        snd_cast_elem, snd_cast_elem_2, snd_cast_void, snd_cast_void_2, snd_cast_blood, snd_cast_blood_2,
        snd_cast_arcane, snd_cast_arcane_2, snd_cast_heal, snd_cast_shield,
        snd_cast_buff, snd_cast_buff_2, snd_cast_debuff,
        // Per-school ability cast SFX (07-17) - split the single snd_cast_elem so
        // fire/frost/shock/arcane/nature no longer sound identical. 2 takes each -> _2.
        snd_cast_fire, snd_cast_fire_2, snd_cast_frost, snd_cast_frost_2,
        snd_cast_shock, snd_cast_shock_2, snd_cast_nature, snd_cast_nature_2,
        snd_sting_levelup, snd_sting_floor, snd_sting_victory, snd_sting_defeat,
        snd_sting_quest, snd_sting_mystery,
        snd_banshee_scream,   // release-ceremony wail (BANSHEE_BOTTLE_SPEC.md)
        // (snd_sting_heartbreak retired 07-14 - snd_betrayal replaced it at the
        // betrayal site; the asset stays in the project but never plays.)
        snd_equip, snd_buy, snd_pet_hatch,
        // Atmosphere pass section 4 - moment stingers (SOUND_ATMOSPHERE_SPEC.md)
        snd_shrine_hum, snd_curse_whisper, snd_curse_laugh, snd_egg_stir, snd_hatch_burst,
        snd_hatch_build, snd_hatch_fanfare,   // Zelda-chest hatch crescendo (M 07-16)
        snd_awakened_cross, snd_bond_up, snd_extract, snd_boss_door,
        snd_betrayal, snd_quest_ready,
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
    if (!variable_global_exists("settings_cursor"))      global.settings_cursor      = 0;   // 0 Music, 1 SFX, 2 Hub Track, 3 Dungeon Track, 4 Menu Tick, 5 Fullscreen, 6 Font Size, 7 Tutorial, 8 D-pad, 9 Pinch, 10 Reset
    if (!variable_global_exists("settings_reset_flash")) global.settings_reset_flash = 0;
    if (!variable_global_exists("tutorial_enabled"))     global.tutorial_enabled     = true;
    if (!variable_global_exists("ui_tick_enabled"))      global.ui_tick_enabled      = true;   // the menu-nav glass ping
    if (!variable_global_exists("font_size_mode"))       global.font_size_mode       = 1;      // 0 Small, 1 Default, 2 Large (ui_font)

    if (!variable_global_exists("settings_loaded")) {
        global.settings_loaded = true;
        ini_open("settings.ini");
        global.music_volume     = clamp(ini_read_real("audio", "music", global.music_volume), 0, 1);
        global.sfx_volume       = clamp(ini_read_real("audio", "sfx",   global.sfx_volume),   0, 1);
        // Tutorial-tips preference lives here too so it persists from the title
        // (where no save slot is loaded). 1 = enabled (default), 0 = disabled.
        global.tutorial_enabled = (ini_read_real("ui", "tutorial_tips", 1) >= 0.5);
        global.ui_tick_enabled  = (ini_read_real("ui", "menu_tick", 1) >= 0.5);
        global.font_size_mode   = clamp(floor(ini_read_real("ui", "font_size", 1)), 0, 2);
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
    ini_write_real("ui", "font_size",
        variable_global_exists("font_size_mode") ? global.font_size_mode : 1);
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
    // Atmosphere-pass beds are loudness-normalized at import (M 07-14: raw gens
    // were "barely audible"), so these trims are the ONLY quiet-maker - raise
    // here first if F5 says a bed still doesn't read.
    audio_sound_gain(snd_amb_ashen,    _mv * 0.55, 0);
    audio_sound_gain(snd_amb_scorched, _mv * 0.55, 0);
    audio_sound_gain(snd_amb_tundra,   _mv * 0.55, 0);
    audio_sound_gain(snd_amb_title,    _mv * 0.55, 0);
    audio_sound_gain(snd_amb_forge,    _mv * 0.50, 0);
    audio_sound_gain(snd_amb_cauldron, _mv * 0.50, 0);
    audio_sound_gain(snd_amb_garden,   _mv * 0.50, 0);
    audio_sound_gain(snd_amb_tavern,   _mv * 0.50, 0);
    // Banshee jukebox tracks ride the flat music gain (they ARE the music).
    audio_sound_gain(snd_music_hub_1,     _mv, 0);
    audio_sound_gain(snd_music_hub_2,     _mv, 0);
    audio_sound_gain(snd_music_dungeon_1, _mv, 0);
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
// its own input). W/S pick a row, A/D or <-/-> adjust sliders / cycle tracks /
// toggle, Esc/O closes. Row order matches ui_draw_settings_overlay (8 rows).
function audio_settings_handle_input() {
    audio_settings_init();
    video_settings_init();
    touch_settings_init();

    // Tick down the "tutorial reset" confirmation flash (drawn by the overlay).
    if (variable_global_exists("settings_reset_flash") && global.settings_reset_flash > 0) {
        global.settings_reset_flash--;
    }

    // Rows: 0 Music, 1 SFX, 2 Hub Music, 3 Dungeon Music, 4 Menu Tick,
    //       5 Fullscreen, 6 Font Size, 7 Tutorial Tips, 8 On-screen D-pad,
    //       9 Pinch Zoom, 10 Reset Tutorial.
    // Rows 8-9 exist only on touch platforms (see touch_platform) - the cursor
    // hops over them on desktop/HTML5, where the rows aren't drawn.
    if (nav_up()) {
        global.settings_cursor = wrap_index(global.settings_cursor - 1, 11);
        if (!touch_platform() && (global.settings_cursor == 8 || global.settings_cursor == 9)) global.settings_cursor = 7;
    }
    if (nav_down()) {
        global.settings_cursor = wrap_index(global.settings_cursor + 1, 11);
        if (!touch_platform() && (global.settings_cursor == 8 || global.settings_cursor == 9)) global.settings_cursor = 10;
    }
    global.settings_cursor = clamp(global.settings_cursor, 0, 10);
    if (!touch_platform() && (global.settings_cursor == 8 || global.settings_cursor == 9)) global.settings_cursor = 10;

    var _left    = nav_left();
    var _right   = nav_right();
    var _confirm = input_confirm() || input_confirm_alt();

    switch (global.settings_cursor) {
        case 0: // Music
            if (_left)  audio_settings_adjust(0, -0.05);
            if (_right) audio_settings_adjust(0,  0.05);
        break;
        case 1: // Sound Effects
            if (_left)  audio_settings_adjust(1, -0.05);
            if (_right) audio_settings_adjust(1,  0.05);
        break;
        case 2: // Hub Music track selector (banshee unlocks; per-save selection)
        case 3: // Dungeon Music track selector
            if (_left || _right) {
                var _ms_pool = (global.settings_cursor == 2) ? "hub" : "dungeon";
                if (music_selection_cycle(_ms_pool, _right ? 1 : -1)) {
                    audio_play_sound(snd_ui_move, 1, false);
                    // Selection is progression, not preference: it lives in the SAVE
                    // (settings.ini is slot-agnostic). No slot loaded (title) = inert row.
                    if (variable_global_exists("save_slot") && global.save_slot >= 0) save_game();
                } else {
                    audio_play_sound(snd_ui_error, 1, false);   // nothing unlocked in this pool yet
                }
            }
        break;
        case 4: // Menu Tick (the nav glass ping) on/off
            if (_left || _right || _confirm) {
                global.ui_tick_enabled = !global.ui_tick_enabled;
                // Turning it ON previews the tick itself; OFF gets the toggle thunk.
                audio_play_sound(global.ui_tick_enabled ? snd_ui_move : snd_ui_toggle_off, 1, false);
                audio_settings_save();
            }
        break;
        case 5: // Fullscreen
            if (_left || _right || _confirm) {
                video_toggle_fullscreen();
                audio_play_sound(window_get_fullscreen() ? snd_ui_toggle_on : snd_ui_toggle_off, 1, false);
            }
        break;
        case 6: // Font Size: A/D cycles Small / Default / Large (Enter steps forward)
            if (_left || _right || _confirm) {
                var _fs_delta = _left ? -1 : 1;
                global.font_size_mode = wrap_index(global.font_size_mode + _fs_delta, 3);
                audio_play_sound(snd_ui_move, 1, false);
                audio_settings_save();
            }
        break;
        case 7: // Tutorial Tips on/off
            if (_left || _right || _confirm) {
                if (!variable_global_exists("tutorial_enabled")) global.tutorial_enabled = true;
                global.tutorial_enabled = !global.tutorial_enabled;
                audio_play_sound(global.tutorial_enabled ? snd_ui_toggle_on : snd_ui_toggle_off, 1, false);
                audio_settings_save();
            }
        break;
        case 8: // On-screen D-pad: A/D sizes it, Enter toggles it off/on entirely
            if (_left)  { touch_pad_scale_adjust(-TOUCH_PAD_SCALE_STEP); audio_play_sound(snd_ui_move, 1, false); }
            if (_right) { touch_pad_scale_adjust( TOUCH_PAD_SCALE_STEP); audio_play_sound(snd_ui_move, 1, false); }
            if (_confirm) {
                touch_gamepad_toggle();
                audio_play_sound(global.touch_gamepad_off ? snd_ui_toggle_off : snd_ui_toggle_on, 1, false);
            }
        break;
        case 9: // Pinch Zoom on/off (SYSTEMS_PINCH_ZOOM.md; touch platforms only)
            if (_left || _right || _confirm) {
                pinch_zoom_toggle();
                audio_play_sound(global.pinch_zoom_off ? snd_ui_toggle_off : snd_ui_toggle_on, 1, false);
            }
        break;
        case 10: // Reset Tutorial - clear seen flags so every tip shows again
            if (_left || _right || _confirm) {
                tutorial_reset_all();
                global.tutorial_enabled   = true;   // resetting implies you want the tips back
                global.settings_reset_flash = 120;
                audio_settings_save();
            }
        break;
    }

    // Esc / O always closes (Enter is reserved for the toggle/action rows above).
    if (input_cancel() || input_hotkey("O")) {
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

// Pause menu rows - shared by pause_menu_step and ui_draw_pause_menu so the
// hit-test and the drawn list can never drift. "Save Game" appears ONLY at the
// hub: saves are hub-gated (never mid-run), and M 07-27 asked for an explicit
// save so a hub chore session can end without running a dungeon to bank it.
function pause_menu_options() {
    if (room == rm_hub) return ["Resume", "Save Game", "Settings", "Quit to Title"];
    return ["Resume", "Settings", "Quit to Title"];
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

    var _opts      = pause_menu_options();
    var _opt_count = array_length(_opts);
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
    if (input_cancel() || input_back()) {
        global.pause_open = false;
        return true;
    }

    var _confirm = input_confirm() || input_confirm_alt() || (mouse_check_button_pressed(mb_left) && _hover != -1);
    if (_confirm) {
        // Dispatch on the LABEL, not the index - the row list is dynamic
        // ("Save Game" only exists at the hub).
        switch (_opts[global.pause_cursor]) {
            case "Resume":
                global.pause_open = false;
                break;
            case "Save Game":   // hub only (saves are hub-gated)
                save_game();
                global.pause_saved_time = current_time;   // "Game saved." flash in the draw
                audio_play_sound(snd_ui_confirm, 1, false);
                break;
            case "Settings":    // opens over the pause menu, returns here on close
                audio_settings_init();
                global.settings_cursor = 0;
                global.settings_open   = true;
                break;
            case "Quit to Title":
                global.pause_open = false;
                pause_quit_to_title();
                break;
        }
    }
    return true;
}

// Drop any open persistent-controller overlays and return to the title screen.
// Saves only from the hub (meta-progression is already banked there). A run in
// progress is CHECKPOINTED, not abandoned (IRONMAN save & quit - the same
// protection Android backgrounding gets; SYSTEMS_RUN_RESUME.md): loading the
// slot force-resumes the dive, so quitting can never bank or dodge anything.
function pause_quit_to_title() {
    if (room == rm_hub && variable_global_exists("save_slot") && global.save_slot >= 0) {
        save_game();
    }
    run_checkpoint_write_now();   // no-op outside a run or once combat is over

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

    // Abandon any in-progress run. Without this, quitting to title mid-run left
    // loadout_confirmed + the floor/run globals on the persistent gc - loading ANY
    // save (or making a new character) afterwards and pressing Enter Dungeon
    // skipped dungeon-select/loadout and dropped the player onto the stale run's
    // floor (07-14 report). Helper lives in scr_save next to load_game.
    run_state_reset();

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

// =============================================================================
// TOUCH SETTINGS - on-screen d-pad enable + SIZE, persisted in settings.ini
// ([touch] section). Slot-agnostic like audio/video. M 07-18 on the S25: the
// shipped d-pad was "too small and too close together" - the size is now a
// player-facing slider because the right number is device- and thumb-dependent
// and can't be guessed from here. Default 1.25 = M's "25% bigger" baseline.
// =============================================================================
#macro TOUCH_PAD_SCALE_DEF 1.25
#macro TOUCH_PAD_SCALE_MIN 0.80
#macro TOUCH_PAD_SCALE_MAX 2.00
#macro TOUCH_PAD_SCALE_STEP 0.15

function touch_settings_init() {
    if (!variable_global_exists("touch_gamepad_off")) global.touch_gamepad_off = false;
    if (!variable_global_exists("touch_pad_scale"))   global.touch_pad_scale   = TOUCH_PAD_SCALE_DEF;
    if (!variable_global_exists("pinch_zoom_off"))    global.pinch_zoom_off    = false;

    if (!variable_global_exists("touch_loaded")) {
        global.touch_loaded = true;
        ini_open("settings.ini");
        global.touch_gamepad_off = (ini_read_real("touch", "gamepad_off", 0) >= 0.5);
        global.touch_pad_scale   = clamp(ini_read_real("touch", "pad_scale", TOUCH_PAD_SCALE_DEF),
                                         TOUCH_PAD_SCALE_MIN, TOUCH_PAD_SCALE_MAX);
        // Pinch zoom (SYSTEMS_PINCH_ZOOM.md): stored as pinch_zoom 1=ON (default).
        global.pinch_zoom_off    = (ini_read_real("touch", "pinch_zoom", 1) < 0.5);
        ini_close();
    }
}

// Persist the touch prefs. Called after any change so a crash never loses them.
function touch_settings_save() {
    ini_open("settings.ini");
    ini_write_real("touch", "gamepad_off", global.touch_gamepad_off ? 1 : 0);
    ini_write_real("touch", "pad_scale",   global.touch_pad_scale);
    ini_write_real("touch", "pinch_zoom",  global.pinch_zoom_off ? 0 : 1);
    ini_close();
}

// Flip pinch zoom off/on (Settings row). Turning it OFF hard-resets the
// transform to 1.0 so a player can never be stranded zoomed-in with the
// gesture disabled (locked decision #2).
function pinch_zoom_toggle() {
    touch_settings_init();
    global.pinch_zoom_off = !global.pinch_zoom_off;
    touch_settings_save();
    if (global.pinch_zoom_off && variable_global_exists("zoom")) {
        global.zoom.z = 1;  global.zoom.vx = 0;  global.zoom.vy = 0;
        global.zoom.active = false;
        zoom_apply();
    }
}

// Nudge the d-pad size by delta (the settings row passes +/- TOUCH_PAD_SCALE_STEP).
function touch_pad_scale_adjust(delta) {
    touch_settings_init();
    global.touch_pad_scale = clamp(global.touch_pad_scale + delta,
                                   TOUCH_PAD_SCALE_MIN, TOUCH_PAD_SCALE_MAX);
    touch_settings_save();
}

// Flip the on-screen d-pad off/on (Settings row; direct tap always still works).
function touch_gamepad_toggle() {
    touch_settings_init();
    global.touch_gamepad_off = !global.touch_gamepad_off;
    touch_settings_save();
}

// ============================================================================
// STEAM ACHIEVEMENTS (2026-08-04, ACHIEVEMENTS_SPEC.md - design-locked 63).
// EXTENSION-SAFE: GMEXT-Steamworks may not be installed yet, so every Steam
// call resolves DYNAMICALLY (asset_get_index + script_execute). This compiles
// and silently no-ops on builds without the extension (Android / itch / IDE
// before the import) - the counters still accumulate so nothing is lost.
// achievements_sync() derives every state-based achievement from live save
// state (also the retro-grant path for existing players); one-shot event
// achievements call ach_unlock() at their sites. Per-achievement wiring
// status: ACHIEVEMENTS_SPEC.md.
// ============================================================================

function ach_available() {
    var _init = asset_get_index("steam_initialised");
    if (_init == -1) return false;
    return script_execute(_init);
}

function ach_unlock(_api) {
    // Session-level dedup only: Steam itself dedups re-sets server-side, so a
    // fresh session harmlessly re-sends anything already earned.
    if (!variable_global_exists("ach_session_sent")) global.ach_session_sent = {};
    if (variable_struct_exists(global.ach_session_sent, _api)) return;
    if (!ach_available()) return;
    var _set = asset_get_index("steam_set_achievement");
    if (_set == -1) return;
    script_execute(_set, _api);
    global.ach_session_sent[$ _api] = true;
}

// Lifetime counters that no existing system tracks. Saved as one guarded
// optional struct (scr_save) - absent on older saves, healed here.
function ach_counters_init() {
    if (!variable_global_exists("ach_counters")) global.ach_counters = {};
    var _c = global.ach_counters;
    if (!variable_struct_exists(_c, "crits"))           _c.crits = 0;
    if (!variable_struct_exists(_c, "detonations"))     _c.detonations = 0;
    if (!variable_struct_exists(_c, "board_done"))      _c.board_done = 0;
    if (!variable_struct_exists(_c, "species_hatched")) _c.species_hatched = [];
    if (!variable_struct_exists(_c, "scions_hatched"))  _c.scions_hatched = [];
    // Journal form reveals (M 08-13): max stage ever reached per species, so
    // the Creatures tab only shows the forms you have actually raised.
    if (!variable_struct_exists(_c, "species_stage_max") || !is_struct(_c.species_stage_max)) _c.species_stage_max = {};
    if (!variable_global_exists("ach_run_absorbed"))    global.ach_run_absorbed = 0;  // run-scoped, reset at run start
}

// Record a hatch into the lifetime species sets (called from pet_hatch).
function ach_record_hatch(_pet) {
    ach_counters_init();
    var _sp  = (is_struct(_pet) && variable_struct_exists(_pet, "species")) ? _pet.species : "";
    if (_sp == "") return;
    var _c = global.ach_counters;
    var _have = false;
    for (var _i = 0; _i < array_length(_c.species_hatched); _i++)
        if (_c.species_hatched[_i] == _sp) { _have = true; break; }
    if (!_have) array_push(_c.species_hatched, _sp);
    // Form reveal (M 08-13): a hatch reveals whatever stage it arrives at
    // (found wild creatures can join above baby).
    compendium_stage_stamp(_sp, variable_struct_exists(_pet, "stage") ? _pet.stage : 0);
    var _scion = variable_struct_exists(_pet, "signature") && _pet.signature;
    if (_scion) {
        var _have_s = false;
        for (var _j = 0; _j < array_length(_c.scions_hatched); _j++)
            if (_c.scions_hatched[_j] == _sp) { _have_s = true; break; }
        if (!_have_s) array_push(_c.scions_hatched, _sp);
    }
}

// ---------------------------------------------------------------------------
// STAGE REVEALS (M 08-13): the Creatures journal shows each form (baby / young
// adult / adult / awakened) only once one of yours has reached it. Stored as
// the max stage per species in ach_counters.species_stage_max - rides the same
// saved struct as the hatch sets, so older saves just start empty and the
// backfill below heals them from the stable on first query.
// ---------------------------------------------------------------------------
function compendium_stage_stamp(_species, _stage) {
    if (!is_string(_species) || _species == "") return;
    ach_counters_init();
    var _m = global.ach_counters.species_stage_max;
    var _prev = variable_struct_exists(_m, _species) ? variable_struct_get(_m, _species) : -1;
    if (_stage > _prev) variable_struct_set(_m, _species, _stage);
}

function compendium_stage_max(_species) {
    ach_counters_init();
    var _m = global.ach_counters.species_stage_max;
    var _best = variable_struct_exists(_m, _species) ? variable_struct_get(_m, _species) : -1;
    // Backfill from the living stable (pre-08-13 saves have no stamps at all).
    if (variable_global_exists("pet_roster") && is_array(global.pet_roster)) {
        for (var _i = 0; _i < array_length(global.pet_roster); _i++) {
            var _p = global.pet_roster[_i];
            if (!is_struct(_p) || !variable_struct_exists(_p, "species")) continue;
            if (_p.species != _species) continue;
            if (variable_struct_exists(_p, "is_egg") && _p.is_egg) continue;
            var _ps = variable_struct_exists(_p, "stage") ? _p.stage : 0;
            if (_ps > _best) { _best = _ps; compendium_stage_stamp(_species, _ps); }
        }
    }
    return _best;   // -1 = never raised (undiscovered)
}

// Walk every state-derived condition; cheap (a few short array walks), safe to
// call from a slow timer. Fires nothing when Steam is absent.
function achievements_sync() {
    if (!ach_available()) return;
    ach_counters_init();

    // --- Epithet-backed (the TRACKED set) ---
    var _eps = [
        ["gravebreaker", "ACH_GRAVEBREAKER"], ["survivor",    "ACH_SURVIVOR"],
        ["goldhand",     "ACH_GOLDHAND"],     ["legend",      "ACH_LEGEND"],
        ["deathless",    "ACH_DEATHLESS"],    ["flamewalker", "ACH_FLAMEWALKER"],
        ["tombwarden",   "ACH_TOMBWARDEN"],   ["vaultbreaker","ACH_VAULTBREAKER"],
        ["soulbound",    "ACH_SOULBOUND"],    ["awakener",    "ACH_AWAKENER"],
        ["beloved",      "ACH_BELOVED"],
    ];
    for (var _i = 0; _i < array_length(_eps); _i++)
        if (epithet_unlocked(_eps[_i][0])) ach_unlock(_eps[_i][1]);

    // --- Lifetime counters already in the game ---
    var _tk = variable_global_exists("total_kills") ? global.total_kills : 0;
    if (_tk >= 1)    ach_unlock("ACH_FIRST_BLOOD");
    if (_tk >= 100)  ach_unlock("ACH_KILLS_100");
    if (_tk >= 1000) ach_unlock("ACH_KILLS_1000");
    if (variable_global_exists("total_boss_kills")   && global.total_boss_kills   >= 10) ach_unlock("ACH_BOSSES_10");
    if (variable_global_exists("duelist_encounters") && global.duelist_encounters >= 5)  ach_unlock("ACH_DUELIST_5");

    // --- Win state / awakening ladder (from run records) ---
    if (variable_global_exists("ironwake_stands") && global.ironwake_stands) ach_unlock("ACH_STANDS");
    if (variable_global_exists("run_history")) {
        for (var _r = 0; _r < array_length(global.run_history); _r++) {
            var _rec = global.run_history[_r];
            if (_rec.result == 1 && variable_struct_exists(_rec, "ascendance")) {
                if (_rec.ascendance >= 1) ach_unlock("ACH_ASCENDING");
            }
            if (variable_struct_exists(_rec, "ascendance")) {
                if (_rec.ascendance >= 3) ach_unlock("ACH_AWAKENING_3");
                if (_rec.ascendance >= 5) ach_unlock("ACH_DEEP_END");
            }
        }
    }
    // Descent unlock = the triple-A5 win condition itself.
    if (epithet_a5_clear("scorched_depths") && epithet_a5_clear("tundra_tomb")
        && epithet_a5_clear("ashen_vault")) ach_unlock("ACH_DESCENT_OPEN");

    // --- The Descent depth ladder: saved best + the live floor mid-fall ---
    var _deep = variable_global_exists("descent_best") ? global.descent_best : 0;
    if (variable_global_exists("descent_active") && global.descent_active
        && variable_global_exists("descent_floor")) _deep = max(_deep, global.descent_floor);
    if (_deep >= 10) ach_unlock("ACH_DESCENT_10");
    if (_deep >= 25) ach_unlock("ACH_DESCENT_25");
    if (_deep >= 50) ach_unlock("ACH_DESCENT_50");

    // --- Banshee songs (the real unlock array; the F8 debug lever does NOT
    //     touch music_unlocked, so this can't false-fire) ---
    banshee_init();
    var _songs = array_length(global.music_unlocked);
    if (_songs >= 1) ach_unlock("ACH_BANSHEE");
    if (_songs >= 5) ach_unlock("ACH_SONGS_5");
    if (_songs >= array_length(music_track_catalog())) ach_unlock("ACH_SONGS_ALL");

    // --- Companions: lifetime hatch sets + live roster states ---
    var _c = global.ach_counters;
    if (array_length(_c.species_hatched) >= 1)  ach_unlock("ACH_ITS_ALIVE");
    if (array_length(_c.species_hatched) >= 5)  ach_unlock("ACH_SPECIES_5");
    if (array_length(_c.species_hatched) >= 10) ach_unlock("ACH_SPECIES_10");
    if (array_length(_c.scions_hatched)  >= 1)  ach_unlock("ACH_SCION_1");
    if (array_length(_c.scions_hatched)  >= 2)  ach_unlock("ACH_SCION_2");
    var _ros = pet_roster();
    for (var _p = 0; _p < array_length(_ros); _p++) {
        var _pt = _ros[_p];
        if (_pt.is_egg) continue;
        var _adult = (_pt.stage >= PET_STAGE_ADULT);
        var _scion = variable_struct_exists(_pt, "signature") && _pt.signature;
        if (_scion && _adult)                          ach_unlock("ACH_SCION_ADULT");
        if (pet_is_fulfilled(_pt))                     ach_unlock("ACH_CORRUPTED");
        if (pet_is_fulfilled(_pt) && _adult)           ach_unlock("ACH_CORRUPT_ADULT");
        if (pet_corr_state(_pt) == "cured")            ach_unlock("ACH_PET_CURE");
        if (_pt.stage >= PET_STAGE_AWAKENED)           ach_unlock("ACH_AWAKENER");
        // ACH_ITS_ALIVE also from the live roster (covers pre-tracking saves).
        ach_unlock("ACH_ITS_ALIVE");
    }

    // --- New lifetime counters (sites wired per ACHIEVEMENTS_SPEC.md) ---
    if (_c.crits >= 50)        ach_unlock("ACH_CRITS_50");
    if (_c.crits >= 500)       ach_unlock("ACH_CRITS_500");
    if (_c.detonations >= 25)  ach_unlock("ACH_DETONATE_25");
    if (_c.board_done >= 25)   ach_unlock("ACH_BOARD_25");
    if (variable_global_exists("ach_run_absorbed") && global.ach_run_absorbed >= 500)
        ach_unlock("ACH_ABSORB_500");

    // --- Web Complete (08-05 wiring): any ability woven to the 4-pick cap. ---
    if (variable_global_exists("ability_web") && is_struct(global.ability_web)) {
        var _wc_names = variable_struct_get_names(global.ability_web);
        for (var _wci = 0; _wci < array_length(_wc_names); _wci++) {
            var _wc_p = variable_struct_get(global.ability_web, _wc_names[_wci]);
            if (is_array(_wc_p) && array_length(_wc_p) >= ability_web_cap()) {
                ach_unlock("ACH_WEB_COMPLETE");
                break;
            }
        }
    }

    // --- Codex Collector / Curator (08-05 wiring): discovered vs total over the
    // cached master list (headers skipped). ---
    var _cx = item_codex_master_list();
    var _cx_total = 0, _cx_disc = 0;
    for (var _cxi = 0; _cxi < array_length(_cx); _cxi++) {
        if (codex_entry_is_header(_cx[_cxi])) continue;
        _cx_total++;
        if (codex_entry_discovered(_cx[_cxi])) _cx_disc++;
    }
    if (_cx_total > 0) {
        if (_cx_disc * 2 >= _cx_total) ach_unlock("ACH_COLLECTOR");
        if (_cx_disc >= _cx_total)     ach_unlock("ACH_CURATOR");
    }

    // --- Pillar of the Community (08-05 wiring): every keeper at Friend+ (tier 2). ---
    var _pl_ids = affinity_npc_ids();
    var _pl_all = (array_length(_pl_ids) > 0);
    for (var _pli = 0; _pli < array_length(_pl_ids); _pli++) {
        if (affinity_tier(_pl_ids[_pli]) < 2) { _pl_all = false; break; }
    }
    if (_pl_all) ach_unlock("ACH_PILLAR");
}

// =============================================================================
// CREATURE COMPENDIUM (08-06, DESIGN_WORLD_EXPANSION_0806.md §10)
// M's brief: a pokedex in the Journal, lore per creature, entries unlock only as
// you find them.
//
// VOICE (M, explicit): NOT vague mysticism. These read as MAGICAL ECOLOGY - what
// the creature eats, how it breeds, what it does to the place it lives in, what
// its magic is FOR. Mysterious because the facts are strange, not because the
// prose is evasive.
//
// Discovery is read from the achievement counters that already exist
// (global.ach_counters.species_hatched, .scions_hatched) - no new save data,
// no SAVE_FORMAT_VERSION bump.
// =============================================================================

function pet_species_lore(species_id) {
    switch (species_id) {
        // --- original eight ---------------------------------------------------
        case "luna_moth":        return "Feeds on moonlight the way other insects feed on nectar, which is why the grubs are found in the deepest unlit galleries - starving, and dreaming of a sky none of them have seen. The wings come in already silvered. Nobody has satisfactorily explained how.";
        case "bone_stag":        return "It grows antler the way coral grows reef: slowly, in layers, and never stopping. Old stags cannot lift their heads at all and stand where they died, becoming small cathedrals. Grave-moss favours their bone above all other surfaces.";
        case "saber_hound":      return "Born with the full adult dentition already through the gum, which is agony, which is why they are born snarling. The pack raises pups communally and the snarl never entirely leaves. Bonds hard once it decides you are pack.";
        case "gloomtoad":        return "Its stare thickens the air in front of it, and thoughts moving through that air arrive slow and heavy. Used as watch-animals by the old Vault wardens, who valued a creature that made intruders forget what they came for.";
        case "wyrmling":         return "Hatches remembering a body it has never had - a wingspan, a hoard, a name. It will spend its whole life a little too small for the instincts it woke up with. The fire is real from the first day.";
        case "nightowl":         return "Does not sleep so much as take turns with itself, one hemisphere at a time, for its entire life. What it watches for it has never explained. Its presence sharpens the judgement of anyone standing near it, which the guild noticed and exploited.";
        case "bonehound":        return "The loyalty outlasts the body. A bonehound that has chosen someone will keep following after death, and the skeleton walks the same route it walked in life until the route itself wears away. Bonds faster than anything else in the dark.";
        case "hollow_pup":       return "Something is missing from the middle of it - a warmth other animals have and this one does not. The tail still wags. Its presence makes healing take better, as though the hollow draws the good in and holds it there a moment longer.";
        // --- 07-31 expansion --------------------------------------------------
        case "duskraven":        return "Collects last words the way other corvids collect bright objects, and will repeat them years later in the speaker's own voice. Follows elites and gravediggers for this reason. It is not mockery. It appears to be archival.";
        case "pale_widow":       return "Spins in total silence on a thread that does not reflect light. Its venom does not kill so much as refuse to finish, keeping a wound open long past when it should have closed. The web is the safest place in any room it occupies.";
        case "shellback":        return "The runes on the shell are not carved. They surface from underneath as the tortoise ages, in a script nobody has matched to a known language. Older shellbacks are correspondingly harder to hurt.";
        case "thorn_boar":       return "The brambles are alive and rooted into the animal, drawing from its blood and paying rent in armour. Piglets are born bare and are seeded within days by the sow, who chews the canes soft first.";
        case "glimmer_slime":    return "Swallows gemstones it cannot digest and carries them for life, so an old slime is a walking assay of everywhere it has been. Prospectors follow them. The slime does not appear to mind, or to notice.";
        case "sporeling":        return "The hum is respiration. A colony in a damp gallery will synchronise its humming over several days until the whole chamber sounds like one animal breathing, which is thought to discourage predators.";
        case "voidkit":          return "Cut, not born - a piece of the dark between stars that has decided to be a cat. It is briefly not where it appears to be, most noticeably when something swings at it. Purrs at a frequency that makes lamps gutter.";
        case "ironshell_beetle": return "Metabolises ore, then sweats the metal outward and lets it harden in plates along the seams of its shell. A beetle that has fed well is functionally a small locked box with legs.";
        // --- existing scions --------------------------------------------------
        case "rimefox":          return "Its breath leaves the body already frozen, so it hunts inside a small permanent fog of its own making. Kits are born into a snow den the vixen keeps below freezing by breathing into it nightly.";
        case "crypt_bat":        return "Echolocates in a register that reflects off bone more cleanly than off stone, which is why it never misses in a tomb and blunders badly outdoors. The Archon's roosts were bred for this.";
        case "hoarfrost_drake":  return "Runs cold rather than hot, and the ice it breathes is a by-product of that metabolism rather than a weapon it chose. Drakelings enter a long dreaming torpor at the first hard freeze, which is when the eggs are safest to take.";
        case "vaultling":        return "Not built and not quite hatched - the Vault's wards accreted a shell around a stone beetle over centuries until the shell became the animal. It still hums on the Vault's frequency and always will.";
        case "marrow_adder":     return "Feeds on marrow specifically, and the vertebrae it grows are demonstrably not its own. Each new segment is a bone it has eaten and kept. The crown is likewise borrowed and does not fit.";
        case "gaolwyrm":         return "The chain is grown, not worn - a mineral secretion along the spine that hardens into links. The tail terminates in a key-shaped ossicle that fits no lock anyone has found, though Malgrath reportedly knew.";
        case "cinder_newt":      return "Amphibian that breeds in cooling slag rather than water. The eggs need the heat curve of a forge going out, which is why they are only ever found where something has recently stopped burning.";
        case "magma_leech":      return "Drinks heat directly, then sweats the spent mineral out as pearls that cool behind it in a trail. Follow the trail and you find the leech. Follow it the other way and you find whatever it drained.";
        case "golemite":         return "A shard of the Ashen Colossus that kept moving. It is still trying to be tall - it climbs everything it can reach and stands on the highest point available, which appears to be the entirety of its ambition.";
        // --- 08-06 expansion: general slate -----------------------------------
        case "cairn_bear":       return "Cubs den under the stone piles left over graves, and the stones settle into the fur as they grow until one rides the shoulder permanently. The bear does not carry it deliberately. It simply never had reason to shrug it off.";
        case "ember_ram":        return "The horn is hollow and the animal banks fire inside it, drawing the coal down for winter and letting it up in the rut. A ram in full display is genuinely dangerous to stand near. Wool never takes the flame.";
        case "salt_hare":        return "Crosses the dry flats at a pace nothing else attempts, and the salt it sweats out crusts along the spine as a record of the distance. Old hares are almost white with mileage.";
        case "mire_heron":       return "Holds position so long that silt settles on its back and the water genuinely stops registering it as an object. Everything it eats swims willingly into reach. The patience is metabolic - its heart nearly stops to do this.";
        case "gravel_tick":      return "Grows a shell out of the exact stone it was hatched on, so a colony is invisible until you disturb it and a section of floor stands up. Attaches for weeks. Its bite keeps a wound from closing.";
        case "ashjaw_lynx":      return "Hunts by heat rather than sight, which works well in the dark and makes it useless in a wildfire. The glow in the throat is a heat-organ, not swallowed coal, though the folk name has outlasted every correction.";
        case "glass_eel":        return "Transparent because it has no pigment to spare - everything goes into the silver spine, which is where its magic lives. Hides by holding still in clear water and simply not being visible.";
        case "chapel_bat":       return "Roosts only where a great deal of singing was done, and the wing membranes take on the patterns of whatever glass the light came through. Colonies outlast the roofs. They keep returning to the coordinates of a building that is no longer there.";
        case "barrow_mole":      return "Digs toward grave goods specifically, apparently by smell, and has never been observed to eat any of it. The claws outgrow the animal. Old moles cannot walk on the surface at all.";
        case "tallow_moth":      return "Feeds on rendered fat and tallow rather than nectar, so it thrives in kitchens and mortuaries and nowhere in between. Too heavy to fly well. It goes to the last candle in a room and stays there.";
        case "gravemask":        return "Excavates old interments with great care and always surfaces holding one small thing - a ring, a coin, a locket. It does not hoard them. It carries one until it finds another it prefers, then leaves the first neatly on the ground.";
        case "bristleback":      return "Will not retreat. Not bravery so much as a wiring fault - the flight response appears to be simply absent. Guard hairs stand and stay standing. Most scars on an old bristleback are on the front.";
        case "frostmarten":      return "Hunts the whole winter beneath the ice sheet and surfaces through holes it did not make, sometimes a long way from where it went under. Trappers who have tried to map its routes stop trying. The pelt is dry when it emerges.";
        case "snowmaw":          return "Lies flat and lets the drift build over it, sometimes for the better part of a season, breathing slowly enough that the crust never melts through. What it waits for is not clear, since it will eat almost anything and rarely seems hungry.";
        case "permafrost_toad":  return "Freezes solid each winter and thaws each spring incompletely, keeping a little more ice inside it every year. Older ones are more ice than toad and move accordingly. None have been found dead, which raises the obvious question.";
        case "icewing_skua":     return "Does not hunt. It shadows anything larger than itself across the ice and waits for that thing to falter, drop something, or die, and it is patient about all three. It has been following some parties since the first floor.";
        case "wispfox":          return "The tailflame gives no heat and lights nothing, which rules out every obvious purpose. It burns brightest when the fox is leading something somewhere. What it is leading them toward remains an open question.";
        case "gravefox":         return "Digs crowns and circlets out of old barrows and wears them until they fall apart. Vixens have been observed stealing them from each other. There is no evidence the fox understands what a crown is, and considerable evidence it does not care.";
        case "pyre_bison":       return "Banks fire in the shoulder shag the way its northern cousins bank fat, and the herd's collective heat keeps a valley thawed all winter. Snow has never once settled on a living bison's back. Ash does not either.";
        case "crypt_gryphon":    return "Nests indoors, in halls, on plinths - anywhere with a sightline down a long room. Centuries of that have dulled the plumage to the exact grey of the stone it perches on. Hunts almost nothing. It is not clear what sustains it.";
        case "threehunger":      return "Three heads, three separate appetites, one stomach to settle the argument in. The lion wants meat, the goat wants forage, the serpent wants neither. It is perpetually half-satisfied and correspondingly bad-tempered.";
        case "wing_hare":        return "The antlers are true bone and shed annually like any deer's, which no leporid should be able to do. The hare treats them as unremarkable, grooms around them, and has never been seen to use them for anything at all.";
        case "stormkirin":       return "Carries a charge it never fully discharges, so the air within a few feet of it is permanently on the edge of becoming lightning. Hooves spark on stone. It will not go near standing water and appears to know exactly why.";
        case "lockjaw_turtle":   return "Once the jaw closes it does not open again until the turtle decides, which can be years. Scars on the beak are from things that tried to make it decide sooner. Slow to judge, and utterly final about it.";
        case "drowned_lamp":     return "The light is an organ, fed by the same oil the fish stores against cold, and water does not touch it. Shoals of them light the flooded galleries well enough to read by, which is how the Reach's last records were recovered.";
        case "honeymaw":         return "Raids hives with an indifference to stinging that suggests the venom simply does not register. The bees follow it anyway, all season, apparently having concluded that the arrangement is now permanent.";
        case "bark_hound":       return "An ordinary dog whose coat takes on the grain and colour of the wood it sleeps against, over years, until the shoulders are indistinguishable from bark. Everything else about it is entirely, stubbornly a dog.";
        case "canopy_shrew":     return "Lives its whole life in the high branches and has never touched ground. Weighs almost nothing, eats nearly its own weight daily, and is furious about the arithmetic of that for the entirety of its very short life.";
        case "witchwood_fawn":   return "Born from a witchwood that had stood long enough to remember the deer that sheltered under it. The antlers bud and blossom on a plant's schedule rather than an animal's, and the fawn browses on nothing at all.";
        case "pressure_snail":   return "Lays down shell far denser than the depth requires, at enormous metabolic cost, for no benefit anyone has identified. Descent specimens are denser still. Whatever it is bracing against, it is not the water.";
        case "flicker_finch":    return "Never entirely present. The edges go first and the bird follows, then returns, on a cycle of a few seconds it does not seem able to control. Nests are found with eggs in them and no evidence of a parent that stayed put.";
        case "rust_vole":        return "Eats iron and voids the impurities, leaving small tidy heaps of nearly pure metal outside the burrow. Smiths who find a colony do not report it. The teeth regrow constantly and are harder than the ore.";
        case "paleswimmer":      return "Eyeless, and so far down that eyes would be an expense with no return. Does not flee, does not approach, does not appear to register a lantern held directly against it. The indifference is the unsettling part.";
        // --- 08-06 expansion: Warden scions -----------------------------------
        case "doorling":         return "It was the doorkeeper's cat and it did not leave when the doorkeeper did. The frame it sat in has grown into its back over the years, the way a tree takes in a fence. It still sits in doorways. It still grooms itself.";
        case "fathom_squid":     return "Has never encountered light and has no organ that could use it. The eyes are enormous and entirely decorative, a leftover from ancestors who lived shallower. The ink is not for hiding down here; nothing can see it anyway.";
        case "tallykeep":        return "Scratches marks into its own hide, unevenly, continuously, over its whole life. The count does not correspond to days, kills, or offspring. It is counting something. It has not been established what.";
        case "lantern_wyrm":     return "The lantern is a growth on a stalk of its own skull, but the light inside it is demonstrably not produced by the wyrm - it is the same cold yellow as Hollowlight's, and it goes out when Hollowlight is killed.";
        case "deepclaw":         return "Carries a slab of the floor it hatched on and adds to it, so an old deepclaw is hauling a considerable piece of the Descent around. The larger claw is for the load, not for fighting. It has never needed to fight.";
        case "sum_moth":         return "The wing patterns resolve into numerals when it is still, and they are different numerals each time. Two moths at rest beside each other have never been observed to show the same figure.";
        case "null_hound":       return "A hound-shaped absence with a starfield where the animal should be. It heels, it sits, it comes when called. Whatever was removed to make it did not include the parts that do those things.";
        case "mimicling":        return "Never develops features of its own. It copies whatever creature it saw most recently and holds that shape imperfectly, so a mimicling raised alongside a companion becomes a poor, earnest impression of it.";
        case "griefwisp":        return "Forms where a grief was set down and not picked back up. The circlet is genuine and far too large, and the wisp keeps it balanced with what looks a great deal like effort.";
        // --- 08-06 expansion: new biome scions --------------------------------
        case "sluice_otter":     return "Lived in the lock-works, learned the flood cycle by feel, and times its dives to the ebb with better accuracy than the Tidewright's own mechanisms. The valve-wheel on its tail cannot be removed and is plainly a favourite.";
        case "chorister_fry":    return "Hatches already knowing one part of the Choirmother's song and holds that one note its entire life. A shoal produces a chord. Removing a single fry leaves an audible gap in the water.";
        case "leviathan_calf":   return "Already scarred, already barnacled, and already too heavy for its size. Growth does not slow. Nobody has kept one long enough to establish where it stops, and the Reach suggests it does not.";
        case "graftling":        return "The Stag grafts antler onto its calves before they can walk, at seams that never fully close and weep sap for life. The calf carries a rack it will not grow into for years and does not appear to find this strange.";
        case "thornlet":         return "The thorns curve inward, toward the animal, which makes them useless for defence and painful to be. It seeks contact anyway, constantly, from anything that will tolerate it. The bleeding is mutual.";
        case "whispervine":      return "A serpent whose body is vine and whose head is a bud that has never opened. It has no mouth, no eyes and no voice, and tastes the air with a tendril. It leans toward speech. It has never once answered.";
    }
    return "";
}

// Dungeons a run can actually be started in. Scions keyed to anything else
// (unbuilt biomes) cannot drop yet, so the Compendium must not count them -
// otherwise completion caps below 100% and reads as a bug. Add a key here the
// moment that dungeon becomes selectable. "descent" joined 08-13: the Depth
// Wardens spawn and roll their scions now (combat_on_enemy_defeated), so the
// art-gated scion loop below counts them honestly.
function compendium_live_dungeons() {
    return ["ashen_vault", "scorched_depths", "tundra_tomb", "descent"];
}

// Compendium roster: every OBTAINABLE species, generic then scion, in catalog
// order. Gated the same way the rolls are (08-08): a species with no imported
// art never rolls (pet_species_random), and a scion keyed to a dungeon you
// cannot enter never drops - so neither belongs in the denominator. Designed
// species appear here automatically once their art lands / their dungeon ships.
function compendium_catalog() {
    var _out = [];
    var _g = pet_species_catalog();
    for (var _i = 0; _i < array_length(_g); _i++) {
        if (!pet_species_has_art(_g[_i].id)) continue;
        array_push(_out, { id: _g[_i].id, name: _g[_i].name, blurb: _g[_i].blurb, scion: false, boss: "" });
    }
    var _live = compendium_live_dungeons();
    var _s = pet_species_signature_catalog();
    for (var _i = 0; _i < array_length(_s); _i++) {
        if (!pet_species_has_art(_s[_i].id)) continue;
        var _dg = variable_struct_exists(_s[_i], "dungeon") ? _s[_i].dungeon : "";
        var _dg_ok = (_dg == "");
        for (var _k = 0; _k < array_length(_live); _k++) if (_live[_k] == _dg) _dg_ok = true;
        if (!_dg_ok) continue;
        array_push(_out, { id: _s[_i].id, name: _s[_i].name, blurb: _s[_i].blurb, scion: true,
                           boss: variable_struct_exists(_s[_i], "boss") ? _s[_i].boss : "" });
    }
    return _out;
}

// Discovered = you have HATCHED it. Reads the achievement counters that already
// track lifetime species/scion sets, so there is nothing new to save.
function compendium_discovered(species_id) {
    if (!variable_global_exists("ach_counters")) return false;
    var _c = global.ach_counters;
    if (!is_struct(_c)) return false;
    if (variable_struct_exists(_c, "species_hatched")) {
        var _a = _c.species_hatched;
        for (var _i = 0; _i < array_length(_a); _i++) if (_a[_i] == species_id) return true;
    }
    if (variable_struct_exists(_c, "scions_hatched")) {
        var _b = _c.scions_hatched;
        for (var _i = 0; _i < array_length(_b); _i++) if (_b[_i] == species_id) return true;
    }
    return false;
}

// {found, total} over the whole roster, or over scions only when _scions_only.
function compendium_progress(_scions_only) {
    var _c = compendium_catalog();
    var _f = 0, _t = 0;
    for (var _i = 0; _i < array_length(_c); _i++) {
        if (_scions_only && !_c[_i].scion) continue;
        if (!_scions_only && _c[_i].scion) continue;
        _t++;
        if (compendium_discovered(_c[_i].id)) _f++;
    }
    return { found: _f, total: _t };
}

// The sprite to draw for a compendium row - adult art when we have it, else the
// baby frame, else -1 (the drawer then falls back to a plain silhouette box).
function compendium_sprite(species_id) {
    var _a = asset_get_index("spr_pet_" + species_id + "_adult_s");
    if (_a >= 0) return _a;
    _a = asset_get_index("spr_pet_" + species_id + "_adult");
    if (_a >= 0) return _a;
    _a = asset_get_index("spr_pet_" + species_id + "_baby_s");
    if (_a >= 0) return _a;
    _a = asset_get_index("spr_pet_" + species_id + "_baby");
    if (_a >= 0) return _a;
    _a = asset_get_index("spr_pet_" + species_id);
    return (_a >= 0) ? _a : -1;
}

// Per-stage journal portrait (M 08-13 form slots). Stage keys mirror
// pet_sprite_key's naming. Returns -1 when that stage has no bespoke art -
// the journal walks DOWN to the closest earlier form (awakened shows adult
// art in-game too, under the engine FX).
function compendium_stage_sprite(species_id, _stage) {
    var _key;
    if (_stage <= PET_STAGE_ADOLESCENT)      _key = "baby";
    else if (_stage == PET_STAGE_YOUNGADULT) _key = "youngadult";
    else if (_stage == PET_STAGE_ADULT)      _key = "adult";
    else                                     _key = "awakened";
    var _a = asset_get_index("spr_pet_" + species_id + "_" + _key + "_s");
    if (_a >= 0) return _a;
    _a = asset_get_index("spr_pet_" + species_id + "_" + _key + "_e");
    return (_a >= 0) ? _a : -1;
}

// Where a species can be found, for the entry's HABITAT line.
function compendium_habitat(species_id) {
    var _s = pet_species_signature_catalog();
    for (var _i = 0; _i < array_length(_s); _i++) {
        if (_s[_i].id != species_id) continue;
        if (_s[_i].dungeon == "descent") return "The Descent - a rare drop from " + _s[_i].boss + ".";
        return dungeon_display_name(_s[_i].dungeon) + " - dropped by " + _s[_i].boss + ".";
    }
    switch (species_id) {
        case "pressure_snail": case "flicker_finch":
        case "rust_vole":      case "paleswimmer":
            return "The Descent only - found in caches and depth events.";
    }
    return "Found in eggs across Ironwake.";
}

// NOTE: dungeon_display_name() already exists at ~9282 and covers the three
// original dungeons. Extended there (not redefined here - GML would not compile
// with two definitions) to cover the 08-06 biomes + the Descent.

// =============================================================================
// RPG ORIGINS (M design-locked 08-11, with notes): a background chosen at
// character creation AFTER the portrait, giving each new character a small
// mechanical head start + flavor. Staging stills resolve by name
// (spr_origin_<id>) and the picker degrades to framed text cards until the art
// imports. One-time grants fire in origin_apply_new_game() (char-select vow
// commit, right before the first save). Per-run grants fire ONCE per run via
// origin_run_start() (floor controller Create, one-shot flag reset in
// end_run; checkpoint resume marks the run already granted).
// All numbers vetoable at F5.
// =============================================================================

function origin_catalog() {
    return [
        { id:"merchant",   name:"Merchant's Son",           blurb:"Coin opened every door of your childhood. It still does.",
          start:"Start with +500 gold." },
        { id:"forester",   name:"Forest Tender",            blurb:"You kept a warden's grove before the dark took it.",
          start:"Start with an extra creature egg." },
        { id:"deserter",   name:"Legion Deserter",          blurb:"You walked away from the Iron Legion - with your kit.",
          start:"Start with a Rare weapon (rough quality)." },
        { id:"gravekeeper",name:"Gravekeeper's Apprentice", blurb:"You learned what the dead leave behind, and how to use it.",
          start:"Start with 60 rune dust and a Common Reforge Ingot." },
        { id:"survivor",   name:"Plague Survivor",          blurb:"The fever took the village. It could not take you.",
          start:"+1 CON permanently. Begin each run with an Antidote." },
        { id:"orphan",     name:"Gutter Orphan",            blurb:"Nobody fed you, so you learned to feed yourself.",
          start:"+1 DEX permanently. Shops charge you 5% less." },
        { id:"scholar",    name:"Failed Scholar",           blurb:"The academy burned your thesis. You kept the footnotes.",
          start:"+1 INT permanently. Start with 2 Energy Tonics." },
        { id:"shrinesworn",name:"Shrine-Sworn",             blurb:"You tended a wayside altar. Something noticed.",
          start:"Begin each run with a minor Boon." },
        { id:"campaigner", name:"Old Campaigner",           blurb:"Thirty years of wars nobody names anymore.",
          start:"+1 STR permanently. Start with an Uncommon armor piece." },
        { id:"banshee",    name:"Banshee-Touched",          blurb:"You heard her sing once, and lived to hum it.",
          start:"+1 WIS permanently. A bottled Banshee already waits at camp." },
        { id:"whisperer",  name:"Beast-Whisperer",          blurb:"Animals never learned to fear you.",
          start:"Pet bonds grow 25% faster. 3 treats per run instead of 2." },
        { id:"debtor",     name:"The Debtor",               blurb:"The money was never yours. The blade you bought with it is.",
          start:"Start with a random Epic item - and a 400g debt that WILL be collected." },
    ];
}

function origin_get(id) {
    var _c = origin_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}

function origin_is(id) {
    return variable_global_exists("origin_id") && global.origin_id == id;
}

// The staging still for an origin (spr_origin_<id>), or -1 until imported.
function origin_still(id) { return asset_get_index("spr_origin_" + id); }

// Gutter Orphan: 5% off everywhere - multiplies into cha_price beside the
// signet/beggar multipliers.
function origin_price_mult() { return origin_is("orphan") ? 0.95 : 1.0; }

// Shrine-Sworn's run-start boon rolls from the MILD plain boons only (M 08-11:
// "make sure the random minor boon is not too powerful") - economy/small-
// sustain picks, never the damage warpers.
function origin_minor_boons() { return ["greed", "aegis", "vampirism"]; }

// Roll one rarity-forced drop of a given slot family. slot_filter: "" = any,
// "weapon" = weapons only, "armor" = wearable non-weapon gear. Bounded retry -
// the loot tables are big enough that 30 rolls always find the family.
function origin_roll_item(_rarity, _slot_filter) {
    var _w = [0, 0, 0, 0, 0];
    _w[_rarity] = 100;
    for (var _try = 0; _try < 30; _try++) {
        var _it = drop_equipment(_w, false);
        if (!is_struct(_it)) continue;
        var _sl = variable_struct_exists(_it, "slot") ? _it.slot : "";
        if (_slot_filter == "") return _it;
        if (_slot_filter == "weapon" && _sl == "weapon") return _it;
        if (_slot_filter == "armor" && (_sl == "chest" || _sl == "helm" || _sl == "gloves" || _sl == "boots")) return _it;
    }
    return drop_equipment(_w, false);   // family miss after 30 - take what came
}

// Push a standard-catalog consumable by name into the pouch (n copies).
function origin_grant_consumable(_name, _n) {
    if (!variable_global_exists("consumables_standard")) return;
    for (var _i = 0; _i < array_length(global.consumables_standard); _i++) {
        var _t = global.consumables_standard[_i];
        if (_t.name != _name) continue;
        if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
        repeat (_n) array_push(global.consumable_inventory,
            create_consumable(_t.name, _t.effect_type, _t.effect_value, _t.description, _t.gold_value));
        return;
    }
}

// One-time grants, called at char-select vow commit BEFORE the first
// save_game() so everything lands in the new slot.
function origin_apply_new_game() {
    if (!variable_global_exists("origin_id") || global.origin_id == "") return;
    switch (global.origin_id) {
        case "merchant":
            global.gold += 500;
            break;
        case "forester":
            // Rides the starter-egg pipeline (random arted species, ready to
            // identify/hatch at Bairc) - this is IN ADDITION to the normal
            // first-Bairc-talk starter egg.
            pet_grant_starter();
            break;
        case "deserter":
            array_push(global.equipment_stash, origin_roll_item(2, "weapon"));
            break;
        case "gravekeeper":
            if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
            global.rune_dust += 60;
            reforge_ingot_add(0, 1);
            break;
        case "survivor":   global.perm_con_bonus += 1; break;   // + per-run Antidote
        case "orphan":     global.perm_dex_bonus += 1; break;   // + origin_price_mult
        case "scholar":
            global.perm_int_bonus += 1;
            origin_grant_consumable("Energy Tonic", 2);
            break;
        case "shrinesworn": break;                              // per-run boon only
        case "campaigner":
            global.perm_str_bonus += 1;
            array_push(global.equipment_stash, origin_roll_item(1, "armor"));
            break;
        case "banshee":
            global.perm_wis_bonus += 1;
            if (!variable_global_exists("banshee_banked")) global.banshee_banked = 0;
            global.banshee_banked += 1;   // release it at Maren = the song unlock flow
            break;
        case "whisperer":  break;                               // passive hooks
        case "debtor":
            array_push(global.equipment_stash, origin_roll_item(3, ""));
            global.debt_gold   = 400;
            global.debt_missed = 0;
            break;
    }
}

// Per-run grants - called from the floor controller's Create through a
// one-shot flag so multi-floor runs and checkpoint resumes never double-grant.
function origin_run_start() {
    if (variable_global_exists("origin_run_granted") && global.origin_run_granted) return;
    global.origin_run_granted = true;
    if (origin_is("survivor")) origin_grant_consumable("Antidote", 1);
    if (origin_is("shrinesworn")) {
        var _pool = origin_minor_boons();
        boon_grant(_pool[irandom(array_length(_pool) - 1)]);
    }
}

// =============================================================================
// THE DEBTOR ledger (M 08-11): 400g owed. Each run-end at camp the creditor
// collects the minimum - 10% of the outstanding debt - from your gold. Miss it
// and the debt gains 15% interest and a missed payment is marked. Three missed
// payments and you are IN COLLECTIONS: a quarter of ALL gold you earn is
// garnished at the source until the debt is cleared. Numbers vetoable.
// =============================================================================

function debt_active() {
    return variable_global_exists("debt_gold") && global.debt_gold > 0;
}

function debt_in_collections() {
    return debt_active()
        && variable_global_exists("debt_missed") && global.debt_missed >= 3;
}

// Garnish hook - lives inside add_gold(). Garnished coin pays the debt down.
function debt_garnish(_amount) {
    if (!debt_in_collections() || _amount <= 0) return _amount;
    var _cut = max(1, floor(_amount * 0.25));
    _cut = min(_cut, global.debt_gold);
    global.debt_gold -= _cut;
    if (global.debt_gold <= 0) { global.debt_gold = 0; global.debt_missed = 0; }
    return _amount - _cut;
}

// Run-end collection - called from end_run (both results; the creditor does
// not care how the run went). Returns a one-line message for the hub, or "".
function debt_collect_run_end() {
    if (!debt_active()) return "";
    var _min = max(1, ceil(global.debt_gold * 0.10));
    if (global.gold >= _min) {
        global.gold      -= _min;
        global.debt_gold -= _min;
        if (global.debt_gold <= 0) {
            global.debt_gold = 0; global.debt_missed = 0;
            return "The last of the debt is paid. The ledger closes.";
        }
        return "The creditor collects " + string(_min) + "g. " + string(global.debt_gold) + "g still owed.";
    }
    // Cannot cover the minimum: interest, and a mark against you.
    global.debt_missed = (variable_global_exists("debt_missed") ? global.debt_missed : 0) + 1;
    global.debt_gold   = ceil(global.debt_gold * 1.15);
    if (debt_in_collections()) {
        return "Payment missed. You are IN COLLECTIONS - a quarter of all gold you earn is garnished until the "
            + string(global.debt_gold) + "g is cleared.";
    }
    return "Payment missed - interest swells the debt to " + string(global.debt_gold)
        + "g. (" + string(global.debt_missed) + "/3 before collections.)";
}

// =============================================================================
// DORN'S PATTERN BOOK (M design-locked 08-11, SYSTEMS_REFORGE_CRAFT.md).
// SMELT unequipped gear -> it is destroyed for a Reforge Ingot of its tier,
// ONE chosen affix family gains blueprint "study" progress, and the item's
// icon art joins the book's ART PAGE. Families unlock in tiers:
//   tier I   = 3 studies (any Uncommon+ fodder)   -> low-band rolls
//   tier II  = 4 MORE studies from RARE+ fodder   -> mid-band rolls
//   tier III = 5 MORE studies from EPIC+ fodder   -> full natural rolls
// CRAFT is a CUSTOM ITEM BUILDER: pick slot + rarity + base stat + every affix
// from unlocked blueprints (up to the rarity's natural budget) + icon art +
// name. Identity is deterministic; the NUMBERS still roll RNG inside the band
// the family's blueprint tier buys (M: "it's customization" - never exceeds
// the rarity's natural values, tier I is strictly a floor roll). A paid
// re-roll re-rolls the numbers WITHIN the same bands. All fees vetoable.
// =============================================================================
function pattern_book_ensure() {
    if (!variable_global_exists("pattern_book") || !is_struct(global.pattern_book)) {
        global.pattern_book = { fam: {}, art: [] };
    }
    if (!variable_struct_exists(global.pattern_book, "fam") || !is_struct(global.pattern_book.fam)) {
        global.pattern_book.fam = {};
    }
    if (!variable_struct_exists(global.pattern_book, "art") || !is_array(global.pattern_book.art)) {
        global.pattern_book.art = [];
    }
    return global.pattern_book;
}

// The studyable/craftable affix families: the 12 stat/utility affixes plus the
// 8 caster school affixes. Elemental WEAPON riders (elem_affix) and legendary
// unique effects are deliberately NOT blueprintable (spec ban). Entries:
// { stat_name, label, kind ("stat"|"school"), prefix, suffix }.
function pattern_family_catalog() {
    var _out = [];
    if (variable_global_exists("affix_pool")) {
        for (var _i = 0; _i < array_length(global.affix_pool); _i++) {
            var _a = global.affix_pool[_i];
            var _lb = _a.suffix;
            if (string_pos("of the ", _lb) == 1)  _lb = string_delete(_lb, 1, 7);
            else if (string_pos("of ", _lb) == 1) _lb = string_delete(_lb, 1, 3);
            array_push(_out, { stat_name: _a.stat_name, label: _lb, kind: "stat",
                               prefix: _a.prefix, suffix: _a.suffix });
        }
    }
    if (variable_global_exists("school_affix_pool")) {
        for (var _j = 0; _j < array_length(global.school_affix_pool); _j++) {
            var _s = global.school_affix_pool[_j];
            var _sl = string_upper(string_char_at(_s.school, 1)) + string_delete(_s.school, 1, 1);
            array_push(_out, { stat_name: _s.stat_name, label: _sl + " damage", kind: "school",
                               prefix: _s.prefix, suffix: _s.suffix });
        }
    }
    return _out;
}

function pattern_family_entry(_stat_name) {
    var _cat = pattern_family_catalog();
    for (var _i = 0; _i < array_length(_cat); _i++) {
        if (_cat[_i].stat_name == _stat_name) return _cat[_i];
    }
    return undefined;
}

// pattern_family_desc(stat_name) - one plain line of WHAT an affix family does
// (M 08-13: the smelt-study list read as bare vernacular - "Insight", "Ruin" -
// with nothing saying what you'd actually be learning).
function pattern_family_desc(_stat_name) {
    switch (_stat_name) {
        case "STR": return "+Strength - harder melee blows";
        case "DEX": return "+Dexterity - accuracy, dodge, crit, turn priority; shrugs Root";
        case "CON": return "+Constitution - more maximum HP; softens poison, shrugs Stun";
        case "INT": return "+Intelligence - stronger spells";
        case "WIS": return "+Wisdom - stronger effects and healing; shrugs Silence";
        case "CHA": return "+Charisma - better prices and gold find";
        case "bonus_max_hp": return "+Maximum HP on the item itself";
        case "crit_flat":    return "+Critical hit chance (all attacks)";
        case "dodge_flat":   return "+Dodge chance";
        case "gold_find":    return "+Gold found from kills and chests";
        case "crit_spell":   return "+Spell critical chance (casters)";
        case "crit_phys":    return "+Physical critical chance (weapons)";
    }
    if (string_pos("school_", _stat_name) == 1) {
        var _sch = string_delete(_stat_name, 1, 7);
        return "+" + string_upper(string_char_at(_sch, 1)) + string_delete(_sch, 1, 1)
             + " damage on your casts (amulet/ring only)";
    }
    return "";
}

// Per-family study progress. REWORKED 08-15 (M: "i cant make anything unless
// i smelt the same thing over and over - not a functional crafting system"):
// a single cumulative study count .s - 1 study crafts Uncommon, 3 unlock Rare,
// 6 unlock Epic. NO fodder-rarity gates; rarer fodder teaches FASTER instead
// (pattern_study_weight). Legacy saves carry {p1,p2,p3} - migrated into .s
// once here (partial old progress is kept, nothing is lost).
function pattern_fam_get(_stat_name) {
    var _b = pattern_book_ensure();
    if (!variable_struct_exists(_b.fam, _stat_name)) {
        variable_struct_set(_b.fam, _stat_name, { p1: 0, p2: 0, p3: 0, s: 0 });
    }
    var _p = variable_struct_get(_b.fam, _stat_name);
    if (!variable_struct_exists(_p, "s")) _p.s = _p.p1 + _p.p2 + _p.p3;   // legacy migrate
    return _p;
}

// Unlocked craftable QUALITY for a family: 0 none, 1 Uncommon, 2 Rare, 3 Epic.
function pattern_fam_tier(_stat_name) {
    var _p = pattern_fam_get(_stat_name);
    if (_p.s >= 6) return 3;
    if (_p.s >= 3) return 2;
    if (_p.s >= 1) return 1;
    return 0;
}

// Studies one smelt of _rarity fodder banks toward this family (M-locked
// 08-15): Epic+ fodder = 3 toward the first rung, 2 toward the second, 1 at
// the third; Rare = 2/1/1; Common/Uncommon = 1 everywhere.
function pattern_study_weight(_stat_name, _rarity) {
    var _t = pattern_fam_tier(_stat_name);
    if (_rarity >= 3) return (_t <= 0) ? 3 : ((_t == 1) ? 2 : 1);
    if (_rarity == 2) return (_t <= 0) ? 2 : 1;
    return 1;
}

// Book-page progress text for a family.
function pattern_fam_progress_text(_stat_name) {
    var _p = pattern_fam_get(_stat_name);
    if (_p.s <= 0) return "0/1 studies - one smelt unlocks Uncommon";
    if (_p.s < 3)  return string(_p.s) + "/3 studies to Rare crafts";
    if (_p.s < 6)  return string(_p.s) + "/6 studies to Epic crafts";
    return "MASTERED (Epic crafts)";
}

// What ONE study from fodder of the given rarity would do for this family.
// Returns { ok, text } - ok=false only once mastered (no fodder gates, 08-15).
function pattern_study_preview(_stat_name, _rarity) {
    var _p = pattern_fam_get(_stat_name);
    if (_p.s < 6) {
        var _w    = pattern_study_weight(_stat_name, _rarity);
        var _next = (_p.s < 1) ? 1 : ((_p.s < 3) ? 3 : 6);
        var _lbl  = (_p.s < 1) ? "Uncommon" : ((_p.s < 3) ? "Rare" : "Epic");
        return { ok: true, text: "+" + string(_w) + " stud" + ((_w == 1) ? "y" : "ies")
            + "  (" + string(min(_next, _p.s + _w)) + "/" + string(_next) + " to " + _lbl + " crafts)" };
    }
    return { ok: false, text: "already mastered" };
}

// Apply one study (rarity-weighted, 08-15). Returns true if progress moved.
function pattern_book_study(_stat_name, _rarity) {
    var _pv = pattern_study_preview(_stat_name, _rarity);
    if (!_pv.ok) return false;
    var _p = pattern_fam_get(_stat_name);
    _p.s += pattern_study_weight(_stat_name, _rarity);
    return true;
}

// The affix families a given item can teach: its base stat + every affix row
// whose stat_name is a known family (school rows included; elem riders are not
// stat_name rows so they naturally fall out).
function pattern_item_families(_it) {
    var _out = [];
    if (!is_struct(_it)) return _out;
    if (variable_struct_exists(_it, "stat_name") && pattern_family_entry(_it.stat_name) != undefined) {
        array_push(_out, _it.stat_name);
    }
    if (variable_struct_exists(_it, "affixes") && is_array(_it.affixes)) {
        for (var _i = 0; _i < array_length(_it.affixes); _i++) {
            var _r = _it.affixes[_i];
            if (!is_struct(_r) || !variable_struct_exists(_r, "stat_name")) continue;
            if (pattern_family_entry(_r.stat_name) == undefined) continue;
            var _dup = false;
            for (var _j = 0; _j < array_length(_out); _j++) { if (_out[_j] == _r.stat_name) { _dup = true; break; } }
            if (!_dup) array_push(_out, _r.stat_name);
        }
    }
    return _out;
}

// ---- ART PAGE ---------------------------------------------------------------
// Every smelted item's icon identity joins the book (dupes ignored). An entry
// holds just enough to re-resolve the same sprite through the slot icon
// resolvers: { slot, base_name, rarity, label, seed (-1 = none) }.
function pattern_art_unlock(_it) {
    var _b   = pattern_book_ensure();
    var _bn  = item_base_name(_it);
    var _rar = variable_struct_exists(_it, "rarity") ? clamp(_it.rarity, 0, 4) : 0;
    var _sd  = variable_struct_exists(_it, "icon_seed") ? _it.icon_seed : -1;
    var _key = _it.slot + "|" + string_lower(_bn) + "|" + string(_rar) + "|" + string(_sd);
    for (var _i = 0; _i < array_length(_b.art); _i++) {
        var _e = _b.art[_i];
        if (_e.slot + "|" + string_lower(_e.base_name) + "|" + string(_e.rarity) + "|" + string(_e.seed) == _key) return false;
    }
    array_push(_b.art, { slot: _it.slot, base_name: _bn, rarity: _rar, label: _bn, seed: _sd });
    return true;
}

function pattern_art_for_slot(_slot) {
    var _b = pattern_book_ensure();
    var _out = [];
    for (var _i = 0; _i < array_length(_b.art); _i++) {
        if (_b.art[_i].slot == _slot) array_push(_out, _b.art[_i]);
    }
    return _out;
}

// A fake-item proxy an art entry (or icon_as field) feeds to the slot icon
// resolvers - they only read name / base_name / rarity / icon_seed.
function pattern_art_proxy(_e) {
    var _p = { name: _e.base_name, base_name: _e.base_name, rarity: _e.rarity, slot: _e.slot };
    if (variable_struct_exists(_e, "seed") && _e.seed >= 0) _p.icon_seed = _e.seed;
    if (variable_struct_exists(_e, "icon_seed")) _p.icon_seed = _e.icon_seed;
    return _p;
}

// ---- SMELT ------------------------------------------------------------------
function pattern_smelt_fee() { return cha_price(25); }

// Picker candidates: UNEQUIPPED gear only (stash + carried - the worn array is
// deliberately not a pool), Uncommon..Epic (legendaries have their own three
// sinks), never dormant. Stash-aware per the 08-11 NPC rule.
function pattern_smelt_candidates() {
    var _out = [];
    var _pools = [];
    if (variable_global_exists("equipment_stash") && is_array(global.equipment_stash)) array_push(_pools, { a: global.equipment_stash, s: 0 });
    if (variable_global_exists("carried_items")   && is_array(global.carried_items))   array_push(_pools, { a: global.carried_items,   s: 1 });
    for (var _p = 0; _p < array_length(_pools); _p++) {
        var _arr = _pools[_p].a;
        for (var _i = 0; _i < array_length(_arr); _i++) {
            var _g = _arr[_i];
            if (!is_struct(_g) || !variable_struct_exists(_g, "slot") || !variable_struct_exists(_g, "rarity")) continue;
            if (_g.rarity < 1 || _g.rarity > 3) continue;
            if (variable_struct_exists(_g, "dormant") && _g.dormant) continue;
            array_push(_out, { source: _pools[_p].s, idx: _i, item: _g, label: _g.name,
                rarity: _g.rarity,
                value: variable_struct_exists(_g, "gold_value") ? _g.gold_value : 0 });
        }
    }
    return _out;
}

// Destroy-by-identity across the unequipped pools (the study popup holds a
// reference, not an index - the picker is long closed by commit time).
function pattern_smelt_remove(_it) {
    for (var _s = 0; _s < 2; _s++) {
        var _a = (_s == 0) ? global.equipment_stash : global.carried_items;
        if (!is_array(_a)) continue;
        for (var _i = 0; _i < array_length(_a); _i++) {
            if (_a[_i] == _it) { array_delete(_a, _i, 1); return true; }
        }
    }
    return false;
}

// Commit a smelt: gold fee is checked by the CALLER (so its error can use the
// shop notification line). _stat_name == "" means "just the ingot" (no study).
// Returns the notification text, or "" if the item vanished (nothing charged).
function pattern_smelt_commit(_it, _stat_name) {
    if (!pattern_smelt_remove(_it)) return "";
    global.gold -= pattern_smelt_fee();
    var _rar = clamp(_it.rarity, 0, 4);
    reforge_ingot_grant(_rar, 1);
    var _new_art = pattern_art_unlock(_it);
    var _msg = "Smelted " + _it.name + " - +1 " + item_rarity_name(_rar) + " ingot";
    if (_stat_name != "") {
        var _fe = pattern_family_entry(_stat_name);
        var _tier_was = pattern_fam_tier(_stat_name);
        if (pattern_book_study(_stat_name, _rar) && _fe != undefined) {
            _msg += ", studied " + _fe.label + " (" + pattern_fam_progress_text(_stat_name) + ")";
            // TIER UNLOCK toast (M 08-16: "something should pop up to say
            // you've unlocked tier 1"): drawn topmost on Dorn's screen.
            var _tier_now = pattern_fam_tier(_stat_name);
            if (_tier_now > _tier_was) {
                var _tq = (_tier_now >= 3) ? "EPIC" : ((_tier_now == 2) ? "RARE" : "UNCOMMON");
                global.dorn_toast_msg   = "TIER " + string(_tier_now) + " UNLOCKED  -  " + _fe.label
                    + " blueprints now craft at " + _tq + "!";
                global.dorn_toast_timer = 300;
                audio_play_sound(snd_confirm_major, 1, false);
            }
        }
    }
    if (_new_art) _msg += ", its art joins the book";
    _msg += ".";
    return _msg;
}

// ---- CRAFT (the custom item builder) ---------------------------------------
// Crafted rarities: 1 Uncommon / 2 Rare / 3 Epic. All numbers vetoable.
// Affix SLOTS per crafted quality (08-15: Uncommon gained a 2nd slot, Epic a
// 3rd, so the concentration rule below has room to breathe - VETOABLE numbers).
function pattern_affix_budget(_rarity) {
    if (_rarity >= 3) return 3;
    return 2;
}
// =============================================================================
// DUNGEON CRAFTING REAGENTS (M-locked 08-17: "reagents needed for crafting items
// at Dorn"). One reagent per dungeon, dropped by that dungeon's elites (40%) and
// bosses (x2, always). Dorn's CRAFT wizard asks 1 / 2 / 3 reagents of ANY kind
// for an Uncommon / Rare / Epic craft on top of gold + dust + ingot. Persisted in
// global.reagents (save/load/new_game in scr_save). Shown on the wizard's
// quality rows and the craft checkout.
// =============================================================================
function reagent_catalog() {
    return [
        { id:"vault_ash",     name:"Vault Ash",     dungeon:"ashen_vault",     blurb:"grey ash that never cooled - the Vault's dead still smoulder in it" },
        { id:"cinder_marrow", name:"Cinder Marrow", dungeon:"scorched_depths", blurb:"marrow that burns without a flame, cut from things that live in the vents" },
        { id:"rime_salt",     name:"Rime Salt",     dungeon:"tundra_tomb",     blurb:"salt that freezes whatever it touches; the Tomb keeps its dead in it" },
        { id:"void_silt",     name:"Void Silt",     dungeon:"descent",         blurb:"silt from below the bottom - it weighs more than it should" },
    ];
}
function reagents_ensure() {
    if (!variable_global_exists("reagents") || !is_struct(global.reagents)) global.reagents = {};
    var _c = reagent_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) {
        if (!variable_struct_exists(global.reagents, _c[_i].id)) variable_struct_set(global.reagents, _c[_i].id, 0);
    }
}
function reagent_get(id) {
    var _c = reagent_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].id == id) return _c[_i];
    return undefined;
}
function reagent_count(id) {
    reagents_ensure();
    return variable_struct_exists(global.reagents, id) ? variable_struct_get(global.reagents, id) : 0;
}
function reagent_add(id, n) {
    reagents_ensure();
    variable_struct_set(global.reagents, id, reagent_count(id) + n);
}
function reagent_total() {
    reagents_ensure();
    var _c = reagent_catalog(), _t = 0;
    for (var _i = 0; _i < array_length(_c); _i++) _t += reagent_count(_c[_i].id);
    return _t;
}
// "Vault Ash x2, Rime Salt x1" (or "none") for UI lines.
function reagent_summary_text() {
    reagents_ensure();
    var _c = reagent_catalog(), _t = "";
    for (var _i = 0; _i < array_length(_c); _i++) {
        var _n = reagent_count(_c[_i].id);
        if (_n > 0) _t += ((_t != "") ? ", " : "") + _c[_i].name + " x" + string(_n);
    }
    return (_t == "") ? "none" : _t;
}
// Spend n reagents of ANY kind, largest stacks first. Returns the names spent.
function reagent_spend_any(n) {
    reagents_ensure();
    var _spent = "";
    while (n > 0) {
        var _c = reagent_catalog(), _best = undefined, _bn = 0;
        for (var _i = 0; _i < array_length(_c); _i++) {
            var _k = reagent_count(_c[_i].id);
            if (_k > _bn) { _bn = _k; _best = _c[_i]; }
        }
        if (_best == undefined) break;
        variable_struct_set(global.reagents, _best.id, _bn - 1);
        _spent += ((_spent != "") ? ", " : "") + _best.name;
        n--;
    }
    return _spent;
}
// The reagent the CURRENT run's dungeon drops.
function reagent_for_current_dungeon() {
    var _d = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
    var _c = reagent_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].dungeon == _d) return _c[_i];
    return _c[0];
}
// Reagents a craft of this rarity asks (1 / 2 / 3).
function pattern_craft_reagents(_rarity) {
    return clamp(_rarity, 1, 3);
}

// =============================================================================
// VALUABLES (M 08-17): five items that exist ONLY to be sold - common -> legendary,
// steep gold. They ride the consumable inventory (item_category "consumable",
// effect_type "valuable") so they show in the pack / Petra's SELL tab with no new
// UI; every use path refuses them ("sell it at camp") and never consumes them.
// =============================================================================
function valuable_catalog() {
    var _v = [
        { c: create_consumable("Tarnished Locket",     "valuable", 0, "A keepsake with the portrait scratched out. Worth something to someone - sell it at camp.",         40),  r: 0 },
        { c: create_consumable("Silver Reliquary",     "valuable", 0, "A finger-bone in a silver box. The bone is worthless; the box is not - sell it at camp.",             120), r: 1 },
        { c: create_consumable("Sovereign's Signet",   "valuable", 0, "A heavy signet from a kingdom no map remembers. Petra knows a buyer - sell it at camp.",             320), r: 2 },
        { c: create_consumable("Star-Iron Idol",       "valuable", 0, "A squat idol of iron that fell from the sky. Collectors pay dearly - sell it at camp.",              750), r: 3 },
        { c: create_consumable("Crown Shard of Ironwake", "valuable", 0, "A shard of the crown the town was named for. Priceless, which is a price - sell it at camp.",     1600), r: 4 },
    ];
    for (var _i = 0; _i < array_length(_v); _i++) _v[_i].c.rarity = _v[_i].r;
    return _v;
}
// Roll a valuable from a source ("standard" / "elite" / "boss"): common-heavy weights.
function valuable_roll(source) {
    var _v = valuable_catalog();
    var _w = (source == "boss") ? [30, 30, 24, 12, 4] : ((source == "elite") ? [45, 30, 17, 7, 1] : [60, 28, 10, 2, 0]);
    var _t = 0; for (var _i = 0; _i < array_length(_w); _i++) _t += _w[_i];
    var _r = irandom(_t - 1);
    for (var _j = 0; _j < array_length(_w); _j++) { _r -= _w[_j]; if (_r < 0) return _v[_j].c; }
    return _v[0].c;
}

function pattern_craft_fee(_rarity) {
    var _g = 150; var _d = 20;
    if (_rarity == 2) { _g = 300; _d = 40; }
    if (_rarity >= 3) { _g = 600; _d = 80; }
    return { gold: cha_price(_g), dust: _d, ingot_rar: _rarity };
}
function pattern_reroll_fee(_rarity) { return cha_price(60 * max(1, _rarity)); }
function pattern_craft_base_val(_rarity) {
    if (_rarity <= 1) return 3;
    if (_rarity == 2) return 5;
    return 7;
}
function pattern_craft_gold_val(_rarity) {
    if (_rarity <= 1) return 40;
    if (_rarity == 2) return 90;
    return 210;
}

// The value band a family's blueprint tier buys at a crafted rarity. Stays
// inside the rarity's NATURAL value - tier I is a floor roll, tier III the
// full natural roll (spec: choice is the power budget, not magnitude).
function pattern_band_range(_stat_name, _rarity, _tier) {
    var _fe = pattern_family_entry(_stat_name);
    if (_fe == undefined) return { lo: 1, hi: 1 };
    var _t = clamp(_tier, 1, 3);
    if (_fe.kind == "school") {
        // School affixes already roll natural ranges: u 1, r 2-4, e 5-6.
        var _lo = 1; var _hi = 1;
        if (_rarity == 2) { _lo = 2; _hi = 4; }
        if (_rarity >= 3) { _lo = 5; _hi = 6; }
        var _span  = _hi - _lo;
        var _third = _span div 3;
        if (_t == 1) return { lo: _lo, hi: _lo + _third };
        if (_t == 2) { var _m = _lo + ceil(_span / 2); return { lo: min(_m, _hi), hi: min(_m, _hi) }; }
        return { lo: _hi - _third, hi: _hi };
    }
    // Stat/utility affixes have one natural value per rarity (u/r/e_val).
    var _nat = 1;
    if (variable_global_exists("affix_pool")) {
        for (var _i = 0; _i < array_length(global.affix_pool); _i++) {
            var _a = global.affix_pool[_i];
            if (_a.stat_name != _stat_name) continue;
            if (_rarity <= 1)      _nat = _a.u_val;
            else if (_rarity == 2) _nat = _a.r_val;
            else                   _nat = _a.e_val;
            break;
        }
    }
    if (_t == 1) { var _l1 = max(1, ceil(_nat * 0.60)); return { lo: _l1, hi: max(_l1, floor(_nat * 0.80)) }; }
    if (_t == 2) { var _l2 = max(1, ceil(_nat * 0.80)); return { lo: _l2, hi: max(_l2, _nat) }; }
    var _l3 = max(1, floor(_nat * 0.90));
    return { lo: _l3, hi: max(_l3, _nat) };
}
function pattern_band_roll(_stat_name, _rarity, _tier) {
    var _b = pattern_band_range(_stat_name, _rarity, _tier);
    return irandom_range(_b.lo, _b.hi);
}
function pattern_band_text(_stat_name, _rarity, _tier) {
    var _b = pattern_band_range(_stat_name, _rarity, _tier);
    if (_b.lo == _b.hi) return "+" + string(_b.lo);
    // "+3 to +4", not "+3-4" - the dash read as dev shorthand (M 08-15 shot).
    return "+" + string(_b.lo) + " to +" + string(_b.hi);
}

// Build the crafted item. Fees are NOT spent here - the caller spends at the
// checkout commit so a failed build never eats materials (forge precedent).
// _affix_names: array of family stat_names (identity chosen, numbers rolled).
// _icon: an art-page entry, or undefined for Dorn's plain work.
function pattern_craft_build(_slot, _rarity, _base_stat, _affix_names, _icon, _name) {
    // 08-15 v2 (M): no separate base-stat pick - the wizard hands ONE list of
    // blueprint picks. The FIRST core stat among them becomes the item's base
    // line at full base value; everything else rolls as an affix. _base_stat
    // is kept in the signature for compat but "" means "derive from picks".
    var _core = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
    var _derived_base = _base_stat;
    var _roll_names = [];
    for (var _i = 0; _i < array_length(_affix_names); _i++) {
        var _nm = _affix_names[_i];
        var _is_core = false;
        for (var _c = 0; _c < array_length(_core); _c++) { if (_core[_c] == _nm) { _is_core = true; break; } }
        if (_derived_base == "" && _is_core) _derived_base = _nm;
        else array_push(_roll_names, _nm);
    }
    var _bv = (_derived_base == "") ? 0 : pattern_craft_base_val(_rarity);
    var _it = create_item(_name, _slot, _rarity, _derived_base, _bv,
        "pattern-crafted at Dorn's anvil", pattern_craft_gold_val(_rarity));
    _it.base_name = _name;
    _it.class_req = -1;
    var _tiers = [];
    for (var _i = 0; _i < array_length(_roll_names); _i++) {
        var _fn = _roll_names[_i];
        var _fe = pattern_family_entry(_fn);
        if (_fe == undefined) continue;
        var _tier = pattern_fam_tier(_fn);
        if (_tier < 1) continue;
        array_push(_it.affixes, {
            suffix: _fe.suffix, prefix: _fe.prefix,
            stat_name: _fn, stat_value: pattern_band_roll(_fn, _rarity, _tier),
        });
        array_push(_tiers, { stat_name: _fn, tier: _tier });
    }
    // SINGLE-AFFIX CONCENTRATION (M-locked 08-15): every unused pick slot
    // pours half a slot's worth into the chosen affixes - a 1-affix build on a
    // 3-slot quality rolls that affix at 2x its band, never exceeding what a
    // full spread would total. Spare counts TOTAL picks (a base-stat pick
    // occupies a slot even though it rolls as the base line, not an affix).
    var _pb_spare = max(0, pattern_affix_budget(_rarity) - array_length(_affix_names));
    var _pb_conc  = 1 + 0.5 * _pb_spare;
    if (_pb_conc > 1) {
        for (var _pci = 0; _pci < array_length(_it.affixes); _pci++) {
            _it.affixes[_pci].stat_value = max(1, round(_it.affixes[_pci].stat_value * _pb_conc));
        }
    }
    _it.gold_value = round(_it.gold_value * power(1.2, array_length(_it.affixes)));
    if (_slot == "weapon" || _slot == "ranged_weapon") {
        _it.weapon_damage = weapon_base_damage(_rarity);
        _it.two_handed    = false;
    }
    _it.socket_count = rune_sockets_for_rarity(_rarity);
    item_quality_stamp(_it, 60, 85);   // player-crafted keeps its band (the craft is the investment)
    _it.player_crafted = true;
    _it.pb_craft = { rar: _rarity, base_stat: _base_stat, fams: _tiers, conc: _pb_conc };
    if (_icon != undefined) {
        _it.icon_as = pattern_art_proxy(_icon);
    }
    _it.lore = "Pattern-crafted at Dorn's anvil from "
        + (variable_global_exists("player_name") ? global.player_name : "a wanderer")
        + "'s book - its maker chose every line of it.";
    return _it;
}

// Paid re-roll: the identity stays, every rolled NUMBER re-rolls within the
// same band each affix was crafted at (advancing a blueprint later doesn't
// retro-buff old pieces - craft a new one). Weapons re-roll flat damage too.
function pattern_craft_reroll(_it) {
    if (!is_struct(_it) || !variable_struct_exists(_it, "pb_craft")) return false;
    var _pc = _it.pb_craft;
    for (var _i = 0; _i < array_length(_it.affixes); _i++) {
        var _row = _it.affixes[_i];
        if (!is_struct(_row) || !variable_struct_exists(_row, "stat_name")) continue;
        for (var _j = 0; _j < array_length(_pc.fams); _j++) {
            if (_pc.fams[_j].stat_name == _row.stat_name) {
                var _rr_conc = variable_struct_exists(_pc, "conc") ? _pc.conc : 1;
                _row.stat_value = max(1, round(pattern_band_roll(_row.stat_name, _pc.rar, _pc.fams[_j].tier) * _rr_conc));
                break;
            }
        }
    }
    if (_it.slot == "weapon" || _it.slot == "ranged_weapon") {
        if (!(variable_struct_exists(_it, "two_handed") && _it.two_handed)) {
            _it.weapon_damage = weapon_base_damage(_pc.rar);
        }
    }
    return true;
}

// ---- NAME GENERATOR (M: "rolls what the game would call it... plus some
// funny flavor"). Standard rolls use the chosen affixes' own prefix/suffix
// pools - the exact words a natural drop would wear. ~1 in 5 rolls comes from
// the flavor page instead. Random button re-rolls; typing always wins.
function pattern_name_noun(_slot, _icon) {
    // The chosen art's last word is the most honest noun ("Ironhide Bulwark"
    // -> "Bulwark"); Dorn's plain work falls back to a slot pool.
    if (_icon != undefined) {
        var _bn = _icon.base_name;
        var _sp = string_last_pos(" ", _bn);
        var _w  = (_sp > 0) ? string_delete(_bn, 1, _sp) : _bn;
        if (string_length(_w) >= 3) return _w;
    }
    var _pool = ["Blade", "Edge", "Brand", "Cleaver", "Warblade"];
    switch (_slot) {
        case "ranged_weapon": _pool = ["Bow", "Longbow", "Recurve", "Warbow"]; break;
        case "offhand":       _pool = ["Ward", "Bulwark", "Buckler", "Aegis"]; break;
        case "helm":          _pool = ["Helm", "Casque", "Visage", "Crown"]; break;
        case "chest":         _pool = ["Cuirass", "Mail", "Vestment", "Plate"]; break;
        case "gloves":        _pool = ["Grips", "Gauntlets", "Fists", "Wraps"]; break;
        case "boots":         _pool = ["Treads", "Greaves", "Striders", "Boots"]; break;
        case "amulet":        _pool = ["Amulet", "Talisman", "Locket", "Charm"]; break;
        case "ring":          _pool = ["Ring", "Band", "Signet", "Loop"]; break;
    }
    return _pool[irandom(array_length(_pool) - 1)];
}
function pattern_name_roll(_slot, _base_stat, _affix_names, _icon) {
    var _noun = pattern_name_noun(_slot, _icon);
    // Flavor page (M asked for "some funny flavor entries").
    if (irandom(99) < 20) {
        var _fl = ["Dorn's Second Draft", "The Backup Plan", "Warranty Voider",
                   "The " + _noun + " of Theseus", "Probably Fine", "Grudge, Settled",
                   "Family Heirloom (New)", "The Apologetic " + _noun,
                   "Ninth Attempt", "Dorn Was Paid For This", "The Pointed Argument",
                   "Customer's Own " + _noun];
        return string_copy(_fl[irandom(array_length(_fl) - 1)], 1, 24);
    }
    var _pfx = ""; var _sfx = "";
    var _n_af = array_length(_affix_names);
    if (_n_af >= 1) {
        var _f1 = pattern_family_entry(_affix_names[0]);
        var _f2 = pattern_family_entry(_affix_names[_n_af - 1]);
        if (_f1 != undefined) _pfx = _f1.prefix;
        if (_f2 != undefined) _sfx = _f2.suffix;
    }
    var _bs = pattern_family_entry(_base_stat);
    if (_pfx == "" && _bs != undefined) _pfx = _bs.prefix;
    if (_sfx == "" && _bs != undefined) _sfx = _bs.suffix;
    // 1 affix reads "Noun of X"; 2 read "Prefix Noun of Y" - the game's own rule.
    var _nm;
    if (_n_af >= 2)      _nm = _pfx + " " + _noun + " " + _sfx;
    else if (irandom(1) == 0) _nm = _noun + " " + _sfx;
    else                 _nm = _pfx + " " + _noun;
    return string_copy(_nm, 1, 24);
}
