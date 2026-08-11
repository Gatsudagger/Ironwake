# SYSTEMS — Deployed Traps (Shadowstrider rework)

**Status: P1-P3 BUILT 08-08, NOT COMPILE-TESTED (awaiting M's F5).**
Built: the data model, the deploy path, the trigger/spring in the reaction stack,
conversion of Bear/Spike/Death Snare, the deployed-trap UI strip with intent-match
pulse, the `traps_deployed` coach-mark, and the Preparation regen rule.
Also built (P4, same day): all four new traps as real abilities - Wire Snare and
Warding Chime are FREE STARTERS, Tripline (150g) and Caltrops (250g) are bought
from Vex (M's split). Blocking-trap payload CUT on M's call: Bear Trap 16 -> 10,
Death Snare 32 -> 20, on the reasoning that cancelling an attack outright is worth
more than the damage. Animation spec written (§8) - NO art generated.
NOT built: the new talent nodes (§6 - `trap_slots_max()` already reads
`trunk_has("trap_slot_plus")`, so the node just needs authoring), IRONMAN
mid-combat save of `player.traps`, and the animation batch itself.
Open questions in §10 were resolved with the recommended answers.

---

## 0. The problem

M, 08-08:

> We should rework shadowstrider trap mechanic, add an animation to throwing a
> trap that sits between the player and the enemy. Instead of it being a direct
> attack it is now a triggered event. [...] if I deploy bear trap which snares
> melee and essentially ends their turn it will still do that however it will
> simply interact with the first mob that attacks and fulfills the parameters of
> the trigger. 2 traps can be placed at a time [...] They can be a defensive
> stall strategy or an offensive defense.

The current implementation does not match its own fiction. Traps are instant
guaranteed-hit attacks that resolve the moment you cast them. The codebase says so
out loud, in `scr_abilities.gml`:

```
// Note: trap abilities (Bear Trap, Spike Trap, Death Snare) set trap_active=true
//       on the caster; the combat engine clears it when the trap fires.
```

…and then in the talent-web comments, the honest version:

```
// Shadowstrider L2b + L11 (trap_active is vestigial, traps fire on cast ...)
```

`trap_active` is dead weight. "Bear Trap" is a 1-AP nuke that happens to apply
Root. Nothing is ever *placed*, nothing ever *waits*, and the class plays as a
worse rogue instead of a controller. The Preparation resource compounds this: it
regenerates "+1/turn if no trap active", a rule that has no meaning when traps
never persist.

**This rework makes the fiction true**, and in doing so gives Shadowstrider the
distinct third playstyle the class roster is missing.

---

## 1. The good news: the hook already exists

This is not a from-scratch reaction system. `obj_combat_controller/Step_0.gml`
already resolves the enemy's intent *before* the blow lands and classifies it, in
order to serve Blink / Shadow Step / Counterblade:

```gml
//   _in_hostile    - the action targets the player at all (anything but a heal)
//   _in_damaging   - it deals damage (basic swing or damage spell)
//   _in_melee_blow - damaging AND melee-delivered (riposte-able)
var _in_reach = variable_struct_exists(actor, "reach") ? actor.reach : "melee";
if (_in_eab != undefined && variable_struct_exists(_in_eab, "reach") && _in_eab.reach != "") {
    _in_reach = _in_eab.reach;
}
```

There is already a **reaction stack** that runs between "the enemy has decided"
and "the damage applies", and it already knows melee vs ranged vs spell vs heal.

**Traps become the first entry in that stack.** No new turn phase, no new intent
system, no change to enemy AI. This is the single biggest reason the rework is
affordable — and it should be preserved as a hard constraint on implementation:
*if a proposed trap needs information the reaction stack doesn't already have, cut
the trap, not the constraint.*

---

## 2. Core model

### 2.1 Deploy

- Traps are **deployed**, not cast at a target. A deployed trap occupies a
  **trap slot** and persists until it triggers or combat ends.
- **2 slots** by default. Traits/talents raise this (§6).
- Deploying with all slots full: the oldest trap is **replaced**, with a confirm
  prompt naming which one is lost (destructive one-click rule).
- Traps do **not** persist between fights. They are a per-combat board state.
- Deploy costs AP + Preparation, as trap abilities do today.

### 2.2 Trigger

Every trap carries a **trigger filter**. When an enemy declares an action, the
reaction stack checks deployed traps **oldest-first**; the first trap whose filter
matches that action **springs**.

| Filter | Springs on | Reads |
|---|---|---|
| `melee`  | a damaging melee-delivered attack | `_in_melee_blow` |
| `ranged` | a damaging attack delivered at range | `_in_damaging && _in_reach == "ranged"` |
| `spell`  | any cast (`eab.kind == "spell"`) | `_in_eab.kind` |
| `any`    | any hostile action | `_in_hostile` |

Exactly **one trap springs per enemy action**. Two traps never both fire on one
swing — that ceiling is what keeps a stall board from becoming a lock.

### 2.3 Spring

Springing does three things, in order:

1. **Intercept.** The trap may cancel, reduce, or let through the incoming
   attack. This is per-trap (`block` field) and is what makes traps *defensive*.
2. **Payload.** Damage and/or status applied to the springing enemy.
3. **Consume.** The trap leaves its slot. (Exceptions in §6.)

A trap that intercepts a melee attack and Roots the attacker "essentially ends
their turn", exactly as M described — but it does it *reactively*, so the player
is spending a turn on a bet about what the enemy will do, not on a guaranteed hit.

### 2.4 Why this is a real third playstyle

- **Bloodwarden** spends its own health for throughput. Resource-as-risk.
- **Duelist / martial** reacts to single attacks with dodges and ripostes.
  Reactive but *reflexive* — the player commits nothing in advance.
- **Shadowstrider (new)** commits to a **prediction**, in advance, at a cost, and
  is paid when the prediction is right. That's a genuinely different decision
  shape: read the enemy intent line, pick the filter, bank the board.

Preparation finally means something too: it becomes the currency of *how many
predictions you can afford*, and the "+1/turn if no trap active" rule inverts into
a real tension — an empty board regenerates faster, so over-committing starves you.

---

## 3. Converting the three existing traps

| Ability | Now | After |
|---|---|---|
| **Bear Trap** (1 AP, 1 Prep) | 16 dmg + Root 1 turn, instantly | Deploy. `melee` filter. **Blocks the attack**, 16 phys, Root 1 turn. The anchor: the melee answer. |
| **Spike Trap** (1 Prep) | 26 dmg + Bleed 6/4t, instantly | Deploy. `any` filter. Does **not** block. 26 phys + Bleed 6/turn 4 turns. The offensive trap — springs on anything, punishes rather than prevents. |
| **Death Snare** (2 Prep) | 32 dmg + Stun 2 turns, instantly | Deploy. `any` filter. **Blocks**, 32 phys, Stun 2 turns. Apex: expensive, always springs, shuts anything down. |

`Bear Trap`'s existing WIS-25 scaling rider ("the Root holds 2 turns") carries over
unchanged.

**Balance note that must be checked in playtest:** these were priced as guaranteed
immediate damage. As deployed traps they gain a *delay and a whiff risk* but also
gain *interception*, which is worth much more than the damage. Expect to have to
lower payload damage. Do not tune this on paper.

---

## 4. New traps (4–6)

Deliberately spread across filters so slot choice is a real decision.

| Name | Cost | Filter | Block | Effect |
|---|---|---|---|---|
| **Tripline** | 1 AP, 1 Prep | `melee` | yes | No damage. Blocks the blow and applies Exposed — the pure defensive stall, and a setup piece for the Exposed combo family. |
| **Warding Chime** | 1 AP, 1 Prep | `spell` | yes | Blocks the cast and Silences 1 turn. The answer to caster packs; currently the class has none. |
| **Wire Snare** | 1 AP, 1 Prep | `ranged` | yes | Blocks the shot, 12 phys, and Roots — punishes archers for kiting. |
| **Caltrops** | 1 AP, 1 Prep | `any` | no | **Does not consume** — springs up to 3 times, 8 phys each. Chip damage that rewards a long fight. |
| **Oil Flask** | 2 AP, 2 Prep | `any` | no | 10 Fire + Burn 3 turns, and the springing enemy's **next** trap takes +50% payload. The combo enabler: pairs with a second slot. |
| **Hollow Ground** *(stretch)* | 2 AP, 3 Prep | `any` | yes | Blocks and Fears — the enemy loses its turn and its intent rerolls. Cut this first if the board proves too controlling. |

Six listed, **four are the commitment** (Tripline, Warding Chime, Wire Snare,
Caltrops). Oil Flask and Hollow Ground ship only if playtest wants them.

---

## 5. Data model

```gml
// Deployed traps live on the player for the duration of one combat.
player.traps = [
    {
        name:      "Bear Trap",   // source ability
        filter:    "melee",       // melee | ranged | spell | any
        block:     true,          // intercepts the incoming attack
        damage:    16,
        dtype:     0,
        status:    "root",
        duration:  1,
        charges:   1,             // Caltrops = 3
        deployed_round: 4         // for oldest-first ordering + UI age
    }
];
player.trap_slots = 2;            // trait/talent modified
```

**Save format:** traps are combat-scoped, so they need saving **only** for the
IRONMAN mid-run resume path (`SYSTEMS_IRON_VOW.md` §12). Serialize `player.traps`
alongside the other combat state there; a normal hub save must not carry them.
Guarded restore, defaulting to `[]` — the standard treatment for every array added
since SAVE_FORMAT_VERSION 2.

---

## 6. Talent / trait interactions

Existing Shadowstrider nodes and how they map:

| Node | Now | After |
|---|---|---|
| **Loaded Springs** (trunk L5) | Traps +2 dmg per Prep held | Unchanged in spirit — payload is calculated **at spring time**, not deploy time, so holding Prep while a trap waits is rewarded. Better than it is today. |
| **Sprung Steel** (trunk L11) | Casting a trap returns 1 Prep | Unchanged (on deploy). |
| **Compounding Dread** | Each trap cast adds +4 trap dmg this combat | Retarget to **each trap SPRUNG**, not cast. Currently it rewards spam; it should reward correct prediction. |
| **Old Fear** (web t1) | The dread starts pre-lit | Unchanged. |
| **Crescendo** (web tk) | +6 instead of +4 | Unchanged. |
| **Killing Spree** | +5 per debuff/mark/**trap effect** on target | Already reads trap effects — verify it counts *sprung* statuses, not deployed traps. |

New nodes worth adding (the slot-count lever M named explicitly):

- **Deep Pockets** (trait or trunk): `trap_slots` 2 → 3.
- **Patient Hands**: a trap that has waited 3+ rounds deals double payload.
- **Twin Jaws** (web keystone): the first trap each combat does not consume on
  spring.

---

## 7. UI / conveyance

This is the half of the feature that decides whether it *feels* like anything.

- **Deployed trap row.** A dedicated strip between the player and the enemy grid —
  literally where M said the trap sits. One chip per slot: trap icon, filter glyph
  (fist / arrow / rune / star), charge pips. Empty slots draw as dim outlines so
  the player always sees they *have* slots.
  - Must claim a y-band and go in `UI_BANDS.md`. Combat's 90–173 and 240–1023 are
    taken; the strip belongs in the gap around the player figure.
- **Filter/intent match highlight.** When an enemy's intent gem shows an action a
  deployed trap would catch, **pulse that trap chip**. This is the single most
  important piece of conveyance in the feature: it teaches the whole mechanic
  without a word of text, and it turns the intent system the game already has into
  a targeting aid.
- **Spring moment.** Trap chip flashes, a `TRAP!` popup over the springing enemy,
  and — when `block` is set — the existing `DODGED!`-style popup already used by
  the reaction stack, reading `BLOCKED!`.
- **Toasts** go through `ui_draw_toast()` only, per the 08-04 standard.
- **Full input parity**: trap chips are inspectable by hover, pad focus and touch;
  hit-tests in Draw, not Step.
- **Onboarding**: one `tutorial_catalog()` tip, `traps_deployed`, fired the first
  time a trap is deployed. The talent-web tip (`talent_first`, 08-08) is the model.

---

## 8. Animation — SPEC (M 08-08: scope it, generate nothing yet)

**No generation has happened and none should until M signs off on a gen count.**

### 8.1 Style baseline (mandatory check before any gen)
Per the house rule, new art is styled from what is already **shipped in-game**, not
from a prompt written in a vacuum. The closest shipped references are:
- `spr_ability_bear_trap` and `spr_ability_spike_trap` — the existing trap ICONS.
  These define the palette and the metal rendering the deployed art must match.
- The ability VFX Gigapack sprites (`SYSTEMS_COMBAT_FX.md`) — these define the
  spring-burst idiom, and a trap burst must sit alongside them without looking
  like a different game.
**Before generating anything I will pull those side by side and confirm canvas
size, palette and pipeline with M** — that verification is part of the spec, not
an optional first step.

### 8.2 What is actually needed

| # | Asset | Count | Notes |
|---|---|---|---|
| 1 | **Throw arc** | 1 shared | The player's deploy motion. ONE arc reused by all 7 traps — a per-trap throw is not worth 7× the spend when the object is barely visible in flight. |
| 2 | **Deployed idle** | 7 (one per trap) | The trap sitting on the ground, between player and enemies. This is the one that must be per-trap: it is what the player reads to know what is on the board. |
| 3 | **Spring burst** | 3 shared | Keyed to payload type, not to trap: *snap* (Bear/Wire/Tripline), *spikes* (Spike/Caltrops), *ward-flash* (Warding Chime/Death Snare). |

### 8.3 Sizing — decided by the UI, not by taste
The deployed idle is drawn inside the trap chip (**176 × 72**, `UI_BANDS.md`), so
it must read at roughly **64 × 48**. That is smaller than the class/creature
sprites and it is deliberate: these are props, not actors. Do NOT author them at
124px and downscale — the existing icon sprites are the correct reference scale.

### 8.4 Gen budget
7 idles + 1 arc + 3 bursts. At the per-asset rates this batch has been running,
**estimate ~60–90 generations**, comfortably inside the ~100/session cap — but it
still needs M's explicit yes, and the 2-bad-rolls-and-stop rule applies.

### 8.5 Sequencing
Blocked on a playtest of the mechanic (§9 steps 1–3 are built but not compiled).
If a trap gets cut or changes filter after M plays a Shadowstrider fight, its idle
is wasted art. One fight's feedback costs nothing and protects the whole batch.

---

## 9. Build order

1. **Data + deploy.** `player.traps`, `trap_slots`, deploy path, slot-full replace
   confirm. Traps deploy and sit there doing nothing. Verifiable in isolation.
2. **Trigger + spring** in the reaction stack. Convert Bear/Spike/Snare. The
   feature is now playable and the old behaviour is gone.
3. **UI strip + intent-match pulse + spring feedback.** The feature becomes
   legible.
4. **New traps** (the four committed).
5. **Talent retargeting** (Compounding Dread) + new nodes.
6. **IRONMAN save**, tutorial tip, `UI_BANDS.md`, balance pass.

Steps 1–3 are the rework. 4–6 are the depth.

---

## 10. Open questions for M

**RESOLVED 08-08 (recommended answers taken, M to override on playtest):**
1 no refund - 2 no enemy awareness - 3 bosses spring traps normally.

1. **Whiff insurance.** If a trap never springs before combat ends, is the
   Preparation refunded? Recommendation: **no** — the cost of a wrong read is the
   point, and a refund makes pre-deploying strictly correct.
2. **Enemy awareness.** Do enemies ever avoid a trap they can "see"? Recommendation:
   **no** for launch. It's an enormous AI change and it makes the player's
   prediction unreliable in a way that reads as unfair.
3. **Boss traps.** Should bosses spring traps normally? Recommendation: **yes**,
   but `block` on a boss's telegraphed nuke may be too strong — consider `block`
   downgrading to 50% reduction against boss abilities.
4. **Damage retune.** Confirmed expected (§3) — flagging it so it isn't a surprise.


---

## ICONS + SPRING VFX — 2026-08-09

All seven traps now have full ability treatment. The four that were missing art
were generated (PixelLab, styled from the three shipped trap icons — 64×64, dark
beveled stone frame, single centered glyph) and M-approved:

| trap | sprite | reads as |
|---|---|---|
| Tripline | `spr_ability_tripline` | taut wire between two stakes |
| Warding Chime | `spr_ability_warding_chime` | brass bell + cyan sound rings |
| Wire Snare | `spr_ability_wire_snare` | barbed-wire noose |
| Caltrops | `spr_ability_caltrops` | scatter of iron four-point spikes |

Wired in `ability_icon_sprite()` (`scr_ui.gml`) by direct identifier, so no
`__sprite_includes` entry is needed.

**Spring VFX (§8, partially answered):** a spring now fires `spr_vfx_snap` — a
sharp starburst from the owned Gigapack, 0 gens — at the trap's own ground
position, computed with the same geometry as `ui_draw_trap_field()` (ground line
712, span 300 from x560), and read *before* the spent trap is removed so the
burst lands on the right one. This is the cheap half of §8: the **deployed idle
props** are still procedural shapes, not sprites, and remain the open item.

**Still sequenced behind one Shadowstrider playtest** — if a trap gets cut or
changes filter after M plays a fight, its bespoke idle would be wasted art. The
icons were safe to do now because an icon survives any retune.


---

## DEPLOYED PROPS + DIAGONAL FIELD — 2026-08-09 (post-F5)

M, after playing the 08-08 build: *"the trap looks awful and it needs to be more
literally in the middle between the player and enemies for more obvious visual
play, like diagonally moved between them. it looks like literal line drawings
from paint."*

Both halves fixed.

**1. Real props.** Seven 64x64 side-on sprites, one per trap, each reading its
own role — `tools/import_trap_props_0809.py`.

| trap | sprite | prop |
|---|---|---|
| Bear Trap | `spr_trap_prop_bear` | rusted open jaws + chain |
| Spike Trap | `spr_trap_prop_spike` | stone plate, bloodied spikes |
| Death Snare | `spr_trap_prop_snare` | nest of black tendrils, verdigris tips, coiled open |
| Tripline | `spr_trap_prop_tripline` | two iron stakes, taut wire |
| Warding Chime | `spr_trap_prop_chime` | bell AT REST on a tripod, cyan runes |
| Wire Snare | `spr_trap_prop_wire` | barbed steel loop + peg |
| Caltrops | `spr_trap_prop_caltrops` | scattered bloodied caltrops |

Drawn at **2x** (128px) — the same chunky scale the 97px enemy sprites use at 3x.
Resolved by `trap_prop_sprite()` in `scr_ui.gml` by direct identifier, so no
`__sprite_includes` entry. A trap with no prop falls back to the old procedural
jaw glyph rather than crashing.

*Import gotcha worth remembering:* the raw generations float their content
anywhere in the 64px box, and the field anchors **bottom-centre**, so an
un-normalised prop hovers above the floor. The importer crops each frame to its
alpha bbox and re-pastes it bottom-aligned. That is the only reason the import
is not a straight file copy.

**2. Diagonal field.** `trap_field_pos(t, n)` puts the traps on a line running
from **(700,700)** at the player's feet up to **(1040,596)** toward the enemy
row — the one genuinely empty corridor on the combat screen. Both the draw
(`ui_draw_trap_field`) and the spring burst (`obj_combat_controller/Step_0`) call
that ONE helper, so the snap VFX can never drift off the prop.

Measured clearances (a script asserts these; `_for_review/trap_props_0809/LAYOUT_MOCK.png`
shows them to scale). Re-check every one before moving the line:

| neighbour | region | clearance |
|---|---|---|
| combat log | x30–1200, y735–945 | 35px below the lowest prop foot |
| enemy HP bars | x990–1885, y86–432 | 36px above the highest prop top |
| player sprite | ends ~x580 | leftmost prop edge x636 |
| enemy sprites | start x1143 at a 4-wide row | rightmost prop edge x1104 |

**Still open in §8:** the throw arc on deploy, and per-trap spring bursts (all
seven currently share `spr_vfx_snap`).

### Prop re-pick round 2 (M, same day)

Three changed after review, and the reasons generalise:

- **Death Snare** — the first batch gave rope-and-hooks, which fought the shipped
  icon. M: *"we made the icon plan tendrils holding the limbs of an enemy
  remember."* Re-generated bespoke as a tendril nest. **Lesson: the prop must
  match the ICON's fiction, not just the ability's name.**
- **Warding Chime** — the tilted mid-ring frame implied motion the prop never has.
  A deployed trap SITS there until something trips it, so it is drawn at rest.
- **Wire Snare** — swapped to the loop-plus-coil-plus-peg read.
