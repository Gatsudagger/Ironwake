// =============================================================================
// obj_combat_controller — Draw GUI event
// Runs every frame after Step. Draws all combat visuals in order:
//   background → enemy HP bars → HUD → result overlay → restart input
// =============================================================================


// -----------------------------------------------------------------------------
// 1. BACKGROUND
// A flat dark fill so nothing from the room layer bleeds through the GUI.
// -----------------------------------------------------------------------------
draw_set_color(make_color_rgb(18, 18, 28));
draw_rectangle(0, 0, 1280, 720, false);


// -----------------------------------------------------------------------------
// 2. ENEMY HP BARS (right side, stacked vertically)
// Defeated enemies are skipped so bars collapse upward as enemies fall.
// -----------------------------------------------------------------------------
var _bar_x      = 800;
var _bar_y      = 80;
var _bar_width  = 350;
var _bar_height = 28;
var _bar_gap    = 40;

var _living_idx = 0;
var _count = array_length(combat_state.combatants);
for (var _i = 0; _i < _count; _i++) {
    var _c = combat_state.combatants[_i];
    if (_c.is_player)   continue;
    if (_c.is_defeated) continue;

    if (_living_idx == selected_target) {
        draw_set_color(c_white);
        draw_set_halign(fa_right);
        draw_set_valign(fa_middle);
        draw_text(_bar_x - 6, _bar_y + _bar_height / 2, ">");
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }

    ui_draw_hp_bar(_bar_x, _bar_y, _bar_width, _bar_height,
                   _c.HP, _c.max_HP, _c.name);

    _living_idx++;
    _bar_y += _bar_gap;
}


// -----------------------------------------------------------------------------
// 3. COMBAT HUD
// Draws player HP, AP pips, secondary resource, turn queue, ability
// buttons, combat log, and any active telegraph warning.
// -----------------------------------------------------------------------------
ui_draw_combat_hud(combat_state, player, player.abilities, selected_ability, combat_log);


// -----------------------------------------------------------------------------
// 3b. CHARACTER SPRITES + COMBAT VFX
// Handles: attack slide lunge, hit flash (additive blend), screen shake,
// and floating damage/heal number popups.
// -----------------------------------------------------------------------------

// Screen shake: randomise offset while timer counts down
if (screen_shake_timer > 0) {
    screen_shake_timer--;
    screen_shake_x = irandom_range(-3, 3);
    screen_shake_y = irandom_range(-2, 2);
} else {
    screen_shake_x = 0;
    screen_shake_y = 0;
}

// Attack slide: compute lunge fraction (0 → peak → 0) over 20 frames
var _anim_progress = 0;
if (attack_anim_timer > 0) {
    attack_anim_timer--;
    _anim_progress = (20 - attack_anim_timer) / 20.0;
}
var _lunge_peak = (_anim_progress < 0.5)
    ? (_anim_progress * 2.0)
    : ((1.0 - _anim_progress) * 2.0);
var _lunge_frac = _lunge_peak * 0.4;   // lunge 40% of the way toward target

// Player sprite
var _class_sprites = [spr_arcanist, spr_bloodwarden, spr_shadowstrider];
var _pspr = _class_sprites[clamp(player.stats.class_id, 0, 2)];

var _px_draw = 220 + screen_shake_x;
var _py_draw = 310 + screen_shake_y;
if (attack_anim_is_player && _anim_progress > 0) {
    _px_draw = lerp(220, attack_anim_dst_x, _lunge_frac) + screen_shake_x;
    _py_draw = lerp(310, attack_anim_dst_y, _lunge_frac) + screen_shake_y;
}
draw_sprite_ext(_pspr, 1, _px_draw, _py_draw, 2.5, 2.5, 0, c_white, 1.0);
if (player.hit_flash > 0) {
    player.hit_flash--;
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(_pspr, 1, _px_draw, _py_draw, 2.5, 2.5, 0, c_white, (player.hit_flash / 15.0) * 0.8);
    gpu_set_blendmode(bm_normal);
}

