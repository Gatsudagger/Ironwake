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
1. `ability_category(ab)` helper + the per-turn tracking + `ability_effective_cost`.  **[x] BUILT 2026-06-26**
2. Wire effective cost into gate/spend (combat) — verify two same-category buffs cast in one turn.  **[x] BUILT 2026-06-26**
3. UI: discounted cost display + category color-coding + Compendium/description text.  **[x] BUILT 2026-06-26**

### Build notes (Phases 1–2, 2026-06-26, not compile-tested)
- `scr_abilities.gml`: added `ability_category(ab)` (name-keyed overrides per the lists above +
  the self/damage fallback), `ability_category_label`, `ability_category_color` (offense red /
  defense blue / support green / control purple), `ability_synergy_active(ab,caster)`, and
  `ability_effective_cost(ab,caster)` = `max(1, energy_cost - (synergy?1:0))` with a free-ability
  (≤0) passthrough.
- `obj_combat_controller/Create_0`: `player.turn_cast_categories = {}` (after `ability_cd` init).
- `obj_combat_controller/Step_0`: reset the tracker in the single `need_player_status_tick`
  player-turn-start block. In the cast block, `_syn_elig` folds a `-1` (floor 1, guarded `>0`) into
  BOTH the affordability gate and the spend, composing with Quickcast/Cracked Focus/Gatewarden;
  category marked via `player.turn_cast_categories[$ ability_category(ab)] = true` right after the
  spend commits (so the FIRST of a category always pays full). Logs a "<Category> synergy: -1 AP!"
  line. Only AP discounted; secondary resources untouched.
- Single ability cast/spend path confirmed (only `ability_spend_resources` call sites in the
  controller are in that one block), so the discount + marking are centralized.

### Build notes (Phase 3, 2026-06-26, not compile-tested)
- `scr_abilities.gml`: split the secondary-resource check out of `ability_can_cast` into
  `ability_secondary_ok(ability,caster)` (so the UI can gate on synergy-discounted AP while still
  checking souls/blood/prep) — `ability_can_cast` behaviour unchanged. Added `ability_category_tag`.
- `ui_draw_ability_buttons` (scr_ui.gml): affordability + pip count now use
  `ability_effective_cost(ab,caster)`; lit pips turn GREEN when discounted (yellow otherwise);
  unselected button border tinted by `ability_category_color`. Free abilities still draw 0 pips.
- `ui_draw_ability_detail` (Tab popup): category-coloured role chip in the header (top-right) +
  a "<Role> — same-role synergy" section explaining the −1 AP discount. (Per M: category text
  lives in the in-depth Tab popup, NOT in `ability_effect_full`, to keep dense rows clean.)
- Loadout list rows + the 4 selected slots (obj_hub_controller/Draw_64) and the Vex ability rows
  (scr_ui.gml ~4258): thin category-colour accent bar on the left edge of each row.
- Compendium: new "Ability Synergy" section (role categories, same-role discount, why it matters,
  what's discounted) after "AP / Turn Economy".

Builds on [[project_viability_pass]] (reactions) and the attack-class system. Pairs with the
weapon-roles work but is independent — can be built before or after.
**Phase 3 BUILT 2026-06-26 — feature now complete (Phases 1–3). Not compile-tested.**
