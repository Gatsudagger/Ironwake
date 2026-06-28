// =============================================================================
// obj_title_controller - Draw GUI
// =============================================================================

// Deep background
draw_set_color(make_color_rgb(6, 7, 12));
draw_rectangle(0, 0, GUI_W, GUI_H, false);

// -----------------------------------------------------------------------
// INTRO SCENE BACKDROP + AMBIENT (forest/town/crypt vista, shooting star,
// red-moon glow, twinkling stars, drifting fog). Drawn under the edge
// vignette below so its frame deepens the scene's forest-opening edges.
// -----------------------------------------------------------------------
// Per-phase fade + pan: cutscene = dim & panning; title/slot = bright.
var _scene_a   = scene_alpha;
var _scene_pan = scene_pan;

// Moon-glow screen position is resolved from the same pan/scale as the scene so
// the halo stays locked to the painted moon. -1 = no vista (skip the glow).
var _moon_x = -1, _moon_y = -1, _moon_r = 0;

if (scene_sprite != -1 && sprite_exists(scene_sprite) && _scene_a > 0.01) {
    var _sw  = sprite_get_width(scene_sprite);
    var _sh  = sprite_get_height(scene_sprite);
    if (_sw > 0 && _sh > 0) {
        // Cover by height (the vista is wider than 16:9) so the full sky/moon
        // shows and the extra width becomes horizontal pan room.
        var _ssc0     = GUI_H / _sh;
        var _sdw0     = _sw * _ssc0;
        var _overscan = max(0, _sdw0 - GUI_W);
        var _sx0      = -_overscan * _scene_pan;

        // Subtle dolly-in toward the town: the vista scales up a little over the
        // intro (scaled around screen centre) so the backdrop reads as approaching
        // rather than static. Moon-glow tracking recomputed from the zoomed values.
        var _z   = lerp(1.0, 1.12, intro_t);
        var _ssc = _ssc0 * _z;
        var _sx  = GUI_CX + (_sx0 - GUI_CX) * _z;
        var _sy  = GUI_CY * (1 - _z);
        draw_sprite_ext(scene_sprite, 0, _sx, _sy, _ssc, _ssc, 0, c_white, _scene_a);

        _moon_x = _sx + moon_fx * _sw * _ssc;
        _moon_y = _sy + moon_fy * _sh * _ssc;
        _moon_r = moon_fr * _sw * _ssc;
    }
}

