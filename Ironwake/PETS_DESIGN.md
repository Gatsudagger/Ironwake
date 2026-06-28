# PETS_DESIGN.md — Creature / Pet Subsystem

**System:** Pets & the Creature Keeper (Bairc)
**Status:** DESIGN COMPLETE — not yet implemented
**Depends on:** event/shrine/curse room system, 3-AP combat, trait system, hybrid affix system, Petra merchant, Gate loadout screen, full-clear extraction logic
**Stage-4 (Awakened) effects:** TBD — flagged placeholder, design pass after 0–3 ships and tests

---

## 1. Overview

A meta-progression companion layer. Players rarely acquire creatures from dungeon events, then raise them across runs through a three-axis economy (Stage / Growth / Bond). Pets gatekeep their utility behind life stages — from inert baby to formidable combat ally or boon-granter. Bairc, the Creature Keeper, is the hub NPC who stables, raises, and (through sparse dialogue) gradually reveals the subsystem's lore: these creatures are pets from past lives, or animals that have died.

Design priorities: keep most pets non-combatant most of the time (avoids combat-math bloat), make raising multifaceted but not grindy, and give the attachment real stakes (pets can be permanently lost).

---

## 2. Bairc, the Creature Keeper

| Field | Value |
|---|---|
| Name | Bairc |
| Title | The Creature Keeper |
| Personality | Male, large, brutish, very strong; gentle, tender, misunderstood |
| Location | Dungeon Gate hub (present from game start) |

**Dialogue restraint is mandatory.** The gentle-giant-among-monsters archetype works through what he *doesn't* say. Sparse lines only.

### Unlock behavior
- Bairc occupies a hub NPC slot from the start but is **dormant** until the player finds their first pet/egg.
- Interacting with him before that:
  > "......"
  > *He looks at you, unsure, then returns to his garden.*
- After the first pet is acquired, his full station opens: stable, feed, raising, lore dialogue.

### Roles once active
1. **Stable-master** — stores inactive pets (soft cap, §6).
2. **Raising** — Bairc-raised pets *select* their Stage-3 kit; wild pets roll it via RNG (§5).
3. **Feed intake** — player supplies feed (bought from Petra) to advance Growth.
4. **Donation** — unwanted/excess pets are donated to Bairc, not released/deleted (§6).
5. **Lore vector** — gradual past-lives reveal through dialogue as pets are raised.

---

## 3. Acquisition

Pets arrive in **two forms** — eggs (raised from scratch) and found creatures (already alive). Both are **rare** outcomes, well below standard event weights.

### Eggs (always hatch at Stage 0)
An egg always hatches a **Stage 0 baby** — never higher. The full raising/bonding loop is the point; an egg that hatched mid-grown would be incoherent and would gut the emotional core.

| Egg source | Rarity | Strength scaling |
|---|---|---|
| Random event room | Least rare (still rare) | Lowest |
| Shrine event | Rarer | Higher |
| Curse event | Rarest | Highest |
| **Boss drop** | **Special rare drop, top of ladder** | **Scales with floor / Awakening (§3.1)** |

**Egg strength/rarity scales with the rarity of its source.**

### Found creatures (already alive, Stage 1–2)
- A creature found **already living** in the dungeon may be at **Stage 1–2** — it has a life behind it.
- **Lower chance than finding an egg**, but possible.
- Flagged in flavor/data as **found, not hatched**, so the player (and the lore) remembers it didn't share the full history of a raised pet. This asymmetry is intentional texture — a Bond/lore distinction, not just a stat one, and a future Bairc-dialogue hook.

### Common to both
- **Archetype** (Boon / Combatant / Guardian) is rolled by **pure RNG at acquisition, independent of source**, and **revealed immediately at hatch/acquisition** so the player can plan loadouts around it.
- Thematic framing examples (sad/hopeful, Ironwake tone):
  - "An egg, beneath the skeleton of its mother — curled in a defensive position."
  - A **corrupted** pet that needs rescuing (§7).

### 3.1 Boss-drop eggs (signature species)

The top of the acquisition ladder — earned, not lucky-in-a-side-room.

- **Source:** any boss can drop one. **Drop rate and egg strength scale with floor / Awakening level.** Remains **rare even at max difficulty** (odds rise with Awakening but never approach guaranteed).
- **Still a Stage-0 egg.** No head start — it must be raised the full way like any other. The kill earns the *egg*; raising earns the *pet*. Earned twice.
- **Distinction (what makes it special):**
  1. **Signature species** — each boss has its **own unique pet**, found nowhere else. Collectible/completion hook across all bosses, and a strong lore vector (you raise something tied to the thing that killed you — past-lives resonance).
  2. **Guaranteed-good kit** — on reaching Stage 3, a boss-egg pet rolls its kit from the **curated (Bairc-raised-tier) pool, not wild RNG.** Its advantage is realized at the *end* of the raising journey, not the start — rewards the kill without an early-game power spike.
  3. **Awakening-scaled strength** — higher Awakening at the time of the drop = higher stat ceiling on that signature pet.

