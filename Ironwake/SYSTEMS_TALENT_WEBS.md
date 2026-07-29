# SYSTEMS_TALENT_WEBS.md — Ability Talent Webs + Class Trunks
**Status: DESIGN-LOCKED 2026-07-27 (M signed off all 8 open questions; see §8 decision
log). Signature shortlist in §3.5 is PROPOSED — M may veto/swap names any time before P3.**
*(Drafted 2026-07-26. Replaces the ability-mastery notch system flagged "incredibly bland
and basic" in COMBAT_IMPROVEMENT_PLAN_2026-07-17 §C. Folds class-passive expansion into
the same system per M's 07-26 decision.)*

---

## 1. Goals / non-goals

**Goals**
- Every ability has a small **talent web** that shapes HOW it plays — branching, flavorful
  nodes — not a flat stat trickle. "Your Snipe isn't my Snipe" gets louder, not quieter.
- Each class gets a **trunk web** that expands its class passive into real class identity
  (today the entire passive is one resource-gen rule per class).
- One currency model, one UI pattern, one save shape for both layers.
- Feasible at our scale: **~64 abilities** across 3 class pools + a general pool. We can NOT
  hand-author 64 bespoke webs before launch-window content; the system must degrade
  gracefully from bespoke → templated.

**Non-goals (v1)**
- No Path-of-Exile mega-web. Webs are SMALL (7 nodes) and fit on one 1920×1080 screen —
  no pan/zoom, readable on a phone.
- No new resource earned in combat. Web points come from lifetime casts (existing
  `global.ability_casts`), trunk points from permanent progression.
- Pet talents are NOT this system (that's backlog item 3, its own design-lock later).

---

## 2. System overview — two layers

| Layer | Scope | Currency | Earned by |
|---|---|---|---|
| **Ability web** | per ability (~64) | Mastery Points (MP), per-ability | lifetime casts of THAT ability |
| **Class trunk** | per class (3) | none — free exclusive pick per row | reaching gate levels L2/5/8/11/14 |

Both layers use the same node/edge data model, the same web-view UI, and the same
resolve pipeline (modified-copy, pools never mutated — the pattern
`ability_mastery_resolve` already uses, so dynamic descriptions keep self-updating).

---

## 3. Ability webs

### 3.1 Shape — the 7-node "wishbone"

```
            [ROOT]                 root = the ability itself, free/auto
            /    \
        (P1)      (T1)             P branch = POWER   (hit harder / more often)
         |          |              T branch = TWIST   (changes behavior)
        (P2)      (T2)
         |          |
        [PK]      [TK]             keystones — play-pattern changers
              \    /
           (cross-link:            P2↔T2 cross-edge — buying either mid-node
            P2 — T2)               opens the OTHER branch's mid-node as a dip
```

- 6 purchasable nodes; **spend cap 4 MP per ability**. A full branch costs 3, so you can
  finish ONE branch + dip 1 into the other — never both keystones. The cap is what forces
  builds to diverge.
- Node ranks: **minor** (P1/T1 — stat bumps, reuses today's mod vocabulary),
  **notable** (P2/T2 — a mechanic tweak), **keystone** (PK/TK — changes the play pattern).

### 3.2 Authoring — template first, bespoke where it counts

- **Template webs (Phase 1, all ~64 abilities):** the web is GENERATED from the ability's
  shape — the same axes `ability_mastery_options()` already branches on, widened with
  attack-class and school:
  - key = damaging / timed-effect / instant-effect × melee/ranged × attack/spell
  - Example template (ranged damaging spell): P1 +3 dmg → P2 +4% crit → PK "kills refund
    1 AP"; T1 +5 acc → T2 "cooldown −1" → TK "first cast each combat costs −1 AP".
  - Notables/keystones draw from a small keyed table (~10 notable effects, ~8 keystone
    effects), assigned by shape + school so sibling abilities don't all read identically.
- **Bespoke overrides (Phase 3, ~6 signature abilities per class = 18):** a name-keyed
  override table (same pattern as the dynamic-description riders) replaces any node with a
  hand-authored one — e.g. Snipe TK "Deadeye: your Snipe crits apply Exposed". Bespoke is
  where the flavor budget goes; templates guarantee coverage everywhere else.

### 3.5 PROPOSED signature shortlist (from M's real cast telemetry, 2026-07-27)
Weighted toward most-played per save slot + class-defining kit pieces. Two general-pool
abilities ride with their heaviest-user class. **M may veto/swap freely before P3.**

| Class | Signatures |
|---|---|
| Arcanist | Soulfire (290 casts) · Singularity (211, general pool) · Void Drain (193) · Arcane Burst (57) · Entropy · Blink |
| Bloodwarden | Blood Leech (30) · Blood Surge (28) · Gore Strike (23) · Iron Skin (18) · Undying · Plague Touch |
| Shadowstrider | Poison Dart (23) · Vanish (22, general pool) · Snipe (18) · Bear Trap · Shadow Step · Death Snare |

Note: Plague Touch's bespoke keystone is the natural home for fixing its latent
`mortality` effect (ROADMAP §2 open item — enemies never heal, so −healing does nothing;
a keystone can route enemy regen through it or replace the effect).

### 3.3 Earning MP

- Keep `global.ability_casts` exactly as-is (per-name lifetime casts, per slot).
- New thresholds: **10 / 30 / 60 / 100 casts → 1 MP each = 4 MP lifetime** (matches the
  spend cap; today it's [25, 75] → 2 notches). Combat-log line on each earn stays.
- All numbers first-pass/tunable.

### 3.4 Node effects — two mechanical kinds

1. **Field mods** (minors, some notables): route through the existing
   `ability_apply_mastery_mod`-style field edits on the resolved copy. Zero new combat code.
2. **Keyed riders** (notables/keystones): a node id the combat controller checks at the
   relevant moment via `ability_web_has(name, node_key)` — same shape as the bespoke
   description riders. Each keystone effect is ONE well-defined hook (on-kill, on-crit,
   first-cast, cooldown math, status application).

---

## 4. Class trunks (the class-passive expansion)

Today each class passive is a single resource rule: Arcanist +2 Souls on kill ·
Bloodwarden +1 Blood when hit · Shadowstrider +1 Prep/turn with no trap armed.
The trunk keeps that rule as its free ROOT and grows ~10 purchasable nodes around it.

### 4.1 Shape
- **5 rows × 2 nodes**, row N gated by permanent level (rows at L2 / L5 / L8 / L11 / L14).
- Each row is a **this-or-that pair**, and pairs are **PERMANENTLY EXCLUSIVE** (locked
  2026-07-27): picking one locks the other — a Vex trunk respec is the only out. Two
  max-level Arcanists still play differently. Rows escalate: early rows widen the
  resource engine, late rows add payoffs.

### 4.2 No trunk currency (locked 2026-07-27)
- There are NO Class Points. Reaching each gate level (L2/5/8/11/14) pops a **one-time
  this-or-that choice** — the permanent exclusivity IS the cost, and every pick is a
  milestone moment. (Original CP economy dropped: with exclusive rows only 5 nodes are
  ever bought, so a spendable added bookkeeping and no decisions.)
- Awakening first-clears do NOT feed trunks. If a level-up crosses multiple gates at
  once, prompts queue one at a time. Picks can be deferred (a pending-pick badge on the
  Abilities tab) — never forced mid-flow.

### 4.3 First-pass trunk content (illustrative — M rewrites freely)

**Arcanist (Souls)**
- L2: "+1 Soul on kill" ⟂ "Start each combat with 2 Souls"
- L5: "Souls persist between combats (max 3 carried)" ⟂ "+2% spell crit per Soul held"
- L8: "Soul spenders cost −1 Soul (min 1)" ⟂ "Overkill damage returns as +1 extra Soul"
- L11: "Every 3rd spell each combat +30% damage" ⟂ "Soul spenders apply Vulnerable 1t"
- L14: "At 5+ Souls, spells can't miss" ⟂ "Killing blows with spells refund 1 AP"

**Bloodwarden (Blood)**
- L2: "+1 Blood on your crits too" ⟂ "+2 max HP per Blood held"
- L5: "Blood abilities' HP costs −25%" ⟂ "Start combat with Blood = missing-HP/10"
- L8: "When hit below 30% HP, gain 2 Blood" ⟂ "Heal 1 HP per Blood spent"
- L11: "Blood spenders Weaken the target 1t" ⟂ "+3% damage per Blood held"
- L14: "Once per combat, survive a killing blow at 1 HP (costs all Blood)" ⟂ "Blood cap +3"

**Shadowstrider (Preparation)**
- L2: "+1 Prep when an enemy misses you" ⟂ "Prep gain also while a trap is armed (half rate)"
- L5: "Traps +2 damage per Prep held" ⟂ "First attack each combat from 2+ Prep auto-crits"
- L8: "Evasive tools cost −1 Prep" ⟂ "+2 accuracy per Prep held"
- L11: "Executes below 25% HP instead of 20%" ⟂ "Trap triggers refund 1 Prep"
- L14: "Turn-start at max Prep: +1 AP" ⟂ "Prep cap +2"

---

## 5. Respec, Whetstone, migration

- **Respec at Vex** (she's already the respec/economy NPC): per-ability web refund
  **100g + 10 rune dust** (MP returns as pending); trunk refund **500g + 50 dust**
  (locked 2026-07-27 — pricier so exclusive class picks feel near-permanent). Trunk
  respec clears ALL rows and re-prompts each unlocked gate one at a time.
- **Whetstone honing rework:** instead of an old mastery mod, the shrine grants ONE
  currently-reachable unowned web node of choice, run-scoped, ignoring the 4-MP cap
  (a taste of the road not taken). Same storage (`global.run_honing` → node id),
  cleared exactly where honing clears today.
- **Migration (SAVE_FORMAT_VERSION bump, current 3 → 4):** keep `ability_casts`;
  recompute MP from new thresholds; DROP old `ability_mastery` picks and return
  everything as pending MP (players re-pick — post-update buff moment, no loss).
  Old honing ids in stale saves resolve to "no honing" (null-safe reads already exist).

---

## 6. UI — one web view, two entries

- **Full-screen web view**, one ability (or the trunk) at a time. Left pane: ability card
  (dynamic description of the RESOLVED copy, MP status, casts to next MP). Right pane:
  the wishbone drawn as icon nodes + connecting lines. Bought = lit; affordable = pulsing
  ring; locked = dim + lock glyph. Node hover/selection shows its full text in a fixed
  detail strip (never a floating tooltip — collision-proof).
- **Entry points:** loadout ability detail (Tab popup gains "[W] Web") + character-menu
  Abilities tab; trunk lives as a third entry on the Abilities tab header
  (STATS-style tab chip: ABILITIES | CLASS TRUNK).
- **Touch (MANDATORY, same task as UI build):** every node is a ≥48px tap target,
  hit-tests in DRAW (not Step); tap selects, CONFIRM chip buys (no fat-finger spends);
  BACK chip exits; web/trunk entry gets an ACTIONS-chip. No letter-hotkey-only verbs.
- **Keyboard/gamepad:** node nav via the shared `key_nav`/`nav_*` hold-repeat helpers;
  Enter/A buys with the same confirm step.
- **UI collision check** at longest strings (longest ability name, 3-digit costs).

---

## 7. Build phases (each F5-gated, shippable alone)

- **P1 — Core:** data model + save v4 + migration; template web generation for all
  abilities; web view UI (replaces the notch-pick UI); resolve pipeline
  (`ability_web_resolve` supersedes `ability_mastery_resolve`); Whetstone rework.
- **P2 — Trunks:** 3 class trunks + gate-level pick prompts (+ pending-pick badge) +
  trunk UI + trunk save.
- **P3 — Bespoke:** ~18 signature-ability node overrides; new keystone hooks as needed.
- **Reference sync (every phase):** compendium (mastery + Class Resources entries),
  loadout notch text, Whetstone shrine text, coach-marks, PATCH_NOTES.

---

## 8. DECISION LOG — all questions answered by M, 2026-07-27 (LOCK RECORD)

1. **Ability web spend cap: 4 of 6.** One keystone + one dip max.
2. **MP thresholds: 10/30/60/100 casts** = 4 MP lifetime per ability.
3. **Trunk gating: permanent level L2/5/8/11/14** (not awakening).
4. **Trunk rows: PERMANENTLY EXCLUSIVE pairs** — pick one, other locks (Vex respec only out).
5. **No trunk currency** — free one-time pick at each gate level (CP dropped as fallout
   of #4; awakening clears no longer feed trunks).
6. **Respec: ability 100g+10 dust · trunk 500g+50 dust** (trunk priced up so exclusive
   picks feel near-permanent).
7. **Signatures: proposed from cast telemetry** (§3.5) — M veto/swap before P3.
8. **Trunk tables (§4.3): locked as drafted, tune in play** after F5 like every system.

Per Design Lock rules: no re-design loops. If implementation reveals an issue, flag it
to M but build as documented.

---

## 9. P1 BUILD RECORD (2026-07-27 — BUILT, awaiting M's F5)

Everything in §7 P1 is coded: engine + templates in scr_abilities (replaces the mastery
block; `ability_web_*`), resolve pipeline (`ability_web_resolve`, riders on
`_c.web_riders`), save v4 + drop-and-refund migration (scr_save), web view UI in the
hub loadout (game controller state + hub Step input + hub Draw_64 wishbone with
Draw-event touch hit-testing, CLOSE button, measured labels), WEB touch chip, Whetstone
node-honing rework (floor Step + Draw), combat hooks (MP counting incl. self-casts,
Opening Gambit discount in `ability_effective_cost` + per-combat flags, Executioner's
Rhythm beside the Momentum precedent, Overwhelm beside the Anchor-rune pattern,
`cd_mod` in `ability_cooldown`), and two compendium entries (Talent Webs, The
Whetstone). Old mastery identifiers: zero references remain.

**Flagged implementation deviations (per Design Lock rules — built, M may veto):**
1. **Web opens with [M], not [W]** — W is nav-up everywhere (`nav_up`), so the doc's
   "[W] Web" was unusable; M was already the mastery key and its muscle memory carries.
2. **Character-menu Abilities-tab entry deferred to P2** — P1 ships the loadout entry
   only; P2 adds the char-menu entry alongside the CLASS TRUNK tab it needs anyway.
3. **Template gap for bespoke-effect abilities:** abilities whose effect lives in
   name-keyed combat code with `effect_value 0` (e.g. Soulbind-style riders) generate
   low-impact "+2 effect strength" nodes. Harmless, but their webs stay bland until
   their P3 bespoke overrides. Also: Blink/Shadow Step previously never counted casts
   (self-cast path skipped counting); fixed — movement casts now earn MP.
4. **Vulnerable rider magnitude:** Overwhelm applies flat +2 (1 turn) matching the
   existing vulnerable convention (Hex Spread / shock affix use flat 2-3, not a %).

**M's first-test revisions (07-27, built same session):**
- **Staged commits.** Node picks are STAGED in the view (pulsing pale-gold ring) and
  only become permanent on **SAVE & CLOSE**; **CLOSE**/Esc discards ("Unsaved weaves
  discarded."). Unstaging a support node auto-drops staged dependents. Doubly important
  because Vex respec doesn't arrive until P2 - staging is the reassess valve.
- **Full input parity.** The view cursor extends past the 6 nodes to SAVE & CLOSE (6)
  and CLOSE (7), so keyboard W/S and controller d-pad reach every control the mouse
  can - no click-only verbs (M's rule: full navigation through all means, always).
- **TRANSFORMATIVE KEYSTONES (M: "talents all too identical - I want ability-changing
  usage").** Damaging-ability keystones now draw from a POOL via a deterministic
  per-name hash so siblings diverge: spells roll detonate / ATTUNEMENT (school
  conversion, player's choice of 2-3 adjacent schools - selecting the staged node
  cycles the choice; stored as "pk@fire") / splash / vulnerable-on-hit; attacks roll
  kill-refund / execute / detonate; twist keystones roll first-cast-free / lifesteal /
  execute-or-splash. Conversion rebases +school% gear scaling, log color, VFX tint
  (school field is metadata - mitigation unchanged). PLUS a bespoke name-keyed table
  (17 signatures: Cinderheart fire-Soulfire, Prismatic Burst, Hungering Maw, Event
  Horizon, Exsanguinate, Pandemic, Deadeye, Serrated Jaws, Iron Bulwark...) that
  replaces template nodes wholesale - curated pairings + names over the same shared
  rider primitives (detonate / splash:X / lifesteal:X / execute:X / crit_sec /
  crit_vuln / cast_shield / cast_sec / status_splash), all wired in the combat
  controller. Whetstone offers choice nodes as one deterministic school (overlay
  fits 3 rows). Non-damaging (timed/instant) templates keep the simpler pool for
  now - flagged as the thin spot until more bespoke coverage in a later pass.

## 10. 07-28 AMENDMENTS (same F5 batch)

- **Node-text clarity (M: "+2 effect strength on Blink is confusing")**: the
  generic value nodes now name the CONCRETE unit and show base -> new numbers
  ("+2 healing (14 -> 16)", "+20% debuff potency (30% -> 36%)") via
  `ability_web_val_node`/`ability_web_val_noun` (noun by effect_type).
- **FRACTION DEFECT fixed**: pure-effect abilities that store a percent FRACTION
  in effect_value (a -30% debuff = 0.3) were catastrophically broken by the
  flat "+2" rider (-230%) and by ceil() in the x1.2/x1.5 riders (-100%).
  Fractions now never receive the flat node (template emits multiplicative
  instead), and the riders scale fractions without ceil, capped at 95%. Legacy
  saves holding a "val" pick on a fraction ability bump +10 percentage points.
- **REWEAVE re-homed Vex -> Vael the Aesthete** (M: "the term fits her and she
  needs more rolls"): Vex trainer back to 5 tabs (60+t*360, 345 wide - Step
  hit-test matches); Vael gained a 4th tab (Skins|Portrait|Tints|Reweave,
  4 headers centred on x960). Same 100g + 10 dust (CHA discount; the old
  vex_price 10% now Vael-less), affinity drip -> vael, confirm = the shared
  checkout popup, [Tab] = the mechanic explainer, Gigapack unweave burst on
  commit. Compendium + detail popup reworded.
- **Queued (task #14)**: bespoke webs for weak-baseline abilities (M's Static
  Arc pattern - talents grant the self-proc synergy the baseline lacks).
