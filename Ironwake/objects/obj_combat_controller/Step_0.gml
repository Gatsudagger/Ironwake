// =============================================================================
// obj_combat_controller — Step event
// Runs every frame. Drives the full turn-based combat loop:
//   player input → ability cast → enemy AI → advance turn → check victory.
// =============================================================================


// Stash is hub-only — no stash access during combat.

// Freeze all combat input when any overlay is open (menu, stash, shop,
// level-up alloc). Level alloc input is handled in obj_game_controller Step
// so it keeps working even while this Step is frozen.
if (ui_input_blocked()) exit;

// Pause / Esc menu — freeze combat while it (or its Settings sub-screen) is open.
// Esc opens it only when no combat sub-overlay owns Esc (loot screen, the [I]
// consumable quick-menu) and the fight is still live. See pause_menu_step (scr_stats).
if (pause_menu_step()) exit;
if (keyboard_check_pressed(vk_escape) && !combat_over && !show_loot_screen && !consumable_quick_open) {
    pause_menu_open();
    exit;
}


// -----------------------------------------------------------------------------
// 1a. COMBAT LOG SCROLLBACK
// New entries snap the view back to the newest line; the mouse wheel scrolls
// through history while hovering the log panel (matches ui_draw_combat_log).
// -----------------------------------------------------------------------------
var _log_len = array_length(combat_log);
if (_log_len != combat_log_last_len) {
    combat_log_scroll   = 0;          // pin to newest whenever the log changes
    combat_log_last_len = _log_len;
}
var _lmx = device_mouse_x_to_gui(0);
var _lmy = device_mouse_y_to_gui(0);
if (_lmx >= 20 && _lmx <= 800 && _lmy >= 490 && _lmy <= 630) {
    var _log_vis = floor((140 - 16) / 19);   // matches panel height / line_h
    var _log_max = max(0, _log_len - _log_vis);
    if (mouse_wheel_up())   combat_log_scroll = min(_log_max, combat_log_scroll + 1);
    if (mouse_wheel_down()) combat_log_scroll = max(0, combat_log_scroll - 1);
}


// -----------------------------------------------------------------------------
// 1. EARLY EXIT — combat already resolved
// -----------------------------------------------------------------------------
if (combat_over) exit;


