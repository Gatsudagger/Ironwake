// Latch whether any gc-managed overlay/modal is open at the START of this Step,
// BEFORE the ESC-close handlers below clear their flags. The hub's pause-menu
// trigger checks this so the same Esc press that closes an overlay (inventory,
// stash, shops, trainers, item picker, comparison) can't also pop the pause menu.
// (Floor/combat manage their own popups with early exits, so they don't need it.)
global.ui_overlay_latch = ui_input_blocked()
    || (variable_global_exists("item_picker") && global.item_picker.open)
    || comparison_open;

// Global fullscreen toggle (F11) - works in every room, persists in settings.ini.
if (keyboard_check_pressed(vk_f11)) {
    video_toggle_fullscreen();
}

// HTML5 / itch: keep the canvas matched to the live browser/itch frame so it always
// fills it. The frame resizes on fullscreen-launch and window-resize, and GM's HTML5
// scaling won't upscale a fixed canvas to a bigger frame, so we re-size to the browser
// dimensions whenever they change. The fixed 1920x1080 GUI layer stretches to fill it.
// (Desktop is sized once in video_apply; this whole block is web-only.)
if (os_browser != browser_not_a_browser) {
    var _bw = browser_width;
    var _bh = browser_height;
    if (_bw > 0 && _bh > 0 && (window_get_width() != _bw || window_get_height() != _bh)) {
        window_set_size(_bw, _bh);
    }
}

// --- Full-screen hatch cutscene ---
// While an egg is hatching it owns every input; the cutscene advances itself and
// applies pet_hatch at the reveal. Drawn over the Bairc screen by hatch_cutscene_draw().
if (hatch_active) {
    hatch_cutscene_step();
    exit;
}

// --- Onboarding coach-mark (see SYSTEMS_ONBOARDING.md) ---
// A tip is modal: ui_input_blocked() reports true while one is active (freezing every
// room controller), and gc owns the dismiss here. The clear is DEFERRED one frame
// (tutorial_dismiss_pending) so the tip stays "active" through the ENTIRE Step phase
// of the dismiss frame - no controller, whatever its instance order, can act on the
// dismissing keypress. We exit so gc's own input handlers below are frozen too.
if (global.tutorial_dismiss_pending) {
    tutorial_dismiss();                       // mark seen + clear active
    global.tutorial_dismiss_pending = false;
}
if (tutorial_is_active()) {
    if (keyboard_check_pressed(vk_anykey) || mouse_check_button_pressed(mb_any)) {
        global.tutorial_dismiss_pending = true;   // clear next frame, not now
    }
    exit;
}

// --- Shared item-sacrifice picker (Vex stat/trait trade) ---
// While open the modal captures all input so the underlying screen is frozen.
// We exit the same frame it closes so the confirming keypress can't fall through
// to the screen below. Gated to the Vex purposes so that - since this controller
// is persistent and also alive on the dungeon floor - only obj_floor_controller
// drives the Shrine picker (no double-stepping). See SYSTEMS_ITEM_PICKER.md.
if (variable_global_exists("item_picker") && global.item_picker.open
    && (global.item_picker.purpose == "vex_trait" || global.item_picker.purpose == "vex_stat"
        || global.item_picker.purpose == "alch_rebirth")) {
    item_picker_step();
    exit;
}
if (variable_global_exists("item_picker") && global.item_picker.resolved_purpose != "") {
    var _rp = global.item_picker.resolved_purpose;
    if (_rp == "vex_trait" || _rp == "vex_stat") {
        trainer_notification = global.item_picker.result_msg;
        global.item_picker.resolved_purpose = "";   // consume the one-shot
    } else if (_rp == "alch_rebirth") {
        sable_notification = global.item_picker.result_msg;
        global.item_picker.resolved_purpose = "";
    }
}

// Close comparison panel on ESC (checked before other handlers)
if (comparison_open && keyboard_check_pressed(vk_escape)) {
    comparison_open     = false;
    comparison_item     = undefined;
    comparison_equipped = undefined;
}

// Tick trait unlock notification timer
if (trait_notif_timer > 0) {
    trait_notif_timer--;
    if (trait_notif_timer <= 0) trait_notif_msg = "";
}

// Tick equip confirmation notification
if (equip_notif_timer > 0) {
    equip_notif_timer--;
    if (equip_notif_timer <= 0) equip_notif_msg = "";
}

// `I` opens the full character menu everywhere, combat included, so the player can
// check equipment/status mid-fight. Combat item USE is a separate quick-menu on the
// C key (obj_combat_controller) - distinct key, so the two don't conflict.
if (!stash_mode_open && !loadout_open && keyboard_check_pressed(ord("I"))) {
    menu_open = !menu_open;
    menu_tab  = 0;
    equip_picker_open       = false;
    consumable_submenu_open = false;
    compendium_section      = 0;
    equip_found_focus       = false;   // Equipment tab: is the right "found items" column focused?
    equip_found_cursor      = 0;
    equip_found_sort        = 0;       // 0 = sort by rarity, 1 = sort by type/slot
}


// =============================================================================
// STASH SCREEN - runs before the menu_open guard so it fires when menu is closed
// =============================================================================
if (stash_mode_open) {
    var _left_count  = array_length(global.carried_items) + array_length(global.consumable_inventory);
    var _right_count = array_length(global.equipment_stash) + array_length(global.consumable_stash);
    var _cur_count   = (stash_mode_side == 0) ? _left_count : _right_count;

    if (keyboard_check_pressed(vk_left)  || keyboard_check_pressed(ord("Q"))) {
        stash_mode_side  = 0;
        stash_mode_index = 0;
    }
    if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("E"))) {
        stash_mode_side  = 1;
        stash_mode_index = 0;
    }
    // Hold-to-repeat + wrap-around (top<->bottom). nav_up/down auto-repeat while held.
    if (nav_up())   stash_mode_index = wrap_index(stash_mode_index - 1, _cur_count);
    if (nav_down()) stash_mode_index = wrap_index(stash_mode_index + 1, _cur_count);

    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
        if (stash_mode_side == 0) {
            var _ceq = array_length(global.carried_items);
            if (stash_mode_index < _ceq) {
                var _it = global.carried_items[stash_mode_index];
                array_delete(global.carried_items, stash_mode_index, 1);
                array_push(global.equipment_stash, _it);
            } else {
                var _ci = stash_mode_index - _ceq;
                if (_ci < array_length(global.consumable_inventory)) {
                    var _it = global.consumable_inventory[_ci];
                    array_delete(global.consumable_inventory, _ci, 1);
                    array_push(global.consumable_stash, _it);
                }
            }
            stash_mode_index = clamp(stash_mode_index, 0, max(0, _left_count - 2));
        } else {
            var _seq = array_length(global.equipment_stash);
            if (stash_mode_index < _seq) {
                var _it = global.equipment_stash[stash_mode_index];
                array_delete(global.equipment_stash, stash_mode_index, 1);
                array_push(global.carried_items, _it);
            } else {
                var _ci = stash_mode_index - _seq;
                if (_ci < array_length(global.consumable_stash)) {
                    var _it = global.consumable_stash[_ci];
                    array_delete(global.consumable_stash, _ci, 1);
                    array_push(global.consumable_inventory, _it);
                }
            }
            stash_mode_index = clamp(stash_mode_index, 0, max(0, _right_count - 2));
        }
        // Persist the deposit/withdraw immediately (stash is hub-only state).
        if (room == rm_hub || room == rm_character_select) save_game();
    }

    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
        stash_mode_open = false;
    }

    // Mouse: click a column to switch side; click an item row to select it.
    // Geometry mirrors ui_draw_stash_screen (cols at x45/x1020 width 855, list
    // top y185, row height 75) including the scroll window so clicks map to the
    // right entry even when the list is scrolled.
    if (mouse_check_button_pressed(mb_left)) {
        var _smx = device_mouse_x_to_gui(0);
        var _smy = device_mouse_y_to_gui(0);
        var _list_top    = 185;
        var _row_h       = 75;
        var _max_bot     = 1020;
        var _rows_vis    = max(1, floor((_max_bot - _list_top) / _row_h));
        // Switch to left side
        if (_smx >= 45 && _smx < 900 && _smy >= 140 && _smy < _max_bot) {
            if (stash_mode_side != 0) { stash_mode_side = 0; stash_mode_index = 0; }
            else if (_smy >= _list_top) {
                var _lcnt   = array_length(global.carried_items) + array_length(global.consumable_inventory);
                var _lscr   = clamp(stash_mode_index - floor(_rows_vis / 2), 0, max(0, _lcnt - _rows_vis));
                var _lrow   = _lscr + floor((_smy - _list_top) / _row_h);
                if (_lrow >= 0 && _lrow < _lcnt) stash_mode_index = _lrow;
            }
        }
        // Switch to right side
        if (_smx >= 1020 && _smx < 1875 && _smy >= 140 && _smy < _max_bot) {
            if (stash_mode_side != 1) { stash_mode_side = 1; stash_mode_index = 0; }
            else if (_smy >= _list_top) {
                var _rcnt   = array_length(global.equipment_stash) + array_length(global.consumable_stash);
                var _rscr   = clamp(stash_mode_index - floor(_rows_vis / 2), 0, max(0, _rcnt - _rows_vis));
                var _rrow   = _rscr + floor((_smy - _list_top) / _row_h);
                if (_rrow >= 0 && _rrow < _rcnt) stash_mode_index = _rrow;
            }
        }
    }

    exit;
}

// =============================================================================
// LEVEL-UP ALLOCATION - handled here so ui_input_blocked() can freeze the
// combat controller's Step while the overlay is active without breaking input.
// =============================================================================
if (level_alloc_open) {
    if (nav_up())   level_alloc_index = wrap_index(level_alloc_index - 1, 6);
    if (nav_down()) level_alloc_index = wrap_index(level_alloc_index + 1, 6);

    // Enter: set or move the provisional stat choice - does NOT commit yet
    if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && global.pending_stat_points > 0) {
        level_alloc_pending_stat = level_alloc_index;
    }

    // Space: commit the provisional choice permanently
    if (keyboard_check_pressed(vk_space)
        && level_alloc_pending_stat >= 0 && global.pending_stat_points > 0) {
        var _alloc_keys = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        var _chosen_key = _alloc_keys[level_alloc_pending_stat];
        variable_struct_set(global.run_stat_bonuses, _chosen_key,
            variable_struct_get(global.run_stat_bonuses, _chosen_key) + 1);
        global.pending_stat_points--;
        level_alloc_pending_stat = -1;
        // Update live player stats if in combat - CON recalcs HP only on confirm
        if (instance_exists(obj_combat_controller)) {
            var _ctrl = instance_find(obj_combat_controller, 0);
            variable_struct_set(_ctrl.player.stats, _chosen_key,
                variable_struct_get(_ctrl.player.stats, _chosen_key) + 1);
            if (_chosen_key == "CON") {
                var _nd = stats_derive(_ctrl.player.stats);
                var _hg = _nd.HP - _ctrl.player.max_HP;
                _ctrl.player.max_HP = _nd.HP;
                _ctrl.player.HP = min(_ctrl.player.max_HP, _ctrl.player.HP + max(0, _hg));
            }
        }
        if (global.pending_stat_points <= 0) level_alloc_open = false;
    }
    exit;
}


// =============================================================================
// DEEPEN BOND (B) inside an open NPC screen, so a ready gate is actionable right
// where you earn it (mirrors the hub-list B handler, which is gated off while a
// screen is open). Maps the currently-open NPC screen to its affinity id. No-ops
// when no NPC screen is open (B stays free for the hub list / combat).
// =============================================================================
if (keyboard_check_pressed(ord("B"))) {
    var _bond_npc = "";
    if (shop_open == 0)                                                    _bond_npc = "petra";
    else if (shop_open == 1)                                               _bond_npc = "dorn";
    else if (variable_instance_exists(id, "trainer_open") && trainer_open) _bond_npc = "vex";
    else if (variable_instance_exists(id, "maren_open")   && maren_open)   _bond_npc = "maren";
    else if (variable_instance_exists(id, "sable_open")   && sable_open)   _bond_npc = "sable";
    else if (variable_instance_exists(id, "vael_open")    && vael_open)    _bond_npc = "vael";
    if (_bond_npc != "" && affinity_gate_ready(_bond_npc)) {
        affinity_try_advance(_bond_npc);
        if (room == rm_hub || room == rm_character_select) save_game();
    }
}

