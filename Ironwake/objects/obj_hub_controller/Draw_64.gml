// =============================================================================
// obj_hub_controller - Draw GUI event
// Draws the full hub screen at the native 1920x1080 GUI.
// Draw order:
//   1. Background
//   2. Title
//   3. Player info panel       (top-left)
//   4. Last run summary panel  (below player info, conditional)
//   5. NPC list                (center)
//   6. Selected NPC detail     (right)
//   7. Enter dungeon button    (bottom-right)
//   8. Bottom instructions     (footer)
// =============================================================================


// Skip all hub content while the loadout overlay is open so nothing bleeds through.
var _loadout_is_open = instance_exists(obj_game_controller)
    && instance_find(obj_game_controller, 0).loadout_open;

if (!_loadout_is_open) {

// -----------------------------------------------------------------------------
// 1. BACKGROUND - gradient base, camp art, drifting embers, vignette
// -----------------------------------------------------------------------------
// 1a. Vertical gradient: cool top -> warmer firelit bottom. The bottom warmth
//     "breathes" via a slow firelight pulse.
var _pulse  = 0.85 + 0.15 * sin(current_time / 650);
var _bg_top = make_color_rgb(13, 13, 20);
var _bg_bot = make_color_rgb(48 * _pulse, 33 * _pulse, 30 * _pulse);
draw_rectangle_color(GUI_XL, 0, GUI_XR, GUI_H, _bg_top, _bg_top, _bg_bot, _bg_bot, false);

// 1b. Camp scene art - cover-fit to the full GUI, dimmed so panels stay readable.
//     No-ops cleanly until spr_hub_background is imported (bg_sprite == -1).
if (bg_sprite != -1 && sprite_exists(bg_sprite)) {
    var _bw = sprite_get_width(bg_sprite);
    var _bh = sprite_get_height(bg_sprite);
    if (_bw > 0 && _bh > 0) {
        var _bsc = max((GUI_XR - GUI_XL) / _bw, GUI_H / _bh);   // uniform cover scale (8b: spans gutters)
        var _bdw = _bw * _bsc;
        var _bdh = _bh * _bsc;
        draw_sprite_ext(bg_sprite, 0, (GUI_W - _bdw) / 2, (GUI_H - _bdh) / 2,
            _bsc, _bsc, 0, c_white, 0.32);
    }
}

// 1b2. Firelight flicker - an additive warm wash over the LOWER camp that subtly
//      brightens/dims so the light feels alive. (The gradient pulse in 1a alone is
//      masked by the camp art, so the flicker wasn't visible.) Two layered sines at
//      different rates give an organic, non-repetitive flicker; kept subtle.
var _flick = 0.72 + 0.10 * sin(current_time / 360) + 0.07 * sin(current_time / 95);
_flick = clamp(_flick, 0.45, 1.0);
gpu_set_blendmode(bm_add);
var _glow_col = make_color_rgb(96 * _flick, 52 * _flick, 20 * _flick);   // warm firelight
draw_rectangle_color(GUI_XL, 600, GUI_XR, GUI_H, c_black, c_black, _glow_col, _glow_col, false);
gpu_set_blendmode(bm_normal);
draw_set_alpha(1.0);
draw_set_color(c_white);

// 1c. Drifting embers - updated and drawn here, behind every panel.
for (var _ei = 0; _ei < array_length(hub_embers); _ei++) {
    var _em = hub_embers[_ei];
    _em.y -= _em.spd;                                       // rise
    if (_em.y < -4) { _em.y = GUI_H + 4; _em.x = GUI_XL + irandom(GUI_XR - GUI_XL); } // wrap to bottom
    var _ex = _em.x + sin(current_time / 1000 + _em.phase) * _em.drift;
    var _ea = _em.a * (0.7 + 0.3 * sin(current_time / 700 + _em.phase));  // shimmer
    draw_set_color(make_color_rgb(255, 180, 90));
    draw_set_alpha(_ea);
    draw_rectangle(_ex, _em.y, _ex + _em.size, _em.y + _em.size, false);
}
draw_set_alpha(1.0);

// 1d. Vignette - soft dark edge bands fading inward so corners sink, center
//     reads. Drawn under the panels (depth only; never darkens UI text).
var _vg    = make_color_rgb(6, 6, 12);
var _vgmax = 0.55;
draw_primitive_begin(pr_trianglestrip);   // top
draw_vertex_color(GUI_XL, 0, _vg, _vgmax); draw_vertex_color(GUI_XR, 0, _vg, _vgmax);
draw_vertex_color(GUI_XL, 135, _vg, 0);    draw_vertex_color(GUI_XR, 135, _vg, 0);
draw_primitive_end();
draw_primitive_begin(pr_trianglestrip);   // bottom
draw_vertex_color(GUI_XL, GUI_H, _vg, _vgmax); draw_vertex_color(GUI_XR, GUI_H, _vg, _vgmax);
draw_vertex_color(GUI_XL, 945, _vg, 0);        draw_vertex_color(GUI_XR, 945, _vg, 0);
draw_primitive_end();
draw_primitive_begin(pr_trianglestrip);   // left
draw_vertex_color(GUI_XL, 0, _vg, _vgmax); draw_vertex_color(GUI_XL, GUI_H, _vg, _vgmax);
draw_vertex_color(180, 0, _vg, 0);         draw_vertex_color(180, GUI_H, _vg, 0);
draw_primitive_end();
draw_primitive_begin(pr_trianglestrip);   // right
draw_vertex_color(GUI_XR, 0, _vg, _vgmax); draw_vertex_color(GUI_XR, GUI_H, _vg, _vgmax);
draw_vertex_color(1740, 0, _vg, 0);        draw_vertex_color(1740, GUI_H, _vg, 0);
draw_primitive_end();
draw_set_alpha(1.0);
draw_set_color(c_white);


// -----------------------------------------------------------------------------
// 2. TITLE
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_set_font(fnt_ui_title);
// Drop shadow = fake-bold weight so it reads as a proper title (drawn at native
// size, no scaling). Raised to y18 for a clear header band above the panels (y105).
draw_set_color(make_color_rgb(16, 24, 42));
draw_text(GUI_CX + 3, 21, "THE IRONWAKE CAMP");
draw_set_color(c_white);
draw_text(GUI_CX, 18, "THE IRONWAKE CAMP");

// Rotating camp flavor line - lives in the open center-column band BELOW the NPC
// list (which ends at y945) and above the footer (y1073). WIDTH-CONSTRAINED to that
// column (x630-1290) so a long lore line wraps within it instead of stretching into
// the character panel (x<=540) or NPC detail (x>=1320).
//
// Drawn ~2x the old size: the readable Centaur UI font scaled up via
// draw_text_ext_transformed (Castellar title font is all-caps and unreadable for
// sentences). The message still AUTO-WRAPS (the messages vary in length), and the
// whole wrapped block is vertically fitted into the band [948..1070] so even the
// longest, three-line message clears the footer. A dark 8-way outline keeps it
// legible over the camp art.
draw_set_font(fnt_ui);
draw_set_halign(fa_center);
draw_set_valign(fa_top);
var _flav_scale = 1.275;                            // 22px Centaur -> ~28px (25% smaller than the 1.7x pass)
var _flav_w     = 700 / _flav_scale;                // ~700px on-screen wrap width (unscaled)
var _flav_sep   = 26;                               // line spacing scales with the text (~33px on-screen)
var _flav_h     = string_height_ext(hub_flavor, _flav_sep, _flav_w) * _flav_scale;
var _flav_y;
if (input_device() == 2) {
    // Touch (M 07-17): keep the lore FULL SIZE (not shrunk) - bottom-anchor it just
    // above the chip bar (top ~y1005) and let it grow UPWARD into the open band below
    // the NPC list. Only a rare very-long message shrinks, and only if it would climb
    // past y888 into the list.
    var _flav_bot = 1000, _flav_top_min = 888;
    if (_flav_h > _flav_bot - _flav_top_min) {
        _flav_scale *= (_flav_bot - _flav_top_min) / _flav_h;
        _flav_w      = 700 / _flav_scale;
        _flav_h      = string_height_ext(hub_flavor, _flav_sep, _flav_w) * _flav_scale;
    }
    _flav_y = _flav_bot - _flav_h;
} else {
    _flav_y = min(max(948, 1008 - _flav_h * 0.5), 1070 - _flav_h);
}
draw_set_color(make_color_rgb(12, 11, 9));
for (var _fox = -2; _fox <= 2; _fox += 2) {
    for (var _foy = -2; _foy <= 2; _foy += 2) {
        if (_fox == 0 && _foy == 0) continue;
        draw_text_ext_transformed(GUI_CX + _fox, _flav_y + _foy, hub_flavor, _flav_sep, _flav_w, _flav_scale, _flav_scale, 0);
    }
}
draw_set_color(make_color_rgb(208, 184, 152));
draw_text_ext_transformed(GUI_CX, _flav_y, hub_flavor, _flav_sep, _flav_w, _flav_scale, _flav_scale, 0);
draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);


// -----------------------------------------------------------------------------
// 3. PLAYER INFO PANEL - top-left (x=30, y=105, w=420, h=210)
// Height trimmed from 300: the 4 stat lines only reach ~y285, so the old box had
// dead space at the bottom that crowded the Last Run panel (y=420). Now ends at
// y315, leaving clear separation.
// -----------------------------------------------------------------------------
var _pi_x = 30;
var _pi_y = 105;
var _pi_w = 420;
var _pi_h = 210;

draw_set_alpha(0.4);
draw_set_color(c_black);
draw_rectangle(_pi_x + 6, _pi_y + 6, _pi_x + _pi_w + 6, _pi_y + _pi_h + 6, false);
draw_set_alpha(0.85);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + _pi_h, false);
draw_set_alpha(1.0);
// Gothic frame FIRST so the blue border below stays on top (the frame's edge art
// would otherwise paint over the left border â€” same fix as the NPC detail panel).
ui_draw_gothic_frame(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + _pi_h);
draw_set_color(make_color_rgb(60, 90, 160));
draw_rectangle(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + _pi_h, true);
draw_rectangle(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + 4, false);   // accent strip

var _px     = _pi_x + 21;
var _py     = _pi_y + 21;
var _line_h = 42;

var _display_gold       = variable_global_exists("gold")         ? global.gold         : 0;
var _display_runs       = variable_global_exists("run_count")    ? global.run_count    : 0;
var _display_best_floor = variable_global_exists("best_floor")   ? global.best_floor   : 0;
var _display_kills      = variable_global_exists("total_kills")  ? global.total_kills  : 0;

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(fnt_ui);
// Gold reads in an antique-gold tint to match the coin economy; the rest stay white.
draw_set_color(make_color_rgb(228, 190, 90));
draw_text(_px, _py,               "Gold:       " + string(_display_gold));
draw_set_color(c_white);
draw_text(_px, _py + _line_h,     "Runs:       " + string(_display_runs));
draw_text(_px, _py + _line_h * 2, "Best Floor: " + string(_display_best_floor));
draw_text(_px, _py + _line_h * 3, "Kills:      " + string(_display_kills));
draw_set_font(-1);


// -----------------------------------------------------------------------------
// 4. LAST RUN SUMMARY PANEL - x=30, y=420, w=420, h=222 (conditional)
// -----------------------------------------------------------------------------
if (show_last_run) {
    var _lr_x = 30;
    var _lr_y = 420;
    var _lr_w = 420;
    var _lr_h = 222;

    draw_set_alpha(0.4);
    draw_set_color(c_black);
    draw_rectangle(_lr_x + 6, _lr_y + 6, _lr_x + _lr_w + 6, _lr_y + _lr_h + 6, false);
    draw_set_alpha(0.85);
    draw_set_color(make_color_rgb(20, 25, 45));
    draw_rectangle(_lr_x, _lr_y, _lr_x + _lr_w, _lr_y + _lr_h, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(60, 90, 160));
    draw_rectangle(_lr_x, _lr_y, _lr_x + _lr_w, _lr_y + _lr_h, true);
    draw_rectangle(_lr_x, _lr_y, _lr_x + _lr_w, _lr_y + 4, false);   // accent strip

    var _lx = _lr_x + 21;
    var _ly = _lr_y + 18;

    // Result header
    draw_set_font(fnt_ui);
    if (global.last_run_result == 1) {
        draw_set_color(c_lime);
        draw_text(_lx, _ly, "LAST RUN: VICTORY");
    } else {
        draw_set_color(c_red);
        draw_text(_lx, _ly, "LAST RUN: DEFEAT");
    }

    // Gold and kills
    draw_set_color(c_white);
    draw_text(_lx, _ly + 39, "Gold earned: " + string(global.last_run_gold));
    draw_text(_lx, _ly + 78, "Kills:       " + string(global.last_run_kills));

    // Permanent points earned (only shown on full-clear victory). Drawn at the
    // smaller UI font so the all-caps gold line fits inside the 420px panel
    // instead of spilling past the right border.
    if (variable_global_exists("last_run_perm_points") && global.last_run_perm_points > 0) {
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(255, 210, 60));
        draw_text(_lx, _ly + 120, "PERMANENT POINTS EARNED: " + string(global.last_run_perm_points));
        // Dismiss hint shifts down
        draw_set_color(c_gray);
        draw_text_outline(_lx, _ly + 156, "Esc to dismiss");
    } else {
        // Dismiss hint
        draw_set_font(fnt_ui_small);
        draw_set_color(c_gray);
        draw_text_outline(_lx, _ly + 123, "Esc to dismiss");
    }
    draw_set_font(-1);
}


// -----------------------------------------------------------------------------
// 4b. CHARACTER PANEL - bottom-left (x=30, y=660, w=510, h=366)
// Shows the player's class sprite, name, class, and total stats. Bigger portrait +
// ornate border, stats spread into the right-side space (was a lot of dead space
// beside the portrait). Right edge x540 clears the NPC list at x630; bottom y1026
// clears the controls hint at y1073.
// -----------------------------------------------------------------------------
var _cp_x = 30;
var _cp_y = 660;
var _cp_w = 510;
var _cp_h = 366;

draw_set_alpha(0.4);
draw_set_color(c_black);
draw_rectangle(_cp_x + 6, _cp_y + 6, _cp_x + _cp_w + 6, _cp_y + _cp_h + 6, false);
draw_set_alpha(0.85);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_cp_x, _cp_y, _cp_x + _cp_w, _cp_y + _cp_h, false);
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(60, 90, 160));
draw_rectangle(_cp_x, _cp_y, _cp_x + _cp_w, _cp_y + _cp_h, true);
draw_rectangle(_cp_x, _cp_y, _cp_x + _cp_w, _cp_y + 4, false);   // accent strip

var _cls_id   = variable_global_exists("chosen_class") ? global.chosen_class : 0;
var _cls_pre  = global.class_presets[_cls_id];

var _base = (variable_global_exists("chosen_stats") && !is_undefined(global.chosen_stats))
            ? global.chosen_stats : _cls_pre;

// Build a stat view the same way scr_ui does: base + equipment + run level + perm bonuses
var _sv = {
    STR: _base.STR, DEX: _base.DEX, CON: _base.CON,
    INT: _base.INT, WIS: _base.WIS, CHA: _base.CHA,
};
var _eq_bonus = apply_equipment_stats(_sv);
if (variable_global_exists("run_stat_bonuses")) {
    _sv.STR += global.run_stat_bonuses.STR;
    _sv.DEX += global.run_stat_bonuses.DEX;
    _sv.CON += global.run_stat_bonuses.CON;
    _sv.INT += global.run_stat_bonuses.INT;
    _sv.WIS += global.run_stat_bonuses.WIS;
    _sv.CHA += global.run_stat_bonuses.CHA;
}
if (variable_global_exists("perm_str_bonus")) {
    _sv.STR += global.perm_str_bonus;
    _sv.DEX += global.perm_dex_bonus;
    _sv.CON += global.perm_con_bonus;
    _sv.INT += global.perm_int_bonus;
    _sv.WIS += global.perm_wis_bonus;
    _sv.CHA += global.perm_cha_bonus;
}
var _cs_STR = _sv.STR;
var _cs_DEX = _sv.DEX;
var _cs_CON = _sv.CON;
var _cs_INT = _sv.INT;
var _cs_WIS = _sv.WIS;
var _cs_CHA = _sv.CHA;
var _derived = stats_derive(_sv);
var _cs_HP   = _derived.HP + _eq_bonus.bonus_max_hp
             + (variable_global_exists("perm_hp_battle_hardened") ? global.perm_hp_battle_hardened : 0);

var _cpx = _cp_x + 21;
var _cpy = _cp_y + 18;

// Name and class header
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(fnt_ui);
draw_set_color(c_white);
draw_text(_cpx, _cpy, global.player_name);
draw_set_font(fnt_ui_small);
draw_set_color(make_color_rgb(100, 160, 220));
draw_text(_cpx, _cpy + 36, _cls_pre.name);

// Divider under header (full panel width)
draw_set_color(make_color_rgb(40, 60, 100));
draw_line(_cp_x + 12, _cp_y + 81, _cp_x + _cp_w - 12, _cp_y + 81);

// Portrait - left side, 240x240. Band 15 surrounds OUTWARD; with the portrait at
// (+21,+102) the band clears the divider (top, y81), the panel border (left), the
// stat column (right) and the panel bottom.
var _port_idx = variable_global_exists("chosen_portrait") ? global.chosen_portrait : 0;
_port_idx = clamp(_port_idx, 0, array_length(global.portrait_sprites) - 1);
var _pt_x = _cp_x + 21;
var _pt_y = _cp_y + 102;
var _pt_w = 240;
var _pt_h = 240;
ui_draw_sprite_cover(global.portrait_sprites[_port_idx], 0, _pt_x, _pt_y, _pt_w, _pt_h, 1.0);
ui_draw_gothic_frame(_pt_x, _pt_y, _pt_x + _pt_w, _pt_y + _pt_h, 15);   // ornate portrait frame

