# SYSTEMS — SUMMONS (08-13, M-locked; enemy side committed db577e6, player side ada611d)

Two independent systems share the word "summon".

## 1. ENEMY SUMMONS (mid-fight reinforcements)
Cast via an `enemy_ability(kind:"summon")` entry (e.g. Pale Archivist's
"Requisition"). Resolution lives in obj_combat_controller Step (~line 4961).

- Candidate pool = the current dungeon's **standard pool** (Descent fights use
  the ashen/default pools per the dungeon switch). Candidates **exclude the
  caster's own name AND any summoner template** — no self-copies, no chains.
- The newcomer arrives **winded at 60% HP** (Awakening-scaled), fully stamped
  with transient fields (hit_flash/recoil/dodge_anim/denied_streak) + a rolled
  intent, and **joins the END of the turn order**.
- **Field cap 4** living enemies — `enemy_pick_ability` never readies a summon
  onto a full field, and the Step re-checks (AoE-kill edge cases).
- **A5 BOSS ESCALATION**: in a boss fight at Awakening 5 (incl. Depth Wardens
  with the call), the pick comes from the **elite pool** captured at Create
  (`summon_pool_elite` + `summon_is_boss_fight`), with an "an ELITE answers"
  log + bigger shake.
- Stage placement (2.5D): the newcomer's station walks to the first spot no
  living enemy holds (round 13d — clash = <60px x AND <40px feet).

## 2. PLAYER SUMMONS (Arcanist kit, ada611d)
Three abilities, pool indices 10-12; bought at Vex; ONE standing summon at a
time on `player.summon {name, kind, turns, power, hits}` — casting replaces the
old one (logged). **Cooldown stamps at SUMMON time.**

| Summon | Cost | CD | Vex | Standing | Detonate |
|---|---|---|---|---|---|
| Magma Golem | 2 AP + 1 Soul | 4 | 400g | intercepts 1 hit | power(22) − fire resist AoE to all; 10 self-damage + 6 to pet |
| Warding Effigy | 2 AP | 3 | 250g | intercepts 2 hits | 8 AoE + Vulnerable(2) for 2t on all |
| Static Husk | 1 AP | 3 | 100g | +power(15) crit on shock/arcane casts | 14 − shock resist arc to all |

- **DETONATE** = press the summon's button while it stands: pre-empt branch
  BEFORE the ability gates (bypasses CD), costs **1 AP, once per turn**.
- **INTERCEPT** sits between the trap gauntlet and Blink in the enemy-action
  stack — eats a damaging hostile action wholesale (denied_streak++, intent
  reroll, turn advance).
- **Lifetime 3 turns** (`ab.effect_duration`; web nodes extend), ticked in
  `need_player_status_tick`.
- UI: GLM/EFG/HSK buff chip with hover contract; the stage prop is a
  PLACEHOLDER pedestal + school-tinted orb + hit pips — replaced by the
  approved elemental art (magma_IDX0 / ward_IDX3 / storm_IDX2) at the next
  GM-closed import sitting.
- Generic web template maps cleanly: value = power, duration = turns.
