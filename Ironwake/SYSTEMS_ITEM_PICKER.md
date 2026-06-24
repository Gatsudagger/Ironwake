# Item Sacrifice Picker — shared select+confirm modal — BUILT 2026-06-23 (verify in-IDE)

## Build summary
- **New global modal** `global.item_picker` (init in `obj_game_controller/Create_0`).
- **Picker module appended to `scr_stats.gml`:** `item_picker_open/close`,
  `item_picker_candidates_by_rarity/by_tribute`, `item_picker_remove_selected`,
  `item_picker_prompt/verb`, `item_picker_resolve`, `item_picker_step`.
- **Draw `ui_draw_item_picker()` appended to `scr_ui.gml`** (centered modal, rarity-colored
  list, armed red confirm bar). Drawn topmost in `obj_hub_controller/Draw_64` (Vex) and
  `obj_floor_controller/Draw_64` (Shrine).
- **Vex Tab 0 (stat) + Tab 3 (trait)** now `item_picker_open(...)` instead of auto-consuming.
- **Shrine** item-tribute path opens the picker (gold/dust paths unchanged).
- **Sable** keeps its list + got a `sable_confirm` arm (option B) — shows dust payout, Esc backs out.
- **Persistence guard:** game_controller drives only `vex_*` purposes, floor_controller only
  `shrine_boon`, so the persistent game_controller doesn't double-step the Shrine picker.
- Old auto-pick helpers (`trainer_consume_item/rare_item`, `boon_item_tribute_pick`,
  `boon_pay` "item" branch) are now unused but left in place. NOT compile-tested.

---

# Item Sacrifice Picker — shared select+confirm modal — DESIGN-LOCK (M approved 2026-06-23)

## Problem
Three systems destroy a player item with **no selection** (auto-pick the least-valuable
qualifying item), and one lets you pick but never confirms. Players lose items by mistake.

| Site | Current code | Issue |
|---|---|---|
| Vex Tab 3 — Trait unlock | `obj_game_controller/Step_0.gml:628` `trainer_consume_item()` | auto-pick, no select, no confirm |
| Vex Tab 0 — Stat upgrade | `obj_game_controller/Step_0.gml:567` `trainer_consume_rare_item()` | auto-pick, no select, no confirm |
| Shrine boon tribute (item) | `obj_floor_controller/Step_0.gml:307` via `boon_item_tribute_pick()` (`scr_stats.gml:1958`) | auto-pick, no select, no confirm |
| Sable salvage (Gear / Runes) | `obj_game_controller/Step_0.gml:941-957` | picks exact item (good) but no confirm |

## M decisions (approved 2026-06-23)
- **Shared picker for ALL sites** (one reusable select+confirm modal; not per-site patches).
- **Sable salvage also gets a confirm step.**

---

## Constraint
Cannot create new script/object resources (`.yy`/`.yyp` are IDE-only). All new functions
live in **existing** scripts; modal state is a **global struct** initialized in
`obj_game_controller/Create_0.gml`.

---

## 1. State (global struct) — `obj_game_controller/Create_0.gml`
Add near the other global inits (guarded with `variable_global_exists`):
```gml
if (!variable_global_exists("item_picker")) global.item_picker = {
    open:       false,
    purpose:    "",     // "vex_trait" | "vex_stat" | "shrine_boon" | "sable_gear" | "sable_rune"
    context:    {},     // purpose-specific payload (trait struct / boon id / gold cost / list ref)
    candidates: [],     // [{ source, idx, item, label, rarity, value }]
    cursor:     0,
    scroll:     0,
    confirm:    false   // an item is selected, awaiting yes/no
};
```
A global (not per-controller) lets the same modal serve the hub (`obj_game_controller`) and
the dungeon (`obj_floor_controller`).

## 2. Logic helpers — append to `scr_stats.gml`
- `item_picker_open(purpose, context, candidates)` — sets state, `open=true`, resets cursor/scroll/confirm.
- `item_picker_close()` — `open=false`, clears confirm.
- `item_picker_candidates_by_rarity(min_rarity)` — returns the **full list** (not just one) of
  qualifying items across stash+pack: `[{source,idx,item,label,rarity,value}]`, sorted
  rarity↑ then value↑ (cursor defaults to least-valuable, but every item is selectable).
  *Generalizes the existing `trainer_find_item` scan.*
- `item_picker_candidates_by_tribute(cost)` — same shape, filtered to items whose
  `item_tribute_value(rarity) >= cost` (generalizes `boon_item_tribute_pick`).
