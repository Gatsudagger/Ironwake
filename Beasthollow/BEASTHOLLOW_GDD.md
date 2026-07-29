# Beasthollow — Game Design Document

*(Supersedes GENETICS_SPEC.md v0.1)*

**Version:** 0.4
**Engine:** GameMaker Studio 2 · **Platform:** Mobile, portrait · **Studio:** Fable 5
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
| **3. Aptitudes** | 4–6 numeric values | Stat variance, partly heritable | Zero |

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

    aptitudes : { vigor, celerity, mass_tendency, fecundity, longevity },

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

1. **Crossover** — each parent contributes one allele at random from its pair.
2. **Conditional blend** — if `abs(parent_A_expressed - parent_B_expressed) >= 2`, then with **10% probability** the inherited pair is replaced by the rounded midpoint of the expressed values.
3. **Mutation** — 2% chance of ±1; 0.3% chance of ±2 which may exceed both parents' range. Clamped 0–6. Mutation rates rise during the Dark moon week and in high-stimulation nests.

Conditional blending means variance appears during adventurous crosses and stays quiet when refining an established line. A flat rate would tax precision breeding for nothing.

Because crossover inherits whole values, distance closes **axis by axis in discrete jumps**. Breeding is assembling a hand of cards, not mixing paint. This puts real weight on archetype placement — intermediates must actually possess the values a bridge requires.

### 5.2 Physical traits

Recessive expression — both copies required. Traits skip generations and reappear.
Trait mutation: 0.1% per locus per birth may create a positive allele from nothing.

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

**Design rule:** one generation of tight breeding to lock a trait, then outcross. That should be the discovered optimum, not a punishment.

### 5.6 Environment biases the roll

Nest and facility quality shift offspring outcomes *before* genetics resolves — trait odds, mutation rate, defect rate, and hatch quality. Ranch investment is therefore genetically meaningful, not merely logistical.

---

## 6. Physical trait expression gates

A locus can be **carried** by any creature but only **expressed** when the phenotype supports it. An art constraint made diegetic.

| Trait | Gate |
|---|---|
| Horn | `frame <= 3` |
| Long fangs | `temperament <= 2` |
| Plumed tail | `integument <= 2` |
| Bioluminescence | `element >= 4` |
| Tusks | `frame <= 2` and high `mass_tendency` |

**This is the core motive for bridging.** A serpentine creature can carry a horn allele indefinitely. Moving that horn onto a creature that can display it requires both the compatibility work and the frame shift — a multi-generation project with a concrete emotional target: *that creature I don't like has the tusks I want.*

### Predicate budget

- ~60% of trait conditions reachable in 1–2 generations
- ~30% requiring one extreme value
- ~10% requiring two or more extremes — chase content

---

## 7. Behavioral traits

**25 at v1**, in four families — Psychological, Sense, Social, Physical. Full tables in **Appendix C**.

Traits are not sorted into separate genetic/learned/acquired lists; each carries **origin flags** (Inherit / Learn / Acquire / Remove) and an optional **variant**. See C.0.

**Genetic (12) — who she is.** Inherited recessively: Territorial, Restless, Glutton, Broody, Vigilant, Placid, Skittish, Hardy, Bold, Fastidious, Sluggish, **Stormsense**.

**Learned (8) — what she was taught.** Acquired in the juvenile window: Share Food, Herd Mother, Patient, Wary, Tidy, Trusting, Foraging Sense, Steady.

Negatives matter as much as positives — "I love her but she's a nightmare in the pen" is real texture, and gives breeding something to breed *out*.

### 7.1 Nesting disposition

A genetic behavioral axis: **Solitary / Communal / Indifferent.**

- Solitary: penalty per nestmate, bonus alone. **Must carry a real upside** (better foraging, superior stress resistance when housed alone) or players breed it out.
- Communal: gains with nestmates, suffers alone.
- Indifferent: flat.

### 7.2 Learning window

Behaviors are learned **during the juvenile stage only**. Elders can re-teach (see Mentoring). This gives the juvenile stage a purpose beyond waiting, and it lands when bond is lowest and care pressure is sharpest.

The juvenile window is approximately **one month long**, which means the season a creature grows up in heavily shapes what she learns — coupling directly to the birth-season imprint.

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
d = 1.5*|metabolism_diff| + 1.5*|frame_diff| + 1.0*|integument_diff|
  + 0.75*|element_diff|   + 0.5*|temperament_diff|
