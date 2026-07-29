# Creature Caretaker — Claude Session Context

## Project
- **Engine**: GameMaker Studio 2024.14.4.222
- **Genre**: Fantasy creature breeding RPG
- **Location**: `C:\Users\miles\GameMakerProjects\CreatureCaretaker\`

---

## Room Flow
```
rm_title → rm_char_create → rm_biome_select → rm_creature_select → rm_ranch
```

---

## Files Created / Modified This Session

### New Scripts
| File | Purpose |
|------|---------|
| `scripts/scr_save_load/scr_save_load.gml` | `scr_save_game()` / `scr_load_game()` using JSON + `cc_save.json` |

### New Objects
| Object | Events | Notes |
|--------|--------|-------|
| `obj_player` | Create, Step, Draw | WASD movement, lerp camera, F5 save, procedural pixel character |
| `obj_hud` | Create, Draw | Day/night tint overlay, clock, day number, phase label |

### Modified Objects
| Object | Change |
|--------|--------|
| `obj_game_controller` | Added `creature_roster = []`; auto-save on day advance; `persistent:true` |
| `obj_char_create_ui` | Room transition: `rm_creature_select` → `rm_biome_select` |
| `obj_biome_select_ui` | Saves `biome_id` to game controller; goes to `rm_creature_select` |
| `obj_creature_select_ui` | Full init on confirm: sets roster, biome bonus, stamina, time; goes to `rm_ranch` |

### New Room
| File | Details |
|------|---------|
| `rooms/rm_ranch/rm_ranch.yy` | 3200×2400, views enabled, 1366×768 viewport, obj_player at (1600,1200), obj_hud at (0,0) |

### New Sprites (21 total)
All in `sprites/spr_*/spr_*.yy` — single-frame sprites linked to asset pack images.

---

## .yy Format Reference (GMS2 2024.14)

### Working room format (`Room1.yy` — confirmed working)
```json
{
  "$GMRoom":"v1",
  "%Name":"Room1",
  ...
  "resourceType":"GMRoom",
  "resourceVersion":"2.0",
}
```

### Object format — CURRENTLY BROKEN
All 7 object `.yy` files are broken. The correct `$GMObject` version value is **unknown**.

**Errors encountered:**
- `"$GMObject":"v1"` → `(3,3): Record version 1 is different than that of this release: 0`
- `"$GMObject":"v0"` → `(2,5): Failed to parse tag-and-version field`

**Current state of broken files** (using `"v0"` which fails to parse):
- `objects/obj_biome_select_ui/obj_biome_select_ui.yy`
- `objects/obj_char_create_ui/obj_char_create_ui.yy`
- `objects/obj_creature_select_ui/obj_creature_select_ui.yy`
- `objects/obj_game_controller/obj_game_controller.yy`
- `objects/obj_hud/obj_hud.yy`
- `objects/obj_player/obj_player.yy`
- `objects/obj_title_ui/obj_title_ui.yy`

### Fix needed
Create a new blank object in GMS2 IDE → save project → read its `.yy` file to get the exact format this IDE version generates → rewrite all 7 broken files to match.

---

## Object .yy Structure (minus the broken `$GMObject` line)

All 7 files follow this structure (confirmed correct except for line 2):

```json
{
  "$GMObject":"???",          ← THIS LINE IS THE PROBLEM
  "%Name":"obj_example",
  "eventList":[
    {"collisionObjectId":null,"eventNum":0,"eventType":0,"isDnD":false,"resourceType":"GMEvent","resourceVersion":"2.0",},
    {"collisionObjectId":null,"eventNum":0,"eventType":3,"isDnD":false,"resourceType":"GMEvent","resourceVersion":"2.0",},
    {"collisionObjectId":null,"eventNum":0,"eventType":8,"isDnD":false,"resourceType":"GMEvent","resourceVersion":"2.0",},
  ],
  "managed":true,
  "name":"obj_example",
  "overriddenProperties":[],
  "parent":{
    "name":"CreatureCaretaker",
    "path":"CreatureCaretaker.yyp",
  },
  "parentObjectId":null,
  "persistent":false,
  "physicsAngularDamping":0.1,
  "physicsDensity":0.5,
  "physicsFriction":0.2,
  "physicsGroup":1,
  "physicsKinematic":false,
  "physicsLinearDamping":0.1,
  "physicsObject":false,
  "physicsRestitution":0.1,
  "physicsSensor":false,
  "physicsShape":1,
  "physicsShapePoints":[],
  "physicsStartAwake":true,
  "properties":[],
  "resourceType":"GMObject",
  "resourceVersion":"2.0",
  "solid":false,
  "spriteId":null,
  "spriteMaskId":null,
  "tags":[],
  "visible":false,
}
```

**Per-object overrides:**

| Object | `visible` | `persistent` | Events |
|--------|-----------|-------------|--------|
| `obj_title_ui` | false | false | Create(0), Step(3), Draw(8) |
| `obj_char_create_ui` | false | false | Create(0), Step(3), Draw(8) |
| `obj_biome_select_ui` | false | false | Create(0), Step(3), Draw(8) |
| `obj_creature_select_ui` | false | false | Create(0), Step(3), Draw(8) |
| `obj_game_controller` | false | **true** | Create(0), Step(3) |
| `obj_player` | **true** | false | Create(0), Step(3), Draw(8) |
| `obj_hud` | false | false | Create(0), Draw(8) |

---

## GML Event File Naming
| eventType | eventNum | Filename |
|-----------|----------|----------|
| 0 | 0 | `Create_0.gml` |
| 3 | 0 | `Step_0.gml` |
| 8 | 0 | `Draw_0.gml` |

---

## Sprite .yy Fixes Applied
- `"$GMSpriteImage":"v1"` → `"$GMSpriteImage":"v0"` (2 occurrences per file, all 21 sprites)
- `"$GMImageLayer":"v1"` → `"$GMImageLayer":"v0"` (all 21 sprites)

---

## Global Variables (set in `obj_game_controller/Create_0.gml`)
```gml
player_name, skin_tone, hair_color, hair_style  // character creation
biome_id, starter_creature                       // selections
creature_stamina, creature_stamina_max           // current creature state
creature_roster = []                             // array of owned creatures
biome_bonus_state                                // from scr_biome_bonus_init()
```

## Global Time Variables (set by `scr_time_init()`)
```gml
global.day_number
global.minutes_in_day
global.time_phase     // MORNING / MIDDAY / EVENING / NIGHT
global.day_just_advanced
```

---

## Save File
- **Path**: `cc_save.json` (working directory)
- **Format**: JSON via `json_stringify` / `json_parse`
- **Trigger**: F5 manual save, auto-save on day advance

---

## Pending / Next Steps
1. **Immediate**: Get correct `$GMObject` version string from GMS2 IDE by creating a test object and reading its `.yy` file
2. Rewrite all 7 broken object `.yy` files with correct format
3. Test full game flow: title → char create → biome select → creature select → ranch
