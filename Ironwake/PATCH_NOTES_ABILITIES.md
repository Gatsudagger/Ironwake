# Ability & Trait Changes — Patch Notes (2026-07-03)

Plain-language summary of everything from the ability audit, approved by M. Full analysis lives in `ABILITY_AUDIT.md`; specs in `INTENT_SPEC.md` / `EXPRESSION_IDEAS.md`.

---

## FIXED — things that were broken

| What | Was | Now |
|---|---|---|
| **Arcane Surge** (trait) | Buffed abilities costing 4+ AP — nothing costs that. It literally never worked. | 3-AP abilities deal +25% damage. |
| **Crimson Reserve** (trait) | "+20 Blood" vs a 10-point bar (a mislabeled full bar). | Start each combat with 4 Blood. |
| **Soulbind** (Arcanist) | **Did nothing.** No combat code existed. | See "reworked" below — fully built. |
| **Undying** (Bloodwarden) | **Did nothing.** No combat code existed. | See "reworked" below — fully built. |
| **Evasive Roll** (Shadowstrider) | **Did nothing.** No combat code existed. | See "reworked" below — fully built. |
| ~9 stale tooltips | Numbers from before the §3 buffs (Arcane Burst "28", etc.). | All match live data. Bonebreaker's DATA was the wrong one — raised 14 → 18. |
| Petra's shop | "v more wares below" on every visit + clicking feed rows misselected (hit-test bug). | Compact rows fit her whole standard stock on one page; clicks land correctly. |

## REWORKED — dead picks given real identities

| Ability | New identity |
|---|---|
| **Soulbind** (2 AP + 1 Soul) | **Lifelink.** The bound enemy takes 40% of every hit you receive, and that stolen vitality heals YOU for the same. Combat-long. |
| **Undying** (3 AP + 3 Blood) | Survive the next lethal blow → **surge back to 25% max HP and gain 3 Blood.** Fires before the Last Stand trait. |
| **Evasive Roll** (0 AP + 2 Prep) | Halve the next hit above 10 damage; **a clean absorb refunds 1 Preparation.** |
| **Strike** (general, 1 AP) | **Momentum:** if Strike kills the target, its AP is refunded. |
| **Second Wind** (general, 2 AP) | Now ALSO cleanses your newest debuff — the game's only self-cleanse. |
| **Spike Trap** (Shadowstrider) | Cost cut 3 AP + 2 Prep → **2 AP + 1 Prep.** The bleed trap; Death Snare stays the stun trap. |
| **Arcane Echo** (Arcanist) | No mechanics change — it secretly ALWAYS splashed 50% of its damage to every other enemy and the tooltip never said so. Tooltip now discloses its mini-AoE identity. |

## ROUND 3 (2026-07-04) — Hexed + trait fixes

