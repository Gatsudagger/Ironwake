# Combat Improvement Plan — 2026-07-17 (proposal; numbers await M's blessing)

**Builds ON TOP of** COMBAT_COMBO_PLAN_2026-07-16.md (implemented, awaiting F5). Nothing here
re-opens that batch. Scope set by M in-session 07-17 via scoping questions:

- Slots: **keep 4 + Expanded Arsenal**; add a **simple Honing shrine** now, with the mastery
  system itself flagged for a later rework (M: "current mastery system is incredibly bland").
- New verbs: **all four approved** for the plan (Poise, Interrupt, Bulwark Slam, Riposte).
- Dead-pick batch: **all five approved** (Bear Trap, Killing Spree, Vital Theft,
  Adrenaline Rush, Galvanize).
- Snipe: **tone the debuff bonus +20 → +12** (straight nerf, no behavior change).

Process rules honored (ABILITY_DIVERSITY_RESEARCH §5): budget math per item
(1 AP ≈ 12–14 pts; DoT ≈ 0.75× face; conditional ≈ face × uptime; stun ≈ 14–16, root ≈ 8 vs
melee / 0 vs ranged, Exposed ≈ 4/hit; secondary resource ≈ 6–8/unit) + "the fight where it's
wrong" named for every change.

**Reference-game sources for this round** (beyond the StS/Hades/Balatro lessons already mined):
Darkest Dungeon (riposte = reactive offense), Into the Breach / Fights in Tight Spaces
(punish telegraphs; no wasted actions), StS Barricade/Body Slam (shield as a spendable).

---

## A. Dead-pick fixes (6)

### A1. Snipe (SS, 1 AP) — tone the payoff
Today: 14 phys, acc 90, crit 15, **+20 vs any debuffed target**, detonator ⇒ ~34 pts at 1 AP
when the condition holds (it almost always does on SS) → "primer + Snipe spam" is the StS
"obviously best" failure. **Fix: +20 → +12.** vs-debuffed total 26 ≈ a strong-but-honest 1-AP
conditional (14 + 12×~0.9 uptime). Detonator status unchanged.
**Wrong fight:** clean targets — base 14 is just a Strike with better crit.
**Sync:** desc_short, desc_full, ability_summary "+20 if debuffed" tag, effect_value 20→12,
compendium/coach-marks mentioning the 20.

### A2. Bear Trap (SS) — 2 AP → **1 AP** (+1 Prep unchanged)
Today at 2 AP + 1 Prep: 16 + root(≈8 vs melee, 0 vs ranged) ≈ 24 pts on a ~30 budget, and
Spike Trap at the same cost prints ~44 → strictly dominated. At **1 AP + 1 Prep** (budget
~20): 16 + root ≈ 24 vs melee, 16 vs ranged — the cheap opener trap next to Spike (damage)
and Snare (stun). *Q1: keep 16 dmg or trim to 14 for the 1-AP slot?*
**Wrong fight:** all-ranged packs (root does nothing).

### A3. Killing Spree (SS, 3 AP + 2 Prep) — kills refund
Today: 12 + 5/debuff needs 4+ debuffs on ONE target just to match Assassinate's base 26 —
dominated in nearly every fight. **Fix: keep 12 + 5/debuff; NEW rider: each enemy KILLED by
this cast refunds 2 AP** (the spree). Identity: the multi-kill sweep turn vs Assassinate's
single execute. Budget: refund only pays on lethal — self-balancing.
**Data bug found (fix in same change):** desc_short/summary say **+5**/debuff but
ability_effect_full says **+6** (scr_abilities.gml:1312) — verify which the controller pays
and unify on +5.
**Wrong fight:** the lone boss — Assassinate is strictly better there, as designed.

