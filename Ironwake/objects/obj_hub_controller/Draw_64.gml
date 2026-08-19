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

// 1c. Drifting embers - MOVED to the foreground pass near the end of this
// event (M 07-31: "drift over even the menus" - they were invisible behind
// the panels). Update + draw both happen there.

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
draw_set_font(ui_font(fnt_ui));
draw_set_halign(fa_center);
draw_set_valign(fa_top);
var _flav_scale = 1.275;                            // 22px Centaur -> ~28px (25% smaller than the 1.7x pass)
var _flav_w     = 700 / _flav_scale;                // ~700px on-screen wrap width (unscaled)
var _flav_sep   = 26;                               // line spacing scales with the text (~33px on-screen)
var _flav_h     = string_height_ext(hub_flavor, _flav_sep, _flav_w) * _flav_scale;
var _flav_y;
// M 08-13 phone shot: the lore line ran BEHIND the STASH/JOURNAL chip bar.
// input_device() flips with the last input event, so a stray mouse/pad event
// on a phone dropped this into the DESKTOP band (y948-1070), which overlaps
// the chips (y1005+). Gate by the BUILD platform - on touch devices the
// chip-aware band always applies, whatever the last input was.
if (touch_platform() || input_device() == 2) {
    // Touch (M 07-17): bottom-anchor the lore just above the chip bar (top
    // ~y1005) and let it grow UPWARD. 08-11 (M screenshot): the old top limit
    // of 888 predates the CAROUSEL, whose stage panel is opaque down to y945 -
    // a wrapped 2-line message hid its first line behind the panel. The band
    // is now clamped BELOW the panel; anything taller shrinks to fit it.
    var _flav_bot = 1000, _flav_top_min = 951;
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
draw_set_font(ui_font(fnt_ui));
// Gold reads in an antique-gold tint to match the coin economy; the rest stay white.
draw_set_color(make_color_rgb(228, 190, 90));
draw_text(_px, _py,               "Gold:       " + string(_display_gold));
draw_set_color(c_white);
draw_text(_px, _py + _line_h,     "Runs:       " + string(_display_runs));
draw_text(_px, _py + _line_h * 2, "Best Floor: " + string(_display_best_floor));
draw_text(_px, _py + _line_h * 3, "Kills:      " + string(_display_kills));
// The Debtor's ledger (08-11 origin): one line in the free band just below the
// info panel (panel ends y315; the Last Run panel starts y420). Red once IN
// COLLECTIONS - a quarter of all earned gold is garnished at the source.
if (debt_active()) {
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(debt_in_collections() ? make_color_rgb(230, 90, 80) : make_color_rgb(200, 130, 90));
    // (touch: the hero card sits at y322 there - the debt line drops under it, clear of the pad)
    draw_text((input_device() == 2) ? 120 : 30, (input_device() == 2) ? 694 : 324, "DEBT OWED: " + string(global.debt_gold) + "g"
        + (debt_in_collections() ? "   [IN COLLECTIONS - 25% garnished]" : "   (10% due after each run)"));
}
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
    draw_set_font(ui_font(fnt_ui));
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
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(255, 210, 60));
        draw_text(_lx, _ly + 120, "PERMANENT POINTS EARNED: " + string(global.last_run_perm_points));
        // Dismiss hint shifts down
        draw_set_color(c_gray);
        draw_text_outline(_lx, _ly + 156, "Esc to dismiss");
    } else {
        // Dismiss hint
        draw_set_font(ui_font(fnt_ui_small));
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
// TOUCH (M 08-18 phone shot "mobile layout needs resizing"): the on-screen d-pad lives
// bottom-left and sat ON the card. The left column has a dead band between the stats
// box (ends y315) and the card, so on touch the card moves up into it and a little right.
if (input_device() == 2) { _cp_x = 120; _cp_y = 322; }

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
draw_set_font(ui_font(fnt_ui));
draw_set_color(c_white);
draw_text(_cpx, _cpy, global.player_name);
draw_set_font(ui_font(fnt_ui_small));
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
draw_set_font(ui_font(fnt_ui));
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
// 5. NPC SHOWCASE - center column (x=630..1290, y=105..945)
// CAROUSEL (default; SYSTEMS_HUB_CAROUSEL.md, M design-locked 07-30): ONE NPC
// on stage - the animated actor sprite at a readable size with name/bond/role
// beneath - plus a JUMP STRIP of face-chips (tap = jump straight to that NPC;
// hot-dots keep off-stage badges visible). The legacy stacked list survives
// below behind settings.ini [ui] hub_carousel=0 (Windows/HTML5 reversion -
// Android is always carousel). All carousel hit-tests live HERE beside their
// drawn rects (touch rule) and fire the SAME simulated keys the Step handlers
// already consume (touch_press) - one dispatch path, no drift.
// -----------------------------------------------------------------------------
if (hub_use_carousel) {
    var _cv_n     = array_length(npc_names);
    var _cv_focus = (selected_npc < _cv_n);              // false = gate button focused
    var _cv_idx   = _cv_focus ? selected_npc : carousel_last;
    var _cv_x1 = 630, _cv_x2 = 1290, _cv_y1 = 105, _cv_y2 = 945;
    var _cv_cx = (_cv_x1 + _cv_x2) / 2;
    var _cv_ids  = ["dorn", "sable", "maren", "vex", "petra", "vael", "bairc", ""];
    var _cv_lock = !npc_unlocked[_cv_idx];
    var _cv_aff  = affinity_npc_ids();

    // Taps fire only while the hub itself owns input: every overlay and hub
    // modal must swallow them (a tap on a shop's CLOSE must not also engage the
    // stage underneath - global.ui_overlay_latch holds the start-of-frame
    // blocked state and covers exactly that close-tap frame).
    var _cv_hit = !ui_input_blocked() && !global.ui_overlay_latch
        && !bond_dialog_open && !ending_active && !zoom_intro_open
        && !show_history
        && !(variable_instance_exists(id, "npc_upgrade_arm") && npc_upgrade_arm != "")
        && !(variable_instance_exists(id, "awaken_boost_open") && awaken_boost_open)
        && !(variable_global_exists("resume_pending") && global.resume_pending)
        && !(variable_global_exists("settings_open")  && global.settings_open)
        && !(variable_global_exists("pause_open")     && global.pause_open)
        && !(variable_global_exists("item_picker")    && global.item_picker.open)
        && !(variable_global_exists("gift_popup")     && global.gift_popup != undefined);
    if (instance_exists(obj_game_controller)
        && instance_find(obj_game_controller, 0).dungeon_select_open) _cv_hit = false;

    // Board turn-in count - shared by the stage banner and the strip hot-dot.
    var _cv_board_ready = 0;
    var _cv_bq = journal_quest_rows();
    for (var _cv_qi = 0; _cv_qi < array_length(_cv_bq); _cv_qi++)
        if (quest_is_complete(_cv_bq[_cv_qi])) _cv_board_ready++;

    // ---- stage panel ---- (M 08-13: more translucent so the campfire scene
    // reads through the box - sprites/icons keep full alpha, only the panel
    // glass thinned: shadow 0.40->0.20, fill 0.78->0.45.)
    draw_set_alpha(0.20);
    draw_set_color(c_black);
    draw_rectangle(_cv_x1 + 6, _cv_y1 + 6, _cv_x2 + 6, _cv_y2 + 6, false);
    draw_set_alpha(0.45);
    draw_set_color(make_color_rgb(20, 25, 40));
    draw_rectangle(_cv_x1, _cv_y1, _cv_x2, _cv_y2, false);
    draw_set_alpha(1.0);
    if (_cv_focus) ui_draw_gothic_frame(_cv_x1, _cv_y1, _cv_x2, _cv_y2, 10);
    draw_set_color(_cv_focus ? make_color_rgb(80, 160, 220) : make_color_rgb(45, 55, 75));
    draw_rectangle(_cv_x1, _cv_y1, _cv_x2, _cv_y2, true);
    draw_rectangle(_cv_x1, _cv_y1, _cv_x2, _cv_y1 + 4, false);   // accent strip

    // ---- stage art: animated idle actor, bottom-anchored at y540 / 400px tall.
    // Own frame state (carousel_frame) - never touches the NPC screens' shared
    // global.npc_actor, so an open screen's actor can't double-advance. ----
    if (carousel_prev != _cv_idx) { carousel_prev = _cv_idx; carousel_frame = 0; }
    carousel_frame += 0.105;   // ~6.3 fps, same cadence as the NPC-screen actor
    if (_cv_idx == 7) {
        // Tavern Requests: the posting board fills the stage box.
        var _cv_tb = asset_get_index("spr_tavern_board");
        if (_cv_tb >= 0 && sprite_exists(_cv_tb)) {
            ui_draw_sprite_cover(_cv_tb, 0, _cv_cx - 255, 150, 510, 390, 1.0);
        } else {
            draw_set_color(make_color_rgb(52, 36, 24));
            draw_rectangle(_cv_cx - 255, 150, _cv_cx + 255, 540, false);
            draw_set_color(make_color_rgb(30, 20, 13));
            draw_rectangle(_cv_cx - 237, 168, _cv_cx + 237, 522, true);
            draw_set_halign(fa_center); draw_set_valign(fa_middle);
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(make_color_rgb(226, 205, 160));
            draw_text(_cv_cx, 345, "Tavern Requests");
            draw_set_valign(fa_top); draw_set_font(-1);
        }
    } else {
        var _cv_spr = asset_get_index("spr_npc_" + _cv_ids[_cv_idx] + "_idle");
        if (_cv_spr >= 0 && sprite_exists(_cv_spr)) {
            var _cv_nf = sprite_get_number(_cv_spr);
            if (carousel_frame >= _cv_nf) carousel_frame -= _cv_nf;
            var _cv_sc = 400 / max(1, sprite_get_height(_cv_spr));
            draw_sprite_ext(_cv_spr, floor(carousel_frame) mod _cv_nf,
                _cv_cx, 540, _cv_sc, _cv_sc, 0, c_white, _cv_lock ? 0.35 : 1.0);
        } else if (_cv_idx < 6) {
            // Actor sprite missing: static portrait cover-crop fallback.
            var _cv_ports = [ Blacksmith_1__Dark_Gritty_, Alcehmist_2__Flirty_,
                Runesmith_3__Facewrap_, Trainer_2__Sullen_,
                Merchant_7__Voluptuous_, Aesthete_2__Gothic_ ];
            ui_draw_sprite_cover(_cv_ports[_cv_idx], 0, _cv_cx - 200, 140, 400, 400, 1.0);
        } else {
            // Bairc fallback: his profile art, head-anchored like the panel crop.
            var _cv_bf = asset_get_index("spr_npc_bairc_portrait");
            if (_cv_bf >= 0 && sprite_exists(_cv_bf))
                ui_draw_sprite_cover(_cv_bf, 0, _cv_cx - 200, 140, 400, 400, 1.0, 0);
        }
    }

    // ---- rotate arrows (72x140 - finger sized; they fire the same keys the
    // keyboard uses, so Step's nav/gate-focus logic is the single authority).
    // Touch fires on clean RELEASE (touch_tap_in) so starting a swipe on an
    // arrow can't also step the carousel; desktop mouse is press-fired. ----
    var _cv_ay1 = 300, _cv_ay2 = 440, _cv_amy = (_cv_ay1 + _cv_ay2) / 2;
    draw_set_alpha(0.55);
    draw_set_color(make_color_rgb(14, 18, 32));
    draw_rectangle(642,  _cv_ay1, 714,  _cv_ay2, false);
    draw_rectangle(1206, _cv_ay1, 1278, _cv_ay2, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(120, 170, 220));
    draw_triangle(700,  _cv_ay1 + 40, 700,  _cv_ay2 - 40, 662,  _cv_amy, false);
    draw_triangle(1220, _cv_ay1 + 40, 1220, _cv_ay2 - 40, 1258, _cv_amy, false);
    var _cv_touch = (input_device() == 2);
    var _cv_al = _cv_touch ? touch_tap_in(642,  _cv_ay1, 714,  _cv_ay2)
                           : touch_tapped(642,  _cv_ay1, 714,  _cv_ay2);
    var _cv_ar = _cv_touch ? touch_tap_in(1206, _cv_ay1, 1278, _cv_ay2)
                           : touch_tapped(1206, _cv_ay1, 1278, _cv_ay2);
    if (_cv_hit && _cv_al) touch_press(vk_left);
    if (_cv_hit && _cv_ar) touch_press(vk_right);

    // ---- name - measured auto-fit so the longest ("Bairc the Creature
    // Keeper") can never cross the arrows or the panel border ----
    var _cv_name = npc_names[_cv_idx] + (_cv_lock ? "  [Locked]" : "");
    draw_set_font(fnt_ui_title);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    var _cv_ns = min(1, 600 / max(1, string_width(_cv_name)));
    draw_set_color(make_color_rgb(16, 24, 42));
    draw_text_transformed(_cv_cx + 2, 558, _cv_name, _cv_ns, _cv_ns, 0);
    draw_set_color(_cv_lock ? c_gray : c_white);
    draw_text_transformed(_cv_cx, 556, _cv_name, _cv_ns, _cv_ns, 0);

    // ---- bond: tier hearts + line (NPCs 0..6 are affinity-wired; the board
    // row shows its turn-in banner instead) ----
    var _cv_line_y = 646;
    draw_set_font(ui_font(fnt_ui_small));
    if (_cv_idx < array_length(_cv_aff)) {
        var _cv_id   = _cv_aff[_cv_idx];
        var _cv_tier = affinity_tier(_cv_id);
        var _cv_rdy  = affinity_gate_ready(_cv_id);
        // 4 heart slots on their own row between the name and the Bond line,
        // centred over it: filled = tier (red row at Lover, blue below; empty =
        // dark). Drawn procedurally - the heart sprite is unreadable this small.
        var _cv_hcol = (_cv_tier >= 4) ? make_color_rgb(235, 70, 95)
                                       : make_color_rgb(95, 155, 240);
        for (var _cv_h = 0; _cv_h < 4; _cv_h++) {
            var _cv_hx = _cv_cx - 57 + _cv_h * 38;
            if (_cv_h < _cv_tier) {
                ui_draw_heart(_cv_hx + 1, 622 + 1, 10, make_color_rgb(10, 12, 20), 0.6);   // drop shadow
                ui_draw_heart(_cv_hx, 622, 10, _cv_hcol, 1.0);
            } else {
                ui_draw_heart(_cv_hx, 622, 10, make_color_rgb(70, 76, 92), 0.55);
            }
        }
        if (_cv_rdy) {
            draw_set_color(c_aqua);
            var _cv_bt = "Bond ready - visit to deepen";
            if (input_device() == 0)      _cv_bt = "[B] Deepen bond - ready";
            else if (input_device() == 1) _cv_bt = "[R3] Deepen bond - ready";
            draw_text(_cv_cx, _cv_line_y, _cv_bt);
        } else {
            draw_set_color(make_color_rgb(210, 190, 130));
            draw_text(_cv_cx, _cv_line_y, "Bond: " + affinity_tier_name_for(_cv_tier));
            if (_cv_tier < 4) {
                // slim progress bar toward the next gate
                var _cv_bx = _cv_cx - 160, _cv_by = _cv_line_y + 30;
                draw_set_color(make_color_rgb(40, 44, 56));
                draw_rectangle(_cv_bx, _cv_by, _cv_bx + 320, _cv_by + 8, false);
                draw_set_color(make_color_rgb(210, 190, 130));
                draw_rectangle(_cv_bx, _cv_by, _cv_bx + 320 * affinity_progress_frac(_cv_id), _cv_by + 8, false);
                draw_set_color(make_color_rgb(90, 96, 110));
                draw_rectangle(_cv_bx, _cv_by, _cv_bx + 320, _cv_by + 8, true);
            }
        }
        // ---- STATION RANK chip (NPC PROGRESSION, M 08-15) ----
        // Pinned in the card's TOP-RIGHT corner (M: "in the corner where there
        // is available space") - above the arrows, clear of the actor art and
        // every text band at any font size. Rank details are HOVER-ONLY (M: the
        // extra text was meant as a mouse-over); the tip rides above the card
        // via ui_draw_tab_tip(). [U] or a tap opens the checkout popup.
        if (!_cv_lock) {
        var _cv_rank = npc_rank(_cv_id);
        var _cv_sl   = "STATION";
        var _cv_slw  = string_width(_cv_sl);
        var _cv_sx1  = _cv_x2 - 22, _cv_sy0 = _cv_y1 + 22;
        var _cv_sx0  = _cv_sx1 - (_cv_slw + 24 + 2 * 20), _cv_sy1 = _cv_sy0 + 36;
        var _cv_smx  = device_mouse_x_to_gui(0), _cv_smy = device_mouse_y_to_gui(0);
        var _cv_shov = (_cv_smx >= _cv_sx0 && _cv_smx <= _cv_sx1 && _cv_smy >= _cv_sy0 && _cv_smy <= _cv_sy1);
        draw_set_alpha(_cv_shov ? 0.85 : 0.60);
        draw_set_color(make_color_rgb(14, 18, 32));
        draw_rectangle(_cv_sx0, _cv_sy0, _cv_sx1, _cv_sy1, false);
        draw_set_alpha(1.0);
        draw_set_color(_cv_shov ? make_color_rgb(230, 200, 120) : make_color_rgb(110, 96, 62));
        draw_rectangle(_cv_sx0, _cv_sy0, _cv_sx1, _cv_sy1, true);
        draw_set_halign(fa_left);
        draw_set_valign(fa_middle);
        draw_set_color(make_color_rgb(230, 200, 120));
        draw_text(_cv_sx0 + 12, (_cv_sy0 + _cv_sy1) / 2, _cv_sl);
        // 2 rank pips: filled gold diamond = owned, dark = still to buy.
        for (var _cv_si = 0; _cv_si < 2; _cv_si++) {
            var _cv_px = _cv_sx0 + 12 + _cv_slw + 12 + _cv_si * 20 + 8;
            var _cv_py = (_cv_sy0 + _cv_sy1) / 2;
            draw_set_color((_cv_si < _cv_rank) ? make_color_rgb(230, 200, 120) : make_color_rgb(70, 76, 92));
            draw_triangle(_cv_px, _cv_py - 8, _cv_px + 8, _cv_py, _cv_px, _cv_py + 8, false);
            draw_triangle(_cv_px, _cv_py - 8, _cv_px - 8, _cv_py, _cv_px, _cv_py + 8, false);
        }
        draw_set_valign(fa_top);
        draw_set_halign(fa_center);
        if (_cv_hit) {
            ui_tab_hover_stash(_cv_sx0, _cv_sy0, _cv_sx1, _cv_sy1,
                "STATION RANK " + string(_cv_rank) + " / 2", npc_rank_card_tip(_cv_id));
            // Tap = the [U] verb (touch + mouse path); the Step opens the checkout.
            if (_cv_rank < 2 && touch_tapped(_cv_sx0, _cv_sy0, _cv_sx1, _cv_sy1))
                input_inject("npcup:open");
        }
        }
    } else {
        if (_cv_board_ready > 0) {
            draw_set_color(make_color_rgb(120, 220, 140));
            draw_text(_cv_cx, _cv_line_y, string(_cv_board_ready) + " ready to turn in");
        } else {
            draw_set_color(make_color_rgb(150, 160, 185));
            draw_text(_cv_cx, _cv_line_y, "Postings from the townsfolk");
        }
    }

    // ---- role line (wrapped + measured so the hint below can never collide;
    // longest current description is 2 lines at 600px) ----
    draw_set_color(make_color_rgb(180, 190, 210));
    var _cv_role = _cv_lock ? "Not yet available." : npc_descriptions[_cv_idx];
    draw_text_ext(_cv_cx, 700, _cv_role, 27, 600);
    var _cv_hint_y = min(700 + string_height_ext(_cv_role, 27, 600) + 15, 792);

    // ---- nav hint ----
    draw_set_color(make_color_rgb(110, 120, 145));
    var _cv_hint = "Swipe or tap the arrows  -  tap the portrait to visit";
    if (input_device() == 0)      _cv_hint = "A/D to rotate  -  Enter to visit  -  S: Dungeon Gate";
    else if (input_device() == 1) _cv_hint = "D-Pad to rotate  -  A to visit  -  Down: Dungeon Gate";
    draw_text(_cv_cx, _cv_hint_y, _cv_hint);
    draw_set_font(-1);

    // ---- JUMP STRIP: one face-chip per NPC (66px = finger sized), tap to jump
    // straight there. Hot-dots keep off-stage badges visible: gold = bond gate
    // ready, green = board turn-ins waiting. ----
    var _cv_ch  = 66;
    var _cv_gap = 12;
    var _cv_sx  = _cv_cx - (_cv_n * _cv_ch + (_cv_n - 1) * _cv_gap) / 2;   // 8 chips = 612px
    var _cv_sy  = 822;
    // Trade-symbol icons, not portrait thumbnails (M 07-31): the 66px faces
    // were unreadable and duplicated the portrait already on screen.
    var _cv_chip_icons = [ spr_icon_npc_dorn, spr_icon_npc_sable,
        spr_icon_npc_maren, spr_icon_npc_vex,
        spr_icon_npc_petra, spr_icon_npc_vael,
        spr_icon_npc_bairc, spr_icon_npc_board ];
    for (var _cv_i = 0; _cv_i < _cv_n; _cv_i++) {
        var _cvx1 = _cv_sx + _cv_i * (_cv_ch + _cv_gap);
        var _cvx2 = _cvx1 + _cv_ch;
        var _cvy1 = _cv_sy, _cvy2 = _cv_sy + _cv_ch;
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(12, 14, 24));
        draw_rectangle(_cvx1, _cvy1, _cvx2, _cvy2, false);
        var _cv_ca = (_cv_i == _cv_idx) ? 1.0 : 0.62;   // on-stage chip brightest
        // 64px art into the chip with a 1px inset so the border stays clean.
        draw_sprite_stretched_ext(_cv_chip_icons[_cv_i], 0,
            _cvx1 + 1, _cvy1 + 1, _cv_ch - 2, _cv_ch - 2, c_white, _cv_ca);
        // Border - teal double-line for the on-stage NPC.
        var _cv_cur = (_cv_i == _cv_idx);
        draw_set_color(_cv_cur ? make_color_rgb(80, 160, 220) : make_color_rgb(45, 55, 75));
        draw_rectangle(_cvx1, _cvy1, _cvx2, _cvy2, true);
        if (_cv_cur) draw_rectangle(_cvx1 - 1, _cvy1 - 1, _cvx2 + 1, _cvy2 + 1, true);
        // Hot-dot badge (pulsing): bond gate ready / board turn-ins.
        var _cv_dot = 0;
        if (_cv_i < array_length(_cv_aff)) { if (affinity_gate_ready(_cv_aff[_cv_i])) _cv_dot = 1; }
        else if (_cv_board_ready > 0) _cv_dot = 2;
        if (_cv_dot > 0) {
            draw_set_color(c_black);
            draw_circle(_cvx2 - 8, _cvy1 + 8, 9, false);
            draw_set_color((_cv_dot == 1) ? make_color_rgb(245, 195, 80) : make_color_rgb(120, 220, 140));
            draw_set_alpha(0.7 + 0.3 * sin(current_time / 300));
            draw_circle(_cvx2 - 8, _cvy1 + 8, 7, false);
            draw_set_alpha(1.0);
        }
        // Tap = jump straight to this NPC (press-fired; the strip sits below
        // the swipe zone so a swipe can never start here).
        if (_cv_hit && touch_tapped(_cvx1, _cvy1, _cvx2, _cvy2)) {
            selected_npc  = _cv_i;
            carousel_last = _cv_i;
            notification  = "";
        }
    }

    // ---- stage tap = visit (engage). Touch fires on clean RELEASE so a swipe
    // can't also open the screen; desktop click is press-fired. Sets the
    // selection first so the simulated Enter engages THIS NPC even when the
    // gate button held focus. ----
    var _cv_sgo = _cv_touch ? touch_tap_in(720, 120, 1200, 810)
                            : touch_tapped(720, 120, 1200, 810);
    if (_cv_hit && _cv_sgo) {
        selected_npc  = _cv_idx;
        carousel_last = _cv_idx;
        touch_press(vk_enter);
    }
    // Horizontal swipe anywhere on the stage rotates - arrives as Q/E via the
    // shared gesture classifier, consumed by input_tab_* in Step (touch-only
    // by construction: the classifier only arms on the touch device).
    if (_cv_hit) touch_swipe_tab(_cv_x1, _cv_y1, _cv_x2, 810);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);

} else {
// -----------------------------------------------------------------------------
// 5b. LEGACY NPC LIST - center (x=630, y=105, w=660, h=840); the pre-carousel
// stacked list, kept behind the [ui] hub_carousel=0 reversion flag.
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
    draw_set_font(ui_font(fnt_ui));
    draw_text(_nl_x + 21, _ry + 27, _name_str);
}
draw_set_font(-1);

