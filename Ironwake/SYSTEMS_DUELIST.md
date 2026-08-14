# SYSTEMS — THE ASHEN DUELIST TIERS (08-13, M design-locked; committed db577e6)

The recurring duel opponent ADDS technique as the ledger
(`global.duelist_encounters`) grows — at the SAME thresholds his tier art
changes. Kit assembly in obj_combat_controller Create (~525); AI sharpening in
`enemy_pick_ability` (scr_enemies ~180).

## Tier thresholds
| Tier | Prior duels | Art | New technique |
|---|---|---|---|
| T0 | 0–1 | t0 sprite | base kit: Quickstep Cut (spell 30%, CD3), Disarming Feint (weaken 15%, 2t) |
| T1 | 2+ | t1 | **Bleeding Lunge** (dot 25%, CD4, 3/t for 2t) + riposte scales with his +10%/duel growth (flat 12 fades vs 2.4× stats by T3 — M ruling) + never wastes the Feint on an already-weakened wrist |
| T2 | 5+ | t2 | **Perfect Parry** (stance 20%, CD5): next melee blow he takes is turned, riposte answers DOUBLE + Quickstep hunts repetition: same ability twice in a row → 60% Quickstep |
| T3 | 9+ | t3 | **THE PERFECT THRUST**: telegraph damage ×2, cannot be dodged (no afterimage/veil) — stun, weaken, or shield through it + opens every duel with the Feint |

## Duel frame (unchanged by tiers)
- Base speed 13 initiative — he outdraws slow heroes (SYSTEMS_INITIATIVE.md).
- Execute swing: player below 25% max HP → swings 50% harder.
- **Mercy**: the duel never kills — mercy fires, HP restored to entry value,
  ledger++, meta-saved on the spot.
- **PAR chip** visible from round 1 (DESIGN_DUELIST_CHALLENGE.md): par, current
  round, live grade (gold/steel/bronze) — grades the dueling-relic rewards.
- Dueling relics: see the 08-11 batch (pattern book record).

## Open items
- Duelist 122px size check (B-list play-pass).
- Per-ability duel anims deferred — combat draws enemies at a fixed frame.
