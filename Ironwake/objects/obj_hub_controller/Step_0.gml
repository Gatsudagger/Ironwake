// =============================================================================
// obj_hub_controller - Step event
// Handles all keyboard input on the hub screen.
// Input map:
//   Up / W       - move selection up (or scroll history)
//   Down / S     - move selection down (or scroll history)
//   Space/Enter  - interact with selected NPC (if unlocked)
//   S (past NPC 5) - highlight dungeon button; Enter/Space confirms entry
//   H            - toggle run history overlay
//   T            - open stash screen
//   P            - open permanent stat allocation (if points available)
//   Escape       - dismiss last-run summary or close history
// =============================================================================

// ENDING SEQUENCE (WIN_STATE_SPEC.md) - fully modal; any confirm key advances the
// stage. Stage layout mirrors the Draw block: intro, one per speaker, absence beat
// (only if someone was betrayed), dawn, epilogue, credits, finale.
if (ending_active) {
    if (input_confirm() || input_confirm_alt() || input_cancel()) {
        var _end_total = 1 + array_length(ending_speakers)
                       + ((ending_absent > 0) ? 1 : 0) + 4;   // dawn + epilogue + credits + finale
        ending_stage++;
        if (ending_stage >= _end_total) {
            ending_active = false;
            global.ending_pending = false;
            save_game();
        } else {
            audio_play_sound(snd_page, 1, false);
        }
    }
    exit;
}

// Onboarding coach-mark is modal - freeze the hub entirely while one is up. gc owns
// the dismiss (see SYSTEMS_ONBOARDING.md); here we just block all hub input.
if (tutorial_is_active()) exit;

// Gift picker (Phase 4b): gc drives the modal; the hub freezes while ANY item picker
// is up. The gift RESULT surfaces as the popup (ui_draw_gift_popup), so the one-shot
// resolved flag just gets cleared here.
if (variable_global_exists("item_picker")) {
    if (global.item_picker.resolved_purpose == "gift") global.item_picker.resolved_purpose = "";
    if (global.item_picker.open) exit;
}

// -----------------------------------------------------------------------------
// 0. AUDIO SETTINGS OVERLAY - captures all input while open; O opens it
// -----------------------------------------------------------------------------
if (variable_global_exists("settings_open") && global.settings_open) {
    audio_settings_handle_input();
    exit;
}
var _dsel_open = false;
if (instance_exists(obj_game_controller)) _dsel_open = instance_find(obj_game_controller, 0).dungeon_select_open;
if (input_hotkey("O") && !ui_input_blocked() && !show_history && !_dsel_open) {
    audio_settings_init();
    global.settings_open = true;
    exit;
}

// -----------------------------------------------------------------------------
// 0b. PAUSE / ESC MENU - Resume / Settings / Quit to Title
// pause_menu_step() freezes the hub while the menu (or its Settings sub-screen)
// is open; otherwise Esc opens it when nothing else is up.
// -----------------------------------------------------------------------------
if (pause_menu_step()) exit;
if (input_cancel() && !ui_input_blocked() && !global.ui_overlay_latch
    && !_dsel_open && !show_history && !show_last_run && !show_gallery) {
    pause_menu_open();
    exit;
}

// -----------------------------------------------------------------------------
// 0a. DUNGEON SELECTION OVERLAY - runs before everything else
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_dsel = instance_find(obj_game_controller, 0);
    if (_gc_dsel.dungeon_select_open) {
        var _dungeon_keys = ["ashen_vault", "scorched_depths", "tundra_tomb"];

        // A/D navigate dungeons - wraps cyclically through all 3
        if (nav_left()) {
            _gc_dsel.dungeon_select_cursor = wrap_index(_gc_dsel.dungeon_select_cursor - 1, 3);
            var _dk = _dungeon_keys[_gc_dsel.dungeon_select_cursor];
            var _max_asc = variable_global_exists("dungeon_ascendance_unlocked")
                ? variable_struct_get(global.dungeon_ascendance_unlocked, _dk) : 0;
            _gc_dsel.dungeon_select_asc = min(_gc_dsel.dungeon_select_asc, _max_asc);
        }
        if (nav_right()) {
            _gc_dsel.dungeon_select_cursor = wrap_index(_gc_dsel.dungeon_select_cursor + 1, 3);
            var _dk = _dungeon_keys[_gc_dsel.dungeon_select_cursor];
            var _max_asc = variable_global_exists("dungeon_ascendance_unlocked")
                ? variable_struct_get(global.dungeon_ascendance_unlocked, _dk) : 0;
            _gc_dsel.dungeon_select_asc = min(_gc_dsel.dungeon_select_asc, _max_asc);
        }

        // Q/E change ascendance (capped by unlocked max for this dungeon)
        var _cur_dk   = _dungeon_keys[_gc_dsel.dungeon_select_cursor];
        var _cur_max_asc = variable_global_exists("dungeon_ascendance_unlocked")
            ? variable_struct_get(global.dungeon_ascendance_unlocked, _cur_dk) : 0;
        if (input_tab_prev()) {
            _gc_dsel.dungeon_select_asc = max(0, _gc_dsel.dungeon_select_asc - 1);
        }
        if (input_tab_next()) {
            _gc_dsel.dungeon_select_asc = min(_cur_max_asc, _gc_dsel.dungeon_select_asc + 1);
        }

        // Enter: confirm dungeon + ascendance, open loadout
        if (input_confirm() || input_confirm_alt()) {
            global.selected_dungeon    = _dungeon_keys[_gc_dsel.dungeon_select_cursor];
            global.selected_ascendance = _gc_dsel.dungeon_select_asc;
            _gc_dsel.dungeon_select_open = false;

            // Open loadout (same logic as the Enter Dungeon handler below)
            var _ds_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;
            var _ds_pool;
            _ds_pool = abilities_class_pool(_ds_class);   // class abilities + general pool
            var _loadout_max = trait_active("Expanded Arsenal") ? 5 : 4;
            var _ds_free = abilities_get_loadout(_ds_class);   // the 4 always-unlocked starters
            _gc_dsel.loadout_selected = [];
            for (var _ldi = 0; _ldi < min(_loadout_max, array_length(_ds_free)); _ldi++) {
                array_push(_gc_dsel.loadout_selected, _ds_free[_ldi].name);
            }
            if (variable_global_exists("player_loadout") && global.player_loadout[0] != "") {
                // Only abilities that are both in this class's pool AND unlocked survive.
                var _ds_valid = [];
                for (var _ai = 0; _ai < array_length(_ds_pool); _ai++) {
                    if (ability_is_unlocked(_ds_pool[_ai].name)) array_push(_ds_valid, _ds_pool[_ai].name);
                }
                _gc_dsel.loadout_selected = [];
                for (var _li = 0; _li < _loadout_max; _li++) {
                    var _lname = global.player_loadout[_li];
                    var _ok = false;
                    for (var _vi = 0; _vi < array_length(_ds_valid); _vi++) {
                        if (_ds_valid[_vi] == _lname) { _ok = true; break; }
                    }
                    if (_ok) array_push(_gc_dsel.loadout_selected, _lname);
                }
                if (array_length(_gc_dsel.loadout_selected) < _loadout_max) {
                    _gc_dsel.loadout_selected = [];
                    for (var _ai = 0; _ai < min(_loadout_max, array_length(_ds_free)); _ai++) {
                        array_push(_gc_dsel.loadout_selected, _ds_free[_ai].name);
                    }
                }
            }
            _gc_dsel.loadout_tab   = 0;
            _gc_dsel.traits_cursor = 0;
            _gc_dsel.traits_selected = [];
            if (variable_global_exists("player_traits") && variable_global_exists("traits_unlocked")) {
                for (var _ti = 0; _ti < array_length(global.player_traits); _ti++) {
                    var _tname = global.player_traits[_ti];
                    if (_tname == "") continue;
                    for (var _tri = 0; _tri < array_length(global.traits_all); _tri++) {
                        var _tr_e = global.traits_all[_tri];
                        if (_tr_e.name != _tname) continue;
                        if (_tr_e.class_req != -1 && _tr_e.class_req != _ds_class) break;
                        if (variable_struct_get(global.traits_unlocked, _tr_e.effect_id)) {
                            array_push(_gc_dsel.traits_selected, _tname);
                        }
                        break;
                    }
                }
            }
            _gc_dsel.loadout_open       = true;
            _gc_dsel.ability_detail_open = false;
            _gc_dsel.loadout_cursor     = 0;
            _gc_dsel.loadout_full_timer = 0;
            _gc_dsel.loadout_confirmed  = false;
            // Onboarding: first time the loadout screen opens.
            tutorial_try_show("loadout");
        }

        // Esc: close dungeon select without entering
        if (input_cancel()) {
            _gc_dsel.dungeon_select_open = false;
        }

        exit;
    }
}


