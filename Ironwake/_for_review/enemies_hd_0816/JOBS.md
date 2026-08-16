# ENEMY HD RE-AUTHOR 0816 — Ashen Vault base six (M-locked: all 6, East + South)

Recipe: create_image_pro, style_image = spr_bone_sovereign_hd (full-res 16-colour paletted PNG,
4.5KB b64 — transport OK), reference "character base" = legacy east frame (frame 1) tight-crop
4x nearest 16c. Canvas <=170 → 4 candidates / 25 gens per call. Prompt = "exact same character,
MORE PIXELS of the same crisp pixel-art detail, dark medieval gothic, side profile facing RIGHT".

## EAST jobs (round 1)
| enemy | sprite | canvas | job id |
|---|---|---|---|
| Skeleton Archer | spr_skeleton_archer | 120x160 | 64fe6e0e-2dd0-43ab-97ff-10ed215d3e92 |
| Ashen Skeleton  | spr_skeleton_soldier | 130x160 | 306ff4f9-2748-4ccf-89d7-072195ec5a7a |
| Vault Crawler   | spr_vault_crawler | 160x120 | 49273952-b83b-458c-8f31-66cd174879cd |
| Dungeon Wraith  | spr_dungeon_wraith | 120x160 | 8c3a1506-c019-4e32-9a4c-d154d63c5f30 |
| Stone Golem     | spr_stone_golem | 150x160 | 480dd11a-c558-43d0-8be4-33e6be9b9f4b |
| Vault Guardian  | spr_vault_guardian | 130x165 | cf63711b-de11-460c-b7e2-28afc95be1c4 |

Download: https://api.pixellab.ai/mcp/images/<job>/download?index=N

## ⚠ ROUND 1 (east 120-165px "HD") REJECTED BY M — "these are like portraits, abandons the
## pixel-sprite consistency (FFT / Tactics Ogre)". 150 gens lost. Archive east_raw/.
## Round 1b (84x84 ~75px, revenant anchor) also too big/realistic — 25 gens.

## ROUND 2 = FF-STYLE (M's REFERENCE SPRITE ART/pixel sprites best match.webp = anchor):
## 64x64 canvas, ~44px figure, 3/4-FRONT single frame (M-locked), style = single-figure
## crop of the best-match sheet, character base = legacy SOUTH frame 3x, 16 candidates/call.
| enemy | job id | gens | verdict |
|---|---|---|---|
| Skeleton Archer (pilot) | 1cdb6ca6-d2c5-45f5-b8c2-2a26309b7cfb | 20 | M PICK IDX2 |
| Ashen Skeleton | 0305b76a-2eb1-473f-880f-0684a5dac8f5 | 20 | IDX3 (+alts 10, 1) |
| Vault Crawler | c6bdc8a2-d411-497f-8e27-eb4fa3106aa2 | 20 | IDX0 (+alts 9, 12) |
| Dungeon Wraith | f8ad3896-1e49-42b1-bd6f-c35219a6008e | 20 | IDX6 (+alts 1, 15) |
| Stone Golem | 7a457590-b27d-4caa-bdf0-bce083b220fc | 20 | IDX1 (+alts 3, 8) |
| Vault Guardian | 9671df3c-e62d-40d6-a5cd-bdea19cb1c17 | 20 | IDX3 (+alts 7, 9) |
Archer: IDX2 (+alts 3, 7). Session spend: 295 gens.
IMPORTED 08-16 (tools/import_enemies_ff_0816.py, GM closed): spr_<enemy>_ff / _ff2 / _ff3
(18 sprites). Wired: enemy_sprite_map -> _ff; enemy_sprite_variants() + combat_enemy_model()
stamp a per-combatant model_var (different models for same-name foes); __sprite_includes.
CLEANUP after M's in-game confirm: delete ff_raw/ pilot_ff_raw/ + sheets (picks live in sprites/).

## ROUND 3 (M sign-off ~200 gens): Ashen four + six Scorched/Tundra, same recipe
| enemy | job id |
|---|---|
| Vault Wraith | 7e9e4ab5-96ae-456d-b9ee-f16d4c927f8d |
| Vault Sentinel | 8e15eae9-ce8a-4516-b5c4-f7a774b20d24 |
| Malgrath the Warden (boss ~52px) | e767216e-2098-4a93-9a21-4ffd164d6c73 |
| Bone Colossus (boss ~56px) | e2734b0c-c69d-41b0-a554-b115b5e20969 |
| Cinder Imp (~34px) | 394f99ef-26d2-40bf-badb-f09bcf2f1df5 |
| Lava Spitter | e751e33a-3af5-48e6-9fa9-e2274431d08e |
| Glacial Lurker | f8955d45-1cf9-46c4-b2a3-868334bc6427 |
| Snowbound Wraith | 9bf7f256-f26f-4347-8adb-41a2f08dfa08 |
| Frost Shard | 36e1272f-0043-4e2f-81c1-a656e48641a1 |
| Magma Slug | 993c78aa-32ac-4300-be93-85d762e73030 |
Session spend: 495 gens.

## Import plan (GM CLOSED)
New sprites spr_<name>_hd (east) + spr_<name>_hd_s (south) cloned from the
spr_bone_sovereign_hd .yy template (tools/import_summons_fonts_0814.py pattern); enemy_sprite_map
→ _hd; add names to enemy_sprite_faces_east; bestiary south lookup → _hd_s; originals untouched.
Spend so far: 150 gens.
