# Phase 4a — Quest Data Layer + Journal Shell (implementation mini-spec)

**Parent designs:** `Journal_System_Design.md`, `NPC_Affinity_System_Design.md` (§4/§6 are 4b/4c), `BUILD_ORDER.md` Phase 4.
**Status:** BUILT 2026-07-03 (same day as lock) — all GML written, needs M's F5. Three perk adaptations made during build (code reality didn't match the approved table; flag to M):
1. **Maren Companion**: "overwrite returns the old rune" had no substrate (unsocketing already returns runes, sockets never overwrite) → now **socketing fee waived** (Friend = halved).
2. **Sable Lover**: exotics are always brewable (nothing to "stock") → now **"Private Reserve": the first brew after each run is free.**
3. **Bairc Lover**: the donation garden is visual-only (no bonus to double) → now **"his full attention": the stable crowding penalty never applies.**
**Design-lock:** numbers TUNABLE; structure locked once M approves.

**4a scope:** quest data layer + Journal overlay (Relationships + Quests tabs) + Bairc affinity wiring + perk tables for all 7 NPCs + 3 starter hunt quests.
**NOT in 4a:** gifts (4b) · real gate quests, soft-demotion, neglect-decay (4c) · cursed items (4d). Gates stay one-click.

---

## 1. Quest data layer

`global.quests` — array of quest structs, **meta-persistent** (saved in `scr_save` beside `npc_affinity`; guarded load, absent → seed from catalog).

```
{ id: "hunt_dorn_floors",  kind: "hunt",          // "hunt" | "gate" (4c) | "recipe" (4d)
  npc: "dorn",                                     // stable NPC key (thin-spec convention)
  status: "available",                             // "available" | "active" | "done"
  obj_type: "clear_floors",  obj_target: 3,  obj_progress: 0,
  obj_param: "",                                   // e.g. enemy family, min Awakening
  reward: { gold: 150, items: [] },                // + feed/rune item grants
  name: "...", flavor: "...", turnin: "dorn" }
```

**Objective template kit (v1 — the hybrid-authoring backbone):**
| obj_type | Ticks from (existing seam) |
|---|---|
| `clear_floors` | boss-clear seam (`petra_order_tick` call site, obj_combat_controller) |
| `kill_family` | `combat_on_enemy_defeated` (family via the enemy-SFX classifier) |
| `boss_kill` | boss-clear seam (param = specific boss name or "" any) |
| `pet_stage` | `pet_run_complete` evolution return (param = min stage) |
| `socket_rune` | Maren socket confirm (hub Step) |
| `use_function` | the existing `affinity_add` drip sites (param = N interactions) |

- `quest_tick(obj_type, param, amount)` — one helper; each seam calls it once. Only `status == "active"` quests advance.
- **Start + turn-in are hub-only** at the quest-giver NPC's panel (`[Q] Quests` affordance when one is available/complete) *and* from the Journal Quests tab (hub only). Mid-dungeon both are greyed with "hub only" per the doc.
- Rewards: gold via `add_gold`, feed via `pet_feed_pouch`, runes via the existing rune-grant path.

### Starter hunts (3 — placeholder content, prove the plumbing)
1. **"The Warden's Due"** (Dorn) — clear 3 floors → 150g.
2. **"A Good Start"** (Bairc) — raise any pet to Adolescent → 2× Prime Cut feed.
3. **"Proof of Craft"** (Maren) — socket 2 runes → one Tier I rune.

---

## 2. Journal overlay

- **Toggle `J`** — hub + dungeon floor map; **blocked in combat** (Room1) and while another modal owns input. Own state on gc (`journal_open/_tab/_cursor/_detail`), drawn from `scr_ui` `ui_draw_journal()`, universal controls (W/S rows, Q/E tabs, Enter, Esc).
- **Two tabs** in an expandable array: **Relationships**, **Quests** (Bestiary/Lore = future slots).
- **Action gating:** view/track everywhere it opens; commit actions (start quest, turn in, later gifting) **hub only** — buttons shown-but-greyed elsewhere.

### Relationships tab (master-detail)
- Left: met NPCs — `npc_unlocked[i]` && (interacted: `affinity score > 0` or tier > 0; Bairc: `bairc_active()`). Row = portrait thumb + name + tier + badge dot.
- Right profile: portrait (the NPC-panel portrait art), name, tier, **diegetic progress bar** (never the raw score), lore blurb (extend `npc_descriptions` with a longer journal blurb per NPC), **gift-taste grid as "???" slots** (schema ships now: 5 bands × per-NPC lists, ALL hidden until 4b reveals them), **interaction ledger** (per-NPC array `{kind, text, run#}` — 4a logs tier crossings + quest turn-ins; gifts append in 4b), pinned active quest.

