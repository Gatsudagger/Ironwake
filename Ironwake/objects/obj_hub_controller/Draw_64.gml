// =============================================================================
// obj_hub_controller — Draw GUI event
// Draws the full hub screen at 1280×720.
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
// 1. BACKGROUND — gradient base, camp art, drifting embers, vignette
// -----------------------------------------------------------------------------
// 1a. Vertical gradient: cool top -> warmer firelit bottom. The bottom warmth
//     "breathes" via a slow firelight pulse.
var _pulse  = 0.85 + 0.15 * sin(current_time / 650);
var _bg_top = make_color_rgb(13, 13, 20);
var _bg_bot = make_color_rgb(48 * _pulse, 33 * _pulse, 30 * _pulse);
draw_rectangle_color(0, 0, 1280, 720, _bg_top, _bg_top, _bg_bot, _bg_bot, false);

// 1b. Camp scene art — cover-fit to 1280x720, dimmed so panels stay readable.
//     No-ops cleanly until spr_hub_background is imported (bg_sprite == -1).
if (bg_sprite != -1 && sprite_exists(bg_sprite)) {
    var _bw = sprite_get_width(bg_sprite);
    var _bh = sprite_get_height(bg_sprite);
    if (_bw > 0 && _bh > 0) {
        var _bsc = max(1280 / _bw, 720 / _bh);   // uniform cover scale
        var _bdw = _bw * _bsc;
        var _bdh = _bh * _bsc;
        draw_sprite_ext(bg_sprite, 0, (1280 - _bdw) / 2, (720 - _bdh) / 2,
            _bsc, _bsc, 0, c_white, 0.32);
    }
}

// 1b2. Firelight flicker — an additive warm wash over the LOWER camp that subtly
//      brightens/dims so the light feels alive. (The gradient pulse in 1a alone is
//      masked by the camp art, so the flicker wasn't visible.) Two layered sines at
//      different rates give an organic, non-repetitive flicker; kept subtle.
var _flick = 0.72 + 0.10 * sin(current_time / 360) + 0.07 * sin(current_time / 95);
_flick = clamp(_flick, 0.45, 1.0);
gpu_set_blendmode(bm_add);
var _glow_col = make_color_rgb(96 * _flick, 52 * _flick, 20 * _flick);   // warm firelight
draw_rectangle_color(0, 400, 1280, 720, c_black, c_black, _glow_col, _glow_col, false);
gpu_set_blendmode(bm_normal);
draw_set_alpha(1.0);
draw_set_color(c_white);

// 1c. Drifting embers — updated and drawn here, behind every panel.
for (var _ei = 0; _ei < array_length(hub_embers); _ei++) {
    var _em = hub_embers[_ei];
    _em.y -= _em.spd;                                       // rise
    if (_em.y < -4) { _em.y = 724; _em.x = irandom(1280); } // wrap to bottom
    var _ex = _em.x + sin(current_time / 1000 + _em.phase) * _em.drift;
    var _ea = _em.a * (0.7 + 0.3 * sin(current_time / 700 + _em.phase));  // shimmer
    draw_set_color(make_color_rgb(255, 180, 90));
    draw_set_alpha(_ea);
    draw_rectangle(_ex, _em.y, _ex + _em.size, _em.y + _em.size, false);
}
draw_set_alpha(1.0);

// 1d. Vignette — soft dark edge bands fading inward so corners sink, center
//     reads. Drawn under the panels (depth only; never darkens UI text).
var _vg    = make_color_rgb(6, 6, 12);
var _vgmax = 0.55;
draw_primitive_begin(pr_trianglestrip);   // top
draw_vertex_color(0, 0, _vg, _vgmax); draw_vertex_color(1280, 0, _vg, _vgmax);
draw_vertex_color(0, 90, _vg, 0);     draw_vertex_color(1280, 90, _vg, 0);
draw_primitive_end();
draw_primitive_begin(pr_trianglestrip);   // bottom
draw_vertex_color(0, 720, _vg, _vgmax); draw_vertex_color(1280, 720, _vg, _vgmax);
draw_vertex_color(0, 630, _vg, 0);      draw_vertex_color(1280, 630, _vg, 0);
draw_primitive_end();
draw_primitive_begin(pr_trianglestrip);   // left
draw_vertex_color(0, 0, _vg, _vgmax); draw_vertex_color(0, 720, _vg, _vgmax);
draw_vertex_color(120, 0, _vg, 0);    draw_vertex_color(120, 720, _vg, 0);
draw_primitive_end();
draw_primitive_begin(pr_trianglestrip);   // right
draw_vertex_color(1280, 0, _vg, _vgmax); draw_vertex_color(1280, 720, _vg, _vgmax);
draw_vertex_color(1160, 0, _vg, 0);      draw_vertex_color(1160, 720, _vg, 0);
draw_primitive_end();
draw_set_alpha(1.0);
draw_set_color(c_white);


// -----------------------------------------------------------------------------
// 2. TITLE
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_text_transformed(640, 30, "THE IRONWAKE CAMP", 1.4, 1.4, 0);

// Rotating camp flavor line — placed in the open bottom-center band (between the
// NPC list and the footer) so it never collides with the title or the NPC rows.
draw_set_color(make_color_rgb(150, 130, 110));
draw_text(640, 662, hub_flavor);
draw_set_halign(fa_left);


// -----------------------------------------------------------------------------
// 3. PLAYER INFO PANEL — top-left (x=20, y=70, w=280, h=200)
// -----------------------------------------------------------------------------
var _pi_x = 20;
var _pi_y = 70;
var _pi_w = 280;
var _pi_h = 200;

draw_set_alpha(0.4);
draw_set_color(c_black);
draw_rectangle(_pi_x + 4, _pi_y + 4, _pi_x + _pi_w + 4, _pi_y + _pi_h + 4, false);
draw_set_alpha(0.85);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + _pi_h, false);
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(60, 90, 160));
draw_rectangle(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + _pi_h, true);
draw_rectangle(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + 3, false);   // accent strip

var _px     = _pi_x + 14;
var _py     = _pi_y + 14;
var _line_h = 28;

var _display_gold       = variable_global_exists("gold")         ? global.gold         : 0;
var _display_runs       = variable_global_exists("run_count")    ? global.run_count    : 0;
var _display_best_floor = variable_global_exists("best_floor")   ? global.best_floor   : 0;
var _display_kills      = variable_global_exists("total_kills")  ? global.total_kills  : 0;

draw_set_halign(fa_left);
draw_set_valign(fa_top);
// Gold reads in an antique-gold tint to match the coin economy; the rest stay white.
draw_set_color(make_color_rgb(228, 190, 90));
draw_text(_px, _py,               "Gold:       " + string(_display_gold));
draw_set_color(c_white);
draw_text(_px, _py + _line_h,     "Runs:       " + string(_display_runs));
draw_text(_px, _py + _line_h * 2, "Best Floor: " + string(_display_best_floor));
draw_text(_px, _py + _line_h * 3, "Kills:      " + string(_display_kills));

// Ornate gothic frame around the panel (surrounds the rect; content untouched).
ui_draw_gothic_frame(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + _pi_h);


