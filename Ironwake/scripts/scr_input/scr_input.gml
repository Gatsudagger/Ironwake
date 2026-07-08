// =============================================================================
// scr_input.gml - device-abstract input layer (INPUT_ABSTRACTION_SPEC.md)
//
// The ONLY place device state should be read once migration completes. Chunk 1
// ships the keyboard backend, which reproduces current behavior EXACTLY - the
// vocabulary is deliberately fine-grained (confirm vs confirm_alt, cancel vs
// back) so every existing site maps faithfully instead of merging keys that
// today mean different things (e.g. level-alloc: Enter = provisional pick,
// Space = commit).
//
// Directional nav stays on the existing nav_up/down/left/right helpers
// (scr_stats) - they already abstract arrows+WASD with hold-repeat + menu tick;
// the gamepad d-pad/stick gets wired INTO key_nav in the gamepad chunk.
//
// Future backends fill in per action:      keyboard   gamepad   touch
//   input_confirm      accept/select        Enter      A         tap focused
//   input_confirm_alt  secondary commit     Space      X         context button
//   input_cancel       dismiss/close        Esc        B         back button
//   input_back         step back            Bksp       B         back button
//   input_tab_next/prev switch tab/category E / Q      RB / LB   tap tab chip
//   input_detail       detail popup         Tab        Y         long-press
//   input_hotkey(ch)   screen letter keys   ord(ch)    ctx menu  legend button
// =============================================================================

// Device the player last used: 0 = keyboard/mouse, 1 = gamepad, 2 = touch.
// Touch is os-forced; pad use flips to 1 inside pad_pressed/pad_nav, keyboard
// claims it back inside the getters below.
function input_device() {
    if (os_type == os_android || os_type == os_ios) return 2;
    if (!variable_global_exists("input_last_device")) global.input_last_device = 0;
    return global.input_last_device;
}

// First connected pad slot (XInput 0-3, then DInput 4-11), -1 if none.
function input_pad() {
    for (var _i = 0; _i < 12; _i++) if (gamepad_is_connected(_i)) return _i;
    return -1;
}

// One gamepad button, pressed-edge; claims the device on use.
function pad_pressed(_btn) {
    var _p = input_pad();
    if (_p >= 0 && gamepad_button_check_pressed(_p, _btn)) {
        global.input_last_device = 1;
        return true;
    }
    return false;
}

// Gamepad twin of key_nav (scr_stats): dpad direction OR the left stick folded
// past a 0.5 deadzone, with the SAME hold-repeat cadence (22-frame delay, then
// every 5). Shares nav_timers; -1 = released sentinel.
function pad_nav(_btn) {
    var _p = input_pad();
    if (_p < 0) return false;
    var _held = gamepad_button_check(_p, _btn);
    switch (_btn) {
        case gp_padu: _held = _held || (gamepad_axis_value(_p, gp_axislv) < -0.5); break;
        case gp_padd: _held = _held || (gamepad_axis_value(_p, gp_axislv) >  0.5); break;
        case gp_padl: _held = _held || (gamepad_axis_value(_p, gp_axislh) < -0.5); break;
        case gp_padr: _held = _held || (gamepad_axis_value(_p, gp_axislh) >  0.5); break;
    }
    if (!variable_global_exists("nav_timers")) global.nav_timers = {};
    var _k = "gp" + string(_btn);
    var _t = variable_struct_exists(global.nav_timers, _k)
           ? variable_struct_get(global.nav_timers, _k) : -1;
    if (!_held) {
        if (_t != -1) variable_struct_set(global.nav_timers, _k, -1);
        return false;
    }
    global.input_last_device = 1;
    if (_t == -1) {   // fresh press
        variable_struct_set(global.nav_timers, _k, 0);
        return true;
    }
    _t += 1;
    variable_struct_set(global.nav_timers, _k, _t);
    return (_t >= 22 && ((_t - 22) mod 5) == 0);
}

function input_confirm() {
    if (keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter)) {
        global.input_last_device = 0;
        return true;
    }
    return pad_pressed(gp_face1);                     // A
}

function input_confirm_alt() {
    if (keyboard_check_pressed(vk_space)) { global.input_last_device = 0; return true; }
    return pad_pressed(gp_face3);                     // X
}

