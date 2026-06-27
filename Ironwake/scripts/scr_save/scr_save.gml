// =============================================================================
// scr_save.gml
// Meta-progression save / load for Ironwake.
// Format: JSON via json_stringify / json_parse, written to "ironwake_save.json"
// in GMS2's sandboxed save directory.
//
// save_game() - call at the end of end_run() and on any other permanent state change.
// load_game() - call once at the end of obj_game_controller Create_0.
// =============================================================================

// ---------------------------------------------------------------------------
// get_slot_preview(slot_num)
// Reads a save slot file and returns a lightweight preview struct, or
// undefined if the slot is empty. Does NOT touch any global state.
// ---------------------------------------------------------------------------
function get_slot_preview(slot_num) {
    var _fname = "ironwake_save_" + string(slot_num) + ".json";
    if (!file_exists(_fname)) return undefined;
    var _file = file_text_open_read(_fname);
    var _json = "";
    while (!file_text_eof(_file)) {
        _json += file_text_read_string(_file);
        file_text_readln(_file);
    }
    file_text_close(_file);
    if (string_char_at(_json, 1) != "{") return undefined;
    var _s;
    try { _s = json_parse(_json); } catch (_e) { return undefined; }
    if (!is_struct(_s)) return undefined;
    return {
        player_name:          variable_struct_exists(_s, "player_name")          ? _s.player_name          : "Unknown",
        run_count:            variable_struct_exists(_s, "run_count")            ? _s.run_count            : 0,
        gold:                 variable_struct_exists(_s, "gold")                 ? _s.gold                 : 0,
        best_floor:           variable_struct_exists(_s, "best_floor")           ? _s.best_floor           : 0,
        dungeon_clears_total: variable_struct_exists(_s, "dungeon_clears_total") ? _s.dungeon_clears_total : 0,
    };
}