// Stats - right of the portrait, spread to fill the panel: muted label on the left,
// bright value right-aligned near the panel edge (fills what used to be dead space).
var _st_lx = _pt_x + _pt_w + 33;   // label x
var _st_vx = _cp_x + _cp_w - 27;   // value x (right-aligned)
var _st_y  = _cp_y + 108;
var _slh   = 33;
var _stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
var _stat_vals  = [_cs_STR, _cs_DEX, _cs_CON, _cs_INT, _cs_WIS, _cs_CHA];
draw_set_font(fnt_ui);
for (var _si = 0; _si < 6; _si++) {
    var _sy = _st_y + _si * _slh;
    draw_set_halign(fa_left);
    draw_set_color(make_color_rgb(150, 165, 200));
    draw_text(_st_lx, _sy, _stat_names[_si]);
    draw_set_halign(fa_right);
    draw_set_color(c_white);
    draw_text(_st_vx, _sy, string(_stat_vals[_si]));
}
// HP on its own line, accented green
var _hp_y = _st_y + 6 * _slh;
draw_set_halign(fa_left);
draw_set_color(make_color_rgb(80, 210, 100));
draw_text(_st_lx, _hp_y, "HP");
draw_set_halign(fa_right);
draw_text(_st_vx, _hp_y, string(_cs_HP));
draw_set_halign(fa_left);
draw_set_font(-1);


// -----------------------------------------------------------------------------
// 5. NPC LIST - center (x=630, y=105, w=660, h=840)
// Each row is 81px tall with a 15px gap between rows.
// -----------------------------------------------------------------------------
var _nl_x      = 630;
var _nl_y      = 105;
var _row_h     = 81;
var _row_gap   = 15;
var _row_w     = 660;

for (var _i = 0; _i < array_length(npc_names); _i++) {
    var _ry      = _nl_y + _i * (_row_h + _row_gap);
    var _is_sel  = (_i == selected_npc);
    var _is_lock = !npc_unlocked[_i];

    // Row fill - lighter for selected
    if (_is_sel) {
        draw_set_alpha(0.9);
        draw_set_color(make_color_rgb(30, 50, 80));
    } else {
        draw_set_alpha(0.7);
        draw_set_color(make_color_rgb(20, 25, 40));
    }
    draw_rectangle(_nl_x, _ry, _nl_x + _row_w, _ry + _row_h, false);

    // Border - bright teal for selected, dark gray otherwise
    draw_set_alpha(1.0);
    if (_is_sel) {
        draw_set_color(make_color_rgb(80, 160, 220));
    } else {
        draw_set_color(make_color_rgb(45, 55, 75));
    }
    draw_rectangle(_nl_x, _ry, _nl_x + _row_w, _ry + _row_h, true);
    if (_is_sel) ui_draw_gothic_frame(_nl_x, _ry, _nl_x + _row_w, _ry + _row_h, 10);   // ornate selection frame

    // NPC name - gray and suffixed "[Locked]" when locked
    var _name_str = npc_names[_i];
    if (_is_lock) {
        _name_str += "  [Locked]";
        draw_set_color(c_gray);
    } else {
        draw_set_color(c_white);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui);
    draw_text(_nl_x + 21, _ry + 27, _name_str);
}
draw_set_font(-1);

draw_set_valign(fa_top);


// -----------------------------------------------------------------------------
// 6. SELECTED NPC DETAIL PANEL - right (x=1320, y=105, w=570, h=225)
// -----------------------------------------------------------------------------
if (selected_npc < array_length(npc_names)) {
var _dp_x = 1320;
var _dp_y = 105;
var _dp_w = 570;
var _dp_h = 225;

draw_set_alpha(0.4);
draw_set_color(c_black);
draw_rectangle(_dp_x + 6, _dp_y + 6, _dp_x + _dp_w + 6, _dp_y + _dp_h + 6, false);
draw_set_alpha(0.9);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, false);
draw_set_alpha(1.0);
// Gothic frame FIRST, then the blue border on top â€” otherwise the frame's left-edge
// art paints over the 1px blue border and it vanishes on that side only.
ui_draw_gothic_frame(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, 30);   // ornate NPC detail frame
draw_set_color(make_color_rgb(80, 160, 220));
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, true);       // blue panel border (all 4 sides)
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + 4, false);          // accent strip

var _ddx = _dp_x + 24;
var _ddy = _dp_y + 18;

// NPC name - fake bold (shadow + main)
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(fnt_ui);
draw_set_color(make_color_rgb(40, 60, 90));
draw_text(_ddx + 2, _ddy + 2, npc_names[selected_npc]);
draw_set_color(c_white);
draw_text(_ddx, _ddy, npc_names[selected_npc]);

// Brief description
draw_set_font(fnt_ui_small);
draw_set_color(make_color_rgb(180, 190, 210));
draw_text_ext(_ddx, _ddy + 42, npc_descriptions[selected_npc], 27, 510);

// --- Affinity (thin track): tier + progress toward next gate. The raw score is
// intentionally never shown (diegetic). Only the 6 affinity-scored NPCs (0..5) have a
// bond; Bairc (index 6) is not affinity-wired until a later Phase-2 slice, so guard the
// index to avoid reading past affinity_npc_ids().
var _aff_ids = affinity_npc_ids();
if (selected_npc < array_length(_aff_ids)) {
    var _aff_id   = _aff_ids[selected_npc];
    var _aff_tier = affinity_tier(_aff_id);
    var _aff_rdy  = affinity_gate_ready(_aff_id);
    draw_set_color(make_color_rgb(210, 190, 130));
    draw_text(_ddx, _ddy + 100, "Bond: " + affinity_tier_name(_aff_id));
    if (_aff_rdy) {
        draw_set_color(c_aqua);
        draw_text(_ddx + 200, _ddy + 100, (input_device() == 1) ? "[R3] Deepen bond" : "[B] Deepen bond");
    } else if (_aff_tier < 4) {
        // thin progress bar toward the next gate
        var _bx = _ddx, _by = _ddy + 124, _bw = 320, _bh = 8;
        draw_set_color(make_color_rgb(40, 44, 56));
        draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, false);
        draw_set_color(make_color_rgb(210, 190, 130));
        draw_rectangle(_bx, _by, _bx + _bw * affinity_progress_frac(_aff_id), _by + _bh, false);
        draw_set_color(make_color_rgb(90, 96, 110));
        draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, true);
    }
}

// Board affordance (Phase 4b): the Tavern Requests row flags turn-in-ready jobs.
if (selected_npc == 7) {
    var _dq_rows = journal_quest_rows();
    var _dq_ready = 0;
    for (var _dqi = 0; _dqi < array_length(_dq_rows); _dqi++)
        if (quest_is_complete(_dq_rows[_dqi])) _dq_ready++;
    if (_dq_ready > 0) {
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(120, 220, 140));
        draw_text(_dp_x + _dp_w - 24, _ddy + 138, string(_dq_ready) + " ready to turn in");
        draw_set_halign(fa_left);
    }
}

// Interaction hint or unlock condition
if (npc_unlocked[selected_npc]) {
    draw_set_color(c_lime);
    draw_text(_ddx, _ddy + 138, (input_device() == 2) ? "Tap to interact" : "Press Space to interact");
} else {
    var _hint = "";
    switch (selected_npc) {
        case 1: _hint = "Unlock after first dungeon clear";  break;
        case 2: _hint = "Unlock after 3 dungeon clears";     break;
        case 3: _hint = "Unlock after 10 dungeon clears";    break;
        case 5: _hint = "Unlock after 5 dungeon clears";     break;
        default: _hint = "Not yet available";
    }
    draw_set_color(c_gray);
    draw_text(_ddx, _ddy + 138, _hint);
}

// Notification message. M 07-16: WRAP inside the panel - long pet/egg notices
// (e.g. "A dark egg festers where the altar stood - visit Bairc.") ran off-screen.
// Small font + 20px sep so two wrapped lines still end above the panel bottom
// (first line y294, panel bottom y330; measured, not eyeballed).
if (notification != "") {
    draw_set_font(fnt_ui_small);
    draw_set_color(c_yellow);
    var _nw = _dp_x + _dp_w - 24 - _ddx;
    var _ntext = notification;
    // Clamp to the 2-line budget (2 * 20px sep). `notification` is fed by ~20
    // concatenating event sources (pet finds, bonds, board completes/expiries),
    // so a busy run stacked 3-4 messages that spilled over the panel border and
    // the portrait - M 07-20 ("request completed text spills over majorly").
    // The full text always survives in the Journal; here we just trim to fit,
    // backing up to a word boundary. "..." not "…" (font-safe, en-dash lesson).
    if (string_height_ext(_ntext, 20, _nw) > 40) {
        var _cut = string_length(_ntext);
        while (_cut > 1 && string_height_ext(string_copy(_ntext, 1, _cut) + "...", 20, _nw) > 40) _cut -= 4;
        var _clip = string_copy(_ntext, 1, max(1, _cut));
        var _sp = string_last_pos(" ", _clip);
        if (_sp > 0) _clip = string_copy(_clip, 1, _sp - 1);
        _ntext = _clip + "...";
    }
    draw_text_ext(_ddx, _ddy + 169, _ntext, 20, _nw);
    draw_set_font(fnt_ui);
}
draw_set_font(-1);
} // end selected_npc < 6


// -----------------------------------------------------------------------------
// 6b. NPC PORTRAIT PANEL - x=1320, y=378, w=570, h=480
// Lowered from y342/h516 so the detail panel's outward gothic band (30px below its
// y330 bottom -> y360) clears the portrait top; still ends at y858, leaving the 12px
// gap above the Enter Dungeon button at y870.
// -----------------------------------------------------------------------------
// Update animation state
if (portrait_prev_npc != selected_npc) {
    portrait_prev_npc   = selected_npc;
    portrait_slide_y    = -30.0;
    portrait_fade_alpha = 0.0;
}
portrait_slide_y    = lerp(portrait_slide_y, 0.0, 0.22);
portrait_fade_alpha = min(1.0, portrait_fade_alpha + 0.09);
if (abs(portrait_slide_y) < 0.5) portrait_slide_y = 0;

var _pp_x = 1320;
var _pp_y = 378;
var _pp_w = 570;
var _pp_h = 480;

// Dark portrait background
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(12, 14, 24));
draw_rectangle(_pp_x, _pp_y, _pp_x + _pp_w, _pp_y + _pp_h, false);

// NPC index -> sprite
var _port_sprites = [
    Blacksmith_1__Dark_Gritty_,
    Alcehmist_2__Flirty_,
    Runesmith_3__Facewrap_,
    Trainer_2__Sullen_,
    Merchant_7__Voluptuous_,
    Aesthete_2__Gothic_
];

// NPC slots: cover-cropped portrait with fade-in. Enter Dungeon slot: preview the
// currently chosen dungeon (was blank before).
if (selected_npc < array_length(_port_sprites)) {
    ui_draw_sprite_cover(_port_sprites[selected_npc], 0, _pp_x, _pp_y, _pp_w, _pp_h, portrait_fade_alpha);
} else if (selected_npc == 6) {
    // NPC beyond the authored portrait set (Bairc): use his hub sprite if imported,
    // else a captioned placeholder so the panel never falls through to the gate art.
    var _np_spr = asset_get_index("spr_npc_bairc_portrait");   // M-supplied profile art
    if (_np_spr < 0) _np_spr = asset_get_index("spr_npc_bairc_idle");
    if (_np_spr >= 0) {
        // v_anchor 0: his portrait is full-bleed 512px - a centered cover-crop in this
        // wider box scalped the top of his head, so the crop bites the bottom instead.
        ui_draw_sprite_cover(_np_spr, 0, _pp_x, _pp_y, _pp_w, _pp_h, portrait_fade_alpha, 0);
    } else {
        draw_set_halign(fa_center); draw_set_valign(fa_middle);
        draw_set_font(fnt_ui_title); draw_set_color(make_color_rgb(120, 130, 160));
        draw_text(_pp_x + _pp_w / 2, _pp_y + _pp_h / 2, npc_names[selected_npc]);
        draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_font(-1);
    }
} else if (selected_npc < array_length(npc_names)) {
    // TAVERN REQUESTS row (Phase 4b): the panel becomes the tavern's posting board.
    // Uses spr_tavern_board art once imported; until then a drawn board placeholder.
    var _tb_spr = asset_get_index("spr_tavern_board");
    if (_tb_spr >= 0) {
        ui_draw_sprite_cover(_tb_spr, 0, _pp_x, _pp_y, _pp_w, _pp_h, portrait_fade_alpha);
    } else {
        // Wooden board + pinned notes placeholder.
        draw_set_alpha(portrait_fade_alpha);
        draw_set_color(make_color_rgb(52, 36, 24));
        draw_rectangle(_pp_x, _pp_y, _pp_x + _pp_w, _pp_y + _pp_h, false);
        draw_set_color(make_color_rgb(30, 20, 13));
        draw_rectangle(_pp_x + 18, _pp_y + 18, _pp_x + _pp_w - 18, _pp_y + _pp_h - 18, true);
        for (var _tn = 0; _tn < 5; _tn++) {
            var _nx = _pp_x + 48 + (_tn mod 3) * 176 + ((_tn div 3) * 40);
            var _ny = _pp_y + 66 + (_tn div 3) * 190 + ((_tn mod 3) * 14);
            draw_set_color(make_color_rgb(206, 188, 150));
            draw_rectangle(_nx, _ny, _nx + 128, _ny + 150, false);
            draw_set_color(make_color_rgb(120, 100, 70));
            for (var _tl = 0; _tl < 5; _tl++) draw_line(_nx + 14, _ny + 30 + _tl * 24, _nx + 114, _ny + 30 + _tl * 24);
            draw_set_color(make_color_rgb(180, 60, 50));
            draw_circle(_nx + 64, _ny + 10, 5, false);
        }
        draw_set_halign(fa_center); draw_set_valign(fa_middle);
        draw_set_font(fnt_ui_title); draw_set_color(make_color_rgb(226, 205, 160));
        draw_text(_pp_x + _pp_w / 2, _pp_y + _pp_h - 45, "Tavern Requests");
        draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_font(-1);
        draw_set_alpha(1.0);
    }
} else {
    // Enter Dungeon preview - the chest+monster "gate" art (now imported).
    var _prev_spr   = spr_dungeon_gate;
    var _prev_title = "Enter the Dungeon";

    // Art fills the box above a caption band
    ui_draw_sprite_cover(_prev_spr, 0, _pp_x, _pp_y, _pp_w, _pp_h - 96, 1.0);
    draw_set_alpha(0.85);
    draw_set_color(make_color_rgb(10, 12, 22));
    draw_rectangle(_pp_x, _pp_y + _pp_h - 96, _pp_x + _pp_w, _pp_y + _pp_h, false);
    draw_set_alpha(1.0);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui);
    draw_set_color(c_white);
    draw_text(_pp_x + _pp_w / 2, _pp_y + _pp_h - 81, _prev_title);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(120, 200, 170));
    draw_text(_pp_x + _pp_w / 2, _pp_y + _pp_h - 39, (input_device() == 2) ? "Tap to choose dungeon & loadout" : "Press Enter to choose dungeon & loadout");
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// Portrait frame border
draw_set_color(make_color_rgb(80, 160, 220));
draw_rectangle(_pp_x, _pp_y, _pp_x + _pp_w, _pp_y + _pp_h, true);


// -----------------------------------------------------------------------------
// 7. ENTER DUNGEON BUTTON - bottom-right (x=1320, y=870, w=570, h=120)
// -----------------------------------------------------------------------------
var _eb_x = 1320;
var _eb_y = 870;
var _eb_w = 570;
var _eb_h = 120;

var _eb_sel = (selected_npc == array_length(npc_names));

draw_set_alpha(1.0);
draw_set_color(_eb_sel ? make_color_rgb(25, 160, 130) : make_color_rgb(20, 120, 100));
draw_rectangle(_eb_x, _eb_y, _eb_x + _eb_w, _eb_y + _eb_h, false);
draw_set_color(_eb_sel ? make_color_rgb(60, 230, 190) : make_color_rgb(30, 180, 150));
draw_rectangle(_eb_x, _eb_y, _eb_x + _eb_w, _eb_y + _eb_h, true);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_font(fnt_ui_title);
draw_set_color(c_white);
draw_text(_eb_x + _eb_w / 2, _eb_y + 42, "ENTER DUNGEON");

draw_set_valign(fa_top);
draw_set_font(fnt_ui_small);
if (_eb_sel) {
    draw_set_color(c_white);
    draw_text(_eb_x + _eb_w / 2, _eb_y + 78, (input_device() == 2) ? "Tap to confirm" : "Press Enter or Space to confirm");
} else {
    draw_set_color(make_color_rgb(100, 140, 130));
    draw_text(_eb_x + _eb_w / 2, _eb_y + 78, "Scroll down to select");
}
draw_set_font(-1);


// -----------------------------------------------------------------------------
// 8. FOOTER INSTRUCTIONS - y=1073
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_font(fnt_ui_small);
draw_set_color(c_gray);
// Chunk 7b: on a gamepad the footer shows the pad chips instead (same layout;
// see __input_pad_hotkey_map in scr_input for the M-approved assignments).
// Chunk 8d: on TOUCH the footer is replaced by the tappable action-chip bar
// (ui_draw_touch_chips, drawn at the end of this event) - no text here.
if (input_device() != 2) {
    var _hub_pad_ui = (input_device() == 1);
    var _foot_txt = _hub_pad_ui
        ? "D-Pad: Navigate   A: Interact   LT: Journal (Quests / Codex / Bestiary)   Y: History   RT: Stash   L3: Upgrade   Select: Settings"
        : "W/S: Navigate   Enter / Space: Interact   J: Journal (Quests / Codex / Bestiary)   H: History   T: Stash   P: Upgrade   O: Settings";
    draw_text_outline(GUI_CX, 1073, _foot_txt);
    // Unread-Journal cue: overdraw the "J: Journal" segment in flashing gold (M 2026-07-04:
    // the old floating pulse dot read as disjoint clutter). Alpha pulse over the same
    // pixels; same font/valign as the footer so it registers exactly.
    if (journal_any_badge()) {
        var _jseg_pre = _hub_pad_ui ? "D-Pad: Navigate   A: Interact   "
                                    : "W/S: Navigate   Enter / Space: Interact   ";
        var _jseg     = _hub_pad_ui ? "LT: Journal" : "J: Journal";
        var _jb_x = GUI_CX - string_width(_foot_txt) / 2 + string_width(_jseg_pre);
        draw_set_halign(fa_left);
        draw_set_alpha(0.55 + 0.45 * sin(current_time / 300));
        draw_set_color(make_color_rgb(245, 195, 80));
        draw_text_outline(_jb_x, 1073, _jseg);
        draw_set_alpha(1.0);
        draw_set_halign(fa_center);
    }
}

