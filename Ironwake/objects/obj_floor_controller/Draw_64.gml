// =============================================================================
// obj_floor_controller - Draw GUI event
// Draws the branching dungeon floor map at native 1920x1080.
// Layout:
//   1. Background
//   2. Header
//   3. Node graph (x=30..1320) - connection lines then nodes
//   4. Detail panel (x=1365, w=525)
//   5. Treasure popup overlay
//   6. Event popup overlay (rest)
//   6c. Event-room interactive choice overlay
//   7. Footer instructions
// =============================================================================


// Event HP-hit jolt (M 07-28): a short whole-map shake when an event costs HP.
// World-matrix translate covers every draw below; reset at the end of this event
// so later objects draw unshaken. Mirrors combat's screen_shake idiom.
if (hp_shake_timer > 0) {
    hp_shake_timer--;
    matrix_set(matrix_world, matrix_build(irandom_range(-5, 5), irandom_range(-3, 3), 0, 0, 0, 0, 1, 1, 1));
}

// Node type colors
var _COL_COMBAT        = make_color_rgb(200, 100,  80);
var _COL_ELITE         = make_color_rgb(220,  70,  70);
var _COL_TREASURE      = make_color_rgb(220, 190,  60);
var _COL_TREASURE_HEAL = make_color_rgb( 80, 200, 140);
var _COL_TREASURE_VAULT= make_color_rgb(100, 160, 230);
var _COL_TREASURE_RARE = make_color_rgb(180, 120, 255);
var _COL_REST          = make_color_rgb( 80, 200, 120);
var _COL_EVENT         = make_color_rgb(120, 205, 200);
var _COL_BOSS          = make_color_rgb(230, 180,  50);

// Node dimensions (must match Create_0 layout - _node_w/_node_h)
var _NW = 195; var _NH = 96;


// -----------------------------------------------------------------------------
// 1. BACKGROUND
// Themed dungeon floor-map backdrop if imported (heavier scrim - lots of nodes +
// text overlay it); otherwise the flat dark fill.
// -----------------------------------------------------------------------------
if (!dungeon_bg_draw("floormap", 0.45)) {
    draw_set_color(make_color_rgb(18, 18, 28));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
}


// -----------------------------------------------------------------------------
// 2. HEADER
// -----------------------------------------------------------------------------
draw_set_font(fnt_ui_title);
draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_text(GUI_CX, 30, "FLOOR " + string(global.current_floor) + " OF 3");
draw_set_font(ui_font(fnt_ui));
draw_set_color(make_color_rgb(160, 140, 110));
var _dung_id = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
var _dung_display_name = "The Ashen Vault";
if (_dung_id == "scorched_depths")  _dung_display_name = "Scorched Depths";
else if (_dung_id == "tundra_tomb") _dung_display_name = "Tundra Tomb";
draw_text(GUI_CX, 84, _dung_display_name);
draw_set_halign(fa_left);

// Awakening tier reference - top-right, matches the combat screen label.
var _awk_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
draw_set_font(ui_font(fnt_ui_small));
draw_set_halign(fa_right);
draw_set_color(_awk_asc > 0 ? make_color_rgb(225, 150, 70) : make_color_rgb(120, 130, 150));
draw_text(1890, 33, awakening_label());
draw_set_halign(fa_left);


// -----------------------------------------------------------------------------
// 3. NODE GRAPH
// Drawn in two passes: connection lines first, then node boxes on top.
// -----------------------------------------------------------------------------
var _count = array_length(current_rooms);

// -- Reachability (greys out branches you can no longer take) + enterable-now --
// _reachable: still on a path you could follow from here. Unreachable = faded.
// _enterable: can be entered THIS step (drives the bright frontier highlight).
var _reachable = floor_compute_reachable(current_rooms);
var _accessible = array_create(_count, false);
for (var _i = 0; _i < _count; _i++) {
    _accessible[_i] = floor_room_enterable(current_rooms, _i);
}

// --- Pass 1: Connection lines ---
// Straight node-edge-to-node-edge connectors (the layout is a planar staircase, so
// direct lines never cross). Drawn as a dark underlay + a brighter top stroke so the
// path reads cleanly instead of as a flat web. Brightness encodes state: a cleared
// parent's edges are the lit "trail you walked", still-reachable edges are mid-tone,
// and abandoned (dead) branches are dimmed hard so they recede.
for (var _i = 0; _i < _count; _i++) {
    var _room = current_rooms[_i];
    var _p_reach = _reachable[_i];
    for (var _ci = 0; _ci < array_length(_room.children); _ci++) {
        var _child_id = _room.children[_ci];
        var _child  = current_rooms[_child_id];
        var _x1 = _room.px + _NW * 0.5;
        var _y1 = _room.py;
        var _x2 = _child.px - _NW * 0.5;
        var _y2 = _child.py;

        var _edge_dead   = (!_p_reach || !_reachable[_child_id]) && !_room.cleared;
        var _top_col; var _top_w; var _top_a;
        if (_room.cleared) {
            _top_col = make_color_rgb(95, 135, 185); _top_w = 5; _top_a = 0.95;   // walked trail
        } else if (!_edge_dead) {
            _top_col = make_color_rgb(70, 95, 140);  _top_w = 4; _top_a = 0.85;   // open path ahead
        } else {
            _top_col = make_color_rgb(34, 40, 58);   _top_w = 2; _top_a = 0.55;   // dead branch
        }

        // Dark underlay for separation from the busy backdrop, then the colored stroke.
        draw_set_alpha(_top_a * 0.6);
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_line_width(_x1, _y1, _x2, _y2, _top_w + 4);
        draw_set_alpha(_top_a);
        draw_set_color(_top_col);
        draw_line_width(_x1, _y1, _x2, _y2, _top_w);
    }
}
draw_set_alpha(1.0);

// Mouse/tap-to-move (M 07-29 accessibility: mouse-only must fully play the
// map). Hit-test lives HERE with the node geometry (touch rule). Gated on the
// BARE map - any floor overlay, popup, or gc-owned screen owns its own clicks.
var _map_click = mouse_check_button_pressed(mb_left)
    && !showing_event && !showing_shrine && !showing_treasure
    && !showing_event_choice && !escape_confirm_open && !showing_extract
    && !(variable_global_exists("pause_open")    && global.pause_open)
    && !(variable_global_exists("settings_open") && global.settings_open)
    && !(variable_global_exists("item_picker")   && global.item_picker.open)
    && !ui_input_blocked();
var _map_mx = device_mouse_x_to_gui(0);
var _map_my = device_mouse_y_to_gui(0);

// --- Pass 2: Node boxes ---
draw_set_font(ui_font(fnt_ui_small));
for (var _i = 0; _i < _count; _i++) {
    var _room   = current_rooms[_i];
    var _is_sel = (_i == selected_room);
    var _nx     = _room.px - _NW * 0.5;
    var _ny     = _room.py - _NH * 0.5;
    var _acc    = _accessible[_i];            // enterable THIS step (frontier)
    var _reach  = _reachable[_i];             // still on a takeable path
    var _future = _reach && !_acc && !_room.cleared;  // reachable but not yet open
    var _dead   = !_reach && !_room.cleared;  // abandoned branch - unselectable

    // Click: select any live node (detail panel updates); click the SELECTED
    // frontier node again to enter - injected as a confirm so Step's ENTER
    // ROOM path (floor_room_enterable gating included) stays the only door.
    if (_map_click
        && _map_mx >= _nx - 1 && _map_mx <= _nx + _NW + 1
        && _map_my >= _ny - 1 && _map_my <= _ny + _NH + 1) {
        _map_click = false;   // one node per click
        if (!_dead) {
            if (_is_sel && _acc) touch_press(vk_enter);
            else                 selected_room = _i;
        }
    }

    // Type color
    var _tc = c_white;
    switch (_room.type) {
        case "combat":          _tc = _COL_COMBAT;         break;
        case "elite":           _tc = _COL_ELITE;          break;
        case "treasure":        _tc = _COL_TREASURE;       break;
        case "treasure_heal":   _tc = _COL_TREASURE_HEAL;  break;
        case "treasure_vault":  _tc = _COL_TREASURE_VAULT; break;
        case "treasure_rare":   _tc = _COL_TREASURE_RARE;  break;
        case "rest":            _tc = _COL_REST;           break;
        case "event":           _tc = _COL_EVENT;          break;
        case "boss":            _tc = _COL_BOSS;           break;
        case "shrine":          _tc = make_color_rgb(210, 170, 90); break;
        case "whetstone":       _tc = make_color_rgb(150, 190, 210); break;
    }

    // Node fill - OPAQUE so the busy floor background never bleeds through and
    // makes labels hard to read. State is conveyed by fill brightness (and the
    // border color below) rather than transparency.
    draw_set_alpha(1.0);
    if (_room.cleared) {
        draw_set_color(make_color_rgb(16, 18, 26));
    } else if (_dead) {
        draw_set_color(make_color_rgb(12, 13, 20));
    } else if (_is_sel) {
        draw_set_color(make_color_rgb(30, 46, 74));
    } else if (_acc) {
        draw_set_color(make_color_rgb(24, 32, 54));
    } else { // future
        draw_set_color(make_color_rgb(18, 22, 34));
    }
    draw_rectangle(_nx, _ny, _nx + _NW, _ny + _NH, false);

    // Black separation ring just outside the box so every node pops off the bg
    // art regardless of how bright/busy it is (07-14 legibility pass, M).
    draw_set_color(make_color_rgb(4, 5, 10));
    draw_rectangle(_nx - 1, _ny - 1, _nx + _NW + 1, _ny + _NH + 1, true);

    // Node border (no white select ring on a dead room - it isn't selectable).
    // Select ring thickened to 2px to match the heavier borders below.
    if (_is_sel && !_dead) {
        draw_set_color(c_white);
        draw_rectangle(_nx - 3, _ny - 3, _nx + _NW + 3, _ny + _NH + 3, true);
        draw_rectangle(_nx - 4, _ny - 4, _nx + _NW + 4, _ny + _NH + 4, true);
    }
    // Border weight encodes state: enterable-now 3px in the type color, future
    // 2px mid-tone, dead/cleared a thin recessed line. Drawn INWARD so the node
    // footprint (and mouse hit rects) is unchanged.
    var _border_col = make_color_rgb(34, 38, 50);   // dead / cleared default
    var _border_w   = 1;
    if (_acc)         { _border_col = _tc;                          _border_w = 3; }
    else if (_future) { _border_col = make_color_rgb(78, 86, 110);  _border_w = 2; }
    draw_set_color(_border_col);
    for (var _bk = 0; _bk < _border_w; _bk++) {
        draw_rectangle(_nx + _bk, _ny + _bk, _nx + _NW - _bk, _ny + _NH - _bk, true);
    }

    // Room name (single line, clipped to the box)
    var _name_str = _room.name;
    if (_room.cleared) _name_str = "âœ“ " + _name_str;
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    var _name_col = make_color_rgb(110, 120, 140); // future
    if (_room.cleared) _name_col = c_dkgray;
    else if (_dead)    _name_col = make_color_rgb(40, 46, 60);
    else if (_acc)     _name_col = c_white;
    draw_set_color(_name_col);
    draw_text(_nx + 12, _room.py, ui_truncate(_name_str, _NW - 24));

    // Type label - bottom-right corner
    var _tl = "";
    switch (_room.type) {
        case "combat":          _tl = "COMBAT";    break;
        case "elite":           _tl = "ELITE";     break;
        case "treasure":        _tl = "CACHE";     break;
        case "treasure_heal":   _tl = "SUPPLY";    break;
        case "treasure_vault":  _tl = "ARMORY";    break;
        case "treasure_rare":   _tl = "RELIQUARY"; break;
        case "rest":            _tl = "REST";      break;
        case "event":           _tl = "EVENT";     break;
        case "boss":            _tl = "BOSS";      break;
        case "shrine":          _tl = "SHRINE";    break;
        case "whetstone":       _tl = "HONE";      break;
    }
    draw_set_halign(fa_right);
    draw_set_valign(fa_bottom);
    draw_set_color(_acc ? _tc : make_color_rgb(40, 46, 62));
    draw_text(_nx + _NW - 9, _ny + _NH - 6, _tl);

    // Sense trait: show extra difficulty hint for uncleared accessible rooms.
    // TRANSCEND "Omniscience" (POTENCY V2): hints show on EVERY uncleared room
    // (the whole floor read at a glance), and treasure rooms reveal their gold.
    if (!_room.cleared && (_acc || trait_transcended("Sense")) && trait_active("Sense")) {
        var _sense_str = "";
        switch (_room.type) {
            case "combat":          _sense_str = "MED *";    break;
            case "elite":           _sense_str = "HARD **";  break;
            case "boss":            _sense_str = "BOSS ***"; break;
            case "treasure":        _sense_str = "SAFE";      break;
            case "treasure_heal":   _sense_str = "SAFE";      break;
            case "treasure_vault":  _sense_str = "SAFE";      break;
            case "treasure_rare":   _sense_str = "SAFE *";    break;
            case "event":           _sense_str = "CHOICE";    break;
            case "rest":            _sense_str = "SAFE";      break;
            case "shrine":          _sense_str = "TRIBUTE";   break;
            case "whetstone":       _sense_str = "HONE";      break;
        }
        if (trait_transcended("Sense")
            && (_room.type == "treasure" || _room.type == "treasure_heal" || _room.type == "treasure_vault")
            && variable_struct_exists(_room, "gold_max") && _room.gold_max > 0) {
            _sense_str = "~" + string(round((_room.gold_min + _room.gold_max) / 2)) + "g";
        }
        if (_sense_str != "") {
            // Brighter readout with a shadow + small pill backing so the Sense hint
            // actually reads against the node fill (it was too subtle before).
            draw_set_halign(fa_right);
            draw_set_valign(fa_top);
            var _ss_w  = string_width(_sense_str);
            var _ss_rx = _nx + _NW - 9;
            var _ss_ty = _ny + 18;
            draw_set_alpha(0.55);
            draw_set_color(make_color_rgb(14, 28, 20));
            draw_rectangle(_ss_rx - _ss_w - 8, _ss_ty - 3, _ss_rx + 5, _ss_ty + 24, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(10, 22, 16));
            draw_text(_ss_rx + 1, _ss_ty + 1, _sense_str);
            draw_set_color(make_color_rgb(150, 240, 175));
            draw_text(_ss_rx, _ss_ty, _sense_str);
        }
    }
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);


