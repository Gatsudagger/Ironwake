# DORN'S PATTERN BOOK — Reforge Craft Rework (BUILT 08-11, awaiting F5)

Status: **BUILT 08-11 (same session as the design lock) — awaiting M's F5.**

## §0 BUILD MAP (what shipped, where)
- **Data layer** (`scr_stats`, appended module): `pattern_book_ensure` (global
  `{fam, art}`, saved/loaded/reset in `scr_save`), `pattern_family_catalog` (12
  stat/utility + 8 school families from the live affix pools),
  `pattern_book_study` + previews (3 / 4-Rare+ / 5-Epic+ pips),
  `pattern_art_unlock`/`pattern_art_for_slot`, `pattern_smelt_*`,
  `pattern_craft_build`/`pattern_craft_reroll`, `pattern_band_range` (tier
  I/II/III = 60–80% / 80–100% / 90–100% of the rarity's natural value; school
  affixes band inside their natural u1/r2-4/e5-6 ranges), `pattern_name_roll`
  (game-rule names from the affix prefix/suffix pools + a funny flavor page).
- **Smelt**: shared item picker purpose `pb_smelt` (unequipped stash+pack,
  Uncommon–Epic, never dormant) → study popup (choose the family IN the modal,
  checkout standing rule) → destroys fodder for 25g: +1 ingot of its tier,
  +1 study, art unlock. Legendaries keep their own three sinks.
