# Bairc's Garden — walkable diorama (DESIGN LOCK 09-17)

M's brief (09-17): "build out Bairc's garden properly ... right now it's all [code-drawn primitives]
... make it magnificent and cool." Scoped via AskUserQuestion, M picked:

| Decision | Locked |
|---|---|
| Spatial model | **3/4 painted diorama, free 2-axis walking** (not a strip, not a tile grid) |
| Player avatar | **Class skin puppet-walk** — existing 108px 8-direction skin sprite, facing from velocity, bob + lean while moving. Zero new art. |
| Pet movement | **Idle-hop now** — existing `_s` / mirrored `_e` frames with a hop while moving. Walk cycles = separate approved batch later. |
| Plate art | PixelLab `create_map_object` 400x224 native, x4 NEAREST (the shipped hub-camp / combat-bg density). 3 panels W / C / E. Centre approved 09-17. Sky, moon, stars stay code-drawn above the painted ground band (nothing stretched). |
| Walk mask | AUTHORED in GML (`garden_walkable`), never generated. |

Comparator lessons (Chao Garden / Pokémon Camp / Slime Rancher sanctuary): creatures must be
*doing something on their own*, the player must be *in the space*, and care must leave a
*visible trace*. The old garden only had the third.

## Layout (world px, 1080p GUI space)
- World = the three panels side by side; `garden_plate_layout()` returns `[{spr, x, y, w, h}]`
  (positions set at import from each panel's cropped content size). Camera scrolls X only,
  follows the player, clamped to the plate. World y == screen y.
- Ground band = the painted grass; walkable rect per panel + blockers (pond ellipse, hut,
  lantern, back wall, headstones). `garden_walkable(x, y)`; movement resolves X then Y so the
  player slides along blockers.
- Depth: everything on the ground is Y-sorted each frame (player, residents, Bairc, ornaments,
  cairn, sparkles, FX) — lower on screen draws in front. Scale 0.86 → 1.0 from band top to
  bottom (2.5D plane idiom), times `pet_stage_size_mult`.
- Fallback: if a plate sprite is not imported yet (`asset_get_index` < 0) the band draws as
  the old flat earth colours so the scene never breaks a build.

## Input (parity rule)
- Walk: WASD / arrows / left stick / d-pad. **Tap-to-walk**: tap or click the ground = path
  there; tap an interactable = walk to it and act on arrival (`garden_goal`). Drag does NOT pan
  any more (the player is the camera).
- Act: [E] / Enter / pad A / the single proximity chip acts on the nearest interactable within
  reach. Interactables: resident (pet), pond (crumb), cairn (stone), forage sparkle, Bairc
  (line), memorial (names), gate (leave). [B] ornaments, [M] music, Esc leave — chips as before.
- Ornament placement keeps the numbered glowing plots (tap / number key).

## Residents (steering, `garden_pets_tick`)
Per resident struct `{ i, x, y, tx, ty, state, t, vx, vy, hop }` seeded from index so the
layout is stable across visits. States: **dwell** (2–6 s), **wander** (target inside its home
third of the plate, walkable), **approach** (player within 260 px and not busy → drift to ~90 px
and face them), **bank** (a fresh crumb pulls anyone within 800 px to the pond edge), **nap**
(near the lantern, eyes-closed = slower bob, 8–14 s). Separation push between residents.
Face: `_s` when still or moving mostly vertically; `_e` mirrored by `sign(vx)` when moving
horizontally. Hop = |sin| * 6 px while moving.

## Kept from the 08-15 garden
Ornament catalog + 8 plots (re-anchored), cairn 5-stone, 3 forage spots/run, crumb, petting
lines, blessing, memorials, music chip, ornament shop overlay, coach-mark (copy updated).
Removed: WORK-IN-PROGRESS banner, drag-pan, "+N more live deeper" cap (all residents placed).

## Art ledger
09-17: centre panel 1 gen (approved). W/E first roll 2 gens — MISSED (enclosed courtyards,
palette drift), archived as `_for_review/garden_0917/_miss1_*`. W/E re-roll 2 gens with a
"continuous field, wall only across the top" prompt — MISSED again (`_miss2_*`). **Two strikes
= STOP.** Shipped as the SINGLE centre panel, cropped to its painted content (316x160 native)
and edge-tiled with a clean grass/wall strip to 480x160 (1920x640 @ x4): `spr_garden_plate`.
Total 5 gens. World = one screen, camera fixed. Tool: `tools/gen_garden_plate_0917.py`
(`import` with GM CLOSED builds the sprite + force-include). Flank panels can be revisited
later with a different method (inpaint-extend from the centre's edge) if M wants a wider plot.

## Phase 2 (M-locked 09-17 late): canopy layer, real ornaments, free placement, SEASONS
M: "the trees have no tops ... another layer separate as the tree tops that transitions into the
sky ... parallax ... replace the ornaments ... with actual visually designed assets ... many
customization options, additional garden unlocks like entirely different garden themes for seasons."

**Canopy layer.** `spr_garden_canopy` = transparent branch-crown strip (400x112 native, x4),
tiled across the width, drawn OVER the plate's top edge at y ≈ GARDEN_PLATE_Y - 60 with parallax
x offset = -(garden_px - 960) * 0.06. Its own top edge is where it thins to nothing, so the code
sky fade goes away. One strip per season (bare / autumn / snow-laden / blossom) = the cheapest
way to make a season read at a glance.

**Real ornaments.** One transparent map-object per ornament at plate density (32-72 native),
size-anchored on the plate's own stone lantern (~24 native tall). Code keeps the LIVE touches
(ember pulse, eye blink, chime sway, wheel spin, firefly motes) drawn over the sprite.
`ui_garden_draw_ornament` falls back to the vignette if the sprite is absent.

**Free placement + multiples.** `global.garden_decor` becomes an ARRAY of `{id, x, y}`; the 8
plots retire. Placing = pick the ornament in the shop -> a ghost follows the cursor / finger over
the grass -> tap/Enter on a walkable spot (>= 70px from any other ornament, off the pond/hut)
-> charged. Placed ornaments are small circular blockers (r 26). Own several of one kind.
A REMOVE mode refunds 50% dust. Save: lazy migration from the old `a<i>` struct.

**Seasons (layered on ONE plate, same walk mask).** A theme = {tint on the plate, sky palette,
canopy strip, particle weather, ambient SFX bed}. Roster v1:
| id | name | unlock | look |
|---|---|---|---|
| `night`  | Still Night (default) | free | current |
| `autumn` | Ember Fall  | 400g + 40 dust, 10 runs | amber tint, red-brown canopy, drifting leaves |
| `winter` | Hollow Frost | 500g + 60 dust, 20 runs | blue-white tint, snow-laden canopy, slow snow, frozen pond glint |
| `spring` | Pale Bloom   | 500g + 60 dust, 30 runs | soft green tint, pale-pink blossom canopy, petals |
| `bloodmoon` | Blood Moon | 800g + 100 dust, 1 Awakened resident | crimson sky + red moon, black canopy, ash motes |
Bought in a new **GROUNDS** tab of Bairc's ornament shop; the active theme is a per-save
selection (jukebox idiom). Art cost = 1 canopy strip per theme (4 gens) + 0 plate gens.
Tints are `draw_sprite_ext` colour blends, particles are code (the ember/firefly idiom).

### Phase 2 art ledger (09-17 late, 15 gens)
Canopy bare: 1 gen, landed OPAQUE on a grey-green key -> keyed + recoloured (30,32,42) + bottom
fade by scratch `canopy_build.py` -> `spr_garden_canopy` (APPROVED). Ornaments: 8 gens + 1 wheel
re-roll (first was a hutch) = all 8 landed; the 40x56 lantern kept as-is at M's call ("Tall
Lantern" size). Seasonal canopies: 4 gens -> autumn LANDED (`spr_garden_canopy_autumn`), winter
(speckled field), spring (teal blobs), bloodmoon (opaque scene with baked moon) MISSED -> STOP;
those three themes tint the bare strip in code (`canopy_tint`). Misses archived `_miss1_*`.
Session total: 20 gens.

## Layout as built (screen px, single plate)
Plate at y 440 (its own treeline+stars band 440..590, wall to ~715). Walkable band y 730..1072,
x 40..1880. Blockers: pond ellipse (770,965 r 252x114), hut rect 1236..1552 x 600..942, lantern
(1190,978 r30), cairn (1720,985 r44), quiet corner rect. Bairc idles at (1440,988). Spawn
(300,1000) facing east. Skin frame order measured on spr_skin_ashen: 0 S, 1 SE, 2 NE, 3 SW,
4 E, 5 N, 6 NW, 7 W (`garden_skin_frame` — fix there if F5 shows a wrong facing).