function save_game() {
    if (!variable_global_exists("gold")) return;
    if (!variable_global_exists("save_slot") || global.save_slot < 0) return;

    var _save = {
        // Economy
        gold:        global.gold,
        player_name: global.player_name,

        // Lifetime stats
        run_count:   global.run_count,
        best_floor:  global.best_floor,
        total_kills: global.total_kills,

        // Last run results (kept for hub summary panel)
        last_run_result:      global.last_run_result,
        last_run_gold:        global.last_run_gold,
        last_run_kills:       global.last_run_kills,
        last_run_mercy_gold:  global.last_run_mercy_gold,
        last_run_perm_points: global.last_run_perm_points,
        last_run_mercy_item:  variable_global_exists("last_run_mercy_item") ? global.last_run_mercy_item : "",

        // Permanent bonuses (perm alloc screen)
        perm_str_bonus:      global.perm_str_bonus,
        perm_dex_bonus:      global.perm_dex_bonus,
        perm_con_bonus:      global.perm_con_bonus,
        perm_int_bonus:      global.perm_int_bonus,
        perm_wis_bonus:      global.perm_wis_bonus,
        perm_cha_bonus:      global.perm_cha_bonus,
        pending_perm_points: global.pending_perm_points,

        // Hub progression gate
        hub_unlocks: global.hub_unlocks,

        // Ability / trait loadout choices
        player_loadout: global.player_loadout,
        player_traits:  global.player_traits,

        // Trait unlock registry
        traits_unlocked: global.traits_unlocked,

        // Vex the Trainer permanent purchases
        bonus_trait_slots:  variable_global_exists("bonus_trait_slots")  ? global.bonus_trait_slots  : 0,
        unlocked_abilities: variable_global_exists("unlocked_abilities") ? global.unlocked_abilities : [],
        trait_potency:      variable_global_exists("trait_potency")      ? global.trait_potency      : {},

        // Item codex (discovered item names)
        items_discovered: global.items_discovered,

        // Run history log
        run_history: global.run_history,

        // Equipped items (8 slots, index matches equip_slot_index())
        inventory: global.inventory,

        // Hub-safe gear and consumable storage
        equipment_stash:  global.equipment_stash,
        consumable_stash: global.consumable_stash,

        // Carried consumable pack (run buffer). Saved so potions withdrawn from
        // the stash into your pack - or carried forward after a winning run -
        // survive a reload. (Equipment's carried_items is intentionally NOT saved
        // so abandoning a run reverts cleanly; consumables persist because losing
        // bought/withdrawn potions on reload was a silent data-loss trap.)
        consumable_inventory: global.consumable_inventory,

        // Shop stock (per-slot persistence). Dorn's rotating gear (with sold flags)
        // and Petra's special are session globals that USED to be shared across every
        // slot - so an item one character bought stayed "sold" in another character's
        // shop. Saving them per slot makes each character's shop independent and makes
        // a purchase survive a reload until the next run re-rolls the stock.
        dorn_stock:          variable_global_exists("dorn_stock")          ? global.dorn_stock          : [],
        petra_stock_special: variable_global_exists("petra_stock_special") ? global.petra_stock_special : undefined,
        petra_special_qty:   variable_global_exists("petra_special_qty")   ? global.petra_special_qty   : 0,

        // Rune system (Maren) - socketed gear runes ride on the item structs above
        rune_inventory: variable_global_exists("rune_inventory") ? global.rune_inventory : [],
        rune_dust:      variable_global_exists("rune_dust")      ? global.rune_dust      : 0,
        aspect_slots:   variable_global_exists("aspect_slots")   ? global.aspect_slots   : 2,
        aspect_runes:   variable_global_exists("aspect_runes")   ? global.aspect_runes   : [],

        // Vael transmog
        player_skin:    variable_global_exists("player_skin")    ? global.player_skin    : "default",
        unlocked_skins: variable_global_exists("unlocked_skins") ? global.unlocked_skins : [],
        player_gender:  variable_global_exists("player_gender")  ? global.player_gender  : "m",

        // Boons (run-scoped)
        run_boons:      variable_global_exists("run_boons")      ? global.run_boons      : [],
        run_curses:     variable_global_exists("run_curses")     ? global.run_curses     : [],

        // Onboarding: which tips this profile has already seen (per-slot).
        // The enable/disable preference is global and lives in settings.ini, not here.
        tutorial_seen: variable_global_exists("tutorial_seen") ? global.tutorial_seen : {},

        // Dungeon ascendance progression
        dungeon_ascendance_unlocked: variable_global_exists("dungeon_ascendance_unlocked") ? global.dungeon_ascendance_unlocked : { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 },
        dungeon_clears:              variable_global_exists("dungeon_clears")              ? global.dungeon_clears              : { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 },
        dungeon_clears_total:        variable_global_exists("dungeon_clears_total")        ? global.dungeon_clears_total        : 0,
        total_boss_kills:            variable_global_exists("total_boss_kills")            ? global.total_boss_kills            : 0,
        highest_run_level:           variable_global_exists("highest_run_level")           ? global.highest_run_level           : 1,
        perm_hp_battle_hardened:     variable_global_exists("perm_hp_battle_hardened")     ? global.perm_hp_battle_hardened     : 0,
        chosen_portrait:             variable_global_exists("chosen_portrait")             ? global.chosen_portrait             : 0,
        chosen_class:                variable_global_exists("chosen_class")                ? global.chosen_class                : 0,
        chosen_stats:                variable_global_exists("chosen_stats")                ? global.chosen_stats                : undefined,
    };

    var _json = json_stringify(_save);
    var _fname = "ironwake_save_" + string(global.save_slot) + ".json";
    var _file = file_text_open_write(_fname);
    file_text_write_string(_file, _json);
    file_text_close(_file);
}