// Reset draw state - font back to default so the not-yet-rescaled overlays below
// (dungeon-select / history / perm-alloc / codex / loadout) keep their look.
draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);

} // end !_loadout_is_open

// -----------------------------------------------------------------------------
// 8b. DUNGEON SELECTION OVERLAY - full-screen, drawn after hub content
// -----------------------------------------------------------------------------
var _gc_ds = instance_exists(obj_game_controller) ? instance_find(obj_game_controller, 0) : noone;
if (_gc_ds != noone && _gc_ds.dungeon_select_open) {

    var _dungeons  = ["ashen_vault", "scorched_depths", "tundra_tomb"];
    var _dung_names = ["Ashen Vault", "Scorched Depths", "Tundra Tomb"];
    var _dung_art  = [spr_dungeon_ashen_vault, spr_dungeon_scorched_depths, spr_dungeon_tundra_tomb];
    var _dung_desc  = [
        "Ancient catacombs filled with undead soldiers and stone constructs. The original vault of the Ironwake.",
        "Volcanic caverns beneath the earth. Fire-wreathed enemies, intense heat, and burning dungeon passives.",
        "Frozen tombs of a lost civilization. Ice-bound horrors and cold air that slows your reflexes."
    ];
    var _dung_color = [
        make_color_rgb(160, 120, 60),
        make_color_rgb(200, 80,  30),
        make_color_rgb(80,  160, 220),
    ];
    var _asc_labels = ["Awakening A0 - Normal", "Awakening A1 - Hardened", "Awakening A2 - Brutal", "Awakening A3 - Relentless", "Awakening A4 - Nightmare", "Awakening A5 - Infernal"];
    // Tier one-liner under the selector is DATA-DRIVEN from the same awaken_*
    // helpers combat uses (the old hand-written percentages had drifted badly);
    // the full breakdown lives in the AWAKENING EFFECTS panel on the right.

    // Dark cover
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(8, 8, 18));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_white);
    draw_text(GUI_CX, 42, "SELECT DUNGEON");

    // Carousel layout - selected dungeon centered large, flanking two smaller and faded.
    // Lerp the visual position each frame so switching feels smooth.
    if (!variable_struct_exists(_gc_ds, "carousel_lerp")) _gc_ds.carousel_lerp = _gc_ds.dungeon_select_cursor;
    _gc_ds.carousel_lerp = lerp(_gc_ds.carousel_lerp, _gc_ds.dungeon_select_cursor, 0.16);

    var _cursor   = _gc_ds.dungeon_select_cursor;
    var _left_i   = (_cursor - 1 + 3) mod 3;
    var _right_i  = (_cursor + 1) mod 3;

    // Side arrows - drawn triangles instead of "<" ">" text (M 07-08: the glyphs
    // read as placeholder), and the LEFT one sits just left of the selected card
    // (x 528) mirroring the right (x 1392) - it used to float at the screen edge.
    var _car_ly = GUI_CY + 12;
    draw_set_color(make_color_rgb(26, 30, 46));
    draw_triangle(549 + 3, _car_ly - 33 + 3, 549 + 3, _car_ly + 33 + 3, 501 + 3, _car_ly + 3, false);
    draw_triangle(1371 - 3, _car_ly - 33 + 3, 1371 - 3, _car_ly + 33 + 3, 1419 + 3, _car_ly + 3, false);
    draw_set_color(make_color_rgb(150, 165, 200));
    draw_triangle(549, _car_ly - 33, 549, _car_ly + 33, 501, _car_ly, false);
    draw_triangle(1371, _car_ly - 33, 1371, _car_ly + 33, 1419, _car_ly, false);
    draw_set_color(make_color_rgb(70, 80, 110));
    draw_triangle(549, _car_ly - 33, 549, _car_ly + 33, 501, _car_ly, true);
    draw_triangle(1371, _car_ly - 33, 1371, _car_ly + 33, 1419, _car_ly, true);

    // Draw order: left preview first so the center card renders on top. The RIGHT
    // flank no longer shows a preview card - it hosts the AWAKENING EFFECTS panel
    // (drawn after this loop) instead.
    var _draw_order = [_left_i, _cursor];

    for (var _doi = 0; _doi < array_length(_draw_order); _doi++) {
        var _di  = _draw_order[_doi];
        var _dkey = _dungeons[_di];
        var _dcol = _dung_color[_di];
        var _unlocked_asc = variable_global_exists("dungeon_ascendance_unlocked")
            ? variable_struct_get(global.dungeon_ascendance_unlocked, _dkey) : 0;

        var _is_center = (_di == _cursor);
        var _is_left   = (_di == _left_i && !_is_center);

        // Card geometry
        var _cx, _cy, _cw, _ch, _alpha, _name_font;
        if (_is_center) {
            _cw = 720; _ch = 765;
            _cx = GUI_CX - _cw / 2;
            _cy = 123;
            _alpha = 1.0;
            _name_font = fnt_ui_title;
        } else if (_is_left) {
            _cw = 429; _ch = 570;
            _cx = 27;
            _cy = 225;
            _alpha = 0.45;
            _name_font = fnt_ui;
        } else {
            _cw = 429; _ch = 570;
            _cx = GUI_W - 27 - _cw;
            _cy = 225;
            _alpha = 0.45;
            _name_font = fnt_ui;
        }

        // Background
        draw_set_alpha(_alpha);
        draw_set_color(_is_center ? make_color_rgb(18, 22, 40) : make_color_rgb(12, 14, 24));
        draw_rectangle(_cx, _cy, _cx + _cw, _cy + _ch, false);

        // Color accent strip at top
        draw_set_color(_dcol);
        draw_rectangle(_cx, _cy, _cx + _cw, _cy + 6, false);

        // Border
        draw_set_color(_is_center ? _dcol : make_color_rgb(38, 44, 68));
        draw_rectangle(_cx, _cy, _cx + _cw, _cy + _ch, true);

        // Name
        draw_set_halign(fa_center);
        draw_set_font(_name_font);
        draw_set_color(_is_center ? _dcol : make_color_rgb(80, 88, 110));
        draw_text(_cx + _cw / 2, _cy + 21, _dung_names[_di]);

        // Dungeon art image - preserve the sprite's aspect ratio (square source),
        // fit it inside the banner slot, and center it. Uniform scale prevents the
        // wide/squashed stretching from scaling x and y independently.
        var _art_spr = _dung_art[_di];
        var _box_w   = _is_center ? 672 : 381;
        // #11: center box dropped 84px down / 180px tall (was 54/210) - Scorched
        // Depths' art fills its full square canvas (no built-in padding like the
        // other two), so it rode up underneath the title text.
        var _box_h   = _is_center ? 180 : 150;
        var _box_x   = _cx + (_cw - _box_w) / 2;
        var _box_y   = _cy + (_is_center ? 84 : 54);
        var _src_w   = sprite_get_width(_art_spr);
        var _src_h   = sprite_get_height(_art_spr);
        if (_src_w <= 0) _src_w = 192;
        if (_src_h <= 0) _src_h = 192;
        var _art_scale = min(_box_w / _src_w, _box_h / _src_h);
        var _art_dw    = _src_w * _art_scale;
        var _art_dh    = _src_h * _art_scale;
        var _art_x     = _box_x + (_box_w - _art_dw) / 2;
        var _art_y     = _box_y + (_box_h - _art_dh) / 2;
        draw_sprite_ext(_art_spr, 0, _art_x, _art_y, _art_scale, _art_scale, 0, c_white, _alpha);

        if (_is_center) {
            // Center card content is a clean top-to-bottom stack so nothing overlaps:
            //   divider -> description -> Max Awakening -> selector -> tier desc -> confirm
            var _body_x = _cx + 24;
            var _body_w = _cw - 48;

            // Divider under the art
            draw_set_color(make_color_rgb(35, 42, 65));
            draw_line(_cx + 18, _cy + 273, _cx + _cw - 18, _cy + 273);

            // Description band (its own vertical space)
            draw_set_halign(fa_left);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(175, 183, 210));
            draw_text_ext(_body_x, _cy + 288, _dung_desc[_di], 30, _body_w);

            // Max unlocked tier - on its own line below the description
            var _asc_col;
            if (_unlocked_asc == 0) {
                _asc_col = make_color_rgb(100, 110, 140);
            } else if (_unlocked_asc >= 4) {
                _asc_col = make_color_rgb(255, 70, 70);
            } else {
                _asc_col = make_color_rgb(255, 200, 50);
            }
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui);
            draw_set_color(_asc_col);
            draw_text(_cx + _cw / 2, _cy + 447, "Max Awakening: A" + string(_unlocked_asc));

            // Ascendance selector row
            var _asc_y = _cy + 483;
            draw_set_color(make_color_rgb(20, 26, 48));
            draw_rectangle(_cx + 21, _asc_y, _cx + _cw - 21, _asc_y + 66, false);
            draw_set_color(_dcol);
            draw_rectangle(_cx + 21, _asc_y, _cx + _cw - 21, _asc_y + 66, true);

            // Q / E arrows (touch shows framed < > stepper buttons instead of keys)
            var _can_left  = (_gc_ds.dungeon_select_asc > 0);
            var _can_right = (_gc_ds.dungeon_select_asc < _unlocked_asc);
            var _asc_touch = (input_device() == 2);
            if (_asc_touch) {
                draw_set_color(_can_left ? make_color_rgb(120, 130, 160) : make_color_rgb(40, 48, 70));
                draw_rectangle(_cx + 21, _asc_y, _cx + 105, _asc_y + 66, true);
                draw_set_color(_can_right ? make_color_rgb(120, 130, 160) : make_color_rgb(40, 48, 70));
                draw_rectangle(_cx + _cw - 105, _asc_y, _cx + _cw - 21, _asc_y + 66, true);
            }
            draw_set_halign(fa_center);
            draw_set_color(_can_left  ? c_white : make_color_rgb(40, 48, 70));
            draw_text(_asc_touch ? (_cx + 63) : (_cx + 48), _asc_y + 20, _asc_touch ? "<" : "Q");
            draw_set_color(_can_right ? c_white : make_color_rgb(40, 48, 70));
            draw_text(_asc_touch ? (_cx + _cw - 63) : (_cx + _cw - 60), _asc_y + 20, _asc_touch ? ">" : "E");

            // Tier label (centered in the selector box)
            draw_set_color(c_white);
            draw_text(_cx + _cw / 2, _asc_y + 21, _asc_labels[_gc_ds.dungeon_select_asc]);

            // Touch (8d, M 07-08 "needs cleaner"): visible affordances - framed
            // carousel arrows, awakening steppers (drawn above), and the green
            // Confirm bar (drawn below) is the tap target for EMBARK. Steppers
            // are exact button zones now, not invisible box halves.
            if (input_device() == 2) {
                // Frames follow the repositioned triangles (left now flanks the
                // selected card at x 528, mirroring the right at 1392).
                draw_set_color(make_color_rgb(120, 130, 160));
                draw_rectangle(474, GUI_CY - 66, 582, GUI_CY + 90, true);
                draw_rectangle(1338, GUI_CY - 66, 1446, GUI_CY + 90, true);
                if      (touch_tapped(444, GUI_CY - 90, 600, GUI_CY + 114))   touch_press(ord("A"));
                else if (touch_tapped(1300, GUI_CY - 90, 1482, GUI_CY + 114)) touch_press(ord("D"));
                else if (touch_tapped(_cx + 21, _asc_y, _cx + 105, _asc_y + 66))            touch_press(ord("Q"));
                else if (touch_tapped(_cx + _cw - 105, _asc_y, _cx + _cw - 21, _asc_y + 66)) touch_press(ord("E"));
                else if (touch_tapped(_cx + 21, _cy + _ch - 87, _cx + _cw - 21, _cy + _ch - 21)) touch_press(vk_enter);
            }

            // Tier description - below the selector box (computed, matches combat)
            var _sel_a   = _gc_ds.dungeon_select_asc;
            var _sel_txt = (_sel_a == 0)
                ? "Standard difficulty. No modifiers. Full effects listed on the right."
                : "Enemies: +" + string(round((awaken_hp_mult(_sel_a) - 1) * 100)) + "% HP, +"
                    + string(round((awaken_dmg_mult(_sel_a) - 1) * 100))
                    + "% damage. Full effects listed on the right.";
            draw_set_halign(fa_left);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(140, 150, 185));
            draw_text_ext(_body_x, _asc_y + 84, _sel_txt, 30, _body_w);

            // Confirm bar
            var _conf_y = _cy + _ch - 87;
            draw_set_color(make_color_rgb(18, 50, 22));
            draw_rectangle(_cx + 21, _conf_y, _cx + _cw - 21, _conf_y + 66, false);
            draw_set_color(make_color_rgb(45, 140, 60));
            draw_rectangle(_cx + 21, _conf_y, _cx + _cw - 21, _conf_y + 66, true);
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui);
            draw_set_color(c_white);
            draw_text(_cx + _cw / 2, _conf_y + 20, (input_device() == 2)
                ? "EMBARK  -  Choose Loadout"
                : "[ Enter ]  Confirm & Choose Loadout");

        } else {
            // Side cards: text below art
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(60, 68, 92));
            draw_text(_cx + _cw / 2, _cy + 219, "A" + string(_unlocked_asc) + " max");
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(55, 60, 82));
            draw_text_ext(_cx + 18, _cy + 252, _dung_desc[_di], 27, _cw - 36);
        }

        draw_set_alpha(1.0);
    }

    // -------------------------------------------------------------------------
    // AWAKENING EFFECTS panel (right flank) - the comprehensive readout of what
    // the selected tier changes for the selected dungeon. Every number comes from
    // the same awaken_* helpers combat consumes, so this can never go stale.
    // -------------------------------------------------------------------------
    var _fx_x1 = 1464, _fx_x2 = 1893, _fx_y1 = 123, _fx_y2 = 1040;
    var _fx_a    = _gc_ds.dungeon_select_asc;
    var _fx_dkey = _dungeons[_cursor];
    var _fx_tcol = (_fx_a == 0) ? make_color_rgb(150, 160, 190)
                 : (_fx_a >= 4  ? make_color_rgb(255, 70, 70)
                                : make_color_rgb(255, 200, 50));

    draw_set_color(make_color_rgb(14, 16, 28));
    draw_rectangle(_fx_x1, _fx_y1, _fx_x2, _fx_y2, false);
    draw_set_color(_fx_tcol);
    draw_rectangle(_fx_x1, _fx_y1, _fx_x2, _fx_y1 + 6, false);
    draw_rectangle(_fx_x1, _fx_y1, _fx_x2, _fx_y2, true);

    var _fxx = _fx_x1 + 21;
    var _fxw = (_fx_x2 - _fx_x1) - 42;
    var _fxy = _fx_y1 + 24;

    draw_set_halign(fa_center);
    draw_set_font(fnt_ui);
    draw_set_color(_fx_tcol);
    draw_text(_fx_x1 + (_fx_x2 - _fx_x1) / 2, _fxy, "AWAKENING EFFECTS");
    _fxy += 42;
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(180, 188, 215));
    draw_text(_fx_x1 + (_fx_x2 - _fx_x1) / 2, _fxy, _asc_labels[_fx_a]);
    _fxy += 48;
    draw_set_halign(fa_left);

    // ---- ENEMIES ----
    draw_set_color(make_color_rgb(235, 110, 90));
    draw_text(_fxx, _fxy, "ENEMIES"); _fxy += 33;
    draw_set_color(make_color_rgb(200, 206, 228));
    if (_fx_a == 0) {
        draw_text(_fxx, _fxy, "No stat bonus - baseline foes."); _fxy += 30;
    } else {
        draw_text(_fxx, _fxy, "HP +" + string(round((awaken_hp_mult(_fx_a) - 1) * 100))
            + "%    Damage +" + string(round((awaken_dmg_mult(_fx_a) - 1) * 100)) + "%");
        _fxy += 30;
    }
    if (awaken_enemy_acc_bonus(_fx_a) > 0) {
        draw_text(_fxx, _fxy, "Accuracy +" + string(awaken_enemy_acc_bonus(_fx_a))
            + " (dodge builds get hit more)");
        _fxy += 30;
    }
    if (awaken_enemy_heal_mult(_fx_a) > 1.0) {
        draw_text(_fxx, _fxy, "Self-healing +"
            + string(round((awaken_enemy_heal_mult(_fx_a) - 1) * 100)) + "%");
        _fxy += 30;
    }
    var _fx_packs = ["Packs: mostly 2-3 foes, 4s rare",
                     "Packs: mostly 2-3 foes, 4s rare",
                     "Packs: 4-strong turn common",
                     "Packs: 4-strong turn common",
                     "Packs: 4s common, 5s appear",
                     "Packs: 4s common, 5s appear"];
    draw_text(_fxx, _fxy, _fx_packs[_fx_a]); _fxy += 30;
    // C1 behavior ladder (M-approved 07-09) - one cumulative line, tier-tinted.
    var _fx_beh = "";
    if      (_fx_a >= 4) _fx_beh = "Cunning: spread debuffs, no wasted control, +1 elite";
    else if (_fx_a >= 3) _fx_beh = "Cunning: no wasted control, smart mending";
    else if (_fx_a >= 2) _fx_beh = "Abilities used more often";
    if (_fx_beh != "") {
        draw_set_color(make_color_rgb(230, 160, 90));
        draw_text(_fxx, _fxy, _fx_beh); _fxy += 30;
        draw_set_color(make_color_rgb(200, 206, 228));
    }
    if (_fx_a >= 5) {
        draw_set_color(make_color_rgb(255, 110, 110));
        draw_text(_fxx, _fxy, "Bosses: +25% HP & dmg; ENRAGE past round 6"); _fxy += 30;
    }
    _fxy += 12;

    // ---- REWARDS ----
    draw_set_color(make_color_rgb(110, 210, 130));
    draw_text(_fxx, _fxy, "REWARDS"); _fxy += 33;
    draw_set_color(make_color_rgb(200, 206, 228));
    // Concrete drop odds from the SAME drop_weights table the loot rolls use
    // (#14 / M 07-09: show the actual loot increase per tier, not abstract pips).
    // Rare-or-better and Epic-or-better chance for standard mobs and bosses.
    var _fx_wstd  = drop_weights("standard", _fx_a);
    var _fx_wboss = drop_weights("boss", _fx_a);
    draw_text(_fxx, _fxy, "Rare+ drops: " + string(_fx_wstd[2] + _fx_wstd[3] + _fx_wstd[4])
        + "% mobs / " + string(_fx_wboss[2] + _fx_wboss[3] + _fx_wboss[4]) + "% bosses");
    _fxy += 30;
    draw_text(_fxx, _fxy, "Epic+ drops: " + string(_fx_wstd[3] + _fx_wstd[4])
        + "% mobs / " + string(_fx_wboss[3] + _fx_wboss[4]) + "% bosses");
    _fxy += 30;
    draw_set_color(make_color_rgb(200, 206, 228));
    // Awakening XP multiplier (C3): the panel is the single reference for it.
    if (awaken_xp_mult(_fx_a) > 1.0) {
        draw_text(_fxx, _fxy, "XP from kills +" + string(round((awaken_xp_mult(_fx_a) - 1) * 100)) + "%");
        _fxy += 30;
    }
    draw_text(_fxx, _fxy, "Full-clear bonus: +" + string(awaken_clear_gold_bonus(_fx_a)) + "g");
    _fxy += 30;
    draw_text(_fxx, _fxy, "Rest alcoves heal +" + string(15 + 4 * _fx_a) + " HP");
    _fxy += 42;

    // ---- DUNGEON PASSIVE (selected dungeon at this tier) ----
    draw_set_color(_dung_color[_cursor]);
    draw_text(_fxx, _fxy, string_upper(_dung_names[_cursor]) + " PASSIVE"); _fxy += 33;
    draw_set_color(make_color_rgb(200, 206, 228));
    var _fx_pass = "";
    if (_fx_dkey == "scorched_depths") {
        var _fx_heat = (_fx_a >= 1) ? 4 : 2;
        _fx_pass = "Searing air: each room entered opens the next combat with a burn - "
            + string(_fx_heat) + " fire damage per turn for 2 turns.";
    } else if (_fx_dkey == "tundra_tomb") {
        _fx_pass = (_fx_a >= 3)
            ? "Numbing cold on EVERY floor: -1 AP on your first turn of each combat."
            : "Numbing cold on odd floors: -1 AP on your first turn of each combat.";
    } else {
        _fx_pass = "No environmental passive - the Vault's dead do not meddle.";
    }
    draw_text_ext(_fxx, _fxy, _fx_pass, 27, _fxw);
    _fxy += string_height_ext(_fx_pass, 27, _fxw) + 24;

    // ---- A0 -> A5 mini-table (selected row highlighted, locked tiers dimmed) ----
    draw_set_color(make_color_rgb(60, 64, 90));
    draw_line(_fxx, _fxy, _fx_x2 - 21, _fxy);
    _fxy += 15;
    var _fx_unl = variable_global_exists("dungeon_ascendance_unlocked")
        ? variable_struct_get(global.dungeon_ascendance_unlocked, _fx_dkey) : 0;
    for (var _ft = 0; _ft <= 5; _ft++) {
        var _ft_sel  = (_ft == _fx_a);
        var _ft_lock = (_ft > _fx_unl);
        if (_ft_sel) {
            draw_set_color(make_color_rgb(34, 38, 20));
            draw_rectangle(_fxx - 6, _fxy - 3, _fx_x2 - 15, _fxy + 25, false);
            draw_set_color(make_color_rgb(255, 205, 90));
            draw_rectangle(_fxx - 6, _fxy - 3, _fx_x2 - 15, _fxy + 25, true);
        }
        draw_set_color(_ft_lock ? make_color_rgb(70, 76, 100)
                     : (_ft_sel ? c_white : make_color_rgb(150, 158, 185)));
        draw_text(_fxx, _fxy, "A" + string(_ft));
        var _ft_hp  = round((awaken_hp_mult(_ft)  - 1) * 100);
        var _ft_dmg = round((awaken_dmg_mult(_ft) - 1) * 100);
        draw_text(_fxx + 55,  _fxy, (_ft_hp  > 0) ? ("+" + string(_ft_hp)  + "% HP")  : "-");
        draw_text(_fxx + 175, _fxy, (_ft_dmg > 0) ? ("+" + string(_ft_dmg) + "% dmg") : "-");
        draw_set_halign(fa_right);
        draw_text(_fx_x2 - 27, _fxy, _ft_lock ? "LOCKED" : ("+" + string(awaken_clear_gold_bonus(_ft)) + "g"));
        draw_set_halign(fa_left);
        _fxy += 31;
    }

    // Footer
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(75, 82, 110));
    draw_set_valign(fa_bottom);
    ui_draw_key_legend(GUI_CX, 1073, "A / D: Cycle Dungeon     Q / E: Awakening     Enter: Confirm     Esc: Back");
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}


