# Ironwake Promo Thumbnail Design Doc

Style reference for YouTube Shorts / promo video thumbnails, established 2026-08-21
with the pets Short and the NPC series. **These are the sample versions** — reuse the
template (and the generator scripts in this folder) for every future category so the
channel reads as one consistent set.

Everything is composited from **shipped game assets only** — no generated art, no
credits spent. Regenerate any thumbnail with:

```
python gen_thumbs.py        # NPC series + dungeon (config-driven, see NPCS list)
python gen_thumb_pets.py    # the original pets-Short thumbnail
```

(Scripts expect the fonts in `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and read
sprites straight from `sprites\`. The camp/title backdrop frames are pulled from the
capture videos on `D:\Ironwake Videos` — see each script's header.)

---

## The template (1080x1920 vertical)

| Band | Content | Spec |
|---|---|---|
| y 90–300 | **Name / category** | Cinzel Decorative Bold ~200px, bright gold `#FFF4C8`, 12px near-black stroke `#0A0806` |
| y 330–430 | **Role / subtitle** | Cinzel ~76px, gold `#E9D9A8`, 8px stroke |
| y 470–1230 | **Painted portrait** | contain-fit in a 660x760 box, double gold frame: inner 6px `#B4965A`, outer 4px `#5A4628` on dark `#0C0E18` backing |
| y ~1200–1600 | **Pixel sprite (left) + thematic icons (right)** | sprite ~460px tall bottom-left at x300; icons fanned bottom-right (spots below), each on a colored radial glow |
| y 1770 | **Tagline** | EB Garamond ~64px gold, three words: `VERB • VERB • VERB` |

**Backdrop** — a warm in-game frame (camp firelight for NPCs, combat bg for dungeon,
title screen for pets), cover-cropped to 9:16, Gaussian blur 18 (11 for scenic art
with no UI), then shaded: base +60 alpha black, ramping to +200 at the bottom and
+180 at the very top so screen chrome (headers, carousel arrows) can never read
through behind the text.

**Pixel sprites** — always NEAREST-neighbor at an **integer factor** (crisp pixels,
never smoothed — same rule as in-game density). Painted art (portraits, boss HD,
splashes) scales LANCZOS.

**Glows** — solid-color ellipse, Gaussian blur 60, alpha ~150–165. One glow per
element cluster. Pick colors from the NPC's palette (table below).

**Icon fan spots** (center points, no overlap crush):
- 1 icon: (760, 1440)
- 2 icons: (670, 1370), (860, 1530)
- 3 icons: (620, 1340), (900, 1430), (730, 1595)

---

## The sample set

| File | Category | Portrait sprite | Pixel sprite | Icons | Glow | Tagline |
|---|---|---|---|---|---|---|
| `thumb_pets.png` | Pets (Bairc) | — (title-screen bg) | voidkit baby + wyrmling adult + dust egg | — | blue / amber / violet | HATCH • RAISE • CORRUPT |
| `thumb_dorn.png` | Dorn — The Blacksmith | `Blacksmith_1__Dark_Gritty_` | `spr_npc_dorn_idle` | `spr_icon_sword_fire_a` | ember orange | TEMPER • REFORGE • CRAFT |
| `thumb_maren.png` | Maren — The Runesmith | `Runesmith_3__Facewrap_` | `spr_npc_maren_idle` | rune icons: abyss, aether, avatar | arcane blue/violet | SOCKET • COMBINE • AWAKEN |
| `thumb_sable.png` | Sable — The Alchemist | `Alcehmist_2__Flirty_` | `spr_npc_sable_idle` | master healing draught, phoenix tonic, faeries tear | brew green | BREW • BOTTLE • EMPOWER |
| `thumb_petra.png` | Petra — The Merchant | `Merchant_7__Voluptuous_` | `spr_npc_petra_idle` | `spr_icon_gold`, `spr_icon_valuable_sovereigns_signet` | coin gold | BUY • SELL • TRADE |
| `thumb_vex.png` | Vex — The Trainer | `Trainer_2__Sullen_` | `spr_npc_vex_idle` | ability icons: arcane burst, assassinate, blazing palm | blood red | LEARN • TRAIN • MASTER |
| `thumb_vael.png` | Vael — The Aesthete | `Aesthete_2__Gothic_` | `spr_npc_vael_idle` | `spr_event_splash_whispering_mirror` | violet | SKINS • PORTRAITS • FLAIR |
| `thumb_dungeon.png` | Dungeon / abilities | — (`spr_combatbg_ashen_1` bg) | `spr_bone_sovereign_hd` (LANCZOS, it's painted-grade) | ability icon row of 4 | violet + ember | FIGHT • CAST • DESCEND |

Carousel portrait order in code (obj_hub_controller Draw_64, `_port_sprites`):
Blacksmith=Dorn, Alchemist=Sable, Runesmith=Maren, Trainer=Vex, Merchant=Petra,
Aesthete=Vael; Bairc uses `spr_npc_bairc_portrait`.

---

## Lessons already paid for (keep them)

1. **Vet at feed-tile size** before showing anything — shrink to ~360px wide and check
   the name still reads and nothing ghosts.
2. **Blur is not enough to hide UI** — high-contrast screen text (camp header, blue
   carousel chevrons) survives blur 11; it takes blur 18 **plus** the top shade band.
3. **Icon names lie** — `spr_icon_chest` is the armor *slot*, not a treasure chest;
   `spr_icon_consumable_chaotic_brew` renders as a black blob at thumbnail scale.
   Always eyeball every icon in the composite before calling it done.
4. **Cute-vs-menacing contrast** is the hook that worked on the pets thumbnail
   (voidkit beside the wyrmling). Prefer one charming + one imposing element over
   two similar ones.
5. Three-word verb taglines, all caps, gold, dot-separated — the series signature.

## Adding a new category

Add one entry to the `NPCS` list in `gen_thumbs.py` (name, role, portrait, sprite,
icons+sizes, two glow colors, tagline) and run it. For a non-NPC category, follow the
dungeon block at the bottom of the script: pick a thematic backdrop sprite, one hero
element, one icon row.
