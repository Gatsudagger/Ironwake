# DESIGN — World Expansion: Creatures, Biomes, Descent Bosses, Awakened Forms

**Status: DRAFT 2026-08-06 — awaiting M's design-lock.** No code written, no art
generated. Scope set by M: 10 new generic pets + 5 Descent pets, unique Descent
bosses every few floors, more boss variety, new biome dungeons, pet types
segregated by dungeon, and a full Awakened-form art pass across every species.

Origin: M noticed while reviewing achievement icons that the roster has no bear.

---

## 0. Where we stand today (verified in code, not assumed)

| Thing | Current state |
|---|---|
| Generic pet species | **16** — `pet_species_catalog()`, 8 original + 8 from the 07-31 expansion |
| Signature pet species | **9** — `pet_species_signature_catalog()`, one per boss, keyed `dungeon`+`floor` |
| Dungeons | **3** — `ashen_vault`, `scorched_depths`, `tundra_tomb` |
| Bosses | **9** — three per dungeon, floors 1/2/3 |
| Awakened (stage 4) | Has **no distinct art**. `pet_sprite_stage()` returns `"adult"` for stage ≥ 3; Awakened is conveyed by an aura tint (`pet_aura_color`) + splash art only |
| Descent | Endless floors, each drawing a **random** existing dungeon theme and ending in that theme's normal floor boss |
| Species art-gating | `pet_species_random()` filters on `pet_species_has_art()` — **species without sprites never roll**, so catalog entries can ship ahead of art safely |

Two facts that shape everything below:

1. **Art-gating already exists and works.** Every species and biome in this doc
   can be wired into the catalogs immediately and stay invisible until its art
   lands. Design and art are decoupled; we never need a big-bang art drop.
2. **Awakened has never actually looked different.** This is the single biggest
   payoff-vs-effort item in the doc — the stage exists, the player earns it, and
   the creature on screen doesn't change shape.

---

## 1. Ten new generic creatures

Design rules honored: creatures, never humanoid; one always-on innate each;
innates stay small and always-true (they are what the creature *is*).

| # | id | Name | Blurb | Innate | fx | Plumbing |
|---|---|---|---|---|---|---|
| 1 | `cairn_bear` | Cairn Bear | a cub that sleeps under stacked stones and wakes heavier | **Standing Weight** — you cannot be knocked below 1 HP by the first hit of a combat | `last_stand` | NEW |
| 2 | `ember_ram` | Ember Ram | horns that glow like coals banked overnight | **Banked Heat** — +3 bonus Fire damage on your first attack each combat | `first_fire` | NEW |
| 3 | `salt_hare` | Salt Hare | quick, twitchy, tastes of the flats it crossed | **Bolt** — +1 starting AP in the first combat of each floor | `floor_ap` | NEW |
| 4 | `mire_heron` | Mire Heron | stands still so long the water forgets it | **Patient Strike** — +4% Phys Crit if you spent no AP last turn | `patient_crit` | NEW |
| 5 | `gravel_tick` | Gravel Tick | a pebble that turns out to have legs | **Cling** — Bleed you apply lasts 1 extra turn | `dot_turns` | reuse |
| 6 | `ashjaw_lynx` | Ashjaw Lynx | soot-furred, hunts by the heat of you | **Heat Sense** — +5% damage to Burning enemies | `vs_burning` | NEW |
| 7 | `glass_eel` | Glass Eel | transparent but for a thread of silver spine | **Slipstream** — +1 El Resist while it is your companion | `el_resist` | reuse |
| 8 | `chapel_bat` | Chapel Bat | roosts where prayers were loudest | **Vespers** — heal 2 HP whenever you clear a combat room | `room_heal` | NEW |
| 9 | `barrow_mole` | Barrow Mole | digs toward things that should stay buried | **Turned Earth** — +6% chance of an extra item from floor caches | `cache_find` | NEW |
| 10 | `tallow_moth` | Tallow Moth | fat, slow, drawn to the last candle | **Guttering Light** — +5% to healing you *give* your companion (feeding, garden) | `pet_heal` | NEW |

Seven of ten need a new innate hook. All seven are one-line reads of existing
state; none needs new combat plumbing beyond a lookup at an existing site. If
you want to cut scope, `gravel_tick` and `glass_eel` are free today.