// =============================================================================
// SHOP INPUT - runs before menu_open guard; gc handles all buy/sell logic
// =============================================================================
if (shop_open != -1 && !stash_mode_open) {

    // Q/E: cycle tabs. Petra (shop_open == 0) has a 3rd "Treasure Trader" tab; Dorn has 2.
    var _shop_ntabs = (shop_open == 0) ? 3 : 2;
    if (keyboard_check_pressed(ord("E"))) {
        shop_tab = (shop_tab + 1) mod _shop_ntabs;
        sell_index = 0; sell_scroll = 0; sell_confirm_name = ""; shop_notification = "";
        petra_trade_confirm = false; petra_trade_selected = []; petra_trade_notification = "";
    }
    if (keyboard_check_pressed(ord("Q"))) {
        shop_tab = (shop_tab + _shop_ntabs - 1) mod _shop_ntabs;
        sell_index = 0; sell_scroll = 0; sell_confirm_name = ""; shop_notification = "";
        petra_trade_confirm = false; petra_trade_selected = []; petra_trade_notification = "";
    }

    // =========================================================================
    // SELL TAB
    // =========================================================================
    if (shop_tab == 1) {

        // Build sell list: stash equipment, stash consumables, carried equipment, carried consumables.
        // Equipment in global.inventory[] (equipped slots) is excluded entirely.
        var _sl_items = [];
        var _sl_src   = [];   // 0=equipment_stash  1=consumable_stash  2=carried_items  3=consumable_inventory
        var _sl_idx   = [];   // index within the source array at build time

        for (var _i = 0; _i < array_length(global.equipment_stash); _i++) {
            array_push(_sl_items, global.equipment_stash[_i]);
            array_push(_sl_src,   0);
            array_push(_sl_idx,   _i);
        }
        for (var _i = 0; _i < array_length(global.consumable_stash); _i++) {
            array_push(_sl_items, global.consumable_stash[_i]);
            array_push(_sl_src,   1);
            array_push(_sl_idx,   _i);
        }
        for (var _i = 0; _i < array_length(global.carried_items); _i++) {
            array_push(_sl_items, global.carried_items[_i]);
            array_push(_sl_src,   2);
            array_push(_sl_idx,   _i);
        }
        for (var _i = 0; _i < array_length(global.consumable_inventory); _i++) {
            array_push(_sl_items, global.consumable_inventory[_i]);
            array_push(_sl_src,   3);
            array_push(_sl_idx,   _i);
        }
        var _sl_count = array_length(_sl_items);

        // Clamp cursor and scroll window
        sell_index = clamp(sell_index, 0, max(0, _sl_count - 1));
        if (sell_index < sell_scroll) {
            sell_scroll = sell_index;
        }
        if (sell_index >= sell_scroll + 7) {
            sell_scroll = sell_index - 6;
        }

        if (_sl_count > 0) {
            var _cur_item  = _sl_items[sell_index];
            var _cur_src   = _sl_src[sell_index];
            var _src_idx   = _sl_idx[sell_index];

            // Compute sell price: 40% of gold_value, min 1.
            // Fallback from rarity if gold_value absent (should not occur with current data).
            var _gv = 0;
            if (variable_struct_exists(_cur_item, "gold_value")) {
                _gv = _cur_item.gold_value;
            }
            if (_gv == 0 && variable_struct_exists(_cur_item, "rarity")) {
                if (_cur_item.rarity == 0)      _gv = 15;
                else if (_cur_item.rarity == 1) _gv = 32;
                else if (_cur_item.rarity == 2) _gv = 82;
                else if (_cur_item.rarity == 3) _gv = 200;
                else                            _gv = 400;
            }
            // Base sell value = 40% of gold_value. The vendor's affinity tier sweetens
            // the deal: +5% per tier (Acquaintance..Lover -> +0%..+20%). (Task: affinity sell)
            var _shop_npc   = (shop_open == 0) ? "petra" : "dorn";
            var _sell_tier  = affinity_tier(_shop_npc);
            var _sell_price = max(1, floor(_gv * 0.4 * (1 + 0.05 * _sell_tier)));

            // Rare-or-above items need a second confirmation step
            var _needs_confirm = variable_struct_exists(_cur_item, "rarity") && _cur_item.rarity >= 2;

            // W/S: navigate (clears any pending confirm)
            if (nav_up()) {
                sell_index        = wrap_index(sell_index - 1, _sl_count);
                sell_confirm_name = "";
                shop_notification = "";
            }
            if (nav_down()) {
                sell_index        = wrap_index(sell_index + 1, _sl_count);
                sell_confirm_name = "";
                shop_notification = "";
            }

            // ESC: cancel pending confirm, or close shop
            if (keyboard_check_pressed(vk_escape)) {
                if (sell_confirm_name != "") {
                    sell_confirm_name = "";
                    shop_notification = "";
                } else {
                    shop_open         = -1;
                    shop_tab          = 0;
                    sell_index        = 0;
                    sell_scroll       = 0;
                    sell_confirm_name = "";
                    shop_notification = "";
                }
            }

            // ENTER: sell common/uncommon immediately; start confirm for rare+
            if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
                if (sell_confirm_name == "") {
                    if (_needs_confirm) {
                        sell_confirm_name = _cur_item.name;
                        shop_notification = "Sell " + _cur_item.name + " for " + string(_sell_price) + "g?";
                    } else {
                        // Sell immediately
                        if (_cur_src == 0)      array_delete(global.equipment_stash,       _src_idx, 1);
                        else if (_cur_src == 1) array_delete(global.consumable_stash,      _src_idx, 1);
                        else if (_cur_src == 2) array_delete(global.carried_items,         _src_idx, 1);
                        else if (_cur_src == 3) array_delete(global.consumable_inventory,  _src_idx, 1);
                        // Scavenger trait intentionally not applied to vendor sales.
                        // Hook: replace the direct write below with add_gold(_sell_price)
                        // if the design decision changes.
                        global.gold       += _sell_price;
                        sell_index         = clamp(sell_index, 0, max(0, _sl_count - 2));
                        shop_notification  = "Sold for +" + string(_sell_price) + "g!";
                        // Persist the sale (gold + removed item) right away.
                        if (room == rm_hub || room == rm_character_select) save_game();
                    }
                }
            }

            // SPACE: complete the rare-item sale after confirm
            if (keyboard_check_pressed(vk_space) && sell_confirm_name != "") {
                if (_cur_src == 0)      array_delete(global.equipment_stash,       _src_idx, 1);
                else if (_cur_src == 1) array_delete(global.consumable_stash,      _src_idx, 1);
                else if (_cur_src == 2) array_delete(global.carried_items,         _src_idx, 1);
                else if (_cur_src == 3) array_delete(global.consumable_inventory,  _src_idx, 1);
                // Scavenger trait intentionally not applied to vendor sales.
                global.gold       += _sell_price;
                sell_index         = clamp(sell_index, 0, max(0, _sl_count - 2));
                shop_notification  = "Sold for +" + string(_sell_price) + "g!";
                sell_confirm_name  = "";
                // Persist the sale (gold + removed item) right away.
                if (room == rm_hub || room == rm_character_select) save_game();
            }

        } else {
            // Empty sell list
            if (keyboard_check_pressed(vk_escape)) {
                shop_open         = -1;
                shop_tab          = 0;
                sell_index        = 0;
                sell_scroll       = 0;
                sell_confirm_name = "";
                shop_notification = "";
            }
        }

        exit;
    }

    // =========================================================================
    // TREASURE TRADER TAB (Petra only; shop_tab == 2). Async gear laundering -
    // 3 same-tier items -> 1 of the next tier, earned by clearing floors. Reads/
    // writes global.petra_order. Logic lives in scr_stats (PETRA_TT_PHASE1_SPEC.md).
    // =========================================================================
    if (shop_tab == 2) {
        // Esc/Backspace: cancel a pending confirm first, else close the shop.
        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
            if (petra_trade_confirm) {
                petra_trade_confirm      = false;
                petra_trade_notification = "";
            } else {
                shop_open = -1; shop_tab = 0; shop_index = 0;
                sell_index = 0; sell_scroll = 0; sell_confirm_name = "";
                shop_notification = ""; petra_trade_notification = "";
            }
            exit;
        }

        // --- An order exists: collect (ready) or cancel (in progress) ---
        if (petra_order_active()) {
            if (global.petra_order.status == "ready") {
                if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
                    petra_trade_notification = petra_collect();
                    petra_trade_confirm = false;
                }
            } else {
                // In progress: C cancels (two-step confirm).
                if (keyboard_check_pressed(ord("C"))) {
                    if (!petra_trade_confirm) {
                        petra_trade_confirm = true;
                        petra_trade_notification = "Cancel the order? You may recover only some inputs - gold is NOT refunded.  C: confirm   Esc: keep";
                    } else {
                        petra_trade_confirm = false;
                        petra_trade_notification = petra_cancel_order();
                    }
                }
            }
            exit;
        }

        // --- No order: choose 3 same-tier stash items, then place ---
        var _stash_n = array_length(global.equipment_stash);

        // Pending no-takeback preview: Space confirms+places; any move cancels it.
        if (petra_trade_confirm) {
            if (keyboard_check_pressed(vk_space)) {
                var _res = petra_place_order(petra_trade_selected, petra_trade_lever);
                if (_res == "") { petra_trade_notification = "Order placed! Earn it by clearing floors."; petra_trade_selected = []; }
                else            { petra_trade_notification = _res; }
                petra_trade_confirm = false;
            }
            if (nav_up() || nav_down() || keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_tab)) {
                petra_trade_confirm = false; petra_trade_notification = "";
            }
            exit;
        }

        // Navigate the stash list (windowed to 8 rows).
        if (_stash_n > 0) {
            if (nav_up())   petra_trade_cursor = wrap_index(petra_trade_cursor - 1, _stash_n);
            if (nav_down()) petra_trade_cursor = wrap_index(petra_trade_cursor + 1, _stash_n);
            petra_trade_cursor = clamp(petra_trade_cursor, 0, _stash_n - 1);
            if (petra_trade_cursor < petra_trade_scroll)      petra_trade_scroll = petra_trade_cursor;
            if (petra_trade_cursor >= petra_trade_scroll + 8) petra_trade_scroll = petra_trade_cursor - 7;
        }

        // Tab toggles the dust roll-bias lever (Lever A).
        if (keyboard_check_pressed(vk_tab)) {
            petra_trade_lever        = !petra_trade_lever;
            petra_trade_notification = petra_trade_lever ? "Roll-bias ON - spends dust for better affix odds." : "Roll-bias off.";
        }

        // Enter toggles selection of the highlighted item (max 3, all same tier).
        if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && _stash_n > 0) {
            var _ci    = petra_trade_cursor;
            var _found = -1;
            for (var _si = 0; _si < array_length(petra_trade_selected); _si++) {
                if (petra_trade_selected[_si] == _ci) { _found = _si; break; }
            }
            if (_found >= 0) {
                array_delete(petra_trade_selected, _found, 1);
                petra_trade_notification = "";
            } else if (array_length(petra_trade_selected) >= 3) {
                petra_trade_notification = "Already chose 3 - deselect one first (Enter).";
            } else {
                var _it = global.equipment_stash[_ci];
                var _r  = (is_struct(_it) && variable_struct_exists(_it, "rarity")) ? _it.rarity : -1;
                var _same = true;
                if (array_length(petra_trade_selected) > 0) {
                    var _first = global.equipment_stash[petra_trade_selected[0]];
                    var _fr    = (is_struct(_first) && variable_struct_exists(_first, "rarity")) ? _first.rarity : -1;
                    _same = (_r == _fr);
                }
                if (petra_ladder_for(_r) == undefined) {
                    petra_trade_notification = item_rarity_name(_r) + " items can't be traded up.";
                } else if (!_same) {
                    petra_trade_notification = "All 3 items must be the same tier.";
                } else {
                    array_push(petra_trade_selected, _ci);
                    petra_trade_notification = "";
                }
            }
        }

        // Space: when 3 are chosen, open the no-takeback preview.
        if (keyboard_check_pressed(vk_space)) {
            if (array_length(petra_trade_selected) != 3) {
                petra_trade_notification = "Select 3 same-tier items first (Enter to toggle).";
            } else {
                var _r2    = global.equipment_stash[petra_trade_selected[0]].rarity;
                var _rung2 = petra_ladder_for(_r2);
                if (_rung2 == undefined) {
                    petra_trade_notification = item_rarity_name(_r2) + " items can't be traded up.";
                } else {
                    var _gc_cost  = floor(_rung2.gold * petra_gold_mult());
                    var _fl       = max(1, _rung2.cost_floors - petra_delivery_reduction());
                    var _awk      = (_rung2.req_awk > 0) ? (" at A" + string(_rung2.req_awk) + "+") : "";
                    var _dust_txt = petra_trade_lever ? ("  +" + string(_rung2.dust) + " dust") : "";
                    petra_trade_notification = "Trade 3 " + item_rarity_name(_r2) + " -> " + item_rarity_name(_rung2.out_rarity)
                        + "  for " + string(_gc_cost) + "g" + _dust_txt + ", " + string(_fl) + " floor" + (_fl == 1 ? "" : "s") + _awk
                        + ".  Affixes destroyed. Space: confirm   Esc: cancel";
                    petra_trade_confirm = true;
                }
            }
        }
        exit;
    }

    // =========================================================================
    // BUY TAB (original buy logic - unchanged)
    // =========================================================================
    var _is_petra = (shop_open == 0);

    if (_is_petra) {
        // Unified buy list: consumables (+special) then pet feeds. Row indices match the draw.
        var _buy_list = petra_buy_list();
        var _buy_n    = array_length(_buy_list);

        if (nav_up())   { shop_index = wrap_index(shop_index - 1, _buy_n); shop_notification = ""; }
        if (nav_down()) { shop_index = wrap_index(shop_index + 1, _buy_n); shop_notification = ""; }
        shop_index = clamp(shop_index, 0, _buy_n - 1);

        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
            var _entry  = _buy_list[shop_index];
            var _sprice = _entry.price;
            if (global.gold < _sprice) {
                shop_notification = "Not enough gold!";
            } else if (_entry.kind == "feed") {
                // Pet feed -> feed pouch (applied later at Bairc).
                global.gold -= _sprice;
                pet_feed_pouch_add(_entry.it.id, 1);
                affinity_add("petra", 2);
                audio_play_sound(utility2, 1, false);
                shop_notification = _entry.it.name + " added to your feed pouch (Bairc feeds it).";
                if (room == rm_hub || room == rm_character_select) save_game();
            } else {
                // Consumable (standard or limited special).
                var _sit = _entry.it;
                global.gold -= _sprice;
                var _fresh = create_consumable(_sit.name, _sit.effect_type, _sit.effect_value,
                                               _sit.description, _sit.gold_value);
                array_push(global.consumable_stash, _fresh);
                affinity_add("petra", 2);   // function-use drip (consumable buy)
                if (_entry.special) {
                    global.petra_special_qty--;
                    if (global.petra_special_qty <= 0) {
                        global.petra_stock_special = undefined;
                        global.petra_special_qty   = 0;
                        shop_index = min(shop_index, array_length(petra_buy_list()) - 1);
                    }
                }
                audio_play_sound(utility2, 1, false);
                shop_notification = "Purchased - added to consumable stash.";
                // Persist the purchase (gold spent + new consumable) right away.
                if (room == rm_hub || room == rm_character_select) save_game();
            }
        }

    } else {
        // Dorn
        var _dorn_len = array_length(global.dorn_stock);

        if (nav_up()) {
            shop_notification = "";
            var _prev = shop_index - 1;
            while (_prev >= 0 && global.dorn_stock[_prev].sold) _prev--;
            if (_prev >= 0) shop_index = _prev;
        }
        if (nav_down()) {
            shop_notification = "";
            var _next = shop_index + 1;
            while (_next < _dorn_len && global.dorn_stock[_next].sold) _next++;
            if (_next < _dorn_len) shop_index = _next;
        }

        if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && _dorn_len > 0
            && !global.dorn_stock[shop_index].sold) {
            var _dentry = global.dorn_stock[shop_index];
            var _dprice = cha_price(_dentry.price);
            if (global.gold >= _dprice) {
                global.gold -= _dprice;
                array_push(global.equipment_stash, _dentry.item);
                affinity_add("dorn", 2);   // function-use drip (gear buy)
                discover_item(item_base_name(_dentry.item));
                global.dorn_stock[shop_index].sold = true;
                audio_play_sound(utility2, 1, false);
                shop_notification = "Purchased - added to equipment stash.";
                // Persist the purchase (gold spent + new gear) right away.
                if (room == rm_hub || room == rm_character_select) save_game();
                // Advance cursor to next non-sold item
                var _nx = shop_index + 1;
                while (_nx < _dorn_len && global.dorn_stock[_nx].sold) _nx++;
                if (_nx < _dorn_len) {
                    shop_index = _nx;
                } else {
                    var _pv = shop_index - 1;
                    while (_pv >= 0 && global.dorn_stock[_pv].sold) _pv--;
                    if (_pv >= 0) shop_index = _pv;
                }
            } else {
                shop_notification = "Not enough gold!";
            }
        }
    }

    if (keyboard_check_pressed(vk_backspace) || keyboard_check_pressed(vk_escape)) {
        shop_open         = -1;
        shop_tab          = 0;
        shop_index        = 0;
        sell_index        = 0;
        sell_scroll       = 0;
        sell_confirm_name = "";
        shop_notification = "";
    }

    // Mouse: tab switch and row selection
    if (mouse_check_button_pressed(mb_left)) {
        var _shmx = device_mouse_x_to_gui(0);
        var _shmy = device_mouse_y_to_gui(0);
        // Tab clicks (auto-centred to match the draw side). Petra (shop_open==0) has 3.
        var _mt_n   = (shop_open == 0) ? 3 : 2;
        var _mt_w   = 320;
        var _mt_gap = 24;
        var _mt_x0  = 960 - (_mt_n * _mt_w + (_mt_n - 1) * _mt_gap) / 2;
        for (var _mti = 0; _mti < _mt_n; _mti++) {
            var _mtx = _mt_x0 + _mti * (_mt_w + _mt_gap);
            if (_shmx >= _mtx && _shmx < _mtx + _mt_w && _shmy >= 96 && _shmy < 138 && shop_tab != _mti) {
                shop_tab = _mti;
                sell_index = 0; sell_scroll = 0; sell_confirm_name = ""; shop_notification = "";
                petra_trade_confirm = false; petra_trade_selected = []; petra_trade_notification = "";
            }
        }
        // Row clicks - select cursor only (Enter buys/sells)
        if (shop_tab == 0) {
            var _shrows;
            if (shop_open == 0) {
                _shrows = 4 + ((global.petra_stock_special != undefined && global.petra_special_qty > 0) ? 1 : 0);
            } else {
                _shrows = array_length(global.dorn_stock);
            }
            for (var _shri = 0; _shri < _shrows; _shri++) {
                var _shry = 189 + _shri * 126;
                if (_shmx >= 150 && _shmx < 1770 && _shmy >= _shry && _shmy < _shry+117) {
                    shop_index = _shri; shop_notification = ""; break;
                }
            }
        }
        if (shop_tab == 1) {
            var _shslcnt = array_length(global.equipment_stash) + array_length(global.consumable_stash)
                         + array_length(global.carried_items) + array_length(global.consumable_inventory);
            var _shvend  = min(sell_scroll + 7, _shslcnt);
            for (var _shri = sell_scroll; _shri < _shvend; _shri++) {
                var _shry = 189 + (_shri - sell_scroll) * 126;
                if (_shmx >= 150 && _shmx < 1770 && _shmy >= _shry && _shmy < _shry+117) {
                    sell_index = _shri; sell_confirm_name = ""; shop_notification = ""; break;
                }
            }
        }
    }

    exit;
}