- `item_picker_resolve()` — the single commit point. Reads `purpose`, removes the **selected**
  candidate (by source+idx), then performs the purpose's effect:
  - `vex_trait` → deduct `context.gold`, set `traits_unlocked[context.effect_id]=true`, `save_game()`, notify.
  - `vex_stat`  → deduct `context.gold`, `+1` to `context.stat_key`, `save_game()`, notify.
  - `shrine_boon` → grant `context.boon_id` (reuse existing boon-grant path), notify.
  - `sable_gear` / `sable_rune` → run existing salvage-at-index for the chosen item.
  - Always `item_picker_close()` at the end.
  - NOTE: indices can shift if stash changed; resolve removes by matching the stored
    candidate struct, and re-reads source arrays defensively.

## 3. Input — shared `item_picker_step()` (append to `scr_stats.gml`)
Returns `true` if it consumed input (caller then skips its own input that frame).
- Up/Down (W/S + arrows): move `cursor` over `candidates`, update `scroll` window (8 rows,
  reuse `loadout_list_scroll`). Clears `confirm` on move.
- Enter/Space:
  - if `!confirm` → set `confirm=true` (arm the "are you sure").
  - if `confirm` → `item_picker_resolve()`.
- Esc / right-click: if `confirm` → just clear confirm; else `item_picker_close()` (cancel, no loss).
- Mouse: row click selects; clicking the armed confirm bar commits.

**Wiring:** at the TOP of `obj_game_controller/Step_0.gml` and `obj_floor_controller/Step_0.gml`
input sections: `if (global.item_picker.open) { item_picker_step(); exit; }` so the modal
captures input and the underlying screen is frozen.

## 4. Draw — `ui_draw_item_picker()` (append to `scr_ui.gml`)
Centered modal panel over a dimmed backdrop. Header = purpose-specific prompt
("Trade an item to Vex", "Sacrifice an item for the boon", "Salvage which item?"). Body =
windowed list (8 rows, ▲older/▼newer-style scroll hints, rarity-colored names + value).
Footer:
- not armed: "Enter: select  ·  Esc: cancel"
- armed (`confirm`): a highlighted bar — **"Trade away `<name>`? This cannot be undone.   Enter: confirm · Esc: back"**

**Wiring:** call `if (global.item_picker.open) ui_draw_item_picker();` at the END of the draw
in `scr_ui` trainer/sable draws AND `obj_floor_controller/Draw_64.gml`, so it layers on top.

## 5. Replace the auto-pick call sites
- **Vex Tab 3** (`Step_0.gml:613-635`): replace the `trainer_consume_item` branch — when gold
  ok & a qualifying item exists, call `item_picker_open("vex_trait", {gold, effect_id, name}, item_picker_candidates_by_rarity(min_rarity))` instead of consuming.
- **Vex Tab 0** (`Step_0.gml:556-573`): same, `purpose:"vex_stat"`, context `{gold, stat_key, stat_name}`.
- **Shrine** (`obj_floor_controller/Step_0.gml` item-tribute branch): replace `boon_item_tribute_pick`
  consume with `item_picker_open("shrine_boon", {boon_id, cost}, item_picker_candidates_by_tribute(cost))`.
- **Sable Gear/Rune** (`Step_0.gml:941-957`): keep the existing list selection; add a
  `sable_confirm` arm before salvaging (see §6). Does NOT use the shared picker.

## 6. Sable confirm — DECIDED: option B (M approved 2026-06-23)
Keep Sable's existing salvage list (it already shows each item + dust payout) and add a
lightweight `sable_confirm` gate:
- First Enter/Space on a gear/rune row → arm `sable_confirm = true` + set notification
  "Salvage `<name>` for `<dust>` dust? Enter: confirm · Esc: back".
- Second Enter/Space while armed → run the existing `sable_salvage_gear_at/rune_at`.
- Esc / moving the cursor / changing phase or tab → clears `sable_confirm` (no salvage).
- Add `sable_confirm` to `obj_game_controller/Create_0` inits and draw the armed prompt in
  the Sable draw. Sable does NOT use the shared `global.item_picker`.

## 7. Out of scope
Alchemical Rebirth (not built; will reuse `item_picker_open("alch_rebirth", …)` when built).
Sable Brew/Upgrade (fixed recipes, not arbitrary loss). Salvage VFX/SFX is a separate task.

## 8. Test
- Vex trait & stat trades open the picker, list every qualifying item, cancel loses nothing,
  confirm removes only the selected item + deducts gold.
- Shrine item tribute opens picker; cancel returns to shrine with item intact.
- Sable salvage shows a confirm; Esc backs out without salvaging.
- Esc/right-click at any stage never destroys an item.
