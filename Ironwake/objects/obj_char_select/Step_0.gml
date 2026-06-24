// =============================================================================
// obj_char_select — Step event
// Handles all keyboard input for the character selection screen.
// Input map:
//   Left / A              — previous class
//   Right / D             — next class
//   Up / W                — previous stat row
//   Down / S              — next stat row
//   Enter / Space         — add 1 free point to selected stat (or confirm when pool empty)
//   X                     — remove 1 point from selected stat (refunds to pool)
//   Mouse click (panel)   — select class
//   Mouse click (stat box)— select stat + add point if pool > 0
// =============================================================================

// Stat name lookup shared by the add and remove sections
var _stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];

// --- Mouse input (GUI space) ---
// Handled early (before naming_active branch) so clicks on panels/boxes register each frame.
if (!naming_active && !confirmed) {
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    if (mouse_check_button_pressed(mb_left)) {
        // Class panels: x0=200, stride=300, w=280, y=120-530
        for (var _ci = 0; _ci < 3; _ci++) {
            var _cpx = 200 + _ci * 300;
            if (_mx >= _cpx && _mx < _cpx+280 && _my >= 120 && _my < 530) {
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
        // Stat boxes: row_x0=375, stride=90, w=80, y=562-614
        var _bx0 = 375;
        var _by0 = 562;
        for (var _si2 = 0; _si2 < 6; _si2++) {
            var _sbx = _bx0 + _si2 * 90;
            if (_mx >= _sbx && _mx < _sbx+80 && _my >= _by0 && _my < _by0+52) {
                selected_stat = _si2;
                if (free_points > 0) {
                    stats_apply_points(working_stats, _stat_names[_si2], 1);
                    free_points = working_stats.free_points;
                }
                break;
            }
        }
        // Confirm: click the bottom instruction bar area when all points are spent
        if (free_points == 0 && _my >= 670 && _my <= 715) {
            naming_active   = true;
            keyboard_string = "";
        }
    }
}


// -----------------------------------------------------------------------------
// NAME ENTRY — active after Space confirms class/stats
// Captures keyboard_string; Enter finalises; Escape cancels back to selection.
// -----------------------------------------------------------------------------
if (naming_active) {
    // Clamp name to 16 characters
    if (string_length(keyboard_string) > 16) {
        keyboard_string = string_copy(keyboard_string, 1, 16);
    }

    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
        var _name = string_trim(keyboard_string);
        if (_name == "") _name = "Hero";
        global.player_name  = _name;
        global.chosen_class = selected_class;
        global.chosen_stats = working_stats;
        global.player_gender = selected_gender;
        naming_active       = false;
        portrait_active     = true;
        selected_portrait   = 0;
        exit;
    }

    if (keyboard_check_pressed(vk_escape)) {
        naming_active    = false;
        keyboard_string  = "";
    }

    exit;
}


// -----------------------------------------------------------------------------
// PORTRAIT SELECTION — active after name entry confirmed
// A / D cycles portraits; Enter confirms and goes to hub.
// -----------------------------------------------------------------------------
if (portrait_active) {
    var _portrait_count = array_length(global.portrait_sprites);

    if (keyboard_check_pressed(vk_left) || keyboard_check_pressed(ord("A"))) {
        selected_portrait = (selected_portrait - 1 + _portrait_count) mod _portrait_count;
    }
    if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"))) {
        selected_portrait = (selected_portrait + 1) mod _portrait_count;
    }

    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
        global.chosen_portrait = selected_portrait;
        save_game();
        confirmed = true;
        room_goto(rm_hub);
    }

    exit;
}


// -----------------------------------------------------------------------------
// 1. CLASS SELECTION — left / right
// -----------------------------------------------------------------------------
var _class_changed = false;

if (keyboard_check_pressed(vk_left) || keyboard_check_pressed(ord("A"))) {
    selected_class = max(0, selected_class - 1);
    _class_changed = true;
}

if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"))) {
    selected_class = min(2, selected_class + 1);
    _class_changed = true;
}

if (_class_changed) {
    // Rebuild working stats from the new class preset and reset the free pool
    working_stats            = stats_init(selected_class);
    working_stats.free_points = 4;
    free_points               = 4;
    selected_stat             = 0;
}


// -----------------------------------------------------------------------------
// 1b. GENDER TOGGLE — Q / E flips the chosen class's combat-sprite gender.
// Cosmetic only; both options shown on the selected class panel.
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(ord("Q")) || keyboard_check_pressed(ord("E"))) {
    selected_gender = (selected_gender == "m") ? "f" : "m";
}


// -----------------------------------------------------------------------------
// 2. STAT ROW SELECTION — up / down
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
    selected_stat = max(0, selected_stat - 1);
}

if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
    selected_stat = min(5, selected_stat + 1);
}


// -----------------------------------------------------------------------------
// 3. ALLOCATE POINT — Z or Enter
// stats_apply_points handles clamping; we read free_points back from the
// struct so the display stays in sync with the actual pool.
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("Z"))) {
    if (free_points > 0) {
        stats_apply_points(working_stats, _stat_names[selected_stat], 1);
        free_points = working_stats.free_points;
    }
}


// -----------------------------------------------------------------------------
// 4. REMOVE POINT — X
// stats_apply_points prevents the stat from dropping below its class preset
// floor, so no additional guard is needed here.
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(ord("X"))) {
    stats_apply_points(working_stats, _stat_names[selected_stat], -1);
    free_points = working_stats.free_points;
}


// -----------------------------------------------------------------------------
// 5. CONFIRM — Space
// Opens the name-entry overlay instead of immediately going to rm_hub.
// -----------------------------------------------------------------------------
if ((keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) && !confirmed && !naming_active) {
    if (free_points == 0) {
        naming_active   = true;
        keyboard_string = "";
    }
}
