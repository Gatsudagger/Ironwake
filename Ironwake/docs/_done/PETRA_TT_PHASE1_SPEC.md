# Phase 1 — Petra Treasure Trader v1 (implementation mini-spec)

**Parent design:** `Petra_Treasure_Trader_Design.md` (this is the buildable v1 subset = doc §12 cut line).
**Build phase:** 1 (after Phase 0.5 thin-affinity). **Builds the two SHARED primitives** both Petra and Pets consume. See `BUILD_ORDER.md`.
**Design-lock:** numbers are placeholder/TUNABLE; agree §-open-questions with M before `.gml`.
**Status:** **GML WRITTEN 2026-06-29 — needs M's F5 (not compile-tested).** `.gml`-only, uncommitted. Files: `scr_stats.gml` (full Petra block after the affinity block: ladder/order lifecycle/floor_clear_credit/make-item/affinity perks), `obj_game_controller/Create` (petra_order init + 4 petra_trade_* tab vars), `scr_save.gml` (save/new_game_reset/load), `obj_combat_controller/Draw_64.gml` (floor-clear hook at boss-clear), `obj_game_controller/Step_0.gml` (Q/E 3-tab cycle + Treasure Trader input block), `scr_ui.gml` (TRADE tab button + trade-tab content draw). UI = 3rd "TRADE" tab on Petra's shop. **Item selection reworked 2026-06-29 from auto-pick to a real MULTI-SELECT** (per M): browse the stash list (W/S), Enter toggles an item into the trade (max 3, same-tier enforced), Tab = roll-bias, Space = place→preview→confirm; selection clears on tab-switch (stale-index guard). `petra_place_order` now takes the chosen stash indices; `petra_consume_indices` replaces the old auto-pick. Note: order progress persists in-memory + saves on next hub-gated save (no mid-combat save). Also: NPC-screen bond readout moved to title row (90,45) for spacing.

**Goal:** ship Petra's async gear-laundering loop — give 3 same-tier items, earn 1 of the next tier up by clearing floors — and lay the floor-clear-banking hook + cross-run persistence layer for Pets to reuse.

---

## 1. Shared primitive #1 — floor-clear banking hook

**Run structure (confirmed in code):** a run = **3 floors**, each ending in a boss. On a boss-clear (`obj_combat_controller/Draw_64` ~line 1053, where `global.just_cleared_boss` is confirmed true): floor 3 → `end_run(1)` (full clear); floors 1–2 → boss-extract popup (Extract `end_run(0)` / Continue `current_floor++`).

**Fire-point:** at that line 1053, **before** the victory/popup branch, call:
```
floor_clear_credit(global.selected_ascendance);   // one floor completed, at this awakening
```
- Fires **once per floor cleared**, regardless of what the player does next (extract / continue / later death) → **partial progress banks**; "even a failed run advances the order."
- Generic, multi-consumer: in Phase 1 it credits the active Petra order; Phase 2 adds the active-pet Stage credit in the same function (pets may weight clear/extract > death — Petra does not).

**Petra credit rule inside `floor_clear_credit(awk)`:**
```
if (global.petra_order != undefined && global.petra_order.status == "in_progress") {
    if (awk >= global.petra_order.req_awakening) {           // per-floor Awakening gate
        global.petra_order.progress_floors += 1;
        if (progress_floors >= cost_floors) status = "ready"; // completed; waits at Petra
    }
    // floors below the order's required awakening DON'T count (anti-cheese)
}
```

---

## 2. Shared primitive #2 — cross-run persistent order

`global.petra_order` — struct or `undefined` (no open order). **Meta-persistent: NOT reset in `end_run`** (model on `global.equipment_stash`). Saved/loaded in `scr_save` (guarded for old saves → `undefined`).

