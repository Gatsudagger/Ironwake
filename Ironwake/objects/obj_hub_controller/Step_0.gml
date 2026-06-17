// =============================================================================
// obj_hub_controller — Step event
// Handles all keyboard input on the hub screen.
// Input map:
//   Up / W       — move selection up (or scroll history)
//   Down / S     — move selection down (or scroll history)
//   Space/Enter  — interact with selected NPC (if unlocked)
//   E            — enter dungeon
//   H            — toggle run history overlay
//   T            — open stash screen
//   P            — open permanent stat allocation (if points available)
//   Escape       — dismiss last-run summary or close history
// =============================================================================

// -----------------------------------------------------------------------------
// 0b. LOADOUT OVERLAY — runs BEFORE ui_input_blocked() check
// loadout_open is included in ui_input_blocked() to freeze the rest of the hub,
// but the handler itself must not be blocked by its own flag.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_ld = instance_find(obj_game_controller, 0);

    if (_gc_ld.loadout_open) {
        var _ld_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;
        var _ld_pool;
        switch (_ld_class) {
            case 0:  _ld_pool = global.abilities_arcanist;      break;
            case 1:  _ld_pool = global.abilities_bloodwarden;   break;
            case 2:  _ld_pool = global.abilities_shadowstrider; break;
            default: _ld_pool = global.abilities_arcanist;
        }
        var _ld_pool_sz = array_length(_ld_pool);
        var _ld_sel_cnt = array_length(_gc_ld.loadout_selected);

        // Tick flash timer (shared between tabs — "slots full" warning)
        if (_gc_ld.loadout_full_timer > 0) _gc_ld.loadout_full_timer--;

        // Q/E switch between Abilities (0) and Traits (1)
        if (keyboard_check_pressed(ord("Q")) || keyboard_check_pressed(ord("E"))) {
            _gc_ld.loadout_tab = 1 - _gc_ld.loadout_tab;
        }

        if (keyboard_check_pressed(vk_escape)) {
            _gc_ld.loadout_open = false;
            exit;
        }

        // =====================================================================
        // ABILITIES TAB
        // =====================================================================
        if (_gc_ld.loadout_tab == 0) {
            var _ld_max_cur = _ld_pool_sz - 1 + (_ld_sel_cnt == 4 ? 1 : 0);

            if (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))) {
                _gc_ld.loadout_cursor = max(0, _gc_ld.loadout_cursor - 1);
            }
            if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
                _gc_ld.loadout_cursor = min(_ld_max_cur, _gc_ld.loadout_cursor + 1);
            }

            // Space or Enter at confirm row: commit and enter dungeon
            if ((keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter))
                && _gc_ld.loadout_cursor == _ld_pool_sz && _ld_sel_cnt == 4) {
                for (var _li = 0; _li < 4; _li++) {
                    global.player_loadout[_li] = _gc_ld.loadout_selected[_li];
                }
                var _tr_sel_c = _gc_ld.traits_selected;
                if (array_length(_tr_sel_c) > 0) {
                    global.player_traits[0] = _tr_sel_c[0];
                } else {
                    global.player_traits[0] = "";
                }
                if (array_length(_tr_sel_c) > 1) {
                    global.player_traits[1] = _tr_sel_c[1];
                } else {
                    global.player_traits[1] = "";
                }
                _gc_ld.loadout_open      = false;
                _gc_ld.loadout_confirmed = true;
                room_goto(rm_dungeon_floor);
            }

            if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
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
                            _ld_pool_sz - 1 + (array_length(_gc_ld.loadout_selected) == 4 ? 1 : 0));
                    } else if (_ld_sel_cnt < 4) {
                        array_push(_gc_ld.loadout_selected, _ld_ab_name);
                    } else {
                        _gc_ld.loadout_full_timer = 60;
                    }
                }
            }

        // =====================================================================
        // TRAITS TAB
        // =====================================================================
        } else {
            // Crown of the Hollow King: +1 trait slot while equipped
            var _max_traits = 2;
            if (variable_global_exists("inventory")) {
                for (var _ci2 = 0; _ci2 < array_length(global.inventory); _ci2++) {
                    var _ci2_it = global.inventory[_ci2];
                    if (_ci2_it == undefined) continue;
                    if (variable_struct_exists(_ci2_it, "unique_effect")
                        && _ci2_it.unique_effect == "crown_hollow_king") {
                        _max_traits = 3;
                        break;
                    }
                }
            }
            // Gracefully trim traits_selected if Crown was just unequipped
            while (array_length(_gc_ld.traits_selected) > _max_traits) {
                array_delete(_gc_ld.traits_selected, array_length(_gc_ld.traits_selected) - 1, 1);
            }

            // Build available (unlocked, class-filtered) and locked trait lists
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
            var _tr_avail_cnt = array_length(_tr_avail);
            var _tr_sel_cnt   = array_length(_gc_ld.traits_selected);

            if (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))) {
                _gc_ld.traits_cursor = max(0, _gc_ld.traits_cursor - 1);
            }
            if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
                _gc_ld.traits_cursor = min(max(0, _tr_avail_cnt - 1), _gc_ld.traits_cursor + 1);
            }

            if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter))
                && _tr_avail_cnt > 0) {
                var _hov_tr_name = _tr_avail[_gc_ld.traits_cursor].name;
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
        }

        exit;
    }
}


