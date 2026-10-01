# SYSTEMS_POTENCY_V2 — Trait Potency Full Revision

**Status: DESIGN-LOCKED 2026-07-27** (M signed off scope/cost/apex via AskUserQuestion;
Transcend table approved in batch — see §6 decision log).
Replaces the "archaic" v1 potency (5 stat points → +10% on one of 8 numeric traits).

---

## 1. Core model

Every trait — all 26, numeric and on/off alike — has **5 Potency ranks**.

- **Numeric traits** (Thick Skin, Scavenger, Quick Recovery, Arcane Surge, Berserker
  Rage, Serrated Strikes, Vampiric Edge, Focused Power, Chain Caster, Blessed
  Thirst, Lucky Find, Battle Hardened, Pack Rat): ranks 1–4 keep the shipped
  behavior — **+10% magnitude per rank** via `trait_potency_mult` (or the trait's
  bespoke scaling: Pack Rat +5 carry, Battle Hardened +3 cap).
- **On/off traits**: each gains a hand-authored **rank knob** that ranks 1–4 turn
  (see §4 table) — the trait's fantasy deepened, not just a percent.
- **Rank 5 = TRANSCEND**: a bespoke transformation per trait (§4). Constraint
  (M 07-27): Transcends are **build-expression** — combat/utility transformations,
  never economy faucets. Any yield-flavored effect must pass a faucet/drain audit
  first; where a Transcend touches loot it grants **choice, not volume**.

## 2. Costs (tiered mixed — M's pick)

| Rank | Cost | Notes |
|---|---|---|
| 1 | 150g + 5 rune dust | accessible early; gold gets Vex Friend 10% off + CHA |
| 2 | 300g + 10 rune dust | " |
| 3 | 4 permanent stat points (any stats, allocator) | the classic Vex flesh-trade |
| 4 | 5 permanent stat points | " |
| 5 | one Epic+ item (shared sacrifice picker) | the Transcend offering |

Vex **Companion** perk (affinity 3+): stat-point ranks cost 1 less (3 / 4).
Vex **Friend** perk (gold 10% off) applies to gold parts only.

## 3. Migration

`global.trait_potency` keeps its shape (name → tier 0–5). Existing tiers carry
over unchanged — v1 buyers paid MORE per rank (5 points from rank 1), so carrying
tiers is strictly fair; no refunds needed.

## 4. Rank knobs + Transcend table (26 traits)

Format: **Trait — ranks 1–4 knob — T5 "Name": effect.**

