# NPC Affinity & Relationship System

**Status:** Final framework draft — numbers placeholder, per-NPC content tables to be authored
**Build phase:** **Phase 0.5 (thin track) now → Phase 4 (full) later.** Thin track = per-NPC score→tiers, all 6 NPCs scored, points→one-click placeholder gate, caps enforced; NO gifts/quests/soft-demotion/neglect-decay yet. Full machinery (gifts, real gate quests, demotion, decay, Journal) is Phase 4. See `BUILD_ORDER.md`.
**System owner:** Meta-progression / NPC layer
**Consumers:** all 6 hub NPCs — Dorn, Sable, **Maren (Runesmith — BUILT, not a stub)**, Vex, **Petra (Treasure Trader perks)**, Vael — plus **Bairc (Creature Keeper — net-new, ships with Pets)** and all future NPCs. (Petra, Maren, Bairc are the worked examples below; the other four still need perk tables.)
**Depends on:** Journal system (Relationships tab + Quests tab — the UI surface; see §11), per-NPC content authoring (gate quests, perk tables, gift tastes)

---

## 0. Reconciliation notes (READ FIRST)

- **Live-build reconciliation (2026-06-29) — supersedes the old "check the GDD" guidance** (the GDD is a stale `.docx`; the real state is the code + `SYSTEMS_*.md`):
  - **There is NO existing affinity/faction/relationship scaffolding.** This system is net-new; build from this doc.
  - **The hub has 6 NPCs, all present from game start** (`obj_hub_controller/Create` `npc_names`): **Dorn** (Blacksmith — gear shop), **Sable** (Alchemist — salvage loot→rune dust, brew/upgrade potions), **Maren** (Runesmith — sockets gear & aspect runes), **Vex** (Trainer — stat/ability/trait upgrades), **Petra** (Merchant — consumables/supplies), **Vael** (Aesthete — cosmetic skins). Affinity should apply to **all six**, not just the three this doc names — Dorn/Sable/Vex/Vael each need a perk table too.
  - **Maren is NOT a stub.** Her rune function is fully built (gear-rune sockets + aspect-rune combat buffs); §11 below is corrected. Her affinity perks can be authored against the real runeworks today.
  - **Bairc (Creature Keeper) does NOT exist yet** — there is no 7th NPC slot. He is net-new and ships with the Pets subsystem (`PETS_DESIGN.md`); adding him means a 7th `npc_names` entry.
  - **Cursed items don't exist** either — the only "curse" system is the run-scoped devil's-bargain (`SYSTEMS_CURSES.md`); Petra's "cursed-recipe" content is net-new (see the Petra doc §0).
- **All numbers are placeholder** (point values, decay rates, pacing) and must be tuned. Pacing intent is given in §3 as the anchor the numbers tune toward.
- **Per-NPC content is hand-authored**, not formulaic: each NPC needs its own gate quests, perk table, gift-taste table, and downward-force tuning. The system defines the *slots*; the characters fill them. Petra is the worked example; Bairc and Maren are stubs.

---

## 1. Purpose

Give NPCs persistent, meaningful relationships that reward investment and create real choice. Affinity is a **build-defining commitment**, not a checklist: scarcity (§5) means you can only bring a few NPCs close, so *who* you invest in matters. Relationships unlock transactional, content, and narrative perks, up to and including optional romance.

---

## 2. Core structure

- **Per-NPC, independent.** Each NPC (Petra, Bairc, Maren…) has its own affinity. No global reputation.
- **Persistent meta-progression.** Affinity banks across runs; never resets per-run.
- **Hidden numeric score → discrete tiers.** Player sees the tier; an internal score drives progress within it.

### Tier ladder
**Stranger → Acquaintance → Friend → Companion → Lover**

- **Stranger → Acquaintance:** pure points threshold, **no quest** (frictionless on-ramp).
- **Acquaintance → Friend:** gate quest.
- **Friend → Companion:** gate quest.
- **Companion → Lover:** gate quest, **player-elected** (you choose to pursue romance; never auto-offered or forced).