### A4. Vital Theft (BW, 2 AP + 1 Blood) — make the theft real
Today: 8 dmg + target −8 max HP ≈ 16 pts on a ~30 budget, and "steal" gives you nothing.
**Fix:** 8 Blood dmg; target max HP −8 AND **your max HP +8 and heal 8**, both combat-long.
Budget: 8 + 8 heal + ~6 (temp max HP) + 8 enemy-pool cut ≈ 30. On.
**Wrong fight:** short trash fights (the max-HP swing never matters).

### A5. Adrenaline Rush (General) — once-per-combat → repeatable risk lever
Today: a permanent slot for +1 AP once, dominated by the Ley Tap trait. **Rework:** 0-AP
action, **once per TURN: pay 5 HP → gain +1 AP.** The general pool's HP-as-resource verb;
loves lifesteal builds (Blood Leech/Void Drain feed it back). Vex 250g unchanged.
Budget: 1 AP ≈ 13 pts for 5 HP + a slot + once/turn cap — priced by the HP spiral risk.
*Q2: once/turn OK, or cap at 2 uses/combat for safety?*
**Wrong fight:** any fight you're losing on HP — exactly when the loan is worst.

### A6. Galvanize (BW, 2 AP) — 12 → **16** Shock dmg
Today 12 at 2 AP is under budget, so the kill→+1 AP rider never gets to trigger. At 16 it's
an honest hit (Gore Strike parity minus the bleed, plus the rider).
**Wrong fight:** unchanged — bosses (nothing dies, no surge).

---

## B. New verbs / rules (all four approved for the plan)

### B1. **Poise** — core rule: unspent AP → shield
At END of the player turn, each unspent AP becomes **2 shield** that lasts until the start of
your next turn (StS block model — it does not stack turn over turn). Max 6 (8 with
Relentless). Kills the dead 3rd-AP turn; creates real swing-or-hold decisions before a
telegraphed hit. Surfacing: end-turn floater ("+4 Poise"), shield chip on the player bar,
compendium entry, one coach-mark. Zero new content.
*Q3: 2 shield/AP right? And confirm expiry at your next turn (vs persisting until broken).*
**Wrong fight:** none — but it slightly rewards passivity; the low rate keeps attacking better.

### B2. **Interrupt** — core rule: punish the telegraph
When your stun or root lands on an enemy whose current INTENT is a charged/heavy attack
(intent system already flags these), **refund 1 AP** (once per turn). Into-the-Breach loop:
read the telegraph, answer it, get tempo back. Surfacing: "INTERRUPT!" splash + AP pip
refill flash; compendium; the intent tooltip gains one line.
*Q4: refund 1 AP (proposed) vs +30% damage on the interrupting hit?*
**Wrong fight:** enemies with no telegraphs — the rule is silent there, as intended.

### B3. **Bulwark Slam** (BW, NEW, 2 AP) — the shield payoff
"Consume ALL your current shield; deal its value **+8** as physical damage." Completes the
BW engine: get hit → Blood → Sanguine Pact shield → Slam. With a full Pact (18 shield) that's
26 for 2 AP + the defense you gave up — the StS Body Slam trade. Power crit (STR, 10).
Vex 400g. NOT a detonator (keep the reaction table's membership stable this round).
Budget: shield was already-paid-for value; the +8 base alone is under budget, so the button
is only good with a stocked ward. On.
**Wrong fight:** any fight where you NEED the shield you'd be spending.

### B4. **Counterblade** (SS, NEW, 1 AP) — the riposte stance
"Until your next turn, whenever a melee attack targets you — hit or dodged — counter for
**12** physical." The Darkest Dungeon reactive-offense verb. Placed on SS (knife-fighter
fantasy; pairs with Shadow Step/Vanish dodges — a dodged attack still gets countered) rather
than BW, whose Bloodthorn Aura (passive 8/hit ×4t at 2 AP) keeps the tank-thorns identity
distinct: Counterblade is one turn, burst-sized, dodge-friendly. Vex 400g.
Budget: vs 2 melee attackers = 24 pts for 1 AP but requires being targeted — face × uptime.
*Q5: counter EVERY melee attacker that turn (proposed) or first only (then 14 dmg)?*
**Wrong fight:** ranged/caster packs — a dead button, exactly like Bear Trap's root.