| What | Was | Now |
|---|---|---|
| **Curse** (Arcanist, 2 AP) | +4 damage taken — a worse Scorch. | **Hexed** (3 turns): still +4 damage taken per hit, but detonation reactions on the target are **DOUBLED** (Exposed +24, burn +80% crit, root/frost +60% dmg, weaken +30%, bleed +10/tick, void 60% lifesteal, shock arc 66%, Mortality −80% healing) and **each detonation spreads +2 damage-taken (2 turns) to every other enemy** (refreshes, never stacks). New HEX badge, log lines, hit-preview shows "HEXED x2!", Compendium glossary entry. |
| **Lucky Find** (trait) | +5% consumable drop when packs cap at 10 — ~1 extra potion per run. | **20% chance a used consumable is not consumed.** Works in combat and from the character menu. |
| **Shadow Meld** (Shadowstrider trait) | +15 dodge after dodging — fights the dodge diminishing-returns curve. | **After you dodge, your next damaging attack is a guaranteed crit.** Dodge feeds offense now. |
| **Treasure Hunter** (trait) | Guaranteed the room's single 40% item roll. (Verified NOT a no-op — rooms are empty 60% of the time without it.) | **Treasure rooms give one additional guaranteed item** — 1 always, 2 when the normal roll also hits. Popup shows the bonus line. |
| **Maren "Proof of Craft" quest** | Socketing runes never counted — stuck at 0/2. | Both gear and Aspect socketing tick the quest. (Progress isn't retroactive — socket again to count.) |

### Test list (F5)
- **Arcanist:** Curse an enemy carrying burn/frost/Exposed, hit it with Arcane Burst → "Hexed! The reaction is doubled!" + doubled bonus, and other enemies gain "Hex Spread" (+2 dmg-taken, HEX badge on the cursed one, VUL on the others).
- **Any class w/ Lucky Find:** chug potions — roughly 1 in 5 should log "Lucky Find - X is not consumed!" and stay in the pack.
- **Shadowstrider w/ Shadow Meld:** dodge an enemy attack → "guaranteed CRIT" log, next attack crits (yellow popup).
- **Any class w/ Treasure Hunter:** open a treasure room → always at least one item, sometimes two (second shown as "+ Name [Rarity]" line).
- **Maren:** take Proof of Craft, socket 2 runes (unsocket/resocket counts) → 2/2 + tavern-board notice.

## ROUND 4 (2026-07-04) — Enemy Intent system (`INTENT_SPEC.md`)

Every enemy now telegraphs its NEXT action on a chip above its health bar, and the telegraph is **binding** — the enemy does what the chip says:

- **Red "ATK ~12-16"** — basic attack with the approximate damage you'd actually take (post-armor). Telegraph-spike attacks show the big number. "x2" = double-strike foes.
- **Purple "CAST ~12"** — a damaging spell.
- **Green "MEND"** — it will heal itself.
- **Amber effect word** ("STUN", "SILENCE", "WOUND"...) — a control/debuff move.
- **Control payoff:** Stun anything, Root a melee foe, or Silence a caster and its chip **greys out with a strike-through** — that move is cancelled. The foe keeps the same intent for its next turn, so the grey-out reads as "you bought a turn."
- If an enemy's action is spent on a whiff (Blink/Vanish/Shadow Step/Phantom Step), it re-rolls and the new chip **pulses** so the change is visible.
- One-time "Enemy Intent" coach-mark joins the combat tip cascade.

### Test list (F5)
- Enter any combat → every living enemy has a chip above its HP bar from turn one.
- Watch an "ATK ~N-M" enemy attack → the damage you take lands inside (or near) the band.
- Watch a "MEND"/amber chip enemy → it does exactly what it telegraphed.
- Stun/root/silence a foe whose chip applies → chip greys + strike-through, enemy skips, chip un-greys next turn.
- Dodge via Blink/Vanish → that enemy's chip pulses with a fresh intent.
- Click enemy HP bars still selects targets (bar rows moved 30px apart for the chips).

## QUEUED — approved, not yet built

1. ~~Enemy intent system~~ **BUILT (round 4, above).**
2. **Flavor pass** — one lore line per ability (past-lives voice), cast barks for ultimates, a keyword glossary (Sear / Exposed / Mark / Bleed...) in the Compendium.
3. **Expression picks** (`EXPRESSION_IDEAS.md`, in recommended order): school-tinted spell VFX sold by Vael → earned titles/epithets → borrowed-memory run abilities from shrines → pet combat stances → per-ability mastery notches → Knucklebones dice game at the tavern.

## HOW TO TEST THIS ROUND (F5)

- **Bloodwarden:** cast Undying, eat a killing blow → "UNDYING!" surge to 25% HP +3 Blood.
- **Arcanist:** cast Soulbind on an enemy, take hits → reflect + self-heal log lines.
- **Shadowstrider:** cast Evasive Roll, take a heavy hit → halved +1 Prep.
- **Any class:** kill a weak enemy with Strike → "Momentum!" AP refund; Second Wind while poisoned → cleanse line.
- **Petra:** full stock visible, no scroll hint, feed rows clickable.

## #26 ARCANIST MELEE KIT (2026-07-08) — NEW, M-approved design

Three melee SPELLS so a close-range Arcanist build exists. They ride the MELEE
weapon's flat damage (not the wand's), and root/silence rules treat them as melee.
All Vex-purchasable in a new premium tier above the 100/250/400 ladder, offense
category (they feed the same-category AP discount).

