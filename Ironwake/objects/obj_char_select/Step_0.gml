// =============================================================================
// obj_char_select — Step event
// Handles all keyboard input for the character selection screen.
// Input map:
//   Left / A         — previous class
//   Right / D        — next class
//   Up / W           — previous stat row
//   Down / S         — next stat row
//   Z / Enter        — add 1 free point to selected stat
//   X                — remove 1 point from selected stat (refunds to pool)
//   Space            — confirm selection and enter combat
// =============================================================================

// Stat name lookup shared by the add and remove sections
var _stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];


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
        confirmed           = true;
        room_goto(rm_hub);
    }

    if (keyboard_check_pressed(vk_escape)) {
        naming_active    = false;
        keyboard_string  = "";
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
if (keyboard_check_pressed(ord("Z")) || keyboard_check_pressed(vk_enter)) {
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
if (keyboard_check_pressed(vk_space) && !confirmed && !naming_active) {
    if (free_points == 0) {
        naming_active   = true;
        keyboard_string = "";
    }
}
