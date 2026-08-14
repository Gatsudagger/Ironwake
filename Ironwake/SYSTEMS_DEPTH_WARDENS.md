# SYSTEMS — DEPTH WARDENS (08-13; committed db577e6, Bottom treatment ada611d+)

Wardens replace the recycled theme boss on **every 5th Descent floor**. Past 50
the catalog cycles (`warden_for_floor`: slot = floor/5, index = (slot−1) mod 10),
so the ladder never runs out. Catalog + hooks live in scr_enemies (~1063);
per-Warden mechanics hook in obj_combat_controller Create (~670) and combat
resolution sites tagged `warden_hook`.

| Floor | Warden | Scion | Hook |
|---|---|---|---|
| 5  | The First Door | doorling | opens with a shield equal to floors cleared |
| 10 | Sister Fathom | fathom_squid | heals for any damage you deal above 30 in one hit |
| 15 | The Tally | tallykeep | gains a permanent stack each time you use the same ability twice |
| 20 | Hollowlight | lantern_wyrm | your healing is INVERTED for the first 2 turns |
| 25 | The Weight of Ironwake | deepclaw | three phases; guaranteed Depthforged legendary |
| 30 | The Long Arithmetic | sum_moth | damage you deal is capped at your current HP |
| 35 | Nothing In Particular | null_hound | untargetable every other turn |
| 40 | The Understudy | mimicling | copies your equipped weapon's affixes |
| 45 | The Hollow Crown | griefwisp | silences one random ability each turn |
| 50 | **The Bottom** | — | the intended end of the ladder (see below) |

## Scion drops
Flat **4%** (`warden_scion_drop_chance`), **once per save per species**
(`global.pet_sig_history`, the 07-31 signature rule). Wardens recur forever on
the cadence, so the chase stays open until the scion is caught. Granted via
`pet_grant_from_source("egg_boss", id)` — "Visit Bairc."

## The Bottom (floor 50) — full treatment as of 08-14
- `global.descent_bottom_cleared` set on the kill — **persisted** (save/load/
  new-char init in scr_save).
- Unlocks the epithet **"the Bottom's Witness"** (epithet_catalog id
  `bottomed`).
- Center-screen splash "THE BOTTOM YIELDS" (bottom_splash_timer 300f, combat
  Draw, above the scene / below pause+settings).
- All Wardens use A5 elite pools for their summons in boss fights.

## Open art debt
All 10 Warden models are STAND-INS (veto pending). Init trick when the runs
happen: img2img from the stand-in at strength 45–70.
