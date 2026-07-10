// =============================================================================
// scr_save.gml
// Meta-progression save / load for Ironwake.
// Format: JSON via json_stringify / json_parse, written to "ironwake_save.json"
// in GMS2's sandboxed save directory.
//
// save_game() - call at the end of end_run() and on any other permanent state change.
// load_game() - call once at the end of obj_game_controller Create_0.
// =============================================================================

// Save-format version, stamped into every save (pre-Steam hardening, 2026-07-07).
// Saves written before the stamp read as version 0. Loading is field-tolerant in
// both directions (unknown fields ignored, missing fields defaulted), so bump this
// ONLY when a field's MEANING changes and add the fix-up in load_game's migration
// block - never repurpose an old field name without one.
#macro SAVE_FORMAT_VERSION 2
// v2 (2026-07-08): weapon flat damage became a per-item RANGE roll (was fixed per
// rarity) and caster ranged weapons gained a rolled wpn_school. Loading a v1 save
// re-rolls every non-hand-tuned weapon once (item_migrate_weapon_fields force flag).

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
        ironwake_stands:      variable_struct_exists(_s, "ironwake_stands")      ? _s.ironwake_stands      : false,
    };
}

function save_game() {
    if (!variable_global_exists("gold")) return;
    if (!variable_global_exists("save_slot") || global.save_slot < 0) return;

    var _save = {
        // Format stamp + write time (see SAVE_FORMAT_VERSION at the top of this file)
        save_version: SAVE_FORMAT_VERSION,
        saved_at:     date_datetime_string(date_current_datetime()),

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

        // Vael spell tints (expression #4) + epithet (expression #5)
        unlocked_tints: variable_global_exists("unlocked_tints") ? global.unlocked_tints : [],
        school_tints:   variable_global_exists("school_tints")   ? global.school_tints   : {},
        player_epithet: variable_global_exists("player_epithet") ? global.player_epithet : "",

        // Ability mastery (expression #2): lifetime casts + spent notch picks
        ability_casts:   variable_global_exists("ability_casts")   ? global.ability_casts   : {},
        ability_mastery: variable_global_exists("ability_mastery") ? global.ability_mastery : {},

        // Boons (run-scoped)
        run_boons:      variable_global_exists("run_boons")      ? global.run_boons      : [],
        run_curses:     variable_global_exists("run_curses")     ? global.run_curses     : [],

        // NPC affinity (thin track, meta-persistent per slot)
        npc_affinity:   variable_global_exists("npc_affinity")   ? global.npc_affinity   : undefined,

        // Phase 4a: quest state, journal badges + per-NPC interaction ledger.
        quests:          (variable_global_exists("quests")          && is_array(global.quests))           ? global.quests          : [],
        journal_badges:  (variable_global_exists("journal_badges")  && is_struct(global.journal_badges))  ? global.journal_badges  : undefined,
        npc_ledger:      (variable_global_exists("npc_ledger")      && is_struct(global.npc_ledger))      ? global.npc_ledger      : undefined,
        // Tavern board requests (BOARD_REQUESTS_SPEC.md): generated defs must persist
        // (unlike the code-authored catalog), plus the id sequence + Reforge Chits.
        board_requests:  (variable_global_exists("board_requests")  && is_array(global.board_requests))   ? global.board_requests  : [],
        board_seq:       variable_global_exists("board_seq")     ? global.board_seq     : 0,
        reforge_chits:   variable_global_exists("reforge_chits") ? global.reforge_chits : 0,
        // Board v2: special-posting cadence must survive reload (rerolls_used is
        // board-age-scoped and resets every run end - not worth persisting).
        board_special_countdown: variable_global_exists("board_special_countdown") ? global.board_special_countdown : 5,
        // Dice v2: High Table cadence + a standing invitation both survive reload
        // (an ACTIVE bracket doesn't - quitting mid-tournament forfeits).
        kb_tourney_countdown: variable_global_exists("kb_tourney_countdown") ? global.kb_tourney_countdown : 5,
        kb_tourney_ready:     variable_global_exists("kb_tourney_ready")     ? global.kb_tourney_ready     : false,
        // Phase 4b: gifts - owned trinkets, revealed tastes, the one-per-run latch.
        gift_trinkets:    (variable_global_exists("gift_trinkets")    && is_array(global.gift_trinkets))     ? global.gift_trinkets    : [],
        npc_tastes_known: (variable_global_exists("npc_tastes_known") && is_struct(global.npc_tastes_known)) ? global.npc_tastes_known : undefined,
        gift_given:       (variable_global_exists("gift_given"))                                             ? global.gift_given       : false,

        // Petra Treasure Trader order (cross-run persistent; undefined = none)
        petra_order:    variable_global_exists("petra_order")    ? global.petra_order    : undefined,

        // Pets (cross-run persistent roster + active companion + uid counter)
        pet_roster:     variable_global_exists("pet_roster")     ? global.pet_roster     : [],
        active_pet:     variable_global_exists("active_pet")     ? global.active_pet     : -1,
        pet_next_id:    variable_global_exists("pet_next_id")    ? global.pet_next_id    : 1,
        pet_starter_given: variable_global_exists("pet_starter_given") ? global.pet_starter_given : false,
        pet_feed_pouch: (variable_global_exists("pet_feed_pouch") && is_struct(global.pet_feed_pouch)) ? global.pet_feed_pouch : {},
        // Bond-axis extras: preferred-feed discoveries (per species), Bairc's donated
        // garden, and the one-time lore ledger + any still-unshown queued lines.
        pet_pref_discovered: (variable_global_exists("pet_pref_discovered") && is_struct(global.pet_pref_discovered)) ? global.pet_pref_discovered : {},
        bairc_donated:   (variable_global_exists("bairc_donated")   && is_array(global.bairc_donated))    ? global.bairc_donated   : [],
        bairc_lore_seen: (variable_global_exists("bairc_lore_seen") && is_struct(global.bairc_lore_seen)) ? global.bairc_lore_seen : {},
        bairc_lore_queue:(variable_global_exists("bairc_lore_queue")&& is_array(global.bairc_lore_queue)) ? global.bairc_lore_queue : [],

        // Onboarding: which tips this profile has already seen (per-slot).
        // The enable/disable preference is global and lives in settings.ini, not here.
        tutorial_seen: variable_global_exists("tutorial_seen") ? global.tutorial_seen : {},

        // Dungeon ascendance progression
        dungeon_ascendance_unlocked: variable_global_exists("dungeon_ascendance_unlocked") ? global.dungeon_ascendance_unlocked : { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 },
        dungeon_clears:              variable_global_exists("dungeon_clears")              ? global.dungeon_clears              : { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 },
        dungeon_clears_total:        variable_global_exists("dungeon_clears_total")        ? global.dungeon_clears_total        : 0,
        // Win state (WIN_STATE_SPEC.md): per-dungeon Awakening-V clears + the ending flags
        dungeon_a5_clears:           variable_global_exists("dungeon_a5_clears")           ? global.dungeon_a5_clears           : { ashen_vault: false, scorched_depths: false, tundra_tomb: false },
        ironwake_stands:             variable_global_exists("ironwake_stands")             ? global.ironwake_stands             : false,
        ending_pending:              variable_global_exists("ending_pending")              ? global.ending_pending              : false,
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
        lucky_find: false, lucky_find_gold: false, salvager: false, soul_siphon: false,
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

    // Equipped items + hub storage (10 slots; index 8 = Ranged Weapon, 9 = Ring 2)
    global.inventory            = array_create(EQUIP_SLOT_COUNT, undefined);
    global.equipment_stash      = [];
    global.consumable_stash     = [];
    global.consumable_inventory = [];

    // NPC affinity (thin track) - fresh zeroed relationships for a new character.
    global.npc_affinity = affinity_fresh();

    // Phase 4a: quests / journal - clean slate.
    global.quests         = [];
    global.journal_badges = { npcs: {}, quests: {} };
    global.npc_ledger     = {};
    // Tavern board requests: empty - board_bootstrap() stocks it on first board open.
    global.board_requests = [];
    global.board_seq      = 0;
    global.reforge_chits  = 0;
    // Board v2 + dice v2 cadences: fresh clocks, no standing invitation.
    global.board_special_countdown = 5;
    global.board_rerolls_used      = 0;
    global.kb_tourney_countdown    = 5;
    global.kb_tourney_ready        = false;
    // Phase 4b: gifts - clean slate.
    global.gift_trinkets    = [];
    global.run_trinkets     = [];
    global.npc_tastes_known = {};
    global.gift_given       = false;

    // Petra Treasure Trader - no open order on a new character.
    global.petra_order = undefined;

    // Pets - a new character owns none yet (gets a starter on first hub visit).
    global.pet_roster  = [];
    global.active_pet  = -1;
    global.pet_next_id = 1;
    global.pet_starter_given = false;
    global.pet_feed_pouch    = {};
    global.pet_pref_discovered = {};
    global.bairc_donated       = [];
    global.bairc_lore_seen     = {};
    global.bairc_lore_queue    = [];

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

    // Spell tints + epithet
    global.unlocked_tints = [];
    global.school_tints   = {};
    global.player_epithet = "";

    // Ability mastery
    global.ability_casts   = {};
    global.ability_mastery = {};

    // Run modifiers
    global.run_boons  = [];
    global.run_curses = [];
    global.run_borrowed_ability = "";   // Borrowed Memory (run-scoped)
    global.run_borrowed_class   = "";
    global.gold_potion_bosses = 0;   // exotic find-buff potions never carry across a load
    global.loot_potion_bosses = 0;

    // Onboarding (per-slot)
    global.tutorial_seen = {};

    // Dungeon ascendance progression
    global.dungeon_ascendance_unlocked = { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 };
    global.dungeon_clears              = { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 };
    global.dungeon_clears_total        = 0;
    global.dungeon_a5_clears           = { ashen_vault: false, scorched_depths: false, tundra_tomb: false };
    global.ironwake_stands             = false;
    global.ending_pending              = false;
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

    // --- Save-format versioning / migrations ---
    // Pre-stamp saves read as v0; every guarded read below already tolerates them.
    // When SAVE_FORMAT_VERSION bumps past 1, put the per-version fix-ups here
    // (if (_save_ver < 2) { ... } etc.) so old slots upgrade in one place.
    var _save_ver = variable_struct_exists(_s, "save_version") ? _s.save_version : 0;
    // v2 migration: pre-v2 weapons carry the old fixed flat damage - re-roll them
    // once into the rarity ranges (M 2026-07-08: migrate + re-roll all).
    var _reroll_weapons = (_save_ver < 2);
    if (_save_ver > SAVE_FORMAT_VERSION) {
        // Newer save than this build understands (e.g. a rolled-back patch).
        // The tolerant loads below still read every field they know; log it so
        // player bug reports carry the mismatch.
        show_debug_message("load_game: slot save v" + string(_save_ver)
            + " newer than game save format v" + string(SAVE_FORMAT_VERSION));
    }

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
        // v2: "Lucky Find" was renamed "Blessed Thirst" (a new, different Lucky
        // Find exists now). Pre-v2 saves that had it EQUIPPED carry the old
        // display name - swap it so the no-consume effect keeps working.
        if (_save_ver < 2) {
            for (var _ti = 0; _ti < array_length(global.player_traits); _ti++) {
                if (global.player_traits[_ti] == "Lucky Find") global.player_traits[_ti] = "Blessed Thirst";
            }
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

    // Lifetime-kills backfill: total_kills was never incremented before 07-09 (the hub
    // stat always showed 0), so old saves carry a 0. Recover it from the per-run kill
    // counts already stored in run history. Only fires on affected saves; a save
    // written after the fix has a nonzero (and more complete) live count.
    if (global.total_kills == 0 && is_array(global.run_history)) {
        var _tk_sum = 0;
        for (var _tk = 0; _tk < array_length(global.run_history); _tk++) {
            var _tk_r = global.run_history[_tk];
            if (is_struct(_tk_r) && variable_struct_exists(_tk_r, "kills")) _tk_sum += _tk_r.kills;
        }
        global.total_kills = _tk_sum;
    }

    // Equipped items. global.inventory is pre-sized to EQUIP_SLOT_COUNT (10): index 8 =
    // Ranged Weapon, 9 = Ring 2. Older saves have fewer entries - the extra positions
    // stay undefined (empty), so the migration is automatic and lossless (the same
    // pattern that added the ranged slot; SYSTEMS_WEAPON_ROLES.md §A).
    global.inventory = array_create(EQUIP_SLOT_COUNT, undefined);   // ensure full width pre-copy
    if (variable_struct_exists(_s, "inventory") && is_array(_s.inventory)) {
        for (var _ii = 0; _ii < min(EQUIP_SLOT_COUNT, array_length(_s.inventory)); _ii++) {
            global.inventory[_ii] = _s.inventory[_ii];
            item_migrate_weapon_fields(global.inventory[_ii], _reroll_weapons);   // backfill weapon_damage/two_handed (+v2 range re-roll)
            item_merge_dup_affixes(global.inventory[_ii]);   // pre-fix saves: "+2 INT +1 INT" -> "+3 INT"
        }
    }

    // Hub-safe stash storage
    if (variable_struct_exists(_s, "equipment_stash") && is_array(_s.equipment_stash)) {
        global.equipment_stash = _s.equipment_stash;
        for (var _esi = 0; _esi < array_length(global.equipment_stash); _esi++) {
            item_migrate_weapon_fields(global.equipment_stash[_esi], _reroll_weapons);
            item_merge_dup_affixes(global.equipment_stash[_esi]);   // pre-fix saves: merge stacked same-stat rows
        }
    }
    if (variable_struct_exists(_s, "consumable_stash") && is_array(_s.consumable_stash)) {
        global.consumable_stash = _s.consumable_stash;
    }

    // NPC affinity (thin track). Restore the saved relationships; affinity_ensure()
    // backfills any missing NPC keys/fields so older saves load cleanly.
    if (variable_struct_exists(_s, "npc_affinity") && is_struct(_s.npc_affinity)) {
        global.npc_affinity = _s.npc_affinity;
    }
    affinity_ensure();

    // Phase 4a: quests / journal (older saves lack these keys -> seeded/empty defaults).
    global.quests         = (variable_struct_exists(_s, "quests")         && is_array(_s.quests))          ? _s.quests         : [];
    global.journal_badges = (variable_struct_exists(_s, "journal_badges") && is_struct(_s.journal_badges)) ? _s.journal_badges : { npcs: {}, quests: {} };
    global.npc_ledger     = (variable_struct_exists(_s, "npc_ledger")     && is_struct(_s.npc_ledger))     ? _s.npc_ledger     : {};
    quest_state_ensure();   // append-migrate rows for quests added since this save
    // Tavern board requests (older saves lack these keys -> empty; board_bootstrap()
    // stocks the board the first time it is opened).
    global.board_requests = (variable_struct_exists(_s, "board_requests") && is_array(_s.board_requests)) ? _s.board_requests : [];
    global.board_seq      = (variable_struct_exists(_s, "board_seq"))     ? _s.board_seq     : 0;
    global.reforge_chits  = (variable_struct_exists(_s, "reforge_chits")) ? _s.reforge_chits : 0;
    // Board v2 (older saves -> fresh 5-run cadence); the reroll ladder always loads reset.
    global.board_special_countdown = (variable_struct_exists(_s, "board_special_countdown")) ? _s.board_special_countdown : 5;
    global.board_rerolls_used      = 0;
    // Dice v2: High Table cadence (older saves -> fresh 5-run clock, no invitation).
    global.kb_tourney_countdown = (variable_struct_exists(_s, "kb_tourney_countdown")) ? _s.kb_tourney_countdown : 5;
    global.kb_tourney_ready     = (variable_struct_exists(_s, "kb_tourney_ready"))     ? _s.kb_tourney_ready     : false;
    // Phase 4b: gifts (older saves -> empty defaults). run_trinkets is run-scoped: empty.
    global.gift_trinkets    = (variable_struct_exists(_s, "gift_trinkets")    && is_array(_s.gift_trinkets))     ? _s.gift_trinkets    : [];
    global.npc_tastes_known = (variable_struct_exists(_s, "npc_tastes_known") && is_struct(_s.npc_tastes_known)) ? _s.npc_tastes_known : {};
    global.gift_given       = (variable_struct_exists(_s, "gift_given"))                                          ? _s.gift_given       : false;
    global.run_trinkets     = [];

    // Petra Treasure Trader order (cross-run persistent). Absent/!struct -> no order.
    global.petra_order = (variable_struct_exists(_s, "petra_order") && is_struct(_s.petra_order))
        ? _s.petra_order : undefined;

    // Pets (cross-run persistent). Older saves lack these keys -> empty roster.
    global.pet_roster  = (variable_struct_exists(_s, "pet_roster")  && is_array(_s.pet_roster))  ? _s.pet_roster  : [];
    global.active_pet  = (variable_struct_exists(_s, "active_pet"))  ? _s.active_pet  : -1;
    global.pet_next_id = (variable_struct_exists(_s, "pet_next_id")) ? _s.pet_next_id : (array_length(global.pet_roster) + 1);
    global.pet_starter_given = (variable_struct_exists(_s, "pet_starter_given")) ? _s.pet_starter_given : false;
    global.pet_feed_pouch    = (variable_struct_exists(_s, "pet_feed_pouch") && is_struct(_s.pet_feed_pouch)) ? _s.pet_feed_pouch : {};
    // Bond-axis extras (older saves lack these keys -> empty defaults).
    global.pet_pref_discovered = (variable_struct_exists(_s, "pet_pref_discovered") && is_struct(_s.pet_pref_discovered)) ? _s.pet_pref_discovered : {};
    global.bairc_donated       = (variable_struct_exists(_s, "bairc_donated")    && is_array(_s.bairc_donated))    ? _s.bairc_donated    : [];
    global.bairc_lore_seen     = (variable_struct_exists(_s, "bairc_lore_seen")  && is_struct(_s.bairc_lore_seen)) ? _s.bairc_lore_seen  : {};
    global.bairc_lore_queue    = (variable_struct_exists(_s, "bairc_lore_queue") && is_array(_s.bairc_lore_queue)) ? _s.bairc_lore_queue : [];
    pet_migrate_retired_species();   // re-skin any retired humanoid-species pets to a real creature
    // Carried consumable pack (run buffer) - restore so withdrawn/carried-forward
    // potions survive a reload. Older saves lack this key; the gc-Create default ([])
    // covers them.
    if (variable_struct_exists(_s, "consumable_inventory") && is_array(_s.consumable_inventory)) {
        global.consumable_inventory = _s.consumable_inventory;
    }

    // Genie Lamp rarity stamp: lamps created before 07-09 lack the legendary rarity
    // field (added so its name golds everywhere). Backfill owned lamps in both
    // consumable pools; new lamps get it at create_consumable. Runs AFTER both pools
    // load (consumable_inventory restores just above).
    var _gl_pools = [global.consumable_stash, global.consumable_inventory];
    for (var _gp = 0; _gp < array_length(_gl_pools); _gp++) {
        var _gl_pool = _gl_pools[_gp];
        if (!is_array(_gl_pool)) continue;
        for (var _gi = 0; _gi < array_length(_gl_pool); _gi++) {
            var _gc2 = _gl_pool[_gi];
            if (is_struct(_gc2) && variable_struct_exists(_gc2, "name") && _gc2.name == "Genie Lamp"
                && !variable_struct_exists(_gc2, "rarity")) {
                _gc2.rarity = 4;
            }
        }
    }

    // Shop stock (per-slot). Restore this character's Dorn/Petra stock. Saves
    // written before shop persistence lack these keys; new_game_reset() leaves
    // dorn_stock empty in that case and the hub seeds a fresh shop on entry.
    if (variable_struct_exists(_s, "dorn_stock") && is_array(_s.dorn_stock)) {
        global.dorn_stock = _s.dorn_stock;
        for (var _dsi = 0; _dsi < array_length(global.dorn_stock); _dsi++) {
            var _de = global.dorn_stock[_dsi];
            if (is_struct(_de) && variable_struct_exists(_de, "item")) {
                item_migrate_weapon_fields(_de.item, _reroll_weapons);   // backfill weapon_damage/two_handed on shop gear (+v2 range re-roll)
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
    if (variable_struct_exists(_s, "unlocked_tints") && is_array(_s.unlocked_tints)) {
        global.unlocked_tints = _s.unlocked_tints;
    }
    if (variable_struct_exists(_s, "school_tints") && is_struct(_s.school_tints)) {
        global.school_tints = _s.school_tints;
    }
    if (variable_struct_exists(_s, "player_epithet")) global.player_epithet = _s.player_epithet;
    if (variable_struct_exists(_s, "ability_casts") && is_struct(_s.ability_casts)) {
        global.ability_casts = _s.ability_casts;
    }
    if (variable_struct_exists(_s, "ability_mastery") && is_struct(_s.ability_mastery)) {
        global.ability_mastery = _s.ability_mastery;
    }
    // Boons and curses are run-scoped (cleared in end_run). A save can only hold
    // non-empty values if it was written mid-run (boon_grant/curse_grant save on
    // pickup); since loading always lands in the hub between runs, restoring them
    // would carry stale modifiers into the next run. Always start a loaded game with
    // none - this is the fresh-run reset the abandoned-run case needs.
    global.run_boons  = [];
    global.run_curses = [];
    global.run_borrowed_ability = "";   // Borrowed Memory: run-scoped, same reasoning
    global.run_borrowed_class   = "";
    global.gold_potion_bosses = 0;   // exotic find-buff potions never carry across a load
    global.loot_potion_bosses = 0;
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

    // Win state (WIN_STATE_SPEC.md) - pre-ending saves default to all-false
    if (variable_struct_exists(_s, "dungeon_a5_clears") && is_struct(_s.dungeon_a5_clears)) {
        if (!variable_global_exists("dungeon_a5_clears")) {
            global.dungeon_a5_clears = { ashen_vault: false, scorched_depths: false, tundra_tomb: false };
        }
        var _wkeys = ["ashen_vault", "scorched_depths", "tundra_tomb"];
        for (var _wi = 0; _wi < array_length(_wkeys); _wi++) {
            if (variable_struct_exists(_s.dungeon_a5_clears, _wkeys[_wi])) {
                variable_struct_set(global.dungeon_a5_clears, _wkeys[_wi],
                    variable_struct_get(_s.dungeon_a5_clears, _wkeys[_wi]));
            }
        }
    }
    if (variable_struct_exists(_s, "ironwake_stands")) global.ironwake_stands = _s.ironwake_stands;
    if (variable_struct_exists(_s, "ending_pending"))  global.ending_pending  = _s.ending_pending;

    // New progression counters
    if (variable_struct_exists(_s, "dungeon_clears_total"))    global.dungeon_clears_total    = _s.dungeon_clears_total;
    if (variable_struct_exists(_s, "total_boss_kills"))        global.total_boss_kills        = _s.total_boss_kills;
    if (variable_struct_exists(_s, "highest_run_level"))       global.highest_run_level       = _s.highest_run_level;
    if (variable_struct_exists(_s, "perm_hp_battle_hardened")) global.perm_hp_battle_hardened = _s.perm_hp_battle_hardened;
    if (variable_struct_exists(_s, "chosen_portrait"))         global.chosen_portrait         = _s.chosen_portrait;
}
