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
    "Vael the Aesthete"
];

// One-line summaries shown in the NPC list rows
npc_descriptions = [
    "Weapons, armor, and gear - browse Dorn's rotating stock. Press Space to enter the forge.",
    "Salvages loot into rune dust; brews and upgrades potions. Press Space to open the apothecary.",
    "Sockets gear runes for stats and aspect runes for combat buffs. Press Space to open the runeworks.",
    "Permanent stat upgrades, ability unlocks, and trait slot expansion.",
    "Consumables and supplies for your next run. Press Space to browse Petra's wares.",
    "Cosmetic transmog - buy and wear character skins. Press Space to visit the atelier."
];

// All six hub NPCs are permanently available from the start (design decision -
// no unlock gating). Not persisted in the save: re-initialized here every time the
// hub loads, so no save can ever re-lock an NPC. Keep this array all-true.
npc_unlocked = [true, true, true, true, true, true];


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

// Hub music
audio_play_sound(Rainy_Memories, 1, true);
audio_apply_volumes();   // honor saved Music/SFX volumes for this session's sounds

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
