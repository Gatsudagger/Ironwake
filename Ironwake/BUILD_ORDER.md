# BUILD ORDER — Petra Treasure Trader + Pets (+ thin Affinity)

**Status:** Sequencing locked 2026-06-29 (M approved). Mini-specs/numbers downstream.
**Scope:** The two current priorities — **Petra Treasure Trader** and the **Pet subsystem** — plus the **thin NPC-Affinity track** they both ride on. Journal, gifts, gate quests, and cursed items are explicitly **Phase 4 / later**.
**Reconciled against:** the live build (code + `SYSTEMS_*.md`), not the stale `Ironwake_GDD_v1.docx`. See each system doc's §0.

Source docs: `Petra_Treasure_Trader_Design.md`, `PETS_DESIGN.md`, `NPC_Affinity_System_Design.md`, `Journal_System_Design.md`.

---

## Locked decisions (2026-06-29)

| Decision | Choice |
|---|---|
| Build order | **Petra first → Pets** |
| Affinity | **Thin track first** (perks live at launch), full system Phase 4 |
| Petra v1 width | **Exact v1 cut line** (doc §12) |
| Thin-affinity tier advance | **Points → one-click placeholder gate** (swap for real quests in Phase 4) |
| Scarcity machinery | **Caps enforced (1 Lover / 1–2 Companion); soft-demotion deferred** to Phase 4 |
| Affinity scope | **Score all 6 hub NPCs**; perks wired Petra now, Bairc Phase 2, others later. **Neglect-decay deferred** to Phase 4 |

---

## Shared primitives (built in Phase 1; both systems consume)

The two systems are **not** independent — Petra's order persistence and Pet persistence are the *same layer* (Petra doc §5), and pets buy feed from Petra. Build these once:

1. **Floor-clear banking hook** — one fire-point per floor cleared, tagged with the run's Awakening level, advancing banked progress on (a) active Petra orders and (b) the active pet's Stage. Banks across runs; extract/clear credit **>** death.
   - *Code seam:* plugs into the existing run spine — `end_run(result)` (1 = victory/full-clear, 0 = extract, −1 = defeat) and `global.current_floor` in `scr_stats`. The per-floor tick is net-new (today only depth + per-dungeon `dungeon_clears` exist).
2. **Cross-run persistent-object layer** — meta-globals **not** reset in `end_run` (model on `global.equipment_stash`), with save/load hooks in `scr_save`. `global.petra_order` (Phase 1); `global.pet_roster` + `global.active_pet` (Phase 2).

---

## Phases

### Phase 0.5 — Thin affinity scaffold
Stands up the tier/perk API before features so perks are live at launch.
- Per-NPC hidden score → discrete tiers (Stranger→Acquaintance→Friend→Companion→Lover). **All 6 hub NPCs** scored via existing function-use hooks; perks wired Petra now.
- **Advance:** points reach a gate, then a **one-click placeholder "deepen bond" confirm** crosses it (stand-in for Phase 4 gate quests). Lover gate stays player-elected.
- **Caps enforced** (1 Lover / 1–2 Companions) as simple blocks. **No** soft-demotion, **no** neglect-decay, **no** gifts, **no** real quests yet.
- Deliverable: the affinity score/tier/perk read-API (`scr_*` helpers + persistent `global.npc_affinity`), Stats-tab/NPC-panel tier display.

### Phase 1 — Petra Treasure Trader v1 (exact cut line)
Reuses the existing Petra NPC; builds both shared primitives.
- Base **3-in / 1-up ladder, 4 rungs**: Common→Uncommon→Rare→Epic→**Legendary** (you can craft Legendaries). The **Legendary-INPUT branch (reroll + Cursed Unique) is HELD** for later. Affixes on inputs destroyed; inputs consumed on placement.
- **Floor-clear banking + per-floor Awakening gate** (ships shared primitive #1; fires at boss-clear, 3 floors/run).
- **Lever A only** (dust roll-bias). OUT: Levers B/C, jackpot overroll, cursed branch, pity.
- **No-takeback preview**, **single order**, cancel-with-recovery.
- Reads affinity tiers: **Friend → discount (live)**; **Companion → faster delivery + better cancel** *(+ 2nd order slot — open Q1 in the Phase-1 spec)*; **Lover → Recipe Insight (no-op until cursed recipes) + best cancel**.
- Full detail + open questions: `PETRA_TT_PHASE1_SPEC.md`.

### Phase 2 — Pets, non-combat
Reuses Phase-1 banking hook + persistence layer + Petra's shop.
- **Bairc as net-new 7th hub NPC** (extend `npc_names`/`npc_descriptions`/`npc_unlocked` in `obj_hub_controller/Create`), dormant until first pet; affinity-scored.
- Acquisition/egg-find + hatch (Stage 0); archetype rolled & revealed at hatch.
- **Companion tab** on the Dungeon Gate loadout screen; 1 active slot.
- **Feed sold by Petra**; Growth (feed) + Stage (runs, via banking hook) + Bond axes.
- Stable (donation, soft cap).

### Phase 3 — Pet combat & stakes
- Always-visible companion sprite → **Combatant turns** (Stage-2 1-AP, Stage-3 2-AP); Boon/Guardian passives.
- Corruption (cure vs. push); **injury ladder → permadeath**.

### Phase 4 — Relationship & content depth (later)
- Gifts + real **gate quests** (swap Phase-0.5 placeholders); **soft-demotion + neglect-decay** turn on; **Journal** (Relationships/Quests tabs); **cursed items** (net-new bespoke framework) → lights up Recipe Insight.

---

## Why this order is the most fluid

Phase 0.5 → 1 front-loads the **smallest** surface (Petra already exists; exact cut line) while laying the two seams Pets cannot ship without. Pets — the bigger, combat-touching, new-NPC system — then becomes mostly **assembly on proven primitives** rather than net-new plumbing. Affinity rides underneath both from the start, so there is no retrofit.

## Per-phase pre-build checklist (per CLAUDE_SETTINGS design-lock)
Each phase gets a mini-spec (numbers + code seams) agreed with M **before** any `.gml` is written. Phase 0.5 mini-spec is the next artifact.
