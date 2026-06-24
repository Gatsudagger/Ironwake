# SYSTEMS — Vael the Aesthete (Transmog / Skins)

**Status: BUILT (verify in-IDE). Confirmed by M.**
Owner NPC: **Vael the Aesthete** (hub slot **5**). Unlocked from start (testing).

---

## 1. Overview
Cosmetic transmog. v1 = **full sprite-replacement skins** for the combat player sprite,
bought with **gold** and switched freely once owned. The player is otherwise a static
class sprite (`spr_arcanist/bloodwarden/shadowstrider`), drawn only in combat + char-select.

Skins override the **combat** sprite (the player-visible one). Char-select still shows the
class sprites (that screen is about picking a class, not cosmetics).

---

## 2. Data model
```
global.player_skin    = "default";   // active skin id
global.unlocked_skins = [];           // owned non-default skin ids
```
Both persist via save/load. Registry: `vael_skin_catalog()` in scr_stats —
`[{ id, name, sprite, gold, desc }]`. `sprite == undefined` → the class default look
(no override). **This shape is the forward-compatible hook**: future per-item visual
layers extend the same catalog/registry pattern (a skin/cosmetic = data + a sprite ref).

Skins ship now:
| id | Name | Sprite (92×92, PixelLab side-view) | Price |
|---|---|---|---|
| default | Default (Class Look) | — (class sprite) | free |
| ashen | Ashen Revenant | `spr_skin_ashen` | 150g |
| ember | Emberforged | `spr_skin_ember` | 250g |
| tide | Tideborn | `spr_skin_tide` | 250g |

---

## 3. Sprite assets
PixelLab humanoids, **side view, 92×92** (matches the class sprites exactly — no resize).
8 directional frames stored in PixelLab's rotation order (south, **east**=frame 1, north,
west, …), so **frame 1 = east = facing right** toward enemies — the same frame combat
draws (`draw_sprite_ext(_pspr, 1, …)`). Built by cloning the `spr_arcanist` .yy structure
(8 frame GUIDs + shared layer GUID + sequence keyframes), registered in `Ironwake.yyp`.

`player_combat_sprite(class_id)` resolves the draw sprite: active skin's `sprite`, else the
class default. Called from `obj_combat_controller/Draw_64`.

---

## 4. Vael hub UI
`ui_draw_vael_screen()` — single skin list (reuses `ui_maren_row` geometry). Each row:
name + status (EQUIPPED / Owned→Enter to wear / price→Enter to buy) + a mini swatch.
Highlighted skin shows a description + large preview (the actual class sprite for
"default"). W/S navigate, Enter buys-or-equips, Esc closes. Buying auto-equips.
State on gc: `vael_open / vael_cursor / vael_notification`.

---

## 5. Integration points
- **scr_stats** — `vael_skin_catalog / vael_skin_get / vael_skin_owned / vael_buy_skin /
  vael_select_skin / player_combat_sprite`.
- **obj_combat_controller Draw_64** — player sprite via `player_combat_sprite`.
- **scr_ui** — `ui_draw_vael_screen()` + `ui_input_blocked` guard.
- **obj_game_controller Create/Step** — skin globals + Vael UI state + input block.
- **obj_hub_controller Create/Step/Draw_64** — unlock slot 5, blurb, interact (kb+mouse),
  draw call.
- **scr_save** — `player_skin` + `unlocked_skins` persisted.
- **Ironwake.yyp** — 3 new sprites registered (`spr_skin_ashen/ember/tide`).

---

## 6. Deferred / out of scope (v1)
- Per-item visual display on the character (the registry is shaped to grow into this).
- Skins for the char-select / hub portraits (combat-only for now).
- Skin unlocks via milestones (chose gold-purchase for v1).
- More skins / class-specific skins (add a `vael_skin_catalog()` entry + a sprite).
