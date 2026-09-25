# DESIGN — Ironwake Improvement Plan (2026-09-24)

**Status:** DESIGN-LOCKED by M 2026-09-24 (all §8 questions answered; decisions recorded in
§8 and folded into the sections). Build starts with P0 the same day. Every section names what
exists today (verified in code 09-24), what is missing, the mechanic, the numbers, the data
shape, the files it touches, art cost, mobile parity, save impact, and a size estimate.

**Constraints locked with M 09-24:** inline research · build-ready specs · keep art
generation low (anything needing PixelLab is flagged `ART`) · full touch parity on every
feature · think big, cut later · save-format changes are acceptable when the upgrade is worth
it, but every proposal below is written to be **additive** (new fields default on load, no
`SAVE_FORMAT_VERSION` bump) unless marked `SAVE-BREAK`.

**Sizing key:** `S` = small (part of a session) · `M` = one session · `L` = two to three
sessions · `XL` = a multi-session system. One session ≈ 150-250k tokens.

---

## 0. Baseline snapshot (so nothing below is a re-proposal)

| Area | Exists today (verified 09-24) |
|---|---|
| **Pets** | 76 species (50 with adult art), 3 archetypes (Fortune / Warrior / Guardian), 5 stages, 3 stats **PWR / SPR / LCK** (base 3/1, +1 per stage, uid-hashed 0-2 talent, Devoted +1, signature +awk/2; `PET_STAT_COEFF 0.03` so a point is ~3%), bond tiers 4/10/18, hunger 0-100 with fed/hungry/starving gates, 8 treats with favored families, preferred feed per species, 21-entry kit (traits + Stage-3 capstones + Awakened splash), species innates + sig moves, quirks, stances (Gate-set), corruption push/cure, injury ladder + permadeath, stable cap 8 (+1 Bairc Friend), donation → garden residents, walkable garden + hut interior + keepsake shelf + peddler's cart. **LCK is consumed by exactly two things: gold find and loot find.** Non-active pets do nothing but eat. |
| **Combat** | 3 AP, initiative, enemy intents (binding telegraphs), timed parry rings T1 + T2 strike windows (On/Assist/Off), Poise (unspent AP → shield), Interrupt, 8 element schools + per-enemy weaknesses + Exposed Weakness detonation, typed statuses, boss phases, enemy summons, Depth Wardens, duelist, 2.5D two-plane stage with station layouts, pet turns/stances/betrayal, ability mastery notches + run honing, VFX gigapack. |
| **Character** | 3 classes (Arcanist / Bloodwarden / Shadowstrider), 7 origins, gender axis, 60 portraits (3 free per class+gender, rest at Vael), 26 Vael skins, epithets, talent webs (7-node wishbone) + class trunks, runes (gear sockets) + aspect slots, 8 gear slots, affixes incl. typed crit, Iron Vow hardcore modes, permanent level + run level, Awakening A0-A5. |
| **Hub / UX** | 7-NPC carousel, station ranks (11 perks), affinity tiers + gates + Lover question, tavern board (8 templates), journal (7 tabs), character menu (5 tabs), stash (3 categories), settings (music/SFX/font size/timed combat), 7 first-open NPC tours, coach-marks, hub notices concatenated into one string (`pet_find_notice`). |
| **Content** | 7 dungeon keys (Ashen Vault, Scorched Depths, Tundra Tomb, Drowned Reach, Hollow Canopy, Stormcrag, The Descent), 83 enemy entries, biome active mechanics (Tide, Climb…), 18 boons, 10 curses, events catalog, 4 reagents + valuables, 63 achievements wired, run seeds. |
| **Parked (roadmap / backlog, not built)** | Cursed items · pet divergent growth · cloak slot · crit split P2 · quest/board rework · knucklebones (stubbed) · borrowed memories (stubbed) · hardcore achievement set · enemy AoE/buffs · rune set bonuses · boon rarities · shop buy-back. |

---

## 1. PETS — "Bairc's Ledger": expeditions for the whole roster  `XL`  ⭐ headline

### 1.1 The problem
Seven of eight stabled pets are dead weight: they cannot grow (runs-only), cannot bond
(active-only), and their three stats do nothing (LCK is two percentages, PWR/SPR are a 3%
multiplier on a single strike or ward). Raising a roster has no payoff beyond the garden
wallpaper. Monster Hunter's Meowcenaries / Tailraiders, Dragon Age Inquisition's war table,
and Assassin's Creed Brotherhood's recruit missions all solved exactly this: **send the
bench out, get things back, level the bench.**

