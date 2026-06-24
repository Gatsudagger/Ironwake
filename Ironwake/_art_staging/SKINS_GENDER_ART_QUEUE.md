# Skins + Gender — Art Queue / Resume Tracker

Code: COMPLETE (see SYSTEMS_SKINS_GENDER.md). All sprites referenced via asset_get_index,
so the project compiles now; art drops in as resources are created.

Sprite spec: match `spr_arcanist` — **92×92, 8 frames** (PixelLab char size 66, view side,
8 directions, standard mode). Build each resource by cloning `spr_arcanist.yy` (8 frame
GUIDs + layer GUIDs + sequence keyframes), placing PixelLab's 8 rotation PNGs as frames,
registering in Ironwake.yyp. Combat draws frame 1 (east) via player_sprite_frame.

## Female class sprites — REGENERATED v2 (2026-06-22)
v1 (below) was STANDARD mode + view "side" → bright anime style, canvas-filling, mismatched
the dark grimdark PRO-mode males. v2 uses **mode pro, view low top-down, size 66** to mirror
the male class sprites (Player chars b79a97fb / ecc2e91d, 92px, low top-down, pro/blank-style).
| sprite resource | v2 PixelLab char ID (pro) | v1 (deprecated, standard) | status |
|---|---|---|---|
| spr_arcanist_f      | 0868d95e-2b0b-4ccf-bc3f-82778860a05e | 136e79fa-... | generating |
| spr_bloodwarden_f   | 45ce9118-d3de-4045-a21a-5a0adffc1e77 | e03a4abb-... | generating |
| spr_shadowstrider_f | 43dc7d51-2de8-4a47-86a1-152edc65c19f | 5979042d-... | generating |

## Skins to generate (20) — sprite name ← description
Not yet fired. Single 8-dir character each (size 66, side, 8-dir).
- spr_skin_wanderer    ← travel-worn hooded cloak, road-weary adventurer (M)
- spr_skin_hearth      ← warm banded-leather guardswoman, fire-tested (F)
- spr_skin_duskhide    ← dark supple rogue leathers, hooded (M)
- spr_skin_pilgrim     ← hooded ascetic robe, wandering pilgrim (F)
- spr_skin_ironscale   ← riveted iron scale armor, dented veteran (M)
- spr_skin_gravewalker ← grave-dirt caked plate, undead-hunter (M)
- spr_skin_bloodsworn  ← crimson warsuit, blood-oath warrior woman (F)
- spr_skin_cryptlight  ← lantern-bearer tattered wraps, crypt delver (M)
- spr_skin_frostbit    ← frost-rimed mail, ice-touched warrior woman (F)
- spr_skin_cinderclad  ← charred glowing warplate, fire knight (M)
- spr_skin_mirewalker  ← bog-shrouded hide and moss, swamp stalker (M)
- spr_skin_stormcall   ← storm-charged robes, lightning sorceress (F)
- spr_skin_bonechoir   ← bound-bone armor, necromantic warrior (M)
- spr_skin_veilbind    ← woven-shadow shroud, shadow sorceress (F)
- spr_skin_goldwrought ← gilded ornate regalia, golden champion woman (F)
- spr_skin_voidtouch   ← star-eaten dark void plate, cosmic knight (M)
- spr_skin_sanguine    ← blood-dark vampire-lord finery, noblewoman (F)
- spr_skin_dawnbreak   ← radiant golden crusader plate, holy knight (M)
- spr_skin_doomherald  ← apocalyptic spiked warlord armor (M)
- spr_skin_sovereign   ← prestige crown-and-cape royal regalia, queen (F)

## Resume steps
1. get_character each ID; download the 8 rotation frames.
2. Build sprite resource (clone spr_arcanist.yy, new GUIDs, 8 frame+layer PNGs) per sprite.
3. Register each in Ironwake.yyp resources (alphabetical).
4. Fire the 20 skins, repeat 1-3.
5. Player opens Ironwake fresh → sprites ingest → art appears (catalog/char-select already wired).
