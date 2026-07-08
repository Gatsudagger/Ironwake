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
    // Rare: the crumbling altar reveals a pet egg (item-tribute claim path).
    if (irandom(99) < 20) {
        var _se2 = pet_grant_altar_egg("egg_shrine");
        shrine_notification += _se2.is_egg ? "  An egg rests in the rubble..." : ("  A " + _se2.name + " stirs in the rubble...");
    }
    // Sacrifice celebration: sparkle flutter + result popup over the floor map.
    shrine_celebrate_timer = 150;
    shrine_celebrate_title = "OFFERING ACCEPTED";
    shrine_celebrate_sub   = shrine_notification;
    shrine_celebrate_seed  = irandom(10000);
}


// -----------------------------------------------------------------------------
// 1. TREASURE POPUP - intercepts all input until dismissed
// -----------------------------------------------------------------------------
if (showing_treasure) {
    if (input_confirm() || input_confirm_alt() || mouse_check_button_pressed(mb_left)) {
        showing_treasure = false;
        treasure_item2   = undefined;   // clear so hunt/vendor popups reusing this overlay never show it
        current_rooms[selected_room].cleared = true;
        global.floor_rooms_cleared[selected_room] = true;
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2. EVENT POPUP (rest / trap) - intercepts all input until dismissed
// -----------------------------------------------------------------------------
if (showing_event) {
    if (input_confirm() || input_confirm_alt() || mouse_check_button_pressed(mb_left)) {
        showing_event = false;
        current_rooms[selected_room].cleared = true;
        global.floor_rooms_cleared[selected_room] = true;
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2a-overflow. CONSUMABLE OVERFLOW PROMPT - a pack-full pickup awaits a discard
// choice. Sits after the treasure/event popups so the player sees what dropped
// first, then resolves the pack here before navigating on.
// -----------------------------------------------------------------------------
if (consumable_overflow_pending()) {
    consumable_overflow_step();
    exit;
}


// -----------------------------------------------------------------------------
// 2b. SHRINE OF TRIBUTE - interactive boon purchase (see SYSTEMS_BOONS.md)
//   W/S select boon - 1 pay gold - 2 pay dust - 3 sacrifice item - Esc leave
// -----------------------------------------------------------------------------
if (showing_shrine) {
    var _sh_n = array_length(shrine_offers);

    // --- Pre-approach: the altar's nature is veiled. The player may walk away freely
    //     (forgoing any boon AND any curse), or APPROACH to commit. Approaching is the
    //     gamble - it reveals the kind, and a curse altar then springs its trap. ------
    if (!shrine_revealed) {
        if (input_cancel() || input_back()) {
            showing_shrine = false;
            current_rooms[selected_room].cleared = true;
            global.floor_rooms_cleared[selected_room] = true;
            exit;
        }
        if (input_confirm() || input_confirm_alt()) {
            shrine_revealed     = true;   // commit - reveal blessing/curse
            shrine_cursor       = 0;
            shrine_notification = "";
        }
        exit;
    }

    // --- Revealed. Leaving is allowed for a BLESSING altar (tribute is optional), but a
    //     CURSE altar will not release the player - they must embrace a curse. The
    //     _sh_n==0 guard keeps a degenerate empty-curse altar from soft-locking. ------
    if (input_cancel() || input_back()) {
        if (shrine_kind != "curse" || _sh_n == 0) {
            showing_shrine = false;
            current_rooms[selected_room].cleared = true;
            global.floor_rooms_cleared[selected_room] = true;
            exit;
        }
        shrine_notification = "The altar's grip holds you - you must embrace a curse to leave.";
    }

    if (_sh_n > 0) {
        if (nav_up())   { shrine_cursor = wrap_index(shrine_cursor - 1, _sh_n); shrine_notification = ""; }
        if (nav_down()) { shrine_cursor = wrap_index(shrine_cursor + 1, _sh_n); shrine_notification = ""; }
        shrine_cursor = clamp(shrine_cursor, 0, _sh_n - 1);

        if (shrine_kind == "curse") {
            // Curse altar - accept the selected curse for free (the difficulty is
            // the cost). Enter/Space binds it for the rest of the run.
            if (input_confirm() || input_confirm_alt()) {
                var _cid = shrine_offers[shrine_cursor];
                var _res = curse_accept(_cid);
                if (_res == "") {
                    var _cd = curse_get(_cid);
                    shrine_notification = "You embrace " + _cd.name + ". The altar is sated.";
                    showing_shrine = false;
                    current_rooms[selected_room].cleared = true;
                    global.floor_rooms_cleared[selected_room] = true;
                    // The sated altar sometimes leaves a (often corrupted) egg behind.
                    if (irandom(99) < 25) {
                        var _ce = pet_grant_altar_egg("egg_curse");
                        shrine_notification += _ce.is_egg ? "  A dark egg festers in the ashes..." : ("  A " + _ce.name + " lurks in the dark...");
                    }
                } else {
                    shrine_notification = _res;
                }
            }
        } else {
            // Blessing altar - pay tribute (gold / dust / item) for a boon.
            var _pay_method = "";
            if (input_hotkey("1")) _pay_method = "gold";
            else if (input_hotkey("2")) _pay_method = "dust";
            else if (input_hotkey("3")) _pay_method = "item";

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
                    // Rare: the crumbling altar reveals a pet egg.
                    if (irandom(99) < 20) {
                        var _se = pet_grant_altar_egg("egg_shrine");
                        shrine_notification += _se.is_egg ? "  An egg rests in the rubble..." : ("  A " + _se.name + " stirs in the rubble...");
                    }
                    // Claim celebration (gold/dust tribute path).
                    shrine_celebrate_timer = 150;
                    shrine_celebrate_title = "BOON CLAIMED";
                    shrine_celebrate_sub   = shrine_notification;
                    shrine_celebrate_seed  = irandom(10000);
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
        if (input_confirm() || input_confirm_alt() || mouse_check_button_pressed(mb_left)) {
            showing_event_choice = false;
            current_rooms[selected_room].cleared = true;
            global.floor_rooms_cleared[selected_room] = true;
        }
        exit;
    }

    var _ev_n = array_length(event_active.choices);

    // Move cursor, skipping locked choices (wraps).
    var _move = 0;
    if (nav_up())   _move = -1;
    if (nav_down()) _move = 1;
    if (_move != 0 && _ev_n > 0) {
        var _try = event_cursor;
        for (var _k = 0; _k < _ev_n; _k++) {
            _try = (_try + _move + _ev_n) mod _ev_n;
            if (event_choice_unlocked(event_active.choices[_try])) { event_cursor = _try; break; }
        }
    }

    // Confirm the selected choice.
    if (input_confirm() || input_confirm_alt()) {
        var _ch = event_active.choices[event_cursor];
        if (event_choice_unlocked(_ch)) {
            var _cost = event_choice_cost(_ch);
            if (_cost > 0) global.gold = max(0, global.gold - _cost);

            global.event_gold_gained = 0;
            var _out     = event_resolve_choice(_ch);
            var _rewards = event_apply_effects(_out.effects);
            event_result_text = _out.text + (_rewards != "" ? "\n\n" + _rewards : "");
            event_phase = "result";
            // Gold-yielding result: spawn the coin burst (coins tossed up from the
            // panel centre that fall and settle into a pile - drawn in Draw_64).
            event_coins = [];
            if (global.event_gold_gained > 0) {
                var _nc = min(6 + (global.event_gold_gained div 10), 24);
                for (var _ci = 0; _ci < _nc; _ci++) {
                    array_push(event_coins, {
                        x: GUI_CX + random_range(-40, 40),
                        y: 640,
                        vx: random_range(-4.2, 4.2),
                        vy: random_range(-9, -4),
                        spin: random_range(0, pi * 2),
                        slot: _ci,           // index into the pile rest positions
                        grounded: false
                    });
                }
            }
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
if (input_cancel()) {
    pause_menu_open();
    exit;
}

// -----------------------------------------------------------------------------
// 3a. ESCAPE ITEMS (Genie Lamp / Devil Wine) - G on the idle map opens a confirm.
// Lamp: free extraction with all loot. Wine: same, but PERMANENTLY lose 3 random
// stat points (subtracted from base stats, floor 1). Both route through end_run(0)
// so extraction bookkeeping (loot -> stash, boss credits already banked) is shared.
// -----------------------------------------------------------------------------
if (escape_confirm_open) {
    if (input_cancel() || mouse_check_button_pressed(mb_right)
        || input_hotkey("G")) {
        escape_confirm_open = false;
    } else if (input_confirm() || input_confirm_alt()) {
        var _esc_ok = (escape_confirm_idx >= 0
            && escape_confirm_idx < array_length(global.consumable_inventory));
        if (_esc_ok) {
            var _esc_it   = global.consumable_inventory[escape_confirm_idx];
            var _esc_wine = (_esc_it.effect_type == "escape_wine");
            array_delete(global.consumable_inventory, escape_confirm_idx, 1);
            if (_esc_wine) {
                // Permanently drain 3 random stat points from the BASE character
                // stats (never below 1 each). The toll is the whole point.
                var _dw_keys = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
                var _dw_lost = "";
                repeat (3) {
                    var _dw_pool = [];
                    for (var _dk = 0; _dk < 6; _dk++) {
                        if (variable_struct_get(global.chosen_stats, _dw_keys[_dk]) > 1)
                            array_push(_dw_pool, _dw_keys[_dk]);
                    }
                    if (array_length(_dw_pool) == 0) break;
                    var _dw_k = _dw_pool[irandom(array_length(_dw_pool) - 1)];
                    variable_struct_set(global.chosen_stats, _dw_k,
                        variable_struct_get(global.chosen_stats, _dw_k) - 1);
                    _dw_lost += (_dw_lost == "" ? "" : ", ") + _dw_k;
                }
                if (variable_global_exists("pet_find_notice")) {
                    var _dw_msg = "The Devil Wine takes its due: -1 " + _dw_lost + " (permanent).";
                    global.pet_find_notice = (global.pet_find_notice != "")
                        ? (global.pet_find_notice + "   " + _dw_msg) : _dw_msg;
                }
            }
            escape_confirm_open = false;
            end_run(0);   // extraction: keep gold, carried loot -> stash, pet banks growth
            save_game();
            global.current_floor       = 1;
            global.floor_rooms_cleared = [];
            global.floor_map_floor     = -1;
            room_goto(rm_hub);
        } else {
            escape_confirm_open = false;
        }
    }
    exit;
}
if (input_hotkey("G") && variable_global_exists("consumable_inventory")) {
    // Prefer the free Lamp; fall back to Devil Wine.
    escape_confirm_idx = -1;
    for (var _gi = 0; _gi < array_length(global.consumable_inventory); _gi++) {
        if (global.consumable_inventory[_gi].effect_type == "escape_lamp") { escape_confirm_idx = _gi; break; }
    }
    if (escape_confirm_idx < 0) {
        for (var _gi2 = 0; _gi2 < array_length(global.consumable_inventory); _gi2++) {
            if (global.consumable_inventory[_gi2].effect_type == "escape_wine") { escape_confirm_idx = _gi2; break; }
        }
    }
    if (escape_confirm_idx >= 0) escape_confirm_open = true;
}

var _nav_reach = floor_compute_reachable(current_rooms);
var _cur = current_rooms[selected_room];

// Horizontal: pick the nearest column on the chosen side, then the room in it
// whose vertical position is closest to the current one.
var _go_left  = nav_left();
var _go_right = nav_right();
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
var _go_up   = nav_up();
var _go_down = nav_down();
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
if (input_confirm() || input_confirm_alt()) {
    var _room = current_rooms[selected_room];

    // Enter only if reachable now (handles cleared + sibling-lock); see scr_stats.
    if (!floor_room_enterable(current_rooms, selected_room)) exit;

    // --- Handle by type ---

    if (_room.type == "treasure") {
        treasure_gold = irandom(_room.gold_max - _room.gold_min) + _room.gold_min;
        add_gold(treasure_gold);
        showing_treasure = true;
        audio_play_sound(snd_chest, 1, false);
        if (treasure_gold > 0) audio_play_sound(snd_gold, 1, false);
        treasure_timer   = 0;

        treasure_item  = undefined;
        treasure_item2 = undefined;
        // Treasure Hunter (audit §6 rework): the trait adds one GUARANTEED extra item on
        // top of the normal 40% roll - so 1 item always, 2 when the roll also hits.
        var _t_item_rolls = (irandom(99) < 40 ? 1 : 0) + (trait_active("Treasure Hunter") ? 1 : 0);
        if (_t_item_rolls > 0) {
            if (!variable_global_exists("run_items_found"))      global.run_items_found      = [];
            if (!variable_global_exists("consumable_inventory")) global.consumable_inventory = [];
            if (!variable_global_exists("carried_items"))        global.carried_items        = [];
            for (var _tri = 0; _tri < _t_item_rolls; _tri++) {
                var _t_found = undefined;
                if (irandom(99) < 70) {
                    var _tc = roll_consumable_weighted(global.consumables_standard);
                    array_push(global.run_items_found, _tc);
                    consumable_award(_tc);
                    _t_found = _tc;
                } else {
                    var _te_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) + curse_loot_asc_bonus();
                    var _te = drop_equipment(drop_weights("chest", _te_asc));
                    array_push(global.run_items_found, _te);
                    array_push(global.carried_items, _te);
                    discover_item(item_base_name(_te));
                    _t_found = _te;
                }
                if (treasure_item == undefined) treasure_item = _t_found;
                else                            treasure_item2 = _t_found;
            }
        }

        show_debug_message("[FLOOR DEBUG] floor=" + string(global.current_floor)
            + " room=" + string(selected_room) + " type=treasure gold=" + string(treasure_gold));

    } else if (_room.type == "rest") {
        // Grant a pending heal picked up by obj_combat_controller on next combat enter.
        // Awakening-scaled (design 2026-07-04): flat = base + 4/tier, plus 5% of max HP
        // resolved at APPLY time (combat start) where the geared max_HP is known.
        if (!variable_global_exists("pending_rest_heal"))     global.pending_rest_heal     = 0;
        if (!variable_global_exists("pending_rest_heal_pct")) global.pending_rest_heal_pct = 0;
        var _rest_tier = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
        var _rest_flat = (trait_active("Quick Recovery") ? round(25 * trait_potency_mult("Quick Recovery")) : 15)
                       + 4 * _rest_tier;
        global.pending_rest_heal     += _rest_flat;
        global.pending_rest_heal_pct += 5;
        event_title  = "REST SITE";
        event_body   = "You find a sheltered alcove and catch\nyour breath in the darkness.\n\n+" + string(_rest_flat)
                     + " HP (+5% of your max HP)\nrestored at the start of\nyour next combat.";
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
        consumable_award(_th_c);
        treasure_gold  = _th_gold;
        treasure_item  = _th_c;
        treasure_timer = 0;
        showing_treasure = true;
        audio_play_sound(snd_chest, 1, false);
        if (treasure_gold > 0) audio_play_sound(snd_gold, 1, false);
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
        audio_play_sound(snd_chest, 1, false);
        if (treasure_gold > 0) audio_play_sound(snd_gold, 1, false);
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
        audio_play_sound(snd_chest, 1, false);
        if (treasure_gold > 0) audio_play_sound(snd_gold, 1, false);
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=treasure_rare gold=" + string(_tr_gold));

    } else if (_room.type == "event") {
        // Event room - roll an event and open the interactive choice overlay.
        event_active      = event_roll();
        event_cursor      = event_first_unlocked(event_active);
        event_phase       = "choose";
        event_result_text = "";
        showing_event_choice = true;
        audio_play_sound(snd_sting_mystery, 1, false);   // something odd in this room...
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=event id=" + event_active.id);

    } else if (_room.type == "shrine") {
        // Shrine altar - roll its nature (~33% cursed; curse altars are the rarer,
        // riskier surprise), then roll the matching offers. If the chosen kind has
        // nothing left to give, fall back to the other kind. The nature stays VEILED
        // (shrine_revealed=false) until the player chooses to approach the altar.
        shrine_kind = (irandom(99) < 33) ? "curse" : "blessing";
        if (shrine_kind == "curse") {
            shrine_offers = curse_offer_roll();
            if (array_length(shrine_offers) == 0) { shrine_kind = "blessing"; shrine_offers = boon_offer_roll(); }
        } else {
            shrine_offers = boon_offer_roll();
            if (array_length(shrine_offers) == 0) { shrine_kind = "curse"; shrine_offers = curse_offer_roll(); }
        }
        shrine_cursor       = 0;
        shrine_notification = "";
        shrine_revealed     = false;   // veiled until the player approaches
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
if (input_hotkey("E")) {
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
            // Touch (8c): tapping the ALREADY-selected node enters it (simulated
            // Enter -> the unchanged ENTER ROOM handler next step). First tap
            // selects, second tap commits - guards against travel mis-taps.
            if (input_device() == 2 && selected_room == _mi
                && floor_room_enterable(current_rooms, _mi)) {
                touch_press(vk_enter);
            }
            selected_room = _mi;
            break;
        }
    }
}
