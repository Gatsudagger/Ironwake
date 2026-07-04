# Ability & Trait Design Audit — 2026-07-03

**Scope:** all 49 abilities (15 per class + 4 general), all 25 traits, loadout economy, genre comparison, flavor. Read from `scr_abilities.gml` + combat hooks; numbers cited are the live values.
**Method:** overlap clustering → dead-pick analysis → bug sweep → genre gap analysis (Slay the Spire, Darkest Dungeon, Monster Train, Wildfrost) → concrete recommendations, ranked.

---

## 1. The good bones (what's already working)

Before the criticism: the underlying architecture is genuinely strong and most fixes are *content* fixes, not system fixes.

- **Role synergy** (same-category −1 AP after the first) + **setup→payoff** (Exposed/Sear primers, detonators) + **status reactions** are three interlocking combo systems — most games in this genre have one.
- Three distinct resource engines (Souls = cast/kill economy, Blood = damage-taken economy, Prep = patience economy) give real class identity.
- Attack-class × control (root/silence/stun) is a smart matchup layer most turn-based roguelites lack.

The problems below are mostly: *redundant slots inside a class*, *traits that don't do anything*, and *no reason to deviate from the obvious loadout*.

---

## 2. Overlap clusters (overly similar abilities)

### CLUSTER A — "Target takes more damage" is five abilities
| Ability | Cost | Effect |
|---|---|---|
| Curse (Arc) | 2 AP, 75 acc | +4 dmg taken, 3t |
| Scorch (Arc) | 1 AP | 8 dmg + Sear +3/hit 2t + 1 Soul |
| Throat Slit (SS) | 1 AP | 5 dmg + Exposed +4/hit 2t |
| Marked for Death (SS) | 1 AP | +8/hit, 3 hits / 4t |
| Bonebreaker (BW) | 3 AP | 18 dmg + +5 taken 3t |

