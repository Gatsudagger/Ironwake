# BIOME IDENTITY PASS — design draft 08-27

*Goal (M): every dungeon plays, reads, and rewards fundamentally differently.
Each biome favors a different ability loadout, its enemies' kits speak its
identity, and it carries its own suite of lore-fitting events with personality.*

Status: **DESIGN-LOCKED with M 08-27** (scope: everything; ambush fangs kept;
identity matrix approved as written). **BUILT 08-27, same session** — event
engine (dungeon routing, pending_status / temper / floor_mod / ambush / offer /
ap_penalty effects, odds-line phrases), all 20 biome events, 9 new monsters +
4 kit retunes, floor-mod hooks (tide_slack / green_hush / bellows_heat /
tomb_marked / boss_exposed), grove item-sacrifice via the shared picker,
ambush-with-prize via the duel-launch + warden-loot idioms, checkpoint
persistence. Awaiting M's F5 with the rest of the 08-27 tree. Art notes in
§6 remain the brief for the pending art run (new enemies ship on stand-ins).
Companion to `DESIGN_WORLD_EXPANSION_0806.md` §3 (ladder + biomes, built 08-27).

---

## 1. Research grounding

**Genre lessons applied:**
- *Dead Cells*: a biome is a **rule you must adapt to** (poison pools force
  positioning, ramparts force verticality) plus **biome-exclusive enemies**.
  Translation for Ironwake: each dungeon gets one combat-level "field identity"
  the player builds around, expressed through its floor passive + its enemies'
  shared status suite — not just different stat sheets.
- *Hades*: region identity lands when **every channel agrees** — palette,
  music, enemy roster, and one region-specific mechanic. Translation: our
  palettes/ambience/art-run briefs must echo the mechanical identity (the doc
  states each biome's full sensory brief for the art run).
- *Slay the Spire*: events earn their keep through **unique costs and
  benefits** that interact with run state, and are allowed to swing runs.
  Translation: biome events trade in the **biome's own currency** (heat, ice,
  the tide, the growth) — not generic gold-for-HP reskins. Several directly
  modulate the biome's floor passive, which makes the passive itself feel
  like a system rather than a tax.