// -----------------------------------------------------------------------------
// 4. LAST RUN SUMMARY PANEL — x=20, y=280, w=280, h=120 (conditional)
// -----------------------------------------------------------------------------
if (show_last_run) {
    var _lr_x = 20;
    var _lr_y = 280;
    var _lr_w = 280;
    var _lr_h = 148;

    draw_set_alpha(0.4);
    draw_set_color(c_black);
    draw_rectangle(_lr_x + 4, _lr_y + 4, _lr_x + _lr_w + 4, _lr_y + _lr_h + 4, false);
    draw_set_alpha(0.85);
    draw_set_color(make_color_rgb(20, 25, 45));
    draw_rectangle(_lr_x, _lr_y, _lr_x + _lr_w, _lr_y + _lr_h, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(60, 90, 160));
    draw_rectangle(_lr_x, _lr_y, _lr_x + _lr_w, _lr_y + _lr_h, true);
    draw_rectangle(_lr_x, _lr_y, _lr_x + _lr_w, _lr_y + 3, false);   // accent strip

    var _lx = _lr_x + 14;
    var _ly = _lr_y + 12;

    // Result header
    if (global.last_run_result == 1) {
        draw_set_color(c_lime);
        draw_text(_lx, _ly, "LAST RUN: VICTORY");
    } else {
        draw_set_color(c_red);
        draw_text(_lx, _ly, "LAST RUN: DEFEAT");
    }

    // Gold and kills
    draw_set_color(c_white);
    draw_text(_lx, _ly + 26, "Gold earned: " + string(global.last_run_gold));
    draw_text(_lx, _ly + 52, "Kills:       " + string(global.last_run_kills));

    // Permanent points earned (only shown on full-clear victory)
    if (variable_global_exists("last_run_perm_points") && global.last_run_perm_points > 0) {
        draw_set_color(make_color_rgb(255, 210, 60));
        draw_text(_lx, _ly + 78, "PERMANENT POINTS EARNED: " + string(global.last_run_perm_points));
        // Dismiss hint shifts down
        draw_set_color(c_gray);
        draw_text(_lx, _ly + 104, "Esc to dismiss");
    } else {
        // Dismiss hint
        draw_set_color(c_gray);
        draw_text(_lx, _ly + 82, "Esc to dismiss");
    }
}


// -----------------------------------------------------------------------------
// 4b. CHARACTER PANEL — bottom-left (x=20, y=440, w=280, h=230)
// Shows the player's class sprite, name, class, and total stats.
// -----------------------------------------------------------------------------
var _cp_x = 20;
var _cp_y = 440;
var _cp_w = 280;
var _cp_h = 230;

draw_set_alpha(0.4);
draw_set_color(c_black);
draw_rectangle(_cp_x + 4, _cp_y + 4, _cp_x + _cp_w + 4, _cp_y + _cp_h + 4, false);
draw_set_alpha(0.85);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_cp_x, _cp_y, _cp_x + _cp_w, _cp_y + _cp_h, false);
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(60, 90, 160));
draw_rectangle(_cp_x, _cp_y, _cp_x + _cp_w, _cp_y + _cp_h, true);
draw_rectangle(_cp_x, _cp_y, _cp_x + _cp_w, _cp_y + 3, false);   // accent strip

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

var _cpx = _cp_x + 12;
var _cpy = _cp_y + 10;

// Name and class header
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_text(_cpx, _cpy, global.player_name);
draw_set_color(make_color_rgb(100, 160, 220));
draw_text(_cpx, _cpy + 18, _cls_pre.name);

// Divider under header
draw_set_color(make_color_rgb(40, 60, 100));
draw_line(_cp_x + 8, _cpy + 36, _cp_x + _cp_w - 8, _cpy + 36);

// Portrait — left side (starts below divider at cpy+36)
var _port_idx = variable_global_exists("chosen_portrait") ? global.chosen_portrait : 0;
_port_idx = clamp(_port_idx, 0, array_length(global.portrait_sprites) - 1);
ui_draw_sprite_cover(global.portrait_sprites[_port_idx], 0,
    _cp_x + 8, _cp_y + 52, 96, 128, 1.0);
ui_draw_gothic_frame(_cp_x + 8, _cp_y + 52, _cp_x + 8 + 96, _cp_y + 52 + 128, 14);   // ornate portrait frame

// Stats — right of sprite
var _st_x = _cp_x + 114;
var _st_y = _cp_y + 52;
var _slh  = 20;

draw_set_color(make_color_rgb(150, 165, 200));
draw_text(_st_x, _st_y,           "STR  " + string(_cs_STR));
draw_text(_st_x, _st_y + _slh,     "DEX  " + string(_cs_DEX));
draw_text(_st_x, _st_y + _slh * 2, "CON  " + string(_cs_CON));
draw_text(_st_x, _st_y + _slh * 3, "INT  " + string(_cs_INT));
draw_text(_st_x, _st_y + _slh * 4, "WIS  " + string(_cs_WIS));
draw_text(_st_x, _st_y + _slh * 5, "CHA  " + string(_cs_CHA));
draw_set_color(make_color_rgb(80, 210, 100));
draw_text(_st_x, _st_y + _slh * 6, "HP   " + string(_cs_HP));


// -----------------------------------------------------------------------------
// 5. NPC LIST — center (x=420, y=70, w=440, h=560)
// Each row is 54px tall with a 10px gap between rows.
// -----------------------------------------------------------------------------
var _nl_x      = 420;
var _nl_y      = 70;
var _row_h     = 54;
var _row_gap   = 10;
var _row_w     = 440;

for (var _i = 0; _i < 6; _i++) {
    var _ry      = _nl_y + _i * (_row_h + _row_gap);
    var _is_sel  = (_i == selected_npc);
    var _is_lock = !npc_unlocked[_i];

    // Row fill — lighter for selected
    if (_is_sel) {
        draw_set_alpha(0.9);
        draw_set_color(make_color_rgb(30, 50, 80));
    } else {
        draw_set_alpha(0.7);
        draw_set_color(make_color_rgb(20, 25, 40));
    }
    draw_rectangle(_nl_x, _ry, _nl_x + _row_w, _ry + _row_h, false);

    // Border — bright teal for selected, dark gray otherwise
    draw_set_alpha(1.0);
    if (_is_sel) {
        draw_set_color(make_color_rgb(80, 160, 220));
    } else {
        draw_set_color(make_color_rgb(45, 55, 75));
    }
    draw_rectangle(_nl_x, _ry, _nl_x + _row_w, _ry + _row_h, true);
    if (_is_sel) ui_draw_gothic_frame(_nl_x, _ry, _nl_x + _row_w, _ry + _row_h, 10);   // ornate selection frame

    // NPC name — gray and suffixed "[Locked]" when locked
    var _name_str = npc_names[_i];
    if (_is_lock) {
        _name_str += "  [Locked]";
        draw_set_color(c_gray);
    } else {
        draw_set_color(c_white);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_text(_nl_x + 14, _ry + 18, _name_str);
}

draw_set_valign(fa_top);


// -----------------------------------------------------------------------------
// 6. SELECTED NPC DETAIL PANEL — right (x=880, y=70, w=380, h=280)
// -----------------------------------------------------------------------------
if (selected_npc < 6) {
var _dp_x = 880;
var _dp_y = 70;
var _dp_w = 380;
var _dp_h = 150;

draw_set_alpha(0.4);
draw_set_color(c_black);
draw_rectangle(_dp_x + 4, _dp_y + 4, _dp_x + _dp_w + 4, _dp_y + _dp_h + 4, false);
draw_set_alpha(0.9);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, false);
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(80, 160, 220));
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, true);
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + 3, false);   // accent strip
ui_draw_gothic_frame(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, 20);   // ornate NPC detail frame

var _ddx = _dp_x + 16;
var _ddy = _dp_y + 12;

// NPC name — fake bold (shadow + main)
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(make_color_rgb(40, 60, 90));
draw_text_transformed(_ddx + 1, _ddy + 1, npc_names[selected_npc], 1.15, 1.15, 0);
draw_set_color(c_white);
draw_text_transformed(_ddx, _ddy, npc_names[selected_npc], 1.15, 1.15, 0);

// Brief description
draw_set_color(make_color_rgb(180, 190, 210));
draw_text_ext(_ddx, _ddy + 28, npc_descriptions[selected_npc], 18, 340);

// Interaction hint or unlock condition
if (npc_unlocked[selected_npc]) {
    draw_set_color(c_lime);
    draw_text(_ddx, _ddy + 92, "Press Space to interact");
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
    draw_text(_ddx, _ddy + 92, _hint);
}

// Notification message
if (notification != "") {
    draw_set_color(c_yellow);
    draw_text(_ddx, _ddy + 114, notification);
}
} // end selected_npc < 6


// -----------------------------------------------------------------------------
// 6b. NPC PORTRAIT PANEL — x=880, y=228, w=380, h=344
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

var _pp_x = 880;
var _pp_y = 228;
var _pp_w = 380;
var _pp_h = 344;

// Dark portrait background
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(12, 14, 24));
draw_rectangle(_pp_x, _pp_y, _pp_x + _pp_w, _pp_y + _pp_h, false);