### Universal
| Trait | Ranks 1–4 | T5 Transcend |
|---|---|---|
| Sense | +3% event-check success /rank | **Omniscience**: Sense hints on EVERY uncleared room (whole floor at a glance) + treasure rooms reveal their gold (exact-contents reveal was cut - room contents roll on entry, so it would have been a paper effect) |
| Scavenger | +10% magnitude /rank | **Weighted Purse**: +1% damage per 500 gold held (cap +10%) — wealth becomes weight |
| Thick Skin | +10% magnitude /rank | **Stone Hide**: above 80% HP, take −15% damage |
| Quick Recovery | +10% magnitude /rank | **Second Wind**: the first rest each run also grants +5 max HP for the run (statuses don't persist outside combat, so the drafted "cleanse" clause was cut as a paper effect) |
| Treasure Hunter | +5% chance /rank the bonus item rolls a tier higher | **Cartographer's Cut**: the bonus item is a **pick 1 of 2** (choice, not volume) |
| Blessed Thirst | +4% preserve chance /rank (20→36%) | **Bottomless**: the first consumable each combat is always preserved |
| Lucky Find | +10% magnitude /rank | **Fortune's Favor**: once per run, reroll a loot drop from the loot screen |
| Battle Hardened | +3 cap /rank (15→27) | **Unbreakable**: the cap is removed entirely |
| Salvager | r2: keep 3 items on death; r4: keep 4 | **Nothing Wasted**: death also keeps ALL equipped items (Descent-hardcore counterplay — M's callout) |
| Iron Will | later statuses −10% duration /rank | **Unshakable**: the ignored status kind can't be applied to you again that combat |
| Expanded Arsenal | +2% damage /rank to slotted abilities | **Deep Reserves**: first cast of every slotted ability costs −1 AP each combat |
| Prospector | +5% chance /rank the bump is two tiers | **Motherlode**: combat loot can never roll common |
| Last Stand | after it triggers: +10% damage /rank rest of combat | **Deathless**: triggers once per FLOOR, not once per run |
| Focused Power | +10% magnitude /rank | **Annihilating Focus**: the focused strike also applies Exposed |
| Chain Caster | +10% magnitude /rank | **Storm Conductor**: splash hits can crit |
| Plaguebearer | spread duration +12.5% /rank (half→full at r4) | **Patient Zero**: when an afflicted enemy dies, its DoTs jump fresh to a random living enemy |

### Arcanist
| Trait | Ranks 1–4 | T5 Transcend |
|---|---|---|
| Soul Siphon | r2/r4: +1 Soul at combat start | **Harvest**: spell killing blows grant +2 Souls |
| Ley Tap | +3% turn-1 spell damage /rank | **Ley Torrent**: the bonus AP recurs every 3rd turn |
| Arcane Surge | +10% magnitude /rank | **Overchannel**: 3-AP casts refund 1 AP on crit |

### Bloodwarden
| Trait | Ranks 1–4 | T5 Transcend |
|---|---|---|
| Crimson Reserve | r2: start 5 Blood; r4: start 6 | **Overflow**: Blood cap +4; up to 4 Blood carries between combats |
| Vampiric Edge | +10% magnitude /rank | **Exsanguinating Feast**: healing from it doubles below 40% HP |
| Berserker Rage | +10% magnitude /rank | **Blood Frenzy**: threshold rises to below 60% HP |
| Relentless | r2: 1 unspent AP carries over; r4: 2 | **Tireless**: turn 1 of every combat has 5 AP |

### Shadowstrider
| Trait | Ranks 1–4 | T5 Transcend |
|---|---|---|
| Phantom Step | +2% dodge /rank | **Afterimage**: once per combat, a hit that would land instead misses |
| Shadow Meld | those crits +10% crit damage /rank | **One With the Dark**: also triggers when an enemy misses you for ANY reason |
| Serrated Strikes | +10% magnitude /rank | **Flaying Edge**: bleeding enemies take +10% damage from you |

## 5. UI (tab 4 rework)

- Row layout keeps the v1 idiom (icon, name, 5 pips) but the sub-line shows the
  NEXT rank's actual effect ("Rank 3: 4 stat points — +3 kept-item cap") and T5
  rows show the Transcend name + effect.
- Buying r1–2 = direct gold+dust confirm (trainer_confirm bar). r3–4 = the
  existing stat allocator. r5 = the shared item-sacrifice picker (epic+).
- Full input parity (keyboard/pad/touch) — same trainer conventions.
- Reference Sync: `ui_draw_potency_detail` rewritten; compendium entry updated.

## 6. Decision log (2026-07-27)

- Scope ALL traits — M. Tiered mixed costs — M. Transcend yes, with the
  "breaking the game should be fun, not a farm" constraint — M (his wording:
  no exhaustive farm yield without checking endgame faucet drains).
- Faucet audit note: the only loot-adjacent Transcends are Cartographer's Cut
  (choice of 2, not +volume), Motherlode (quality floor, not quantity), and
  Fortune's Favor (1 reroll/run). No gold/dust/XP faucets anywhere in the table.
## 7. BUILD RECORD (2026-07-27, same day — awaiting F5)

Engine: `trait_upgradable_list` now = every unlocked class-legal trait;
`trait_potency_info` (26-entry knob/Transcend table), `trait_potency_rank_cost`,
`trait_potency_r14` (rank knob, 0 unless equipped), `trait_transcended`;
`trait_potency_mult` clamped to 4 ranks. Tab 4: windowed 8 rows, per-rank cost
column, gold-pip Transcend rank; r1-2 gold+dust confirm bar, r3-4 stat allocator
(variable `trainer_statpick_need`), r5 item picker purpose `vex_potency`.
All 26 trait mechanics wired at their real sites (combat controller, scr_combat,
scr_stats, floor controller, loot screen chip for Fortune's Favor [V],
Cartographer's Cut via the shared picker purpose `cartographer` with
cancel-defaults-to-first-find). Run-scoped state reset in `run_state_reset`.
DEVIATIONS (paper-effect vetoes per M's condition): Second Wind's "cleanse"
clause cut (no out-of-combat statuses); Omniscience redefined to whole-floor
hints + treasure gold (room contents roll on entry); Fortune's Favor rerolls
EQUIPMENT rows only (consumables stack by struct — reroll would corrupt pouch
counts); "Nothing Wasted" (Salvager T5) triggers in the Descent hardcore death
handler (equipped items are never lost in the base game today).

- **M's build condition (07-27, batch approval): the effect side must be REAL.**
  Every Transcend ships with its actual in-game affordance in the same batch —
  Fortune's Favor = a working reroll verb on the loot screen (key + touch chip +
  pad), Cartographer's Cut = a working pick-1-of-2 modal, Afterimage = a real
  forced-miss in the hit pipeline. A Transcend whose trigger can't be wired is a
  defect, not a description.