**Deliberate spread:** the roster leans reptile/undead/insect. These add
**mammal weight** (bear, ram, hare, lynx, mole) which is exactly the gap the
missing bear exposed.

Three of these (`mire_heron`, `glass_eel`, `tallow_moth`) are natural residents
of the new biomes and appear again in §3 under their home biome — they are
counted once, here. Biome assignment for the whole roster is in §5.

---

## 2. Five Descent creatures

The Descent gets creatures in **two distinct classes**, matching how the rest of
the game already works. Neither is depth-gated — both are pure rarity, so a
player who plateaus at floor 12 can still eventually own all of them.

### 2.1 Warden scions — rare drops, one per Depth Warden

**Universal rule proposed: every boss in the game has a scion.** The nine dungeon
bosses already do. The nine Depth Wardens (§4) get the same treatment — a
`signature:true` species that drops *only* from that Warden, at a low rate. This
reuses `pet_species_signature_catalog()` and the whole existing scion pipeline
(the `scions_hatched` set, ACH_SCION_1/2/ADULT, "kin of…" UI) with zero new
systems — Wardens just need `dungeon:"descent"` instead of a dungeon key.

| Warden | Scion | Blurb | Signature move (once per combat) |
|---|---|---|---|
| The First Door | `doorling` | Doorkeeper's Cat | it never left its post | **Held Open** — you take no damage from the first enemy to act |
| Sister Fathom | `fathom_squid` | Fathom Squid | it has never seen light and does not miss it | **Ink Fathom** — the first enemy to target you loses its turn to the dark |
| The Tally | `tallykeep` | Tallykeep | it counts on toes it does not have | **Reckoning** — every 3rd ability you cast deals +20% damage |
| Hollowlight | `lantern_wyrm` | Lantern Wyrm | the light on its head is not its own | **Borrowed Light** — the first time you drop below 50% HP, heal 15% max HP |
| The Weight of Ironwake | `deepclaw` | Deepclaw | carries a floor of the Descent on its back | **Deadweight** — the first enemy to act is slowed, acting last for 2 turns |
| The Long Arithmetic | `sum_moth` | Sum Moth | its wings show a number that keeps changing | **Carry the One** — your first overkill damage each combat carries to another enemy |
| Nothing In Particular | `null_hound` | Null Hound | a dog-shaped absence that heels anyway | **Nothing Follows** — the first debuff applied to you is erased |
| The Understudy | `mimicling` | Mimicling | it is doing an impression of your last companion | **Understudy** — it copies the innate of the last creature you had active |
| **The Hollow Crown** | `griefwisp` | Griefwisp | it carries a crown far too big for it | **Abdication** — the first elite or boss ability each combat costs it its next turn |

**Drop rate: 4% flat** off the keyed Warden. Wardens recur on the five-floor
cadence forever, so this is a fishing expedition at whatever depth you can
survive — no wall, just odds.

### 2.2 General Descent creatures — not boss-bound

Four species that exist *only* in the Descent but drop from nothing in
particular. These are the "I went down there and came back with something"
creatures, and they can surface on floor 2 as easily as floor 40.

| id | Name | Blurb | Innate | Source |
|---|---|---|---|---|
| `pressure_snail` | Pressure Snail | its shell is denser than it has any right to be | **Deep Shell** — +2 Armor while it is your companion | ~3% egg roll, any Descent floor cache |
| `flicker_finch` | Flicker Finch | it is only ever mostly here | **Flicker** — +8% chance the first blow aimed at you misses | ~3% egg roll, any Descent floor cache |
| `rust_vole` | Rust Vole | eats iron, leaves the good bits | **Scavenged Ore** — +10 gold per elite killed | Descent room event *The Rust Nest* |
| `paleswimmer` | Paleswimmer | eyeless, and it does not react to you at all | **Undertow** — enemies that strike you have an 8% chance to be Weakened for 1 turn | Descent room event *The Still Pool* |

Both room events are one-offer-per-descent, so stacking them means descending
repeatedly rather than farming a single long run.

**Why rarity instead of depth gates:** the Descent already asks "how deep dare
you go" through Depthforged gear and push-your-luck banking. A second depth
ladder would just restate that question. Rarity asks a different one — how many
times will you come back.

⚠ **Drop-rate flag:** 4% off a Warden is roughly one scion per 25 kills of that
specific Warden. Across nine scions that is a *very* long chase. Fine if you want
these to be a season-long collection; raise to ~10% if you want them inside a few
evenings. Flagging rather than deciding.