### 1.2 The fantasy
Bairc keeps a ledger at his desk in the hut (the desk interactable already exists,
`garden:desk`). You pick a job from the ledger, pick one to three stabled creatures, and they
leave through the garden gate. They are gone for one to three **runs** (runs are the game's
clock; nothing is real-time). When you come back from a dive, Bairc has written what
happened: what they brought back, who got hurt, who found something they should not have.

### 1.3 Jobs (mission types)
Six kinds. Each is governed by one pet stat, prefers a habitat (derived from the treat
`favored` families that already exist, zero new data), and pays in a distinct currency so
players learn "PWR jobs bring reagents, LCK jobs bring gold and eggs".

| Kind | Governing stat | Duration (runs) | Pays | Fail risk |
|---|---|---|---|---|
| **Hunt** | PWR | 1 | dungeon reagents (2-5), valuables, 1 feed | injury tier 1 (25%) |
| **Vigil** | SPR | 1 | rune dust 15-40, 1 Warding/Vital egg-type feed, reduces one party member's corruption by 1 push if pushing | none (a Vigil never injures) |
| **Scavenge** | LCK | 1 | gold 60-220 × Awakening, valuables, **2% egg** (source `egg_ledger`) | nothing back (no injury) |
| **Long Forage** | mixed | 2 | **growth for every party member** (see 1.6), preferred-feed discovery for one species | hunger drain doubled for party |
| **Rescue** | PWR + SPR | 2 | a **found creature** (Stage 1-2, source `found_ledger`), or nothing | injury tier 1-2 (35%) |
| **Patrol** (always available) | any | 1 | 1 treat, +1 bond each | none |
| **Expedition** (M 09-24) | all three | 3 | tier-3 payout of Hunt + Scavenge combined, **5% egg**, 1 valuable guaranteed, growth 3/run away | injury tier 1-2 (30%); one offer at a time, never at tier 1 |

Special offers (one at a time, seeded): **NPC errands** hook the existing NPC drip —
"Petra needs eight Brine Jerky's worth of eel" (Scavenge, wet-born favored, pays affinity
+3 with Petra + gold); "Dorn wants Cinder Marrow" (Hunt, Scorched). Reuse
`board_build_template` flavor style; these are ledger rows, not board rows.

### 1.4 Offers, dispatch, resolution
- **Offers:** 3 rotating per run (seeded by `run_count` like `garden_shop_stock`) + 1 NPC
  errand at 40% + Patrol always. Kinds weighted 30/15/25/15/10/5 (Hunt/Vigil/Scavenge/
  Forage/Rescue/errand). Each offer carries a `dungeon` key (habitat) and a **tier** 1-3
  (tier = min(3, 1 + Awakening div 2)); tier scales requirement and payout.
- **Party:** 1-3 pets. Ineligible: the active companion, eggs, injured tier 2+, starving,
  already away, corruption `pushing` on Rescue. **Max 2 parties out at once** (a third slot
  unlocks at Bairc rank 2 — a new rank perk, replaces nothing).
- **Score:** `score = Σ party stat(kind's stat) + Σ (stage div 2)`; requirement
  `req = 4 × tier + 2 × (party size − 1)`. Base chance
  `p = clamp(0.35 + 0.08 × (score − req), 0.10, 0.92)`, then **+12% per habitat-matched
  species (max +24%)**, +5% per Devoted+ bond, −20% if any member is hungry, +LCK crit:
  `great = 0.04 + 0.02 × Σ LCK` (cap 0.30).
- **Deterministic roll:** the outcome is rolled at dispatch with `seed = run_seed ^ mission
  uid` and stored; it is only *revealed* at resolution. No save-scum reroll.
