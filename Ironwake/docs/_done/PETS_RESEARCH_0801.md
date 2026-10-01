# Pets deepening research — 2026-08-01 (M-requested, NOT design-locked)

M's brief: research how to make the pet system (1) more emergent, (2) pets that
feel unique (builds or abilities), (3) a visually/meaningfully expanded garden.
This doc is the research output — nothing here is built. Each pillar lists
options ranked by my recommendation, with rough build cost.

## Where the system stands (code audit, 08-01)

What carries mechanics today: **archetype** (Boon/Combatant/Guardian — rolled at
creation), stage, stats (POW/SPR/LCK talents), stances, kit (2 auto traits +
Stage-3 capstone from a 4-pool + Awakened crossover splash), bond tier, hunger,
injuries, corruption arc, egg-type boon.

What does NOT carry mechanics: **species**. All 16 generic + 9 signature species
differ only in name, blurb and sprite — the single species-mechanical hook in
the game is the preferred feed (growth bonus). Two same-archetype pets of
different species play identically. Signature (boss) pets are marked
`signature: true` but the flag only gates the awk stat ceiling.

Cross-system audit: pets touch gold/loot find, combat (strike/guard/intercept),
events (Sharp Eye capstone) — and nothing else. No interaction with curses,
boons, Element Schools, dungeons/floors, shrines, the board, other NPCs, or
each other. Corruption is the only "story arc" a pet can have, and it's opt-in
at a single site.

The garden: a ≤150px strip under the Bairc roster, max 7 donated creatures on
sine-wander, hidden entirely when space is short. Donated creatures are frozen
structs {species, name, stage} — donated eggs stay stage 0 forever even though
Bairc's donate copy promises "he hatches it in his own time."

## Comparator lessons