**Verdict:** Scorch makes **Curse strictly worse** (Curse costs more, does no damage, banks no Soul, can miss at 75%, and its +4 is barely above Sear's +3). Within Shadowstrider, Throat Slit vs Marked overlap but differentiate on window shape (burst-window vs long mark) — keep both, but Curse needs a new identity (see §6).

### CLUSTER B — Four Soul-spending elemental nukes (Arcanist)
Arcane Burst (3AP+1S, 38, detonator) · Soul Nova (2AP, 8 + 7/Soul ≤4, detonator) · Arcane Echo (3AP+1S, 14 + 4/Soul *held*) · Singularity (3AP+3S, 32 AoE).
**Verdict:** Singularity is fine (AoE ultimate). Burst vs Nova is a real choice (fixed cost vs dump). **Arcane Echo is the redundant one** — "scales with Souls held" vs Nova's "scales with Souls spent" is a distinction players can't feel, and Echo costs *more* AP for usually less payoff. Rework it into something that isn't a fourth nuke (see §6).

### CLUSTER C — Spike Trap is strictly dominated
Bear Trap (2AP+1P: 16 + root) → Spike Trap (3AP+2P: 26 + bleed) → Death Snare (3AP+2P: 32 + **2-turn stun**). Spike and Snare cost the **same**, and a 2-turn stun beats 24 ticking bleed in nearly every fight.
**Verdict:** dead middle rung. Give Spike Trap a niche (see §6) or drop to 2AP+1P.

### CLUSTER D — Cross-class near-twins (acceptable, but watch)
- Blink (Arc) / Shadow Step (SS): same 1AP, 2-CD, 3-attack evasion; deterministic vs chance. Fine — class flavor — but they will always be compared.
- Soulbind (Arc, reflect 40%) / Bloodthorn Aura (BW, reflect 8 flat): the reflect fantasy twice. Both are individually weak (reactive damage in a game where you want enemies dead *before* they hit you). Consider merging identities: make one a *damage* tool, one a *tank* tool.
- Undying (BW ability, 3AP+3B) vs **Last Stand (trait, free once/run)**: the trait makes the ability nearly pointless for anyone who owns it. Undying needs to be cheaper or do more (heal on trigger).

### CLUSTER E — Sustain saturation (Bloodwarden)
Blood Leech, Blood Surge, Crimson Apex, Bloodfeast, + general Field Dressing/Second Wind + Vampiric Edge trait = 7 healing sources for one class. Individually fine, but the class's 15-slot pool spends ~5 slots saying "heal," which crowds out identity. **Second Wind is strictly dominated by Field Dressing** (2 AP for 10 HP + 1 resource vs 1 AP for 14 HP on a short CD).

### CLUSTER F — Strike (general) is a newbie trap after floor 1
Every class's 1-AP attack outclasses it (Soulfire 15+2 Souls, Cleave hits everyone, Snipe 14 @ 90 acc + crit 15). Fine as a floor for brand-new characters; bad that it stays selectable forever with no scaling.

---

## 3. Dead-end traits

| Trait | Problem | Severity |
|---|---|---|
| **Arcane Surge** | **Literal no-op.** Gated on `energy_cost >= 4`; no ability costs more than 3 AP. It can never fire. It's also a Vex-purchasable AND a potency target — players can invest in a dead trait twice. | BUG |
| **Crimson Reserve** | Says "+20 Blood"; `blood_max = 10`. At best it means "start full" — the number is a lie either way. | BUG (text/value) |
| **Lucky Find** | +5% consumable drop when base is ~10% and the pack caps at 10. Wins you ~1 potion per run. | Dead pick |
| **Treasure Hunter** | "Treasure rooms always contain at least one item" — post-loot-rework, do they ever contain zero? If not, this is a no-op in practice. Verify. | Likely dead |
| **Shadow Meld** | +15 dodge for 1 turn *after* dodging — but the stat-curve pass put diminishing returns on dodge specifically to stop dodge stacking. The trait fights the curve. | Weak |
| **Salvager** | Keep 2 items on death instead of 1 — a trait slot spent planning to lose. Has a niche (A5 pushing) but reads as anti-reward. | Marginal |
| **Sense** | Genuinely useful for new players, near-zero value once room types are memorized. Fine as a default. | OK-by-design |

The three AoE levers (Focused Power / Chain Caster / Plaguebearer) are good trait design — they change *how* your loadout plays, not just numbers. That's the bar the dead ones should be raised to.

---

## 4. Bugs found during audit (fix regardless of design decisions)

0. **UNIMPLEMENTED ABILITIES (found during the fix pass): Soulbind, Undying, and Evasive Roll have no combat code at all.** They exist as definitions, icons and tooltips only — no hook applies the reflect, the lethal-save, or the halve. Casting them spends AP/resources for nothing, and Soulbind/Undying are Vex purchases at 400g. These must be implemented (fold in their §6 rework versions directly — no point building the weak originals first).

1. **Arcane Surge condition** can never be true (§3). Either retune to "3-AP abilities deal +25%" or redesign.
2. **Crimson Reserve** value/cap mismatch (§3).
3. **`ability_category` cases "Death Trap"** — the ability is named "Death **Snare**"; the case never matches (falls through to the offense fallback, so same result today, but it's a landmine if the fallback logic changes).
4. **Stale player-facing numbers** — hand-written `desc_short`/`desc_full` strings drifted from the data after the §3 rework buffs: Arcane Burst says 28 (is 38), Marrow Crush says 18 (is 24), Spike Trap says 22 (is 26), Death Snare says 28 (is 32), Assassinate says 24 (is 26), Crimson Apex says heal 18 (is 20), Bloodthorn says 5 (is 8), Bonebreaker says 18 (is 14 in data!). Bonebreaker may be a *data* regression, not a text one — check which was intended.

---

## 5. Genre comparison — what's missing

**vs Slay the Spire:**
- **Enemy intent.** StS's single biggest lesson: defensive/control choices are only interesting when you can see what's coming. Ironwake has an approximate hit-preview; per-enemy intent icons (attack/spell/buff + rough magnitude) would make Defense and Control loadout slots *rationally pickable* instead of vibes. **This is the highest-leverage missing feature.**
- **In-run ability variance.** Loadouts are locked at the gate; every run with the same loadout plays the same opening. StS gets infinite variety from drafting. Cheap adaptation: shrines/events can grant a **temporary 5th/6th ability slot for this run only** (a "borrowed memory" — past-lives lore writes itself). Variance without redesigning the loadout system.
- **Ramp/scaling archetype.** Nothing in the game grows *within* a combat (StS: Demon Form; Monster Train: stacking units). Long boss fights therefore play the same on turn 8 as turn 2. One scaling ability per class fills this (see §6 Curse/Echo reworks).

**vs Darkest Dungeon:**
- **Personality in combat text.** DD's abilities drip flavor (bark lines, crits announced with drama). Ironwake's combat log is mechanically excellent and emotionally flat. Cheap win: 1 flavor line per ability shown in the Tab popup + occasional cast barks in the log.
- Positioning is DD's core; Ironwake's reach system covers ~30% of that value at ~5% of the complexity. Don't chase the rest.

**vs Monster Train / Wildfrost:**
- **Keyworded statuses.** You already have Sear, Exposed, bleed, poison, root, silence, stun, vulnerable — but they're described longhand in each tooltip. Promoting them to consistent bolded keywords (one glossary, reused everywhere) compounds every future ability's readability.

**What Ironwake has that these games don't:** the persistent hub/NPC/pet layer. The audit's flavor recommendations should route ability identity *through* that (Vex teaches you abilities — his lines should reference the ones you bought; Maren's runes touch schools — school-tagged abilities could get one rune interaction each).

---

## 6. Concrete rework proposals (dead picks → unique hooks)

Numbers TBD-balance; the point is each gets a hook no other ability has.

| Ability | Rework |
|---|---|
| **Curse (Arc)** | "Hexed: when the target takes a status reaction (detonation), the detonation bonus is doubled and the hex spreads +2 dmg-taken to all other enemies." Makes it the Control piece of a detonation build instead of a worse Scorch. |
| **Arcane Echo (Arc)** | Make it literally echo: "Deal 14. Next turn, it recasts itself free at 50% damage." First ramp/scaling ability in the game; keeps the name honest. |
| **Second Wind (gen)** | "Heal 8 + cleanse 1 debuff + restore 1 secondary." The only self-cleanse in the game — instant niche vs enemy control. |
| **Strike (gen)** | "Momentum: if Strike kills, refund the AP." Stays humble, gains a chaff-clearing tempo identity all classes can use. |
| **Spike Trap (SS)** | Drop to 2AP+1P and: "counts as 3 bleed ticks for Rupture-style consumers; the bleed is Exposed-boosted." The bleed-build trap vs Death Snare's control trap. |
| **Soulbind (Arc)** | Lean lifelink: "reflect 40% AND heal you for the reflected amount." One cast covers sustain + punish; deletes the overlap with Bloodthorn (which stays the tank thorns). |
| **Undying (BW)** | On trigger, also heal to 25% max HP and gain 3 Blood ("your blood refuses"). Cost justified vs Last Stand. |
| **Evasive Roll (SS)** | "Also gain 1 Prep when it absorbs a hit" — the defensive pick that feeds the trap economy. |
| **Arcane Surge (trait)** | Retune: "3-AP abilities deal +25%" (they're the committed casts) — one-line fix, instantly alive. |
| **Crimson Reserve (trait)** | "Start each combat with 4 Blood" (of 10) — honest and strong. |
| **Lucky Find (trait)** | Fold into Scavenger or rework: "consumables have a 20% chance to not be consumed." A real trait. |
| **Shadow Meld (trait)** | "After you dodge, your next attack is a guaranteed crit." Dodge feeds offense instead of more dodge — fights the curve no more. |
| **Treasure Hunter (trait)** | "Treasure rooms contain one additional item" (verify current behavior first). |

---

## 7. Flavor opportunities (cheap, high-charm)

1. **One lore line per ability** (`desc_flavor`, italic in the Tab popup below the mechanics). ~49 lines of writing; the past-lives premise gives every class a voice: Arcanist abilities remember *being cast before*; Bloodwarden's remember *wounds*; Shadowstrider's remember *jobs*.
2. **Cast barks in the combat log** for ultimates + first-cast-per-combat only (avoid spam): "Singularity: the room bends inward."
3. **Keyword glossary** in the Compendium (Sear, Exposed, Mark, Root, Silence, Stun, Bleed, Poison, Vulnerable) — then shorten every tooltip to use them.
4. **Trait names as memories**: the frame "traits are things the loop taught you" costs nothing and unifies the meta-progression fiction with the pet/Awakening lore.
5. **NPC voice on abilities**: Vex's ability-purchase rows get one opinionated line each ("Flurry. Fast hands waste no breath."). He's the trainer; let him coach.

---

## 8. Ranked plan (my recommendation)

**Quick wins (bug-tier, do first):** §4 all items — Arcane Surge condition, Crimson Reserve value, Death Trap/Snare case, stale desc numbers sweep. **[DONE 2026-07-03]**
**Also DONE 2026-07-03:** the unimplemented trio built as their §6 versions (Undying = cheat-death → 25% HP + 3 Blood at the shared lethal gate; Soulbind = 40% lifelink reflect on both enemy strike paths; Evasive Roll = halve >10 + 1 Prep refund), Strike = Momentum AP-refund-on-kill, Second Wind = +cleanse, Spike Trap = 2AP+1P, Arcane Echo = tooltip now discloses its (already-implemented!) 50% splash-to-all — the "redundant nuke" verdict was really an undocumented identity.
**Still open:** Curse detonation-hex rework, Lucky Find / Shadow Meld / Treasure Hunter trait fixes, enemy intent (INTENT_SPEC.md), flavor pass.
**High leverage (one system, huge fun-per-effort):** enemy intent icons — it retroactively justifies every Defense/Control pick in the game.
**Content pass:** §6 reworks (≈10 abilities/traits, all data + one rider each) — kills every dead pick without nerfing anything.
**Charm pass:** §7 items 1–3 (flavor lines, barks, keyword glossary).
**Later/optional:** run-scoped borrowed-ability events; a ramp ability for BW/SS to match Echo's; Second Wind-style cleanse counterplay if enemy control grows.
