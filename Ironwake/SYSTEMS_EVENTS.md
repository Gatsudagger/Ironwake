# SYSTEMS — Event Rooms

**Status: BUILT 2026-06-22 (verify in-IDE) — NOT compile-tested.**
Implemented exactly as locked below. Engine + 7-event catalog live in `scr_stats.gml`
(`event_catalog`/`event_roll`/`event_resolve_choice`/`event_apply_effects`/
`event_choice_unlocked`/`event_choice_cost`/`event_first_unlocked`/`event_check_chance`/
`player_effective_stat`). Overlay in `obj_floor_controller` (Create vars, Step §2c input
handler, Draw §6c render). Old `trap` room removed from pools/handlers; `ui_room_icon_sprite`
"trap" case repointed to "event".
A new `"event"` room type that replaces fight-and-loot popups with **interactive,
stat-aware choices** (risk/reward gambles). Built to fix "non-combat rooms all feel
the same": today only the Shrine asks the player to decide anything. Events add a
second decision-room family and **fold the old passive `trap` room in** as one event.

**M's design decisions (2026-06-22):**
1. **Trap is folded into events** — the standalone passive `trap` room is removed; its
   fantasy returns as the "Trapped Corridor" event (disarm / force / retreat).
2. **Stat-gated choices: YES** — choices can gate on or scale odds by STR/DEX/INT/WIS/CHA.
   First time character stats matter *outside combat* (only CHA did, for prices).
3. **Outcomes can grant a rare boon** — events award gold/HP/items/consumables/dust, with
   an occasional low-weight **boon** jackpot (ties into the existing boon system).
4. **Treasure variants stay passive** — the 4 treasure rooms remain guaranteed-reward
   pacing beats, a deliberate contrast to decision rooms. Out of scope this pass.

---

## 1. Data model (lives in scr_stats — sibling to boons; NO new script resource)
An event is a struct; the catalog is a function returning an array. A choice resolves to
exactly one **outcome**, by one of two methods:

```gml
event = {
  id, title, body, color,           // color = node + overlay accent
  choices: [ choice, ... ]          // 2-3 choices
}

choice = {
  label,                            // button text, e.g. "Disarm the mechanism"
  hint,                             // one-line sub-text (cost/odds/flavor)
  cost_gold,        // optional, default 0 — gold paid to pick (gated if unaffordable)
  req_stat,         // optional "" — hard gate: choice locked unless stat >= req_amount
  req_amount,       // optional 0
  resolve,          // "weighted" | "check"
  // resolve == "weighted":
  outcomes: [ { weight, text, effects }, ... ],
  // resolve == "check":
  check_stat, check_base, check_per, check_ref,   // success% math (see §2)
  success: { text, effects },
  fail:    { text, effects }
}

effects = {            // every field optional; omitted = 0/none
  gold,                // +add_gold / -max(0,gold-n)
  hp,                  // + -> pending_rest_heal ; - -> pending_trap_damage (deferred, see §3)
  item,                // drop-source string ("chest"/"vault"/"reliquary"/"standard"/"boss")
  consumable,          // pool string "standard" | "elite"
  dust,                // + rune_dust
  rune,                // tier int 1|2 -> rune_random(tier)
  boon                 // "random" (unowned) or a specific boon id
}
```

## 2. Resolution math (helpers in scr_stats)
- `player_effective_stat(name)` — `global.chosen_stats[name]` + `run_stat_bonuses[name]`
  (+ `perm_cha_bonus` for CHA). Generalizes the existing `player_effective_cha()`.
- **Hard gate:** a choice with `req_stat` is shown but **locked** (greyed, unpickable)
  unless `player_effective_stat(req_stat) >= req_amount`. Same treatment for `cost_gold`
  the player can't afford. (Mirrors the shrine's affordability gating.)
- **Stat check** (`resolve:"check"`): success% =
  `clamp(check_base + (player_effective_stat(check_stat) - check_ref) * check_per, 10, 90)`.
  Roll `irandom(99) < pct` → `success`, else `fail`. The overlay shows the live % so the
  gamble is informed. Example (Disarm, DEX): base 55, ref 5, per 6 →
  DEX 5 = 55%, DEX 8 = 73%, DEX 10 = 85%, DEX 2 = 37% (floored at 10).
- **Weighted** (`resolve:"weighted"`): pick by integer weight (same pattern as drop tables).
- `event_apply_effects(fx, fl)` applies an effects struct; `fl = clamp(current_floor-1,0,2)`
  scales magnitudes (numbers in §4 are written as `[f1/f2/f3]`).

## 3. HP / deferred-damage model (reuses existing plumbing — no new HP state)
There is no persistent overworld HP bar; damage/heal is **deferred to the next combat**.
- HP loss → `global.pending_trap_damage += n` (applied on next combat enter — established).
- HP gain → `global.pending_rest_heal += n` (the rest-room hook).
- Items → `drop_equipment(drop_weights(src, asc))`, push to `global.carried_items`
  (auto-discovers via base_name). `asc = global.selected_ascendance`.
- Consumables → `roll_consumable(global.consumables_<pool>)`, push `consumable_inventory`.
- Dust → `global.rune_dust`. Runes → `rune_random(tier)` → `rune_inventory`.
- Boon → `boon_grant("random"→boon_offer_roll()[0] | id)`. No-op if none unowned.

## 4. Starter catalog (v1 = 7 events)
Magnitudes scale by floor `[f1 / f2 / f3]`. All numbers first-pass/tunable.

