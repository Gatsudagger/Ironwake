# Ironwake Sound Pass — Audit & Replacement Map

Status: **Batch 1 IMPORTED 2026-07-07 + confirm-hierarchy revision (M F5'd v1, disliked the
click confirm).** Confirm tiers now: `snd_ui_confirm` = wood tap (general, e.g. quest accept),
`snd_confirm_major` = harpsichord chime_quick (embark into dungeon, Alchemical Rebirth),
`snd_npc_confirm` = book close (Bairc actions ×7, Sable brew/upgrade), `snd_sell` = wood drop
(shop sells ×2, Sable salvage gear + scrap rune). 64 `snd_*` assets in (importer:
`tools/import_sounds_batch1.py` = the pick manifest of record), registered in `audio_sfx_assets()`.
Sting voice = BOTH families: harpsichord for dungeon/combat/negative (level-up, boss victory,
defeat, error, debuff, quest, mystery), music box for bond moments (heal, hatch, heartbreak,
ordinary-win chime). Victory hierarchy: boss win = `snd_sting_victory` (grand), normal win =
`snd_sting_floor` (light chime). New call sites wired: nav tick in `nav_up/down/left/right`,
Knucklebones/High Table (shake/roll/place/capture/payout/error), settings toggles + close,
shop buy/can't-afford, equip ×3, Bairc confirms ×7, egg hatch, betrayal heartbreak, event-room
mystery, tavern-board cancel. Still on legacy sounds: Blink/Shadow Step `teleport`, player-hurt
direct sites (`hurt` — slot fallback path now covers variations), hub/title/floor music.
**Batch 2 IMPORTED 2026-07-07** (7 assets, 70 total): snd_gold (treasure rooms w/ gold, all 4
types) + snd_chest (every treasure reveal), snd_potion (combat consumable use, single shared
hook), snd_forge (Dorn chit reforge + Maren rune combine), snd_rune_socket (Maren socket/
unsocket/aspect), snd_page (journal open, char-menu tabs Q/E + mouse, loadout tabs E/Q + mouse
— all change-guarded), snd_gate (portcullis on fresh-run floor-1 arrival only), + snd_ui_error
at ALL remaining can't-afford sites (trainer ×2, Maren ×7, Vael, rebirth) and Maren rune-split
→ snd_sell. Post-B2 polish: per-asset trim map LIVE in audio_apply_volumes (snd_ui_move 0.45×), settings
"Menu Tick" toggle (ui/menu_tick ini key) gating the nav ping, snd_gold + procedural coin
burst + atmosphere pass on event screens, telegraph banner re-z-ordered above the combat log.
Batch 3 = G ambience + legacy retirement + more trims as F5 flags them.