draw_set_valign(fa_top);
} // end carousel / legacy list


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
draw_set_font(ui_font(fnt_ui));
draw_set_color(make_color_rgb(40, 60, 90));
draw_text(_ddx + 2, _ddy + 2, npc_names[selected_npc]);
draw_set_color(c_white);
draw_text(_ddx, _ddy, npc_names[selected_npc]);

// Brief description
draw_set_font(ui_font(fnt_ui_small));
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
    draw_set_font(ui_font(fnt_ui_small));
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
    draw_set_font(ui_font(fnt_ui));
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
    // Contain-fit (07-31, M): cover-crop was cutting hoods/heads - show the art whole.
    ui_draw_sprite_contain(_port_sprites[selected_npc], 0, _pp_x, _pp_y, _pp_w, _pp_h, portrait_fade_alpha);
} else if (selected_npc == 6) {
    // NPC beyond the authored portrait set (Bairc): use his hub sprite if imported,
    // else a captioned placeholder so the panel never falls through to the gate art.
    var _np_spr = asset_get_index("spr_npc_bairc_portrait");   // M-supplied profile art
    if (_np_spr < 0) _np_spr = asset_get_index("spr_npc_bairc_idle");
    if (_np_spr >= 0) {
        // Contain-fit (07-31): whole portrait visible, no crop bias games needed.
        ui_draw_sprite_contain(_np_spr, 0, _pp_x, _pp_y, _pp_w, _pp_h, portrait_fade_alpha);
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
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(c_white);
    draw_text(_pp_x + _pp_w / 2, _pp_y + _pp_h - 81, _prev_title);
    draw_set_font(ui_font(fnt_ui_small));
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
draw_set_font(ui_font(fnt_ui_small));
if (_eb_sel) {
    draw_set_color(c_white);
    draw_text(_eb_x + _eb_w / 2, _eb_y + 78, (input_device() == 2) ? "Tap to confirm" : "Press Enter or Space to confirm");
} else {
    draw_set_color(make_color_rgb(100, 140, 130));
    // Carousel mode: down hops focus to this button (no scrolling list); touch
    // just taps it directly (the Step hit-test fires regardless of focus).
    var _eb_hint = "Scroll down to select";
    if (hub_use_carousel) {
        if (input_device() == 2)      _eb_hint = "Tap to confirm";
        else if (input_device() == 1) _eb_hint = "D-Pad Down, then A";
        else                          _eb_hint = "Press S, then Enter";
    }
    draw_text(_eb_x + _eb_w / 2, _eb_y + 78, _eb_hint);
}
draw_set_font(-1);


// -----------------------------------------------------------------------------
// 8. FOOTER INSTRUCTIONS - y=1073
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_font(ui_font(fnt_ui_small));
draw_set_color(c_gray);
// Chunk 7b: on a gamepad the footer shows the pad chips instead (same layout;
// see __input_pad_hotkey_map in scr_input for the M-approved assignments).
// Chunk 8d: on TOUCH the footer is replaced by the tappable action-chip bar
// (ui_draw_touch_chips, drawn at the end of this event) - no text here.
if (input_device() != 2) {
    var _hub_pad_ui = (input_device() == 1);
    // The nav prefix is shared with the Journal-badge overdraw below so the
    // measured segment position can never drift from the drawn text. Keyboard
    // wording follows the layout: the carousel rotates on A/D (W/S = gate).
    var _foot_nav = _hub_pad_ui
        ? "D-Pad: Navigate   A: Interact   "
        : (hub_use_carousel ? "A/D: Rotate   W/S: Gate   Enter / Space: Interact   "
                            : "W/S: Navigate   Enter / Space: Interact   ");
    var _foot_txt = _foot_nav + (_hub_pad_ui
        ? "LT: Journal (Quests / Codex / Bestiary)   Y: History   RT: Stash   L3: Upgrade   Select: Settings"
        : "J: Journal (Quests / Codex / Bestiary)   H: History   T: Stash   P: Upgrade   O: Settings");
    draw_text_outline(GUI_CX, 1073, _foot_txt);
    // Unread-Journal cue: overdraw the "J: Journal" segment in flashing gold (M 2026-07-04:
    // the old floating pulse dot read as disjoint clutter). Alpha pulse over the same
    // pixels; same font/valign as the footer so it registers exactly.
    if (journal_any_badge()) {
        var _jseg_pre = _foot_nav;
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
        var _unlocked_asc = dungeon_max_ascendance(_dkey);   // A6+ frontier post-win

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
        draw_set_font(ui_font(_name_font));
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
            draw_set_font(ui_font(fnt_ui_small));
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
            draw_set_font(ui_font(fnt_ui));
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
            }
            // CLICK paths on EVERY device (M 08-19: "I cannot click Enter/confirm, the
            // cycling arrows or the awakening Q/E - the entire game must be mouse-
            // clickable"): these were gated to touch. touch_tapped reads the mouse, so
            // the same zones serve desktop clicks - arrows / side cards cycle, the
            // Q / E boxes step awakening, the green bar confirms.
            if      (touch_tapped(444, GUI_CY - 90, 600, GUI_CY + 114))   touch_press(ord("A"));
            else if (touch_tapped(1300, GUI_CY - 90, 1482, GUI_CY + 114)) touch_press(ord("D"));
            else if (touch_tapped(_cx + 21, _asc_y, _cx + 105, _asc_y + 66))            touch_press(ord("Q"));
            else if (touch_tapped(_cx + _cw - 105, _asc_y, _cx + _cw - 21, _asc_y + 66)) touch_press(ord("E"));
            else if (touch_tapped(_cx + 21, _cy + _ch - 87, _cx + _cw - 21, _cy + _ch - 21)) touch_press(vk_enter);

            // Tier description - below the selector box (computed, matches combat)
            var _sel_a   = _gc_ds.dungeon_select_asc;
            var _sel_txt = (_sel_a == 0)
                ? "Standard difficulty. No modifiers. Full effects listed on the right."
                : "Enemies: +" + string(round((awaken_hp_mult(_sel_a) - 1) * 100)) + "% HP, +"
                    + string(round((awaken_dmg_mult(_sel_a) - 1) * 100))
                    + "% damage. Full effects listed on the right.";
            draw_set_halign(fa_left);
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(140, 150, 185));
            draw_text_ext(_body_x, _asc_y + 84, _sel_txt, 30, _body_w);

            // Confirm bar
            var _conf_y = _cy + _ch - 87;
            draw_set_color(make_color_rgb(18, 50, 22));
            draw_rectangle(_cx + 21, _conf_y, _cx + _cw - 21, _conf_y + 66, false);
            draw_set_color(make_color_rgb(45, 140, 60));
            draw_rectangle(_cx + 21, _conf_y, _cx + _cw - 21, _conf_y + 66, true);
            draw_set_halign(fa_center);
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(c_white);
            draw_text(_cx + _cw / 2, _conf_y + 20, (input_device() == 2)
                ? "EMBARK  -  Choose Loadout"
                : "[ Enter ]  Confirm & Choose Loadout");

        } else {
            // Side cards: text below art
            draw_set_halign(fa_center);
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(60, 68, 92));
            draw_text(_cx + _cw / 2, _cy + 219, "A" + string(_unlocked_asc) + " max");
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(55, 60, 82));
            draw_text_ext(_cx + 18, _cy + 252, _dung_desc[_di], 27, _cw - 36);
            // Click/tap a SIDE card to cycle to it (08-19 mouse pass).
            if (touch_tapped(_cx, _cy, _cx + _cw, _cy + _ch)) touch_press(_is_left ? ord("A") : ord("D"));
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
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(_fx_tcol);
    draw_text(_fx_x1 + (_fx_x2 - _fx_x1) / 2, _fxy, "AWAKENING EFFECTS");
    _fxy += 42;
    draw_set_font(ui_font(fnt_ui_small));
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
    var _fx_unl = dungeon_max_ascendance(_fx_dkey);   // A6+ frontier post-win
    // Post-win the ladder is endless: show a 6-row window that keeps the
    // selected tier visible (pre-win this is exactly the old A0-A5 table).
    var _ft_lo = clamp(_fx_a - 3, 0, max(0, _fx_unl - 5));
    for (var _fti = 0; _fti <= 5; _fti++) {
        var _ft = _ft_lo + _fti;
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
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(75, 82, 110));
    draw_set_valign(fa_bottom);
    ui_draw_key_legend(GUI_CX, 1073, "A / D: Cycle Dungeon     Q / E: Awakening     Enter: Confirm     Esc: Back");
    // -------------------------------------------------------------------------
    // THE DESCENT banner (SYSTEMS_ENDLESS.md §3) - post-win only. Rects MUST
    // match the Step_0 hit-tests: banner (330,972)-(1250,1050), severity chip
    // (1270,972)-(1590,1050). [V] arms it; [G]/tap cycles severity while armed.
    // -------------------------------------------------------------------------
    if (variable_global_exists("ironwake_stands") && global.ironwake_stands) {
        var _dsb_on  = variable_global_exists("descent_pending") && global.descent_pending;
        var _dsb_hc  = variable_global_exists("descent_hardcore") ? global.descent_hardcore : 0;
        var _dsb_best = variable_global_exists("descent_best") ? global.descent_best : 0;
        if (!variable_instance_exists(id, "descent_pulse")) descent_pulse = 0;
        descent_pulse += 0.08;
        var _dsb_p = 0.5 + 0.5 * sin(descent_pulse);
        draw_set_color(_dsb_on ? make_color_rgb(38, 20, 44) : make_color_rgb(14, 15, 24));
        draw_rectangle(330, 972, 1250, 1050, false);
        draw_set_color(_dsb_on ? merge_color(make_color_rgb(200, 130, 255), c_white, _dsb_p * 0.5) : make_color_rgb(70, 60, 96));
        draw_rectangle(330, 972, 1250, 1050, true);
        draw_set_halign(fa_left);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(_dsb_on ? make_color_rgb(230, 200, 255) : make_color_rgb(150, 140, 175));
        draw_text(354, 981, _dsb_on ? "THE DESCENT  -  ARMED" : "THE DESCENT" + ((input_device() == 2) ? "" : "   [V]"));
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(140, 135, 165));
        draw_text(354, 1017, _dsb_on
            ? "Enter begins the fall: endless floors, random dungeons, Depthforged spoils."
            : ("Endless floors beyond the win.  Deepest: " + ((_dsb_best > 0) ? ("Floor " + string(_dsb_best)) : "never entered")));
        // Severity chip (only meaningful while armed).
        var _dsb_hc_names = ["STANDARD", "HARDCORE", "MERCILESS"];
        var _dsb_hc_descs = ["death keeps worn gear", "death takes 1 worn item", "each worn item 50/50"];
        draw_set_color(_dsb_on ? ((_dsb_hc > 0) ? make_color_rgb(46, 14, 14) : make_color_rgb(20, 22, 30)) : make_color_rgb(14, 15, 24));
        draw_rectangle(1270, 972, 1590, 1050, false);
        draw_set_color(_dsb_on ? ((_dsb_hc > 0) ? make_color_rgb(220, 80, 80) : make_color_rgb(80, 84, 104)) : make_color_rgb(50, 52, 66));
        draw_rectangle(1270, 972, 1590, 1050, true);
        draw_set_halign(fa_center);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(_dsb_on ? ((_dsb_hc > 0) ? make_color_rgb(255, 140, 140) : make_color_rgb(170, 175, 195)) : make_color_rgb(90, 94, 112));
        draw_text(1430, 981, _dsb_hc_names[_dsb_hc] + ((_dsb_on && input_device() != 2) ? "   [G]" : ""));
        draw_text(1430, 1017, _dsb_hc_descs[_dsb_hc]);
        draw_set_halign(fa_left);
    }

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
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(200, 170, 230));
        draw_text(GUI_CX, 105, "\"" + _rh_ep + "\"");
    }

    // Column headers
    draw_set_halign(fa_left);
    draw_set_font(ui_font(fnt_ui_small));
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
        draw_set_font(ui_font(fnt_ui));
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
    draw_set_font(ui_font(fnt_ui_small));
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
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(make_color_rgb(255, 215, 60));
        draw_text(GUI_CX, _ban_y + 21, "! PERMANENT POINTS AVAILABLE !");
        draw_set_font(ui_font(fnt_ui_small));
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
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(c_white);
        var _perm_pts_str = (global.pending_perm_points == 1) ? "1 point" : string(global.pending_perm_points) + " points";
        draw_text(GUI_CX, 159, "Allocate " + _perm_pts_str + " into permanent stats");
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(150, 160, 180));
        draw_text(GUI_CX, 195, "These bonuses carry into every future run.");
        draw_set_halign(fa_left);

        var _perm_stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        var _perm_stat_descs = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"];
        var _perm_glob_keys  = ["perm_str_bonus", "perm_dex_bonus", "perm_con_bonus",
                                "perm_int_bonus", "perm_wis_bonus", "perm_cha_bonus"];

        draw_set_font(ui_font(fnt_ui));
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
        draw_set_font(ui_font(fnt_ui_small));
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
// 12. ITEM CODEX OVERLAY - moved to scr_ui/obj_game_controller 07-28 so it
// also opens mid-run from the Journal. State: gc codex_* vars.
// -----------------------------------------------------------------------------
ui_draw_item_codex();


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
        var _loadout_max = 5;   // class pass 08-13: base 5, EA 6th
        for (var _ea = 0; _ea < array_length(_gc_ov.traits_selected); _ea++) {
            if (_gc_ov.traits_selected[_ea] == "Expanded Arsenal") { _loadout_max = 6; break; }
        }
        // REQUIRED count (class pass 08-13): mirrors the Step gate - a fresh
        // character owns only the 4 starters, so readiness is judged against
        // what you can actually slot, never a cap you cannot reach yet.
        var _ov_req = _loadout_max;
        {
            var _ov_owned = 0;
            for (var _lu = 0; _lu < array_length(_ov_pool); _lu++)
                if (ability_is_unlocked(_ov_pool[_lu].name)) _ov_owned++;
            _ov_req = min(_loadout_max, max(4, _ov_owned));
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
        draw_set_font(ui_font(fnt_ui));
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
        draw_set_font(ui_font(fnt_ui_small));
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
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(make_color_rgb(130, 150, 200));
            draw_text(_lx, 60, "CLASS ABILITIES");
            // Touch: the 90px tabs cover (_rx, 60) - the header moves to the free
            // strip right of the COMPANION tab (M 07-08: "all overlap with the
            // companion tab"). Same treatment on all three tabs.
            if (input_device() == 2) {
                draw_set_font(ui_font(fnt_ui_small));
                draw_text(1460, 66, "YOUR LOADOUT");
                draw_set_font(ui_font(fnt_ui));
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
                    draw_set_font(ui_font(fnt_ui));
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
                draw_set_font(ui_font(fnt_ui));
                draw_set_color(!_ab_unlocked ? make_color_rgb(125, 112, 78)
                            : (_in_sel  ? make_color_rgb(90, 210, 110)
                            : (_is_cur ? c_white
                                       : make_color_rgb(170, 180, 205))));
                draw_text(_row_textx, _ry + 6, _ab.name + _name_suffix);

                // Energy cost tag - right-aligned inside the row
                draw_set_font(ui_font(fnt_ui_small));
                draw_set_halign(fa_right);
                draw_set_color(c_yellow);
                draw_text(_lx + 972, _ry + 6, "[" + string(_ab.energy_cost) + " AP]");
                // Talent web: unspent point = pulsing gold call-to-action;
                // woven nodes = quiet count on the row's lower right.
                var _web_pend  = ability_web_mp_pending(_ab.name);
                var _web_picks = array_length(ability_web_picks(_ab.name));
                if (_web_pend > 0) {
                    draw_set_alpha(0.6 + 0.4 * (0.5 + 0.5 * sin(current_time / 250)));
                    draw_set_color(make_color_rgb(255, 205, 90));
                    draw_text(_lx + 972, _ry + 39, "WEB PT!  [M]");   // kept short - shares line 2 with the row description
                    draw_set_alpha(1.0);
                } else if (_web_picks > 0) {
                    draw_set_color(make_color_rgb(200, 170, 100));
                    draw_text(_lx + 972, _ry + 39, "Web " + string(_web_picks) + "/" + string(ability_web_cap()));
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
            draw_set_font(ui_font(fnt_ui_small));
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

                draw_set_font(ui_font(fnt_ui));
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
                    draw_set_font(ui_font(fnt_ui));
                    draw_set_color(make_color_rgb(110, 215, 130));
                    draw_text(_slot_textx, _sy + 12, _gc_ov.loadout_selected[_si2]);
                    for (var _ai2 = 0; _ai2 < _ov_pool_sz; _ai2++) {
                        if (_ov_pool[_ai2].name == _gc_ov.loadout_selected[_si2]) {
                            // Energy cost in the slot header
                            draw_set_font(ui_font(fnt_ui_small));
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
                    draw_set_font(ui_font(fnt_ui));
                    draw_set_color(make_color_rgb(45, 50, 70));
                    draw_text(_rx + 48, _sy + 39, "---  empty  ---");
                }
            }

            // --- "Press Tab" hint (clearly above the description box - ample room here) ---
            draw_set_halign(fa_center);
            draw_set_valign(fa_top);
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(120, 205, 240));
            draw_text_outline(960, 843, ui_hint("[ Tab ]  -  full breakdown of the highlighted ability", "Hold a row for its full breakdown"));
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
                draw_set_font(ui_font(fnt_ui));
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
                draw_set_font(ui_font(fnt_ui_small));
                draw_set_color(make_color_rgb(172, 187, 217));
                draw_text_ext(_desc_x + 24, 927, ability_describe(_dab), -1, _desc_w - 48);
            } else {
                draw_set_font(ui_font(fnt_ui_small));
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(80, 195, 100));
                draw_text(_desc_x + _desc_w / 2, 921, "All " + string(_ov_req) + " abilities chosen - " + ui_hint("press Enter on", "tap") + " the confirm bar below to start your run.");
                draw_set_halign(fa_left);
            }

            // --- Confirm / counter bar: y=998-1043 ---
            // Cursor==pool_sz is the active confirm position; bar highlights when reached.
            var _conf_cur = (_gc_ov.loadout_cursor == _ov_pool_sz);
            var _conf_sel = (_conf_cur && _ov_sel_cnt >= _ov_req);
            // #6: the gold-shortfall flash reddens the bar like the loadout-full flash.
            var _bar_red = _gc_ov.loadout_full_timer > 0
                || (variable_instance_exists(_gc_ov, "loadout_gold_timer") && _gc_ov.loadout_gold_timer > 0);
            // M 07-28: the thin pulsing frame alone still read as "just another
            // row" - when the cursor is ON the bar the fill itself now breathes
            // and an outer glow halo makes focus unmistakable at a glance.
            var _cf_pulse = 0.5 + 0.5 * sin(current_time / 200);
            draw_set_color(_bar_red                        ? make_color_rgb(40, 10, 10)
                         : (_conf_sel                      ? merge_color(make_color_rgb(16, 70, 25),  make_color_rgb(45, 160, 70),  _cf_pulse * 0.65)
                         : (_conf_cur                      ? merge_color(make_color_rgb(45, 38, 14),  make_color_rgb(110, 92, 32),  _cf_pulse * 0.65)
                         : (_ov_sel_cnt >= _ov_req         ? make_color_rgb(14, 48, 18)
                                                           : make_color_rgb(14, 16, 28)))));
            draw_rectangle(_desc_x, 998, _desc_x + _desc_w, 1043, false);
            draw_set_color(_bar_red                        ? make_color_rgb(155, 40, 40)
                         : (_conf_sel                      ? make_color_rgb(50, 185, 75)
                         : (_conf_cur                      ? make_color_rgb(220, 175, 70)
                         : (_ov_sel_cnt >= _ov_req         ? make_color_rgb(35, 95, 45)
                                                           : make_color_rgb(35, 40, 65)))));
            draw_rectangle(_desc_x, 998, _desc_x + _desc_w, 1043, true);
            // Focused confirm bar: thick pulsing frame + a soft glow halo that
            // radiates outward. Green when the loadout is complete (ready to
            // launch), gold while picks are still missing.
            if (_conf_cur) {
                var _cf_gcol = _conf_sel ? make_color_rgb(90, 235, 120) : make_color_rgb(255, 205, 90);
                for (var _cf_gi = 1; _cf_gi <= 8; _cf_gi++) {
                    draw_set_alpha((0.28 + 0.22 * _cf_pulse) * (1 - _cf_gi / 9));
                    draw_set_color(_cf_gcol);
                    draw_rectangle(_desc_x - _cf_gi, 998 - _cf_gi, _desc_x + _desc_w + _cf_gi, 1043 + _cf_gi, true);
                }
                draw_set_alpha(0.65 + 0.35 * _cf_pulse);
                draw_set_color(_conf_sel ? make_color_rgb(120, 235, 140) : make_color_rgb(255, 205, 90));
                draw_rectangle(_desc_x - 1, 997, _desc_x + _desc_w + 1, 1044, true);
                draw_rectangle(_desc_x - 2, 996, _desc_x + _desc_w + 2, 1045, true);
                draw_set_alpha(1.0);
            }

            draw_set_font(ui_font(fnt_ui_small));
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
                draw_text_outline(GUI_CX, 1010, string(_ov_sel_cnt) + " / " + string(_ov_req) + " selected   |   " + ui_hint("[ Space ]  Confirm and Enter Dungeon", "Tap again to Enter the Dungeon"));
            } else if (_ov_sel_cnt >= _ov_req) {
                draw_set_color(make_color_rgb(80, 175, 100));
                draw_text(GUI_CX, 1010, string(_ov_sel_cnt) + " / " + string(_ov_req) + " selected   |   " + ui_hint("Scroll down to [ Enter ] to confirm", "Tap this bar to confirm"));
            } else {
                draw_set_color(make_color_rgb(160, 170, 200));
                draw_text(GUI_CX, 1010, string(_ov_sel_cnt) + " / " + string(_ov_req) + " selected");
            }

            // --- Controls hint: y=1050 ---
            draw_set_color(make_color_rgb(65, 75, 100));
            if (input_device() != 2) ui_draw_key_legend(GUI_CX, 1050, "W/S: Navigate   Q/E: Switch Tab   Enter: Toggle   Tab: Details   M: Talent Web   Space: Confirm   Esc: Cancel");
            draw_set_halign(fa_left);

            // --- Tab ability-detail popup, drawn over the loadout (P7) ---
            if (_gc_ov.ability_detail_open && _gc_ov.loadout_cursor < _ov_pool_sz) {
                ui_draw_ability_detail(_ov_pool[_gc_ov.loadout_cursor], (input_device() == 1) ? "Y" : "Tab", _gc_ov.ability_detail_scroll);
            }

            // --- Talent-web view (SYSTEMS_TALENT_WEBS.md), over everything on
            //     this tab. Hit-testing for touch/mouse lives HERE in Draw (the
            //     chip-bar rule): tap a node to select it, tap the selected node
            //     again to weave it; CLOSE button bottom-center. ---
            if (_gc_ov.web_view_open) {
                var _wv_ab2 = undefined;
                for (var _wvj = 0; _wvj < _ov_pool_sz; _wvj++) {
                    if (_ov_pool[_wvj].name == _gc_ov.web_view_ability) { _wv_ab2 = _ov_pool[_wvj]; break; }
                }
                if (_wv_ab2 != undefined) {
                    draw_set_alpha(0.8); draw_set_color(c_black);
                    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
                    draw_set_alpha(1.0);
                    var _wx0 = 460, _wy0 = 130, _wx1 = 1460, _wy1 = 985;
                    draw_set_color(make_color_rgb(22, 22, 36));
                    draw_rectangle(_wx0, _wy0, _wx1, _wy1, false);
                    draw_set_color(make_color_rgb(255, 205, 90));
                    draw_rectangle(_wx0, _wy0, _wx1, _wy1, true);

                    var _wv_name   = _wv_ab2.name;
                    var _wv_nodes  = ability_web_nodes(_wv_ab2);
                    var _wv_order  = ["p1", "p2", "pk", "t1", "t2", "tk"];
                    var _wv_staged = _gc_ov.web_view_staged;
                    var _wv_stn    = array_length(_wv_staged);
                    var _wv_pend   = ability_web_mp_pending(_wv_name);
                    var _wv_avail  = _wv_pend - _wv_stn;          // points left AFTER staged assignments
                    var _wv_spent  = array_length(ability_web_picks(_wv_name));
                    var _wv_next   = ability_web_next_threshold(_wv_name);

                    // Header
                    draw_set_halign(fa_center);
                    draw_set_font(fnt_ui_title);
                    draw_set_color(make_color_rgb(255, 215, 120));
                    draw_text(GUI_CX, _wy0 + 26, "TALENT WEB - " + _wv_name);
                    // Subtitle sits BELOW the measured title height (07-29: the fixed
                    // +72 offset ran into the title font's descenders on long names).
                    var _wv_title_h = string_height("TALENT WEB - " + _wv_name);
                    draw_set_font(ui_font(fnt_ui_small));
                    draw_set_color(make_color_rgb(170, 175, 195));
                    var _wv_hdr = string(_wv_avail) + " point" + ((_wv_avail == 1) ? "" : "s") + " to spend"
                        + ((_wv_stn > 0) ? (" (" + string(_wv_stn) + " staged)") : "") + "   -   "
                        + string(_wv_spent) + "/" + string(ability_web_cap()) + " woven   -   "
                        + string(ability_casts(_wv_name)) + " lifetime casts"
                        + ((_wv_next > 0) ? ("  (next point at " + string(_wv_next) + ")") : "");
                    draw_text(GUI_CX, _wy0 + 26 + max(46, _wv_title_h) + 6, _wv_hdr);

                    // Node geometry: root top-center, POWER branch left column,
                    // TWIST branch right column, mid-tier cross-link. 68px+ tap
                    // discs (touch rule: >=48px targets).
                    var _wv_rx = GUI_CX,        _wv_ry = _wy0 + 175;
                    var _wv_px = GUI_CX - 220,  _wv_tx = GUI_CX + 220;
                    var _wv_yy = [_wy0 + 300, _wy0 + 430, _wy0 + 575];   // tiers 1/2/3
                    var _wv_nx = [_wv_px, _wv_px, _wv_px, _wv_tx, _wv_tx, _wv_tx];
                    var _wv_ny = [_wv_yy[0], _wv_yy[1], _wv_yy[2], _wv_yy[0], _wv_yy[1], _wv_yy[2]];

                    // Edges first (under the discs). Lit gold when both ends are
                    // woven (the root always counts as woven).
                    var _wv_edges = [[-1, 0], [0, 1], [1, 2], [-1, 3], [3, 4], [4, 5], [1, 4]];
                    for (var _we = 0; _we < array_length(_wv_edges); _we++) {
                        var _we_a = _wv_edges[_we][0], _we_b = _wv_edges[_we][1];
                        var _we_ax = (_we_a < 0) ? _wv_rx : _wv_nx[_we_a];
                        var _we_ay = (_we_a < 0) ? _wv_ry : _wv_ny[_we_a];
                        var _we_on = ((_we_a < 0) || ability_web_owned_or_staged(_wv_name, _wv_order[_we_a], _wv_staged))
                                  && ability_web_owned_or_staged(_wv_name, _wv_order[_we_b], _wv_staged);
                        draw_set_color(_we_on ? make_color_rgb(255, 205, 90) : make_color_rgb(55, 58, 82));
                        draw_line_width(_we_ax, _we_ay, _wv_nx[_we_b], _wv_ny[_we_b], _we_on ? 4 : 2);
                    }

                    // Root disc: the ability itself, tinted by its school.
                    draw_set_color(school_color(ability_school(_wv_ab2)));
                    draw_circle(_wv_rx, _wv_ry, 30, false);
                    draw_set_color(make_color_rgb(255, 205, 90));
                    draw_circle(_wv_rx, _wv_ry, 30, true);
                    draw_set_font(ui_font(fnt_ui_small));
                    draw_set_color(make_color_rgb(200, 205, 225));
                    draw_text(_wv_rx, _wv_ry - 62, "ROOT");

                    // Branch headers
                    draw_set_color(make_color_rgb(200, 130, 90));
                    draw_text(_wv_px, _wy0 + 240, "POWER");
                    draw_set_color(make_color_rgb(120, 170, 220));
                    draw_text(_wv_tx, _wy0 + 240, "TWIST");

                    // Nodes
                    var _wv_pulse = 0.5 + 0.5 * sin(current_time / 250);
                    for (var _wn = 0; _wn < 6; _wn++) {
                        var _n_node  = _wv_nodes[_wn];
                        var _n_id    = _wv_order[_wn];
                        var _n_x     = _wv_nx[_wn], _n_y = _wv_ny[_wn];
                        var _n_r     = (_n_node.tier == 3) ? 40 : 34;
                        var _n_owned  = ability_web_owned(_wv_name, _n_id);
                        var _n_staged = ability_web_staged_has(_wv_staged, _n_id);
                        var _n_lit    = _n_owned || _n_staged;
                        var _n_reach  = ability_web_reachable_staged(_wv_name, _n_id, _wv_staged);
                        var _n_buy    = (!_n_lit && _n_reach && _wv_avail > 0 && (_wv_spent + _wv_stn) < ability_web_cap());
                        var _n_sel    = (_gc_ov.web_view_cursor == _wn);
                        // Fill
                        if (_n_lit)        draw_set_color(make_color_rgb(72, 58, 26));
                        else if (_n_reach) draw_set_color(make_color_rgb(34, 34, 52));
                        else               draw_set_color(make_color_rgb(24, 24, 36));
                        draw_circle(_n_x, _n_y, _n_r, false);
                        // Ring: owned = solid gold, staged = pulsing pale gold (not yet permanent)
                        if (_n_owned)      { draw_set_color(make_color_rgb(255, 205, 90)); }
                        else if (_n_staged){ draw_set_alpha(0.55 + 0.45 * _wv_pulse); draw_set_color(make_color_rgb(255, 240, 190)); }
                        else if (_n_buy)   { draw_set_alpha(0.45 + 0.55 * _wv_pulse); draw_set_color(make_color_rgb(255, 205, 90)); }
                        else if (_n_reach) { draw_set_color(make_color_rgb(110, 115, 145)); }
                        else               { draw_set_color(make_color_rgb(55, 58, 82)); }
                        draw_circle(_n_x, _n_y, _n_r, true);
                        if (_n_node.tier == 3) draw_circle(_n_x, _n_y, _n_r - 5, true);   // double ring = keystone
                        draw_set_alpha(1.0);
                        // Selection ring
                        if (_n_sel) { draw_set_color(c_white); draw_circle(_n_x, _n_y, _n_r + 6, true); }
                        // Center glyph: woven/staged star / open plus / locked dash
                        draw_set_font(ui_font(fnt_ui));
                        draw_set_color(_n_lit ? make_color_rgb(255, 225, 150) : (_n_reach ? make_color_rgb(150, 155, 180) : make_color_rgb(70, 74, 100)));
                        draw_text(_n_x, _n_y - 12, _n_lit ? "*" : (_n_reach ? "+" : "-"));
                        // Title + label, outward of each column. MEASURED against
                        // the panel edge (UI-collision rule) - a label that would
                        // overflow is omitted here; the detail strip always
                        // carries the full text for the selected node.
                        draw_set_font(ui_font(fnt_ui_small));
                        var _n_tcol  = _n_lit ? make_color_rgb(255, 215, 120) : (_n_reach ? make_color_rgb(185, 190, 210) : make_color_rgb(95, 100, 125));
                        var _n_tx    = (_wn < 3) ? (_n_x - _n_r - 16) : (_n_x + _n_r + 16);
                        var _n_avail = (_wn < 3) ? (_n_tx - (_wx0 + 16)) : ((_wx1 - 16) - _n_tx);
                        draw_set_halign((_wn < 3) ? fa_right : fa_left);
                        draw_set_color(_n_tcol);
                        if (string_width(_n_node.title) <= _n_avail) draw_text(_n_tx, _n_y - 24, _n_node.title);
                        draw_set_color(make_color_rgb(120, 125, 150));
                        if (string_width(_n_node.label) <= _n_avail) draw_text(_n_tx, _n_y + 2, _n_node.label);
                        draw_set_halign(fa_center);
                    }

                    // Detail strip: the selected node spelled out (fixed strip, no
                    // floating tooltip - collision-proof by construction).
                    var _ds_y0 = _wy1 - 210, _ds_y1 = _wy1 - 118;
                    draw_set_color(make_color_rgb(28, 28, 44));
                    draw_rectangle(_wx0 + 24, _ds_y0, _wx1 - 24, _ds_y1, false);
                    draw_set_color(make_color_rgb(60, 62, 90));
                    draw_rectangle(_wx0 + 24, _ds_y0, _wx1 - 24, _ds_y1, true);
                    if (_gc_ov.web_view_cursor < 6) {
                        var _ds_node   = _wv_nodes[_gc_ov.web_view_cursor];
                        var _ds_id     = _wv_order[_gc_ov.web_view_cursor];
                        var _ds_owned  = ability_web_owned(_wv_name, _ds_id);
                        var _ds_staged = ability_web_staged_has(_wv_staged, _ds_id);
                        var _ds_reach  = ability_web_reachable_staged(_wv_name, _ds_id, _wv_staged);
                        var _ds_status;
                        if (_ds_owned) {
                            _ds_status = "WOVEN - permanent.";
                            if (variable_struct_exists(_ds_node, "schools")) {
                                var _ds_wf = ability_web_pick_full(_wv_name, _ds_id);
                                if (ability_web_id_param(_ds_wf) != "") _ds_status = "WOVEN - permanent (" + school_label(ability_web_id_param(_ds_wf)) + ").";
                            }
                        }
                        else if (_ds_staged) {
                            _ds_status = "STAGED - select again to remove. SAVE & CLOSE makes it permanent.";
                            if (variable_struct_exists(_ds_node, "schools")) {
                                var _ds_sf = ability_web_staged_full(_wv_staged, _ds_id);
                                _ds_status = "STAGED: " + school_label(ability_web_id_param(_ds_sf))
                                    + " - select again to cycle schools (past the last removes). SAVE & CLOSE makes it permanent.";
                            }
                        }
                        else if (!_ds_reach)                               _ds_status = "Locked - weave an adjoining node first.";
                        else if (_wv_spent + _wv_stn >= ability_web_cap()) _ds_status = "Web cap reached (" + string(ability_web_cap()) + " of 6) - its shape is set.";
                        else if (_wv_avail <= 0)                           _ds_status = (_wv_next > 0) ? ("No point to spend - next at " + string(_wv_next) + " casts.") : "No point to spend.";
                        else                                               _ds_status = "Stage for 1 Talent Point (nothing is permanent until SAVE & CLOSE).";
                        draw_set_font(ui_font(fnt_ui));
                        draw_set_color(c_white);
                        draw_text(GUI_CX, _ds_y0 + 16, _ds_node.title + "  -  " + _ds_node.label);
                        draw_set_font(ui_font(fnt_ui_small));
                        draw_set_color(make_color_rgb(170, 175, 195));
                        draw_text(GUI_CX, _ds_y0 + 54, _ds_status);
                    } else {
                        draw_set_font(ui_font(fnt_ui));
                        draw_set_color(c_white);
                        draw_text(GUI_CX, _ds_y0 + 16, (_gc_ov.web_view_cursor == 6) ? "SAVE & CLOSE" : "CLOSE");
                        draw_set_font(ui_font(fnt_ui_small));
                        draw_set_color(make_color_rgb(170, 175, 195));
                        draw_text(GUI_CX, _ds_y0 + 54, (_gc_ov.web_view_cursor == 6)
                            ? ("Make " + string(_wv_stn) + " staged node" + ((_wv_stn == 1) ? "" : "s") + " permanent and leave.")
                            : ((_wv_stn > 0) ? "Leave WITHOUT saving - staged nodes are discarded." : "Leave the web."));
                    }

                    // SAVE & CLOSE + CLOSE buttons (touch needs an explicit way
                    // out - whetstone rule; both sit on the keyboard/pad cursor
                    // path as positions 6 and 7 so every input method reaches
                    // them). SAVE commits the staged nodes; CLOSE discards.
                    var _sv_x0 = GUI_CX - 260, _sv_x1 = GUI_CX - 10;
                    var _cl_x0 = GUI_CX + 10,  _cl_x1 = GUI_CX + 260;
                    var _bt_y0 = _wy1 - 82,    _bt_y1 = _wy1 - 22;
                    var _sv_sel = (_gc_ov.web_view_cursor == 6);
                    var _cl_sel = (_gc_ov.web_view_cursor == 7);
                    // SAVE & CLOSE - gold when it has staged work to commit
                    draw_set_color((_wv_stn > 0) ? make_color_rgb(52, 44, 26) : make_color_rgb(34, 34, 48));
                    draw_rectangle(_sv_x0, _bt_y0, _sv_x1, _bt_y1, false);
                    draw_set_color((_wv_stn > 0) ? make_color_rgb(255, 205, 90) : make_color_rgb(90, 95, 120));
                    draw_rectangle(_sv_x0, _bt_y0, _sv_x1, _bt_y1, true);
                    if (_sv_sel) { draw_set_color(c_white); draw_rectangle(_sv_x0 - 4, _bt_y0 - 4, _sv_x1 + 4, _bt_y1 + 4, true); }
                    draw_set_font(ui_font(fnt_ui));
                    draw_set_color((_wv_stn > 0) ? make_color_rgb(255, 225, 150) : make_color_rgb(150, 155, 180));
                    draw_text((_sv_x0 + _sv_x1) * 0.5, _bt_y0 + 14, "SAVE & CLOSE" + ((_wv_stn > 0) ? (" (" + string(_wv_stn) + ")") : ""));
                    // CLOSE (discard)
                    draw_set_color(make_color_rgb(40, 34, 34));
                    draw_rectangle(_cl_x0, _bt_y0, _cl_x1, _bt_y1, false);
                    draw_set_color(make_color_rgb(180, 120, 90));
                    draw_rectangle(_cl_x0, _bt_y0, _cl_x1, _bt_y1, true);
                    if (_cl_sel) { draw_set_color(c_white); draw_rectangle(_cl_x0 - 4, _bt_y0 - 4, _cl_x1 + 4, _bt_y1 + 4, true); }
                    draw_set_font(ui_font(fnt_ui));
                    draw_set_color(make_color_rgb(230, 200, 170));
                    draw_text((_cl_x0 + _cl_x1) * 0.5, _bt_y0 + 14, "CLOSE");
                    if (input_device() != 2) {
                        draw_set_font(ui_font(fnt_ui_small));
                        draw_set_color(make_color_rgb(120, 125, 150));
                        ui_draw_key_legend(GUI_CX, _wy1 - 110, "W/S: Move   A/D: Branch   Enter: Stage / Button   Esc: Discard & Close");
                    }
                    draw_set_halign(fa_left);

                    // --- Touch/mouse hit-testing (Draw-event rule). Buttons act
                    //     on first tap; nodes select on first tap, stage/unstage
                    //     on a second tap of the same node. Stands down while the
                    //     talent tour runs (the tour owns all input). ---
                    if (mouse_check_button_pressed(mb_left) && _gc_ov.talent_tour_step < 0) {
                        var _wv_mx = device_mouse_x_to_gui(0);
                        var _wv_my = device_mouse_y_to_gui(0);
                        if (_wv_my >= _bt_y0 && _wv_my <= _bt_y1 && _wv_mx >= _sv_x0 && _wv_mx <= _sv_x1) {
                            // SAVE & CLOSE
                            if (_wv_stn > 0) {
                                var _sv_res = ability_web_commit_staged(_wv_name, _wv_staged);
                                if (_sv_res == "") {
                                    notification = _wv_name + ": " + string(_wv_stn) + " node" + ((_wv_stn == 1) ? "" : "s") + " woven (permanent).";
                                    if (room == rm_hub || room == rm_character_select) save_game();
                                } else notification = _sv_res;
                            }
                            _gc_ov.web_view_open = false;
                        } else if (_wv_my >= _bt_y0 && _wv_my <= _bt_y1 && _wv_mx >= _cl_x0 && _wv_mx <= _cl_x1) {
                            // CLOSE (discard)
                            if (_wv_stn > 0) notification = "Unsaved weaves discarded.";
                            _gc_ov.web_view_open = false;
                        } else {
                            for (var _wt = 0; _wt < 6; _wt++) {
                                var _wt_r = (_wv_nodes[_wt].tier == 3) ? 40 : 34;
                                if (point_distance(_wv_mx, _wv_my, _wv_nx[_wt], _wv_ny[_wt]) <= _wt_r + 10) {
                                    if (_gc_ov.web_view_cursor == _wt) {
                                        // Second tap on the selected node = stage/unstage.
                                        var _wt_res = ability_web_stage_toggle(_wv_name, _wv_order[_wt], _wv_staged);
                                        if (_wt_res != "") notification = _wt_res;
                                    } else _gc_ov.web_view_cursor = _wt;
                                    break;
                                }
                            }
                        }
                    }

                    // Talent-web guided tour (M 08-04) - drawn LAST so it dims and
                    // annotates the whole web. Advanced by gc Step; first open only.
                    ui_draw_talent_tour();
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
                if (_tr.unlock_type == "duelist" && !trait_is_unlocked(_tr.name)) continue;   // hidden until earned
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
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(make_color_rgb(150, 120, 210));
            draw_text(_lx, 60, "AVAILABLE TRAITS  (" + string(_tr_avail_cnt) + " / " + string(_tr_cnt) + ")");
            // Touch: header clears the 90px COMPANION tab (see abilities tab note).
            if (input_device() == 2) {
                draw_set_font(ui_font(fnt_ui_small));
                draw_text(1460, 66, "SELECTED  (" + string(_tr_sel_cnt) + " / " + string(max_trait_slots()) + ")");
                draw_set_font(ui_font(fnt_ui));
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
                    draw_set_font(ui_font(fnt_ui));
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
                draw_set_font(ui_font(fnt_ui));
                draw_set_color(!_tr_unl ? make_color_rgb(125, 112, 78)
                            : (_in_sel  ? make_color_rgb(190, 130, 255)
                            : (_is_cur ? c_white
                                       : make_color_rgb(170, 175, 210))));
                draw_text(_lx + 92, _ry + 8, _tr.name + _tr_name_suf);
                draw_set_font(ui_font(fnt_ui_small));
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
            draw_set_font(ui_font(fnt_ui_small));
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

                draw_set_font(ui_font(fnt_ui_small));
                draw_set_color(make_color_rgb(70, 80, 105));
                draw_text(_rx + 14, _sy + 7, string(_si2 + 1));

                if (_has_tr) {
                    var _tr_name   = _gc_ov.traits_selected[_si2];
                    var _tr_struct = trait_get_by_name(_tr_name);
                    if (_tr_struct != undefined) {
                        ui_draw_trait_icon(_rx + 40, _sy + 28, 68, _tr_struct);
                    }
                    draw_set_font(ui_font(fnt_ui));
                    draw_set_color(make_color_rgb(190, 130, 255));
                    draw_text(_rx + 124, _sy + 24, _tr_name);
                    if (_tr_struct != undefined) {
                        draw_set_font(ui_font(fnt_ui_small));
                        draw_set_color(make_color_rgb(130, 95, 180));
                        draw_text_ext(_rx + 124, _sy + 62, _tr_struct.description, -1, 596);
                    }
                } else {
                    // Empty-slot placeholder badge.
                    draw_set_color(make_color_rgb(16, 18, 28));
                    draw_rectangle(_rx + 40, _sy + 28, _rx + 108, _sy + 96, false);
                    draw_set_color(make_color_rgb(48, 40, 70));
                    draw_rectangle(_rx + 40, _sy + 28, _rx + 108, _sy + 96, true);
                    draw_set_font(ui_font(fnt_ui));
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
                draw_set_font(ui_font(fnt_ui));
                draw_set_color(_dte.unlocked ? make_color_rgb(200, 155, 255) : make_color_rgb(125, 112, 78));
                draw_text(_desc_x + 90, 911, _dtr.name + (_dte.unlocked ? "" : "  [LOCKED - see Vex]"));
                draw_set_font(ui_font(fnt_ui_small));
                draw_set_color(make_color_rgb(155, 130, 210));
                draw_text_ext(_desc_x + 90, 942, _dtr.description, -1, _desc_w - 105);
            } else {
                draw_set_font(ui_font(fnt_ui_small));
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

            draw_set_font(ui_font(fnt_ui_small));
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

            draw_set_font(ui_font(fnt_ui));
            draw_set_color(make_color_rgb(150, 210, 160));
            draw_text(_lx, 60, "YOUR CREATURES  (" + string(array_length(_eqp)) + ")");
            // Touch: header clears the 90px COMPANION tab (see abilities tab note).
            if (input_device() == 2) {
                draw_set_font(ui_font(fnt_ui_small));
                draw_text(1460, 66, "ACTIVE");
                draw_set_font(ui_font(fnt_ui));
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
                    draw_set_font(ui_font(fnt_ui));
                    draw_set_color(make_color_rgb(170, 176, 190));
                    draw_text(_ctx, _ry + 24, "No companion");
                    if (_active) {
                        draw_set_halign(fa_right);
                        draw_set_font(ui_font(fnt_ui_small));
                        draw_set_color(make_color_rgb(120, 230, 150));
                        draw_text(_lx + 660 - 16, _ry + 28, "ACTIVE");
                        draw_set_halign(fa_left);
                    }
                } else {
                    var _cp   = global.pet_roster[_ridx];
                    var _cisp = pet_sprite(_cp, "s");
                    if (_cisp >= 0) {
                        // #16 bbox fit (08-11, M screenshot: expansion species drew
                        // outside the icon box - the raw draw assumed a bottom-centre
                        // origin the new sprites don't have).
                        var _cifit = pet_sprite_fit(_cisp, (_ibx0 + _ibx1) / 2, _iby1 - 5, _ibs - 10, _ibs - 8);
                        draw_sprite_ext(_cisp, pet_anim_frame(_cisp), _cifit.x, _cifit.y, _cifit.scale, _cifit.scale, 0, c_white, 1);
                    }
                    // Line 1: name (green when equipped) + stage on the right.
                    draw_set_font(ui_font(fnt_ui));
                    draw_set_color(_active ? make_color_rgb(150, 235, 170) : make_color_rgb(220, 226, 238));
                    draw_text(_ctx, _ry + 10, _cp.name);
                    draw_set_halign(fa_right);
                    draw_set_font(ui_font(fnt_ui_small));
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
                    draw_set_font(ui_font(fnt_ui_small));
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
                    // #16 bbox fit (08-11, M screenshot: the raw draw assumed a
                    // bottom-centre origin - expansion species hung out of the box).
                    var _fw = (_px1 - _px0) - 26, _fh = (_py1 - _py0) - 22;
                    var _hfit = pet_sprite_fit(_hsp, (_px0 + _px1) / 2, _py1 - 11, _fh, _fw);
                    draw_sprite_ext(_hsp, pet_anim_frame(_hsp), _hfit.x, _hfit.y, _hfit.scale, _hfit.scale, 0, c_white, 1);
                    // Awakened FX v2 (08-13): hologram echo + pulse ring + rising motes.
                    ui_draw_pet_awakened_fx(_hp, _hsp, pet_anim_frame(_hsp),
                        _hfit.x, _hfit.y, _hfit.scale, _hfit.scale,
                        (_px0 + _px1) / 2, (_py0 + _py1) / 2 + 15);
                    // Corruption dressing (07-09 art track): flicker / dark aura + motes.
                    ui_draw_pet_corruption_fx(_hp, _hsp, pet_anim_frame(_hsp),
                        _hfit.x, _hfit.y, _hfit.scale, _hfit.scale,
                        (_px0 + _px1) / 2, (_py0 + _py1) / 2 + 15);
                }

                // Header band (right of portrait): name + stage/archetype + egg chip.
                var _tx = _px1 + 28;
                var _active_here = (global.active_pet == _eqp[_ccur]);
                draw_set_font(ui_font(fnt_ui)); draw_set_color(c_white);
                draw_text(_tx, _py0 + 6, _hp.name + (_active_here ? "   (active)" : ""));
                draw_set_font(ui_font(fnt_ui_small)); draw_set_color(make_color_rgb(190, 160, 240));
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
                draw_set_font(ui_font(fnt_ui));
                var _ew = (_gx1 - _gx0) - 28;
                var _eh = string_height_ext(_ceff, 30, _ew);
                var _gy1 = _gy0 + 46 + _eh + 18;
                draw_set_color(make_color_rgb(20, 30, 24));
                draw_rectangle(_gx0, _gy0, _gx1, _gy1, false);
                draw_set_color(make_color_rgb(64, 110, 80));
                draw_rectangle(_gx0, _gy0, _gx1, _gy1, true);
                draw_set_font(ui_font(fnt_ui_small)); draw_set_color(make_color_rgb(120, 200, 140));
                draw_text(_gx0 + 14, _gy0 + 12, "GRANTS");
                draw_set_font(ui_font(fnt_ui)); draw_set_color(make_color_rgb(210, 230, 214));
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
                    draw_set_font(ui_font(fnt_ui));
                    var _hst_lbl_w = string_width(pet_stance_label(_hst));
                    draw_set_font(ui_font(fnt_ui_small));
                    var _hst_dsc_x = _gx0 + 14 + _hst_lbl_w + 24;
                    var _hst_dsc_w = (_gx1 - _gx0) - 52 - _hst_lbl_w;
                    var _hst_dsc_h = string_height_ext(pet_stance_desc(_hst), 26, _hst_dsc_w);
                    var _sty1 = min(_cy1 - 54, _sty0 + max(112, 52 + _hst_dsc_h + 14));
                    draw_set_color(make_color_rgb(26, 24, 36));
                    draw_rectangle(_gx0, _sty0, _gx1, _sty1, false);
                    draw_set_color(make_color_rgb(110, 96, 150));
                    draw_rectangle(_gx0, _sty0, _gx1, _sty1, true);
                    draw_set_font(ui_font(fnt_ui_small)); draw_set_color(make_color_rgb(170, 150, 220));
                    draw_text(_gx0 + 14, _sty0 + 12, (input_device() == 1) ? "STANCE   [RT] change" : "STANCE   [B] change");
                    draw_set_font(ui_font(fnt_ui)); draw_set_color(make_color_rgb(222, 214, 240));
                    draw_text(_gx0 + 14, _sty0 + 46, pet_stance_label(_hst));
                    draw_set_font(ui_font(fnt_ui_small)); draw_set_color(make_color_rgb(150, 150, 175));
                    draw_text_ext(_hst_dsc_x, _sty0 + 52, pet_stance_desc(_hst), 26, _hst_dsc_w);
                }

                // Footer hint inside the card.
                draw_set_font(ui_font(fnt_ui_small)); draw_set_color(make_color_rgb(150, 160, 190));
                draw_text(_cx0 + _ipad, _cy1 - 42, (input_device() == 2) ? "Hold for full kit & details" : "[Tab] full kit & details");
            } else {
                draw_set_color(make_color_rgb(18, 20, 30));
                draw_rectangle(_cx0, _cy0, _cx1, _cy1, false);
                draw_set_color(make_color_rgb(50, 58, 72));
                draw_rectangle(_cx0, _cy0, _cx1, _cy1, true);
                draw_set_font(ui_font(fnt_ui));
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
ui_draw_garden_scene();     // BAIRC'S GARDEN full-screen grounds (M-locked 08-15) - covers the station
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

// Trait unlock notification toast (renders above all other UI) - shared
// ui_draw_toast (08-04); band y21-90 documented in UI_BANDS.md.
if (instance_exists(obj_game_controller)) {
    var _gc_toast = instance_find(obj_game_controller, 0);
    if (_gc_toast.trait_notif_timer > 0 && _gc_toast.trait_notif_msg != "") {
        ui_draw_toast(_gc_toast.trait_notif_msg, GUI_CX, 21,
                      min(1.0, _gc_toast.trait_notif_timer / 30.0), c_white);
    }
}
ui_draw_find_banner();   // FIND banner (pets / eggs / banshee) - topmost, M 08-18

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
    // Carousel: hearts burst at the stage actor's chest; legacy list: near the
    // right-hand portrait panel.
    if (hub_use_carousel) npc_hearts_consume_pending(960, 380);
    else                  npc_hearts_consume_pending(1605, 600);
    npc_hearts_draw();
}

// Audio settings overlay - drawn on top of everything when open
if (variable_global_exists("settings_open") && global.settings_open) {
    ui_draw_settings_overlay();
}

// Pause / Esc menu (no-ops unless open; hides itself while Settings is showing)
ui_draw_pause_menu();

// Item-sacrifice picker modal - topmost (Vex stat/trait trade)
// -----------------------------------------------------------------------------
// AWAKENING BOOST POPUP (SYSTEMS_ENDLESS.md §1) - card geometry MUST match the
// Step_0 hit-test: x = 960 + (i - (n-1)/2)*460 - 210, w 420, y 420-700.
// -----------------------------------------------------------------------------
if (variable_instance_exists(id, "awaken_boost_open") && awaken_boost_open) {
    if (!variable_instance_exists(id, "awaken_boost_pulse")) awaken_boost_pulse = 0;
    awaken_boost_pulse += 0.09;
    var _abp = 0.5 + 0.5 * sin(awaken_boost_pulse);
    var _ab_opts = awaken_boost_options();

    draw_set_alpha(0.88);
    draw_set_color(make_color_rgb(6, 6, 14));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    // Radiant title - twin expanding rings pulse behind it (the "fun little
    // animation": the wave of your triumph rolling outward).
    for (var _abr = 0; _abr < 2; _abr++) {
        var _ab_rad = 70 + ((awaken_boost_pulse * 40 + _abr * 60) mod 120);
        draw_set_alpha(0.35 * (1 - _ab_rad / 190));
        draw_set_color(make_color_rgb(235, 200, 110));
        draw_circle(960, 255, _ab_rad, true);
        draw_circle(960, 255, _ab_rad + 2, true);
    }
    draw_set_alpha(1.0);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(merge_color(make_color_rgb(235, 200, 110), c_white, _abp * 0.5));
    draw_text_outline(960, 225, "THE AWAKENING SPREADS");
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(200, 190, 170));
    draw_text(960, 305, "Your triumph echoes through the deep places. Another dungeon stirs to answer it.");
    draw_set_color(make_color_rgb(150, 150, 175));
    draw_text(960, 345, "Choose which awakening deepens:");

    for (var _abi = 0; _abi < array_length(_ab_opts); _abi++) {
        var _abo = _ab_opts[_abi];
        var _abx = 960 + (_abi - (array_length(_ab_opts) - 1) / 2) * 460 - 210;
        var _sel = (awaken_boost_cursor == _abi);
        draw_set_color(_sel ? make_color_rgb(44, 36, 16) : make_color_rgb(16, 17, 26));
        draw_rectangle(_abx, 420, _abx + 420, 700, false);
        draw_set_color(_sel ? merge_color(make_color_rgb(210, 175, 90), c_white, _abp * 0.6) : make_color_rgb(60, 62, 80));
        draw_rectangle(_abx, 420, _abx + 420, 700, true);
        if (_sel) draw_rectangle(_abx - 4, 416, _abx + 424, 704, true);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
        draw_text(_abx + 210, 455, _abo.name);
        draw_set_font(fnt_ui_title);
        draw_set_color(_sel ? make_color_rgb(235, 210, 140) : make_color_rgb(120, 118, 100));
        draw_text(_abx + 210, 520, "A" + string(_abo.cur) + "  ->  A" + string(_abo.cur + 1));
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(140, 145, 165));
        draw_text(_abx + 210, 615, "Awakening " + string(_abo.cur + 1) + " unlocks without the climb");
        if (_sel) {
            draw_set_color(make_color_rgb(235, 210, 140));
            draw_text(_abx + 210, 655, (input_device() == 2) ? "tap again to bless" : "[Enter] bless this dungeon");
        }
    }

    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(120, 125, 150));
    ui_draw_key_legend(960, 760, "W/S or A/D: Choose    Enter: Bless    (or tap a card)");
    draw_set_halign(fa_left);
    draw_set_font(-1);
}
// Post-pick celebration banner (runs after the modal closes).
if (variable_instance_exists(id, "awaken_boost_done_timer") && awaken_boost_done_timer > 0) {
    awaken_boost_done_timer--;
    var _abd_a = min(1, awaken_boost_done_timer / 40);
    draw_set_alpha(0.75 * _abd_a);
    draw_set_color(make_color_rgb(30, 24, 8));
    draw_rectangle(360, 130, 1560, 205, false);
    draw_set_alpha(_abd_a);
    draw_set_color(make_color_rgb(210, 175, 90));
    draw_rectangle(360, 130, 1560, 205, true);
    draw_set_halign(fa_center);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(240, 215, 150));
    draw_text_outline(960, 152, awaken_boost_done_name);
    draw_set_halign(fa_left);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