---

## 3. New biome dungeons

**Two designed in full below**, taking the roster to **five dungeons, 15 bosses**.
A third (Stormcrag) is left as a sketch in §3.3 so we don't over-commit.

Each follows the existing shape exactly: three floors, three bosses on floors
1/2/3, a standard enemy pool, an elite pool, a floor passive, a background set,
and a single weakness identity. **Each boss carries a scion** (§2.1's universal
rule), and each biome brings **four generic creatures** of its own — the
collector pull M is after.

---

### 3.0 World difficulty ladder (DESIGN-LOCKED 08-27, supersedes "follows the existing shape exactly" on difficulty)

> **BUILT 08-27 (code-complete, awaiting M's F5):** offsets + `awakening_effective()`
> wired through enemy scaling/AI/loot/gold/XP/floor length; chained A2 unlocks with
> "?" mystery cards, card-flip reveal popup, save migration, both coach-marks, and
> the 5-card carousel (mod-3 hardcode generalized). §3.1 + §3.2 rosters, bosses
> (with bespoke hooks), floor passives, bestiary, scion plumbing all live.
> **ART/AUDIO PENDING:** dungeon card art (`spr_dungeon_drowned_reach` /
> `spr_dungeon_hollow_canopy`), combat/floor-map backgrounds + 2.5D plane pairs
> (`drowned` / `canopy` tags resolve by string and fall back gracefully), enemy
> sprites (stand-ins from the shipped roster, Depth-Warden precedent), ambience
> beds (borrowing tundra/ashen). Steam achievements for the new dungeons: not
> created (needs Steamworks work).

The five dungeons are no longer parallel same-baseline zones — the **world itself
is the difficulty ladder**. Each dungeon gets a **baseline Awakening offset**,
added to `selected_ascendance` everywhere the tier feeds enemy scaling, loot,
gold, and floor length. Each dungeon keeps its own selectable A0–A5 ladder and
existing `dungeon_ascendance_unlocked` save data untouched; the offset is
invisible math plus visible framing.

| Dungeon | Offset | Effective range | Role |
|---|---|---|---|
| Ashen Vault | +0 | A0–A5 | Teaching dungeon (no floor passive — the starter) |
| Scorched Depths | +1 | A1–A6 | Early-mid |
| Tundra Tomb | +2 | A2–A7 | Mid |
| Drowned Reach | +4 | A4–A9 | Late |
| Hollow Canopy | +5 | A5–A10 | Current peak |

**Rules (all locked with M via scope questions 08-27):**

1. **Floor length follows the EFFECTIVE tier** (base + offset) through the 08-27
   awakening-scaled floor-length curve — Drowned Reach A0 runs ~7 layers by
   design; new biomes feel like long late-game dives.
2. **Loot/gold scale off the effective tier** so harder always visibly pays more
   (Isaac-Repentance lesson: elevated difficulty without elevated reward reads
   as a tax). Check the existing `true_asc` guard in `drop_weights`
   (scr_stats.gml ~2733) when wiring — it exists to catch inflated asc values.
3. **Chained unlocks, A2 keys**: Ashen Vault A2 unlocks Scorched Depths →
   Scorched A2 unlocks Tundra Tomb → Tundra A2 unlocks Drowned Reach → Drowned
   Reach A2 unlocks Hollow Canopy. The gate is always shallow — two tiers into
   content you're already geared for — never a full re-climb (Slay-the-Spire
   re-climb grind is the anti-pattern; Diablo-4 World Tier backlash is the
   hard-gate anti-pattern).
4. **Hidden "?" cards + reveal moment**: locked dungeons appear in the select
   carousel as mystery cards (question-mark face) so players know content
   awaits. On unlock, a popup plays the card revealing itself — new card art +
   dungeon name shown. (Carousel is currently hardcoded `mod 3` in
   obj_hub_controller Draw_64 ~1136 — must generalize to N cards with hidden
   states.)
5. **Two coach-marks** (existing `tutorial_catalog`/`try_show` system):
   - *First dungeon launch*: what Awakening tiers do, that dungeons themselves
     have baseline strength, climb to unlock the next.
   - *First biome-tier reveal* (Drowned Reach unlock): "these depths start at
     Awakening IV strength" — advice framing, not a wall (Elden Ring
     Shadow-of-the-Erdtree lesson: endgame-tuned zones land only when the
     tuning is explicitly communicated).
