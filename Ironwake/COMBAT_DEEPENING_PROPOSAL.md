# COMBAT DEEPENING PROPOSAL — build expression & fun (2026-07-29)

**Status: DESIGN-LOCKED by M 2026-07-30.** Locked decisions:
- **Build order:** pinch zoom first (built 07-30), then P1 retype + P4 Mandate
  as one session, then P2 weaknesses. P3 riders stay parked.
  (07-30 later same day: M slid the HUB CAROUSEL in ahead of combat —
  SYSTEMS_HUB_CAROUSEL.md; effective order: carousel → P1+P4 → P2.)
- **P2 weakness axis: CREATURE ARCHETYPE**, not dungeon. Tag each enemy by what
  it is — undead→fire, construct/sentinel→shock, beast→frost, wraith→arcane —
  so variety survives inside each dungeon. (Bestiary "families" are per-dungeon;
  archetype is a NEW per-enemy tag added at P2 build time.)
- **AP refund: ONCE PER ENEMY PER COMBAT** (M's call) — each distinct enemy can
  grant the 1-AP Exposed Weakness refund one time per fight. A 4-pack offers up
  to 4 refunds total across the combat; no per-turn ad-infinitum loop.
- **P4 Mandate ships with FULL POTENCY RANKS** (R2–4 gold find w/ Legendary
  equipped, TRANSCEND = 3-turn protection).
- **P1 retype list:** full per-class audit table to be drafted at P1 build
  session start and approved by M before edits (per doc §2 candidates).

Written per M's 07-28 notes: "frost shot says
physical… that's the goal, people making their own builds like fire warden or
poison archer", "more ways for classes to utilize other stats", the Mandate
from Heaven trait idea, and "do some research on games known for fun turn
based combat."

---

## ✅ BUILT 08-01 (ALL FOUR PHASES, one session — M approved each table live; awaiting F5)
- **P1**: Poison Dart (7 dmg) + Frost Shot (12 dmg) retyped dtype 1; **Death
  Snare stays physical (M's call** — silence-blocking trap placement felt wrong).
- **P2**: map below shipped verbatim in `enemy_weak_school()` (scr_enemies,
  name-keyed); +30% & once-per-enemy AP refund at the player damage site;
  school-colored diamond on the intent chip; "weakness" coach-mark.
- **P4**: Mandate from Heaven trait live (Vex 2000g + Legendary; cleanse guard
  in combat_cleanse_one via applied_round stamps; R2-4 +4%/rank gold find w/
  Legendary; Transcend "Divine Right" = 3 turns; "the MANDATE holds" log line).
- **P3 SLIM (M approved after explainer)**: 9 off-stat riders live
  (ability_stat_rider catalog + threshold check; RIDER section in the Tab
  detail + loadout detail, gold when active / grey with "you: N" when not):
  Entropy WIS25 +1/tick · Soul Shield CON20 +5 · Gravewrack Grip STR25 root 2t
  · Blood Leech INT20 +4 heal · Iron Skin WIS20 4 turns · Marrow Crush CON25
  +4 shield · Bear Trap WIS25 root +1t · Snipe STR25 +15% crit dmg · Field
  Dressing/Second Wind CHA20 +20% healing.

## BUILD-SESSION AUDIT TABLES (08-01 — drafted per the lock; M approved live)

### A. P1 retype table (full audit of all 41 abilities)

Audited every ability across Arcanist (18), Bloodwarden (15), Shadowstrider
(16 incl. Winter's Bite) + general pool (5). Arcanist is already fully
elemental; Bloodwarden's kit is blood-typed (dtype 3) where flavored;
Winter's Bite was born dtype 1. **Exactly THREE abilities are elementally
flavored but physically typed — all Shadowstrider:**

| ability | today | retype to | base dmg | notes |
|---|---|---|---|---|
| Poison Dart | dtype 0 phys + school poison | dtype 1 elemental | 6 → 7 | "poison archer" unlocked; INT gear scales it; el_resist not armor |
| Frost Shot | dtype 0 phys + school frost | dtype 1 elemental | 10 → 12 | THE bug M reported 07-28; frost affix gear + (P2) frost weaknesses apply |
| Death Snare | dtype 0 phys, no school | dtype 1 + school poison | 32 → 34 | fits the tendril art (M's lock note). ⚠ becomes a SPELL for control gating — an enemy SILENCE could block placing it (root won't). Can stay physical if that feels wrong. |

Everything else stays: traps/blades/Snipe are honestly physical, blood kit is
blood, DoT *statuses* (bleed/poison elements) are unaffected either way.
Desc_short/full strings for the three get their element words updated same
edit. Crit stays DEX-typed (they become spells for silence purposes but keep
the phys-crit channel — the DEX identity survives).

### B. P2 per-enemy weakness map (archetype axis, locked 07-30; draft assignments)

Rule of thumb applied: undead→fire, construct/sentinel→shock, wraith/spirit→
arcane, beast→frost — EXCEPT fire-born creatures→frost (quench) and ice-born
→fire (thaw), so each dungeon still reads varied and no enemy is weak to its
own element. Bosses DO have weaknesses (build payoff); the Ashen Duelist has
NONE (pure duel). Implementation: name-keyed `enemy_weak_school(name)` map —
zero edits to the enemy_define pools, clones inherit automatically.

| Ashen Vault | weak | Scorched Depths | weak | Tundra Tomb | weak |
|---|---|---|---|---|---|
| Ashen Skeleton | fire | Cinder Imp | frost | Ice Specter | fire |
| Skeleton Archer | fire | Magma Slug | frost | Frost Shard | fire |
| Vault Crawler | frost | Ash Wraith | arcane | Frozen Thrall | fire |
| Dungeon Wraith | arcane | Lava Spitter | frost | Snowbound Wraith | arcane |
| Bone Colossus (std+boss) | fire | Fire Drake | frost | Glacial Lurker | shock |
| Stone Golem | shock | Smoldering Revenant | arcane | Pale Archivist | arcane |
| Vault Guardian | fire | Cinder Golem | shock | Glacial Beast | shock |
| Vault Wraith | arcane | Infernal Revenant | arcane | Frozen Sentinel | shock |
| Vault Sentinel | shock | Forge Tyrant (boss) | shock | Glacial Warden (boss) | fire |
| Grave Stalker | frost | Molten Revenant (boss) | arcane | Tomb Archon (boss) | arcane |
| Bone Sovereign (boss) | fire | The Ashen Colossus (boss) | shock | The Eternal Frost (boss) | fire |
| Malgrath the Warden (boss) | arcane | | | |

Spread: fire 10 / arcane 9 / shock 8 / frost 7 — every school has real
targets, frost's smaller count offset by owning most of Scorched Depths.

Hitting a weakness: **+30% damage + 1 AP refund ONCE PER ENEMY PER COMBAT**
(locked), "EXPOSED WEAKNESS!" log line, school glyph beside the intent-row
Melee/Ranged tag (perfect information), one coach-mark.

### C. P4 Mandate from Heaven — as locked (no open questions)

Vex trait: 2000g + Legendary sacrifice. R1: statuses YOU apply uncleansable
2 turns (applied_round stamp; cleanse sites skip young statuses). R2–4:
+gold find while a Legendary is equipped. TRANSCEND: 3-turn protection.
Control-resist ramp NOT bypassed.

---

## 1. What the research says (and how Ironwake measures up)

Four widely-studied systems, one line each on why they're fun:

- **Slay the Spire** — fun lives in the BUILD: every fight advances your
  engine, and synergies make 2+2=7. *(Ironwake: talent webs + traits + runes
  already do this; ability SYNERGY discounts too. Strong.)*
- **Shin Megami Tensei (Press Turn)** — hitting an elemental WEAKNESS is
  explosively rewarded (extra actions), so knowing the enemy matters every
  single turn. *(Ironwake: schools exist but enemies have no per-school
  weaknesses — el_resist is one flat number. This is our biggest untapped
  vein.)*
- **Into the Breach** — perfect information: you see exactly what enemies
  will do and the fun is unpicking it. *(Ironwake: intent chips already
  telegraph enemy actions. Solid since the 07-03 audit.)*
- **Darkest Dungeon** — a second resource axis (stress) makes fights matter
  beyond HP. *(Ironwake: bond/hunger/corruption push this OUTSIDE combat;
  adding an in-combat second axis would be a huge lift — not recommended
  pre-launch.)*

**Distilled:** Ironwake is already strong on build-engine and telegraphing.
The gap is **elemental identity** — schools are cosmetic damage riders today,
not a decision axis. Everything below pulls on that one thread so the
proposals reinforce each other instead of adding parallel systems.

---

## 2. P1 — TRUE ELEMENTAL TYPING (the retype pass)          [cheap, unlocks the rest]

**Today:** `damage_type` is the real scaling axis — dtype 0 (physical) scales
with STR-side `phys_dmg_bonus` and is cut by armor; dtype 1 (elemental) scales
with INT-side `elem_dmg_bonus` and is cut by el_resist. Frost Shot, Poison
Dart, Winter's Bite riders etc. are dtype 0 with a school TAG — so they read
"physical", scale off the class primary, and ignore INT entirely.

**Change:** retype elementally-flavored abilities to dtype 1 + correct school
tag. Immediate effects, all from existing code paths:
- INT gear/stats now scale them (`elem_dmg_bonus`) → **frost archer / poison
  archer are real builds on day one**.
- School-damage affixes (caster-slot gear) now apply → gear chase per element.
- Descriptions auto-read the element (desc pipeline reads dtype/school).
- Armor-heavy enemies stop double-dipping against them (el_resist instead).

**Candidate list (SS):** Poison Dart, Frost Shot, Winter's Bite, Death Snare
(poison — fits the new tendril art), Smoke Bomb stays utility. **(BW):** blood
kit is already dtype 3; Ember/fire riders where flavored. **(Arcanist)**
already elemental. Full audit table comes at design-lock.

**Risk:** SS/BW players who stacked primary stat lose a few points of damage
on retyped abilities. Mitigation: +1–2 base damage on each retyped ability so
parity-stat damage is unchanged; INT investment is pure upside.

---

## 3. P2 — SCHOOL WEAKNESSES + EXPOSED WEAKNESS (the SMT borrow)   [the fun multiplier]

Give each enemy FAMILY one `weak_school` (undead→fire, constructs→shock,
beasts→frost, wraiths→arcane…) shown as a small school glyph beside the
Melee/Ranged tag (perfect-information rule).

**Hitting a weakness:** +30% damage AND — once per player turn — **refunds
1 AP** ("Exposed Weakness!"). That's the SMT dopamine loop sized for our AP
economy: build variety in, tempo out. Enemies do NOT get the refund (our
enemies already got their 07-28 AI buffs; the asymmetry is deliberate,
Into-the-Breach-style player-favored clarity).

**Why it synergizes:** P1 makes elemental abilities scale; P2 makes CARRYING
a second element worth a loadout slot even off-build. Multi-school dipping →
off-stat investment (INT for the frost dip) happens naturally — this is the
honest answer to "more ways to use other stats" without a stat-rework.

---

## 4. P3 — SECONDARY STAT RIDERS (the off-stat pass)        [design-heavy, do LAST]

Every class ability gets one small visible rider keyed to a NON-primary stat,
shown as its own line in the Tab detail popup ("Rider: +1 turn root at 25
WIS"). Examples: Bear Trap root +1 turn @ WIS 25; Snipe +15% crit damage @
STR 25; Arcane Bolt small splash @ DEX 25; heals +X% @ CHA 20.

This is the direct answer to "you ignore almost all stats except your
primary" — but it's ~40 ability designs + balance. Recommend AFTER P1+P2
prove the elemental economy, because P1/P2 may already soak the off-stat
itch (INT dips, WIS control durations) with zero new design surface.

---

## 5. P4 — MANDATE FROM HEAVEN (M's trait, spec'd)          [cheap, ships with P1]

- **Cost:** 2000 gold + one Legendary item (Vex trait tab already supports
  gold + rarity-matched item sacrifice).
- **Effect:** statuses YOU apply cannot be cleansed for 2 turns (stamp
  `applied_round` on the status; the new `combat_cleanse_one` + A2+ heal
  riders skip anything younger than 2 rounds).
- **Fantasy:** the heavens ratify your claims — enemy menders' hands falter.
- **Design note:** this is the premium answer to the 07-28 cleanse AI. The
  cleansers stay annoying (that's their job — M: "you must get more
  creative"); Mandate is the expensive late-game opt-out, and it makes
  DETONATION setups (which cleansers currently eat) reliable again. Suggest
  it does NOT protect against the control-resist ramp (resist is the enemy
  fighting through, not a cleanse) so the anti-perma-lock guard survives.
- **POTENCY ranks:** R2-4 = +gold find while a Legendary is equipped (flavor
  echo), TRANSCEND = protection extends to 3 turns. (Optional, can ship R1.)

---

## 6. Recommended sequencing

1. **P1 retype + P4 Mandate** — one session, mostly data edits, immediately
   delivers "frost archer works" + the trait M asked for.
2. **P2 weaknesses + AP refund** — one session (enemy family data + one hook
   at the damage site + intent-row glyph + coach-mark). This is the biggest
   fun-per-effort item in this doc.
3. **P3 riders** — its own design-lock later; may shrink after P2 lands.

Nothing here touches save format. P2 adds enemy data only. All three build on
systems that already shipped (schools, AP, detonation, intent chips, Vex
trait-buys, the 07-28 cleanse AI).

**Questions for M at design-lock:** weakness map per family; whether the AP
refund is once/turn or once/combat; Mandate potency ranks yes/no; the P1
retype list per class.

---

*Sources: [Turn Based Lovers — amazing turn-based combat systems](https://turnbasedlovers.com/lists/10-games-featuring-an-amazing-turn-based-combat-systems/),
[Game8 — SMT V Press Turn guide](https://game8.co/games/Shin-Megami-Tensei-V/archives/348265),
[CBR — how Press Turn works](https://www.cbr.com/shin-megami-tensei-press-turn-system/),
[Megami Tensei Wiki — Press Turn](https://megatenwiki.com/wiki/Press_Turn_System),
[TheGamer — best turn-based roguelikes](https://www.thegamer.com/the-best-turn-based-roguelikes/).*
