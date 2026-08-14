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
#macro SAVE_FORMAT_VERSION 4
// v2 (2026-07-08): weapon flat damage became a per-item RANGE roll (was fixed per
// rarity) and caster ranged weapons gained a rolled wpn_school. Loading a v1 save
// re-rolls every non-hand-tuned weapon once (item_migrate_weapon_fields force flag).
// v4 (2026-07-27): mastery notches became TALENT WEBS (SYSTEMS_TALENT_WEBS.md).
// ability_casts carries over unchanged; the old ability_mastery picks are DROPPED
// on load (not read), so every MP earned from casts returns as pending - old
// slots re-pick their webs, a strict buff. New field: ability_web { name: [ids] }.

// ---------------------------------------------------------------------------
// get_slot_preview(slot_num)
// Reads a save slot file and returns a lightweight preview struct, or
// undefined if the slot is empty. Does NOT touch any global state.
// ---------------------------------------------------------------------------
function get_slot_preview(slot_num) {
    var _fname = "ironwake_save_" + string(slot_num) + ".json";
    // THE IRON VOW: a fallen character's slot shows a memorial gravestone
    // instead of reading empty (SYSTEMS_IRON_VOW.md). Not loadable - see
    // slot_preview_loadable.
    if (!file_exists(_fname)) return vow_memorial_read(slot_num);
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
        memorial:             false,
        vow_mode:             variable_struct_exists(_s, "vow_mode")             ? _s.vow_mode             : 0,
        vow_lives_left:       variable_struct_exists(_s, "vow_lives_left")       ? _s.vow_lives_left       : 0,
    };
}

// ---------------------------------------------------------------------------
// slot_preview_loadable(p)
// True when a slot preview is a LIVING character. Memorial gravestones occupy
// the card visually but can never be loaded (and don't enable the Load menu).
// ---------------------------------------------------------------------------
function slot_preview_loadable(_p) {
    if (_p == undefined) return false;
    if (variable_struct_exists(_p, "memorial") && _p.memorial) return false;
    return true;
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
        vex_stat_buys:      variable_global_exists("vex_stat_buys")      ? global.vex_stat_buys      : 0,

        // Item codex (discovered item names + best rarity seen per base, 07-29)
        items_discovered: global.items_discovered,
        items_discovered_best: (variable_global_exists("items_discovered_best") && is_struct(global.items_discovered_best))
            ? global.items_discovered_best : {},

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
        ability_casts:   variable_global_exists("ability_casts") ? global.ability_casts : {},
        ability_web:     variable_global_exists("ability_web")   ? global.ability_web   : {},
        // Class trunks (P2, 08-05): 3 classes x 5 rows, -1/0/1. Optional field -
        // stale saves read as "nothing picked", no format bump.
        trunk_picks:     variable_global_exists("trunk_picks")   ? global.trunk_picks   : [[-1,-1,-1,-1,-1],[-1,-1,-1,-1,-1],[-1,-1,-1,-1,-1]],

        // Boons (run-scoped)
        run_boons:      variable_global_exists("run_boons")      ? global.run_boons      : [],
        run_curses:     variable_global_exists("run_curses")     ? global.run_curses     : [],

        // RPG origin (08-11) + the Debtor's ledger + per-run grant flag
        origin_id:          variable_global_exists("origin_id")          ? global.origin_id          : "",
        origin_run_granted: variable_global_exists("origin_run_granted") ? global.origin_run_granted : false,
        debt_gold:          variable_global_exists("debt_gold")          ? global.debt_gold          : 0,
        debt_missed:        variable_global_exists("debt_missed")        ? global.debt_missed        : 0,

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
        reforge_ingots:  (variable_global_exists("reforge_ingots") && is_array(global.reforge_ingots)) ? global.reforge_ingots : [0, 0, 0, 0, 0],
        // Pattern Book (08-11): blueprint studies + unlocked art page.
        pattern_book:    (variable_global_exists("pattern_book") && is_struct(global.pattern_book)) ? global.pattern_book : undefined,
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
        // Garden memorial stones (08-01): pets lost to the injury ladder.
        bairc_memorials: (variable_global_exists("bairc_memorials") && is_array(global.bairc_memorials))  ? global.bairc_memorials : [],
        bairc_lore_seen: (variable_global_exists("bairc_lore_seen") && is_struct(global.bairc_lore_seen)) ? global.bairc_lore_seen : {},
        // Boss-signature once-per-save ledger (07-31): species id -> true once found.
        pet_sig_history: (variable_global_exists("pet_sig_history") && is_struct(global.pet_sig_history)) ? global.pet_sig_history : {},
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
        // The Bottom (Descent floor 50) cleared - drives the epithet + splash
        // (set in combat_on_enemy_defeated; was write-only until 08-14).
        descent_bottom_cleared:      variable_global_exists("descent_bottom_cleared")      ? global.descent_bottom_cleared      : false,
        ironwake_stands:             variable_global_exists("ironwake_stands")             ? global.ironwake_stands             : false,
        ending_pending:              variable_global_exists("ending_pending")              ? global.ending_pending              : false,
        // Awakening Boost popup (SYSTEMS_ENDLESS.md §1) - earned but unspent picks survive a quit.
        awaken_boost_pending:        variable_global_exists("awaken_boost_pending")        ? global.awaken_boost_pending        : false,
        awaken_boost_from:           variable_global_exists("awaken_boost_from")           ? global.awaken_boost_from           : "",
        // A6+ endless frontier (SYSTEMS_ENDLESS.md §2) - shared across dungeons post-win.
        endless_awakening_unlocked:  variable_global_exists("endless_awakening_unlocked")  ? global.endless_awakening_unlocked  : 5,
        // THE DESCENT (SYSTEMS_ENDLESS.md §3): deepest-floor record + severity preference.
        descent_best:                variable_global_exists("descent_best")                ? global.descent_best                : 0,
        descent_hardcore:            variable_global_exists("descent_hardcore")            ? global.descent_hardcore            : 0,
        // THE LEGENDARY FORGE (M locked 07-28): vendor component counts.
        forge_comp_frame:            variable_global_exists("forge_comp_frame")            ? global.forge_comp_frame            : 0,
        forge_comp_core:             variable_global_exists("forge_comp_core")             ? global.forge_comp_core             : 0,
        forge_comp_quint:            variable_global_exists("forge_comp_quint")            ? global.forge_comp_quint            : 0,
        // NPC PROGRESSION ranks (M-locked 08-15) - struct id -> 0..2.
        npc_ranks:                   (variable_global_exists("npc_ranks") && is_struct(global.npc_ranks)) ? global.npc_ranks : {},
        // THE IRON VOW (SYSTEMS_IRON_VOW.md): opt-in hardcore mode + lives left.
        vow_mode:                    variable_global_exists("vow_mode")                    ? global.vow_mode                    : 0,
        vow_lives_left:              variable_global_exists("vow_lives_left")              ? global.vow_lives_left              : 0,
        total_boss_kills:            variable_global_exists("total_boss_kills")            ? global.total_boss_kills            : 0,
        // The Ashen Duelist (DESIGN_DUELIST_CHALLENGE.md): lifetime rival ledger.
        duelist_encounters:          variable_global_exists("duelist_encounters")          ? global.duelist_encounters          : 0,
        duelist_tokens:              variable_global_exists("duelist_tokens")              ? global.duelist_tokens              : 0,
        duelist_wins:                variable_global_exists("duelist_wins")                ? global.duelist_wins                : 0,
        // Understudy ledger (mimicling sig move, 08-06): last/previous active species.
        pet_last_species:            variable_global_exists("pet_last_species")            ? global.pet_last_species            : "",
        pet_prev_species:            variable_global_exists("pet_prev_species")            ? global.pet_prev_species            : "",
        // STEAM ACHIEVEMENTS lifetime counters (08-04) - optional struct, healed
        // by ach_counters_init() on older saves. No SAVE_FORMAT_VERSION bump.
        ach_counters:                variable_global_exists("ach_counters")                ? global.ach_counters                : undefined,
        highest_run_level:           variable_global_exists("highest_run_level")           ? global.highest_run_level           : 1,
        perm_hp_battle_hardened:     variable_global_exists("perm_hp_battle_hardened")     ? global.perm_hp_battle_hardened     : 0,
        chosen_portrait:             variable_global_exists("chosen_portrait")             ? global.chosen_portrait             : 0,
        chosen_class:                variable_global_exists("chosen_class")                ? global.chosen_class                : 0,
        chosen_stats:                variable_global_exists("chosen_stats")                ? global.chosen_stats                : undefined,

        // Banshee in a Bottle + music jukebox (v3, BANSHEE_BOTTLE_SPEC.md).
        // banked = stash-side bottles awaiting Maren; carried is run-scoped and
        // intentionally NOT saved (same reasoning as carried_items above).
        banshee_banked:     variable_global_exists("banshee_banked")     ? global.banshee_banked     : 0,
        banshee_boss_drops: (variable_global_exists("banshee_boss_drops") && is_struct(global.banshee_boss_drops)) ? global.banshee_boss_drops : {},
        music_unlocked:     (variable_global_exists("music_unlocked")     && is_array(global.music_unlocked))      ? global.music_unlocked     : [],
        music_sel_hub:      variable_global_exists("music_sel_hub")      ? global.music_sel_hub      : "",
        music_sel_dungeon:  variable_global_exists("music_sel_dungeon")  ? global.music_sel_dungeon  : "",
    };

    save_write_atomic("ironwake_save_" + string(global.save_slot) + ".json", json_stringify(_save));
}