// -----------------------------------------------------------------------------
// 4. DETAIL PANEL - right side (x=1365, w=525, h=630)
// -----------------------------------------------------------------------------
var _dp_x = 1365;
var _dp_y = 150;
var _dp_w = 525;
var _dp_h = 630;

draw_set_alpha(0.9);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, false);
draw_set_alpha(1.0);

var _sel = current_rooms[selected_room];
var _sel_tc = c_white;
switch (_sel.type) {
    case "combat":          _sel_tc = _COL_COMBAT;         break;
    case "elite":           _sel_tc = _COL_ELITE;          break;
    case "treasure":        _sel_tc = _COL_TREASURE;       break;
    case "treasure_heal":   _sel_tc = _COL_TREASURE_HEAL;  break;
    case "treasure_vault":  _sel_tc = _COL_TREASURE_VAULT; break;
    case "treasure_rare":   _sel_tc = _COL_TREASURE_RARE;  break;
    case "rest":            _sel_tc = _COL_REST;           break;
    case "event":           _sel_tc = _COL_EVENT;          break;
    case "boss":            _sel_tc = _COL_BOSS;           break;
    case "shrine":          _sel_tc = make_color_rgb(210, 170, 90); break;
    case "whetstone":       _sel_tc = make_color_rgb(150, 190, 210); break;
}
draw_set_color(_sel_tc);
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, true);

// Room-type icon (top-right corner) - only the four rooms with art show one
var _rsp = ui_room_icon_sprite(_sel.type);
if (_rsp != -1 && sprite_exists(_rsp)) {
    var _ris = 84;
    draw_set_alpha(1.0);
    draw_sprite_stretched(_rsp, 0, _dp_x + _dp_w - _ris - 21, _dp_y + 21, _ris, _ris);
}

var _ddx = _dp_x + 27;
var _ddy = _dp_y + 27;

// Room name
draw_set_font(ui_font(fnt_ui));
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(make_color_rgb(30, 40, 70));
draw_text(_ddx + 2, _ddy + 2, _sel.name);
draw_set_color(c_white);
draw_text(_ddx, _ddy, _sel.name);

// Room type label
var _det_type_str = "";
switch (_sel.type) {
    case "combat":          _det_type_str = "Combat Room";       break;
    case "elite":           _det_type_str = "Elite Chamber";     break;
    case "treasure":        _det_type_str = "Treasure Cache";    break;
    case "treasure_heal":   _det_type_str = "Supply Cache";      break;
    case "treasure_vault":  _det_type_str = "Hidden Armory";     break;
    case "treasure_rare":   _det_type_str = "Ancient Reliquary"; break;
    case "rest":            _det_type_str = "Rest Site";         break;
    case "event":           _det_type_str = "Event Room";        break;
    case "boss":            _det_type_str = "Boss Chamber";      break;
    case "shrine":          _det_type_str = "Shrine of Tribute"; break;
    case "whetstone":       _det_type_str = "The Whetstone";     break;
}
draw_set_font(ui_font(fnt_ui_small));
draw_set_color(_sel_tc);
draw_text(_ddx, _ddy + 51, _det_type_str);

// Description
var _det_desc = "";
switch (_sel.type) {
    case "combat":
        _det_desc = "Enemies lurk in the dark.\nPrepare yourself."; break;
    case "elite":
        _det_desc = "Hardened guardians wait here.\nExpect a fierce fight."; break;
    case "treasure":
        _det_desc = "A cache of forgotten wealth.\nNo enemies present.\nMay contain items."; break;
    case "treasure_heal":
        _det_desc = "Stocked with recovery supplies.\nNo enemies present.\nGuaranteed consumable item."; break;
    case "treasure_vault":
        _det_desc = "A concealed weapons cache.\nNo enemies present.\nGuaranteed equipment drop."; break;
    case "treasure_rare":
        _det_desc = "An ancient sealed chamber.\nNo enemies present.\nGuaranteed uncommon+ equipment."; break;
    case "rest":
        _det_desc = "A sheltered alcove.\nYou may rest and recover here.\n+" + string(15 + 4 * (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0)) + " HP +5% of max HP restored."; break;
    case "event":
        _det_desc = "A choice awaits - risk and\nreward in equal measure.\nYour stats may tip the odds."; break;
    case "boss":
        _det_desc = "The dungeon guardian waits.\nDefeat it to clear the floor."; break;
    case "whetstone":
        _det_desc = "A grindstone hums with old power.\nNo enemies present.\nHone one slotted ability for this run - free."; break;
}
draw_set_font(ui_font(fnt_ui));
draw_set_color(make_color_rgb(170, 180, 200));
draw_text_ext(_ddx, _ddy + 90, _det_desc, -1, _dp_w - 54);

// Accessible / cleared status
draw_set_font(ui_font(fnt_ui_small));
var _sel_acc = _accessible[selected_room];
if (_sel.cleared) {
    draw_set_color(c_gray);
    draw_text(_ddx, _ddy + 255, "Cleared");
} else if (!_sel_acc) {
    draw_set_color(make_color_rgb(80, 90, 110));
    draw_text(_ddx, _ddy + 255, "Clear a connecting room first.");
} else {
    draw_set_color(c_lime);
    draw_text(_ddx, _ddy + 255, (input_device() == 2) ? "Tap the room to enter" : "Press Enter to enter");
}

// Reward preview (uncleared rooms only)
if (!_sel.cleared) {
    if (_sel.type == "rest") {
        draw_set_color(_COL_REST);
        draw_text(_ddx, _ddy + 300, "+" + string(15 + 4 * (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0)) + " HP +5% max restored");
    } else if (_sel.type == "event") {
        draw_set_color(_COL_EVENT);
        draw_text(_ddx, _ddy + 300, "An uncertain encounter.");
        draw_set_color(make_color_rgb(150, 160, 180));
        draw_text(_ddx, _ddy + 330, "Choose your path - outcomes vary.");
    } else if (_sel.type == "treasure" && _sel.gold_min > 0) {
        draw_set_color(c_yellow);
        draw_text(_ddx, _ddy + 300, string(_sel.gold_min) + "-" + string(_sel.gold_max) + " gold");
        draw_set_color(make_color_rgb(180, 170, 100));
        draw_text(_ddx, _ddy + 330, "40% chance: item");
    } else if (_sel.type == "treasure_heal" && _sel.gold_min > 0) {
        draw_set_color(_COL_TREASURE_HEAL);
        draw_text(_ddx, _ddy + 300, string(_sel.gold_min) + "-" + string(_sel.gold_max) + " gold  +  consumable");
    } else if (_sel.type == "treasure_vault" && _sel.gold_min > 0) {
        draw_set_color(_COL_TREASURE_VAULT);
        draw_text(_ddx, _ddy + 300, string(_sel.gold_min) + "-" + string(_sel.gold_max) + " gold  +  equipment");
    } else if (_sel.type == "treasure_rare" && _sel.gold_min > 0) {
        draw_set_color(_COL_TREASURE_RARE);
        draw_text(_ddx, _ddy + 300, string(_sel.gold_min) + "-" + string(_sel.gold_max) + " gold  +  rare gear");
    }
}


