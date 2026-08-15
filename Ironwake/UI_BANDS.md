# UI_BANDS.md — reserved text/UI y-bands per screen (1920×1080 GUI)

**Rule (M 07-29):** every screen's fixed text lines OWN a y-band. New text
claims a FREE band, or — if it must share — it SUPPRESSES the occupant while
visible (the Vex sacrifice-bar pattern), never draws over it. When you add or
move a band, UPDATE THIS FILE in the same change. Anything placed after
variable-width text must be positioned with `string_width()` measured in the
font it draws with.

Verified bands (file references are approximate anchors, not exact lines):

## 2.5D COMBAT STAGE BANDS (round 11, M 08-13: "hard assign some spacing rules")
Every actor and UI panel in 2.5D combat owns a region. NOTHING may stand
inside another owner's region. `combat_enemy_slot_pos` + the Draw anchors
enforce these; when a station or panel moves, UPDATE THIS TABLE in the same
change. All sprite metrics come from `sprite_true_bounds` (measured pixels) —
never canvas size or .yy bbox metadata.

| Region | Owner | Rule |
|---|---|---|
| x0–330, y568–741 | POTENTIAL DAMAGE box (bottom-pinned 741, rides the log top) | no actor may enter |
| x0–330, y30–345 | Left HUD stack: HP 30 / AP 90 / resource 140 / Lv 185 / **buffs+debuffs 222–278** / **PET bar 290–316** / traps+boons+curses below | player-owned readouts; buff row is DIRECTLY under the level block (M: under pet bar read as pet effects) |
| x20–1200, y747–945 | Combat log (198px = exactly 6 rows, zero waste — 08-13) | enemies must bottom out ABOVE y747; near feet ≤702 |
| x1220–1890, y747–945 | Ability card (198px band, matches log) | never covered by anything |
| y946–982 | End Turn strip | — |
| y985–1080 | Ability buttons | — |
| Player: x330, feet y726 | hero, shipped 345px canvas scale (round 12) | near-camera anchor; VFX bind to the Draw-stamped player_stage_cx/cy |
| Pet: beside player (flat formula +130), feet 706, 0.90 size | round 12: BACK beside the player | clear of PD box + log |
| Summon: (560, 700) | mid-lane pedestal | between ally and enemy wedges |
| Enemy wedge: x≥1015, ALL feet ≤702 | 4 stations/layout, far 1.56× → front 1.72× (08-16 flatten; was 1.50→1.85), boss center 2.45× feet 655 cap 250 | HARD 185px visible ceiling (Boss-KIND on an ordinary station: 215); `enemy_size_mult` = species table THEN bestiary kind (Elite ×1.14, Boss ×1.30) applies before it; stations FREEZE per enemy; mid-fight summons walk to the first unclashed spot (13d); target reticle = constant 0.50 scale (~64px) |
| Horizon y470 | wall/floor seam | far stations start feet ≥540 |


## Floor map (obj_floor_controller/Draw_64)
| Band (y) | Owner |
|---|---|
| 30–96 | HP / gold readout (top-left; floating "-N" rises FROM 30 upward) |
| 102 | Escape-item hint ([G] Use …) — hidden during event/shrine/treasure overlays |
| 998–1043 | (detail panel) footer region of popups |
| 1047 | "E: Extract" footer line |
| 1073 | Key legend (GUI_CX centered) |
| 352–496 | Shrine-celebration popup panel (centered ~430) |

## Hub (obj_hub_controller/Draw_64)
| Band (y) | Owner |
|---|---|
| 300–780 | Bond-dialogue window (modal — dims everything behind) |
| 372–708 | IRONMAN resume popup (modal) |
| NPC panel rows | Bond line + "Favor: …" progress at x+210 (truncated to 470px) |

### Hub CAROUSEL center column (x630–1290, carousel mode 07-31)
| Band (y) | Owner |
|---|---|
| 105–945 | Stage panel (border + accent strip at top) |
| 140–540 | Stage art (actor bottom-anchored y540, ≤400px tall; arrows 300–440) |
| 556–~600 | NPC name (fnt_ui_title, measured auto-fit ≤600px wide) |
| 604–634 | Bond heart slots (4× 30px) |
| 646–684 | Bond/board line + progress bar (646 text, 676–684 bar) |
| 700–~781 | Role line (wrapped 600px, ≤3 lines measured) |
| ~730–792 | Nav hint (measured: role bottom +15, clamped ≤792) |
| 822–888 | Jump strip (8× 66px chips; below the swipe zone y≤810) |
| 951–1000 | (touch) flavor line band — clamped BELOW the opaque stage panel (bottom y945; 08-11 fix — the old 888 top hid line 1 of a wrapped message behind the panel). Taller messages auto-shrink to the band. |