- **Craft wizard** (`[N]` on the reforge tab): slot → rarity (U/R/E; fee 150/
  300/600g + 20/40/80 dust + 1 tier-matched-or-higher ingot) → base stat
  (+3/+5/+7, needs tier I of that stat) → affixes (full natural budget 1/2/2,
  chosen from unlocked blueprints; school affixes on amulet/ring only) → icon
  (any unlocked art for the slot via `icon_as` proxy, or Dorn's plain work) →
  name (typed, 24 cap, RANDOM generator button) → checkout → result card with
  paid REROLL NUMBERS (60g×rarity, same bands). Crafted piece lands in the
  stash, rolls quality 60–85 (temperable), sockets by rarity.
- **UI**: reforge tab gear list 6→5 rows; verb row SMELT [T] / PATTERN BOOK [B]
  / CRAFT [N] at y772–824; book browser overlay (pips + art count, visible
  scroll bar, touch arrows); geometry in UI_BANDS.md. Tutorial `pattern_book`
  fires on the tab. Full touch/kb parity (rows + buttons hit-test in Draw).
- **v1 deviations (flagged, not silent)**: COMPLETE is folded into the wizard's
  icon+name steps (M's answers 2+4 make it the builder's last pages, not a
  separate verb); the §3 ◆ crafted-affix marker belongs to the superseded
  imprint model — a fully crafted piece is marked by its lore line + custom
  name instead; elemental weapon riders are neither studyable nor craftable
  (crafted weapons trade the elemental roll for determinism); crafted 2H not
  offered v1. Vetoables: all fees, bands, base stat +3/+5/+7, budget 1/2/2.


## §7 ANSWERS (M, 08-11 — these override anything below that conflicts)
1. **Tier gates:** tier I open; tier II = Awakening 2+; tier III = **Awakening 5
   in one dungeon + Awakening 2 in a SECOND dungeon** (cross-dungeon proof, NOT
   the win — "a full win seems too steep and throttling").
2. **CRAFT = a CUSTOM ITEM BUILDER, not a single imprint.** The player: picks the
   slot + rarity (bounded by what they can pay), picks the ICON from the book's
   unlocked art page, and picks EVERY affix from their unlocked blueprints up to
   the rarity's natural affix budget. The item must stay "within item ranges" —
   the NUMBERS still roll RNG inside the rarity's normal value bands. "It's
   customization": deterministic identity, rolled magnitude.
3. **Rolls within a band + paid re-roll within the tier** (gold sink; tier sets
   the band, blueprint tier I/II/III = low/mid/high band).
4. **COMPLETE = assign icon + FULL RENAME, with a RANDOM NAME GENERATOR button**
   (rolls what the game would have called it — prefix/suffix pools — plus some
   funny flavor entries).
5. Smelt fodder is stash-aware (assumed yes; consistent with the 08-11 NPC
   stash rule).
M's brief (08-11): "instead of just doing a reroll... allow a system where players can
eventually craft their own item by combining component affixes... melting the item down
you can destroy it BUT keep one affix... making even uncommon items slightly useful...
we need to design a way of accruing blueprints that requires multiple breakdowns and
also tiers so you unlock the weakest version first but can then customize your own
uncommon item thats more useful than a rare potentially if it fits you specifically...
smelting can also unlock the art they assign when completing their item."

Decision already made by M: this is a **deeper design first** (option 3), with a
**RECIPE BOOK** as the accrual structure. Slow accrual is the anti-break lever: no
instant access to BiS affixes.

---

## 1. The loop

```
SMELT gear  ──►  learn BLUEPRINT progress (affix family)  ──►  unlock tier I → II → III
     │                                                              │
     └──►  unlock the smelted item's ICON ART                       ▼
                                            CRAFT: imprint a learned affix onto YOUR item
                                                     │
                                                     ▼
                                            COMPLETE the item → assign any unlocked art
```

Three verbs on Dorn's reworked tab (the blind ingot REROLL stays as the cheap fourth):

1. **SMELT** — destroy an unequipped item (ingot of its tier + small gold fee).
   You choose ONE of its affixes to *study*: that affix family gains +1 blueprint
   progress. The item's icon art is also added to the PATTERN BOOK's art page.
2. **CRAFT (imprint)** — take a base item (Uncommon+), pay gold + dust, and apply a
   *learned* blueprint affix at any tier you've unlocked. The affix is CHOSEN, not
   rolled — that determinism is the whole power budget (see §4).
3. **COMPLETE** — an item with at least one crafted affix can be *completed* for a
   finishing fee: it gets a nameplate flourish ("Crafted by <character>"), and you
   may assign ANY icon art unlocked in the book. Visual chase closes here.

## 2. Blueprint accrual (the recipe book)

Per affix family (e.g. "+STR", "+crit chance", "lifesteal", "+max HP"...):

| Tier | Roll strength | Unlock requirement (smelts carrying that family) |
|---|---|---|
| I   | the family's floor roll | 3 smelts |
| II  | mid roll | 4 MORE smelts, each from a RARE+ item carrying the family |
| III | near-ceiling roll | 5 MORE smelts, each from an EPIC+ item carrying the family |

- Progress is per-family, shown as pips in the book ("Lifesteal ●●○ — 1 more study").
- A smelt only advances ONE family (the one you chose to study) — multi-affix items
  make you pick what to learn, which is a real decision and halves accrual speed.
- **Legendary affixes / unique effects are NOT blueprintable.** Legendaries already
  have three sinks; their identity stays theirs.
- Tier gates can additionally sit behind progression (proposal: tier II needs
  Awakening 2+, tier III needs the win or Descent 10+) — *M to veto/keep*.

## 3. Crafting rules (anti-break levers)

- Base must be **unequipped, Uncommon or better**, and NOT dormant.
- An item holds at most **1 crafted affix** (v1). It *replaces* an existing affix of
  your choice, or fills an empty affix slot if the rarity budget has room — it never
  exceeds the rarity's natural affix count. An Uncommon with the exactly-right chosen
  affix beats a random Rare *in fit*, not in raw budget — M's stated target.
- Crafted affixes are marked in the stat line (proposal: `+8 STR ◆` with the book's
  diamond) so the item reads as yours at a glance.
- Re-crafting the same item overwrites the previous crafted affix (fee again).
- Fees (all vetoable): SMELT = ingot of item tier + 25g. CRAFT = 150g + 20 dust at
  tier I, ×2 per tier above. COMPLETE = 100g flat.
- Smelting is destructive → **checkout popup** (standing rule), and the affix-study
  choice happens IN the popup so it can't be fat-fingered.

## 4. Why this doesn't break early game

- 3 smelts before the FIRST tier-I blueprint = you must feed it real drops early,
  when drops are still scarce.
- Tier I rolls are floor rolls — strictly worse than a good natural roll; what you
  buy is *choice*, not power.
- The strong versions (II/III) are gated behind rarity-specific smelt fodder that
  only late game supplies in volume, plus optional progression gates (§2).
- Gold/dust fees ride the same economy as tempering, which M has already tuned.

## 5. Art unlock page

- Every smelted item's icon goes into the book's ART page (dupes ignored).
- COMPLETE lets you assign any unlocked icon to the crafted item (icon_seed/sprite
  override field — same channel the icon reforge used before it was removed from
  tempering, so the plumbing exists).
- Proposal: sets ("smelt all 5 armor weights of a family") could unlock bonus
  flourish frames later — parked, post-launch.

## 6. UI sketch (Dorn tab rework)

- Tab renamed **REFORGE → PATTERN BOOK** (or keep "Reforge"; M call).
- Left panel: ingot inventory (unchanged) + the book: affix families with tier pips.
- Right panel: three stacked verbs — Smelt / Craft / Complete — each opening the
  shared item picker (EQUIPPED-tagged, stash-aware) with the relevant filter.
- Reroll keeps its current flow, demoted visually to a side action.

## 7. Open questions for M

1. Tier II/III progression gates (Awakening 2+ / win) — keep or drop?
2. 1 crafted affix per item in v1 — or allow 2 on Epic+ for a steep fee?
3. Should the crafted affix be re-rollable WITHIN its tier (pay to bump a bad
   floor roll), or is tier = fixed roll (simpler, recommended)?
4. Does COMPLETE rename the item too ("...of <player-chosen suffix>")? Forge
   already has naming precedent.
5. Smelt fodder from the stash directly (stash-aware picker) — assumed yes.
