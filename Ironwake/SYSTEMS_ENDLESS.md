# SYSTEMS_ENDLESS — Awakening Boost, A6+ Tiers, and THE DESCENT

**Status: DESIGN-LOCKED 2026-07-27** (M signed off via AskUserQuestion rounds;
courier events + hardcore added by M mid-session). Build same day.

---

## 1. Awakening boost popup ("the hybrid")

Per-dungeon ascendance ladders stay. NEW: when the player clears a dungeon at
its **highest unlocked tier** (a first-time progression clear), a popup after
the run summary lets them pick **ONE other dungeon** to raise by +1 awakening
unlock — with a celebratory animation + SFX (existing catalog only).

- Fires on FIRST-TIME tier clears only (re-farming a cleared tier grants no
  boost — that would undo the power-spike brake, M's pick).
- Boost caps at A5 pre-win. No eligible dungeon (all at/above) → no popup.
- Effect: distributes the "climb every ladder from A0" redundancy (min win path
  ~10 first-time clears instead of 18) while trailing dungeons stay near your
  power level. Migration: none needed — purely additive.

## 2. A6+ — unbounded awakening (post-win)

- After IRONWAKE STANDS, tiers continue past A5 with **propagating unlocks**:
  clearing A6 in ANY dungeon opens A7 in ALL dungeons (endless climbing must
  not be 3×-clear homework — M).
- Enemy scaling: compounding **+12% HP/damage per tier past 5** on top of the
  A5 values (`awaken_endless_mult`).
- Loot: rarity weights stay at the A5 anchors; **affix values scale** with the
  tier via the same item-level mechanism the Descent uses (§3), tagged on the
  item. XP/gold: +8%/tier past 5.
- Win state, A5 boss enrage, and all A0–A5 content untouched.

## 3. THE DESCENT (infinite mode)

Unlocks **after IRONWAKE STANDS** (per slot). Entry: dungeon-select screen.

- **Structure**: endless floors. Each floor draws a random dungeon theme
  (ashen/scorched/tundra — bg, music, enemy pool, floor passive) and plays as a
  normal floor DAG ending in a floor boss.
- **Scaling**: floor N runs at effective awakening `5 + N*0.5` fed through the
  same compounding formula as A6+, PLUS a stacking modifier ladder (every 3rd
  floor adds one: enemy affixes, elite auras, +enemy count...) — P2 if needed;
  compounding ships first.
- **Depthforged gear**: drops roll with `item_level = floor` — affix values
  scale past normal legendary caps; items past floor ~10 are tagged
  "Depthforged — Floor N" on the item card. FULL CARRY-OUT (M: breaking the
  base game post-win IS the trophy).
- **Push-your-luck banking**: after each floor boss: RETREAT (bank everything,
  deepest floor recorded) or DESCEND. Death loses the UNBANKED Depthforged loot
  found this descent; gold/XP follow normal death rules.
- **Courier events (M mid-session)**: descent events can offer to SEND ITEMS
  HOME mid-descent — 1 item usually, 2 sometimes, 3 on an ultra-rare roll —
  banking without retreating, so greed keeps its tension.
- **Hardcore toggle (M mid-session)**: chosen at descent start. Death can also
  claim EQUIPPED items — severity tiers roll the RNG selection (e.g. Hardcore:
  1 random equipped slot; Merciless: each equipped item 50/50). This gives the
  item-protection traits new endgame weight — **Salvager's "Nothing Wasted"
  Transcend (POTENCY V2) protects equipped items here.**
- Records: deepest floor per slot (slot sigil + dungeon-select), best banked
  haul.

## 4. BUILD RECORD (2026-07-27, same day — awaiting F5)

- **Boost popup**: earned at the ascendance ratchet (scr_stats end_run victory
  path → `awaken_boost_pending`/`awaken_boost_from`, saved); shown by
  obj_hub_controller on hub arrival (ending sequence outranks it) — modal
  "THE AWAKENING SPREADS" with pulsing-ring animation, card pick (W/S/A/D +
  Enter + tap, second-tap confirms), celebration banner after; `awaken_boost_options()`.
- **A6+**: `awaken_endless_mult` (+12%/tier compounding) folded into
  awaken_hp/dmg/heal mults; XP +8%/tier; acc +2/tier; clear gold +60/tier;
  `endless_awakening_unlocked` (saved) ratchets on post-win frontier clears;
  `dungeon_max_ascendance()` is the single selection-cap source (hub select
  Step+Draw all route through it); effects-panel table windows past A5;
  `awakening_label` shows "Beyond Infernal".
- **Item scaling**: `item_empower` in drop_equipment (both paths): +6%/tier
  compounding on stat_value / weapon_damage / affix magnitudes past effective
  A5; Descent drops add "[Depthforged - Floor N]" name tag + depth_floor field.
  NOTE: Dorn's stock also empowers if the last selected run was A6+ — accepted
  (shop already grows with awakening).
- **THE DESCENT**: armed on the dungeon-select screen ([V] + banner tap,
  [G]/chip cycles severity STANDARD/HARDCORE/MERCILESS; post-win only; banner
  shows deepest-floor record). Confirm starts floor 1 at A5.5 with a random
  theme. Every floor boss opens the (reworded) retreat/descend popup — the
  full-clear-at-floor-3 branch is skipped; DESCEND rerolls the dungeon theme
  and sets `selected_ascendance = 5 + floor*0.5` (ALL downstream systems read
  that one value). RETREAT = the existing extraction banking. Death: normal
  rules + hardcore equipped-loss in end_run (severity 1: one random worn slot;
  2: each worn item 50/50; Salvager's "Nothing Wasted" Transcend protects all).
  Courier: 35% of Descent event rooms become a SPECTRAL COURIER — 1/2/3
  (70/25/5) sends via the shared picker purpose `courier`, Esc departs early,
  result shown on the event popup. `descent_best` + `descent_hardcore` saved;
  descent state cleared in run_state_reset/end_run/load.
- **DEFERRED to P2**: the every-3rd-floor stacking modifier ladder (§3) —
  compounding + theme rotation + floor passives carry difficulty for now.
- Reference Sync: compendium gained "Awakening Boost", "Beyond Infernal (A6+)",
  "The Descent" entries.

## 5. ENDLESS RUNE ECONOMY (built 2026-07-27 night, same F5 batch)

M: "we need more than just I and II for rune forges... combine them up much
higher for the descent dungeons and just something to do with so many leftover
runes." Locked via AskUserQuestion (unbounded post-win; distributed-NPC sink was
M's own counter-design: "distribute items across multiple npcs instead of
bottlenecking each").

- **Unbounded tiers (post-win)**: Maren's combine loses its tier-III source cap
  when IRONWAKE STANDS (`rune_combine_tier_cap`, same gate as A6+/Descent).
  Values: tiers IV+ compound +40%/tier on the authored tier-III value, min +1
  per tier (`rune_value`). Costs double per step from III->IV = 400g + 60 dust
  (`rune_combine_cost`); split refunds and Sable salvage scale to match
  (`rune_split_dust`, `sable_salvage_rune_dust`). Roman numerals now generic
  (`rune_tier_roman`). Drops still roll I-III only - higher tiers are forged.
- **Sable TRANSMUTE (gamble sink)**: Salvage tab gained a third verb - pick any
  3 SAME-TIER runes (mixed types = the junk drain) -> 1 RANDOM rune of the next
  tier, fee 60g x tier (CHA-discounted). Multi-pick UI w/ teal rings, two-step
  confirm. Result pool = catalog minus flagships (`rune_blueprint_pool`).
  Respects the same post-win cap.
- **Petra BLUEPRINTS (planned sink)**: trade tab gained a mode toggle ([R] +
  chip). Pick 5 SAME-TIER runes -> choose ANY catalog rune as a blueprint ->
  async order (80g x tier, ready in 3 floor clears, Companion -1) sharing the
  single `petra_order` slot via `kind:"rune"` (collect/cancel/status all
  branch; cancel recovers random runes of the tier, band unchanged).
- Reference Sync: compendium "Endless Runes (IV+)" + "Rune Transmute &
  Blueprints" entries; Maren combine breadcrumb states the cap/unlock.

## 5b. Same-night UI batch (M's standing rule born tonight)

M: "prioritize making anything with abundant information or lists scrollable
with a vertical scroll bar... we are working off too much text on screen and
less ui/visual communication" + an accidental one-click legendary reroll at
Dorn. Rule recorded in CLAUDE_SETTINGS.md ("Scrollable Overflow + Visual-First
UI") and memory.

- **Dorn reforge two-step screen**: list Enter/second-tap opens a confirm card
  (item + stats + ingot cost) -> COMMIT plays snd_forge + code-drawn spark/ring
  forge animation over a veiled "?" card -> reveal (snd_confirm_major) shows the
  reworked item beside the BEFORE snapshot. reforge_stage 0-3 in gc Step;
  ui_draw_reforge_confirm; tab/[R] locked while staged.
- **Petra visual/touch pass**: gear rows tappable (petra:gearrow), PLACE ORDER
  button when 3 chosen, popup lever rows tappable + CONFIRM button (popup
  heightened 795->850), READY card got pulse ring + tappable COLLECT +
  snd_confirm_major.
- **Bairc feed pouch scroll fix**: pages were hard-coded 6-wide while the
  squeezed box fit fewer rows ("+2 more in the pouch" unreachable). Draw
  measures capacity -> _gc.bairc_feed_vis, Step pages/hotkeys read it, visible
  scrollbar track+thumb added, out-of-window number keys dropped.
- **Checkout popups (M's follow-up, same night)**: the inline bottom-line
  confirm let Enter deselect the very rune it was committing (transmute bug).
  New shared `ui_draw_checkout_confirm()` = bordered overlay popup with
  CONFIRM/CANCEL buttons + a MODAL Step state; Sable's salvage-gear /
  scrap-rune / transmute confirms and Petra's blueprint order all route through
  it. STANDING RULE: every store/shop/trainer checkout confirms via this popup,
  never bottom text (CLAUDE_SETTINGS.md "Scrollable Overflow + Visual-First UI" #5).
- **Hub manual save**: pause menu (Esc) gains a "Save Game" row AT THE HUB ONLY
  (saves stay hub-gated; M: chore sessions shouldn't need a run to bank).
  pause_menu_options() is the single row source for Step + Draw; "Game saved."
  flash + snd_ui_confirm.

## 4b. Decision log (2026-07-27)

- Hybrid boost popup over strict lockstep / propagating unlocks — M ("a bit of
  a hybrid... popup prompt after completing a full dungeon run with a fun
  little animation and sound effect").
- First-time-clears-only earning — M (recommended).
- Descent gated behind the win — M (recommended; at first-A5 the other
  dungeons may trail at ~A3 and Depthforged gear would trivialize them).
- A6+ relaxes to propagating unlocks post-win — M (recommended).
- Both A6+ AND the Descent; Descent is the star — M.
- Full carry-out Depthforged, push-your-luck banking — M (recommended).
- Courier events (1/2/3-ultra-rare) + hardcore equipped-loss option — M's own
  additions, quoted in task #10.
