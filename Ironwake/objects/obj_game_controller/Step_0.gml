// Pinch-zoom gesture (SYSTEMS_PINCH_ZOOM.md): tracked BEFORE the one-finger
// classifier so a two-finger pinch mutes taps/drags for the whole frame.
touch_pinch_update();

// Touch gesture classifier (8d): updated once per frame, before anything reads
// taps/drags/long-presses. No-op on non-touch devices.
touch_gesture_update();
find_banner_tick();   // FIND banner queue (pets / eggs / banshee bottles) - runs in every room

// IRONMAN resume (SYSTEMS_RUN_RESUME.md): Android is about to suspend the game
// (phone call, home button - the OS may kill us without another frame) - flush
// the run checkpoint NOW. os_is_paused() is best-effort on some devices, so the
// room-boundary + watcher writes remain the primary safety net; this only
// tightens the loss window. No-op outside a run or once combat is decided.
if (os_is_paused()) run_checkpoint_write_now();

// Latch whether any gc-managed overlay/modal is open at the START of this Step,
// BEFORE the ESC-close handlers below clear their flags. The hub AND floor pause-
// menu triggers check this so the same Esc press that closes an overlay (inventory,
// stash, shops, trainers, item picker, comparison) can't also pop the pause menu.
// (Combat manages its own popups with early exits, so it doesn't need it.)
global.ui_overlay_latch = ui_input_blocked()
    || (variable_global_exists("item_picker") && global.item_picker.open)
    || (variable_global_exists("reagent_picker") && global.reagent_picker != undefined)
    || comparison_open;

// FORGE-RESULT REVEAL (07-31): modal close - one confirm/cancel press takes the
// item. The keys are CLEARED so the craft screen underneath never sees the same
// press (its input block also stands down on forge_result_up() as belt+braces).
if (variable_global_exists("forge_result") && global.forge_result != undefined) {
    var _fr_close = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)
                 || keyboard_check_pressed(vk_escape)
                 || (gamepad_is_connected(0) && (gamepad_button_check_pressed(0, gp_face1)
                                              || gamepad_button_check_pressed(0, gp_face2)));
    if (_fr_close) {
        global.forge_result = undefined;
        audio_play_sound(snd_page, 1, false);
    }
    keyboard_clear(vk_enter);
    keyboard_clear(vk_space);
    keyboard_clear(vk_escape);
}

// CURSED REBIRTH ritual timer (07-31): ~3.5s of dark ceremony, skippable with
// any confirm; the forge-result reveal fires when it completes. Keys cleared so
// the skip press can't leak into the Sable screen (whose block also stands down).
if (cursed_ritual_t >= 0) {
    cursed_ritual_t++;
    var _crit_skip = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)
                  || keyboard_check_pressed(vk_escape)
                  || (gamepad_is_connected(0) && gamepad_button_check_pressed(0, gp_face1));
    if (_crit_skip) cursed_ritual_t = max(cursed_ritual_t, 210);
    keyboard_clear(vk_enter);
    keyboard_clear(vk_space);
    keyboard_clear(vk_escape);
    if (cursed_ritual_t >= 210) {
        forge_result_open("CURSED REBIRTH", "The dark gives it back... changed.",
            cursed_ritual_item, cursed_ritual_prev, [], make_color_rgb(220, 90, 100));
        audio_play_sound(snd_confirm_major, 1, false);
        cursed_ritual_t    = -1;
        cursed_ritual_item = undefined;
        cursed_ritual_prev = undefined;
    }
}

// STATS-PAGE GUIDED TOUR (07-31): arms on the first Stats-tab open; while it
// runs, Enter/Space/N = next step, Esc = skip out - all CLEARED so the menu's
// own handlers (Esc closes the menu) never see the press. Steps are drawn by
// ui_draw_stats_tour at the end of the Stats tab.
if (menu_open && menu_tab == 0) {
    if (stats_tour_step < 0 && !tutorial_seen_has("stats_tour")
        && variable_global_exists("chosen_class")   // page draws stats only with a character
        && (!variable_global_exists("tutorial_enabled") || global.tutorial_enabled)) {
        stats_tour_step = 0;
    }
    if (stats_tour_step >= 0) {
        var _st_next = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)
                    || keyboard_check_pressed(ord("N"))
                    || (gamepad_is_connected(0) && gamepad_button_check_pressed(0, gp_face1));
        var _st_skip = keyboard_check_pressed(vk_escape)
                    || (gamepad_is_connected(0) && gamepad_button_check_pressed(0, gp_face2));
        if (_st_skip) {
            tutorial_mark_seen("stats_tour");
            stats_tour_step = -1;
            audio_play_sound(snd_page, 1, false);
        } else if (_st_next) {
            stats_tour_step++;
            audio_play_sound(snd_page, 1, false);
            if (stats_tour_step > 5) {   // past the last step = done
                tutorial_mark_seen("stats_tour");
                stats_tour_step = -1;
            }
        }
        keyboard_clear(vk_enter);
        keyboard_clear(vk_space);
        keyboard_clear(vk_escape);
        keyboard_clear(ord("N"));
    }
} else if (stats_tour_step >= 0 && !menu_open) {
    stats_tour_step = -1;   // menu closed mid-tour: not marked seen, re-offers next open
}

// TALENT-WEB GUIDED TOUR (M 08-04): same shape as the stats tour - arms on the
// first web open, Enter/Space/N = next, Esc = skip; keys cleared so the web's
// own handlers never see the press (the hub web Step also stands down while
// talent_tour_step >= 0). Steps drawn by ui_draw_talent_tour over the web view.
if (web_view_open) {
    if (talent_tour_step < 0 && !tutorial_seen_has("talent_tour")
        && (!variable_global_exists("tutorial_enabled") || global.tutorial_enabled)) {
        talent_tour_step = 0;
    }
    if (talent_tour_step >= 0) {
        var _tt_next = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)
                    || keyboard_check_pressed(ord("N"))
                    || (gamepad_is_connected(0) && gamepad_button_check_pressed(0, gp_face1));
        var _tt_skip = keyboard_check_pressed(vk_escape)
                    || (gamepad_is_connected(0) && gamepad_button_check_pressed(0, gp_face2));
        if (_tt_skip) {
            tutorial_mark_seen("talent_tour");
            talent_tour_step = -1;
            audio_play_sound(snd_page, 1, false);
        } else if (_tt_next) {
            talent_tour_step++;
            audio_play_sound(snd_page, 1, false);
            if (talent_tour_step > 4) {   // past the last step = done
                tutorial_mark_seen("talent_tour");
                talent_tour_step = -1;
            }
        }
        keyboard_clear(vk_enter);
        keyboard_clear(vk_space);
        keyboard_clear(vk_escape);
        keyboard_clear(ord("N"));
    }
} else if (talent_tour_step >= 0) {
    talent_tour_step = -1;   // web closed mid-tour: not marked seen, re-offers next open
}

// NPC STATION GUIDED TOURS (M-locked 08-15: framework + all seven keepers).
// Same shape as the stats/talent tours - arms once per NPC on the FIRST open of
// that keeper's screen (tutorial_seen "tour_<npc>"), Enter/Space/N = next,
// Esc = skip, keys cleared. The NPC input blocks below all stand down while
// npc_tour_step >= 0, so nothing can be bought or toggled under the dim.
// Hub-only (the mid-run ghost/floor shops never tour); a coach-mark tip
// outranks arming (one teacher at a time). Steps drawn by ui_draw_npc_tour
// at the very end of the hub's Draw_64.
var _nt_id = "";
if (instance_exists(obj_hub_controller) && !menu_open) {
    if (shop_open == 1)      _nt_id = "dorn";
    else if (shop_open == 0) _nt_id = "petra";
    else if (variable_instance_exists(id, "trainer_open") && trainer_open) _nt_id = "vex";
    else if (variable_instance_exists(id, "maren_open")   && maren_open)   _nt_id = "maren";
    else if (variable_instance_exists(id, "sable_open")   && sable_open)   _nt_id = "sable";
    else if (variable_instance_exists(id, "vael_open")    && vael_open)    _nt_id = "vael";
    else if (variable_instance_exists(id, "bairc_open")   && bairc_open
        && !bairc_intro_open
        && !(variable_instance_exists(id, "garden_open") && garden_open)) _nt_id = "bairc";
}
if (_nt_id != "") {
    if (npc_tour_step < 0 && !tutorial_seen_has("tour_" + _nt_id)
        && !tutorial_is_active()
        && (!variable_global_exists("tutorial_enabled") || global.tutorial_enabled)) {
        npc_tour_step = 0;
        npc_tour_npc  = _nt_id;
    }
    if (npc_tour_step >= 0 && npc_tour_npc == _nt_id) {
        var _nt_steps = npc_tour_steps(npc_tour_npc);
        var _nt_total = array_length(_nt_steps);
        // Steps that name a `tab` switch the screen to it while they show (Maren's
        // SPIRITS step) - so the tour points at what is actually on screen.
        if (npc_tour_step < _nt_total && variable_struct_exists(_nt_steps[npc_tour_step], "tab")) {
            if (npc_tour_npc == "maren" && variable_instance_exists(id, "maren_tab")) maren_tab = _nt_steps[npc_tour_step].tab;
        }
        var _nt_next = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)
                    || keyboard_check_pressed(ord("N"))
                    || (gamepad_is_connected(0) && gamepad_button_check_pressed(0, gp_face1));
        var _nt_skip = keyboard_check_pressed(vk_escape)
                    || (gamepad_is_connected(0) && gamepad_button_check_pressed(0, gp_face2));
        if (_nt_skip) {
            tutorial_mark_seen("tour_" + npc_tour_npc);
            npc_tour_step = -1;
            audio_play_sound(snd_page, 1, false);
        } else if (_nt_next) {
            npc_tour_step++;
            audio_play_sound(snd_page, 1, false);
            if (npc_tour_step >= _nt_total) {   // past the last step = done
                tutorial_mark_seen("tour_" + npc_tour_npc);
                npc_tour_step = -1;
            }
        }
        keyboard_clear(vk_enter);
        keyboard_clear(vk_space);
        keyboard_clear(vk_escape);
        keyboard_clear(ord("N"));
    }
} else if (npc_tour_step >= 0) {
    npc_tour_step = -1;   // screen closed mid-tour: not marked seen, re-offers next open
}

// =============================================================================
// BAIRC'S GARDEN (M design-locked 08-15): full-screen wandering-camera scene.
// bairc_open STAYS TRUE underneath (so every existing modal gate holds); the
// bairc station block below stands down on garden_open. Verbs: A/D or arrows
// or drag = pan; [1] pond crumb, [2] cairn stone, [3] forage, [E] pet,
// [B] ornament shop, Esc leaves (or backs out of shop/placement). Every verb
// also has a tap path via chips drawn in ui_draw_garden_scene (touch rule).
// =============================================================================
if (!variable_instance_exists(id, "garden_open")) garden_open = false;
if (garden_open && bairc_open) {
    garden_ensure();
    if (garden_fade > 0) garden_fade--;
    // First visit: the garden coach-mark (pan/drag/verbs) - M 08-18. The tip is modal
    // (any confirm dismisses it), so the scene's verbs stand down while it is up.
    tutorial_try_show("garden_scene");
    // NOTE (08-18 SOFTLOCK fix, M: "press any key... nothing happens"): this block runs
    // BEFORE the shared coach-mark dismiss handler further down, so an `exit` here while
    // the tip is up meant the dismiss code never ran. The garden's own verbs stand down
    // via the garden_tut_up flag below; the shared handler dismisses and exits.
    var garden_tut_up = tutorial_is_active();
    if (garden_tut_up) {
        if (garden_notice_t > 0) { garden_notice_t--; if (garden_notice_t == 0) garden_notice = ""; }
        if (variable_instance_exists(id, "garden_wip_t") && garden_wip_t > 0) garden_wip_t--;
    }
    if (!garden_tut_up) {
    if (garden_notice_t > 0) { garden_notice_t--; if (garden_notice_t == 0) garden_notice = ""; }
    if (variable_instance_exists(id, "garden_wip_t") && garden_wip_t > 0) garden_wip_t--;
    // Expire old reaction FX (4s life).
    for (var _gfi = array_length(garden_fx) - 1; _gfi >= 0; _gfi--) {
        if (current_time - garden_fx[_gfi].t0 > 4000) array_delete(garden_fx, _gfi, 1);
    }

    // ---- ORNAMENT SHOP overlay (modal within the garden) ----
    if (garden_shop_open) {
        var _gs_cat = garden_decor_catalog();
        var _gs_n   = array_length(_gs_cat);
        for (var _gsi = 0; _gsi < _gs_n; _gsi++) {
            if (input_inject_take("garden:shoprow" + string(_gsi))) {
                if (garden_shop_cur == _gsi) input_inject("garden:shopgo");   // 2nd tap = pick
                else garden_shop_cur = _gsi;
            }
        }
        if (nav_up())   garden_shop_cur = wrap_index(garden_shop_cur - 1, _gs_n);
        if (nav_down()) garden_shop_cur = wrap_index(garden_shop_cur + 1, _gs_n);
        if (input_confirm() || input_inject_take("garden:shopgo")) {
            var _gs_d = _gs_cat[garden_shop_cur];
            if (garden_decor_placed(_gs_d.id)) {
                garden_notice = "The " + _gs_d.name + " already stands in the garden.";
                garden_notice_t = 150;
            } else if (global.gold < _gs_d.gold
                || (variable_global_exists("rune_dust") ? global.rune_dust : 0) < _gs_d.dust) {
                garden_notice = _gs_d.name + " needs " + string(_gs_d.gold) + "g + " + string(_gs_d.dust) + " dust.";
                garden_notice_t = 150;
                audio_play_sound(snd_ui_error, 1, false);
            } else {
                garden_place_pick = _gs_d.id;   // charged at placement
                garden_shop_open  = false;
                garden_notice = "Choose a plot for the " + _gs_d.name + " - tap a glowing ring, or press its number.";
                garden_notice_t = 300;
                audio_play_sound(snd_page, 1, false);
            }
        }
        if (input_cancel() || input_back()) {
            garden_shop_open = false;
            audio_play_sound(snd_page, 1, false);
        }
    } else {
        // ---- PLACEMENT mode: pick a plot for garden_place_pick ----
        if (garden_place_pick != "") {
            var _gp_anchors = garden_decor_anchors();
            for (var _gpi = 0; _gpi < array_length(_gp_anchors); _gpi++) {
                if (keyboard_check_pressed(ord(string(_gpi + 1)))
                    || input_inject_take("garden:plot" + string(_gpi))) {
                    var _gp_res = garden_decor_place(_gpi, garden_place_pick);
                    if (_gp_res == "") {
                        var _gp_d = garden_decor_get(garden_place_pick);
                        garden_notice = "The " + _gp_d.name + " settles into the earth.";
                        garden_notice_t = 200;
                        garden_place_pick = "";
                        audio_play_sound(snd_confirm_major, 1, false);
                    } else {
                        garden_notice = _gp_res; garden_notice_t = 150;
                        audio_play_sound(snd_ui_error, 1, false);
                    }
                    break;
                }
            }
            if (input_cancel() || input_back()) {
                garden_place_pick = "";
                garden_notice = "Placement set aside.";
                garden_notice_t = 100;
            }
        } else if (input_cancel() || input_back() || input_inject_take("garden:leave")) {
            // ---- Leave the garden -> back to Bairc's station ----
            garden_open = false;
            music_garden_stop();
            audio_play_sound(music_hub_snd(), 1, true);
            audio_apply_volumes();
            audio_play_sound(snd_page, 1, false);
        }

        // ---- Activities (hotkeys; the draw chips inject these same tags) ----
        if (garden_place_pick == "") {
            if (keyboard_check_pressed(ord("1")) || input_inject_take("garden:crumb")) {
                garden_crumb_t = current_time;
                garden_crumb_x = 1250 + irandom_range(-60, 60);
                array_push(garden_fx, { kind: "ripple", x: garden_crumb_x, y: 900, t0: current_time });
                garden_notice = "The water dimples. Shapes rise to meet it.";
                garden_notice_t = 120;
            }
            if (keyboard_check_pressed(ord("2")) || input_inject_take("garden:stone")) {
                var _gc_msg = garden_cairn_place();
                if (_gc_msg != "") {
                    garden_notice = _gc_msg; garden_notice_t = 200;
                    array_push(garden_fx, { kind: "stone", x: 2650, y: 870, t0: current_time });
                    audio_play_sound(snd_page, 1, false);
                }
            }
            if (keyboard_check_pressed(ord("3")) || input_inject_take("garden:forage")) {
                // Nearest untaken sparkle to the screen centre.
                var _gf_spots = garden_forage_spots();
                var _gf_best = -1, _gf_bd = 999999;
                for (var _gfj = 0; _gfj < array_length(_gf_spots); _gfj++) {
                    var _gfs = _gf_spots[_gfj];
                    if (_gfs.taken) continue;
                    var _gfd = abs(_gfs.x - (garden_cam_x + 960));
                    if (_gfd < _gf_bd) { _gf_bd = _gfd; _gf_best = _gfs.idx; }
                }
                if (_gf_best >= 0 && _gf_bd < 1100) {
                    garden_notice = garden_forage_take(_gf_best);
                    garden_notice_t = 220;
                    audio_play_sound(snd_confirm_major, 1, false);
                } else if (_gf_best >= 0) {
                    garden_notice = "Nothing glitters here - wander further.";
                    garden_notice_t = 120;
                } else {
                    garden_notice = "The grounds are picked clean today. A run will turn up more.";
                    garden_notice_t = 180;
                }
            }
            // Tap on a specific sparkle (draw injects the exact index).
            for (var _gfk = 0; _gfk < 3; _gfk++) {
                if (input_inject_take("garden:forage" + string(_gfk))) {
                    var _gfm = garden_forage_take(_gfk);
                    if (_gfm != "") {
                        garden_notice = _gfm; garden_notice_t = 220;
                        audio_play_sound(snd_confirm_major, 1, false);
                    }
                }
            }
            // Petting: [E] pets the resident nearest the screen centre; a tap
            // on a resident injects its exact index.
            var _gpe_pick = -1;
            if (keyboard_check_pressed(ord("E"))) _gpe_pick = -2;   // nearest
            var _gpe_dn = array_length(bairc_donated());
            for (var _gpl = 0; _gpl < min(_gpe_dn, 16); _gpl++) {
                if (input_inject_take("garden:pet" + string(_gpl))) _gpe_pick = _gpl;
            }
            if (_gpe_pick != -1 && _gpe_dn > 0) {
                var _gpe_i = _gpe_pick;
                if (_gpe_i == -2) {
                    // Nearest by the same deterministic home-x the draw uses.
                    var _gpe_bd = 999999; _gpe_i = 0;
                    for (var _gpn = 0; _gpn < min(_gpe_dn, 16); _gpn++) {
                        var _gph = frac(sin((_gpn + 1) * 91.17) * 47453.25);
                        var _gpx = 260 + _gph * (garden_world_w() - 620);
                        var _gpd = abs(_gpx - (garden_cam_x + 960));
                        if (_gpd < _gpe_bd) { _gpe_bd = _gpd; _gpe_i = _gpn; }
                    }
                }
                var _gpe_d = bairc_donated()[_gpe_i];
                var _gpe_h = frac(sin((_gpe_i + 1) * 91.17) * 47453.25);
                array_push(garden_fx, { kind: "hearts",
                    x: 260 + _gpe_h * (garden_world_w() - 620),
                    y: (_gpe_i mod 2 == 0) ? 952 : 800, t0: current_time });
                garden_notice = garden_pet_line(_gpe_d.name);
                garden_notice_t = 200;
                audio_play_sound(snd_page, 1, false);
            }
            // Shop open.
            if (input_hotkey("B") || input_inject_take("garden:shop")) {
                garden_shop_open = true;
                garden_shop_cur  = 0;
                audio_play_sound(snd_page, 1, false);
            }
            // [M] / the music chip: cycle Default + the garden's track pool
            // (per-save selection, banshee-selector idiom - live-swaps here).
            if (input_hotkey("M") || input_inject_take("garden:music")) {
                if (music_selection_cycle("garden", 1)) {
                    var _gm_t = music_selected_track("garden");
                    garden_notice = "Now playing: " + ((_gm_t == undefined) ? "Stillwater" : _gm_t.name);
                    garden_notice_t = 150;
                    if (variable_global_exists("save_slot") && global.save_slot >= 0) save_game();
                }
            }
        }

        // ---- Camera pan: held keys + drag (mouse/touch) ----
        var _gcam_v = 0;
        if (keyboard_check(ord("D")) || keyboard_check(vk_right)) _gcam_v += 16;
        if (keyboard_check(ord("A")) || keyboard_check(vk_left))  _gcam_v -= 16;
        // Gamepad: left stick / d-pad pans too (input parity, 08-18).
        if (gamepad_is_connected(0)) {
            var _gax = gamepad_axis_value(0, gp_axislh);
            if (abs(_gax) > 0.25) _gcam_v += 16 * _gax;
            if (gamepad_button_check(0, gp_padr)) _gcam_v += 16;
            if (gamepad_button_check(0, gp_padl)) _gcam_v -= 16;
        }
        garden_cam_x += _gcam_v;
        if (mouse_check_button(mb_left)) {
            var _gdm = device_mouse_x_to_gui(0);
            if (garden_drag_mx >= 0) garden_cam_x -= (_gdm - garden_drag_mx);
            garden_drag_mx = _gdm;
        } else {
            garden_drag_mx = -1;
        }
        garden_cam_x = clamp(garden_cam_x, 0, garden_world_w() - 1920);
    }
    }   // !garden_tut_up (08-18 softlock fix)
}

// Global fullscreen toggle (F11) - works in every room, persists in settings.ini.
if (keyboard_check_pressed(vk_f11)) {
    video_toggle_fullscreen();
}

// Wide-aspect geometry (8b): re-fit the GUI band whenever the window shape
// changes - F11 fullscreen, the F7 aspect lever below, HTML5 frame resize.
if (window_get_width() != geom_last_w || window_get_height() != geom_last_h) {
    geom_last_w = window_get_width();
    geom_last_h = window_get_height();
    gui_geometry_apply();
}

// =============================================================================
// TEST LEVER (08-21, M) - F12 in the HUB grants one IDENTIFIED egg of EVERY EGG
// TYPE (the 10 in pet_egg_type_catalog, catalog order) so the re-authored egg
// art + each type's bespoke hatch animation can be viewed on one save. Species
// inside are spread over shipped expansion creatures so the hatchlings differ.
// Replaces the 08-01 expansion-species lever. Does NOT touch the boss-egg
// once-per-save ledger. ADDITIVE ONLY - never clears the roster.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only).
// =============================================================================
if (GM_build_type == "run" && room == rm_hub && keyboard_check_pressed(vk_f12)) {
    var _dev_species = ["duskraven", "pale_widow", "shellback", "thorn_boar",
                        "glimmer_slime", "sporeling", "voidkit", "ironshell_beetle",
                        "lockjaw_turtle", "rimefox"];
    var _dev_eggs = pet_egg_type_catalog();
    for (var _dvi = 0; _dvi < array_length(_dev_eggs); _dvi++) {
        var _dp = pet_make(_dev_species[_dvi mod array_length(_dev_species)], "egg_event", -1, PET_STAGE_BABY, true);
        _dp.egg_type   = _dev_eggs[_dvi].id;   // one of each egg design, catalog order
        _dp.identified = true;                 // skip Bairc's identify fee - straight to hatchable
        pet_add(_dp);
    }
    if (instance_exists(obj_hub_controller)) {
        instance_find(obj_hub_controller, 0).notification = "DEV: one egg of each of the 10 egg types delivered to Bairc.";
    }
    audio_play_sound(snd_confirm_major, 1, false);
}

// =============================================================================
// TEST LEVER (08-21, M) - F3 in the HUB grants the PROMO SHOWCASE roster for
// the pets video: two full growth lines (Wyrmling + Voidkit - identified egg,
// young adult, adult with capstone, Awakened with capstone + splash so no
// PENDING badges dirty the shot), a young-adult Hoarfrost Drake scion (egg_boss
// source -> signature kin-of card + Long Winter move), and a corrupted
// young-adult Pale Widow (pushing state -> violet flicker FX + CORRUPTING tag).
// ADDITIVE ONLY - never clears the roster, so a real save stays safe; record on
// a fresh slot for a clean lineup.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only).
// =============================================================================
if (GM_build_type == "run" && room == rm_hub && keyboard_check_pressed(vk_f3)) {
    var _show_lines = ["wyrmling", "voidkit"];
    for (var _sli = 0; _sli < array_length(_show_lines); _sli++) {
        var _ssp = _show_lines[_sli];
        var _se = pet_make(_ssp, "egg_event", -1, PET_STAGE_BABY, true);
        _se.identified = true;   // skip Bairc's identify fee - straight to hatchable
        pet_add(_se);
        pet_add(pet_make(_ssp, "found", -1, PET_STAGE_YOUNGADULT, false));
        var _sa = pet_make(_ssp, "found", -1, PET_STAGE_ADULT, false);
        pet_assign_capstone(_sa);
        pet_add(_sa);
        var _sw = pet_make(_ssp, "found", -1, PET_STAGE_AWAKENED, false);
        pet_assign_capstone(_sw);
        pet_assign_splash(_sw);
        pet_add(_sw);
    }
    pet_add(pet_make("hoarfrost_drake", "egg_boss", -1, PET_STAGE_YOUNGADULT, false));
    var _scor = pet_make("pale_widow", "found", -1, PET_STAGE_YOUNGADULT, false);
    _scor.corrupted        = true;
    _scor.corruption_state = "pushing";
    _scor.corruption_runs  = 1;   // detail card reads "Corrupting 1/3"
    pet_add(_scor);
    if (instance_exists(obj_hub_controller)) {
        instance_find(obj_hub_controller, 0).notification = "DEV: promo showcase roster (10 pets) delivered to Bairc.";
    }
    audio_play_sound(snd_confirm_major, 1, false);
}

// =============================================================================
// TEST LEVER (8b) - F7 cycles the WINDOWED shape 16:9 -> 19.5:9 (S25) -> 20:9 so
// the wide-aspect gutters can be F5-verified on a PC monitor without a device
// build. Drops out of fullscreen first; 810-high shapes fit a 1080p display.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only;
// packaged .exe reports "exe"). Keeps the lever for dev without shipping it -
// replaces the old "REMOVE BEFORE RELEASE" manual step (07-20).
// =============================================================================
if (GM_build_type == "run" && os_type == os_windows && keyboard_check_pressed(vk_f7)) {
    if (!variable_global_exists("debug_aspect_idx")) global.debug_aspect_idx = 0;
    global.debug_aspect_idx = (global.debug_aspect_idx + 1) mod 3;
    if (global.fullscreen) video_toggle_fullscreen();
    var _shapes = [[1440, 810], [1755, 810], [1800, 810]];   // 16:9, 19.5:9, 20:9
    var _shp = _shapes[global.debug_aspect_idx];
    window_set_size(_shp[0], _shp[1]);
    window_center();
    show_debug_message("[TEST] aspect lever -> " + string(_shp[0]) + "x" + string(_shp[1]));
}

// =============================================================================
// TEST LEVER (07-16) - F8 toggles UNLOCK-EVERYTHING for playtesting: abilities,
// traits, music tracks and Maren flagship recipes all read as unlocked while ON.
// Deliberately a CHECK BYPASS, not a data grant - global.debug_unlock_all is
// never written to the save, so the real slot's progression is untouched and a
// relaunch always starts OFF. Audio cue: rising = ON, low = OFF.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only;
// packaged .exe reports "exe"), so a player - or a Valve build reviewer - can't
// press F8 to unlock the whole progression system. Keeps the lever for dev
// without shipping it; replaces the old "REMOVE BEFORE RELEASE" step (07-20).
// =============================================================================
if (GM_build_type == "run" && keyboard_check_pressed(vk_f8)) {
    if (!variable_global_exists("debug_unlock_all")) global.debug_unlock_all = false;
    global.debug_unlock_all = !global.debug_unlock_all;
    var _dua_si = audio_play_sound(snd_loot_reveal, 1, false);
    audio_sound_pitch(_dua_si, global.debug_unlock_all ? 1.4 : 0.7);
    show_debug_message("[TEST] debug_unlock_all = " + string(global.debug_unlock_all));
}

// =============================================================================
// TEST LEVER (07-30) - F6 cycles the pinch-zoom transform x1.0 -> x1.5 -> x2.5
// (view centered) so zoomed taps / fixed on-screen controls can be F5-verified
// on a PC monitor, where a two-finger pinch can't be simulated. Pairs with F9
// forced-touch for the full mobile approximation. Panning can't be simulated -
// device-verify that half on the S25.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only).
// =============================================================================
if (GM_build_type == "run" && os_type == os_windows && keyboard_check_pressed(vk_f6)) {
    zoom_state_init();
    var _zl = global.zoom;
    var _zt = 1.0;
    if (_zl.z < 1.2)      _zt = 1.5;
    else if (_zl.z < 2.0) _zt = 2.5;
    _zl.z  = _zt;
    _zl.vx = _zl.vis_w * (1 - 1 / _zt) / 2;   // centre the zoomed view
    _zl.vy = GUI_H     * (1 - 1 / _zt) / 2;
    zoom_pan_clamp();
    zoom_apply();
    show_debug_message("[TEST] zoom lever -> x" + string(_zt));
}

// =============================================================================
// TEST LEVER (07-24) - F9 toggles FORCED TOUCH MODE on Windows: input_device()
// reads 2, so the full touch UI (chips, on-screen d-pad, tap targets, long-press,
// swipes) runs and is driven by the mouse - no phone needed. Pairs with F7's
// phone-aspect lever for a desktop approximation of the S25. Never persisted;
// relaunch always starts OFF. Audio cue: rising = ON, low = OFF.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only).
// =============================================================================
if (GM_build_type == "run" && os_type == os_windows && keyboard_check_pressed(vk_f9)) {
    if (!variable_global_exists("debug_force_touch")) global.debug_force_touch = false;
    global.debug_force_touch = !global.debug_force_touch;
    var _dft_si = audio_play_sound(snd_ui_toggle_on, 1, false);
    audio_sound_pitch(_dft_si, global.debug_force_touch ? 1.4 : 0.7);
    show_debug_message("[TEST] debug_force_touch = " + string(global.debug_force_touch));
}

// =============================================================================
// TEST LEVER (07-30) - F10 arms the Ashen Duelist: the NEXT event room entered
// becomes the duel (floor 2+ still required; the lever also bypasses the
// once-per-run gate so win AND loss can be tested in one run). Players never
// see this - the hidden 8% roll is untouched. Rising cue = armed, low = off.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only).
// =============================================================================
if (GM_build_type == "run" && os_type == os_windows && keyboard_check_pressed(vk_f10)) {
    if (!variable_global_exists("debug_force_duel")) global.debug_force_duel = false;
    global.debug_force_duel = !global.debug_force_duel;
    var _dfd_si = audio_play_sound(snd_ui_toggle_on, 1, false);
    audio_sound_pitch(_dfd_si, global.debug_force_duel ? 1.4 : 0.7);
    show_debug_message("[TEST] debug_force_duel = " + string(global.debug_force_duel));
}

// =============================================================================
// TEST LEVER (08-04, M) - F4 grants 5000 gold for testing (autosave means
// there's no quit-without-saving cheat roll; this is the honest dev tap).
// F1-F4 carry no gameplay bindings anywhere, so it can't double-fire.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only).
// =============================================================================
// =============================================================================
// TEST LEVER (08-26, M) - F2 grants a CRAFTING DEMO KIT for the crafting video:
// +5 of each dungeon reagent, +250 rune dust and +2 Reforge Ingots per tier, so
// Dorn's smelt/craft/rework loop can be demoed without farming. ADDITIVE ONLY.
// COMPILED OUT OF RELEASE BUILDS: gated on GM_build_type == "run" (IDE/F5 only).
// =============================================================================
if (GM_build_type == "run" && keyboard_check_pressed(vk_f2)) {
    reagents_ensure();
    var _dk_cat = reagent_catalog();
    for (var _dki = 0; _dki < array_length(_dk_cat); _dki++) reagent_add(_dk_cat[_dki].id, 5);
    if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
    global.rune_dust += 250;
    reforge_ingots_ensure();
    for (var _dkt = 0; _dkt < 5; _dkt++) global.reforge_ingots[_dkt] += 2;
    var _dk_si = audio_play_sound(snd_ui_toggle_on, 1, false);
    audio_sound_pitch(_dk_si, 1.4);
    show_debug_message("[TEST] crafting demo kit (F2): +5 each reagent, +250 dust, +2 each ingot tier");
    if (instance_exists(obj_hub_controller)) {
        instance_find(obj_hub_controller, 0).notification = "DEV: crafting kit - +5 each reagent, +250 dust, +2 each ingot tier.";
    }
}

if (GM_build_type == "run" && keyboard_check_pressed(vk_f4)) {
    global.gold += 5000;
    var _dg_si = audio_play_sound(snd_ui_toggle_on, 1, false);
    audio_sound_pitch(_dg_si, 1.4);
    show_debug_message("[TEST] +5000 gold (F4) -> " + string(global.gold));
}

// Hub station flavor loops (SOUND_ATMOSPHERE_SPEC.md section 3): keep each open
// NPC screen's quiet bed in lock-step with its *_open flag. Runs above every
// modal early-exit below so a loop can never stick on while one is up.
hub_station_ambience_update();

// Android (8c): pop the OS on-screen keyboard whenever a typed-text modal is
// capturing keyboard_string (hero naming at char create, pet naming at Bairc)
// and dismiss it when the modal closes. One pump - text_entry_active() already
// tracks every naming modal, and gc runs in all the rooms that have one.
if (os_type == os_android) {
    var _osk_want = text_entry_active();
    if (!variable_global_exists("osk_shown")) global.osk_shown = false;
    if (_osk_want && !global.osk_shown) {
        keyboard_virtual_show(kbv_type_default, kbv_returnkey_default, kbv_autocapitalize_sentences, false);
        global.osk_shown = true;
    } else if (!_osk_want && global.osk_shown) {
        keyboard_virtual_hide();
        global.osk_shown = false;
    }
}

// HTML5 / itch: keep the canvas matched to the live browser/itch frame so it always
// fills it. The frame resizes on fullscreen-launch and window-resize, and GM's HTML5
// scaling won't upscale a fixed canvas to a bigger frame, so we re-size to the browser
// dimensions whenever they change. The fixed 1920x1080 GUI layer stretches to fill it.
// (Desktop is sized once in video_apply; this whole block is web-only.)
if (os_browser != browser_not_a_browser) {
    var _bw = browser_width;
    var _bh = browser_height;
    if (_bw > 0 && _bh > 0 && (window_get_width() != _bw || window_get_height() != _bh)) {
        window_set_size(_bw, _bh);
    }
}

// STATION RANK from INSIDE the NPC screen (M 08-17: pad has no free hub button):
// [U] / pad L3 arms the same checkout popup the carousel uses; the hub Step's
// modal block (0a3) resolves it, so every NPC block below stands down meanwhile.
// Sits AFTER the always-run preamble (F11 / aspect refit / ambience / OSK) so the
// popup's early-exit can't stall those, and never fires while a name is being typed.
if (_nt_id != "" && npc_tour_step < 0 && !tutorial_is_active() && !text_entry_active()) {
    if (hub_checkout_up()) exit;   // popup owns input until CONFIRM / CANCEL
    if (input_hotkey("U")) {
        var _st_err = npc_station_arm(_nt_id);
        if (_st_err != "" && instance_exists(obj_hub_controller)) {
            var _st_hub = instance_find(obj_hub_controller, 0);
            _st_hub.bond_dialog_open  = true;  _st_hub.bond_dialog_npc = _nt_id;
            _st_hub.bond_dialog_hearts = [];
            _st_hub.bond_dialog_title = "Station rank";
            _st_hub.bond_dialog_body  = "No rank to buy here right now - " + _st_err + ".";
        }
        exit;
    }
}

// --- Full-screen hatch cutscene ---
// While an egg is hatching it owns every input; the cutscene advances itself and
// applies pet_hatch at the reveal. Drawn over the Bairc screen by hatch_cutscene_draw().
if (hatch_active) {
    hatch_cutscene_step();
    exit;
}

// --- Onboarding coach-mark (see SYSTEMS_ONBOARDING.md) ---
// A tip is modal: ui_input_blocked() reports true while one is active (freezing every
// room controller), and gc owns the dismiss here. The clear is DEFERRED one frame
// (tutorial_dismiss_pending) so the tip stays "active" through the ENTIRE Step phase
// of the dismiss frame - no controller, whatever its instance order, can act on the
// dismissing keypress. We exit so gc's own input handlers below are frozen too.
if (global.tutorial_dismiss_pending) {
    tutorial_dismiss();                       // mark seen + clear active
    global.tutorial_dismiss_pending = false;
}
if (tutorial_is_active()) {
    if (input_any() || mouse_check_button_pressed(mb_any)) {
        global.tutorial_dismiss_pending = true;   // clear next frame, not now
    }
    exit;
}

// --- Shared item-sacrifice picker (Vex stat/trait trade) ---
// While open the modal captures all input so the underlying screen is frozen.
// We exit the same frame it closes so the confirming keypress can't fall through
// to the screen below. Gated to the Vex purposes so that - since this controller
// is persistent and also alive on the dungeon floor - only obj_floor_controller
// drives the Shrine picker (no double-stepping). See SYSTEMS_ITEM_PICKER.md.
// REAGENT STAGE (M 08-05): the cursed-rebirth multi-select modal runs modally
// over the frozen Sable window, exactly like the picker below - and exits so
// no later handler (gifting, hotkeys) sees its input.
if (variable_global_exists("reagent_picker") && global.reagent_picker != undefined) {
    reagent_picker_step();
    exit;
}
if (variable_global_exists("item_picker") && global.item_picker.open
    && (global.item_picker.purpose == "vex_trait" || global.item_picker.purpose == "vex_stat"
        || global.item_picker.purpose == "vex_potency"
        || global.item_picker.purpose == "alch_rebirth" || global.item_picker.purpose == "gift"
        || global.item_picker.purpose == "chit_reforge" || global.item_picker.purpose == "pb_smelt"
        || global.item_picker.purpose == "maren_sunder" || global.item_picker.purpose == "cursed_rebirth"
        || global.item_picker.purpose == "maren_temper" || global.item_picker.purpose == "maren_awaken"
        || global.item_picker.purpose == "statreq_rebirth")) {
    item_picker_step();
    exit;
}
if (variable_global_exists("item_picker") && global.item_picker.resolved_purpose != "") {
    var _rp = global.item_picker.resolved_purpose;
    if (_rp == "vex_trait" || _rp == "vex_stat" || _rp == "vex_potency") {
        trainer_notification = global.item_picker.result_msg;
        global.item_picker.resolved_purpose = "";   // consume the one-shot
    } else if (_rp == "alch_rebirth" || _rp == "cursed_rebirth" || _rp == "statreq_rebirth") {
        sable_notification = global.item_picker.result_msg;
        global.item_picker.resolved_purpose = "";
        if (_rp == "cursed_rebirth") ui_checkout_vfx(spr_vfx_void, 960, 540);   // the dark answers
    } else if (_rp == "chit_reforge") {
        shop_notification = global.item_picker.result_msg;   // Dorn's window shows the result
        global.item_picker.resolved_purpose = "";
    } else if (_rp == "pb_smelt") {
        // Pattern Book: the picker chose the fodder - now Dorn asks WHAT TO STUDY
        // from it (modal popup on the reforge tab; commit destroys + grants there).
        var _pbc = global.item_picker.context;
        var _pb_it = (is_struct(_pbc) && variable_struct_exists(_pbc, "chosen")) ? _pbc.chosen : undefined;
        global.item_picker.resolved_purpose = "";
        if (_pb_it != undefined) {
            pb_smelt_item = _pb_it;
            pb_smelt_open = true;
            pb_smelt_pick = 0;
        }
    } else if (_rp == "maren_sunder" || _rp == "maren_temper" || _rp == "maren_awaken") {
        maren_notification = global.item_picker.result_msg;
        global.item_picker.resolved_purpose = "";
    }
}