// NPC index → sprite
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
} else {
    // Enter Dungeon preview — the chest+monster "gate" art (now imported).
    var _prev_spr   = spr_dungeon_gate;
    var _prev_title = "Enter the Dungeon";

    // Art fills the box above a caption band
    ui_draw_sprite_cover(_prev_spr, 0, _pp_x, _pp_y, _pp_w, _pp_h - 64, 1.0);
    draw_set_alpha(0.85);
    draw_set_color(make_color_rgb(10, 12, 22));
    draw_rectangle(_pp_x, _pp_y + _pp_h - 64, _pp_x + _pp_w, _pp_y + _pp_h, false);
    draw_set_alpha(1.0);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_transformed(_pp_x + _pp_w / 2, _pp_y + _pp_h - 54, _prev_title, 1.1, 1.1, 0);
    draw_set_color(make_color_rgb(120, 200, 170));
    draw_text(_pp_x + _pp_w / 2, _pp_y + _pp_h - 26, "Press Enter to choose dungeon & loadout");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// Portrait frame border
draw_set_color(make_color_rgb(80, 160, 220));
draw_rectangle(_pp_x, _pp_y, _pp_x + _pp_w, _pp_y + _pp_h, true);


// -----------------------------------------------------------------------------
// 7. ENTER DUNGEON BUTTON — bottom-right (x=880, y=580, w=380, h=80)
// -----------------------------------------------------------------------------
var _eb_x = 880;
var _eb_y = 580;
var _eb_w = 380;
var _eb_h = 80;

var _eb_sel = (selected_npc == 6);

draw_set_alpha(1.0);
draw_set_color(_eb_sel ? make_color_rgb(25, 160, 130) : make_color_rgb(20, 120, 100));
draw_rectangle(_eb_x, _eb_y, _eb_x + _eb_w, _eb_y + _eb_h, false);
draw_set_color(_eb_sel ? make_color_rgb(60, 230, 190) : make_color_rgb(30, 180, 150));
draw_rectangle(_eb_x, _eb_y, _eb_x + _eb_w, _eb_y + _eb_h, true);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_color(c_white);
draw_text_transformed(_eb_x + _eb_w / 2, _eb_y + 28, "ENTER DUNGEON", 1.2, 1.2, 0);

draw_set_valign(fa_top);
if (_eb_sel) {
    draw_set_color(c_white);
    draw_text(_eb_x + _eb_w / 2, _eb_y + 52, "Press Enter or Space to confirm");
} else {
    draw_set_color(make_color_rgb(100, 140, 130));
    draw_text(_eb_x + _eb_w / 2, _eb_y + 52, "Scroll down to select");
}


// -----------------------------------------------------------------------------
// 8. FOOTER INSTRUCTIONS — y=695
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_color(c_gray);
draw_text(640, 715, "W/S: Navigate   Enter / Space: Interact   H: History   T: Stash   G: Item Codex   P: Upgrade   O: Settings");

// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);

} // end !_loadout_is_open

// -----------------------------------------------------------------------------
// 8b. DUNGEON SELECTION OVERLAY — full-screen, drawn after hub content
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
    var _asc_desc   = [
        "Standard difficulty. No modifiers.",
        "Enemies have +10% HP and +5% damage.",
        "Enemies have +20% HP and +10% damage.",
        "Enemies have +35% HP and +20% damage. All floor passives active.",
        "Enemies have +50% HP and +30% damage.",
        "Enemies have +70% HP and +40% damage. Boss gains +25% on top."
    ];

    // Dark cover
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(8, 8, 18));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    draw_text_transformed(640, 28, "SELECT DUNGEON", 1.4, 1.4, 0);

    // Carousel layout — selected dungeon centered large, flanking two smaller and faded.
    // Lerp the visual position each frame so switching feels smooth.
    if (!variable_struct_exists(_gc_ds, "carousel_lerp")) _gc_ds.carousel_lerp = _gc_ds.dungeon_select_cursor;
    _gc_ds.carousel_lerp = lerp(_gc_ds.carousel_lerp, _gc_ds.dungeon_select_cursor, 0.16);

    var _cursor   = _gc_ds.dungeon_select_cursor;
    var _left_i   = (_cursor - 1 + 3) mod 3;
    var _right_i  = (_cursor + 1) mod 3;

    // Side arrow hints
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(120, 130, 160));
    draw_text_transformed(52, 360, "<", 2.5, 2.5, 0);
    draw_text_transformed(1228, 360, ">", 2.5, 2.5, 0);

    // Draw order: sides first so center card renders on top
    var _draw_order = [_left_i, _right_i, _cursor];

    for (var _doi = 0; _doi < 3; _doi++) {
        var _di  = _draw_order[_doi];
        var _dkey = _dungeons[_di];
        var _dcol = _dung_color[_di];
        var _unlocked_asc = variable_global_exists("dungeon_ascendance_unlocked")
            ? variable_struct_get(global.dungeon_ascendance_unlocked, _dkey) : 0;

        var _is_center = (_di == _cursor);
        var _is_left   = (_di == _left_i && !_is_center);

        // Card geometry
        var _cx, _cy, _cw, _ch, _alpha, _name_scale;
        if (_is_center) {
            _cw = 480; _ch = 510;
            _cx = 640 - _cw / 2;
            _cy = 82;
            _alpha = 1.0;
            _name_scale = 1.3;
        } else if (_is_left) {
            _cw = 286; _ch = 380;
            _cx = 18;
            _cy = 150;
            _alpha = 0.45;
            _name_scale = 1.0;
        } else {
            _cw = 286; _ch = 380;
            _cx = 1280 - 18 - _cw;
            _cy = 150;
            _alpha = 0.45;
            _name_scale = 1.0;
        }

        // Background
        draw_set_alpha(_alpha);
        draw_set_color(_is_center ? make_color_rgb(18, 22, 40) : make_color_rgb(12, 14, 24));
        draw_rectangle(_cx, _cy, _cx + _cw, _cy + _ch, false);

        // Color accent strip at top
        draw_set_color(_dcol);
        draw_rectangle(_cx, _cy, _cx + _cw, _cy + 4, false);

        // Border
        draw_set_color(_is_center ? _dcol : make_color_rgb(38, 44, 68));
        draw_rectangle(_cx, _cy, _cx + _cw, _cy + _ch, true);

        // Name
        draw_set_halign(fa_center);
        draw_set_color(_is_center ? _dcol : make_color_rgb(80, 88, 110));
        draw_text_transformed(_cx + _cw / 2, _cy + 14, _dung_names[_di], _name_scale, _name_scale, 0);

        // Dungeon art image — preserve the sprite's aspect ratio (square source),
        // fit it inside the banner slot, and center it. Uniform scale prevents the
        // wide/squashed stretching from scaling x and y independently.
        var _art_spr = _dung_art[_di];
        var _box_w   = _is_center ? 448 : 254;
        var _box_h   = _is_center ? 140 : 100;
        var _box_x   = _cx + (_cw - _box_w) / 2;
        var _box_y   = _cy + 36;
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
            var _body_x = _cx + 16;
            var _body_w = _cw - 32;

            // Divider under the art
            draw_set_color(make_color_rgb(35, 42, 65));
            draw_line(_cx + 12, _cy + 182, _cx + _cw - 12, _cy + 182);

            // Description band (its own vertical space)
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(175, 183, 210));
            draw_text_ext(_body_x, _cy + 192, _dung_desc[_di], 20, _body_w);

            // Max unlocked tier — on its own line below the description
            var _asc_col;
            if (_unlocked_asc == 0) {
                _asc_col = make_color_rgb(100, 110, 140);
            } else if (_unlocked_asc >= 4) {
                _asc_col = make_color_rgb(255, 70, 70);
            } else {
                _asc_col = make_color_rgb(255, 200, 50);
            }
            draw_set_halign(fa_center);
            draw_set_color(_asc_col);
            draw_text(_cx + _cw / 2, _cy + 298, "Max Awakening: A" + string(_unlocked_asc));

            // Ascendance selector row
            var _asc_y = _cy + 322;
            draw_set_color(make_color_rgb(20, 26, 48));
            draw_rectangle(_cx + 14, _asc_y, _cx + _cw - 14, _asc_y + 44, false);
            draw_set_color(_dcol);
            draw_rectangle(_cx + 14, _asc_y, _cx + _cw - 14, _asc_y + 44, true);

            // Q / E arrows
            var _can_left  = (_gc_ds.dungeon_select_asc > 0);
            var _can_right = (_gc_ds.dungeon_select_asc < _unlocked_asc);
            draw_set_halign(fa_center);
            draw_set_color(_can_left  ? c_white : make_color_rgb(40, 48, 70));
            draw_text_transformed(_cx + 32, _asc_y + 13, "Q", 1.1, 1.1, 0);
            draw_set_color(_can_right ? c_white : make_color_rgb(40, 48, 70));
            draw_text_transformed(_cx + _cw - 40, _asc_y + 13, "E", 1.1, 1.1, 0);

            // Tier label (centered in the selector box)
            draw_set_color(c_white);
            draw_text(_cx + _cw / 2, _asc_y + 14, _asc_labels[_gc_ds.dungeon_select_asc]);

            // Tier description — below the selector box
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(140, 150, 185));
            draw_text_ext(_body_x, _asc_y + 56, _asc_desc[_gc_ds.dungeon_select_asc], 20, _body_w);

            // Confirm bar
            var _conf_y = _cy + _ch - 58;
            draw_set_color(make_color_rgb(18, 50, 22));
            draw_rectangle(_cx + 14, _conf_y, _cx + _cw - 14, _conf_y + 44, false);
            draw_set_color(make_color_rgb(45, 140, 60));
            draw_rectangle(_cx + 14, _conf_y, _cx + _cw - 14, _conf_y + 44, true);
            draw_set_halign(fa_center);
            draw_set_color(c_white);
            draw_text(_cx + _cw / 2, _conf_y + 13, "[ Enter ]  Confirm & Choose Loadout");

        } else {
            // Side cards: text below art (art ends at _cy+136)
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(60, 68, 92));
            draw_text(_cx + _cw / 2, _cy + 146, "A" + string(_unlocked_asc) + " max");
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(55, 60, 82));
            draw_text_ext(_cx + 12, _cy + 168, _dung_desc[_di], 18, _cw - 24);
        }

        draw_set_alpha(1.0);
    }

    // Footer
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);
    draw_set_color(make_color_rgb(75, 82, 110));
    draw_text(640, 715, "A / D: Cycle Dungeon     Q / E: Awakening     Enter: Confirm     Esc: Back");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}


