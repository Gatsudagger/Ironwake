// =============================================================================
// scr_ui.gml
// Combat HUD drawing functions for Ironwake.
// Room dimensions: 1280 × 720.
//
// All functions are pure draw calls — they read state but never mutate it.
// Call every function from a Draw event (or a dedicated Draw GUI event).
//
// Draw call order in ui_draw_combat_hud():
//   1. Turn queue        — top-center
//   2. Player HP bar     — top-left
//   3. Energy pips       — below HP bar
//   4. Secondary resource— below energy pips
//   5. Ability buttons   — bottom-center
//   6. Combat log        — bottom-left
//   7. Telegraph warning — overlaid at top (only when active)
// =============================================================================

// ---------------------------------------------------------------------------
// ui_input_blocked()
// Returns true when any full-screen overlay managed by obj_game_controller is
// open. Call as the very first line of room-controller Step events so their
// regular input does not bleed through while overlays are active.
// gc Step is intentionally excluded — it must keep running to handle overlays.
// ---------------------------------------------------------------------------
function ui_input_blocked() {
    if (!instance_exists(obj_game_controller)) return false;
    var _gc = instance_find(obj_game_controller, 0);
    if (_gc.menu_open)       return true;   // character menu (I)
    if (_gc.stash_mode_open) return true;   // stash screen (T)
    if (_gc.shop_open != -1) return true;   // Petra / Dorn shops
    if (variable_instance_exists(_gc, "level_alloc_open") && _gc.level_alloc_open) return true;
    if (variable_instance_exists(_gc, "loadout_open")     && _gc.loadout_open)     return true;
    return false;
}

