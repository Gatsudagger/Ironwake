# Abilities Expansion — IMPLEMENTED (2026-06-19)

## Implementation notes / deviations (read these)
- **Singularity** ships as a heavy *single-target* elemental nuke (32 base), not true
  AoE — the combat engine has no multi-target damage path (existing Rift / Smoke Bomb
  are single-target too). Wording kept accurate ("arcane detonation").
- **Damage-taken debuffs** (Mana Sever +4, Bonebreaker +5) apply a visible `debuff`
  status but do NOT yet amplify incoming damage — the engine never reads debuff
  magnitude (same gap as existing Curse / Marrow Crush). They DO persist as statuses
  and feed **Killing Spree**'s "+5 per debuff/trap on target" bonus, which is wired.
- **char_level** ability gating reads a new persistent `global.highest_run_level`
  (ratcheted in `grant_xp`, saved/loaded), since `run_level` resets every run.
- **Prospector** hooks `drop_equipment`'s rarity roll (`_rarity++`, capped at 4), so it
  improves *all* equipment drops, not strictly combat loot — a strict buff either way.
- **Loadout list now scrolls**: class pool (13) + general (4) = 17 rows exceeds the
  screen. `loadout_list_scroll()` windows 10 rows; renderer (Draw_64) and mouse
  hit-test (Step_0) share it. ▲/▼ "more" indicators added.
- New self abilities are name-hooked in `obj_combat_controller/Step_0` (Second Wind
  secondary refund, Adrenaline Rush +1 AP once/combat via `player.adrenaline_used`,
  Sanguine Pact HP→Blood, Vanish untargetable + `player.vanish_bonus`). Damage riders
  (Arcane Echo soul-scaling, Killing Spree, Vanish ambush) are in the pre-crit block.
- Vex sells `vex`-type only via new `class_vex_purchasable()`; goal abilities never
  appear for sale. `class_locked_abilities()` is now dead (left in place).

---

# Abilities Expansion — DESIGN-LOCKED (M approved 2026-06-19)

15 new unlockables = **13 abilities + 2 traits**. The two utility/passive effects (loot
quality, death save) are TRAITS, not abilities, per M's "separate perk" call — the trait
system already is the passive-perk track (slotted pre-run, unlocked via progression).

Gating: ~75% Vex-gold, rest goal-gated for variety; strongest gated hardest. Vex pricing
is **tiered** (500 / 800 / 1200g) by power.

## How ability gating works (reuses trait unlock machinery)
`ability_is_unlocked(name)` is true when ANY holds:
- **free** — default starter, always available (not in the unlock table).
- **vex** — bought from Vex (Abilities tab) at its tiered price; persists in `unlocked_abilities`.
- **goal** — unlocks automatically/free when a progression goal is met
  (`char_level`, `dungeon_clears_total`, `total_boss_kills`), shown with its condition in the loadout.

`ability_unlock_info(name)` → `{ type, cost, goal_type, goal_value }`; not listed = free.
Vex's Abilities tab sells only `vex`-type; goal-type unlock on their own.

## Vex price tiers
- **500g** — utility / sidegrade
- **800g** — strong
- **1200g** — powerful / ultimate

## NEW ABILITIES (13: 4 general + 9 class)

### GENERAL POOL — any class (new `global.abilities_general`, class_req -1)
| Ability | Gate | AP | Effect |
|---|---|---|---|
| **Strike** | free | 1 | 10 physical dmg, 85 acc, precision crit. Reliable cheap attack for every class. |
| **Field Dressing** | free | 1 | Self-heal 12 HP. Basic sustain. |
| **Second Wind** | vex 500g | 2 | Self-heal 10 + restore 1 secondary resource (souls/blood/prep). |
| **Adrenaline Rush** | vex 800g | 0 | +1 AP this turn, once per combat (slot version of Energy Tonic). |

