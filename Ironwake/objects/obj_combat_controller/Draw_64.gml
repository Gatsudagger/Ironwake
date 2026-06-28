// =============================================================================
// obj_combat_controller - Draw GUI event
// Runs every frame after Step. Draws all combat visuals in order:
//   background -> enemy HP bars -> HUD -> result overlay -> restart input
// =============================================================================


// -----------------------------------------------------------------------------
// 1. BACKGROUND
// Themed per-floor combat arena if imported (lighter scrim - keeps the arena
// readable behind the enemy cluster); otherwise a flat dark fill so nothing from
// the room layer bleeds through the GUI.
// -----------------------------------------------------------------------------
if (!dungeon_bg_draw("combat", 0.30)) {
    draw_set_color(make_color_rgb(18, 18, 28));
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
}

// Reset the hover-status tooltip each frame; the status icon rows (enemy bars +
// player buff row, drawn below) set it when the mouse is over a badge, and it's
// drawn after those rows so the popup lands on top. (Task: hover-explain debuffs.)
global.combat_status_tip = undefined;


// -----------------------------------------------------------------------------
// 2. ENEMY HP BARS (right side, stacked vertically)
// Defeated enemies are skipped so bars collapse upward as enemies fall.
// -----------------------------------------------------------------------------
// Enemy HP bars laid out in a 2-COLUMN grid (was a single 4-tall stack that
// collided with the enemy sprites). Fill left->right, top->bottom: each pair of
// foes starts a new row, so 4 enemies form a 2x2 block instead of one deep column.
var _bar_width   = 400;
var _bar_height  = 42;
// Columns spread wider apart so the LEFT-of-bar target reticle for the right
// column sits in a clear gutter instead of clipping the end of the left bar.
var _bar_col_x   = [990, 1485];   // the two column origins (x)
var _bar_row_y0  = 96;
var _bar_row_gap = 78;           // bar + status-icon row per grid row

var _living_idx = 0;
var _count = array_length(combat_state.combatants);

// Inspect-on-hover: the enemy under the cursor (its HP bar OR its sprite) gets an
// inspect tooltip drawn after the HUD. Capture the cursor + target here; the bar
// loop and the sprite loop below both test against it. (Task: enemy class clarity.)
var _mx_gui = device_mouse_x_to_gui(0);
var _my_gui = device_mouse_y_to_gui(0);
var _inspect_target = undefined;

for (var _i = 0; _i < _count; _i++) {
    var _c = combat_state.combatants[_i];
    if (_c.is_player)   continue;
    if (_c.is_defeated) continue;

    var _bar_x = _bar_col_x[_living_idx mod 2];
    var _bar_y = _bar_row_y0 + (_living_idx div 2) * _bar_row_gap;

    if (_living_idx == selected_target) {
        // Small target reticle just LEFT of the bar - the SAME marker shown under the
        // selected foe's sprite (just smaller), so the highlighted name/HP bar and the
        // sprite read as one selection. The old ">" glyph was big and bled into the
        // adjacent column's bar; this is sized + centred to sit in the gutter cleanly.
        var _mk_sz = 32;   // doubled from 16 so the bar marker reads clearly
        var _mk_sc = (_mk_sz / max(1, sprite_get_width(spr_target_cursor)))
                   * (1 + 0.06 * sin(current_time / 180));   // same breathing pulse
        // Pushed a little further left so the larger marker still clears the bar.
        draw_sprite_ext(spr_target_cursor, 0, _bar_x - 22, _bar_y + _bar_height / 2,
                        _mk_sc, _mk_sc, current_time * 0.05, c_white, 0.95);
    }

    ui_draw_hp_bar(_bar_x, _bar_y, _bar_width, _bar_height,
                   _c.HP, _c.max_HP, _c.name, true);

    // Attack-class tag (reach/kind), right-aligned under the bar so the player can
    // see which control applies: ROOT blocks Melee, SILENCE blocks Spell, STUN all.
    // Ranged foes are tinted amber as a "root won't stop this" cue.
    var _ec_ranged = (variable_struct_exists(_c, "reach") && _c.reach == "ranged");
    draw_set_font(fnt_ui_small);
    draw_set_halign(fa_right);
    draw_set_valign(fa_top);
    draw_set_color(_ec_ranged ? make_color_rgb(220, 170, 80) : make_color_rgb(140, 155, 185));
    draw_text(_bar_x + _bar_width, _bar_y + _bar_height + 9, enemy_class_tag(_c));
    draw_set_halign(fa_left);
    draw_set_font(-1);

    // The HP bar (+ its class-tag line) is an inspect surface - hovering it opens
    // the inspect tooltip after the HUD draws.
    if (_mx_gui >= _bar_x && _mx_gui <= _bar_x + _bar_width
        && _my_gui >= _bar_y && _my_gui <= _bar_y + _bar_height + 30) {
        _inspect_target = _c;
    }

    // Status icons below the HP bar for this enemy
    if (variable_struct_exists(_c, "status_effects") && array_length(_c.status_effects) > 0) {
        ui_draw_enemy_status_icons(_bar_x, _bar_y + _bar_height + 6, _c.status_effects);
    }

    _living_idx++;
}