6. **Card UI shows the baseline** ("Baseline: A4") reusing the existing tier
   color language (select screen already goes red at A4+).
7. **Save migration**: existing saves keep everything already unlocked — any
   dungeon with `dungeon_ascendance_unlocked > 0` or `dungeon_clears > 0` is
   revealed and enterable regardless of the new chain. No player loses access
   they had.

---

### 3.1 The Drowned Reach (`drowned_reach`)

*A flooded undercity. The water is knee-high on the first floor and over your
head by the third. Nothing down here has been dry in a very long time.*

- **Weakness identity:** everything is soaked → **Shock-weak** (Arcane on the wraith-likes)
- **Floor passive:** *Rising Water* — every 3rd turn every combatant loses 2 HP. No one out-waits the tide.
- **Tone:** green-black, lantern light on moving water, distant bells

**Standard pool (8):** Drowned Deckhand · Reach Eel · Bloatling · Silt Wraith ·
Barnacle Thrall · Tide Crawler · Sunken Chorister · Kelp Hound

**Elite pool (4):** The Long Drink · Anchor Revenant · Deepwater Sentinel ·
Pale Fisher

**Bosses + scions:**

| F | Boss | Weakness | Hook | Scion | Signature move |
|---|---|---|---|---|---|
| 1 | **The Tidewright** | shock | Alternates flood/ebb turns; flood turns halve your healing | `sluice_otter` — Sluice Otter · *it lived in the lock-works and still wears one* | **Ebb** — the first heal you receive each combat is doubled |
| 2 | **Choirmother of the Deep** | shock | Summons Choristers; her damage scales with how many still sing | `chorister_fry` — Chorister Fry · *it hums the part it was taught* | **Descant** — the first time an enemy summons, that summon arrives at 1 HP |
| 3 | **Leviathan Below** | arcane | Occupies the whole arena; you fight the parts of it that surface | `leviathan_calf` — Leviathan Calf · *enormous, eventually* | **Something Larger** — once per combat, the first enemy to strike you takes 25% of its own max HP |

**Biome creatures (4 generic):**

| id | Name | Blurb | Innate |
|---|---|---|---|
| `mire_heron` | Mire Heron | stands still so long the water forgets it | **Patient Strike** — +4% Phys Crit if you spent no AP last turn *(moved here from §1)* |
| `glass_eel` | Glass Eel | transparent but for a thread of silver spine | **Slipstream** — +1 El Resist *(moved here from §1)* |
| `lockjaw_turtle` | Lockjaw Turtle | it has decided about you already | **Set Jaw** — your Bleeds deal +1 damage per tick |
| `drowned_lamp` | Drowned Lamp | a fish carrying a light no water puts out | **Wet Light** — +5% to event stat-checks in flooded and dark rooms |

---

### 3.2 The Hollow Canopy (`hollow_canopy`)

*A forest that grew over the ruins, and then over itself. The canopy is so thick
the floor has forgotten daylight. Things up in the branches are watching.*

- **Weakness identity:** everything is overgrown and dry-rotted → **Fire-weak** (Arcane on the spore-minds)
- **Floor passive:** *Choking Growth* — the **first** ability you cast each combat costs +1 AP. Openers get punished; the fight rewards a cheap first move.
- **Tone:** deep green and bone, shafts of light, pollen in the air

**Standard pool (8):** Bramble Husk · Rootbound Corpse · Spore Moth ·
Canopy Stalker · Thicket Boar · Witchwood Sapling · Moss Wraith · Hollow Nester

**Elite pool (4):** The Grafted Knight · Sporemind · Old Growth · The Nest

**Bosses + scions:**

| F | Boss | Weakness | Hook | Scion | Signature move |
|---|---|---|---|---|---|
| 1 | **The Grafted Stag** | fire | Every wound sprouts; unhealed wounds become adds after 3 turns | `graftling` — Graftling · *antlers already, and it is very small* | **Take Root** — the first enemy add each combat arrives Rooted |
| 2 | **Mother Bramble** | fire | Walls of thorn cut the arena; reaching her costs AP | `thornlet` — Thornlet · *it hugs, and you bleed a little* | **Bramble Wall** — once per combat the first enemy attack on you is stopped outright |
| 3 | **The Green Silence** | arcane | Silences one ability per turn; the fight gets quieter | `quietbud` — Quietbud · *it has never made a sound* | **Held Breath** — the first ability silenced or disabled each combat is refunded |

