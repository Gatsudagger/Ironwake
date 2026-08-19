// =============================================================================
// obj_char_select - Step event
// Handles all keyboard input for the character selection screen.
// Input map (remapped 2026-07-14, M: streamline - stat boxes are a horizontal
// row so left/right selects them; vertical +/- matches "up = more"):
//   Q / E                 - previous / next class
//   Left / A, Right / D   - previous / next stat box
//   Up / W                - add 1 free point to selected stat
//   Down / S  or  X       - remove 1 point from selected stat (refunds to pool)
//   Enter / Space         - add 1 free point (or confirm when pool empty)
//   G                     - toggle gender
//   Mouse click (panel)   - select class
//   Mouse click (stat box)- select stat + add point if pool > 0
// =============================================================================

// Touch-controls intro popup (07-24): while up it owns the screen - the GOT IT
// tap is handled in Draw_64 (draw + hit-test together, per the touch rule).
if (touch_intro_open) exit;

// Stat name lookup shared by the add and remove sections
var _stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];

// --- Mouse input (GUI space) ---
// Handled early (before naming_active branch) so clicks on panels/boxes register
// each frame. Gated off during the Vow step so card taps can't leak through to
// the class panels / stat boxes underneath the overlay.
if (!naming_active && !confirmed && !vow_active && !portrait_active && !origin_active) {
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    // Right-click a stat box: take ONE point back (the X key) - 08-19 mouse pass (the touch
// REMOVE button has no desktop twin; the legend names it).
if (mouse_check_button_pressed(mb_right) && free_points < 4) {
    var _rmx = device_mouse_x_to_gui(0), _rmy = device_mouse_y_to_gui(0);
    if (_rmx >= 0 && _rmx <= GUI_W && _rmy >= 150 && _rmy <= 900) touch_press(ord("X"));
}
if (mouse_check_button_pressed(mb_left)) {
        // Class panels: x0=150, stride=552, w=516, y=174-789 (lockstep with native draw layout)
        for (var _ci = 0; _ci < 3; _ci++) {
            var _cpx = 150 + _ci * 552;
            if (_mx >= _cpx && _mx < _cpx+516 && _my >= 174 && _my < 789) {
                if (_ci != selected_class) {
                    selected_class = _ci;
                    working_stats  = stats_init(selected_class);
                    working_stats.free_points = 4;
                    free_points    = 4;
                    selected_stat  = 0;
                }
                break;
            }
        }
        // Stat boxes: row_x0=562.5, stride=135, w=120, y=843-921 (lockstep with native draw)
        var _bx0 = 562.5;
        var _by0 = 843;
        for (var _si2 = 0; _si2 < 6; _si2++) {
            var _sbx = _bx0 + _si2 * 135;
            if (_mx >= _sbx && _mx < _sbx+120 && _my >= _by0 && _my < _by0+78) {
                selected_stat = _si2;
                if (free_points > 0) {
                    stats_apply_points(working_stats, _stat_names[_si2], 1);
                    free_points = working_stats.free_points;
                }
                break;
            }
        }
        // Confirm: click the bottom instruction bar area when all points are spent
        if (free_points == 0 && _my >= 1005 && _my <= 1073) {
            naming_active   = true;
            keyboard_string = "";
        }
    }
}


// -----------------------------------------------------------------------------
// NAME ENTRY - active after Space confirms class/stats
// Captures keyboard_string; Enter finalises; Escape cancels back to selection.
// -----------------------------------------------------------------------------
if (naming_active) {
    // Clamp name to 16 characters
    if (string_length(keyboard_string) > 16) {
        keyboard_string = string_copy(keyboard_string, 1, 16);
    }

    if (input_confirm()) {
        var _name = string_trim(keyboard_string);
        if (_name == "") {
            // No nameless heroes (07-14 report) - hold the modal until they type one.
            naming_blocked_flash = 60;   // Draw shows "Enter a name to continue"
            exit;
        }
        global.player_name  = _name;
        global.chosen_class = selected_class;
        global.chosen_stats = working_stats;
        global.player_gender = selected_gender;
        naming_active       = false;
        portrait_active     = true;
        selected_portrait   = 0;
        // Curated creation pool (08-14): 3 picks for THIS class+gender; the
        // rest of the 60 live at Vael. Flat indices into global.portrait_sprites.
        portrait_pool       = portrait_creation_pool(global.chosen_class, global.player_gender);
        exit;
    }
    if (naming_blocked_flash > 0) naming_blocked_flash--;

    if (input_cancel()) {
        naming_active    = false;
        keyboard_string  = "";
    }

    exit;
}


