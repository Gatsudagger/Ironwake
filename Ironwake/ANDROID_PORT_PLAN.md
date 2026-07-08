# Ironwake — Android port plan (input chunk 8 + export + Play Console)

Drafted 2026-07-07 (M-approved scope: design docs + checklists now; touch code starts
once an Android build can run on a device). One GM project, per-target exports; all
mobile code gated on `os_type` so the Windows/Steam build cannot change behavior.

## 1. Touch input backend (chunk 8 — the last scr_input backend)

`input_device()` already returns **2** on Android/iOS (os-forced). The design keeps the
7b architecture: the key-legend contract becomes *tappable*.

### 1a. Single-touch = mouse (free coverage)
GM maps the first finger to the mouse on Android: `mouse_check_button_pressed(mb_left)` +
`device_mouse_x/y_to_gui(0)` all fire on tap. The **157 existing mouse sites** (row clicks,
tab chips, shop buy buttons, combat ability buttons + enemy bars, ITEMS button, loot
continue) carry over untouched. First device test = drive the game by taps alone and
list what's UNREACHABLE — that list should equal the keyboard-only hotkeys + drag needs.

### 1b. On-screen action buttons from the legends
- New `ui_draw_touch_actions()` drawn by each room controller last (same slot as the
  legend footers): renders the current context's actions as tap chips along the bottom
  edge — sourced from the SAME per-context data as `__input_pad_hotkey_map()` plus the
  core verbs (Confirm/Cancel appear only where a row-tap isn't already the confirm).
- A tapped chip calls `input_touch_tap(ch)` → buffers the char; `input_hotkey(ch)`
  returns true for it once, next step (mirror of the Bairc `input_inject` mechanism,
  but PLAIN chars — a touch tap should reproduce the keyboard key exactly).
- The Bairc action submenu from 7b IS the touch pattern for over-subscribed screens:
  on touch, tapping a roster row opens the same menu (rows are tappable via mouse
  mapping already — verify the menu's rows get mouse hitboxes in chunk 8).
- Nav/scroll: rows are directly tappable; add drag-scroll only where lists exceed a
  screen (stash, codex, history) — GM `device_mouse_*` deltas, one shared helper.
- Android **back button**: route to `input_cancel()` (GM delivers it as a key — verify
  the keycode on device; do NOT let the OS default close the app mid-run).

### 1c. Text entry
`keyboard_string` sites (char naming, pet naming): call
`keyboard_virtual_show(kbv_type_default, kbv_returnkey_done, kbv_autocapitalize_words, false)`
when the naming modal opens on `os_type == os_android`, `keyboard_virtual_hide()` on close.

## 2. Screen geometry: 20:9 + safe areas (GUI_W/H plan)

Today: `#macro GUI_W 1920`, `GUI_H 1080` (scr_ui.gml:8-11), UI authored for 16:9.
Phones are 19.5:9–21:9 (e.g. 2400×1080 = 20:9). Plan — **height-locked, width-flex**:

1. Keep the logical height at 1080: `display_set_gui_maximise` / GUI size set per device
   to `(1080 * display_aspect) x 1080`, so all vertical layout survives unchanged.
2. `GUI_W` becomes a runtime read (`display_get_gui_width()` wrapped in a function-macro),
   `GUI_CX` follows. On 16:9 desktop it evaluates to exactly 1920 — zero change there.
3. **Literal audit** (the real work): grep `1920|1900|1850` and right-anchored `960`
   literals in Draw code; anything pinned to the right edge or centered must use
   GUI_W/GUI_CX. Center-anchored screens (most of our panels) just gain background at
   the sides — the gothic vista fills naturally.
4. **Safe areas** (notches/punch-holes): `display_get_safe_area()` insets; only edge-
   anchored elements care — the touch action bar (1b) and the hub footer get pushed in
   by the inset. One helper `gui_safe_l()/gui_safe_r()`.
5. Combat layout check: ability bar at x=240..(240+9*252) fits 1920; on 20:9 it stays
   centered — fine. Enemy-bar columns at x=990/1485 likewise.

## 3. GameMaker Android export — setup steps (one-time, ~1-2h)
1. Install per GM's "Required SDKs" help page for LTS 2026 (versions must match GM's
   table, not latest): Android Studio (SDK + platform-tools + build-tools), NDK, OpenJDK.
2. GM Preferences → Platform Settings → Android: paths to SDK/NDK/JDK; check "Build
   Tools/Target SDK" against Play's current **target API level requirement** (Play
   raises it yearly — check the requirement the week you submit).
3. **Keystore**: create in GM prefs (BACK IT UP — losing it means losing update rights,
   though Play App Signing mitigates). Package name suggestion: `com.outlawstar.ironwake`.
4. Game Options → Android: icons (adaptive), orientation **Landscape locked**, version
   code/name, texture page size (phones: keep 2048 pages), "Interpolate colours" as on
   Windows.
5. Audio: our OGGs are fine on Android; large music files stream — no change expected.
6. Output: **AAB** for Play uploads (`Build → Package`), APK for local device testing.
7. First device test = USB debugging + GM's Target device; F5-equivalent on device.

## 4. Google Play account — M's checklist ($25, one-time)
- [ ] Create Play Console dev account ($25 one-time; identity verification — takes a
      few days; needs matching payment method + ID).
- [ ] **Merchant account** too (required for a PAID app — Steam-first premium pricing
      carries over; set up early, it gates the price field).
- [ ] Create the app entry: Landscape game, Premium, no ads, no in-app purchases.
- [ ] **THE GATING RULE (personal accounts created after Nov 2023): before production
      release you must run a CLOSED TEST with ≥ 20 testers opted-in, continuously, for
      14 days, then apply for production access.** Plan this into the timeline: recruit
      20+ testers (friends/Discord/itch followers — they need Google accounts, opt-in
      link, and the app installed), start the clock EARLY — it can run while Steam EA
      ships. Testers must stay opted in; churn below 20 can reset eligibility.
- [ ] Store listing: 512px icon, 1024×500 feature graphic, ≥2 phone screenshots
      (reuse Steam capture set at phone aspect), short + full description (reuse
      STEAM_PAGE_KIT.md copy).
- [ ] Content rating questionnaire (IARC — fantasy violence, no gambling mechanics
      question issues expected; Knucklebones is not real-money).
- [ ] **Data safety form + privacy policy URL** — required even collecting nothing;
      a one-page "collects no data" policy hosted anywhere (itch page works).
- [ ] Play App Signing: accept (Google holds the release key; our keystore = upload key).
- [ ] AI disclosure: Play has an AI-generated-content question in the listing flow —
      answer consistently with the Steam disclosure (already drafted, see
      commercial-roadmap notes).

## 5. Order of work (proposed chunks, each with its own device test)
8a. Export setup + first APK on a device (no code changes) — proves toolchain.
8b. Geometry: GUI_W flex + literal audit + safe-area helpers (testable on Windows by
    forcing a 20:9 window).
8c. Touch: back button, `keyboard_virtual_*` naming, tap-only playthrough fix list.
8d. Touch action bar (`ui_draw_touch_actions` + `input_touch_tap`) + drag-scroll.
8e. Closed test build → 20-tester program starts.
