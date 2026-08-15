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

// IRONMAN RUN-RESUME (SYSTEMS_RUN_RESUME.md) - FIRST and fully modal: a loaded
// slot with an interrupted run FORCE-resumes into the dungeon. No abandon
// option (M 07-28: declining would grant a mid-floor extract the game never
// offers - quit-outs could bank loot that should be at risk). The hub is
// locked behind the single RESUME button until the dive is re-entered.
if (variable_global_exists("resume_pending") && global.resume_pending) {
    if (input_confirm() || input_confirm_alt() || input_inject_take("resume:go")) {
        global.resume_pending = false;
        run_checkpoint_apply(global.resume_data);
        global.resume_data = undefined;
        audio_play_sound(snd_confirm_major, 1, false);
        music_hub_stop();
        room_goto(rm_dungeon_floor);
    }
    exit;
}

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

// PINCH ZOOM INTRO (SYSTEMS_PINCH_ZOOM.md decision #3) - one-time touch popup,
// fully modal. Resume/ending outrank it (it re-shows next visit if unseen).
// Keyboard/pad path here; the GOT IT tap lives with the button in Draw_64.
if (!variable_instance_exists(id, "zoom_intro_open")) zoom_intro_open = false;
if (zoom_intro_open) {
    if (input_confirm() || input_confirm_alt() || input_cancel()) {
        zoom_intro_open = false;
        ini_open("settings.ini");
        ini_write_real("touch", "zoom_intro_seen", 1);
        ini_close();
        audio_play_sound(snd_page, 1, false);
    }
    exit;
}

// AWAKENING BOOST POPUP (SYSTEMS_ENDLESS.md §1) - a first-time tier clear earned
// a pick: raise ONE other dungeon's awakening by +1. Fully modal on hub arrival;
// the ending sequence outranks it. Card geometry MUST match Draw_64.
if (!variable_instance_exists(id, "awaken_boost_open")) {
    awaken_boost_open       = false;
    awaken_boost_cursor     = 0;
    awaken_boost_done_timer = 0;
    awaken_boost_done_name  = "";
}
if (!awaken_boost_open && variable_global_exists("awaken_boost_pending") && global.awaken_boost_pending
    && (!variable_global_exists("ending_pending") || !global.ending_pending) && !ending_active) {
    if (array_length(awaken_boost_options()) == 0) {
        global.awaken_boost_pending = false;   // both other dungeons already capped
    } else {
        awaken_boost_open   = true;
        awaken_boost_cursor = 0;
        audio_play_sound(snd_sting_levelup, 1, false);
    }
}
if (awaken_boost_open) {
    var _ab_opts = awaken_boost_options();
    if (array_length(_ab_opts) == 0) { awaken_boost_open = false; global.awaken_boost_pending = false; exit; }
    if (nav_up()   || input_dir_left())  awaken_boost_cursor = wrap_index(awaken_boost_cursor - 1, array_length(_ab_opts));
    if (nav_down() || input_dir_right()) awaken_boost_cursor = wrap_index(awaken_boost_cursor + 1, array_length(_ab_opts));
    var _ab_go = input_confirm() || input_confirm_alt();
    if (mouse_check_button_pressed(mb_left)) {
        var _abmx = device_mouse_x_to_gui(0), _abmy = device_mouse_y_to_gui(0);
        for (var _abi = 0; _abi < array_length(_ab_opts); _abi++) {
            var _abx = 960 + (_abi - (array_length(_ab_opts) - 1) / 2) * 460 - 210;
            if (_abmx >= _abx && _abmx < _abx + 420 && _abmy >= 420 && _abmy < 700) {
                if (awaken_boost_cursor == _abi) _ab_go = true;   // second tap confirms
                else awaken_boost_cursor = _abi;
                break;
            }
        }
    }
    if (_ab_go && awaken_boost_cursor < array_length(_ab_opts)) {
        var _ab_pick = _ab_opts[awaken_boost_cursor];
        variable_struct_set(global.dungeon_ascendance_unlocked, _ab_pick.key, _ab_pick.cur + 1);
        global.awaken_boost_pending = false;
        global.awaken_boost_from    = "";
        awaken_boost_open       = false;
        awaken_boost_done_timer = 165;
        awaken_boost_done_name  = _ab_pick.name + " rises to Awakening " + string(_ab_pick.cur + 1) + "!";
        audio_play_sound(snd_confirm_major, 1, false);
        save_game();
    }
    exit;   // modal - nothing else on the hub moves while the choice is up
}