ui_draw_item_picker();
ui_draw_reagent_picker();

// CURSED REBIRTH ritual overlay (07-31) - the dark ceremony between commit and
// reveal. Timed by gc Step (cursed_ritual_t); any confirm/tap hurries it.
if (instance_exists(obj_game_controller)) {
    var _crg = instance_find(obj_game_controller, 0);
    if (variable_instance_exists(_crg, "cursed_ritual_t") && _crg.cursed_ritual_t >= 0) {
        var _crt = _crg.cursed_ritual_t;
        var _crf = min(1, _crt / 45);                        // veil ramp-in
        draw_set_alpha(0.88 * _crf);
        draw_set_color(c_black);
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
        // Blood pulse breathing under the veil.
        var _crp = 0.5 + 0.5 * sin(_crt / 9);
        draw_set_alpha(0.18 * _crf * _crp);
        draw_set_color(make_color_rgb(140, 20, 30));
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
        // Scene window (M 08-04: "a little scene, like how eggs hatch") - the
        // approved spectral-hand-from-the-cauldron art in its own framed pane,
        // the hand REVEALED top-down as the ritual builds (source-row crop
        // slides up, so the cauldron sits fixed while the fingers emerge).
        // String-resolved: falls back to the 07-31 text-only ceremony until
        // the sprite lands in the project.
        var _cr_scn = asset_get_index("spr_scene_cursed_ritual");
        var _cr_has = (_cr_scn != -1 && sprite_exists(_cr_scn));
        var _cr_ty  = 540;   // ceremony line y (drops below the window when it's up)
        if (_cr_has) {
            // AN EVENT, not an image download (M 08-04: the old row-crop read as
            // dial-up loading): the scene breathes in with a settling zoom, sheds
            // rising ectoplasm motes, pulses with the blood beat, and FLASHES on
            // the "something gives it back" turn at t=120.
            var _wx1 = GUI_CX - 252, _wy1 = 156, _wx2 = GUI_CX + 252, _wy2 = 156 + 504;
            draw_set_alpha(_crf);
            draw_set_color(make_color_rgb(10, 8, 16));
            draw_rectangle(_wx1, _wy1, _wx2, _wy2, false);
            // Entrance: fade + zoom settle (x3.24 -> x3.0 over ~36 frames, eased).
            var _cr_in = min(1, _crt / 36);
            _cr_in = _cr_in * (2 - _cr_in);                       // ease-out
            var _cr_sc = 3 * (1.05 - 0.05 * _cr_in);   // 1.05 start = exactly flush with the 504px window
            var _cr_w2 = 160 * _cr_sc * 0.5;
            var _cr_cx = GUI_CX, _cr_cy = (_wy1 + _wy2) * 0.5;
            draw_sprite_ext(_cr_scn, 0, _cr_cx - _cr_w2, _cr_cy - _cr_w2,
                _cr_sc, _cr_sc, 0, c_white, _crf * _cr_in);
            // Breathing ectoplasm glow, swelling as the ritual builds.
            gpu_set_blendmode(bm_add);
            draw_sprite_ext(_cr_scn, 0, _cr_cx - _cr_w2, _cr_cy - _cr_w2,
                _cr_sc, _cr_sc, 0, c_white,
                _crf * _cr_in * (0.06 + 0.14 * _crp + 0.10 * min(1, _crt / 195)));
            // THE TURN (t=120): a hard spectral flash as the dark decides.
            if (_crt >= 120 && _crt < 138) {
                draw_sprite_ext(_cr_scn, 0, _cr_cx - _cr_w2, _cr_cy - _cr_w2,
                    _cr_sc, _cr_sc, 0, make_color_rgb(170, 255, 220),
                    0.7 * (1 - (_crt - 120) / 18));
            }
            // Rising ectoplasm motes (stateless from the timer, cast-fx idiom).
            for (var _cmi = 0; _cmi < 14; _cmi++) {
                var _cmp = (_cmi * 137.5) mod 97;                       // phase scramble
                var _cmx = _wx1 + 30 + ((_cmp * 5.3) mod (504 - 60));
                var _cmy = _wy2 - 24 - ((_crt * (1.1 + (_cmp mod 7) * 0.22) + _cmp * 4) mod (504 - 48));
                var _cma = 0.5 * _crf * _cr_in * (0.4 + 0.6 * abs(sin(_cmp + _crt / 25)));
                draw_set_alpha(_cma);
                draw_set_color(make_color_rgb(120, 235, 190));
                draw_rectangle(_cmx - 2, _cmy - 5, _cmx + 2, _cmy + 5, false);
            }
            gpu_set_blendmode(bm_normal);
            // Frame: Sable violet over a dark inner rim.
            draw_set_alpha(_crf);
            draw_set_color(make_color_rgb(40, 30, 58));
            draw_rectangle(_wx1 + 4, _wy1 + 4, _wx2 - 4, _wy2 - 4, true);
            draw_set_color(make_color_rgb(150, 110, 220));
            draw_rectangle(_wx1, _wy1, _wx2, _wy2, true);
            _cr_ty = 738;
        }
        // Ring of ember-motes closing in on the offering (orbits the scene
        // window's center when it's up - drifting embers in front read fine).
        var _crr = 330 - 140 * min(1, _crt / 195);
        var _cr_my = _cr_has ? 420 : 540;
        draw_set_color(make_color_rgb(190, 60, 80));
        for (var _cri = 0; _cri < 12; _cri++) {
            var _cra2 = _crt / 40 + _cri * (pi / 6);
            draw_set_alpha(_crf * (0.35 + 0.65 * abs(sin(_cra2 * 3 + _crt / 30))));
            draw_circle(GUI_CX + cos(_cra2) * _crr, _cr_my + sin(_cra2) * _crr * 0.72, 6, false);
        }
        draw_set_alpha(_crf);
        draw_set_halign(fa_center); draw_set_valign(fa_middle);
        draw_set_font(fnt_ui_title);
        draw_set_color(make_color_rgb(205, 90, 105));
        // The line stays PUT; only the dots animate, appended left-anchored past
        // the measured line end (M 08-04: centering line+dots together made the
        // whole sentence shuffle sideways with every tick).
        var _cr_line = (_crt > 120) ? "Something gives it back" : "The dark considers the offering";
        draw_text(GUI_CX, _cr_ty, _cr_line);
        draw_set_halign(fa_left);
        draw_text(GUI_CX + string_width(_cr_line) / 2, _cr_ty,
            string_repeat(".", 1 + (_crt div 20) mod 3));
        draw_set_halign(fa_center);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(150, 130, 140));
        draw_text(GUI_CX, _cr_ty + 78, (input_device() == 2) ? "tap to hurry it" : "Enter: hurry it");
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_alpha(1.0); draw_set_color(c_white); draw_set_font(-1);
        if (touch_tapped(GUI_XL, 0, GUI_XR, GUI_H)) touch_press(vk_enter);
    }
}