// Block all hub input while any gc overlay (menu, stash, shop, level alloc) is open.
// Perm alloc is hub-specific and not in ui_input_blocked — handled below.
if (ui_input_blocked()) exit;


// -----------------------------------------------------------------------------
// 0a. HUB-SPECIFIC OVERLAY TOGGLES (perm alloc, stash opener, shop opener)
// These run after ui_input_blocked() so they are skipped when another
// overlay is already active.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_hub = instance_find(obj_game_controller, 0);

    // T: open stash screen (not while perm alloc is open)
    if (!_gc_hub.perm_alloc_open && keyboard_check_pressed(ord("T"))) {
        _gc_hub.stash_mode_open  = true;
        _gc_hub.stash_mode_index = 0;
        _gc_hub.stash_mode_side  = 0;
        exit;
    }

    // P: open permanent stat allocation (only when points are available)
    if (variable_global_exists("pending_perm_points") && global.pending_perm_points > 0
        && keyboard_check_pressed(ord("P"))) {
        _gc_hub.perm_alloc_open  = true;
        _gc_hub.perm_alloc_index = 0;
        exit;
    }

    // Perm alloc input — runs when open; blocks everything below
    if (_gc_hub.perm_alloc_open) {
        if (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))) {
            _gc_hub.perm_alloc_index = max(0, _gc_hub.perm_alloc_index - 1);
        }
        if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
            _gc_hub.perm_alloc_index = min(5, _gc_hub.perm_alloc_index + 1);
        }
        if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && global.pending_perm_points > 0) {
            var _perm_stat_keys = ["perm_str_bonus", "perm_dex_bonus", "perm_con_bonus",
                                   "perm_int_bonus", "perm_wis_bonus", "perm_cha_bonus"];
            var _pkey = _perm_stat_keys[_gc_hub.perm_alloc_index];
            variable_global_set(_pkey, variable_global_get(_pkey) + 1);
            global.pending_perm_points--;
            if (global.pending_perm_points <= 0) {
                _gc_hub.perm_alloc_open = false;
            }
        }
        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
            _gc_hub.perm_alloc_open = false;
        }
        exit;
    }
}


// -----------------------------------------------------------------------------
// 0. RUN HISTORY OVERLAY — intercepts navigation input while open
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(ord("H"))) {
    show_history   = !show_history;
    history_scroll = 0;
}