// -----------------------------------------------------------------------------
// 9. RUN HISTORY OVERLAY — drawn last so it covers everything
// -----------------------------------------------------------------------------
if (show_history) {

    // Full-screen dark cover
    draw_set_alpha(0.95);
    draw_set_color(make_color_rgb(10, 12, 20));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_transformed(640, 30, "RUN HISTORY", 1.5, 1.5, 0);

    // Column headers
    draw_set_halign(fa_left);
    draw_set_color(make_color_rgb(120, 140, 160));
    draw_text(  80, 90, "RUN");
    draw_text( 160, 90, "RESULT");
    draw_text( 290, 90, "FLOOR");
    draw_text( 390, 90, "AWK");
    draw_text( 480, 90, "KILLS");
    draw_text( 560, 90, "GOLD EARNED");
    draw_text( 720, 90, "GOLD KEPT");
    draw_text( 880, 90, "END LVL");
    draw_text(1000, 90, "PERM PTS");

    // Divider
    draw_set_color(make_color_rgb(60, 70, 90));
    draw_line(60, 110, 1220, 110);

    // Run entries — newest first, up to 8 visible rows
    var _history_count = array_length(global.run_history);
    var _visible = min(8, _history_count);

    for (var _i = 0; _i < _visible; _i++) {
        var _idx = _history_count - 1 - (_i + history_scroll);
        if (_idx < 0) break;
        var _r  = global.run_history[_idx];
        var _ry = 130 + _i * 60;

        // Row background
        draw_set_alpha(0.4);
        draw_set_color(make_color_rgb(20, 25, 40));
        draw_rectangle(60, _ry - 5, 1220, _ry + 45, false);
        draw_set_alpha(1.0);

        // Result label and color
        var _result_color = c_white;
        var _result_str   = "EXTRACT";
        if (_r.result == 1)       { _result_color = c_lime; _result_str = "VICTORY"; }
        else if (_r.result == -1) { _result_color = c_red;  _result_str = "DEFEAT";  }

        draw_set_color(c_white);
        draw_text( 80, _ry + 5, "Run " + string(_r.run_number));
        draw_set_color(_result_color);
        draw_text(160, _ry + 5, _result_str);
        draw_set_color(c_white);
        draw_text(290, _ry + 5, "Floor " + string(_r.floor_reached));
        // Awakening (ascendance) tier the run was played at (— for old runs)
        if (variable_struct_exists(_r, "ascendance")) {
            draw_set_color(make_color_rgb(255, 200, 50));
            draw_text(390, _ry + 5, "A" + string(_r.ascendance));
        } else {
            draw_set_color(make_color_rgb(80, 90, 110));
            draw_text(390, _ry + 5, "—");
        }
        draw_set_color(c_white);
        draw_text(480, _ry + 5, string(_r.kills));
        draw_set_color(c_yellow);
        draw_text(560, _ry + 5, string(_r.gold_earned) + "g");
        draw_set_color(make_color_rgb(180, 220, 120));
        draw_text(720, _ry + 5, string(_r.gold_kept) + "g");
        // End level (— for old runs without this field)
        draw_set_color(c_white);
        if (variable_struct_exists(_r, "end_level")) {
            draw_text(880, _ry + 5, "Lv " + string(_r.end_level));
        } else {
            draw_text(880, _ry + 5, "—");
        }
        // Perm points (— for old runs)
        if (variable_struct_exists(_r, "perm_points_earned") && _r.perm_points_earned > 0) {
            draw_set_color(make_color_rgb(255, 210, 60));
            draw_text(1000, _ry + 5, "+" + string(_r.perm_points_earned));
        } else if (variable_struct_exists(_r, "perm_points_earned")) {
            draw_set_color(make_color_rgb(80, 90, 110));
            draw_text(1000, _ry + 5, "0");
        } else {
            draw_set_color(make_color_rgb(80, 90, 110));
            draw_text(1000, _ry + 5, "—");
        }
    }

    // Empty state
    if (_history_count == 0) {
        draw_set_halign(fa_center);
        draw_set_color(c_gray);
        draw_text(640, 300, "No runs recorded yet.");
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
    draw_set_color(make_color_rgb(255, 210, 60));
    draw_text(640, 668, "Lifetime Perm Points — Earned: " + string(_total_earned) + "   Spent: " + string(_total_spent) + "   Available: " + string(global.pending_perm_points));

    // Scroll / close hint
    draw_set_color(make_color_rgb(120, 130, 150));
    if (_history_count > 8) {
        draw_text(640, 690, "W/S to scroll   Esc to close");
    } else {
        draw_text(640, 690, "Esc to close");
    }

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

    // Banner — centered in the open zone below the NPC list, with blink
    if (global.pending_perm_points > 0 && !_gc_hub_d.perm_alloc_open) {
        var _blink_on = ((current_time mod 900) < 500);
        draw_set_alpha(_blink_on ? 1.0 : 0.28);

        var _ban_w = 480;
        var _ban_h = 52;
        var _ban_x = 640 - _ban_w / 2;
        var _ban_y = 476;

        draw_set_color(make_color_rgb(50, 38, 8));
        draw_rectangle(_ban_x, _ban_y, _ban_x + _ban_w, _ban_y + _ban_h, false);
        draw_set_color(make_color_rgb(200, 160, 30));
        draw_rectangle(_ban_x, _ban_y, _ban_x + _ban_w, _ban_y + _ban_h, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(make_color_rgb(255, 215, 60));
        draw_text_transformed(640, _ban_y + 14, "! PERMANENT POINTS AVAILABLE !", 1.05, 1.05, 0);
        draw_set_color(make_color_rgb(220, 190, 100));
        draw_text(640, _ban_y + 35, string(global.pending_perm_points) + " point(s) to spend  —  press  P");

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
    }

    // Full-screen allocation overlay
    if (_gc_hub_d.perm_alloc_open) {
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_rectangle(0, 0, 1280, 720, false);

        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(255, 200, 50));
        draw_text_transformed(640, 60, "PERMANENT UPGRADE", 1.5, 1.5, 0);
        draw_set_color(c_white);
        var _perm_pts_str = (global.pending_perm_points == 1) ? "1 point" : string(global.pending_perm_points) + " points";
        draw_text(640, 106, "Allocate " + _perm_pts_str + " into permanent stats");
        draw_set_color(make_color_rgb(150, 160, 180));
        draw_text(640, 130, "These bonuses carry into every future run.");
        draw_set_halign(fa_left);

        var _perm_stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        var _perm_stat_descs = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"];
        var _perm_glob_keys  = ["perm_str_bonus", "perm_dex_bonus", "perm_con_bonus",
                                "perm_int_bonus", "perm_wis_bonus", "perm_cha_bonus"];

        for (var _si = 0; _si < 6; _si++) {
            var _sy     = 170 + _si * 72;
            var _is_sel = (_si == _gc_hub_d.perm_alloc_index);
            var _cur    = variable_global_get(_perm_glob_keys[_si]);

            draw_set_alpha(_is_sel ? 1.0 : 0.6);
            draw_set_color(_is_sel ? make_color_rgb(50, 35, 10) : make_color_rgb(18, 22, 38));
            draw_rectangle(340, _sy, 940, _sy + 58, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_sel ? make_color_rgb(220, 170, 50) : make_color_rgb(70, 60, 40));
            draw_rectangle(340, _sy, 940, _sy + 58, true);

            draw_set_color(_is_sel ? c_white : make_color_rgb(140, 150, 170));
            draw_text(360, _sy + 18, _perm_stat_descs[_si] + "  (" + _perm_stat_names[_si] + ")");
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(255, 200, 50));
            draw_text(920, _sy + 18, "+" + string(_cur) + " permanent");
            draw_set_halign(fa_left);
        }

        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        draw_text(640, 625, "W/S: Navigate   Enter: Spend Point   Esc: Back");
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
    }
}

