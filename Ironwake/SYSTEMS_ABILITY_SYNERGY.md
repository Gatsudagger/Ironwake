# Ironwake — Ability Synergy (role categories + same-type AP discount)

Design-locked 2026-06-25. Goal: make "minor buff" abilities viable and reward thematic
loadouts. Casting an ability of a role category makes the NEXT same-category ability this
turn cost −1 AP. Adds a role axis (Offense/Defense/Support/Control) alongside the existing
reach×kind attack-class and the detonation reactions. CORE mechanic (applies to everyone).

Status: `[ ]` not built yet.

---

## Categories (4)  [ ]
A new role tag via `ability_category(ab)` (derive like `ability_attack_class` — name-keyed
overrides + a field fallback). Hybrids resolve by PRIMARY role (see rule).

- **offense** ⚔️ — deals damage as its point. base_damage > 0 and not a pure setup/CC.
  Strike, Cleave, Snipe, Flurry, Killing Spree, Throat Slit, Assassinate, Gore Strike,
  Marrow Crush, Bonebreaker, Crimson Apex, Rupture, Soulfire, Arcane Burst, Soul Nova,
  Arcane Echo, Singularity, Rift, Scorch, Poison Dart, Crippling Shot, Mana Sever,
  Vital Theft, Soulbind, + the traps (Bear/Spike/Death — they're damage tools that also CC;
  classed offense so trap users still get the offense discount. Tunable.)
- **defense** 🛡️ — self-protection. Iron Skin, Bloodthorn Aura, Soul Shield, Blink,
  Shadow Step, Evasive Roll, Vanish, Undying.
- **support** ✨ — heal / buff / resource. Field Dressing, Void Drain, Blood Surge,
  Second Wind, Adrenaline Rush, Soul Harvest, Sanguine Pact, Bloodfeast, Blood Leech (heal+dmg
  but sustain-primary — judgment call, tunable).
- **control** 🌀 — pure debuff / CC with no damage as the point. Curse, Smoke Bomb,
  Marked for Death, Entropy (DoT-only debuff — judgment call), Plague Touch.

**Derivation rule (fallback when not name-listed):**
1. self_targeted + effect_type heal/resource OR a buff → support
2. self_targeted + protective status (shield/dodge/survival/reflect/damage-reduction) → defense
3. base_damage == 0 + applies debuff/CC → control
4. base_damage > 0 → offense
Name-keyed overrides win over the rule (for the hybrids above).

## Synergy discount  [ ]
- Each ability cast AFTER the first of its category THIS TURN costs **−1 AP, floor 1**.
  First of a category = full cost. Resets every player turn.
- Example: Bloodthorn Aura (2, defense) → Iron Skin (2−1=1, defense) = **3 AP** for both
  (was 4 → uncastable together). Offense benefits least (1-AP attacks already at the floor).
- **Single source of truth:** `ability_effective_cost(ab, caster)` =
  `max(1, ab.energy_cost - (category_already_cast_this_turn ? 1 : 0))`. Use it EVERYWHERE:
  the AP-affordability gate, the actual AP spend, and the UI cost display — so they never drift.

## Implementation notes  [ ]
- State on player: `turn_cast_categories` (struct/set). RESET at player-turn start —
  obj_combat_controller/Step_0 ~157 (where ability_cd ticks / need_player_status_tick).
- After a successful cast, mark the category: `turn_cast_categories[?category] = true`.
- AP gate + spend: the cast block (~407 gate, ~861 spend per prior memory) must use
  `ability_effective_cost` instead of raw `ab.energy_cost`. `ability_can_cast` may need the
  caster + the discount too.
- UI: combat ability buttons (obj_combat_controller Draw_64 / ui_draw_ability_buttons) show
  the DISCOUNTED cost live (e.g. "1 AP" highlighted when discounted). Color-code abilities by
  category (offense red, defense blue, support green, control purple) on the buttons + the
  Tab ability-detail popup + loadout/Vex rows. Add a Compendium entry explaining the synergy.
- Add the category to the generated description (`ability_effect_full`) and the detail popup
  so players can read it.
- Edge cases: free (0-AP) abilities stay 0; min 1 floor; AoE/ultimate treated uniformly.
  Secondary-resource cost (souls/blood/prep) is NOT discounted — only AP.

## Build order
1. `ability_category(ab)` helper + the per-turn tracking + `ability_effective_cost`.
2. Wire effective cost into gate/spend (combat) — verify two same-category buffs cast in one turn.
3. UI: discounted cost display + category color-coding + Compendium/description text.

Builds on [[project_viability_pass]] (reactions) and the attack-class system. Pairs with the
weapon-roles work but is independent — can be built before or after.