// -----------------------------------------------------------------------------
// 0b. LOADOUT OVERLAY - runs BEFORE ui_input_blocked() check
// loadout_open is included in ui_input_blocked() to freeze the rest of the hub,
// but the handler itself must not be blocked by its own flag.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_ld = instance_find(obj_game_controller, 0);

    if (_gc_ld.loadout_open) {
        var _ld_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;
        var _ld_pool  = abilities_class_pool(_ld_class);   // class abilities + general pool
        var _ld_pool_sz  = array_length(_ld_pool);
        var _ld_sel_cnt  = array_length(_gc_ld.loadout_selected);
        // Cap reads the LIVE trait selection (not committed traits) so picking
        // Expanded Arsenal on the Traits tab opens the 5th slot immediately,
        // without having to enter the dungeon and come back.
        var _loadout_max = 4;
        for (var _ea = 0; _ea < array_length(_gc_ld.traits_selected); _ea++) {
            if (_gc_ld.traits_selected[_ea] == "Expanded Arsenal") { _loadout_max = 5; break; }
        }
        // Trim if Expanded Arsenal was just deselected while 5 abilities were picked
        while (array_length(_gc_ld.loadout_selected) > _loadout_max) {
            array_delete(_gc_ld.loadout_selected, array_length(_gc_ld.loadout_selected) - 1, 1);
        }
        _ld_sel_cnt = array_length(_gc_ld.loadout_selected);

        // --- Tab ability-detail popup (P7) ---
        // While the popup is up, only Tab/Esc (close) - swallow all other loadout input.
        if (_gc_ld.ability_detail_open) {
            if (input_detail() || input_cancel()) {
                _gc_ld.ability_detail_open = false;
                exit;
            }
            // Q/E cycle to the prev/next ability in the pool so the in-depth breakdowns
            // can be read sequentially without closing the popup (mirrors W/S list nav).
            if (_ld_pool_sz > 0) {
                if (input_tab_prev()) {
                    _gc_ld.loadout_cursor = wrap_index(_gc_ld.loadout_cursor - 1, _ld_pool_sz);
                    _gc_ld.ability_detail_scroll = 0;
                }
                if (input_tab_next()) {
                    _gc_ld.loadout_cursor = wrap_index(_gc_ld.loadout_cursor + 1, _ld_pool_sz);
                    _gc_ld.ability_detail_scroll = 0;
                }
            }
            // W/S (or Up/Down) scroll the breakdown body when it overflows the panel.
            var _ad_max = global.ui_ability_detail_max_scroll;
            if (nav_down()) _gc_ld.ability_detail_scroll = clamp(_gc_ld.ability_detail_scroll + 48, 0, _ad_max);
            if (nav_up())   _gc_ld.ability_detail_scroll = clamp(_gc_ld.ability_detail_scroll - 48, 0, _ad_max);
            exit;
        }
        // Tab opens the full breakdown for the highlighted ability (Abilities tab, on a row).
        if (input_detail() && _gc_ld.loadout_tab == 0 && _gc_ld.loadout_cursor < _ld_pool_sz) {
            _gc_ld.ability_detail_open   = true;
            _gc_ld.ability_detail_scroll = 0;
            exit;
        }

        // --- Mastery pick modal (expression #2). While open it owns all input. ---
        if (_gc_ld.mastery_pick_open) {
            if (input_cancel()) { _gc_ld.mastery_pick_open = false; exit; }
            if (nav_up() || nav_down()) _gc_ld.mastery_pick_cursor = 1 - _gc_ld.mastery_pick_cursor;
            if (input_confirm()) {
                var _mp_ab = undefined;
                for (var _mpi = 0; _mpi < _ld_pool_sz; _mpi++) {
                    if (_ld_pool[_mpi].name == _gc_ld.mastery_pick_ability) { _mp_ab = _ld_pool[_mpi]; break; }
                }
                if (_mp_ab != undefined) {
                    var _mp_opts = ability_mastery_options(_mp_ab);
                    var _mp_res  = ability_mastery_pick(_mp_ab.name, _mp_opts[_gc_ld.mastery_pick_cursor].id);
                    if (_mp_res == "") {
                        notification = _mp_ab.name + " mastered: " + _mp_opts[_gc_ld.mastery_pick_cursor].label
                            + ((ability_mastery_pending(_mp_ab.name) > 0) ? "   (another notch awaits)" : "");
                        if (room == rm_hub || room == rm_character_select) save_game();
                    } else notification = _mp_res;
                }
                _gc_ld.mastery_pick_open = false;
            }
            exit;
        }
        // M on a pool row with an unspent notch opens the pick modal.
        if (input_hotkey("M") && _gc_ld.loadout_tab == 0 && _gc_ld.loadout_cursor < _ld_pool_sz) {
            var _mn = _ld_pool[_gc_ld.loadout_cursor].name;
            if (ability_mastery_pending(_mn) > 0) {
                _gc_ld.mastery_pick_open    = true;
                _gc_ld.mastery_pick_ability = _mn;
                _gc_ld.mastery_pick_cursor  = 0;
                exit;
            } else {
                notification = _mn + ": " + string(ability_casts(_mn)) + " casts - next notch at "
                    + ((ability_notches_earned(_mn) < 1) ? "25" : ((ability_notches_earned(_mn) < 2) ? "75" : "max (2/2)"));
            }
        }
        // Companion-tab pet-kit detail popup (Tab). While up, only Tab/Esc closes it.
        if (_gc_ld.companion_detail_open) {
            if (input_detail() || input_cancel()) _gc_ld.companion_detail_open = false;
            exit;
        }
        if (input_detail() && _gc_ld.loadout_tab == 2) {
            var _cd_eq = 0;
            for (var _cdi = 0; _cdi < pet_count(); _cdi++) if (!global.pet_roster[_cdi].is_egg) _cd_eq++;
            if (_gc_ld.loadout_cursor < _cd_eq) { _gc_ld.companion_detail_open = true; exit; }
        }

        // Tick flash timers (shared between tabs - "slots full" / "locked ability")
        if (_gc_ld.loadout_full_timer > 0) _gc_ld.loadout_full_timer--;
        if (variable_instance_exists(_gc_ld, "loadout_locked_timer") && _gc_ld.loadout_locked_timer > 0) _gc_ld.loadout_locked_timer--;

        // Q/E cycle the three tabs: Abilities (0) / Traits (1) / Companion (2).
        if (input_tab_next()) { _gc_ld.loadout_tab = (_gc_ld.loadout_tab + 1) mod 3; _gc_ld.loadout_cursor = 0; audio_play_sound(snd_page, 1, false); }
        if (input_tab_prev()) { _gc_ld.loadout_tab = (_gc_ld.loadout_tab + 2) mod 3; _gc_ld.loadout_cursor = 0; audio_play_sound(snd_page, 1, false); }

        if (input_cancel()) {
            _gc_ld.loadout_open = false;
            exit;
        }

        // =====================================================================
        // ABILITIES TAB
        // =====================================================================
        if (_gc_ld.loadout_tab == 0) {
            var _ld_max_cur = _ld_pool_sz - 1 + (_ld_sel_cnt == _loadout_max ? 1 : 0);

            if (nav_up())   _gc_ld.loadout_cursor = wrap_index(_gc_ld.loadout_cursor - 1, _ld_max_cur + 1);
            if (nav_down()) _gc_ld.loadout_cursor = wrap_index(_gc_ld.loadout_cursor + 1, _ld_max_cur + 1);

            // Space or Enter at confirm row: commit and enter dungeon
            if ((input_confirm() || input_confirm_alt())
                && _gc_ld.loadout_cursor == _ld_pool_sz && _ld_sel_cnt == _loadout_max) {
                var _tr_sel_c = _gc_ld.traits_selected;
                // 50g per previously-filled trait slot that is being changed
                var _respec_cost = trait_respec_cost(_tr_sel_c);
                if (_respec_cost > 0 && global.gold < _respec_cost) {
                    notification = "Trait respec costs " + string(_respec_cost) + "g  (need " + string(_respec_cost - global.gold) + "g more)";
                } else {
                    if (_respec_cost > 0) global.gold -= _respec_cost;
                    for (var _li = 0; _li < _loadout_max; _li++) global.player_loadout[_li] = _gc_ld.loadout_selected[_li];
                    if (_loadout_max < 5) global.player_loadout[4] = "";
                    commit_player_traits(_tr_sel_c);
                    _gc_ld.loadout_open      = false;
                    _gc_ld.loadout_confirmed = true;
                    audio_play_sound(snd_confirm_major, 1, false);   // committing to the descent
                    audio_stop_sound(Rainy_Memories);
                    room_goto(rm_dungeon_floor);
                }
            }

            if (input_confirm()) {
                if (_gc_ld.loadout_cursor < _ld_pool_sz) {
                    var _ld_ab_name = _ld_pool[_gc_ld.loadout_cursor].name;
                    var _ld_in_sel  = false;
                    var _ld_sel_i   = -1;
                    for (var _si = 0; _si < _ld_sel_cnt; _si++) {
                        if (_gc_ld.loadout_selected[_si] == _ld_ab_name) {
                            _ld_in_sel = true;
                            _ld_sel_i  = _si;
                            break;
                        }
                    }
                    if (_ld_in_sel) {
                        array_delete(_gc_ld.loadout_selected, _ld_sel_i, 1);
                        _gc_ld.loadout_cursor = min(_gc_ld.loadout_cursor,
                            _ld_pool_sz - 1 + (array_length(_gc_ld.loadout_selected) == _loadout_max ? 1 : 0));
                    } else if (!ability_is_unlocked(_ld_ab_name)) {
                        _gc_ld.loadout_locked_timer = 90;   // must buy it from Vex first
                    } else if (_ld_sel_cnt < _loadout_max) {
                        array_push(_gc_ld.loadout_selected, _ld_ab_name);
                    } else {
                        _gc_ld.loadout_full_timer = 60;
                    }
                }
            }

        // =====================================================================
        // TRAITS TAB
        // =====================================================================
        } else if (_gc_ld.loadout_tab == 1) {
            // Base 2 + bought slots (Vex) + 1 while Crown of the Hollow King is equipped
            var _max_traits = max_trait_slots();
            // Gracefully trim traits_selected if Crown was just unequipped
            while (array_length(_gc_ld.traits_selected) > _max_traits) {
                array_delete(_gc_ld.traits_selected, array_length(_gc_ld.traits_selected) - 1, 1);
            }

            // Build the merged trait list (unlocked first, then locked) - must
            // mirror the Draw_64 traits tab exactly: cursor and mouse share indices.
            var _tr_avail  = [];
            var _tr_locked = [];
            for (var _tri = 0; _tri < array_length(global.traits_all); _tri++) {
                var _tr = global.traits_all[_tri];
                if (_tr.class_req != -1 && _tr.class_req != _ld_class) continue;
                var _unl = variable_struct_get(global.traits_unlocked, _tr.effect_id);
                if (_unl) {
                    array_push(_tr_avail, _tr);
                } else {
                    array_push(_tr_locked, _tr);
                }
            }
            var _tr_all = [];
            for (var _tmi = 0; _tmi < array_length(_tr_avail);  _tmi++) array_push(_tr_all, { tr: _tr_avail[_tmi],  unlocked: true  });
            for (var _tmj = 0; _tmj < array_length(_tr_locked); _tmj++) array_push(_tr_all, { tr: _tr_locked[_tmj], unlocked: false });
            var _tr_cnt     = array_length(_tr_all);
            var _tr_sel_cnt = array_length(_gc_ld.traits_selected);

            if (_tr_cnt > 0) {
                if (nav_up())   _gc_ld.traits_cursor = wrap_index(_gc_ld.traits_cursor - 1, _tr_cnt);
                if (nav_down()) _gc_ld.traits_cursor = wrap_index(_gc_ld.traits_cursor + 1, _tr_cnt);
            }

            // Enter toggles only unlocked rows; a locked row already tells the
            // player it's a Vex purchase, so it just sits inert.
            if ((input_confirm())
                && _tr_cnt > 0 && _tr_all[_gc_ld.traits_cursor].unlocked) {
                var _hov_tr_name = _tr_all[_gc_ld.traits_cursor].tr.name;
                var _tr_in_sel   = false;
                var _tr_sel_idx  = -1;
                for (var _si = 0; _si < _tr_sel_cnt; _si++) {
                    if (_gc_ld.traits_selected[_si] == _hov_tr_name) {
                        _tr_in_sel  = true;
                        _tr_sel_idx = _si;
                        break;
                    }
                }
                if (_tr_in_sel) {
                    array_delete(_gc_ld.traits_selected, _tr_sel_idx, 1);
                } else if (_tr_sel_cnt < _max_traits) {
                    array_push(_gc_ld.traits_selected, _hov_tr_name);
                } else {
                    _gc_ld.loadout_full_timer = 60;
                }
            }

        // =====================================================================
        // COMPANION TAB (equip-only: choose the active pet, or None)
        // =====================================================================
        } else {
            // Equippable pets = non-egg roster entries; rows = those + a final "None".
            var _eq_pets = [];
            for (var _pci = 0; _pci < pet_count(); _pci++) {
                if (!global.pet_roster[_pci].is_egg) array_push(_eq_pets, _pci);
            }
            var _comp_rows = array_length(_eq_pets) + 1;   // pets + the "No companion" row
            if (nav_up())   _gc_ld.loadout_cursor = wrap_index(_gc_ld.loadout_cursor - 1, _comp_rows);
            if (nav_down()) _gc_ld.loadout_cursor = wrap_index(_gc_ld.loadout_cursor + 1, _comp_rows);

            if (input_confirm()) {
                global.active_pet = (_gc_ld.loadout_cursor < array_length(_eq_pets))
                    ? _eq_pets[_gc_ld.loadout_cursor]   // equip the highlighted pet
                    : -1;                                // "None" row
                if (room == rm_hub || room == rm_character_select) save_game();
            }

            // B: cycle the highlighted pet's combat stance (expression #3). No-op for
            // Fortune pets (they have no combat turn) and the "None" row.
            if (input_hotkey("B") && _gc_ld.loadout_cursor < array_length(_eq_pets)) {
                var _st_pet = global.pet_roster[_eq_pets[_gc_ld.loadout_cursor]];
                var _st_new = pet_stance_cycle(_st_pet);
                if (_st_new != "" && (room == rm_hub || room == rm_character_select)) save_game();
            }
        }

        // Touch (8d): drag over the list scrolls it - simulated arrow steps ride
        // the existing edge-scroll logic; pitch matches the active tab's rows.
        // A HORIZONTAL swipe anywhere across the overlay body flips the tab
        // (M 07-08 device test) - simulated Q/E into the existing tab handler.
        if (input_device() == 2) {
            touch_drag_rows(60, 106, 1050, 880, (_gc_ld.loadout_tab == 1) ? 96 : 74);
            touch_swipe_tab(60, 106, 1860, 980);
        }

        // Mouse: loadout tab buttons, ability/trait rows, confirm bar.
        // Touch (8d): rows act on TAP-RELEASE so a drag can never select, and a
        // LONG-PRESS opens the row's detail popup. Desktop mouse keeps press
        // semantics - this branch is byte-identical for device 0/1.
        var _ld_tap = (input_device() == 2) && touch_tap();
        var _ld_lp  = (input_device() == 2) && touch_lp();
        if ((input_device() != 2 && mouse_check_button_pressed(mb_left)) || _ld_tap || _ld_lp) {
            var _ldmx = _ld_tap ? touch_tap_x() : (_ld_lp ? touch_lp_x() : device_mouse_x_to_gui(0));
            var _ldmy = _ld_tap ? touch_tap_y() : (_ld_lp ? touch_lp_y() : device_mouse_y_to_gui(0));

            // Three tab buttons, centred: ABILITIES / TRAITS / COMPANION.
            // Ranges match the Draw_64 tab-bar loop (_tx0=479, width 315, gap 9).
            // Touch (M 07-08: "only registers sometimes"): Draw grows the tabs to
            // 90px on touch, so the hit band grows to the full strip above the
            // list (y 0..105) and the 9px gaps between tabs stop eating taps.
            var _ld_touch  = (input_device() == 2);
            var _ld_tab_y0 = _ld_touch ? 0   : 9;
            var _ld_tab_y1 = _ld_touch ? 105 : 51;
            // Touch bands are contiguous (479/799/1123); desktop keeps the exact
            // original rects so PC mouse behavior is unchanged.
            var _ld_t0_x1  = _ld_touch ? 799  : 794;
            var _ld_t1_x0  = _ld_touch ? 799  : 803;
            var _ld_t1_x1  = _ld_touch ? 1123 : 1118;
            var _ld_t2_x0  = _ld_touch ? 1123 : 1127;
            if (!_ld_lp && _ldmy >= _ld_tab_y0 && _ldmy < _ld_tab_y1) {
                if      (_ldmx >= 479      && _ldmx < _ld_t0_x1) { if (_gc_ld.loadout_tab != 0) audio_play_sound(snd_page, 1, false); _gc_ld.loadout_tab = 0; _gc_ld.loadout_cursor = 0; }
                else if (_ldmx >= _ld_t1_x0 && _ldmx < _ld_t1_x1) { if (_gc_ld.loadout_tab != 1) audio_play_sound(snd_page, 1, false); _gc_ld.loadout_tab = 1; _gc_ld.loadout_cursor = 0; }
                else if (_ldmx >= _ld_t2_x0 && _ldmx < 1442)      { if (_gc_ld.loadout_tab != 2) audio_play_sound(snd_page, 1, false); _gc_ld.loadout_tab = 2; _gc_ld.loadout_cursor = 0; }
            }

            if (_gc_ld.loadout_tab == 0) {
                // Ability rows: x=60-1050, windowed list (matches Draw_64 scroll)
                var _ld_max_vis = 10;
                // Stateful EDGE scrolling (matches Draw_64): the view only moves when
                // the cursor would leave the window, instead of pinning the cursor to
                // the 2nd-from-bottom row mid-list like loadout_list_scroll did.
                var _ld_scroll = variable_instance_exists(_gc_ld, "loadout_scroll") ? _gc_ld.loadout_scroll : 0;
                _ld_scroll = clamp(_ld_scroll, _gc_ld.loadout_cursor - (_ld_max_vis - 1), _gc_ld.loadout_cursor);
                _ld_scroll = clamp(_ld_scroll, 0, max(0, _ld_pool_sz - _ld_max_vis));
                _gc_ld.loadout_scroll = _ld_scroll;
                for (var _ldvis = 0; _ldvis < min(_ld_max_vis, _ld_pool_sz - _ld_scroll); _ldvis++) {
                    var _ldai = _ld_scroll + _ldvis;
                    var _ldry = 106 + _ldvis * 74;   // matches Draw_64 _list_y0
                    if (_ldmx >= 60 && _ldmx < 1050 && _ldmy >= _ldry && _ldmy < _ldry+69) {
                        if (_ld_lp) {   // long-press: open the ability's detail popup
                            _gc_ld.loadout_cursor = _ldai;
                            touch_press(vk_tab);
                            break;
                        }
                        var _ldname = _ld_pool[_ldai].name;
                        var _ldin   = false;
                        var _ldsi   = -1;
                        for (var _ldsck = 0; _ldsck < _ld_sel_cnt; _ldsck++) {
                            if (_gc_ld.loadout_selected[_ldsck] == _ldname) { _ldin = true; _ldsi = _ldsck; break; }
                        }
                        if (_ldin) {
                            array_delete(_gc_ld.loadout_selected, _ldsi, 1);
                        } else if (!ability_is_unlocked(_ldname)) {
                            _gc_ld.loadout_locked_timer = 90;   // must buy it from Vex first
                        } else if (_ld_sel_cnt < _loadout_max) {
                            array_push(_gc_ld.loadout_selected, _ldname);
                        } else {
                            _gc_ld.loadout_full_timer = 60;
                        }
                        _gc_ld.loadout_cursor = _ldai;
                        break;
                    }
                }
                // Confirm bar: x=60-1860, y=998-1043, requires 4 abilities selected
                if (!_ld_lp && _ldmx >= 60 && _ldmx < 1860 && _ldmy >= 998 && _ldmy < 1043 && _ld_sel_cnt == _loadout_max) {
                    var _ltr = _gc_ld.traits_selected;
                    var _mc_cost = trait_respec_cost(_ltr);
                    if (_mc_cost > 0 && global.gold < _mc_cost) {
                        notification = "Trait respec costs " + string(_mc_cost) + "g  (need " + string(_mc_cost - global.gold) + "g more)";
                    } else {
                        if (_mc_cost > 0) global.gold -= _mc_cost;
                        for (var _lci = 0; _lci < _loadout_max; _lci++) global.player_loadout[_lci] = _gc_ld.loadout_selected[_lci];
                        if (_loadout_max < 5) global.player_loadout[4] = "";
                        commit_player_traits(_ltr);
                        _gc_ld.loadout_open      = false;
                        _gc_ld.loadout_confirmed = true;
                        audio_play_sound(snd_confirm_major, 1, false);   // committing to the descent
                        audio_stop_sound(Rainy_Memories);
                        room_goto(rm_dungeon_floor);
                    }
                }
            } else if (_gc_ld.loadout_tab == 1) {
                // Traits tab - merged unlocked+locked rows, windowed (mirrors the
                // Draw_64 list: 106 + 96px pitch, 90px tall, 8 visible, edge scroll).
                var _ldtr_avail  = [];
                var _ldtr_locked = [];
                for (var _ltta = 0; _ltta < array_length(global.traits_all); _ltta++) {
                    var _ltt = global.traits_all[_ltta];
                    if (_ltt.class_req != -1 && _ltt.class_req != _ld_class) continue;
                    if (variable_struct_get(global.traits_unlocked, _ltt.effect_id)) {
                        array_push(_ldtr_avail, _ltt);
                    } else {
                        array_push(_ldtr_locked, _ltt);
                    }
                }
                var _ldtr_all = [];
                for (var _ldm1 = 0; _ldm1 < array_length(_ldtr_avail);  _ldm1++) array_push(_ldtr_all, { tr: _ldtr_avail[_ldm1],  unlocked: true  });
                for (var _ldm2 = 0; _ldm2 < array_length(_ldtr_locked); _ldm2++) array_push(_ldtr_all, { tr: _ldtr_locked[_ldm2], unlocked: false });
                var _ldtr_cnt = array_length(_ldtr_all);
                var _ldtr_max = max_trait_slots();
                var _ldt_max_vis = 8;
                var _ldt_scroll = variable_instance_exists(_gc_ld, "traits_scroll") ? _gc_ld.traits_scroll : 0;
                _ldt_scroll = clamp(_ldt_scroll, _gc_ld.traits_cursor - (_ldt_max_vis - 1), _gc_ld.traits_cursor);
                _ldt_scroll = clamp(_ldt_scroll, 0, max(0, _ldtr_cnt - _ldt_max_vis));
                _gc_ld.traits_scroll = _ldt_scroll;
                for (var _ldtv = 0; _ldtv < min(_ldt_max_vis, _ldtr_cnt - _ldt_scroll); _ldtv++) {
                    var _ldtai = _ldt_scroll + _ldtv;
                    var _ldrty = 106 + _ldtv * 96;
                    if (_ldmx >= 60 && _ldmx < 1050 && _ldmy >= _ldrty && _ldmy < _ldrty+90) {
                        _gc_ld.traits_cursor = _ldtai;
                        if (_ld_lp) break;                        // long-press: cursor only (no Tab popup here)
                        if (!_ldtr_all[_ldtai].unlocked) break;   // locked: cursor only
                        var _ldtrname = _ldtr_all[_ldtai].tr.name;
                        var _ldtrin   = false;
                        var _ldtrsi   = -1;
                        var _ldtrsc   = array_length(_gc_ld.traits_selected);
                        for (var _lts = 0; _lts < _ldtrsc; _lts++) {
                            if (_gc_ld.traits_selected[_lts] == _ldtrname) { _ldtrin = true; _ldtrsi = _lts; break; }
                        }
                        if (_ldtrin) {
                            array_delete(_gc_ld.traits_selected, _ldtrsi, 1);
                        } else if (_ldtrsc < _ldtr_max) {
                            array_push(_gc_ld.traits_selected, _ldtrname);
                        } else {
                            _gc_ld.loadout_full_timer = 60;
                        }
                        break;
                    }
                }
            }
        }

        exit;
    }
}