// --- GIFT RESULT POPUP (Phase 4b UX): modal over the giver's window; any confirm
// key dismisses. Owns all input while up.
if (variable_global_exists("gift_popup") && global.gift_popup != undefined) {
    if (input_confirm()
        || input_confirm_alt() || input_cancel()
        || input_hotkey("F") || mouse_check_button_pressed(mb_left)) {
        global.gift_popup = undefined;
    }
    exit;
}

// --- KNUCKLEBONES (expression #1): the tavern dice game, opened with K at the
// board. While open it owns all input. Phases: stake -> play -> over.
if (variable_instance_exists(id, "kb_open") && kb_open) {
    var _g = kb;

    // Rules overlay: H toggles it in any phase; while up it owns all input so the
    // table underneath is frozen (first-time players get it auto-opened).
    if (input_hotkey("H")) { _g.help = !_g.help; exit; }
    if (_g.help) {
        if (input_cancel() || input_confirm()) _g.help = false;
        exit;
    }

    if (_g.phase == "stake") {
        if (input_cancel()) { kb_open = false; exit; }
        var _stakes = [10, 25, 50];
        var _si = 1;
        for (var _s = 0; _s < 3; _s++) if (_stakes[_s] == _g.stake) _si = _s;
        if (nav_left())  { _si = wrap_index(_si - 1, 3); _g.stake = _stakes[_si]; }
        if (nav_right()) { _si = wrap_index(_si + 1, 3); _g.stake = _stakes[_si]; }
        if (input_confirm()) {
            if (global.gold < _g.stake) { _g.msg = "You can't cover the stake."; audio_play_sound(snd_ui_error, 1, false); exit; }
            global.gold -= _g.stake;
            _g.phase = "play";
            _g.msg   = "";
            play_sfx_var("snd_dice_shake", -1);   // dice hit the cup
        }
        exit;
    }

    if (_g.phase == "over") {
        if (input_confirm()
            || input_cancel()) {
            if (kb_tourney != undefined) {
                // HIGH TABLE bracket flow (dice v2): win advances, tie replays the
                // same seat, anything else forfeits the buy-in.
                if (_g.result == "win") {
                    kb_tourney.stage += 1;
                    if (kb_tourney.stage >= 3) {
                        // Champion: the pot plus a curiosity, straight to the pouch.
                        ach_unlock("ACH_HIGH_ROLLER");   // achievement hook (08-05 wiring)
                        global.gold += kb_tourney_pot();
                        var _ht_prize = kb_tourney_prize_roll();
                        tavern_board_note = "HIGH TABLE CHAMPION! You sweep the "
                            + string(kb_tourney_pot()) + "g pot and claim " + _ht_prize + ".";
                        kb_tourney = undefined;
                        kb_open = false;
                        audio_play_sound(snd_kb_payout, 1, false);   // the pot slides over
                        save_game();
                    } else {
                        var _ht_next = kb_tourney.opponents[kb_tourney.stage];
                        kb = kb_new_game(_ht_next);
                        kb.phase = "play";   // buy-in already paid - no per-match stake
                        kb.stake = 0;
                        kb.msg   = "Match " + string(kb_tourney.stage + 1) + " of 3 - "
                            + npc_display_name(_ht_next) + " takes the seat.";
                        play_sfx_var("snd_dice_shake", -1);
                    }
                } else if (_g.result == "tie") {
                    var _ht_same = kb_tourney.opponents[kb_tourney.stage];
                    kb = kb_new_game(_ht_same);
                    kb.phase = "play";
                    kb.stake = 0;
                    kb.msg   = "Dead even - " + npc_display_name(_ht_same) + " racks the dice again.";
                    play_sfx_var("snd_dice_shake", -1);
                } else {
                    tavern_board_note = "The High Table keeps your " + string(kb_tourney_buyin())
                        + "g. The invitation won't come again for a while.";
                    kb_tourney = undefined;
                    kb_open = false;
                }
            } else {
                kb_open = false;
            }
        }
        exit;
    }

    // phase "play"
    if (input_cancel()) {   // concede - the stake stays on the table
        _g.phase  = "over";
        _g.result = "conceded";
        _g.msg    = "You push back from the table. The stake stays.";
        exit;
    }
    if (_g.my_turn) {
        if (nav_left())  _g.cursor = wrap_index(_g.cursor - 1, 3);
        if (nav_right()) _g.cursor = wrap_index(_g.cursor + 1, 3);
        if ((input_confirm())
            && kb_col_count(_g.mine, _g.cursor) < 3) {
            var _foes_before = kb_col_count(_g.foes, _g.cursor);
            kb_place(_g.mine, _g.cursor, _g.die);
            kb_destroy(_g.foes, _g.cursor, _g.die);
            play_sfx_var("snd_dice_place", -1);
            if (kb_col_count(_g.foes, _g.cursor) < _foes_before) audio_play_sound(snd_kb_capture, 1, false);
            if (kb_board_full(_g.mine) || kb_board_full(_g.foes)) {
                _g.phase = "over";
            } else {
                _g.my_turn   = false;
                // Sable's charm-cheat: best of two dice, delivered with a smile.
                _g.foe_die   = irandom(5) + 1;
                if (_g.foe == "sable") _g.foe_die = max(_g.foe_die, irandom(5) + 1);
                _g.foe_timer = 45;
                play_sfx_var("snd_dice_roll", -1);   // the foe's die tumbles out
            }
        }
    } else {
        _g.foe_timer--;
        if (_g.foe_timer <= 0) {
            var _pick = kb_ai_pick(_g);
            if (_pick >= 0) {
                var _mine_before = kb_col_count(_g.mine, _pick);
                kb_place(_g.foes, _pick, _g.foe_die);
                kb_destroy(_g.mine, _pick, _g.foe_die);
                play_sfx_var("snd_dice_place", -1);
                if (kb_col_count(_g.mine, _pick) < _mine_before) audio_play_sound(snd_kb_capture, 1, false);
            }
            if (_pick < 0 || kb_board_full(_g.mine) || kb_board_full(_g.foes)) {
                _g.phase = "over";
            } else {
                _g.my_turn = true;
                _g.die     = irandom(5) + 1;
                play_sfx_var("snd_dice_roll", -1);   // your next die tumbles out
            }
        }
    }
    // Resolve the finished game once (payout + affinity + ledger).
    if (_g.phase == "over" && _g.result == "") {
        var _pm = kb_total(_g.mine), _pf = kb_total(_g.foes);
        if (_pm > _pf) {
            _g.result = "win";
            ach_unlock("ACH_BONES");   // achievement hook (08-05 wiring): a game of knucklebones won
            global.gold += _g.stake * 2;
            affinity_add(_g.foe, 2);   // a good game warms the table
            ledger_add(_g.foe, "milestone", "Beat them at knucklebones for " + string(_g.stake) + "g. They'll want revenge.");
            _g.msg = "You win " + string(_g.stake * 2) + "g! " + npc_display_name(_g.foe) + " eyes the dice suspiciously.";
            audio_play_sound(snd_kb_payout, 1, false);     // coins slide your way
        } else if (_pf > _pm) {
            _g.result = "loss";
            ledger_add(_g.foe, "milestone", "Lost " + string(_g.stake) + "g to them at knucklebones.");
            _g.msg = npc_display_name(_g.foe) + " sweeps up your " + string(_g.stake) + "g without gloating. Much.";
            audio_play_sound(snd_kb_payout_2, 1, false);   // ...and away from you
        } else {
            _g.result = "tie";
            global.gold += _g.stake;
            _g.msg = "Dead even. The stake slides back across the table.";
        }
        if (room == rm_hub || room == rm_character_select) save_game();
    }
    exit;
}

// --- TAVERN REQUESTS BOARD (Phase 4b UX): the quest action surface. W/S rows,
// Enter accepts an available request / turns in a finished one, Esc closes.
if (tavern_board_open) {
    if (input_cancel()) { tavern_board_open = false; audio_play_sound(snd_ui_cancel, 1, false); exit; }
    if (input_hotkey("K")) {
        // Knucklebones: tonight's opponent rotates with the run count.
        var _kb_ids = affinity_npc_ids();
        kb_open = true;
        kb = kb_new_game(_kb_ids[(variable_global_exists("run_count") ? global.run_count : 0) mod array_length(_kb_ids)]);
        // First ever sit-down: open with the rules up (persistent flag, same store
        // as the onboarding coach-marks; H re-opens them whenever).
        if (!tutorial_seen_has("knucklebones")) {
            kb.help = true;
            tutorial_mark_seen("knucklebones");
            save_game();
        }
        exit;
    }
    // HIGH TABLE tournament (dice v2): [T] when the invitation stands. 100g buy-in,
    // three opponents back-to-back, winner takes the pot. Sitting down consumes the
    // invitation - the 5-run clock is already re-armed (kb_tourney_run_end).
    if (input_hotkey("T")) {
        kb_tourney_ensure();
        if (!global.kb_tourney_ready) {
            tavern_board_note = "The High Table isn't set tonight. (every 5th run - "
                + string(global.kb_tourney_countdown) + " to go)";
        } else if (global.gold < kb_tourney_buyin()) {
            tavern_board_note = "The High Table wants a " + string(kb_tourney_buyin()) + "g buy-in.";
            audio_play_sound(snd_ui_error, 1, false);
        } else {
            global.gold -= kb_tourney_buyin();
            global.kb_tourney_ready = false;
            kb_tourney = { stage: 0, opponents: kb_tourney_roll_opponents() };
            kb_open = true;
            kb = kb_new_game(kb_tourney.opponents[0]);
            kb.phase = "play";   // buy-in covers the bracket - no per-match stake
            kb.stake = 0;
            kb.msg   = "Match 1 of 3 - " + npc_display_name(kb_tourney.opponents[0]) + " takes the seat.";
            play_sfx_var("snd_dice_shake", -1);
            save_game();
            exit;
        }
    }
    var _tb = tavern_board_rows();   // active + available only - fulfilled live in the Journal
    var _tbn = array_length(_tb);
    if (_tbn > 0) {
        if (nav_up())   { tavern_board_cursor = wrap_index(tavern_board_cursor - 1, _tbn); tavern_board_note = ""; }
        if (nav_down()) { tavern_board_cursor = wrap_index(tavern_board_cursor + 1, _tbn); tavern_board_note = ""; }
        tavern_board_cursor = clamp(tavern_board_cursor, 0, _tbn - 1);
        // v2: [R] rerolls the highlighted POSTED request for gold (cost doubles per
        // use, resets when the board ages at run end). scr_stats board_reroll owns
        // all the validation; it returns the note either way.
        if (input_hotkey("R")) {
            var _rrid = _tb[tavern_board_cursor];
            tavern_board_note = board_reroll(_rrid);
            save_game();
        }
        if (input_confirm() || input_confirm_alt()) {
            var _tbid = _tb[tavern_board_cursor];
            var _tbd  = quest_def(_tbid);
            journal_clear_quest(_tbid);
            if (quest_is_complete(_tbid)) {
                var _tbres = quest_turn_in(_tbid);
                if (_tbres == "") {
                    tavern_board_note = quest_is_gate(_tbd)
                        ? ("\"" + _tbd.name + "\" fulfilled - your bond with " + npc_display_name(_tbd.npc)
                           + " deepens: " + affinity_tier_name_for(_tbd.gate_tier) + ".")
                        : ("\"" + _tbd.name + "\" fulfilled - " + journal_quest_reward_text(_tbd) + " collected.");
                    audio_play_sound(snd_sting_quest, 1, false);
                    save_game();
                } else tavern_board_note = _tbres;
            } else if (quest_state(_tbid) != undefined && quest_state(_tbid).status == "available") {
                var _tbres2 = quest_start(_tbid);
                if (_tbres2 == "") {
                    tavern_board_note = "Taken: \"" + _tbd.name + "\" - " + _tbd.objective + ".";
                    audio_play_sound(snd_ui_confirm, 1, false);
                    save_game();
                } else tavern_board_note = _tbres2;
            } else if (quest_state(_tbid) != undefined && quest_state(_tbid).status == "active") {
                tavern_board_note = "Still underway - " + _tbd.objective + ".";
            } else {
                tavern_board_note = "Already fulfilled.";
            }
        }
    }
    exit;
}

// --- ITEM CODEX gallery - RETIRED IN PLACE (07-29 M pass): the Journal's codex
// tab is now the full inline codex (bestiary-style), so nothing sets codex_open
// anymore and this block never runs. Kept one F5-verified session for safety;
// delete this block + ui_draw_item_codex together when cleaning up.
if (codex_open && room == Room1) codex_open = false;   // safety: never blocks combat
if (codex_open) {
    // G still closes for old muscle memory; Esc/back chip is the real path.
    if (input_hotkey("G")) {
        codex_open        = false;
        codex_detail_item = undefined;
        exit;
    }

    // Build master item list (same logic as Draw does - needed for scroll bounds)
    var _gal_all = [];
    if (variable_global_exists("loot_table_common"))    { for (var _gi = 0; _gi < array_length(global.loot_table_common);    _gi++) array_push(_gal_all, global.loot_table_common[_gi]);    }
    if (variable_global_exists("loot_table_uncommon"))  { for (var _gi = 0; _gi < array_length(global.loot_table_uncommon);  _gi++) array_push(_gal_all, global.loot_table_uncommon[_gi]);  }
    if (variable_global_exists("loot_table_rare"))      { for (var _gi = 0; _gi < array_length(global.loot_table_rare);      _gi++) array_push(_gal_all, global.loot_table_rare[_gi]);      }
    if (variable_global_exists("loot_table_legendary")) { for (var _gi = 0; _gi < array_length(global.loot_table_legendary); _gi++) array_push(_gal_all, global.loot_table_legendary[_gi]); }
    var _gal_count      = array_length(_gal_all);
    var _gal_visible    = 12;
    var _gal_max_scroll = max(0, _gal_count - _gal_visible);

    if (nav_up()) {
        if (codex_cursor > 0) {
            codex_cursor--;
            if (codex_cursor < codex_scroll) codex_scroll = codex_cursor;
        }
    }
    if (nav_down()) {
        if (codex_cursor < _gal_count - 1) {
            codex_cursor++;
            if (codex_cursor >= codex_scroll + _gal_visible) codex_scroll = codex_cursor - _gal_visible + 1;
        }
    }
    // Mouse wheel scrolling
    var _wheel = mouse_wheel_up() - mouse_wheel_down();
    if (_wheel != 0) {
        codex_scroll = clamp(codex_scroll - _wheel, 0, _gal_max_scroll);
    }

    // Enter/click on a discovered item opens detail
    if ((input_confirm())
        && codex_cursor >= 0 && codex_cursor < _gal_count) {
        var _sel = _gal_all[codex_cursor];
        var _disc = false;
        if (variable_global_exists("items_discovered")) {
            for (var _di = 0; _di < array_length(global.items_discovered); _di++) {
                if (global.items_discovered[_di] == _sel.name) { _disc = true; break; }
            }
        }
        if (_disc) {
            codex_detail_item = (codex_detail_item == _sel) ? undefined : _sel;
        }
    }

    // Mouse click on gallery rows
    if (mouse_check_button_pressed(mb_left)) {
        var _gmx = device_mouse_x_to_gui(0);
        var _gmy = device_mouse_y_to_gui(0);
        // List rows: x=30-1095, y=120+i*69, h=63
        for (var _gri = 0; _gri < _gal_visible; _gri++) {
            var _gry = 120 + _gri * 69;
            if (_gmx >= 30 && _gmx < 1095 && _gmy >= _gry && _gmy < _gry + 63) {
                var _abs_i = codex_scroll + _gri;
                if (_abs_i < _gal_count) {
                    codex_cursor = _abs_i;
                    var _sel2 = _gal_all[_abs_i];
                    var _disc2 = false;
                    if (variable_global_exists("items_discovered")) {
                        for (var _di2 = 0; _di2 < array_length(global.items_discovered); _di2++) {
                            if (global.items_discovered[_di2] == _sel2.name) { _disc2 = true; break; }
                        }
                    }
                    if (_disc2) {
                        codex_detail_item = (codex_detail_item == _sel2) ? undefined : _sel2;
                    } else {
                        codex_detail_item = undefined;
                    }
                }
                break;
            }
        }
        // Close detail panel X button: x=1853-1883, y=108-138
        if (_gmx >= 1853 && _gmx < 1883 && _gmy >= 108 && _gmy < 138 && codex_detail_item != undefined) {
            codex_detail_item = undefined;
        }
    }

    // Alt+click on a discovered gallery row opens the comparison panel.
    // Hub-only: the floor's Draw doesn't render the comparison overlay, so
    // opening it there would be an invisible state eating the next Esc.
    if (room == rm_hub && mouse_check_button_pressed(mb_left) && keyboard_check(vk_alt)) {
        var _gax = device_mouse_x_to_gui(0);
        var _gay = device_mouse_y_to_gui(0);
        for (var _gari = 0; _gari < _gal_visible; _gari++) {
            var _gary = 120 + _gari * 69;
            if (_gax >= 30 && _gax < 1095 && _gay >= _gary && _gay < _gary + 63) {
                var _gabs = codex_scroll + _gari;
                if (_gabs < _gal_count) {
                    var _gcit = _gal_all[_gabs];
                    var _gcdisc = false;
                    if (variable_global_exists("items_discovered")) {
                        for (var _gdi = 0; _gdi < array_length(global.items_discovered); _gdi++) {
                            if (global.items_discovered[_gdi] == _gcit.name) { _gcdisc = true; break; }
                        }
                    }
                    if (_gcdisc && variable_struct_exists(_gcit, "slot")) {
                        comparison_item     = _gcit;
                        comparison_equipped = undefined;
                        if (variable_global_exists("inventory")) {
                            var _gcsi = comparison_target_index(_gcit);   // ring-aware target
                            if (_gcsi >= 0 && _gcsi < array_length(global.inventory)) {
                                comparison_equipped = global.inventory[_gcsi];
                            }
                        }
                        comparison_open = true;
                    }
                }
                break;
            }
        }
    }

    if (input_cancel()) {
        if (comparison_open) {
            comparison_open     = false;
            comparison_item     = undefined;
            comparison_equipped = undefined;
        } else if (codex_detail_item != undefined) {
            codex_detail_item = undefined;
        } else {
            codex_open = false;
        }
    }

    exit; // codex owns input while open
}

// --- JOURNAL (Phase 4a): J toggles the overlay at the hub / on the floor map. While
// open it owns all input (ui_input_blocked() reports true, freezing every room
// controller). VIEW/TRACK ONLY (Phase 4b) - actions live at the Tavern board.
if (journal_open) {
    if (input_hotkey("J") || input_cancel()) {
        journal_open = false;
        journal_badges_sweep_orphans();   // stuck badges on delisted entries can't flash the chip forever
        exit;
    }
    // Six tabs since 2026-08-06: Relationships / Quests / Compendium /
    // Item Codex / Bestiary / Creatures. Q back, E forward.
    if (input_tab_next() || touch_dpad_tab_next()) { journal_tab = (journal_tab + 1) mod 7; journal_cursor = 0; }
    if (input_tab_prev() || touch_dpad_tab_prev()) { journal_tab = (journal_tab + 6) mod 7; journal_cursor = 0; }
    if (journal_tab == 6) {
        // BLUEPRINTS (M 08-13): the Pattern Book as a read-only Journal tab -
        // Dorn's [B] overlay stays the working shortcut, this is the reference
        // copy you can check anywhere. journal_cursor walks the family list.
        var _jp_n = array_length(pattern_family_catalog());
        if (_jp_n > 0) {
            if (nav_up())   journal_cursor = wrap_index(journal_cursor - 1, _jp_n);
            if (nav_down()) journal_cursor = wrap_index(journal_cursor + 1, _jp_n);
            var _jp_wheel = mouse_wheel_up() - mouse_wheel_down();
            repeat (abs(_jp_wheel)) {
                if (_jp_wheel > 0) journal_cursor = max(0, journal_cursor - 1);
                else               journal_cursor = min(_jp_n - 1, journal_cursor + 1);
            }
        }
        exit;
    }
    if (journal_tab == 5) {
        // CREATURES (the compendium proper - DESIGN_WORLD_EXPANSION_0806.md §10):
        // walks every species, discovered or not. Undiscovered rows stay as
        // silhouettes, so the list length never leaks less than the full roster.
        var _jk_cat = compendium_catalog();
        var _jk_n = array_length(_jk_cat);
        if (!variable_instance_exists(id, "journal_form")) journal_form = 3;
        if (_jk_n > 0) {
            if (nav_up())   { journal_cursor = wrap_index(journal_cursor - 1, _jk_n); journal_form = 3; }
            if (nav_down()) { journal_cursor = wrap_index(journal_cursor + 1, _jk_n); journal_form = 3; }
            // Wheel walks the list too - the roster is 60+ deep. No wrap on wheel.
            var _jk_wheel = mouse_wheel_up() - mouse_wheel_down();
            repeat (abs(_jk_wheel)) {
                if (_jk_wheel > 0) journal_cursor = max(0, journal_cursor - 1);
                else               journal_cursor = min(_jk_n - 1, journal_cursor + 1);
                journal_form = 3;
            }
            // FORM SLOTS (M 08-13): A/D cycles the four forms (baby / young
            // adult / adult / awakened), skipping ones not yet revealed. The
            // draw side clamps DOWN to the highest revealed, so the default 3
            // always lands on the best form you have seen.
            // (touch: LEFT/RIGHT switch journal tabs instead - the form chips are tap targets)
            if ((nav_left() || nav_right()) && input_device() != 2) {
                var _jf_id     = _jk_cat[clamp(journal_cursor, 0, _jk_n - 1)].id;
                var _jf_max    = compendium_stage_max(_jf_id);
                var _jf_stages = [PET_STAGE_BABY, PET_STAGE_YOUNGADULT, PET_STAGE_ADULT, PET_STAGE_AWAKENED];
                var _jf_dir    = nav_right() ? 1 : -1;
                var _jf_try    = clamp(journal_form, 0, 3);
                repeat (4) {
                    _jf_try = wrap_index(_jf_try + _jf_dir, 4);
                    if (_jf_stages[_jf_try] <= _jf_max) { journal_form = _jf_try; break; }
                }
            }
        }
        exit;
    }
    if (journal_tab == 2) {
        // Compendium (moved here from the character menu): browse sections.
        var _jc_count = array_length(ui_compendium_sections());
        if (nav_down()) compendium_section = wrap_index(compendium_section + 1, _jc_count);
        if (nav_up())   compendium_section = wrap_index(compendium_section - 1, _jc_count);
        exit;
    }
    if (journal_tab == 3) {
        // Item Codex: inline browse (07-29 M pass - the old Enter-hop into a
        // separate full-screen gallery was redundant; the tab IS the codex now,
        // mirroring the Bestiary's list + detail). W/S walks every entry;
        // discovered rows show their record, the rest stay ???.
        var _jx_list = item_codex_master_list();
        var _jx_n    = array_length(_jx_list);
        if (_jx_n > 0) {
            journal_cursor = clamp(journal_cursor, 0, _jx_n - 1);
            // Section headers occupy rows but can't be selected - normalize a
            // fresh cursor off one, and hop over them while navigating.
            if (codex_entry_is_header(_jx_list[journal_cursor])) journal_cursor = codex_nav_move(journal_cursor, 1, _jx_list);
            if (nav_up())   journal_cursor = codex_nav_move(journal_cursor, -1, _jx_list);
            if (nav_down()) journal_cursor = codex_nav_move(journal_cursor,  1, _jx_list);
            // Mouse wheel walks the list too (it's ~150 entries deep). No wrap:
            // stepping past either end stays put (codex_nav_move wraps, so a
            // wrapped result moving against the scroll direction means "end").
            var _jx_wheel = mouse_wheel_up() - mouse_wheel_down();
            repeat (abs(_jx_wheel)) {
                var _jx_d   = (_jx_wheel > 0) ? -1 : 1;
                var _jx_try = codex_nav_move(journal_cursor, _jx_d, _jx_list);
                if ((_jx_d > 0 && _jx_try < journal_cursor) || (_jx_d < 0 && _jx_try > journal_cursor)) break;
                journal_cursor = _jx_try;
            }
        }
        exit;
    }
    if (journal_tab == 4) {
        // Bestiary: browse species lore.
        var _jb_n = array_length(bestiary_catalog());
        if (_jb_n > 0) {
            if (nav_up())   journal_cursor = wrap_index(journal_cursor - 1, _jb_n);
            if (nav_down()) journal_cursor = wrap_index(journal_cursor + 1, _jb_n);
        }
        exit;
    }
    if (journal_tab == 0) {
        var _jm = journal_met_ids();
        var _jn = array_length(_jm);
        if (_jn > 0) {
            if (nav_up())   journal_cursor = wrap_index(journal_cursor - 1, _jn);
            if (nav_down()) journal_cursor = wrap_index(journal_cursor + 1, _jn);
            journal_cursor = clamp(journal_cursor, 0, _jn - 1);
            journal_clear_npc(_jm[journal_cursor]);   // badges clear on VIEW
        }
    } else {
        var _jq  = journal_quest_rows();
        var _jqn = array_length(_jq);
        if (_jqn > 0) {
            if (nav_up())   journal_cursor = wrap_index(journal_cursor - 1, _jqn);
            if (nav_down()) journal_cursor = wrap_index(journal_cursor + 1, _jqn);
            journal_cursor = clamp(journal_cursor, 0, _jqn - 1);
            var _jrow = _jq[journal_cursor];
            journal_clear_quest(_jrow);               // badges clear on VIEW
            // (View-only since Phase 4b: accepting/turning in happens at the Tavern
            // Requests board - taking jobs out of your own diary felt wrong. - M)
        }
    }
    exit;
}
if (input_hotkey("J") && (room == rm_hub || room == rm_dungeon_floor)
    && !ui_input_blocked() && !global.ui_overlay_latch
    && (!variable_global_exists("pause_open") || !global.pause_open)) {
    journal_open   = true;
    journal_cursor = 0;
    audio_play_sound(snd_page, 1, false);
    exit;
}

// --- P: COMPANION INSPECT (M 07-08) - the full pet profile (ui_draw_pet_detail)
// as an overlay on the floor map and in combat. While open every room controller
// freezes (pet_inspect_open reports through ui_input_blocked). No active
// companion = no-op; the hub reaches the same profile via char menu > Companion.
if (pet_inspect_open) {
    if (input_hotkey("P") || input_cancel() || input_back() || input_detail()
        || input_confirm()) {
        pet_inspect_open = false;
    }
    exit;
}
if (input_hotkey("P") && (room == rm_dungeon_floor || instance_exists(obj_combat_controller))
    && !ui_input_blocked() && !global.ui_overlay_latch
    && (!variable_global_exists("pause_open") || !global.pause_open)
    && pet_active() != undefined) {
    pet_inspect_open = true;
    audio_play_sound(snd_page, 1, false);
    exit;
}

// Close comparison panel on ESC (checked before other handlers)
if (comparison_open && input_cancel()) {
    comparison_open     = false;
    comparison_item     = undefined;
    comparison_equipped = undefined;
}

// Tick trait unlock notification timer
if (trait_notif_timer > 0) {
    trait_notif_timer--;
    if (trait_notif_timer <= 0) trait_notif_msg = "";
}

// Tick equip confirmation notification
if (equip_notif_timer > 0) {
    equip_notif_timer--;
    if (equip_notif_timer <= 0) equip_notif_msg = "";
}

// `I` opens the full character menu everywhere, combat included, so the player can
// check equipment/status mid-fight. Combat item USE is a separate quick-menu on the
// C key (obj_combat_controller) - distinct key, so the two don't conflict. Stands
// down while a name is being typed (text_entry_active - the letter is just a letter)
// and while Bairc's Garden is open (#15: I there = Identify egg, not inventory).
if (!stash_mode_open && !loadout_open && !bairc_open && !text_entry_active() && input_hotkey("I")) {
    menu_open = !menu_open;
    menu_tab  = 0;
    equip_picker_open       = false;
    consumable_submenu_open = false;
    ability_page            = 0;
    trunk_arm               = false;
    compendium_section      = 0;
    equip_found_focus       = false;   // Equipment tab: is the right "found items" column focused?
    equip_found_cursor      = 0;
    equip_found_sort        = 0;       // 0 = sort by rarity, 1 = sort by type/slot
}


// =============================================================================
// STASH SCREEN - runs before the menu_open guard so it fires when menu is closed
// =============================================================================
if (stash_mode_open) {
    // Category tabs: 0 = equipment, 1 = consumables. Q/E flip the tab (matching
    // the journal/Maren/loadout idiom); both columns show only that category, so
    // the two item families no longer interleave in one long list.
    // Consumables navigate by GROUP (identical items share one xN row - see
    // ui_consumable_groups), equipment by individual item.
    var _left_count  = (stash_mode_tab == 0) ? array_length(global.carried_items)
                                             : array_length(ui_consumable_groups(global.consumable_inventory));
    var _right_count = (stash_mode_tab == 0) ? array_length(global.equipment_stash)
                                             : array_length(ui_consumable_groups(global.consumable_stash));
    var _cur_count   = (stash_mode_side == 0) ? _left_count : _right_count;

    // Rewired to scr_input (INPUT_ABSTRACTION_SPEC.md chunk 1 template) - keyboard
    // behavior is identical; gamepad/touch backends land later behind the same calls.
    // Tab 2 = MISC (M 08-26): the read-only holdings ledger - reagents, ingots,
    // dust, forge parts, banshees/songs, eggs (stash_misc_rows, scr_stats).
    if (input_tab_next()) {
        stash_mode_tab   = (stash_mode_tab + 1) mod 3;
        stash_mode_index = 0;   // side is kept: tab-flipping in the stash column stays there
        stash_scroll     = 0;
        audio_play_sound(snd_page, 1, false);
    }
    if (input_tab_prev()) {
        stash_mode_tab   = (stash_mode_tab + 2) mod 3;
        stash_mode_index = 0;
        stash_scroll     = 0;
        audio_play_sound(snd_page, 1, false);
    }
    // Touch (M 07-08): sideways swipe across the item columns flips the tab -
    // simulated Q/E into the handler above.
    if (input_device() == 2) touch_swipe_tab(45, 249, 1875, 960);
    // MISC is a single read-only list: no sides, and its row count drives the cursor.
    if (stash_mode_tab == 2) _cur_count = array_length(stash_misc_rows());
    // nav_left/right = arrows AND A/D, like every other two-column screen.
    if (stash_mode_tab != 2 && nav_left()) {
        stash_mode_side  = 0;
        stash_mode_index = 0;
        stash_scroll     = 0;
    }
    if (stash_mode_tab != 2 && nav_right()) {
        stash_mode_side  = 1;
        stash_mode_index = 0;
        stash_scroll     = 0;
    }
    // Hold-to-repeat + wrap-around (top<->bottom). nav_up/down auto-repeat while held.
    if (nav_up())   stash_mode_index = wrap_index(stash_mode_index - 1, _cur_count);
    if (nav_down()) stash_mode_index = wrap_index(stash_mode_index + 1, _cur_count);

    // Edge-triggered scroll for the ACTIVE column: cursor moves within the visible
    // window; the list only shifts when the cursor reaches the top/bottom edge. Visible
    // rows mirror the Draw + mouse math (list top y249, row 75, bottom 1020 -> 10 rows).
    var _stash_vis = max(1, floor((1020 - 249) / 75));
    if (stash_mode_index < stash_scroll)               stash_scroll = stash_mode_index;
    if (stash_mode_index >= stash_scroll + _stash_vis) stash_scroll = stash_mode_index - (_stash_vis - 1);
    stash_scroll = clamp(stash_scroll, 0, max(0, _cur_count - _stash_vis));

    if (input_confirm() && stash_mode_tab != 2) {   // MISC is read-only - nothing to move
        // The tab picks the array pair, the side picks the direction.
        if (stash_mode_side == 0) {
            if (stash_mode_tab == 0 && stash_mode_index < array_length(global.carried_items)) {
                var _it = global.carried_items[stash_mode_index];
                array_delete(global.carried_items, stash_mode_index, 1);
                array_push(global.equipment_stash, _it);
            } else if (stash_mode_tab == 1) {
                // Grouped row: move ONE copy of the selected kind per press.
                var _lg = ui_consumable_groups(global.consumable_inventory);
                if (stash_mode_index < array_length(_lg)) {
                    var _src = _lg[stash_mode_index].first_index;
                    var _it  = global.consumable_inventory[_src];
                    array_delete(global.consumable_inventory, _src, 1);
                    array_push(global.consumable_stash, _it);
                }
            }
            // Re-clamp against the POST-move count (a grouped xN row survives a
            // single-copy move, so the stale pre-move count would bump the cursor).
            var _post_l = (stash_mode_tab == 0) ? array_length(global.carried_items)
                                                : array_length(ui_consumable_groups(global.consumable_inventory));
            stash_mode_index = clamp(stash_mode_index, 0, max(0, _post_l - 1));
        } else {
            if (stash_mode_tab == 0 && stash_mode_index < array_length(global.equipment_stash)) {
                var _it = global.equipment_stash[stash_mode_index];
                array_delete(global.equipment_stash, stash_mode_index, 1);
                array_push(global.carried_items, _it);
            } else if (stash_mode_tab == 1) {
                // Grouped row: move ONE copy of the selected kind per press.
                var _rg = ui_consumable_groups(global.consumable_stash);
                if (stash_mode_index < array_length(_rg)) {
                    var _src = _rg[stash_mode_index].first_index;
                    var _it  = global.consumable_stash[_src];
                    array_delete(global.consumable_stash, _src, 1);
                    array_push(global.consumable_inventory, _it);
                }
            }
            var _post_r = (stash_mode_tab == 0) ? array_length(global.equipment_stash)
                                                : array_length(ui_consumable_groups(global.consumable_stash));
            stash_mode_index = clamp(stash_mode_index, 0, max(0, _post_r - 1));
        }
        // Persist the deposit/withdraw immediately (stash is hub-only state).
        if (room == rm_hub || room == rm_character_select) save_game();
    }

    if (input_cancel() || input_back()) {
        stash_mode_open = false;
    }

    // Mouse: click a tab to switch category, a column to switch side, an item
    // row to select it. Geometry mirrors ui_draw_stash_screen (tabs at
    // x660/x975 y138..190; cols at x45/x1020 width 855, list top y249, row
    // height 75) including the scroll window so clicks map to the right entry
    // even when the list is scrolled.
    if (mouse_check_button_pressed(mb_left)) {
        var _smx = device_mouse_x_to_gui(0);
        var _smy = device_mouse_y_to_gui(0);
        var _list_top    = 249;
        var _row_h       = 75;
        var _max_bot     = 1020;
        var _rows_vis    = max(1, floor((_max_bot - _list_top) / _row_h));
        // Category tabs (3-up since MISC, M 08-26: x = 503 + t*315, 285 wide -
        // MUST mirror ui_draw_stash_screen's tab bar)
        if (_smy >= 138 && _smy < 190) {
            for (var _stt = 0; _stt < 3; _stt++) {
                var _sttx = 503 + _stt * 315;
                if (_smx >= _sttx && _smx < _sttx + 285 && stash_mode_tab != _stt) {
                    stash_mode_tab = _stt; stash_mode_index = 0; stash_scroll = 0;
                    audio_play_sound(snd_page, 1, false);
                    break;
                }
            }
        }
        // MISC tab: single list panel (x360-1560) - a click selects its row.
        if (stash_mode_tab == 2) {
            if (_smx >= 360 && _smx < 1560 && _smy >= _list_top && _smy < _max_bot) {
                var _mcnt = array_length(stash_misc_rows());
                var _mscr = clamp(stash_scroll, 0, max(0, _mcnt - _rows_vis));
                var _mrow = _mscr + floor((_smy - _list_top) / _row_h);
                if (_mrow >= 0 && _mrow < _mcnt) stash_mode_index = _mrow;
            }
        } else {
        // Switch to left side
        if (_smx >= 45 && _smx < 900 && _smy >= 204 && _smy < _max_bot) {
            if (stash_mode_side != 0) { stash_mode_side = 0; stash_mode_index = 0; stash_scroll = 0; }
            else if (_smy >= _list_top) {
                var _lcnt   = (stash_mode_tab == 0) ? array_length(global.carried_items)
                                                    : array_length(ui_consumable_groups(global.consumable_inventory));
                var _lscr   = clamp(stash_scroll, 0, max(0, _lcnt - _rows_vis));
                var _lrow   = _lscr + floor((_smy - _list_top) / _row_h);
                if (_lrow >= 0 && _lrow < _lcnt) stash_mode_index = _lrow;
            }
        }
        // Switch to right side
        if (_smx >= 1020 && _smx < 1875 && _smy >= 204 && _smy < _max_bot) {
            if (stash_mode_side != 1) { stash_mode_side = 1; stash_mode_index = 0; stash_scroll = 0; }
            else if (_smy >= _list_top) {
                var _rcnt   = (stash_mode_tab == 0) ? array_length(global.equipment_stash)
                                                    : array_length(ui_consumable_groups(global.consumable_stash));
                var _rscr   = clamp(stash_scroll, 0, max(0, _rcnt - _rows_vis));
                var _rrow   = _rscr + floor((_smy - _list_top) / _row_h);
                if (_rrow >= 0 && _rrow < _rcnt) stash_mode_index = _rrow;
            }
        }
        }   // end tab-0/1 column handling (MISC handled above)
    }

    exit;
}

// =============================================================================
// LEVEL-UP ALLOCATION - handled here so ui_input_blocked() can freeze the
// combat controller's Step while the overlay is active without breaking input.
// =============================================================================
if (level_alloc_open) {
    if (nav_up())   level_alloc_index = wrap_index(level_alloc_index - 1, 6);
    if (nav_down()) level_alloc_index = wrap_index(level_alloc_index + 1, 6);

    // Enter: set or move the provisional stat choice - does NOT commit yet
    if ((input_confirm()) && global.pending_stat_points > 0) {
        level_alloc_pending_stat = level_alloc_index;
    }

    // Space: commit the provisional choice permanently
    if (input_confirm_alt()
        && level_alloc_pending_stat >= 0 && global.pending_stat_points > 0) {
        var _alloc_keys = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        var _chosen_key = _alloc_keys[level_alloc_pending_stat];
        variable_struct_set(global.run_stat_bonuses, _chosen_key,
            variable_struct_get(global.run_stat_bonuses, _chosen_key) + 1);
        global.pending_stat_points--;
        level_alloc_pending_stat = -1;
        // Update live player stats if in combat - CON recalcs HP only on confirm.
        // BUG FIX (2026-07-04): this used to OVERWRITE max_HP with the bare
        // stats_derive value, silently dropping gear +HP, Thick Skin and boon/curse
        // multipliers (the "HP bar snaps to base HP after combat" report) - and the
        // clamped current HP was then saved as the carried run HP, so HP was really
        // lost. Apply only the CON DELTA on top of the true combat max instead.
        if (instance_exists(obj_combat_controller)) {
            var _ctrl = instance_find(obj_combat_controller, 0);
            var _hp_derived_before = stats_derive(_ctrl.player.stats).HP;
            variable_struct_set(_ctrl.player.stats, _chosen_key,
                variable_struct_get(_ctrl.player.stats, _chosen_key) + 1);
            if (_chosen_key == "CON") {
                var _hg = stats_derive(_ctrl.player.stats).HP - _hp_derived_before;
                _ctrl.player.max_HP += max(0, _hg);
                _ctrl.player.HP      = min(_ctrl.player.max_HP, _ctrl.player.HP + max(0, _hg));
            }
        }
        if (global.pending_stat_points <= 0) level_alloc_open = false;
    }
    exit;
}