// -----------------------------------------------------------------------------
// 9. RUN HISTORY OVERLAY - drawn last so it covers everything
// -----------------------------------------------------------------------------
if (show_history) {

    // Full-screen dark cover
    draw_set_alpha(0.95);
    draw_set_color(make_color_rgb(10, 12, 20));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_white);
    draw_text(GUI_CX, 45, "RUN HISTORY");

    // Equipped epithet (expression #5) under the title - the ledger knows your name.
    var _rh_ep = player_epithet_text();
    if (_rh_ep != "") {
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(200, 170, 230));
        draw_text(GUI_CX, 105, "\"" + _rh_ep + "\"");
    }

    // Column headers
    draw_set_halign(fa_left);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(120, 140, 160));
    draw_text( 120, 135, "RUN");
    draw_text( 240, 135, "RESULT");
    draw_text( 435, 135, "FLOOR");
    draw_text( 585, 135, "AWK");
    draw_text( 720, 135, "KILLS");
    draw_text( 840, 135, "GOLD EARNED");
    draw_text(1080, 135, "GOLD KEPT");
    draw_text(1320, 135, "END LVL");
    draw_text(1500, 135, "PERM PTS");

    // Divider
    draw_set_color(make_color_rgb(60, 70, 90));
    draw_line(90, 165, 1830, 165);

    // Run entries - newest first, up to 8 visible rows
    var _history_count = array_length(global.run_history);
    var _visible = min(8, _history_count);

    for (var _i = 0; _i < _visible; _i++) {
        var _idx = _history_count - 1 - (_i + history_scroll);
        if (_idx < 0) break;
        var _r  = global.run_history[_idx];
        var _ry = 195 + _i * 90;

        // Row background
        draw_set_alpha(0.4);
        draw_set_color(make_color_rgb(20, 25, 40));
        draw_rectangle(90, _ry - 8, 1830, _ry + 68, false);
        draw_set_alpha(1.0);

        // Result label and color
        var _result_color = c_white;
        var _result_str   = "EXTRACT";
        if (_r.result == 1)       { _result_color = c_lime; _result_str = "VICTORY"; }
        else if (_r.result == -1) { _result_color = c_red;  _result_str = "DEFEAT";  }

        draw_set_color(c_white);
        draw_text( 120, _ry + 8, "Run " + string(_r.run_number));
        draw_set_color(_result_color);
        draw_text(240, _ry + 8, _result_str);
        draw_set_color(c_white);
        draw_text(435, _ry + 8, "Floor " + string(_r.floor_reached));
        // Awakening (ascendance) tier the run was played at (- for old runs)
        if (variable_struct_exists(_r, "ascendance")) {
            draw_set_color(make_color_rgb(255, 200, 50));
            draw_text(585, _ry + 8, "A" + string(_r.ascendance));
        } else {
            draw_set_color(make_color_rgb(80, 90, 110));
            draw_text(585, _ry + 8, "-");
        }
        draw_set_color(c_white);
        draw_text(720, _ry + 8, string(_r.kills));
        draw_set_color(c_yellow);
        draw_text(840, _ry + 8, string(_r.gold_earned) + "g");
        draw_set_color(make_color_rgb(180, 220, 120));
        draw_text(1080, _ry + 8, string(_r.gold_kept) + "g");
        // End level (- for old runs without this field)
        draw_set_color(c_white);
        if (variable_struct_exists(_r, "end_level")) {
            draw_text(1320, _ry + 8, "Lv " + string(_r.end_level));
        } else {
            draw_text(1320, _ry + 8, "-");
        }
        // Perm points (- for old runs)
        if (variable_struct_exists(_r, "perm_points_earned") && _r.perm_points_earned > 0) {
            draw_set_color(make_color_rgb(255, 210, 60));
            draw_text(1500, _ry + 8, "+" + string(_r.perm_points_earned));
        } else if (variable_struct_exists(_r, "perm_points_earned")) {
            draw_set_color(make_color_rgb(80, 90, 110));
            draw_text(1500, _ry + 8, "0");
        } else {
            draw_set_color(make_color_rgb(80, 90, 110));
            draw_text(1500, _ry + 8, "-");
        }
    }

    // Empty state
    if (_history_count == 0) {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(c_gray);
        draw_text(GUI_CX, 450, "No runs recorded yet.");
    }

    // Lifetime totals footer
    var _total_earned = 0;
    for (var _hi = 0; _hi < _history_count; _hi++) {
        if (variable_struct_exists(global.run_history[_hi], "perm_points_earned")) {
            _total_earned += global.run_history[_hi].perm_points_earned;
        }
    }
    var _total_spent = 0;
    if (variable_global_exists("perm_str_bonus")) {
        _total_spent = global.perm_str_bonus + global.perm_dex_bonus + global.perm_con_bonus
                     + global.perm_int_bonus + global.perm_wis_bonus + global.perm_cha_bonus;
    }
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(255, 210, 60));
    // Touch: lift clear of the persistent chip bar (top ~y1005) which draws over this
    // hub-context overlay (M 07-17: was hidden behind the menu buttons).
    draw_text(GUI_CX, (input_device() == 2) ? 958 : 1002, "Lifetime Perm Points - Earned: " + string(_total_earned) + "   Spent: " + string(_total_spent) + "   Available: " + string(global.pending_perm_points));

    // Scroll / close hint
    draw_set_color(make_color_rgb(120, 130, 150));
    if (_history_count > 8) {
        ui_draw_key_legend(GUI_CX, 1035, "W/S: Scroll   Esc: Close");
    } else {
        ui_draw_key_legend(GUI_CX, 1035, "Esc: Close");
    }

    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// -----------------------------------------------------------------------------
// 10. PERMANENT ALLOCATION BANNER + OVERLAY
// Banner appears when points are waiting; overlay opens on P.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller) && variable_global_exists("pending_perm_points")) {
    var _gc_hub_d = instance_find(obj_game_controller, 0);

    // Banner - centered in the open zone below the NPC list, with blink. The list is
    // 8 rows since the Tavern Requests board joined (last row ends y858), so the
    // banner sits under that.
    if (global.pending_perm_points > 0 && !_gc_hub_d.perm_alloc_open) {
        var _blink_on = ((current_time mod 900) < 500);
        draw_set_alpha(_blink_on ? 1.0 : 0.28);

        var _ban_w = 720;
        var _ban_h = 78;
        var _ban_x = GUI_CX - _ban_w / 2;
        var _ban_y = 872;

        draw_set_color(make_color_rgb(50, 38, 8));
        draw_rectangle(_ban_x, _ban_y, _ban_x + _ban_w, _ban_y + _ban_h, false);
        draw_set_color(make_color_rgb(200, 160, 30));
        draw_rectangle(_ban_x, _ban_y, _ban_x + _ban_w, _ban_y + _ban_h, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(255, 215, 60));
        draw_text(GUI_CX, _ban_y + 21, "! PERMANENT POINTS AVAILABLE !");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(220, 190, 100));
        draw_text(GUI_CX, _ban_y + 53, string(global.pending_perm_points) + " point(s) to spend  -  press  P");

        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
    }

    // Full-screen allocation overlay
    if (_gc_hub_d.perm_alloc_open) {
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);

        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_title);
        draw_set_color(make_color_rgb(255, 200, 50));
        draw_text(GUI_CX, 90, "PERMANENT UPGRADE");
        draw_set_font(fnt_ui);
        draw_set_color(c_white);
        var _perm_pts_str = (global.pending_perm_points == 1) ? "1 point" : string(global.pending_perm_points) + " points";
        draw_text(GUI_CX, 159, "Allocate " + _perm_pts_str + " into permanent stats");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(150, 160, 180));
        draw_text(GUI_CX, 195, "These bonuses carry into every future run.");
        draw_set_halign(fa_left);

        var _perm_stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        var _perm_stat_descs = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"];
        var _perm_glob_keys  = ["perm_str_bonus", "perm_dex_bonus", "perm_con_bonus",
                                "perm_int_bonus", "perm_wis_bonus", "perm_cha_bonus"];

        draw_set_font(fnt_ui);
        for (var _si = 0; _si < 6; _si++) {
            var _sy     = 255 + _si * 108;
            var _is_sel = (_si == _gc_hub_d.perm_alloc_index);
            var _is_arm = (_si == _gc_hub_d.perm_alloc_confirm);
            var _cur    = variable_global_get(_perm_glob_keys[_si]);

            draw_set_alpha(_is_sel ? 1.0 : 0.6);
            draw_set_color(_is_arm ? make_color_rgb(30, 60, 30) : (_is_sel ? make_color_rgb(50, 35, 10) : make_color_rgb(18, 22, 38)));
            draw_rectangle(510, _sy, 1410, _sy + 87, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_arm ? make_color_rgb(110, 220, 130) : (_is_sel ? make_color_rgb(220, 170, 50) : make_color_rgb(70, 60, 40)));
            draw_rectangle(510, _sy, 1410, _sy + 87, true);

            draw_set_color(_is_sel ? c_white : make_color_rgb(140, 150, 170));
            draw_text(540, _sy + 27, _perm_stat_descs[_si] + "  (" + _perm_stat_names[_si] + ")");
            draw_set_halign(fa_right);
            if (_is_arm) {
                draw_set_color(make_color_rgb(110, 220, 130));
                draw_text(1380, _sy + 27, "Confirm +1 " + _perm_stat_names[_si] + "?");
            } else {
                draw_set_color(make_color_rgb(255, 200, 50));
                draw_text(1380, _sy + 27, "+" + string(_cur) + " permanent");
            }
            draw_set_halign(fa_left);
        }

        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(80, 90, 110));
        ui_draw_key_legend(GUI_CX, 938, (_gc_hub_d.perm_alloc_confirm != -1)
            ? "Enter: CONFIRM permanent point   Esc: Cancel"
            : "W/S: Navigate   Enter: Select   Enter again: Confirm   Esc: Back");
        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
    }
}

