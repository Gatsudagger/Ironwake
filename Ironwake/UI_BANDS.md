# UI_BANDS.md — reserved text/UI y-bands per screen (1920×1080 GUI)

**Rule (M 07-29):** every screen's fixed text lines OWN a y-band. New text
claims a FREE band, or — if it must share — it SUPPRESSES the occupant while
visible (the Vex sacrifice-bar pattern), never draws over it. When you add or
move a band, UPDATE THIS FILE in the same change. Anything placed after
variable-width text must be positioned with `string_width()` measured in the
font it draws with.

Verified bands (file references are approximate anchors, not exact lines):

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
| 888–1000 | (touch) flavor line band — unchanged, sits below the strip |

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

## Sable REBIRTH tab (scr_ui ui_draw_sable_screen)
| Band (y) | Owner |
|---|---|
| 225 | Title + M's flavor line (fit-scaled) |
| 285–495 | 3 craft rows (72px stride, name + tagline only) |
| 531–963 | Detail panel: selected craft's full body + cost list + eligibility |
| 999 | sable_notification (unchanged) |
| 1026 | Key legend (unchanged) |

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
| 90–173 | Loot screen title + "Items collected" header |
| 96–168 | Fortune's Favor chip (x 1560–1870) |
| 240–~1023 | Loot rows (98px stride, 8 visible) |
| 953 | Loot scroll hint (kb only) |
| 990 | "Enter / R to continue" |
| 987–1041 | Vex trainer: sacrifice confirm bar — key legend HIDDEN while it owns the band |

## Shops (Dorn/Petra, scr_ui)
| Band (y) | Owner |
|---|---|
| ~960–1010 | Sell confirm bar + notification ("[SPACE] Confirm …") |
| 1026 | Sell-tab footer key legend — swaps to confirm hint when confirm pending |

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