// -----------------------------------------------------------------------------
// 12. ITEM GALLERY OVERLAY — shown when show_gallery is true
// Full-screen dark cover; list on left (x=20-740), detail panel on right (x=760-1260).
// -----------------------------------------------------------------------------
if (show_gallery) {

    // Full-screen dark cover
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(10, 12, 20));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    draw_text_transformed(640, 20, "ITEM CODEX", 1.4, 1.4, 0);
    draw_set_halign(fa_left);

    // Build master item list (common → uncommon → rare → legendary)
    var _gal_all = [];
    if (variable_global_exists("loot_table_common"))    { for (var _gi = 0; _gi < array_length(global.loot_table_common);    _gi++) array_push(_gal_all, global.loot_table_common[_gi]);    }
    if (variable_global_exists("loot_table_uncommon"))  { for (var _gi = 0; _gi < array_length(global.loot_table_uncommon);  _gi++) array_push(_gal_all, global.loot_table_uncommon[_gi]);  }
    if (variable_global_exists("loot_table_rare"))      { for (var _gi = 0; _gi < array_length(global.loot_table_rare);      _gi++) array_push(_gal_all, global.loot_table_rare[_gi]);      }
    if (variable_global_exists("loot_table_legendary")) { for (var _gi = 0; _gi < array_length(global.loot_table_legendary); _gi++) array_push(_gal_all, global.loot_table_legendary[_gi]); }
    var _gal_count   = array_length(_gal_all);
    var _gal_visible = 12;
    var _row_h       = 46;
    var _list_y0     = 80;

    // Build discovered set for fast lookup
    var _disc_set = [];
    if (variable_global_exists("items_discovered")) {
        for (var _di = 0; _di < array_length(global.items_discovered); _di++) {
            array_push(_disc_set, global.items_discovered[_di]);
        }
    }
    var _disc_count = array_length(_disc_set);

    // -------------------------------------------------------------------------
    // LEFT PANEL — scrollable item list (x=20, w=720)
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
        draw_rectangle(20, _ry, 740, _ry + _row_h - 2, false);
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
        draw_rectangle(20, _ry, 740, _ry + _row_h - 2, true);

        // Rarity color badge (left 4px strip)
        var _rar_col = item_rarity_color(_it.rarity);
        draw_set_alpha(_disc ? 1.0 : 0.4);
        draw_set_color(_rar_col);
        draw_rectangle(20, _ry, 24, _ry + _row_h - 2, false);
        draw_set_alpha(1.0);

        // Item name or ???
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        if (_disc) {
            draw_set_color(_rar_col);
            draw_text(30, _ry + 5, _it.name);
        } else {
            draw_set_color(make_color_rgb(55, 60, 85));
            draw_text(30, _ry + 5, "???");
        }

        // Slot label (right side)
        var _slot_str = string_upper(string(_it.slot));
        draw_set_halign(fa_right);
        draw_set_color(_disc ? make_color_rgb(140, 150, 190) : make_color_rgb(40, 45, 68));
        draw_text(735, _ry + 5, _slot_str);

        // Stat preview (second line, only if discovered)
        if (_disc) {
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(100, 110, 145));
            draw_text(30, _ry + 25, _it.effect_desc);
        }
    }

    // Scroll indicator
    if (_gal_count > _gal_visible) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(70, 80, 110));
        draw_text(380, _list_y0 + _gal_visible * _row_h + 4,
            string(gallery_scroll + 1) + " - " + string(min(gallery_scroll + _gal_visible, _gal_count))
            + " of " + string(_gal_count) + "  (W/S or mouse wheel)");
    }

    // Discovered count
    draw_set_halign(fa_right);
    draw_set_color(make_color_rgb(80, 100, 150));
    draw_text(735, 52, string(_disc_count) + " / " + string(_gal_count) + " discovered");

    // -------------------------------------------------------------------------
    // RIGHT PANEL — detail view (x=760, w=500) or empty state
    // -------------------------------------------------------------------------
    var _dp_x = 760;
    var _dp_y = 80;
    var _dp_w = 500;
    var _dp_h = 560;

    draw_set_alpha(0.85);
    draw_set_color(make_color_rgb(12, 14, 26));
    draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(45, 55, 90));
    draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, true);

    if (gallery_detail_item != undefined) {
        var _d   = gallery_detail_item;
        var _dx  = _dp_x + 18;
        var _txw = _dp_w - 36;
        var _is_leg = (variable_struct_exists(_d, "rarity") && _d.rarity == 4);

        // Rarity strip at top of detail panel
        draw_set_color(item_rarity_color(_d.rarity));
        draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + 4, false);

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // --- Splash art box (splash sprite if it exists, else scaled item icon) ---
        var _art_sz = 132;
        var _art_x  = _dp_x + (_dp_w - _art_sz) / 2;
        var _art_y  = _dp_y + 14;
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_rectangle(_art_x, _art_y, _art_x + _art_sz, _art_y + _art_sz, false);
        draw_set_color(item_rarity_color(_d.rarity));
        draw_rectangle(_art_x, _art_y, _art_x + _art_sz, _art_y + _art_sz, true);
        var _splash = item_splash_sprite(item_base_name(_d));
        if (_splash != -1 && sprite_exists(_splash)) {
            ui_draw_sprite_cover(_splash, 0, _art_x + 2, _art_y + 2, _art_sz - 4, _art_sz - 4, 1.0);
        } else {
            // Fallback: enlarge the item icon, centered in the box
            ui_draw_item_icon(_art_x + (_art_sz - 80) / 2, _art_y + (_art_sz - 80) / 2, 80, _d);
        }

        // --- Name + rarity/slot ---
        var _ly = _art_y + _art_sz + 12;
        draw_set_halign(fa_center);
        draw_set_color(item_rarity_color(_d.rarity));
        draw_text_ext_transformed(_dp_x + _dp_w / 2, _ly, _d.name, 22, _txw, 1.1, 1.1, 0);
        _ly += 28;
        draw_set_color(make_color_rgb(130, 140, 185));
        draw_text(_dp_x + _dp_w / 2, _ly, string_upper(item_rarity_name(_d.rarity)) + "  •  " + string_upper(string(_d.slot)));
        _ly += 24;
        draw_set_halign(fa_left);

        // Divider
        draw_set_color(make_color_rgb(45, 55, 90));
        draw_line(_dx, _ly, _dp_x + _dp_w - 18, _ly);
        _ly += 10;

        // --- Lore (legendary, gold) OR generic description ---
        if (_is_leg && variable_struct_exists(_d, "lore") && _d.lore != "") {
            draw_set_color(make_color_rgb(235, 205, 120));
            draw_text_ext(_dx, _ly, _d.lore, 20, _txw);
            _ly += string_height_ext(_d.lore, 20, _txw) + 8;
        } else {
            draw_set_color(make_color_rgb(170, 185, 215));
            var _gdesc = item_generic_desc(_d);
            draw_text_ext(_dx, _ly, _gdesc, 20, _txw);
            _ly += string_height_ext(_gdesc, 20, _txw) + 4;
            // one-line flavor from the item's effect_desc, when present
            if (variable_struct_exists(_d, "effect_desc") && _d.effect_desc != "") {
                draw_set_color(make_color_rgb(110, 122, 150));
                draw_text_ext(_dx, _ly, "\"" + _d.effect_desc + "\"", 20, _txw);
                _ly += string_height_ext("\"" + _d.effect_desc + "\"", 20, _txw) + 6;
            }
        }

        // --- Stat ranges reference ---
        draw_set_color(make_color_rgb(45, 55, 90));
        draw_line(_dx, _ly, _dp_x + _dp_w - 18, _ly);
        _ly += 10;
        draw_set_color(make_color_rgb(150, 165, 200));
        draw_text(_dx, _ly, "Rolls & Stats");
        _ly += 22;
        draw_set_color(make_color_rgb(190, 200, 225));
        var _ranges = item_stat_ranges_text(_d);
        draw_text_ext(_dx, _ly, _ranges, 18, _txw);
        _ly += string_height_ext(_ranges, 18, _txw) + 8;

        // --- Unique effect (legendary) ---
        if (variable_struct_exists(_d, "unique_desc") && _d.unique_desc != "") {
            draw_set_color(make_color_rgb(255, 200, 60));
            draw_text(_dx, _ly, "Unique Effect");
            _ly += 22;
            draw_set_color(make_color_rgb(255, 220, 100));
            draw_text_ext(_dx + 6, _ly, _d.unique_desc, 20, _txw - 6);
        }

        // Gold value
        draw_set_color(make_color_rgb(45, 55, 90));
        draw_line(_dx, _dp_y + _dp_h - 60, _dp_x + _dp_w - 18, _dp_y + _dp_h - 60);
        draw_set_color(make_color_rgb(200, 170, 60));
        draw_text(_dx, _dp_y + _dp_h - 46, "Value:  " + string(_d.gold_value) + "g");

        // Close hint
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(70, 80, 118));
        draw_text(_dp_x + _dp_w - 18, _dp_y + _dp_h - 46, "Esc / click to close");
        draw_set_halign(fa_left);

    } else {
        // Empty state
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(make_color_rgb(45, 52, 82));
        draw_text_transformed(_dp_x + _dp_w / 2, _dp_y + _dp_h / 2,
            "Select a discovered item\nto view details", 1.0, 1.0, 0);
        draw_set_valign(fa_top);
    }

    // Footer hint
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(60, 68, 100));
    draw_text(640, 696, "W/S: Navigate   Enter: Inspect   G / Esc: Close Gallery");
    draw_set_halign(fa_left);
    draw_set_alpha(1.0);
}