// Enemy sprites
var _espr_map = {
    "Ashen Skeleton":  spr_skeleton_soldier,
    "Skeleton Archer": spr_skeleton_archer,
    "Vault Crawler":   spr_vault_crawler,
    "Dungeon Wraith":  spr_dungeon_wraith,
    "Stone Golem":     spr_stone_golem,
    "Vault Guardian":  spr_vault_guardian,
};
var _espr_x0  = 1080;
var _espr_y0  = 155;
var _espr_dx  = -80;
var _espr_dy  = 70;
var _espr_idx = 0;

var _ecnt = array_length(combat_state.combatants);
for (var _ei = 0; _ei < _ecnt; _ei++) {
    var _ec = combat_state.combatants[_ei];
    if (_ec.is_player || _ec.is_defeated) continue;

    var _ex = _espr_x0 + (_espr_idx * _espr_dx);
    var _ey = _espr_y0 + (_espr_idx * _espr_dy);

    // Attack slide for the enemy that is currently attacking
    if (!attack_anim_is_player && attack_anim_enemy_idx == _espr_idx && _anim_progress > 0) {
        _ex = lerp(attack_anim_src_x, attack_anim_dst_x, _lunge_frac) + screen_shake_x;
        _ey = lerp(attack_anim_src_y, attack_anim_dst_y, _lunge_frac) + screen_shake_y;
    } else {
        _ex += screen_shake_x;
        _ey += screen_shake_y;
    }

    if (variable_struct_exists(_espr_map, _ec.name)) {
        var _espr = variable_struct_get(_espr_map, _ec.name);
        draw_sprite_ext(_espr, 3, _ex, _ey, 2, 2, 0, c_white, 1.0);
        if (variable_struct_exists(_ec, "hit_flash") && _ec.hit_flash > 0) {
            _ec.hit_flash--;
            gpu_set_blendmode(bm_add);
            draw_sprite_ext(_espr, 3, _ex, _ey, 2, 2, 0, c_white, (_ec.hit_flash / 15.0) * 0.8);
            gpu_set_blendmode(bm_normal);
        }
    }
    _espr_idx++;
}

// VFX impact sprite: fades out and scales up over 20 frames with additive blend
if (vfx_timer > 0) {
    vfx_timer--;
    var _vfx_alpha = min(1.0, vfx_timer / 10.0);
    var _vfx_scale = lerp(2.5, 1.5, vfx_timer / 20.0);
    gpu_set_blendmode(bm_add);
    draw_set_alpha(_vfx_alpha);
    draw_sprite_ext(vfx_spr, 0, vfx_x + screen_shake_x, vfx_y + screen_shake_y, _vfx_scale, _vfx_scale, 0, c_white, 1.0);
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1.0);
}