// -----------------------------------------------------------------------------
// 5. TREASURE POPUP OVERLAY
// -----------------------------------------------------------------------------
if (showing_treasure) {
    draw_set_alpha(0.78);
    draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    var _float_offset = sin(treasure_timer * 0.1) * 6;
    var _pop_cx = GUI_CX;
    var _pop_cy = 450 + _float_offset;

    // #19 polish: coin burst on the chest moment - reuses the event-result sim.
    // Seeded on the popup's first frame (treasure_timer resets to 0 on open);
    // coins toss up from the gold line and settle into a pile below the text.
    if (treasure_timer == 0) {
        treasure_coins = (treasure_gold > 0)
            ? ui_seed_coin_burst(min(6 + (treasure_gold div 10), 24), GUI_CX, 540)
            : [];
    }
    if (array_length(treasure_coins) > 0) {
        ui_draw_coin_burst(treasure_coins, 924);
    }

    draw_set_font(fnt_ui_title);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(make_color_rgb(80, 60, 0));
    draw_text(_pop_cx + 4, _pop_cy + 4, "TREASURE!");
    draw_set_color(c_yellow);
    draw_text(_pop_cx, _pop_cy, "TREASURE!");

    draw_set_font(ui_font(fnt_ui));
    draw_set_color(c_white);
    var _tg_txt = "You found " + string(treasure_gold) + " gold!";
    // Coin glyph beside the amount (#19 - M-approved icon, gen_reward_icons.py).
    draw_sprite_stretched(spr_icon_gold, 0, _pop_cx - string_width(_tg_txt) * 0.5 - 44, _pop_cy + 66, 36, 36);
    draw_text(_pop_cx, _pop_cy + 84, _tg_txt);

    if (treasure_item != undefined) {
        var _tr_is_cons = variable_struct_exists(treasure_item, "item_category")
                          && treasure_item.item_category == "consumable";
        if (_tr_is_cons) {
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(ui_consumable_name_color(treasure_item));   // Genie Lamp reads legendary gold
            draw_text(_pop_cx, _pop_cy + 138, treasure_item.name);
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(140, 200, 200));
            draw_text(_pop_cx, _pop_cy + 180, treasure_item.description);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(_pop_cx, _pop_cy + 210, "[CONSUMABLE]");
        } else {
            var _tr_col = item_rarity_color(treasure_item.rarity);
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(_tr_col);
            draw_text(_pop_cx, _pop_cy + 138, treasure_item.name);
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(180, 180, 200));
            draw_text(_pop_cx, _pop_cy + 180, treasure_item.effect_desc);
            draw_set_color(_tr_col);
            draw_text(_pop_cx, _pop_cy + 210,
                "[" + item_rarity_name(treasure_item.rarity) + "]   Slot: " + treasure_item.slot);
        }
    } else {
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(make_color_rgb(100, 110, 130));
        draw_text(_pop_cx, _pop_cy + 138, "No other items found.");
    }

    // Treasure Hunter's bonus item - one compact line (name + tag) below the first.
    var _enter_y = _pop_cy + 252;
    if (treasure_item2 != undefined) {
        var _t2_is_cons = variable_struct_exists(treasure_item2, "item_category")
                          && treasure_item2.item_category == "consumable";
        draw_set_font(ui_font(fnt_ui));
        if (_t2_is_cons) {
            draw_set_color(ui_consumable_name_color(treasure_item2));   // Genie Lamp reads legendary gold
            draw_text(_pop_cx, _pop_cy + 252, "+ " + treasure_item2.name + "  [CONSUMABLE]");
        } else {
            draw_set_color(item_rarity_color(treasure_item2.rarity));
            draw_text(_pop_cx, _pop_cy + 252,
                "+ " + treasure_item2.name + "  [" + item_rarity_name(treasure_item2.rarity) + "]");
        }
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(180, 160, 90));
        draw_text(_pop_cx, _pop_cy + 288, "Treasure Hunter: bonus item!");
        _enter_y = _pop_cy + 330;
    }

    // Banshee in a Bottle - the off-ladder wail below everything else. Icon +
    // pale-cyan name line + the extraction warning (the whole tension of the find).
    if (treasure_banshee) {
        var _bb_txt = "A BANSHEE IN A BOTTLE!";
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(make_color_rgb(150, 235, 235));
        draw_sprite_stretched(spr_icon_banshee_bottle, 0,
            _pop_cx - string_width(_bb_txt) * 0.5 - 44, _enter_y - 6, 36, 36);
        draw_text(_pop_cx, _enter_y + 12, _bb_txt);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(120, 170, 175));
        draw_text(_pop_cx, _enter_y + 51, "Something wails within. Extract alive to keep it - Maren can free the spirit.");
        _enter_y += 96;
    }

    if (input_device() == 2) {
        // Touch: framed CONTINUE button (M 07-08, same as rest/event popups).
        ui_draw_touch_continue(_pop_cx, _enter_y - 12);
    } else {
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(c_ltgray);
        draw_text(_pop_cx, _enter_y, ((input_device() == 2) ? "Tap to continue" : "Press Enter to continue"));
    }

    treasure_timer++;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}


// -----------------------------------------------------------------------------
// 6. EVENT POPUP OVERLAY - rest / trap rooms
// -----------------------------------------------------------------------------
if (showing_event) {
    // Near-opaque backdrop so the floor map + room detail panel behind it don't
    // bleed through and collide with the notice text (rest/heal/treasure screens).
    draw_set_alpha(0.96);
    draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    var _ef = sin(event_timer * 0.08) * 4.5;
    var _ecx = GUI_CX;
    var _ecy = 450 + _ef;

    draw_set_font(fnt_ui_title);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(make_color_rgb(30, 20, 10));
    draw_text(_ecx + 3, _ecy + 3, event_title);
    draw_set_color(event_color);
    draw_text(_ecx, _ecy, event_title);

    // Body + prompt are TOP-aligned below the (middle-anchored) title so a multi-line
    // body can't ride up and collide with the title (e.g. the Rest Site screen).
    draw_set_font(ui_font(fnt_ui));
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(190, 195, 215));
    draw_text_ext(_ecx, _ecy + 68, event_body, -1, 900);

    if (input_device() == 2) {
        // Touch: framed CONTINUE button instead of keyboard prompt text
        // (M 07-08, heal/rest/trap rooms).
        ui_draw_touch_continue(_ecx, _ecy + 288);
    } else {
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(c_ltgray);
        draw_text(_ecx, _ecy + 300, ((input_device() == 2) ? "Tap to continue" : "Press Enter to continue"));
    }

    event_timer++;

    // Ornate gothic rim around the notice (content is centred, well inside the opening).
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}


// -----------------------------------------------------------------------------
// 6a2. THE WHETSTONE - run-scoped ability honing picker (combat plan v2 §C)
// -----------------------------------------------------------------------------
if (showing_whetstone) {
    // Scene dressing (M 08-13: "the whetstone event rooms need a background
    // scene setting"): the current dungeon's combat backdrop under a heavy
    // scrim, so the stone sits IN the dungeon instead of floating in void.
    // Falls back to the old near-black fill if the art isn't imported.
    if (!dungeon_bg_draw("combat", 0.82)) {
        draw_set_alpha(0.95);
        draw_set_color(c_black);
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
        draw_set_alpha(1.0);
    }

    var _wt_steel = make_color_rgb(150, 190, 210);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(_wt_steel);
    draw_text(GUI_CX, 84, "The Whetstone");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(170, 180, 195));
    draw_text(GUI_CX, 162, "Set one edge sharper for the rest of this run. No cost - the stone asks nothing.");

    var _wt_na = array_length(whetstone_abilities);

    if (_wt_na == 0) {
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(make_color_rgb(150, 150, 170));
        draw_text(GUI_CX, 520, "You carry no abilities to hone. (Esc to leave.)");
    } else if (whetstone_phase == "ability") {
        // Phase 1: pick which slotted ability to hone.
        draw_set_halign(fa_left);
        var _wt_rx0 = 420, _wt_rx1 = 1500, _wt_rh = 96, _wt_pitch = 108, _wt_y0 = 270;
        for (var _wi = 0; _wi < _wt_na; _wi++) {
            var _wab  = whetstone_abilities[_wi];
            var _wry  = _wt_y0 + _wi * _wt_pitch;
            var _wsel = (_wi == whetstone_ab_cursor);
            draw_set_color(_wsel ? make_color_rgb(28, 42, 52) : make_color_rgb(16, 20, 26));
            draw_rectangle(_wt_rx0, _wry, _wt_rx1, _wry + _wt_rh, false);
            draw_set_color(_wsel ? _wt_steel : make_color_rgb(56, 70, 82));
            draw_rectangle(_wt_rx0, _wry, _wt_rx1, _wry + _wt_rh, true);

            draw_set_font(ui_font(fnt_ui));
            draw_set_color(_wsel ? c_white : make_color_rgb(190, 205, 215));
            draw_text(_wt_rx0 + 26, _wry + 12, _wab.name);
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(150, 165, 180));
            // The web nodes this ability could take (titles only - labels would
            // overflow the row with 3 options), previewed so the choice is legible.
            var _wopt = ability_web_whetstone_options(_wab);
            var _wprev = "";
            for (var _wo = 0; _wo < array_length(_wopt); _wo++) _wprev += (_wo > 0 ? "   |   " : "") + _wopt[_wo].title;
            draw_text(_wt_rx0 + 26, _wry + 54, _wprev);
        }
        // Touch: tap a row to select it, tap the selected row again to choose
        // its edge (simulated Enter). The LEAVE button below covers Esc.
        if (mouse_check_button_pressed(mb_left)) {
            var _wtx = device_mouse_x_to_gui(0);
            var _wty = device_mouse_y_to_gui(0);
            for (var _wti = 0; _wti < _wt_na; _wti++) {
                var _wty0 = _wt_y0 + _wti * _wt_pitch;
                if (_wtx >= _wt_rx0 && _wtx <= _wt_rx1 && _wty >= _wty0 && _wty <= _wty0 + _wt_rh) {
                    if (_wti != whetstone_ab_cursor) whetstone_ab_cursor = _wti;
                    else touch_press(vk_enter);
                    break;
                }
            }
        }
        draw_set_halign(fa_center);
        ui_draw_key_legend(GUI_CX, 990, "W/S: Select      Enter: Choose an edge      Esc: Leave (no honing)");
    } else {
        // Phase 2: pick one of the chosen ability's reachable unowned web nodes.
        var _wcab  = whetstone_abilities[whetstone_ab_cursor];
        var _wcopt = ability_web_whetstone_options(_wcab);
        var _wcn   = array_length(_wcopt);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(make_color_rgb(210, 220, 230));
        draw_text(GUI_CX, 260, "Hone " + _wcab.name + " - borrow one unwoven strand for this run:");

        draw_set_halign(fa_left);
        var _wm_rx0 = 520, _wm_rx1 = 1400, _wm_rh = 108, _wm_pitch = 132, _wm_y0 = 360;
        for (var _mi = 0; _mi < _wcn; _mi++) {
            var _mry  = _wm_y0 + _mi * _wm_pitch;
            var _msel = (_mi == whetstone_mod_cursor);
            draw_set_color(_msel ? make_color_rgb(28, 42, 52) : make_color_rgb(16, 20, 26));
            draw_rectangle(_wm_rx0, _mry, _wm_rx1, _mry + _wm_rh, false);
            draw_set_color(_msel ? _wt_steel : make_color_rgb(56, 70, 82));
            draw_rectangle(_wm_rx0, _mry, _wm_rx1, _mry + _wm_rh, true);
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(_msel ? c_white : make_color_rgb(190, 205, 215));
            draw_set_valign(fa_middle);
            draw_text(_wm_rx0 + 30, _mry + _wm_rh * 0.5, _wcopt[_mi].title + "  -  " + _wcopt[_mi].label);
            draw_set_valign(fa_top);
        }
        // Touch: tap a mod row to select it, tap the selected row again to hone
        // (simulated Enter). The BACK button below covers Esc.
        if (mouse_check_button_pressed(mb_left)) {
            var _wmx = device_mouse_x_to_gui(0);
            var _wmy = device_mouse_y_to_gui(0);
            for (var _wmi = 0; _wmi < _wcn; _wmi++) {
                var _wmy0 = _wm_y0 + _wmi * _wm_pitch;
                if (_wmx >= _wm_rx0 && _wmx <= _wm_rx1 && _wmy >= _wmy0 && _wmy <= _wmy0 + _wm_rh) {
                    if (_wmi != whetstone_mod_cursor) whetstone_mod_cursor = _wmi;
                    else touch_press(vk_enter);
                    break;
                }
            }
        }
        draw_set_halign(fa_center);
        ui_draw_key_legend(GUI_CX, 990, "W/S: Select      Enter: Hone this edge      Esc: Back");
    }

    // Touch (07-24 softlock fix): key legends draw nothing on a phone, so the
    // whetstone had NO way out by touch. Explicit bottom button - LEAVE from the
    // ability list / empty stone, BACK from the edge picker (simulated Esc).
    if (input_device() == 2) {
        var _wlb_txt = (_wt_na > 0 && whetstone_phase != "ability") ? "BACK" : "LEAVE";
        draw_set_color(make_color_rgb(20, 28, 34));
        draw_rectangle(GUI_CX - 180, 954, GUI_CX + 180, 1020, false);
        draw_set_color(_wt_steel);
        draw_rectangle(GUI_CX - 180, 954, GUI_CX + 180, 1020, true);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(GUI_CX, 987, _wlb_txt);
        draw_set_valign(fa_top);
        if (touch_tapped(GUI_CX - 180, 954, GUI_CX + 180, 1020)) touch_press(vk_escape);
    }

    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}


