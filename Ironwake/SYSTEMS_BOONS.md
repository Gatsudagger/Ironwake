# SYSTEMS — Boons (Tribute / Shrine rooms)

**Status: BUILT (verify in-IDE). Confirmed by M.**
Roguelite run-variety layer (ROADMAP §3). Boons are **run-scoped** modifiers bought
with **tribute** (gold / rune dust / sacrificed item) at **Shrine rooms** in the dungeon.
Built after the Enemy Difficulty Pass so boons are a counterweight, not power creep.

---

## 1. Model
- `global.run_boons` = active boon ids. **Reset every run** in `end_run` (boons vanish on
  win/loss/extract). Init in gc Create; persisted in save/load for mid-run continues.
- `boon_catalog()` (scr_stats): `{id, name, desc, cost, value}` — cost is in tribute points.
- Query: `boon_active(id)` / `boon_value(id)`. Aggregate helpers `boon_damage_mult`,
  `boon_incoming_mult`, `boon_maxhp_mult`.

### Catalog (v1, 10 boons)
| id | effect | cost |
|---|---|---|
| bloodlust | +15% damage dealt | 120 |
| ironhide | +20% max HP | 120 |
| duelist | +10% crit chance | 120 |
| vampirism | heal 5 HP per kill | 140 |
| warding | take 12% less damage | 140 |
| greed | +50% gold from kills | 80 |
| runic | +50% rune dust from kills | 80 |
| executioner | +25% damage vs enemies <30% HP | 140 |
| aegis | start each combat with a 15 shield | 120 |
| glasscannon | +30% damage, −15% max HP | 160 |

---

## 2. Tribute
Each boon costs `cost` tribute points, payable by **one** method:
- **Gold:** `cost` gold (1 pt = 1 g).
- **Dust:** `ceil(cost / 3)` (dust worth 3 pts each).
- **Item:** sacrifice the *lowest-value unequipped* item whose worth ≥ cost
  (`item_tribute_value` by rarity: 20 / 40 / 80 / 140 / 240). Auto-picked — no item-picker
  UI. Pulls from `carried_items` + `equipment_stash`.

`boon_pay(id, method)` validates + spends + grants; "" on success else a reason.

---

## 3. Shrine rooms
- New room type **`shrine`** added to all three floor pools (`_type_pools`), with name pool
  + node color (gold) + label "SHRINE" + Sense "TRIBUTE" + detail "Shrine of Tribute".
  `_enemies = "none"`.
- Entering rolls `boon_offer_roll()` (up to 3 distinct unowned boons) → `showing_shrine`.
- **Interactive overlay** (floor controller, like treasure/event but with input): W/S select,
  `1` gold / `2` dust / `3` item, Esc leave. Shows each boon's three payment costs with
  affordability colors + your gold/dust. One boon per shrine; buying or leaving **clears**
  the room (no farming).

---

## 4. Effect hook points
- **Damage** (bloodlust/glasscannon/executioner): `boon_damage_mult(target_hp_frac)` ×`_final_dmg`
  in combat Step (after aspect runes).
- **Crit** (duelist): `+ boon_value("duelist")` in the player `combat_roll_crit` call.
- **Max HP** (ironhide/glasscannon): `boon_maxhp_mult()` in combat Create (after equip bonus).
- **Incoming** (warding): `boon_incoming_mult()` in `combat_mitigate_player` + the two inline
  enemy-attack chains.
- **On-kill** (vampirism heal, greed gold): `combat_on_enemy_defeated`.
- **Dust** (runic): `handle_enemy_drops`.
- **Start shield** (aegis): `combat_apply_start_traits`.

---

## 5. Active-boon display (BUILT — verify in-IDE)
Boons are run-scoped (no per-turn duration), so the display is a **static legend**, not a
ticking buff icon. One shared data source: `ui_boon_style(id)` (scr_ui) maps each boon id →
`{abbr, col}` (short code + badge color); falls back to a neutral "BOON" badge for unknown ids.
- **Combat HUD:** `ui_draw_active_boons(x, y)` (scr_ui) draws a vertical "BOONS" strip of
  colored abbr-badges + boon names. Called from `ui_draw_combat_hud` at `(20, 185)` — left
  column, below the per-combat buff icon row (y≈148–171), above the combat log (y=490) and
  clear of the player sprite (x≥220). No-op when `global.run_boons` is empty.
- **Character menu (Stats tab):** right column, "── Active Boons ──" at `_content_y+460`
  listing `• name — desc`, capped at 6 rows with "+N more…" to avoid overflow; "None this
  run" when empty.
Reads `global.run_boons` + `boon_get(id)` — no new state, draw-only.

## 6. Deferred / future
- Boon rarities / weighted offers; higher-tier boons at deeper floors.
- Curses (opt-in downside for stronger boons) — the original §3 Phase 3.
- Event rooms (narrative choices) — original §3 Phase 2.
- Item-tribute picker (choose which item) instead of auto lowest-value.
