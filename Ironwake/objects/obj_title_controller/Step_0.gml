// =============================================================================
// obj_title_controller - Step
// =============================================================================

// Audio settings overlay - while open it captures all input.
if (variable_global_exists("settings_open") && global.settings_open) {
    audio_settings_handle_input();
    exit;
}
// Open settings with O once past the intro cutscene.
if (phase != "cutscene" && input_hotkey("O")) {
    audio_settings_init();
    global.settings_open = true;
    exit;
}

if (phase == "cutscene") {
    skip_timer++;

    // Any key after the grace period skips straight to the title screen
    // (touch, 8c: a tap counts as the any-key)
    if (skip_timer > skip_hold
        && (input_any() || (input_device() == 2 && mouse_check_button_pressed(mb_left)))) {
        phase = "title";
        exit;
    }

    // Fade the whole screen in once at the start
    screen_alpha = min(1.0, screen_alpha + 0.04);

    // Backdrop fades up to a dim 0.5 (readable behind the text) and slow-pans.
    scene_alpha = min(0.5, scene_alpha + 0.01);
    scene_pan   = min(1.0, scene_pan + 0.0016);
    // Dolly creeps forward through the cutscene (foreground trees slowly approach,
    // still fully opaque - the fade-out is saved for the title load below).
    intro_t     = min(0.45, intro_t + 0.0014);

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
    // Backdrop brightens to full and keeps a gentle parallax drift.
    scene_alpha = min(1.0, scene_alpha + 0.012);
    scene_pan   = min(1.0, scene_pan + 0.0008);
    // Dolly accelerates as the title loads - the foreground treeline grows, sinks
    // past the camera and fades out as we arrive at the town.
    intro_t     = min(1.0, intro_t + 0.009);

    // Fade in title logo, then menu
    title_alpha = min(1.0, title_alpha + 0.018);
    if (title_alpha > 0.6) {
        menu_alpha = min(1.0, menu_alpha + 0.025);
    }
    can_input = (menu_alpha >= 1.0);
    blink     = (blink + 1) mod 60;

    if (can_input) {
        if (nav_up())   selected = wrap_index(selected - 1, 4);
        if (nav_down()) selected = wrap_index(selected + 1, 4);

        // Esc at the title = straight into Settings (M 08-13: immediate volume
        // control; Esc had no job on this screen).
        if (input_cancel()) {
            audio_settings_init();
            global.settings_open = true;
            exit;
        }

        // Touch (8c): tap a menu row to highlight it, tap the highlighted row to
        // activate (simulated Enter -> the unchanged handler below). Rows match
        // the Draw layout: y = 585 + i*93, box 660..1260 (+/-33).
        // M 08-13 ("clicking doesn't seem to work on title screen"): the row
        // hit-test was touch-gated - a MOUSE click did nothing on desktop/HTML.
        // Now any click selects; a click on the selected row activates.
        if (mouse_check_button_pressed(mb_left)) {
            var _tmx = device_mouse_x_to_gui(0);
            var _tmy = device_mouse_y_to_gui(0);
            for (var _ti = 0; _ti < 4; _ti++) {
                var _toy = 585 + _ti * 93;
                if (_tmx >= 660 && _tmx <= 1260 && _tmy >= _toy - 33 && _tmy <= _toy + 33) {
                    if (selected == _ti) touch_press(vk_enter);
                    else selected = _ti;
                    break;
                }
            }
        }

        if (input_confirm() || input_confirm_alt()) {
            var _any_save_t = (slot_preview_loadable(slot_previews[0])
                            || slot_preview_loadable(slot_previews[1])
                            || slot_preview_loadable(slot_previews[2]));
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
            } else if (selected == 2) {
                audio_settings_init();
                global.settings_open = true;
                audio_play_sound(snd_page, 1, false);
            } else if (selected == 3) {
                phase = "credits";
                audio_play_sound(snd_page, 1, false);
            }
        }
    }

} else if (phase == "credits") {
    // Asset credits overlay - any dismiss key returns to the title menu.
    if (input_cancel() || input_back() || input_confirm()) {
        phase = "title";
    }

} else if (phase == "slot_picker") {

    if (input_cancel()) {
        phase        = "title";
        slot_confirm = false;
        exit;
    }

    // Left/right or A/D to change slot
    if (nav_left())  { slot_selected = wrap_index(slot_selected - 1, 3); slot_confirm = false; }
    if (nav_right()) { slot_selected = wrap_index(slot_selected + 1, 3); slot_confirm = false; }

    // Touch (8c): tap a slot card to highlight, tap the highlighted card to
    // confirm (simulated Enter keeps the overwrite two-step intact). Cards match
    // the Draw layout: x = 150 + s*555, y 330..660, w 510.
    if (input_device() == 2 && mouse_check_button_pressed(mb_left)) {
        var _smx = device_mouse_x_to_gui(0);
        var _smy = device_mouse_y_to_gui(0);
        for (var _si = 0; _si < 3; _si++) {
            var _scx = 150 + _si * 555;
            if (_smx >= _scx && _smx <= _scx + 510 && _smy >= 330 && _smy <= 660) {
                if (slot_selected == _si) touch_press(vk_enter);
                else { slot_selected = _si; slot_confirm = false; }
                break;
            }
        }
    }

    if (input_confirm() || input_confirm_alt()) {
        var _preview = slot_previews[slot_selected];

        if (slot_mode == "load_game") {
            if (!slot_preview_loadable(_preview)) {
                // Empty slot or a Vow memorial gravestone - can't load, do nothing
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
                // A New Game claiming this slot orphans any interrupted-run
                // checkpoint the OLD character left (SYSTEMS_RUN_RESUME.md) -
                // delete it so the identity guards never even see it. Same for
                // a fallen Vow character's gravestone (SYSTEMS_IRON_VOW.md).
                run_checkpoint_delete();
                vow_memorial_delete(slot_selected);
                audio_stop_sound(Viking_March);
                room_goto(rm_character_select);
            }
        }
    }
}