// -----------------------------------------------------------------------------
// 6b. SHRINE OF TRIBUTE - interactive boon-purchase overlay
// -----------------------------------------------------------------------------
if (showing_shrine) {
    draw_set_alpha(0.95);
    draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);

    if (!shrine_revealed) {
    // --- Veiled altar: its nature stays hidden until the player chooses to approach.
    //     Leaving here forgoes the shrine entirely; approaching commits (a revealed
    //     curse then traps them). See the shrine block in Step_0. -------------------
    // Shrine splash art (M 07-09; restacked 07-10): the full-bleed tablet v2 was
    // covering its own title, so the band now sits BELOW the title (y170) and the
    // body text BELOW the band - no text ever draws over the art anymore.
    var _shr_x0 = GUI_CX - 400, _shr_y0 = 170, _shr_x1 = GUI_CX + 400, _shr_y1 = _shr_y0 + 448;
    draw_sprite_stretched(spr_shrine_splash_ancient_altar, 0, _shr_x0, _shr_y0, 800, 448);
    gpu_set_blendmode(bm_subtract);
    draw_rectangle_color(_shr_x0, _shr_y0 + 240, _shr_x1, _shr_y1, c_black, c_black, c_white, c_white, false);
    draw_rectangle_color(_shr_x0, _shr_y0, _shr_x0 + 70, _shr_y1, c_white, c_black, c_black, c_white, false);
    draw_rectangle_color(_shr_x1 - 70, _shr_y0, _shr_x1, _shr_y1, c_black, c_white, c_white, c_black, false);
    gpu_set_blendmode(bm_normal);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(150, 140, 170));
    draw_text(GUI_CX, 84, "An Ancient Altar");
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(180, 175, 195));
    draw_text(GUI_CX, 650, "A shrouded altar thrums with hidden power.");
    draw_text(GUI_CX, 706, "Its nature - blessing or curse - is veiled.");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(200, 160, 120));
    draw_text(GUI_CX, 790, "Approach and you are committed - a curse, once revealed, will not release you.");
    draw_set_color(c_ltgray);
    // Touch (8d): explicit APPROACH button; X chip = leave. Keyboard keeps the legend.
    if (input_device() == 2) {
        draw_set_color(make_color_rgb(38, 32, 20));
        draw_rectangle(GUI_CX - 210, 906, GUI_CX + 210, 972, false);
        draw_set_color(make_color_rgb(200, 160, 120));
        draw_rectangle(GUI_CX - 210, 906, GUI_CX + 210, 972, true);
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_text(GUI_CX, 924, "APPROACH THE ALTAR");
        if (touch_tapped(GUI_CX - 210, 906, GUI_CX + 210, 972)) touch_press(vk_enter);
    } else {
        ui_draw_key_legend(GUI_CX, 990, "Space / Enter: Approach the altar      Esc: Leave (forgo it)");
    }
    draw_set_halign(fa_center);
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    } else {
    var _is_curse = (shrine_kind == "curse");
    // Revealed splash: menacing Cursed Altar art vs the serene shrine (M 07-09).
    // Restacked 07-10 (M: "move options lower"): the tablet shrinks to a 560x314
    // band under the title, the offer rows sit fully BELOW the art (y490+, h132,
    // pitch 150). Only the scrimmed subtitle + gold/dust readout ride the band top.
    var _shr2_x0 = GUI_CX - 280, _shr2_y0 = 150, _shr2_x1 = GUI_CX + 280, _shr2_y1 = _shr2_y0 + 314;
    draw_sprite_stretched(_is_curse ? spr_shrine_splash_curse_altar : spr_shrine_splash_ancient_altar,
        0, _shr2_x0, _shr2_y0, 560, 314);
    gpu_set_blendmode(bm_subtract);
    draw_rectangle_color(_shr2_x0, _shr2_y0 + 190, _shr2_x1, _shr2_y1, c_black, c_black, c_white, c_white, false);
    draw_rectangle_color(_shr2_x0, _shr2_y0, _shr2_x0 + 50, _shr2_y1, c_white, c_black, c_black, c_white, false);
    draw_rectangle_color(_shr2_x1 - 50, _shr2_y0, _shr2_x1, _shr2_y1, c_black, c_white, c_white, c_black, false);
    var _shr2_sc = make_color_rgb(55, 55, 60);
    draw_rectangle_color(GUI_CX - 590, 150, GUI_CX + 590, 240, _shr2_sc, _shr2_sc, _shr2_sc, _shr2_sc, false);
    draw_rectangle_color(GUI_CX - 560, 158, GUI_CX + 560, 230, _shr2_sc, _shr2_sc, _shr2_sc, _shr2_sc, false);
    gpu_set_blendmode(bm_normal);
    if (_is_curse) {
        draw_set_font(fnt_ui_title);
        draw_set_color(make_color_rgb(205, 70, 70));
        draw_text(GUI_CX, 84, "Cursed Altar");
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(195, 160, 170));
        draw_text(GUI_CX, 162, "Embrace a curse to grow richer in spoils. Its burden lasts the whole run.");
    } else {
        draw_set_font(fnt_ui_title);
        draw_set_color(make_color_rgb(220, 185, 110));
        draw_text(GUI_CX, 84, "Shrine of Tribute");
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(165, 168, 188));
        draw_text(GUI_CX, 162, "Offer tribute for a boon that lasts this run. Boons vanish when the run ends.");
    }
    var _sg  = global.gold;
    var _sdu = variable_global_exists("rune_dust") ? global.rune_dust : 0;
    draw_set_font(ui_font(fnt_ui_small));
    // Centered line drawn in segments: "Rune Dust:" label light purple, values
    // stay gold (M 2026-07-07, matches the NPC screens' dust readouts).
    var _sh_g = "Gold: " + string(_sg) + "      ";
    var _sh_l = "Rune Dust:";
    var _sh_v = " " + string(_sdu);
    // Inline coin/dust glyphs lead their readouts (#19 - M-approved icons).
    var _sh_ic = 30;
    var _sh_x = GUI_CX - (string_width(_sh_g) + string_width(_sh_l) + string_width(_sh_v) + _sh_ic * 2) * 0.5;
    draw_set_halign(fa_left);
    draw_sprite_stretched(spr_icon_gold, 0, _sh_x, 197, 24, 24);
    draw_set_color(make_color_rgb(210, 200, 150));
    draw_text(_sh_x + _sh_ic, 198, _sh_g);
    draw_sprite_stretched(spr_icon_dust, 0, _sh_x + _sh_ic + string_width(_sh_g), 197, 24, 24);
    draw_set_color(make_color_rgb(195, 155, 255));
    draw_text(_sh_x + _sh_ic * 2 + string_width(_sh_g), 198, _sh_l);
    draw_set_color(make_color_rgb(210, 200, 150));
    draw_text(_sh_x + _sh_ic * 2 + string_width(_sh_g) + string_width(_sh_l), 198, _sh_v);
    draw_set_halign(fa_center);

    // --- V2 reroll chip (blessing altars only): one dust reshuffle per shrine.
    // Drawn beside the header band, right of the scrim (x1620..1856 sits clear of
    // the rows at x330..1590 and the centered readout). Tap = press R (arm/commit
    // handled in Step); grayed once used or when dust can't cover it.
    if (!_is_curse) {
        var _rr_cost  = shrine_reroll_cost();
        var _rr_can   = !shrine_rerolled && _sdu >= _rr_cost;
        var _rr_x0 = 1620, _rr_y0 = 158, _rr_x1 = 1856, _rr_y1 = 212;
        draw_set_color(_rr_can ? make_color_rgb(35, 30, 18) : make_color_rgb(22, 22, 26));
        draw_rectangle(_rr_x0, _rr_y0, _rr_x1, _rr_y1, false);
        draw_set_color(shrine_reroll_arm ? make_color_rgb(255, 230, 140)
            : (_rr_can ? make_color_rgb(200, 160, 120) : make_color_rgb(70, 70, 80)));
        draw_rectangle(_rr_x0, _rr_y0, _rr_x1, _rr_y1, true);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_halign(fa_center);
        if (shrine_rerolled) {
            draw_set_color(make_color_rgb(110, 110, 122));
            draw_text((_rr_x0 + _rr_x1) * 0.5, _rr_y0 + 14, "REROLLED");
        } else {
            var _rr_txt = (shrine_reroll_arm ? "CONFIRM " : "[R] REROLL ") + string(_rr_cost);
            var _rr_tw  = string_width(_rr_txt) + 26;
            var _rr_tx  = (_rr_x0 + _rr_x1) * 0.5 - _rr_tw * 0.5;
            draw_set_halign(fa_left);
            draw_set_color(_rr_can ? make_color_rgb(230, 220, 190) : make_color_rgb(120, 110, 110));
            draw_text(_rr_tx, _rr_y0 + 14, _rr_txt);
            draw_sprite_stretched(spr_icon_dust, 0, _rr_tx + string_width(_rr_txt) + 4, _rr_y0 + 13, 24, 24);
            draw_set_halign(fa_center);
        }
        // Touch: the chip is the button (arm on first tap, commit on second).
        if (input_device() == 2 && touch_tapped(_rr_x0, _rr_y0, _rr_x1, _rr_y1)) touch_press(ord("R"));
    }

    // Hover-inspect capture for the suggested "[3] Sacrifice ..." item; drawn last
    // (after the gothic frame) so the tooltip sits on top of everything.
    var _shrine_tip_item = undefined;
    var _shrine_tip_x    = 0;
    var _shrine_tip_y    = 0;

    var _sn = array_length(shrine_offers);
    if (_sn == 0) {
        draw_set_font(ui_font(fnt_ui));
        draw_set_color(make_color_rgb(150, 150, 170));
        draw_text(GUI_CX, 540, _is_curse
            ? "No curse remains to bind here. (Esc to leave.)"
            : "You already carry every boon. (Esc to leave.)");
    } else {
        draw_set_halign(fa_left);
        for (var _i = 0; _i < _sn; _i++) {
            var _ry   = 490 + _i * 150;
            var _ssel = (_i == shrine_cursor);

            if (_is_curse) {
                var _cd = curse_get(shrine_offers[_i]);
                // Rows sit below the art now (07-10) - solid fills, nothing shows through.
                draw_set_color(_ssel ? make_color_rgb(48, 22, 22) : make_color_rgb(20, 14, 14));
                draw_rectangle(330, _ry, 1590, _ry + 132, false);
                draw_set_color(_ssel ? make_color_rgb(205, 80, 80) : make_color_rgb(80, 45, 45));
                draw_rectangle(330, _ry, 1590, _ry + 132, true);

                draw_set_font(ui_font(fnt_ui));
                draw_set_color(make_color_rgb(235, 130, 130));
                draw_text(360, _ry + 10, _cd.name);
                draw_set_font(ui_font(fnt_ui_small));
                draw_set_color(make_color_rgb(210, 160, 160));
                draw_text(360, _ry + 56, "Curse:  " + _cd.desc);
                draw_set_color(make_color_rgb(150, 220, 150));
                draw_text(360, _ry + 94, "Reward: " + _cd.reward);
            } else {
                var _bd = boon_get(shrine_offers[_i]);
                // Rows sit below the art now (07-10) - solid fills, nothing shows through.
                draw_set_color(_ssel ? make_color_rgb(45, 38, 22) : make_color_rgb(22, 20, 16));
                draw_rectangle(330, _ry, 1590, _ry + 132, false);
                draw_set_color(_ssel ? make_color_rgb(220, 185, 110) : make_color_rgb(70, 62, 45));
                draw_rectangle(330, _ry, 1590, _ry + 132, true);

                draw_set_font(ui_font(fnt_ui));
                draw_set_color(make_color_rgb(235, 215, 150));
                draw_text(360, _ry + 10, _bd.name);
                draw_set_font(ui_font(fnt_ui_small));
                draw_set_color(make_color_rgb(190, 195, 210));
                draw_text(360, _ry + 52, _bd.desc);

                // Sharp Eye (C5): quoted prices go through shrine_boon_price so the
                // display always matches what boon_pay will actually charge.
                var _bcost   = shrine_boon_price(_bd.cost);
                var _gold_ok = _sg >= _bcost;
                var _dc      = boon_dust_cost(_bcost);
                var _dust_ok = _sdu >= _dc;
                var _ipick   = boon_item_tribute_pick(_bcost);
                draw_set_color(_gold_ok ? make_color_rgb(150, 220, 150) : make_color_rgb(150, 110, 110));
                var _p1_txt = "[1] " + string(_bcost) + "g";
                draw_text(360, _ry + 94, _p1_txt);
                draw_sprite_stretched(spr_icon_gold, 0, 360 + string_width(_p1_txt) + 8, _ry + 93, 24, 24);
                draw_set_color(_dust_ok ? make_color_rgb(150, 220, 150) : make_color_rgb(150, 110, 110));
                var _p2_txt = "[2] " + string(_dc) + " dust";
                draw_text(540, _ry + 94, _p2_txt);
                draw_sprite_stretched(spr_icon_dust, 0, 540 + string_width(_p2_txt) + 8, _ry + 93, 24, 24);
                draw_set_color((_ipick != undefined) ? make_color_rgb(150, 220, 150) : make_color_rgb(150, 110, 110));
                var _ip_txt = (_ipick != undefined)
                    ? ("[3] Sacrifice " + _ipick.item.name + " (" + item_rarity_name(_ipick.item.rarity) + ")")
                    : "[3] No item valuable enough";
                draw_text(780, _ry + 94, _ip_txt);
                // Hover-inspect the suggested sacrifice: the full item tooltip so the
                // player knows EXACTLY what they'd be giving up (picker still lets them
                // choose a different item after pressing 3).
                if (_ipick != undefined) {
                    var _shx = device_mouse_x_to_gui(0);
                    var _shy = device_mouse_y_to_gui(0);
                    draw_set_font(ui_font(fnt_ui_small));
                    if (_shx >= 780 && _shx <= 780 + string_width(_ip_txt)
                        && _shy >= _ry + 88 && _shy <= _ry + 124) {
                        _shrine_tip_item = _ipick.item;
                        _shrine_tip_x    = _shx;
                        _shrine_tip_y    = _shy;
                    }
                }
            }
        }
        draw_set_halign(fa_center);

        // Touch (8d, M 07-08 "no confirmation to click"): tap an offer row to
        // select it; on the SELECTED row a blessing pays via its [1]/[2]/[3]
        // price labels (simulated digit keys), a curse row is embraced by
        // tapping it again (simulated Enter). Rows: y = 490 + i*150, h 132.
        if (mouse_check_button_pressed(mb_left)) {
            var _tsx = device_mouse_x_to_gui(0);
            var _tsy = device_mouse_y_to_gui(0);
            for (var _tsi = 0; _tsi < _sn; _tsi++) {
                var _tsy0 = 490 + _tsi * 150;
                if (_tsx >= 330 && _tsx <= 1590 && _tsy >= _tsy0 && _tsy <= _tsy0 + 132) {
                    if (_tsi != shrine_cursor) {
                        shrine_cursor       = _tsi;
                        shrine_notification = "";
                        shrine_notification_fail = false;
                        shrine_curse_arm    = -1;
                    } else if (_is_curse) {
                        touch_press(vk_enter);
                    } else if (_tsy >= _tsy0 + 84) {
                        if      (_tsx >= 345 && _tsx < 540)  touch_press(ord("1"));
                        else if (_tsx >= 540 && _tsx < 780)  touch_press(ord("2"));
                        else if (_tsx >= 780 && _tsx < 1575) touch_press(ord("3"));
                    }
                    break;
                }
            }
        }
    }

    if (shrine_notification != "") {
        draw_set_font(ui_font(fnt_ui_small));
        // #13: failures (can't afford / no valid tribute / the altar's grip) draw RED.
        draw_set_color(shrine_notification_fail ? make_color_rgb(235, 80, 70)
            : (_is_curse ? make_color_rgb(225, 150, 150) : make_color_rgb(225, 200, 150)));
        // 07-10 restack: rows end at y922 (490 + 2*150 + 132) - the line sits
        // between the last row and the y990 key legend.
        draw_text(GUI_CX, 940, shrine_notification);
    } else if (!_is_curse && _sn > 0) {
        // V2 flavor whisper: the highlighted blessing's one-liner rides the empty
        // notification slot (the rows are too dense for a 4th text line each).
        var _flv_bd = boon_get(shrine_offers[shrine_cursor]);
        if (_flv_bd != undefined && variable_struct_exists(_flv_bd, "flavor")) {
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(170, 150, 120));
            draw_text(GUI_CX, 940, "\"" + _flv_bd.flavor + "\"");
        }
    }
    if (input_device() == 2) {
        // Touch instruction line (the offer rows + price labels are the buttons)
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(c_ltgray);
        draw_text(GUI_CX, 990, _is_curse
            ? ((_sn == 0) ? "No curse remains - X to leave"
                          : "Tap a curse to choose it - tap twice more to embrace  (the altar will not release you)")
            : "Tap a boon to choose it - then tap a price to pay");
    } else {
        ui_draw_key_legend(GUI_CX, 990, _is_curse
            ? ((_sn == 0)
                ? "No curse remains  -  Esc: Leave"
                : "W/S: Select     Enter: Embrace the curse - confirms twice  (the altar will not release you)")
            : "W/S: Select     1: Gold     2: Dust     3: Item     R: Reroll     Esc: Leave");
    }
    draw_set_halign(fa_center);

    // Ornate gothic rim (title y84, offer rows x330..1590, hint y990 - all inside the opening).
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    // Sacrifice hover tooltip - topmost, follows the cursor like the equipment screens.
    if (_shrine_tip_item != undefined) {
        ui_draw_item_tooltip(min(_shrine_tip_x + 24, 1300), min(_shrine_tip_y + 18, 500), _shrine_tip_item, undefined);
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    }   // end revealed branch
}