| Ability | Cost | What it does |
|---|---|---|
| **Blazing Palm** (Vex 500g) | 1 AP | 12 Fire melee spell. Banks **+1 Soul** on a landed hit. The close-range Soulfire. |
| **Gravewrack Grip** (Vex 800g) | 2 AP | 16 Void melee drain — **always hits, ignores armor**, and **Roots 1 turn** (melee enemies skip; detonators shatter the root for +30%). |
| **Soul Rend** (Vex 1200g) | 3 AP | 30 Arcane melee finisher. **Consumes up to 2 Souls for +8 damage each.** |

**F5 checks:** buy all three at Vex (new 500/800/1200 prices; CHA/Friend discounts
apply) → slot them → in combat: Blazing Palm logs "+1 Soul."; Gravewrack Grip never
misses, the enemy shows Rooted and a melee enemy skips its turn; Soul Rend with 2+
Souls logs "consumes 2 Souls (+16 dmg)" and the hit preview includes the bonus;
while Rooted, a detonator (e.g. Arcane Burst) on that target logs the shatter (+30%).

## AP-COST TRUTH + SOUL CLARITY (2026-07-09 batch)

**The Singularity bug (M 07-09):** the button pips, the "can I cast it" gate and
the actual AP spend each computed the discount stack DIFFERENTLY. The gate knew
synergy + Quickcast; the spend also applied Cracked Focus and Gatewarden's Brand;
the pips showed synergy only. Result: a Singularity that would really cost 1 AP
was refused at 1 AP with "Not enough resources."

| What | Was | Now |
|---|---|---|
| Cost source of truth | 3 divergent computations | `ability_effective_cost` folds in synergy + Quickcast + Cracked Focus + Brand; the pips, the gate and the spend all read it. |
| Cost pips | Discounted count only (a 3-AP spell read as "2 AP ability") | BASE-cost pips always drawn; discount-waived pips are hollow struck-green ("you're not paying these"). |
| Refusal message | "Not enough resources." | Names the gap: "Singularity needs 2 AP - you have 1." / "... needs 3 Souls - you have 2." |
| First-spell charges | Quickcast/Cracked Focus burned even when they saved nothing | Only consumed when they actually lower the cost. |
| **Arcane Surge** | (verified, no change) | Keys off BASE cost ≥3, so a synergy-discounted Singularity still gets +25%. Preview matches. |
| **Soulfire "+4 Souls"** | On-kill class passive logged as "Soul Harvest" — colliding with the ABILITY named Soul Harvest; Void Drain's +1 was silent | Kill line now reads "Arcanist passive: +2 Souls on the kill."; Void Drain logs its +1; new compendium "Class Resources" section documents all three class passives. |
| Crit sources | Unstated whether gear crit was phys-only | Compendium now states: gear "+X% crit" feeds ALL four crit types; only "Spell crit" sources are spell-only. (Bug: Flurry's per-strike rolls dropped Shadow Sickle's bonus — fixed.) |

**F5 checks:** cast two same-category spells with 1 AP left — the second's pips
show struck-green waived pips and it casts if (and only if) the gate says so; kill
with Soulfire → two labeled +2 lines (spell, then Arcanist passive); Void Drain
logs "+1 Soul."; try an unaffordable cast → the log names the missing resource.
DoT kills still do NOT trigger the Arcanist on-kill +2 (pre-existing; flagged as a
design question, not changed).

## BALANCE PROGRAM WAVE 1 (2026-07-09 late) — C1-C7 + D§3 reworks, all M-approved

**Difficulty & reward loop:** Awakening behavior ladder (A2+ +15% enemy ability use, A3+
smart control + mends the worst-hurt ALLY, A4+ +1 elite/floor + debuff diversity, A5 boss
ENRAGE +10%/round past 6) + top-end stat bump (A4 HP x2.20, A5 x2.75/x2.45); steeper A5
loot anchors (legendaries off mobs/elites now exist); **Awakening XP mult [1.0..2.0] — XP
never scaled with tier before; this was the "stuck at level 8" root cause.**

