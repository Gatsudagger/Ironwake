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
// 1. BACKGROUND
// -----------------------------------------------------------------------------
draw_set_color(make_color_rgb(18, 18, 28));
draw_rectangle(0, 0, 1280, 720, false);


// -----------------------------------------------------------------------------
// 2. TITLE
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_text_transformed(640, 30, "THE IRONWAKE CAMP", 1.4, 1.4, 0);
draw_set_halign(fa_left);


// -----------------------------------------------------------------------------
// 3. PLAYER INFO PANEL — top-left (x=20, y=70, w=280, h=200)
// -----------------------------------------------------------------------------
var _pi_x = 20;
var _pi_y = 70;
var _pi_w = 280;
var _pi_h = 200;

draw_set_alpha(0.85);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + _pi_h, false);
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(60, 90, 160));
draw_rectangle(_pi_x, _pi_y, _pi_x + _pi_w, _pi_y + _pi_h, true);

var _px     = _pi_x + 14;
var _py     = _pi_y + 14;
var _line_h = 28;

var _display_gold       = variable_global_exists("gold")         ? global.gold         : 0;
var _display_runs       = variable_global_exists("run_count")    ? global.run_count    : 0;
var _display_best_floor = variable_global_exists("best_floor")   ? global.best_floor   : 0;
var _display_kills      = variable_global_exists("total_kills")  ? global.total_kills  : 0;

draw_set_color(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_text(_px, _py,               "Gold:       " + string(_display_gold));
draw_text(_px, _py + _line_h,     "Runs:       " + string(_display_runs));
draw_text(_px, _py + _line_h * 2, "Best Floor: " + string(_display_best_floor));
draw_text(_px, _py + _line_h * 3, "Kills:      " + string(_display_kills));


// -----------------------------------------------------------------------------
// 4. LAST RUN SUMMARY PANEL — x=20, y=280, w=280, h=120 (conditional)
// -----------------------------------------------------------------------------
if (show_last_run) {
    var _lr_x = 20;
    var _lr_y = 280;
    var _lr_w = 280;
    var _lr_h = 148;

    draw_set_alpha(0.85);
    draw_set_color(make_color_rgb(20, 25, 45));
    draw_rectangle(_lr_x, _lr_y, _lr_x + _lr_w, _lr_y + _lr_h, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(60, 90, 160));
    draw_rectangle(_lr_x, _lr_y, _lr_x + _lr_w, _lr_y + _lr_h, true);

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
var _dp_x = 880;
var _dp_y = 70;
var _dp_w = 380;
var _dp_h = 280;

draw_set_alpha(0.9);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, false);
draw_set_alpha(1.0);
draw_set_color(make_color_rgb(80, 160, 220));
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, true);

var _ddx = _dp_x + 16;
var _ddy = _dp_y + 16;

// NPC name — fake bold (shadow + main)
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(make_color_rgb(40, 60, 90));
draw_text_transformed(_ddx + 1, _ddy + 1, npc_names[selected_npc], 1.15, 1.15, 0);
draw_set_color(c_white);
draw_text_transformed(_ddx, _ddy, npc_names[selected_npc], 1.15, 1.15, 0);

// Full description — wrapping allowed in the detail panel
draw_set_color(make_color_rgb(180, 190, 210));
draw_text_ext(_ddx, _ddy + 36, npc_descriptions[selected_npc], 20, 340);

// Interaction hint or unlock condition
if (npc_unlocked[selected_npc]) {
    draw_set_color(c_lime);
    draw_text(_ddx, _ddy + 120, "Press Space to interact");
} else {
    // Per-NPC unlock hint — indices match npc_names order
    var _hint = "";
    switch (selected_npc) {
        case 1: _hint = "Unlock after first dungeon clear";  break;  // Sable
        case 2: _hint = "Unlock after 3 dungeon clears";     break;  // Maren
        case 3: _hint = "Unlock after 10 dungeon clears";    break;  // Vex
        case 5: _hint = "Unlock after 5 dungeon clears";     break;  // Vael
        default: _hint = "Not yet available";
    }
    draw_set_color(c_gray);
    draw_text(_ddx, _ddy + 120, _hint);
}

// Notification message (set by Step_0 on interact or lock attempt)
if (notification != "") {
    draw_set_color(c_yellow);
    draw_text(_ddx, _ddy + 155, notification);
}


// -----------------------------------------------------------------------------
// 7. ENTER DUNGEON BUTTON — bottom-right (x=880, y=580, w=380, h=80)
// -----------------------------------------------------------------------------
var _eb_x = 880;
var _eb_y = 580;
var _eb_w = 380;
var _eb_h = 80;