// -----------------------------------------------------------------------------
// 6c. EVENT ROOM - interactive stat-gated choice overlay (see SYSTEMS_EVENTS.md)
// -----------------------------------------------------------------------------
if (showing_event_choice && event_active != undefined) {
    // Atmosphere: the dungeon's own backdrop, heavily scrimmed, instead of a
    // flat black void (M: "event screens are incredibly barren", 2026-07-07).
    if (!dungeon_bg_draw("combat", 0.84)) {
        draw_set_alpha(0.95);
        draw_set_color(c_black);
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
        draw_set_alpha(1.0);
    }

    var _ev = event_active;

    // --- Atmosphere layer (M 07-08, staged pass 1: code-drawn; splash art can
    // layer on later for the best events) -------------------------------------
    // 1) Corner vignette: subtractive gradients darken the edges smoothly.
    gpu_set_blendmode(bm_subtract);
    var _vg = make_color_rgb(70, 70, 78);
    draw_rectangle_color(GUI_XL, 0, GUI_XR, 240, _vg, _vg, c_black, c_black, false);
    draw_rectangle_color(GUI_XL, GUI_H - 240, GUI_XR, GUI_H, c_black, c_black, _vg, _vg, false);
    draw_rectangle_color(GUI_XL, 0, 300, GUI_H, _vg, c_black, c_black, _vg, false);
    draw_rectangle_color(GUI_W - 300, 0, GUI_XR, GUI_H, c_black, _vg, _vg, c_black, false);
    gpu_set_blendmode(bm_normal);

    // 1b) #16 stage 2: M-approved splash art for the four starred events, a
    // cinematic band behind the title/body (400x224 source @2x, M approved all
    // four 07-08). Subtractive fades dissolve the lower edge before the choice
    // rows and the side edges into the scrim; a soft two-step subtractive band
    // sits behind the flavor text so it stays readable over the bright
    // centerpiece. Events without a panel keep the pure code-drawn pass.
    var _splash = -1;
    switch (_ev.id) {
        case "merchants_ghost":   _splash = spr_event_splash_merchants_ghost;   break;
        case "whispering_mirror": _splash = spr_event_splash_whispering_mirror; break;
        case "cursed_idol":       _splash = spr_event_splash_cursed_idol;       break;
        case "mysterious_font":   _splash = spr_event_splash_mysterious_font;   break;
        // Remaining 11 events, M approved 07-09 - every event now has a panel.
        case "abandoned_nest":    _splash = spr_event_splash_abandoned_nest;    break;
        case "arcane_locus":      _splash = spr_event_splash_arcane_locus;      break;
        case "collapsed_shrine":  _splash = spr_event_splash_collapsed_shrine;  break;
        case "forked_omen":       _splash = spr_event_splash_forked_omen;       break;
        case "gamblers_cache":    _splash = spr_event_splash_gamblers_cache;    break;
        case "runed_anvil":       _splash = spr_event_splash_runed_anvil;       break;
        case "starving_hound":    _splash = spr_event_splash_starving_hound;    break;
        case "strangers_memory":  _splash = spr_event_splash_strangers_memory;  break;
        case "trapped_corridor":  _splash = spr_event_splash_trapped_corridor;  break;
        case "vagrant_oracle":    _splash = spr_event_splash_vagrant_oracle;    break;
        case "wounded_wanderer":  _splash = spr_event_splash_wounded_wanderer;  break;
    }
    if (_splash != -1) {
        var _sp_x0 = GUI_CX - 400, _sp_y0 = 40, _sp_x1 = GUI_CX + 400, _sp_y1 = _sp_y0 + 448;
        draw_sprite_stretched(_splash, 0, _sp_x0, _sp_y0, 800, 448);
        gpu_set_blendmode(bm_subtract);
        // Bottom dissolve (fades to the dark scrim before the rows at y315+).
        draw_rectangle_color(_sp_x0, 300, _sp_x1, _sp_y1, c_black, c_black, c_white, c_white, false);
        // Side fades so the band has no hard vertical cut.
        draw_rectangle_color(_sp_x0, _sp_y0, _sp_x0 + 70, _sp_y1, c_white, c_black, c_black, c_white, false);
        draw_rectangle_color(_sp_x1 - 70, _sp_y0, _sp_x1, _sp_y1, c_black, c_white, c_white, c_black, false);
        // Readability band behind the body text (two nested steps = soft edge).
        var _sc = make_color_rgb(55, 55, 60);
        draw_rectangle_color(GUI_CX - 590, 150, GUI_CX + 590, 270, _sc, _sc, _sc, _sc, false);
        draw_rectangle_color(GUI_CX - 560, 165, GUI_CX + 560, 255, _sc, _sc, _sc, _sc, false);
        gpu_set_blendmode(bm_normal);
    }

    // 2) Giant faint drop-cap of the event's title, tinted its accent color - an
    // illuminated-manuscript motif that is unique per event with no art budget.
    draw_set_font(fnt_ui_title);
    draw_set_halign(fa_center); draw_set_valign(fa_middle);
    draw_set_alpha(0.10);
    draw_set_color(_ev.color);
    draw_text_transformed(GUI_CX, 560, string_char_at(_ev.title, 1), 9, 9, 0);
    draw_set_alpha(1.0);
    draw_set_valign(fa_top);

    // 3) Ambient particles, style keyed by event id. STATELESS: every position/
    // pulse derives from current_time + the particle index, nothing persisted.
    var _pstyle = "mist";
    switch (_ev.id) {
        case "cursed_idol": case "runed_anvil":                        _pstyle = "embers";   break;
        case "trapped_corridor": case "collapsed_shrine":              _pstyle = "falldust"; break;
        case "strangers_memory": case "gamblers_cache": case "forked_omen":
        case "arcane_locus": case "mysterious_font": case "whispering_mirror":
                                                                       _pstyle = "glints";   break;
        // wounded_wanderer / merchants_ghost / abandoned_nest / vagrant_oracle /
        // starving_hound and any future event default to drifting mist.
    }
    var _at = current_time / 1000;
    for (var _pi = 0; _pi < 18; _pi++) {
        var _aph = (_pi * 137.5) mod 977;   // cheap per-particle phase scramble
        if (_pstyle == "embers") {
            var _aex = 120 + ((_aph * 1.83) mod (GUI_W - 240)) + sin(_at * 1.4 + _aph) * 22;
            var _aey = GUI_H - ((_at * (34 + (_aph mod 27)) + _aph * 3) mod (GUI_H + 60));
            draw_set_alpha(0.32 + 0.2 * sin(_at * 3 + _aph));
            draw_set_color(merge_color(_ev.color, make_color_rgb(255, 170, 60), 0.5));
            draw_circle(_aex, _aey, 2 + (_pi mod 2), false);
        } else if (_pstyle == "falldust") {
            var _afx = 90 + ((_aph * 2.11) mod (GUI_W - 180));
            var _afy = ((_at * (26 + (_aph mod 19)) + _aph * 5) mod (GUI_H + 40)) - 20;
            draw_set_alpha(0.22);
            draw_set_color(make_color_rgb(150, 140, 120));
            draw_circle(_afx, _afy, 1.5, false);
        } else if (_pstyle == "glints") {
            var _agx = 140 + ((_aph * 1.97) mod (GUI_W - 280));
            var _agy = 150 + ((_aph * 3.31) mod (GUI_H - 300));
            draw_set_alpha(0.28 * (0.5 + 0.5 * sin(_at * (2 + (_pi mod 3)) + _aph)));
            draw_set_color(merge_color(_ev.color, c_white, 0.5));
            draw_rectangle(_agx - 1, _agy - 4, _agx + 1, _agy + 4, false);
            draw_rectangle(_agx - 4, _agy - 1, _agx + 4, _agy + 1, false);
        } else {   // mist
            var _amx = ((_at * (14 + (_aph mod 11)) + _aph * 7) mod (GUI_W + 500)) - 250;
            var _amy = 220 + ((_aph * 2.63) mod (GUI_H - 420));
            draw_set_alpha(0.05 + 0.02 * sin(_at + _aph));
            draw_set_color(merge_color(_ev.color, make_color_rgb(200, 205, 220), 0.7));
            draw_ellipse(_amx - 130, _amy - 30, _amx + 130, _amy + 30, false);
        }
    }
    draw_set_alpha(1.0);

    // Title + flavor body
    draw_set_font(fnt_ui_title);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(20, 24, 30));
    draw_text(962, 74, _ev.title);
    draw_set_color(_ev.color);
    draw_text(960, 72, _ev.title);

    // Divider under the title: twin rules meeting a small diamond, in the
    // event's accent color (echoes the codex/journal headers).
    draw_set_alpha(0.9);
    draw_set_color(_ev.color);
    draw_rectangle(GUI_CX - 280, 143, GUI_CX - 26, 145, false);
    draw_rectangle(GUI_CX + 26,  143, GUI_CX + 280, 145, false);
    var _dvy = 144;
    draw_triangle(GUI_CX - 12, _dvy, GUI_CX, _dvy - 9, GUI_CX + 12, _dvy, false);
    draw_triangle(GUI_CX - 12, _dvy, GUI_CX, _dvy + 9, GUI_CX + 12, _dvy, false);
    draw_set_alpha(1.0);

    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(185, 192, 208));
    draw_text_ext(GUI_CX, 168, ui_sentence(_ev.body), -1, 1140);

    if (event_phase == "result") {
        // Framed result panel (same visual language as the choice rows).
        var _rp_x0 = 480, _rp_x1 = 1440, _rp_y0 = 372, _rp_y1 = 876;
        draw_set_alpha(0.88);
        draw_set_color(make_color_rgb(20, 22, 32));
        draw_rectangle(_rp_x0, _rp_y0, _rp_x1, _rp_y1, false);
        draw_set_alpha(1.0);
        draw_set_color(_ev.color);
        draw_rectangle(_rp_x0, _rp_y0, _rp_x1, _rp_y1, true);
        draw_rectangle(_rp_x0 + 4, _rp_y0 + 4, _rp_x1 - 4, _rp_y1 - 4, true);

        draw_set_font(ui_font(fnt_ui));
        // Loot lines wear their loot's color (M 08-15: "rare gear" announced in
        // white read confusing) - split the joined result and tint any line
        // carrying a "[Rarity]" tag, "[Rune]" or "BOON:"; prose keeps the grey.
        var _rl_rest = ui_sentence(event_result_text);
        var _rl_y = _rp_y0 + 48;
        var _rl_w = _rp_x1 - _rp_x0 - 120;
        while (_rl_rest != "") {
            var _rl_nl   = string_pos("\n", _rl_rest);
            var _rl_line = (_rl_nl > 0) ? string_copy(_rl_rest, 1, _rl_nl - 1) : _rl_rest;
            _rl_rest     = (_rl_nl > 0) ? string_delete(_rl_rest, 1, _rl_nl) : "";
            var _rl_col = make_color_rgb(215, 220, 235);
            for (var _rl_r = 4; _rl_r >= 0; _rl_r--) {
                if (string_pos("[" + item_rarity_name(_rl_r) + "]", _rl_line) > 0) { _rl_col = item_rarity_color(_rl_r); break; }
            }
            if (string_pos("[Rune]", _rl_line) > 0) _rl_col = make_color_rgb(190, 120, 220);
            if (string_pos("BOON:", _rl_line) > 0)  _rl_col = make_color_rgb(255, 205, 110);
            draw_set_color(_rl_col);
            draw_text_ext(GUI_CX, _rl_y, _rl_line, -1, _rl_w);
            _rl_y += max(string_height_ext(_rl_line, -1, _rl_w), string_height("Ag"));
        }

        // Coin burst: shared draw-side sim (ui_draw_coin_burst, #19 polish -
        // also runs on the treasure popup). Pile floor sits on the panel.
        if (array_length(event_coins) > 0) {
            ui_draw_coin_burst(event_coins, _rp_y1 - 66);
        }

        if (input_device() == 2) {
            // Touch: framed CONTINUE button (M 07-08) - result also closes on
            // any tap, the button is the visible control.
            ui_draw_touch_continue(GUI_CX, 900);
        } else {
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(c_ltgray);
            draw_text(GUI_CX, 972, ((input_device() == 2) ? "Tap to continue" : "Press Enter to continue"));
        }
    } else {
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(210, 200, 150));
        draw_text(GUI_CX, 252, "Gold: " + string(global.gold));

        draw_set_halign(fa_left);
        // Choice rows (M 07-09 restyle): TRANSLUCENT fills so the splash art and
        // vignette stay visible behind them - the old opaque slabs buried the art.
        // Tighter rows (132px, 150 pitch) trim the dead space; four choices now end
        // at y930, clear of the footer (opaque rows at 165 pitch reached y975).
        var _en = array_length(_ev.choices);
        for (var _i = 0; _i < _en; _i++) {
            var _ch       = _ev.choices[_i];
            var _unlocked = event_choice_unlocked(_ch);
            var _ry       = 330 + _i * 150;
            var _csel     = (_i == event_cursor);

            draw_set_alpha(_csel ? 0.80 : 0.55);
            draw_set_color(_csel ? make_color_rgb(38, 44, 58) : make_color_rgb(20, 22, 32));
            draw_rectangle(330, _ry, 1590, _ry + 132, false);
            draw_set_alpha(1.0);
            draw_set_color(_csel ? _ev.color : make_color_rgb(58, 62, 80));
            draw_rectangle(330, _ry, 1590, _ry + 132, true);

            // Label + hint
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(_unlocked ? make_color_rgb(236, 240, 250) : make_color_rgb(110, 112, 122));
            draw_text(360, _ry + 12, ui_sentence(_ch.label));
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(_unlocked ? make_color_rgb(178, 186, 204) : make_color_rgb(92, 94, 104));
            draw_text(360, _ry + 60, ui_sentence(_ch.hint));

            // Generated mechanics line under the lore hint: odds + what each
            // outcome actually grants, so the player understands the bet.
            draw_set_color(_unlocked ? make_color_rgb(150, 200, 230) : make_color_rgb(80, 90, 112));
            draw_text(360, _ry + 96, event_choice_mechanics_text(_ch));

            // Right-side info: gold cost / check odds / lock reason
            draw_set_halign(fa_right);
            if (!_unlocked) {
                draw_set_color(make_color_rgb(205, 110, 110));
                var _lock = (_ch.req_stat != "" && player_effective_stat(_ch.req_stat) < _ch.req_amount)
                    ? ("NEED " + _ch.req_stat + " " + string(_ch.req_amount))
                    : "NOT ENOUGH GOLD";
                draw_text(1560, _ry + 15, _lock);
            } else {
                var _info = "";
                var _cost = event_choice_cost(_ch);
                if (_cost > 0) _info = string(_cost) + "g";
                if (_ch.resolve == "check") {
                    var _pct = event_check_chance(_ch.check_stat, _ch.check_base, _ch.check_per, _ch.check_ref);
                    _info = (_info != "" ? _info + "    " : "") + _ch.check_stat + " " + string(_pct) + "%";
                }
                if (_info != "") {
                    draw_set_color(make_color_rgb(150, 200, 230));
                    draw_text(1560, _ry + 15, _info);
                }
            }
            draw_set_halign(fa_left);
        }

        // Touch (8d follow-up, M 07-08 SOFTLOCK: "event room doesnt register my
        // touches"): tap a choice row to select it, tap the selected row again
        // to choose it (simulated Enter - the existing confirm handler pays the
        // cost/rolls the check). Locked rows ignore taps. Same idiom as the
        // shrine offer rows. Rows: y = 330 + i*150, h 132, x 330..1590 (kept in
        // sync with the translucent row draw above).
        if (mouse_check_button_pressed(mb_left)) {
            var _tex = device_mouse_x_to_gui(0);
            var _tey = device_mouse_y_to_gui(0);
            for (var _ti = 0; _ti < _en; _ti++) {
                var _ty0 = 330 + _ti * 150;
                if (_tex >= 330 && _tex <= 1590 && _tey >= _ty0 && _tey <= _ty0 + 132) {
                    if (event_choice_unlocked(_ev.choices[_ti])) {
                        if (_ti != event_cursor) event_cursor = _ti;
                        else                     touch_press(vk_enter);
                    }
                    break;
                }
            }
        }

        draw_set_halign(fa_center);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(c_ltgray);
        if (input_device() == 2) {
            draw_text(GUI_CX, 972, "Tap a choice - tap it again to commit");
        } else {
            ui_draw_key_legend(GUI_CX, 972, "W/S: Select     Enter: Choose");
        }
    }

    // Ornate gothic rim (choice rows x330..1590, hint y972 - all inside the opening).
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}


