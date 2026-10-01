# ARMOR WEIGHT CLASSES — design (M-requested 2026-07-31, awaiting number approval)

M: "armor is never really prominent on much equipment and should exist in varying
degrees on leather/plate armor, with more on plate less on leather and basically
none on robes cloth... categorize equipment into light medium heavy."

## What Armor does today (unchanged)
Flat reduction subtracted from every enemy hit AFTER % reductions; a landed hit
always deals at least 1. Sources today: shield "of Warding" affixes, Ironhide /
Feast of Crows boons. Body armor carries none — that's the gap.

## Classification: DERIVED, never stored (no save migration)
Same philosophy as the computed stat-requirement system: weight class is derived
from the item at read time, applies to all existing gear (incl. the 63 variants)
and every future drop automatically.

`item_weight_class(item)` for slots chest / helm / gloves / boots:
1. base_name keyword match first:
   - HEAVY:  plate, mail, visor, bulwark, iron, tower, greaves
   - MEDIUM: leather, hide, scale, brigand, chain
   - CLOTH:  robe, cloth, hood, wrap, silk, veil, tatter
2. Fallback by primary stat: STR/CON → HEAVY, DEX → MEDIUM, INT/WIS/CHA → CLOTH.
Shields (offhand_kind "shield") get a flat baseline of their own, stacking with
any of-Warding affix. Weapons/jewelry/focus offhands: never.

## Proposed baseline Armor (per piece, by rarity C/U/R/E/L)
| Slot   | HEAVY     | MEDIUM    | CLOTH |
|--------|-----------|-----------|-------|
| Chest  | 1/2/2/3/4 | 0/1/1/2/2 | 0     |
| Helm   | 1/1/2/2/3 | 0/1/1/1/2 | 0     |
| Gloves | 0/1/1/1/2 | 0/0/1/1/1 | 0     |
| Boots  | 0/1/1/1/2 | 0/0/1/1/1 | 0     |
| Shield | 1/2/2/3/4 baseline (any class) |     |

Full legendary HEAVY set = 11 Armor (+4 shield = 15). Early full common heavy
= 2. Baseline shows on the item card as its own line ("Armor: N"), separate
from affixes.

**Cloth compensation (optional, recommended):** cloth chest/helm carry
El Resist 1/1/2/2/3 instead — plate stops blades, cloth wards spells. Uses the
existing el_resist channel; nothing new in combat.

**Identity synergy:** Rare+ heavy chest/helm already DEMAND STR/CON via the
computed stat-requirement system, so plate stays a warrior's purchase; medium
keeps the DEX/dodge identity; cloth pays for its casting stats with skin.

## Presentation (same build)
- "Armor" CAPITALIZED everywhere on items (today the affix prints "+2 armor").
- Armor line prominent on item cards/rows for armor slots.
- Compendium glossary entry: ARMOR + the three weight classes.
- Stats page already has the Armor row + hover explainer (verified).

## Tuning notes / risks
- Flat armor is strongest vs multi-hit chip (double_strike mobs) — intended,
  that's plate's job; watch A5 where 15 total vs ~20-25 hits may over-mitigate.
  First lever if too strong: drop shield baseline, then gloves/boots to 0.
- Armor never reduces DoTs or status damage (unchanged rule).

## Status
**BUILT 2026-07-31** (M approved the table + cloth El Resist same session):
`item_weight_class` / `item_base_armor` / `item_base_el_resist` (scr_stats, by
item_stat_requirement), folded into apply_equipment_stats' per-item loop.
Display: ui_item_stat_str appends "+N Armor" / "+N El Resist" baseline segments
and capitalizes the armor/el_resist affix labels. Compendium glossary gained an
ARMOR entry (AP/Turn section, after Poise). Combat consumption unchanged
(equip_armor / equip_el_resist channels already existed). Awaiting M's F5.
