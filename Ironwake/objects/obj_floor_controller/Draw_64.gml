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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
}


// -----------------------------------------------------------------------------
// 2. HEADER
// -----------------------------------------------------------------------------
draw_set_font(fnt_ui_title);
draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_text(GUI_CX, 30, "FLOOR " + string(global.current_floor) + " OF 3");
draw_set_font(fnt_ui);
draw_set_color(make_color_rgb(160, 140, 110));
var _dung_id = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
var _dung_display_name = "The Ashen Vault";
if (_dung_id == "scorched_depths")  _dung_display_name = "Scorched Depths";
else if (_dung_id == "tundra_tomb") _dung_display_name = "Tundra Tomb";
draw_text(GUI_CX, 84, _dung_display_name);
draw_set_halign(fa_left);

// Awakening tier reference - top-right, matches the combat screen label.
var _awk_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
draw_set_font(fnt_ui_small);
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

// --- Pass 2: Node boxes ---
draw_set_font(fnt_ui_small);
for (var _i = 0; _i < _count; _i++) {
    var _room   = current_rooms[_i];
    var _is_sel = (_i == selected_room);
    var _nx     = _room.px - _NW * 0.5;
    var _ny     = _room.py - _NH * 0.5;
    var _acc    = _accessible[_i];            // enterable THIS step (frontier)
    var _reach  = _reachable[_i];             // still on a takeable path
    var _future = _reach && !_acc && !_room.cleared;  // reachable but not yet open
    var _dead   = !_reach && !_room.cleared;  // abandoned branch - unselectable

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

    // Node border (no white select ring on a dead room - it isn't selectable)
    if (_is_sel && !_dead) {
        draw_set_color(c_white);
        draw_rectangle(_nx - 3, _ny - 3, _nx + _NW + 3, _ny + _NH + 3, true);
    }
    var _border_col = make_color_rgb(34, 38, 50);   // dead / cleared default
    if (_acc)         _border_col = _tc;
    else if (_future) _border_col = make_color_rgb(62, 68, 88);
    draw_set_color(_border_col);
    draw_rectangle(_nx, _ny, _nx + _NW, _ny + _NH, true);

    // Room name (single line, clipped to the box)
    var _name_str = _room.name;
    if (_room.cleared) _name_str = "✓ " + _name_str;
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
    }
    draw_set_halign(fa_right);
    draw_set_valign(fa_bottom);
    draw_set_color(_acc ? _tc : make_color_rgb(40, 46, 62));
    draw_text(_nx + _NW - 9, _ny + _NH - 6, _tl);

    // Sense trait: show extra difficulty hint for uncleared accessible rooms
    if (!_room.cleared && _acc && trait_active("Sense")) {
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
draw_set_font(fnt_ui);
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
}
draw_set_font(fnt_ui_small);
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
        _det_desc = "A sheltered alcove.\nYou may rest and recover here.\n+" + string(15 + 4 * (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0)) + " HP +5% max HP at next combat."; break;
    case "event":
        _det_desc = "A choice awaits - risk and\nreward in equal measure.\nYour stats may tip the odds."; break;
    case "boss":
        _det_desc = "The dungeon guardian waits.\nDefeat it to clear the floor."; break;
}
draw_set_font(fnt_ui);
draw_set_color(make_color_rgb(170, 180, 200));
draw_text_ext(_ddx, _ddy + 90, _det_desc, -1, _dp_w - 54);

// Accessible / cleared status
draw_set_font(fnt_ui_small);
var _sel_acc = _accessible[selected_room];
if (_sel.cleared) {
    draw_set_color(c_gray);
    draw_text(_ddx, _ddy + 255, "Cleared");
} else if (!_sel_acc) {
    draw_set_color(make_color_rgb(80, 90, 110));
    draw_text(_ddx, _ddy + 255, "Clear a connecting room first.");
} else {
    draw_set_color(c_lime);
    draw_text(_ddx, _ddy + 255, "Press Enter to enter");
}