// -----------------------------------------------------------------------------
// 12. ITEM GALLERY OVERLAY - shown when show_gallery is true
// Full-screen dark cover; list on left (x=20-740), detail panel on right (x=760-1260).
// -----------------------------------------------------------------------------
if (show_gallery) {

    // Full-screen dark cover
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(10, 12, 20));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_font(fnt_ui_title);
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    draw_text(GUI_CX, 30, "ITEM CODEX");
    draw_set_halign(fa_left);

    // Build master item list (common -> uncommon -> rare -> legendary)
    var _gal_all = [];
    if (variable_global_exists("loot_table_common"))    { for (var _gi = 0; _gi < array_length(global.loot_table_common);    _gi++) array_push(_gal_all, global.loot_table_common[_gi]);    }
    if (variable_global_exists("loot_table_uncommon"))  { for (var _gi = 0; _gi < array_length(global.loot_table_uncommon);  _gi++) array_push(_gal_all, global.loot_table_uncommon[_gi]);  }
    if (variable_global_exists("loot_table_rare"))      { for (var _gi = 0; _gi < array_length(global.loot_table_rare);      _gi++) array_push(_gal_all, global.loot_table_rare[_gi]);      }
    if (variable_global_exists("loot_table_legendary")) { for (var _gi = 0; _gi < array_length(global.loot_table_legendary); _gi++) array_push(_gal_all, global.loot_table_legendary[_gi]); }
    var _gal_count   = array_length(_gal_all);
    var _gal_visible = 12;
    var _row_h       = 69;
    var _list_y0     = 120;

    // Build discovered set for fast lookup
    var _disc_set = [];
    if (variable_global_exists("items_discovered")) {
        for (var _di = 0; _di < array_length(global.items_discovered); _di++) {
            array_push(_disc_set, global.items_discovered[_di]);
        }
    }
    var _disc_count = array_length(_disc_set);

    // -------------------------------------------------------------------------
    // LEFT PANEL - scrollable item list (x=30, w=1080)
    // -------------------------------------------------------------------------
    for (var _ri = 0; _ri < _gal_visible; _ri++) {
        var _abs_i = gallery_scroll + _ri;
        if (_abs_i >= _gal_count) break;

        var _it    = _gal_all[_abs_i];
        var _ry    = _list_y0 + _ri * _row_h;
        var _is_cur = (_abs_i == gallery_cursor);

        // Check discovered
        var _disc = false;
        for (var _dci = 0; _dci < _disc_count; _dci++) {
            if (_disc_set[_dci] == _it.name) { _disc = true; break; }
        }

        // Row background
        var _bg_col = _is_cur ? make_color_rgb(28, 38, 65) : make_color_rgb(14, 16, 28);
        draw_set_alpha(_disc ? 1.0 : 0.55);
        draw_set_color(_bg_col);
        draw_rectangle(30, _ry, 1110, _ry + _row_h - 3, false);
        draw_set_alpha(1.0);
        var _is_equipped_gal = false;
        if (_disc && variable_global_exists("inventory")) {
            for (var _ei = 0; _ei < array_length(global.inventory); _ei++) {
                if (global.inventory[_ei] != undefined && global.inventory[_ei].name == _it.name) {
                    _is_equipped_gal = true; break;
                }
            }
        }
        var _bord_col = _is_cur        ? make_color_rgb(70, 100, 200)
            : (_is_equipped_gal        ? make_color_rgb(55, 185, 95)
            :                            make_color_rgb(35, 40, 62));
        draw_set_color(_bord_col);
        draw_rectangle(30, _ry, 1110, _ry + _row_h - 3, true);

        // Rarity color badge (left 6px strip)
        var _rar_col = item_rarity_color(_it.rarity);
        draw_set_alpha(_disc ? 1.0 : 0.4);
        draw_set_color(_rar_col);
        draw_rectangle(30, _ry, 36, _ry + _row_h - 3, false);
        draw_set_alpha(1.0);

        // Item name or ???
        draw_set_font(fnt_ui);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        if (_disc) {
            draw_set_color(_rar_col);
            draw_text(45, _ry + 8, _it.name);
        } else {
            draw_set_color(make_color_rgb(55, 60, 85));
            draw_text(45, _ry + 8, "???");
        }

        // Slot label (right side)
        var _slot_str = string_upper(string(_it.slot));
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_right);
        draw_set_color(_disc ? make_color_rgb(140, 150, 190) : make_color_rgb(40, 45, 68));
        draw_text(1103, _ry + 8, _slot_str);

        // Stat preview (second line, only if discovered)
        if (_disc) {
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(100, 110, 145));
            draw_text(45, _ry + 38, _it.effect_desc);
        }
    }

    // Scroll indicator
    if (_gal_count > _gal_visible) {
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(70, 80, 110));
        draw_text(570, _list_y0 + _gal_visible * _row_h + 6,
            string(gallery_scroll + 1) + " - " + string(min(gallery_scroll + _gal_visible, _gal_count))
            + " of " + string(_gal_count) + "  (W/S or mouse wheel)");
    }

    // Discovered count
    draw_set_font(fnt_ui_small);
    draw_set_halign(fa_right);
    draw_set_color(make_color_rgb(80, 100, 150));
    draw_text(1103, 78, string(_disc_count) + " / " + string(_gal_count) + " discovered");

    // -------------------------------------------------------------------------
    // RIGHT PANEL - detail view (x=1140, w=750) or empty state
    // -------------------------------------------------------------------------
    var _dp_x = 1140;
    var _dp_y = 120;
    var _dp_w = 750;
    var _dp_h = 840;

    draw_set_alpha(0.85);
    draw_set_color(make_color_rgb(12, 14, 26));
    draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(45, 55, 90));
    draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, true);

    if (gallery_detail_item != undefined) {
        var _d   = gallery_detail_item;
        var _dx  = _dp_x + 27;
        var _txw = _dp_w - 54;
        var _is_leg = (variable_struct_exists(_d, "rarity") && _d.rarity == 4);

        // Rarity strip at top of detail panel
        draw_set_color(item_rarity_color(_d.rarity));
        draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + 6, false);

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // --- Splash art box (splash sprite if it exists, else scaled item icon) ---
        var _art_sz = 198;
        var _art_x  = _dp_x + (_dp_w - _art_sz) / 2;
        var _art_y  = _dp_y + 21;
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_rectangle(_art_x, _art_y, _art_x + _art_sz, _art_y + _art_sz, false);
        draw_set_color(item_rarity_color(_d.rarity));
        draw_rectangle(_art_x, _art_y, _art_x + _art_sz, _art_y + _art_sz, true);
        var _splash = item_splash_sprite(item_base_name(_d));
        if (_splash != -1 && sprite_exists(_splash)) {
            ui_draw_sprite_cover(_splash, 0, _art_x + 3, _art_y + 3, _art_sz - 6, _art_sz - 6, 1.0);
        } else {
            // Fallback: enlarge the item icon, centered in the box. Unframed (#10):
            // the art box above IS the frame - the icon's own box read as an
            // icon-within-an-icon (Chipped Spear et al.).
            ui_draw_item_icon(_art_x + (_art_sz - 150) / 2, _art_y + (_art_sz - 150) / 2, 150, _d, false);
        }

        // --- Name + rarity/slot ---
        var _ly = _art_y + _art_sz + 18;
        draw_set_font(fnt_ui_title);
        draw_set_halign(fa_center);
        draw_set_color(item_rarity_color(_d.rarity));
        draw_text_ext(_dp_x + _dp_w / 2, _ly, _d.name, -1, _txw);
        _ly += string_height_ext(_d.name, -1, _txw) + 6;
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(130, 140, 185));
        var _rs_line = string_upper(item_rarity_name(_d.rarity)) + "  *  " + string_upper(string(_d.slot));
        draw_text(_dp_x + _dp_w / 2, _ly, _rs_line);
        _ly += string_height(_rs_line) + 12;
        draw_set_halign(fa_left);

        // Divider
        draw_set_color(make_color_rgb(45, 55, 90));
        draw_line(_dx, _ly, _dp_x + _dp_w - 27, _ly);
        _ly += 15;

        // --- Lore (legendary, gold) OR generic description ---
        if (_is_leg && variable_struct_exists(_d, "lore") && _d.lore != "") {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(235, 205, 120));
            draw_text_ext(_dx, _ly, _d.lore, -1, _txw);
            _ly += string_height_ext(_d.lore, -1, _txw) + 12;
        } else {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(170, 185, 215));
            var _gdesc = item_generic_desc(_d);
            draw_text_ext(_dx, _ly, _gdesc, -1, _txw);
            _ly += string_height_ext(_gdesc, -1, _txw) + 6;
            // one-line flavor from the item's effect_desc, when present
            if (variable_struct_exists(_d, "effect_desc") && _d.effect_desc != "") {
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(110, 122, 150));
                var _flav = "\"" + ui_sentence(_d.effect_desc) + "\"";
                draw_text_ext(_dx, _ly, _flav, -1, _txw);
                _ly += string_height_ext(_flav, -1, _txw) + 9;
            }
        }

        // --- Stat ranges reference ---
        draw_set_color(make_color_rgb(45, 55, 90));
        draw_line(_dx, _ly, _dp_x + _dp_w - 27, _ly);
        _ly += 15;
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(150, 165, 200));
        draw_text(_dx, _ly, "Rolls & Stats");
        _ly += string_height("Rolls & Stats") + 6;
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(190, 200, 225));
        var _ranges = item_stat_ranges_text(_d);
        draw_text_ext(_dx, _ly, _ranges, -1, _txw);
        _ly += string_height_ext(_ranges, -1, _txw) + 12;

        // --- Unique effect (legendary) ---
        if (variable_struct_exists(_d, "unique_desc") && _d.unique_desc != "") {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(255, 200, 60));
            draw_text(_dx, _ly, "Unique Effect");
            _ly += string_height("Unique Effect") + 6;
            draw_set_color(make_color_rgb(255, 220, 100));
            draw_text_ext(_dx + 9, _ly, _d.unique_desc, -1, _txw - 9);
        }

        // Gold value
        draw_set_color(make_color_rgb(45, 55, 90));
        draw_line(_dx, _dp_y + _dp_h - 90, _dp_x + _dp_w - 27, _dp_y + _dp_h - 90);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(200, 170, 60));
        draw_text(_dx, _dp_y + _dp_h - 69, "Value:  " + string(_d.gold_value) + "g");

        // Close hint
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(70, 80, 118));
        draw_text_outline(_dp_x + _dp_w - 27, _dp_y + _dp_h - 69, "Esc / click to close");
        draw_set_halign(fa_left);

    } else {
        // Empty state
        draw_set_font(fnt_ui);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(make_color_rgb(45, 52, 82));
        draw_text(_dp_x + _dp_w / 2, _dp_y + _dp_h / 2, "Select a discovered item\nto view details");
        draw_set_valign(fa_top);
    }

    // Footer hint
    draw_set_font(fnt_ui_small);
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(60, 68, 100));
    ui_draw_key_legend(GUI_CX, 1044, "W/S: Navigate   Enter: Inspect   G / Esc: Close Gallery");
    draw_set_halign(fa_left);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}


