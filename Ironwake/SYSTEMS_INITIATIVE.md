# SYSTEMS — INITIATIVE V1 (08-13, M-locked; committed db577e6)

Turn order is rolled ONCE at combat start (`combat_start`, scr_combat ~line 40)
and drives the `combatants` array order for the whole fight.

## The roll
- **Player**: `10 + DEX/2`.
- **Enemies**: a family speed from `enemy_speed(name)` (scr_enemies ~265):

| Speed | Who |
|---|---|
| 13 | The Ashen Duelist (always outdraws a slow hero) |
| 12 | skirmishers — name contains stalker / crawler / lurker / imp / specter / shard / archer |
| 8  | default trash |
| 6  | bruisers — golem / colossus / sentinel / guardian / thrall / beast |
| 5  | ALL bosses and ALL Depth Wardens (they reliably close the round) |
| 4  | slugs |

## Sort
Descending initiative; ties break **DEX desc, then WIS desc** (the pre-initiative
pure-DEX order survives as the tiebreak). Insertion sort — stable for true ties.

## Interactions
- **Deadweight** (deepclaw scion signature): the swiftest FOE is dragged to the
  back of the order (applied right after the sort).
- Mid-fight **summons join the END of the turn order** (see SYSTEMS_SUMMONS.md) —
  they do not re-roll initiative.
- The player's stats-tour "Staying alive" card documents the player-facing rule:
  high DEX draws first, slow foes act last.

## Tuning levers
The speed table in `enemy_speed`, the player formula, and the tiebreak order.
V2 candidates (not built): initiative-modifying gear/traits, per-round re-rolls.
