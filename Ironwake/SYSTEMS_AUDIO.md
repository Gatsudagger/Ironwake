# SYSTEMS — Audio / Sound Settings

**Status: BUILT (verify in-IDE).** Player-facing volume control, split into **Music**
and **Sound Effects**, reachable from the **title screen and the hub** (key `O`).

---

## 1. Model
- Two globals, 0..1: `global.music_volume` (default 0.7), `global.sfx_volume` (default 0.8).
- Overlay state: `global.settings_open` (bool), `global.settings_cursor` (0 = Music, 1 = SFX).
- **No audio groups** are assigned in the IDE (that needs `.yy` edits we don't make), so
  volume is applied **per sound asset** via `audio_sound_gain(asset, gain, 0)`. In GMS2 the
  asset's gain persists to future instances, and as belt-and-suspenders we re-apply at the
  Create of every music-playing room.

## 2. Helpers (scr_stats.gml, end of file)
- `audio_music_assets()` / `audio_sfx_assets()` — the categorized asset lists (the single
  source of truth for which slider controls a sound). Add a new sound to the correct list.
- `audio_settings_init()` — defaults + one-time load from `settings.ini` (guarded by
  `global.settings_loaded`).
- `audio_settings_save()` — writes `settings.ini` (`[audio] music/sfx`). Global, independent
  of the per-slot save — volume set at the title persists even before choosing a slot.
- `audio_apply_volumes()` — loops both lists, calling `audio_sound_gain`.
- `audio_settings_adjust(which, delta)` — clamp + re-apply (used by the ±5% steps).
- `audio_settings_handle_input()` — shared overlay input (W/S pick, A/D or ←/→ ±5%,
  Esc/O/Enter close+save). Returns true so the caller can `exit`.

## 3. UI (scr_ui.gml)
- `ui_draw_settings_overlay()` — dim + centered panel, two slider rows (label, track, %),
  highlight on `settings_cursor`, footer hint. Draw-only.

## 4. Wiring
- **Boot:** `obj_title_controller/Create` calls `audio_settings_init()` + `audio_apply_volumes()`
  before the title music plays.
- **Open/close + input:** `obj_title_controller/Step` (open with `O` once past the cutscene)
  and `obj_hub_controller/Step` (open with `O` when no other overlay is up — guarded by
  `ui_input_blocked()`, `show_history`, dungeon-select). Both intercept at the top and `exit`.
- **Draw:** title `Draw_64` + hub `Draw_64` call `ui_draw_settings_overlay()` when open;
  both screens show an `O: Settings` hint.
- **Re-apply on room entry:** hub / floor / combat Create call `audio_apply_volumes()` after
  starting their music, so freshly-started loops honor the saved volume.

## 5. Deferred / future
- Master volume slider; mute toggle.
- Per-sound-asset coverage is by the two hand-maintained lists — a brand-new sound not added
  to either list plays at full gain. (Keep the lists current when adding sounds.)
- **Only list sounds that are actually played** via `audio_play_sound`. Referencing a
  placeholder/empty sound resource (a `.yy` with no source audio — the project has one named
  `Sounds`) makes the build fail: *"Failed to convert audio file … source file does not exist."*
- If SFX ever ignore the slider on some target, switch to play-wrappers that set gain on the
  returned instance id (guaranteed per-instance) instead of per-asset gain.
