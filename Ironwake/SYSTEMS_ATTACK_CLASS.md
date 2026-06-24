# Attack Classification + Control Effects — DESIGN-LOCKED (M approved 2026-06-20)

Every offensive action is classified on two axes, and control effects key off them.

## Axes → 4 classes
- **reach**: `melee` | `ranged`
- **kind**: `attack` (physical) | `spell` (magical)
- → `melee_attack`, `ranged_attack`, `melee_spell`, `ranged_spell`. Self/buff = `none`.

## Control rules (M: build silence functionally now)
| status | blocks | a target is shut down when… |
|---|---|---|
| **stun** | everything | always (any class) |
| **root** | melee actions | target's reach is `melee` (melee_attack/melee_spell) |
| **silence** | spell actions | target's kind is `spell` (melee_spell/ranged_spell) |

So: a melee_attack skeleton → stopped by root or stun (not silence). A ranged_spell
archivist → stopped by silence or stun (not root). A melee_spell wraith → root OR silence.
A ranged_attack archer → only stun.

Applied to **enemies** (their turn) and the **player** (cast guard — dormant until an enemy
applies control to the player; that's a later content item).

## Player ability classification (derived, single source of truth)
- **kind** = `attack` if `damage_type == 0` (physical), else `spell` (elemental/drain/blood).
- **reach** = `melee` if name ∈ MELEE set, else `ranged`. Self-targeted = `none`.
- **MELEE set:** Strike, Gore Strike, Marrow Crush, Bonebreaker, Blood Leech, Vital Theft,
  Plague Touch, Crimson Apex, Flurry, Killing Spree.
- Everything else offensive = ranged. Result: Arcanist = all ranged_spell; Bloodwarden phys =
  melee_attack, blood = melee_spell; Shadowstrider snipes/darts/traps = ranged_attack, Flurry/
  Killing Spree = melee_attack; Strike = melee_attack.

## Enemy classification
- **RANGED:** Skeleton Archer, Lava Spitter, Frost Shard, Pale Archivist. All others **melee**.
- **SPELL kind:** all wraiths (Dungeon/Vault/Ash/Snowbound Wraith), Ice Specter, Pale Archivist,
  Fire Drake, Lava Spitter, Frost Shard, Cinder Imp, Infernal Revenant, Smoldering Revenant.
  All others **attack**. Bosses (renamed) default to **melee_attack**.

## Status sources (player → enemy)
- **Bear Trap → root** (melee-lock). **Death Snare → stun**. **Mana Sever → silence**
  (changed from its old `vulnerable` debuff — "sever mana" = can't cast).

## Implementation (all .gml)
- `scr_abilities.gml`: `ability_attack_class(ab)` (derives from MELEE set + damage_type);
  update Mana Sever desc to silence.
- `scr_enemies.gml`: `enemy_is_ranged(name)`, `enemy_is_spellcaster(name)`.
- `scr_combat.gml`: `ability_status_kind` Mana Sever → `silence`; add `silence` to taxonomy;
  `combat_control_block_reason(combatant, attack_class)` → "" or "stunned"/"rooted"/"silenced".
- `obj_combat_controller/Create_0.gml`: set `enemy.reach` + `enemy.kind` after enemy build.
- `obj_combat_controller/Step_0.gml`: rewrite enemy control block (reach/kind aware);
  add player cast guard (block class via `combat_control_block_reason`).
- Text: Bear Trap (root → "can't use melee"), Mana Sever (silence), Death Snare (stun) — descs
  + `ui_draw_ability_tooltip`. (Full ability-text audit is a separate roadmap task.)

## Notes / future
- Enemy→player control (an enemy that roots/silences you) is the natural next content step;
  the player cast guard is built now so it just works when added.
- Compendium (§4b) will document all four classes + the three control effects.