// Block all hub input while any gc overlay (menu, stash, shop, level alloc) is open.
// Perm alloc is hub-specific and not in ui_input_blocked - handled below.
if (ui_input_blocked()) exit;


// -----------------------------------------------------------------------------
// 0a. HUB-SPECIFIC OVERLAY TOGGLES (perm alloc, stash opener, shop opener)
// These run after ui_input_blocked() so they are skipped when another
// overlay is already active.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_hub = instance_find(obj_game_controller, 0);

    // T: open stash screen (not while perm alloc or gallery is open)
    if (!_gc_hub.perm_alloc_open && !show_gallery && input_hotkey("T")) {
        _gc_hub.stash_mode_open  = true;
        _gc_hub.stash_mode_index = 0;
        _gc_hub.stash_mode_side  = 0;
        _gc_hub.stash_mode_tab   = 0;   // always land on Equipment
        exit;
    }

    // P: open permanent stat allocation (only when points are available)
    if (variable_global_exists("pending_perm_points") && global.pending_perm_points > 0
        && input_hotkey("P")) {
        _gc_hub.perm_alloc_open  = true;
        _gc_hub.perm_alloc_index = 0;
        exit;
    }

    // Perm alloc input - runs when open; blocks everything below.
    // Spending is TWO-STEP (M 07-08: permanent loss deserves a confirm): the first
    // Enter / click-on-selected ARMS the row (perm_alloc_confirm), the second
    // commits. Moving the cursor or Esc disarms without spending.
    if (_gc_hub.perm_alloc_open) {
        if (nav_up())   { _gc_hub.perm_alloc_index = wrap_index(_gc_hub.perm_alloc_index - 1, 6); _gc_hub.perm_alloc_confirm = -1; }
        if (nav_down()) { _gc_hub.perm_alloc_index = wrap_index(_gc_hub.perm_alloc_index + 1, 6); _gc_hub.perm_alloc_confirm = -1; }
        if ((input_confirm()) && global.pending_perm_points > 0) {
            if (_gc_hub.perm_alloc_confirm != _gc_hub.perm_alloc_index) {
                _gc_hub.perm_alloc_confirm = _gc_hub.perm_alloc_index;   // arm - confirm bar shows in Draw
            } else {
                var _perm_stat_keys = ["perm_str_bonus", "perm_dex_bonus", "perm_con_bonus",
                                       "perm_int_bonus", "perm_wis_bonus", "perm_cha_bonus"];
                var _pkey = _perm_stat_keys[_gc_hub.perm_alloc_index];
                variable_global_set(_pkey, variable_global_get(_pkey) + 1);
                global.pending_perm_points--;
                _gc_hub.perm_alloc_confirm = -1;
                if (global.pending_perm_points <= 0) {
                    _gc_hub.perm_alloc_open = false;
                }
            }
        }
        if (input_cancel() || input_back()) {
            if (_gc_hub.perm_alloc_confirm != -1) _gc_hub.perm_alloc_confirm = -1;   // disarm first
            else                                  _gc_hub.perm_alloc_open   = false;
        }
        // Mouse: click a row to select; click the selected row to arm; click the
        // armed row to spend. Clicking anywhere else disarms.
        if (mouse_check_button_pressed(mb_left)) {
            var _pamx = device_mouse_x_to_gui(0);
            var _pamy = device_mouse_y_to_gui(0);
            var _pa_hit = false;
            for (var _pai = 0; _pai < 6; _pai++) {
                var _pay = 255 + _pai * 108;
                if (_pamx >= 510 && _pamx < 1410 && _pamy >= _pay && _pamy < _pay+87) {
                    _pa_hit = true;
                    if (_gc_hub.perm_alloc_index != _pai) {
                        _gc_hub.perm_alloc_index   = _pai;
                        _gc_hub.perm_alloc_confirm = -1;
                    } else if (global.pending_perm_points > 0) {
                        if (_gc_hub.perm_alloc_confirm != _pai) {
                            _gc_hub.perm_alloc_confirm = _pai;   // arm
                        } else {
                            var _pkeys = ["perm_str_bonus","perm_dex_bonus","perm_con_bonus",
                                          "perm_int_bonus","perm_wis_bonus","perm_cha_bonus"];
                            variable_global_set(_pkeys[_pai], variable_global_get(_pkeys[_pai]) + 1);
                            global.pending_perm_points--;
                            _gc_hub.perm_alloc_confirm = -1;
                            if (global.pending_perm_points <= 0) _gc_hub.perm_alloc_open = false;
                        }
                    }
                    break;
                }
            }
            if (!_pa_hit) _gc_hub.perm_alloc_confirm = -1;
        }
        exit;
    }
}


