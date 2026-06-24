# Vex the Trainer — DESIGN-LOCKED Task Doc

Status: **IMPLEMENTED (2026-06-19).** Currency = Gold (+ items for stats).
Ability gating decision (locked-vs-unlocked): M chose "lock all non-starter (6/class)" —
only each class's default 4-ability loadout stays free; the other 6 cost 500g each.
Side-effects shipped with the build: `trait_active()` now loops the whole `player_traits`
array (fixes Crown of the Hollow King's 3rd slot, which never applied before); the
loadout trait-confirm logic was generalized to N slots via `commit_player_traits()` /
`trait_respec_cost()` / `max_trait_slots()`.
NPC index 3 in `obj_hub_controller`. Already `npc_unlocked[3] = true`; the interaction
handler in `obj_hub_controller/Step_0.gml` (~line 647–667 keyboard, ~730–743 mouse)
currently falls through to `"Coming Soon."` because only Dorn(0)/Petra(4) are wired.

Rarity scale (scr_stats `item_rarity_name`): 0 Common,1 Uncommon,2 Rare,3 Epic,4 Legendary.
"Rare or higher" = `rarity >= 2`.

## Screen
Full-screen overlay like the shops (model on `ui_draw_shop_screen` + gc shop_open pattern).
Add a `trainer_open` flag on obj_game_controller, opened from Vex. Four sections.

## 1. Permanent stat upgrades — Gold + Item
- Cost per +1 to a stat: **200 gold + ONE item of rarity ≥ 2 (Rare+)**, consumed.
- All Rare+ items carry the same trade value (rarity beyond Rare gives no bonus).
- Item source: consume from `global.equipment_stash` / `global.carried_items`.
  Auto-consume the **lowest-rarity, lowest-value** eligible item (player-friendly;
  avoids accidental legendary loss). Show what was consumed.
- Raises `global.perm_str_bonus` … `global.perm_cha_bonus` (already feed the stats system).
- **No cap** (user wants open-ended "continually leveling" value).

## 2. Trait slot expansion — Gold
- Base 2 slots (`global.player_traits = ["",""]`). Add persistent `global.bonus_trait_slots`.
- +1 slot for **800g**, +1 more for **2000g**. Max **4** total. Stacks w/ Crown of the Hollow King.
- Loadout / trait-select screens must read base 2 + bonus_trait_slots (see `_max_traits` in
  obj_hub_controller/Step_0 ~225, and player_traits array sizing in gc Create_0 ~425).

## 3. Ability unlocks — Gold
- Persistent `global.unlocked_abilities` (list of ability names/ids). Unlocked abilities
  become selectable in the class loadout pool.
- **500g** flat per ability. Confirm exact locked-vs-unlocked ability set at build time
  against `global.abilities_arcanist/bloodwarden/shadowstrider` + `abilities_get_loadout`.

## 4. Trait potency via stat SACRIFICE — Option A (permanent stat reduction)
- Each **applicable** trait (one with a numeric magnitude) gets a persistent
  `potency_tier` 0–5 (store as `global.trait_potency` struct keyed by trait name).
- Each tier = **+10%** to that trait's magnitude. **5 sacrificed stat points per tier.**
  Cap **tier 5 (+50%) = 25 points.** (1 tier = 5 pts = +10%, exactly as specified.)
- **Sacrifice = permanent reduction** of the player's banked permanent stat pool
  (`global.perm_*_bonus`; verify leveling/stat model during build). You can only sacrifice
  points you actually have in the associated stat. NOT REFUNDABLE.
- Each applicable trait scales off ONE associated stat (the "5 of INT" example). Proposed
  applicable set + scaling stat (confirm/curate at build):
  - Thick Skin (CON) — +10% max HP base
  - Scavenger (CHA) — +15% gold base
  - Quick Recovery (WIS) — rest heal 25 base
  - Berserker Rage (STR) — +20% dmg below 40% HP (Bloodwarden)
  - Arcane Surge (INT) — Arcanist dmg bonus
  - Serrated Strikes (DEX) — Shadowstrider effect
  - Vampiric Edge (CON or WIS) — heal 2 HP/DoT tick (Bloodwarden)
  - Boolean traits (Sense, Phantom Step, Iron Will, etc.) are NOT upgradable.
- Implementation: replace each applicable trait's hard-coded magnitude at its effect site
  with `base * (1 + 0.10 * potency_tier(trait))`. Add a helper
  `trait_potency_mult(trait_name)` in scr_abilities.

### Confirmation popup (required for any sacrifice)
Before committing a sacrifice show: **"Beware, what you are about to do can not be undone."**
with confirm / cancel.

## Persistence
Update `scr_save.gml` to save/load: `bonus_trait_slots`, `unlocked_abilities`,
`trait_potency`, and ensure `perm_*_bonus` changes persist (they likely already do).

## Files in scope (all .gml — no .yy/.yyp edits)
- `obj_game_controller/Create_0.gml` — new globals + `trainer_open`/cursor state.
- `obj_game_controller/Step_0.gml` — trainer input handling.
- `obj_hub_controller/Step_0.gml` — wire Vex (case 3) to open trainer; trait-slot max reads.
- `obj_hub_controller/Draw_64.gml` — call trainer draw (or put draw in scr_ui).
- `scripts/scr_ui/scr_ui.gml` — `ui_draw_trainer_screen()`.
- `scripts/scr_abilities/scr_abilities.gml` — `trait_potency_mult()`, unlock checks.
- `scripts/scr_combat/scr_combat.gml` + `obj_combat_controller/Step_0.gml` — apply
  potency multiplier at each applicable trait effect site.
- `scripts/scr_save/scr_save.gml` — persist new globals.
