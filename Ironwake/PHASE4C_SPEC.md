# Phase 4c — Gate Quests + Downward Forces (Demotion / Decay / Betrayal)

**Parent designs:** `NPC_Affinity_System_Design.md` (§2 gates, §5 scarcity, §6 downward forces, §7 romance), `BUILD_ORDER.md` Phase 4.
**Builds on:** 4a quest layer (`quest_catalog`/`quest_tick`/board/Journal), 4b gifts, thin-affinity track (score→tier, `gate_ready`, one-click deepen).
**Status:** BUILT 2026-07-04 (this doc is the as-built record).

---

## 1. Gate quests replace the one-click deepen

- 21 new catalog entries, `kind:"gate"`, one per NPC per gate:
  Acquaintance→Friend (`gate_tier:2`), Friend→Companion (`gate_tier:3`), Companion→Lover (`gate_tier:4`, player-elected by *starting* it).
- **Visibility** (`quest_visible`): a gate quest is hidden until its NPC's score has the gate READY and the player sits exactly one tier below (`entry.tier + 1 == gate_tier`). Active/done gates always show. Hunts unchanged.
- **[B] Deepen** (`affinity_try_advance`) now routes through the quest:
  - gate quest **available** → auto-starts it ("they ask something of you first").
  - **active** → progress reminder.
  - **done** (re-climb after neglect/demotion where the quest survived) → **free one-click recross** — neglect never re-quests (§6).
- **Turn-in** (board Enter, same flow as hunts) crosses the tier via `affinity_gate_cross` — heart burst, ledger, badge — instead of a material reward. Tier IS the reward.
- Objectives reuse the 4a tick types (`use_function` / `boss_kill` / `clear_floors` / `kill_family(any)` / `socket_rune` / `pet_stage`) plus new **`gift_good`** (give that NPC a Loved/Liked gift — ticked from the 4b gift resolver).

## 2. Scarcity enforcement (replaces the hard blocks)

- **Companion (cap 2):** the 3rd Companion gate can be pursued & completed; completing it **slot-demotes the lowest-score existing Companion** to Friend and **resets their Companion gate quest** (re-quest required, §5 "teeth"). Hub notice + ledger both sides.
- **Lover (cap 1):** pursuing a second Lover is **betrayal**: completing the new Lover gate drops the old Lover to **soured Acquaintance** (tier 1, score slashed to the tier floor), resets ALL their gate quests (full re-court), ledger heartbreak entry + notice.
- The old `affinity_try_advance` hard blocks are removed — the costs above are the enforcement now.

## 3. Neglect decay

- New per-NPC field `idle_clears` (migrated on read; reset to 0 by any `affinity_add` function-use).
- On every **floor clear** (the existing `clear_floors` tick site): `affinity_neglect_tick()` — for each NPC **below Companion** (Companion+ frozen, §6): `idle_clears++`; once past **6**, erode `score` by **2 per further clear** (floor 0). Score hitting **0** drops exactly one tier (ledger "drifting apart", badge).
- Re-climb is points-only: the gate quest for a tier already cleared stays `done`, so the recross is the free one-click path. **Neglect never re-quests.**

## 4. Numbers (tunable)

- Thresholds unchanged: [0, 15, 45, 100, 180]; soft cap 30/run; Companion pacing target ~5–8 runs.
- Decay: grace 6 floor-clears, then −2 score/clear. Betrayal floor: score = 15 (Acquaintance threshold).
- Gate quest objectives sized: Friend small (2–3 interactions), Companion medium (bosses/gifts/raising), Lover large (deep-run proof).

## 5. Not built (deliberate)

- Per-NPC quest-abandon consequences — no abandon action exists in the quest layer.
- Per-NPC betrayal severity curves — v1 uses one severity; per-NPC color goes in with the flavor pass.
- Theft/story betrayal triggers — no such actions exist yet; only the romance-switch trigger is live.