// =============================================================================
// TRAINER INPUT (Vex) - runs before the menu_open guard. Four sections:
//   tab 0 Stats   tab 1 Trait Slots   tab 2 Abilities   tab 3 Potency
// =============================================================================
if (trainer_open) {
    var _tr_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;

    // --- Tab: examine the highlighted ability (tab 2) or trait (tab 3) before buying.
    if (vex_detail_open) {
        if (keyboard_check_pressed(vk_tab) || keyboard_check_pressed(vk_escape)) vex_detail_open = false;
        exit;
    }
    if (keyboard_check_pressed(vk_tab)) {
        if (trainer_tab == 2 && trainer_cursor < array_length(class_vex_purchasable(_tr_class))) {
            vex_detail_open = true; exit;
        } else if (trainer_tab == 3 && trainer_cursor < array_length(trait_vex_purchasable(_tr_class))) {
            vex_detail_open = true; exit;
        } else if (trainer_tab == 4) {
            vex_detail_open = true; exit;   // Potency: general mechanic explanation
        }
    }

    // --- Trait-potency STAT PICKER sub-modal (tab 4) ------------------------
    // Opened from tab 4: pick ANY stat to sacrifice 5 permanent points from
    // (starting allocation + bought bonus). Intercepts all input while open.
    // Row geometry MUST match ui_draw_trainer_statpick() in scr_ui.
    if (variable_instance_exists(id, "trainer_statpick_open") && trainer_statpick_open) {
        var _sp_stats = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        // Per-stat allocation of the 5 points to spend (distribute with - / +).
        if (!variable_instance_exists(id, "trainer_statpick_alloc")
            || array_length(trainer_statpick_alloc) != 6) {
            trainer_statpick_alloc = [0, 0, 0, 0, 0, 0];
        }
        var _sp_total = 0;
        for (var _ti = 0; _ti < 6; _ti++) _sp_total += trainer_statpick_alloc[_ti];

        // Esc / right-click - cancel a pending confirm first, else close the picker.
        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)
            || mouse_check_button_pressed(mb_right)) {
            if (trainer_statpick_confirm) { trainer_statpick_confirm = false; }
            else { trainer_statpick_open = false; trainer_notification = ""; }
            exit;
        }

        // W/S - move between stat rows.
        if (nav_up())   trainer_statpick_cursor = wrap_index(trainer_statpick_cursor - 1, 6);
        if (nav_down()) trainer_statpick_cursor = wrap_index(trainer_statpick_cursor + 1, 6);

        // A/D or Left/Right (and the on-row - / + buttons) adjust the highlighted stat.
        var _dec     = keyboard_check_pressed(vk_left)  || keyboard_check_pressed(ord("A"));
        var _inc     = keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"));
        var _do_conf = keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space);

        // Mouse: rows + on-row -/+ buttons + the confirm bar. Geometry MUST match
        // ui_draw_trainer_statpick() (scr_ui).
        var _sp_px = 630, _sp_pw = 660, _sp_py = 255, _sp_ph = 660, _sp_y0 = 375, _sp_rh = 60;
        if (mouse_check_button_pressed(mb_left)) {
            var _spmx = device_mouse_x_to_gui(0);
            var _spmy = device_mouse_y_to_gui(0);
            var _minus_x = _sp_px + _sp_pw - 144;
            var _plus_x  = _sp_px + _sp_pw - 72;
            for (var _spi = 0; _spi < 6; _spi++) {
                var _spry = _sp_y0 + _spi * _sp_rh;
                if (_spmy >= _spry && _spmy < _spry + _sp_rh - 6
                    && _spmx >= _sp_px + 24 && _spmx < _sp_px + _sp_pw - 24) {
                    trainer_statpick_cursor = _spi;
                    if      (_spmx >= _minus_x && _spmx < _minus_x + 48) _dec = true;
                    else if (_spmx >= _plus_x  && _spmx < _plus_x  + 48) _inc = true;
                    break;
                }
            }
            // Confirm bar (only meaningful at total 5).
            if (_spmy >= _sp_py + _sp_ph - 105 && _spmy < _sp_py + _sp_ph - 54
                && _spmx >= _sp_px + 24 && _spmx < _sp_px + _sp_pw - 24) {
                _do_conf = true;
            }
        }

        // Apply +/- with caps: can't exceed a stat's available points, nor 5 total.
        if (_dec || _inc) {
            trainer_statpick_confirm = false;   // any change disarms the confirm
            var _cs    = trainer_statpick_cursor;
            var _avail = stat_available_points(_sp_stats[_cs]);
            if (_dec && trainer_statpick_alloc[_cs] > 0) trainer_statpick_alloc[_cs] -= 1;
            if (_inc && _sp_total < 5 && trainer_statpick_alloc[_cs] < _avail) trainer_statpick_alloc[_cs] += 1;
            _sp_total = 0;
            for (var _ti2 = 0; _ti2 < 6; _ti2++) _sp_total += trainer_statpick_alloc[_ti2];
        }

        // Confirm / commit.
        if (_do_conf) {
            var _sp_tier = trait_potency_tier(trainer_statpick_trait);
            if (_sp_tier >= 5) {
                trainer_statpick_open = false;
                trainer_notification  = trainer_statpick_trait + " is already at max potency.";
            } else if (_sp_total != 5) {
                trainer_notification = "Allocate exactly 5 points to sacrifice (currently " + string(_sp_total) + ").";
            } else if (!trainer_statpick_confirm) {
                trainer_statpick_confirm = true;
                trainer_notification = "Sacrifice these 5 points permanently? This cannot be undone.";
            } else {
                for (var _ci = 0; _ci < 6; _ci++) {
                    if (trainer_statpick_alloc[_ci] > 0) stat_spend_permanent(_sp_stats[_ci], trainer_statpick_alloc[_ci]);
                }
                if (!variable_global_exists("trait_potency")) global.trait_potency = {};
                variable_struct_set(global.trait_potency, trainer_statpick_trait, _sp_tier + 1);
                save_game();
                trainer_notification = trainer_statpick_trait + " potency raised to Tier " + string(_sp_tier + 1)
                    + "  (+" + string((_sp_tier + 1) * 10) + "% strength).";
                trainer_statpick_confirm = false;
                trainer_statpick_open    = false;
            }
        }
        exit;
    }

    // Row count for the active tab (used for navigation + mouse hit-testing)
    var _tr_rows = 1;
    if (trainer_tab == 0)      _tr_rows = 6;
    else if (trainer_tab == 1) _tr_rows = 1;
    else if (trainer_tab == 2) _tr_rows = max(1, array_length(class_vex_purchasable(_tr_class)));
    else if (trainer_tab == 3) _tr_rows = max(1, array_length(trait_vex_purchasable(_tr_class)));
    else if (trainer_tab == 4) _tr_rows = array_length(trait_upgradable_list());

    var _act    = false;  // perform the selected row's action (Enter / second-click)
    var _commit = false;  // confirm a pending sacrifice (Space / confirm bar click)

    // Esc / Backspace - cancel a pending confirm first, otherwise close the screen
    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
        if (trainer_confirm) { trainer_confirm = false; trainer_notification = ""; }
        else                 { trainer_open = false; trainer_statpick_open = false; trainer_notification = ""; }
        exit;
    }

    // Q/E - switch section tabs (5 tabs: Stats | Trait Slots | Abilities | Traits | Potency)
    if (keyboard_check_pressed(ord("Q"))) {
        trainer_tab = (trainer_tab - 1 + 5) mod 5;
        trainer_cursor = 0; trainer_confirm = false; trainer_notification = "";
    }
    if (keyboard_check_pressed(ord("E"))) {
        trainer_tab = (trainer_tab + 1) mod 5;
        trainer_cursor = 0; trainer_confirm = false; trainer_notification = "";
    }

    // W/S - navigate rows
    if (nav_up())   { trainer_cursor = wrap_index(trainer_cursor - 1, _tr_rows); trainer_confirm = false; trainer_notification = ""; }
    if (nav_down()) { trainer_cursor = wrap_index(trainer_cursor + 1, _tr_rows); trainer_confirm = false; trainer_notification = ""; }
    trainer_cursor = clamp(trainer_cursor, 0, max(0, _tr_rows - 1));

    // Enter = act, Space = commit a sacrifice
    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) _act = true;
    if (keyboard_check_pressed(vk_space)) _commit = true;

    // Mouse: tab bar, row select / second-click acts, confirm bar
    if (mouse_check_button_pressed(mb_left)) {
        var _tmx = device_mouse_x_to_gui(0);
        var _tmy = device_mouse_y_to_gui(0);
        for (var _tbi = 0; _tbi < 5; _tbi++) {
            var _tbx = 68 + _tbi * 360;
            if (_tmx >= _tbx && _tmx < _tbx + 345 && _tmy >= 96 && _tmy < 144 && trainer_tab != _tbi) {
                trainer_tab = _tbi; trainer_cursor = 0;
                trainer_confirm = false; trainer_notification = "";
            }
        }
        // Scroll-aware row hit-test - Abilities (2) and Traits (3) lists can exceed
        // the screen and are windowed to 8 rows (matching the draw side).
        var _tr_vis    = _tr_rows;
        var _tr_hscroll = 0;
        if (trainer_tab == 2 || trainer_tab == 3) {
            // Tab 3 (Traits) windows to 7 rows so the trade-item readout at y=626
            // doesn't overlap the last row; Tab 2 (Abilities) has no readout, shows 8.
            var _tr_window = (trainer_tab == 3) ? 7 : 8;
            _tr_vis     = min(_tr_window, _tr_rows);
            _tr_hscroll = loadout_list_scroll(trainer_cursor, _tr_rows, _tr_window);
        }
        for (var _rwi = 0; _rwi < _tr_vis; _rwi++) {
            var _rwy = 225 + _rwi * 96;
            if (_tmx >= 180 && _tmx < 1500 && _tmy >= _rwy && _tmy < _rwy + 87) {
                var _row_idx = _tr_hscroll + _rwi;
                if (trainer_cursor == _row_idx) { _act = true; }
                else { trainer_cursor = _row_idx; trainer_confirm = false; trainer_notification = ""; }
                break;
            }
        }
        if (trainer_tab == 4 && trainer_confirm
            && _tmx >= 180 && _tmx < 1740 && _tmy >= 987 && _tmy < 1041) {
            _commit = true;
        }
    }

    // === TAB 0: PERMANENT STAT UPGRADE - 200g + one Rare+ item ===
    if (trainer_tab == 0 && _act) {
        var _stat_keys  = ["perm_str_bonus","perm_dex_bonus","perm_con_bonus","perm_int_bonus","perm_wis_bonus","perm_cha_bonus"];
        var _stat_names = ["STR","DEX","CON","INT","WIS","CHA"];
        var _stat_cost  = cha_price(200);
        if (global.gold < _stat_cost) {
            trainer_notification = "Not enough gold - a stat costs " + string(_stat_cost) + "g + a Rare item.";
        } else if (!trainer_has_rare_item()) {
            trainer_notification = "You need a Rare or better item in your stash/pack to trade.";
        } else {
            // Open the picker so the player chooses + confirms the item to trade.
            item_picker_open("vex_stat",
                { gold: _stat_cost, stat_key: _stat_keys[trainer_cursor], stat_name: _stat_names[trainer_cursor] },
                item_picker_candidates_by_rarity(2));
            trainer_notification = "";
        }
    }
    // === TAB 1: TRAIT SLOT EXPANSION - 800g then 2000g, max +2 ===
    else if (trainer_tab == 1 && _act) {
        var _bts = variable_global_exists("bonus_trait_slots") ? global.bonus_trait_slots : 0;
        if (_bts >= 2) {
            trainer_notification = "All trait slots already purchased (4 total).";
        } else {
            var _slot_cost = cha_price((_bts == 0) ? 800 : 2000);
            if (global.gold < _slot_cost) {
                trainer_notification = "Not enough gold - the next slot costs " + string(_slot_cost) + "g.";
            } else {
                global.gold -= _slot_cost;
                global.bonus_trait_slots = _bts + 1;
                affinity_add("vex", 2);   // function-use drip (trait slot)
                save_game();
                trainer_notification = "Trait slot unlocked - you can now equip " + string(2 + global.bonus_trait_slots) + " traits.";
            }
        }
    }
    // === TAB 2: ABILITY UNLOCK - tiered cost (500 / 800 / 1200g) ===
    else if (trainer_tab == 2 && _act) {
        var _locked = class_vex_purchasable(_tr_class);
        if (array_length(_locked) == 0) {
            trainer_notification = "Every purchasable ability for this class is unlocked.";
        } else {
            var _ab   = _locked[clamp(trainer_cursor, 0, array_length(_locked) - 1)];
            var _cost = ability_unlock_cost(_ab.name);
            if (global.gold < _cost) {
                trainer_notification = _ab.name + " costs " + string(_cost) + "g  (need "
                    + string(_cost - global.gold) + "g more).";
            } else {
                global.gold -= _cost;
                if (!variable_global_exists("unlocked_abilities")) global.unlocked_abilities = [];
                array_push(global.unlocked_abilities, _ab.name);
                affinity_add("vex", 2);   // function-use drip (ability unlock)
                save_game();
                trainer_notification = "Unlocked " + _ab.name + "! It can now be slotted in your loadout.";
                trainer_cursor = clamp(trainer_cursor, 0, max(0, array_length(_locked) - 2));
            }
        }
    }
    // === TAB 3: TRAIT UNLOCK - gold + a rarity-matched item ===
    else if (trainer_tab == 3 && _act) {
        var _tr_locked = trait_vex_purchasable(_tr_class);
        if (array_length(_tr_locked) == 0) {
            trainer_notification = "Every trait available to this class is unlocked.";
        } else {
            var _tt    = _tr_locked[clamp(trainer_cursor, 0, array_length(_tr_locked) - 1)];
            var _tcost = trait_unlock_cost(_tt.name);
            if (global.gold < _tcost.gold) {
                trainer_notification = _tt.name + " costs " + string(_tcost.gold) + "g + a "
                    + _tcost.item_label + " item  (need " + string(_tcost.gold - global.gold) + "g more).";
            } else if (!trainer_has_item(_tcost.min_rarity)) {
                trainer_notification = _tt.name + " also needs a " + _tcost.item_label
                    + "+ item in your stash/pack to trade.";
            } else {
                // Open the picker so the player chooses + confirms the item to trade.
                item_picker_open("vex_trait",
                    { gold: _tcost.gold, effect_id: _tt.effect_id, trait_name: _tt.name },
                    item_picker_candidates_by_rarity(_tcost.min_rarity));
                trainer_notification = "";
            }
        }
    }
    // === TAB 4: TRAIT POTENCY - sacrifice 5 permanent stat points per tier ===
    else if (trainer_tab == 4) {
        var _ups  = trait_upgradable_list();
        var _up   = _ups[clamp(trainer_cursor, 0, array_length(_ups) - 1)];
        var _tier = trait_potency_tier(_up.name);

        // Choosing a trait opens the stat picker (handled at the top of this block):
        // you sacrifice 5 points from ANY stat you choose, not a fixed one.
        if (_act) {
            if (_tier >= 5) {
                trainer_notification = _up.name + " is already at max potency (Tier 5, +50%).";
            } else {
                trainer_statpick_open    = true;
                trainer_statpick_trait   = _up.name;
                trainer_statpick_cursor  = 0;
                trainer_statpick_confirm = false;
                trainer_statpick_alloc   = [0, 0, 0, 0, 0, 0];
                trainer_notification     = "";
            }
        }
    }

    exit;
}