// -----------------------------------------------------------------------------
// 3. COMBAT HUD
// Draws player HP, AP pips, secondary resource, turn queue, ability
// buttons, combat log, and any active telegraph warning.
// -----------------------------------------------------------------------------
// draw_log=false defers the hit-preview + combat log to ui_draw_combat_overlay
// (called after the battler sprites) so combat text always sits on top of them.
ui_draw_combat_hud(combat_state, player, player.abilities, selected_ability, combat_log, false);

// Awakening tier reference - small label top-right, above the enemy HP bars.
var _awk_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
draw_set_font(fnt_ui_small);
draw_set_halign(fa_right);
draw_set_valign(fa_top);
draw_set_color(_awk_asc > 0 ? make_color_rgb(225, 150, 70) : make_color_rgb(120, 130, 150));
draw_text(1905, 12, awakening_label());
draw_set_font(-1);
draw_set_halign(fa_left);


// -----------------------------------------------------------------------------
// 3b. CHARACTER SPRITES + COMBAT VFX
// Handles: attack slide lunge, hit flash (additive blend), screen shake,
// and floating damage/heal number popups.
// -----------------------------------------------------------------------------

// Screen shake: randomise offset while timer counts down
if (screen_shake_timer > 0) {
    screen_shake_timer--;
    screen_shake_x = irandom_range(-5, 5);
    screen_shake_y = irandom_range(-3, 3);
} else {
    screen_shake_x = 0;
    screen_shake_y = 0;
}

// Attack slide: compute lunge fraction (0 -> peak -> 0) over 20 frames
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

var _px_draw = 330 + screen_shake_x;
var _py_draw = 465 + screen_shake_y;
if (attack_anim_is_player && _anim_progress > 0) {
    _px_draw = lerp(330, attack_anim_dst_x, _lunge_frac) + screen_shake_x;
    _py_draw = lerp(465, attack_anim_dst_y, _lunge_frac) + screen_shake_y;
}
// Per-sprite damage shake: jolt the player sprite while its hit flash is active,
// plus a constant nervous shiver while stunned/paralyzed.
if (player.hit_flash > 0) { _px_draw += irandom_range(-8, 8); _py_draw += irandom_range(-5, 5); }
if (combatant_has_status_kind(player, "stun")) _px_draw += irandom_range(-3, 3);
// Normalise display size: larger canvases (skins, female class sprites) scale down
// to the same ~345px display height (native 1080p; was 230px at 720p).
var _pscale = 345 / max(1, sprite_get_height(_pspr));
// Ground shadow beneath the player so the sprite reads against busy backgrounds.
// Baseline raised to ~0.94 of the canvas height so it sits at the model's feet
// rather than at the empty bottom of the sprite canvas.
ui_draw_ground_shadow(_px_draw + sprite_get_width(_pspr) * _pscale * 0.5,
                      _py_draw + sprite_get_height(_pspr) * _pscale * 0.94,
                      sprite_get_width(_pspr) * _pscale);
draw_sprite_ext(_pspr, _pfr, _px_draw, _py_draw, _pscale, _pscale, 0, c_white, 1.0);
if (player.hit_flash > 0) {
    player.hit_flash--;
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(_pspr, _pfr, _px_draw, _py_draw, _pscale, _pscale, 0, c_white, (player.hit_flash / 15.0) * 0.8);
    gpu_set_blendmode(bm_normal);
}
// Looping status VFX (poison gas, flames, blind mist, ...) over the player sprite.
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
    // Scorched Depths bosses - reuse fitting elite sprites (these renamed clones were
    // missing from the map, so they rendered with no model). See obj_combat_controller Create.
    "Forge Tyrant":         spr_cinder_golem,
    "Molten Revenant":      spr_infernal_revenant,
    "The Ashen Colossus":   spr_fire_drake,
};
var _espr_x0  = 1665;
var _espr_y0  = 225;
var _espr_dx  = -174;   // strong horizontal spread so foes read as a row, not a column
var _espr_dy  = 36;     // gentle slope (was 70 - enemies marched too far down the screen)
var _espr_zig = 36;     // alternating up/down nudge so the cluster isn't a straight diagonal line
var _espr_idx = 0;