So: one free threshold + **three gate quests** per NPC. Points get you to a gate; the quest is the key that opens it.

- **Perks start at Friend.** Stranger/Acquaintance are access/relationship-building tiers with no mechanical perk. (Exception: Bairc — see §9.)
- **All NPCs are romanceable** (full ladder available for every NPC). Player-side scarcity, not per-NPC gating, limits how many you can actually max.

---

## 3. Earning the score

The hidden score accrues from three weighted sources:

| Source | Role | Magnitude |
|---|---|---|
| **Using their function** (trade with Petra, runes with Maren, etc.) | Steady baseline | Small drip per meaningful interaction |
| **Gifts** (§4) | Spikes | Per-NPC taste-dependent; can be negative |
| **Gate quests** | Big chunks | The tier keys; large one-time awards |

### Per-run soft cap
Grindable sources (function-use, gifts) are **soft-capped per run** to prevent blitzing a relationship in one session. Relationships are meant to build over many runs.
- **Gate-quest chunks BYPASS the soft cap** — they're discrete, non-farmable gate events, so capping them would be arbitrary. The cap applies only to the grindable drip/spike sources.

### Pacing intent (the tuning anchor)
A dedicated player should reach **Companion in ~5–8 runs**. The per-run soft cap and gate-quest costs must sum toward that. Lover sits deliberately beyond, as extra commitment. (Numbers placeholder; tune to this target.)

---

## 4. Gifts (per-NPC, Stardew-style)

Gifting is a deliberate, scarce action — not a spam button.

- **Limited to 1–2 gifts per run.** Precious; choose well.
- **Full 5-band reactions:** Loved / Liked / Neutral / Disliked / Hated. Per-NPC taste tables (hand-authored content).
- **Bad gifts hurt:** Disliked/Hated **lower** affinity. A wrong gift is a double-cost (loses points *and* burns a scarce give), so taste knowledge matters.

### Learning tastes
Players learn tastes two complementary ways, both surfaced in the **Journal → Relationships tab**:
- **Soft hints** — dialogue/observation reveal preferences over time.
- **Logged reactions** — the interaction ledger records what you've tried and how the NPC reacted (learn-by-doing, but remembered).

Because bad gifts punish, pure blind trial-and-error is avoided — there's always at least a hint path.

---

## 5. Scarcity & commitment (the heart of the system)

Strong perks live at **Companion** and **Lover**, and both are deliberately scarce:

- **Lover:** exactly **one** NPC, ever (exclusive).
- **Companion:** limited to **1–2** NPCs.

So a maxed player's roster is roughly *1 Lover + 1–2 Companions*, everyone else at Friend or below. Who you bring close is a real choice with opportunity cost.

### Enforcement — soft demotion with teeth
- Climbing a **3rd** NPC to Companion **soft-demotes your lowest Companion by a full tier** (Companion → Friend).
- The demoted NPC must **re-clear the Companion gate quest** to return.
- Re-allocation is therefore *possible but expensive* — you commit to a roster and only reshuffle when you really mean it. (This is the resolution of an earlier free-swap design that would have made scarcity nominal; the re-quest cost is what gives the cap teeth.)

### Cap is permanent
The 1–2 Companion cap does **not** expand via meta-progression. Scarcity is the point.

---

## 6. The three downward forces (keep distinct & legible)

Three different things can lower a relationship. A player must always be able to tell *which* happened. They differ in trigger, magnitude, and whether they force a re-quest.