```
global.petra_order = {
    input_tier:      "common",      // tier of the 3 consumed inputs
    output_tier:     "uncommon",    // next tier up (the eventual reward)
    req_awakening:   0,             // per-floor Awakening gate
    cost_floors:     1,             // total floor-clears needed (AFTER affinity speedup)
    progress_floors: 0,             // banked credited floor-clears
    dust_bias:       false,         // Lever A applied at placement
    status:          "in_progress"  // "in_progress" -> "ready" (collect) 
};
```
- **One order at a time** (v1). Completed order sits at `status:"ready"`; player must **collect before placing a new one**.

---

## 3. The ladder (v1 = 4 rungs, denominated in floor-clears)

| Input (3× same tier) | Output (1×) | cost_floors | req_awakening | gold cost |
|---|---|---|---|---|
| Common | Uncommon | 1 | 0 | 25 |
| Uncommon | Rare | 3 (1 run) | 0 | 75 |
| Rare | Epic | 6 (2 runs) | 2 | 200 |
| Epic | **Legendary** | 6 (2 runs) | 3 | 500 |

- **Top rung = Epic→Legendary** (you *can* craft Legendaries in v1). The **Legendary-INPUT branch (reroll + Cursed Unique) is HELD for later** (cut line §12; cursed items are net-new/undesigned anyway).
- **Inputs:** any 3 of the same tier (item *type* ignored). **Affixes on inputs are destroyed** (told to player up front). Inputs **consumed on placement**, not completion.
- **No tier-skipping** — always N→N+1.
- **Scaling gold cost** (M override 2026-06-29 — supersedes the parent doc's "no gold"): charged **at placement** alongside the item consumption. Scales with output tier (placeholder **25 / 75 / 200 / 500**, TUNABLE). Insufficient gold → placement blocked in the preview. So the v1 price = **3 items + scaling gold + time (floor-clears) + optional dust**. **Gold is sunk on placement** (not refunded on cancel — that's the commitment teeth; cancel still recovers items per §5). The Friend discount reduces this gold cost (see §6 / Q3-followup).

---

## 4. Lever A — dust roll-bias (the only lever in v1)

