# Vex Rework — Abilities = gold, Traits = gold + item — IMPLEMENTED (2026-06-20)

## Implementation notes / deviations
- **Abilities tab now windows to 8 rows too.** Making every ability gold-only grew the
  purchasable list (Arcanist ~11), which overflowed the old non-scrolling Abilities tab.
  Both Abilities (tab 2) and Traits (tab 3) use `loadout_list_scroll(cursor,n,8)` in the
  draw AND a scroll-aware mouse hit-test (`_tr_hscroll`) so clicks map to the right index.
- **Goal/milestone ability machinery retained but dead:** `goal_met` + the `goal` branch
  in `ability_is_unlocked` stay for future milestone-free abilities; no ability uses them.
- `trainer_find_rare_item/has/consume` kept as `min_rarity=2` wrappers → Stats tab untouched.
- Trait purchase writes `traits_unlocked[effect_id]=true`; all effect_ids already exist as
  keys (+ Create backfill), so `variable_struct_set` is safe.
- Class traits show in the Traits tab only for the matching class; universals always show.
- NOT compile-tested in-IDE (can't run GMS2 here).

---

# Vex Rework — Abilities = gold, Traits = gold + item — DESIGN-LOCKED (M approved 2026-06-20)

Fixes the misread that Vex "trains abilities the class already has." Classes already
have separate ability pools (no cross-class learning) — but per M, Vex should also be
the **trait** trainer, abilities should be **cheaper & gold-only**, and traits should
cost **gold + a rarity-matched item** instead of unlocking free at milestones.

## M decisions
1. **Vex = full 5-tab trainer:** `Stats | Trait Slots | Abilities | Traits | Potency`.
2. **Abilities → gold only**, re-tiered **100 / 250 / 400g** (was 500/800/1200). The 6
   progression-goal abilities become normal Vex purchases. The "goal/milestone-free"
   unlock machinery is **retained but unused** — reserved for *future* abilities that
   unlock free at a milestone (M: "we can add abilities that only unlock from milestones
   and are free later").
3. **Traits → bought at Vex**, **no gate** (every non-default, class-appropriate trait is
   available from the start). **All milestone auto-unlocks for traits are removed.**
   Price tiered by required trade-item rarity:
   - **Tier 1 — 200g + an Uncommon+ item**
   - **Tier 2 — 350g + a Rare+ item**
   - **Tier 3 — 500g + a Legendary item**
4. The 3 **default** traits (Sense, Scavenger, Thick Skin) stay free from the start.

---

## 1. Ability re-pricing (`scr_abilities.gml` → `ability_unlock_info`)
All non-starter abilities become `type:"vex"`. New tiers map 1:1 from old:
- **100g** (was 500): Soul Harvest, Curse, Soul Shield, Mana Sever, Bloodthorn Aura,
  Plague Touch, Sanguine Pact, Smoke Bomb, Crippling Shot, Marked for Death, Second Wind.
- **250g** (was 800 + the lvl-6 goal trio): Entropy, Marrow Crush, Vital Theft, Spike Trap,
  Evasive Roll, Flurry, Adrenaline Rush, **Arcane Echo, Bonebreaker, Vanish**.
- **400g** (was 1200 + the boss-kill goal trio): Rift, Soulbind, Undying, Bloodfeast,
  Death Snare, **Singularity, Crimson Apex, Killing Spree**.

`ability_is_unlocked` / `goal_met` keep their `goal` branch (dead for now, future-proof).
`class_vex_purchasable` already lists every vex-type locked ability — now that's all of
them, so the Abilities tab needs no structural change beyond the new prices.

## 2. Trait unlock data + helpers (`scr_abilities.gml`)
New: `trait_get_by_name(name)`, `trait_is_default(t)` (= `unlock_type=="default"`),
`trait_is_unlocked(name)` (looks up `effect_id` in `global.traits_unlocked`),
`trait_unlock_tier(name)`→1/2/3, `trait_unlock_cost(name)`→`{gold, min_rarity, item_label}`,
and `trait_vex_purchasable(class_id)` (not-default, `class_req==-1 || ==class_id`, not yet
unlocked — **no milestone check**).

**Tier assignment (table):**

| Tier (gold + item) | Traits |
|---|---|
| **T1 — 200g + Uncommon+** | Quick Recovery, Treasure Hunter, Lucky Find, Salvager, Prospector |
| **T2 — 350g + Rare+** | Battle Hardened, Iron Will, Expanded Arsenal, Last Stand, Soul Siphon, Ley Tap, Crimson Reserve, Vampiric Edge, Phantom Step, Shadow Meld |
| **T3 — 500g + Legendary** | Focused Power, Chain Caster, Plaguebearer, Arcane Surge, Berserker Rage, Serrated Strikes |

Rarity scale: 0 common, 1 uncommon, 2 rare, 3 epic, 4 legendary.
`min_rarity`: T1=1, T2=2, T3=4 (Legendary specifically).

## 3. Generalized trade-item helpers (`scr_stats.gml`)
Extend `trainer_find_rare_item` → `trainer_find_item(min_rarity)` (lowest-rarity,
lowest-value match ≥ min_rarity, across stash + carried pack). Add `trainer_has_item(min)`
/ `trainer_consume_item(min)`. Keep `trainer_*_rare_item()` as `min_rarity=2` wrappers so
the Stats tab is untouched.

## 4. REMOVE all trait milestone auto-unlocks
Delete the `global.traits_unlocked.X = true` milestone blocks (and their trait_notif
toasts), keeping surrounding counters/logic:
- `scr_stats.gml` `grant_xp`: **salvager** (lvl 5), **chain_caster** (lvl 8). *(Keep the
  highest_run_level ratchet and the level-up logic.)*
- `scr_stats.gml` full-clear hook (~ln 218): **lucky_find**.
- `scr_stats.gml` `end_run` dungeon-clears section (~ln 374–406): **quick_recovery,
  prospector, treasure_hunter, battle_hardened, expanded_arsenal, iron_will,
  plaguebearer**. *(Keep `dungeon_clears_total++` and the rest of end_run.)*
- `obj_combat_controller/Step_0.gml` boss-kill block (~ln 75–117): **soul_siphon,
  crimson_reserve, phantom_step, ley_tap, vampiric_edge, shadow_meld, last_stand,
  arcane_surge, berserker_rage, serrated_strikes, focused_power**. *(Keep
  `total_boss_kills++`, the Battle-Hardened perm-HP grant, level-alloc, and loot flow.)*

After this, `global.traits_unlocked.*` flips **only** via a Vex Traits-tab purchase.
`traits_unlocked` defaults (gc Create) and the save/load are already generic — no change.

## 5. Trainer input — 4 tabs → 5 (`obj_game_controller/Step_0.gml`)
- `trainer_tab` range 0–4: every `mod 4`→`mod 5`, tab-click loop `_tbi < 4`→`< 5`.
- `_tr_rows`: **tab 3 = Traits** = `array_length(trait_vex_purchasable(_tr_class))`;
  **tab 4 = Potency** = `array_length(trait_upgradable_list())` (moved from tab 3).
- **New TAB 3 purchase logic:** pick `trait_vex_purchasable(_tr_class)[cursor]`, read
  `trait_unlock_cost`, require `global.gold >= gold` AND `trainer_has_item(min_rarity)`;
  on buy: deduct gold, `trainer_consume_item(min_rarity)`, set the trait's `effect_id`
  true in `traits_unlocked`, `save_game()`, notify "Unlocked <trait>! (traded: <item>)".
- Potency logic moves from the `trainer_tab == 3` branch to `trainer_tab == 4`.

## 6. Trainer draw (`scr_ui.gml` → `ui_draw_trainer_screen`)
- `tab_names = ["Stats","Trait Slots","Abilities","Traits","Potency"]`.
- Tab bar re-fit for 5 tabs (≤1280px): `tab_w≈230, x = 45 + i*240`.
- New **Traits** tab render: one row per `trait_vex_purchasable` entry — name, one-line
  effect, and `"<gold>g + <Uncommon/Rare/Legendary> item"`; grey/"Owned" when unlocked,
  red when unaffordable / no qualifying item. Mirrors the Abilities tab styling.
- Re-point the Potency draw to tab index 4.

## 7. Out of scope / unchanged
Per-class ability pools (already separate), loadout screen, combat AoE/status systems,
`scr_save` (generic). Class-trait *gameplay* effects unchanged — only how they unlock.

## Open / confirm before build
- Tier table in §2 — adjust any trait's tier if you disagree (e.g. move a class trait).
- Tab order `Stats | Trait Slots | Abilities | Traits | Potency` (Traits before Potency,
  per your preview).