- **Resolution:** in `end_run` (any result — a death still brings the party home; they were
  not with you). Each active mission with `due_run <= run_count` resolves: FAIL / PARTIAL
  (p < roll < p + 0.15: half payout, no injury) / SUCCESS / GREAT (payout ×2 and one extra
  roll on the kind's rare table).
- **The report:** on the next hub load, the garden's Bairc dialogue idiom
  (`ui_draw_bairc_dialogue`) shows the ledger page: one line per mission in his voice, sparse
  ("Frostmarten. Cinder Marrow, three. It would not eat for a day after."). Rewards land in
  stash / reagent pouch / feed pouch as they would from a run. This also becomes the home of
  the **hub Inbox** (§4.1) — the two ship together.

### 1.5 Away state
- Pet struct gains `away_until` (run index, 0 = home) and `away_kind`. Additive.
- Away pets: hidden from the Gate Companion tab, from Bairc's feed list (they eat from the
  mission: hunger −10 per run away, Forage −20), and from the garden — **they are seen
  leaving**: at dispatch, `garden_pets_follow`-style walk to the gate (x 1394 sill or the
  plate's right edge) then `room = "away"`. On return they re-enter from the same edge on the
  next garden visit. Zero art: reuses walk steering + the door.
- Donated residents (garden pets) are **not** the roster; they cannot be sent. Keep the two
  ledgers separate — donation stays final.

### 1.6 What it fixes in the stat model
- **LCK** finally has a job: Scavenge chance, GREAT rolls, egg odds. **PWR/SPR** decide
  Hunt/Vigil. Raise `PET_STAT_COEFF` to 0.05 at the same time (combat value ~5%/pt) so a
  stat point reads on both boards.
- **Growth for the bench:** Long Forage banks `growth += 3 per run away` (an active clear
  banks 2 + feed; keep Forage strictly below active play + feed). It never crosses a stage —
  "feed fills the bar, runs unlock the gate" is preserved; a Forage-full pet still needs one
  active run to evolve. Bond +1 per mission for every member (active bonding is 2-3/run;
  the bench bonds slower, as designed).
- **Signature pets** get +1 score on Hunt (they are boss-blooded). Awakened pets count
  stage 4 → +2.

### 1.7 Callings — divergent growth with RNG (parked item #3, folded in)  `M`
At the Young Adult crossing, Bairc offers **two Callings drawn from four** (the RNG gate M
asked for) and the player picks one; found creatures roll one. A Calling is a permanent tag:
+2 to one stat and one expedition perk that also reads in combat, so it is not a
mission-only stat.

| Calling | Stat | Expedition perk | Combat echo |
|---|---|---|---|
| Trailblazer | PWR +2 | party missions resolve 1 run sooner (min 1) | acts first among companions |
| Packmule | LCK +2 | +1 payout roll | +1 consumable drop on kill (5%) |
| Sentinel | SPR +2 | party cannot be injured on FAIL | intercept chance +10% (Guarded) |
| Nightwise | LCK +2 | night habitats (Canopy, Vault) always count as matched | +3% crit to you at night themes |
| Ironhide | SPR +2 | takes the injury instead of a partner | −15% damage taken by pet |
| Bloodnose | PWR +2 | Hunt payouts +1 reagent | +20% damage vs Bleeding |

Pool: 6 (v1), offer 2. Field `calling` on the pet, additive. Shown as a pill beside stage.

### 1.8 Ledger UI (keyboard / pad / touch)
- **Entry:** the hut desk (`garden:desk`) opens **THE LEDGER**; Bairc outside keeps opening the
  station. Also a `[L] Ledger` key on the Bairc station legend and a corner chip.
- **Layout:** left column = offers (rows 88px, tap = select, second tap = open), right pane =
  the offer: kind, habitat crest (dungeon card art, exists), governing stat, tier, duration,
  payout line, **success meter** (live, recomputed as you toggle party members), then a
  3-slot party strip. Below: roster rows (portrait, name, stat trio with the governing one
  highlighted, habitat match ✓, hunger pip); tap toggles. `[Enter] SEND` is a 150px button
  bottom-right (thumb zone). Away parties list on a second tab `OUT` with return run.
- **Mobile:** every row ≥ 88px, gaps ≥ 30px, primary button bottom-right per
  MOBILE_UI_PATTERNS; the success meter replaces any hover tooltip.
- **Touch parity check:** all hit-tests in Draw (project rule), `input_inject` tags
  `ledger:offerN / ledger:petN / ledger:send / ledger:tab`.

### 1.9 Data, save, files
```
global.pet_ledger = {
  offers:      [ { id, kind, dungeon, tier, dur, req, pays:[...], npc:"" } ],   // 3-5
  offers_run:  0,                                                             // rebuild when != run_count
  active:      [ { uid, kind, dungeon, tier, party:[pet uids], sent_run, due_run,
                   seed, outcome:"", payout:[...] } ],
  log:         [ last 12 ledger lines ],
  parties_max: 2
}
pet: away_until (int), away_kind (string), calling (string)      // all additive, default 0/""
```
- Save: the 3 scr_save sites (slot, checkpoint ignore, load defaults). No version bump.
- Files: `scr_stats` (ledger catalog/roll/resolve, ~500 lines), `scr_ui` (ledger screen +
  Bairc report page, ~600), `obj_game_controller Step` (input block + garden verb), `scr_save`,
  `end_run` hook, garden draw (leave/return walk).
- **ART:** none required. Optional: one 64px "ledger" icon for the chip; a 4-frame gate
  swing is nice-to-have, not needed (pets walk off the plate edge).

### 1.10 Also in this batch (small, high-charm)
- **Garden chores** `S`: residents inside the hut sometimes carry an item to the shelf; a
  resident napping by the hearth grants +5 hunger to the active pet on garden exit. Zero art.
- **Pet report card** in the Companion tab `S`: missions completed, GREAT count, favorite
  habitat, last injury. Reads the ledger log.

---

## 2. COMBAT — more decisions per turn, more reasons to look at the board

Everything below reuses existing hooks (intents, 2.5D planes, schools/weaknesses, timed
rings, VFX gigapack). No new sprites unless flagged.

### 2.1 Cover: front / back line on the enemy planes  `M`
The two-plane stage already places enemies on front and back planes (`stage_layout`).
Make it mean something:
- A back-plane enemy is **COVERED** while any front-plane enemy stands. Melee abilities
  cannot target it; ranged abilities can at −10 accuracy; spells ignore cover; AoE hits both.
- Enemies choose planes by role (casters/summoners back, brutes front). Two new verbs on
  existing abilities via a `reach:"pull"` rider: Bear Trap and Shadowstrider's Hook line pull
  a covered target forward (it swaps with a front enemy).
- Intent chips gain a small "COVERED" tag; the nameplate row order already mirrors the planes.
- Files: `obj_combat_controller` Step (target legality + enemy plane pick), Draw (tag),
  `scr_enemies` (role → plane), `scr_abilities` (pull rider on 2-3 abilities). Save: none.
- Why: it turns "which enemy" into a real question and gives control/ranged builds a job
  every fight, which the encounter-mix audit (COMBAT_IMPROVEMENT_PLAN §D) asked for.

### 2.2 Break bar (stagger) on elites and bosses  `M`
Monster Hunter part-break for a turn-based game:
- Elites/bosses carry `guard = 25% of max HP`. Hits in the enemy's **weakness school**
  (exists) chip guard ×2, other hits ×1, DoTs ×0.5. At 0 → **STAGGERED**: loses its next turn,
  takes +30% damage, its intent chip breaks, and a **T2 strike ring** opens on it for a
  free finisher press (PERFECT = +50% on your next hit). Guard refills to 60% after the
  stagger turn.
- Draw: a thin amber bar under the HP bar, cracks at 50%/0. Reuse ring drawing.
- Files: `scr_enemies` (guard field on elite/boss clone), `obj_combat_controller` Step (chip
  on damage, stagger state in the turn loop, intent clear), Draw (bar). Save: none.

### 2.3 Companion commands (live pet tactics)  `S/M`
Stances are set at the Gate and forgotten. Add **one free command per player turn** (0 AP,
a 4th button on the ability bar, hotkey C / pad Y / a 130px touch button):
- **Sic** — pet strikes YOUR current target this turn, adds 1 Exposed stack if the hit lands
  (Warrior; Guardian/Fortune pets do a 50% strike).
- **Heel** — pet intercepts the next enemy attack on you (Bodyguard math, once).
- **Fetch** — LCK check (`0.25 + 0.05 × LCK`): steals 10-30g or a consumable from the
  target's "pockets" (a per-enemy drop preview); fail = nothing. Fortune pets +15%.
- Cooldown: a command used sets a 2-turn CD on that command only. Injured/benched pets show
  the button greyed with the reason.
- Files: `scr_combat` (`combat_pet_command`), Step (input + resolution before the pet's own
  turn), Draw (button + CD pips). Uses `pet_stance` as the default when no command given.

### 2.4 Momentum and class Finishers  `M`
The "ult meter" the 07-17 plan deferred, built so it rewards *variety*:
- **Momentum** 0-100, combat-scoped. +15 per ability whose category differs from the last
  one used this turn (Attack → Spell → Control = 45), +10 per PERFECT parry, +20 per
  Interrupt, +10 per stagger. Decays 20 at the start of your turn. Reading: a thin bar over
  the AP pips.
- **P2 payoff (M 09-24):** at 100 the meter empties for **+1 AP** (surplus pip, orange like
  AP items). **P3 payoff:** one **Finisher per Oath** (six, §3.1) replaces the +1 AP; at 100
  the Finisher replaces the basic attack button for one use (0 AP). Class drafts to split per
  Oath in P3:
  - Arcanist **Cataclysm** — 3 school hits of your three most-used schools this combat, 1.6×
    spell damage split across all enemies, applies Exposed. (Ashen Scholar) / **Collapse** —
    every summon detonates now at 150% (Voidbinder).
  - Bloodwarden **Exsanguinate** — consume all Blood: 8 + 6 per Blood physical, heal 50% of
    damage dealt, target Bleeds 3. (Crimson Vow) / **Sepulchre** — your shield becomes a
    3-turn thorn wall at 40% (Gravewarden).
  - Shadowstrider **Deathmark** — mark one target: your next 3 hits crit; if it dies while
    marked, refund 2 AP. (Knifewind) / **Afterimage Storm** — dodge the next 2 attacks and
    counter each for 14 (Hollow Step).
- Zero art: reuse the biggest gigapack burst per school and a full-screen desaturate flash.
- Files: `scr_abilities` (3 finisher defs), Step (meter + button swap), Draw (bar).

### 2.5 Elite affixes  `S`
Diablo-style suffixes on elites (and bosses at A3+), 1 at A0-2, 2 at A3+, from the mechanics
that already exist: **Warded** (fortify), **Hasted** (double_strike 50%), **Thorned**
(retribution), **Vampiric** (regen on hit), **Twinned** (a summon clone at 50% HP),
**Shrouded** (starts covered, 2.1). Shown on the nameplate ("Ash Revenant, Thorned") and in
the Bestiary as a seen list; +1 loot tier roll per affix. Files: `scr_enemies` (affix table +
apply in clone), Draw (label), `handle_enemy_drops`.

### 2.6 Battlefield objects per biome  `M` + `ART (5 small props)`
One targetable prop per biome on the front plane, 1 AP to use, once per fight:
Vault **brazier** (Blind all enemies 1t), Scorched **vent** (Fire DoT on the front line),
Tundra **icicle** (Root a target), Drowned uses the **wheel** that exists (Tide), Canopy
**vine** (pull a covered enemy). Enemies can also use them on a low-chance intent ("Kicks
the brazier"). Art: 5 props at plane scale (~10 gens). Skip the art and this is `S` with
text-only props; not recommended.

### 2.7 Smaller combat items
- **Coup de grâce ring** `S`: when a hit will kill, a T2 ring opens; PERFECT = the kill
  drops +1 rarity tier once per fight. Uses existing strike windows.
- **Auto-resolve trash** `S`: from Awakening ≥ 2, fights where every enemy is ≥ 6 levels
  below the run level offer `[X] Overwhelm` — resolves at full loot, no XP, costs 10% HP.
  Respects timed-combat OFF. Mobile: a bottom-left button.
- **Enemy buffs to allies** (backlog): a "Warcry" intent kind for pack leaders (+15% dmg to
  allies 2t) — gives Silence a target in packs. `S`.

---

## 3. CHARACTER — deeper customization that is legible on the sheet

### 3.1 Oaths (a subclass pick at permanent level 5)  `L`
Two Oaths per class, chosen once at Vex (a swap costs 400g + 40 dust; rare). An Oath is a
resource twist + one signature passive + one replaced trunk row; it does **not** add
abilities, so ability balance holds.

| Class | Oath | Twist |
|---|---|---|
| Arcanist | **Ashen Scholar** | spells of the same school back-to-back cost −1 AP (min 1), but Momentum gains halved |
| Arcanist | **Voidbinder** | summons last +1 turn and detonate on expiry; you lose 2 max HP per active summon |
| Bloodwarden | **Crimson Vow** | Blood cap 10 → 14; below 30% HP all Blood spends are free once per turn |
| Bloodwarden | **Gravewarden** | Poise doubles; you cannot crit, but shields you hold at turn end deal 25% as thorns |
| Shadowstrider | **Knifewind** | first ability each turn from stealth/dodge is a guaranteed crit; max AP 3 → 2 with +1 refund per kill |
| Shadowstrider | **Hollow Step** | dodge kit gains a free counter (Counterblade math); dodges cost 1 Momentum each |

Data: `global.player_oath` (string, additive). Files: `scr_abilities` (cost/crit hooks),
Step, trunks table, Vex screen row, stats tab line. Save additive.

### 3.2 The Heirloom (a persistent personal relic) and Cursed Items  `L`
Answers the parked cloak-slot and cursed-items items without a 9th gear family:
- One **Heirloom** slot on the sheet (not gear; no drop family). The origin picks its
  starting heirloom (merchant's scale, forester's charm, …, 7 items, text + the existing
  origin-gift icons). It **levels by deeds** (clears, boss kills, GREAT expeditions), 5 ranks,
  each rank adding one small stat or rider.
- **Cursing** an heirloom or a legendary at Sable's cauldron (the Cursed Rebirth tab exists):
  the item is renamed with the existing curse suffix table, gets one drawback + one upside
  from a 12-entry cursed-affix pool ("of the Hollowed: −6 INT, spells that kill refund 1
  AP"), and becomes **unique** (one per save). This is parked item #1 in a form that ships on
  existing UI.
- Save: `global.heirloom {id, rank, deeds, cursed_affix}` additive; legendaries already carry
  affix arrays.

### 3.3 Skin tints (palette shader) at Vael  `M`  · zero art
A palette-swap shader (`shd_palette`, 8 ramp entries) applied to the combat skin: Vael sells
**dye sets** (ember, verdigris, bone, void, tide, gilt; 80-150g). Tints also apply to the
garden walker and the hub sprite. This is the cosmetic gold sink Vael's shop lacks late-game
and the tint idea from EXPRESSION_IDEAS #4 done on sprites instead of VFX. Files: one
shader, `player_combat_sprite` draw sites (3), Vael tab. Save: `player_tint` string.

### 3.4 Scars (death-earned permanent tradeoffs)  `M`
On a death, choose **one of three Scars** (or none): a small permanent tradeoff ("Limp: −1
initiative, +6 max HP"; "Singed: fire resist +10%, frost resist −10%"; "Hollow Eye: +4 crit,
−4 accuracy"). Max 3 held; Sable removes one for 150 dust. It makes dying produce a
*choice* instead of only a loss, and it is the meta layer roguelites use to make runs
accumulate identity (Hades' keepsakes, Darkest Dungeon's quirks). Pool of 15. Save:
`player_scars[]` additive.

### 3.5 Loadout presets  `S`
Three named presets on the Gate screen (abilities + traits + aspect runes + companion +
stance). `[1-3]` keys, tap chips. Save additive.

### 3.6 Heraldry  `S`
A procedural crest (two-tone shield, one of 24 charges drawn as vector shapes, colors from
the origin) shown on the run-summary and the character sheet. Zero art. Ties into §4.2.

---

## 4. UX / UI remodels

### 4.1 The Hub Inbox (replaces the concatenated notice string)  `M`
`pet_find_notice` is a single string that grows by concatenation and is shown once. Replace
with a **notice queue**: `global.hub_inbox = [ {kind, title, body, icon, run, read} ]` fed by
pet evolutions, bond milestones, ledger reports (§1.4), board completions, NPC gate
readiness, keepsakes earned. Surfaces as a corner bell chip with a count; opens a scrollable
list (visible bar) with mark-read. Mobile: rows 88px. Save: keep last 30, additive.

### 4.2 Run summary screen  `M`
After any run end (before the hub): one screen — result, floors, kills, damage dealt/taken,
gold banked vs lost, loot highlights, pet report (bond/growth gained, injuries), missions
returned, achievements, epithet earned, and the heraldry crest. Right now this information is
scattered across toasts. `[Enter]` continues. Reads state the end_run site already has.

### 4.3 Floor map route preview  `S`
On node hover/tap-hold, highlight every node still reachable from it (the DAG is known) and
show the count of rooms of each kind ahead. Turns the map into a plan.

### 4.4 Combat readability
- **Enemy panel on tap-hold / [V]** already exists for abilities; add the same for enemies:
  weakness school, affixes (§2.5), guard (§2.2), intent history (last 3). `S`
- **Ability bar: hold-to-preview** on touch shows the tooltip without committing. `S`
- **Bottom-docked End Turn** on touch (MOBILE_UI_PATTERNS thumb map): move the End Turn strip
  to bottom-right, 150px, and the consumables button bottom-left. `S`
- **Turn order strip** (initiative exists but is invisible mid-fight): small portraits in
  order across the top, current one raised. `S`

### 4.5 Stash and equipment
- Filters (slot / rarity / cursed / sockets) and a search box on desktop; filter chips on
  touch. `S`
- **Buy-back** tab at every merchant for the last 10 sold (MISC §9). `S`
- Compare tooltip standardised: every item hover shows the equipped item beside it, same
  layout everywhere (some screens do, some do not). `S`

### 4.6 Settings additions  `S`
Colorblind palette (protan/deutan/tritan shifts on school colors and status tints), reduce
flashes, auto-end-turn when AP hits 0 (off by default), damage number size, screen shake
slider, and a "replay tutorials" list.

### 4.7 Codex completion  `S`
Each journal tab shows `seen / total` and a thin bar; Bestiary rows gain a "hunt" marker
(§5.4). Completion feeds three achievements (Bestiary 50%/100%, Creatures 100%).

---

## 5. CONTENT additions and expansions

### 5.1 Contracts (the quest/board rework, parked #8)  `L`
Replace "count and redeem" with **contracts** that have a choice or a step mid-run:
- Kinds: **Escort** (an NPC's hireling joins as a temporary 2nd companion for one run; if
  it survives, pay ×2), **Sacrifice** (turn in an item of X rarity; the NPC remembers what
  you gave and the reward scales), **Timed** (finish within N rounds total), **Choice**
  (mid-run event with two endings that change the reward and a bond line), **Chain** (3
  steps across 3 runs, the last a named elite — §5.2).
- Board shows 3 contracts + 1 chain; a contract taken adds a **floor-map marker** on the
  room where its step fires (events already spawn from the pool; add a `contract` tag).
- Files: board templates, journal quests tab, floor pool weighting, `event_catalog` (5 new
  contract events), NPC dialogue lines. Save: quest state already exists; add `step`.

### 5.2 Nemesis: the one that killed you  `M`  · zero art
When you die to a non-boss enemy, it becomes your **Nemesis**: named from the existing
cursed-title generator, gets 1 elite affix (§2.5), +1 per further kill of you, and is
guaranteed to appear once in your next run in that dungeon as an elite with a bounty
(gold ×3, a Reforge Ingot, a keepsake at 3 kills). Killing it clears it. Shadow of Mordor's
loop at the cost of one struct. Save: `global.nemesis {enemy, name, affixes, kills, dungeon}`.

### 5.3 Anomalies: weekly seeded runs  `M`
A date-seeded **Anomaly** dungeon offer on the select screen: fixed seed, fixed dungeon,
2 modifiers from a 14-entry table ("Every elite is Twinned", "Shrines are free, curses are
mandatory", "Tide never recedes"). One attempt per week counts; the run summary posts the
score locally **and to a Steam leaderboard per week key (M 09-24: same batch)** —
`steam_upload_score` via the Steamworks extension, one board `anomaly_<yyyy>_<ww>`, a
board panel (top 10 + your rank) on the select screen; Android shows the local score only.
Uses `run_seed` reseeding that already exists.

### 5.4 Marks (bestiary hunts)  `S`
Each Bestiary entry has a **Mark**: kill 10 → its Compendium page unlocks a lore line + a
small permanent bonus vs that family (+3% damage). 83 entries make this a long tail that
rewards the bestiary tab, which nobody opens today.

### 5.5 NPC side stories  `M`  · text only
Each of the seven NPCs gets a 3-beat side story gated by bond tier 2/3/4: a ledger event, a
request with a real choice (two endings), and a payoff line + a keepsake trinket on the hut
shelf (8 keepsakes exist; add 7 NPC ones — `ART` 7 tiny trinkets, ~7 gens, or reuse the
NPC portrait miniatures). This gives the "town remembers" fantasy content instead of copy.

### 5.6 Secret rooms and keys  `S/M`
Scavenge GREAT results and Vault chests can yield **keys**; a floor with a key spawns a
locked side node (existing treasure_vault art) with a guaranteed rare+ and one of 6 new
egg-less **relic consumables** (run-scoped, powerful: "Hourglass: retake your last turn").

### 5.7 Descent Trials  `S`
Three fixed-build challenge runs unlocked at A3 (preset class + loadout + companion), each a
single floor with a named boss variant and a unique epithet. Cheap, uses existing bosses
with elite affixes.

### 5.8 Egg and species content tied to §1
Two new egg types: **Ledger Egg** (from Scavenge GREAT: hatches with a Calling already
chosen) and **Rescue** found creatures arriving with an injury tier 1 and +2 bond. Species:
no new art; the 26 species without adult art remain gated as today.

---

## 6. Economy glue (what feeds what)

| Faucet (new) | Sink (new) |
|---|---|
| Ledger: reagents, valuables, dust, gold, eggs, feed | Callings swap at Bairc (dust), 3rd party slot (rank 2) |
| Nemesis bounties, Anomaly rewards | Oath swap (Vex), Scar removal (Sable), dyes (Vael) |
| Marks, contract payouts (ingots) | Heirloom cursing (Sable), key vault gambles |

Gold inflation guard: ledger gold scales with Awakening like drops and is capped at 25% of a
run's average banked gold per resolved mission (tunable constant `LEDGER_GOLD_CAP`).

---

## 7. Build order, sizes, and what ships together

| Phase | Items | Size | Save | Art |
|---|---|---|---|---|
| **P0 quick wins** | 2.3 companion commands · 2.5 elite affixes · 4.4 combat readability (4 items) · 4.5 buy-back + filters · 3.5 presets · 5.4 Marks | 1-2 sessions | additive | none |
| ↳ **P0 status 09-24** | BUILT, awaiting M F5: elite affixes (5, nameplate + inspect + compendium + tutorial + loot tier) · companion commands SIC/HEEL/FETCH (keys Z/X/F, pad Y/LB/RB, touch chips, tutorial) · Hunter's Marks (kill ledger saved, +3/5/8%, bestiary + inspect lines) · BUY-BACK tab on Petra + Dorn (last 10 sales, +25%, saved) · loadout presets P1-P3 (keys 1-3 / V, pad L3/R3/Select/Start, chips, saved). **Deferred to P0b:** stash filters + search, ability hold-to-preview on touch, enemy-panel tap on touch, bottom-docked End Turn (existing touch layout was M-tuned; revisit with the S25 pass). The turn-order strip already existed (top chips). | | | |
| **P1 THE LEDGER** | §1 in full (jobs, dispatch, away state, report) + 4.1 Inbox + 4.2 run summary + 1.7 Callings | 3-4 sessions | additive | none |
| **P2 combat depth** | 2.1 cover · 2.2 break bar · 2.4 Momentum + finishers · 2.7 items · 2.6 props (art) | 2-3 sessions | none | 5 props |
| **P3 identity** | 3.1 Oaths · 3.2 Heirloom + cursed items · 3.3 tints · 3.4 Scars · 3.6 heraldry · 4.6 settings | 3 sessions | additive | none (shader) |
| **P4 content** | 5.1 Contracts · 5.2 Nemesis · 5.3 Anomalies · 5.5 side stories · 5.6 keys · 5.7 trials · 5.8 eggs | 3-4 sessions | additive | 7 trinkets optional |

Every phase ends with an M F5, a mobile touch pass (S25), and a commit. P1 is the headline
and should be the first thing after P0; P2-P4 can reorder on M's taste. Nothing here bumps
`SAVE_FORMAT_VERSION`; every new field defaults on load with the existing
`variable_struct_exists` idiom, so 1.0.7 saves on Steam and Play keep working.

---

## 8. Decisions (M, 2026-09-24) — LOCKED

1. **Ledger entry point:** the hut desk (`garden:desk`) opens THE LEDGER; Bairc on the
   grounds keeps opening the creature station.
2. **Parties out at once:** 2 from the start; a third slot is the Bairc rank-2 perk.
3. **Durations:** 1/2 runs as specced **plus a 3-run EXPEDITION kind** (best payouts, 5% egg,
   one offer at a time, never at tier 1) — added to the §1.3 table.
4. **Long Forage grows the bench:** 3 growth per run away; never crosses a stage by itself.
5. **Callings** are picked at the Young Adult crossing.
6. **Finishers: one per Oath (six), ship with P3.** Momentum ships in P2 with a +1 AP payoff
   at 100 (§2.4).
7. **Cover applies to the pet:** while Heel is up, enemies must go through the pet.
8. **Scars are opt-in** (choose none allowed), max three, Sable removes for dust.
9. **Anomalies wire Steam leaderboards in the same batch** (weekly board key; Android local).
10. **Keep all of §5** (Contracts, Nemesis, Anomalies + Marks + Trials, side stories + keys).
11. **Momentum in P2** with the +1 AP placeholder payoff (see 6).
12. **Go:** doc locked and committed 09-24; P0 quick wins begin the same session.