// ---------------------------------------------------------------------------
// new_game_reset()
// Wipes every PERSISTED run/meta global back to first-launch defaults so a New
// Game starts from a clean slate. Without this, a New Game inherited whatever was
// last in memory - e.g. the gold / run history / inventory / stats of a save you
// had just LOADED - and the first save_game() then wrote that stale state into the
// new slot (the "new file has my Save 1 Arcanist's gold" bug). Resets EXACTLY the
// set save_game() persists (the leak surface); character creation then fills in
// name/class/stats/gender/portrait. Catalogs/pools (affix_pool, abilities_*,
// traits_all, audio) are NOT touched - they aren't persisted and load once at boot.
// Call right before entering character creation for a New Game, AND right before
// load_game() when loading a slot, so loading a character starts from a clean slate
// and can't inherit the previously-active character's non-overwritten globals.
// ---------------------------------------------------------------------------
function new_game_reset() {
    // Economy
    global.gold             = 0;
    global.current_run_gold = 0;
    global.player_name      = "Hero";

    // Lifetime stats
    global.run_count   = 0;
    global.best_floor  = 0;
    global.total_kills = 0;

    // Last-run summary (hub panel)
    global.last_run_result      = 0;
    global.last_run_gold        = 0;
    global.last_run_kills       = 0;
    global.last_run_mercy_gold  = 0;
    global.last_run_perm_points = 0;
    global.last_run_mercy_item  = "";

    // Permanent stat bonuses
    global.perm_str_bonus      = 0;
    global.perm_dex_bonus      = 0;
    global.perm_con_bonus      = 0;
    global.perm_int_bonus      = 0;
    global.perm_wis_bonus      = 0;
    global.perm_cha_bonus      = 0;
    global.pending_perm_points = 0;

    // Hub progression gate
    global.hub_unlocks = 0;

    // Ability / trait loadout + unlock registry
    global.player_loadout  = ["", "", "", "", ""];
    global.player_traits   = ["", ""];
    global.traits_unlocked = {
        sense: true, scavenger: true, thick_skin: true,
        lucky_find: false, salvager: false, soul_siphon: false,
        crimson_reserve: false, phantom_step: false,
        quick_recovery: false, treasure_hunter: false, battle_hardened: false,
        iron_will: false, ley_tap: false, arcane_surge: false,
        vampiric_edge: false, berserker_rage: false, shadow_meld: false,
        serrated_strikes: false, expanded_arsenal: false, prospector: false,
        last_stand: false, focused_power: false, chain_caster: false, plaguebearer: false,
    };

    // Vex the Trainer permanent purchases
    global.bonus_trait_slots  = 0;
    global.unlocked_abilities = [];
    global.trait_potency      = {};

    // Item codex
    global.items_discovered = [];

    // Run history log
    global.run_history = [];

    // Equipped items + hub storage (9 slots; index 8 = Ranged Weapon)
    global.inventory            = array_create(9, undefined);
    global.equipment_stash      = [];
    global.consumable_stash     = [];
    global.consumable_inventory = [];

    // Shop stock (per-slot). Cleared so no previous character's Dorn/Petra stock
    // bleeds in; left empty here, then either restored by load_game() or freshly
    // rolled by the hub on entry (restock_shops()).
    global.dorn_stock          = [];
    global.petra_stock_special = undefined;
    global.petra_special_qty   = 0;

    // Rune system (Maren)
    global.rune_inventory = [];
    global.rune_dust      = 0;
    global.aspect_slots   = 2;
    global.aspect_runes   = [];

    // Transmog (Vael)
    global.player_skin    = "default";
    global.unlocked_skins = [];
    global.player_gender  = "m";

    // Run modifiers
    global.run_boons  = [];
    global.run_curses = [];

    // Onboarding (per-slot)
    global.tutorial_seen = {};

    // Dungeon ascendance progression
    global.dungeon_ascendance_unlocked = { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 };
    global.dungeon_clears              = { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 };
    global.dungeon_clears_total        = 0;
    global.total_boss_kills            = 0;
    global.highest_run_level           = 1;
    global.perm_hp_battle_hardened     = 0;
    global.selected_ascendance         = 0;
    global.selected_dungeon            = "ashen_vault";

    // Character identity - defaulted here, set during character creation
    global.chosen_portrait = 0;
    global.chosen_class    = 0;
    global.chosen_stats    = undefined;
}


// Recover a character's class from a saved ability loadout. Abilities are
// class-specific (the starter + Vex pools differ per class), so the loadout's
// names uniquely point back to the owning class. Used to repair saves written
// before chosen_class was persisted (which silently reverted to Arcanist).
// Returns 0..2, or -1 if nothing class-specific matched.
function class_infer_from_loadout(_loadout) {
    if (!is_array(_loadout)) return -1;
    var _lists = [global.abilities_arcanist, global.abilities_bloodwarden, global.abilities_shadowstrider];
    var _best = -1, _best_count = 0;
    for (var _c = 0; _c < 3; _c++) {
        var _count = 0;
        for (var _li = 0; _li < array_length(_loadout); _li++) {
            var _nm = _loadout[_li];
            if (!is_string(_nm) || _nm == "") continue;
            for (var _ai = 0; _ai < array_length(_lists[_c]); _ai++) {
                if (_lists[_c][_ai].name == _nm) { _count++; break; }
            }
        }
        if (_count > _best_count) { _best_count = _count; _best = _c; }
    }
    return _best;
}