// =============================================================================
// BAIRC FIRST-TALK DIALOGUE - a modal popup shown before his station opens the very
// first time. Arms only after the interact key that triggered it is released, so that
// same keypress can't dismiss it; then any key / click opens the station + hatch prompt.
// =============================================================================
if (variable_instance_exists(id, "bairc_intro_open") && bairc_intro_open) {
    if (!bairc_intro_armed) {
        if (!keyboard_check(vk_anykey) && !mouse_check_button(mb_left)) bairc_intro_armed = true;
    } else if (keyboard_check_pressed(vk_anykey) || mouse_check_button_pressed(mb_left)) {
        bairc_intro_open   = false;
        bairc_open         = true;   // now open the station
        bairc_cursor       = 0;
        bairc_notification = "Your egg is stirring - highlight it and press Enter to hatch it.";
    }
    exit;
}

// =============================================================================
// BAIRC THE CREATURE KEEPER - pet stable / hatchery (Phase 2). Cursor over the
// roster; Enter hatches an egg, else sets the highlighted pet as active companion;
// Esc closes. Layout constants MUST match ui_draw_bairc_screen() in scr_ui.
// =============================================================================
if (variable_instance_exists(id, "bairc_open") && bairc_open) {
    var _bp_n = pet_count();
    if (_bp_n > 0) bairc_cursor = clamp(bairc_cursor, 0, _bp_n - 1); else bairc_cursor = 0;

    // NAMING modal (typed text entry): captures keyboard_string; Enter confirms, Esc cancels.
    // First name is free; renaming costs 20 dust. Swallows all other input while up.
    if (bairc_naming) {
        if (string_length(keyboard_string) > 16) keyboard_string = string_copy(keyboard_string, 1, 16);
        if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_return)) {
            var _nm = string_trim(keyboard_string);
            if (_nm != "" && _bp_n > 0) {
                var _np      = global.pet_roster[bairc_cursor];
                var _rename  = pet_named(_np);
                if (!_rename || global.rune_dust >= 20) {
                    if (_rename) global.rune_dust -= 20;
                    _np.name  = _nm;
                    _np.named = true;
                    bairc_notification = "\"" + _nm + "\" - this name will now be known to them...";
                    audio_play_sound(Check_1, 1, false);
                    if (room == rm_hub || room == rm_character_select) save_game();
                } else {
                    bairc_notification = "Renaming costs 20 dust.";
                }
            }
            bairc_naming = false;
        }
        if (keyboard_check_pressed(vk_escape)) bairc_naming = false;
        exit;
    }

    // CAPSTONE PICK modal (raised Adult choosing its permanent Stage-3 gift). Two-step:
    // A/D highlights a card, Enter opens a Yes/No confirm, Enter again locks it. Esc backs
    // out (confirm -> selection -> close). Swallows all other input while up.
    if (bairc_capstone_open) {
        var _cp_pet  = (_bp_n > 0) ? global.pet_roster[bairc_cursor] : undefined;
        var _cp_pool = (is_struct(_cp_pet)) ? pet_archetype_capstones(_cp_pet.archetype) : [];
        var _cp_n    = array_length(_cp_pool);
        if (!pet_capstone_can_pick(_cp_pet) || _cp_n == 0) { bairc_capstone_open = false; exit; }

        if (!bairc_capstone_confirm) {
            if (nav_left())  bairc_capstone_sel = wrap_index(bairc_capstone_sel - 1, _cp_n);
            if (nav_right()) bairc_capstone_sel = wrap_index(bairc_capstone_sel + 1, _cp_n);
            bairc_capstone_sel = clamp(bairc_capstone_sel, 0, _cp_n - 1);
            if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_space)) {
                bairc_capstone_confirm = true;
            }
            if (keyboard_check_pressed(vk_escape)) bairc_capstone_open = false;
        } else {
            // Yes/No confirm - permanent choice.
            if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_return)) {
                var _pick = _cp_pool[clamp(bairc_capstone_sel, 0, _cp_n - 1)];
                if (pet_capstone_choose(_cp_pet, _pick.id)) {
                    bairc_notification = _cp_pet.name + " takes up " + _pick.name + " - its path is set.";
                    audio_play_sound(Check_1, 1, false);
                    if (room == rm_hub || room == rm_character_select) save_game();
                }
                bairc_capstone_open    = false;
                bairc_capstone_confirm = false;
            }
            if (keyboard_check_pressed(vk_escape)) bairc_capstone_confirm = false;   // back to selection
        }
        exit;
    }

    // RELEASE confirm modal: permanently let the highlighted creature go. Enter confirms,
    // Esc keeps it. Swallows all other input while up.
    if (bairc_release_confirm) {
        if (_bp_n == 0) { bairc_release_confirm = false; exit; }
        if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_return)) {
            var _rl = pet_release(bairc_cursor);
            if (_rl != "") {
                bairc_notification = "You let " + _rl + " go. It slips back into the dark.";
                audio_play_sound(Check_1, 1, false);
                bairc_cursor = clamp(bairc_cursor, 0, max(0, pet_count() - 1));
                if (room == rm_hub || room == rm_character_select) save_game();
            }
            bairc_release_confirm = false;
        }
        if (keyboard_check_pressed(vk_escape)) bairc_release_confirm = false;
        exit;
    }

    // Tab pet-kit detail popup: while up, only Tab/Esc (close) - swallow all else.
    if (bairc_detail_open) {
        if (keyboard_check_pressed(vk_tab) || keyboard_check_pressed(vk_escape)) bairc_detail_open = false;
        exit;
    }
    if (keyboard_check_pressed(vk_tab) && _bp_n > 0) {
        bairc_detail_open = true;
        exit;
    }

    if (keyboard_check_pressed(vk_escape)) {
        bairc_open = false;
        exit;
    }
    if (_bp_n > 0) {
        if (nav_up())   { bairc_cursor = wrap_index(bairc_cursor - 1, _bp_n); bairc_notification = ""; }
        if (nav_down()) { bairc_cursor = wrap_index(bairc_cursor + 1, _bp_n); bairc_notification = ""; }

        var _bp = global.pet_roster[bairc_cursor];
        if (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_space)) {
            if (_bp.is_egg) {
                hatch_cutscene_start(_bp);   // full-screen shake -> crack -> reveal; hatches at the reveal
            } else {
                global.active_pet  = bairc_cursor;
                bairc_notification = _bp.name + " is now your active companion.";
                audio_play_sound(Check_1, 1, false);
                if (room == rm_hub || room == rm_character_select) save_game();
            }
        }

        // Feed: number keys 1-N apply an OWNED feed (bought from Petra) to the highlighted
        // pet - no gold here. Feed FILLS the growth bar; an active run still evolves it.
        var _owned    = pet_feed_owned_list();
        var _feed_key = -1;
        if      (keyboard_check_pressed(ord("1"))) _feed_key = 0;
        else if (keyboard_check_pressed(ord("2"))) _feed_key = 1;
        else if (keyboard_check_pressed(ord("3"))) _feed_key = 2;
        else if (keyboard_check_pressed(ord("4"))) _feed_key = 3;
        else if (keyboard_check_pressed(ord("5"))) _feed_key = 4;
        else if (keyboard_check_pressed(ord("6"))) _feed_key = 5;
        if (_feed_key >= 0) {
            if (_feed_key >= array_length(_owned)) {
                if (!_bp.is_egg && pet_feed_pouch_total() <= 0)
                    bairc_notification = "No feed on hand - buy some from Petra the Trader.";
            } else {
                var _fr = pet_feed_apply(_bp, _owned[_feed_key].id);
                if (_fr == "") {
                    bairc_notification = _bp.name + " enjoys the " + _owned[_feed_key].name + "."
                        + (pet_growth_ready(_bp) ? "  Ready to grow - take it on a run!" : "");
                    audio_play_sound(Check_1, 1, false);
                    if (room == rm_hub || room == rm_character_select) save_game();
                } else {
                    bairc_notification = _fr;
                }
            }
        }

        // C: cure a pushed corrupted pet (keeps the gains so far, drops the debuff,
        // forfeits the grand ability).
        if (keyboard_check_pressed(ord("C"))) {
            var _cure = pet_corruption_cure(_bp);
            if (_cure != "") {
                bairc_notification = _cure;
                audio_play_sound(Check_1, 1, false);
                if (room == rm_hub || room == rm_character_select) save_game();
            }
        }

        // G: choose the raised Adult's permanent Stage-3 capstone (opens the pick modal).
        if (keyboard_check_pressed(ord("G"))) {
            if (pet_capstone_can_pick(_bp)) {
                bairc_capstone_open    = true;
                bairc_capstone_sel     = 0;
                bairc_capstone_confirm = false;
            } else if (!_bp.is_egg && !_bp.raised) {
                bairc_notification = "Only creatures you raised from an egg choose their gift.";
            } else if (!_bp.is_egg && _bp.stage < PET_STAGE_ADULT) {
                bairc_notification = _bp.name + " must reach adulthood before choosing a gift.";
            } else if (pet_capstone_is_locked(_bp)) {
                bairc_notification = _bp.name + "'s path is already set.";
            }
        }

        // R: release the highlighted creature (opens a confirm; permanent).
        if (keyboard_check_pressed(ord("R"))) {
            bairc_release_confirm = true;
        }

        // N: name / rename the highlighted creature (first name free, rename 20 dust).
        if (keyboard_check_pressed(ord("N"))) {
            if (_bp.is_egg) {
                bairc_notification = "You can name it once it hatches.";
            } else if (pet_named(_bp) && global.rune_dust < 20) {
                bairc_notification = "Renaming costs 20 dust (you have " + string(global.rune_dust) + ").";
            } else {
                bairc_naming    = true;
                keyboard_string = "";
            }
        }
    }
    exit;
}