function input_cancel() {
    if (keyboard_check_pressed(vk_escape)) { global.input_last_device = 0; return true; }
    return pad_pressed(gp_face2);                     // B
}

// B also serves back - cancel/back are OR'd together at nearly every site, and
// the lone back-only site (slot re-pick) reads naturally on B too.
function input_back() {
    if (keyboard_check_pressed(vk_backspace)) { global.input_last_device = 0; return true; }
    return pad_pressed(gp_face2);
}

function input_tab_next() {
    if (keyboard_check_pressed(ord("E"))) { global.input_last_device = 0; return true; }
    return pad_pressed(gp_shoulderr);                 // RB
}

function input_tab_prev() {
    if (keyboard_check_pressed(ord("Q"))) { global.input_last_device = 0; return true; }
    return pad_pressed(gp_shoulderl);                 // LB
}

function input_detail() {
    if (keyboard_check_pressed(vk_tab)) { global.input_last_device = 0; return true; }
    return pad_pressed(gp_face4);                     // Y
}

// The pad buttons that count as "any" input (skip/dismiss/arming patterns).
function __pad_any_buttons() {
    return [gp_face1, gp_face2, gp_face3, gp_face4,
            gp_shoulderl, gp_shoulderr, gp_start, gp_select,
            gp_padu, gp_padd, gp_padl, gp_padr];
}

// "Press any key" (cutscene/splash skip, popup dismiss).
function input_any() {
    if (keyboard_check_pressed(vk_anykey)) { global.input_last_device = 0; return true; }
    var _p = input_pad();
    if (_p >= 0) {
        var _bs = __pad_any_buttons();
        for (var _i = 0; _i < array_length(_bs); _i++) {
            if (gamepad_button_check_pressed(_p, _bs[_i])) {
                global.input_last_device = 1;
                return true;
            }
        }
    }
    return false;
}

// Held variant - used by arming patterns that wait for ALL input released
// before accepting the next press (Bairc dialog pages).
function input_any_held() {
    if (keyboard_check(vk_anykey)) return true;
    var _p = input_pad();
    if (_p >= 0) {
        var _bs = __pad_any_buttons();
        for (var _i = 0; _i < array_length(_bs); _i++) {
            if (gamepad_button_check(_p, _bs[_i])) return true;
        }
    }
    return false;
}

// Single-press directional (arrows OR A/D OR dpad tap, NO hold-repeat, no menu
// tick) - steppers and focus swaps that want exactly one move per press.
// Repeating directional nav lives in nav_* (scr_stats) + pad_nav above.
function input_dir_left() {
    if (keyboard_check_pressed(vk_left) || keyboard_check_pressed(ord("A"))) {
        global.input_last_device = 0;
        return true;
    }
    return pad_pressed(gp_padl);
}
function input_dir_right() {
    if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"))) {
        global.input_last_device = 0;
        return true;
    }
    return pad_pressed(gp_padr);
}

// Screen-local letter hotkeys (T stash, H history, O settings, ...). A single
// funnel: keyboard reads the literal key (unchanged); a connected gamepad
// additionally fires the hotkey when the button assigned to it in the current
// CONTEXT (see __input_pad_hotkey_map) is pressed. The touch backend later
// renders these as buttons straight from the key-legend footers.
function input_hotkey(ch) {
    if (keyboard_check_pressed(ord(ch))) { global.input_last_device = 0; return true; }
    var _cm = __input_ctx_hotkeys();
    if (_cm != undefined && variable_struct_exists(_cm, ch)) {
        return pad_pressed(variable_struct_get(_cm, ch));
    }
    return false;
}

// =============================================================================
// CHUNK 7b - contextual gamepad hotkeys + device-aware key legends
// (M-approved layout 2026-07-07: uniform buttons across contexts - Journal=LT,
// Character Menu=Start, Settings=Select, Bond-Ask=R3, Gift=RT; per-screen
// extras on the 6 free buttons RT/LT/Start/Select/L3/R3. Keyboard rows above
// are untouched - the pad path only ADDS a trigger for the same hotkey char.)
// =============================================================================