// =============================================================================
// TOUCH ACTION MENU (M 07-17) - modal list of the open NPC screen's letter-hotkey
// verbs (Deepen Bond / Gift / Reforge / Cancel), for touch where those keys have
// no direct tap target. Opened by long-press (on empty space, so it can't also
// trip a press-fire buy) or the ACTIONS chip; a row tap fires the matching
// simulated key through the unchanged handler NEXT frame. The menu owns input
// while open (exits, freezing the screen beneath). Drawn by
// ui_draw_touch_action_menu. Placed AFTER the higher modals (item picker / gift /
// kb / journal / pet inspect, which all exit above) so those keep priority -
// __input_ctx() reads shop/bairc only when none of them own input.
// =============================================================================
if (input_device() == 2) {
    if (!variable_global_exists("touch_amenu")) global.touch_amenu = { open: false, open_t0: -1 };
    var _am_ctx = __input_ctx();
    var _am_npc = (_am_ctx == "shop" || _am_ctx == "bairc");
    if (global.touch_amenu.open) {
        var _am_items = touch_action_menu_items();
        if (!_am_npc || array_length(_am_items) == 0) {
            global.touch_amenu.open = false;
        } else {
            // Ignore the very gesture that opened the menu (same press-origin time)
            // so its own release can't instantly select a row or dismiss.
            if (global.tg.t0 != global.touch_amenu.open_t0) {
                var _am_lay = touch_amenu_rects(array_length(_am_items));
                var _am_hit = false;
                for (var _ai = 0; _ai < array_length(_am_items); _ai++) {
                    var _amr = _am_lay.rows[_ai];
                    if (touch_tap_in(_am_lay.x1, _amr.y1, _am_lay.x2, _amr.y2)) {
                        touch_press(_am_items[_ai].key);
                        global.touch_amenu.open = false;
                        _am_hit = true;
                        break;
                    }
                }
                // Close row or any tap outside a row dismisses.
                if (!_am_hit && touch_tap()) global.touch_amenu.open = false;
            }
            exit;   // modal owns input while open
        }
    } else if (_am_npc && touch_lp() && array_length(touch_action_menu_items()) > 0) {
        global.touch_amenu.open    = true;
        global.touch_amenu.open_t0 = global.tg.t0;
        audio_play_sound(snd_page, 1, false);
        exit;
    }
}

// =============================================================================
// DEEPEN BOND (B) inside an open NPC screen, so a ready gate is actionable right
// where you earn it (mirrors the hub-list B handler, which is gated off while a
// screen is open). Maps the currently-open NPC screen to its affinity id. No-ops
// when no NPC screen is open (B stays free for the hub list / combat).
// =============================================================================
if (input_hotkey("B")) {
    var _bond_npc = "";
    if (shop_open == 0)                                                    _bond_npc = "petra";
    else if (shop_open == 1)                                               _bond_npc = "dorn";
    else if (variable_instance_exists(id, "trainer_open") && trainer_open) _bond_npc = "vex";
    else if (variable_instance_exists(id, "maren_open")   && maren_open)   _bond_npc = "maren";
    else if (variable_instance_exists(id, "sable_open")   && sable_open)   _bond_npc = "sable";
    else if (variable_instance_exists(id, "vael_open")    && vael_open)    _bond_npc = "vael";
    if (_bond_npc != "" && affinity_gate_ready(_bond_npc)) {
        // 4c: advancing may START the gate quest instead of crossing. Show the
        // result ON THE OPEN SCREEN's own notification line - the hub line is
        // hidden behind the overlay, so pressing B looked like it did nothing and
        // players only discovered the change later in the journal (M 07-08). A
        // successful crossing ("" return) gets an explicit message too.
        var _adv_msg = affinity_try_advance(_bond_npc);
        if (_adv_msg == "") {
            _adv_msg = npc_display_name(_bond_npc) + ": your bond deepens to " + affinity_tier_name(_bond_npc) + "!";
        }
        if (_adv_msg != "Not ready.") {
            switch (_bond_npc) {
                case "petra": case "dorn": shop_notification    = _adv_msg; break;
                case "vex":                trainer_notification = _adv_msg; break;
                case "maren":              maren_notification   = _adv_msg; break;
                case "sable":              sable_notification   = _adv_msg; break;
                case "vael":               vael_notification    = _adv_msg; break;
            }
            if (instance_exists(obj_hub_controller)) instance_find(obj_hub_controller, 0).notification = _adv_msg;
        }
        if (room == rm_hub || room == rm_character_select) save_game();
    }
}

// =============================================================================
// F = GIVE A GIFT, inside the open NPC's engagement window (Phase 4b UX, M: gifting
// from the hub list felt out of place - you hand it over in person). One shared
// handler for all seven windows; guarded against every sub-modal that owns input.
// =============================================================================
if (input_hotkey("F") && room == rm_hub && !text_entry_active() && !menu_open
    && !(variable_global_exists("item_picker") && global.item_picker.open)) {
    var _gift_npc = "", _gift_notify = -1;   // -1 = none; else which notification var
    if (shop_open != -1 && !stash_mode_open) {
        _gift_npc = (shop_open == 0) ? "petra" : "dorn"; _gift_notify = 0;
    } else if (trainer_open && !trainer_statpick_open && !vex_detail_open) {
        _gift_npc = "vex"; _gift_notify = 1;
    } else if (variable_instance_exists(id, "maren_open") && maren_open && maren_confirm == undefined
        && !banshee_release_open) {
        _gift_npc = "maren"; _gift_notify = 2;
    } else if (variable_instance_exists(id, "sable_open") && sable_open) {
        _gift_npc = "sable"; _gift_notify = 3;
    } else if (variable_instance_exists(id, "vael_open") && vael_open) {
        _gift_npc = "vael"; _gift_notify = 4;
    } else if (variable_instance_exists(id, "bairc_open") && bairc_open
        && !bairc_naming && !bairc_capstone_open && !bairc_release_confirm
        && !bairc_detail_open && !hatch_active) {
        _gift_npc = "bairc"; _gift_notify = 5;
    }
    if (_gift_npc != "") {
        var _gmsg = gift_try_open(_gift_npc, npc_display_name(_gift_npc));
        if (_gmsg != "") {
            switch (_gift_notify) {
                case 0: shop_notification    = _gmsg; break;
                case 1: trainer_notification = _gmsg; break;
                case 2: maren_notification   = _gmsg; break;
                case 3: sable_notification   = _gmsg; break;
                case 4: vael_notification    = _gmsg; break;
                case 5: bairc_notification   = _gmsg; break;
            }
        }
        exit;
    }
}