## Character menu STATS tab (scr_ui, content_y=135; x: left col 60, mid col 540, right col 1230)
| Band (y) | Owner |
|---|---|
| 135–210 | Class / level / HP header + epithet line |
| 261–405 | Core stat grid (2 cols; hover popup floats at cursor) |
| 429–648 | Offense: damage bonuses (left) / crit rates + notes (mid) |
| 711–873 | Defense: dodge/reduction/HP/Armor (left) / accuracy + notes (mid) |
| 876–961 | Fortune header + Gold Find / Loot Find (mid col x540, 07-31) |
| 945–981 | Gold + Run/Floor footer (left col x60) |
| 1008–1041 | Bonds summary line (left, truncated 1120px) |
| (overlay) | Stats guided tour: dim + highlight rect + measured card (07-31) |

## Character menu ABILITIES tab (scr_ui; 3 pages walked with A/D, 08-08)
Page chips are drawn LAST so the panel frames can't clip them. Only ONE page
body draws at a time — the "no abilities" fallback is scoped to page 0, which is
what made it print through the CLASS TRUNK header (M screenshot 08-08).

| Band (y) | Owner |
|---|---|
| 104–142 | ABILITIES / CLASS TRUNK / TALENTS chips (3× w280 gap10, centered) |
| 144–170 | **DEAD ZONE — gothic frame filigree.** `ui_draw_gothic_frame` draws its ornamental band OUTSIDE the box, `band` px above y1. All five abilities-tab panels use band 26, so a panel at y150 threw filigree up to y124, straight through the chips (M screenshot 08-08). Panel tops are **y170** so the band lands at 144, just under the chips. **Any new panel on this tab starts at 170, not 150.** |
| 170–1012 | Page body panel (all three pages share this top) |
| — page 1 CLASS TRUNK | |
| 178–214 | Class + resource header (left) / "Permanent Level N" at +14 (right-aligned x1820) |
| 216–243 | Rules line — kept ≤130 chars so it ends by x1290 |
| 252–962 | 5 node rows (y=252+r*142, h=126; box A x260–1000, box B x1090–1830) — **ABSOLUTE, mirrored in gc Step click zones**, so they did NOT move with the panel; that is why the trunk header offsets are tighter than the other pages' |
| 958–1000 | Footer: hints, or the armed confirm bar (replaces the hints) |
| — page 2 TALENTS (all offsets are _y1-relative, so they moved +20 with the panel) | |
| 186–726 | Left list: 1 row per loadout ability (≤5, h=108) + 4 progress pips at row+58 |
| 213–270 | Right: icon + ability name + cast count |
| 320–456 | Explainer + next-milestone line |
| 456–534 | "points waiting" callout (only when unspent points exist) |
| 534–914 | WOVEN header + up to 4 node cards (h=84, step 92); loop breaks before _td_y2-64 |
| 972–1000 | Footer key hints |
| — page 0 ABILITIES | |
| 186+ | Left list rows start at panel top +16; **gc Step hit-test hardcodes 186** — change both together |

## Sable REBIRTH tab (scr_ui ui_draw_sable_screen)
| Band (y) | Owner |
|---|---|
| 225 | Title + M's flavor line (fit-scaled) |
| 285–495 | 3 craft rows (72px stride, name + tagline only) |
| 531–963 | Detail panel: selected craft's full body + cost list + eligibility |
| 999 | sable_notification (unchanged) |
| 1026 | Key legend (unchanged) |

## Bairc panel LEFT column (scr_ui ui_draw_bairc_screen inset panel)
| Band (y, within the inset panel `_lp_y0.._lp_y1`) | Owner |
|---|---|
| `_list_y` … `_lp_y1 - 198` | STABLE roster scroll window (`_vis` MEASURED from the space left above the garden band; visible scrollbar in the right gutter when overflowing) |
| **`_lp_y1 - 190` … `_lp_y1`** | **HIS GARDEN band — ALWAYS reserved (08-11, M: "it should always show")**. Header at band top, divider +30, earth wash below; pond ellipse left (cx `_list_x+140`), memorial headstones right edge on the back floor, creatures on two depth lanes (back floor `_lp_y1-60` @40px, front floor `_lp_y1-14` @54px, ≤10 shown, "+N more" in the header). Roster rows may NEVER draw into this band — the scroll window capacity subtracts it. |

## Shared modals (07-31, drawn over screens)
- Forge-result reveal popup: centered, MEASURED height (item card / lines).
- Cursed-rebirth ritual overlay: full-screen veil, text at y540/y640.