---

## 4. Archetypes & Life Stages

Archetype is fixed from acquisition through Stage 3. **Crossover is only possible at Stage 4 (Awakened).**

| Stage | Name | Boon | Combatant | Guardian |
|---|---|---|---|---|
| 0 | Baby | none* | none* | none* |
| 1 | Adolescent | 1 minor passive | 1 minor passive | 1 minor passive |
| 2 | Young Adult | 2 minor boons (e.g. +5% gold find) | own turn, 1 AP, limited ability selection | passive auto-buff/heal companion |
| 3 | Adult | 1 permanent passive (chosen at evolution, locked) + strong boons | own turn, 2 AP, 2 abilities | stronger auto-heal/buff + 1 permanent passive |
| 4 | Awakened | **TBD — crossover unlocked** | **TBD — crossover unlocked** | **TBD — crossover unlocked** |

\* *Stage 0 = no effect, except for a reserved signature pet/trait (see §11 Future Hooks).*

**Stage 3 permanent passive** is chosen at evolution into Stage 3 and **cannot be reselected** — a committed build decision.

**Combat presence:** the active pet's sprite is **always visible** beside the player for all archetypes (sells the lore — it's *with* you). Only **Combatant** pets take a turn (after the player's turn). Boon/Guardian pets are present but do not act on their own initiative.

> **Build note:** because all archetypes show a combat sprite, PixelLab/sprite work must cover every pet, not just combatants.

---

## 5. Progression — Three Axes

Progression is deliberately multifaceted. Three independent values per pet:

### Axis 1 — Stage (power; gated by RUNS)
- Crossing a stage boundary (evolving) **requires the pet to be the active companion and complete a run.**
- Run-progress is banked per run; **extraction/clear yields more than dying.**
- Only the **equipped (active) pet** gains run-progress. Stabled pets gain none.

### Axis 2 — Growth (fills the bar; driven by FEED)
- Feed advances *growth progress* toward the next stage transition.
- Feed works on **any** pet, active or stabled.
- **Feed is a multiplier on growth, never a replacement for runs.** Baseline (unfed) growth from an active run = **1× (never zero)** — a pet always grows from runs alone, just slower. Better feed = faster. Preferred feed = ceiling.

**The critical interaction (state this exactly):**
> A stabled pet can be fed right up to the edge of a stage transition and sit there *ready to evolve*, but it **cannot cross** until it is swapped to the **active slot** and completes a run. **Feed fills the bar; runs unlock the gate.**

This permits a patient player to prep a bench of ready-to-evolve pets, while the single active slot still forces an opportunity cost to cash them in. No hoarding exploit.

### Axis 3 — Bond / Loyalty (relationship)
- Rises from carrying a pet **active** through clean extractions/clears.
- Purpose: makes the past-lives lore *numeric* without grinding.
- Payoffs (specifics TBD, tune in playtest): species **preferred-feed discovery**, unique Bairc dialogue lines, possible Stage-4 flavor differentiation.

### Wild vs. Raised (kit quality)
- **Wild pets** (event/shrine/curse eggs, found creatures): Stage-3 ability/trait kit is **rolled by RNG** (often mediocre).
- **Bairc-raised pets:** player **selects** the Stage-3 kit from a curated pool.
- **Boss-egg (signature) pets:** roll from the **curated pool automatically** at Stage 3 (Bairc-tier quality without needing to be hand-raised by him) — see §3.1.
- Same ceiling for all (any pet can reach any stage); the difference is **quality/control, not access.** This is the concrete "raised usually stronger" mechanism.

### Feed (Petra merchant)
Add to Petra's item list:
- **3 tiers** of generic feed (scaling growth multiplier, scaling gold cost).
- A rare **species-preferred feed** per species → bonus growth progress (discovery tied to Bond).

---

## 6. The Stable (Bairc)

- **Soft cap.** Storage is not hard-limited, but **stabled pets require feed to stay happy and keep growing.** Past comfortable capacity, upkeep cost pressures the player to curate. (Threshold/curve TBD — playtest.)
- Stabled pets gain **Growth via feed only** (no run-progress; cannot evolve while stabled — see §5).
- **Donation, not release.** Unwanted/excess pets are **donated to Bairc** (lore-aligned: entrusted, not abandoned). Donated pets live in his visitable stable.
- **Visitable stable tab:** MVP shows each pet's **name + icon/sprite**. Animated sprites are **shelved but data-reserved** (sprite-state fields present, unused for now).

---

## 7. Corruption (rescued/corrupted pets)

A corrupted pet has **negative effects now but a higher ceiling when resolved.** On acquiring one, the player chooses a path:

- **Cure it** — safe, resolves to a **weaker** final form.
- **Push the corruption** — risky; carry the debuff (curse-system tone) and, **if survived to resolution, it becomes the strongest form in the game.**

- Corruption is tracked **separately** from injury (§8) — a pet can be both corrupted and injured (doubly impaired).
- Pushing is specced as a carried debuff that resolves to the strongest form if survived. Whether pushing adds permanent run-side risk vs. delayed payoff: **TBD, lean toward curse-room-style carried risk.**

---

## 8. Death, Injury & Permadeath

When the player **dies** in a run carrying the active pet:

- **All pets** (not only corrupted) take a temporary **injury debuff** (HP/stat penalty) on the *next* run.
- Injury **clears** on the next successful **extraction or full clear**.
- **Injury STACKS** on repeated deaths. An **injury ladder** of worsening tiers culminates in **permanent loss** of the pet if the player keeps dying while carrying it.
- Injury (`pet_injured`) stacks **distinctly** from corruption (§7).

> Exact ladder tiers/thresholds → **flagged for playtest tuning**, not guessed here.

This is the stakes mechanic: it makes the death-debuff meaningful and gives corruption-pushing real weight.

---

## 9. Pet Loadout / Companion Slot

- **1 active companion slot**, chosen at the **Dungeon Gate** before a run.
- Implemented as a **new "Companion" tab** on the existing tabbed Gate screen (alongside Abilities / Traits), reusing the universal control scheme (W/S nav, Q/E tabs, Enter select, Space confirm, Esc back).
- Inactive pets live in **Bairc's stable** (§6).
- Only the equipped pet levels (Stage) each run.

---

## 10. Lore

- **Premise:** these creatures are pets from past lives, or animals that have died.
- **Reveal:** slightly hidden, ambiguous; surfaced **gradually through Bairc's dialogue** as the player raises pets. Bond milestones can trigger fragments.
- **Thematic link:** Stage 4 **"Awakened"** deliberately echoes the **"Awakening"** difficulty modifier — pets reach their final form *because of* the loop, reinforcing the past-lives premise.

> **Naming safety:** *Awakened* (pet stage) and *Awakening* (difficulty) are distinct strings and pose **no engine collision**. Only risk is player UI confusion. Mitigation: never display them adjacent. Use explicitly distinct constants, e.g. `PET_STAGE_AWAKENED` vs `global.awakening_level`. Pet stage shows on the Companion panel; difficulty shows on run-select — different screens.

---

## 11. Deferred / Future Hooks

Captured for intent; **not** committed scope.

- **Bairc's garden as visible state** — garden visibly populates/grows as more pets are raised; passive progress display + reason to care about the whole roster.
- **Animated pet sprites everywhere** — all pet sprites animated (stable + combat). Data structure leaves room now; animation layer shelved.
- **Signature rule-breaker pet** — one reserved pet that breaks a stage rule (e.g. a Stage-0 baby that *does* have an effect, or a pet that "remembers" the player across the loop). Anchors lore in something concrete.
- **Bond payoff specifics** — exact thresholds and rewards for the Bond axis.

---

## 12. Open / TBD Summary

| Item | Status |
|---|---|
| Stage 4 (Awakened) crossover effects | TBD — design pass after 0–3 ships |
| Stable soft-cap threshold & upkeep curve | TBD — playtest |
| Injury ladder tiers & permadeath threshold | TBD — playtest |
| Corruption "push" risk model | TBD — lean carried-risk |
| Bond thresholds & payoffs | TBD |
| Feed tier multipliers & gold costs | TBD — balance pass |
| Boss-egg drop rate curve per floor/Awakening | TBD — balance pass |
| Signature species roster (one per boss) | TBD — content pass |

---

## 13. First Build Slice

**Slice 1 (next): Data structures + Bairc hub NPC (dormant state). No combat, no effects.**
- Define the pet data struct (archetype, stage, growth, bond, injury, corruption, sprite-state fields incl. shelved-animation placeholders).
- Add Bairc as a hub NPC slot, dormant; interaction shows the "......" line until first pet acquired.
- Globals for the stable array + active companion slot (empty for now).

Subsequent slices (order TBD): acquisition/egg-find + hatch → Companion Gate tab + equip → feed/growth → run-based stage evolution → combat sprite presence → Combatant turns → corruption → injury ladder.
