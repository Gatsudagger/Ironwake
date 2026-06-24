# SYSTEMS — Floor & Event Variety (§6)

Built 2026-06-23 (verify in-IDE). Fixes MISC_TASKS §6 "More random generation of room
layouts and events — dungeon floors are very similar / often identical."

## Root cause (the big one)
`global.run_seed` was set **once per session** (`obj_floor_controller/Create_0`, guarded by
`if (!variable_global_exists("run_seed"))`) and **never re-rolled** — so the template pick
`(run_seed + floor) mod 5` and the seeded type/name RNG produced the **identical floors every
run**. Re-seeding alone is most of the perceived fix.

## Changes

### 1. Re-seed per run (`scr_stats.gml` → `end_run`)
Added `global.run_seed = irandom(99999)+1`, `global.floor_map_floor = -1` (force regen), and
`global.events_seen_this_run = []` to the per-run reset block. `end_run` is the single funnel
for all exit paths (victory `1` / extract `0` / defeat `-1`), so every new run now gets fresh
floors + a fresh event pool.

### 2. Procedural floor layouts (`obj_floor_controller/Create_0`)
Replaced the 5 hand-coded DAG templates with a **seeded layered-DAG generator** (seed
`run_seed*101 + floor*17 + 3`). It outputs the same four arrays the rest of Create_0 consumes
(`_node_count` / `_children` / `_layers` / `_slots`), so **all downstream position/parent/map
code is untouched.**
- **5-6 layers**; entry + boss layers = 1 node; intermediate layers = **1-3 nodes** (weighted
  toward 2). 5-6 layers (not 4) guarantees enough rooms that the "≥2 combat/elite" safety net
  never eats the whole floor.
- **Edges:** each node fans out to 1-2 random nodes in the next layer; a reachability pass gives
  any parentless next-layer node a random parent. **Guarantees a valid DAG** — every node is
  reachable from the entry AND has a path to the boss (no dead ends, no orphans).
- Respects the existing draw geometry (≤3 nodes/layer, ≤6 columns). `Draw_64`/`Step_0` already
  read `px/py/children/layer` generically, so they handle any generated shape.

### 3. Event variety (`scr_stats.gml`)
- **Catalog 7 → 13.** New events (all data-only, no per-event code): Arcane Locus (INT→rune),
  Collapsed Shrine (STR hard-gate + DEX), Vagrant Oracle (CHA), Runed Anvil (STR/INT→runes),
  Starving Hound, Whispering Mirror (WIS→boon). These add the previously-unused **INT/CHA**
  checks, **`req_stat` hard-gates**, and **rune** rewards for fresh decision texture.
- **No-repeat guard** in `event_roll()`: excludes events already shown this run
  (`global.events_seen_this_run`) until the catalog is exhausted, then resets. Reset per run in
  `end_run`.

### 4. Type-mix polish (`obj_floor_controller/Create_0`)
After the base per-floor type pool is chosen, inject **0-2 random floor-appropriate bonus rooms**
(event / treasure variants / shrine / elite) before the shuffle, so the *composition* of
decision/loot rooms shifts run-to-run, not just the order. The "≥2 combat/elite" net keeps every
floor fight-bearing.

## Verify in IDE
- [ ] Project compiles.
- [ ] Two consecutive runs (same session) now have **visibly different floor shapes** (was identical).
- [ ] Floor maps vary in layer count (5-6) and per-layer width; no unreachable/dead-end nodes; the
      auto-selected frontier room is always enterable.
- [ ] Boss is always the rightmost single node; entry always the leftmost.
- [ ] Event rooms show a wider rotation incl. the 6 new ones; the same event doesn't repeat within
      a run until others have been seen.
- [ ] New events resolve correctly (INT/CHA/STR checks, STR-8 hard gate locks when under, rune
      rewards land in the rune inventory).

## Out of scope (still open in §6)
- "Higher risk / higher reward at higher Awakenings" (worse+stronger trap rooms, more intense
  events at high tiers) — separate backlog item, not touched here.