// Onboarding coach-mark is modal - freeze the hub entirely while one is up. gc owns
// the dismiss (see SYSTEMS_ONBOARDING.md); here we just block all hub input.
if (tutorial_is_active()) exit;

// C7 (M-approved 07-09): the first time ANY townsfolk reaches a friendship gate,
// explain the gate-quest system once. Poll pattern mirrors the escape_item tip.
if (!tutorial_seen_has("bond_gates")) {
    var _bg_ids = ["petra", "dorn", "vex", "maren", "sable", "bairc"];
    for (var _bgi = 0; _bgi < array_length(_bg_ids); _bgi++) {
        if (affinity_gate_ready(_bg_ids[_bgi])) { tutorial_try_show("bond_gates"); break; }
    }
}
// C7: the first corrupt creature in the roster (hatched or found) explains the
// corruption bargain once - cost, permanence, cure vs fulfilled.
if (!tutorial_seen_has("corruption_101")) {
    var _cr = pet_roster();
    for (var _cri = 0; _cri < array_length(_cr); _cri++) {
        var _crp = _cr[_cri];
        if (!is_struct(_crp) || _crp.is_egg) continue;
        var _crs = pet_corr_state(_crp);
        if (_crs == "pushing" || _crs == "fulfilled" || _crs == "cured") { tutorial_try_show("corruption_101"); break; }
    }
}
// The hidden surprise (M-locked 08-15): the first FULLY corrupted pet reveals
// the betrayal chance - a tutorial that only ever fires after the fact.
if (!tutorial_seen_has("corruption_fulfilled")) {
    var _cf = pet_roster();
    for (var _cfi = 0; _cfi < array_length(_cf); _cfi++) {
        var _cfp = _cf[_cfi];
        if (!is_struct(_cfp) || _cfp.is_egg) continue;
        if (pet_corr_state(_cfp) == "fulfilled") { tutorial_try_show("corruption_fulfilled"); break; }
    }
}
// NPC PROGRESSION (M 08-15): explain STATION RANKS once - on the first camp
// arrival after a run (the hub tip has had its turn), while the carousel with
// its STATION chips is what's on screen.
if (!tutorial_seen_has("station_ranks") && tutorial_seen_has("hub")
    && global.run_count >= 1 && !ui_input_blocked()) {
    tutorial_try_show("station_ranks");
}

// Gift picker (Phase 4b): gc drives the modal; the hub freezes while ANY item picker
// is up. The gift RESULT surfaces as the popup (ui_draw_gift_popup), so the one-shot
// resolved flag just gets cleared here.
if (variable_global_exists("item_picker")) {
    if (global.item_picker.resolved_purpose == "gift") global.item_picker.resolved_purpose = "";
    if (global.item_picker.open) exit;
}
// Cursed-rebirth reagent stage (M 08-05): same freeze - gc steps the modal.
if (variable_global_exists("reagent_picker") && global.reagent_picker != undefined) exit;

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
// 0a2. BOND DIALOGUE window (M 07-28): modal - any confirm/cancel/tap closes.
// Runs BEFORE the pause block so Esc closes the dialogue, not opens the menu.
// -----------------------------------------------------------------------------
if (bond_dialog_open) {
    if (input_confirm() || input_confirm_alt() || input_cancel()
        || mouse_check_button_pressed(mb_left)) {
        bond_dialog_open = false;
    }
    exit;
}