// =============================================================================
// SHOP INPUT - runs before menu_open guard; gc handles all buy/sell logic.
// Stands down while the I character menu is up (M 07-28: inventory popped over
// the shop but arrows/enter kept driving the shop underneath) - the menu block
// owns input until it closes, then control falls back to the shop.
// =============================================================================
if (shop_open != -1 && !stash_mode_open && !menu_open && !forge_result_up()
    && npc_tour_step < 0) {   // guided tour owns input while it runs

    // Q/E: cycle tabs. Petra (shop_open == 0) has BUY/SELL/TRADE; Dorn has BUY/SELL/REFORGE.
    // The reforge confirm/anim screen (reforge_stage > 0) is MODAL - tab cycling and
    // the [R] jump are locked out until it resolves (the roll may already be paid for).
    // M 08-26 (Steam bug): so are the Legendary Forge, the Pattern Book modals, and
    // the Dorn checkout popup - this block runs BEFORE those modal blocks, so typing
    // Q/E into a forge/craft NAME was also rotating the shop tabs underneath.
    // text_entry_active() belts-and-suspenders the naming phases specifically.
    var _rf_modal = (variable_instance_exists(id, "reforge_stage") && reforge_stage > 0)
        || (variable_instance_exists(id, "forge_open")    && forge_open)
        || (variable_instance_exists(id, "pb_craft_open") && pb_craft_open)
        || (variable_instance_exists(id, "pb_smelt_open") && pb_smelt_open)
        || (variable_instance_exists(id, "pb_book_open")  && pb_book_open)
        || (variable_instance_exists(id, "dorn_ck_open")  && dorn_ck_open)
        || text_entry_active();
    var _shop_ntabs = shop_tab_count(shop_open);
    if ((input_tab_next() || touch_dpad_tab_next()) && !_rf_modal) {
        shop_tab = (shop_tab + 1) mod _shop_ntabs;
        sell_index = 0; sell_scroll = 0; buy_scroll = 0; sell_confirm_name = ""; shop_notification = "";
        reforge_index = 0; reforge_scroll = 0;
        petra_trade_confirm = false; petra_trade_selected = []; petra_trade_notification = "";
    }
    if ((input_tab_prev() || touch_dpad_tab_prev()) && !_rf_modal) {
        shop_tab = (shop_tab + _shop_ntabs - 1) mod _shop_ntabs;
        sell_index = 0; sell_scroll = 0; buy_scroll = 0; sell_confirm_name = ""; shop_notification = "";
        reforge_index = 0; reforge_scroll = 0;
        petra_trade_confirm = false; petra_trade_selected = []; petra_trade_notification = "";
    }

    // Dorn's affix rework lives on its own REFORGE tab now (shop_tab == 2). [R] is a
    // shortcut that jumps straight to it from any Dorn tab.
    if (shop_open == 1 && input_hotkey("R") && !_rf_modal) {
        shop_tab = 2; reforge_index = 0; reforge_scroll = 0; shop_notification = "";
    }

    // =========================================================================
    // SELL TAB
    // =========================================================================
    if (shop_tab == 1) {

        // Sell list via the shared sorted builder (rarity-DESC equipment, then
        // consumables) - MUST match the Draw renderer's list exactly, so both call
        // shop_build_sell_list(). Equipped slots (global.inventory[]) excluded.
        var _sl       = shop_build_sell_list();
        var _sl_items = _sl.items;
        var _sl_src   = _sl.src;    // 0=equipment_stash  1=consumable_stash  2=carried_items  3=consumable_inventory
        var _sl_idx   = _sl.idx;    // index within the source array at build time
        var _sl_count = array_length(_sl_items);

        // Clamp cursor and scroll window
        sell_index = clamp(sell_index, 0, max(0, _sl_count - 1));
        if (sell_index < sell_scroll) {
            sell_scroll = sell_index;
        }
        if (sell_index >= sell_scroll + shop_sell_visible_rows()) {
            sell_scroll = sell_index - (shop_sell_visible_rows() - 1);
        }

        if (_sl_count > 0) {
            var _cur_item  = _sl_items[sell_index];
            var _cur_src   = _sl_src[sell_index];
            var _src_idx   = _sl_idx[sell_index];

            // Sell price: shop_sell_price() - ONE formula shared with the SELL-tab list
            // draw (40% of value, legendary x3 / 1200 floor, +5%/affinity tier, Petra
            // rank 2 +10%; valuables pay their authored value).
            var _shop_npc   = (shop_open == 0) ? "petra" : "dorn";
            var _sell_price = shop_sell_price(_cur_item, _shop_npc);

            // Rare-or-above items need a second confirmation step
            var _needs_confirm = variable_struct_exists(_cur_item, "rarity") && _cur_item.rarity >= 2;

            // W/S: navigate (clears any pending confirm)
            if (nav_up()) {
                sell_index        = wrap_index(sell_index - 1, _sl_count);
                sell_confirm_name = "";
                shop_notification = "";
            }
            if (nav_down()) {
                sell_index        = wrap_index(sell_index + 1, _sl_count);
                sell_confirm_name = "";
                shop_notification = "";
            }

            // ESC: cancel pending confirm, or close shop
            if (input_cancel()) {
                if (sell_confirm_name != "") {
                    sell_confirm_name = "";
                    shop_notification = "";
                } else {
                    shop_open         = -1;
                    shop_tab          = 0;
                    sell_index        = 0;
                    sell_scroll       = 0;
                    sell_confirm_name = "";
                    shop_notification = "";
                }
            }

            // ENTER: sell common/uncommon immediately; start confirm for rare+
            if (input_confirm()) {
                if (sell_confirm_name == "") {
                    if (_needs_confirm) {
                        sell_confirm_name = _cur_item.name;
                        shop_notification = "Sell " + _cur_item.name + " for " + string(_sell_price) + "g?";
                    } else {
                        // Sell immediately
                        if (_cur_src == 0)      array_delete(global.equipment_stash,       _src_idx, 1);
                        else if (_cur_src == 1) array_delete(global.consumable_stash,      _src_idx, 1);
                        else if (_cur_src == 2) array_delete(global.carried_items,         _src_idx, 1);
                        else if (_cur_src == 3) array_delete(global.consumable_inventory,  _src_idx, 1);
                        // Scavenger trait intentionally not applied to vendor sales.
                        // Hook: replace the direct write below with add_gold(_sell_price)
                        // if the design decision changes.
                        global.gold       += _sell_price;
                        sell_index         = clamp(sell_index, 0, max(0, _sl_count - 2));
                        shop_notification  = "Sold for +" + string(_sell_price) + "g!";
                        audio_play_sound(snd_sell, 1, false);
                        // Persist the sale (gold + removed item) right away.
                        if (room == rm_hub || room == rm_character_select) save_game();
                    }
                }
            }

            // SPACE: complete the rare-item sale after confirm
            if (input_confirm_alt() && sell_confirm_name != "") {
                if (_cur_src == 0)      array_delete(global.equipment_stash,       _src_idx, 1);
                else if (_cur_src == 1) array_delete(global.consumable_stash,      _src_idx, 1);
                else if (_cur_src == 2) array_delete(global.carried_items,         _src_idx, 1);
                else if (_cur_src == 3) array_delete(global.consumable_inventory,  _src_idx, 1);
                // Scavenger trait intentionally not applied to vendor sales.
                global.gold       += _sell_price;
                sell_index         = clamp(sell_index, 0, max(0, _sl_count - 2));
                shop_notification  = "Sold for +" + string(_sell_price) + "g!";
                audio_play_sound(snd_sell, 1, false);
                sell_confirm_name  = "";
                // Persist the sale (gold + removed item) right away.
                if (room == rm_hub || room == rm_character_select) save_game();
            }

        } else {
            // Empty sell list
            if (input_cancel()) {
                shop_open         = -1;
                shop_tab          = 0;
                sell_index        = 0;
                sell_scroll       = 0;
                sell_confirm_name = "";
                shop_notification = "";
            }
        }

        exit;
    }

    // =========================================================================
    // REFORGE TAB (Dorn only; shop_tab == 2). Two-panel rework: choose affix-bearing
    // gear on the right, spend the lowest matching-tier ingot to reroll its affixes
    // in place. Same effect as the old [R] picker (chit_reforge_item + spend).
    // =========================================================================
    if (shop_tab == 2 && shop_open == 1) {
        // First look at the REFORGE tab explains it (M 08-18 on phone: "went to reforge for
        // the first time, no tutorial") - the same tip also fires on the first ingot earned;
        // whichever comes first shows it once.
        if (npc_tour_step < 0 && !tutorial_is_active()) tutorial_try_show("dorn_reforge");
        var _rf_list = item_picker_candidates_affixed();
        var _rf_n    = array_length(_rf_list);
        reforge_index = clamp(reforge_index, 0, max(0, _rf_n - 1));

        // ---- TWO-STEP REWORK SCREEN (M 07-27: a legendary got rerolled in ONE
        // click - destructive spends get a confirmation screen now, standing rule).
        // Stage 0 = gear list below. Stage 1 = confirm card (item + cost, commit or
        // back out). Stage 2 = forge animation, input locked (the roll is already
        // paid + made, but VEILED until the reveal). Stage 3 = result card.
        // Draw side = ui_draw_reforge_confirm (buttons hit-test there, inject tags
        // "reforge:commit"/"reforge:back"/"reforge:done" per the touch rule).
        if (!variable_instance_exists(id, "reforge_stage")) {
            reforge_stage = 0; reforge_target = undefined; reforge_before = undefined;
            reforge_anim_t = 0; reforge_spent_tier = -1; reforge_is_recast = false;
            dorn_ck_open = false; dorn_ck_title = ""; dorn_ck_body = "";
            dorn_ck_kind = "frame";
            forge_open = false; forge_phase = 0; forge_cursor = 0;
            forge_slot_pick = 0; forge_fx_pick = 0; forge_result = undefined;
            // Pattern Book state (08-11): smelt study popup / book overlay / craft wizard.
            pb_smelt_open = false; pb_smelt_item = undefined; pb_smelt_pick = 0;
            pb_book_open = false; pb_book_scroll = 0; pb_book_cursor = 0;
            pb_craft_open = false; pb_craft_phase = 0;
            pb_cursor = 0; pb_scroll = 0;
            pb_cat_pick = 0;   // category phase (08-15: weapons/armor/jewelry)
            pb_slot_pick = 0; pb_rar_pick = 0; pb_base_stat = "";
            pb_affix_picks = []; pb_icon_entry = undefined;
            pb_name = ""; pb_result = undefined;
            pb_opt_twoh = false; pb_opt_school = ""; pb_hone_pick = -1;   // 08-26 chips + hone
        }

        // First-visit coach-mark (M 07-29: "Strike a Mythril Frame" read as
        // gibberish without the Legendary Forge context). Idempotent - the
        // seen-flag guard inside makes repeat calls free.
        tutorial_try_show("legendary_forge");
        // Pattern Book coach-mark (08-11): queues behind the forge one (the
        // one-at-a-time guard inside makes this safe to call every frame).
        tutorial_try_show("pattern_book");

        // THE LEGENDARY FORGE (M locked 07-28) - modal over the reforge tab.
        // Phases: 0 pick slot, 1 pick effect, 2 NAME IT (keyboard_string, the
        // char-select idiom; text_entry_active() stands global hotkeys down),
        // 3 result card. Draw = ui_draw_legendary_forge (row taps inject
        // forge:row<i>; DONE injects forge:done).
        if (forge_open) {
            if (forge_phase == 2) {
                // Cap 20 -> 60 (M 08-26: "at least 3x"); the entry box + every
                // name display shrink-to-fit, so long names render safely.
                if (string_length(keyboard_string) > 60) keyboard_string = string_copy(keyboard_string, 1, 60);
                // Keyboard is LOCKED to the name field while typing (M 08-26):
                // Backspace ONLY edits text - never backs out. (An empty-field
                // backout was tried and misfired: GM trims keyboard_string
                // BEFORE Step, so deleting the last letter read as empty and
                // kicked the player back a screen.) Esc / pad B back out.
                if (keyboard_check_pressed(vk_escape) || pad_pressed(gp_face2)) {
                    forge_phase = 1; forge_cursor = forge_fx_pick; keyboard_string = "";
                    if (input_device() == 2) keyboard_virtual_hide();
                    exit;
                }
                if (keyboard_check_pressed(vk_enter)) {
                    var _fname = string_trim(keyboard_string);
                    if (_fname == "") exit;   // no nameless legendaries
                    var _f_fx   = forge_effect_catalog()[clamp(forge_fx_pick, 0, array_length(forge_effect_catalog()) - 1)];
                    var _f_slot = forge_slot_list()[clamp(forge_slot_pick, 0, array_length(forge_slot_list()) - 1)];
                    var _f_it   = forge_build_item(_f_slot, _f_fx, _fname);
                    forge_components_ensure();
                    global.forge_comp_frame -= 1;
                    global.forge_comp_core  -= 1;
                    global.forge_comp_quint -= 1;
                    array_push(global.equipment_stash, _f_it);
                    discover_item(item_base_name(_f_it), _f_it.rarity);
                    save_game();
                    forge_result    = _f_it;
                    forge_phase     = 3;
                    keyboard_string = "";
                    if (input_device() == 2) keyboard_virtual_hide();
                    audio_play_sound(snd_confirm_major, 1, false);
                    ui_checkout_vfx(spr_vfx_impact, 960, 520);
                }
                exit;
            }
            if (forge_phase == 3) {
                if (input_confirm() || input_cancel() || input_inject_take("forge:done")) {
                    forge_open = false; forge_result = undefined;
                }
                exit;
            }
            var _f_rows = (forge_phase == 0) ? array_length(forge_slot_list()) : array_length(forge_effect_catalog());
            if (input_cancel() || input_back()) {
                if (forge_phase == 1) { forge_phase = 0; forge_cursor = forge_slot_pick; }
                else forge_open = false;
                exit;
            }
            if (nav_up())   forge_cursor = wrap_index(forge_cursor - 1, _f_rows);
            if (nav_down()) forge_cursor = wrap_index(forge_cursor + 1, _f_rows);
            forge_cursor = clamp(forge_cursor, 0, _f_rows - 1);
            var _f_tap = -1;
            for (var _fti = 0; _fti < _f_rows; _fti++) {
                if (input_inject_take("forge:row" + string(_fti))) { _f_tap = _fti; break; }
            }
            if (_f_tap >= 0) forge_cursor = _f_tap;
            if (input_confirm() || _f_tap >= 0) {
                if (forge_phase == 0) { forge_slot_pick = forge_cursor; forge_phase = 1; forge_cursor = 0; }
                else {
                    forge_fx_pick = forge_cursor; forge_phase = 2; keyboard_string = "";
                    if (input_device() == 2) keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_words, false);
                }
            }
            exit;
        }

        // Mythril Frame checkout popup (modal; Dorn's forge component).
        if (dorn_ck_open) {
            if (input_cancel() || input_back() || input_inject_take("dorn:cancel")) {
                dorn_ck_open = false;
                // Backing out of the CRAFT checkout returns to the naming phase -
                // touch users need the virtual keyboard back to keep editing.
                if (dorn_ck_kind == "pb_craft" && pb_craft_open && pb_craft_phase == 5
                    && input_device() == 2) keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_words, false);
                exit;
            }
            if (input_confirm() || input_inject_take("dorn:ok")) {
                dorn_ck_open = false;
                reforge_ingots_ensure();
                // PATTERN CRAFT checkout (08-11): validate all three costs, then
                // build + stash. A failed check returns to the naming phase with
                // nothing spent (the name survives in keyboard_string).
                if (dorn_ck_kind == "pb_craft") {
                    var _pcf = pattern_craft_fee(1 + pb_rar_pick);
                    if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
                    if (global.gold < _pcf.gold) {
                        shop_notification = "The craft asks " + string(_pcf.gold) + "g.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else if (global.rune_dust < _pcf.dust) {
                        shop_notification = "The craft asks " + string(_pcf.dust) + " rune dust - Sable salvages runes into dust.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else if (reforge_ingot_tier_for(_pcf.ingot_rar) < 0) {
                        shop_notification = "The craft asks a " + item_rarity_name(_pcf.ingot_rar) + "-tier (or higher) Reforge Ingot - smelting and the tavern board pay them.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else if (reagent_total() < pattern_craft_reagents(1 + pb_rar_pick)) {
                        // Dungeon reagents (M-locked 08-17): 1/2/3 of any kind.
                        shop_notification = "The craft asks " + string(pattern_craft_reagents(1 + pb_rar_pick)) + " dungeon reagent"
                            + ((pattern_craft_reagents(1 + pb_rar_pick) == 1) ? "" : "s") + " (you have " + string(reagent_total())
                            + ") - elites and bosses drop their dungeon's reagent.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        global.gold      -= _pcf.gold;
                        global.rune_dust -= _pcf.dust;
                        reforge_ingot_spend(_pcf.ingot_rar);
                        reagent_spend_any(pattern_craft_reagents(1 + pb_rar_pick));
                        var _pcit = pattern_craft_build(forge_slot_list()[pb_slot_pick], 1 + pb_rar_pick,
                            pb_base_stat, pb_affix_picks, pb_icon_entry, pb_name,
                            pb_opt_twoh, pb_opt_school);   // naming-screen chips (08-26)
                        array_push(global.equipment_stash, _pcit);
                        discover_item(item_base_name(_pcit), _pcit.rarity);
                        affinity_add("dorn", 2);   // function-use drip (craft) - M 08-16
                        save_game();
                        pb_result = _pcit;
                        pb_craft_phase = 6;
                        keyboard_string = "";
                        audio_play_sound(snd_confirm_major, 1, false);
                        ui_checkout_vfx(spr_vfx_impact, 960, 520);
                    }
                    exit;
                }
                // Ingot fuse checkout (M 07-29): 3 same-tier -> 1 next tier.
                if (dorn_ck_kind == "combine") {
                    var _cmb2 = reforge_combine_tier();
                    if (_cmb2 < 0) {
                        shop_notification = "Nothing to fuse - it asks 3 ingots of one tier.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        global.reforge_ingots[_cmb2]     -= 3;
                        global.reforge_ingots[_cmb2 + 1] += 1;
                        save_game();
                        shop_notification = "Dorn fuses 3 " + item_rarity_name(_cmb2)
                            + " ingots into 1 " + item_rarity_name(_cmb2 + 1) + "!";
                        audio_play_sound(snd_forge, 1, false);
                        ui_checkout_vfx(spr_vfx_fire, 960, 540);
                    }
                    exit;
                }
                var _df_g = forge_frame_cost();
                if (global.gold < _df_g) {
                    shop_notification = "The frame asks " + string(_df_g) + "g.";
                    audio_play_sound(snd_ui_error, 1, false);
                } else if (global.reforge_ingots[4] < 1) {
                    shop_notification = "The frame asks a LEGENDARY Reforge Ingot - Sunder a legendary at Maren, or the board pays them.";
                    audio_play_sound(snd_ui_error, 1, false);
                } else {
                    global.gold -= _df_g;
                    global.reforge_ingots[4] -= 1;
                    forge_components_ensure();
                    global.forge_comp_frame += 1;
                    save_game();
                    shop_notification = "MYTHRIL FRAME forged - Dorn's Legendary Forge part. (" + string(global.forge_comp_frame) + " held)";
                    audio_play_sound(snd_confirm_major, 1, false);
                    ui_checkout_vfx(spr_vfx_fire, 960, 540);
                }
                exit;
            }
            exit;
        }
        // =================================================================
        // PATTERN BOOK (M design-locked 08-11, SYSTEMS_REFORGE_CRAFT.md).
        // Three modals over the reforge tab, forge_open idiom: the SMELT
        // study popup (fodder already chosen in the shared picker), the BOOK
        // browse overlay, and the CRAFT wizard. Draw side hit-tests rows and
        // injects pbsm:/pbbk:/pb: tags per the touch rule.
        // =================================================================

        // ---- SMELT STUDY POPUP: choose which affix family the fodder teaches.
        if (pb_smelt_open) {
            if (pb_smelt_item == undefined) { pb_smelt_open = false; exit; }
            var _sm_fams = pattern_item_families(pb_smelt_item);
            var _sm_rows = array_length(_sm_fams) + 1;   // + "Just the ingot"
            if (input_cancel() || input_back() || input_inject_take("pbsm:cancel")) {
                pb_smelt_open = false; pb_smelt_item = undefined;
                exit;
            }
            if (nav_up())   pb_smelt_pick = wrap_index(pb_smelt_pick - 1, _sm_rows);
            if (nav_down()) pb_smelt_pick = wrap_index(pb_smelt_pick + 1, _sm_rows);
            for (var _smi = 0; _smi < _sm_rows; _smi++) {
                if (input_inject_take("pbsm:row" + string(_smi))) pb_smelt_pick = _smi;
            }
            pb_smelt_pick = clamp(pb_smelt_pick, 0, _sm_rows - 1);
            if (input_confirm() || input_inject_take("pbsm:ok")) {
                var _sm_fee = pattern_smelt_fee();
                if (global.gold < _sm_fee) {
                    shop_notification = "Smelting asks " + string(_sm_fee) + "g.";
                    audio_play_sound(snd_ui_error, 1, false);
                } else {
                    var _sm_pick = (pb_smelt_pick < array_length(_sm_fams)) ? _sm_fams[pb_smelt_pick] : "";
                    var _sm_msg  = pattern_smelt_commit(pb_smelt_item, _sm_pick);
                    if (_sm_msg == "") {
                        shop_notification = "It seems to have gone missing.";
                    } else {
                        shop_notification = _sm_msg;
                        audio_play_sound(snd_forge, 1, false);
                        ui_checkout_vfx(spr_vfx_fire, 960, 540);
                        affinity_add("dorn", 2);   // function-use drip (smelt) - M 08-16
                        save_game();
                    }
                    pb_smelt_open = false; pb_smelt_item = undefined;
                }
            }
            exit;
        }

        // ---- BOOK BROWSE OVERLAY: every family's pips + the art page count.
        if (pb_book_open) {
            var _bk_n   = array_length(pattern_family_catalog());
            var _bk_vis = 10;   // MUST mirror ui_draw_pattern_book
            if (input_cancel() || input_back() || input_confirm() || input_inject_take("pbbk:close")) {
                pb_book_open = false;
                exit;
            }
            // Row CURSOR, not bare window scroll (M 08-13: "no active selector in
            // blueprint screen - there should be a blue highlighter on the current
            // selection that scrolls down with key selects like every other menu").
            if (!variable_instance_exists(id, "pb_book_cursor")) pb_book_cursor = 0;
            if (nav_up()   || mouse_wheel_up()   || input_inject_take("pbbk:up")) pb_book_cursor -= 1;
            if (nav_down() || mouse_wheel_down() || input_inject_take("pbbk:dn")) pb_book_cursor += 1;
            pb_book_cursor = clamp(pb_book_cursor, 0, max(0, _bk_n - 1));
            if (pb_book_cursor < pb_book_scroll)                pb_book_scroll = pb_book_cursor;
            if (pb_book_cursor >= pb_book_scroll + _bk_vis)     pb_book_scroll = pb_book_cursor - _bk_vis + 1;
            pb_book_scroll = clamp(pb_book_scroll, 0, max(0, _bk_n - _bk_vis));
            exit;
        }

        // ---- CRAFT WIZARD: slot -> rarity -> base stat -> affixes -> art ->
        // name -> checkout -> result. Esc walks back one phase; the pick lists
        // share pb_cursor/pb_scroll (reset at each phase change).
        if (pb_craft_open) {
            // Phase row lists are rebuilt every frame from the same sources the
            // draw uses, so cursor/tap indices always agree with what's shown.
            // PHASES (08-15 v2, M: "list all of your unlocked blueprints nothing
            // else"): 0 category, 1 slot within it, 2 quality, 3 BLUEPRINTS
            // (one merged list, quality-eligible only - the first core stat
            // picked becomes the base line), 4 art, 5 name, 6 result.
            var _cw_rows = 0;
            var _cw_slots = forge_slot_list();
            var _cw_cats  = pattern_craft_categories();
            var _cw_cslots = _cw_cats[clamp(pb_cat_pick, 0, array_length(_cw_cats) - 1)].slots;
            var _cw_fams  = [];
            if (pb_craft_phase == 0) _cw_rows = array_length(_cw_cats);
            if (pb_craft_phase == 1) _cw_rows = array_length(_cw_cslots);
            if (pb_craft_phase == 2) _cw_rows = 3;
            if (pb_craft_phase == 3) {
                // ONLY blueprints unlocked for the chosen quality list here
                // (M-locked): tier >= quality; caster affixes only on jewelry.
                var _cw_cat = pattern_family_catalog();
                var _cw_slot = _cw_slots[clamp(pb_slot_pick, 0, array_length(_cw_slots) - 1)];
                var _cw_caster = (_cw_slot == "amulet" || _cw_slot == "ring");
                for (var _cfi = 0; _cfi < array_length(_cw_cat); _cfi++) {
                    var _cfe = _cw_cat[_cfi];
                    if (_cfe.kind == "school" && !_cw_caster) continue;
                    if (pattern_fam_tier(_cfe.stat_name) < 1 + pb_rar_pick) continue;
                    array_push(_cw_fams, _cfe);
                }
                _cw_rows = array_length(_cw_fams);
            }
            if (pb_craft_phase == 4) _cw_rows = 1 + array_length(pattern_art_for_slot(_cw_slots[clamp(pb_slot_pick, 0, array_length(_cw_slots) - 1)]));

            // NAMING phase (5): keyboard_string capture, forge phase-2 idiom.
            if (pb_craft_phase == 5) {
                // Cap 24 -> 72 (M 08-26: "at least 3x" - see forge phase 2 note).
                if (string_length(keyboard_string) > 72) keyboard_string = string_copy(keyboard_string, 1, 72);
                if (input_inject_take("pb:rand")) {
                    keyboard_string = pattern_name_roll(_cw_slots[pb_slot_pick], pb_base_stat, pb_affix_picks, pb_icon_entry);
                }
                // WEAPON OPTION CHIPS (M design-locked 08-26 parity): typing owns
                // the letters, so chips ride NON-CHARACTER keys - Tab toggles
                // TWO-HANDED (~+80% damage, locks the offhand; a chosen-school 2H
                // is a staff and keeps focus/tome offhands), Left/Right cycle a
                // ranged craft's damage school (Physical + the 8 schools). The
                // draw mirrors them as tap chips (pb:twoh / pb:school).
                var _cw_wslot  = _cw_slots[clamp(pb_slot_pick, 0, array_length(_cw_slots) - 1)];
                var _cw_is_wpn = (_cw_wslot == "weapon" || _cw_wslot == "ranged_weapon");
                if (_cw_is_wpn && (keyboard_check_pressed(vk_tab) || input_inject_take("pb:twoh"))) {
                    pb_opt_twoh = !pb_opt_twoh;
                    audio_play_sound(pb_opt_twoh ? snd_ui_toggle_on : snd_ui_toggle_off, 1, false);
                }
                if (_cw_wslot == "ranged_weapon") {
                    var _cw_schools = ability_school_list();          // 8 schools
                    var _cw_sv = 0;                                   // 0 = Physical, 1..8 = school index+1
                    for (var _cwsi = 0; _cwsi < array_length(_cw_schools); _cwsi++) {
                        if (_cw_schools[_cwsi] == pb_opt_school) { _cw_sv = _cwsi + 1; break; }
                    }
                    var _cw_dir = 0;
                    if (keyboard_check_pressed(vk_right) || input_inject_take("pb:school")) _cw_dir = 1;
                    else if (keyboard_check_pressed(vk_left)) _cw_dir = -1;
                    if (_cw_dir != 0) {
                        _cw_sv = (_cw_sv + _cw_dir + array_length(_cw_schools) + 1) mod (array_length(_cw_schools) + 1);
                        pb_opt_school = (_cw_sv == 0) ? "" : _cw_schools[_cw_sv - 1];
                        audio_play_sound(snd_ui_move, 1, false);
                    }
                }
                // Keyboard locked to the name field while typing (M 08-26, forge
                // phase-2 idiom): Backspace ONLY edits text - never backs out
                // (GM trims keyboard_string before Step, so an empty-field
                // backout misfires on the last letter). Esc / pad B back out.
                if (keyboard_check_pressed(vk_escape) || pad_pressed(gp_face2)) {
                    pb_craft_phase = 4; pb_cursor = 0; pb_scroll = 0; keyboard_string = "";
                    if (input_device() == 2) keyboard_virtual_hide();
                    exit;
                }
                if (keyboard_check_pressed(vk_enter) || input_inject_take("pb:ok")) {
                    var _cw_nm = string_trim(keyboard_string);
                    if (_cw_nm == "") exit;   // no nameless craftwork
                    pb_name = string_copy(_cw_nm, 1, 72);
                    var _cw_fee = pattern_craft_fee(1 + pb_rar_pick);
                    dorn_ck_open  = true;
                    dorn_ck_kind  = "pb_craft";
                    dorn_ck_title = "CRAFT " + string_upper(pb_name) + "?";
                    dorn_ck_body  = "A " + item_rarity_name(1 + pb_rar_pick) + " "
                        + item_slot_noun(_cw_slots[pb_slot_pick]) + " of your own design."
                        + "\nDorn asks " + string(_cw_fee.gold) + "g + " + string(_cw_fee.dust)
                        + " rune dust + 1 " + item_rarity_name(_cw_fee.ingot_rar) + "-tier (or higher) ingot"
                        + " + " + string(pattern_craft_reagents(1 + pb_rar_pick)) + " dungeon reagent"
                        + ((pattern_craft_reagents(1 + pb_rar_pick) == 1) ? "" : "s") + " (you hold: " + reagent_summary_text() + ")."
                        + "\nThe numbers roll inside your blueprints' bands.";
                    if (input_device() == 2) keyboard_virtual_hide();
                }
                exit;
            }

            // RESULT phase (6): reveal card - HONE the numbers or keep them
            // (M design-locked 08-26: HONE replaced the numbers-reroll, which
            // charged gold on bands that were often zero-width).
            if (pb_craft_phase == 6) {
                if (pb_result == undefined) { pb_craft_open = false; pb_craft_phase = 0; exit; }
                if (!variable_instance_exists(id, "pb_hone_pick")) pb_hone_pick = -1;
                // HONE list open: W/S pick a line, Enter buys +1, Esc closes.
                if (pb_hone_pick >= 0) {
                    var _hn_rows = pattern_hone_rows(pb_result);
                    var _hn_n    = array_length(_hn_rows);
                    if (_hn_n == 0) { pb_hone_pick = -1; exit; }
                    if (input_cancel() || input_back() || input_inject_take("pbhn:close")) { pb_hone_pick = -1; exit; }
                    if (nav_up())   pb_hone_pick = wrap_index(pb_hone_pick - 1, _hn_n);
                    if (nav_down()) pb_hone_pick = wrap_index(pb_hone_pick + 1, _hn_n);
                    for (var _hni = 0; _hni < _hn_n; _hni++) {
                        if (input_inject_take("pbhn:row" + string(_hni))) pb_hone_pick = _hni;
                    }
                    pb_hone_pick = clamp(pb_hone_pick, 0, _hn_n - 1);
                    if (input_confirm() || input_inject_take("pbhn:buy")) {
                        var _hn_fee = pattern_hone_fee(pb_result);
                        var _hn_row = _hn_rows[pb_hone_pick];
                        if (_hn_row.value >= _hn_row.cap) {
                            shop_notification = _hn_row.label + " is already at its mastery ceiling (+" + string(_hn_row.cap) + ").";
                            audio_play_sound(snd_ui_error, 1, false);
                        } else if (global.gold < _hn_fee) {
                            shop_notification = "Honing asks " + string(_hn_fee) + "g.";
                            audio_play_sound(snd_ui_error, 1, false);
                        } else if (pattern_craft_hone(pb_result, _hn_row.stat_name) == "") {
                            global.gold -= _hn_fee;
                            shop_notification = "";
                            audio_play_sound(snd_forge, 1, false);
                            ui_checkout_vfx(spr_vfx_impact, 960, 540);
                            save_game();
                        }
                    }
                    exit;
                }
                if (input_hotkey("R") || input_inject_take("pb:hone")) {
                    if (array_length(pattern_hone_rows(pb_result)) > 0) { pb_hone_pick = 0; shop_notification = ""; }
                    else {
                        shop_notification = "Nothing to hone - this piece carries no crafted affix lines.";
                        audio_play_sound(snd_ui_error, 1, false);
                    }
                    exit;
                }
                if (input_confirm() || input_cancel() || input_back() || input_inject_take("pb:done")) {
                    shop_notification = "Crafted " + pb_result.name + " - it waits in your stash.";
                    pb_craft_open = false; pb_craft_phase = 0; pb_result = undefined;
                }
                exit;
            }

            // List phases (0-4): shared nav + tap + edge-triggered scroll.
            if (input_cancel() || input_back()) {
                if (pb_craft_phase == 0)      { pb_craft_open = false; }
                else if (pb_craft_phase == 3) { pb_craft_phase = 2; pb_affix_picks = []; }
                else                          { pb_craft_phase -= 1; }
                pb_cursor = 0; pb_scroll = 0;
                exit;
            }
            // CONTINUE out of the blueprint phase with a PARTIAL pick (M-locked
            // 08-15 concentration): >= 1 pick, Space or the on-screen button
            // moves on; unused slots boost the chosen rolls.
            if (pb_craft_phase == 3 && array_length(pb_affix_picks) >= 1
                && (keyboard_check_pressed(vk_space) || input_inject_take("pb:cont"))) {
                pb_craft_phase = 4; pb_cursor = 0; pb_scroll = 0;
                exit;
            }
            if (_cw_rows > 0) {
                if (nav_up())   pb_cursor = wrap_index(pb_cursor - 1, _cw_rows);
                if (nav_down()) pb_cursor = wrap_index(pb_cursor + 1, _cw_rows);
                if (mouse_wheel_up())   pb_cursor = max(0, pb_cursor - 1);
                if (mouse_wheel_down()) pb_cursor = min(_cw_rows - 1, pb_cursor + 1);
            }
            var _cw_tap = -1;
            for (var _cwt = 0; _cwt < _cw_rows; _cwt++) {
                if (input_inject_take("pb:row" + string(_cwt))) { _cw_tap = _cwt; break; }
            }
            if (_cw_tap >= 0) pb_cursor = _cw_tap;
            pb_cursor = clamp(pb_cursor, 0, max(0, _cw_rows - 1));
            var _cw_vis = (pb_craft_phase == 3) ? 6 : 9;   // MUST mirror ui_draw_pattern_craft (phase-3 rows are taller: desc subrows)
            if (pb_cursor < pb_scroll)            pb_scroll = pb_cursor;
            if (pb_cursor >= pb_scroll + _cw_vis) pb_scroll = pb_cursor - (_cw_vis - 1);
            pb_scroll = clamp(pb_scroll, 0, max(0, _cw_rows - _cw_vis));

            if ((input_confirm() || _cw_tap >= 0) && _cw_rows > 0) {
                if (pb_craft_phase == 0) {
                    // Category: weapons / armor / jewelry.
                    pb_cat_pick = pb_cursor;
                    pb_craft_phase = 1; pb_cursor = 0; pb_scroll = 0;
                } else if (pb_craft_phase == 1) {
                    // Slot within the category -> map back to the forge_slot_list index.
                    var _cw_sid = _cw_cslots[clamp(pb_cursor, 0, array_length(_cw_cslots) - 1)].id;
                    for (var _cwsi = 0; _cwsi < array_length(_cw_slots); _cwsi++) {
                        if (_cw_slots[_cwsi] == _cw_sid) { pb_slot_pick = _cwsi; break; }
                    }
                    pb_craft_phase = 2; pb_cursor = 0; pb_scroll = 0;
                } else if (pb_craft_phase == 2) {
                    pb_rar_pick = pb_cursor;   // 0/1/2 -> rarity 1/2/3
                    pb_affix_picks = [];
                    pb_base_stat = "";   // derived from the picks at build (v2)
                    pb_craft_phase = 3; pb_cursor = 0; pb_scroll = 0;
                } else if (pb_craft_phase == 3) {
                    // Toggle the blueprint under the cursor (list is pre-filtered
                    // to quality-eligible). Full budget advances; a PARTIAL pick
                    // continues via Space / the CONTINUE button (concentration).
                    var _cw_fam = _cw_fams[pb_cursor].stat_name;
                    var _cw_had = false;
                    for (var _cwp = 0; _cwp < array_length(pb_affix_picks); _cwp++) {
                        if (pb_affix_picks[_cwp] == _cw_fam) {
                            array_delete(pb_affix_picks, _cwp, 1);
                            _cw_had = true;
                            break;
                        }
                    }
                    var _cw_budget = pattern_affix_budget(1 + pb_rar_pick);
                    if (!_cw_had) {
                        if (array_length(pb_affix_picks) >= _cw_budget) {
                            shop_notification = "A " + item_rarity_name(1 + pb_rar_pick) + " piece holds " + string(_cw_budget) + " pick" + ((_cw_budget == 1) ? "" : "s") + ".";
                            audio_play_sound(snd_ui_error, 1, false);
                        } else {
                            array_push(pb_affix_picks, _cw_fam);
                        }
                    }
                    if (array_length(pb_affix_picks) >= _cw_budget) {
                        pb_craft_phase = 4; pb_cursor = 0; pb_scroll = 0;
                    }
                } else if (pb_craft_phase == 4) {
                    var _cw_arts = pattern_art_for_slot(_cw_slots[pb_slot_pick]);
                    pb_icon_entry = (pb_cursor == 0) ? undefined : _cw_arts[pb_cursor - 1];
                    pb_craft_phase = 5; pb_cursor = 0; pb_scroll = 0;
                    keyboard_string = pattern_name_roll(_cw_slots[pb_slot_pick], pb_base_stat, pb_affix_picks, pb_icon_entry);
                    if (input_device() == 2) keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_words, false);
                }
            }
            exit;
        }

        if (reforge_stage > 0) {
            if (reforge_target == undefined) { reforge_stage = 0; exit; }
            if (reforge_stage == 1) {
                if (input_cancel() || input_back() || input_inject_take("reforge:back")) {
                    reforge_stage = 0; reforge_target = undefined;
                } else if (input_confirm() || input_inject_take("reforge:commit")) {
                    // Snapshot the item's OLD face for the before-card, then roll.
                    var _rb = reforge_target;
                    reforge_before = {
                        label: _rb.name,
                        rar:   variable_struct_exists(_rb, "rarity") ? clamp(_rb.rarity, 0, 4) : 0,
                        stat:  ui_item_stat_str(_rb),
                    };
                    if (reforge_is_recast) {
                        // LEGENDARY RECAST (M 07-28 legendary sinks): gold, not an
                        // ingot - the legendary becomes a DIFFERENT legendary.
                        var _rc_g = legendary_recast_cost();
                        if (global.gold < _rc_g) {
                            shop_notification = "Recasting a legendary asks " + string(_rc_g) + "g.";
                            audio_play_sound(snd_ui_error, 1, false);
                            reforge_stage = 0; reforge_target = undefined;
                        } else if (legendary_recast(_rb)) {
                            global.gold -= _rc_g;
                            reforge_spent_tier = -1;   // no ingot spent
                            audio_play_sound(snd_forge, 1, false);
                            affinity_add("dorn", 2);   // function-use drip (recast) - M 08-16
                            reforge_stage = 2; reforge_anim_t = 0;
                            if (room == rm_hub || room == rm_character_select) save_game();
                        } else {
                            shop_notification = "The forge refuses - nothing else to become.";
                            audio_play_sound(snd_ui_error, 1, false);
                            reforge_stage = 0; reforge_target = undefined;
                        }
                    } else if (chit_reforge_item(_rb)) {
                        reforge_spent_tier = reforge_ingot_spend(reforge_before.rar);
                        audio_play_sound(snd_forge, 1, false);
                        affinity_add("dorn", 2);   // function-use drip (rework) - M 08-16
                        reforge_stage = 2; reforge_anim_t = 0;
                        if (room == rm_hub || room == rm_character_select) save_game();
                    } else {
                        shop_notification = "That item has no affixes to rework.";
                        audio_play_sound(snd_ui_error, 1, false);
                        reforge_stage = 0; reforge_target = undefined;
                    }
                }
            } else if (reforge_stage == 2) {
                reforge_anim_t++;
                // Enter / tap skips straight to the reveal.
                if (input_confirm() || mouse_check_button_pressed(mb_left)) reforge_anim_t = max(reforge_anim_t, 90);
                if (reforge_anim_t >= 90) {
                    reforge_stage = 3;
                    audio_play_sound(snd_confirm_major, 1, false);
                    // Gigapack impact burst over the NEW card at the reveal (M 07-28).
                    ui_checkout_vfx(spr_vfx_impact, 1185, 540);
                }
            } else {   // stage 3: result shown
                reforge_anim_t++;   // keeps the reveal burst animating
                if (input_confirm() || input_cancel() || input_back() || input_inject_take("reforge:done")) {
                    shop_notification = reforge_is_recast
                        ? ("Dorn recast " + reforge_before.label + " into " + reforge_target.name + "!  (-" + string(legendary_recast_cost()) + "g)")
                        : ("Dorn reworked " + reforge_before.label + " into " + reforge_target.name
                            + "  (spent a " + item_rarity_name(reforge_spent_tier) + " ingot)");
                    reforge_stage = 0; reforge_target = undefined; reforge_before = undefined;
                    reforge_is_recast = false;
                }
            }
            exit;
        }

        if (input_cancel() || input_back()) {
            shop_open = -1; shop_tab = 0; shop_index = 0;
            reforge_index = 0; reforge_scroll = 0; shop_notification = "";
            exit;
        }

        // [G] / chip - strike a Mythril Frame; [V] / chip - open THE LEGENDARY
        // FORGE once all three components are held (M locked 07-28).
        if (input_hotkey("G") || input_inject_take("dorn:frame")) {
            dorn_ck_open  = true;
            dorn_ck_kind  = "frame";
            // 08-11 reword (M: still read as gibberish) - lead with FUNCTION
            // (buying 1 of the 3 forge parts), keep the lore name second.
            dorn_ck_title = "BUY DORN'S FORGE PART?";
            dorn_ck_body  = "The LEGENDARY FORGE takes 3 parts, one from each smith."
                + "\nDorn's part is the MYTHRIL FRAME: pay " + string(forge_frame_cost())
                + "g + 1 LEGENDARY Reforge Ingot."
                + "\nGet Maren's RUNEHEART CORE and Sable's QUINTESSENCE,"
                + "\nthen return here and press [V] to forge a custom legendary.";
            exit;
        }
        // [C] / chip - fuse 3 same-tier ingots into 1 of the next tier (M 07-29:
        // low-tier ingots' real role once rerolling commons stops being worth it).
        if (input_hotkey("C") || input_inject_take("dorn:combine")) {
            var _cmb = reforge_combine_tier();
            if (_cmb < 0) {
                shop_notification = "Fusing asks 3 Reforge Ingots of one tier (Legendary ingots don't fuse).";
                audio_play_sound(snd_ui_error, 1, false);
            } else {
                dorn_ck_open  = true;
                dorn_ck_kind  = "combine";
                dorn_ck_title = "FUSE INGOTS?";
                dorn_ck_body  = "3 " + item_rarity_name(_cmb) + " Reforge Ingots fuse into"
                    + "\n1 " + item_rarity_name(_cmb + 1) + " Reforge Ingot.";
            }
            exit;
        }
        if (input_hotkey("V") || input_inject_take("dorn:forge")) {
            if (forge_components_ready()) {
                forge_open = true; forge_phase = 0; forge_cursor = 0;
                shop_notification = "";
            } else {
                forge_components_ensure();
                shop_notification = "The LEGENDARY FORGE asks all three: Frame " + string(global.forge_comp_frame)
                    + " / Core " + string(global.forge_comp_core) + " / Quintessence " + string(global.forge_comp_quint) + ".";
                audio_play_sound(snd_ui_error, 1, false);
            }
            exit;
        }

        // ---- PATTERN BOOK verbs (08-11): [T] smelt, [B] book, [N] craft.
        if (input_hotkey("T") || input_inject_take("dorn:smelt")) {
            var _pb_cands = pattern_smelt_candidates();
            if (array_length(_pb_cands) == 0) {
                shop_notification = "Nothing unequipped to smelt - Uncommon to Epic gear feeds the book.";
                audio_play_sound(snd_ui_error, 1, false);
            } else {
                item_picker_open("pb_smelt", {}, _pb_cands);
                shop_notification = "";
            }
            exit;
        }
        if (input_hotkey("B") || input_inject_take("dorn:book")) {
            pb_book_open = true; pb_book_scroll = 0; pb_book_cursor = 0; shop_notification = "";
            exit;
        }
        if (input_hotkey("N") || input_inject_take("dorn:craft")) {
            pb_craft_open = true; pb_craft_phase = 0;
            pb_cursor = 0; pb_scroll = 0;
            pb_affix_picks = []; pb_icon_entry = undefined;
            pb_result = undefined; pb_name = "";
            pb_opt_twoh = false; pb_opt_school = ""; pb_hone_pick = -1;   // 08-26 chips + hone
            shop_notification = "";
            exit;
        }

        if (_rf_n > 0) {
            if (nav_up())   { reforge_index = wrap_index(reforge_index - 1, _rf_n); shop_notification = ""; }
            if (nav_down()) { reforge_index = wrap_index(reforge_index + 1, _rf_n); shop_notification = ""; }

            if (input_confirm()) {
                var _rc = _rf_list[reforge_index];
                var _rr = variable_struct_exists(_rc.item, "rarity") ? clamp(_rc.item.rarity, 0, 4) : 0;
                if (_rr >= 4) {
                    // LEGENDARY RECAST (M 07-28): gold-only, no ingot gate.
                    reforge_target = _rc.item; reforge_stage = 1;
                    reforge_is_recast = true;
                    reforge_anim_t = 0; shop_notification = "";
                } else {
                    var _rt = reforge_ingot_tier_for(_rr);   // -1 = no ingot of that tier or higher
                    if (_rt < 0) {
                        shop_notification = "No " + item_rarity_name(_rr) + "-tier (or higher) Reforge Ingot - smelting and the tavern board pay them.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        // Open the confirmation screen - nothing is spent or rolled yet.
                        reforge_target = _rc.item; reforge_stage = 1;
                        reforge_is_recast = false;
                        reforge_anim_t = 0; shop_notification = "";
                    }
                }
            }
        }

        // Edge-triggered scroll: the selector moves WITHIN the visible window and the
        // list only shifts once the cursor reaches the top/bottom edge (matches the Sell
        // list) - instead of pinning the cursor mid-window while rows slide under it.
        // 5 visible since 08-11: the Pattern Book verb row claimed the bottom band.
        var _rf_vis = 5;
        if (reforge_index < reforge_scroll)            reforge_scroll = reforge_index;
        if (reforge_index >= reforge_scroll + _rf_vis) reforge_scroll = reforge_index - (_rf_vis - 1);
        reforge_scroll = clamp(reforge_scroll, 0, max(0, _rf_n - _rf_vis));

        // Mouse: click a tab header to leave, or a gear row to select it (Enter reworks).
        // Row window MUST mirror ui_draw_dorn_reforge (5 visible, pitch 102, top y255).
        if (mouse_check_button_pressed(mb_left)) {
            var _rmx = device_mouse_x_to_gui(0);
            var _rmy = device_mouse_y_to_gui(0);
            var _rt_w = 320, _rt_gap = 24, _rt_n = shop_tab_count(shop_open);
            var _rt_x0 = 960 - (_rt_n * _rt_w + (_rt_n - 1) * _rt_gap) / 2;
            for (var _rti = 0; _rti < _rt_n; _rti++) {
                var _rtx = _rt_x0 + _rti * (_rt_w + _rt_gap);
                if (_rmx >= _rtx && _rmx < _rtx + _rt_w && _rmy >= 96 && _rmy < 138 && shop_tab != _rti) {
                    shop_tab = _rti; shop_notification = ""; sell_index = 0; sell_scroll = 0;
                }
            }
            if (_rf_n > 0) {
                var _rvis  = 5;
                var _rwin0 = clamp(reforge_scroll, 0, max(0, _rf_n - _rvis));
                var _rwin1 = min(_rf_n, _rwin0 + _rvis);
                for (var _rri = _rwin0; _rri < _rwin1; _rri++) {
                    var _rry = 255 + (_rri - _rwin0) * 102;
                    if (_rmx >= 642 && _rmx < 1488 && _rmy >= _rry && _rmy < _rry + 96) {
                        if (_rri == reforge_index) {
                            // Second tap on the selected row = Enter (opens the
                            // confirmation screen) - the touch path to rework.
                            var _rc2 = _rf_list[_rri];
                            var _rr2 = variable_struct_exists(_rc2.item, "rarity") ? clamp(_rc2.item.rarity, 0, 4) : 0;
                            if (_rr2 >= 4) {
                                reforge_target = _rc2.item; reforge_stage = 1;
                                reforge_is_recast = true;
                                reforge_anim_t = 0; shop_notification = "";
                            } else if (reforge_ingot_tier_for(_rr2) < 0) {
                                shop_notification = "No " + item_rarity_name(_rr2) + "-tier (or higher) Reforge Ingot - smelting and the tavern board pay them.";
                                audio_play_sound(snd_ui_error, 1, false);
                            } else {
                                reforge_target = _rc2.item; reforge_stage = 1;
                                reforge_is_recast = false;
                                reforge_anim_t = 0; shop_notification = "";
                            }
                        } else {
                            reforge_index = _rri; shop_notification = "";
                        }
                        break;
                    }
                }
            }
        }
        exit;
    }

    // =========================================================================
    // TEMPER TAB (Dorn only; shop_tab == 3). Moved off Maren's forge menu on
    // 08-08 - working rough metal toward its finish is smith work. Unlike the old
    // flow (a bare item_picker fired from a menu row) this is a real screen: the
    // list shows every rough piece with its quality, the step fee and whether you
    // can afford it, and the right panel PREVIEWS the exact before/after the step
    // will produce - so the player knows what they are buying before they buy it.
    // Geometry MUST mirror ui_draw_dorn_temper (scr_ui): 7 visible, pitch 90, y255.
    // =========================================================================
    if (shop_tab == 3 && shop_open == 1) {
        if (!variable_instance_exists(id, "temper_index")) { temper_index = 0; temper_scroll = 0; }
        var _tp_list = item_picker_candidates_temperable();
        var _tp_n    = array_length(_tp_list);
        var _tp_vis  = 7;

        if (_tp_n > 0) {
            if (nav_down()) temper_index = wrap_index(temper_index + 1, _tp_n);
            if (nav_up())   temper_index = wrap_index(temper_index - 1, _tp_n);
        }
        temper_index = clamp(temper_index, 0, max(0, _tp_n - 1));
        // Edge-triggered scroll, matching the Sell/Reforge lists.
        if (temper_index < temper_scroll)             temper_scroll = temper_index;
        if (temper_index >= temper_scroll + _tp_vis)  temper_scroll = temper_index - (_tp_vis - 1);
        temper_scroll = clamp(temper_scroll, 0, max(0, _tp_n - _tp_vis));

        var _tp_act = false;

        // Mouse/touch: tab headers, then rows (re-click on the selected row acts).
        if (mouse_check_button_pressed(mb_left)) {
            var _tmx = device_mouse_x_to_gui(0);
            var _tmy = device_mouse_y_to_gui(0);
            var _tt_w = 320, _tt_gap = 24, _tt_n = shop_tab_count(shop_open);
            var _tt_x0 = 960 - (_tt_n * _tt_w + (_tt_n - 1) * _tt_gap) / 2;
            for (var _tti = 0; _tti < _tt_n; _tti++) {
                var _ttx = _tt_x0 + _tti * (_tt_w + _tt_gap);
                if (_tmx >= _ttx && _tmx < _ttx + _tt_w && _tmy >= 96 && _tmy < 138 && shop_tab != _tti) {
                    shop_tab = _tti; shop_notification = ""; sell_index = 0; sell_scroll = 0;
                }
            }
            if (_tp_n > 0) {
                var _twin0 = clamp(temper_scroll, 0, max(0, _tp_n - _tp_vis));
                var _twin1 = min(_tp_n, _twin0 + _tp_vis);
                for (var _tri = _twin0; _tri < _twin1; _tri++) {
                    var _try = 255 + (_tri - _twin0) * 90;
                    if (_tmx >= 60 && _tmx < 900 && _tmy >= _try && _tmy < _try + 84) {
                        if (_tri == temper_index) _tp_act = true;
                        else { temper_index = _tri; shop_notification = ""; }
                    }
                }
                // The confirm bar under the preview panel is a tap target too.
                if (_tmx >= 940 && _tmx < 1860 && _tmy >= 906 && _tmy < 960) _tp_act = true;
            }
        }
        if (input_confirm() || input_confirm_alt()) _tp_act = true;

        if (_tp_act && _tp_n > 0) {
            var _tp_row = _tp_list[clamp(temper_index, 0, _tp_n - 1)];
            var _tp_it  = _tp_row.item;
            var _tp_fee = temper_fee(_tp_it);
            if (!variable_global_exists("rune_dust")) global.rune_dust = 0;
            if (global.gold < _tp_fee.gold || global.rune_dust < _tp_fee.dust) {
                shop_notification = "Not enough - Dorn asks " + string(_tp_fee.gold) + "g + "
                    + string(_tp_fee.dust) + " rune dust for that step.";
                audio_play_sound(snd_ui_error, 1, false);
            } else {
                global.gold      -= _tp_fee.gold;
                global.rune_dust -= _tp_fee.dust;
                // Snapshot BEFORE mutating - the reveal popup runs after (M 08-08).
                var _tp_was = item_shallow_copy(_tp_it);
                _tp_it.quality = min(100, (variable_struct_exists(_tp_it, "quality") ? _tp_it.quality : 100) + ((npc_rank("dorn") >= 2) ? 12 : 10));   // Master Anvil rank perk (08-15)
                // No icon_seed re-roll (M 08-11): tempering never changes a piece's look.
                affinity_add("dorn", 2);   // function-use drip (temper step) - M 08-16
                save_game();
                shop_notification = _tp_it.name + " tempered to " + string(_tp_it.quality) + "%"
                    + ((_tp_it.quality >= 100) ? " - FINISHED." : ".");
                forge_result_open("TEMPERED", (_tp_it.quality >= 100)
                        ? "The metal finally sings its whole note."
                        : "Closer to what it was always meant to be.",
                    _tp_it, _tp_was, [], make_color_rgb(200, 170, 110));
                audio_play_sound(snd_forge, 1, false);
                // A piece that just hit 100% leaves the list - keep the cursor in range.
                temper_index = clamp(temper_index, 0, max(0, array_length(item_picker_candidates_temperable()) - 1));
            }
        }

        if (input_cancel() || input_back() || mouse_check_button_pressed(mb_right)) {
            shop_open = -1; shop_tab = 0; shop_index = 0;
            shop_notification = ""; temper_index = 0; temper_scroll = 0;
        }
        exit;
    }

    // =========================================================================
    // TREASURE TRADER TAB (Petra only; shop_tab == 2). Async gear laundering -
    // 3 same-tier items -> 1 of the next tier, earned by clearing floors. Reads/
    // writes global.petra_order. Logic lives in scr_stats (PETRA_TT_PHASE1_SPEC.md).
    // =========================================================================
    if (shop_tab == 2 && shop_open == 0) {
        // Rune-blueprint mode state (M 07-27 distributed rune economy). Mode 0 =
        // the original 3-gear trade; mode 1 = trade 5 same-tier runes for a CHOSEN
        // rune blueprint order. Draw = the trade tab in scr_ui (mode chip + rows
        // hit-test THERE, injecting petra:* tags consumed below - touch rule).
        if (!variable_instance_exists(id, "petra_trade_mode")) {
            petra_trade_mode = 0; petra_rune_phase = 0; petra_rune_sel = [];
            petra_rune_cursor = 0; petra_rune_scroll = 0;
            petra_rune_result_cursor = 0; petra_rune_result_scroll = 0;
            petra_reveal_open = false;
        }
        // Reagent-swap mode state (M-locked 08-26): give/get picks + checkout arm.
        if (!variable_instance_exists(id, "petra_rg_phase")) {
            petra_rg_phase = 0; petra_rg_give = 0; petra_rg_get = 1; petra_rg_ck = false;
        }

        // --- ORDER REVEAL popup (M 07-28: the yield vanished into a stash stack -
        // now it's EXAMINED before it goes). Modal: Enter/Esc/DONE closes.
        if (petra_reveal_open) {
            if (input_confirm() || input_cancel() || input_back() || input_inject_take("petra:revealdone")) {
                petra_reveal_open   = false;
                global.petra_reveal = undefined;
            }
            exit;
        }

        // Esc/Backspace: cancel a pending confirm first, then step back a rune
        // phase (result-pick -> rune-pick), then back out of place-another mode
        // to the ledger view, else close the shop.
        if (!variable_instance_exists(id, "petra_place_more")) petra_place_more = false;
        if (input_cancel() || input_back()) {
            if (petra_trade_confirm) {
                petra_trade_confirm      = false;
                petra_trade_notification = "";
            } else if (petra_trade_mode == 2 && petra_rg_ck) {
                petra_rg_ck = false; petra_trade_notification = "";
            } else if (petra_trade_mode == 2 && petra_rg_phase == 1) {
                petra_rg_phase = 0; petra_trade_notification = "";
            } else if (petra_trade_mode == 1 && petra_rune_phase == 1) {
                petra_rune_phase = 0; petra_trade_notification = "";
            } else if (petra_place_more && petra_order_active()) {
                petra_place_more = false; petra_trade_notification = "";
            } else {
                shop_open = -1; shop_tab = 0; shop_index = 0;
                sell_index = 0; sell_scroll = 0; sell_confirm_name = "";
                shop_notification = ""; petra_trade_notification = "";
                petra_trade_mode = 0; petra_rune_phase = 0; petra_rune_sel = [];
                petra_place_more = false;
            }
            exit;
        }

        // --- THE LEDGER VIEW (two-order refactor 08-15): orders exist and we're
        // not placing another. Enter collects the first READY order; Space (or
        // the button) opens the trade UI while a second line is free at rank 1;
        // C cancels the NEWEST order (two-step confirm).
        if (petra_order_active() && !petra_place_more) {
            var _po_ready = false;
            for (var _poi = 0; _poi < array_length(global.petra_orders); _poi++) {
                if (global.petra_orders[_poi].status == "ready") { _po_ready = true; break; }
            }
            if (_po_ready && (input_confirm() || input_inject_take("petra:collect"))) {
                petra_trade_notification = petra_collect();
                petra_trade_confirm = false;
                // The reveal moment (matching Dorn's forge reveal): burst + the
                // examine popup (petra_collect stocked global.petra_reveal).
                audio_play_sound(snd_confirm_major, 1, false);
                ui_checkout_vfx(spr_vfx_arcane, 960, 460);   // Gigapack collect burst
                petra_collect_time = current_time;
                if (variable_global_exists("petra_reveal") && global.petra_reveal != undefined) {
                    petra_reveal_open = true;
                }
            }
            if (petra_order_can_place()
                && (input_confirm_alt() || input_inject_take("petra:more"))) {
                petra_place_more = true;
                petra_trade_confirm = false; petra_trade_notification = "";
                audio_play_sound(snd_page, 1, false);
            }
            // C cancels the newest order (two-step confirm).
            if (input_hotkey("C")) {
                var _po_last = global.petra_orders[array_length(global.petra_orders) - 1];
                if (_po_last.status == "ready") {
                    petra_trade_notification = "That order is READY - collect it instead.";
                } else if (!petra_trade_confirm) {
                    petra_trade_confirm = true;
                    petra_trade_notification = "Cancel the "
                        + ((array_length(global.petra_orders) > 1) ? "NEWEST order" : "order")
                        + "? You may recover only some inputs - gold is NOT refunded.  C: confirm   Esc: keep";
                } else {
                    petra_trade_confirm = false;
                    petra_trade_notification = petra_cancel_order();
                }
            }
            exit;
        }

        // --- No order: [R] / mode chip cycles GEAR -> RUNES -> REAGENTS (08-26) ---
        if (input_hotkey("R") || input_inject_take("petra:mode")) {
            petra_trade_mode = (petra_trade_mode + 1) mod 3;
            petra_rune_phase = 0; petra_rune_sel = [];
            petra_rune_cursor = 0; petra_rune_scroll = 0;
            petra_rg_phase = 0; petra_rg_ck = false;
            petra_trade_confirm = false; petra_trade_notification = "";
            exit;
        }

        // --- REAGENT SWAP MODE (M-locked 08-26): give N of one type for M of
        // another (petra_reagent_trade_terms: 2->1, Petra rank 2+ 3->2). Column
        // 0 = GIVE, column 1 = RECEIVE (petra_rg_phase); the standard checkout
        // popup confirms the spend (07-27 rule). Draw injects petra:rg* tags.
        if (petra_trade_mode == 2) {
            var _rgc = reagent_catalog();
            var _rgn = array_length(_rgc);
            var _rgt = petra_reagent_trade_terms();
            // Checkout popup owns input while armed (Esc handled in the shared
            // cancel block above; buttons inject rgok/rgcancel).
            if (petra_rg_ck) {
                if (input_inject_take("petra:rgcancel")) { petra_rg_ck = false; exit; }
                if (input_confirm() || input_inject_take("petra:rgok")) {
                    petra_rg_ck = false;
                    var _gv = _rgc[clamp(petra_rg_give, 0, _rgn - 1)];
                    var _gt = _rgc[clamp(petra_rg_get,  0, _rgn - 1)];
                    if (reagent_count(_gv.id) < _rgt.give || _gv.id == _gt.id) {
                        petra_trade_notification = "Need " + string(_rgt.give) + " " + _gv.name + " - you hold " + string(reagent_count(_gv.id)) + ".";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        reagent_add(_gv.id, -_rgt.give);
                        reagent_add(_gt.id,  _rgt.get);
                        affinity_add("petra", 2);   // function-use drip (reagent swap)
                        petra_trade_notification = "Traded " + string(_rgt.give) + " " + _gv.name
                            + " for " + string(_rgt.get) + " " + _gt.name + " - you hold " + string(reagent_count(_gt.id)) + ".";
                        audio_play_sound(snd_buy, 1, false);
                        ui_checkout_vfx(spr_vfx_gain, 960, 500);
                        petra_rg_phase = 0;
                        if (room == rm_hub || room == rm_character_select) save_game();
                    }
                }
                exit;
            }
            // Row taps set the pick AND focus that column (draw injects them).
            for (var _rgi = 0; _rgi < _rgn; _rgi++) {
                if (input_inject_take("petra:rggive" + string(_rgi))) { petra_rg_give = _rgi; petra_rg_phase = 0; }
                if (input_inject_take("petra:rgget"  + string(_rgi))) { petra_rg_get  = _rgi; petra_rg_phase = 1; }
            }
            // A/D switch column, W/S move within it (two-column idiom).
            if (nav_left())  petra_rg_phase = 0;
            if (nav_right()) petra_rg_phase = 1;
            if (petra_rg_phase == 0) {
                if (nav_up())   petra_rg_give = wrap_index(petra_rg_give - 1, _rgn);
                if (nav_down()) petra_rg_give = wrap_index(petra_rg_give + 1, _rgn);
            } else {
                if (nav_up())   petra_rg_get = wrap_index(petra_rg_get - 1, _rgn);
                if (nav_down()) petra_rg_get = wrap_index(petra_rg_get + 1, _rgn);
            }
            // Enter / TRADE button: advance GIVE -> RECEIVE, then arm the checkout.
            if (input_confirm() || input_inject_take("petra:rgtrade")) {
                var _gvp = _rgc[clamp(petra_rg_give, 0, _rgn - 1)];
                if (reagent_count(_gvp.id) < _rgt.give) {
                    petra_trade_notification = "Need " + string(_rgt.give) + " " + _gvp.name
                        + " to trade - you hold " + string(reagent_count(_gvp.id)) + ".";
                    audio_play_sound(snd_ui_error, 1, false);
                } else if (petra_rg_phase == 0) {
                    petra_rg_phase = 1;
                    if (petra_rg_get == petra_rg_give) petra_rg_get = (petra_rg_give + 1) mod _rgn;
                    petra_trade_notification = "";
                } else if (petra_rg_get == petra_rg_give) {
                    petra_trade_notification = "Pick a DIFFERENT reagent to receive.";
                    audio_play_sound(snd_ui_error, 1, false);
                } else {
                    petra_rg_ck = true;   // checkout popup (drawn topmost in scr_ui)
                }
            }
            exit;
        }

        // --- RUNE BLUEPRINT MODE: pick 5 same-tier runes, then choose the result ---
        if (petra_trade_mode == 1) {
            rune_inventory_sort();
            var _pr_inv = variable_global_exists("rune_inventory") ? global.rune_inventory : [];
            if (petra_rune_phase == 0) {
                var _pr_n = array_length(_pr_inv);
                // Draw-side row taps inject an absolute index.
                var _pr_tap = -1;
                for (var _pi = 0; _pi < _pr_n; _pi++) {
                    if (input_inject_take("petra:runerow" + string(_pi))) { _pr_tap = _pi; break; }
                }
                if (_pr_tap >= 0) petra_rune_cursor = _pr_tap;
                if (_pr_n > 0) {
                    if (nav_up())   petra_rune_cursor = wrap_index(petra_rune_cursor - 1, _pr_n);
                    if (nav_down()) petra_rune_cursor = wrap_index(petra_rune_cursor + 1, _pr_n);
                    petra_rune_cursor = clamp(petra_rune_cursor, 0, _pr_n - 1);
                    if (petra_rune_cursor < petra_rune_scroll)      petra_rune_scroll = petra_rune_cursor;
                    if (petra_rune_cursor >= petra_rune_scroll + 8) petra_rune_scroll = petra_rune_cursor - 7;

                    // Enter (or a row tap) toggles the pick - max 5, all same tier.
                    if (input_confirm() || _pr_tap >= 0) {
                        var _pci   = petra_rune_cursor;
                        var _pfound = -1;
                        for (var _psi = 0; _psi < array_length(petra_rune_sel); _psi++) {
                            if (petra_rune_sel[_psi] == _pci) { _pfound = _psi; break; }
                        }
                        if (_pfound >= 0) {
                            array_delete(petra_rune_sel, _pfound, 1);
                            petra_trade_notification = "";
                        } else if (array_length(petra_rune_sel) >= 5) {
                            petra_trade_notification = "Already chose 5 - deselect one first (Enter).";
                        } else if (array_length(petra_rune_sel) > 0
                            && _pr_inv[petra_rune_sel[0]].tier != _pr_inv[_pci].tier) {
                            petra_trade_notification = "All 5 runes must share a tier.";
                        } else {
                            array_push(petra_rune_sel, _pci);
                            petra_trade_notification = "";
                        }
                    }
                }
                // Space / the CHOOSE button: with 5 picked, move to the result pick.
                if (input_confirm_alt() || input_inject_take("petra:runego")) {
                    if (array_length(petra_rune_sel) != 5) {
                        petra_trade_notification = "Select 5 same-tier runes first (Enter to toggle).";
                    } else {
                        petra_rune_phase = 1;
                        petra_rune_result_cursor = 0; petra_rune_result_scroll = 0;
                        petra_trade_notification = "";
                    }
                }
            } else {
                // Phase 1: choose the blueprint (any non-flagship catalog rune, at
                // the picked tier). Enter/tap arms the checkout POPUP (M 07-27
                // standing rule); while armed the list is modal-locked.
                var _bp_pool = rune_blueprint_pool();
                var _bp_n    = array_length(_bp_pool);
                var _bp_tier = (array_length(petra_rune_sel) > 0 && petra_rune_sel[0] < array_length(_pr_inv))
                    ? _pr_inv[petra_rune_sel[0]].tier : 1;

                if (petra_trade_confirm) {
                    // MODAL: only place or cancel (popup buttons / Enter; Esc is
                    // handled by the shared cancel block at the top).
                    if (input_inject_take("petra:cancelbp")) {
                        petra_trade_confirm = false; petra_trade_notification = "";
                    } else if (input_confirm() || input_inject_take("petra:placebp")) {
                        petra_trade_confirm = false;
                        var _bp_res = petra_start_rune_order(petra_rune_sel, _bp_pool[petra_rune_result_cursor]);
                        if (_bp_res == "") {
                            petra_trade_notification = "Blueprint order placed! Earn it by clearing floors.";
                            audio_play_sound(snd_npc_confirm, 1, false);
                            petra_rune_sel = []; petra_rune_phase = 0;
                            petra_place_more = false;   // back to the ledger view
                        } else {
                            petra_trade_notification = _bp_res;
                            audio_play_sound(snd_ui_error, 1, false);
                        }
                    }
                    exit;
                }

                var _bp_tap  = -1;
                for (var _bi = 0; _bi < _bp_n; _bi++) {
                    if (input_inject_take("petra:runeres" + string(_bi))) { _bp_tap = _bi; break; }
                }
                if (_bp_tap >= 0 && _bp_tap != petra_rune_result_cursor) {
                    petra_rune_result_cursor = _bp_tap;
                }
                if (nav_up())   petra_rune_result_cursor = wrap_index(petra_rune_result_cursor - 1, _bp_n);
                if (nav_down()) petra_rune_result_cursor = wrap_index(petra_rune_result_cursor + 1, _bp_n);
                petra_rune_result_cursor = clamp(petra_rune_result_cursor, 0, max(0, _bp_n - 1));
                if (petra_rune_result_cursor < petra_rune_result_scroll)      petra_rune_result_scroll = petra_rune_result_cursor;
                if (petra_rune_result_cursor >= petra_rune_result_scroll + 8) petra_rune_result_scroll = petra_rune_result_cursor - 7;

                if (input_confirm() || (_bp_tap >= 0 && _bp_tap == petra_rune_result_cursor)) {
                    petra_trade_confirm = true;   // popup drawn by the trade-tab draw
                    petra_trade_notification = "";
                }
            }
            exit;
        }

        // --- No order: choose 3 same-tier stash items, then place ---
        var _stash_n = array_length(global.equipment_stash);

        // PLACE-ORDER POPUP (M 07-08 redesign): the roll treatment is chosen here,
        // AFTER the 3 inputs - W/S (or Tab) flips Standard <-> Roll-bias, Enter or
        // Space confirms and places, Esc cancels (the shop Esc handler above clears
        // petra_trade_confirm). Geometry lives in the scr_ui trade-tab popup.
        if (petra_trade_confirm) {
            // Draw-side taps: lever rows + the CONFIRM button (petra:* tags).
            if (input_inject_take("petra:lever0")) petra_trade_lever = false;
            if (input_inject_take("petra:lever1")) petra_trade_lever = true;
            if (nav_up() || nav_down() || input_detail()) petra_trade_lever = !petra_trade_lever;
            if (input_confirm() || input_confirm_alt() || input_inject_take("petra:place")) {
                var _res = petra_place_order(petra_trade_selected, petra_trade_lever);
                if (_res == "") {
                    petra_trade_notification = "Order placed! Earn it by clearing floors.";
                    petra_trade_selected = [];
                    audio_play_sound(snd_npc_confirm, 1, false);
                    petra_place_more = false;   // back to the ledger view
                }
                else            { petra_trade_notification = _res; }
                petra_trade_confirm = false;
            }
            exit;
        }

        // Navigate the stash list (windowed to 8 rows).
        if (_stash_n > 0) {
            if (nav_up())   petra_trade_cursor = wrap_index(petra_trade_cursor - 1, _stash_n);
            if (nav_down()) petra_trade_cursor = wrap_index(petra_trade_cursor + 1, _stash_n);
            petra_trade_cursor = clamp(petra_trade_cursor, 0, _stash_n - 1);
            if (petra_trade_cursor < petra_trade_scroll)      petra_trade_scroll = petra_trade_cursor;
            if (petra_trade_cursor >= petra_trade_scroll + 8) petra_trade_scroll = petra_trade_cursor - 7;
        }

        // (The Tab roll-bias lever moved INTO the place-order popup above - the
        // always-on toggle was easy to miss and its notification overlapped the
        // instruction line; M 07-08.)

        // Row taps (drawn + hit-tested in the trade-tab draw) select-and-toggle.
        var _pg_tap = -1;
        for (var _pgi = 0; _pgi < _stash_n; _pgi++) {
            if (input_inject_take("petra:gearrow" + string(_pgi))) { _pg_tap = _pgi; break; }
        }
        if (_pg_tap >= 0) petra_trade_cursor = _pg_tap;

        // Enter (or a row tap) toggles selection of the highlighted item (max 3, all same tier).
        if ((input_confirm() || _pg_tap >= 0) && _stash_n > 0) {
            var _ci    = petra_trade_cursor;
            var _found = -1;
            for (var _si = 0; _si < array_length(petra_trade_selected); _si++) {
                if (petra_trade_selected[_si] == _ci) { _found = _si; break; }
            }
            if (_found >= 0) {
                array_delete(petra_trade_selected, _found, 1);
                petra_trade_notification = "";
            } else if (array_length(petra_trade_selected) >= 3) {
                petra_trade_notification = "Already chose 3 - deselect one first (Enter).";
            } else {
                var _it = global.equipment_stash[_ci];
                var _r  = (is_struct(_it) && variable_struct_exists(_it, "rarity")) ? _it.rarity : -1;
                var _same = true;
                if (array_length(petra_trade_selected) > 0) {
                    var _first = global.equipment_stash[petra_trade_selected[0]];
                    var _fr    = (is_struct(_first) && variable_struct_exists(_first, "rarity")) ? _first.rarity : -1;
                    _same = (_r == _fr);
                }
                if (petra_ladder_for(_r) == undefined) {
                    petra_trade_notification = item_rarity_name(_r) + " items can't be traded up.";
                } else if (!_same) {
                    petra_trade_notification = "All 3 items must be the same tier.";
                } else {
                    array_push(petra_trade_selected, _ci);
                    petra_trade_notification = "";
                }
            }
        }

        // Space (or the PLACE ORDER button): when 3 are chosen, open the preview.
        if (input_confirm_alt() || input_inject_take("petra:placeopen")) {
            if (array_length(petra_trade_selected) != 3) {
                petra_trade_notification = "Select 3 same-tier items first (Enter to toggle).";
            } else {
                var _r2    = global.equipment_stash[petra_trade_selected[0]].rarity;
                var _rung2 = petra_ladder_for(_r2);
                if (_rung2 == undefined) {
                    petra_trade_notification = item_rarity_name(_r2) + " items can't be traded up.";
                } else {
                    // Open the place-order popup (details + roll-treatment choice
                    // are drawn there; default = standard roll).
                    petra_trade_notification = "";
                    petra_trade_lever   = false;
                    petra_trade_confirm = true;
                }
            }
        }
        exit;
    }

    // =========================================================================
    // BUY TAB (original buy logic - unchanged)
    // =========================================================================
    var _is_petra = (shop_open == 0);

    if (_is_petra) {
        // Unified buy list: consumables (+special) then pet feeds. Row indices match the draw.
        var _buy_list = petra_buy_list();
        var _buy_n    = array_length(_buy_list);

        if (nav_up())   { shop_index = wrap_index(shop_index - 1, _buy_n); shop_notification = ""; }
        if (nav_down()) { shop_index = wrap_index(shop_index + 1, _buy_n); shop_notification = ""; }
        shop_index = clamp(shop_index, 0, _buy_n - 1);

        // Edge-triggered scroll (vis 9): cursor moves within the window; the list only
        // shifts when the cursor hits the top/bottom edge (matches Sell / Reforge).
        var _buy_vis = 9;
        if (shop_index < buy_scroll)             buy_scroll = shop_index;
        if (shop_index >= buy_scroll + _buy_vis) buy_scroll = shop_index - (_buy_vis - 1);
        buy_scroll = clamp(buy_scroll, 0, max(0, _buy_n - _buy_vis));

        if (input_confirm()) {
            var _entry  = _buy_list[shop_index];
            var _sprice = _entry.price;
            if (global.gold < _sprice) {
                shop_notification = "Not enough gold!";
                audio_play_sound(snd_ui_error, 1, false);
            } else if (_entry.kind == "feed") {
                // Pet feed -> feed pouch (applied later at Bairc).
                global.gold -= _sprice;
                pet_feed_pouch_add(_entry.it.id, 1);
                affinity_add("petra", 2);
                audio_play_sound(snd_buy, 1, false);
                shop_notification = _entry.it.name + " added to your feed pouch (Bairc feeds it).";
                if (room == rm_hub || room == rm_character_select) save_game();
            } else if (_entry.kind == "reagent") {
                // Limited RNG reagent lot (M-locked 08-26): one per press.
                global.gold -= _sprice;
                reagent_add(_entry.it.id, 1);
                global.petra_reagent_stock[_entry.stock_idx].qty -= 1;
                affinity_add("petra", 2);
                audio_play_sound(snd_buy, 1, false);
                shop_notification = _entry.it.name + " purchased - you hold " + string(reagent_count(_entry.it.id)) + ".";
                // A sold-out lot drops from the list - keep the cursor in range.
                shop_index = min(shop_index, max(0, array_length(petra_buy_list()) - 1));
                if (room == rm_hub || room == rm_character_select) save_game();
            } else {
                // Consumable (standard or limited special).
                var _sit = _entry.it;
                global.gold -= _sprice;
                var _fresh = create_consumable(_sit.name, _sit.effect_type, _sit.effect_value,
                                               _sit.description, _sit.gold_value);
                array_push(global.consumable_stash, _fresh);
                affinity_add("petra", 2);   // function-use drip (consumable buy)
                if (_entry.special) {
                    global.petra_special_qty--;
                    if (global.petra_special_qty <= 0) {
                        global.petra_stock_special = undefined;
                        global.petra_special_qty   = 0;
                        shop_index = min(shop_index, array_length(petra_buy_list()) - 1);
                    }
                }
                audio_play_sound(snd_buy, 1, false);
                shop_notification = "Purchased - added to consumable stash.";
                // Persist the purchase (gold spent + new consumable) right away.
                if (room == rm_hub || room == rm_character_select) save_game();
            }
        }

    } else {
        // Dorn
        var _dorn_len = array_length(global.dorn_stock);

        if (nav_up()) {
            shop_notification = "";
            var _prev = shop_index - 1;
            while (_prev >= 0 && global.dorn_stock[_prev].sold) _prev--;
            if (_prev >= 0) shop_index = _prev;
        }
        if (nav_down()) {
            shop_notification = "";
            var _next = shop_index + 1;
            while (_next < _dorn_len && global.dorn_stock[_next].sold) _next++;
            if (_next < _dorn_len) shop_index = _next;
        }

        if ((input_confirm()) && _dorn_len > 0
            && !global.dorn_stock[shop_index].sold) {
            var _dentry = global.dorn_stock[shop_index];
            var _dprice = cha_price(_dentry.price);
            if (global.gold >= _dprice) {
                global.gold -= _dprice;
                array_push(global.equipment_stash, _dentry.item);
                affinity_add("dorn", 2);   // function-use drip (gear buy)
                discover_item(item_base_name(_dentry.item), _dentry.item.rarity);
                global.dorn_stock[shop_index].sold = true;
                audio_play_sound(snd_buy, 1, false);
                shop_notification = "Purchased - added to equipment stash.";
                // Persist the purchase (gold spent + new gear) right away.
                if (room == rm_hub || room == rm_character_select) save_game();
                // Advance cursor to next non-sold item
                var _nx = shop_index + 1;
                while (_nx < _dorn_len && global.dorn_stock[_nx].sold) _nx++;
                if (_nx < _dorn_len) {
                    shop_index = _nx;
                } else {
                    var _pv = shop_index - 1;
                    while (_pv >= 0 && global.dorn_stock[_pv].sold) _pv--;
                    if (_pv >= 0) shop_index = _pv;
                }
            } else {
                shop_notification = "Not enough gold!";
                audio_play_sound(snd_ui_error, 1, false);
            }
        }
    }

    if (input_back() || input_cancel()) {
        shop_open         = -1;
        shop_tab          = 0;
        shop_index        = 0;
        sell_index        = 0;
        sell_scroll       = 0;
        sell_confirm_name = "";
        shop_notification = "";
    }

    // Mouse: tab switch and row selection
    if (mouse_check_button_pressed(mb_left)) {
        var _shmx = device_mouse_x_to_gui(0);
        var _shmy = device_mouse_y_to_gui(0);
        // Tab clicks (auto-centred to match the draw side). Both shops have 3 tabs.
        var _mt_n   = shop_tab_count(shop_open);
        var _mt_w   = 320;
        var _mt_gap = 24;
        var _mt_x0  = 960 - (_mt_n * _mt_w + (_mt_n - 1) * _mt_gap) / 2;
        for (var _mti = 0; _mti < _mt_n; _mti++) {
            var _mtx = _mt_x0 + _mti * (_mt_w + _mt_gap);
            if (_shmx >= _mtx && _shmx < _mtx + _mt_w && _shmy >= 96 && _shmy < 138 && shop_tab != _mti) {
                shop_tab = _mti;
                sell_index = 0; sell_scroll = 0; sell_confirm_name = ""; shop_notification = "";
                petra_trade_confirm = false; petra_trade_selected = []; petra_trade_notification = "";
            }
        }
        // Row clicks - select cursor only (Enter buys/sells)
        if (shop_tab == 0) {
            if (shop_open == 0) {
                // Petra: COMPACT windowed rows (87px + 6 gap, 8 visible) covering the FULL
                // buy list incl. feeds. Audit fix 2026-07-03: the old hit-test only spanned
                // the 4-5 consumable rows at Dorn's 126px pitch, so feed rows misclicked.
                var _shp_n    = array_length(petra_buy_list());
                var _shp_vis  = min(9, _shp_n);
                var _shp_win0 = (_shp_n > 9) ? clamp(buy_scroll, 0, max(0, _shp_n - 9)) : 0;
                for (var _shri = 0; _shri < _shp_vis; _shri++) {
                    var _shry = 189 + _shri * 90;
                    if (_shmx >= 150 && _shmx < 1500 && _shmy >= _shry && _shmy < _shry + 84) {
                        shop_index = _shp_win0 + _shri; shop_notification = ""; break;
                    }
                }
            } else {
                var _shrows = array_length(global.dorn_stock);
                for (var _shri = 0; _shri < _shrows; _shri++) {
                    var _shry = 189 + _shri * 126;
                    if (_shmx >= 150 && _shmx < 1770 && _shmy >= _shry && _shmy < _shry+117) {
                        shop_index = _shri; shop_notification = ""; break;
                    }
                }
            }
        }
        if (shop_tab == 1) {
            var _shslcnt = array_length(global.equipment_stash) + array_length(global.consumable_stash)
                         + array_length(global.carried_items) + array_length(global.consumable_inventory);
            var _shvend  = min(sell_scroll + shop_sell_visible_rows(), _shslcnt);
            for (var _shri = sell_scroll; _shri < _shvend; _shri++) {
                var _shry = 189 + (_shri - sell_scroll) * 126;
                if (_shmx >= 150 && _shmx < 1770 && _shmy >= _shry && _shmy < _shry+117) {
                    sell_index = _shri; sell_confirm_name = ""; shop_notification = ""; break;
                }
            }
        }
    }

    exit;
}