// Which screen owns input right now. Mirrors the ownership order of the
// controllers' Step events (gc overlays first, then room controllers). A wrong
// answer here can only mis-route a PAD button - keyboard reads are unaffected.
function __input_ctx() {
    if (variable_global_exists("settings_open") && global.settings_open) return "settings";
    if (variable_global_exists("item_picker") && global.item_picker.open) return "none";
    var _gc = instance_exists(obj_game_controller) ? instance_find(obj_game_controller, 0) : noone;
    if (_gc != noone) {
        if (variable_instance_exists(_gc, "kb_open") && _gc.kb_open)       return "kb";
        if (_gc.tavern_board_open)                                         return "board";
        if (_gc.journal_open)                                              return "journal";
        if (_gc.menu_open)                                                 return "charmenu";
        if (_gc.stash_mode_open)                                           return "none";
        if (_gc.loadout_open)                                              return "loadout";
        if (_gc.level_alloc_open)                                          return "none";
        if (_gc.dungeon_select_open)                                       return "none";
        if (_gc.perm_alloc_open)                                           return "none";
        if (variable_instance_exists(_gc, "bairc_open") && _gc.bairc_open) return "bairc";
        if (_gc.shop_open != -1
            || (variable_instance_exists(_gc, "maren_open") && _gc.maren_open)
            || (variable_instance_exists(_gc, "sable_open") && _gc.sable_open)
            || (variable_instance_exists(_gc, "vael_open")  && _gc.vael_open)
            || (variable_instance_exists(_gc, "trainer_open") && _gc.trainer_open)) return "shop";
    }
    if (instance_exists(obj_combat_controller)) {
        var _cc = instance_find(obj_combat_controller, 0);
        if (_cc.show_loot_screen) return "loot";
        return "combat";
    }
    if (instance_exists(obj_floor_controller)) {
        var _fc = instance_find(obj_floor_controller, 0);
        if (_fc.showing_shrine) return "shrine";
        return "floor";
    }
    if (instance_exists(obj_hub_controller))   return "hub";
    if (instance_exists(obj_char_select))      return "charsel";
    if (instance_exists(obj_title_controller)) return "title";
    return "none";
}

// Hand-curated hotkey->button table per context. Two chars may share a button
// within one context ONLY when their handlers are tab/state-exclusive (loadout
// M/B, char-menu T/U, shop R/C) - exactly one acts on any given press.
function __input_pad_hotkey_map() {
    if (!variable_global_exists("input_pad_hkmap")) {
        var _m = {};
        var _s;
        _s = {}; _s[$ "T"] = gp_shoulderrb; _s[$ "J"] = gp_shoulderlb;
                 _s[$ "I"] = gp_start;      _s[$ "O"] = gp_select;
                 _s[$ "H"] = gp_face4;      _s[$ "P"] = gp_stickl;
                 _s[$ "B"] = gp_stickr;                              _m[$ "hub"]      = _s;
        _s = {}; _s[$ "E"] = gp_shoulderrb; _s[$ "G"] = gp_stickr;
                 _s[$ "J"] = gp_shoulderlb; _s[$ "I"] = gp_start;    _m[$ "floor"]    = _s;
        _s = {}; _s[$ "T"] = gp_shoulderrb; _s[$ "C"] = gp_shoulderlb;
                 _s[$ "V"] = gp_stickr;     _s[$ "I"] = gp_start;    _m[$ "combat"]   = _s;
        _s = {}; _s[$ "E"] = gp_shoulderrb;                          _m[$ "loot"]     = _s;
        _s = {}; _s[$ "1"] = gp_face3;      _s[$ "2"] = gp_face4;
                 _s[$ "3"] = gp_shoulderrb;                          _m[$ "shrine"]   = _s;
        _s = {}; _s[$ "K"] = gp_shoulderrb; _s[$ "T"] = gp_shoulderlb;
                 _s[$ "R"] = gp_stickr;                              _m[$ "board"]    = _s;
        _s = {}; _s[$ "H"] = gp_face4;                               _m[$ "kb"]       = _s;
        _s = {}; _s[$ "M"] = gp_shoulderrb; _s[$ "B"] = gp_shoulderrb; _m[$ "loadout"]  = _s;
        _s = {}; _s[$ "T"] = gp_shoulderrb; _s[$ "U"] = gp_shoulderrb;
                 _s[$ "I"] = gp_start;                               _m[$ "charmenu"] = _s;
        _s = {}; _s[$ "O"] = gp_select;                              _m[$ "settings"] = _s;
        _s = {}; _s[$ "J"] = gp_shoulderlb;                          _m[$ "journal"]  = _s;
        _s = {}; _s[$ "F"] = gp_shoulderrb; _s[$ "R"] = gp_shoulderlb;
                 _s[$ "C"] = gp_shoulderlb; _s[$ "B"] = gp_stickr;   _m[$ "shop"]     = _s;
        _s = {}; _s[$ "F"] = gp_shoulderrb; _s[$ "B"] = gp_stickr;   _m[$ "bairc"]    = _s;
        _s = {}; _s[$ "X"] = gp_shoulderlb;                          _m[$ "charsel"]  = _s;
        _s = {}; _s[$ "O"] = gp_select;                              _m[$ "title"]    = _s;
        global.input_pad_hkmap = _m;
    }
    return global.input_pad_hkmap;
}

