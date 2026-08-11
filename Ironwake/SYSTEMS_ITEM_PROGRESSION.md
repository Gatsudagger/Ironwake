# SYSTEMS — Item Progression Rework (Tempering + Dormant Legendaries + Reassemblage)

> **STATUS: ALL FOUR SECTIONS BUILT 08-04 ("build it") — AWAITING F5.**
> Implementation notes per section below. Numbers are v1 - tune after playtest.
> Build map: quality/dormancy stamps in drop_equipment; scaling in
> apply_equipment_stats via item_power_mult (application-time, stored rolls
> untouched, grandfathered saves read as 100%/awake); Maren FORGE tab rows 5
> (Temper) + 6 (Awaken) -> shared item picker purposes maren_temper /
> maren_awaken (gc Step routes, scr_stats resolves); stat-string tags
> [Quality NN%] / [DORMANT] in ui_item_stat_str; long-name shrink-to-fit pass
> on equip picker, sell list, compare popup, Maren socket lists, Sable salvage.
> Dorn stock tune BUILT 08-05: his restock re-stamps quality 70-85 (all three
> stock paths - normal rolls, the 1-in-200 legendary jackpot, Master's Pick).

## The problem (M, 08-04)

A knowledgeable player races the loot-rarity ladder rapidly; the item ceiling
arrives early and NPC functions (Maren/Sable upgrades) feel optional next to
"just find a legendary." Goals: slow raw item progression, give the redundant
epic/potion flood a purpose, and make town investment a co-equal power axis.

## 1. TEMPERING (Maren) — drops roll weak, the smith finishes them

- Every item GAINED (drop, chest, vendor, reward) rolls `quality`: **60–85%**
  (uniform). Quality scales the item's stat_value, weapon_damage and affix
  values (display keeps the true rolled numbers; quality multiplies at
  stat-application time so the tooltip can show both).
- **Maren TEMPER service** (new row on her screen): +10% quality per step, to
  a 100% cap. Cost per step scales by rarity — proposal:
  | rarity | gold | rune dust |
  |--------|------|-----------|
  | Common | 40 | 5 |
  | Uncommon | 80 | 10 |
  | Rare | 160 | 20 |
  | Epic | 320 | 40 |
  | Legendary | 640 | 60 |
  A 62%-rolled legendary → 100% is 4 steps ≈ 2560g + 240 dust: the smith is
  half of every endgame item's story.
- A raw-dropped legendary (≈60-85%) lands near a tempered epic — racing rarity
  alone leaves real power on the table.
- Tooltip line: `Quality: 72%  (Maren can temper)` — gold at 100% ("Tempered").
- MIGRATION: items already in M's save get `quality = 100` (grandfathered; no
  save-format bump — missing field reads as 100).
- Dorn's stock rolls 70–85% (he sells decent, not finished, wares).

## 2. DORMANT LEGENDARIES — the find is the START of the story

- Legendary drop RATES are unchanged (they keep their weight slot — M: dormant
  must not mean "drops like an epic").
