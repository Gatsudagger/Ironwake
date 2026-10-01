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

## 2. Screen geometry: 20:9 + safe areas — BUILT 2026-07-17 (design revised, M-approved)

**As-built: centered band + art-filled gutters** (M's ruling 07-17 — the original
width-flex plan required hand-auditing ~177 bare `960` literals in shipping draw code
a month before Steam launch; rejected as needless PC risk for zero visibility gain).

1. ALL layout stays in 1920×1080 coordinates. `gui_geometry_apply()` (scr_ui.gml, by
   the GUI macros) fits the band to the window: 16:9-or-narrower keeps the shipped
   `display_set_gui_size` path byte-for-byte (gutter 0); wider windows get uniform
   height-locked scale, centered via `display_set_gui_maximise` with equal side
   gutters. Mouse/touch→GUI mapping follows the transform automatically.
2. New macros `GUI_GUTTER` / `GUI_XL` / `GUI_XR` = one side's gutter width and the
   true visible screen edges in GUI units (collapse to 0/0/1920 on 16:9). Every
   full-bleed draw — backgrounds, dim scrims, vignettes, fog/scrim primitives, the
   hub gradient/firelight/embers, title vista pan + treeline tiling + shooting-star
   bounds, `dungeon_bg_draw` cover — spans GUI_XL..GUI_XR so gutters show art, never
   raw black. UI panels/text/hitboxes untouched (56 rect sites + ~12 specials).
3. Applied from obj_game_controller Create; its Step re-applies on any window-shape
   change (F11 fullscreen, browser resize, Android boot/fold).
4. **Safe areas come free**: content lives in the centered band, ≥~107 GUI px inside
   the true edges on 19.5:9 — beyond any punch-hole. No inset code needed.
5. **TEST LEVER (REMOVE BEFORE RELEASE)**: F7 (Windows, obj_game_controller Step)
   cycles windowed 1440×810 (16:9) → 1755×810 (19.5:9 S25) → 1800×810 (20:9).
6. Bonus PC fix: ultrawide-monitor fullscreen used to horizontally STRETCH the GUI;
   it now gets the same centered band + art gutters (only non-16:9 displays change).

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
- [ ] **THE GATING RULE (verified 2026-07-17; Google cut 20→12 testers on Dec 11
      2024): personal accounts created after Nov 2023 must run a CLOSED TEST with
      ≥ 12 testers opted-in, continuously, for 14 consecutive days, then apply for
      production access (questionnaire). ORGANIZATION accounts (require a registered
      business + free D-U-N-S number) and pre-Nov-2023 personal accounts are EXEMPT.**
      The 14-day clock starts only after the release is approved AND 12 are opted in;
      Google also expects visible dev activity (updates/feedback response) during the
      window — an untouched build for 14 days can be rejected. Recruit 12+ testers
      (friends/Discord/itch followers — Google accounts + opt-in link + install),
      start EARLY — it can run while Steam EA ships. Churn below 12 pauses the clock.
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
8b. Geometry: DONE 2026-07-17 (centered band + gutters, §2 as-built; F7 Windows
    lever for F5 verification).
8c. Touch: back button, `keyboard_virtual_*` naming, tap-only playthrough fix list.
8d. Touch action bar (`ui_draw_touch_actions` + `input_touch_tap`) + drag-scroll.
8e. Closed test build → 20-tester program starts.