if (_scene_a > 0.01) {
    // --- Twinkling stars (upper sky) ---
    for (var _si = 0; _si < array_length(sky_stars); _si++) {
        var _st = sky_stars[_si];
        var _sa = _st.a * (0.45 + 0.55 * sin(current_time / 600 + _st.phase)) * _scene_a;
        if (_sa > 0) {
            draw_set_alpha(_sa);
            draw_set_color(make_color_rgb(210, 220, 245));
            draw_rectangle(_st.x, _st.y, _st.x + _st.size, _st.y + _st.size, false);
        }
    }

    // --- Drifting fog/mist banks (soft horizontal gradient bands) ---
    for (var _fi = 0; _fi < array_length(fog_layers); _fi++) {
        var _fl  = fog_layers[_fi];
        var _fy  = _fl.y + sin(current_time * _fl.spd + _fl.off) * 10;
        var _fa  = _fl.a * (0.65 + 0.35 * sin(current_time / 2500 + _fl.off)) * _scene_a;
        var _fcl = make_color_rgb(86, 96, 118);
        var _fh  = 90;   // band half-height (transparent -> fog -> transparent)
        draw_primitive_begin(pr_trianglestrip);
        draw_vertex_color(0,     _fy - _fh, _fcl, 0);
        draw_vertex_color(GUI_W, _fy - _fh, _fcl, 0);
        draw_vertex_color(0,     _fy,       _fcl, _fa);
        draw_vertex_color(GUI_W, _fy,       _fcl, _fa);
        draw_vertex_color(0,     _fy + _fh, _fcl, 0);
        draw_vertex_color(GUI_W, _fy + _fh, _fcl, 0);
        draw_primitive_end();
    }
    draw_set_alpha(1.0);

    // --- Red-moon glow (soft additive halo, slow pulse) - tracks the painted moon ---
    if (_moon_x >= 0) {
        var _mp    = 0.5 + 0.5 * sin(current_time / 950);
        var _mglow = (0.07 + 0.06 * _mp) * _scene_a;
        gpu_set_blendmode(bm_add);
        draw_set_color(make_color_rgb(185, 38, 26));
        for (var _g = 3; _g >= 1; _g--) {
            draw_set_alpha(_mglow / _g);
            draw_circle(_moon_x, _moon_y, _moon_r * (0.6 + _g * 0.55), false);
        }
        gpu_set_blendmode(bm_normal);
        draw_set_alpha(1.0);
    }

    // --- Shooting star: update timer/motion then draw the streak ---
    if (!star_active) {
        star_timer--;
        if (star_timer <= 0) {
            star_active  = true;
            var _fromleft = (random(1) < 0.5);
            star_y        = 40 + irandom(190);
            var _spd      = 17 + random(9);
            star_dx       = _fromleft ?  _spd : -_spd;
            star_x        = _fromleft ? -60  : (GUI_W + 60);
            star_dy       = 5 + random(5);
            star_maxlife  = 90;
            star_life     = star_maxlife;
        }
    } else {
        star_x += star_dx;
        star_y += star_dy;
        star_life--;
        if (star_life <= 0 || star_x < -90 || star_x > GUI_W + 90) {
            star_active = false;
            star_timer  = 300 + irandom(450);   // ~5-12s between streaks
        }
    }

    if (star_active) {
        // Fade in over the first frames, out over the last - never a hard pop.
        var _ta = _scene_a
                * clamp(star_life / 22.0, 0, 1)
                * clamp((star_maxlife - star_life) / 8.0, 0, 1);
        gpu_set_blendmode(bm_add);
        for (var _t = 7; _t >= 1; _t--) {       // tail behind the head
            var _px = star_x - star_dx * _t * 0.55;
            var _py = star_y - star_dy * _t * 0.55;
            draw_set_alpha(_ta * (1 - _t / 8.0));
            draw_set_color(make_color_rgb(190, 205, 255));
            draw_circle(_px, _py, max(0.5, 2.3 - _t * 0.22), false);
        }
        draw_set_alpha(_ta);
        draw_set_color(c_white);
        draw_circle(star_x, star_y, 2.6, false);
        gpu_set_blendmode(bm_normal);
        draw_set_alpha(1.0);
    }

    draw_set_color(c_white);
}

// -----------------------------------------------------------------------
// PARALLAX FOREGROUND LAYER (near treeline silhouette)
// Drawn in FRONT of the vista + sky ambient (stars/moon/fog/shooting star) but
// BEHIND the vignette and text crawl. A transparent-sky pine treeline clump is
// tiled across the bottom and panned faster than the vista so it reads as a
// closer plane -> depth. Alternate tiles are MIRRORED, which makes their edges
// match exactly (seamless) and hides the single-clump repeat. Optional: no-ops
// cleanly until spr_title_foreground is imported, so the intro never breaks.
// -----------------------------------------------------------------------
{
    var _fg = asset_get_index("spr_title_foreground");
    // Foreground fades OUT as we push through it on arrival (held solid until the
    // title starts loading). screen_alpha covers the initial scene fade-in so the
    // trees come up with the rest of the vista rather than popping in.
    var _fg_t    = intro_t;
    var _fg_fade = 1 - clamp((_fg_t - 0.45) / 0.45, 0, 1);   // solid <=0.45, gone by 0.9
    var _fg_a    = screen_alpha * _fg_fade * 0.95;
    if (_fg != -1 && sprite_exists(_fg) && _fg_a > 0.01) {
        var _fw = sprite_get_width(_fg);
        var _fh = sprite_get_height(_fg);
        if (_fw > 0 && _fh > 0) {
            // Dolly-forward: the treeline GROWS (gets closer) and SINKS below the
            // camera as intro_t rises, so it reads as the viewer moving through the
            // forest edge toward the town.
            var _target_h = GUI_H * lerp(0.52, 1.15, _fg_t);
            var _fsc      = _target_h / _fh;
            var _tile_w   = _fw * _fsc;
            var _fy       = GUI_H - _target_h + _target_h * 0.55 * _fg_t;
            var _pan_px   = 420 * _fg_t;                 // gentle horizontal drift too

            // Tile across the screen (+ a tile of margin each side). Even tiles
            // normal, odd tiles mirrored so the seams match exactly (seamless).
            var _first = floor(_pan_px / _tile_w) - 1;
            var _last  = _first + ceil(GUI_W / _tile_w) + 2;
            for (var _t = _first; _t <= _last; _t++) {
                var _tx  = _t * _tile_w - _pan_px;
                var _mir = ((_t & 1) == 0) ? 1 : -1;
                var _ox  = (_mir == 1) ? _tx : _tx + _tile_w;
                draw_sprite_ext(_fg, 0, _ox, _fy, _fsc * _mir, _fsc, 0, c_white, _fg_a);
            }
        }
    }
}