- The **15 bespoke named legendaries** (leg_* unique riders: Duelist's Rebuke,
  Longshot's Memory, Veil, Ashen Blade, ...) always drop TRUE — pure
  legendaries only found in legendary form (M 08-04).
- Generic stat-legendaries drop **DORMANT**: stats at ~0.55x (≈epic budget),
  name shown as "Dormant <name>", grey-gold tint, lore line telling you what
  it could become.
- **AWAKENING (Maren)**: consumes 2 epics + 300g + 60 rune dust (numbers TBD)
  → removes the dormant multiplier. Pairs with tempering: awaken first, then
  temper to 100% (dormant items can't be tempered — one pipeline order).
- Together with §1, a fresh dormant legendary needs Maren twice before it
  out-performs the epic you already finished — but a TRUE legendary find is
  still the jackpot moment.

## 3. CURSED REBIRTH — Alchemical Reassemblage  ✅ BUILT 08-04 (awaiting F5)

M design (08-04, both AskUserQuestion rounds): keep the loop, curses stack,
the ridiculous stacking title IS the flex, and the rolls are TRUE RNG:

- **RNG rolls (cursed_rebirth_make)**: every feed applies ONE positive surge —
  ×1.10..×2.40 rolled on stat_value / weapon_damage / positive affixes — and
  ONE curse at 60%..160% of its table bite. Old curses are NEVER re-scaled
  (they accumulate, not compound — this was the 3x death-spiral root cause).
  God rolls and busts both exist; a lucky item can be dragged down later.
- **Escalating cost (cursed_rebirth_fee)**: ×1.5 per curse already on the
  item. Base: cha_price(700)g + 2 potions + a gear bundle — 1 epic OR 3 rares
  OR 12 uncommons (equivalence bundles per M). Feed #2 ≈ 1050g/3 potions,
  feed #3 ≈ 1575g/5 potions, bundle counts ceil-scale the same way.
- **Payment — REAGENT PICKER (M 08-05) ✅ BUILT**: the player hand-picks what
  burns (auto-burn destroyed build-relevant items gold value can't see, e.g. a
  void build's cheap void rares). After the offering is chosen, a second modal
  (`global.reagent_picker`, stepped by `reagent_picker_step()` in gc, drawn by
  `ui_draw_reagent_picker()` in hub Draw_64) lists every eligible reagent —
  gear AND potions, both manual per M — with the junkiest/cheapest PRE-TICKED
  to meet the ask; any row toggles; SEAL bar arms then commits
  (`cursed_rebirth_commit()`). Gear is measured in ESSENCE so bundles mix
  freely: uncommon 1 / rare 4 / epic 12, ask = `fee.uncommons` points (same
  totals as the old rigid ladder at every tier). Overshoot allowed with a
  "the dark keeps the excess" warning. The picker DETAIL PANE previews the
  exact ask (red when unpayable) and says the burn choice comes next screen;
  the result message itemizes what burned.
- **Maren AWAKEN fuel is also manual (M 08-05: "all item selections are
  manual")**: same modal via `reagent_picker_open_awaken()` — epics-only rows
  (each worth 1, goal 2, junkiest 2 pre-ticked), amber forge skin ("FUEL FOR
  THE FORGE" / "LIGHT THE FORGE"), gold+dust line, no potion quota; commits
  via `maren_awaken_commit()`. Awaken picker detail pane gained a MAREN ASKS
  fee preview matching the temper one.
- Naming: prefixes stack + every epithet stays in the title (BUILT);
  codex identity stays clean-singular. Stash/loadout/codex long-name audit
  still due as a follow-up.
- **DARK GIFTS (M 08-04 round 2) ✅ BUILT**: every 3rd curse adds something
  NEW - a named boon rolled blind (magnitude rolled too), stamped into
  unique_desc as "DARK GIFT - <Name>: <effect>". Catalog: dark_gift_catalog()
  in scr_stats - 8 school hearts (Emberwake/Rimeheart/Stormlung/Hollowlight/
  Redthirst/Voidmaw/Nightbloom/Gravebloom, flat school damage via the existing
  school_ affix keys), 8 body gifts (Gravecoin gold find, Mothstep dodge,
  Palefang crit, Oxblood HP, Ironmarrow armor, Wardglass resist, Spellfang/
  Bonefang split crits - all existing affix plumbing), 3 bespoke hooks
  (Fifth Pulse +1 AP every 5th round @ player-turn-start, Nightgorge heal-on-
  kill @ combat_on_enemy_defeated, Bonelattice shield @ combat Create; all
  read equipped gear via dark_gift_total()). Gift affixes are marked
  `gift: true` and NEVER re-scale with later surges (their stamped line stays
  honest); duplicates can roll and stack. M: "lets try every 3rd and see."
- **CEREMONY SCENE (M 08-04 round 2) — art pending M approval**: cursed
  rebirth gets its own little window scene like the egg hatch - a spectral
  hand reaching out of a dark cauldron. PixelLab candidates generated 08-04
  (~25 gens); M picks/approves BEFORE wiring. Scene presentation: reuse the
  gc cursed_ritual_t ceremony timing, swap the code-drawn overlay for the
  approved scene sprite + reveal.
- **M's 08-04 notes, folded in:**
  - "An Inequivalent Exchange..." flavor line BUILT (card tag + picker prompt).
  - 3x+ SPIRAL ROOT CAUSE (found in code): re-feeding doubles ALL affixes -
    INCLUDING the curses already on the item - and adds a new curse. Negatives
    compound at 2x per feed AND accumulate; positives only get the 2x. After 3
    feeds the first curse is at 4x (-30% gold find -> -120%). Options for M:
    (a) keep as the natural god-mode brake, (b) curses NEVER re-double - they
    only accumulate one full-strength curse per feed, cost ladder is the brake
    (Claude recommends), (c) curses re-scale at x1.5 instead of x2.
  - RE-ATTUNE WIPE BUG: clone_item dropped req_stat/req_value, so a paid
    re-attunement vanished on cursed rebirth. FIXED 08-04 (clone carries all
    transform bookkeeping: req override, icon_seed, curse_count, cursed,
    splash_base).
  - Cost ladder numbers still to lock with M.

## 4. EMERGENT ICON VARIANTS (M 08-04) — BUILT

M saw cursed items change their icon: real, not a glitch - variant art is
picked by hashing the item's base_name (weapon buckets, rarity-banded armor
bands, rare-sword themes), and cursed rebirth renames the item, moving the
hash. Formalized 08-04: `ui_icon_item_key` mixes a SAVED per-item `icon_seed`
into every variant hash. Services that remake an item stamp a fresh seed —
re-attune + cursed rebirth wired now; tempering-to-100 and dormant awakening
should stamp one too when they build. Unseeded items never shift (no visual
churn on existing saves), and a given seed is stable forever - the remade look
is permanent, not per-session.

## Build order (after M locks numbers)

1. Tempering core (quality field + stat application + Maren service + tooltip).
2. Dormant legendaries (drop-side flag + awakening service).
3. Reassemblage cost ladder (after M's notes land).
Each phase is save-safe without a format bump (missing fields default: quality
100, dormant false, curse_count 0).