function load_game() {
    if (!variable_global_exists("save_slot") || global.save_slot < 0) return;
    var _fname = "ironwake_save_" + string(global.save_slot) + ".json";
    if (!file_exists(_fname)) return;

    var _file = file_text_open_read(_fname);
    var _json = "";
    while (!file_text_eof(_file)) {
        _json += file_text_read_string(_file);
        file_text_readln(_file);
    }
    file_text_close(_file);

    if (string_char_at(_json, 1) != "{") return;
    var _s;
    try { _s = json_parse(_json); } catch (_e) { return; }
    if (!is_struct(_s)) return;

    // Economy
    if (variable_struct_exists(_s, "gold"))        global.gold        = _s.gold;
    if (variable_struct_exists(_s, "player_name")) global.player_name = _s.player_name;

    // Character class. New saves store it directly; older saves predate the field
    // and must recover it from the ability loadout, otherwise the character would
    // silently load as Arcanist (class 0). (Bug fix: class was never persisted.)
    if (variable_struct_exists(_s, "chosen_class")) {
        global.chosen_class = _s.chosen_class;
    } else {
        var _recovered = class_infer_from_loadout(variable_struct_exists(_s, "player_loadout") ? _s.player_loadout : []);
        if (_recovered >= 0) global.chosen_class = _recovered;
    }

    // Base stat block. New saves store it; older saves predate it and must rebuild
    // it from the (now-resolved) class, otherwise the character menu reads an unset
    // global.chosen_stats and crashes. (Same omission as chosen_class above.)
    if (variable_struct_exists(_s, "chosen_stats") && is_struct(_s.chosen_stats)) {
        global.chosen_stats = _s.chosen_stats;
    } else if (!variable_global_exists("chosen_stats") || is_undefined(global.chosen_stats)) {
        var _cls = (variable_global_exists("chosen_class") && !is_undefined(global.chosen_class)) ? global.chosen_class : 0;
        global.chosen_stats = stats_init(_cls);
    }

    // Lifetime stats
    if (variable_struct_exists(_s, "run_count"))   global.run_count   = _s.run_count;
    if (variable_struct_exists(_s, "best_floor"))  global.best_floor  = _s.best_floor;
    if (variable_struct_exists(_s, "total_kills")) global.total_kills = _s.total_kills;

    // Last run results
    if (variable_struct_exists(_s, "last_run_result"))      global.last_run_result      = _s.last_run_result;
    if (variable_struct_exists(_s, "last_run_gold"))        global.last_run_gold        = _s.last_run_gold;
    if (variable_struct_exists(_s, "last_run_kills"))       global.last_run_kills       = _s.last_run_kills;
    if (variable_struct_exists(_s, "last_run_mercy_gold"))  global.last_run_mercy_gold  = _s.last_run_mercy_gold;
    if (variable_struct_exists(_s, "last_run_perm_points")) global.last_run_perm_points = _s.last_run_perm_points;
    if (variable_struct_exists(_s, "last_run_mercy_item"))  global.last_run_mercy_item  = _s.last_run_mercy_item;

    // Permanent bonuses
    if (variable_struct_exists(_s, "perm_str_bonus"))      global.perm_str_bonus      = _s.perm_str_bonus;
    if (variable_struct_exists(_s, "perm_dex_bonus"))      global.perm_dex_bonus      = _s.perm_dex_bonus;
    if (variable_struct_exists(_s, "perm_con_bonus"))      global.perm_con_bonus      = _s.perm_con_bonus;
    if (variable_struct_exists(_s, "perm_int_bonus"))      global.perm_int_bonus      = _s.perm_int_bonus;
    if (variable_struct_exists(_s, "perm_wis_bonus"))      global.perm_wis_bonus      = _s.perm_wis_bonus;
    if (variable_struct_exists(_s, "perm_cha_bonus"))      global.perm_cha_bonus      = _s.perm_cha_bonus;
    if (variable_struct_exists(_s, "pending_perm_points")) global.pending_perm_points = _s.pending_perm_points;

    // Hub progression
    if (variable_struct_exists(_s, "hub_unlocks")) global.hub_unlocks = _s.hub_unlocks;

    // Loadout - copy element-by-element to preserve existing array length
    if (variable_struct_exists(_s, "player_loadout") && is_array(_s.player_loadout)) {
        for (var _i = 0; _i < min(5, array_length(_s.player_loadout)); _i++) {
            global.player_loadout[_i] = _s.player_loadout[_i];
        }
    }
    // Replace the whole array so bought/Crown trait slots beyond slot 2 persist.
    if (variable_struct_exists(_s, "player_traits") && is_array(_s.player_traits)) {
        global.player_traits = _s.player_traits;
        if (array_length(global.player_traits) < 2) {
            // Always keep at least the two base slots so index access stays safe.
            while (array_length(global.player_traits) < 2) array_push(global.player_traits, "");
        }
    }

    // Vex the Trainer permanent purchases
    if (variable_struct_exists(_s, "bonus_trait_slots"))  global.bonus_trait_slots  = _s.bonus_trait_slots;
    if (variable_struct_exists(_s, "unlocked_abilities") && is_array(_s.unlocked_abilities)) {
        global.unlocked_abilities = _s.unlocked_abilities;
    }
    if (variable_struct_exists(_s, "trait_potency") && is_struct(_s.trait_potency)) {
        global.trait_potency = _s.trait_potency;
    }

    // Trait unlock registry - only write keys already declared in the default struct
    // so a corrupt / future save file can't inject unknown trait keys
    if (variable_struct_exists(_s, "traits_unlocked") && is_struct(_s.traits_unlocked)) {
        var _save_keys = variable_struct_get_names(_s.traits_unlocked);
        for (var _i = 0; _i < array_length(_save_keys); _i++) {
            var _k = _save_keys[_i];
            if (variable_struct_exists(global.traits_unlocked, _k)) {
                variable_struct_set(global.traits_unlocked, _k,
                    variable_struct_get(_s.traits_unlocked, _k));
            }
        }
    }

    // Item codex
    if (variable_struct_exists(_s, "items_discovered") && is_array(_s.items_discovered)) {
        global.items_discovered = _s.items_discovered;
    }

    // Run history
    if (variable_struct_exists(_s, "run_history") && is_array(_s.run_history)) {
        global.run_history = _s.run_history;
    }

    // Equipped items. global.inventory is pre-sized to 9 (index 8 = Ranged Weapon).
    // Old saves only have 8 entries - min() leaves index 8 undefined (empty ranged
    // slot), so the migration is automatic and lossless (SYSTEMS_WEAPON_ROLES.md §A).
    if (variable_struct_exists(_s, "inventory") && is_array(_s.inventory)) {
        for (var _ii = 0; _ii < min(9, array_length(_s.inventory)); _ii++) {
            global.inventory[_ii] = _s.inventory[_ii];
            item_migrate_weapon_fields(global.inventory[_ii]);   // backfill weapon_damage/two_handed
        }
    }

    // Hub-safe stash storage
    if (variable_struct_exists(_s, "equipment_stash") && is_array(_s.equipment_stash)) {
        global.equipment_stash = _s.equipment_stash;
        for (var _esi = 0; _esi < array_length(global.equipment_stash); _esi++) {
            item_migrate_weapon_fields(global.equipment_stash[_esi]);
        }
    }
    if (variable_struct_exists(_s, "consumable_stash") && is_array(_s.consumable_stash)) {
        global.consumable_stash = _s.consumable_stash;
    }
    // Carried consumable pack (run buffer) - restore so withdrawn/carried-forward
    // potions survive a reload. Older saves lack this key; the gc-Create default ([])
    // covers them.
    if (variable_struct_exists(_s, "consumable_inventory") && is_array(_s.consumable_inventory)) {
        global.consumable_inventory = _s.consumable_inventory;
    }

    // Shop stock (per-slot). Restore this character's Dorn/Petra stock. Saves
    // written before shop persistence lack these keys; new_game_reset() leaves
    // dorn_stock empty in that case and the hub seeds a fresh shop on entry.
    if (variable_struct_exists(_s, "dorn_stock") && is_array(_s.dorn_stock)) {
        global.dorn_stock = _s.dorn_stock;
        for (var _dsi = 0; _dsi < array_length(global.dorn_stock); _dsi++) {
            var _de = global.dorn_stock[_dsi];
            if (is_struct(_de) && variable_struct_exists(_de, "item")) {
                item_migrate_weapon_fields(_de.item);   // backfill weapon_damage/two_handed on shop gear
            }
        }
    }
    if (variable_struct_exists(_s, "petra_stock_special") && is_struct(_s.petra_stock_special)) {
        global.petra_stock_special = _s.petra_stock_special;
    } else {
        global.petra_stock_special = undefined;
    }
    if (variable_struct_exists(_s, "petra_special_qty")) global.petra_special_qty = _s.petra_special_qty;

    // Rune system (Maren)
    if (variable_struct_exists(_s, "rune_inventory") && is_array(_s.rune_inventory)) {
        global.rune_inventory = _s.rune_inventory;
    }
    if (variable_struct_exists(_s, "rune_dust"))    global.rune_dust    = _s.rune_dust;
    if (variable_struct_exists(_s, "aspect_slots")) global.aspect_slots = _s.aspect_slots;
    if (variable_struct_exists(_s, "aspect_runes") && is_array(_s.aspect_runes)) {
        global.aspect_runes = _s.aspect_runes;
    }
    if (variable_struct_exists(_s, "player_skin"))    global.player_skin    = _s.player_skin;
    if (variable_struct_exists(_s, "unlocked_skins") && is_array(_s.unlocked_skins)) {
        global.unlocked_skins = _s.unlocked_skins;
    }
    if (variable_struct_exists(_s, "player_gender"))  global.player_gender  = _s.player_gender;
    // Boons and curses are run-scoped (cleared in end_run). A save can only hold
    // non-empty values if it was written mid-run (boon_grant/curse_grant save on
    // pickup); since loading always lands in the hub between runs, restoring them
    // would carry stale modifiers into the next run. Always start a loaded game with
    // none - this is the fresh-run reset the abandoned-run case needs.
    global.run_boons  = [];
    global.run_curses = [];
    if (variable_struct_exists(_s, "tutorial_seen") && is_struct(_s.tutorial_seen)) {
        global.tutorial_seen = _s.tutorial_seen;
    }
    // NOTE: global.tutorial_enabled is intentionally NOT restored here. The
    // enable/disable preference is a global setting owned by settings.ini (see
    // audio_settings_init/save) so it persists from the title and across all
    // profiles; loading a slot must not clobber it. Only tutorial_seen is per-slot.

    // Dungeon ascendance progression
    if (variable_struct_exists(_s, "dungeon_ascendance_unlocked") && is_struct(_s.dungeon_ascendance_unlocked)) {
        var _dkeys = ["ashen_vault", "scorched_depths", "tundra_tomb"];
        if (!variable_global_exists("dungeon_ascendance_unlocked")) {
            global.dungeon_ascendance_unlocked = { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 };
        }
        for (var _di = 0; _di < array_length(_dkeys); _di++) {
            var _dk = _dkeys[_di];
            if (variable_struct_exists(_s.dungeon_ascendance_unlocked, _dk)) {
                variable_struct_set(global.dungeon_ascendance_unlocked, _dk,
                    variable_struct_get(_s.dungeon_ascendance_unlocked, _dk));
            }
        }
    }
    if (variable_struct_exists(_s, "dungeon_clears") && is_struct(_s.dungeon_clears)) {
        var _dkeys2 = ["ashen_vault", "scorched_depths", "tundra_tomb"];
        if (!variable_global_exists("dungeon_clears")) {
            global.dungeon_clears = { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 };
        }
        for (var _di = 0; _di < array_length(_dkeys2); _di++) {
            var _dk = _dkeys2[_di];
            if (variable_struct_exists(_s.dungeon_clears, _dk)) {
                variable_struct_set(global.dungeon_clears, _dk,
                    variable_struct_get(_s.dungeon_clears, _dk));
            }
        }
    }

    // New progression counters
    if (variable_struct_exists(_s, "dungeon_clears_total"))    global.dungeon_clears_total    = _s.dungeon_clears_total;
    if (variable_struct_exists(_s, "total_boss_kills"))        global.total_boss_kills        = _s.total_boss_kills;
    if (variable_struct_exists(_s, "highest_run_level"))       global.highest_run_level       = _s.highest_run_level;
    if (variable_struct_exists(_s, "perm_hp_battle_hardened")) global.perm_hp_battle_hardened = _s.perm_hp_battle_hardened;
    if (variable_struct_exists(_s, "chosen_portrait"))         global.chosen_portrait         = _s.chosen_portrait;
}
