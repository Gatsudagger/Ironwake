// =============================================================================
// obj_combat_controller — Step event
// Runs every frame. Drives the full turn-based combat loop:
//   player input → ability cast → enemy AI → advance turn → check victory.
// =============================================================================


// Freeze all combat input when any overlay is open (menu, stash, shop,
// level-up alloc). Level alloc input is handled in obj_game_controller Step
// so it keeps working even while this Step is frozen.
if (ui_input_blocked()) exit;


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
    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter) || keyboard_check_pressed(ord("R"))) {
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
    // Boss floor-completion XP bonus (granted once per combat on boss kill)
    if (!combat_over && !boss_bonus_granted
        && variable_global_exists("next_enemy_type") && global.next_enemy_type == "boss") {
        boss_bonus_granted = true;
        var _boss_xp_gained = grant_xp(25);
        array_push(combat_log, "Floor completion: +25 XP!");
        if (_boss_xp_gained > 0) {
            array_push(combat_log, "LEVEL UP! Now level " + string(global.run_level) + ".");
        }
        // Malgrath kill (floor 3 boss) unlocks all three class traits
        if (variable_global_exists("current_floor") && global.current_floor >= 3
            && variable_global_exists("traits_unlocked")
            && instance_exists(obj_game_controller)) {
            var _gc_boss = instance_find(obj_game_controller, 0);
            var _any_new = false;
            if (!global.traits_unlocked.soul_siphon)     { global.traits_unlocked.soul_siphon     = true; _any_new = true; }
            if (!global.traits_unlocked.crimson_reserve) { global.traits_unlocked.crimson_reserve = true; _any_new = true; }
            if (!global.traits_unlocked.phantom_step)    { global.traits_unlocked.phantom_step    = true; _any_new = true; }
            if (_any_new) {
                _gc_boss.trait_notif_msg   = "TRAIT UNLOCKED: Class Traits now available!";
                _gc_boss.trait_notif_timer = 180;
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
        array_push(combat_log, "Victory! All enemies defeated.");
    }
    exit;
}

if (_result == -1) {
    combat_over   = true;
    combat_result = -1;
    array_push(combat_log, "Defeated...");
    exit;
}


// -----------------------------------------------------------------------------
// 3. PLAYER TURN
// -----------------------------------------------------------------------------
if (player_turn) {

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

    // --- Cast attempt (Space or Enter) ---
    if (keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_enter)) {

        var ab = player.abilities[selected_ability];

        // Already used this ability this turn?
        var _already_used = false;
        for (var _ui = 0; _ui < array_length(abilities_used_this_turn); _ui++) {
            if (abilities_used_this_turn[_ui] == ab.name) { _already_used = true; break; }
        }

        if (_already_used) {
            array_push(combat_log, ab.name + " already used this turn.");

        // Resource gate — must have enough energy and secondary resource
        } else if (!ability_can_cast(ab, player)) {
            array_push(combat_log, "Not enough resources.");

        } else {
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

            if (!ab.self_targeted) {
                // --- Find the selected_target-th living enemy ---
                var target = undefined;
                var _living_idx = 0;
                for (var _ti = 0; _ti < array_length(combat_state.combatants); _ti++) {
                    var _tc = combat_state.combatants[_ti];
                    if (!_tc.is_player && !_tc.is_defeated) {
                        if (_living_idx == selected_target) {
                            target = _tc;
                            break;
                        }
                        _living_idx++;
                    }
                }
                // Safety fallback — selected_target may be out of range after a kill;
                // reset to 0 and pick the first living enemy so the cast never fails silently.
                if (target == undefined) {
                    selected_target = 0;
                    for (var _ti = 0; _ti < array_length(combat_state.combatants); _ti++) {
                        var _tc = combat_state.combatants[_ti];
                        if (!_tc.is_player && !_tc.is_defeated) {
                            target = _tc;
                            break;
                        }
                    }
                }

                if (target == undefined) {
                    // All enemies already down — victory check will fire next frame
                    array_push(combat_log, ab.name + " found no target.");

                } else {
                    // --- Hit roll ---
                    var _hit = combat_roll_hit(
                        player.stats,
                        ab.base_acc,
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
                            _crit_result = combat_roll_crit(
                                player.stats,
                                ab.base_crit,
                                ab.crit_type
                            );
                        }

                        // --- Damage calculation ---
                        var _dmg = ab.base_damage;
                        if (_crit_result.critted) {
                            _dmg = round(_dmg * _crit_result.multiplier);
                        }

                        var _final_dmg = combat_resolve_damage(
                            _dmg,
                            ab.damage_type,
                            target.armor,
                            target.el_resist
                        );

                        combat_apply_damage(target, _final_dmg);

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

                        // VFX impact sprite keyed to damage type
                        var _ab_dtype = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
                        var _vfx_spr_list = [spr_vfx_slash, spr_vfx_fire, spr_vfx_void];
                        vfx_spr   = (_ab_dtype >= 0 && _ab_dtype <= 2) ? _vfx_spr_list[_ab_dtype] : spr_vfx_arcane;
                        vfx_x     = _vfx_ex;
                        vfx_y     = _vfx_ey;
                        vfx_timer = 20;

                        // --- Hit log ---
                        var _log_entry = player.name + " used " + ab.name
                            + " for " + string(_final_dmg) + " damage";
                        if (_crit_result.critted) _log_entry += " (CRIT!)";
                        array_push(combat_log, _log_entry);

                        // --- On-hit heal (e.g. Void Drain) ---
                        if (ab.effect_type == "heal") {
                            var _heal = min(player.max_HP - player.HP, ab.effect_value);
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

                        // --- Defeat check on target ---
                        if (target.HP <= 0) {
                            target.is_defeated = true;
                            array_push(combat_log, target.name + " defeated!");
                            // --- Gold drop ---
                            var _gold_drop = irandom(target.gold_max - target.gold_min) + target.gold_min;
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
                            // --- XP grant ---
                            var _xp_base;
                            if (variable_struct_exists(target, "xp_value")) {
                                _xp_base = target.xp_value;
                            } else {
                                _xp_base = 10;
                            }
                            var _xp_floor;
                            if (variable_global_exists("current_floor")) {
                                _xp_floor = global.current_floor;
                            } else {
                                _xp_floor = 1;
                            }
                            var _xp_scale;
                            if (_xp_floor == 2) {
                                _xp_scale = 1.25;
                            } else if (_xp_floor >= 3) {
                                _xp_scale = 1.5;
                            } else {
                                _xp_scale = 1.0;
                            }
                            var _xp_amt   = round(_xp_base * _xp_scale);
                            var _xp_lvls  = grant_xp(_xp_amt);
                            array_push(combat_log, "Gained " + string(_xp_amt) + " XP!");
                            if (_xp_lvls > 0) {
                                array_push(combat_log, "LEVEL UP! Now level " + string(global.run_level) + ".");
                            }
                            // --- Kill soul generation (Arcanist) ---
                            if (player.class_id == 0 && variable_struct_exists(player, "souls")) {
                                player.souls = min(player.souls_max, player.souls + 2);
                                array_push(combat_log, "Soul Harvest: gained 2 Souls.");
                            }
                            // --- Soul Siphon on kill (Arcanist only) ---
                            if (player.class_id == 0 && variable_struct_exists(player, "souls")
                                && trait_active("Soul Siphon")) {
                                player.souls = min(player.souls_max, player.souls + 1);
                                array_push(combat_log, "Soul Siphon: +1 Soul.");
                            }
                            // --- Heartstone Aegis: heal 5 HP on enemy death ---
                            if (variable_struct_exists(player, "heartstone_aegis") && player.heartstone_aegis) {
                                var _aegis_heal = min(5, player.max_HP - player.HP);
                                if (_aegis_heal > 0) {
                                    player.HP += _aegis_heal;
                                    array_push(combat_log, "Heartstone Aegis: +" + string(_aegis_heal) + " HP.");
                                }
                            }
                        }

                        // --- Apply status effect to target ---
                        // Only applied on a living target so DoTs don't stack on corpses.
                        if (!target.is_defeated) {
                            if (ab.effect_type == "dot" || ab.effect_type == "debuff") {
                                var _status = {
                                    name:         ab.name,
                                    effect_type:  ab.effect_type,
                                    effect_value: ab.effect_value,
                                    duration:     ab.effect_duration,
                                    source:       "player"
                                };
                                array_push(target.status_effects, _status);
                                array_push(combat_log, ab.name + " applied to " + target.name + "!");
                            }
                        }
                    }
                }

            } else {
                // --- Self-targeted ability ---
                array_push(combat_log, player.name + " used " + ab.name + ".");

                if (ab.effect_type == "heal") {
                    var _heal = min(player.max_HP - player.HP, ab.effect_value);
                    player.HP += _heal;
                    if (_heal > 0) {
                        array_push(damage_popups, { value: _heal, x: 220, y: 240, timer: 45, col: c_lime });
                    }
                    array_push(combat_log, player.name + " restored " + string(_heal) + " HP.");
                }

                // --- Iron Skin: set flat damage reduction for N turns ---
                if (ab.name == "Iron Skin") {
                    player.damage_reduction   = ab.effect_value;
                    player.iron_skin_duration = ab.effect_duration;
                    array_push(combat_log,
                        "Hero activates Iron Skin — incoming damage reduced by "
                        + string(ab.effect_value) + " for " + string(ab.effect_duration) + " turns.");
                }

                // --- Blink: become untargetable for 1 turn ---
                if (ab.name == "Blink") {
                    player.is_untargetable    = true;
                    player.untargetable_turns = 1;
                    array_push(combat_log, "Hero blinks away — untargetable for 1 turn!");
                }

                // --- Shadow Step: dodge the next single-target attack ---
                if (ab.name == "Shadow Step") {
                    player.shadow_step_active = true;
                    array_push(combat_log, "Hero prepares to dodge the next attack!");
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
        if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; }
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
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; }
            if (player_turn) {
                enemy_turn_timer = 0;
            } else {
                enemy_turn_timer = enemy_turn_delay;
            }
            exit;
        }

        // --- Tick status effects on this enemy ---
        // Runs before the enemy attacks so DoT can kill the enemy before they act.
        var _se_count = array_length(actor.status_effects);
        var _se_keep  = [];
        for (var _si = 0; _si < _se_count; _si++) {
            var _se = actor.status_effects[_si];

            if (_se.effect_type == "dot") {
                // DoT bypasses armor — poison and bleed are internal damage
                var _dot_dmg = _se.effect_value;
                combat_apply_damage(actor, _dot_dmg);
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
                array_push(damage_popups, { value: _dot_dmg, x: _dot_ex, y: _dot_ey - 70, timer: 45, col: make_color_rgb(255, 140, 0) });
                array_push(combat_log,
                    actor.name + " takes " + string(_dot_dmg) + " " + _se.name + " damage!");
                if (actor.HP <= 0) {
                    actor.is_defeated = true;
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
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Check player untargetable (Blink) ---
        if (player.is_untargetable) {
            array_push(combat_log, actor.name + "'s attack passes through thin air!");
            player.untargetable_turns--;
            if (player.untargetable_turns <= 0) {
                player.is_untargetable = false;
                array_push(combat_log, "Hero reappears!");
            }
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Check shadow step (dodge next single-target attack) ---
        if (player.shadow_step_active) {
            array_push(combat_log, actor.name + "'s attack is dodged!");
            player.shadow_step_active = false;
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Check Phantom Step (auto-miss the very first enemy attack each combat) ---
        if (combat_check_phantom_step(player, combat_log)) {
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Determine base damage for this turn (handles telegraph spike) ---
        var _base_dmg = enemy_get_attack_damage(actor, combat_state.round);

        // --- Primary attack hit roll ---
        // Enemies don't have a full stats struct; pass a minimal anonymous struct
        // with only the DEX field that combat_roll_hit() needs.
        var _hit = combat_roll_hit({ DEX: 3 }, actor.acc, player.dodge, false);

        if (!_hit) {
            array_push(combat_log, actor.name + " attacked but missed!");

        } else {
            var _final_dmg = combat_resolve_damage(
                _base_dmg,
                0,              // enemies deal physical damage by default
                player.armor,
                player.el_resist
            );
            // Subtract flat damage reduction (Iron Skin), then equipment armor
            _final_dmg = max(0, _final_dmg - player.damage_reduction);
            _final_dmg = max(1, _final_dmg - player.equip_armor);

            combat_apply_damage(player, _final_dmg);
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
            array_push(combat_log,
                actor.name + " attacked for " + string(_final_dmg) + " damage!");

            // --- Blood generation on taking a hit (Bloodwarden) ---
            if (player.class_id == 1 && variable_struct_exists(player, "blood")) {
                player.blood = min(player.blood_max, player.blood + 1);
                array_push(combat_log, "Blood generated: " + string(player.blood) + "/" + string(player.blood_max));
            }

            if (player.HP <= 0) {
                player.is_defeated = true;
                // Victory check at the top of the next frame will catch this
            }
        }

        // --- Double-strike mechanic ---
        // Fire a second independent hit roll using mechanic_value as the flat
        // per-hit damage (separate from the telegraphed damage path).
        if (actor.mechanic_type == "double_strike") {
            var _hit2 = combat_roll_hit({ DEX: 3 }, actor.acc, player.dodge, false);

            if (!_hit2) {
                array_push(combat_log, actor.name + "'s second strike missed!");
            } else {
                var _final_dmg2 = combat_resolve_damage(
                    actor.mechanic_value,
                    0,
                    player.armor,
                    player.el_resist
                );
                _final_dmg2 = max(1, _final_dmg2 - player.equip_armor);

                combat_apply_damage(player, _final_dmg2);
                player.hit_flash   = max(player.hit_flash, 12);
                screen_shake_timer = max(screen_shake_timer, 8);
                array_push(damage_popups, { value: _final_dmg2, x: 185, y: 225, timer: 50, col: make_color_rgb(255, 80, 80) });
                array_push(combat_log,
                    actor.name + " strikes again for " + string(_final_dmg2) + " damage!");

                // --- Blood generation on taking a hit (Bloodwarden) ---
                if (player.class_id == 1 && variable_struct_exists(player, "blood")) {
                    player.blood = min(player.blood_max, player.blood + 1);
                    array_push(combat_log, "Blood generated: " + string(player.blood) + "/" + string(player.blood_max));
                }

                if (player.HP <= 0) {
                    player.is_defeated = true;
                }
            }
        }

        // --- Advance turn ---
        combat_next_turn(combat_state);
        player_turn      = combat_state.active.is_player;
        if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; }
        if (player_turn) {
            enemy_turn_timer = 0;
        } else {
            enemy_turn_timer = enemy_turn_delay;
        }
    }
}