var _ecnt = array_length(combat_state.combatants);
for (var _ei = 0; _ei < _ecnt; _ei++) {
    var _ec = combat_state.combatants[_ei];
    if (_ec.is_player || _ec.is_defeated) continue;

    var _ex = _espr_x0 + (_espr_idx * _espr_dx);
    var _ey = _espr_y0 + (_espr_idx * _espr_dy)
            + ((_espr_idx % 2 == 0) ? -_espr_zig : _espr_zig);

    // Inspect hit-box from the RESTING sprite position (before lunge/shake jitter is
    // applied below) so hovering the creature itself also opens the inspect tooltip,
    // and the hot-zone doesn't jump around while it animates.
    if (variable_struct_exists(_espr_map, _ec.name)) {
        var _isp   = variable_struct_get(_espr_map, _ec.name);
        var _isp_w = sprite_get_width(_isp)  * 3;
        var _isp_h = sprite_get_height(_isp) * 3;
        if (_mx_gui >= _ex && _mx_gui <= _ex + _isp_w
            && _my_gui >= _ey && _my_gui <= _ey + _isp_h) {
            _inspect_target = _ec;
        }
    }

    // Attack slide for the enemy that is currently attacking
    if (!attack_anim_is_player && attack_anim_enemy_idx == _espr_idx && _anim_progress > 0) {
        _ex = lerp(attack_anim_src_x, attack_anim_dst_x, _lunge_frac) + screen_shake_x;
        _ey = lerp(attack_anim_src_y, attack_anim_dst_y, _lunge_frac) + screen_shake_y;
    } else {
        _ex += screen_shake_x;
        _ey += screen_shake_y;
    }

    // Per-sprite damage shake + stun shiver (mirrors the player sprite treatment).
    if (variable_struct_exists(_ec, "hit_flash") && _ec.hit_flash > 0) { _ex += irandom_range(-8, 8); _ey += irandom_range(-5, 5); }
    if (combatant_has_status_kind(_ec, "stun")) _ex += irandom_range(-3, 3);

    if (variable_struct_exists(_espr_map, _ec.name)) {
        var _espr = variable_struct_get(_espr_map, _ec.name);
        var _espr_frame = (sprite_get_number(_espr) > 1) ? 3 : 0;

        // Ground shadow beneath the enemy (under both the reticle and the sprite) so
        // foes read against busy backgrounds.
        // Baseline raised to ~0.94 of the sprite height so the shadow hugs the
        // enemy's feet; width scales with the model so big foes cast bigger shadows.
        ui_draw_ground_shadow(_ex + sprite_get_width(_espr)  * 3 * 0.5,
                              _ey + sprite_get_height(_espr) * 3 * 0.94,
                              sprite_get_width(_espr) * 3);

        // Selected-target reticle: a slowly-swirling arcane rune at the foe's feet,
        // drawn UNDER the sprite so it reads as a ground marker. Lets you map the
        // highlighted name/HP bar to the correct sprite while tabbing targets.
        if (_espr_idx == selected_target) {
            var _cur_cx = _ex + sprite_get_width(_espr)  * 3 * 0.5;
            var _cur_cy = _ey + sprite_get_height(_espr) * 3;            // at the feet
            // Shrunk 30% from the old *0.4 factor (0.4 -> 0.28) so the ground rune sits tighter under the foe.
            var _cur_sc = max(0.18, (sprite_get_width(_espr) * 3) / sprite_get_width(spr_target_cursor)) * 0.28;
            _cur_sc    *= 1 + 0.06 * sin(current_time / 180);            // gentle breathing pulse
            var _cur_rot = current_time * 0.05;                          // continuous swirl
            draw_sprite_ext(spr_target_cursor, 0, _cur_cx, _cur_cy,
                            _cur_sc, _cur_sc, _cur_rot, c_white, 0.9);
        }

        draw_sprite_ext(_espr, _espr_frame, _ex, _ey, 3, 3, 0, c_white, 1.0);
        if (variable_struct_exists(_ec, "hit_flash") && _ec.hit_flash > 0) {
            _ec.hit_flash--;
            gpu_set_blendmode(bm_add);
            draw_sprite_ext(_espr, _espr_frame, _ex, _ey, 3, 3, 0, c_white, (_ec.hit_flash / 15.0) * 0.8);
            gpu_set_blendmode(bm_normal);
        }
        // Looping status VFX over this enemy.
        if (variable_struct_exists(_ec, "status_effects")) {
            ui_draw_status_fx(_ex + sprite_get_width(_espr) * 3 * 0.5, _ey,
                              sprite_get_height(_espr) * 3, _ec.status_effects);
        }
    }
    _espr_idx++;
}

// VFX impact sprite: plays its frames, fades out and shrinks over its lifetime with
// additive blend. The sub-image is driven by the countdown so multi-frame Gigapack
// effects animate; single-frame sprites (spr_fx_impact) just hold frame 0. Scale is
// normalised by source width so 64px and 128px effects read at a consistent on-screen
// size.
if (vfx_timer > 0) {
    vfx_timer--;
    var _vfx_max    = (vfx_timer_max > 0) ? vfx_timer_max : 20;
    var _vfx_prog   = clamp((_vfx_max - vfx_timer) / _vfx_max, 0, 1);   // 0 -> 1 over life
    var _vfx_count  = sprite_get_number(vfx_spr);
    var _vfx_frame  = clamp(floor(_vfx_prog * _vfx_count), 0, _vfx_count - 1);
    var _vfx_alpha  = min(1.0, vfx_timer / 10.0);
    var _vfx_target = lerp(248, 173, _vfx_prog);                        // on-screen px, shrinks
    var _vfx_scale  = _vfx_target / max(1, sprite_get_width(vfx_spr));
    gpu_set_blendmode(bm_add);
    draw_set_alpha(_vfx_alpha);
    draw_sprite_ext(vfx_spr, _vfx_frame, vfx_x + screen_shake_x, vfx_y + screen_shake_y, _vfx_scale, _vfx_scale, 0, c_white, 1.0);
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1.0);
}

// Floating damage / heal numbers
draw_set_font(fnt_ui);
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
draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// Combat text overlay (hit preview + combat log) - drawn AFTER the battler sprites
// and their shadows so combat text always has visual priority over them.
ui_draw_combat_overlay(combat_state, player, player.abilities, selected_ability, combat_log);

