// =============================================================================
// obj_floor_controller — Step event
// Handles all input on the floor map screen.
// Input map:
//   Up / W     — move selection up
//   Down / S   — move selection down
//   Space      — enter selected room (or dismiss treasure popup)
//   E          — extract to camp (only after clearing at least one room)
// =============================================================================

// Freeze floor input while any gc overlay (character menu, stash, shop) is open.
if (ui_input_blocked()) exit;


// -----------------------------------------------------------------------------
// 1. TREASURE POPUP — intercepts all input until dismissed
// The popup is shown after entering a treasure room. Gold is already added when
// the popup opens; Space dismisses it and marks the room cleared.
// -----------------------------------------------------------------------------
if (showing_treasure) {
    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
        showing_treasure = false;
        current_rooms[selected_room].cleared = true;
        global.floor_rooms_cleared[selected_room] = true;
        selected_room = min(selected_room + 1, array_length(current_rooms) - 1);
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2. ROOM LIST NAVIGATION
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
    selected_room = max(0, selected_room - 1);
}

if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
    selected_room = min(array_length(current_rooms) - 1, selected_room + 1);
}


// -----------------------------------------------------------------------------
// 3. ENTER ROOM
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
    var _room = current_rooms[selected_room];

    if (_room.cleared) exit; // cleared rooms cannot be re-entered

    // Check if this room is accessible — all previous rooms must be cleared
    var _accessible = true;
    for (var _check = 0; _check < selected_room; _check++) {
        if (!current_rooms[_check].cleared) {
            _accessible = false;
            break;
        }
    }
    if (!_accessible) exit; // room not yet reachable

    if (_room.type == "treasure") {
        // Roll gold, bank it immediately, then show the popup
        treasure_gold = irandom(_room.gold_max - _room.gold_min) + _room.gold_min;
        add_gold(treasure_gold);
        showing_treasure = true;
        treasure_timer   = 0;

        // 40% chance to find one item alongside the gold.
        // Scavenger does not apply to items — only to the add_gold() call above.
        treasure_item = undefined;
        if (irandom(99) < 40) {
            if (!variable_global_exists("run_items_found"))      global.run_items_found      = [];
            if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
            if (!variable_global_exists("carried_items"))        global.carried_items        = [];

            if (irandom(99) < 70) {
                // 70%: consumable from the standard pool
                var _tc = roll_consumable(global.consumables_standard);
                array_push(global.run_items_found, _tc);
                array_push(global.consumable_inventory, _tc);
                treasure_item = _tc;
            } else {
                // 30%: equipment — 50 common / 35 uncommon / 13 rare / 2 epic, never legendary.
                // Calls drop_equipment() which calls roll_affixes() / apply_affixes_to_item()
                // — the exact same affix pipeline used by all combat drops.
                var _te = drop_equipment([50, 35, 13, 2]);
                array_push(global.run_items_found, _te);
                array_push(global.carried_items, _te);
                treasure_item = _te;
            }
        }

        // DEBUG — strip once treasure drops are verified
        var _tdbg_item = (treasure_item != undefined) ? treasure_item.name : "none";
        show_debug_message("[FLOOR DEBUG] floor=" + string(global.current_floor)
            + " room_index=" + string(selected_room)
            + " type=treasure | item: " + _tdbg_item
            + " name=" + _room.name);
        // END DEBUG

    } else if (_room.type == "combat" || _room.type == "boss") {
        // Tell the combat controller which enemy pool to use and which room we came from
        global.next_enemy_type    = _room.enemies;
        global.current_room_index = selected_room;
        global.just_cleared_room  = false;
        global.just_cleared_boss  = (_room.type == "boss");
        // DEBUG — strip this block once floor progression is verified
        show_debug_message("[FLOOR DEBUG] floor=" + string(global.current_floor)
            + " room_index=" + string(selected_room)
            + " type=" + _room.type
            + " enemies=" + _room.enemies
            + " name=" + _room.name);
        // END DEBUG
        room_goto(Room1);
    }
}


// -----------------------------------------------------------------------------
// 4. EXTRACT TO CAMP
// Only available after at least one room has been cleared this floor.
// end_run(0) records gold/kills earned so far without a full victory payout.
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(ord("E"))) {
    var _any_cleared = false;
    for (var _i = 0; _i < array_length(current_rooms); _i++) {
        if (current_rooms[_i].cleared) {
            _any_cleared = true;
            break;
        }
    }
    if (_any_cleared) {
        end_run(0);
        global.current_floor       = 1;
        global.floor_rooms_cleared = [];
        room_goto(rm_hub);
    }
}
