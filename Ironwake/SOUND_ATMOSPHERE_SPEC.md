# Ironwake Atmosphere & Flavor Sound Spec (2026-07-14)

**DESIGN-LOCKED by M 2026-07-14** (full scope approved as listed; haul rule =
reveal ticks per row + ONE stinger for the highest rarity in the haul).

Scope per M: **loot dopamine, atmosphere beds, flavor one-shots, music.**
Explicitly NOT this pass: player ability sounds, enemy ability sounds.

Generation: ElevenLabs (Creator tier) under the credit rules in
CLAUDE_SETTINGS.md ("AI Generation Credit Budgets") - one candidate per sound,
audition, 2-strike rule, short explicit durations, ~10k credits/session cap.
Music: Suno web app (M generates, drops into Asset_Library\Sounds\Suno\).
Import: existing pipeline - `audio_sfx_assets()` registry, `play_sfx_var`
variations, `ambience_set([...])` beds ride the music slider.
Style anchor for every prompt: *gothic dark-fantasy, aged parchment-and-iron
world, candlelit; no modern/synthetic character unless noted.*

---

## 1. LOOT DOPAMINE SUITE (priority 1 - M: "very important")

The rarity ladder. Each step must be instantly distinguishable eyes-closed.
All one-shots, 0.6-2.5s except legendary/unique (up to ~4s).

| Slot | Sound direction | Est. len |
|---|---|---|
| `snd_loot_common`    | soft cloth/leather drop, dull, unremarkable (that's the point) | 0.6s |
| `snd_loot_uncommon`  | metal clink + single faint chime tail | 0.8s |
| `snd_loot_rare`      | bright crystalline chime, two-note rise | 1.2s |
| `snd_loot_epic`      | deep resonant bell + airy shimmer swell | 2.0s |
| `snd_loot_legendary` | EVENT: sub-boom -> rising choir/shimmer -> cathedral bell toll tail | 3.5-4s |
| `snd_loot_unique`    | signature relic motif - music-box notes over a low whisper drone (deliberately NOT on the rarity ladder's family; "you found a story") | 3s |
| `snd_loot_reveal`    | quick card-flip/parchment tick per loot-screen row (x2-3 variations) | 0.3s |

Wiring: loot screen plays `snd_loot_reveal` per row as items appear, then ONE
stinger = the highest rarity in the haul (no stacking cacophony). Drop-moment
sites (chest `snd_chest`, boss reward) layer the rarity stinger over the open.
Legendary/unique also fire at the FORGE (Dorn reforge hitting legendary) and
Petra trade-order completion. Visual glint/flash on legendary+ = separate art
task, sound ships first.

## 2. DUNGEON AMBIENCE IDENTITY (priority 2)

Today all three dungeons share ONE cave bed (`snd_amb_cave`). Each gets its
own 45-60s seamless loop (generate ~22s and loop-edit if needed), quiet, LOW
frequency emphasis so combat/UI reads over it:

| Slot | Direction |
|---|---|
| `snd_amb_ashen`    | dry crypt: dust settling, faint bone rattles far away, stone-hall air |
| `snd_amb_scorched` | deep magma rumble, ember hiss, occasional distant metal groan |
| `snd_amb_tundra`   | thin arctic wind through stone, ice creaks/cracks, hollow resonance |

Wiring: floor + combat controllers' `ambience_set` picks by
`global.selected_dungeon` (torch layer stays shared). Cave bed retires or
stays as Ashen fallback.
Also: `snd_amb_title` - night forest wind + distant owl + faint town bell for
the title screen's living backdrop (currently silent bed).

## 3. HUB STATION FLAVOR (priority 3)

Short quiet loops (10-20s) that play only while that NPC screen is open
(hook: each `*_open` flag already gates draw - same gate starts/stops loop):

| Slot | Direction |
|---|---|
| `snd_amb_forge`   | Dorn: slow bellows breath, coal crackle, occasional distant hammer tap |
| `snd_amb_cauldron`| Sable: gentle thick bubbling, glass clinks (matches animated cauldron) |
| `snd_amb_garden`  | Bairc: soft creature chitters/coos, straw rustle |
| `snd_amb_tavern`  | Tavern board + High Table: low murmur, mug clunks, fire pop |

## 4. MOMENT STINGERS (priority 3)

One-shots for the emotional beats (several sites currently silent):

| Slot | Direction |
|---|---|
| `snd_shrine_hum`     | approaching sanctity - low choral drone swell, 2s |
| `snd_curse_whisper`  | curse altar - dissonant whisper cluster, unsettling, 2s |
| `snd_egg_stir`       | shell wobble + faint tap from inside, 1s (hatch cutscene phase 0) |
| `snd_hatch_burst`    | shell crack + warm chime bloom (upgrade for existing snd_pet_hatch layer) |
| `snd_awakened_cross` | pet Awakening: airy rising swell into a single deep bell, 4s (the wing moment) |
| `snd_bond_up`        | warm two-note harp/bell motif, 1.5s (bond tier advance) |
| `snd_betrayal`       | reversed sting + heartbeat thud, cold, 2.5s (betrayal severity moments) |
| `snd_extract`        | extraction: stone gate rumble + wind rush + fading chime, 2.5s |
| `snd_boss_door`      | entering boss room: massive iron groan + sub hit, 2s |

## 5. MUSIC (Suno - M's account, web flow)

Current: Rainy_Memories (hub), one `_2_dungeon` track shared by all floors,
Garrard/Coldfire licensed set. Proposed additions, in order of impact:

1. Three dungeon floor themes (Ashen: sparse funeral organ/strings; Scorched:
   low percussion + brass drones; Tundra: glassy celesta/strings, cold) -
   replaces the one shared track.
2. Boss theme (one, shared: driving low strings + choir).
3. Win-state/credits theme (warm reprise of title mood).
4. (Optional) Title theme distinct from hub.

Suno flow: M generates 2-3 candidates each -> Asset_Library\Sounds\Suno\ ->
Claude auditions/trims/loops -> import ride the music slider. LICENSE: Suno
commercial plan required; **Steam AI disclosure must gain an AI-audio line
when the first Suno track OR ElevenLabs SFX ships** (currently art-only).

---

## Budget & order

ElevenLabs Creator = ~100k credits/mo; SFX gen ~= 100-200 credits each.
Full list above ~= 30 sounds; with the 1-candidate + audition discipline and
some re-rolls, expect ~5-8k credits = inside one session cap.

Session order: (1) Loot suite end-to-end incl. wiring + F5, (2) dungeon
ambience trio + title bed, (3) hub flavor + stingers, (4) music runs in
parallel on M's Suno side whenever he wants.
