# DELIVERY MUTATORS — design locked 08-11 (M's answers), v1 BUILT same day

M's brief: "more unique modifiers like 'spells that bounce, bounce 1 additional
time'... static arc/lightning chain is dif than a simultaneous aoe, its a rng
bounce per enemy hit with their own visual VFX and sequential damage."

## Locked decisions (M, 08-11)
- **Eligibility:** SPELLS ONLY — plus specific bespoke abilities we add to the
  category (Ricochet Shot, Bouncing Bomb, etc.), some per class, asymmetric is
  fine. Bloodwarden candidates: Plague Touch / blood spells. Arcanist benefits
  most inherently.
- **Stacking:** ONE mutator per cast. Priority: legendary affix > web node > innate.
- **Numbers:** baseline table below + per-school variety.
- **Carriers (strong):** 4 NEW named legendaries.

## The four mutators

| Mutator | Weak (web node) | Strong (legendary) | School spice (+pct) |
|---|---|---|---|
| BOUNCE — after the hit, arcs on to 1 random other enemy (sequential, delayed) | 40% | 60% | shock +15, arcane +5 |
| SPLIT — forks simultaneously to 1 other enemy | 50% | 70% | arcane +10, frost +5 |
| ECHO — the hit repeats on its target moments later (original dead → random) | 35% | 50% | void +10, shock +5 |
| LINGER — leaves a 2-turn DoT on the target (per-tick % of the hit) | 30% | 45% | fire +10, poison +10, blood +5 |

Static Arc is EXCLUDED — its native chain (50%, ALL if shocked, Storm Unbound
100%) already owns the bounce identity for that ability.

## v1 BUILT (08-11)
- `ability_delivery_mutator(ab)` + `mutator_school_bonus()` (scr_abilities end).
- Combat: `mutator_queue` on the controller; BOUNCE/ECHO resolve as delayed
  sub-hits (22 / 80 frames) through `combat_resolve_damage` at the reduced pct;
  SPLIT is an immediate fork (splash pattern); LINGER pushes a kind:"dot"
  status (element = school, source "player") so existing DoT ticks + the Ember
  Saint's Censer +2 both apply.
- Web nodes (weak): Hoarfrost Lance "Shatterfork" (mut_split:50 — frost +5 ⇒ 55),
  Entropy "Recurrence" (mut_echo:35 — void +10 ⇒ 45), Blood Leech "Seeping
  Wound" (mut_linger:30 — blood +5 ⇒ 35 bleed), Poison Dart "Pooling Venom"
  (mut_linger:30 — poison +10 ⇒ 40).
- Legendaries (strong, any qualifying spell): Stormskip Band (ring, BOUNCE),
  Prism of the Twinned Flame (offhand, SPLIT), Bell of the Second Toll
  (amulet, ECHO), Smolderbrand Mantle (chest, LINGER). Icons: TBD batch for
  M approval (resolver falls back safely meanwhile).

## v2 BUILT 08-11 (same night, awaiting F5)
- **Innate carriers live**: Shadowstrider **Ricochet Shot** (1 AP + 1 Prep,
  12 phys, innate BOUNCE 50%, Vex 250g) and **Bouncing Bomb** (2 AP, 16 phys,
  BOUNCE with 2 DECAYING hops at 40% each - each hop's base is the previous
  landed damage, Vex 400g); Bloodwarden **Gout of Rot** (1 AP + 1 Blood, 11
  Poison spell, innate LINGER 40% ⇒ 50% with poison spice, Vex 250g). All
  registered: pools (appended, indices stable), offense category, ranged by
  default, descs, icon remaps (Snipe / Smoke Bomb / Plague Touch) with
  string-resolved bespoke sprites that light up when the icon batch imports.
- **Bounce is a real traveling bolt now**: the queue resolves a bounce by
  launching a projectile between the two enemies and applying damage on
  ARRIVAL (new "hit" queue entries timed to the flight). Multi-hop chains
  re-launch from each victim.
- **Echo fires on the ACTUAL next player turn** (wait_turn entries; the old
  frame countdown remains only as a never-hang fallback, e.g. if the whole
  enemy phase is stunned away).
- **New weak node** (M: "talents that make spells bounce as well"):
  Galvanize t2 "Live Current" (mut_bounce:40 + shock 15 ⇒ 55%).
- **⚠ Web-node id fix**: the four v1 weak nodes had shipped with an appended
  id "mt", which the replace-only bespoke merge silently DROPPED (the web UI
  draws exactly six ids). All four now claim real slots: Shatterfork → pk,
  Recurrence / Seeping Wound / Pooling Venom → t2. A save that had woven
  those slots sees the pick morph - flagged for M's F5.

## v3 backlog
- Bespoke icons for the 3 carriers (approved art batch; remaps hold till then).
- More weak bounce/split nodes if the family plays well (arcane candidates).