**Biome creatures (4 generic):**

| id | Name | Blurb | Innate |
|---|---|---|---|
| `tallow_moth` | Tallow Moth | fat, slow, drawn to the last candle | **Guttering Light** — +5% to healing you give your companion *(moved here from §1)* |
| `bark_hound` | Bark Hound | its coat is not fur | **Weathered** — the first Burn or Poison applied to you each combat is halved |
| `canopy_shrew` | Canopy Shrew | small, furious, extremely high up | **Overhead** — +3% Phys Crit against enemies below half HP |
| `witchwood_fawn` | Witchwood Fawn | born from a tree that remembered being a deer | **Green Memory** — your companion recovers hunger 20% faster |

---

### 3.3 The Stormcrag (`stormcrag`) — sketch only

*A mountain the sky never stopped hitting.* Frost-weak; enemies are
storm-touched, iron-carrion, living lightning. Floor passive *Static Charge* —
crits chain 3 damage to one other enemy. Bosses: The Rimeherald · Thundershrike ·
The Crag Itself. Creatures include `cairn_bear`, `ember_ram` and `salt_hare` from
§1's slate.

Left deliberately unfinished. Two biomes is already a large build; a third should
be its own design pass once the first two are real.

---

**Cost honesty:** each biome is roughly the largest single content unit in the
game — 8 standard enemies, 4 elites, 3 bosses with sprites, backgrounds, a floor
map, music, a weakness table, plus 3 scions and 4 creatures with full art ladders.
**Two biomes is a multi-session project on its own** and is the piece I'd most
expect to slip past Aug 19.

---

## 4. Descent bosses — unique, every five floors

Today the Descent recycles the same 9 dungeon bosses forever, which is the
weakest part of an otherwise strong endless mode.

**Proposal — The Depth Wardens.** Nine unique bosses that appear *only* in the
Descent, on a five-floor cadence:

| Floor | Warden | Hook |
|---|---|---|
| 5 | The First Door | Opens with a shield equal to the floors you've cleared |
| 10 | Sister Fathom | Heals for any damage you deal above 30 in one hit |
| 15 | The Tally | Gains a permanent stack each time you use the same ability twice |
| 20 | Hollowlight | Your healing is inverted for the first 2 turns |
| 25 | **The Weight of Ironwake** *(milestone)* | Three phases; drops a guaranteed Depthforged legendary |
| 30 | The Long Arithmetic | Damage you deal is capped at your current HP |
| 35 | Nothing In Particular | Untargetable every other turn |
| 40 | The Understudy | Copies your equipped weapon's affixes |
| 45 | **The Hollow Crown** | Silences one random ability each turn — the fight gets quieter until you are fighting in silence. A vast empty circlet above a throne of nothing; the king it belonged to is long gone and it is still ruling. *(M: "a very epic name — reads as a strong Descent boss")* |
| 50 | **The Bottom** *(milestone)* | The intended end of the ladder; unique title + splash |

Past floor 50 the Wardens cycle with compounding scaling.

**Why five floors:** the Descent's floor-boss cadence is already every floor, so
Wardens *replace* the recycled dungeon boss on 5/10/15/…, keeping normal theme
bosses on the floors between. No new pacing system needed, and floors 1-4 stay
exactly as they are today.

Design intent: each Warden attacks a **habit** rather than a stat — ability
spam, burst-hoarding, heal-reliance, single-target focus. Endless scaling
eventually beats raw numbers, so the fights have to test something else.

---

## 5. Segregating pets by dungeon

**Proposal:** every generic species gains a `biome` tag. Eggs found in a dungeon
roll from **that dungeon's pool**; hub sources (altar, board rewards, Bairc)
roll from the full pool as they do now.

