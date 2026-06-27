// =============================================================================
// obj_title_controller - Step
// =============================================================================

// Audio settings overlay - while open it captures all input.
if (variable_global_exists("settings_open") && global.settings_open) {
    audio_settings_handle_input();
    exit;
}
// Open settings with O once past the intro cutscene.
if (phase != "cutscene" && keyboard_check_pressed(ord("O"))) {
    audio_settings_init();
    global.settings_open = true;
    exit;
}

if (phase == "cutscene") {
    skip_timer++;

    // Any key after the grace period skips straight to the title screen
    if (skip_timer > skip_hold && keyboard_check_pressed(vk_anykey)) {
        phase = "title";
        exit;
    }

    // Fade the whole screen in once at the start
    screen_alpha = min(1.0, screen_alpha + 0.04);

    var _num_panels = array_length(cutscene_panels);

    if (panel_idx < _num_panels) {
        var _panel_str = cutscene_panels[panel_idx];
        var _panel_len = string_length(_panel_str);

        typed_chars = min(_panel_len, typed_chars + type_speed);

        if (typed_chars >= _panel_len) {
            line_pause++;
            if (line_pause >= 30) {
                line_pause  = 0;
                typed_chars = 0.0;
                panel_idx++;
            }
        }
    } else {
        // All lines typed - brief hold then transition to title
        line_pause++;
        if (line_pause >= 80) {
            phase = "title";
        }
    }

} else if (phase == "title") {
    // Fade in title logo, then menu
    title_alpha = min(1.0, title_alpha + 0.018);
    if (title_alpha > 0.6) {
        menu_alpha = min(1.0, menu_alpha + 0.025);
    }
    can_input = (menu_alpha >= 1.0);
    blink     = (blink + 1) mod 60;

    if (can_input) {
        if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
            selected = max(0, selected - 1);
        }
        if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
            selected = min(1, selected + 1);
        }

        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
        ||  keyboard_check_pressed(vk_space)) {
            var _any_save_t = (slot_previews[0] != undefined
                            || slot_previews[1] != undefined
                            || slot_previews[2] != undefined);
            if (selected == 0) {
                slot_mode     = "new_game";
                slot_selected = 0;
                slot_confirm  = false;
                phase         = "slot_picker";
            } else if (selected == 1 && _any_save_t) {
                slot_mode     = "load_game";
                slot_selected = 0;
                slot_confirm  = false;
                phase         = "slot_picker";
            }
        }
    }

} else if (phase == "slot_picker") {

    if (keyboard_check_pressed(vk_escape)) {
        phase        = "title";
        slot_confirm = false;
        exit;
    }

    // Left/right or A/D to change slot
    if (keyboard_check_pressed(vk_left) || keyboard_check_pressed(ord("A"))) {
        slot_selected = max(0, slot_selected - 1);
        slot_confirm  = false;
    }
    if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"))) {
        slot_selected = min(2, slot_selected + 1);
        slot_confirm  = false;
    }

    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
    ||  keyboard_check_pressed(vk_space)) {
        var _preview = slot_previews[slot_selected];

        if (slot_mode == "load_game") {
            if (_preview == undefined) {
                // Empty slot - can't load, do nothing
            } else {
                global.save_slot = slot_selected;
                // Wipe all run/meta globals to defaults FIRST so nothing from a
                // previously-loaded character (e.g. another slot's shop stock, which
                // isn't fully overwritten by load_game) can bleed into this one. Then
                // load this slot's data over the clean slate.
                new_game_reset();
                load_game();
                audio_stop_sound(Viking_March);
                room_goto(rm_hub);
            }

        } else {
            // New Game - occupied slots need one confirmation press
            if (_preview != undefined && !slot_confirm) {
                slot_confirm = true;
            } else {
                global.save_slot = slot_selected;
                // Wipe all persisted run/meta globals to defaults FIRST, so a New
                // Game never inherits a previously-loaded save's gold/run history/
                // inventory/stats (and never writes them into the new slot).
                new_game_reset();
                audio_stop_sound(Viking_March);
                room_goto(rm_character_select);
            }
        }
    }
}