- **Chao Garden** (the genre's high-water mark): the loop that made it beloved
  was *things you find in the core game shape the creature* — animals carried
  back from levels changed stats AND appearance. Lifecycle + visible
  consequence of care built the attachment. Ironwake's equivalent hook exists
  (feeds, dungeon drops) but drops nothing species- or history-shaped into the
  pet.
- **Hades keepsakes/companions**: few in number but each has a *named, loud,
  once-per-run moment*. Ironwake capstones are passive percentages; nothing a
  pet does is ever a spectacle.
- **Monster-raiser genre** (Monster Rancher / DQ Monsters): uniqueness =
  species innate + individual variance on top, so two of the same species
  still differ.

## Pillar 1 — Emergence (pets reacting to, and bending, the rest of the game)

Emergence = systems colliding where the player didn't script it. Ranked:

**1a. Pet MEMORIES → quirks (recommended, the big one).** Track 2-3 counters on
the pet struct from things that actually happen (knocked out by a school-X
enemy; present at a full clear of dungeon Y; carried through N curses; fed at
starving M times). At thresholds the pet develops a named QUIRK shown on its
sheet with the story attached — e.g. KO'd twice by Ember enemies →
"Flinches at Flame" (-10% vs Ember floors) OR, if it *survived* the KO run,
"Emberscarred" (+10% there). Quirks are the pet's biography made mechanical —
pure emergence, and it reuses the epithet flavor Ironwake already speaks.
Cost: M (struct fields + ~8 quirk defs + sheet row; save-safe lazy fields).

**1b. Species × dungeon affinity.** Each species has a home biome (crypt_bat →
Tundra Tomb, cinder_newt → Scorched Depths...). At home: small bonus (+1 stance
slot use, +10% its effect) and a garden/roster tag. Signature pets feel it
hardest — kin of the boss, stronger in the boss's halls. Cheap, thematic,
makes WHICH pet you carry a per-run decision instead of "always my best."
Cost: S-M (catalog field + 2-3 hook sites).

**1c. Pets react to CURSES/BOONS.** A carried pet responds to run modifiers:
a Guardian whimpers under Blood-price curses (intercept chance up — it's
protective), a Boon pet's LCK spikes under gold curses, corrupted-pushing pets
*like* curses (corruption run counts double on cursed runs — synergy with the
existing arc). A few hand-picked pairings, surfaced as one-line combat log
notes. Cost: S per pairing.

**1d. Stable social layer.** Pets stabled together develop one liked/disliked
companion (deterministic from uid pair); feeding crowd penalty softens for
friends, garden wander pairs them. Light, mostly-cosmetic emergence that makes
the stable feel alive. Cost: S (display + feed-mult tweak).

## Pillar 2 — Unique-feeling pets

**2a. Species INNATE (recommended, do first).** One small named passive per
species, always on, listed at the top of the kit: crypt_bat "Echo Sense"
(enemy intent visible one extra slot), voidkit "Slip Between" (10% dodge the
first blow aimed at it), glimmer_slime "Gemcrust" (+3% gold),
shellback "Runeshell" (+1 armor to the player)... 25 one-liners, one per
species. This single change makes species ≠ skin everywhere at once — roster,
hatch reveal, boss-egg chase ("I want a NIGHTOWL guardian"). Egg identify and
the once-per-save signature ledger both get more interesting for free.
Cost: M (catalog field + pet sheet line + ~8-10 of the 25 having real hooks at
launch; rest can start cosmetic-adjacent).

**2b. Signature pets get a SIGNATURE MOVE.** The 9 boss species each carry one
loud once-per-combat ability echoing their boss (Gaolwyrm: chains the enemy's
next action; Golemite: taunts a hit into its stone shell; Hoarfrost Drake:
freezes an enemy's intent for a turn). This is the Hades lesson — named,
visible, rare. Boss eggs are once-per-save now; the reward should be a MOVE,
not a stat ceiling. Cost: M-L (9 combat effects + VFX/log lines), can ship 3
per session.

**2c. Temperament roll.** Each hatch rolls 1 of ~6 temperaments (Fierce, Timid,
Stoic, Greedy, Doting, Strange): ±small stance-flavored bias (Fierce combatant
crits more but intercepts less...). Two same-species same-archetype pets now
differ. Cheap Monster-Rancher-style individuality. Cost: S-M.

**2d. Capstone pool × species reskin.** Same mechanics, species-flavored names
("Rend" on a duskraven = "Carrion Harvest"). Pure flavor, near-zero risk.
Cost: S (name table).

Recommended composite: 2a + 1a give every pet a THREE-layer identity —
species innate (what it IS) + archetype kit (what it DOES) + quirks (what it's
LIVED) — which is the full monster-raiser uniqueness stack.

## Pillar 3 — Bairc's garden

**3a. Donated creatures KEEP GROWING (recommended, fixes a promise the UI
already makes).** Each completed run, donated creatures gain garden-growth;
eggs hatch, babies age toward adult over ~6-8 runs. The garden becomes a
time-lapse of your generosity — donation stops being a stat sink and becomes
planting. Cost: S (one tick in pet_run_complete + the stored stage field
already exists).

**3b. Full GARDEN VIEW screen.** Promote the 150px strip to its own screen
(from Bairc: "Visit the Garden" / a gate key). Layered backdrop (existing hub
atmosphere pipeline), creatures wander on 2-3 depth lanes at proper scale with
name tags on hover/tap, ambient SFX reuse. Room for every donated creature —
the +N more cap dies. This is where the collection finally *looks like* a
collection. Cost: M-L (one new UI screen + a backdrop gen; input parity +
scroll rules apply).

**3c. Garden BLESSING (meaningful).** The garden tends back: a small hub-wide
passive scaling with garden population/stages (e.g. +1% growth food value per
2 residents, cap +10%; or a free feed pouch item per N runs "from Bairc").
Makes donating a real economy loop without power-creeping runs. Cost: S.

**3d. Memorial stones.** Permadead pets (injury ladder) get a small stone in
the garden with name + epithet; Bairc has a lore line for the first one.
Cheap, and it makes loss part of the story instead of a silent array_delete.
Cost: S.

**3e. Garden keepsakes.** Residents occasionally leave a gift on the next hub
return (a preferred feed, 5 dust, once a rare egg at high population) — the
Chao "visible consequence of care" beat. Cost: S-M.

## Suggested build order (if M locks all three pillars)

1. 3a + 3d + 3c (small, self-contained, garden immediately meaningful)
2. 2a species innates (the uniqueness backbone)
3. 1a memories/quirks (the emergence backbone)
4. 3b garden screen (art + UI session)
5. 2b signature moves (3 per session alongside other work)
6. 1b/1c/1d/2c as batch filler

Sources consulted: Chao Garden design retrospectives (attachment via lifecycle
+ core-loop integration), Hades companion/keepsake pattern (few but loud),
monster-raiser genre conventions (innate + individual variance).

---

# DESIGN LOCK v1 — M APPROVED ALL FOUR PILLARS 08-01; BUILT same session
# (A + B + C in full; D = Tundra trio, 6 moves remain). Awaiting F5.
# Implementation deltas from the approved tables:
# - Ember Memory (wyrmling): school_dmg is a FLAT rider, not a %, and the
#   school id is "fire" — shipped as +3 flat Fire damage on Fire abilities.
# - Last Words (duskraven): pays via the shared kill handler; elites killed by
#   DoT ticks use the separate inline path and skip it (v1 scope note).
# - Innates are always-on (not injury/hunger-gated); signature MOVES are gated
#   on the pet being fit to act and sit out duels, like all pet actions.
# - Echo Shriek/Still Breath/Long Winter statuses ride existing kinds
#   (vulnerable / weaken / stun); Long Winter = 1-turn stun at combat start.

Only existing systems are referenced (statuses verified in scr_combat: stun /
root / silence / poison / bleed / burn / exposed — no chill exists, so frost
effects use damage-down or delay instead).

## A. Garden small-batch

- **Growth ticks**: every SURVIVED run (extract or clear), each garden
  resident gains 1 tick. Donated eggs hatch at 1 tick (they already render as
  babies — now it becomes true). Stage-ups: baby→adolescent 2, →youngadult +3,
  →adult +3 (~8 survived runs egg→adult). Garden caps at Adult — only carried
  creatures Awaken (lore intact). Lazy `gg` field on the donated struct
  (old saves safe).
- **Memorial stones**: permadeath (injury ladder top) adds {name, species} to
  `global.bairc_memorials` (saved/loaded/reset with the explicit-assignment
  pattern). Drawn as small primitive headstones at the right end of the garden
  strip, name beneath in fnt_ui_small; new Bairc lore line "first_loss".
- **Garden blessing**: +1% feed growth value per 2 residents, cap +10%
  (hooks pet_feed_effective_growth). Shown in the garden header:
  "HIS GARDEN (n) — blessing +x% growth".

## B. Species innates (generic 16 — signature 9 are covered by pillar D
instead, so boss pets stay categorically different)

One always-on named passive per species, ~half a capstone in power, listed
first on the pet sheet. Works for ANY archetype (player-side or universal).

| species | innate | effect |
|---|---|---|
| luna_moth | Lunar Grace | +3% Spell Crit |
| bone_stag | Cathedral Calm | +1 Armor |
| saber_hound | Pack Snarl | +2% Phys Crit |
| gloomtoad | Mire Stare | first enemy attack on you each combat -10% dmg |
| wyrmling | Ember Memory | +5% Ember school damage |
| nightowl | Long Watch | +5% event stat-check success |
| bonehound | Grave Loyal | its bond gains +25% |
| hollow_pup | Empty Comfort | +5% to all healing you receive |
| duskraven | Last Words | +15 gold whenever an ELITE dies |
| pale_widow | Venom Thread | your bleed/poison statuses last +1 turn |
| shellback | Runeshell | +1 Armor, +1 El Resist |
| thorn_boar | Bramble Hide | attackers take 2 thorns damage |
| glimmer_slime | Gemcrust | +4% gold find |
| sporeling | Spore Cloud | 5% chance attackers are Poisoned |
| voidkit | Slip Between | first blow aimed at you each combat: 10% full miss |
| ironshell_beetle | Riveted Plate | +2 Armor |

## C. Memories → quirks (max 2 per pet, first-earned lock; sheet shows the
story line, e.g. "KO'd twice in the Scorched Depths")

