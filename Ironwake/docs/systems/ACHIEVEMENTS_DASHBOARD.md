# Steamworks Dashboard — Achievement Definitions (paste-ready)

Entry order below = the spec's group order = intended dashboard order.
Steamworks admin → your app → **Stats & Achievements → Achievements → New Achievement**.
For each row: paste API Name, Display Name, Description; set Hidden where marked;
upload `_for_review\achievement_icons\<API>.png` (Achieved) and `<API>_locked.png` (Unachieved).

⚠ COUNT NOTE (08-05): the design-locked table actually holds **67** achievements, not the
63 in the spec headline — the 08-04 merge under-counted. All 67 are wired and have icons.
Trim candidates (if M wants fewer) remain: KILLS_1000, BONES, CRITS_500, PET_CURE, the
three Gatekeepers.

| # | API Name | Display Name | Description | Hidden |
|---|---|---|---|---|
| 1 | ACH_FIRST_BLOOD | First Blood | Win your first battle beneath Ironwake. | |
| 2 | ACH_GRAVEBREAKER | The Gravebreaker | Clear a full dungeon, boss and all. | |
| 3 | ACH_ITS_ALIVE | It's Alive | Hatch your first companion. | |
| 4 | ACH_FIRST_LEGEND | Hand-Authored | Find your first legendary. | |
| 5 | ACH_ACQUAINTED | Getting Acquainted | Deepen a companion's bond for the first time. | |
| 6 | ACH_REFORGED | Reforged | Have Dorn rework a piece of gear. | |
| 7 | ACH_KILLS_100 | Hundredfold | Fell 100 enemies, Gatsu. | |
| 8 | ACH_SLAYER | Purged | Fell 500 enemies. | |
| 9 | ACH_KILLS_1000 | Mountain of Skulls | Fell 1,000 enemies. | |
| 10 | ACH_SURVIVOR | The Survivor | Finish 25 runs, one way or another. | |
| 11 | ACH_GOLDHAND | The Goldhanded | Haul 10,000 gold out of the dark. | |
| 12 | ACH_LEGEND | Ascended | Reach permanent level 10. | |
| 13 | ACH_COLLECTOR | Collector | Discover half the item codex. | |
| 14 | ACH_CURATOR | Curator | Complete the item codex. | |
| 15 | ACH_FC_DEPTHS | Gatekeeper of Ash | Fully clear the Scorched Depths. | |
| 16 | ACH_FC_TOMB | Gatekeeper of Frost | Fully clear the Tundra Tomb. | |
| 17 | ACH_FC_VAULT | Gatekeeper of Dust | Fully clear the Ashen Vault. | |
| 18 | ACH_BOSSES_10 | Bossbreaker | Slay 10 bosses. | |
| 19 | ACH_DUELIST_5 | Old Rivals | Cross blades with the Ashen Duelist five times. | |
| 20 | ACH_NO_DAMAGE | Perfect Read | Win a combat without taking a scratch. | |
| 21 | ACH_ABSORB_500 | Anvil Soul | Weather 500 damage in a single run. | |
| 22 | ACH_CRITS_50 | Critical Habit | Land 50 critical hits. | |
| 23 | ACH_CRITS_500 | Executioner's Rhythm | Land 500 critical hits. | |
| 24 | ACH_DETONATE_25 | Detonator | Trigger 25 status detonations. | |
| 25 | ACH_CLR_ARCANIST | Soulbinder | Clear a dungeon as the Arcanist. | |
| 26 | ACH_CLR_BLOOD | Bloodsworn | Clear a dungeon as the Bloodwarden. | |
| 27 | ACH_CLR_SHADOW | Nightfall | Clear a dungeon as the Shadowstrider. | |
| 28 | ACH_FLAMEWALKER | Flamewalker | Fully clear the Scorched Depths at Awakening 5. | |
| 29 | ACH_TOMBWARDEN | Tombwarden | Fully clear the Tundra Tomb at Awakening 5. | |
| 30 | ACH_VAULTBREAKER | Vaultbreaker | Fully clear the Ashen Vault at Awakening 5. | |
| 31 | ACH_SPECIES_5 | Growing Menagerie | Hatch 5 different species. | |
| 32 | ACH_SPECIES_10 | Full Menagerie | Hatch 10 different species. | |
| 33 | ACH_SCION_1 | Blood of the Boss | Hatch a scion — a creature of a boss's own line. | |
| 34 | ACH_SCION_2 | Twice-Marked | Hatch scions of two different lines. | |
| 35 | ACH_SCION_ADULT | Scion Ascendant | Raise a scion to adulthood. | |
| 36 | ACH_SOULBOUND | The Soul-bound | Reach the deepest bond a companion can hold. | |
| 37 | ACH_AWAKENER | The Awakener | Raise a companion to its Awakened form. | |
| 38 | ACH_CORRUPTED | What Have You Done | A companion falls to corruption. | ✔ |
| 39 | ACH_CORRUPT_ADULT | Loved Anyway | Raise a corrupted companion to adulthood, uncured. | ✔ |
| 40 | ACH_PET_CURE | Purged Clean | Cure a companion's corruption. | |
| 41 | ACH_BELOVED | The Beloved | Reach Lover standing with someone in Ironwake. | |
| 42 | ACH_REMEMBERS | The Town Remembers | Betray a keeper. Ironwake does not forget. | ✔ |
| 43 | ACH_KEPT_WORD | Kept Your Word | See a keeper's questline through to the end. | |
| 44 | ACH_PILLAR | Pillar of the Community | Stand at Friend or better with every keeper. | |
| 45 | ACH_BOARD_25 | The Town Provides | Complete 25 tavern-board requests. | |
| 46 | ACH_ASCENDING | Ascending | Clear a run at Awakening 1 or higher. | |
| 47 | ACH_AWAKENING_3 | The Ladder Climbs | Clear a run at Awakening 3 or higher. | |
| 48 | ACH_DEEP_END | Into the Deep End | Clear a run at Awakening 5. | |
| 49 | ACH_DESCENT_OPEN | Beyond the Veil | Unlock The Descent. | |
| 50 | ACH_DESCENT_10 | Ten Fathoms | Reach floor 10 of The Descent. | |
| 51 | ACH_DESCENT_25 | The Long Fall | Reach floor 25 of The Descent. | |
| 52 | ACH_DESCENT_50 | Bottom of the World | Reach floor 50 of The Descent. | |
| 53 | ACH_DEATHLESS | The Deathless | Ten full clears without a single death between them. | |
| 54 | ACH_STANDS | IRONWAKE STANDS | Reach the ending. | ✔ |
| 55 | ACH_PACT_BOUND | Pact-Bound | Win a run carrying a curse. | ✔ |
| 56 | ACH_CURSES_3 | Glutton for Punishment | Win a run carrying three or more curses. | |
| 57 | ACH_MEGA_CURSE | Pact Sealed | Win a run under one of the dark's heaviest curses. | |
<!-- M CONFIRMED 08-06: "heaviest curse" = a TIER-3 ALTAR curse (Doom / Damnation /
     Ruin / Devil's Pact), on a full clear. NOT the stacked cursed-rebirth item
     sense of "mega-cursed" used elsewhere in the code. Wired as built. -->
| 58 | ACH_IRON_VOW | Iron Vow | Win under a sworn Vow. | |
| 59 | ACH_HIGH_ROLLER | High Roller | Win the High Table tournament. | |
| 60 | ACH_BONES | Bones | Win a game of knucklebones. | |
| 61 | ACH_BREW | Cauldron Roulette | Drink a Chaotic Brew and live out the run. | |
| 62 | ACH_REBIRTH | Born Again Wrong | Complete a cursed-rebirth ceremony. | |
| 63 | ACH_FORGE_LEGEND | Smith of Legends | Forge a legendary of your own making. | |
| 64 | ACH_WEB_COMPLETE | Web Complete | Weave an ability's talent web to its cap. | |
| 65 | ACH_BANSHEE | Banshee in a Bottle | Free your first song. | ✔ |
| 66 | ACH_SONGS_5 | Growing Choir | Free 5 songs. | |
| 67 | ACH_SONGS_ALL | The Choir Complete | Free every song. | |
