# Enemy Intent — implementation mini-spec

**Source:** ABILITY_AUDIT.md §5 (highest-leverage missing feature; approved by M 2026-07-03).
**Goal:** every enemy telegraphs its NEXT action so Defense/Control loadout picks become informed decisions. This is the Slay-the-Spire lesson: reactive abilities are only fun when you can see what's coming.
**Status:** BUILT 2026-07-04 (needs M F5). Implementation notes:
- `enemy_roll_intent` / `enemy_intent_estimate` / `enemy_intent_blocked` in scr_enemies.gml; chips render via `ui_draw_intent_chip` (scr_ui) above each HP bar (bar row pitch 78→108; the click hit-test in Step matches).
- Binding contract: execution reads `actor.intent.eab`; re-rolls fire at every action-consuming turn end (ability used, attack resolved, or whiffed vs Blink/Vanish/Shadow Step/Phantom Step). A controlled skip KEEPS the intent (chip greys with strike-through while the control holds).
- Text chips v1 (no icon sprites): red "ATK ~lo-hi" (+" x2" for double_strike), purple "CAST ~N", green "MEND", amber effect word (Stun/Root/Silence/Blind/Weaken/Expose/Wither/Wound). Bands are post-mitigation estimates (armor/resist/flat/percent layers; shields and reactive layers excluded).
- Telegraph-spike aware: a basic-attack intent uses telegraph_damage on spike rounds (the old red banner remains as drama on the turn before).
- Onboarding: "intent" coach-mark added to the combat tip cascade (after targeting, before inspect).
- v1 skips (per §5 + no current content): AoE marker (no player+pet-hitting enemy moves yet), boss "?" ambiguity, A4+ magnitude hiding.

## 1. What shows

Above each enemy's HP bar, one **intent chip** for the action it will take on its next turn:
- **Icon + tint by kind:** sword (attack, red) / scroll (spell, purple) / shield-up (buff/heal, green) / chains (control — root/silence/stun/debuff, amber).
- **Magnitude:** for damaging intents, the *approximate* damage band using the existing hit-preview math (e.g. "~12-16"). Buff/control intents show the effect word ("Stun", "Enrage") — no numbers.
- **AoE marker** when the action hits the player + pet or has splash.

## 2. How enemies decide (the honest-telegraph contract)

- Enemy AI currently picks its action **at execution time**. Change: each enemy rolls its next action **at the end of its previous turn** (and once at combat start) and stores it (`c.intent = { kind, ability, dmg_lo, dmg_hi }`).
- The stored intent is **binding** — the enemy does what it telegraphed. Exceptions allowed only when the telegraphed action became illegal (target died, enemy silenced/rooted out of it) → re-roll and **update the chip immediately** (chip pulses once so the change is visible).
- Control interactions become visible tactics: silence a "scroll" intent, root a melee "sword" intent, stun anything — the chip greys out with a strike-through when its action is blocked. **This is the payoff moment for the whole Control category.**

## 3. Tuning levers

- **Boss ambiguity (optional, ships later):** bosses may show a "?" on signature moves the first time (Darkest Dungeon-style dread), never on repeats.
- Awakening could hide magnitudes at A4+ (icon only) as a difficulty knob — deferred, playtest first.

## 4. Code seams

| Concern | Seam |
|---|---|
| Intent roll + store | enemy turn-end in obj_combat_controller Step (where the next enemy is advanced) + combat_init for the opening roll; reuse the existing enemy ability-selection logic, just called one turn early |
| Magnitude band | the existing hit-preview approximation helpers |
| Chip draw | obj_combat_controller Draw_64 beside the enemy name/HP row (reach/kind tag already drawn there — intent chip joins it) |
| Blocked-intent grey-out | where root/silence/stun currently cancel enemy actions |
| Onboarding | one coach-mark ("their next move is shown above their head") via the existing tutorial system |

## 5. Out of scope (v1)

Multi-turn previews, exact damage numbers, intent for summons-not-yet-spawned, player-side intent.
