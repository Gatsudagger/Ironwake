# Ironwake — Steam Achievements (DESIGN-LOCKED 2026-08-04, merged)

**Merge of the 07-17 draft (32, epithet-grounded) + M's 08-04 additions (~34 after dupe
unification). ⚠ ACTUAL COUNT: the locked table below holds 67 achievements — the 08-04
"63" headline under-counted its own rows (caught 08-05 by the icon batch). All 67 are
wired + have icons; trim candidates at bottom if M wants fewer.** M approved the merge
08-04. Steam sweet spot is 15–40 but roguelites run 50–80 routinely.

Wiring: GMEXT-Steamworks (Steam builds only; all calls guarded `steam_initialised()`,
Android/itch no-op). Thin wrapper `ach_unlock("ACH_X")` + post-run/post-load
`achievements_sync()` that walks epithets/counters (also retro-grants for existing saves).

**Key:** TRACKED = existing state/epithet. HOOK = one line at existing event site.
+FLAG = tiny new counter first. Hidden = ✔ (no name/desc until unlocked).

## Onboarding
| API | Display | Condition | How |
|---|---|---|---|
| ACH_FIRST_BLOOD | First Blood | win first battle | HOOK |
| ACH_GRAVEBREAKER | The Gravebreaker | clear a full dungeon | TRACKED epithet |
| ACH_ITS_ALIVE | It's Alive | hatch first companion | HOOK |
| ACH_FIRST_LEGEND | Hand-Authored | first legendary drop | HOOK |
| ACH_ACQUAINTED | Getting Acquainted | first bond tier-up | HOOK |
| ACH_REFORGED | Reforged | reforge at Dorn | HOOK |

## Progression
| API | Display | Condition | How |
|---|---|---|---|
| ACH_KILLS_100 | Hundredfold | 100 lifetime kills | TRACKED total_kills |
| ACH_SLAYER | Slayer of Hundreds | 500 lifetime kills | TRACKED epithet |
| ACH_KILLS_1000 | Thousandfold | 1,000 lifetime kills | TRACKED total_kills |
| ACH_SURVIVOR | The Survivor | finish 25 runs | TRACKED epithet |
| ACH_GOLDHAND | The Goldhanded | 10,000 lifetime dungeon gold | TRACKED epithet |
| ACH_LEGEND | The Legend | permanent level 10 | TRACKED epithet |
| ACH_COLLECTOR | Collector | discover half the codex | +FLAG count |
| ACH_CURATOR | Curator | complete the codex | +FLAG count |
| ACH_FC_DEPTHS | Gatekeeper of Ash | first full clear: Scorched Depths | +FLAG per-dungeon |
| ACH_FC_TOMB | Gatekeeper of Frost | first full clear: Tundra Tomb | +FLAG per-dungeon |
| ACH_FC_VAULT | Gatekeeper of Dust | first full clear: Ashen Vault | +FLAG per-dungeon |

## Combat skill
| API | Display | Condition | How |
|---|---|---|---|
| ACH_BOSSES_10 | Bossbreaker | slay 10 bosses | TRACKED total_boss_kills |
| ACH_DUELIST_5 | Old Rivals | face the Ashen Duelist 5× | TRACKED duelist_encounters |
| ACH_NO_DAMAGE | Perfect Read | win a combat taking 0 damage | +FLAG combat flag |
| ACH_ABSORB_500 | Anvil Soul | absorb 500+ dmg in one run (incl. shield/block/mitigation) | +FLAG run accumulator |
| ACH_CRITS_50 | Critical Habit | 50 lifetime crits | +FLAG lifetime counter |
| ACH_CRITS_500 | Executioner's Rhythm | 500 lifetime crits | +FLAG same counter |
| ACH_DETONATE_25 | Detonator | 25 status detonations | +FLAG lifetime counter |

## Class mastery
| API | Display | Condition | How |
|---|---|---|---|
| ACH_CLR_ARCANIST | Soulbinder | clear a dungeon as Arcanist | +FLAG class at clear |
| ACH_CLR_BLOOD | Bloodsworn | clear as Bloodwarden | +FLAG |
| ACH_CLR_SHADOW | Nightfall | clear as Shadowstrider | +FLAG |

