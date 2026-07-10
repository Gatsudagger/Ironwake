# Balance Design Note — 2026-07-09 (Bucket C — **DESIGN-LOCKED, M approved all sections 2026-07-09**)

**STATUS: C1–C7 ALL APPROVED as written (M, interactive review 07-09). No re-design loops —
implement as documented; flag issues but build to spec.** Current values verified against
live code (file refs inline).

---

## C1. Awakening difficulty per tier — "harder, but not just stat walls"

**Current** (`scr_combat.gml` awaken_* tables):

| Tier | Enemy HP | Enemy DMG | Enemy ACC | Enemy self-heal | Packs | Extra |
|---|---|---|---|---|---|---|
| A0 | ×1.00 | ×1.00 | +0 | ×1.00 | 2–3 | — |
| A1 | ×1.20 | ×1.15 | +0 | ×1.15 | 2–3 | — |
| A2 | ×1.45 | ×1.35 | +5 | ×1.35 | 4s common | — |
| A3 | ×1.75 | ×1.60 | +10 | ×1.60 | 4s common | — |
| A4 | ×2.10 | ×1.90 | +18 | ×1.90 | 4–5 | — |
| A5 | ×2.55 | ×2.30 | +28 | ×2.30 | 4–5 | Bosses +25% HP/dmg |

**Problem:** tiers only pile on stats; A3→A5 feels like the same fight with bigger numbers.

**Proposal — one NEW BEHAVIOR per tier (StS-ascension style ladder), plus a modest top-end stat bump:**

