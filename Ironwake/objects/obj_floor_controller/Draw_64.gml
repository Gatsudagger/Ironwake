// =============================================================================
// obj_floor_controller — Draw GUI event
// Draws the dungeon floor map at 1280×720.
// Draw order:
//   1. Background
//   2. Header (floor title + dungeon name)
//   3. Room list (center)
//   4. Selected room detail panel (right)
//   5. Treasure popup overlay (conditional)
//   6. Footer instructions
// =============================================================================


// -----------------------------------------------------------------------------
// 1. BACKGROUND
// -----------------------------------------------------------------------------
draw_set_color(make_color_rgb(18, 18, 28));
draw_rectangle(0, 0, 1280, 720, false);


// -----------------------------------------------------------------------------
// 2. HEADER
// -----------------------------------------------------------------------------
draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_set_color(c_white);
draw_text_transformed(640, 30, "FLOOR " + string(global.current_floor) + " OF 3", 1.3, 1.3, 0);
draw_set_color(make_color_rgb(160, 140, 110));
draw_text(640, 66, "The Ashen Vault");
draw_set_halign(fa_left);


// -----------------------------------------------------------------------------
// 3. ROOM LIST — center (x=340, y=120, w=600)
// Each row is 70px tall with a 10px gap.
// Cleared rooms are dimmed. Selected row has a bright blue border.
// Boss rooms use a gold border. Type label is right-aligned.
// -----------------------------------------------------------------------------
var _rl_x   = 340;
var _rl_y   = 120;
var _rl_w   = 600;
var _row_h  = 70;
var _row_gap = 10;
var _count  = array_length(current_rooms);

for (var _i = 0; _i < _count; _i++) {
    var _room   = current_rooms[_i];
    var _ry     = _rl_y + _i * (_row_h + _row_gap);
    var _is_sel = (_i == selected_room);

    // --- Accessibility check — all previous rooms must be cleared ---
    var _accessible = true;
    for (var _ci = 0; _ci < _i; _ci++) {
        if (!current_rooms[_ci].cleared) { _accessible = false; break; }
    }

    // --- Row fill — alpha reflects state: cleared / available / locked ---
    if (_room.cleared) {
        draw_set_alpha(0.5);
        draw_set_color(make_color_rgb(20, 22, 30));
    } else if (!_accessible) {
        draw_set_alpha(0.3);
        draw_set_color(make_color_rgb(20, 22, 30));
    } else if (_is_sel) {
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(25, 45, 75));
    } else {
        draw_set_alpha(0.75);
        draw_set_color(make_color_rgb(22, 26, 42));
    }
    draw_rectangle(_rl_x, _ry, _rl_x + _rl_w, _ry + _row_h, false);

    // --- Border color ---
    draw_set_alpha(1.0);
    if (_is_sel && _room.type == "boss") {
        draw_set_color(make_color_rgb(200, 170, 60));   // gold for selected boss
    } else if (_room.type == "boss") {
        draw_set_color(make_color_rgb(120, 90, 30));    // dim gold for unselected boss
    } else if (_is_sel) {
        draw_set_color(make_color_rgb(80, 160, 220));   // bright blue for selected
    } else {
        draw_set_color(make_color_rgb(45, 55, 75));     // dark gray otherwise
    }
    draw_rectangle(_rl_x, _ry, _rl_x + _rl_w, _ry + _row_h, true);

    // --- Room name (left) — prefix/suffix reflects state ---
    var _name_str = _room.name;
    if (_room.cleared) {
        _name_str = "✓  " + _name_str;
        draw_set_color(c_gray);
    } else if (!_accessible) {
        _name_str = _name_str + "  [LOCKED]";
        draw_set_color(make_color_rgb(70, 75, 90));
    } else {
        draw_set_color(c_white);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_text(_rl_x + 16, _ry + _row_h / 2, _name_str);

    // --- Type label (right) ---
    var _type_label = "";
    var _type_color = c_white;
    switch (_room.type) {
        case "combat":   _type_label = "[COMBAT]";   _type_color = make_color_rgb(200, 100, 80);  break;
        case "treasure": _type_label = "[TREASURE]"; _type_color = c_yellow;                       break;
        case "boss":     _type_label = "[BOSS]";     _type_color = make_color_rgb(220, 180, 60);  break;
    }
    draw_set_color(_room.cleared ? c_dkgray : _type_color);
    draw_set_halign(fa_right);
    draw_text(_rl_x + _rl_w - 14, _ry + _row_h / 2, _type_label);

    // --- Sense trait: difficulty and loot hint for uncleared rooms ---
    if (!_room.cleared && trait_active("Sense")) {
        var _sense_str = "";
        switch (_room.type) {
            case "combat":
                _sense_str = (_room.enemies == "elite") ? "HARD  ★★" : "MED  ★";
                break;
            case "boss":
                _sense_str = "BOSS  ★★★";
                break;
            case "treasure":
                _sense_str = "SAFE  GOLD";
                break;
        }
        if (_sense_str != "") {
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(155, 215, 175));
            draw_text(_rl_x + _rl_w - 14, _ry + _row_h - 18, _sense_str);
        }
    }
}

draw_set_halign(fa_left);
draw_set_valign(fa_top);


// -----------------------------------------------------------------------------
// 4. SELECTED ROOM DETAIL PANEL — right (x=980, y=120, w=280, h=300)
// -----------------------------------------------------------------------------
var _dp_x = 980;
var _dp_y = 120;
var _dp_w = 280;
var _dp_h = 300;

draw_set_alpha(0.9);
draw_set_color(make_color_rgb(20, 25, 45));
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, false);
draw_set_alpha(1.0);

