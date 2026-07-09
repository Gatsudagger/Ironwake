// =============================================================================
// obj_hub_controller - Create event
// Initialises all hub UI state. Runs once when the hub room is entered.
// Reads global state set by obj_game_controller - that object must exist and
// be persistent before this room is loaded.
// =============================================================================

// Seed a shop if this character doesn't have one yet. Shop stock persists per slot
// (saved/restored in scr_save), so a loaded character keeps their exact Dorn/Petra
// stock and this is a no-op. It only rolls a fresh shop when the stock is empty -
// a brand-new character, or a save written before shop persistence existed.
if (!variable_global_exists("dorn_stock") || !is_array(global.dorn_stock)
    || array_length(global.dorn_stock) == 0) {
    restock_shops();
}

// Bairc Companion perk (Phase 4a): on the first hub return after a run, he quietly
// mends one injury tier on the most-hurt creature. Armed in end_run, consumed here.
if (variable_global_exists("bairc_mend_pending") && global.bairc_mend_pending
    && affinity_at_least("bairc", 3)) {
    global.bairc_mend_pending = false;
    var _bm_best = undefined;
    var _bm_r = pet_roster();
    for (var _bm = 0; _bm < array_length(_bm_r); _bm++) {
        var _bmp = _bm_r[_bm];
        if (is_struct(_bmp) && !_bmp.is_egg && _bmp.injured > 0
            && (_bm_best == undefined || _bmp.injured > _bm_best.injured)) _bm_best = _bmp;
    }
    if (_bm_best != undefined) {
        _bm_best.injured = max(0, _bm_best.injured - 1);
        if (variable_global_exists("pet_find_notice")) {
            var _bm_msg = "Bairc has already seen to " + _bm_best.name + " - its wounds sit easier.";
            global.pet_find_notice = (global.pet_find_notice != "")
                ? (global.pet_find_notice + "   " + _bm_msg) : _bm_msg;
        }
    }
}


// -----------------------------------------------------------------------------
// 1. NPC ROSTER
// -----------------------------------------------------------------------------

// Index of the currently highlighted NPC row
selected_npc = 0;

// Display names shown in the list and detail panel
npc_names = [
    "Dorn the Blacksmith",
    "Sable the Alchemist",
    "Maren the Runesmith",
    "Vex the Trainer",
    "Petra the Merchant",
    "Vael the Aesthete",
    "Bairc the Creature Keeper",
    "Tavern Requests"
];

// One-line summaries shown in the NPC list rows
npc_descriptions = [
    "Weapons, armor, and gear - browse Dorn's rotating stock. Press Space to enter the forge.",
    "Salvages loot into rune dust; brews and upgrades potions. Press Space to open the apothecary.",
    "Sockets gear runes for stats and aspect runes for combat buffs. Press Space to open the runeworks.",
    "Permanent stat upgrades, ability unlocks, and trait slot expansion.",
    "Consumables and supplies for your next run. Press Space to browse Petra's wares.",
    "Cosmetic transmog - buy and wear character skins. Press Space to visit the atelier.",
    "Tends and raises the creatures you find below. Press Space to visit his garden.",
    "Postings from the townsfolk - jobs, hunts and favors. Press Space to read the board."
];

// All seven hub NPCs are permanently present from the start (design decision -
// no unlock gating). Bairc is PRESENT but DORMANT until you find your first pet/egg
// (handled at interaction, not here). Not persisted: re-initialized every hub load so
// no save can re-lock an NPC. Keep this array all-true. Row 8 = the Tavern Requests
// board (Phase 4b UX: quests are accepted/turned in at the board, not the Journal).
npc_unlocked = [true, true, true, true, true, true, true, true];


// -----------------------------------------------------------------------------
// 2. LAST RUN SUMMARY
// show_last_run is true whenever there is a completed run to display.
// The player can dismiss it with Escape; it also clears on room re-entry.
// -----------------------------------------------------------------------------
show_last_run = (global.last_run_result != 0);


// -----------------------------------------------------------------------------
// 3. NOTIFICATION STRING
// Overwritten by interactions; cleared on the next navigation keypress.
// Drawn by Draw_64 as a small overlay near the bottom of the detail panel.
// -----------------------------------------------------------------------------
notification = "";
// Re-validate equipped gear against stats WITHOUT the run's temporary gains
// (run_stat_bonuses are cleared by now): an item equipped on borrowed mid-run
// stats gets auto-unequipped to the stash instead of gaming the gate (M 07-08).
var _eq_dropped = equip_validate_stat_reqs();
if (array_length(_eq_dropped) > 0) {
    var _eq_names = "";
    for (var _eqi = 0; _eqi < array_length(_eq_dropped); _eqi++) {
        _eq_names += (_eqi > 0 ? ", " : "") + _eq_dropped[_eqi];
    }
    notification = "Your temporary power has left you - unequipped to stash: " + _eq_names + ".";
    if (variable_global_exists("save_slot") && global.save_slot >= 0) save_game();
}
// Surface a pet/egg recovered during the last run (set at boss-clear), once, on return.
// Persist immediately so a creature found mid-run can't be lost before the next save.
if (variable_global_exists("pet_find_notice") && global.pet_find_notice != "") {
    notification = (notification != "" ? notification + "   " : "") + global.pet_find_notice;
    global.pet_find_notice = "";
    if (variable_global_exists("save_slot") && global.save_slot >= 0) save_game();
}