// =============================================================================
// TRAINER INPUT (Vex) - runs before the menu_open guard. Six sections:
//   tab 0 Stats   tab 1 Trait Slots   tab 2 Abilities   tab 3 Traits
//   tab 4 Potency   tab 5 Reweave (talent-web respec)
// =============================================================================
if (trainer_open && !menu_open && !forge_result_up()
    && npc_tour_step < 0) {   // I menu owns input while open (see shop block); tour too
    var _tr_class = variable_global_exists("chosen_class") ? global.chosen_class : 0;

    // --- Tab: examine the highlighted ability (tab 2) or trait (tab 3) before buying.
    if (vex_detail_open) {
        if (input_detail() || input_cancel()) vex_detail_open = false;
        // Scroll audit (M 08-13): this popup showed a scrollbar but the early
        // `exit` ate W/S and the wheel - same defect as combat's V popup.
        var _vd_max = variable_global_exists("ui_ability_detail_max_scroll")
                    ? global.ui_ability_detail_max_scroll : 0;
        if (nav_down() || mouse_wheel_down()) vex_detail_scroll = clamp(vex_detail_scroll + 48, 0, _vd_max);
        if (nav_up()   || mouse_wheel_up())   vex_detail_scroll = clamp(vex_detail_scroll - 48, 0, _vd_max);
        exit;
    }
    if (input_detail()) {
        if (trainer_tab == 2 && trainer_cursor < array_length(class_vex_purchasable(_tr_class))) {
            vex_detail_open = true; vex_detail_scroll = 0; exit;
        } else if (trainer_tab == 3 && trainer_cursor < array_length(trait_vex_purchasable(_tr_class))) {
            vex_detail_open = true; vex_detail_scroll = 0; exit;
        } else if (trainer_tab == 4) {
            vex_detail_open = true; vex_detail_scroll = 0; exit;   // Potency: general mechanic explanation
        }
    }

    // --- Trait-potency STAT PICKER sub-modal (tab 4) ------------------------
    // Opened from tab 4: pick ANY stat to sacrifice 5 permanent points from
    // (starting allocation + bought bonus). Intercepts all input while open.
    // Row geometry MUST match ui_draw_trainer_statpick() in scr_ui.
    if (variable_instance_exists(id, "trainer_statpick_open") && trainer_statpick_open) {
        var _sp_stats = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        // Per-stat allocation of the 5 points to spend (distribute with - / +).
        if (!variable_instance_exists(id, "trainer_statpick_alloc")
            || array_length(trainer_statpick_alloc) != 6) {
            trainer_statpick_alloc = [0, 0, 0, 0, 0, 0];
        }
        var _sp_total = 0;
        for (var _ti = 0; _ti < 6; _ti++) _sp_total += trainer_statpick_alloc[_ti];

        // Esc / right-click - cancel a pending confirm first, else close the picker.
        if (input_cancel() || input_back()
            || mouse_check_button_pressed(mb_right)) {
            if (trainer_statpick_confirm) { trainer_statpick_confirm = false; }
            else { trainer_statpick_open = false; trainer_notification = ""; }
            exit;
        }

        // W/S - move between stat rows.
        if (nav_up())   trainer_statpick_cursor = wrap_index(trainer_statpick_cursor - 1, 6);
        if (nav_down()) trainer_statpick_cursor = wrap_index(trainer_statpick_cursor + 1, 6);

        // A/D or Left/Right (and the on-row - / + buttons) adjust the highlighted stat.
        var _dec     = input_dir_left();
        var _inc     = input_dir_right();
        var _do_conf = input_confirm() || input_confirm_alt();

        // Mouse: rows + on-row -/+ buttons + the confirm bar. Geometry MUST match
        // ui_draw_trainer_statpick() (scr_ui).
        var _sp_px = 630, _sp_pw = 660, _sp_py = 255, _sp_ph = 660, _sp_y0 = 375, _sp_rh = 60;
        if (mouse_check_button_pressed(mb_left)) {
            var _spmx = device_mouse_x_to_gui(0);
            var _spmy = device_mouse_y_to_gui(0);
            var _minus_x = _sp_px + _sp_pw - 144;
            var _plus_x  = _sp_px + _sp_pw - 72;
            for (var _spi = 0; _spi < 6; _spi++) {
                var _spry = _sp_y0 + _spi * _sp_rh;
                if (_spmy >= _spry && _spmy < _spry + _sp_rh - 6
                    && _spmx >= _sp_px + 24 && _spmx < _sp_px + _sp_pw - 24) {
                    trainer_statpick_cursor = _spi;
                    if      (_spmx >= _minus_x && _spmx < _minus_x + 48) _dec = true;
                    else if (_spmx >= _plus_x  && _spmx < _plus_x  + 48) _inc = true;
                    break;
                }
            }
            // Confirm bar (only meaningful at total 5).
            if (_spmy >= _sp_py + _sp_ph - 105 && _spmy < _sp_py + _sp_ph - 54
                && _spmx >= _sp_px + 24 && _spmx < _sp_px + _sp_pw - 24) {
                _do_conf = true;
            }
        }

        // Apply +/- with caps: can't exceed a stat's available points, nor the total.
        // POTENCY V2: the point count comes from the rank being bought (set at open;
        // falls back to the legacy vex_potency_points for safety).
        var _sp_need = variable_instance_exists(id, "trainer_statpick_need")
            ? trainer_statpick_need : vex_potency_points();
        if (_dec || _inc) {
            trainer_statpick_confirm = false;   // any change disarms the confirm
            var _cs    = trainer_statpick_cursor;
            var _avail = stat_available_points(_sp_stats[_cs]);
            if (_dec && trainer_statpick_alloc[_cs] > 0) trainer_statpick_alloc[_cs] -= 1;
            if (_inc && _sp_total < _sp_need && trainer_statpick_alloc[_cs] < _avail) trainer_statpick_alloc[_cs] += 1;
            _sp_total = 0;
            for (var _ti2 = 0; _ti2 < 6; _ti2++) _sp_total += trainer_statpick_alloc[_ti2];
        }

        // Confirm / commit.
        if (_do_conf) {
            var _sp_tier = trait_potency_tier(trainer_statpick_trait);
            if (_sp_tier >= 5) {
                trainer_statpick_open = false;
                trainer_notification  = trainer_statpick_trait + " is already at max potency.";
            } else if (_sp_total != _sp_need) {
                trainer_notification = "Allocate exactly " + string(_sp_need) + " points to sacrifice (currently " + string(_sp_total) + ").";
            } else if (!trainer_statpick_confirm) {
                trainer_statpick_confirm = true;
                trainer_notification = "Sacrifice these " + string(_sp_need) + " points permanently? This cannot be undone.";
            } else {
                for (var _ci = 0; _ci < 6; _ci++) {
                    if (trainer_statpick_alloc[_ci] > 0) stat_spend_permanent(_sp_stats[_ci], trainer_statpick_alloc[_ci]);
                }
                if (!variable_global_exists("trait_potency")) global.trait_potency = {};
                variable_struct_set(global.trait_potency, trainer_statpick_trait, _sp_tier + 1);
                save_game();
                trainer_notification = trainer_statpick_trait + " potency raised to Rank " + string(_sp_tier + 1) + ".";
                trainer_statpick_confirm = false;
                trainer_statpick_open    = false;
            }
        }
        exit;
    }

    // Row count for the active tab (used for navigation + mouse hit-testing)
    var _tr_rows = 1;
    if (trainer_tab == 0)      _tr_rows = 6;
    else if (trainer_tab == 1) _tr_rows = 1;
    else if (trainer_tab == 2) _tr_rows = max(1, array_length(class_vex_purchasable(_tr_class)));
    else if (trainer_tab == 3) _tr_rows = max(1, array_length(trait_vex_purchasable(_tr_class)));
    else if (trainer_tab == 4) _tr_rows = array_length(trait_upgradable_list());

    var _act    = false;  // perform the selected row's action (Enter / second-click)
    var _commit = false;  // confirm a pending sacrifice (Space / confirm bar click)

    // Esc / Backspace - cancel a pending confirm first, otherwise close the screen
    if (input_cancel() || input_back()) {
        if (trainer_confirm) { trainer_confirm = false; trainer_notification = ""; }
        else                 { trainer_open = false; trainer_statpick_open = false; trainer_notification = ""; }
        exit;
    }

    // Q/E - switch section tabs (5 tabs: Stats | Trait Slots | Abilities | Traits |
    // Potency). REWEAVE moved to Vael the Aesthete (M 07-28 - the term fits her).
    if (input_tab_prev() || touch_dpad_tab_prev()) {
        trainer_tab = (trainer_tab - 1 + 5) mod 5;
        trainer_cursor = 0; trainer_confirm = false; trainer_notification = "";
    }
    if (input_tab_next() || touch_dpad_tab_next()) {
        trainer_tab = (trainer_tab + 1) mod 5;
        trainer_cursor = 0; trainer_confirm = false; trainer_notification = "";
    }

    // W/S - navigate rows
    if (nav_up())   { trainer_cursor = wrap_index(trainer_cursor - 1, _tr_rows); trainer_confirm = false; trainer_notification = ""; }
    if (nav_down()) { trainer_cursor = wrap_index(trainer_cursor + 1, _tr_rows); trainer_confirm = false; trainer_notification = ""; }
    // Mouse wheel walks the row cursor too (clamped, not wrapped). M 07-30.
    var _trw = mouse_wheel_down() - mouse_wheel_up();
    if (_trw != 0) {
        trainer_cursor = clamp(trainer_cursor + _trw, 0, max(0, _tr_rows - 1));
        trainer_confirm = false; trainer_notification = "";
    }
    trainer_cursor = clamp(trainer_cursor, 0, max(0, _tr_rows - 1));

    // Enter = act, Space = commit a sacrifice
    if (input_confirm()) _act = true;
    if (input_confirm_alt()) _commit = true;

    // Mouse: tab bar, row select / second-click acts, confirm bar
    if (mouse_check_button_pressed(mb_left)) {
        var _tmx = device_mouse_x_to_gui(0);
        var _tmy = device_mouse_y_to_gui(0);
        // Geometry MUST match the 5-tab bar in ui_draw_trainer_screen (60 + t*360, 345 wide).
        for (var _tbi = 0; _tbi < 5; _tbi++) {
            var _tbx = 60 + _tbi * 360;
            if (_tmx >= _tbx && _tmx < _tbx + 345 && _tmy >= 96 && _tmy < 144 && trainer_tab != _tbi) {
                trainer_tab = _tbi; trainer_cursor = 0;
                trainer_confirm = false; trainer_notification = "";
            }
        }
        // Scroll-aware row hit-test - Abilities (2) and Traits (3) lists can exceed
        // the screen and are windowed to 8 rows (matching the draw side).
        var _tr_vis    = _tr_rows;
        var _tr_hscroll = 0;
        if (trainer_tab == 2 || trainer_tab == 3 || trainer_tab == 4) {
            // Tab 3 (Traits) windows to 7 rows so the trade-item readout at y=626
            // doesn't overlap the last row; Tabs 2/4 have no readout, show 8.
            var _tr_window = (trainer_tab == 3) ? 7 : 8;
            _tr_vis     = min(_tr_window, _tr_rows);
            _tr_hscroll = loadout_list_scroll(trainer_cursor, _tr_rows, _tr_window);
        }
        for (var _rwi = 0; _rwi < _tr_vis; _rwi++) {
            var _rwy = 225 + _rwi * 96;
            if (_tmx >= 180 && _tmx < 1500 && _tmy >= _rwy && _tmy < _rwy + 87) {
                var _row_idx = _tr_hscroll + _rwi;
                if (trainer_cursor == _row_idx) { _act = true; }
                else { trainer_cursor = _row_idx; trainer_confirm = false; trainer_notification = ""; }
                break;
            }
        }
        if (trainer_tab == 4 && trainer_confirm
            && _tmx >= 180 && _tmx < 1740 && _tmy >= 987 && _tmy < 1041) {
            _commit = true;
        }
    }

    // === TAB 0: PERMANENT STAT UPGRADE - scaling gold + escalating trade item
    // (08-11: was flat 200g + 1 Rare forever, trivially stackable late-game) ===
    if (trainer_tab == 0 && _act) {
        var _stat_keys  = ["perm_str_bonus","perm_dex_bonus","perm_con_bonus","perm_int_bonus","perm_wis_bonus","perm_cha_bonus"];
        var _stat_names = ["STR","DEX","CON","INT","WIS","CHA"];
        var _stat_cost  = vex_price(cha_price(vex_stat_base_cost()));   // Vex Friend perk: 10% off
        var _stat_rar   = vex_stat_rarity_req();
        var _stat_rlbl  = item_rarity_name(_stat_rar);
        if (global.gold < _stat_cost) {
            trainer_notification = "Not enough gold - a stat costs " + string(_stat_cost) + "g + a " + _stat_rlbl + " item.";
            audio_play_sound(snd_ui_error, 1, false);
        } else if (!trainer_has_item(_stat_rar)) {
            trainer_notification = "You need a " + _stat_rlbl + " or better item in your stash/pack to trade.";
        } else {
            // Open the picker so the player chooses + confirms the item to trade.
            item_picker_open("vex_stat",
                { gold: _stat_cost, stat_key: _stat_keys[trainer_cursor], stat_name: _stat_names[trainer_cursor] },
                item_picker_candidates_by_rarity(_stat_rar));
            trainer_notification = "";
        }
    }
    // === TAB 1: TRAIT SLOT EXPANSION - 800/2000/4000/8000g, max +4 (M 07-16: was +2) ===
    else if (trainer_tab == 1 && _act) {
        var _bts = variable_global_exists("bonus_trait_slots") ? global.bonus_trait_slots : 0;
        if (_bts >= 4) {
            trainer_notification = "All trait slots already purchased (6 total).";
        } else {
            var _slot_ladder = [800, 2000, 4000, 8000];
            var _slot_cost = vex_price(cha_price(_slot_ladder[_bts]));   // Vex Friend perk: 10% off
            if (global.gold < _slot_cost) {
                trainer_notification = "Not enough gold - the next slot costs " + string(_slot_cost) + "g.";
                audio_play_sound(snd_ui_error, 1, false);
            } else {
                global.gold -= _slot_cost;
                vex_first_buy_consume();   // Drill Regimen: first buy each visit
                global.bonus_trait_slots = _bts + 1;
                affinity_add("vex", 2);   // function-use drip (trait slot)
                save_game();
                trainer_notification = "Trait slot unlocked - you can now equip " + string(2 + global.bonus_trait_slots) + " traits.";
            }
        }
    }
    // === TAB 2: ABILITY UNLOCK - tiered cost (500 / 800 / 1200g) ===
    else if (trainer_tab == 2 && _act) {
        var _locked = class_vex_purchasable(_tr_class);
        if (array_length(_locked) == 0) {
            trainer_notification = "Every purchasable ability for this class is unlocked.";
        } else {
            var _ab   = _locked[clamp(trainer_cursor, 0, array_length(_locked) - 1)];
            var _cost = ability_unlock_cost(_ab.name);
            if (global.gold < _cost) {
                trainer_notification = _ab.name + " costs " + string(_cost) + "g  (need "
                    + string(_cost - global.gold) + "g more).";
                trainer_confirm = false;
            } else if (!trainer_confirm) {
                // Misclick guard (M 07-08): first press arms, second press buys.
                // trainer_confirm resets on nav / tab change / Esc like tab 4's.
                trainer_confirm = true;
                trainer_notification = "Buy " + _ab.name + " for " + string(_cost) + "g?  Confirm to purchase.";
            } else {
                trainer_confirm = false;
                global.gold -= _cost;
                vex_first_buy_consume();   // Drill Regimen: first buy each visit
                if (!variable_global_exists("unlocked_abilities")) global.unlocked_abilities = [];
                array_push(global.unlocked_abilities, _ab.name);
                affinity_add("vex", 2);   // function-use drip (ability unlock)
                save_game();
                trainer_notification = "Unlocked " + _ab.name + "! It can now be slotted in your loadout.";
                trainer_cursor = clamp(trainer_cursor, 0, max(0, array_length(_locked) - 2));
            }
        }
    }
    // === TAB 3: TRAIT UNLOCK - gold + a rarity-matched item ===
    else if (trainer_tab == 3 && _act) {
        var _tr_locked = trait_vex_purchasable(_tr_class);
        if (array_length(_tr_locked) == 0) {
            trainer_notification = "Every trait available to this class is unlocked.";
        } else {
            var _tt    = _tr_locked[clamp(trainer_cursor, 0, array_length(_tr_locked) - 1)];
            var _tcost = trait_unlock_cost(_tt.name);
            if (global.gold < _tcost.gold) {
                trainer_notification = _tt.name + " costs " + string(_tcost.gold) + "g + a "
                    + _tcost.item_label + " item  (need " + string(_tcost.gold - global.gold) + "g more).";
            } else if (!trainer_has_item(_tcost.min_rarity)) {
                trainer_notification = _tt.name + " also needs a " + _tcost.item_label
                    + "+ item in your stash/pack to trade.";
            } else {
                // Open the picker so the player chooses + confirms the item to trade.
                item_picker_open("vex_trait",
                    { gold: _tcost.gold, effect_id: _tt.effect_id, trait_name: _tt.name },
                    item_picker_candidates_by_rarity(_tcost.min_rarity));
                trainer_notification = "";
            }
        }
    }
    // === TAB 4: TRAIT POTENCY (V2, SYSTEMS_POTENCY_V2.md) - tiered mixed costs:
    // ranks 1-2 gold+dust, ranks 3-4 the stat allocator, rank 5 an Epic+ offering ===
    else if (trainer_tab == 4) {
        var _ups  = trait_upgradable_list();
        var _up   = _ups[clamp(trainer_cursor, 0, array_length(_ups) - 1)];
        var _tier = trait_potency_tier(_up.name);

        if (_act || _commit) {
            if (_tier >= 5) {
                trainer_notification = _up.name + " has already Transcended.";
            } else {
                var _pc = trait_potency_rank_cost(_tier + 1);
                if (_pc.kind == "gold") {
                    var _pg = vex_price(cha_price(_pc.gold));   // Vex Friend perk: 10% off
                    var _pd = _pc.dust;
                    var _pdust_have = variable_global_exists("rune_dust") ? global.rune_dust : 0;
                    if (trainer_confirm) {
                        if (global.gold >= _pg && _pdust_have >= _pd) {
                            global.gold      -= _pg;
                            global.rune_dust -= _pd;
                            vex_first_buy_consume();   // Drill Regimen: first buy each visit
                            if (!variable_global_exists("trait_potency")) global.trait_potency = {};
                            variable_struct_set(global.trait_potency, _up.name, _tier + 1);
                            affinity_add("vex", 2);   // function-use drip (potency)
                            save_game();
                            trainer_confirm      = false;
                            trainer_notification = _up.name + " potency raised to Rank " + string(_tier + 1) + ".";
                            audio_play_sound(snd_npc_confirm, 1, false);
                        }
                    } else if (_act) {
                        if (global.gold < _pg) {
                            trainer_notification = "Not enough gold - Rank " + string(_tier + 1) + " costs " + string(_pg) + "g + " + string(_pd) + " dust.";
                            audio_play_sound(snd_ui_error, 1, false);
                        } else if (_pdust_have < _pd) {
                            trainer_notification = "Need " + string(_pd) + " rune dust (you have " + string(_pdust_have) + ").";
                            audio_play_sound(snd_ui_error, 1, false);
                        } else {
                            trainer_confirm      = true;
                            trainer_notification = "Raise " + _up.name + " to Rank " + string(_tier + 1) + " for " + string(_pg) + "g + " + string(_pd) + " dust?";
                        }
                    }
                } else if (_pc.kind == "stats") {
                    // Ranks 3-4: the stat allocator - point count comes from the
                    // V2 cost table (Vex Companion perk takes one off).
                    if (_act) {
                        trainer_statpick_open    = true;
                        trainer_statpick_trait   = _up.name;
                        trainer_statpick_need    = _pc.points;
                        trainer_statpick_cursor  = 0;
                        trainer_statpick_confirm = false;
                        trainer_statpick_alloc   = [0, 0, 0, 0, 0, 0];
                        trainer_notification     = "";
                    }
                } else if (_act) {
                    // Rank 5: the Transcend offering - one Epic+ item via the picker.
                    if (!trainer_has_item(3)) {
                        trainer_notification = "Transcending " + _up.name + " asks an Epic or better item from your stash/pack.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        var _tinfo = trait_potency_info(_up.name);
                        item_picker_open("vex_potency",
                            { trait_name: _up.name, tname: _tinfo.tname },
                            item_picker_candidates_by_rarity(3));
                        trainer_notification = "";
                    }
                }
            }
        }
    }
    // (REWEAVE moved to Vael the Aesthete, M 07-28 - see the vael_open handler.)

    exit;
}


// =============================================================================
// BAIRC FIRST-TALK DIALOGUE - a modal popup shown before his station opens the very
// first time. Arms only after the interact key that triggered it is released, so that
// same keypress can't dismiss it; then any key / click opens the station + hatch prompt.
// =============================================================================
if (variable_instance_exists(id, "bairc_intro_open") && bairc_intro_open) {
    if (!bairc_intro_armed) {
        if (!input_any_held() && !mouse_check_button(mb_left)) bairc_intro_armed = true;
    } else if (input_any() || mouse_check_button_pressed(mb_left)) {
        bairc_intro_open   = false;
        bairc_open         = true;   // now open the station
        bairc_cursor       = 0;
        bairc_notification = "Your egg is stirring - highlight it and press Enter to hatch it.";
    }
    exit;
}

// =============================================================================
// BAIRC LORE FRAGMENT - his portrait dialogue for a queued one-time lore line
// (bond milestones / first donation, design §10). Same arm-then-any-key flow as
// the intro so the keypress that opened the garden can't skip it.
// =============================================================================
if (variable_instance_exists(id, "bairc_lore_open") && bairc_lore_open) {
    if (!bairc_lore_armed) {
        if (!input_any_held() && !mouse_check_button(mb_left)) bairc_lore_armed = true;
    } else if (input_any() || mouse_check_button_pressed(mb_left)) {
        bairc_lore_open = false;
        var _lq = bairc_lore_queue();
        if (array_length(_lq) > 0) array_delete(_lq, 0, 1);   // consumed
        if (room == rm_hub || room == rm_character_select) save_game();
    }
    exit;
}