| Biome | Generic species |
|---|---|
| Ashen Vault | bone_stag, bonehound, hollow_pup, pale_widow, barrow_mole |
| Scorched Depths | wyrmling, ashjaw_lynx, gravel_tick, ironshell_beetle |
| Tundra Tomb | nightowl, voidkit, shellback, salt_hare |
| Drowned Reach | gloomtoad, glimmer_slime, mire_heron, glass_eel, lockjaw_turtle, drowned_lamp |
| Hollow Canopy | luna_moth, sporeling, thorn_boar, tallow_moth, bark_hound, canopy_shrew, witchwood_fawn |
| Stormcrag *(sketch)* | saber_hound, duskraven, cairn_bear, ember_ram, chapel_bat |
| Descent only | pressure_snail, flicker_finch, rust_vole, still_pool_thing |
| *(any)* | hub sources — altar, board rewards, Bairc — draw from the full pool |

Scions are not in this table: they are already bound to their boss, which binds
them to their dungeon automatically.

Benefits: dungeons gain a collecting identity, the "which dungeon should I run"
question gets a second answer beyond loot, and 26 species stop feeling like one
undifferentiated bucket.

⚠ **Risk worth naming:** this makes specific pets *harder* to get. If someone
wants a Cairn Bear and Stormcrag doesn't exist yet, the bear is unreachable from
dungeon eggs. **Mitigation:** hub sources stay unfiltered, so nothing is ever
gated behind unbuilt content. I'd hold the segregation until at least one new
biome ships — flagging rather than deciding.

---

## 6. Awakened forms — the fluid pass

**The problem, stated plainly:** Awakening is the top of the pet ladder and the
creature does not change. `pet_sprite_stage()` collapses stage 3 and 4 into
`"adult"`. The aura tint and splash art carry the whole moment.

### 6.1 Design principle — *escalate the silhouette, keep the creature*

An Awakened form must read as **the same animal, transformed** — not a new
species. Every awakened design escalates along **one axis** the adult already
established, so the change feels like growth rather than replacement:

| Axis | Adult reads as | Awakened becomes |
|---|---|---|
| **Crown** | horns, antlers, frills | the crown overtakes the head — antlers branch into a cathedral |
| **Flame** | embers, heat, coals | the body becomes the fire it was carrying |
| **Bone** | exposed structure | bone erupts outward into armor or wings |
| **Void** | shadow, absence | the outline stays; the interior becomes starfield |
| **Growth** | moss, thorns, spores | the creature is overtaken by what grew on it |
| **Light** | glow, lantern, eyes | light escapes the body and holds a shape around it |

Each species is assigned exactly one axis. The rule that makes it *fluid*: **the
adult silhouette must remain recognizable inside the awakened one.** Same pose
family, same proportions, one dramatic addition. This is also what makes the art
batchable — it's a consistent transformation applied per-species, not 35
unrelated designs.

### 6.2 Code shape (small — this is the cheap half)

- `pet_sprite_stage()` returns `"awakened"` for stage 4 instead of `"adult"`.
- New sprite key `spr_pet_<species>_awakened`.
- **Fallback is mandatory:** when the awakened sprite is absent, fall back to
  adult art + today's aura tint. This makes the whole pass art-gated and
  shippable in waves — exactly like `pet_species_has_art()`.
- Keep the aura on top of awakened art. It reads as *charged*, not redundant.

### 6.3 Art volume, honestly

Full species tally if everything in this doc ships:

| Group | Count |
|---|---|
| Existing generic | 16 |
| Existing scions | 9 |
| §1 new generic | 10 |
| §2.1 Warden scions | 9 |
| §2.2 Descent-only generic | 4 |
| §3 biome generic (2 biomes) | 5 *(3 of the 8 listed come from §1)* |
| §3 biome scions (2 biomes) | 6 |
| **Total** | **59** |

At 20 generations per set that is **~1,180 generations for the awakened pass
alone** — and the 34 brand-new species each also need egg, baby and adult art
first, which is roughly another 2,000.

I want that number in front of you before anything starts, because it is the
real cost of this doc and it dwarfs everything else in it. It is very achievable
across many sessions at our quota; it is not achievable in one, and it is not
achievable before Aug 19.

