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

*Started 07-29 from verified reads; extend as screens are touched. Unlisted
screens are NOT collision-free — they're unaudited.*
