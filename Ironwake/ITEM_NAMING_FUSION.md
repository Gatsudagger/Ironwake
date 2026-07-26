# Item Name Fusion

**Added 2026-07-23.** Fixes awkward procedural item names with a double preposition
("Ashkeeper Blade of Charm **of Frost**") by fusing the two "of X" phrases into one lore phrase
("Ashkeeper Blade **of Frostbound Charm**").

## Why the double-"of" happened
Two independent functions each appended an "of X" and didn't know about each other:
- `apply_affixes_to_item` (scr_stats) — a 2+ affix item gets `"{Prefix} {Base} of {lastStatSuffix}"`.
- `apply_elemental_affix_to_item` — the weapon element rider, seeing the item already has a prefix,
  *appended* `" of {elemSuffix}"`.

The stat side only ever shows ONE suffix (the last affix's), so the collision is always exactly
**one stat/school suffix × one weapon element** (only 3: burn→"of Embers", frost→"of Frost",
shock→"of Storms"). There is never a third "of".

## How fusion resolves (scr_stats `item_fused_elem_suffix`)
When the element rider lands on an item ending in "of {statNoun}", it builds ONE phrase, in order:
1. **Bespoke pair table** (`global.name_bespoke_pairs`) — a hand-authored phrase for a specific
   `element × stat_name` combo. If present, use it.
2. **Composed fusion** — else `"of {elementAdjective} {statNoun}"`, where:
   - `elementAdjective` = `global.name_combine_adj[element]` (falls back to the element's display
     prefix if unlisted).
   - `statNoun` = the stat suffix with "of "/"of the " stripped (`affix_suffix_noun`):
     "of the Void" → "Void", "of Charm" → "Charm".

Any pair NOT in the bespoke table still auto-fuses cleanly — there is never an awkward name.

## The data (obj_game_controller Create, next to the affix pools)
**`global.name_combine_adj`** — adjective each weapon element lends when fused:
| element | combine adjective |
|---|---|
| frost | Frostbound |
| burn  | Emberwreathed |
| shock | Stormbound |

**`global.name_bespoke_pairs`** — special-cased combos (grow freely):
| elem | stat | phrase |
|---|---|---|
| frost | CHA | of Winterheart |
| burn  | CHA | of the Ember Muse |
| shock | INT | of the Tempest Mind |
| frost | crit_flat | of Shatterfrost |
| burn  | STR | of the Forgeborn |

To add a bespoke name: append `{ elem: "<burn|frost|shock>", stat: "<stat_name>", phrase: "of ..." }`
to `global.name_bespoke_pairs`. `stat_name` values come from `global.affix_pool` /
`global.school_affix_pool` (STR/DEX/CON/INT/WIS/CHA, bonus_max_hp, crit_flat, dodge_flat,
gold_find, school_fire … school_blood).

## Examples (composed default)
| Today (awkward) | Fused |
|---|---|
| Blade of Charm of Frost | Blade of Frostbound Charm |
| Sword of Might of Embers | Sword of Emberwreathed Might |
| Axe of Grit of Storms | Axe of Stormbound Grit |

## INVARIANT: droppable base names must NOT contain " of "
The affix namer appends "of {suffix}", so a base name that already contains "of" produces a
second double-"of" the fusion system does NOT catch (it only handles stat×element). Full scan
07-23 found exactly ONE offender: **"Medallion of Endurance"** (rare amulet) → renamed to
**"Enduring Medallion"** (Create_0 + its art-case in scr_ui `ui_item_art_sprite`; the sprite asset
id `spr_item_art_medallion_of_endurance` was left unchanged). Legendaries with "of" names (Crown of
the Hollow King, Thief of Hours) are safe — they return with fixed names and never get affixes
appended. **When adding any droppable common/uncommon/rare base, keep "of" out of the name.**

## Notes
- **Existing saved items keep their old names** until re-rolled — names are stored on the item
  struct. New drops use fusion. Not worth a save migration (purely cosmetic).
- 1-affix or 0-affix items + an element still use the element's PREFIX form
  ("Flaming {Base} of Charm") — no collision, unchanged.
- Legendaries with hand-authored `.name`/`.affixes` don't go through the random element-roll path,
  so they're unaffected.
