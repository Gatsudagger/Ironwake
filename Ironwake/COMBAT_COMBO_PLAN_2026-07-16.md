# Combat Combo Plan — 2026-07-16 (DESIGN-LOCKED + IMPLEMENTED same day)

**§H answers (M, in-session 07-16):** Overwhelm CORE +15% · Overcharge on damage AND
heals/shields (+2/pt) · Warpath +2/turn · Flip streak per-combat (+8/win) · Crippling Shot
RENAMED **Frost Shot** (M's call), Chill 1 turn · SS ramp (Compounding Dread) added now ·
Entropy 6/8/10/12. Implementation notes + F5 checklist: PATCH_NOTES_ABILITIES.md (07-16 section).

**Scope approved by M 2026-07-16:** all four buckets (A juice/legibility, B Bloodwarden parity,
C dead-pick reworks, D borrowed-memory draft) **plus both global rules** (Overwhelm, Overcharge).
This doc fixes the numbers. Per the design-before-code rule, implementation starts only after
M blesses the values below (open questions collected in §8).

**Process rules honored** (ABILITY_DIVERSITY_RESEARCH §5, M-approved 07-09): every item states
its budget math (yardstick: 1 AP ≈ 12–14 damage points; DoT ≈ 0.75× face; conditional ≈ face ×
realistic uptime; stun ≈ 14–16, weaken ≈ 8, Exposed ≈ 4/hit) and names the fight where it's wrong.

**Findings this plan answers** (review 2026-07-16):
1. Bloodwarden has ZERO reaction-table detonators (list is Snipe/Assassinate/Arcane Burst/Soul
   Nova) — Chill→SHATTER, Hexed ×2, stun-crit, void-lifesteal are all unreachable for BW.
   Rupture's bleed-consume is a bespoke rider, not a reaction.
2. Combos are invisible before commit: `combat_estimate_hit` deliberately omits reactions, so
   the planning half of the combo loop never happens on screen.
3. No reason to stack DIFFERENT statuses; no cash-out moment at full Souls/Blood/Prep; no
   multi-enemy detonation turn; ramp exists only for Arcanist (Soul Engine).

---

## A. Combo Legibility + Juice (presentation only — no balance risk)

### A1. Reaction-aware hit preview
When the selected ability is a detonator and the target carries a reactive status, append a
colored chip to the existing "→ ~X dmg" readout (keep the base estimate untouched/stable):

| Target status | Chip text (school-colored) |
|---|---|
| Chill / root | `+SHATTER 30%` |
| Bleed (Rupture) | `+5/tick ×N` |
| Stun | `CRIT!` |
| Exposed / vulnerable | `+12` |
| Weaken | `+15%` |
| Void DoT | `+30% lifesteal` |
| Burn | `+40% crit` |
| Hexed target | append `×2` to the chip |

Also on the Tab detail popup in combat: a live "vs current target" reaction line.

### A2. Detonatable-status glow
Enemy status-row icons pulse (2-frame sine alpha, school color) while the currently selected
ability would react with them. Zero new art — tint + alpha on the existing status icons.

### A3. Sequenced detonation resolution (the Balatro lesson)
A detonating hit resolves as a staggered sequence instead of one lump number
(reuse the loot-reveal stagger idiom, ~8 frames/step):
1. Base damage popup + normal hit SFX
2. Reaction splash text ("SHATTER!" / "RUPTURE!" / "EXPOSED!") + bonus damage popup, SFX step 2
3. If Hexed: "HEXED ×2!" splash + the doubled remainder, SFX step 3
4. Crit flourish last (existing crit presentation), SFX step 4

SFX ladder = existing hit sounds re-pitched via `audio_sound_pitch` (1.0 → 1.12 → 1.25 → 1.4)
— **zero ElevenLabs spend**. Damage is computed exactly as today (one internal total); only the
presentation is staggered, so logs/saves/balance are untouched. Any key/click skips to the total
(loot-reveal rule). Shake tiers: reaction = current shake, Hexed step = +50%.

**Wrong fight:** none — pure presentation.

---

## B. Bloodwarden combo parity

### B1. Rupture → full detonator
Add Rupture to `ability_is_detonator`. **Delete its bespoke bleed rider in the same change** —
the shared Bleed reaction (+5/remaining tick, consume) is the identical effect; keeping both
would double-dip. Net behavior vs bleed: unchanged. New behavior: Rupture now also shatters
Chill/root, crits vs stun, drinks void DoTs, and gets doubled on Hexed targets.
Budget: unchanged vs bleed (2 AP: 8 + 5/tick as today); the new reactions are the class
finally joining a system everyone else already had.

### B2. Bonebreaker → detonator #2
The committed 3-AP hit becomes BW's big detonation button (18 dmg + Exposed-primer stays).
No stat changes. Together with B1, BW gets exactly two detonators — same count as Arc/SS.

### B3. NEW ability — **Warpath** (BW ramp; the Soul Engine mirror)
2 AP, once per combat, combat-long self-buff (support category): "Your physical and Blood
abilities deal +2 more for every full turn that has passed since you lit it."
Budget: Soul Engine is +3/turn on spells; BW swings more often per turn with cheaper hits, so
+2/turn ≈ the same growth per AP spent. Vex 500g (premium tier, matches Soul Engine).
**Wrong fight:** 2-turn trash — 2 AP for nothing. The boss-fight pick, by design.

### B4. OPTIONAL (flagged, not in the approved bucket) — SS ramp
**Compounding Dread** (SS): each trap that fires permanently adds +4 to your trap damage this
combat. Only if M wants ramp coverage in all three classes now; otherwise queue it.

---

## C. Dead-pick reworks (4)

### C1. Crippling Shot (SS, 2 AP) — the shatter-primer
Today: 10 dmg + Weaken 25%/3t ≈ 18 pts — under the 24–28 budget, identity owned by Marrow
Crush (Weaken) and Smoke Bomb (SS defense).
**Rework:** 10 physical + Weaken 25%/3t **+ Chill 1 turn**. Budget: 10 + 8 + ~6 = 24. On.
SS gains its own SHATTER setup (pairs with Snipe/Assassinate/Winter's Bite — Winter's Bite's
+9-and-refund-vs-Chilled clause finally has an in-class enabler).
**Wrong fight:** low-threat trash whose damage output never mattered.

### C2. Entropy (Arc, 2 AP) — the accelerating DoT
Today: 6/turn × 4 = 24 delayed ≈ 18 pts. Bland on the nuke class.
**Rework:** ticks **6 / 8 / 10 / 12** (36 total, heavily back-loaded ≈ 25–27 effective).
Long-fight DoT identity, distinct from Scorch (primer) and Poison Dart (cheap SS poison).
Detonating it early (void reaction: 30% lifesteal, consume) now sacrifices the big late ticks —
a real hold-or-pop decision.
**Wrong fight:** anything that dies in 2 turns.

### C3. Rift (Arc, 3 AP + 2 Souls) — the cascade button
Today: 20 Arcane AoE — squeezed between Singularity (32 AoE for +1 Soul) and Cleave (1 AP chaff).
**Rework:** 20 Arcane AoE **and Rift detonates the statuses on every enemy it hits** (each
enemy's reaction resolves individually; Hexed doubling per-target; sequenced per A3 = the
biggest audiovisual turn in the game).
Budget: huge on a prepared board — gated by 3 AP + 2 Souls + the multi-turn setup investment.
**Wrong fight:** a lone clean boss with no statuses — Singularity is strictly better there.

### C4. Devil's Flip (General, 1 AP) — the streak
Today: 50/50 deal 26 / take 8. EV 13 = Strike, but Strike refunds AP on kill → Flip strictly worse.
**Rework:** each consecutive WIN adds **+8** to the next flip's payout (26 → 34 → 42 → …,
per-combat streak); a loss still deals 8 to you and resets the streak.
Budget: EV at streak 0 unchanged (13); the escalation is the paid-in-variance reward.
*Variant for M:* per-RUN streak (funnier, swingier — the gambler's epic). Default: per-combat.
**Wrong fight:** any fight you can't afford to eat an 8 — which is exactly when gambling is wrong.

---

## D. Borrowed Memories → draft (pick 1 of 3)
Today `borrowed_memory_grant()` rolls ONE random off-class ability. Change the granting
event/shrine to roll **3 distinct candidates** (reroll duplicates) and open a picker
(reuse the shared item-picker modal idiom: name, class tag, desc_short, Tab for detail).
The StS lesson: the choice IS the fun. No new content — same pool, same run-scoped clear.
**Wrong fight:** n/a (event-layer).

---

## E. Global rule 1 — **Overwhelm** (multi-status bonus; Hades "Privileged Status" analog)
**Rule (CORE, all combats):** an enemy carrying **2+ distinct status kinds** takes **+15%
damage from all sources**. Distinct = different `kind`s in its status list (two bleed stacks =
one kind; bleed + chill = two). Surfacing: an "OVERWHELMED" tag on the enemy status row
(glows per A2 idiom) + compendium entry + one coach-mark tip.
Why core and not a trait: it teaches mixing statuses to everyone and makes Plaguebearer,
Serrated Strikes, and multi-school weapons instantly better without touching their numbers.
*Fallback if M prefers opt-in:* ship as a universal trait "Opportunist's Eye" instead. **Q for M.**
**Wrong fight:** mono-status spam builds get nothing — intended; that's the rule doing its job.

## F. Global rule 2 — **Overcharge** (the cash-out)
**Rule:** when your secondary resource is **FULL (10)** as you cast a spender, the cast
**consumes the entire reserve**; every point beyond the ability's printed/scaled consumption
adds **+2 damage** (self-buff spenders like Sanguine Pact/Blood Surge: +2 shield/heal per point).
Abilities with their own per-point scaling (Soul Nova +7 ≤4, Soul Rend +8 ≤2) keep their better
rate up to their cap; Overcharge's +2 applies to the points beyond it.
Surfacing: resource bar glows at 10 + "OVERCHARGE" tag on spender buttons while full.
Budget: at full Souls a Soul Nova = 8 + 4×7 + 5×2 = 46 for 2 AP + the whole reserve — a
turn you *built toward*, priced by the hoarding turns it took.
**Wrong fight:** short fights (never reach 10) and dump-constantly builds — by design, this is
the patient hoarder's payoff.

---

## G. Implementation map (for the build session — after number lock)
- `scr_abilities.gml`: detonator list (+Rupture, +Bonebreaker), Warpath def + desc, C1/C2/C3/C4
  data + desc rewrites, `ability_unlock_info` (Warpath Vex 500g), category tags.
- `obj_combat_controller/Step_0.gml`: delete Rupture bespoke rider (~1069–1086); reaction block
  (~881–1090) gains the A3 sequencing timers; Overwhelm multiplier at the damage-calc site;
  Overcharge in the spend path (`ability_spend_resources` call site) + Warpath rider next to
  Soul Engine's; Rift per-enemy reaction loop in the AoE branch.
- Hit-preview draw site + ability buttons: A1 chips, Overcharge tag; status row: A2 glow +
  OVERWHELMED tag.
- Borrowed-memory grant site: 3-roll + picker modal.
- Compendium: Overwhelm + Overcharge sections; reaction-preview mention in Status Reactions.
- `PATCH_NOTES_ABILITIES.md`: one row per change WITH budget math (process rule).
- Reference sync sweep (CLAUDE_SETTINGS rule): Rupture/Rift/Entropy/Crippling Shot/Devil's Flip
  tooltips, Vex rows, compendium, any coach-marks that describe old behavior.
- Audio: pitched reuse of existing SFX only — no generation spend.

## H. §8 Open questions for M (the numbers to bless)
1. Warpath +2/turn — right mirror of Soul Engine's +3, or match at +3?
2. Overwhelm: +15% at 2+ distinct statuses — and CORE rule vs opt-in trait?
3. Overcharge +2 per excess point — and should self-spenders (heals/shields) get it too?
4. Devil's Flip streak: per-combat (default) or per-run?
5. Crippling Shot's Chill: 1 turn (proposed) or 2 (= Hoarfrost parity, likely too strong at 2 AP)?
6. B4 SS ramp (Compounding Dread) now, or queue it?
7. Entropy 6/8/10/12 — comfortable with 36 total on a 2-AP DoT given how back-loaded it is?