// -----------------------------------------------------------------------------
// 7. FOOTER INSTRUCTIONS
// E to extract is only shown after the floor boss is defeated.
// -----------------------------------------------------------------------------
var _boss_cleared = false;
for (var _fi = 0; _fi < array_length(current_rooms); _fi++) {
    if (current_rooms[_fi].type == "boss" && current_rooms[_fi].cleared) {
        _boss_cleared = true;
        break;
    }
}

// Touch: the chip bar (JOURNAL/HERO/.../EXTRACT) replaces this keyboard footer
// outright - both drew in the same bottom strip (M 07-08: "chips clearly on
// top of the keyboard legend").
if (input_device() != 2) {
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_halign(fa_center);
    draw_set_valign(fa_bottom);

    draw_set_color(c_gray);
    // M 08-13 (HTML5): the floor map never listed the menu keys - I/J were
    // invisible controls. Only VERIFIED floor-map keys are listed (T/O are
    // hub-only; advertising dead keys is worse than omitting them).
    draw_text(GUI_CX, 1073, "WASD: Move   Enter: Enter Room   I: Hero   J: Journal   P: Companion");

    if (_boss_cleared) {
        draw_set_color(c_gray);
        draw_text_outline(GUI_CX, 1047, "E: Extract to Camp");
    } else {
        draw_set_color(make_color_rgb(45, 50, 60));
        draw_text(GUI_CX, 1047, "E: Extract  [Defeat the boss first]");
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// Player HP + gold readout (top-left). Drawn AFTER the event/shrine overlays (which
// dim the whole screen) so it stays visible during them - many events gamble HP and
// gold, so the player needs both at a glance. Drawn BEFORE the character/pause menus
// so those full overlays still cover it (they show HP/gold themselves).
var _hud_max_hp = out_of_combat_max_hp();
var _hud_hp     = (variable_global_exists("run_current_hp") && global.run_current_hp > 0)
                  ? min(global.run_current_hp, _hud_max_hp) : _hud_max_hp;
draw_set_font(ui_font(fnt_ui));
draw_set_halign(fa_left);
draw_set_valign(fa_top);
// Bright flash while the HP-hit jolt runs, then the usual muted red.
draw_set_color((hp_shake_timer > 0) ? make_color_rgb(255, 70, 60) : make_color_rgb(225, 95, 95));
draw_text(30, 30, "HP: " + string(_hud_hp) + " / " + string(_hud_max_hp));
// Floating "-N" from an event HP hit: rises off the readout and fades.
if (hp_hit_popup != undefined) {
    hp_hit_popup.timer--;
    if (hp_hit_popup.timer <= 0) {
        hp_hit_popup = undefined;
    } else {
        var _hpp_y = 30 - (90 - hp_hit_popup.timer) * 0.55;
        draw_set_alpha(min(1, hp_hit_popup.timer / 30));
        draw_set_color(make_color_rgb(255, 90, 70));
        draw_text(30 + string_width("HP: " + string(_hud_hp) + " / " + string(_hud_max_hp)) + 18,
                  _hpp_y, "-" + string(hp_hit_popup.value));
        draw_set_alpha(1.0);
    }
}
draw_set_color(c_yellow);
// Split the readout: banked total vs gold FOUND THIS RUN (the at-risk share you
// lose most of on death). "Gold: 812g (+130g this run - at risk)".
var _hud_run_gold = variable_global_exists("current_run_gold") ? global.current_run_gold : 0;
if (_hud_run_gold > 0) {
    draw_text(30, 66, "Gold: " + string(global.gold) + "g");
    draw_set_color(make_color_rgb(225, 180, 90));
    draw_text(30 + string_width("Gold: " + string(global.gold) + "g") + 14, 66,
              "(+" + string(_hud_run_gold) + "g this run - at risk)");
} else {
    draw_text(30, 66, "Gold: " + string(global.gold) + "g");
}
draw_set_color(c_white);
draw_set_font(-1);

// -----------------------------------------------------------------------------
// ESCAPE ITEM (Genie Lamp / Devil Wine): carry hint + confirm popup.
// -----------------------------------------------------------------------------
var _esc_have = undefined;
if (variable_global_exists("consumable_inventory")) {
    for (var _ehi = 0; _ehi < array_length(global.consumable_inventory); _ehi++) {
        var _eh_t = global.consumable_inventory[_ehi].effect_type;
        if (_eh_t == "escape_lamp") { _esc_have = global.consumable_inventory[_ehi]; break; }
        if (_eh_t == "escape_wine" && _esc_have == undefined) _esc_have = global.consumable_inventory[_ehi];
    }
}
if (_esc_have != undefined && !showing_event && !showing_shrine && !showing_treasure
    && !showing_event_choice && !escape_confirm_open) {
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(170, 150, 220));
    draw_text(30, 102, "[G] Use " + _esc_have.name + "  (escape with your loot)");
    draw_set_color(c_white);
    draw_set_font(-1);
}
if (escape_confirm_open && escape_confirm_idx >= 0
    && escape_confirm_idx < array_length(global.consumable_inventory)) {
    var _ec_it   = global.consumable_inventory[escape_confirm_idx];
    var _ec_wine = (_ec_it.effect_type == "escape_wine");
    draw_set_alpha(0.65); draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(0.96); draw_set_color(_ec_wine ? make_color_rgb(34, 14, 16) : make_color_rgb(20, 22, 36));
    draw_rectangle(510, 360, 1410, 690, false);
    draw_set_alpha(1.0); draw_set_color(_ec_wine ? make_color_rgb(200, 80, 80) : make_color_rgb(150, 140, 220));
    draw_rectangle(510, 360, 1410, 690, true);
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(c_white);
    draw_text(960, 393, _ec_wine ? "Drink the Devil Wine?" : "Rub the Genie Lamp?");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(190, 195, 215));
    draw_text_ext(960, 456, _ec_wine
        ? "You extract to camp with ALL your loot and found gold...\nbut PERMANENTLY lose 2 random stat points. The wine always collects."
        : "A lazy plume of smoke swallows you.\nYou extract to camp with ALL your loot and found gold. No cost - this once.", 30, 780);
    draw_set_color(make_color_rgb(150, 160, 185));
    if (input_device() == 2) {
        // Touch: tap the panel to drink/rub, tap outside to cancel (the popup
        // was Enter-only - unconfirmable from the G chip on a phone).
        draw_text(960, 621, "Tap here to confirm - tap outside to cancel");
        if (mouse_check_button_pressed(mb_left)) {
            var _ecmx = device_mouse_x_to_gui(0);
            var _ecmy = device_mouse_y_to_gui(0);
            if (_ecmx >= 510 && _ecmx <= 1410 && _ecmy >= 360 && _ecmy <= 690) touch_press(vk_enter);
            else                                                               touch_press(vk_escape);
        }
    } else {
        ui_draw_key_legend(960, 621, "Enter: Confirm      Esc / G: Cancel");
    }
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_font(-1);
}