**Pets:** Executioner +100% below 30% + SLAYS non-elite/non-boss under 15%; 7 new kit
entries — Charmed (+3% all crit, LCK-scaled), Fate's Coin (once/combat lethal save at 1 HP,
fires before Last Stand), Sharp Eye (+10% event checks, shrine boons -15% via
shrine_boon_price single-source), Opportunist (pet strike DETONATES a carried status,
+35%), Bloodscent (second strike at half vs bleeding), Bodyguard (Guardian intercepts 40%
in ANY stance, pays +25% — ADAPTED: guardians have no guarded stance), Lifespring (heal
also cleanses, once/combat).

**Aspects:** Echo BLURB fixed (mechanic was already the 50% echo); NEW flagships Cascade
(kills refund 1 resource; unlock 25 boss kills) + Bastion (start combat +8 shield; unlock
20 full clears — ADAPTED from "60 floors" onto the existing counter); locked recipes show
greyed at Maren with their condition.

**D§3 reworks:** Sanguine Pact = Blood->shield dump (3 Blood -> 6 each); Soul Shield +3 per
Soul HELD; Smoke Bomb also cloaks YOU (+15% dodge, SMK chip); Marked for Death = "+30% from
ALL sources below half HP" (universal-sink hook, so pets and DoTs count). **Curse and
Entropy needed NO mechanics change — both had already been reworked in earlier audits and
only stale text/analysis said otherwise.**

**Onboarding:** bond_gates + corruption_101 coach-marks (roster/gate polls); Compendium
gained Companions + Townsfolk sections; NPC bond header now shows the active gate quest's
objective + progress inline.

**F5 checklist:** A5 dungeon-select panel shows XP/loot/behavior lines; kill at A1+ logs
scaled XP; a marked enemy under half HP takes visibly more from a pet strike/DoT; Smoke
Bomb shows SMK chip and enemies whiff more; Sanguine Pact logs the ward; Soul Shield with 4
Souls logs 22 absorb; new capstones appear in the Bairc [G] picker (4 options/archetype);
Maren Forge lists 4 flagships, 2 greyed with conditions; corrupt pet in roster fires the
corruption tip once.

## D§4 GAP-FILLER WAVE (2026-07-09 late) — 7 NEW ABILITIES, M-approved

All Vex-purchasable; icons show a blank badge until the PixelLab round.

| Ability | Class / Cost | Vex | What it does |
|---|---|---|---|
| **Hoarfrost Lance** | Arcanist, 2 AP | 400g | 16 Frost + Chilled 2t (target -30% dmg; detonators SHATTER the chill for +30% — the existing frost reaction). |
| **Glacial Ward** | Arcanist, 1 AP | 250g | 8 shield; melee enemies that land a blow this turn are Chilled. GLW chip. |
| **Static Arc** | Arcanist, 1 AP | 250g | 9 Shock, chains 50% of dealt damage to one other enemy — to ALL others if the target was already Shocked. |
| **Soul Engine** | Arcanist, 2 AP | 500g | Once/combat, combat-long: spells +3 per full turn elapsed. ENG chip shows the live bonus; hit preview includes it. |
| **Galvanize** | Bloodwarden, 2 AP | 400g | Melee spell, 12 Shock; a killing blow banks +1 AP next turn. |
| **Winter's Bite** | Shadowstrider, 1 AP + 1 Prep | 250g | Melee spell, 9 Frost; vs a CHILLED target +9 and the Prep refunds. |
| **Devil's Flip** | General, 1 AP | 100g | Coin flip: heads = selected target takes 26 (phys-mitigated); tails = YOU take 8 (lethal gate applies). EV = Strike. |

Frost/shock ride the EXISTING status plumbing (Chilled = frost-element weaken, shatter =
the frost detonation; Shocked = the weapon-affix shock status). Winter's Bite + Galvanize
are melee SPELLS (Blazing Palm precedent: root-blocked, silence-blocked, melee weapon flat
damage rides along).

**F5 checks:** buy all 7 at Vex (prices above); Hoarfrost then Arcane Burst logs the
shatter; Glacial Ward chip + a melee attacker logs "Chilled by the Glacial Ward"; Static
Arc into a shock-affix-statused target chains to everyone; Soul Engine on turn 1, then a
turn-4 Soulfire previews and deals +9 more; Galvanize kill → next turn shows 4 AP; Winter's
Bite on a chilled foe logs +9 and the Prep back; Devil's Flip logs HEADS or TAILS and the
right victim. New abilities show blank icon badges (PixelLab round queued).