1. **Trapped Corridor** (color: violet) — *the reframed trap.*
   - **Disarm the mechanism** — `check` DEX, base 55/ref 5/per 6.
     success: gold `[25/40/65]` + 60% consumable("standard"); fail: hp `-[14/18/24]`.
   - **Force through** — `weighted` 100%: hp `-[8/11/15]` + item("chest"). (guaranteed loot, guaranteed bruise)
   - **Retreat** — `weighted` 100%: nothing. (safe exit)

2. **Mysterious Font** (teal)
   - **Drink deeply** — `check` CON, base 50/ref 5/per 7.
     success: hp `+[20/26/34]`; fail: hp `-[12/16/22]` ("the water is fouled").
   - **Fill a vial** — `weighted` 100%: consumable("standard").
   - **Leave it** — nothing.

3. **Wounded Wanderer** (green)
   - **Tend their wounds** — cost_gold 0, `weighted`: 70% → boon "random" *(rare jackpot — they
     repay you)* ... actually split: 70% gold `[30/50/80]` + dust `[3/4/6]`, 30% **boon "random"**. Costs hp `-[10/12/16]` regardless (write as a flat pre-effect in both outcomes).
   - **Rob them** — `weighted` 100%: gold `[45/70/110]`. (no HP cost, no jackpot — the "evil" gold play)
   - **Walk on** — nothing.

4. **Gambler's Cache** (gold)
   - **Pay to open** — cost_gold `[40/60/90]`, `weighted`: 55% item("vault"), 30% item("chest"),
     12% item("reliquary"), 3% **boon "random"**. (gold sink → loot gamble)
   - **Pry it open** — `check` STR, base 45/ref 6/per 6. success: item("chest");
     fail: hp `-[12/16/22]` ("the lid snaps shut on your hand").
   - **Leave it** — nothing.

5. **Cursed Idol** (crimson)
   - **Take the offering** — `weighted`: 65% gold `[50/80/120]` + item("chest"),
     35% hp `-[16/22/30]` ("the idol's eyes flare"). (greed gamble)
   - **Pray before it** — `check` WIS, base 50/ref 5/per 7. success: dust `[5/7/10]` +
     30% **boon "random"**; fail: nothing ("the idol is silent").
   - **Leave it** — nothing.

6. **Merchant's Ghost** (blue)
   - **Haggle & buy** — cost_gold `[35/55/85]` (further reduced by `cha_price`), `weighted` 100%:
     item("vault"). CHA already discounts via `cha_price` on the cost. (reliable but priced)
   - **Intimidate** — `check` STR, base 40/ref 6/per 6. success: item("vault") free;
     fail: nothing + hp `-[6/8/10]` ("the ghost lashes out").
   - **Decline** — nothing.

7. **Forked Omen** (indigo)
   - **Take the gold** — `weighted` 100%: gold `[60/90/140]`.
   - **Take the blessing** — `weighted`: 80% dust `[4/6/9]` + consumable("elite"),
     20% **boon "random"**.
   - **Heed the warning** — `weighted` 100%: hp `+[18/24/30]`. (pre-heal before the next fight)

Catalog grows by appending structs — no per-event code. `event_roll()` picks a random
event id (room can store the chosen id, or roll on entry; roll-on-entry is simpler and
fine since events aren't seed-critical).

## 5. Overlay + input (model on the existing Shrine overlay)
New `obj_floor_controller` instance vars: `showing_event_choice`, `event_active` (the
rolled event struct), `event_cursor`, `event_phase` ("choose" | "result"),
`event_result_text`.
- **Step_0:** when `_room.type == "event"` is entered → roll event, set
  `showing_event_choice = true`, phase "choose". While showing: W/S or ↑/↓ move cursor
  (skip locked choices), Enter/Space confirm → resolve (gate check → roll outcome →
  `event_apply_effects` → set `event_result_text`, phase "result"); in "result" phase a
  keypress closes the overlay and marks the room cleared (same completion path as shrine/
  treasure). Input is **blocked from map nav while the overlay is open** (guard like
  `showing_shrine`).
- **Draw_64:** dim backdrop, title (accent color), body, choice list with cursor
  highlight; each choice shows label + hint + (live success% for checks) + LOCKED tag
  when gated; result phase shows `event_result_text` + "press any key". Reuse the shrine
  overlay's panel styling for consistency.

## 6. Floor integration (obj_floor_controller/Create_0)
- **Remove `"trap"`** from all three `_type_pools` and add **`"event"`** (1 on floor 1,
  1 on floor 2, 2 on floor 3 — roughly where traps were, so floor density is unchanged).
- Add `"event"` to the `switch (_t)` name-pool block and a `_nm_event` name pool
  (e.g. "Strange Alcove", "Whispering Hollow", "Forked Path", "Ill Omen", "Crossroads").
- Add `case "event": _enemies = "none"; break;` in the type→enemies switch (no pre-rolled
  gold; events handle their own rewards).
- **Delete** the old `_nm_trap` pool + the `trap` cases (folded in).
- **Draw_64:** give `"event"` a node color/label; **delete** the `trap` node styling.

## 7. Out of scope / future
- **Curses** (§3 roadmap): the `effects.boon` slot is the hook — a future `effects.curse`
  field plugs the devil's-bargain system into events with no structural change.
- Per-item "pick 1 of 2" treasure agency (M declined for this pass).
- Seeded event selection (currently roll-on-entry; fine for v1).
- Hand-written art per event (text-only overlay for v1).
