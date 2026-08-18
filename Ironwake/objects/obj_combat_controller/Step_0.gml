// =============================================================================
// obj_combat_controller - Step event
// Runs every frame. Drives the full turn-based combat loop:
//   player input -> ability cast -> enemy AI -> advance turn -> check victory.
// =============================================================================


// Stash is hub-only - no stash access during combat.

// Family immunities (M-locked 08-17): strip any status an enemy is immune to the
// frame it lands - IMMUNE popup + log. One central hook (see combat_immune_sweep).
if (!combat_over && is_struct(combat_state)) combat_immune_sweep(combat_state, combat_log, damage_popups);

// IRONMAN resume anti-cheese watcher (SYSTEMS_RUN_RESUME.md): mirror the LIVE
// player HP/resources into the checkpoint whenever they change (1s throttle),
// so killing the app mid-fight resumes the re-fight at the HP you actually had
// while the enemies reset to full - a rage-quit is always a net loss. Runs
// before every early exit below; suspended once the fight is decided
// (victory keeps the pre-fight checkpoint, defeat deleted it).
if (!combat_over && is_struct(player)) {
    if (run_ckpt_cooldown > 0) run_ckpt_cooldown--;
    var _ck_sig = string(player.HP)
        + "|" + (variable_struct_exists(player, "souls")       ? string(player.souls)       : "")
        + "|" + (variable_struct_exists(player, "blood")       ? string(player.blood)       : "")
        + "|" + (variable_struct_exists(player, "preparation") ? string(player.preparation) : "");
    if (_ck_sig != run_ckpt_sig && run_ckpt_cooldown <= 0) {
        run_ckpt_sig      = _ck_sig;
        run_ckpt_cooldown = 60;
        // Patch-only (NOT a full write): a full write here would checkpoint the
        // gold/XP/items already earned this fight against a still-uncleared
        // room, and the resume's re-fight would earn them all AGAIN.
        run_checkpoint_update_hp(player);
    }
}

// 2.5D v3 lever (M 08-13): F7 flips the two-plane stage set live and persists
// (its own ini key so the retired v2 value can never resurrect the warp).
if (keyboard_check_pressed(vk_f7)) {
    global.combat_25d = !combat_25d();
    ini_open("settings.ini");
    ini_write_real("ui", "combat_25d_v3", global.combat_25d ? 1 : 0);
    ini_close();
    array_push(combat_log, "Arena view: " + (global.combat_25d ? "2.5D stage (v3)" : "flat (classic)") + ".");
}

// ===== DELIVERY MUTATOR QUEUE (M 08-11, SYSTEMS_MUTATORS.md) =====
// Delayed sub-hits: BOUNCE arcs to a random other enemy on a real traveling
// bolt (v2, 08-11); ECHO repeats on its target at the player's ACTUAL next
// turn (v2 - was a flat 80-frame delay). Ticks every frame (even during enemy
// phases) so a hop can never be swallowed by a turn change.
if (!combat_over && array_length(mutator_queue) > 0) {
    for (var _mq = array_length(mutator_queue) - 1; _mq >= 0; _mq--) {
        var _mm = mutator_queue[_mq];
        // ECHO waits for the next player turn (an enemy phase must pass first);
        // the countdown doubles as a fallback so a stunned-out enemy phase can
        // never leave the toll hanging forever.
        var _mm_ready;
        if (variable_struct_exists(_mm, "wait_turn") && _mm.wait_turn) {
            if (!player_turn) _mm.seen_enemy = true;
            _mm.t--;
            _mm_ready = (_mm.seen_enemy && player_turn) || (_mm.t <= 0);
        } else {
            _mm.t--;
            _mm_ready = (_mm.t <= 0);
        }
        if (!_mm_ready) continue;
        array_delete(mutator_queue, _mq, 1);

        // BOUNCE ARRIVAL ("hit"): the bolt has landed - apply the locked hit.
        if (_mm.kind == "hit") {
            var _mhv = _mm.victim;
            if (_mhv == undefined || _mhv.is_defeated) continue;
            var _mhd = combat_resolve_damage(max(1, round(_mm.base * _mm.pct / 100)),
                _mm.dtype, _mhv.armor, _mhv.el_resist);
            if (_mhd < 1) _mhd = 1;
            combat_apply_damage(_mhv, _mhd);
            _mhv.hit_flash = max(_mhv.hit_flash, 10);
            var _mh_a = combat_enemy_anchor(_mhv, _mm.slot);   // 2.5D: over the creature, not the flat grid
            array_push(damage_popups, { value: _mhd, x: _mh_a.x, y: _mh_a.y - 60,
                                        timer: 45, col: (_mm.school != "") ? school_color(_mm.school) : c_white });
            array_push(combat_log, _mm.name + " arcs on to " + _mhv.name + " for " + string(_mhd) + "!");
            if (_mhv.HP <= 0 && !_mhv.is_defeated) combat_on_enemy_defeated(_mhv, player, combat_log);
            // Multi-hop (Bouncing Bomb): the arc keeps going, its payload
            // decaying to this hop's landed damage.
            if (variable_struct_exists(_mm, "hops") && _mm.hops > 1 && !_mhv.is_defeated) {
                array_push(mutator_queue, { kind: "bounce", t: 8, from: _mhv, pct: _mm.pct,
                    base: _mhd, dtype: _mm.dtype, school: _mm.school, name: _mm.name, hops: _mm.hops - 1 });
            }
            continue;
        }

        // Pick the victim: bounce = random living enemy that ISN'T the source
        // hit's target; echo = the original target, or a random living enemy
        // if it already fell. Track the living-slot index for the popup spot.
        var _mv = undefined, _mv_slot = 0, _mf_slot = 0;
        var _mc_live = 0, _mc_pool = [], _mc_slots = [];
        for (var _mi = 0; _mi < array_length(combat_state.combatants); _mi++) {
            var _mc = combat_state.combatants[_mi];
            if (_mc.is_player || _mc.is_defeated) continue;
            if (_mc == _mm.from) _mf_slot = _mc_live;
            if (_mm.kind == "echo" && _mc == _mm.from) { _mv = _mc; _mv_slot = _mc_live; }
            if (_mm.kind == "bounce" && _mc != _mm.from) { array_push(_mc_pool, _mc); array_push(_mc_slots, _mc_live); }
            if (_mm.kind == "echo") { array_push(_mc_pool, _mc); array_push(_mc_slots, _mc_live); }
            _mc_live++;
        }
        if (_mv == undefined && array_length(_mc_pool) > 0) {
            var _mp = irandom(array_length(_mc_pool) - 1);
            _mv = _mc_pool[_mp]; _mv_slot = _mc_slots[_mp];
        }
        if (_mv == undefined) continue;   // nothing left standing to receive it

        if (_mm.kind == "bounce") {
            // v2: the arc is a REAL bolt between the hop's two enemies - damage
            // lands when it arrives (the "hit" entry above, timed to the flight).
            var _mb_sx = 1620 - _mf_slot * 120, _mb_sy = 233 + _mf_slot * 105 - 20;
            var _mb_tx = 1620 - _mv_slot * 120, _mb_ty = 233 + _mv_slot * 105 - 20;
            // 2.5D: arc between the two foes' stamped visual centres, not the
            // flat-row grid (M 08-13 projectile-targeting pass).
            if (combat_25d()) {
                if (variable_struct_exists(_mm.from, "last_ecx")) { _mb_sx = _mm.from.last_ecx; _mb_sy = _mm.from.last_ecy; }
                if (variable_struct_exists(_mv, "last_ecx"))      { _mb_tx = _mv.last_ecx;      _mb_ty = _mv.last_ecy; }
            }
            array_push(combat_projectiles, { spr: -1, school: _mm.school,
                impact_spr: spr_fx_impact, ticks: 12,
                sx: _mb_sx, sy: _mb_sy, tx: _mb_tx, ty: _mb_ty, bx: _mb_tx, by: _mb_ty,
                t: 0, dur: 14, delay: 0, tgt: _mv, shake: 4 });
            array_push(mutator_queue, { kind: "hit", t: 15, victim: _mv, slot: _mv_slot,
                base: _mm.base, pct: _mm.pct, dtype: _mm.dtype, school: _mm.school, name: _mm.name,
                hops: variable_struct_exists(_mm, "hops") ? _mm.hops : 1 });
            continue;
        }

        var _md = combat_resolve_damage(max(1, round(_mm.base * _mm.pct / 100)),
            _mm.dtype, _mv.armor, _mv.el_resist);
        if (_md < 1) _md = 1;
        combat_apply_damage(_mv, _md);
        _mv.hit_flash = max(_mv.hit_flash, 10);
        var _md_px = 1620 + _mv_slot * (-120), _md_py = 233 + _mv_slot * 105 - 60;
        if (combat_25d() && variable_struct_exists(_mv, "last_ecx")) { _md_px = _mv.last_ecx; _md_py = _mv.last_ecy - 90; }
        array_push(damage_popups, { value: _md, x: _md_px, y: _md_py,
                                    timer: 45, col: (_mm.school != "") ? school_color(_mm.school) : c_white });
        array_push(combat_log, _mm.name + " echoes on " + _mv.name + " for " + string(_md) + "!");
        if (_mv.HP <= 0 && !_mv.is_defeated) combat_on_enemy_defeated(_mv, player, combat_log);
    }
}

// Freeze all combat input when any overlay is open (menu, stash, shop,
// level-up alloc). Level alloc input is handled in obj_game_controller Step
// so it keeps working even while this Step is frozen.
if (ui_input_blocked()) exit;

// Pause / Esc menu - freeze combat while it (or its Settings sub-screen) is open.
// Esc opens it only when no combat sub-overlay owns Esc (loot screen, the [I]
// consumable quick-menu) and the fight is still live. See pause_menu_step (scr_stats).
if (pause_menu_step()) exit;
if (input_cancel() && !combat_over && !show_loot_screen && !consumable_quick_open && !ability_detail_open
    && !consumable_overflow_pending()) {   // Esc in the discard modal disarms, never opens pause
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
if (_lmx >= 30 && _lmx <= 1200 && _lmy >= 735 && _lmy <= 945) {
    var _log_vis = floor((210 - 24) / 29);   // matches panel height / line_h
    var _log_max = max(0, _log_len - _log_vis);
    if (mouse_wheel_up())   combat_log_scroll = min(_log_max, combat_log_scroll + 1);
    if (mouse_wheel_down()) combat_log_scroll = max(0, combat_log_scroll - 1);
}
// Touch (8d, punch item 9): drag the log panel to scroll it - one row per
// 29px (the log line height). Tap-in-place keeps the line-inspect popup.
if (input_device() == 2) {
    var _lg_dy = touch_drag_dy(30, 735, 1200, 945);
    if (_lg_dy != 0) {
        if (!variable_global_exists("log_drag_acc")) global.log_drag_acc = 0;
        global.log_drag_acc += _lg_dy;
        var _lg_vis = floor((210 - 24) / 29);
        var _lg_max = max(0, _log_len - _lg_vis);
        if (global.log_drag_acc >= 29)       { combat_log_scroll = min(_lg_max, combat_log_scroll + 1); global.log_drag_acc -= 29; }
        else if (global.log_drag_acc <= -29) { combat_log_scroll = max(0, combat_log_scroll - 1);       global.log_drag_acc += 29; }
    }
}


// -----------------------------------------------------------------------------
// 1. EARLY EXIT - combat already resolved
// -----------------------------------------------------------------------------
if (combat_over) exit;

// Vigil (Awakened Guardian splash): polled every live-combat frame so it catches any
// damage source the moment the player first drops below 40% HP. Fires at most once
// per combat (global.pet_vigil_used, reset in Create); no-op for everyone else.
combat_pet_vigil_check(player, combat_log, damage_popups);


// -----------------------------------------------------------------------------
// 1b. LOOT SCREEN - intercepts all input after combat while items are shown
// -----------------------------------------------------------------------------
if (show_loot_screen) {
    // Staggered reveal: one row every 8 frames with a tick; the best item's row
    // fires the haul's ONE rarity stinger as it lands (SOUND_ATMOSPHERE_SPEC.md
    // section 1). Rows beyond the visible window count as "revealed" with the
    // last visible one so the stinger can't be lost to scrolling.
    var _lr_count   = array_length(global.run_items_found) + array_length(loot_special_rows);
    var _lr_visible = min(8, _lr_count);
    if (loot_reveal_shown < _lr_visible) {
        if (loot_reveal_timer mod 8 == 0) {
            loot_reveal_shown++;
            play_sfx_var("snd_loot_reveal", -1);
            var _lr_best_vis = min(loot_best_row, _lr_visible - 1);
            if (!loot_sting_played && loot_reveal_shown - 1 >= _lr_best_vis) {
                loot_sting_played = true;
                audio_play_sound(loot_rarity_sound(loot_best_rarity), 1, false);
            }
        }
        loot_reveal_timer++;
        // Any key/click skips the stagger: reveal everything + fire the stinger.
        if (input_confirm() || input_confirm_alt() || input_cancel()
            || mouse_check_button_pressed(mb_left)) {
            loot_reveal_shown = _lr_visible;
            if (!loot_sting_played) {
                loot_sting_played = true;
                audio_play_sound(loot_rarity_sound(loot_best_rarity), 1, false);
            }
        }
        exit;   // input below (scroll/close) waits until the reveal finishes
    }
    if (nav_up())   loot_screen_scroll = max(0, loot_screen_scroll - 1);
    if (nav_down()) {
        var _max_scroll = max(0, array_length(global.run_items_found) + array_length(loot_special_rows) - 5);
        loot_screen_scroll = min(_max_scroll, loot_screen_scroll + 1);
    }
    // Fortune's Favor (POTENCY V2, Lucky Find T5): once per run, reroll the TOP
    // LISTED equipment drop. [V] or the chip at (1560,96)-(1870,168) - geometry
    // MUST match the Draw_64 chip. Scroll moves which item sits on top.
    var _ff_idx = clamp(loot_screen_scroll, 0, max(0, array_length(global.run_items_found) - 1));
    // Scrolled past the items onto a SPECIAL row -> nothing rerollable on top.
    var _ff_old = (array_length(global.run_items_found) > 0 && loot_screen_scroll < array_length(global.run_items_found))
        ? global.run_items_found[_ff_idx] : undefined;
    var _ff_ok  = trait_transcended("Lucky Find")
        && (!variable_global_exists("fortune_favor_used") || !global.fortune_favor_used)
        && is_struct(_ff_old) && variable_struct_exists(_ff_old, "rarity")
        && !(variable_struct_exists(_ff_old, "item_category") && _ff_old.item_category == "consumable");
    var _ff_tap = false;
    if (mouse_check_button_pressed(mb_left)) {
        var _ffmx = device_mouse_x_to_gui(0), _ffmy = device_mouse_y_to_gui(0);
        _ff_tap = (_ffmx >= 1560 && _ffmx < 1870 && _ffmy >= 96 && _ffmy < 168);
    }
    if (_ff_ok && (input_hotkey("V") || _ff_tap)) {
        global.fortune_favor_used = true;
        for (var _ffi = array_length(global.carried_items) - 1; _ffi >= 0; _ffi--) {
            if (global.carried_items[_ffi] == _ff_old) { array_delete(global.carried_items, _ffi, 1); break; }
        }
        var _ff_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
        var _ff_src = variable_global_exists("next_enemy_type") ? global.next_enemy_type : "standard";
        var _ff_new = drop_equipment(drop_weights(_ff_src, _ff_asc), true, curse_loot_tier_bonus_for(_ff_src));
        array_push(global.carried_items, _ff_new);
        discover_item(item_base_name(_ff_new), _ff_new.rarity);
        global.run_items_found[_ff_idx] = _ff_new;
        loot_item_sting(_ff_new);
        exit;   // consume this press - never fall through to the close handlers
    }
    if (input_confirm() || input_confirm_alt() || input_hotkey("R")
        || (mouse_check_button_pressed(mb_left) && device_mouse_y_to_gui(0) >= 960 && !_ff_tap)) {
        show_loot_screen = false;
        loot_special_rows = [];   // consumed with the haul so the screen can't re-arm
        // Clear run_items_found so the loot screen cannot re-trigger, then let the
        // victory path below finish combat NEXT frame - it resolves any pack-full
        // consumable-overflow discard first. Setting combat_over here skipped that
        // modal; on the FINAL boss there is no floor screen after to catch it, so
        // the queued item was silently lost (M 07-08).
        global.run_items_found = [];
    }
    exit;
}


// -----------------------------------------------------------------------------
// 2. VICTORY / DEFEAT CHECK
// Evaluated at the top of every frame so a kill on the previous frame is
// caught immediately at the start of the next, before any new input is read.
// -----------------------------------------------------------------------------
// (Thickened Vitae's per-frame max-HP sync REMOVED 08-13 - the node is now
// Clotted Armor, read at combat_mitigate_player. fx id unchanged: "blood_hp".)

var _result = combat_check_victory(combat_state);

// -----------------------------------------------------------------------------
// DUEL MERCY (DESIGN_DUELIST_CHALLENGE.md): the Duelist's blow stopped at 1 HP
// (combat_try_last_stand). Close the fight as result 2 - a loss that is NEVER a
// death - and restore the player to the HP they entered the room with. The exit
// each frame freezes the fight under the result overlay; duel_active stays true
// until the Draw-side dismiss returns to the floor.
// -----------------------------------------------------------------------------
if (global.duel_active && variable_global_exists("duel_mercy_fired") && global.duel_mercy_fired) {
    if (!combat_over) {
        combat_over   = true;
        combat_result = 2;
        player.HP     = clamp(global.duel_entry_hp, 1, player.max_HP);
        array_push(combat_log, "He binds your wounds himself, unhurried.");
        array_push(combat_log, "\"Keep the arm. Come back when it's faster.\"");
        global.duelist_encounters += 1;   // the ledger remembers every crossing
        save_game();                      // meta-persistent - bank it now
        audio_play_sound(snd_sting_floor, 1, false);
    }
    exit;
}

if (_result == 1) {
    // Hold briefly on the killing blow so the final hit's damage number and the combat
    // log are readable before the victory transition begins. (Task 2)
    if (!combat_over && victory_pause_timer < victory_pause_frames) {
        victory_pause_timer++;
        exit;
    }
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
            audio_play_sound(snd_sting_levelup, 1, false);
            array_push(combat_log, "LEVEL UP! Now level " + string(global.run_level) + ".");
        }
        // Traits no longer auto-unlock on boss kills - they are bought from Vex
        // (Traits tab) for gold + a rarity-matched item. See SYSTEMS_VEX_REWORK.md.
        if (variable_global_exists("total_boss_kills")) global.total_boss_kills++;

        // Battle Hardened: boss kill grants +3 permanent max HP (max +15 total).
        // POTENCY V2: +3 cap per rank (15 -> 27); TRANSCEND "Unbreakable" removes
        // the cap entirely.
        if (trait_active("Battle Hardened") && variable_global_exists("perm_hp_battle_hardened")) {
            var _bh_cap = trait_transcended("Battle Hardened") ? 999999 : (15 + 3 * trait_potency_r14("Battle Hardened"));
            if (global.perm_hp_battle_hardened < _bh_cap) {
                global.perm_hp_battle_hardened = min(_bh_cap, global.perm_hp_battle_hardened + 3);
                if (instance_exists(obj_game_controller)) {
                    var _gc_bh = instance_find(obj_game_controller, 0);
                    _gc_bh.trait_notif_msg   = "Battle Hardened: permanent +3 max HP!";
                    _gc_bh.trait_notif_timer = 120;
                }
            }
        }
    }
    // Slagpearl (magma_leech signature move, 08-05 pillar D): every combat victory
    // the leech sweats out a cooling slagpearl - +8 gold. Once per victory via the
    // per-combat player struct (this block re-runs during the victory pause);
    // benched/starving companions pay nothing (fit-to-act gate), duels sit out.
    if (pet_active_sig_move("slagpearl") && !variable_struct_exists(player, "sig_slag_done")) {
        player.sig_slag_done = true;
        add_gold(8);
        array_push(combat_log, "[Companion] " + pet_active().name + " sweats out a SLAGPEARL (+8g).");
    }
    // Vespers (chapel_bat innate, 08-06): clearing a combat room heals N HP.
    // Same once-per-victory flag idiom as the slagpearl above (this block
    // re-runs during the victory pause).
    if (pet_active_innate("room_heal") > 0 && !variable_struct_exists(player, "innate_vespers_done")) {
        player.innate_vespers_done = true;
        var _vp_amt = min(pet_active_innate("room_heal"), player.max_HP - player.HP);
        if (_vp_amt > 0) {
            player.HP += _vp_amt;
            array_push(combat_log, "[Companion] " + pet_active().name + "'s VESPERS settle over you (+"
                + string(_vp_amt) + " HP).");
        }
    }
    // Board challenge requests (BOARD_REQUESTS_SPEC.md §6) - scored once per victory.
    // Swift uses the threshold-tick trick: victory on round n ticks every T >= n so a
    // def with obj_param T completes exactly when n <= T.
    if (!combat_over && !board_ticks_granted) {
        board_ticks_granted = true;
        if (!combat_state.player_took_damage) {
            quest_tick("flawless_fight", "", 1);
            ach_unlock("ACH_NO_DAMAGE");   // achievement hook (08-05 wiring): flawless win
        }
        if (!combat_state.used_consumable)    quest_tick("clean_fight", "", 1);
        if (variable_global_exists("next_enemy_type") && global.next_enemy_type == "boss") {
            for (var _bst = clamp(combat_state.round, 1, 12); _bst <= 12; _bst++) {
                quest_tick("boss_swift", string(_bst), 1);
            }
        }
    }
    // DUEL VICTORY GRADING (DESIGN_DUELIST_CHALLENGE.md): fired once, on the
    // victory frame, BEFORE the loot-screen check below so the prize item lists
    // with the haul. GOLD (<= par): a Duelist Token (cap 3; post-arc pays 25
    // dust instead) + an item at elite weights +1 tier. SILVER (<= par+2):
    // elite-weighted item + 25 dust. BRONZE (any win): 15 dust + a 50g purse.
    if (!combat_over && global.duel_active && !duel_rewards_granted) {
        duel_rewards_granted = true;
        global.duelist_encounters += 1;   // he remembers this one bitterly
        // DUELING RELICS (M 08-11, #23): total-WINS ladder at 1/3/5 - any grade
        // counts (the token ARTS ladder below stays GOLD-only).
        if (!variable_global_exists("duelist_wins")) global.duelist_wins = 0;
        global.duelist_wins += 1;
        var _dr_relic = duelist_relic_for_win(global.duelist_wins);
        if (_dr_relic != undefined) {
            // 08-18 (M: "the item I got from the duelist was not showing in my inventory
            // until I was back in the hub"): relics land in the PACK like every other prize.
            array_push(global.carried_items, _dr_relic);
            array_push(global.run_items_found, _dr_relic);
            discover_item(item_base_name(_dr_relic), _dr_relic.rarity);
            array_push(combat_log, "DUELING RELIC: he surrenders the " + _dr_relic.name
                + " - it is in your pack. (" + string(global.duelist_wins) + " duels won)");
        }
        duel_grade_round = combat_state.round;
        var _dg_par = variable_global_exists("duel_par") ? global.duel_par : duel_turn_par();
        var _dg_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
        if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
        if (duel_grade_round <= _dg_par) {
            duel_grade = "GOLD";
            if (global.duelist_tokens < 3) {
                global.duelist_tokens += 1;
                array_push(combat_log, "He presses a DUELIST TOKEN into your hand (" + string(global.duelist_tokens) + "/3). Duelist Arts await at Vex.");
                // The token ladder unlocks land immediately; Vex's DUELIST ARTS
                // panel is where the full ladder reads out.
                if (global.duelist_tokens == 1) {
                    array_push(combat_log, "DUELIST ARTS: MEASURED RIPOSTE learned - find it in your loadout's general pool.");
                }
                if (global.duelist_tokens == 2) {
                    if (variable_global_exists("traits_unlocked")) global.traits_unlocked[$ "duelist_poise"] = true;
                    array_push(combat_log, "DUELIST ARTS: DUELIST'S POISE learned - a new trait waits in your loadout.");
                }
                if (global.duelist_tokens == 3) {
                    var _dg_blade = duelist_make_ashen_blade();
                    array_push(global.carried_items, _dg_blade);   // 08-18: pack, not stash (M)
                    array_push(global.run_items_found, _dg_blade);
                    discover_item(item_base_name(_dg_blade), _dg_blade.rarity);
                    array_push(combat_log, "DUELIST ARTS: he unbuckles THE ASHEN BLADE itself and hands it over - it is in your pack.");
                }
            } else {
                global.rune_dust += 25;
                array_push(combat_log, "The arc is complete - he pays in dust instead (+25).");
            }
            var _dg_item = drop_equipment(drop_weights("elite", _dg_asc), true, 1);
            array_push(global.run_items_found, _dg_item);
            array_push(global.carried_items, _dg_item);
            discover_item(item_base_name(_dg_item), _dg_item.rarity);
            array_push(combat_log, "\"...So the stories were short by half. Take it. It was never mine to keep.\"");
            array_push(combat_log, "Prize: " + _dg_item.name + " [" + item_rarity_name(_dg_item.rarity) + "]");
        } else if (duel_grade_round <= _dg_par + 2) {
            duel_grade = "SILVER";
            global.rune_dust += 25;
            var _dg_item2 = drop_equipment(drop_weights("elite", _dg_asc), true, 0);
            array_push(global.run_items_found, _dg_item2);
            array_push(global.carried_items, _dg_item2);
            discover_item(item_base_name(_dg_item2), _dg_item2.rarity);
            array_push(combat_log, "\"Close. Two bells late, but close.\"  (+" + _dg_item2.name + ", +25 dust)");
        } else {
            duel_grade = "BRONZE";
            global.rune_dust += 15;
            add_gold(50);
            array_push(combat_log, "\"You won. Slowly.\"  (+50g, +15 dust)");
        }
        save_game();   // tokens/ledger are meta-persistent - bank them at the victory frame
    }
    // Genie Lamp: ~1.5% drop from ELITE and BOSS kills only (design 2026-07-04).
    // A free mid-run escape - rub it on the floor map [G] to extract with all loot.
    if (!combat_over && !genie_lamp_rolled && variable_global_exists("next_enemy_type")
        && (global.next_enemy_type == "boss" || global.next_enemy_type == "elite")) {
        genie_lamp_rolled = true;
        if (irandom(999) < 15) {
            consumable_award(create_consumable("Genie Lamp", "escape_lamp", 0,
                "Rub it on the floor map [G]: escape to camp with everything you found", 500));
            array_push(combat_log, "A tarnished GENIE LAMP tumbles from the remains! (Floor map: [G] to use)");
        }
    }
    // BOSS SPECTACLE DROPS (M 07-28): the egg / signature-trinket / banshee
    // rolls used to run at the R-dismiss in Draw_64 - AFTER the loot screen -
    // so they never listed with the haul. Rolled HERE once instead, on the same
    // deterministic stream (loot_room_seed; SYSTEMS_RUN_RESUME.md - a re-fight
    // after a crash still cannot re-roll them), and pushed as SPECIAL rows the
    // loot screen appends after the item rows.
    if (!combat_over && !boss_drops_rolled
        && variable_global_exists("next_enemy_type") && global.next_enemy_type == "boss"
        && variable_global_exists("just_cleared_boss") && global.just_cleared_boss) {
        boss_drops_rolled = true;
        // Boss-Blooded quirk (08-01, pillar C): the carried creature stood with
        // you at this boss's FIRST fall (its signature kin not yet in the
        // once-per-save ledger). No RNG - checked BEFORE the egg roll below can
        // mark that ledger.
        var _bb_pet = pet_active();
        if (_bb_pet != undefined && !_bb_pet.is_egg) {
            var _bb_sig = pet_boss_signature_species(
                variable_global_exists("selected_dungeon") ? global.selected_dungeon : "",
                variable_global_exists("current_floor")    ? global.current_floor    : 1);
            if (_bb_sig != "" && (!variable_global_exists("pet_sig_history")
                || !is_struct(global.pet_sig_history)
                || !variable_struct_exists(global.pet_sig_history, _bb_sig))) {
                var _bb_msg = pet_quirk_add(_bb_pet, "boss_blooded", "", "");   // no story line (M 08-18)
                if (_bb_msg != "") array_push(combat_log, "[Companion] " + _bb_msg);
            }
        }
        var _bsr_seed = random_get_seed();
        random_set_seed(loot_room_seed(0, 2));
        // Phase 2 pets: rare boss-egg drop (odds scale with Awakening). Lands in
        // Bairc's stable; the hub notice on return stays as a second reminder.
        var _bsr_egg = pet_try_boss_egg(variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
        if (_bsr_egg != undefined) {
            var _bsr_lbl = _bsr_egg.is_egg
                ? ("Mysterious " + (pet_egg_label(_bsr_egg) != "" ? pet_egg_label(_bsr_egg) : "Egg"))
                : ("A living " + _bsr_egg.name);
            array_push(combat_log, "Among the remains: " + _bsr_lbl + "! Bairc can raise it.");
            global.pet_find_notice = _bsr_egg.is_egg
                ? ("You recovered a " + (pet_egg_label(_bsr_egg) != "" ? pet_egg_label(_bsr_egg) : "mysterious egg") + " - visit Bairc.")
                : ("A " + _bsr_egg.name + " follows you home - visit Bairc.");
            array_push(loot_special_rows, { kind: "pet", pet: _bsr_egg, label: _bsr_lbl,
                sub: _bsr_egg.is_egg ? "Something alive waits inside - Bairc can raise it."
                                     : "It pads after you, already loyal - Bairc will see to it.",
                tag: "[COMPANION]" });
        }
        // Signature gift trinket roll (Phase 4b, 3%): extraction-gated keepsake.
        var _bsr_tk = gift_try_boss_trinket();
        if (_bsr_tk != undefined) {
            array_push(combat_log, "Among the remains: " + _bsr_tk.name + " - " + _bsr_tk.flavor + ". A gift begging for its owner.");
            array_push(loot_special_rows, { kind: "trinket", id: _bsr_tk.id, label: _bsr_tk.name,
                sub: _bsr_tk.flavor + " - a gift begging for its owner.", tag: "[KEEPSAKE]" });
        }
        // Banshee in a Bottle: guaranteed from each dungeon's FINAL boss, first
        // kill only (BANSHEE_BOTTLE_SPEC.md). Granted here so it LISTS; the
        // R-dismiss full-clear branch banks it via end_run(1) as before.
        var _bsr_desc = variable_global_exists("descent_active") && global.descent_active;
        if (global.current_floor >= 3 && !_bsr_desc) {
            banshee_init();
            var _bsr_dung = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
            if (!variable_struct_exists(global.banshee_boss_drops, _bsr_dung)) {
                variable_struct_set(global.banshee_boss_drops, _bsr_dung, true);
                global.banshee_carried++;
                array_push(combat_log, "Among the remains: a corked bottle, faintly wailing. A Banshee in a Bottle!");
                array_push(loot_special_rows, { kind: "banshee", label: "Banshee in a Bottle",
                    sub: "A corked bottle, faintly wailing - Maren can free the song at camp.", tag: "[SONG]" });
            }
        }
        random_set_seed(_bsr_seed);
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
    // Show loot screen once all points are allocated (special rows alone - a
    // boss egg with no item drops - still open it: the spectacle IS the point).
    if (!combat_over
        && ((variable_global_exists("run_items_found") && array_length(global.run_items_found) > 0)
            || array_length(loot_special_rows) > 0)
        && !show_loot_screen) {
        show_loot_screen = true;
        // Arm the staggered reveal + find the best item for the ONE stinger
        // (haul rule, SOUND_ATMOSPHERE_SPEC.md section 1).
        loot_reveal_timer = 0;
        loot_reveal_shown = 0;
        loot_sting_played = false;
        loot_best_row     = 0;
        loot_best_rarity  = 0;
        for (var _lbi = 0; _lbi < array_length(global.run_items_found); _lbi++) {
            var _lbit = global.run_items_found[_lbi];
            var _lbr  = variable_struct_exists(_lbit, "rarity") ? _lbit.rarity : 0;
            if (_lbr > loot_best_rarity) { loot_best_rarity = _lbr; loot_best_row = _lbi; }
        }
        // A special row (pet/banshee/trinket) is the haul's headline: its first
        // row carries the legendary-grade stinger regardless of item rarities.
        if (array_length(loot_special_rows) > 0) {
            loot_best_rarity = 4;
            loot_best_row    = array_length(global.run_items_found);
        }
        exit;
    }
    // Resolve any pack-full consumable pickups before combat closes (after the
    // loot review so the player has seen what dropped). The modal runs one frame
    // at a time until the overflow queue is empty.
    // M 08-13 ("pops up first then gets overridden by item rewards"): the step
    // used to PROCESS the modal invisibly while the level-alloc / loot screens
    // were still up - eating their inputs and advancing the discard state under
    // them. It now honors the SAME gate as the Draw modal: it only runs once
    // every other post-battle screen is done (still ahead of the boss
    // extract/descend choice, which waits on combat_over).
    if (!combat_over && consumable_overflow_pending()) {
        var _ovf_alloc = instance_exists(obj_game_controller)
                      && instance_find(obj_game_controller, 0).level_alloc_open;
        if (!_ovf_alloc && !show_loot_screen) {
            // The ordered chain above has fully drained (alloc + loot done) -
            // NOW the Draw modal may appear (it gates on this flag so it can't
            // flash early during the victory pause; M 08-14).
            overflow_stage_reached = true;
            consumable_overflow_step();
        }
        exit;
    }
    if (!combat_over) {
        combat_over   = true;
        combat_result = 1;
        // Crimson Reserve TRANSCEND "Overflow" (POTENCY V2): bank up to 4 of the
        // Blood still in the tank for the next combat (read at start traits).
        if (player.class_id == 1 && variable_struct_exists(player, "blood")
            && trait_transcended("Crimson Reserve")) {
            global.blood_carry = min(player.blood, 4);
            if (global.blood_carry > 0) array_push(combat_log, "Overflow: " + string(global.blood_carry) + " Blood is kept warm for the next fight.");
        }
        // Soul Shield "Unbroken" web keystone (P3, 07-29 - LIVETEST WATCH): the
        // shield left standing at victory carries to the next combat (max 10).
        if (variable_struct_exists(player, "shield_hp") && player.shield_hp > 0
            && variable_struct_exists(player, "abilities")) {
            for (var _ubi = 0; _ubi < array_length(player.abilities); _ubi++) {
                var _uba = player.abilities[_ubi];
                if (_uba.name == "Soul Shield" && ability_web_copy_has_rider(_uba, "unbroken")) {
                    global.unbroken_shield = min(10, player.shield_hp);
                    array_push(combat_log, "Unbroken: " + string(global.unbroken_shield) + " of the ward refuses to fall - it will stand in the next fight.");
                    break;
                }
            }
        }
        // Victory hierarchy: boss (floor-completing) wins get the grand harpsichord
        // flourish, ordinary fights a light music-box chime so it never wears thin.
        var _is_boss_win = variable_global_exists("next_enemy_type") && global.next_enemy_type == "boss";
        audio_play_sound(_is_boss_win ? snd_sting_victory : snd_sting_floor, 1, false);
        array_push(combat_log, "Victory! All enemies defeated.");
    }
    exit;
}

if (_result == -1) {
    combat_over   = true;
    combat_result = -1;
    // IRONMAN resume: death is SETTLED the frame it lands (SYSTEMS_RUN_RESUME.md)
    // - checkpoint gone, mercy/clawback resolved, and the result committed to
    // disk BEFORE the defeat screen even draws. Killing the app here changes
    // nothing. The Draw result handler skips its own end_run via defeat_settled.
    run_checkpoint_delete();
    end_run(-1);
    // THE IRON VOW (SYSTEMS_IRON_VOW.md): a defeat consumes a life inside the
    // same settle frame. The final death writes the gravestone and erases the
    // save instead of saving it - alt-F4 on the death screen changes nothing.
    if (variable_global_exists("vow_mode") && global.vow_mode > 0) {
        global.vow_lives_left = max(0, global.vow_lives_left - 1);
        if (global.vow_lives_left <= 0) {
            vow_fall();
            vow_fallen = true;
        } else {
            save_game();
        }
    } else {
        save_game();
    }
    defeat_settled = true;
    audio_play_sound(snd_sting_defeat, 1, false);
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
        // Reset the same-category AP synergy tracker at the start of each player turn
        // (SYSTEMS_ABILITY_SYNERGY.md): the first ability of a category pays full cost
        // again. This is the single canonical player-turn-start hook (the per-turn
        // one-liners elsewhere just raise need_player_status_tick).
        player.turn_cast_categories = {};
        // Combat plan v2 (07-17): reset per-turn flags, end the Counterblade stance,
        // and expire whatever Poise shield survived the enemy turn (StS block does not
        // carry over). poise_shield is decremented as shield is spent, so only the
        // UNSPENT remainder is removed here - persistent shields (Sanguine Pact,
        // Ashkeeper Blade) are never touched.
        player.adrenaline_turn_used = false;
        player.interrupt_used       = false;
        player.counterblade_active  = false;
        player.measured_riposte_active = false;   // Duelist Arts: the answer expires with the turn
        if (variable_struct_exists(player, "poise_shield") && player.poise_shield > 0) {
            player.shield_hp = max(0, player.shield_hp - player.poise_shield);
            player.poise_shield = 0;
        }
        // Arcane Burst FADING (M 08-18): remember whether it was cast LAST turn so a
        // back-to-back cast lands at half power. Rolls at every player-turn start.
        player.burst_cast_prev = variable_struct_exists(player, "burst_cast_this") ? player.burst_cast_this : false;
        player.burst_cast_this = false;
        // Tick down per-ability cooldowns at the start of the player's turn.
        if (variable_struct_exists(player, "ability_cd")) {
            for (var _cdi = 0; _cdi < array_length(player.ability_cd); _cdi++) {
                if (player.ability_cd[_cdi] > 0) player.ability_cd[_cdi]--;
            }
        }
        // SUMMON lifetime (class pass 08-13): the construct weathers 3 of your
        // turns, then crumbles - detonate before the clock runs out.
        if (variable_struct_exists(player, "summon") && is_struct(player.summon)) {
            player.summon.turns -= 1;
            if (player.summon.turns <= 0) {
                array_push(combat_log, "The " + player.summon.name + " crumbles to dust - its moment has passed.");
                player.summon = undefined;
            }
        }
        // Fifth Pulse dark gift (08-04): the cursed metal beats once every 5th
        // round - +1 AP per equipped Pulse (same unclamped idiom as Void Scepter).
        var _dg_fp = dark_gift_total("ap_pulse");
        if (_dg_fp > 0 && combat_state.round mod 5 == 0 && combat_state.round > 0) {
            player.energy += _dg_fp;
            array_push(combat_log, "FIFTH PULSE - the dark metal beats: +" + string(_dg_fp) + " AP!");
        }
        var _hp_pre_tick = player.HP;
        combat_tick_statuses(player, combat_log);
        // Board "flawless" requests: DoT ticks count as taking damage (the Blood
        // Price self-drain below deliberately does NOT - it's the player's curse).
        if (player.HP < _hp_pre_tick) combat_state.player_took_damage = true;
        // Blood Price curse: lose a flat amount of HP at the start of each turn.
        var _bp_drain = curse_turn_hp_drain();
        if (_bp_drain > 0) {
            player.HP -= _bp_drain;
            array_push(combat_log, "Blood Price drains " + string(_bp_drain) + " HP.");
        }
        if (player.HP <= 0 && !combat_try_last_stand(player, combat_log)) {
            player.is_defeated = true;
            exit; // victory/defeat check at the top of next frame resolves it
        }
    }

    // Onboarding coach-marks (see SYSTEMS_ONBOARDING.md). On the player's turn, teach
    // the AP economy first; once that's seen, teach target-switching the first time a
    // fight has more than one foe. Both are once-only and self-gate (one tip at a time).
    if (!combat_over) {
        if (!tutorial_try_show("combat_ap")) {
            // Count living foes (the roster is combat_state.combatants - player + enemies,
            // distinguished by is_player; there is no standalone `enemies` array here).
            var _foe_count = 0;
            var _cbts = combat_state.combatants;
            for (var _tci = 0; _tci < array_length(_cbts); _tci++) {
                var _tcc = _cbts[_tci];
                if (variable_struct_exists(_tcc, "is_player") && _tcc.is_player) continue;
                if (variable_struct_exists(_tcc, "HP") && _tcc.HP <= 0) continue;
                _foe_count++;
            }
            // Teach target-switching only in multi-foe fights; once that's handled (shown
            // now, already seen, or single foe), teach the intent chips, then
            // inspect-on-hover. One tip at a time.
            if (!(_foe_count > 1 && tutorial_try_show("targeting"))) {
                if (!tutorial_try_show("intent")) {
                    if (!tutorial_try_show("inspect")) tutorial_try_show("weakness");   // P2 gem (08-01)
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // 3a. CONSUMABLE QUICK MENU - intercepts all other input while open
    // -------------------------------------------------------------------------
    // Small framed button, far bottom-right so it clears the ability tooltip
    // (x1260-1740). Must stay in sync with the draw in Draw_64.
    // Shared geometry (scr_ui combat_items_button_geom) - was duplicated literals
    // here and in Draw_64, which is exactly how the two drift apart. On touch the
    // button relocates into the right gutter, and this hit-test follows for free.
    var _ibg = combat_items_button_geom();
    var _ibx = _ibg.x1;
    var _iby = _ibg.y1;
    var _ibw = _ibg.w;
    var _ibh = _ibg.h;

    // C key or ITEMS button click to toggle. The menu always opens - when the
    // run buffer is empty it shows "No consumables held." rather than doing
    // nothing (stash consumables stay hub-only; the buffers stay separate).
    if (input_hotkey("C")) {
        consumable_quick_open = !consumable_quick_open;
        if (consumable_quick_open) consumable_quick_cursor = 0;
        consumable_confirm_idx = -1;   // never reopen with a row still armed
    }

    if (mouse_check_button_pressed(mb_left)) {
        var _iqmx = device_mouse_x_to_gui(0);
        var _iqmy = device_mouse_y_to_gui(0);
        if (_iqmx >= _ibx && _iqmx < _ibx + _ibw && _iqmy >= _iby && _iqmy < _iby + _ibh) {
            consumable_quick_open = !consumable_quick_open;
            if (consumable_quick_open) consumable_quick_cursor = 0;
            consumable_confirm_idx = -1;
        }
    }

    if (consumable_quick_open) {
        // Grouped view (identical consumables collapse to one row); cursor + use map
        // through it back to a real inventory index. Mirrors Draw_64.
        var _qgroups = consumables_grouped();
        var _qcount  = array_length(_qgroups);
        if (_qcount == 0) {
            // Empty state: the menu stays open showing "No consumables held.";
            // Esc closes it (C is handled by the toggle above).
            if (input_cancel()) consumable_quick_open = false;
        } else {
            // Navigation (hold-repeat + wrap). Moving off an armed row disarms it,
            // so a confirm can never land on an item you didn't mean to pick.
            if (nav_up())   { consumable_quick_cursor = wrap_index(consumable_quick_cursor - 1, _qcount); consumable_confirm_idx = -1; }
            if (nav_down()) { consumable_quick_cursor = wrap_index(consumable_quick_cursor + 1, _qcount); consumable_confirm_idx = -1; }
            // Esc closes. (C is handled by the toggle above - checking it here too
            // would re-close it in the same frame it opens, so it's intentionally absent.)
            if (input_cancel()) {
                // An armed row swallows the first cancel: Esc means "never mind,
                // don't use that" before it means "close the menu".
                if (consumable_confirm_idx != -1) { consumable_confirm_idx = -1; exit; }
                consumable_quick_open = false;
                exit;
            }

            // Determine if use was triggered (keyboard or mouse click on a row)
            var _use_item = false;
            var _use_idx  = consumable_quick_cursor;
            if (input_confirm()) {
                _use_item = true;
            }
            if (mouse_check_button_pressed(mb_left)) {
                var _qcmx  = device_mouse_x_to_gui(0);
                var _qcmy  = device_mouse_y_to_gui(0);
                // Same windowing as the draw (Draw_64) so clicks hit the visible rows.
                var _q_max_vis = 6;
                var _q_vis     = min(_qcount, _q_max_vis);
                var _q_first   = ui_list_window("combat_quick", consumable_quick_cursor, _qcount, _q_max_vis);
                var _q_last    = min(_qcount, _q_first + _q_max_vis);
                var _qpw   = 750;
                var _qph   = 84 + _q_vis * 108 + 66;
                var _qpx   = 960 - _qpw / 2;
                var _qpy   = max(120, 990 - _qph - 21);
                for (var _qi = _q_first; _qi < _q_last; _qi++) {
                    var _qry = _qpy + 75 + (_qi - _q_first) * 108;
                    if (_qcmx >= _qpx + 15 && _qcmx < _qpx + _qpw - 15
                     && _qcmy >= _qry && _qcmy < _qry + 93) {
                        consumable_quick_cursor = _qi;
                        _use_idx  = _qi;
                        _use_item = true;
                        break;
                    }
                }
            }

            // TOUCH CONFIRM GATE (M 07-18). On a phone the first press only ARMS
            // the row - the second press on that same row actually uses it. Using
            // a consumable is irreversible and a thumb is imprecise, so a single
            // stray tap must never spend a rare potion. Desktop is unchanged: a
            // mouse click / Enter on the highlighted row uses it outright.
            if (_use_item && input_device() == 2) {
                if (consumable_confirm_idx != _use_idx) {
                    consumable_confirm_idx  = _use_idx;
                    consumable_quick_cursor = _use_idx;
                    _use_item = false;              // swallow this press - it armed the row
                    play_sfx_var("snd_ui_move", -1);
                }
            }

            if (_use_item) {
                consumable_confirm_idx = -1;        // spent (or refused) - always disarm
                // Map the grouped row back to a real inventory index (the first instance).
                var _real_idx = _qgroups[_use_idx].first_index;
                var _citem = _qgroups[_use_idx].item;
                // AP-restore items ("energy") and the resource+AP brew ("resource_ap")
                // cost no AP, so they work at 0 AP too (and their +AP is a real net gain).
                var _q_is_ap = (_citem.effect_type == "energy" || _citem.effect_type == "resource_ap");
                if (_citem.effect_type == "escape_lamp" || _citem.effect_type == "escape_wine") {
                    // Escape items resolve on the FLOOR MAP (G key) - never mid-fight, and
                    // they must not fall through the chain and get consumed for nothing.
                    array_push(combat_log, _citem.name + " cannot be used mid-fight - use it from the floor map [G].");
                } else if (_citem.effect_type == "valuable") {
                    array_push(combat_log, _citem.name + " has no use in a fight - sell it at camp (Petra).");   // 08-17 valuables
                } else if (player.energy < 1 && !_q_is_ap) {
                    array_push(combat_log, "Need 1 AP to use a consumable.");
                } else {
                    combat_state.used_consumable = true;   // board "clean fights" requests
                    audio_play_sound(snd_potion, 1, false);
                    // CHAOTIC BREW (reworked 08-15, M-locked): effects were stamped
                    // at BREW time (60% of each base + a rolled downside, all readable
                    // in the item desc). Apply each part through the same channels the
                    // base potions use. Legacy pre-rework brews (no .mix) keep the old
                    // drink-time roll. Never mutate _citem - stacked brews share the
                    // group representative.
                    if (_citem.effect_type == "chaotic") {
                        global.ach_brew_run = true;   // ACH_BREW: drank one - now survive the run
                        if (variable_struct_exists(_citem, "mix")) {
                            array_push(combat_log, "The Chaotic Brew takes hold!");
                            var _chmix = _citem.mix;
                            for (var _chi = 0; _chi < array_length(_chmix); _chi++) {
                                var _chp = _chmix[_chi];
                                switch (_chp.effect_type) {
                                    case "heal": {
                                        var _chh = min(player.max_HP - player.HP, _chp.effect_value);
                                        player.HP += _chh;
                                        if (_chh > 0) array_push(damage_popups, { value: _chh, x: 475, y: 545, timer: 45, col: c_lime });
                                        array_push(combat_log, "...restored " + string(_chh) + " HP.");
                                    } break;
                                    case "shield": {
                                        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                                        player.shield_hp += _chp.effect_value;
                                        array_push(combat_log, "...a " + string(_chp.effect_value) + "-point ward hardens.");
                                    } break;
                                    case "heal_dot": {
                                        if (!variable_struct_exists(player, "status_effects")) player.status_effects = [];
                                        array_push(player.status_effects, {
                                            name: "Chaotic Brew", kind: "regen", effect_type: "heal_dot",
                                            effect_value: _chp.effect_value, duration: 3, element: ""
                                        });
                                        array_push(combat_log, "...regenerating " + string(_chp.effect_value) + " HP/turn for 3 turns.");
                                    } break;
                                    case "energy": {
                                        player.energy += _chp.effect_value;
                                        array_push(combat_log, "...+" + string(_chp.effect_value) + " AP!");
                                    } break;
                                    case "resource_ap": {
                                        var _chres = _chp.effect_value;
                                        if (variable_struct_exists(player, "souls"))            player.souls = min(player.souls_max, player.souls + _chres);
                                        else if (variable_struct_exists(player, "blood"))       player.blood = min(player.blood_max, player.blood + _chres);
                                        else if (variable_struct_exists(player, "preparation")) player.preparation = min(player.preparation_max, player.preparation + _chres);
                                        player.energy += 1;
                                        array_push(combat_log, "...+" + string(_chres) + " resource and +1 AP!");
                                    } break;
                                    case "cleanse_dot":    { var _chc = combat_cleanse(player, "dot"); if (_chc > 0) array_push(combat_log, "...cleared " + string(_chc) + " DoT(s)."); } break;
                                    case "cleanse_debuff": { var _chc2 = combat_cleanse(player, "one"); if (_chc2 > 0) array_push(combat_log, "...removed a debuff."); } break;
                                    case "cleanse_all":    { var _chc3 = combat_cleanse(player, "all"); if (_chc3 > 0) array_push(combat_log, "...cleared " + string(_chc3) + " negative effect(s)."); } break;
                                    case "gold_find_pot": potion_drink_gold(_chp.effect_value); array_push(combat_log, "...gold drops +" + string(_chp.effect_value) + "% until 2 bosses fall."); break;
                                    case "loot_find_pot": potion_drink_loot(_chp.effect_value); array_push(combat_log, "...loot chance +" + string(_chp.effect_value) + "% until 2 bosses fall."); break;
                                }
                            }
                            var _chd = variable_struct_exists(_citem, "downside") ? _citem.downside : undefined;
                            // Sealed Reserve (Sable rank 2, M-locked 08-15): downsides HALVED
                            // - the bite bleeds half, the numbness misses half the time.
                            var _chd_seal = (npc_rank("sable") >= 2);
                            if (_chd != undefined) {
                                if (_chd.kind == "bite") {
                                    var _bite = irandom_range(8, 15);
                                    if (_chd_seal) _bite = max(1, _bite div 2);
                                    player.HP = max(1, player.HP - _bite);
                                    array_push(combat_log, "...the dregs bite going down - " + string(_bite) + " damage!");
                                    array_push(damage_popups, { value: _bite, x: 475, y: 545, timer: 45, col: c_red });
                                } else if (_chd.kind == "sluggish") {
                                    if (_chd_seal && irandom(1) == 0) {
                                        array_push(combat_log, "...the sealed dregs pass clean - no numbness.");
                                    } else {
                                        player.energy = max(0, player.energy - 1);
                                        array_push(combat_log, "...the dregs numb your arm - 1 AP lost.");
                                    }
                                }
                            }
                            _citem = { name: "Chaotic Brew", effect_type: "chaotic_spent", effect_value: 0 };
                        } else {
                            var _ch = chaotic_brew_roll();
                            array_push(combat_log, "The Chaotic Brew " + _ch.label + "!");
                            if (_ch.sting) {
                                var _bite = irandom_range(8, 15);
                                player.HP = max(1, player.HP - _bite);
                                array_push(combat_log, "...but it curdles going down - " + string(_bite) + " damage!");
                                array_push(damage_popups, { value: _bite, x: 475, y: 545, timer: 45, col: c_red });
                            }
                            _citem = { name: "Chaotic Brew", effect_type: _ch.effect_type, effect_value: _ch.value };
                        }
                    }
                    if (_citem.effect_type == "heal") {
                        var _qheal = min(player.max_HP - player.HP, _citem.effect_value);
                        player.HP += _qheal;
                        array_push(combat_log, "Used " + _citem.name
                            + " - restored " + string(_qheal) + " HP!");
                        if (_qheal > 0) {
                            array_push(damage_popups,
                                { value: _qheal, x: 475, y: 545, timer: 45, col: c_lime });
                        }
                    } else if (_citem.effect_type == "energy") {
                        // Burst AP: no cap (can exceed the 3-AP turn limit) and no use cost.
                        player.energy += _citem.effect_value;
                        array_push(combat_log, "Used " + _citem.name
                            + " - +" + string(_citem.effect_value) + " AP!");
                    } else if (_citem.effect_type == "cleanse_dot") {
                        var _cl_n = combat_cleanse(player, "dot");
                        array_push(combat_log, "Used " + _citem.name + (_cl_n > 0
                            ? " - cleared " + string(_cl_n) + " damage-over-time effect(s)!"
                            : " - no DoT effects to clear."));
                    } else if (_citem.effect_type == "cleanse_debuff") {
                        var _cl_n = combat_cleanse(player, "one");
                        array_push(combat_log, "Used " + _citem.name + (_cl_n > 0
                            ? " - removed a debuff!" : " - no debuff to remove."));
                    } else if (_citem.effect_type == "cleanse_all") {
                        var _cl_n = combat_cleanse(player, "all");
                        array_push(combat_log, "Used " + _citem.name + (_cl_n > 0
                            ? " - cleared " + string(_cl_n) + " negative effect(s)!"
                            : " - no negative effects to clear."));
                    } else if (_citem.effect_type == "heal_dot") {
                        // Heal-over-time: apply a "regen" status that ticks each player
                        // turn via combat_tick_statuses (previously this did NOTHING).
                        // Both heal_dot tonics read "per turn for 3 turns".
                        if (!variable_struct_exists(player, "status_effects")) player.status_effects = [];
                        array_push(player.status_effects, {
                            name:         _citem.name,
                            kind:         "regen",
                            effect_type:  "heal_dot",
                            effect_value: _citem.effect_value,
                            duration:     3,
                            element:      ""
                        });
                        array_push(combat_log, "Used " + _citem.name + " - regenerating "
                            + string(_citem.effect_value) + " HP/turn for 3 turns.");
                    } else if (_citem.effect_type == "shield") {
                        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                        player.shield_hp += _citem.effect_value;
                        array_push(combat_log, "Used " + _citem.name
                            + " - gained a " + string(_citem.effect_value) + "-point shield!");
                    } else if (_citem.effect_type == "resource_ap") {
                        // Ley Battery: restore the class's secondary resource AND grant +1
                        // burst AP (free to use). Distinct from Adrenaline Vial (pure AP).
                        var _ley_res   = _citem.effect_value;
                        var _ley_label = "resource";
                        if (variable_struct_exists(player, "souls")) {
                            player.souls = min(player.souls_max, player.souls + _ley_res); _ley_label = "Souls";
                        } else if (variable_struct_exists(player, "blood")) {
                            player.blood = min(player.blood_max, player.blood + _ley_res); _ley_label = "Blood";
                        } else if (variable_struct_exists(player, "preparation")) {
                            player.preparation = min(player.preparation_max, player.preparation + _ley_res); _ley_label = "Preparation";
                        }
                        player.energy += 1;
                        array_push(combat_log, "Used " + _citem.name
                            + " - +" + string(_ley_res) + " " + _ley_label + " and +1 AP!");
                    } else if (_citem.effect_type == "gold_find_pot") {
                        // Goldfinger Elixir: +gold drops until 2 bosses are slain.
                        potion_drink_gold(_citem.effect_value);
                        array_push(combat_log, "Used " + _citem.name
                            + " - gold drops +" + string(_citem.effect_value) + "% until 2 bosses fall!");
                    } else if (_citem.effect_type == "loot_find_pot") {
                        // Faerie's Tear: +loot drop chance until 2 bosses are slain.
                        potion_drink_loot(_citem.effect_value);
                        array_push(combat_log, "Used " + _citem.name
                            + " - loot chance +" + string(_citem.effect_value) + "% until 2 bosses fall!");
                    }
                    // AP-restore items are free; everything else costs 1 AP.
                    if (!_q_is_ap) player.energy -= 1;
                    // Blessed Thirst (was Lucky Find): 20% chance the item is not consumed.
                    // POTENCY V2: +4%/rank (20-36%); TRANSCEND "Bottomless": the FIRST
                    // consumable each combat is always preserved.
                    var _bt_first = trait_transcended("Blessed Thirst")
                        && (!variable_struct_exists(player, "bottomless_used") || !player.bottomless_used);
                    if (trait_active("Blessed Thirst")
                        && (_bt_first || irandom(99) < 20 + 4 * trait_potency_r14("Blessed Thirst"))) {
                        if (_bt_first) player.bottomless_used = true;
                        array_push(combat_log, (_bt_first ? "Bottomless" : "Blessed Thirst") + " - " + _citem.name + " is not consumed!");
                    } else {
                        array_delete(global.consumable_inventory, _real_idx, 1);
                    }
                    if (instance_exists(obj_game_controller)) {
                        instance_find(obj_game_controller, 0).items_used_this_turn++;
                    }
                    // Close if nothing left, otherwise clamp cursor to the new GROUP count
                    // (using the last of a stack removes that whole row).
                    var _remaining = array_length(consumables_grouped());
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

    // -------------------------------------------------------------------------
    // 3b. ABILITY DETAIL POPUP (V) - full breakdown of the selected ability
    // Mirrors the Tab popup on the loadout / Vex screens (ui_draw_ability_detail).
    // Tab itself stays bound to target-cycling here, so combat uses V instead.
    // While the popup is up, V or Esc closes it and all other combat input is
    // swallowed.
    // -------------------------------------------------------------------------
    if (ability_detail_open) {
        if (input_hotkey("V") || input_cancel()) {
            ability_detail_open = false;
        }
        // Scroll (M 08-13: the popup SHOWED a scrollbar but the early `exit`
        // swallowed W/S and the wheel before any scroll code could run).
        var _ad_max = variable_global_exists("ui_ability_detail_max_scroll")
                    ? global.ui_ability_detail_max_scroll : 0;
        if (nav_down() || mouse_wheel_down()) ability_detail_scroll = clamp(ability_detail_scroll + 48, 0, _ad_max);
        if (nav_up()   || mouse_wheel_up())   ability_detail_scroll = clamp(ability_detail_scroll - 48, 0, _ad_max);
        exit;
    }
    if (input_hotkey("V") && array_length(player.abilities) > 0) {
        ability_detail_open   = true;
        ability_detail_scroll = 0;
        exit;
    }

    // --- Ability selection (navigate with arrow keys or WASD; wraps around) ---
    var _ability_count = array_length(player.abilities);
    if (_ability_count > 0) {
        if (nav_left())  selected_ability = wrap_index(selected_ability - 1, _ability_count);
        if (nav_right()) selected_ability = wrap_index(selected_ability + 1, _ability_count);
        // Mouse wheel cycles the selection too (M 07-30) - anywhere on screen
        // EXCEPT over the combat log, which keeps its own wheel scroll (the
        // rect here mirrors the log wheel gate at the top of this event).
        var _abw = mouse_wheel_down() - mouse_wheel_up();
        if (_abw != 0) {
            var _abw_mx = device_mouse_x_to_gui(0);
            var _abw_my = device_mouse_y_to_gui(0);
            if (!(_abw_mx >= 30 && _abw_mx <= 1200 && _abw_my >= 735 && _abw_my <= 945)) {
                selected_ability = wrap_index(selected_ability + _abw, _ability_count);
                end_turn_focus = false;
            }
        }
    }

    // D-pad End Turn reachability (07-24): DOWN focuses the END TURN button,
    // UP or sideways drops back to the ability row. The confirm gate at the
    // cast-attempt block below ends the turn while focused.
    if (nav_down()) end_turn_focus = true;
    if (nav_up() || nav_left() || nav_right()) end_turn_focus = false;

    // --- Tab key cycles through living enemies ---
    if (input_detail()) {
        var _living_count = 0;
        for (var _i = 0; _i < array_length(combat_state.combatants); _i++) {
            var _c = combat_state.combatants[_i];
            if (!_c.is_player && !_c.is_defeated) _living_count++;
        }
        if (_living_count > 1) {
            selected_target = (selected_target + 1) mod _living_count;
        }
    }

    // --- Number hotkeys: select and cast the matching ability (1..N, max 9) ---
    var _should_cast = false;
    var _hk_max = min(array_length(player.abilities), 9);
    for (var _hk = 0; _hk < _hk_max; _hk++) {
        if (input_hotkey(string(_hk + 1))) {
            selected_ability = _hk;
            _should_cast = true;
        }
    }

    // --- Mouse input ---
    // Touch (8d): abilities cast on TAP-RELEASE (a drag can't cast) and a
    // LONG-PRESS examines the ability instead (simulated V -> detail popup).
    // Desktop mouse keeps press semantics - byte-identical for device 0/1.
    var _cb_tap = (input_device() == 2) && touch_tap();
    var _cb_lp  = (input_device() == 2) && touch_lp();
    if ((input_device() != 2 && mouse_check_button_pressed(mb_left)) || _cb_tap || _cb_lp) {
        var _cmx = _cb_tap ? touch_tap_x() : (_cb_lp ? touch_lp_x() : device_mouse_x_to_gui(0));
        var _cmy = _cb_tap ? touch_tap_y() : (_cb_lp ? touch_lp_y() : device_mouse_y_to_gui(0));

        // Ability buttons: geometry from the shared combat_ability_geom (touch
        // widens the row; desktop = 240+i*252, 240x75 @ y990).
        // Touch two-step (M 07-08 device test: single tap-release still cast by
        // accident coming out of a scroll): first tap only SELECTS/highlights
        // the ability, tapping the selected ability again casts it. Desktop
        // mouse keeps single-click cast - byte-identical for device 0/1.
        var _abg = combat_ability_geom(array_length(player.abilities));
        for (var _cbi = 0; _cbi < array_length(player.abilities); _cbi++) {
            var _cbx = _abg.x0 + _cbi * _abg.pitch;
            if (_cmx >= _cbx && _cmx < _cbx + _abg.w && _cmy >= _abg.y && _cmy < _abg.y + _abg.h) {
                if (_cb_lp) {
                    selected_ability = _cbi;
                    touch_press(ord("V"));   // examine, don't cast
                } else if (_cb_tap && selected_ability != _cbi) {
                    selected_ability = _cbi; // first tap: select only
                } else {
                    selected_ability = _cbi;
                    _should_cast = true;     // second tap (or desktop click): cast
                }
                break;
            }
        }
        // Enemy HP bars: 2-column grid matching Draw_64 - columns at x=990/1485 (w400)
        // (width 420), living enemy i at row (i div 2), y=96+row*108, h=42.
        // (Row pitch 78->108 with the intent-chip strip above each bar.)
        var _cbar_li = 0;
        for (var _cti = 0; _cti < array_length(combat_state.combatants); _cti++) {
            var _ctc = combat_state.combatants[_cti];
            if (!_ctc.is_player && !_ctc.is_defeated) {
                var _cbar_x = (_cbar_li mod 2 == 0) ? 990 : 1485;
                var _cbar_y = 96 + (_cbar_li div 2) * 132;   // keep in sync with Draw_64 _bar_row_gap
                if (_cmx >= _cbar_x && _cmx < _cbar_x + 400 && _cmy >= _cbar_y && _cmy < _cbar_y + 42) {
                    selected_target = _cbar_li;
                }
                _cbar_li++;
            }
        }
        // End Turn button (around the "T: End Turn" prompt at y=954, x center).
        // NOT on touch - the framed END TURN button (Draw) fires a simulated T
        // there; running this inline zone too would end the turn twice.
        if (input_device() != 2 && _cmx >= 660 && _cmx < 1260 && _cmy >= 946 && _cmy < 982) {
            // Inline end-turn - mirrors the T-key block below
            player.poise_shield = 0;
            if (player.energy > 0) {
                array_push(combat_log, "Turn ended - " + string(player.energy) + " AP unspent.");
                // Aegis of the Unbroken Line (07-28 legendary): poise converts at 3
                // shield per unspent AP and the cap doubles.
                var _poise_rate = (variable_struct_exists(player, "leg_line") && player.leg_line) ? 3 : 2;
                var _poise_capm = (variable_struct_exists(player, "leg_line") && player.leg_line) ? 2 : 1;
                // POISE (07-17): unspent AP braces you - 2 shield each (cap 6, 8 with
                // Relentless), expiring at the start of your next turn (StS block model).
                if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                player.poise_shield = min(player.energy * _poise_rate, (trait_active("Relentless") ? 8 : 6) * _poise_capm);
                player.shield_hp += player.poise_shield;
                array_push(combat_log, "Poise braces you (+" + string(player.poise_shield) + " shield).");
            }
            if (variable_struct_exists(player, "iron_skin_duration") && player.iron_skin_duration > 0) {
                player.iron_skin_duration--;
                if (player.iron_skin_duration <= 0) {
                    player.damage_reduction = 0;
                    array_push(combat_log, "Iron Skin wore off.");
                }
            }
            // Smoke Bomb self-cover ticks with your turns, like Iron Skin.
            if (variable_struct_exists(player, "smoke_dodge_turns") && player.smoke_dodge_turns > 0) {
                player.smoke_dodge_turns--;
                if (player.smoke_dodge_turns <= 0) array_push(combat_log, "The smoke thins - your cover is gone.");
            }
            // Glacial Ward's rebuke covers one round of enemy swings.
            if (variable_struct_exists(player, "glacial_ward_turns") && player.glacial_ward_turns > 0) {
                player.glacial_ward_turns--;
            }
            combat_next_turn(combat_state);
            player_turn = combat_state.active.is_player;
            if (!player_turn) {
                // Pet takes its turn before the enemies (Pets Phase 3 lightweight hook).
                enemy_turn_timer = enemy_turn_delay
                    + (combat_pet_act(combat_state, player, combat_log, damage_popups) ? 45 : 0);
            }
            exit;
        }
    }

    // --- G key: call off / resume the companion's guard (M 07-09). Only lands on
    // a guarded-stance Combatant that can actually intercept - otherwise silent.
    // While called off it makes no intercepts (and takes no intercept damage);
    // its own halved strikes continue as normal. Costs no AP.
    if (input_hotkey("G")) {
        var _gt_pet = pet_active();
        if (_gt_pet != undefined && !_gt_pet.is_egg && _gt_pet.stage >= PET_STAGE_YOUNGADULT
            && _gt_pet.archetype == PET_ARCH_COMBATANT && pet_stance(_gt_pet) == "guarded") {
            array_push(combat_log, pet_guard_toggle(_gt_pet)
                ? ("[Companion] " + _gt_pet.name + " falls back - it will not intercept blows.")
                : ("[Companion] " + _gt_pet.name + " stands guard again."));
        }
    }

    // --- T key: End Turn manually ---
    if (input_hotkey("T")) {
        if (player.energy > 0) {
            array_push(combat_log, "Turn ended - " + string(player.energy) + " AP unspent.");
        }
        // Iron Skin ticks once per player turn end, not per ability cast
        if (variable_struct_exists(player, "iron_skin_duration") && player.iron_skin_duration > 0) {
            player.iron_skin_duration--;
            if (player.iron_skin_duration <= 0) {
                player.damage_reduction = 0;
                array_push(combat_log, "Iron Skin wore off.");
            }
        }
        // Smoke Bomb self-cover ticks with your turns, like Iron Skin.
        if (variable_struct_exists(player, "smoke_dodge_turns") && player.smoke_dodge_turns > 0) {
            player.smoke_dodge_turns--;
            if (player.smoke_dodge_turns <= 0) array_push(combat_log, "The smoke thins - your cover is gone.");
        }
        // Glacial Ward's rebuke covers one round of enemy swings.
        if (variable_struct_exists(player, "glacial_ward_turns") && player.glacial_ward_turns > 0) {
            player.glacial_ward_turns--;
        }
        combat_next_turn(combat_state);
        player_turn = combat_state.active.is_player;
        if (!player_turn) {
            // Pet takes its turn before the enemies (Pets Phase 3 lightweight hook).
            enemy_turn_timer = enemy_turn_delay
                + (combat_pet_act(combat_state, player, combat_log, damage_popups) ? 45 : 0);
        }
    }

    // --- Cast attempt (Space, Enter, click, or 1-4 hotkey) ---
    if (_should_cast) end_turn_focus = false;   // an explicit cast always retakes focus
    if ((input_confirm() || input_confirm_alt()) && end_turn_focus) {
        // Confirm while END TURN is focused: end the turn through the unchanged
        // T-key handler (the simulated press is read next frame, like touch).
        end_turn_focus = false;
        touch_press(ord("T"));
    } else if (input_confirm_alt() || input_confirm() || _should_cast) {

        var ab = player.abilities[selected_ability];

        // Already used this ability this turn?
        var _already_used = false;
        for (var _ui = 0; _ui < array_length(abilities_used_this_turn); _ui++) {
            if (abilities_used_this_turn[_ui] == ab.name) { _already_used = true; break; }
        }

        // ===== SUMMON DETONATE (class pass, M 08-13) =====
        // Pressing the button of the summon that is STANDING detonates it.
        // Bypasses the cooldown (which started at summon time) - the detonate
        // is the payoff press - but still costs 1 AP and its once-per-turn use.
        if (ab.effect_type == "summon"
            && variable_struct_exists(player, "summon") && is_struct(player.summon)
            && player.summon.name == ab.name) {
            if (_already_used) {
                array_push(combat_log, ab.name + " already acted this turn.");
            } else if (player.energy < 1) {
                array_push(combat_log, "Detonating the " + ab.name + " takes 1 AP.");
            } else {
                player.energy -= 1;
                array_push(abilities_used_this_turn, ab.name);
                var _sm  = player.summon;
                var _liv = combat_living_enemies(combat_state);
                if (_sm.kind == "golem") {
                    // The eruption: heavy Fire to every enemy - and it is honest,
                    // you and your companion stand in the same room.
                    array_push(combat_log, "The MAGMA GOLEM ERUPTS!");
                    for (var _sd_i = 0; _sd_i < array_length(_liv); _sd_i++) {
                        var _sd_e = _liv[_sd_i];
                        var _sd_d = max(1, (variable_struct_exists(_sm, "power") ? _sm.power : 22) - _sd_e.el_resist);
                        _sd_e.HP -= _sd_d;
                        _sd_e.hit_flash = 15;
                        array_push(combat_log, _sd_e.name + " takes " + string(_sd_d) + " fire damage from the eruption!");
                        if (variable_struct_exists(_sd_e, "last_ex")) {
                            array_push(vfx_bursts, { spr: spr_vfx_fire, x: variable_struct_exists(_sd_e, "last_ecx") ? _sd_e.last_ecx : _sd_e.last_ex + 145, y: variable_struct_exists(_sd_e, "last_ecy") ? _sd_e.last_ecy : _sd_e.last_ey + 145,
                                                     timer: 20 + _sd_i * 4, timer_max: 20, school: "fire", scale: 1.3 });
                        }
                        if (_sd_e.HP <= 0) combat_on_enemy_defeated(_sd_e, player, combat_log);
                    }
                    var _sd_self = 10;
                    combat_apply_damage(player, _sd_self);
                    array_push(combat_log, "The blast sears YOU for " + string(_sd_self) + "!");
                    array_push(damage_popups, { value: _sd_self, x: 475, y: 545, timer: 45, col: make_color_rgb(255, 120, 60) });
                    var _sd_pet = global.duel_active ? undefined : pet_active();
                    if (_sd_pet != undefined && !_sd_pet.is_egg && pet_hp(_sd_pet) > 0) {
                        var _sd_ko = pet_take_damage(_sd_pet, 6);
                        array_push(combat_log, "[Companion] " + _sd_pet.name + " is caught in the blast for 6!"
                            + (_sd_ko ? "  It goes DOWN." : ""));
                    }
                    screen_shake_timer = 18;
                } else if (_sm.kind == "effigy") {
                    array_push(combat_log, "The WARDING EFFIGY bursts into a shockwave - every foe stands EXPOSED!");
                    for (var _sd_i = 0; _sd_i < array_length(_liv); _sd_i++) {
                        var _sd_e = _liv[_sd_i];
                        var _sd_d = 8;
                        _sd_e.HP -= _sd_d;
                        _sd_e.hit_flash = 12;
                        array_push(_sd_e.status_effects, { name: "Warding Shockwave", effect_type: "debuff",
                            kind: "vulnerable", effect_value: 2, duration: 2, source: "player" });
                        if (variable_struct_exists(_sd_e, "last_ex")) {
                            array_push(vfx_bursts, { spr: spr_vfx_arcane, x: variable_struct_exists(_sd_e, "last_ecx") ? _sd_e.last_ecx : _sd_e.last_ex + 145, y: variable_struct_exists(_sd_e, "last_ecy") ? _sd_e.last_ecy : _sd_e.last_ey + 145,
                                                     timer: 18 + _sd_i * 3, timer_max: 18, school: "arcane" });
                        }
                        if (_sd_e.HP <= 0) combat_on_enemy_defeated(_sd_e, player, combat_log);
                    }
                    screen_shake_timer = 10;
                } else {
                    // Static Husk: the chain arc lashes the whole line.
                    array_push(combat_log, "The STATIC HUSK discharges - lightning arcs down the enemy line!");
                    for (var _sd_i = 0; _sd_i < array_length(_liv); _sd_i++) {
                        var _sd_e = _liv[_sd_i];
                        var _sd_d = max(1, 14 - _sd_e.el_resist);
                        _sd_e.HP -= _sd_d;
                        _sd_e.hit_flash = 12;
                        array_push(combat_log, _sd_e.name + " takes " + string(_sd_d) + " shock damage from the arc!");
                        if (variable_struct_exists(_sd_e, "last_ex")) {
                            array_push(vfx_bursts, { spr: spr_vfx_shock, x: variable_struct_exists(_sd_e, "last_ecx") ? _sd_e.last_ecx : _sd_e.last_ex + 145, y: variable_struct_exists(_sd_e, "last_ecy") ? _sd_e.last_ecy : _sd_e.last_ey + 145,
                                                     timer: 16 + _sd_i * 5, timer_max: 16, school: "shock" });
                        }
                        if (_sd_e.HP <= 0) combat_on_enemy_defeated(_sd_e, player, combat_log);
                    }
                    screen_shake_timer = 12;
                }
                player.summon = undefined;
                // Victory detection: the standing end-of-frame check picks up any
                // kills the detonation scored, same as the trap-splash path.
            }
            exit;
        }

        // Control gate - root blocks melee abilities, silence blocks spells, stun blocks all.
        // Dormant until an enemy applies control to the player, but ready. (SYSTEMS_ATTACK_CLASS.md)
        var _ctrl_block = combat_control_block_reason(player, ability_attack_class(ab));
        // Held Breath (whispervine signature move, 08-06): once per combat, the
        // first cast a control would block slips through anyway - the vine exhales.
        if (_ctrl_block != "" && pet_active_sig_move("held_breath")
            && !variable_struct_exists(player, "sig_breath_done")) {
            player.sig_breath_done = true;
            array_push(combat_log, "[Companion] " + pet_active().name + " releases its HELD BREATH - "
                + ab.name + " slips through!");
            _ctrl_block = "";
        }

        // Cooldown gate - evasion abilities (Blink / Shadow Step) can't be re-cast
        // until their per-combat cooldown counter ticks back to 0.
        var _cd_left = (variable_struct_exists(player, "ability_cd")
                        && selected_ability < array_length(player.ability_cd))
                       ? player.ability_cd[selected_ability] : 0;

        // Resource gate cost: ability_effective_cost is the SINGLE SOURCE OF TRUTH
        // (synergy + Quickcast + Cracked Focus + Gatewarden's Brand), so this gate,
        // the button pips and the actual spend below can never disagree (07-09 bug:
        // Cracked Focus applied at spend but not here, so a Singularity that would
        // really cost 1 AP was refused at 1 AP). Discount eligibility is recomputed
        // here only for the cast branch's log lines + charge consumption.
        var _qc_orig_ec = ab.energy_cost;
        var _syn_elig  = ability_synergy_active(ab, player);
        // Support abilities floor at 0 (a 1-AP support after another support is free);
        // every other role floors at 1. Matches ability_effective_cost.
        var _syn_floor = (ability_category(ab) == "support") ? 0 : 1;
        var _qc_elig = rune_aspect_socketed("quickcast")
                       && variable_struct_exists(player, "rune_first_spell_used")
                       && !player.rune_first_spell_used
                       && ability_class_is_spell(ability_attack_class(ab));
        var _eff_cost    = ability_effective_cost(ab, player);
        var _qc_can_cast = (player.energy >= _eff_cost) && ability_secondary_ok(ab, player);

        // THE HOLLOW CROWN (Depth Warden, 08-13): the ability it silenced on its
        // last turn cannot be cast until the crown turns its attention elsewhere.
        // A dead crown holds nothing - the gag only binds while it reigns.
        var _crown_gag = false;
        if (variable_struct_exists(player, "crown_silenced") && player.crown_silenced == ab.name) {
            for (var _cg_i = 0; _cg_i < array_length(combat_state.combatants); _cg_i++) {
                var _cg_e = combat_state.combatants[_cg_i];
                if (!_cg_e.is_player && !_cg_e.is_defeated
                    && variable_struct_exists(_cg_e, "warden_hook") && _cg_e.warden_hook == "crown") {
                    _crown_gag = true;
                    break;
                }
            }
        }

        if (_already_used) {
            array_push(combat_log, ab.name + " already used this turn.");

        } else if (_crown_gag) {
            array_push(combat_log, "THE HOLLOW CROWN holds " + ab.name + " silent - it will not answer you.");

        } else if (_cd_left > 0) {
            array_push(combat_log, ab.name + " is on cooldown (" + string(_cd_left) + " turn(s)).");

        } else if (_ctrl_block != "") {
            array_push(combat_log, "You are " + _ctrl_block + " - can't use " + ab.name + ".");

        // Resource gate - must have enough energy and secondary resource. Name the
        // missing resource explicitly ("Not enough resources." told M nothing when
        // Singularity wanted AP while he was staring at a full Soul bar).
        } else if (!_qc_can_cast) {
            if (player.energy < _eff_cost) {
                array_push(combat_log, ab.name + " needs " + string(_eff_cost)
                    + " AP - you have " + string(player.energy) + ".");
            } else {
                array_push(combat_log, ab.name + " needs " + string(ab.secondary_cost)
                    + " " + ability_secondary_label(player) + " - you have "
                    + string(ability_secondary_amount(player)) + ".");
            }

        } else {
            // Same-category synergy discount: apply the -1 AP for this cast (floor 0 for
            // support, 1 for other roles - see _syn_floor above).
            // Applied before Quickcast/Cracked Focus so those can still reduce further.
            // Guarded on >0 so a free (0-AP) ability is never pushed up to 1.
            if (_syn_elig && ab.energy_cost > 0) {
                ab.energy_cost = max(_syn_floor, ab.energy_cost - 1);
                array_push(combat_log, ab.name + " - "
                    + ability_category_label(ability_category(ab)) + " synergy: -1 AP!");
            }

            // Quickcast: apply the -1 AP discount for this cast and consume the rune.
            // The >0 guard matches ability_effective_cost - a spell synergy already
            // made free doesn't burn the once-per-combat charge for nothing.
            if (_qc_elig && ab.energy_cost > 0) {
                ab.energy_cost -= 1;
                player.rune_first_spell_used = true;
                array_push(combat_log, "Quickcast rune - " + ab.name + " costs 1 less AP!");
            }

            // Cracked Focus (class weapon): first SPELL each combat costs 1 less AP (min 1).
            // The >1 guard matches ability_effective_cost - the charge is only consumed
            // when it actually lowers the cost (never raises 0 back to 1, never burns on
            // a 1-AP spell for zero effect).
            if (ab.energy_cost > 1
                && variable_struct_exists(player, "cf_first_spell_ap") && player.cf_first_spell_ap
                && !player.cf_used && ability_class_is_spell(ability_attack_class(ab))) {
                ab.energy_cost -= 1;
                player.cf_used = true;
                array_push(combat_log, "Cracked Focus - first spell costs 1 less AP!");
            }

            // Third Wind blessing (Shrine V2, 07-29): this cast is the 3rd of the
            // combat - it costs 1 less AP. Mirrors ability_effective_cost (the
            // counter increments after the spend, so both read the same phase).
            if (ab.energy_cost > 0 && boon_active("thirdwind")
                && variable_struct_exists(player, "boon_cast_count")
                && (player.boon_cast_count mod 3) == 2) {
                ab.energy_cost -= 1;
                array_push(combat_log, "Third Wind - the third breath comes free: -1 AP!");
            }

            // OVERCHARGE arming (07-16 combo batch, M-approved): casting a secondary-
            // resource spender while the reserve is FULL drains the WHOLE reserve -
            // the excess pays out at +2 damage / heal / shield per point. Armed here
            // (full check BEFORE the printed cost is paid); resolved after the
            // ability's own consumption riders; cleared unconditionally post-cast so
            // a whiffed cast keeps the reserve. Reserve-HELD scalers (Soul Shield,
            // Arcane Echo) are excluded - they already ARE the hoard payoff, and
            // draining under them would double-dip or trap.
            player.overcharge_armed = ability_overcharge_eligible(ab, player);

            // Gatewarden's Brand: first ability each combat costs 0 AP.
            // Only the energy_cost is waived; secondary resource cost still applies.
            var _brand_proc = player.gatewarden_brand && !player.gatewarden_used;
            if (_brand_proc) {
                player.gatewarden_used = true;
                var _saved_ec = ab.energy_cost;
                ab.energy_cost = 0;
                ability_spend_resources(ab, player);
                ab.energy_cost = _saved_ec;
                array_push(combat_log, "Gatewarden's Brand - " + ab.name + " costs 0 AP!");
            } else {
                ability_spend_resources(ab, player);
            }

            // Rule of Three trunk counter (P2, 08-05): count SPELL casts once per
            // cast at the spend commit; the damage site reads (count mod 3 == 0).
            if (ability_class_is_spell(ability_attack_class(ab))) {
                if (!variable_struct_exists(player, "trunk_spell_casts")) player.trunk_spell_casts = 0;
                player.trunk_spell_casts += 1;
            }
            // Reckoning counter (tallykeep signature move, 08-06): count EVERY
            // ability cast at the spend commit; the damage site reads mod 3 == 0.
            if (!variable_struct_exists(player, "sig_reckon_casts")) player.sig_reckon_casts = 0;
            player.sig_reckon_casts += 1;

            // Duelist T2 repetition ledger (08-13): did this cast repeat the last?
            // Read by enemy_pick_ability - the Quickstep hunts the pattern.
            player.duel_rep = (variable_struct_exists(player, "duel_last_cast")
                               && player.duel_last_cast == ab.name);
            player.duel_last_cast = ab.name;
            // Arcane Burst FADING ledger (M 08-18): mark the cast at the spend commit (a
            // miss still counts as "used this turn"); the damage site reads burst_cast_prev.
            if (ab.name == "Arcane Burst") player.burst_cast_this = true;

            // BLOOD PRICE (class pass, M 08-13: the Bloodwarden heals too well
            // and never bleeds for it). Its two heaviest blows now cost ~5% max
            // HP at the spend commit - paid in blood, never lethal (floors at
            // 1 HP), and healing is deliberately untouched: spend, then mend.
            if (ab.name == "Gore Strike" || ab.name == "Marrow Crush") {
                var _bp = max(1, round(player.max_HP * 0.05));
                if (player.HP > 1) {
                    _bp = min(_bp, player.HP - 1);
                    player.HP -= _bp;
                    array_push(combat_log, ab.name + " takes its blood price - " + string(_bp) + " HP.");
                    array_push(damage_popups, { value: _bp, x: 475, y: 545, timer: 40,
                                                col: make_color_rgb(200, 60, 60) });
                }
            }

            // THE TALLY (Depth Warden, 08-13): it counts. Every time you commit
            // an ability you have ALREADY used this combat, the Tally gains a
            // permanent stack - +2 damage each. The per-combat use ledger rides
            // the player struct; the stack rides the Warden.
            if (!variable_struct_exists(player, "combat_ability_uses")) player.combat_ability_uses = {};
            var _ty_seen = variable_struct_exists(player.combat_ability_uses, ab.name);
            player.combat_ability_uses[$ ab.name] = true;
            if (_ty_seen) {
                for (var _ty_i = 0; _ty_i < array_length(combat_state.combatants); _ty_i++) {
                    var _ty_e = combat_state.combatants[_ty_i];
                    if (!_ty_e.is_player && !_ty_e.is_defeated
                        && variable_struct_exists(_ty_e, "warden_hook") && _ty_e.warden_hook == "tally") {
                        _ty_e.tally_stacks = (variable_struct_exists(_ty_e, "tally_stacks") ? _ty_e.tally_stacks : 0) + 1;
                        _ty_e.damage += 2;
                        _ty_e.telegraph_damage += 2;
                        array_push(combat_log, "THE TALLY marks the repetition - " + string(_ty_e.tally_stacks)
                            + " stack(s), its blows land +2 harder.");
                        break;
                    }
                }
            }

            // Restore the real energy_cost (Arcane Surge etc. read the ability's true cost).
            // Unconditional - synergy, Quickcast and Cracked Focus all mutate it; _qc_orig_ec
            // is the untouched original captured before any discount.
            ab.energy_cost = _qc_orig_ec;

            // Record this ability's role category so the NEXT same-category ability THIS
            // turn gets the -1 AP synergy discount (SYSTEMS_ABILITY_SYNERGY.md). Marked
            // after the resource spend commits, so the first of a category always pays full.
            player.turn_cast_categories[$ ability_category(ab)] = true;

            // Third Wind blessing: count the committed cast (per-combat rhythm).
            if (variable_struct_exists(player, "boon_cast_count")) player.boon_cast_count += 1;

            // Cast windup FX (07-09 art track): SPELL casts flare the caster in the
            // school's color (melee keeps its lunge). Drawn in Draw_64 by the sprite.
            if (ability_class_is_spell(ability_attack_class(ab))) {
                cast_fx_timer = 26;
                var _cfx_sch  = ability_school(ab);
                cast_fx_color = (_cfx_sch == "") ? make_color_rgb(150, 120, 220) : school_color(_cfx_sch);
            }

            // ---- TRAP DEPLOY (08-08 rework, SYSTEMS_TRAPS.md) ----
            // Traps are self-targeted now, so they never reach the damage/status
            // path below - the whole payload waits until the trap SPRINGS. All that
            // happens here is that it takes a slot.
            if (ability_is_trap(ab.name)) {
                if (!variable_struct_exists(player, "traps") || !is_array(player.traps)) player.traps = [];
                var _tdf  = trap_def(ab.name);
                var _tcap = trap_slots_max(player);
                // Slots full: the OLDEST trap is replaced, and the log names what was
                // lost. (Deploy is not a destructive one-click - the board is visible
                // on the trap strip before you commit, and nothing owned is destroyed.)
                if (array_length(player.traps) >= _tcap) {
                    var _tlost = player.traps[0].name;
                    array_delete(player.traps, 0, 1);
                    array_push(combat_log, "No room - you pull up the " + _tlost + " to make space.");
                }
                // Static stations (M 08-11): the trap claims the first FREE slot
                // and keeps it - deploying another trap never moves this one.
                var _tslot = 0;
                for (var _ts = 0; _ts < _tcap; _ts++) {
                    var _ts_used = false;
                    for (var _te = 0; _te < array_length(player.traps); _te++) {
                        if (trap_slot_of(player.traps[_te], _te) == _ts) { _ts_used = true; break; }
                    }
                    if (!_ts_used) { _tslot = _ts; break; }
                }
                // Talent-web riders are baked into the deployed instance at set
                // time, so the trap on the ground is a complete description of
                // itself and the spring path never has to re-consult the web.
                array_push(player.traps, {
                    name:     _tdf.name,
                    slot:     _tslot,
                    filter:   ability_web_copy_has_rider(ab, "trap_any") ? "any" : _tdf.filter,
                    block:    _tdf.block || ability_web_copy_has_rider(ab, "trap_block"),
                    damage:   _tdf.damage + (ability_web_copy_has_rider(ab, "trap_dmg") ? 6 : 0),
                    dtype:    _tdf.dtype,
                    status:   _tdf.status,
                    duration: _tdf.duration + (ability_web_copy_has_rider(ab, "trap_dur") ? 1 : 0),
                    charges:  _tdf.charges + (ability_web_copy_has_rider(ab, "trap_charge") ? 1 : 0),
                    r_vuln:   ability_web_copy_has_rider(ab, "trap_vuln"),
                    r_stun:   ability_web_copy_has_rider(ab, "trap_stun"),
                    r_splash: ability_web_copy_has_rider(ab, "trap_splash"),
                    r_reset:   ability_web_copy_has_rider(ab, "trap_reset"),
                    r_patient: ability_web_copy_has_rider(ab, "trap_patient"),
                    deployed_round: combat_state.round,
                    flash:    0
                });
                // Throw arc (P5): the prop flies from the player's hands to its
                // station - a draw-owned transient (ui_draw_trap_field advances
                // and clears it, the checkout-VFX idiom). Purely conveyance.
                global.trap_throw = { name: _tdf.name, slot: _tslot, t: 0, tmax: 22 };
                // "any" filter gets its own phrasing (M 08-11: "waits for the
                // next any action" read as jank).
                array_push(combat_log, (_tdf.filter == "any")
                    ? (ab.name + " is set - the next enemy action of any kind will spring it.")
                    : (ab.name + " is set - it waits for the next " + trap_filter_label(_tdf.filter) + "."));

                // Sprung Steel trunk node: deploying a trap returns 1 Prep. Moved here
                // from the old targeted-resolution site, which traps no longer reach.
                if (player.class_id == 2 && variable_struct_exists(player, "preparation")
                    && trunk_has("prep_trap_refund")) {
                    player.preparation = min(player.preparation_max, player.preparation + 1);
                    array_push(combat_log, "Sprung Steel: the trap resets itself - +1 Prep.");
                }
                tutorial_try_show("traps_deployed");
                // snd_equip is the closest thing to a mechanism being seated; a
                // bespoke trap-set SFX belongs in the audio pass, not invented here.
                audio_play_sound(snd_equip, 1, false);
            }

            // ---- SUMMON CAST (class pass, M 08-13) ----
            // Self-targeted like traps: nothing resolves downstream - the summon
            // takes the field and waits. One at a time: casting a DIFFERENT
            // summon replaces the old one (it crumbles unspent, named in the
            // log - same non-destructive-one-click reasoning as the trap slots).
            // The detonate press for the STANDING summon is intercepted earlier.
            if (ab.effect_type == "summon") {
                if (variable_struct_exists(player, "summon") && is_struct(player.summon)) {
                    array_push(combat_log, "The " + player.summon.name + " crumbles as its replacement rises.");
                }
                var _smk = "golem";
                if (ab.name == "Warding Effigy") _smk = "effigy";
                if (ab.name == "Static Husk")    _smk = "husk";
                // Reads the RESOLVED copy so talent-web value/duration nodes feed
                // the construct (power = detonate dmg / hits / crit by kind).
                player.summon = {
                    name:  ab.name,
                    kind:  _smk,
                    turns: max(1, ab.effect_duration),
                    power: ab.effect_value,
                    hits:  (_smk == "effigy") ? max(1, ab.effect_value) : 1
                };
                array_push(combat_log, (_smk == "golem")
                    ? "A MAGMA GOLEM heaves itself out of the floor - it will eat one blow, or ERUPT on your command."
                    : ((_smk == "effigy")
                        ? "A WARDING EFFIGY takes the field - it will absorb the next 2 hits meant for you."
                        : "A STATIC HUSK rises, humming - your Shock and Arcane casts crit harder while it stands."));
                array_push(vfx_bursts, { spr: (_smk == "golem") ? spr_vfx_fire : ((_smk == "husk") ? spr_vfx_shock : spr_vfx_arcane),
                                         x: 640, y: 600, timer: 20, timer_max: 20,
                                         school: (_smk == "golem") ? "fire" : ((_smk == "husk") ? "shock" : "arcane") });
                audio_play_sound(snd_equip, 1, false);
                // The cooldown starts NOW - the detonate press bypasses it.
                if (variable_struct_exists(player, "ability_cd")
                    && selected_ability < array_length(player.ability_cd)) {
                    player.ability_cd[selected_ability] = ability_cooldown(ab);
                }
            }

            // Smoke Bomb self-cover (D§3 rework, M-approved 07-09): the smoke hides
            // YOU too - +15 dodge for the blind's duration (combat_smoke_dodge).
            if (ab.name == "Smoke Bomb") {
                player.smoke_dodge_turns = ab.effect_duration;
                array_push(combat_log, "The smoke cloaks you too - +15% dodge while it lingers.");
                // "Acrid Haze" web node (P3, 07-29): the smoke also WEAKENS every
                // enemy inside it (-15% damage for the blind's duration).
                // "Choking Cloud" keystone (P3): enemies caught in it lose their
                // planned move - their intent is wiped and rerolled as a plain swing.
                var _smk_weaken   = ability_web_copy_has_rider(ab, "smoke_weaken");
                var _smk_confound = ability_web_copy_has_rider(ab, "smoke_confound");
                if (_smk_weaken || _smk_confound) {
                    var _smk_hit = 0;
                    for (var _smi = 0; _smi < array_length(combat_state.combatants); _smi++) {
                        var _smc = combat_state.combatants[_smi];
                        if (_smc.is_player || _smc.is_defeated) continue;
                        if (_smk_weaken && variable_struct_exists(_smc, "status_effects")) {
                            array_push(_smc.status_effects, {
                                name: "Acrid Haze", effect_type: "debuff", kind: "weaken",
                                effect_value: 0.15, duration: max(1, ab.effect_duration),
                                element: "", source: "player"
                            });
                        }
                        if (_smk_confound && variable_struct_exists(_smc, "intent") && _smc.intent != undefined
                            && _smc.intent.eab != undefined) {
                            _smc.intent.eab = undefined;   // the planned move is lost in the smoke
                            _smk_hit++;
                        }
                    }
                    if (_smk_weaken)         array_push(combat_log, "Acrid Haze - everything in the smoke swings 15% softer.");
                    if (_smk_confound && _smk_hit > 0) array_push(combat_log, "Choking Cloud - " + string(_smk_hit) + " foe" + ((_smk_hit == 1) ? " loses" : "s lose") + " their planned move in the smoke!");
                }
            }

            if (!ab.self_targeted) {
                // --- Build the target list ---
                // AoE abilities resolve against every living enemy; Focused Power
                // converts an AoE into a single hard-hitting strike on the selection.
                // Call of the Void "Spreading Dark" keystone (08-17): the single-target
                // call becomes a 2-3 target call, each rolling its own debuff.
                var _cv_spread = (ab.name == "Call of the Void") && ability_web_copy_has_rider(ab, "void_spread");
                var _is_aoe = ((variable_struct_exists(ab, "is_aoe") && ab.is_aoe) || _cv_spread)
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
                    if (_cv_spread && array_length(_targets) > 2) {
                        // 2-3 of the living enemies, shuffled - the selected target always
                        // stays in the call so the player's aim still matters.
                        var _cv_keep = min(array_length(_targets), choose(2, 3));
                        _targets = array_shuffle(_targets);
                        var _cv_sel = undefined, _cv_li = 0;
                        for (var _cvi = 0; _cvi < array_length(combat_state.combatants); _cvi++) {
                            var _cvc = combat_state.combatants[_cvi];
                            if (_cvc.is_player || _cvc.is_defeated) continue;
                            if (_cv_li == selected_target) { _cv_sel = _cvc; break; }
                            _cv_li++;
                        }
                        var _cv_out = [];
                        if (_cv_sel != undefined) array_push(_cv_out, _cv_sel);
                        for (var _cvj = 0; _cvj < array_length(_targets) && array_length(_cv_out) < _cv_keep; _cvj++) {
                            if (_targets[_cvj] != _cv_sel) array_push(_cv_out, _targets[_cvj]);
                        }
                        _targets = _cv_out;
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
                    // All enemies already down - victory check will fire next frame
                    array_push(combat_log, ab.name + " found no target.");

                } else {
                  // Echo aspect rune: the first AoE each combat echoes for 50% to every
                  // enemy hit. Evaluated once for the whole AoE; consumed after the loop.
                  var _echo_now = _is_aoe && rune_aspect_socketed("echo")
                                  && variable_struct_exists(player, "rune_first_aoe_used")
                                  && !player.rune_first_aoe_used;

                  // Void Scepter (class weapon): a spell crit refunds 1 AP - once per cast,
                  // even if an AoE crits multiple targets.
                  var _scepter_refunded = false;

                  // Duelist boon V2 (Shrine 07-29): crits restore 1 class resource -
                  // once per cast (same guard shape as the Scepter, so AoE crits
                  // can't fountain resources).
                  var _duelist_refunded = false;

                  // Whetstone Echo blessing (Shrine V2): the FIRST damaging ability
                  // each combat echoes at 40% power on everything it hit. Evaluated
                  // once for the cast; consumed after the loop only if it fired.
                  var _whet_now = boon_active("whetecho")
                                  && variable_struct_exists(player, "whet_echo_used")
                                  && !player.whet_echo_used;
                  var _whet_fired = false;

                  // Resolve the ability against each target independently.
                  for (var _tgi = 0; _tgi < array_length(_targets); _tgi++) {
                    var target = _targets[_tgi];

                    // Reach-appropriate weapon contributions for this ability (set in the
                    // weapon-damage block below). Both are applied as SEPARATE, TRULY-FLAT
                    // components after the crit roll (never crit-scaled) so weapons stay the
                    // damage FLOOR, not another multiplier (SYSTEMS_WEAPON_ROLES.md §B/§C):
                    //  _wpn_flat = the weapon's flat damage. Martial weapons deal it as
                    //              PHYSICAL (its own type, regardless of the ability's type);
                    //              caster ranged weapons (wands - _wpn_school != "") deal it
                    //              as their rolled SCHOOL, resolved as elemental.
                    //  _elem_aff = the elemental affix (its own element + setup status).
                    var _wpn_flat   = 0;
                    var _wpn_school = "";
                    var _elem_aff   = undefined;

                    // ===== Detonation reactions (P1, SYSTEMS_VIABILITY_PASS.md) =====
                    // A detonator ability reacts with the target's strongest status. Burn/Stun
                    // resolve through the crit roll (below), Blind through the hit roll; the rest
                    // (damage mods / poison->mortality / void lifesteal / consume) resolve later.
                    // 07-16 combo batch: the list lives in ability_is_detonator (adds Rupture,
                    // Bonebreaker, and Rift - Rift being AoE makes this per-target pick THE
                    // cascade: every enemy's own status detonates individually).
                    // EVENT HORIZON (M-locked 08-15): the ultimate skips the single
                    // pick - it gathers EVERY distinct reaction key on this target
                    // (_eh_keys) and fires them ALL through the same sites below,
                    // then strips the target of every status after the hit.
                    var _is_eh   = (ab.name == "Event Horizon");
                    var _eh_keys = _is_eh ? combat_detonator_keys_all(target) : [];
                    var _detonator = (ab.base_damage > 0 && ability_is_detonator(ab) && !_is_eh);
                    var _react           = _detonator ? combat_detonator_pick(target) : { key: "", idx: -1 };
                    var _react_key       = _react.key;
                    // Hexed (Curse rework, audit §6): a detonation on a hexed target has its
                    // numeric bonus DOUBLED, and (post-damage) spreads +2 dmg-taken to every
                    // other living enemy. The hex itself is a 3-turn window, not consumed.
                    var _hexed    = ((_react_key != "" || array_length(_eh_keys) > 0)
                                     && combat_status_total(target, "hexed") > 0);
                    var _hex_mult = _hexed ? 2 : 1;
                    if (_hexed) array_push(combat_log, "Hexed! The reaction is doubled!");
                    var _react_crit_bonus = 0;      // fed into the crit roll
                    var _react_force_hit  = false;  // Blind reaction: cannot miss
                    switch (_react_key) {
                        case "burn":  _react_crit_bonus = 40 * _hex_mult;  break;   // +40% crit chance (+80% hexed)
                        case "stun":  _react_crit_bonus = 999; break;   // guaranteed crit
                        case "blind": _react_force_hit  = true; break;
                    }
                    // Event Horizon cascade - roll-time reactions, all at once.
                    if (array_length(_eh_keys) > 0) {
                        if (combat_keys_has(_eh_keys, "burn")) _react_crit_bonus += 40 * _hex_mult;
                        if (combat_keys_has(_eh_keys, "stun")) _react_crit_bonus = 999;
                        if (combat_keys_has(_eh_keys, "blind")) _react_force_hit = true;
                    }
                    // Shock reaction (§C): arcs to other enemies post-damage; against a LONE
                    // foe (no other living enemy) it instead empowers this hit with +25% crit.
                    if (_react_key == "shock" || combat_keys_has(_eh_keys, "shock")) {
                        var _shock_has_others = false;
                        for (var _shi = 0; _shi < array_length(combat_state.combatants); _shi++) {
                            var _shc = combat_state.combatants[_shi];
                            if (!_shc.is_player && !_shc.is_defeated && _shc != target) { _shock_has_others = true; break; }
                        }
                        if (!_shock_has_others) _react_crit_bonus += 25 * _hex_mult;
                    }

                    // --- Hit roll ---
                    // Blind on the caster lowers accuracy (percentage points).
                    // Hunter aspect rune adds accuracy to ranged actions.
                    // Measured Breathing trunk node (P2, 08-05): +2 accuracy per Prep held.
                    var _trk_acc = (player.class_id == 2 && variable_struct_exists(player, "preparation")
                                    && trunk_has("prep_acc")) ? 2 * player.preparation : 0;
                    var _cast_acc = ab.base_acc - combat_status_max(player, "blind") * 100
                                    + rune_aspect_ranged_acc(ab) + _trk_acc;
                    // Inevitable Arcana trunk node (P2, 08-05): at 5+ Souls, spells cannot miss.
                    var _trk_sure = (player.class_id == 0 && variable_struct_exists(player, "souls")
                                     && player.souls >= 5 && ability_class_is_spell(ability_attack_class(ab))
                                     && trunk_has("soul_sure"));
                    var _hit = combat_roll_hit(
                        _cast_acc + player.acc,
                        target.dodge,
                        ab.guaranteed_hit || _react_force_hit || _trk_sure
                    );

                    if (_hit != "hit") {
                        // AoE misses name the target too, so every enemy gets a line (#21).
                        array_push(combat_log, (_hit == "dodge")
                            ? (target.name + " dodged " + ab.name + "!")
                            : (ab.name + " missed" + (_is_aoe ? (" " + target.name) : "") + "!"));
                        play_sfx_var("snd_miss", -1);   // whiff (silent until imported)
                        // Conveyance (08-04): the defender visibly SIDESTEPS on a dodge,
                        // and the verdict floats at the foe (it was log-only before).
                        var _ms_slot = 0;
                        for (var _msi = 0; _msi < array_length(combat_state.combatants); _msi++) {
                            if (combat_state.combatants[_msi] == target) break;
                            if (!combat_state.combatants[_msi].is_player) _ms_slot++;
                        }
                        if (_hit == "dodge") target.dodge_anim = 14;
                        var _ms_a = combat_enemy_anchor(target, _ms_slot);   // 2.5D: over the creature
                        array_push(damage_popups, { value: 0, text: (_hit == "dodge") ? "DODGED!" : "MISS!",
                            x: _ms_a.x, y: _ms_a.y - 105,
                            timer: 40, col: make_color_rgb(200, 205, 220) });

                    } else {
                        // --- Crit roll (skip for abilities with no crit) ---
                        var _crit_result = { critted: false, multiplier: 1.0,
                                             bonus_el_stacks: 0, effect_quality: 0 };
                        if (ab.crit_type != -1) {
                            // Surge aspect rune + Duelist boon add crit chance.
                            var _wpn_crit = (variable_struct_exists(player, "weapon_crit_bonus")) ? player.weapon_crit_bonus : 0;
                            // Shadow Meld (audit §6 rework): a primed dodge guarantees the crit on
                            // the next DAMAGING attack, then is spent (first target of an AoE).
                            var _sm_crit = variable_struct_exists(player, "shadow_meld_crit")
                                           && player.shadow_meld_crit && ab.base_damage > 0;
                            if (_sm_crit) {
                                player.shadow_meld_crit = false;
                                array_push(combat_log, "Shadow Meld: strike from the shadows - guaranteed crit!");
                            }
                            // Longshot's Memory (07-28 legendary): the FIRST damaging
                            // hit each combat is a guaranteed crit (same 999 idiom).
                            var _ls_crit = variable_struct_exists(player, "leg_longshot")
                                           && player.leg_longshot && !player.leg_longshot_used
                                           && ab.base_damage > 0;
                            if (_ls_crit) {
                                player.leg_longshot_used = true;
                                array_push(combat_log, "Longshot's Memory: it has made this shot before - guaranteed crit!");
                            }
                            // Patient Opener trunk node (P2, 08-05): the first ATTACK each
                            // combat thrown from 2+ Prep auto-crits (same 999 idiom).
                            var _po_crit = (player.class_id == 2 && ab.base_damage > 0
                                            && variable_struct_exists(player, "preparation") && player.preparation >= 2
                                            && !variable_struct_exists(player, "trunk_opener_done")
                                            && !ability_class_is_spell(ability_attack_class(ab))
                                            && trunk_has("prep_first_crit"));
                            if (_po_crit) {
                                player.trunk_opener_done = true;
                                array_push(combat_log, "Patient Opener: rehearsed a hundred times - guaranteed crit!");
                            }
                            // Soul-Lit Focus trunk node (P2, 08-05): +2% spell crit per Soul held.
                            var _slf_crit = (player.class_id == 0 && variable_struct_exists(player, "souls")
                                             && ability_class_is_spell(ability_attack_class(ab))
                                             && trunk_has("soul_crit")) ? 2 * player.souls : 0;
                            // Patient Strike / Overhead (mire_heron / canopy_shrew innates,
                            // 08-06): situational PHYS crit (Power/Precision rolls only).
                            // Patient: a whole turn spent holding still; Overhead: the
                            // target is below half HP and the drop line is open.
                            var _inn_crit = 0;
                            if (ab.crit_type <= 1) {
                                if (pet_active_innate("patient_crit") > 0
                                    && variable_struct_exists(player, "spent_no_ap_last_turn")
                                    && player.spent_no_ap_last_turn) {
                                    _inn_crit += pet_active_innate("patient_crit");
                                }
                                if (pet_active_innate("crit_low") > 0
                                    && target.max_HP > 0 && target.HP < target.max_HP * 0.5) {
                                    _inn_crit += pet_active_innate("crit_low");
                                }
                            }
                            // STATIC HUSK standing charge (class pass 08-13): while it
                            // stands, Shock and Arcane casts crit harder (base +15,
                            // web value nodes can raise it).
                            if (variable_struct_exists(player, "summon") && is_struct(player.summon)
                                && player.summon.kind == "husk") {
                                var _hk_sch = ability_school(ab);
                                if (_hk_sch == "shock" || _hk_sch == "arcane") {
                                    _inn_crit += variable_struct_exists(player.summon, "power")
                                               ? player.summon.power : 15;
                                }
                            }
                            _crit_result = combat_roll_crit(
                                player.stats,
                                ab.base_crit + rune_aspect_spell_crit(ab) + boon_value("duelist") + _wpn_crit + _react_crit_bonus
                                    + _slf_crit + _inn_crit
                                    + ((_sm_crit || _ls_crit || _po_crit) ? 999 : 0),
                                ab.crit_type
                            );
                            // Cruor Feast trunk node (P2, 08-05): your crits also feed the engine.
                            if (_crit_result.critted && player.class_id == 1
                                && variable_struct_exists(player, "blood") && trunk_has("blood_on_crit")) {
                                player.blood = min(player.blood_max, player.blood + 1);
                            }
                            // Shadow Meld potency ranks (POTENCY V2): meld-guaranteed crits
                            // cut deeper - +10% crit damage per rank.
                            if (_sm_crit && _crit_result.critted) {
                                _crit_result.multiplier += 0.10 * trait_potency_r14("Shadow Meld");
                            }
                        }

                        // --- Damage calculation ---
                        // Pure-debuff / utility abilities define base_damage 0 (e.g. Marked for
                        // Death, Curse) - they apply a status and deal NO direct
                        // damage. _deals_damage gates the damage riders, popup and log below so
                        // they never "carry" a damage number (was picking up the target's own
                        // Vulnerable bonus and reporting 0-12 phantom damage).
                        // WEAPON SHOT conditional element (M-locked 08-15): with a
                        // CASTER ranged weapon (wand/scepter/staff = wpn_school set)
                        // the shot fires as that school's ELEMENTAL damage - resolved
                        // vs wards, crits as a spell, flies the school's colored bolt.
                        // With a bow it stays the physical arrow. Per-cast clone so
                        // the loadout's resolved copy is never mutated.
                        if (ab.name == "Weapon Shot"
                            && variable_struct_exists(player, "derived")
                            && variable_struct_exists(player.derived, "ranged_school")
                            && player.derived.ranged_school != "") {
                            ab = variable_clone(ab, 1);
                            ab.damage_type = 1;
                            ab.school      = player.derived.ranged_school;
                        }
                        var _dmg = ab.base_damage;
                        var _deals_damage = (ab.base_damage > 0);
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
                            // Reach-gated weapon contributions: the melee weapon feeds melee
                            // abilities, the ranged weapon feeds ranged abilities (attacks AND
                            // spells) - captured here, applied as flat post-crit components
                            // below. Self-targeted abilities are "none" and get nothing.
                            if (variable_struct_exists(player.derived, "melee_dmg_bonus")) {
                                var _reach_ac = ability_attack_class(ab);
                                if (ability_class_is_melee(_reach_ac)) {
                                    _wpn_flat = player.derived.melee_dmg_bonus;
                                    if (variable_struct_exists(player.derived, "melee_elem")) _elem_aff = player.derived.melee_elem;
                                } else if (ability_class_is_ranged(_reach_ac)) {
                                    _wpn_flat = player.derived.ranged_dmg_bonus;
                                    if (variable_struct_exists(player.derived, "ranged_school")) _wpn_school = player.derived.ranged_school;
                                    if (variable_struct_exists(player.derived, "ranged_elem")) _elem_aff = player.derived.ranged_elem;
                                }
                                // WEAPON STRIKES (M-locked 08-13): the strike
                                // channels the WHOLE weapon - its flat damage
                                // joins a second time HERE, pre-crit, so crits
                                // amplify the craft. The post-crit floor below
                                // still applies like every other ability.
                                if (ab.name == "Weapon Strike" || ab.name == "Weapon Shot") _dmg += _wpn_flat;
                            }
                        }

                        // --- Expansion ability damage riders (pre-crit so they scale) ---
                        // Arcane Echo: scales with Souls held after paying its cost.
                        if (ab.name == "Arcane Echo" && variable_struct_exists(player, "souls")) {
                            _dmg += player.souls * 4;
                        }
                        // Bulwark Slam (07-17): consume your ENTIRE shield and add its value
                        // to the hit (the +8 base is on the ability). Pre-crit so the whole
                        // blow crits together. Zeroes the Poise tracker too so it can't
                        // double-expire a shield that's already been spent.
                        if (ab.name == "Bulwark Slam") {
                            var _bs_sh = variable_struct_exists(player, "shield_hp") ? player.shield_hp : 0;
                            if (_bs_sh > 0) {
                                _dmg += _bs_sh;
                                player.shield_hp = 0;
                                if (variable_struct_exists(player, "poise_shield")) player.poise_shield = 0;
                                array_push(combat_log, "Bulwark Slam spends the whole ward - +" + string(_bs_sh) + " damage!");
                            }
                        }
                        // Killing Spree: bonus per debuff / trap / mark on the target (07-17: +5, unified).
                        if (ab.name == "Killing Spree" && variable_struct_exists(target, "status_effects")) {
                            _dmg += array_length(target.status_effects) * 5;
                        }
                        // Vanish: the empowered strike out of stealth deals bonus damage.
                        // Only a real ATTACK spends the ambush bonus - casting a pure debuff
                        // (Marked for Death etc.) leaves it intact for your next damaging strike.
                        var _vanish_fired = false;
                        if (_deals_damage && variable_struct_exists(player, "vanish_bonus") && player.vanish_bonus) {
                            // "Deeper Shadow" web node (P3): +18 instead of +12.
                            var _van_amt = variable_struct_exists(player, "vanish_bonus_amt") ? player.vanish_bonus_amt : 12;
                            _dmg += _van_amt;
                            player.vanish_bonus = false;
                            _vanish_fired = true;
                            array_push(combat_log, "Vanish: ambush strike for +" + string(_van_amt) + " damage!");
                        }
                        // Detonation reaction - pre-crit damage component (replaces the old flat
                        // Snipe +20). Burn/Stun resolve via the crit roll above; Blind via the hit
                        // roll; Poison/Void/consume resolve post-damage. (P1)
                        if (_react_key == "root" || _react_key == "frost") {
                            _dmg = round(_dmg * (1 + 0.30 * _hex_mult));
                            array_push(combat_log, ab.name + " shatters a held foe (+" + string(30 * _hex_mult) + "% damage)!");
                        } else if (_react_key == "weaken") {
                            _dmg = round(_dmg * (1 + 0.15 * _hex_mult));
                        } else if (_react_key == "vulnerable") {
                            _dmg += 12 * _hex_mult;
                        } else if (_react_key == "bleed") {
                            var _react_bt = 0;
                            for (var _rbi = 0; _rbi < array_length(target.status_effects); _rbi++) {
                                var _rbse = target.status_effects[_rbi];
                                if (variable_struct_exists(_rbse, "kind") && _rbse.kind == "dot"
                                    && combat_status_element(_rbse) == "bleed") {
                                    _react_bt += variable_struct_exists(_rbse, "duration") ? _rbse.duration : 0;
                                }
                            }
                            if (_react_bt > 0) {
                                _dmg += _react_bt * 5 * _hex_mult;
                                array_push(combat_log, ab.name + " detonates bleed (+" + string(_react_bt * 5 * _hex_mult) + ")!");
                            }
                        }
                        // Event Horizon cascade - pre-crit damage reactions, all at
                        // once (same values as the single-pick chain above).
                        if (array_length(_eh_keys) > 0) {
                            if (combat_keys_has(_eh_keys, "root") || combat_keys_has(_eh_keys, "frost")) {
                                _dmg = round(_dmg * (1 + 0.30 * _hex_mult));
                                array_push(combat_log, ab.name + " shatters a held foe (+" + string(30 * _hex_mult) + "% damage)!");
                            }
                            if (combat_keys_has(_eh_keys, "weaken")) _dmg = round(_dmg * (1 + 0.15 * _hex_mult));
                            if (combat_keys_has(_eh_keys, "vulnerable")) _dmg += 12 * _hex_mult;
                            if (combat_keys_has(_eh_keys, "bleed")) {
                                var _eh_bt = 0;
                                for (var _ehb = 0; _ehb < array_length(target.status_effects); _ehb++) {
                                    var _ehbs = target.status_effects[_ehb];
                                    if (variable_struct_exists(_ehbs, "kind") && _ehbs.kind == "dot"
                                        && combat_status_element(_ehbs) == "bleed") {
                                        _eh_bt += variable_struct_exists(_ehbs, "duration") ? _ehbs.duration : 0;
                                    }
                                }
                                if (_eh_bt > 0) {
                                    _dmg += _eh_bt * 5 * _hex_mult;
                                    array_push(combat_log, ab.name + " detonates bleed (+" + string(_eh_bt * 5 * _hex_mult) + ")!");
                                }
                            }
                        }

                        // ===== §3 ability-rework combo riders (pre-crit so they scale) =====
                        // (Arcane Burst's old flat +40%-vs-Exposed is now handled by the unified
                        //  detonation reaction system above - vulnerable -> +12, plus the richer
                        //  element reactions. One consistent mechanic instead of a special case.)
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
                        // Soul Rend (#26 melee kit): consume up to 2 Souls for +8 damage each.
                        if (ab.name == "Soul Rend" && variable_struct_exists(player, "souls")) {
                            var _rend_souls = min(player.souls, 2);
                            if (_rend_souls > 0) {
                                _dmg += _rend_souls * 8;
                                player.souls -= _rend_souls;
                                array_push(combat_log, "Soul Rend consumes " + string(_rend_souls)
                                    + (_rend_souls == 1 ? " Soul" : " Souls") + " (+" + string(_rend_souls * 8) + " dmg)!");
                            }
                        }
                        // Assassinate: execute - DOUBLE damage to a target below 30% HP.
                        if (ab.name == "Assassinate") {
                            var _ass_ratio = (target.max_HP > 0) ? (target.HP / target.max_HP) : 1;
                            if (_ass_ratio < 0.30) {
                                _dmg *= 2;
                                array_push(combat_log, "Assassinate - execute! Double damage.");
                            }
                        }
                        // (Rupture's old bespoke detonate-all-DoTs rider is DELETED - 07-16:
                        //  Rupture is now a true detonator, so the shared Bleed reaction above
                        //  covers the +5/tick burst, and every other status reacts per the
                        //  table: chill shatters, poison spreads Mortality, void heals, etc.)
                        // ===== end §3 combo riders =====

                        // Weaken on the caster reduces outgoing damage (max of stacked debuffs).
                        var _cast_weaken = combat_status_max(player, "weaken");
                        if (_cast_weaken > 0) _dmg = max(1, round(_dmg * (1 - _cast_weaken)));

                        // Flurry: resolve as 3 independent strikes - each rolls crit and is
                        // mitigated separately. Multi-hit identity: strong with crit scaling,
                        // softer vs heavy armor (armor bites each hit). (P2)
                        var _final_dmg;
                        var _bd_mitig_loss  = 0;     // damage eaten by armor/resist (breakdown line)
                        var _bd_dmg_precrit = _dmg;  // pre-crit accumulator (breakdown "Power & bonuses")
                        if (ab.name == "Flurry") {
                            var _fl_each = max(1, round(_dmg / 3));
                            _final_dmg = 0;
                            for (var _fhi = 0; _fhi < 3; _fhi++) {
                                // Include weapon_crit_bonus (Shadow Sickle) - the main roll above
                                // has it, but these per-strike re-rolls dropped it, so Flurry was
                                // the one attack the sickle's "+crit to all rolls" skipped.
                                var _fl_cr  = combat_roll_crit(player.stats,
                                    ab.base_crit + boon_value("duelist") + _react_crit_bonus
                                        + (variable_struct_exists(player, "weapon_crit_bonus") ? player.weapon_crit_bonus : 0),
                                    ab.crit_type);
                                var _fl_hit = _fl_cr.critted ? round(_fl_each * _fl_cr.multiplier) : _fl_each;
                                if (_fl_cr.critted) _crit_result.critted = true; // popup/log flag CRIT if any hit crit
                                _final_dmg += combat_resolve_damage(_fl_hit, ab.damage_type, target.armor, target.el_resist);
                            }
                        } else {
                            // P3 rider (08-01): STR 25 - Snipe drawn on a heavier bow
                            // cuts +15% deeper when it crits.
                            if (_crit_result.critted && ab.name == "Snipe" && ability_stat_rider_active("Snipe")) {
                                _crit_result.multiplier += 0.15;
                            }
                            if (_crit_result.critted) {
                                _dmg = round(_dmg * _crit_result.multiplier);
                            }
                            _final_dmg = combat_resolve_damage(
                                _dmg,
                                ab.damage_type,
                                target.armor,
                                target.el_resist
                            );
                            _bd_mitig_loss = max(0, _dmg - _final_dmg);
                        }

                        // Vulnerable: target takes extra flat damage from every DAMAGING hit
                        // (summed). Pure-debuff abilities (base damage 0) must NOT pick this up -
                        // they only apply their own debuff.
                        var _bd_vuln_flat = 0;   // vulnerable/hexed flat rider (breakdown line)
                        if (_deals_damage) {
                            _bd_vuln_flat = combat_status_total(target, "vulnerable")
                                          + combat_status_total(target, "hexed");   // Hexed keeps Curse's flat dmg-taken
                            _final_dmg += _bd_vuln_flat;
                        }

                        // Scorch firemark: every damaging hit deals bonus TRUE FIRE damage,
                        // routed through the target's elemental resist (real fire, unlike the
                        // typeless vulnerable bonus above). Summed across stacked marks.
                        if (_deals_damage) {
                            var _firemark = combat_status_total(target, "firemark");
                            if (_firemark > 0) {
                                var _fire_bonus = combat_resolve_damage(_firemark, 1, target.armor, target.el_resist);
                                if (_fire_bonus > 0) {
                                    _final_dmg += _fire_bonus;
                                    array_push(combat_log, target.name + " takes +" + string(_fire_bonus) + " fire damage (Searing)!");
                                }
                            }
                        }

                        // Arcane Surge: 3-AP (committed-cast) abilities deal +25% damage (Arcanist
                        // only). Audit fix 2026-07-03: was >= 4, which no ability costs - a no-op.
                        // TRANSCEND "Overchannel" (POTENCY V2): a critting 3-AP cast refunds 1 AP
                        // (once per cast - this block runs per cast, not per splash target).
                        if (player.class_id == 0 && trait_active("Arcane Surge")
                            && variable_struct_exists(ab, "energy_cost") && ab.energy_cost >= 3) {
                            _final_dmg = floor(_final_dmg * (1 + 0.25 * trait_potency_mult("Arcane Surge")));
                            if (trait_transcended("Arcane Surge") && _crit_result.critted) {
                                player.energy += 1;
                                array_push(combat_log, "Overchannel: the surge snaps back - 1 AP refunded!");
                            }
                        }
                        // Soul Engine (D§4, M-approved 07-09): the lit engine adds +3 flat
                        // to SPELLS per full turn elapsed since ignition (combat-long).
                        // Mirrored in combat_estimate_hit so the preview shows it.
                        if (variable_struct_exists(player, "soul_engine_active") && player.soul_engine_active
                            && ability_class_is_spell(ability_attack_class(ab))) {
                            _final_dmg += 3 * max(0, combat_state.round - player.soul_engine_round);
                        }
                        // Warpath (07-16 combo batch): the Bloodwarden ramp - physical and
                        // Blood abilities gain +2 per FULL turn elapsed since the march began.
                        // Mirrored in combat_estimate_hit so the preview shows it.
                        if (variable_struct_exists(player, "warpath_active") && player.warpath_active
                            && _deals_damage && (ab.damage_type == 0 || ab.damage_type == 3)) {
                            var _wp_rate = variable_struct_exists(player, "warpath_rate") ? player.warpath_rate : 2;
                            _final_dmg += _wp_rate * max(0, combat_state.round - player.warpath_round);
                        }
                        // Compounding Dread (07-16): accumulated trap bonus - flat, post-crit,
                        // mirrored in combat_estimate_hit. The +4 increments after each trap
                        // cast below (so the first trap after lighting it gets +0).
                        if (variable_struct_exists(player, "dread_bonus") && player.dread_bonus > 0
                            && (ab.name == "Bear Trap" || ab.name == "Spike Trap" || ab.name == "Death Snare")) {
                            _final_dmg += player.dread_bonus;
                            array_push(combat_log, "Compounding Dread: +" + string(player.dread_bonus) + " trap damage!");
                        }
                        // OVERCHARGE resolution (07-16, M-approved): a spender cast at a FULL
                        // reserve drains everything left on its first landed hit - +2 damage
                        // per point drained. Armed at the spend (after the printed cost);
                        // resolves AFTER Soul Nova / Soul Rend's own consumption so their
                        // better per-point rates apply first. Once per cast (first AoE target).
                        if (variable_struct_exists(player, "overcharge_armed") && player.overcharge_armed && _deals_damage) {
                            var _oc_pts = 0;
                            if      (variable_struct_exists(player, "souls"))       { _oc_pts = player.souls;       player.souls = 0; }
                            else if (variable_struct_exists(player, "blood"))       { _oc_pts = player.blood;       player.blood = 0; }
                            else if (variable_struct_exists(player, "preparation")) { _oc_pts = player.preparation; player.preparation = 0; }
                            player.overcharge_armed = false;
                            if (_oc_pts > 0) {
                                // Crownfire Diadem (07-28 legendary; buffed 07-29 M pass -
                                // +3 was outdamaged by any +5-dmg basic item): the drain
                                // pays +4 damage per point instead of +2.
                                var _oc_rate = (variable_struct_exists(player, "leg_diadem") && player.leg_diadem) ? 4 : 2;
                                _final_dmg += _oc_pts * _oc_rate;
                                player.overcharge_hit_pts  = _oc_pts;                 // read by the splash sequence below
                                player.overcharge_hit_dmg  = _oc_pts * _oc_rate;     // read by the popup
                                array_push(combat_log, "OVERCHARGE! The reserve empties into the blow - +" + string(_oc_pts * _oc_rate) + " damage!");
                            }
                        }
                        // Berserker Rage: below 40% HP deal +20% damage (Bloodwarden only).
                        // TRANSCEND "Blood Frenzy" (POTENCY V2): threshold rises to 60%.
                        if (player.class_id == 1 && trait_active("Berserker Rage")
                            && player.HP <= floor(player.max_HP * (trait_transcended("Berserker Rage") ? 0.60 : 0.40))) {
                            _final_dmg = floor(_final_dmg * (1 + 0.20 * trait_potency_mult("Berserker Rage")));
                        }
                        // Last Stand fury (POTENCY V2 ranks): +10%/rank after it triggers,
                        // rest of combat. Mirrored in combat_estimate_hit.
                        if (variable_struct_exists(player, "last_stand_fury") && player.last_stand_fury > 0) {
                            _final_dmg = max(1, floor(_final_dmg * (1 + player.last_stand_fury)));
                        }
                        // Expanded Arsenal potency ranks (POTENCY V2): +2% ability damage per
                        // rank. Mirrored in combat_estimate_hit.
                        var _ea_r = trait_potency_r14("Expanded Arsenal");
                        if (_ea_r > 0) {
                            _final_dmg = max(1, floor(_final_dmg * (1 + 0.02 * _ea_r)));
                        }
                        // Scavenger TRANSCEND "Weighted Purse" (POTENCY V2): +1% damage per
                        // 500 gold held, cap +10%. Mirrored in combat_estimate_hit.
                        if (trait_transcended("Scavenger") && global.gold >= 500) {
                            _final_dmg = max(1, floor(_final_dmg * (1 + min(0.10, 0.01 * (global.gold div 500)))));
                        }
                        // Miser's Blade (07-28 legendary; buffed 07-29): +1 flat damage
                        // per 125g held, cap +10. Flat (not %) so it matters most on
                        // cheap pokes.
                        if (variable_struct_exists(player, "leg_miser") && player.leg_miser && _deals_damage) {
                            _final_dmg += min(10, global.gold div 125);
                        }
                        // Duelist's Rebuke (07-28 legendary): the dodge-primed +50%,
                        // consumed by this damaging ability.
                        if (variable_struct_exists(player, "leg_rebuke_primed") && player.leg_rebuke_primed && _deals_damage) {
                            player.leg_rebuke_primed = false;
                            _final_dmg = max(1, floor(_final_dmg * 1.5));
                            array_push(combat_log, "Duelist's Rebuke: the answer lands (+50%)!");
                        }
                        // Ley Tap potency ranks (POTENCY V2): +3%/rank spell damage on
                        // ROUND 1 (the borrowed surge of the opening). Mirrored in estimate.
                        if (player.class_id == 0 && combat_state.round == 1
                            && ability_class_is_spell(ability_attack_class(ab))) {
                            var _lt_r = trait_potency_r14("Ley Tap");
                            if (_lt_r > 0) _final_dmg = max(1, floor(_final_dmg * (1 + 0.03 * _lt_r)));
                        }
                        // Serrated Strikes TRANSCEND "Flaying Edge" (POTENCY V2): a target
                        // already bleeding takes +10% from you (checked before this cast's
                        // own Serrated bleed is pushed below).
                        if (trait_transcended("Serrated Strikes") && _deals_damage
                            && variable_struct_exists(target, "status_effects")) {
                            var _fe_bleeding = false;
                            for (var _fe_i = 0; _fe_i < array_length(target.status_effects); _fe_i++) {
                                var _fe_se = target.status_effects[_fe_i];
                                if (variable_struct_exists(_fe_se, "element") && _fe_se.element == "bleed") { _fe_bleeding = true; break; }
                            }
                            if (_fe_bleeding) {
                                _final_dmg = max(1, floor(_final_dmg * 1.10));
                                array_push(combat_log, "Flaying Edge: the wound tears wider (+10%)!");
                            }
                        }
                        // Heat Sense (ashjaw_lynx innate, 08-06): +N% damage to a target
                        // that is already Burning (any burn-element effect on it).
                        if (pet_active_innate("vs_burning") > 0 && _deals_damage
                            && variable_struct_exists(target, "status_effects")) {
                            var _hs_burning = false;
                            for (var _hs_i = 0; _hs_i < array_length(target.status_effects); _hs_i++) {
                                var _hs_se = target.status_effects[_hs_i];
                                if (variable_struct_exists(_hs_se, "element") && _hs_se.element == "burn") { _hs_burning = true; break; }
                            }
                            if (_hs_burning) {
                                _final_dmg = max(1, floor(_final_dmg * (1 + pet_active_innate("vs_burning") / 100)));
                                array_push(combat_log, "[Companion] Heat Sense finds the char (+"
                                    + string(pet_active_innate("vs_burning")) + "%)!");
                            }
                        }
                        // Banked Heat / Lure (ember_ram / wispfox innates, 08-06): the
                        // FIRST damaging ATTACK each combat carries +N bonus Fire damage
                        // (same attack-not-spell split as Forge Spark below).
                        var _bh_ac = ability_attack_class(ab);
                        if (pet_active_innate("first_fire") > 0 && _deals_damage
                            && (_bh_ac == "melee_attack" || _bh_ac == "ranged_attack")
                            && !variable_struct_exists(player, "innate_fire_done")) {
                            player.innate_fire_done = true;
                            _final_dmg += pet_active_innate("first_fire");
                            array_push(combat_log, "[Companion] " + pet_active().name + "'s banked heat rides the blow (+"
                                + string(pet_active_innate("first_fire")) + " Fire)!");
                        }
                        // Reckoning (tallykeep signature move, 08-06): every 3rd ability
                        // you cast lands +20% - it is keeping count. Counter increments
                        // at the spend commit, so this cast IS the 3rd/6th/9th.
                        if (pet_active_sig_move("reckoning") && _deals_damage
                            && variable_struct_exists(player, "sig_reckon_casts")
                            && player.sig_reckon_casts > 0 && (player.sig_reckon_casts mod 3) == 0) {
                            _final_dmg = max(1, floor(_final_dmg * 1.20));
                            array_push(combat_log, "[Companion] " + pet_active().name + "'s RECKONING - the count comes due (+20%)!");
                        }
                        // Arcane Burst FADING (M 08-18: "should weaken if used 2 turns in a row"):
                        // cast on consecutive player turns -> this one deals 50% damage. The
                        // flag rolls at player-turn start (burst_cast_prev / burst_cast_this),
                        // so a turn's rest between casts restores full power.
                        if (ab.name == "Arcane Burst" && _deals_damage) {
                            if (variable_struct_exists(player, "burst_cast_prev") && player.burst_cast_prev) {
                                _final_dmg = max(1, floor(_final_dmg * 0.5));
                                array_push(combat_log, "Arcane Burst FADES - cast two turns running, it lands at half power.");
                                var _fb_slot = 0;
                                for (var _fbi = 0; _fbi < array_length(combat_state.combatants); _fbi++) {
                                    if (combat_state.combatants[_fbi] == target) break;
                                    if (!combat_state.combatants[_fbi].is_player) _fb_slot++;
                                }
                                var _fb_a = combat_enemy_anchor(target, _fb_slot);
                                array_push(damage_popups, { value: 0, text: "FADED", x: _fb_a.x, y: _fb_a.y - 130,
                                    timer: 40, col: make_color_rgb(170, 150, 220) });
                            }
                        }
                        // Serrated Strikes: physical ATTACKS apply 1 bleed stack (Shadowstrider
                        // only). Gated on _deals_damage so a pure debuff (e.g. Marked for Death,
                        // also physical-typed) doesn't proc a free bleed - it isn't an attack.
                        if (_deals_damage && player.class_id == 2 && trait_active("Serrated Strikes")
                            && variable_struct_exists(ab, "damage_type") && ab.damage_type == 0
                            && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            var _bleed_se = {
                                name:         "Serrated Bleed",
                                effect_type:  "dot",
                                kind:         "dot",
                                effect_value: round(3 * trait_potency_mult("Serrated Strikes")),
                                duration:     2,
                                element:      "bleed",
                                source:       "player"
                            };
                            array_push(target.status_effects, _bleed_se);
                            array_push(combat_log, "Serrated Strikes: bleed applied to " + target.name + "!");
                        }

                        // Forge Spark (cinder_newt signature move, 08-05 pillar D): your
                        // first damaging ATTACK each combat (not a spell - same split as
                        // Serrated Strikes) also sets the target Burning, at the Flaming
                        // weapon affix's rate (3/turn, 2 turns). Once per combat.
                        // Cinderheart (Soulfire keystone, 08-18): the bolt leaves the target Burning.
                        if (ab.name == "Soulfire" && _deals_damage && ability_web_copy_has_rider(ab, "soulfire_burn")
                            && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            array_push(target.status_effects, { name: "Burning", effect_type: "dot", kind: "dot",
                                effect_value: 3, duration: 2, element: "burn", source: "player" });
                            array_push(combat_log, "Cinderheart: " + target.name + " is set BURNING (3/turn, 2 turns).");
                        }
                        var _fs_ac = ability_attack_class(ab);
                        if (_deals_damage && (_fs_ac == "melee_attack" || _fs_ac == "ranged_attack")
                            && pet_active_sig_move("forge_spark")
                            && !variable_struct_exists(player, "sig_spark_done")
                            && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            player.sig_spark_done = true;
                            array_push(target.status_effects, {
                                name:         "Burning",
                                effect_type:  "dot",
                                kind:         "dot",
                                effect_value: 3,
                                duration:     2,
                                element:      "burn",
                                source:       "pet"
                            });
                            array_push(combat_log, "[Companion] " + pet_active().name + "'s FORGE SPARK leaps - " + target.name + " is set ablaze!");
                        }

                        // Blazing Palm Sear rider (M-locked 08-15): the palm
                        // print smolders - same [Fire+] mark Scorch applies.
                        if (ab.name == "Blazing Palm" && _deals_damage
                            && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            array_push(target.status_effects, {
                                name: "Sear", effect_type: "debuff", kind: "firemark",
                                effect_value: 3, duration: 2, element: "fire", source: "player"
                            });
                            array_push(combat_log, "The palm print SEARS - follow-up hits on " + target.name + " burn +3 for 2 turns!");
                        }

                        // --- Class trunk spender riders (P2, 08-05): paying the class
                        // resource stamps the target. Applied per enemy hit (an AoE
                        // spender marks everyone it touches, same as other on-hit riders).
                        if (player.class_id == 0 && ab.secondary_cost > 0 && trunk_has("soul_vuln")
                            && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            array_push(target.status_effects, {
                                name: "Rending Payment", effect_type: "debuff", kind: "vulnerable",
                                effect_value: 2, duration: 1, element: "", source: "player"
                            });
                            array_push(combat_log, "Rending Payment: " + target.name + " is laid Vulnerable!");
                        }
                        if (player.class_id == 1 && ab.secondary_cost > 0 && trunk_has("blood_spend_weaken")
                            && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            array_push(target.status_effects, {
                                name: "Dread Payment", effect_type: "debuff", kind: "weaken",
                                effect_value: 0.20, duration: 1, element: "", source: "player"
                            });
                            array_push(combat_log, "Dread Payment: " + target.name + " is Weakened by the omen!");
                        }

                        // Aspect runes: Ember (elemental), Hemorrhage (blood),
                        // Serration (physical attacks) add an outgoing-damage %.
                        var _aspect_dmg_pct = rune_aspect_damage_pct(ab);
                        if (_aspect_dmg_pct > 0) _final_dmg = round(_final_dmg * (1 + _aspect_dmg_pct));

                        // Boons: Bloodlust / Glass Cannon (+ Executioner vs low-HP targets,
                        // + the V2 Bloodlust below-half ramp and Feast of Crows stacks).
                        var _thf = (target.max_HP > 0) ? (target.HP / target.max_HP) : 1;
                        var _boon_dm = boon_damage_mult(_thf, player);
                        if (_boon_dm != 1.0) _final_dmg = max(1, round(_final_dmg * _boon_dm));

                        // --- Class trunk damage nodes (P2, 08-05) ---
                        // Sanguine Might: +3% damage per Blood held.
                        if (_deals_damage && player.class_id == 1 && variable_struct_exists(player, "blood")
                            && player.blood > 0 && trunk_has("blood_dmg")) {
                            _final_dmg = max(1, round(_final_dmg * (1 + 0.03 * player.blood)));
                        }
                        // Rule of Three: every 3rd spell cast this combat lands +30%
                        // (counter incremented once per cast at the spend site).
                        if (_deals_damage && player.class_id == 0
                            && ability_class_is_spell(ability_attack_class(ab))
                            && variable_struct_exists(player, "trunk_spell_casts")
                            && player.trunk_spell_casts > 0 && (player.trunk_spell_casts mod 3) == 0
                            && trunk_has("soul_third_spell")) {
                            _final_dmg = max(1, round(_final_dmg * 1.30));
                            array_push(combat_log, "Rule of Three: the third word lands harder (+30%)!");
                        }
                        // Finisher's Doctrine: damaging hits deal +30% below 25% HP.
                        if (_deals_damage && player.class_id == 2 && _thf < 0.25
                            && trunk_has("prep_finisher")) {
                            _final_dmg = max(1, round(_final_dmg * 1.30));
                        }
                        // Loaded Springs: traps bite +2 per Prep held (flat, post-mult -
                        // same layer as Compounding Dread).
                        if (_deals_damage && player.class_id == 2
                            && variable_struct_exists(player, "preparation") && player.preparation > 0
                            && (ab.name == "Bear Trap" || ab.name == "Spike Trap" || ab.name == "Death Snare")
                            && trunk_has("prep_trap_dmg")) {
                            _final_dmg += 2 * player.preparation;
                        }
                        // Corruption (Pets §7): pushing a corrupted active pet saps your damage.
                        var _pet_corr_dm = pet_corruption_player_dmg_mult();
                        if (_pet_corr_dm != 1.0) _final_dmg = max(1, round(_final_dmg * _pet_corr_dm));

                        // Focused Power: an AoE funneled to one target hits 50% harder.
                        // POTENCY V2: +10% focus-bonus strength per rank (1.5x -> up to 1.7x);
                        // TRANSCEND "Annihilating Focus" also applies Exposed to the target.
                        if (_focused_burst) {
                            _final_dmg = round(_final_dmg * (1 + 0.5 * trait_potency_mult("Focused Power")));
                            if (trait_transcended("Focused Power") && !target.is_defeated
                                && variable_struct_exists(target, "status_effects")) {
                                array_push(target.status_effects, {
                                    name: "Exposed", effect_type: "debuff", kind: "vulnerable",
                                    effect_value: 2, duration: 2, source: "player"
                                });
                                array_push(combat_log, "Annihilating Focus: " + target.name + " is laid EXPOSED!");
                            }
                        }
                        // AoE falloff (1.0 = full damage to every enemy).
                        if (_is_aoe && _aoe_falloff != 1.0) _final_dmg = max(1, round(_final_dmg * _aoe_falloff));

                        // Class-weapon damage rider: Vaultstone Wand boosts spell damage.
                        var _atk_class = ability_attack_class(ab);
                        if (variable_struct_exists(player, "spell_dmg_bonus") && player.spell_dmg_bonus > 0
                            && ability_class_is_spell(_atk_class)) {
                            _final_dmg = max(1, round(_final_dmg * (1 + player.spell_dmg_bonus)));
                        }

                        // Weapon flat damage: the reach-matched weapon's flat damage, dealt as
                        // a SEPARATE PHYSICAL component (its own type - a melee spell gets it as
                        // flat physical, not the spell's element) and TRULY FLAT (added after the
                        // crit roll, never crit-scaled). Mitigated by armor like any physical
                        // hit, so it's the steady floor of weapon output, not a multiplier. (§B)
                        if (_deals_damage && _wpn_flat > 0) {
                            // Caster ranged weapons (wands) deal this as their rolled
                            // SCHOOL, resolved as elemental (vs el_resist); martial
                            // weapons keep it physical (vs armor).
                            var _wpn_is_school = (_wpn_school != "");
                            var _wpn_hit = combat_resolve_damage(_wpn_flat, _wpn_is_school ? 1 : 0, target.armor, target.el_resist);
                            if (_wpn_hit > 0) {
                                _final_dmg += _wpn_hit;
                                if (_wpn_is_school) {
                                    array_push(combat_log, ab.name + " - " + school_label(_wpn_school) + " weapon damage (+" + string(_wpn_hit) + ")!");
                                }
                            }
                        }

                        // Rider damage layers (07-29 M): weapon/school bonuses still add
                        // into _final_dmg (one total in the log), but each also records a
                        // {amt, col} entry here so the popup site can float it as its OWN
                        // school-colored number beside the base hit.
                        var _rider_pops = [];

                        // Elemental weapon affix (M-locked 08-13 rework: "too many
                        // weapons add elemental damage... imbue effects on almost
                        // every spell"): the affix no longer rides EVERY ability of
                        // the weapon's reach - only true weapon actions (Strike /
                        // Weapon Strike / Weapon Shot) and abilities woven with an
                        // Edge-Carried talent carry it. Resolved vs el_resist as
                        // before; the setup status below honors the same gate.
                        var _elem_ok = (ab.name == "Strike" || ab.name == "Weapon Strike" || ab.name == "Weapon Shot"
                                        || ability_web_copy_has_rider(ab, "edge_carried"));
                        if (!_elem_ok) _elem_aff = undefined;
                        if (_deals_damage && _elem_aff != undefined && _elem_aff.dmg > 0) {
                            var _elem_hit = combat_resolve_damage(_elem_aff.dmg, 1, target.armor, target.el_resist);
                            if (_elem_hit > 0) {
                                _final_dmg += _elem_hit;
                                array_push(_rider_pops, { amt: _elem_hit, col: school_color(elem_element_name(_elem_aff.element)) });
                                array_push(combat_log, ab.name + " - " + school_label(elem_element_name(_elem_aff.element)) + " strike (+" + string(_elem_hit) + ")!");
                            }
                        }

                        // School-damage gear affixes: "+X <school> damage" adds a separate
                        // TRULY-FLAT component to any damaging ability of that school, resolved
                        // once against the ability's OWN mitigation (school is metadata, dtype
                        // governs mitigation). Never crit-scaled. (SYSTEMS_ELEMENT_SCHOOLS.md §C)
                        if (_deals_damage && variable_struct_exists(player.derived, "school_dmg")) {
                            var _sch = ability_school(ab);
                            if (_sch != "" && variable_struct_exists(player.derived.school_dmg, _sch)) {
                                var _sch_bonus = variable_struct_get(player.derived.school_dmg, _sch);
                                if (_sch_bonus > 0) {
                                    var _sch_hit = combat_resolve_damage(_sch_bonus, ab.damage_type, target.armor, target.el_resist);
                                    if (_sch_hit > 0) {
                                        _final_dmg += _sch_hit;
                                        array_push(_rider_pops, { amt: _sch_hit, col: school_color(_sch) });
                                        array_push(combat_log, ab.name + " - " + school_label(_sch) + " damage (+" + string(_sch_hit) + ")!");
                                    }
                                }
                            }
                        }

                        // SCHOOL WEAKNESS (P2, M-approved 08-01): a damaging ability of the
                        // school this enemy is WEAK to hits +30% - and refunds 1 AP, ONCE
                        // PER ENEMY PER COMBAT (flag on the clone; a 4-pack offers up to 4
                        // refunds across the fight, never a per-turn loop). SMT-style: the
                        // glyph beside its intent tag telegraphs it (perfect information).
                        if (_deals_damage && _final_dmg > 0) {
                            var _wk = enemy_weak_school(target.name);
                            if (_wk != "" && _wk == ability_school(ab)) {
                                _final_dmg = round(_final_dmg * 1.30);
                                if (!variable_struct_exists(target, "weak_refunded") || !target.weak_refunded) {
                                    target.weak_refunded = true;
                                    player.energy += 1;
                                    array_push(combat_log, "EXPOSED WEAKNESS! " + school_label(_wk) + " sears " + target.name + " (+30% damage, +1 AP)!");
                                } else {
                                    array_push(combat_log, "Weakness struck - " + school_label(_wk) + " sears " + target.name + " (+30% damage)!");
                                }
                            }
                        }

                        // DUELIST T2 PERFECT PARRY (08-13): an armed guard turns the
                        // next melee blow aside outright - and the riposte answers
                        // it DOUBLE. Spells and ranged shots go around a parry.
                        if (_deals_damage && _final_dmg > 0
                            && variable_struct_exists(target, "parry_armed") && target.parry_armed
                            && ability_class_is_melee(ability_attack_class(ab))) {
                            target.parry_armed = false;
                            _final_dmg = 0;
                            var _pp_rip = 2 * (variable_struct_exists(target, "riposte_dmg") ? target.riposte_dmg : 12);
                            array_push(combat_log, "PERFECT PARRY! The blow is turned - and answered for " + string(_pp_rip) + "!");
                            combat_apply_damage(player, _pp_rip);
                            player.hit_flash = max(player.hit_flash, 10);
                            array_push(damage_popups, { value: _pp_rip, x: 475, y: 545, timer: 40, delay: 10, col: make_color_rgb(230, 140, 100) });
                            if (player.HP <= 0 && !combat_try_last_stand(player, combat_log)) player.is_defeated = true;
                        }
                        // Pure debuffs never deal damage, even if a rider tried to add some.
                        if (_deals_damage) combat_apply_damage(target, _final_dmg);

                        // Gravelstone Sword (class weapon): leech a share of melee damage dealt.
                        if (variable_struct_exists(player, "weapon_lifesteal") && player.weapon_lifesteal > 0
                            && ability_class_is_melee(_atk_class) && _final_dmg > 0) {
                            var _ls = combat_heal_after_mortality(player, max(1, round(_final_dmg * player.weapon_lifesteal)));
                            if (_ls > 0) {
                                player.HP = min(player.max_HP, player.HP + _ls);
                                array_push(combat_log, "Gravelstone Sword - leeched " + string(_ls) + " HP.");
                            }
                        }
                        // ===== Detonation reaction - post-damage (P1) =====
                        // Achievement counter (08-05 wiring): a detonation reaction
                        // fired on this landed hit (ACH_DETONATE_25 via sync).
                        if (_react_key != "" || array_length(_eh_keys) > 0) {
                            ach_counters_init();
                            global.ach_counters.detonations += 1;
                        }
                        if ((_react_key == "void" || combat_keys_has(_eh_keys, "void")) && _final_dmg > 0) {
                            var _react_ls = combat_heal_after_mortality(player, round(_final_dmg * 0.3 * _hex_mult));
                            if (_react_ls > 0) {
                                player.HP = min(player.max_HP, player.HP + _react_ls);
                                array_push(damage_popups, { value: _react_ls, x: 475, y: 545, timer: 45, col: c_lime });
                                array_push(combat_log, ab.name + " siphons " + string(_react_ls) + " HP from the void!");
                            }
                        }
                        if ((_react_key == "poison" || combat_keys_has(_eh_keys, "poison"))
                            && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                            array_push(target.status_effects, {
                                name: "Mortality", effect_type: "debuff", kind: "mortality",
                                effect_value: min(0.8, 0.4 * _hex_mult), duration: 4, element: "", source: "player"
                            });
                            array_push(combat_log, ab.name + " spreads the poison - " + target.name + "'s healing is suppressed!");
                        }
                        // Shock arc (§C): chain ~33% of the hit to every OTHER living enemy.
                        // (If the target was alone, the +25% crit applied above instead.)
                        if ((_react_key == "shock" || combat_keys_has(_eh_keys, "shock")) && _final_dmg > 0) {
                            var _arc_dmg = max(1, round(_final_dmg * 0.33 * _hex_mult));
                            for (var _ari = 0; _ari < array_length(combat_state.combatants); _ari++) {
                                var _arc_c = combat_state.combatants[_ari];
                                if (_arc_c.is_player || _arc_c.is_defeated || _arc_c == target) continue;
                                combat_apply_damage(_arc_c, _arc_dmg);
                                _arc_c.hit_flash = max(_arc_c.hit_flash, 10);
                                array_push(combat_log, ab.name + " arcs to " + _arc_c.name + " (+" + string(_arc_dmg) + ")!");
                                if (_arc_c.HP <= 0) combat_on_enemy_defeated(_arc_c, player, combat_log);
                            }
                        }
                        // Consume the reacted status (poison/bleed/root/frost/burn/shock/void are
                        // spent; stun/vulnerable/weaken/blind persist as ongoing windows).
                        if (_react_key == "bleed" || _react_key == "poison" || _react_key == "void"
                            || _react_key == "root" || _react_key == "frost" || _react_key == "burn"
                            || _react_key == "shock") {
                            var _rk_kept = [];
                            for (var _rci = 0; _rci < array_length(target.status_effects); _rci++) {
                                var _rcs = target.status_effects[_rci];
                                var _rck = variable_struct_exists(_rcs, "kind") ? _rcs.kind : "";
                                var _rce = combat_status_element(_rcs);
                                var _rdrop = false;
                                switch (_react_key) {
                                    case "bleed":  _rdrop = (_rck == "dot" && _rce == "bleed"); break;
                                    case "poison": _rdrop = (_rck == "dot" && _rce == "poison"); break;
                                    case "void":   _rdrop = (_rck == "dot" && _rce == "void"); break;
                                    case "root":   _rdrop = (_rck == "root"); break;
                                    case "frost":  _rdrop = (_rce == "frost"); break;
                                    case "burn":   _rdrop = (_rce == "burn"); break;
                                    case "shock":  _rdrop = (_rce == "shock"); break;
                                }
                                if (!_rdrop) array_push(_rk_kept, _rcs);
                            }
                            target.status_effects = _rk_kept;
                        }
                        // EVENT HORIZON: after every reaction has fired, the horizon
                        // keeps it ALL - the target comes out carrying nothing
                        // (stun/vulnerable/weaken/blind included, unlike the
                        // single-pick consume above). The Mortality the poison
                        // reaction JUST applied is the one thing spared - the wipe
                        // must not eat its own reaction's output. M-locked 08-15.
                        if (_is_eh && array_length(_eh_keys) > 0
                            && variable_struct_exists(target, "status_effects")
                            && array_length(target.status_effects) > 0) {
                            var _eh_kept = [];
                            for (var _ehk = 0; _ehk < array_length(target.status_effects); _ehk++) {
                                var _ehs = target.status_effects[_ehk];
                                if (variable_struct_exists(_ehs, "kind") && _ehs.kind == "mortality") {
                                    array_push(_eh_kept, _ehs);
                                }
                            }
                            array_push(combat_log, "The horizon takes everything - "
                                + target.name + "'s statuses are stripped away.");
                            target.status_effects = _eh_kept;
                        }

                        // Hexed spread: each detonation during the hex window marks every OTHER
                        // living enemy with +2 damage-taken for 2 turns. Re-detonations REFRESH
                        // the mark rather than stacking it, so repeat combos can't snowball.
                        if (_hexed) {
                            var _hx_spread = false;
                            for (var _hxi = 0; _hxi < array_length(combat_state.combatants); _hxi++) {
                                var _hxc = combat_state.combatants[_hxi];
                                if (_hxc.is_player || _hxc.is_defeated || _hxc == target) continue;
                                if (!variable_struct_exists(_hxc, "status_effects")) continue;
                                var _hx_found = false;
                                for (var _hxj = 0; _hxj < array_length(_hxc.status_effects); _hxj++) {
                                    var _hxs = _hxc.status_effects[_hxj];
                                    if (variable_struct_exists(_hxs, "name") && _hxs.name == "Hex Spread") {
                                        _hxs.duration = 2; _hx_found = true; break;
                                    }
                                }
                                if (!_hx_found) array_push(_hxc.status_effects, {
                                    name: "Hex Spread", effect_type: "debuff", kind: "vulnerable",
                                    effect_value: 2, duration: 2, element: "", source: "player"
                                });
                                _hx_spread = true;
                            }
                            if (_hx_spread) array_push(combat_log, "The hex spreads - other enemies take +2 damage per hit!");
                        }

                        // Void Scepter (class weapon): a spell crit refunds 1 AP (once per cast).
                        if (!_scepter_refunded && variable_struct_exists(player, "spell_crit_ap") && player.spell_crit_ap
                            && _crit_result.critted && ability_class_is_spell(_atk_class)) {
                            player.energy += 1;
                            _scepter_refunded = true;
                            array_push(combat_log, "Void Scepter - spell crit restores 1 AP!");
                        }

                        // --- VFX: hit flash, popup, attack slide, screen shake ---
                        // Conveyance (08-04): resolve the DELIVERY first. A projectile
                        // defers the whole hit presentation (flash / shake / popups /
                        // impact burst / recoil / HP-bar drain) to its arrival frame -
                        // the mechanics all resolved above. A killing blow presents
                        // instantly (the foe's sprite is already gone from the row).
                        var _dlv = ability_delivery(ab);
                        var _dlv_delay = (_dlv == "projectile")
                            ? (15 + array_length(combat_projectiles) * 4) : 0;
                        // Death linger (M 08-04: "they die before the spell hits"):
                        // a foe killed by a projectile stays standing until the bolt
                        // LANDS, then fades. The Draw loop owns the fade; here we
                        // just size the linger to the travel time. (Non-projectile
                        // kills get a short lazy-init fade in Draw.)
                        if (target.is_defeated && _dlv == "projectile") {
                            target.death_linger = _dlv_delay + 20;
                        }
                        if (_dlv_delay == 0) {
                            target.hit_flash   = 15;
                            target.hit_recoil  = 10;
                            screen_shake_timer = 8;
                        }
                        var _vfx_slot = 0;
                        for (var _vsi = 0; _vsi < array_length(combat_state.combatants); _vsi++) {
                            if (combat_state.combatants[_vsi] == target) break;
                            if (!combat_state.combatants[_vsi].is_player) _vfx_slot++;
                        }
                        var _vfx_ex = 1620 + _vfx_slot * (-120);
                        var _vfx_ey = 233  + _vfx_slot * 105;
                        // 2.5D (M 08-13: "projectiles go for mob nameplates
                        // sometimes not the mobs"): the flat-row formula above
                        // lands in the HP-bar grid. Aim everything downstream
                        // (bolt, burst, popups, splash labels, melee lunge) at
                        // the foe's stamped visual centre instead.
                        if (combat_25d()) {
                            if (variable_struct_exists(target, "last_ecx")) {
                                _vfx_ex = target.last_ecx;
                                _vfx_ey = target.last_ecy;
                            } else {
                                var _vsp25 = variable_struct_exists(target, "stage_station")
                                           ? target.stage_station : combat_enemy_slot_pos(_vfx_slot);
                                _vfx_ex = _vsp25.cx;
                                _vfx_ey = _vsp25.cy;
                            }
                        }
                        if (_deals_damage) {
                            var _pop_col = (_crit_result.critted) ? c_yellow : make_color_rgb(255, 100, 100);
                            // Base number excludes the rider layers - they float as their
                            // own colored numbers just after (M 07-29: "see the layers
                            // play out"). The log keeps the single combined total.
                            var _pop_base = _final_dmg;
                            for (var _rpi = 0; _rpi < array_length(_rider_pops); _rpi++) _pop_base -= _rider_pops[_rpi].amt;
                            array_push(damage_popups, { value: _pop_base, x: _vfx_ex, y: _vfx_ey - 105, timer: 50, delay: _dlv_delay, col: _pop_col });
                            for (var _rpi = 0; _rpi < array_length(_rider_pops); _rpi++) {
                                array_push(damage_popups, { value: _rider_pops[_rpi].amt, x: _vfx_ex + 64, y: _vfx_ey - 68 - _rpi * 34,
                                    timer: 46, delay: _dlv_delay + 8 + _rpi * 8, col: _rider_pops[_rpi].col });
                            }
                        }
                        // ===== Sequenced combo presentation (07-16, COMBAT_COMBO_PLAN §A3) =====
                        // A detonating hit READS as a sequence: damage number, then the
                        // reaction splash, then the hex splash - staggered popups with a
                        // rising reveal tick (the loot-suite lesson). Damage was resolved
                        // above in one pass; this is presentation only.
                        if (_deals_damage && _react_key != "") {
                            var _cq_lbl = "";
                            var _cq_col = c_white;
                            switch (_react_key) {
                                case "root": case "frost": _cq_lbl = "SHATTER!";     _cq_col = make_color_rgb(140, 210, 255); break;
                                case "bleed":              _cq_lbl = "BLOOD BURST!"; _cq_col = make_color_rgb(235,  80,  80); break;
                                case "stun":               _cq_lbl = "OPENING!";     _cq_col = c_yellow; break;
                                case "burn":               _cq_lbl = "IGNITE!";      _cq_col = make_color_rgb(255, 150,  60); break;
                                case "vulnerable":         _cq_lbl = "EXPOSED!";     _cq_col = make_color_rgb(255, 200,  90); break;
                                case "weaken":             _cq_lbl = "BREAK!";       _cq_col = make_color_rgb(210, 160, 255); break;
                                case "poison":             _cq_lbl = "FESTER!";      _cq_col = make_color_rgb(150, 220,  90); break;
                                case "void":               _cq_lbl = "SIPHON!";      _cq_col = make_color_rgb(190, 120, 255); break;
                                case "shock":              _cq_lbl = "ARC!";         _cq_col = make_color_rgb(120, 200, 255); break;
                                case "blind":              _cq_lbl = "TRUE SHOT!";   _cq_col = make_color_rgb(200, 200, 200); break;
                            }
                            if (_cq_lbl != "") {
                                array_push(damage_popups, { value: 0, text: _cq_lbl, x: _vfx_ex, y: _vfx_ey - 145,
                                    timer: 44, delay: _dlv_delay + 10, col: _cq_col, sfx: snd_loot_reveal, pitch: 1.12 });
                                if (_hexed) {
                                    array_push(damage_popups, { value: 0, text: "HEXED x2!", x: _vfx_ex, y: _vfx_ey - 185,
                                        timer: 44, delay: _dlv_delay + 22, col: make_color_rgb(200, 110, 255), sfx: snd_loot_reveal, pitch: 1.28 });
                                }
                                screen_shake_timer = max(screen_shake_timer, _hexed ? 12 : 10);
                            }
                        }
                        // Overcharge splash rides the same sequence, one step later.
                        // (Popup reads overcharge_hit_dmg so the Crownfire Diadem's
                        // 3-per-point rate shows honestly.)
                        if (_deals_damage && variable_struct_exists(player, "overcharge_hit_pts") && player.overcharge_hit_pts > 0) {
                            var _oc_pop = variable_struct_exists(player, "overcharge_hit_dmg")
                                ? player.overcharge_hit_dmg : player.overcharge_hit_pts * 2;
                            array_push(damage_popups, { value: 0, text: "OVERCHARGE +" + string(_oc_pop) + "!",
                                x: _vfx_ex, y: _vfx_ey - 225, timer: 44, delay: _dlv_delay + 34, col: make_color_rgb(255, 230, 120),
                                sfx: snd_loot_reveal, pitch: 1.4 });
                            player.overcharge_hit_pts = 0;
                        }
                        // Conveyance (08-04): only a MELEE delivery lunges - projectile /
                        // beam / overhead casters hold their ground (spells already flare
                        // via cast_fx_timer at the cast gate).
                        if (_dlv == "melee") {
                            attack_anim_timer     = 20;
                            attack_anim_src_x     = 330;
                            attack_anim_src_y     = 465;
                            attack_anim_dst_x     = _vfx_ex - 90;
                            attack_anim_dst_y     = _vfx_ey;
                            attack_anim_is_player = true;
                        }

                        // VFX impact keyed to the ability's element SCHOOL (bespoke bursts for
                        // frost/shock/poison/blood/shadow, 07-29); physical keeps the impact
                        // burst. See ability_attack_vfx (scr_abilities).
                        // Conveyance (08-04): a projectile CARRIES the burst to arrival; a
                        // beam adds an instant lance under the burst; the rest stay instant.
                        var _vfxp = ability_attack_vfx(ab);
                        // 2.5D: launch from the live player anchor (flat: shipped 505,570).
                        var _prj_sx = 505, _prj_sy = 570;
                        if (combat_25d()) {
                            var _prj_pa = combat_player_vfx_anchor(player);
                            _prj_sx = _prj_pa.x + 210;
                            _prj_sy = _prj_pa.y + 120;
                        }
                        if (_dlv == "projectile") {
                            array_push(combat_projectiles, {
                                spr: ability_projectile_sprite(ab), school: ability_school(ab),
                                impact_spr: _vfxp.spr, ticks: _vfxp.ticks,
                                sx: _prj_sx, sy: _prj_sy, tx: _vfx_ex, ty: _vfx_ey,
                                bx: _vfx_ex, by: _vfx_ey,   // burst anchor (spr_vfx_* are center-origin)
                                t: 0, dur: 15, delay: _dlv_delay - 15, tgt: target, shake: 8,
                                // Bespoke flight renders (Snipe's arrow; Weapon Shot's arrow
                                // only while PHYSICAL - a caster weapon's elemental shot flies
                                // its school bolt instead, M-locked 08-15).
                                aname: (ab.name == "Weapon Shot" && ab.damage_type != 0) ? "" : ab.name,
                                scale: variable_struct_exists(_vfxp, "scale") ? _vfxp.scale : 1   // pacing: finisher bursts bigger
                            });
                            if (_deals_damage) target.hp_hold = _dlv_delay;
                        } else {
                            if (_dlv == "beam") {
                                array_push(combat_beams, { sx: _prj_sx, sy: _prj_sy, tx: _vfx_ex, ty: _vfx_ey,
                                    t: 0, dur: 12, col: school_color(ability_school(ab)),
                                    spr: ability_beam_sprite(ab) });
                            }
                            vfx_spr       = _vfxp.spr;
                            vfx_x         = _vfx_ex;
                            vfx_y         = _vfx_ey;
                            vfx_timer     = _vfxp.ticks;
                            vfx_timer_max = _vfxp.ticks;
                            vfx_school    = ability_school(ab);   // spell-tint blend key
                            vfx_scale_mult = variable_struct_exists(_vfxp, "scale") ? _vfxp.scale : 1;
                        }
                        // Attack audio keyed to the ABILITY (damage type), not the class.
                        // See play_ability_cast_sfx / SYSTEMS_COMBAT_FX.md.
                        play_ability_cast_sfx(ab, player, true);
                        ability_web_count_cast(ab.name, combat_log);   // talent-web MP
                        // Opening Gambit: burn the first-cast flag AFTER the AP was
                        // charged at the discounted rate (same as Quickcast below).
                        if (ability_web_copy_has_rider(ab, "first_free")) ability_web_first_cast_mark(player, ab.name);
                        // Deep Reserves (POTENCY V2): burn the potency first-cast flag too.
                        if (variable_struct_exists(player, "potency_first_casts"))
                            variable_struct_set(player.potency_first_casts, ab.name, true);
                        // Counterphase (task #14): the armed 1-AP discount is spent by this cast.
                        if (variable_struct_exists(player, "blink_tempo_ready")) player.blink_tempo_ready = false;
                if (variable_struct_exists(player, "ashen_tempo_ready")) player.ashen_tempo_ready = false;   // Ashen Blade discount spent
                        ability_web_cast_riders(ab, player, combat_log);   // bespoke on-cast riders (shield/resource)

                        // --- Hit log - damaging abilities report damage; pure debuffs/utility
                        //     just report the cast (the debuff itself is logged when applied). ---
                        if (_deals_damage) {
                            // AoE casts (Singularity et al.) name each target so the
                            // per-enemy lines don't read as one duplicated entry (#21).
                            var _log_entry = player.name + " used " + ab.name
                                + (_is_aoe ? (" on " + target.name) : "")
                                + " for " + string(_final_dmg) + " damage";
                            if (_crit_result.critted) _log_entry += " (CRIT!)";
                            array_push(combat_log, _log_entry);

                            // Damage breakdown for the hover tooltip (Task 1). These are the
                            // component magnitudes that fed this hit - like reading the dice
                            // roll. Component damage is shown pre-mitigation; the line's total
                            // is the real post-armor number. Whole feature is gated by the flag.
                            if (global.combat_log_breakdowns) {
                                var _bd_lines = [];
                                var _bd_base  = variable_struct_exists(ab, "base_damage") ? ab.base_damage : 0;
                                array_push(_bd_lines, { label: "Ability base", val: string(_bd_base) });
                                // Split Vanish out of the lump so the ambush +12 reads as its own
                                // line (it lands inside _dmg pre-crit, same as stat scaling).
                                var _bd_bonus = _bd_dmg_precrit - _bd_base - (_vanish_fired ? 12 : 0);   // stat scaling + pre-crit riders
                                if (_bd_bonus != 0)
                                    array_push(_bd_lines, { label: "Power & bonuses", val: (_bd_bonus > 0 ? "+" : "") + string(_bd_bonus) });
                                if (_vanish_fired)
                                    array_push(_bd_lines, { label: "Vanish ambush", val: "+12" });
                                if (_crit_result.critted)
                                    array_push(_bd_lines, { label: "Critical hit", val: "x" + string(_crit_result.multiplier) });
                                if (_bd_mitig_loss > 0)
                                    array_push(_bd_lines, { label: "Target armor/resist", val: "-" + string(_bd_mitig_loss) });
                                if (_bd_vuln_flat > 0)
                                    array_push(_bd_lines, { label: "Vulnerable/Hexed", val: "+" + string(_bd_vuln_flat) });
                                if (_wpn_flat > 0)
                                    array_push(_bd_lines, { label: ability_class_is_melee(_atk_class) ? "Melee weapon" : "Ranged weapon", val: "+" + string(_wpn_flat) + " " + (_wpn_school != "" ? string_lower(_wpn_school) : "physical") });
                                if (_elem_aff != undefined && _elem_aff.dmg > 0)
                                    array_push(_bd_lines, { label: elem_element_name(_elem_aff.element) + " (weapon)", val: "+" + string(_elem_aff.dmg) });
                                if (_aspect_dmg_pct > 0)
                                    array_push(_bd_lines, { label: "Aspect rune", val: "+" + string(round(_aspect_dmg_pct * 100)) + "%" });
                                if (variable_struct_exists(player, "spell_dmg_bonus") && player.spell_dmg_bonus > 0 && ability_class_is_spell(_atk_class))
                                    array_push(_bd_lines, { label: "Spell focus", val: "+" + string(round(player.spell_dmg_bonus * 100)) + "%" });
                                var _bd = {
                                    title:   ab.name,
                                    total:   _final_dmg,
                                    crit:    _crit_result.critted,
                                    school:  ability_school(ab),
                                    lines:   _bd_lines
                                };
                                // Lazily realign combat_log_detail to combat_log, then attach.
                                while (array_length(combat_log_detail) < array_length(combat_log) - 1)
                                    array_push(combat_log_detail, undefined);
                                array_push(combat_log_detail, _bd);
                            }
                        } else {
                            var _log_entry = player.name + " used " + ab.name;
                            if (_crit_result.critted) _log_entry += " (CRIT - empowered)";
                            array_push(combat_log, _log_entry);
                        }

                        // --- On-hit heal (e.g. Void Drain), reduced by Mortality ---
                        // Leech aspect rune boosts healing from drain (dtype 2) abilities.
                        if (ab.effect_type == "heal") {
                            var _base_heal = ab.effect_value;
                            var _leech_pct = rune_aspect_drain_heal_pct(ab);
                            if (_leech_pct > 0) _base_heal = round(_base_heal * (1 + _leech_pct));
                            // P3 rider (08-01): INT 20 - the blood arts read deeper.
                            if (ab.name == "Blood Leech" && ability_stat_rider_active("Blood Leech")) _base_heal += 4;
                            var _heal_amt = combat_heal_after_mortality(player, _base_heal);
                            var _heal = min(player.max_HP - player.HP, _heal_amt);
                            player.HP += _heal;
                            if (_heal > 0) {
                                array_push(damage_popups, { value: _heal, x: 475, y: 545, timer: 45, col: c_lime });
                            }
                            array_push(combat_log, player.name + " restored " + string(_heal) + " HP.");
                        }

                        // --- Void Drain: soul generation + start its 2-turn cooldown ---
                        if (ab.name == "Void Drain") {
                            if (player.class_id == 0 && variable_struct_exists(player, "souls")) {
                                player.souls = min(player.souls_max, player.souls + 1);
                                // Was SILENT - the desc promises "Banks +1 Soul on hit" but the
                                // log never showed it, so no-kill turns ended with unexplained
                                // Souls (M 07-09 read them as Soulfire double-fires).
                                array_push(combat_log, "Void Drain: +1 Soul.");
                            }
                            if (variable_struct_exists(player, "ability_cd")
                                && selected_ability < array_length(player.ability_cd)) {
                                player.ability_cd[selected_ability] = ability_cooldown(ab);
                            }
                        }

                        // --- Scorch soul generation (Arcanist fire primer; +1 Soul on a
                        //     landed cast so it carries the same-school synergy instead of
                        //     being a Soul-dead filler). Pairs with Soul Nova / Arcane Echo. ---
                        if (ab.name == "Scorch") {
                            if (player.class_id == 0 && variable_struct_exists(player, "souls")) {
                                player.souls = min(player.souls_max, player.souls + 1);
                                array_push(combat_log, "Scorch: +1 Soul.");
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
                                array_push(combat_log, ab.name + ": +" + string(_res_amt) + (_res_amt == 1 ? " Soul." : " Souls."));
                            } else if (variable_struct_exists(player, "blood")) {
                                player.blood = min(player.blood_max, player.blood + _res_amt);
                                array_push(combat_log, ab.name + ": +" + string(_res_amt) + " Blood.");
                            } else if (variable_struct_exists(player, "preparation")) {
                                player.preparation = min(player.preparation_max, player.preparation + _res_amt);
                                array_push(combat_log, ab.name + ": +" + string(_res_amt) + " Preparation.");
                            }
                        }

                        // --- Aspect runes: Bulwark (melee-attack shield) + Anchor (melee Weaken) ---
                        // Bulwark is PER HIT (M 08-18: "should scale with multi-hit melee") -
                        // Flurry's three strikes each grant it.
                        var _bul = rune_aspect_melee_shield(ab) * ((ab.name == "Flurry") ? 3 : 1);
                        if (_bul > 0) {
                            if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                            player.shield_hp += _bul;
                            array_push(combat_log, "Bulwark rune: +" + string(_bul) + " shield" + ((ab.name == "Flurry") ? " (3 hits)." : "."));
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

                        // --- Talent-web Overwhelm keystone (damaging spells): hits leave
                        // the target Vulnerable - flat bonus damage taken, 1 turn (same
                        // shape as Hex Spread / shock-affix vulnerables). ---
                        if (ability_web_copy_has_rider(ab, "hit_vuln") && !target.is_defeated
                            && variable_struct_exists(target, "status_effects")) {
                            array_push(target.status_effects, {
                                name:         "Vulnerable",
                                effect_type:  "debuff",
                                kind:         "vulnerable",
                                effect_value: 2,
                                duration:     1,
                                element:      "",
                                source:       "player"
                            });
                            array_push(combat_log, "Overwhelm: " + target.name + " is left Vulnerable!");
                        }

                        // --- Soulbind: bind this enemy's fate to yours (audit §6 build -
                        // reflect 40% of damage you take AND heal you the same; combat-long).
                        if (ab.name == "Soulbind" && !target.is_defeated) {
                            // Re-binding: strip the marker badge off the previous bond target.
                            var _old_sb = player.soulbind_enemy;
                            if (is_struct(_old_sb) && _old_sb != target && variable_struct_exists(_old_sb, "status_effects")) {
                                var _sb_kept = [];
                                for (var _sbi = 0; _sbi < array_length(_old_sb.status_effects); _sbi++) {
                                    var _sbse = _old_sb.status_effects[_sbi];
                                    if (!(variable_struct_exists(_sbse, "kind") && _sbse.kind == "soulbind")) array_push(_sb_kept, _sbse);
                                }
                                _old_sb.status_effects = _sb_kept;
                            }
                            player.soulbind_enemy = target;
                            // Visible marker badge (duration -1 = combat-long; the enemy
                            // status tick keeps negative durations forever). The lifelink
                            // itself runs off player.soulbind_enemy - this is display only.
                            var _sb_marked = false;
                            for (var _sbj = 0; _sbj < array_length(target.status_effects); _sbj++) {
                                var _sbm = target.status_effects[_sbj];
                                if (variable_struct_exists(_sbm, "kind") && _sbm.kind == "soulbind") { _sb_marked = true; break; }
                            }
                            if (!_sb_marked) {
                                array_push(target.status_effects, {
                                    name:         "Soulbind",
                                    effect_type:  "debuff",
                                    kind:         "soulbind",
                                    effect_value: 0.4,
                                    duration:     -1,
                                    element:      "",
                                    source:       "player"
                                });
                            }
                            array_push(combat_log, "Soulbind: " + target.name + "'s fate is tied to yours.");
                        }

                        // ASHEN DUELIST RIPOSTE (DESIGN_DUELIST_CHALLENGE.md): every
                        // melee blow he survives is answered - flat 12 at T0, then
                        // scaled by his +10%/duel growth from T1 on (M-locked 08-13).
                        if (global.duel_active && target.HP > 0 && !target.is_defeated
                            && ability_class_is_melee(_atk_class) && _final_dmg > 0) {
                            var _rip_dmg = variable_struct_exists(target, "riposte_dmg") ? target.riposte_dmg : 12;
                            combat_apply_damage(player, _rip_dmg);
                            player.hit_flash = max(player.hit_flash, 8);
                            array_push(damage_popups, { value: _rip_dmg, x: 475, y: 545, timer: 40, delay: 10, col: make_color_rgb(230, 140, 100) });
                            array_push(combat_log, "Riposte! The Duelist answers the blow for " + string(_rip_dmg) + ".");
                            if (player.HP <= 0 && !combat_try_last_stand(player, combat_log)) player.is_defeated = true;
                        }

                        // --- Defeat check on target (shared kill handler) ---
                        if (target.HP <= 0) {
                            combat_on_enemy_defeated(target, player, combat_log);
                            // Soul Siphon TRANSCEND "Harvest" (POTENCY V2): SPELL killing
                            // blows grant +2 Souls - the defeat handler granted the first,
                            // this tops up the second.
                            if (player.class_id == 0 && variable_struct_exists(player, "souls")
                                && trait_transcended("Soul Siphon")
                                && ability_class_is_spell(ability_attack_class(ab))) {
                                player.souls = min(player.souls_max, player.souls + 1);
                                array_push(combat_log, "Harvest: the soul comes in whole (+1 more).");
                            }
                        }

                        // --- Talent-web Executioner's Rhythm keystone: killing blows with
                        // this ability refund 1 AP (bursts above the cap like AP items). ---
                        if (target.is_defeated && ability_web_copy_has_rider(ab, "kill_ap")) {
                            player.energy += 1;
                            array_push(combat_log, "Executioner's Rhythm: the AP returns.");
                        }
                        // Reaper's Dividend trunk node (P2, 08-05): SPELL killing
                        // blows refund 1 AP (class-wide sibling of the web keystone).
                        if (target.is_defeated && player.class_id == 0
                            && ability_class_is_spell(ability_attack_class(ab))
                            && trunk_has("soul_kill_ap")) {
                            player.energy += 1;
                            array_push(combat_log, "Reaper's Dividend: the AP returns.");
                        }

                        // --- Talent-web transformative riders (keystone pool + bespoke,
                        //     M 07-27). Shared primitives; the web assigns them per ability. ---
                        // Execute: finish the wounded (own defeat check, Winter's Bite pattern).
                        var _wr_exe = ability_web_rider_value(ab, "execute", 0);
                        if (_wr_exe > 0 && _final_dmg > 0 && !target.is_defeated && target.HP <= target.max_HP * 0.25) {
                            var _wr_ed = max(1, round(_final_dmg * _wr_exe / 100));
                            combat_apply_damage(target, _wr_ed);
                            array_push(combat_log, "Execution! +" + string(_wr_ed) + " to the wounded " + target.name + ".");
                            if (target.HP <= 0) combat_on_enemy_defeated(target, player, combat_log);
                        }
                        // Widowmaker's Point relic (08-11, #23): the decided fight
                        // ends - +40% to enemies below 25% HP (execute idiom above).
                        if (legendary_worn("duel_widow") && _final_dmg > 0 && !target.is_defeated
                            && target.HP <= target.max_HP * 0.25) {
                            var _dw_ed = max(1, round(_final_dmg * 0.40));
                            combat_apply_damage(target, _dw_ed);
                            array_push(combat_log, "Widowmaker's Point: +" + string(_dw_ed) + " to the wounded " + target.name + ".");
                            if (target.HP <= 0) combat_on_enemy_defeated(target, player, combat_log);
                        }
                        // Lifesteal: drink a share of the damage dealt.
                        var _wr_ls = ability_web_rider_value(ab, "lifesteal", 0);
                        if (_wr_ls > 0 && _final_dmg > 0) {
                            var _wr_hp = min(ceil(_final_dmg * _wr_ls / 100), player.max_HP - player.HP);
                            if (_wr_hp > 0) {
                                player.HP += _wr_hp;
                                array_push(combat_log, "Siphoned " + string(_wr_hp) + " HP from the wound.");
                            }
                        }
                        // Splash: echo a share of the damage to one other enemy
                        // (Static Arc chain pattern, single fork).
                        var _wr_sp = ability_web_rider_value(ab, "splash", 0);
                        if (_wr_sp > 0 && _final_dmg > 0) {
                            var _wr_others = [];
                            var _wr_slots  = [];
                            var _wr_live   = 0;
                            for (var _wri = 0; _wri < array_length(combat_state.combatants); _wri++) {
                                var _wrc = combat_state.combatants[_wri];
                                if (_wrc.is_player || _wrc.is_defeated) continue;
                                if (_wrc != target) { array_push(_wr_others, _wrc); array_push(_wr_slots, _wr_live); }
                                _wr_live++;
                            }
                            if (array_length(_wr_others) > 0) {
                                var _wr_pick = irandom(array_length(_wr_others) - 1);
                                var _wr_t    = _wr_others[_wr_pick];
                                var _wr_sd   = combat_resolve_damage(max(1, round(_final_dmg * _wr_sp / 100)),
                                    variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0, _wr_t.armor, _wr_t.el_resist);
                                if (_wr_sd < 1) _wr_sd = 1;
                                combat_apply_damage(_wr_t, _wr_sd);
                                _wr_t.hit_flash = max(_wr_t.hit_flash, 10);
                                var _wr_a = combat_enemy_anchor(_wr_t, _wr_slots[_wr_pick]);   // 2.5D: over the creature
                                array_push(damage_popups, { value: _wr_sd, x: _wr_a.x, y: _wr_a.y - 60, timer: 45, col: make_color_rgb(200, 170, 255) });
                                array_push(combat_log, ab.name + " forks to " + _wr_t.name + " for " + string(_wr_sd) + "!");
                                if (_wr_t.HP <= 0) combat_on_enemy_defeated(_wr_t, player, combat_log);
                            }
                        }
                        // ===== DELIVERY MUTATORS (M 08-11, SYSTEMS_MUTATORS.md) =====
                        // ONE per cast (legendary > web node > innate). SPLIT forks
                        // immediately (splash pattern); BOUNCE and ECHO queue delayed
                        // sub-hits (processed at the top of Step); LINGER leaves a
                        // 2-turn DoT so existing ticks + the Censer's +2 both apply.
                        var _mut = (_deals_damage && _final_dmg > 0) ? ability_delivery_mutator(ab) : undefined;
                        if (_mut != undefined) {
                            var _mut_sch = ability_school(ab);
                            if (_mut.kind == "split") {
                                var _sp_pool = [], _sp_slots = [], _sp_live = 0;
                                for (var _spi = 0; _spi < array_length(combat_state.combatants); _spi++) {
                                    var _spc = combat_state.combatants[_spi];
                                    if (_spc.is_player || _spc.is_defeated) continue;
                                    if (_spc != target) { array_push(_sp_pool, _spc); array_push(_sp_slots, _sp_live); }
                                    _sp_live++;
                                }
                                if (array_length(_sp_pool) > 0) {
                                    var _sp_p = irandom(array_length(_sp_pool) - 1);
                                    var _sp_t = _sp_pool[_sp_p];
                                    var _sp_d = combat_resolve_damage(max(1, round(_final_dmg * _mut.pct / 100)),
                                        variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0, _sp_t.armor, _sp_t.el_resist);
                                    if (_sp_d < 1) _sp_d = 1;
                                    combat_apply_damage(_sp_t, _sp_d);
                                    _sp_t.hit_flash = max(_sp_t.hit_flash, 10);
                                    var _sp_px = 1620 + _sp_slots[_sp_p] * (-120);
                                    var _sp_py = 233 + _sp_slots[_sp_p] * 105 - 60;
                                    if (combat_25d() && variable_struct_exists(_sp_t, "last_ecx")) { _sp_px = _sp_t.last_ecx; _sp_py = _sp_t.last_ecy - 90; }
                                    array_push(damage_popups, { value: _sp_d, x: _sp_px, y: _sp_py, timer: 45,
                                        col: (_mut_sch != "") ? school_color(_mut_sch) : c_white });
                                    array_push(combat_log, ab.name + " SPLITS to " + _sp_t.name + " for " + string(_sp_d) + "!");
                                    if (_sp_t.HP <= 0 && !_sp_t.is_defeated) combat_on_enemy_defeated(_sp_t, player, combat_log);
                                }
                            } else if (_mut.kind == "bounce" || _mut.kind == "echo") {
                                // v2 (08-11): echo waits for the ACTUAL next player
                                // turn (t doubles as the never-hang fallback);
                                // bounce carries a hop count (Bouncing Bomb = 2).
                                array_push(mutator_queue, {
                                    kind: _mut.kind, t: (_mut.kind == "bounce") ? 22 : 600,
                                    wait_turn: (_mut.kind == "echo"), seen_enemy: false,
                                    from: target, pct: _mut.pct, base: _final_dmg,
                                    dtype: variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0,
                                    school: _mut_sch, name: ab.name,
                                    hops: variable_struct_exists(_mut, "hops") ? _mut.hops : 1
                                });
                            } else if (_mut.kind == "linger" && !target.is_defeated
                                       && variable_struct_exists(target, "status_effects")) {
                                // House DoT shape (Serrated Bleed / Burning): effect_type
                                // "dot" + the DoT element vocabulary, so the tick engine,
                                // its colors and the Censer's +2 all just apply.
                                var _lg_el = (_mut_sch == "fire") ? "burn"
                                           : ((_mut_sch == "blood") ? "bleed" : _mut_sch);
                                array_push(target.status_effects, {
                                    name: "Lingering " + ((_mut_sch != "") ? school_label(_mut_sch) : "Wound"),
                                    effect_type: "dot", kind: "dot",
                                    effect_value: max(1, round(_final_dmg * _mut.pct / 100)),
                                    duration: 2, element: _lg_el, source: "player"
                                });
                                array_push(combat_log, ab.name + " lingers on " + target.name + " - it will "
                                    + ((_lg_el == "bleed") ? "bleed" : ((_lg_el == "poison") ? "fester" : "burn")) + " for 2 turns!");
                            }
                        }

                        // Whetstone Echo (Shrine V2): the first damaging ability rings
                        // twice - 40% of the landed damage repeats on this target.
                        if (_whet_now && _final_dmg > 0 && !target.is_defeated) {
                            var _we_dmg = max(1, round(_final_dmg * 0.40));
                            combat_apply_damage(target, _we_dmg);
                            target.hit_flash = max(target.hit_flash, 10);
                            var _we_slot = 0;
                            for (var _wei = 0; _wei < array_length(combat_state.combatants); _wei++) {
                                if (combat_state.combatants[_wei] == target) break;
                                if (!combat_state.combatants[_wei].is_player) _we_slot++;
                            }
                            var _we_px = 1620 + _we_slot * (-120) + 52, _we_py = 233 + _we_slot * 105 - 140;
                            if (combat_25d() && variable_struct_exists(target, "last_ecx")) { _we_px = target.last_ecx + 52; _we_py = target.last_ecy - 140; }
                            array_push(damage_popups, { value: _we_dmg, x: _we_px,
                                y: _we_py, timer: 45, delay: 14, col: make_color_rgb(170, 220, 255) });
                            array_push(combat_log, "Whetstone Echo - " + ab.name + " rings twice for " + string(_we_dmg) + "!");
                            _whet_fired = true;
                            if (target.HP <= 0 && !target.is_defeated) combat_on_enemy_defeated(target, player, combat_log);
                        }

                        // Crit riders: resource on crit (Hungering Maw) / Vulnerable on crit (Deadeye).
                        if (_crit_result.critted) {
                            // Duelist boon V2: the perfect cut pays back 1 class resource.
                            if (!_duelist_refunded && boon_active("duelist")) {
                                combat_grant_secondary(player, 1, "Duelist boon", combat_log);
                                _duelist_refunded = true;
                            }
                            var _wr_cs = ability_web_rider_value(ab, "crit_sec", 0);
                            if (_wr_cs > 0) combat_grant_secondary(player, _wr_cs, "Hungering Maw", combat_log);
                            var _wr_cv = ability_web_rider_value(ab, "crit_vuln", 0);
                            if (_wr_cv > 0 && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                                array_push(target.status_effects, {
                                    name: "Vulnerable", effect_type: "debuff", kind: "vulnerable",
                                    effect_value: 2, duration: _wr_cv, element: "", source: "player"
                                });
                                array_push(combat_log, "Deadeye: " + target.name + " is left Vulnerable!");
                            }
                        }
                        // Status splash (Pandemic / Virulent Spread): this ability's
                        // status also lands on one other enemy.
                        if (ability_web_copy_has_rider(ab, "status_splash")) {
                            var _wr_kind = ability_status_kind(ab);
                            if (_wr_kind != "") {
                                var _wr_o2 = [];
                                for (var _wrj = 0; _wrj < array_length(combat_state.combatants); _wrj++) {
                                    var _wc2 = combat_state.combatants[_wrj];
                                    if (!_wc2.is_player && !_wc2.is_defeated && _wc2 != target) array_push(_wr_o2, _wc2);
                                }
                                if (array_length(_wr_o2) > 0) {
                                    var _wr_t2 = _wr_o2[irandom(array_length(_wr_o2) - 1)];
                                    array_push(_wr_t2.status_effects, {
                                        name: ab.name, effect_type: ab.effect_type, kind: _wr_kind,
                                        effect_value: ab.effect_value, duration: max(1, ab.effect_duration),
                                        element: ability_status_element(ab), source: "player"
                                    });
                                    array_push(combat_log, ab.name + " spreads to " + _wr_t2.name + "!");
                                }
                            }
                        }

                        // --- Momentum (audit §6): Strike refunds its AP when it fells the
                        // target - the humble general attack becomes a tempo chaff-clearer.
                        if (ab.name == "Strike" && target.is_defeated) {
                            player.energy += 1;
                            array_push(combat_log, "Momentum! Strike's AP returns.");
                        }

                        // --- Galvanize (D§4, M-approved 07-09): a killing blow banks
                        //     +1 AP for NEXT turn (granted in combat_next_turn).
                        // "Chain Reaction" web keystone (task #14): a landed CRIT also
                        // triggers the surge, not just a killing blow.
                        if (ab.name == "Galvanize" && (target.is_defeated
                            || (ability_web_copy_has_rider(ab, "galv_crit") && _crit_result.critted))) {
                            player.galvanize_ap = 1;
                            array_push(combat_log, "Galvanize - the surge carries: +1 AP next turn!");
                        }

                        // --- Killing Spree (07-17): the spree - every enemy this cast FELLS
                        //     refunds 2 AP, so kills chain into more kills this turn.
                        if (ab.name == "Killing Spree" && target.is_defeated) {
                            player.energy += 2;
                            array_push(combat_log, "Killing Spree - the spree continues! +2 AP.");
                        }

                        // --- Vital Theft (07-17): the steal is real - drain the target's max
                        //     HP, add it to your own, and heal the same, all combat-long. Fires
                        //     on the landed hit (was never wired before this pass).
                        if (ab.name == "Vital Theft") {
                            var _vt = ab.effect_value;
                            target.max_HP = max(1, target.max_HP - _vt);
                            if (target.HP > target.max_HP) target.HP = target.max_HP;
                            player.max_HP += _vt;
                            player.HP = min(player.max_HP, player.HP + _vt);
                            array_push(combat_log, "Vital Theft: you steal " + string(_vt) + " max HP - you grow as they wither.");
                        }

                        // --- Winter's Bite (D§4): against a CHILLED target the knife
                        //     bites deeper - +9 Frost and the Prep comes back.
                        if (ab.name == "Winter's Bite") {
                            var _wb_chilled = false;
                            for (var _wbi = 0; _wbi < array_length(target.status_effects); _wbi++) {
                                if (combat_status_element(target.status_effects[_wbi]) == "frost") { _wb_chilled = true; break; }
                            }
                            if (_wb_chilled) {
                                if (!target.is_defeated) {
                                    var _wb_dmg = combat_resolve_damage(9, 1, target.armor, target.el_resist);
                                    if (_wb_dmg < 1) _wb_dmg = 1;
                                    combat_apply_damage(target, _wb_dmg);
                                    array_push(combat_log, "Winter's Bite sinks into the chill - +" + string(_wb_dmg) + "!");
                                    if (target.HP <= 0) combat_on_enemy_defeated(target, player, combat_log);
                                }
                                if (variable_struct_exists(player, "preparation")) {
                                    player.preparation = min(player.preparation_max, player.preparation + 1);
                                    array_push(combat_log, "Winter's Bite: the Prep returns.");
                                }
                            }
                        }

                        // --- Static Arc (D§4): the arc chains 50% of the dealt damage to
                        //     one other enemy - to ALL others if the target was already
                        //     Shocked (the shock is not consumed).
                        if (ab.name == "Static Arc" && _final_dmg > 0) {
                            var _sa_shocked = false;
                            for (var _sasi = 0; _sasi < array_length(target.status_effects); _sasi++) {
                                if (combat_status_element(target.status_effects[_sasi]) == "shock") { _sa_shocked = true; break; }
                            }
                            var _sa_others = [];
                            var _sa_slots  = [];
                            var _sa_live   = 0;
                            for (var _saci = 0; _saci < array_length(combat_state.combatants); _saci++) {
                                var _sac = combat_state.combatants[_saci];
                                if (_sac.is_player || _sac.is_defeated) continue;
                                if (_sac != target) { array_push(_sa_others, _sac); array_push(_sa_slots, _sa_live); }
                                _sa_live++;
                            }
                            if (array_length(_sa_others) > 0) {
                                var _sa_first = _sa_shocked ? 0 : irandom(array_length(_sa_others) - 1);
                                var _sa_count = _sa_shocked ? array_length(_sa_others) : 1;
                                // "Storm Unbound" web keystone (task #14): full-damage chain.
                                var _sa_rate  = ability_web_copy_has_rider(ab, "chain_full") ? 1.0 : 0.5;
                                if (_sa_shocked) array_push(combat_log, "The shock ARCS to everything standing!");
                                for (var _sahi = 0; _sahi < _sa_count; _sahi++) {
                                    var _sa_idx = _sa_shocked ? _sahi : _sa_first;
                                    var _sa_t   = _sa_others[_sa_idx];
                                    var _sa_dmg = combat_resolve_damage(max(1, round(_final_dmg * _sa_rate)), 1, _sa_t.armor, _sa_t.el_resist);
                                    if (_sa_dmg < 1) _sa_dmg = 1;
                                    combat_apply_damage(_sa_t, _sa_dmg);
                                    _sa_t.hit_flash = max(_sa_t.hit_flash, 10);
                                    var _sa_a = combat_enemy_anchor(_sa_t, _sa_slots[_sa_idx]);   // 2.5D: over the creature
                                    array_push(damage_popups, { value: _sa_dmg, x: _sa_a.x, y: _sa_a.y - 60, timer: 45, col: make_color_rgb(150, 200, 245) });
                                    array_push(combat_log, "Static Arc chains to " + _sa_t.name + " for " + string(_sa_dmg) + "!");
                                    if (_sa_t.HP <= 0) combat_on_enemy_defeated(_sa_t, player, combat_log);
                                }
                            }
                            // "Live Wire" web node (task #14): the Arc leaves the target
                            // SHOCKED, so the caster's own NEXT Arc chains to everything.
                            // Applied AFTER this cast's chain check - the setup pays off
                            // on the next cast, not retroactively.
                            if (ability_web_copy_has_rider(ab, "hit_shock")
                                && !target.is_defeated && variable_struct_exists(target, "status_effects")) {
                                array_push(target.status_effects, {
                                    name: "Shocked", effect_type: "status", kind: "status",
                                    effect_value: 0, duration: 1, element: "shock", source: "player"
                                });
                                array_push(combat_log, "Live Wire: " + target.name + " is SHOCKED - the next arc will leap!");
                            }
                        }

                        // --- Echo: 50% second instance to this target (first AoE only) ---
                        if (_echo_now && !target.is_defeated && _final_dmg > 0) {
                            var _echo_dmg = max(1, round(_final_dmg * 0.5));
                            combat_apply_damage(target, _echo_dmg);
                            target.hit_flash = max(target.hit_flash, 10);
                            array_push(damage_popups, { value: _echo_dmg, x: _vfx_ex, y: _vfx_ey - 60, timer: 45, col: make_color_rgb(180, 140, 255) });
                            array_push(combat_log, "Echo: " + target.name + " takes " + string(_echo_dmg) + " more!");
                            if (target.HP <= 0) combat_on_enemy_defeated(target, player, combat_log);
                        }

                        // --- Arcane Echo: always echoes 50% of its damage to every OTHER
                        //     living enemy (its identity - a soul-fuelled mini-AoE). (P2) ---
                        if (ab.name == "Arcane Echo" && _final_dmg > 0) {
                            var _echo_splash = max(1, round(_final_dmg * 0.5));
                            for (var _aei = 0; _aei < array_length(combat_state.combatants); _aei++) {
                                var _aec = combat_state.combatants[_aei];
                                if (_aec.is_player || _aec.is_defeated || _aec == target) continue;
                                combat_apply_damage(_aec, _echo_splash);
                                _aec.hit_flash = max(_aec.hit_flash, 10);
                                array_push(combat_log, "Arcane Echo: " + _aec.name
                                    + " takes " + string(_echo_splash) + " echo damage!");
                                if (_aec.HP <= 0) combat_on_enemy_defeated(_aec, player, combat_log);
                            }
                        }

                        // --- Chain Caster: single-target elemental/void/blood damage
                        //     splashes 40% to every OTHER living enemy. ---
                        if (!_is_aoe && trait_active("Chain Caster") && ab.base_damage > 0
                            && (ab.damage_type == 1 || ab.damage_type == 2 || ab.damage_type == 3)) {
                            // POTENCY V2: +10% splash strength per rank (40% -> up to 56%);
                            // TRANSCEND "Storm Conductor": each splash can crit (own roll).
                            var _splash = max(1, round(_final_dmg * 0.4 * trait_potency_mult("Chain Caster")));
                            for (var _cci = 0; _cci < array_length(combat_state.combatants); _cci++) {
                                var _ccc = combat_state.combatants[_cci];
                                if (_ccc.is_player || _ccc.is_defeated || _ccc == target) continue;
                                var _cc_dmg = _splash;
                                if (trait_transcended("Chain Caster") && ab.crit_type != -1) {
                                    var _cc_cr = combat_roll_crit(player.stats, ab.base_crit, ab.crit_type);
                                    if (_cc_cr.critted) {
                                        _cc_dmg = round(_cc_dmg * _cc_cr.multiplier);
                                        array_push(combat_log, "Storm Conductor: the arc CRITS " + _ccc.name + "!");
                                    }
                                }
                                combat_apply_damage(_ccc, _cc_dmg);
                                _ccc.hit_flash = max(_ccc.hit_flash, 10);
                                array_push(combat_log, "Chain Caster: " + _ccc.name
                                    + " takes " + string(_cc_dmg) + " splash damage!");
                                if (_ccc.HP <= 0) combat_on_enemy_defeated(_ccc, player, combat_log);
                            }
                        }

                        // --- Stormcaller's Loop (07-28 legendary; buffed 07-29 to 25%):
                        //     single-target SPELLS echo to ONE other living enemy (any
                        //     spell school - Chain Caster's lightweight cousin). ---
                        if (!_is_aoe && variable_struct_exists(player, "leg_loop") && player.leg_loop
                            && ab.base_damage > 0 && ability_class_is_spell(ability_attack_class(ab))) {
                            var _sl_hosts = [];
                            for (var _sli = 0; _sli < array_length(combat_state.combatants); _sli++) {
                                var _slc = combat_state.combatants[_sli];
                                if (!_slc.is_player && !_slc.is_defeated && _slc != target) array_push(_sl_hosts, _slc);
                            }
                            if (array_length(_sl_hosts) > 0) {
                                var _sl_t   = _sl_hosts[irandom(array_length(_sl_hosts) - 1)];
                                var _sl_dmg = max(1, round(_final_dmg * 0.25));
                                combat_apply_damage(_sl_t, _sl_dmg);
                                _sl_t.hit_flash = max(_sl_t.hit_flash, 10);
                                array_push(combat_log, "Stormcaller's Loop: the spell strays - " + _sl_t.name
                                    + " takes " + string(_sl_dmg) + " echo damage!");
                                if (_sl_t.HP <= 0) combat_on_enemy_defeated(_sl_t, player, combat_log);
                            }
                        }

                        // --- Apply status effect to target (typed status layer) ---
                        // Only applied on a living target so DoTs don't stack on corpses.
                        if (!target.is_defeated) {
                            // --- 08-17 Arcanist control pair (M-locked) - bespoke rolls ---
                            if (ab.name == "Paralytic Pulse") {
                                // Every enemy rolls its OWN chance (independent): 40%, +10 Wider
                                // Pulse, +20 Resonant Pulse if it already carries a debuff.
                                var _pp_ch = 40 + (ability_web_copy_has_rider(ab, "pulse10") ? 10 : 0);
                                if (ability_web_copy_has_rider(ab, "pulse_debuffed")) {
                                    for (var _ppi = 0; _ppi < array_length(target.status_effects); _ppi++) {
                                        if (combat_status_is_debuff(target.status_effects[_ppi])) { _pp_ch += 20; break; }
                                    }
                                }
                                if (irandom(99) < _pp_ch) {
                                    if (combat_control_resist_try(target, "stun")) {
                                        array_push(combat_log, target.name + " fights through the Paralytic Pulse - the stun fails to take hold!");
                                    } else {
                                        var _pp_dur = ab.effect_duration + ((_crit_result.effect_quality == 1) ? 1 : 0);
                                        array_push(target.status_effects, { name: ab.name, effect_type: "debuff", kind: "stun",
                                            effect_value: 1, duration: _pp_dur, element: "", source: "player" });
                                        array_push(combat_log, "Paralytic Pulse -> " + target.name + ": Stunned (" + ability_turns(_pp_dur) + ").");
                                        var _pp_slot = 0;
                                        for (var _ppsi = 0; _ppsi < array_length(combat_state.combatants); _ppsi++) {
                                            if (combat_state.combatants[_ppsi] == target) break;
                                            if (!combat_state.combatants[_ppsi].is_player) _pp_slot++;
                                        }
                                        var _pp_a = combat_enemy_anchor(target, _pp_slot);
                                        array_push(damage_popups, { value: 0, text: "STUNNED!", x: _pp_a.x, y: _pp_a.y - 105, timer: 40, col: c_yellow });
                                    }
                                } else {
                                    array_push(combat_log, target.name + " shrugs off the Paralytic Pulse (" + string(_pp_ch) + "% roll).");
                                }
                            } else if (ab.name == "Call of the Void") {
                                // ONE random debuff (TWO different ones with Chorus), 2 turns.
                                var _cv_pool = ["weaken", "silence", "root", "vulnerable", "blind"];
                                var _cv_n = ability_web_copy_has_rider(ab, "void_chorus") ? 2 : 1;
                                _cv_pool = array_shuffle(_cv_pool);
                                var _cv_dur = ab.effect_duration + ((_crit_result.effect_quality == 1) ? 1 : 0);
                                for (var _cvk = 0; _cvk < _cv_n; _cvk++) {
                                    var _cv_kind = _cv_pool[_cvk];
                                    if (combat_control_resist_try(target, _cv_kind)) {
                                        array_push(combat_log, target.name + " fights through the void's " + _cv_kind + " - it fails to take hold!");
                                        continue;
                                    }
                                    var _cv_val = 1, _cv_ph = "";
                                    switch (_cv_kind) {
                                        case "weaken":     _cv_val = 0.20; _cv_ph = "Weakened (-20% dmg)"; break;
                                        case "silence":    _cv_val = 1;    _cv_ph = "Silenced"; break;
                                        case "root":       _cv_val = 1;    _cv_ph = "Rooted"; break;
                                        case "vulnerable": _cv_val = 3;    _cv_ph = "Exposed (+3 dmg taken/hit)"; break;
                                        case "blind":      _cv_val = 0.30; _cv_ph = "Blinded (-30% acc)"; break;
                                    }
                                    array_push(target.status_effects, { name: ab.name, effect_type: "debuff", kind: _cv_kind,
                                        effect_value: _cv_val, duration: _cv_dur, element: "void", source: "player" });
                                    array_push(combat_log, "Call of the Void -> " + target.name + ": " + _cv_ph + " (" + ability_turns(_cv_dur) + ").");
                                }
                            } else
                            // DoTs, debuffs, and the control traps (Bear Trap root /
                            // Death Snare stun) all land as typed statuses.
                            if (ab.effect_type == "dot" || ab.effect_type == "debuff"
                                || ab.name == "Bear Trap" || ab.name == "Death Snare") {
                                var _status_ev  = ab.effect_value;
                                var _status_dur = ab.effect_duration;
                                if (ab.effect_type == "dot" && variable_struct_exists(player, "derived")) {
                                    _status_ev += player.derived.dot_dmg_bonus;
                                }
                                // P3 riders (08-01): WIS 25 sharpens Entropy's every tick;
                                // STR/WIS-braced roots (Gravewrack Grip / Bear Trap) hold
                                // one extra turn.
                                if (ab.name == "Entropy" && ability_stat_rider_active("Entropy")) _status_ev += 1;
                                if ((ab.name == "Gravewrack Grip" || ab.name == "Bear Trap")
                                    && ability_status_kind(ab) == "root"
                                    && ability_stat_rider_active(ab.name)) _status_dur += 1;
                                // Entropy escalation (M ask): if the target already carries a
                                // void DoT, this cast deals DOUBLE damage - so stacking Entropy
                                // on itself ramps up instead of being a flat re-apply.
                                if (ab.name == "Entropy") {
                                    var _has_void_dot = false;
                                    for (var _evi = 0; _evi < array_length(target.status_effects); _evi++) {
                                        var _evse = target.status_effects[_evi];
                                        if (variable_struct_exists(_evse, "kind") && _evse.kind == "dot"
                                            && combat_status_element(_evse) == "void") { _has_void_dot = true; break; }
                                    }
                                    if (_has_void_dot) {
                                        _status_ev *= 2;
                                        array_push(combat_log, "Entropy feeds on lingering void - DOUBLE damage!");
                                    }
                                }
                                if (_crit_result.effect_quality == 1) {
                                    _status_dur += 1;
                                }
                                var _status_kind = ability_status_kind(ab);
                                // Escalating control resist (M 07-28): chained
                                // stun/root/silence fizzles more each time - see
                                // combat_control_resist_try. Damage already landed.
                                var _ctrl_resisted = combat_control_resist_try(target, _status_kind);
                                if (_ctrl_resisted) {
                                    array_push(combat_log, target.name + " fights through " + ab.name + " - the control fails to take hold!");
                                }
                                if (!_ctrl_resisted) {
                                var _status = {
                                    name:         ab.name,
                                    effect_type:  ab.effect_type,
                                    kind:         _status_kind,
                                    effect_value: _status_ev,
                                    duration:     _status_dur,
                                    element:      ability_status_element(ab),
                                    source:       "player"
                                };
                                // Entropy (07-16, M-approved): the rot ACCELERATES - each tick
                                // grows +2 (6/8/10/12 = 36 back-loaded). Both DoT tickers honor
                                // the `accel` field; the double-on-reapply above still applies
                                // to the starting value.
                                if (ab.name == "Entropy") _status.accel = 2;
                                array_push(target.status_effects, _status);
                                // Name what the status DOES so players learn the system by reading the log.
                                var _kind_phrase = "";
                                switch (_status_kind) {
                                    case "dot":        _kind_phrase = (ability_status_element(ab) != "" ? ability_status_element(ab) : "DoT") + " " + string(_status_ev) + "/turn"; break;
                                    case "vulnerable": _kind_phrase = "Exposed (+" + string(_status_ev) + " dmg taken/hit)"; break;
                                    case "hexed":      _kind_phrase = "Hexed (+" + string(_status_ev) + " dmg taken/hit; detonations doubled + spread)"; break;
                                    case "firemark":   _kind_phrase = "Searing (+" + string(_status_ev) + " fire dmg/hit)"; break;
                                    case "weaken":     _kind_phrase = (ability_status_element(ab) == "frost")
                                        ? ("Chilled (-" + string(round(_status_ev * 100)) + "% dmg; detonators shatter it)")
                                        : ("Weakened (-" + string(round(_status_ev * 100)) + "% dmg)"); break;
                                    case "blind":      _kind_phrase = "Blinded (-" + string(round(_status_ev * 100)) + "% acc)"; break;
                                    case "stun":       _kind_phrase = "Stunned"; break;
                                    case "root":       _kind_phrase = "Rooted"; break;
                                    case "silence":    _kind_phrase = "Silenced"; break;
                                    case "marked":     _kind_phrase = "Marked (+30% from ALL sources below half HP)"; break;
                                    case "mortality":  _kind_phrase = "Mortality (-" + string(round(_status_ev * 100)) + "% healing)"; break;
                                    default:           _kind_phrase = ab.name;
                                }
                                array_push(combat_log, ab.name + " -> " + target.name + ": " + _kind_phrase + " (" + ability_turns(_status_dur) + ").");

                                // P3 rider (08-01): CON 25 - Marrow Crush also braces
                                // YOU: the follow-through hardens into +4 shield.
                                if (ab.name == "Marrow Crush" && ability_stat_rider_active("Marrow Crush")) {
                                    if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                                    player.shield_hp += 4;
                                    array_push(combat_log, "The crushing follow-through braces you (+4 shield).");
                                }

                                // INTERRUPT (07-17): a STUN, or a ROOT on a MELEE foe, that
                                // lands while the target is winding up a charged/heavy attack
                                // answers the telegraph AND refunds 1 AP (once per turn). Root
                                // only counts on melee foes (it can't stop a ranged wind-up),
                                // mirroring enemy_intent_blocked.
                                var _int_stops = (_status_kind == "stun")
                                    || (_status_kind == "root" && (variable_struct_exists(target, "reach") ? target.reach : "melee") == "melee");
                                if (_int_stops
                                    && variable_struct_exists(target, "intent") && target.intent != undefined
                                    && variable_struct_exists(target.intent, "heavy") && target.intent.heavy
                                    && !(variable_struct_exists(player, "interrupt_used") && player.interrupt_used)) {
                                    player.energy += 1;
                                    player.interrupt_used = true;
                                    array_push(combat_log, "INTERRUPT! " + target.name + "'s charged attack is broken - +1 AP!");
                                }

                                // Plaguebearer: single-target debuffs/DoTs also strike every
                                // OTHER living enemy at half duration.
                                // POTENCY V2 ranks: spread duration +12.5%/rank of the full
                                // value - 50% / 62.5% / 75% / 87.5% / 100% at rank 4.
                                if (!_is_aoe && trait_active("Plaguebearer")) {
                                    var _pb_frac = 0.5 + 0.125 * trait_potency_r14("Plaguebearer");
                                    var _pb_dur = max(1, floor(_status_dur * _pb_frac));
                                    var _pb_spread = false;
                                    for (var _pbi = 0; _pbi < array_length(combat_state.combatants); _pbi++) {
                                        var _pbc = combat_state.combatants[_pbi];
                                        if (_pbc.is_player || _pbc.is_defeated || _pbc == target) continue;
                                        if (!variable_struct_exists(_pbc, "status_effects")) continue;
                                        // Spread controls ramp each victim's own resist counter too.
                                        if (combat_control_resist_try(_pbc, _status_kind)) continue;
                                        array_push(_pbc.status_effects, {
                                            name:         ab.name,
                                            effect_type:  ab.effect_type,
                                            kind:         _status_kind,
                                            effect_value: _status_ev,
                                            duration:     _pb_dur,
                                            element:      ability_status_element(ab),
                                            source:       "player"
                                        });
                                        _pb_spread = true;
                                    }
                                    if (_pb_spread) array_push(combat_log, "Plaguebearer spreads " + ab.name + " to all enemies!");
                                }
                                }   // end !_ctrl_resisted
                            }

                            // Frost Shot (07-16 combo batch): the SS shatter-primer's second
                            // edge - a 1-turn Chill rider on top of its 3-turn Weaken (same
                            // status shape as Hoarfrost Lance's chill, shorter window). The
                            // weaken layer aggregates by MAX, so they overlap, not stack.
                            if (ab.name == "Frost Shot") {
                                array_push(target.status_effects, {
                                    name: "Chilled", effect_type: "debuff", kind: "weaken",
                                    effect_value: 0.30, duration: 1, element: "frost", source: "player"
                                });
                                array_push(combat_log, target.name + " is Chilled (1 turn) - detonators will SHATTER it!");
                            }

                            // Elemental weapon affix MAY apply its setup status (burn/frost/shock)
                            // on a damaging hit of the weapon's reach class - now a chance proc
                            // (~10% uncommon), not every hit, so the rider no longer out-values
                            // abilities. The flat elemental damage above still lands every hit.
                            // The `element` tag feeds the detonation reaction. (Task 12, §C)
                            var _elem_proc = (_elem_aff != undefined)
                                && (variable_struct_exists(_elem_aff, "status_chance") ? random(1) < _elem_aff.status_chance : true);
                            if (_deals_damage && _elem_aff != undefined && _elem_proc) {
                                array_push(target.status_effects, {
                                    name:         elem_status_name(_elem_aff.element),
                                    effect_type:  (_elem_aff.status_kind == "dot") ? "dot" : "debuff",
                                    kind:         _elem_aff.status_kind,
                                    effect_value: _elem_aff.status_value,
                                    duration:     _elem_aff.status_dur,
                                    element:      _elem_aff.element,
                                    source:       "player"
                                });
                                array_push(combat_log, target.name + " is " + elem_status_verb(_elem_aff.element) + "!");
                            }
                        }
                    }   // end if (_hit) else
                  }     // end per-target for loop

                  // Echo consumes its once-per-combat charge after the full AoE resolves.
                  if (_echo_now) player.rune_first_aoe_used = true;

                  // Whetstone Echo consumes its charge only when it actually rang.
                  if (_whet_fired) player.whet_echo_used = true;

                  // Compounding Dread (07-16): each trap cast while the dread is lit
                  // compounds the permanent (this-combat) trap bonus by +4. Incremented
                  // AFTER resolution so the first trap after lighting it gets +0.
                  if (variable_struct_exists(player, "dread_active") && player.dread_active
                      && (ab.name == "Bear Trap" || ab.name == "Spike Trap" || ab.name == "Death Snare")) {
                      player.dread_bonus += variable_struct_exists(player, "dread_rate") ? player.dread_rate : 4;
                      array_push(combat_log, "The dread compounds - traps now +" + string(player.dread_bonus) + " damage this combat.");
                  }

                  // Sprung Steel trunk node (P2, 08-05): casting a trap returns 1 Prep
                  // (after resolution, once per cast - Bear/Spike run free, Snare nets 1).
                  if (player.class_id == 2 && variable_struct_exists(player, "preparation")
                      && (ab.name == "Bear Trap" || ab.name == "Spike Trap" || ab.name == "Death Snare")
                      && trunk_has("prep_trap_refund")) {
                      player.preparation = min(player.preparation_max, player.preparation + 1);
                      array_push(combat_log, "Sprung Steel: the trap resets itself - +1 Prep.");
                  }
                  // OVERCHARGE safety: a fully-missed cast keeps the reserve (generous).
                  player.overcharge_armed = false;
                }       // end "targets non-empty" else

            } else {
                // --- Self-targeted ability ---
                array_push(combat_log, player.name + " used " + ab.name + ".");
                // Talent-web MP + Opening Gambit flag for ALL self-casts (movement
                // included - Blink/Shadow Step never earned mastery before the web
                // rework, which left their webs unreachable).
                ability_web_count_cast(ab.name, combat_log);
                if (ability_web_copy_has_rider(ab, "first_free")) {
                    // 0-AP Opening Gambit (07-29): the spend already waived the
                    // secondary cost for this first cast - say so before burning
                    // the flag.
                    if (ability_gambit_waives_secondary(ab, player)) {
                        array_push(combat_log, "Opening Gambit - the first " + ab.name + " costs nothing!");
                    }
                    ability_web_first_cast_mark(player, ab.name);
                }
                // Deep Reserves (POTENCY V2): burn the potency first-cast flag too.
                if (variable_struct_exists(player, "potency_first_casts"))
                    variable_struct_set(player.potency_first_casts, ab.name, true);
                // Counterphase (task #14): the armed 1-AP discount is spent by this cast.
                if (variable_struct_exists(player, "blink_tempo_ready")) player.blink_tempo_ready = false;
                if (variable_struct_exists(player, "ashen_tempo_ready")) player.ashen_tempo_ready = false;   // Ashen Blade discount spent
                ability_web_cast_riders(ab, player, combat_log);   // bespoke on-cast riders (shield/resource)
                if (ab.name == "Shadow Step") {
                    audio_play_sound(snd_move_whoosh, 1, false);   // movement keeps its whoosh
                } else {
                    if (ab.name == "Blink") {
                        // Blink flutter (M 07-30: it shared the Shadow Step whoosh and,
                        // sitting in the whoosh branch, skipped the VFX block entirely):
                        // pitched-up arcane shimmer over a fast whoosh - short, instant,
                        // magical - and it falls through to the haste-clock burst below.
                        var _bk_sh = audio_play_sound(snd_cast_arcane_2, 1, false);
                        audio_sound_pitch(_bk_sh, 1.35);
                        var _bk_wh = audio_play_sound(snd_move_whoosh, 1, false);
                        audio_sound_pitch(_bk_wh, 1.55);
                    } else {
                        // Support cast - sound keyed to the effect kind (heal/shield/buff/...).
                        play_ability_cast_sfx(ab, player, false);
                    }
                    // Self-cast VFX over the player, keyed to what the ability does
                    // (heal/shield/resource/self-debuff/evasion/dark pact/offense buff)
                    // instead of the old heal-or-sword split. See ability_support_vfx.
                    var _vfxp = ability_support_vfx(ab);
                    var _pvfa = combat_player_vfx_anchor(player);
                    vfx_spr       = _vfxp.spr;
                    vfx_x         = _pvfa.x;
                    vfx_y         = _pvfa.y;
                    vfx_timer     = _vfxp.ticks;
                    vfx_timer_max = _vfxp.ticks;
                    vfx_school    = ability_school(ab);   // spell-tint blend key
                    vfx_scale_mult = 1;
                    // Iron Skin (M 08-13: "should be an envelopment of bone or
                    // armor briefly, not this digital blue blurr"): the generic
                    // shield burst is replaced by the bespoke iron-shell
                    // overlay drawn on the player sprite itself (Draw_64).
                    if (ab.name == "Iron Skin") {
                        vfx_timer = 0;
                        ironskin_fx_timer = 34;
                    }
                }

                if (ab.effect_type == "heal") {
                    var _self_heal_base = ab.effect_value;
                    // P3 rider (08-01): CHA 20 - a healer's bedside manner, +20%.
                    if ((ab.name == "Field Dressing" || ab.name == "Second Wind")
                        && ability_stat_rider_active(ab.name)) {
                        _self_heal_base = round(_self_heal_base * 1.20);
                    }
                    // Emergency Triage keystone (heal split 08-13): the dressing
                    // works DOUBLE on a failing body (below half HP).
                    if (ability_web_copy_has_rider(ab, "triage")
                        && player.max_HP > 0 && player.HP < player.max_HP * 0.5) {
                        _self_heal_base *= 2;
                        array_push(combat_log, "Emergency Triage - the mending works double on a failing body!");
                    }
                    // OVERCHARGE (07-16): a heal spender cast at a FULL reserve drains
                    // what's left for +2 healing per point (e.g. Blood Surge at 10 Blood:
                    // pay 2, drain the other 8, heal 14 + 16).
                    if (variable_struct_exists(player, "overcharge_armed") && player.overcharge_armed) {
                        var _och_pts = 0;
                        if      (variable_struct_exists(player, "souls"))       { _och_pts = player.souls;       player.souls = 0; }
                        else if (variable_struct_exists(player, "blood"))       { _och_pts = player.blood;       player.blood = 0; }
                        else if (variable_struct_exists(player, "preparation")) { _och_pts = player.preparation; player.preparation = 0; }
                        player.overcharge_armed = false;
                        if (_och_pts > 0) {
                            _self_heal_base += _och_pts * 2;
                            array_push(combat_log, "OVERCHARGE! The reserve empties into the mending - +" + string(_och_pts * 2) + " healing!");
                        }
                    }
                    var _heal_amt = combat_heal_after_mortality(player, _self_heal_base);
                    var _heal = min(player.max_HP - player.HP, _heal_amt);
                    player.HP += _heal;
                    if (_heal > 0) {
                        array_push(damage_popups, { value: _heal, x: 475, y: 545, timer: 45, col: c_lime });
                    }
                    array_push(combat_log, player.name + " restored " + string(_heal) + " HP.");
                    // --- Talent-web riders on self-heals (07-29 bespoke pass) ---
                    // Mender's Rite: the dressing also shakes off the newest debuff
                    // (same pop-newest idiom as Second Wind's cleanse).
                    if (ability_web_copy_has_rider(ab, "self_cleanse")
                        && variable_struct_exists(player, "status_effects") && array_length(player.status_effects) > 0) {
                        var _fd_cl = player.status_effects[array_length(player.status_effects) - 1];
                        array_delete(player.status_effects, array_length(player.status_effects) - 1, 1);
                        array_push(combat_log, "The dressing draws out "
                            + (variable_struct_exists(_fd_cl, "type") ? _fd_cl.type : "an affliction") + "!");
                    }
                    // Crimson Overflow: healing past full hardens into a shield.
                    if (ability_web_copy_has_rider(ab, "overheal_shield") && _heal_amt > _heal) {
                        var _ovh = _heal_amt - _heal;
                        player.shield_hp += _ovh;
                        array_push(combat_log, "Crimson Overflow - " + string(_ovh) + " excess mending hardens into a shield!");
                    }
                    // Heal split (M-locked 08-13): Field Dressing is TRIAGE - it
                    // always staunches your newest BLEED on cast (deepest-first
                    // scan finds the most recent one).
                    if (ab.name == "Field Dressing"
                        && variable_struct_exists(player, "status_effects")) {
                        for (var _fdb = array_length(player.status_effects) - 1; _fdb >= 0; _fdb--) {
                            var _fds = player.status_effects[_fdb];
                            if (combat_status_kind_of(_fds) == "dot" && combat_status_element(_fds) == "bleed") {
                                array_delete(player.status_effects, _fdb, 1);
                                array_push(combat_log, "The dressing staunches the bleeding!");
                                break;
                            }
                        }
                    }
                    // Cooldown stamps (generic CD gate above blocks re-casts):
                    // Field Dressing 2t; Second Wind 3t (heal split 08-13).
                    if (ab.name == "Field Dressing" || ab.name == "Second Wind")
                        player.ability_cd[selected_ability] = ability_cooldown(ab);
                }

                // --- Generic "resource" effect for SELF-targeted abilities (Soul Harvest).
                //     Mirrors the on-hit path above; revives the dead data path. ---
                if (ab.effect_type == "resource" && ab.effect_value > 0) {
                    var _sres_amt = ab.effect_value;
                    // "Reaper's Tempo" web node (P3, 07-29): +1 extra when an enemy
                    // died this round (combat_on_enemy_defeated stamps the round).
                    if (ability_web_copy_has_rider(ab, "harvest_kill")
                        && variable_global_exists("last_kill_round") && global.last_kill_round == combat_state.round) {
                        _sres_amt += 1;
                        array_push(combat_log, "Reaper's Tempo: the fresh death pays one more.");
                    }
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
                    // "Soulmend" web keystone (P3, 07-29 - the Arcanist's only
                    // self-sustain): Soul Harvest also heals 3 HP per resource gained.
                    if (ability_web_copy_has_rider(ab, "soulmend")) {
                        var _sm_heal = min(_sres_amt * 3, player.max_HP - player.HP);
                        if (_sm_heal > 0) {
                            player.HP += _sm_heal;
                            array_push(combat_log, "Soulmend: the gathered souls knit flesh (+" + string(_sm_heal) + " HP).");
                        }
                    }
                }

                // --- Iron Skin: set flat damage reduction for N turns ---
                if (ab.name == "Iron Skin") {
                    player.damage_reduction   = ab.effect_value;
                    // P3 rider (08-01): WIS 20 - the skin holds a 4th turn.
                    player.iron_skin_duration = ab.effect_duration + (ability_stat_rider_active("Iron Skin") ? 1 : 0);
                    // "Sharp Edges" web node (P3, 07-29): while the skin holds, melee
                    // blows that land take the reduction value back (fired at the
                    // enemy melee-hit sites, next to the Bloodthorn reflect).
                    player.sharp_edges_value  = ability_web_copy_has_rider(ab, "sharp_edges") ? ab.effect_value : 0;
                    array_push(combat_log,
                        "Hero activates Iron Skin - incoming damage reduced by "
                        + string(ab.effect_value) + " for " + string(player.iron_skin_duration) + " turns."
                        + ((player.sharp_edges_value > 0) ? " Its edges are SHARP." : ""));
                }

                // --- Soul Shield: add to the damage-absorbing shield pool ---
                if (ab.name == "Soul Shield") {
                    // D§3 rework (M-approved 07-09): +3 shield per Soul HELD (not
                    // spent) - the reserve-defense identity, vs Iron Skin's flat
                    // mitigation. A stocked Arcanist wards ~2x harder.
                    // "Soulweave" web node (P3, 07-29): the per-Soul rate rises to +4.
                    var _ss_rate  = ability_web_copy_has_rider(ab, "soul_dense") ? 4 : 3;
                    var _ss_bonus = variable_struct_exists(player, "souls") ? player.souls * _ss_rate : 0;
                    // P3 rider (08-01): CON 20 - a sturdier frame carries a wider ward.
                    var _ss_flat  = ability_stat_rider_active("Soul Shield") ? 5 : 0;
                    player.shield_hp += ab.effect_value + _ss_bonus + _ss_flat;
                    array_push(combat_log,
                        "Soul Shield raised - absorbs the next " + string(ab.effect_value + _ss_bonus + _ss_flat) + " damage"
                        + ((_ss_bonus > 0) ? " (+" + string(_ss_bonus) + " from Souls held)." : "."));
                }

                // --- Glacial Ward (D§4, M-approved 07-09): shield + a frozen rebuke -
                //     melee enemies that land a blow this turn are Chilled.
                if (ab.name == "Glacial Ward") {
                    if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                    player.shield_hp += ab.effect_value;
                    player.glacial_ward_turns = 1;
                    // "Deep Freeze" web keystone (task #14): stash whether the rebuke
                    // reaches RANGED attackers too (read at the rebuke site).
                    player.glacial_ward_reach_all = ability_web_copy_has_rider(ab, "ward_reach");
                    array_push(combat_log, "Glacial Ward raised - " + string(ab.effect_value)
                        + " shield; " + (player.glacial_ward_reach_all ? "ALL" : "melee") + " attackers will be Chilled.");
                }

                // --- Soul Engine (D§4): once per combat, combat-long ramp - spells
                //     gain +3 per FULL turn elapsed since it was lit.
                if (ab.name == "Soul Engine") {
                    if (variable_struct_exists(player, "soul_engine_active") && player.soul_engine_active) {
                        array_push(combat_log, "The Soul Engine already turns.");
                    } else {
                        player.soul_engine_active = true;
                        player.soul_engine_round  = combat_state.round;
                        array_push(combat_log, "SOUL ENGINE lit - your spells grow +3 for every turn that passes.");
                    }
                }

                // --- Warpath (07-16 combo batch): the Bloodwarden ramp - once per
                //     combat, combat-long: physical/Blood abilities +2 per full turn. ---
                if (ab.name == "Warpath") {
                    if (variable_struct_exists(player, "warpath_active") && player.warpath_active) {
                        array_push(combat_log, "The march is already on.");
                    } else {
                        player.warpath_active = true;
                        // "First Blood" (P3): the march starts a turn pre-lit.
                        // "Crescendo" (P3): the ramp climbs +3/turn instead of +2.
                        player.warpath_round  = combat_state.round - (ability_web_copy_has_rider(ab, "ramp_prelit") ? 1 : 0);
                        player.warpath_rate   = ability_web_copy_has_rider(ab, "ramp_fast") ? 3 : 2;
                        array_push(combat_log, "WARPATH - every turn from here hits +" + string(player.warpath_rate) + " harder"
                            + ((player.warpath_round < combat_state.round) ? " (already marching)" : "") + ".");
                    }
                }

                // --- Compounding Dread (07-16): the Shadowstrider trap ramp - each
                //     trap cast while lit permanently adds +4 trap damage this combat. ---
                if (ab.name == "Compounding Dread") {
                    if (variable_struct_exists(player, "dread_active") && player.dread_active) {
                        array_push(combat_log, "The dread already gathers.");
                    } else {
                        player.dread_active = true;
                        if (!variable_struct_exists(player, "dread_bonus")) player.dread_bonus = 0;
                        // "Crescendo" (P3): +6 per trap; "Old Fear" (P3): starts pre-lit
                        // so the FIRST trap after lighting already carries the bonus.
                        player.dread_rate = ability_web_copy_has_rider(ab, "ramp_fast") ? 6 : 4;
                        if (ability_web_copy_has_rider(ab, "ramp_prelit")) player.dread_bonus += player.dread_rate;
                        array_push(combat_log, "COMPOUNDING DREAD - every trap from here teaches the next to cut deeper (+"
                            + string(player.dread_rate) + " each" + ((player.dread_bonus > 0) ? (", +" + string(player.dread_bonus) + " already gathered") : "") + ").");
                    }
                }

                // --- Devil's Flip (D§4): the coin IS the roll - no accuracy, no
                //     dodge. Heads: your SELECTED target takes 26 (phys-mitigated).
                //     Tails: YOU take 8 (the lethal gate still applies).
                if (ab.name == "Devil's Flip") {
                    // Win streak (07-16, M-approved): +8 payout per consecutive win THIS
                    // combat; a tails resets it. EV at streak 0 unchanged (Strike parity).
                    if (!variable_struct_exists(player, "flip_streak")) player.flip_streak = 0;
                    if (irandom(1) == 0) {
                        // Resolve the selected target with the same fallback walk the
                        // cast path uses (first living enemy when selection is stale).
                        var _df_t = undefined, _df_slot = 0, _df_live = 0;
                        for (var _dfi = 0; _dfi < array_length(combat_state.combatants); _dfi++) {
                            var _dfc = combat_state.combatants[_dfi];
                            if (_dfc.is_player || _dfc.is_defeated) continue;
                            if (_df_t == undefined) { _df_t = _dfc; _df_slot = _df_live; }   // fallback: first living
                            if (_df_live == selected_target) { _df_t = _dfc; _df_slot = _df_live; break; }
                            _df_live++;
                        }
                        // "Loaded Coin" web keystone (task #14): the streak pays +12/win.
                        var _df_rate = ability_web_copy_has_rider(ab, "flip_hot") ? 12 : 8;
                        if (_df_t != undefined) {
                            var _df_base = 26 + player.flip_streak * _df_rate;
                            var _df_dmg = combat_resolve_damage(_df_base, 0, _df_t.armor, _df_t.el_resist);
                            if (_df_dmg < 1) _df_dmg = 1;
                            combat_apply_damage(_df_t, _df_dmg);
                            _df_t.hit_flash = max(_df_t.hit_flash, 12);
                            var _df_a = combat_enemy_anchor(_df_t, _df_slot);   // 2.5D: over the creature
                            array_push(damage_popups, { value: _df_dmg, x: _df_a.x, y: _df_a.y - 60, timer: 50, col: make_color_rgb(235, 190, 90) });
                            player.flip_streak += 1;
                            array_push(combat_log, "DEVIL'S FLIP - heads! " + _df_t.name + " takes " + string(_df_dmg)
                                + ((player.flip_streak >= 2) ? (" (streak " + string(player.flip_streak) + " - next flip +" + string(player.flip_streak * _df_rate) + ")") : "") + "!");
                            if (_df_t.HP <= 0) combat_on_enemy_defeated(_df_t, player, combat_log);
                        } else {
                            array_push(combat_log, "Devil's Flip finds no one to collect from.");
                        }
                    } else if (ability_web_copy_has_rider(ab, "flip_safe")) {
                        // "Devil's Insurance" web keystone (task #14): the loss costs no
                        // HP - only the streak dies.
                        array_push(combat_log, "DEVIL'S FLIP - tails! The house waves the debt"
                            + ((player.flip_streak > 0) ? (" - but the " + string(player.flip_streak) + "-win streak dies") : "") + ".");
                        player.flip_streak = 0;
                    } else {
                        combat_apply_damage(player, 8);
                        player.hit_flash = 15;
                        combat_state.player_took_damage = true;
                        array_push(damage_popups, { value: 8, x: 475, y: 545, timer: 50, col: make_color_rgb(255, 130, 60) });
                        array_push(combat_log, "DEVIL'S FLIP - tails! The house collects 8 from YOU"
                            + ((player.flip_streak > 0) ? (" - the " + string(player.flip_streak) + "-win streak dies") : "") + ".");
                        player.flip_streak = 0;
                        if (player.HP <= 0 && !combat_try_last_stand(player, combat_log)) player.is_defeated = true;
                    }
                }

                // --- Blink: staged guard over the next 3 attacks (3-turn CD, M 08-18). Only the
                //     FIRST is a guaranteed full dodge; the 2nd takes 50% dmg and the 3rd
                //     25% less if they land. Resolved in the incoming-attack block below. ---
                if (ab.name == "Blink") {
                    player.blink_charges = 3;
                    // "Afterimage Veil" web node (P3, 07-29): softening 50/25 -> 60/35.
                    player.blink_soft_rider = ability_web_copy_has_rider(ab, "blink_soft");
                    // Talent audit (M 08-17) bespoke POWER side: Steady Fade (3rd hit
                    // softened like the 2nd), Soul Flicker (+1 Soul on cast), Phase
                    // Cascade (4 charges - the 2nd attack is a full dodge too).
                    player.blink_even_rider   = ability_web_copy_has_rider(ab, "blink_even");
                    player.blink_double_rider = ability_web_copy_has_rider(ab, "blink_double");
                    if (player.blink_double_rider) player.blink_charges = 4;
                    if (ability_web_copy_has_rider(ab, "blink_soul") && variable_struct_exists(player, "souls")) {
                        player.souls = min(player.souls_max, player.souls + 1);
                        array_push(combat_log, "Soul Flicker: the blink leaves a Soul behind (+1).");
                    }
                    player.ability_cd[selected_ability] = ability_cooldown(ab);
                    // "Counterphase" web keystone (task #14): remember the rider so the
                    // full-dodge consume (enemy-turn block) can arm the AP discount.
                    player.blink_tempo_rider = ability_web_copy_has_rider(ab, "blink_tempo");
                    array_push(combat_log, "Hero blinks - the next attack is fully evaded, the two after are softened!");
                }

                // --- Shadow Step: chance to dodge each of the next 2 attacks (2-turn CD).
                //     It's a dodge CHANCE (not guaranteed), so it covers more attacks. ---
                if (ab.name == "Shadow Step") {
                    // "Long Stride" bespoke node (P3, 08-05): 4 charges instead of 3.
                    // CLASS IDENTITY PASS (M 08-13): traps gave the Shadowstrider an
                    // active answer, so Shadow Step steps back - 2 charges base
                    // (was 3), Long Stride grants 3 (was 4). CD stays 2.
                    var _ss_n = ability_web_copy_has_rider(ab, "step_charges") ? 3 : 2;
                    player.shadow_step_charges = _ss_n;
                    player.ability_cd[selected_ability] = ability_cooldown(ab);
                    array_push(combat_log, "Hero readies evasion - "
                        + string(combat_evasion_chance(player)) + "% to dodge each of the next " + string(_ss_n) + " attacks!");
                }

                // --- Counterblade: arm the riposte stance (07-29 fix - the cast never
                //     SET the flag; it was initialized, checked and cleared but never
                //     armed, so the stance had never fired). Cleared at the player's
                //     next turn start alongside the other per-turn flags. ---
                if (ab.name == "Counterblade") {
                    player.counterblade_active = true;
                    array_push(combat_log, "Counterblade raised - every melee blow will be answered with 12 physical!");
                }

                // --- Measured Riposte (Duelist Arts, DESIGN_DUELIST_CHALLENGE.md):
                //     until your next turn, the FIRST melee blow is answered at 18
                //     (150% of Counterblade). One perfect answer, then it is spent. ---
                if (ab.name == "Measured Riposte") {
                    player.measured_riposte_active = true;
                    array_push(combat_log, "Measured Riposte - the first melee blow will be answered with 18 physical!");
                }

                // --- Bloodthorn Aura: reflect flat damage on each incoming hit ---
                if (ab.name == "Bloodthorn Aura") {
                    player.bloodthorn_active   = true;
                    player.bloodthorn_duration = ab.effect_duration;
                    player.bloodthorn_value    = ab.effect_value;
                    array_push(combat_log,
                        player.name + " raises Bloodthorn Aura - reflects "
                        + string(ab.effect_value) + " damage per hit for "
                        + string(ab.effect_duration) + " turns.");
                }

                // --- Undying: arm the cheat-death (audit §6 build - consumed at the
                // lethal gate in combat_try_last_stand; fires before Last Stand). ---
                if (ab.name == "Undying") {
                    player.undying_active = true;
                    array_push(combat_log, "UNDYING armed - the next killing blow will not take you.");
                }

                // --- Evasive Roll: arm the reactive halve (audit §6 build - consumed
                // by the next incoming hit above 10 damage; absorbing it refunds 1 Prep). ---
                if (ab.name == "Evasive Roll") {
                    player.evasive_roll_armed = true;
                    array_push(combat_log, "Evasive Roll ready - the next heavy hit will be halved.");
                }

                // --- Second Wind: restore 1 secondary resource (heal handled above).
                // Heal split (08-13): the base cleanse is GONE - cleansing is the
                // "Clean Break" web node's job (two newest afflictions, below). ---
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
                    // Heal split (08-13): the BASE cleanse moved to the Field
                    // Dressing line - Second Wind only cleanses with the
                    // "Clean Break" node (two newest afflictions).
                    var _sw_pops = ability_web_copy_has_rider(ab, "cleanse_two") ? 2 : 0;
                    repeat (_sw_pops) {
                        if (variable_struct_exists(player, "status_effects") && array_length(player.status_effects) > 0) {
                            var _sw_cl = player.status_effects[array_length(player.status_effects) - 1];
                            array_delete(player.status_effects, array_length(player.status_effects) - 1, 1);
                            array_push(combat_log, "Second Wind shakes off "
                                + (variable_struct_exists(_sw_cl, "type") ? _sw_cl.type : "an affliction") + ".");
                        }
                    }
                    // "Adrenal Memory" web keystone (P3, 07-29): cast below half HP,
                    // it also snaps 1 AP back into your legs.
                    if (ability_web_copy_has_rider(ab, "adrenal_memory")
                        && player.max_HP > 0 && player.HP < player.max_HP * 0.5) {
                        player.energy += 1;
                        array_push(combat_log, "Adrenal Memory: the body remembers - +1 AP!");
                    }
                }

                // --- Adrenaline Rush (07-17 rework): once per TURN, pay 5 HP -> +1 AP.
                //     The HP-as-fuel lever; loves lifesteal builds, ruinous when bleeding out. ---
                if (ab.name == "Adrenaline Rush") {
                    // "Numbed Nerves" web node (P3, 07-29): the push costs 3 HP.
                    var _ar_cost = ability_web_copy_has_rider(ab, "rush_cheap") ? 3 : 5;
                    // "Overdrive" web keystone (P3, 07-29 - LIVETEST WATCH): once per
                    // COMBAT, the once-per-turn limit may be broken a single time.
                    var _ar_blocked = variable_struct_exists(player, "adrenaline_turn_used") && player.adrenaline_turn_used;
                    if (_ar_blocked && ability_web_copy_has_rider(ab, "overdrive")
                        && !(variable_struct_exists(player, "overdrive_used") && player.overdrive_used)) {
                        player.overdrive_used = true;
                        _ar_blocked = false;
                        array_push(combat_log, "OVERDRIVE - the nerves fire twice!");
                    }
                    if (_ar_blocked) {
                        array_push(combat_log, "Adrenaline Rush already spent this turn.");
                    } else if (player.HP <= _ar_cost) {
                        array_push(combat_log, "Not enough HP to push - Adrenaline Rush needs more than " + string(_ar_cost) + " HP.");
                    } else {
                        player.HP -= _ar_cost;
                        player.energy += 1;
                        player.adrenaline_turn_used = true;
                        array_push(combat_log, "Adrenaline Rush: " + string(_ar_cost) + " HP -> +1 AP!");
                    }
                }

                // --- Sanguine Pact: spend 8 HP (never lethal) to gain 3 Blood ---
                if (ab.name == "Sanguine Pact" && variable_struct_exists(player, "blood")) {
                    // D§3 rework (M-approved 07-09): was an HP->Blood trickle on the
                    // class that gains Blood by BEING HIT. Now the Blood DUMP defense:
                    // seal up to 3 Blood into 6 shield each.
                    var _sp_spend = min(3, player.blood);
                    if (_sp_spend <= 0) {
                        array_push(combat_log, "Sanguine Pact: no Blood to seal with.");
                    } else {
                        player.blood -= _sp_spend;
                        if (!variable_struct_exists(player, "shield_hp")) player.shield_hp = 0;
                        // "Rich Veins" web node (P3, 07-29): 7 shield per Blood sealed.
                        var _sp_rate = ability_web_copy_has_rider(ab, "pact_dense") ? 7 : 6;
                        var _sp_ward = _sp_spend * _sp_rate;
                        // OVERCHARGE (07-16): sealed at a FULL reserve, the Pact takes ALL
                        // the Blood - the first 3 at its own 6/point rate, the rest at +2.
                        if (variable_struct_exists(player, "overcharge_armed") && player.overcharge_armed) {
                            var _sp_extra = player.blood;
                            player.blood = 0;
                            player.overcharge_armed = false;
                            if (_sp_extra > 0) {
                                _sp_ward += _sp_extra * 2;
                                array_push(combat_log, "OVERCHARGE! The whole reserve seals into the ward - +" + string(_sp_extra * 2) + " shield!");
                            }
                        }
                        player.shield_hp += _sp_ward;
                        // "Blood Debt" web keystone (P3, 07-29): track the pact's share
                        // of the shield - the hit that SHATTERS it repays its full value
                        // to the attacker (resolved at the shield-absorb sites).
                        if (ability_web_copy_has_rider(ab, "blood_debt")) {
                            player.pact_shield     = (variable_struct_exists(player, "pact_shield") ? player.pact_shield : 0) + _sp_ward;
                            player.pact_debt       = _sp_ward;
                            player.pact_debt_armed = true;
                        }
                        array_push(combat_log, "Sanguine Pact: seals the Blood into a " + string(_sp_ward) + "-point ward."
                            + (ability_web_copy_has_rider(ab, "blood_debt") ? " Breaking it will cost them." : ""));
                    }
                }

                // --- Vanish: untargetable next attack; next strike deals bonus damage ---
                if (ab.name == "Vanish") {
                    player.is_untargetable    = true;
                    player.untargetable_turns = 1;
                    player.vanish_bonus       = true;
                    // "Deeper Shadow" web node (P3, 07-29): the ambush strike hits +18.
                    player.vanish_bonus_amt   = ability_web_copy_has_rider(ab, "vanish_sharp") ? 18 : 12;
                    array_push(combat_log, "Hero vanishes - "
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
    // timer - avoids a full 3-second pause on dead enemy slots
    var _actor = combat_state.active;
    if (_actor.is_player || _actor.is_defeated) {
        combat_next_turn(combat_state);
        player_turn      = combat_state.active.is_player;
        if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
        enemy_turn_timer = enemy_turn_delay;
        exit;
    }

    // Count down the delay before the enemy acts - gives the player time
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

        // Still Breath (rimefox signature move, 08-01 pillar D): the first enemy
        // to act each combat draws breath in the cold - -25% outgoing damage for
        // 2 turns. Once per combat; the flag rides the per-combat player struct.
        if (pet_active_sig_move("still_breath") && !variable_struct_exists(player, "sig_still_done")) {
            player.sig_still_done = true;
            array_push(actor.status_effects, {
                name:         "Still Breath",
                effect_type:  "debuff",
                kind:         "weaken",
                effect_value: 0.25,
                duration:     2,
                element:      "frost",
                source:       "pet"
            });
            array_push(combat_log, "[Companion] " + pet_active().name + "'s STILL BREATH settles over " + actor.name + " (-25% damage, 2 turns).");
        }

        // Held Open (doorling signature move, 08-06): the first enemy to act each
        // combat deals NO damage with that action - the way is held open. Marked
        // here with the round stamp; the attack and spell damage paths below zero
        // any damage from an actor whose stamp matches the current round.
        if (pet_active_sig_move("held_open") && !variable_struct_exists(player, "sig_door_done")) {
            player.sig_door_done = true;
            actor.sig_door_round = combat_state.round;
            array_push(combat_log, "[Companion] " + pet_active().name + " HOLDS THE WAY OPEN - "
                + actor.name + "'s opening means nothing!");
        }

        // Ink Fathom (fathom_squid signature move, 08-06): the first enemy whose
        // action would come for you loses its whole turn to the dark. A readied
        // HEAL doesn't target you - it passes, and the ink waits.
        if (pet_active_sig_move("ink_fathom") && !variable_struct_exists(player, "sig_ink_done")
            && !(variable_struct_exists(actor, "intent") && actor.intent != undefined
                 && actor.intent.eab != undefined && actor.intent.eab.kind == "heal")) {
            player.sig_ink_done = true;
            array_push(combat_log, "[Companion] " + pet_active().name + "'s INK FATHOM swallows "
                + actor.name + "'s turn - the dark keeps it!");
            enemy_roll_intent(actor, player, combat_state.round + 1, true);
            combat_next_turn(combat_state);
            player_turn = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // Gaol Chains (gaolwyrm signature move, 08-05 pillar D): the first ability
        // an elite or boss READIES against you is chained away - a 1-turn stun laid
        // before the control capture below (so it costs this very action) and the
        // planned move wiped from its intent (same wipe as smoke confound). Fires
        // only for the elite/boss itself - the first enemy slot. Once per combat.
        if (pet_active_sig_move("gaol_chains") && !variable_struct_exists(player, "sig_gaol_done")
            && variable_global_exists("next_enemy_type")
            && (global.next_enemy_type == "elite" || global.next_enemy_type == "boss")
            && variable_struct_exists(actor, "intent") && actor.intent != undefined
            && actor.intent.eab != undefined
            && variable_struct_exists(actor, "status_effects")) {
            var _gj_first = undefined;
            for (var _gj_i = 0; _gj_i < array_length(combat_state.combatants); _gj_i++) {
                if (!combat_state.combatants[_gj_i].is_player) { _gj_first = combat_state.combatants[_gj_i]; break; }
            }
            if (actor == _gj_first) {
                player.sig_gaol_done = true;
                actor.intent.eab = undefined;   // the readied move is lost in the chains
                array_push(actor.status_effects, {
                    name:         "Gaol Chains",
                    effect_type:  "debuff",
                    kind:         "stun",
                    effect_value: 0,
                    duration:     1,
                    element:      "",
                    source:       "pet"
                });
                array_push(combat_log, "[Companion] " + pet_active().name + "'s GAOL CHAINS drag " + actor.name + "'s readied move into the dark!");
            }
        }

        // THE HOLLOW CROWN (Depth Warden, 08-13): each of its turns it silences
        // one random player ability - a new pick every turn, the old one freed.
        // The fight gets quieter the longer it goes on.
        if (variable_struct_exists(actor, "warden_hook") && actor.warden_hook == "crown"
            && !actor.is_defeated && array_length(player.abilities) > 0) {
            var _hc_pick = player.abilities[irandom(array_length(player.abilities) - 1)];
            player.crown_silenced = _hc_pick.name;
            array_push(combat_log, "THE HOLLOW CROWN turns - " + _hc_pick.name + " falls SILENT.");
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
        // Mandate from Heaven (P4, 08-01): stamp each player-sourced status with
        // the round its first tick sees it (~its application round). The cleanse
        // guard treats UNSTAMPED as just-applied, so a status cleansed before it
        // ever ticked is still protected.
        for (var _mh_i = 0; _mh_i < _se_count; _mh_i++) {
            var _mh_se = actor.status_effects[_mh_i];
            if (variable_struct_exists(_mh_se, "source") && _mh_se.source == "player"
                && !variable_struct_exists(_mh_se, "applied_round")) {
                _mh_se.applied_round = combat_state.round;
            }
        }
        // Counts DoT popups spawned this tick so stacked effects (e.g. two poisons)
        // can be staggered in time/space instead of overlapping into one number.
        var _dot_pop_n = 0;
        // Aggregate DoT damage by FLAVOR (bleed/poison/void) so the combat log shows a
        // combined total per flavor instead of one line per stack naming the ability.
        var _dot_total = {};   // flavor -> summed damage this tick
        var _dot_count = {};   // flavor -> number of stacks
        for (var _si = 0; _si < _se_count; _si++) {
            var _se = actor.status_effects[_si];

            if (_se.effect_type == "dot") {
                // DoT bypasses armor - poison and bleed are internal damage
                var _dot_dmg = _se.effect_value;
                // Set Jaw (lockjaw_turtle innate, 08-06): the player's Bleeds tick
                // +N harder - once latched, it does not let go.
                if (pet_active_innate("bleed_dmg") > 0
                    && variable_struct_exists(_se, "source") && _se.source == "player"
                    && combat_status_element(_se) == "bleed") {
                    _dot_dmg += pet_active_innate("bleed_dmg");
                }
                combat_apply_damage(actor, _dot_dmg);
                // Accelerating DoT (Entropy 07-16): each tick grows by `accel` (6/8/10/12).
                if (variable_struct_exists(_se, "accel") && _se.accel > 0) _se.effect_value += _se.accel;
                // Vampiric Edge: Bloodwarden heals 2 HP per DoT tick from player effects
                if (variable_struct_exists(_se, "source") && _se.source == "player"
                    && player.class_id == 1 && trait_active("Vampiric Edge")) {
                    var _vamp_heal = round(2 * trait_potency_mult("Vampiric Edge"));
                    // TRANSCEND "Exsanguinating Feast" (POTENCY V2): doubled below 40% HP.
                    if (trait_transcended("Vampiric Edge") && player.HP <= floor(player.max_HP * 0.40)) {
                        _vamp_heal *= 2;
                    }
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
                var _dot_a  = combat_enemy_anchor(actor, _dot_slot);   // 2.5D: over the creature, not the HP-bar grid
                var _dot_ex = _dot_a.x;
                var _dot_ey = _dot_a.y;
                // Stagger stacked DoT numbers: each successive popup this tick starts
                // ~14 frames later and shifts right, so two poison stacks read "6" then "6".
                array_push(damage_popups, {
                    value: _dot_dmg,
                    x: _dot_ex + _dot_pop_n * 36,
                    y: _dot_ey - 105,
                    timer: 45,
                    delay: _dot_pop_n * 14,
                    col: make_color_rgb(255, 140, 0)
                });
                _dot_pop_n++;
                // Accumulate by flavor (logged as a combined total after the loop).
                var _dot_fl = combat_status_element(_se);
                if (_dot_fl == "") _dot_fl = "damage-over-time";
                if (!variable_struct_exists(_dot_total, _dot_fl)) {
                    variable_struct_set(_dot_total, _dot_fl, 0);
                    variable_struct_set(_dot_count, _dot_fl, 0);
                }
                variable_struct_set(_dot_total, _dot_fl, variable_struct_get(_dot_total, _dot_fl) + _dot_dmg);
                variable_struct_set(_dot_count, _dot_fl, variable_struct_get(_dot_count, _dot_fl) + 1);
                // Death from DoT - guard against a second stack re-firing the rewards.
                if (actor.HP <= 0 && !actor.is_defeated) {
                    actor.is_defeated = true;
                    enemy_death_sound(actor.name);
                    array_push(combat_log, actor.name + " succumbs to " + _dot_fl + "!");
                    // IRONMAN resume: deterministic reward stream per kill, same
                    // as the direct-kill path (loot_room_seed) - no quit-scum
                    // re-rolls. Restored right after the drop roll.
                    var _dot_lseed = random_get_seed();
                    random_set_seed(loot_room_seed(variable_struct_exists(actor, "drop_slot") ? actor.drop_slot : 0, 1));
                    // --- Gold drop on DoT kill ---
                    var _gold_drop = irandom(actor.gold_max - actor.gold_min) + actor.gold_min;
                    add_gold(_gold_drop);
                    global.current_run_kills++;
                    global.total_kills++;   // lifetime counter (see combat_on_enemy_defeated)
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
                    random_set_seed(_dot_lseed);   // back to the live stream
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
                    var _dot_xp_amt   = round(_dot_xp_base * _dot_xp_scale * awaken_xp_mult());   // Awakening XP mult (C3)
                    var _dot_xp_lvls  = grant_xp(_dot_xp_amt);
                    array_push(combat_log, "Gained " + string(_dot_xp_amt) + " XP!");
                    if (_dot_xp_lvls > 0) {
                        audio_play_sound(snd_sting_levelup, 1, false);
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

            // Decrement duration; keep effect if turns remain. Negative duration =
            // COMBAT-LONG (e.g. Soulbind's bond marker): never ticks, never expires.
            if (_se.duration < 0) {
                array_push(_se_keep, _se);
            } else {
                _se.duration--;
                if (_se.duration > 0) {
                    array_push(_se_keep, _se);
                } else {
                    // Venom Thread (pale_widow innate, 08-01): your Bleed/Poison
                    // cling one extra turn (once per application - vt_ext flags it).
                    var _vt_el = variable_struct_exists(_se, "element") ? _se.element : "";
                    if (pet_active_innate("dot_turns") > 0
                        && variable_struct_exists(_se, "source") && _se.source == "player"
                        && (_vt_el == "bleed" || _vt_el == "poison")
                        && !variable_struct_exists(_se, "vt_ext")) {
                        _se.vt_ext   = true;
                        _se.duration = pet_active_innate("dot_turns");
                        array_push(_se_keep, _se);
                        array_push(combat_log, "Venom Thread: the " + _se.name + " clings to " + actor.name + "!");
                    } else {
                        array_push(combat_log, _se.name + " wore off " + actor.name + ".");
                    }
                }
            }
        }
        actor.status_effects = _se_keep;

        // Combined DoT readout - one line per flavor with the total and stack count,
        // e.g. "Skeleton takes 11 bleed damage (2 stacks)!" instead of per-ability lines.
        var _dot_fl_names = variable_struct_get_names(_dot_total);
        for (var _dfi = 0; _dfi < array_length(_dot_fl_names); _dfi++) {
            var _dfn = _dot_fl_names[_dfi];
            var _dft = variable_struct_get(_dot_total, _dfn);
            var _dfc = variable_struct_get(_dot_count, _dfn);
            if (_dft > 0) {
                array_push(combat_log, actor.name + " takes " + string(_dft) + " " + _dfn
                    + " damage" + (_dfc > 1 ? " (" + string(_dfc) + " stacks)" : "") + "!");
            }
        }

        // Skip the attack entirely if DoT finished the enemy this frame
        if (actor.is_defeated) {
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Control: stun/root/silence may make the enemy skip its turn ---
        // INTENT: the stored plan is KEPT (the foe still intends that move next
        // turn) - the chip greys out while the control lasts, then un-greys.
        if (_was_controlled) {
            array_push(combat_log, actor.name + " " + _ctrl_reason + "!");
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // Per-attack incoming-damage multiplier for this enemy turn. Blink's 2nd/3rd
        // charge sets it below; the damage paths (spell + basic + double-strike) read it.
        var _incoming_mult = 1.0;

        // --- (07-29 fix) Classify the INCOMING ACTION before the reaction stack. ---
        // Dodges and ripostes used to run blind: Shadow Step burned a charge and
        // printed "the blow connects!" against a mob that was about to HEAL, and
        // Counterblade keyed off the mob's static reach instead of the attack it
        // is actually making. Resolve the intent first, then classify:
        //   _in_hostile  - the action targets the player at all (anything but a heal)
        //   _in_damaging - it deals damage (basic swing or damage spell)
        //   _in_melee_blow - damaging AND melee-delivered (riposte-able). An eab may
        //     carry its own reach tag (e.g. boss nukes are ranged casts even on a
        //     melee boss); otherwise delivery inherits the mob's reach.
        if (!variable_struct_exists(actor, "intent") || actor.intent == undefined) {
            enemy_roll_intent(actor, player, combat_state.round, false);
        }
        var _in_eab      = actor.intent.eab;
        var _in_hostile  = (_in_eab == undefined) || (_in_eab.kind != "heal");
        var _in_damaging = (_in_eab == undefined) || (_in_eab.kind == "spell");
        var _in_reach    = variable_struct_exists(actor, "reach") ? actor.reach : "melee";
        if (_in_eab != undefined && variable_struct_exists(_in_eab, "reach") && _in_eab.reach != "") {
            _in_reach = _in_eab.reach;
        }
        var _in_melee_blow = _in_hostile && _in_damaging && (_in_reach == "melee");

        // ---- RAGE COMBO-BREAKER (M 08-08) ----
        // Once a boss fight is 1v1 the player could rotate heals, dodges and traps
        // and take zero damage indefinitely. After a boss or elite has been DENIED
        // three times in a row - trapped, blocked, dodged or negated - its next
        // action cannot be stopped by any of those. It deals its NORMAL damage at
        // low Awakening (this is an anti-turtle valve, not a punish spike); from A3
        // up it also hits harder, because that is where stacked defence gets silly.
        // Streak lives on the actor and resets the moment a blow lands.
        // Deliberately NOT on trash: a clean defensive rotation should still feel
        // rewarding there, and Shadowstrider's whole new kit is denial.
        if (!variable_struct_exists(actor, "denied_streak")) actor.denied_streak = 0;
        // Encounter kind comes from global.next_enemy_type - the same source
        // awaken_boss_enrage_mult() uses. Enemy structs carry no is_boss/is_elite
        // field, so testing for one would have made this silently never fire.
        var _rage_kind = variable_global_exists("next_enemy_type") ? global.next_enemy_type : "";
        var _rage_elig = (_rage_kind == "boss" || _rage_kind == "elite" || global.duel_active);
        var _rage_now  = _rage_elig && _in_hostile && (actor.denied_streak >= 3);
        if (_rage_now) {
            actor.denied_streak = 0;
            array_push(combat_log, actor.name + " ROARS - the pattern breaks. This blow will not be stopped!");
            array_push(damage_popups, { value: 0, text: "RAGE!", x: 1180, y: 300, timer: 46,
                                        col: make_color_rgb(240, 90, 70) });
            // 08-09: rage shipped as text only. The burst goes on the RAGING foe,
            // using the standing position Draw stamps each frame (last_ex/last_ey
            // is the sprite's top-left, drawn at 3x), so it works wherever the
            // boss happens to sit in the row. Falls back to the popup's anchor on
            // the first frame of a fight, before Draw has stamped anything.
            var _rg_x = 1180, _rg_y = 330;
            if (variable_struct_exists(actor, "last_ex") && variable_struct_exists(actor, "last_ey")) {
                var _rg_map = enemy_sprite_map();
                var _rg_spr = variable_struct_exists(_rg_map, actor.name)
                            ? variable_struct_get(_rg_map, actor.name) : -1;
                var _rg_w = (_rg_spr >= 0) ? sprite_get_width(_rg_spr)  * 3 : 180;
                var _rg_h = (_rg_spr >= 0) ? sprite_get_height(_rg_spr) * 3 : 180;
                _rg_x = actor.last_ex + _rg_w * 0.5;
                _rg_y = actor.last_ey + _rg_h * 0.5;
            }
            array_push(vfx_bursts, { spr: spr_vfx_rage, x: _rg_x, y: _rg_y,
                                     timer: 26, timer_max: 26, school: "" });
        }

        // --- TRAPS: the floor answers first (08-08, SYSTEMS_TRAPS.md §2.3). ---
        //     Checked ahead of Blink/Shadow Step because a trap is something the
        //     player COMMITTED to in an earlier turn - it should not be wasted by a
        //     reflex dodge that would have saved them anyway. Oldest-first, and
        //     EXACTLY ONE trap springs per enemy action: that ceiling is what keeps
        //     a full board from becoming a lock.
        if (!_rage_now && variable_struct_exists(player, "traps") && is_array(player.traps)
            && array_length(player.traps) > 0) {
            var _in_spell = (_in_eab != undefined && _in_eab.kind == "spell");
            var _sprung   = -1;
            for (var _tpi = 0; _tpi < array_length(player.traps); _tpi++) {
                if (trap_matches(player.traps[_tpi], _in_hostile, _in_damaging, _in_reach, _in_spell)) {
                    _sprung = _tpi; break;
                }
            }
            if (_sprung >= 0) {
                var _tp = player.traps[_sprung];
                _tp.flash = 18;                       // chip flash, drawn by the strip

                // Payload is computed NOW, not at deploy - so Loaded Springs reads the
                // Prep you are actually holding when it goes off.
                var _tp_dmg = _tp.damage;
                var _tp_bd_prep = 0, _tp_bd_dread = 0, _tp_bd_patient = false;
                if (_tp_dmg > 0) {
                    if (player.class_id == 2 && variable_struct_exists(player, "preparation")
                        && trunk_has("prep_trap_dmg")) { _tp_bd_prep = 2 * player.preparation; _tp_dmg += _tp_bd_prep; }
                    if (variable_struct_exists(player, "dread_bonus") && player.dread_bonus > 0) {
                        _tp_bd_dread = player.dread_bonus;
                        _tp_dmg += _tp_bd_dread;
                    }
                    // "Patient Hands" (P5): a trap that waited 3+ rounds pays double.
                    if (variable_struct_exists(_tp, "r_patient") && _tp.r_patient
                        && combat_state.round - _tp.deployed_round >= 3) {
                        _tp_dmg *= 2;
                        _tp_bd_patient = true;
                        array_push(combat_log, "Patient Hands: the long wait pays DOUBLE.");
                    }
                }

                array_push(combat_log, actor.name + " springs the " + _tp.name + "!");
                // Spring conveyance v2 (M 08-13: the old flash sat low, near the log,
                // and read as nothing). The banner now lands CENTER SCREEN and the
                // trap's own flash bursts big ON the enemy that sprang it, so cause
                // and victim both read instantly.
                array_push(damage_popups, { value: 0, text: "TRAP SPRUNG - " + string_upper(_tp.name) + "!",
                                            x: 960, y: 420, timer: 55, col: trap_spring_tint(_tp.name) });
                if (variable_struct_exists(actor, "last_ex") && variable_struct_exists(actor, "last_ey")) {
                    array_push(vfx_bursts, { spr: trap_spring_vfx(_tp.name),
                                             x: variable_struct_exists(actor, "last_ecx") ? actor.last_ecx : actor.last_ex + 145, y: variable_struct_exists(actor, "last_ecy") ? actor.last_ecy : actor.last_ey + 145,
                                             timer: 24, timer_max: 24, school: "",
                                             col: trap_spring_tint(_tp.name), scale: 1.7 });
                    actor.hit_flash = 15;
                }

                // The snap burst fires ON the trap, not on the enemy - the whole
                // point of the 08-08 rework is that the trap is a THING standing
                // between the two of you. Position comes from trap_field_pos(),
                // the SAME helper ui_draw_trap_field draws with, so the burst can
                // never drift off the prop if the field is ever re-laid out.
                var _tf_pos = trap_field_pos(trap_slot_of(_tp, _sprung), trap_slots_max(player));
                array_push(vfx_bursts, { spr: trap_spring_vfx(_tp.name), x: _tf_pos.x, y: _tf_pos.y - 40,
                                         timer: 16, timer_max: 16, school: "",
                                         col: trap_spring_tint(_tp.name) });

                if (_tp_dmg > 0) {
                    actor.HP -= _tp_dmg;
                    array_push(combat_log, actor.name + " takes " + string(_tp_dmg) + " damage from the trap!");
                }
                // Trap springs read as attacks in the log (M 08-13): attach the same
                // hover breakdown a player hit gets. Rides the damage line when the
                // trap deals damage, else the "springs the trap" line itself.
                if (global.combat_log_breakdowns) {
                    var _tbd_lines = [];
                    if (_tp.damage > 0)   array_push(_tbd_lines, { label: "Trap base", val: string(_tp.damage) });
                    if (_tp_bd_prep > 0)  array_push(_tbd_lines, { label: "Loaded Springs (Prep)", val: "+" + string(_tp_bd_prep) });
                    if (_tp_bd_dread > 0) array_push(_tbd_lines, { label: "Compounding Dread", val: "+" + string(_tp_bd_dread) });
                    if (_tp_bd_patient)   array_push(_tbd_lines, { label: "Patient Hands", val: "x2" });
                    if (_tp.block)        array_push(_tbd_lines, { label: "Blocks the action", val: "yes" });
                    if (_tp.status != "") array_push(_tbd_lines, { label: "Applies", val: _tp.status + " (" + string(_tp.duration) + " turn" + (_tp.duration == 1 ? "" : "s") + ")" });
                    var _tbd = { title: _tp.name + " (trap)", total: _tp_dmg, crit: false, school: "", lines: _tbd_lines };
                    while (array_length(combat_log_detail) < array_length(combat_log) - 1)
                        array_push(combat_log_detail, undefined);
                    array_push(combat_log_detail, _tbd);
                }
                if (_tp.status != "" && !actor.is_defeated) {
                    // "exposed" is a catalog word, not a status kind: the whole Exposed
                    // family (damage-per-hit sum, detonators, payoff checks) reads kind
                    // "vulnerable". Left unmapped, Tripline's mark drew a chip and fed
                    // NOTHING (08-11 fix). +3/hit sits mid-family (Shriek 2, Shiv 4).
                    var _tp_kind = (_tp.status == "exposed") ? "vulnerable" : _tp.status;
                    // blind carries an accuracy FRACTION (Wire Snare 08-11: -35%,
                    // matching the enemy Haunting Gaze 0.20 shape).
                    var _tp_val  = (_tp.status == "bleed") ? 6
                                 : ((_tp.status == "exposed") ? 3
                                 : ((_tp.status == "blind") ? 0.35 : 1));
                    array_push(actor.status_effects, {
                        name: _tp.name, effect_type: (_tp.status == "bleed") ? "dot" : "debuff",
                        kind: _tp_kind,
                        effect_value: _tp_val,
                        duration: _tp.duration,
                        source: "player"   // the player set the trap (08-11 crash fix: the DoT tick reads source)
                    });
                }

                // Compounding Dread now compounds on a SPRING, not a cast (08-08):
                // it should reward reading the enemy correctly, not spamming deploys.
                if (variable_struct_exists(player, "dread_active") && player.dread_active) {
                    player.dread_bonus += variable_struct_exists(player, "dread_rate") ? player.dread_rate : 4;
                    array_push(combat_log, "The dread compounds - traps now +" + string(player.dread_bonus) + " damage this combat.");
                }

                // ---- keystone riders, baked in at deploy ----
                if (!actor.is_defeated && variable_struct_exists(_tp, "r_vuln") && _tp.r_vuln) {
                    array_push(actor.status_effects, { name: "Hunter's Anchor", effect_type: "debuff",
                        kind: "vulnerable", effect_value: 1, duration: 1, source: "player" });
                    array_push(combat_log, "Hunter's Anchor: " + actor.name + " is Vulnerable!");
                }
                if (!actor.is_defeated && _tp.block && variable_struct_exists(_tp, "r_stun") && _tp.r_stun) {
                    array_push(actor.status_effects, { name: "Second Chance", effect_type: "debuff",
                        kind: "stun", effect_value: 1, duration: 1, source: "player" });
                    array_push(combat_log, "Second Chance: " + actor.name + " is Stunned!");
                }
                if (_tp_dmg > 0 && variable_struct_exists(_tp, "r_splash") && _tp.r_splash) {
                    for (var _tsi = 0; _tsi < array_length(combat_state.combatants); _tsi++) {
                        var _tsc = combat_state.combatants[_tsi];
                        if (_tsc.is_player || _tsc.is_defeated || _tsc == actor) continue;
                        _tsc.HP -= _tp_dmg;
                        array_push(combat_log, _tsc.name + " catches the spread for " + string(_tp_dmg) + "!");
                        if (_tsc.HP <= 0) combat_on_enemy_defeated(_tsc, player, combat_log);
                    }
                }

                // Spend a charge; Caltrops-style traps survive to spring again.
                // "Resetting Coil" (P5, Bear Trap keystone): the FIRST spring
                // each combat re-arms the trap instead of spending it.
                if (variable_struct_exists(_tp, "r_reset") && _tp.r_reset
                    && !(variable_struct_exists(player, "trap_reset_used") && player.trap_reset_used)) {
                    player.trap_reset_used = true;
                    array_push(combat_log, "Resetting Coil: the " + _tp.name + " snaps back open, unspent!");
                } else {
                    _tp.charges -= 1;
                    if (_tp.charges <= 0) array_delete(player.traps, _sprung, 1);
                }

                if (actor.HP <= 0) combat_on_enemy_defeated(actor, player, combat_log);

                // BLOCK: the attack is cancelled and the actor's turn is spent. This is
                // the "essentially ends their turn" behaviour M asked for - but earned
                // by a correct prediction rather than granted on cast.
                if (_tp.block && !actor.is_defeated) {
                    array_push(combat_log, actor.name + "'s attack never lands!");
                    array_push(damage_popups, { value: 0, text: "BLOCKED!", x: 475, y: 505, timer: 40,
                                                col: make_color_rgb(200, 205, 220) });
                }
                if (_tp.block || actor.is_defeated) {
                    if (_tp.block) actor.denied_streak += 1;   // rage breaker (08-08)
                    enemy_roll_intent(actor, player, combat_state.round + 1, true);
                    combat_next_turn(combat_state);
                    player_turn = combat_state.active.is_player;
                    if (player_turn) {
                        abilities_used_this_turn = [];
                        if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0;
                        need_player_status_tick = true;
                    }
                    enemy_turn_timer = enemy_turn_delay;
                    exit;
                }
                // Non-blocking trap (Spike/Caltrops): the payload landed, the blow
                // still comes. Fall through to the rest of the reaction stack.
            }
        }

        // --- SUMMON INTERCEPT (class pass, M 08-13): the standing summon eats a
        //     damaging blow meant for you. Checked after traps (a set trap is a
        //     committed read that should not be wasted) and BEFORE Blink/Shadow
        //     Step (never spend a dodge on a blow the construct exists to take).
        //     The enemy's action is spent on the summon - blow, turn and all. ---
        if (!_rage_now && _in_hostile && _in_damaging
            && variable_struct_exists(player, "summon") && is_struct(player.summon)) {
            var _smn = player.summon;
            _smn.hits -= 1;
            array_push(combat_log, "The " + _smn.name + " takes " + actor.name + "'s blow meant for you!");
            array_push(vfx_bursts, { spr: spr_fx_impact, x: 590, y: 560, timer: 16, timer_max: 16, school: "" });
            if (_smn.hits <= 0) {
                array_push(combat_log, "The " + _smn.name + " crumbles, spent"
                    + ((_smn.kind == "golem") ? " - its fire dies with it." : "."));
                player.summon = undefined;
            }
            actor.denied_streak += 1;   // rage breaker, same as a blocking trap
            enemy_roll_intent(actor, player, combat_state.round + 1, true);
            combat_next_turn(combat_state);
            player_turn = combat_state.active.is_player;
            if (player_turn) {
                abilities_used_this_turn = [];
                if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0;
                need_player_status_tick = true;
            }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Blink: staged guard. 1st incoming attack = guaranteed full dodge; 2nd
        //     takes 50% damage; 3rd takes 25% less; then it ends. One charge consumed
        //     per enemy turn so it spans multiple foes (the 2-4 mob case). ---
        if (!_rage_now && _in_hostile && player.blink_charges >= 3) {
            actor.denied_streak += 1;   // rage breaker (08-08)
            // Phase Cascade (4 charges): 4 -> 3 keeps a SECOND full dodge queued.
            player.blink_charges = (player.blink_charges >= 4) ? 3 : 2;
            array_push(combat_log, actor.name + "'s attack passes through thin air!");
            player.dodge_anim = 14;   // conveyance: visible sidestep
            array_push(damage_popups, { value: 0, text: "DODGED!", x: 475, y: 505, timer: 40, col: make_color_rgb(200, 205, 220) });
            // "Counterphase" web keystone (task #14): the full evade arms a 1-AP
            // discount on the caster's next ability (consumed at cast commit).
            if (variable_struct_exists(player, "blink_tempo_rider") && player.blink_tempo_rider) {
                player.blink_tempo_ready = true;
                array_push(combat_log, "Counterphase: the missed swing feeds your tempo - next ability costs 1 less AP!");
            }
            enemy_roll_intent(actor, player, combat_state.round + 1, true);   // action spent on the whiff
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        } else if (_in_damaging && player.blink_charges == 2) {
            // "Afterimage Veil" web node (P3): 50% -> 60% softening.
            var _bl_soft2 = (variable_struct_exists(player, "blink_soft_rider") && player.blink_soft_rider) ? 0.40 : 0.5;
            _incoming_mult *= _bl_soft2;   // 2nd attack softened if it lands
            player.blink_charges = 1;
            array_push(combat_log, "A blink afterimage softens the blow (" + string(round((1 - _bl_soft2) * 100)) + "% reduced)!");
        } else if (_in_damaging && player.blink_charges == 1) {
            // "Afterimage Veil" web node (P3): 25% -> 35% softening.
            var _bl_soft3 = (variable_struct_exists(player, "blink_soft_rider") && player.blink_soft_rider) ? 0.65 : 0.75;
            // Steady Fade (P1, 08-17): the 3rd hit is softened as much as the 2nd.
            if (variable_struct_exists(player, "blink_even_rider") && player.blink_even_rider) _bl_soft3 -= 0.25;
            _incoming_mult *= _bl_soft3;   // 3rd attack softened if it lands
            player.blink_charges = 0;
            array_push(combat_log, "Blink's last shimmer dampens the hit (" + string(round((1 - _bl_soft3) * 100)) + "% reduced)!");
        }

        // --- Vanish: chance-based untargetable window (Wisdom-scaled). Consumes one
        //     charge per incoming attack; whiffs on a successful roll, else falls through. ---
        if (_in_hostile && player.is_untargetable) {
            player.untargetable_turns--;
            if (player.untargetable_turns <= 0) player.is_untargetable = false;
            if (irandom(99) < combat_evasion_chance(player)) {
                array_push(combat_log, actor.name + "'s attack passes through thin air!");
                player.dodge_anim = 14;   // conveyance: visible sidestep
                array_push(damage_popups, { value: 0, text: "DODGED!", x: 475, y: 505, timer: 40, col: make_color_rgb(200, 205, 220) });
                enemy_roll_intent(actor, player, combat_state.round + 1, true);   // action spent on the whiff
                combat_next_turn(combat_state);
                player_turn      = combat_state.active.is_player;
                if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
                enemy_turn_timer = enemy_turn_delay;
                exit;
            } else {
                array_push(combat_log, "The vanish falters - " + actor.name + " finds its mark!");
            }
        }

        // --- Counterblade (07-17): riposte stance - a MELEE BLOW is answered with 12
        //     physical, whether it lands or is dodged. (07-29 fix) Keys off the attack
        //     the enemy is ACTUALLY making - a melee-delivered damage spell triggers it,
        //     a ranged spell or a hex/heal does not, regardless of the mob's class.
        //     Fires once per attacking melee enemy (each enemy runs this section on its
        //     own turn); the stance clears at the player's next turn start. A riposte
        //     that kills ends that enemy's turn. ---
        if (variable_struct_exists(player, "counterblade_active") && player.counterblade_active
            && _in_melee_blow
            && !actor.is_defeated) {
            var _cb_dmg = combat_resolve_damage(12, 0, actor.armor, actor.el_resist);
            if (_cb_dmg < 1) _cb_dmg = 1;
            combat_apply_damage(actor, _cb_dmg);
            actor.hit_flash = max(actor.hit_flash, 10);
            array_push(combat_log, "Counterblade ripostes " + actor.name + " for " + string(_cb_dmg) + "!");
            // The Ashen Blade: a riposte arms -1 AP on your next ability.
            if (player.leg_ashen && !player.ashen_tempo_ready) {
                player.ashen_tempo_ready = true;
                array_push(combat_log, "The Ashen Blade hums - your next ability costs 1 less AP.");
            }
            if (actor.HP <= 0 && !actor.is_defeated) {
                combat_on_enemy_defeated(actor, player, combat_log);
                combat_next_turn(combat_state);
                player_turn = combat_state.active.is_player;
                if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
                enemy_turn_timer = enemy_turn_delay;
                exit;
            }
        }

        // --- Measured Riposte (Duelist Arts): the FIRST melee blow until your next
        //     turn is answered at 18 - then the answer is spent. Same per-attack
        //     melee classification as Counterblade; the two stack (both fire). ---
        if (variable_struct_exists(player, "measured_riposte_active") && player.measured_riposte_active
            && _in_melee_blow
            && !actor.is_defeated) {
            player.measured_riposte_active = false;
            var _mr_dmg = combat_resolve_damage(18, 0, actor.armor, actor.el_resist);
            if (_mr_dmg < 1) _mr_dmg = 1;
            combat_apply_damage(actor, _mr_dmg);
            actor.hit_flash = max(actor.hit_flash, 10);
            array_push(combat_log, "Measured Riposte! " + actor.name + " takes " + string(_mr_dmg) + " for the approach.");
            // The Ashen Blade: a riposte arms -1 AP on your next ability.
            if (player.leg_ashen && !player.ashen_tempo_ready) {
                player.ashen_tempo_ready = true;
                array_push(combat_log, "The Ashen Blade hums - your next ability costs 1 less AP.");
            }
            if (actor.HP <= 0 && !actor.is_defeated) {
                combat_on_enemy_defeated(actor, player, combat_log);
                combat_next_turn(combat_state);
                player_turn = combat_state.active.is_player;
                if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
                enemy_turn_timer = enemy_turn_delay;
                exit;
            }
        }

        // --- Shadow Step: dodge CHANCE on each of the next 2 attacks (charge-based) ---
        if (!_rage_now && _in_hostile && player.shadow_step_charges > 0) {
            player.shadow_step_charges--;
            // "Sharpened Instinct" bespoke node (08-11 web rework): +10% dodge
            // chance while charges are live. Read off the SLOTTED copy, same
            // idiom as Phantom Momentum below.
            var _ss_ev = 0;
            if (variable_struct_exists(player, "abilities")) {
                for (var _sei = 0; _sei < array_length(player.abilities); _sei++) {
                    var _sea = player.abilities[_sei];
                    if (_sea.name == "Shadow Step") { _ss_ev = ability_web_rider_value(_sea, "step_evade", 0); break; }
                }
            }
            if (irandom(99) < combat_evasion_chance(player) + _ss_ev) {
                array_push(combat_log, actor.name + "'s attack is dodged!");
                player.dodge_anim = 14;   // conveyance: visible sidestep
                array_push(damage_popups, { value: 0, text: "DODGED!", x: 475, y: 505, timer: 40, col: make_color_rgb(200, 205, 220) });
                // "Phantom Momentum" bespoke node (P3, 08-05): each successful
                // Shadow Step dodge feeds the engine. Rider read off the SLOTTED
                // copy (Unbroken idiom) - the cast copy is long gone by now.
                if (variable_struct_exists(player, "preparation") && variable_struct_exists(player, "abilities")) {
                    for (var _pmi = 0; _pmi < array_length(player.abilities); _pmi++) {
                        var _pma = player.abilities[_pmi];
                        if (_pma.name == "Shadow Step" && ability_web_copy_has_rider(_pma, "step_dodge_prep")) {
                            player.preparation = min(player.preparation_max, player.preparation + 1);
                            array_push(combat_log, "Phantom Momentum: the slip is fuel - +1 Prep.");
                            break;
                        }
                    }
                }
                enemy_roll_intent(actor, player, combat_state.round + 1, true);   // action spent on the whiff
                combat_next_turn(combat_state);
                player_turn      = combat_state.active.is_player;
                if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
                enemy_turn_timer = enemy_turn_delay;
                exit;
            } else {
                array_push(combat_log, "The dodge mistimes - " + actor.name + " isn't shaken!");
            }
        }

        // --- Check Phantom Step (auto-miss the very first enemy attack each combat) ---
        if (_in_hostile && combat_check_phantom_step(player, combat_log)) {
            player.dodge_anim = 14;   // conveyance: visible sidestep
            array_push(damage_popups, { value: 0, text: "DODGED!", x: 475, y: 505, timer: 40, col: make_color_rgb(200, 205, 220) });
            enemy_roll_intent(actor, player, combat_state.round + 1, true);   // action spent on the auto-miss
            combat_next_turn(combat_state);
            player_turn      = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Enemy special ability (Difficulty Pass - see SYSTEMS_ENEMY_DIFFICULTY.md) ---
        // If an ability procs it consumes the enemy's whole turn (instead of the basic
        // attack). Statuses applied to the player ride the existing typed-status layer;
        // duration gets +1 (except DoT) to survive the start-of-player-turn tick.
        // INTENT (INTENT_SPEC.md): the action was already rolled at the end of this
        // enemy's previous turn (or at combat start) and telegraphed on its chip -
        // execute the stored plan. Lazy fallback covers any enemy without one.
        if (!variable_struct_exists(actor, "intent") || actor.intent == undefined) {
            enemy_roll_intent(actor, player, combat_state.round, false);
        }
        var _eab = actor.intent.eab;
        if (_eab != undefined) {
            // Warden's Seal (vaultling signature move, 08-05 pillar D): the first
            // enemy ABILITY that would hit you breaks against the seal - negated
            // outright, the action spent. Heals pass (they don't strike you); a
            // basic attack never triggers it. Once per combat via the player flag.
            if (_eab.kind != "heal" && _eab.kind != "summon" && pet_active_sig_move("wardens_seal")
                && !variable_struct_exists(player, "sig_seal_done")) {
                player.sig_seal_done = true;
                array_push(combat_log, "[Companion] " + pet_active().name + "'s WARDEN'S SEAL flares - " + actor.name + "'s " + _eab.name + " breaks against it!");
                // Action spent: roll the next intent and advance, same as a resolved ability.
                enemy_roll_intent(actor, player, combat_state.round + 1, true);
                combat_next_turn(combat_state);
                player_turn = combat_state.active.is_player;
                if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
                enemy_turn_timer = enemy_turn_delay;
                exit;
            }
            // Abdication (griefwisp signature move, 08-06): the first ability an
            // elite or boss spends against you costs it its NEXT turn - the crown
            // weighs. The ability itself still resolves; the 1-turn stun is read
            // pre-tick at its next turn start, so the throne sits empty exactly once.
            if (pet_active_sig_move("abdication") && !variable_struct_exists(player, "sig_crownfall_done")
                && variable_global_exists("next_enemy_type")
                && (global.next_enemy_type == "elite" || global.next_enemy_type == "boss")
                && _eab.kind != "heal"
                && variable_struct_exists(actor, "status_effects")) {
                player.sig_crownfall_done = true;
                array_push(actor.status_effects, {
                    name:         "Abdication",
                    effect_type:  "debuff",
                    kind:         "stun",
                    effect_value: 0,
                    duration:     1,
                    element:      "",
                    source:       "pet"
                });
                array_push(combat_log, "[Companion] " + pet_active().name + "'s ABDICATION - "
                    + actor.name + "'s next turn is forfeit to the hollow crown!");
            }
            // Living-slot index + the SHARED position helper (2.5D v3): casts now
            // launch from where the caster is actually drawn, at every depth.
            var _sa_slot = 0;
            for (var _sai = 0; _sai < array_length(combat_state.combatants); _sai++) {
                if (combat_state.combatants[_sai] == actor) break;
                if (!combat_state.combatants[_sai].is_player && !combat_state.combatants[_sai].is_defeated) _sa_slot++;
            }
            var _sa_p = (combat_25d() && variable_struct_exists(actor, "stage_station"))
                      ? actor.stage_station : combat_enemy_slot_pos(_sa_slot);
            var _sa_x = _sa_p.x;
            var _sa_y = _sa_p.y;

            // Family-themed attack/cast sound for any offensive ability (not heals).
            if (_eab.kind != "heal") enemy_attack_sound(actor.name);

            if (_eab.kind == "heal") {
                // C1 A3+ SMART TARGETING (M-approved 07-09): the mend goes to the MOST
                // WOUNDED living ally (itself included), not blindly to itself.
                var _htgt = actor;
                if ((variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) >= 3) {
                    var _worst = (actor.max_HP > 0) ? (actor.HP / actor.max_HP) : 1;
                    for (var _hti = 0; _hti < array_length(combat_state.combatants); _hti++) {
                        var _htc = combat_state.combatants[_hti];
                        if (_htc.is_player || _htc.is_defeated || _htc.max_HP <= 0) continue;
                        var _hfrac = _htc.HP / _htc.max_HP;
                        if (_hfrac < _worst) { _worst = _hfrac; _htgt = _htc; }
                    }
                }
                // Popup lands on the healed TARGET's slot, not the caster's.
                var _ht_slot = 0;
                for (var _hsi = 0; _hsi < array_length(combat_state.combatants); _hsi++) {
                    if (combat_state.combatants[_hsi] == _htgt) break;
                    if (!combat_state.combatants[_hsi].is_player && !combat_state.combatants[_hsi].is_defeated) _ht_slot++;
                }
                // GLYPH CAST VFX (M 08-13: "when pale archivist traces a
                // restorative glyph and heals it would be cool if an actual
                // glyph appears and then the restorative effect takes place"):
                // a gold rune ring traced at the target's feet (glyph_fx,
                // drawn under the sprites), then the green mend burst blooms
                // as the trace completes (delayed vfx_bursts entry).
                var _ht_pv = (combat_25d() && variable_struct_exists(_htgt, "stage_station"))
                           ? _htgt.stage_station : combat_enemy_slot_pos(_ht_slot);
                array_push(glyph_fx, { x: _ht_pv.cx, y: _ht_pv.feet - 6, t: 0, dur: 36,
                                       col: make_color_rgb(255, 215, 120) });
                array_push(vfx_bursts, { spr: spr_vfx_heal, x: _ht_pv.cx, y: _ht_pv.cy,
                    timer: 22, timer_max: 22, school: "", delay: 30 });
                // Scale by Awakening, then reduce by the target's Mortality (anti-heal). (P6)
                var _eheal_raw = round(_eab.value * awaken_enemy_heal_mult());
                var _eheal_amt = combat_heal_after_mortality(_htgt, _eheal_raw);
                var _ehl = min(_htgt.max_HP - _htgt.HP, _eheal_amt);
                _htgt.HP += _ehl;
                // Guarded (08-13 crash): a summoned ally may not carry the
                // transient fields yet on older saves mid-combat.
                _htgt.hit_flash = max(variable_struct_exists(_htgt, "hit_flash") ? _htgt.hit_flash : 0, 6);
                if (_ehl > 0) {
                    // Popup waits for the glyph trace to complete (delay ~30).
                    array_push(damage_popups, { value: _ehl, x: _ht_pv.cx, y: _ht_pv.cy - 90, timer: 45, delay: 30, col: c_lime });
                }
                if (_ehl <= 0 && combat_has_status(_htgt, "mortality")) {
                    array_push(combat_log, actor.name + "'s mending is suppressed!");
                } else if (_htgt != actor) {
                    array_push(combat_log, actor.name + " mends " + _htgt.name + " for " + string(_ehl) + " HP!");
                } else {
                    array_push(combat_log, actor.name + " " + ((_eab.msg != "") ? _eab.msg : ("mends " + string(_ehl) + " HP")) + ".");
                }
                // A2+ CLEANSE RIDER (M 07-28 AI pass): the mend also shakes hostile
                // statuses off its target - controls first, so a support enemy can
                // free a snared ally. One status at A2+, two at A4+. Same
                // awakening-gated-smarts idiom as the A3 targeting above.
                var _cl_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
                if (_cl_asc >= 2) {
                    var _cl_n = (_cl_asc >= 4) ? 2 : 1;
                    repeat (_cl_n) {
                        var _cl_name = combat_cleanse_one(_htgt);
                        if (_cl_name == "") {
                            // Mandate from Heaven (P4): the seal held - say so, so
                            // the 2000g purchase is FELT every time it matters.
                            if (combat_any_mandate_protected(_htgt)) {
                                array_push(combat_log, actor.name + "'s mending falters - the MANDATE holds your claim!");
                            }
                            break;
                        }
                        array_push(combat_log, actor.name + "'s mending unravels " + _cl_name + "!");
                    }
                }

            } else if (_eab.kind == "summon") {
                // SUMMONS (08-13, M-locked): the caster calls one standard-pool mob
                // mid-fight. Arrives winded (60% HP, Awakening-scaled) and joins the
                // END of the turn order. enemy_pick_ability never readies this onto
                // a full field, but re-check the 4-cap here for AoE-kill edge cases.
                var _su_n = 0;
                for (var _su_i = 0; _su_i < array_length(combat_state.combatants); _su_i++) {
                    var _su_c = combat_state.combatants[_su_i];
                    if (!_su_c.is_player && !_su_c.is_defeated) _su_n++;
                }
                // A5 BOSS ESCALATION (M 08-13): a summoning BOSS - Sovereign,
                // Archivist boss, or a Depth Warden carrying the call - raises
                // ELITE reinforcements at Awakening 5. Everyone else keeps the
                // dungeon's standard roster.
                var _su_src   = variable_instance_exists(id, "summon_pool") ? summon_pool : [];
                var _su_elite = false;
                if ((variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0) >= 5
                    && variable_instance_exists(id, "summon_is_boss_fight") && summon_is_boss_fight
                    && variable_instance_exists(id, "summon_pool_elite") && array_length(summon_pool_elite) > 0) {
                    _su_src   = summon_pool_elite;
                    _su_elite = true;
                }
                // Candidate filter (M 08-13 crash report: "pale archivist seems
                // to have summoned himself"): never a copy of the CALLER, and
                // summoners never call other summoners - calls cannot chain.
                var _su_cands = [];
                {
                    for (var _sc_i = 0; _sc_i < array_length(_su_src); _sc_i++) {
                        var _sc_t = _su_src[_sc_i];
                        if (_sc_t.name == actor.name) continue;
                        var _sc_summoner = false;
                        if (variable_struct_exists(_sc_t, "abilities") && is_array(_sc_t.abilities)) {
                            for (var _sc_a = 0; _sc_a < array_length(_sc_t.abilities); _sc_a++)
                                if (_sc_t.abilities[_sc_a].kind == "summon") { _sc_summoner = true; break; }
                        }
                        if (!_sc_summoner) array_push(_su_cands, _sc_t);
                    }
                }
                if (_su_n < 4 && array_length(_su_cands) > 0) {
                    var _su_new = enemy_clone(_su_cands[irandom(array_length(_su_cands) - 1)]);
                    // Combat-ready transients (08-13 crash fix: the raw clone
                    // lacked hit_flash - the A3 smart-heal read it unguarded the
                    // moment it targeted a summoned ally and crashed).
                    _su_new.hit_flash     = 0;
                    _su_new.hit_recoil    = 0;
                    _su_new.dodge_anim    = 0;
                    _su_new.denied_streak = 0;
                    var _su_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
                    if (_su_asc > 0) {
                        _su_new.max_HP = round(_su_new.max_HP * awaken_hp_mult(_su_asc));
                        _su_new.damage = round(_su_new.damage * awaken_dmg_mult(_su_asc));
                        _su_new.telegraph_damage = round(_su_new.telegraph_damage * awaken_dmg_mult(_su_asc));
                    }
                    _su_new.max_HP = max(1, round(_su_new.max_HP * 0.60));
                    _su_new.HP     = _su_new.max_HP;
                    // Descant (chorister_fry signature move, 08-06): the first summon
                    // an enemy calls arrives at 1 HP - sung down before it lands.
                    if (pet_active_sig_move("descant") && !variable_struct_exists(player, "sig_descant_done")) {
                        player.sig_descant_done = true;
                        _su_new.HP = 1;
                        array_push(combat_log, "[Companion] " + pet_active().name + "'s DESCANT undercuts the call - "
                            + _su_new.name + " arrives at 1 HP!");
                    }
                    array_push(combat_state.combatants, _su_new);
                    // The newborn telegraphs like everyone else from its first frame.
                    enemy_roll_intent(_su_new, player, combat_state.round + 1, true);
                    array_push(combat_log, actor.name + " " + ((_eab.msg != "") ? _eab.msg : "calls for aid")
                        + " - " + (_su_elite ? ("an ELITE answers: " + _su_new.name + " joins the fight!")
                                             : (_su_new.name + " joins the fight!")));
                    screen_shake_timer = max(screen_shake_timer, _su_elite ? 14 : 8);
                } else {
                    array_push(combat_log, actor.name + " calls into the dark - nothing answers.");
                }

            } else if (_eab.kind == "stance") {
                // DUELIST T2 PERFECT PARRY (08-13, M-locked): he settles into a
                // guard - the next melee blow he takes is turned aside outright
                // and his riposte answers it DOUBLE (the intercept lives at the
                // player damage-application site).
                actor.parry_armed = true;
                array_push(combat_log, actor.name + " " + ((_eab.msg != "") ? _eab.msg : "takes a guarded stance")
                    + " - the next melee blow will be TURNED.");

            } else if (_eab.kind == "spell") {
                // A5 boss enrage applies to spells too (same helper as the swing path).
                var _sdmg = combat_mitigate_player(player,
                    max(1, round(_eab.value * awaken_boss_enrage_mult(combat_state.round))), _eab.dtype, combat_log);
                if (_incoming_mult < 1.0) _sdmg = max(1, round(_sdmg * _incoming_mult));  // Blink softening
                // Held Open (doorling sig move): the first actor's stamped action
                // deals nothing - the door takes the blow.
                if (variable_struct_exists(actor, "sig_door_round") && actor.sig_door_round == combat_state.round
                    && _sdmg > 0) {
                    _sdmg = 0;
                    array_push(combat_log, "[Companion] The way stands HELD OPEN - " + actor.name + "'s cast spends itself on the door.");
                }
                if (_sdmg > 0) combat_state.player_took_damage = true;
                combat_apply_damage(player, _sdmg);
                play_player_vocal("snd_player_hurt", -1);
                // Conveyance (08-04): a RANGED-delivered spell now FLIES to you (dtype-
                // keyed bolt; flash/shake/popup/HP-drain defer to arrival). A melee-
                // delivered spell keeps the lunge. The ability's own reach wins over
                // the mob's (a melee boss can still hurl a ranged nuke).
                var _sp_reach = (variable_struct_exists(_eab, "reach") && _eab.reach != "")
                    ? _eab.reach
                    : (variable_struct_exists(actor, "reach") ? actor.reach : "melee");
                var _sp_delay = 0;
                if (_sp_reach == "ranged") {
                    _sp_delay = 15 + array_length(combat_projectiles) * 4;
                    var _sp_bolt = spr_vfx_arcane; var _sp_hit = spr_vfx_arcane; var _sp_sch = "arcane";
                    var _sp_bx = 415; var _sp_by = 560;   // burst anchor (center-origin spr_vfx_*)
                    switch (_eab.dtype) {
                        // spr_fx_impact is TOP-LEFT origin - anchor it like the shipped
                        // enemy hit spark (300,450) so the burst centers on the player.
                        case 0: _sp_bolt = -1;            _sp_hit = spr_fx_impact; _sp_sch = "";      _sp_bx = 300; _sp_by = 450; break;
                        // dtype 1 (elemental) previously fell through to the arcane
                        // default - a Fire Drake's Cinder Breath flew as purple (M
                        // 08-13 VFX pass). It now reads the caster's family school.
                        case 1:
                            _sp_sch  = enemy_attack_school(actor.name);
                            if (_sp_sch == "") _sp_sch = "arcane";
                            _sp_bolt = school_bolt_sprite(_sp_sch);
                            _sp_hit  = _sp_bolt;
                            break;
                        case 2: _sp_bolt = spr_vfx_void;  _sp_hit = spr_vfx_void;  _sp_sch = "void";  break;
                        case 3: _sp_bolt = spr_vfx_blood; _sp_hit = spr_vfx_blood; _sp_sch = "blood"; break;
                    }
                    // 2.5D: fly to the live player anchor, not the flat-mode spot.
                    var _sp_tx = 415, _sp_ty = 560;
                    if (combat_25d()) {
                        var _sp_pa = combat_player_vfx_anchor(player);
                        _sp_tx = _sp_pa.x + 110; _sp_ty = _sp_pa.y + 110;
                        _sp_bx = (_sp_bolt == -1) ? _sp_pa.x : _sp_tx;   // impact spark is top-left origin
                        _sp_by = (_sp_bolt == -1) ? (_sp_pa.y + 60) : _sp_ty;
                    }
                    array_push(combat_projectiles, {
                        spr: _sp_bolt, school: _sp_sch, impact_spr: _sp_hit, ticks: 20,
                        sx: _sa_x + 90, sy: _sa_y + 90, tx: _sp_tx, ty: _sp_ty,
                        bx: _sp_bx, by: _sp_by,
                        t: 0, dur: 15, delay: _sp_delay - 15, tgt: player, shake: 12
                    });
                    player.hp_hold = _sp_delay;
                } else {
                    player.hit_flash = 15; player.hit_recoil = 10; screen_shake_timer = 12;
                    attack_anim_timer = 20; attack_anim_src_x = _sa_x; attack_anim_src_y = _sa_y;
                    // 2.5D: horizontal lunge at own depth (see the melee branch note).
                    attack_anim_dst_x = combat_25d() ? (combat_player_vfx_anchor(player).x + 280) : 435;
                    attack_anim_dst_y = combat_25d() ? _sa_y : 465;
                    attack_anim_is_player = false; attack_anim_enemy_idx = _sa_slot;
                }
                array_push(damage_popups, { value: _sdmg, x: 475, y: 545, timer: 50, delay: _sp_delay, col: make_color_rgb(255, 130, 60) });
                array_push(combat_log, actor.name + " " + ((_eab.msg != "") ? _eab.msg : "casts a spell") + " for " + string(_sdmg) + " damage!");
                // --- "Sharp Edges" (P3): a MELEE-delivered damage spell still counts
                //     as a melee blow - the iron answers it too. ---
                if (variable_struct_exists(player, "sharp_edges_value") && player.sharp_edges_value > 0
                    && player.iron_skin_duration > 0 && _in_melee_blow && !actor.is_defeated) {
                    combat_apply_damage(actor, player.sharp_edges_value);
                    actor.hit_flash = max(actor.hit_flash, 8);
                    array_push(combat_log, "Sharp Edges: " + actor.name + " cuts itself on the iron for " + string(player.sharp_edges_value) + "!");
                    if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
                }
                // --- "Blood Debt" (P3): a spell can shatter the pact ward too
                //     (combat_mitigate_player flagged it; the attacker is known here). ---
                if (variable_struct_exists(player, "pact_debt_due") && player.pact_debt_due) {
                    player.pact_debt_due   = false;
                    player.pact_debt_armed = false;
                    if (player.pact_debt > 0 && !actor.is_defeated) {
                        combat_apply_damage(actor, player.pact_debt);
                        actor.hit_flash = max(actor.hit_flash, 12);
                        array_push(combat_log, "BLOOD DEBT - the shattered pact repays " + actor.name + " with " + string(player.pact_debt) + "!");
                        if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
                    }
                    player.pact_debt = 0;
                }
                if (player.class_id == 1 && variable_struct_exists(player, "blood")) player.blood = min(player.blood_max, player.blood + 1);
                if (player.HP <= 0 && !combat_try_last_stand(player, combat_log)) player.is_defeated = true;

            } else {
                // debuff / dot / control -> typed status on the player
                // PURE-DEBUFF CAST VFX (08-14, the last VFX-less action class):
                // the caster traces a BALEFUL rune at your feet - ember for
                // DoTs, violet for debuffs/control - and a dark burst blooms as
                // the trace completes. Hostile mirror of the Restorative Glyph
                // idiom above; shown even when Iron Will / Nothing Follows eats
                // the effect (the cast still happened - the log tells the save).
                var _db_pa  = combat_player_vfx_anchor(player);
                var _db_dot = (_eab.kind == "dot");
                array_push(glyph_fx, { x: _db_pa.x, y: _db_pa.y + 180, t: 0, dur: 36,
                                       col: _db_dot ? make_color_rgb(225, 115, 55) : make_color_rgb(170, 110, 235) });
                array_push(vfx_bursts, { spr: spr_vfx_void, x: _db_pa.x, y: _db_pa.y,
                    timer: 22, timer_max: 22, school: _db_dot ? "fire" : "void", delay: 30 });
                // Nothing Follows (null_hound signature move, 08-06): the first
                // debuff aimed at you each combat is erased before it lands.
                // Checked BEFORE Iron Will so the absence spares the absorb charge.
                if (pet_active_sig_move("nothing_follows")
                    && !variable_struct_exists(player, "sig_nothing_done")) {
                    player.sig_nothing_done = true;
                    array_push(combat_log, "[Companion] " + pet_active().name + " - NOTHING FOLLOWS. "
                        + actor.name + "'s " + _eab.name + " simply never happened.");
                } else if (variable_struct_exists(player, "iron_will_active") && player.iron_will_active) {
                    player.iron_will_active = false;
                    // TRANSCEND "Unshakable" (POTENCY V2): the absorbed KIND is
                    // banned for the rest of the combat (checked below).
                    if (trait_transcended("Iron Will")) player.iron_will_banned = _eab.status_kind;
                    array_push(combat_log, "Iron Will absorbs " + actor.name + "'s " + _eab.name + "!");
                } else if (variable_struct_exists(player, "iron_will_banned")
                    && player.iron_will_banned != "" && player.iron_will_banned == _eab.status_kind) {
                    array_push(combat_log, "Unshakable: " + _eab.name + " cannot take hold of you again!");
                } else if (_eab.kind != "dot" && irandom(99) < combat_stat_resist_pct(player, _eab.status_kind)) {
                    // STAT RESIST (08-16): CON shrugs Stun, WIS shrugs Silence/Weaken,
                    // DEX shrugs Root - 0.5% per point, capped 15%. DoTs are not
                    // shrugged; CON softens their bite below instead.
                    var _sr_stat = (_eab.status_kind == "stun") ? "Constitution"
                                 : ((_eab.status_kind == "root") ? "Dexterity" : "Wisdom");
                    array_push(combat_log, "Your " + _sr_stat + " shrugs off " + actor.name + "'s " + _eab.name + "!");
                } else {
                    var _edur = (_eab.kind == "dot") ? _eab.turns : (_eab.turns + 1);
                    // Iron Will potency ranks (POTENCY V2): later statuses run
                    // -10% duration per rank (floors at 1 turn).
                    var _iw_r = trait_potency_r14("Iron Will");
                    if (_iw_r > 0) _edur = max(1, floor(_edur * (1 - 0.10 * _iw_r)));
                    // Warding V2 (Shrine 07-29): hostile afflictions run 1 turn shorter.
                    if (boon_active("warding")) _edur = max(1, _edur - 1);
                    // Slow Thaw / Weathered (permafrost_toad / bark_hound innates,
                    // 08-06): the first Burn/Poison laid on the player each combat
                    // ticks at half strength (shares its flag with the Scorching Air
                    // site in Create, so only ONE first-DoT is softened per combat).
                    var _eab_val = _eab.value;
                    // CON softens DoT ticks (08-16 stat resists): -0.5%/pt, cap 15%.
                    if (_eab.kind == "dot") {
                        var _sr_dot = combat_stat_resist_pct(player, "dot");
                        if (_sr_dot > 0) _eab_val = max(1, round(_eab_val * (1 - _sr_dot / 100)));
                    }
                    if (_eab.kind == "dot" && pet_active_innate("dot_halve") > 0
                        && !variable_struct_exists(player, "innate_thaw_done")) {
                        player.innate_thaw_done = true;
                        _eab_val = max(1, ceil(_eab_val / 2));
                        array_push(combat_log, "[Companion] " + pet_active().name + " weathers "
                            + actor.name + "'s " + _eab.name + " - it bites half as deep.");
                    }
                    array_push(player.status_effects, {
                        name:         _eab.name,
                        effect_type:  (_eab.kind == "dot") ? "dot" : "debuff",
                        kind:         _eab.status_kind,
                        effect_value: _eab_val,
                        duration:     _edur,
                        source:       "enemy"
                    });
                    array_push(combat_log, actor.name + " " + ((_eab.msg != "") ? _eab.msg : ("inflicts " + _eab.name)) + "!");
                }
            }

            // Ability consumed the enemy's action - roll its next intent, advance.
            enemy_roll_intent(actor, player, combat_state.round + 1, true);
            combat_next_turn(combat_state);
            player_turn = combat_state.active.is_player;
            if (player_turn) { abilities_used_this_turn = []; if (instance_exists(obj_game_controller)) instance_find(obj_game_controller, 0).items_used_this_turn = 0; need_player_status_tick = true; }
            enemy_turn_timer = enemy_turn_delay;
            exit;
        }

        // --- Determine base damage for this turn (handles telegraph spike) ---
        var _base_dmg = enemy_get_attack_damage(actor, combat_state.round);
        // ASHEN DUELIST: the execute swing - below 25% HP he cuts 50% harder.
        if (global.duel_active && player.max_HP > 0 && player.HP < player.max_HP * 0.25) {
            _base_dmg = round(_base_dmg * 1.5);
            array_push(combat_log, "The Duelist sees the opening - an execute swing!");
        }
        // A5 BOSS ENRAGE (C1, M-approved 07-09): in a boss room at Awakening 5,
        // every enemy swing gains +10% per round past round 6 - no turtling.
        _base_dmg = max(1, round(_base_dmg * awaken_boss_enrage_mult(combat_state.round)));
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
        // Phantom Step potency ranks (POTENCY V2): +2% flat dodge per rank.
        var _pp_dodge = (variable_struct_exists(player, "phantom_dodge")) ? player.phantom_dodge : 0;
        var _hit = combat_roll_hit(_enemy_acc + 9, player.dodge + combat_smoke_dodge(player) + _pp_dodge, false);

        // Phantom Step TRANSCEND "Afterimage" (POTENCY V2): once per combat, a
        // swing that would land passes through an afterimage instead.
        if (_hit == "hit" && variable_struct_exists(player, "afterimage_ready") && player.afterimage_ready) {
            player.afterimage_ready = false;
            _hit = "dodge";
            array_push(combat_log, "AFTERIMAGE! " + actor.name + "'s blow parts empty shadow.");
        }
        // Veil of the Patient Dark (07-28 legendary): the first enemy attack each
        // combat parts the concealment instead of you (same idiom as Afterimage).
        if (_hit == "hit" && variable_struct_exists(player, "leg_veil_ready") && player.leg_veil_ready) {
            player.leg_veil_ready = false;
            _hit = "dodge";
            array_push(combat_log, "THE VEIL PARTS! " + actor.name + " strikes where you no longer are.");
        }
        // Slip Between (voidkit innate, 08-01): the FIRST blow aimed at you each
        // combat has a 10% chance to part around empty night. One roll per combat
        // (the lazy flag lives on the per-combat player struct).
        if (_hit == "hit" && pet_active_innate("slip") > 0
            && !variable_struct_exists(player, "innate_slip_rolled")) {
            player.innate_slip_rolled = true;
            if (irandom(99) < pet_active_innate("slip")) {
                _hit = "dodge";
                array_push(combat_log, "[Companion] " + pet_active().name + " flickers - " + actor.name + "'s blow slips between worlds.");
            }
        }
        // Bramble Wall (thornlet signature move, 08-06): the FIRST enemy attack
        // that would land on you each combat is stopped outright by the wall.
        // Sits with the other pre-RAGE avoidance layers on purpose - a breaker
        // blow (below) still smashes through, same as Afterimage and the Veil.
        if (_hit == "hit" && pet_active_sig_move("bramble_wall")
            && !variable_struct_exists(player, "sig_bramble_done")) {
            player.sig_bramble_done = true;
            _hit = "dodge";
            array_push(combat_log, "[Companion] " + pet_active().name + "'s BRAMBLE WALL stops " + actor.name + "'s blow dead!");
        }

        // RAGE (08-08) overrides EVERY avoidance above - afterimage, the Veil, Slip
        // Between and the plain dodge roll alike. It sits after ALL of them on
        // purpose: a raging blow that a once-per-combat charge could still eat
        // would not be a breaker at all.
        if (_rage_now) _hit = "hit";
        // DUELIST T3 THE PERFECT THRUST (08-13, M-locked): on his telegraph turn
        // the thrust cannot be evaded - same override seat as RAGE, for the same
        // reason. Stun stops him acting, Weaken dulls it, a shield absorbs it;
        // footwork does not answer a blow rehearsed nine duels deep.
        if (_hit != "hit"
            && variable_struct_exists(actor, "perfect_thrust") && actor.perfect_thrust
            && actor.telegraph_turn > 0 && (combat_state.round mod actor.telegraph_turn) == 0) {
            _hit = "hit";
            array_push(combat_log, "THE PERFECT THRUST finds you through the sidestep - it cannot be evaded!");
        }
        // Streak bookkeeping: a landed blow clears it, a denial feeds it.
        if (_hit == "hit") actor.denied_streak = 0;
        else               actor.denied_streak += 1;
        // A3+ Awakening: the breaker also bites harder, because that is the tier
        // where stacked defence gets silly. A0-A2 keep NORMAL damage so this can
        // never read as an unfair spike on a player who was defending well.
        if (_rage_now) {
            var _aw_t = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
            var _rg_m = (_aw_t >= 5) ? 1.35 : ((_aw_t >= 4) ? 1.25 : ((_aw_t >= 3) ? 1.15 : 1.0));
            if (_rg_m > 1.0) _base_dmg = max(1, round(_base_dmg * _rg_m));
        }

        if (_hit != "hit") {
            array_push(combat_log, (_hit == "dodge")
                ? ("You dodged " + actor.name + "'s attack!")
                : (actor.name + " attacked but missed!"));
            // Conveyance (08-04): you visibly sidestep + the verdict floats over you.
            if (_hit == "dodge") player.dodge_anim = 14;
            array_push(damage_popups, { value: 0, text: (_hit == "dodge") ? "DODGED!" : "MISS!",
                x: 475, y: 505, timer: 40, col: make_color_rgb(200, 205, 220) });
            // Punished Whiffs trunk node (P2, 08-05): every enemy miss or dodged
            // swing feeds the Shadowstrider engine (+1 Prep).
            if (player.class_id == 2 && variable_struct_exists(player, "preparation")
                && trunk_has("prep_on_miss")) {
                player.preparation = min(player.preparation_max, player.preparation + 1);
                array_push(combat_log, "Punished Whiffs: their miss is your moment - +1 Prep.");
            }
            // Duelist's Rebuke (07-28 legendary): a dodge primes +50% on your next
            // damaging ability (Shadow Meld idiom - persists until consumed).
            if (_hit == "dodge" && variable_struct_exists(player, "leg_rebuke") && player.leg_rebuke) {
                player.leg_rebuke_primed = true;
                array_push(combat_log, "Duelist's Rebuke: the miss will cost them - your next ability strikes +50% harder!");
            }
            // The Ashen Blade (Duelist Arts): a dodge arms -1 AP on your next ability.
            if (_hit == "dodge" && player.leg_ashen && !player.ashen_tempo_ready) {
                player.ashen_tempo_ready = true;
                array_push(combat_log, "The Ashen Blade hums - your next ability costs 1 less AP.");
            }
            // Shadow Meld (audit §6 rework): a successful dodge primes a guaranteed crit
            // on your next damaging attack (dodge feeds offense, not more dodge).
            // TRANSCEND "One With the Dark" (POTENCY V2): ANY miss primes it, not
            // just a dodge.
            if ((_hit == "dodge" || trait_transcended("Shadow Meld"))
                && player.class_id == 2 && trait_active("Shadow Meld")) {
                player.shadow_meld_crit = true;
                array_push(combat_log, "Shadow Meld: you slip into the dark - your next attack is a guaranteed CRIT!");
            }

        } else {
            // Gross incoming = the enemy's effective swing before ANY of the player's
            // defensive layers (armor / Iron Skin / equip armor / phys reduction /
            // Warding). Captured here so we can report how much was mitigated in the log.
            var _gross_incoming = _base_dmg + combat_status_total(player, "vulnerable");
            // ARMOR REWORK (M-locked 08-18): one % pool (base + gear + boon + Clotted),
            // Iron Skin flat first - combat_player_apply_armor is the single source.
            var _final_dmg = combat_player_apply_armor(player, _gross_incoming, 0);
            if (variable_struct_exists(player, "derived") && player.derived.phys_dmg_reduction > 0) {
                _final_dmg = max(1, ceil(_final_dmg * (1.0 - (player.derived.phys_dmg_reduction / 100.0))));
            }
            // Warding boon: flat % incoming-damage reduction.
            if (boon_active("warding")) _final_dmg = max(1, round(_final_dmg * boon_incoming_mult()));
            // Warding egg (Pets §3): active hatchling reduces incoming damage.
            if (pet_egg_ward_mult() != 1.0) _final_dmg = max(1, round(_final_dmg * pet_egg_ward_mult()));
            // Curse penalties (Exposed/Ruin): flat % incoming-damage increase.
            if (curse_incoming_mult() != 1.0) _final_dmg = max(1, round(_final_dmg * curse_incoming_mult()));
            // Mire Stare (gloomtoad innate, 08-01): the first enemy attack that
            // lands each combat sinks into the mire - 10% weaker.
            if (pet_active_innate("mire") > 0 && !variable_struct_exists(player, "innate_mire_done")) {
                player.innate_mire_done = true;
                _final_dmg = max(1, round(_final_dmg * (1 - pet_active_innate("mire") / 100)));
                array_push(combat_log, "[Companion] Mire Stare drags at " + actor.name + "'s blow.");
            }
            // Blink softening: 2nd/3rd charge takes 50%/25%-reduced damage if the hit lands.
            if (_incoming_mult < 1.0) _final_dmg = max(1, round(_final_dmg * _incoming_mult));
            // Evasive Roll (audit §6 build): the armed roll halves the next hit above 10,
            // and a clean absorb refunds 1 Preparation.
            if (player.evasive_roll_armed && _final_dmg > 10) {
                _final_dmg = ceil(_final_dmg / 2);
                player.evasive_roll_armed = false;
                if (variable_struct_exists(player, "preparation")) {
                    player.preparation = min(player.preparation_max, player.preparation + 1);
                }
                array_push(combat_log, "Evasive Roll! The blow is halved (+1 Preparation).");
            }
            // Pet stance (expression #3): a GUARDED Warrior companion has a 25% chance
            // to intercept part of any blow aimed at you (its own strikes are halved).
            // #20: the intercepted portion now hits the PET's stage-scaled HP pool;
            // at 0 HP it collapses - injury tier +1 (existing ladder benches it for
            // the rest of the run; capped below the permadeath tier, a KO never
            // kills outright). The pool refills between runs / when fed.
            var _gpet = global.duel_active ? undefined : pet_active();   // duel: companion sits out - no intercepts
            var _g_can = false, _g_body = false;
            if (_gpet != undefined && !_gpet.is_egg && _gpet.stage >= PET_STAGE_YOUNGADULT
                && !pet_guard_off(_gpet)   // called off mid-fight (G) = no intercepts
                && pet_injury_mult(_gpet.injured) > 0 && pet_hp(_gpet) > 0) {
                if (_gpet.archetype == PET_ARCH_COMBATANT && pet_stance(_gpet) == "guarded") _g_can = true;
                // Bodyguard capstone (C5, M-approved 07-09): a Guardian intercepts in
                // ANY stance at 40% - Guardians have no guarded stance, so the capstone
                // carries the intercept identity itself (design adaptation, flagged).
                // M ruling 07-10: the pet takes the intercepted portion REDUCED by 10%
                // (0.90x) - capstone toughness, not a surcharge (was +25%).
                if (_gpet.archetype == PET_ARCH_GUARDIAN && pet_kit_mods(_gpet).bodyguard) { _g_can = true; _g_body = true; }
            }
            if (_g_can && _final_dmg > 1 && irandom(99) < (_g_body ? 40 : 25)) {
                var _gcut = max(1, round(_final_dmg * 0.35));
                _final_dmg -= _gcut;
                var _gko = pet_take_damage(_gpet, _g_body ? max(1, round(_gcut * 0.90)) : _gcut);
                array_push(combat_log, "[Companion] " + _gpet.name + " intercepts the blow (-" + string(_gcut)
                    + ")!  [" + string(pet_hp(_gpet)) + "/" + string(pet_max_hp(_gpet)) + " HP]");
                if (_gko) {
                    // Deathdodger quirk (08-01, pillar C): once per run it shrugs
                    // the KO and stays standing at 1 HP.
                    if (pet_quirk_has(_gpet, "deathdodger")
                        && (!variable_struct_exists(_gpet, "dd_run") || _gpet.dd_run != global.run_count)) {
                        _gpet.dd_run  = global.run_count;
                        _gpet.hp_dmg  = pet_max_hp(_gpet) - 1;
                        array_push(combat_log, "[Companion] DEATHDODGER - " + _gpet.name + " refuses to fall (1 HP)!");
                    } else {
                        // Memory (pillar C): the KO is remembered - by dungeon, and
                        // for this run (Deathdodger is earned by surviving one).
                        pet_mem_bump_dungeon(_gpet, "mem_ko");
                        _gpet.mem_ko_this_run = true;
                        _gpet.injured = min(_gpet.injured + 1, PET_INJURY_DEATH - 1);
                        array_push(combat_log, "[Companion] " + _gpet.name
                            + " collapses from its wounds - out for the rest of the run!");
                    }
                }
            }
            // How much the player's defenses shaved off this swing (armor/Iron Skin/etc.),
            // measured before Soul Shield (which logs its own absorb line separately).
            var _dmg_blocked = max(0, _gross_incoming - _final_dmg);
            // Second Skin blessing (Shrine V2): the first hit each combat is halved -
            // before the shield so the ward isn't spent on the waived half.
            _final_dmg = boon_second_skin_apply(player, _final_dmg, combat_log);

            // Soul Shield absorbs damage before it reaches HP.
            if (variable_struct_exists(player, "shield_hp") && player.shield_hp > 0 && _final_dmg > 0) {
                var _sa = min(player.shield_hp, _final_dmg);
                player.shield_hp -= _sa;
                // Poise is spent first (07-17): decrement the tracker so its turn-start
                // expiry only removes what survived, never a persistent ward.
                if (variable_struct_exists(player, "poise_shield") && player.poise_shield > 0) player.poise_shield = max(0, player.poise_shield - _sa);
                // "Blood Debt" (P3): the pact's share depletes with the ward; the hit
                // that shatters the whole shield triggers the repayment below.
                if (variable_struct_exists(player, "pact_shield") && player.pact_shield > 0) {
                    player.pact_shield = max(0, player.pact_shield - _sa);
                    if (player.shield_hp <= 0 && player.pact_debt_armed) player.pact_debt_due = true;
                }
                _final_dmg -= _sa;
                array_push(combat_log, "Soul Shield absorbs " + string(_sa) + " damage.");
            }

            // Held Open (doorling sig move): the first actor's stamped action
            // deals nothing - the door takes the blow.
            if (variable_struct_exists(actor, "sig_door_round") && actor.sig_door_round == combat_state.round
                && _final_dmg > 0) {
                _final_dmg = 0;
                array_push(combat_log, "[Companion] The way stands HELD OPEN - " + actor.name + "'s blow spends itself on the door.");
            }
            // Board "flawless" requests count HP damage only - a full Soul Shield
            // absorb keeps the fight untouched (defense play stays rewarded).
            if (_final_dmg > 0) combat_state.player_took_damage = true;
            combat_apply_damage(player, _final_dmg);
            // Bramble Hide / Spore Cloud (thorn_boar / sporeling innates, 08-01):
            // striking you has a price. Thorns route through the universal damage
            // sink (deaths sweep like any DoT kill); the spore is a 2/turn poison.
            if (pet_active_innate("thorns") > 0 && actor.HP > 0) {
                combat_apply_damage(actor, pet_active_innate("thorns"));
                array_push(combat_log, "[Companion] Brambles bite " + actor.name + " for " + string(pet_active_innate("thorns")) + "!");
            }
            // Undertow (paleswimmer innate, 08-06): a foe that strikes you has an
            // N% chance to be dragged Weakened for 1 turn (same on-strike price
            // idiom as the brambles above; no once-flag - every landed blow rolls).
            if (pet_active_innate("undertow") > 0 && actor.HP > 0
                && variable_struct_exists(actor, "status_effects")
                && irandom(99) < pet_active_innate("undertow")) {
                array_push(actor.status_effects, {
                    name:         "Undertow",
                    effect_type:  "debuff",
                    kind:         "weaken",
                    effect_value: 0.15,
                    duration:     1,
                    element:      "",
                    source:       "pet"
                });
                array_push(combat_log, "[Companion] The UNDERTOW drags at " + actor.name + " - Weakened!");
            }
            // Something Larger (leviathan_calf signature move, 08-06): the first
            // enemy to strike you learns what swims beneath - it takes 25% of its
            // OWN max HP. Routed through the universal sink so deaths sweep clean.
            if (pet_active_sig_move("something_larger") && actor.HP > 0
                && !variable_struct_exists(player, "sig_larger_done")) {
                player.sig_larger_done = true;
                var _sl_dmg = max(1, round(actor.max_HP * 0.25));
                combat_apply_damage(actor, _sl_dmg);
                actor.hit_flash = max(actor.hit_flash, 12);
                array_push(combat_log, "[Companion] SOMETHING LARGER stirs beneath " + pet_active().name
                    + " - " + actor.name + " takes " + string(_sl_dmg) + "!");
                if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
            }
            if (pet_active_innate("spore") > 0 && actor.HP > 0
                && variable_struct_exists(actor, "status_effects")
                && irandom(99) < pet_active_innate("spore")) {
                array_push(actor.status_effects, {
                    name:         "Spore Cloud",
                    effect_type:  "dot",
                    kind:         "dot",
                    effect_value: 2,
                    duration:     2,
                    element:      "poison",
                    source:       "pet"
                });
                array_push(combat_log, "[Companion] Spores bloom across " + actor.name + " - Poisoned!");
            }
            // Player takes a hit - gendered human "damage" grunt (snd_player_hurt[_f]).
            play_player_vocal("snd_player_hurt", -1);
            // VFX: hit flash, popup, enemy attack slide, screen shake
            // Living-slot index + the SHARED position helper (2.5D v3): the lunge
            // and the shot now start from the drawn sprite, at every depth.
            var _ea_slot = 0;
            for (var _asi = 0; _asi < array_length(combat_state.combatants); _asi++) {
                if (combat_state.combatants[_asi] == actor) break;
                if (!combat_state.combatants[_asi].is_player && !combat_state.combatants[_asi].is_defeated) _ea_slot++;
            }
            var _ea_p = (combat_25d() && variable_struct_exists(actor, "stage_station"))
                      ? actor.stage_station : combat_enemy_slot_pos(_ea_slot);
            var _ea_src_x = _ea_p.x;
            var _ea_src_y = _ea_p.y;
            // Conveyance (08-04): a RANGED foe's blow now visibly flies to you - the
            // hit presentation (flash/shake/popup/spark/recoil/HP drain) rides the
            // projectile. A melee foe keeps the lunge, instant as before.
            var _ea_ranged = (variable_struct_exists(actor, "reach") && actor.reach == "ranged");
            var _ea_delay  = _ea_ranged ? (15 + array_length(combat_projectiles) * 4) : 0;
            if (_ea_ranged) {
                // Family VFX (M 08-13): elemental foes' basic shots now carry their
                // school's bolt + burst instead of the generic needle. Physical
                // families ("" school) keep the shipped needle + impact spark.
                var _ea_sch  = enemy_attack_school(actor.name);
                var _ea_bolt = school_bolt_sprite(_ea_sch);
                if (_ea_sch != "" && _ea_bolt >= 0) {
                    array_push(combat_projectiles, {
                        spr: _ea_bolt, school: _ea_sch, impact_spr: _ea_bolt, ticks: 20,
                        sx: _ea_src_x + 90, sy: _ea_src_y + 90, tx: 415, ty: 560,
                        bx: 415, by: 560,   // spr_vfx_* are center-origin
                        t: 0, dur: 15, delay: _ea_delay - 15, tgt: player, shake: 12
                    });
                } else {
                    array_push(combat_projectiles, {
                        spr: -1, school: "", impact_spr: spr_fx_impact, ticks: 18,
                        sx: _ea_src_x + 90, sy: _ea_src_y + 90, tx: 415, ty: 560,
                        bx: 300, by: 450,   // spr_fx_impact is top-left origin (shipped spark anchor)
                        t: 0, dur: 15, delay: _ea_delay - 15, tgt: player, shake: 12
                    });
                }
                player.hp_hold = _ea_delay;
            } else {
                player.hit_flash   = 15;
                player.hit_recoil  = 10;
                screen_shake_timer = 12;
                attack_anim_timer     = 20;
                attack_anim_src_x     = _ea_src_x;
                attack_anim_src_y     = _ea_src_y;
                // 2.5D: lunge horizontally toward the player at the attacker's OWN
                // depth row (the flat 435,465 contact point yanked deep-row foes
                // out of their plane). Flat mode: shipped contact point.
                attack_anim_dst_x     = combat_25d() ? (combat_player_vfx_anchor(player).x + 280) : 435;
                attack_anim_dst_y     = combat_25d() ? _ea_src_y : 465;
                attack_anim_is_player = false;
                attack_anim_enemy_idx = _ea_slot;
                // Impact spark over the player where the blow lands (same one-shot VFX
                // system as outgoing hits; spr_fx_impact is a 64px top-left-origin burst).
                var _pvha = combat_player_vfx_anchor(player);
                vfx_spr       = spr_fx_impact;
                vfx_x         = combat_25d() ? _pvha.x : 300;
                vfx_y         = combat_25d() ? (_pvha.y + 60) : 450;
                vfx_scale_mult = 1;
                vfx_timer     = 18;
                vfx_timer_max = 18;
                vfx_school    = "";   // enemy hit spark - never tinted
            }
            array_push(damage_popups, { value: _final_dmg, x: 475, y: 545, timer: 50, delay: _ea_delay, col: make_color_rgb(255, 80, 80) });
            array_push(combat_log,
                actor.name + " attacked for " + string(_final_dmg) + " damage!"
                + ((_dmg_blocked > 0) ? ("  (" + string(_dmg_blocked) + " blocked)") : ""));

            // --- Glacial Ward rebuke (D§4, M-approved 07-09): a MELEE attacker that
            //     lands a blow while the ward stands is Chilled (frost weaken; the
            //     same status detonators shatter).
            if (variable_struct_exists(player, "glacial_ward_turns") && player.glacial_ward_turns > 0
                && (((variable_struct_exists(actor, "reach") ? actor.reach : "melee") == "melee")
                    // "Deep Freeze" web keystone (task #14): the rebuke reaches ranged too.
                    || (variable_struct_exists(player, "glacial_ward_reach_all") && player.glacial_ward_reach_all))
                && variable_struct_exists(actor, "status_effects") && !actor.is_defeated) {
                array_push(actor.status_effects, {
                    name: "Chilled", effect_type: "debuff", kind: "weaken",
                    effect_value: 0.30, duration: 2, element: "frost", source: "player"
                });
                array_push(combat_log, actor.name + " is Chilled by the Glacial Ward!");
            }

            // --- Ashen Parry Dagger relic (08-11, #23): every MELEE blow that
            //     lands is answered for a flat 8 - the Duelist's own riposte
            //     number, now in your off-hand. ---
            if (legendary_worn("duel_parry") && _in_melee_blow && !actor.is_defeated) {
                combat_apply_damage(actor, 8);
                actor.hit_flash = max(actor.hit_flash, 10);
                array_push(damage_popups, { value: 8, x: _ea_src_x, y: _ea_src_y - 105,
                                            timer: 45, col: make_color_rgb(210, 205, 190) });
                array_push(combat_log, "Parry Dagger: the blow is answered - " + actor.name + " takes 8!");
                if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
            }

            // --- Bloodthorn Aura reflect ---
            if (player.bloodthorn_active) {
                combat_apply_damage(actor, player.bloodthorn_value);
                actor.hit_flash = max(actor.hit_flash, 10);
                array_push(damage_popups, {
                    value: player.bloodthorn_value,
                    x: _ea_src_x, y: _ea_src_y - 75,
                    timer: 45, col: make_color_rgb(200, 80, 50)
                });
                array_push(combat_log,
                    "Bloodthorn Aura: " + actor.name + " takes "
                    + string(player.bloodthorn_value) + " reflected damage!");
                // Bloodthorn companion change (P3, M 07-29): the thorns stay under
                // the skin - MELEE attackers also start Bleeding (2/turn, 2 turns).
                // Keeps Bloodthorn distinct now that Iron Skin can reflect too:
                // reflect + DoT = the anti-melee-pack tool.
                if (_in_melee_blow && !actor.is_defeated && variable_struct_exists(actor, "status_effects")) {
                    array_push(actor.status_effects, {
                        name: "Thorn Bleed", effect_type: "dot", kind: "dot",
                        effect_value: 2, duration: 2, element: "bleed", source: "player"
                    });
                    array_push(combat_log, "The thorns stay in - " + actor.name + " is Bleeding!");
                }
                // Reflect can be the killing blow - run the shared kill handler
                // (same rule as Soulbind below), or the enemy stands at 0 HP.
                if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
                player.bloodthorn_duration--;
                if (player.bloodthorn_duration <= 0) {
                    player.bloodthorn_active = false;
                    array_push(combat_log, "Bloodthorn Aura fades.");
                }
            }

            // --- "Sharp Edges" web node (P3, 07-29): while Iron Skin holds, a melee
            //     blow that LANDS takes the skin's reduction value back as damage. ---
            if (variable_struct_exists(player, "sharp_edges_value") && player.sharp_edges_value > 0
                && player.iron_skin_duration > 0 && _in_melee_blow && !actor.is_defeated) {
                combat_apply_damage(actor, player.sharp_edges_value);
                actor.hit_flash = max(actor.hit_flash, 8);
                array_push(damage_popups, { value: player.sharp_edges_value, x: _ea_src_x, y: _ea_src_y - 45,
                    timer: 40, delay: 8, col: make_color_rgb(190, 190, 210) });
                array_push(combat_log, "Sharp Edges: " + actor.name + " cuts itself on the iron for " + string(player.sharp_edges_value) + "!");
                if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
            }

            // --- "Blood Debt" web keystone (P3, 07-29): this blow shattered the
            //     pact ward - it repays its full sealed value to the attacker. ---
            if (variable_struct_exists(player, "pact_debt_due") && player.pact_debt_due) {
                player.pact_debt_due   = false;
                player.pact_debt_armed = false;
                if (player.pact_debt > 0 && !actor.is_defeated) {
                    combat_apply_damage(actor, player.pact_debt);
                    actor.hit_flash = max(actor.hit_flash, 12);
                    array_push(damage_popups, { value: player.pact_debt, x: _ea_src_x, y: _ea_src_y - 60,
                        timer: 45, delay: 10, col: make_color_rgb(220, 60, 60) });
                    array_push(combat_log, "BLOOD DEBT - the shattered pact repays " + actor.name + " with " + string(player.pact_debt) + "!");
                    if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
                }
                player.pact_debt = 0;
            }

            // --- Soulbind: the bound enemy shares your pain - 40% reflected AND the
            // stolen vitality heals you (audit §6 lifelink build). Combat-long. ---
            if (player.soulbind_enemy != undefined && _final_dmg > 0) {
                var _sb = player.soulbind_enemy;
                if (is_struct(_sb) && !_sb.is_defeated) {
                    var _sb_dmg = max(1, round(_final_dmg * 0.4));
                    combat_apply_damage(_sb, _sb_dmg);
                    _sb.hit_flash = max(_sb.hit_flash, 10);
                    var _sb_before = player.HP;
                    player.HP = min(player.max_HP, player.HP + _sb_dmg);
                    array_push(combat_log, "Soulbind: " + _sb.name + " suffers " + string(_sb_dmg) + " of your pain"
                        + ((player.HP > _sb_before) ? (" - you recover " + string(player.HP - _sb_before) + " HP") : "") + "!");
                    if (_sb.HP <= 0) combat_on_enemy_defeated(_sb, player, combat_log);
                } else {
                    player.soulbind_enemy = undefined;   // the bond died with them
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
        if (actor.mechanic_type == "double_strike" && !actor.is_defeated) {
            var _hit2 = combat_roll_hit(_enemy_acc + 9, player.dodge + combat_smoke_dodge(player), false);

            if (_hit2 != "hit") {
                array_push(combat_log, (_hit2 == "dodge")
                    ? ("You dodged " + actor.name + "'s second strike!")
                    : (actor.name + "'s second strike missed!"));
                // Conveyance (08-04): the second-strike verdict floats too.
                if (_hit2 == "dodge") player.dodge_anim = 14;
                array_push(damage_popups, { value: 0, text: (_hit2 == "dodge") ? "DODGED!" : "MISS!",
                    x: 475, y: 505, timer: 40, col: make_color_rgb(200, 205, 220) });
                // Punished Whiffs trunk node (P2, 08-05): the second whiff pays too.
                if (player.class_id == 2 && variable_struct_exists(player, "preparation")
                    && trunk_has("prep_on_miss")) {
                    player.preparation = min(player.preparation_max, player.preparation + 1);
                    array_push(combat_log, "Punished Whiffs: their miss is your moment - +1 Prep.");
                }
                // The Ashen Blade (Duelist Arts): a dodge arms -1 AP on your next ability.
                if (_hit2 == "dodge" && player.leg_ashen && !player.ashen_tempo_ready) {
                    player.ashen_tempo_ready = true;
                    array_push(combat_log, "The Ashen Blade hums - your next ability costs 1 less AP.");
                }
            } else {
                var _gross_incoming2 = actor.mechanic_value + combat_status_total(player, "vulnerable");
                // ARMOR REWORK (08-18): same % pool as the main strike.
                var _final_dmg2 = combat_player_apply_armor(player, _gross_incoming2, 0);
                if (boon_active("warding")) _final_dmg2 = max(1, round(_final_dmg2 * boon_incoming_mult()));
                if (pet_egg_ward_mult() != 1.0) _final_dmg2 = max(1, round(_final_dmg2 * pet_egg_ward_mult()));   // Warding egg
                if (curse_incoming_mult() != 1.0) _final_dmg2 = max(1, round(_final_dmg2 * curse_incoming_mult()));
                if (_incoming_mult < 1.0) _final_dmg2 = max(1, round(_final_dmg2 * _incoming_mult));  // Blink softening
                // Evasive Roll: covers the double strike too (audit §6 build).
                if (player.evasive_roll_armed && _final_dmg2 > 10) {
                    _final_dmg2 = ceil(_final_dmg2 / 2);
                    player.evasive_roll_armed = false;
                    if (variable_struct_exists(player, "preparation")) {
                        player.preparation = min(player.preparation_max, player.preparation + 1);
                    }
                    array_push(combat_log, "Evasive Roll! The blow is halved (+1 Preparation).");
                }
                // Second Skin covers the double strike too (if the first hit of the
                // combat somehow IS the second strike).
                _final_dmg2 = boon_second_skin_apply(player, _final_dmg2, combat_log);
                var _dmg_blocked2 = max(0, _gross_incoming2 - _final_dmg2);
                // Soul Shield absorbs the second strike too.
                if (variable_struct_exists(player, "shield_hp") && player.shield_hp > 0 && _final_dmg2 > 0) {
                    var _sa2 = min(player.shield_hp, _final_dmg2);
                    player.shield_hp -= _sa2;
                    if (variable_struct_exists(player, "poise_shield") && player.poise_shield > 0) player.poise_shield = max(0, player.poise_shield - _sa2);
                    // "Blood Debt" (P3): pact tracking covers the double strike too.
                    if (variable_struct_exists(player, "pact_shield") && player.pact_shield > 0) {
                        player.pact_shield = max(0, player.pact_shield - _sa2);
                        if (player.shield_hp <= 0 && player.pact_debt_armed) player.pact_debt_due = true;
                    }
                    _final_dmg2 -= _sa2;
                    array_push(combat_log, "Soul Shield absorbs " + string(_sa2) + " damage.");
                }

                if (_final_dmg2 > 0) combat_state.player_took_damage = true;
                combat_apply_damage(player, _final_dmg2);
                play_player_vocal("snd_player_hurt", -1);
                player.hit_flash   = max(player.hit_flash, 12);
                player.hit_recoil  = 10;   // conveyance: knock on damage taken
                screen_shake_timer = max(screen_shake_timer, 8);
                array_push(damage_popups, { value: _final_dmg2, x: 475, y: 545, timer: 50, col: make_color_rgb(255, 80, 80) });
                array_push(combat_log,
                    actor.name + " strikes again for " + string(_final_dmg2) + " damage!"
                    + ((_dmg_blocked2 > 0) ? ("  (" + string(_dmg_blocked2) + " blocked)") : ""));

                // --- Bloodthorn Aura reflect (double strike) ---
                if (player.bloodthorn_active) {
                    combat_apply_damage(actor, player.bloodthorn_value);
                    actor.hit_flash = max(actor.hit_flash, 8);
                    // Own source position: the first-strike branch's _ea_src_x/_y is only
                    // set when strike 1 landed, and strike 2 can land after a strike-1 miss.
                    var _ds_slot = 0;
                    for (var _dsri = 0; _dsri < array_length(combat_state.combatants); _dsri++) {
                        if (combat_state.combatants[_dsri] == actor) break;
                        if (!combat_state.combatants[_dsri].is_player && !combat_state.combatants[_dsri].is_defeated) _ds_slot++;
                    }
                    var _ds_p = (combat_25d() && variable_struct_exists(actor, "stage_station"))
                              ? actor.stage_station : combat_enemy_slot_pos(_ds_slot);
                    array_push(damage_popups, {
                        value: player.bloodthorn_value,
                        x: _ds_p.x, y: _ds_p.y - 75,
                        timer: 45, col: make_color_rgb(200, 80, 50)
                    });
                    array_push(combat_log,
                        "Bloodthorn Aura: " + actor.name + " takes "
                        + string(player.bloodthorn_value) + " reflected damage!");
                    // Bloodthorn companion change (P3, M 07-29): the double strike is
                    // melee by nature - the thorns stay in and it Bleeds (2/2t).
                    if (!actor.is_defeated && variable_struct_exists(actor, "status_effects")) {
                        array_push(actor.status_effects, {
                            name: "Thorn Bleed", effect_type: "dot", kind: "dot",
                            effect_value: 2, duration: 2, element: "bleed", source: "player"
                        });
                        array_push(combat_log, "The thorns stay in - " + actor.name + " is Bleeding!");
                    }
                    // Reflect can be the killing blow here too.
                    if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
                    player.bloodthorn_duration--;
                    if (player.bloodthorn_duration <= 0) {
                        player.bloodthorn_active = false;
                        array_push(combat_log, "Bloodthorn Aura fades.");
                    }
                }

                // --- "Sharp Edges" (P3): the double strike is melee - the iron answers. ---
                if (variable_struct_exists(player, "sharp_edges_value") && player.sharp_edges_value > 0
                    && player.iron_skin_duration > 0 && !actor.is_defeated) {
                    combat_apply_damage(actor, player.sharp_edges_value);
                    actor.hit_flash = max(actor.hit_flash, 8);
                    array_push(combat_log, "Sharp Edges: " + actor.name + " cuts itself on the iron for " + string(player.sharp_edges_value) + "!");
                    if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
                }

                // --- "Blood Debt" (P3): the second strike can shatter the pact too. ---
                if (variable_struct_exists(player, "pact_debt_due") && player.pact_debt_due) {
                    player.pact_debt_due   = false;
                    player.pact_debt_armed = false;
                    if (player.pact_debt > 0 && !actor.is_defeated) {
                        combat_apply_damage(actor, player.pact_debt);
                        actor.hit_flash = max(actor.hit_flash, 12);
                        array_push(combat_log, "BLOOD DEBT - the shattered pact repays " + actor.name + " with " + string(player.pact_debt) + "!");
                        if (actor.HP <= 0 && !actor.is_defeated) combat_on_enemy_defeated(actor, player, combat_log);
                    }
                    player.pact_debt = 0;
                }

                // --- Soulbind lifelink covers the double strike too (audit §6 build). ---
                if (player.soulbind_enemy != undefined && _final_dmg2 > 0) {
                    var _sb2 = player.soulbind_enemy;
                    if (is_struct(_sb2) && !_sb2.is_defeated) {
                        var _sb2_dmg = max(1, round(_final_dmg2 * 0.4));
                        combat_apply_damage(_sb2, _sb2_dmg);
                        _sb2.hit_flash = max(_sb2.hit_flash, 8);
                        var _sb2_before = player.HP;
                        player.HP = min(player.max_HP, player.HP + _sb2_dmg);
                        array_push(combat_log, "Soulbind: " + _sb2.name + " suffers " + string(_sb2_dmg) + " of your pain"
                            + ((player.HP > _sb2_before) ? (" - you recover " + string(player.HP - _sb2_before) + " HP") : "") + "!");
                        if (_sb2.HP <= 0) combat_on_enemy_defeated(_sb2, player, combat_log);
                    } else {
                        player.soulbind_enemy = undefined;
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

        // --- Advance turn (rolling this enemy's next intent first) ---
        if (!actor.is_defeated) enemy_roll_intent(actor, player, combat_state.round + 1, true);
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