## COMBAT COMBO BATCH (2026-07-16) — M-approved numbers, COMBAT_COMBO_PLAN_2026-07-16.md

Budget yardstick: 1 AP ~ 12-14 pts; DoT ~0.75x face; stun ~14-16, weaken ~8, Exposed ~4/hit.

**Detonator parity + cascade:**
| Change | Budget math | Wrong fight |
|---|---|---|
| **Rupture** = true detonator (bespoke detonate-ALL-DoTs rider DELETED; shared bleed reaction is the same +5/tick, consumed) | vs bleed: unchanged. NEW: shatters chill, crits vs stun, drinks void, Hexed-doubled — BW finally reaches the reaction table | No statuses on the target |
| **Bonebreaker** = detonator #2 (stats unchanged) | 3 AP: 18 + Exposed 5x3t ~ on budget; detonation is the read | Clean targets |
| **Rift** = the CASCADE: detonates EVERY enemy it hits, each individually (per-target reaction incl. Hexed x2) | Gated by 3 AP + 2 Souls + multi-turn setup | A lone clean boss (Singularity wins) |

**New ramps (Vex 500g each, once/combat, combat-long, support):**
| Ability | Effect | Budget | Wrong fight |
|---|---|---|---|
| **Warpath** (BW, 2 AP) | Physical/Blood abilities +2 per full turn elapsed | Soul Engine mirror at +2 (BW swings more/turn) | 2-turn trash |
| **Compounding Dread** (SS, 2 AP) | Each trap cast after lighting it: permanent +4 trap damage this combat | Trap-build boss scaling | Trapless kits / short fights |

**Reworks:**
| Ability | Change | Budget | Wrong fight |
|---|---|---|---|
| **Frost Shot** (was Crippling Shot; save-migrated: loadout/unlocks/mastery/casts) | 10 phys + Weaken 25%/3t + NEW Chill 1t (Hoarfrost-shape status; weaken layer = max, no stack) | 10+8+6 = 24 on a 2-AP slot | Low-threat trash |
| **Entropy** | Accelerating DoT 6/8/10/12 (36 total; `accel` field, both tickers honor it). Double-on-void-reapply kept | ~26 effective, heavily back-loaded | Anything dying in 2 turns |
| **Devil's Flip** | Win streak: +8 payout per consecutive win THIS combat; tails deals 8 to YOU and resets | EV at streak 0 unchanged (13) | Fights where eating 8 kills you |

**Global rules (CORE):**
- **OVERWHELM**: enemy with 2+ DISTINCT status kinds (dots split by element) takes +15% from ALL sources (combat_apply_damage, next to Marked). Gold OVW+ badge, hover-explained, Compendium entry.
- **OVERCHARGE**: spender cast at FULL reserve drains it all — +2 damage per excess point (post-crit flat, once per cast, after Nova/Rend's own rates), +2 heal on Blood Surge-style self heals, Pact seals ALL Blood (first 3 at 6/pt, rest at 2/pt). Reserve-HELD scalers (Soul Shield, Arcane Echo) excluded. Full bar glows gold + eligible buttons pulse; whiffed cast keeps the reserve.

**Combo juice/legibility (presentation only):**
- Detonating hits resolve as a SEQUENCE: damage number → reaction splash ("SHATTER!", "BLOOD BURST!"…) → "HEXED x2!" → each on a rising snd_loot_reveal tick (pitch 1.12/1.28/1.4 for OVERCHARGE). Popups carry text/sfx/pitch/delay.
- The status badge your SELECTED ability would detonate PULSES on the enemy row; hit preview already names the bonus (auto-covers the new detonators).
- Borrowed Memories = pick-1-of-3 DRAFT: the event offer opens a second choice screen (same event UI, synthetic event `borrowed_pick`, new fx key `memory_pick`).

**F5 checks:** Gore Strike → Rupture logs BLOOD BURST + no leftover bleed; Hoarfrost → Rupture shatters (BW!); Rift into 3 statused enemies logs 3 separate reactions; Frost Shot then Snipe logs SHATTER; Entropy ticks 6/8/10/12 on a dummy; Flip twice-heads logs streak 2 and +8; Warpath turn-4 Gore Strike previews +6; Dread + 2 Spike Traps: second logs +4; fill Souls to 10 → bar glows FULL, Soul Nova button pulses, cast logs OVERCHARGE +12 (4 at 7, 6 at 2); Blood Surge at 10 Blood heals 14+16; enemy with bleed+chill shows OVW+ badge and takes +15%; Stranger's Memory event → result closes into a 3-memory pick screen; old save with Crippling Shot equipped loads as Frost Shot.

## F5 NOTES BATCH (2026-07-16 late) — M's 9 notes from the combo-batch F5

**Audio:**
- **Crickets** (`snd_amb_title`) no longer play under the title/intro music — moved to the
  character-creation screen, the one place that's otherwise silent (obj_title_controller /
  obj_char_select Create).