Original draft (audit + full candidate shortlists) follows — kept for Batch 2+ and by-ear swaps.
Source packs (both licensed for commercial use, credit optional, no raw redistribution):
- **400 Sounds Pack** (Chequered Ink — https://ci.itch.io/400-sounds-pack) — `C:\Asset_Library\Sounds\400 Sounds Pack\`
- **Free Fantasy SFX Pack** (TomMusic — https://tommusic.itch.io/) — `C:\Asset_Library\Sounds\Free Fantasy SFX Pack By TomMusic\...\WAV Files\`

Import rules (unchanged): every imported sound gets a `snd_*` asset name, is bare-listed in
`audio_sfx_assets()` (scr_stats) or it plays at full volume / gets stripped; ambient loops that
should ride the MUSIC slider go in `audio_music_assets()` instead. Raw masters stay in
C:\Asset_Library (repo's Sound/ masters are gitignored). An empty "Sounds" IDE asset breaks builds.

---

## 1. Audit — what plays today

**The entire game runs on 15 gain-registered sounds**, and only five controllers make any sound at
all (title, hub, floor, combat, game controller). Everything else is silent.

### Over-used / duplicated
| Sound | Uses | Where |
|---|---|---|
| `Check_1` | 12 sites | THE universal confirm: equip item (×3), Bairc pet actions (feed, cure, name, set-active, egg-identify, donate, crossing), quest fulfilled, settings. Equipping a sword and feeding a pet sound identical. |
| `hurt` | 3 | Every instance of player taking damage (2 direct + `snd_player_hurt` fallback). |
| `Chimes__Ascending_` | 3 | Level-up (2 sites) + floor-completion XP — same chime for different-magnitude moments. |
| `utility2` | 3 + fallback | Hub-menu toggles AND the `snd_cast_buff` fallback. |
| `attack1` / `grunt` | several | Melee cast, blood-cast layer, Bloodwarden grunt, construct/beast attack+death fallbacks — one thunk for half the combat roster. |

### The empty slot system (built, never fed)
`play_sfx_var(base, fallback)` already probes `<base>`, `<base>_2`, `<base>_3` and random-picks —
so variations are free once files exist. Slots currently falling back to the legacy library:
- `snd_miss` (**currently SILENT** — fallback -1)
- `snd_player_atk` (+ `_f` female set via `play_player_vocal`), `snd_player_hurt` (+ `_f`)
- `snd_cast_heal / shield / buff / debuff / elem / void / blood / arcane`
- `snd_attack_<fam>` and `snd_death_<fam>` for families: undead, wraith, construct, beast, fire, ice, boss
- Known limitation: `snd_cast_elem` is ONE slot for all 8 element schools (keyed on damage_type,
  not school). Optional later extension: key by school for fire vs ice casts.

### Events with NO sound at all
- **All cursor/menu navigation** (the global `key_nav` hold-repeat system = one clean hook point)
- Cancel/back, error/can't-afford, toggle
- **Knucklebones & High Table dice** — roll, place, destroy-capture, payout
- Shop buy/sell (Petra/Dorn/Sable/Vex), gold gain anywhere
- Dorn forge/reforge, salvage (incl. the new dissolve/shatter glyphs), rune socketing
- Sable brewing / Potion Fusion, drinking a consumable in combat
- Loot screen reveal/pickup, chest/reward, board-request accept
- Codex/journal/tab page-turns, floor-map open
- Dungeon-gate entry, floor transitions
- Egg hatch, pet growth, Awakened crossing
- Ambience: zero ambient layer anywhere (hub/dungeon have music only)

### Unused imported assets (candidates to retire after the pass)
`Check_2`, `Harp_1__Ascending_`, `Miscellaneous_1__Atmospheric_`, `Selection`, `Strings_2`, `Success_3`.

---

## 2. Proposed replacement map

Naming: new asset = slot name below; variations get `_2`/`_3` (free via `play_sfx_var`).
`(NEW SITE)` = needs a new one-line call added; everything else feeds an existing slot/call.

### A. UI core — 400 Pack `UI\` (+ Musical Effects)
| Slot | Candidates | Notes |
|---|---|---|
| `snd_ui_move` (NEW SITE, hook `key_nav`) | select_1..4, pop_1..4 | subtle; one global hook |
| `snd_ui_confirm` | click_double_on, click_double_on_2, select_3 | replaces MOST `Check_1` sites |
| `snd_ui_cancel` (NEW SITE) | cancel.wav | back out of menus |
| `snd_ui_error` (NEW SITE) | synth_error, `<fam>_negative_quick` | can't afford / locked / invalid |
| `snd_ui_toggle` (NEW SITE) | toggle_on / toggle_off | settings rows |

### B. Knucklebones / High Table — 400 Pack `Card and Board\`
| Slot | Candidates |
|---|---|
| `snd_dice_roll` (NEW SITE) | dice_roll_1..4 (import 3 as variations) |
| `snd_dice_shake` (NEW SITE) | dice_shake_2/3/4 (pre-roll flourish) |
| `snd_dice_place` (NEW SITE) | chips_place_1..3 |
| `snd_kb_capture` (NEW SITE) | crunch_quick, glass_ping_small (opposing dice destroyed) |
| `snd_kb_payout` (NEW SITE) | chips_gather_2/3, coins_gather_medium |

### C. Combat — TomMusic `SFX\Attacks` + 400 `Combat and Gore\` / `Weapons\`
| Slot | Candidates |
|---|---|
| `snd_player_atk` ×3 | Sword Attack 1–3 (bow users later: Bow Attack 1–2) |
| `snd_miss` ×2–3 | swipe.wav, whoosh_1, whoosh_2 (finally un-silences whiffs) |
| `snd_player_hurt` ×3 | punch_2, slap, crunch_quick (packs have no female vocals — `_f` set stays empty for now) |
| `snd_attack_undead` | bone_snap • `snd_death_undead`: crunch_splat |
| `snd_attack_wraith` | ghost_long (400 `Other\`) • `snd_death_wraith`: whoosh_2 + ghost tail |
| `snd_attack_construct` | metal_clang, harsh_thud • `snd_death_construct`: stone_push_short + metal_clang |
| `snd_attack_beast` | crunch, kick • `snd_death_beast`: squelching_2 |
| `snd_attack_fire` | Fireball 2 • `snd_death_fire`: Firespray 1 |
| `snd_attack_ice` | Ice Throw 1 • `snd_death_ice`: Ice Freeze 2 (shatter) |
| `snd_attack_boss` | Sword Impact Hit 3 + harsh_thud • `snd_death_boss`: crunch_splat_2 + `<fam>_defeated` |

### D. Casts — TomMusic `SFX\Spells` (feeds the 8 existing `snd_cast_*` slots)
| Slot | Candidates |
|---|---|
| `snd_cast_elem` ×3 | Fireball 1–3 (or 1 each of Fireball/Ice Throw/Waterspray for texture spread) |
| `snd_cast_void` | ghost_long, horror_sting (400) |
| `snd_cast_blood` ×3 | squelching_1/3/4 |
| `snd_cast_arcane` ×3 | Spell Impact 1–3 |
| `snd_cast_heal` | `<fam>_chime_positive`, heart_collect |
| `snd_cast_shield` | Ice Wall 1, Rock Wall 1 |
| `snd_cast_buff` ×2 | Firebuff 1–2 |
| `snd_cast_debuff` | Ice Freeze 1, `<fam>_negative` |

### E. Economy / items — 400 `Items\` / `Weapons\` / `Materials\` + TomMusic `Doors Gates and Chests`
| Slot | Candidates |
|---|---|
| `snd_gold` (NEW SITE) | coin_collect, coins_gather_quick/small (gold gain, sell) |
| `snd_equip` | weapon_equip, item_equip (replaces `Check_1` on the 3 equip sites) |
| `snd_unequip` (NEW SITE) | weapon_unequip |
| `snd_buy` (NEW SITE) | coin_jingle_small, coins_gather_medium |
| `snd_potion` (NEW SITE) | drink_slurp (400 `Other\`) — combat consumable + Sable |
| `snd_forge` (NEW SITE) | weapon_upgrade, sword_sharpen (Dorn craft/reforge) |
| `snd_salvage_dissolve` (NEW SITE) | water_boiling_loop (one-shot trim), gurgling — Sable dissolve glyph |
| `snd_salvage_shatter` (NEW SITE) | glass_ping_big, pottery_clang — shatter glyph |
| `snd_rune_socket` (NEW SITE) | gem_collect |
| `snd_page` (NEW SITE) | page_turn, book_open/close (codex/journal/tabs) |
| `snd_chest` (NEW SITE) | Chest Open 1–2 (loot reveal / reward) |
| `snd_gate` (NEW SITE) | Portcullis Gate, Gate Open (dungeon entry) |
| `snd_pet_hatch` (NEW SITE) | ceramic_jar_open + `<fam>_chime_positive` layer |

### F. Musical stings — 400 `Musical Effects\` (11 cues × 11 instrument families)
Pick ONE instrument family as the game's "voice" for identity (fam = that prefix):
- Level-up: `<fam>_level_complete` (replaces Chimes__Ascending_ at level-up sites)
- Floor-complete XP: `<fam>_chime_quick` (differentiates from level-up)
- Victory: `<fam>_positive_long` (or keep Success_2/MusicBox1)
- Quest/request fulfilled: `<fam>_chime_positive`
- Event room / mystery: `<fam>_mystery`
- Defeat sting: `<fam>_defeated` (or keep Game_Over)
Family candidates, gothic-appropriate: **harpsichord**, **music_box** (matches existing MusicBox1),
grand_piano, vibraphone. (Also available: 8_bit, brass, sitar, steel_drums, synth_bass, xylophone.)

### G. Ambience — TomMusic `BGS Loops\` — DONE (Batch 3, 2026-07-07)
| Place | Shipped loop (asset) |
|---|---|
| Hub (rainy — matches Rainy_Memories) | Forest Night Rain (`snd_amb_rain`, 0.50× music) |
| Dungeon floors (under _2_dungeon music) | Cave (`snd_amb_cave`, 0.55× music) |
| Torch crackle, hub gate + floor braziers | Torch Loop (`snd_amb_torch`, 0.30× music) |
Resolved: loops ride the MUSIC slider (M, 07-07 — registered in `audio_music_assets()`, zero new
UI). Imported as OGG (60s/60s/10s beds — wav triples the weight) via `tools/import_sounds_batch3.py`.
Layering: each room controller's Create declares its full bed via `ambience_set([...])` (scr_stats)
— hub = rain+torch, floor = cave+torch, title/combat = none; shared members keep playing across the
transition, so no music stop-site needed changes. Trim map lives in `audio_apply_volumes()`.

---

## 3. Import batch plan (proposed order)
1. **Batch 1 — biggest bang**: UI core (A) + dice (B) + combat/casts (C+D). Kills the Check_1
   monotony, un-silences whiffs and Knucklebones, gives all 7 enemy families a voice.
2. **Batch 2**: economy/items (E) + stings (F).
3. **Batch 3** — DONE 2026-07-07: ambience (G) + retired 6 unused legacy assets (Check_2,
   Harp_1__Ascending_, Miscellaneous_1__Atmospheric_, Selection, Strings_2, Success_3 — zero
   .gml references; removed from .yyp, folders deleted by `tools/import_sounds_batch3.py`).
Each batch: M auditions shortlist → approve picks → import (.wav → snd_* assets, `audio_sfx_assets()`
registration, new call sites in .gml) → M F5s.
