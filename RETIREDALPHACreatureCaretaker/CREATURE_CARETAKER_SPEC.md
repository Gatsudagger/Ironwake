# Creature Caretaker — Master Game Design Specification
**Version:** 1.0 | **Engine:** GameMaker Studio 2 | **Developer:** Miles  
**Project Path:** `C:\Users\miles\GameMakerProjects\CreatureCaretaker\CreatureCaretaker.yyp`

---

> **HOW TO USE THIS DOCUMENT**  
> Paste this at the start of every Claude Code or Cursor session:  
> *"Read CREATURE_CARETAKER_SPEC.md in full before writing any code. Do not guess asset names — use only the names listed in Section 6."*

---

## TABLE OF CONTENTS

1. [Game Overview](#1-game-overview)
2. [Creatures & Stats](#2-creatures--stats)
3. [Biomes & Passive Growth](#3-biomes--passive-growth)
4. [Time System](#4-time-system)
5. [Breeding System](#5-breeding-system)
6. [Asset Pipeline — CRITICAL](#6-asset-pipeline--critical)
7. [File Map & Script Responsibilities](#7-file-map--script-responsibilities)
8. [Rooms & UI Screens](#8-rooms--ui-screens)
9. [Game Loop Overview](#9-game-loop-overview)
10. [Known Issues & Bugs](#10-known-issues--bugs)
11. [Session Template](#11-session-template)

---

## 1. Game Overview

**Genre:** Creature breeding / life simulation RPG  
**Core Loop:** Catch wild creatures → raise them in biomes to grow stats → breed them for stronger offspring → repeat  
**Tone:** Cozy but strategic. No combat between player-owned creatures (yet). Focus is on breeding optimization and creature care.

**Win Condition (v1):** None — sandbox progression. Player builds the strongest possible creature through selective breeding and biome optimization.

---

## 2. Creatures & Stats

### 2.1 The Eight Stats

| Stat | ID Enum | Description |
|------|---------|-------------|
| Strength | STAT.STRENGTH | Physical power, carrying capacity, melee task performance |
| Agility | STAT.AGILITY | Movement speed, dodge chance, quick task completion |
| Dexterity | STAT.DEXTERITY | Fine motor tasks, crafting efficiency, accuracy |
| Stamina | STAT.STAMINA | How many tasks a creature can perform before exhaustion |
| Intellect | STAT.INTELLECT | Learning rate, bond growth speed, puzzle solving |
| Willpower | STAT.WILLPOWER | Resistance to negative conditions, focus under stress |
| Defense | STAT.DEFENSE | Damage reduction, environmental resistance |
| Health | STAT.HEALTH | Maximum HP pool |

**Stat Range:** All stats operate between 0 and 100 (base). Biome bonuses are additive and tracked separately (see Section 3).

---

### 2.2 Creature Roster

#### HAREHOUND
- **Description:** A rabbit-dog hybrid. Fierce, loyal, and tireless.
- **Archetype:** Balanced physical / high stamina
- **Wild Encounter Time:** Morning
- **Base Stats:**

| Strength | Agility | Dexterity | Stamina | Intellect | Willpower | Defense | Health |
|----------|---------|-----------|---------|-----------|-----------|---------|--------|
| 80 | 75 | 60 | 80 | 55 | 78 | 30 | 65 |

---

#### AMPHIBI
- **Description:** An electric frog. Playful and brilliant but fragile.
- **Archetype:** High intellect / low defense glass cannon
- **Wild Encounter Time:** Midday
- **Base Stats:**

| Strength | Agility | Dexterity | Stamina | Intellect | Willpower | Defense | Health |
|----------|---------|-----------|---------|-----------|-----------|---------|--------|
| 30 | 55 | 75 | 55 | 80 | 35 | 30 | 35 |

---

#### BOULDEER
- **Description:** A bone-armored deer. Territorial and built like a fortress.
- **Archetype:** Tank / high defense
- **Wild Encounter Time:** Dawn and Dusk only
- **Base Stats:**

| Strength | Agility | Dexterity | Stamina | Intellect | Willpower | Defense | Health |
|----------|---------|-----------|---------|-----------|-----------|---------|--------|
| 85 | 50 | 55 | 55 | 55 | 60 | 90 | 60 |

---

#### SALAPENT
- **Description:** A six-legged snake-salamander. Shy but nimble and clever.
- **Archetype:** Speed + intellect hybrid
- **Wild Encounter Time:** Evening
- **Color Variants (10 total):** Crimson/Gold, Cobalt/Silver, Emerald/Black, Purple/White, Orange/Teal, Pink/Grey, Yellow/Brown, White/Ice Blue, Midnight Black/Red, Forest Green/Copper
- **Base Stats:**

| Strength | Agility | Dexterity | Stamina | Intellect | Willpower | Defense | Health |
|----------|---------|-----------|---------|-----------|-----------|---------|--------|
| 30 | 80 | 78 | 58 | 75 | 55 | 30 | 55 |

---

#### RAPTOWL
- **Description:** A raptor-owl predator. Silent, precise, and high-risk.
- **Archetype:** High agility / dexterity assassin
- **Wild Encounter Time:** Night only
- **Base Stats:**

| Strength | Agility | Dexterity | Stamina | Intellect | Willpower | Defense | Health |
|----------|---------|-----------|---------|-----------|-----------|---------|--------|
| 65 | 85 | 82 | 50 | 60 | 65 | 25 | 45 |

---

### 2.3 Creature Data Structure (GML Struct)

Every creature instance uses this struct. **Do not add or remove fields without updating scr_save_load.gml.**

```gml
{
    // Identity
    uid:          "",        // unique ID, generated at creation (string)
    species:      SPECIES.HAREHOUND,
    name:         "unnamed",
    generation:   1,
    age_days:     0,

    // Base stats (fixed at creation from species defaults)
    base_strength:   80,
    base_agility:    75,
    base_dexterity:  60,
    base_stamina:    80,
    base_intellect:  55,
    base_willpower:  78,
    base_defense:    30,
    base_health:     65,

    // Biome bonus stats (accumulated separately, see Section 3)
    bonus_strength:   0,
    bonus_agility:    0,
    bonus_dexterity:  0,
    bonus_stamina:    0,
    bonus_intellect:  0,
    bonus_willpower:  0,
    bonus_defense:    0,
    bonus_health:     0,

    // Current state
    current_stamina:  80,    // depletes with tasks, restores at Night
    current_health:   65,
    biome:            BIOME.NONE,
    bond:             0,     // 0-100

    // Visual
    color_variant:    0,     // 0-9, only used by Salapent
    sprite_name:      "",    // exact GameMaker sprite asset name (see Section 6)

    // Lineage
    parent_a_uid:    "",
    parent_b_uid:    "",
}
```

---

## 3. Biomes & Passive Growth

### 3.1 Biome Definitions

> ⚠️ Use the exact enum names below — they live in `scr_biome_growth.gml`. Short names like BIOME.ALPINE or BIOME.MOUNTAIN do not exist and will crash.

| Biome | Exact Enum | Boosted Stats | Rate Field | Cap Per Stat |
|-------|-----------|---------------|------------|--------------|
| Alpine Forest | `BIOME.ALPINE_FOREST` | Defense, Willpower | 1 day | +15 |
| Temperate Forest | `BIOME.TEMPERATE_FOREST` | All stats except Health (7) | 3 days | +4 |
| Jungle | `BIOME.JUNGLE` | Agility, Dexterity | 1 day | +15 |
| Oasis | `BIOME.OASIS` | Stamina, Willpower | 1 day | +15 |
| Mountain Valley | `BIOME.MOUNTAIN_VALLEY` | Strength, Defense | 1 day | +15 |

**No BIOME.NONE** — unassigned biome is represented as `-1`. Always guard: `if (biome_id < 0 \|\| biome_id >= BIOME.COUNT)`.

**Real biome struct fields** (from `scr_biome_growth.gml`):
- `stats` — array of STAT_* strings (NOT `boosted_stats`)
- `rate_days` — growth interval (NOT `growth_rate`)
- `cap_per_stat`, `total_cap`, `name`, `icon`, `desc`, `accent`

**Key functions:** `scr_biome_get_data(biome_id)`, `scr_biome_growth_apply(biome_bonus_state)`, `scr_biome_bonus_init(creature_id, biome_id)`

### 3.2 Growth Rules

- Growth only triggers when a creature **completes a task** during that in-game day
- Growth is applied to **bonus stats** (not base stats) — tracked separately
- Bonus stats are capped per the table above — `scr_stat_clamp.gml` enforces this
- Effective stat = `base_stat + bonus_stat` (used in all calculations)

---

## 4. Time System

### 4.1 Scale

| Real Time | In-Game Time |
|-----------|-------------|
| 1 real minute | 6 in-game minutes |
| 10 real minutes | 1 in-game hour |
| 40 real minutes | 1 in-game day |
| 4 real hours | Full day cycle |

### 4.2 Day Phases

| Phase | In-Game Hours | Real Duration |
|-------|--------------|---------------|
| Morning | 0–6 | 0–60 real min |
| Midday | 6–12 | 60–120 real min |
| Evening | 12–18 | 120–180 real min |
| Night | 18–24 | 180–240 real min |

### 4.3 Phase Rules

- **Morning:** Feeding, grooming, resource collection available
- **Midday:** Training, quests, exploration available
- **Evening:** Breeding activities, socializing creatures
- **Night:** Rest only. Tasks attempted at night cost **double stamina**. Stamina fully restores at end of Night phase.
- **Dawn/Dusk:** Transition windows (~30 in-game minutes each) — only time Bouldeer can be encountered in the wild

### 4.4 Wild Encounter Windows

| Creature | Encounter Phase |
|----------|----------------|
| Harehound | Morning |
| Amphibi | Midday |
| Salapent | Evening |
| Raptowl | Night |
| Bouldeer | Dawn and Dusk only |

---

## 5. Breeding System

### 5.1 Eligibility

- Two creatures required (no self-breeding)
- Both must have Stamina > 30 at time of breeding
- Breeding is only available during **Evening** phase
- Same species breeding only (v1 — cross-species breeding is a future feature)

### 5.2 Stat Inheritance Formula

For each of the 8 stats, offspring stat is calculated as:

```
base = (parent_a_base_stat + parent_b_base_stat) / 2
variance = random_range(-5, 5)
mutation_roll = random(1)  // 0.0 to 1.0

if mutation_roll < 0.05:  // 5% mutation chance
    offspring_stat = clamp(base + random_range(-15, 15), 10, 100)
else:
    offspring_stat = clamp(base + variance, 10, 100)
```

- Biome bonuses from parents **do NOT transfer** to offspring
- Offspring start with zero biome bonuses and must be raised in a biome
- Offspring generation = max(parent_a_generation, parent_b_generation) + 1

### 5.3 Inheritance Priority (future v2 feature — note here for planning)
- Dominant/recessive gene system for color variants
- Trait locking via special items

---

## 6. Asset Pipeline — CRITICAL

> **This section exists because the asset pipeline is currently broken.**  
> Claude Code must read this section before assigning ANY sprite, sound, or object reference.

### 6.1 The Core Problem

Claude Code guesses asset names. GameMaker asset names are **exact and case-sensitive**. A sprite named `spr_harehound_idle` is NOT the same as `spr_Harehound_Idle`. Wrong names cause silent failures — the game loads but uses a placeholder or crashes.

### 6.2 The Rule: Always Audit Before Assigning

Before writing any code that references a sprite, sound, or object by name, Claude Code must run:

```bash
# List all sprites in the project
find "C:/Users/miles/GameMakerProjects/CreatureCaretaker/sprites" -name "*.yy" | sed 's/.*\///' | sed 's/.yy//'

# List all objects
find "C:/Users/miles/GameMakerProjects/CreatureCaretaker/objects" -name "*.yy" | sed 's/.*\///' | sed 's/.yy//'

# List all scripts
find "C:/Users/miles/GameMakerProjects/CreatureCaretaker/scripts" -name "*.gml" | sed 's/.*\///' | sed 's/.gml//'

# List all rooms
find "C:/Users/miles/GameMakerProjects/CreatureCaretaker/rooms" -name "*.yy" | sed 's/.*\///' | sed 's/.yy//'
```

**Only use asset names that appear in this output. Never assume a name exists.**

### 6.3 Sprite Naming Convention (ESTABLISH AND ENFORCE THIS)

All new sprites added to the project must follow this convention:

```
spr_{creature}_{state}
spr_{creature}_{state}_{variant}

Examples:
spr_harehound_idle
spr_harehound_walk
spr_harehound_sleep
spr_amphibi_idle
spr_bouldeer_idle
spr_salapent_idle_crimson_gold
spr_raptowl_idle
spr_biome_alpine
spr_biome_temperate
spr_biome_jungle
spr_biome_oasis
spr_biome_mountain
spr_ui_statbar
spr_ui_button_breed
```

### 6.4 Assigning Sprites in Code

**CORRECT — use sprite_get() to verify existence first:**

```gml
// In obj_creature Create event:
var _spr_name = creature_data.sprite_name;
if sprite_exists(asset_get_index(_spr_name)) {
    sprite_index = asset_get_index(_spr_name);
} else {
    sprite_index = spr_placeholder;  // fallback
    show_debug_message("WARNING: sprite not found: " + _spr_name);
}
```

**WRONG — never hardcode guessed names:**
```gml
sprite_index = spr_Harehound;  // BAD - guessed name, will break
```

### 6.5 Object Naming Convention

```
obj_{purpose}

Examples:
obj_game_controller    // persistent global controller
obj_creature           // base creature display object
obj_ui_hud             // HUD overlay
obj_ui_creature_list   // creature roster screen
obj_ui_biome_select    // biome selection screen
obj_ui_breeding        // breeding screen
```

### 6.6 Script Naming Convention

```
scr_{system}_{action}

Examples:
scr_creature_data       // creature struct definitions and constructors
scr_biome_data          // biome struct definitions
scr_time_system         // time tick and phase calculation
scr_passive_growth      // apply biome growth on day tick
scr_stat_clamp          // enforce stat min/max
scr_breeding            // offspring generation
scr_save_load           // JSON serialization
```

### 6.7 .yy File Format — CRITICAL

GameMaker expects **v0 format** in .yy files. Claude Code sometimes generates v1 format which the IDE rejects.

**Rule:** Before generating any new .yy file (object, room, sprite), read an existing working file from the project to match the format:

```bash
cat "C:/Users/miles/GameMakerProjects/CreatureCaretaker/rooms/Room1/Room1.yy"
```

Match that exact format. Never use `$GMObject v1` — use `$GMObject` with no version tag, matching whatever the existing files use.

### 6.8 GameMaker Workflow Rules

1. **Close GameMaker** before Claude Code writes any .yy or .gml files
2. **Reopen GameMaker** after writes are complete to reload assets
3. **Never write files while GameMaker is open** — it will overwrite Claude Code's changes on next save

---

## 7. File Map & Script Responsibilities

> ⚠️ **AUDIT RESULT — last updated from live project scan.**  
> Use the ACTUAL names in the right column when writing code — never the spec names.

### Scripts

| Actual Name | Responsibility | Status |
|-------------|---------------|--------|
| `scr_creature_data` | SPECIES enum, STAT_* macros, base stat templates, `scr_creature_create(species)` constructor | ✅ Fixed today |
| `scr_biome_growth` | ALL biome logic: `scr_biome_data_init()`, `scr_biome_get_data()`, `scr_biome_bonus_init()`, `scr_biome_growth_apply(bonus_state)`, `scr_biome_get_effective_stat()`, `scr_biome_get_bonus_summary()` | ✅ Exists |
| `scr_time_system` | Real-to-game time, phase detection, `global.day_just_advanced` flag | ✅ Exists |
| `scr_stat_clamp` | `clamp_base_stats()`, `clamp_bonus_stats()` — guards biome_id < 0 | ✅ Created today |
| `scr_creature_skills` | 3 skills per species (15 total), `scr_creature_skills_init()`, `scr_skill_get_power()` | ✅ Exists |
| `scr_ui_utils` | `scr_draw_pixel_button()`, `scr_draw_panel()`, `scr_draw_character_preview()`, `scr_get_stat_colour()` | ✅ Exists |
| `scr_save_load` | JSON serialization — **needs audit against new creature instance struct** | ⚠️ Needs audit |
| `scr_breeding` | Offspring generation from two parent structs | 🔴 MISSING — Task E |
| ~~`scr_biome_data`~~ | Was duplicate of scr_biome_growth — **deleted** | 🗑️ Gone |

### Objects

| Name | Responsibility | Status |
|------|---------------|--------|
| `obj_game_controller` | Persistent global controller; creature list, time, player name, biome | ✅ Exists |
| `obj_creature` | Visual display of one creature; reads from creature struct | ✅ Exists |

### Sprites — Creatures

> **Actual naming convention in project: `spr_creature_*` and `spr_walk_*`**  
> Confirm exact names with audit before assigning. Never guess suffixes.

| Sprite Purpose | Expected Name Pattern |
|---------------|----------------------|
| Creature idle | `spr_creature_{name}` |
| Creature walking | `spr_walk_{name}` |
| Fallback placeholder | `spr_placeholder` — 🔴 MISSING, must create a 1-frame placeholder sprite |

### Sprites — World & UI (present in project, not yet used in creature systems)

| Sprite | Notes |
|--------|-------|
| `spr_bg_grass` | Background tile |
| `spr_npc_*` | 9 NPC sprites — not yet wired to any system |
| `spr_player` | Player character sprite |
| `spr_skill_icons` | Skill icon sheet |
| `spr_tileset_house` | House tileset |
| `spr_tileset_overworld` | Overworld tileset |
| `spr_tree_oak` | Oak tree |
| `spr_tree_spruce` | Spruce tree |
| `spr_ui_icons_16` | UI icon sheet |

### Sprites — Biomes (ALL MISSING)

These must be created and added to GameMaker before the biome selection screen can work:

| Sprite Needed | Notes |
|--------------|-------|
| `spr_biome_alpine` | Alpine Forest selection card art |
| `spr_biome_temperate` | Temperate Forest selection card art |
| `spr_biome_jungle` | Jungle selection card art |
| `spr_biome_oasis` | Oasis selection card art |
| `spr_biome_mountain` | Mountain Valley selection card art |

**Status key:** ✅ Verified working | ⚠️ Exists but needs audit | 🔴 Missing or broken

---

## 8. Rooms & UI Screens

> ⚠️ **AUDIT RESULT** — right column shows actual room names in project. Always use actual names in code.

| Spec Name | Actual Name | Purpose | Status |
|-----------|------------|---------|--------|
| `rm_title` | — | Title screen | 🔴 Missing |
| `rm_new_game` | `rm_char_create` | Player name entry + starter creature select | ✅ Exists — **use `rm_char_create`** |
| `rm_biome_select` | `rm_creature_select` | Choose starting biome | ✅ Exists — **use `rm_creature_select`** |
| `rm_main` | `rm_ranch` | Primary gameplay room | ✅ Exists — **use `rm_ranch`** |
| `rm_creature_list` | — | Scrollable list of owned creatures | 🔴 Missing |
| `rm_creature_detail` | — | Full stat view for one creature | 🔴 Missing |
| `rm_breeding` | — | Breeding UI | 🔴 Missing |
| `rm_wild_encounter` | — | Wild creature encounter and catch | 🔴 Missing |

---

## 9. Game Loop Overview

```
GAME START
  └─ rm_new_game: Enter player name, pick starter creature (Harehound / Amphibi / Bouldeer)
        └─ rm_biome_select: Choose starting biome
              └─ rm_main: Core loop begins

CORE LOOP (rm_main)
  ├─ Time advances (scr_time_system alarm tick)
  ├─ Phase changes trigger events (morning feed prompt, night rest, etc.)
  ├─ Player assigns creatures to tasks
  │     └─ Task completion → scr_passive_growth (if task done this in-game day)
  ├─ Wild encounter check (time of day vs encounter table)
  │     └─ Match → rm_wild_encounter
  ├─ Evening: Breeding available → rm_breeding
  └─ Night: Force rest, restore stamina, apply day tick to all creatures
```

---

## 10. Known Issues & Bugs

> Updated from live audit. Fix in priority order.

| Priority | Issue | Root Cause | Fix |
|----------|-------|-----------|-----|
| 🔴 P1 | `scr_biome_data` missing | Never created | Create it — Task A below |
| 🔴 P1 | `scr_stat_clamp` missing | Never created | Create it — Task B below |
| 🔴 P1 | `spr_placeholder` missing | Never created | Add 1-frame 32x32 white square sprite in GameMaker IDE named `spr_placeholder` |
| 🔴 P1 | Code references `scr_passive_growth` — project has `scr_biome_growth` | Name drift | Use `scr_biome_growth` everywhere — never write `scr_passive_growth` in new code |
| 🔴 P1 | Spec room names don't match project | Name drift | Use `rm_char_create`, `rm_ranch`, `rm_creature_select` — never old spec names |
| 🟡 P2 | All 5 biome sprites missing | Not imported yet | Import pixel art into GameMaker IDE as `spr_biome_alpine`, `spr_biome_temperate`, `spr_biome_jungle`, `spr_biome_oasis`, `spr_biome_mountain` |
| 🟡 P2 | `scr_breeding` missing | Never created | Create after P1 fixes — Task C |
| 🟡 P2 | 4 rooms missing | Not yet built | Build after core scripts verified |
| 🟢 P3 | NPC sprites, player sprite, tilesets exist but unwired | Filler from early build | Leave alone until core creature loop works |

---

## 11. Session Template

**Copy-paste this at the start of every Claude Code session:**

```
CONTEXT: I am building Creature Caretaker in GameMaker Studio 2.
Project: C:\Users\miles\GameMakerProjects\CreatureCaretaker\CreatureCaretaker.yyp
Spec: CREATURE_CARETAKER_SPEC.md — read this in full before writing anything.

CRITICAL NAME CORRECTIONS (use these, not the old spec names):
- scr_biome_growth (NOT scr_passive_growth)
- rm_char_create (NOT rm_new_game)
- rm_ranch (NOT rm_main)
- rm_creature_select (NOT rm_biome_select)
- Sprite convention: spr_creature_* and spr_walk_* (NOT spr_{name}_idle)

RULES (non-negotiable):
1. Before referencing ANY sprite or asset by name — run the audit in Section 6.2 first
2. Use v0 .yy format — read an existing .yy file as reference before generating new ones
3. GameMaker must be CLOSED before writing files
4. Never guess asset names. Only use names confirmed by file scan

TODAY'S TASK: [paste one task from the queue below]
```

---

## 12. Prioritized Task Queue

Work through these in order. One task per Claude Code session.

### 🔴 TASK A — Create scr_biome_data
```
Read scr_creature_data.gml to understand the existing code style and struct patterns.
Then create scripts/scr_biome_data/scr_biome_data.gml with:
- BIOME enum: NONE, ALPINE, TEMPERATE, JUNGLE, OASIS, MOUNTAIN
- A get_biome_data(biome) function returning a struct with:
    name (string), boosted_stats (array of STAT enum values),
    growth_rate (days between ticks), cap_per_stat (max bonus)
- Use the exact values from Section 3.1 of the spec
- Match the code style of scr_creature_data.gml exactly
```

### 🔴 TASK B — Create scr_stat_clamp
```
Create scripts/scr_stat_clamp/scr_stat_clamp.gml with:
- clamp_base_stats(creature_struct): clamps all 8 base stats to 0-100
- clamp_bonus_stats(creature_struct): clamps each bonus stat to 0 and the cap
  defined in get_biome_data(creature_struct.biome).cap_per_stat
- Returns the modified struct
- Depends on scr_biome_data — Task A must be done first
```

### 🔴 TASK C — Audit and fix scr_creature_data
```
Read scr_creature_data.gml in full.
Compare every field against the creature struct definition in Section 2.3 of the spec.
List any fields that are missing, renamed, or have wrong default values.
Then fix the file to match Section 2.3 exactly.
Do not change field names that already exist and match — only add missing ones.
```

### 🔴 TASK D — Audit and fix obj_creature + obj_game_controller
```
Read the Create and Step events of obj_creature and obj_game_controller.
Check:
1. Does obj_game_controller initialize global_creature_list as an array?
2. Does obj_game_controller alarm[0] call scr_biome_growth? (not scr_passive_growth)
3. Does obj_creature assign sprite_index using asset_get_index() with a fallback to spr_placeholder?
Fix any of the above that are wrong. Show me the before/after for each change.
```

### 🟡 TASK E — Create scr_breeding
```
Only start this after Tasks A, B, C, D are done.
Create scripts/scr_breeding/scr_breeding.gml with a breed(creature_a, creature_b) function.
Use the inheritance formula in Section 5.2 of the spec exactly.
Return a new creature struct using scr_creature_data's constructor.
Validate that both creatures have current_stamina > 30 before proceeding.
```

### 🟡 TASK F — Build rm_creature_list room and obj_ui_creature_list
```
Only start after Tasks A-D are done.
Create a room rm_creature_list and object obj_ui_creature_list.
The screen shows a scrollable list of all creatures in global_creature_list[].
Each row shows: creature name, species, generation, top 3 stats.
Read Room1.yy for .yy format reference before writing any .yy files.
```

---

## Appendix: Breeding Quick Reference

| Stat | Parent A | Parent B | Avg | Variance | Min/Max Clamp | Mutation (5%) |
|------|----------|----------|-----|----------|---------------|---------------|
| Any stat | X | Y | (X+Y)/2 | ±5 | 10–100 | ±15 from avg |

**Mutation chance:** 5% per stat, independent rolls  
**Biome bonuses:** Never inherited — offspring start at 0 bonus  
**Generation:** max(gen_a, gen_b) + 1