// -----------------------------------------------------------------------------
// PORTRAIT SELECTION - active after name entry confirmed
// A / D cycles portraits; Enter confirms and goes to hub.
// -----------------------------------------------------------------------------
if (portrait_active) {
    // selected_portrait indexes the CURATED pool (3/class+gender, 08-14); the
    // flat 60-list index is resolved at confirm. Guard for resumed old state.
    if (!variable_instance_exists(id, "portrait_pool") || array_length(portrait_pool) == 0) {
        portrait_pool = portrait_creation_pool(global.chosen_class, global.player_gender);
    }
    var _portrait_count = array_length(portrait_pool);

    if (nav_left())  selected_portrait = wrap_index(selected_portrait - 1, _portrait_count);
    if (nav_right()) selected_portrait = wrap_index(selected_portrait + 1, _portrait_count);

    // Touch (8c): the X chip (simulated Esc) steps back to naming. Touch-gated -
    // the PC keyboard flow (no back from portrait) is unchanged.
    if (input_device() == 2 && input_cancel()) {
        portrait_active = false;
        naming_active   = true;
        exit;
    }

    if (input_confirm() || input_confirm_alt()) {
        global.chosen_portrait = portrait_pool[clamp(selected_portrait, 0, array_length(portrait_pool) - 1)];
        // ORIGIN step (08-11) comes after the portrait, before the Vow.
        portrait_active = false;
        origin_active   = true;
        selected_origin = 0;
        exit;
    }

    exit;
}


// -----------------------------------------------------------------------------
// RPG ORIGIN - background choice (08-11, M design-locked). 4x3 card grid;
// A/D walks, W/S hops rows, Enter commits. Card taps are hit-tested in Draw_64
// (touch rule) and inject origin:pickN / origin:go. Esc steps back to portraits.
// -----------------------------------------------------------------------------
if (origin_active) {
    var _og_n = array_length(origin_catalog());

    if (nav_left())  selected_origin = wrap_index(selected_origin - 1, _og_n);
    if (nav_right()) selected_origin = wrap_index(selected_origin + 1, _og_n);
    if (nav_up())    selected_origin = wrap_index(selected_origin - 4, _og_n);
    if (nav_down())  selected_origin = wrap_index(selected_origin + 4, _og_n);
    for (var _ogi = 0; _ogi < _og_n; _ogi++) {
        if (input_inject_take("origin:pick" + string(_ogi))) selected_origin = _ogi;
    }

    if (input_cancel()) {   // back to portrait choice (all devices)
        origin_active   = false;
        portrait_active = true;
        exit;
    }

    if (input_confirm() || input_confirm_alt() || input_inject_take("origin:go")) {
        global.origin_id = origin_catalog()[selected_origin].id;
        origin_active = false;
        vow_active    = true;
        selected_vow  = 0;
        exit;
    }

    exit;
}


