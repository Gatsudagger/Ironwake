# SFX / VFX AUDIT — 2026-08-17 (for M's itch.io shopping)

M (08-17): "I can get SFX/VFX packs from itch.io if you point me towards ones we need for
missing effects." This is the shopping list. Nothing here is generated; the game currently
FALLS BACK for every gap below (shared cue / generic burst / no visual), so nothing is broken —
these are the places a bespoke asset would read better.

## How the code consumes them (so a pack fits without rework)
- **SFX**: `play_sfx_var("snd_<key>", fallback)` looks for `snd_<key>`, `snd_<key>_2`, `snd_<key>_3`
  and picks one at random → drop 1-3 variants per key. Any format GM imports (.ogg / .wav),
  mono or stereo, short (≤1.5s for hits, ≤3s for casts). Register via a small import script
  (pattern: `tools/import_sounds_batch4.py`) + `audio_sfx_assets()`.
- **Status VFX** (`spr_fx_<kind>`): 64x64, 4 frames, additive-friendly (drawn with `bm_add`),
  transparent background, loops. Existing: bleed / blind / burn / impact / poison / stun / weaken.
- **Burst VFX** (`spr_vfx_<name>`): 96–128px square, 7–16 frames, transparent, additive.
  Existing set: fire/frost/shock/arcane/void/shadow/blood/poison (+ `_2` variants), heal, shield,
  buff, gain, haste, rage, slash, snap, spikes, crush, pierce, boom, wardflash, scorch, dark.
- **Bolt VFX** (`spr_vfx_bolt_<school>`): 96x48, 12 frames, flies left→right (mirrored in code).

## A. STATUS VFX GAPS (spr_fx_* missing → status draws NO overlay on the enemy)
| kind | used by | wanted look |
|---|---|---|
| root | Bear Trap, Gravewrack Grip, Wire Snare, Call of the Void | vines / roots wrapping feet (approved 08-13, never made) |
| silence | Mana Sever, Warding Chime, Call of the Void, Hollow Crown | muted rune ring / crossed lips glyph |
| vulnerable / exposed | Scorch primer chain, Bonebreaker, Pack Tactics, Call of the Void | cracked-armour shards / target reticle |
| hexed | Curse | violet skull sigil orbiting |
| marked | Marked for Death | crimson crosshair / mark |
| mortality | Plague Touch | wilting green flies |
| firemark (Sear) | Scorch, Blazing Palm | ember motes clinging |
| chill (weaken+frost) | Hoarfrost Lance, Frost Shot | ice crystals (currently reuses weaken) |
| shock (status) | Static Arc chain | small arcs (currently reuses generic shock burst) |
Search terms: "pixel art status effect vfx 64x64", "rpg status icons animated pixel", "buff debuff
sprite sheet 16-bit". Prefer packs with 4-8 frame loops and NO baked background.

## B. SFX GAPS (keys the code calls with a shared fallback → sounds the same as something else)
| key | where | fallback today |
|---|---|---|
| snd_pet_strike / snd_pet_rend / snd_pet_pounce / snd_pet_snarl / snd_pet_mend / snd_pet_cleanse | 08-17 pet move pools (combat_pet_act) | none (silent) — creature bite / claw / snarl / soft chime wanted |
| snd_stun_land | Paralytic Pulse, Death Snare, Second Chance | none — a dull thud + ring |
| snd_immune | 08-17 IMMUNE popup (combat_immune_sweep) | none — short "clink / deflect" |
| snd_cast_paralytic / snd_cast_void_call | new Arcanist pair | shares snd_cast_arcane / snd_cast_void |
| snd_reagent_pickup / snd_valuable_pickup | 08-17 reagent + valuable drops | shares snd_loot_common |
| snd_trap_spring_* per trap | traps all share one spring | one spring |
| snd_summon_* (Husk / Effigy / Golem arrive) | summons | shares snd_cast_* |
| snd_shatter (frost chill detonation) | Chill shatter reaction | shares impact |
| snd_detonate | every detonation reaction | shares snd_cast_arcane |
| snd_station_rank | NPC station-rank purchase | shares snd_forge |
| snd_garden_* (pond crumb / cairn stone / forage / pet) | Bairc's garden verbs | UI move / confirm |
Search terms: "rpg spell sfx pack", "creature attack sound pack pixel rpg", "ui/rpg impact sfx
16-bit", "monster growls pack". Prefer packs with a permissive license we can list in CREDITS.md
(CC0 / royalty-free with attribution) — the credit record rule applies.

## C. WHAT'S ALREADY COVERED (don't buy)
Family attack/death cues (beast / boss / construct / fire / ice / undead / wraith), cast cues by
school (arcane / blood / buff / debuff / elem / fire / frost / heal / nature / shield / shock /
void), loot tier stings, UI set, ambience per dungeon + hub + garden, music (14 tracks).

## D. HOW I'LL WIRE A PACK ONCE YOU DROP IT IN
1. Files → `C:\Asset_Library\` drop spot (reference_asset_library rule), tell me the pack.
2. I write `tools/import_sfx_<date>.py` (GM closed) → sounds/ + yyp + `audio_sfx_assets()`.
3. Wire keys above at their sites (each is one `play_sfx_var` line / one `spr_fx_` case).
4. CREDITS.md license line.