// Floating damage / heal numbers
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
var _kept_popups = [];
for (var _di = 0; _di < array_length(damage_popups); _di++) {
    var _dp = damage_popups[_di];
    _dp.timer--;
    _dp.y -= 1.0;
    if (_dp.timer > 0) {
        var _dp_alpha = min(1.0, _dp.timer / 18.0);
        var _dp_scale = lerp(1.0, 1.5, clamp(_dp.timer / 50.0, 0, 1));
        draw_set_alpha(_dp_alpha);
        draw_set_color(c_black);
        draw_text_transformed(_dp.x + 2, _dp.y + 2, string(_dp.value), _dp_scale, _dp_scale, 0);
        draw_set_color(_dp.col);
        draw_text_transformed(_dp.x, _dp.y, string(_dp.value), _dp_scale, _dp_scale, 0);
        draw_set_alpha(1.0);
        array_push(_kept_popups, _dp);
    }
}
damage_popups = _kept_popups;
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// -----------------------------------------------------------------------------
// 3a. AP SYSTEM OVERLAYS (player turn only)
// Drawn after the HUD so they appear on top of ability buttons.
// Button positions must match ui_draw_ability_buttons: x=160, y=660, 160×50, gap=8.
// -----------------------------------------------------------------------------
if (player_turn && !combat_over) {
    var _btn_w   = 160;
    var _btn_h   = 50;
    var _btn_gap = 8;
    var _btn_x0  = 160;
    var _btn_y   = 660;

    for (var _bi = 0; _bi < array_length(player.abilities); _bi++) {
        var _ab   = player.abilities[_bi];
        var _used = false;
        for (var _ui = 0; _ui < array_length(abilities_used_this_turn); _ui++) {
            if (abilities_used_this_turn[_ui] == _ab.name) { _used = true; break; }
        }
        if (_used) {
            var _bx = _btn_x0 + _bi * (_btn_w + _btn_gap);
            draw_set_alpha(0.62);
            draw_set_color(make_color_rgb(20, 15, 25));
            draw_rectangle(_bx, _btn_y, _bx + _btn_w, _btn_y + _btn_h, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(175, 85, 85));
            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            draw_text(_bx + _btn_w / 2, _btn_y + _btn_h / 2, "USED");
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
        }
    }

    // End Turn prompt — brighter when out of AP to make it more visible
    var _ap_col;
    if (player.energy <= 0) {
        _ap_col = make_color_rgb(235, 195, 60);
    } else {
        _ap_col = make_color_rgb(130, 150, 115);
    }
    draw_set_halign(fa_center);
    draw_set_color(_ap_col);
    draw_text(640, 636, "T: End Turn   " + string(player.energy) + " AP remaining");
    draw_set_halign(fa_left);
}


// -----------------------------------------------------------------------------
// 3b. LEVEL-UP ALLOCATION OVERLAY
// Drawn after combat victory when the player has unspent stat points.
// Provisional flow: Space selects a stat, Enter commits it permanently.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_alloc_draw = instance_find(obj_game_controller, 0);
    if (_gc_alloc_draw.level_alloc_open) {

        draw_set_alpha(0.94);
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_rectangle(0, 0, 1280, 720, false);
        draw_set_alpha(1.0);

        var _pend_idx   = _gc_alloc_draw.level_alloc_pending_stat;   // -1 = none
        var _has_pend   = (_pend_idx >= 0);

        draw_set_halign(fa_center);
        draw_set_color(c_lime);
        draw_text_transformed(640, 60, "LEVEL UP  —  Level " + string(global.run_level), 1.5, 1.5, 0);

        draw_set_color(c_yellow);
        var _pts_str;
        if (global.pending_stat_points == 1) {
            _pts_str = "1 point";
        } else {
            _pts_str = string(global.pending_stat_points) + " points";
        }
        if (_has_pend) {
            draw_text(640, 105, "Allocate " + _pts_str + "   (Enter: change choice   Space: confirm)");
        } else {
            draw_text(640, 105, "Allocate " + _pts_str + "   (W/S: Navigate   Enter: choose stat)");
        }

        draw_set_halign(fa_left);

        var _alloc_stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        var _alloc_stat_descs = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"];

        for (var _si = 0; _si < 6; _si++) {
            var _sy      = 160 + _si * 72;
            var _is_sel  = (_si == _gc_alloc_draw.level_alloc_index);
            var _is_pend = (_si == _pend_idx);
            var _cur_val = variable_struct_get(player.stats, _alloc_stat_names[_si]);

            // Background
            var _bg_col;
            if (_is_pend) {
                _bg_col = make_color_rgb(48, 32, 8);
            } else if (_is_sel) {
                _bg_col = make_color_rgb(30, 50, 90);
            } else {
                _bg_col = make_color_rgb(18, 22, 38);
            }
            if (_is_sel || _is_pend) {
                draw_set_alpha(1.0);
            } else {
                draw_set_alpha(0.6);
            }
            draw_set_color(_bg_col);
            draw_rectangle(340, _sy, 940, _sy + 58, false);
            draw_set_alpha(1.0);

            // Border — amber for pending, blue for selected cursor, gray otherwise
            var _bd_col;
            if (_is_pend) {
                _bd_col = make_color_rgb(220, 145, 35);
            } else if (_is_sel) {
                _bd_col = make_color_rgb(80, 140, 220);
            } else {
                _bd_col = make_color_rgb(45, 55, 75);
            }
            draw_set_color(_bd_col);
            draw_rectangle(340, _sy, 940, _sy + 58, true);

            // Stat label
            var _lbl_col;
            if (_is_pend) {
                _lbl_col = make_color_rgb(235, 165, 50);
            } else if (_is_sel) {
                _lbl_col = c_white;
            } else {
                _lbl_col = make_color_rgb(140, 150, 170);
            }
            draw_set_color(_lbl_col);
            draw_text(360, _sy + 18, _alloc_stat_descs[_si] + "  (" + _alloc_stat_names[_si] + ")");

            // Value — show "X -> X+1" for the provisionally selected stat
            draw_set_halign(fa_right);
            if (_is_pend) {
                draw_set_color(make_color_rgb(235, 165, 50));
                draw_text(920, _sy + 18, string(_cur_val) + "  ->  " + string(_cur_val + 1));
            } else {
                draw_set_color(_lbl_col);
                draw_text(920, _sy + 18, string(_cur_val));
            }
            draw_set_halign(fa_left);
        }

        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        if (_has_pend) {
            draw_text(640, 620, "W/S: Navigate   Enter: Change selection   Space: Confirm");
        } else {
            draw_text(640, 620, "W/S: Navigate   Enter: Choose stat");
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);

        ui_draw_character_menu();
        exit;
    }
}