// ---------------------------------------------------------------------------
// ui_draw_hp_bar(x, y, width, height, current_hp, max_hp, label)
// Draws a filled HP bar with a label and "current / max" readout.
// Color zones: green ≥50%, yellow 25–50%, red <25%.
// ---------------------------------------------------------------------------
function ui_draw_hp_bar(x, y, width, height, current_hp, max_hp, label) {
    var ratio = (max_hp > 0) ? clamp(current_hp / max_hp, 0, 1) : 0;

    // Background track
    draw_set_color(c_dkgray);
    draw_rectangle(x, y, x + width, y + height, false);

    // Fill color based on HP ratio
    var fill_color;
    if (ratio >= 0.5) {
        fill_color = c_green;
    } else if (ratio >= 0.25) {
        fill_color = c_yellow;
    } else {
        fill_color = c_red;
    }

    var fill_width = floor(width * ratio);
    if (fill_width > 0) {
        draw_set_color(fill_color);
        draw_rectangle(x, y, x + fill_width, y + height, false);
    }

    // Thin border over the bar
    draw_set_color(c_black);
    draw_rectangle(x, y, x + width, y + height, true);

    // Label (left-aligned, vertically centered on the bar)
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(c_white);
    draw_text(x + 4, y + height / 2, label);

    // HP readout right-aligned
    draw_set_halign(fa_right);
    draw_text(x + width - 4, y + height / 2, string(current_hp) + " / " + string(max_hp));

    // Reset alignment to safe defaults
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_energy_pips(x, y, current_energy, max_energy)
// Draws energy as a row of small squares.
// Lit pips: bright yellow. Empty pips: dark gray.
// Each pip is 16×16 with a 4px gap between them.
// ---------------------------------------------------------------------------
function ui_draw_energy_pips(x, y, current_energy, max_energy) {
    var pip_size = 16;
    var pip_gap  = 4;

    for (var i = 0; i < max_energy; i++) {
        var px = x + i * (pip_size + pip_gap);

        // Fill
        if (i < current_energy) {
            draw_set_color(c_yellow);
        } else {
            draw_set_color(c_dkgray);
        }
        draw_rectangle(px, y, px + pip_size, y + pip_size, false);

        // Border
        draw_set_color(c_black);
        draw_rectangle(px, y, px + pip_size, y + pip_size, true);
    }

    // Label to the right of the pips
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    var label_x = x + max_energy * (pip_size + pip_gap) + 4;
    draw_text(label_x, y + pip_size / 2, "AP");
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_secondary_resource(x, y, current, maximum, resource_name, color)
// Draws a slim labeled bar for Souls / Blood / Preparation.
// The bar fill uses the passed color; background is dark gray.
// ---------------------------------------------------------------------------
function ui_draw_secondary_resource(x, y, current, maximum, resource_name, color) {
    var width  = 250;
    var height = 16;
    var ratio  = (maximum > 0) ? clamp(current / maximum, 0, 1) : 0;

    // Background
    draw_set_color(c_dkgray);
    draw_rectangle(x, y, x + width, y + height, false);

    // Fill
    var fill_width = floor(width * ratio);
    if (fill_width > 0) {
        draw_set_color(color);
        draw_rectangle(x, y, x + fill_width, y + height, false);
    }

    // Border
    draw_set_color(c_black);
    draw_rectangle(x, y, x + width, y + height, true);

    // Resource name and value
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_text(x + 4, y + height / 2, resource_name);

    draw_set_halign(fa_right);
    draw_text(x + width - 4, y + height / 2, string(current) + " / " + string(maximum));

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_turn_queue(x, y, combat_state)
// Draws the initiative order as a horizontal row of name boxes.
// Active combatant: bright white border. Player boxes: teal. Enemy: orange.
// Names are truncated to 8 characters to fit the box.
// ---------------------------------------------------------------------------
function ui_draw_turn_queue(x, y, combat_state) {
    var box_width  = 80;
    var box_height = 32;
    var box_gap    = 6;

    var count = array_length(combat_state.combatants);

    for (var i = 0; i < count; i++) {
        var c  = combat_state.combatants[i];
        var bx = x + i * (box_width + box_gap);

        // Skip defeated combatants — show a dim slot instead
        if (c.is_defeated) {
            draw_set_alpha(0.3);
        }

        // Box fill — teal for player, orange for enemies
        if (c.is_player) {
            draw_set_color(c_teal);
        } else {
            draw_set_color(c_orange);
        }
        draw_rectangle(bx, y, bx + box_width, y + box_height, false);

        // Border — bright white for the active combatant, black otherwise
        if (i == combat_state.turn_index) {
            draw_set_color(c_white);
        } else {
            draw_set_color(c_black);
        }
        draw_rectangle(bx, y, bx + box_width, y + box_height, true);

        // Name — truncate to 8 chars
        var display_name = string_copy(c.name, 1, 8);
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(bx + box_width / 2, y + box_height / 2, display_name);

        draw_set_alpha(1.0);
    }

    // Reset alignment
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_ability_buttons(x, y, ability_array, selected_index, caster)
// Draws a row of ability buttons showing name and energy cost.
// Uncastable abilities are dimmed. Selected ability has a white border.
// Each button: 160×50 with 8px gap.
// ---------------------------------------------------------------------------
function ui_draw_ability_buttons(x, y, ability_array, selected_index, caster) {
    var btn_width  = 160;
    var btn_height = 50;
    var btn_gap    = 8;

    var count = array_length(ability_array);

    for (var i = 0; i < count; i++) {
        var ab = ability_array[i];
        var bx = x + i * (btn_width + btn_gap);
        var castable = ability_can_cast(ab, caster);

        // Dim uncastable buttons
        if (!castable) {
            draw_set_alpha(0.45);
        }

        // Button background — dark fill
        draw_set_color(make_color_rgb(40, 40, 55));
        draw_rectangle(bx, y, bx + btn_width, y + btn_height, false);

        // Border — white for selected, gray otherwise
        if (i == selected_index) {
            draw_set_color(c_white);
        } else {
            draw_set_color(c_gray);
        }
        draw_rectangle(bx, y, bx + btn_width, y + btn_height, true);

        // Ability name (centered horizontally, upper half of button)
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(bx + btn_width / 2, y + 16, ab.name);

        // Energy cost pips in bottom half — small 8×8 squares
        var pip_size = 8;
        var pip_gap  = 3;
        var pip_total_width = ab.energy_cost * (pip_size + pip_gap) - pip_gap;
        var pip_start_x = bx + (btn_width - pip_total_width) / 2;
        var pip_y       = y + btn_height - 14;

        for (var p = 0; p < ab.energy_cost; p++) {
            var px = pip_start_x + p * (pip_size + pip_gap);
            // Lit if the caster has enough energy to cover pips up to this one
            if (p < caster.energy) {
                draw_set_color(c_yellow);
            } else {
                draw_set_color(c_dkgray);
            }
            draw_rectangle(px, pip_y, px + pip_size, pip_y + pip_size, false);
        }

        draw_set_alpha(1.0);
    }

    // Reset alignment
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_telegraph_warning(enemy_name, message)
// Draws a full-width red banner at the top of the screen.
// Only called when enemy_should_telegraph() returns true for any enemy.
// ---------------------------------------------------------------------------
function ui_draw_telegraph_warning(enemy_name, message) {
    var room_w      = 1280;
    var banner_h    = 36;
    var banner_y    = 600;
    var padding     = 8;

    // Semi-transparent dark red backing
    draw_set_alpha(0.88);
    draw_set_color(make_color_rgb(160, 20, 20));
    draw_rectangle(0, banner_y, room_w, banner_y + banner_h, false);

    // Solid red border
    draw_set_alpha(1.0);
    draw_set_color(c_red);
    draw_rectangle(0, banner_y, room_w, banner_y + banner_h, true);

    // Warning text — enemy name bolded by drawing twice with 1px offset (fake bold)
    var warning_text = enemy_name + " " + message;
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    var mid_y = banner_y + banner_h / 2;

    // Fake bold: draw shadow offset then main text on top
    draw_set_color(make_color_rgb(80, 0, 0));
    draw_text(room_w / 2 + 1, mid_y + 1, warning_text);
    draw_set_color(c_white);
    draw_text(room_w / 2, mid_y, warning_text);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_combat_log(x, y, width, height, log_array)
// Fills the panel from bottom up, most recent entry at the bottom.
// Each entry reserves height proportional to its estimated wrapped line count
// so wrapped text never overlaps the entry below it.
// Stops drawing when the next entry would reach the top padding boundary.
// ---------------------------------------------------------------------------
function ui_draw_combat_log(x, y, width, height, log_array) {
    var line_h  = 20;
    var padding = 10;

    // Background panel
    draw_set_alpha(0.7);
    draw_set_color(make_color_rgb(15, 15, 25));
    draw_rectangle(x, y, x + width, y + height, false);
    draw_set_alpha(1.0);
    draw_set_color(c_gray);
    draw_rectangle(x, y, x + width, y + height, true);

    var log_count = array_length(log_array);
    if (log_count == 0) return;

    var max_width   = width - (padding * 2);
    var cur_draw_y  = y + height - padding;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // Walk the array from newest to oldest, placing each entry above the previous
    for (var i = log_count - 1; i >= 0 && cur_draw_y > y + padding; i--) {
        var line_text = log_array[i];

        // Fixed 2-line height per entry — prevents overlap regardless of wrap.
        // Short entries waste space but long entries never collide.
        var entry_height = line_h * 2;

        cur_draw_y -= entry_height;
        if (cur_draw_y < y + padding) break;

        // Fade entries by age: 0 = newest (fully opaque), older entries fade toward 0.4
        var age = log_count - 1 - i;
        draw_set_alpha(lerp(1.0, 0.4, min(age / 6.0, 1.0)));
        draw_set_color(c_white);
        draw_text_ext(x + padding, cur_draw_y, line_text, 18, max_width);
    }

    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_ability_tooltip(x, y, ability, caster)
// Draws a tooltip panel for the currently selected ability.
// Panel: 400×280. Shows name, costs, damage, effect, accuracy.
// ---------------------------------------------------------------------------
function ui_draw_ability_tooltip(x, y, ability, caster) {
    var panel_w   = 340;
    var panel_h   = 220;
    var padding   = 14;
    var line_h    = 22;
    var cur_y     = y + padding;

    // --- Panel background and border ---
    draw_set_alpha(0.92);
    draw_set_color(make_color_rgb(20, 25, 40));
    draw_rectangle(x, y, x + panel_w, y + panel_h, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(80, 120, 160));
    draw_rectangle(x, y, x + panel_w, y + panel_h, true);

    var tx = x + padding;

    // --- Line 1: Ability name (fake bold) ---
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(40, 50, 70));
    draw_text(tx + 1, cur_y + 1, ability.name);
    draw_set_color(c_white);
    draw_text(tx, cur_y, ability.name);
    cur_y += line_h + 4;

    // --- Line 2: Energy cost + secondary resource cost ---
    var cost_str = "Energy: " + string(ability.energy_cost);
    if (variable_struct_exists(ability, "secondary_cost") && ability.secondary_cost > 0) {
        var sec_label = "Resource";
        if (variable_struct_exists(caster, "souls")) {
            sec_label = "Souls";
        } else if (variable_struct_exists(caster, "blood")) {
            sec_label = "Blood";
        } else if (variable_struct_exists(caster, "preparation")) {
            sec_label = "Prep";
        }
        cost_str += " | " + sec_label + ": " + string(ability.secondary_cost);
    }
    draw_set_color(c_yellow);
    draw_text(tx, cur_y, cost_str);
    cur_y += line_h;

    // --- Line 3: Blank gap ---
    cur_y += line_h / 2;

    // --- Line 4: Damage ---
    if (variable_struct_exists(ability, "base_damage") && ability.base_damage > 0) {
        var dmg_type_str = "physical";
        if (variable_struct_exists(ability, "damage_type")) {
            if (ability.damage_type == 1) {
                dmg_type_str = "elemental";
            } else if (ability.damage_type == 2) {
                dmg_type_str = "drain";
            }
        }
        draw_set_color(c_white);
        draw_text(tx, cur_y, "Damage: " + string(ability.base_damage) + " (" + dmg_type_str + ")");
        cur_y += line_h;
    }

    // --- Line 5: Effect description ---
    var effect_str = "";
    if (variable_struct_exists(ability, "effect_type") && ability.effect_type != "") {
        var ev = variable_struct_exists(ability, "effect_value") ? ability.effect_value : 0;
        var ed = variable_struct_exists(ability, "effect_duration") ? ability.effect_duration : 0;

        if (ability.effect_type == "heal") {
            effect_str = "Restores " + string(ev) + " HP";
        } else if (ability.effect_type == "dot") {
            effect_str = "Applies DoT: " + string(ev) + " damage/turn for " + string(ed) + " turns";
        } else if (ability.effect_type == "shield") {
            if (ed > 0) {
                effect_str = "Reduces incoming damage by " + string(ev) + " for " + string(ed) + " turns";
            } else {
                effect_str = "Absorbs " + string(ev) + " damage";
            }
        } else if (ability.effect_type == "debuff") {
            effect_str = "Debuffs target for " + string(ed) + " turns";
        } else if (ability.effect_type == "resource") {
            effect_str = "Generates " + string(ev) + " secondary resource on kill";
        } else if (ability.effect_type == "passive") {
            effect_str = "Passive — triggers automatically";
        } else if (ability.effect_type == "status") {
            if (ability.name == "Blink") {
                effect_str = "Become untargetable for 1 turn";
            } else if (ability.name == "Shadow Step") {
                effect_str = "Dodge the next single-target attack";
            } else if (ability.name == "Bear Trap") {
                effect_str = "Roots target — skips their next move action";
            } else if (ability.name == "Death Snare") {
                effect_str = "Stuns target for 2 turns";
            } else if (ability.name == "Spike Trap") {
                effect_str = "Applies Bleed — stacks twice";
            } else if (ability.name == "Bloodthorn Aura") {
                effect_str = "Returns " + string(ev) + " damage to attacker when hit for " + string(ed) + " turns";
            } else if (ability.name == "Undying") {
                effect_str = "Survive a lethal hit at 1 HP this turn";
            } else if (ability.name == "Vital Theft") {
                effect_str = "Steal " + string(ev) + " max HP from target for this combat";
            } else if (ability.name == "Bloodfeast") {
                effect_str = "Each ability drains " + string(ev) + " HP for " + string(ed) + " turns";
            } else if (ability.name == "Soulbind") {
                effect_str = "Reflect " + string(ev * 100) + "% of damage dealt back to attacker";
            } else {
                effect_str = "Applies status effect for " + string(ed) + " turns";
            }
        }
    }
    if (effect_str != "") {
        draw_set_color(c_white);
        draw_text_ext(tx, cur_y, effect_str, line_h, panel_w - padding * 2);
        cur_y += line_h * 2;
    }

    // --- Line 6: Guaranteed hit indicator ---
    if (variable_struct_exists(ability, "guaranteed_hit") && ability.guaranteed_hit) {
        draw_set_color(c_lime);
        draw_text(tx, cur_y, "Always hits");
        cur_y += line_h;

    // --- Line 7: Accuracy (only when not guaranteed) ---
    } else {
        var dex    = variable_struct_exists(caster.stats, "DEX") ? caster.stats.DEX : 0;
        var acc    = clamp(ability.base_acc + dex * 3, 0, 95);
        draw_set_color(c_ltgray);
        draw_text(tx, cur_y, "Accuracy: " + string(acc) + "%");
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_combat_hud(combat_state, player, ability_array, selected_ability_index, log_array)
// Master draw function — calls all component functions at their correct positions.
//
// Layout (1280×720):
//   Top-left       Player HP bar         (20,  20) w250 h24
//   Below HP       Energy pips           (20,  56)
//   Below energy   Secondary resource    (20,  90) w250 h16
//   Top-center     Turn queue            (400, 10)
//   Bottom-center  Ability buttons       (160, 640)
//   Bottom-left    Combat log            (20,  200) w440 h280
//   Right-center   Ability tooltip       (820, 280) w400 h280
//   Top overlay    Telegraph warning     (full-width, only when active)
// ---------------------------------------------------------------------------
function ui_draw_combat_hud(combat_state, player, ability_array, selected_ability_index, log_array) {

    // --- Turn queue (top-center) ---
    ui_draw_turn_queue(400, 10, combat_state);

    // --- Player HP bar (top-left) ---
    ui_draw_hp_bar(20, 20, 250, 24, player.HP, player.max_HP, "HP");

    // --- Energy pips (below HP bar) ---
    ui_draw_energy_pips(20, 56, player.energy, 3);

    // --- Secondary resource bar (below energy pips) ---
    // Determine which resource this class uses and pick a matching color
    var res_name  = "";
    var res_cur   = 0;
    var res_max   = 0;
    var res_color = c_white;

    if (variable_struct_exists(player, "souls")) {
        res_name  = "Souls";
        res_cur   = player.souls;
        res_max   = player.souls_max;
        res_color = c_purple;
    } else if (variable_struct_exists(player, "blood")) {
        res_name  = "Blood";
        res_cur   = player.blood;
        res_max   = player.blood_max;
        res_color = c_red;
    } else if (variable_struct_exists(player, "preparation")) {
        res_name  = "Preparation";
        res_cur   = player.preparation;
        res_max   = player.preparation_max;
        res_color = c_aqua;
    }

    if (res_name != "") {
        ui_draw_secondary_resource(20, 90, res_cur, res_max, res_name, res_color);
    }

    // --- Run level and XP bar (below secondary resource) ---
    if (variable_global_exists("run_level")) {
        draw_set_color(c_white);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_text(20, 115, "Lv " + string(global.run_level));

        if (global.run_level < 15 && variable_global_exists("run_xp")) {
            var _xp_lo    = xp_threshold(global.run_level);
            var _xp_hi    = xp_threshold(global.run_level + 1);
            var _xp_ratio = (_xp_hi > _xp_lo)
                            ? clamp((global.run_xp - _xp_lo) / (_xp_hi - _xp_lo), 0, 1)
                            : 1;
            var _xb = 44;
            var _xbw = 226;
            var _xbh = 8;
            var _xby = 121;
            draw_set_color(make_color_rgb(35, 45, 55));
            draw_rectangle(_xb, _xby, _xb + _xbw, _xby + _xbh, false);
            draw_set_color(make_color_rgb(60, 180, 200));
            var _xfill = floor(_xbw * _xp_ratio);
            if (_xfill > 0) draw_rectangle(_xb, _xby, _xb + _xfill, _xby + _xbh, false);
            draw_set_color(make_color_rgb(50, 70, 80));
            draw_rectangle(_xb, _xby, _xb + _xbw, _xby + _xbh, true);
        } else if (global.run_level >= 15) {
            draw_set_color(make_color_rgb(255, 200, 50));
            draw_text(44, 115, "MAX");
        }
    }

    // --- Ability buttons (bottom-center) ---
    ui_draw_ability_buttons(160, 660, ability_array, selected_ability_index, player);

    // --- Combat log (bottom strip — freed left zone for character sprites) ---
    ui_draw_combat_log(20, 490, 780, 140, log_array);

    // --- Ability tooltip (right-center) ---
    var _sel_ab = ability_array[selected_ability_index];
    ui_draw_ability_tooltip(820, 370, _sel_ab, player);

    // NOTE: Target selection indicator (">") is drawn in Draw_64.gml alongside
    // the enemy HP bars — it needs selected_target from obj_combat_controller
    // directly and cannot be drawn here without passing it as a parameter.

    // --- Telegraph warning (top overlay — check all enemies) ---
    // Uses the combat engine's turn counter stored in combat_state.round as
    // a proxy for turn_number. Replace with your actual per-enemy turn counter
    // if you track those separately.
    var combatant_count = array_length(combat_state.combatants);
    for (var i = 0; i < combatant_count; i++) {
        var c = combat_state.combatants[i];
        if (!c.is_player && enemy_should_telegraph(c, combat_state.round)) {
            ui_draw_telegraph_warning(c.name, c.telegraph_message);
            break; // Only one warning banner at a time
        }
    }
}

// ---------------------------------------------------------------------------
// ui_draw_character_menu()
// Draws the full-screen character menu overlay.
// Called by each room controller's Draw GUI so it renders regardless of which
// room is active (obj_game_controller's own Draw GUI is unreliable when the
// object is persistent and sprite-less).
// ---------------------------------------------------------------------------
function ui_draw_character_menu() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!_gc.menu_open) return;
    var menu_tab = _gc.menu_tab;
    var items_used_this_turn = _gc.items_used_this_turn;

    var tab_names = ["Stats", "Equipment", "Abilities", "Consumables"];

    draw_set_alpha(1.0);
    draw_set_color(c_white);

    // Full screen dark overlay
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(8, 10, 18));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Tab bar at top
    var _tab_w = 200;
    var _tab_h = 44;
    var _tab_y = 20;
    for (var _t = 0; _t < 4; _t++) {
        var _tx = 240 + _t * (_tab_w + 8);
        if (_t == menu_tab) {
            draw_set_color(make_color_rgb(30, 50, 90));
            draw_rectangle(_tx, _tab_y, _tx + _tab_w, _tab_y + _tab_h, false);
            draw_set_color(make_color_rgb(80, 140, 220));
            draw_rectangle(_tx, _tab_y, _tx + _tab_w, _tab_y + _tab_h, true);
        } else {
            draw_set_color(make_color_rgb(20, 25, 40));
            draw_rectangle(_tx, _tab_y, _tx + _tab_w, _tab_y + _tab_h, false);
            draw_set_color(make_color_rgb(50, 60, 80));
            draw_rectangle(_tx, _tab_y, _tx + _tab_w, _tab_y + _tab_h, true);
        }
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color((_t == menu_tab) ? c_white : make_color_rgb(140, 150, 170));
        draw_text(_tx + _tab_w / 2, _tab_y + _tab_h / 2, tab_names[_t]);
    }
    draw_set_valign(fa_top);
    draw_set_halign(fa_left);

    // Get player reference if in combat
    var _player    = undefined;
    var _in_combat = instance_exists(obj_combat_controller);
    if (_in_combat) {
        var _ctrl = instance_find(obj_combat_controller, 0);
        _player = _ctrl.player;
    }

    // Out-of-combat fallback — build a read-only view from globals so Stats and
    // Abilities tabs are populated when the menu is opened in the hub or floor map.
    // Always copies chosen_stats and applies equipment bonuses — never mutates the global.
    if (_player == undefined && variable_global_exists("chosen_class")) {
        var _base        = global.chosen_stats;
        var _stats_view  = {
            class_id:    _base.class_id,
            class_name:  _base.class_name,
            STR:         _base.STR,
            DEX:         _base.DEX,
            CON:         _base.CON,
            INT:         _base.INT,
            WIS:         _base.WIS,
            CHA:         _base.CHA,
            free_points: _base.free_points,
        };
        var _sv_bonus = apply_equipment_stats(_stats_view);
        // Add run stat bonuses from XP leveling
        if (variable_global_exists("run_stat_bonuses")) {
            _stats_view.STR += global.run_stat_bonuses.STR;
            _stats_view.DEX += global.run_stat_bonuses.DEX;
            _stats_view.CON += global.run_stat_bonuses.CON;
            _stats_view.INT += global.run_stat_bonuses.INT;
            _stats_view.WIS += global.run_stat_bonuses.WIS;
            _stats_view.CHA += global.run_stat_bonuses.CHA;
        }
        // Add permanent meta-progression bonuses
        if (variable_global_exists("perm_str_bonus")) {
            _stats_view.STR += global.perm_str_bonus;
            _stats_view.DEX += global.perm_dex_bonus;
            _stats_view.CON += global.perm_con_bonus;
            _stats_view.INT += global.perm_int_bonus;
            _stats_view.WIS += global.perm_wis_bonus;
            _stats_view.CHA += global.perm_cha_bonus;
        }
        var _derived_view = stats_derive(_stats_view);
        var _sv_max_hp = _derived_view.HP + _sv_bonus.bonus_max_hp;
        _player = {
            class_id:  global.chosen_class,
            stats:     _stats_view,
            HP:        (variable_global_exists("run_current_hp") && global.run_current_hp > 0)
                           ? global.run_current_hp
                           : _sv_max_hp,
            max_HP:    _sv_max_hp,
            abilities: abilities_get_loadout(global.chosen_class),
            dodge:     _derived_view.DODGE + _sv_bonus.dodge_flat,
        };
    }

    var _content_y = 90;
    var _pad       = 40;

    // ---- STATS TAB ----
    if (menu_tab == 0) {
        if (_player != undefined) {
            draw_set_color(make_color_rgb(80, 160, 220));
            var _class_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
            draw_text_transformed(_pad, _content_y, _class_names[_player.class_id], 1.5, 1.5, 0);

            draw_set_color(c_white);
            draw_text(_pad, _content_y + 40, "HP: " + string(_player.HP) + " / " + string(_player.max_HP));

            var _stats      = _player.stats;
            var _stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
            var _stat_keys  = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];

            for (var _s = 0; _s < 6; _s++) {
                var _sx  = _pad + floor(_s / 3) * 300;
                var _sy  = _content_y + 90 + (_s mod 3) * 50;
                var _val = variable_struct_get(_stats, _stat_keys[_s]);
                draw_set_color(make_color_rgb(140, 160, 200));
                draw_text(_sx, _sy, _stat_names[_s] + ":");
                draw_set_color(c_white);
                draw_text(_sx + 60, _sy, string(_val));
            }

            var _derived = stats_derive(_stats);
            draw_set_color(make_color_rgb(120, 140, 170));
            draw_text(_pad,       _content_y + 260, "DODGE: "      + string(_derived.DODGE));
            draw_text(_pad,       _content_y + 290, "ACC bonus: +" + string(_derived.ACC_modifier));
            draw_text(_pad,       _content_y + 320, "Max HP: "     + string(_derived.HP));
            draw_text(_pad + 300, _content_y + 260, "STR crit: "   + string(_derived.STR_crit_chance) + "%");
            draw_text(_pad + 300, _content_y + 290, "DEX crit: "   + string(_derived.DEX_crit_chance) + "%");
            draw_text(_pad + 300, _content_y + 320, "INT crit: "   + string(_derived.INT_crit_chance) + "%");
            draw_text(_pad + 300, _content_y + 350, "WIS crit: "   + string(_derived.WIS_crit_chance) + "%");

            draw_set_color(c_yellow);
            draw_text(_pad, _content_y + 400, "Gold: " + string(global.gold) + "g");
            draw_set_color(c_white);
            draw_text(_pad, _content_y + 430,
                "Run: " + string(global.run_count + 1) + "  |  Floor: " + string(global.current_floor));
        } else {
            draw_set_color(make_color_rgb(120, 130, 150));
            draw_text(_pad, _content_y + 20, "No active character — start a run to view stats.");
        }
    }

    // ---- EQUIPMENT TAB ----
    if (menu_tab == 1) {
        var _slot_names = ["Weapon", "Offhand", "Helm", "Chest", "Gloves", "Boots", "Amulet", "Ring"];
        var _slot_keys  = ["weapon", "offhand", "helm", "chest", "gloves", "boots", "amulet", "ring"];
        var _sel_slot   = _gc.equip_slot_selected;

        // Stash / Pack counts in top-right
        var _stash_count = variable_global_exists("equipment_stash") ? array_length(global.equipment_stash) : 0;
        var _pack_count  = variable_global_exists("carried_items")   ? array_length(global.carried_items)   : 0;
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(120, 130, 150));
        draw_text(1240, _content_y, "Stash: " + string(_stash_count) + "   Pack: " + string(_pack_count));
        draw_set_halign(fa_left);

        // 8 equipment slots
        for (var _sl = 0; _sl < 8; _sl++) {
            var _slx    = _pad + floor(_sl / 4) * 580;
            var _sly    = _content_y + 24 + (_sl mod 4) * 120;
            var _is_sel = (_sl == _sel_slot);

            // Slot background — highlight selected row
            if (_is_sel) {
                draw_set_color(make_color_rgb(30, 50, 80));
            } else {
                draw_set_color(make_color_rgb(20, 25, 40));
            }
            draw_rectangle(_slx, _sly, _slx + 520, _sly + 100, false);
            draw_set_color(_is_sel ? make_color_rgb(80, 140, 220) : make_color_rgb(50, 60, 80));
            draw_rectangle(_slx, _sly, _slx + 520, _sly + 100, true);

            var _equipped = undefined;
            if (variable_global_exists("inventory") && array_length(global.inventory) > _sl) {
                _equipped = global.inventory[_sl];
            }
            draw_set_color(_is_sel ? c_white : make_color_rgb(100, 110, 130));
            draw_text(_slx + 10, _sly + 8, _slot_names[_sl]);

            if (_equipped != undefined) {
                var _rcol = item_rarity_color(_equipped.rarity);
                draw_set_color(_rcol);
                draw_text(_slx + 10, _sly + 35, _equipped.name);
                draw_set_color(c_white);
                draw_text(_slx + 10, _sly + 58, _equipped.effect_desc);
                // Legendary unique effect shown in gold on a third line
                if (variable_struct_exists(_equipped, "unique_desc") && _equipped.unique_desc != "") {
                    draw_set_color(make_color_rgb(255, 200, 50));
                    draw_text(_slx + 10, _sly + 78, _equipped.unique_desc);
                    draw_set_color(_rcol);
                }
                draw_set_halign(fa_right);
                draw_text(_slx + 510, _sly + 35, item_rarity_name(_equipped.rarity));
                draw_set_halign(fa_left);
            } else {
                draw_set_color(make_color_rgb(60, 65, 80));
                draw_text(_slx + 10, _sly + 45, "— Empty —");
            }
        }

        // Bottom instruction line
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        if (_gc.equip_picker_open) {
            draw_text(640, 690, "W/S: Navigate   Enter: Equip   Esc: Cancel");
        } else {
            draw_text(640, 690, "W/S: Navigate   Enter: Equip   U: Unequip");
        }
        draw_set_halign(fa_left);

        // --- EQUIP PICKER OVERLAY ---
        if (_gc.equip_picker_open) {
            var _slot_name = _slot_keys[_sel_slot];

            // Build filtered list (same order as Step)
            var _picker_items = [];
            var _picker_src   = [];
            if (variable_global_exists("equipment_stash")) {
                for (var _pi = 0; _pi < array_length(global.equipment_stash); _pi++) {
                    if (global.equipment_stash[_pi].slot == _slot_name) {
                        array_push(_picker_items, global.equipment_stash[_pi]);
                        array_push(_picker_src, 0);   // 0 = stash
                    }
                }
            }
            if (variable_global_exists("carried_items")) {
                for (var _pi = 0; _pi < array_length(global.carried_items); _pi++) {
                    if (global.carried_items[_pi].slot == _slot_name) {
                        array_push(_picker_items, global.carried_items[_pi]);
                        array_push(_picker_src, 1);   // 1 = pack
                    }
                }
            }

            // Picker panel
            var _px      = 240;
            var _py      = 120;
            var _pw      = 800;
            var _row_h   = 72;
            var _visible = array_length(_picker_items);
            var _ph      = max(100, _visible * _row_h + 32);

            draw_set_alpha(0.97);
            draw_set_color(make_color_rgb(12, 15, 28));
            draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(80, 140, 220));
            draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

            draw_set_halign(fa_center);
            draw_set_color(c_white);
            draw_text(_px + _pw / 2, _py + 8, "Choose " + _slot_names[_sel_slot]);
            draw_set_halign(fa_left);

            // Class restriction warning / equip_msg
            if (variable_instance_exists(_gc, "equip_msg") && _gc.equip_msg != "") {
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(255, 120, 60));
                draw_text(_px + _pw / 2, _py + _ph + 6, _gc.equip_msg);
                draw_set_halign(fa_left);
            }

            if (_visible == 0) {
                draw_set_color(make_color_rgb(100, 110, 130));
                draw_text(_px + 20, _py + 40, "No matching items in stash or pack.");
            } else {
                var _pc = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                for (var _ri = 0; _ri < _visible; _ri++) {
                    var _it     = _picker_items[_ri];
                    var _ry     = _py + 32 + _ri * _row_h;
                    var _is_sel = (_ri == _gc.equip_picker_index);
                    var _src    = _picker_src[_ri];
                    var _it_cr  = variable_struct_exists(_it, "class_req") ? _it.class_req : -1;
                    var _locked = (_it_cr != -1 && _it_cr != _pc);

                    draw_set_alpha((_is_sel && !_locked) ? 0.9 : (_locked ? 0.28 : 0.45));
                    draw_set_color(_is_sel ? make_color_rgb(30, 50, 90) : make_color_rgb(18, 22, 38));
                    draw_rectangle(_px + 4, _ry, _px + _pw - 4, _ry + _row_h - 4, false);
                    draw_set_alpha(1.0);

                    var _rcol = _locked ? make_color_rgb(80, 80, 90) : item_rarity_color(_it.rarity);
                    draw_set_color(_rcol);
                    draw_text(_px + 14, _ry + 8, _it.name);

                    // effect_desc (stats line)
                    draw_set_color(_locked ? make_color_rgb(70, 70, 80) : make_color_rgb(150, 160, 185));
                    draw_text(_px + 14, _ry + 34, _it.effect_desc);

                    // Unique effect in gold if present
                    if (!_locked && variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "") {
                        draw_set_color(make_color_rgb(255, 200, 50));
                        draw_text(_px + 14, _ry + 52, _it.unique_desc);
                    }

                    // Source tag, rarity, class restriction
                    draw_set_halign(fa_right);
                    if (_locked) {
                        var _cr_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                        draw_set_color(make_color_rgb(180, 80, 80));
                        draw_text(_px + _pw - 14, _ry + 8, "[" + _cr_names[_it_cr] + " only]");
                    } else {
                        draw_set_color((_src == 0) ? make_color_rgb(120, 200, 120) : make_color_rgb(200, 180, 100));
                        draw_text(_px + _pw - 14, _ry + 8, (_src == 0) ? "[Stash]" : "[Pack]");
                        draw_set_color(_rcol);
                        draw_text(_px + _pw - 14, _ry + 34, item_rarity_name(_it.rarity));
                    }
                    draw_set_halign(fa_left);
                }
            }
        }
    }

    // ---- ABILITIES TAB ----
    if (menu_tab == 2) {
        if (_player != undefined) {
            for (var _ab = 0; _ab < array_length(_player.abilities); _ab++) {
                var _a  = _player.abilities[_ab];
                var _ay = _content_y + _ab * 130;

                draw_set_color(make_color_rgb(20, 28, 48));
                draw_rectangle(_pad, _ay, 1240, _ay + 110, false);
                draw_set_color(make_color_rgb(60, 80, 120));
                draw_rectangle(_pad, _ay, 1240, _ay + 110, true);

                draw_set_color(c_white);
                draw_text(_pad + 14, _ay + 10, _a.name);
                draw_set_color(c_yellow);
                draw_text(_pad + 14, _ay + 38, "Energy: " + string(_a.energy_cost));

                if (_a.base_damage > 0) {
                    draw_set_color(make_color_rgb(220, 100, 80));
                    var _dtype = ["physical", "elemental", "drain"];
                    draw_text(_pad + 140, _ay + 38,
                        "Damage: " + string(_a.base_damage) + " (" + _dtype[_a.damage_type] + ")");
                }

                draw_set_color(make_color_rgb(160, 170, 200));
                draw_text(_pad + 14, _ay + 66, _a.effect_type + " — " + string(_a.effect_value));

                if (_a.guaranteed_hit) {
                    draw_set_color(make_color_rgb(100, 180, 100));
                    draw_text(_pad + 500, _ay + 38, "Always hits");
                }
            }
        }
    }

    // ---- CONSUMABLES TAB ----
    if (menu_tab == 3) {
        var _cons_count     = array_length(global.consumable_inventory);
        var _sub_open       = _gc.consumable_submenu_open;
        var _sub_cur        = _gc.consumable_submenu_cursor;

        // Determine per-turn item limit state
        var _limit_reached = false;
        if (_in_combat) {
            var _ctrl_lim = instance_find(obj_combat_controller, 0);
            if (!_ctrl_lim.player_turn && items_used_this_turn >= 1) {
                _limit_reached = true;
            }
        }

        if (_cons_count == 0) {
            draw_set_color(make_color_rgb(100, 110, 130));
            draw_text(_pad, _content_y + 20, "No consumables in inventory.");
        } else {
            // Status header (combat only)
            if (_in_combat) {
                var _ctrl_hdr = instance_find(obj_combat_controller, 0);
                if (!_ctrl_hdr.player_turn) {
                    if (_limit_reached) {
                        draw_set_color(c_red);
                        draw_text(_pad, _content_y, "Item use limit reached for this enemy turn.");
                    } else {
                        draw_set_color(c_yellow);
                        draw_text(_pad, _content_y, "Enemy turn — 1 item use remaining.");
                    }
                }
            }

            for (var _ci = 0; _ci < _cons_count; _ci++) {
                var _c      = global.consumable_inventory[_ci];
                var _cy2    = _content_y + 40 + _ci * 80;
                var _is_cur = (_sub_open && _ci == _sub_cur);

                // Background — highlighted when this row is the cursor
                if (_is_cur) {
                    draw_set_color(make_color_rgb(30, 80, 80));
                } else {
                    draw_set_color(make_color_rgb(20, 30, 48));
                }
                draw_rectangle(_pad, _cy2, 900, _cy2 + 65, false);

                // Border
                if (_is_cur && !_limit_reached) {
                    draw_set_color(make_color_rgb(80, 220, 220));
                } else if (_is_cur && _limit_reached) {
                    draw_set_color(make_color_rgb(180, 60, 60));
                } else if (_sub_open) {
                    draw_set_color(make_color_rgb(30, 90, 90));
                } else {
                    draw_set_color(make_color_rgb(40, 140, 140));
                }
                draw_rectangle(_pad, _cy2, 900, _cy2 + 65, true);

                // Name
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(50, 130, 130));
                } else if (_is_cur && _limit_reached) {
                    draw_set_color(make_color_rgb(200, 100, 100));
                } else if (_is_cur) {
                    draw_set_color(make_color_rgb(120, 255, 255));
                } else {
                    draw_set_color(make_color_rgb(80, 220, 220));
                }
                draw_text(_pad + 12, _cy2 + 8, _c.name);

                // Description
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(70, 80, 95));
                } else {
                    draw_set_color(c_white);
                }
                draw_text(_pad + 12, _cy2 + 36, _c.description);

                // Gold value
                draw_set_halign(fa_right);
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(80, 90, 60));
                } else {
                    draw_set_color(c_yellow);
                }
                draw_text(890, _cy2 + 8, string(_c.gold_value) + "g value");
                draw_set_halign(fa_left);
            }
        }
    }

    // Bottom instructions
    if (menu_tab != 1 && menu_tab != 3) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        draw_text(640, 690, "Q/E: Switch Tab   I: Close");
        draw_set_halign(fa_left);
    }
    if (menu_tab == 3) {
        draw_set_halign(fa_center);
        if (_gc.consumable_submenu_open && array_length(global.consumable_inventory) > 0) {
            if (_limit_reached) {
                draw_set_color(make_color_rgb(200, 80, 80));
                draw_text(640, 690, "W/S: Navigate   1 per turn limit   Esc: Cancel");
            } else {
                draw_set_color(make_color_rgb(80, 90, 110));
                draw_text(640, 690, "W/S: Navigate   Enter: Use   Esc: Cancel");
            }
        } else {
            draw_set_color(make_color_rgb(100, 200, 100));
            draw_text(640, 690, "Enter: Browse Items   Q/E: Switch Tab   I: Close");
        }
        draw_set_halign(fa_left);
    }
}