// (Starter pet is now granted the first time you TALK to Bairc - see obj_hub_controller
// Step: he notices the egg stir, hands it to you as a tutorial. No auto-grant here.)

// One-time capstone re-pick migration: raised Adults from before the pick UI get their
// auto-rolled capstone cleared so they can choose. Self-guarding, safe to call each entry.
if (variable_global_exists("pet_roster")) pet_capstone_migrate_all();

// Re-skin any retired humanoid-species pets to a real creature (idempotent).
if (variable_global_exists("pet_roster")) pet_migrate_retired_species();


// -----------------------------------------------------------------------------
// 4. RUN HISTORY PANEL STATE
// -----------------------------------------------------------------------------
show_history   = false;
history_scroll = 0;


// -----------------------------------------------------------------------------
// 5. ITEM GALLERY STATE
// -----------------------------------------------------------------------------
show_gallery        = false;
gallery_scroll      = 0;    // top visible row index
gallery_cursor      = -1;   // highlighted row (-1 = none)
gallery_detail_item = undefined;   // item struct shown in detail panel (undefined = closed)

// Hub music + ambience bed (night rain outside, torch crackle at the gate)
audio_play_sound(Rainy_Memories, 1, true);
audio_apply_volumes();   // honor saved Music/SFX volumes for this session's sounds
ambience_set([snd_amb_rain, snd_amb_torch]);

// -----------------------------------------------------------------------------
// ENDING SEQUENCE (WIN_STATE_SPEC.md) - armed by end_run when the third
// Awakening-V dungeon clear lands; plays once, on this hub arrival.
// Speakers = every NPC at Acquaintance+ who was never betrayed; betrayed
// keepers are counted for the absence beat instead.
// -----------------------------------------------------------------------------
ending_active   = false;
ending_stage    = 0;
ending_speakers = [];
ending_absent   = 0;
if (variable_global_exists("ending_pending") && global.ending_pending) {
    affinity_ensure();
    var _end_ids = affinity_npc_ids();
    for (var _ei = 0; _ei < array_length(_end_ids); _ei++) {
        var _ee = affinity_entry(_end_ids[_ei]);
        if (_ee != undefined && variable_struct_exists(_ee, "betrayed") && _ee.betrayed) {
            ending_absent++;
            continue;
        }
        var _et = affinity_tier(_end_ids[_ei]);
        if (_et >= 1) array_push(ending_speakers, { id: _end_ids[_ei], tier: _et });
    }
    ending_active = true;
    audio_play_sound(snd_sting_victory, 1, false);
}

// NPC portrait animation state
portrait_prev_npc   = 0;
portrait_slide_y    = 0.0;
portrait_fade_alpha = 1.0;


// -----------------------------------------------------------------------------
// 6. HUB ATMOSPHERE - camp background art, ambient embers, flavor line
// -----------------------------------------------------------------------------
// Looked up by name so the project compiles before the sprite resource exists.
// Returns -1 until you create spr_hub_background in the IDE; the draw is guarded.
bg_sprite = asset_get_index("spr_hub_background");

// Drifting ember motes rising from the campfire glow (subtle, behind panels).
// Count tripled (18 -> 54) for a livelier, more atmospheric drift.
hub_embers = [];
for (var _ei = 0; _ei < 54; _ei++) {
    array_push(hub_embers, {
        x:     irandom(GUI_W),
        y:     irandom(GUI_H),
        spd:   0.2 + random(0.4),     // upward px/frame
        phase: random(6.283),         // sine seed for horizontal drift + shimmer
        drift: 8 + random(14),        // horizontal drift amplitude (px)
        size:  1 + irandom(2),        // 1-3 px
        a:     0.20 + random(0.32)    // base alpha 0.20-0.52 (slightly more visible)
    });
}

// Rotating camp flavor line - one picked per hub visit.
hub_flavor_lines = [
    "The fire crackles low. Dorn's hammer rings somewhere in the dark.",
    "Embers drift on a cold wind. The dungeon gate glows beyond the tents.",
    "Camp is quiet. Sable hums over a bubbling flask.",
    "Steel and rune-dust scent the air. Rest while you can.",
    "Maren traces runes by firelight. The night holds its breath.",
    "Below, the dungeon stirs. The camp keeps its small, stubborn warmth."
];
hub_flavor = hub_flavor_lines[irandom(array_length(hub_flavor_lines) - 1)];


// -----------------------------------------------------------------------------
// 7. ONBOARDING - show the hub coach-mark on the player's very first camp visit
// (the first surface they see after character creation). Once-only; gated by the
// saved tutorial flags. See SYSTEMS_ONBOARDING.md.
// -----------------------------------------------------------------------------
tutorial_try_show("hub");