// -----------------------------------------------------------------------------
// 0. RUN HISTORY OVERLAY - intercepts navigation input while open
// -----------------------------------------------------------------------------
if (input_hotkey("H")) {
    show_history   = !show_history;
    history_scroll = 0;
}

if (show_history) {
    if (nav_up())   history_scroll = max(0, history_scroll - 1);
    if (nav_down()) {
        var _max_scroll = max(0, array_length(global.run_history) - 5);
        history_scroll = min(_max_scroll, history_scroll + 1);
    }
    if (input_cancel()) {
        show_history = false;
    }
    exit; // block NPC navigation while viewing history
}


// -----------------------------------------------------------------------------
// 0c. ITEM GALLERY OVERLAY - intercepts input while open. G no longer OPENS it
// from the hub (M 2026-07-06): the Item Codex lives in the Journal now
// (J -> Item Codex -> Enter). G still closes an open gallery for old muscle
// memory; Esc works too.
// -----------------------------------------------------------------------------
var _loadout_is_open_step = instance_exists(obj_game_controller)
    && instance_find(obj_game_controller, 0).loadout_open;
if (!_loadout_is_open_step && input_hotkey("G") && show_gallery) {
    show_gallery        = false;
    gallery_detail_item = undefined;
}

if (show_gallery) {
    // Build master item list (same logic as Draw does - needed for scroll bounds)
    var _gal_all = [];
    if (variable_global_exists("loot_table_common"))    { for (var _gi = 0; _gi < array_length(global.loot_table_common);    _gi++) array_push(_gal_all, global.loot_table_common[_gi]);    }
    if (variable_global_exists("loot_table_uncommon"))  { for (var _gi = 0; _gi < array_length(global.loot_table_uncommon);  _gi++) array_push(_gal_all, global.loot_table_uncommon[_gi]);  }
    if (variable_global_exists("loot_table_rare"))      { for (var _gi = 0; _gi < array_length(global.loot_table_rare);      _gi++) array_push(_gal_all, global.loot_table_rare[_gi]);      }
    if (variable_global_exists("loot_table_legendary")) { for (var _gi = 0; _gi < array_length(global.loot_table_legendary); _gi++) array_push(_gal_all, global.loot_table_legendary[_gi]); }
    var _gal_count    = array_length(_gal_all);
    var _gal_visible  = 12;
    var _gal_max_scroll = max(0, _gal_count - _gal_visible);

    if (nav_up()) {
        if (gallery_cursor > 0) {
            gallery_cursor--;
            if (gallery_cursor < gallery_scroll) gallery_scroll = gallery_cursor;
        }
    }
    if (nav_down()) {
        if (gallery_cursor < _gal_count - 1) {
            gallery_cursor++;
            if (gallery_cursor >= gallery_scroll + _gal_visible) gallery_scroll = gallery_cursor - _gal_visible + 1;
        }
    }
    // Mouse wheel scrolling
    var _wheel = mouse_wheel_up() - mouse_wheel_down();
    if (_wheel != 0) {
        gallery_scroll = clamp(gallery_scroll - _wheel, 0, _gal_max_scroll);
    }

    // Enter/click on a discovered item opens detail
    if ((input_confirm())
        && gallery_cursor >= 0 && gallery_cursor < _gal_count) {
        var _sel = _gal_all[gallery_cursor];
        var _disc = false;
        if (variable_global_exists("items_discovered")) {
            for (var _di = 0; _di < array_length(global.items_discovered); _di++) {
                if (global.items_discovered[_di] == _sel.name) { _disc = true; break; }
            }
        }
        if (_disc) {
            gallery_detail_item = (gallery_detail_item == _sel) ? undefined : _sel;
        }
    }

    // Mouse click on gallery rows
    if (mouse_check_button_pressed(mb_left)) {
        var _gmx = device_mouse_x_to_gui(0);
        var _gmy = device_mouse_y_to_gui(0);
        // List rows: x=30-1095, y=120+i*69, h=63
        for (var _gri = 0; _gri < _gal_visible; _gri++) {
            var _gry = 120 + _gri * 69;
            if (_gmx >= 30 && _gmx < 1095 && _gmy >= _gry && _gmy < _gry + 63) {
                var _abs_i = gallery_scroll + _gri;
                if (_abs_i < _gal_count) {
                    gallery_cursor = _abs_i;
                    var _sel2 = _gal_all[_abs_i];
                    var _disc2 = false;
                    if (variable_global_exists("items_discovered")) {
                        for (var _di2 = 0; _di2 < array_length(global.items_discovered); _di2++) {
                            if (global.items_discovered[_di2] == _sel2.name) { _disc2 = true; break; }
                        }
                    }
                    if (_disc2) {
                        gallery_detail_item = (gallery_detail_item == _sel2) ? undefined : _sel2;
                    } else {
                        gallery_detail_item = undefined;
                    }
                }
                break;
            }
        }
        // Close detail panel X button: x=1853-1883, y=108-138
        if (_gmx >= 1853 && _gmx < 1883 && _gmy >= 108 && _gmy < 138 && gallery_detail_item != undefined) {
            gallery_detail_item = undefined;
        }
    }

    // Alt+click on a discovered gallery row opens the comparison panel
    if (mouse_check_button_pressed(mb_left) && keyboard_check(vk_alt)) {
        var _gax = device_mouse_x_to_gui(0);
        var _gay = device_mouse_y_to_gui(0);
        for (var _gari = 0; _gari < _gal_visible; _gari++) {
            var _gary = 120 + _gari * 69;
            if (_gax >= 30 && _gax < 1095 && _gay >= _gary && _gay < _gary + 63) {
                var _gabs = gallery_scroll + _gari;
                if (_gabs < _gal_count) {
                    var _gcit = _gal_all[_gabs];
                    var _gcdisc = false;
                    if (variable_global_exists("items_discovered")) {
                        for (var _gdi = 0; _gdi < array_length(global.items_discovered); _gdi++) {
                            if (global.items_discovered[_gdi] == _gcit.name) { _gcdisc = true; break; }
                        }
                    }
                    if (_gcdisc && variable_struct_exists(_gcit, "slot")
                            && instance_exists(obj_game_controller)) {
                        var _gcgc = instance_find(obj_game_controller, 0);
                        _gcgc.comparison_item     = _gcit;
                        _gcgc.comparison_equipped = undefined;
                        if (variable_global_exists("inventory")) {
                            var _gcsi = comparison_target_index(_gcit);   // ring-aware target
                            if (_gcsi >= 0 && _gcsi < array_length(global.inventory)) {
                                _gcgc.comparison_equipped = global.inventory[_gcsi];
                            }
                        }
                        _gcgc.comparison_open = true;
                    }
                }
                break;
            }
        }
    }

    if (input_cancel()) {
        if (instance_exists(obj_game_controller)
                && instance_find(obj_game_controller, 0).comparison_open) {
            var _gcesc = instance_find(obj_game_controller, 0);
            _gcesc.comparison_open     = false;
            _gcesc.comparison_item     = undefined;
            _gcesc.comparison_equipped = undefined;
        } else if (gallery_detail_item != undefined) {
            gallery_detail_item = undefined;
        } else {
            show_gallery = false;
        }
    }

    exit; // block NPC navigation while gallery is open
}