// ---------------------------------------------------------------------------
// ui_draw_shop_screen()
// Full-screen overlay for Petra's Supplies (shop_open==0) or Dorn's Forge
// (shop_open==1). Draws all purchasable rows, gold balance, and a notification
// line. Called by obj_hub_controller Draw_64 after the stash screen call.
// ---------------------------------------------------------------------------
function ui_draw_shop_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc  = instance_find(obj_game_controller, 0);
    if (_gc.shop_open == -1) return;

    var _is_petra = (_gc.shop_open == 0);
    var _accent   = _is_petra ? make_color_rgb(60, 190, 190) : make_color_rgb(210, 130, 40);
    var _title    = _is_petra ? "PETRA'S SUPPLIES" : "DORN'S FORGE";

    // Full-screen dark cover
    draw_set_alpha(0.96);
    draw_set_color(make_color_rgb(8, 10, 18));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(_accent);
    draw_text_transformed(640, 18, _title, 1.5, 1.5, 0);

    // Gold (top-right)
    draw_set_halign(fa_right);
    draw_set_color(c_yellow);
    draw_text(1260, 22, "Gold: " + string(global.gold) + "g");

    // --- BUY / SELL tab bar ---
    var _tab_y = 58;
    var _tab_h = 26;

    // BUY tab (left of center)
    var _buy_on = (_gc.shop_tab == 0);
    draw_set_color(_buy_on ? make_color_rgb(16, 32, 22) : make_color_rgb(12, 14, 20));
    draw_rectangle(400, _tab_y, 625, _tab_y + _tab_h, false);
    draw_set_color(_buy_on ? _accent : make_color_rgb(30, 42, 50));
    draw_rectangle(400, _tab_y, 625, _tab_y + _tab_h, true);
    draw_set_halign(fa_center);
    draw_set_color(_buy_on ? _accent : make_color_rgb(70, 88, 100));
    draw_text(512, _tab_y + 6, "BUY");

    // SELL tab (right of center)
    var _sell_on = (_gc.shop_tab == 1);
    draw_set_color(_sell_on ? make_color_rgb(32, 24, 10) : make_color_rgb(12, 14, 20));
    draw_rectangle(655, _tab_y, 880, _tab_y + _tab_h, false);
    draw_set_color(_sell_on ? make_color_rgb(220, 155, 45) : make_color_rgb(30, 42, 50));
    draw_rectangle(655, _tab_y, 880, _tab_y + _tab_h, true);
    draw_set_color(_sell_on ? make_color_rgb(220, 155, 45) : make_color_rgb(70, 88, 100));
    draw_text(767, _tab_y + 6, "SELL");

    // Q/E hint between tabs
    draw_set_color(make_color_rgb(50, 60, 80));
    draw_text(640, _tab_y + 6, "Q/E");
    draw_set_halign(fa_left);

    // Notification line (shifted below tab bar)
    if (_gc.shop_notification != "") {
        draw_set_halign(fa_center);
        var _is_sold_notif = (string_pos("Sold for", _gc.shop_notification) > 0);
        var _is_bad_notif  = (string_pos("Not enough", _gc.shop_notification) > 0);
        var _notif_col;
        if (_is_bad_notif) {
            _notif_col = c_red;
        } else if (_is_sold_notif) {
            _notif_col = c_yellow;
        } else {
            _notif_col = make_color_rgb(100, 220, 120);
        }
        draw_set_color(_notif_col);
        draw_text(640, 92, _gc.shop_notification);
        draw_set_halign(fa_left);
    }

    var _rx0  = 100;
    var _rw   = 1080;
    var _rh   = 78;    // tall enough for 3 lines (stats + unique desc / class tag)
    var _rgap = 6;
    var _ry0  = 126;   // shifted down from 112 to make room for tab bar

    // =========================================================================
    // SELL TAB
    // =========================================================================
    if (_gc.shop_tab == 1) {

        // Build the sell list: stash equipment → stash consumables → carried equipment → carried consumables.
        // global.inventory[] (equipped slots) is excluded entirely.
        var _sl_items = [];
        var _sl_src   = [];
        var _sl_tags  = [];

        for (var _i = 0; _i < array_length(global.equipment_stash); _i++) {
            array_push(_sl_items, global.equipment_stash[_i]);
            array_push(_sl_src,   0);
            array_push(_sl_tags,  "[STASH]");
        }
        for (var _i = 0; _i < array_length(global.consumable_stash); _i++) {
            array_push(_sl_items, global.consumable_stash[_i]);
            array_push(_sl_src,   1);
            array_push(_sl_tags,  "[STASH]");
        }
        for (var _i = 0; _i < array_length(global.carried_items); _i++) {
            array_push(_sl_items, global.carried_items[_i]);
            array_push(_sl_src,   2);
            array_push(_sl_tags,  "[CARRIED]");
        }
        for (var _i = 0; _i < array_length(global.consumable_inventory); _i++) {
            array_push(_sl_items, global.consumable_inventory[_i]);
            array_push(_sl_src,   3);
            array_push(_sl_tags,  "[CARRIED]");
        }
        var _sl_count = array_length(_sl_items);

        if (_sl_count == 0) {
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(90, 100, 120));
            draw_text(640, 320, "Nothing to sell.");
            draw_set_halign(fa_left);
        } else {
            var _sell_idx    = clamp(_gc.sell_index, 0, _sl_count - 1);
            var _sell_scroll = clamp(_gc.sell_scroll, 0, max(0, _sl_count - 7));
            var _visible_end = min(_sell_scroll + 7, _sl_count);

            for (var _ri = _sell_scroll; _ri < _visible_end; _ri++) {
                var _ry    = _ry0 + (_ri - _sell_scroll) * (_rh + _rgap);
                var _it    = _sl_items[_ri];
                var _is_sel = (_ri == _sell_idx);

                // Compute sell price
                var _gv = 0;
                if (variable_struct_exists(_it, "gold_value")) {
                    _gv = _it.gold_value;
                }
                if (_gv == 0 && variable_struct_exists(_it, "rarity")) {
                    if (_it.rarity == 0)      _gv = 15;
                    else if (_it.rarity == 1) _gv = 32;
                    else if (_it.rarity == 2) _gv = 82;
                    else if (_it.rarity == 3) _gv = 200;
                    else                      _gv = 400;
                }
                var _sprice = max(1, floor(_gv * 0.4));

                // Name color: rarity color for equipment, cyan for consumables
                var _name_col;
                if (variable_struct_exists(_it, "rarity")) {
                    _name_col = item_rarity_color(_it.rarity);
                } else {
                    _name_col = make_color_rgb(80, 210, 210);
                }

                // Row background
                draw_set_alpha(_is_sel ? 1.0 : 0.55);
                draw_set_color(_is_sel ? make_color_rgb(30, 26, 10) : make_color_rgb(14, 18, 28));
                draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, false);
                draw_set_alpha(1.0);
                draw_set_color(_is_sel ? make_color_rgb(200, 155, 40) : make_color_rgb(55, 50, 25));
                draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, true);

                // Name
                draw_set_color(_name_col);
                draw_text(_rx0 + 16, _ry + 10, _it.name);

                // Description: stat line + unique effect for legendaries
                var _desc = "";
                if (variable_struct_exists(_it, "effect_desc")) {
                    _desc = _it.effect_desc;
                } else if (variable_struct_exists(_it, "description")) {
                    _desc = _it.description;
                }
                draw_set_color(make_color_rgb(130, 140, 155));
                draw_text(_rx0 + 16, _ry + 36, _desc);
                if (variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "") {
                    draw_set_color(make_color_rgb(200, 160, 40));
                    draw_text(_rx0 + 16, _ry + 52, _it.unique_desc);
                }

                // Right side: source tag + sell price + class restriction if any
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(155, 165, 180));
                draw_text(_rx0 + _rw - 16, _ry + 10, _sl_tags[_ri]);
                draw_set_color(c_yellow);
                draw_text(_rx0 + _rw - 16, _ry + 36, string(_sprice) + "g");
                if (variable_struct_exists(_it, "class_req") && _it.class_req != -1) {
                    var _cr_labels = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                    draw_set_color(make_color_rgb(160, 110, 60));
                    draw_text(_rx0 + _rw - 16, _ry + 52, "[" + _cr_labels[_it.class_req] + "]");
                }
                draw_set_halign(fa_left);
            }

            // Scroll indicator
            if (_sl_count > 7) {
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(80, 90, 110));
                draw_text(640, _ry0 + 7 * (_rh + _rgap) + 4, "W/S to scroll  (" + string(_sl_count) + " items)");
                draw_set_halign(fa_left);
            }
        }

        // Confirm bar for rare+ items (amber highlight)
        if (_gc.sell_confirm_name != "") {
            var _cf_y = 636;
            draw_set_color(make_color_rgb(50, 30, 8));
            draw_rectangle(100, _cf_y, 1180, _cf_y + 46, false);
            draw_set_color(make_color_rgb(220, 145, 40));
            draw_rectangle(100, _cf_y, 1180, _cf_y + 46, true);
            draw_set_halign(fa_center);
            draw_set_color(c_white);
            draw_text(640, _cf_y + 12, _gc.shop_notification + "   [SPACE] Confirm   [ESC] Cancel");
            draw_set_halign(fa_left);
        }

        // Sell tab footer — swaps to confirm hint when rare+ item confirmation is pending
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(75, 85, 105));
        if (_gc.sell_confirm_name != "") {
            draw_text(640, 695, "SPACE to confirm   ESC to cancel");
        } else {
            draw_text(640, 695, "W/S: Navigate   Q/E: Buy/Sell   Enter: Sell   Esc: Close");
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
        return;
    }

    // =========================================================================
    // BUY TAB — unchanged buy content
    // =========================================================================

    // -------------------------------------------------------------------------
    // PETRA — 4 standard consumables always, plus optional limited special
    // -------------------------------------------------------------------------
    if (_is_petra) {
        var _has_spec  = (global.petra_stock_special != undefined && global.petra_special_qty > 0);
        var _row_count = 4 + (_has_spec ? 1 : 0);

        for (var _ri = 0; _ri < _row_count; _ri++) {
            var _ry      = _ry0 + _ri * (_rh + _rgap);
            var _is_sel  = (_ri == _gc.shop_index);
            var _is_spec = (_ri == 4);

            var _it;
            var _price;
            if (_is_spec) {
                _it    = global.petra_stock_special;
                _price = floor(_it.gold_value * 2);
            } else {
                _it    = global.consumables_standard[_ri];
                _price = floor(_it.gold_value * 1.5);
            }

            draw_set_alpha(_is_sel ? 1.0 : 0.55);
            draw_set_color(_is_sel ? make_color_rgb(16, 42, 50) : make_color_rgb(14, 18, 28));
            draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_sel ? make_color_rgb(55, 170, 170) : make_color_rgb(38, 75, 85));
            draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, true);

            // Name
            draw_set_color(make_color_rgb(80, 210, 210));
            draw_text(_rx0 + 16, _ry + 10, _it.name);

            // Description
            draw_set_color(make_color_rgb(130, 160, 170));
            draw_text(_rx0 + 16, _ry + 38, _it.description);

            // Limited tag
            if (_is_spec) {
                draw_set_color(make_color_rgb(255, 155, 30));
                draw_set_halign(fa_right);
                draw_text(_rx0 + _rw - 150, _ry + 10, "[LIMITED — " + string(global.petra_special_qty) + " left]");
                draw_set_halign(fa_left);
            }

            // Price (right-aligned)
            var _can_afford = (global.gold >= _price);
            draw_set_color(_can_afford ? c_yellow : make_color_rgb(180, 80, 80));
            draw_set_halign(fa_right);
            draw_text(_rx0 + _rw - 16, _ry + 38, string(_price) + "g");
            draw_set_halign(fa_left);
        }

    // -------------------------------------------------------------------------
    // DORN — rotating gear list; sold entries appear greyed with SOLD tag
    // -------------------------------------------------------------------------
    } else {
        var _dorn_count = array_length(global.dorn_stock);

        for (var _ri = 0; _ri < _dorn_count; _ri++) {
            var _ry      = _ry0 + _ri * (_rh + _rgap);
            var _entry   = global.dorn_stock[_ri];
            var _is_sold = _entry.sold;
            var _is_sel  = (!_is_sold && _ri == _gc.shop_index);

            draw_set_alpha(_is_sold ? 0.28 : (_is_sel ? 1.0 : 0.55));
            draw_set_color(_is_sel ? make_color_rgb(38, 28, 10) : make_color_rgb(14, 18, 28));
            draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_sold ? make_color_rgb(45, 45, 45)
                         : (_is_sel ? make_color_rgb(195, 135, 38) : make_color_rgb(75, 58, 28)));
            draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, true);

            if (_is_sold) {
                draw_set_color(make_color_rgb(65, 65, 65));
                draw_text(_rx0 + 16, _ry + 10, _entry.item.name);
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(75, 75, 75));
                draw_text(_rx0 + _rw - 16, _ry + 28, "SOLD");
                draw_set_halign(fa_left);
            } else {
                var _rcol = item_rarity_color(_entry.item.rarity);
                draw_set_color(_rcol);
                draw_text(_rx0 + 16, _ry + 10, _entry.item.name);

                draw_set_color(make_color_rgb(135, 145, 165));
                draw_text(_rx0 + 16, _ry + 38, _entry.item.effect_desc);

                var _can_afford = (global.gold >= _entry.price);
                draw_set_color(_can_afford ? c_yellow : make_color_rgb(180, 80, 80));
                draw_set_halign(fa_right);
                draw_text(_rx0 + _rw - 16, _ry + 38, string(_entry.price) + "g");
                draw_set_color(_rcol);
                draw_text(_rx0 + _rw - 16, _ry + 10, "[" + item_rarity_name(_entry.item.rarity) + "]");
                draw_set_halign(fa_left);
            }
        }
    }

    // Buy tab footer
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(75, 85, 105));
    draw_text(640, 695, "W/S: Navigate   Q/E: Buy/Sell   Enter: Buy   Esc: Close     Purchases go to your stash.");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_stash_screen()
