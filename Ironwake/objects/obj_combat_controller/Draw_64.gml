// =============================================================================
// obj_combat_controller — Draw GUI event
// Runs every frame after Step. Draws all combat visuals in order:
//   background → enemy HP bars → HUD → result overlay → restart input
// =============================================================================


// -----------------------------------------------------------------------------
// 1. BACKGROUND
// Themed per-floor combat arena if imported (lighter scrim — keeps the arena
// readable behind the enemy cluster); otherwise a flat dark fill so nothing from
// the room layer bleeds through the GUI.
// -----------------------------------------------------------------------------
if (!dungeon_bg_draw("combat", 0.30)) {
    draw_set_color(make_color_rgb(18, 18, 28));
    draw_rectangle(0, 0, 1280, 720, false);
}


// -----------------------------------------------------------------------------
// 2. ENEMY HP BARS (right side, stacked vertically)
// Defeated enemies are skipped so bars collapse upward as enemies fall.
// -----------------------------------------------------------------------------
// Enemy HP bars laid out in a 2-COLUMN grid (was a single 4-tall stack that
// collided with the enemy sprites). Fill left→right, top→bottom: each pair of
// foes starts a new row, so 4 enemies form a 2x2 block instead of one deep column.
var _bar_width   = 280;
var _bar_height  = 28;
var _bar_col_x   = [694, 988];   // the two column origins (x)
var _bar_row_y0  = 64;
var _bar_row_gap = 52;           // bar + status-icon row per grid row

var _living_idx = 0;
var _count = array_length(combat_state.combatants);
for (var _i = 0; _i < _count; _i++) {
    var _c = combat_state.combatants[_i];
    if (_c.is_player)   continue;
    if (_c.is_defeated) continue;

    var _bar_x = _bar_col_x[_living_idx mod 2];
    var _bar_y = _bar_row_y0 + (_living_idx div 2) * _bar_row_gap;

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

    // Status icons below the HP bar for this enemy
    if (variable_struct_exists(_c, "status_effects") && array_length(_c.status_effects) > 0) {
        ui_draw_enemy_status_icons(_bar_x, _bar_y + _bar_height + 4, _c.status_effects);
    }

    _living_idx++;
}


// -----------------------------------------------------------------------------
// 3. COMBAT HUD
// Draws player HP, AP pips, secondary resource, turn queue, ability
// buttons, combat log, and any active telegraph warning.
// -----------------------------------------------------------------------------
ui_draw_combat_hud(combat_state, player, player.abilities, selected_ability, combat_log);

// Awakening tier reference — small label top-right, above the enemy HP bars.
var _awk_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
draw_set_halign(fa_right);
draw_set_valign(fa_top);
draw_set_color(_awk_asc > 0 ? make_color_rgb(225, 150, 70) : make_color_rgb(120, 130, 150));
draw_text(1270, 8, awakening_label());
draw_set_halign(fa_left);


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

// Player sprite (Vael skin override applied via player_combat_sprite).
// Frame index is sprite-aware: 8-dir = east/frame 1, single side-view skin = frame 0.
var _pspr = player_combat_sprite(clamp(player.stats.class_id, 0, 2));
var _pfr  = player_sprite_frame(_pspr);

var _px_draw = 220 + screen_shake_x;
var _py_draw = 310 + screen_shake_y;
if (attack_anim_is_player && _anim_progress > 0) {
    _px_draw = lerp(220, attack_anim_dst_x, _lunge_frac) + screen_shake_x;
    _py_draw = lerp(310, attack_anim_dst_y, _lunge_frac) + screen_shake_y;
}
// Per-sprite damage shake: jolt the player sprite while its hit flash is active,
// plus a constant nervous shiver while stunned/paralyzed.
if (player.hit_flash > 0) { _px_draw += irandom_range(-5, 5); _py_draw += irandom_range(-3, 3); }
if (combatant_has_status_kind(player, "stun")) _px_draw += irandom_range(-2, 2);
// Normalise display size: 92px sprites stay at 2.5x; larger canvases (skins,
// female class sprites) scale down to the same ~230px display height.
var _pscale = 230 / max(1, sprite_get_height(_pspr));
draw_sprite_ext(_pspr, _pfr, _px_draw, _py_draw, _pscale, _pscale, 0, c_white, 1.0);
if (player.hit_flash > 0) {
    player.hit_flash--;
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(_pspr, _pfr, _px_draw, _py_draw, _pscale, _pscale, 0, c_white, (player.hit_flash / 15.0) * 0.8);
    gpu_set_blendmode(bm_normal);
}
// Looping status VFX (poison gas, flames, blind mist, …) over the player sprite.
if (variable_struct_exists(player, "status_effects")) {
    ui_draw_status_fx(_px_draw + sprite_get_width(_pspr) * _pscale * 0.5, _py_draw,
                      sprite_get_height(_pspr) * _pscale, player.status_effects);
}