// -----------------------------------------------------------------------------
// 11. LOADOUT OVERLAY — tabbed: ABILITIES (tab 0) and TRAITS (tab 1)
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
        // list fits 10 rows (49px each) from y=55 to y=542, leaving y=600-715 for the bottom zone
        var _lx      = 40;
        var _rx      = 750;
        var _list_y0 = 55;
        var _row_h   = 46;
        var _row_gap = 3;   // 49px per row

        // Background — fully opaque; nothing from the hub draws underneath
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_rectangle(0, 0, 1280, 720, false);

        // --- Tab bar ---
        var _tab_y  = 6;
        var _tab_h  = 28;
        var _tab_w  = 210;
        var _mid    = 640;

        // ABILITIES tab
        var _t0_on = (_gc_ov.loadout_tab == 0);
        draw_set_color(_t0_on ? make_color_rgb(22, 32, 65) : make_color_rgb(11, 13, 22));
        draw_rectangle(_mid - _tab_w - 6, _tab_y, _mid - 6, _tab_y + _tab_h, false);
        draw_set_color(_t0_on ? make_color_rgb(70, 100, 200) : make_color_rgb(32, 38, 65));
        draw_rectangle(_mid - _tab_w - 6, _tab_y, _mid - 6, _tab_y + _tab_h, true);
        draw_set_halign(fa_center);
        draw_set_color(_t0_on ? c_white : make_color_rgb(75, 85, 120));
        draw_text(_mid - _tab_w / 2 - 6, _tab_y + 7, "ABILITIES");

        // TRAITS tab
        var _t1_on = (_gc_ov.loadout_tab == 1);
        draw_set_color(_t1_on ? make_color_rgb(28, 18, 52) : make_color_rgb(11, 13, 22));
        draw_rectangle(_mid + 6, _tab_y, _mid + _tab_w + 6, _tab_y + _tab_h, false);
        draw_set_color(_t1_on ? make_color_rgb(120, 65, 190) : make_color_rgb(32, 38, 65));
        draw_rectangle(_mid + 6, _tab_y, _mid + _tab_w + 6, _tab_y + _tab_h, true);
        draw_set_color(_t1_on ? c_white : make_color_rgb(75, 85, 120));
        draw_text(_mid + _tab_w / 2 + 6, _tab_y + 7, "TRAITS");

        // [ TAB ] hint between tabs
        draw_set_color(make_color_rgb(55, 62, 88));
        draw_text(_mid, _tab_y + 7, "Q / E");

        draw_set_halign(fa_left);

        // =====================================================================
        // ABILITIES TAB
        // =====================================================================
        if (_gc_ov.loadout_tab == 0) {

            // Panel headers
            draw_set_color(make_color_rgb(130, 150, 200));
            draw_text(_lx, 40, "CLASS ABILITIES");
            draw_text(_rx, 40, "YOUR LOADOUT");

            // Left panel: ability rows (windowed — the pool exceeds the screen)
            var _ov_max_vis = 10;
            var _ov_scroll  = loadout_list_scroll(_gc_ov.loadout_cursor, _ov_pool_sz, _ov_max_vis);
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
                            : (_is_cur  ? make_color_rgb(22, 32, 65)
                                        : make_color_rgb(14, 16, 28)));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + _row_h, false);
                draw_set_alpha(1.0);
                draw_set_color(_in_sel  ? make_color_rgb(50, 150, 70)
                            : (_is_cur ? make_color_rgb(60, 90, 185)
                                       : make_color_rgb(35, 40, 65)));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + _row_h, true);

                var _name_suffix = _in_sel ? "  [SELECTED]" : (!_ab_unlocked ? "  [LOCKED]" : "");
                draw_set_color(!_ab_unlocked ? make_color_rgb(125, 112, 78)
                            : (_in_sel  ? make_color_rgb(90, 210, 110)
                            : (_is_cur ? c_white
                                       : make_color_rgb(170, 180, 205))));
                draw_text(_lx + 12, _ry + 4, _ab.name + _name_suffix);

                // Energy cost tag — right-aligned inside the row
                draw_set_halign(fa_right);
                draw_set_color(c_yellow);
                draw_text(_lx + 648, _ry + 4, "[" + string(_ab.energy_cost) + " AP]");
                draw_set_halign(fa_left);

                if (!_ab_unlocked) {
                    draw_set_color(make_color_rgb(150, 120, 60));
                    draw_text(_lx + 12, _ry + 26, "Locked — " + ability_unlock_condition_text(_ab.name));
                } else {
                    draw_set_color(_is_cur ? make_color_rgb(160, 170, 195) : make_color_rgb(85, 95, 120));
                    var _ls_tag = ability_attack_class_tag(_ab);
                    var _ls_sum = ability_summary(_ab);
                    draw_text(_lx + 12, _ry + 26, (_ls_tag != "") ? (_ls_sum + "  " + _ls_tag) : _ls_sum);
                }
            }

            // Scroll indicators when the pool overflows the visible window
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(110, 120, 150));
            if (_ov_scroll > 0) {
                draw_text(_lx + 330, _list_y0 - 14, "▲ " + string(_ov_scroll) + " more above");
            }
            var _ov_below = _ov_pool_sz - (_ov_scroll + _ov_max_vis);
            if (_ov_below > 0) {
                draw_text(_lx + 330, _list_y0 + _ov_max_vis * (_row_h + _row_gap) - 4, "▼ " + string(_ov_below) + " more below");
            }
            draw_set_halign(fa_left);

            // Right panel: 4 ability slots (y=55, each 72px + 10px gap)
            var _slot_h  = 72;
            var _slot_y0 = _list_y0;
            for (var _si2 = 0; _si2 < _loadout_max; _si2++) {
                var _sy     = _slot_y0 + _si2 * (_slot_h + 10);
                var _has_ab = (_si2 < _ov_sel_cnt);

                draw_set_color(_has_ab ? make_color_rgb(14, 30, 18) : make_color_rgb(12, 14, 22));
                draw_rectangle(_rx, _sy, _rx + 490, _sy + _slot_h, false);
                draw_set_color(_has_ab ? make_color_rgb(45, 120, 55) : make_color_rgb(35, 40, 60));
                draw_rectangle(_rx, _sy, _rx + 490, _sy + _slot_h, true);

                draw_set_color(make_color_rgb(70, 80, 105));
                draw_text(_rx + 10, _sy + 8, string(_si2 + 1) + ".");

                if (_has_ab) {
                    draw_set_color(make_color_rgb(110, 215, 130));
                    draw_text(_rx + 32, _sy + 8, _gc_ov.loadout_selected[_si2]);
                    for (var _ai2 = 0; _ai2 < _ov_pool_sz; _ai2++) {
                        if (_ov_pool[_ai2].name == _gc_ov.loadout_selected[_si2]) {
                            // Energy cost in the slot header
                            draw_set_halign(fa_right);
                            draw_set_color(c_yellow);
                            draw_text(_rx + 478, _sy + 8, "[" + string(_ov_pool[_ai2].energy_cost) + " AP]");
                            draw_set_halign(fa_left);
                            draw_set_color(make_color_rgb(85, 125, 95));
                            var _sl_tag = ability_attack_class_tag(_ov_pool[_ai2]);
                            var _sl_sum = ability_summary(_ov_pool[_ai2]);
                            draw_text(_rx + 32, _sy + 40, (_sl_tag != "") ? (_sl_sum + "  " + _sl_tag) : _sl_sum);
                            break;
                        }
                    }
                } else {
                    draw_set_color(make_color_rgb(45, 50, 70));
                    draw_text(_rx + 32, _sy + 26, "---  empty  ---");
                }
            }

            // --- Description box: y=600-660 ---
            var _desc_x = 40;
            var _desc_w = 1200;
            draw_set_color(make_color_rgb(10, 13, 26));
            draw_rectangle(_desc_x, 600, _desc_x + _desc_w, 660, false);
            draw_set_color(make_color_rgb(45, 55, 85));
            draw_rectangle(_desc_x, 600, _desc_x + _desc_w, 660, true);

            draw_set_halign(fa_left);
            if (_gc_ov.loadout_cursor < _ov_pool_sz) {
                var _dab = _ov_pool[_gc_ov.loadout_cursor];
                draw_set_color(c_white);
                draw_text(_desc_x + 10, 607, _dab.name);
                draw_set_color(make_color_rgb(160, 175, 205));
                draw_text_ext(_desc_x + 10, 628, ability_describe(_dab), -1, _desc_w - 20);
            } else {
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(80, 195, 100));
                draw_text(_desc_x + _desc_w / 2, 622, "All " + string(_loadout_max) + " abilities chosen — press Enter on the confirm bar below to start your run.");
                draw_set_halign(fa_left);
            }

            // --- Confirm / counter bar: y=665-695 ---
            // Cursor==pool_sz is the active confirm position; bar highlights when reached.
            var _conf_sel = (_gc_ov.loadout_cursor == _ov_pool_sz && _ov_sel_cnt == _loadout_max);
            draw_set_color(_gc_ov.loadout_full_timer > 0 ? make_color_rgb(40, 10, 10)
                         : (_conf_sel                      ? make_color_rgb(16, 70, 25)
                         : (_ov_sel_cnt == _loadout_max    ? make_color_rgb(14, 48, 18)
                                                           : make_color_rgb(14, 16, 28))));
            draw_rectangle(_desc_x, 665, _desc_x + _desc_w, 695, false);
            draw_set_color(_gc_ov.loadout_full_timer > 0 ? make_color_rgb(155, 40, 40)
                         : (_conf_sel                      ? make_color_rgb(50, 185, 75)
                         : (_ov_sel_cnt == _loadout_max    ? make_color_rgb(35, 95, 45)
                                                           : make_color_rgb(35, 40, 65))));
            draw_rectangle(_desc_x, 665, _desc_x + _desc_w, 695, true);

            draw_set_halign(fa_center);
            var _locked_flash = (variable_instance_exists(_gc_ov, "loadout_locked_timer") && _gc_ov.loadout_locked_timer > 0);
            if (_locked_flash) {
                draw_set_color(make_color_rgb(230, 180, 80));
                draw_text(640, 673, "That ability is locked — buy it from Vex or meet its unlock goal first.");
            } else if (_gc_ov.loadout_full_timer > 0) {
                draw_set_color(make_color_rgb(255, 100, 100));
                draw_text(640, 673, "Loadout full — remove an ability before adding another.");
            } else if (_conf_sel) {
                draw_set_color(c_white);
                draw_text(640, 673, string(_ov_sel_cnt) + " / " + string(_loadout_max) + " selected   |   [ Space ]  Confirm and Enter Dungeon");
            } else if (_ov_sel_cnt == _loadout_max) {
                draw_set_color(make_color_rgb(80, 175, 100));
                draw_text(640, 673, string(_ov_sel_cnt) + " / " + string(_loadout_max) + " selected   |   Scroll down to [ Enter ] to confirm");
            } else {
                draw_set_color(make_color_rgb(160, 170, 200));
                draw_text(640, 673, string(_ov_sel_cnt) + " / " + string(_loadout_max) + " selected");
            }

            // --- Controls hint: y=700-715 ---
            draw_set_color(make_color_rgb(65, 75, 100));
            draw_text(640, 700, "W/S: Navigate   Q/E: Switch Tab   Enter: Toggle   Enter / Space: Confirm   Esc: Cancel");
            draw_set_halign(fa_left);

        // =====================================================================
        // TRAITS TAB
        // =====================================================================
        } else {

            // Build available (unlocked, class-filtered) and locked lists
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
            var _tr_avail_cnt = array_length(_tr_avail);
            var _tr_sel_cnt   = array_length(_gc_ov.traits_selected);

            // Panel headers
            draw_set_color(make_color_rgb(150, 120, 210));
            draw_text(_lx, 40, "AVAILABLE TRAITS");
            draw_text(_rx, 40, "SELECTED TRAITS");

            // Available trait rows (cursor navigates these)
            var _tr_row_h   = 52;
            var _tr_row_gap = 4;
            for (var _tai = 0; _tai < _tr_avail_cnt; _tai++) {
                var _tr     = _tr_avail[_tai];
                var _ry     = _list_y0 + _tai * (_tr_row_h + _tr_row_gap);
                var _is_cur = (_tai == _gc_ov.traits_cursor);

                var _in_sel = false;
                for (var _si = 0; _si < _tr_sel_cnt; _si++) {
                    if (_gc_ov.traits_selected[_si] == _tr.name) { _in_sel = true; break; }
                }

                draw_set_alpha(_is_cur ? 1.0 : 0.65);
                draw_set_color(_in_sel  ? make_color_rgb(28, 14, 52)
                            : (_is_cur ? make_color_rgb(30, 18, 58)
                                       : make_color_rgb(14, 16, 28)));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + _tr_row_h, false);
                draw_set_alpha(1.0);
                draw_set_color(_in_sel  ? make_color_rgb(140, 70, 210)
                            : (_is_cur ? make_color_rgb(100, 60, 180)
                                       : make_color_rgb(35, 40, 65)));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + _tr_row_h, true);

                var _tr_name_suf = _in_sel ? "  [SELECTED]" : "";
                draw_set_color(_in_sel  ? make_color_rgb(190, 130, 255)
                            : (_is_cur ? c_white
                                       : make_color_rgb(170, 175, 210)));
                draw_text(_lx + 12, _ry + 5, _tr.name + _tr_name_suf);
                draw_set_color(_is_cur ? make_color_rgb(155, 165, 200) : make_color_rgb(80, 88, 118));
                draw_text(_lx + 12, _ry + 28, _tr.description);
            }

            // Locked trait rows (greyed, no cursor, show unlock condition)
            var _lock_y0 = _list_y0 + _tr_avail_cnt * (_tr_row_h + _tr_row_gap) + 10;
            for (var _tli = 0; _tli < array_length(_tr_locked); _tli++) {
                var _tr  = _tr_locked[_tli];
                var _ry  = _lock_y0 + _tli * 38;
                draw_set_alpha(0.45);
                draw_set_color(make_color_rgb(14, 16, 28));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + 34, false);
                draw_set_color(make_color_rgb(28, 32, 48));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + 34, true);
                draw_set_color(make_color_rgb(80, 85, 108));
                draw_text(_lx + 12, _ry + 3, _tr.name + "  [LOCKED]");
                var _cond = "";
                if      (_tr.unlock_type == "full_clear")  _cond = "Unlock: Complete a full 3-floor run";
                else if (_tr.unlock_type == "char_level")  _cond = "Unlock: Reach level " + string(_tr.unlock_value) + " in a run";
                else if (_tr.unlock_type == "boss_kill")   _cond = "Unlock: Defeat Malgrath the Warden";
                draw_set_color(make_color_rgb(55, 60, 78));
                draw_text(_lx + 12, _ry + 18, _cond);
                draw_set_alpha(1.0);
            }

            // Right panel: trait slots (base 2 + bought + Crown)
            var _tr_slot_max = max_trait_slots();
            var _tr_slot_h  = 82;
            var _tr_slot_y0 = _list_y0;
            for (var _si2 = 0; _si2 < _tr_slot_max; _si2++) {
                var _sy      = _tr_slot_y0 + _si2 * (_tr_slot_h + 14);
                var _has_tr  = (_si2 < _tr_sel_cnt);

                draw_set_color(_has_tr ? make_color_rgb(24, 12, 44) : make_color_rgb(12, 14, 22));
                draw_rectangle(_rx, _sy, _rx + 490, _sy + _tr_slot_h, false);
                draw_set_color(_has_tr ? make_color_rgb(110, 55, 170) : make_color_rgb(35, 40, 60));
                draw_rectangle(_rx, _sy, _rx + 490, _sy + _tr_slot_h, true);

                draw_set_color(make_color_rgb(70, 80, 105));
                draw_text(_rx + 10, _sy + 10, string(_si2 + 1) + ".");

                if (_has_tr) {
                    var _tr_name = _gc_ov.traits_selected[_si2];
                    draw_set_color(make_color_rgb(190, 130, 255));
                    draw_text(_rx + 32, _sy + 10, _tr_name);
                    for (var _tri2 = 0; _tri2 < array_length(global.traits_all); _tri2++) {
                        if (global.traits_all[_tri2].name == _tr_name) {
                            draw_set_color(make_color_rgb(130, 95, 180));
                            draw_text(_rx + 32, _sy + 44, global.traits_all[_tri2].description);
                            break;
                        }
                    }
                } else {
                    draw_set_color(make_color_rgb(45, 50, 70));
                    draw_text(_rx + 32, _sy + 30, "---  none  ---");
                }
            }

            // --- Description box: y=600-660 ---
            var _desc_x = 40;
            var _desc_w = 1200;
            draw_set_color(make_color_rgb(10, 13, 26));
            draw_rectangle(_desc_x, 600, _desc_x + _desc_w, 660, false);
            draw_set_color(make_color_rgb(60, 38, 92));
            draw_rectangle(_desc_x, 600, _desc_x + _desc_w, 660, true);

            draw_set_halign(fa_left);
            if (_tr_avail_cnt > 0) {
                var _dtr = _tr_avail[_gc_ov.traits_cursor];
                draw_set_color(make_color_rgb(200, 155, 255));
                draw_text(_desc_x + 10, 607, _dtr.name);
                draw_set_color(make_color_rgb(155, 130, 210));
                draw_text_ext(_desc_x + 10, 628, _dtr.description, -1, _desc_w - 20);
            } else {
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(80, 70, 115));
                draw_text(_desc_x + _desc_w / 2, 622, "No traits available yet. Complete runs to unlock more.");
                draw_set_halign(fa_left);
            }

            // --- Counter / flash bar: y=665-695 ---
            draw_set_color(_gc_ov.loadout_full_timer > 0 ? make_color_rgb(40, 10, 10) : make_color_rgb(18, 10, 36));
            draw_rectangle(_desc_x, 665, _desc_x + _desc_w, 695, false);
            draw_set_color(_gc_ov.loadout_full_timer > 0 ? make_color_rgb(155, 40, 40) : make_color_rgb(90, 50, 140));
            draw_rectangle(_desc_x, 665, _desc_x + _desc_w, 695, true);

            draw_set_halign(fa_center);
            if (_gc_ov.loadout_full_timer > 0) {
                draw_set_color(make_color_rgb(255, 100, 100));
                draw_text(640, 673, "Max " + string(_tr_slot_max) + " traits — remove one before adding another.");
            } else {
                // Live respec cost preview (50g per previously-equipped trait dropped)
                var _pcost = trait_respec_cost(_gc_ov.traits_selected);
                var _all_empty = true;
                for (var _pti = 0; _pti < array_length(global.player_traits); _pti++) {
                    if (global.player_traits[_pti] != "") { _all_empty = false; break; }
                }
                var _cost_hint = "";
                if (_pcost > 0) {
                    _cost_hint = "  •  Respec cost: " + string(_pcost) + "g";
                } else if (_all_empty) {
                    _cost_hint = "  •  First assignment free";
                }
                draw_set_color(make_color_rgb(170, 120, 255));
                draw_text(640, 673, string(_tr_sel_cnt) + " / " + string(_tr_slot_max) + " traits selected" + _cost_hint + "   (confirm on Abilities tab)");
            }

            // --- Controls hint: y=700-715 ---
            draw_set_color(make_color_rgb(65, 75, 100));
            draw_text(640, 700, "W/S: Navigate   Q/E: Switch Tab   Enter: Toggle Trait   Esc: Cancel");
            draw_set_halign(fa_left);
        }

        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
    }
}

ui_draw_stash_screen();
ui_draw_shop_screen();
ui_draw_trainer_screen();
ui_draw_maren_screen();
ui_draw_sable_screen();
ui_draw_vael_screen();
ui_draw_character_menu();

// Comparison panel — drawn above all overlays
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
        draw_rectangle(260, 14, 1020, 52, false);
        draw_set_color(make_color_rgb(140, 88, 220));
        draw_rectangle(260, 14, 1020, 52, true);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(c_white);
        draw_text_transformed(640, 33, _gc_toast.trait_notif_msg, 1.1, 1.1, 0);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
    }
}

// Audio settings overlay — drawn on top of everything when open
if (variable_global_exists("settings_open") && global.settings_open) {
    ui_draw_settings_overlay();
}

// Pause / Esc menu (no-ops unless open; hides itself while Settings is showing)
ui_draw_pause_menu();

// Item-sacrifice picker modal — topmost (Vex stat/trait trade)
ui_draw_item_picker();