## Dungeon mastery (A5 epithets)
| API | Display | Condition | How |
|---|---|---|---|
| ACH_FLAMEWALKER | Flamewalker | Scorched Depths full clear @ A5 | TRACKED epithet |
| ACH_TOMBWARDEN | Tombwarden | Tundra Tomb full clear @ A5 | TRACKED epithet |
| ACH_VAULTBREAKER | Vaultbreaker | Ashen Vault full clear @ A5 | TRACKED epithet |

## Companions
| API | Display | Condition | How |
|---|---|---|---|
| ACH_SPECIES_5 | Growing Menagerie | hatch 5 different species | +FLAG species set |
| ACH_SPECIES_10 | Full Menagerie | hatch 10 different species | +FLAG same |
| ACH_SCION_1 | Blood of the Boss | hatch a scion (signature) species | HOOK signature flag |
| ACH_SCION_2 | Twice-Marked | hatch 2 different scion species | +FLAG scion set |
| ACH_SCION_ADULT | Scion Ascendant | raise a scion to adulthood | HOOK stage+signature |
| ACH_SOULBOUND | The Soul-bound | bond 18 (Soul-bound) | TRACKED epithet |
| ACH_AWAKENER | The Awakener | raise to Awakened form | TRACKED epithet |
| ACH_CORRUPTED ✔ | What Have You Done | a companion falls to corruption | HOOK |
| ACH_CORRUPT_ADULT ✔ | Loved Anyway | corrupted companion reaches adulthood uncured | HOOK stage+corruption |
| ACH_PET_CURE | Purged Clean | cure a companion's corruption | HOOK pet_corruption_cure |

## Town
| API | Display | Condition | How |
|---|---|---|---|
| ACH_BELOVED | The Beloved | reach Lover with someone | TRACKED epithet |
| ACH_REMEMBERS ✔ | The Town Remembers | betray a keeper | HOOK betrayal |
| ACH_KEPT_WORD | Kept Your Word | complete a keeper questline | +FLAG |
| ACH_PILLAR | Pillar of the Community | Friend+ with every keeper | +FLAG |
| ACH_BOARD_25 | The Town Provides | complete 25 board requests | +FLAG lifetime counter |

## Endgame
| API | Display | Condition | How |
|---|---|---|---|
| ACH_ASCENDING | Ascending | clear a run at Awakening 1+ | HOOK |
| ACH_AWAKENING_3 | The Ladder Climbs | reach Awakening 3 | HOOK |
| ACH_DEEP_END | Into the Deep End | reach Awakening 5 | HOOK |
| ACH_DESCENT_OPEN | Beyond the Veil | unlock The Descent (triple-A5 win) | HOOK |
| ACH_DESCENT_10 | Ten Fathoms | Descent floor 10 | TRACKED descent_floor |
| ACH_DESCENT_25 | The Long Fall | Descent floor 25 | TRACKED descent_floor |
| ACH_DESCENT_50 | Bottom of the World | Descent floor 50 | TRACKED descent_floor |
| ACH_DEATHLESS | The Deathless | 10 full clears with no death between | TRACKED epithet |
| ACH_STANDS ✔ | IRONWAKE STANDS | reach the ending | TRACKED flag |

## Risk
| API | Display | Condition | How |
|---|---|---|---|
| ACH_PACT_BOUND ✔ | Pact-Bound | win a run carrying a curse | +FLAG |
| ACH_CURSES_3 | Glutton for Punishment | win a run with 3+ curses | +FLAG same site |
| ACH_MEGA_CURSE | Pact Sealed | win a run with a mega curse | +FLAG same site |
| ACH_IRON_VOW | Iron Vow | win under a Vow (hardcore) | HOOK vow flag at win |

## Elaborate / fun
| API | Display | Condition | How |
|---|---|---|---|
| ACH_HIGH_ROLLER | High Roller | win the High Table tournament | HOOK |
| ACH_BONES | Bones | win a game of Knucklebones | HOOK |
| ACH_BREW | Cauldron Roulette | drink a Chaotic Brew and survive the run | +FLAG |
| ACH_REBIRTH | Born Again Wrong | complete a cursed-rebirth ceremony | HOOK |
| ACH_FORGE_LEGEND | Smith of Legends | forge a legendary | HOOK |
| ACH_WEB_COMPLETE | Web Complete | fill an entire talent web | HOOK node count |
| ACH_BANSHEE ✔ | Banshee in a Bottle | free your first song | HOOK |
| ACH_SONGS_5 | Growing Choir | free 5 songs | TRACKED freed count |
| ACH_SONGS_ALL | The Choir Complete | free every song | TRACKED count==pool |

