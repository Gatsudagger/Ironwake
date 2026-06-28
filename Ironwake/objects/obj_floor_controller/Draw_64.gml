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
for (var _i = 0; _i < _count; _i++) {
    var _room = current_rooms[_i];
    for (var _ci = 0; _ci < array_length(_room.children); _ci++) {
        var _child  = current_rooms[_room.children[_ci]];
        var _x1 = _room.px + _NW * 0.5;
        var _y1 = _room.py;
        var _x2 = _child.px - _NW * 0.5;
        var _y2 = _child.py;
        var _mid_x = (_x1 + _x2) * 0.5;

        // Line brightness: cleared parent = brighter
        if (_room.cleared) {
            draw_set_color(make_color_rgb(70, 100, 140));
            draw_set_alpha(0.9);
        } else {
            draw_set_color(make_color_rgb(38, 48, 70));
            draw_set_alpha(0.7);
        }

        // Elbow line: horizontal from parent, vertical segment, horizontal to child
        draw_line(_x1, _y1, _mid_x, _y1);
        draw_line(_mid_x, _y1, _mid_x, _y2);
        draw_line(_mid_x, _y2, _x2, _y2);
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
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(155, 215, 175));
            draw_text(_nx + _NW - 9, _ny + 21, _sense_str);
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
        _det_desc = "A sheltered alcove.\nYou may rest and recover here.\n+15 HP at start of next combat."; break;
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
        draw_text(_ddx, _ddy + 300, "+15 HP (applied next combat)");
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

    draw_set_font(fnt_ui_small);
    draw_set_color(c_ltgray);
    draw_text(_pop_cx, _pop_cy + 252, "Press Enter to continue");

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
    var _is_curse = (shrine_kind == "curse");

    draw_set_alpha(0.95);
    draw_set_color(c_black);
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
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
    draw_set_color(make_color_rgb(210, 200, 150));
    draw_text(GUI_CX, 198, "Gold: " + string(_sg) + "      Rune Dust: " + string(_sdu));

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
                draw_text(780, _ry + 102, (_ipick != undefined)
                    ? ("[3] Sacrifice " + _ipick.item.name + " (" + item_rarity_name(_ipick.item.rarity) + ")")
                    : "[3] No item valuable enough");
            }
        }
        draw_set_halign(fa_center);
    }

    if (shrine_notification != "") {
        draw_set_font(fnt_ui_small);
        draw_set_color(_is_curse ? make_color_rgb(225, 150, 150) : make_color_rgb(225, 200, 150));
        draw_text(GUI_CX, 834, shrine_notification);
    }
    draw_set_font(fnt_ui_small);
    draw_set_color(c_ltgray);
    draw_text(GUI_CX, 990, _is_curse
        ? "W/S: Select     Enter: Embrace the curse     Esc: Leave"
        : "W/S: Select     1: Gold     2: Dust     3: Item     Esc: Leave");

    // Ornate gothic rim (title y84, offer rows x330..1590, hint y990 - all inside the opening).
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
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
    draw_text_ext(GUI_CX, 150, _ev.body, -1, 1140);

    if (event_phase == "result") {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(215, 220, 235));
        draw_text_ext(GUI_CX, 450, event_result_text, -1, 1230);
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
            draw_text(360, _ry + 18, _ch.label);
            draw_set_font(fnt_ui_small);
            draw_set_color(_unlocked ? make_color_rgb(178, 186, 204) : make_color_rgb(92, 94, 104));
            draw_text(360, _ry + 72, _ch.hint);

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
        draw_text_outline(GUI_CX, 972, "W/S: Select     Enter: Choose");
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
draw_text(30, 66, "Gold: " + string(global.gold) + "g");
draw_set_color(c_white);
draw_set_font(-1);

ui_draw_character_menu();

// Item-sacrifice picker modal - topmost (Shrine item tribute)
ui_draw_item_picker();

// Consumable overflow discard prompt (pack-full pickup)
ui_draw_consumable_overflow();

// Pause / Esc menu + its Settings sub-screen (drawn here since the floor doesn't
// otherwise host the settings overlay during a run)
if (variable_global_exists("settings_open") && global.settings_open) ui_draw_settings_overlay();
ui_draw_pause_menu();

// Onboarding coach-mark - drawn last so it sits on top of the floor + shrine overlay.
ui_draw_tutorial_tip();
