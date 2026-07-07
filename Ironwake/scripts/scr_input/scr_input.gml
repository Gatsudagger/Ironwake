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
// funnel so the gamepad chunk can surface them contextually and the touch
// backend can render them as buttons straight from the key-legend footers.
function input_hotkey(ch) {
    return keyboard_check_pressed(ord(ch));
}