// Current context's hotkey->button struct, or undefined.
function __input_ctx_hotkeys() {
    var _m   = __input_pad_hotkey_map();
    var _ctx = __input_ctx();
    return variable_struct_exists(_m, _ctx) ? variable_struct_get(_m, _ctx) : undefined;
}

// Display name for a pad button (text-chip glyphs, M-approved 2026-07-07).
function __pad_btn_name(_btn) {
    switch (_btn) {
        case gp_face1:      return "A";      case gp_face2:      return "B";
        case gp_face3:      return "X";      case gp_face4:      return "Y";
        case gp_shoulderl:  return "LB";     case gp_shoulderr:  return "RB";
        case gp_shoulderlb: return "LT";     case gp_shoulderrb: return "RT";
        case gp_start:      return "Start";  case gp_select:     return "Select";
        case gp_stickl:     return "L3";     case gp_stickr:     return "R3";
    }
    return "?";
}

// ---------------------------------------------------------------------------
// Synthetic hotkey injection - the Bairc pad action menu picks an entry and
// injects a namespaced tag ("bairc:N"); the existing handler consumes it via
// input_inject_take on the NEXT step. Namespaced so an injected letter can
// never trip an unrelated handler (e.g. plain "I" would toggle the char menu).
// Tags expire after 100ms so a gated handler can't fire one steps later.
// ---------------------------------------------------------------------------
function input_inject(_tag) {
    global.input_inject_tag  = _tag;
    global.input_inject_time = current_time;
}

function input_inject_take(_tag) {
    if (!variable_global_exists("input_inject_tag"))          return false;
    if (global.input_inject_tag != _tag)                      return false;
    global.input_inject_tag = "";
    return (current_time - global.input_inject_time <= 100);
}

