# SYSTEMS — Sable the Alchemist

**Status: BUILT (verify in-IDE). Confirmed by M.**
Owner NPC: **Sable the Alchemist** (hub slot **1**). Unlocked from start (testing).
Shares the **rune dust** economy with Maren (see `SYSTEMS_RUNES.md` §8). Sable is the
**primary dust faucet** (salvage) and a dust **sink** (brewing/upgrading consumables).

---

## 1. Overview — three tabs
Tabbed overlay mirroring Maren's pattern (Q/E + click tabs, W/S rows, Enter acts,
Esc back/close): **Salvage · Brew · Upgrade**. State on obj_game_controller:
`sable_open / sable_tab / sable_phase / sable_cursor / sable_notification`.

Currency: **rune dust** (`global.rune_dust`) + **gold** (`global.gold`).

---

## 2. Salvage — the dust faucet (gear + runes → dust)
Operates on **unequipped** gear (`global.carried_items` + `global.equipment_stash`)
and **unsocketed** runes (`global.rune_inventory`). Never touches equipped gear
(`global.inventory`) or socketed runes.

- **Gear by rarity:** Common 1 · Uncommon 2 · Rare 5 · Epic 10 · Legendary 20 dust.
- **Runes by tier (fully scrapped, NO rune returned):** I 6 · II 16 · III 40 dust.

**Distinct from Maren's Split:** Split *downgrades* a rune to reclaim a lower-tier rune
+ a little dust (stays in the rune economy). Sable Salvage *destroys* a rune for max
dust — the intended fix for off-class aspect runes piling up (e.g. Bloodwarden-only
runes on an Arcanist run).

**No-exploit tuning:** combine→salvage never net-profits dust. 3×T1 salvage = 18 dust;
combining them (−10 dust) then salvaging the T2 (16) nets +6 < 18. 3×T2 salvage = 48;
combine (−30) then salvage T3 (40) nets +10 < 48.

Salvage tab is phased: phase 0 = choose **Gear** or **Runes**; phase 1 = gear list;
phase 2 = rune list. Each row shows the dust it yields; Enter salvages immediately.

---

## 3. Brew — alchemy-exclusive potions (dust + gold)
Sable-only consumables, pushed into `global.consumable_inventory` (respects the
**4-slot cap** — brew is blocked when full). Four reuse existing combat effect types;
**Aegis Draught introduces a new `shield` effect** (combat handler: `player.shield_hp
+= value`).

| Potion | effect_type / value | Cost |
|---|---|---|
| Aegis Draught | `shield` 30 (→ player.shield_hp) | 25 dust + 30g |
| Master Healing Draught | `heal` 90 | 30 dust + 40g |
| Phoenix Tonic | `heal_dot` 15 (4 turns) | 35 dust + 40g |
| Cleansing Philter | `cleanse_all` | 20 dust + 25g |
| Ley Battery | `energy` 3 (full) | 30 dust + 35g |

Catalog: `sable_brew_catalog()` in scr_stats (each entry carries the create_consumable
args + dust/gold cost). `sable_brew(id)` checks dust+gold+slot cap, then crafts.

---

## 4. Upgrade — fuse consumables
**3× identical standard potion → its elite upgrade** for **10 dust + 20g**.

| 3× standard | → elite |
|---|---|
| Healing Salve | Greater Healing Salve |
| Energy Tonic | Adrenaline Vial |
| Antidote | Purification Draught |
| Smelling Salts | Purification Draught |

`sable_upgrade_groups()` lists standard consumables held 3+ times that have an upgrade
mapping; `sable_upgrade(name)` consumes 3 and adds the elite version (respects slot cap
— net −2 slots, so always fits).

---

## 5. Integration points
- **scr_stats** — salvage rate helpers, `sable_salvageable_gear()`, `sable_salvage_gear`,
  `sable_salvage_rune`, `sable_brew_catalog`, `sable_brew`, `sable_upgrade_map`,
  `sable_upgrade_groups`, `sable_upgrade`.
- **obj_combat_controller Step_0** — new `shield` consumable effect handler.
- **scr_ui** — `ui_draw_sable_screen()` (full-screen overlay) + `ui_input_blocked` guard.
- **obj_game_controller Create/Step** — Sable UI state + input block.
- **obj_hub_controller Create/Step/Draw_64** — unlock slot 1, blurb, interact (kb+mouse),
  draw call.
- **Save/load** — nothing new: dust, consumables, carried_items, equipment_stash already
  persist.

---

## 6. Deferred / out of scope (v1)
- Brewing from the new potions into even higher tiers (only standard→elite for now).
- Reagent types beyond rune dust (single shared currency by design).
- Sable's own cosmetic/flavor art; gating (unlocked from start for testing — confirm later).