// -----------------------------------------------------------------------------
// 11. LOADOUT OVERLAY - tabbed: ABILITIES (tab 0) and TRAITS (tab 1)
// Full-screen overlay; drawn on top of all hub content when loadout_open.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_ov = instance_find(obj_game_controller, 0);

    if (_gc_ov.loadout_open) {
        var _ov_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;
        var _ov_pool  = abilities_class_pool(_ov_class);   // class abilities + general pool
        var _ov_pool_sz  = array_length(_ov_pool);
        var _ov_sel_cnt  = array_length(_gc_ov.loadout_selected);
        // Match the live-selection cap used in Step (Expanded Arsenal opens slot 5 immediately)
        var _loadout_max = 4;
        for (var _ea = 0; _ea < array_length(_gc_ov.traits_selected); _ea++) {
            if (_gc_ov.traits_selected[_ea] == "Expanded Arsenal") { _loadout_max = 5; break; }
        }

        // Shared layout constants
        // list fits 10 rows (74px each) from y=106, leaving the bottom zone for
        // desc/confirm/hints. 106 (not 83): the fnt_ui headers at y=60 are 33px
        // tall and the cursor's gold frame juts 3px above the row - anything
        // higher and the header text collides with a highlighted top row.
        var _lx      = 60;
        var _rx      = 1125;
        var _list_y0 = 106;
        var _row_h   = 69;
        var _row_gap = 5;   // 74px per row

        // Background - fully opaque; nothing from the hub draws underneath
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);

        // --- Tab bar ---
        // Touch (M 07-08 device test: "tapping repeatedly ... only registers
        // sometimes"): the 42px-tall tabs are half a fingertip on glass, so on
        // touch the drawn tabs grow to 90px (the Step hit zones grow with them)
        // and the pressed tab brightens the moment the finger lands.
        var _tab_touch = (input_device() == 2);
        var _tab_y  = 9;
        var _tab_h  = _tab_touch ? 90 : 42;
        var _tab_w  = 315;
        var _mid    = GUI_CX;

        // Three centred tabs: ABILITIES / TRAITS / COMPANION (ranges mirror the Step
        // mouse hit-tests). Each gets its own accent colour.
        var _tab_names = ["ABILITIES", "TRAITS", "COMPANION"];
        var _tab_acc   = [make_color_rgb(70, 100, 200), make_color_rgb(120, 65, 190), make_color_rgb(90, 170, 110)];
        var _tab_bgon  = [make_color_rgb(22, 32, 65),   make_color_rgb(28, 18, 52),   make_color_rgb(18, 42, 26)];
        var _tab_gap   = 9;
        var _tab_tot   = 3 * _tab_w + 2 * _tab_gap;
        var _tab_x0    = _mid - _tab_tot / 2;
        var _tab_pmx   = device_mouse_x_to_gui(0);
        var _tab_pmy   = device_mouse_y_to_gui(0);
        var _tab_pdn   = _tab_touch && mouse_check_button(mb_left);
        draw_set_font(fnt_ui);
        draw_set_halign(fa_center);
        for (var _tbi = 0; _tbi < 3; _tbi++) {
            var _tbx = _tab_x0 + _tbi * (_tab_w + _tab_gap);
            var _ton = (_gc_ov.loadout_tab == _tbi);
            var _tpr = _tab_pdn && _tab_pmx >= _tbx && _tab_pmx < _tbx + _tab_w
                                && _tab_pmy >= 0    && _tab_pmy < _tab_y + _tab_h + 12;
            draw_set_color(_tpr ? make_color_rgb(52, 44, 26) : (_ton ? _tab_bgon[_tbi] : make_color_rgb(11, 13, 22)));
            draw_rectangle(_tbx, _tab_y, _tbx + _tab_w, _tab_y + _tab_h, false);
            draw_set_color(_tpr ? make_color_rgb(245, 195, 80) : (_ton ? _tab_acc[_tbi] : make_color_rgb(32, 38, 65)));
            draw_rectangle(_tbx, _tab_y, _tbx + _tab_w, _tab_y + _tab_h, true);
            draw_set_color(_ton ? c_white : make_color_rgb(75, 85, 120));
            draw_text(_tbx + _tab_w / 2, _tab_y + (_tab_touch ? 33 : 11), _tab_names[_tbi]);
        }
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(55, 62, 88));
        if (_tab_touch) {
            // Touch hint (M 07-08: asked for a drag hint + swipe tabs) - replaces
            // the keyboard-speak line. Drawn in the free strip BELOW the confirm
            // bar (the taller touch tabs leave no room above the list at y106).
            draw_text_outline(_mid, 1048, "Swipe sideways to switch tabs - drag to scroll - hold a row for details");
        } else {
            draw_text_outline(_mid, _tab_y + _tab_h + 6, "Q / E switch tabs");
        }
        draw_set_halign(fa_left);

        // =====================================================================
        // ABILITIES TAB
        // =====================================================================
        if (_gc_ov.loadout_tab == 0) {

            // Panel headers
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(130, 150, 200));
            draw_text(_lx, 60, "CLASS ABILITIES");
            // Touch: the 90px tabs cover (_rx, 60) - the header moves to the free
            // strip right of the COMPANION tab (M 07-08: "all overlap with the
            // companion tab"). Same treatment on all three tabs.
            if (input_device() == 2) {
                draw_set_font(fnt_ui_small);
                draw_text(1460, 66, "YOUR LOADOUT");
                draw_set_font(fnt_ui);
            } else {
                draw_text(_rx, 60, "YOUR LOADOUT");
            }

            // Left panel: ability rows (windowed - the pool exceeds the screen)
            var _ov_max_vis = 10;
            // Stateful EDGE scrolling (kept in sync with Step_0): scroll only when the
            // cursor crosses the window's top/bottom edge.
            var _ov_scroll = variable_instance_exists(_gc_ov, "loadout_scroll") ? _gc_ov.loadout_scroll : 0;
            _ov_scroll = clamp(_ov_scroll, _gc_ov.loadout_cursor - (_ov_max_vis - 1), _gc_ov.loadout_cursor);
            _ov_scroll = clamp(_ov_scroll, 0, max(0, _ov_pool_sz - _ov_max_vis));
            _gc_ov.loadout_scroll = _ov_scroll;
            for (var _ai = _ov_scroll; _ai < min(_ov_pool_sz, _ov_scroll + _ov_max_vis); _ai++) {
                var _ab     = _ov_pool[_ai];
                var _ry     = _list_y0 + (_ai - _ov_scroll) * (_row_h + _row_gap);
                var _is_cur = (_ai == _gc_ov.loadout_cursor);

                var _in_sel = false;
                for (var _si = 0; _si < _ov_sel_cnt; _si++) {
                    if (_gc_ov.loadout_selected[_si] == _ab.name) { _in_sel = true; break; }
                }
                var _ab_unlocked = ability_is_unlocked(_ab.name);

                draw_set_alpha(_is_cur ? 1.0 : (_ab_unlocked ? 0.6 : 0.4));
                draw_set_color(_in_sel   ? make_color_rgb(16, 45, 22)
                            : (_is_cur  ? make_color_rgb(30, 44, 88)
                                        : make_color_rgb(14, 16, 28)));
                draw_rectangle(_lx, _ry, _lx + 990, _ry + _row_h, false);
                draw_set_alpha(1.0);
                draw_set_color(_in_sel  ? make_color_rgb(50, 150, 70)
                            : (_is_cur ? make_color_rgb(60, 90, 185)
                                       : make_color_rgb(35, 40, 65)));
                draw_rectangle(_lx, _ry, _lx + 990, _ry + _row_h, true);
                // Cursor row: thick pulsing gold frame + chevron so the selection can't
                // be missed (the old single 1px blue border read as "just another row").
                if (_is_cur) {
                    var _cur_pulse = 0.65 + 0.35 * (0.5 + 0.5 * sin(current_time / 200));
                    draw_set_alpha(_cur_pulse);
                    draw_set_color(make_color_rgb(255, 205, 90));
                    draw_rectangle(_lx - 1, _ry - 1, _lx + 991, _ry + _row_h + 1, true);
                    draw_rectangle(_lx - 2, _ry - 2, _lx + 992, _ry + _row_h + 2, true);
                    draw_rectangle(_lx - 3, _ry - 3, _lx + 993, _ry + _row_h + 3, true);
                    draw_set_font(fnt_ui);
                    draw_set_valign(fa_middle);
                    draw_text(_lx - 26, _ry + _row_h * 0.5, ">");
                    draw_set_valign(fa_top);
                    draw_set_alpha(1.0);
                }

                // Role-category accent bar on the left edge (offense red / defense blue /
                // support green / control purple) - SYSTEMS_ABILITY_SYNERGY.md.
                draw_set_color(ability_category_color(ability_category(_ab)));
                draw_rectangle(_lx, _ry, _lx + 6, _ry + _row_h, false);

                // Ability icon on the left of the row (dim when locked)
                draw_set_alpha(_ab_unlocked ? 1.0 : 0.4);
                ui_draw_ability_icon(_lx + 9, _ry + 5, 60, _ab);
                draw_set_alpha(1.0);
                var _row_textx = _lx + 9 + 60 + 12;

                var _name_suffix = _in_sel ? "  [SELECTED]" : (!_ab_unlocked ? "  [LOCKED]" : "");
                draw_set_font(fnt_ui);
                draw_set_color(!_ab_unlocked ? make_color_rgb(125, 112, 78)
                            : (_in_sel  ? make_color_rgb(90, 210, 110)
                            : (_is_cur ? c_white
                                       : make_color_rgb(170, 180, 205))));
                draw_text(_row_textx, _ry + 6, _ab.name + _name_suffix);

                // Energy cost tag - right-aligned inside the row
                draw_set_font(fnt_ui_small);
                draw_set_halign(fa_right);
                draw_set_color(c_yellow);
                draw_text(_lx + 972, _ry + 6, "[" + string(_ab.energy_cost) + " AP]");
                // Mastery (expression #2): unspent notch = pulsing gold call-to-action;
                // spent picks = quiet pip count on the row's lower right.
                var _mast_pend  = ability_mastery_pending(_ab.name);
                var _mast_picks = array_length(ability_mastery_picks(_ab.name));
                if (_mast_pend > 0) {
                    draw_set_alpha(0.6 + 0.4 * (0.5 + 0.5 * sin(current_time / 250)));
                    draw_set_color(make_color_rgb(255, 205, 90));
                    draw_text(_lx + 972, _ry + 39, "NOTCH!  [M]");
                    draw_set_alpha(1.0);
                } else if (_mast_picks > 0) {
                    draw_set_color(make_color_rgb(200, 170, 100));
                    draw_text(_lx + 972, _ry + 39, "Mastery " + string(_mast_picks) + "/2");
                }
                draw_set_halign(fa_left);

                if (!_ab_unlocked) {
                    draw_set_color(make_color_rgb(150, 120, 60));
                    draw_text(_row_textx, _ry + 39, "Locked - " + ability_unlock_condition_text(_ab.name));
                } else {
                    draw_set_color(_is_cur ? make_color_rgb(160, 170, 195) : make_color_rgb(85, 95, 120));
                    var _ls_tag = ability_attack_class_tag(_ab);
                    var _ls_sum = ability_summary(_ab);
                    draw_text(_row_textx, _ry + 39, (_ls_tag != "") ? (_ls_sum + "  " + _ls_tag) : _ls_sum);
                }
            }

            // Scroll indicators when the pool overflows the visible window
            draw_set_font(fnt_ui_small);
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(110, 120, 150));
            if (_ov_scroll > 0) {
                ui_draw_scroll_more(_lx + 495, _list_y0 - 21, true, string(_ov_scroll) + " more above");
            }
            var _ov_below = _ov_pool_sz - (_ov_scroll + _ov_max_vis);
            if (_ov_below > 0) {
                ui_draw_scroll_more(_lx + 495, _list_y0 + _ov_max_vis * (_row_h + _row_gap) - 6, false, string(_ov_below) + " more below");
            }
            draw_set_halign(fa_left);

            // Right panel: ability slots (each 108px + 15px gap)
            var _slot_h  = 108;
            var _slot_y0 = _list_y0;
            for (var _si2 = 0; _si2 < _loadout_max; _si2++) {
                var _sy     = _slot_y0 + _si2 * (_slot_h + 15);
                var _has_ab = (_si2 < _ov_sel_cnt);

                draw_set_color(_has_ab ? make_color_rgb(14, 30, 18) : make_color_rgb(12, 14, 22));
                draw_rectangle(_rx, _sy, _rx + 735, _sy + _slot_h, false);
                draw_set_color(_has_ab ? make_color_rgb(45, 120, 55) : make_color_rgb(35, 40, 60));
                draw_rectangle(_rx, _sy, _rx + 735, _sy + _slot_h, true);

                draw_set_font(fnt_ui);
                draw_set_color(make_color_rgb(70, 80, 105));
                draw_text(_rx + 15, _sy + 12, string(_si2 + 1) + ".");

                if (_has_ab) {
                    // Role-category accent bar on the slot's left edge (SYSTEMS_ABILITY_SYNERGY.md).
                    draw_set_color(ability_category_color(ability_category(_gc_ov.loadout_selected[_si2])));
                    draw_rectangle(_rx, _sy, _rx + 6, _sy + _slot_h, false);

                    // 84x84 ability icon between the slot number and its name
                    draw_set_alpha(1.0);
                    ui_draw_ability_icon(_rx + 45, _sy + 12, 84, _gc_ov.loadout_selected[_si2]);
                    var _slot_textx = _rx + 45 + 84 + 15;
                    draw_set_font(fnt_ui);
                    draw_set_color(make_color_rgb(110, 215, 130));
                    draw_text(_slot_textx, _sy + 12, _gc_ov.loadout_selected[_si2]);
                    for (var _ai2 = 0; _ai2 < _ov_pool_sz; _ai2++) {
                        if (_ov_pool[_ai2].name == _gc_ov.loadout_selected[_si2]) {
                            // Energy cost in the slot header
                            draw_set_font(fnt_ui_small);
                            draw_set_halign(fa_right);
                            draw_set_color(c_yellow);
                            draw_text(_rx + 717, _sy + 12, "[" + string(_ov_pool[_ai2].energy_cost) + " AP]");
                            draw_set_halign(fa_left);
                            draw_set_color(make_color_rgb(85, 125, 95));
                            var _sl_tag = ability_attack_class_tag(_ov_pool[_ai2]);
                            var _sl_sum = ability_summary(_ov_pool[_ai2]);
                            draw_text(_slot_textx, _sy + 60, (_sl_tag != "") ? (_sl_sum + "  " + _sl_tag) : _sl_sum);
                            break;
                        }
                    }
                } else {
                    draw_set_font(fnt_ui);
                    draw_set_color(make_color_rgb(45, 50, 70));
                    draw_text(_rx + 48, _sy + 39, "---  empty  ---");
                }
            }

            // --- "Press Tab" hint (clearly above the description box - ample room here) ---
            draw_set_halign(fa_center);
            draw_set_valign(fa_top);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(120, 205, 240));
            draw_text_outline(960, 843, "[ Tab ]  -  full breakdown of the highlighted ability");
            draw_set_halign(fa_left);

            // --- Description box: y=870-990, ornate double border + top accent strip ---
            var _desc_x = 60;
            var _desc_w = 1800;
            draw_set_color(make_color_rgb(10, 13, 26));
            draw_rectangle(_desc_x, 870, _desc_x + _desc_w, 990, false);
            draw_set_color(make_color_rgb(82, 108, 158));                          // outer border
            draw_rectangle(_desc_x, 870, _desc_x + _desc_w, 990, true);
            draw_set_color(make_color_rgb(38, 52, 82));                            // inner border
            draw_rectangle(_desc_x + 3, 873, _desc_x + _desc_w - 3, 987, true);
            draw_set_color(make_color_rgb(95, 135, 205));                          // top accent strip
            draw_rectangle(_desc_x, 870, _desc_x + _desc_w, 875, false);

            draw_set_halign(fa_left);
            if (_gc_ov.loadout_cursor < _ov_pool_sz) {
                var _dab = _ov_pool[_gc_ov.loadout_cursor];
                // Line 1: name + role chip + cost (the "basic ability part" from the Tab popup).
                draw_set_font(fnt_ui);
                draw_set_color(c_white);
                draw_text(_desc_x + 24, 885, _dab.name);
                var _dn_w = string_width(_dab.name);
                var _d_cat = ability_category(_dab);
                draw_set_color(ability_category_color(_d_cat));
                draw_text(_desc_x + 24 + _dn_w + 30, 888, ability_category_label(_d_cat));
                // Cost line, right-aligned (AP + secondary resource + cooldown).
                var _d_ap  = variable_struct_exists(_dab, "energy_cost")    ? _dab.energy_cost    : 0;
                var _d_sec = variable_struct_exists(_dab, "secondary_cost") ? _dab.secondary_cost : 0;
                var _d_cls = variable_global_exists("chosen_class") ? global.chosen_class : 0;
                var _d_res = (_d_cls == 0) ? "Souls" : ((_d_cls == 1) ? "Blood" : "Preparation");
                var _d_cost = string(_d_ap) + " AP";
                if (_d_sec > 0) _d_cost += "   +" + string(_d_sec) + " " + _d_res;
                var _d_cd = ability_cooldown(_dab);
                if (_d_cd > 0) _d_cost += "   *   " + string(_d_cd) + "-turn CD";
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(228, 190, 90));
                draw_text(_desc_x + _desc_w - 24, 888, _d_cost);
                draw_set_halign(fa_left);
                // Line 2+: full mechanics breakdown.
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(172, 187, 217));
                draw_text_ext(_desc_x + 24, 927, ability_describe(_dab), -1, _desc_w - 48);
            } else {
                draw_set_font(fnt_ui_small);
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(80, 195, 100));
                draw_text(_desc_x + _desc_w / 2, 921, "All " + string(_loadout_max) + " abilities chosen - press Enter on the confirm bar below to start your run.");
                draw_set_halign(fa_left);
            }

            // --- Confirm / counter bar: y=998-1043 ---
            // Cursor==pool_sz is the active confirm position; bar highlights when reached.
            var _conf_cur = (_gc_ov.loadout_cursor == _ov_pool_sz);
            var _conf_sel = (_conf_cur && _ov_sel_cnt == _loadout_max);
            // #6: the gold-shortfall flash reddens the bar like the loadout-full flash.
            var _bar_red = _gc_ov.loadout_full_timer > 0
                || (variable_instance_exists(_gc_ov, "loadout_gold_timer") && _gc_ov.loadout_gold_timer > 0);
            draw_set_color(_bar_red                        ? make_color_rgb(40, 10, 10)
                         : (_conf_sel                      ? make_color_rgb(16, 70, 25)
                         : (_conf_cur                      ? make_color_rgb(45, 38, 14)
                         : (_ov_sel_cnt == _loadout_max    ? make_color_rgb(14, 48, 18)
                                                           : make_color_rgb(14, 16, 28)))));
            draw_rectangle(_desc_x, 998, _desc_x + _desc_w, 1043, false);
            draw_set_color(_bar_red                        ? make_color_rgb(155, 40, 40)
                         : (_conf_sel                      ? make_color_rgb(50, 185, 75)
                         : (_conf_cur                      ? make_color_rgb(220, 175, 70)
                         : (_ov_sel_cnt == _loadout_max    ? make_color_rgb(35, 95, 45)
                                                           : make_color_rgb(35, 40, 65)))));
            draw_rectangle(_desc_x, 998, _desc_x + _desc_w, 1043, true);
            // Focused confirm bar gets the same thick pulsing frame as the ability
            // cursor - focus is unmistakable whether it's on a row or on this bar.
            if (_conf_cur) {
                var _cf_pulse = 0.65 + 0.35 * (0.5 + 0.5 * sin(current_time / 200));
                draw_set_alpha(_cf_pulse);
                draw_set_color(_conf_sel ? make_color_rgb(120, 235, 140) : make_color_rgb(255, 205, 90));
                draw_rectangle(_desc_x - 1, 997, _desc_x + _desc_w + 1, 1044, true);
                draw_rectangle(_desc_x - 2, 996, _desc_x + _desc_w + 2, 1045, true);
                draw_set_alpha(1.0);
            }

            draw_set_font(fnt_ui_small);
            draw_set_halign(fa_center);
            var _locked_flash = (variable_instance_exists(_gc_ov, "loadout_locked_timer") && _gc_ov.loadout_locked_timer > 0);
            var _gold_flash = (variable_instance_exists(_gc_ov, "loadout_gold_timer") && _gc_ov.loadout_gold_timer > 0);
            if (_gold_flash) {
                // #6: respec shortfall - drawn in the overlay itself, red like a fail.
                draw_set_color(make_color_rgb(255, 100, 100));
                draw_text(GUI_CX, 1010, _gc_ov.loadout_gold_msg);
            } else if (_locked_flash) {
                draw_set_color(make_color_rgb(230, 180, 80));
                draw_text(GUI_CX, 1010, "That ability is locked - buy it from Vex or meet its unlock goal first.");
            } else if (_gc_ov.loadout_full_timer > 0) {
                draw_set_color(make_color_rgb(255, 100, 100));
                draw_text(GUI_CX, 1010, "Loadout full - remove an ability before adding another.");
            } else if (_conf_sel) {
                draw_set_color(c_white);
                draw_text_outline(GUI_CX, 1010, string(_ov_sel_cnt) + " / " + string(_loadout_max) + " selected   |   [ Space ]  Confirm and Enter Dungeon");
            } else if (_ov_sel_cnt == _loadout_max) {
                draw_set_color(make_color_rgb(80, 175, 100));
                draw_text(GUI_CX, 1010, string(_ov_sel_cnt) + " / " + string(_loadout_max) + " selected   |   Scroll down to [ Enter ] to confirm");
            } else {
                draw_set_color(make_color_rgb(160, 170, 200));
                draw_text(GUI_CX, 1010, string(_ov_sel_cnt) + " / " + string(_loadout_max) + " selected");
            }

            // --- Controls hint: y=1050 ---
            draw_set_color(make_color_rgb(65, 75, 100));
            if (input_device() != 2) ui_draw_key_legend(GUI_CX, 1050, "W/S: Navigate   Q/E: Switch Tab   Enter: Toggle   Tab: Details   M: Mastery   Space: Confirm   Esc: Cancel");
            draw_set_halign(fa_left);

            // --- Tab ability-detail popup, drawn over the loadout (P7) ---
            if (_gc_ov.ability_detail_open && _gc_ov.loadout_cursor < _ov_pool_sz) {
                ui_draw_ability_detail(_ov_pool[_gc_ov.loadout_cursor], (input_device() == 1) ? "Y" : "Tab", _gc_ov.ability_detail_scroll);
            }

            // --- Mastery pick modal (expression #2), over everything on this tab ---
            if (_gc_ov.mastery_pick_open) {
                var _mp_ab2 = undefined;
                for (var _mpj = 0; _mpj < _ov_pool_sz; _mpj++) {
                    if (_ov_pool[_mpj].name == _gc_ov.mastery_pick_ability) { _mp_ab2 = _ov_pool[_mpj]; break; }
                }
                if (_mp_ab2 != undefined) {
                    draw_set_alpha(0.75); draw_set_color(c_black);
                    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
                    draw_set_alpha(1.0);
                    var _mx0 = 560, _my0 = 330, _mx1 = 1360, _my1 = 750;
                    draw_set_color(make_color_rgb(22, 22, 36));
                    draw_rectangle(_mx0, _my0, _mx1, _my1, false);
                    draw_set_color(make_color_rgb(255, 205, 90));
                    draw_rectangle(_mx0, _my0, _mx1, _my1, true);
                    draw_set_halign(fa_center);
                    draw_set_font(fnt_ui_title);
                    draw_set_color(make_color_rgb(255, 215, 120));
                    draw_text(GUI_CX, _my0 + 30, "MASTERY: " + _mp_ab2.name);
                    draw_set_font(fnt_ui_small);
                    draw_set_color(make_color_rgb(170, 175, 195));
                    draw_text(GUI_CX, _my0 + 96, string(ability_casts(_mp_ab2.name)) + " lifetime casts - its edge is yours to choose. Permanent.");
                    var _mp_o = ability_mastery_options(_mp_ab2);
                    for (var _mo = 0; _mo < 2; _mo++) {
                        var _oy  = _my0 + 150 + _mo * 108;
                        var _on  = (_gc_ov.mastery_pick_cursor == _mo);
                        draw_set_color(_on ? make_color_rgb(52, 44, 26) : make_color_rgb(28, 28, 44));
                        draw_rectangle(_mx0 + 60, _oy, _mx1 - 60, _oy + 84, false);
                        draw_set_color(_on ? make_color_rgb(255, 205, 90) : make_color_rgb(60, 62, 90));
                        draw_rectangle(_mx0 + 60, _oy, _mx1 - 60, _oy + 84, true);
                        draw_set_font(fnt_ui);
                        draw_set_color(_on ? c_white : make_color_rgb(175, 180, 200));
                        draw_text(GUI_CX, _oy + 24, _mp_o[_mo].label);
                    }
                    draw_set_font(fnt_ui_small);
                    draw_set_color(make_color_rgb(120, 125, 150));
                    ui_draw_key_legend(GUI_CX, _my1 - 48, "W/S: Choose     Enter: Commit     Esc: Not yet");
                    draw_set_halign(fa_center);
                    draw_set_halign(fa_left);
                }
            }

        // =====================================================================
        // TRAITS TAB
        // =====================================================================
        } else if (_gc_ov.loadout_tab == 1) {

            // Build the merged trait list: unlocked first, then locked - ONE
            // edge-scrolled window the cursor walks end to end (same pattern as
            // the ABILITIES tab; the old separate locked strip overflowed the
            // description box once ~9 traits were unlocked).
            var _tr_avail  = [];
            var _tr_locked = [];
            for (var _tri = 0; _tri < array_length(global.traits_all); _tri++) {
                var _tr = global.traits_all[_tri];
                if (_tr.class_req != -1 && _tr.class_req != _ov_class) continue;
                var _unl = variable_struct_get(global.traits_unlocked, _tr.effect_id);
                if (_unl) {
                    array_push(_tr_avail, _tr);
                } else {
                    array_push(_tr_locked, _tr);
                }
            }
            var _tr_all = [];
            for (var _tmi = 0; _tmi < array_length(_tr_avail);  _tmi++) array_push(_tr_all, { tr: _tr_avail[_tmi],  unlocked: true  });
            for (var _tmj = 0; _tmj < array_length(_tr_locked); _tmj++) array_push(_tr_all, { tr: _tr_locked[_tmj], unlocked: false });
            var _tr_cnt       = array_length(_tr_all);
            var _tr_avail_cnt = array_length(_tr_avail);
            var _tr_sel_cnt   = array_length(_gc_ov.traits_selected);

            // Panel headers
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(150, 120, 210));
            draw_text(_lx, 60, "AVAILABLE TRAITS  (" + string(_tr_avail_cnt) + " / " + string(_tr_cnt) + ")");
            // Touch: header clears the 90px COMPANION tab (see abilities tab note).
            if (input_device() == 2) {
                draw_set_font(fnt_ui_small);
                draw_text(1460, 66, "SELECTED  (" + string(_tr_sel_cnt) + " / " + string(max_trait_slots()) + ")");
                draw_set_font(fnt_ui);
            } else {
                draw_text(_rx, 60, "SELECTED TRAITS  (" + string(_tr_sel_cnt) + " / " + string(max_trait_slots()) + ")");
            }

            // Trait rows: stateful EDGE scrolling (kept in sync with Step_0),
            // 8 rows visible (96px pitch from y=106 ends at 874, clearing the
            // y=900 description box).
            var _tr_row_h   = 90;
            var _tr_row_gap = 6;
            var _tr_max_vis = 8;
            var _tr_scroll  = variable_instance_exists(_gc_ov, "traits_scroll") ? _gc_ov.traits_scroll : 0;
            _tr_scroll = clamp(_tr_scroll, _gc_ov.traits_cursor - (_tr_max_vis - 1), _gc_ov.traits_cursor);
            _tr_scroll = clamp(_tr_scroll, 0, max(0, _tr_cnt - _tr_max_vis));
            _gc_ov.traits_scroll = _tr_scroll;
            for (var _tai = _tr_scroll; _tai < min(_tr_cnt, _tr_scroll + _tr_max_vis); _tai++) {
                var _te     = _tr_all[_tai];
                var _tr     = _te.tr;
                var _tr_unl = _te.unlocked;
                var _ry     = _list_y0 + (_tai - _tr_scroll) * (_tr_row_h + _tr_row_gap);
                var _is_cur = (_tai == _gc_ov.traits_cursor);

                var _in_sel = false;
                if (_tr_unl) {
                    for (var _si = 0; _si < _tr_sel_cnt; _si++) {
                        if (_gc_ov.traits_selected[_si] == _tr.name) { _in_sel = true; break; }
                    }
                }

                draw_set_alpha(_is_cur ? 1.0 : (_tr_unl ? 0.65 : 0.4));
                draw_set_color(_in_sel  ? make_color_rgb(28, 14, 52)
                            : (_is_cur ? make_color_rgb(30, 18, 58)
                                       : make_color_rgb(14, 16, 28)));
                draw_rectangle(_lx, _ry, _lx + 990, _ry + _tr_row_h, false);
                draw_set_alpha(1.0);
                draw_set_color(_in_sel  ? make_color_rgb(140, 70, 210)
                            : (_is_cur ? make_color_rgb(100, 60, 180)
                            : (_tr_unl ? make_color_rgb(35, 40, 65)
                                       : make_color_rgb(28, 32, 48))));
                draw_rectangle(_lx, _ry, _lx + 990, _ry + _tr_row_h, true);
                // Cursor row: thick pulsing gold frame + chevron, mirroring the
                // ABILITIES tab cursor so the selection can't be missed.
                if (_is_cur) {
                    var _tcur_pulse = 0.65 + 0.35 * (0.5 + 0.5 * sin(current_time / 200));
                    draw_set_alpha(_tcur_pulse);
                    draw_set_color(make_color_rgb(255, 205, 90));
                    draw_rectangle(_lx - 1, _ry - 1, _lx + 991, _ry + _tr_row_h + 1, true);
                    draw_rectangle(_lx - 2, _ry - 2, _lx + 992, _ry + _tr_row_h + 2, true);
                    draw_rectangle(_lx - 3, _ry - 3, _lx + 993, _ry + _tr_row_h + 3, true);
                    draw_set_font(fnt_ui);
                    draw_set_valign(fa_middle);
                    draw_text(_lx - 26, _ry + _tr_row_h * 0.5, ">");
                    draw_set_valign(fa_top);
                    draw_set_alpha(1.0);
                }

                // Left accent bar on the active cursor / selected rows.
                if (_is_cur || _in_sel) {
                    draw_set_color(_in_sel ? make_color_rgb(140, 70, 210) : make_color_rgb(100, 60, 180));
                    draw_rectangle(_lx, _ry, _lx + 5, _ry + _tr_row_h, false);
                }

                // Trait icon badge (left of the text); locked rows dim it hard.
                draw_set_alpha(_tr_unl ? (_is_cur ? 1.0 : 0.78) : 0.4);
                ui_draw_trait_icon(_lx + 14, _ry + 13, 64, _tr);
                draw_set_alpha(1.0);

                var _tr_name_suf = _in_sel ? "  [SELECTED]" : (!_tr_unl ? "  [LOCKED]" : "");
                draw_set_font(fnt_ui);
                draw_set_color(!_tr_unl ? make_color_rgb(125, 112, 78)
                            : (_in_sel  ? make_color_rgb(190, 130, 255)
                            : (_is_cur ? c_white
                                       : make_color_rgb(170, 175, 210))));
                draw_text(_lx + 92, _ry + 8, _tr.name + _tr_name_suf);
                draw_set_font(fnt_ui_small);
                if (!_tr_unl) {
                    // Real unlock path since the Vex rework: bought from Vex for
                    // gold + a rarity-matched item (the old milestone text was stale).
                    var _tr_cost = trait_unlock_cost(_tr.name);
                    draw_set_color(make_color_rgb(150, 120, 60));
                    draw_text(_lx + 92, _ry + 41, "Locked - Vex sells it: " + string(_tr_cost.gold) + "g + a " + _tr_cost.item_label + " item");
                } else {
                    draw_set_color(_is_cur ? make_color_rgb(155, 165, 200) : make_color_rgb(80, 88, 118));
                    draw_text_ext(_lx + 92, _ry + 41, _tr.description, -1, 880);
                }
            }

            // Scroll indicators when the merged list overflows the window
            draw_set_font(fnt_ui_small);
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(110, 120, 150));
            if (_tr_scroll > 0) {
                ui_draw_scroll_more(_lx + 495, _list_y0 - 21, true, string(_tr_scroll) + " more above");
            }
            var _tr_below = _tr_cnt - (_tr_scroll + _tr_max_vis);
            if (_tr_below > 0) {
                ui_draw_scroll_more(_lx + 495, _list_y0 + _tr_max_vis * (_tr_row_h + _tr_row_gap) - 6, false, string(_tr_below) + " more below");
            }
            draw_set_halign(fa_left);

            // Right panel: trait slots (base 2 + bought + Crown)
            var _tr_slot_max = max_trait_slots();
            var _tr_slot_h  = 123;
            var _tr_slot_y0 = _list_y0;
            for (var _si2 = 0; _si2 < _tr_slot_max; _si2++) {
                var _sy      = _tr_slot_y0 + _si2 * (_tr_slot_h + 21);
                var _has_tr  = (_si2 < _tr_sel_cnt);

                draw_set_color(_has_tr ? make_color_rgb(24, 12, 44) : make_color_rgb(12, 14, 22));
                draw_rectangle(_rx, _sy, _rx + 735, _sy + _tr_slot_h, false);
                draw_set_color(_has_tr ? make_color_rgb(110, 55, 170) : make_color_rgb(35, 40, 60));
                draw_rectangle(_rx, _sy, _rx + 735, _sy + _tr_slot_h, true);

                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(70, 80, 105));
                draw_text(_rx + 14, _sy + 7, string(_si2 + 1));

                if (_has_tr) {
                    var _tr_name   = _gc_ov.traits_selected[_si2];
                    var _tr_struct = trait_get_by_name(_tr_name);
                    if (_tr_struct != undefined) {
                        ui_draw_trait_icon(_rx + 40, _sy + 28, 68, _tr_struct);
                    }
                    draw_set_font(fnt_ui);
                    draw_set_color(make_color_rgb(190, 130, 255));
                    draw_text(_rx + 124, _sy + 24, _tr_name);
                    if (_tr_struct != undefined) {
                        draw_set_font(fnt_ui_small);
                        draw_set_color(make_color_rgb(130, 95, 180));
                        draw_text_ext(_rx + 124, _sy + 62, _tr_struct.description, -1, 596);
                    }
                } else {
                    // Empty-slot placeholder badge.
                    draw_set_color(make_color_rgb(16, 18, 28));
                    draw_rectangle(_rx + 40, _sy + 28, _rx + 108, _sy + 96, false);
                    draw_set_color(make_color_rgb(48, 40, 70));
                    draw_rectangle(_rx + 40, _sy + 28, _rx + 108, _sy + 96, true);
                    draw_set_font(fnt_ui);
                    draw_set_color(make_color_rgb(45, 50, 70));
                    draw_text(_rx + 124, _sy + 48, "---  empty slot  ---");
                }
            }

            // --- Description box: y=900-990 ---
            var _desc_x = 60;
            var _desc_w = 1800;
            draw_set_color(make_color_rgb(10, 13, 26));
            draw_rectangle(_desc_x, 900, _desc_x + _desc_w, 990, false);
            draw_set_color(make_color_rgb(60, 38, 92));
            draw_rectangle(_desc_x, 900, _desc_x + _desc_w, 990, true);

            draw_set_halign(fa_left);
            if (_tr_cnt > 0 && _gc_ov.traits_cursor < _tr_cnt) {
                var _dte = _tr_all[_gc_ov.traits_cursor];
                var _dtr = _dte.tr;
                draw_set_alpha(_dte.unlocked ? 1.0 : 0.4);
                ui_draw_trait_icon(_desc_x + 13, 913, 64, _dtr);
                draw_set_alpha(1.0);
                draw_set_font(fnt_ui);
                draw_set_color(_dte.unlocked ? make_color_rgb(200, 155, 255) : make_color_rgb(125, 112, 78));
                draw_text(_desc_x + 90, 911, _dtr.name + (_dte.unlocked ? "" : "  [LOCKED - see Vex]"));
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(155, 130, 210));
                draw_text_ext(_desc_x + 90, 942, _dtr.description, -1, _desc_w - 105);
            } else {
                draw_set_font(fnt_ui_small);
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(80, 70, 115));
                draw_text(_desc_x + _desc_w / 2, 933, "No traits available yet. Complete runs to unlock more.");
                draw_set_halign(fa_left);
            }

            // --- Counter / flash bar: y=998-1043 ---
            draw_set_color(_gc_ov.loadout_full_timer > 0 ? make_color_rgb(40, 10, 10) : make_color_rgb(18, 10, 36));
            draw_rectangle(_desc_x, 998, _desc_x + _desc_w, 1043, false);
            draw_set_color(_gc_ov.loadout_full_timer > 0 ? make_color_rgb(155, 40, 40) : make_color_rgb(90, 50, 140));
            draw_rectangle(_desc_x, 998, _desc_x + _desc_w, 1043, true);

            draw_set_font(fnt_ui_small);
            draw_set_halign(fa_center);
            if (_gc_ov.loadout_full_timer > 0) {
                draw_set_color(make_color_rgb(255, 100, 100));
                draw_text(GUI_CX, 1010, "Max " + string(_tr_slot_max) + " traits - remove one before adding another.");
            } else {
                // Live respec cost preview (50g per previously-equipped trait dropped)
                var _pcost = trait_respec_cost(_gc_ov.traits_selected);
                var _all_empty = true;
                for (var _pti = 0; _pti < array_length(global.player_traits); _pti++) {
                    if (global.player_traits[_pti] != "") { _all_empty = false; break; }
                }
                var _cost_hint = "";
                if (_pcost > 0) {
                    _cost_hint = "  *  Respec cost: " + string(_pcost) + "g";
                } else if (_all_empty) {
                    _cost_hint = "  *  First assignment free";
                }
                draw_set_color(make_color_rgb(170, 120, 255));
                draw_text(GUI_CX, 1010, string(_tr_sel_cnt) + " / " + string(_tr_slot_max) + " traits selected" + _cost_hint + "   (confirm on Abilities tab)");
            }

            // --- Controls hint: y=1050 ---
            draw_set_color(make_color_rgb(65, 75, 100));
            if (input_device() != 2) ui_draw_key_legend(GUI_CX, 1050, "W/S: Navigate   Q/E: Switch Tab   Enter: Toggle Trait   Esc: Cancel");
            draw_set_halign(fa_left);

        // =====================================================================
        // COMPANION TAB (equip-only: pick the active pet, or None)
        // =====================================================================
        } else {
            var _eqp = [];
            for (var _cpi = 0; _cpi < pet_count(); _cpi++) {
                if (!global.pet_roster[_cpi].is_egg) array_push(_eqp, _cpi);
            }
            var _crows = array_length(_eqp) + 1;   // pets + a "No companion" row
            var _ccur  = clamp(_gc_ov.loadout_cursor, 0, _crows - 1);

            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(150, 210, 160));
            draw_text(_lx, 60, "YOUR CREATURES  (" + string(array_length(_eqp)) + ")");
            // Touch: header clears the 90px COMPANION tab (see abilities tab note).
            if (input_device() == 2) {
                draw_set_font(fnt_ui_small);
                draw_text(1460, 66, "ACTIVE");
                draw_set_font(fnt_ui);
            } else {
                draw_text(_rx, 60, "COMPANION");
            }

            var _crh = 78;
            for (var _ri = 0; _ri < _crows; _ri++) {
                var _ry      = _list_y0 + _ri * _crh;
                var _sel     = (_ri == _ccur);
                var _is_none = (_ri >= array_length(_eqp));
                var _ridx    = _is_none ? -1 : _eqp[_ri];
                var _active  = (global.active_pet == _ridx);

                draw_set_color(_sel ? make_color_rgb(28, 44, 34) : make_color_rgb(18, 22, 30));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + _crh - 10, false);
                draw_set_color(_sel ? make_color_rgb(90, 180, 120) : make_color_rgb(40, 50, 62));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + _crh - 10, true);

                // Equipped companion: steady bright-green double frame + left accent
                // bar. Steady (not pulsing) so it can't be mistaken for the cursor.
                if (_active) {
                    draw_set_color(make_color_rgb(120, 230, 150));
                    draw_rectangle(_lx, _ry, _lx + 660, _ry + _crh - 10, true);
                    draw_rectangle(_lx + 1, _ry + 1, _lx + 659, _ry + _crh - 11, true);
                    draw_rectangle(_lx, _ry, _lx + 6, _ry + _crh - 10, false);
                }

                // Icon box (creature sprite shrunk to fit); blank for the "None" row.
                // Inset clear of the row border AND the active companion's 6px left
                // accent bar (M 07-17: the box hugged/bled into the border) - 16px
                // left, 8px top/bottom margins inside the 68px row box.
                var _ibs  = _crh - 26;
                var _ibx0 = _lx + 16, _iby0 = _ry + 8, _ibx1 = _ibx0 + _ibs, _iby1 = _iby0 + _ibs;
                draw_set_color(make_color_rgb(14, 18, 22));
                draw_rectangle(_ibx0, _iby0, _ibx1, _iby1, false);
                draw_set_color(_sel ? make_color_rgb(80, 150, 100) : make_color_rgb(40, 50, 60));
                draw_rectangle(_ibx0, _iby0, _ibx1, _iby1, true);

                var _ctx = _ibx1 + 14;
                if (_is_none) {
                    draw_set_font(fnt_ui);
                    draw_set_color(make_color_rgb(170, 176, 190));
                    draw_text(_ctx, _ry + 24, "No companion");
                    if (_active) {
                        draw_set_halign(fa_right);
                        draw_set_font(fnt_ui_small);
                        draw_set_color(make_color_rgb(120, 230, 150));
                        draw_text(_lx + 660 - 16, _ry + 28, "ACTIVE");
                        draw_set_halign(fa_left);
                    }
                } else {
                    var _cp   = global.pet_roster[_ridx];
                    var _cisp = pet_sprite(_cp, "s");
                    if (_cisp >= 0) {
                        var _cisc = min((_ibs - 10) / max(1, sprite_get_width(_cisp)), (_ibs - 8) / max(1, sprite_get_height(_cisp)));
                        draw_sprite_ext(_cisp, pet_anim_frame(_cisp), (_ibx0 + _ibx1) / 2, _iby1 - 5, _cisc, _cisc, 0, c_white, 1);
                    }
                    // Line 1: name (green when equipped) + stage on the right.
                    draw_set_font(fnt_ui);
                    draw_set_color(_active ? make_color_rgb(150, 235, 170) : make_color_rgb(220, 226, 238));
                    draw_text(_ctx, _ry + 10, _cp.name);
                    draw_set_halign(fa_right);
                    draw_set_font(fnt_ui_small);
                    draw_set_color(make_color_rgb(150, 200, 140));
                    draw_text(_lx + 660 - 16, _ry + 14, pet_stage_name(_cp.stage));
                    // Line 2 right edge: ACTIVE tag for the equipped companion.
                    if (_active) {
                        draw_set_color(make_color_rgb(120, 230, 150));
                        draw_text(_lx + 660 - 16, _ry + 42, "ACTIVE");
                    }
                    draw_set_halign(fa_left);
                    // Line 2: species + archetype + tags, muted. Truncated against the
                    // right-aligned ACTIVE tag - a long species + [CORRUPTING x/3] ran
                    // into it (M 07-09 screenshot).
                    draw_set_font(fnt_ui_small);
                    draw_set_color(make_color_rgb(150, 160, 185));
                    var _cl2 = "(" + pet_species_get(_cp.species).name + ")   " + pet_archetype_name(_cp.archetype) + pet_injury_tag(_cp) + pet_corruption_tag(_cp);
                    var _cl2_max = (_lx + 660 - 16) - _ctx - (_active ? string_width("ACTIVE") + 18 : 0);
                    draw_text(_ctx, _ry + 42, ui_truncate(_cl2, _cl2_max));
                }
            }

            // Right: framed companion detail card - a portrait box + header band +
            // GRANTS box + egg-gift chip, so nothing floats or overlaps.
            var _cx0 = _rx, _cx1 = 1836, _cy0 = _list_y0, _cy1 = 900;
            if (_ccur < array_length(_eqp)) {
                var _hp = global.pet_roster[_eqp[_ccur]];

                // Card frame.
                draw_set_color(make_color_rgb(18, 20, 30));
                draw_rectangle(_cx0, _cy0, _cx1, _cy1, false);
                draw_set_color(make_color_rgb(70, 100, 84));
                draw_rectangle(_cx0, _cy0, _cx1, _cy1, true);

                var _ipad = 24;
                // Portrait box (left within card); fit art by BOTH width and height.
                var _px0 = _cx0 + _ipad, _py0 = _cy0 + _ipad, _px1 = _px0 + 200, _py1 = _py0 + 200;
                draw_set_color(make_color_rgb(24, 27, 38));
                draw_rectangle(_px0, _py0, _px1, _py1, false);
                draw_set_color(make_color_rgb(60, 70, 92));
                draw_rectangle(_px0, _py0, _px1, _py1, true);
                var _hsp = pet_sprite(_hp, "s");
                if (_hsp >= 0) {
                    var _fw = (_px1 - _px0) - 26, _fh = (_py1 - _py0) - 22;
                    var _hsc = min(_fw / max(1, sprite_get_width(_hsp)), _fh / max(1, sprite_get_height(_hsp)));
                    // Awakened aura: pulsing archetype-tinted halo behind the portrait (Stage 4).
                    var _haura = pet_aura_color(_hp);
                    if (_haura >= 0) {
                        var _hap = 0.20 + 0.10 * sin(current_time / 340);
                        gpu_set_blendmode(bm_add);
                        draw_sprite_ext(_hsp, pet_anim_frame(_hsp), (_px0 + _px1) / 2, _py1 - 9, _hsc * 1.08, _hsc * 1.08, 0, _haura, _hap);
                        gpu_set_blendmode(bm_normal);
                    }
                    draw_sprite_ext(_hsp, pet_anim_frame(_hsp), (_px0 + _px1) / 2, _py1 - 11, _hsc, _hsc, 0, c_white, 1);
                    // Corruption dressing (07-09 art track): flicker / dark aura + motes.
                    ui_draw_pet_corruption_fx(_hp, _hsp, pet_anim_frame(_hsp),
                        (_px0 + _px1) / 2, _py1 - 11, _hsc, _hsc,
                        (_px0 + _px1) / 2, (_py0 + _py1) / 2 + 15);
                }

                // Header band (right of portrait): name + stage/archetype + egg chip.
                var _tx = _px1 + 28;
                var _active_here = (global.active_pet == _eqp[_ccur]);
                draw_set_font(fnt_ui); draw_set_color(c_white);
                draw_text(_tx, _py0 + 6, _hp.name + (_active_here ? "   (active)" : ""));
                draw_set_font(fnt_ui_small); draw_set_color(make_color_rgb(190, 160, 240));
                draw_text(_tx, _py0 + 54, pet_stage_name(_hp.stage) + "  -  " + pet_archetype_name(_hp.archetype));
                var _egl = pet_egg_label(_hp);
                if (_egl != "") {
                    var _chtxt = "Egg gift: " + _egl;
                    var _chy = _py0 + 96, _chw = 26 + string_width(_chtxt);
                    draw_set_color(make_color_rgb(40, 36, 22));
                    draw_rectangle(_tx, _chy, _tx + _chw, _chy + 36, false);
                    draw_set_color(make_color_rgb(150, 130, 70));
                    draw_rectangle(_tx, _chy, _tx + _chw, _chy + 36, true);
                    draw_set_color(make_color_rgb(222, 200, 140));
                    draw_text(_tx + 13, _chy + 7, _chtxt);
                }

                // GRANTS box (below portrait, full card width).
                var _gx0 = _cx0 + _ipad, _gx1 = _cx1 - _ipad, _gy0 = _py1 + 26;
                var _ceff = pet_effect_text(_hp);
                if (_ceff == "") _ceff = "No passive yet - it grows into its gifts.";
                // The egg gift is part of what it grants - spell its effect out here;
                // the header chip alone names it without saying what it does.
                if (_egl != "") {
                    var _ceg = pet_egg_type_get(_hp.egg_type);
                    if (_ceg != undefined) _ceff += "\n" + _egl + " - " + _ceg.desc;
                }
                // Corruption state belongs in the card too (M 07-09: it only showed as
                // a name-row tag). Spell out what the state DOES - the +15%/run is a
                // permanent multiplier on the passive above (pet_corruption_mult).
                var _ccst = pet_corr_state(_hp);
                if (_ccst == "pushing") {
                    _ceff += "\nCorrupting " + string(pet_corr_runs(_hp)) + "/3 - each pushed run adds +15% to its passive, permanently; while it pushes YOU pay -20% max HP and -10% damage.";
                } else if (_ccst == "fulfilled") {
                    _ceff += "\nFULLY CORRUPTED - its passive is 45% stronger, forever" + ((_hp.archetype == PET_ARCH_BOON) ? ", plus a grand boon: extra gold and loot find on top." : ".");
                } else if (_ccst == "cured") {
                    _ceff += "\nPurged of corruption - the +" + string(pet_corr_runs(_hp) * 15) + "% it had already earned is kept.";
                }
                // The Awakened splash pick (Stage-4 gift) is a grant as well - it was
                // invisible here and on the detail popup once chosen (M 07-09).
                var _cspl = pet_splash_text(_hp);
                if (_cspl != "") _ceff += "\n" + _cspl;
                draw_set_font(fnt_ui);
                var _ew = (_gx1 - _gx0) - 28;
                var _eh = string_height_ext(_ceff, 30, _ew);
                var _gy1 = _gy0 + 46 + _eh + 18;
                draw_set_color(make_color_rgb(20, 30, 24));
                draw_rectangle(_gx0, _gy0, _gx1, _gy1, false);
                draw_set_color(make_color_rgb(64, 110, 80));
                draw_rectangle(_gx0, _gy0, _gx1, _gy1, true);
                draw_set_font(fnt_ui_small); draw_set_color(make_color_rgb(120, 200, 140));
                draw_text(_gx0 + 14, _gy0 + 12, "GRANTS");
                draw_set_font(fnt_ui); draw_set_color(make_color_rgb(210, 230, 214));
                draw_text_ext(_gx0 + 14, _gy0 + 46, _ceff, 30, _ew);

                // STANCE box (expression #3): Warriors/Guardians only - the behavioral
                // dial for its combat turn, cycled with [B] right here on this tab.
                var _hst = pet_stance(_hp);
                if (_hst != "") {
                    var _sty0 = _gy1 + 20;
                    // Size the box to the MEASURED wrapped description - the fixed
                    // 112px cap let long stance text (guarded, 4 lines) run past the
                    // bottom border (M 07-09 screenshot). Label width measured in the
                    // font it draws in (fnt_ui).
                    draw_set_font(fnt_ui);
                    var _hst_lbl_w = string_width(pet_stance_label(_hst));
                    draw_set_font(fnt_ui_small);
                    var _hst_dsc_x = _gx0 + 14 + _hst_lbl_w + 24;
                    var _hst_dsc_w = (_gx1 - _gx0) - 52 - _hst_lbl_w;
                    var _hst_dsc_h = string_height_ext(pet_stance_desc(_hst), 26, _hst_dsc_w);
                    var _sty1 = min(_cy1 - 54, _sty0 + max(112, 52 + _hst_dsc_h + 14));
                    draw_set_color(make_color_rgb(26, 24, 36));
                    draw_rectangle(_gx0, _sty0, _gx1, _sty1, false);
                    draw_set_color(make_color_rgb(110, 96, 150));
                    draw_rectangle(_gx0, _sty0, _gx1, _sty1, true);
                    draw_set_font(fnt_ui_small); draw_set_color(make_color_rgb(170, 150, 220));
                    draw_text(_gx0 + 14, _sty0 + 12, (input_device() == 1) ? "STANCE   [RT] change" : "STANCE   [B] change");
                    draw_set_font(fnt_ui); draw_set_color(make_color_rgb(222, 214, 240));
                    draw_text(_gx0 + 14, _sty0 + 46, pet_stance_label(_hst));
                    draw_set_font(fnt_ui_small); draw_set_color(make_color_rgb(150, 150, 175));
                    draw_text_ext(_hst_dsc_x, _sty0 + 52, pet_stance_desc(_hst), 26, _hst_dsc_w);
                }

                // Footer hint inside the card.
                draw_set_font(fnt_ui_small); draw_set_color(make_color_rgb(150, 160, 190));
                draw_text(_cx0 + _ipad, _cy1 - 42, (input_device() == 2) ? "Hold for full kit & details" : "[Tab] full kit & details");
            } else {
                draw_set_color(make_color_rgb(18, 20, 30));
                draw_rectangle(_cx0, _cy0, _cx1, _cy1, false);
                draw_set_color(make_color_rgb(50, 58, 72));
                draw_rectangle(_cx0, _cy0, _cx1, _cy1, true);
                draw_set_font(fnt_ui);
                draw_set_color(make_color_rgb(150, 156, 175));
                draw_text(_cx0 + 26, _cy0 + 26, "Dive alone - no companion this run.");
            }

            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(65, 75, 100));
            if (input_device() != 2) ui_draw_key_legend(GUI_CX, 1050, "W/S: Navigate   Q/E: Switch Tab   Tab: Details   Enter: Set Active   B: Stance   Esc: Cancel");
            draw_set_halign(fa_left);

            // Tab pet-kit detail popup over the Companion tab.
            if (_gc_ov.companion_detail_open && _ccur < array_length(_eqp)) {
                ui_draw_pet_detail(global.pet_roster[_eqp[_ccur]]);
            }
        }

        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
        draw_set_font(-1);
    }
}

