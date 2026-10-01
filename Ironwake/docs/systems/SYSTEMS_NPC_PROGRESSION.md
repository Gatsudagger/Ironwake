# SYSTEMS — NPC STATION PROGRESSION ("Both, layered")

M design-locked 08-15. Two parallel tracks per camp keeper:

1. **BOND** (existing affinity tiers, Stranger → Friend → Companion → Lover):
   earned through use, gated by favors at gates. Grants the per-NPC bond perks
   plus a generic service discount: `npc_bond_discount(id)` = 5% (Friend) /
   10% (Companion) / 15% (Lover).
2. **STATION RANKS** (this system): the keeper's WORKSHOP is upgraded with
   gold + rune dust, independent of friendship. Two ranks per NPC.

## Mechanics

- State: `global.npc_ranks` struct (`npc_ranks_ensure()`), persisted in the
  save (scr_save, 3 sites: save/load/new_game).
- Read: `npc_rank(id)` → 0/1/2.
- Costs: `npc_rank_cost(rank)` — rank 1 = 300g + 20 dust, rank 2 = 900g + 60 dust.
- Buy: `npc_rank_buy(id)` — from the hub carousel card. The card carries only
  a small **STATION** chip (2 rank pips) pinned in its top-right corner; rank details are
  HOVER-ONLY (`npc_rank_card_tip`, via `ui_tab_hover_stash`). **[U]** or a tap
  on the chip opens the standard checkout popup (`ui_draw_checkout_confirm`,
  hub Step 0a3 modal while `npc_upgrade_arm` is set; the result lands in the
  bond dialog). Gamepad has no free hub button for [U] yet (known gap).
- Onboarding: `station_ranks` coach-mark (tutorial_catalog) fires once on the
  first camp arrival after a run (`run_count >= 1`, hub tip seen, no NPC screen
  open) - hub Step poll beside the bond_gates / corruption tips. Reset Tutorial
  re-arms it like every other tip.
- Price helper: `npc_service_price(id, base)` folds bond discount + rank
  multipliers for sable/vex/vael services. (Vex and Vael route through their
  own wrappers — see below — because they already carry bond discounts.)

## Perks (all WIRED as of 08-15 late session)

| NPC   | Rank 1                                        | Rank 2 |
|-------|-----------------------------------------------|--------|
| Dorn  | Widened Stall — +2 stock pieces               | Master Anvil — temper steps +12% quality |
| Maren | Etching Bench — combine dust −20%             | Deep Socket — [D] Socket Gear tab: +1 socket into an equipped piece, 400g+80 dust, once per RUN, once EVER per item (`item.deep_socketed`, `global.deep_socket_used` reset in end_run) |
| Sable | Second Cauldron — brews −10% (brew catalog only) | Sealed Reserve — Chaotic Brew downsides HALVED (combat bite div 2, sluggish 50% skip, camp spill 15g→8g) |
| Vex   | Sparring Yard — ability/trait unlocks −10% (`vex_price(g,"learn")`) | Drill Regimen — FIRST purchase each visit −25% (`global.vex_visit_first` armed on trainer open, consumed via `vex_first_buy_consume()` at every gold commit; discount shows on all price tags until spent) |
| Petra | Second Ledger Line — TWO simultaneous trade orders (`global.petra_orders` array, capacity `petra_order_capacity()`); special shelf never empty + qty 2-3 | Favored Client — delivery −1 floor (stacks with Companion), traded goods re-stamp quality 75-95, selling +10% |
| Vael  | Atelier — tints/skins −20% (`vael_cosmetic_price()`, all 5 display/charge sites) | Private Gallery — one free portrait change per run (`global.vael_portrait_free`, armed in end_run, consumed at the portrait tab; Companion tier makes all changes free anyway) |
| Bairc | Warm Pens — roster hunger drains ×0.70 (base drain raised 20/10→28/14) | Night Garden — garden blessing ×1.5 (cap +10% → +15% feed growth) |

## Petra two-order refactor (08-15)

`global.petra_order` (single struct) → `global.petra_orders` (array).
- `petra_orders_ensure()` migrates legacy saves idempotently; save writes BOTH
  keys (legacy usually undefined post-migration).
- `petra_order_is_rune(order)` now takes the order struct.
- `petra_cancel_order(idx=-1)` cancels the NEWEST by default.
- `petra_collect()` collects the FIRST ready order.
- `floor_clear_credit` advances EVERY in-progress order (each keeps its own
  Awakening gate).
- TRADE tab UI: "ledger view" (stacked status cards, COLLECT on first ready,
  PLACE ANOTHER ORDER button when capacity remains → `gc.petra_place_more`
  flips to the classic trade UI; Esc returns to the ledger).

## Interplay notes

- Bond discounts and station discounts STACK multiplicatively (e.g. Vex Lover
  + rank 1 + first-buy = 0.85 × 0.90 × 0.75 of CHA-discounted price).
- Deep Socket + Dorn REWORK: rework rerolls affixes and does not touch
  socket_count — a deepened item keeps its socket.
- `clone_item` carries `deep_socketed` presence-conditionally.
