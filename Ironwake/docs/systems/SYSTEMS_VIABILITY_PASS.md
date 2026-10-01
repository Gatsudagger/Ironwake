# Ironwake — Viability Pass (ability variety + status reactions + enemy healing)

Design-locked 2026-06-25. Goal: break the single "obvious optimal" loadout per class,
make secondary resources the damage ceiling, add depth via status reactions, and make
anti-heal meaningful by giving enemies real healing. NO blanket enemy buffs — the floor
stays; the ceiling rises and gates behind engagement (resources / consumables / gear).

Status legend: `[ ]` todo · `[x]` done (verify in-IDE). Not compile-tested by the agent.

---

## Diagnosis (why one loadout dominated)
- **Flat "+20 if debuffed" on Snipe (and +40% on Arcane Burst)** triggered off the cheapest
  possible debuff — a 1-AP poison DoT — so the setup→payoff loop cost nothing and repeated
  every turn. Confirmed: combat rider `combat_has_status(target, "dot")` etc. (Step_0 ~641).
- **Secondary resources were optional** — the strongest builds (Poison Dart + Shadow Step +
  Field Dressing + Snipe) never spent Preparation; the class economy was bypassed.
- **Free universal sustain** (Field Dressing, 1 AP, no resource) + cheap dodge let any class
  run heal+dodge+burst on cheap 1-AP slots.
- **Redundant damage abilities** (Flurry≈Killing Spree≈Snipe; 4 Arcanist soul-nukes; 5
  Bloodwarden melee hits) competed only on damage-per-AP → one wins, the rest are dead.
- **Anti-heal was dead**: `combat_heal_after_mortality` is only ever called on the PLAYER, so
  Plague Touch's mortality on an enemy did nothing — and almost nothing healed anyway.
- **Most enemy mechanics are unwired**: only `double_strike` has a combat handler; regen/
  fortify/phase_shift/charge/retribution/death_burst are defined but don't fire. The enemy
  *ability* path DOES work (Ember Mending heal resolves at Step_0 ~1375) → build healing on it.

---

## P1 — Detonation Reaction system  (replaces flat "+20 if debuffed")  [ ]
Designated **detonator** abilities react with the target's status on hit, applying a
status-specific effect and (usually) consuming the status. Poison still "counts" — it just
yields a poison-appropriate effect (heal reduction), not flat burst — so the spam combo dies
without breaking the rule that poison is a debuff.

**Detonators:** Snipe, Assassinate, Arcane Burst, Soul Nova, Rupture.

**Status element tag.** At status application, tag the struct with `element`:
poison / bleed / void exist now; burn / frost / shock are future-ready (no fire/ice DoTs yet —
"frozen" maps to ROOT for now). Derive from the source ability (name + damage_type).

**Reaction table** (detonator hits a target carrying the status):

| Status / element | Reaction | Consume |
|---|---|---|
| Poison | Apply Mortality −40% healing, 4 turns | yes |
| Bleed | +5 damage per remaining bleed tick (Rupture-style) | yes |
| Root / Frost | +30% damage (shatter) | yes (root) |
| Stun | This hit is a guaranteed crit | no |
| Vulnerable (Exposed) | +12 flat damage | no (multi-hit window) |
| Weaken | +15% damage | no |
| Blind | Cannot miss + small bonus | no |
| Void DoT (Entropy) | Caster heals 30% of damage dealt | yes |
| Burn (future fire DoT) | +40% crit chance this hit | yes |

- **Snipe folded in:** base bonus 20 → **+12 (Vulnerable reaction)**; everything else via table.
- Rupture's existing bleed-detonate becomes the Bleed reaction (shared code).
- Killing Spree / Flurry keep their broad per-debuff-COUNT scaling (that's a different axis —
  stacking many statuses — and is intended depth, not a free 1-AP trigger).
- Reactions resolve pre-crit so they scale (mirror the existing rider ordering).

## P2 — Differentiate redundant abilities  [ ]
- **Flurry** (SS) → 3-hit multi-strike: 3 × 6 physical, each rolls crit independently and
  procs on-hit riders (Serrated bleed / poison spread / weapon lifesteal). Identity = on-hit
  synergy. *(small loop in the cast resolver)*
- **Killing Spree** (SS) → Prep stack-payoff: 12 base + 6 per debuff/trap/mark, 2 Prep.
- **Arcane Echo** (Arc) → hit 14 (+4/Soul), then 50% splash to all OTHER enemies. Soul-fueled
  mini-AoE, distinct from Soul Nova (single dump) and Singularity (full AoE ult). *(splash loop)*
- **Bonebreaker** (BW) damage 18 → 14 — leans into its Exposed-primer role (it applies
  vulnerable) vs Marrow Crush's 24 weaken-nuke.

## P3 — Tighten free sustain  [ ]
- **Field Dressing** → once per combat, heal 12 → 14. Ongoing sustain now means class
  resource-heals (Void Drain / Blood Leech / Blood Surge / Second Wind). Use the player
  ability-cooldown system (ability_cd) or a per-combat flag.

## P4 — Resources = damage ceiling  [ ]
- Spike Trap 22→26, Death Snare 28→32, Assassinate base 24→26 (Prep spenders).
- Snipe base stays 14 (filler without a reaction).
- Crimson Apex heal 18→20.

## P5 — Revive dead abilities  [ ]
- Soulbind (Arc): reflect 40%→50% + add a 6 void hit (not a pure 2-AP/1-soul setup).
- Bloodthorn Aura (BW): reflect 5→8 per hit.

## P6 — Enemy healing (makes anti-heal real)  [ ]
- **6a fix:** route enemy heal abilities (Step_0 ~1375) — and the regen mechanic if wired —
  through `combat_heal_after_mortality(actor, amt)`. Plague Touch / mortality finally works.
- **6b content:** mender archetype on the working ability path — one healer enemy per biome
  (heal ~18, ~3-turn cooldown; self-heal, ally-heal as stretch) + tag 2–3 tanky enemies with
  modest self-regen heal abilities (~8–10). Fix the regen mechanic handler if cheap.
- **6c scaling:** enemy heal amounts scale with Awakening via a heal multiplier mirroring the
  dmg table `[1.0, 1.15, 1.35, 1.6, 1.9, 2.3]`. At A4 an 18 heal ≈ 34 → slow damage stalls
  without burst / anti-heal / consumables.

## P7 — Discoverability  [ ]
- **`ui_draw_ability_detail(ability)`** — full-screen popup, opened by **Tab** while an
  ability is highlighted, in: loadout/ability-assignment screen, character-menu Abilities tab,
  and the Vex ability list. Shows icon, attack-class, AP + secondary cost, cooldown, damage /
  type, crit, full mechanics, a **Reactions** block (what it triggers vs each status), and
  flavor. Closed by Tab/Esc. `[Tab] Details` hint on rows.
- **Compendium**: add a **"Status Reactions"** section to `ui_compendium_sections()` listing
  each element/status → its reaction, so the whole system is readable in one place.

---

## Notes
- Ability descriptions are generated (`ability_describe`/`ability_effect_full` in scr_abilities)
  — update those so detonators surface their reaction behavior automatically (no hardcoded
  drift). See [[project_ability_rework]] for the prior setup→payoff pass this builds on.
- Builds on the prior §3 rework (Exposed combos, resource path). Combo riders live in
  obj_combat_controller/Step_0 next to the Snipe / Arcane Echo hooks.
