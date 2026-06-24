# SYSTEMS — Enemy Sound Effects (family-themed)

**Status: BUILT (2026-06-23), not compile-tested in IDE.** Scope chosen by M: enemy
**death + attack** sounds, framework now (best-fit existing sounds + drop-in slots for
new audio). Replaces the old behavior where every enemy played the same human death
yell (`die5`).

## How it works
`enemy_sound_family(name)` (scr_combat) keyword-classifies an enemy NAME into one of
seven families. `enemy_death_sound(name)` / `enemy_attack_sound(name)` then play a
family sound via `play_enemy_sfx(preferred_name, fallback)`:
- If the audio asset named `preferred_name` **exists in the project**, it plays.
- Otherwise it falls back to a best-fit sound from the existing library.

So **new audio is plug-and-play**: name a file per the convention and it's picked up
with no code change (one small follow-up — see "Adding new sounds").

## Family taxonomy (first match wins — handles overlaps)
| Priority | Family | Name keywords | Example enemies |
|---|---|---|---|
| 1 | **boss** | malgrath, sovereign, eternal frost | Malgrath the Warden, Bone Sovereign, The Eternal Frost |
| 2 | **wraith** | wraith, specter, revenant, archivist, ghost | Dungeon/Ash/Vault/Snowbound Wraith, Ice Specter, Smoldering/Infernal Revenant, Pale Archivist |
| 3 | **construct** | golem, colossus, sentinel, guardian, stone | Stone/Cinder Golem, Bone Colossus, Vault/Frozen Sentinel, Vault Guardian |
| 4 | **beast** | imp, drake, slug, crawler, stalker, lurker, beast | Cinder Imp, Fire Drake, Magma Slug, Vault Crawler, Grave Stalker, Glacial Lurker/Beast |
| 5 | **fire** | cinder, magma, lava, ash, infernal, smolder, ember, flame, fire | Lava Spitter (others caught above by type) |
| 6 | **ice** | frost, ice, glacial, frozen, snow, pale, shard | Frost Shard, Frozen Thrall, Glacial Warden |
| 7 | **undead** (default) | skeleton, bone, tomb, grave, thrall, archon — and anything unmatched | Ashen Skeleton, Skeleton Archer, Tomb Archon |

Type beats element on purpose: a "Smoldering Revenant" should wail like a wraith, not
hiss like fire. Adjust keyword lists in `enemy_sound_family` if a specific enemy reads
wrong.

## Sound-name convention (what M adds in the IDE)
For each family, add up to two audio assets:
- `snd_death_<family>`  — played on the enemy's death
- `snd_attack_<family>` — played when the enemy attacks/casts (on hit OR miss)

Families: `undead, wraith, construct, beast, fire, ice, boss`. e.g.
`snd_death_fire`, `snd_attack_beast`, `snd_death_boss` (a roar), `snd_death_ice`
(a shatter). You don't need all of them — any that exist override the fallback;
any missing keep using it.

## Existing-library fallbacks (used until themed sounds are added)
| Family | death fallback | attack fallback |
|---|---|---|
| undead | die5 | attack1 |
| wraith | teleport | Magic |
| construct | grunt | attack1 |
| beast | grunt | grunt |
| fire | Magic | Magic |
| ice | teleport | spell1 |
| boss | die5 | grunt |

## Adding new sounds (the ONE follow-up step)
1. Import the audio file in the GameMaker IDE, named exactly `snd_death_<family>` /
   `snd_attack_<family>`.
2. **Add its bare identifier to `audio_sfx_assets()` in scr_stats** (the list at
   ~line 2457). This is required for TWO reasons: it routes the sound through the
   **SFX volume slider**, and it prevents the build from **stripping** the asset
   (string-only references get tree-shaken out — same gotcha as sprites). Claude does
   this edit once the asset exists (can't reference a not-yet-created asset by bare
   name). No other code change needed — `play_enemy_sfx` finds it by name.

## Integration points (files)
- **scr_combat**: `enemy_sound_family`, `play_enemy_sfx`, `enemy_death_sound`,
  `enemy_attack_sound` (just above `combat_on_enemy_defeated`).
- **Death calls:** `combat_on_enemy_defeated` (scr_combat) + the DoT-death path
  (obj_combat_controller/Step_0 ~1013).
- **Attack calls:** obj_combat_controller/Step_0 — offensive ability branch (~1147,
  non-heal) and the basic-attack pre-roll (~1205).
- **scr_stats** `audio_sfx_assets()` — register new snd_* here (volume + strip guard).