// -----------------------------------------------------------------------------
// 0a3. UPGRADE STATION checkout (NPC PROGRESSION, M 08-15): armed by [U] / the
// STATION chip tap in 2c below; the popup (ui_draw_checkout_confirm in Draw) is
// MODAL per the standing checkout rule - CONFIRM spends, CANCEL/Esc backs out,
// nothing else reaches the hub while it's up. Result lands in the bond dialog.
// -----------------------------------------------------------------------------
if (!variable_instance_exists(id, "npc_upgrade_arm")) npc_upgrade_arm = "";
if (npc_upgrade_arm != "") {
    if (input_cancel() || input_inject_take("npcup:cancel")) { npc_upgrade_arm = ""; exit; }
    if (input_confirm() || input_inject_take("npcup:ok")) {
        var _up_id = npc_upgrade_arm;
        npc_upgrade_arm = "";
        var _up_ids = affinity_npc_ids();
        var _up_ix  = selected_npc;
        for (var _up_i = 0; _up_i < array_length(_up_ids); _up_i++) if (_up_ids[_up_i] == _up_id) _up_ix = _up_i;
        var _up_err = npc_rank_buy(_up_id);
        bond_dialog_open   = true;
        bond_dialog_npc    = _up_id;
        bond_dialog_hearts = [];
        if (_up_err == "") {
            bond_dialog_title = npc_names[_up_ix] + "  -  Station Rank " + string(npc_rank(_up_id));
            bond_dialog_body  = "The work is done by morning.\n\nUNLOCKED: "
                + npc_rank_perk_text(_up_id, npc_rank(_up_id));
            audio_play_sound(snd_forge, 1, false);
        } else {
            bond_dialog_title = npc_names[_up_ix];
            bond_dialog_body  = _up_err;
        }
    }
    exit;
}