// =============================================================================
// MAREN THE RUNESMITH - rune socketing (Phase 1: Socket gear + Runes list).
// Runs alongside the trainer block, before the menu_open guard.
// Socket tab is a 3-phase flow: 0 pick item -> 1 pick socket -> 2 pick rune.
// Layout constants here MUST match ui_draw_maren_screen() in scr_ui.
// =============================================================================
if (variable_instance_exists(id, "maren_open") && maren_open) {
    rune_inventory_sort();   // keep the rune/aspect pool alphabetical (display + index ops read this)
    var _m_slots = maren_socketable_slots();
    var _m_gear  = rune_inventory_indices("gear");
    var _m_asp   = rune_inventory_indices("aspect");

    // Item currently being worked on (Socket-tab phases 1/2)
    var _m_item = (maren_item_sel >= 0 && maren_item_sel < array_length(global.inventory))
                  ? global.inventory[maren_item_sel] : undefined;
    item_ensure_sockets(_m_item);

    // --- Confirm modal: a pending gold-costing / destructive action awaiting a yes/no.
    //     Takes input priority over the whole screen. Enter confirms, Esc cancels. ---
    if (maren_confirm != undefined) {
        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)
            || mouse_check_button_pressed(mb_right)) {
            maren_confirm = undefined;
            maren_notification = "Cancelled.";
            exit;
        }
        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
            var _cf = maren_confirm;
            maren_confirm = undefined;

            if (_cf.action == "socket") {
                if (global.gold < _cf.cost) { maren_notification = "Need " + string(_cf.cost) + "g."; exit; }
                if (maren_socket_rune(maren_item_sel, _cf.rune_inv)) {
                    global.gold -= _cf.cost; affinity_add("maren", 2); save_game();   // function-use drip (socket)
                    maren_notification = "Socketed " + _cf.name + " " + rune_tier_roman(_cf.tier)
                        + ".  (-" + string(_cf.cost) + "g)";
                } else {
                    maren_notification = "That item has no open sockets.";
                }
                maren_phase = 1; maren_cursor = 0; maren_scroll = 0;

            } else if (_cf.action == "unsocket") {
                if (global.gold < _cf.cost) { maren_notification = "Need " + string(_cf.cost) + "g."; exit; }
                if (maren_unsocket_rune(maren_item_sel, _cf.rune_idx)) {
                    global.gold -= _cf.cost; save_game();
                    maren_notification = "Removed " + _cf.name + " " + rune_tier_roman(_cf.tier)
                        + " (returned to inventory).  (-" + string(_cf.cost) + "g)";
                    maren_cursor = clamp(maren_cursor, 0, max(0, (_m_item != undefined ? _m_item.socket_count : 1) - 1));
                } else {
                    maren_notification = "Could not remove that rune.";
                }

            } else if (_cf.action == "split") {
                var _sr_name = _cf.name; var _sr_tier = _cf.tier;
                var _sres = maren_split_rune(_cf.rune_inv);
                maren_notification = (_sres == "")
                    ? ("Split " + _sr_name + " " + rune_tier_roman(_sr_tier) + ".")
                    : _sres;
                maren_cursor = clamp(maren_cursor, 0, max(0, array_length(global.rune_inventory) - 1));

            } else if (_cf.action == "combine") {
                var _cres = maren_combine_rune(_cf.grp_id, _cf.grp_tier);
                maren_notification = (_cres == "")
                    ? ("Forged " + _cf.name + " " + rune_tier_roman(_cf.grp_tier + 1) + "!")
                    : _cres;
                maren_cursor = 0; maren_scroll = 0;

            } else if (_cf.action == "aspect_socket") {
                if (global.gold < _cf.cost) { maren_notification = "Need " + string(_cf.cost) + "g."; exit; }
                if (maren_aspect_socket(_cf.rune_inv)) {
                    global.gold -= _cf.cost; affinity_add("maren", 2); save_game();   // function-use drip (aspect socket)
                    maren_notification = "Socketed " + _cf.name + " " + rune_tier_roman(_cf.tier)
                        + ".  (-" + string(_cf.cost) + "g)";
                } else {
                    maren_notification = "No open Aspect slot.";
                }
                maren_phase = 0; maren_cursor = 0; maren_scroll = 0;

            } else if (_cf.action == "aspect_unsocket") {
                if (global.gold < _cf.cost) { maren_notification = "Need " + string(_cf.cost) + "g."; exit; }
                if (maren_aspect_unsocket(_cf.slot_idx)) {
                    global.gold -= _cf.cost; save_game();
                    maren_notification = "Removed " + _cf.name + " " + rune_tier_roman(_cf.tier)
                        + " (returned to inventory).  (-" + string(_cf.cost) + "g)";
                    // Re-clamp against the aspect-tab row count (nav re-clamps next frame too).
                    maren_cursor = clamp(maren_cursor, 0, max(0, (variable_global_exists("aspect_slots") ? global.aspect_slots : 2)));
                } else {
                    maren_notification = "Could not remove that rune.";
                }
            }
            exit;
        }
        exit;   // swallow all other input while the confirm prompt is open
    }

    // Aspect-tab state
    var _m_aslots  = variable_global_exists("aspect_slots") ? global.aspect_slots : 2;
    var _m_asocked = variable_global_exists("aspect_runes") ? array_length(global.aspect_runes) : 0;
    var _m_arows0  = _m_aslots + ((_m_aslots < aspect_slot_cap()) ? 1 : 0); // slot rows + optional unlock row

    // Forge-tab state
    var _m_groups = rune_combine_groups();
    var _m_flags  = rune_flagship_ids();

    // Row count for the active tab + phase (navigation + mouse hit-test)
    var _m_rows = 1;
    if (maren_tab == 0) {
        if (maren_phase == 0)      _m_rows = max(1, array_length(_m_slots));
        else if (maren_phase == 1) _m_rows = (_m_item != undefined) ? max(1, _m_item.socket_count) : 1;
        else                       _m_rows = max(1, array_length(_m_gear));
    } else if (maren_tab == 1) {
        if (maren_phase == 0)      _m_rows = max(1, _m_arows0);
        else                       _m_rows = max(1, array_length(_m_asp));
    } else if (maren_tab == 2) {
        if (maren_phase == 0)      _m_rows = 3;                                       // Combine/Split/Craft menu
        else if (maren_phase == 1) _m_rows = max(1, array_length(_m_groups));         // Combine groups
        else if (maren_phase == 2) _m_rows = max(1, array_length(global.rune_inventory)); // Split list
        else                       _m_rows = max(1, array_length(_m_flags));          // Flagship list
    } else {
        _m_rows = max(1, array_length(global.rune_inventory));
    }

    // Esc / Backspace - step back one phase, else close the screen
    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
        if (maren_tab == 0 && maren_phase == 2)      { maren_phase = 1; maren_cursor = 0; maren_scroll = 0; }
        else if (maren_tab == 0 && maren_phase == 1) { maren_phase = 0; maren_item_sel = -1; maren_cursor = 0; maren_scroll = 0; }
        else if (maren_tab == 1 && maren_phase == 1) { maren_phase = 0; maren_cursor = 0; maren_scroll = 0; }
        else if (maren_tab == 2 && maren_phase > 0)  { maren_phase = 0; maren_cursor = 0; maren_scroll = 0; }
        else                                          { maren_open = false; }
        maren_notification = "";
        exit;
    }

    // Q/E (or <-/->) - switch tab (4 tabs; Q/<- left, E/-> right; resets the active flow)
    var _maren_tabchg = 0;
    if (keyboard_check_pressed(ord("E")) || keyboard_check_pressed(vk_right)) _maren_tabchg = 1;
    else if (keyboard_check_pressed(ord("Q")) || keyboard_check_pressed(vk_left)) _maren_tabchg = -1;
    if (_maren_tabchg != 0) {
        maren_tab = (maren_tab + _maren_tabchg + 4) mod 4;
        maren_phase = 0; maren_item_sel = -1; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
        exit;
    }

    // W/S - navigate rows
    if (nav_up())   { maren_cursor = wrap_index(maren_cursor - 1, _m_rows); maren_notification = ""; }
    if (nav_down()) { maren_cursor = wrap_index(maren_cursor + 1, _m_rows); maren_notification = ""; }
    maren_cursor = clamp(maren_cursor, 0, max(0, _m_rows - 1));

    // Scroll window: keep the cursor on-screen for long lists (auto-follow). Because
    // this re-derives scroll from the cursor every frame, it also self-resets to 0
    // whenever a tab/phase change sets maren_cursor back to 0. Shared with the draw.
    var _m_vis = maren_visible_rows();
    if (maren_cursor < maren_scroll)               maren_scroll = maren_cursor;
    else if (maren_cursor >= maren_scroll + _m_vis) maren_scroll = maren_cursor - _m_vis + 1;
    maren_scroll = clamp(maren_scroll, 0, max(0, _m_rows - _m_vis));

    // Mouse - tab bar (x=445+t*200, y=70, w=190, h=40) + row select acts immediately
    var _m_act = (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter));
    if (mouse_check_button_pressed(mb_left)) {
        var _mmx = device_mouse_x_to_gui(0);
        var _mmy = device_mouse_y_to_gui(0);
        var _hit_tab = false;
        for (var _mtb = 0; _mtb < 4; _mtb++) {
            var _mtx = 368 + _mtb * 300;
            if (_mmx >= _mtx && _mmx < _mtx + 285 && _mmy >= 105 && _mmy < 165) {
                maren_tab = _mtb; maren_phase = 0; maren_item_sel = -1; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                _hit_tab = true; break;
            }
        }
        // Rows: list starts at y=285, each row 72px tall, x 300..1620. The clicked
        // screen-row maps to data index maren_scroll + row (windowed list).
        if (!_hit_tab && _mmx >= 300 && _mmx < 1620) {
            var _row = floor((_mmy - 285) / 72);
            if (_row >= 0 && _row < _m_vis) {
                var _click_idx = maren_scroll + _row;
                if (_click_idx < _m_rows) { maren_cursor = _click_idx; _m_act = true; }
            }
        }
    }

    // Enter / click - perform the row action
    if (_m_act) {
        if (maren_tab == 0) {
            if (maren_phase == 0) {
                if (array_length(_m_slots) > 0) {
                    maren_item_sel = _m_slots[clamp(maren_cursor, 0, array_length(_m_slots) - 1)];
                    maren_phase = 1; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                }
            } else if (maren_phase == 1 && _m_item != undefined) {
                var _filled = array_length(_m_item.runes);
                if (maren_cursor < _filled) {
                    // Unsocket -> confirm + 30g (rune returns to inventory unharmed).
                    var _ur = _m_item.runes[maren_cursor];
                    var _ucost = rune_socket_cost();
                    if (global.gold < _ucost) {
                        maren_notification = "Removing a rune costs " + string(_ucost) + "g - not enough gold.";
                    } else {
                        maren_confirm = {
                            action: "unsocket", cost: _ucost, rune_idx: maren_cursor,
                            name: _ur.name, tier: _ur.tier,
                            message: "Remove " + _ur.name + " " + rune_tier_roman(_ur.tier)
                                + " from " + _m_item.name + " for " + string(_ucost) + "g?",
                            warn: "The rune returns to your inventory unharmed."
                        };
                    }
                } else if (array_length(_m_gear) > 0) {
                    maren_phase = 2; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                } else {
                    maren_notification = "No gear runes to socket. (Aspect runes go in the Aspects tab.)";
                }
            } else if (maren_phase == 2) {
                if (array_length(_m_gear) > 0) {
                    // Socket -> confirm + 30g.
                    var _ri = _m_gear[clamp(maren_cursor, 0, array_length(_m_gear) - 1)];
                    var _rn = global.rune_inventory[_ri];
                    var _scost = rune_socket_cost();
                    if (global.gold < _scost) {
                        maren_notification = "Socketing costs " + string(_scost) + "g - not enough gold.";
                    } else {
                        maren_confirm = {
                            action: "socket", cost: _scost, rune_inv: _ri,
                            name: _rn.name, tier: _rn.tier,
                            message: "Socket " + _rn.name + " " + rune_tier_roman(_rn.tier)
                                + " into " + (_m_item != undefined ? _m_item.name : "this item")
                                + " for " + string(_scost) + "g?",
                            warn: ""
                        };
                    }
                }
            }
        } else if (maren_tab == 1) {
            // -------- ASPECTS TAB --------
            if (maren_phase == 0) {
                if (maren_cursor < _m_asocked) {
                    // Filled slot -> unsocket (confirm + 30g; rune returns to inventory).
                    var _ua = global.aspect_runes[maren_cursor];
                    var _aucost = rune_socket_cost();
                    if (global.gold < _aucost) {
                        maren_notification = "Removing a rune costs " + string(_aucost) + "g - not enough gold.";
                    } else {
                        maren_confirm = {
                            action: "aspect_unsocket", cost: _aucost, slot_idx: maren_cursor,
                            name: _ua.name, tier: _ua.tier,
                            message: "Remove " + _ua.name + " " + rune_tier_roman(_ua.tier)
                                + " from its Aspect slot for " + string(_aucost) + "g?",
                            warn: "The rune returns to your inventory unharmed."
                        };
                    }
                } else if (maren_cursor < _m_aslots) {
                    // Empty slot -> choose an aspect rune
                    if (array_length(_m_asp) > 0) {
                        maren_phase = 1; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                    } else {
                        maren_notification = "No aspect runes to socket.";
                    }
                } else {
                    // Unlock-next-slot row
                    var _res = maren_unlock_aspect_slot();
                    maren_notification = (_res == "") ? "Unlocked a new Aspect slot!" : _res;
                }
            } else if (maren_phase == 1) {
                if (array_length(_m_asp) > 0) {
                    // Aspect socket -> confirm + 30g.
                    var _ai  = _m_asp[clamp(maren_cursor, 0, array_length(_m_asp) - 1)];
                    var _rna = global.rune_inventory[_ai];
                    var _ascost = rune_socket_cost();
                    if (global.gold < _ascost) {
                        maren_notification = "Socketing costs " + string(_ascost) + "g - not enough gold.";
                    } else {
                        maren_confirm = {
                            action: "aspect_socket", cost: _ascost, rune_inv: _ai,
                            name: _rna.name, tier: _rna.tier,
                            message: "Socket " + _rna.name + " " + rune_tier_roman(_rna.tier)
                                + " into an Aspect slot for " + string(_ascost) + "g?",
                            warn: ""
                        };
                    }
                }
            }
        } else if (maren_tab == 2) {
            // -------- FORGE TAB --------
            if (maren_phase == 0) {
                // Sub-menu: 0 Combine, 1 Split, 2 Craft Flagship
                maren_phase = clamp(maren_cursor, 0, 2) + 1;
                maren_cursor = 0; maren_scroll = 0; maren_notification = "";
            } else if (maren_phase == 1) {
                // Combine -> confirm (consumes 3 runes).
                if (array_length(_m_groups) > 0) {
                    var _grp  = _m_groups[clamp(maren_cursor, 0, array_length(_m_groups) - 1)];
                    var _ccost = rune_combine_cost(_grp.tier);
                    maren_confirm = {
                        action: "combine", grp_id: _grp.id, grp_tier: _grp.tier, name: _grp.name,
                        message: "Combine 3x " + _grp.name + " " + rune_tier_roman(_grp.tier)
                            + " into 1x " + _grp.name + " " + rune_tier_roman(_grp.tier + 1)
                            + " for " + string(_ccost.gold) + "g + " + string(_ccost.dust) + " dust?",
                        warn: "This DESTROYS all 3 source runes to forge the upgrade."
                    };
                }
            } else if (maren_phase == 2) {
                // Split -> confirm (breaks the rune down; net loss).
                if (array_length(global.rune_inventory) > 0) {
                    var _sidx = clamp(maren_cursor, 0, array_length(global.rune_inventory) - 1);
                    var _sr2  = global.rune_inventory[_sidx];
                    var _spcost = rune_split_cost();
                    var _spdust = rune_split_dust(_sr2.tier);
                    var _spwarn = (_sr2.tier > 1)
                        ? ("This DESTROYS the rune, returning one " + _sr2.name + " " + rune_tier_roman(_sr2.tier - 1)
                           + " + " + string(_spdust) + " dust (you lose a tier).")
                        : ("This DESTROYS the rune for only " + string(_spdust) + " dust - no rune is returned.");
                    maren_confirm = {
                        action: "split", rune_inv: _sidx, name: _sr2.name, tier: _sr2.tier,
                        message: "Split " + _sr2.name + " " + rune_tier_roman(_sr2.tier)
                            + " for " + string(_spcost.gold) + "g?",
                        warn: _spwarn
                    };
                    maren_cursor = clamp(maren_cursor, 0, max(0, array_length(global.rune_inventory) - 1));
                }
            } else {
                // Craft Flagship
                if (array_length(_m_flags) > 0) {
                    var _fid  = _m_flags[clamp(maren_cursor, 0, array_length(_m_flags) - 1)];
                    var _fdef = rune_get(_fid);
                    var _fres = maren_craft_flagship(_fid);
                    maren_notification = (_fres == "")
                        ? ("Forged the " + _fdef.name + " flagship rune!")
                        : _fres;
                }
            }
        }
        // Runes tab is read-only.
    }

    exit;
}


