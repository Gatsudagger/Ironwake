# SYSTEMS — Enemy Difficulty Pass

**Status: BUILT (verify in-IDE). Confirmed by M.**
Goal: the game was too easy. This pass gives enemies **real abilities** (debuffs,
typed damage, self-heal, and — sparingly — control of YOU) and a **moderate stat
buff + per-floor scaling**, so the §3 boons (next) can be a genuine counterweight
instead of runaway power creep.

---

## 1. Enemy abilities
Enemies could previously only basic-attack (+ telegraph spike + one passive mechanic).
Now an enemy may use **one special ability per turn instead of its basic attack**.

`enemy_define(...)` gained an optional 17th param `abilities = []` (existing 16-arg
calls untouched). Each ability is built with **`enemy_ability(name, kind, chance,
cooldown, value, extra)`** (`extra` may set `dtype`, `status_kind`, `turns`, `msg`).

**Kinds:**
| kind | effect |
|---|---|
| `spell` | typed damage to the player (`dtype` 0-3), full mitigation chain via `combat_mitigate_player` |
| `debuff` | a status on the player (`status_kind` = vulnerable/weaken/blind), `value` + `turns` |
| `dot` | a damage-over-time on the player (`value` dmg, `turns`) |
| `control` | stun / root / silence on the player (`status_kind`, `turns`) — **sparingly** |
| `heal` | enemy self-heal (`value`) |

**Selection** (`enemy_pick_ability`): each enemy turn, tick per-ability cooldowns, then
among ready abilities that pass their `chance` roll, pick one at random (else fall through
to the basic attack). Cooldowns (`ability_cd`, reset in `enemy_clone`) prevent spam.

**Timing fix:** player statuses tick at the *start* of the player's turn (before they
act), so enemy-applied statuses use `duration = turns + 1` (except `dot`, which deals its
damage at tick time and uses `turns`). This makes a "1-turn stun" actually cost one action.
**Iron Will** (player trait) absorbs the first enemy status each combat.

**Control is deliberately rare:** low `chance` (22-30%), long `cooldown` (4), short
duration (1 turn stun / 2 turn silence). No stun-lock.

---

## 2. Ability assignments (v1)
All 9 **bosses** get `boss_ability_set(floor, dungeon)`: a scaling typed nuke
(14/20/28 by floor) + a sparing "Crushing Slam" stun (30%, cd 4).

**Ashen Vault:** Dungeon Wraith (Soul Drain + blind), Grave Stalker (Rending bleed),
Bone Colossus (Bone Crush stun, 22%).
**Scorched Depths:** Fire Drake (Cinder Breath + Searing burn), Smoldering Revenant (self-heal).
**Tundra Tomb:** Pale Archivist (Death Rune silence + Frost Bolt), Ice Specter (Numbing Chill weaken).

Other enemies remain basic-attackers (still buffed by §3). Easy to expand — add an
`abilities` arg to any `enemy_define`.

---

## 3. Stat buff + floor scaling
In `obj_combat_controller/Create_0`, after the ascendance multipliers:
- **Baseline +15%** HP/damage/telegraph for all enemies.
- **Per-floor** ×[1.00, 1.15, 1.30] on standard/elite (bosses excluded — their per-floor
  stats are already hand-tuned and escalate).
- Stacks multiplicatively with ascendance.

So a floor-3 standard enemy is ~1.15 × 1.30 = **~1.5×** its old HP/damage; floor-1 is +15%.

---

## 3b. Encounter size (2-4 enemies)
Combat previously always spawned exactly 2 enemies. Now `obj_combat_controller/Create_0`
builds an `enemies` array of **2-4** by room difficulty + RNG:
- **Standard:** 2-4 (`irandom(99) + (floor-1)*18` → <45 = 2, <80 = 3, else 4 — deeper floors lean larger).
- **Elite:** elite + 1, with a `(25 + floor*12)%` chance of a 2nd add (→ 3).
- **Boss:** boss + 1, with a `(15 + floor*12)%` chance of a 2nd add (→ 3). Adds are weak (HP 35 / dmg 6).

All scaling (ascendance, difficulty, stats/status/reach init, hit_flash) now **loops over the
`enemies` array**; `combat_init([player] + enemies)`. The combat Step/Draw already iterated
`combat_state.combatants` generically (target-cycling uses living-count), so no other files
changed. (Draw stair-steps enemies by slot — 4 fit but crowd; layout polish deferred.)

## 4. Integration points
- **scr_enemies** — `enemy_define` abilities param; `enemy_ability`, `enemy_pick_ability`,
  `boss_ability_set`; `enemy_clone` resets `ability_cd`; 7 enemies given abilities.
- **scr_combat** — `combat_mitigate_player(player, raw, dtype, log)` (shared player damage chain).
- **obj_combat_controller/Step_0** — ability execution block before the basic attack.
- **obj_combat_controller/Create_0** — boss ability assignment + difficulty/floor scaling.

---

## 5. Tuning knobs (all numbers are first-pass — expect to adjust)
- `_diff_base` (1.15) and `_diff_fmult` ([1.00,1.15,1.30]) in combat Create.
- Per-ability `chance` / `cooldown` / `value` / `turns` in the enemy definitions.
- `boss_ability_set` magnitudes.

## 6. Deferred
- Enemy AoE / multi-target abilities (only one player target today).
- Enemy buffs to allied enemies (only self-heal so far).
- Telegraphed control (wind-up then control) — kept simple (low chance + cooldown) for v1.
- Abilities on the remaining basic-attacker enemies.