// ---------------------------------------------------------------------------
// save_write_atomic(fname, json)
// ATOMIC WRITE (task #2, approved 07-23): write to a temp file first, verify
// it parses back, then swap it in. A crash/kill mid-write can no longer
// truncate the real file - the worst case is a stale-but-valid file. Shared
// by save_game and the IRONMAN run-resume checkpoint (SYSTEMS_RUN_RESUME.md).
// ---------------------------------------------------------------------------
function save_write_atomic(_fname, _json) {
    var _tmp = _fname + ".tmp";
    var _file = file_text_open_write(_tmp);
    file_text_write_string(_file, _json);
    file_text_close(_file);
    // Verify the temp round-trips before touching the real file. json_stringify
    // emits a single line, so one read covers the whole payload.
    var _ok = false;
    if (file_exists(_tmp)) {
        var _vf = file_text_open_read(_tmp);
        var _vtxt = file_text_read_string(_vf);
        file_text_close(_vf);
        try { var _parsed = json_parse(_vtxt); _ok = is_struct(_parsed); } catch (_e) { _ok = false; }
    }
    if (_ok) {
        if (file_exists(_fname)) file_delete(_fname);
        file_rename(_tmp, _fname);
    } else if (file_exists(_tmp)) {
        // Bad write - keep the old file untouched, discard the temp.
        file_delete(_tmp);
    }
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
    // A new character must not inherit a previous session's in-progress run
    // (same leak as load_game - see run_state_reset).
    run_state_reset();

    // Economy (M 08-13: every new game starts with a 100g purse)
    global.gold             = 100;
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
        relentless: false,
    };

    // Vex the Trainer permanent purchases
    global.bonus_trait_slots  = 0;
    global.vex_stat_buys      = 0;
    global.unlocked_abilities = [];
    global.trait_potency      = {};

    // Item codex
    global.items_discovered = [];
    global.items_discovered_best = {};

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
    global.reforge_ingots = [0, 0, 0, 0, 0];
    global.pattern_book   = { fam: {}, art: [] };
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
    global.bairc_memorials     = [];
    global.bairc_lore_seen     = {};
    global.bairc_lore_queue    = [];
    global.pet_sig_history     = {};   // no signature kin found yet (07-31)

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

    // THE IRON VOW - a new character is Standard until the creation Vow step says otherwise.
    global.vow_mode       = 0;
    global.vow_lives_left = 0;

    // Ability mastery
    global.ability_casts = {};
    global.ability_web   = {};
    global.trunk_picks   = [[-1,-1,-1,-1,-1],[-1,-1,-1,-1,-1],[-1,-1,-1,-1,-1]];

    // Run modifiers
    global.run_boons  = [];
    global.run_curses = [];
    global.run_borrowed_ability = "";   // Borrowed Memory (run-scoped)
    global.run_borrowed_class   = "";
    run_honing_clear();                 // Whetstone honing (run-scoped, never persisted)

    // RPG origin (08-11): fresh slot, no background chosen yet, clean ledger.
    global.origin_id          = "";
    global.origin_run_granted = false;
    global.debt_gold          = 0;
    global.debt_missed        = 0;
    // Shrine V2 / duel / web-P3 run-scoped state (07-29): never crosses a reset.
    global.gambler_cd = 0; global.gambler_proc = false;
    global.feast_stacks = 0; global.bloodtithe_bank = 0; global.unbroken_shield = 0;
    global.duel_offered_this_run = false; global.duel_launch = false; global.duel_active = false;
    global.gold_potion_bosses = 0;   // exotic find-buff potions never carry across a load
    global.loot_potion_bosses = 0;

    // Onboarding (per-slot)
    global.tutorial_seen = {};

    // Dungeon ascendance progression
    global.dungeon_ascendance_unlocked = { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 };
    global.dungeon_clears              = { ashen_vault: 0, scorched_depths: 0, tundra_tomb: 0 };
    global.dungeon_clears_total        = 0;
    global.dungeon_a5_clears           = { ashen_vault: false, scorched_depths: false, tundra_tomb: false };
    global.descent_bottom_cleared      = false;
    global.ironwake_stands             = false;
    global.ending_pending              = false;
    global.awaken_boost_pending        = false;
    global.awaken_boost_from           = "";
    global.endless_awakening_unlocked  = 5;
    global.descent_best                = 0;
    global.descent_hardcore            = 0;
    global.descent_active              = false;
    global.descent_pending             = false;
    global.forge_comp_frame            = 0;
    global.forge_comp_core             = 0;
    global.forge_comp_quint            = 0;
    global.npc_ranks                   = {};   // NPC PROGRESSION (08-15)
    global.total_boss_kills            = 0;
    global.duelist_encounters          = 0;   // Ashen Duelist: lifetime duels fought (+10% stats each)
    global.duelist_tokens              = 0;   // Ashen Duelist: gold-tier tokens (Duelist Arts ladder)
    global.duelist_wins                = 0;   // Ashen Duelist: total WINS (Dueling Relics ladder, 08-11)
    global.pet_last_species            = "";  // Understudy ledger: current active species (08-06 wiring)
    global.pet_prev_species            = "";  // Understudy ledger: the one before it (what the mimicling copies)
    global.highest_run_level           = 1;
    global.perm_hp_battle_hardened     = 0;
    global.selected_ascendance         = 0;
    global.selected_dungeon            = "ashen_vault";

    // Character identity - defaulted here, set during character creation
    global.chosen_portrait = 0;
    global.chosen_class    = 0;
    global.chosen_stats    = undefined;

    // Banshee in a Bottle + music jukebox - a new character owns nothing yet.
    global.banshee_carried    = 0;
    global.banshee_banked     = 0;
    global.banshee_boss_drops = {};
    global.music_unlocked     = [];
    global.music_sel_hub      = "";
    global.music_sel_dungeon  = "";
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
    if (variable_struct_exists(_s, "vex_stat_buys"))      global.vex_stat_buys      = _s.vex_stat_buys;
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
    global.items_discovered_best = (variable_struct_exists(_s, "items_discovered_best") && is_struct(_s.items_discovered_best))
        ? _s.items_discovered_best : {};

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

    // Veil of the Patient Dark offhand -> helm reslot (07-30): fix the stale
    // slot on saved copies, stash the Veil if it now collides with a worn helm.
    veil_slot_fixup();

    // CODEX PASS round 2 (07-29): pre-pass saves only stored discovered NAMES,
    // so epics found before the ledger existed show at rare tint. Rebuild what
    // we can from items the player still owns (worn + stash just restored).
    codex_backfill_owned();

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
    global.reforge_ingots = (variable_struct_exists(_s, "reforge_ingots") && is_array(_s.reforge_ingots) && array_length(_s.reforge_ingots) == 5) ? _s.reforge_ingots : [0, 0, 0, 0, 0];
    // Pattern Book (08-11): older saves -> empty book; pattern_book_ensure()
    // repairs any missing sub-field on first touch.
    global.pattern_book = (variable_struct_exists(_s, "pattern_book") && is_struct(_s.pattern_book)) ? _s.pattern_book : { fam: {}, art: [] };
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
    // Explicit either-way assignment (slot-leak rule, cf. pet_sig_history).
    global.bairc_memorials     = (variable_struct_exists(_s, "bairc_memorials")  && is_array(_s.bairc_memorials))  ? _s.bairc_memorials  : [];
    global.bairc_lore_seen     = (variable_struct_exists(_s, "bairc_lore_seen")  && is_struct(_s.bairc_lore_seen)) ? _s.bairc_lore_seen  : {};
    global.bairc_lore_queue    = (variable_struct_exists(_s, "bairc_lore_queue") && is_array(_s.bairc_lore_queue)) ? _s.bairc_lore_queue : [];
    // Boss-signature once-per-save ledger (07-31). Explicit assignment either way
    // so slot-switching in one session can never leak another save's ledger.
    // Older saves lack the key: seed it here from what the save already owns
    // (roster + Bairc's garden, both loaded just above).
    if (variable_struct_exists(_s, "pet_sig_history") && is_struct(_s.pet_sig_history)) {
        global.pet_sig_history = _s.pet_sig_history;
    } else {
        global.pet_sig_history = {};
        var _sh_seed = array_concat(global.pet_roster, global.bairc_donated);
        var _sh_cat  = pet_species_signature_catalog();
        for (var _shi = 0; _shi < array_length(_sh_seed); _shi++) {
            if (!is_struct(_sh_seed[_shi]) || !variable_struct_exists(_sh_seed[_shi], "species")) continue;
            for (var _shj = 0; _shj < array_length(_sh_cat); _shj++)
                if (_sh_cat[_shj].id == _sh_seed[_shi].species) global.pet_sig_history[$ _sh_seed[_shi].species] = true;
        }
    }
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

    // Banshee in a Bottle + music jukebox (v3). Pre-v3 saves lack every key ->
    // fresh defaults (nothing owned, default music). Selections re-validate
    // against ownership in music_selected_track, so a hand-edited save can't
    // point at a locked track.
    global.banshee_carried    = 0;   // run-scoped: never persists across a load
    global.banshee_banked     = (variable_struct_exists(_s, "banshee_banked")) ? max(0, _s.banshee_banked) : 0;
    global.banshee_boss_drops = (variable_struct_exists(_s, "banshee_boss_drops") && is_struct(_s.banshee_boss_drops)) ? _s.banshee_boss_drops : {};
    global.music_unlocked     = (variable_struct_exists(_s, "music_unlocked") && is_array(_s.music_unlocked)) ? _s.music_unlocked : [];
    global.music_sel_hub      = (variable_struct_exists(_s, "music_sel_hub"))     ? _s.music_sel_hub     : "";
    global.music_sel_dungeon  = (variable_struct_exists(_s, "music_sel_dungeon")) ? _s.music_sel_dungeon : "";

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
    // v4 talent webs: pre-v4 saves carry "ability_mastery" instead - deliberately
    // NOT read (old picks drop; MP recomputes from casts and returns as pending,
    // so old slots re-pick their webs). ability_web resets to empty either way
    // so a v4 load never inherits a previous session's picks.
    global.ability_web = {};
    if (variable_struct_exists(_s, "ability_web") && is_struct(_s.ability_web)) {
        global.ability_web = _s.ability_web;
    }
    // Class trunks (P2, 08-05): reset-then-read so a load never inherits a
    // previous session's picks; trunk_picks_init() heals any malformed shape.
    global.trunk_picks = [[-1,-1,-1,-1,-1],[-1,-1,-1,-1,-1],[-1,-1,-1,-1,-1]];
    if (variable_struct_exists(_s, "trunk_picks") && is_array(_s.trunk_picks)) {
        global.trunk_picks = _s.trunk_picks;
        trunk_picks_init();
    }
    // 07-16: "Crippling Shot" was renamed "Frost Shot" (combo batch - it gained the
    // Chill rider and the frost identity). Sweep every name-keyed store so old saves
    // keep the ability equipped/unlocked/mastered. Idempotent - no version gate
    // needed (same pattern as the Lucky Find -> Blessed Thirst trait rename).
    if (variable_global_exists("player_loadout") && is_array(global.player_loadout)) {
        for (var _fsi = 0; _fsi < array_length(global.player_loadout); _fsi++) {
            if (global.player_loadout[_fsi] == "Crippling Shot") global.player_loadout[_fsi] = "Frost Shot";
        }
    }
    if (variable_global_exists("unlocked_abilities") && is_array(global.unlocked_abilities)) {
        for (var _fsj = 0; _fsj < array_length(global.unlocked_abilities); _fsj++) {
            if (global.unlocked_abilities[_fsj] == "Crippling Shot") global.unlocked_abilities[_fsj] = "Frost Shot";
        }
    }
    if (variable_global_exists("ability_casts") && is_struct(global.ability_casts)
        && variable_struct_exists(global.ability_casts, "Crippling Shot")) {
        variable_struct_set(global.ability_casts, "Frost Shot", variable_struct_get(global.ability_casts, "Crippling Shot"));
        variable_struct_remove(global.ability_casts, "Crippling Shot");
    }
    if (variable_global_exists("ability_web") && is_struct(global.ability_web)
        && variable_struct_exists(global.ability_web, "Crippling Shot")) {
        variable_struct_set(global.ability_web, "Frost Shot", variable_struct_get(global.ability_web, "Crippling Shot"));
        variable_struct_remove(global.ability_web, "Crippling Shot");
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
    run_honing_clear();                 // Whetstone honing: run-scoped, same reasoning

    // RPG origin (08-11): meta-persistent per slot. Loading lands in the hub
    // between runs, so the per-run grant flag re-arms (matches the boon reset
    // reasoning above); the Debtor's ledger is meta and loads as saved.
    global.origin_id          = variable_struct_exists(_s, "origin_id")   ? _s.origin_id   : "";
    global.origin_run_granted = false;
    global.debt_gold          = variable_struct_exists(_s, "debt_gold")   ? _s.debt_gold   : 0;
    global.debt_missed        = variable_struct_exists(_s, "debt_missed") ? _s.debt_missed : 0;
    // Shrine V2 / duel / web-P3 run-scoped state (07-29): same reasoning.
    global.gambler_cd = 0; global.gambler_proc = false;
    global.feast_stacks = 0; global.bloodtithe_bank = 0; global.unbroken_shield = 0;
    global.duel_offered_this_run = false; global.duel_launch = false; global.duel_active = false;
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
    global.descent_bottom_cleared = variable_struct_exists(_s, "descent_bottom_cleared") ? _s.descent_bottom_cleared : false;
    if (variable_struct_exists(_s, "ending_pending"))  global.ending_pending  = _s.ending_pending;
    global.awaken_boost_pending = variable_struct_exists(_s, "awaken_boost_pending") ? _s.awaken_boost_pending : false;
    global.awaken_boost_from    = variable_struct_exists(_s, "awaken_boost_from")    ? _s.awaken_boost_from    : "";
    global.endless_awakening_unlocked = variable_struct_exists(_s, "endless_awakening_unlocked") ? _s.endless_awakening_unlocked : 5;
    global.descent_best     = variable_struct_exists(_s, "descent_best")     ? _s.descent_best     : 0;
    global.descent_hardcore = variable_struct_exists(_s, "descent_hardcore") ? _s.descent_hardcore : 0;
    global.descent_active   = false;   // runs never persist - a loaded save is always in the hub
    global.descent_pending  = false;
    // THE LEGENDARY FORGE components (M locked 07-28) - additive, default 0.
    global.forge_comp_frame = variable_struct_exists(_s, "forge_comp_frame") ? _s.forge_comp_frame : 0;
    global.forge_comp_core  = variable_struct_exists(_s, "forge_comp_core")  ? _s.forge_comp_core  : 0;
    global.forge_comp_quint = variable_struct_exists(_s, "forge_comp_quint") ? _s.forge_comp_quint : 0;
    global.npc_ranks        = (variable_struct_exists(_s, "npc_ranks") && is_struct(_s.npc_ranks)) ? _s.npc_ranks : {};
    // THE IRON VOW (SYSTEMS_IRON_VOW.md) - pre-Vow saves are Standard.
    global.vow_mode       = variable_struct_exists(_s, "vow_mode")       ? _s.vow_mode       : 0;
    global.vow_lives_left = variable_struct_exists(_s, "vow_lives_left") ? _s.vow_lives_left : 0;

    // New progression counters
    if (variable_struct_exists(_s, "dungeon_clears_total"))    global.dungeon_clears_total    = _s.dungeon_clears_total;
    if (variable_struct_exists(_s, "total_boss_kills"))        global.total_boss_kills        = _s.total_boss_kills;
    if (variable_struct_exists(_s, "duelist_encounters"))      global.duelist_encounters      = _s.duelist_encounters;
    if (variable_struct_exists(_s, "duelist_tokens"))          global.duelist_tokens          = _s.duelist_tokens;
    if (variable_struct_exists(_s, "duelist_wins"))            global.duelist_wins            = _s.duelist_wins;
    if (variable_struct_exists(_s, "pet_last_species"))        global.pet_last_species        = _s.pet_last_species;
    if (variable_struct_exists(_s, "pet_prev_species"))        global.pet_prev_species        = _s.pet_prev_species;
    if (variable_struct_exists(_s, "ach_counters") && is_struct(_s.ach_counters)) global.ach_counters = _s.ach_counters;
    ach_counters_init();   // heal missing fields on older saves (achievements, 08-04)
    if (variable_struct_exists(_s, "highest_run_level"))       global.highest_run_level       = _s.highest_run_level;
    if (variable_struct_exists(_s, "perm_hp_battle_hardened")) global.perm_hp_battle_hardened = _s.perm_hp_battle_hardened;
    if (variable_struct_exists(_s, "chosen_portrait"))         global.chosen_portrait         = _s.chosen_portrait;

    // A loaded slot must NEVER inherit another session's in-progress run (07-14
    // report: quit-to-title mid-run leaked run state on the persistent gc; Enter
    // Dungeon then skipped loadout and resumed the old session's floor).
    run_state_reset();

    // IRONMAN RUN-RESUME (SYSTEMS_RUN_RESUME.md): an interrupted run FORCE-
    // resumes - the hub Step gates everything behind the RESUME popup while
    // resume_pending is set, then run_checkpoint_apply consumes the file.
    // A corrupt/stale checkpoint is forfeited (deleted + hub notice), never an
    // escape hatch and never a softlock.
    global.resume_pending = false;
    global.resume_data    = undefined;
    var _ck = run_checkpoint_peek();
    if (_ck != undefined) {
        if (_ck.ok) {
            global.resume_pending = true;
            global.resume_data    = _ck.data;
        } else {
            run_checkpoint_delete();
            var _ck_msg = "Your interrupted dive could not be recovered - the run is forfeit.";
            if (variable_global_exists("pet_find_notice") && global.pet_find_notice != "") {
                global.pet_find_notice += "   " + _ck_msg;
            } else {
                global.pet_find_notice = _ck_msg;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// run_state_reset()
// Clears every run-scoped piece of state to fresh-run defaults. Runs are
// hub-gated and never saved mid-run, so ANY entry into a character context
// (load_game, new_game_reset, quit-to-title) must call this - otherwise the
// persistent obj_game_controller carries the previous session's run across
// slots (loadout_confirmed alone is enough to skip straight onto a floor).
// Mirrors the tail of the end-of-run cleanup in scr_stats.
// ---------------------------------------------------------------------------
function run_state_reset() {
    if (instance_exists(obj_game_controller)) {
        instance_find(obj_game_controller, 0).loadout_confirmed = false;
    }
    global.run_seed             = irandom(99999) + 1;
    global.floor_map_floor      = -1;   // force floor 1 regen on the next run
    global.events_seen_this_run = [];
    global.just_cleared_boss    = false;
    global.just_cleared_room    = false;
    global.current_room_index   = 0;
    global.run_xp               = 0;
    global.run_level            = 1;
    global.pending_stat_points  = 0;
    global.run_stat_bonuses     = { STR: 0, DEX: 0, CON: 0, INT: 0, WIS: 0, CHA: 0 };
    global.run_trinkets         = [];
    global.banshee_carried      = 0;   // run-scoped bottles never survive a run teardown
    run_honing_clear();                 // Whetstone honing is run-scoped - never survives a run teardown
    // POTENCY V2 run-scoped state (Second Wind / Fortune's Favor / Overflow).
    global.second_wind_used     = false;
    global.run_bonus_max_hp     = 0;
    global.fortune_favor_used   = false;
    global.blood_carry          = 0;
    global.gravewalker_used     = false;   // Gravewalker Treads (07-28 legendary), once per run
    global.oathbreaker_hp       = 0;       // Oathbreaker's Shard (07-28 legendary), run max-HP counter
    // THE DESCENT is run-scoped - a fresh run never starts mid-fall.
    global.descent_active       = false;
    global.descent_floor        = 0;
    // IRONMAN resume: a torn-down run has no pending extract choice. The
    // checkpoint FILE is deliberately NOT deleted here - load_game calls this
    // before peeking at the file, and quit-to-title calls it after writing one.
    global.run_extract_pending  = false;
}

// =============================================================================
// IRONMAN RUN-RESUME CHECKPOINT (SYSTEMS_RUN_RESUME.md, M-locked 07-18/07-28)
// A per-slot file holding the run-scoped state so an INTERRUPTED run continues
// instead of being lost. Ironman rules: consumed the moment it is applied,
// force-resumed (no abandon), deleted the frame a defeat lands, and mirrors
// live combat HP so a rage-quit can never reset a losing fight in the player's
// favor. Persistent state stays in the main save; floor maps regenerate
// deterministically from run_seed and are never serialized.
// =============================================================================
#macro RESUME_FORMAT_VERSION 1

function run_checkpoint_file() {
    return "ironwake_resume_" + string(global.save_slot) + ".json";
}

function run_checkpoint_delete() {
    if (!variable_global_exists("save_slot") || global.save_slot < 0) return;
    var _f = run_checkpoint_file();
    if (file_exists(_f)) file_delete(_f);
    if (file_exists(_f + ".tmp")) file_delete(_f + ".tmp");
}

// ---------------------------------------------------------------------------
// run_checkpoint_write(live)
// Serializes the run. `live` is the combat controller's player struct (or
// undefined) - passing it overrides HP/resources with the LIVE mid-fight
// values, the anti-cheese half of the design: resuming re-fights the room at
// the HP you actually had while the enemies reset to full.
// ---------------------------------------------------------------------------
function run_checkpoint_write(_live) {
    if (!variable_global_exists("save_slot") || global.save_slot < 0) return;
    if (!variable_global_exists("current_floor") || !variable_global_exists("run_seed")) return;

    var _hp   = variable_global_exists("run_current_hp")  ? global.run_current_hp  : 0;
    var _soul = variable_global_exists("run_souls")       ? global.run_souls       : 0;
    var _bld  = variable_global_exists("run_blood")       ? global.run_blood       : 0;
    var _prp  = variable_global_exists("run_preparation") ? global.run_preparation : 0;
    // Deployed trap board (08-11, task #28): only ever non-empty when this write
    // happens MID-COMBAT (traps are combat-scoped, a fresh board every fight).
    // Without it a resume re-fought the room with the AP/Prep spent on traps
    // gone but every trap silently wiped.
    var _trp = [];
    if (_live != undefined) {
        _hp = _live.HP;
        if (variable_struct_exists(_live, "souls"))       _soul = _live.souls;
        if (variable_struct_exists(_live, "blood"))       _bld  = _live.blood;
        if (variable_struct_exists(_live, "preparation")) _prp  = _live.preparation;
        if (variable_struct_exists(_live, "traps") && is_array(_live.traps)) _trp = _live.traps;
        // Never snapshot a dead player - the defeat handler owns that frame
        // (deletes the file and settles the run). Belt-and-braces vs ordering.
        if (_hp <= 0) return;
    }

    var _c = {
        // Identity + stale-detection guards (a New Game reusing the slot must
        // not inherit the old character's run - see run_checkpoint_peek).
        resume_version: RESUME_FORMAT_VERSION,
        save_version:   SAVE_FORMAT_VERSION,
        saved_at:       date_datetime_string(date_current_datetime()),
        player_name:    variable_global_exists("player_name") ? global.player_name : "",
        run_count:      variable_global_exists("run_count")   ? global.run_count   : 0,

        // Route - the floor map itself regenerates from run_seed + current_floor.
        run_seed:            global.run_seed,
        current_floor:       global.current_floor,
        floor_rooms_cleared: variable_global_exists("floor_rooms_cleared") ? global.floor_rooms_cleared : [],
        current_room_index:  variable_global_exists("current_room_index")  ? global.current_room_index  : 0,
        selected_dungeon:    variable_global_exists("selected_dungeon")    ? global.selected_dungeon    : "ashen_vault",
        selected_ascendance: variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0,
        descent_active:      variable_global_exists("descent_active")      ? global.descent_active      : false,
        descent_floor:       variable_global_exists("descent_floor")       ? global.descent_floor       : 0,
        extract_pending:     variable_global_exists("run_extract_pending") ? global.run_extract_pending : false,

        // Progress. gold is included because add_gold mutates it LIVE mid-run -
        // the hub save predates every pickup and spend (shrine tributes) since.
        gold:                global.gold,
        current_run_gold:    variable_global_exists("current_run_gold")   ? global.current_run_gold   : 0,
        current_run_kills:   variable_global_exists("current_run_kills")  ? global.current_run_kills  : 0,
        run_xp:              variable_global_exists("run_xp")             ? global.run_xp             : 0,
        run_level:           variable_global_exists("run_level")          ? global.run_level          : 1,
        pending_stat_points: variable_global_exists("pending_stat_points") ? global.pending_stat_points : 0,
        run_stat_bonuses:    variable_global_exists("run_stat_bonuses")   ? global.run_stat_bonuses   : { STR: 0, DEX: 0, CON: 0, INT: 0, WIS: 0, CHA: 0 },
        run_current_hp:      _hp,
        run_souls:           _soul,
        run_blood:           _bld,
        run_preparation:     _prp,
        run_traps:           _trp,
        run_bonus_max_hp:    variable_global_exists("run_bonus_max_hp")   ? global.run_bonus_max_hp   : 0,

        // Collections. carried_items/consumables are the real payload - the
        // main save intentionally omits mid-run finds so abandons revert.
        carried_items:        variable_global_exists("carried_items")        ? global.carried_items        : [],
        secured_items:        variable_global_exists("secured_items")        ? global.secured_items        : [],
        consumable_inventory: variable_global_exists("consumable_inventory") ? global.consumable_inventory : [],
        run_items_found:      variable_global_exists("run_items_found")      ? global.run_items_found      : [],
        run_found_pets:       variable_global_exists("run_found_pets")       ? global.run_found_pets       : [],
        run_trinkets:         variable_global_exists("run_trinkets")         ? global.run_trinkets         : [],
        run_boons:            variable_global_exists("run_boons")            ? global.run_boons            : [],
        run_curses:           variable_global_exists("run_curses")           ? global.run_curses           : [],
        run_honing:           variable_global_exists("run_honing")           ? global.run_honing           : {},
        events_seen_this_run: variable_global_exists("events_seen_this_run") ? global.events_seen_this_run : [],
        // Equip/loadout can change mid-run (loot-screen equips, Borrowed Memory),
        // so snapshot them rather than trusting the stale hub save.
        inventory:            variable_global_exists("inventory")            ? global.inventory            : [],
        player_loadout:       variable_global_exists("player_loadout")       ? global.player_loadout       : [],
        player_traits:        variable_global_exists("player_traits")        ? global.player_traits        : [],

        // Run-scoped flags and counters.
        second_wind_used:    variable_global_exists("second_wind_used")    ? global.second_wind_used    : false,
        fortune_favor_used:  variable_global_exists("fortune_favor_used")  ? global.fortune_favor_used  : false,
        blood_carry:         variable_global_exists("blood_carry")         ? global.blood_carry         : 0,
        gravewalker_used:    variable_global_exists("gravewalker_used")    ? global.gravewalker_used    : false,
        oathbreaker_hp:      variable_global_exists("oathbreaker_hp")      ? global.oathbreaker_hp      : 0,
        last_stand_used:     variable_global_exists("last_stand_used")     ? global.last_stand_used     : false,
        gift_given:          variable_global_exists("gift_given")          ? global.gift_given          : false,
        pet_treats_run:      variable_global_exists("pet_treats_run")      ? global.pet_treats_run      : 0,
        banshee_carried:     variable_global_exists("banshee_carried")     ? global.banshee_carried     : 0,
        run_borrowed_ability: variable_global_exists("run_borrowed_ability") ? global.run_borrowed_ability : "",
        run_borrowed_class:   variable_global_exists("run_borrowed_class")   ? global.run_borrowed_class   : "",
        pending_fire_stacks: variable_global_exists("pending_fire_stacks") ? global.pending_fire_stacks : 0,
        pending_ap_penalty:  variable_global_exists("pending_ap_penalty")  ? global.pending_ap_penalty  : 0,
        gold_potion_bosses:  variable_global_exists("gold_potion_bosses")  ? global.gold_potion_bosses  : 0,
        loot_potion_bosses:  variable_global_exists("loot_potion_bosses")  ? global.loot_potion_bosses  : 0,

        // Persistent-scope state that still MUTATES mid-run (rune drops, dust
        // trickle, kill-quest ticks, codex discoveries). The main save is
        // hub-stale during a dive, so without these a resume would lose every
        // rune/tick/discovery from the run's earlier rooms.
        rune_inventory:   variable_global_exists("rune_inventory")   ? global.rune_inventory   : [],
        rune_dust:        variable_global_exists("rune_dust")        ? global.rune_dust        : 0,
        quests:           (variable_global_exists("quests") && is_array(global.quests)) ? global.quests : [],
        total_kills:      variable_global_exists("total_kills")      ? global.total_kills      : 0,
        items_discovered: variable_global_exists("items_discovered") ? global.items_discovered : [],
        items_discovered_best: (variable_global_exists("items_discovered_best") && is_struct(global.items_discovered_best))
            ? global.items_discovered_best : {},
    };
    save_write_atomic(run_checkpoint_file(), json_stringify(_c));
}

// ---------------------------------------------------------------------------
// run_checkpoint_update_hp(live)
// Mid-combat writes must NOT re-serialize globals: gold/XP/items earned during
// the fight would land in a checkpoint whose room is still uncleared, and the
// resume's re-fight would then earn them AGAIN (dupe). The on-disk checkpoint
// from floor entry IS the room-entry state - so in combat we only patch the
// live HP/resource fields into it (the anti-rage-quit mirror) and leave every
// other field exactly as it was when the player walked in.
// ---------------------------------------------------------------------------
function run_checkpoint_update_hp(_live) {
    if (_live == undefined || _live.HP <= 0) return;
    var _ck = run_checkpoint_peek();
    if (_ck == undefined || !_ck.ok) return;
    var _c = _ck.data;
    _c.run_current_hp = _live.HP;
    if (variable_struct_exists(_live, "souls"))       _c.run_souls       = _live.souls;
    if (variable_struct_exists(_live, "blood"))       _c.run_blood       = _live.blood;
    if (variable_struct_exists(_live, "preparation")) _c.run_preparation = _live.preparation;
    // Trap board rides the same live patch (task #28) - the entry checkpoint
    // holds [] so a resume before any deploy still starts a clean board.
    if (variable_struct_exists(_live, "traps") && is_array(_live.traps)) _c.run_traps = _live.traps;
    save_write_atomic(run_checkpoint_file(), json_stringify(_c));
}

// ---------------------------------------------------------------------------
// run_checkpoint_write_now()
// Context-aware write for "the player is leaving RIGHT NOW" moments (quit to
// title mid-run, os_is_paused backgrounding). In combat it passes the LIVE
// player struct; once combat_over it writes NOTHING - the disk state is
// already correct (victory: the last mid-fight checkpoint stands, so the room
// is re-fought at the HP you had and its rewards are forfeit; defeat: the
// checkpoint was deleted the frame the death landed, never resurrected).
// ---------------------------------------------------------------------------
function run_checkpoint_write_now() {
    if (room == Room1) {
        if (instance_exists(obj_combat_controller)) {
            var _cc = instance_find(obj_combat_controller, 0);
            if (_cc.combat_over) return;
            run_checkpoint_update_hp(_cc.player);   // patch-only: see run_checkpoint_update_hp
        }
        return;
    }
    if (room == rm_dungeon_floor) run_checkpoint_write(undefined);
}

// ---------------------------------------------------------------------------
// run_checkpoint_peek()
// Reads + validates the slot's checkpoint WITHOUT touching global state.
// Returns undefined (no file), { ok: true, data } (valid), or { ok: false }
// (corrupt/version-mismatched/stale - caller deletes it and forfeits the run;
// M's rule: a broken checkpoint is never a free escape, but never a softlock).
// Stale = identity guards don't match the save just loaded (a New Game reused
// the slot between the crash and this load).
// ---------------------------------------------------------------------------
function run_checkpoint_peek() {
    if (!variable_global_exists("save_slot") || global.save_slot < 0) return undefined;
    var _f = run_checkpoint_file();
    if (!file_exists(_f)) return undefined;
    var _file = file_text_open_read(_f);
    var _json = "";
    while (!file_text_eof(_file)) {
        _json += file_text_read_string(_file);
        file_text_readln(_file);
    }
    file_text_close(_file);
    var _c = undefined;
    try { _c = json_parse(_json); } catch (_e) { return { ok: false }; }
    if (!is_struct(_c)) return { ok: false };
    if (!variable_struct_exists(_c, "resume_version") || _c.resume_version != RESUME_FORMAT_VERSION) return { ok: false };
    if (!variable_struct_exists(_c, "save_version")   || _c.save_version   != SAVE_FORMAT_VERSION)   return { ok: false };
    if (!variable_struct_exists(_c, "run_seed") || !variable_struct_exists(_c, "current_floor"))     return { ok: false };
    var _nm = variable_global_exists("player_name") ? global.player_name : "";
    var _rc = variable_global_exists("run_count")   ? global.run_count   : 0;
    if (!variable_struct_exists(_c, "player_name") || _c.player_name != _nm) return { ok: false };
    if (!variable_struct_exists(_c, "run_count")   || _c.run_count   != _rc) return { ok: false };
    return { ok: true, data: _c };
}

// ---------------------------------------------------------------------------
// run_checkpoint_apply(c)
// Restores the run from a peeked checkpoint and CONSUMES the file (ironman:
// a checkpoint is used exactly once). Caller then room_goto(rm_dungeon_floor);
// the floor controller regenerates the map from run_seed and, if the crash
// happened at the boss extract choice, re-opens that popup via
// global.run_extract_pending.
// ---------------------------------------------------------------------------
function run_checkpoint_apply(_c) {
    global.run_seed            = _c.run_seed;
    global.current_floor       = _c.current_floor;
    global.floor_map_floor     = -1;   // force map regen from the restored seed
    // The regen resets floor_rooms_cleared to all-false, so the restored flags
    // go through a stash the floor controller re-applies AFTER building the map.
    global.resume_rooms_cleared = variable_struct_exists(_c, "floor_rooms_cleared") ? _c.floor_rooms_cleared : undefined;
    global.current_room_index  = variable_struct_exists(_c, "current_room_index")  ? _c.current_room_index  : 0;
    global.selected_dungeon    = variable_struct_exists(_c, "selected_dungeon")    ? _c.selected_dungeon    : "ashen_vault";
    global.selected_ascendance = variable_struct_exists(_c, "selected_ascendance") ? _c.selected_ascendance : 0;
    global.descent_active      = variable_struct_exists(_c, "descent_active")      ? _c.descent_active      : false;
    global.descent_floor       = variable_struct_exists(_c, "descent_floor")       ? _c.descent_floor       : 0;
    global.run_extract_pending = variable_struct_exists(_c, "extract_pending")     ? _c.extract_pending     : false;

    global.gold                = variable_struct_exists(_c, "gold")                ? _c.gold                : global.gold;
    global.current_run_gold    = variable_struct_exists(_c, "current_run_gold")    ? _c.current_run_gold    : 0;
    global.current_run_kills   = variable_struct_exists(_c, "current_run_kills")   ? _c.current_run_kills   : 0;
    global.run_xp              = variable_struct_exists(_c, "run_xp")              ? _c.run_xp              : 0;
    global.run_level           = variable_struct_exists(_c, "run_level")           ? _c.run_level           : 1;
    global.pending_stat_points = variable_struct_exists(_c, "pending_stat_points") ? _c.pending_stat_points : 0;
    global.run_stat_bonuses    = variable_struct_exists(_c, "run_stat_bonuses")    ? _c.run_stat_bonuses    : { STR: 0, DEX: 0, CON: 0, INT: 0, WIS: 0, CHA: 0 };
    global.run_current_hp      = variable_struct_exists(_c, "run_current_hp")      ? _c.run_current_hp      : 0;
    global.run_souls           = variable_struct_exists(_c, "run_souls")           ? _c.run_souls           : 0;
    global.run_blood           = variable_struct_exists(_c, "run_blood")           ? _c.run_blood           : 0;
    global.run_preparation     = variable_struct_exists(_c, "run_preparation")     ? _c.run_preparation     : 0;
    // Guarded restore, default [] (task #28): pre-08-11 checkpoints have no
    // run_traps field. Consumed (and cleared) by obj_combat_controller Create.
    global.run_traps           = (variable_struct_exists(_c, "run_traps") && is_array(_c.run_traps)) ? _c.run_traps : [];
    global.run_bonus_max_hp    = variable_struct_exists(_c, "run_bonus_max_hp")    ? _c.run_bonus_max_hp    : 0;

    global.carried_items        = variable_struct_exists(_c, "carried_items")        ? _c.carried_items        : [];
    global.secured_items        = variable_struct_exists(_c, "secured_items")        ? _c.secured_items        : [];
    // Same dup-row hygiene the main load runs on inventory/stash (covers run loot
    // checkpointed before the 07-28 legendary same-stat fold).
    for (var _cmi = 0; _cmi < array_length(global.carried_items); _cmi++) item_merge_dup_affixes(global.carried_items[_cmi]);
    for (var _cmi = 0; _cmi < array_length(global.secured_items); _cmi++) item_merge_dup_affixes(global.secured_items[_cmi]);
    global.consumable_inventory = variable_struct_exists(_c, "consumable_inventory") ? _c.consumable_inventory : [];
    global.run_items_found      = variable_struct_exists(_c, "run_items_found")      ? _c.run_items_found      : [];
    global.run_found_pets       = variable_struct_exists(_c, "run_found_pets")       ? _c.run_found_pets       : [];
    global.run_trinkets         = variable_struct_exists(_c, "run_trinkets")         ? _c.run_trinkets         : [];
    global.run_boons            = variable_struct_exists(_c, "run_boons")            ? _c.run_boons            : [];
    global.run_curses           = variable_struct_exists(_c, "run_curses")           ? _c.run_curses           : [];
    // A resumed run already received its origin run-start grants (08-11).
    global.origin_run_granted   = true;
    global.run_honing           = variable_struct_exists(_c, "run_honing")           ? _c.run_honing           : {};
    global.events_seen_this_run = variable_struct_exists(_c, "events_seen_this_run") ? _c.events_seen_this_run : [];
    if (variable_struct_exists(_c, "inventory"))      global.inventory      = _c.inventory;
    if (variable_struct_exists(_c, "player_loadout")) global.player_loadout = _c.player_loadout;
    if (variable_struct_exists(_c, "player_traits"))  global.player_traits  = _c.player_traits;

    global.second_wind_used     = variable_struct_exists(_c, "second_wind_used")     ? _c.second_wind_used     : false;
    global.fortune_favor_used   = variable_struct_exists(_c, "fortune_favor_used")   ? _c.fortune_favor_used   : false;
    global.blood_carry          = variable_struct_exists(_c, "blood_carry")          ? _c.blood_carry          : 0;
    global.gravewalker_used     = variable_struct_exists(_c, "gravewalker_used")     ? _c.gravewalker_used     : false;
    global.oathbreaker_hp       = variable_struct_exists(_c, "oathbreaker_hp")       ? _c.oathbreaker_hp       : 0;
    global.last_stand_used      = variable_struct_exists(_c, "last_stand_used")      ? _c.last_stand_used      : false;
    global.gift_given           = variable_struct_exists(_c, "gift_given")           ? _c.gift_given           : false;
    global.pet_treats_run       = variable_struct_exists(_c, "pet_treats_run")       ? _c.pet_treats_run       : 0;
    global.banshee_carried      = variable_struct_exists(_c, "banshee_carried")      ? _c.banshee_carried      : 0;
    global.run_borrowed_ability = variable_struct_exists(_c, "run_borrowed_ability") ? _c.run_borrowed_ability : "";
    global.run_borrowed_class   = variable_struct_exists(_c, "run_borrowed_class")   ? _c.run_borrowed_class   : "";
    global.pending_fire_stacks  = variable_struct_exists(_c, "pending_fire_stacks")  ? _c.pending_fire_stacks  : 0;
    global.pending_ap_penalty   = variable_struct_exists(_c, "pending_ap_penalty")   ? _c.pending_ap_penalty   : 0;
    global.gold_potion_bosses   = variable_struct_exists(_c, "gold_potion_bosses")   ? _c.gold_potion_bosses   : 0;
    global.loot_potion_bosses   = variable_struct_exists(_c, "loot_potion_bosses")   ? _c.loot_potion_bosses   : 0;

    // Persistent-scope state that mutated mid-run (see the write side).
    if (variable_struct_exists(_c, "rune_inventory"))   global.rune_inventory   = _c.rune_inventory;
    if (variable_struct_exists(_c, "rune_dust"))        global.rune_dust        = _c.rune_dust;
    if (variable_struct_exists(_c, "quests") && is_array(_c.quests)) global.quests = _c.quests;
    if (variable_struct_exists(_c, "total_kills"))      global.total_kills      = _c.total_kills;
    if (variable_struct_exists(_c, "items_discovered")) global.items_discovered = _c.items_discovered;
    if (variable_struct_exists(_c, "items_discovered_best") && is_struct(_c.items_discovered_best)) {
        global.items_discovered_best = _c.items_discovered_best;
    }
    // Veil reslot fixup + CODEX PASS round 2 (07-29): same order as the main
    // load (worn + carried/secured run loot restored above).
    veil_slot_fixup();
    codex_backfill_owned();

    // Not mid-transition: the floor controller Create derives these on arrival.
    global.just_cleared_boss = false;
    global.just_cleared_room = false;

    // The loadout was committed when this run started - re-latch the flag so
    // nothing routes the player back through dungeon-select/loadout.
    if (instance_exists(obj_game_controller)) {
        instance_find(obj_game_controller, 0).loadout_confirmed = true;
    }

    // IRONMAN: the checkpoint is consumed the moment it is loaded.
    run_checkpoint_delete();
}

// ---------------------------------------------------------------------------
// run_floor_advance()
// Single source for the boss CONTINUE choice: advance the floor (Descent
// floors re-roll their theme and deepen the effective Awakening) and re-enter
// the dungeon. Called from the combat extract popup AND the floor-map resume
// popup so the two can never drift. (SYSTEMS_ENDLESS.md §3 for the Descent math.)
// ---------------------------------------------------------------------------
function run_floor_advance() {
    global.run_extract_pending = false;
    global.just_cleared_boss   = false;
    global.floor_rooms_cleared = [];
    global.current_floor++;
    if (variable_global_exists("descent_active") && global.descent_active) {
        var _dsc_keys = ["ashen_vault", "scorched_depths", "tundra_tomb"];
        global.selected_dungeon    = _dsc_keys[irandom(2)];
        global.descent_floor       = global.current_floor;
        global.selected_ascendance = 5 + global.current_floor * 0.5;
    }
    room_goto(rm_dungeon_floor);
}

// =============================================================================
// THE IRON VOW - memorials + the fall (SYSTEMS_IRON_VOW.md, M-locked 07-28).
// A fallen Vow character leaves a small gravestone record where the save was;
// the title screen draws it on the slot card. A New Game claiming the slot
// deletes it (obj_title_controller, beside the stale-checkpoint delete).
// =============================================================================
function vow_memorial_file(_slot) {
    return "ironwake_memorial_" + string(_slot) + ".json";
}

function vow_memorial_delete(_slot) {
    var _f = vow_memorial_file(_slot);
    if (file_exists(_f)) file_delete(_f);
    if (file_exists(_f + ".tmp")) file_delete(_f + ".tmp");
}

function vow_memorial_read(_slot) {
    var _f = vow_memorial_file(_slot);
    if (!file_exists(_f)) return undefined;
    var _file = file_text_open_read(_f);
    var _json = "";
    while (!file_text_eof(_file)) {
        _json += file_text_read_string(_file);
        file_text_readln(_file);
    }
    file_text_close(_file);
    var _m = undefined;
    try { _m = json_parse(_json); } catch (_e) { return undefined; }
    if (!is_struct(_m)) return undefined;
    _m.memorial = true;   // the flag the slot card + loadable check key off
    return _m;
}

// ---------------------------------------------------------------------------
// vow_fall()
// The final death: write the gravestone, then delete the save file and the
// resume checkpoint. Runs INSIDE the defeat-settlement frame (after
// end_run(-1) has updated the lifetime stats), so killing the app on the
// death screen cannot preserve the character. (SYSTEMS_IRON_VOW.md)
// ---------------------------------------------------------------------------
function vow_fall() {
    if (!variable_global_exists("save_slot") || global.save_slot < 0) return;
    var _mem = {
        player_name:          variable_global_exists("player_name")          ? global.player_name          : "Unknown",
        class_id:             variable_global_exists("chosen_class")         ? global.chosen_class         : 0,
        epithet:              variable_global_exists("player_epithet")       ? global.player_epithet       : "",
        best_floor:           variable_global_exists("best_floor")           ? global.best_floor           : 0,
        run_count:            variable_global_exists("run_count")            ? global.run_count            : 0,
        dungeon_clears_total: variable_global_exists("dungeon_clears_total") ? global.dungeon_clears_total : 0,
        ironwake_stands:      variable_global_exists("ironwake_stands")      ? global.ironwake_stands      : false,
        vow_mode:             global.vow_mode,
        died_at:              date_datetime_string(date_current_datetime()),
    };
    save_write_atomic(vow_memorial_file(global.save_slot), json_stringify(_mem));
    var _sf = "ironwake_save_" + string(global.save_slot) + ".json";
    if (file_exists(_sf)) file_delete(_sf);
    if (file_exists(_sf + ".tmp")) file_delete(_sf + ".tmp");
    run_checkpoint_delete();
    // Unbind the slot so NOTHING can save_game() the dead character back into
    // existence between here and the next slot claim (save_game no-ops at -1).
    global.save_slot = -1;
}
