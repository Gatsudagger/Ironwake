# DESIGN LOCK — Active per-biome mechanics (09-02 late, designed with M)

Status: **§1 THE TIDE BUILT 09-09 (uncommitted, awaiting M F5).** §2-§5 still design-locked, not built. Build order = §7.
Companion to `DESIGN_BIOME_IDENTITY_0827.md` (the passive identities, all built).

## 0. Ground rules (M's, 09-02)
- A biome mechanic **costs or punishes the player; it never hands out free advantage.**
  The only upside anywhere is an opt-in *gamble* with a real downside (Scorched Quench, Vault Ledger)
  or a *lever* the player works (Drowned tide). "Some offer too much advantage without much
  disadvantage" was the note on the first draft.
- **Enemies are native.** Nothing a biome does hurts them (the drowned know the tide; the Canopy grew
  the vines). Low tide *weakening* enemies is the one exception and it is the player's lever, not a gift.
- **The timing ring stays the general combat verb.** Biome cues reuse it (press, or hold-and-release).
- The **typing / trace mini-game for Blink & Shadowstep is GENERAL combat variety, NOT a biome thing** -
  parked, "leave them free for now". Do not marry it to any biome.
- The map only ever goes forward. Never describe anything as "no backtracking" - it means nothing here.
- Touch parity on every input ([[feedback-touch-compat-always]]); every new HUD element is visible in
  **every scene** (floor map AND combat); descriptions/lore update in the same edit.

## 1. Drowned Reach — THE TIDE (M's design)
**The Clock made visible and steerable.** A **tide counter** ticks and cycles HIGH ⇄ LOW.
- **Ticks:** every floor-map node pick = 1, every **combat round** = 1. (So burning turns in a fight
  is a real lever: "you might want to burn turns if you know the next room is a treasure room.")
- **Cycle:** start at **8 high / 8 low** (M: 6 may be too short across a long fight, 4 "far too short";
  don't exhaust the player). Tuning knob `tide_phase_len`, same at every awakening until playtested.
- **Gauge:** a **ship's wheel** that turns with each tick, shown on the floor map AND in combat, with
  ticks-to-turn readable. "We need fun stuff like that." Wheel art = a small animated sprite (art run).
- **HIGH tide:**
  - event rooms resolve to their **negative variant** (positive/neutral outcomes flip to the bad branch
    or a "ruined by the water" variant - each Drowned event gets an authored high-tide text);
  - **loot rarity -1 tier**, but **~10% chance of a hand-authored TIDE DROP** (5-8 unique tide-themed
    gear pieces only obtainable at high tide - the reason to ever *want* high tide);
  - in combat the **breath ring** opens when the water crests (hold, release in the band). Perfect =
    nothing happens. Poor = -1 AP next round. Miss = -1 AP + drowning damage. **Punish-only.**
- **LOW tide:** enemies **-15% dmg / -15% HP** and **Rising Water disabled**; rooms resolve normally
  (a positive room is never made negative at low tide).
- **Tide change DURING combat** does something + plays a brief VFX: HIGH→LOW = the water drains
  (enemies lose their Rising Water stacks / summons falter, one-off); LOW→HIGH = a surge (all combatants
  pushed: player loses 1 AP this round, enemies gain a Rising Water tick). Camera/scrim wash + bell.
- **Lore voice:** "the ocean beats you down, waves wear you away" - use for the tide tooltips, the
  wheel coach-mark, and the Drowned floor-intro line.
- **Vertical map:** Drowned Reach **descends** (layer 0 at the TOP, exit at the BOTTOM); the shaft
  darkens per layer; the tide gauge sits beside the shaft.

## 2. Hollow Canopy — THE CLIMB (bridges break)
- **Vertical map:** Hollow Canopy **climbs** (layer 0 at the BOTTOM); gold light shafts thin out upward.
- Some connections are **rope bridges / root-floors that can give way**. When one breaks you **drop
  one layer** and land on an **unvisited** node; the map **regenerates a short procedural spur
  (2-3 nodes)** from there back up. The spur is extra Reprisal-roster fights; the layer you fell through
  is gone. Rotten crossings are **partly telegraphed by a stat check** (Perception / Dexterity: a cracked
  icon) so a careful build reads the map and a reckless one pays.
- **Combat cue - Cut the Vine:** vine stacks build one per enemy turn (visible status); at the snap
  (3 stacks) a **press ring** opens. Perfect = you avoid the Root, nothing else. Miss = Rooted.
  **No Expose reward.**

## 3. Tundra Tomb — SHATTER (control rings, Tundra ONLY)
- The **only** biome where enemy CONTROL abilities (stun/root/weaken/blind/silence/chill) open a ring.
  Elsewhere they land with no ring, as today (M: "I don't want to make the game too easy by dodging
  everything").
- Grades: **perfect = negated**, **good = duration halved**, **miss = status lasts +1 turn** (M: "if
  we're allowing complete dodging then it needs a punish as well").
- **Roster follow-through** (Tundra must be control-heavy to earn this): add control riders to
  **Glacial Beast** and **Frozen Sentinel**, give **Glacial Warden** a freeze phase; existing carriers =
  Frozen Thrall (root), Ice Specter (weaken), Mourner in Ice (keening), Barrow Wight (chill).
- Map stays passive (the Denial already reads).

## 4. Scorched Depths — THE VENT + THE QUENCH (gamble)
- **Vents** on the floor map pulse on a visible rhythm. Entering a node **during the flash = start the
  fight Burned**. Entering in the lull is simply safe - **no bonus.**
- **The Quench** at floor end (opt-in, always skippable): one press in a tight band. Perfect = temp
  damage buff for the next floor; miss = weapon **brittle** (-armor) for the next floor.

## 5. Ashen Vault — THE LEDGER (gamble, lightest touch: teaching floor)
- At floor exit the Count shows **kills vs hits taken**. **Settle** = modest gold scaled by how clean the
  books are. **Carry** = larger payout next floor with a **Candle Thief ambush** chance. Walking past is free.

## 6. Biome events must interact with the mechanics (M: "we need to add unique events to each biome
that affect and interact with these new room mechanics")
- Drowned: every existing Drowned event gets a HIGH-tide variant; add 2 tide events (e.g. *The Wheelhouse*
  - spin the wheel: advance the tide N ticks either way for a price; *Slack Water* - hold the tide for
  the next 2 rooms).
- Canopy: add 2 climb events (e.g. *The Rope-Wright* - reinforce the next crossing for an item;
  *The Long Way Round* - accept a guaranteed spur now for a guaranteed loot node above).
- Scorched: *The Bellows Still Breathe* already exists - make it shift the vent rhythm.
- Tundra: one event that pre-applies a control the ring can practise on (tutorial-ish).
- Vault: *The Jailer's Ledger* becomes the in-fiction explainer for the floor-end Ledger.

## 7. Build order (proposed, needs M's go)
1. Tide system + wheel HUD + breath ring + low/high effects + tide drops (Drowned vertical map).
2. Canopy vertical map + break/spur + vine ring.
3. Tundra control rings + roster riders.
4. Scorched vents + Quench. 5. Vault Ledger. 6. Biome events pass (§6). 7. Coach-marks + lore text.
Systems to hang on: parry/strike rings (combat Step ~4828 / Draw_64), layered-DAG floor gen
(obj_floor_controller Create_0 ~117-320, `global.floor_node_w`), `floor_mod` flags (scr_stats ~13101),
event `dungeon:` routing, boons, summons, initiative.