### ARCANIST (+3)
| Ability | Gate | AP | Effect |
|---|---|---|---|
| **Mana Sever** | vex 500g | 2 | 10 void dmg + damage-dealt debuff on target. |
| **Arcane Echo** | goal: char level 6 | 3 (1 soul) | Elemental nuke that scales with souls held. |
| **Singularity** | goal: 3 boss kills | 3 (3 souls) | 22 elemental AoE to all enemies. Ultimate. |

### BLOODWARDEN (+3)
| Ability | Gate | AP | Effect |
|---|---|---|---|
| **Sanguine Pact** | vex 500g | 1 | Spend HP to gain a burst of Blood. |
| **Bonebreaker** | goal: char level 6 | 3 | 18 physical + armor-shred debuff (target takes more dmg, 3 turns). |
| **Crimson Apex** | goal: 3 boss kills | 3 (3 blood) | Big heal + heavy hit. Ultimate. |

### SHADOWSTRIDER (+3)
| Ability | Gate | AP | Effect |
|---|---|---|---|
| **Flurry** | vex 800g | 2 | 16 physical, high precision crit. |
| **Vanish** | goal: char level 6 | 1 | Untargetable 1 attack, next hit bonus dmg (Blink-style status). |
| **Killing Spree** | goal: 3 boss kills | 3 (2 prep) | Bonus dmg per debuff/trap on target. Ultimate. |

## NEW TRAITS (2) — the "perk" track, `global.traits_all`
| Trait | Unlock | Effect | Hook |
|---|---|---|---|
| **Prospector** | dungeon_clears_total 2 | Combat loot rolls one quality tier better (improved rare chance). | scr_stats drop roll |
| **Last Stand** | total_boss_kills 3 | First time you'd hit 0 HP each dungeon run, survive at 1 HP. Once per run. | combat lethal-damage path; `global.last_stand_used` reset in end_run |

(Renamed from the proposal to avoid clashing with existing "Sense" / "Treasure Hunter" / "Undying".)

## Re-tiered prices for EXISTING vex abilities (currently flat 500g)
- **Arcanist:** Soul Harvest 500, Curse 500, Soul Shield 500, Entropy 800, Rift 1200, Soulbind 1200
- **Bloodwarden:** Bloodthorn Aura 500, Plague Touch 500, Marrow Crush 800, Vital Theft 800, Undying 1200, Bloodfeast 1200
- **Shadowstrider:** Smoke Bomb 500, Crippling Shot 500, Marked for Death 500, Spike Trap 800, Evasive Roll 800, Death Snare 1200

## Implementation scope (all .gml — no .yy edits)
- `scr_abilities`: `global.abilities_general` + 13 ability_define blocks (+ desc_short/full);
  the 2 new traits in `global.traits_all`; `ability_unlock_info` / `ability_unlock_cost` /
  `ability_unlock_condition_text`; generalize `ability_is_unlocked` (free/vex/goal);
  `abilities_class_pool(class_id)` (class + general); `ability_in_loadout(name)`;
  `goal_met(type, value)` helper (shared with trait unlock checks if convenient).
- `obj_game_controller/Create_0`: add the 2 trait keys to `traits_unlocked`; `last_stand_used` run flag.
- Loadout pool sites → `abilities_class_pool`: hub `Step_0` (default + overlay), hub `Draw_64`
  (overlay), `obj_combat_controller/Create_0`.
- Vex Abilities tab (`scr_ui` draw + gc `Step_0`): list/sell only vex-type, charge `ability_unlock_cost`.
- Loadout draw: goal-locked ability rows show their condition; vex rows show their price.
- `scr_stats`: Prospector loot-quality hook in the drop roll.
- `obj_combat_controller`/`scr_combat`: Last Stand death-save hook; reset `last_stand_used` in `end_run`.
- `scr_save`: `unlocked_abilities` already persists; add the 2 new traits to the unlocked registry
  (already saved generically); goal unlocks derived, no extra save.
</content>