## Loadout overlay (hub Draw_64, loadout section)
| Band (y) | Owner |
|---|---|
| 921 | "All N abilities chosen…" helper line |
| 998–1043 | Confirm bar (breathing fill + glow when focused) |
| 1010 | Status/flash text INSIDE the confirm bar (gold-shortfall red, locked, full, count) |
| 1050 | Key legend (kb/pad only) |

## Combat (obj_combat_controller/Draw_64)
| Band (y) | Owner |
|---|---|
| **diagonal x742–1104, y468–672** | **Deployed trap field** (`ui_draw_trap_field` + `trap_field_pos`, Shadowstrider only). NOT a rectangular band — STATIC stations (08-11: slot stamped at deploy, traps never displaced) at `f=(slot+1)/cap` on the DIAGONAL from (700,700) up to (1040,596), bottom-centre anchored, 64px props drawn at 2x. The player-end stretch (f<0.5 at cap 2) is deliberately unused — it overlapped the pet companion row (feet up to ~(720,726)). Measured clearances, re-check ALL of these before moving it: combat log x30–1200/y735–945, enemy HP bars x990–1885/y86–432 (36px above the highest prop top), pet companion feet ≤(720,726) vs nearest station left edge 806, enemy sprites start x1143 at a 4-wide row. Read-only, no hit-test. Armed ring + charge pips carry the filter colour; the prop art is drawn untinted. |
| 690–762 | *(retired 08-09)* the old horizontal trap CHIP strip lived here. Freed. |
| 90–173 | Loot screen title + "Items collected" header |
| 96–168 | Fortune's Favor chip (x 1560–1870) |
| 240–~1023 | Loot rows (98px stride, 8 visible) |
| 953 | Loot scroll hint (kb only) |
| 990 | "Enter / R to continue" |
| 987–1041 | Vex trainer: sacrifice confirm bar — key legend HIDDEN while it owns the band |

## Vendor option rows (shared standard, 08-08; font-size aware 08-14)
`ui_draw_option_row(x1,y1,x2,y2,opt)` is now THE row for every vendor craft/service
menu (M: "wall of text issues, need more text color variance"). It owns its box and
enforces the split: accent-coloured TITLE (fnt_ui) at y1+8, dim body (fnt_ui_small)
at y1+max(41, 12+measured title height), cost chips right-aligned from y1+14 in 27px
steps. **The text column is measured against the widest cost chip and truncated to
clear it by 24px** — a long description can never run under a price. Row height must
be >= 66 for both text lines to sit inside the plate. Callers own geometry AND
hit-testing (hit-tests live in Draw), so caller and helper must agree on the same box.

## Vendor list metrics (M 08-14 font-size pass — HARD RULE)
`ui_vendor_row_pitch()` / `ui_vendor_visible_rows(n_default)` in scr_ui are the ONLY
source of vendor list row pitch and window capacity. Default/Small return the shipped
72px / n_default verbatim (bit-identical layouts); Large measures the fnt_ui +
fnt_ui_small variants and grows the pitch (row box = pitch-6). Consumers (keep in
sync — never hard-code 72/66/9/10 again): ui_maren_row + maren_visible_rows + Maren
Forge menu + Sable salvage/rune/transmute/brew/chaos windows + transmute/chaos pick
rings + Vael skins/tints/reweave lists (draw), and the matching mouse hit-tests in
obj_game_controller Step (Maren rows, Sable rows, Vael skins/tints/reweave).
`ui_draw_key_legend` also self-clamps its text bottom to the gothic-frame opening
(y≤1046) at any font size — callers keep passing the shipped y values.

## Maren FORGE tab (scr_ui, maren_phase == 0)
| Band (y) | Owner |
|---|---|
| 225 | "Maren's Forge - choose your craft:" |
| 285–717 | 6 option rows (285 + i*72, h66, x300–1500) — was 7 before TEMPER moved to Dorn |

## Dorn REFORGE tab (scr_ui ui_draw_dorn_reforge, shop_tab == 2) — 08-11 Pattern Book rework
Row geometry is DUPLICATED in obj_game_controller/Step (**5 visible** since 08-11,
pitch 102, top y255) — change both together or clicks misroute.
| Band (y) | Owner |
|---|---|
| 189–900 | Left panel x150–600 (ingots 243+t*70, fuse 610–654, forge block 668–836, hint ≤844) |
| 189–900 | Right panel x630–1500 |
| 255–759 | Gear rows (255 + i*102, h96; **5 visible** — was 6) |
| 772–824 | Pattern Book verb row: SMELT x642–922 / PATTERN BOOK x934–1214 / CRAFT x1226–1488 |
| 870 | "N / M" position readout — only when the list scrolls |
| 1026 | Key legend |