draw_set_alpha(1.0);
draw_set_color(make_color_rgb(20, 120, 100));
draw_rectangle(_eb_x, _eb_y, _eb_x + _eb_w, _eb_y + _eb_h, false);
draw_set_color(make_color_rgb(30, 180, 150));
draw_rectangle(_eb_x, _eb_y, _eb_x + _eb_w, _eb_y + _eb_h, true);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_color(c_white);
draw_text_transformed(_eb_x + _eb_w / 2, _eb_y + 28, "ENTER DUNGEON", 1.2, 1.2, 0);

draw_set_valign(fa_top);
draw_set_color(make_color_rgb(160, 220, 210));
draw_text(_eb_x + _eb_w / 2, _eb_y + 52, "Press E to begin your run");


// -----------------------------------------------------------------------------
// 8. FOOTER INSTRUCTIONS — y=695
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);
draw_set_color(c_gray);
draw_text(640, 715, "W/S: Navigate   Enter: Interact   E: Enter Dungeon   H: History   T: Stash   P: Upgrade   I: Menu");

// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);

} // end !_loadout_is_open


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
    draw_text( 80, 90, "RUN");
    draw_text(160, 90, "RESULT");
    draw_text(310, 90, "FLOOR");
    draw_text(410, 90, "KILLS");
    draw_text(510, 90, "GOLD EARNED");
    draw_text(680, 90, "GOLD KEPT");
    draw_text(850, 90, "END LVL");
    draw_text(980, 90, "PERM PTS");

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
        draw_text(310, _ry + 5, "Floor " + string(_r.floor_reached));
        draw_text(410, _ry + 5, string(_r.kills));
        draw_set_color(c_yellow);
        draw_text(510, _ry + 5, string(_r.gold_earned) + "g");
        draw_set_color(make_color_rgb(180, 220, 120));
        draw_text(680, _ry + 5, string(_r.gold_kept) + "g");
        // End level (— for old runs without this field)
        draw_set_color(c_white);
        if (variable_struct_exists(_r, "end_level")) {
            draw_text(850, _ry + 5, "Lv " + string(_r.end_level));
        } else {
            draw_text(850, _ry + 5, "—");
        }
        // Perm points (— for old runs)
        if (variable_struct_exists(_r, "perm_points_earned") && _r.perm_points_earned > 0) {
            draw_set_color(make_color_rgb(255, 210, 60));
            draw_text(980, _ry + 5, "+" + string(_r.perm_points_earned));
        } else if (variable_struct_exists(_r, "perm_points_earned")) {
            draw_set_color(make_color_rgb(80, 90, 110));
            draw_text(980, _ry + 5, "0");
        } else {
            draw_set_color(make_color_rgb(80, 90, 110));
            draw_text(980, _ry + 5, "—");
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

    // Banner — shown below player info panel when overlay is closed
    if (global.pending_perm_points > 0 && !_gc_hub_d.perm_alloc_open) {
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(c_yellow);
        draw_text(20, 282,
            "* Permanent points to allocate: " + string(global.pending_perm_points) + "  (press P)");
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
// 11. LOADOUT OVERLAY — tabbed: ABILITIES (tab 0) and TRAITS (tab 1)
// Full-screen overlay; drawn on top of all hub content when loadout_open.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_ov = instance_find(obj_game_controller, 0);

    if (_gc_ov.loadout_open) {
        var _ov_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;
        var _ov_pool;
        switch (_ov_class) {
            case 0:  _ov_pool = global.abilities_arcanist;      break;
            case 1:  _ov_pool = global.abilities_bloodwarden;   break;
            case 2:  _ov_pool = global.abilities_shadowstrider; break;
            default: _ov_pool = global.abilities_arcanist;
        }
        var _ov_pool_sz = array_length(_ov_pool);
        var _ov_sel_cnt = array_length(_gc_ov.loadout_selected);

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

            // Left panel: ability rows
            for (var _ai = 0; _ai < _ov_pool_sz; _ai++) {
                var _ab     = _ov_pool[_ai];
                var _ry     = _list_y0 + _ai * (_row_h + _row_gap);
                var _is_cur = (_ai == _gc_ov.loadout_cursor);

                var _in_sel = false;
                for (var _si = 0; _si < _ov_sel_cnt; _si++) {
                    if (_gc_ov.loadout_selected[_si] == _ab.name) { _in_sel = true; break; }
                }

                draw_set_alpha(_is_cur ? 1.0 : 0.6);
                draw_set_color(_in_sel   ? make_color_rgb(16, 45, 22)
                            : (_is_cur  ? make_color_rgb(22, 32, 65)
                                        : make_color_rgb(14, 16, 28)));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + _row_h, false);
                draw_set_alpha(1.0);
                draw_set_color(_in_sel  ? make_color_rgb(50, 150, 70)
                            : (_is_cur ? make_color_rgb(60, 90, 185)
                                       : make_color_rgb(35, 40, 65)));
                draw_rectangle(_lx, _ry, _lx + 660, _ry + _row_h, true);

                var _name_suffix = _in_sel ? "  [SELECTED]" : "";
                draw_set_color(_in_sel  ? make_color_rgb(90, 210, 110)
                            : (_is_cur ? c_white
                                       : make_color_rgb(170, 180, 205)));
                draw_text(_lx + 12, _ry + 4, _ab.name + _name_suffix);

                draw_set_color(_is_cur ? make_color_rgb(160, 170, 195) : make_color_rgb(85, 95, 120));
                draw_text(_lx + 12, _ry + 26, _ab.desc_short);
            }

            // Right panel: 4 ability slots (y=55, each 72px + 10px gap)
            var _slot_h  = 72;
            var _slot_y0 = _list_y0;
            for (var _si2 = 0; _si2 < 4; _si2++) {
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
                            draw_set_color(make_color_rgb(85, 125, 95));
                            draw_text(_rx + 32, _sy + 40, _ov_pool[_ai2].desc_short);
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
                draw_text_ext(_desc_x + 10, 628, _dab.desc_full, -1, _desc_w - 20);
            } else {
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(80, 195, 100));
                draw_text(_desc_x + _desc_w / 2, 622, "All 4 abilities chosen — press Enter on the confirm bar below to start your run.");
                draw_set_halign(fa_left);
            }

            // --- Confirm / counter bar: y=665-695 ---
            // Cursor==pool_sz is the active confirm position; bar highlights when reached.
            var _conf_sel = (_gc_ov.loadout_cursor == _ov_pool_sz && _ov_sel_cnt == 4);
            draw_set_color(_gc_ov.loadout_full_timer > 0 ? make_color_rgb(40, 10, 10)
                         : (_conf_sel               ? make_color_rgb(16, 70, 25)
                         : (_ov_sel_cnt == 4        ? make_color_rgb(14, 48, 18)
                                                    : make_color_rgb(14, 16, 28))));
            draw_rectangle(_desc_x, 665, _desc_x + _desc_w, 695, false);
            draw_set_color(_gc_ov.loadout_full_timer > 0 ? make_color_rgb(155, 40, 40)
                         : (_conf_sel               ? make_color_rgb(50, 185, 75)
                         : (_ov_sel_cnt == 4        ? make_color_rgb(35, 95, 45)
                                                    : make_color_rgb(35, 40, 65))));
            draw_rectangle(_desc_x, 665, _desc_x + _desc_w, 695, true);

            draw_set_halign(fa_center);
            if (_gc_ov.loadout_full_timer > 0) {
                draw_set_color(make_color_rgb(255, 100, 100));
                draw_text(640, 673, "Loadout full — remove an ability before adding another.");
            } else if (_conf_sel) {
                draw_set_color(c_white);
                draw_text(640, 673, string(_ov_sel_cnt) + " / 4 selected   |   [ Space ]  Confirm and Enter Dungeon");
            } else if (_ov_sel_cnt == 4) {
                draw_set_color(make_color_rgb(80, 175, 100));
                draw_text(640, 673, string(_ov_sel_cnt) + " / 4 selected   |   Scroll down to [ Enter ] to confirm");
            } else {
                draw_set_color(make_color_rgb(160, 170, 200));
                draw_text(640, 673, string(_ov_sel_cnt) + " / 4 selected");
            }

            // --- Controls hint: y=700-715 ---
            draw_set_color(make_color_rgb(65, 75, 100));
            draw_text(640, 700, "W/S: Navigate   Q/E: Switch Tab   Enter: Toggle   Space: Confirm   Esc: Cancel");
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

            // Right panel: 2 trait slots
            var _tr_slot_h  = 82;
            var _tr_slot_y0 = _list_y0;
            for (var _si2 = 0; _si2 < 2; _si2++) {
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
                draw_text(640, 673, "Max 2 traits — remove one before adding another.");
            } else {
                draw_set_color(make_color_rgb(170, 120, 255));
                draw_text(640, 673, string(_tr_sel_cnt) + " / 2 traits selected   (optional — go to Abilities tab and scroll to confirm)");
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
ui_draw_character_menu();

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