// =============================================================================
// BAIRC THE CREATURE KEEPER - pet stable / hatchery (Phase 2). Cursor over the
// roster; Enter hatches an egg, else sets the highlighted pet as active companion;
// Esc closes. Layout constants MUST match ui_draw_bairc_screen() in scr_ui.
// =============================================================================
if (variable_instance_exists(id, "bairc_open") && bairc_open && npc_tour_step < 0
    && !garden_open) {   // the garden scene owns input while it is up
    var _bp_n = pet_count();
    if (_bp_n > 0) bairc_cursor = clamp(bairc_cursor, 0, _bp_n - 1); else bairc_cursor = 0;

    // VISIT THE GARDEN (M design-locked 08-15): [V] / the header chip fades
    // into the full-screen grounds. Only from the base station view - the
    // sub-modals below own their input.
    if (!bairc_pad_menu_open && !bairc_detail_open && !bairc_naming
        && !bairc_release_confirm && !bairc_capstone_open && !hatch_active
        && (input_hotkey("V") || input_inject_take("bairc:garden"))) {
        garden_open   = true;
        garden_fade   = 24;
        garden_cam_x  = 0;
        garden_notice = ""; garden_notice_t = 0;
        garden_wip_t  = 480;   // 8s WORK-IN-PROGRESS banner on every entry (M 08-18)
        garden_shop_open = false; garden_place_pick = ""; garden_fx = [];
        // The garden's own music pool (selection via the [M] chip in-scene).
        music_hub_stop();
        audio_play_sound(music_garden_snd(), 1, true);
        audio_apply_volumes();
        audio_play_sound(snd_page, 1, false);
        exit;
    }

    // A queued lore fragment takes the floor before anything else (one per visit-moment;
    // the next queued line shows after this one is dismissed).
    if (array_length(bairc_lore_queue()) > 0 && !bairc_lore_open) {
        bairc_lore_open  = true;
        bairc_lore_armed = false;
        exit;
    }

    // NAMING modal (typed text entry): captures keyboard_string; Enter confirms, Esc cancels.
    // First name is free; renaming costs 20 dust. Swallows all other input while up.
    if (bairc_naming) {
        if (string_length(keyboard_string) > 16) keyboard_string = string_copy(keyboard_string, 1, 16);
        if (input_confirm()) {
            var _nm = string_trim(keyboard_string);
            if (_nm != "" && _bp_n > 0) {
                var _np      = global.pet_roster[bairc_cursor];
                var _rename  = pet_named(_np);
                if (!_rename || global.rune_dust >= 20) {
                    if (_rename) global.rune_dust -= 20;
                    _np.name  = _nm;
                    _np.named = true;
                    bairc_notification = "\"" + _nm + "\" - this name will now be known to them...";
                    audio_play_sound(snd_npc_confirm, 1, false);
                    if (room == rm_hub || room == rm_character_select) save_game();
                } else {
                    bairc_notification = "Renaming costs 20 dust.";
                }
            }
            bairc_naming = false;
        }
        if (input_cancel()) bairc_naming = false;
        exit;
    }

    // CAPSTONE PICK modal (raised Adult choosing its permanent Stage-3 gift). Two-step:
    // A/D highlights a card, Enter opens a Yes/No confirm, Enter again locks it. Esc backs
    // out (confirm -> selection -> close). Swallows all other input while up.
    if (bairc_capstone_open) {
        // Serves BOTH permanent picks: the Stage-3 capstone and the Stage-4 Awakened
        // splash (bairc_capstone_mode switches the pool + lock fn; same two-step UX).
        var _cp_pet    = (_bp_n > 0) ? global.pet_roster[bairc_cursor] : undefined;
        var _cp_splash = (bairc_capstone_mode == "splash");
        var _cp_pool   = [];
        if (is_struct(_cp_pet)) _cp_pool = _cp_splash ? pet_splash_pool(_cp_pet.archetype) : pet_archetype_capstones(_cp_pet.archetype);
        var _cp_n    = array_length(_cp_pool);
        var _cp_ok   = _cp_splash ? pet_splash_can_pick(_cp_pet) : pet_capstone_can_pick(_cp_pet);
        if (!_cp_ok || _cp_n == 0) { bairc_capstone_open = false; exit; }

        if (!bairc_capstone_confirm) {
            if (nav_left())  bairc_capstone_sel = wrap_index(bairc_capstone_sel - 1, _cp_n);
            if (nav_right()) bairc_capstone_sel = wrap_index(bairc_capstone_sel + 1, _cp_n);
            // Card taps (Draw injects; touch rule 08-16).
            for (var _cp_t = 0; _cp_t < _cp_n; _cp_t++)
                if (input_inject_take("capstone:pick" + string(_cp_t))) bairc_capstone_sel = _cp_t;
            bairc_capstone_sel = clamp(bairc_capstone_sel, 0, _cp_n - 1);
            if (input_confirm() || input_confirm_alt() || input_inject_take("capstone:confirm")) {
                bairc_capstone_confirm = true;
            }
            if (input_cancel()) bairc_capstone_open = false;
        } else {
            // Yes/No confirm - permanent choice.
            if (input_confirm() || input_inject_take("capstone:lock")) {
                var _pick   = _cp_pool[clamp(bairc_capstone_sel, 0, _cp_n - 1)];
                var _locked = _cp_splash ? pet_splash_choose(_cp_pet, _pick.id) : pet_capstone_choose(_cp_pet, _pick.id);
                if (_locked) {
                    bairc_notification = _cp_splash
                        ? (_cp_pet.name + " draws " + _pick.name + " into itself - the crossing is complete.")
                        : (_cp_pet.name + " takes up " + _pick.name + " - its path is set.");
                    audio_play_sound(snd_npc_confirm, 1, false);
                    affinity_add("bairc", 2);   // function-use drip (gift/splash pick)
                    if (room == rm_hub || room == rm_character_select) save_game();
                }
                bairc_capstone_open    = false;
                bairc_capstone_confirm = false;
            }
            if (input_cancel()) bairc_capstone_confirm = false;   // back to selection
        }
        exit;
    }

    // DONATE confirm modal (design §6: donation, not release): entrust the highlighted
    // creature to Bairc's garden. Enter confirms, Esc keeps it. Swallows all other input.
    if (bairc_release_confirm) {
        if (_bp_n == 0) { bairc_release_confirm = false; exit; }
        if (input_confirm()) {
            var _rl = pet_donate(bairc_cursor);
            if (_rl != "") {
                bairc_notification = "Bairc takes " + _rl + " gently. It has a home in his garden now.";
                audio_play_sound(snd_npc_confirm, 1, false);
                affinity_add("bairc", 2);   // function-use drip (donation)
                bairc_cursor = clamp(bairc_cursor, 0, max(0, pet_count() - 1));
                if (room == rm_hub || room == rm_character_select) save_game();
            }
            bairc_release_confirm = false;
        }
        if (input_cancel()) bairc_release_confirm = false;
        exit;
    }

    // Gamepad action submenu (chunk 7b, M 2026-07-07: "pressing confirm goes into
    // the list and you select there"): opened by pad-A on a roster row (below).
    // Picking an entry injects a namespaced synthetic hotkey ("bairc:N") that the
    // UNCHANGED letter handlers further down consume on the next step - keyboard
    // behavior is untouched. Level 1 lists the owned feeds (Feed... entry).
    if (bairc_pad_menu_open) {
        if (_bp_n == 0) { bairc_pad_menu_open = false; exit; }
        var _pm_pet   = global.pet_roster[clamp(bairc_cursor, 0, _bp_n - 1)];
        var _pm_items = bairc_pad_menu_items(_pm_pet, bairc_pad_menu_level);
        var _pm_n     = array_length(_pm_items);
        bairc_pad_menu_cursor = clamp(bairc_pad_menu_cursor, 0, max(0, _pm_n - 1));
        if (nav_up())   bairc_pad_menu_cursor = wrap_index(bairc_pad_menu_cursor - 1, _pm_n);
        if (nav_down()) bairc_pad_menu_cursor = wrap_index(bairc_pad_menu_cursor + 1, _pm_n);
        if (input_cancel() || input_back()) {
            if (bairc_pad_menu_level == 1) { bairc_pad_menu_level = 0; bairc_pad_menu_cursor = 0; }
            else bairc_pad_menu_open = false;
            exit;
        }
        if ((input_confirm() || input_confirm_alt()) && _pm_n > 0) {
            var _pm_pick = _pm_items[bairc_pad_menu_cursor];
            if (_pm_pick.tag == "feed_menu") {
                bairc_pad_menu_level  = 1;
                bairc_pad_menu_cursor = 0;
            } else if (_pm_pick.tag != "") {
                input_inject(_pm_pick.tag);
                bairc_pad_menu_open = false;
            }
        }
        exit;
    }

    // Tab pet-kit detail popup: while up, only Tab/Esc (close) - swallow all else.
    if (bairc_detail_open) {
        if (input_detail() || input_cancel()) bairc_detail_open = false;
        exit;
    }
    if ((input_detail() || input_inject_take("bairc:detail")) && _bp_n > 0) {
        bairc_detail_open = true;
        exit;
    }

    if (input_cancel()) {
        bairc_open = false;
        exit;
    }
    if (_bp_n > 0) {
        if (nav_up())   { bairc_cursor = wrap_index(bairc_cursor - 1, _bp_n); bairc_notification = ""; }
        if (nav_down()) { bairc_cursor = wrap_index(bairc_cursor + 1, _bp_n); bairc_notification = ""; }

        var _bp = global.pet_roster[bairc_cursor];
        // I: identify a mysterious egg (paid). Until identified, the egg can't hatch
        // and its species/type read "??" (design 2026-07-04).
        if ((input_hotkey("I") || input_inject_take("bairc:I")) && _bp.is_egg && !pet_egg_identified(_bp)) {
            var _id_cost = pet_egg_identify_cost();
            if (global.gold >= _id_cost) {
                global.gold -= _id_cost;
                _bp.identified = true;
                bairc_notification = "Bairc turns it over in his hands... a "
                    + pet_species_get(_bp.species).name + " egg - " + pet_archetype_name(_bp.archetype) + ".";
                audio_play_sound(snd_npc_confirm, 1, false);
                affinity_add("bairc", 2);   // function-use drip (identification)
                if (room == rm_hub || room == rm_character_select) save_game();
            } else {
                bairc_notification = "Identifying costs " + string(_id_cost) + "g - you're short.";
            }
        }
        // Chunk 7b/8d: on a gamepad OR touch, confirm opens the action submenu
        // instead of the direct set-active/hatch (which becomes the menu's first
        // entry, tag "bairc:confirm"). On touch the confirm arrives as a
        // simulated Enter from tapping the selected roster row. Keyboard
        // Enter/Space keep their direct behavior - the device check routes.
        var _bc_conf = input_confirm() || input_confirm_alt();
        if (_bc_conf && input_device() >= 1) {
            bairc_pad_menu_open   = true;
            bairc_pad_menu_level  = 0;
            bairc_pad_menu_cursor = 0;
        } else if (_bc_conf || input_inject_take("bairc:confirm")) {
            if (_bp.is_egg && !pet_egg_identified(_bp)) {
                bairc_notification = "Bairc shakes his head - identify it first ([I], "
                    + string(pet_egg_identify_cost()) + "g). No telling what would crawl out.";
            } else if (_bp.is_egg) {
                hatch_cutscene_start(_bp);   // full-screen shake -> crack -> reveal; hatches at the reveal
                affinity_add("bairc", 2);    // function-use drip (hatching together)
            } else {
                global.active_pet  = bairc_cursor;
                bairc_notification = _bp.name + " is now your active companion.";
                audio_play_sound(snd_npc_confirm, 1, false);
                affinity_add("bairc", 2);    // function-use drip (companion chosen)
                if (room == rm_hub || room == rm_character_select) save_game();
            }
        }

        // Feed: number keys 1-N apply an OWNED feed (bought from Petra) to the highlighted
        // pet - no gold here. Feed FILLS the growth bar; an active run still evolves it.
        // Pouches deeper than the 6 hotkey rows page with [A]/[D] (M 07-09: overflow
        // items were listed as "+N more" but could never be seen or selected).
        var _owned      = pet_feed_owned_list();
        // Page size = the row capacity the Draw pass measured last frame
        // (_gc.bairc_feed_vis) - NOT a flat 6. When the boxes above squeeze the
        // FEED box below 6 rows, 6-wide pages hid the tail forever (M 07-27:
        // "+2 more in the pouch but i cant see what i want").
        var _feed_vis   = variable_instance_exists(id, "bairc_feed_vis") ? max(1, bairc_feed_vis) : 6;
        var _feed_pages = max(1, ceil(array_length(_owned) / _feed_vis));
        if (input_hotkey("D")) bairc_feed_page = (bairc_feed_page + 1) mod _feed_pages;
        if (input_hotkey("A")) bairc_feed_page = (bairc_feed_page - 1 + _feed_pages) mod _feed_pages;
        bairc_feed_page = clamp(bairc_feed_page, 0, _feed_pages - 1);
        var _feed_key = -1;
        if      (input_hotkey("1") || input_inject_take("bairc:feed1")) _feed_key = 0;
        else if (input_hotkey("2") || input_inject_take("bairc:feed2")) _feed_key = 1;
        else if (input_hotkey("3") || input_inject_take("bairc:feed3")) _feed_key = 2;
        else if (input_hotkey("4") || input_inject_take("bairc:feed4")) _feed_key = 3;
        else if (input_hotkey("5") || input_inject_take("bairc:feed5")) _feed_key = 4;
        else if (input_hotkey("6") || input_inject_take("bairc:feed6")) _feed_key = 5;
        // Pad/touch action-menu feeds inject an ABSOLUTE index ("bairc:feedabs<i>") -
        // the digit path above is page-relative and capped at 6, which silently hid
        // feed types 7+ from pad/touch players (07-24 audit).
        var _feed_abs = -1;
        for (var _fai = 0; _fai < array_length(_owned); _fai++) {
            if (input_inject_take("bairc:feedabs" + string(_fai))) { _feed_abs = _fai; break; }
        }
        // A number key past the visible window ([5] when only 4 rows fit) would
        // silently feed an item on the NEXT page - drop it instead.
        if (_feed_key >= _feed_vis) _feed_key = -1;
        if (_feed_key >= 0 || _feed_abs >= 0) {
            var _feed_idx = (_feed_abs >= 0) ? _feed_abs
                : bairc_feed_page * _feed_vis + _feed_key;   // hotkeys address the visible page
            if (_feed_idx >= array_length(_owned)) {
                if (!_bp.is_egg && pet_feed_pouch_total() <= 0)
                    bairc_notification = "No feed on hand - buy some from Petra the Trader.";
            } else {
                var _fr = pet_feed_apply(_bp, _owned[_feed_idx].id);
                if (_fr == "") {
                    bairc_notification = _bp.name + " enjoys the " + _owned[_feed_idx].name + "."
                        + (pet_growth_ready(_bp) ? "  Ready to grow - take it on a run!" : "");
                    audio_play_sound(snd_npc_confirm, 1, false);
                    affinity_add("bairc", 2);   // function-use drip (feeding)
                    if (room == rm_hub || room == rm_character_select) save_game();
                } else {
                    bairc_notification = _fr;
                }
            }
        }

        // C: cure a pushed corrupted pet (keeps the gains so far, drops the debuff,
        // forfeits the grand ability).
        if (input_hotkey("C") || input_inject_take("bairc:C")) {
            // Two-press confirm (M 08-15: "i just automatically cured one
            // corrupt pet" - curing forfeits the grand power, so it asks first).
            if (!variable_instance_exists(id, "bairc_cure_arm")) bairc_cure_arm = undefined;
            if (pet_corr_state(_bp) == "pushing" && bairc_cure_arm != _bp) {
                bairc_cure_arm = _bp;
                bairc_notification = "Cure " + _bp.name + "? It KEEPS its dark strength but FORFEITS the grand power. Press [C] again to confirm.";
                audio_play_sound(snd_page, 1, false);
            } else {
                var _cure = pet_corruption_cure(_bp);
                bairc_cure_arm = undefined;
                if (_cure != "") {
                    bairc_notification = _cure;
                    audio_play_sound(snd_npc_confirm, 1, false);
                    if (room == rm_hub || room == rm_character_select) save_game();
                }
            }
        }

        // G: choose the raised pet's permanent pick - Stage-3 capstone first, then the
        // Stage-4 Awakened splash once it crosses (same modal, bairc_capstone_mode).
        if (input_hotkey("G") || input_inject_take("bairc:G")) {
            if (pet_capstone_can_pick(_bp)) {
                bairc_capstone_mode    = "cap";
                bairc_capstone_open    = true;
                bairc_capstone_sel     = 0;
                bairc_capstone_confirm = false;
            } else if (pet_splash_can_pick(_bp)) {
                bairc_capstone_mode    = "splash";
                bairc_capstone_open    = true;
                bairc_capstone_sel     = 0;
                bairc_capstone_confirm = false;
            } else if (!_bp.is_egg && !_bp.raised) {
                bairc_notification = "Only creatures you raised from an egg choose their gift.";
            } else if (!_bp.is_egg && _bp.stage < PET_STAGE_ADULT) {
                bairc_notification = _bp.name + " must reach adulthood before choosing a gift.";
            } else if (pet_splash_is_locked(_bp) || pet_capstone_is_locked(_bp)) {
                bairc_notification = _bp.name + "'s path is already set.";
            }
        }

        // R: donate the highlighted creature to Bairc's garden (opens a confirm; permanent).
        if (input_hotkey("R") || input_inject_take("bairc:R")) {
            bairc_release_confirm = true;
        }

        // N: name / rename the highlighted creature (first name free, rename 20 dust).
        if (input_hotkey("N") || input_inject_take("bairc:N")) {
            if (_bp.is_egg) {
                bairc_notification = "You can name it once it hatches.";
            } else if (pet_named(_bp) && global.rune_dust < 20) {
                bairc_notification = "Renaming costs 20 dust (you have " + string(global.rune_dust) + ").";
            } else {
                bairc_naming    = true;
                keyboard_string = "";
            }
        }
    }
    exit;
}


// =============================================================================
// MAREN THE RUNESMITH - rune socketing (Phase 1: Socket gear + Runes list).
// Runs alongside the trainer block, before the menu_open guard.
// Socket tab is a 3-phase flow: 0 pick item -> 1 pick socket -> 2 pick rune.
// Layout constants here MUST match ui_draw_maren_screen() in scr_ui.
// =============================================================================
if (variable_instance_exists(id, "maren_open") && maren_open && !menu_open && !forge_result_up()
    && npc_tour_step < 0) {
    // Aspects tab first view: explain that accuracy runes stack to a CAP (M 08-17).
    if (maren_tab == 1 && !banshee_release_open) tutorial_try_show("rune_caps");
    // --- Banshee release ceremony popup: owns ALL input while open. Any key
    //     first skips to the reveal, then closes. (Drawn by ui_draw_maren.) ---
    if (banshee_release_open) {
        banshee_release_timer++;
        // Melodic scream lands as the spirit clears the bottle mouth (anim frame
        // ~4 of 17 at 5 game-steps per frame - matches ui_draw_banshee_release).
        if (!banshee_scream_played && banshee_release_timer >= 20) {
            banshee_scream_played = true;
            audio_play_sound(snd_banshee_scream, 1, false);
        }
        var _bb_anim_done = (banshee_release_timer >= 17 * 5);
        if (keyboard_check_pressed(vk_anykey) || mouse_check_button_pressed(mb_left)) {
            if (!_bb_anim_done) {
                banshee_release_timer = 17 * 5;   // skip to the held final frame + reveal
                if (!banshee_scream_played) {
                    banshee_scream_played = true;
                    audio_play_sound(snd_banshee_scream, 1, false);
                }
            } else {
                banshee_release_open   = false;
                banshee_release_result = undefined;
            }
        }
        exit;
    }

    rune_inventory_sort();   // keep the rune/aspect pool alphabetical (display + index ops read this)
    var _m_slots = maren_socketable_slots();
    var _m_gear  = rune_inventory_indices("gear");
    var _m_asp   = rune_inventory_indices("aspect");

    // Item currently being worked on (Socket-tab phases 1/2)
    var _m_item = (maren_item_sel >= 0 && maren_item_sel < array_length(global.inventory))
                  ? global.inventory[maren_item_sel] : undefined;
    item_ensure_sockets(_m_item);

    // --- Confirm modal: a pending gold-costing / destructive action awaiting a yes/no.
    //     Takes input priority over the whole screen. Enter confirms, Esc cancels. ---
    if (maren_confirm != undefined) {
        if (input_cancel() || input_back()
            || mouse_check_button_pressed(mb_right)) {
            maren_confirm = undefined;
            maren_notification = "Cancelled.";
            exit;
        }
        if (input_confirm()) {
            var _cf = maren_confirm;
            maren_confirm = undefined;

            if (_cf.action == "socket") {
                if (global.gold < _cf.cost) { maren_notification = "Need " + string(_cf.cost) + "g."; audio_play_sound(snd_ui_error, 1, false); exit; }
                if (maren_socket_rune(maren_item_sel, _cf.rune_inv)) {
                    global.gold -= _cf.cost; affinity_add("maren", 2); save_game();   // function-use drip (socket)
                    maren_notification = "Socketed " + _cf.name + " " + rune_tier_roman(_cf.tier)
                        + ".  (-" + string(_cf.cost) + "g)";
                    audio_play_sound(snd_rune_socket, 1, false);
                } else {
                    maren_notification = "That item has no open sockets.";
                }
                maren_phase = 1; maren_cursor = 0; maren_scroll = 0;

            } else if (_cf.action == "unsocket") {
                if (global.gold < _cf.cost) { maren_notification = "Need " + string(_cf.cost) + "g."; audio_play_sound(snd_ui_error, 1, false); exit; }
                if (maren_unsocket_rune(maren_item_sel, _cf.rune_idx)) {
                    global.gold -= _cf.cost; save_game();
                    maren_notification = "Removed " + _cf.name + " " + rune_tier_roman(_cf.tier)
                        + " (returned to inventory).  (-" + string(_cf.cost) + "g)";
                    audio_play_sound(snd_rune_socket, 1, false);
                    maren_cursor = clamp(maren_cursor, 0, max(0, (_m_item != undefined ? _m_item.socket_count : 1) - 1));
                } else {
                    maren_notification = "Could not remove that rune.";
                }

            } else if (_cf.action == "split") {
                var _sr_name = _cf.name; var _sr_tier = _cf.tier;
                var _sres = maren_split_rune(_cf.rune_inv);
                maren_notification = (_sres == "")
                    ? ("Split " + _sr_name + " " + rune_tier_roman(_sr_tier) + ".")
                    : _sres;
                if (_sres == "") audio_play_sound(snd_sell, 1, false);   // breaking down = the salvage rattle
                maren_cursor = clamp(maren_cursor, 0, max(0, array_length(global.rune_inventory) - 1));

            } else if (_cf.action == "combine") {
                var _cres = maren_combine_rune(_cf.grp_id, _cf.grp_tier);
                maren_notification = (_cres == "")
                    ? ("Forged " + _cf.name + " " + rune_tier_roman(_cf.grp_tier + 1) + "!")
                    : _cres;
                if (_cres == "") audio_play_sound(snd_forge, 1, false);
                maren_cursor = 0; maren_scroll = 0;

            } else if (_cf.action == "aspect_socket") {
                if (global.gold < _cf.cost) { maren_notification = "Need " + string(_cf.cost) + "g."; audio_play_sound(snd_ui_error, 1, false); exit; }
                if (maren_aspect_socket(_cf.rune_inv)) {
                    global.gold -= _cf.cost; affinity_add("maren", 2); save_game();   // function-use drip (aspect socket)
                    maren_notification = "Socketed " + _cf.name + " " + rune_tier_roman(_cf.tier)
                        + ".  (-" + string(_cf.cost) + "g)";
                    audio_play_sound(snd_rune_socket, 1, false);
                } else {
                    maren_notification = "No open Aspect slot.";
                }
                maren_phase = 0; maren_cursor = 0; maren_scroll = 0;

            } else if (_cf.action == "aspect_unsocket") {
                if (global.gold < _cf.cost) { maren_notification = "Need " + string(_cf.cost) + "g."; exit; }
                if (maren_aspect_unsocket(_cf.slot_idx)) {
                    global.gold -= _cf.cost; save_game();
                    maren_notification = "Removed " + _cf.name + " " + rune_tier_roman(_cf.tier)
                        + " (returned to inventory).  (-" + string(_cf.cost) + "g)";
                    // Re-clamp against the aspect-tab row count (nav re-clamps next frame too).
                    maren_cursor = clamp(maren_cursor, 0, max(0, (variable_global_exists("aspect_slots") ? global.aspect_slots : 2)));
                } else {
                    maren_notification = "Could not remove that rune.";
                }

            } else if (_cf.action == "deep_socket") {
                // DEEP SOCKET (Maren rank 2, M-locked 08-15): +1 socket into an
                // equipped piece - 400g + 80 dust, once per run, once ever per item.
                if (global.gold < 400 || global.rune_dust < 80) {
                    maren_notification = "Deep Socket costs 400g + 80 dust.";
                    audio_play_sound(snd_ui_error, 1, false); exit;
                }
                var _dsi = _cf.item;
                item_ensure_sockets(_dsi);
                _dsi.socket_count += 1;
                _dsi.deep_socketed = true;
                global.deep_socket_used = true;
                global.gold -= 400; global.rune_dust -= 80;
                affinity_add("maren", 2); save_game();
                maren_notification = "Maren drills a DEEP SOCKET into " + _dsi.name + "!  (-400g, -80 dust)";
                audio_play_sound(snd_forge, 1, false);

            } else if (_cf.action == "banshee_release") {
                // Free the spirit: consume a banked bottle, roll the reward, and start
                // the release ceremony popup (bottle opens, banshee rises, scream).
                var _bb_res = banshee_release_roll();
                if (_bb_res == undefined) {
                    maren_notification = "No bottled spirits to free.";
                } else {
                    banshee_release_open   = true;
                    banshee_release_timer  = 0;
                    banshee_release_result = _bb_res;
                    banshee_scream_played  = false;
                    affinity_add("maren", 2);   // she loves this work (function-use drip)
                    save_game();
                }
            }
            exit;
        }
        exit;   // swallow all other input while the confirm prompt is open
    }

    // DEEP SOCKET (Maren rank 2, M-locked 08-15): [D] on the Socket Gear tab
    // drills +1 socket into the targeted equipped piece. Phase 0 targets the
    // highlighted row; phases 1/2 target the item already being worked on.
    // The draw side offers a tappable chip that presses D (touch parity).
    if (maren_tab == 0 && input_hotkey("D")) {
        var _ds_item = _m_item;
        if (_ds_item == undefined && maren_phase == 0) {
            var _ds_slots = maren_socketable_slots();
            if (array_length(_ds_slots) > 0) {
                _ds_item = global.inventory[_ds_slots[clamp(maren_cursor, 0, array_length(_ds_slots) - 1)]];
            }
        }
        if (npc_rank("maren") < 2) {
            maren_notification = "Deep Socket needs Maren's station at rank 2  ([U] or the STATION chip on the camp carousel).";
            audio_play_sound(snd_ui_error, 1, false);
        } else if (variable_global_exists("deep_socket_used") && global.deep_socket_used) {
            maren_notification = "The deep bit is spent - Maren can drill again after your next run.";
            audio_play_sound(snd_ui_error, 1, false);
        } else if (_ds_item == undefined) {
            maren_notification = "Select an equipped piece to deep-socket first.";
            audio_play_sound(snd_ui_error, 1, false);
        } else if (variable_struct_exists(_ds_item, "deep_socketed") && _ds_item.deep_socketed) {
            maren_notification = _ds_item.name + " already carries a deep socket - one per item, ever.";
            audio_play_sound(snd_ui_error, 1, false);
        } else if (global.gold < 400 || (variable_global_exists("rune_dust") ? global.rune_dust : 0) < 80) {
            maren_notification = "Deep Socket costs 400g + 80 dust.";
            audio_play_sound(snd_ui_error, 1, false);
        } else {
            item_ensure_sockets(_ds_item);
            maren_confirm = {
                action: "deep_socket", cost: 400, item: _ds_item,
                name: _ds_item.name, tier: 0,
                message: "Drill a DEEP SOCKET into " + _ds_item.name + " for 400g + 80 dust?  ("
                    + string(array_length(_ds_item.runes)) + "/" + string(_ds_item.socket_count) + " -> "
                    + string(array_length(_ds_item.runes)) + "/" + string(_ds_item.socket_count + 1) + " sockets)",
                warn: "Once per run - and an item can only ever be deepened once."
            };
        }
    }

    // Aspect-tab state
    var _m_aslots  = variable_global_exists("aspect_slots") ? global.aspect_slots : 2;
    var _m_asocked = variable_global_exists("aspect_runes") ? array_length(global.aspect_runes) : 0;
    var _m_arows0  = _m_aslots + ((_m_aslots < aspect_slot_cap()) ? 1 : 0); // slot rows + optional unlock row

    // Forge-tab state
    var _m_groups = rune_combine_groups();
    var _m_flags  = rune_flagship_ids();

    // Row count for the active tab + phase (navigation + mouse hit-test)
    var _m_rows = 1;
    if (maren_tab == 0) {
        if (maren_phase == 0)      _m_rows = max(1, array_length(_m_slots));
        else if (maren_phase == 1) _m_rows = (_m_item != undefined) ? max(1, _m_item.socket_count) : 1;
        else                       _m_rows = max(1, array_length(_m_gear));
    } else if (maren_tab == 1) {
        if (maren_phase == 0)      _m_rows = max(1, _m_arows0);
        else                       _m_rows = max(1, array_length(_m_asp));
    } else if (maren_tab == 2) {
        if (maren_phase == 0)      _m_rows = 6;                                       // Combine/Split/Craft/Sunder/Runeheart/Awaken (Temper moved to Dorn 08-08)
        else if (maren_phase == 1) _m_rows = max(1, array_length(_m_groups));         // Combine groups
        else if (maren_phase == 2) _m_rows = max(1, array_length(global.rune_inventory)); // Split list
        else if (maren_phase == 4) _m_rows = max(1, array_length(maren_core_candidates())); // Runeheart sacrifice list
        else                       _m_rows = max(1, array_length(_m_flags));          // Flagship list
    } else if (maren_tab == 3) {
        _m_rows = max(1, array_length(global.rune_inventory));                        // Runes (owned list)
    } else {
        _m_rows = 1;                                                                  // Spirits: single Release action row
    }

    // LEGENDARY FORGE - Runeheart Core checkout popup (M locked 07-28). MODAL.
    if (!variable_instance_exists(id, "maren_ck_open")) {
        maren_ck_open = false; maren_ck_rune_idx = -1;
        maren_ck_title = ""; maren_ck_body = "";
    }
    if (maren_ck_open) {
        if (input_cancel() || input_back() || input_inject_take("maren:cancel")) {
            maren_ck_open = false; maren_notification = "";
            exit;
        }
        if (input_confirm() || input_inject_take("maren:ok")) {
            maren_ck_open = false;
            var _mk_dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
            if (_mk_dust < 40) {
                maren_notification = "A Runeheart Core asks 40 dust (you have " + string(_mk_dust) + ").";
                audio_play_sound(snd_ui_error, 1, false);
            } else if (maren_ck_rune_idx >= 0 && maren_ck_rune_idx < array_length(global.rune_inventory)
                && global.rune_inventory[maren_ck_rune_idx].tier >= 3) {
                var _mk_nm = rune_title(global.rune_inventory[maren_ck_rune_idx]);
                array_delete(global.rune_inventory, maren_ck_rune_idx, 1);
                global.rune_dust -= 40;
                forge_components_ensure();
                global.forge_comp_core += 1;
                save_game();
                maren_notification = "RUNEHEART CORE forged from " + _mk_nm + ". (" + string(global.forge_comp_core) + " held)";
                audio_play_sound(snd_confirm_major, 1, false);
                ui_checkout_vfx(spr_vfx_arcane, 960, 540);
                maren_phase = 0; maren_cursor = 0; maren_scroll = 0;
            } else {
                maren_notification = "That rune is gone.";
                audio_play_sound(snd_ui_error, 1, false);
            }
            exit;
        }
        exit;   // modal - swallow everything else while the popup is up
    }

    // Esc / Backspace - step back one phase, else close the screen
    if (input_cancel() || input_back()) {
        if (maren_tab == 0 && maren_phase == 2)      { maren_phase = 1; maren_cursor = 0; maren_scroll = 0; }
        else if (maren_tab == 0 && maren_phase == 1) { maren_phase = 0; maren_item_sel = -1; maren_cursor = 0; maren_scroll = 0; }
        else if (maren_tab == 1 && maren_phase == 1) { maren_phase = 0; maren_cursor = 0; maren_scroll = 0; }
        else if (maren_tab == 2 && maren_phase > 0)  { maren_phase = 0; maren_cursor = 0; maren_scroll = 0; }
        else                                          { maren_open = false; }
        maren_notification = "";
        exit;
    }

    // Q/E (or <-/->) - switch tab (5 tabs; Q/<- left, E/-> right; resets the active flow)
    var _maren_tabchg = 0;
    if (input_tab_next() || keyboard_check_pressed(vk_right)) _maren_tabchg = 1;
    else if (input_tab_prev() || keyboard_check_pressed(vk_left)) _maren_tabchg = -1;
    if (_maren_tabchg != 0) {
        maren_tab = (maren_tab + _maren_tabchg + 5) mod 5;
        maren_phase = 0; maren_item_sel = -1; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
        exit;
    }

    // W/S - navigate rows
    if (nav_up())   { maren_cursor = wrap_index(maren_cursor - 1, _m_rows); maren_notification = ""; }
    if (nav_down()) { maren_cursor = wrap_index(maren_cursor + 1, _m_rows); maren_notification = ""; }
    maren_cursor = clamp(maren_cursor, 0, max(0, _m_rows - 1));

    // Scroll window: keep the cursor on-screen for long lists (auto-follow). Because
    // this re-derives scroll from the cursor every frame, it also self-resets to 0
    // whenever a tab/phase change sets maren_cursor back to 0. Shared with the draw.
    var _m_vis = maren_visible_rows();
    if (maren_cursor < maren_scroll)               maren_scroll = maren_cursor;
    else if (maren_cursor >= maren_scroll + _m_vis) maren_scroll = maren_cursor - _m_vis + 1;
    maren_scroll = clamp(maren_scroll, 0, max(0, _m_rows - _m_vis));

    // Mouse - tab bar (5 tabs: x=368+t*240, y=105, w=225, h=60 - MUST match
    // ui_draw_maren's bar) + row select acts immediately
    var _m_act = (input_confirm());
    if (mouse_check_button_pressed(mb_left)) {
        var _mmx = device_mouse_x_to_gui(0);
        var _mmy = device_mouse_y_to_gui(0);
        var _hit_tab = false;
        for (var _mtb = 0; _mtb < 5; _mtb++) {
            var _mtx = 368 + _mtb * 240;
            if (_mmx >= _mtx && _mmx < _mtx + 225 && _mmy >= 105 && _mmy < 165) {
                maren_tab = _mtb; maren_phase = 0; maren_item_sel = -1; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                _hit_tab = true; break;
            }
        }
        // Rows: list starts at y=285, pitch from the shared vendor metrics
        // (72 default, taller on Large - M 08-14 font pass), x 300..1620. The
        // clicked screen-row maps to data index maren_scroll + row (windowed list).
        if (!_hit_tab && _mmx >= 300 && _mmx < 1620) {
            var _row = floor((_mmy - 285) / ui_vendor_row_pitch());
            if (_row >= 0 && _row < _m_vis) {
                var _click_idx = maren_scroll + _row;
                if (_click_idx < _m_rows) { maren_cursor = _click_idx; _m_act = true; }
            }
        }
    }

    // Enter / click - perform the row action
    if (_m_act) {
        if (maren_tab == 0) {
            if (maren_phase == 0) {
                if (array_length(_m_slots) > 0) {
                    maren_item_sel = _m_slots[clamp(maren_cursor, 0, array_length(_m_slots) - 1)];
                    maren_phase = 1; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                }
            } else if (maren_phase == 1 && _m_item != undefined) {
                var _filled = array_length(_m_item.runes);
                if (maren_cursor < _filled) {
                    // Unsocket -> confirm + 30g (rune returns to inventory unharmed).
                    var _ur = _m_item.runes[maren_cursor];
                    var _ucost = rune_socket_cost();
                    if (global.gold < _ucost) {
                        maren_notification = "Removing a rune costs " + string(_ucost) + "g - not enough gold.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        maren_confirm = {
                            action: "unsocket", cost: _ucost, rune_idx: maren_cursor,
                            name: _ur.name, tier: _ur.tier,
                            message: "Remove " + _ur.name + " " + rune_tier_roman(_ur.tier)
                                + " from " + _m_item.name + " for " + string(_ucost) + "g?",
                            warn: "The rune returns to your inventory unharmed."
                        };
                    }
                } else if (array_length(_m_gear) > 0) {
                    maren_phase = 2; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                } else {
                    maren_notification = "No gear runes to socket. (Aspect runes go in the Aspects tab.)";
                }
            } else if (maren_phase == 2) {
                if (array_length(_m_gear) > 0) {
                    // Socket -> confirm + 30g.
                    var _ri = _m_gear[clamp(maren_cursor, 0, array_length(_m_gear) - 1)];
                    var _rn = global.rune_inventory[_ri];
                    var _scost = rune_socket_cost();
                    if (global.gold < _scost) {
                        maren_notification = "Socketing costs " + string(_scost) + "g - not enough gold.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        maren_confirm = {
                            action: "socket", cost: _scost, rune_inv: _ri,
                            name: _rn.name, tier: _rn.tier,
                            message: "Socket " + _rn.name + " " + rune_tier_roman(_rn.tier)
                                + " into " + (_m_item != undefined ? _m_item.name : "this item")
                                + " for " + string(_scost) + "g?",
                            warn: ""
                        };
                    }
                }
            }
        } else if (maren_tab == 1) {
            // -------- ASPECTS TAB --------
            if (maren_phase == 0) {
                if (maren_cursor < _m_asocked) {
                    // Filled slot -> unsocket (confirm + 30g; rune returns to inventory).
                    var _ua = global.aspect_runes[maren_cursor];
                    var _aucost = rune_socket_cost();
                    if (global.gold < _aucost) {
                        maren_notification = "Removing a rune costs " + string(_aucost) + "g - not enough gold.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        maren_confirm = {
                            action: "aspect_unsocket", cost: _aucost, slot_idx: maren_cursor,
                            name: _ua.name, tier: _ua.tier,
                            message: "Remove " + _ua.name + " " + rune_tier_roman(_ua.tier)
                                + " from its Aspect slot for " + string(_aucost) + "g?",
                            warn: "The rune returns to your inventory unharmed."
                        };
                    }
                } else if (maren_cursor < _m_aslots) {
                    // Empty slot -> choose an aspect rune
                    if (array_length(_m_asp) > 0) {
                        maren_phase = 1; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                    } else {
                        maren_notification = "No aspect runes to socket.";
                    }
                } else {
                    // Unlock-next-slot row
                    var _res = maren_unlock_aspect_slot();
                    maren_notification = (_res == "") ? "Unlocked a new Aspect slot!" : _res;
                }
            } else if (maren_phase == 1) {
                if (array_length(_m_asp) > 0) {
                    // Aspect socket -> confirm + 30g.
                    var _ai  = _m_asp[clamp(maren_cursor, 0, array_length(_m_asp) - 1)];
                    var _rna = global.rune_inventory[_ai];
                    var _ascost = rune_socket_cost();
                    if (global.gold < _ascost) {
                        maren_notification = "Socketing costs " + string(_ascost) + "g - not enough gold.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        maren_confirm = {
                            action: "aspect_socket", cost: _ascost, rune_inv: _ai,
                            name: _rna.name, tier: _rna.tier,
                            message: "Socket " + _rna.name + " " + rune_tier_roman(_rna.tier)
                                + " into an Aspect slot for " + string(_ascost) + "g?",
                            warn: ""
                        };
                    }
                }
            }
        } else if (maren_tab == 2) {
            // -------- FORGE TAB --------
            if (maren_phase == 0) {
                // Sub-menu: 0 Combine, 1 Split, 2 Craft Flagship, 3 Sunder
                // Legendary, 4 Runeheart Core, 5 Awaken Legendary.
                // TEMPER left this menu on 08-08 - it lives on Dorn's TEMPER tab now
                // (smith work, not rune work). Keep this order in sync with the
                // _menu array in scr_ui's Maren forge draw.
                if (maren_cursor == 5) {
                    // AWAKEN (08-04 dormant legendaries): pick a dormant find.
                    var _awk_cands = item_picker_candidates_dormant();
                    if (array_length(_awk_cands) == 0) {
                        maren_notification = "No dormant legendaries - the true ones never slept.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        item_picker_open("maren_awaken", {}, _awk_cands);
                        maren_notification = "";
                    }
                } else if (maren_cursor == 4) {
                    if (array_length(maren_core_candidates()) == 0) {
                        maren_notification = "A Runeheart Core asks a tier-III or better rune - you hold none unsocketed.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        maren_phase = 4; maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                    }
                } else if (maren_cursor == 3) {
                    // SUNDER (M 07-28 legendary sinks): pick a legendary via the
                    // shared picker; the picker resolve pays out ingot/dust/rune.
                    var _snd_cands = item_picker_candidates_by_rarity(4);
                    if (array_length(_snd_cands) == 0) {
                        maren_notification = "You hold no unequipped legendaries to sunder.";
                        audio_play_sound(snd_ui_error, 1, false);
                    } else {
                        item_picker_open("maren_sunder", {}, _snd_cands);
                        maren_notification = "";
                    }
                } else {
                    maren_phase = clamp(maren_cursor, 0, 2) + 1;
                    maren_cursor = 0; maren_scroll = 0; maren_notification = "";
                }
            } else if (maren_phase == 1) {
                // Combine -> confirm (consumes 3 runes).
                if (array_length(_m_groups) > 0) {
                    var _grp  = _m_groups[clamp(maren_cursor, 0, array_length(_m_groups) - 1)];
                    var _ccost = rune_combine_cost(_grp.tier);
                    maren_confirm = {
                        action: "combine", grp_id: _grp.id, grp_tier: _grp.tier, name: _grp.name,
                        message: "Combine 3x " + _grp.name + " " + rune_tier_roman(_grp.tier)
                            + " into 1x " + _grp.name + " " + rune_tier_roman(_grp.tier + 1)
                            + " for " + string(_ccost.gold) + "g + " + string(_ccost.dust) + " dust?",
                        warn: "This DESTROYS all 3 source runes to forge the upgrade."
                    };
                }
            } else if (maren_phase == 2) {
                // Split -> confirm (breaks the rune down; net loss).
                if (array_length(global.rune_inventory) > 0) {
                    var _sidx = clamp(maren_cursor, 0, array_length(global.rune_inventory) - 1);
                    var _sr2  = global.rune_inventory[_sidx];
                    var _spcost = rune_split_cost();
                    var _spdust = rune_split_dust(_sr2.tier);
                    var _spwarn = (_sr2.tier > 1)
                        ? ("This DESTROYS the rune, returning one " + _sr2.name + " " + rune_tier_roman(_sr2.tier - 1)
                           + " + " + string(_spdust) + " dust (you lose a tier).")
                        : ("This DESTROYS the rune for only " + string(_spdust) + " dust - no rune is returned.");
                    maren_confirm = {
                        action: "split", rune_inv: _sidx, name: _sr2.name, tier: _sr2.tier,
                        message: "Split " + _sr2.name + " " + rune_tier_roman(_sr2.tier)
                            + " for " + string(_spcost.gold) + "g?",
                        warn: _spwarn
                    };
                    maren_cursor = clamp(maren_cursor, 0, max(0, array_length(global.rune_inventory) - 1));
                }
            } else if (maren_phase == 4) {
                // RUNEHEART CORE (LEGENDARY FORGE, M locked 07-28): pick the
                // tier-III+ rune to sacrifice; commit via the checkout popup.
                var _mc_cands = maren_core_candidates();
                if (array_length(_mc_cands) > 0) {
                    var _mc_i  = _mc_cands[clamp(maren_cursor, 0, array_length(_mc_cands) - 1)];
                    var _mc_rn = global.rune_inventory[_mc_i];
                    maren_ck_open     = true;
                    maren_ck_rune_idx = _mc_i;
                    maren_ck_title    = "FORGE A RUNEHEART CORE?";
                    maren_ck_body     = rune_title(_mc_rn) + " + 40 rune dust\nbecome Maren's share of the LEGENDARY FORGE. The rune is consumed.";
                    maren_notification = "";
                }
            } else {
                // Craft Flagship
                if (array_length(_m_flags) > 0) {
                    var _fid  = _m_flags[clamp(maren_cursor, 0, array_length(_m_flags) - 1)];
                    var _fdef = rune_get(_fid);
                    var _fres = maren_craft_flagship(_fid);
                    maren_notification = (_fres == "")
                        ? ("Forged the " + _fdef.name + " flagship rune!")
                        : _fres;
                }
            }
        } else if (maren_tab == 4) {
            // -------- SPIRITS TAB (Banshee in a Bottle release) --------
            banshee_init();
            if (global.banshee_banked <= 0) {
                maren_notification = "No bottled spirits to free. Bottles ride out of the dungeon with a living extractor.";
                audio_play_sound(snd_ui_error, 1, false);
            } else {
                var _bb_all_owned = (array_length(global.music_unlocked) >= array_length(music_track_catalog()));
                maren_confirm = {
                    action: "banshee_release",
                    message: "Free the spirit from a Banshee in a Bottle?",
                    warn: _bb_all_owned
                        ? "Every song is already yours - this spirit leaves 25 Rune Dust in gratitude."
                        : "Its parting song becomes a music track you can choose in Settings.",
                    cost: 0
                };
            }
        }
        // Runes tab is read-only.
    }

    exit;
}