| Force | Trigger | Magnitude | Re-quest? |
|---|---|---|---|
| **Neglect decay** | No meaningful function-use with the NPC for **6 floor-clears** (≈2 runs) | Erodes points *within* a tier; only drops a full tier if score hits zero. **Frozen at Companion+ (Companion & Lover are safe).** | **No** — if decay drops you below a gate you already cleared, you just **re-earn points**, never re-quest. |
| **Slot demotion** | Climbing a 3rd NPC to Companion (§5) | Full tier drop (Companion → Friend) on your lowest Companion | **Yes** — must re-clear the Companion gate |
| **Betrayal** | Pursuing another romance, hostile acts (theft), and/or specific story choices (**all count**) | Souring. For a broken **Lover**: drops all the way to a **soured low tier** (real heartbreak). Severity **varies per-NPC**. | **Yes** to re-climb; some NPCs take you back colder/slower |

Notes:
- Only **slot demotion** and **betrayal** force re-quests. **Neglect never does** — it's the gentle, forgiving force.
- **Companion+ is the commitment reward:** committed relationships don't rot from neglect. Casual ones need occasional attention.

---

## 7. Romance

- **One at a time, exclusive.** Only one Lover ever (§5).
- **Player-elected.** The Companion→Lover gate is pursued by player choice; never forced or auto-offered. (Consent-forward tone.)
- **Perks balanced per-NPC** ("mix"): some NPCs' Lover perk is genuine power, others lateral/unique flavor. Authored per character, not a formula. (Petra's is lateral — Recipe Insight, §10.)
- **Switching Lovers = betrayal.** Taking a new Lover breaks the old: full demotion to a soured low tier, per-NPC severity. The single Lover slot is weighty precisely because heartbreak is costly and the re-climb is punishing — you don't swap lovers to chase perks.

---

## 8. Perk schema (the reusable per-NPC table)

Every NPC fills in this schema. The system defines the slots; the character defines the contents.

**Per-NPC fields to author:**
- **Gift tastes** — Loved / Liked / Neutral / Disliked / Hated item lists.
- **Gate quests** — Acquaintance→Friend, Friend→Companion, Companion→Lover (structure + objective; fiction authored separately).
- **Perk table** — one headline perk each at Friend / Companion / Lover, tagged by layer (transactional / content / narrative). Layer mix **varies per NPC**.
- **Downward-force tuning** — betrayal severity, breakup floor, and quest-abandon consequence (see below).
- **Neglect:** universal rule (6 floor-clears idle), but "function-use" is defined per NPC (what counts as interacting with *them*).

### Quest-abandonment (per-NPC)
If a player starts a gate quest and fails/abandons it, the consequence **varies per NPC**: some don't care (gate just stays locked, retry freely), others impose a minor affinity ding or a retry cooldown. Another character-defining slot.

### Perk layers
- **Transactional** — discounts, faster service, better odds.
- **Content** — unlock unique items / recipes / quests.
- **Narrative** — dialogue, story, romance.

All three exist across the perk-bearing tiers (Friend/Companion/Lover); the *mix and ordering* is per-NPC.

---

## 9. Worked example — Bairc (Creature Keeper) [STUB]

> Bairc is a **net-new NPC** (no hub slot exists yet — see §0); his function (creature/pet subsystem, `PETS_DESIGN.md`) is its own design pass. Perks here are placeholder shapes, flagged.

**Signature trait — early warmth.** Bairc is the outcast who extends friendliness *before* it's earned. **Unique exception to "perks start at Friend":** Bairc grants a **tiny friendly perk at Stranger tier** (lore-justified — he understands being an outcast). This both characterizes him and demonstrates the schema's per-NPC perk-floor flexibility.

- **Stranger:** tiny goodwill perk (placeholder — e.g. a minor creature-care convenience). *Bairc only.*
- **Friend / Companion / Lover:** TBD pending the creature subsystem design. Author once Bairc's function exists.
- Everything else (gifts, gate quests, betrayal tuning) follows the standard schema.

---

## 10. Worked example — Petra (Treasure Trader) [COMPLETE]

Cross-references the *Petra Treasure Trader* doc; this is the affinity-tier mapping.

