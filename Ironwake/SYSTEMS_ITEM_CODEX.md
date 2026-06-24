# SYSTEMS — Item Codex

**Status: BUILT (verify in-IDE). Splash art COMPLETE — all 62 base items.**
The hub Item Codex (`G`) is a reference for every base equipment item: what it is, what
it rewards, how it can roll, and its lore. Left = scrollable master list (discovered vs `???`),
right = detail pane.

---

## 1. Discovery tracking (FIXED)
**Bug:** affixes mutate `item.name` ("Iron Sword" → "Sharp Iron Sword of the Bear"), and
discovery recorded the *mutated* name, which never matched the base loot-table entry — so
nothing above Common ever showed as discovered.
**Fix:** every item carries an immutable `base_name` (set in `create_item`, preserved by
`clone_item`, untouched by `apply_affixes_to_item`). `item_base_name(item)` returns it; all
discovery sites (`drop_equipment`, `handle_enemy_drops`, treasure/reliquary in floor Step,
Dorn purchase, legendaries) call `discover_item(item_base_name(...))`. The codex matches base
names on both sides. (Old saves keep stale affixed entries; they re-register on next drop.)

## 2. Lore + descriptions
- **Legendaries:** hand-written `lore` field (2–3 sentences) on each of the 4 legendaries in
  obj_game_controller Create. Shown in the detail pane in gold.
- **Everything else:** auto-generated generic description via `item_generic_desc(item)`
  (scr_stats) — derived from slot + primary stat archetype (no per-item authoring). The
  item's existing one-line `effect_desc` still shows as flavor when present.

## 3. RNG stat ranges
`item_stat_ranges_text(base_item)` (scr_stats) returns reference lines:
- Base primary stat is **fixed** per item (`stat_value`) — shown as "STR +4 (base)".
- Affixes are rolled at drop time. Count by rarity: Common 0 · Uncommon 1 · Rare 1–2 ·
  Epic 2 (epic draws from the rare base table). Affix values per tier come from
  `global.affix_pool` (u_val/r_val/e_val). The text lists how many affixes each tier rolls
  and the per-tier bonus magnitudes, so players can judge an item's ceiling.
- A base item only appears at the tiers its table allows (Common base = no affixes ever;
  Rare base = Rare or Epic), so the text is scoped to that item's reachable tiers.

## 4. Splash art
- `item_splash_sprite(base_name)` (scr_ui) maps a base item → its `spr_item_art_*` sprite,
  returning -1 until that art exists. The detail pane draws the splash sprite when present,
  otherwise **falls back to the scaled item icon** (`ui_draw_item_icon`) so the pane is never
  empty. This lets art land incrementally without code changes beyond the lookup table.
- **Art: DONE.** PixelLab splash art generated for ALL 62 base items (24 common, 17 uncommon,
  17 rare, 4 legendary), 128×128 transparent PNGs, `view=side`. Sprites at
  `sprites/spr_item_art_<snake_base_name>/`, registered in the .yyp, all wired into the
  `item_splash_sprite` switch. Generated via `tools/gen_item_art.py` (downloads a PixelLab
  map-object by id with retry, writes the frame+layer PNG + .yy, registers in .yyp, accumulates
  switch cases) — reusable for future items. PixelLab rate-limits to ~4 concurrent generations,
  so it was done in rounds of 4.

## 5. Detail pane layout (redesigned)
Top: splash art (or scaled icon) in a framed box · name (rarity color) · RARITY • SLOT.
Body: lore (legendary, gold) OR generic description; `effect_desc` flavor; base stat;
stat-range reference block; affixes (for the shown base, if any); unique effect (legendary).
Footer: value + close hint.

## 6. Deferred / future
- Per-item hand-written lore beyond legendaries (currently auto-generic).
- "New!" badge on items discovered since last codex open.
- Re-roll any splash arts that read poorly in-game (swap the PNG in the sprite folder, same dims).
