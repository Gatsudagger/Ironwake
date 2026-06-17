// Tick trait unlock notification timer
if (trait_notif_timer > 0) {
    trait_notif_timer--;
    if (trait_notif_timer <= 0) trait_notif_msg = "";
}

if (!stash_mode_open && !loadout_open && keyboard_check_pressed(ord("I"))) {
    menu_open = !menu_open;
    menu_tab  = 0;
    equip_picker_open       = false;
    consumable_submenu_open = false;
}


// =============================================================================
// STASH SCREEN — runs before the menu_open guard so it fires when menu is closed
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
    if (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))) {
        stash_mode_index = max(0, stash_mode_index - 1);
    }
    if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
        stash_mode_index = min(max(0, _cur_count - 1), stash_mode_index + 1);
    }

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
    }

    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
        stash_mode_open = false;
    }
    exit;
}

// =============================================================================
// LEVEL-UP ALLOCATION — handled here so ui_input_blocked() can freeze the
// combat controller's Step while the overlay is active without breaking input.
// =============================================================================
if (level_alloc_open) {
    if (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))) {
        level_alloc_index = max(0, level_alloc_index - 1);
    }
    if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
        level_alloc_index = min(5, level_alloc_index + 1);
    }

    // Enter: set or move the provisional stat choice — does NOT commit yet
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
        // Update live player stats if in combat — CON recalcs HP only on confirm
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
// SHOP INPUT — runs before menu_open guard; gc handles all buy/sell logic
// =============================================================================
if (shop_open != -1 && !stash_mode_open) {

    // Q/E: switch between BUY and SELL tabs
    if (keyboard_check_pressed(ord("Q")) || keyboard_check_pressed(ord("E"))) {
        shop_tab          = 1 - shop_tab;
        sell_index        = 0;
        sell_scroll       = 0;
        sell_confirm_name = "";
        shop_notification = "";
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
            var _sell_price = max(1, floor(_gv * 0.4));

            // Rare-or-above items need a second confirmation step
            var _needs_confirm = variable_struct_exists(_cur_item, "rarity") && _cur_item.rarity >= 2;

            // W/S: navigate (clears any pending confirm)
            if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
                sell_index        = max(0, sell_index - 1);
                sell_confirm_name = "";
                shop_notification = "";
            }
            if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
                sell_index        = min(max(0, _sl_count - 1), sell_index + 1);
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
    // BUY TAB (original buy logic — unchanged)
    // =========================================================================
    var _is_petra = (shop_open == 0);

    if (_is_petra) {
        var _has_spec  = (global.petra_stock_special != undefined && global.petra_special_qty > 0);
        var _petra_max = 3 + (_has_spec ? 1 : 0);

        if (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))) {
            shop_index = max(0, shop_index - 1);
            shop_notification = "";
        }
        if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
            shop_index = min(_petra_max, shop_index + 1);
            shop_notification = "";
        }

        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
            var _sit;
            var _sprice;
            if (shop_index < 4) {
                _sit    = global.consumables_standard[shop_index];
                _sprice = floor(_sit.gold_value * 1.5);
            } else {
                _sit    = global.petra_stock_special;
                _sprice = floor(_sit.gold_value * 2);
            }
            if (global.gold >= _sprice) {
                global.gold -= _sprice;
                var _fresh = create_consumable(_sit.name, _sit.effect_type, _sit.effect_value,
                                               _sit.description, _sit.gold_value);
                array_push(global.consumable_stash, _fresh);
                if (shop_index == 4 && _has_spec) {
                    global.petra_special_qty--;
                    if (global.petra_special_qty <= 0) {
                        global.petra_stock_special = undefined;
                        global.petra_special_qty   = 0;
                        shop_index = min(shop_index, 3);
                    }
                }
                shop_notification = "Purchased — added to consumable stash.";
            } else {
                shop_notification = "Not enough gold!";
            }
        }

    } else {
        // Dorn
        var _dorn_len = array_length(global.dorn_stock);

        if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
            shop_notification = "";
            var _prev = shop_index - 1;
            while (_prev >= 0 && global.dorn_stock[_prev].sold) _prev--;
            if (_prev >= 0) shop_index = _prev;
        }
        if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
            shop_notification = "";
            var _next = shop_index + 1;
            while (_next < _dorn_len && global.dorn_stock[_next].sold) _next++;
            if (_next < _dorn_len) shop_index = _next;
        }

        if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && _dorn_len > 0
            && !global.dorn_stock[shop_index].sold) {
            var _dentry = global.dorn_stock[shop_index];
            if (global.gold >= _dentry.price) {
                global.gold -= _dentry.price;
                array_push(global.equipment_stash, _dentry.item);
                global.dorn_stock[shop_index].sold = true;
                shop_notification = "Purchased — added to equipment stash.";
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

    exit;
}

if (!menu_open) exit;

// Q/E cycle tabs (blocked while picker or consumable submenu is open)
if (!equip_picker_open && !consumable_submenu_open) {
    if (keyboard_check_pressed(ord("Q"))) {
        menu_tab = (menu_tab - 1 + 4) mod 4;
        equip_picker_open = false;
    }
    if (keyboard_check_pressed(ord("E"))) {
        menu_tab = (menu_tab + 1) mod 4;
        equip_picker_open = false;
    }
}


// =============================================================================
// EQUIPMENT TAB — slot select, picker, unequip
// =============================================================================
if (menu_tab == 1) {
    var _slot_keys = ["weapon", "offhand", "helm", "chest", "gloves", "boots", "amulet", "ring"];

    if (!equip_picker_open) {
        // W/S moves slot cursor
        if (keyboard_check_pressed(ord("W")) || keyboard_check_pressed(vk_up)) {
            equip_slot_selected = max(0, equip_slot_selected - 1);
        }
        if (keyboard_check_pressed(ord("S")) || keyboard_check_pressed(vk_down)) {
            equip_slot_selected = min(7, equip_slot_selected + 1);
        }

        // Enter opens the item picker for this slot
        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
            equip_picker_open  = true;
            equip_picker_index = 0;
        }

        // U unequips the selected slot
        if (keyboard_check_pressed(ord("U"))) {
            var _old = global.inventory[equip_slot_selected];
            if (_old != undefined) {
                global.inventory[equip_slot_selected] = undefined;
                var _in_hub = (room == rm_hub || room == rm_character_select);
                if (_in_hub) {
                    array_push(global.equipment_stash, _old);
                } else {
                    array_push(global.carried_items, _old);
                }
            }
        }

    } else {
        // Picker open — build filtered list for the selected slot every frame
        var _slot_name   = _slot_keys[equip_slot_selected];
        var _picker_items = [];
        var _picker_src   = [];   // { source: 0=stash/1=carried, idx: original_index }
        for (var _pi = 0; _pi < array_length(global.equipment_stash); _pi++) {
            if (global.equipment_stash[_pi].slot == _slot_name) {
                array_push(_picker_items, global.equipment_stash[_pi]);
                array_push(_picker_src, { source: 0, idx: _pi });
            }
        }
        for (var _pi = 0; _pi < array_length(global.carried_items); _pi++) {
            if (global.carried_items[_pi].slot == _slot_name) {
                array_push(_picker_items, global.carried_items[_pi]);
                array_push(_picker_src, { source: 1, idx: _pi });
            }
        }
        var _picker_count = array_length(_picker_items);

        if (keyboard_check_pressed(ord("W")) || keyboard_check_pressed(vk_up)) {
            equip_picker_index = max(0, equip_picker_index - 1);
            equip_msg = "";
        }
        if (keyboard_check_pressed(ord("S")) || keyboard_check_pressed(vk_down)) {
            equip_picker_index = min(max(0, _picker_count - 1), equip_picker_index + 1);
            equip_msg = "";
        }

        if ((keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) && _picker_count > 0) {
            var _chosen   = _picker_items[equip_picker_index];

            // Class restriction check
            var _chosen_cr = variable_struct_exists(_chosen, "class_req") ? _chosen.class_req : -1;
            var _player_cl = variable_global_exists("chosen_class") ? global.chosen_class : -1;
            if (_chosen_cr != -1 && _chosen_cr != _player_cl) {
                var _class_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                var _req_name    = (_chosen_cr >= 0 && _chosen_cr <= 2) ? _class_names[_chosen_cr] : "Unknown";
                equip_msg = _chosen.name + " requires " + _req_name + ".";
                // Don't equip — skip the rest of the block
            } else {
            equip_msg = "";

            var _src_info = _picker_src[equip_picker_index];
            var _old      = global.inventory[equip_slot_selected];

            // Remove chosen item from its source array
            if (_src_info.source == 0) {
                array_delete(global.equipment_stash, _src_info.idx, 1);
                if (_old != undefined) array_push(global.equipment_stash, _old);
            } else {
                array_delete(global.carried_items, _src_info.idx, 1);
                if (_old != undefined) array_push(global.carried_items, _old);
            }

            global.inventory[equip_slot_selected] = _chosen;
            equip_picker_open = false;
            } // end class_req else block
        }

        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
            equip_picker_open = false;
            equip_msg = "";
        }
    }
}