### Quests tab (master-detail)
- Left grouped **Active / Available / Completed**; right pane = objective + progress, reward, giver NPC (+ tier it unlocks for 4c gates), flavor, turn-in hint.

### Badges
- `global.journal_badges` — per NPC + per quest dirty flags, set on: affinity tier/gate change, taste learned (4b), quest progress/turn-in-ready.
- **Clear on viewing that entry.** Small dot on the row + a `[J]` hint pulse in the hub footer while any badge is set.

---

## 3. Bairc affinity wiring (closes the Phase-2 deferral)

- Add `bairc` key to `global.npc_affinity` (guarded save-load migration, same shape).
- **Drip (+2, same 30/run soft cap):** any Bairc station transaction — feed applied, donation, capstone/splash pick, hatch, set-active.
- **Early-warmth Stranger perk (LOCKED):** from first meeting (`bairc_active()`), **pet-feed lines at Petra cost 10% less** — "he puts in a word." Seam: the feed-price line in `petra_buy_list`.
- Tier line + deepen-bond affordance on his hub panel (same as the other 6).

---

## 4. Numbers

Thin-track thresholds (15/45/100/180) and drip (+2, cap 30/run) **unchanged in 4a** — they rise in 4c when quest chunks land, per the thin spec's pacing note.

---

## 5. Perk tables — all 7 NPCs (DRAFT — needs M approval, wired in 4a once approved)

Perks read `affinity_at_least(npc, tier)`; Friend = tier 2, Companion = 3, Lover = 4. Petra's are live already; the six below are new.

| NPC | Friend | Companion | Lover |
|---|---|---|---|
| **Dorn** | 10% gear discount (after cha_price) | +1 shop stock slot each restock | "Master's Pick" — one guaranteed Rare+ affixed piece in stock |
| **Sable** | +10% dust from salvage | Brew/upgrade costs −20% | "Private Reserve" — one exotic potion (Goldfinger / Faerie's Tear) always stocked |
| **Maren** | Socketing fee halved | Overwriting a socketed rune returns the old rune | "Signature Rune" — a unique aspect rune only she grants *(content authored in 4c)* |
| **Vex** | 10% off permanent upgrades | Trait-potency stat cost 5 → 4 | Unique trait *(content TBD — authored in 4c)* |
| **Vael** | 15% skin discount | Portrait changes free | Exclusive "Beloved" skin *(art pass later — PixelLab)* |
| **Bairc** | +1 stable capacity (8→9) | Once per hub return, he mends 1 injury tier on one pet (free) | "Heart of the Garden" — donation-garden bonus doubled |
| **Petra** *(live)* | Discount | Faster delivery + 2nd order slot* + better cancel | Recipe Insight *(no-op until 4d)* + best cancel |

\* Petra's 2nd order slot is a held Petra-TT build item — ships with her held-features pass, not 4a.

---

## 6. Code seams

| Concern | Seam |
|---|---|
| Quest globals + catalog | `scr_stats` new block: `quest_catalog()`, `quest_state_init` (gc Create, guarded), `quest_tick/start/turn_in` |
| Save/load | `scr_save` — `global.quests`, `global.journal_badges`, ledger arrays, `npc_affinity.bairc` migration |
| Progress ticks | boss-clear site (beside `petra_order_tick`), `combat_on_enemy_defeated`, `pet_run_complete`, Maren socket confirm, `affinity_add` |
| Journal input/draw | gc Create (state) + gc Step (J toggle + nav, room-gated) + `scr_ui` `ui_draw_journal` |
| Hub quest affordances | NPC-panel `[Q]` prompt + turn-in flow in hub Step/Draw |
| Bairc drip + perk | Bairc station handlers in gc Step; `petra_buy_list` feed price line |
| New perk hooks | Dorn/Sable/Maren/Vex/Vael price+behavior sites (each already has a single confirm site from the drip wiring) |

---

## 7. Open

1. **M approves/edits the §5 perk tables** (the one blocking review).
2. Journal lore blurbs per NPC — I draft, M edits (short, in-voice).
3. Vex/Maren Lover content + Vael skin art — slots defined now, content lands 4c/art pass.
