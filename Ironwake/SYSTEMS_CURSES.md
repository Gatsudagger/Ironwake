# SYSTEMS — Curses ("Devil's Bargain")

ROADMAP §3 (opt-in difficulty for better loot) + §6 (higher risk / higher reward at
higher awakenings). Curses are the **inverse of boons** ([SYSTEMS_BOONS.md] / `boon_*`):
a boon costs *tribute* for a *benefit*; a curse costs *nothing up front* — you accept a
**run-long penalty** in exchange for a **run-long reward boost** (better loot + more
gold/dust). The price is the difficulty.

**Design-locked 2026-06-24** (M approved all three forks):
- **Placement:** Shrine altars. Each Shrine room rolls as EITHER a *Blessing* altar
  (boons, existing) OR a *Curse* altar (accept a curse for power). Reuses the shrine
  room + overlay plumbing; makes shrines more varied.
- **Reward:** run-long boost (loot-tier + gold/dust multipliers), applied for the rest
  of the run. Late curses still matter.
- **Stacking:** free — take as many as you dare; penalties and rewards both stack.
- Once accepted a curse is **locked for the run** (no removal). Reset every run.

---

## Core (parallels `run_boons`)

`global.run_curses` = array of active curse ids. Reset in `end_run`, init in
`obj_game_controller/Create`, saved/loaded guarded — identical plumbing to `run_boons`.

`curse_catalog()` — 10 curses, tiered & awakening-gated like the Aesthete skins:

| id | name | tier | penalty | reward | loot | gold | dust |
|----|------|------|---------|--------|------|------|------|
| `frail`      | Frail        | 1 | −20% max HP                          | +40% gold found            | 0 | .40 | .00 |
| `famine`     | Famine       | 1 | No consumable drops this run         | +60% rune dust             | 0 | .00 | .60 |
| `exposed`    | Exposed      | 1 | Take +15% damage                     | Loot rarity +1 tier        | 1 | .00 | .00 |
| `bloodprice` | Blood Price  | 2 | Lose 4 HP at the start of each turn  | +50% gold & dust           | 0 | .50 | .50 |
| `savagery`   | Savagery     | 2 | Enemies deal +20% damage             | Loot +1 tier, +25% gold    | 1 | .25 | .00 |
| `withered`   | Withered     | 2 | −50% healing received                | Loot rarity +1 tier        | 1 | .00 | .00 |
| `doom`       | Doom         | 3 | Enemies have +25% HP & +15% damage   | Loot rarity +2 tiers       | 2 | .00 | .00 |
| `damnation`  | Damnation    | 3 | Start each combat at 65% HP          | Loot +2 tiers, +40% gold   | 2 | .40 | .00 |
| `ruin`       | Ruin         | 3 | −30% max HP & +10% damage taken      | Loot +2 tiers, +50% dust   | 2 | .00 | .50 |
| `devilspact` | Devil's Pact | 3 | Enemies +20% damage; you −15% max HP | Loot +2 tiers; **bonus equip drop from every elite & boss** | 2 | .00 | .00 |

**Tier gating** (`curse_tier_available(tier)`): t1 always; t2 needs
`highest_awakening_unlocked() >= 2`; t3 needs `>= 4`. (Same gate idiom as skins.)

**The "better loot" lever:** `curse_loot_asc_bonus()` sums the `loot` field of every
active curse and is ADDED to the awakening `asc` fed into `drop_weights(source, asc)`.
`drop_weights` already lerps A0→A5 toward better rarity and clamps 0..5, so "+N tiers"
shifts the rarity table upward — and **compounds at higher awakening** (high base asc +
bonus pushes toward the A5 ceiling = §6).

Gold/dust rewards (`curse_gold_mult()` / `curse_dust_mult()`, additive like Greed/Runic).

## Helpers (scr_stats, after the boon block)

`curse_get/active/grant/accept`, `curse_tier_available`, `curse_offer_roll` (≤3 unowned,
tier-available, Fisher-Yates), `curse_maxhp_mult`, `curse_incoming_mult`,
`curse_enemy_hp_mult`, `curse_enemy_damage_mult`, `curse_loot_asc_bonus`,
`curse_gold_mult`, `curse_dust_mult`, `curse_blocks_consumables`, `curse_heal_mult`
(Withered), `curse_combat_start_hp_frac` (Damnation), `curse_turn_hp_drain` (Blood
Price), `curse_has_bonus_drops` (Devil's Pact).

## Effect hooks (nearly all parallel existing boon hooks)

- **max HP** — `obj_combat_controller/Create` ~206, alongside `boon_maxhp_mult()`.
- **incoming dmg** — `combat_mitigate_player` (scr_combat ~534) + inline basic/double
  strike chains (`obj_combat_controller/Step` ~1424/1512), alongside `boon_incoming_mult()`.
- **enemy HP & dmg** — `obj_combat_controller/Create`, a dedicated curse loop right
  after the difficulty pass (~485).
- **gold from kills** — `combat_on_enemy_defeated` (scr_combat ~643), alongside Greed.
- **rune dust** — `handle_enemy_drops` (scr_stats ~1045), alongside Runic.
- **consumable block** — `handle_enemy_drops` consumable rolls (~1058/1077/1100).
- **loot asc bonus** — every `drop_weights` call site that uses the run awakening
  (scr_stats ~1024 & ~2504; floor chest/vault/reliquary ~265/313/331). Shop (Dorn) is
  HUB-side and unaffected (run_curses is empty between runs).
- **Withered heal** — `combat_heal_after_mortality` (scr_combat ~514): every heal routes
  through it, so multiply by `curse_heal_mult()` there.
- **Blood Price drain** — the single `need_player_status_tick` block
  (`obj_combat_controller/Step` ~173), right after `combat_tick_statuses`, before the
  defeat check (so the drain can kill / trigger last stand).
- **Damnation start HP** — `obj_combat_controller/Create` after start traits (~267):
  `player.HP = min(player.HP, ceil(player.max_HP * curse_combat_start_hp_frac()))`.
- **Devil's Pact bonus drop** — extra `drop_equipment` in the elite & boss branches of
  `handle_enemy_drops` when `curse_has_bonus_drops()`.

## Shrine integration (obj_floor_controller)

- Create: new `shrine_kind = "blessing"`.
- Step entry (`type=="shrine"`): coin-flip `shrine_kind`; roll the matching offers
  (`boon_offer_roll` / `curse_offer_roll`) into `shrine_offers`. If the chosen kind has
  0 offers, fall back to the other kind.
- Step interactive: branch on `shrine_kind`. Curse altar = W/S select, **Enter/Space
  accept** (no payment — `curse_accept`), Esc leave. (Blessing = existing 1/2/3 tribute.)
- Draw (`6b`): branch on `shrine_kind` — curse altar shows red theming, each row's
  penalty + reward, and an "[Enter] Embrace the curse · Esc: Leave" hint.

## UI display

`ui_curse_style(id)` + `ui_draw_active_curses(x,y)` (scr_ui) mirror the boon strip;
shown in the combat HUD (below the boon strip) and the character-menu Stats tab.

## Tunable
All curse numbers (`loot`/`gold`/`dust` + penalty magnitudes), tier gates, and the
shrine blessing/curse coin-flip weight are tunable. Builds on [SYSTEMS_BOONS.md].