// =============================================================================
// SABLE THE ALCHEMIST - Salvage / Brew / Upgrade (see SYSTEMS_SABLE.md).
// Layout constants here MUST match ui_draw_sable_screen() in scr_ui.
// =============================================================================
if (variable_instance_exists(id, "sable_open") && sable_open) {
    rune_inventory_sort();   // keep the rune/aspect pool alphabetical (display + index ops read this)
    var _s_gear   = sable_salvageable_gear();
    var _s_rinv   = variable_global_exists("rune_inventory") ? global.rune_inventory : [];
    var _s_brew   = sable_brew_catalog();
    var _s_groups = sable_upgrade_groups();

    // Row count for the active tab + phase
    var _s_rows = 1;
    if (sable_tab == 0) {
        if (sable_phase == 0)      _s_rows = 2;                                    // Gear / Runes menu
        else if (sable_phase == 1) _s_rows = max(1, array_length(_s_gear));        // Gear list
        else                       _s_rows = max(1, array_length(_s_rinv));        // Rune list
    } else if (sable_tab == 1) {
        _s_rows = max(1, array_length(_s_brew));                                   // Brew list
    } else if (sable_tab == 2) {
        _s_rows = max(1, array_length(_s_groups));                                 // Upgrade list
    } else {
        _s_rows = 1;                                                               // Rebirth - single action row
    }

    // Esc / Backspace - cancel a pending salvage confirm first, then step back
    // (Salvage sub-list -> menu), else close.
    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
        if (sable_confirm) { sable_confirm = false; sable_notification = ""; exit; }
        if (sable_tab == 0 && sable_phase > 0) { sable_phase = 0; sable_cursor = 0; }
        else                                    { sable_open = false; }
        sable_notification = "";
        exit;
    }

    // Q/E (or <-/->) - switch tab (3 tabs; Q/<- left, E/-> right)
    var _sable_tabchg = 0;
    if (keyboard_check_pressed(ord("E")) || keyboard_check_pressed(vk_right)) _sable_tabchg = 1;
    else if (keyboard_check_pressed(ord("Q")) || keyboard_check_pressed(vk_left)) _sable_tabchg = -1;
    if (_sable_tabchg != 0) {
        sable_tab = (sable_tab + _sable_tabchg + 4) mod 4;
        sable_phase = 0; sable_cursor = 0; sable_notification = ""; sable_confirm = false;
        exit;
    }

    // W/S - navigate (moving the cursor cancels a pending salvage confirm)
    if (nav_up())   { sable_cursor = wrap_index(sable_cursor - 1, _s_rows); sable_notification = ""; sable_confirm = false; }
    if (nav_down()) { sable_cursor = wrap_index(sable_cursor + 1, _s_rows); sable_notification = ""; sable_confirm = false; }
    sable_cursor = clamp(sable_cursor, 0, max(0, _s_rows - 1));

    // Mouse - tab bar (x=345+t*200) + row select
    var _s_act = (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter));
    if (mouse_check_button_pressed(mb_left)) {
        var _smx = device_mouse_x_to_gui(0);
        var _smy = device_mouse_y_to_gui(0);
        var _s_hit_tab = false;
        for (var _stb = 0; _stb < 4; _stb++) {
            var _stx = 368 + _stb * 300;   // centred on x960 (matches the draw side)
            if (_smx >= _stx && _smx < _stx + 285 && _smy >= 105 && _smy < 165) {
                sable_tab = _stb; sable_phase = 0; sable_cursor = 0; sable_notification = "";
                _s_hit_tab = true; break;
            }
        }
        if (!_s_hit_tab && _smx >= 300 && _smx < 1620) {
            var _srow = floor((_smy - 285) / 72);
            // The salvage gear/rune lists (tab 0, phase 1/2) are WINDOWED in the draw
            // (ui_list_window_first, _svis=9) - map the clicked screen row back to the
            // real list index via the same window offset. Other tabs aren't windowed
            // (short lists) so _sfirst stays 0. Keep _svis in sync with scr_ui.
            var _sfirst = 0;
            var _svis_now = _s_rows;
            if (sable_tab == 0 && sable_phase >= 1) {
                _sfirst   = ui_list_window_first(sable_cursor, _s_rows, 9);
                _svis_now = min(_s_rows - _sfirst, 9);
            }
            if (_srow >= 0 && _srow < _svis_now) {
                var _sidx = clamp(_sfirst + _srow, 0, _s_rows - 1);
                if (sable_cursor != _sidx) sable_confirm = false;   // clicking a new row cancels a pending salvage confirm
                sable_cursor = _sidx; _s_act = true;
            }
        }
    }

    // Enter / click - perform the row action
    if (_s_act) {
        if (sable_tab == 0) {
            if (sable_phase == 0) {
                sable_phase = (sable_cursor == 0) ? 1 : 2; sable_cursor = 0; sable_notification = "";
            } else if (sable_phase == 1) {
                if (array_length(_s_gear) > 0) {
                    var _gsel = clamp(sable_cursor, 0, array_length(_s_gear) - 1);
                    var _gname = _s_gear[_gsel].item.name;
                    if (!sable_confirm) {
                        // First press arms the confirm (shows the dust payout); no loss yet.
                        sable_confirm = true;
                        var _gprev = sable_salvage_gear_dust(_s_gear[_gsel].item.rarity);
                        sable_notification = "Salvage " + _gname + " for " + string(_gprev) + " dust?   Enter: confirm   Esc: back";
                    } else {
                        sable_confirm = false;
                        var _gd = sable_salvage_gear_at(_gsel);
                        sable_notification = (_gd >= 0) ? ("Salvaged " + _gname + " for " + string(_gd) + " dust.") : "Could not salvage.";
                        if (_gd >= 0) affinity_add("sable", 2);   // function-use drip (salvage)
                        sable_cursor = clamp(sable_cursor, 0, max(0, array_length(sable_salvageable_gear()) - 1));
                    }
                }
            } else {
                if (array_length(_s_rinv) > 0) {
                    var _rsel = clamp(sable_cursor, 0, array_length(_s_rinv) - 1);
                    var _rname = _s_rinv[_rsel].name + " " + rune_tier_roman(_s_rinv[_rsel].tier);
                    if (!sable_confirm) {
                        sable_confirm = true;
                        var _rprev = sable_salvage_rune_dust(_s_rinv[_rsel].tier);
                        sable_notification = "Scrap " + _rname + " for " + string(_rprev) + " dust?   Enter: confirm   Esc: back";
                    } else {
                        sable_confirm = false;
                        var _rd = sable_salvage_rune_at(_rsel);
                        sable_notification = (_rd >= 0) ? ("Scrapped " + _rname + " for " + string(_rd) + " dust.") : "Could not scrap.";
                        if (_rd >= 0) affinity_add("sable", 2);   // function-use drip (scrap)
                        sable_cursor = clamp(sable_cursor, 0, max(0, array_length(global.rune_inventory) - 1));
                    }
                }
            }
        } else if (sable_tab == 1) {
            if (array_length(_s_brew) > 0) {
                var _bsel = clamp(sable_cursor, 0, array_length(_s_brew) - 1);
                var _bdef = _s_brew[_bsel];
                var _bres = sable_brew(_bdef.id);
                sable_notification = (_bres == "") ? ("Brewed " + _bdef.name + "!") : _bres;
                if (_bres == "") affinity_add("sable", 2);   // function-use drip (brew)
            }
        } else if (sable_tab == 2) {
            if (array_length(_s_groups) > 0) {
                var _usel = clamp(sable_cursor, 0, array_length(_s_groups) - 1);
                var _ug = _s_groups[_usel];
                var _ures = sable_upgrade(_ug.from);
                sable_notification = (_ures == "") ? ("Upgraded 3x " + _ug.from + " into " + _ug.to + "!") : _ures;
                if (_ures == "") affinity_add("sable", 2);   // function-use drip (upgrade)
                sable_cursor = 0;
            }
        } else {
            // -------- REBIRTH TAB -------- open the shared item picker on class gear.
            var _reb = item_picker_candidates_class_specific();
            if (array_length(_reb) == 0) {
                sable_notification = "You hold no class-specific gear (Uncommon+) to reforge.";
            } else {
                item_picker_open("alch_rebirth", {}, _reb);
            }
        }
    }

    exit;
}


// =============================================================================
// VAEL THE AESTHETE - transmog / skin selection (see SYSTEMS_VAEL.md).
// Single list: Enter buys an unowned skin or equips an owned one.
// Layout constants here MUST match ui_draw_vael_screen() in scr_ui.
// =============================================================================
if (variable_instance_exists(id, "vael_open") && vael_open) {
    var _v_cat  = vael_skin_catalog();
    var _v_rows = max(1, array_length(_v_cat));

    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
        vael_open = false; vael_notification = "";
        exit;
    }

    // --- Tab switching (Q/E or click the tab headers; geometry matches ui_draw_vael_screen) ---
    var _vt_prev = vael_tab;
    if (keyboard_check_pressed(ord("Q"))) vael_tab = 0;
    if (keyboard_check_pressed(ord("E"))) vael_tab = 1;
    if (mouse_check_button_pressed(mb_left)) {
        var _vtm_x = device_mouse_x_to_gui(0);
        var _vtm_y = device_mouse_y_to_gui(0);
        if (_vtm_y >= 87 && _vtm_y <= 135) {
            if (_vtm_x >= 840 - 108 && _vtm_x <= 840 + 108) vael_tab = 0;
            if (_vtm_x >= 1080 - 108 && _vtm_x <= 1080 + 108) vael_tab = 1;
        }
    }
    if (vael_tab != _vt_prev) {
        vael_notification = "";
        if (vael_tab == 1) vael_portrait_cursor = clamp(global.chosen_portrait, 0, max(0, array_length(global.portrait_sprites) - 1));
    }

    // --- Portrait tab: carousel browse + 100g change ---
    if (vael_tab == 1) {
        var _p_cnt = max(1, array_length(global.portrait_sprites));
        if (nav_left())  { vael_portrait_cursor = wrap_index(vael_portrait_cursor - 1, _p_cnt); vael_notification = ""; }
        if (nav_right()) { vael_portrait_cursor = wrap_index(vael_portrait_cursor + 1, _p_cnt); vael_notification = ""; }
        vael_portrait_cursor = clamp(vael_portrait_cursor, 0, _p_cnt - 1);

        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
            if (vael_portrait_cursor == global.chosen_portrait) {
                vael_notification = "That's already your portrait.";
            } else if (global.gold >= 100) {
                global.gold -= 100;
                global.chosen_portrait = vael_portrait_cursor;
                vael_notification = "Portrait changed!  (-100g)";
            } else {
                vael_notification = "Not enough gold - you need 100g.";
            }
        }
        exit;
    }

    if (nav_up())   { vael_cursor = wrap_index(vael_cursor - 1, _v_rows); vael_notification = ""; }
    if (nav_down()) { vael_cursor = wrap_index(vael_cursor + 1, _v_rows); vael_notification = ""; }
    vael_cursor = clamp(vael_cursor, 0, max(0, _v_rows - 1));

    var _v_act = (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter));
    if (mouse_check_button_pressed(mb_left)) {
        var _vmx = device_mouse_x_to_gui(0);
        var _vmy = device_mouse_y_to_gui(0);
        // Windowed list: x300..1200, start y225, row step 72 (matches ui_draw_vael_screen).
        if (_vmx >= 300 && _vmx < 1200) {
            var _v_vis    = 10;   // match the draw-side window (clears the controls line)
            var _v_scroll = vael_list_scroll(clamp(vael_cursor, 0, _v_rows - 1), _v_rows, _v_vis);
            var _vvis_row = floor((_vmy - 225) / 72);
            if (_vvis_row >= 0 && _vvis_row < _v_vis) {
                var _vrow = _v_scroll + _vvis_row;
                if (_vrow >= 0 && _vrow < _v_rows) { vael_cursor = _vrow; _v_act = true; }
            }
        }
    }

    if (_v_act) {
        var _vsel = _v_cat[clamp(vael_cursor, 0, array_length(_v_cat) - 1)];
        if (vael_skin_owned(_vsel.id)) {
            var _vres = vael_select_skin(_vsel.id);
            vael_notification = (_vres == "") ? ("Now wearing " + _vsel.name + ".") : _vres;
        } else {
            var _vbuy = vael_buy_skin(_vsel.id);
            vael_notification = (_vbuy == "") ? ("Purchased & equipped " + _vsel.name + "!") : _vbuy;
            if (_vbuy == "") affinity_add("vael", 2);   // function-use drip (skin buy / transmog)
        }
    }

    exit;
}


if (!menu_open) exit;

// Escape: close picker/submenu first; only close whole menu if none are open
if (keyboard_check_pressed(vk_escape)) {
    if (equip_picker_open) {
        equip_picker_open = false;
        equip_msg         = "";
    } else if (consumable_submenu_open) {
        consumable_submenu_open = false;
    } else {
        menu_open = false;
    }
    exit;
}

// Q/E cycle tabs (no wrap - clamped to 0-4)
if (!equip_picker_open && !consumable_submenu_open) {
    if (keyboard_check_pressed(ord("Q"))) {
        menu_tab          = max(0, menu_tab - 1);
        equip_picker_open = false;
    }
    if (keyboard_check_pressed(ord("E"))) {
        menu_tab          = min(4, menu_tab + 1);
        equip_picker_open = false;
    }
}

// Compendium tab (4): W/S or Up/Down browse sections (hold-repeat + wrap)
if (menu_tab == 4) {
    var _comp_count = array_length(ui_compendium_sections());
    if (nav_down()) compendium_section = wrap_index(compendium_section + 1, _comp_count);
    if (nav_up())   compendium_section = wrap_index(compendium_section - 1, _comp_count);
}

// Abilities tab (2): W/S browse the loadout (left list -> right breakdown).
if (menu_tab == 2 && variable_global_exists("chosen_class")) {
    var _abil_count = array_length(abilities_resolve_player_loadout(global.chosen_class));
    if (_abil_count > 0) {
        if (nav_down()) ability_view_cursor = wrap_index(ability_view_cursor + 1, _abil_count);
        if (nav_up())   ability_view_cursor = wrap_index(ability_view_cursor - 1, _abil_count);
    }
}