// Enemy sprites
var _espr_map = {
    "Ashen Skeleton":      spr_skeleton_soldier,
    "Skeleton Archer":     spr_skeleton_archer,
    "Vault Crawler":       spr_vault_crawler,
    "Dungeon Wraith":      spr_dungeon_wraith,
    "Stone Golem":         spr_stone_golem,
    "Vault Guardian":      spr_vault_guardian,
    "Vault Wraith":        spr_vault_wraith,
    "Vault Sentinel":      spr_vault_sentinel,
    "Bone Sovereign":      spr_bone_sovereign,
    "Malgrath the Warden": spr_malgrath_warden,
    "Grave Stalker":        spr_grave_stalker,
    "Bone Colossus":        spr_bone_colossus,
    "Cinder Imp":           spr_cinder_imp,
    "Magma Slug":           spr_magma_slug,
    "Ash Wraith":           spr_ash_wraith,
    "Fire Drake":           spr_fire_drake,
    "Lava Spitter":         spr_lava_spitter,
    "Smoldering Revenant":  spr_smoldering_revenant,
    "Cinder Golem":         spr_cinder_golem,
    "Infernal Revenant":    spr_infernal_revenant,
    "Ice Specter":          spr_ice_specter,
    "Frost Shard":          spr_frost_shard,
    "Glacial Lurker":       spr_glacial_lurker,
    "Pale Archivist":       spr_pale_archivist,
    "Snowbound Wraith":     spr_snowbound_wraith,
    "Frozen Thrall":        spr_frozen_thrall,
    "Glacial Beast":        spr_glacial_beast,
    "Frozen Sentinel":      spr_frozen_sentinel,
    "Glacial Warden":       spr_glacial_beast,
    "Tomb Archon":          spr_frozen_sentinel,
    "The Eternal Frost":    spr_frozen_sentinel,
};
var _espr_x0  = 1110;
var _espr_y0  = 150;
var _espr_dx  = -116;   // strong horizontal spread so foes read as a row, not a column
var _espr_dy  = 24;     // gentle slope (was 70 — enemies marched too far down the screen)
var _espr_zig = 24;     // alternating up/down nudge so the cluster isn't a straight diagonal line
var _espr_idx = 0;

