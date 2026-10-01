# Ironwake — Win State / Ending ("IRONWAKE STANDS")

Design locked 2026-07-07 (M picked "Full: gathering + dawn + epilogue" via preview).
Goal declared on the store page: **clear all three dungeons at Awakening V.**

## Trigger
- `end_run(1)` with `current_floor >= 3` and `selected_ascendance >= 5` marks
  `global.dungeon_a5_clears[selected_dungeon] = true` (new saved struct).
- When all three are true and `global.ironwake_stands` is not yet set:
  `ironwake_stands = true`, `ending_pending = true` (both saved). The ending plays on the
  NEXT HUB ARRIVAL — the walk home is the theme. Repeat A5 clears after that change nothing.

## Ending sequence (obj_hub_controller, input-driven; Enter/Space/Esc advances)
1. **Gathering intro** — "The gate stands quiet. The keepers of Ironwake have gathered."
2. **One screen per speaking NPC** (portrait + farewell line). Speakers = affinity tier >= 1
   AND not betrayed; line has two voice bands: tier 1–2 (warm-distant) vs tier 3–4 (intimate).
   Bairc uses his hub portrait sprite if imported (same fallback as the NPC panel).
3. **Absence beat** — only if any NPC carries the new `betrayed` flag:
   "Not every face is here. The town remembers that, too."
4. **Dawn** — warm gradient breaks over the hub: "For the first time in living memory,
   dawn breaks over Ironwake."
5. **Epilogue stats card** — IRONWAKE STANDS + runs taken, full clears, kills, deepest bond,
   companion (name + stage), gold earned lifetime is NOT tracked → omitted.
6. **Credits** — shared `ui_draw_credits_page()` (refactored out of the title screen so both
   call one source).
7. **"The Awakenings continue."** — ending closes, `ending_pending = false`, save_game().
   Endless awakenings exactly as before.

## Betrayal flag
`affinity_betrayal_for()` now stamps `betrayed: true` on each demoted lover's affinity entry
(persists with the affinity struct; absent on old saves → guarded reads treat as false).

## Title screen
Save-slot cards show a small gold "IRONWAKE STANDS" sigil line when that slot's save has the
flag (via get_slot_preview).

## Non-goals (EA)
No new art/music assets; dawn is a draw-time gradient. No dialogue trees — one line per NPC.
Hub dungeon sigils (progress toward the goal) were offered and NOT picked — revisit post-EA.
