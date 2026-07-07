# Ironwake — Asset Credits & License Audit

Audit of everything that ships in the build. Status: ✅ verified · ⚠️ action needed · ❓ unknown, needs M.
Last verified 2026-07-07 (itch pages fetched live; quotes are from the pack pages on that date).

## Art

| Source | Used for | License | Status |
|---|---|---|---|
| **PixelLab** (AI generation, pixellab.ai) | Character skins (26), NPC sprites, pets/eggs, portraits, item codex splash art (62), dungeon backgrounds (9 combat + 3 floor maps), gothic UI frame, chest/helm/gloves/boots + various unique-item icons, gargoyle gate | PixelLab ToS — generated assets usable in commercial projects | ✅ (AI — disclose) |
| **Batareya — Pixel Skill Icons: 250 Warrior Abilities** | Ability icons (19), trait icon sources | "You can use this pack for personal and commercial purposes without restrictions." | ✅ (AI — disclose) |
| **Batareya — 250 Magical Icons** ("MAGE ICONS BIG PACK") | Ability icons (30), trait icon sources | "Completely free for both commercial and non-commercial use. All we ask is that you **credit the author**." | ⚠️ **credit Batareya required** — covered by Credits screen |
| **Batareya — Pixel Art Sword Pack (50)** ("Full Sword pack") | 17 rare+ sword icons | "Free and commercial projects… Credit is not necessary, but appreciated. You may not redistribute it or resell it." | ✅ (AI — disclose) |
| **Batareya — Fantasy Jewelry Pack** ("Full Accessories pack") | Ring + amulet icons (14) | Same wording as sword pack (verified on pack page) | ✅ (AI — disclose) |
| **Medieval Weapons Pack v1.2** | Off-hand shield icons (3, sliced from shields sheet) | Bundled Read me.txt: "free to use in any personal or commercial project… no mentions required… not allowed to re-upload or sell" | ✅ (❓ author name for credits — folder/readme unsigned) |
| **CaptainSkeleto/CaptainSkolot — Magic Tomes pack** | Caster off-hand foci icons (4: totem/orb/stone/focus slots — visually matched to the pack's sheet) | Pack page (found by M 2026-07-07): "freedom to use this asset pack in both your free and commercial projects… credit is not required, we genuinely appreciate any attribution… may not redistribute or resell the assets on their own, that includes NFT/images asset compilations." AI-assisted ("local generative tool for rough concepts, then refined by hand") | ✅ (AI — disclose; credited anyway) |
| **unTied Games — Super Pixel Effects Gigapack (Free) v2.5.0** | 6 combat VFX sprites (impact/fire/void/arcane/heal/buff) | Commercial OK, **attribution required**, no reselling. Suggested line: "Pixel art effects - unTied Games" | ⚠️ **credit required** — covered by Credits screen |
| **CraftPix — 48 Magic Potions / 48 Minerals** | Potion + consumable icons | Bundled License.txt (craftpix.net/file-licenses): commercial OK, no raw redistribution, attribute where feasible | ✅ |
| Procedural (in-repo tools: gen_trait_icons.py frames, coin burst, etc.) | Trait icon framing, event coin VFX | Own work | ✅ |

## Audio

| Source | Used for | License | Status |
|---|---|---|---|
| **Chequered Ink — 400 Sounds Pack** (ci.itch.io) | Most snd_* SFX (UI, combat, economy, stings) | Commercial OK, credit optional, no raw redistribution | ✅ |
| **TomMusic — Free Fantasy SFX Pack** (tommusic.itch.io) | Sword/spell/chest/gate SFX + ambience beds (rain/cave/torch) | Commercial OK, credit optional, no raw redistribution | ✅ |
| **Sara Garrard (sonatina.itch.io) — "Shadows/Infinity: Battle Zone"** | _2_dungeon_INITIAL/LOOP, _3_critical_INITIAL/LOOP, _14_BOSS_y_LOOP, _15_game_over_INITIAL (identified 2026-07-07 via embedded vorbis tags: ARTIST=Sara Garrard, ALBUM=Shadows/Infinity: Battle Zone, 2022) | Commercial use OK incl. monetized games; **credit Sara Garrard required**; on itch, link sonatina.itch.io on the game page; donation appreciated, not required. Full terms ship in the pack download | ⚠️ **credit required** — covered by Credits screen. Locate M's pack download for the full terms file (for the Steam context) |
| **Alex Coldfire — "12 Instrumental Game Soundtracks (Visual Novel/Action)"** (alex-coldfire.itch.io/12-soundtracks; identified by M 2026-07-07, track list verified on page) | Viking_March (title), Rainy_Memories (hub) | **CC BY-ND 4.0**: free in commercial projects; "you must **credit me (Alex Coldfire)** as the author in the game's credits and in the author section on all relevant pages"; **no major changes to tracks**; no resale | ⚠️ **credit required** (game credits + store pages) — covered by Credits screen; use tracks as-is |
| **Sara Garrard — "RPG music pack: INFINITY CRYSTAL"** (sonatina.itch.io/infinity-crystal; M identified 2026-07-07) | Game_Over (defeat sting) | Same terms as Battle Zone: commercial OK, credit Sara Garrard + itch-page link, donation optional | ✅ covered by existing Sara Garrard credit |
| **MusicBox1** (FL Studio 21 render) | Pet/music-box theme | ❓ M: standalone free itch download, author not yet recalled | ⚠️ last unidentified track — name the creator when found, or replace |
| **Legacy SFX** — utility2, Check_1, Chimes__Ascending_, Success_1/2, spell1, Magic, attack1, grunt, teleport, die5, hurt, Obscure, Strings_1, Harp_2__Descending_ | Remaining fallback/cast/shop sounds | ❓ Old ffmpeg-converted set (Lavf54 = ~2013 tooling), generic names, no tags | ⚠️ identify via M's itch library OR retire (sound-pass epilogue replaces the last live uses from the two cleared packs) |
| **MidJourney (M's own generations)** | ALL NPC artwork + ALL portraits (6 hub NPC portraits, 60 char-creation portraits, Vael portrait carousel) — confirmed by M 2026-07-07 | MidJourney paid-plan terms: subscriber owns/has commercial rights to generations | ✅ (AI — disclose) |

## Fonts

| Font | Used for | License | Status |
|---|---|---|---|
| **EB Garamond** (Google Fonts) | fnt_ui, fnt_ui_small | SIL OFL 1.1 (text staged in Asset_Library\fonts\_steam_font_swap) | ✅ swapped 2026-07-07 |
| **Cinzel Decorative** (Google Fonts) | fnt_ui_title | SIL OFL 1.1 | ✅ swapped 2026-07-07 |
| ~~Centaur / Castellar (Monotype)~~ | (removed from .yy 2026-07-07) | Windows system fonts — NOT licensed for game embedding | ✅ resolved by swap |

## Steam AI Content Disclosure (draft for the Content Survey)

> Ironwake contains pre-generated AI content. Some 2D art assets (character sprites, portraits,
> item illustrations, backgrounds, and icon sets) were created using AI image-generation tools
> (PixelLab and MidJourney, plus licensed third-party icon packs produced with Stable Diffusion).
> All AI-generated assets were reviewed, curated, and integrated by the developer. The game does
> not generate any content with AI at runtime, and no live AI models are accessed by the game.

## In-game credits screen — minimum required lines

- "Music by Sara Garrard" + link to sonatina.itch.io on the itch game page *(required by the Battle Zone / Infinity Crystal licenses)*
- "Music by Alex Coldfire" — in game credits AND the author/credits section of store pages *(required by CC BY-ND 4.0)*
- "Icons by Batareya" *(required by the 250 Magical Icons license)*
- "Pixel art effects - unTied Games" *(required by the Gigapack license)*
- Recommended courtesy: PixelLab, Chequered Ink, TomMusic, CraftPix, CaptainSkeleto (if kept),
  Medieval Weapons Pack author (if identified), Google Fonts (EB Garamond, Cinzel Decorative — OFL).
