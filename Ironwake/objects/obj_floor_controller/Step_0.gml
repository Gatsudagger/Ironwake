// =============================================================================
// obj_floor_controller - Step event
// Handles all input on the dungeon floor map screen.
// Input map:
//   W / Up    - select previous room (by id)
//   S / Down  - select next room (by id)
//   Enter / Space - enter selected room (accessibility + clear checks)
//   E         - extract to camp (only after boss cleared)
// Accessibility rule: room is enterable if it has no parents OR any parent cleared.
// =============================================================================

if (ui_input_blocked()) exit;

// Pause / Esc menu - freeze the floor while it (or its Settings sub-screen) is open.
// The Esc-to-open trigger lives lower down, past every popup block, so it only
// fires when no shrine/event/treasure popup is up. See pause_menu_step (scr_stats).
if (pause_menu_step()) exit;

// Transition dungeon music from intro to loop when intro finishes
if (!dungeon_music_looping && !audio_is_playing(_2_dungeon_INITIAL)) {
    dungeon_music_looping = true;
    audio_play_sound(_2_dungeon_LOOP, 1, true);
}

// --- Shared item-sacrifice picker (Shrine item tribute) ---
// Captures input while open (screen frozen); exits the frame it closes so the
// confirming keypress doesn't fall through. On resolve the boon is already
// granted; here we close the shrine + mark the room cleared. See SYSTEMS_ITEM_PICKER.md.
if (variable_global_exists("item_picker") && global.item_picker.open
    && global.item_picker.purpose == "shrine_boon") {
    item_picker_step();
    exit;
}
if (variable_global_exists("item_picker") && global.item_picker.resolved_purpose == "shrine_boon") {
    shrine_notification = global.item_picker.result_msg;
    showing_shrine = false;
    current_rooms[selected_room].cleared = true;
    global.floor_rooms_cleared[selected_room] = true;
    global.item_picker.resolved_purpose = "";   // consume the one-shot
}