// Two-column stash management overlay drawn in the hub.
// Left column: items taken on the run (at risk). Right: safe stash.
// Called by obj_hub_controller Draw_64 after the history overlay.
// ---------------------------------------------------------------------------
function ui_draw_stash_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!_gc.stash_mode_open) return;

    // Full-screen opaque cover
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(8, 10, 18));
    draw_rectangle(0, 0, 1280, 720, false);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_transformed(640, 18, "ITEM STASH", 1.3, 1.3, 0);

    // Subtitle warning
    draw_set_color(make_color_rgb(180, 150, 80));
    draw_text(640, 54, "Equipped gear is always safe.   Carried items are lost on death (1 random salvage).");
    draw_set_halign(fa_left);

    var _ly      = 82;
    var _col_w   = 570;
    var _row_h   = 50;
    var _max_bot = 680;

    // Build left list: carried equipment then consumable_inventory
    var _left_items = [];
    var _left_types = [];  // 0 = equipment, 1 = consumable
    for (var _i = 0; _i < array_length(global.carried_items); _i++) {
        array_push(_left_items, global.carried_items[_i]);
        array_push(_left_types, 0);
    }
    for (var _i = 0; _i < array_length(global.consumable_inventory); _i++) {
        array_push(_left_items, global.consumable_inventory[_i]);
        array_push(_left_types, 1);
    }

    // Build right list: equipment_stash then consumable_stash
    var _right_items = [];
    var _right_types = [];
    for (var _i = 0; _i < array_length(global.equipment_stash); _i++) {
        array_push(_right_items, global.equipment_stash[_i]);
        array_push(_right_types, 0);
    }
    for (var _i = 0; _i < array_length(global.consumable_stash); _i++) {
        array_push(_right_items, global.consumable_stash[_i]);
        array_push(_right_types, 1);
    }

    var _left_active  = (_gc.stash_mode_side == 0);
    var _right_active = (_gc.stash_mode_side == 1);

    // ---- LEFT COLUMN ----
    var _lx = 30;
    draw_set_color(_left_active ? make_color_rgb(80, 160, 220) : make_color_rgb(45, 55, 75));
    draw_rectangle(_lx, _ly, _lx + _col_w, _max_bot, true);

    draw_set_color(make_color_rgb(200, 100, 80));
    draw_text(_lx + 10, _ly + 6, "TAKING ON RUN  (at risk)");

    var _item_y = _ly + 30;
    for (var _i = 0; _i < array_length(_left_items); _i++) {
        if (_item_y + _row_h > _max_bot) break;
        var _it     = _left_items[_i];
        var _is_sel = (_left_active && _gc.stash_mode_index == _i);

        draw_set_alpha(_is_sel ? 0.9 : 0.5);
        draw_set_color(_is_sel ? make_color_rgb(30, 50, 80) : make_color_rgb(18, 22, 38));
        draw_rectangle(_lx + 4, _item_y, _lx + _col_w - 4, _item_y + _row_h - 2, false);
        draw_set_alpha(1.0);

        var _col = (_left_types[_i] == 1) ? make_color_rgb(80, 220, 220) : item_rarity_color(_it.rarity);
        draw_set_color(_col);
        draw_text(_lx + 12, _item_y + 5, _it.name);
        draw_set_color(make_color_rgb(140, 150, 170));
        draw_text(_lx + 12, _item_y + 26, (_left_types[_i] == 1) ? _it.description : _it.effect_desc);

        _item_y += _row_h;
    }
    if (array_length(_left_items) == 0) {
        draw_set_color(make_color_rgb(70, 80, 100));
        draw_text(_lx + 12, _ly + 38, "Nothing in pack.");
    }

    // ---- RIGHT COLUMN ----
    var _rx = 680;
    draw_set_color(_right_active ? make_color_rgb(80, 160, 220) : make_color_rgb(45, 55, 75));
    draw_rectangle(_rx, _ly, _rx + _col_w, _max_bot, true);

    draw_set_color(make_color_rgb(100, 200, 100));
    draw_text(_rx + 10, _ly + 6, "STASH  (safe)");

    _item_y = _ly + 30;
    for (var _i = 0; _i < array_length(_right_items); _i++) {
        if (_item_y + _row_h > _max_bot) break;
        var _it     = _right_items[_i];
        var _is_sel = (_right_active && _gc.stash_mode_index == _i);

        draw_set_alpha(_is_sel ? 0.9 : 0.5);
        draw_set_color(_is_sel ? make_color_rgb(30, 50, 80) : make_color_rgb(18, 22, 38));
        draw_rectangle(_rx + 4, _item_y, _rx + _col_w - 4, _item_y + _row_h - 2, false);
        draw_set_alpha(1.0);

        var _col = (_right_types[_i] == 1) ? make_color_rgb(80, 220, 220) : item_rarity_color(_it.rarity);
        draw_set_color(_col);
        draw_text(_rx + 12, _item_y + 5, _it.name);
        draw_set_color(make_color_rgb(140, 150, 170));
        draw_text(_rx + 12, _item_y + 26, (_right_types[_i] == 1) ? _it.description : _it.effect_desc);

        _item_y += _row_h;
    }
    if (array_length(_right_items) == 0) {
        draw_set_color(make_color_rgb(70, 80, 100));
        draw_text(_rx + 12, _ly + 38, "Nothing in stash.");
    }

    // Footer
    draw_set_halign(fa_center);
    draw_set_color(c_gray);
    draw_text(640, 698, "Q/E: Switch Side   W/S: Navigate   Enter: Move Item   Esc: Close");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}