// Hover-explain tooltip for a status badge (set by ui_draw_status_icon_row above).
// Drawn here so it sits over the bars/HUD; later full-screen overlays (consumable
// menu, ability detail, loot, pause) draw afterwards and naturally occlude it.
if (global.combat_status_tip != undefined) {
    ui_draw_status_tooltip(global.combat_status_tip.x, global.combat_status_tip.y,
                           global.combat_status_tip.se);
}

// Enemy inspect tooltip - attack class + which controls stop the hovered foe. Drawn
// last (over bars/HUD) but suppressed while a status-badge tooltip is up, so the two
// hover popups don't overlap.
if (_inspect_target != undefined && global.combat_status_tip == undefined) {
    ui_draw_enemy_inspect_tooltip(_mx_gui, _my_gui, _inspect_target);
}

// -----------------------------------------------------------------------------
// 3a. AP SYSTEM OVERLAYS (player turn only)
// Drawn after the HUD so they appear on top of ability buttons.
// Button positions must match ui_draw_ability_buttons: x=240, y=990, 240x75, gap=12.
// -----------------------------------------------------------------------------
if (player_turn && !combat_over) {
    var _btn_w   = 240;
    var _btn_h   = 75;
    var _btn_gap = 12;
    var _btn_x0  = 240;
    var _btn_y   = 990;

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
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(175, 85, 85));
            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            draw_text(_bx + _btn_w / 2, _btn_y + _btn_h / 2, "USED");
            draw_set_font(-1);
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
        }
    }

    // End Turn prompt - brighter when out of AP to make it more visible
    var _ap_col;
    if (player.energy <= 0) {
        _ap_col = make_color_rgb(235, 195, 60);
    } else {
        _ap_col = make_color_rgb(130, 150, 115);
    }
    draw_set_font(fnt_ui);
    draw_set_halign(fa_center);
    draw_set_color(_ap_col);
    draw_text(960, 954, "T: End Turn   " + string(player.energy) + " AP remaining");
    draw_set_font(-1);
    draw_set_halign(fa_left);
}


// Stash is hub-only - button not shown during combat.