ui_draw_forge_result();   // craft/forge reveal popup (07-31) - over screens + picker
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
        draw_set_font(ui_font(fnt_ui));
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
            draw_set_font(ui_font(fnt_ui));
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
                ui_draw_sprite_contain(_port, 0, 730, 150, 460, 460, 1.0);
                ui_draw_gothic_frame(730, 150, 1190, 610, 15);
            }
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(make_color_rgb(228, 190, 90));
            draw_text(960, 660, npc_display_name(_sp.id) + "  -  " + affinity_tier_name_for(_sp.tier));
            draw_set_color(c_white);
            draw_text_ext(960, 724, ending_farewell_line(_sp.id, _sp.tier), 40, 1240);
        } else if (_eabs == 1 && ending_stage == _st_abs) {
            draw_set_font(ui_font(fnt_ui));
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
                draw_set_font(ui_font(fnt_ui));
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
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(c_white);
            draw_text(960, 480, "Ironwake stands. The gate stays open - for you.");
        }

        ui_draw_gothic_frame(30, 30, 1890, 1050, 30);
    }

    draw_set_halign(fa_center);
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(100, 110, 135));
    ui_draw_key_legend(960, 1002, "Enter: Continue");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// BOND DIALOGUE window (M 07-28 rework): the deepen-relationship exchange in
