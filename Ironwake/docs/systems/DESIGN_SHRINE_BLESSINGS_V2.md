# DESIGN — Shrine Blessings V2 (draft for M review, 2026-07-29)

**Status: BUILT 07-29 (same session, M's order), awaiting F5. Build notes: blessing
"Bloodprice" shipped as "Blood Tithe" (a curse named "Blood Price" already exists -
flagged); Silvered Tongue = the extra event choice only (check odds were ALREADY
shown to everyone baseline, so the boon's odds half was redundant); reroll is
arm-then-confirm per the destructive-one-click rule; flavor line rides the empty
notification slot (rows too dense for a 4th line at measured font sizes).**

## Problem (M, 07-29)
- Blessings are generic ("+gold gained", flat % stats) — "you're basically praying for a
  cursed shrine every time."
- VERY expensive at A0–A2 (flat 80–160g while early-run gold is scarce); ROI only lands
  at high tiers.
- Nothing at a shrine feels like a *moment* or a build-around.

Current state (scr_stats `boon_catalog()`): 10 boons, flat costs, all passive stat
multipliers. Tribute methods (gold / dust ×3 / item by rarity) are fine and stay.

## Goals
1. Every blessing changes HOW a run plays, not just a number.
2. Costs scale with Awakening so A0–A2 shrines are a real choice.
3. Keep the existing tribute plumbing (`boon_pay`, dust/item routes) untouched.
4. Cheap to build: each blessing rides an EXISTING combat hook (splash, execute,
   detonate, shield, AP economy, first-cast flags) — no new systems.

## §1 Cost curve (replaces flat costs)
`boon_cost(base, asc) = round(base * [0.40, 0.55, 0.70, 0.85, 1.00, 1.15][asc])`
- A0: a 120g boon costs 48g. A5: 138g. Dust/item tribute derive from the scaled cost
  as today (dust worth 3/pt — this also makes dust *matter* early, per M's dust note).

## §2 Blessing catalog v2 (proposed — M edits freely)
Keep 4 of the old 10 as the "plain" pool: Vampirism, Aegis, Glass Cannon, Executioner
(they already have identity). Retire the rest. Add 8 CREATIVE blessings:

| Blessing | Effect | Base cost | Implementation hook |
|---|---|---|---|
| Pyre's Favor | Enemies you kill DETONATE their statuses on death | 130 | `combat_detonate_statuses` at `combat_on_enemy_defeated` |
| Second Skin | The first hit you take each combat is halved | 110 | Evasive-Roll idiom, per-combat flag |
| Gambler's Icon | Win a combat in ≤3 turns → its loot rolls +1 rarity tier. **M-LOCKED: all combat types, but with an internal cooldown — after a proc the next 2 fights are ineligible (proc → cooldown → cooldown → eligible), so it can't chain with cursed-shrine loot bumps every room** | 140 | `combat_state.round` check at loot roll + a run-scoped fights-since-proc counter |
| Whetstone Echo | Your FIRST ability each combat echoes at 40% power | 150 | first-cast flag + echo-damage idiom (Arcane Echo/splash path) |
| Bloodprice | Bank 1 gold per HP you lose; paid out on extraction | 90 | increment at `combat_apply_damage(player)`, pay at extract |
| Third Wind | Every 3rd ability you cast in a combat costs 1 less AP | 130 | per-combat cast counter + `ability_effective_cost` hook |
| Carrion Crown | **M-LOCKED "Feast of Crows":** each enemy that dies in a combat adds a crown stack — +8% damage and +2 flat armor per corpse, until the fight ends. Packs melt from the back; single-foe boss rooms get nothing (built-in trade-off). | 120 | per-combat stack counter incremented in `combat_on_enemy_defeated`; damage/armor reads at the boon mult sites |
| Silvered Tongue | Event rooms reveal their stat-gated option's odds & one extra choice | 100 | events already have `resolve` metadata; display + extra row |

Shrine OFFER: roll 3 — 2 creative + 1 plain — plus the reroll (M-LOCKED 07-29):
**pay (10 + 10×awakening) dust — A0 10 → A5 60 — to reroll the offer, once per
shrine** (dust sink that scales with the dust economy, M's undertuned-dust note).

## §3 Presentation (small, same-task)
- Blessing rows show a one-line *flavor* under the mechanic (the curse altar already
  feels better partly because of tone).
- On purchase: `ui_checkout_vfx` burst + a named log line ("The altar accepts. PYRE'S
  FAVOR settles over you.") — the moment should land like a legendary drop.

## §4 Out of scope (parked)
- Dungeon-specific shrine gods / per-dungeon pools (post-launch flavor pass).
- Blessing upgrades / stacking tiers.

## §5 Walkthrough decisions (M, 07-29 — ALL LOCKED)
- All 8 creative blessings in, Carrion Crown as "Feast of Crows" (see table).
- **ALL 10 old boons stay, each with its one-line rework (M approved all 6):**
  - Bloodlust: +15% damage, rising to +25% while below half HP.
  - Ironhide: +20% max HP and +2 flat armor.
  - Duelist: +10% crit, and your crits restore 1 class resource (crit_sec rider).
  - Warding: 12% less damage, and hostile DoTs tick 1 turn shorter on you.
  - Greed: +50% gold from kills, plus elite/boss kills drop a bonus purse (+75g).
  - Runic Affinity: +50% dust, and runes you socket this run act 1 tier higher (cap V).
  - (Vampirism, Aegis, Glass Cannon, Executioner unchanged — already have identity.)
- Reroll: (10 + 10×awakening) dust, once per shrine.
- Gambler's Icon: all combat types, 2-fight internal cooldown after each proc.
- Offer roll stays 2 creative + 1 (reworked) plain.