| Tier | Petra perk | Layer |
|---|---|---|
| Stranger / Acquaintance | None | — |
| **Friend** | Discount on her services | Transactional |
| **Companion** | Faster delivery + **2nd order slot** + improved cancel-recovery (1–2 items) | Transactional / content |
| **Lover** | **Recipe Insight** (auto-reveal one cursed-recipe hint per run) + best cancel-recovery (2–3 items) | Content (lateral) |

- **2nd order slot at Companion** ties Petra's biggest convenience to a scarce slot — spending it on her costs you a Companion elsewhere.
- **Recipe Insight (Lover)** is lateral, not power-creep; feeds her cursed-recipe discovery loop.
- **Cancel-recovery, tier-stepped:** pre-Friend 0–1, Friend 0–1, Companion 1–2, Lover 2–3 items.
- **Neglect for Petra** = no buy/sell/trade for 6 floor-clears.
- **Gift tastes / gate quests:** author per §8 (sample taste table + 3 gate quests with objectives to be written; fiction is M's).

---

## 11. Worked example — Maren (Runesmith) [FUNCTION BUILT — perks to author]

> **Corrected 2026-06-29:** Maren's rune function is **already built**, not a stub. She sockets **gear runes** (stat bonuses) and **aspect runes** (combat buffs) into equipment. Perks below are now anchored to that real function; only the perk *content/tuning* is open.

| Tier | Maren perk | Layer |
|---|---|---|
| **Friend** | Discount / better rates on rune-socketing services | Transactional |
| **Companion** | Improved socket outcomes (e.g. better roll odds) or an extra socket slot/option | Transactional / content |
| **Lover** | Signature rune perk — TBD (power vs. lateral per the per-NPC call) | TBD |

- **Neglect for Maren** = no rune-socketing interaction for 6 floor-clears.

---

## 12. Journal dependency (UI surface)

Affinity has a hard dependency on the **Journal system** (its own buildout doc). The Journal is the in-fiction artifact — the player character's personal journal — which is why intimate content (relationships, romance) belongs there rather than a clinical "codex." Matches Ironwake's existing tabbed-overlay UI convention (Q/E tab-switching, full-screen overlay).

Journal tabs relevant here:
- **Relationships tab** — per-NPC profile: portrait, lore, current tier, learned gift-taste hints, and the **interaction ledger** (logged reactions, recent history).
- **Quests tab** — active/available/completed quests, including affinity **gate quests** (with objective + progress + which NPC/tier they unlock) and Petra's cursed-recipe hunts.

Affinity cannot fully ship without the Journal's Relationships and Quests tabs. (The Journal also hosts Petra's recipe Trade Ledger from the Treasure Trader doc.)

---

## 13. Open / to-confirm

1. **GDD reconciliation** — existing NPC/faction scaffolding (§0).
2. **Numbers** — point values per source, soft-cap size, decay rate, gate-quest costs, all tuned to the ~5–8-run Companion pacing.
3. **Per-NPC content** — gift-taste tables, gate-quest fiction, perk tables, betrayal/abandon tuning for every NPC. Hand-authored.
4. **Bairc function** — stubbed; net-new NPC, perks can't finalize until the Pets subsystem ships. (**Maren is no longer blocked — her runeworks is built.**) The 4 unworked NPCs (Dorn/Sable/Vex/Vael) also need perk tables.
5. **Journal system** — its own doc; affinity + Petra both depend on it.

---

## 14. Spun-off systems (track these)

This design surfaced dependencies that are their own docs / work:
- **Journal system** — Relationships + Quests tabs (+ Petra's recipe ledger). Load-bearing for affinity and Petra.
- **Bairc + Pets subsystem** — net-new NPC + creature layer (`PETS_DESIGN.md`); needed before Bairc's perks finalize.
- **Perk tables for the other 4 hub NPCs** — Dorn, Sable, Vex, Vael all exist and need authored gift tastes + gate quests + perk tables.

(~~Maren's rune function~~ — **already built**, no longer blocking; her perks just need authoring. Also outstanding from the Petra doc: cursed items are net-new/undesigned, and a dust/rune faucet audit.)