// -----------------------------------------------------------------------------
// 4. LOOT SCREEN OVERLAY — shown after combat when items dropped this room
// -----------------------------------------------------------------------------
if (show_loot_screen) {

    // Full-screen dark cover
    draw_set_alpha(0.92);
    draw_set_color(make_color_rgb(10, 12, 22));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_yellow);
    draw_text_transformed(640, 60, "LOOT FOUND", 2, 2, 0);

    draw_set_color(make_color_rgb(160, 160, 180));
    draw_text(640, 115, "Items collected this room:");

    // Item rows
    var _count   = array_length(global.run_items_found);
    var _visible = min(8, _count);

    for (var _i = 0; _i < _visible; _i++) {
        var _idx = _i + loot_screen_scroll;
        if (_idx >= _count) break;
        var _item = global.run_items_found[_idx];
        var _iy   = 160 + _i * 65;

        // Row background
        draw_set_alpha(0.5);
        draw_set_color(make_color_rgb(20, 25, 45));
        draw_rectangle(240, _iy - 5, 1040, _iy + 50, false);
        draw_set_alpha(1.0);

        var _is_consumable = variable_struct_exists(_item, "item_category")
                             && _item.item_category == "consumable";

        if (_is_consumable) {
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_set_halign(fa_left);
            draw_text(260, _iy + 5, _item.name);
            draw_set_color(make_color_rgb(140, 200, 200));
            draw_text(260, _iy + 28, _item.description);
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(1020, _iy + 5, "[CONSUMABLE]");
        } else {
            var _rarity_col = item_rarity_color(_item.rarity);
            draw_set_color(_rarity_col);
            draw_set_halign(fa_left);
            draw_text(260, _iy + 5, _item.name);
            draw_set_color(make_color_rgb(180, 180, 200));
            draw_text(260, _iy + 28, _item.effect_desc);
            draw_set_halign(fa_right);
            draw_set_color(_rarity_col);
            draw_text(1020, _iy + 5, "[" + item_rarity_name(_item.rarity) + "]");
            draw_set_color(make_color_rgb(140, 140, 100));
            draw_text(1020, _iy + 28, "Slot: " + _item.slot);
        }
    }

    // Scroll hint (only when list overflows)
    draw_set_halign(fa_center);
    if (_count > 8) {
        draw_set_color(make_color_rgb(120, 130, 150));
        draw_text(640, 635, "W/S to scroll");
    }

    draw_set_color(c_white);
    draw_text(640, 660, "Enter / R to continue");

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    ui_draw_character_menu();
    exit;
}