// Reward preview (uncleared rooms only)
if (!_sel.cleared) {
    if (_sel.type == "rest") {
        draw_set_color(_COL_REST);
        draw_text(_ddx, _ddy + 300, "+" + string(15 + 4 * (variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0)) + " HP +5% max (next combat)");
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    var _float_offset = sin(treasure_timer * 0.1) * 6;
    var _pop_cx = GUI_CX;
    var _pop_cy = 450 + _float_offset;

    draw_set_font(fnt_ui_title);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(make_color_rgb(80, 60, 0));
    draw_text(_pop_cx + 4, _pop_cy + 4, "TREASURE!");
    draw_set_color(c_yellow);
    draw_text(_pop_cx, _pop_cy, "TREASURE!");

    draw_set_font(fnt_ui);
    draw_set_color(c_white);
    draw_text(_pop_cx, _pop_cy + 84, "You found " + string(treasure_gold) + " gold!");

    if (treasure_item != undefined) {
        var _tr_is_cons = variable_struct_exists(treasure_item, "item_category")
                          && treasure_item.item_category == "consumable";
        if (_tr_is_cons) {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(_pop_cx, _pop_cy + 138, treasure_item.name);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(140, 200, 200));
            draw_text(_pop_cx, _pop_cy + 180, treasure_item.description);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(_pop_cx, _pop_cy + 210, "[CONSUMABLE]");
        } else {
            var _tr_col = item_rarity_color(treasure_item.rarity);
            draw_set_font(fnt_ui);
            draw_set_color(_tr_col);
            draw_text(_pop_cx, _pop_cy + 138, treasure_item.name);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(180, 180, 200));
            draw_text(_pop_cx, _pop_cy + 180, treasure_item.effect_desc);
            draw_set_color(_tr_col);
            draw_text(_pop_cx, _pop_cy + 210,
                "[" + item_rarity_name(treasure_item.rarity) + "]   Slot: " + treasure_item.slot);
        }
    } else {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(100, 110, 130));
        draw_text(_pop_cx, _pop_cy + 138, "No other items found.");
    }

    // Treasure Hunter's bonus item - one compact line (name + tag) below the first.
    var _enter_y = _pop_cy + 252;
    if (treasure_item2 != undefined) {
        var _t2_is_cons = variable_struct_exists(treasure_item2, "item_category")
                          && treasure_item2.item_category == "consumable";
        draw_set_font(fnt_ui);
        if (_t2_is_cons) {
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(_pop_cx, _pop_cy + 252, "+ " + treasure_item2.name + "  [CONSUMABLE]");
        } else {
            draw_set_color(item_rarity_color(treasure_item2.rarity));
            draw_text(_pop_cx, _pop_cy + 252,
                "+ " + treasure_item2.name + "  [" + item_rarity_name(treasure_item2.rarity) + "]");
        }
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(180, 160, 90));
        draw_text(_pop_cx, _pop_cy + 288, "Treasure Hunter: bonus item!");
        _enter_y = _pop_cy + 330;
    }

    draw_set_font(fnt_ui_small);
    draw_set_color(c_ltgray);
    draw_text(_pop_cx, _enter_y, "Press Enter to continue");

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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
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
    draw_set_font(fnt_ui);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(190, 195, 215));
    draw_text_ext(_ecx, _ecy + 68, event_body, -1, 900);

    draw_set_font(fnt_ui_small);
    draw_set_color(c_ltgray);
    draw_text(_ecx, _ecy + 300, "Press Enter to continue");

    event_timer++;

    // Ornate gothic rim around the notice (content is centred, well inside the opening).
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);

    if (!shrine_revealed) {
    // --- Veiled altar: its nature stays hidden until the player chooses to approach.
    //     Leaving here forgoes the shrine entirely; approaching commits (a revealed
    //     curse then traps them). See the shrine block in Step_0. -------------------
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(150, 140, 170));
    draw_text(GUI_CX, 84, "An Ancient Altar");
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(180, 175, 195));
    draw_text(GUI_CX, 320, "A shrouded altar thrums with hidden power.");
    draw_text(GUI_CX, 384, "Its nature - blessing or curse - is veiled.");
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(200, 160, 120));
    draw_text(GUI_CX, 500, "Approach and you are committed - a curse, once revealed, will not release you.");
    draw_set_color(c_ltgray);
    ui_draw_key_legend(GUI_CX, 990, "Space / Enter: Approach the altar      Esc: Leave (forgo it)");
    draw_set_halign(fa_center);
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    } else {
    var _is_curse = (shrine_kind == "curse");
    if (_is_curse) {
        draw_set_font(fnt_ui_title);
        draw_set_color(make_color_rgb(205, 70, 70));
        draw_text(GUI_CX, 84, "Cursed Altar");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(195, 160, 170));
        draw_text(GUI_CX, 162, "Embrace a curse to grow richer in spoils. Its burden lasts the whole run.");
    } else {
        draw_set_font(fnt_ui_title);
        draw_set_color(make_color_rgb(220, 185, 110));
        draw_text(GUI_CX, 84, "Shrine of Tribute");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(165, 168, 188));
        draw_text(GUI_CX, 162, "Offer tribute for a boon that lasts this run. Boons vanish when the run ends.");
    }
    var _sg  = global.gold;
    var _sdu = variable_global_exists("rune_dust") ? global.rune_dust : 0;
    draw_set_font(fnt_ui_small);
    // Centered line drawn in segments: "Rune Dust:" label light purple, values
    // stay gold (M 2026-07-07, matches the NPC screens' dust readouts).
    var _sh_g = "Gold: " + string(_sg) + "      ";
    var _sh_l = "Rune Dust:";
    var _sh_v = " " + string(_sdu);
    var _sh_x = GUI_CX - (string_width(_sh_g) + string_width(_sh_l) + string_width(_sh_v)) * 0.5;
    draw_set_halign(fa_left);
    draw_set_color(make_color_rgb(210, 200, 150));
    draw_text(_sh_x, 198, _sh_g);
    draw_set_color(make_color_rgb(195, 155, 255));
    draw_text(_sh_x + string_width(_sh_g), 198, _sh_l);
    draw_set_color(make_color_rgb(210, 200, 150));
    draw_text(_sh_x + string_width(_sh_g) + string_width(_sh_l), 198, _sh_v);
    draw_set_halign(fa_center);

    // Hover-inspect capture for the suggested "[3] Sacrifice ..." item; drawn last
    // (after the gothic frame) so the tooltip sits on top of everything.
    var _shrine_tip_item = undefined;
    var _shrine_tip_x    = 0;
    var _shrine_tip_y    = 0;

    var _sn = array_length(shrine_offers);
    if (_sn == 0) {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(150, 150, 170));
        draw_text(GUI_CX, 480, _is_curse
            ? "No curse remains to bind here. (Esc to leave.)"
            : "You already carry every boon. (Esc to leave.)");
    } else {
        draw_set_halign(fa_left);
        for (var _i = 0; _i < _sn; _i++) {
            var _ry   = 294 + _i * 162;
            var _ssel = (_i == shrine_cursor);

            if (_is_curse) {
                var _cd = curse_get(shrine_offers[_i]);
                draw_set_color(_ssel ? make_color_rgb(48, 22, 22) : make_color_rgb(20, 14, 14));
                draw_rectangle(330, _ry, 1590, _ry + 144, false);
                draw_set_color(_ssel ? make_color_rgb(205, 80, 80) : make_color_rgb(80, 45, 45));
                draw_rectangle(330, _ry, 1590, _ry + 144, true);

                draw_set_font(fnt_ui);
                draw_set_color(make_color_rgb(235, 130, 130));
                draw_text(360, _ry + 15, _cd.name);
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(210, 160, 160));
                draw_text(360, _ry + 66, "Curse:  " + _cd.desc);
                draw_set_color(make_color_rgb(150, 220, 150));
                draw_text(360, _ry + 102, "Reward: " + _cd.reward);
            } else {
                var _bd = boon_get(shrine_offers[_i]);
                draw_set_color(_ssel ? make_color_rgb(45, 38, 22) : make_color_rgb(22, 20, 16));
                draw_rectangle(330, _ry, 1590, _ry + 144, false);
                draw_set_color(_ssel ? make_color_rgb(220, 185, 110) : make_color_rgb(70, 62, 45));
                draw_rectangle(330, _ry, 1590, _ry + 144, true);

                draw_set_font(fnt_ui);
                draw_set_color(make_color_rgb(235, 215, 150));
                draw_text(360, _ry + 15, _bd.name);
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(190, 195, 210));
                draw_text(360, _ry + 63, _bd.desc);

                var _gold_ok = _sg >= _bd.cost;
                var _dc      = boon_dust_cost(_bd.cost);
                var _dust_ok = _sdu >= _dc;
                var _ipick   = boon_item_tribute_pick(_bd.cost);
                draw_set_color(_gold_ok ? make_color_rgb(150, 220, 150) : make_color_rgb(150, 110, 110));
                draw_text(360, _ry + 102, "[1] " + string(_bd.cost) + "g");
                draw_set_color(_dust_ok ? make_color_rgb(150, 220, 150) : make_color_rgb(150, 110, 110));
                draw_text(540, _ry + 102, "[2] " + string(_dc) + " dust");
                draw_set_color((_ipick != undefined) ? make_color_rgb(150, 220, 150) : make_color_rgb(150, 110, 110));
                var _ip_txt = (_ipick != undefined)
                    ? ("[3] Sacrifice " + _ipick.item.name + " (" + item_rarity_name(_ipick.item.rarity) + ")")
                    : "[3] No item valuable enough";
                draw_text(780, _ry + 102, _ip_txt);
                // Hover-inspect the suggested sacrifice: the full item tooltip so the
                // player knows EXACTLY what they'd be giving up (picker still lets them
                // choose a different item after pressing 3).
                if (_ipick != undefined) {
                    var _shx = device_mouse_x_to_gui(0);
                    var _shy = device_mouse_y_to_gui(0);
                    draw_set_font(fnt_ui_small);
                    if (_shx >= 780 && _shx <= 780 + string_width(_ip_txt)
                        && _shy >= _ry + 96 && _shy <= _ry + 132) {
                        _shrine_tip_item = _ipick.item;
                        _shrine_tip_x    = _shx;
                        _shrine_tip_y    = _shy;
                    }
                }
            }
        }
        draw_set_halign(fa_center);
    }

    if (shrine_notification != "") {
        draw_set_font(fnt_ui_small);
        draw_set_color(_is_curse ? make_color_rgb(225, 150, 150) : make_color_rgb(225, 200, 150));
        draw_text(GUI_CX, 834, shrine_notification);
    }
    ui_draw_key_legend(GUI_CX, 990, _is_curse
        ? ((_sn == 0)
            ? "No curse remains  -  Esc: Leave"
            : "W/S: Select     Enter: Embrace the curse  (the altar will not release you)")
        : "W/S: Select     1: Gold     2: Dust     3: Item     Esc: Leave");
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
    draw_set_alpha(0.95);
    draw_set_color(c_black);
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    var _ev = event_active;

    // Title + flavor body
    draw_set_font(fnt_ui_title);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(20, 24, 30));
    draw_text(962, 74, _ev.title);
    draw_set_color(_ev.color);
    draw_text(960, 72, _ev.title);
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(185, 192, 208));
    draw_text_ext(GUI_CX, 150, ui_sentence(_ev.body), -1, 1140);

    if (event_phase == "result") {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(215, 220, 235));
        draw_text_ext(GUI_CX, 450, ui_sentence(event_result_text), -1, 1230);
        draw_set_font(fnt_ui_small);
        draw_set_color(c_ltgray);
        draw_text(GUI_CX, 972, "Press Enter to continue");
    } else {
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(210, 200, 150));
        draw_text(GUI_CX, 252, "Gold: " + string(global.gold));

        draw_set_halign(fa_left);
        var _en = array_length(_ev.choices);
        for (var _i = 0; _i < _en; _i++) {
            var _ch       = _ev.choices[_i];
            var _unlocked = event_choice_unlocked(_ch);
            var _ry       = 315 + _i * 165;
            var _csel     = (_i == event_cursor);

            draw_set_color(_csel ? make_color_rgb(38, 44, 58) : make_color_rgb(20, 22, 32));
            draw_rectangle(330, _ry, 1590, _ry + 147, false);
            draw_set_color(_csel ? _ev.color : make_color_rgb(58, 62, 80));
            draw_rectangle(330, _ry, 1590, _ry + 147, true);

            // Label + hint
            draw_set_font(fnt_ui);
            draw_set_color(_unlocked ? make_color_rgb(236, 240, 250) : make_color_rgb(110, 112, 122));
            draw_text(360, _ry + 18, ui_sentence(_ch.label));
            draw_set_font(fnt_ui_small);
            draw_set_color(_unlocked ? make_color_rgb(178, 186, 204) : make_color_rgb(92, 94, 104));
            draw_text(360, _ry + 72, ui_sentence(_ch.hint));

            // Generated mechanics line under the lore hint: odds + what each
            // outcome actually grants, so the player understands the bet.
            draw_set_color(_unlocked ? make_color_rgb(150, 200, 230) : make_color_rgb(80, 90, 112));
            draw_text(360, _ry + 108, event_choice_mechanics_text(_ch));

            // Right-side info: gold cost / check odds / lock reason
            draw_set_halign(fa_right);
            if (!_unlocked) {
                draw_set_color(make_color_rgb(205, 110, 110));
                var _lock = (_ch.req_stat != "" && player_effective_stat(_ch.req_stat) < _ch.req_amount)
                    ? ("NEED " + _ch.req_stat + " " + string(_ch.req_amount))
                    : "NOT ENOUGH GOLD";
                draw_text(1560, _ry + 21, _lock);
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
                    draw_text(1560, _ry + 21, _info);
                }
            }
            draw_set_halign(fa_left);
        }
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(c_ltgray);
        ui_draw_key_legend(GUI_CX, 972, "W/S: Select     Enter: Choose");
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

