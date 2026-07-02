# Petra the Merchant — Treasure Trader Function

**Status:** Final draft (workshopped) — numbers are placeholder, pending tuning pass
**Build phase:** **Phase 1** (first feature built, after the Phase-0.5 thin-affinity scaffold). Ships the shared floor-clear-banking hook + cross-run persistence layer. v1 = exact cut line (§12). See `BUILD_ORDER.md`.
**System owner:** Vendor / meta-progression
**Depends on:** Tier ladder, affix system (rarity-scaled, 0–2 affixes), magic dust + rune economy, floor-clear / boss-kill tracking, cursed-item framework (§0 — reconcile w/ GDD), **NPC Affinity system** (Petra's perks + cancel-recovery odds + discounts; see that doc), **Journal system** (Quests tab surfaces her gate quests + recipe hunts; Relationships tab shows her profile/ledger)

---

## 0. Reconciliation notes (READ FIRST)

- **Cursed items DO NOT exist yet** (corrected 2026-06-29 against the live build; the "GDD" is `Ironwake_GDD_v1.docx`, a stale Word doc — the living spec is the `SYSTEMS_*.md` files + code). The only "curse" system Ironwake has is the run-scoped **"devil's bargain"** (`SYSTEMS_CURSES.md` / `curse_catalog()` in `scr_stats`): accept a run-long penalty at a Shrine *Curse altar* for a run-long loot/gold/dust boost. That is **not** an item-level system. **"Cursed Unique" gear (§6/§7) is net-new and undesigned.** Per M (2026-06-29) it is to be its **own separate item framework with bespoke per-item drawbacks** — NOT a reuse of the run-curse penalty vocabulary. Working definition until that framework is designed: *high-power items with a real, unique drawback, obtainable ONLY through Petra, never as dungeon drops.* Do not conflate with run-curses.
- **NPC Affinity system** is referenced for cancel-recovery odds and (future) discounts. It is its own design doc; Petra is one consumer of it.
- **All numbers are placeholder** and must be tuned against live economy data (dust/rune faucet, drop rates, floor counts).

---

## 1. Problem this solves

Petra is already the hub's **consumables & supplies merchant** ("Consumables and supplies for your next run"), but that role is shallow. Treasure Trader is a **second function layered onto the existing merchant** — making her a sink for surplus gear + risk resources, and a soft crafting/gambling hybrid that rewards cross-run planning.

- Converts junk-tier surplus into a directed upgrade path.
- Costs **time + risk + a scaling gold fee** (gold fee added by M 2026-06-29; supersedes the original "not gold" framing — see `PETRA_TT_PHASE1_SPEC.md §3`). Time/risk still compete with the extraction decision; the gold fee is an additional sink + the target of Petra's Friend discount.
- Gives dust and runes a second meaningful use.

---

## 2. Core loop

1. Player gives Petra **3 items of the same tier** (item type ignored — pure tier-fuel).
2. Petra returns **1 item of the next tier up** after a **delivery cost** measured in floor-clears / boss kills.
3. Player may add **risk resources** to bias affix rolls, request a stat, or lock the slot.
4. Order persists across runs; completes when the delivery cost is met; collected on next visit.

Asynchronous by design: place the order, then *earn* it by playing.

---

## 3. Inputs & base trade ladder

### Input rules
- **3 items of the same tier.** Item *type* is irrelevant — any 3 same-tier items are valid fuel.
- **Affixes on inputs are destroyed.** Clean slate; no roll carries over. (Players should be told this clearly — it's a real loss.)
- Inputs are **consumed on order placement**, not on completion (see §5 cancel rules).

### Ladder (3-in → 1-up)

| Input (3×) | Output (1×) | Base delivery cost | Notes |
|---|---|---|---|
| Common | Uncommon | 1 boss kill (any) | First-boss extract satisfies it; intended free laundering floor |
| Uncommon | Rare | 1 full run (any) | |
| Rare | Epic | 2 full runs, A2+ | Awakening floor begins |
| Epic | Legendary | 2 full runs, A3+ | |
| **Legendary** | **Reroll OR Cursed Unique** | see §6 | Terminal-tier branch |

### Cost philosophy
- Junk tiers: near-instant, pure laundering.
- High tiers: gated by **time AND per-floor Awakening floor** (§4). The floor is load-bearing — do not soften.
- **No tier-skipping.** Always N→N+1, step by step, paying each step. Primary anti-degenerate guard.

---

## 4. Delivery cost = floor-clears (partial progress banks)

Delivery cost is denominated in **floor-clears**; boss kills are a subset. A "full run" is shorthand for N floor-clears (N = floors per run).

- **Partial progress banks.** Clear 2 of 3 floors then die or extract → 2 floors credited; a later session clearing 1 more completes that run's worth. Nothing is wasted, and even a failed run advances the order.
- **Per-floor Awakening gate.** Each *credited* floor must be cleared at or above the order's required Awakening level. Floors cleared below the requirement do **not** count. (Prevents banking cheap A0 floors and finishing one floor at A3.)

This model also softens the commitment trap: a struggling player still inches forward rather than losing everything to repeated deaths.

---

## 5. Order persistence, preview, cancel

- Persistent **order object**, survives extract/death (same layer as pet persistence if applicable).
- **One open order at a time** in v1 (2nd slot via reputation, §8).
- **No-takeback preview:** before inputs are consumed, show the player the **full delivery cost** (floors/bosses + Awakening floor) and **resource cost**. No blind commits.
- Completed item waits at Petra; player must **collect before placing a new order**.

### Cancel (anti-softlock)
A player who places an order but never reaches the required floor must not be permanently soft-locked.
- Cancelling an order attempts to **recover 0–3 of the consumed inputs**, RNG-weighted by **NPC affinity** (higher affinity → better recovery odds).
- This preserves commitment teeth (you might get nothing back) while removing the permanent trap.
- Ties cancel directly into the Affinity system — reputation's third job, alongside delivery speed and the 2nd slot.

---

## 6. Risk resources (levers) & time costs

Base trade = random output item, random in-tier affixes. Levers buy down randomness. Lever **time cost is by type**; lower tiers use the same mechanics at reduced steepness.

### Lever A — Dust roll-bias
Spend magic dust to shift the affix-value RNG distribution upward (more likely +4 than +3). Guarantees nothing. **Resource-only — no time cost** (weakest lever, kept cheap/frictionless). Dust cost scales with output tier.

### Lever B — Directed affix (sacrifice runes)
Request one specific affix present on output (e.g. +fire dmg), *if legal on the slot*. Rest stay RNG. Failed/illegal request → **refund runes** + show legal-affix list up front. **Time cost: +1 full run.** This lever defines the time ceiling.

### Lever C — Slot lock
Request the output equipment slot instead of random. **Time cost: +1–2 bosses.**
- When used **with** Lever B: slot's bosses are **absorbed** into the run B already added (no stacking — cap holds).
- When used **alone** (no affix lever): slot's bosses sit **on top** of base (nothing to absorb into).

### Legendary-trade ceiling
- Base 2 floor-runs A3+ → **hard cap 3 floor-runs A3+** with affix lever.
- Dust adds no time; slot rides inside the affix run; affix is the only lever that extends to the cap.
- Result of a full god-roll order: specific slot + guaranteed directed affix + biased rolls, for **3 runs A3+** and a resource pile. Pinnacle-but-humane.

### Lower-tier steepness
Same mechanics, smaller numbers (e.g. on Rare→Epic, the affix lever adds a partial/single boss rather than a full run; slot may add 0–1 boss). Steepness *is* the tier gate. **Exact per-tier numbers = placeholder.**

### Jackpot overroll (raw trades only)
To preserve a gambling thrill and a reason *not* to always max levers:
- **Raw / no-lever trades** carry a rare chance to **overroll past the normal affix cap** — a jackpot you cannot buy with levers.
- **Mutually exclusive with levers** (using any lever removes the chance). The deterministic path buys consistency; the raw path keeps a lottery ticket.
- Presents as a **rare, visible "Petra found something extraordinary" moment** — exciting, not a stealth stat.

---

## 7. Legendary-input branch

Two outcomes, accessed differently:

### Reroll
3 Legendaries → reroll affixes on a Legendary (toward god-roll). Subject to levers + pity (§9).

### Cursed Unique (recipe-gated)
Requires **specific legendary combinations + a reagent** — a recipe to discover, not a menu pick. Chase content, obtainable ONLY here. Cursed-item mechanics themselves are **net-new and undesigned** (a separate bespoke item-drawback framework) — see §0; there is NO existing spec.

**Discovery = ledger + lore (both):**
- **Lore drops** (scrolls/notes in-world) seed awareness a recipe exists.
- **Trade Ledger** (Petra-side) tracks progress and reveals recipes progressively as partial conditions are met (e.g. hold 2 of 3 required legendaries → redacted hint appears).
- Together: lore creates curiosity, ledger makes the hunt legible without forcing out-of-game datamining.

---

## 8. Affinity track (Petra's perks by relationship tier)

Petra is a consumer of the **NPC Affinity system** (see *NPC Affinity & Relationship System* doc). Her perks are her tier rewards. Tiers: Stranger → Acquaintance → Friend → Companion → Lover. Perks start at **Friend** (Stranger/Acquaintance are access/quest tiers, no perks).

| Tier | Petra perk |
|---|---|
| Stranger / Acquaintance | No perk (relationship-building tiers) |
| **Friend** | **Discount** on her services (transactional) |
| **Companion** | **Faster delivery** (scaled reduction on floor/boss cost) + **2nd order slot** + **improved cancel-recovery** (1–2 items) |
| **Lover** | **Recipe Insight** — auto-reveals one cursed-recipe hint per run (signature lateral perk, feeds §7 discovery) + **best cancel-recovery** (2–3 items) |

### Notes
- **The 2nd order slot is now concretely the Companion-tier perk** (this supersedes the earlier vague "gated DEEP" language). Because Companion is a *scarce* slot (player can hold only 1–2 Companions total, per the Affinity system), spending Petra's Companion slot on the 2nd order is a real opportunity cost against bringing another NPC close. That scarcity is the gate, not raw grind.
- **Recipe Insight (Lover)** is lateral, not power-creep — it accelerates cursed-recipe *discovery* (§7), reinforcing Petra's treasure-trader identity rather than scaling her numbers.
- **Cancel-recovery (§5)** is tier-stepped: pre-Friend 0–1, Friend 0–1, Companion 1–2, Lover 2–3 items recovered on a cancelled order.
- Standard affinity rules apply (gate quests to advance, neglect decay below Companion, betrayal/slot-demotion). See the Affinity doc; neglect for Petra = no buy/sell/trade with her for 6 floor-clears.

---

## 9. Reroll bad-luck protection (pity)

Tracked **pity counter** on rerolls: after N failed/poor rerolls, the next is guaranteed an improved floor. Prevents the feel-bad spiral that kills gambling systems. Tune N against reroll cost.

---

## 10. Anti-degenerate guardrails (summary)

- No tier-skipping (step-by-step laundering, each step paid).
- Per-floor Awakening gate on high tiers — do not soften.
- Lever time capped via the affix lever; slot absorbed; dust costs no time → Legendary cap = 3 runs A3+.
- 2nd order slot gated deep.
- Inputs consumed on placement; cancel = RNG 0–3 recovery (affinity-weighted); collect-before-reorder.
- Jackpot overroll mutually exclusive with levers (deterministic vs. gamble tradeoff).
- **Audit dust/rune faucet vs. this new sink** — biggest balance risk.

---

## 11. Open / to-confirm

1. **Cursed-item mechanics** — net-new and undesigned; build a **separate bespoke item-drawback framework** (§0). There is NO existing spec to reconcile against (the run-curse "devil's bargain" is a different, run-scoped system).
2. **Lever C resource** — does slot lock cost dust, runes, or both?
3. **Exact numbers** — dust per tier, floor/boss counts per tier, Awakening floors, lower-tier lever steepness, pity N, jackpot overroll rarity, reputation thresholds, 2nd-slot gate depth, cancel-recovery odds curve vs. affinity. All placeholder.
4. **Ledger hint UI** — how redacted recipe hints render.
5. **Reagent definition** — what reagents cursed recipes consume, and where they come from.

---

## 12. v1 cut line

**Ship:** base ladder + floor-clear tracking w/ per-floor Awakening gate + Lever A (dust bias) + no-takeback preview + single order + reputation (delivery speed only) + cancel (flat or simple recovery).

**Hold for v1.1:** Levers B/C, jackpot overroll, Legendary branch (reroll + cursed), pity, 2nd order slot (Companion-tier affinity perk), ledger + lore discovery, affinity-weighted cancel recovery, Recipe Insight (Lover perk). Most of these depend on the Affinity and Journal systems shipping.

Rationale: validates the sink + async floor-clear loop with minimal tuning surface before layering in the deterministic/gambling systems and the Affinity dependency.