// Atmospheric edge vignette
draw_set_alpha(0.35);
draw_set_color(c_black);
draw_rectangle(0,    0,    270,   GUI_H, false);
draw_rectangle(1650, 0,    GUI_W, GUI_H, false);
draw_rectangle(0,    0,    GUI_W, 150,   false);
draw_rectangle(0,    930,  GUI_W, GUI_H, false);
draw_set_alpha(1.0);

// -----------------------------------------------------------------------
// CUTSCENE PHASE
// -----------------------------------------------------------------------
if (phase == "cutscene") {
    // Soft central scrim so the crawl stays legible over the lit vista without
    // hiding the sky (stars/moon) above or the fog below. Peaks in the text band.
    var _scrim = make_color_rgb(4, 5, 9);
    draw_primitive_begin(pr_trianglestrip);
    draw_vertex_color(0,     250, _scrim, 0);    draw_vertex_color(GUI_W, 250, _scrim, 0);
    draw_vertex_color(0,     540, _scrim, 0.5);  draw_vertex_color(GUI_W, 540, _scrim, 0.5);
    draw_vertex_color(0,     830, _scrim, 0);    draw_vertex_color(GUI_W, 830, _scrim, 0);
    draw_primitive_end();
    draw_set_alpha(1.0);
    draw_set_color(c_white);

    draw_set_font(fnt_ui);
    var _num_panels = array_length(cutscene_panels);
    var _sep        = 48;   // line separation WITHIN a panel
    var _gap        = 33;   // extra space BETWEEN panels

    // Each panel is a multi-line string (\n). Measure real heights so a 3-line
    // panel can't overlap the next one, and center the whole block vertically.
    var _heights = array_create(_num_panels, 0);
    var _total_h = 0;
    for (var _i = 0; _i < _num_panels; _i++) {
        var _ln = string_count("\n", cutscene_panels[_i]) + 1;
        _heights[_i] = _ln * _sep;
        _total_h += _heights[_i] + (_i > 0 ? _gap : 0);
    }
    var _cy = GUI_CY - _total_h * 0.5;

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_alpha(screen_alpha);

    // All completed panels - fully visible, advanced by each panel's real height
    for (var _i = 0; _i < panel_idx; _i++) {
        draw_set_color(c_black);
        draw_text_ext(962, _cy + 2, cutscene_panels[_i], _sep, 1350);
        draw_set_color(make_color_rgb(205, 208, 220));
        draw_text_ext(960, _cy, cutscene_panels[_i], _sep, 1350);
        _cy += _heights[_i] + _gap;
    }

    // Currently typing panel
    if (panel_idx < _num_panels) {
        var _visible = string_copy(cutscene_panels[panel_idx], 1, floor(typed_chars));
        draw_set_color(c_black);
        draw_text_ext(962, _cy + 2, _visible, _sep, 1350);
        draw_set_color(make_color_rgb(205, 208, 220));
        draw_text_ext(960, _cy, _visible, _sep, 1350);
    }

    draw_set_alpha(1.0);

    // Skip hint fades in after grace period
    if (skip_timer > skip_hold) {
        var _hint_a = min(0.55, (skip_timer - skip_hold) / 40.0);
        draw_set_alpha(_hint_a);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(90, 95, 115));
        draw_text(960, 998, "Press any key to skip");
        draw_set_alpha(1.0);
    }
    draw_set_font(-1);

