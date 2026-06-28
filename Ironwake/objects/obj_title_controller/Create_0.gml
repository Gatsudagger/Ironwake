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

// =============================================================================
// INTRO SCENE BACKGROUND + AMBIENT ATMOSPHERE
// A wide dark-forest/town/crypt night vista (spr_title_background) drawn behind
// BOTH the cutscene (slow horizontal pan, dim behind the text) and the title menu
// (brightens to full, gentle parallax drift). Looked up by name so the project
// compiles before the sprite resource exists - the draw is guarded on existence.
// =============================================================================
scene_sprite = asset_get_index("spr_title_background");
scene_alpha  = 0.0;     // background fade-in (ramps to 0.5 in cutscene, 1.0 at title)
scene_pan    = 0.0;     // 0..1 horizontal pan progress across the vista's overscan
// intro_t: 0..1 "dolly forward" progress for the parallax. Creeps up through the
// cutscene, then accelerates as the title loads. Drives the foreground treeline
// (grows + sinks + fades as you push through it) and a subtle vista zoom-in.
intro_t = 0.0;

// Twinkling stars scattered across the upper sky band.
sky_stars = [];
for (var _si = 0; _si < 70; _si++) {
    array_push(sky_stars, {
        x:     irandom(GUI_W),
        y:     irandom(430),            // upper sky region only
        phase: random(6.283),
        size:  (random(1) < 0.82) ? 1 : 2,
        a:     0.20 + random(0.45)
    });
}

// Drifting low fog/mist banks hazing the town + forest base.
fog_layers = [];
for (var _fi = 0; _fi < 3; _fi++) {
    array_push(fog_layers, {
        y:    700 + _fi * 95,
        spd:  0.0006 + _fi * 0.0003,    // sine-bob rate (slow)
        off:  random(6.283),
        a:    0.10 + _fi * 0.03         // base alpha per band
    });
}

// Periodic shooting star. Dormant until the timer fires, then streaks across the
// sky and resets to a fresh cooldown. Only one streak in flight at a time.
star_timer   = 90 + irandom(180);      // frames until the first streak
star_active  = false;
star_x       = 0;
star_y       = 0;
star_dx      = 0;
star_dy      = 0;
star_life    = 0;
star_maxlife = 0;

// Red-moon glow anchor, stored as FRACTIONS of the vista image so the additive
// halo tracks the painted moon as the scene pans. Measured from the art: the moon
// disc sits at ~(0.555, 0.178) of the image, radius ~0.083 of its width.
moon_fx = 0.555;
moon_fy = 0.178;
moon_fr = 0.083;