// =============================================================================
// SABLE THE ALCHEMIST - Salvage / Brew / Upgrade (see SYSTEMS_SABLE.md).
// Layout constants here MUST match ui_draw_sable_screen() in scr_ui.
// =============================================================================
if (variable_instance_exists(id, "sable_open") && sable_open && !menu_open && !forge_result_up()
    && cursed_ritual_t < 0 && npc_tour_step < 0) {
    rune_inventory_sort();   // keep the rune/aspect pool alphabetical (display + index ops read this)
    var _s_gear   = sable_salvageable_gear();
    var _s_rinv   = variable_global_exists("rune_inventory") ? global.rune_inventory : [];
    var _s_brew   = sable_brew_catalog_priced();
    var _s_groups = sable_upgrade_groups();

    // Transmute selection state (phase 3 of tab 0 - M 07-27 rune sink) + the
    // checkout-popup descriptor (what a confirmed sable_confirm will DO) + the
    // Chaotic Brew pick-3 state (tab 2, M 07-28).
    if (!variable_instance_exists(id, "sable_trans_sel")) {
        sable_trans_sel     = [];
        sable_confirm_kind  = "";
        sable_confirm_idx   = -1;
        sable_confirm_label = "";
        sable_confirm_title = "";
        sable_confirm_body  = "";
        // Colored subject block on the checkout popup (M 08-14: name the thing
        // being consumed IN ITS COLOR, effect line under it).
        sable_confirm_subject     = "";
        sable_confirm_subject_col = undefined;
        sable_confirm_subject_sub = "";
        // Result TOAST + transmute rune-reveal card (M 08-15: results were a
        // bottom line that collided with the legend and caught no one's eye).
        sable_toast_msg     = "";
        sable_toast_timer   = 0;
        sable_result_rune   = undefined;
        sable_result_timer  = 0;
        sable_chaos_open    = false;
        sable_chaos_sel     = [];
        sable_chaos_kind    = "chaotic";   // "chaotic" | "quint" (LEGENDARY FORGE)
    }
    if (sable_toast_timer > 0)  sable_toast_timer--;
    if (sable_result_timer > 0) sable_result_timer--; else sable_result_rune = undefined;

    // Row count for the active tab + phase
    var _s_rows = 1;
    if (sable_tab == 0) {
        if (sable_phase == 0)      _s_rows = 3;                                    // Gear / Runes / Transmute menu
        else if (sable_phase == 1) _s_rows = max(1, array_length(_s_gear));        // Gear list
        else                       _s_rows = max(1, array_length(_s_rinv));        // Rune list (salvage AND transmute)
    } else if (sable_tab == 1) {
        _s_rows = max(1, array_length(_s_brew));                                   // Brew list
    } else if (sable_tab == 2) {
        // Fusion groups + the always-present CHAOTIC BREW + QUINTESSENCE rows;
        // in pick mode the rows are the combined stash+pouch pool (08-11).
        _s_rows = sable_chaos_open
            ? max(1, array_length(sable_potion_pool()))
            : (array_length(_s_groups) + 2);
    } else {
        _s_rows = 3;    // Rebirth: class / attunement (M 07-29) / cursed (M 07-28)
    }

    // Esc / Backspace - cancel a pending salvage confirm first, then step back
    // (Salvage sub-list -> menu), else close.
    if (input_cancel() || input_back()) {
        if (sable_confirm) { sable_confirm = false; sable_notification = ""; exit; }
        if (sable_tab == 0 && sable_phase > 0)  { sable_phase = 0; sable_cursor = 0; sable_trans_sel = []; }
        else if (sable_tab == 2 && sable_chaos_open) { sable_chaos_open = false; sable_chaos_sel = []; sable_cursor = 0; }
        else                                    { sable_open = false; }
        sable_notification = "";
        exit;
    }

    // CHECKOUT MODAL (M 07-27 standing rule): while the confirm popup is up, only
    // commit (Enter / CONFIRM button) or cancel (Esc above / CANCEL button) are
    // heard - nav, tabs and row toggles are locked so the pending action can't
    // shift under the popup (the old bottom-line confirm let Enter deselect the
    // very rune it was about to transmute - M's bug report).
    if (sable_confirm) {
        if (input_inject_take("sable:cancel")) {
            sable_confirm = false; sable_notification = "";
            exit;
        }
        if (input_confirm() || input_inject_take("sable:ok")) {
            sable_confirm = false;
            switch (sable_confirm_kind) {
                // SUCCESSES speak through the boxed result TOAST (top of the list
                // area, drawn topmost) - the old bottom notification line collided
                // with the key legend and caught no one's eye (M 08-15). Errors
                // keep the bottom line.
                case "gear": {
                    var _gd = sable_salvage_gear_at(sable_confirm_idx);
                    if (_gd >= 0) {
                        sable_toast_msg   = "Salvaged " + sable_confirm_label + ":  +" + string(_gd) + " Rune Dust!";
                        sable_toast_timer = 210;
                        sable_notification = "";
                        audio_play_sound(snd_sell, 1, false); affinity_add("sable", 2);
                    } else {
                        sable_notification = "Could not salvage.";
                    }
                    sable_cursor = clamp(sable_cursor, 0, max(0, array_length(sable_salvageable_gear()) - 1));
                } break;
                case "rune": {
                    var _rd = sable_salvage_rune_at(sable_confirm_idx);
                    if (_rd >= 0) {
                        sable_toast_msg   = "Scrapped " + sable_confirm_label + ":  +" + string(_rd) + " Rune Dust!";
                        sable_toast_timer = 210;
                        sable_notification = "";
                        audio_play_sound(snd_sell, 1, false); affinity_add("sable", 2);
                    } else {
                        sable_notification = "Could not scrap.";
                    }
                    sable_cursor = clamp(sable_cursor, 0, max(0, array_length(global.rune_inventory) - 1));
                } break;
                case "transmute": {
                    var _t_out = { title: "", rune: undefined };
                    var _t_res = sable_transmute_runes(sable_trans_sel, _t_out);
                    if (_t_res == "") {
                        // Reveal CARD with the new rune's icon + effect (M 08-15:
                        // "it plays the animation then i have no idea what i got").
                        sable_result_rune  = _t_out.rune;
                        sable_result_timer = 300;
                        sable_toast_msg    = "The cauldron yields...";
                        sable_toast_timer  = 300;
                        sable_notification = "";
                        audio_play_sound(snd_confirm_major, 1, false);
                        ui_checkout_vfx(spr_vfx_void, 960, 540);   // Gigapack cauldron burst
                        affinity_add("sable", 2);   // function-use drip (transmute)
                        sable_trans_sel = [];
                        sable_cursor = clamp(sable_cursor, 0, max(0, array_length(global.rune_inventory) - 1));
                    } else {
                        sable_notification = _t_res;
                        audio_play_sound(snd_ui_error, 1, false);
                    }
                } break;
                case "fusion": {
                    var _f_res = sable_upgrade(sable_confirm_label);
                    if (_f_res == "") {
                        sable_toast_msg   = "Fused 3x " + sable_confirm_label + " into their improved form!";
                        sable_toast_timer = 210;
                        sable_notification = "";
                        audio_play_sound(snd_npc_confirm, 1, false);
                        affinity_add("sable", 2);   // function-use drip (upgrade)
                        sable_cursor = 0;
                    } else {
                        sable_notification = _f_res;
                        audio_play_sound(snd_ui_error, 1, false);
                    }
                } break;
                case "chaotic": {
                    var _c_res = sable_chaotic_fuse(sable_chaos_sel);
                    if (_c_res == "") {
                        sable_toast_msg   = "The cauldron shudders... a CHAOTIC BREW settles out!";
                        sable_toast_timer = 240;
                        sable_notification = "";
                        audio_play_sound(snd_confirm_major, 1, false);
                        ui_checkout_vfx(spr_vfx_void, 960, 540);   // Gigapack cauldron burst
                        affinity_add("sable", 2);   // function-use drip (chaos)
                        sable_chaos_sel  = [];
                        sable_chaos_open = false;
                        sable_cursor     = 0;
                    } else {
                        sable_notification = _c_res;
                        audio_play_sound(snd_ui_error, 1, false);
                    }
                } break;
                case "quint": {
                    // LEGENDARY FORGE component (M locked 07-28).
                    var _q_res = sable_quintessence_distill(sable_chaos_sel);
                    if (_q_res == "") {
                        forge_components_ensure();
                        sable_toast_msg   = "QUINTESSENCE distilled!  (" + string(global.forge_comp_quint) + " held - Sable's forge share is ready)";
                        sable_toast_timer = 240;
                        sable_notification = "";
                        audio_play_sound(snd_confirm_major, 1, false);
                        ui_checkout_vfx(spr_vfx_arcane, 960, 540);
                        affinity_add("sable", 2);   // function-use drip (forge craft)
                        sable_chaos_sel  = [];
                        sable_chaos_open = false;
                        sable_cursor     = 0;
                    } else {
                        sable_notification = _q_res;
                        audio_play_sound(snd_ui_error, 1, false);
                    }
                } break;
            }
            exit;
        }
        exit;   // modal - swallow everything else while the popup is up
    }

    // Q/E (or <-/->) - switch tab (3 tabs; Q/<- left, E/-> right)
    var _sable_tabchg = 0;
    if (input_tab_next() || keyboard_check_pressed(vk_right)) _sable_tabchg = 1;
    else if (input_tab_prev() || keyboard_check_pressed(vk_left)) _sable_tabchg = -1;
    if (_sable_tabchg != 0) {
        sable_tab = (sable_tab + _sable_tabchg + 4) mod 4;
        sable_phase = 0; sable_cursor = 0; sable_notification = ""; sable_confirm = false;
        exit;
    }

    // W/S - navigate (moving the cursor cancels a pending salvage confirm)
    if (nav_up())   { sable_cursor = wrap_index(sable_cursor - 1, _s_rows); sable_notification = ""; sable_confirm = false; }
    if (nav_down()) { sable_cursor = wrap_index(sable_cursor + 1, _s_rows); sable_notification = ""; sable_confirm = false; }
    sable_cursor = clamp(sable_cursor, 0, max(0, _s_rows - 1));

    // Mouse - tab bar (x=345+t*200) + row select
    var _s_act = (input_confirm());
    if (mouse_check_button_pressed(mb_left)) {
        var _smx = device_mouse_x_to_gui(0);
        var _smy = device_mouse_y_to_gui(0);
        var _s_hit_tab = false;
        for (var _stb = 0; _stb < 4; _stb++) {
            var _stx = 368 + _stb * 300;   // centred on x960 (matches the draw side)
            if (_smx >= _stx && _smx < _stx + 285 && _smy >= 105 && _smy < 165) {
                sable_tab = _stb; sable_phase = 0; sable_cursor = 0; sable_notification = "";
                _s_hit_tab = true; break;
            }
        }
        if (!_s_hit_tab && _smx >= 300 && _smx < 1620) {
            // Every Sable list starts at the standard y285 (08-15: the fusion
            // tab's diagram panel is gone, its rows moved up to match).
            var _srow_base = 285;
            var _srow = floor((_smy - _srow_base) / ui_vendor_row_pitch());
            // The salvage gear/rune lists (tab 0, phase 1/2) are WINDOWED in the draw
            // (ui_list_window_first, _svis = ui_vendor_visible_rows(9)) - map the
            // clicked screen row back to the real list index via the same window
            // offset. Other tabs aren't windowed (short lists) so _sfirst stays 0.
            // Capacity + pitch come from the shared vendor metrics (M 08-14 font
            // pass) so Large-mode clicks land on the row they visually hit.
            var _s_cap = ui_vendor_visible_rows(9);
            var _sfirst = 0;
            var _svis_now = _s_rows;
            if (sable_tab == 0 && sable_phase >= 1) {
                // phase 1 gear / 2 rune / 3 transmute - separate scroll state each
                var _sid  = (sable_phase == 1) ? "sable_gear" : ((sable_phase == 2) ? "sable_rune" : "sable_trans");
                _sfirst   = ui_list_window(_sid, sable_cursor, _s_rows, _s_cap);
                _svis_now = min(_s_rows - _sfirst, _s_cap);
            } else if (sable_tab == 1) {
                // Brew tab windowed since the 07-28 catalog expansion (18 recipes).
                _sfirst   = ui_list_window("sable_brew", sable_cursor, _s_rows, _s_cap);
                _svis_now = min(_s_rows - _sfirst, _s_cap);
            } else if (sable_tab == 2 && sable_chaos_open) {
                // Chaotic Brew pick-3 list windows over the whole potion pouch.
                _sfirst   = ui_list_window("sable_chaos", sable_cursor, _s_rows, _s_cap);
                _svis_now = min(_s_rows - _sfirst, _s_cap);
            }
            if (_srow >= 0 && _srow < _svis_now) {
                var _sidx = clamp(_sfirst + _srow, 0, _s_rows - 1);
                if (sable_cursor != _sidx) sable_confirm = false;   // clicking a new row cancels a pending salvage confirm
                sable_cursor = _sidx; _s_act = true;
            }
        }
    }

    // Enter / click - perform the row action
    if (_s_act) {
        if (sable_tab == 0) {
            if (sable_phase == 0) {
                sable_phase = sable_cursor + 1; sable_cursor = 0; sable_notification = "";
                sable_trans_sel = [];
            } else if (sable_phase == 1) {
                if (array_length(_s_gear) > 0) {
                    // Enter arms the checkout popup - the commit lives in the modal
                    // handler above (M 07-27 standing rule: popup, not bottom text).
                    var _gsel = clamp(sable_cursor, 0, array_length(_s_gear) - 1);
                    var _gname = _s_gear[_gsel].item.name;
                    var _grar  = _s_gear[_gsel].item.rarity;
                    var _gprev = sable_salvage_gear_dust(_grar);
                    sable_confirm       = true;
                    sable_confirm_kind  = "gear";
                    sable_confirm_idx   = _gsel;
                    sable_confirm_label = _gname;
                    sable_confirm_title = "SALVAGE THIS GEAR?";
                    sable_confirm_subject     = _gname;
                    sable_confirm_subject_col = item_rarity_color(_grar);
                    sable_confirm_subject_sub = "[" + item_rarity_name(_grar) + "]";
                    sable_confirm_body  = "Melts down for " + string(_gprev) + " rune dust. It cannot be reclaimed.";
                    sable_notification  = "";
                }
            } else if (sable_phase == 2) {
                if (array_length(_s_rinv) > 0) {
                    var _rsel = clamp(sable_cursor, 0, array_length(_s_rinv) - 1);
                    var _rname = _s_rinv[_rsel].name + " " + rune_tier_roman(_s_rinv[_rsel].tier);
                    var _rprev = sable_salvage_rune_dust(_s_rinv[_rsel].tier);
                    sable_confirm       = true;
                    sable_confirm_kind  = "rune";
                    sable_confirm_idx   = _rsel;
                    sable_confirm_label = _rname;
                    sable_confirm_title = "SCRAP THIS RUNE?";
                    // Subject block: rune in its glyph color, effect line under it
                    // (M 08-14: the old name\n-body wrap read as a broken sentence).
                    sable_confirm_subject     = _rname;
                    sable_confirm_subject_col = rune_glyph_color(_s_rinv[_rsel].id);
                    sable_confirm_subject_sub = rune_effect(_s_rinv[_rsel]);
                    sable_confirm_body  = "Scrapped whole for " + string(_rprev) + " rune dust. Nothing else comes back.";
                    sable_notification  = "";
                }
            } else {
                // -------- TRANSMUTE (phase 3, M 07-27) -------- pick any 3 SAME-TIER
                // runes -> 1 random next-tier rune. Enter toggles a rune in/out of
                // the pick; the 3rd pick (or Enter with 3 already picked) arms the
                // checkout POPUP - the commit lives in the modal handler above, so
                // Enter can never deselect the rune it's committing (M's bug).
                if (array_length(_s_rinv) > 0) {
                    var _tsel   = clamp(sable_cursor, 0, array_length(_s_rinv) - 1);
                    var _t_pos  = -1;
                    for (var _ti = 0; _ti < array_length(sable_trans_sel); _ti++) {
                        if (sable_trans_sel[_ti] == _tsel) { _t_pos = _ti; break; }
                    }
                    var _t_arm = false;
                    if (_t_pos >= 0) {
                        array_delete(sable_trans_sel, _t_pos, 1);   // deselect
                        sable_notification = "";
                    } else if (array_length(sable_trans_sel) < 3) {
                        if (array_length(sable_trans_sel) > 0
                            && _s_rinv[sable_trans_sel[0]].tier != _s_rinv[_tsel].tier) {
                            sable_notification = "All three must share a tier.";
                            audio_play_sound(snd_ui_error, 1, false);
                        } else {
                            array_push(sable_trans_sel, _tsel);
                            _t_arm = (array_length(sable_trans_sel) == 3);
                        }
                    } else {
                        _t_arm = true;   // 3 already picked - Enter re-opens the popup
                    }
                    if (_t_arm) {
                        var _tt = _s_rinv[sable_trans_sel[0]].tier;
                        var _t_names = "";
                        for (var _tn = 0; _tn < 3; _tn++) {
                            _t_names += (_tn > 0 ? ", " : "") + rune_title(_s_rinv[sable_trans_sel[_tn]]);
                        }
                        sable_confirm       = true;
                        sable_confirm_kind  = "transmute";
                        sable_confirm_title = "TRANSMUTE 3 RUNES?";
                        sable_confirm_subject     = _t_names;
                        sable_confirm_subject_col = rune_glyph_color(_s_rinv[sable_trans_sel[0]].id);
                        sable_confirm_subject_sub = "";
                        sable_confirm_body  = "They melt into ONE RANDOM tier-" + rune_tier_roman(_tt + 1)
                            + " rune for " + string(sable_transmute_cost(_tt)) + "g. All three are consumed.";
                        sable_notification  = "";
                    }
                }
            }
        } else if (sable_tab == 1) {
            if (array_length(_s_brew) > 0) {
                var _bsel = clamp(sable_cursor, 0, array_length(_s_brew) - 1);
                var _bdef = _s_brew[_bsel];
                var _bres = sable_brew(_bdef.id);
                sable_notification = (_bres == "") ? ("Brewed " + _bdef.name + "!") : _bres;
                if (_bres == "") audio_play_sound(snd_npc_confirm, 1, false);
                if (_bres == "") affinity_add("sable", 2);   // function-use drip (brew)
            }
        } else if (sable_tab == 2) {
            if (sable_chaos_open) {
                // -------- CHAOTIC BREW pick-3 (M 07-28) -------- Enter toggles a
                // potion; the 3rd pick arms the checkout popup (commit in the
                // modal handler above). ANY mix - that's the point. The list is
                // the combined stash+pouch pool (08-11): indices are combined
                // indices, matching what sable_chaotic_fuse expects.
                var _ch_inv = sable_potion_pool();
                if (array_length(_ch_inv) > 0) {
                    var _chsel = clamp(sable_cursor, 0, array_length(_ch_inv) - 1);
                    var _ch_pos = -1;
                    for (var _chi = 0; _chi < array_length(sable_chaos_sel); _chi++) {
                        if (sable_chaos_sel[_chi] == _chsel) { _ch_pos = _chi; break; }
                    }
                    var _ch_arm = false;
                    if (_ch_pos >= 0) {
                        array_delete(sable_chaos_sel, _ch_pos, 1);   // deselect
                        sable_notification = "";
                    } else if (array_length(sable_chaos_sel) < 3) {
                        array_push(sable_chaos_sel, _chsel);
                        _ch_arm = (array_length(sable_chaos_sel) == 3);
                    } else {
                        _ch_arm = true;   // 3 already picked - re-open the popup
                    }
                    if (_ch_arm) {
                        var _ch_names = "";
                        for (var _chn = 0; _chn < 3; _chn++) {
                            _ch_names += (_chn > 0 ? ", " : "") + _ch_inv[sable_chaos_sel[_chn]].it.name;
                        }
                        sable_confirm = true;
                        sable_confirm_subject     = _ch_names;
                        sable_confirm_subject_col = make_color_rgb(150, 230, 170);   // Sable's brew green
                        sable_confirm_subject_sub = "";
                        if (sable_chaos_kind == "quint") {
                            // LEGENDARY FORGE component (M locked 07-28).
                            sable_confirm_kind  = "quint";
                            sable_confirm_title = "DISTILL QUINTESSENCE?";
                            sable_confirm_body  = "They boil down into ONE Quintessence for "
                                + string(forge_quint_cost()) + "g - Sable's share of the Legendary Forge.";
                        } else {
                            var _ch_cost = sable_chaotic_cost();
                            sable_confirm_kind  = "chaotic";
                            sable_confirm_title = "BREW SOMETHING CHAOTIC?";
                            sable_confirm_body  = "They swirl into ONE Chaotic Brew for "
                                + string(_ch_cost.gold) + "g + " + string(_ch_cost.dust)
                                + " dust. What it does is decided when you drink it - and sometimes it bites.";
                        }
                        sable_notification  = "";
                    }
                }
            } else if (sable_cursor >= array_length(_s_groups)) {
                // The always-present rows: CHAOTIC BREW (groups) and QUINTESSENCE
                // (groups+1, LEGENDARY FORGE component) - both enter pick-3 mode.
                var _ch_have = array_length(sable_potion_pool());   // stash + pouch (08-11)
                var _ch_kind = (sable_cursor == array_length(_s_groups)) ? "chaotic" : "quint";
                if (_ch_have < 3) {
                    sable_notification = "You need at least 3 potions (you hold " + string(_ch_have) + ").";
                    audio_play_sound(snd_ui_error, 1, false);
                } else {
                    sable_chaos_open = true; sable_chaos_sel = []; sable_cursor = 0;
                    sable_chaos_kind = _ch_kind;
                    sable_notification = "";
                }
            } else if (array_length(_s_groups) > 0) {
                // Fusion - arms the checkout popup (standing rule: no instant
                // 3-potion spends). Recipes now list ALWAYS (07-28); a row you
                // can't afford yet just says how many you're short.
                var _usel = clamp(sable_cursor, 0, array_length(_s_groups) - 1);
                var _ug   = _s_groups[_usel];
                if (_ug.count < 3) {
                    sable_notification = "Need 3x " + _ug.from + " (you hold " + string(_ug.count) + ") - find, buy or brew more.";
                    audio_play_sound(snd_ui_error, 1, false);
                } else {
                    var _uc = sable_upgrade_cost();
                    sable_confirm       = true;
                    sable_confirm_kind  = "fusion";
                    sable_confirm_label = _ug.from;
                    sable_confirm_title = "FUSE THESE POTIONS?";
                    sable_confirm_subject     = "3x " + _ug.from + "  ->  1x " + _ug.to;
                    sable_confirm_subject_col = make_color_rgb(150, 230, 170);   // Sable's brew green
                    sable_confirm_subject_sub = "";
                    sable_confirm_body  = "Fused for " + string(_uc.gold) + "g + " + string(_uc.dust)
                        + " dust. The three are consumed.";
                    sable_notification  = "";
                }
            }
        } else {
            // -------- REBIRTH TAB -------- row 0 = class rebirth (shared picker);
            // row 1 = ATTUNEMENT rebirth (M 07-29): re-set an item's stat req;
            // row 2 = CURSED REBIRTH (M 07-28 legendary sinks).
            if (sable_cursor == 0) {
                var _reb = item_picker_candidates_class_specific();
                if (array_length(_reb) == 0) {
                    sable_notification = "You hold no class-specific gear (Uncommon+) to reforge.";
                } else {
                    item_picker_open("alch_rebirth", {}, _reb);
                }
            } else if (sable_cursor == 1) {
                var _sqc = item_picker_candidates_statreq();
                if (array_length(_sqc) == 0) {
                    sable_notification = "Nothing you hold carries a stat requirement (Rare+ gear gates).";
                    audio_play_sound(snd_ui_error, 1, false);
                } else {
                    item_picker_open("statreq_rebirth", {}, _sqc);
                }
            } else {
                var _crc = item_picker_candidates_by_rarity(4);
                if (array_length(_crc) == 0) {
                    sable_notification = "You hold no unequipped legendaries to offer the dark.";
                    audio_play_sound(snd_ui_error, 1, false);
                } else {
                    item_picker_open("cursed_rebirth", {}, _crc);
                }
            }
        }
    }

    exit;
}


// =============================================================================
// VAEL THE AESTHETE - transmog / skin selection (see SYSTEMS_VAEL.md).
// Single list: Enter buys an unowned skin or equips an owned one.
// Layout constants here MUST match ui_draw_vael_screen() in scr_ui.
// =============================================================================
if (variable_instance_exists(id, "vael_open") && vael_open && !menu_open && npc_tour_step < 0) {
    var _v_cat  = vael_skin_catalog_visible();   // class-gated view - MUST match the draw (08-14)
    var _v_rows = max(1, array_length(_v_cat));

    // REWEAVE tab state (moved from Vex trainer tab 5, M 07-28 - "the term fits
    // her and she needs more rolls").
    if (!variable_instance_exists(id, "vael_rw_cursor")) {
        vael_rw_cursor = 0; vael_rw_detail = false; vael_rw_name = "";
        vael_confirm = false; vael_confirm_title = ""; vael_confirm_body = "";
    }

    if (input_cancel() || input_back()) {
        if (vael_confirm)   { vael_confirm = false; vael_notification = ""; exit; }
        if (vael_rw_detail) { vael_rw_detail = false; exit; }
        vael_open = false; vael_notification = "";
        exit;
    }

    // --- Tab switching (Q/E step left/right or click the tab headers; geometry
    //     matches ui_draw_vael_screen). 0 Skins / 1 Portrait / 2 Tints / 3 Reweave. ---
    var _vt_prev = vael_tab;
    if (input_tab_prev()) vael_tab = max(0, vael_tab - 1);
    if (input_tab_next()) vael_tab = min(3, vael_tab + 1);
    if (mouse_check_button_pressed(mb_left)) {
        var _vtm_x = device_mouse_x_to_gui(0);
        var _vtm_y = device_mouse_y_to_gui(0);
        if (_vtm_y >= 96 && _vtm_y <= 144) {
            // 4 headers centred on x960 (960 + (t - 1.5) * 240, +-108) - matches draw.
            for (var _vth = 0; _vth < 4; _vth++) {
                var _vthx = 960 + (_vth - 1.5) * 240;
                if (_vtm_x >= _vthx - 108 && _vtm_x <= _vthx + 108) vael_tab = _vth;
            }
        }
    }
    if (vael_tab != _vt_prev) {
        vael_notification = ""; vael_confirm = false; vael_rw_detail = false;
        if (vael_tab == 1) vael_portrait_cursor = clamp(global.chosen_portrait, 0, max(0, array_length(global.portrait_sprites) - 1));
    }

    // --- REWEAVE tab (3): unweave an ability's talent web; its picks return as
    // Talent Points (moved from Vex, M 07-28). Checkout POPUP per standing rule.
    if (vael_tab == 3) {
        // Tab key: mechanic explainer (ui_draw_reweave_detail) toggles.
        if (vael_rw_detail) {
            if (input_detail()) vael_rw_detail = false;
            exit;
        }
        if (input_detail()) { vael_rw_detail = true; exit; }

        // Checkout modal (M 07-27 standing rule): commit or cancel only.
        if (vael_confirm) {
            if (input_inject_take("vael:cancel")) { vael_confirm = false; vael_notification = ""; exit; }
            if (input_confirm() || input_inject_take("vael:ok")) {
                vael_confirm = false;
                // Class-trunk respec (P2, 08-05): pricier ladder - 500g + 50 dust,
                // clears ALL rows for the current class; gates re-offer one at a time.
                var _rwc_trunk = variable_instance_exists(id, "vael_rw_is_trunk") && vael_rw_is_trunk;
                var _rwc_g = _rwc_trunk ? cha_price(500) : cha_price(100);
                var _rwc_d = _rwc_trunk ? 50 : 10;
                var _rwc_dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
                if (global.gold >= _rwc_g && _rwc_dust >= _rwc_d) {
                    global.gold      -= _rwc_g;
                    global.rune_dust -= _rwc_d;
                    if (_rwc_trunk) {
                        trunk_respec(variable_global_exists("chosen_class") ? global.chosen_class : 0);
                        vael_notification = "The trunk stands bare - every class choice is open again (Abilities tab).";
                    } else {
                        ability_web_respec(vael_rw_name);
                        vael_notification = vael_rw_name + " unwoven - its Talent Points returned. Reweave from the loadout ([M]).";
                    }
                    affinity_add("vael", 2);   // function-use drip (reweave)
                    ui_checkout_vfx(spr_vfx_arcane, 900, 500);   // Gigapack unweave burst
                    save_game();
                    vael_rw_cursor    = 0;
                    audio_play_sound(snd_npc_confirm, 1, false);
                } else {
                    vael_notification = "Not enough - this costs " + string(_rwc_g) + "g + " + string(_rwc_d) + " dust.";
                    audio_play_sound(snd_ui_error, 1, false);
                }
                exit;
            }
            exit;   // modal - swallow everything else
        }

        var _rw_list = vael_reweave_rows();   // trunk row first when picks exist (P2, 08-05)
        var _rw_n    = array_length(_rw_list);
        if (_rw_n > 0) {
            if (nav_up())   { vael_rw_cursor = wrap_index(vael_rw_cursor - 1, _rw_n); vael_notification = ""; }
            if (nav_down()) { vael_rw_cursor = wrap_index(vael_rw_cursor + 1, _rw_n); vael_notification = ""; }
            vael_rw_cursor = clamp(vael_rw_cursor, 0, _rw_n - 1);

            var _rw_act = input_confirm();
            // Row taps (geometry MUST mirror ui_draw_vael_reweave_tab: x300..1500,
            // y225, 72 pitch, 10 visible, window id "vael_reweave").
            if (mouse_check_button_pressed(mb_left)) {
                var _rwm_x = device_mouse_x_to_gui(0), _rwm_y = device_mouse_y_to_gui(0);
                if (_rwm_x >= 300 && _rwm_x < 1500) {
                    var _rw_vis = ui_vendor_visible_rows(10);
                    var _rw_scr = ui_list_window("vael_reweave", vael_rw_cursor, _rw_n, _rw_vis);
                    var _rw_row = floor((_rwm_y - 225) / ui_vendor_row_pitch());
                    if (_rw_row >= 0 && _rw_row < _rw_vis) {
                        var _rw_abs = _rw_scr + _rw_row;
                        if (_rw_abs < _rw_n) {
                            if (vael_rw_cursor == _rw_abs) _rw_act = true;
                            else { vael_rw_cursor = _rw_abs; vael_notification = ""; }
                        }
                    }
                }
            }

            if (_rw_act) {
                var _rw   = _rw_list[vael_rw_cursor];
                var _rw_t = variable_struct_exists(_rw, "is_trunk") && _rw.is_trunk;
                var _rw_g = _rw_t ? cha_price(500) : cha_price(100);
                var _rw_dc = _rw_t ? 50 : 10;
                var _dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
                if (global.gold < _rw_g) {
                    vael_notification = "Not enough gold - this costs " + string(_rw_g) + "g + " + string(_rw_dc) + " dust.";
                    audio_play_sound(snd_ui_error, 1, false);
                } else if (_dust < _rw_dc) {
                    vael_notification = "Need " + string(_rw_dc) + " rune dust (you have " + string(_dust) + ") - salvage at Sable or Maren.";
                    audio_play_sound(snd_ui_error, 1, false);
                } else if (_rw_t) {
                    vael_rw_name       = _rw.name;
                    vael_rw_is_trunk   = true;
                    vael_confirm       = true;
                    vael_confirm_title = "UNMAKE THE CLASS TRUNK?";
                    vael_confirm_body  = "All " + string(_rw.picks) + " sealed class choice" + (_rw.picks == 1 ? "" : "s")
                        + " reopen for " + string(_rw_g) + "g + 50 rune dust.\nEvery row re-offers its this-or-that on the Abilities tab. Nothing else is touched.";
                    vael_notification  = "";
                } else {
                    vael_rw_name       = _rw.name;
                    vael_rw_is_trunk   = false;
                    vael_confirm       = true;
                    vael_confirm_title = "REWEAVE THIS ABILITY?";
                    vael_confirm_body  = _rw.name + " unweaves for " + string(_rw_g) + "g + 10 rune dust.\nIts "
                        + string(_rw.picks) + " woven pick" + (_rw.picks == 1 ? "" : "s")
                        + " return as Talent Points - reweave from the loadout ([M]). Cast progress is never lost.";
                    vael_notification  = "";
                }
            }
        }
        exit;
    }

    // --- Portrait tab: carousel browse + 100g change ---
    if (vael_tab == 1) {
        var _p_cnt = max(1, array_length(global.portrait_sprites));
        if (nav_left())  { vael_portrait_cursor = wrap_index(vael_portrait_cursor - 1, _p_cnt); vael_notification = ""; }
        if (nav_right()) { vael_portrait_cursor = wrap_index(vael_portrait_cursor + 1, _p_cnt); vael_notification = ""; }
        vael_portrait_cursor = clamp(vael_portrait_cursor, 0, _p_cnt - 1);

        if (input_confirm()) {
            // Vael Companion perk: portrait changes are free ("for you? always").
            // Private Gallery (rank 2, M-locked 08-15): one free change per run.
            var _pg_free = variable_global_exists("vael_portrait_free") && global.vael_portrait_free
                        && npc_rank("vael") >= 2;
            var _pcost = (affinity_at_least("vael", 3) || _pg_free) ? 0 : 100;
            if (vael_portrait_cursor == global.chosen_portrait) {
                vael_notification = "That's already your portrait.";
            } else if (global.gold >= _pcost) {
                global.gold -= _pcost;
                global.chosen_portrait = vael_portrait_cursor;
                if (_pcost == 0 && _pg_free && !affinity_at_least("vael", 3)) {
                    global.vael_portrait_free = false;   // the gallery sitting is spent
                    vael_notification = "Portrait changed!  (Private Gallery - on the house this run)";
                } else {
                    vael_notification = (_pcost > 0) ? "Portrait changed!  (-100g)" : "Portrait changed!  (her gift)";
                }
                affinity_add("vael", 2);   // function-use drip (portrait change)
            } else {
                vael_notification = "Not enough gold - you need 100g.";
                audio_play_sound(snd_ui_error, 1, false);
            }
        }
        exit;
    }

    // --- Tints tab: per-school spell palettes (expression #4). List geometry mirrors
    //     the Skins tab exactly (x300..1160, y225, row 72, 10 visible). ---
    if (vael_tab == 2) {
        var _t_cat  = vael_tint_catalog();
        var _t_rows = max(1, array_length(_t_cat));

        if (nav_up())   { vael_tint_cursor = wrap_index(vael_tint_cursor - 1, _t_rows); vael_notification = ""; }
        if (nav_down()) { vael_tint_cursor = wrap_index(vael_tint_cursor + 1, _t_rows); vael_notification = ""; }
        vael_tint_cursor = clamp(vael_tint_cursor, 0, _t_rows - 1);

        var _t_act = (input_confirm());
        if (mouse_check_button_pressed(mb_left)) {
            var _tmx = device_mouse_x_to_gui(0);
            var _tmy = device_mouse_y_to_gui(0);
            if (_tmx >= 300 && _tmx < 1160) {
                var _t_vis    = ui_vendor_visible_rows(10);
                var _t_scroll = ui_list_window("vael_tints", vael_tint_cursor, _t_rows, _t_vis);
                var _t_vrow   = floor((_tmy - 225) / ui_vendor_row_pitch());
                if (_t_vrow >= 0 && _t_vrow < _t_vis) {
                    var _t_row = _t_scroll + _t_vrow;
                    if (_t_row >= 0 && _t_row < _t_rows) { vael_tint_cursor = _t_row; _t_act = true; }
                }
            }
        }

        if (_t_act) {
            var _tsel = _t_cat[vael_tint_cursor];
            if (vael_tint_owned(_tsel.id)) {
                if (school_tint_id(_tsel.school) == _tsel.id) {
                    // Enter on the equipped tint reverts the school to its base color.
                    vael_equip_tint("default", _tsel.school);
                    vael_notification = school_label(_tsel.school) + " restored to its true color.";
                } else {
                    var _teq = vael_equip_tint(_tsel.id);
                    vael_notification = (_teq == "") ? ("Your " + string_lower(school_label(_tsel.school)) + " now burns " + _tsel.name + ".") : _teq;
                }
            } else {
                var _tbuy = vael_buy_tint(_tsel.id);
                vael_notification = (_tbuy == "") ? ("Purchased & equipped " + _tsel.name + "!") : _tbuy;
                if (_tbuy == "") affinity_add("vael", 2);   // function-use drip (cosmetic purchase)
            }
        }
        exit;
    }

    if (nav_up())   { vael_cursor = wrap_index(vael_cursor - 1, _v_rows); vael_notification = ""; }
    if (nav_down()) { vael_cursor = wrap_index(vael_cursor + 1, _v_rows); vael_notification = ""; }
    vael_cursor = clamp(vael_cursor, 0, max(0, _v_rows - 1));

    var _v_act = (input_confirm());
    if (mouse_check_button_pressed(mb_left)) {
        var _vmx = device_mouse_x_to_gui(0);
        var _vmy = device_mouse_y_to_gui(0);
        // Windowed list: x300..1200, start y225, row step 72 (matches ui_draw_vael_screen).
        if (_vmx >= 300 && _vmx < 1200) {
            var _v_vis    = ui_vendor_visible_rows(10);   // match the draw-side window
            var _v_scroll = ui_list_window("vael_skins", clamp(vael_cursor, 0, _v_rows - 1), _v_rows, _v_vis);
            var _vvis_row = floor((_vmy - 225) / ui_vendor_row_pitch());
            if (_vvis_row >= 0 && _vvis_row < _v_vis) {
                var _vrow = _v_scroll + _vvis_row;
                if (_vrow >= 0 && _vrow < _v_rows) { vael_cursor = _vrow; _v_act = true; }
            }
        }
    }

    if (_v_act) {
        var _vsel = _v_cat[clamp(vael_cursor, 0, array_length(_v_cat) - 1)];
        if (vael_skin_owned(_vsel.id)) {
            var _vres = vael_select_skin(_vsel.id);
            vael_notification = (_vres == "") ? ("Now wearing " + _vsel.name + ".") : _vres;
        } else {
            var _vbuy = vael_buy_skin(_vsel.id);
            vael_notification = (_vbuy == "") ? ("Purchased & equipped " + _vsel.name + "!") : _vbuy;
            if (_vbuy == "") affinity_add("vael", 2);   // function-use drip (skin buy / transmog)
        }
    }

    exit;
}


if (!menu_open) exit;

// Escape: close picker/submenu first; only close whole menu if none are open
if (input_cancel()) {
    if (equip_picker_open) {
        equip_picker_open = false;
        equip_msg         = "";
    } else if (consumable_submenu_open) {
        consumable_submenu_open = false;
    } else if (trunk_arm) {
        // Trunk view (P2, 08-05): an armed pick disarms first...
        trunk_arm = false;
    } else if (ability_page != 0) {
        // ...then Esc steps back to the ability list, not out of the menu.
        ability_page = 0;
    } else {
        menu_open = false;
    }
    exit;
}

// Q/E cycle tabs (no wrap - clamped to 0-4; tab 4 = Companion, M 07-08)
if (!equip_picker_open && !consumable_submenu_open) {
    if (input_tab_prev()) {
        if (menu_tab > 0) audio_play_sound(snd_page, 1, false);
        menu_tab          = max(0, menu_tab - 1);
        equip_picker_open = false;
        ability_page      = 0;
        trunk_arm         = false;
    }
    if (input_tab_next()) {
        if (menu_tab < 4) audio_play_sound(snd_page, 1, false);
        menu_tab          = min(4, menu_tab + 1);
        equip_picker_open = false;
        ability_page      = 0;
        trunk_arm         = false;
    }

    // T on the Stats tab: cycle the equipped epithet through earned titles
    // (expression #5). The header line redraws immediately - that's the feedback.
    if (menu_tab == 0 && input_hotkey("T")) {
        epithet_cycle();
    }

    // P jumps straight to the Companion tab (mirrors the floor/combat P overlay).
    if (input_hotkey("P") && menu_tab != 4) {
        menu_tab = 4;
        audio_play_sound(snd_page, 1, false);
    }
}