ui_draw_stash_screen();
ui_draw_shop_screen();
ui_draw_trainer_screen();
ui_draw_trainer_statpick();
ui_draw_maren_screen();
ui_draw_sable_screen();
ui_draw_vael_screen();
ui_draw_bairc_screen();
ui_draw_bairc_intro();      // first-talk dialogue popup (before the station opens)
ui_draw_bairc_lore();       // queued one-time lore fragment, over the garden (design Â§10)
ui_draw_bairc_capstone();   // raised-Adult capstone pick modal, over the Bairc screen
hatch_cutscene_draw();   // full-screen egg-hatch sequence, over the Bairc screen
ui_draw_journal();       // J-key Journal overlay (Phase 4a) - over hub content, under pause
ui_draw_tavern_board();  // Tavern Requests board (Phase 4b) - the quest action surface
ui_draw_knucklebones();  // Knucklebones dice game (expression #1) - over the board
ui_draw_character_menu();

// Comparison panel - drawn above all overlays
if (instance_exists(obj_game_controller)) {
    var _gc_cmp = instance_find(obj_game_controller, 0);
    if (_gc_cmp.comparison_open && _gc_cmp.comparison_item != undefined) {
        ui_draw_comparison_panel(_gc_cmp.comparison_item, _gc_cmp.comparison_equipped);
    }
}