// -----------------------------------------------------------------------------
// 1. TREASURE POPUP - intercepts all input until dismissed
// -----------------------------------------------------------------------------
if (showing_treasure) {
    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
        || keyboard_check_pressed(vk_space) || mouse_check_button_pressed(mb_left)) {
        showing_treasure = false;
        current_rooms[selected_room].cleared = true;
        global.floor_rooms_cleared[selected_room] = true;
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2. EVENT POPUP (rest / trap) - intercepts all input until dismissed
// -----------------------------------------------------------------------------
if (showing_event) {
    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
        || keyboard_check_pressed(vk_space) || mouse_check_button_pressed(mb_left)) {
        showing_event = false;
        current_rooms[selected_room].cleared = true;
        global.floor_rooms_cleared[selected_room] = true;
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2b. SHRINE OF TRIBUTE - interactive boon purchase (see SYSTEMS_BOONS.md)
//   W/S select boon - 1 pay gold - 2 pay dust - 3 sacrifice item - Esc leave
// -----------------------------------------------------------------------------
if (showing_shrine) {
    var _sh_n = array_length(shrine_offers);

    // Leave (mark cleared - shrines don't persist once visited)
    if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace)) {
        showing_shrine = false;
        current_rooms[selected_room].cleared = true;
        global.floor_rooms_cleared[selected_room] = true;
        exit;
    }

    if (_sh_n > 0) {
        if (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))) { shrine_cursor = max(0, shrine_cursor - 1);        shrine_notification = ""; }
        if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) { shrine_cursor = min(_sh_n - 1, shrine_cursor + 1); shrine_notification = ""; }
        shrine_cursor = clamp(shrine_cursor, 0, _sh_n - 1);

        if (shrine_kind == "curse") {
            // Curse altar - accept the selected curse for free (the difficulty is
            // the cost). Enter/Space binds it for the rest of the run.
            if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
                var _cid = shrine_offers[shrine_cursor];
                var _res = curse_accept(_cid);
                if (_res == "") {
                    var _cd = curse_get(_cid);
                    shrine_notification = "You embrace " + _cd.name + ". The altar is sated.";
                    showing_shrine = false;
                    current_rooms[selected_room].cleared = true;
                    global.floor_rooms_cleared[selected_room] = true;
                } else {
                    shrine_notification = _res;
                }
            }
        } else {
            // Blessing altar - pay tribute (gold / dust / item) for a boon.
            var _pay_method = "";
            if (keyboard_check_pressed(ord("1"))) _pay_method = "gold";
            else if (keyboard_check_pressed(ord("2"))) _pay_method = "dust";
            else if (keyboard_check_pressed(ord("3"))) _pay_method = "item";

            if (_pay_method == "item") {
                // Item tribute now opens the shared picker (select + confirm) instead of
                // auto-sacrificing the least valuable qualifying item.
                var _bid = shrine_offers[shrine_cursor];
                var _bd2 = boon_get(_bid);
                if (boon_active(_bid)) {
                    shrine_notification = "Already claimed.";
                } else {
                    var _cands = item_picker_candidates_by_tribute(_bd2.cost);
                    if (array_length(_cands) == 0) {
                        shrine_notification = "No item valuable enough to sacrifice.";
                    } else {
                        item_picker_open("shrine_boon", { boon_id: _bid, cost: _bd2.cost }, _cands);
                        shrine_notification = "";
                    }
                }
            } else if (_pay_method != "") {
                var _bid = shrine_offers[shrine_cursor];
                var _res = boon_pay(_bid, _pay_method);
                if (_res == "") {
                    var _bd = boon_get(_bid);
                    shrine_notification = "Claimed " + _bd.name + "! The altar crumbles.";
                    showing_shrine = false;
                    current_rooms[selected_room].cleared = true;
                    global.floor_rooms_cleared[selected_room] = true;
                } else {
                    shrine_notification = _res;
                }
            }
        }
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2c. EVENT ROOM - interactive stat-gated choice overlay (see SYSTEMS_EVENTS.md)
//   W/S select choice (skips locked) - Enter confirm - result phase: any key closes
// -----------------------------------------------------------------------------
if (showing_event_choice) {
    // Result phase - any key closes the overlay and marks the room cleared.
    if (event_phase == "result") {
        if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
            || keyboard_check_pressed(vk_space) || mouse_check_button_pressed(mb_left)) {
            showing_event_choice = false;
            current_rooms[selected_room].cleared = true;
            global.floor_rooms_cleared[selected_room] = true;
        }
        exit;
    }

    var _ev_n = array_length(event_active.choices);

    // Move cursor, skipping locked choices (wraps).
    var _move = 0;
    if (keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))) _move = -1;
    if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) _move = 1;
    if (_move != 0 && _ev_n > 0) {
        var _try = event_cursor;
        for (var _k = 0; _k < _ev_n; _k++) {
            _try = (_try + _move + _ev_n) mod _ev_n;
            if (event_choice_unlocked(event_active.choices[_try])) { event_cursor = _try; break; }
        }
    }

    // Confirm the selected choice.
    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
        var _ch = event_active.choices[event_cursor];
        if (event_choice_unlocked(_ch)) {
            var _cost = event_choice_cost(_ch);
            if (_cost > 0) global.gold = max(0, global.gold - _cost);

            var _out     = event_resolve_choice(_ch);
            var _rewards = event_apply_effects(_out.effects);
            event_result_text = _out.text + (_rewards != "" ? "\n\n" + _rewards : "");
            event_phase = "result";
            show_debug_message("[FLOOR DEBUG] event=" + event_active.id
                + " choice=" + _ch.label + " result=" + _out.text);
        }
    }
    exit;
}


// -----------------------------------------------------------------------------
// 3.SPATIAL NAVIGATION
// Move by map geometry instead of cycling ids: Left/Right change column (layer),
// Up/Down move within the current column. Only reachable rooms are selectable.
// -----------------------------------------------------------------------------
// Esc opens the pause menu - only reachable here, with no popup active (every
// treasure/event/shrine block above exits first), so it never steals Esc from them.
if (keyboard_check_pressed(vk_escape)) {
    pause_menu_open();
    exit;
}

var _nav_reach = floor_compute_reachable(current_rooms);
var _cur = current_rooms[selected_room];

// Horizontal: pick the nearest column on the chosen side, then the room in it
// whose vertical position is closest to the current one.
var _go_left  = keyboard_check_pressed(vk_left)  || keyboard_check_pressed(ord("A"));
var _go_right = keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"));
if (_go_left || _go_right) {
    var _best_layer = -1;
    for (var _i = 0; _i < array_length(current_rooms); _i++) {
        if (!_nav_reach[_i]) continue;
        var _rl = current_rooms[_i].layer;
        if (_go_right && _rl > _cur.layer) {
            if (_best_layer == -1 || _rl < _best_layer) _best_layer = _rl;
        } else if (_go_left && _rl < _cur.layer) {
            if (_best_layer == -1 || _rl > _best_layer) _best_layer = _rl;
        }
    }
    if (_best_layer != -1) {
        var _best_i = -1; var _best_dy = 999999;
        for (var _i = 0; _i < array_length(current_rooms); _i++) {
            if (!_nav_reach[_i] || current_rooms[_i].layer != _best_layer) continue;
            var _dy = abs(current_rooms[_i].py - _cur.py);
            if (_dy < _best_dy) { _best_dy = _dy; _best_i = _i; }
        }
        if (_best_i != -1) selected_room = _best_i;
    }
}

