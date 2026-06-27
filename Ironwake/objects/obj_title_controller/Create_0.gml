// =============================================================================
// obj_title_controller - Create
// Manages the intro cutscene -> title screen -> new game flow.
// =============================================================================

// Intro cutscene panels - displayed one at a time with typewriter effect
cutscene_panels = [
    "You have wandered for an eternity-\nor was it just a day?",
    "A town. A wake.\nThe dead are being honored by those\nwho've forgotten they too are lost.",
    "Through the haze, you see it:\na crypt crowned with ironwork,\ngilded and beckoning.",
    "And there - a tavern,\ncloser, warmer, more insistent still.",
    "You have been here before.\nYou will be here again.",
    "Welcome to the Ironwake.",
];

panel_idx    = 0;
typed_chars  = 0.0;    // fractional character counter
type_speed   = 0.4;    // characters typed per frame
line_pause   = 0;      // frames waited after a line finishes before starting the next
screen_alpha = 0.0;    // overall cutscene fade-in

phase        = "cutscene";  // "cutscene" | "title" | "slot_picker"

// Load saved audio volumes and apply them before any sound plays this session.
audio_settings_init();
audio_apply_volumes();

// Intro and title screen music - loops until the player starts a new game
audio_play_sound(Viking_March, 1, true);
skip_timer   = 0;
skip_hold    = 40;           // frames before any-key-skip is accepted

// Title screen
title_alpha  = 0.0;
menu_alpha   = 0.0;
selected     = 0;       // 0 = New Game, 1 = Load Game
blink        = 0;
can_input    = false;

// Slot picker
slot_mode     = "new_game";   // "new_game" | "load_game"
slot_selected = 0;            // 0-2
slot_confirm  = false;        // true when overwrite confirmation is waiting

// Cache slot previews once at startup - avoids per-frame file/HTTP reads in HTML5
slot_previews    = array_create(3, undefined);
slot_previews[0] = get_slot_preview(0);
slot_previews[1] = get_slot_preview(1);
slot_previews[2] = get_slot_preview(2);