// -----------------------------------------------------------------------
// TITLE PHASE
// -----------------------------------------------------------------------
} else if (phase == "title") {

    // --- Logo ---
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui_title);
    draw_set_alpha(title_alpha);

    // Glow layer (color underlay)
    draw_set_alpha(title_alpha * 0.18);
    draw_set_color(make_color_rgb(60, 120, 200));
    draw_text(960, 300, "IRONWAKE");

    // Shadow
    draw_set_alpha(title_alpha);
    draw_set_color(make_color_rgb(15, 40, 70));
    draw_text(966, 306, "IRONWAKE");

    // Main title
    draw_set_color(make_color_rgb(130, 195, 255));
    draw_text(960, 300, "IRONWAKE");

    // Subtitle (black outline so it stays legible over the lit vista)
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(120, 134, 160));
    draw_text_outline(960, 402, "A  R O G U E L I T E  D U N G E O N  C R A W L E R");

    // Decorative line under subtitle
    draw_set_alpha(title_alpha * 0.4);
    draw_set_color(make_color_rgb(60, 100, 160));
    draw_rectangle(585, 428, 1335, 431, false);
    draw_set_alpha(title_alpha);

    // --- Menu options ---
    draw_set_alpha(menu_alpha);

    // Check if any save exists to enable Load Game
    var _any_save = (slot_previews[0] != undefined
                  || slot_previews[1] != undefined
                  || slot_previews[2] != undefined);

    var _options = ["NEW GAME", "LOAD GAME"];
    for (var _i = 0; _i < 2; _i++) {
        var _oy     = 585 + _i * 93;
        var _is_sel = (_i == selected);
        var _avail  = (_i == 0) || _any_save;

        if (_is_sel && _avail) {
            if (blink < 30) {
                draw_set_alpha(menu_alpha * 0.12);
                draw_set_color(make_color_rgb(80, 140, 220));
                draw_rectangle(660, _oy - 33, 1260, _oy + 33, false);
                draw_set_alpha(menu_alpha);
            }
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(130, 195, 255));
            draw_text_outline(698, _oy, ">");
        }

        draw_set_font(fnt_ui);
        draw_set_color(_avail ? c_white : make_color_rgb(110, 116, 134));
        draw_text_outline(960, _oy, _options[_i]);

        if (_i == 1 && !_any_save) {
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(120, 125, 142));
            draw_text_outline(960, _oy + 39, "no saves found");
        }
    }

    if (can_input && blink < 42) {
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(100, 110, 135));
        draw_text_outline(960, 818, "W/S: Navigate   Enter / Space: Select");
    }

    // Settings hint (always shown on the title screen)
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(130, 140, 165));
    draw_text_outline(960, 1035, "[ O ]  Settings");

    draw_set_alpha(1.0);
    draw_set_font(-1);

