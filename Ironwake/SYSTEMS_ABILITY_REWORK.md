# SYSTEMS — §3 Ability Rework (setup→payoff combos)

Design-locked 2026-06-23. Fixes MISC_TASKS §3 "Major ability rework — redundancy problem"
(the Arcanist/Strider single-combo loop). Built; **not yet compile-tested in IDE.**

## Problem diagnosed
- Abilities are **once per turn** (`abilities_used_this_turn`), so a turn = pressing 3–4
  *different* cheap abilities; the loop is **across turns** (same buttons, same order, forever).
- **Inverted AP curve**: three 1-AP abilities out-damage AND out-utility any single 3-AP nuke,
  so the expensive abilities were dead weight (e.g. Arcane Burst 28 < Soulfire + a 2-AP spell).
- **Shadowstrider** worst offender: 3× 1-AP options (Snipe + Poison Dart + dodge) → identical
  every turn. **Arcanist** had only one cheap damage spell (Soulfire) + dominated nukes.
- Almost nothing was **state-dependent**, so the optimal turn never changed.

## Fix = three coordinated levers
1. **Fix the AP curve** — buffed the single-target nukes so a committed 3-AP cast beats a turn
   of cheap casts *when set up*.
2. **Setup→payoff combos** — cheap **primers** apply **Exposed** (a `vulnerable` debuff);
   **payoffs** hit harder vs an Exposed/debuffed target or when a resource is banked.
3. **New damage abilities** with distinct triggers (Expose / soul-dump / bleed-detonate /
   execute) so loadout choice and turn sequencing matter.

"Exposed" reuses the existing `vulnerable` status (already adds flat damage per hit), so the
primers need **no new combat code** — just `effect_type:"debuff"`.

## Changes — abilities (scr_abilities.gml)
Rebalances (field changes):
- **Arcane Burst** base 28 → **38** (+ rider: +40% vs Exposed/debuffed).
- **Marrow Crush** base 18 → **24**.
- **Flurry** unchanged base, + rider: +3 per debuff on target.

New abilities (pushed at class indices 13–14; earlier index literals unaffected):

| Class | Idx | Name | Gate | AP | Dmg | Role / rider |
|---|---|---|---|---|---|---|
| Arcanist | 13 | **Scorch** | FREE | 1 | 8 elem | Primer — applies Exposed (+3/hit, 2t) |
| Arcanist | 14 | **Soul Nova** | Vex 250g | 2 | 8 elem | Dump — consumes ≤4 Souls, +7 dmg each |
| Bloodwarden | 13 | **Cleave** | FREE | 1 | 11 phys | Reliable 1-AP filler (BW lacked one) |
| Bloodwarden | 14 | **Rupture** | Vex 400g | 2 | 8 blood | Detonate bleeds: +5 per remaining DoT tick, clears them |
| Shadowstrider | 13 | **Throat Slit** | FREE | 1 | 5 phys | Primer — applies Exposed (+4/hit, 2t) |
| Shadowstrider | 14 | **Assassinate** | Vex 400g | 3 | 24 phys | Execute — DOUBLE dmg if target <30% HP (−2 Prep) |

One **free** primer/filler per class (selectable from the start); the payoffs are Vex-purchased
(auto-listed by `class_vex_purchasable`). Free = no `ability_unlock_info` entry.

Also updated in scr_abilities.gml:
- `ability_attack_class` melee set += Cleave, Rupture, Throat Slit, Assassinate.
  Scorch/Soul Nova are elemental → ranged_spell automatically.
- `ability_effect_full` + `ability_summary` bespoke clauses for all riders (auto-generated text).

## Changes — combat (obj_combat_controller/Step_0.gml)
Combo riders in the pre-crit damage block (next to the Snipe/Arcane Echo hooks):
- `_tgt_exposed` shared test (vulnerable/weaken/dot/blind/mortality/silence).
- Arcane Burst ×1.4 if Exposed; Flurry +3/debuff; Soul Nova +7×min(souls,4) **and consumes
  them** (single-target, on hit only — a miss wastes no Souls); Assassinate ×2 if target <30% HP;
  Rupture sums DoT durations → +5/tick and clears the DoT statuses.

## Side-fix (required, flagged): dead `"resource"` effect type
ROADMAP flagged that `effect_type:"resource"` was never read — **Soulfire's "+2 Souls" and Soul
Harvest's never actually fired**; the Arcanist soul economy barely worked, which *forced*
Soulfire-spam. Revived the data path generically:
- On-hit path (near the Void Drain/Blood Leech hooks) + self-targeted path (self branch) now grant
  `effect_value` of the caster's secondary resource for any `effect_type:"resource"` ability.
- Fixes Soulfire (+2 Souls) and Soul Harvest; makes the new soul-dumps (Soul Nova / Arcane Burst /
  Singularity) actually fuel-able. **This is the change to call out for playtest.**

## Verify in IDE
- [ ] Project compiles.
- [ ] Soulfire now logs "+2 Souls" and the Soul bar climbs; Soul Nova/Arcane Burst become castable.
- [ ] Scorch / Throat Slit deal damage AND apply Exposed (status row shows it); follow-up hits do +N.
- [ ] Arcane Burst logs "+40%" only vs an Exposed/debuffed target.
- [ ] Rupture consumes bleeds (Gore Strike → Rupture) and spikes damage; does nothing with no DoTs.
- [ ] Assassinate doubles below 30% HP.
- [ ] Free primers slot without a Vex purchase; Soul Nova/Rupture/Assassinate appear in Vex shop.