Overlays (each owns the full 150–1500 × 189–900 panel while open):
- CRAFT wizard (ui_draw_pattern_craft): title 204, breadcrumb 241, pick rows
  **9 visible** (300 + i*56, h50 — mirrored in gc Step), scroll bar x1468–1476,
  phase-3 counter line 272, legend 1026. Naming: box 560–1360 × 460–530,
  buttons 580–636. Result: card 660–1260 × 300–640, buttons 700–756, hint 780.
- BOOK browser (ui_draw_pattern_book): header 204, wrapped subtext 233–~281
  (width 1240), family rows **10 visible** (297 + i*56, h50 — mirrored in gc
  Step, end 851), scroll bar, UP/DOWN touch arrows top/bottom right,
  CLOSE 810–1110 × 856–896, legend 1026.
- SMELT study popup (ui_draw_pb_smelt): bottom-anchored to y780, dim + bordered
  box x510–1410, family rows h48 pitch 54, SMELT/CANCEL buttons y690–756.

## Dorn TEMPER tab (scr_ui ui_draw_dorn_temper, shop_tab == 3)
Row geometry is DUPLICATED in obj_game_controller/Step (7 visible, pitch 90, top
y255) — change both together or clicks misroute.
| Band (y) | Owner |
|---|---|
| 96–138 | Shared shop tab bar (4 tabs for Dorn: BUY/SELL/REFORGE/TEMPER) |
| 219 | List caption |
| 255–879 | Gear rows (255 + i*90, h84, x60–900; 7 visible) |
| 888 | "Showing N-M of T" — only when the list scrolls |
| 255–890 | Preview panel (x940–1860): header 275, name 307, rule 355, NOW/AFTER 371, rule 403, delta rows from 417 (33px pitch), footnote clamped to <= _py2-96 |
| 906–960 | Confirm bar (also a tap target) |
| 1026 | Key legend |

## Shops (Dorn/Petra, scr_ui)
| Band (y) | Owner |
|---|---|
| 189–936 | SELL list rows — **6 visible** (`shop_sell_visible_rows()`), y=189+i*126, h=117. Was 7, which ended at y1062: through the legend and out into the perimeter frame (M 08-08). A row holds 3 lines (name +12, stats +45, effect +75, ending ~+102) so the height can't shrink enough to fit 7. Window size is read by the draw loop, the Step scroll clamp and the Step click hit-test — never hardcode it again. |
| 954–1023 | Sell confirm bar (only when `sell_confirm_name != ""`) |
| 1026 | Sell-tab footer key legend (centred 960, ends well short of x1450) — swaps to confirm hint when confirm pending |
| 1026 | "Showing N-M of T   W/S to scroll" — RIGHT-aligned x1770, shares the legend's line |

## Global overlays (drawn topmost)
- Touch chips / back chip / on-screen d-pad: bottom + left gutter, always last.
- Tutorial coach-marks: drawn last; keep panels clear of active tutorial anchor.
- Notification lines (hub `notification`, shop `shop_notification`): single
  line, screen-specific y — check the target screen before reusing.
- **TOASTS (08-04 STANDARD, M's order): every transient floating notice goes
  through `ui_draw_toast()` (scr_ui) — measured backdrop box + border, called
  at the END of the owning Draw so it's topmost. NEVER bare `draw_text`.**
  - Trait-unlock toast: y21–~90 centered (hub + floor + combat; clears combat
    enemy grid at y96 and floor's top-LEFT HP band).
  - Character-menu equip toast: y52–~115 centered, above frame + tabs.

## Character menu (all tabs, scr_ui ui_draw_character_menu)
| Band (y) | Owner |
|---|---|
| 52–~115 | Equip-confirmation toast (ui_draw_toast, drawn LAST/topmost) |

*Started 07-29 from verified reads; extend as screens are touched. Unlisted
screens are NOT collision-free — they're unaudited.*

## COMBAT LEFT COLUMN (M 08-15 reorder — HARD MAP)
| y | element |
|---|---------|
| 24 | "Lv X" label (fnt_ui) + XP bar x130-405 y34 h12 |
| 58-94 | Player HP bar (30,58 w375 h36) |
| 96+ | Buff/debuff status row at x430 (RIGHT of AP pips, below HP line) |
| 102 | Energy/AP pips |
| 150 | Secondary resource (Souls/Blood/Prep) |
| 200-226 | PET bar (w280 h26); guard text x322 y214 |
| 244 (200 no-pet) | Trap block, then boons/curses stack below |