// -----------------------------------------------------------------------
// SLOT PICKER PHASE
// -----------------------------------------------------------------------
} else if (phase == "slot_picker") {

    // Background title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(130, 195, 255));
    draw_text(960, 120, slot_mode == "new_game" ? "SELECT SAVE SLOT - NEW GAME" : "SELECT SAVE SLOT - LOAD GAME");
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(70, 80, 105));
    draw_text_outline(960, 177, slot_mode == "new_game" ? "A/D to choose slot   Enter to confirm   Esc to go back" : "A/D to choose slot   Enter to load   Esc to go back");

    // Draw 3 slot cards
    var _card_w  = 510;
    var _card_h  = 330;
    var _card_y  = 330;
    var _gap     = 45;
    var _total_w = _card_w * 3 + _gap * 2;
    var _start_x = GUI_CX - _total_w / 2;

    for (var _s = 0; _s < 3; _s++) {
        var _cx      = _start_x + _s * (_card_w + _gap);
        var _is_sel  = (_s == slot_selected);
        var _preview = slot_previews[_s];
        var _occupied = (_preview != undefined);
        var _locked  = (slot_mode == "load_game" && !_occupied);

        // Card background
        var _bg_col;
        if (_locked)       _bg_col = make_color_rgb(14, 15, 22);
        else if (_is_sel)  _bg_col = make_color_rgb(20, 34, 58);
        else               _bg_col = make_color_rgb(12, 16, 28);
        draw_set_alpha(_locked ? 0.4 : 1.0);
        draw_set_color(_bg_col);
        draw_rectangle(_cx, _card_y, _cx + _card_w, _card_y + _card_h, false);

        // Card border - rarity-glow on selected
        var _border_col;
        if (_locked)        _border_col = make_color_rgb(35, 38, 50);
        else if (_is_sel)   _border_col = make_color_rgb(130, 195, 255);
        else                _border_col = make_color_rgb(50, 60, 85);
        draw_set_color(_border_col);
        draw_rectangle(_cx, _card_y, _cx + _card_w, _card_y + _card_h, true);

        draw_set_alpha(_locked ? 0.3 : 1.0);

        // Slot number header bar
        draw_set_color(_is_sel ? make_color_rgb(35, 65, 110) : make_color_rgb(22, 28, 44));
        draw_rectangle(_cx, _card_y, _cx + _card_w, _card_y + 48, false);
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(_locked ? make_color_rgb(55, 58, 70) : c_white);
        draw_text(_cx + _card_w / 2, _card_y + 12, "SAVE SLOT " + string(_s + 1));

        // Slot content
        var _mid = _cx + _card_w / 2;
        if (!_occupied) {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(55, 65, 90));
            draw_text(_mid, _card_y + 180, "- Empty -");
        } else {
            // Character name
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(180, 215, 255));
            draw_text(_mid, _card_y + 83, _preview.player_name);
            // Stats
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(140, 155, 180));
            draw_text(_mid, _card_y + 135, "Runs:   " + string(_preview.run_count));
            draw_text(_mid, _card_y + 168, "Gold:   " + string(_preview.gold) + "g");
            draw_text(_mid, _card_y + 201, "Clears: " + string(_preview.dungeon_clears_total));
            draw_text(_mid, _card_y + 234, "Best floor: " + string(_preview.best_floor));
        }

        // Overwrite warning on selected occupied slot in new_game mode
        if (_is_sel && slot_mode == "new_game" && _occupied) {
            draw_set_font(fnt_ui_small);
            var _warn_col = slot_confirm ? make_color_rgb(255, 100, 80) : make_color_rgb(220, 170, 50);
            draw_set_color(_warn_col);
            draw_text(_mid, _card_y + _card_h - 54,
                slot_confirm ? "Press Enter again to OVERWRITE" : "! Occupied - confirm to overwrite");
        }

        // "No save" hint on empty slot in load_game mode
        if (_is_sel && slot_mode == "load_game" && !_occupied) {
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(150, 80, 80));
            draw_text(_mid, _card_y + _card_h - 54, "No save data");
        }

        // Ornate gothic frame around each save plaque. Band 15 keeps the corner
        // ornaments inside the 45px inter-card gaps and clear of the title (y120/177
        // above) and the selection caret (y below). Locked cards dim to match.
        draw_set_font(-1);
        ui_draw_gothic_frame(_cx, _card_y, _cx + _card_w, _card_y + _card_h, 15, _locked ? 0.35 : 1.0);

        draw_set_alpha(1.0);
    }

    // Arrow caret under selected card
    var _arrow_x = _start_x + slot_selected * (_card_w + _gap) + _card_w / 2;
    if ((current_time mod 700) < 400) {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(130, 195, 255));
        draw_text(_arrow_x, _card_y + _card_h + 21, "^");
    }

    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// Audio settings overlay - drawn on top of everything when open
draw_set_font(-1);
if (variable_global_exists("settings_open") && global.settings_open) {
    ui_draw_settings_overlay();
}

// Reset draw state
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_alpha(1.0);
draw_set_color(c_white);
draw_set_font(-1);