// -----------------------------------------------------------------------------
// 1b. LOOT SCREEN — intercepts all input after combat while items are shown
// -----------------------------------------------------------------------------
if (show_loot_screen) {
    if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
        loot_screen_scroll = max(0, loot_screen_scroll - 1);
    }
    if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
        var _max_scroll = max(0, array_length(global.run_items_found) - 5);
        loot_screen_scroll = min(_max_scroll, loot_screen_scroll + 1);
    }
    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
        || keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("R"))
        || (mouse_check_button_pressed(mb_left) && device_mouse_y_to_gui(0) >= 640)) {
        show_loot_screen = false;
        combat_over   = true;
        combat_result = 1;
        // Clear run_items_found so the loot screen cannot re-trigger
        global.run_items_found = [];
        array_push(combat_log, "Victory! All enemies defeated.");
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2. VICTORY / DEFEAT CHECK
// Evaluated at the top of every frame so a kill on the previous frame is
// caught immediately at the start of the next, before any new input is read.
// -----------------------------------------------------------------------------
var _result = combat_check_victory(combat_state);

if (_result == 1) {
    // Close stash if open when combat resolves
    if (instance_exists(obj_game_controller)) {
        instance_find(obj_game_controller, 0).stash_mode_open = false;
    }
    // Boss floor-completion XP bonus (granted once per combat on boss kill)
    if (!combat_over && !boss_bonus_granted
        && variable_global_exists("next_enemy_type") && global.next_enemy_type == "boss") {
        boss_bonus_granted = true;
        var _boss_xp_gained = grant_xp(25);
        array_push(combat_log, "Floor completion: +25 XP!");
        if (_boss_xp_gained > 0) {
            audio_play_sound(Chimes__Ascending_, 1, false);
            array_push(combat_log, "LEVEL UP! Now level " + string(global.run_level) + ".");
        }
        // Traits no longer auto-unlock on boss kills — they are bought from Vex
        // (Traits tab) for gold + a rarity-matched item. See SYSTEMS_VEX_REWORK.md.
        if (variable_global_exists("total_boss_kills")) global.total_boss_kills++;

        // Battle Hardened: boss kill grants +3 permanent max HP (max +15 total)
        if (trait_active("Battle Hardened") && variable_global_exists("perm_hp_battle_hardened")) {
            if (global.perm_hp_battle_hardened < 15) {
                global.perm_hp_battle_hardened = min(15, global.perm_hp_battle_hardened + 3);
                if (instance_exists(obj_game_controller)) {
                    var _gc_bh = instance_find(obj_game_controller, 0);
                    _gc_bh.trait_notif_msg   = "Battle Hardened: permanent +3 max HP!";
                    _gc_bh.trait_notif_timer = 120;
                }
            }
        }
    }
    // Open level-up stat allocation if points are waiting
    if (!combat_over && global.pending_stat_points > 0
        && instance_exists(obj_game_controller)) {
        var _gc_v = instance_find(obj_game_controller, 0);
        if (!_gc_v.level_alloc_open) {
            _gc_v.level_alloc_open = true;
        }
        exit;
    }
    // Show loot screen once all points are allocated
    if (!combat_over && variable_global_exists("run_items_found")
        && array_length(global.run_items_found) > 0
        && !show_loot_screen) {
        show_loot_screen = true;
        exit;
    }
    if (!combat_over) {
        combat_over   = true;
        combat_result = 1;
        audio_play_sound(Success_2, 1, false);
        array_push(combat_log, "Victory! All enemies defeated.");
    }
    exit;
}

if (_result == -1) {
    combat_over   = true;
    combat_result = -1;
    audio_play_sound(Game_Over, 1, false);
    array_push(combat_log, "Defeated...");
    // Close stash if open when combat ends
    if (instance_exists(obj_game_controller)) {
        instance_find(obj_game_controller, 0).stash_mode_open = false;
    }
    exit;
}


// Close consumable quick menu whenever it is not the player's turn
if (consumable_quick_open && !player_turn) {
    consumable_quick_open = false;
}


// -----------------------------------------------------------------------------
// 3. PLAYER TURN
// -----------------------------------------------------------------------------
if (player_turn) {

    // Tick the player's status effects once at the start of each player turn
    // (DoTs deal damage; all durations decrement). Mirrors the enemy tick.
    if (need_player_status_tick) {
        need_player_status_tick = false;
        // Tick down per-ability cooldowns at the start of the player's turn.
        if (variable_struct_exists(player, "ability_cd")) {
            for (var _cdi = 0; _cdi < array_length(player.ability_cd); _cdi++) {
                if (player.ability_cd[_cdi] > 0) player.ability_cd[_cdi]--;
            }
        }
        combat_tick_statuses(player, combat_log);
        if (player.HP <= 0 && !combat_try_last_stand(player, combat_log)) {
            player.is_defeated = true;
            exit; // victory/defeat check at the top of next frame resolves it
        }
    }

    // -------------------------------------------------------------------------
    // 3a. CONSUMABLE QUICK MENU — intercepts all other input while open
    // -------------------------------------------------------------------------
    var _ibx = 1060;
    var _iby = 660;
    var _ibw = 180;
    var _ibh = 50;

    // I key or ITEMS button click to toggle
    if (keyboard_check_pressed(ord("I"))) {
        if (consumable_quick_open) {
            consumable_quick_open = false;
        } else if (variable_global_exists("consumable_inventory")
                   && array_length(global.consumable_inventory) > 0) {
            consumable_quick_open   = true;
            consumable_quick_cursor = 0;
        }
    }

    if (mouse_check_button_pressed(mb_left)) {
        var _iqmx = device_mouse_x_to_gui(0);
        var _iqmy = device_mouse_y_to_gui(0);
        if (_iqmx >= _ibx && _iqmx < _ibx + _ibw && _iqmy >= _iby && _iqmy < _iby + _ibh) {
            if (consumable_quick_open) {
                consumable_quick_open = false;
            } else if (variable_global_exists("consumable_inventory")
                       && array_length(global.consumable_inventory) > 0) {
                consumable_quick_open   = true;
                consumable_quick_cursor = 0;
            }
        }
    }

    if (consumable_quick_open) {
        var _qcount = array_length(global.consumable_inventory);
        if (_qcount == 0) {
            consumable_quick_open = false;
        } else {
            // Navigation
            if (keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W"))) {
                consumable_quick_cursor = max(0, consumable_quick_cursor - 1);
            }
            if (keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))) {
                consumable_quick_cursor = min(_qcount - 1, consumable_quick_cursor + 1);
            }
            if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(ord("I"))) {
                consumable_quick_open = false;
                exit;
            }

            // Determine if use was triggered (keyboard or mouse click on a row)
            var _use_item = false;
            var _use_idx  = consumable_quick_cursor;
            if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
                _use_item = true;
            }
            if (mouse_check_button_pressed(mb_left)) {
                var _qcmx  = device_mouse_x_to_gui(0);
                var _qcmy  = device_mouse_y_to_gui(0);
                // Same windowing as the draw (Draw_64) so clicks hit the visible rows.
                var _q_max_vis = 6;
                var _q_vis     = min(_qcount, _q_max_vis);
                var _q_first   = ui_list_window_first(consumable_quick_cursor, _qcount, _q_max_vis);
                var _q_last    = min(_qcount, _q_first + _q_max_vis);
                var _qpw   = 500;
                var _qph   = 56 + _q_vis * 72 + 44;
                var _qpx   = 640 - _qpw / 2;
                var _qpy   = max(80, 660 - _qph - 14);
                for (var _qi = _q_first; _qi < _q_last; _qi++) {
                    var _qry = _qpy + 50 + (_qi - _q_first) * 72;
                    if (_qcmx >= _qpx + 10 && _qcmx < _qpx + _qpw - 10
                     && _qcmy >= _qry && _qcmy < _qry + 62) {
                        consumable_quick_cursor = _qi;
                        _use_idx  = _qi;
                        _use_item = true;
                        break;
                    }
                }
            }

            if (_use_item) {
                var _citem = global.consumable_inventory[_use_idx];
                // AP-restore items ("energy") cost no AP, so they work at 0 AP too.
                var _q_is_ap = (_citem.effect_type == "energy");
                if (player.energy < 1 && !_q_is_ap) {
                    array_push(combat_log, "Need 1 AP to use a consumable.");
                } else {
                    if (_citem.effect_type == "heal") {
                        var _qheal = min(player.max_HP - player.HP, _citem.effect_value);
                        player.HP += _qheal;
                        array_push(combat_log, "Used " + _citem.name
                            + " — restored " + string(_qheal) + " HP!");
                        if (_qheal > 0) {
                            array_push(damage_popups,
                                { value: _qheal, x: 220, y: 240, timer: 45, col: c_lime });
                        }
                    } else if (_citem.effect_type == "energy") {
                        // Burst AP: no cap (can exceed the 3-AP turn limit) and no use cost.
                        player.energy += _citem.effect_value;
                        array_push(combat_log, "Used " + _citem.name
                            + " — +" + string(_citem.effect_value) + " AP!");
                    } else if (_citem.effect_type == "cleanse_dot") {
                        array_push(combat_log, "Used " + _citem.name + " — cleared DoT effects!");
                    } else if (_citem.effect_type == "cleanse_all") {
                        array_push(combat_log, "Used " + _citem.name + " — cleared all effects!");
                    } else if (_citem.effect_type == "heal_dot") {
                        array_push(combat_log, "Used " + _citem.name + "!");
                    } else if (_citem.effect_type == "shield") {
                        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                        player.shield_hp += _citem.effect_value;
                        array_push(combat_log, "Used " + _citem.name
                            + " — gained a " + string(_citem.effect_value) + "-point shield!");
                    }
                    // AP-restore items are free; everything else costs 1 AP.
                    if (!_q_is_ap) player.energy -= 1;
                    array_delete(global.consumable_inventory, _use_idx, 1);
                    if (instance_exists(obj_game_controller)) {
                        instance_find(obj_game_controller, 0).items_used_this_turn++;
                    }
                    // Close if nothing left, otherwise clamp cursor
                    var _remaining = array_length(global.consumable_inventory);
                    if (_remaining == 0) {
                        consumable_quick_open = false;
                    } else {
                        consumable_quick_cursor = min(consumable_quick_cursor, _remaining - 1);
                    }
                }
            }
        }
        exit; // block all other combat input while the quick menu is open
    }

    // --- Ability selection (navigate with arrow keys or WASD) ---
    if (keyboard_check_pressed(vk_left) || keyboard_check_pressed(ord("A"))) {
        selected_ability = max(0, selected_ability - 1);
    }

    if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"))) {
        selected_ability = min(array_length(player.abilities) - 1, selected_ability + 1);
    }

    // --- Tab key cycles through living enemies ---
    if (keyboard_check_pressed(vk_tab)) {
        var _living_count = 0;
        for (var _i = 0; _i < array_length(combat_state.combatants); _i++) {
            var _c = combat_state.combatants[_i];
            if (!_c.is_player && !_c.is_defeated) _living_count++;
        }
        if (_living_count > 1) {
            selected_target = (selected_target + 1) mod _living_count;
        }
    }

    // --- 1-4 hotkeys: select and cast the corresponding ability ---
    var _should_cast = false;
    for (var _hk = 0; _hk < 4; _hk++) {
        if (keyboard_check_pressed(ord(string(_hk + 1)))) {
            if (_hk < array_length(player.abilities)) {
                selected_ability = _hk;
                _should_cast = true;
            }
        }
    }

    // --- Mouse input ---
    if (mouse_check_button_pressed(mb_left)) {
        var _cmx = device_mouse_x_to_gui(0);
        var _cmy = device_mouse_y_to_gui(0);

        // Ability buttons: x=160+i*168, y=660-710, w=160, h=50
        for (var _cbi = 0; _cbi < array_length(player.abilities); _cbi++) {
            var _cbx = 160 + _cbi * 168;
            if (_cmx >= _cbx && _cmx < _cbx+160 && _cmy >= 660 && _cmy < 710) {
                selected_ability = _cbi;
                _should_cast = true;
                break;
            }
        }
        // Enemy HP bars: x=800-1150, living enemy i at y=80+i*40, h=28
        var _cbar_y = 80;
        var _cbar_li = 0;
        for (var _cti = 0; _cti < array_length(combat_state.combatants); _cti++) {
            var _ctc = combat_state.combatants[_cti];
            if (!_ctc.is_player && !_ctc.is_defeated) {
                if (_cmx >= 800 && _cmx < 1120 && _cmy >= _cbar_y && _cmy < _cbar_y+28) {
                    selected_target = _cbar_li;
                }
                _cbar_y  += 40;
                _cbar_li++;
            }
        }
        // End Turn button (around the "T: End Turn" prompt at y=636, x center)
        if (_cmx >= 440 && _cmx < 840 && _cmy >= 624 && _cmy < 648) {
            // Inline end-turn — mirrors the T-key block below
            if (player.energy > 0) {
                array_push(combat_log, "Turn ended — " + string(player.energy) + " AP unspent.");
            }
            if (variable_struct_exists(player, "iron_skin_duration") && player.iron_skin_duration > 0) {
                player.iron_skin_duration--;
                if (player.iron_skin_duration <= 0) {
                    player.damage_reduction = 0;
                    array_push(combat_log, "Iron Skin wore off.");
                }
            }
            combat_next_turn(combat_state);
            player_turn = combat_state.active.is_player;
            if (!player_turn) enemy_turn_timer = enemy_turn_delay;
            exit;
        }
    }

    // --- T key: End Turn manually ---
    if (keyboard_check_pressed(ord("T"))) {
        if (player.energy > 0) {
            array_push(combat_log, "Turn ended — " + string(player.energy) + " AP unspent.");
        }
        // Iron Skin ticks once per player turn end, not per ability cast
        if (variable_struct_exists(player, "iron_skin_duration") && player.iron_skin_duration > 0) {
            player.iron_skin_duration--;
            if (player.iron_skin_duration <= 0) {
                player.damage_reduction = 0;
                array_push(combat_log, "Iron Skin wore off.");
            }
        }
        combat_next_turn(combat_state);
        player_turn = combat_state.active.is_player;
        if (!player_turn) {
            enemy_turn_timer = enemy_turn_delay;
        }
    }

    // --- Cast attempt (Space, Enter, click, or 1-4 hotkey) ---
    if (keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter) || _should_cast) {

        var ab = player.abilities[selected_ability];

        // Already used this ability this turn?
        var _already_used = false;
        for (var _ui = 0; _ui < array_length(abilities_used_this_turn); _ui++) {
            if (abilities_used_this_turn[_ui] == ab.name) { _already_used = true; break; }
        }

        // Control gate — root blocks melee abilities, silence blocks spells, stun blocks all.
        // Dormant until an enemy applies control to the player, but ready. (SYSTEMS_ATTACK_CLASS.md)
        var _ctrl_block = combat_control_block_reason(player, ability_attack_class(ab));

        // Cooldown gate — evasion abilities (Blink / Shadow Step) can't be re-cast
        // until their per-combat cooldown counter ticks back to 0.
        var _cd_left = (variable_struct_exists(player, "ability_cd")
                        && selected_ability < array_length(player.ability_cd))
                       ? player.ability_cd[selected_ability] : 0;

        // Quickcast aspect rune: the first SPELL each combat costs -1 AP. Evaluate the
        // resource gate against the discounted cost (so it's castable at cost-1), but
        // only consume the rune in the cast branch. ab.energy_cost is restored after spend.
        var _qc_orig_ec = ab.energy_cost;
        var _qc_elig = rune_aspect_socketed("quickcast")
                       && variable_struct_exists(player, "rune_first_spell_used")
                       && !player.rune_first_spell_used
                       && ability_class_is_spell(ability_attack_class(ab));
        if (_qc_elig) ab.energy_cost = max(0, ab.energy_cost - 1);
        var _qc_can_cast = ability_can_cast(ab, player);
        ab.energy_cost = _qc_orig_ec;   // restore; re-applied below only on actual cast

        if (_already_used) {
            array_push(combat_log, ab.name + " already used this turn.");

        } else if (_cd_left > 0) {
            array_push(combat_log, ab.name + " is on cooldown (" + string(_cd_left) + " turn(s)).");

        } else if (_ctrl_block != "") {
            array_push(combat_log, "You are " + _ctrl_block + " — can't use " + ab.name + ".");

        // Resource gate — must have enough energy and secondary resource (Quickcast-aware)
        } else if (!_qc_can_cast) {
            array_push(combat_log, "Not enough resources.");

        } else {
            // Quickcast: apply the -1 AP discount for this cast and consume the rune.
            if (_qc_elig) {
                ab.energy_cost = max(0, ab.energy_cost - 1);
                player.rune_first_spell_used = true;
                array_push(combat_log, "Quickcast rune — " + ab.name + " costs 1 less AP!");
            }

            // Cracked Focus (class weapon): first SPELL each combat costs 1 less AP (min 1).
            if (variable_struct_exists(player, "cf_first_spell_ap") && player.cf_first_spell_ap
                && !player.cf_used && ability_class_is_spell(ability_attack_class(ab))) {
                ab.energy_cost = max(1, ab.energy_cost - 1);
                player.cf_used = true;
                array_push(combat_log, "Cracked Focus — first spell costs 1 less AP!");
            }

            // Gatewarden's Brand: first ability each combat costs 0 AP.
            // Only the energy_cost is waived; secondary resource cost still applies.
            var _brand_proc = player.gatewarden_brand && !player.gatewarden_used;
            if (_brand_proc) {
                player.gatewarden_used = true;
                var _saved_ec = ab.energy_cost;
                ab.energy_cost = 0;
                ability_spend_resources(ab, player);
                ab.energy_cost = _saved_ec;
                array_push(combat_log, "Gatewarden's Brand — " + ab.name + " costs 0 AP!");
            } else {
                ability_spend_resources(ab, player);
            }

            // Restore the real energy_cost (Arcane Surge etc. read the ability's true cost).
            // Unconditional — Quickcast and Cracked Focus both mutate it; _qc_orig_ec is the
            // untouched original captured before any discount.
            ab.energy_cost = _qc_orig_ec;

            if (!ab.self_targeted) {
                // --- Build the target list ---
                // AoE abilities resolve against every living enemy; Focused Power
                // converts an AoE into a single hard-hitting strike on the selection.
                var _is_aoe = variable_struct_exists(ab, "is_aoe") && ab.is_aoe
                              && !trait_active("Focused Power");
                var _focused_burst = variable_struct_exists(ab, "is_aoe") && ab.is_aoe
                                     && trait_active("Focused Power");
                var _aoe_falloff = variable_struct_exists(ab, "aoe_falloff") ? ab.aoe_falloff : 1.0;

                var _targets = [];
                if (_is_aoe) {
                    for (var _ti = 0; _ti < array_length(combat_state.combatants); _ti++) {
                        var _tc = combat_state.combatants[_ti];
                        if (!_tc.is_player && !_tc.is_defeated) array_push(_targets, _tc);
                    }
                } else {
                    // Single target: the selected-th living enemy (with safety fallback)
                    var _single = undefined;
                    var _living_idx = 0;
                    for (var _ti = 0; _ti < array_length(combat_state.combatants); _ti++) {
                        var _tc = combat_state.combatants[_ti];
                        if (!_tc.is_player && !_tc.is_defeated) {
                            if (_living_idx == selected_target) { _single = _tc; break; }
                            _living_idx++;
                        }
                    }
                    if (_single == undefined) {
                        selected_target = 0;
                        for (var _ti = 0; _ti < array_length(combat_state.combatants); _ti++) {
                            var _tc = combat_state.combatants[_ti];
                            if (!_tc.is_player && !_tc.is_defeated) { _single = _tc; break; }
                        }
                    }
                    if (_single != undefined) array_push(_targets, _single);
                }

                if (array_length(_targets) == 0) {
                    // All enemies already down — victory check will fire next frame
                    array_push(combat_log, ab.name + " found no target.");

                } else {
                  // Echo aspect rune: the first AoE each combat echoes for 50% to every
                  // enemy hit. Evaluated once for the whole AoE; consumed after the loop.
                  var _echo_now = _is_aoe && rune_aspect_socketed("echo")
                                  && variable_struct_exists(player, "rune_first_aoe_used")
                                  && !player.rune_first_aoe_used;

                  // Void Scepter (class weapon): a spell crit refunds 1 AP — once per cast,
                  // even if an AoE crits multiple targets.
                  var _scepter_refunded = false;

                  // Resolve the ability against each target independently.
                  for (var _tgi = 0; _tgi < array_length(_targets); _tgi++) {
                    var target = _targets[_tgi];

                    // --- Hit roll ---
                    // Blind on the caster lowers accuracy (percentage points).
                    // Hunter aspect rune adds accuracy to ranged actions.
                    var _cast_acc = ab.base_acc - combat_status_max(player, "blind") * 100
                                    + rune_aspect_ranged_acc(ab);
                    var _hit = combat_roll_hit(
                        player.stats,
                        _cast_acc,
                        target.dodge,
                        ab.guaranteed_hit
                    );

                    if (!_hit) {
                        array_push(combat_log, ab.name + " missed!");

                    } else {
                        // --- Crit roll (skip for abilities with no crit) ---
                        var _crit_result = { critted: false, multiplier: 1.0,
                                             bonus_el_stacks: 0, effect_quality: 0 };
                        if (ab.crit_type != -1) {
                            // Surge aspect rune + Duelist boon add crit chance.
                            var _wpn_crit = (variable_struct_exists(player, "weapon_crit_bonus")) ? player.weapon_crit_bonus : 0;
                            _crit_result = combat_roll_crit(
                                player.stats,
                                ab.base_crit + rune_aspect_spell_crit(ab) + boon_value("duelist") + _wpn_crit,
                                ab.crit_type
                            );
                        }

                        // --- Damage calculation ---
                        var _dmg = ab.base_damage;
                        var _ab_stat_dtype = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
                        if (ab.base_damage > 0 && variable_struct_exists(player, "derived")) {
                            if (_ab_stat_dtype == 0) {
                                _dmg += player.derived.phys_dmg_bonus + player.derived.cha_dmg_bonus;
                            } else if (_ab_stat_dtype == 1) {
                                _dmg += player.derived.elem_dmg_bonus + player.derived.cha_dmg_bonus;
                            } else if (_ab_stat_dtype == 2) {
                                _dmg += player.derived.cha_dmg_bonus;
                            } else if (_ab_stat_dtype == 3) {
                                _dmg += player.derived.elem_dmg_bonus + player.derived.cha_dmg_bonus;
                            }
                        }

                        // --- Expansion ability damage riders (pre-crit so they scale) ---
                        // Arcane Echo: scales with Souls held after paying its cost.
                        if (ab.name == "Arcane Echo" && variable_struct_exists(player, "souls")) {
                            _dmg += player.souls * 4;
                        }
                        // Killing Spree: bonus per debuff / trap / mark on the target.
                        if (ab.name == "Killing Spree" && variable_struct_exists(target, "status_effects")) {
                            _dmg += array_length(target.status_effects) * 5;
                        }
                        // Vanish: the empowered strike out of stealth deals bonus damage.
                        if (variable_struct_exists(player, "vanish_bonus") && player.vanish_bonus) {
                            _dmg += 12;
                            player.vanish_bonus = false;
                            array_push(combat_log, "Vanish: ambush strike for +12 damage!");
                        }
                        // Snipe: +20 against a target already suffering a debuff/DoT/blind.
                        if (ab.name == "Snipe" && (combat_has_status(target, "vulnerable")
                            || combat_has_status(target, "weaken") || combat_has_status(target, "dot")
                            || combat_has_status(target, "blind"))) {
                            _dmg += 20;
                        }

                        // ===== §3 ability-rework combo riders (pre-crit so they scale) =====
                        // Shared "is this target Exposed/debuffed?" test (mirrors Snipe's set).
                        var _tgt_exposed = (combat_has_status(target, "vulnerable")
                            || combat_has_status(target, "weaken") || combat_has_status(target, "dot")
                            || combat_has_status(target, "blind") || combat_has_status(target, "mortality")
                            || combat_has_status(target, "silence"));

                        // Arcane Burst: a true payoff — +40% into an Exposed/debuffed foe.
                        if (ab.name == "Arcane Burst" && _tgt_exposed) {
                            _dmg = round(_dmg * 1.4);
                            array_push(combat_log, "Arcane Burst strikes an Exposed foe (+40%)!");
                        }
                        // Flurry: +3 damage per debuff/DoT stack on the target.
                        if (ab.name == "Flurry" && variable_struct_exists(target, "status_effects")) {
                            _dmg += array_length(target.status_effects) * 3;
                        }
                        // Soul Nova: consume up to 4 Souls for +7 damage each (single-target).
                        if (ab.name == "Soul Nova" && variable_struct_exists(player, "souls")) {
                            var _nova_souls = min(player.souls, 4);
                            if (_nova_souls > 0) {
                                _dmg += _nova_souls * 7;
                                player.souls -= _nova_souls;
                                array_push(combat_log, "Soul Nova consumes " + string(_nova_souls) + " Souls (+" + string(_nova_souls * 7) + " dmg)!");
                            }
                        }
                        // Assassinate: execute — DOUBLE damage to a target below 30% HP.
                        if (ab.name == "Assassinate") {
                            var _ass_ratio = (target.max_HP > 0) ? (target.HP / target.max_HP) : 1;
                            if (_ass_ratio < 0.30) {
                                _dmg *= 2;
                                array_push(combat_log, "Assassinate — execute! Double damage.");
                            }
                        }
                        // Rupture: detonate all bleed/poison stacks — +5 per remaining tick,
                        // then clear those DoTs from the target.
                        if (ab.name == "Rupture" && variable_struct_exists(target, "status_effects")) {
                            var _bleed_turns = 0;
                            var _rupture_kept = [];
                            for (var _rsi = 0; _rsi < array_length(target.status_effects); _rsi++) {
                                var _rse  = target.status_effects[_rsi];
                                var _rkind = variable_struct_exists(_rse, "kind") ? _rse.kind : "";
                                if (_rkind == "dot") {
                                    _bleed_turns += (variable_struct_exists(_rse, "duration") ? _rse.duration : 0);
                                } else {
                                    array_push(_rupture_kept, _rse);
                                }
                            }
                            if (_bleed_turns > 0) {
                                _dmg += _bleed_turns * 5;
                                target.status_effects = _rupture_kept;
                                array_push(combat_log, "Rupture detonates " + string(_bleed_turns) + " bleed ticks (+" + string(_bleed_turns * 5) + " dmg)!");
                            }
                        }
                        // ===== end §3 combo riders =====

                        // Weaken on the caster reduces outgoing damage (max of stacked debuffs).
                        var _cast_weaken = combat_status_max(player, "weaken");
                        if (_cast_weaken > 0) _dmg = max(1, round(_dmg * (1 - _cast_weaken)));

                        if (_crit_result.critted) {
                            _dmg = round(_dmg * _crit_result.multiplier);
                        }

                        var _final_dmg = combat_resolve_damage(
                            _dmg,
                            ab.damage_type,
                            target.armor,
                            target.el_resist
                        );

                        // Vulnerable: target takes extra flat damage from every hit (summed).
                        _final_dmg += combat_status_total(target, "vulnerable");

                        // Arcane Surge: abilities costing 4+ AP deal +25% damage (Arcanist only)
                        if (player.class_id == 0 && trait_active("Arcane Surge")
                            && variable_struct_exists(ab, "energy_cost") && ab.energy_cost >= 4) {
                            _final_dmg = floor(_final_dmg * (1 + 0.25 * trait_potency_mult("Arcane Surge")));
                        }
                        // Berserker Rage: below 40% HP deal +20% damage (Bloodwarden only)
                        if (player.class_id == 1 && trait_active("Berserker Rage")
                            && player.HP <= floor(player.max_HP * 0.40)) {
                            _final_dmg = floor(_final_dmg * (1 + 0.20 * trait_potency_mult("Berserker Rage")));
                        }
                        // Serrated Strikes: physical abilities apply 1 bleed stack (Shadowstrider only)
                        if (player.class_id == 2 && trait_active("Serrated Strikes")
                            && variable_struct_exists(ab, "damage_type") && ab.damage_type == 0
                            && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            var _bleed_se = {
                                name:         "Serrated Bleed",
                                effect_type:  "dot",
                                effect_value: round(3 * trait_potency_mult("Serrated Strikes")),
                                duration:     2,
                                source:       "player"
                            };
                            array_push(target.status_effects, _bleed_se);
                            array_push(combat_log, "Serrated Strikes: bleed applied to " + target.name + "!");
                        }

                        // Aspect runes: Ember (elemental), Hemorrhage (blood),
                        // Serration (physical attacks) add an outgoing-damage %.
                        var _aspect_dmg_pct = rune_aspect_damage_pct(ab);
                        if (_aspect_dmg_pct > 0) _final_dmg = round(_final_dmg * (1 + _aspect_dmg_pct));

                        // Boons: Bloodlust / Glass Cannon (+ Executioner vs low-HP targets).
                        var _thf = (target.max_HP > 0) ? (target.HP / target.max_HP) : 1;
                        var _boon_dm = boon_damage_mult(_thf);
                        if (_boon_dm != 1.0) _final_dmg = max(1, round(_final_dmg * _boon_dm));

                        // Focused Power: an AoE funneled to one target hits 50% harder.
                        if (_focused_burst) _final_dmg = round(_final_dmg * 1.5);
                        // AoE falloff (1.0 = full damage to every enemy).
                        if (_is_aoe && _aoe_falloff != 1.0) _final_dmg = max(1, round(_final_dmg * _aoe_falloff));

                        // Class-weapon damage rider: Vaultstone Wand boosts spell damage.
                        var _atk_class = ability_attack_class(ab);
                        if (variable_struct_exists(player, "spell_dmg_bonus") && player.spell_dmg_bonus > 0
                            && ability_class_is_spell(_atk_class)) {
                            _final_dmg = max(1, round(_final_dmg * (1 + player.spell_dmg_bonus)));
                        }

                        combat_apply_damage(target, _final_dmg);

                        // Gravelstone Sword (class weapon): leech a share of melee damage dealt.
                        if (variable_struct_exists(player, "weapon_lifesteal") && player.weapon_lifesteal > 0
                            && ability_class_is_melee(_atk_class) && _final_dmg > 0) {
                            var _ls = combat_heal_after_mortality(player, max(1, round(_final_dmg * player.weapon_lifesteal)));
                            if (_ls > 0) {
                                player.HP = min(player.max_HP, player.HP + _ls);
                                array_push(combat_log, "Gravelstone Sword — leeched " + string(_ls) + " HP.");
                            }
                        }
                        // Void Scepter (class weapon): a spell crit refunds 1 AP (once per cast).
                        if (!_scepter_refunded && variable_struct_exists(player, "spell_crit_ap") && player.spell_crit_ap
                            && _crit_result.critted && ability_class_is_spell(_atk_class)) {
                            player.energy += 1;
                            _scepter_refunded = true;
                            array_push(combat_log, "Void Scepter — spell crit restores 1 AP!");
                        }

                        // --- VFX: hit flash, popup, attack slide, screen shake ---
                        target.hit_flash   = 15;
                        screen_shake_timer = 8;
                        var _vfx_slot = 0;
                        for (var _vsi = 0; _vsi < array_length(combat_state.combatants); _vsi++) {
                            if (combat_state.combatants[_vsi] == target) break;
                            if (!combat_state.combatants[_vsi].is_player) _vfx_slot++;
                        }
                        var _vfx_ex = 1080 + _vfx_slot * (-80);
                        var _vfx_ey = 155  + _vfx_slot * 70;
                        var _pop_col = (_crit_result.critted) ? c_yellow : make_color_rgb(255, 100, 100);
                        array_push(damage_popups, { value: _final_dmg, x: _vfx_ex, y: _vfx_ey - 70, timer: 50, col: _pop_col });
                        attack_anim_timer     = 20;
                        attack_anim_src_x     = 220;
                        attack_anim_src_y     = 310;
                        attack_anim_dst_x     = _vfx_ex - 60;
                        attack_anim_dst_y     = _vfx_ey;
                        attack_anim_is_player = true;

                        // VFX impact sprite keyed to damage type (3 = blood reuses slash)
                        var _ab_dtype = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
                        var _vfx_spr_list = [spr_vfx_slash, spr_vfx_fire, spr_vfx_void, spr_vfx_slash];
                        if (_ab_dtype >= 0 && _ab_dtype <= 3) {
                            vfx_spr = _vfx_spr_list[_ab_dtype];
                        } else {
                            vfx_spr = spr_vfx_arcane;
                        }
                        vfx_x     = _vfx_ex;
                        vfx_y     = _vfx_ey;
                        vfx_timer = 20;
                        // Per-class attack audio
                        switch (player.class_id) {
                            case 0: // Arcanist — arcane caster, no grunt
                                audio_play_sound(spell1, 1, false);
                                // NOTE: the "Magic" chime is the heal twinkle and is now
                                // reserved for heals only — it used to layer onto offensive
                                // Arcanist casts (incl. drains), which felt redundant.
                                break;
                            case 1: // Bloodwarden — heavy hitter, always grunts
                                audio_play_sound((_ab_dtype == 0) ? attack1 : spell1, 1, false);
                                audio_play_sound(grunt, 1, false);
                                break;
                            case 2: // Shadowstrider — quick and quiet
                                audio_play_sound((_ab_dtype == 0) ? utility2 : teleport, 1, false);
                                break;
                            default:
                                audio_play_sound((_ab_dtype == 0) ? attack1 : spell1, 1, false);
                                audio_play_sound(grunt, 1, false);
                        }

                        // --- Hit log ---
                        var _log_entry = player.name + " used " + ab.name
                            + " for " + string(_final_dmg) + " damage";
                        if (_crit_result.critted) _log_entry += " (CRIT!)";
                        array_push(combat_log, _log_entry);

                        // --- On-hit heal (e.g. Void Drain), reduced by Mortality ---
                        // Leech aspect rune boosts healing from drain (dtype 2) abilities.
                        if (ab.effect_type == "heal") {
                            var _base_heal = ab.effect_value;
                            var _leech_pct = rune_aspect_drain_heal_pct(ab);
                            if (_leech_pct > 0) _base_heal = round(_base_heal * (1 + _leech_pct));
                            var _heal_amt = combat_heal_after_mortality(player, _base_heal);
                            var _heal = min(player.max_HP - player.HP, _heal_amt);
                            player.HP += _heal;
                            if (_heal > 0) {
                                array_push(damage_popups, { value: _heal, x: 220, y: 240, timer: 45, col: c_lime });
                            }
                            array_push(combat_log, player.name + " restored " + string(_heal) + " HP.");
                        }

                        // --- Void Drain soul generation ---
                        if (ab.name == "Void Drain") {
                            if (player.class_id == 0 && variable_struct_exists(player, "souls")) {
                                player.souls = min(player.souls_max, player.souls + 1);
                            }
                        }

                        // --- Blood Leech blood generation ---
                        if (ab.name == "Blood Leech") {
                            if (player.class_id == 1 && variable_struct_exists(player, "blood")) {
                                player.blood = min(player.blood_max, player.blood + 1);
                            }
                        }

                        // --- Generic "resource" effect (revives the dead data path; see
                        //     ROADMAP §"Dead resource effect type"). Grants effect_value of
                        //     the caster's secondary resource on a landed hit. Fixes Soulfire
                        //     (+2 Souls), which previously never generated. Self-targeted
                        //     resource abilities (Soul Harvest) are handled in the self branch.
                        if (ab.effect_type == "resource" && ab.effect_value > 0) {
                            var _res_amt = ab.effect_value;
                            if (variable_struct_exists(player, "souls")) {
                                player.souls = min(player.souls_max, player.souls + _res_amt);
                                array_push(combat_log, ab.name + ": +" + string(_res_amt) + " Souls.");
                            } else if (variable_struct_exists(player, "blood")) {
                                player.blood = min(player.blood_max, player.blood + _res_amt);
                                array_push(combat_log, ab.name + ": +" + string(_res_amt) + " Blood.");
                            } else if (variable_struct_exists(player, "preparation")) {
                                player.preparation = min(player.preparation_max, player.preparation + _res_amt);
                                array_push(combat_log, ab.name + ": +" + string(_res_amt) + " Preparation.");
                            }
                        }

                        // --- Aspect runes: Bulwark (melee-attack shield) + Anchor (melee Weaken) ---
                        var _bul = rune_aspect_melee_shield(ab);
                        if (_bul > 0) {
                            if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                            player.shield_hp += _bul;
                            array_push(combat_log, "Bulwark rune: +" + string(_bul) + " shield.");
                        }
                        var _anc = rune_aspect_melee_weaken_turns(ab);
                        if (_anc > 0 && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            array_push(target.status_effects, {
                                name:         "Weaken",
                                effect_type:  "debuff",
                                kind:         "weaken",
                                effect_value: 0.20,   // -20% outgoing damage (vs 0.30 for dedicated weakens)
                                duration:     _anc,
                                source:       "player"
                            });
                            array_push(combat_log, "Anchor rune: " + target.name + " is Weakened!");
                        }

                        // --- Defeat check on target (shared kill handler) ---
                        if (target.HP <= 0) {
                            combat_on_enemy_defeated(target, player, combat_log);
                        }

                        // --- Echo: 50% second instance to this target (first AoE only) ---
                        if (_echo_now && !target.is_defeated && _final_dmg > 0) {
                            var _echo_dmg = max(1, round(_final_dmg * 0.5));
                            combat_apply_damage(target, _echo_dmg);
                            target.hit_flash = max(target.hit_flash, 10);
                            array_push(damage_popups, { value: _echo_dmg, x: _vfx_ex, y: _vfx_ey - 40, timer: 45, col: make_color_rgb(180, 140, 255) });
                            array_push(combat_log, "Echo: " + target.name + " takes " + string(_echo_dmg) + " more!");
                            if (target.HP <= 0) combat_on_enemy_defeated(target, player, combat_log);
                        }

                        // --- Chain Caster: single-target elemental/void/blood damage
                        //     splashes 40% to every OTHER living enemy. ---
                        if (!_is_aoe && trait_active("Chain Caster") && ab.base_damage > 0
                            && (ab.damage_type == 1 || ab.damage_type == 2 || ab.damage_type == 3)) {
                            var _splash = max(1, round(_final_dmg * 0.4));
                            for (var _cci = 0; _cci < array_length(combat_state.combatants); _cci++) {
                                var _ccc = combat_state.combatants[_cci];
                                if (_ccc.is_player || _ccc.is_defeated || _ccc == target) continue;
                                combat_apply_damage(_ccc, _splash);
                                _ccc.hit_flash = max(_ccc.hit_flash, 10);
                                array_push(combat_log, "Chain Caster: " + _ccc.name
                                    + " takes " + string(_splash) + " splash damage!");
                                if (_ccc.HP <= 0) combat_on_enemy_defeated(_ccc, player, combat_log);
                            }
                        }

                        // --- Apply status effect to target (typed status layer) ---
                        // Only applied on a living target so DoTs don't stack on corpses.
                        if (!target.is_defeated) {
                            // DoTs, debuffs, and the control traps (Bear Trap root /
                            // Death Snare stun) all land as typed statuses.
                            if (ab.effect_type == "dot" || ab.effect_type == "debuff"
                                || ab.name == "Bear Trap" || ab.name == "Death Snare") {
                                var _status_ev  = ab.effect_value;
                                var _status_dur = ab.effect_duration;
                                if (ab.effect_type == "dot" && variable_struct_exists(player, "derived")) {
                                    _status_ev += player.derived.dot_dmg_bonus;
                                }
                                if (_crit_result.effect_quality == 1) {
                                    _status_dur += 1;
                                }
                                var _status_kind = ability_status_kind(ab);
                                var _status = {
                                    name:         ab.name,
                                    effect_type:  ab.effect_type,
                                    kind:         _status_kind,
                                    effect_value: _status_ev,
                                    duration:     _status_dur,
                                    source:       "player"
                                };
                                array_push(target.status_effects, _status);
                                array_push(combat_log, ab.name + " applied to " + target.name + "!");

                                // Plaguebearer: single-target debuffs/DoTs also strike every
                                // OTHER living enemy at half duration.
                                if (!_is_aoe && trait_active("Plaguebearer")) {
                                    var _pb_dur = max(1, floor(_status_dur / 2));
                                    var _pb_spread = false;
                                    for (var _pbi = 0; _pbi < array_length(combat_state.combatants); _pbi++) {
                                        var _pbc = combat_state.combatants[_pbi];
                                        if (_pbc.is_player || _pbc.is_defeated || _pbc == target) continue;
                                        if (!variable_struct_exists(_pbc, "status_effects")) continue;
                                        array_push(_pbc.status_effects, {
                                            name:         ab.name,
                                            effect_type:  ab.effect_type,
                                            kind:         _status_kind,
                                            effect_value: _status_ev,
                                            duration:     _pb_dur,
                                            source:       "player"
                                        });
                                        _pb_spread = true;
                                    }
                                    if (_pb_spread) array_push(combat_log, "Plaguebearer spreads " + ab.name + " to all enemies!");
                                }
                            }
                        }
                    }   // end if (_hit) else
                  }     // end per-target for loop

                  // Echo consumes its once-per-combat charge after the full AoE resolves.
                  if (_echo_now) player.rune_first_aoe_used = true;
                }       // end "targets non-empty" else

            } else {
                // --- Self-targeted ability ---
                array_push(combat_log, player.name + " used " + ab.name + ".");
                if (ab.name == "Blink" || ab.name == "Shadow Step") {
                    audio_play_sound(teleport, 1, false);
                } else if (ab.effect_type == "heal") {
                    audio_play_sound(Magic, 1, false);   // heal "twinkle" — reserved for heals
                } else {
                    audio_play_sound(spell1, 1, false);  // non-heal self-cast (buffs / resource gen)
                }

                if (ab.effect_type == "heal") {
                    var _heal_amt = combat_heal_after_mortality(player, ab.effect_value);
                    var _heal = min(player.max_HP - player.HP, _heal_amt);
                    player.HP += _heal;
                    if (_heal > 0) {
                        array_push(damage_popups, { value: _heal, x: 220, y: 240, timer: 45, col: c_lime });
                    }
                    array_push(combat_log, player.name + " restored " + string(_heal) + " HP.");
                }

                // --- Generic "resource" effect for SELF-targeted abilities (Soul Harvest).
                //     Mirrors the on-hit path above; revives the dead data path. ---
                if (ab.effect_type == "resource" && ab.effect_value > 0) {
                    var _sres_amt = ab.effect_value;
                    if (variable_struct_exists(player, "souls")) {
                        player.souls = min(player.souls_max, player.souls + _sres_amt);
                        array_push(combat_log, ab.name + ": +" + string(_sres_amt) + " Souls.");
                    } else if (variable_struct_exists(player, "blood")) {
                        player.blood = min(player.blood_max, player.blood + _sres_amt);
                        array_push(combat_log, ab.name + ": +" + string(_sres_amt) + " Blood.");
                    } else if (variable_struct_exists(player, "preparation")) {
                        player.preparation = min(player.preparation_max, player.preparation + _sres_amt);
                        array_push(combat_log, ab.name + ": +" + string(_sres_amt) + " Preparation.");
                    }
                }

                // --- Iron Skin: set flat damage reduction for N turns ---
                if (ab.name == "Iron Skin") {
                    player.damage_reduction   = ab.effect_value;
                    player.iron_skin_duration = ab.effect_duration;
                    array_push(combat_log,
                        "Hero activates Iron Skin — incoming damage reduced by "
                        + string(ab.effect_value) + " for " + string(ab.effect_duration) + " turns.");
                }

                // --- Soul Shield: add to the damage-absorbing shield pool ---
                if (ab.name == "Soul Shield") {
                    player.shield_hp += ab.effect_value;
                    array_push(combat_log,
                        "Soul Shield raised — absorbs the next " + string(ab.effect_value) + " damage.");
                }

                // --- Blink: chance-based dodge window for the next attack (2-turn CD) ---
                if (ab.name == "Blink") {
                    player.is_untargetable    = true;
                    player.untargetable_turns = 1;
                    player.ability_cd[selected_ability] = ability_cooldown(ab);
                    array_push(combat_log, "Hero blinks — "
                        + string(combat_evasion_chance(player)) + "% to dodge the next attack!");
                }

                // --- Shadow Step: chance to dodge the next single-target attack (2-turn CD) ---
                if (ab.name == "Shadow Step") {
                    player.shadow_step_active = true;
                    player.ability_cd[selected_ability] = ability_cooldown(ab);
                    array_push(combat_log, "Hero readies a dodge — "
                        + string(combat_evasion_chance(player)) + "% to evade the next attack!");
                }

                // --- Bloodthorn Aura: reflect flat damage on each incoming hit ---
                if (ab.name == "Bloodthorn Aura") {
                    player.bloodthorn_active   = true;
                    player.bloodthorn_duration = ab.effect_duration;
                    player.bloodthorn_value    = ab.effect_value;
                    array_push(combat_log,
                        player.name + " raises Bloodthorn Aura — reflects "
                        + string(ab.effect_value) + " damage per hit for "
                        + string(ab.effect_duration) + " turns.");
                }

                // --- Second Wind: restore 1 secondary resource (heal handled above) ---
                if (ab.name == "Second Wind") {
                    if (variable_struct_exists(player, "souls")) {
                        player.souls = min(player.souls_max, player.souls + 1);
                        array_push(combat_log, "Second Wind: +1 Soul.");
                    } else if (variable_struct_exists(player, "blood")) {
                        player.blood = min(player.blood_max, player.blood + 1);
                        array_push(combat_log, "Second Wind: +1 Blood.");
                    } else if (variable_struct_exists(player, "preparation")) {
                        player.preparation = min(player.preparation_max, player.preparation + 1);
                        array_push(combat_log, "Second Wind: +1 Preparation.");
                    }
                }

                // --- Adrenaline Rush: +1 AP this turn, once per combat ---
                if (ab.name == "Adrenaline Rush") {
                    if (!variable_struct_exists(player, "adrenaline_used") || !player.adrenaline_used) {
                        player.adrenaline_used = true;
                        player.energy += 1;
                        array_push(combat_log, "Adrenaline Rush: +1 AP this turn!");
                    } else {
                        array_push(combat_log, "Adrenaline Rush already spent this combat.");
                    }
                }

                // --- Sanguine Pact: spend 8 HP (never lethal) to gain 3 Blood ---
                if (ab.name == "Sanguine Pact" && variable_struct_exists(player, "blood")) {
                    var _sp_cost = min(8, player.HP - 1);
                    player.HP   -= _sp_cost;
                    player.blood = min(player.blood_max, player.blood + 3);
                    array_push(combat_log, "Sanguine Pact: -" + string(_sp_cost) + " HP, +3 Blood.");
                }

                // --- Vanish: untargetable next attack; next strike deals bonus damage ---
                if (ab.name == "Vanish") {
                    player.is_untargetable    = true;
                    player.untargetable_turns = 1;
                    player.vanish_bonus       = true;
                    array_push(combat_log, "Hero vanishes — "
                        + string(combat_evasion_chance(player)) + "% to dodge the next attack, next strike empowered!");
                }
            }

            // Track use for this turn; player presses T to end their turn
            array_push(abilities_used_this_turn, ab.name);
        }
    }