## Wiring status (08-04, first pass — extension-safe, compiles without GMEXT)
**CORE BUILT** in scr_stats.gml (end of file): `ach_unlock()` (dynamic
asset_get_index/script_execute — no-ops without the extension), `ach_counters_init()`
(+ save/load in scr_save, no version bump), `ach_record_hatch()`, `achievements_sync()`
(walks all state-derived conditions; called every ~5s from gc Step + at pet_hatch;
this is also the retro-grant path).

**LIVE via sync (~40):** all 11 epithet-backed, FIRST_BLOOD/KILLS_100/KILLS_1000,
BOSSES_10, DUELIST_5, STANDS, ASCENDING/AWAKENING_3/DEEP_END (from run-record
ascendance), DESCENT_OPEN (triple-A5 derive), DESCENT_10/25/50 (descent_best + live),
BANSHEE/SONGS_5/SONGS_ALL, ITS_ALIVE, SPECIES_5/10 + SCION_1/2 (lifetime sets fed by
pet_hatch), SCION_ADULT, CORRUPTED, CORRUPT_ADULT, PET_CURE (also hooked at cure site),
AWAKENER, plus the counter thresholds below once their sites are wired.

**DONE 08-05 — counter increment sites (all wired):**
- crits++ inside `combat_roll_crit` (scr_combat — only player rolls reach it)
- detonations++ at the post-damage reaction block (Step_0, `_react_key != ""` on a landed hit)
- `ach_run_absorbed += damage` in `combat_apply_damage` player branch. v1 CAVEAT: counts
  damage ARRIVING at the HP sink — shield-absorbed portions never reach it (undercount).
  Reset to 0 in end_run (plus new-save default), so each dive starts clean.
- board_done++ in `quest_turn_in` (non-gate path = the tavern-board requests)

**DONE 08-05 — event hooks (all wired):** ACQUAINTED (pet_bond_gain tier crossing),
REFORGED (chit_reforge_item success), FIRST_LEGEND (drop_equipment final rarity 4, past
the awakening gate), REMEMBERS (affinity_betrayal_for), KEPT_WORD (quest_turn_in gate
tier 4 = Lover rung), HIGH_ROLLER (High Table champion branch, gc Step), BONES
(knucklebones win resolve, gc Step), BREW (`global.ach_brew_run` set at both
chaotic_brew_roll drink sites; unlocked in end_run on result >= 0), REBIRTH
(cursed_rebirth_commit), FORGE_LEGEND (forge_build_item — single caller = commit path),
NO_DAMAGE (victory flawless branch, Step_0), IRON_VOW / PACT_BOUND / CURSES_3 /
MEGA_CURSE (end_run result == 1; **"mega curse" interpreted as a tier-3 altar curse** —
Doom/Damnation/Ruin/Devil's Pact — flag for M if he meant something else),
FC_DEPTHS/TOMB/VAULT + CLR_* (end_run result == 1 reading selected_dungeon +
chosen_class), WEB_COMPLETE / COLLECTOR / CURATOR / PILLAR (added to achievements_sync:
any web at the 4-pick cap; codex discovered vs item_codex_master_list; all keepers at
affinity tier >= 2).

**TODO — outside code:** GMEXT-Steamworks import (GM closed). DONE 08-05: 67 icons
composited (color + _locked grayscale, 256×256, contact sheet) → _for_review\
achievement_icons\, awaiting M's batch approval; paste-ready dashboard table with
player-facing descriptions → ACHIEVEMENTS_DASHBOARD.md.

## Build notes
- **63 total.** Trim candidates if M wants ~50: ACH_KILLS_1000, ACH_BONES, ACH_CRITS_500,
  ACH_PET_CURE, per-dungeon Gatekeepers (fold into ACH_GRAVEBREAKER). Do NOT trim M's
  explicit 08-04 asks (absorb/crits/detonate, scion+corrupted ladders, Descent 10/25/50,
  song ladder).
- New counters (+FLAG) persist as struct_exists-guarded optional save fields — no
  SAVE_FORMAT_VERSION bump expected.
- Retro-grant on first boot: achievements_sync() walks all TRACKED conditions.
- Steam stats (progress bars) skipped v1 — plain booleans at thresholds.
- Icons: 63 composited from existing in-game art (PIL, zero credits), 256×256, batched to
  _for_review\ for M approval. Dashboard entry order = the groups above.
- Steam allows adding achievements post-launch; shipped API names are permanent.