// =============================================================================
// CONSUMABLE TAB — item submenu (W/S navigate, Enter use, Esc cancel)
// =============================================================================
if (menu_tab == 3) {

    if (consumable_submenu_open) {
        var _cons_cnt = array_length(global.consumable_inventory);

        // Navigate
        if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
            consumable_submenu_cursor = max(0, consumable_submenu_cursor - 1);
        }
        if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
            consumable_submenu_cursor = min(max(0, _cons_cnt - 1), consumable_submenu_cursor + 1);
        }

        // Close without using
        if (keyboard_check_pressed(vk_escape)) {
            consumable_submenu_open = false;
        }

        // Use selected item
        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
            var _can_use = true;
            if (instance_exists(obj_combat_controller)) {
                var _ctrl_c = instance_find(obj_combat_controller, 0);
                if (!_ctrl_c.player_turn && items_used_this_turn >= 1) {
                    _can_use = false;
                }
            }
            if (_can_use && _cons_cnt > 0 && consumable_submenu_cursor < _cons_cnt) {
                var _item = global.consumable_inventory[consumable_submenu_cursor];
                if (instance_exists(obj_combat_controller)) {
                    var _ctrl_c = instance_find(obj_combat_controller, 0);
                    var _player = _ctrl_c.player;
                    if (_item.effect_type == "heal") {
                        var _heal = min(_player.max_HP - _player.HP, _item.effect_value);
                        _player.HP += _heal;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " — restored " + string(_heal) + " HP!");
                    } else if (_item.effect_type == "energy") {
                        _player.energy = min(3, _player.energy + _item.effect_value);
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " — restored " + string(_item.effect_value) + " energy!");
                    } else if (_item.effect_type == "cleanse_dot") {
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " — cleared DoT effects!");
                    } else if (_item.effect_type == "cleanse_all") {
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " — cleared all negative effects!");
                    }
                    if (!_ctrl_c.player_turn) items_used_this_turn++;
                }
                array_delete(global.consumable_inventory, consumable_submenu_cursor, 1);
                consumable_submenu_cursor = min(consumable_submenu_cursor,
                    max(0, array_length(global.consumable_inventory) - 1));
                if (array_length(global.consumable_inventory) == 0) {
                    consumable_submenu_open = false;
                }
            }
        }

    } else {
        // Submenu closed — Enter opens it (only when items exist)
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


