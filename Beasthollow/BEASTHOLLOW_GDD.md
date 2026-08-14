# Beasthollow — Game Design Document

*(Supersedes GENETICS_SPEC.md v0.1)*

**Version:** 3.6
**Engine:** GameMaker Studio 2 · **Platform:** Mobile (landscape) and PC · **Studio:** Fable 5
**Setting:** Grounded medieval fantasy — a decayed creature sanctuary being reclaimed

---

## 0. Design pillars

1. **Few creatures, deeply invested.** Not a production line. A player may keep 1–3 companions for most of the game. Lifespans are long; loss is rare and meaningful.
2. **Breeding is the game.** Every other system gives it purpose, pressure, or payoff.
3. **Derived, not authored.** Compatibility, species identity, and trait availability are computed from the genome. No hand-written N×N tables.
4. **Soft caps, never walls.** Every limit is a penalty you can accept, not a block.
5. **Divergent paths.** Specialist breeder/shower and adventurer/battler are both complete games. An "ugly" creature by association standards may be the finest working companion alive.
6. **Weighty days.** Days are Harvest Moon dense, not Monster Rancher instant. A day should contain enough that playing it is worth it.
7. **Art is the constraint.** Any genetic feature that multiplies the sprite budget is wrong regardless of how it reads on paper.

---

## 1. Vocabulary

| Term | Meaning |
|---|---|
| **The Board** | Outward-facing NPC commissions. Money and goods come *in*. |
| **The Works** | Inward-facing restoration projects. Money, materials, days go *out*. |
| **Place** | A named region of the sanctuary (the brook, the meadow). Fixed environment. |
| **Nest** | A built structure within a place that moderates its environment. |
| **Archetype** | One of 15–20 seeded reference species. Landmarks, not a roster. |
| **Strain** | A creature outside every archetype radius. Auto-named, player-renameable. |
| **Handler level** | Baseline expertise floor across all species. |
| **Familiarity** | Per-archetype expertise, can exceed the floor. |

---

## 2. Genome structure

Four independent layers.

| Layer | Contents | Governs | Art cost |
|---|---|---|---|
| **1. Axes** | 5 diploid integer genes, 0–6 | Species identity, compatibility, silhouette, palette | High |
| **2a. Features** | 16 diploid booleans | Discrete visible morphology | High |
| **2b. Traits** | 25 at v1, in four families, expandable | Ranch, social, sense, and combat effects | **Zero** |
| **3. Aptitudes** | 6 numeric values | Stat ceilings, partly heritable | Zero |
| **4. Stats** | 6 derived values | Trials, combat, work — **Appendix E** | Zero |

The 2a/2b split is the most important production decision here. Physical traits cost a compositor part each and are capped. Behavioral traits cost only code, so they expand indefinitely — and they generate the "she's special because of *how she acts*" attachment the visual layer can't reach.

### 2.1 Data shape

```gml
creature = {
    axes : {
        metabolism  : [a, b],   // 0..6
        integument  : [a, b],
        frame       : [a, b],
        element     : [a, b],
        temperament : [a, b]
    },
    features : { horn:[t,f], long_fangs:[f,f], ... },        // Appendix C.1

    // Behavioral traits carry origin flags and optional variants — Appendix C.0
    traits : [
        { id:"territorial",     variant:"own_kind", alleles:[t,f], origin:"inherit" },
        { id:"tolerant",        variant:"cold",     alleles:[t,t], origin:"inherit" },
        { id:"share_food",      variant:null,       alleles:null,  origin:"learn"   },
        { id:"battle_hardened", variant:null,       alleles:null,  origin:"acquire" }
    ],

    aptitudes : { vigor, celerity, nerve, acuity, fecundity, longevity },

    // Size input — lives with the size system (§9), not the stat block
    mass_tendency,

    // Stats — Appendix E. Ceiling derived at birth, current stored and levelled.
    stat_ceiling  : { vitality, power, celerity, nerve, stamina, acuity },
    stat_current  : { vitality, power, celerity, nerve, stamina, acuity },
    stat_overshoot: { vitality, power, celerity, nerve, stamina, acuity },

    // Non-genetic
    sex, age_days, birth_season, birth_moon, life_stage, care_history,
    bond, affinities{}, bonded_to, grief_state,
    fertility_remaining, inbreeding_coefficient, injuries,
    lineage_id, parents, is_retired, is_pastured, is_in_party
}
```

---

## 3. The phenotype axes

Five axes, seven integer steps each (0–6). ~16,800 expressed phenotypes.

| Axis | 0 | 6 | Owns |
|---|---|---|---|
| **Frame** | upright, limbed | sprawling, serpentine | Silhouette — 7 base bodies |
| **Integument** | fur / feather | scale / slime | Texture overlay — 7 patterns |
| **Metabolism** | endotherm | ectotherm | Palette temperature |
| **Element** | pyric | hydric | Palette ramp |
| **Temperament** | feral | placid | Posture / eye overlay |

**Hard art rule:** exactly one axis owns silhouette, exactly one owns texture. Everything else is palette or a small shared overlay. If two axes alter body shape, asset count squares.

Integers rather than floats because the compositor must select a discrete asset per layer, and because countable distance makes compatibility legible without a tutorial.

---

## 4. Dominance

Dominance rank is a property of the **value**, not the allele instance — required so mutation-created values arrive with a rank defined.

```gml
rank(v) = 3 - abs(v - 3)   // 3→3, 2/4→2, 1/5→1, 0/6→0
```

Ties resolve randomly.

**Extremes recessive, middle dominant.** Consequences, all intended:
- Rare phenotypes hide as carried recessives, giving the expertise ladder a job
- Populations drift toward the mean, keeping purebred extremes scarce
- No *directional* drift — both ends equally recessive
- Wild capture and traders are the faucet reintroducing extreme stock

---

## 5. Inheritance

### 5.1 Axes

Per axis, per birth:

1. **Crossover** — each parent contributes one allele from its pair. Selection is random by default, weighted by **line designation** and **inheritance fidelity** where either applies (§5.7).
2. **Conditional blend** — if `abs(parent_A_expressed - parent_B_expressed) >= 2`, then with **10% probability** the inherited pair is replaced by the rounded midpoint of the expressed values.
3. **Mutation** — 4% chance of ±1; 0.5% chance of ±2 which may exceed both parents' range. Clamped 0–6. Mutation rates rise during the Dark moon week and in high-stimulation nests.

Rolled **per axis, per birth**, so at 4% roughly one birth in five carries an axis mutation somewhere. Note that ±1 only breaks the natural range when the value already sits at 0 or 6 — most of the time it simply shifts something. It is **±2 that genuinely exceeds what the parents could produce**, which is why it stays an order of magnitude rarer and carries the anti-optimisation weight of §5.4.

Conditional blending means variance appears during adventurous crosses and stays quiet when refining an established line. A flat rate would tax precision breeding for nothing.

Because crossover inherits whole values, distance closes **axis by axis in discrete jumps**. Breeding is assembling a hand of cards, not mixing paint. This puts real weight on archetype placement — intermediates must actually possess the values a bridge requires.

### 5.2 Features

**Mixed dominance — 11 recessive, 5 dominant.** Recessive features need both copies; dominant features express on one. Per-locus flags live in C.1.

All-recessive was wrong for a reason that is arithmetic rather than aesthetic. At an allele frequency of 0.2, recessive expression is p² = 4% per locus, so across 16 loci the expected feature count is ~0.6 *before* the phenotype gates cut further. In a game where a player keeps one to three animals for most of a playthrough, most creatures having no features at all is flatness, not scarcity.

Dominant expression is `2p - p²` — 36% at the same frequency, nine times more common. A split of ~11 recessive at p≈0.25 and ~5 dominant at p≈0.15 lands near two expressed features before gating. Distinct animals, not Christmas trees.

The two modes also produce opposite breeding puzzles, which is the real reason to have both:

| | Finding it | Locking it |
|---|---|---|
| **Recessive** | Hard — hides in the line, skips generations, rewards expertise tier 3 | Trivial — two expressing parents are both homozygous, so it fixes permanently |
| **Dominant** | Easy — visible on sight, easy to select against | Hard — a heterozygote looks identical to a homozygote without deeper reading |

**No incomplete or co-dominance.** A visible heterozygote intermediate means a third asset per locus — 16 extra parts against a ~30-part budget. Pillar 7 settles it.

