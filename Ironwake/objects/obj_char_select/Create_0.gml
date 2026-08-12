// =============================================================================
// obj_char_select - Create event
// Initialises the character selection screen state.
// The player picks a class, optionally allocates 4 free stat points, then
// confirms to proceed into combat.
// =============================================================================


// -----------------------------------------------------------------------------
// SELECTION STATE
// -----------------------------------------------------------------------------

// Night-forest crickets under the otherwise-silent creation screen (M 07-16:
// they clashed with the title music, but fit here in the quiet).
ambience_set([snd_amb_title]);

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

// Frames left on the "Enter a name to continue" warning (confirm with empty name)
naming_blocked_flash = 0;

// Set true when the portrait-selection overlay is active (after name confirmed)
portrait_active   = false;
selected_portrait = 0;

// RPG ORIGIN step (08-11, M design-locked) - after portrait, before the Vow.
// 12 background cards in a 4x3 grid; each is a small mechanical start.
origin_active   = false;
selected_origin = 0;

// THE IRON VOW step (SYSTEMS_IRON_VOW.md) - after portrait, before the hub.
// 0 = Standard (default), 1 = THE IRON VOW (3 lives), 2 = THE UNBROKEN VOW (1).
// Picking a Vow opens a bordered CONFIRM/CANCEL popup (checkout standing rule).
vow_active       = false;
selected_vow     = 0;
vow_confirm_open = false;

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

// -----------------------------------------------------------------------------
// TOUCH CONTROLS INTRO (07-24, ANDROID_TRACKING: popup on the new-character
// screen, before class choice). One-time note for touch players: tap and the
// on-screen d-pad both work, and the d-pad is resizable/removable in Settings.
// Seen-flag lives in settings.ini [touch] (device-level, beside the d-pad prefs
// it points at) - NOT the save: save_game() mid-char-create would write a stub
// character into the slot.
// -----------------------------------------------------------------------------
touch_settings_init();
ini_open("settings.ini");
touch_intro_open = (input_device() == 2) && (ini_read_real("touch", "intro_seen", 0) < 0.5);
ini_close();