// -----------------------------------------------------------------------------
// 1. NPC LIST NAVIGATION
// Clearing the notification on any navigation keypress keeps the UI clean.
// -----------------------------------------------------------------------------
// Positions: one row per NPC (0..N-1) plus the Enter-Dungeon button at index N.
var _npc_slots = array_length(npc_names) + 1;
if (nav_up())   { selected_npc = wrap_index(selected_npc - 1, _npc_slots); notification = ""; }
if (nav_down()) { selected_npc = wrap_index(selected_npc + 1, _npc_slots); notification = ""; }


// -----------------------------------------------------------------------------
// 2. INTERACT WITH SELECTED NPC
// -----------------------------------------------------------------------------
if (input_confirm() || input_confirm_alt()) {
    if (selected_npc < array_length(npc_names) && npc_unlocked[selected_npc]) {
        if (instance_exists(obj_game_controller)) {
            var _gc_interact = instance_find(obj_game_controller, 0);
            if (selected_npc == 0) {
                // Dorn the Blacksmith
                _gc_interact.shop_open         = 1;
                _gc_interact.shop_index        = 0;
                _gc_interact.shop_notification = "";
                _gc_interact.shop_tab          = 0;
                _gc_interact.sell_index        = 0;
                _gc_interact.sell_scroll       = 0;
                _gc_interact.sell_confirm_name = "";
            } else if (selected_npc == 4) {
                // Petra the Merchant
                _gc_interact.shop_open         = 0;
                _gc_interact.shop_index        = 0;
                _gc_interact.shop_notification = "";
                _gc_interact.shop_tab          = 0;
                _gc_interact.sell_index        = 0;
                _gc_interact.sell_scroll       = 0;
                _gc_interact.sell_confirm_name = "";
            } else if (selected_npc == 3) {
                // Vex the Trainer
                _gc_interact.trainer_open         = true;
                _gc_interact.trainer_tab          = 0;
                _gc_interact.trainer_cursor       = 0;
                _gc_interact.trainer_confirm      = false;
                _gc_interact.trainer_notification = "";
                _gc_interact.trainer_statpick_open = false;
                // Onboarding: first time Vex the Trainer opens.
                tutorial_try_show("vex");
            } else if (selected_npc == 2) {
                // Maren the Runesmith
                _gc_interact.maren_open         = true;
                _gc_interact.maren_tab          = 0;
                _gc_interact.maren_phase        = 0;
                _gc_interact.maren_item_sel     = -1;
                _gc_interact.maren_cursor       = 0;
                _gc_interact.maren_notification = "";
            } else if (selected_npc == 1) {
                // Sable the Alchemist
                _gc_interact.sable_open         = true;
                _gc_interact.sable_tab          = 0;
                _gc_interact.sable_phase        = 0;
                _gc_interact.sable_cursor       = 0;
                _gc_interact.sable_notification = "";
            } else if (selected_npc == 5) {
                // Vael the Aesthete
                _gc_interact.vael_open            = true;
                _gc_interact.vael_cursor          = 0;
                _gc_interact.vael_notification    = "";
                _gc_interact.vael_tab             = 0;
                _gc_interact.vael_portrait_cursor = clamp(global.chosen_portrait, 0, array_length(global.portrait_sprites) - 1);
            } else if (selected_npc == 6) {
                // Bairc the Creature Keeper. FIRST talk: he notices the egg you brought stir,
                // hands it over, and his station opens (the hatch tutorial). After that, normal.
                if (!variable_global_exists("pet_starter_given") || !global.pet_starter_given) {
                    pet_grant_starter();
                    global.pet_starter_given        = true;
                    _gc_interact.bairc_intro_open    = true;   // dialogue popup first, then the station
                    _gc_interact.bairc_intro_armed   = false;
                    _gc_interact.bairc_cursor        = 0;
                    if (room == rm_hub || room == rm_character_select) save_game();
                } else if (!bairc_active()) {
                    notification = "Bairc looks at you, unsure, then returns to his garden.   \"......\"";
                } else {
                    _gc_interact.bairc_open         = true;
                    _gc_interact.bairc_cursor       = 0;
                    _gc_interact.bairc_notification = "";
                }
            } else if (selected_npc == 7) {
                // Tavern Requests board (Phase 4b UX): quests are read, accepted and
                // turned in HERE - the Journal only tracks them.
                _gc_interact.tavern_board_open   = true;
                _gc_interact.tavern_board_cursor = 0;
                _gc_interact.tavern_board_note   = "";
            } else {
                notification = npc_names[selected_npc] + ": Coming Soon.";
            }
        }
    } else {
        notification = "This NPC is not yet available.";
    }
}


