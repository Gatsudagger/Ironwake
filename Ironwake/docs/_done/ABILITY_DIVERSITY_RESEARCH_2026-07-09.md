# Ability Functional-Diversity Research + Proposals — 2026-07-09 (Bucket D — **DESIGN-LOCKED, M approved all sections 2026-07-09**)

M's ask: "abilities still need rework in terms of functional diversity, do a deep dive,
compare and contrast other games for balancing mechanics and viable variety... still many
useless abilities or missing abilities like frost."

Everything in §3–§5 is a **proposal for M's approval**. §1–§2 are analysis.

---

## 1. What the reference games teach

**Slay the Spire** (the genre's balance benchmark):
- Three functional buckets — Attacks (damage + secondary), Skills (defense/utility/debuff),
  Powers (combat-long engines). Ironwake's offense/defense/support/control mirrors the first
  two; **Ironwake has almost no "Power"-analog ramp abilities** (see gap G3).
- Their stated failure test: *"if any choice is obviously the best regardless of
  circumstances, the designers failed."* This is exactly the Rend-vs-Executioner problem
  (BALANCE_NOTE C4) applied to abilities: every kit needs its "when is this the wrong pick?"
  answer.
- Cards earn a slot by trading frontload for scaling or consistency for spikes — variance is
  a design axis, not a flaw. **Ironwake has zero gamble/variance abilities** (gap G5).

**Darkest Dungeon**: every hero skill is positional/situational — no skill is always
castable, so "useless in this fight" is fine if it's "essential in that fight." Ironwake's
analog is the school/status matchup (Void vs armor, silence vs casters, detonators vs
statused targets). Mana Sever ("wasted on pure melee bruisers") is GOOD design by this
lens — the problem is only when an ability has no fight where it shines.

**Monster Train / AP-economy games**: tactical depth comes from *more effective but more
expensive/risky options* competing for the same AP — and from costing by internal point
budgets (e.g., 1 AP ≈ N points; DoT points at ~0.75× face value because they're delayed;
conditional damage at face × realistic uptime; AoE per-target at ~0.6×).

**A working internal budget for Ironwake** (derived from the live kit): 1 AP ≈ 12–14 damage
points for a plain hit (Strike 10 + Momentum rider ≈ 13; Soulfire 15 − accuracy risk ≈ 13).
Secondary resource ≈ 6–8 points per unit (Soul Nova +7/Soul, Soul Rend +8/Soul). Statuses:
stun ≈ 14–16 (denies a turn), root ≈ 8 vs melee/0 vs ranged, silence ≈ 12 vs casters/0
otherwise, Weaken ≈ 8, Exposed ≈ 4/hit remaining. This is the yardstick used in §5.

## 2. Ironwake's functional coverage map (52 abilities)

| Function | Coverage | Notes |
|---|---|---|
| Single-target nuke | **Rich** | Arcane Burst, Singularity, Assassinate, Marrow Crush, Soul Rend, Snipe... |
| AoE | **OK** | Cleave, Rift, Singularity, Arcane Echo (splash), Flurry (multi-hit) |
| DoT | **OK** | Poison Dart, Plague Touch, Rupture, Scorch (burn), bleed sources |
| Control | **OK** | stun (Death Snare), root (Bear Trap, Gravewrack Grip), silence (Mana Sever, Curse?), blind (Smoke Bomb), Weaken |
| Setup→payoff | **Good** (post §3 rework) | Exposed combos, detonators, Marked for Death |
| Resource gen/dump | **Good** (Arcanist), OK (others) | Souls have 5 generators + 5 spenders; Blood and Prep have fewer levers |
| Defense | **OK** | Iron Skin, Soul Shield, Blink, Shadow Step, Evasive Roll, Undying, Bloodthorn |
| Heal | **Thin by design** | Field Dressing, Second Wind, Vital Theft/drains |
| **G1: Frost school** | **EMPTY** | flagged "sparse by design" in code; M wants it filled |
| **G2: Shock school** | **Weapon affixes only** | shock STATUS exists in the reaction system; no ability applies/spends it |
| **G3: Ramp ("Power") abilities** | **EMPTY** | nothing grows turn-over-turn; long fights play the same as turn 1 |
| **G4: AP economy** | **1 ability** | Adrenaline Rush only; the synergy discount is systemic, not a choice |
| **G5: Variance/gamble** | **EMPTY** | no high-roll option anywhere; Knucklebones has the gambling identity but combat doesn't |

## 3. "Still many useless abilities" — re-audit shortlist

Ranked by (my estimate of) pick-rate deadness, with the smallest rework that gives each a job:

| Ability | Why it's dead | Smallest fix (proposal) |
|---|---|---|
| **Curse** (Arcanist, no dmg) | Pure debuff, competes with Mana Sever/Soulbind which DO things | Fold into the hex system explicitly: "Hexed 3t: status REACTIONS against this target are doubled" (it already half-exists via `_hex_mult`) — makes Curse the detonator-build enabler |
| **Smoke Bomb** (Shadow) | Blind is weak vs abilities that don't roll accuracy | Also grants +15% dodge to YOU for the same turns — panic button identity |
| **Sanguine Pact** (Bloodwarden) | Resource trickle on a class that gains Blood by being hit | Rework: "1 AP: convert up to 3 Blood into 6 shield each" — Blood DUMP defense (Blood has generators but only damage spenders) |
| **Marked for Death** | Flat +dmg debuff, boring vs Exposed | Make it the EXECUTE setup: "target takes +30% from all sources while below 50% HP" |
| **Entropy** (Arcanist) | Slow void DoT on the nuke class | Give it the ramp job (G3): "combat-long: this deals +4 more each time it ticks" |
| **Soul Shield** vs Iron Skin | Two flat mitigation buttons | Differentiate: Soul Shield scales with Souls held (+3 shield per Soul) — reserve-defense identity |

(Full pass on all 52 happens at implementation; these six are the confirmed offenders.)

## 4. Missing-school kits (G1/G2) — proposed, all Vex-purchasable

**FROST = tempo control.** Rides the existing status/reaction plumbing (new status kind
`chill`; reaction partner: SHATTER, mirroring burn's crit bonus):

| Ability | Class | Cost | Effect (budget check) |
|---|---|---|---|
| **Hoarfrost Lance** | Arcanist | 2 AP | 16 Frost dmg + Chilled 2t (Chilled: the enemy's next attack deals −30%, and detonators SHATTER the chill for +35% dmg). ≈ 16 + 8 tempo = on budget |
| **Glacial Ward** | Arcanist | 1 AP | 8 shield; melee attackers who hit you this turn get Chilled. Defense that feeds the shatter loop |
| **Winter's Bite** | Shadowstrider | 1 AP + 1 Prep | Melee 9 Frost; vs Chilled targets +9 and refunds the Prep. Cross-class frost dip |

**SHOCK = chain/multi-target.** Shock status already exists from weapon affixes — these
abilities finally let a build APPLY it on purpose:

| Ability | Class | Cost | Effect |
|---|---|---|---|
| **Static Arc** | Arcanist | 1 AP | 9 Shock dmg, chains 50% to one other enemy; if the target was already Shocked, chains to ALL enemies |
| **Galvanize** | Bloodwarden | 2 AP | 12 Shock melee; you gain +1 AP next turn if it kills (shock-tempo bruiser) |

**RAMP (G3):** **Soul Engine** (Arcanist, 2 AP, once per combat, combat-long): "Your spells
deal +3 more for each turn that has fully passed." The StS-Power analog; strong in boss
fights, dead weight in 2-turn trash fights — a real deckbuilding decision.

**GAMBLE (G5):** **Devil's Flip** (General, 1 AP): "50/50 — deal 26 damage, or take 8
yourself." Budget: EV 13 vs Strike's 13, pure variance. Cheap to build, huge personality.

## 5. Balancing method going forward (process proposal)

1. Every new/reworked ability states its **budget math** in the PATCH_NOTES row (like §1's
   yardstick) — cheap to audit, prevents drift.
2. Every ability must name **the fight where it's wrong** (StS test). If we can't, it's
   overtuned; if we can't name the fight where it's RIGHT, it's dead.
3. New content prefers **filling a gap column** (§2 table) over adding to a Rich column.

---

## Approval checklist — ALL APPROVED (M, 2026-07-09)

- [x] §3 all six reworks (Curse, Sanguine Pact, Entropy, Smoke Bomb, Marked for Death, Soul Shield)
- [x] §4 Frost kit — all 3 abilities + chill/SHATTER status
- [x] §4 Shock pair (Static Arc, Galvanize)
- [x] §4 Soul Engine ramp
- [x] §4 Devil's Flip gamble
- [x] §5 process rules (budget math in patch notes; name the fight where it's wrong; fill gap columns first)

**Pricing (M-approved):** 1-AP entries Vex 250g · 2-AP entries Vex 400g · Soul Engine
premium 500g · Devil's Flip 100g (personality pick). Standard rarity-matched item costs
per the existing Vex ladder.

Sources: [Cloudfall Studios — Game Design Tips from Slay the Spire](https://www.cloudfallstudios.com/blog/2020/11/2/game-design-tips-reverse-engineering-slay-the-spires-decisions), [Slay the Spire wiki — Cards](https://slaythespire.wiki.gg/wiki/Cards), [Game Developer — 12 ways to improve turn-based RPG combat systems](https://www.gamedeveloper.com/design/12-ways-to-improve-turn-based-rpg-combat-systems), [Untamed Tactics — designing turn-based combat](https://gameworldobserver.com/2022/12/02/how-to-design-turn-based-combat-system-untamed-tactics), [Rogueliker — A Decade of Darkest Dungeon](https://rogueliker.com/darkest-dungeon-retrospective/)
