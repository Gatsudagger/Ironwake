# AoE + Status (Buff/Debuff) Systems — IMPLEMENTED (2026-06-19)

## Implementation notes / deviations (read these)
- **Typed status layer** lives in `scr_combat.gml`: `combat_status_kind_of`,
  `ability_status_kind`, `combat_status_total/max/has`, `combat_tick_statuses`,
  `combat_heal_after_mortality`, `combat_absorb_shield`, `combat_on_enemy_defeated`.
  Each applied status now carries a `kind`; legacy statuses fall back to `effect_type`.
- **AoE via target-list loop**: the single-target cast block in
  `obj_combat_controller/Step_0` was wrapped in a `for (_targets)` loop. `_targets`
  = all living enemies when `ab.is_aoe`, else the selected one. Same code path =
  no single/AoE divergence. Tagged AoE: Rift, Singularity (damage), Smoke Bomb (blind).
- **Kill rewards** refactored into `combat_on_enemy_defeated()` (gold/loot/XP/soul/
  aegis) — called by the single, AoE, and Chain-Caster-splash paths. The DoT-kill
  path in the enemy tick was left on its own (no soul-on-kill/aegis there, unchanged).
- **Control**: Death Snare (stun 2t) and Bear Trap (root 1t) have `effect_type
  "status"`, which the status-push guard previously excluded — they never applied.
  Guard widened to push them; enemy turn skips while `combat_has_status(stun/root)`.
  Control state is captured BEFORE the tick decrements it so a 1-turn stun still costs
  a turn.
