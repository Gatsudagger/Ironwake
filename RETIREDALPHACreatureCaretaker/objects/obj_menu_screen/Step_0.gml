// Toggle menu on Escape
if (keyboard_check_pressed(vk_escape)) {
    visible = !visible;
}
if (!visible) exit;

// Tab switching with Q/E or left/right arrow
if (keyboard_check_pressed(ord("Q")) || keyboard_check_pressed(vk_left)) {
    active_tab = max(0, active_tab - 1);
}
if (keyboard_check_pressed(ord("E")) || keyboard_check_pressed(vk_right)) {
    active_tab = min(4, active_tab + 1);
}

// Save/Quit tab actions
if (active_tab == 4) {
    if (keyboard_check_pressed(ord("S"))) scr_save_game();
    if (keyboard_check_pressed(ord("Q"))) game_end();
}