// -----------------------------------------------------------------------------
// 2b. DEEPEN BOND (4c: routes through the NPC's GATE QUEST). When the selected
// NPC's relationship has reached a gate (affinity_gate_ready), B either crosses
// it (quest already cleared / re-climb) or STARTS the gate quest - the returned
// message is the ask. Auto-gated by the ui_input_blocked() exit above, so it
// never fires while a shop screen is open.
// -----------------------------------------------------------------------------
if (input_hotkey("B") && selected_npc < array_length(affinity_npc_ids()) && !show_history && !show_gallery) {
    var _bond_ids = affinity_npc_ids();
    var _bond_id  = _bond_ids[selected_npc];
    if (affinity_gate_ready(_bond_id)) {
        var _adv = affinity_try_advance(_bond_id);
        if (_adv == "") {
            notification = npc_names[selected_npc] + ": your bond deepens to " + affinity_tier_name(_bond_id) + ".";
        } else {
            notification = _adv;   // gate-quest ask / progress reminder
        }
        if (room == rm_hub || room == rm_character_select) save_game();
    }
}

// (Gifting moved INSIDE each NPC's engagement window - press F there. Quests are
// accepted/turned in at the Tavern Requests board, row 8. Phase 4b UX pass, M.)


// -----------------------------------------------------------------------------
// 3. ENTER DUNGEON - dungeon button must be highlighted (the slot AFTER the last NPC)
// Opens dungeon selection overlay; loadout opens after dungeon is chosen.
// -----------------------------------------------------------------------------
if (!show_gallery && selected_npc == array_length(npc_names)
    && (input_confirm() || input_confirm_alt())) {
    if (instance_exists(obj_game_controller)) {
        var _gc_e = instance_find(obj_game_controller, 0);

        if (_gc_e.loadout_confirmed) {
            audio_stop_sound(Rainy_Memories);
            room_goto(rm_dungeon_floor);
        } else {
            // Open dungeon selection (player picks dungeon + ascendance before loadout)
            var _cur_dk2 = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
            var _dungeon_keys2 = ["ashen_vault", "scorched_depths", "tundra_tomb"];
            _gc_e.dungeon_select_cursor = 0;
            for (var _dki = 0; _dki < array_length(_dungeon_keys2); _dki++) {
                if (_dungeon_keys2[_dki] == _cur_dk2) { _gc_e.dungeon_select_cursor = _dki; break; }
            }
            var _cur_asc2 = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
            var _max_asc2 = variable_global_exists("dungeon_ascendance_unlocked")
                ? variable_struct_get(global.dungeon_ascendance_unlocked, _cur_dk2) : 0;
            _gc_e.dungeon_select_asc  = min(_cur_asc2, _max_asc2);
            _gc_e.dungeon_select_open = true;
            // Onboarding: first time the dungeon/awakening selector opens.
            tutorial_try_show("ascendance");
            exit;
        }

    }
}


