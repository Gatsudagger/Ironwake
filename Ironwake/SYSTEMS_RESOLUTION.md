# Ironwake — Native 1080p Resolution Re-base

Design-locked 2026-06-26 (decisions in §G; font face/sizes finalize in Phase 2). Goal: render
the game at a **native 1920×1080 GUI** for crisp text and UI, replacing today's 1280×720 GUI
that GameMaker bilinearly upscales to fill the display. Not started.

---

## A. How rendering works today (the starting point)

- `obj_game_controller/Create_0` (~15-21): `window_set_size(1280,720)`,
  `display_set_gui_size(1280,720)`, then `video_apply()`.
- **Everything is drawn on the GUI layer** (each controller's `Draw_64` / Draw GUI event):
  title, char-select, hub, combat, floor, all menus/overlays (`scr_ui.gml`). The room
  camera is effectively irrelevant to what the player sees — the GUI is the canvas.
- Fullscreen (`video_apply`/`video_toggle_fullscreen` in scr_stats ~3961): just toggles
  `window_set_fullscreen`; the 1280×720 GUI is **scaled up to fill the display**. That final
  upscale is a **raster bilinear blur on everything** — text, rectangles, and sprites alike.
- **Fonts: there are NO font assets in the project, and `draw_set_font` is never called.**
  All text is GameMaker's built-in **default font** (a small Arial-ish bitmap). Large text
  (titles, names) is faked by scaling the default font via `draw_text_transformed(... 1.4 ...)`,
  which is already soft even before the fullscreen upscale.

### Why "it already fills 1080p" ≠ "it's sharp"
Today the game DOES fill a 1080p screen — by upscaling a 720p surface. The re-base wins
**native pixel density**: the GUI surface becomes 1920×1080 and maps 1:1 to a 1080p display,
so there's no upscale blur. But native density only helps content that is itself authored at
native density — see fonts (§D) and sprites (§E). Geometry (rectangles/lines) is resolution-
independent and becomes crisp for free.

---

## B. Scope of the change

A naïve "multiply every number by 1.5" is **wrong and dangerous** — the same `.gml` literals
also encode alphas (`0.45`), colors, durations, loop bounds, and font *scale factors*. The
rescale must be a deliberate, screen-by-screen pass over layout coordinates only.

Hardcoded-coordinate surface area (literal `1280`/`720` only — the real count is far higher
once panel edges like `260`/`1020`, the `640`/`360` centers, row pitches, and pads are
included):

| File | `1280`/`720` lits | Role |
|---|---|---|
| `scripts/scr_ui/scr_ui.gml` | 17 | **The big one** — every menu/overlay/HUD primitive |
| `objects/obj_hub_controller/Draw_64.gml` | 23 | Hub + loadout + shop screens |
| `objects/obj_floor_controller/Draw_64.gml` | 6 | Floor map, shrine/event overlays |
| `objects/obj_combat_controller/Draw_64.gml` | 4 | Combat HUD + buttons |
| `objects/obj_title_controller/Draw_64.gml` | 5 | Title |
| `objects/obj_char_select/Draw_64.gml` | 4 | Character select |
| `objects/obj_game_controller/Create_0.gml` | 2 | Window/GUI setup |
| `objects/obj_game_controller/Step_0.gml` | 1 | (mouse-region / hit-test) |
| `objects/obj_hub_controller/Create_0.gml` | 2 | layout init |
| `scripts/scr_stats/scr_stats.gml` | 1 | fullscreen restore size |

Plus **mouse hit-testing**: every clickable region compares `device_mouse_x_to_gui` /
`mouse_*` against the same hardcoded coordinates. These MUST move in lockstep with the draw
coordinates or clicks land in the wrong place. (The combat button hit-region at
`obj_combat_controller/Draw_64:289` is explicitly commented to "match ui_draw_ability_buttons"
— that coupling is the pattern to watch everywhere.)

---

## C. Approach options (recommended: full rescale)

**Option A — Full coordinate rescale to a native 1920×1080 GUI. ✅ Recommended.**
Set the GUI to 1920×1080 and rescale every layout coordinate ×1.5, screen by screen.
- Pros: codebase stays clean (numbers = real pixels), geometry crisp, true native density,
  no per-draw wrappers. Each screen is independently testable.
- Cons: large one-time mechanical pass over the biggest files; rounding on odd pixels
  (e.g. `25 → 37.5` → pick 38); easy to miss a paired hit-test.

**Option B — Global 1.5× transform matrix per Draw GUI.** Keep all 720p coordinates, set GUI
to 1920×1080, and wrap each `Draw_64` in `matrix_set(matrix_world, scale 1.5)` … reset.
- Pros: almost no coordinate edits.
- Cons: **does NOT meet the sharpness goal** — text (bitmap font) and sprites are raster-scaled
  by the matrix exactly like today's upscale, so they stay blurry. Only rectangles/lines sharpen.
  To make text/sprites native you'd have to unset the matrix and draw them at ×1.5 anyway —
  i.e. the same per-site work as Option A, plus matrix bookkeeping. Net: more complexity, less
  benefit. **Rejected for the sharpness goal**; noted only as the "just fill the screen" path
  (which we already have for free).

**Option C — Scale helper (`ui_px(v)` / `GUI_W`/`GUI_H` constants).** A thin wrapper used in
new code, with constants for the canvas. Doesn't retro-fix existing literals, but pairs well
with Option A: introduce the constants in Phase 0 and replace `1280`/`720`/`640` references
with `GUI_W`/`GUI_H`/`GUI_W*0.5` as each screen is rescaled, so future res changes are one-line.
**Adopt the constants alongside Option A** (don't add a per-coordinate `ui_px()` call — it would
bloat every draw line; just author at native 1920×1080 with named canvas constants).

---

## D. Fonts — the #1 text-sharpness lever (REQUIRES IDE asset work by M)

Because all text is the default bitmap font today, **the single biggest sharpness win is adding
real font assets** — independent of, and more impactful than, the coordinate rescale.

Plan:
1. **M creates font asset(s) in the IDE** (Claude can't make `.yy`/`.yyp`). Proposal: one
   primary UI font (a clean readable face — e.g. the project's existing display look) added at
   **two or three point sizes** matched to the on-screen sizes we actually use at 1080p:
   - `fnt_ui` — body text (~22–24 px) — replaces default-font body draws.
   - `fnt_ui_small` — list sub-text / pips (~16–18 px).
   - `fnt_ui_title` — headers/titles (~34–40 px) — replaces the `draw_text_transformed(...1.4)` hacks.
   (Final px sizes set once we see them at native res; antialiasing ON.)
2. **Claude wires them:** a `ui_fonts_init()` + `draw_set_font(fnt_ui)` discipline — set the
   right font per text block, and **delete the `draw_text_transformed` scale hacks** for titles
   (draw at native size with `fnt_ui_title` instead, which is genuinely crisp vs. a scaled bitmap).
3. Body text that currently relies on `draw_text_ext` wrap widths is unaffected mechanically
   but must be re-checked for fit at the new font metrics (line heights change).

This step can be **partially decoupled**: even before the full coordinate rescale, swapping the
default font for `fnt_ui` would already sharpen text under the current pipeline. But final sizing
should be done on the native 1080p canvas, so it's sequenced into the re-base (Phase 2).

---

## E. Sprites / raster art — sharpness depends on source resolution

Native density only helps a sprite if its **source** is high enough res; otherwise a ×1.5 draw
still upscales it. Categories:
- **UI frame / panels** (`spr_ui_frame` gothic rim, backings): if drawn stretched/9-sliced these
  scale cleanly; verify they don't get soft. Re-export at 1.5× source if they read blurry.
- **Backgrounds** (`spr_hub_background`, `spr_combatbg_*`, `spr_floormap_*`): authored ~720p →
  will upscale (soft) on a 1080p canvas. For true sharpness, **re-generate at ≥1080p source**
  (PixelLab/source pipeline). Lower priority than text — backgrounds tolerate softness.
- **Pixel-art icons/sprites** (items, abilities, enemies, skins): drawn at fixed pixel sizes and
  typically nearest-neighbor — scaling the *draw size* ×1.5 keeps them crisp (pixel-art aesthetic
  is fine). Just scale their draw dimensions with the rest of the layout.

Art re-export is its own art-pipeline pass (§ Phase 4) and can lag the code re-base — the game is
fully playable with backgrounds slightly soft while text+geometry+icons are already native.

---

## F. Build order (phased, each phase compiles + is testable)

0. **✅ DONE (2026-06-26).** Canvas + constants + setup. GUI → 1920×1080 via
   `display_set_gui_size(GUI_W,GUI_H)` in `obj_game_controller/Create_0`; windowed sizing
   single-sourced in `scr_stats` `video_apply()` (auto-fit: native 1920×1080, clamped to the
   display only on sub-1080p monitors, centered). Added `GUI_W`/`GUI_H`/`GUI_CX`/`GUI_CY` macros
   at the top of `scr_ui.gml`. Stale "1280×720" setup comments updated. Everything now draws in
   the top-left quadrant (still 720p coords) — expected, temporary. **Not yet compile/launch-tested
   in the IDE.** No draw coords or hit-tests touched (incl. the `Step_0` literal — that's Phase 1+).
1. **✅ DONE (2026-06-26).** Rescale shared primitives + HUD + whole combat scene
   (`scr_ui.gml` combat cluster, `obj_combat_controller` Draw_64 + Step_0). All combat-only
   `scr_ui` primitives' internal sizes/offsets ×1.5 (hp/energy/secondary/turn-queue/ability-
   buttons/combat-log/telegraph/ability-tooltip/status-icon-row/boons/curses) + the
   `ui_draw_combat_hud` orchestrator call-sites. Draw_64: bg→`GUI_W/H`, enemy HP-bar 2-col grid,
   character/enemy **sprite layout + draw scale (×2→×3)**, VFX/shake/popup magnitudes, awakening
   label, ITEMS button + consumable quick-menu, End-Turn prompt, and ALL post-combat overlays
   (loot / level-up allocation / combat-result / boss-extract) with their hover hit-tests. Step_0:
   every clickable region rescaled in lockstep (ability buttons, End-Turn, ITEMS, quick-menu rows,
   combat-log scroll zone) + all damage-popup / VFX / attack-lunge anchor positions. **Fixed** the
   pre-existing enemy-HP-bar click hit-test that was out of sync with the bar layout — now matches
   the 2-column grid. Text left at default-font scale (Phase 2). Not yet compile/launch-tested in IDE.
2. **✅ DONE (2026-06-26).** Fonts — combat screen. M created `fnt_ui` (Georgia 24),
   `fnt_ui_small` (Georgia 18), `fnt_ui_title` (Georgia 40), AntiAlias on, all registered in
   `.yyp`. Wired across the combat cluster in `scr_ui.gml` + `obj_combat_controller/Draw_64.gml`:
   body→`fnt_ui`, sub-text/pips/badges/durations/log/hints→`fnt_ui_small`, big overlay titles
   (VICTORY/DEFEATED, LOOT FOUND, LEVEL UP, FLOOR CLEARED)→`fnt_ui_title` with the
   `draw_text_transformed(... static-scale ...)` title hacks **deleted** (drawn at native size now).
   Discipline: every block sets its font and restores `draw_set_font(-1)`; explicit `-1` resets
   before all shared-menu draws/exits (character menu, stash, pause, settings, tutorial stay
   default-font until Phase 3). Kept the **animated** damage-popup scale and `ui_draw_label_fit`
   shrink-to-fit (those are dynamic, not hacks). `ui_draw_ability_icon` left untouched (shared with
   Phase 3; self-adjusts to caller font). Fit fix: status badges widened 39→48px for 4-char labels
   ("STUN"). Dynamic-height sizing (ability tooltip, level-up hints) measures with the same font it
   draws. Not yet IDE compile/launch-tested.
3. **Rescale remaining screens** one at a time, each with its paired mouse hit-tests:
   hub + loadout (`obj_hub_controller` — the biggest), floor map + shrine/event overlays
   (`obj_floor_controller`), title, char-select, character menu + Compendium + stash + the NPC
   overlays / shops in `scr_ui.gml`.
   - **obj_hub_controller is 1705-line Draw_64 spanning 6 surfaces** → split into 3 tasks
     (M-confirmed): T1 main hub screen, T2 dungeon-select + run-history + perm-alloc, T3 Item
     Codex + Loadout. Fonts wired together with coords per surface. Shops are NOT here — they live
     in `scr_ui.gml` (`ui_draw_shop_screen`/`maren`/`sable`/`vael`), sequenced with the scr_ui pass.
   - **✅ T1 DONE (2026-06-26, not compile-tested).** Main hub `Draw_64` lines 1-545 (now ~567 after
     font lines): bg gradient/camp-cover/firelight/embers/vignette → `GUI_W`/`GUI_H`; all 8 panels
     (player-info, last-run, character, NPC-list, NPC-detail, portrait, enter-button, footer) ×1.5;
     every `draw_text_transformed(...static-scale...)` title/name/stat hack **deleted** → `fnt_ui`
     (body) / `fnt_ui_small` (sub-text/hints/footer) / `fnt_ui_title` (camp title + ENTER DUNGEON),
     each block sets its font + restores `draw_set_font(-1)` so the not-yet-rescaled overlays below
     stay default-font. `Create_0` ember spawn bounds → `GUI_W`/`GUI_H`. `Step_0` paired hit-tests
     rescaled in lockstep: NPC rows (630-1290, 105+i*96, h81), Enter Dungeon (1320-1890, 870-990),
     last-run dismiss (30-450, 420-642). NPC-desc `draw_text_ext` wrap re-checked (510 in 570-wide
     panel). Half-pixels: accent strips 3→4, shadow offsets 4→6. **Game boots clean (M F5-confirmed).**
   - **✅ T2 DONE (2026-06-26).** Three full-screen hub overlays in `Draw_64` ×1.5 + fonts, each
     self-contained (own dark cover → `GUI_W`/`GUI_H`, sets fonts, restores `draw_set_font(-1)` at
     end so the still-720p Codex/Loadout below stay default): (1) **dungeon-select carousel** —
     center card 720×765 @ (GUI_CX-360,123), side cards 429×570, `_name_scale`→`_name_font`
     (fnt_ui_title center / fnt_ui sides), art boxes 672×210 & 381×150, full center stack
     (divider/desc fnt_ui_small/Max-Awakening fnt_ui/selector box 66-tall/Q-E arrows fnt_ui/tier
     label/tier desc/confirm bar), side-arrow `<`/`>` as fnt_ui_title glyphs (78/1842, GUI_CY);
     (2) **run-history** — 9 columns (x 120-1500), rows pitch 90 from y195, fnt_ui_small headers+rows,
     fnt_ui empty-state, totals/hints fnt_ui_small; (3) **perm-alloc banner** (720×78 @ y714) +
     **full-screen overlay** (title fnt_ui_title, 6 stat rows 510-1410 pitch 108 from y255, fnt_ui).
     `Step_0` perm-alloc mouse hit-test rescaled in lockstep (510-1410, 255+i*108, h87). Not retested
     in IDE since T1 (no new font assets needed; same macros/fonts).
   - **✅ T3 DONE (2026-06-26, not compile-tested).** Item Codex (§12) + Loadout overlay (§11) + trait
     toast in `Draw_64`, paired `Step_0` hit-tests. **obj_hub_controller is now fully native (all 6
     surfaces).** Codex: cover→`GUI_W/H`, title→`fnt_ui_title`; left list (12 rows, pitch 46→69 from
     y80→120, x 20-740→30-1110, rarity strip 4→6, name `fnt_ui` / slot+stat-preview `fnt_ui_small`);
     scroll + discovered-count `fnt_ui_small`; detail pane `_dp` 760,80,500,560→1140,120,750,840 (fits
     1080), art box 132→198, **name was `draw_text_ext_transformed`→`draw_text_ext` + `fnt_ui_title` with
     `_ly` advanced by `string_height_ext` (long names no longer overlap the rarity subline)**; all
     wrapped bodies switched to natural line-height (`-1`) + re-measured `_ly` (lore/desc `fnt_ui`,
     stat-ranges/quote `fnt_ui_small`); footer `fnt_ui_small`. Loadout: tab bar (`fnt_ui` labels,
     `fnt_ui_small` Q/E), ability rows (icon 40→60, pitch 49→74 from y55→83, name `fnt_ui` / AP-tag+summary
     `fnt_ui_small`), 4 ability slots (72→108h, icon 56→84), traits tab (avail rows 60→90h pitch 64→96,
     locked rows 38→57 pitch, trait slots 82→123h), desc box (600-660→900-990), confirm/counter bar
     (665-695→998-1043), hints (700→1050). Deleted all 3 `draw_text_transformed` (Codex title, Codex
     empty-state, trait toast 260,14,1020,52→390,21,1530,78). Every block sets its font + section restores
     `draw_set_font(-1)`. `Step_0` lockstep: tab buttons (636-951/969-1284, y9-51), ability rows
     (60-1050, 83+i*74, h69), confirm bar (60-1860, 998-1043), trait rows (83+i*84, h78), gallery list
     rows (30-1095, 120+i*69, h63), close-X (1853-1883/108-138), alt-click rows (same as list). Half-px:
     accent strips 4→6, row-gap 3→5, tab gap 6→9. **NOTE: comparison panel is `ui_draw_comparison_panel`
     (a `scr_ui` func, Draw_64:1720) — LEFT for the scr_ui pass; only its alt-click trigger hit-test was
     rescaled here. NOTE 2: pre-existing trait-row pitch mismatch preserved (Draw 96 vs Step 84 — was 64
     vs 56; rescaled each ×1.5 so behavior is unchanged, not "fixed").**
   - **✅ obj_floor_controller DONE (2026-06-26, M F5-CONFIRMED boots clean — together with hub T3 Codex/Loadout).** Dungeon floor map — all 7 Draw_64
     sections + shrine (6b) + event-choice (6c) overlays ×1.5 + fonts, Create_0 node-graph layout
     rescaled, Step_0 node-click hit-test in lockstep. **Create_0:** graph band `x20..880,y100..680`→
     `x30..1320,y150..1020`, `_node_w/_node_h 130/64`→`195/96`, `_y_spread 110`→`165` (px/py are computed
     from these and persisted in `global.floor_map`, so Draw + Step auto-scale). **Draw_64:** `_NW/_NH`→
     `195/96`; header (title `fnt_ui_title`, dungeon name `fnt_ui`, awakening `fnt_ui_small`); node boxes
     (select ring 2→3, name `fnt_ui_small` via `ui_truncate(_NW-24)`, type/sense labels `fnt_ui_small`);
     detail panel `910,100,350,420`→`1365,150,525,630` (icon 56→84, name `fnt_ui` dual-draw shadow 1→2,
     type `fnt_ui_small`, desc `fnt_ui` natural line-height + re-measured, status/reward `fnt_ui_small` at
     ddy+255/+300/+330); treasure popup (cy 300→450, TREASURE! `fnt_ui_title`, body `fnt_ui`, sub
     `fnt_ui_small`); rest/trap popup (cy 450, title `fnt_ui_title`, body `fnt_ui` wrap 600→900); shrine
     6b (title `fnt_ui_title` y84, rows x220..1060→330..1590 pitch 108→162 h96→144, `fnt_ui` names /
     `fnt_ui_small` body+costs, cost cols 240/360/520→360/540/780); event-choice 6c (title dual-draw
     960/72 + shadow 962/74, body/result `fnt_ui` wrap 760/820→1140/1230, rows pitch 110→165 h98→147,
     right-info x1040→1560); footer `fnt_ui_small` y698/715→1047/1073. **All ~16 `draw_text_transformed`
     deleted.** `ui_draw_gothic_frame` CALL args rescaled to `(30,30,1890,1050,30)` (full-screen rim) in
     all 3 overlays — **its internals + the shared menus (`ui_draw_character_menu`/`ui_draw_item_picker`/
     `ui_draw_settings_overlay`/`ui_draw_pause_menu`/`ui_draw_tutorial_tip`) are `scr_ui` funcs LEFT for the
     scr_ui pass** (render at 720p until then). `draw_set_font(-1)` restored before the shared-menu calls.
     Step_0 node box `px-65/py-32 130×64`→`px-98/py-48 195×96` (other clicks are coordinate-free full-screen
     mb_left; shrine/event overlays are keyboard-nav, no row hit-tests).
   - **✅ obj_title_controller DONE (2026-06-26, not compile-tested).** Title screen — all 3 phases in
     `Draw_64` ×1.5 + fonts; keyboard-nav only (no `Step_0` hit-tests). Bg + vignette → `GUI_W/H`.
     **Cutscene:** `fnt_ui` body, line-sep `_sep 32→48`, `_gap 22→33`, block centred on `GUI_CY`, text
     960 / shadow 962 (+2), wrap 900→1350; skip hint `fnt_ui_small` @y998. **Title:** IRONWAKE logo — the
     3 layered `draw_text_transformed` (glow 3.7 / shadow 3.5 / main 3.5) **deleted** → `fnt_ui_title` at
     native (960,300), shadow offset +4→+6 (966,306); glow keeps its low-alpha colour underlay (size-halo
     dropped, no font-scale hack); subtitle `fnt_ui_small`; decorative line 2→3px (585,428,1335,431); menu
     options `fnt_ui` (oy 390+62i→585+93i, sel-highlight 660-1260 ±33, caret `>` @698), "no saves"/nav/
     settings hints `fnt_ui_small`. **Slot picker:** title `fnt_ui_title` @y120, subtitle `fnt_ui_small`;
     3 cards `_card_w 340→510 / _card_h 220→330 / _card_y 220→330 / _gap 30→45`, `_start_x`→`GUI_CX`-based;
     header bar 32→48 + slot label `fnt_ui` @+12, name `fnt_ui` @+83, 4 stat lines `fnt_ui_small` pitch
     22→33 from +135, warning/no-save `fnt_ui_small` @-54; gothic-frame CALL band 10→15 (internals left for
     scr_ui pass); arrow caret `fnt_ui` @+21. Every block sets its font + `draw_set_font(-1)` before the
     settings-overlay call and at the reset tail (overlay = `ui_draw_settings_overlay`, scr_ui func).
   - **✅ obj_char_select DONE (2026-06-26, not compile-tested).** Class/character select — `Draw_64` ×1.5 +
     fonts, `Step_0` mouse hit-tests in lockstep. Panel consts `_panel_w 344→516 / _panel_h 410→615 /
     _gap 24→36 / _panel_y 116→174 / _panel_x0`→`GUI_W`-based (=150). Bg → `GUI_W/H`. Title IRONWAKE
     `draw_text_transformed 2.5` **deleted** → `fnt_ui_title` (960,60) + shadow +2 (962,62); subtitle `fnt_ui`.
     Class panels: name `fnt_ui` (shadow +1→+2); **gender selector `_gtarget 100→150, _cellhw 58→87, _gy
     +98→+147, _mx/_fx ±70→±105`**, sprite draws auto-scale via `_gtarget` (§E), placeholder/labels
     `fnt_ui_small`; single-preview `_ucy +104→+156, target 128→192`; description `draw_text_ext` → `fnt_ui_small`
     natural line-height (-1), pad +14→+21 / +188→+282, wrap `_panel_w-28→-42`; stat block `_stat_block_y +272→
     +408, line_h 20→30`, `fnt_ui_small`; SELECTED `fnt_ui_small` @-27. Stat-alloc row: `_alloc_y 540→810`,
     `_alloc_cx`→`GUI_CX`, Free-Points `fnt_ui`; boxes `_box_w 80→120 / _box_h 52→78 / _gap 10→15`, `_row_x0`
     =`GUI_CX`-row/2 (562.5), `_box_y +22→+33`, label `fnt_ui_small` @+15 / value `fnt_ui` @+48; stat-desc +
     key hints `fnt_ui_small`. Instruction bar `_inst_y 680→1020` `fnt_ui_small`. Name overlay → `GUI_W/H`,
     title `fnt_ui_title` @y405, box `390,320,500,52→585,480,750,78`, typed text `fnt_ui` @+21, hints
     `fnt_ui_small` @y597. Portrait overlay → `GUI_W/H`, title `fnt_ui_title` @y90, center `320→480` @(GUI_CX-240,240),
     border ±2→±3, gothic-frame band 24→36 (CALL only), thumbs `160→240` gap 24→36, counter `fnt_ui` /
     instructions `fnt_ui_small`. **`Step_0` hit-tests lockstep:** stat boxes (row_x0 562.5, stride 135, w120,
     y843-921) + confirm bar (y1005-1073) rescaled ×1.5 to match draws. **FIXED (flagged): the class-panel
     click hit-test was a PRE-EXISTING mismatch (`x0=200/stride=300/w=280/y120-530` vs draw `x0=100/stride=368/
     w=344/y116-526` — dead-zones + wrong-panel selection); rebuilt to true lockstep with the native draw
     (x0=150, stride=552, w=516, y174-789). This is a behaviour correction, not a silent rescale — confirm OK.**
   - **scr_ui.gml shared-menu cluster (LAST P3 group) — ~3000 lines across ~15 screen funcs, split into
     sub-tasks (one screen-group ≈ one task), shared with combat so re-test combat after each.** Sub-task map:
     **A = cross-cutting overlays** (pause/tutorial/settings/item-picker); **B = character menu + Compendium**
     (`ui_draw_character_menu` ~825 lines, `ui_draw_ability_detail`, `ui_draw_trait_detail`); **C = stash +
     shop + comparison + item tooltip** (`ui_draw_item_tooltip`, `ui_draw_stash_screen`, `ui_draw_shop_screen`,
     `ui_draw_comparison_panel`); **D = NPC screens** (`ui_draw_trainer_screen`/`statpick` = Vex,
     `ui_draw_maren_screen`, `ui_draw_sable_screen`, `ui_draw_vael_screen`/portrait-tab). NOTE: the combat-only
     primitives (hp/energy/turn-queue/ability-buttons/log/tooltips/status/boons/curses + `ui_draw_combat_hud`)
     are already P1/P2-done; the icon helpers (`ui_draw_item_icon`/`ui_draw_consumable_icon`/`ui_draw_ability_icon`)
     are size-parameterized — callers pass the scaled `sz`, no internal rescale needed. **`ui_draw_gothic_frame`
     is fully parameterized (draws relative to passed `x1,y1,x2,y2,band`) — resolution-independent, NO internal
     rescale; the earlier "gothic_frame internals" flag was a no-op.**
   - **✅ Sub-task A DONE (2026-06-26, not compile-tested).** Cross-cutting overlays ×1.5 + fonts, paired input
     hit-tests in `scr_stats`. **Pause menu** (`ui_draw_pause_menu`): bg→`GUI_W/H`, panel 360×300→540×450 @
     `GUI_CX`, "Paused"→`fnt_ui_title`, 3 rows `fnt_ui` (_row_h 56→84, _first_y 312→468, _bx0/1 490/790→735/1185,
     row-h 44→66), legend kept shrink-to-fit but base `fnt_ui_small`; `pause_menu_step` hover hit-test rescaled
     lockstep (735-1185, 468+84r, h66). **Tutorial tip** (`ui_draw_tutorial_tip`): bg→`GUI_W/H`, _bw 660→990,
     wrap-pad 80→120, body `fnt_ui` natural -1 (was sep 22) + box auto-sizes to `string_height_ext`, title
     `fnt_ui_title`, footer `fnt_ui_small`, gothic band 20→30; input is any-key/click (coordinate-free).
     **Settings** (`ui_draw_settings_overlay`): bg→`GUI_W/H`, panel 560×452→840×678 @ `GUI_CX/CY`, title
     `fnt_ui_title`, rows `fnt_ui` (_row_y +100→+150, _row_h 72→108, _bar_x +200→+300, _bar_w 280→420, _bar_h
     18→27, pills 92→138), hints/(F11)/flash/footer `fnt_ui_small`; input keyboard-only (no hit-test). **Item
     picker** (`ui_draw_item_picker`): panel 220,110,840,500→330,165,1260,750, list (_lx0 +16→+24, _lx1 +404→+606,
     _ly0 +86→+129, _rh 38→57, row-h 34→51, inline icon 28→42), detail pane (_dvx/_dx/_dr, big icon 64→96, name
     `draw_text_ext` `fnt_ui` natural -1, all wrapped bodies sep 20→-1 + re-measured, `fnt_ui_small`), confirm/
     footer band (_cby 76/40→114/60); header `fnt_ui` / sub+rows+detail+footer `fnt_ui_small`; `item_picker_step`
     BOTH hit-test blocks (hover + click incl. confirm-bar `_px+20→+30`) rescaled lockstep. Per-block font +
     `draw_set_font(-1)` on every exit. **Also fixed (in-scope): `dungeon_bg_draw` stretched the surface bg to
     `1280×720`** — called by the already-native combat + floor Draw_64, so their backgrounds only filled the
     top-left quadrant → changed to `GUI_W/H`. (Boots fine; was a visual bug missed by P1/floor passes.)
   - **✅ Sub-task B DONE (2026-06-26, not compile-tested).** Character menu + Compendium + ability/trait
     detail. `ui_draw_ability_detail` + `ui_draw_trait_detail` (full-screen Tab popups → `GUI_W/H`, panels
     ×1.5, `fnt_ui_title` name/`fnt_ui` body/`fnt_ui_small` labels, wrapped bodies natural -1; chip auto-position
     recomputed in `fnt_ui`). `ui_draw_character_menu` (~825 lines, 5 tabs) fully ×1.5 + fonts: tab bar
     (168×44→252×66, _tx 204+176i→306+264i), Stats tab (2-col stat grid + Offense/Defense readouts `fnt_ui_small`,
     portrait card 820-1200→1230-1800 sprite ×1.5, readiness + Boons&Effects), Equipment tab (9 slots 520×96→780×144
     2-col stride 580→870, icons 40→60, rarity/name/stat fonts), Equip-picker overlay (240,120,800→360,180,1200,
     row_h 72→108, eq-offset 72→108, hover tooltip anchor), Abilities tab (rows 130→195), Consumables tab (windowed
     rows 80→120 pitch, icons 48→72), Compendium tab (left list 46→69 pitch, detail `fnt_ui_title` + entries). Paired
     `obj_game_controller/Step_0` hit-tests all rescaled: tab bar (306+264i, 30-96), Compendium list (60-450, 135+69i),
     equip slots (60+870col, 171+162row, 780×144), equip-picker rows (228 base + 108 eq-off + 108i, 366-1554, h102),
     consumables (195+120i, 60-1350, h98). NOTE: pre-existing abilities-tab row-pitch mismatch (Step 96 vs draw 126)
     preserved (was 64 vs 84 — rescaled ×1.5, behaviour unchanged).
   - **✅ Sub-task C DONE (2026-06-26, not compile-tested).** Item tooltip + stash + shop + comparison.
     `ui_draw_item_tooltip` (content-self-sizing: `_pad 10→15`, `_lh 20→27`, `_tw_min/max 300/470→450/705`, screen-clamp
     1270/710→1905/1065, `fnt_ui_small`). `ui_draw_shop_screen` (Petra/Dorn — bg→`GUI_W/H`, title `fnt_ui_title`,
     BUY/SELL tab bar 400-625/655-880→600-938/983-1320, rows _rx0 100→150 _rw 1080→1620 _rh 78→117 _ry0 126→189,
     gothic frame, all 3 list branches + confirm bar 636→954 + footers; `shop` Step hit-tests: tabs + rows 126+84i→189+126i,
     150-1180→150-1770 h117). `ui_draw_stash_screen` (2 cols 570→855 @ _lx 30→45 / _rx 680→1020, rows _row_h 50→75,
     icons 20→30, hover tooltip + alt-click compare, gothic frame). `ui_draw_comparison_panel` (centred, _row_h 28→42
     _hdr 78→117 _pw 500→750 @ `GUI_CX/CY`, headers `fnt_ui`/rows `fnt_ui_small`). Stash row-select is keyboard-only
     (no Step hit-test) — only the draw-embedded hover/alt-click rescaled.
   - **✅ Sub-task D DONE (2026-06-26, not compile-tested) — `scr_ui.gml` now FULLY native.** NPC screens.
     Vex (`ui_draw_trainer_screen` 5 tabs + `ui_draw_trainer_statpick` popup): tab bar 45+240i/64-96→68+360i/96-144,
     rows _rx0 120→180 _rx1 1160→1740 _ry0 150→225 _rh 58→87, ability rows 78→117 icon 56→84, potency pips 540+18p→810+27p,
     statpick popup 420,170,440,440→630,255,660,660 with −/+ buttons; Vex+statpick Step hit-tests all lockstep
     (tabs 68+360i, rows 225+96i h87, statpick rows 375+60i + −/+ btns 48-wide + confirm bar). Maren
     (`ui_draw_maren_screen` 4 tabs + `ui_maren_row` helper): `ui_maren_row` 200,_base190,48-pitch,44h→300,285,72,66;
     tab bar 245+200i/70-110→368+300i/105-165; shared `_list_x/_list_x2/_row_y0 200/1080/190→300/1620/285`; bulk-updated
     the shared row offsets (`_list_x+16→+24`, `_list_x2-16→-24`, `_row_y0+8→+12`, breadcrumbs `,150/168→,225/252`)
     across Maren+Sable (both use the same convention); Maren Step hit-tests (tabs 368+300i/105-165, rows 285+72i 300-1620).
     Sable (`ui_draw_sable_screen` 4 tabs, reuses `ui_maren_row`): header/tabs 345+200i→518+300i, constants→300/1620/285,
     Rebirth-tab unique coords 176/200/226→264/300/339; Sable Step hit-tests lockstep. Vael (`ui_draw_vael_screen`
     skins-tab list + `ui_draw_vael_portrait_tab` carousel): own coords — tabs 560/720±72@58-90→840/1080±108@87-135,
     skin list 200-800 y150 row48→300-1200 y225 row72, detail panel 840-1250→1260-1875 preview 210→315, portrait
     carousel 300→450 thumbs 120→180; Vael Step hit-tests lockstep (tabs ±108@87-135, list 300-1200 225+72i). All NPC
     screens: title `fnt_ui_title` / body+rows `fnt_ui` / sub-text+hints `fnt_ui_small`, per-block font + `draw_set_font(-1)`
     on exit, gothic-frame calls → `(30,30,1890,1050,30)`. **Phase 3 is now COMPLETE — every screen renders native 1080p.**
4. **✅ DONE (2026-06-26) — backgrounds sharpened, UI frame verified.** Key finding: PixelLab
   `create_map_object` caps at **400px** and every background was already 400px, so "regenerate at a
   bigger source" via PixelLab was impossible — and the softness was never source-size, it was
   `option_windows_interpolate_pixels:true` bilinear-stretching the 400px texture to 1920 (4.8×).
   **M-confirmed fix (no PixelLab credits): nearest-neighbor upscale the existing 13 background sprites
   ×4 (400→1600px; hub 400×218→1600×872) and re-import.** GM now only bilinear-stretches 1600→1920 (1.2×)
   instead of 4.8× → crisp, pixel-art look preserved. Done via `scratchpad/upscale_bgs.py`: PIL NEAREST
   resize of each sprite's frame + layer PNGs, plus regex-patch of the 4 `.yy` dimension fields
   (`width`/`height`/`bbox_right`/`bbox_bottom`); GUIDs/origin untouched so GM keeps the asset identity.
   Draw code needed NO change (`dungeon_bg_draw` / hub camp-cover already stretch to `GUI_W/H`). **UI frame
   `spr_ui_frame` (192×192) left as-is** — 9-sliced with corner scale `band/42`, and the bands used (10–45)
   downscale the corners → already crisp; reads sharp in-game. **NOTE:** the ×4 textures add ~74MB VRAM
   (fine for desktop); if the HTML5/itch build needs trimming, drop to ×3 (1200px) or a compressed texture
   group. **The native-1080p re-base is now COMPLETE (P0–P4).** Reload/compile in the IDE to pick up the
   new sprite dimensions.

Sequencing note: Phases 1 and 3 are the bulk and should be split across **several compaction
cycles** (one screen ≈ one task), per CLAUDE_SETTINGS. Phase 0 must land first and alone so the
canvas is correct before any coordinate work.

---

## G. Decisions (locked 2026-06-26 unless noted)

1. **Windowed default on small monitors → AUTO-FIT (locked).** Author the GUI at native
   1920×1080; let GM scale the *window* down only when the physical display can't fit it. True
   native sharpness on ≥1080p displays; still runs on smaller ones (scaled). Implement via the
   window/GUI setup in Phase 0 (open at 1920×1080, clamp window to display size, center).
2. **Font face + sizes → IN PROGRESS.** GM fonts are bitmap atlases baked per size, so we create
   the face at **2–3 separate sizes** (drawn at native size, never scaled). Source: any installed
   Windows family (Segoe UI / Georgia / Garamond) via Fonts → Create Font, OR a free gothic TTF
   from Google Fonts (titles: **Cinzel**/Cinzel Decorative; body: **EB Garamond**). M creates the
   asset(s) in the IDE. **Unblock placeholder: `fnt_ui` = Georgia @24** now; finalize face +
   `fnt_ui_small`(~18) + `fnt_ui_title`(~40) during Phase 2 once seen at native res. AA on.
3. **Scale factor → clean ×1.5 (locked).** 1280→1920, 720→1080 exactly. Keep 16:9. Centers
   `640→960`, `360→540`. Round any odd half-pixels to nearest whole.
4. **Background art → RE-GENERATE as part of this (locked).** Backgrounds (hub/combat/floor) get
   re-generated at ≥1080p source during the re-base rather than shipped soft. This pulls Phase 4
   onto the critical path (PixelLab/source pipeline) — schedule it after the code phases so the
   layout/sizing is final before art is regenerated to fit.
5. **Hit-test method → lockstep rescale (locked).** Rescale each clickable region with its draw in
   the same edit; mouse coords stay real GUI pixels (no logical-720p shim).

---

## H. Risks
- **Missed hit-tests** → clicks land off-target. Mitigation: rescale draw + its mouse region in
  the same edit; test each screen's clicks before moving on.
- **`draw_text_ext` wrap widths** authored for the default font reflow under new font metrics →
  re-check overflow per screen during Phase 2/3.
- **Half-pixel rounding** accumulating into 1px seams on stacked panels → prefer rescaling the
  panel's anchor + size rather than each derived edge independently.
- **Scope creep into a regex mass-replace** → forbidden; numbers are overloaded (alphas, colors,
  scales). Manual, per-screen only.

Builds on the whole UI surface; independent of gameplay systems. Pairs with the art pipeline
(§ Art notes in ROADMAP) for the raster re-export tail.