---

## C. Honing shrine (simple v1) + mastery-rework flag

**V1 (this plan):** a new floor event/shrine — working name **"The Whetstone"** — appears
~once per run (event-pool weighting like other event rooms). Pick ONE slotted ability →
choose one of its two existing mastery mod options as a **RUN-SCOPED** bonus (stacks with
permanent notches; same mod ids). Storage: `global.run_honing { name: mod_id }`, applied in
`ability_mastery_resolve` after permanent picks, cleared in `run_state_reset`/end_run/load.
UI: reuse the shared item-picker modal idiom (ability rows → 2 mod options).
*Q6: once per run guaranteed, or a per-floor chance? Free, or a gold/sacrifice cost?*

**FLAGGED FOR LATER (M 07-17):** the mastery system itself is "incredibly bland and basic" —
generic +3 dmg / +5 acc / +2 effect mods. Future rework: hand-authored per-ability mod
tables (e.g. Snipe: "+8 vs full-HP targets" vs "crits refund 1 AP"; Entropy: "ticks spread
on death" vs "+1 turn") so notches AND honing offer build-defining choices. The v1 shrine is
built so only `ability_mastery_options()` needs to change when that rework lands.

---

## D. Deferred / noted (not in this batch)
- **Mastery rework** (above) — queued behind this batch.
- **Encounter-mix audit:** Plague Touch / Mana Sever / Static Arc / Bear Trap are only as
  good as regenerator/caster/swarm/melee frequency in the roster. One pass over encounter
  tables to guarantee each situational ability its fight — multiplies all ability work.
- **Pair-synergy gear affixes** (Hades duo-boon analog) — future itemization lever.
- **Ult/charge meter** (Hades Call) — would free once-per-combat effects from slot tax;
  large system, revisit post-launch if slot pressure still bites.

## E. Implementation map (after number lock — NO code before M blesses §F)
- `scr_abilities.gml`: A1–A6 data + desc edits (incl. the +5/+6 KS drift); Bulwark Slam +
  Counterblade defs, categories (offense / defense), attack classes (Bulwark = melee_attack;
  Counterblade = none/self), `ability_unlock_info` (both Vex 400g); Adrenaline Rush rework.
- `obj_combat_controller/Step_0.gml`: Killing Spree kill-refund rider; Adrenaline once-per-
  turn HP-pay path; Poise end-turn grant + expiry; Interrupt check at stun/root apply site
  (reads the target's intent); Bulwark shield-consume damage calc; Counterblade counter in
  the incoming-attack block (next to Blink/Shadow Step charge handling); honing resolve.
- Event layer: Whetstone shrine room + picker modal.
- UI: Poise floater/chip, INTERRUPT splash, Vex rows, loadout descs; UI-collision check on
  every new/changed string (CLAUDE_SETTINGS rule).
- Compendium + coach-marks: Poise, Interrupt, honing; Snipe/Bear Trap/KS/Vital Theft/
  Adrenaline/Galvanize reference-sync sweep.
- `PATCH_NOTES_ABILITIES.md`: one row per change WITH budget math.
- Audio: reuse/pitch existing SFX; no generation spend planned.

## F. Open questions for M (the numbers to bless)
1. Bear Trap at 1 AP: keep 16 dmg, or 14?
2. Adrenaline Rush: once per turn, or 2 uses/combat cap?
3. Poise: 2 shield per unspent AP, expiring at your next turn — confirm?
4. Interrupt: refund 1 AP (proposed) or +30% damage instead?
5. Counterblade: counter all melee attackers at 12, or first-only at 14?
6. Whetstone: guaranteed once/run or per-floor chance? Free or costed?
7. Bulwark Slam: consume-ALL-shield +8 base at 2 AP, Vex 400g — confirm?