// --- ITEMS button (bottom-right, always visible during player turn) ---
if (player_turn && !combat_over) {
    // Small framed button, far bottom-right so it clears the ability tooltip
    // (x1260-1740). Toggles the quick menu; bound to the C key (Step_0 reads ord("C")).
    // Coords must stay in sync with the click hit-test in Step_0.
    var _ibx = 1767;
    var _iby = 990;
    var _ibw = 141;
    var _ibh = 63;
    var _cx  = _ibx + _ibw / 2;
    var _has_consumables = variable_global_exists("consumable_inventory")
                           && array_length(global.consumable_inventory) > 0;

    // Per-state colors + subtitle.
    var _fill   = make_color_rgb(28, 28, 38);
    var _border = make_color_rgb(45, 48, 65);
    var _tcol   = make_color_rgb(55, 60, 82);
    var _scol   = make_color_rgb(45, 50, 68);
    var _sub    = "none";
    if (_has_consumables) {
        _fill   = consumable_quick_open ? make_color_rgb(28, 55, 40) : make_color_rgb(18, 40, 28);
        _border = consumable_quick_open ? make_color_rgb(60, 190, 110) : make_color_rgb(35, 130, 70);
        _tcol   = c_white;
        _scol   = make_color_rgb(100, 200, 140);
        _sub    = "x" + string(array_length(global.consumable_inventory)) + " held";
    }

    draw_set_alpha(1.0);
    // Fill
    draw_set_color(_fill);
    draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, false);
    // Framed double border (dark outer edge + brighter inner edge) so it reads as a button.
    draw_set_color(make_color_rgb(10, 12, 18));
    draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, true);
    draw_set_color(_border);
    draw_rectangle(_ibx + 2, _iby + 2, _ibx + _ibw - 2, _iby + _ibh - 2, true);

    // Labels - real fonts at native size (fit comfortably in the button).
    draw_set_font(fnt_ui_small);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    var _title = "[ C ] ITEMS";
    draw_set_color(_tcol);
    draw_text(_cx, _iby + _ibh / 2 - 12, _title);
    draw_set_color(_scol);
    draw_text(_cx, _iby + _ibh / 2 + 12, _sub);
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // --- Consumable quick-use popup ---
    // Opens even with an empty run buffer (shows "No consumables held.") so the
    // [C] button never silently no-ops. Stash consumables stay hub-only.
    if (consumable_quick_open) {
        // Grouped view: identical consumables collapse to one "Name xN" row (the real
        // array still holds N entries). Step uses the same grouping for nav + use.
        var _qgroups = consumables_grouped();
        var _qcount  = array_length(_qgroups);
        // Windowed list - cap visible rows and scroll around the cursor so the
        // selection is always on screen. Step's mouse hit-test uses the same math.
        var _q_max_vis = 6;
        var _q_vis     = min(_qcount, _q_max_vis);
        var _q_first   = ui_list_window_first(consumable_quick_cursor, _qcount, _q_max_vis);
        var _q_last    = min(_qcount, _q_first + _q_max_vis);
        var _pw     = 750;
        var _ph     = 84 + _q_vis * 108 + 66;
        var _px     = 960 - _pw / 2;
        var _py     = max(120, 990 - _ph - 21);

        // Background
        draw_set_alpha(0.97);
        draw_set_color(make_color_rgb(12, 16, 28));
        draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(55, 170, 100));
        draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

        // Header
        draw_set_font(fnt_ui);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        var _qhdr = (_qcount > 0) ? "USE CONSUMABLE  (1 AP)" : "CONSUMABLES";
        if (_qcount > _q_max_vis) _qhdr += "   (" + string(consumable_quick_cursor + 1) + "/" + string(_qcount) + ")";
        draw_text(_px + _pw / 2, _py + 21, _qhdr);
        // Scroll hints
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(120, 210, 160));
        if (_q_first > 0)        draw_text(_px + _pw / 2, _py + 54, "^ more");
        if (_q_last < _qcount)   draw_text(_px + _pw / 2, _py + _ph - 66, "v more");

        // Empty-state message (run buffer holds no consumables this run).
        if (_qcount == 0) {
            draw_set_font(fnt_ui);
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(150, 165, 185));
            draw_text(_px + _pw / 2, _py + _ph / 2 - 6, "No consumables held.");
        }

        // Item rows
        for (var _qi = _q_first; _qi < _q_last; _qi++) {
            var _qitem  = _qgroups[_qi].item;
            var _qlabel = consumable_group_label(_qgroups[_qi]);
            var _qry    = _py + 75 + (_qi - _q_first) * 108;
            var _is_cur = (_qi == consumable_quick_cursor);

            draw_set_alpha(_is_cur ? 1.0 : 0.65);
            draw_set_color(_is_cur ? make_color_rgb(22, 55, 35) : make_color_rgb(14, 18, 30));
            draw_rectangle(_px + 15, _qry, _px + _pw - 15, _qry + 93, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_cur ? make_color_rgb(60, 200, 110) : make_color_rgb(35, 80, 52));
            draw_rectangle(_px + 15, _qry, _px + _pw - 15, _qry + 93, true);

            draw_set_halign(fa_left);
            draw_set_font(fnt_ui);
            draw_set_color(_is_cur ? c_white : make_color_rgb(160, 175, 195));
            draw_text(_px + 33, _qry + 12, _qlabel);
            draw_set_font(fnt_ui_small);
            draw_set_color(_is_cur ? make_color_rgb(120, 210, 160) : make_color_rgb(80, 110, 95));
            draw_text(_px + 33, _qry + 48, _qitem.description);
        }

        // Footer hint
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(70, 85, 110));
        draw_text(_px + _pw / 2, _py + _ph - 42,
            (_qcount > 0) ? "W/S: Navigate   Enter/Click: Use   C/Esc: Close" : "C/Esc: Close");
        draw_set_font(-1);
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
        draw_rectangle(0, 0, GUI_W, GUI_H, false);
        draw_set_alpha(1.0);

        var _pend_idx   = _gc_alloc_draw.level_alloc_pending_stat;   // -1 = none
        var _has_pend   = (_pend_idx >= 0);

        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_title);
        draw_set_color(c_lime);
        draw_text(960, 90, "LEVEL UP  -  Level " + string(global.run_level));

        draw_set_font(fnt_ui);
        draw_set_color(c_yellow);
        var _pts_str;
        if (global.pending_stat_points == 1) {
            _pts_str = "1 point";
        } else {
            _pts_str = string(global.pending_stat_points) + " points";
        }
        if (_has_pend) {
            draw_text(960, 158, "Allocate " + _pts_str + "   (Enter: change choice   Space: confirm)");
        } else {
            draw_text_outline(960, 158, "Allocate " + _pts_str + "   (W/S: Navigate   Enter: choose stat)");
        }

        draw_set_halign(fa_left);

        var _alloc_stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        var _alloc_stat_descs = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"];
        var _alloc_stat_hints = [
            "Boosts physical ability dmg  *  Phys dmg reduction  *  Power crit +1.5% (x1.6 dmg)",
            "+3 accuracy  *  +2 dodge  *  Precision crit +2% (x1.35 dmg)",
            "+3 max HP per point",
            "Boosts elemental ability dmg  *  Arcane crit +1% (x1.25 dmg)",
            "Boosts DoT / status effect dmg  *  Effect crit +1.5% (extends statuses)",
            "Boosts ALL ability damage  *  +1% gold find/pt  *  cheaper NPC prices (1.5%/pt, max 30%)"
        ];

        // Layout: wider boxes with the hint wrapped INSIDE the box, and a uniform
        // box height derived from the tallest wrapped hint so no text ever spills
        // past the border. The value sits on the label row, top-right.
        var _bx_l    = 435;
        var _bx_r    = 1485;
        var _bx_padx = 33;
        var _hint_lh = 29;
        var _hint_w  = (_bx_r - _bx_l) - _bx_padx * 2;

        // Hint font drives both the measured box height and the drawn hints below.
        draw_set_font(fnt_ui_small);
        var _max_hint_h = 0;
        for (var _hi = 0; _hi < 6; _hi++) {
            _max_hint_h = max(_max_hint_h, string_height_ext(_alloc_stat_hints[_hi], _hint_lh, _hint_w));
        }
        var _bx_h     = 39 + _max_hint_h + 18;   // label row + wrapped hint + padding
        var _row_step = _bx_h + 15;
        var _alloc_y0 = 210;

        for (var _si = 0; _si < 6; _si++) {
            var _sy      = _alloc_y0 + _si * _row_step;
            var _is_sel  = (_si == _gc_alloc_draw.level_alloc_index);
            var _is_pend = (_si == _pend_idx);
            var _cur_val = variable_struct_get(player.stats, _alloc_stat_names[_si]);

            // Background
            var _bg_col;
            if (_is_pend)      _bg_col = make_color_rgb(48, 32, 8);
            else if (_is_sel)  _bg_col = make_color_rgb(30, 50, 90);
            else               _bg_col = make_color_rgb(18, 22, 38);
            draw_set_alpha((_is_sel || _is_pend) ? 1.0 : 0.6);
            draw_set_color(_bg_col);
            draw_rectangle(_bx_l, _sy, _bx_r, _sy + _bx_h, false);
            draw_set_alpha(1.0);

            // Border - amber for pending, blue for selected cursor, gray otherwise
            var _bd_col;
            if (_is_pend)      _bd_col = make_color_rgb(220, 145, 35);
            else if (_is_sel)  _bd_col = make_color_rgb(80, 140, 220);
            else               _bd_col = make_color_rgb(45, 55, 75);
            draw_set_color(_bd_col);
            draw_rectangle(_bx_l, _sy, _bx_r, _sy + _bx_h, true);

            // Stat label
            var _lbl_col;
            if (_is_pend)      _lbl_col = make_color_rgb(235, 165, 50);
            else if (_is_sel)  _lbl_col = c_white;
            else               _lbl_col = make_color_rgb(140, 150, 170);
            draw_set_font(fnt_ui);
            draw_set_color(_lbl_col);
            draw_text(_bx_l + _bx_padx, _sy + 9, _alloc_stat_descs[_si] + "  (" + _alloc_stat_names[_si] + ")");

            // Value - right-aligned on the label row; "X -> X+1" when pending
            draw_set_halign(fa_right);
            if (_is_pend) {
                draw_set_color(make_color_rgb(235, 165, 50));
                draw_text(_bx_r - _bx_padx, _sy + 9, string(_cur_val) + "  ->  " + string(_cur_val + 1));
            } else {
                draw_set_color(_lbl_col);
                draw_text(_bx_r - _bx_padx, _sy + 9, string(_cur_val));
            }
            draw_set_halign(fa_left);

            // Wrapped hint on the line(s) below the label
            var _hint_col = (_is_sel || _is_pend) ? make_color_rgb(170, 188, 215) : make_color_rgb(95, 105, 128);
            draw_set_font(fnt_ui_small);
            draw_set_color(_hint_col);
            draw_text_ext(_bx_l + _bx_padx, _sy + 42, _alloc_stat_hints[_si], _hint_lh, _hint_w);
        }

        var _alloc_footer_y = _alloc_y0 + 6 * _row_step + 12;
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        if (_has_pend) {
            draw_text_outline(960, _alloc_footer_y, "W/S: Navigate   Enter: Change selection   Space: Confirm");
        } else {
            draw_text_outline(960, _alloc_footer_y, "W/S: Navigate   Enter: Choose stat");
        }
        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);

        ui_draw_character_menu();
        exit;
    }
}


