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
// Touch is os-forced; gamepad detection lands with the gamepad chunk.
function input_device() {
    if (os_type == os_android || os_type == os_ios) return 2;
    if (!variable_global_exists("input_last_device")) global.input_last_device = 0;
    return global.input_last_device;
}

function input_confirm() {
    return keyboard_check_pressed(vk_return) || keyboard_check_pressed(vk_enter);
}

function input_confirm_alt() {
    return keyboard_check_pressed(vk_space);
}

function input_cancel() {
    return keyboard_check_pressed(vk_escape);
}

function input_back() {
    return keyboard_check_pressed(vk_backspace);
}

function input_tab_next() {
    return keyboard_check_pressed(ord("E"));
}

function input_tab_prev() {
    return keyboard_check_pressed(ord("Q"));
}

function input_detail() {
    return keyboard_check_pressed(vk_tab);
}

// "Press any key" (cutscene/splash skip). Gamepad backend later maps this to
// any face button; touch to any tap.
function input_any() {
    return keyboard_check_pressed(vk_anykey);
}

// Screen-local letter hotkeys (T stash, H history, O settings, ...). A single
// funnel so the gamepad chunk can surface them contextually and the touch
// backend can render them as buttons straight from the key-legend footers.
function input_hotkey(ch) {
    return keyboard_check_pressed(ord(ch));
}
