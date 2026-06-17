// =============================================================================
// obj_hub_controller — Create event
// Initialises all hub UI state. Runs once when the hub room is entered.
// Reads global state set by obj_game_controller — that object must exist and
// be persistent before this room is loaded.
// =============================================================================


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
    "Weapons, armor, and gear — browse Dorn's rotating stock. Press Space to enter the forge.",
    "Purification altar. Removes curses from equipment using reagents.",
    "Sockets runes into abilities and gear. Combines and splits runes.",
    "Permanent stat upgrades, ability unlocks, and trait slot expansion.",
    "Consumables and supplies for your next run. Press Space to browse Petra's wares.",
    "Cosmetic transmog — change the appearance of your gear."
];

// Dorn and Petra are available from the start; the rest gate on hub_unlocks
npc_unlocked = [true, false, false, false, true, false];


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