// ONE bordered opaque window at the NPC - portrait, the ask / progress / the
// crossing itself. Standing popup rule: bordered frame + dimmed backdrop.
if (bond_dialog_open) {
    draw_set_alpha(0.72);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    var _bdx0 = 460, _bdy0 = 300, _bdx1 = 1460, _bdy1 = 780;
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(22, 20, 30));
    draw_rectangle(_bdx0, _bdy0, _bdx1, _bdy1, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(200, 170, 110));
    draw_rectangle(_bdx0, _bdy0, _bdx1, _bdy1, true);
    draw_rectangle(_bdx0 + 6, _bdy0 + 6, _bdx1 - 6, _bdy1 - 6, true);
    // Portrait - same art mapping as the ending farewell scene.
    var _bd_port = -1;
    switch (bond_dialog_npc) {
        case "dorn":  _bd_port = Blacksmith_1__Dark_Gritty_; break;
        case "sable": _bd_port = Alcehmist_2__Flirty_;       break;
        case "maren": _bd_port = Runesmith_3__Facewrap_;     break;
        case "vex":   _bd_port = Trainer_2__Sullen_;         break;
        case "petra": _bd_port = Merchant_7__Voluptuous_;    break;
        case "vael":  _bd_port = Aesthete_2__Gothic_;        break;
        case "bairc": _bd_port = asset_get_index("spr_npc_bairc_portrait"); break;
    }
    var _bd_tx = _bdx0 + 40;   // text column start (moves right when a portrait draws)
    if (_bd_port != -1 && sprite_exists(_bd_port)) {
        ui_draw_sprite_contain(_bd_port, 0, _bdx0 + 36, _bdy0 + 66, 330, 330, 1.0);
        ui_draw_gothic_frame(_bdx0 + 36, _bdy0 + 66, _bdx0 + 366, _bdy0 + 396, 15);
        _bd_tx = _bdx0 + 410;
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(255, 225, 150));
    draw_text(_bd_tx, _bdy0 + 40, bond_dialog_title);
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(215, 220, 235));
    draw_text_ext(_bd_tx, _bdy0 + 104, bond_dialog_body, 30, _bdx1 - 48 - _bd_tx);
    // Floating hearts (M 08-15: "popup and little heart animation") - seeded
    // in the Step when a tier crossing opens this dialog; ambient loop while
    // it stays open. Procedural hearts: two lobes + a point, rising with sway.
    if (variable_instance_exists(id, "bond_dialog_hearts") && array_length(bond_dialog_hearts) > 0) {
        for (var _bh = 0; _bh < array_length(bond_dialog_hearts); _bh++) {
            var _h = bond_dialog_hearts[_bh];
            _h.y   -= _h.vy;
            _h.sway += 0.06;
            var _hx = _h.x + sin(_h.sway) * 14;
            if (_h.y < _bdy0 + 40) { _h.y = _bdy1 + random(40); _h.x = _bdx0 + random(_bdx1 - _bdx0); }
            var _ha = 0.85 * clamp((_h.y - (_bdy0 + 40)) / 120, 0, 1);
            var _r  = 7 * _h.sc;
            draw_set_alpha(_ha);
            draw_set_color(make_color_rgb(235, 100, 140));
            draw_circle(_hx - _r * 0.55, _h.y - _r * 0.4, _r * 0.62, false);
            draw_circle(_hx + _r * 0.55, _h.y - _r * 0.4, _r * 0.62, false);
            draw_triangle(_hx - _r * 1.12, _h.y - _r * 0.14, _hx + _r * 1.12, _h.y - _r * 0.14,
                          _hx, _h.y + _r * 1.05, false);
        }
        draw_set_alpha(1.0);
    }
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(140, 150, 175));
    draw_set_font(ui_font(fnt_ui_small));
    ui_draw_key_legend((_bdx0 + _bdx1) / 2, _bdy1 - 46,
        (input_device() == 2) ? "Tap to continue" : "Enter / Esc: Continue");
    draw_set_halign(fa_left);
    draw_set_font(-1);
}

