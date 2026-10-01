# Bairc's Hut - interior (09-22, M: "add features and interior to Bairc's garden")

M's scope (09-22): **Both** decorate-and-live AND a functional nursery/keepsake room. Features locked:
indoor ornament placement, pets come inside, keepsake shelf, and Bairc's creature screen reachable
from the garden (outside AND inside - "right now he does nothing"). Art route: PixelLab plate via
the garden recipe, one test plate shown to M before anything else.

## Rooms
The garden scene gains a `garden_room` ("grounds" | "hut") on obj_game_controller. Everything the
scene already does (free 2-axis walk, y-sort, proximity chip, tap-to-walk, ornament placement,
residents) runs in both rooms; the room only swaps the plate, the walk band/blockers, the
interactable list and which residents are present.

- **Enter**: the hut door is a new interactable on the grounds (`garden:door`, at the hut's sill
  x 1394 y 950, reach 120) - "Go inside". Tapping the hut walks you there and enters.
- **Inside**: plate `spr_hut_plate` (1920x640 @ x4, drawn at GARDEN_PLATE_Y like the grounds plate;
  no code sky, no canopy, no pond/koi/cairn/forage/memorial). Walk band y 730..1040, x 220..1700.
  Blockers authored after the plate lands (hearth, desk, shelf, table).
- **Leave**: `garden:out` chip / Esc / walking off the bottom edge near the door -> back on the
  grounds at the sill, facing south. Esc inside the hut goes OUT, not to the station (two Escs to
  leave the garden entirely - same as backing out of the shop).

## Inside the hut (interactables)
| tag | where | does |
|---|---|---|
| `garden:desk` | Bairc at his ledger desk | opens the creature station (`garden_open = false`, `bairc_open` stays true) with his garden line as the station notification |
| `garden:shelf` | keepsake shelf on the back wall | opens the KEEPSAKES panel (below) |
| `garden:hearth` | the fire | "Stoke the fire" - a warm FX + residents inside drift to nap by it (flavour, no economy) |
| `garden:out` | the door mat | leave |
| `garden:orn<i>` | placed indoor ornaments | take-up, same two-press rule |
| `garden:pet<i>` | residents inside | pet them, same as outside |

Outside, Bairc's own interactable (`garden:bairc`) now ALSO opens the creature station (M: he did
nothing but talk). His line shows as the station notification instead of a garden toast.

## Indoor ornaments (8, 1 gen each, `garden_decor_catalog` entries with `room:"hut"`)
| id | name | gold/dust | footprint |
|---|---|---|---|
| rug | Wolf-pelt Rug | 90 / 5 | flat (r 0) |
| shelf2 | Ledger Shelf | 160 / 15 | 26 |
| herbs | Hanging Herbs | 70 / 5 | 20 |
| cot | Straw Cot | 140 / 10 | 34 |
| kettle | Iron Kettle | 80 / 5 | 22 |
| crate | Feed Crates | 100 / 10 | 30 |
| candles | Candle Cluster | 60 / 5 | 18 |
| perch | Roost Perch | 120 / 10 | 24 |

Placed entries carry `room` ("grounds" default on migration). The shop lists only the current
room's catalog; the GROUNDS (seasons) tab is outside-only. Placement rules unchanged (walkable,
70px apart, not on Bairc).

## Pets come inside
On entering, every resident within 300px of the player follows (`room = "hut"`), spawning just
inside the door; residents with `seed < 0.3` are homebodies and are always inside. Inside, the
nap spot is the hearth instead of the lantern. Residents keep their room until the player next
enters the grounds from the station (fresh visit re-seeds as today).

## Keepsake shelf (zero new counters - all read from existing state)
| id | name | earned when |
|---|---|---|
| first_egg | The First Shell | any species hatched (`ach_counters.species_hatched` > 0) |
| full_cairn | Five Stones | `garden_cairn` >= 5 |
| awakened | A Waking | any `species_stage_max` >= PET_STAGE_AWAKENED |
| ten_kinds | Ten Kinds | 10+ species hatched |
| board25 | Twenty-five Jobs | `ach_counters.board_done` >= 25 |
| remembered | The Quiet Corner | `bairc_memorials()` > 0 |
| his_word | His Word | Bairc bond >= Companion |
| deep_runs | Twenty-five Dives | `run_count` >= 25 |

Each keepsake is a small object sprite (`spr_keep_<id>`, 1 gen each, ~24-32px native @ x4) that
sits on the painted shelf once earned (dark silhouette slot while not). The panel (`garden:shelf`)
lists all eight with name, blurb and earned/not - scrollable per the info-dense rule.

## Art ledger (09-22)
Plan shown to M with the scoping question (plate 4-6 rolls + 8-10 ornaments ~15-20 gens, YES).
Actual: see `_for_review/hut_0922/JOBS.json`. Tool: `tools/gen_hut_interior_0922.py`
(submit / poll / import, GM CLOSED for import). Test plate FIRST; M sees it before any ornament.

## Seam fix (09-22, same session, grounds)
The canopy strip is one solid crown mass (30,32,42) whose steep bottom fade landed exactly on the
plate's top edge (y 440) - both edges fused into a hard band. Fix in `ui_draw_garden_scene`:
canopy base 80 -> 120 px into the plate (fade straddles the trunk tops) and the mass is merged
45% toward the theme's sky colour (30% for themed strips). Themed sky overlay is now a fade, not a
flat rect. Composite sheet: scratch `seam_variants.png` variant B.

## Decor economy rework (09-22 late, M-locked)
- **Stores, not refunds.** Taking an ornament up (one press now - nothing is destroyed) moves it to
  `global.garden_decor.stored` (array of ids). Esc during placement stores it too. Placing from the
  stores is free. Stores are only reachable in the garden and hut: shop window, STORED tab.
- **Peddler's cart** (`spr_garden_cart`, grounds, GARDEN_CART_X/Y 560/792, blocker r52) = the
  rotating stock: `garden_shop_stock()` picks 5 of the 16-item catalog seeded by run_count, mixed
  rooms. Charged at BUY (`garden_decor_buy`). Bought for this room -> placement; for the other
  room -> stores with a note. [B] DECOR chip opens the same window anywhere in the scene.
- **Tabs**: STOCK | STORED (n) | GROUNDS (outside only). Every row draws the real sprite.
- Petra tab / merchant NPC: considered, declined (placement happens in the scene; the cart costs
  one object gen instead of an 8-dir NPC).
