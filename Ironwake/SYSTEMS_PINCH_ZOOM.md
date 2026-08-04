# PINCH ZOOM — mobile magnifier (M design-locked 2026-07-28, build NOW pre-launch)

Answer to the #1 tester complaint (mobile text too small): a global pinch-to-
zoom magnifier rather than re-laying-out every dense screen before Aug 19.
Complements (does not replace) post-launch per-screen readability passes.

## Locked decisions
1. **Gestures:** two-finger pinch zooms around the pinch midpoint; two-finger
   drag pans while zoomed; zooming out below ~1.1x snaps back to 1.0. One-
   finger input is COMPLETELY unchanged (taps, holds, d-pad, list drags).
2. **Settings toggle** (M): "Pinch Zoom" ON/OFF row in the Settings overlay,
   persisted in settings.ini [touch] pinch_zoom (default ON). OFF = gesture
   ignored + transform hard-reset to 1.0. Lets players lock normal mode.
3. **Tutorial popup** (M): one-time mobile popup guiding the visual tweaks
   (pinch to zoom, two-finger drag to pan, pinch-out to reset, toggle lives in
   Settings). Shown on first HUB visit on a touch device; seen-flag in
   settings.ini [touch] zoom_intro_seen (device-level, like the d-pad intro).
   Also fold a line into the char-create Touch Controls intro for new players.
4. **On-screen controls stay FIXED** — d-pad, back chip, action chips keep
   screen size/position while the world+UI zoom beneath. Implementation: their
   draw+hit rects pass through an inverse-transform helper (screen→GUI:
   gui = (screen - offset) / scale) so draw and hit-test stay in lockstep.
5. **Max zoom 2.5x**; min 1.0; pan clamped so the view never leaves the
   1920×1080 canvas.
6. Touch-gated: gesture only when input_device() == 2. Desktop unaffected.

## Architecture (AS BUILT 2026-07-30)
One state struct `global.zoom` (scr_ui): z (1.0–ZOOM_MAX 2.5), vx/vy (pan in
GUI units from the base view origin), plus the base window fit recorded by
gui_geometry_apply (sx/sy scale, ox centering offset, l0 = GUI x at the
window's left edge, vis_w = visible width incl gutters).
- **GUI layer only.** The whole game renders in Draw GUI (no Draw_0 events
  exist anywhere), so zooming the GUI layer zooms everything — the spec's
  room-camera half was unnecessary and was NOT built. `zoom_apply()` pushes
  display_set_gui_maximise(sx*z, sy*z, ox*z − vx*sx*z, −vy*sy*z); at 1.0 it
  restores the exact shipped calls. device_mouse_*_to_gui passes through the
  transform, so every existing hit-test keeps working untouched.
- **Gesture:** `touch_pinch_update()` (scr_input), called at the top of
  obj_game_controller Step BEFORE touch_gesture_update. Two fingers =
  device_mouse_check_button(0|1); positions read via device_mouse_raw_* (raw
  window px — to_gui would feed back through the transform being changed).
  Zoom-about-midpoint and two-finger pan both fall out of one anchor equation
  (the GUI point that started under the midpoint stays under it). While a
  pinch is live (+10 cooldown frames) the one-finger classifier is muted so
  lifting the pinch can't fire a stray tap. Release below 1.1x snaps to 1.0.
- **Fixed controls (decision #4):** zgx()/zgy()/ziv() (scr_ui) map a nominal
  GUI coordinate to the zoomed coordinate that renders at the same physical
  pixel. touch_pad_geom() transforms its whole geometry struct (so pad draw +
  hit-test + footprint mask all follow); ui_draw_touch_back and
  ui_draw_touch_chips map their rect corners and draw labels via
  draw_text_transformed at ziv() scale.
- **Settings:** [touch] pinch_zoom (1=ON default) via touch_settings_init/save;
  `pinch_zoom_toggle()` hard-resets the transform when turning OFF. Settings
  overlay row 8 "Pinch Zoom" (touch platforms only; touch panel row pitches
  squeezed 108→96 / 84→76 to fit the 10th row in the 1050 panel).
- **Intros:** one-time hub popup ([touch] zoom_intro_seen, device-level;
  obj_hub_controller Create/Step/Draw_64, modal, measured-height panel) + a
  PINCH line folded into the char-create Touch Controls intro (panel now
  auto-sizes from measured text height).
- **Dev lever:** F6 (IDE-only, GM_build_type=="run") cycles x1.0→x1.5→x2.5
  centered so zoomed taps + fixed controls can be verified on PC (pairs with
  F9 forced-touch). Two-finger PAN cannot be simulated — device-verify on S25.
- **HTML5:** unsupported (browser gate in touch_pinch_update + geometry apply).
- Window shape change (fold/rotate/F7 lever) resets zoom to 1.0 (stale anchor
  math is never reused). Zoom persists across rooms (gc is persistent).

## F5 / device test list
Zoomed taps on hub menus / combat targeting / stash rows; d-pad + back chip +
action chips stay put (and stay tappable) while zoomed; toggle OFF resets;
snap-back below 1.1x; settings row reachable by W/S + tap; hub popup shows
once and persists; char-create intro line; F6 lever cycles on PC.
Known accepted quirk: the first finger of a pinch briefly counts as a normal
press before the second lands — press-fired buttons under finger #1 can
trigger; start pinches on empty space (watch for complaints, fix later if real).

## Status
**BUILT 2026-07-30 (this file is the as-built record). Awaiting M's F5 +
S25 device pass.** The 07-28 "implementation started" note was stale — nothing
had actually landed in .gml; built fresh this session.