// Vertical: move to the nearest reachable room in the same column above/below.
var _go_up   = keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"));
var _go_down = keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"));
if (_go_up || _go_down) {
    var _v_best_i = -1; var _v_best_dy = 999999;
    for (var _i = 0; _i < array_length(current_rooms); _i++) {
        if (!_nav_reach[_i] || current_rooms[_i].layer != _cur.layer || _i == selected_room) continue;
        var _ry = current_rooms[_i].py;
        var _ok = _go_up ? (_ry < _cur.py) : (_ry > _cur.py);
        if (!_ok) continue;
        var _dy = abs(_ry - _cur.py);
        if (_dy < _v_best_dy) { _v_best_dy = _dy; _v_best_i = _i; }
    }
    if (_v_best_i != -1) selected_room = _v_best_i;
}


// -----------------------------------------------------------------------------
// 4. ENTER ROOM
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) {
    var _room = current_rooms[selected_room];

    // Enter only if reachable now (handles cleared + sibling-lock); see scr_stats.
    if (!floor_room_enterable(current_rooms, selected_room)) exit;

    // --- Handle by type ---

    if (_room.type == "treasure") {
        treasure_gold = irandom(_room.gold_max - _room.gold_min) + _room.gold_min;
        add_gold(treasure_gold);
        showing_treasure = true;
        treasure_timer   = 0;

        treasure_item = undefined;
        if (trait_active("Treasure Hunter") || irandom(99) < 40) {
            if (!variable_global_exists("run_items_found"))      global.run_items_found      = [];
            if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
            if (!variable_global_exists("carried_items"))        global.carried_items        = [];
            if (irandom(99) < 70) {
                var _tc = roll_consumable_weighted(global.consumables_standard);
                array_push(global.run_items_found, _tc);
                array_push(global.consumable_inventory, _tc);
                treasure_item = _tc;
            } else {
                var _te_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) + curse_loot_asc_bonus();
                var _te = drop_equipment(drop_weights("chest", _te_asc));
                array_push(global.run_items_found, _te);
                array_push(global.carried_items, _te);
                discover_item(item_base_name(_te));
                treasure_item = _te;
            }
        }

        show_debug_message("[FLOOR DEBUG] floor=" + string(global.current_floor)
            + " room=" + string(selected_room) + " type=treasure gold=" + string(treasure_gold));

    } else if (_room.type == "rest") {
        // Grant a pending heal picked up by obj_combat_controller on next combat enter
        if (!variable_global_exists("pending_rest_heal")) global.pending_rest_heal = 0;
        global.pending_rest_heal += (trait_active("Quick Recovery") ? round(25 * trait_potency_mult("Quick Recovery")) : 15);
        event_title  = "REST SITE";
        event_body   = "You find a sheltered alcove and catch\nyour breath in the darkness.\n\n+15 HP restored at the start of\nyour next combat.";
        event_color  = make_color_rgb(80, 200, 120);
        showing_event = true;
        event_timer   = 0;

        show_debug_message("[FLOOR DEBUG] floor=" + string(global.current_floor)
            + " room=" + string(selected_room) + " type=rest  pending_heal=" + string(global.pending_rest_heal));

    } else if (_room.type == "treasure_heal") {
        // Supply cache: guaranteed consumable + small gold
        var _th_gold = (_room.gold_max > _room.gold_min)
            ? irandom(_room.gold_max - _room.gold_min) + _room.gold_min : _room.gold_min;
        if (_th_gold > 0) add_gold(_th_gold);
        if (!variable_global_exists("run_items_found"))      global.run_items_found      = [];
        if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
        var _th_c = roll_consumable(global.consumables_standard);
        array_push(global.run_items_found, _th_c);
        array_push(global.consumable_inventory, _th_c);
        treasure_gold  = _th_gold;
        treasure_item  = _th_c;
        treasure_timer = 0;
        showing_treasure = true;
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=treasure_heal gold=" + string(_th_gold));

    } else if (_room.type == "treasure_vault") {
        // Hidden armory: guaranteed equipment item + medium gold
        var _tv_gold = (_room.gold_max > _room.gold_min)
            ? irandom(_room.gold_max - _room.gold_min) + _room.gold_min : _room.gold_min;
        if (_tv_gold > 0) add_gold(_tv_gold);
        if (!variable_global_exists("run_items_found")) global.run_items_found = [];
        if (!variable_global_exists("carried_items"))   global.carried_items   = [];
        var _tv_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) + curse_loot_asc_bonus();
        var _tv_e = drop_equipment(drop_weights("vault", _tv_asc));
        array_push(global.run_items_found, _tv_e);
        array_push(global.carried_items, _tv_e);
        discover_item(item_base_name(_tv_e));
        treasure_gold  = _tv_gold;
        treasure_item  = _tv_e;
        treasure_timer = 0;
        showing_treasure = true;
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=treasure_vault gold=" + string(_tv_gold));

    } else if (_room.type == "treasure_rare") {
        // Ancient reliquary: guaranteed uncommon+ equipment + higher gold
        var _tr_gold = (_room.gold_max > _room.gold_min)
            ? irandom(_room.gold_max - _room.gold_min) + _room.gold_min : _room.gold_min;
        if (_tr_gold > 0) add_gold(_tr_gold);
        if (!variable_global_exists("run_items_found")) global.run_items_found = [];
        if (!variable_global_exists("carried_items"))   global.carried_items   = [];
        var _tr_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) + curse_loot_asc_bonus();
        var _tr_e = drop_equipment(drop_weights("reliquary", _tr_asc));
        array_push(global.run_items_found, _tr_e);
        array_push(global.carried_items, _tr_e);
        discover_item(item_base_name(_tr_e));
        treasure_gold  = _tr_gold;
        treasure_item  = _tr_e;
        treasure_timer = 0;
        showing_treasure = true;
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=treasure_rare gold=" + string(_tr_gold));

    } else if (_room.type == "event") {
        // Event room - roll an event and open the interactive choice overlay.
        event_active      = event_roll();
        event_cursor      = event_first_unlocked(event_active);
        event_phase       = "choose";
        event_result_text = "";
        showing_event_choice = true;
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=event id=" + event_active.id);

    } else if (_room.type == "shrine") {
        // Shrine altar - coin-flip its nature, then roll the matching offers. If the
        // chosen kind has nothing left to give, fall back to the other kind.
        shrine_kind = (irandom(1) == 0) ? "curse" : "blessing";
        if (shrine_kind == "curse") {
            shrine_offers = curse_offer_roll();
            if (array_length(shrine_offers) == 0) { shrine_kind = "blessing"; shrine_offers = boon_offer_roll(); }
        } else {
            shrine_offers = boon_offer_roll();
            if (array_length(shrine_offers) == 0) { shrine_kind = "curse"; shrine_offers = curse_offer_roll(); }
        }
        shrine_cursor       = 0;
        shrine_notification = "";
        showing_shrine      = true;
        tutorial_try_show("shrine");   // first-altar coach-mark (see SYSTEMS_ONBOARDING.md)
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=shrine kind=" + shrine_kind + " offers=" + string(array_length(shrine_offers)));

    } else if (_room.type == "combat" || _room.type == "elite" || _room.type == "boss") {
        audio_stop_sound(_2_dungeon_INITIAL);
        audio_stop_sound(_2_dungeon_LOOP);
        global.next_enemy_type    = _room.enemies;
        global.current_room_index = selected_room;
        global.just_cleared_room  = false;
        global.just_cleared_boss  = (_room.type == "boss");

        show_debug_message("[FLOOR DEBUG] floor=" + string(global.current_floor)
            + " room=" + string(selected_room)
            + " type=" + _room.type + " enemies=" + _room.enemies
            + " name=" + _room.name);
        room_goto(Room1);
    }
}