// -----------------------------------------------------------------------------
// 4. ENEMY TURN
// -----------------------------------------------------------------------------
} else {

    // Immediately skip defeated or player combatants without waiting for the
    // timer — avoids a full 3-second pause on dead enemy slots
    var _actor = combat_state.active;
    if (_actor.is_player || _actor.is_defeated) {
        combat_next_turn(combat_state);
        player_turn      = combat_state.active.is_player;
        if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
        enemy_turn_timer = enemy_turn_delay;
        exit;
    }

    // Count down the delay before the enemy acts — gives the player time
    // to read the log and any active telegraph warning
    enemy_turn_timer--;

    if (enemy_turn_timer <= 0) {

        var actor = combat_state.active;

        // If the queue somehow lands on a player or a defeated enemy, skip the
        // slot and advance without acting (handles edge cases during AoE kills)
        if (actor.is_player || actor.is_defeated) {
            combat_next_turn(combat_state);
            player_turn       = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            if (player_turn) {
                enemy_turn_timer = 0;
            } else {
                enemy_turn_timer = enemy_turn_delay;
            }
            exit;
        }

        // Capture control state BEFORE the tick decrements durations, so a 1-turn
        // control still costs the enemy this turn. reach/kind decide which apply:
        // stun=all, root=melee enemies, silence=spellcasters. See SYSTEMS_ATTACK_CLASS.md.
        var _actor_reach = variable_struct_exists(actor, "reach") ? actor.reach : "melee";
        var _actor_kind  = variable_struct_exists(actor, "kind")  ? actor.kind  : "attack";
        var _ctrl_reason = "";
        if (combat_has_status(actor, "stun"))                                       _ctrl_reason = "is stunned and cannot act";
        else if (combat_has_status(actor, "root")    && _actor_reach == "melee")    _ctrl_reason = "is rooted and can't reach you";
        else if (combat_has_status(actor, "silence") && _actor_kind  == "spell")    _ctrl_reason = "is silenced and can't cast";
        var _was_controlled = (_ctrl_reason != "");

        // --- Tick status effects on this enemy ---
        // Runs before the enemy attacks so DoT can kill the enemy before they act.
        var _se_count = array_length(actor.status_effects);
        var _se_keep  = [];
        // Counts DoT popups spawned this tick so stacked effects (e.g. two poisons)
        // can be staggered in time/space instead of overlapping into one number.
        var _dot_pop_n = 0;
        for (var _si = 0; _si < _se_count; _si++) {
            var _se = actor.status_effects[_si];

            if (_se.effect_type == "dot") {
                // DoT bypasses armor — poison and bleed are internal damage
                var _dot_dmg = _se.effect_value;
                combat_apply_damage(actor, _dot_dmg);
                // Vampiric Edge: Bloodwarden heals 2 HP per DoT tick from player effects
                if (_se.source == "player" && player.class_id == 1 && trait_active("Vampiric Edge")) {
                    var _vamp_heal = round(2 * trait_potency_mult("Vampiric Edge"));
                    player.HP = min(player.max_HP, player.HP + _vamp_heal);
                    array_push(combat_log, "Vampiric Edge: +" + string(_vamp_heal) + " HP.");
                }
                // VFX: hit flash + orange damage popup
                actor.hit_flash    = 10;
                screen_shake_timer = max(screen_shake_timer, 5);
                var _dot_slot = 0;
                for (var _dsi = 0; _dsi < array_length(combat_state.combatants); _dsi++) {
                    if (combat_state.combatants[_dsi] == actor) break;
                    if (!combat_state.combatants[_dsi].is_player) _dot_slot++;
                }
                var _dot_ex = 1080 + _dot_slot * (-80);
                var _dot_ey = 155  + _dot_slot * 70;
                // Stagger stacked DoT numbers: each successive popup this tick starts
                // ~14 frames later and shifts right, so two poison stacks read "6" then "6".
                array_push(damage_popups, {
                    value: _dot_dmg,
                    x: _dot_ex + _dot_pop_n * 24,
                    y: _dot_ey - 70,
                    timer: 45,
                    delay: _dot_pop_n * 14,
                    col: make_color_rgb(255, 140, 0)
                });
                _dot_pop_n++;
                array_push(combat_log,
                    actor.name + " takes " + string(_dot_dmg) + " " + _se.name + " damage!");
                if (actor.HP <= 0) {
                    actor.is_defeated = true;
                    enemy_death_sound(actor.name);
                    array_push(combat_log, actor.name + " defeated by " + _se.name + "!");
                    // --- Gold drop on DoT kill ---
                    var _gold_drop = irandom(actor.gold_max - actor.gold_min) + actor.gold_min;
                    add_gold(_gold_drop);
                    global.current_run_kills++;
                    array_push(combat_log, "Gained " + string(_gold_drop) + "g!");
                    // --- Item / consumable drop ---
                    var _drop_type;
                    if (variable_global_exists("next_enemy_type")) {
                        _drop_type = global.next_enemy_type;
                    } else {
                        _drop_type = "standard";
                    }
                    var _drop_result = handle_enemy_drops(_drop_type);
                    if (_drop_result != "") {
                        array_push(combat_log, "Loot: " + _drop_result + "!");
                    }
                    // --- XP grant on DoT kill ---
                    var _dot_xp_base;
                    if (variable_struct_exists(actor, "xp_value")) {
                        _dot_xp_base = actor.xp_value;
                    } else {
                        _dot_xp_base = 10;
                    }
                    var _dot_xp_floor;
                    if (variable_global_exists("current_floor")) {
                        _dot_xp_floor = global.current_floor;
                    } else {
                        _dot_xp_floor = 1;
                    }
                    var _dot_xp_scale;
                    if (_dot_xp_floor == 2) {
                        _dot_xp_scale = 1.25;
                    } else if (_dot_xp_floor >= 3) {
                        _dot_xp_scale = 1.5;
                    } else {
                        _dot_xp_scale = 1.0;
                    }
                    var _dot_xp_amt   = round(_dot_xp_base * _dot_xp_scale);
                    var _dot_xp_lvls  = grant_xp(_dot_xp_amt);
                    array_push(combat_log, "Gained " + string(_dot_xp_amt) + " XP!");
                    if (_dot_xp_lvls > 0) {
                        audio_play_sound(Chimes__Ascending_, 1, false);
                        array_push(combat_log, "LEVEL UP! Now level " + string(global.run_level) + ".");
                    }
                    // --- Soul Siphon on DoT kill (Arcanist only) ---
                    if (player.class_id == 0 && variable_struct_exists(player, "souls")
                        && trait_active("Soul Siphon")) {
                        player.souls = min(player.souls_max, player.souls + 1);
                        array_push(combat_log, "Soul Siphon: +1 Soul.");
                    }
                }
            }

            // Decrement duration; keep effect if turns remain
            _se.duration--;
            if (_se.duration > 0) {
                array_push(_se_keep, _se);
            } else {
                array_push(combat_log, _se.name + " wore off " + actor.name + ".");
            }
        }
        actor.status_effects = _se_keep;

        // Skip the attack entirely if DoT finished the enemy this frame
        if (actor.is_defeated) {
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Control: stun/root/silence may make the enemy skip its turn ---
        if (_was_controlled) {
            array_push(combat_log, actor.name + " " + _ctrl_reason + "!");
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Check player untargetable (Blink) — Wisdom-scaled dodge CHANCE ---
        // The window always consumes one charge on an incoming attack. On a
        // successful roll the attack whiffs and the enemy turn ends; on a failed
        // roll the blink falters and we FALL THROUGH to the normal attack.
        if (player.is_untargetable) {
            player.untargetable_turns--;
            if (player.untargetable_turns <= 0) player.is_untargetable = false;
            if (irandom(99) < combat_evasion_chance(player)) {
                array_push(combat_log, actor.name + "'s attack passes through thin air!");
                combat_next_turn(combat_state);
                player_turn      = combat_state.active.is_player;
                if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
                enemy_turn_timer = enemy_turn_delay;
                exit;
            } else {
                array_push(combat_log, "The blink falters — " + actor.name + " finds its mark!");
            }
        }

        // --- Check shadow step (dodge next single-target attack) — chance-based ---
        if (player.shadow_step_active) {
            player.shadow_step_active = false;
            if (irandom(99) < combat_evasion_chance(player)) {
                array_push(combat_log, actor.name + "'s attack is dodged!");
                combat_next_turn(combat_state);
                player_turn      = combat_state.active.is_player;
                if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
                enemy_turn_timer = enemy_turn_delay;
                exit;
            } else {
                array_push(combat_log, "The dodge mistimes — the blow connects!");
            }
        }

        // --- Check Phantom Step (auto-miss the very first enemy attack each combat) ---
        if (combat_check_phantom_step(player, combat_log)) {
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Enemy special ability (Difficulty Pass — see SYSTEMS_ENEMY_DIFFICULTY.md) ---
        // If an ability procs it consumes the enemy's whole turn (instead of the basic
        // attack). Statuses applied to the player ride the existing typed-status layer;
        // duration gets +1 (except DoT) to survive the start-of-player-turn tick.
        var _eab = enemy_pick_ability(actor);
        if (_eab != undefined) {
            var _sa_slot = 0;
            for (var _sai = 0; _sai < array_length(combat_state.combatants); _sai++) {
                if (combat_state.combatants[_sai] == actor) break;
                if (!combat_state.combatants[_sai].is_player) _sa_slot++;
            }
            var _sa_x = 1080 + _sa_slot * (-80);
            var _sa_y = 155  + _sa_slot * 70;

            // Family-themed attack/cast sound for any offensive ability (not heals).
            if (_eab.kind != "heal") enemy_attack_sound(actor.name);

            if (_eab.kind == "heal") {
                var _ehl = min(actor.max_HP - actor.HP, _eab.value);
                actor.HP += _ehl;
                actor.hit_flash = max(actor.hit_flash, 6);
                if (_ehl > 0) array_push(damage_popups, { value: _ehl, x: _sa_x, y: _sa_y - 40, timer: 45, col: c_lime });
                array_push(combat_log, actor.name + " " + ((_eab.msg != "") ? _eab.msg : ("mends " + string(_ehl) + " HP")) + ".");

            } else if (_eab.kind == "spell") {
                var _sdmg = combat_mitigate_player(player, _eab.value, _eab.dtype, combat_log);
                combat_apply_damage(player, _sdmg);
                audio_play_sound(hurt, 1, false);
                player.hit_flash = 15; screen_shake_timer = 12;
                array_push(damage_popups, { value: _sdmg, x: 220, y: 240, timer: 50, col: make_color_rgb(255, 130, 60) });
                attack_anim_timer = 20; attack_anim_src_x = _sa_x; attack_anim_src_y = _sa_y;
                attack_anim_dst_x = 290; attack_anim_dst_y = 310; attack_anim_is_player = false; attack_anim_enemy_idx = _sa_slot;
                array_push(combat_log, actor.name + " " + ((_eab.msg != "") ? _eab.msg : "casts a spell") + " for " + string(_sdmg) + " damage!");
                if (player.class_id == 1 && variable_struct_exists(player, "blood")) player.blood = min(player.blood_max, player.blood + 1);
                if (player.HP <= 0 && !combat_try_last_stand(player, combat_log)) player.is_defeated = true;

            } else {
                // debuff / dot / control → typed status on the player
                if (variable_struct_exists(player, "iron_will_active") && player.iron_will_active) {
                    player.iron_will_active = false;
                    array_push(combat_log, "Iron Will absorbs " + actor.name + "'s " + _eab.name + "!");
                } else {
                    var _edur = (_eab.kind == "dot") ? _eab.turns : (_eab.turns + 1);
                    array_push(player.status_effects, {
                        name:         _eab.name,
                        effect_type:  (_eab.kind == "dot") ? "dot" : "debuff",
                        kind:         _eab.status_kind,
                        effect_value: _eab.value,
                        duration:     _edur,
                        source:       "enemy"
                    });
                    array_push(combat_log, actor.name + " " + ((_eab.msg != "") ? _eab.msg : ("inflicts " + _eab.name)) + "!");
                }
            }

            // Ability consumed the enemy's action — advance the turn.
            combat_next_turn(combat_state);
            player_turn = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Determine base damage for this turn (handles telegraph spike) ---
        var _base_dmg = enemy_get_attack_damage(actor, combat_state.round);
        // Weaken debuff on the enemy reduces its outgoing damage (max of stacks).
        var _enemy_weaken = combat_status_max(actor, "weaken");
        if (_enemy_weaken > 0) _base_dmg = max(1, round(_base_dmg * (1 - _enemy_weaken)));

        // Blind debuff on the enemy lowers its accuracy (percentage points);
        // Awakening tier raises it so stacked dodge can't trivialize high tiers.
        var _enemy_acc = actor.acc - combat_status_max(actor, "blind") * 100 + awaken_enemy_acc_bonus();

        // Family-themed attack-swing sound (plays on hit or miss, like a swing whoosh).
        enemy_attack_sound(actor.name);

        // --- Primary attack hit roll ---
        // Enemies don't have a full stats struct; pass a minimal anonymous struct
        // with only the DEX field that combat_roll_hit() needs.
        var _shadow_meld_bonus = (variable_struct_exists(player, "shadow_meld_bonus")) ? player.shadow_meld_bonus : 0;
        player.shadow_meld_bonus = 0; // consume bonus whether hit or miss
        var _effective_dodge = player.dodge + _shadow_meld_bonus;
        var _hit = combat_roll_hit({ DEX: 3 }, _enemy_acc, _effective_dodge, false);

        if (!_hit) {
            array_push(combat_log, actor.name + " attacked but missed!");
            // Shadow Meld: grant +15 dodge for next turn after successfully dodging
            if (player.class_id == 2 && trait_active("Shadow Meld")) {
                player.shadow_meld_bonus = 15;
                array_push(combat_log, "Shadow Meld: +15 dodge until next attack!");
            }

        } else {
            var _final_dmg = combat_resolve_damage(
                _base_dmg,
                0,              // enemies deal physical damage by default
                player.armor,
                player.el_resist
            );
            // Vulnerable on the player adds flat damage taken (summed).
            _final_dmg += combat_status_total(player, "vulnerable");
            // Subtract flat damage reduction (Iron Skin), then equipment armor
            _final_dmg = max(0, _final_dmg - player.damage_reduction);
            _final_dmg = max(1, _final_dmg - player.equip_armor);
            if (variable_struct_exists(player, "derived") && player.derived.phys_dmg_reduction > 0) {
                _final_dmg = max(1, ceil(_final_dmg * (1.0 - (player.derived.phys_dmg_reduction / 100.0))));
            }
            // Warding boon: flat % incoming-damage reduction.
            if (boon_active("warding")) _final_dmg = max(1, round(_final_dmg * boon_incoming_mult()));
            // Soul Shield absorbs damage before it reaches HP.
            if (variable_struct_exists(player, "shield_hp") && player.shield_hp > 0 && _final_dmg > 0) {
                var _sa = min(player.shield_hp, _final_dmg);
                player.shield_hp -= _sa;
                _final_dmg -= _sa;
                array_push(combat_log, "Soul Shield absorbs " + string(_sa) + " damage.");
            }

            combat_apply_damage(player, _final_dmg);
            audio_play_sound(hurt, 1, false);
            // VFX: hit flash, popup, enemy attack slide, screen shake
            player.hit_flash   = 15;
            screen_shake_timer = 12;
            var _ea_slot = 0;
            for (var _asi = 0; _asi < array_length(combat_state.combatants); _asi++) {
                if (combat_state.combatants[_asi] == actor) break;
                if (!combat_state.combatants[_asi].is_player) _ea_slot++;
            }
            var _ea_src_x = 1080 + _ea_slot * (-80);
            var _ea_src_y = 155  + _ea_slot * 70;
            array_push(damage_popups, { value: _final_dmg, x: 220, y: 240, timer: 50, col: make_color_rgb(255, 80, 80) });
            attack_anim_timer     = 20;
            attack_anim_src_x     = _ea_src_x;
            attack_anim_src_y     = _ea_src_y;
            attack_anim_dst_x     = 290;
            attack_anim_dst_y     = 310;
            attack_anim_is_player = false;
            attack_anim_enemy_idx = _ea_slot;
            // Impact spark over the player where the blow lands (same one-shot VFX
            // system as outgoing hits; spr_fx_impact is a 64px top-left-origin burst).
            vfx_spr   = spr_fx_impact;
            vfx_x     = 200;
            vfx_y     = 300;
            vfx_timer = 18;
            array_push(combat_log,
                actor.name + " attacked for " + string(_final_dmg) + " damage!");

            // --- Bloodthorn Aura reflect ---
            if (player.bloodthorn_active) {
                combat_apply_damage(actor, player.bloodthorn_value);
                actor.hit_flash = max(actor.hit_flash, 10);
                array_push(damage_popups, {
                    value: player.bloodthorn_value,
                    x: _ea_src_x, y: _ea_src_y - 50,
                    timer: 45, col: make_color_rgb(200, 80, 50)
                });
                array_push(combat_log,
                    "Bloodthorn Aura: " + actor.name + " takes "
                    + string(player.bloodthorn_value) + " reflected damage!");
                player.bloodthorn_duration--;
                if (player.bloodthorn_duration <= 0) {
                    player.bloodthorn_active = false;
                    array_push(combat_log, "Bloodthorn Aura fades.");
                }
            }

            // --- Blood generation on taking a hit (Bloodwarden) ---
            if (player.class_id == 1 && variable_struct_exists(player, "blood")) {
                player.blood = min(player.blood_max, player.blood + 1);
                array_push(combat_log, "Blood generated: " + string(player.blood) + "/" + string(player.blood_max));
            }

            if (player.HP <= 0) {
                if (!combat_try_last_stand(player, combat_log)) {
                    player.is_defeated = true;
                    // Victory check at the top of the next frame will catch this
                }
            }
        }

        // --- Double-strike mechanic ---
        // Fire a second independent hit roll using mechanic_value as the flat
        // per-hit damage (separate from the telegraphed damage path).
        if (actor.mechanic_type == "double_strike") {
            var _hit2 = combat_roll_hit({ DEX: 3 }, _enemy_acc, player.dodge, false);

            if (!_hit2) {
                array_push(combat_log, actor.name + "'s second strike missed!");
            } else {
                var _final_dmg2 = combat_resolve_damage(
                    actor.mechanic_value,
                    0,
                    player.armor,
                    player.el_resist
                );
                _final_dmg2 += combat_status_total(player, "vulnerable");
                _final_dmg2 = max(1, _final_dmg2 - player.equip_armor);
                if (boon_active("warding")) _final_dmg2 = max(1, round(_final_dmg2 * boon_incoming_mult()));
                // Soul Shield absorbs the second strike too.
                if (variable_struct_exists(player, "shield_hp") && player.shield_hp > 0 && _final_dmg2 > 0) {
                    var _sa2 = min(player.shield_hp, _final_dmg2);
                    player.shield_hp -= _sa2;
                    _final_dmg2 -= _sa2;
                    array_push(combat_log, "Soul Shield absorbs " + string(_sa2) + " damage.");
                }

                combat_apply_damage(player, _final_dmg2);
                audio_play_sound(hurt, 1, false);
                player.hit_flash   = max(player.hit_flash, 12);
                screen_shake_timer = max(screen_shake_timer, 8);
                array_push(damage_popups, { value: _final_dmg2, x: 185, y: 225, timer: 50, col: make_color_rgb(255, 80, 80) });
                array_push(combat_log,
                    actor.name + " strikes again for " + string(_final_dmg2) + " damage!");

                // --- Bloodthorn Aura reflect (double strike) ---
                if (player.bloodthorn_active) {
                    combat_apply_damage(actor, player.bloodthorn_value);
                    actor.hit_flash = max(actor.hit_flash, 8);
                    array_push(damage_popups, {
                        value: player.bloodthorn_value,
                        x: _ea_src_x, y: _ea_src_y - 50,
                        timer: 45, col: make_color_rgb(200, 80, 50)
                    });
                    array_push(combat_log,
                        "Bloodthorn Aura: " + actor.name + " takes "
                        + string(player.bloodthorn_value) + " reflected damage!");
                    player.bloodthorn_duration--;
                    if (player.bloodthorn_duration <= 0) {
                        player.bloodthorn_active = false;
                        array_push(combat_log, "Bloodthorn Aura fades.");
                    }
                }

                // --- Blood generation on taking a hit (Bloodwarden) ---
                if (player.class_id == 1 && variable_struct_exists(player, "blood")) {
                    player.blood = min(player.blood_max, player.blood + 1);
                    array_push(combat_log, "Blood generated: " + string(player.blood) + "/" + string(player.blood_max));
                }

                if (player.HP <= 0) {
                    if (!combat_try_last_stand(player, combat_log)) {
                        player.is_defeated = true;
                    }
                }
            }
        }

        // --- Advance turn ---
        combat_next_turn(combat_state);
        player_turn      = combat_state.active.is_player;
        if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
        if (player_turn) {
            enemy_turn_timer = 0;
        } else {
            enemy_turn_timer = enemy_turn_delay;
        }
    }
}
