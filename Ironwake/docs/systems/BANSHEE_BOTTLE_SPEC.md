# BANSHEE IN A BOTTLE — Unlockable Music Tracks (design-locked 2026-07-15)

M's scoping answers locked 07-14/15. No re-design loops; deviations get flagged, not improvised.

---

## 1. Concept

A very rare dungeon find, **Banshee in a Bottle**, banks to the stash on successful
extraction. Maren the Runesmith can **release the spirit** (free) — a lore popup plays
(bottle opens, banshee flies out, melodic scream) and the player is rewarded a **random
new background music track**. Unlocked tracks are assignable from the Settings menu:
one selector for **Hub Music**, one for **Dungeon Music**.

## 2. Locked decisions

| Decision | Ruling |
|---|---|
| Track source | **3 launch tracks from ElevenLabs** (M experiments with Suno separately; Suno tracks join the pool later) |
| Track length | **~2 min loops** — M's explicit sign-off to exceed the 10k-credit session cap |
| Pools | **Split**: 2 hub-mood tracks + 1 dungeon-mood track. Each settings row cycles only its own pool |
| Drop: guaranteed | **Final boss of each dungeon, first kill only, per save** (3 dungeons = 3 guaranteed) |
| Drop: random | Small chance at chest sites (treasure / vault / reliquary), **~4%, LCK/loot-bonus scaled** |
| Run rules | **Extract-or-lose, stackable**: rides run loot; die = lost, extract = banked via existing `end_run(0)` loot→stash flow |
| Release | **Free**, at Maren — new **5th tab "Spirits"** (tab bar reflows 4→5) |
| Pool exhausted | Further releases pay a **25 Rune Dust bounty** instead (never a dead drop) |
| Persistence | **Per-save**: unlocks + selected hub/dungeon track in the save file (bump `SAVE_FORMAT_VERSION` 2→3, fix-up defaults for old saves) |
| Reward roll | Random among **not-yet-owned** tracks (both pools weighted equally); duplicate-proof by construction |

## 3. Player flow

1. Kill a dungeon's final boss for the first time (per save) → bottle drops into run loot
   (splash/notice at loot screen; distinct rarity styling — it's an off-ladder relic-tier find).
   Chest sites can also roll one (~4%).
2. Extract (E / Lamp / Wine all route through the shared extraction bookkeeping) → bottle
   banks to stash. Death loses it like any carried loot.
3. Hub → Maren → **Spirits** tab: shows banked bottles + a released-spirits ledger
   (track names discovered so far, "?" rows for unowned).
4. Release → **lore popup** (gothic-framed, Bairc-intro idiom) with an animation phase:
   bottle opens → banshee ghost flies out → melodic scream stinger → reward text
   ("The spirit's song lingers... 'TRACK NAME' can now be chosen in Settings.")
   Any key dismisses after the animation lands (egg-hatch phase pattern).
5. Settings (pause → Settings): two new cyclable rows under the sliders —
   **Hub Music** and **Dungeon Music** — A/D (and Enter?) cycles `Default` + that pool's
   unlocked tracks. Change applies live if the relevant music is currently playing.

## 4. Music wiring

- Hub today: `audio_play_sound(Rainy_Memories, 1, true)` in `obj_hub_controller/Create_0.gml:140`.
  → route through `music_hub_track()` helper: returns selected unlocked track or `Rainy_Memories`.
- Dungeon today: `_2_dungeon_INITIAL` once then `_2_dungeon_LOOP` (floor controller Create/Step).
  → custom dungeon track **skips the intro/loop pair entirely** and just loops; the
  `dungeon_music_looping` handoff and both `audio_stop_sound` sites gain awareness of the
  custom track (single `music_dungeon_stop()` helper so no site needs the track list).
- New tracks register in `audio_sfx_assets()`'s music sibling `audio_music_assets()` so the
  Music volume slider governs them. Ambience beds unaffected.
- Combat rooms: unchanged (combat has its own audio); dungeon selection applies to floor rooms.

## 5. New assets

| Asset | Source | Notes |
|---|---|---|
| 3 music tracks (~2min): 2 hub-mood (melancholy dark-fantasy calm), 1 dungeon-mood (tense, driving) | ElevenLabs `compose_music` | ONE track gen → audition by M → report real credit cost → then tracks 2–3. Meter reported start + wrap |
| Banshee scream stinger (~3s, melodic wail, musical not horror-jumpscare) | ElevenLabs SFX | 2-strike rule applies |
| Bottle item icon | PixelLab | Style-sourced from existing unique-item icons; base to `_for_review\` before import |
| Release animation (bottle opens, ghost rises) | PixelLab animate_object | Base image approved by M BEFORE animating |
| Sound `.yy` + sprite `.yy` + `.yyp` entries | import script (tools/) | Same pipeline as import_sounds_loot.py; Igor load+link gate, M F5 = the compile |

## 6. Save / data shape (per save)

```
global.banshee_bottles_banked   // int, stash-side count
global.banshee_boss_drops       // struct: dungeon_id -> true once first-kill bottle granted
global.music_unlocked           // array of track ids, e.g. ["hub_emberfall"]
global.music_sel_hub            // "" = default, else track id (validated on load)
global.music_sel_dungeon        // "" = default, else track id
```
Track catalog is code-side (id, display name, pool, sound asset) — save stores ids only.
`SAVE_FORMAT_VERSION` 2→3; loader fix-up initializes all five for older saves.

## 7. Out of scope (flagged, not built)

- Per-dungeon music selection (one dungeon slot covers all three dungeons)
- Combat music selection
- Suno import pipeline specifics (built when M delivers first Suno track; catalog is ready for it)
- Steam AI-disclosure line gains "AI-generated music (ElevenLabs)" — goes with the pending v2 paste

## 8. Reference-sync sweep (mandatory before done)

- Item codex entry for Banshee in a Bottle (lore + "release at Maren" hint)
- Maren tab key legend / footer
- Settings overlay legend + row count (cursor bounds, mouse hit rects in audio_settings_handle_input)
- Any "Settings" tutorial/coach-mark text that enumerates rows
- UI collision check at 1920×1080 with longest track display name