**Codebase audit findings (what's dishonest today):**
1. **Scorched Depths claims burn, barely burns.** Only Fire Drake's Searing
   Brand (and the boss's phase ability) applies a DoT. The dungeon's searing-
   air passive burns you between rooms, but its residents mostly just punch.
2. **Tundra Tomb claims numbing cold, barely chills.** One weaken (Ice
   Specter). Its "denial" identity lives entirely in the -1 AP passive.
3. **Events are dungeon-blind.** One flat 13-event catalog everywhere; zero
   biome voice. (Drowned/Canopy shipped 08-27 with strong *enemy* identity —
   sustain/summons vs lockdown/thorns — but no event support.)
4. **The Vault has no identity beyond "the starter."** Acceptable as the
   teaching dungeon (Dead Cells' Prisoners' Quarters is deliberately plain),
   but it deserves *voice* via events even if its combat stays clean.

---

## 2. The identity matrix (design targets)

One line each: **fantasy / field rule / enemy status suite / the loadout it
favors / the counter-tools it teaches.**

### Ashen Vault (+0) — "The Count"
- **Fantasy:** duty that outlived death. Everything still at its post,
  still counting. Amber, bone, dust columns.
- **Field rule:** none (the teaching dungeon stays mechanically clean — the
  chain's on-ramp).
- **Enemy suite:** honest physical + telegraphed charges + a little arcane
  drain. The tutorial for intents, weakness gems, and control.
- **Favors:** anything — deliberately neutral. Void-school gear bias (kept).
- **Teaches:** telegraph reading (charge enemies), first control uses.

### Scorched Depths (+1) — "The Windup"
- **Fantasy:** the forge that never went out. Ember on black, white-hot
  telegraphs, everything HITS HARD but SAYS SO FIRST.
- **Field rule:** Searing Air (kept) — rooms stack burn onto your next fight.
- **Enemy suite (retuned):** BURN + CHARGE. Most residents either apply burn
  DoTs or wind up huge telegraphed blows. Burn-immune themselves.
- **Favors:** **defense/timing loadouts** — Counterblade, Iron Skin, dodge
  kits (timed-combat parries shine here), frost-school offense, sustain to
  out-live the burns. Support cleansing (Leechbane line) finally has a home.
- **Teaches:** answering telegraphs; that DoTs on YOU are a damage race.

### Tundra Tomb (+2) — "The Denial"
- **Fantasy:** a court of frozen judgment. Blue-white silence; the dungeon
  takes things away — AP, accuracy, your abilities — and mends its own.
- **Field rule:** Numbing Cold (kept) — -1 AP on your first turn.
- **Enemy suite (retuned):** CHILL/WEAKEN + CONTROL + SELF-HEAL. Residents
  weaken, root, silence, and knit themselves back. Chill-immune.
- **Favors:** **control-counter + AP-economy loadouts** — cheap abilities
  (the -1 AP passive + weakens punish 3-AP haymakers), anti-heal (Mortality,
  Mana Sever), fire-school offense, cleanse consumables.
- **Teaches:** economy under denial; burst through mending.

### Drowned Reach (+4) — "The Clock"
- **Fantasy:** the flooded undercity; bells under water. Green-black,
  lantern-light, everything down here endures and outlasts.
- **Field rule:** Rising Water (built 08-27) — every 3rd round everyone -2 HP.
- **Enemy suite (built):** SUSTAIN + SUMMON — regen, drains, choirs, the
  Tidewright's flood turns halving your heals.
- **Favors:** **burst-offense + anti-heal loadouts** — the tide punishes slow
  fights, their regen punishes chip damage. Shock school (+30% everywhere),
  Mortality effects, Exposed setup→payoff combos, initiative (strike first,
  end fast). Healing-reliant builds are actively taxed (flood turns).
- **Teaches:** the kill-window mindset; fighting a clock.

### Hollow Canopy (+5) — "The Reprisal"
- **Fantasy:** the forest that punishes habit. Deep green + bone, shafts of
  light, spores in the air. It answers what you do: repeat an element and
  the thorns answer; open big and the growth chokes it.
- **Field rule:** Choking Growth (built 08-27) — first cast each combat +1 AP.
- **Enemy suite (built):** LOCKDOWN + THORNS — root, silence, blind,
  retribution, death-bursts.
- **Favors:** **flexible/varied loadouts** — two damage schools minimum
  (retribution punishes repeats), fire school, cheap or free openers
  (support chains, basic-attack starts), cleanse, ranged kits (roots stop
  melee lines — including YOURS if you build pure melee).
- **Teaches:** rotation discipline; the peak exam before/alongside A5 play.

---

## 3. Event system extension (small, surgical)

1. **Biome routing:** events gain an optional `dungeon:` field. `event_roll()`
   builds its pool as *generic events + current dungeon's events*, with biome
   events **double-weighted** — in-biome flavor should be the norm, not a
   cameo. No-repeat-per-run logic unchanged (ids).
2. **Three new effect keys** in `event_apply_effects` (everything else uses
   existing machinery — gold/hp/item/consumable/dust/rune/pet_egg/boon/
   ghost_shop/sicken/duel):
   - `pending_status: {kind, turns, mag}` — carry a status (blind/silence/
     weaken/burn) into your NEXT fight. Generalizes the existing
     `pending_sickness` (Wounded Wanderer) idiom.
   - `temper: 1` — one free quality step on a random equipped item (reuses
     Dorn's temper math; the Quenching Trough's whole point).
   - `floor_mod: "<tag>"` — a this-floor-only flag the relevant system reads:
     `tide_slack` (Rising Water fires every 4th round instead of 3rd),
     `green_hush` (Choking Growth waived this floor), `bellows_heat` (next
     3 combats: enemies -2 armor), `tomb_marked` (next 3 combats: enemies
     +5 acc — the price of robbing graves). Cleared on floor advance.
3. **One forced-fight effect:** `ambush: "elite"` — the result screen closes
   into an elite combat (reuses the duel-launch pattern), with the event
   pre-declaring the reward. Used sparingly (2 events total).

---

## 4. Event suites (authored)

*Format: title — hook / choices (mechanics). All magnitudes floor-scaled like
the existing catalog. Voice: house style — dry, concrete, a little haunted.*

### Ashen Vault — the Count (4)
1. **The Unfinished Muster** — a skeleton sergeant holds a muster roll;
   one name is never answered. *Answer for the missing name* (CHA check →
   the dead accept you: gold + consumable; fail: the count restarts —
   -HP as the column marches through you) / *Correct the ledger* (INT →
   dust + rune chance) / *Leave them to it*.
2. **The Jailer's Ledger** — Malgrath's duplicate records, still warm.
   *Study the entries* (INT → next boss enters Exposed — `pending_status`
   on the boss via floor flag; fail: paper cuts, literal: -HP) / *Feed a
   page to your torch* (gold bonus, but `tomb_marked`-style: +enemy acc 1
   fight — the Vault notices) / *Close the book*.
3. **A Door That Remembers You** — a cell door swings open at your step;
   inside, a prisoner's hoard. *Take the hoard* (item [chest] + the door
   closes: start next fight -1 AP — it wants a replacement) / *Take only
   what you need* (small gold, no cost) / *Leave it open* (nothing — but
   the log thanks you; pure voice).
4. **The Last Post** — one soldier still standing sentry, too tired to
   raise the spear. *Relieve him* (CON check → he hands over his kit: item
   with `item_min` uncommon+; fail: he mistakes you — take his last blow,
   -HP) / *Salute and pass* (small heal — a moment of order in the dark) /
   *Put him to rest* (STR → gold + dust; the post stands empty now).

### Scorched Depths — the Windup (4)
1. **The Quenching Trough** — the great trough still hisses. *Temper your
   steel in it* (STR check → `temper: 1` free quality step; fail: steam
   scalds — -HP + burn into next fight via `pending_status`) / *Drink*
   (heal, small — forge-water is technically water) / *Pass by*.
2. **Firewalk** — the short way is a floor of live coals. *Walk it*
   (guaranteed: burn into next fight + gold cache on the far side) /
   *Throw your boots* (sacrifice 15g, cross clean → item [chest]) /
   *The long way around* (nothing).
3. **The Tyrant's Tithe Bowl** — every smith paid him; the bowl still
   expects. *Pay the tithe* (gold → fire-school-biased gear, `item_min`
   uncommon; the forge stamps its mark) / *Take from the bowl* (gold jackpot
   but `ambush: "elite"` — the Depths collect) / *Respect the custom*.
4. **The Bellows Still Breathe** — the great forge-lungs, waiting. *Pump
   them* (STR check → `floor_mod: bellows_heat` — heat softens the enemy
   line, -2 armor for 3 fights; fail: backdraft, -HP + burn) / *Slash them*
   (DEX → dust from the fittings; the Depths run colder: tiny heal) /
   *Leave the lungs alone*.

### Tundra Tomb — the Denial (4)
1. **The Frozen Archivist's Query** — a voice from a reading stand asks one
   question, precisely. *Answer* (INT check → rune + dust; fail: your voice
   is FILED — silence into next fight) / *Refuse politely* (nothing) /
   *Steal the stand's inkwell* (DEX → gold; fail: silence + the Tomb
   notices: `tomb_marked`).
2. **A Body in the Ice** — armored, perfect, three feet deep. *Chip it
   free* (`ambush: "elite"` — it thaws mid-work; win pays its gear:
   pre-declared item [vault, uncommon+]) / *Take only the sword-hilt above
   the ice* (small item [chest]) / *Let winter keep it*.
3. **The Cold Court** — thrones of black ice; the seated dead turn to you.
   *Stand judgment* (CHA/WIS check → acquitted: boon-tier reward (dust +
   heal + consumable); fail: judged wanting — weaken into next fight) /
   *Plead guilty at once* (small gold fine, safe — the court respects
   efficiency) / *Decline the docket*.
4. **Grave Goods** — the honored dead, buried with everything. *Take the
   grave goods* (item [vault] + `floor_mod: tomb_marked` — enemies +5 acc,
   3 fights: the Tomb remembers thieves) / *Take only the offering-coins*
   (gold, no mark — coins were left to be taken) / *Add your own offering*
   (pay 20g → heal + dust; the dead approve).

### Drowned Reach — the Clock (4)
1. **The Diving Bell** — the salvage rig still works; the water is very
   dark. *Descend* (CON check → reliquary-tier item; fail: half-drowned —
   enter next fight at -25% current HP) / *Send the hook down blind*
   (weighted: gold / junk / snagged consumable) / *Leave the winch alone*.
2. **The Bell-Ringer's Toll** — a drowned sexton offers stillness, for
   coin. *Pay the toll* (gold → `floor_mod: tide_slack` — Rising Water
   holds to every 4th round this floor) / *Ring the bells yourself* (STR →
   the tide LIKES it: gold + consumable; fail: the water rises angry — -HP)
   / *Keep your coin* (the bells follow you out; pure voice).
3. **The Fisher's Market** — a Pale Fisher, off-duty, with a catch to
   trade. *Trade* (gold → 2 consumables + chance of a pearl: dust) / *Cut
   his line* (DEX check → his catch AND his tackle: item; fail:
   `ambush: "elite"` — he was not off-duty) / *Wave, from a distance*.
4. **What the Flood Kept** — a sealed cabinet above the waterline, dry as
   a sermon. *Pry it open* (STR check → item [reliquary]; fail: the seal
   was load-bearing — bloatlings: -HP + small gold) / *Read the label*
   (INT → its manifest: dust + reveal — small gold) / *Leave it sealed*
   (the Reach approves of things that stay shut; tiny heal).

### Hollow Canopy — the Reprisal (4)
1. **The Grove That Listens** — a clearing that leans in when you speak.
   *Make an offering* (sacrifice one carried item via the item picker →
   heal + boon-tier: dust + `floor_mod: green_hush` — Choking Growth waived
   this floor) / *Whisper a lie* (CHA check → the grove pays for a good
   story: gold; fail: it KNOWS — weaken next fight) / *Say nothing* (the
   polite option; nothing).
2. **Pollen Sleep** — a hollow full of warm, drifting gold. *Sleep* (full
   rest-tier heal + blind into next fight — you wake watched) / *Rest at
   the edge* (half heal, no cost) / *Press on* (nothing).
3. **The Wardens' Graft** — a living branch offers itself to your gear.
   *Accept the graft* (WIS check → `temper: 1` + the wood remembers: heal;
   fail: it takes root in YOU — -HP + root into next fight) / *Cut a
   switch instead* (small dust) / *Refuse — it's still alive*.
4. **A Clearing With No Sound** — the Green Silence has been here; even
   your footfalls arrive muffled. *Listen to the nothing* (WIS check →
   what the silence ate: rune + dust; fail: it eats your voice — silence
   next fight) / *Shout* (weighted: the echo returns gold / returns
   TEETH: -HP / returns nothing) / *Back away quietly*.

*(Generic catalog untouched — 13 + duelist still roll everywhere.)*

---

## 5. New monsters

*All on live mechanics. Original trio gets identity reinforcement; new
biomes are already at 12+3 residents each and get nothing (they're the
standard being matched). Stand-in sprites at import, art run later.*

### Ashen Vault (+2 standard, +1 elite)
- **Candle Thief** (std) — a shade that hoards light. HP 30, dmg 6, dodge
  12, phase_shift 1/3; ability: *Snuff* (debuff blind — "your torchlight
  dies around you"). Small (0.8). Weak: arcane. *Teaches blind early.*
- **Rustkeeper** (std) — a construct that maintains the Vault's bars. HP 44,
  dmg 6, armor 6, fortify 0.45/4, telegraph 18 ("raises its maul of keys").
  Weak: shock. *Teaches armor + fortify windows.*
- **The Second Count** (elite) — a robed skeleton auditor; the Sovereign's
  bookkeeper. HP 76, dmg 10; charge telegraph 20 ("totals the column");
  abilities: *Audit* (control silence — "finds an irregularity in your
  casting"), *Carry the One* (heal 12). Weak: fire. *The Vault's one taste
  of Tundra-style denial — foreshadows the ladder.*

### Scorched Depths (+2 standard, +1 elite) — burn/charge honesty
- **Pyre Dancer** (std) — HP 34, dmg 5, dodge 10, double_strike 4;
  ability: *Trailing Flame* (dot burn 4/3t). Weak: frost.
- **Slagback Tortoise** (std) — HP 52, dmg 6, armor 6, death_burst 12,
  telegraph 19 ("its shell glows white"). Slow (speed: slug band). Weak: frost.
- **The Unquenched** (elite) — a smith who wouldn't stop. HP 84, dmg 11,
  regen 5/2; abilities: *Hammer Rain* (spell fire 12), *Stoke* (dot burn
  5/3t). Weak: frost. *Sustain preview of the Reach, in fire.*

### Tundra Tomb (+2 standard, +1 elite) — chill/control honesty
- **Mourner in Ice** (std) — HP 38, dmg 5; abilities: *Keening* (debuff
  weaken 2t — "the grief gets into your arms"), *Composure* (heal 10);
  regen 3/2. Weak: fire.
- **Barrow Wight** (std) — HP 42, dmg 7, phase_shift 1/3; ability: *Chill
  of the Barrow* (spell frost 10 + its message seeds the chill fantasy).
  Weak: fire.
- **Cortege Bearer** (elite) — it carries coffins; the coffins are not
  empty. HP 80, dmg 10, armor 5, telegraph 20; ability: *Bear Forth*
  (SUMMON — "sets a coffin down, and opens it"). Weak: fire. *Second
  summoner in the game pre-Reach; makes Tundra elites scarier.*

### Kit retunes (original trio, small)
- **Fire Drake**: Searing Brand chance 30→35 (burn identity carrier).
- **Smoldering Revenant**: gains *Cinder Spit* (dot burn 4/2t, 25%).
- **Frozen Thrall**: gains *Grasp of the Drift* (control root 1t, 20%) —
  Tundra's denial reaches the standard line.
- **Ice Specter**: Numbing Chill 35→40 (weaken identity carrier).
- (Nothing touched on Vault standards — the teaching floor stays gentle.)

---

## 6. Visual / audio identity briefs (for the pending art+audio runs)

| Biome | Palette | Backgrounds say | Ambience says |
|---|---|---|---|
| Vault | amber, bone, dust-shafts | order decayed: rows, cells, columns | dry air, distant count-taps |
| Scorched | ember on black, white-hot accents | industry: anvils, vents, slag channels | bellows-breath, metal ticking as it cools |
| Tundra | blue-white, black-ice | judgment: thrones, niches, frozen ranks | wind through stone teeth, ice groan |
| Drowned | green-black, lantern gold | drowned civic: flooded naves, bells | water lap, muffled bells, drips in dark |
| Canopy | deep green, bone, gold light-shafts | overgrowth over ruin: roots through walls | leaves without wind, spore hiss, one distant knock |

Event panels tint to the dungeon accent color (already per-event `color`;
biome suites use their dungeon's palette). Enemy sprite art runs should read
the suite: Scorched enemies glow at the WIND-UP (telegraph fantasy), Tundra
enemies carry frost-mist, Reach enemies drip, Canopy enemies bloom.

---

## 7. Build plan (post design-lock)

1. Event engine: `dungeon:` routing + `pending_status` + `temper` +
   `floor_mod` + `ambush` (one shared launch path).
2. Author all 20 biome events.
3. New monsters ×9 + kit retunes ×4 (+ bestiary lore, weakness, class maps,
   sprite stand-ins, size/speed entries).
4. Floor-passive hooks read their `floor_mod` flags (tide_slack, green_hush,
   bellows_heat, tomb_marked).
5. Coach-marks: none new needed (events self-describe).

**Open questions for M** (the scope-lock):
- Ambush events (2): OK to launch combats from events via the duel pattern?
- The Grove's item sacrifice uses the shared item picker (route-through rule).
- Gold-jackpot-with-ambush (Tithe Bowl) can eat a run at A5-baseline — keep
  the fangs, or soften to gold loss on failure?