// Mouse input for the character menu overlay
if (mouse_check_button_pressed(mb_left)) {
    var _mmx = device_mouse_x_to_gui(0);
    var _mmy = device_mouse_y_to_gui(0);

    // --- Tab bar: tab t starts at x = 306+t*264, y=30, w=252, h=66 (5 tabs, centered) ---
    for (var _mt = 0; _mt < 5; _mt++) {
        var _tx = 306 + _mt * 264;
        if (_mmx >= _tx && _mmx < _tx+252 && _mmy >= 30 && _mmy < 96) {
            menu_tab                = _mt;
            equip_picker_open       = false;
            consumable_submenu_open = false;
            break;
        }
    }

    // --- Compendium tab (4): click a section in the left list ---
    if (menu_tab == 4) {
        var _comp_secs = ui_compendium_sections();
        for (var _mcs = 0; _mcs < array_length(_comp_secs); _mcs++) {
            var _csy = 135 + _mcs * 69;
            if (_mmx >= 60 && _mmx < 450 && _mmy >= _csy && _mmy < _csy + 60) {
                compendium_section = _mcs;
                break;
            }
        }
    }

    // --- Equipment tab (1) ---
    if (menu_tab == 1) {
        if (!equip_picker_open) {
            // Click an equipment slot -> select and open picker. Single-column list
            // on the right (geometry mirrors ui_draw_character_menu equipment tab:
            // list x740..1850, rows from y166, height ~83).
            for (var _msl = 0; _msl < EQUIP_SLOT_COUNT; _msl++) {
                var _msly = 166 + _msl * 83;
                if (_mmx >= 740 && _mmx < 1850 && _mmy >= _msly && _mmy < _msly+80) {
                    equip_slot_selected = _msl;
                    equip_picker_open   = true;
                    equip_picker_index  = 0;
                    equip_msg           = "";
                    break;
                }
            }
        } else {
            // Picker is open - click a row to equip. Filter by the item-TYPE the
            // position accepts (Ring 2 accepts "ring" items).
            var _msel_inv  = equip_display_to_inv(equip_slot_selected);
            var _mpslname  = equip_position_item_slot(_msel_inv);
            var _mpitems   = [];
            var _mpsrc     = [];
            // Stash is hub-only: during a run you can only equip from your pack.
            var _mp_in_hub = (room == rm_hub || room == rm_character_select);
            if (_mp_in_hub) {
                for (var _mpi = 0; _mpi < array_length(global.equipment_stash); _mpi++) {
                    if (global.equipment_stash[_mpi].slot == _mpslname) {
                        array_push(_mpitems, global.equipment_stash[_mpi]);
                        array_push(_mpsrc, { source: 0, idx: _mpi });
                    }
                }
            }
            for (var _mpi = 0; _mpi < array_length(global.carried_items); _mpi++) {
                if (global.carried_items[_mpi].slot == _mpslname) {
                    array_push(_mpitems, global.carried_items[_mpi]);
                    array_push(_mpsrc, { source: 1, idx: _mpi });
                }
            }
            // Selectable rows are pushed down one row when an item is worn in this
            // slot (the dimmed "[Equipped]" row occupies the top - see scr_ui picker).
            var _mp_eq_off = (global.inventory[_msel_inv] != undefined) ? 108 : 0;
            for (var _mri = 0; _mri < array_length(_mpitems); _mri++) {
                var _mpry = 228 + _mp_eq_off + _mri * 108;
                if (_mmx >= 366 && _mmx < 1554 && _mmy >= _mpry && _mmy < _mpry+102) {
                    equip_picker_index = _mri;
                    var _mchosen  = _mpitems[_mri];
                    var _mcr      = variable_struct_exists(_mchosen, "class_req") ? _mchosen.class_req : -1;
                    var _mpcl     = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                    var _msreq = equip_stat_block_reason(_mchosen);
                    if (_mcr != -1 && _mcr != _mpcl) {
                        var _mcrnames = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                        equip_msg = _mchosen.name + " requires " + _mcrnames[_mcr] + ".";
                    } else if (_msreq != "") {
                        equip_msg = _msreq;
                    } else if (_msel_inv == 1 && hard_two_handed_equipped()) {
                        // Offhand slot is locked while a greatsword/longbow 2H is equipped.
                        equip_msg = "Two-handed weapon equipped - offhand is locked.";
                    } else if (_msel_inv == 1 && caster_staff_equipped() && item_is_shield_offhand(_mchosen)) {
                        equip_msg = "A two-handed staff cannot also hold a shield.";
                    } else if (_msel_inv == 0 && caster_staff_equipped()) {
                        equip_msg = "A two-handed staff is equipped - no melee weapon.";
                    } else {
                        equip_msg = "";
                        var _msinfo = _mpsrc[_mri];
                        var _mold   = global.inventory[_msel_inv];
                        if (_msinfo.source == 0) {
                            array_delete(global.equipment_stash, _msinfo.idx, 1);
                            if (_mold != undefined) array_push(global.equipment_stash, _mold);
                        } else {
                            array_delete(global.carried_items, _msinfo.idx, 1);
                            if (_mold != undefined) array_push(global.carried_items, _mold);
                        }
                        global.inventory[_msel_inv] = _mchosen;
                        // 2H weapon vacates the offhand. A caster staff only displaces a
                        // SHIELD (keeps a focus/tome) and clears any melee weapon; other
                        // 2H weapons displace any offhand. (Task 10)
                        if ((_msel_inv == 0 || _msel_inv == 8) && item_is_two_handed(_mchosen)) {
                            if (item_is_caster_2h(_mchosen)) {
                                if (item_is_shield_offhand(global.inventory[1])) return_offhand_to_pack(_mp_in_hub);
                                return_inv_slot_to_pack(0, _mp_in_hub);
                            } else {
                                return_offhand_to_pack(_mp_in_hub);
                            }
                        }
                        equip_notif_msg   = "Equipped " + _mchosen.name + "  ->  " + string_upper(_mpslname);
                        equip_notif_timer = 150;
                        audio_play_sound(Check_1, 1, false);
                        equip_picker_open = false;
                        // Persist the equip - but only in the hub, where both the slot
                        // and the source (stash) are saved. Mid-run equips stay unsaved
                        // so an abandoned run reverts cleanly (carried pack isn't saved).
                        if (room == rm_hub || room == rm_character_select) save_game();
                    }
                    break;
                }
            }
        }
    }

    // --- Abilities tab (2): click a row in the left list to select it ---
    if (menu_tab == 2 && variable_global_exists("chosen_class")) {
        var _alist = abilities_resolve_player_loadout(global.chosen_class);
        var _alcnt = array_length(_alist);
        if (_alcnt > 0 && _mmx >= 86 && _mmx < 684) {
            var _alrh = min(108, (830) / _alcnt);   // mirrors the draw (panel 150..1012, pad 16)
            for (var _ali = 0; _ali < _alcnt; _ali++) {
                var _aly = 166 + _ali * _alrh;
                if (_mmy >= _aly && _mmy < _aly + _alrh - 6) { ability_view_cursor = _ali; break; }
            }
        }
    }

    // --- Consumables tab (3) ---
    if (menu_tab == 3) {
        // Grouped view (one row per distinct consumable); clicks map back to a real
        // inventory index. Mirrors the scr_ui draw + the keyboard handler.
        var _mgroups = consumables_grouped();
        var _mcons   = array_length(_mgroups);
        // Same windowing as the draw (scr_ui) so clicks land on the visible rows.
        var _mcons_max_vis = 7;
        var _mcons_first   = ui_list_window_first(consumable_submenu_cursor, _mcons, _mcons_max_vis);
        var _mcons_last    = min(_mcons, _mcons_first + _mcons_max_vis);
        for (var _mci = _mcons_first; _mci < _mcons_last; _mci++) {
            var _mcy = 195 + (_mci - _mcons_first) * 120;
            if (_mmx >= 60 && _mmx < 1350 && _mmy >= _mcy && _mmy < _mcy+98) {
                if (!consumable_submenu_open) {
                    consumable_submenu_open   = true;
                    consumable_submenu_cursor = _mci;
                } else if (consumable_submenu_cursor == _mci) {
                    // Click already-highlighted item -> use it
                    var _mcan = true;
                    // AP-restore items ("energy") cost no AP, so they work at 0 AP too.
                    var _m_is_ap = (_mci < array_length(_mgroups)
                        && _mgroups[_mci].item.effect_type == "energy");
                    if (instance_exists(obj_combat_controller)) {
                        var _mctrl = instance_find(obj_combat_controller, 0);
                        if (!_mctrl.player_turn && items_used_this_turn >= 1) _mcan = false;
                        if (_mctrl.player_turn && _mctrl.player.energy < 1 && !_m_is_ap) {
                            _mcan = false;
                            array_push(_mctrl.combat_log, "Need 1 AP to use an item!");
                        }
                    }
                    if (_mcan && _mci < array_length(_mgroups)) {
                        var _mreal_idx = _mgroups[_mci].first_index;
                        var _mit = _mgroups[_mci].item;
                        var _mused = false;
                        if (instance_exists(obj_combat_controller)) {
                            var _mctrl2 = instance_find(obj_combat_controller, 0);
                            var _mplyr  = _mctrl2.player;
                            _mused = true;
                            if (_mit.effect_type == "heal") {
                                var _mheal = min(_mplyr.max_HP - _mplyr.HP, _mit.effect_value);
                                _mplyr.HP += _mheal;
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + " - restored " + string(_mheal) + " HP!");
                            } else if (_mit.effect_type == "energy") {
                                // Burst AP: no cap (can exceed the 3-AP turn limit) and no use cost.
                                _mplyr.energy += _mit.effect_value;
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + " - +" + string(_mit.effect_value) + " AP!");
                            } else if (_mit.effect_type == "cleanse_dot") {
                                var _mcl = combat_cleanse(_mplyr, "dot");
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + (_mcl > 0
                                    ? " - cleared " + string(_mcl) + " damage-over-time effect(s)!"
                                    : " - no DoT effects to clear."));
                            } else if (_mit.effect_type == "cleanse_debuff") {
                                var _mcl = combat_cleanse(_mplyr, "one");
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + (_mcl > 0
                                    ? " - removed a debuff!" : " - no debuff to remove."));
                            } else if (_mit.effect_type == "cleanse_all") {
                                var _mcl = combat_cleanse(_mplyr, "all");
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + (_mcl > 0
                                    ? " - cleared " + string(_mcl) + " negative effect(s)!"
                                    : " - no negative effects to clear."));
                            } else if (_mit.effect_type == "gold_find_pot") {
                                potion_drink_gold(_mit.effect_value);
                                array_push(_mctrl2.combat_log, "Used " + _mit.name
                                    + " - gold drops +" + string(_mit.effect_value) + "% until 2 bosses fall!");
                            } else if (_mit.effect_type == "loot_find_pot") {
                                potion_drink_loot(_mit.effect_value);
                                array_push(_mctrl2.combat_log, "Used " + _mit.name
                                    + " - loot chance +" + string(_mit.effect_value) + "% until 2 bosses fall!");
                            }
                            // AP-restore items are free; everything else costs 1 AP on your turn.
                            if (_mctrl2.player_turn) {
                                if (_mit.effect_type != "energy") {
                                    _mctrl2.player.energy -= 1;
                                    array_push(_mctrl2.combat_log, "  [-1 AP]");
                                }
                            } else {
                                items_used_this_turn++;
                            }
                        } else {
                            // Out of combat: heals apply to the persistent run HP;
                            // non-heal items have no effect here and are not consumed.
                            _mused = consumable_use_out_of_combat(_mit);
                        }
                        if (_mused) {
                            array_delete(global.consumable_inventory, _mreal_idx, 1);
                            var _mg2 = array_length(consumables_grouped());
                            consumable_submenu_cursor = min(_mci, max(0, _mg2 - 1));
                            if (_mg2 == 0) consumable_submenu_open = false;
                        }
                    }
                } else {
                    consumable_submenu_cursor = _mci;
                }
                break;
            }
        }
    }
}