// STATION UPGRADE checkout (NPC PROGRESSION 08-15): the standard bordered
// CONFIRM/CANCEL popup - buttons hit-test here and inject npcup:ok / npcup:cancel
// for the Step's modal block (0a3). Never up at the same time as the bond dialog
// (arming clears on commit before the result dialog opens).
if (variable_instance_exists(id, "npc_upgrade_arm") && npc_upgrade_arm != "" && !bond_dialog_open) {
    ui_draw_checkout_confirm(npc_upgrade_title, npc_upgrade_body, "npcup:ok", "npcup:cancel");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(-1);
}

// IRONMAN RUN-RESUME popup (SYSTEMS_RUN_RESUME.md) - modal over the whole hub
// (the Step gate exits before any hub handler while this is pending). Single
// RESUME button by design: an interrupted run can only be played out. Button
// hit-test lives here in Draw (touch rule) and injects "resume:go" for the Step.
if (variable_global_exists("resume_pending") && global.resume_pending) {
    draw_set_alpha(0.72);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    var _rz0 = 560, _rw0 = 372, _rz1 = 1360, _rw1 = 708;
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(22, 20, 30));
    draw_rectangle(_rz0, _rw0, _rz1, _rw1, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(200, 170, 110));
    draw_rectangle(_rz0, _rw0, _rz1, _rw1, true);
    draw_rectangle(_rz0 + 6, _rw0 + 6, _rz1 - 6, _rw1 - 6, true);
    draw_set_halign(fa_center);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(255, 225, 150));
    draw_text((_rz0 + _rz1) / 2, _rw0 + 24, "AN UNFINISHED DIVE");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(210, 214, 228));
    var _rd = global.resume_data;
    var _rd_dung = "the dungeon";
    if (is_struct(_rd) && variable_struct_exists(_rd, "selected_dungeon")) {
        switch (_rd.selected_dungeon) {
            case "ashen_vault":     _rd_dung = "the Ashen Vault";     break;
            case "scorched_depths": _rd_dung = "the Scorched Depths"; break;
            case "tundra_tomb":     _rd_dung = "the Tundra Tomb";     break;
        }
    }
    var _rd_floor = (is_struct(_rd) && variable_struct_exists(_rd, "current_floor")) ? _rd.current_floor : 1;
    draw_text_ext((_rz0 + _rz1) / 2, _rw0 + 84,
        "Your dive through " + _rd_dung + " was interrupted on floor " + string(_rd_floor)
        + ".\nIronwake does not forget. You return where you fell -\nthe dive ends only in extraction or death.",
        30, (_rz1 - _rz0) - 90);
    draw_set_halign(fa_left);
    var _rmx = device_mouse_x_to_gui(0), _rmy = device_mouse_y_to_gui(0);
    var _rmp = mouse_check_button_pressed(mb_left);
    ui_confirm_button((_rz0 + _rz1) / 2 - 220, _rw1 - 90, (_rz0 + _rz1) / 2 + 220, _rw1 - 24,
        "RESUME THE DIVE  [Enter]", make_color_rgb(120, 210, 130), _rmx, _rmy, _rmp, "resume:go");
    draw_set_font(-1);
}

