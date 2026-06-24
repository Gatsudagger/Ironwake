# SYSTEMS — Loot Rarity Scaling (Awakening-Gated)

**Status: BUILT (verify in-IDE), 2026-06-22. NOT compile-tested.**

Drop rarity now scales with **awakening (ascendance) tier**. Previously every drop
source used a hardcoded rarity-weight array that never changed, so A0 handed out the
same loot as A5 — players got decked out at A0 and cheesed floors. Loot also skewed
uncommon/rare because the high-volume sources (elites, bosses, reliquaries) had little
or no common weight.

---

## 1. `drop_weights(source, asc)` — scr_stats
Returns `[common%, uncommon%, rare%, epic%, legendary%]` for a drop `source`, lerped
between an **A0 baseline** and an **A5 ceiling** by `asc/5` (asc clamped 0..5). The
upper four tiers lerp; **common (index 0) absorbs the rounding remainder** so weights
always sum to 100. Premium sources with no common floor (reliquary) route the leftover
into uncommon instead.

| Source | A0 `[C,U,R,E,L]` | A5 `[C,U,R,E,L]` |
|---|---|---|
| standard  | `[90, 9, 1, 0, 0]`   | `[45, 33, 17, 5, 0]` |
| elite     | `[72, 23, 5, 0, 0]`  | `[22, 38, 28, 10, 2]` |
| boss      | `[33, 42, 21, 3, 1]` | `[6, 28, 38, 22, 6]` |
| chest     | `[80, 17, 3, 0, 0]`  | `[33, 37, 22, 7, 1]` |
| vault     | `[70, 24, 5, 1, 0]`  | `[25, 38, 26, 9, 2]` |
| reliquary | `[0, 60, 32, 7, 1]`  | `[0, 25, 40, 28, 7]` |
| dorn      | `[55, 38, 7, 0, 0]`  | `[10, 35, 35, 18, 2]` |

**A0 intent:** rares ~1–5% off most sources; legendaries only really appear on bosses
and reliquaries (~1%) — "possible but very rare." Reliquary keeps its "uncommon+"
identity (no common floor). By A5 the good gear actually flows.

**Decision:** awakening shifts **rarity tier only** — affix counts stay tied to rarity
exactly as before (Common 0 · Uncommon 1 · Rare 1–2 · Epic 2 · Legendary fixed). No
extra affix scaling.

## 2. Drop call sites (source per faucet)
- `handle_enemy_drops` (scr_stats): standard / elite / boss → `drop_weights(<type>, _drop_asc)`
  where `_drop_asc = global.selected_ascendance` (the current run's awakening).
- `obj_floor_controller/Step_0`: treasure chest → `"chest"`, treasure_vault → `"vault"`,
  treasure_rare (reliquary) → `"reliquary"`, each using `selected_ascendance`.
- Drop *rates/quantities* (4% standard, 28% elite, 100% boss, 40% chest, etc.) are
  **unchanged** — only rarity is gated. (Revisit quantity later if loot still floods.)

## 3. Dorn the Blacksmith — meta-scaled, real gear
`restock_shops` (scr_stats) rebuilt. Dorn now:
- Scales with **`highest_awakening_unlocked()`** (max ascendance unlocked across ALL
  dungeons) — a **permanent** shop upgrade, so Dorn stays good even on an A0 run.
- Stocks **fully-rolled items with affixes** via `drop_equipment(weights, false)` (no
  longer raw un-affixed commons that were strictly worse than any drop). The `false`
  flag skips codex discovery at stock time — items are revealed only when bought
  (`discover_item` on purchase, unchanged).
- Stock **count grows**: 3 items at A0–A1, 4 at A2–A3, 5 at A4–A5.
- Price = `max(1, floor(gold_value * 1.6))`.

## 4. New / changed functions (all scr_stats unless noted)
- NEW `highest_awakening_unlocked()` — max over `global.dungeon_ascendance_unlocked`.
- NEW `drop_weights(source, asc)` — the scaling table above.
- `drop_equipment(rarity_weights, do_discover = true)` — added the `do_discover`
  param; both internal `discover_item` calls (legendary + normal path) are guarded.
- `restock_shops()` — Dorn block rewritten (see §3).
- Call sites: `handle_enemy_drops` (×3), `obj_floor_controller/Step_0` (×3).

## 5. Deferred / future
- Optional drop-*quantity* tuning if players still feel over-geared at low awakening.
- Per-source legendary pity timers.
- Awakening-gated affix quality (explicitly declined this pass).