// -----------------------------------------------------------------------------
// 4. LOOT SCREEN OVERLAY - shown after combat when items dropped this room
// -----------------------------------------------------------------------------
if (show_loot_screen) {

    // Full-screen dark cover
    draw_set_alpha(0.92);
    draw_set_color(make_color_rgb(10, 12, 22));
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_yellow);
    draw_text(960, 90, "LOOT FOUND");

    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(160, 160, 180));
    draw_text(960, 173, "Items collected this room:");

    // Item rows
    var _count   = array_length(global.run_items_found);
    var _visible = min(8, _count);

    for (var _i = 0; _i < _visible; _i++) {
        var _idx = _i + loot_screen_scroll;
        if (_idx >= _count) break;
        var _item = global.run_items_found[_idx];
        var _iy   = 240 + _i * 98;

        // Row background
        draw_set_alpha(0.5);
        draw_set_color(make_color_rgb(20, 25, 45));
        draw_rectangle(360, _iy - 8, 1560, _iy + 75, false);
        draw_set_alpha(1.0);

        var _is_consumable = variable_struct_exists(_item, "item_category")
                             && _item.item_category == "consumable";

        if (_is_consumable) {
            ui_draw_consumable_icon(372, _iy, 66, _item);
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_set_halign(fa_left);
            draw_text(456, _iy + 8, _item.name);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(140, 200, 200));
            draw_text(456, _iy + 42, _item.description);
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(1530, _iy + 8, "[CONSUMABLE]");
        } else {
            var _rarity_col = item_rarity_color(_item.rarity);
            ui_draw_item_icon(372, _iy, 66, _item);
            draw_set_font(fnt_ui);
            draw_set_color(_rarity_col);
            draw_set_halign(fa_left);
            draw_text(456, _iy + 3, _item.name);
            // Class restriction tag after the name (gold = your class, red = locked).
            // Standardized with the loadout tooltip / Dorn shop so it shows everywhere.
            var _loot_cr = variable_struct_exists(_item, "class_req") ? _item.class_req : -1;
            if (_loot_cr != -1) {
                var _loot_cr_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                var _loot_my_cl    = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                draw_set_font(fnt_ui_small);
                draw_set_color((_loot_cr == _loot_my_cl) ? make_color_rgb(210, 175, 90) : make_color_rgb(225, 80, 80));
                draw_text(456 + string_width(_item.name) + 18, _iy + 9,
                    "[" + _loot_cr_names[clamp(_loot_cr, 0, 2)] + " only]");
                draw_set_font(fnt_ui);
            }
            // Stat line (e.g. "+4 STR, +12 HP") so found gear is readable at a glance.
            // Scale it down to ONE line within the left content area so a many-affix
            // item can't overrun the right-hand rarity/slot/req column.
            draw_set_font(fnt_ui_small);
            draw_set_color(c_white);
            draw_set_halign(fa_left);
            ui_draw_stat_line_fit(456, _iy + 33, ui_item_stat_str(_item), 1230 - 456);
            draw_set_color(make_color_rgb(160, 165, 185));
            draw_text(456, _iy + 60, _item.effect_desc);
            // Right column (right-aligned): rarity, slot, and stat requirement - kept
            // separate from the stat line so they never overlap. Requirement is red
            // when the current class can't meet it (equipping is hard-blocked).
            draw_set_halign(fa_right);
            draw_set_color(_rarity_col);
            draw_text(1530, _iy + 6, "[" + item_rarity_name(_item.rarity) + "]");
            draw_set_color(make_color_rgb(140, 140, 100));
            draw_text(1530, _iy + 33, "Slot: " + item_slot_label(_item.slot));
            var _lreq = item_stat_requirement(_item);
            if (_lreq.value > 0 && _lreq.stat != "") {
                draw_set_color((player_base_stat(_lreq.stat) >= _lreq.value)
                    ? make_color_rgb(110, 170, 110) : make_color_rgb(225, 80, 80));
                draw_text(1530, _iy + 58, "Req " + string(_lreq.value) + " " + _lreq.stat);
            }
        }
    }

    // Scroll hint (only when list overflows)
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    if (_count > 8) {
        draw_set_color(make_color_rgb(120, 130, 150));
        draw_text_outline(960, 953, "W/S to scroll");
    }

    draw_set_font(fnt_ui);
    draw_set_color(c_white);
    draw_text(960, 990, "Enter / R to continue");

    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    ui_draw_character_menu();
    exit;
}