// =============================================================================
// EQUIPMENT TAB - slot select, picker, unequip
// =============================================================================
if (menu_tab == 1) {
    // equip_slot_selected is the VISUAL list row (single column, 0..9); the actual
    // inventory index is mapped through equip_display_to_inv so Ring 2 can sit under
    // Ring 1 without remapping stored slots.
    var _sel_inv = equip_display_to_inv(equip_slot_selected);

    if (!equip_picker_open) {
        // ===== Found-items (pack) column: focus / browse / sort / equip =====
        // The right column lists the pack. A/<- focuses the slots, D/-> the found list;
        // a click focuses whichever was clicked. Q/E stay reserved for tab switching.
        var _found   = equip_found_list(equip_found_sort);
        var _found_n = array_length(_found);
        equip_found_cursor = clamp(equip_found_cursor, 0, max(0, _found_n - 1));

        if (mouse_check_button_pressed(mb_left)) {
            var _emx = device_mouse_x_to_gui(0);
            var _emy = device_mouse_y_to_gui(0);
            if (_emx >= 1652 && _emx <= 1842 && _emy >= 162 && _emy <= 202) {
                equip_found_sort = (equip_found_sort + 1) mod 2;   // sort toggle button
            } else if (_emx >= 1360 && _emx <= 1862 && _emy >= 150 && _emy <= 1012) {
                equip_found_focus = true;   // clicking the column focuses it even when empty
                if (_found_n > 0) {
                    var _ffirst = ui_list_window_first(equip_found_cursor, _found_n, 12);
                    var _frow   = floor((_emy - 236) / 60);
                    if (_frow >= 0 && _frow < min(12, _found_n - _ffirst)) equip_found_cursor = clamp(_ffirst + _frow, 0, _found_n - 1);
                }
            } else if (_emx >= 580 && _emx <= 1340 && _emy >= 150 && _emy <= 1012) {
                equip_found_focus = false;
                var _srow = floor((_emy - 166) / 83);
                if (_srow >= 0 && _srow < EQUIP_SLOT_COUNT) equip_slot_selected = _srow;
            }
        }
        if (keyboard_check_pressed(ord("D")) || keyboard_check_pressed(vk_right)) equip_found_focus = true;   // lateral swap (works even if pack empty)
        if (keyboard_check_pressed(ord("A")) || keyboard_check_pressed(vk_left))  equip_found_focus = false;

        if (equip_found_focus) {
            if (_found_n > 0 && nav_up())   equip_found_cursor = wrap_index(equip_found_cursor - 1, _found_n);
            if (_found_n > 0 && nav_down()) equip_found_cursor = wrap_index(equip_found_cursor + 1, _found_n);
            equip_found_cursor = clamp(equip_found_cursor, 0, max(0, _found_n - 1));

            // Enter equips the highlighted found item into its slot.
            if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && _found_n > 0) {
                var _fitem = _found[equip_found_cursor].item;
                var _fsrc  = _found[equip_found_cursor].idx;
                var _fsrctype = variable_struct_exists(_found[equip_found_cursor], "src") ? _found[equip_found_cursor].src : 1; // 0 stash / 1 pack
                var _ftgt  = equip_target_inv_for_slot(_fitem.slot);
                var _fcr   = variable_struct_exists(_fitem, "class_req") ? _fitem.class_req : -1;
                var _fmycl = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                var _fsreq = equip_stat_block_reason(_fitem);
                if (_ftgt == -1) {
                    equip_msg = "Can't equip that item.";
                } else if (_fcr != -1 && _fcr != _fmycl) {
                    var _fcn = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                    equip_msg = _fitem.name + " requires " + ((_fcr >= 0 && _fcr <= 2) ? _fcn[_fcr] : "another class") + ".";
                } else if (_fsreq != "") {
                    equip_msg = _fsreq;
                } else if (_ftgt == 1 && hard_two_handed_equipped()) {
                    equip_msg = "Two-handed weapon equipped - offhand is locked.";
                } else if (_ftgt == 1 && caster_staff_equipped() && item_is_shield_offhand(_fitem)) {
                    equip_msg = "A two-handed staff cannot also hold a shield.";
                } else if (_ftgt == 0 && caster_staff_equipped()) {
                    equip_msg = "A two-handed staff is equipped - no melee weapon.";
                } else {
                    var _fhub = (room == rm_hub || room == rm_character_select);
                    var _fold = global.inventory[_ftgt];
                    // Remove the chosen item from its own source (stash or pack), and return
                    // the previously-equipped item to that same source.
                    if (_fsrctype == 0) {
                        array_delete(global.equipment_stash, _fsrc, 1);
                        if (_fold != undefined) array_push(global.equipment_stash, _fold);
                    } else {
                        array_delete(global.carried_items, _fsrc, 1);
                        if (_fold != undefined) array_push(global.carried_items, _fold);
                    }
                    global.inventory[_ftgt] = _fitem;
                    if ((_ftgt == 0 || _ftgt == 8) && item_is_two_handed(_fitem)) {
                        if (item_is_caster_2h(_fitem)) {
                            if (item_is_shield_offhand(global.inventory[1])) return_offhand_to_pack(_fhub);
                            return_inv_slot_to_pack(0, _fhub);
                        } else {
                            return_offhand_to_pack(_fhub);
                        }
                    }
                    equip_notif_msg   = "Equipped " + _fitem.name + "  ->  " + string_upper(_fitem.slot);
                    equip_notif_timer = 150;
                    equip_msg         = "";
                    audio_play_sound(Check_1, 1, false);
                    if (_fhub) save_game();
                    // List rebuilds next frame (stash + pack); just keep the cursor non-negative,
                    // the draw/Step re-clamp to the new length.
                    equip_found_cursor = max(0, equip_found_cursor);
                }
            }
        } else {
        // Single-column navigation - W/S wrap through all 10 slot rows.
        if (nav_up())   equip_slot_selected = wrap_index(equip_slot_selected - 1, EQUIP_SLOT_COUNT);
        if (nav_down()) equip_slot_selected = wrap_index(equip_slot_selected + 1, EQUIP_SLOT_COUNT);
        _sel_inv = equip_display_to_inv(equip_slot_selected);

        // Enter opens the item picker for this slot
        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
            equip_picker_open  = true;
            equip_picker_index = 0;
        }

        // U unequips the selected slot
        if (keyboard_check_pressed(ord("U"))) {
            var _old = global.inventory[_sel_inv];
            if (_old != undefined) {
                global.inventory[_sel_inv] = undefined;
                var _in_hub = (room == rm_hub || room == rm_character_select);
                if (_in_hub) {
                    array_push(global.equipment_stash, _old);
                } else {
                    array_push(global.carried_items, _old);
                }
                // Persist the unequip only in the hub. Mid-run the item goes to the
                // un-saved carried pack, so saving an empty slot here would lose it.
                if (_in_hub) save_game();
            }
        }
        }   // end slot-focus branch

    } else {
        // Picker open - build filtered list for the selected slot every frame. Use the
        // item-TYPE the position accepts (Ring 2 accepts "ring" items) so rings list for
        // either ring position.
        var _slot_name   = equip_position_item_slot(_sel_inv);
        var _picker_items = [];
        var _picker_src   = [];   // { source: 0=stash/1=carried, idx: original_index }
        // Stash is hub-only: during a run you can only equip from your pack.
        var _picker_in_hub = (room == rm_hub || room == rm_character_select);
        if (_picker_in_hub) {
            for (var _pi = 0; _pi < array_length(global.equipment_stash); _pi++) {
                if (global.equipment_stash[_pi].slot == _slot_name) {
                    array_push(_picker_items, global.equipment_stash[_pi]);
                    array_push(_picker_src, { source: 0, idx: _pi });
                }
            }
        }
        for (var _pi = 0; _pi < array_length(global.carried_items); _pi++) {
            if (global.carried_items[_pi].slot == _slot_name) {
                array_push(_picker_items, global.carried_items[_pi]);
                array_push(_picker_src, { source: 1, idx: _pi });
            }
        }
        var _picker_count = array_length(_picker_items);

        if (nav_up())   { if (_picker_count > 0) equip_picker_index = wrap_index(equip_picker_index - 1, _picker_count); equip_msg = ""; }
        if (nav_down()) { if (_picker_count > 0) equip_picker_index = wrap_index(equip_picker_index + 1, _picker_count); equip_msg = ""; }

        if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && _picker_count == 0) {
            equip_picker_open = false;
            equip_msg         = "";
        }
        if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && _picker_count > 0) {
            var _chosen   = _picker_items[equip_picker_index];

            // Class restriction check
            var _chosen_cr = variable_struct_exists(_chosen, "class_req") ? _chosen.class_req : -1;
            var _player_cl = variable_global_exists("chosen_class") ? global.chosen_class : -1;
            var _ksreq     = equip_stat_block_reason(_chosen);
            if (_chosen_cr != -1 && _chosen_cr != _player_cl) {
                var _class_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                var _req_name    = (_chosen_cr >= 0 && _chosen_cr <= 2) ? _class_names[_chosen_cr] : "Unknown";
                equip_msg = _chosen.name + " requires " + _req_name + ".";
                // Don't equip - skip the rest of the block
            } else if (_ksreq != "") {
                equip_msg = _ksreq;   // hard block: stat requirement not met
            } else if (_sel_inv == 1 && hard_two_handed_equipped()) {
                // Offhand slot is locked while a greatsword/longbow 2H is equipped.
                equip_msg = "Two-handed weapon equipped - offhand is locked.";
            } else if (_sel_inv == 1 && caster_staff_equipped() && item_is_shield_offhand(_chosen)) {
                equip_msg = "A two-handed staff cannot also hold a shield.";
            } else if (_sel_inv == 0 && caster_staff_equipped()) {
                equip_msg = "A two-handed staff is equipped - no melee weapon.";
            } else {
            equip_msg = "";

            var _src_info = _picker_src[equip_picker_index];
            var _old      = global.inventory[_sel_inv];

            // Remove chosen item from its source array
            if (_src_info.source == 0) {
                array_delete(global.equipment_stash, _src_info.idx, 1);
                if (_old != undefined) array_push(global.equipment_stash, _old);
            } else {
                array_delete(global.carried_items, _src_info.idx, 1);
                if (_old != undefined) array_push(global.carried_items, _old);
            }

            global.inventory[_sel_inv] = _chosen;
            // A 2H weapon vacates the offhand. A caster staff only displaces a SHIELD
            // (keeps a focus/tome) and clears any melee weapon; other 2H weapons
            // displace any offhand. (Task 10)
            if ((_sel_inv == 0 || _sel_inv == 8) && item_is_two_handed(_chosen)) {
                if (item_is_caster_2h(_chosen)) {
                    if (item_is_shield_offhand(global.inventory[1])) return_offhand_to_pack(_picker_in_hub);
                    return_inv_slot_to_pack(0, _picker_in_hub);
                } else {
                    return_offhand_to_pack(_picker_in_hub);
                }
            }
            equip_notif_msg   = "Equipped " + _chosen.name + "  ->  " + string_upper(_slot_name);
            equip_notif_timer = 150;
            audio_play_sound(Check_1, 1, false);
            equip_picker_open = false;
            // Persist the equip only in the hub (see unequip/Maren notes above):
            // mid-run the source is the un-saved carried pack.
            if (_picker_in_hub) save_game();
            } // end class_req else block
        }

        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
            equip_picker_open = false;
            equip_msg = "";
        }
    }
}


// =============================================================================
// CONSUMABLE TAB - item submenu (W/S navigate, Enter use, Esc cancel)
// =============================================================================
if (menu_tab == 3) {

    if (consumable_submenu_open) {
        // Grouped view: identical consumables show as one "Name xN" row; cursor + use
        // map back through it to a real inventory index. Mirrors the scr_ui draw.
        var _cgroups  = consumables_grouped();
        var _cons_cnt = array_length(_cgroups);

        // Navigate (hold-repeat + wrap)
        if (nav_up())   consumable_submenu_cursor = wrap_index(consumable_submenu_cursor - 1, _cons_cnt);
        if (nav_down()) consumable_submenu_cursor = wrap_index(consumable_submenu_cursor + 1, _cons_cnt);

        // Close without using
        if (keyboard_check_pressed(vk_escape)) {
            consumable_submenu_open = false;
        }

        // Use selected item
        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
            var _can_use = true;
            // AP-restore items ("energy") and the resource+AP brew ("resource_ap") cost
            // no AP, so they stay usable at 0 AP.
            var _sel_et    = (_cons_cnt > 0 && consumable_submenu_cursor < _cons_cnt)
                ? _cgroups[consumable_submenu_cursor].item.effect_type : "";
            var _sel_is_ap = (_sel_et == "energy" || _sel_et == "resource_ap");
            if (instance_exists(obj_combat_controller)) {
                var _ctrl_c = instance_find(obj_combat_controller, 0);
                if (!_ctrl_c.player_turn && items_used_this_turn >= 1) {
                    _can_use = false;
                }
                if (_ctrl_c.player_turn && _ctrl_c.player.energy < 1 && !_sel_is_ap) {
                    _can_use = false;
                    array_push(_ctrl_c.combat_log, "Need 1 AP to use an item!");
                }
            }
            if (_can_use && _cons_cnt > 0 && consumable_submenu_cursor < _cons_cnt) {
                var _real_idx = _cgroups[consumable_submenu_cursor].first_index;
                var _item = _cgroups[consumable_submenu_cursor].item;
                var _used = false;
                if (instance_exists(obj_combat_controller)) {
                    var _ctrl_c = instance_find(obj_combat_controller, 0);
                    var _player = _ctrl_c.player;
                    _used = true;
                    if (_item.effect_type == "heal") {
                        var _heal = min(_player.max_HP - _player.HP, _item.effect_value);
                        _player.HP += _heal;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " - restored " + string(_heal) + " HP!");
                    } else if (_item.effect_type == "energy") {
                        // Burst AP: no cap (can exceed the 3-AP turn limit) and no use cost.
                        _player.energy += _item.effect_value;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " - +" + string(_item.effect_value) + " AP!");
                    } else if (_item.effect_type == "cleanse_dot") {
                        var _cl = combat_cleanse(_player, "dot");
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + (_cl > 0
                            ? " - cleared " + string(_cl) + " damage-over-time effect(s)!"
                            : " - no DoT effects to clear."));
                    } else if (_item.effect_type == "cleanse_debuff") {
                        var _cl = combat_cleanse(_player, "one");
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + (_cl > 0
                            ? " - removed a debuff!" : " - no debuff to remove."));
                    } else if (_item.effect_type == "cleanse_all") {
                        var _cl = combat_cleanse(_player, "all");
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + (_cl > 0
                            ? " - cleared " + string(_cl) + " negative effect(s)!"
                            : " - no negative effects to clear."));
                    } else if (_item.effect_type == "shield") {
                        if (!variable_struct_exists(_player, "shield_hp")) _player.shield_hp = 0;
                        _player.shield_hp += _item.effect_value;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name
                            + " - gained a " + string(_item.effect_value) + "-point shield!");
                    } else if (_item.effect_type == "heal_dot") {
                        if (!variable_struct_exists(_player, "status_effects")) _player.status_effects = [];
                        array_push(_player.status_effects, {
                            name: _item.name, kind: "regen", effect_type: "heal_dot",
                            effect_value: _item.effect_value, duration: 3, element: ""
                        });
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " - regenerating "
                            + string(_item.effect_value) + " HP/turn for 3 turns.");
                    } else if (_item.effect_type == "resource_ap") {
                        // Ley Battery: +N class secondary resource AND +1 burst AP (free).
                        var _ley_res2   = _item.effect_value;
                        var _ley_label2 = "resource";
                        if (variable_struct_exists(_player, "souls")) {
                            _player.souls = min(_player.souls_max, _player.souls + _ley_res2); _ley_label2 = "Souls";
                        } else if (variable_struct_exists(_player, "blood")) {
                            _player.blood = min(_player.blood_max, _player.blood + _ley_res2); _ley_label2 = "Blood";
                        } else if (variable_struct_exists(_player, "preparation")) {
                            _player.preparation = min(_player.preparation_max, _player.preparation + _ley_res2); _ley_label2 = "Preparation";
                        }
                        _player.energy += 1;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name
                            + " - +" + string(_ley_res2) + " " + _ley_label2 + " and +1 AP!");
                    } else if (_item.effect_type == "gold_find_pot") {
                        potion_drink_gold(_item.effect_value);
                        array_push(_ctrl_c.combat_log, "Used " + _item.name
                            + " - gold drops +" + string(_item.effect_value) + "% until 2 bosses fall!");
                    } else if (_item.effect_type == "loot_find_pot") {
                        potion_drink_loot(_item.effect_value);
                        array_push(_ctrl_c.combat_log, "Used " + _item.name
                            + " - loot chance +" + string(_item.effect_value) + "% until 2 bosses fall!");
                    }
                    // AP-restore items are free; everything else costs 1 AP on your turn.
                    if (_ctrl_c.player_turn) {
                        if (_item.effect_type != "energy" && _item.effect_type != "resource_ap") {
                            _ctrl_c.player.energy -= 1;
                            array_push(_ctrl_c.combat_log, "  [-1 AP]");
                        }
                    } else {
                        items_used_this_turn++;
                    }
                } else {
                    // Out of combat (hub / floor map): apply heals to the persistent
                    // run HP. Items with no out-of-combat effect are NOT consumed.
                    _used = consumable_use_out_of_combat(_item);
                }
                if (_used) {
                    array_delete(global.consumable_inventory, _real_idx, 1);
                    var _cg2 = array_length(consumables_grouped());
                    consumable_submenu_cursor = min(consumable_submenu_cursor, max(0, _cg2 - 1));
                    if (_cg2 == 0) {
                        consumable_submenu_open = false;
                    }
                }
            }
        }

    } else {
        // Submenu closed - Enter opens it (only when items exist)
        if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter))
            && array_length(global.consumable_inventory) > 0) {
            consumable_submenu_open   = true;
            consumable_submenu_cursor = 0;
        }
    }
}

// Close submenu automatically when switching away from the consumables tab
if (menu_tab != 3) {
    consumable_submenu_open = false;
}

// Reset item use counter each player turn
if (instance_exists(obj_combat_controller)) {
    var _ctrl = instance_find(obj_combat_controller, 0);
    if (_ctrl.player_turn) items_used_this_turn = 0;
}


