# SYSTEMS — Skin Expansion + Gender Variants

**Status: BUILT (2026-06-22) — code + all 23 sprites done & registered; NOT compile-tested in IDE.**
All 20 skins + 3 female class sprites generated (PixelLab, 8-dir 96×96), built via
`tools/build_char_sprite.py` (clones spr_arcanist .yy), registered in Ironwake.yyp via
`tools/register_skins.py`. PixelLab "heavy load" forced firing in small batches of ~4.
Extends SYSTEMS_VAEL.md (skins) and the character creator (`obj_char_select`).
Decisions confirmed by M: gender = **combat sprite only**; skin art = **single side-view
frame now, expandable to 8-dir + idle anim later**; ladder = **as proposed**.

---

## PART A — Aesthete skins (20 new → 23 total)

### A1. Catalog changes (`vael_skin_catalog()` in scr_stats)
Add two optional fields to each entry; existing shape stays valid:
```
{ id, name, sprite, gold, desc,
  req,      // optional milestone gate id (omitted/"" = ungated)
  gender }  // optional "m"|"f" cosmetic tag (display only; any player can wear any skin)
```
- **Pricing:** bump `ashen` 150 → **250g** (all ungated skins now floor at 250g).
- Sprites referenced via `asset_get_index("spr_skin_<id>")` cached at catalog build so the
  project compiles before the art exists; a missing sprite → entry shows but the preview
  falls back to the class look (never errors).

### A2. Milestone gating
New helper `vael_skin_unlocked(skin)`:
- no `req` → always available (purchasable with gold immediately).
- has `req` → unlocked once the benchmark is met; **still costs gold** after unlock.

Gate ids → condition (all existing trackable globals):
| req id | Condition |
|---|---|
| `clear1`  | `dungeon_clears_total >= 1` (first full dungeon clear) |
| `awk1`    | `highest_awakening_unlocked() >= 2` (cleared an A1) |
| `awk2`    | `highest_awakening_unlocked() >= 3` (cleared an A2) |
| `awk3`    | `highest_awakening_unlocked() >= 4` (cleared an A3) |
| `awk4`    | `highest_awakening_unlocked() >= 5` (cleared an A4) |

*(Awakening unlock is "next tier unlocked on clear", so clearing A1 sets unlocked=2, etc.)*

`vael_buy_skin` gains a gate check: locked → return its requirement text. Vael UI shows a
locked skin greyed with its requirement (e.g. "Clear an A2 dungeon") in place of the buy line.

### A3. The 20 new skins (+ 3 existing = 23)
~8 female-presenting (★). Names/themes first-pass; tunable.

**Ungated — 250–400g**
1. `wanderer`  Wanderer's Garb — travel-worn cloak — 250g
2. `hearth` ★ Hearthguard — warm banded leather — 300g
3. `duskhide`  Duskhide — dark rogue leathers — 320g
4. `pilgrim` ★ Pilgrim's Shroud — hooded ascetic robe — 360g
5. `ironscale` Ironscale — riveted scale armor — 400g

**First Blood — `clear1` — 350–550g**
6. `gravewalker` Gravewalker — grave-dirt plate — 420g
7. `bloodsworn` ★ Bloodsworn — crimson warsuit — 480g
8. `cryptlight` Cryptlight — lantern-bearer's wraps — 550g

**Awakened I — `awk1` — 550–750g**
9. `frostbit` ★ Frostbitten — ice-rimed mail — 600g
10. `cinderclad` Cinderclad — charred warplate — 680g
11. `mirewalker` Mirewalker — bog-shrouded hide — 750g

**Awakened II — `awk2` — 750–1000g**
12. `stormcall` ★ Stormcaller — storm-charged robes — 820g
13. `bonechoir` Bonechoir — bound-bone armor — 900g
14. `veilbind` ★ Veilbinder — shadow-mage shroud — 1000g

**Awakened III — `awk3` — 1000–1400g**
15. `goldwrought` ★ Goldwrought — gilded regalia — 1150g
16. `voidtouch` Voidtouched — star-eaten dark plate — 1250g
17. `sanguine` ★ Sanguine Regalia — vampire-lord finery — 1400g

**Awakened IV — `awk4` — 1400–2000g**
18. `dawnbreak` Dawnbreaker — radiant crusader plate — 1550g
19. `doomherald` Doomherald — apocalyptic warlord — 1750g
20. `sovereign` ★ Eternal Sovereign — prestige crown regalia — 2000g

### A4. Skin art (PixelLab)
Each new skin = **single side-view frame, 92×92**, facing right (matches combat draw).
Sprite ids `spr_skin_<id>`. Resource `.yy` is a 1-frame sprite (like map objects), but named/
shaped so 8 directional frames can be appended later without renaming.

**Combat frame index (handles 1-frame now / 8-frame later):**
`var _fr = (sprite_get_number(_spr) >= 8) ? 1 : 0;` — 8-dir uses east=frame 1, single uses 0.
Applied in `player_combat_sprite` consumers (`obj_combat_controller/Draw_64`).

---

## PART B — Gender / female class variants

### B1. New axis
`global.player_gender = "m"` (default), saved/loaded via scr_save. Cosmetic only — no stat
or mechanical effect.

### B2. Female class combat sprites
3 new sprites matching the existing 92×92 side-view class sprites:
`spr_arcanist_f`, `spr_bloodwarden_f`, `spr_shadowstrider_f`. (8-directional to match the
male class sprites, since these are the persistent class look, not gated skins.)

`player_combat_sprite(class_id)` updated:
- default look picks male/female by `global.player_gender`.
- a skin override still wins over both (skins are full-body; gender-agnostic to wear).

### B3. Character creator UI (`obj_char_select`)
Same screen as class + stats (no new step). Add a **male/female toggle** that shows both
class sprites side-by-side; selecting sets the working gender. New Create var
`selected_gender = "m"`; committed to `global.player_gender` on confirm (alongside class/
stats/name/portrait). Input: a key (e.g. **Tab** or **Q/E**) flips gender; both sprites drawn,
the chosen one highlighted. Portrait headshot remains its own independent pick (unchanged).

---

## Integration points
- **scr_stats** — `vael_skin_catalog` (+req/gender, asset_get_index refs), `vael_skin_unlocked`,
  `vael_buy_skin` (gate check), `player_combat_sprite` (gender default + frame-count-safe).
- **scr_ui** — `ui_draw_vael_screen` (locked rows show requirement; price tiers).
- **obj_char_select** — Create (`selected_gender`), Step (toggle input), Draw (dual sprite + toggle).
- **obj_combat_controller/Draw_64** — frame index `(sprite_get_number>=8)?1:0`.
- **scr_save** — persist `player_gender` (skins already persisted).
- **Ironwake.yyp** — register 23 new sprites (20 `spr_skin_*` + 3 `spr_*_f`). Created by Claude
  (approved-art exception); M opens Ironwake fresh so they ingest on next open.

## Build order
Code-first (all catalog/gating/gender/UI referencing sprites by name → compiles before art),
then generate the 23 sprites in batches and drop them in. Locked skins + gender toggle are
testable immediately; art fills in as it lands.

## Future / out of scope (noted, not built)
- **8-directional skins + idle animation** (M wants this) — sprites built single-frame but
  expandable; the catalog/draw already tolerate multi-frame.
- **Inventory character viewer** — rotating model + basic idle anim to show off your
  character/skin (M's idea). Depends on the 8-dir art above. Separate future feature.
- Female portrait set / gender-filtered portrait gallery (M chose combat-sprite-only for now).