// -----------------------------------------------------------------------------
// EXTRACT CONFIRM (#3) - same idiom as the escape-item confirm above.
// -----------------------------------------------------------------------------
if (extract_confirm_open) {
    draw_set_alpha(0.65); draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(0.96); draw_set_color(make_color_rgb(16, 32, 18));
    draw_rectangle(510, 360, 1410, 690, false);
    draw_set_alpha(1.0); draw_set_color(make_color_rgb(70, 170, 90));
    draw_rectangle(510, 360, 1410, 690, true);
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(c_white);
    draw_text(960, 393, "Extract to camp?");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(190, 195, 215));
    draw_text_ext(960, 456,
        "The run ends here. You keep all your loot and found gold -\ndeeper floors (and their richer bosses) wait for another day.", 30, 780);
    // Carried banshee bottles: remind the player what makes it out with them.
    banshee_init();
    if (global.banshee_carried > 0) {
        draw_set_color(make_color_rgb(150, 235, 235));
        draw_text(960, 552, "Carrying: Banshee in a Bottle x" + string(global.banshee_carried)
            + "  (banks to Maren on extraction)");
    }
    draw_set_color(make_color_rgb(150, 160, 185));
    if (input_device() == 2) {
        draw_text(960, 621, "Tap here to confirm - tap outside to cancel");
        if (mouse_check_button_pressed(mb_left)) {
            var _xcmx = device_mouse_x_to_gui(0);
            var _xcmy = device_mouse_y_to_gui(0);
            if (_xcmx >= 510 && _xcmx <= 1410 && _xcmy >= 360 && _xcmy <= 690) touch_press(vk_enter);
            else                                                               touch_press(vk_escape);
        }
    } else {
        ui_draw_key_legend(960, 621, "Enter: Confirm      Esc / E: Cancel");
    }
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_font(-1);
}

// -----------------------------------------------------------------------------
// LEAVE-WITHOUT-CHOOSING CONFIRM (M 08-13) - same idiom as the confirms above.
// Armed by the shrine / whetstone Esc paths; drawn last so it tops their
// overlays. A stray Esc can no longer forfeit a one-per-run room.
// -----------------------------------------------------------------------------
if (leave_confirm_open) {
    draw_set_alpha(0.65); draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(0.96); draw_set_color(make_color_rgb(30, 24, 16));
    draw_rectangle(510, 380, 1410, 670, false);
    draw_set_alpha(1.0); draw_set_color(make_color_rgb(200, 165, 90));
    draw_rectangle(510, 380, 1410, 670, true);
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(c_white);
    draw_text(960, 413, "Leave without choosing?");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(190, 195, 215));
    draw_text_ext(960, 476, (leave_confirm_kind == "whetstone")
        ? "The stone hones one edge per run - walk away now and it offers nothing.\nThis room will not open again."
        : "The altar will not offer again this run.\nLeave now and its gifts are forfeit.", 30, 780);
    draw_set_color(make_color_rgb(150, 160, 185));
    if (input_device() == 2) {
        draw_text(960, 601, "Tap here to leave - tap outside to stay");
        if (mouse_check_button_pressed(mb_left)) {
            var _lcmx = device_mouse_x_to_gui(0);
            var _lcmy = device_mouse_y_to_gui(0);
            if (_lcmx >= 510 && _lcmx <= 1410 && _lcmy >= 380 && _lcmy <= 670) input_inject("lvc:ok");
            else                                                               input_inject("lvc:stay");
        }
    } else {
        ui_draw_key_legend(960, 601, "Enter: Leave      Esc: Stay");
    }
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_font(-1);
}

// -----------------------------------------------------------------------------
// SHRINE CLAIM CELEBRATION - sparkle flutter + "what just happened" popup.
// Procedural (no particle system): each sparkle's path derives from its index +
// the per-claim seed, so no state array is needed. Fades over the last 40 frames.
// -----------------------------------------------------------------------------
if (shrine_celebrate_timer > 0) {
    shrine_celebrate_timer--;
    var _cel_t     = 150 - shrine_celebrate_timer;              // frames since claim
    var _cel_fade  = min(1, shrine_celebrate_timer / 40);       // tail fade-out
    var _cel_cx    = GUI_CX;
    var _cel_cy    = 430;

    // Popup panel
    var _cel_w = max(720, string_width(shrine_celebrate_sub) + 120);
    draw_set_alpha(0.92 * _cel_fade);
    draw_set_color(make_color_rgb(26, 22, 12));
    draw_rectangle(_cel_cx - _cel_w / 2, _cel_cy - 78, _cel_cx + _cel_w / 2, _cel_cy + 66, false);
    draw_set_alpha(_cel_fade);
    draw_set_color(make_color_rgb(230, 190, 90));
    draw_rectangle(_cel_cx - _cel_w / 2, _cel_cy - 78, _cel_cx + _cel_w / 2, _cel_cy + 66, true);
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(255, 225, 140));
    draw_text(_cel_cx, _cel_cy - 57, shrine_celebrate_title);
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(215, 220, 235));
    draw_text_ext(_cel_cx, _cel_cy - 9, shrine_celebrate_sub, 27, _cel_w - 60);
    draw_set_halign(fa_left); draw_set_valign(fa_top);

    // Sparkle flutter: 26 golden motes rising and drifting around the panel.
    gpu_set_blendmode(bm_add);
    for (var _sp = 0; _sp < 26; _sp++) {
        var _ph   = (shrine_celebrate_seed * 0.37 + _sp * 12.9898) mod (2 * pi);
        var _rate = 0.7 + 0.5 * ((_sp * 7 + shrine_celebrate_seed) mod 10) / 10;
        var _sx   = _cel_cx + sin(_ph + _cel_t * 0.017 * _rate) * (120 + (_sp mod 8) * 46);
        var _sy   = _cel_cy + 40 - _cel_t * (0.9 + _rate) + cos(_ph * 3 + _cel_t * 0.05) * 26;
        var _tw   = 0.35 + 0.65 * abs(sin(_ph * 5 + _cel_t * 0.21 * _rate));   // twinkle
        draw_set_alpha(_tw * _cel_fade * 0.9);
        draw_set_color((_sp mod 3 == 0) ? c_white : make_color_rgb(255, 214, 110));
        var _sr = 2 + (_sp mod 3);
        draw_circle(_sx, _sy, _sr, false);
        // 4-point star cross on the larger motes
        if (_sp mod 3 == 2) {
            draw_line(_sx - _sr * 2.4, _sy, _sx + _sr * 2.4, _sy);
            draw_line(_sx, _sy - _sr * 2.4, _sx, _sy + _sr * 2.4);
        }
    }
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1.0);
    draw_set_color(c_white);
}

