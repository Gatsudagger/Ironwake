# CREATURE VISUAL LOCK — 34 new species

**Purpose:** lock every creature's look *in words* before a single PixelLab call.
Per DESIGN_WORLD_EXPANSION_0806.md §9.5, this is where generation savings
actually come from — vague prompts cause rerolls, and every reroll is another
20-40 generations.

**Status: DRAFT 2026-08-06 — awaiting M's approval.** Nothing generated yet.

---

## How to read an entry

Each creature locks four things, and a prompt is assembled from them:

- **Silhouette** — the shape read at 64px, squinting. The single most important field; if two creatures share a silhouette, one of them is wrong.
- **Palette** — 2 colors + 1 accent. Keeps the roster from turning into brown mud.
- **Feature** — the one detail a player would describe it by.
- **Axis** — its Awakened escalation path (§6.1): Crown · Flame · Bone · Void · Growth · Light.

**House style constant** (prepended to every prompt) — ⚠ REWRITTEN 08-07 after
the first batch came back off-style:
> creature companion sprite matching the reference art style exactly: chunky
> readable pixel art with rich hand-placed detail, strong dark outlines,
> characterful and stylized like a monster-collecting game creature, NOT a
> realistic wildlife painting

**STYLE ANCHOR IS MANDATORY.** Every call passes `style_images` built from the
**original character class sprites** — `spr_arcanist` [5], `spr_bloodwarden` [4],
`spr_shadowstrider` [6] (front-facing frames; frame [0] is a side view). M:
*"they have these awesome details but are still very authentically pixel
graphics, they have flavor and heart."*

**The one-line direction (M, 08-07):** *"this needs to read more like Pokémon and
less like National Geographic."* If a creature could appear in a wildlife
documentary unaltered, it is wrong.

Transport recipe (base64 corrupts above ~2KB): crop to bbox → 64px thumbnail →
quantize to 16 colours → ~1.5KB. Build with the snippet in `tools/_styleref/`.

**Hard rule:** creatures, never humanoid. No bipedal stances, no hands, no
clothing. (See `feedback_pets_not_anthropomorphic`.)

---

## Design principles (M, 08-06)

### P1 — Pets are animals that have passed on. Objects are the rare exception.