// Trait unlock notification toast (renders above all other UI)
if (instance_exists(obj_game_controller)) {
    var _gc_toast = instance_find(obj_game_controller, 0);
    if (_gc_toast.trait_notif_timer > 0 && _gc_toast.trait_notif_msg != "") {
        var _t_alpha = min(1.0, _gc_toast.trait_notif_timer / 30.0);
        draw_set_alpha(_t_alpha);
        draw_set_color(make_color_rgb(12, 10, 24));
        draw_rectangle(390, 21, 1530, 78, false);
        draw_set_color(make_color_rgb(140, 88, 220));
        draw_rectangle(390, 21, 1530, 78, true);
        draw_set_font(fnt_ui);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(c_white);
        draw_text(GUI_CX, 50, _gc_toast.trait_notif_msg);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
        draw_set_font(-1);
    }
}

// Tier-up heart VFX (blue Acquaintance..Companion, red Lover) for hub-list deepens.
// Only when no NPC screen is open - an open screen draws its own hearts via the actor
// (drawing in both places would double-advance the shared particle list).
var _hb_gc = instance_exists(obj_game_controller) ? instance_find(obj_game_controller, 0) : noone;
var _hb_screen = false;
if (_hb_gc != noone) {
    _hb_screen = (_hb_gc.shop_open != -1)
        || (variable_instance_exists(_hb_gc, "trainer_open") && _hb_gc.trainer_open)
        || (variable_instance_exists(_hb_gc, "maren_open")   && _hb_gc.maren_open)
        || (variable_instance_exists(_hb_gc, "sable_open")   && _hb_gc.sable_open)
        || (variable_instance_exists(_hb_gc, "vael_open")    && _hb_gc.vael_open)
        || (variable_instance_exists(_hb_gc, "bairc_open")   && _hb_gc.bairc_open);
}
if (!_hb_screen) {
    npc_hearts_consume_pending(1605, 600);   // near the NPC portrait panel
    npc_hearts_draw();
}

// Audio settings overlay - drawn on top of everything when open
if (variable_global_exists("settings_open") && global.settings_open) {
    ui_draw_settings_overlay();
}

// Pause / Esc menu (no-ops unless open; hides itself while Settings is showing)
ui_draw_pause_menu();

// Item-sacrifice picker modal - topmost (Vex stat/trait trade)
ui_draw_item_picker();
ui_draw_gift_popup();    // gift reaction + bond delta/progress (Phase 4b) - over the picker layer

// Onboarding coach-mark - drawn last so it sits on top of the hub (see SYSTEMS_ONBOARDING.md).
ui_draw_tutorial_tip();

// =============================================================================
// ENDING SEQUENCE (WIN_STATE_SPEC.md) - drawn over the whole hub. Stage layout
// mirrors the Step block: intro, speakers, absence (conditional), dawn,
// epilogue, credits (shared page), finale.
// =============================================================================
if (ending_active) {
    var _en      = array_length(ending_speakers);
    var _eabs    = (ending_absent > 0) ? 1 : 0;
    var _st_abs  = 1 + _en;            // meaningful only when _eabs == 1
    var _st_dawn = 1 + _en + _eabs;
    var _st_epi  = _st_dawn + 1;
    var _st_cred = _st_epi + 1;

    draw_set_valign(fa_top);

    if (ending_stage == _st_cred) {
        ui_draw_credits_page();
    } else if (ending_stage == _st_dawn) {
        // Dawn: no dark scrim - the hub itself brightens under a warm wash.
        draw_set_alpha(0.42);
        draw_rectangle_color(GUI_XL, 0, GUI_XR, GUI_H,
            make_color_rgb(255, 196, 120), make_color_rgb(255, 196, 120),
            make_color_rgb(40, 28, 30),    make_color_rgb(40, 28, 30), false);
        draw_set_alpha(0.16);
        draw_set_color(c_white);
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
        draw_set_alpha(1.0);
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_title);
        draw_set_color(make_color_rgb(255, 226, 160));
        draw_text(960, 330, "DAWN");
        draw_set_font(fnt_ui);
        draw_set_color(c_white);
        draw_text(960, 470, "For the first time in living memory,");
        draw_text(960, 514, "dawn breaks over Ironwake.");
    } else {
        // Dark stage backdrop for every text/portrait beat
        draw_set_alpha(0.88);
        draw_set_color(make_color_rgb(6, 7, 12));
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
        draw_set_alpha(1.0);
        draw_set_halign(fa_center);

        if (ending_stage == 0) {
            draw_set_font(fnt_ui_title);
            draw_set_color(make_color_rgb(130, 195, 255));
            draw_text(960, 300, "THE GATE STANDS QUIET");
            draw_set_font(fnt_ui);
            draw_set_color(c_white);
            draw_text(960, 450, "Three dungeons. Five Awakenings each.");
            draw_text(960, 494, "The keepers of Ironwake have gathered.");
        } else if (ending_stage >= 1 && ending_stage < 1 + _en) {
            var _sp = ending_speakers[ending_stage - 1];
            var _port = -1;
            switch (_sp.id) {
                case "dorn":  _port = Blacksmith_1__Dark_Gritty_; break;
                case "sable": _port = Alcehmist_2__Flirty_;       break;
                case "maren": _port = Runesmith_3__Facewrap_;     break;
                case "vex":   _port = Trainer_2__Sullen_;         break;
                case "petra": _port = Merchant_7__Voluptuous_;    break;
                case "vael":  _port = Aesthete_2__Gothic_;        break;
                case "bairc": _port = asset_get_index("spr_npc_bairc_portrait"); break;
            }
            if (_port != -1 && sprite_exists(_port)) {
                ui_draw_sprite_cover(_port, 0, 730, 150, 460, 460, 1.0);
                ui_draw_gothic_frame(730, 150, 1190, 610, 15);
            }
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(228, 190, 90));
            draw_text(960, 660, npc_display_name(_sp.id) + "  -  " + affinity_tier_name_for(_sp.tier));
            draw_set_color(c_white);
            draw_text_ext(960, 724, ending_farewell_line(_sp.id, _sp.tier), 40, 1240);
        } else if (_eabs == 1 && ending_stage == _st_abs) {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(170, 150, 170));
            draw_text(960, 420, "Not every face is here.");
            draw_text(960, 480, "The town remembers that, too.");
        } else if (ending_stage == _st_epi) {
            draw_set_font(fnt_ui_title);
            draw_set_color(make_color_rgb(228, 190, 90));
            draw_text(960, 170, "IRONWAKE STANDS");
            // Deepest bond + companion, both guarded - epilogue never crashes on
            // a bondless / petless save.
            var _deep_name = "", _deep_tier = 0;
            var _eids2 = affinity_npc_ids();
            for (var _di = 0; _di < array_length(_eids2); _di++) {
                var _dt = affinity_tier(_eids2[_di]);
                if (_dt > _deep_tier) { _deep_tier = _dt; _deep_name = npc_display_name(_eids2[_di]); }
            }
            var _pet_line = "None hatched";
            var _ep = pet_active();
            if (is_struct(_ep) && variable_struct_exists(_ep, "name")) {
                _pet_line = _ep.name + "  (" + pet_stage_name(_ep.stage) + ")";
            }
            var _epi_rows = [
                ["Runs taken",        string(global.run_count)],
                ["Full clears",       string(variable_global_exists("dungeon_clears_total") ? global.dungeon_clears_total : 0)],
                ["Monsters felled",   string(global.total_kills)],
                ["Deepest bond",      (_deep_tier > 0) ? (_deep_name + "  (" + affinity_tier_name_for(_deep_tier) + ")") : "A town of strangers"],
                ["Companion",         _pet_line],
            ];
            var _ey = 350;
            for (var _ri = 0; _ri < array_length(_epi_rows); _ri++) {
                draw_set_font(fnt_ui);
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(150, 160, 185));
                draw_text(920, _ey, _epi_rows[_ri][0]);
                draw_set_halign(fa_left);
                draw_set_color(c_white);
                draw_text(1000, _ey, _epi_rows[_ri][1]);
                _ey += 62;
            }
            draw_set_halign(fa_center);
        } else {
            // Finale
            draw_set_font(fnt_ui_title);
            draw_set_color(make_color_rgb(130, 195, 255));
            draw_text(960, 330, "THE AWAKENINGS CONTINUE");
            draw_set_font(fnt_ui);
            draw_set_color(c_white);
            draw_text(960, 480, "Ironwake stands. The gate stays open - for you.");
        }

        ui_draw_gothic_frame(30, 30, 1890, 1050, 30);
    }

    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(100, 110, 135));
    ui_draw_key_legend(960, 1002, "Enter: Continue");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// Touch (8d): action-chip bar, then the Back/menu chip + key pump - always LAST (topmost).
ui_draw_touch_chips();
ui_draw_touch_back();
// Touch (M 07-17): NPC-screen long-press action menu - drawn last so it's modal-topmost.
ui_draw_touch_action_menu();
ui_draw_touch_gamepad();   // on-screen d-pad in the left gutter (M 07-17)