var _ecnt = array_length(combat_state.combatants);
for (var _ei = 0; _ei < _ecnt; _ei++) {
    var _ec = combat_state.combatants[_ei];
    if (_ec.is_player || _ec.is_defeated) continue;

    var _ex = _espr_x0 + (_espr_idx * _espr_dx);
    var _ey = _espr_y0 + (_espr_idx * _espr_dy)
            + ((_espr_idx % 2 == 0) ? -_espr_zig : _espr_zig);

    // Attack slide for the enemy that is currently attacking
    if (!attack_anim_is_player && attack_anim_enemy_idx == _espr_idx && _anim_progress > 0) {
        _ex = lerp(attack_anim_src_x, attack_anim_dst_x, _lunge_frac) + screen_shake_x;
        _ey = lerp(attack_anim_src_y, attack_anim_dst_y, _lunge_frac) + screen_shake_y;
    } else {
        _ex += screen_shake_x;
        _ey += screen_shake_y;
    }

    // Per-sprite damage shake + stun shiver (mirrors the player sprite treatment).
    if (variable_struct_exists(_ec, "hit_flash") && _ec.hit_flash > 0) { _ex += irandom_range(-5, 5); _ey += irandom_range(-3, 3); }
    if (combatant_has_status_kind(_ec, "stun")) _ex += irandom_range(-2, 2);

    if (variable_struct_exists(_espr_map, _ec.name)) {
        var _espr = variable_struct_get(_espr_map, _ec.name);
        var _espr_frame = (sprite_get_number(_espr) > 1) ? 3 : 0;

        // Selected-target reticle: a slowly-swirling arcane rune at the foe's feet,
        // drawn UNDER the sprite so it reads as a ground marker. Lets you map the
        // highlighted name/HP bar to the correct sprite while tabbing targets.
        if (_espr_idx == selected_target) {
            var _cur_cx = _ex + sprite_get_width(_espr)  * 2 * 0.5;
            var _cur_cy = _ey + sprite_get_height(_espr) * 2;            // at the feet
            var _cur_sc = max(0.18, (sprite_get_width(_espr) * 2) / sprite_get_width(spr_target_cursor)) * 0.4;
            _cur_sc    *= 1 + 0.06 * sin(current_time / 180);            // gentle breathing pulse
            var _cur_rot = current_time * 0.05;                          // continuous swirl
            draw_sprite_ext(spr_target_cursor, 0, _cur_cx, _cur_cy,
                            _cur_sc, _cur_sc, _cur_rot, c_white, 0.9);
        }

        draw_sprite_ext(_espr, _espr_frame, _ex, _ey, 2, 2, 0, c_white, 1.0);
        if (variable_struct_exists(_ec, "hit_flash") && _ec.hit_flash > 0) {
            _ec.hit_flash--;
            gpu_set_blendmode(bm_add);
            draw_sprite_ext(_espr, _espr_frame, _ex, _ey, 2, 2, 0, c_white, (_ec.hit_flash / 15.0) * 0.8);
            gpu_set_blendmode(bm_normal);
        }
        // Looping status VFX over this enemy.
        if (variable_struct_exists(_ec, "status_effects")) {
            ui_draw_status_fx(_ex + sprite_get_width(_espr) * 2 * 0.5, _ey,
                              sprite_get_height(_espr) * 2, _ec.status_effects);
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
    // Staggered popups (e.g. multiple poison stacks ticking the same frame) hold
    // a countdown so they appear one after another instead of overlapping exactly.
    if (variable_struct_exists(_dp, "delay") && _dp.delay > 0) {
        _dp.delay--;
        array_push(_kept_popups, _dp);
        continue;
    }
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


// Stash is hub-only — button not shown during combat.

// --- ITEMS button (bottom-right, always visible during player turn) ---
if (player_turn && !combat_over) {
    var _ibx = 1060;
    var _iby = 660;
    var _ibw = 180;
    var _ibh = 50;
    var _has_consumables = variable_global_exists("consumable_inventory")
                           && array_length(global.consumable_inventory) > 0;
    var _ib_lit = consumable_quick_open || (_has_consumables
                  && device_mouse_x_to_gui(0) >= _ibx && device_mouse_x_to_gui(0) < _ibx + _ibw
                  && device_mouse_y_to_gui(0) >= _iby && device_mouse_y_to_gui(0) < _iby + _ibh);

    draw_set_alpha(1.0);
    if (!_has_consumables) {
        draw_set_color(make_color_rgb(28, 28, 38));
        draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, false);
        draw_set_color(make_color_rgb(45, 48, 65));
        draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, true);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(make_color_rgb(55, 60, 82));
        draw_text(_ibx + _ibw / 2, _iby + _ibh / 2 - 8, "[ I ]  ITEMS");
        draw_set_color(make_color_rgb(45, 50, 68));
        draw_text(_ibx + _ibw / 2, _iby + _ibh / 2 + 10, "None carried");
    } else {
        draw_set_color(consumable_quick_open ? make_color_rgb(28, 55, 40) : make_color_rgb(18, 40, 28));
        draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, false);
        draw_set_color(consumable_quick_open ? make_color_rgb(60, 190, 110) : make_color_rgb(35, 130, 70));
        draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, true);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(c_white);
        draw_text(_ibx + _ibw / 2, _iby + _ibh / 2 - 8, "[ I ]  ITEMS");
        draw_set_color(make_color_rgb(100, 200, 140));
        draw_text(_ibx + _ibw / 2, _iby + _ibh / 2 + 10,
            string(array_length(global.consumable_inventory)) + " carried");
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // --- Consumable quick-use popup ---
    if (consumable_quick_open && _has_consumables) {
        var _qcount = array_length(global.consumable_inventory);
        // Windowed list — cap visible rows and scroll around the cursor so the
        // selection is always on screen. Step's mouse hit-test uses the same math.
        var _q_max_vis = 6;
        var _q_vis     = min(_qcount, _q_max_vis);
        var _q_first   = ui_list_window_first(consumable_quick_cursor, _qcount, _q_max_vis);
        var _q_last    = min(_qcount, _q_first + _q_max_vis);
        var _pw     = 500;
        var _ph     = 56 + _q_vis * 72 + 44;
        var _px     = 640 - _pw / 2;
        var _py     = max(80, 660 - _ph - 14);

        // Background
        draw_set_alpha(0.97);
        draw_set_color(make_color_rgb(12, 16, 28));
        draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(55, 170, 100));
        draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

        // Header
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        var _qhdr = "USE CONSUMABLE  (1 AP)";
        if (_qcount > _q_max_vis) _qhdr += "   (" + string(consumable_quick_cursor + 1) + "/" + string(_qcount) + ")";
        draw_text_transformed(_px + _pw / 2, _py + 14, _qhdr, 1.1, 1.1, 0);
        // Scroll hints
        draw_set_color(make_color_rgb(120, 210, 160));
        if (_q_first > 0)        draw_text(_px + _pw / 2, _py + 36, "▲ more");
        if (_q_last < _qcount)   draw_text(_px + _pw / 2, _py + _ph - 44, "▼ more");

        // Item rows
        for (var _qi = _q_first; _qi < _q_last; _qi++) {
            var _qitem  = global.consumable_inventory[_qi];
            var _qry    = _py + 50 + (_qi - _q_first) * 72;
            var _is_cur = (_qi == consumable_quick_cursor);

            draw_set_alpha(_is_cur ? 1.0 : 0.65);
            draw_set_color(_is_cur ? make_color_rgb(22, 55, 35) : make_color_rgb(14, 18, 30));
            draw_rectangle(_px + 10, _qry, _px + _pw - 10, _qry + 62, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_cur ? make_color_rgb(60, 200, 110) : make_color_rgb(35, 80, 52));
            draw_rectangle(_px + 10, _qry, _px + _pw - 10, _qry + 62, true);

            draw_set_halign(fa_left);
            draw_set_color(_is_cur ? c_white : make_color_rgb(160, 175, 195));
            draw_text(_px + 22, _qry + 8, _qitem.name);
            draw_set_color(_is_cur ? make_color_rgb(120, 210, 160) : make_color_rgb(80, 110, 95));
            draw_text(_px + 22, _qry + 32, _qitem.description);
        }

        // Footer hint
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(70, 85, 110));
        draw_text(_px + _pw / 2, _py + _ph - 28, "W/S: Navigate   Enter/Click: Use   I/Esc: Close");
        draw_set_halign(fa_left);
        draw_set_alpha(1.0);
    }
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
        var _alloc_stat_hints = [
            "Boosts physical ability dmg  •  Phys dmg reduction  •  Power crit +1.5% (×1.6 dmg)",
            "+3 accuracy  •  +2 dodge  •  Precision crit +2% (×1.35 dmg)",
            "+3 max HP per point",
            "Boosts elemental ability dmg  •  Arcane crit +1% (×1.25 dmg)",
            "Boosts DoT / status effect dmg  •  Effect crit +1.5% (extends statuses)",
            "Boosts ALL ability damage  •  +1% gold find/pt  •  cheaper NPC prices (1.5%/pt, max 30%)"
        ];

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
            draw_text(360, _sy + 10, _alloc_stat_descs[_si] + "  (" + _alloc_stat_names[_si] + ")");

            // Stat hint description on second line
            var _hint_col = (_is_sel || _is_pend) ? make_color_rgb(160, 180, 210) : make_color_rgb(90, 100, 120);
            draw_set_color(_hint_col);
            draw_text(360, _sy + 32, _alloc_stat_hints[_si]);

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
            ui_draw_consumable_icon(248, _iy, 44, _item);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_set_halign(fa_left);
            draw_text(304, _iy + 5, _item.name);
            draw_set_color(make_color_rgb(140, 200, 200));
            draw_text(304, _iy + 28, _item.description);
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(1020, _iy + 5, "[CONSUMABLE]");
        } else {
            var _rarity_col = item_rarity_color(_item.rarity);
            ui_draw_item_icon(248, _iy, 44, _item);
            draw_set_color(_rarity_col);
            draw_set_halign(fa_left);
            draw_text(304, _iy + 2, _item.name);
            // Stat line (e.g. "+4 STR, +12 HP") so found gear is readable at a glance
            draw_set_color(c_white);
            draw_text(304, _iy + 22, ui_item_stat_str(_item));
            draw_set_color(make_color_rgb(160, 165, 185));
            draw_text(304, _iy + 40, _item.effect_desc);
            draw_set_halign(fa_right);
            draw_set_color(_rarity_col);
            draw_text(1020, _iy + 5, "[" + item_rarity_name(_item.rarity) + "]");
            draw_set_color(make_color_rgb(140, 140, 100));
            draw_text(1020, _iy + 28, "Slot: " + item_slot_label(_item.slot));
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

    // Stop battle music and start result music — fires exactly once
    if (!combat_music_stopped) {
        combat_music_stopped = true;
        audio_stop_sound(_3_critical_LOOP);
        audio_stop_sound(_14_BOSS_y_LOOP);
        if (combat_result == -1) {
            audio_play_sound(_15_game_over_INITIAL, 1, true);
        }
        if (combat_result == 1
            && variable_global_exists("current_floor") && global.current_floor >= 3
            && variable_global_exists("just_cleared_boss") && global.just_cleared_boss) {
            audio_play_sound(MusicBox1, 1, true);
        }
    }

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

    // Continue / return prompt — hidden when extract popup is open
    if (!boss_extract_open) {
        draw_set_color(c_white);
        if (combat_result == 1) {
            draw_text(_cx, _summary_y, "Press R to continue");
        } else {
            draw_text(_cx, _summary_y, "Press R to return to camp");
        }
    }

    // Reset alignment
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // -------------------------------------------------------------------------
    // 5a. BOSS EXTRACT POPUP — shown after defeating a floor boss (floor < 3)
    // Player chooses: E = extract to camp, Enter/Space = descend to next floor.
    // -------------------------------------------------------------------------
    if (boss_extract_open) {
        // Backdrop
        draw_set_alpha(0.88);
        draw_set_color(make_color_rgb(8, 10, 20));
        draw_rectangle(240, 240, 1040, 490, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(60, 80, 140));
        draw_rectangle(240, 240, 1040, 490, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_top);
        draw_set_color(c_white);
        draw_text_transformed(_cx, 264, "FLOOR " + string(global.current_floor) + " CLEARED", 1.3, 1.3, 0);
        draw_set_color(make_color_rgb(160, 175, 210));
        draw_text(_cx, 306, "What will you do?");

        // Extract button
        draw_set_color(make_color_rgb(16, 36, 16));
        draw_rectangle(268, 340, 620, 415, false);
        draw_set_color(make_color_rgb(50, 160, 70));
        draw_rectangle(268, 340, 620, 415, true);
        draw_set_color(c_white);
        draw_text_transformed(444, 355, "[ E ]  Extract to Camp", 1.1, 1.1, 0);
        draw_set_color(make_color_rgb(140, 210, 140));
        draw_text(444, 386, "Keep all rewards  •  Safe");

        // Continue button
        draw_set_color(make_color_rgb(30, 22, 10));
        draw_rectangle(660, 340, 1012, 415, false);
        draw_set_color(make_color_rgb(180, 130, 40));
        draw_rectangle(660, 340, 1012, 415, true);
        draw_set_color(c_white);
        draw_text_transformed(836, 355, "[ Enter ]  Descend Deeper", 1.1, 1.1, 0);
        draw_set_color(make_color_rgb(220, 190, 120));
        draw_text(836, 386, "Floor " + string(global.current_floor + 1) + "  •  Harder enemies");

        draw_set_color(make_color_rgb(70, 80, 110));
        draw_text(_cx, 430, "E: Extract     Enter / Space: Continue to next floor");

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // Mouse hover highlights
        var _bmx = device_mouse_x_to_gui(0);
        var _bmy = device_mouse_y_to_gui(0);
        var _hover_extract  = (_bmx >= 268 && _bmx < 620  && _bmy >= 340 && _bmy < 415);
        var _hover_continue = (_bmx >= 660 && _bmx < 1012 && _bmy >= 340 && _bmy < 415);
        if (_hover_extract) {
            draw_set_alpha(0.18);
            draw_set_color(c_white);
            draw_rectangle(268, 340, 620, 415, false);
            draw_set_alpha(1.0);
        }
        if (_hover_continue) {
            draw_set_alpha(0.18);
            draw_set_color(c_white);
            draw_rectangle(660, 340, 1012, 415, false);
            draw_set_alpha(1.0);
        }

        // Input: Extract
        var _do_extract = keyboard_check_pressed(ord("E"))
            || (mouse_check_button_pressed(mb_left) && _hover_extract);
        if (_do_extract) {
            audio_stop_sound(MusicBox1);
            end_run(0);
            global.current_floor       = 1;
            global.floor_rooms_cleared = [];
            global.floor_map_floor     = -1;
            room_goto(rm_hub);
            exit;
        }

        // Input: Continue
        var _do_continue = keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)
            || keyboard_check_pressed(vk_space)
            || (mouse_check_button_pressed(mb_left) && _hover_continue);
        if (_do_continue) {
            boss_extract_open = false;
            audio_stop_sound(MusicBox1);
            global.just_cleared_boss   = false;
            global.floor_rooms_cleared = [];
            global.current_floor++;
            room_goto(rm_dungeon_floor);
            exit;
        }

        exit; // block normal R-key handler while popup is open
    }

    // -------------------------------------------------------------------------
    // 5b. RESULT INPUT
    // Only checked when the result screen is visible so R is free during combat.
    // Victory returns to the floor map and marks the room cleared.
    // Defeat calls end_run(-1) to claw back run gold and returns to the hub.
    // -------------------------------------------------------------------------
    if (keyboard_check_pressed(ord("R")) || keyboard_check_pressed(vk_enter)
        || keyboard_check_pressed(vk_space) || mouse_check_button_pressed(mb_left)) {
        if (combat_result == 1) {
            // Save HP and secondary resources to carry into the next room
            global.run_current_hp = player.HP;
            if (variable_struct_exists(player, "souls"))       global.run_souls       = player.souls;
            if (variable_struct_exists(player, "blood"))       global.run_blood       = player.blood;
            if (variable_struct_exists(player, "preparation")) global.run_preparation = player.preparation;

            global.just_cleared_room = true;

            if (variable_global_exists("just_cleared_boss") && global.just_cleared_boss) {
                if (global.current_floor >= 3) {
                    // Full dungeon clear — end run as victory
                    global.just_cleared_boss = false;
                    global.floor_rooms_cleared = [];
                    audio_stop_sound(MusicBox1);
                    end_run(1);
                    room_goto(rm_hub);
                    exit;
                } else {
                    // Floor boss cleared — open extract choice popup, don't advance yet
                    boss_extract_open = true;
                    exit;
                }
            }

            room_goto(rm_dungeon_floor);
        } else {
            audio_stop_sound(_15_game_over_INITIAL);
            end_run(-1);
            room_goto(rm_hub);
        }
    }
}

ui_draw_stash_screen();
ui_draw_character_menu();

// Comparison panel — drawn above all overlays
if (instance_exists(obj_game_controller)) {
    var _gc_cmp2 = instance_find(obj_game_controller, 0);
    if (_gc_cmp2.comparison_open && _gc_cmp2.comparison_item != undefined) {
        ui_draw_comparison_panel(_gc_cmp2.comparison_item, _gc_cmp2.comparison_equipped);
    }
}

// Pause / Esc menu + its Settings sub-screen (combat doesn't otherwise host the
// settings overlay) — topmost.
if (variable_global_exists("settings_open") && global.settings_open) ui_draw_settings_overlay();
ui_draw_pause_menu();