// ---------------------------------------------------------------------------
// Legend key translation - turns the KEY part of a ui_draw_key_legend segment
// ("W/S", "Enter / Space", "C/Esc", "A/D or <-/->") into pad text chips.
// Returns "" when nothing on the pad performs the action (segment is hidden).
// ---------------------------------------------------------------------------
function input_legend_key(_key) {
    // normalize separators, then split on "/"
    _key = string_replace_all(_key, " or ", "/");
    var _toks = [];
    var _cur  = "";
    for (var _i = 1; _i <= string_length(_key); _i++) {
        var _c = string_char_at(_key, _i);
        if (_c == "/" && _cur != "<" && _cur != "-") {   // keep "<-" / "->" intact
            array_push(_toks, _cur); _cur = "";
        } else {
            _cur += _c;
        }
    }
    array_push(_toks, _cur);

    // Q/E pair = the tab idiom (LB/RB); lone E may instead be a hotkey below.
    var _has_q = false;
    for (var _q = 0; _q < array_length(_toks); _q++) {
        if (__str_trim(_toks[_q]) == "Q") _has_q = true;
    }

    var _cm  = __input_ctx_hotkeys();
    var _out = [];
    for (var _t = 0; _t < array_length(_toks); _t++) {
        var _tok = __str_trim(_toks[_t]);
        var _lbl = "";
        switch (_tok) {
            case "Enter":                        _lbl = "A";     break;
            case "Space":                        _lbl = "X";     break;
            case "Esc":                          _lbl = "B";     break;
            case "Backspace": case "Bksp":       _lbl = "B";     break;
            case "Tab":                          _lbl = "Y";     break;
            case "Click": case "click":          _lbl = "Click"; break;
            case "W": case "S": case "<-": case "->":
            case "Arrows":                       _lbl = "D-Pad"; break;
            case "Q":                            _lbl = "LB";    break;
            case "E":                            _lbl = _has_q ? "RB" : ""; break;
            default: break;
        }
        // A and D are WASD nav unless the context binds them (no context does today)
        if (_lbl == "" && (_tok == "A" || _tok == "D")
            && (_cm == undefined || !variable_struct_exists(_cm, _tok))) {
            _lbl = "D-Pad";
        }
        // single letter/digit -> contextual button
        if (_lbl == "" && string_length(_tok) == 1 && _cm != undefined
            && variable_struct_exists(_cm, _tok)) {
            _lbl = __pad_btn_name(variable_struct_get(_cm, _tok));
        }
        if (_lbl != "") array_push(_out, _lbl);
    }

    // dedupe (keeps first occurrence); "A" makes a sibling "X" redundant
    var _ded = [];
    for (var _d = 0; _d < array_length(_out); _d++) {
        var _dup = false;
        for (var _e = 0; _e < array_length(_ded); _e++) if (_ded[_e] == _out[_d]) { _dup = true; break; }
        if (!_dup) array_push(_ded, _out[_d]);
    }
    var _has_a = false;
    for (var _a = 0; _a < array_length(_ded); _a++) if (_ded[_a] == "A") _has_a = true;
    var _txt = "";
    for (var _o = 0; _o < array_length(_ded); _o++) {
        if (_has_a && _ded[_o] == "X" && array_length(_ded) > 1) continue;
        _txt += (_txt != "" ? "/" : "") + _ded[_o];
    }
    return _txt;
}

// Leading/trailing space trim (hand-rolled - keeps the file runtime-agnostic).
function __str_trim(_s) {
    while (string_length(_s) > 0 && string_char_at(_s, 1) == " ")                  _s = string_delete(_s, 1, 1);
    while (string_length(_s) > 0 && string_char_at(_s, string_length(_s)) == " ") _s = string_delete(_s, string_length(_s), 1);
    return _s;
}

// =============================================================================
// CHUNK 8c (minimal) - touch backbone: simulated keypresses
// A tapped chip/zone calls touch_press(key): keyboard_key_press makes the
// EXISTING keyboard handler react - the io-level twin of the pad's synthetic
// hotkeys. touch_sim_pump() (called once per frame from ui_draw_touch_back,
// which every room controller draws last) releases keys pressed in EARLIER
// frames, so each tap lands exactly one clean pressed-edge.
// =============================================================================
function touch_press(_key) {
    if (!variable_global_exists("touch_sim_keys"))  global.touch_sim_keys  = [];
    if (!variable_global_exists("touch_sim_frame")) global.touch_sim_frame = 0;
    keyboard_key_press(_key);
    array_push(global.touch_sim_keys, { key: _key, frame: global.touch_sim_frame });
}

function touch_sim_pump() {
    if (!variable_global_exists("touch_sim_keys"))  global.touch_sim_keys  = [];
    if (!variable_global_exists("touch_sim_frame")) global.touch_sim_frame = 0;
    for (var _i = array_length(global.touch_sim_keys) - 1; _i >= 0; _i--) {
        if (global.touch_sim_keys[_i].frame < global.touch_sim_frame) {
            keyboard_key_release(global.touch_sim_keys[_i].key);
            array_delete(global.touch_sim_keys, _i, 1);
        }
    }
    global.touch_sim_frame += 1;
}

// Tap (mouse pressed-edge) inside a GUI-space rect. PRESS-fired - right for
// buttons/chips. Lists that must distinguish tap-from-drag use the gesture
// system below instead (touch_tap_in fires on clean RELEASE).
function touch_tapped(_x1, _y1, _x2, _y2) {
    if (!mouse_check_button_pressed(mb_left)) return false;
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    return (_mx >= _x1 && _mx <= _x2 && _my >= _y1 && _my <= _y2);
}