ui_draw_character_menu();

// Item-sacrifice picker modal - topmost (Shrine item tribute)
ui_draw_item_picker();

// Consumable overflow discard prompt (pack-full pickup)
ui_draw_consumable_overflow();

// J-key Journal overlay (Phase 4a) - view/track mid-run; actions are hub-only.
ui_draw_journal();

// Full Item Codex gallery - opens from the Journal's codex tab mid-run too
// (07-28: M's hardcore test couldn't reach it at camp).
ui_draw_item_codex();

// P-key companion inspect (M 07-08) - the full pet profile as an overlay.
if (instance_exists(obj_game_controller)) {
    var _gc_pi = instance_find(obj_game_controller, 0);
    if (variable_instance_exists(_gc_pi, "pet_inspect_open") && _gc_pi.pet_inspect_open
        && pet_active() != undefined) {
        ui_draw_pet_detail(pet_active());
        draw_set_halign(fa_center);
        draw_set_font(ui_font(fnt_ui_small));
        draw_set_color(make_color_rgb(140, 150, 175));
        ui_draw_key_legend(GUI_CX, 1044, "P / Esc: Close");
        draw_set_halign(fa_left);
        draw_set_font(-1);
    }
}

// IRONMAN resume (SYSTEMS_RUN_RESUME.md): re-offered boss EXTRACT/CONTINUE
// choice. Bordered overlay popup (standing checkout rule), arm-then-confirm;
// hit-tests live here in Draw (touch rule) and inject tags for the Step.
if (showing_extract) {
    draw_set_alpha(0.66);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    var _fx0 = 560, _fy0 = 372, _fx1 = 1360, _fy1 = 708;
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(22, 20, 30));
    draw_rectangle(_fx0, _fy0, _fx1, _fy1, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(200, 170, 110));
    draw_rectangle(_fx0, _fy0, _fx1, _fy1, true);
    draw_rectangle(_fx0 + 6, _fy0 + 6, _fx1 - 6, _fy1 - 6, true);
    var _fx_desc = variable_global_exists("descent_active") && global.descent_active;
    draw_set_halign(fa_center);
    draw_set_font(ui_font(fnt_ui));
    draw_set_color(make_color_rgb(255, 225, 150));
    draw_text((_fx0 + _fx1) / 2, _fy0 + 24, _fx_desc ? "THE FLOOR LIES QUIET" : "THE FLOOR IS CLEARED");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(210, 214, 228));
    var _fx_body = "You return where the dive was interrupted - the boss of floor "
        + string(global.current_floor) + " is slain and the choice still stands.\n"
        + (_fx_desc ? "Retreat to bank everything you carry, or descend deeper into the dark."
                    : "Extract to bank everything you carry, or press on to the next floor.");
    if (extract_arm != "") {
        _fx_body += "\n\nPress again to confirm.";
    }
    draw_text_ext((_fx0 + _fx1) / 2, _fy0 + 84, _fx_body, 30, (_fx1 - _fx0) - 90);
    draw_set_halign(fa_left);
    var _fmx = device_mouse_x_to_gui(0), _fmy = device_mouse_y_to_gui(0);
    var _fmp = mouse_check_button_pressed(mb_left);
    var _fx_col_e = (extract_arm == "extract")  ? make_color_rgb(190, 255, 200) : make_color_rgb(120, 210, 130);
    var _fx_col_c = (extract_arm == "continue") ? make_color_rgb(255, 220, 150) : make_color_rgb(200, 170, 110);
    ui_confirm_button(_fx0 + 60, _fy1 - 90, (_fx0 + _fx1) / 2 - 30, _fy1 - 24,
        (_fx_desc ? "RETREAT" : "EXTRACT") + "  [E]", _fx_col_e, _fmx, _fmy, _fmp, "fxresume:extract");
    ui_confirm_button((_fx0 + _fx1) / 2 + 30, _fy1 - 90, _fx1 - 60, _fy1 - 24,
        (_fx_desc ? "DESCEND" : "CONTINUE") + "  [Enter]", _fx_col_c, _fmx, _fmy, _fmp, "fxresume:continue");
    draw_set_font(-1);
}

// Pause / Esc menu + its Settings sub-screen (drawn here since the floor doesn't
// otherwise host the settings overlay during a run)
if (variable_global_exists("settings_open") && global.settings_open) ui_draw_settings_overlay();
ui_draw_pause_menu();

// Onboarding coach-mark - drawn last so it sits on top of the floor + shrine overlay.
ui_draw_tutorial_tip();

// Trait unlock toast (08-04): was hub-only; now shows wherever it fires.
// Shared ui_draw_toast; centered, so it clears the top-LEFT HP/gold band.
if (instance_exists(obj_game_controller)) {
    var _gc_tn = instance_find(obj_game_controller, 0);
    if (_gc_tn.trait_notif_timer > 0 && _gc_tn.trait_notif_msg != "") {
        ui_draw_toast(_gc_tn.trait_notif_msg, GUI_CX, 21,
                      min(1.0, _gc_tn.trait_notif_timer / 30.0), c_white);
    }
}

// Touch (8d): action-chip bar, then the Back/menu chip + key pump - always LAST (topmost).
ui_draw_touch_chips();
ui_draw_touch_back();
ui_draw_touch_gamepad();   // on-screen d-pad in the left gutter (M 07-17)

// Reset the HP-hit shake translate so objects drawing after us are unshaken.
matrix_set(matrix_world, matrix_build_identity());


// =============================================================================
// MERCHANT'S GHOST SHOP overlay (M-locked 08-15) - drawn dead last, topmost.
// A fanciful spectral stall: every row leads with its icon, names wear their
// rarity colors, ghost exclusives carry a gold tag. Geometry mirrored by the
// Step input block (rows y262, pitch 102, height 92 - six rows end at y864,
// clear of the key legend at y900; the old 108 pitch ran row 6 into it).
// =============================================================================
if (variable_instance_exists(id, "ghost_shop_open") && ghost_shop_open) {
    draw_set_alpha(0.78);
    draw_set_color(make_color_rgb(6, 10, 18));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(16, 22, 34));
    draw_rectangle(480, 150, 1440, 940, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(100, 160, 230));
    draw_rectangle(480, 150, 1440, 940, true);
    draw_rectangle(486, 156, 1434, 934, true);
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(160, 205, 250));
    draw_text(960, 172, "THE GHOST'S WARES");
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(140, 160, 190));
    draw_text(960, 222, "\"Everything must go. Everything already went, once.\"");
    draw_set_halign(fa_right);
    draw_set_color(c_yellow);
    draw_set_font(ui_font(fnt_ui));
    draw_text(1400, 176, "Gold: " + string(global.gold) + "g");
    draw_set_halign(fa_left);
    var _gsd = global.ghost_stock;
    for (var _gd = 0; _gd < array_length(_gsd); _gd++) {
        var _row = _gsd[_gd];
        var _gry = 262 + _gd * 102;
        var _gsel = (_gd == ghost_cursor);
        draw_set_color(_gsel ? make_color_rgb(30, 40, 60) : make_color_rgb(20, 26, 40));
        draw_rectangle(530, _gry, 1390, _gry + 92, false);
        draw_set_color(_row.sold ? make_color_rgb(50, 56, 70)
                     : (_gsel ? make_color_rgb(120, 180, 245) : make_color_rgb(52, 66, 92)));
        draw_rectangle(530, _gry, 1390, _gry + 92, true);
        var _dimc = _row.sold ? 0.35 : 1.0;
        draw_set_alpha(_dimc);
        if (_row.kind == "item") {
            ui_draw_item_icon(544, _gry + 12, 72, _row.item);
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(item_rarity_color(_row.item.rarity));
            var _nm = _row.item.name;
            draw_text(636, _gry + 10, _nm);
            // Measure the name in the font it was DRAWN in (fnt_ui) before switching to
            // the small tag font - measuring after the switch under-sized the gap and
            // ran the tag into the name (M 08-18 shot).
            var _nm_w = string_width(_nm);
            if (variable_struct_exists(_row.item, "ghost_exclusive")) {
                draw_set_font(ui_font(fnt_ui_small));
                draw_set_color(make_color_rgb(255, 210, 120));
                draw_text(636 + _nm_w + 24, _gry + 16, "GHOST EXCLUSIVE");
                draw_set_font(ui_font(fnt_ui));
            }
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(160, 168, 188));
            draw_text(636, _gry + 54, ui_truncate(ui_item_stat_str(_row.item), 560));
        } else {
            var _rspr = rune_icon_sprite(_row.rune.id);
            if (_rspr != -1 && sprite_exists(_rspr)) {
                draw_sprite_stretched(_rspr, 0, 544, _gry + 12, 72, 72);
            } else {
                var _rgc = rune_glyph_color(_row.rune.id);
                draw_set_color(_rgc);
                draw_triangle(556, _gry + 48, 580, _gry + 18, 604, _gry + 48, false);
                draw_triangle(556, _gry + 48, 580, _gry + 78, 604, _gry + 48, false);
            }
            draw_set_font(ui_font(fnt_ui));
            draw_set_color(make_color_rgb(200, 150, 240));
            draw_text(636, _gry + 10, rune_title(_row.rune) + "   [Rune]");
            draw_set_font(ui_font(fnt_ui_small));
            draw_set_color(make_color_rgb(160, 168, 188));
            draw_text(636, _gry + 54, ui_truncate(rune_effect(_row.rune), 560));
        }
        draw_set_halign(fa_right);
        draw_set_font(ui_font(fnt_ui));
        if (_row.sold) {
            draw_set_color(make_color_rgb(110, 116, 130));
            draw_text(1370, _gry + 32, "SOLD");
        } else {
            draw_set_color((global.gold >= _row.price) ? c_yellow : make_color_rgb(220, 100, 90));
            draw_text(1370, _gry + 32, string(_row.price) + "g");
        }
        draw_set_halign(fa_left);
        draw_set_alpha(1.0);
    }
    draw_set_halign(fa_center);
    draw_set_font(ui_font(fnt_ui_small));
    draw_set_color(make_color_rgb(120, 140, 170));
    ui_draw_key_legend(960, 900, "W/S: Choose   Enter/Click: Buy   Esc: Leave the cart");
    draw_set_halign(fa_left);
}