// -----------------------------------------------------------------------------
// 4. DISMISS LAST RUN SUMMARY
// -----------------------------------------------------------------------------
if (input_cancel()) {
    if (show_last_run) {
        show_last_run = false;
    }
}


// -----------------------------------------------------------------------------
// 5. MOUSE INPUT - NPC list rows, Enter Dungeon button, last-run dismiss
// -----------------------------------------------------------------------------
if (mouse_check_button_pressed(mb_left)) {
    var _hmx = device_mouse_x_to_gui(0);
    var _hmy = device_mouse_y_to_gui(0);

    // NPC rows: x=630-1290, y=105+i*96, h=81
    for (var _hni = 0; _hni < array_length(npc_names); _hni++) {
        var _hnry = 105 + _hni * 96;
        if (_hmx >= 630 && _hmx < 1290 && _hmy >= _hnry && _hmy < _hnry+81) {
            if (_hni == selected_npc && npc_unlocked[_hni]) {
                // Second click on already-selected unlocked NPC -> interact
                if (instance_exists(obj_game_controller)) {
                    var _gc_mc = instance_find(obj_game_controller, 0);
                    if (_hni == 0) {
                        _gc_mc.shop_open = 1; _gc_mc.shop_index = 0;
                        _gc_mc.shop_notification = ""; _gc_mc.shop_tab = 0;
                        _gc_mc.sell_index = 0; _gc_mc.sell_scroll = 0; _gc_mc.sell_confirm_name = "";
                    } else if (_hni == 4) {
                        _gc_mc.shop_open = 0; _gc_mc.shop_index = 0;
                        _gc_mc.shop_notification = ""; _gc_mc.shop_tab = 0;
                        _gc_mc.sell_index = 0; _gc_mc.sell_scroll = 0; _gc_mc.sell_confirm_name = "";
                    } else if (_hni == 3) {
                        _gc_mc.trainer_open = true; _gc_mc.trainer_tab = 0;
                        _gc_mc.vex_detail_open = false;
                        _gc_mc.trainer_cursor = 0; _gc_mc.trainer_confirm = false;
                        _gc_mc.trainer_notification = "";
                        _gc_mc.trainer_statpick_open = false;
                        tutorial_try_show("vex");   // Onboarding: first Vex open
                    } else if (_hni == 2) {
                        _gc_mc.maren_open = true; _gc_mc.maren_tab = 0;
                        _gc_mc.maren_phase = 0; _gc_mc.maren_item_sel = -1;
                        _gc_mc.maren_cursor = 0; _gc_mc.maren_notification = "";
                    } else if (_hni == 1) {
                        _gc_mc.sable_open = true; _gc_mc.sable_tab = 0;
                        _gc_mc.sable_phase = 0; _gc_mc.sable_cursor = 0;
                        _gc_mc.sable_notification = "";
                    } else if (_hni == 5) {
                        _gc_mc.vael_open = true; _gc_mc.vael_cursor = 0;
                        _gc_mc.vael_notification = "";
                        _gc_mc.vael_tab = 0;
                        _gc_mc.vael_portrait_cursor = clamp(global.chosen_portrait, 0, array_length(global.portrait_sprites) - 1);
                    } else if (_hni == 6) {
                        // Bairc - first talk hands you the starter egg (tutorial), then normal.
                        if (!variable_global_exists("pet_starter_given") || !global.pet_starter_given) {
                            pet_grant_starter();
                            global.pet_starter_given     = true;
                            _gc_mc.bairc_intro_open       = true;   // dialogue popup first, then the station
                            _gc_mc.bairc_intro_armed      = false;
                            _gc_mc.bairc_cursor           = 0;
                            if (room == rm_hub || room == rm_character_select) save_game();
                        } else if (!bairc_active()) {
                            notification = "Bairc looks at you, unsure, then returns to his garden.   \"......\"";
                        } else {
                            _gc_mc.bairc_open = true; _gc_mc.bairc_cursor = 0;
                            _gc_mc.bairc_notification = "";
                        }
                    } else {
                        notification = npc_names[_hni] + ": Coming Soon.";
                    }
                }
            } else {
                selected_npc  = _hni;
                notification  = "";
            }
            break;
        }
    }

    // Enter Dungeon button: x=1320-1890, y=870-990
    if (_hmx >= 1320 && _hmx < 1890 && _hmy >= 870 && _hmy < 990) {
        if (instance_exists(obj_game_controller)) {
            var _gc_e2 = instance_find(obj_game_controller, 0);
            if (_gc_e2.loadout_confirmed) {
                audio_stop_sound(Rainy_Memories);
                room_goto(rm_dungeon_floor);
            } else {
                // Open dungeon selection overlay (mirrors keyboard handler)
                var _cur_dk3 = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
                var _dkeys3 = ["ashen_vault", "scorched_depths", "tundra_tomb"];
                _gc_e2.dungeon_select_cursor = 0;
                for (var _dki3 = 0; _dki3 < array_length(_dkeys3); _dki3++) {
                    if (_dkeys3[_dki3] == _cur_dk3) { _gc_e2.dungeon_select_cursor = _dki3; break; }
                }
                var _cur_asc3 = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
                var _max_asc3 = variable_global_exists("dungeon_ascendance_unlocked")
                    ? variable_struct_get(global.dungeon_ascendance_unlocked, _cur_dk3) : 0;
                _gc_e2.dungeon_select_asc  = min(_cur_asc3, _max_asc3);
                _gc_e2.dungeon_select_open = true;
                // Onboarding: first time the dungeon/awakening selector opens.
                tutorial_try_show("ascendance");
            }
        }
    }

    // Last run summary dismiss
    if (show_last_run && _hmx >= 30 && _hmx < 450 && _hmy >= 420 && _hmy < 642) {
        show_last_run = false;
    }
}