- **Sable's cauldron** (`snd_amb_cauldron`) REPLACED in place — v1 read as a toilet; v2 is a
  thick viscous porridge-simmer, no watery glugs. Same asset name, wiring untouched.
- **Egg hatch = Zelda chest**: tremble stretched 50→110 frames; new `snd_hatch_build` (2.5s
  rising harp/celesta swell) starts at the first wobble and crests INTO the shell-break,
  where the new `snd_hatch_fanfare` (bright resolving flourish) lands on top of the old
  burst+foley. Both in audio_sfx_assets().

**Bloodwarden lackluster (M: "too many 3 AP abilities"):**
- NEW TRAIT **Relentless** (BW-only, tier 3 = 500g + Legendary at Vex, unlock 6 boss kills):
  base AP 3 → 4 EVERY turn. Single source of truth `actor_turn_ap()` — turn refill, first
  turn, and the HUD pips all read it. Enemies unaffected.
- **AP audit** (M-approved): **Undying 3→2 AP**, **Bloodfeast 3→2 AP** — the two whole-turn
  utility casts; Marrow Crush / Bonebreaker / Crimson Apex deliberately stay 3.
- **Vex trait slots**: purchasable cap +2 → **+4** (6 equipped max, 7 with Crown). Price
  ladder 800/2000/4000/8000g. Tab text + compendium + coach-mark synced.
- **BUGFIX found during wiring**: Ley Tap did `player.AP += 1` but the combat struct's field
  is `energy` — equipping Ley Tap crashed at combat start. Now `player.energy += 1`.

**Pets/UI:**
- **Baby moth size**: combat pet draw now passes a width cap (1.35× the stage height) to
  pet_sprite_fit — height-only fit blew the wide caterpillar up to knight size.
- **Corrupt-egg notice** (and all hub NPC-panel notifications) now WRAP inside the detail
  panel (small font, measured to end above the y330 panel bottom) instead of running off-screen.
- **Maren Spirits ledger**: lists ONLY freed songs — no "???" rows, no x/total count; a
  veiled "...more spirits still wander the dark." when any remain. (NOTE: F8 makes every
  song read as owned — toggle it OFF to see the mystery view.)

**Awaiting M approval (in _for_review\):**
- `music_samples\` — 6 × 30s track auditions (~405 credits each): dungeon Ashfall /
  Hoarfrost / The Iron Deep, hub Hearthlight / Moth & Lantern / The Wake. Approved concepts
  get full-length versions + catalog wiring (Maren release + Settings selectors).
- Dust Egg redesign candidates + Relentless trait icon candidates (PixelLab, M picks).
  Until the icon lands, Relentless shows the slate fallback badge.

**F5 checks:** title screen = music only, char create = crickets only; Sable's tab bubbles
properly; hatch an egg — longer tremble, build swells, fanfare lands ON the crack; Vex trait
tab sells slots 3/4/5/6 at 800/2000/4000/8000 and Relentless for 500g+Legendary (BW);
Relentless run: 4 yellow pips every turn, Marrow Crush + Blood Leech same turn works;
Undying/Bloodfeast buttons show 2 AP; equip Ley Tap on an Arcanist — combat STARTS (was a
crash) with 4 AP turn 1; baby moth in combat is house-cat sized; trigger a curse-altar egg →
hub notice wraps inside the panel; Maren Spirits with F8 OFF shows only freed songs.
