# DESIGN — Talent Web Bespoke Pass (P3) (draft for M review, 2026-07-29)

**Status: BUILT 07-29 (same session, M's order), awaiting F5. Build notes:
"Crescendo: ramp cap +1" was uncodable as written (neither Warpath nor Dread has
a cap) - shipped as a FASTER ramp instead (Warpath +3/turn, Dread +6/trap),
flagged for M. Remaining pure-template webs (no identity yet, per the standing
rule's allowance): Glacial Ward/Marked for Death/Shadow Step/Curse/Mana Sever
and the plain damaging abilities on the hashed keystone pool.**

## Problem (M, 07-29: "a lot of these talents need rework as they're just clones and generic")
The web generator (`ability_web_nodes`) templates by shape (damaging / timed / instant).
Damaging abilities got a hashed keystone pool (07-27) so they diverge; the NON-damaging
templates still emit clone nodes:
- Instant heals/shields: `Deeper Roots` → `Concentration` → `Overflowing Power` on one
  branch, and `Deeper Roots II` / `Concentration II` on the other — four +healing nodes
  that read identically (M's Blood Surge report).
- Every non-damaging tk = `Opening Gambit`, every CD ability t2 = `Swift Recovery`.

Fixed already (07-29): Field Dressing (Twist t1 → **Mender's Rite** cleanse), Blood
Surge (Twist → **Thick Blood** cost -1, **Crimson Overflow** overheal-to-shield),
Opening Gambit now waives resource cost on 0-AP abilities.

## Rule going forward (M-LOCKED 07-29 — standing rule for all future web work)
**Every ability's two branches must answer different questions.**
- POWER: "more of what it already does."
- TWIST: "a different way to use it" — economy, timing, conversion, utility.
A branch whose nodes could be copy-pasted onto a sibling ability is a defect.
Value nodes may stay for tiers 1-2 on the POWER side only; TWIST tiers should be
bespoke (rider) nodes wherever the ability has any identity to build on.

## Proposed bespoke TWIST nodes (worst offenders first)
All ride existing rider keys / idioms — cheap to wire. New rider keys marked ★.

| Ability | Twist t1/t2 proposal | Keystone (tk) proposal |
|---|---|---|
| Iron Skin | t2: **"Sharp Edges"** — while Iron Skin holds, melee blows that hit you take its reduction value back as damage ★ (M-LOCKED 07-29; rides the per-attack melee classification) | keep Iron Bulwark (has bespoke) |
| Bloodthorn Aura | **companion change (M 07-29): its reflect also applies Bleed 2/2t to melee attackers** — keeps Bloodthorn distinct once Iron Skin reflects (reflect+DoT = the anti-melee-pack tool) ★ | — |
| Soul Shield | t1: "+3 shield per Soul held becomes +4" ★ (scales its identity) | "Unbroken: shield remnant carries to next combat (max 10)" ★ |
| Blink | t1: "2nd/3rd charge softening 50/25% → 60/35%" ★ | keep Counterphase (has bespoke) |
| Vanish | t1: "+12 next-strike bonus → +18" ★ | keep Shadow Feint (has bespoke) |
| Smoke Bomb | t1: "The smoke also WEAKENS enemies inside (-15% dmg)" ★ | "Choking Cloud: enemies acting in smoke lose their intent 1st round" ★ |
| Second Wind | t1: "Cleanses TWO afflictions" ★ | "Adrenal Memory: also refunds 1 AP if you're below 50% HP" ★ |
| Adrenaline Rush | t1: "HP cost 5 → 3" ★ | "Overdrive: usable twice per turn (once per combat)" ★ |
| Soul Harvest | t1: "+1 extra resource when an enemy died this turn" ★ | **"Soulmend"** — Soul Harvest also heals 3 HP per Soul gained (M-LOCKED 07-29; the Arcanist's only self-sustain — replaces the redundant kill-trigger idea, kills already pay Souls) ★ |
| Sanguine Pact | t1: "Shield per Blood +1" ★ | "Blood Debt: pact shield breaking deals its value as damage to attacker" ★ |
| Warpath / Compounding Dread (ramps) | t1: "Ramp starts 1 stack pre-lit" ★ | "Crescendo: ramp cap +1" ★ |

## Scope & order (M-LOCKED 07-29)
- **ONE build pass:** the full table + the sweep of remaining `Deeper Roots II` /
  `Concentration II` emissions together (template fallbacks stay only for
  abilities with no identity yet — log which remain at build time).
- Table approved in full. **Livetest watch-list (flagged hot):** Adrenaline Rush
  "Overdrive" (twice-per-turn HP→AP) and Soul Shield "Unbroken" (carryover
  shield) — tune first if anything's degenerate.
- Reference sync per node (web labels self-describe, so this is mostly free).