if (show_history) {
    if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
        history_scroll = max(0, history_scroll - 1);
    }
    if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
        var _max_scroll = max(0, array_length(global.run_history) - 5);
        history_scroll = min(_max_scroll, history_scroll + 1);
    }
    if (keyboard_check_pressed(vk_escape)) {
        show_history = false;
    }
    exit; // block NPC navigation while viewing history
}


// -----------------------------------------------------------------------------
// 1. NPC LIST NAVIGATION
// Clearing the notification on any navigation keypress keeps the UI clean.
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
    selected_npc = max(0, selected_npc - 1);
    notification = "";
}

if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
    selected_npc = min(5, selected_npc + 1);
    notification = "";
}


// -----------------------------------------------------------------------------
// 2. INTERACT WITH SELECTED NPC
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter)) {
    if (npc_unlocked[selected_npc]) {
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
            } else {
                notification = npc_names[selected_npc] + ": Coming Soon.";
            }
        }
    } else {
        notification = "This NPC is not yet available.";
    }
}


// -----------------------------------------------------------------------------
// 3. ENTER DUNGEON — opens loadout overlay on first press; goes directly once confirmed
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(ord("E"))) {
    if (instance_exists(obj_game_controller)) {
        var _gc_e = instance_find(obj_game_controller, 0);

        if (_gc_e.loadout_confirmed) {
            room_goto(rm_dungeon_floor);
        } else {
            // Determine class ability pool
            var _e_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;
            var _e_pool;
            switch (_e_class) {
                case 0:  _e_pool = global.abilities_arcanist;      break;
                case 1:  _e_pool = global.abilities_bloodwarden;   break;
                case 2:  _e_pool = global.abilities_shadowstrider; break;
                default: _e_pool = global.abilities_arcanist;
            }

            // Build valid name set for this class
            var _e_valid = [];
            for (var _ai = 0; _ai < array_length(_e_pool); _ai++) {
                array_push(_e_valid, _e_pool[_ai].name);
            }

            // Try restoring saved loadout (validate each name against the pool)
            _gc_e.loadout_selected = [];
            for (var _li = 0; _li < 4; _li++) {
                var _lname = global.player_loadout[_li];
                var _ok    = false;
                for (var _vi = 0; _vi < array_length(_e_valid); _vi++) {
                    if (_e_valid[_vi] == _lname) { _ok = true; break; }
                }
                if (_ok) array_push(_gc_e.loadout_selected, _lname);
            }

            // Fall back to first 4 if saved loadout wasn't 4 valid entries
            if (array_length(_gc_e.loadout_selected) < 4) {
                _gc_e.loadout_selected = [];
                for (var _ai = 0; _ai < min(4, array_length(_e_pool)); _ai++) {
                    array_push(_gc_e.loadout_selected, _e_pool[_ai].name);
                }
            }

            // Init traits state — restore saved selections if still valid
            _gc_e.loadout_tab   = 0;
            _gc_e.traits_cursor = 0;
            _gc_e.traits_selected = [];
            if (variable_global_exists("player_traits") && variable_global_exists("traits_unlocked")) {
                for (var _ti = 0; _ti < 2; _ti++) {
                    var _tname = global.player_traits[_ti];
                    if (_tname == "") continue;
                    for (var _tri = 0; _tri < array_length(global.traits_all); _tri++) {
                        var _tr_e = global.traits_all[_tri];
                        if (_tr_e.name != _tname) continue;
                        if (_tr_e.class_req != -1 && _tr_e.class_req != _e_class) break;
                        if (variable_struct_get(global.traits_unlocked, _tr_e.effect_id)) {
                            array_push(_gc_e.traits_selected, _tname);
                        }
                        break;
                    }
                }
            }

            _gc_e.loadout_open       = true;
            _gc_e.loadout_cursor     = 0;
            _gc_e.loadout_full_timer = 0;
        }
    }
}


// -----------------------------------------------------------------------------
// 4. DISMISS LAST RUN SUMMARY
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(vk_escape)) {
    if (show_last_run) {
        show_last_run = false;
    }
}