// -----------------------------------------------------------------------------
// 5. COMBAT RESULT OVERLAY
// Drawn on top of everything when combat is resolved.
// -----------------------------------------------------------------------------
if (combat_over) {

    // Semi-transparent black vignette over the full screen
    draw_set_alpha(0.65);
    draw_set_color(c_black);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Centre-screen text
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);

    var _cx = 640;
    var _cy = 320;

    if (combat_result == 1) {
        // Victory
        draw_set_color(c_green);
        // Fake large text: draw the string three times with offsets (drop shadow + main)
        draw_set_color(make_color_rgb(0, 60, 0));
        draw_text_transformed(_cx + 3, _cy + 3, "VICTORY", 3, 3, 0);
        draw_set_color(c_green);
        draw_text_transformed(_cx, _cy, "VICTORY", 3, 3, 0);

    } else if (combat_result == -1) {
        // Defeat
        draw_set_color(make_color_rgb(80, 0, 0));
        draw_text_transformed(_cx + 3, _cy + 3, "DEFEATED", 3, 3, 0);
        draw_set_color(c_red);
        draw_text_transformed(_cx, _cy, "DEFEATED", 3, 3, 0);
    }

    // Run summary
    draw_set_halign(fa_center);
    var _summary_y = _cy + 50;

    draw_set_color(c_yellow);
    var _gold_suffix = "";
    if (combat_result != 1) {
        _gold_suffix = "  |  Kept: " + string(floor(global.current_run_gold * 0.25)) + "g";
    }
    draw_text(_cx, _summary_y,
        "Gold earned: " + string(global.current_run_gold) + "g" + _gold_suffix);
    _summary_y += 28;

    draw_set_color(c_white);
    draw_text(_cx, _summary_y, "Enemies defeated: " + string(global.current_run_kills));
    _summary_y += 28;

    if (combat_result != 1) {
        draw_set_color(make_color_rgb(180, 150, 80));
        draw_text(_cx, _summary_y, "Salvaged: " + string(floor(global.current_run_gold * 0.25)) + "g kept");
        _summary_y += 28;
        if (variable_global_exists("last_run_mercy_item") && global.last_run_mercy_item != "") {
            draw_text(_cx, _summary_y, "Salvaged item: " + global.last_run_mercy_item);
            _summary_y += 28;
        }
    }

    draw_text(_cx, _summary_y, "Run " + string(global.run_count + 1));
    _summary_y += 36;

    // Continue / return prompt — message differs by result
    draw_set_color(c_white);
    if (combat_result == 1) {
        draw_text(_cx, _summary_y, "Press R to continue");
    } else {
        draw_text(_cx, _summary_y, "Press R to return to camp");
    }

    // Reset alignment
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // -------------------------------------------------------------------------
    // 5. RESULT INPUT
    // Only checked when the result screen is visible so R is free during combat.
    // Victory returns to the floor map and marks the room cleared.
    // Defeat calls end_run(-1) to claw back run gold and returns to the hub.
    // -------------------------------------------------------------------------
    if (keyboard_check_pressed(ord("R"))) {
        if (combat_result == 1) {
            // Save HP and secondary resources to carry into the next room
            global.run_current_hp = player.HP;
            if (variable_struct_exists(player, "souls"))       global.run_souls       = player.souls;
            if (variable_struct_exists(player, "blood"))       global.run_blood       = player.blood;
            if (variable_struct_exists(player, "preparation")) global.run_preparation = player.preparation;

            global.just_cleared_room = true;

            if (variable_global_exists("just_cleared_boss") && global.just_cleared_boss) {
                global.just_cleared_boss  = false;
                global.floor_rooms_cleared = [];
                if (global.current_floor < 3) {
                    // Advance to the next floor
                    global.current_floor++;
                } else {
                    // Full dungeon clear — end run as victory
                    end_run(1);
                    room_goto(rm_hub);
                    exit;
                }
            }

            room_goto(rm_dungeon_floor);
        } else {
            end_run(-1);
            room_goto(rm_hub);
        }
    }
}

ui_draw_character_menu();