// -----------------------------------------------------------------------------
// THE IRON VOW - mode choice (SYSTEMS_IRON_VOW.md, M-locked 07-28)
// A / D cycles the three cards (Standard default). Enter on Standard proceeds;
// Enter on a Vow opens the CONFIRM/CANCEL popup (its buttons are hit-tested in
// Draw_64 and inject vow:ok / vow:cancel). Esc steps back to portraits.
// -----------------------------------------------------------------------------
if (vow_active) {
    if (vow_confirm_open) {
        if (input_inject_take("vow:ok") || input_confirm() || input_confirm_alt()) {
            vow_confirm_open      = false;
            global.vow_mode       = selected_vow;
            global.vow_lives_left = (selected_vow == 2) ? 1 : 3;
            origin_apply_new_game();   // one-time origin grants land in the first save (08-11)
            save_game();
            confirmed = true;
            room_goto(rm_hub);
        } else if (input_inject_take("vow:cancel") || input_cancel()) {
            vow_confirm_open = false;
        }
        exit;
    }

    if (nav_left())  selected_vow = wrap_index(selected_vow - 1, 3);
    if (nav_right()) selected_vow = wrap_index(selected_vow + 1, 3);
    // Card taps (hit-tested in Draw_64): first tap selects, tap-again confirms.
    if (input_inject_take("vow:pick0")) selected_vow = 0;
    if (input_inject_take("vow:pick1")) selected_vow = 1;
    if (input_inject_take("vow:pick2")) selected_vow = 2;

    if (input_cancel()) {   // back to the origin choice (08-11; was portraits)
        vow_active    = false;
        origin_active = true;
        exit;
    }

    if (input_confirm() || input_confirm_alt() || input_inject_take("vow:go")) {
        if (selected_vow == 0) {
            // Standard Ironwake - no popup, exactly the old flow.
            global.vow_mode       = 0;
            global.vow_lives_left = 0;
            origin_apply_new_game();   // one-time origin grants land in the first save (08-11)
            save_game();
            confirmed = true;
            room_goto(rm_hub);
        } else {
            vow_confirm_open = true;
        }
    }

    exit;
}


// -----------------------------------------------------------------------------
// 1. CLASS SELECTION - Q / E (was A/D; remapped so the stat row owns left/right)
// -----------------------------------------------------------------------------
var _class_changed = false;

if (input_tab_prev()) { selected_class = wrap_index(selected_class - 1, 3); _class_changed = true; }
if (input_tab_next()) { selected_class = wrap_index(selected_class + 1, 3); _class_changed = true; }

if (_class_changed) {
    // Rebuild working stats from the new class preset and reset the free pool
    working_stats            = stats_init(selected_class);
    working_stats.free_points = 4;
    free_points               = 4;
    selected_stat             = 0;
}


// -----------------------------------------------------------------------------
// 1b. GENDER TOGGLE - G flips the chosen class's combat-sprite gender (was Q/E,
// which now cycles class). Cosmetic only; both options shown on the class panel.
// -----------------------------------------------------------------------------
if (input_hotkey("G")) {
    selected_gender = (selected_gender == "m") ? "f" : "m";
}


// -----------------------------------------------------------------------------
// 2. STAT SELECTION - left / right (the 6 stat boxes are a horizontal row)
// -----------------------------------------------------------------------------
if (nav_left())  selected_stat = wrap_index(selected_stat - 1, 6);
if (nav_right()) selected_stat = wrap_index(selected_stat + 1, 6);


// -----------------------------------------------------------------------------
// 3. ALLOCATE POINT - W (hold-repeats), Z, or Enter/Space
// stats_apply_points handles clamping; we read free_points back from the
// struct so the display stays in sync with the actual pool.
// -----------------------------------------------------------------------------
if (nav_up() || input_confirm() || input_confirm_alt() || input_hotkey("Z")) {
    if (free_points > 0) {
        stats_apply_points(working_stats, _stat_names[selected_stat], 1);
        free_points = working_stats.free_points;
    }
}


// -----------------------------------------------------------------------------
// 4. REMOVE POINT - S (hold-repeats) or X
// stats_apply_points prevents the stat from dropping below its class preset
// floor, so no additional guard is needed here.
// -----------------------------------------------------------------------------
if (nav_down() || input_hotkey("X")) {
    stats_apply_points(working_stats, _stat_names[selected_stat], -1);
    free_points = working_stats.free_points;
}


// -----------------------------------------------------------------------------
// 5. CONFIRM - Space
// Opens the name-entry overlay instead of immediately going to rm_hub.
// -----------------------------------------------------------------------------
if ((input_confirm() || input_confirm_alt()) && !confirmed && !naming_active) {
    if (free_points == 0) {
        naming_active   = true;
        keyboard_string = "";
    }
}