// -----------------------------------------------------------------------------
// 5. EXTRACT TO CAMP - only after floor boss is defeated
// -----------------------------------------------------------------------------
if (keyboard_check_pressed(ord("E"))) {
    var _boss_cleared = false;
    for (var _bi = 0; _bi < array_length(current_rooms); _bi++) {
        if (current_rooms[_bi].type == "boss" && current_rooms[_bi].cleared) {
            _boss_cleared = true;
            break;
        }
    }
    if (_boss_cleared) {
        audio_stop_sound(_2_dungeon_INITIAL);
        audio_stop_sound(_2_dungeon_LOOP);
        end_run(0);
        global.current_floor       = 1;
        global.floor_rooms_cleared = [];
        global.floor_map_floor     = -1; // force map regen next run
        room_goto(rm_hub);
    }
}


// -----------------------------------------------------------------------------
// 6. MOUSE: click a node box to select it
// Node center is at (room.px, room.py), half-dims are NW/2=98, NH/2=48.
// Only reachable rooms can be selected (unreachable ones are greyed out).
// -----------------------------------------------------------------------------
if (mouse_check_button_pressed(mb_left)) {
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    var _mreach = floor_compute_reachable(current_rooms);
    for (var _mi = 0; _mi < array_length(current_rooms); _mi++) {
        if (!_mreach[_mi]) continue;
        var _mr  = current_rooms[_mi];
        var _mnx = _mr.px - 98;
        var _mny = _mr.py - 48;
        if (_mx >= _mnx && _mx < _mnx + 195 && _my >= _mny && _my < _mny + 96) {
            selected_room = _mi;
            break;
        }
    }
}
