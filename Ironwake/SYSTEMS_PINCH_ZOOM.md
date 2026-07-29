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

## Architecture (single source of truth)
Globals: zoom_scale (1.0–2.5), zoom_ox, zoom_oy (screen-px offsets).
Two transforms driven together from ONE state, applied every frame by the
persistent obj_game_controller:
- **GUI layer:** display_set_gui_maximise(zoom_scale, zoom_scale, ox, oy)
  (falls back to display_set_gui_size(1920,1080) at 1.0 — the current setup,
  SYSTEMS_RESOLUTION.md). device_mouse_*_to_gui passes through this transform,
  so EVERY existing GUI hit-test keeps working untouched. ⚠ F5-VERIFY FIRST:
  confirm taps land correctly while zoomed before polishing anything else.
- **Room camera:** camera_set_view_size(cam, 1920/scale, 1080/scale) + view
  position offset with the same focal math, so room-space content (combat
  enemies, hub scene) stays glued to its GUI overlays. Restored at 1.0.
Gesture tracking lives beside touch_gesture_update (two-touch distance +
midpoint deltas; GameMaker multi-touch device_mouse_x/y(0|1)).

## Surfaces / reference sync
Settings overlay row + settings.ini, hub one-time popup, char-create touch
intro line, compendium not needed (device UX, not a game mechanic), F5 test
list: zoomed taps on hub menus / combat targeting / stash / d-pad fixedness /
toggle OFF resets / snap-back / persistence across rooms (zoom persists;
panning is the player's job).

## Status
Spec written 07-28 late session; implementation started same session — see
memory project_endgame_batch_0727 for how far it got before handoff.