// FOREGROUND EMBERS (M 07-31): the campfire motes drift over every panel and
// menu so the atmosphere stays visible. 1-3px at <=0.52 alpha - they dust the
// UI without ever obscuring a word. Drawn before the touch chrome so chips,
// d-pad and coach-marks stay clean on top.
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
draw_set_color(c_white);

// Touch (8d): action-chip bar, then the Back/menu chip + key pump - always LAST (topmost).
ui_draw_touch_chips();
ui_draw_touch_back();
// Touch (M 07-17): NPC-screen long-press action menu - drawn last so it's modal-topmost.
ui_draw_touch_action_menu();
ui_draw_touch_gamepad();   // on-screen d-pad in the left gutter (M 07-17)

// PINCH ZOOM INTRO (SYSTEMS_PINCH_ZOOM.md decision #3) - drawn after the touch
// chrome so it tops everything. Step exits while it's open; GOT IT (or any
// confirm key, handled in Step) persists [touch] zoom_intro_seen and closes.
// Panel height is MEASURED from the wrapped text so the copy can never collide
// with the button (UI collision rule).
if (zoom_intro_open) {
    draw_set_alpha(0.72);
    draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);
    var _zi_txt = "Two-finger PINCH zooms the whole screen - handy wherever the text runs small."
        + "\n\nTwo-finger DRAG pans while zoomed. Pinch back down to snap to normal view."
        + "\n\nYour d-pad and buttons stay put while you zoom. Pinch Zoom can be turned OFF any time in SETTINGS.";
    draw_set_font(ui_font(fnt_ui));
    var _zi_th  = string_height_ext(_zi_txt, 45, 900);
    var _zi_ph  = 132 + _zi_th + 36 + 63 + 66;   // title zone + text + gap + button + bottom pad
    var _zix1 = GUI_CX - 495, _ziy1 = GUI_CY - _zi_ph / 2;
    var _zix2 = GUI_CX + 495, _ziy2 = _ziy1 + _zi_ph;
    draw_set_color(make_color_rgb(14, 16, 24));
    draw_rectangle(_zix1, _ziy1, _zix2, _ziy2, false);
    ui_draw_gothic_frame(_zix1, _ziy1, _zix2, _ziy2, 24);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(228, 205, 140));
    draw_text(GUI_CX, _ziy1 + 42, "Pinch to Zoom");
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(200, 208, 222));
    draw_text_ext(GUI_CX, _ziy1 + 132, _zi_txt, 45, 900);
    var _zib_x1 = GUI_CX - 165, _zib_y1 = _ziy2 - 129, _zib_x2 = GUI_CX + 165, _zib_y2 = _ziy2 - 66;
    draw_set_color(make_color_rgb(20, 34, 58));
    draw_rectangle(_zib_x1, _zib_y1, _zib_x2, _zib_y2, false);
    draw_set_color(make_color_rgb(80, 160, 220));
    draw_rectangle(_zib_x1, _zib_y1, _zib_x2, _zib_y2, true);
    draw_set_valign(fa_middle);
    draw_set_color(c_white);
    draw_text(GUI_CX, (_zib_y1 + _zib_y2) / 2, "GOT IT");
    draw_set_valign(fa_top);
    if (touch_tapped(_zib_x1, _zib_y1, _zib_x2, _zib_y2, true)) {
        zoom_intro_open = false;
        ini_open("settings.ini");
        ini_write_real("touch", "zoom_intro_seen", 1);
        ini_close();
        audio_play_sound(snd_page, 1, false);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_font(-1);
}

// Tab hover quick-ref popup (M 08-15) - drawn dead last so it rides above
// every vendor screen; the stash is set by whichever tab bar the mouse is on
// this frame and consumed here.
ui_draw_tab_tip();

// NPC STATION GUIDED TOUR (M-locked 08-15) - the true last call: the spotlight
// dim + explainer card must ride above the station screens AND the tab tips.
ui_draw_npc_tour();