// =============================================================================
// CHUNK 8d - touch gesture classifier: TAP vs DRAG vs LONG-PRESS
// Updated ONCE per frame at the top of obj_game_controller's Step (gc runs in
// every gameplay room). One finger = one gesture:
//   - moves > 27px from origin      -> DRAG   (touch_drag_dy feeds scrolling)
//   - held >= 450ms without moving  -> LONG-PRESS (fires once, at the origin)
//   - released early without moving -> TAP    (fires at the release position)
// Consumers that only care about buttons keep using the press-fired
// touch_tapped above; lists use these so a scroll can't select.
// =============================================================================
function touch_gesture_update() {
    if (!variable_global_exists("tg")) {
        global.tg = { held: false, ox: 0, oy: 0, px: 0, py: 0, dx: 0, dy: 0,
                      drag: false, t0: 0, tap: false, tapx: 0, tapy: 0,
                      lp: false, lp_done: false };
    }
    var _g = global.tg;
    _g.tap = false;
    _g.lp  = false;
    _g.dx  = 0;
    _g.dy  = 0;
    if (input_device() != 2) { _g.held = false; _g.drag = false; return; }
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    if (mouse_check_button_pressed(mb_left)) {
        _g.held = true;  _g.drag = false;  _g.lp_done = false;
        _g.ox = _mx;  _g.oy = _my;  _g.px = _mx;  _g.py = _my;
        _g.t0 = current_time;
        global.touch_drag_acc = 0;
    } else if (_g.held && mouse_check_button(mb_left)) {
        _g.dx = _mx - _g.px;
        _g.dy = _my - _g.py;
        _g.px = _mx;  _g.py = _my;
        if (!_g.drag && point_distance(_g.ox, _g.oy, _mx, _my) > 27) _g.drag = true;
        if (!_g.drag && !_g.lp_done && current_time - _g.t0 >= 450) {
            _g.lp      = true;
            _g.lp_done = true;
        }
    } else if (_g.held) {   // released this frame
        _g.held = false;
        if (!_g.drag && !_g.lp_done && current_time - _g.t0 < 450) {
            _g.tap  = true;
            _g.tapx = _mx;
            _g.tapy = _my;
        }
        _g.drag = false;
    }
}

function touch_tap()   { return variable_global_exists("tg") && global.tg.tap; }
function touch_tap_x() { return global.tg.tapx; }
function touch_tap_y() { return global.tg.tapy; }
function touch_lp()    { return variable_global_exists("tg") && global.tg.lp; }
function touch_lp_x()  { return global.tg.ox; }
function touch_lp_y()  { return global.tg.oy; }

function touch_tap_in(_x1, _y1, _x2, _y2) {
    if (!touch_tap()) return false;
    return (global.tg.tapx >= _x1 && global.tg.tapx <= _x2
         && global.tg.tapy >= _y1 && global.tg.tapy <= _y2);
}

function touch_lp_in(_x1, _y1, _x2, _y2) {
    if (!touch_lp()) return false;
    return (global.tg.ox >= _x1 && global.tg.ox <= _x2
         && global.tg.oy >= _y1 && global.tg.oy <= _y2);
}

// Per-frame vertical drag delta, only while a drag that STARTED inside the
// rect is in progress (so a drag can't scroll a list it didn't begin on).
function touch_drag_dy(_x1, _y1, _x2, _y2) {
    if (!variable_global_exists("tg")) return 0;
    var _g = global.tg;
    if (!_g.held || !_g.drag) return 0;
    if (_g.ox < _x1 || _g.ox > _x2 || _g.oy < _y1 || _g.oy > _y2) return 0;
    return _g.dy;
}

// Drag-to-cursor: converts vertical drag inside a rect into simulated arrow
// presses (one row per _pitch px, max one per frame). The consumer's EXISTING
// nav handlers do the rest, including their edge-scroll - zero list rewrites.
function touch_drag_rows(_x1, _y1, _x2, _y2, _pitch) {
    var _dy = touch_drag_dy(_x1, _y1, _x2, _y2);
    if (_dy == 0) return;
    if (!variable_global_exists("touch_drag_acc")) global.touch_drag_acc = 0;
    global.touch_drag_acc += _dy;
    if (global.touch_drag_acc >= _pitch)       { touch_press(vk_up);   global.touch_drag_acc -= _pitch; }
    else if (global.touch_drag_acc <= -_pitch) { touch_press(vk_down); global.touch_drag_acc += _pitch; }
}
