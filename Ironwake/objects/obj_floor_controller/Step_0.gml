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
    shrine_notification_fail = false;
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
            shrine_notification_fail = false;
            shrine_curse_arm    = -1;
            // A curse altar springs its trap the moment it drops the veil.
            if (shrine_kind == "curse") audio_play_sound(snd_curse_whisper, 1, false);
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
        shrine_notification_fail = true;
    }

    if (_sh_n > 0) {
        if (nav_up())   { shrine_cursor = wrap_index(shrine_cursor - 1, _sh_n); shrine_notification = ""; shrine_notification_fail = false; shrine_curse_arm = -1; }
        if (nav_down()) { shrine_cursor = wrap_index(shrine_cursor + 1, _sh_n); shrine_notification = ""; shrine_notification_fail = false; shrine_curse_arm = -1; }
        shrine_cursor = clamp(shrine_cursor, 0, _sh_n - 1);

        if (shrine_kind == "curse") {
            // Curse altar - accept the selected curse for free (the difficulty is
            // the cost). #7: arm-then-confirm - the first Enter on a row warns,
            // the second Enter on the SAME row binds it for the rest of the run.
            if (input_confirm() || input_confirm_alt()) {
                if (shrine_curse_arm != shrine_cursor) {
                    shrine_curse_arm = shrine_cursor;
                    var _cad = curse_get(shrine_offers[shrine_cursor]);
                    shrine_notification = "Embrace " + _cad.name + "? Confirm again to accept - a curse cannot be undone.";
                    shrine_notification_fail = false;
                } else {
                    shrine_curse_arm = -1;
                    var _cid = shrine_offers[shrine_cursor];
                    var _res = curse_accept(_cid);
                    if (_res == "") {
                        var _cd = curse_get(_cid);
                        shrine_notification = "You embrace " + _cd.name + ". The altar is sated.";
                        shrine_notification_fail = false;
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
                        shrine_notification_fail = true;
                    }
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
                    shrine_notification_fail = true;
                } else {
                    // Sharp Eye (C5): the tribute tier uses the discounted price too.
                    var _bcost2 = shrine_boon_price(_bd2.cost);
                    var _cands = item_picker_candidates_by_tribute(_bcost2);
                    if (array_length(_cands) == 0) {
                        shrine_notification = "No item valuable enough to sacrifice.";
                        shrine_notification_fail = true;
                    } else {
                        item_picker_open("shrine_boon", { boon_id: _bid, cost: _bcost2 }, _cands);
                        shrine_notification = "";
                        shrine_notification_fail = false;
                    }
                }
            } else if (_pay_method != "") {
                var _bid = shrine_offers[shrine_cursor];
                var _res = boon_pay(_bid, _pay_method);
                if (_res == "") {
                    var _bd = boon_get(_bid);
                    shrine_notification = "Claimed " + _bd.name + "! The altar crumbles.";
                    shrine_notification_fail = false;
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
                    shrine_notification_fail = true;   // #13: can't-afford etc. read as failure
                }
            }
        }
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2b2. THE WHETSTONE - run-scoped ability honing (combat plan v2 §C)
//   W/S select - Enter confirm - Esc/back: pick_mod -> ability list, ability -> leave.
//   FREE: hone one slotted ability's mastery mod for the rest of the run.
// -----------------------------------------------------------------------------
if (showing_whetstone) {
    var _wt_n = array_length(whetstone_abilities);

    // Degenerate empty-loadout guard: let the player leave freely.
    if (_wt_n == 0) {
        if (input_cancel() || input_back() || input_confirm() || input_confirm_alt()) {
            showing_whetstone = false;
            current_rooms[selected_room].cleared = true;
            global.floor_rooms_cleared[selected_room] = true;
        }
        exit;
    }

    if (whetstone_phase == "ability") {
        if (input_cancel() || input_back()) {
            // Leave without honing - the edge stays as it is (no obligation).
            showing_whetstone = false;
            current_rooms[selected_room].cleared = true;
            global.floor_rooms_cleared[selected_room] = true;
            exit;
        }
        if (nav_up())   whetstone_ab_cursor = wrap_index(whetstone_ab_cursor - 1, _wt_n);
        if (nav_down()) whetstone_ab_cursor = wrap_index(whetstone_ab_cursor + 1, _wt_n);
        whetstone_ab_cursor = clamp(whetstone_ab_cursor, 0, _wt_n - 1);
        if (input_confirm() || input_confirm_alt()) {
            whetstone_phase      = "mod";
            whetstone_mod_cursor = 0;
        }
        exit;
    }

    // whetstone_phase == "mod": pick one of the ability's two mastery mods.
    var _wt_ab   = whetstone_abilities[whetstone_ab_cursor];
    var _wt_mods = ability_mastery_options(_wt_ab);
    var _wt_mn   = array_length(_wt_mods);
    if (input_cancel() || input_back()) {
        whetstone_phase = "ability";   // back up to the ability list
        exit;
    }
    if (nav_up())   whetstone_mod_cursor = wrap_index(whetstone_mod_cursor - 1, _wt_mn);
    if (nav_down()) whetstone_mod_cursor = wrap_index(whetstone_mod_cursor + 1, _wt_mn);
    whetstone_mod_cursor = clamp(whetstone_mod_cursor, 0, _wt_mn - 1);
    if (input_confirm() || input_confirm_alt()) {
        var _wt_pick = _wt_mods[whetstone_mod_cursor];
        ability_run_honing_set(_wt_ab.name, _wt_pick.id);
        global.run_whetstone_used = true;   // once-per-run gate (cleared at run teardown)
        whetstone_notification = _wt_ab.name + " honed: " + _wt_pick.label + " (this run).";
        showing_whetstone = false;
        current_rooms[selected_room].cleared = true;
        global.floor_rooms_cleared[selected_room] = true;
        audio_play_sound(snd_forge, 1, false);   // the honing strike on the stone
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
            // Borrowed Memory DRAFT (07-16 combo batch): if the event just offered
            // memories, the overlay stays open and becomes the pick-1-of-3 screen -
            // a synthetic event rendered by the same generic choice UI. The room
            // clears when the PICK's own result closes (offer is empty by then).
            if (variable_global_exists("borrowed_offer") && is_array(global.borrowed_offer)
                && array_length(global.borrowed_offer) > 0) {
                var _bo = global.borrowed_offer;
                var _bo_choices = [];
                for (var _boi = 0; _boi < array_length(_bo); _boi++) {
                    array_push(_bo_choices, {
                        label: _bo[_boi].name + " (" + _bo[_boi].from_class + ")",
                        hint:  _bo[_boi].hint,
                        cost_gold: 0, req_stat: "", req_amount: 0, resolve: "weighted",
                        outcomes: [ { weight: 100,
                            text: "The " + _bo[_boi].from_class + "'s memory settles into your hands as if they had always known it.",
                            effects: { memory_pick: _bo[_boi].name, memory_pick_class: _bo[_boi].from_class } } ]
                    });
                }
                global.borrowed_offer = [];
                event_active = {
                    id:    "borrowed_pick",
                    title: "Borrowed Memories",
                    body:  "Three ghosts of other lives hang in the air, each offering what it knew. Only one will stay with you.",
                    color: make_color_rgb(150, 130, 220),
                    choices: _bo_choices
                };
                event_phase  = "choices";
                event_cursor = 0;
                exit;
            }
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
            // panel centre that fall and settle into a pile - drawn in Draw_64
            // via the shared ui_draw_coin_burst sim).
            event_coins = [];
            if (global.event_gold_gained > 0) {
                event_coins = ui_seed_coin_burst(min(6 + (global.event_gold_gained div 10), 24), GUI_CX, 640);
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
// Exception: the escape-item confirm lives BELOW this block, so it must be gated
// here too - its legend promises "Esc: Cancel", but Esc was opening the pause
// menu over the popup instead (found 07-08 wiring the touch path).
// gc-managed overlays (character menu [I], journal, stash...) are usable on the
// floor and gc's Step runs FIRST, so the Esc that closes one has already cleared
// its flag by the time we get here - global.ui_overlay_latch holds the start-of-
// frame state so that same press can't also open the pause menu (hub idiom).
if (input_cancel() && !escape_confirm_open && !extract_confirm_open
    && !ui_input_blocked() && !global.ui_overlay_latch) {
    pause_menu_open();
    exit;
}

// -----------------------------------------------------------------------------
// 3a. ESCAPE ITEMS (Genie Lamp / Devil Wine) - G on the idle map opens a confirm.
// Lamp: free extraction with all loot. Wine: same, but PERMANENTLY lose 2 random
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
                // Permanently drain 2 random stat points from the BASE character
                // stats (never below 1 each). The toll is the whole point.
                // (Was 3 - M 07-08: "too strong of a loss".)
                var _dw_keys = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
                var _dw_lost = "";
                repeat (2) {
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
            music_dungeon_stop();   // parity with the E-extract path (the lamp path never stopped the track)
            audio_play_sound(snd_extract, 1, false);   // gate rumble + wind rush out
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
// -----------------------------------------------------------------------------
// 3b. EXTRACT CONFIRM (#3) - E opens this instead of extracting on the spot.
// Enter confirms (end the run, keep loot); Esc / right-click / E again cancels.
// -----------------------------------------------------------------------------
if (extract_confirm_open) {
    if (input_cancel() || mouse_check_button_pressed(mb_right)
        || input_hotkey("E")) {
        extract_confirm_open = false;
    } else if (input_confirm() || input_confirm_alt()) {
        extract_confirm_open = false;
        music_dungeon_stop();   // default pair + any banshee-jukebox dungeon track
        audio_play_sound(snd_extract, 1, false);   // gate rumble + wind rush out
        end_run(0);
        global.current_floor       = 1;
        global.floor_rooms_cleared = [];
        global.floor_map_floor     = -1; // force map regen next run
        room_goto(rm_hub);
    }
    exit;
}

// Onboarding: the first time the player stands on the floor map CARRYING an
// escape item, teach it (M 07-08: "tutorial message when you find a lamp or
// devil wine"). Fired here - not at loot/purchase time - so the tip appears
// exactly where its instructions apply (the G key / LAMP-WINE chip exist here).
if (!tutorial_seen_has("escape_item") && variable_global_exists("consumable_inventory")) {
    for (var _oti = 0; _oti < array_length(global.consumable_inventory); _oti++) {
        var _ott = global.consumable_inventory[_oti].effect_type;
        if (_ott == "escape_lamp" || _ott == "escape_wine") { tutorial_try_show("escape_item"); break; }
    }
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
                    // Curse loot-tiers are a post-roll rarity bump now, not an awakening offset.
                    var _te_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
                    var _te = drop_equipment(drop_weights("chest", _te_asc), true, curse_loot_tier_bonus());
                    array_push(global.run_items_found, _te);
                    array_push(global.carried_items, _te);
                    discover_item(item_base_name(_te));
                    _t_found = _te;
                }
                if (treasure_item == undefined) treasure_item = _t_found;
                else                            treasure_item2 = _t_found;
            }
            // Dopamine layer: the best EQUIPMENT find sings its rarity over the
            // chest foley; consumable-only chests keep just chest+gold.
            var _t_best = treasure_item;
            if (is_struct(treasure_item2)) {
                var _t_eq1 = is_struct(_t_best) && variable_struct_exists(_t_best, "rarity")
                    && !(variable_struct_exists(_t_best, "item_category") && _t_best.item_category == "consumable");
                var _t_eq2 = variable_struct_exists(treasure_item2, "rarity")
                    && !(variable_struct_exists(treasure_item2, "item_category") && treasure_item2.item_category == "consumable");
                if (_t_eq2 && (!_t_eq1 || treasure_item2.rarity > _t_best.rarity)) _t_best = treasure_item2;
            }
            loot_item_sting(_t_best);
        }

        show_debug_message("[FLOOR DEBUG] floor=" + string(global.current_floor)
            + " room=" + string(selected_room) + " type=treasure gold=" + string(treasure_gold));

    } else if (_room.type == "rest") {
        // Heal applies IMMEDIATELY so the floor HUD's HP readout moves (it reads
        // run_current_hp; a deferred heal made rest sites look broken). Awakening-
        // scaled: flat = base + 4/tier, plus 5% of the geared max HP, which
        // out_of_combat_max_hp() can resolve here.
        var _rest_tier = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
        var _rest_flat = (trait_active("Quick Recovery") ? round(25 * trait_potency_mult("Quick Recovery")) : 15)
                       + 4 * _rest_tier;
        var _rest_max  = out_of_combat_max_hp();
        var _rest_amt  = _rest_flat + round(_rest_max * 0.05);
        if (!variable_global_exists("run_current_hp") || global.run_current_hp <= 0) global.run_current_hp = _rest_max;
        var _rest_before = global.run_current_hp;
        global.run_current_hp = min(_rest_max, global.run_current_hp + _rest_amt);
        var _rest_gain = global.run_current_hp - _rest_before;
        event_title  = "REST SITE";
        event_body   = "You find a sheltered alcove and catch\nyour breath in the darkness.\n\n+" + string(_rest_gain)
                     + " HP restored" + ((_rest_gain < _rest_amt) ? " (you were near full)" : "") + ".";
        event_color  = make_color_rgb(80, 200, 120);
        showing_event = true;
        event_timer   = 0;

        show_debug_message("[FLOOR DEBUG] floor=" + string(global.current_floor)
            + " room=" + string(selected_room) + " type=rest  healed=" + string(_rest_gain));

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
        treasure_banshee = banshee_chest_try();   // very rare: a Banshee in a Bottle rides the haul
        showing_treasure = true;
        audio_play_sound(snd_chest, 1, false);
        if (treasure_gold > 0) audio_play_sound(snd_gold, 1, false);
        if (treasure_banshee) audio_play_sound(snd_sting_mystery, 1, false);   // something wails inside the chest...
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=treasure_heal gold=" + string(_th_gold));

    } else if (_room.type == "treasure_vault") {
        // Hidden armory: guaranteed equipment item + medium gold
        var _tv_gold = (_room.gold_max > _room.gold_min)
            ? irandom(_room.gold_max - _room.gold_min) + _room.gold_min : _room.gold_min;
        if (_tv_gold > 0) add_gold(_tv_gold);
        if (!variable_global_exists("run_items_found")) global.run_items_found = [];
        if (!variable_global_exists("carried_items"))   global.carried_items   = [];
        // Curse loot-tiers are a post-roll rarity bump now, not an awakening offset.
        var _tv_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
        var _tv_e = drop_equipment(drop_weights("vault", _tv_asc), true, curse_loot_tier_bonus());
        array_push(global.run_items_found, _tv_e);
        array_push(global.carried_items, _tv_e);
        discover_item(item_base_name(_tv_e));
        treasure_gold  = _tv_gold;
        treasure_item  = _tv_e;
        treasure_timer = 0;
        treasure_banshee = banshee_chest_try();   // very rare: a Banshee in a Bottle rides the haul
        showing_treasure = true;
        audio_play_sound(snd_chest, 1, false);
        if (treasure_gold > 0) audio_play_sound(snd_gold, 1, false);
        if (treasure_banshee) audio_play_sound(snd_sting_mystery, 1, false);   // something wails inside the chest...
        loot_item_sting(_tv_e);   // armory find sings its rarity
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=treasure_vault gold=" + string(_tv_gold));

    } else if (_room.type == "treasure_rare") {
        // Ancient reliquary: guaranteed uncommon+ equipment + higher gold
        var _tr_gold = (_room.gold_max > _room.gold_min)
            ? irandom(_room.gold_max - _room.gold_min) + _room.gold_min : _room.gold_min;
        if (_tr_gold > 0) add_gold(_tr_gold);
        if (!variable_global_exists("run_items_found")) global.run_items_found = [];
        if (!variable_global_exists("carried_items"))   global.carried_items   = [];
        // Curse loot-tiers are a post-roll rarity bump now, not an awakening offset.
        var _tr_asc = (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
        var _tr_e = drop_equipment(drop_weights("reliquary", _tr_asc), true, curse_loot_tier_bonus());
        array_push(global.run_items_found, _tr_e);
        array_push(global.carried_items, _tr_e);
        discover_item(item_base_name(_tr_e));
        treasure_gold  = _tr_gold;
        treasure_item  = _tr_e;
        treasure_timer = 0;
        treasure_banshee = banshee_chest_try();   // very rare: a Banshee in a Bottle rides the haul
        showing_treasure = true;
        audio_play_sound(snd_chest, 1, false);
        if (treasure_gold > 0) audio_play_sound(snd_gold, 1, false);
        if (treasure_banshee) audio_play_sound(snd_sting_mystery, 1, false);   // something wails inside the chest...
        loot_item_sting(_tr_e, true);   // reliquary: legendary = the relic motif
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
        shrine_notification_fail = false;
        shrine_curse_arm    = -1;
        shrine_revealed     = false;   // veiled until the player approaches
        showing_shrine      = true;
        audio_play_sound(snd_shrine_hum, 1, false);   // low choral swell - the altar's pull (still veiled)
        tutorial_try_show("shrine");   // first-altar coach-mark (see SYSTEMS_ONBOARDING.md)
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=shrine kind=" + shrine_kind + " offers=" + string(array_length(shrine_offers)));

    } else if (_room.type == "whetstone") {
        // The Whetstone - open the run-scoped honing picker. Build the equipped
        // ability list now (mastery-resolved copies; .name drives the honing key).
        var _wclass = variable_global_exists("chosen_class") ? global.chosen_class : 0;
        whetstone_abilities    = abilities_resolve_player_loadout(_wclass);
        whetstone_phase        = "ability";
        whetstone_ab_cursor    = 0;
        whetstone_mod_cursor   = 0;
        whetstone_notification = "";
        showing_whetstone      = true;
        audio_play_sound(snd_shrine_hum, 1, false);   // the grindstone's low ring
        show_debug_message("[FLOOR DEBUG] room=" + string(selected_room) + " type=whetstone abilities=" + string(array_length(whetstone_abilities)));

    } else if (_room.type == "combat" || _room.type == "elite" || _room.type == "boss") {
        music_dungeon_stop();   // default pair + any banshee-jukebox dungeon track
        global.next_enemy_type    = _room.enemies;
        global.current_room_index = selected_room;
        global.just_cleared_room  = false;
        global.just_cleared_boss  = (_room.type == "boss");
        // Boss threshold: the iron door groans open as the room transition starts
        // (audio rides across room_goto - gc is persistent, sounds aren't stopped).
        if (_room.type == "boss") audio_play_sound(snd_boss_door, 1, false);

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
    // #3: open the confirm popup (block 3b) instead of extracting on the spot.
    if (_boss_cleared) extract_confirm_open = true;
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