draw_set_font(fnt_ui_small);
draw_set_halign(fa_center);
draw_set_valign(fa_bottom);

draw_set_color(c_gray);
draw_text(GUI_CX, 1073, "WASD / Arrow Keys: Move between rooms   Enter: Enter Room");

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

// Player HP + gold readout (top-left). Drawn AFTER the event/shrine overlays (which
// dim the whole screen) so it stays visible during them - many events gamble HP and
// gold, so the player needs both at a glance. Drawn BEFORE the character/pause menus
// so those full overlays still cover it (they show HP/gold themselves).
var _hud_max_hp = out_of_combat_max_hp();
var _hud_hp     = (variable_global_exists("run_current_hp") && global.run_current_hp > 0)
                  ? min(global.run_current_hp, _hud_max_hp) : _hud_max_hp;
draw_set_font(fnt_ui);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(make_color_rgb(225, 95, 95));
draw_text(30, 30, "HP: " + string(_hud_hp) + " / " + string(_hud_max_hp));
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
    draw_set_font(fnt_ui_small);
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(0.96); draw_set_color(_ec_wine ? make_color_rgb(34, 14, 16) : make_color_rgb(20, 22, 36));
    draw_rectangle(510, 360, 1410, 690, false);
    draw_set_alpha(1.0); draw_set_color(_ec_wine ? make_color_rgb(200, 80, 80) : make_color_rgb(150, 140, 220));
    draw_rectangle(510, 360, 1410, 690, true);
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_font(fnt_ui);
    draw_set_color(c_white);
    draw_text(960, 393, _ec_wine ? "Drink the Devil Wine?" : "Rub the Genie Lamp?");
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(190, 195, 215));
    draw_text_ext(960, 456, _ec_wine
        ? "You extract to camp with ALL your loot and found gold...\nbut PERMANENTLY lose 3 random stat points. The wine always collects."
        : "A lazy plume of smoke swallows you.\nYou extract to camp with ALL your loot and found gold. No cost - this once.", 30, 780);
    draw_set_color(make_color_rgb(150, 160, 185));
    ui_draw_key_legend(960, 621, "Enter: Confirm      Esc / G: Cancel");
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
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(255, 225, 140));
    draw_text(_cel_cx, _cel_cy - 57, shrine_celebrate_title);
    draw_set_font(fnt_ui_small);
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

// Pause / Esc menu + its Settings sub-screen (drawn here since the floor doesn't
// otherwise host the settings overlay during a run)
if (variable_global_exists("settings_open") && global.settings_open) ui_draw_settings_overlay();
ui_draw_pause_menu();

// Onboarding coach-mark - drawn last so it sits on top of the floor + shrine overlay.
ui_draw_tutorial_tip();