// -----------------------------------------------------------------------------
// 0b. PAUSE / ESC MENU - Resume / Settings / Quit to Title
// pause_menu_step() freezes the hub while the menu (or its Settings sub-screen)
// is open; otherwise Esc opens it when nothing else is up.
// -----------------------------------------------------------------------------
if (pause_menu_step()) exit;
if (input_cancel() && !ui_input_blocked() && !global.ui_overlay_latch
    && !_dsel_open && !show_history && !show_last_run) {
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
            _gc_dsel.dungeon_select_asc = min(_gc_dsel.dungeon_select_asc, dungeon_max_ascendance(_dk));
        }
        if (nav_right()) {
            _gc_dsel.dungeon_select_cursor = wrap_index(_gc_dsel.dungeon_select_cursor + 1, 3);
            var _dk = _dungeon_keys[_gc_dsel.dungeon_select_cursor];
            _gc_dsel.dungeon_select_asc = min(_gc_dsel.dungeon_select_asc, dungeon_max_ascendance(_dk));
        }

        // Q/E change ascendance (capped by unlocked max for this dungeon; post-win
        // the shared A6+ endless frontier applies - dungeon_max_ascendance).
        var _cur_dk   = _dungeon_keys[_gc_dsel.dungeon_select_cursor];
        var _cur_max_asc = dungeon_max_ascendance(_cur_dk);
        if (input_tab_prev()) {
            _gc_dsel.dungeon_select_asc = max(0, _gc_dsel.dungeon_select_asc - 1);
        }
        if (input_tab_next()) {
            _gc_dsel.dungeon_select_asc = min(_cur_max_asc, _gc_dsel.dungeon_select_asc + 1);
        }

        // THE DESCENT toggle (SYSTEMS_ENDLESS.md §3) - post-win only. [V] arms
        // descent mode, [G] cycles the hardcore severity while armed; the banner
        // at (330,972)-(1250,1050) / severity chip (1270,972)-(1590,1050) is
        // tappable (geometry MUST match the hub Draw_64 banner).
        if (variable_global_exists("ironwake_stands") && global.ironwake_stands) {
            if (!variable_global_exists("descent_pending"))  global.descent_pending  = false;
            if (!variable_global_exists("descent_hardcore")) global.descent_hardcore = 0;
            var _dsc_tap = false, _dsc_hc_tap = false;
            if (mouse_check_button_pressed(mb_left)) {
                var _dmx = device_mouse_x_to_gui(0), _dmy = device_mouse_y_to_gui(0);
                _dsc_tap    = (_dmx >= 330  && _dmx < 1250 && _dmy >= 972 && _dmy < 1050);
                _dsc_hc_tap = (_dmx >= 1270 && _dmx < 1590 && _dmy >= 972 && _dmy < 1050);
            }
            if (input_hotkey("V") || _dsc_tap) {
                global.descent_pending = !global.descent_pending;
                audio_play_sound(snd_npc_confirm, 1, false);
            }
            if ((input_hotkey("G") || _dsc_hc_tap) && global.descent_pending) {
                global.descent_hardcore = (global.descent_hardcore + 1) mod 3;
                audio_play_sound(snd_npc_confirm, 1, false);
            }
        }

        // Enter: confirm dungeon + ascendance, open loadout
        if (input_confirm() || input_confirm_alt()) {
            global.selected_dungeon    = _dungeon_keys[_gc_dsel.dungeon_select_cursor];
            global.selected_ascendance = _gc_dsel.dungeon_select_asc;
            // THE DESCENT overrides the choice: random first theme, floor-1 tier.
            if (variable_global_exists("descent_pending") && global.descent_pending
                && variable_global_exists("ironwake_stands") && global.ironwake_stands) {
                global.descent_pending     = false;   // one-shot arm
                global.descent_active      = true;
                global.descent_floor       = 1;
                global.selected_dungeon    = _dungeon_keys[irandom(2)];
                global.selected_ascendance = 5.5;     // floor 1 = A5 + 0.5
            } else {
                global.descent_active = false;
            }
            _gc_dsel.dungeon_select_open = false;

            // Open loadout (same logic as the Enter Dungeon handler below)
            var _ds_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;
            var _ds_pool;
            _ds_pool = abilities_class_pool(_ds_class);   // class abilities + general pool
            var _loadout_max = trait_active("Expanded Arsenal") ? 6 : 5;   // class pass 08-13: base 5, EA 6th
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
                // Bounded by the SAVED array's real length (class pass 08-13:
                // the cap grew to 5/6, but pre-existing saves hold 5 slots -
                // reading to the cap crashed with index [5] out of range [5]).
                var _ls_n     = min(_loadout_max, array_length(global.player_loadout));
                var _ls_saved = 0;
                for (var _li = 0; _li < _ls_n; _li++) {
                    var _lname = global.player_loadout[_li];
                    if (_lname != "") _ls_saved++;
                    var _ok = false;
                    for (var _vi = 0; _vi < array_length(_ds_valid); _vi++) {
                        if (_ds_valid[_vi] == _lname) { _ok = true; break; }
                    }
                    if (_ok) array_push(_gc_dsel.loadout_selected, _lname);
                }
                // Fall back to the starters only when saved entries were LOST
                // (invalid/locked), not merely because the cap outgrew the save.
                if (_ls_saved == 0 || array_length(_gc_dsel.loadout_selected) < _ls_saved) {
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
        var _loadout_max = 5;   // class pass 08-13: base 5, EA 6th
        for (var _ea = 0; _ea < array_length(_gc_ld.traits_selected); _ea++) {
            if (_gc_ld.traits_selected[_ea] == "Expanded Arsenal") { _loadout_max = 6; break; }
        }
        // Trim if Expanded Arsenal was just deselected while 6 abilities were picked
        while (array_length(_gc_ld.loadout_selected) > _loadout_max) {
            array_delete(_gc_ld.loadout_selected, array_length(_gc_ld.loadout_selected) - 1, 1);
        }
        _ld_sel_cnt = array_length(_gc_ld.loadout_selected);

        // REQUIRED count (class pass 08-13): the base cap grew to 5, but a
        // fresh character owns only the 4 starters - the dungeon can never
        // demand more slots than the abilities you actually own.
        var _ld_owned = 0;
        for (var _lu = 0; _lu < _ld_pool_sz; _lu++)
            if (ability_is_unlocked(_ld_pool[_lu].name)) _ld_owned++;
        var _loadout_req = min(_loadout_max, max(4, _ld_owned));

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

        // --- Talent-web view (SYSTEMS_TALENT_WEBS.md). While open it owns all
        //     input. W/S walk 6 nodes then SAVE & CLOSE then CLOSE (full
        //     keyboard/pad parity - M 07-27), A/D hop branch (or between the
        //     two buttons), Enter STAGES/unstages a node or fires a button.
        //     Staged picks only become permanent on SAVE & CLOSE; CLOSE/Esc
        //     discards them. Touch taps are hit-tested in Draw_64. ---
        if (_gc_ld.web_view_open) {
            // Talent tour owns all input while it runs (gc Step advances it).
            if (variable_instance_exists(_gc_ld, "talent_tour_step") && _gc_ld.talent_tour_step >= 0) exit;
            if (input_cancel()) {
                if (array_length(_gc_ld.web_view_staged) > 0) notification = "Unsaved weaves discarded.";
                _gc_ld.web_view_open = false;
                exit;
            }
            var _wv_ab = undefined;
            for (var _wvi = 0; _wvi < _ld_pool_sz; _wvi++) {
                if (_ld_pool[_wvi].name == _gc_ld.web_view_ability) { _wv_ab = _ld_pool[_wvi]; break; }
            }
            if (_wv_ab == undefined) { _gc_ld.web_view_open = false; exit; }
            if (nav_down()) _gc_ld.web_view_cursor = wrap_index(_gc_ld.web_view_cursor + 1, 8);
            if (nav_up())   _gc_ld.web_view_cursor = wrap_index(_gc_ld.web_view_cursor - 1, 8);
            if (nav_left() || nav_right()) {
                if (_gc_ld.web_view_cursor < 6) _gc_ld.web_view_cursor = wrap_index(_gc_ld.web_view_cursor + 3, 6);
                else _gc_ld.web_view_cursor = (_gc_ld.web_view_cursor == 6) ? 7 : 6;
            }
            if (input_confirm()) {
                if (_gc_ld.web_view_cursor == 6) {
                    // SAVE & CLOSE - commit every staged node.
                    var _wv_stn = array_length(_gc_ld.web_view_staged);
                    if (_wv_stn > 0) {
                        var _wv_cres = ability_web_commit_staged(_wv_ab.name, _gc_ld.web_view_staged);
                        if (_wv_cres == "") {
                            notification = _wv_ab.name + ": " + string(_wv_stn) + " node" + ((_wv_stn == 1) ? "" : "s") + " woven (permanent).";
                            if (room == rm_hub || room == rm_character_select) save_game();
                        } else notification = _wv_cres;
                    }
                    _gc_ld.web_view_open = false;
                } else if (_gc_ld.web_view_cursor == 7) {
                    // CLOSE - back out, nothing committed.
                    if (array_length(_gc_ld.web_view_staged) > 0) notification = "Unsaved weaves discarded.";
                    _gc_ld.web_view_open = false;
                } else {
                    var _wv_order = ["p1", "p2", "pk", "t1", "t2", "tk"];
                    var _wv_id    = _wv_order[_gc_ld.web_view_cursor];
                    var _wv_res   = ability_web_stage_toggle(_wv_ab.name, _wv_id, _gc_ld.web_view_staged);
                    if (_wv_res != "") notification = _wv_res;
                }
            }
            exit;
        }
        // M on a pool row opens its talent web (always - progress is visible
        // even with nothing to spend).
        if (input_hotkey("M") && _gc_ld.loadout_tab == 0 && _gc_ld.loadout_cursor < _ld_pool_sz) {
            _gc_ld.web_view_open    = true;
            _gc_ld.web_view_ability = _ld_pool[_gc_ld.loadout_cursor].name;
            _gc_ld.web_view_cursor  = 0;
            _gc_ld.web_view_staged  = [];
            exit;
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
        if (variable_instance_exists(_gc_ld, "loadout_gold_timer") && _gc_ld.loadout_gold_timer > 0) _gc_ld.loadout_gold_timer--;

        // Q/E cycle the three tabs: Abilities (0) / Traits (1) / Companion (2).
        // Tabs swap on Q/E AND on left/right (the d-pad / arrows / A-D) - the loadout
        // has no other use for horizontal nav, so left=right maps to the tab swap
        // (M 07-17: on-screen d-pad left/right did nothing here).
        if (input_tab_next() || nav_right()) { _gc_ld.loadout_tab = (_gc_ld.loadout_tab + 1) mod 3; _gc_ld.loadout_cursor = 0; audio_play_sound(snd_page, 1, false); }
        if (input_tab_prev() || nav_left())  { _gc_ld.loadout_tab = (_gc_ld.loadout_tab + 2) mod 3; _gc_ld.loadout_cursor = 0; audio_play_sound(snd_page, 1, false); }

        if (input_cancel()) {
            _gc_ld.loadout_open = false;
            exit;
        }

        // =====================================================================
        // ABILITIES TAB
        // =====================================================================
        if (_gc_ld.loadout_tab == 0) {
            var _ld_max_cur = _ld_pool_sz - 1 + (_ld_sel_cnt >= _loadout_req ? 1 : 0);

            if (nav_up())   _gc_ld.loadout_cursor = wrap_index(_gc_ld.loadout_cursor - 1, _ld_max_cur + 1);
            if (nav_down()) _gc_ld.loadout_cursor = wrap_index(_gc_ld.loadout_cursor + 1, _ld_max_cur + 1);
            // Mouse wheel walks the same cursor (edge-scroll follows it); clamped,
            // not wrapped - wheeling past the end of a list shouldn't teleport. M 07-30.
            var _ldw = mouse_wheel_down() - mouse_wheel_up();
            if (_ldw != 0) _gc_ld.loadout_cursor = clamp(_gc_ld.loadout_cursor + _ldw, 0, _ld_max_cur);

            // Space or Enter at confirm row: commit and enter dungeon
            if ((input_confirm() || input_confirm_alt())
                && _gc_ld.loadout_cursor == _ld_pool_sz && _ld_sel_cnt >= _loadout_req) {
                var _tr_sel_c = _gc_ld.traits_selected;
                // 50g per previously-filled trait slot that is being changed
                var _respec_cost = trait_respec_cost(_tr_sel_c);
                if (_respec_cost > 0 && global.gold < _respec_cost) {
                    // #6: flash the shortfall INSIDE the loadout overlay - the hub
                    // `notification` line is hidden behind it (read as silent fail).
                    _gc_ld.loadout_gold_msg   = "Trait respec costs " + string(_respec_cost) + "g - you're " + string(_respec_cost - global.gold) + "g short.";
                    _gc_ld.loadout_gold_timer = 150;
                } else {
                    if (_respec_cost > 0) global.gold -= _respec_cost;
                    // Write what was actually selected (may be fewer than the
                    // cap), then blank every remaining saved slot so stale
                    // names can't ride along (GML arrays grow on write).
                    for (var _li = 0; _li < array_length(_gc_ld.loadout_selected); _li++) global.player_loadout[_li] = _gc_ld.loadout_selected[_li];
                    for (var _lb = array_length(_gc_ld.loadout_selected); _lb < max(6, array_length(global.player_loadout)); _lb++) global.player_loadout[_lb] = "";
                    commit_player_traits(_tr_sel_c);
                    _gc_ld.loadout_open      = false;
                    _gc_ld.loadout_confirmed = true;
                    audio_play_sound(snd_confirm_major, 1, false);   // committing to the descent
                    music_hub_stop();   // stops the default AND any banshee-jukebox hub track
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
                            _ld_pool_sz - 1 + (array_length(_gc_ld.loadout_selected) >= _loadout_req ? 1 : 0));
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
                if (_tr.unlock_type == "duelist" && !trait_is_unlocked(_tr.name)) continue;   // hidden until earned
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
                if (!_ld_lp && _ldmx >= 60 && _ldmx < 1860 && _ldmy >= 998 && _ldmy < 1043 && _ld_sel_cnt >= _loadout_req) {
                    var _ltr = _gc_ld.traits_selected;
                    var _mc_cost = trait_respec_cost(_ltr);
                    if (_mc_cost > 0 && global.gold < _mc_cost) {
                        // #6: same in-overlay flash as the keyboard confirm path.
                        _gc_ld.loadout_gold_msg   = "Trait respec costs " + string(_mc_cost) + "g - you're " + string(_mc_cost - global.gold) + "g short.";
                        _gc_ld.loadout_gold_timer = 150;
                    } else {
                        if (_mc_cost > 0) global.gold -= _mc_cost;
                        for (var _lci = 0; _lci < array_length(_gc_ld.loadout_selected); _lci++) global.player_loadout[_lci] = _gc_ld.loadout_selected[_lci];
                        for (var _lcb = array_length(_gc_ld.loadout_selected); _lcb < max(6, array_length(global.player_loadout)); _lcb++) global.player_loadout[_lcb] = "";
                        commit_player_traits(_ltr);
                        _gc_ld.loadout_open      = false;
                        _gc_ld.loadout_confirmed = true;
                        audio_play_sound(snd_confirm_major, 1, false);   // committing to the descent
                        music_hub_stop();   // stops the default AND any banshee-jukebox hub track
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
                    if (_ltt.unlock_type == "duelist" && !trait_is_unlocked(_ltt.name)) continue;   // hidden until earned
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
    if (!_gc_hub.perm_alloc_open && input_hotkey("T")) {
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
// 0c. ITEM GALLERY - moved to obj_game_controller 07-28 (codex_* vars) so the
// codex opens mid-run too. While it is open, ui_input_blocked() reports true
// and everything below is frozen by the guards that already consult it.
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// 1. NPC NAVIGATION
// Clearing the notification on any navigation keypress keeps the UI clean.
// selected_npc keeps its exact legacy meaning in BOTH layouts (0..N-1 = NPC,
// N = the Enter Dungeon button) so every handler below - and the right-hand
// detail/portrait panels - work unchanged.
// -----------------------------------------------------------------------------
var _npc_slots = array_length(npc_names) + 1;
if (hub_use_carousel) {
    // CAROUSEL (SYSTEMS_HUB_CAROUSEL.md): left/right rotate the stage with the
    // global hold-repeat nav (wrap-around); up/down hop focus to the persistent
    // DUNGEON GATE button and back. A horizontal swipe on the stage arrives as
    // Q/E via touch_swipe_tab - handled with input_tab_* so pad shoulders
    // rotate too. The stage/arrow/chip TAPS live in Draw_64 with their rects
    // and fire these same keys (touch_press), so this is the only dispatch.
    var _cn = array_length(npc_names);
    if (selected_npc < _cn) {
        carousel_last = selected_npc;   // keep the stage memory in sync
        if (nav_left())  { selected_npc = wrap_index(selected_npc - 1, _cn); notification = ""; }
        if (nav_right()) { selected_npc = wrap_index(selected_npc + 1, _cn); notification = ""; }
        if (input_tab_next())      { selected_npc = wrap_index(selected_npc + 1, _cn); notification = ""; }
        else if (input_tab_prev()) { selected_npc = wrap_index(selected_npc - 1, _cn); notification = ""; }
        carousel_last = selected_npc;
        if (nav_up() || nav_down()) { selected_npc = _cn; notification = ""; }   // focus the gate
    } else {
        // Gate focused: any direction returns to the carousel where you left it.
        if (nav_up() || nav_down() || nav_left() || nav_right()) {
            selected_npc = carousel_last;
            notification = "";
        }
    }
} else {
    // LEGACY stacked list (settings.ini [ui] hub_carousel=0 reversion).
    if (nav_up())   { selected_npc = wrap_index(selected_npc - 1, _npc_slots); notification = ""; }
    if (nav_down()) { selected_npc = wrap_index(selected_npc + 1, _npc_slots); notification = ""; }
}


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
                // Drill Regimen (Vex rank 2, M-locked 08-15): the first purchase
                // each VISIT is 25% off - armed on every open.
                global.vex_visit_first = (npc_rank("vex") >= 2);
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
if (input_hotkey("B") && selected_npc < array_length(affinity_npc_ids()) && !show_history) {
    var _bond_ids = affinity_npc_ids();
    var _bond_id  = _bond_ids[selected_npc];
    if (affinity_gate_ready(_bond_id)) {
        var _adv = affinity_try_advance(_bond_id);
        // M 07-28 rework: the whole exchange happens in ONE bordered dialogue
        // window at the NPC - the ask, the progress reminder, and the crossing
        // (a FINISHED favor now turns in right here; no tavern-board trip).
        bond_dialog_open = true;
        bond_dialog_npc  = _bond_id;
        if (_adv == "") {
            // Friendly lore beat + heart burst on the crossing (M 08-15);
            // the Lover elevation gets its own authored line.
            var _bd_tier = affinity_tier(_bond_id);
            var _bd_lore = affinity_deepen_line(_bond_id, _bd_tier);
            if (_bd_lore == "") _bd_lore = "Something settles between you - warmer than words.";
            bond_dialog_title = npc_names[selected_npc] + "  -  " + affinity_tier_name(_bond_id);
            bond_dialog_body  = _bd_lore + "\n\nYour bond with "
                + npc_names[selected_npc] + " deepens to " + affinity_tier_name(_bond_id) + ".";
            // Seed the floating hearts (drawn in the bond dialog, hub Draw).
            bond_dialog_hearts = [];
            var _bd_n = (_bd_tier >= 4) ? 14 : 7;
            repeat (_bd_n) {
                array_push(bond_dialog_hearts, {
                    x: 460 + random(1000), y: 780 + random(60),
                    vy: 0.8 + random(1.2), sway: random(pi * 2),
                    sc: 0.7 + random(0.8), a: 0.9
                });
            }
            audio_play_sound(snd_quest_ready, 1, false);
        } else {
            bond_dialog_hearts = [];
            bond_dialog_title = npc_names[selected_npc];
            bond_dialog_body  = _adv;   // gate-quest ask / progress reminder
        }
        if (room == rm_hub || room == rm_character_select) save_game();
    }
}

// -----------------------------------------------------------------------------
// 2c. UPGRADE STATION (NPC PROGRESSION, M-locked 08-15): [U] on a focused NPC
// card - or a tap on the card's STATION chip (Draw injects npcup:open) - arms
// the checkout popup; the spend itself commits in 0a3 on CONFIRM.
// -----------------------------------------------------------------------------
if ((input_hotkey("U") || input_inject_take("npcup:open"))
    && selected_npc < array_length(affinity_npc_ids()) && !show_history) {
    var _up_ids = affinity_npc_ids();
    var _up_id  = _up_ids[selected_npc];
    if (npc_rank(_up_id) < 2 && npc_unlocked[selected_npc]) {
        var _up_next = npc_rank(_up_id) + 1;
        var _up_c    = npc_rank_cost(_up_next);
        var _up_dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
        npc_upgrade_arm   = _up_id;
        npc_upgrade_title = string_upper(npc_names[selected_npc]) + "  -  STATION RANK " + string(_up_next);
        npc_upgrade_body  = npc_rank_perk_text(_up_id, _up_next)
            + "\n\nCost: " + string(_up_c.gold) + "g + " + string(_up_c.dust) + " dust"
            + "   (you have " + string(global.gold) + "g, " + string(_up_dust) + " dust)";
        audio_play_sound(snd_page, 1, false);
    }
}

// (Gifting moved INSIDE each NPC's engagement window - press F there. Quests are
// accepted/turned in at the Tavern Requests board, row 8. Phase 4b UX pass, M.)


// -----------------------------------------------------------------------------
// 3. ENTER DUNGEON - dungeon button must be highlighted (the slot AFTER the last NPC)
// Opens dungeon selection overlay; loadout opens after dungeon is chosen.
// -----------------------------------------------------------------------------
if (selected_npc == array_length(npc_names)
    && (input_confirm() || input_confirm_alt())) {
    if (instance_exists(obj_game_controller)) {
        var _gc_e = instance_find(obj_game_controller, 0);

        if (_gc_e.loadout_confirmed) {
            music_hub_stop();   // stops the default AND any banshee-jukebox hub track
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
            _gc_e.dungeon_select_asc  = min(_cur_asc2, dungeon_max_ascendance(_cur_dk2));
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

    // NPC rows: x=630-1290, y=105+i*96, h=81. LEGACY LIST ONLY - the carousel
    // handles its own stage/arrow/chip taps in Draw_64, beside the drawn rects.
    if (!hub_use_carousel)
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
                        tutorial_try_show("maren_forge");   // onboarding: first Maren open - explain tempering (M 08-04)
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
                    } else if (_hni == 7) {
                        // Tavern Requests board - this mouse/tap path was missing the
                        // case the keyboard-Enter path has (~line 960), so tapping the
                        // row fell through to "Coming Soon" on touch (M 07-17).
                        _gc_mc.tavern_board_open   = true;
                        _gc_mc.tavern_board_cursor = 0;
                        _gc_mc.tavern_board_note   = "";
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
                music_hub_stop();   // stops the default AND any banshee-jukebox hub track
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
                _gc_e2.dungeon_select_asc  = min(_cur_asc3, dungeon_max_ascendance(_cur_dk3));
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