// Detail panel border matches the selected room type
var _sel_room = current_rooms[selected_room];
if (_sel_room.type == "boss") {
    draw_set_color(make_color_rgb(200, 170, 60));
} else {
    draw_set_color(make_color_rgb(80, 160, 220));
}
draw_rectangle(_dp_x, _dp_y, _dp_x + _dp_w, _dp_y + _dp_h, true);

var _ddx = _dp_x + 16;
var _ddy = _dp_y + 16;

// Room name — fake bold
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(make_color_rgb(40, 55, 85));
draw_text_transformed(_ddx + 1, _ddy + 1, _sel_room.name, 1.1, 1.1, 0);
draw_set_color(c_white);
draw_text_transformed(_ddx, _ddy, _sel_room.name, 1.1, 1.1, 0);

// Room type label
var _det_type_color = c_white;
var _det_type_str   = "";
switch (_sel_room.type) {
    case "combat":   _det_type_str = "Combat Room";   _det_type_color = make_color_rgb(200, 100, 80); break;
    case "treasure": _det_type_str = "Treasure Room"; _det_type_color = c_yellow;                      break;
    case "boss":     _det_type_str = "Boss Chamber";  _det_type_color = make_color_rgb(220, 180, 60); break;
}
draw_set_color(_det_type_color);
draw_text(_ddx, _ddy + 34, _det_type_str);

// Brief description
var _det_desc = "";
switch (_sel_room.type) {
    case "combat":   _det_desc = "Enemies await.\nPrepare yourself.";    break;
    case "treasure": _det_desc = "A cache of forgotten gold.";           break;
    case "boss":     _det_desc = "The dungeon guardian waits.";          break;
}
draw_set_color(make_color_rgb(170, 180, 200));
draw_text_ext(_ddx, _ddy + 60, _det_desc, 22, _dp_w - 32);

// Enter / cleared state
if (_sel_room.cleared) {
    draw_set_color(c_gray);
    draw_text(_ddx, _ddy + 130, "Cleared");
} else {
    draw_set_color(c_lime);
    draw_text(_ddx, _ddy + 130, "Press Enter to enter");
}


// -----------------------------------------------------------------------------
// 5. TREASURE POPUP OVERLAY — only when showing_treasure is true
// A floating animation is driven by treasure_timer (incremented here each frame).
// -----------------------------------------------------------------------------
if (showing_treasure) {

    // Full-screen semi-transparent overlay
    draw_set_alpha(0.78);
    draw_set_color(c_black);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Floating offset using treasure_timer for a gentle bob
    var _float_offset = sin(treasure_timer * 0.1) * 4;
    var _pop_cx = 640;
    var _pop_cy = 300 + _float_offset;

    // "TREASURE!" — large gold text with shadow
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(make_color_rgb(80, 60, 0));
    draw_text_transformed(_pop_cx + 3, _pop_cy + 3, "TREASURE!", 2.5, 2.5, 0);
    draw_set_color(c_yellow);
    draw_text_transformed(_pop_cx, _pop_cy, "TREASURE!", 2.5, 2.5, 0);

    // Gold amount
    draw_set_color(c_white);
    draw_text_transformed(_pop_cx, _pop_cy + 56, "You found " + string(treasure_gold) + " gold!", 1.2, 1.2, 0);

    // Item drop — displayed if one was rolled, consistent with combat loot screen style
    if (treasure_item != undefined) {
        var _tr_is_cons = variable_struct_exists(treasure_item, "item_category")
                          && treasure_item.item_category == "consumable";
        if (_tr_is_cons) {
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text_transformed(_pop_cx, _pop_cy + 92, treasure_item.name, 1.1, 1.1, 0);
            draw_set_color(make_color_rgb(140, 200, 200));
            draw_text(_pop_cx, _pop_cy + 120, treasure_item.description);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(_pop_cx, _pop_cy + 140, "[CONSUMABLE]");
        } else {
            var _tr_col = item_rarity_color(treasure_item.rarity);
            draw_set_color(_tr_col);
            draw_text_transformed(_pop_cx, _pop_cy + 92, treasure_item.name, 1.1, 1.1, 0);
            draw_set_color(make_color_rgb(180, 180, 200));
            draw_text(_pop_cx, _pop_cy + 120, treasure_item.effect_desc);
            draw_set_color(_tr_col);
            draw_text(_pop_cx, _pop_cy + 140, "[" + item_rarity_name(treasure_item.rarity) + "]"
                      + "   Slot: " + treasure_item.slot);
        }
    } else {
        draw_set_color(make_color_rgb(100, 110, 130));
        draw_text(_pop_cx, _pop_cy + 92, "No other items found.");
    }

    // Dismiss prompt (pushed down to clear item text)
    draw_set_color(c_ltgray);
    draw_text(_pop_cx, _pop_cy + 168, "Press Enter to continue");

    // Advance timer (animation is driven by this counter)
    treasure_timer++;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}


// -----------------------------------------------------------------------------
// 6. FOOTER INSTRUCTIONS
// E to extract is dimmed until at least one room is cleared.
// -----------------------------------------------------------------------------
var _any_cleared = false;
for (var _fi = 0; _fi < array_length(current_rooms); _fi++) {
    if (current_rooms[_fi].cleared) { _any_cleared = true; break; }
}

draw_set_halign(fa_center);
draw_set_valign(fa_bottom);

draw_set_color(c_gray);
draw_text(640, 715, "W/S: Navigate   Enter: Enter Room");

// Extract prompt — bright when available, dark gray when locked
if (_any_cleared) {
    draw_set_color(c_gray);
} else {
    draw_set_color(make_color_rgb(45, 50, 60));
}
draw_text(640, 698, "E: Extract to Camp");

// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);

ui_draw_character_menu();