The pet system's quiet lore is *we are all spirits stuck in limbo*, and a pet is
an **animal that died and lingered**. Object-creatures ("a living lamp", "a door
that walks") dilute that if they're common.

**The rule:** object-bound pets are **rare, always boss-tied, and always show
the animal underneath.** The appealing version is a boss's small servant —
a creature that was bound into the thing it tended and still behaves like the
animal it was. One or two across the whole roster, not a category.

Practically:
- A creature may **carry, wear, or be fused with** an object (Deepclaw's floor
  slab, Lantern Wyrm's lamp, Drowned Lamp's brow-light). The animal is still the
  subject. **This is fine and stays.**
- A creature may not simply **be** an object with legs. Reworked in this pass:
  `sluiceling` → **Sluice Otter**, `still_pool_thing` → **Paleswimmer**.
- **`doorling` is the sanctioned exception** — the one object-bound servant. Its
  lore and design must make the animal read (see its entry).

### P2 — Biome creatures should not all wear their biome as a costume

⚠ **CORRECTED 08-07 by M — I had this backwards.** My first reading was "the
Canopy is natural, so its creatures should be plain animals", which produced
Canopy Shrew (just a shrew) and is *also* wrong.

M's actual point: *"I noticed you started making everything a PLANT — like a bud
with no eyes — for several creatures."* The failure was **material monotony**:
four Canopy creatures had all become vines, thorns, bark and buds. A biome's
roster must vary in what its creatures are MADE OF, never converge on one
texture. Thorns get used once, not four times.

### P3 — Every creature needs an uncanny tell (M, 08-07)

*"Some of these aren't new creatures, they're just regular animals."* A bear that
is only a bear does not belong in a game whose pets are things that died and
lingered. **Every creature carries at least one detail that could not occur in
life** — a glow, a growth, a wrongness, something it carries and shouldn't.

"Subtle" is allowed. "Absent" is not. Cairn Bear's stone and Wispfox's cold flame
clear the bar; the first pass's Canopy Shrew and Bark Hound did not.

---

## M'S APPROVALS — 08-07 review of the first (off-style) batch

**Approved as concepts. All to be regenerated anchored to the class sprites:**
witchwood_fawn · graftling · thornlet · whispervine · lockjaw_turtle ·
null_hound · stormkirin · fathom_squid · lantern_wyrm · deepclaw

**Approved with required changes:**
- **lockjaw_turtle** — "needs more effects/details". Added: cracked mossy shell with glowing amber cracks, water dripping from the beak.
- **fathom_squid** — first pass read as "a cute baby". Reframed as a **void squid**: mantle like a hole in space with faint stars inside, huge pale glowing eyes.
- **deepclaw** — ⚠ the slab "looks very AI". M's fix, now canon and better: **its shell is a dungeon floor tile that fits the floor like a puzzle piece**, so from above it is invisible — part of the floor, or of a shipwreck deck. This is a LORE point, not just a look: it hides by being architecture.

**Rejected, concept kept:**
- **griefwisp** — "needs some shaping, maybe a wisp vaguely in the form of a tombstone." Regenerating as a tombstone-shaped wisp with the crooked crown on top.

**Everything else from the first batch is dropped** as art. The written designs
below stay as baselines — M: *"many of your creature baselines are great to build
off of."*

---

## 1. General slate (10) — §1 of the design doc

| # | id | Silhouette | Palette | Feature | Axis |
|---|---|---|---|---|---|
| 1 | `cairn_bear` | Low, heavy quadruped, head below shoulder line, broad wedge back — **bear first, everything else second** | slate grey-brown fur / moss green / pale lichen accent | ONE flat stone settled into the fur of its shoulder, lichen-edged, like something it slept under and kept. Fur reads as fur, not armor | **Bone** |
| 2 | `ember_ram` | Compact quadruped, huge spiral horns dominating the top half | charcoal wool / dull iron / ember-orange accent | Horns lit from within at the spiral core — banked coals, not open flame | **Flame** |
| 3 | `salt_hare` | Long-legged, tall ears, coiled crouch — all tension | bone white / pale dune / cold blue accent | A crust of salt crystals along its spine and ear tips | **Light** |
| 4 | `mire_heron` | Tall, thin, S-curved neck, single visible leg, dagger beak | deep green-grey / wet black / amber eye accent | Utterly still stance; water beads hanging off its underfeathers | **Growth** |
| 5 | `gravel_tick` | Squat armored disc on six short legs, wider than tall | grey stone / dark iron / rust-red accent | Reads as a pebble until the legs unfold — mottled stone shell | **Bone** |
| 6 | `ashjaw_lynx` | Lean stalking cat, tufted ears, low predatory head | soot black / warm ash grey / ember-orange accent | Jaw and throat glow faintly, as if it swallowed a coal | **Flame** |
| 7 | `glass_eel` | Long sinuous ribbon, no limbs, gentle S-curve | translucent pale / near-clear / silver accent | Fully transparent body but for a bright silver spine visible through it | **Light** |
| 8 | `chapel_bat` | Small hanging or half-furled bat, wings folded like a cloak | dusty brown / stone grey / candle-gold accent | Wing membranes marked with faint stained-glass patterning | **Light** |
| 9 | `barrow_mole` | Fat cylindrical body, enormous front claws, no visible eyes | dark earth brown / pale pink snout / bone-white claw accent | Claws far too large for it, still caked with grave soil | **Bone** |
| 10 | `tallow_moth` | Broad heavy moth, thick furred body, wings held open flat | waxy cream / dull grey-brown / dim candle-gold accent | Wings look like dripping wax; body fat and slow | **Flame** |

### 1b. Badgers and foxes (M, 08-06) — 4 more

Roster gaps M called out: no badger at all, and foxes limited to the Tundra
signature `rimefox`. Canines were over-represented by hounds specifically, so
these fill mustelid and vulpine space instead.

**Two badgers, deliberately opposite** — one is a digger, one is a fighter:

| # | id | Silhouette | Palette | Feature | Axis |
|---|---|---|---|---|---|
| 36 | `gravemask` | Low slung, wide-bodied badger, head down in a digging posture, heavy forelimbs | charcoal grey / dirty cream / tarnished silver accent | The classic black-and-white face stripe, but the white has gone grave-pale. Something small and metal always clamped in its jaws — a ring, a coin, a locket it dug up | **Bone** |
| 37 | `bristleback` | Squat, braced, side-on and **facing you** — head up, weight forward | dark brindle / dusty tan / old-scar pink accent | Scarred and unbothered. Guard hairs standing up along the spine. Reads as *small and completely unwilling to move* — the opposite of Gravemask's turned back | **Growth** |

**Two foxes, chosen to fix the axis imbalance** (§6 — Flame and Crown were thin):

| # | id | Silhouette | Palette | Feature | Axis |
|---|---|---|---|---|---|
| 38 | `wispfox` | Slender fox, low and light on its feet, tail carried high and long | dusk grey-red / smoke / pale blue-white flame accent | A single cold pale flame burning at the very tip of its tail, lighting nothing. It leads you somewhere and does not look back | **Flame** |
| 39 | `gravefox` | Alert upright fox, ears large and forward, one paw raised | bone-pale cream / ash grey / tarnished gold accent | Wearing a small circlet of fused bone it dug up somewhere and will absolutely not surrender. It has decided the crown is its | **Crown** |

---

### 1c. Fantasy hybrids (M, 08-06) — 5 more

M's note: *"we don't need every creature to directly resemble a real animal — we
want hybrid fantasy made-up stuff as well. These are just body structural
baselines."* Real animals give us readable silhouettes; hybrids give us the
fantasy. This block is the second half of that balance.

**Rule for hybrids:** combine **two** structural baselines, not four. A gryphon
reads instantly because it is exactly eagle-front + lion-back. Add a third
element and the silhouette turns to mush at 64px.

| # | id | Silhouette | Palette | Feature | Axis |
|---|---|---|---|---|---|
| 40 | `pyre_bison` | **Bison base.** Enormous shoulder hump, head carried low, short curved horns, narrow hindquarters — front-heavy and immovable | charcoal shag / dark umber / deep ember-orange accent | Embers live *inside* the shoulder shag, glowing between the hairs like a banked fire under a blanket. Snow or ash never settles on its back | **Flame** |
| 41 | `crypt_gryphon` | **Eagle front + lion back.** Hooked beak, feathered forequarters and raised wings, heavy padded haunches and a tufted tail | dust-grey plumage / tawny hide / tarnished gold beak accent | Feathers gone dull and dusty like a thing that has been indoors for centuries. It perches on stone the way a statue would, and the resemblance is the joke | **Crown** |
| 42 | `threehunger` | **Chimaera — lion body, goat's head at the shoulder, serpent tail.** Deliberately unbalanced, three focal points fighting for the eye | dark tawny / slate-grey goat / venom-green serpent accent | The three heads **want different things** and visibly pull against each other. Nothing about it looks comfortable | **Bone** |
| 43 | `wing_hare` | **Hare base + small antlers.** Tall ears, coiled crouch, a modest branched rack between the ears | soft dun brown / cream belly / pale velvet-antler accent | A jackalope that behaves entirely like a hare — the antlers are treated as completely unremarkable by their owner | **Crown** |
| 44 | `stormkirin` | **Deer front + drake back.** Slender cloven forelegs, scaled hindquarters, a single spiralling horn | storm blue-grey / dark scale / white-hot lightning accent | Static lifts its mane and the fur along its spine constantly, as if the air near it is charged. Hooves strike sparks off stone | **Light** |

---

## 2. Warden scions (9) — §2.1

Scion rule: each must read as a **small echo** of its Warden. Same motif, none
of the menace.

| # | id | Silhouette | Palette | Feature | Axis |
|---|---|---|---|---|---|
| 11 | `doorling` | **A cat.** Sitting upright in a doorkeeper's posture, tail curled around its feet, ears forward | weathered stone grey fur / iron / faint gold seam accent | *The sanctioned object-bound pet (P1).* It was the doorkeeper's cat and it never left its post; the frame it guarded is now grown into its back like a shell, a small dark doorway between its shoulders. **It still sits in doorways. It still grooms itself. The cat reads first, the door second** | **Void** |
| 12 | `fathom_squid` | Round mantle, short trailing tentacles, wide-set eyes | deep ink blue / near-black / bioluminescent cyan accent | Enormous lightless eyes; a faint ink trail always behind it | **Void** |
| 13 | `tallykeep` | Small hunched rodent-ish thing, long thin tail | parchment tan / dusty brown / red-ink accent | Tally marks scratched into its own hide, uneven, ongoing | **Bone** |
| 14 | `lantern_wyrm` | Short serpentine body, no limbs, head raised | dark scaled green / black / pale yellow lantern accent | A lantern-bulb on a stalk from its skull — the light is clearly not its own | **Light** |
| 15 | `deepclaw` | Wide low crab, oversized flat carapace, short legs splayed under load, one claw notably larger | granite grey / dark shell / faint blue rune accent | Carries a visible slab of dungeon floor on its back, tile seams and all; the big claw is chipped stone-hard | **Bone** |
| 16 | `sum_moth` | Slender moth, narrow wings held in a shallow V | dull silver / dark grey / shifting pale gold accent | Wing patterns form numerals that don't quite resolve | **Light** |
| 17 | `null_hound` | Classic hound stance, alert, ears up, tail low — a **crisp, confident dog silhouette** | void black interior / thin cold-white rim light / deep violet accent | The outline is sharp and rim-lit so it never reads as a missing sprite; the interior is not flat black but a faint starfield with two clear pale eyes and a suggestion of ribs and haunch where light catches. **See §9 for the stage ladder** | **Void** |
| 18 | `mimicling` | Deliberately generic small quadruped, no strong features | shifting grey / muted / faint iridescent accent | Half-formed: parts of it are mid-copy of something else | **Void** |
| 19 | `griefwisp` | Small drifting wisp-body with a thin tarnished circlet resting crooked on top | tarnished gold / deep violet / cold white accent | A crown far too big for it, worn askew — it is carrying someone else's grief | **Crown** |

---

## 3. Descent generals (4) — §2.2

| # | id | Silhouette | Palette | Feature | Axis |
|---|---|---|---|---|---|
| 20 | `pressure_snail` | Dense conical spiral shell, small foot barely visible | dark basalt / deep blue-grey / faint pearl accent | Shell visibly *too dense* — thick walled, compressed rings | **Bone** |
| 21 | `flicker_finch` | Small perched bird, wings half-open | pale grey / ghost white / soft cyan accent | Partially transparent, edges dissolving — never fully present | **Light** |
| 22 | `rust_vole` | Small stout rodent, low to the ground | rust orange-brown / dark iron / bright metal accent | Chewing an iron fragment; flecks of rust in its fur | **Bone** |
| 23 | `paleswimmer` | **Blind cave salamander** — long soft body, external feathery gills, stubby splayed legs | translucent flesh-white / faint pink / dim white eye-spot accent | Eyeless, skin so thin the organs shadow through. Unsettling because it is *real*, not abstract — it drifts and does not react to you at all | **Void** |

---

## 4. Drowned Reach (4 generic + 3 scions) — §3.1

| # | id | Silhouette | Palette | Feature | Axis |
|---|---|---|---|---|---|
| 24 | `lockjaw_turtle` | Low broad turtle, heavy blunt head thrust forward | drab olive / dark shell / bone-white beak accent | Jaw clamped shut, scarred — visibly has already decided | **Bone** |
| 25 | `drowned_lamp` | Deep-bodied fish, fan tail, forward-set eyes | dark teal / black / warm lantern-gold accent | Carries a small lit lamp fused to its brow; light unaffected by water | **Light** |
| 26 | `sluice_otter` *(scion — Tidewright)* | **Otter.** Sleek, long-bodied, mid-turn as if swimming a corkscrew | wet dark brown / slick black / verdigris accent | An otter that lived in the lock-works. A single verdigris valve-wheel is snagged permanently on its tail like a ring it can't shed — it plays with it constantly | **Bone** |
| 27 | `chorister_fry` *(scion — Choirmother)* | Small round-bodied fish, mouth held open in an O | pale drowned white / green-black / faint gold accent | Mouth permanently open mid-note; throat glows softly | **Light** |
| 28 | `leviathan_calf` *(scion — Leviathan Below)* | Blunt-headed whale-ish body, small flippers, oversized head | deep slate blue / barnacled grey / pale underbelly accent | Already scarred and barnacled despite being small | **Growth** |

---

## 5. Hollow Canopy (3 generic + 3 scions) — §3.2

| # | id | Silhouette | Palette | Feature | Axis |
|---|---|---|---|---|---|
*Per P2, this biome's roster is deliberately the LEAST altered in the game —
these are mostly ordinary forest animals that happened to die in a forest.*

| 29 | `bark_hound` | Lean dog shape, normal canine proportions and posture | weathered grey-brown / grey lichen / deep moss accent | **Lightly touched:** an ordinary rough-coated dog whose fur has taken on the grain and colour of bark at the shoulders and back. Reads as a dog with a strange coat, not a wooden construct | **Growth** |
| 30 | `canopy_shrew` | Tiny, hunched, oversized eyes, tail curled for balance | russet brown / cream belly / sharp black eye accent | **Untouched:** just a shrew. Very small, visibly furious, gripping a twig. Nothing magical about it whatsoever, and that is the point | **Growth** |
| 31 | `witchwood_fawn` | Slender fawn, thin legs, small budding antlers | pale birch / soft green / white blossom accent | **The one strongly marked creature here:** antlers are living branches still in bud, with real blossom on them | **Crown** |
| 32 | `graftling` *(scion — Grafted Stag)* | Small stag calf, antlers already disproportionately large | dark bark / bone / green sap accent | Antlers grafted on at visible seams — sap where bone meets wood | **Crown** |
| 33 | `thornlet` *(scion — Mother Bramble)* | Round bramble-ball creature with stubby limbs | dark thorn green / deep red / pale thorn-tip accent | Covered in inward-curving thorns; looks huggable, isn't | **Growth** |
| 34 | `whispervine` *(scion — Green Silence)* | **Snake/plant hybrid** — a serpent whose body is a living vine, coiled with the head raised in a listening posture | muted sage / grey-green bark-scale / faint white bud accent | Its "head" is a closed bud where a snake's would be — no mouth, no eyes, no rattle. Scales and leaves blur into each other down the coil; it tastes the air with a tendril instead of a tongue | **Growth** |
| 35 | `honeymaw` | Big shaggy forest bear, round-shouldered, head low and wide | warm russet brown / dark umber / honey-gold accent | Muzzle and forepaws sticky with wild honey, a few bees still orbiting it. Soft where Cairn Bear is hard | **Growth** |

---

## 6. Axis distribution check

Updated after the 08-06 additions (badgers, foxes) — 39 creatures:

| Axis | Count | Notes |
|---|---|---|
| Bone | 9 | heaviest — bone/stone is the game's core visual language |
| Light | 8 | second; kept distinct via warm vs cold light |
| Growth | 8 | concentrated in Hollow Canopy, as intended |
| Void | 5 | concentrated in the Descent, as intended |
| Flame | 4 | improved by `wispfox` |
| Crown | 4 | improved by `gravefox`; still deliberately the rarest |

Better balanced than the first pass. Bone still leads, which is correct for this
game, but Flame and Crown are no longer conspicuously thin.

---

## 7. Batching plan (feeds §9.2)

Group by **shared prompt scaffolding**, 4 per call at 170px:

1. Mammals A: cairn_bear, ember_ram, salt_hare, ashjaw_lynx
2. Mammals B: barrow_mole, canopy_shrew, rust_vole, witchwood_fawn
3. Insects/moths: gravel_tick, tallow_moth, sum_moth, thornlet
4. Aquatic A: glass_eel, drowned_lamp, chorister_fry, fathom_squid
5. Aquatic B: lockjaw_turtle, pressure_snail, weight_crab, leviathan_calf
6. Birds/bats: chapel_bat, mire_heron, flicker_finch, quietbud
7. Void/abstract: null_hound, mimicling, still_pool_thing, hollow_crown
8. Constructs: doorling, sluiceling, tallykeep, lantern_wyrm
9. Antlered: graftling, bark_hound *(2 only — pair with rerolls)*

**9 calls ≈ 180-360 generations for all 34 adult forms.** Baby and egg stages
follow the same grouping.

---

## 9. `null_hound` — solving "cool silhouette, unappealing sprite"

M approved the concept and named the real risk: a flat black dog-shape reads as
a *missing asset*, and it has nowhere to grow across four stages. The fix keeps
the silhouette absolute and puts all the detail in three places that don't break
it — **rim, interior, and eyes**.

**The three rules:**
1. **The outline is always crisp and rim-lit** (thin cold-white edge). This alone is what separates "deliberate void creature" from "sprite failed to load".
2. **The interior is never flat black** — it is a faint starfield, denser toward the body's core. Read as depth, not absence.
3. **Light catches structure.** A suggestion of ribs, shoulder and haunch picked out where the rim light wraps, so the anatomy is *felt* without ever being drawn in full.

**Stage ladder — growth = the void filling in, not the shape changing:**

| Stage | What changes |
|---|---|
| **Egg** | A black sphere with a rim of cold light; a few stars inside. Reads as a hole in the world that happens to be egg-shaped |
| **Baby** | Puppy proportions — big head, short legs. Interior nearly empty, only 3-4 stars. Eyes large and pale. Endearing *because* it's mostly empty |
| **Adolescent** | Legs lengthen to hound proportions. Starfield thickens; the first hints of rib and shoulder catch the rim light |
| **Adult** | Full alert hound stance. Dense starfield, clear structural highlights on ribs/haunch/muzzle. Reads unmistakably as a dog made of night |
| **Awakened** *(Void axis)* | The outline stays **exactly** the same — the interior becomes a deep starfield with visible depth, and the rim light burns brighter and colder. The creature does not grow; the void inside it does |

This is the strongest awakened payoff in the whole roster: because the
silhouette never changes, the transformation is *entirely* interior — which is
precisely the "escalate one axis, keep the creature" rule taken to its limit.

---

## 8. Open questions

1. **Axis balance** — Flame (3) and Crown (3) are thin against Bone (8) and Light (8). Rebalance now, or accept it?
2. **`still_pool_thing`** — the id is a placeholder; display name is "Quiet Swimmer". Want a better id before it goes in the catalog and becomes permanent in saves?
3. **`null_hound` as pure silhouette** — a black shape with no interior detail is striking but may read as a rendering bug at 64px. Worth a test render before committing.
4. **Scion legibility** — scions echo their boss, but the player meets the scion long before they can name the boss. Fine, or should scions carry a shared visual tell (a mark, a shared accent color) so "this is a scion" reads instantly?