- Optional at placement: spend **magic dust** to bias the output's affix-value rolls upward. **Resource-only, no added time cost.** Guarantees nothing.
- Sets `dust_bias = true`; on completion each affix magnitude is rolled via **take-higher-of-two** (LOCKED 2026-06-29): roll the value twice, keep the higher, still clamped to the tier cap (no overroll — that's a held v1.1 feature).
- **Dust cost scales with output tier** (placeholder): Uncommon 5 · Rare 10 · Epic 20 · Legendary 40.
- OUT in v1: Lever B (directed affix), Lever C (slot lock), jackpot overroll, pity.

---

## 5. Flow: place → earn → collect

1. **Open Petra → Treasure Trader** (new mode on her hub screen, beside her consumables shop).
2. **Pick 3 same-tier items** from stash (reuse stash list rendering + the shared item-picker selection pattern, [[project_item_picker]]).
3. **No-takeback preview modal:** output tier, full `cost_floors` + `req_awakening`, dust cost if Lever A toggled, "inputs & their affixes will be destroyed." Confirm / cancel. **No blind commits.**
4. On confirm: consume the 3 inputs, build `global.petra_order`, save.
5. **Earn:** each qualifying floor-clear ticks `progress_floors` (via §1). Status panel shows `progress_floors / cost_floors` + the awakening gate.
6. On completion `status:"ready"` → the output item waits at Petra; **collect** (rolls the output item + affixes, applies dust bias) → goes to stash. Order cleared; can place anew.

### Cancel (anti-softlock)
- Cancel an `in_progress` order → recover some inputs (clean base items of the input tier; affixes already gone). **Gold is NOT refunded** (sunk at placement).
- **Recovery = affinity-tier-stepped** (LOCKED 2026-06-29): RNG within band by Petra tier — pre-Friend **0–1**, Friend **0–1**, Companion **1–2**, Lover **2–3** inputs recovered. Reads `affinity_tier("petra")`.

---

## 6. Affinity perk integration (reads Phase-0.5 thin-affinity API)

Petra calls `affinity_at_least("petra", tier)`:
- **Friend (≥2):** **−10% on Petra's gold costs** — the trade gold fee (§3) and her consumable-shop prices (LOCKED 2026-06-29). Dust lever cost stays a pure resource sink (excluded).
- **Companion (≥3):** **faster delivery** (reduce `cost_floors`, placeholder −1 floor min 1) + **better cancel recovery** (1–2 band). **2nd order slot HELD** for v1.1 (LOCKED — v1 stays single-order).
- **Lover (4):** **Recipe Insight** = no-op in v1 (no cursed recipes yet) + **best cancel recovery** (2–3 band).

---

## 7. UI

- Petra hub screen: a **Treasure Trader** sub-mode (toggle from her consumables shop) — universal control scheme (W/S nav, Q/E mode/tab, Enter select, Space confirm, Esc back).
- **No order:** input-picker (stash list, pick 3 same-tier) + lever toggle + "[Preview order]".
- **Order in progress:** status card — output tier, `progress_floors / cost_floors`, awakening gate, "[Cancel]".
- **Order ready:** "Petra has something for you — [Collect]".
- Preview + cancel reuse the existing hub confirm-modal pattern.

---

## 8. Code seams (where the `.gml` lands)

| Concern | Seam |
|---|---|
| `global.petra_order` init (= `undefined`) | `obj_game_controller/Create` (guarded) |
| **Floor-clear hook** `floor_clear_credit(awk)` | **new fn in `scr_stats`**, **called from `obj_combat_controller/Draw_64` ~1053** (boss-clear, before the victory/popup branch) |
| Ladder, costs, place/cancel/collect, roll, helpers | **new fns in `scr_stats`** (`petra_ladder`, `petra_place_order` [consumes 3 items + deducts gold via `add_gold(-cost)` after Friend-discount], `petra_cancel_order`, `petra_collect`, `petra_order_status_text`) — keeps to `.gml`-only (no new asset) |
| Lever A bias on roll | inside `petra_collect`, bias the existing `roll_affixes` path |
| Persistence | `scr_save` — serialize/restore `global.petra_order` with the meta globals (guarded) |
| `end_run` | **no change** — order persists by design (only confirm it's NOT cleared) |
| Petra TT UI + input | `obj_hub_controller/Step` + `Draw_64` (Petra branch) |
| Affinity reads | `affinity_at_least("petra", …)` from Phase 0.5 |
| Affinity drip on order placement | `petra_place_order` calls `affinity_add("petra", 4)` (per Phase-0.5 §2) |

---

## 9. Decisions (M, 2026-06-29) + remaining

**Resolved / locked:**
1. **2nd order slot — HELD for v1.1.** v1 stays strictly single-order. Companion perk = faster delivery + better cancel only.
2. **Cancel recovery — affinity-tier-stepped now** (pre-Friend 0–1 / Friend 0–1 / Companion 1–2 / Lover 2–3).
3. **Scaling gold cost added** (M override): trade costs gold (placeholder 25/75/200/500 by output tier), charged at placement, sunk on cancel. Price = 3 items + gold + time + optional dust.
4. **Ladder top rung = Epic→Legendary** (Legendary-INPUT reroll/cursed branch held). **Floor-clear credits at boss-clear, 3 floors/run, banked immediately** (extract & death keep cleared floors), per-floor Awakening-gated.

**Also locked 2026-06-29:**
- **Friend-discount coverage** = trade gold fee + consumable-shop prices (−10%); dust excluded.
- **Lever A bias** = take-higher-of-two; dust costs 5/10/20/40 by output tier.

**Tuning only (curve locked for build, values playtest-tunable):** gold curve 25/75/200/500, discount 10%, faster-delivery −1 floor, drip/threshold values from Phase 0.5.

→ **No open blockers.** Build order: Phase 0.5 `.gml` first (Petra reads its affinity API), then Phase 1 `.gml` per §8.