Lazy counters on the pet struct; quirk rolls resolve at run end with a notice.

1. **KO'd twice in dungeon D** → roll: Vengeful ("+10% its actions in D") vs
   Flinches ("-10% in D"). Bond decides the odds: tier 0-1 40/60, tier 2+
   70/30 — trust turns fear into fury.
2. **3 full clears of D while carried** → "Master of D" (+5% its effect in D).
   Exclusive with #1 per dungeon; first earned wins.
3. **Carried through 5 cursed runs** → "Curse-Eater" (+5% its effect while
   any curse is active).
4. **Hit 0 HP but the run survived** → "Deathdodger" (once per run it shrugs
   its first KO, staying at 1 HP).
5. **Fed while STARVING 3 times** → "Grateful Belly" (hunger decays 25%
   slower).
6. **Present at a boss FIRST kill** → "Boss-Blooded" (+3% its effect vs
   elites and bosses).

## D. Signature moves (the 9 boss species; once per combat, auto-trigger,
log line + screen-flash; replaces the "awk stat ceiling" as the signature
pets' real payoff — ceiling stays, move is the star)

| species (boss) | move | effect (once per combat) |
|---|---|---|
| vaultling (Vault Sentinel) | Warden's Seal | negates the first enemy ABILITY (not basic attack) that would hit you |
| marrow_adder (Bone Sovereign) | Marrow Crown | when an enemy first dies, the weakest survivor takes 10% max-HP damage |
| gaolwyrm (Malgrath) | Gaol Chains | the first elite/boss ability readied against you is STUNNED away (1 turn) |
| cinder_newt (Forge Tyrant) | Forge Spark | your first attack each combat also applies Burn |
| magma_leech (Molten Revenant) | Slagpearl | each combat victory drips +8 gold |
| golemite (Ashen Colossus) | Stoneshadow | the first blow that would drop you below 50% HP is halved |
| rimefox (Glacial Warden) | Still Breath | the first enemy to act deals -25% damage for 2 turns |
| crypt_bat (Tomb Archon) | Echo Shriek | first time you fall below 40% HP, ALL enemies are Exposed |
| hoarfrost_drake (Eternal Frost) | Long Winter | the first elite/boss action of the combat is delayed one turn |

Build order once approved: A → B → C → D (D ships 3 moves per session).
