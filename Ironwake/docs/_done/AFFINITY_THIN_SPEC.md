# Phase 0.5 — Thin Affinity Scaffold (implementation mini-spec)

**Parent design:** `NPC_Affinity_System_Design.md` (this is the buildable *subset*, not a redesign).
**Build phase:** 0.5 (precedes Petra TT). See `BUILD_ORDER.md`.
**Status:** **GML WRITTEN 2026-06-29 — needs M's F5 (not compile-tested).** `.gml`-only, uncommitted. Files touched: `scr_stats.gml` (helper block + end_run reset + the 2 Vex picker drips), `obj_game_controller/Create_0.gml` (init), `scr_save.gml` (save/reset/load), `obj_game_controller/Step_0.gml` (6-NPC drip hooks), `obj_hub_controller/Step_0.gml` (B = deepen-bond) + `Draw_64.gml` (tier line/bar/affordance), `scr_ui.gml` (Stats-tab Bonds line).
**Design-lock:** numbers below are **placeholder/TUNABLE**.

**Goal:** stand up a per-NPC hidden score → tier system with a perk read-API, so Petra (Phase 1) and Bairc (Phase 2) light up tier perks at launch. **No** gifts, real gate quests, soft-demotion, or neglect-decay (all Phase 4).

---

## 1. Data model (persistent, per save slot)

`global.npc_affinity` — struct keyed by stable NPC id:

```
global.npc_affinity = {
    dorn:  { score: 0, tier: 0, gate_ready: false, run_gain: 0 },
    sable: { ... }, maren: { ... }, vex: { ... },
    petra: { ... }, vael: { ... }
    // bairc added in Phase 2
};
```

- **Stable string keys** (`dorn/sable/maren/vex/petra/vael`) — index-independent so roster growth (Bairc = 7th) can't shift them.
- **`tier`**: 0 Stranger · 1 Acquaintance · 2 Friend · 3 Companion · 4 Lover.
- **`gate_ready`**: score has reached the next gate; awaiting the one-click confirm (§3).
- **`run_gain`**: grindable score banked *this run*, for the per-run soft cap (§2). Reset to 0 in `end_run`.
- **Meta-persistent:** `global.npc_affinity` is **NOT** reset in `end_run` (only `run_gain` is). Saved/loaded in `scr_save` alongside the other meta globals (model on `equipment_stash`). Guard load for old saves (absent → init zeros).

---

## 2. Earning score (drip-only in the thin track)

Gifts and gate-quest chunks don't exist yet, so **function-use drip is the sole source.**

| NPC | "Function-use" = one meaningful interaction | Drip |
|---|---|---|
| Dorn | Buy a piece of gear | +2 |
| Sable | Salvage loot→dust **or** brew/upgrade a potion | +2 |
| Maren | Socket a gear/aspect rune | +2 |
| Vex | Buy a permanent upgrade (stat/ability/trait) | +2 |
| Petra | Buy a consumable (Phase 1: **or place a TT order**, +4) | +2 |
| Vael | Buy a skin / apply transmog | +2 |

- **Per-run soft cap:** drip stops adding once `run_gain >= 30` for that NPC (≈15 interactions/run; bumped from 10 on 2026-06-29). Prevents one-session blitzing while letting a session of buying actually cross a tier. **TUNABLE.**
- **Score only ever rises** in the thin track (no decay). Gate-crossing (§3) does not spend score; score keeps climbing past a gate toward the next.

### Thin-track pacing note
Because the big "gate-quest chunks" are absent, thresholds are tuned so **drip alone** is viable: ~Friend in 1–2 active runs, ~Companion in 4–6. When Phase 4 adds gift spikes + quest chunks, thresholds rise and drip becomes the baseline it's meant to be. So thin-track thresholds are deliberately lower than final.

### Thresholds (placeholder, TUNABLE)
| Gate | Cumulative score |
|---|---|
| → Acquaintance (1) | 15 |
| → Friend (2) | 45 |
| → Companion (3) | 100 |
| → Lover (4) | 180 |

---

## 3. Tier advance — points → one-click placeholder gate

1. When `score >= threshold(tier+1)`, set `gate_ready = true`.
2. At that NPC's hub panel, a prompt appears: **"[Deepen bond]"** (placeholder stand-in for the Phase-4 gate quest).
   - **Stranger→Acquaintance** auto-crosses (no prompt) — the doc's frictionless on-ramp.
   - **Companion→Lover** prompt is explicitly **player-elected** ("Pursue a deeper bond?") — never auto.