// -----------------------------------------------------------------------------
// 4b. CONSUMABLE OVERFLOW PROMPT - pack-full pickups awaiting a discard choice.
// Only shown once the fight is won (no living enemies), matching the Step gate
// in the victory path - so it never interrupts an ongoing battle.
// -----------------------------------------------------------------------------
if (!combat_over && consumable_overflow_pending()
    && array_length(combat_living_enemies(combat_state)) == 0) {
    ui_draw_consumable_overflow();
    exit;
}


// -----------------------------------------------------------------------------
// 5. COMBAT RESULT OVERLAY
// Drawn on top of everything when combat is resolved.
// -----------------------------------------------------------------------------
if (combat_over) {

    // Stop battle music and start result music - fires exactly once
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Centre-screen text
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);

    var _cx = 960;
    var _cy = 480;

    draw_set_font(fnt_ui_title);
    if (combat_result == 1) {
        // Victory - drop shadow + main, drawn with the native title font
        draw_set_color(make_color_rgb(0, 60, 0));
        draw_text(_cx + 5, _cy + 5, "VICTORY");
        draw_set_color(c_green);
        draw_text(_cx, _cy, "VICTORY");

    } else if (combat_result == -1) {
        // Defeat
        draw_set_color(make_color_rgb(80, 0, 0));
        draw_text(_cx + 5, _cy + 5, "DEFEATED");
        draw_set_color(c_red);
        draw_text(_cx, _cy, "DEFEATED");
    }

    // Run summary
    draw_set_font(fnt_ui);
    draw_set_halign(fa_center);
    var _summary_y = _cy + 75;

    draw_set_color(c_yellow);
    var _gold_suffix = "";
    if (combat_result != 1) {
        _gold_suffix = "  |  Kept: " + string(floor(global.current_run_gold * 0.25)) + "g";
    }
    draw_text(_cx, _summary_y,
        "Gold earned: " + string(global.current_run_gold) + "g" + _gold_suffix);
    _summary_y += 42;

    draw_set_color(c_white);
    draw_text(_cx, _summary_y, "Enemies defeated: " + string(global.current_run_kills));
    _summary_y += 42;

    if (combat_result != 1) {
        draw_set_color(make_color_rgb(180, 150, 80));
        draw_text(_cx, _summary_y, "Salvaged: " + string(floor(global.current_run_gold * 0.25)) + "g kept");
        _summary_y += 42;
        if (variable_global_exists("last_run_mercy_item") && global.last_run_mercy_item != "") {
            draw_text(_cx, _summary_y, "Salvaged item: " + global.last_run_mercy_item);
            _summary_y += 42;
        }
    }

    draw_text(_cx, _summary_y, "Run " + string(global.run_count + 1));
    _summary_y += 54;

    // Continue / return prompt - hidden when extract popup is open
    if (!boss_extract_open) {
        draw_set_color(c_white);
        if (combat_result == 1) {
            draw_text(_cx, _summary_y, "Press R to continue");
        } else {
            draw_text_outline(_cx, _summary_y, "Press R to return to camp");
        }
    }

    // Reset alignment
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // -------------------------------------------------------------------------
    // 5a. BOSS EXTRACT POPUP - shown after defeating a floor boss (floor < 3)
    // Player chooses: E = extract to camp, Enter/Space = descend to next floor.
    // -------------------------------------------------------------------------
    if (boss_extract_open) {
        // Backdrop
        draw_set_alpha(0.88);
        draw_set_color(make_color_rgb(8, 10, 20));
        draw_rectangle(360, 360, 1560, 735, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(60, 80, 140));
        draw_rectangle(360, 360, 1560, 735, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_top);
        draw_set_font(fnt_ui_title);
        draw_set_color(c_white);
        draw_text(_cx, 396, "FLOOR " + string(global.current_floor) + " CLEARED");
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(160, 175, 210));
        draw_text(_cx, 459, "What will you do?");

        // Extract button
        draw_set_color(make_color_rgb(16, 36, 16));
        draw_rectangle(402, 510, 930, 623, false);
        draw_set_color(make_color_rgb(50, 160, 70));
        draw_rectangle(402, 510, 930, 623, true);
        draw_set_font(fnt_ui);
        draw_set_color(c_white);
        draw_text_outline(666, 533, "[ E ]  Extract to Camp");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(140, 210, 140));
        draw_text(666, 579, "Keep all rewards  *  Safe");

        // Continue button
        draw_set_color(make_color_rgb(30, 22, 10));
        draw_rectangle(990, 510, 1518, 623, false);
        draw_set_color(make_color_rgb(180, 130, 40));
        draw_rectangle(990, 510, 1518, 623, true);
        draw_set_font(fnt_ui);
        draw_set_color(c_white);
        draw_text(1254, 533, "[ Enter ]  Descend Deeper");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(220, 190, 120));
        draw_text(1254, 579, "Floor " + string(global.current_floor + 1) + "  *  Harder enemies");

        draw_set_color(make_color_rgb(70, 80, 110));
        draw_text_outline(_cx, 645, "E: Extract     Enter / Space: Continue to next floor");

        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // Mouse hover highlights
        var _bmx = device_mouse_x_to_gui(0);
        var _bmy = device_mouse_y_to_gui(0);
        var _hover_extract  = (_bmx >= 402 && _bmx < 930  && _bmy >= 510 && _bmy < 623);
        var _hover_continue = (_bmx >= 990 && _bmx < 1518 && _bmy >= 510 && _bmy < 623);
        if (_hover_extract) {
            draw_set_alpha(0.18);
            draw_set_color(c_white);
            draw_rectangle(402, 510, 930, 623, false);
            draw_set_alpha(1.0);
        }
        if (_hover_continue) {
            draw_set_alpha(0.18);
            draw_set_color(c_white);
            draw_rectangle(990, 510, 1518, 623, false);
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
                    // Full dungeon clear - end run as victory
                    global.just_cleared_boss = false;
                    global.floor_rooms_cleared = [];
                    audio_stop_sound(MusicBox1);
                    end_run(1);
                    room_goto(rm_hub);
                    exit;
                } else {
                    // Floor boss cleared - open extract choice popup, don't advance yet
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

// Combat owns fonts; shared menu/overlay draws below are still default-font
// (Phase 3) - make sure none of them inherit a combat font.
draw_set_font(-1);
ui_draw_stash_screen();
ui_draw_character_menu();

// Comparison panel - drawn above all overlays
if (instance_exists(obj_game_controller)) {
    var _gc_cmp2 = instance_find(obj_game_controller, 0);
    if (_gc_cmp2.comparison_open && _gc_cmp2.comparison_item != undefined) {
        ui_draw_comparison_panel(_gc_cmp2.comparison_item, _gc_cmp2.comparison_equipped);
    }
}

// Ability detail breakdown (V) - full-screen popup over the combat HUD, mirroring
// the Tab popup on the loadout / Vex screens. Close hint reads [V] since Tab is the
// target-cycle key in combat. Drawn under the pause menu so Esc->pause still wins
// if both somehow coexist (they don't - the Esc guard closes this first).
if (player_turn && !combat_over && ability_detail_open) {
    var _ad_idx = clamp(selected_ability, 0, array_length(player.abilities) - 1);
    ui_draw_ability_detail(player.abilities[_ad_idx], "V");
}

// Pause / Esc menu + its Settings sub-screen (combat doesn't otherwise host the
// settings overlay) - topmost.
if (variable_global_exists("settings_open") && global.settings_open) ui_draw_settings_overlay();
ui_draw_pause_menu();

// Onboarding coach-mark - drawn last so it sits on top of the combat scene.
ui_draw_tutorial_tip();