```

Computed on **expressed** values only. Carried recessives don't affect compatibility.
**Threshold:** compatible if `d <= 8`. Biology is harder to bridge than personality.

### 8.2 Species labelling and naming

- Within radius **R** of an archetype → that species name
- Outside every archetype → **strain**, auto-named `FrameArchetype × IntegumentArchetype`, player-renameable

With 15–20 archetypes across ~16,800 phenotypes, most creatures land in unclaimed space. Do not force nearest-neighbour labels. Unclaimed space is where bridge creatures live, where the rarest combinations fire, and where player-named strains become worth showing off.

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

Mass raises HP and damage, lowers speed and evasion. Size is never a strict upgrade.

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

Days are named for the deified guardians of the shrine. Domains colour events and dialogue; **they never gate actions.**

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

**Lifespan range: 120–240 days (1.5–3 years).** Wide diversity by species and individual. Proportions scale with total lifespan.

| Stage | % of life | At 160 days (2 yr) |
|---|---|---|
| Incubation | 2–5 days by rarity/type | 3 |
| Hatchling | 6% | 10 |
| Juvenile *(learning window)* | 12% | 19 |
| Adult *(fertile)* | 58% | 93 |
| Elder *(mentoring)* | 24% | 38 |
| Degradation *(tail of elder)* | last 5% | 8 |

**Gestation: 4–5 days**, fixed regardless of species — so short-lived archetypes turn generations much faster relative to their own lives.

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

Injuries from the wilds, trials, and severe weather **permanently reduce expectancy**. This is the price tag on the adventure path: the breeder's animals live longer because they were never at risk; the adventurer's live shorter and better.

Healers, the shrine, and restorative items acquire real weight from this.

### 12.4 Fertile span

```
fertile_fraction = species_base (0.55–0.75)
                 + trait_modifiers (±0.10)
                 + individual_roll (±0.05)