- **Vulnerable** (sum) added after `combat_resolve_damage` on both directions;
  **Weaken** (max) reduces outgoing damage; **Blind** (max) subtracts `value*100`
  accuracy points; **Mortality** (max) scales heals via `combat_heal_after_mortality`
  (applied at the two player ability-heal sites; enemy healing isn't implemented in
  combat yet, so Plague Touch's mortality is latent until it is).
- **Soul Shield** now has a real consumer: `player.shield_hp` absorbs damage before
  HP (primary + double-strike). Previously Soul Shield did nothing.
- **Player status array**: `player.status_effects = []` + `player.shield_hp = 0` in
  combat Create; ticked once per player turn via `need_player_status_tick` (set at all
  enemy→player transitions, consumed at turn start; DoT death routes through Last Stand).
- **3 traits** added (`traits_all` + `traits_unlocked` keys + backfill for old saves):
  Focused Power (total_boss_kills 4, unlock in combat boss block), Chain Caster
  (char_level 8 via `grant_xp`), Plaguebearer (dungeon_clears_total 6 via scr_stats).
  Plaguebearer spread gated to `!_is_aoe`. Chain Caster splash 40% to others on
  single-target elemental/void/blood hits.
- **Snipe** "+20 if debuffed" was never wired; now fires on vulnerable/weaken/dot/blind.
- Tooltip shows "Targets: ALL enemies" (or "SELECTED (Focused Power +50%)") for AoE.
- **NOT done in-IDE**: GMS2 compile/test must be run by M (can't compile here).

---

# AoE + Status (Buff/Debuff) Systems — DESIGN-LOCKED (M approved 2026-06-19)

**M decisions (all "your call"): (1) INCLUDE stun/root control effects this pass.
(2) INCLUDE Plaguebearer as the 3rd trait. (3) AoE deals FULL damage to all; Focused
Power is the single-target burst lever.** Build everything in §1–6 + all three traits.

Goal: (1) a real **AoE** system so "hit all enemies" abilities actually do; (2) a
**typed status layer** so debuffs/buffs that abilities already advertise actually work;
(3) **new AoE-themed traits**. All `.gml` only.

Current engine facts this builds on:
- Player→enemy damage: `combat_resolve_damage()` does flat mitigation, then the caller
  applies % mods (Arcane Surge etc.) → `combat_apply_damage()`. One `target`.
- Enemies own `status_effects[]`, ticked on their own turn (DoT works). Player has NO
  status array — buffs are ad-hoc fields (`damage_reduction`/`iron_skin_duration`,
  `bloodthorn_*`). Enemies don't apply statuses to the player today.
- `"debuff"` effect_type is overloaded: +dmg-taken (Curse), −dmg-dealt (Marrow Crush),
  −acc (Smoke Bomb), −healing (Plague Touch) all share it and none are applied.

---

## 1. Status taxonomy (new `kind` on each applied status)

When a status is pushed onto a combatant, tag it with a `kind`. Aggregation helpers in
`scr_combat` read all active statuses and return the combined modifier:

| kind | meaning | aggregation | applied where |
|---|---|---|---|
| `dot` | damage over time | sum of values, ticks on bearer's turn | already works (enemy); add player tick |
| `vulnerable` | +flat damage taken | **sum** | enemy: after `combat_resolve_damage`, before % mods |
| `weaken` | −% damage dealt | **max** (no stacking abuse) | reduces that combatant's outgoing damage |
| `blind` | −% accuracy | **max** | subtract from hit chance in `combat_roll_hit` path |
| `mortality` | −% healing received | **max** | scales heals applied to the bearer |
| `mark` | +flat dmg per hit taken | **sum** | folded into `vulnerable` (same math) |
| `stun` | skip bearer's next turn | flag | enemy turn: skip + decrement (see §4) |
| `root` | bearer can't act offensively | flag | enemy turn (see §4) |

Helper API (new, in `scr_combat.gml`):
```
combat_status_total(c, kind)   // sum of effect_value for active statuses of kind
combat_status_max(c, kind)     // max effect_value (for % kinds)
combat_has_status(c, kind)     // bool — used by Snipe "+20 if debuffed"
combat_tick_statuses(c, log)   // tick DoTs, decrement durations, drop expired — reused
                               //   for BOTH enemy and (new) player turn start
```

### Ability → status-kind mapping (re-tag existing; no number changes)
- **vulnerable**: Curse (+4/3t), Mana Sever (+4/3t), Bonebreaker (+5/3t),
  Marked for Death (+8 per hit/4t).
- **weaken**: Marrow Crush (−30%/3t), Crippling Shot (−25%/3t).
- **blind**: Smoke Bomb (−40%/2t, AoE).
- **mortality**: Plague Touch (−50%/5t).
- **dot**: Gore Strike, Entropy, Poison Dart, Spike Trap, Serrated Strikes, Bloodfeast rider (unchanged).
- **Snipe**: "+20 if target debuffed" → fires when `combat_has_status(target,"vulnerable")
  || _ "weaken" || _ "dot" || _ "blind"` is true.

Mapping lives in one place: a small `ability_status_kind(ability)` switch (by name /
effect_type) so the cast code tags the pushed status correctly.

---

## 2. Buffs (player self) — make the advertised ones real
- `vulnerable`/`weaken`/etc. also work **on the player** via the same helpers once the
  player gets a `status_effects[]` array (added in combat Create + ticked at player turn
  start). Lets future enemy debuffs land on the player too.
- **Soul Shield** (absorb 10): currently a `shield` status with no consumer. Add a
  `player.shield_hp` pool; incoming damage depletes shield before HP. (Verify it isn't
  already handled — if so, leave it.)
- Iron Skin / Bloodthorn stay as-is (already functional).
- New generic buff kind `empower` (+% damage dealt) reserved for traits/future use.

---

## 3. AoE system
Mark abilities post-define: `ability.is_aoe = true` (default absent = single-target).
Optional `ability.aoe_falloff` (default `1.0` = full damage to every enemy).

**AoE abilities**: Rift, Singularity (damage), Smoke Bomb (blind, no damage).
Cast resolution for `is_aoe && !self_targeted`:
- Loop every living enemy. Per target: independent hit roll, independent crit roll,
  full damage pipeline (× falloff), apply its DoT/debuff, spawn VFX/popup.
- Kill handling (gold/loot/xp/soul-on-kill) refactored into a single
  `combat_on_enemy_defeated(target, ...)` helper and called per enemy (removes today's
  inline-in-one-target duplication; single-target path calls the same helper).
- Targeting UI: AoE abilities show "Targets: ALL" and ignore `selected_target`.

---

## 4. Control statuses (stun/root) — scope check
Bear Trap root, Death Snare stun, Spike Trap currently push `status` with no consumer.
**Proposed (small):** at enemy turn start, if `combat_has_status(actor,"stun")` →
skip the turn and decrement; `root` → allow nothing offensive (same as stun for these
single-attacker enemies). If you'd rather defer control effects to a later pass, say so
and I'll ship §1–3 + traits only.

---

## 5. New traits (AoE-themed) — `global.traits_all` + `traits_unlocked` keys

| Trait | Class | Unlock | Effect | Hook |
|---|---|---|---|---|
| **Focused Power** | any | total_boss_kills 4 | AoE abilities instead hit only your selected target for **+50%** damage. | AoE cast branch: if active → single-target path × 1.5 |
| **Chain Caster** | any (or Arcanist) | char_level 8 | Your single-target elemental/void/blood damage abilities deal **40% splash** to all other enemies. | post-damage on single-target damaging casts |
| **Plaguebearer** *(optional 3rd)* | any | dungeon_clears_total 6 | DoTs/debuffs you apply also apply to all other enemies at half duration. | on status apply |

Potency-upgradable? No (boolean traits) — consistent with Sense/Iron Will.

---

## 6. Files in scope (all `.gml`)
- `scr_combat.gml`: status helpers (`combat_status_total/max/has`, `combat_tick_statuses`,
  `ability_status_kind`), `combat_on_enemy_defeated` helper, shield-pool consumer.
- `obj_combat_controller/Create_0.gml`: `player.status_effects = []`, `player.shield_hp = 0`.
- `obj_combat_controller/Step_0.gml`: AoE cast loop + single-target via shared helper;
  apply vulnerability/weaken in damage calc; blind in hit path; mortality at heal sites;
  player status tick at player turn start; stun/root at enemy turn (if in scope); Snipe
  conditional; Focused Power / Chain Caster hooks.
- `obj_combat_controller/Draw_64.gml`: "Targets: ALL" indicator for AoE; status icons/text
  on enemies (optional polish).
- `scr_abilities.gml`: `is_aoe` tags on Rift/Singularity/Smoke Bomb; 2–3 new trait defines;
  unlock helpers already generalize.
- `scr_stats.gml`: Plaguebearer/trait unlock hooks (if added); no save changes (traits
  saved generically; `highest_run_level` already persisted).

---

## Open questions for M (pick or say "your call")
1. **Control effects (stun/root)** in this pass, or defer? (Recommend: include — small.)
2. **Plaguebearer** (3rd trait) yes/no? (Recommend: yes — ties debuffs to AoE theme.)
3. AoE damage: **full to all** (proposed) vs reduced falloff baseline? (Recommend: full;
   Focused Power trait is the lever for single-target burst.)
