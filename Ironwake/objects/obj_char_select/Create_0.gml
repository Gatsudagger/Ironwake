// =============================================================================
// obj_char_select - Create event
// Initialises the character selection screen state.
// The player picks a class, optionally allocates 4 free stat points, then
// confirms to proceed into combat.
// =============================================================================


// -----------------------------------------------------------------------------
// SELECTION STATE
// -----------------------------------------------------------------------------

// Currently highlighted class tab (0=Arcanist, 1=Bloodwarden, 2=Shadowstrider)
selected_class = 0;

// Index of the stat row currently highlighted for point allocation
// 0=STR  1=DEX  2=CON  3=INT  4=WIS  5=CHA
selected_stat = 0;

// Points remaining for the player to distribute before confirming
free_points = 4;

// Set true once the player presses Confirm - triggers room transition
confirmed = false;

// Set true when the name-entry overlay is active
naming_active = false;

// Set true when the portrait-selection overlay is active (after name confirmed)
portrait_active   = false;
selected_portrait = 0;

// Cosmetic gender for the chosen class's combat sprite ("m"/"f"). Toggled with Q/E
// on the class-select screen; committed to global.player_gender at confirm.
selected_gender = "m";


// -----------------------------------------------------------------------------
// BASE STAT TEMPLATES
// Pre-built so switching between classes instantly restores the preset values
// without re-calling stats_init each frame.
// -----------------------------------------------------------------------------
arcanist_stats    = stats_init(0);
bloodwarden_stats = stats_init(1);
shadowstrider_stats = stats_init(2);


// -----------------------------------------------------------------------------
// WORKING STATS
// A live copy of the selected class stats that the player edits.
// Reset to the class preset whenever the player switches class.
// -----------------------------------------------------------------------------
working_stats = stats_init(selected_class);
working_stats.free_points = 4;


// -----------------------------------------------------------------------------
// CLASS DISPLAY DATA
// -----------------------------------------------------------------------------

class_names = [
    "Arcanist",
    "Bloodwarden",
    "Shadowstrider",
];

class_descriptions = [
    "Glass cannon mage. Kills fast, heals off kills. Secondary resource: Souls.",
    "Sustain drain tank. Wins by attrition. Secondary resource: Blood.",
    "Evasion ranger. Avoids damage through traps. Secondary resource: Preparation.",
];