| Tier | New behavior (stacking) | Stat change |
|---|---|---|
| A1 | (none — entry tier) | unchanged |
| A2 | Enemies open combat with their ability available turn 1 (no warm-up round) | unchanged |
| A3 | **Smart targeting:** ability-users stop wasting control on already-controlled targets; healers heal the MOST wounded ally, not a random one | unchanged |
| A4 | **Coordinated packs:** one extra ELITE spawn per floor; pack members won't stack the same debuff on you (they diversify) | HP ×2.10 → **×2.20** |
| A5 | **Boss enrage:** floor bosses gain +10% damage each round after round 6 (fights can't be turtled) | HP ×2.55 → **×2.75**, DMG ×2.30 → **×2.45** |

Rationale: behaviors make higher tiers *feel* different and punish autopilot; the stat bump is
small because C3 (XP scaling) simultaneously makes the player stronger at high tiers.

---

## C2. Loot rarity scaling with Awakening — "feels off"

**Current** (`drop_weights`, A0→A5 lerp): at **A5** standard mobs are still **45% common**,
5% epic, 0% legendary. Boss floors fixed 07-09 (F2 uncommon+, F3 rare+), mobs untouched.

**Proposal — steepen the A5 anchors only** (A0 anchors unchanged; the lerp handles the middle,
so every tier between also improves smoothly):

| Source | A5 today [C,U,R,E,L] | A5 proposed |
|---|---|---|
| standard | [45, 33, 17, 5, 0] | **[28, 36, 24, 10, 2]** |
| elite | [22, 38, 28, 10, 2] | **[10, 30, 34, 20, 6]** |
| chest | [33, 37, 22, 7, 1] | **[20, 36, 28, 13, 3]** |
| vault | [25, 38, 26, 9, 2] | **[12, 32, 32, 18, 6]** |
| boss | [6, 28, 38, 22, 6] | **[0, 20, 38, 30, 12]** |

Net effect at A5: a standard mob is worth opening the loot screen for (36% rare+, was 22%);
legendaries actually exist outside bosses (2% mobs / 6% elites). The awakening panel's new
"Rare+/Epic+ drops" lines (shipped this batch) will show these numbers live.

---

## C3. XP & permanent points at A5 — "max lvl ~8, never 10"

**Root cause found:** enemy XP does **NOT scale with Awakening at all** (`combat_on_enemy_defeated`:
xp_value × floor mult 1.0/1.25/1.5 only). At A5 enemies have ×2.55 HP but pay A0 XP.
Perm points (safe return): L5/10/15 → 1/2/3 (`scr_stats.gml` ~416). L10 needs 820 cumulative
XP; a thorough A5 clear currently lands ~500–650 → L8 → 1 point. Working as coded, not as intended.

**Proposal — Awakening XP multiplier** (applied at both kill sites, shown on the awakening panel):

| Tier | XP mult |
|---|---|
| A0 | ×1.00 |
| A1 | ×1.15 |
| A2 | ×1.30 |
| A3 | ×1.50 |
| A4 | ×1.75 |
| A5 | ×2.00 |

Expected outcome: a thorough A5 full clear ≈ 1000–1300 XP ≈ **L11–12 → 2 perm points**;
L15 (3 points) stays a trophy for kill-everything A5 runs. Skipping fights still costs levels —
that tradeoff is intended and stays.

*Alternative (if ×2.0 feels too fast): add an L8 perm rung instead — L5/8/12/15 → 1/2/3/4 —
and a smaller XP mult (A5 ×1.5). My recommendation is the XP mult; it also fixes mid-run
pacing (you reach your build's abilities sooner on hard tiers, where you need them).*

---

## C4. Rend vs Executioner (pet capstones) — strict dominance

**Current** (`pet_kit_catalog`): Rend = **+50% attack damage, always**. Executioner = **+40%
below 30% HP** — worse magnitude AND conditional. Nobody should ever take Executioner.

**Proposal:** Executioner → **"+100% damage to enemies below 30% HP, and its strike SLAYS
outright a non-elite, non-boss enemy below 15% HP."**
Math: ~30% uptime × 100% ≈ same average as Rend's flat 50%, but it deletes the wounded-enemy
tail (anti-heal, anti-"one more turn each"), while Rend stays the consistent pick. Two real
identities: metronome vs finisher.

---

## C5. Fortune pets — "feel less useful than Guardian or Warrior"

**Current:** everything Fortune does is economy: gold 5/8/12/15% by stage, loot-find 3/5/6 pts,
kit = Prospector +4% gold (S1), Lucky Streak +2% loot (S2), capstones Windfall +8% gold OR
Treasure Sense +4% loot, splash +6%/+2%, fulfilled corruption = grand boon (+5% gold, +3 loot).
Warriors swing 16–20/turn ×1.5; Guardians heal/shield every turn. In a fight, Fortune does nothing.

**Proposal — give LUCK a table presence (new kit entries, Fortune only):**

| Slot | Name | Effect |
|---|---|---|
| Stage-2 trait (new) | **Charmed** | +3% crit chance to ALL your crit rolls while it's active (LCK-scaled) |
| Capstone (new 3rd option) | **Fate's Coin** | Once per combat: the first hit that would kill you leaves you at 1 HP instead |
| Capstone (new 4th option) | **Sharp Eye** | Event stat-checks +10% success; shrine boon prices −15% |

Plus **+2 new capstone options for Warrior and Guardian too** (M: "maybe pets just need more
capstones") — proposals: Warrior "Opportunist" (its strike detonates status reactions like a
player detonator) / "Bloodscent" (+1 strike vs bleeding targets); Guardian "Bodyguard"
(intercept chance 25%→40% but pet takes +25% of it) / "Lifespring" (its heal also cleanses
your newest debuff, 1/combat).

Corruption on Fortune (answered in-game this batch): the +45% multiplies its passive
percentages, and a fulfilled Fortune adds the grand boon on top.

---

## C6. Echo III + flagship aspects — "limited applications"

**Current:** Echo (tier-3-only aspect) = "first AoE each combat applies its **rider** at full
duration" — dead on riderless AoEs, invisible on most casts. Only Quickcast + Echo exist as
tier-3 flagships.

**Proposal:**
- **Echo III rework:** "Your first AoE each combat **echoes — 35% of its damage repeats** at
  the start of your next turn (riders included, full duration)." Works on every AoE, visibly.
- **Two NEW tier-3-only flagship aspects** (Maren craft, recipe unlocked by progression):
  - **Cascade** — "Kills with abilities refund 1 secondary resource (Souls/Blood/Prep)." Unlock: 25 total boss kills.
  - **Bastion** — "Start each combat with 8 shield." Unlock: survive 60 total floors.
- Unlock surfacing: locked recipes show at Maren greyed with their condition (same idiom as
  Vex ability unlocks).

---

## C7. Relationship deepening + corruption onboarding

**Proposal (all comms/UX, no mechanics change):**
- **New tutorial tips** (existing coach-mark system, `tutorial` tips list):
  - `bond_gates` — fires the first time an NPC reaches a gate ("Friendly - a favor would deepen
    it"): explains gate quests, slots, demotion, neglect decay.
  - `corruption_101` — fires on FIRST corrupt egg hatch AND on first identifying a corrupt egg:
    pushing 3 runs → your -20% max HP / -10% dmg while it pushes → +15%/run permanent → cure
    locks gains / fulfilled = grand power, per-type effect named.
- **Compendium:** two new sections — "Companions" (stages, hunger, bond, HP, capstone + splash
  picks, stances, injuries, **corruption table incl. what fulfilled grants per archetype**) and
  "Townsfolk" (affinity, gate quests, betrayal, perks per NPC). Every tutorial tip's content
  must exist in the compendium (M's rule, now also in CLAUDE_SETTINGS.md reference-sync).
- **NPC screen header:** show the active gate quest + progress inline ("Deepen: Give Petra 2
  gifts she likes (1/2)") instead of only on the board/journal.

---

## Approval checklist — ALL APPROVED (M, 2026-07-09)

- [x] C1 behaviors ladder + top-end stat bump
- [x] C2 A5 loot anchors table
- [x] C3 XP mult table [1.0/1.15/1.3/1.5/1.75/2.0] (ladder option, no L8 rung)
- [x] C4 Executioner rework (100% below 30% / slay non-elite <15%)
- [x] C5 Fortune kit additions + 2 extra capstones per archetype (all 7 entries)
- [x] C6 Echo rework (35% echo) + Cascade/Bastion flagships w/ unlock conditions
- [x] C7 tutorials + compendium sections + NPC header
