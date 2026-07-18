# Ironwake — Steam Achievements (design for M sign-off)

32 achievements. Drafted 2026-07-17 for the Steam launch (STEAM_LAUNCH_CHECKLIST.md §4.3).
You enter these in App Admin → Stats & Achievements; Claude wires `steam_set_achievement("API_NAME")`
at each firing hook once GMEXT-Steamworks is installed. Deliberately front-loaded with easy
"onboarding" unlocks (high completion % helps Steam's discovery algorithm), tapering to hard
mastery + a few hidden/spoiler ones.

**Feasibility key:**
- `TRACKED` = fires off state the game already stores (often an existing `epithet_*` check or counter). Trivial.
- `HOOK` = needs a one-line `steam_set_achievement` at an existing event site (a "first X"). Easy.
- `+FLAG` = needs a tiny new counter/flag first, then a hook. Small.

Hidden = don't reveal name/desc until unlocked (spoilers / thematic reveal).

---

## Onboarding (early, high completion %)
| API name | Display | Description | Hidden | Firing hook |
|---|---|---|---|---|
| ACH_FIRST_BLOOD | First Blood | Win your first battle. | — | HOOK: first combat victory (`total_kills` first ↑ / victory) |
| ACH_GRAVEBREAKER | The Gravebreaker | Clear a full dungeon. | — | TRACKED: `epithet_unlocked("gravebreaker")` / `dungeon_clears_total>=1` |
| ACH_ITS_ALIVE | It's Alive | Hatch your first companion. | — | HOOK: pet hatch event (`snd_pet_hatch` site) |
| ACH_FIRST_LEGEND | Hand-Authored | Find your first legendary item. | — | HOOK: first drop of rarity 4 (`discover_item` / drop) |
| ACH_ACQUAINTED | Getting Acquainted | Raise any keeper to the first bond tier. | — | HOOK: first affinity tier-up |
| ACH_REFORGED | Reforged | Rework an item's affixes at Dorn. | — | HOOK: `chit_reforge_item` success (the new REFORGE tab) |

## Progression milestones
| API name | Display | Description | Hidden | Firing hook |
|---|---|---|---|---|
| ACH_SLAYER | Slayer of Hundreds | 500 lifetime kills. | — | TRACKED: `epithet_unlocked("slayer")` / `total_kills>=500` |
| ACH_SURVIVOR | The Survivor | Finish 25 runs. | — | TRACKED: `epithet_unlocked("survivor")` / `run_count>=25` |
| ACH_GOLDHAND | The Goldhanded | Earn 10,000 lifetime gold in the dungeons. | — | TRACKED: `epithet_unlocked("goldhand")` |
| ACH_LEGEND | The Legend | Reach permanent level 10. | — | TRACKED: `epithet_unlocked("legend")` |
| ACH_COLLECTOR | Collector | Discover half the item codex. | — | +FLAG: discovered-count ≥ half of catalog |
| ACH_CURATOR | Curator | Complete the item codex. | — | +FLAG: all items discovered |

## Class mastery
| API name | Display | Description | Hidden | Firing hook |
|---|---|---|---|---|
| ACH_CLR_ARCANIST | Soulbinder | Clear a dungeon as the Arcanist. | — | +FLAG: dungeon clear + `class_id==0` |
| ACH_CLR_BLOOD | Bloodsworn | Clear a dungeon as the Bloodwarden. | — | +FLAG: clear + `class_id==1` |
| ACH_CLR_SHADOW | Nightfall | Clear a dungeon as the Shadowstrider. | — | +FLAG: clear + `class_id==2` |

## Dungeon mastery (hard — the A5 epithets)
| API name | Display | Description | Hidden | Firing hook |
|---|---|---|---|---|
| ACH_FLAMEWALKER | Flamewalker | Full-clear the Scorched Depths at Awakening 5. | — | TRACKED: `epithet_unlocked("flamewalker")` |
| ACH_TOMBWARDEN | Tombwarden | Full-clear the Tundra Tomb at Awakening 5. | — | TRACKED: `epithet_unlocked("tombwarden")` |
| ACH_VAULTBREAKER | Vaultbreaker | Full-clear the Ashen Vault at Awakening 5. | — | TRACKED: `epithet_unlocked("vaultbreaker")` |

## Companion
| API name | Display | Description | Hidden | Firing hook |
|---|---|---|---|---|
| ACH_SOULBOUND | The Soul-bound | Raise a companion to Soul-bound (Bond 18). | — | TRACKED: `epithet_unlocked("soulbound")` |
| ACH_AWAKENER | The Awakener | Raise a companion to its Awakened form. | — | TRACKED: `epithet_unlocked("awakener")` |
| ACH_CORRUPTED | What Have You Done | Let a companion fall to corruption. | ✔ | HOOK: pet reaches corrupted stage |

## Town bonds
| API name | Display | Description | Hidden | Firing hook |
|---|---|---|---|---|
| ACH_BELOVED | The Beloved | Reach Lover with someone in Ironwake. | — | TRACKED: `epithet_unlocked("beloved")` |
| ACH_REMEMBERS | The Town Remembers | Betray one of Ironwake's keepers. | ✔ | HOOK: betrayal event (betrayed flag) |
| ACH_KEPT_WORD | Kept Your Word | Complete a keeper's personal quest line. | — | +FLAG: a keeper questline completes |
| ACH_PILLAR | Pillar of the Community | Reach Friend or higher with every keeper. | — | +FLAG: all affinities ≥ Friend |

## Endgame / mastery
| API name | Display | Description | Hidden | Firing hook |
|---|---|---|---|---|
| ACH_ASCENDING | Ascending | Clear a run at Awakening 1 or higher. | — | HOOK: clear with `awakening_level>=1` |
| ACH_DEEP_END | Into the Deep End | Reach Awakening 5. | — | HOOK: `awakening_level>=5` reached |
| ACH_DEATHLESS | The Deathless | Earn 10 full clears with no death between them. | — | TRACKED: `epithet_unlocked("deathless")` |
| ACH_STANDS | IRONWAKE STANDS | Reach the ending — the town endures. | ✔ | TRACKED: `global.ironwake_stands == true` |

## Skill / fun / hidden
| API name | Display | Description | Hidden | Firing hook |
|---|---|---|---|---|
| ACH_HIGH_ROLLER | High Roller | Win the High Table dice tournament. | — | HOOK: High Table victory |
| ACH_BONES | Bones | Win a game of Knucklebones. | — | HOOK: Knucklebones win |
| ACH_PACT_BOUND | Pact-Bound | Complete a run while carrying a curse. | ✔ | +FLAG: curse active at clear |
| ACH_BANSHEE | Banshee in a Bottle | Free the banshee. | ✔ | HOOK: banshee music unlock (SAVE v3) |

---

## Notes for wiring (later session)
- **Cheapest to ship first:** the 12 `TRACKED` ones — the `epithet_unlocked()` / counter checks
  already exist, so wiring is a single call at the point epithets/counters update (e.g. a
  post-run `achievements_sync()` that walks the epithet ids). No new state.
- **`+FLAG` ones** (codex tiers, per-class clears, questline, all-friends, curse-at-clear) each
  need a tiny bit of new tracking — batch them when we do the SDK session.
- **Steam rule:** achievements are boolean; back the count-based ones (kills/gold/runs) with a
  Steam *stat* only if you want the % progress bar, otherwise a plain boolean at the threshold
  is fine and simpler.
- **Count check:** 32 is a healthy roguelite spread (Steam sweet spot ~15–40). If you want fewer,
  the first cut candidates are ACH_BONES + ACH_PACT_BOUND. If more, add per-dungeon *first-clear*
  (non-A5) and an "Awakening 3" mid-tier.
- Order in the dashboard by the groups above (Steam shows them in entry order).
