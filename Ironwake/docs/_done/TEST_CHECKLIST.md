# In-IDE Test Checklist — Vex Rework + AoE/Status (2026-06-20)

Two unverified builds (no GMS2 compile from the agent). Run these in order — a clean
compile first, then the Vex rework (most invasive), then AoE/status spot checks.

## 0. Compile / boot
- [ ] Project compiles with no errors (scr_abilities, scr_stats, scr_combat, scr_ui,
      obj_game_controller, obj_combat_controller all touched).
- [ ] New game boots to hub; existing save loads without error (trait-key backfill runs).

## 1. Vex — tabs & navigation
- [ ] Vex shows **5 tabs**: Stats | Trait Slots | Abilities | Traits | Potency — no overlap,
      all labels readable, none clipped at screen edge.
- [ ] Q/E cycles all 5 tabs; clicking each tab selects it; cursor resets on tab change.
- [ ] W/S navigates rows; Esc closes (and cancels a pending Potency confirm first).

## 2. Vex — Abilities tab (gold only, 100/250/400)
- [ ] Lists this class's locked abilities + general pool, with new prices (e.g. Curse 100g,
      Entropy/Arcane Echo 250g, Rift/Singularity 400g).
- [ ] List **scrolls** past 8 rows (▲/▼ indicators); mouse-click selects the *correct* row
      while scrolled (click a lower row after scrolling — it should pick that ability).
- [ ] Buy with enough gold → gold deducted, ability appears in loadout pool at Dungeon Gate.
- [ ] Buy with too little gold → "need Xg more", no purchase.

## 3. Vex — Traits tab (NEW: gold + rarity item)
- [ ] Lists non-default, class-appropriate, not-yet-owned traits with `Xg + 1 <rarity> item`.
- [ ] Tier sanity: Prospector = 200g+Uncommon; Iron Will = 350g+Rare; Plaguebearer/Arcane
      Surge = 500g+Legendary.
- [ ] Class traits show ONLY for the matching class (e.g. Soul Siphon hidden as Bloodwarden).
- [ ] Buy with gold + a qualifying item → gold deducted, **lowest-value qualifying item
      consumed** from stash/pack, trait leaves the list, "traded: <item name>" shown.
- [ ] Buy with gold but NO qualifying item → blocked with "needs a <rarity>+ item".
- [ ] Trade-item readout at the bottom matches the selected row's required rarity.
- [ ] Purchased trait is now selectable at the Dungeon Gate loadout screen.

## 4. Vex — Potency tab (unchanged, now tab 5)
- [ ] Lists the 7 upgradable traits; stat-sacrifice purchase + "Beware…" confirm still works.
- [ ] Confirm bar click region still commits (it moved with the tab).

## 5. Milestone unlocks REMOVED (regression guard)
- [ ] Kill a floor boss → **no** "TRAIT UNLOCKED" toast; boss kill still counts
      (total_boss_kills increments; Battle Hardened +HP still fires if equipped).
- [ ] Level up / full-clear a dungeon → **no** trait-unlock toasts.
- [ ] The only way a trait becomes equippable is buying it at Vex.

## 6. AoE + Status spot checks (earlier build)
- [ ] **AoE**: Rift / Singularity (Arcanist) or Smoke Bomb hit BOTH enemies in one cast;
      each gets its own damage popup / status; kills award gold+XP+loot per enemy.
- [ ] **Focused Power** equipped → an AoE instead hits only the selected target for ~+50%;
      tooltip reads "Targets: SELECTED".
- [ ] **Vulnerable** (Curse/Mana Sever/Bonebreaker): target visibly takes extra flat damage
      from the next hit.
- [ ] **Weaken** (Marrow Crush/Crippling Shot): that enemy's next attack hits for less.
- [ ] **Blind** (Smoke Bomb): enemies miss noticeably more for 2 turns.
- [ ] **Stun/Root** (Death Snare / Bear Trap): the affected enemy skips its turn ("stunned/
      rooted and cannot act"), then resumes.
- [ ] **Soul Shield**: shows absorb message and eats damage before HP drops.
- [ ] **Chain Caster** / **Plaguebearer** (if owned): splash damage / debuff spread to the
      other enemy fires.
- [ ] Player DoT/debuff (if any lands on you) ticks at the start of YOUR turn; Last Stand
      still catches a lethal DoT tick.

## 7. Clean-save testing notes

**Why a clean save matters:** old saves already have many traits unlocked from the *old*
milestone system, so on an existing save you can't tell "free auto-unlock fired" (the bug
we removed) from "this trait was earned earlier" (grandfathered, fine). The §5 regression
guard is only trustworthy on a **fresh** save that starts with just the 3 default traits.

Test against **two fixtures**:

### Fixture A — CLEAN save (validates §3 Traits + §5 regression)
- Title → **New Game** on a slot. (3 slots: 0/1/2. New Game on an occupied slot asks for
  one confirm press, then overwrites — pick an **empty** slot to keep your real save.)
- This starts you with only Sense / Scavenger / Thick Skin unlocked, 0 bought abilities.
- [ ] At the Dungeon Gate, only the 3 default traits are selectable.
- [ ] Do a run: kill a boss, gain a level, clear a floor → **no** "TRAIT UNLOCKED" toasts,
      and the trait list at the Gate is still just the 3 defaults.
- [ ] To actually buy from Vex you need gold + a qualifying item — easiest is to do a short
      dungeon run first to earn gold and pick up an Uncommon/Rare/Legendary drop, then return
      to Vex. Confirm a purchase unlocks the trait and it appears at the Gate.

### Fixture B — EXISTING save (validates backfill / no data loss)
- Title → **Load Game** on your pre-rework slot.
- [ ] Loads with no error (the Create backfill adds focused_power/chain_caster/plaguebearer
      etc. as needed).
- [ ] Traits you'd already earned are **still unlocked** (grandfathered — expected, not a bug).
- [ ] Previously goal-unlocked abilities (Arcane Echo, Singularity, etc.) are now **locked
      again** unless in `unlocked_abilities` — they're gold-only now, so buy them at Vex.
- [ ] Bought abilities / trait slots / potency from before are intact.

### Wiping a slot for a truly empty start
- Save files: `ironwake_save_0.json` / `_1` / `_2` in the GMS2 sandbox, typically
  `C:\Users\miles\AppData\Local\<GameName>\` (search that folder for `ironwake_save_*.json`
  to confirm the exact path/name).
- **Back up the folder first**, then delete the slot's JSON for a guaranteed-blank slot
  (or just use New Game on an empty slot — non-destructive, no file deletion needed).
- After editing/deleting save files, relaunch so the title screen re-reads slot previews.

## Notes / fails
- Record any console error + the step number here as you go.