```

**Sex is part of the genome and gates breeding** (Appendix C.9). Fertility: base 3 clutches, modified by `fecundity`. **Parents survive breeding** — they spend fertility, not lives. With gestation at 4–5 days, fertility rather than time is the binding constraint.

### 12.5 Retirement

**Retirement is the player's decision, not automatic.**

Disposition bias:
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

Lifespan is **never a number in the UI**. Precision arrives as dialogue, scaled to expertise:

| Expertise | What you hear |
|---|---|
| Novice | "She has many seasons yet." |
| Practised | "She's past her prime but strong." |
| Expert | "Three, maybe four. I'd start thinking about it." |

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

**Eligibility:** elder past fertility, bond tier 4+.
**Action:** elder and juvenile share a nest for a stretch of days.
**Effect:** the juvenile gains one permanent Lesson drawn from the elder's own life.

**Limits:** one Lesson per creature ever, one apprentice per elder.

**The detail that lands:** the Lesson carries the elder's name. *Maple's Patience* sits permanently on a living creature and nothing else in the world.

### 13.4 The lineage tree

The real collection artifact — not a species dex. Every creature raised, living and passed, connected. Passed creatures never leave it.

### 13.5 Deification

Late-game quests yield **legendary artifacts** extending life far beyond natural limits. Nothing lasts forever; the player must still make their peace.

A creature carried that far may, on passing, **ascend** — becoming an aspect that blesses the shrine and joins the five guardians in the sanctuary's veneration. A permanent ranch-wide boon, achievable perhaps once or twice in a long playthrough.

### 13.6 The starter egg

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
| Feeding trough | Fullness → size growth | 4 | 9 | 16 |
| Grooming station | Bond gain | 4 | 9 | 16 |
| Enrichment yard | Affinity, stress relief | 4 | 9 | 16 |
| Nursery | Gestation, hatch quality, egg capacity | 2 | 5 | 9 |
| Weathervane | Forecast range | — | — | — |

Cost roughly triples per tier. Duplicates buildable where plots allow.

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
| Start | 6 | T1 (4) |
| Early | 10 | T1→T2 |
| Mid | 16 | T2 (9) |
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

```
comfort = distance(creature_preference, effective_environment)
```

Preference derives from phenotype, chiefly integument and metabolism. Serious mismatch means steady stress, never a hard block.

Nest materials come from foraging.

**Nest warmth biases offspring sex for ectotherm species** (Appendix C.9) — making nests a breeding tool, not only a comfort system.

### 16.3 Seasonal effects

Seasons touch **everything**: comfort, foraging yields, breeding, growth rates, aging.

**Birth-season imprint.** A hatchling's birth season permanently shifts its comfort preference toward those conditions and biases which behaviors come easily — winter-born lean Hardy and Wary, summer-born lean Bold and Curious.

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
| 3 | Carried recessives — axes and trait loci |
| 4 | Predicted compatibility distance between any two creatures |

Tier 3 is the inflection point: before it, breeding is folklore; after it, engineering.

**Strains stay mysterious.** Because familiarity averages down for hybrids, unclaimed phenotype space is genuinely harder to read no matter how expert you become.

---

## 18. The Board — commissions

Generated from the player's **capability envelope** (phenotypes reachable within ~1–3 generations of owned stock), mixed with fixed difficulty tiers. The player opts into difficulty for scaled rewards.

One persistent **stretch commission** sits on the board at all times: deliberately beyond current reach, no expiry.

### 18.1 Rewards

**Money is never the reward for hard commissions.** Money problems are solvable by grinding easy ones; scarce goods belong behind difficulty.

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

**No crafting trees.** Materials are direct inputs to nests and Works projects and nothing else.

---

## 20. Acquisition and adventure

### 20.1 Sources

**Wild capture and traders both**, wild stock rarer. Outcrossed stock is essential (§5.5) — the trader and the wilds are the release valve on inbreeding.

**Wild and traded creatures arrive at varied ages, including elderly.** Thematically exact for a sanctuary, and it means a player experiences the full life arc — bonding, mentoring, degradation, passing, a marker in the grove — within a few hours rather than after thirty. It also creates a genuinely affecting early decision: you find an old animal in the ruins with perhaps a season left. Do you take her in anyway?

### 20.2 Foraging

- *Creature-sent* — costs days and fatigue; yield scales with traits (Foraging Sense). You continue other work.
- *Player-led* — costs your day, but you see what's there and choose, and may bring one creature whose traits open options.

Reachable wild areas are gated by cleared plots, so acquisition grows out of ranch progression.

### 20.3 Adventures

Multi-day expeditions into biomes with your party of 1–3. **Not time compression** — adventure days are the *densest* days in the game, with active combat, exploration, and encounters. A single adventure day may take longer to play than a ranch week.

While away, the ranch tick still runs, resolved by a hired **farm-sitter**. This is delegation, not fast-forward — you return to consequences. A cheap hand does a poor job.

Adventures yield experience, rewards, materials, rare stock, and deep bonding — and risk injury, which permanently costs lifespan (§12.3).

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

Trials read from the same genome and stats as everything else. No bespoke show stats.

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
| **Ranch view** | Top-down, walkable, tap-to-move. Creatures wander. Stations open menus. |
| **Creature view** | Full-screen, high-res composite on a painted diorama, idle animation, tap parts to inspect. |
| **System screens** | Menu overlays — breeding, appraisal, the Board, the Works. |

**The ranch view carries ambience only. No mechanic lives there.** The walkable layer stays shallow; emotional weight sits in the creature view. The ranch expands as the player progresses.

Tap-to-move. No virtual stick on a portrait phone.

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
- Inbreeding coefficient thresholds and defect table
- Emergency mini-game design
- Artifact and deification quest design
- Trial disciplines and scoring
- Consequence event system architecture
- Creature stat block for trials and combat
- Economy baselines — prices and payouts
- Save structure and offline handling

---

## 30. Tuning constants

```gml
#macro AXIS_STEPS            7
#macro COMPAT_THRESHOLD      8
#macro BLEND_CHANCE          0.10
#macro BLEND_MIN_GAP         2
#macro MUT_CHANCE_1          0.02
#macro MUT_CHANCE_2          0.003
#macro TRAIT_MUT_CHANCE      0.001
#macro BASE_FERTILITY        3
#macro PASTURE_SLOTS_START   4
#macro DAYS_PER_WEEK         5
#macro WEEKS_PER_SEASON      4
#macro SEASON_DAYS           20
#macro SEASONS_PER_YEAR      4
#macro YEAR_DAYS             80
#macro LIFESPAN_MIN_DAYS     120
#macro LIFESPAN_MAX_DAYS     240
#macro GESTATION_DAYS        4
#macro CARE_FLOOR            0.4
#macro GRACE_T1_DAYS         3
#macro GRACE_T2_DAYS         5
#macro GRACE_T3_DAYS         8
#macro NEST_MOD_MAX          2
#macro PARTY_MAX             3
```

All numbers are prototyping baselines. Agree changes here before editing dependent code.

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
Fullness decay. Fatigue accrual or recovery. Bond decay under sustained neglect (floored — never to zero from neglect alone). Byproduct accrual, scaled by comfort.
*Must run after 6 so stress feeds these.*

**8. Affinity**
Growth for co-nested pairs. Rate scaled by phenotype distance (speed only, never ceiling), nest quality, and both creatures' stress.

**9. Growth**
Size progress toward `ceiling * maturity(age) * care_score`. Reads today's fullness and comfort.

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

| # | Archetype | Met | Int | Frm | Ele | Tmp | Lifespan | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | **Stiltling** | 0 | 0 | 0 | 5 | 3 | 200 | Heron-like. Upright extreme, feathered, wading. |
| 2 | **Rapt** | 0 | 0 | 2 | 1 | 1 | 170 | Raptor. Fast, fierce, dry-country. |
| 3 | **Corvid** | 0 | 0 | 3 | 3 | 2 | 220 | Clever, long-lived, unsettling. |
| 4 | **Emberhound** | 0 | 1 | 2 | 0 | 1 | 160 | Pyric extreme. Warm-blooded, furred, hot. |
| 5 | **Lupin** | 1 | 1 | 2 | 2 | 1 | 150 | Wolf-like. The baseline predator. |
| 6 | **Ursine** | 1 | 1 | 1 | 3 | 3 | 230 | Bear-like. Heavy, long-lived, deceptively calm. |
| 7 | **Cervine** | 1 | 1 | 2 | 4 | 5 | 170 | Deer-like. Skittish, graceful. |
| 8 | **Woolback** | 1 | 0 | 2 | 3 | 6 | 210 | Placid extreme. Hardy, gentle, unglamorous. |
| 9 | **Bristleback** | 1 | 2 | 2 | 2 | 1 | 150 | Boar. Coarse-coated, bad-tempered, durable. |
| 10 | **Fenling** | 2 | 2 | 3 | 5 | 3 | 130 | Marsh mustelid. Short-lived, playful, quick generations. |
| 11 | **Thornbeast** | 2 | 6 | 2 | 3 | 4 | 220 | Armoured herbivore. Scale extreme on a limbed frame. |
| 12 | **Delver** | 2 | 1 | 4 | 4 | 4 | 130 | Burrower. Low light, low drama, fast turnover. |
| 13 | **Draik** | 3 | 6 | 3 | 0 | 0 | 240 | Small drake. Feral and pyric extremes, long-lived. |
| 14 | **Mistling** | 4 | 3 | 4 | 6 | 6 | 210 | Fog-dweller. Hydric and placid extremes. |
| 15 | **Coilkin** | 5 | 5 | 6 | 3 | 2 | 180 | Serpentine extreme. |
| 16 | **Stonegaze** | 5 | 6 | 5 | 2 | 1 | 230 | Basilisk-adjacent. Slow, scaled, dangerous. |
| 17 | **Newtling** | 6 | 4 | 5 | 5 | 5 | 120 | Shortest-lived. Excellent breeding stock. |
| 18 | **Salamandra** | 6 | 4 | 5 | 6 | 4 | 160 | Ectotherm and hydric. The classic bridging target. |
| 19 | **Boggart** | 6 | 5 | 4 | 6 | 5 | 130 | Toad-kin. Damp, placid, homely. |

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
- **Traits** — behavioral. Organized into four families. 25 at v1.

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

### Expression density

Expression is per-trait and independent. **Nothing enforces one trait per family** — a creature may express three Sense traits and nothing else, and some creatures express none at all. That is intended: it makes trait-rich animals a genuine find.

**Tuning target:** average creature expresses 2–3 traits; exceptional ones 5+; roughly one in six expresses none. Allele frequency in the wild population is the single knob controlling this.

### Practical and combat effects

Every trait has a **practical effect** on ranch, breeding, or adventure life. Most also have a **combat correlate** that follows naturally from the practical one. Where no sensible combat reading exists, the trait simply has none — correlation is not forced.

---

## C.1 Features (16)

Recessive expression. A locus may be **carried** by any creature regardless of phenotype; the gate governs **expression** only.

**Gating principle:** a gate exists when the feature cannot plausibly sit on that body — referencing **frame** (owns silhouette) and **integument** (owns texture), plus mass where relevant. Two **thematic** gates are retained where the axis owns the visual channel the feature uses. Temperament never gates morphology.

**Variants may carry their own gates.** Feathered Pinions need `integument <= 2`; membranous Pinions need `integument >= 4`. Same locus, opposite requirements — bird wing versus bat wing. This makes one feature a bridging target in both directions.

| # | Feature | Anchor | Gate | Type | Variants |
|---|---|---|---|---|---|
| 1 | **Horn** | head | `frame <= 3` | anatomical | single / paired / spiral |
| 2 | **Crest** | head | *by variant* | anatomical | feathered (`int <= 3`) / membrane (`int >= 4`) |
| 3 | **Long Fangs** | jaw | none | free | sabre / needle |
| 4 | **Talons** | limb | `frame <= 4` | anatomical | hooked / broad / retractable |
| 5 | **Frill** | head | `integument >= 3` | anatomical | bone / membrane |
| 6 | **Barbels** | jaw | `element >= 3` | thematic | — |
| 7 | **Split Tail** | tail | none | free | twin / forked |
| 8 | **Heterochromia** | eye overlay | none | free | — |
| 9 | **Mane** | head + spine | `integument <= 2` | anatomical | full / ruff |
| 10 | **Plumed Tail** | tail | `integument <= 2` | anatomical | fan / streamer |
| 11 | **Spined Ridge** | spine | `integument >= 4` | anatomical | sail / spikes |
| 12 | **Bioluminescence** | palette + glow | `element >= 4` | thematic | spots / veins |
| 13 | **Webbed Feet** | limb | `frame <= 4` | anatomical | — |
| 14 | **Tusks** | jaw | `frame <= 2` + high mass | anatomical | upper / lower |
| 15 | **Pinions** | spine | *by variant* | anatomical | feathered (`int <= 2`) / membrane (`int >= 4`) |
| 16 | **Carapace** | spine | `integument >= 5` | anatomical | plated / segmented |

**Total parts: ~30** across 16 loci. Linear, not multiplicative — every part composites onto any of the 7 base bodies via anchors.

**Anchor load:** head 3, jaw 3, spine 3, limb 2, tail 2, overlay 3. Evenly spread.

**Cross-gate opportunities.** Mane (`integument <= 2`) and Carapace (`integument >= 5`) can never be expressed by the same creature, though a lineage can carry both. Feathered Pinions and membranous Pinions likewise sit at opposite integument poles. These impossible-together pairs are what drive long breeding projects.

---

## C.2 Psychological (7)

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

**Resource Guarding is acquirable from neglect** — specifically, from being the lowest-bond creature during sustained facility overload. She learned that food isn't guaranteed. It persists long after the ranch is fixed, it is hard to remove, and it is the player's fault.

**Fixated** is a creature under pressure developing a coping behavior that makes her worse at work. Accurate, and quietly sad. Partial removal through patient care makes her a redemption project rather than a write-off.

---

## C.3 Sense (6)

Perception. The adventurer's family.

| Trait | Kind | Practical | Combat | I | L | A | R |
|---|---|---|---|---|---|---|---|
| **Stormsense** | ± | +1 day forecast; calms nestmates in severe weather. Unwilling to range far — reduced forage yield | Pre-encounter warning in weather | ✓ | — | — | — |
| **Keen Nose** | + | Trail tracking; enables find-quests; turns up small finds around the farm | Tracks fleeing enemies, detects ambush | ✓ | ✓ | — | — |
| **Empath** | + | Reads *states* in other creatures — illness, pregnancy, stress, readiness | Reads enemy condition and intent | ✓ | ✓ | — | — |
| **Night Eye** | ± | Operates in darkness; stronger during the Dark and the Hollow. Suffers in High Sun | No darkness penalty; penalty in bright light | ✓ | — | — | — |
| **Sixth Sense** | rare + | Unlocks certain quests and requests; communes with the passed | Perceives hidden and spirit enemies | ✓ | — | — | — |
| **Danger Sense** | ± | Warns of ambush — but refuses to advance into risk | Cannot be surprised; may refuse to engage | ✓ | — | ✓ | — |

### Keen Nose

Physical scent tracking. Follows trails on adventures, enables find-quests (a lost child, a strayed creature, a stolen item), and produces small finds around the farm every few days — which gives a non-adventuring player a reason to want her too.

### Empath

Reads **states, never genetics** — illness, pregnancy, stress, breeding readiness, nearing the end. She never reveals axes or carried recessives. This preserves the expertise ladder: expertise reads the genome, Empath reads the animal.

### Sixth Sense

The game's most distinctive trait.

**Gating is hybrid.** It opens meaningful content, special events, and unique items, but never blocks overall progression — the game has no hard linear path, only cumulative unlock. Rare enough to feel like a revelation; findable enough that a player who wants one can go get it (a specific archetype carries it more often, and the Wildspeaker can point toward a carrier).

**Communing** happens at **Hollownight** with the player's own passed creatures, and with the **pre-existing shrine ghosts** — the previous caretaker's animals, whose markers are in the grove on day one. Those ghosts deliver the sanctuary's history directly, giving the same lore two routes: Founding delivers fragments annually, Sixth Sense lets a player go and ask.

Sixth Sense is also useful in any ghost event, request, or quest.

**What she brings back:** a memory that advances the sanctuary's history, a Keepsake that shouldn't exist, or knowledge of where something was buried.

**This gives the memorial system an ongoing role.** Without it, the grove only pays out at the moment of death.

---

## C.4 Social (6)

How she is with others. Note that **bond** (creature ↔ player) and **affinity** (creature ↔ creature) are separate values, and Social traits act on both.

| Trait | Kind | Practical | Combat | I | L | A | R |
|---|---|---|---|---|---|---|---|
| **Vigilant** | ± | Reduces stress for all nestmates; costs her own rest | Party cannot be surprised | ✓ | — | — | — |
| **Herd Mother** *(gendered)* | + | Juveniles in her nest bond faster and learn more readily | Buffs younger party members | rare | ✓ | — | — |
| **Share Food** | + | Splits her bond gain with the lowest-bond nestmate | Shares recovery with an ally | rare | ✓ | — | — |
| **Singular Bonding** | ± | One attachment only — extraordinary with it, poor with everyone else | Large bonus fighting alongside her bonded | ✓ | — | ✓ | — |
| **Aloof** | ± | Slow bond growth; ~20% resistant to negative impacts such as poor-nest decay | Resists morale swings; gains nothing from party buffs | ✓ | — | — | — |
| **Territorial** *(3 variants)* | − | Slows affinity growth — toward all, toward other species only, or toward its own kind only | Bonus defending home ground | ✓ | — | — | — |

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

## C.5 Physical (6)

Constitution and body.

| Trait | Kind | Practical | Combat | I | L | A | R |
|---|---|---|---|---|---|---|---|
| **Hardy** | ± | Reduced injury severity; slower bond growth | Damage resistance | ✓ | — | — | — |
| **Broody** | + | Faster fertility recovery, self and nestmates | — | ✓ | — | — | — |
| **Tolerant** *(4 variants)* | + | Widens comfort range — cold, heat, damp, or dry | Resists matching elemental damage | ✓ | — | ✓ | — |
| **Glutton** | ± | Reaches size ceiling faster; consumes 2 feeding slots | Higher stamina pool | ✓ | — | ✓ | partial |
| **Sluggish** | ± | Lower fatigue accrual; reduced celerity | Low initiative, high endurance | ✓ | — | — | — |
| **Frail** | − | Higher injury severity, shorter expectancy | Takes increased damage | ✓ | — | — | — |

**Tolerant is the variant system doing real work** — one trait, four variants, plugging directly into places, nests, seasons, and weather. A cold-tolerant creature can live in the brook through the Hollow without needing a burrow.

**Longevity remains an aptitude**, not a trait. It is already a numeric genome value; duplicating it would give two systems the same job.

---

## C.6 Balance summary

| Family | + | ± | − | Total |
|---|---|---|---|---|
| Psychological | 3 | 1 | 3 | 7 |
| Sense | 2 | 3 | 1 | 6 |
| Social | 2 | 3 | 1 | 6 |
| Physical | 2 | 3 | 1 | 6 |
| **Total** | **9** | **10** | **6** | **25** |

**Defect pool.** High inbreeding coefficients (§5.5) draw from a separate negative-only list that is *not* part of the 25 and never a breeding target: Frail Constitution, Poor Sight, Barren, Malformed, Anxious. These are what goes wrong, not what you chase.

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

**More fantastical species** will carry elemental relationships between their traits and their sexes, to be designed alongside those archetypes.