// Abilities tab (2): three pages walked with A/D (08-08 M rework - the old [T]
// toggle is gone; every page is reached the same way the equipment sub-lists are).
// W/S browses whatever list the current page shows.
if (menu_tab == 2 && variable_global_exists("chosen_class")) {
    // A/D (and d-pad left/right) walk ABILITIES <-> CLASS TRUNK <-> TALENTS.
    // Clamped, not wrapped, so the ends feel like edges rather than a loop.
    if (input_dir_left() && ability_page > 0) {
        ability_page--;
        trunk_arm = false;
        audio_play_sound(snd_page, 1, false);
    } else if (input_dir_right() && ability_page < ABILITY_PAGE_COUNT - 1) {
        ability_page++;
        trunk_arm = false;
        audio_play_sound(snd_page, 1, false);
    }

    if (ability_page == 1) {
        // The 10 nodes are ONE list walked with W/S in reading order, so left/right
        // stays free for page switching. Any movement disarms a pending confirm.
        var _tk_idx = trunk_cursor * 2 + trunk_side;
        if (nav_down()) { _tk_idx = wrap_index(_tk_idx + 1, 10); trunk_arm = false; }
        if (nav_up())   { _tk_idx = wrap_index(_tk_idx - 1, 10); trunk_arm = false; }
        trunk_cursor = _tk_idx div 2;
        trunk_side   = _tk_idx mod 2;
        // Enter/A: arm, then commit the PERMANENT pick (exclusive - Vael-only undo).
        if (input_confirm() || input_confirm_alt()) {
            var _tk_cls = global.chosen_class;
            if (!trunk_row_unlocked(trunk_cursor) || trunk_pick_get(_tk_cls, trunk_cursor) != -1) {
                audio_play_sound(snd_ui_error, 1, false);
                trunk_arm = false;
            } else if (!trunk_arm) {
                trunk_arm = true;
                audio_play_sound(snd_page, 1, false);
            } else {
                trunk_pick_set(_tk_cls, trunk_cursor, trunk_side);
                trunk_arm = false;
                save_game();
                audio_play_sound(snd_confirm_major, 1, false);
            }
        }
    } else {
        // Pages 0 (ABILITIES) and 2 (TALENTS) both browse the loadout list; each
        // keeps its own cursor so switching pages doesn't move the other one.
        var _abil_count = array_length(abilities_resolve_player_loadout(global.chosen_class));
        if (_abil_count > 0) {
            if (ability_page == 2) {
                talent_cursor = clamp(talent_cursor, 0, _abil_count - 1);
                if (nav_down()) talent_cursor = wrap_index(talent_cursor + 1, _abil_count);
                if (nav_up())   talent_cursor = wrap_index(talent_cursor - 1, _abil_count);
            } else {
                if (nav_down()) ability_view_cursor = wrap_index(ability_view_cursor + 1, _abil_count);
                if (nav_up())   ability_view_cursor = wrap_index(ability_view_cursor - 1, _abil_count);
            }
        }
    }
}

// Mouse input for the character menu overlay
if (mouse_check_button_pressed(mb_left)) {
    var _mmx = device_mouse_x_to_gui(0);
    var _mmy = device_mouse_y_to_gui(0);

    // --- Tab bar: 5 tabs (tab 4 = Companion), w=252 gap=12, bar centered on
    // GUI_W - geometry MUST match ui_draw_character_menu's _tab_x0. ---
    var _tab_bar_x0 = (GUI_W - (5 * 264 - 12)) / 2;
    for (var _mt = 0; _mt < 5; _mt++) {
        var _tx = _tab_bar_x0 + _mt * 264;
        if (_mmx >= _tx && _mmx < _tx+252 && _mmy >= 30 && _mmy < 96) {
            if (menu_tab != _mt) audio_play_sound(snd_page, 1, false);
            menu_tab                = _mt;
            equip_picker_open       = false;
            consumable_submenu_open = false;
            ability_page            = 0;
            trunk_arm               = false;
            break;
        }
    }

    // --- Equipment tab (1) ---
    if (menu_tab == 1) {
        if (!equip_picker_open) {
            // Click an equipment slot -> select and open picker. Single-column list
            // on the right (geometry mirrors ui_draw_character_menu equipment tab:
            // list x740..1850, rows from y166, height ~83).
            for (var _msl = 0; _msl < EQUIP_SLOT_COUNT; _msl++) {
                var _msly = 166 + _msl * 83;
                if (_mmx >= 740 && _mmx < 1850 && _mmy >= _msly && _mmy < _msly+80) {
                    equip_slot_selected = _msl;
                    equip_picker_open   = true;
                    equip_picker_index  = 0;
                    equip_picker_scroll = 0;
                    equip_msg           = "";
                    break;
                }
            }
        } else {
            // Picker is open - click a row to equip. Filter by the item-TYPE the
            // position accepts (Ring 2 accepts "ring" items).
            var _msel_inv  = equip_display_to_inv(equip_slot_selected);
            var _mpslname  = equip_position_item_slot(_msel_inv);
            var _mpitems   = [];
            var _mpsrc     = [];
            // Stash is hub-only: during a run you can only equip from your pack.
            var _mp_in_hub = (room == rm_hub || room == rm_character_select);
            if (_mp_in_hub) {
                for (var _mpi = 0; _mpi < array_length(global.equipment_stash); _mpi++) {
                    if (global.equipment_stash[_mpi].slot == _mpslname) {
                        array_push(_mpitems, global.equipment_stash[_mpi]);
                        array_push(_mpsrc, { source: 0, idx: _mpi });
                    }
                }
            }
            for (var _mpi = 0; _mpi < array_length(global.carried_items); _mpi++) {
                if (global.carried_items[_mpi].slot == _mpslname) {
                    array_push(_mpitems, global.carried_items[_mpi]);
                    array_push(_mpsrc, { source: 1, idx: _mpi });
                }
            }
            // Selectable rows are pushed down one row when an item is worn in this
            // slot (the dimmed "[Equipped]" row occupies the top - see scr_ui picker).
            // The list is WINDOWED past what fits on screen - this scroll math MUST
            // mirror ui_draw_character_menu's picker (_pk_scroll).
            var _mp_eq_off    = (global.inventory[_msel_inv] != undefined) ? 108 : 0;
            var _mp_count     = array_length(_mpitems);
            var _mp_max_rows  = max(1, (1020 - (228 + _mp_eq_off)) div 108);
            var _mp_scroll    = clamp(equip_picker_scroll, 0, max(0, _mp_count - _mp_max_rows));
            var _mp_win_rows  = min(_mp_count - _mp_scroll, _mp_max_rows);
            for (var _mwr = 0; _mwr < _mp_win_rows; _mwr++) {
                var _mri  = _mp_scroll + _mwr;
                var _mpry = 228 + _mp_eq_off + _mwr * 108;
                if (_mmx >= 366 && _mmx < 1554 && _mmy >= _mpry && _mmy < _mpry+102) {
                    equip_picker_index = _mri;
                    var _mchosen  = _mpitems[_mri];
                    var _mcr      = variable_struct_exists(_mchosen, "class_req") ? _mchosen.class_req : -1;
                    var _mpcl     = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                    var _msreq = equip_stat_block_reason(_mchosen);
                    if (_mcr != -1 && _mcr != _mpcl) {
                        var _mcrnames = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                        equip_msg = _mchosen.name + " requires " + _mcrnames[_mcr] + ".";
                    } else if (_msreq != "") {
                        equip_msg = _msreq;
                    } else if (_msel_inv == 1 && hard_two_handed_equipped()) {
                        // Offhand slot is locked while a greatsword/longbow 2H is equipped.
                        equip_msg = "Two-handed weapon equipped - offhand is locked.";
                    } else if (_msel_inv == 1 && caster_staff_equipped() && item_is_shield_offhand(_mchosen)) {
                        equip_msg = "A two-handed staff cannot also hold a shield.";
                    } else if (_msel_inv == 0 && caster_staff_equipped()) {
                        equip_msg = "A two-handed staff is equipped - no melee weapon.";
                    } else {
                        equip_msg = "";
                        var _msinfo = _mpsrc[_mri];
                        var _mold   = global.inventory[_msel_inv];
                        if (_msinfo.source == 0) {
                            array_delete(global.equipment_stash, _msinfo.idx, 1);
                            if (_mold != undefined) array_push(global.equipment_stash, _mold);
                        } else {
                            array_delete(global.carried_items, _msinfo.idx, 1);
                            if (_mold != undefined) array_push(global.carried_items, _mold);
                        }
                        global.inventory[_msel_inv] = _mchosen;
                        // 2H weapon vacates the offhand. A caster staff only displaces a
                        // SHIELD (keeps a focus/tome) and clears any melee weapon; other
                        // 2H weapons displace any offhand. (Task 10)
                        if ((_msel_inv == 0 || _msel_inv == 8) && item_is_two_handed(_mchosen)) {
                            if (item_is_caster_2h(_mchosen)) {
                                if (item_is_shield_offhand(global.inventory[1])) return_offhand_to_pack(_mp_in_hub);
                                return_inv_slot_to_pack(0, _mp_in_hub);
                            } else {
                                return_offhand_to_pack(_mp_in_hub);
                            }
                        }
                        equip_notif_msg   = "Equipped " + _mchosen.name + "  ->  " + string_upper(_mpslname);
                        equip_notif_timer = 150;
                        audio_play_sound(snd_equip, 1, false);
                        equip_picker_open = false;
                        // Persist the equip - but only in the hub, where both the slot
                        // and the source (stash) are saved. Mid-run equips stay unsaved
                        // so an abandoned run reverts cleanly (carried pack isn't saved).
                        if (room == rm_hub || room == rm_character_select) save_game();
                    }
                    break;
                }
            }
        }
    }

    // --- Abilities tab (2): trunk chips, trunk boxes, then the ability list ---
    if (menu_tab == 2 && variable_global_exists("chosen_class")) {
        // ABILITIES | CLASS TRUNK | TALENTS chips (geometry MUST mirror
        // ui_draw_character_menu: 3 chips w=280 gap=10, centered, y=104..142).
        if (_mmy >= 104 && _mmy < 142) {
            var _apc_x0 = GUI_CX - (ABILITY_PAGE_COUNT * 290 - 10) / 2;
            for (var _apc = 0; _apc < ABILITY_PAGE_COUNT; _apc++) {
                var _apcx = _apc_x0 + _apc * 290;
                if (_mmx >= _apcx && _mmx < _apcx + 280) {
                    if (ability_page != _apc) audio_play_sound(snd_page, 1, false);
                    ability_page = _apc;
                    trunk_arm    = false;
                    break;
                }
            }
        }
        if (ability_page == 1) {
            // Node boxes (geometry mirrors the draw: rows y=252+r*142 h=126;
            // A x=260..1000, B x=1090..1830). First tap selects+arms, second
            // tap on the SAME box commits - arm-then-confirm for touch too.
            for (var _tkr = 0; _tkr < 5; _tkr++) {
                var _tky = 252 + _tkr * 142;
                if (_mmy < _tky || _mmy >= _tky + 126) continue;
                var _tks = -1;
                if (_mmx >= 260 && _mmx < 1000)  _tks = 0;
                if (_mmx >= 1090 && _mmx < 1830) _tks = 1;
                if (_tks == -1) break;
                if (!trunk_row_unlocked(_tkr) || trunk_pick_get(global.chosen_class, _tkr) != -1) {
                    audio_play_sound(snd_ui_error, 1, false);
                    trunk_arm = false;
                } else if (trunk_arm && trunk_cursor == _tkr && trunk_side == _tks) {
                    trunk_pick_set(global.chosen_class, _tkr, _tks);
                    trunk_arm = false;
                    save_game();
                    audio_play_sound(snd_confirm_major, 1, false);
                } else {
                    trunk_cursor = _tkr;
                    trunk_side   = _tks;
                    trunk_arm    = true;
                    audio_play_sound(snd_page, 1, false);
                }
                break;
            }
        } else {
            var _alist = abilities_resolve_player_loadout(global.chosen_class);
            var _alcnt = array_length(_alist);
            if (_alcnt > 0 && _mmx >= 86 && _mmx < 684) {
                // Mirrors the draw: panel top moved 150 -> 170 on 08-08 so the gothic
                // frame's filigree stops clear of the ABILITIES/CLASS TRUNK/TALENTS
                // chips, so the first row starts at 170+16. The 108 cap is what keeps
                // this in step with the draw's own row-height maths at every real
                // loadout size (4, or 5 with Expanded Arsenal).
                var _alrh = min(108, (830) / _alcnt);
                for (var _ali = 0; _ali < _alcnt; _ali++) {
                    var _aly = 186 + _ali * _alrh;
                    if (_mmy >= _aly && _mmy < _aly + _alrh - 6) {
                        if (ability_page == 2) talent_cursor = _ali;
                        else                   ability_view_cursor = _ali;
                        break;
                    }
                }
            }
        }
    }

    // --- Consumables tab (3) ---
    if (menu_tab == 3) {
        // Grouped view (one row per distinct consumable); clicks map back to a real
        // inventory index. Mirrors the scr_ui draw + the keyboard handler.
        var _mgroups = consumables_grouped();
        var _mcons   = array_length(_mgroups);
        // Same windowing as the draw (scr_ui) so clicks land on the visible rows.
        var _mcons_max_vis = 7;
        var _mcons_first   = ui_list_window("consumables", consumable_submenu_cursor, _mcons, _mcons_max_vis);
        var _mcons_last    = min(_mcons, _mcons_first + _mcons_max_vis);
        for (var _mci = _mcons_first; _mci < _mcons_last; _mci++) {
            var _mcy = 195 + (_mci - _mcons_first) * 120;
            if (_mmx >= 60 && _mmx < 1350 && _mmy >= _mcy && _mmy < _mcy+98) {
                if (!consumable_submenu_open) {
                    consumable_submenu_open   = true;
                    consumable_submenu_cursor = _mci;
                } else if (consumable_submenu_cursor == _mci) {
                    // Click already-highlighted item -> use it
                    var _mcan = true;
                    // AP-restore items ("energy") cost no AP, so they work at 0 AP too.
                    var _m_is_ap = (_mci < array_length(_mgroups)
                        && _mgroups[_mci].item.effect_type == "energy");
                    if (instance_exists(obj_combat_controller)) {
                        var _mctrl = instance_find(obj_combat_controller, 0);
                        if (!_mctrl.player_turn && items_used_this_turn >= 1) _mcan = false;
                        if (_mctrl.player_turn && _mctrl.player.energy < 1 && !_m_is_ap) {
                            _mcan = false;
                            array_push(_mctrl.combat_log, "Need 1 AP to use an item!");
                        }
                    }
                    if (_mcan && _mci < array_length(_mgroups)) {
                        var _mreal_idx = _mgroups[_mci].first_index;
                        var _mit = _mgroups[_mci].item;
                        var _mused = false;
                        if (instance_exists(obj_combat_controller)) {
                            var _mctrl2 = instance_find(obj_combat_controller, 0);
                            var _mplyr  = _mctrl2.player;
                            _mused = true;
                            if (_mit.effect_type == "heal") {
                                var _mheal = min(_mplyr.max_HP - _mplyr.HP, _mit.effect_value);
                                _mplyr.HP += _mheal;
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + " - restored " + string(_mheal) + " HP!");
                            } else if (_mit.effect_type == "energy") {
                                // Burst AP: no cap (can exceed the 3-AP turn limit) and no use cost.
                                _mplyr.energy += _mit.effect_value;
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + " - +" + string(_mit.effect_value) + " AP!");
                            } else if (_mit.effect_type == "cleanse_dot") {
                                var _mcl = combat_cleanse(_mplyr, "dot");
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + (_mcl > 0
                                    ? " - cleared " + string(_mcl) + " damage-over-time effect(s)!"
                                    : " - no DoT effects to clear."));
                            } else if (_mit.effect_type == "cleanse_debuff") {
                                var _mcl = combat_cleanse(_mplyr, "one");
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + (_mcl > 0
                                    ? " - removed a debuff!" : " - no debuff to remove."));
                            } else if (_mit.effect_type == "cleanse_all") {
                                var _mcl = combat_cleanse(_mplyr, "all");
                                array_push(_mctrl2.combat_log, "Used " + _mit.name + (_mcl > 0
                                    ? " - cleared " + string(_mcl) + " negative effect(s)!"
                                    : " - no negative effects to clear."));
                            } else if (_mit.effect_type == "gold_find_pot") {
                                potion_drink_gold(_mit.effect_value);
                                array_push(_mctrl2.combat_log, "Used " + _mit.name
                                    + " - gold drops +" + string(_mit.effect_value) + "% until 2 bosses fall!");
                            } else if (_mit.effect_type == "loot_find_pot") {
                                potion_drink_loot(_mit.effect_value);
                                array_push(_mctrl2.combat_log, "Used " + _mit.name
                                    + " - loot chance +" + string(_mit.effect_value) + "% until 2 bosses fall!");
                            }
                            // AP-restore items are free; everything else costs 1 AP on your turn.
                            if (_mctrl2.player_turn) {
                                if (_mit.effect_type != "energy") {
                                    _mctrl2.player.energy -= 1;
                                    array_push(_mctrl2.combat_log, "  [-1 AP]");
                                }
                            } else {
                                items_used_this_turn++;
                            }
                        } else {
                            // Out of combat: heals apply to the persistent run HP;
                            // non-heal items have no effect here and are not consumed.
                            _mused = consumable_use_out_of_combat(_mit);
                        }
                        if (_mused) {
                            // Blessed Thirst (was Lucky Find): 20% chance the item is not
                            // consumed. POTENCY V2: +4% per rank.
                            if (trait_active("Blessed Thirst") && irandom(99) < 20 + 4 * trait_potency_r14("Blessed Thirst")) {
                                if (instance_exists(obj_combat_controller)) {
                                    array_push(instance_find(obj_combat_controller, 0).combat_log,
                                        "Blessed Thirst - " + _mit.name + " is not consumed!");
                                }
                            } else {
                                array_delete(global.consumable_inventory, _mreal_idx, 1);
                            }
                            var _mg2 = array_length(consumables_grouped());
                            consumable_submenu_cursor = min(_mci, max(0, _mg2 - 1));
                            if (_mg2 == 0) consumable_submenu_open = false;
                        }
                    }
                } else {
                    consumable_submenu_cursor = _mci;
                }
                break;
            }
        }
    }
}


// =============================================================================
// EQUIPMENT TAB - slot select, picker, unequip
// =============================================================================
if (menu_tab == 1) {
    // equip_slot_selected is the VISUAL list row (single column, 0..9); the actual
    // inventory index is mapped through equip_display_to_inv so Ring 2 can sit under
    // Ring 1 without remapping stored slots.
    var _sel_inv = equip_display_to_inv(equip_slot_selected);

    if (!equip_picker_open) {
        // ===== Found-items (pack) column: focus / browse / sort / equip =====
        // The right column lists the pack. A/<- focuses the slots, D/-> the found list;
        // a click focuses whichever was clicked. Q/E stay reserved for tab switching.
        var _found   = equip_found_list(equip_found_sort);
        var _found_n = array_length(_found);
        equip_found_cursor = clamp(equip_found_cursor, 0, max(0, _found_n - 1));

        if (mouse_check_button_pressed(mb_left)) {
            var _emx = device_mouse_x_to_gui(0);
            var _emy = device_mouse_y_to_gui(0);
            if (_emx >= 1652 && _emx <= 1842 && _emy >= 162 && _emy <= 202) {
                equip_found_sort = (equip_found_sort + 1) mod 2;   // sort toggle button
            } else if (_emx >= 1360 && _emx <= 1862 && _emy >= 150 && _emy <= 1012) {
                equip_found_focus = true;   // clicking the column focuses it even when empty
                if (_found_n > 0) {
                    var _ffirst = ui_list_window("equip_found", equip_found_cursor, _found_n, 12);
                    var _frow   = floor((_emy - 236) / 60);
                    if (_frow >= 0 && _frow < min(12, _found_n - _ffirst)) equip_found_cursor = clamp(_ffirst + _frow, 0, _found_n - 1);
                }
            } else if (_emx >= 580 && _emx <= 1340 && _emy >= 150 && _emy <= 1012) {
                equip_found_focus = false;
                var _srow = floor((_emy - 166) / 83);
                if (_srow >= 0 && _srow < EQUIP_SLOT_COUNT) equip_slot_selected = _srow;
            }
        }
        if (input_dir_right()) equip_found_focus = true;   // lateral swap (works even if pack empty)
        if (input_dir_left())  equip_found_focus = false;

        if (equip_found_focus) {
            if (_found_n > 0 && nav_up())   equip_found_cursor = wrap_index(equip_found_cursor - 1, _found_n);
            if (_found_n > 0 && nav_down()) equip_found_cursor = wrap_index(equip_found_cursor + 1, _found_n);
            equip_found_cursor = clamp(equip_found_cursor, 0, max(0, _found_n - 1));

            // Enter equips the highlighted found item into its slot.
            if ((input_confirm()) && _found_n > 0) {
                var _fitem = _found[equip_found_cursor].item;
                var _fsrc  = _found[equip_found_cursor].idx;
                var _fsrctype = variable_struct_exists(_found[equip_found_cursor], "src") ? _found[equip_found_cursor].src : 1; // 0 stash / 1 pack
                var _ftgt  = equip_target_inv_for_slot(_fitem.slot);
                var _fcr   = variable_struct_exists(_fitem, "class_req") ? _fitem.class_req : -1;
                var _fmycl = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                var _fsreq = equip_stat_block_reason(_fitem);
                if (_ftgt == -1) {
                    equip_msg = "Can't equip that item.";
                } else if (_fcr != -1 && _fcr != _fmycl) {
                    var _fcn = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                    equip_msg = _fitem.name + " requires " + ((_fcr >= 0 && _fcr <= 2) ? _fcn[_fcr] : "another class") + ".";
                } else if (_fsreq != "") {
                    equip_msg = _fsreq;
                } else if (_ftgt == 1 && hard_two_handed_equipped()) {
                    equip_msg = "Two-handed weapon equipped - offhand is locked.";
                } else if (_ftgt == 1 && caster_staff_equipped() && item_is_shield_offhand(_fitem)) {
                    equip_msg = "A two-handed staff cannot also hold a shield.";
                } else if (_ftgt == 0 && caster_staff_equipped()) {
                    equip_msg = "A two-handed staff is equipped - no melee weapon.";
                } else {
                    var _fhub = (room == rm_hub || room == rm_character_select);
                    var _fold = global.inventory[_ftgt];
                    // Remove the chosen item from its own source (stash or pack), and return
                    // the previously-equipped item to that same source.
                    if (_fsrctype == 0) {
                        array_delete(global.equipment_stash, _fsrc, 1);
                        if (_fold != undefined) array_push(global.equipment_stash, _fold);
                    } else {
                        array_delete(global.carried_items, _fsrc, 1);
                        if (_fold != undefined) array_push(global.carried_items, _fold);
                    }
                    global.inventory[_ftgt] = _fitem;
                    if ((_ftgt == 0 || _ftgt == 8) && item_is_two_handed(_fitem)) {
                        if (item_is_caster_2h(_fitem)) {
                            if (item_is_shield_offhand(global.inventory[1])) return_offhand_to_pack(_fhub);
                            return_inv_slot_to_pack(0, _fhub);
                        } else {
                            return_offhand_to_pack(_fhub);
                        }
                    }
                    equip_notif_msg   = "Equipped " + _fitem.name + "  ->  " + string_upper(_fitem.slot);
                    equip_notif_timer = 150;
                    equip_msg         = "";
                    audio_play_sound(snd_equip, 1, false);
                    if (_fhub) save_game();
                    // List rebuilds next frame (stash + pack); just keep the cursor non-negative,
                    // the draw/Step re-clamp to the new length.
                    equip_found_cursor = max(0, equip_found_cursor);
                }
            }
        } else {
        // Single-column navigation - W/S wrap through all 10 slot rows.
        if (nav_up())   equip_slot_selected = wrap_index(equip_slot_selected - 1, EQUIP_SLOT_COUNT);
        if (nav_down()) equip_slot_selected = wrap_index(equip_slot_selected + 1, EQUIP_SLOT_COUNT);
        _sel_inv = equip_display_to_inv(equip_slot_selected);

        // Enter opens the item picker for this slot
        if (input_confirm()) {
            equip_picker_open   = true;
            equip_picker_index  = 0;
            equip_picker_scroll = 0;
        }

        // U unequips the selected slot
        if (input_hotkey("U")) {
            var _old = global.inventory[_sel_inv];
            if (_old != undefined) {
                global.inventory[_sel_inv] = undefined;
                var _in_hub = (room == rm_hub || room == rm_character_select);
                if (_in_hub) {
                    array_push(global.equipment_stash, _old);
                } else {
                    array_push(global.carried_items, _old);
                }
                // Persist the unequip only in the hub. Mid-run the item goes to the
                // un-saved carried pack, so saving an empty slot here would lose it.
                if (_in_hub) save_game();
            }
        }
        }   // end slot-focus branch

    } else {
        // Picker open - build filtered list for the selected slot every frame. Use the
        // item-TYPE the position accepts (Ring 2 accepts "ring" items) so rings list for
        // either ring position.
        var _slot_name   = equip_position_item_slot(_sel_inv);
        var _picker_items = [];
        var _picker_src   = [];   // { source: 0=stash/1=carried, idx: original_index }
        // Stash is hub-only: during a run you can only equip from your pack.
        var _picker_in_hub = (room == rm_hub || room == rm_character_select);
        if (_picker_in_hub) {
            for (var _pi = 0; _pi < array_length(global.equipment_stash); _pi++) {
                if (global.equipment_stash[_pi].slot == _slot_name) {
                    array_push(_picker_items, global.equipment_stash[_pi]);
                    array_push(_picker_src, { source: 0, idx: _pi });
                }
            }
        }
        for (var _pi = 0; _pi < array_length(global.carried_items); _pi++) {
            if (global.carried_items[_pi].slot == _slot_name) {
                array_push(_picker_items, global.carried_items[_pi]);
                array_push(_picker_src, { source: 1, idx: _pi });
            }
        }
        var _picker_count = array_length(_picker_items);

        if (nav_up())   { if (_picker_count > 0) equip_picker_index = wrap_index(equip_picker_index - 1, _picker_count); equip_msg = ""; }
        if (nav_down()) { if (_picker_count > 0) equip_picker_index = wrap_index(equip_picker_index + 1, _picker_count); equip_msg = ""; }

        // Edge-triggered scroll: window size mirrors the Draw + mouse math (row_h 108,
        // list top 228 + a worn-item row when one is equipped). Synced every frame so
        // the Draw and the mouse hit-test (which both read equip_picker_scroll) agree.
        var _pk_eq_off = (global.inventory[_sel_inv] != undefined) ? 108 : 0;
        var _pk_vis    = max(1, (1020 - (228 + _pk_eq_off)) div 108);
        if (equip_picker_index < equip_picker_scroll)            equip_picker_scroll = equip_picker_index;
        if (equip_picker_index >= equip_picker_scroll + _pk_vis) equip_picker_scroll = equip_picker_index - (_pk_vis - 1);
        equip_picker_scroll = clamp(equip_picker_scroll, 0, max(0, _picker_count - _pk_vis));

        if ((input_confirm()) && _picker_count == 0) {
            equip_picker_open = false;
            equip_msg         = "";
        }
        if ((input_confirm()) && _picker_count > 0) {
            var _chosen   = _picker_items[equip_picker_index];

            // Class restriction check
            var _chosen_cr = variable_struct_exists(_chosen, "class_req") ? _chosen.class_req : -1;
            var _player_cl = variable_global_exists("chosen_class") ? global.chosen_class : -1;
            var _ksreq     = equip_stat_block_reason(_chosen);
            if (_chosen_cr != -1 && _chosen_cr != _player_cl) {
                var _class_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                var _req_name    = (_chosen_cr >= 0 && _chosen_cr <= 2) ? _class_names[_chosen_cr] : "Unknown";
                equip_msg = _chosen.name + " requires " + _req_name + ".";
                // Don't equip - skip the rest of the block
            } else if (_ksreq != "") {
                equip_msg = _ksreq;   // hard block: stat requirement not met
            } else if (_sel_inv == 1 && hard_two_handed_equipped()) {
                // Offhand slot is locked while a greatsword/longbow 2H is equipped.
                equip_msg = "Two-handed weapon equipped - offhand is locked.";
            } else if (_sel_inv == 1 && caster_staff_equipped() && item_is_shield_offhand(_chosen)) {
                equip_msg = "A two-handed staff cannot also hold a shield.";
            } else if (_sel_inv == 0 && caster_staff_equipped()) {
                equip_msg = "A two-handed staff is equipped - no melee weapon.";
            } else {
            equip_msg = "";

            var _src_info = _picker_src[equip_picker_index];
            var _old      = global.inventory[_sel_inv];

            // Remove chosen item from its source array
            if (_src_info.source == 0) {
                array_delete(global.equipment_stash, _src_info.idx, 1);
                if (_old != undefined) array_push(global.equipment_stash, _old);
            } else {
                array_delete(global.carried_items, _src_info.idx, 1);
                if (_old != undefined) array_push(global.carried_items, _old);
            }

            global.inventory[_sel_inv] = _chosen;
            // A 2H weapon vacates the offhand. A caster staff only displaces a SHIELD
            // (keeps a focus/tome) and clears any melee weapon; other 2H weapons
            // displace any offhand. (Task 10)
            if ((_sel_inv == 0 || _sel_inv == 8) && item_is_two_handed(_chosen)) {
                if (item_is_caster_2h(_chosen)) {
                    if (item_is_shield_offhand(global.inventory[1])) return_offhand_to_pack(_picker_in_hub);
                    return_inv_slot_to_pack(0, _picker_in_hub);
                } else {
                    return_offhand_to_pack(_picker_in_hub);
                }
            }
            equip_notif_msg   = "Equipped " + _chosen.name + "  ->  " + string_upper(_slot_name);
            equip_notif_timer = 150;
            audio_play_sound(snd_equip, 1, false);
            equip_picker_open = false;
            // Persist the equip only in the hub (see unequip/Maren notes above):
            // mid-run the source is the un-saved carried pack.
            if (_picker_in_hub) save_game();
            } // end class_req else block
        }

        if (input_cancel() || input_back()) {
            equip_picker_open = false;
            equip_msg = "";
        }
    }
}


// =============================================================================
// CONSUMABLE TAB - item submenu (W/S navigate, Enter use, Esc cancel)
// =============================================================================
if (menu_tab == 3) {

    if (consumable_submenu_open) {
        // Grouped view: identical consumables show as one "Name xN" row; cursor + use
        // map back through it to a real inventory index. Mirrors the scr_ui draw.
        var _cgroups  = consumables_grouped();
        var _cons_cnt = array_length(_cgroups);

        // Navigate (hold-repeat + wrap)
        if (nav_up())   consumable_submenu_cursor = wrap_index(consumable_submenu_cursor - 1, _cons_cnt);
        if (nav_down()) consumable_submenu_cursor = wrap_index(consumable_submenu_cursor + 1, _cons_cnt);

        // Close without using
        if (input_cancel()) {
            consumable_submenu_open = false;
        }

        // Use selected item
        if (input_confirm()) {
            var _can_use = true;
            // AP-restore items ("energy") and the resource+AP brew ("resource_ap") cost
            // no AP, so they stay usable at 0 AP.
            var _sel_et    = (_cons_cnt > 0 && consumable_submenu_cursor < _cons_cnt)
                ? _cgroups[consumable_submenu_cursor].item.effect_type : "";
            var _sel_is_ap = (_sel_et == "energy" || _sel_et == "resource_ap");
            if (instance_exists(obj_combat_controller)) {
                var _ctrl_c = instance_find(obj_combat_controller, 0);
                if (!_ctrl_c.player_turn && items_used_this_turn >= 1) {
                    _can_use = false;
                }
                if (_ctrl_c.player_turn && _ctrl_c.player.energy < 1 && !_sel_is_ap) {
                    _can_use = false;
                    array_push(_ctrl_c.combat_log, "Need 1 AP to use an item!");
                }
            }
            if (_can_use && _cons_cnt > 0 && consumable_submenu_cursor < _cons_cnt) {
                var _real_idx = _cgroups[consumable_submenu_cursor].first_index;
                var _item = _cgroups[consumable_submenu_cursor].item;
                var _used = false;
                if (instance_exists(obj_combat_controller)) {
                    var _ctrl_c = instance_find(obj_combat_controller, 0);
                    var _player = _ctrl_c.player;
                    _used = true;
                    // CHAOTIC BREW (M 07-28): payoff rolled at drink time - resolve into
                    // a FRESH local struct (never mutate the menu's shared item struct).
                    // Always costs the 1 AP (mystery tax), even when it rolls AP.
                    var _was_chaotic = false;
                    if (_item.effect_type == "chaotic") {
                        _was_chaotic = true;
                        var _ch = chaotic_brew_roll();
                        global.ach_brew_run = true;   // ACH_BREW: drank one - now survive the run
                        array_push(_ctrl_c.combat_log, "The Chaotic Brew " + _ch.label + "!");
                        if (_ch.sting) {
                            var _bite = irandom_range(8, 15);
                            _player.HP = max(1, _player.HP - _bite);
                            array_push(_ctrl_c.combat_log, "...but it curdles going down - " + string(_bite) + " damage!");
                        }
                        _item = { name: "Chaotic Brew", effect_type: _ch.effect_type, effect_value: _ch.value };
                    }
                    if (_item.effect_type == "heal") {
                        var _heal = min(_player.max_HP - _player.HP, _item.effect_value);
                        _player.HP += _heal;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " - restored " + string(_heal) + " HP!");
                    } else if (_item.effect_type == "energy") {
                        // Burst AP: no cap (can exceed the 3-AP turn limit) and no use cost.
                        _player.energy += _item.effect_value;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " - +" + string(_item.effect_value) + " AP!");
                    } else if (_item.effect_type == "cleanse_dot") {
                        var _cl = combat_cleanse(_player, "dot");
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + (_cl > 0
                            ? " - cleared " + string(_cl) + " damage-over-time effect(s)!"
                            : " - no DoT effects to clear."));
                    } else if (_item.effect_type == "cleanse_debuff") {
                        var _cl = combat_cleanse(_player, "one");
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + (_cl > 0
                            ? " - removed a debuff!" : " - no debuff to remove."));
                    } else if (_item.effect_type == "cleanse_all") {
                        var _cl = combat_cleanse(_player, "all");
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + (_cl > 0
                            ? " - cleared " + string(_cl) + " negative effect(s)!"
                            : " - no negative effects to clear."));
                    } else if (_item.effect_type == "shield") {
                        if (!variable_struct_exists(_player, "shield_hp")) _player.shield_hp = 0;
                        _player.shield_hp += _item.effect_value;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name
                            + " - gained a " + string(_item.effect_value) + "-point shield!");
                    } else if (_item.effect_type == "heal_dot") {
                        if (!variable_struct_exists(_player, "status_effects")) _player.status_effects = [];
                        array_push(_player.status_effects, {
                            name: _item.name, kind: "regen", effect_type: "heal_dot",
                            effect_value: _item.effect_value, duration: 3, element: ""
                        });
                        array_push(_ctrl_c.combat_log, "Used " + _item.name + " - regenerating "
                            + string(_item.effect_value) + " HP/turn for 3 turns.");
                    } else if (_item.effect_type == "resource_ap") {
                        // Ley Battery: +N class secondary resource AND +1 burst AP (free).
                        var _ley_res2   = _item.effect_value;
                        var _ley_label2 = "resource";
                        if (variable_struct_exists(_player, "souls")) {
                            _player.souls = min(_player.souls_max, _player.souls + _ley_res2); _ley_label2 = "Souls";
                        } else if (variable_struct_exists(_player, "blood")) {
                            _player.blood = min(_player.blood_max, _player.blood + _ley_res2); _ley_label2 = "Blood";
                        } else if (variable_struct_exists(_player, "preparation")) {
                            _player.preparation = min(_player.preparation_max, _player.preparation + _ley_res2); _ley_label2 = "Preparation";
                        }
                        _player.energy += 1;
                        array_push(_ctrl_c.combat_log, "Used " + _item.name
                            + " - +" + string(_ley_res2) + " " + _ley_label2 + " and +1 AP!");
                    } else if (_item.effect_type == "gold_find_pot") {
                        potion_drink_gold(_item.effect_value);
                        array_push(_ctrl_c.combat_log, "Used " + _item.name
                            + " - gold drops +" + string(_item.effect_value) + "% until 2 bosses fall!");
                    } else if (_item.effect_type == "loot_find_pot") {
                        potion_drink_loot(_item.effect_value);
                        array_push(_ctrl_c.combat_log, "Used " + _item.name
                            + " - loot chance +" + string(_item.effect_value) + "% until 2 bosses fall!");
                    }
                    // AP-restore items are free; everything else costs 1 AP on your turn.
                    // (A Chaotic Brew that ROLLED an AP effect still pays - mystery tax.)
                    if (_ctrl_c.player_turn) {
                        if ((_item.effect_type != "energy" && _item.effect_type != "resource_ap") || _was_chaotic) {
                            _ctrl_c.player.energy -= 1;
                            array_push(_ctrl_c.combat_log, "  [-1 AP]");
                        }
                    } else {
                        items_used_this_turn++;
                    }
                } else {
                    // Out of combat (hub / floor map): apply heals to the persistent
                    // run HP. Items with no out-of-combat effect are NOT consumed.
                    _used = consumable_use_out_of_combat(_item);
                }
                if (_used) {
                    // Blessed Thirst (was Lucky Find): 20% chance the item is not
                    // consumed. POTENCY V2: +4% per rank.
                    if (trait_active("Blessed Thirst") && irandom(99) < 20 + 4 * trait_potency_r14("Blessed Thirst")) {
                        if (instance_exists(obj_combat_controller)) {
                            array_push(instance_find(obj_combat_controller, 0).combat_log,
                                "Blessed Thirst - " + _item.name + " is not consumed!");
                        }
                    } else {
                        array_delete(global.consumable_inventory, _real_idx, 1);
                    }
                    var _cg2 = array_length(consumables_grouped());
                    consumable_submenu_cursor = min(consumable_submenu_cursor, max(0, _cg2 - 1));
                    if (_cg2 == 0) {
                        consumable_submenu_open = false;
                    }
                }
            }
        }

    } else {
        // Submenu closed - Enter opens it (only when items exist)
        if ((input_confirm())
            && array_length(global.consumable_inventory) > 0) {
            consumable_submenu_open   = true;
            consumable_submenu_cursor = 0;
        }
    }
}

// Close submenu automatically when switching away from the consumables tab
if (menu_tab != 3) {
    consumable_submenu_open = false;
}

// Reset item use counter each player turn
if (instance_exists(obj_combat_controller)) {
    var _ctrl = instance_find(obj_combat_controller, 0);
    if (_ctrl.player_turn) items_used_this_turn = 0;
}

// STEAM ACHIEVEMENTS periodic sync (08-04): every ~5s walk the state-derived
// conditions (kills, epithets, descent floor, songs, roster states...). Cheap
// (a few short array walks) and a no-op without the Steamworks extension.
// Event-shaped achievements fire ach_unlock() at their own sites instead.
ach_sync_clock++;
if (ach_sync_clock >= 300) {
    ach_sync_clock = 0;
    achievements_sync();
}