3. On confirm: `tier += 1`, `gate_ready = false`. Save.
4. **Caps checked at confirm (§4).** If blocked, the prompt shows the block reason instead of advancing.

> Phase 4 swaps step 2's one-click confirm for a real gate quest; everything else (score, thresholds, tiers, perks) stays.

---

## 4. Scarcity caps (enforced; demotion deferred)

- **Lover:** max **1** NPC, ever. Confirming a 2nd Lover gate is **blocked** ("Your heart belongs to another.").
- **Companion:** max **2** (locked 2026-06-29). Confirming a 3rd Companion gate is **blocked** ("You can't commit to more right now.").
- **NO soft-demotion / re-quest** logic yet (needs ≥3 perk NPCs to matter + the Phase-4 quest layer). Caps are simple hard blocks at the confirm step.
- Helpers: `affinity_count_at_tier(4)` / `affinity_count_at_tier(3)` for the checks.

---

## 5. Perk read-API (what Petra/Bairc call)

Generic, content-agnostic readers — features query these, never the raw struct:

```
affinity_tier(npc_id)            -> 0..4
affinity_at_least(npc_id, tier)  -> bool      // e.g. affinity_at_least("petra", 2) for Friend perk
affinity_tier_name(npc_id)       -> "Stranger".."Lover"
```

**Phase-1 Petra perks read these** (numbers owned by the Petra spec, gated here):
- Friend (≥2): purchase/service **discount**.
- Companion (≥3): **faster delivery** + **2nd order slot** + better cancel-recovery.
- Lover (4): **Recipe Insight** (no-op until cursed recipes) + best cancel-recovery.

Other 4 NPCs are **scored but have no perks wired yet** (Phase 4 authors their tables). Scoring them now means their relationships are already underway when perks arrive — no retroactive grind.

---

## 6. UI (thin)

- **Hub NPC panel** (`obj_hub_controller/Draw_64`): add a tier line under the selected NPC (e.g. "Petra — Friend"). When `gate_ready`, show the **[Deepen bond]** affordance + the diegetic progress (tier + bar toward next gate, **never the raw number** — per design §2).
- **Character-menu Stats tab** (locked in for 0.5): a small "Relationships" list — met NPCs + tiers. Cheap, accepted as throwaway, replaced by the Phase-4 Journal.
- **Confirm flow:** reuse the existing hub confirm/modal pattern + universal control scheme (W/S, Enter, Esc).

---

## 7. Code seams (where the `.gml` lands)

| Concern | Seam |
|---|---|
| Globals init | `obj_game_controller/Create` — init `global.npc_affinity` (guarded) |
| Drip on function-use | each NPC's purchase/service confirm in `obj_hub_controller/Step` (Dorn buy, Sable salvage/brew, Maren socket, Vex upgrade, Petra buy, Vael skin) → call `affinity_add(npc_id, amt)` |
| Soft-cap + gate-ready | inside `affinity_add` (in `scr_stats`, after the boon/curse blocks) |
| Tier-advance confirm | `obj_hub_controller/Step` NPC-panel interaction + `Draw_64` affordance |
| Reset `run_gain` | `end_run` (alongside the existing per-run resets) — **but NOT `score`/`tier`** |
| Save/load | `scr_save` — serialize `global.npc_affinity` with the meta globals; guarded restore |
| Perk reads | `scr_stats` helpers `affinity_tier/at_least/tier_name/count_at_tier` |

---

## 8. Resolved (M, 2026-06-29) — spec locked

1. **Numbers** — drip **+2**, soft cap **30/run** (bumped from 10 on 2026-06-29), thresholds **15 / 45 / 100 / 180** (Acq/Friend/Companion/Lover). Pacing "as specced": ~Friend in 1–2 runs, ~Companion in 4–6. Values stay numerically tunable in playtest, but the curve is locked for build.
2. **Companion cap = 2** (1 Lover + 2 Companions). Hard block on a 3rd Companion; demotion deferred to Phase 4.
3. **Petra TT order grants +4 drip** (vs +2 for a consumable buy), still under the 10/run soft cap. (Phase-1 cross-dependency confirmed.)
4. **Affinity UI = hub NPC-panel tier line + minimal Stats-tab Relationships list** now. Full Journal is Phase 4. (The Stats-tab list is accepted as cheap throwaway, replaced by the Journal later.)
5. **Progress display = tier + bar, never the raw number** (diegetic; inherited from the parent design §2).

→ No open blockers. Next concrete step: Phase 0.5 `.gml` per §7 seams.