Awakened waves I'd suggest, most-visible first:
1. The 8 original species (most players' first companion)
2. The 9 existing scions (already the prestige tier)
3. The 07-31 expansion 8
4. The 10 new generic
5. Descent + biome species, as those systems land

---

## 7. Sequencing recommendation

Ordered by payoff per unit of work:

1. **Awakened form system + wave 1 art** — the stage already exists and is earned; making it *visible* is the highest-value change in this doc.
2. **10 new generic creatures** — pure additive, art-gated, no risk to existing content.
3. **Descent Wardens** — fixes the weakest part of the endgame; no new biome art needed, since Wardens reuse existing backgrounds.
4. **Descent creatures** — 9 Warden scions ride on the Warden work; the 4 general species need two Descent room events and a cache egg roll.
5. **Pet segregation** — cheap code, but should wait for a new biome so it doesn't just make pets harder to find.
6. **New biomes** — the largest unit by far, and the most likely to slip past Aug 19.

**Launch reality check:** Aug 19 is thirteen days out and the current code batch
is still awaiting F5. None of this should displace launch-critical work. Items
1-2 could realistically land pre-launch if you want them; 3-6 read as a post-
launch content update, which is also a good thing to *have* lined up for the
weeks after release.

---

## 8. Open questions for M

1. **Warden scion drop rate** — 4% is ~25 kills of one specific Warden per scion, nine times over. Season-long chase, or raise to ~10%?
2. **Universal scion rule** — confirm every boss gets a scion (9 dungeon + 9 Warden + 6 biome = 24 scions). It's a clean rule and a strong collector spine, but it means every future boss owes us a creature.
3. **Segregation timing** — hold until a new biome ships, or apply now to the existing three?
4. **Awakened axis assignment** — review the per-species axis list before art starts, or trust the rule and judge the art?
5. **Third biome** — is Stormcrag wanted, or are two enough?
6. **Pre-launch scope** — anything here before Aug 19, or is this the post-launch update?

---

## 10. The Creature Compendium (M, 08-06)

*"Like a pokédex, accessed from the Journal, lore per creature, entries unlock
only as you find them."*

### 10.1 Roster changes locked in this pass

- `weight_crab` → **`deepclaw`** / "Deepclaw"
- `quietbud` → **`whispervine`** / "Whispervine"
- **Hollow Crown promoted to a Descent boss** (floor 45 Warden). Too epic a name for a wisp. Its scion is now **`griefwisp`** / "Griefwisp" — same design, humbler name.
- **`honeymaw`** / "Honeymaw" added — a second bear, since canines were over-represented. Hollow Canopy resident; soft and shaggy where Cairn Bear is hard.
- **Cairn Bear** approved, armor dialed back: ONE lichen-edged stone settled in the shoulder fur. Bear first, cairn second.
- **Null Hound** approved with a stage ladder that keeps the silhouette absolute and grows the *interior* — full spec in `CREATURE_VISUAL_LOCK_0806.md` §9.

Net species: **60**.

### 10.2 It's cheaper than it sounds — the plumbing already exists

Verified in code:

- **The Journal already has 5 tabs** — RELATIONSHIPS, QUESTS, COMPENDIUM, ITEM CODEX, BESTIARY (`scr_ui.gml:2615`). Tab cycling is `mod 5` in `obj_game_controller/Step_0.gml:784`. A sixth tab is a one-line change plus a draw block.
- **The Bestiary is the exact UI shape we want** — scrolling list on the left, lore detail on the right, family grouping (`scr_ui.gml:3128`). Clone it.
- **Discovery tracking already exists.** `ach_record_hatch()` maintains lifetime species and scion sets for the achievements (`scr_stats.gml:12668+`). The compendium reads those — **no new save data, no format bump.**

So the *system* is small. The **content** is the real work: ~60 lore entries.

### 10.3 Design

**Placement:** Journal → 6th tab, **CREATURES**. (Named to avoid colliding with the existing COMPENDIUM tab, which is the glossary of game terms.)

**Unlock model — two states, not one:**

| State | Trigger | Shows |
|---|---|---|
| **Undiscovered** | — | Row present but greyed: "???" with a blacked-out silhouette. The player can see the *shape* of what they're missing, and how many remain |
| **Discovered** | First **hatch** of that species | Full entry: art, name, lore, innate or signature move, habitat, and where it can be found |

Showing locked rows as silhouettes is the whole collector hook — an empty list
motivates nobody, a list of 60 shadowy outlines motivates a lot. This mirrors
how the Item Codex already gates discovery.

**Per-entry content:**
- Creature art (stage-appropriate: shows the highest stage you've raised)
- Name, and "kin of ⟨Boss⟩" for scions (that string already exists)
- **Lore** — 2-4 sentences, in the game's voice
- Its innate or signature move
- **Habitat** — which dungeon/biome it comes from (pairs directly with §5's segregation)
- Stage progress: which of egg/baby/adolescent/adult/awakened you have personally raised

**Header counter:** "CREATURES — 27 / 60 discovered". Scions counted separately: "SCIONS — 4 / 24".

**Mandatory passes** (per our standing rules — flagged now so they aren't discovered late):
- Scrollable with a **visible** scrollbar, capacity measured (60 rows will not fit)
- Full touch/keyboard/pad parity, hit-tests in **Draw**, not Step
- Overlap audit at 1920×1080 with longest strings — creature names plus "kin of ⟨Boss⟩" is the worst case
- Modal suppression while the Journal is open

### 10.4 Cost

| Piece | Effort |
|---|---|
| 6th tab + input wiring | Trivial — one `mod` change, tab label |
| List/detail draw block | Small — clone the Bestiary block |
| Discovery read | Trivial — `ach_record_hatch` sets already exist |
| Silhouette rendering for locked rows | Small — draw art at black with alpha |
| **~60 lore entries** | **The real cost.** This is writing, not code |

The compendium is the single best value item added to this doc: it makes all 60
creatures *legible as a collection*, which is the pull M is chasing, and it does
it almost entirely with plumbing we already have.

---

## 9. Art budget — how to spend far less than the naive number

Verified with PixelLab 08-06, not assumed.

### 9.1 The billing model (this corrects an intuition)

**Generations are billed per CALL, by canvas size tier — not by how many
candidates come back.** A 4-candidate review pack costs exactly what a
1-candidate result costs.

So *reducing drafts per creature saves nothing.* It removes choice for free.
The lever runs the other way — a smaller canvas returns MORE candidates at the
same price:

| Canvas size | Candidates per call |
|---|---|
| ≤ 42px | 64 |
| ≤ 85px | 16 |
| ≤ 170px | 4 |
| > 170px | 1 |

### 9.2 Lever one — many DIFFERENT creatures per call

`create_1_direction_object` accepts `item_descriptions`: per-object prompts when
the size tier yields multiple objects. At 170px that is **4 distinct creatures
per call**; at 85px, **16**. Our pet sprites run 64-176px, so 170px is a natural
fit and 34 new species' adult art becomes ~9 calls instead of 34.

### 9.3 Lever two — awakened forms are EDITS, not new generations

`edit_image` returns *your* image with pose, composition and pixel style
preserved, changing only what the instruction asks. That is precisely §6.1's
rule — keep the silhouette, escalate one axis — so the tool enforces the design
intent instead of us hoping for it.

It bills by the **total frame grid**, so several sprites in one call cost one
call (≤128px → 4 frames per call). Batch **by axis**: every Crown species gets
"antlers branch into a cathedral of bone, radiant aura" in a single call.

Result: the awakened pass drops from ~1,180 generations to **~300-600**, and
comes out *more* internally consistent than generating each from scratch.

### 9.4 Revised budget

| Work | Naive | Batched |
|---|---|---|
| 34 new species — egg / baby / adult | ~2,040 | ~540-1,080 |
| 59 awakened forms | ~1,180 | ~300-600 |
| 15 new bosses (6 biome + 9 Warden) | ~300 | ~300-600 |
| 24 biome enemies | ~480 | ~120-240 |
| Backgrounds, floor maps | ~160 | ~160 |
| **Total** | **~4,160** | **~1,400-2,700** |

Quota at time of writing: **7,487** subscription generations. The entire doc
fits inside it with comfortable room for rerolls.

### 9.5 Why the visual design pass matters (M's instinct, corrected reason)

Designing each creature visually before prompting does **not** reduce the cost
of a call. It reduces the number of **wasted** calls — every reroll is another
20-40 generations, and vague prompts are what cause rerolls. Locking silhouette,
palette and one distinguishing feature in text ahead of time is where the real
saving lives. That lock lives in `CREATURE_VISUAL_LOCK_0806.md`.

### 9.7 Note on §9.4 totals

The revised budget in §9.4 predates the roster changes in §10.1 (+1 bear, Hollow
Crown promoted to boss). Net species count moves 59 → 60; the budget bands are
wide enough that this does not move them.

### 9.6 The actual constraint

Generations are not the binding limit — **F5 cycles are.** Every system here
needs compile-and-livetest loops, and the code surface (biome plumbing, Warden
bosses, scion wiring, awakened sprite keys, room events) is substantial. The art
and design are two-day work; the integration will want more.