**Assignment rule.** The chase features requiring two extreme values (§6's 10% band) stay recessive. The ungated modest ones go dominant: Long Fangs, Split Tail, Heterochromia, Webbed Feet, Frill.

Feature mutation: 0.1% per locus per birth may create a positive allele from nothing.

### 5.3 Aptitudes

```
offspring = round(parent_average * 0.6 + random_range(min, max) * 0.4)
```

### 5.4 Inheritance ceiling

Normal breeding cannot exceed the 0–6 range or the aptitude cap. Values beyond the natural range arise **only from mutation**. Deliberate anti-optimization: there is always something breeding alone cannot reach.

### 5.5 Inbreeding

Each creature carries an **inbreeding coefficient**, computed recursively from shared ancestry between its parents. Wild-caught and traded stock have a coefficient of 0.

High coefficients raise the chance of **defects** — negative behavioral traits, reduced longevity, reduced fertility, failure to express otherwise-guaranteed traits.

This is the primary anti-perfection mechanism. A player cannot close their gene pool and grind toward a perfect creature; they must periodically outcross, reintroducing variance they didn't choose.

**Design rule:** one generation of tight breeding to lock a trait, then outcross. That should be the discovered optimum, not a punishment — the threshold bands in **Appendix D** are calibrated so a single sibling pairing is survivable and a second is not.

### 5.6 Environment biases the roll

Nest and facility quality shift offspring outcomes *before* genetics resolves — trait odds, mutation rate, defect rate, and hatch quality. Ranch investment is therefore genetically meaningful, not merely logistical.

### 5.7 Inheritance agency

Two levers give the player control over *inheritance* rather than only over compatibility. Without them the breeding project — assembling specific values in one animal — is an unmitigated lottery, and every comparable game in the genre provides an equivalent.

**Inheritance fidelity.** A quality value on the breeding nest, derived from nest tier, facility effectiveness, and both parents' comfort. It raises the chance that crossover takes the **higher dominance-ranked** allele at each locus rather than a coin flip.

```gml
fidelity = clamp(nest_quality * facility_effectiveness * comfort_factor, 0, 1)
p_take_better = FIDELITY_MAX * fidelity          // 0 at squalor, FIDELITY_MAX at best
```

This is the mechanism §5.6 promises and never specifies. It makes the Works economically load-bearing for a player who never fights, and it is undirected by design — it improves outcomes generally, it does not let you aim.

**Line designation.** A rite or item naming one parent as **the line**. Crossover shifts from 50/50 to `LINE_WEIGHT` in her favour across all loci for that breeding.

```gml
p_from_designated = LINE_WEIGHT      // else (1 - LINE_WEIGHT)
```

Directed but coarse — it aims at a whole parent, never a specific gene. That distinction is deliberate: locus-level locking would reduce breeding to a documented procedure, which is what happened to the systems that offer it.

**Both levers are visible in the appraiser at expertise tier 2+.** A novice breeds in a good nest without knowing why it helped.

---

## 6. Feature expression gates

A locus can be **carried** by any creature but only **expressed** when the phenotype supports it. An art constraint made diegetic.

**The full gate and inheritance table is Appendix C.1** — all 16 features, their anchors, variants, and gates. Do not duplicate it here; the earlier inline table drifted out of sync and was removed in v0.7.

**This is the core motive for bridging.** A serpentine creature can carry a horn allele indefinitely. Moving that horn onto a creature that can display it requires both the compatibility work and the frame shift — a multi-generation project with a concrete emotional target: *that creature I don't like has the tusks I want.*

### Predicate budget

- ~60% of feature conditions reachable in 1–2 generations
- ~30% requiring one extreme value
- ~10% requiring two or more extremes — chase content

---

## 7. Behavioral traits

**30 at v1**, in four families — Psychological, Sense, Social, Physical. Full tables in **Appendix C**.

Traits are not sorted into separate genetic/learned/acquired lists; each carries **origin flags** (Inherit / Learn / Acquire / Remove), a **frequency tier**, and an optional **variant**. See C.0.

*(The genetic/learned split lists that stood here through v0.6 were from the abandoned 20-trait set and were removed. Appendix C is the only trait authority.)*

Negatives matter as much as positives — "I love her but she's a nightmare in the pen" is real texture, and gives breeding something to breed *out*.

### 7.1 Nesting disposition

**A trait with two variants, not a separate system** — `nesting_disposition` with variants **Solitary** and **Communal**. Non-expression is the neutral case (indifferent), which is also the majority outcome at the density in C.0. Most animals don't mind who they live with; some strongly do.

- **Solitary**: penalty per nestmate, bonus alone. **Carries a real upside** (better foraging, superior stress resistance when housed alone) or players breed it out.
- **Communal**: gains with nestmates, suffers alone.
- **Not expressed**: flat.

Housed in the Social family. Being heritable is the point — a Communal line is the player's structural answer to facility overload (§15.3).

### 7.2 Learning window

Behaviors are learned **during the juvenile stage only**. Elders can re-teach (see Mentoring). This gives the juvenile stage a purpose beyond waiting, and it lands when bond is lowest and care pressure is sharpest.

The juvenile window's length is **species-dependent** via `maturity_rate` (§12.1) and shifted further by Precocious and Late Bloomer. A fast Newtling passes through in under a fortnight; a slow Draik spends a season and a half there and is correspondingly more teachable. The season a creature grows up in therefore shapes what she learns, and how much of the year it covers depends on what she is.

### 7.3 Fixation

A learned behavior can become genetic across generations. If a creature learns X and both parents expressed X, its offspring have a chance to be *born* with X as an allele.

- **Weak/modest behaviors:** fixate readily over several generations
- **Strong behaviors:** fixate very rarely, as a special event

Biologically nonsense, emotionally correct. The long game is cultivating a **culture** in your herd — a bloodline that raises its own young properly because its ancestors were taught to.

**Guardrail:** strong behaviors must stay largely learned, or the endgame is a self-running herd and the care loop evaporates.

---

## 8. Compatibility and bridging

### 8.1 Distance

```gml
d = 1.5*|metabolism_diff| + 1.0*|integument_diff| + 1.5*|frame_diff|
  + 0.75*|element_diff|    + 0.5*|temperament_diff|
// Term order matches the worked examples in B.2. Weights: met 1.5, int 1.0, frm 1.5, ele 0.75, tmp 0.5.
```

**All five axes appear, and the weights are ordered by how hard each is to bridge.** Frame and metabolism are the deepest biology — a serpentine ectotherm and an upright endotherm are barely the same kind of animal — so they carry 1.5. Integument sits at 1.0. Element at 0.75 and temperament at 0.5 are the softest: palette and personality bridge easily. Total possible distance is 31.5.

Computed on **expressed** values only. Carried recessives don't affect compatibility.
**Threshold:** compatible if `d <= 8`. Biology is harder to bridge than personality.

### 8.2 Species labelling and naming

**Species radius R = 3.** Roughly a tenth of the total distance range, and well inside the compatibility threshold of 8.

- Within radius **R** of an archetype → that species name
- Outside every archetype → **strain**, auto-named `FrameArchetype × IntegumentArchetype`, player-renameable

At R = 3 an archetype claims a small neighbourhood — a creature two steps off on temperament and one on element still reads as her species, but three steps of frame drift does not. **Most creatures land in unclaimed space**, which is intended: with 19 archetypes across ~16,800 phenotypes, Do not force nearest-neighbour labels. Unclaimed space is where bridge creatures live, where the rarest combinations fire, and where player-named strains become worth showing off.

### 8.3 Seeding

15–20 archetypes. Place so no two are more than ~3 bridging generations apart, and at least one archetype sits near each extreme on every axis — otherwise extreme alleles have no entry point into the gene pool.

---

## 9. Size and growth

```
ceiling  = f(frame, mass_tendency)     // genetic, fixed at birth
maturity = g(age_days)                 // ranch clock, caps progress
realised = ceiling * maturity * care_score
```

Age caps reachable size; care determines how close you get; genetics sets the ceiling.

Mass raises Vitality and Power, lowers Celerity and Acuity. Size is never a strict upgrade.

`mass_tendency` is a **size input, not a stat aptitude** — it is consumed here and nowhere else. It was moved out of the aptitude block in v0.6 so that every aptitude does exactly one job.

---

## 10. The calendar

**Year = 4 seasons × 20 days = 80 days.**
**Season = 4 weeks × 5 days.** One week is one moon phase.

The calendar is load-bearing: birthdays, deathdays, festivals, tournaments, and events all anchor to it.

### 10.1 Seasons

**the Thaw · the Bloom · the Fade · the Hollow**

Environmental values shift predictably along them, so players can plan.

### 10.2 Weeks (moon phases)

**Waxing · Full · Waning · Dark**

The **Dark** carries real weight: mutation chance rises, certain rare creatures appear in the wilds, and some behaviors are more readily learned.

### 10.3 Days — the five guardians

Days are named for the deified guardians of the shrine. Domains colour events and dialogue, and **some rites and events are day-bound**.

**What days may gate:** shrine rites, festival content, certain commissions, and specific events. **What days may never gate:** ordinary play — daily care, breeding, selling, training, travel. A player who ignores the calendar entirely must never be blocked from the core loop; a player who reads it gets access to things the others don't.

This is the change that makes the five-day week mechanically legible. Until now the week had names and no consequences.

**Required: the calendar surfaces upcoming day-bound opportunities.** Days are weighty and a missed window can cost up to five days of waiting. Missing a rite because you didn't know it existed is not difficulty, it's a UI failure.

| Day | Aspect | Domain |
|---|---|---|
| **Alden** | the First Keeper | Beginnings, hatching, new arrivals |
| **Ysra** | the Gentle Hand | Care, healing, patience |
| **Corin** | the Wandering | Journeys, the wilds, returning |
| **Vesh** | the Bargainer | Trade, exchange, obligation. Traders restock. |
| **Thorne** | the Last Watch | Age, endings, the grove |

When a creature ascends (§12.5) she becomes a **new aspect venerated at the shrine**, standing beside the five. The week stays five days; the shrine gains a name that wasn't there when you arrived.

**Date format:** `Thorne, Waning of the Bloom, Year 4` — compact form `Bloom 15, Y4`.

### 10.4 Festivals — 18 days of the year

| Season | Festival | Days | Character |
|---|---|---|---|
| **Thaw** | **Firstthaw** | 1 | New year. Eggs, beginnings, fresh trader stock. *Atmospheric.* |
| | **The Stirring** | 3 | Waking of the world. Mild breeding blessing. |
| **Bloom** | **Wildsday** | 1 | Celebration of the wild. Wild creatures approach the sanctuary. *Atmospheric.* |
| | **Moondark Vigil** *(Dark)* | 3 | Strangeness at its peak — mutation, rare appearances. |
| **Fade** | **The Shedding** | 2 | Byproduct harvest. |
| | **The Gathering** | 5 | Harvest and the annual championship — heats, semis, final. |
| **Hollow** | **Founding** | 1 | Sanctuary anniversary. Lore about the previous caretaker surfaces. *Atmospheric.* |
| | **Hollownight** *(Dark)* | 2 | Gifts, creatures brought in from the cold, the grove lit. Deep bond gains. |

**The Gathering** commits the player to a dense competitive block — the competitive path's equivalent of a dungeon run, once a year, prepared for all year.

**Hollownight** is the memorial system's warmth: the one night the grove isn't sad.

**Founding** is the lore delivery mechanism — once a year the sanctuary's own history advances without exposition.

---

## 11. Weather

No new machinery — weather is a fourth term on the existing environment equation.

```
effective = place_base + season_shift + weather_shift + nest_modifiers
```

### 11.1 Daily weather

| Weather | Moisture | Warmth | Shelter | Common in |
|---|---|---|---|---|
| Clear | – | +1 | – | Bloom |
| Overcast | – | – | +1 | any |
| Rain | +2 | −1 | – | Thaw, Fade |
| Downpour | +3 | −1 | −2 | Fade |
| Fog | +1 | – | +1 | Thaw, Fade |
| Gale | – | −1 | −3 | Fade, Hollow |
| Frost | −1 | −3 | – | Hollow |
| Snow | +1 | −3 | −1 | Hollow |
| High Sun | −2 | +3 | – | Bloom |

**Shelter is load-bearing** because nests provide it — making nest investment continuously relevant rather than a one-time sorting exercise.

Weather also shifts foraging yields, modifies adventure conditions, gates a few rare creatures, and changes what a working trial tests.

### 11.2 Severe events

One or two per season, multi-day, mapped to places so housing decisions carry long-term risk.

| Event | Season | Threatens |
|---|---|---|
| Flood | Thaw, Fade | The brook and low ground |
| Wildfire | Bloom | The meadow, dry places |
| Gale | Fade, Hollow | Structures, exposed nests |
| Hard Frost | Hollow | Cold-vulnerable creatures anywhere |
| Blight fog | Fade | Illness, stress, foraging shut down |

Severe events **shut down most normal actions for the day** and spawn an emergency scenario — battening down, moving creatures to shelter, comforting panicked animals, fighting a flood. A storm day is a *different kind of day*, not a modifier on a normal one.

**Design principle: emergencies reward preparation, not reflexes.** A prepared ranch has a manageable emergency; an unprepared one has a scramble. The value sits in Stormsense, forecasting, and infrastructure — not thumb speed.

**Stakes:** lost comfort, lost progress, damaged structures requiring Works repair, occasional injury. Creature death from weather should be vanishingly rare or absent — death is built to be slow and foreseen-but-unpredictable, and a bad roll killing a beloved animal would feel arbitrary rather than sad.

### 11.3 Forecasting

A 1–3 day forecast, improved by a weathervane facility, expertise, or a creature with the **Stormsense** trait.

**Advance warning unlocks preparation actions unavailable without it** — boarding structures, moving creatures, stocking feed, securing the nursery. A weather-sensing creature is therefore infrastructure, and players will breed for her deliberately. Weather feeds the genetics system rather than sitting beside it.

---

## 12. Life cycle

### 12.1 Stages

Incubation → Hatchling → Juvenile *(learning window)* → Adult *(fertile)* → Elder *(mentoring)* → Degradation → Passing

**Lifespan range: 120–240 days (1.5–3 years).** Wide diversity by species and individual.

**Maturity is a separate species value from lifespan.** Each archetype carries `maturity_rate` — **fast / standard / slow** — which scales the pre-adult stages independently of how long she lives (Appendix B). A fast archetype is fertile in a fortnight; a slow one takes a season and a half. Without this, every species has a proportionally identical childhood and short-lived archetypes are merely animals that die sooner rather than genuinely faster breeders.

```gml
pre_adult_days = lifespan * (HATCHLING_PCT + JUVENILE_PCT) * maturity_mult
// maturity_mult: fast 0.6, standard 1.0, slow 1.6
```

`maturity_rate` also sets the **stat approach rate** (Appendix E.4) — one value governs how fast she grows up and how fast she becomes what she is capable of. A Draik lost early never showed you what she was.

| Stage | % of life (average case) | At 160 days, standard |
|---|---|---|
| Incubation | 2–5 days by rarity/type | 3 |
| Hatchling | 6% × maturity_mult | 10 |
| Juvenile *(learning window)* | 12% × maturity_mult | 19 |
| Adult *(fertile)* | until fertility ends | ~93 |
| Elder *(mentoring)* | remainder, ~25–45% | ~38 |
| Degradation *(tail of elder)* | last 5% | 8 |

**Adulthood ends when fertility ends** (§12.4). The stage percentages above are averages, not fixed boundaries: a creature with a long fertile span has a short retirement, one who stops early has years of mentoring ahead of her. The breeder wants the first; a player cultivating a herd culture wants the second. Same number, read two ways.

**Gestation scales with species and `maturity_rate`** — 3 days fast, 4 standard, 7 slow. Fixed gestation was a v0.6 holdover that undercut the maturity system: a Draik carrying as fast as a Newtling erases the identity `maturity_rate` exists to create. Short-lived, fast-maturing archetypes now turn generations much faster in absolute terms as well as relative to their own lives.

Species range: short-lived archetypes ~120 days (6 seasons, fast turnover, good breeding stock), long-lived ~240+ (12+ seasons, companion material, where the deification arc lives).

### 12.2 Lifespan formula

```
lifespan = species_base
         × longevity_alleles     (0.8 – 1.3)
         × care_history          (0.7 – 1.15, lifetime stress and fatigue)
         − injury_accumulation
         + life_event_modifiers  (rare)
         × hidden_variance       (±10%)
```

Hidden variance means the player can never compute the date, only estimate it.

**Exceptional longevity** arises from a rare dedicated allele *plus* luck, not either alone.

### 12.3 Injuries

**Most injuries are treatable and fully reversible.** Treated promptly and properly, an animal recovers with no lasting cost. Permanence is earned, not automatic — and that makes *care* the variable rather than luck.

Permanence arrives from four sources:

| Source | Becomes permanent when |
|---|---|
| **Untreated injury** | Left without treatment long enough to set |
| **Repeated injury** | The same region injured again and again — accumulation, not any single event |
| **Catastrophic injury** | A small set of named, severe injuries that scar regardless of treatment |
| **Curses** | Their own category, removed only by rite |

A permanent injury becomes a **chronic condition**, and it is chronic conditions — not injuries as such — that reduce expectancy.

**Inherited conditions are separate and are always permanent.** Weak Heart and the rest of Appendix D's defect pool come from the genome, not from the field. Treatment manages them; nothing cures them. That distinction matters: the adventurer's animal is damaged by her life, the inbred animal was damaged before she was born, and the player should never confuse the two.

This still prices the adventure path — but on judgement rather than dice. The breeder's animals were never at risk. The adventurer who treats her animals properly keeps them; the one who pushes on through accumulates permanence. **And the near-fatal injury that earns an overshoot (E.6) is exactly the kind that leaves a mark** — the breakthrough and the scar come from the same day.

Healers, the shrine, and restorative items acquire real weight from this.

### 12.4 Fertile span

```
fertile_fraction = species_base (0.55–0.75)
                 + trait_modifiers (±0.10)
                 + individual_roll (±0.05)
```

`fertile_fraction` is measured from the end of the juvenile stage, and **its end defines the adult/elder boundary** (§12.1). This is the single definition of the fertile span; the fixed 58% figure that appeared in the v0.6 stage table was a second, conflicting one and is gone.

**Sex is part of the genome and gates breeding** (Appendix C.9).

**Fertility varies by species, derived from `maturity_rate`:**

**There is no lifetime clutch quota.** Breeding is limited by a **recovery period** between clutches, so clutches fill whatever fertile window a creature has. The v2.6 flat quota (5 / 3 / 2 per life) produced an absurdity: a slow archetype with ~155 fertile days and 2 clutches sat idle roughly 75 days between them.

```gml
recovery_days = RECOVERY_BASE[maturity_tier]
              / care_score          // well-kept animals recover faster
              / fecundity_mult      // the aptitude's new job
```

| Maturity | Recovery base | ≈ clutches at good care | ≈ at poor care |
|---|---|---|---|
| Fast | 15 days | 5 | 2 |
| Standard | 20 days | 4 | under 2 |
| Slow | 35 days | 4 | under 2 |

**Care is the lever, species is the floor.** Care swings throughput by more than double across its range, which is a direct reward for the care loop. But a species base sits underneath it: without one, care-only scaling hands the volume crown to slow long-lived species and inverts B.3's workhorse identity. Fast archetypes stay ahead on both counts — more clutches *and* far faster generation turnover.

**`fecundity` now shortens recovery** rather than modifying a clutch count that no longer exists. Appendix D's fertility defects lengthen it, or shorten the fertile window.

**Time and care are the binding constraint, not an abstract fertility counter.** Each clutch costs days of her fertile life, which is a more legible price than a hidden quota — and it means a neglected animal is not just unhappy, she is a slower breeder.

**A clutch is ONE offspring.** This was never stated through v2.5 and the tier-1 nursery's two egg slots wrongly implied otherwise — those are two *concurrent* pregnancies, not a clutch of two. One per clutch means 5 / 3 / 2 offspring across an entire life, which is the volume pillar 1 wants: creatures kept and invested in, not produced in bulk.

**Twins are the exception, and they are heritable.** A rare trait (C.5), expressing in roughly 2% of creatures, yields two offspring from one clutch. Rare enough to be a find, breedable enough to be a project.

Individual `fecundity` modifies within the species, and a few archetypes may carry an explicit override where their identity demands it.

This is what finally gives B.3's claim real backing: the short-lived fast-maturing species turn generations quickly **and** produce more per life, which makes them genuine workhorses of a breeding program rather than merely animals that die sooner. The counterweight is already in place — those same species reach lower stat ceilings and shorter lives, so they are poor companions and poor fighters. Good at making animals, bad at being one.

**Parents survive breeding** — they spend days and condition, not lives.

**Juvenile breeding is permitted and penalised.** A creature may be bred before leaving the juvenile stage, at a cost:

| Penalty | Effect |
|---|---|
| Gestation | × `JUV_BREED_GESTATION` — a young body carries slowly |
| Defect chance | + `JUV_BREED_DEFECT` |
| Offspring quality | × `JUV_BREED_QUALITY` |
| Reputation | patrons who notice disapprove |

The penalty is a flat rule; `maturity_rate` decides how long a creature is exposed to it. A fast archetype passes through the penalised window in days and effectively never needs it; a slow one sits in it for weeks and cannot be rushed. Same mechanic, entirely different species feel, no special-casing — and it cuts a three-generation bridging project through fast stock from roughly 110 days to 55.

### 12.5 Retirement

**Retirement is the player's decision, not automatic.**

Disposition bias is a **trait with two variants** (`working_disposition`, Psychological family), not a separate field. Non-expression is neutral — she retires without complaint.
- **Steadfast** — declines in retirement, wants work
- **Restful** — degrades faster if worked past prime

Late retirement penalty is **mild**. **High bond acts as forgiveness** — she stayed because she wanted to.

Disposition is read through **bond and expertise combined** — bond gives the emotional read, expertise the clinical one, together the specific one.

**Retirement is not an ending.** Retired creatures mentor, steady their nest, and contribute behaviorally.

**Forestalling:** items and events extend the useful span. Players should never feel the life cycle is robbery.

### 12.6 Degradation and passing

Four descriptive stages — **Slowing, Frail, Failing, Ready** — visible on her sheet and legible in her idle posture.

**The decline is visible. The moment is not.** Passing is a **rising probability roll**, not a countdown. At Failing it might be tomorrow or three weeks hence. You know it's coming and never know when.

**Non-farmable by construction:** Keepsake quality scales with lifespan lived and bond depth, nothing shortens life to the player's benefit, and Ready cannot be induced.

**Accessibility:** a settings toggle makes the pasture permanent — creatures age out of usefulness but never pass.

### 12.7 Information

Lifespan is **never a number in the UI** — and that stays absolute. Precision arrives as dialogue, scaled to expertise:

| Expertise | What you hear |
|---|---|
| Novice | "She has many seasons yet." |
| Practised | "She's past her prime but strong." |
| Expert | "Three, maybe four. I'd start thinking about it." |

**The estimate is opt-in, and asking is a decision.** At high expertise the game may *offer* to estimate rather than volunteering it — the player chooses whether to know. Declining is a legitimate way to play, and the offer should be written so that it reads as a weight rather than a menu item.

**Escalating care hints replace numbers as she declines.** Where expertise is high enough, the game leans on tenderness rather than data: *"She's looking a little unsteady. If she's to keep pushing on much longer, she'll want extra care."* This carries the same information as a countdown without ever becoming one, and it points the player at an action instead of a date.

---

## 13. Legacy systems

### 13.1 The Keepsake

On natural passing, a one-use item guaranteeing one specific allele of hers into a future birth in her bloodline. The thing you loved about her is the thing she passes on.

### 13.2 The memorial grove

A visible, accumulating place — not a menu. Each marker carries a name, strain, and an epitaph generated from the creature's actual life.

**Effect:** creatures born on the ranch start with slightly higher base bond, scaling with the grove's size. Diegetic and unfarmable.

**The grove is already there when you arrive.** Weathered markers from the previous caretaker, names you don't recognise. You inherit someone else's grief before you earn your own, and the mechanic teaches itself on day one.

Deathday anniversaries anchor quiet events. Hollownight lights the grove.

### 13.3 Mentoring

**Eligibility:** the elder life stage, and nothing else. Since fertility now drives the adult/elder boundary (§12.4), "elder" already means past fertility — the old bond tier 4 gate is removed. **Bond raises Lesson quality**, it does not decide who may teach.

**Action:** elder and juvenile share a nest for a stretch of days.
**Effect:** the apprentice gains a permanent Lesson drawn from the elder's own life.

**Lesson capacity:**

```gml
lesson_cap(creature) = min(handler_tier, bond_tier)     // 1..5
```

An expert handler with a beloved animal is the only combination reaching 5; a novice with a market purchase gets 1. Both halves must rise, so capacity is a joint statement about the trainer and the relationship.

**Where the slots get filled.** §7.2 puts learning in the juvenile window, which is exactly when bond is lowest — so the window delivers her first Lesson or two, and **elder re-teaching fills the rest later** as bond and handler level grow. That makes re-teaching the late-game depth mechanism rather than a footnote: a creature's Lesson set keeps growing for as long as you keep investing in her.

**No elder-side limit.** An elder may teach as many apprentices as days allow. Matriarch / Patriarch (C.4) is a throughput advantage — several apprentices at once — not an exemption from a rule. The v0.6 limits of one Lesson per creature and one apprentice per elder were asserted without approval and are removed: §7.3's ambition is a bloodline that raises its own young properly, and both limits made that arithmetically impossible.

**Lesson or breakthrough.** Where the elder carries an overshoot (E.6), mentoring may transmit that instead of a behavioural Lesson — **the player chooses at completion**, and it consumes a Lesson slot either way. Overshoot transmission remains **once per elder**: behavioural Lessons scale with throughput, numeric breakthroughs never do.

**The detail that lands:** the Lesson carries the elder's name. *Maple's Patience* sits permanently on a living creature and nothing else in the world.

### 13.4 The lineage tree

The real collection artifact — not a species dex. Every creature raised, living and passed, connected. Passed creatures never leave it.

### 13.5 Deification

Late-game quests yield **legendary artifacts** extending life far beyond natural limits. Nothing lasts forever; the player must still make their peace.

A creature carried that far may, on passing, **ascend** — becoming an aspect that blesses the shrine and joins the five guardians in the sanctuary's veneration. A permanent ranch-wide boon, achievable perhaps once or twice in a long playthrough.

### 13.6 The Codex

An in-world tome of creature knowledge. **One page per species**, with personal sub-entries beneath it.

**The species page is official and scientific.** A painted plate of your designated model creature, encyclopedic description, lore, and the min–max ranges *you personally* have found, raised or seen for that species. It is the record of what the world knows and what you have proven.

**The sub-entries are personal.** One per individual of that species you actually raised — biographical rather than relational, recording what she did, what she was like, what she won, and how she went. Nostalgic by intent.

**This does not duplicate the lineage tree (§13.4).** The tree is *relational* — who descended from whom, what recurred through a line. The codex journal is *biographical*. Same animals, different axis; each links to the other.

#### Committing an entry

Hire a painter. The creature must be present and owned. **Each life stage is a separate entry** — hatchling, juvenile, adult, elder — so a complete page requires you to have kept an animal of that species across her whole life, or to have raised several.

**Grade mirrors her condition**: bond, health, and care at the moment of commitment. **Grade is normalised per life stage** — a bond ceiling that is unreachable at hatchling never penalises the hatchling entry. An S at that stage means *as good as a hatchling gets*.

**Depth reflects your expertise at commit time.** A page committed as a novice is thin; one committed at tier 4 carries gates, carried recessives, and full ranges. Re-raising a species better and re-committing improves both grade and depth — the replay hook.

**Re-committing costs a creature, not coins.** The painter's fee is trivial; the requirement is having raised an animal that good. Grade is therefore an honest record of your best work rather than a purchase.

#### The art: a painterly pass, not painted assets

The plate must reflect the individual's actual genome, which a pre-made per-species painting cannot do. So there are **no painterly codex assets at all** — the composite renders through a painterly treatment: canvas grain, brush-edge distortion, palette warmth, paper texture.

**Grade drives the treatment**, which yields grade-varying art for free:

| Grade | Treatment |
|---|---|
| D | Rough pencil sketch, unfinished, plain frame |
| C–B | Inked line work, flat colour |
| A | Full painted treatment |
| S | Masterwork — richer frame, gilt seal, painter's signature |

Nineteen species × four life stages × four grades is 304 distinct images at zero asset cost, each one a painting of the player's own animal with her own features at that age. This is the diegetic home for painterly art that §25 otherwise restricts to fixed assets.

**The plate depicts the individual, not the species.** Whatever she carries goes in — her fangs, her mane, her pinions, her heterochromia, her build, her palette — because the pass runs over her actual composite. Two players' pages for the same species will not match, and re-committing with a better specimen changes the subject as well as the grade.

**This means the plate is a specimen portrait, not a neutral reference — deliberately.** If the only Lupin you ever owned carried a recessive Pinion, your official-looking plate shows a winged Lupin. That is correct: a naturalist's tome is illustrated from the specimens its author actually had. **The encyclopedic text carries the species ranges; the plate carries the individual.** Do not later "fix" this into a generic species illustration — it would cost the page everything personal about it.

The phenotype gates (C.1) keep this from becoming absurd, since a species cannot express features its frame and integument disallow. Plates stay recognisable even when the individual is unusual. The composite renders from the 256px authored tier (§25), not the 64px world sprite.

#### Marginalia — the naturalist's annotations

**Unlocked by an S entry for that species *or* by high expertise.** Two independent paths, deliberately: the codex-filler arrives through grade, the reader arrives through study. Both playstyles reach it.

Once unlocked, the page annotates. Alongside your individual animal's traits it lists **what is typical for the species**, in two columns that are allowed to disagree:

| Column | Source |
|---|---|
| **The standard** | The association's written standard for that species — authored, static, and the thing a conformation judge scores against (§22) |
| **Observed** | The min–max ranges *you* have found, raised or seen |

**The disagreement is the point.** When your line's temperament sits outside what the association calls standard, that is either your bloodline drifting or the association's standard being decades out of date, and NPCs may hold opinions on which. The page raises the question; it never answers it.

**Traits outside the standard are tagged.** Two tiers:

| Tag | Source | Condition |
|---|---|---|
| *(unusual)* | Statistical | An axis value outside the association's standard band, or a feature rare for that species — but within what the species can naturally produce |
| *(unheard of)* | **Provenance** | A trait that could only have arrived by **bridging** (§8) — something the species does not have and could not produce alone |

**(unheard of) is not a rarity threshold; it is a lineage fact.** The game reads the lineage tree (§13.4) and sees the bridge. No tuning constant required, and the tag is honest in a way a percentile could never be: this animal carries something her species does not have, and the player put it there.

**This gives bridging projects their monument.** §8's ladder is the deepest long-term content in the design, and until now the only reward for completing one was owning the animal. The tome now records it permanently.

**The tag is permanent.** It never decays, never softens to *(unusual)*, and is not affected by how thoroughly the trait has been fixed in the player's own bloodline. The reference is the species and the association's standard, not your line — twenty generations of Lupins with membranous pinions are still twenty generations of Lupins that should not have them.

**Name the bridge where the lineage can trace it** — *"membranous pinions, out of the Draik line, four generations back."* §13.4 already holds that data, so the annotation costs nothing and turns a tag into a sentence worth reading. Where the animal was bought rather than bred, it reads *provenance unknown*, which is its own texture — and a reason to breed rather than buy.

**The generation count is what keeps permanence from diluting the brag.** Once a line is established, every animal in it carries the tag — so the tag alone stops distinguishing them. The sentence beneath it does not: *four generations back* reads very differently from *twenty-two generations back*. The first is a player who did the work; the second inherited it from themselves. Same tag, entirely different claim.

**The tags are neutral and must stay neutral.** No colour coding toward good or bad, no positive or negative framing. The association reads unusual as a flaw; a trainer may read it as the whole point. The moment the annotation editorialises, §22's central tension collapses into a right answer — and §22 exists precisely so an association-ugly animal can be the finest worker you ever raise.

Thresholds for both tags are tuning constants, not settled here.

#### Rewards

A four-rung ladder. Nothing game-breaking; much of it unsignposted. Players who never engage lose nothing structural.

| Rung | Condition | Reward |
|---|---|---|
| 1 | Any entry | Permanent reference — the gates, traits and observed ranges you knew when you committed it, consultable forever |
| 2 | All four life stages filled | The appraiser reads **that species** one tier deeper, free |
| 3 | High average grade | That species appears more often in trader stock and Board commissions |
| 4 | All stages at S | One singular hidden reward per species — a rite, a lore fragment, an artifact recipe |

Rung 2 does not violate §17.2 ("familiarity is never granted, only earned"): the bonus is earned by raising the animal well, and it cannot be bought. Rung 3 is a steering lever, not power. Rung 4 is discoverable, never signposted.

**This is a completionist layer for the players who want one**, consistent with the design's insistence that several playstyles are complete games. A mass breeder, a tournament fighter and a codex-filler are all playing Beasthollow correctly.

### 13.7 The starter egg

Found in the shrine garden beneath nest materials, beside mysterious remains — a parent who died bringing her egg somewhere safe.

**Tone: sacrifice and love, not reconstruction.** The parent *succeeded*. What accumulates is understanding, not an objective.

**Mechanically: observation, never a quest marker.** When a descendant is born carrying something she carried, the game notes it quietly — *she had this too.* No completion percentage.

---

## 14. Bond and affinity

**Bond** (creature ↔ player, 0–5). Raised by care actions. Gates **willingness**, never genome information.

| Tier | Unlocks |
|---|---|
| 1 | Willing to breed |
| 2 | Small offspring quality bonus |
| 3 | Reveals her *preferences* — foods, enrichment, penmates |
| 4 | Mentoring eligibility |
| 5 | Full-quality Keepsake; strongest retirement forgiveness |

**Affinity** (creature ↔ creature). Raised by shared nest time. **Phenotype distance affects growth speed, not the ceiling.** Well-equipped nests accelerate it.

**Parent affinity multiplies offspring quality.** A freshly bridged pair is compatible but barely acquainted, so their first offspring is poor. Distance costs generations *and* time, but nothing is ever permanently blocked.

---

## 15. Care, facilities, capacity

### 15.1 Care actions

Per creature, on the ranch clock: Feed, Groom, Play, Rest, Enrichment. **Effectiveness is gated by facilities**, not a shared action pool — the question is "can my ranch support this many animals well," not "who do I neglect."

### 15.2 Facilities

| Facility | Gates | T1 | T2 | T3 |
|---|---|---|---|---|
| Feeding trough | Fullness → size growth | 6 | 9 | 16 |
| Grooming station | Bond gain | 6 | 9 | 16 |
| Enrichment yard | Affinity, stress relief | 6 | 9 | 16 |
| Nursery | Gestation, hatch quality, egg capacity | 2 | 5 | 9 |
| Weathervane | Forecast range | — | — | — |

Cost roughly triples per tier. Duplicates buildable where plots allow.

**Tier 1 is 6, matching the starting roster cap of 6** (§15.4). At the previous value of 4 a new player ran at 0.67 effectiveness from the moment they filled their roster, permanently, in the first hour — the soft cap biting before they had any means of responding to it. The T1→T2 step is now compressed (6→9); if that reads as weak, the alternative is 6 / 12 / 20 rather than reverting T1.

### 15.3 Overload

```gml
effectiveness = clamp(capacity / population, 0.4, 1.0)
```

**Lowest-bond creatures absorb degradation first** — the least settled animal suffers most, inadvertently rather than by intent. The 0.4 floor prevents spirals.

**Settling-in grace** protects new arrivals, scaling with facility tier: T1 = 3 days, T2 = 5, T3 = 8.

**The intended fix is breeding, not micromanagement.** Share Food and similar behaviors redistribute care to the lowest-bond creature in the nest. Seed at least one caretaking behavior into starter or early trader stock so the answer exists before the player can breed it.

Facility load *is* overcrowding. No separate overcrowding penalty.

### 15.4 Three capacity systems

| Capacity | Limit | Governed by |
|---|---|---|
| **Party** | 1–3 companions who journey with you | Handler level, story |
| **Ranch roster** | Total housed | Hard cap from built enclosures; soft cap from facility capacity |
| **Egg capacity** | Unhatched eggs | Nursery tier |

Egg capacity throttles breeding throughput independently of adult roster — a player can't flood the ranch with clutches just because they have space.

| Stage | Roster cap | Typical tier |
|---|---|---|
| Start | 6 | T1 (6) |
| Early | 10 | T1→T2 |
| Mid | 16 | T2 (9), duplicates |
| Late | 24 | T3 (16) |

**Pastured creatures don't consume capacity.**

### 15.5 Helpers

Hired hands raise effective care capacity for **recurring wages**. Together with feed costs, this gives the economy a continuous outflow — the only thing that turns an accumulating coin pile into a decision.

Keep the pressure mild. A cozy game shouldn't have payroll anxiety.

Helpers also enable the **farm-sitter** role (§20).

**One UI requirement:** a ranch-load panel showing all facilities as X/Y with effectiveness percentage.

---

## 16. Places, nests, seasons

### 16.1 Places

Named regions of the sanctuary — the quiet brook behind the shrine, the meadow down the hill, the stone hollow, the old orchard. Not abstract pen types.

Each carries three environmental values on the 0–6 scale: **moisture, warmth, shelter**.

The plots you reclaim *are* the habitats. Clearing the brook isn't unlocking a wetland pen; it's uncovering the brook.

### 16.2 Nests

Built *within* places, and they **moderate** them — a burrow adds shelter, a basking stone adds warmth, a wallow adds moisture. Each shifts a value by up to **±2**: enough to fix a moderate mismatch, never enough to turn the brook into a desert.

**Exceptional nests exceed the cap.** A hothouse, an ice-house, a deep wallow — rare, **recipe-gated Works projects** rather than purchases, and restricted to appropriate places. This keeps ±2 as the ordinary ceiling while letting a fully restored sanctuary reach conditions the wild ground never offers. It matters beyond comfort: nest warmth drives the ectotherm sex bias (C.9) and comfort feeds inheritance fidelity (§5.7), so habitat range is breeding depth.

```
comfort = distance(creature_preference, effective_environment)
```

Preference derives from phenotype, chiefly integument and metabolism. Serious mismatch means steady stress, never a hard block.

Nest materials come from foraging.

**Nest warmth biases offspring sex for ectotherm species** (Appendix C.9) — making nests a breeding tool, not only a comfort system.

### 16.3 Seasonal effects

Seasons touch **everything**: comfort, foraging yields, breeding, growth rates, aging.

**Birth-season imprint.** A hatchling's birth season permanently shifts its comfort preference toward those conditions, and **biases the trait frequency tiers** for that birth (C.0) rather than naming specific traits.

```gml
// Each season promotes one family's tiers by one step and demotes another's
// e.g. the Hollow: Physical +1 tier, Social -1 tier
```

Biasing tiers rather than listing traits means the imprint keeps working as the trait pool grows past 30, and it never hard-codes a season to a trait that might later be rebalanced or removed. Which family each season favours is an open tuning item.

**No season may be strictly best.** Each imprint is a tradeoff.

**Art constraint:** seasonal visuals must be **palette-driven** — one tileset per place with seasonal ramps applied via shader, plus a handful of props. Hand-authoring four versions of every place is how this project stalls.

---

## 17. Expertise

```gml
insight(creature) = max(handler_level, familiarity[nearest_archetype])
```

For hybrids: familiarity is the **average of the two nearest contributing archetypes, rounded down**. Where more than two contribute, use the two nearest.

### 17.1 Handler level

The floor across all species. Rises from **cumulative experience across milestones, commissions, and achievements**.

**Tier conversion requires XP *plus* a specific accomplishment.** The grind gets you ready; the accomplishment makes it real.

### 17.2 Species familiarity

Per-archetype, can exceed the floor. Earned **only through acts involving that species** — hatching, raising, appraising, breeding within it, and completing species-specific quests.

**Rule: familiarity is never granted, only earned.** It must never become purchasable.

### 17.3 What expertise reveals

| Tier | Reveals |
|---|---|
| 0 | Species or strain name, size |
| 1 | Expressed axes as words |
| 2 | Expressed axes as numbers |
| 3 | Carried recessives — axes, trait loci, and **carried defect alleles** |
| 4 | Predicted compatibility distance between any two creatures |

Tier 3 is the inflection point: before it, breeding is folklore; after it, engineering.

**Strains stay mysterious.** Because familiarity averages down for hybrids, unclaimed phenotype space is genuinely harder to read no matter how expert you become.

---

## 18. The Board — commissions

Generated from the player's **capability envelope** (phenotypes reachable within ~1–3 generations of owned stock), mixed with fixed difficulty tiers. The player opts into difficulty for scaled rewards.

One persistent **stretch commission** sits on the board at all times: deliberately beyond current reach, no expiry.

### 18.1 Rewards

**Reward type follows the patron, not the difficulty.** Anonymous board postings pay goods, materials and handler XP. Named patrons pay according to who they are — a lord pays coin, a trainer pays tuition and species quests, the steward pays deeds, townsfolk pay money. Money at high difficulty therefore always arrives with a relationship attached, which feeds §18.3's moral weight rather than sitting apart from it.

The v0.6 rule ("money is never the reward for hard commissions") was too absolute: helper wages and feed are recurring outflows, and a late-game ranch running twenty-four creatures with hired hands needs a coin faucet proportional to its costs.

| Tier | Pays |
|---|---|
| Simple | Money, small XP, common materials |
| Standard | Money, XP, nest materials, facility parts, occasional blueprint |
| Demanding | Large XP, blueprints, deeds, trainer introductions |
| Rare commission | Legendary artifacts, unique materials, rare wild eggs, archetype unlocks |

Every tier pays handler XP — the Board is the primary handler-level faucet.

### 18.2 Patrons

A **mix of named NPCs and anonymous posters**. Named patrons recur, pay distinct reward types, and carry relationships: the land steward pays deeds, a trainer pays tuition and species quests, townsfolk pay money, lords and kings pay extraordinarily for perfect or unique animals.

### 18.3 Moral weight

Selling and placing creatures carries consequence. Buyers differ — some kind, some cruel, some criminal. Refusing a lucrative sale costs money and earns something else.

Placements have **emergent consequences**: a destructive beast sold to criminals may surface in later crime events; a creature placed well may return as a story. Monster Rancher's event system is the reference, but deeper, dynamic, and emergent rather than a fixed table.

---

## 19. The Works — restoration

Inward-facing projects: clearing plots, repairing pens, raising facilities, repairing storm damage.

**Two gates on expansion:**
- **Deeds** — permission, earned through commissions
- **Clearing** — labor, paid in days and money

A commission grants the right and the blueprint; the Works spends money and days to realise it.

### 19.1 Materials

| Category | Source | Feeds |
|---|---|---|
| **Forage** | Foraging — fibres, reeds, stone, hide scraps | Nests |
| **Salvage** | Clearing plots — timber, fittings, ironwork | The Works |
| **Rare** | Deep wilds, stretch commissions | Unique nests, artifacts, Charms |

### 19.2 Crafting

**Recipe knowledge is a progression layer; components are the cost.** Everything crafted consumes ingredients. Basic nests and repairs are known from day one; better nests, Charms, Tinctures and tools arrive as blueprints from commissions, trainers and the wilds; artifacts additionally need a rare component and the shrine.

**Depth: 2 steps above base materials, 3 for artifacts only.** Base materials are foraged, salvaged or harvested — never crafted.

Depth alone is not what ruins crafting games; depth plus friction is. The Graveyard Keeper failure mode is a chain gated behind separate machines you don't own yet, many chains needed at once, and no in-game guidance. Three structural guardrails, which matter more than the depth number:

1. **One crafting surface.** The Works bench does everything; the shrine handles rites. No per-station unlock chains.
2. **Craft-through.** Selecting a finished item expands to base materials and performs intermediate steps automatically where the player holds the components. Depth stays invisible until someone wants to see it. This is the affordance that makes the system viable on a phone.
3. **A small shared intermediate pool** — 6–8 total, reused across many recipes. Never one bespoke intermediate per output. This is what stops the pyramid.

---

## 20. Acquisition and adventure

### 20.1 Sources

**Wild capture and traders both**, wild stock rarer. Outcrossed stock is essential (§5.5) — the trader and the wilds are the release valve on inbreeding.

**Wild and traded creatures arrive at varied ages, including elderly.** Thematically exact for a sanctuary, and it means a player experiences the full life arc — bonding, mentoring, degradation, passing, a marker in the grove — within a few hours rather than after thirty. It also creates a genuinely affecting early decision: you find an old animal in the ruins with perhaps a season left. Do you take her in anyway?

### 20.2 Foraging

- *Creature-sent* — costs days and fatigue; yield scales with traits (chiefly **Keen Nose**, which absorbed the old Foraging Sense). You continue other work.
- *Player-led* — costs your day, but you see what's there and choose, and may bring one creature whose traits open options.

Reachable wild areas are gated by cleared plots, so acquisition grows out of ranch progression.

### 20.3 Adventures

Multi-day expeditions into biomes with your party of 1–3. **Not time compression** — adventure days are the *densest* days in the game, with active combat, exploration, and encounters. A single adventure day may take longer to play than a ranch week.

While away, the ranch tick still runs, resolved by a hired **farm-sitter**. This is delegation, not fast-forward — you return to consequences. A cheap hand does a poor job.

Adventures yield experience, rewards, materials, rare stock, and deep bonding — and risk injury. Most injuries are treatable; untreated, repeated, or catastrophic ones become chronic conditions that cost lifespan (§12.3).

The farm-sitter cost is the structural difference between the paths: the breeder's farm runs smoothly because they're always there; the adventurer pays for absence and gets what the breeder can't reach.

---

## 21. Economy

**Inflows:** commissions, trials and tournaments, creature sales and placements, byproducts.

**Byproducts** — shed scales, moulted fur, down, gathered materials. Yield and type derive from phenotype, mostly integument and element. This makes the high-roster path economically real: a rancher with twenty-four creatures earns steady passive income; a specialist with six earns from commissions and trials. Diverse stock has value beyond breeding, quietly supporting the outcrossing the inbreeding system requires. **The Shedding** is this system's festival.

**Reputation** — a well-known creature raises standing and attracts better commissions passively.

**Outflows:** Works projects, facility tiers, helper wages, feed, nest materials, healers, storm repairs.

Recurring costs matter: without them money only accumulates and never becomes a decision.

---

## 22. Divergent paths

Two complete games sharing one genome.

**The Breeder / Shower.** Lineage work, deep reading, trials, sales to lords and associations. Values phenotype purity, rare expressions, association standards. Animals live longer because they were never at risk.

**The Handler / Adventurer.** Working companions, exploration, battle, artifact hunting. Values aptitudes, behavioral traits, resilience. **An animal an association would call ugly may be the finest working companion alive** — and NPC reactions and trial results must say so out loud.

Neither is a subset of the other. Both must fund a ranch, raise handler level, and reach the late game.

### 22.1 Trials and shows

**Working trials, not pageantry** — Schutzhund rather than Crufts. Tracking, obedience, protection, retrieval, endurance. Conformation is one association discipline among many and explicitly *not* the measure of a good animal.

Trials read from the same genome and stats as everything else. No bespoke show stats. Discipline weightings are in **Appendix E.7**.

**The Gathering** (§10.4) is the annual championship.

### 22.2 Deferred but designed-for

Combat, expeditions, and the full trial circuit are post-v1. Nothing here may require rework to accommodate them: every activity is a different **weighting of the same numbers**.

---

## 23. Ranch clock

Day-based. The player acts freely, then presses **End day**.

**Days are weighty.** A day should contain enough that playing it is worth it — the design does not rely on skipping.

| Action | Days |
|---|---|
| Gestation | 4–5 |
| Incubation | 2–5 by rarity |
| Appraisal | 1 |
| Foraging | variable |
| Mentoring | a stretch of days |
| Adventure | multi-day, densest play |

**Daily RNG events** ride on top of festivals — weather, encounters, visitors, small incidents. Season-weighted.

---

## 24. Presentation

| Tier | Content |
|---|---|
| **Ranch view** | Top-down, walkable, directional movement. Creatures wander. Stations open menus. |
| **Creature view** | Close-up in the same renderer — her actual nest, season, and weather, shallow depth of field. Idle animation, tap parts to inspect. |
| **System screens** | Menu overlays — breeding, appraisal, the Board, the Works. |

**The ranch view is fully walkable and creatures visibly live in it — but no mechanic is reachable only by walking.** Menu parity is guaranteed: everything doable in the world is also doable from a screen. Creatures wander, interact, react to weather, and are worth watching; emotional weight still sits in the creature view. The ranch expands as the player progresses.

The v0.6 wording ("no mechanic lives there") was too absolute and contradicted an approved system — §11.2's severe-weather emergencies are inherently spatial. The constraint that matters is not "nothing happens here" but "nothing is *locked* behind pixel-hunting on a six-inch screen," which also caps the animation budget pillar 7 warns about.

**Orientation: landscape, on both targets.** Portrait was a v0.8 assumption and it was wrong — nobody plays a game like this in portrait, and landscape is also the aspect the voxel-diorama presentation (§25) was designed around.

**Mobile-first, PC-up.** Design to the landscape phone safe area and scale up; a UI built for the constrained target converts upward cleanly, whereas a PC layout retro-fitted down to a phone does not. Build at 16:9 and allow horizontal bleed out to 20:9 rather than assuming a fixed aspect.

**What landscape buys this game specifically:** side-by-side comparison. A breeding game spends most of its time holding two animals against each other — parents at the nest, a purchase against the line you already own, an offspring against its dam. Portrait made that a paged flip; landscape makes it a single screen. Appraisal, the lineage tree, and the breeding screen should all be rebuilt around two-panel layouts.

**Costs of the change:** touch targets and text legibility still have to hold at five to six inches, so mobile remains the binding constraint on UI density. And the creature composite is now viewed at PC resolution, so the art has to survive a much larger presentation than a phone required.

### 24.1 Presentation is 2.5D

**The world is real geometry; creatures and characters are sprites standing in it.** Reference point is the Dramatic Shape voxel mod for the Gen 1 Recompilation Project — as a guardrail, not a target. Beasthollow is not bound by that mod's Game Boy constraints and should look considerably better.

**Three resolutions are decoupled.** The reference couples tile-art resolution, geometry resolution, and framebuffer resolution — its pixels are its voxels and its framebuffer is its pixel grid, which is why it cannot scale. Beasthollow separates all three:

| Dial | Setting |
|---|---|
| Texture resolution | Tile art at **32px**, nearest-neighbour filtered, no mipmaps |
| Geometry resolution | A **coarse height grid**, independent of art resolution, chamfered profiles |
| Framebuffer | **Native display resolution. Never upscaled.** |

**Geometry comes from a height grid, not per-pixel extrusion.** Per-pixel extrusion couples geometry to art and produces staircase artifacts on every curve. A coarse height grid with chamfered edges reads as form rather than noise, keeps triangle counts sane on mobile, and lets tile art get more detailed without geometry cost. Bake meshes at load, merge into chunks, cull interior faces.

**Sprites are z-tilted slabs, not billboards.** The corner-id vertex shader tilts sprites into the depth buffer, so occlusion is a z-test rather than a y-sort and the camera angle does not dispel the illusion. Alpha-discard, never alpha-blend. Snap slabs to the pixel grid so creature art stays crisp while geometry gains fidelity.

**The creature composite renders to a surface, then becomes one slab.** The ~30-part compositor (§25.1) is untouched by any of this.

### 24.1.1 Resolution and zoom

**Every scale factor is a whole number. This is the rule that prevents fuzziness.** Fuzziness in pixel art does not come from large screens; it comes from fractional scaling. A 32px tile drawn at 3.27× puts some source pixels on 3 screen pixels and some on 4, so the grid goes lumpy — the "stretched and broken" look, and it happens at any resolution.

**Designed world height: 360 world-pixels.** Zoom is derived by integer division of the display height, which is why 360 was chosen — it divides 1080, 1440 and 2160 exactly.

| Device | Screen height | Zoom | World shown |
|---|---|---|---|
| Phone | 1080 | 3× | 360 |
| Tablet | 1600 | 4× | 400 |
| PC 1440p | 1440 | 4× | 360 |
| 4K | 2160 | 6× | 360 |

At 32px tiles that is ~11 tiles vertically on every device. Note what this achieves: a tile occupies three times as many *physical* pixels on a phone as in the source art, so the phone is effectively zoomed in for legibility — while the amount of world visible stays near-constant, so no device is playing a different game.

**Odd screen heights bleed, never letterbox.** 1179 ÷ 360 = 3.27, so round the zoom *down* to 3× and show slightly more world (the extent varies 360–440). Bounded variance, no black bars, never a fractional scale.

**Player zoom: one whole step, bounded by extent, not by direction.** The device sets the default and the player may nudge it a single integer step either way — but the *resulting extent* is capped at **480 world-pixels**, and that cap decides who can actually step out.

| Device | Default | Step in | Step out | Allowed? |
|---|---|---|---|---|
| Phone 1080 | 3× (360) | 4× (270) ✓ | 2× (540) | **No** — over the cap |
| PC 1440 | 4× (360) | 5× (288) ✓ | 3× (480) | Yes — exactly at the cap |
| 4K 2160 | 6× (360) | 7× (309) ✓ | 5× (432) | Yes |

Zooming **in** is always legal — it shows less world, so it can never confer an advantage, and it is the accessibility case that matters most on a small screen. Zooming **out** is the direction that breaks parity, so it is granted only where the screen is large enough to absorb it. A phone is already at its widest legal view by default; a large monitor gets the extra breathing room its size can justify. Nobody sees more than 480 world-pixels of ranch, ever.

**Other rules:**

1. **Clamped horizontal.** Width bleeds from 16:9 out to 21:9 and stops. Phones are often 20:9, so this rule mostly protects against ultrawide monitors revealing too much.
2. **Snap the camera to whole pixels.** Integer zoom alone is not enough — a fractional camera position makes sprites shimmer while walking. One line to add now, very hard to retrofit.
3. **Never rotate a sprite slab.** Rotation destroys pixel art at any scale. Fixed camera, fixed slab orientation.
4. **The UI canvas is a separate render target with its own scale factor, sized by physical screen size — not by world zoom.** A finger is the same size on every device. If buttons scaled with zoom they would be enormous on a phone and unusable on a monitor.
5. **Pixel font throughout, scaled by the same whole-number factor as the world.** Consistent with nearest-filtered textures, and it stays legible because it scales with the display rather than against it.
6. **Creature sprites scale by integer factors only.** The 256px authored composite displays at 2× or 4× rather than being re-authored per platform.
7. **Run fog and tilt-shift at half resolution.** Blur does not need native 4K, nobody can tell, and tablet-class GPUs will otherwise struggle. Convenient side effect: the tilt-shift blur sits exactly on the far plane where high-resolution aliasing appears, so the diorama effect is also the anti-aliasing fix.

**Post-processing, in priority order:**

| Pass | Why | Cost |
|---|---|---|
| Baked vertex AO | Contact darkening; the single biggest gain in solidity. Without it interiors read as slabs in a void | Free at runtime |
| Height fog + light colour | **Driven by season and weather (§10, §11).** The Thaw pale, the Bloom warm, the Fade amber, the Hollow blue and foggy; storms drop light and thicken fog | Cheap |
| Tilt-shift | Default, not optional — the miniature read is the diorama feeling a shrine-ranch wants | Cheap |
| Material shading | Matte foliage, rough stone, a real water surface with depth-based colour | Moderate |
| Shadow map | Deferred. Projected shadow quads suffice on flat ranch ground; real shadow mapping only matters once roofs and cliffs must receive shadows | Expensive in GameMaker |

**The atmosphere pass is the differentiator.** Season- and weather-driven lighting gives four distinct looks and a live weather response for no art cost at all, against a reference that has exactly one lighting condition. This is where "better looking" actually comes from — not from more geometry.

**No painted dioramas.** The creature view is a close-up in the same renderer. One visual language, no register clash between a painted backdrop and a voxel world, and the backdrop art budget disappears.

### 24.2 Input

**Directional movement is primary** — WASD and gamepad on PC, an on-screen stick on mobile. **Tap-to-move is retained as a secondary scheme**, not a platform split: one set of design assumptions, two ways to drive it. Splitting by platform would mean two interaction models to design and test, which is the failure this revision exists to correct.

**Consequence — interaction needs a facing model.** With directional movement the player no longer taps the object they want; they walk to it and act on what they're facing. That means a nearest-interactable prompt (Stardew-style), which is new UI the portrait design didn't need. Tap-to-move users get direct object tapping as before.

**Consequence — thumb zones.** In landscape the on-screen stick occupies the lower-left and the action button the lower-right. Nothing tappable may live in either zone, which constrains every HUD layout. Reserve them before laying out any screen.

---

## 25. Art pipeline

**Creatures are pixel art, fully composited, at multiple resolutions.**

**Author at 256px; downsample by exact integer factors** to 128 (inspection) and 64 (world). The 7 base bodies get a hand-touched 64px variant; trait parts do not.

**World sprite resolution determines how many traits are distinguishable.** Trait count and sprite size are the same decision.

### 25.1 Layer stack

1. Base body — by `frame` (7 assets)
2. Integument overlay — by `integument` (7 patterns, drawn to work on any body)
3. Palette shader — from `element` + `metabolism`
4. Feature parts — attached to **anchor points**; variant selects which part
5. Posture / eye overlay — from `temperament`
6. Scale transform — from realised size

**Anchor points** (head, jaw, spine, tail, limb) are defined per base body. Trait parts are drawn once against a canonical anchor and composite onto any frame. Without anchors, 16 traits × 7 bodies = 112 assets instead of 16.

**Estimated v1 budget:** 7 bodies + 7 overlays + ~30 feature parts + shared posture set ≈ 46 authored asset sets.

### 25.2 Generation discipline

PixelLab generation is viable — proven on Ironwake — under four rules:

1. **Lock the reference before generating.** Every part against one canonical base body, in batches.
2. **Define anchor pixel coordinates first, then crop to them.**
3. **Budget hand-cleanup on every part.** Generation yields candidates, not assets.
4. **Run a palette normalisation pass.**

**Painterly generation is for fixed assets only** — NPCs, backdrops, UI frames, the shrine. Never for composited creature parts.

**The codex plate is not an exception to this.** §13.6 applies a painterly *shader treatment* to an already-composited creature at render time. No painterly asset is generated, and no creature part is authored painterly. Generation and treatment are different things; the rule above governs the first and says nothing about the second.

### 25.3 Animation

What works: transforming the whole composite (breathing, sway, idle squash) and offsetting anchor-attached parts on a sine wave. What does not: hand-drawn frame animation, which would need authoring per body per overlay.

---

## 26. Onboarding and monetization

**Trial gate is progress-based** — free through first hatch. A timer punishes exactly the audience a breeding sim attracts.

Mechanism: free app, non-consumable IAP unlock. Verify current store requirements before building the billing path.

**First session, six beats, each teaching one system:**

1. Arrive. The sanctuary is overgrown. The grove is already there, with markers you didn't write.
2. Find the egg beneath nest materials, beside the remains.
3. Build a nest from what was there.
4. Advance days to incubate — teaches the ranch clock.
5. The caretaker reads the egg and can't tell you much — teaches that expertise exists and yours is nothing.
6. It hatches.

The starter egg needs shortened incubation to fit one session.

---

## 27. Naming

Title: **Beasthollow**. It signals genre (a browsing player sees "Beast" and knows creatures are involved) while remaining one ownable, searchable word.

Note: "hollow" appears in both the title and a season name (the Hollow) — treat as internal rhyme, and avoid compounding it further in place names.

Alternatives considered and set aside: **Kinhallow**, **Hollowbrook**, **Aldenwake**, **Brackenhollow**, **The Keeping**.

Whatever is chosen, pair an evocative title with a descriptive store subtitle — the title carries memorability, the subtitle carries search.

---

## 28. Influences

**Jade Cocoon** — size growth with maturity, emergent traits from merging.

**Monster Rancher (PS2 / GBA)** — Base × Sub two-slot species identity mapping onto frame/integument; compatibility charts governing bonding ease; parent friendship multiplying offspring quality; lifespan with stress and fatigue as inputs; monsters becoming stunted rather than dying; consequence events driven by treatment and decisions; market-day restocking.

*Avoid:* MR1/2's inverted combining math, where parents needed *less* of a stat to benefit offspring. Opaque inheritance is the failure mode.

**Mewgenics** — taken for systems, explicitly not for tone:
- Environment shapes the roll before genetics resolves
- Inbreeding coefficients producing defects, forcing continual outcrossing
- A hard ceiling on inherited values, exceeded only by mutation
- Information as a progression currency unlocked in discrete tiers
- RNG that deliberately prevents a perfect specimen in a short span

*Not adopted:* the cruelty, culling-as-core-loop, or the obscenity. Our equivalent of donating unwanted animals is placing them in good homes — moral weight rather than disposal.

**Harvest Moon / Stardew** — weighty days, player-directed investment in land and buildings, seasonal calendar, festivals.

---

## 29. Open items

- Foraging and mentoring durations
- Distance weight tuning against playtested bridging times
- Species radius **R**
- Emergency mini-game design
- Artifact and deification quest design
- Trial discipline content and difficulty curves (weightings settled — E.7)
- The association's written standard as a data structure — target value per axis, permitted band, correct and faulted features. Nineteen records, and a prerequisite for both conformation judging (§22) and codex marginalia (§13.6)
- The named catastrophic injuries that scar regardless of treatment (§12.3)
- Which rites and events are day-bound, and the calendar UI that surfaces them (§10.3)
- Which 6–8 intermediate goods the crafting pool contains (§19.2)
- Recipe unlock sources and pacing (§19.2)
- Exceptional-nest list and their place restrictions (§16.2)
- Named patron reward tables (§18.1)
- Consequence event system architecture
- Overshoot trigger content — which events, at which stages
- Herd Mother's gendered counterpart (Matriarch / Patriarch is a separate trait, not that pair)
- Which trait family each season promotes and demotes (§16.3)
- Economy baselines — prices and payouts
- Save structure and offline handling
- Whether elder stat decay should be trait-modifiable, and whether 0.2%/day reads as cruel
- Facility tier curve: 6 / 9 / 16 versus 6 / 12 / 20 (§15.2)

---

## 30. Tuning constants

```gml
#macro AXIS_STEPS            7
#macro COMPAT_THRESHOLD      8
#macro BLEND_CHANCE          0.10
#macro BLEND_MIN_GAP         2
#macro MUT_CHANCE_1          0.04   // per axis, per birth
#macro MUT_CHANCE_2          0.005
#macro TRAIT_MUT_CHANCE      0.002  // per locus, per birth
#macro RECOVERY_FAST         15
#macro RECOVERY_STANDARD     20
#macro RECOVERY_SLOW         35
#macro PASTURE_SLOTS_START   4
#macro DAYS_PER_WEEK         5
#macro WEEKS_PER_SEASON      4
#macro SEASON_DAYS           20
#macro SEASONS_PER_YEAR      4
#macro YEAR_DAYS             80
#macro SPECIES_BASE_MIN_DAYS 120
#macro SPECIES_BASE_MAX_DAYS 240
#macro LIFESPAN_HARD_CEILING 400   // safety net only — never a routine clamp
#macro GESTATION_FAST        3
#macro GESTATION_STANDARD    4
#macro GESTATION_SLOW        7
#macro CARE_FLOOR            0.4
#macro GRACE_T1_DAYS         3
#macro GRACE_T2_DAYS         5
#macro GRACE_T3_DAYS         8
#macro NEST_MOD_MAX          2
#macro PARTY_MAX             3
#macro INBREED_MILD          0.125
#macro INBREED_MODERATE      0.25
#macro INBREED_SEVERE        0.375
#macro TRAIT_COUNT           30
#macro FEATURE_LOCI          16

// Maturity — §12.1
#macro MATURITY_FAST         0.75
#macro MATURITY_STANDARD     1.0
#macro MATURITY_SLOW         1.4
#macro HATCHLING_PCT         0.04
#macro JUVENILE_PCT          0.10
#macro JUV_BREED_GESTATION   1.5
#macro JUV_BREED_DEFECT      0.10
#macro JUV_BREED_QUALITY     0.75

// Inheritance agency — §5.7
#macro FIDELITY_MAX          0.50
#macro LINE_WEIGHT           0.70

// Trait frequency tiers — C.0
#macro FREQ_COMMON           0.32
#macro FREQ_UNCOMMON         0.20
#macro FREQ_RARE             0.10

// Offspring sex — C.9
#macro MOON_SEX_BIAS         0.05
#macro DARK_MOON_SEX_BIAS    0.08

// Stats — Appendix E
#macro APT_MIN               10
#macro APT_MAX               100
#macro APT_BUDGET_BASE       330
#macro APT_BAND_HALFWIDTH    15
#macro APT_STRENGTH_LOW      0.88
#macro APT_STRENGTH_HIGH     1.12
#macro APT_DIFFICULTY_MOD    1.04
#macro APT_DIFFICULTY_HARD   1.07

// Combat — Appendix G
#macro HANDLER_DISTANCE_PENALTY 0.12
#macro PARTY_MAX_CREATURES      3
#macro STAT_COUNT            6
#macro CURRENT_START_PCT     0.25
#macro TRAIN_RATE            0.06   // base; divided by maturity_mult per species
#macro TRAIN_FLOOR_GAIN      0.4
#macro OVERSHOOT_STEP        0.06
#macro OVERSHOOT_MAX_STEPS   3
#macro MISREAD_ACUITY_PIVOT  55
#macro MISREAD_MAX_CHANCE    0.30
#macro ELDER_DECAY_PER_DAY   0.002
#macro BOND_FLOOR_RATIO      0.5

// Mentoring — §13.3
#macro LESSON_CAP_MAX        5

// Crafting — §19.2
#macro CRAFT_DEPTH_MAX       2
#macro CRAFT_DEPTH_ARTIFACT  3
#macro INTERMEDIATE_GOODS    8

// Features — §5.2
#macro FEAT_RECESSIVE_COUNT  11
#macro FEAT_DOMINANT_COUNT   5
#macro FEAT_FREQ_RECESSIVE   0.25
#macro FEAT_FREQ_DOMINANT    0.15
```

All numbers are prototyping baselines. Agree changes here before editing dependent code.

---

## 31. Difficulty

Three presets with custom sliders underneath. **Difficulty scales consequence, never the genome.**

### What never scales

- **Genetics.** Inheritance, mutation rates, trait frequencies, compatibility distances, inbreeding coefficients and their defect thresholds are identical at every difficulty. A Twinning line bred on Easy is the same achievement as one bred on Hard, and the codex, the lineage tree, and *(unheard of)* all keep meaning one thing.
- **The expertise ladder.** §17.3's reveal tiers are the same for everyone. Information is earned by study, not granted by a menu.
- **Handler death ends the run** at all three levels. Easy's protection is the save system, not immortality.
- **Lifespan.** Genetic-adjacent, and changing it would change the game's rhythm rather than its difficulty.

### The presets

| Parameter | Easy | Normal | Hard |
|---|---|---|---|
| **Saving** | Free from the menu anywhere except combat | Free from the menu anywhere except combat | **Autosave only**, after every resolved event that does not soft-lock |
| Creature death from injury | Never — she is retired, not lost | Deep places only | Anywhere dangerous |
| Untreated-injury grace | 5 days before chronic | 3 days | 1 day |
| `CARE_FLOOR` | 0.55 | 0.40 | 0.25 |
| Bond decay rate | ×0.6 | ×1.0 | ×1.5 |
| `BOND_FLOOR_RATIO` | 0.65 | 0.50 | 0.35 |
| Illness chance | ×0.6 | ×1.0 | ×1.4 |
| Prices and payouts | Generous | Baseline | Tight |
| Enemy strength and count | ×0.8 | ×1.0 | ×1.25 |
| `HANDLER_DISTANCE_PENALTY` | ×0.75 | ×1.0 | ×1.25 |

**Saving is the spine.** On Hard the game autosaves after every resolved event, so a death, an injury, a failed trial, a bad birth is simply what happened. On Easy and Normal a player may save before anything and undo it — which is why the other dials matter less than this one row.

### Custom

Custom unlocks every preset dial **and the genetic parameters the presets protect** — mutation rates, trait frequencies, compatibility threshold, defect chances. Goofy playthroughs are a legitimate way to enjoy a breeding game and should not be locked away.

**Custom saves are flagged, and so is every codex page committed in one.** A rarity bred under custom rules stays visible and stays yours; it simply is not confused with one bred under standard rules. The flag is a label, not a penalty.

### Changing difficulty

**Lower freely; never raise.** A player who finds Hard punishing may drop without restarting, which matters in a game where a single run can span dozens of hours.

**The save records the lowest difficulty ever used, and codex entries stamp that** — not the setting at the moment of commitment. Without this a player drops to Easy for the dangerous stretch, returns to Hard, and their pages claim something they did not do. Same principle as the custom flag: nothing is forbidden, everything is legible.

---

# Appendix A — The Day Tick

The single most load-bearing function in the game. Everything else is a query against state the tick produces.

## A.0 Contract

- **Deterministic given a seed.** Same state + same seed = same result, always. Required for save integrity and for batching multiple days when a party is away.
- **No UI dependency.** The tick never calls a display function. It emits an **event log**; the UI reads the log afterward and decides what to show.
- **Idempotent per day.** Running the tick twice for the same date is a bug, not a doubling.
- **Order matters.** Later stages read values written by earlier ones. Do not reorder without checking the dependency notes.

```gml
/// tick_day(state, seed) -> { state, events[] }
```

## A.1 Processing order

**1. Advance the date**
Increment day. Roll over week (moon phase), season, year. Emit `season_changed`, `year_changed`, `moon_changed`.
*Season rollover must happen before environment resolution so places use the new season's values.*

**2. Roll weather**
Draw from the season-weighted table (§11.1). Check severe-event trigger against season and recent history (severe events should not stack on consecutive days).
Emit `weather_set`, optionally `severe_event`.

**3. Resolve severe event, if any**
Lock the day's normal action set. Queue the emergency scenario. Apply preparation state from the previous day's forecast actions — prepared structures take reduced damage.
Emit `emergency_begin`.

**4. Resolve environment per place**
`effective = place_base + season_shift + weather_shift + nest_modifiers`
Cached per place for this day; every creature reads from the cache.
*Must run after weather and season.*

**5. Facility load**
For each facility: `effectiveness = clamp(capacity / population, 0.4, 1.0)`.
Apply helper contributions to capacity. Apply the farm-sitter's competence multiplier if the player is away.
*Must run before any care resolution.*

**6. Per-creature comfort and stress**
`comfort = distance(preference, effective_environment[place])`
Stress delta from comfort, facility effectiveness, nesting disposition versus nestmate count, and injury state. Settling-in grace exempts new arrivals.
Lowest-bond creatures absorb facility degradation first.
Emit `stress_threshold_crossed` where relevant.
*Must run after 4 and 5.*

**7. Passive creature updates**
Fullness decay. Fatigue accrual or recovery. Bond decay under sustained neglect — **floored at a fraction of peak bond ever reached**, never to zero from neglect alone. Byproduct accrual, scaled by comfort.

```gml
bond_floor = peak_bond_reached * BOND_FLOOR_RATIO
```

An animal who loved you deeply does not forget entirely; one you barely knew can fall close to nothing. **The floor protects the number, not the animal** — neglect still costs stress, illness risk, refusals, and trait consequences, and climbing back out of a neglect trough is slower than the original climb was. A high floor must never read as permission.
*Must run after 6 so stress feeds these.*

**8. Affinity**
Growth for co-nested pairs. Rate scaled by phenotype distance (speed only, never ceiling), nest quality, and both creatures' stress.

**9. Growth**
Size progress toward `ceiling * maturity(age) * care_score`. Reads today's fullness and comfort.

**9b. Stats**
Apply the day's stat progression (Appendix E.4): training and work gains toward `ceiling * maturity(life_stage)`, scaled by `maturity_rate`, trait modifiers, and condition. Apply elder decay where the life stage warrants it.
Emit `stat_changed`, `overshoot_gained`.
*Must run after 9 so realised size is current — Vitality and Power read it.*

**10. Gestation and incubation**
Decrement counters. On zero, resolve birth: run inheritance (§5), apply nest environment bias, birth-season imprint, moon-phase mutation modifier, and inbreeding coefficient.
Emit `hatched` with the full genome.
*Must run after 4 — the nest's environment on the hatch day biases the roll.*

**11. Juvenile learning**
For creatures inside the learning window, roll behavior acquisition against nestmates' expressed behaviors, care patterns, season, and moon phase.
Emit `behavior_learned`.

**12. Mentoring**
Advance mentoring pairings. On completion, grant the named Lesson.
Emit `lesson_granted`.

**13. Aging**
`age_days++`. Check life-stage transitions. Fold today's stress and fatigue into `care_history`. Apply injury accumulation to expectancy.
Check degradation stage (Slowing / Frail / Failing / Ready).
**Roll passing** as a rising probability against the current degradation stage — never a countdown.
Emit `stage_changed`, `degradation_changed`, `passed`.
*Must run after 6 and 7 so today's conditions are already folded in.*

**14. Passing resolution**
Generate Keepsake (quality from lifespan lived and bond). Place a grove marker with a generated epitaph. Update the lineage tree. Check ascension eligibility.
Emit `keepsake_created`, `marker_placed`, optionally `ascension`.

**15. Returns**
Foraging parties and adventure parties return if due. Resolve yields, fatigue, injuries, and bonding.
Emit `party_returned`.

**16. World refresh**
On **Vesh**: trader restock, Board refresh. Expire lapsed commissions. Generate new commissions from the capability envelope. Guarantee the persistent stretch commission still exists.

**17. Festivals**
Check the calendar. Begin, continue, or end multi-day festivals. Apply their modifiers.
Emit `festival_begin`, `festival_end`.

**18. Random events**
Roll the daily event table, weighted by season, weather, moon phase, reputation, and outstanding consequences from past placements.
Emit `event`.

**19. Economy**
Deduct helper wages and feed costs. Credit passive byproduct and reputation income.

**20. Persist**
Autosave. Compact the event log for the UI.

## A.2 Batching

When the player is away on an adventure, the tick runs N times in sequence with the farm-sitter's competence applied at stage 5. The event log accumulates across all days and is presented as a **homecoming summary** — not a stream of popups.

Nothing in the tick may block on player input. Emergencies that occur while away resolve automatically at the sitter's competence level, with worse outcomes than a prepared player would have achieved.

## A.3 Testing hooks

- Seeded replay: same state and seed reproduces an identical log
- Fast-forward harness: run 1,000 days headless and assert no NaNs, no negative ages, no creatures stuck between stages
- Population drift check: run a closed gene pool 50 generations and confirm inbreeding defects appear on schedule
- Distance matrix dump: print pairwise archetype distances to verify bridging depth

---

# Appendix B — Archetype set

Nineteen landmarks in phenotype space. **Not a roster** — most creatures a player meets will be strains between these.

Axis values 0–6. Reminder of poles:
`metabolism` 0 endotherm → 6 ectotherm · `integument` 0 fur/feather → 6 scale/slime · `frame` 0 upright/limbed → 6 sprawling/serpentine · `element` 0 pyric → 6 hydric · `temperament` 0 feral → 6 placid

| # | Archetype | Met | Int | Frm | Ele | Tmp | Lifespan | Mat | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **Stiltling** | 0 | 0 | 0 | 5 | 3 | 200 | std | Heron-like. Upright extreme, feathered, wading. |
| 2 | **Rapt** | 0 | 0 | 2 | 1 | 1 | 170 | std | Raptor. Fast, fierce, dry-country. |
| 3 | **Corvid** | 0 | 0 | 3 | 3 | 2 | 220 | slow | Clever, long-lived, unsettling. |
| 4 | **Emberhound** | 0 | 1 | 2 | 0 | 1 | 160 | std | Pyric extreme. Warm-blooded, furred, hot. |
| 5 | **Lupin** | 1 | 1 | 2 | 2 | 1 | 150 | std | Wolf-like. The baseline predator. |
| 6 | **Ursine** | 1 | 1 | 1 | 3 | 3 | 230 | slow | Bear-like. Heavy, long-lived, deceptively calm. |
| 7 | **Cervine** | 1 | 1 | 2 | 4 | 5 | 170 | fast | Deer-like. Skittish, graceful. Precocial. |
| 8 | **Woolback** | 1 | 0 | 2 | 3 | 6 | 210 | std | Placid extreme. Hardy, gentle, unglamorous. |
| 9 | **Bristleback** | 1 | 2 | 2 | 2 | 1 | 150 | std | Boar. Coarse-coated, bad-tempered, durable. |
| 10 | **Fenling** | 2 | 2 | 3 | 5 | 3 | 130 | fast | Marsh mustelid. Short-lived, playful, quick generations. |
| 11 | **Thornbeast** | 2 | 6 | 2 | 3 | 4 | 220 | slow | Armoured herbivore. Scale extreme on a limbed frame. |
| 12 | **Delver** | 2 | 1 | 4 | 4 | 4 | 130 | fast | Burrower. Low light, low drama, fast turnover. |
| 13 | **Draik** | 3 | 6 | 3 | 0 | 0 | 240 | slow | Small drake. Feral and pyric extremes, long-lived. Cannot be rushed. |
| 14 | **Mistling** | 4 | 3 | 4 | 6 | 6 | 210 | slow | Fog-dweller. Hydric and placid extremes. |
| 15 | **Coilkin** | 5 | 5 | 6 | 3 | 2 | 180 | std | Serpentine extreme. |
| 16 | **Stonegaze** | 5 | 6 | 5 | 2 | 1 | 230 | slow | Basilisk-adjacent. Slow, scaled, dangerous. |
| 17 | **Newtling** | 6 | 4 | 5 | 5 | 5 | 120 | fast | Shortest-lived. Excellent breeding stock. |
| 18 | **Salamandra** | 6 | 4 | 5 | 6 | 4 | 160 | fast | Ectotherm and hydric. The classic bridging target. |
| 19 | **Boggart** | 6 | 5 | 4 | 6 | 5 | 130 | fast | Toad-kin. Damp, placid, homely. |

**Maturity spread: 6 fast, 7 standard, 6 slow.** Long-lived does not imply slow-maturing — Woolback is long-lived and standard, Cervine is mid-lived and fast — so the two axes stay genuinely independent rather than collapsing into one "good species" gradient.

## B.1 Coverage check

Every axis has at least one archetype at or adjacent to each pole:

| Axis | 0-pole | 6-pole |
|---|---|---|
| Metabolism | Stiltling, Rapt, Corvid, Emberhound | Newtling, Salamandra, Boggart |
| Integument | Stiltling, Rapt, Corvid, Woolback | Thornbeast, Draik, Stonegaze |
| Frame | Stiltling (0), Ursine (1) | Coilkin (6), Stonegaze (5) |
| Element | Draik (0), Emberhound (0) | Mistling, Salamandra, Boggart |
| Temperament | Draik (0), Rapt (1), Lupin (1) | Woolback, Mistling (6) |

Extreme alleles therefore all have an entry point into the gene pool via wild capture or trade.

## B.2 Worked bridging example

**Lupin → Salamandra**, the case this system was designed around.

```
Lupin      [1, 1, 2, 2, 1]
Salamandra [6, 4, 5, 6, 4]

d = 1.5(5) + 1.0(3) + 1.5(3) + 0.75(4) + 0.5(3)
  = 7.5 + 3.0 + 4.5 + 3.0 + 1.5 = 19.5     → incompatible (threshold 8)
```

Bridge candidates sitting between them:

```
Fenling  [2, 2, 3, 5, 3]  — d to Lupin  = 1.5+1.0+1.5+2.25+1.0 = 7.25  ✓ compatible
Delver   [2, 1, 4, 4, 4]  — d to Salamandra = 6.0+3.0+1.5+1.5+0.0 = 12.0  ✗
Boggart  [6, 5, 4, 6, 5]  — d to Salamandra = 0+1.0+1.5+0+0.5 = 3.0    ✓ compatible
```

So: breed Lupin × Fenling, breed Salamandra × Boggart, then cross the two offspring. Because crossover inherits whole values, the first-generation results are *combinations* of parent alleles — the player selects the offspring whose inherited values pulled toward the middle, and the second cross becomes viable. Typically two to three generations, with selection pressure on which offspring to keep.

**Tuning note:** this example should be validated against the real distance matrix once seeded. Target depth for the average distant pair is 2–3 generations. Dump the full matrix and check that no pair exceeds 4.

## B.2.5 Aptitude bands

Through v3.2 archetypes carried axes, lifespan and maturity rate but **no aptitude bands**, so every species rolled vigor, celerity, nerve and acuity from identical distributions and reached comparable stat ceilings. Species differed in timing and shape, never in potential. This section closes that.

### Axes say what shape she is; aptitudes say what quality she is

**Aptitude bands must not re-derive from the axes that already feed stats.** E.3 applies axis contributions directly — integument to Vitality, frame to Power and Celerity, temperament to Nerve and Acuity, metabolism to Stamina. Deriving vigor from integument as well counts the same fact twice.

Worked: a Thornbeast at integument 6 gets `n(integument) × 20 = +20` Vitality from the axis. Give her a vigor band of 60–90 instead of 40–70 and her mid-roll adds `(75 − 55) × 0.55 ≈ +11` more, from the same fact about her skin. The species spread ends up half again as wide as either mechanism intended, and neither is identifiable as the cause when balance data looks wrong.

So aptitudes carry what morphology does not determine:

| Aptitude | Derived from |
|---|---|
| `longevity` | `lifespan_base` — near-direct |
| `fecundity` | inverse of `maturity_rate` — fast species throw more young |
| `vigor`, `celerity`, `nerve`, `acuity` | the remaining budget, distributed by species identity |

Element is the one axis stats never read, and it has no clean aptitude reading — it stays out. Hand overrides handle identity the derivation misses: a Corvid is sharp because she is **clever**, not because of her feathers.

### The budget

**Budget = the sum of the six band midpoints.** Standard is **330** (six midpoints of 55, on an aptitude range of 10–100). Bands are ±15 around each midpoint, clamped to [`APT_MIN`, `APT_MAX`].

Without a budget some species are simply better, and nineteen archetypes collapse into a tier list. With one, every archetype is good at something and bad at something — which B.3 already claims and never enforced.

**Two independent multipliers, and they stack:**

| Strength | × | | Difficulty | × |
|---|---|---|---|---|
| Diminished | 0.88 | | Easy | 1.00 |
| Standard | 1.00 | | Moderate | 1.04 |
| Strong | 1.12 | | Demanding | 1.07 |

`budget = 330 × strength_mult × difficulty_mult` → range **290 to 396**, or ±20%.

Strength and difficulty are **separate**. A species may be strong and easy — rare, and a deliberate prize. A species that is both strong and demanding sits at the ceiling, because the difficulty modifier compensates on top of the strength tier rather than replacing it.

**5–6 of the nineteen are Strong.** More than that and above-budget stops meaning anything; fewer and the tier is a footnote.

### Difficulty is derived, never assigned

Hand-assigning difficulty lets a species be labelled demanding while playing easy, collecting free points. Derive it from what is already in the data:

| Factor | Raises difficulty when |
|---|---|
| `maturity_rate` | Slow — long investment before any payoff |
| Axis extremity | Values at 0 or 6 narrow comfort tolerance and gate more features out |
| Isolation | High mean distance to other archetypes — few compatible mates without bridging |
| Fecundity floor | Low base fecundity — fewer attempts per life |

This keeps the modifier honest: a species is compensated for being hard exactly insofar as it *is* hard, and rebalancing maturity or fecundity moves difficulty with it automatically.

### Consequence for the fertility decisions

The recovery-period model (§5.5) assumed fast species pay for their breeding advantage with lower stat ceilings. **That counterweight did not exist before this section** — it exists now, through `fecundity` consuming budget that vigor, nerve and acuity would otherwise get. A fast fecund species is genuinely a poorer fighter, and that is now a fact about the data rather than an assertion.

## B.3 Species-varied lifespans

Short-lived (120–140): Newtling, Fenling, Delver, Boggart. Fast generational turnover — these are the workhorses of a breeding program.

Long-lived (210–240): Draik, Ursine, Stonegaze, Corvid, Mistling, Woolback, Thornbeast. Companion material. The deification arc lives here.

Mid (150–200): everything else.

This gives archetype choice a strategic dimension beyond coordinates — and lets the player choose their own emotional exposure to loss.

---

# Appendix C — Features and Traits

## C.0 Architecture

Two distinct systems, previously conflated:

- **Features** — morphological. Horns, fangs, plumage. Each is one compositor part on an anchor. 16 at v1.
- **Traits** — behavioral. Organized into four families. 30 at v1.

### Origin flags

Traits are not sorted into "genetic," "learned," and "acquired" lists. Each trait carries flags:

| Flag | Meaning |
|---|---|
| **Inherit** | Can be passed genetically (recessive — both copies required) |
| **Learn** | Can be acquired during the juvenile window through upbringing |
| **Acquire** | Can be written on by an event at any age |
| **Remove** | Can be trained out, healed, or resolved — fully, partially, or not at all |

**Fixation** applies to *learned* traits only. Upbringing can become family culture over generations; **lived experience never becomes heritable.** A Battle-Hardened veteran cannot pass her experience to a hatchling — she can only transmit it socially, by mentoring.

### Variants

A trait may carry a **variant** rather than spawning near-duplicate traits: `trait: { id, variant }`.

- **Territorial** — toward all species / toward other species only / toward its own kind only
- **Tolerant** — cold / heat / damp / dry
- **Gendered pairs** — Herd Mother and its male counterpart: same family role, different effect

Variants multiply expressiveness without multiplying the trait count. The appraiser reports the variant only at higher expertise — knowing she is Territorial is tier 1; knowing she is Territorial *only toward her own kind* is deeper reading.

### Expression density and frequency tiers

Expression is per-trait and independent. **Nothing enforces one trait per family** — a creature may express three Sense traits and nothing else, and some creatures express none at all. That is intended: it makes trait-rich animals a genuine find.

**Each trait carries a frequency tier** setting its allele frequency in the wild population:

| Tier | Allele freq | Expression rate | Count |
|---|---|---|---|
| Common | 0.32 | ~10% | 13 |
| Uncommon | 0.20 | 4% | 13 |
| Rare | 0.10 | 1% | 4 |

Under recessive expression across 30 independent loci this yields an expected **1.9 traits per creature**, roughly **1 in 7** expressing none, and 5+ traits at about **1 in 29**.

**This replaces the v0.6 targets, which could not all hold at once.** At an average of 2.5 traits the allele frequency sits near 0.32 uniform, only 1 in 14 animals expresses nothing, and 5+ traits occurs to roughly 1 in 9 — common enough that "exceptional" stops meaning anything. Pulling the expectation down to ~1.9 makes all three read correctly. To trim to exactly 1.8, move two Common traits to Uncommon.

Tiers rather than a uniform frequency because the document already requires it: Sixth Sense is described as rare and archetype-concentrated, while Territorial and Hardy should be everywhere. Tiers give a direct dial on which traits are worth building a project around.

### Practical and combat effects

Every trait has a **practical effect** on ranch, breeding, or adventure life. Most also have a **combat correlate** that follows naturally from the practical one. Where no sensible combat reading exists, the trait simply has none — correlation is not forced.

---

## C.1 Features (16)

Recessive expression. A locus may be **carried** by any creature regardless of phenotype; the gate governs **expression** only.

**Gating principle:** a gate exists when the feature cannot plausibly sit on that body — referencing **frame** (owns silhouette) and **integument** (owns texture), plus mass where relevant. Two **thematic** gates are retained where the axis owns the visual channel the feature uses. Temperament never gates morphology.

**Variants may carry their own gates.** Feathered Pinions need `integument <= 2`; membranous Pinions need `integument >= 4`. Same locus, opposite requirements — bird wing versus bat wing. This makes one feature a bridging target in both directions.

| # | Feature | Anchor | Gate | Inheritance | Type | Variants |
|---|---|---|---|---|---|---|
| 1 | **Horn** | head | `frame <= 3` | recessive | anatomical | single / paired / spiral |
| 2 | **Crest** | head | *by variant* | recessive | anatomical | feathered (`int <= 3`) / membrane (`int >= 4`) |
| 3 | **Long Fangs** | jaw | none | **dominant** | free | sabre / needle |
| 4 | **Talons** | limb | `frame <= 4` | recessive | anatomical | hooked / broad / retractable |
| 5 | **Frill** | head | `integument >= 3` | **dominant** | anatomical | bone / membrane |
| 6 | **Barbels** | jaw | `element >= 3` | recessive | thematic | — |
| 7 | **Split Tail** | tail | none | **dominant** | free | twin / forked |
| 8 | **Heterochromia** | eye overlay | none | **dominant** | free | — |
| 9 | **Mane** | head + spine | `integument <= 2` | recessive | anatomical | full / ruff |
| 10 | **Plumed Tail** | tail | `integument <= 2` | recessive | anatomical | fan / streamer |
| 11 | **Spined Ridge** | spine | `integument >= 4` | recessive | anatomical | sail / spikes |
| 12 | **Bioluminescence** | palette + glow | `element >= 4` | recessive | thematic | spots / veins |
| 13 | **Webbed Feet** | limb | `frame <= 4` | **dominant** | anatomical | — |
| 14 | **Tusks** | jaw | `frame <= 2` + high mass | recessive | anatomical | upper / lower |
| 15 | **Pinions** | spine | *by variant* | recessive | anatomical | feathered (`int <= 2`) / membrane (`int >= 4`) |
| 16 | **Carapace** | spine | `integument >= 5` | recessive | anatomical | plated / segmented |

**Inheritance:** 11 recessive (both copies required) and 5 dominant (one copy expresses) — see §5.2 for why the split exists. Gates govern expression in both cases.

**Total parts: ~30** across 16 loci. Linear, not multiplicative — every part composites onto any of the 7 base bodies via anchors.

**Anchor load:** head 3, jaw 3, spine 3, limb 2, tail 2, overlay 3. Evenly spread.

**Cross-gate opportunities.** Mane (`integument <= 2`) and Carapace (`integument >= 5`) can never be expressed by the same creature, though a lineage can carry both. Feathered Pinions and membranous Pinions likewise sit at opposite integument poles. These impossible-together pairs are what drive long breeding projects.

---

## C.2 Psychological (8)

Stability, nerve, and drive. How she holds up, and what breaks.

| Trait | Kind | Practical | Combat | I | L | A | R |
|---|---|---|---|---|---|---|---|
| **Sound Nerve** | + | Recovers quickly from fright | Resists fear and morale effects | ✓ | — | — | — |
| **Driven** | + | Works willingly, trains faster | Faster action recovery | ✓ | ✓ | — | — |
| **Resolute** | + | Holds under pressure in trials | Does not break at low health | ✓ | ✓ | ✓ | — |
| **Fixated** | ± | Self-soothing repetition — eases her stress, hampers training | Locks onto one target, ignores better ones | ✓ | — | ✓ | partial |
| **Lazy** | − | Resists work | Low initiative | ✓ | ✓ | — | partial |
| **Resource Guarding** | − | Aggressive around food and nest | Fights harder when cornered | ✓ | — | ✓ | hard |
| **Storm-shy** | − | Panics in weather; stress spikes in severe events | Penalties in weather encounters | ✓ | — | ✓ | partial |
| **Working Disposition** *(2 variants)* | ± | **Steadfast** declines in retirement and wants work; **Restful** degrades faster if worked past prime. Non-expression is neutral | — | ✓ | — | — | — |

**Frequency tiers.** Common: Sound Nerve, Fixated, Lazy, Storm-shy, Working Disposition. Uncommon: Driven, Resolute, Resource Guarding.

**Resource Guarding is acquirable from neglect** — specifically, from being the lowest-bond creature during sustained facility overload. She learned that food isn't guaranteed. It persists long after the ranch is fixed, it is hard to remove, and it is the player's fault.

**Fixated** is a creature under pressure developing a coping behavior that makes her worse at work. Accurate, and quietly sad. Partial removal through patient care makes her a redemption project rather than a write-off.

---

## C.3 Sense (6)

Perception. The adventurer's family.

| Trait | Kind | Practical | Combat | I | L | A | R |
|---|---|---|---|---|---|---|---|
| **Stormsense** | ± | +1 day forecast; calms nestmates in severe weather. Unwilling to range far — reduced forage yield | Pre-encounter warning in weather | ✓ | — | — | — |
| **Keen Nose** | + | Trail tracking; enables find-quests; turns up small finds around the farm; drives creature-sent foraging yield | Tracks fleeing enemies, detects ambush | ✓ | ✓ | — | — |
| **Empath** | + | Reads *states* in other creatures — illness, pregnancy, stress, readiness | Reads enemy condition and intent | ✓ | ✓ | — | — |
| **Night Eye** | ± | Operates in darkness; stronger during the Dark and the Hollow. Suffers in High Sun | No darkness penalty; penalty in bright light | ✓ | — | — | — |
| **Sixth Sense** | rare + | Unlocks certain quests and requests; communes with the passed | Perceives hidden and spirit enemies | ✓ | — | — | — |
| **Danger Sense** | ± | Warns of ambush — but refuses to advance into risk | Cannot be surprised; may refuse to engage | ✓ | — | ✓ | — |

**Frequency tiers.** Common: Keen Nose. Uncommon: Stormsense, Empath, Night Eye, Danger Sense. Rare: Sixth Sense.

### Keen Nose

Physical scent tracking. Follows trails on adventures, enables find-quests (a lost child, a strayed creature, a stolen item), and produces small finds around the farm every few days — which gives a non-adventuring player a reason to want her too.

### Empath

Reads **states** — illness, pregnancy, stress, breeding readiness, nearing the end.

**Depth scales with your expertise.** An Empath in a novice's hands reads feelings; in an expert's hands she reads further, because the handler can finally interpret what she is sensing. Mechanically she grants **+1 reveal tier** on any creature she is present for, capped so that she can never take a player past what expertise tier 4 already gives.

This does not break §17.2 — the access is earned by having bred or raised an Empath, and it cannot be bought. It follows the same precedent as the codex's species-scoped appraisal bonus (§13.6): a reward that accelerates the ladder without replacing it. Expertise still reads the genome; the Empath is a living appraisal aid, not a shortcut around the work.

### Sixth Sense

The game's most distinctive trait.

**Gating is hybrid.** It opens meaningful content, special events, and unique items, but never blocks overall progression — the game has no hard linear path, only cumulative unlock. Rare enough to feel like a revelation; findable enough that a player who wants one can go get it (a specific archetype carries it more often, and the Wildspeaker can point toward a carrier).

**Communing** happens at **Hollownight** with the player's own passed creatures, and with the **pre-existing shrine ghosts** — the previous caretaker's animals, whose markers are in the grove on day one. Those ghosts deliver the sanctuary's history directly, giving the same lore two routes: Founding delivers fragments annually, Sixth Sense lets a player go and ask.

Sixth Sense is also useful in any ghost event, request, or quest.

**What she brings back:** a memory that advances the sanctuary's history, a Keepsake that shouldn't exist, or knowledge of where something was buried.

**This gives the memorial system an ongoing role.** Without it, the grove only pays out at the moment of death.

---

## C.4 Social (8)

How she is with others. Note that **bond** (creature ↔ player) and **affinity** (creature ↔ creature) are separate values, and Social traits act on both.

| Trait | Kind | Practical | Combat | I | L | A | R |
|---|---|---|---|---|---|---|---|
| **Vigilant** | ± | Reduces stress for all nestmates; costs her own rest | Party cannot be surprised | ✓ | — | — | — |
| **Herd Mother** *(gendered)* | + | Juveniles in her nest bond faster and learn more readily | Buffs younger party members | rare | ✓ | — | — |
| **Share Food** | + | Splits her bond gain with the lowest-bond nestmate | Shares recovery with an ally | rare | ✓ | — | — |
| **Singular Bonding** | ± | One attachment only — extraordinary with it, poor with everyone else | Large bonus fighting alongside her bonded | ✓ | — | ✓ | — |
| **Aloof** | ± | Slow bond growth; ~20% resistant to negative impacts such as poor-nest decay | Resists morale swings; gains nothing from party buffs | ✓ | — | — | — |
| **Territorial** *(3 variants)* | − | Slows affinity growth — toward all, toward other species only, or toward its own kind only | Bonus defending home ground | ✓ | — | — | — |
| **Nesting Disposition** *(2 variants)* | ± | **Solitary** takes a penalty per nestmate and a bonus alone; **Communal** gains with nestmates and suffers alone. Non-expression is indifferent | — | ✓ | — | — | — |
| **Matriarch / Patriarch** *(gendered)* | rare + | Can mentor **several** apprentices at once rather than one at a time — throughput, not a rule exemption | Commands a larger party formation | ✓ | — | — | — |

**Frequency tiers.** Common: Aloof, Territorial, Nesting Disposition. Uncommon: Vigilant, Singular Bonding. Rare: Herd Mother, Share Food, Matriarch / Patriarch.

### Matriarch / Patriarch

The propagation trait. §7.3's long game is a bloodline that raises its own young properly, and an ordinary elder can only teach sequentially — one apprentice at a time, for however many days she has left. A Matriarch teaches a whole cohort at once, which on a short elder tail is the difference between seeding a generation and seeding one animal. That makes her the most valuable animal on the ranch and a genuine breeding target rather than a lucky roll.

**Overshoot does not scale with her.** Numeric breakthroughs transmit once per elder regardless (E.6); only behavioural Lessons multiply. Otherwise one animal launders a stat ceiling into a whole cohort.

### Singular Bonding

**Attachment window.** From introduction, the player has **one day** to isolate her with a chosen creature — or with only the player. After that day, she attaches to whoever her affinity improves with first.

To use that window deliberately you must *know* she has the trait, which means expertise. A novice's Singular Bonding creatures attach by accident to whoever happened to be in the pen; an expert directs it. Same mechanic, entirely different experience, with nothing artificially gated.

**Her positives are steep, matching her limits:**
- Bred with her bonded partner, offspring quality receives a large bonus rather than the usual affinity penalty — she is a poor generalist breeder and an exceptional dedicated one
- Player-bonded, she gains substantial trial and adventure performance while the player is present, learns faster, and resists stress near them

She is not a worse animal. She is an animal who only works one way, and works extraordinarily well that way.

### Aloof

Slow to attach, and that same distance means less can hurt her. Emotionally distant and therefore harder to wound — a tradeoff rather than a flaw.

---

## C.5 Physical (8)

Constitution and body.

| Trait | Kind | Practical | Combat | I | L | A | R |
|---|---|---|---|---|---|---|---|
| **Hardy** | ± | Reduced injury severity; slower bond growth | Damage resistance | ✓ | — | — | — |
| **Broody** | + | Faster fertility recovery, self and nestmates | — | ✓ | — | — | — |
| **Tolerant** *(4 variants)* | + | Widens comfort range — cold, heat, damp, or dry | Resists matching elemental damage | ✓ | — | ✓ | — |
| **Glutton** | ± | Reaches size ceiling faster; consumes 2 feeding slots | Higher stamina pool | ✓ | — | ✓ | partial |
| **Sluggish** | ± | Lower fatigue accrual; reduced celerity | Low initiative, high endurance | ✓ | — | — | — |
| **Frail** | − | Higher injury severity, shorter expectancy | Takes increased damage | ✓ | — | — | — |
| **Precocious** | ± | Shorter juvenile stage, earlier fertility — and a correspondingly shorter learning window, so she picks up fewer learned traits | Reaches usable stats sooner | ✓ | — | — | — |
| **Late Bloomer** | ± | Longer juvenile stage, later fertility — and a longer learning window, so she is markedly more teachable | Later peak, higher approach ceiling | ✓ | — | — | — |
| **Twinning** | rare + | Clutches yield **two** offspring rather than one | — | ✓ | — | — | — |

**Frequency tiers.** Common: Hardy, Tolerant, Glutton, Sluggish. Uncommon: Broody, Frail, Precocious, Late Bloomer. Rare: Twinning.

**Twinning** is the only route to more than one offspring per clutch and the single most valuable trait a breeding line can carry — it doubles throughput without touching the lifetime clutch cap. At ~2% expression it is a genuine find, and because it is heritable it is also a project worth years. Watch it in balance: a line that fixes Twinning has effectively doubled its selection pool, which is the closest thing in the design to a dominant strategy.

### Precocious and Late Bloomer

Individual variance on top of the species `maturity_rate` (§12.1), and the cost is diegetic rather than arbitrary: she grew up fast, so she had less childhood in which to be raised. The pair splits cleanly along the two paths — a breeder chasing turnover wants Precocious, a player building a mentoring culture wants Late Bloomer.

Deliberately **not** a single positive. A pure "matures faster" trait gets bred into every line within a few generations and quietly erases the species maturity identity it sits on top of.

**Tolerant is the variant system doing real work** — one trait, four variants, plugging directly into places, nests, seasons, and weather. A cold-tolerant creature can live in the brook through the Hollow without needing a burrow.

**Longevity remains an aptitude**, not a trait. It is already a numeric genome value; duplicating it would give two systems the same job.

---

## C.6 Balance summary

| Family | + | ± | − | Total |
|---|---|---|---|---|
| Psychological | 3 | 2 | 3 | 8 |
| Sense | 2 | 3 | 1 | 6 |
| Social | 3 | 4 | 1 | 8 |
| Physical | 2 | 5 | 1 | 8 |
| **Total** | **10** | **14** | **6** | **30** |

Added in v0.7: Working Disposition (Psych), Nesting Disposition and Matriarch / Patriarch (Social), Precocious and Late Bloomer (Physical). The ± column now dominates, which matches the standing preference for tradeoffs over strict upgrades.

**Defect pool.** High inbreeding coefficients produce outcomes drawn from a separate negative-only pool that is *not* part of the 30 and never a breeding target. See **Appendix D**.

---

## C.7 Grief

When a creature dies, **every creature holding high affinity with her grieves.** Not only pairs — a Herd Mother bonded to five means five grieve. **Singular Bonding creatures suffer heightened penalties.**

Grief manifests as a lasting stress state, withdrawal, and reluctance to form new attachments.

**It has a floor.** A cascade that could collapse a ranch in a week reads as punishment, not sorrow.

**Comforting is a player action.** The days after a death are spent with the ones left — which is exactly what those days should be. Sitting with a grieving creature speeds recovery and deepens bond permanently. Grief becomes gameplay rather than a debuff you wait out.

Suppressed entirely when the permanent-pasture accessibility toggle is on.

---

## C.8 Bridging workarounds

A ladder, so the player always has a lever proportional to the gap.

| Tier | Item / event | Effect | Availability |
|---|---|---|---|
| Common | **Tincture** | Shifts one *expressed* axis value by ±1 for a single breeding. Genetics unchanged; only the compatibility check sees it. Closes near-misses at distance 9–10. | Purchasable |
| Uncommon | **The Wildspeaker** | A wandering NPC who brokers one difficult pairing, substantially raising the effective threshold, for a price. | A few times a year, unscheduled |
| Rare | **Alden's Blessing** | Ignores the compatibility threshold entirely. Any two creatures. | Once per year, at the Stirring |

Note that this ladder addresses **distance only**. The levers on *inheritance* are separate and live in §5.7 — nest fidelity and line designation. Conflating the two was the gap that made every breeding project a lottery through v0.6.

### Alden's Blessing — constraints

Performed at the shrine under the First Keeper's aspect. Without costs, nobody would bridge — they would simply wait for the Stirring.

1. **Requires preparation.** An offering of rare materials or an artifact recovered from the wilds. An annual opportunity you must have worked toward, not a recurring gift.
2. **Both parents at bond tier 2+.** For animals you have raised, not a pair bought at market that morning.
3. **The offspring is born unquiet.** Elevated defect chance, high starting stress, low starting bond, and a substantial chance of a negative trait.

The third is the best part: **it is redeemable through care.** The player ends up with a difficult, unhappy animal carrying exactly the genetics they wanted, and turning her around is a project. The Blessing produces a story rather than a shortcut.

**Net effect: the Blessing skips distance, never quality.**

---

## C.9 Sex

**Sex is part of the genome and gates breeding.** A rare phenotype therefore requires securing both a male and a female carrier — which is precisely why real breeders keep more animals than they want, and which pushes players toward the trader and the wilds that the inbreeding system already required.

**Nest warmth biases offspring sex for ectotherm species** (high `metabolism`), mirroring real reptile biology. A basking stone tilts one way, a shaded burrow the other. This makes nests a breeding tool rather than only a comfort system, gives ectotherm archetypes a mechanical identity warm-blooded ones lack, and gives players a lever against the most frustrating RNG in the game — using numbers that already exist.

**Endotherms get the moon.** Warm-blooded species have no thermal lever, so conception moon-phase biases sex instead — a whisper rather than a lever, at `MOON_SEX_BIAS` (55/45), rising to `DARK_MOON_SEX_BIAS` (58/42) during the Dark.

**Deliberately weak, and the rare sex-setting item carries the real weight.** A strong calendar bias would turn every conception into a scheduling exercise. At this strength the moon rewards a player who notices without punishing one who doesn't — and the recovery-period model (§5.5) already defuses the line-ending risk that motivated a sex lever at all, since a creature now produces four to five offspring across her life rather than two. The symmetry is the lore: cold-blooded animals answer to heat, warm-blooded ones answer to the moon, and the shrine calendar becomes a breeding instrument for the whole roster rather than half of it. It costs nothing to build — weeks are already moon phases and the tick already applies a moon modifier at birth resolution (A.1 step 10).

**Plus a rare rite that sets sex outright**, gated behind rare commissions or the deep wilds — **never the trader**. If it is purchasable, the calendar bias becomes irrelevant the moment a player has money and a whole system has been spent on a shop item.

Without one of these, a run of wrong-sex offspring can end a line outright: roughly four to five clutches across a life, a six-slot early roster, and recessive targets that need both a male and a female carrier. It is the single most-cited frustration in comparable genetics games.

**More fantastical species** will carry elemental relationships between their traits and their sexes, to be designed alongside those archetypes.

---

# Appendix D — Inbreeding and the defect pool

## D.0 Two channels

Inbreeding produces bad outcomes through **both** channels, escalating with the coefficient:

- **Mild** — raises the expression odds of ordinary negative traits already in the 25 (Lazy, Frail, Storm-shy, Resource Guarding, Territorial). Costs no new content.
- **Severe** — introduces true **defects** from a separate pool that can appear no other way.

## D.1 Threshold bands

Anchored to real coefficients. Full siblings sit at **0.25**, so 0.25 must be survivable once — the design rule is *one generation of tight breeding to lock a trait, then outcross* (§5.5).

| Coefficient | Band | Effect |
|---|---|---|
| under 0.125 | Negligible | No effect |
| 0.125 – 0.25 | Mild | Negative trait expression odds +~25% |
| 0.25 – 0.375 | Moderate | Odds +~50%; small chance of a mild defect |
| above 0.375 | Severe | Defect chance climbs steeply; multiple defects possible |

A single sibling pairing lands at the bottom of Moderate — a real risk, usually survived. Doing it again lands in Severe. **The discovered optimum becomes the intended rule**, without the game ever stating it.

Reference points: full siblings and parent–offspring = 0.25 · half siblings = 0.125 · first cousins = 0.0625.

## D.2 The defect pool

**Defects are heritable alleles.** They do not merely happen to an individual — they enter the lineage and persist, recessive and invisible, until two carriers meet. A careless birth can contaminate a line for generations.

This is thematically exact (real inbreeding depression works precisely this way) and it is the harshest system in the game. It is calibrated by the safety valves in D.3, not by softening the mechanic.

| Defect | Severity | Effect |
|---|---|---|
| **Tremors** | mild | Reduced celerity; fails precision trial disciplines |
| **Poor Sight** | mild | Reduced forage and adventure performance; cannot learn **sight-based** Sense traits (Night Eye). Scent, weather, empathic and precognitive senses are unaffected |
| **Sickly** | moderate | Chronic stress floor; frequent illness events |
| **Stunted** | moderate | Never reaches adult size ceiling |
| **Malformed** | moderate | Feature expression fails; reduced trial scores |
| **Weak Heart** | severe | Drastically shortened lifespan |
| **Barren** | severe | Wholly infertile — the line ends with her |
| **Withdrawn** | severe | Cannot bond past tier 2 — **treatable** to tier 4 |

**Frail** is not in this pool; it is a Physical trait in the 25 (Appendix C.5). **Weak Heart** is the severe analogue.

### Withdrawn is treatable, and deliberately so

Sustained care lifts her bond ceiling from tier 2 to tier 4 across a long stretch. She can get close. **She never quite arrives.**

A creature structurally impossible to love would be the cruelest thing in a game built on attachment. A creature you can nearly reach is sadder, and far better.

## D.3 Safety valves

**The primary valve is information, not forgiveness.**

**Carried defect alleles are revealed at expertise tier 3**, alongside other carried recessives (§17.3). An expert can screen a line before breeding it; a novice cannot. A contaminated lineage therefore becomes a consequence of breeding blind rather than of bad luck — and it gives the expertise ladder its sharpest practical payoff.

The inbreeding coefficient of a prospective pairing is likewise visible at tier 3. **The warning is available; the specific outcome remains a surprise.**

Three routes out of a contaminated line, in ascending cost:

| Route | Cost | Scope |
|---|---|---|
| **Outcross** | Free, slow | Dilutes across generations |
| **Placement** | Loses the animal | Retires carriers from the breeding pool |
| **Shrine purification** | Very rare, very expensive | Clears one defect allele from one individual |

**Placement is the humane cull.** The moral placement system (§18.3) already handles finding a creature a good home — so removing a carrier from your gene pool is an act of care rather than disposal. This is the deliberate counterpoint to Mewgenics' donation loop.

**Shrine purification is rare** — rarer than Alden's Blessing, gated behind late-game progression or quest reward rather than purchase. It clears one allele from one creature and never a whole lineage. It exists so a beloved animal is not condemned by her grandparents, not so lines can be laundered.


---

# Appendix E — The Stat Block

Six numbers. Every trial, every fight, every piece of work is a different weighting of them.

## E.0 Three layers

Stats are **hybrid** — derived at birth, stored thereafter, modified at read time.

| Layer | Storage | Changes when |
|---|---|---|
| **Ceiling** | Rolled at birth from aptitudes, axes, and size. Fixed for life. | Never, except overshoot |
| **Current** | Stored. Starts low, rises with growth and work, falls in the elder tail. | Daily tick, training, trials, adventures |
| **Modifiers** | Not stored. Applied when a stat is *queried*. | Traits, injury, fatigue, stress, grief, bond |

```gml
effective(stat) = clamp(
    stat_current[stat] * trait_mult(stat) * condition_mult(),
    0,
    stat_ceiling[stat] + stat_overshoot[stat]
)
```

**Modifiers are never written into `current`.** If Frail is acquired at day 40 and baked into stored Vitality, every removable trait and every healed injury needs a reverse-write, and any error there is permanent and invisible in the save. A trait change must be one flag, not a migration.

---

## E.1 The six stats

| Stat | Combat | Trials | Ranch / adventure |
|---|---|---|---|
| **Vitality** | Health pool, injury resistance | Endurance, protection | Illness resistance, recovery speed |
| **Power** | Damage, holds, staggers | Protection | Hauling, clearing Works sites |
| **Celerity** | Initiative, evasion | Retrieval, agility | Travel speed on adventures |
| **Nerve** | Morale floor, resists fear | Obedience, protection | Stress resistance, storm tolerance |
| **Stamina** | Action economy, sustain | Endurance, tracking | Days sustainable in the field |
| **Acuity** | Read quality (E.5), target selection | Tracking, obedience, retrieval | Foraging yield, find events |

---

## E.2 The revised aptitude layer

Six aptitudes, range `APT_MIN`–`APT_MAX`, inherited per §5.3.

| Aptitude | Feeds |
|---|---|
| **vigor** | Vitality, Power |
| **celerity** | Celerity |
| **nerve** | Nerve |
| **acuity** | Acuity |
| **longevity** | lifespan (§12.2) **and** Stamina |
| **fecundity** | fertility (§12.4) |

`mass_tendency` moved to §9. Every aptitude now has exactly one home, and the "aptitude cap" of §5.4 means one thing rather than two.

**Longevity pays twice** — deliberately. A long-lived line is also an enduring one, which gives the adventurer a reason to breed for a stat that would otherwise belong only to the sentimental player. It also means the animal who lasts is the animal who lasts, in both senses.

---

## E.3 Ceiling derivation

Axis terms normalise to 0–1: `n(v) = v / 6`. `size` is the birth-fixed size ceiling from §9, normalised 0–1.

```gml
ceiling.vitality = apt.vigor     * 0.55 + n(integument)      * 20 + size * 25
ceiling.power    = apt.vigor     * 0.35 + (1 - n(frame))     * 15 + size * 35
ceiling.celerity = apt.celerity  * 0.60 + n(frame)           * 20 - size * 15 + 15
ceiling.nerve    = apt.nerve     * 0.65 + n(temperament)     * 25
ceiling.stamina  = apt.longevity * 0.45 + (1 - n(metabolism))* 20 + apt.vigor * 0.15
ceiling.acuity   = apt.acuity    * 0.65 + (1 - n(temperament))* 25 - size * 10 + 10
```

**Temperament pulls opposite ways for Nerve and Acuity.** Placid holds composure and reads slowly; feral is alert and brittle. This is the reason the axis is not a good/bad slider, and the reason feral stock stays worth keeping instead of being bred out of the world by turn thirty.

**Balance watch:** `vigor` feeds two stats and touches a third. It will be the most contested aptitude on the market and should be priced accordingly. If playtesting shows it dominating, move Power's primary onto `size` and drop the vigor term to 0.20 rather than adding a seventh aptitude.

---

## E.4 Growth

A hatchling is weak regardless of pedigree.

```gml
current[s] = ceiling[s] * CURRENT_START_PCT          // at hatch

reachable[s] = ceiling[s] * maturity(life_stage)
gain         = TRAIN_RATE
             / maturity_mult                                 // fast species climb faster
             * (reachable[s] - current[s]) / reachable[s]     // diminishing
             * discipline_match                               // 1.0 targeted, TRAIN_FLOOR_GAIN incidental
             * trait_rate_mult                                // Driven, Lazy, Sluggish, Late Bloomer
             * condition_mult()
```

**Approach rate is `maturity_rate` (§12.1), not a separate value.** One species number governs how fast she grows up and how fast she becomes what she is capable of. A Newtling matures fast, trains fast, and reaches a modest ceiling well inside her short life. A Draik matures slowly, trains slowly, and spends most of a long life climbing toward a high one — so a Draik acquired at forty days and lost early never showed you what she was. That is the correct feel for a drake.

The cost of reusing one number: there can be no slow-maturing but fast-learning species. Accepted for one fewer knob. Individual variance comes from traits that already exist.

| Stage | maturity |
|---|---|
| Hatchling | 0.35 |
| Juvenile | 0.60 |
| Adult | 1.00 |
| Elder | 1.00, decaying `ELDER_DECAY_PER_DAY` |
| Degradation | continues decaying, floor 0.60 |

Work that raises stats: training drills, trials, adventures, foraging, Works labour. Adventures and trials give the largest gains and carry injury risk — **the adventurer's animal gets better faster and dies sooner** (§12.3), which is the whole trade.

Elder decay is what gives retirement its weight. She is still the best mentor on the ranch and no longer the best worker, and both facts are visible in the same screen.

---

## E.5 Acuity and read quality

Acuity governs whether the creature **understood you**, not whether she connected.

```gml
misread_chance = MISREAD_MAX_CHANCE
               * clamp((MISREAD_ACUITY_PIVOT - effective(acuity)) / MISREAD_ACUITY_PIVOT, 0, 1)
               * situation_complexity
               * (2 - 1.5 * bond_factor)     // 2.0 unbonded → 0.5 at peak bond
```

**Bond swings this fourfold.** An unbonded animal doubles her misread chance; one at peak bond quarters it relative to that — the same creature, read by a handler she trusts. This is where §14's bond system earns its keep in the field, and it means a mediocre-Acuity animal you have raised well outperforms a better animal you just bought. Bond cannot eliminate misreads entirely: a low-Acuity creature stays unreliable in genuinely confusing situations no matter how much she loves you.

**A misread is never a whiff.** She does the wrong *sensible* thing: goes for the nearest threat rather than the indicated one, breaks a hold early, takes the fresher trail instead of the correct one. The failure must be legible as an animal making a judgement, not as a die coming up short. A whiff teaches nothing and reads as broken; a misread teaches that she needs more work, or that this was the wrong animal for this job.

Interactions already written elsewhere:

- **Fixated** — forces target lock; misreads become target *persistence* rather than target switching
- **Danger Sense** — may refuse to advance; a misread here is refusal, not error
- **Empath** — reduces `situation_complexity` against living opponents
- **Singular Bonding** — `bond_factor` uses the bonded partner's presence, not the player's, when she is not player-bonded

Acuity's ranch face is foraging yield and find events, so a breeder who never fights still has a reason to want it.

---

## E.6 Overshoot

The only route past a genetic ceiling within one life.

```gml
stat_overshoot[s] += ceiling[s] * OVERSHOOT_STEP     // max OVERSHOOT_MAX_STEPS per creature
```

**Three hard rules:**

1. **Never heritable.** Inheritance reads `aptitudes` only. Overshoot is stored separately precisely so that two overshot parents cannot launder raised ceilings into the pool — that would kill §5.4 by proxy. §C.0 already rules that lived experience does not become heritable; this is the numeric form of the same rule.
2. **Consumes a Lesson slot when transmitted by mentoring.** §13.3 caps Lessons at `min(handler_tier, bond_tier)`; where the elder carries an overshoot, the player chooses at completion whether that slot delivers a behavioural Lesson or the numeric breakthrough. Transmission stays **once per elder** even for a Matriarch — behavioural Lessons scale with that trait, numeric ones never do.
3. **Unfarmable.** Triggers are things survived, not things done: coming through a near-fatal injury, placing in a Gathering final, an artifact event, a deification stage, mentoring under an elder who carries overshoot in that stat (once, socially transmitted). If a player can identify and repeat a trigger, grinding replaces breeding as the optimal path and pillar 2 is gone.
4. **Dramatic, but bounded.** `OVERSHOOT_STEP` at 6% and a cap of three means a maximum of ~18%. A breakthrough should feel like one — a 3% step was inside the noise of a good training week and read as nothing. 18% is a different animal.

   The bound is the genome gap: a mediocre ceiling sits roughly 20–30% below a good one, so three breakthroughs still do not lift a poor animal past a well-bred one. They close the distance enough to matter and never enough to make breeding advisory. **If playtesting shows the gap is narrower than 20%, this constant comes down, not the cap** — the ceiling spread is load-bearing for pillar 2 and the step is not.

An animal with two overshoots is remarkable. One with three has a story attached to every one of them.

---

## E.7 Trial discipline weightings

Score is a weighted sum of effective stats, modified by bond and traits, tested against a difficulty threshold.

| Discipline | Vit | Pow | Cel | Ner | Sta | Acu |
|---|---|---|---|---|---|---|
| **Tracking** | — | — | 0.10 | 0.15 | 0.25 | 0.50 |
| **Obedience** | — | — | 0.20 | 0.45 | — | 0.35 |
| **Protection** | 0.10 | 0.40 | 0.20 | 0.30 | — | — |
| **Retrieval** | — | — | 0.35 | 0.10 | 0.20 | 0.35 |
| **Endurance** | 0.30 | — | — | 0.20 | 0.50 | — |
| **Conformation** | — | — | — | — | — | — |

```gml
score = sum(weight[d][s] * effective(s)) * bond_term * trait_mods
```

**Conformation reads no stats at all** — it scores features and axis values against a written association standard. That is the mechanical statement of §22: the association's measure and the working measure are different measures, and an animal can win one while failing the other. NPC judges should say so out loud.

No discipline uses more than four stats, and every stat is primary in at least one. A six-stat spread with a hole in it would mean a stat nobody breeds for.

---

## E.8 What expertise reveals

Extends §17.3. Two different things now exist to read — where she is, and what she could become — and the second is expert work.

| Tier | Stats revealed |
|---|---|
| 0 | Descriptive only — "she is quick", "she does not startle" |
| 1 | Current values as broad bands |
| 2 | Exact current; ceiling as a band |
| 3 | Exact ceiling; overshoot flagged and attributed; aptitude alleles |
| 4 | Projected ceilings for a *hypothetical pairing* — alongside §17.3's compatibility distance |

Tier 4 extends §17.3's five-tier table, which E.8 stopped short of through v0.6. It is the point where an expert can evaluate a mating on paper before spending a clutch on it — powerful, and the reason tier 4 should be genuinely hard to reach.

Tier 3 matching Appendix D's carried-defect reveal is intentional — one tier, one promise: *you can finally see what she actually is.*

**This is the appraiser's second job.** A novice buying at market sees a strong animal and pays for strength; an expert sees a strong animal three points below her ceiling and knows what she becomes with a season of work. That gap is the market inefficiency the expertise ladder exists to sell.

---

## E.9 Open against this appendix

- Numeric balance pass once the distance matrix and archetype aptitude spreads are seeded
- `situation_complexity` scale — needs combat prototype
- Whether elder decay should be trait-modifiable (Sluggish, Hardy are candidates)
- Training drill content: which drills, what days they cost, what they feed

---

# Appendix F — Build Specification

Everything above this line describes what the game does. This appendix describes how it is structured, so an implementation does not have to invent structure — and does not invent a *different* structure each session.

## F.0 Principles

1. **Content is data, code is behaviour.** Archetypes, traits, features, gates, standards and recipes live in JSON. Formulas live in GML. Adding a trait must never require touching code.
2. **The simulation never draws.** Sim code cannot call a draw function, reference a sprite, or read input. This is what makes headless balance runs possible, and it is a hard rule, not a preference.
3. **Rolls are locked.** A given event produces the same outcome no matter how many times it is loaded. No save scumming.
4. **Saves are versioned from the first build**, not from the first time it breaks.

---

## F.1 Layer boundaries

```
┌───────────────────────────────────────────────┐
│  PRESENTATION   render, UI, input, audio      │  may read sim, never mutate it
├───────────────────────────────────────────────┤
│  APPLICATION    game state, save/load, flow   │  orchestrates; owns the RNG streams
├───────────────────────────────────────────────┤
│  SIMULATION     genome, breeding, tick, life  │  pure. no draw, no input, no sprites
├───────────────────────────────────────────────┤
│  DATA           JSON content + schema         │  loaded once at boot, immutable
└───────────────────────────────────────────────┘
```

**Mutation flows down, reads flow up.** Presentation asks Application to do a thing; Application calls Simulation; Simulation returns new state. Presentation never writes to a creature.

**The test for the sim boundary:** if a function could not run in a console-only build looping 500 days, it does not belong in the simulation layer.

### Modules

| Module | Owns | Depends on |
|---|---|---|
| `bh_data` | JSON load, schema validation, content lookup | — |
| `bh_genome` | Genome struct, axes, features, traits, expression gates | `bh_data` |
| `bh_breeding` | Compatibility, distance, inheritance, mutation, defects | `bh_genome`, `bh_rng` |
| `bh_creature` | Creature struct, stats, life stage, bond, condition | `bh_genome`, `bh_data` |
| `bh_tick` | The day tick (Appendix A), in its documented order | all sim modules |
| `bh_calendar` | Date, season, moon, weather, guardian days | `bh_rng` |
| `bh_ranch` | Facilities, nests, capacity, care scores, byproducts | `bh_creature` |
| `bh_economy` | Money, trader stock, Board commissions, the Works | `bh_data` |
| `bh_rng` | Seeded streams, derivation, roll locking | — |
| `bh_save` | Serialise, deserialise, version migration | all sim modules |

**One rule that prevents the usual mess:** `bh_tick` is the only module permitted to advance time. Nothing else changes the date, ages a creature, or decays a value.

---

## F.2 Data schema

All content ships as JSON in Included Files, loaded once at boot into immutable structs. **Validate on load and fail loudly** — a typo in a trait name must be a startup error naming the file and key, never a silent nothing at runtime.

```
/data
  archetypes.json      19 records
  traits.json          31 records
  features.json        16 records
  standards.json       19 records — the association's written standard
  defects.json         Appendix D pool
  recipes.json         crafting
  places.json          nests, environments, modifiers
  constants.json       everything in §30
```

**`constants.json` is not optional.** Every value in §30 lives there, not in `#macro`s. Balance work means editing one file and relaunching, not recompiling — and a headless balance run needs to sweep them programmatically.

### archetypes.json

```json
{
  "id": "lupin",
  "display_name": "Lupin",
  "axes": { "frame": 5, "integument": 3, "metabolism": 5, "element": 2, "temperament": 3 },
  "maturity_rate": "standard",
  "lifespan_base_days": 160,
  "aptitude_bands": {
    "vigor":     [45, 75],
    "celerity":  [40, 70],
    "nerve":     [35, 65],
    "acuity":    [40, 70],
    "fecundity": [30, 60],
    "longevity": [40, 70]
  },
  "mass_tendency_band": [40, 70],
  "sex_determination": "endotherm",
  "starter_available": true
}
```

`maturity_rate` is the string key into the tier constants — it drives childhood length, gestation, stat approach rate, and breeding recovery. One value, four jobs (§12.1, §5.5, E.4).

### traits.json

```json
{
  "id": "keen_nose",
  "display_name": "Keen Nose",
  "family": "sense",
  "valence": "positive",
  "frequency_tier": "common",
  "inheritance": "recessive",
  "heritable": true,
  "learnable": false,
  "variant_group": null,
  "sex_restricted": null,
  "effects": [
    { "key": "forage.yield",   "op": "mult", "value": 1.25 },
    { "key": "trial.tracking", "op": "mult", "value": 1.40 },
    { "key": "combat.misread", "op": "mult", "value": 0.85 }
  ],
  "excludes": [],
  "requires_axis": null
}
```

`variant_group` links alternatives that cannot co-occur (Solitary / Communal; Steadfast / Restful; Territorial / Tolerant). `effects` is a list of namespaced key/op/value records — see the effect-key vocabulary below.

### Effect keys — the closed vocabulary

`effects` in `traits.json` is the contract between content and code. **The key list is closed and validated at load: an unknown key is a startup error naming the file and key.** An open list would let a typo become a silent no-op — a trait that appears to work and does nothing, which is the hardest class of content bug to notice.

**Keys are namespaced by the system that owns them.** A system reads only its own namespace, and no system may invent keys in another's. This is what keeps effects from becoming a global bag that everything greps.

```json
"effects": [
  { "key": "forage.yield",        "op": "mult", "value": 1.25 },
  { "key": "trial.tracking",      "op": "mult", "value": 1.40 },
  { "key": "combat.misread",      "op": "mult", "value": 0.85 },
  { "key": "breed.recovery_days", "op": "add",  "value": -2 }
]
```

**Three operations, applied `set` → `add` → `mult`:**

| Op | Meaning | Stacking |
|---|---|---|
| `mult` | Scale the value | **Always stacks.** 1.10 × 0.95 = 1.045. Commutative, so load order is irrelevant and no conflict is possible |
| `add` | Flat adjustment | **Always stacks.** Summed. Also commutative |
| `set` | Hard override | **Cannot stack.** Two `set` ops on one key is a load-time crash |

The crash is deliberate and narrow. Multipliers and additions combine on their own — a trait giving +10% and another giving −5% simply yields +4.5%, and that is the normal case. But there is no sensible reconciliation of *"attack is 40"* with *"attack is 25"*: one silently wins, and which one depends on file load order, which would make a save non-deterministic from content alone. `set` should be rare; when two of them collide the content is wrong, not the creature.

**Namespaces:**

| Namespace | Owner | Example keys |
|---|---|---|
| `stat.*` | `bh_creature` | `vitality`, `power`, `celerity`, `nerve`, `stamina`, `acuity`, `ceiling_mult`, `train_rate`, `elder_decay` |
| `breed.*` | `bh_breeding` | `recovery_days`, `fertile_fraction`, `gestation_days`, `clutch_size`, `defect_chance`, `sex_bias`, `inherit_fidelity` |
| `care.*` | `bh_ranch` | `fullness_rate`, `comfort_tolerance`, `stress_floor`, `illness_chance`, `byproduct_yield`, `nest_share` |
| `life.*` | `bh_creature` | `lifespan_mult`, `maturity_mult`, `injury_chance`, `recovery_rate`, `learning_window` |
| `bond.*` | `bh_creature` | `gain_rate`, `decay_rate`, `floor_ratio`, `cap`, `exclusive` |
| `trial.*` | `bh_economy` | `tracking`, `obedience`, `protection`, `retrieval`, `endurance`, `conformation` |
| `combat.*` | *(deferred)* | `damage`, `resist`, `initiative`, `morale_floor`, `misread`, `party_size` |
| `forage.*` | `bh_ranch` | `yield`, `rare_chance`, `find_chance` |
| `social.*` | `bh_creature` | `mentor_slots`, `lesson_cap`, `herd_tolerance`, `territorial` |

**Rules:**

1. **A key exists only if a system reads it.** No speculative keys. `combat.*` is declared but unimplemented — traits may carry those effects now, and the combat module honours them when it exists.
2. **Systems pull; traits never push.** Whichever system owns a key queries all expressed traits for it. A trait never calls into a system.
3. **Defects and chronic conditions use the same vocabulary.** Appendix D's pool is content, not special-cased code.
4. **Validation is not optional.** On load: every key resolves, every op is one of three, and no two traits that can co-express both `set` the same key.

### features.json

```json
{
  "id": "long_fangs",
  "display_name": "Long Fangs",
  "anchor": "jaw",
  "inheritance": "dominant",
  "allele_frequency": 0.15,
  "gate": null,
  "parts": ["fang_upper", "fang_lower"],
  "conflicts": ["blunt_muzzle"]
}
```

```json
{
  "id": "mane",
  "inheritance": "recessive",
  "allele_frequency": 0.25,
  "gate": { "axis": "integument", "op": ">=", "value": 5 },
  "parts": ["mane_neck", "mane_shoulder"],
  "conflicts": ["carapace"]
}
```

**A gate suppresses expression; it never alters the allele.** A gated-out feature is still carried and still inherited — that is the entire point of the appraisal ladder (§17.3) and of tier-3 reveal.

### standards.json

The association's written standard, per species. Read by conformation judging (§22) and by codex marginalia (§13.6).

```json
{
  "archetype_id": "lupin",
  "axis_targets": {
    "frame":       { "ideal": 5, "band": [4, 6] },
    "integument":  { "ideal": 3, "band": [2, 4] },
    "metabolism":  { "ideal": 5, "band": [4, 6] },
    "temperament": { "ideal": 4, "band": [3, 5] },
    "element":     { "ideal": 2, "band": [1, 3] }
  },
  "correct_features": ["long_fangs", "thick_pelt"],
  "faulted_features": ["split_tail", "frill"],
  "revised_year": 41
}
```

`revised_year` is flavour with teeth: an old date is the hook for NPCs arguing the standard is out of date when a player's line drifts outside it (§13.6).

---

## F.3 Runtime structures

```gml
creature = {
    id, lineage_id, parents: [id, id],
    archetype_id,
    genome: {
        axes:     { frame, integument, metabolism, element, temperament },
        features: [ { locus_id, allele_a, allele_b } ],   // 16
        traits:   [ { locus_id, allele_a, allele_b } ],   // 31
        aptitudes:{ vigor, celerity, nerve, acuity, fecundity, longevity },
        mass_tendency
    },
    sex, birth_day, birth_season, birth_moon,
    life_stage, lifespan_days, fertile_fraction,
    stat_ceiling:   { vitality, power, celerity, nerve, stamina, acuity },
    stat_current:   { ... },
    stat_overshoot: { ... },
    bond, peak_bond, care_history, condition,
    last_clutch_day, injuries: [], chronic_conditions: [],
    learned_traits: [], lessons: [],
    inbreeding_coefficient,
    is_retired, is_pastured, is_in_party,
    rng_seed                                  // see F.4
}
```

**Cache derived values, invalidate on event — never recompute per frame.** Invalidation points: birth, growth tick, life-stage transition, trait change, injury, chronic condition change, bond tier change.

`peak_bond` exists solely so the bond floor can scale (§14). `last_clutch_day` replaced the lifetime clutch counter in v2.7.

---

## F.4 RNG and roll locking

Determinism is a design requirement, not a nicety: **reloading a save must reproduce the same outcome.**

```gml
world_seed                                    // generated once at new game, saved
stream(name) = hash(world_seed, name)         // named independent streams
```

Named streams — `weather`, `market`, `events`, `wilds`, `birth` — so that consuming a roll in one system never shifts another. Without this, buying an item before a birth changes the offspring, which is both a bug and a save-scum vector.

**Every creature carries its own seed, derived at conception:**

```gml
child.rng_seed = hash(world_seed, sire.id, dam.id, conception_day, clutch_index)
```

Every genetic roll for that child — axes, features, traits, aptitudes, sex, defects, mutation — draws from a stream seeded on `child.rng_seed`. **The outcome is fixed at conception, before the player sees anything.** Reloading and re-running the pregnancy produces the identical animal, because the inputs are identical. No re-roll is possible without changing the pairing or the day, which is exactly the intended cost.

The same derivation governs any event whose outcome should not be re-rollable: death timing, defect manifestation, trial judging, overshoot triggers.

**Deliberately not locked:** ordinary combat and moment-to-moment interaction. Those are skill expression, and reloading a fight is a normal thing for a player to do.

---

## F.5 Save structure

Full snapshot, JSON, versioned from build one.

```json
{
  "save_version": 1,
  "game_version": "0.1.0",
  "difficulty": { "current": "hard", "lowest_ever": "normal", "custom_rules": false },
  "world_seed": 8471023,
  "created_utc": "...",
  "calendar": { "day": 143, "year": 2, "season": "bloom", "moon_phase": 2 },
  "player": { "money": 0, "expertise": {}, "recipes_known": [], "handler_tier": 2 },
  "creatures": [ ... ],
  "lineages": [ ... ],
  "codex": { "pages": [ ... ] },
  "ranch": { "facilities": [], "nests": [], "works_progress": {} },
  "economy": { "trader_stock": [], "board_commissions": [] },
  "memorial": [ ... ],
  "flags": {}
}
```

**Rules:**

- `save_version` increments on any schema change; a migration function per step, chained. Migrations run oldest to newest on load.
- **Never serialise derived values.** Stats recompute from genome and stored current; a save holding a cached ceiling will silently contradict a rebalanced formula. Store `stat_current` and `stat_overshoot` — never `stat_ceiling`.
- **Content is referenced by id, never embedded.** A save holds `"keen_nose"`, not a copy of the trait record, so rebalancing traits updates existing saves.
- **Dead creatures persist.** The memorial grove, the lineage tree and codex sub-entries all read them. Dead records may be slimmed, never deleted.
- Write to a temp file and rename on success. A crash mid-write must never destroy the previous save.
- **Saving is player-initiated and available from the menu at any time**, plus an end-of-day autosave after the tick completes. Mid-tick state is not a valid save point. **On Hard the manual save is removed entirely** — the game autosaves after every resolved event instead (§31).
- **`lowest_ever` is monotonic** and never rises. Codex entries stamp it, not `current`.
- **The one exception is combat:** the save button is disabled for the duration of a fight (G.4), so an encounter is one committed decision rather than a sequence of re-rollable turns.

---

## F.6 Headless mode

The simulation must run with no rendering, so balance is measurable before content exists.

```gml
sim_run_headless(world_seed, days, policy_struct) -> stats_struct
```

`policy_struct` describes an automated player — which pairings to make, what to cull, what to train. **This is what paper math cannot reach: selection.** Hand-computed averages assume random mating; a real player picks the best animal every generation, and the compounding effect on allele frequencies is not hand-computable across twenty generations.

Questions the harness must answer:

| Question | Measure |
|---|---|
| Trait density | Mean expressed traits per birth; proportion at 0; proportion at 5+ |
| Bridging cost | Generations to bridge a distance-20 pair under a selective policy |
| Offspring volume | Births per creature-life, by maturity tier and care level |
| Inbreeding drift | Mean coefficient over 20 generations on a 6-slot roster |
| Archetype erosion | Axis variance between archetypes after 20 generations of mutation |
| Stat spread | Ceiling gap between a mediocre and a well-bred animal — **must stay above 20%**, or overshoot (E.6) makes breeding advisory |

Run a matrix of seeds, not one. Report distributions, not means — the design lives in the tails.

---

## F.7 Build order

1. `bh_data` + `bh_rng` + schema validation
2. `bh_genome` — genome, expression, gates
3. `bh_breeding` — distance, compatibility, inheritance, mutation
4. `bh_creature` — stats, life stage, derivation
5. `bh_tick` — Appendix A order, exactly as written
6. **`sim_run_headless` — balance harness. Stop and measure before going further.**
7. `bh_save` — snapshot and migration
8. `bh_ranch`, `bh_calendar`, `bh_economy`
9. Presentation: 2.5D renderer, UI, input

**Step 6 is a gate, not a milestone.** Every number in §30 was set by reasoning, not measurement. Building presentation on an unmeasured breeding economy means discovering the economy is wrong after the art depends on it.

---

## F.8 Open against this appendix

- Economy baselines, needed before `bh_economy`
- Auditing all 31 traits and the defect pool into concrete effect records
- Whether the codex painterly pass is a shader or a pre-render to surface
- Policy-struct vocabulary for the headless harness

---

# Appendix G — Combat

Small-grid turn-based tactics. **You are on the field, and you do not control your creatures — you command them, and they interpret.** That gap is the whole design.

## G.0 The twist

In Final Fantasy Tactics or Baldur's Gate, units execute perfectly. Here, Acuity decides whether she understood you — and on a grid, a misread is **spatial**. She goes to the wrong tile.

**Command complexity is gated by Acuity, not command power.**

| Complexity | Example | Misread risk |
|---|---|---|
| Simple | *Attack the nearest thing* | Almost never |
| Moderate | *Move to that tile, then hold* | Some |
| Complex | *Circle to their flank, wait for my mark, break the line* | High |

A low-Acuity creature is not weak — she is **blunt**. She hits as hard as her Power says and you cannot do anything clever with her. A sharp creature unlocks tactical depth. **Acuity is a play-depth stat, not a power stat**, so breeding for it changes how the game plays rather than how much damage you do.

A misread is never a whiff (E.5). She does the wrong *sensible* thing — takes the nearer enemy, breaks a hold early, moves to the tile that looked right. On a grid that is sometimes fine and sometimes catastrophic, and it always reads as an animal making a judgement.

---

## G.1 The handler on the field

**You occupy a tile.** Your position is not flavour:

```gml
misread_chance *= 1 + (handler_distance * HANDLER_DISTANCE_PENALTY)
```

**Distance from a creature raises her misread chance.** Close, she reads your body, your voice, your gesture. Far, she is working from memory and instinct. **Your positioning is your command bandwidth** — and the tiles where you command best are the tiles where you are exposed.

This single rule carries most of the tactical tension: it gives you a reason to move every turn, it makes a dull creature perfectly playable if you stay at her shoulder, and it means splitting the party across the field costs you control of whoever you left behind.

**Your turn, three options:**

| Action | Effect |
|---|---|
| **Reposition** | Move. Changes who you can command well and who can reach you |
| **Rally / Steady** | Restore Nerve, break a fear state, or grant one creature a guaranteed read on her next order. Scales with bond |
| **Item** | Tinctures, Charms, treatment |

You never attack. You are a handler.

### You can be hurt, and you can die

**Injuries you take are real** and carry consequences past the fight. **Death is permanent — game over, reload.** The most dangerous places in the world can kill you, which is what makes choosing to go there mean something (§20).

**But your creatures may save you.** A downed handler is a creature's decision, not a scripted rescue: whether she comes for you depends on bond, on traits, and on what she is.

| Factor | Effect on rescue |
|---|---|
| Bond tier | The dominant term |
| **Singular Bonding** | Near-certain — if you are her person |
| **Vigilant**, **Herd Mother** | Strong |
| **Aloof**, **Lazy** | Weak |
| **Territorial** | Only if you went down on ground she holds |
| Nerve | A creature who has broken will not come |

This is the payoff for the entire raising loop, delivered at the moment it matters most. An animal you bought last week watches. An animal you raised from the egg comes.

### When you are down

**Your creatures fall back on instinct, and temperament drives it.**

| Temperament | Behaviour without orders |
|---|---|
| Feral (0–2) | Attacks the nearest threat, pursues, does not disengage |
| Middle (3) | Holds position, defends itself |
| Placid (4–6) | Defends the downed handler, does not pursue |

This gives temperament its first combat job — until now it fed only Nerve and Acuity ceilings (E.3). It also means a feral party without a handler scatters, while a placid one forms up over you. Neither is better; they are different animals.

---

## G.2 The grid

**Size varies by encounter.** A farm skirmish is tight and cluttered; open wilds are broader. Landscape mobile is the constraint — a grid must be readable at five inches without pinching.

**Party: 2–3 creatures plus the handler.** Enemies scale to the location.

**Initiative is Celerity**, and creatures act individually. You issue a command when her turn arrives; the misread roll happens at execution, so you see the result immediately and can never guarantee it.

---

## G.3 Environment and element

**This is where the element axis finally earns its keep.** Through v3.3 element drove palette, byproduct type, and two feature gates — nothing mechanical. On a grid it becomes tactical:

| Element | Field effect |
|---|---|
| Pyric (0–2) | Ignites oil, dry brush, tar. Leaves burning tiles |
| Neutral (3) | No terrain interaction |
| Hydric (4–6) | Floods tiles, douses fire, leaves standing water |

**And they chain.** Fire into water makes steam — vision blocked. Water plus a storm makes a conductive tile. Water plus frost makes ice — movement becomes unreliable for anyone crossing it.

**Element becomes a breeding target for the adventure path**, which it never was. A pyric and a hydric creature in the same party is a combo engine; two of the same element is raw force.

### Weather is the free content layer

§11's weather generates the terrain. Rain leaves standing water. Storms make lightning conduits of it. Frost freezes it. Fog cuts sight lines and raises misread risk at distance.

**No encounter authoring required** — the same fight in clear weather and in a storm is a different fight. It also makes farm defence during severe weather (§11.2) tactically distinct from the identical fight on a calm day.

**Combos require setup across turns, and setup requires reliable execution.** So the whole combo system is gated behind Acuity, bond, and your positioning. A player with a bought, unbonded party can fight — they cannot *scheme*.

---

## G.4 Stakes

**Danger scales with where you choose to go.** The Hollow's deep places can kill; the near woods bruise. Nothing forces you into either.

- Creature injuries follow §12.3 — most treatable, permanence from untreated, repeated, or catastrophic damage
- **Creature death is possible in the deepest places** and is permanent
- A near-fatal injury survived is an overshoot trigger (E.6) — the breakthrough and the scar arrive together
- Handler death ends the run

**Combat rolls are deliberately not locked** (F.4). Genetic outcomes are fixed at conception and cannot be re-rolled; a fight is skill expression, and reloading one is a normal thing for a player to do.

**But saving is disabled for the duration of a fight.** The player may save freely everywhere else, including immediately before an encounter. Once combat begins the save button is unavailable until it resolves.

Without this, free saving plus unlocked combat rolls lets a player save before every enemy turn and re-roll anything that goes badly — which does not break the breeding game, but hollows out the injury and death stakes entirely. Danger-by-location stops meaning danger and starts meaning slow. The rule keeps a fight a single committed decision while costing an honest player nothing: they saved on the way in.

**A fight is therefore the unit of risk.** You choose to enter it knowing where you are; once inside, what happens happens.

---

## G.5 Open

- Ability set per creature — what she can actually do, and whether abilities are trait-derived or learned
- Command vocabulary: the actual list, and how complexity tiers map to Acuity thresholds
- Enemy roster and encounter tables per location
- `situation_complexity` scale (E.5) — now concretely definable as command tier × distance × fog
- Whether the handler has stats, or only items and bond
- Party formation rules — does Matriarch's larger formation (C.4) mean 4 creatures?
