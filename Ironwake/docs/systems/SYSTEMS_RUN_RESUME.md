# IRONMAN Run-Resume Checkpoint

M-locked 2026-07-18 (base) + 2026-07-28 (revisions). Built 2026-07-28.

## What it is
A per-slot checkpoint file (`ironwake_resume_<slot>.json`) that lets an
*interrupted* run continue instead of being lost — Android kills backgrounded
apps, crashes happen, and multi-floor runs are too long to lose to faulty
software. It can NEVER rewind a death and can never be declined for profit.

## IRONMAN rules (anti-save-scum, M's hard requirement)
1. **Consumed on load.** The file is deleted the moment its data is applied.
2. **No abandon.** Loading a slot with a live checkpoint FORCE-resumes into the
   dungeon (hub is modal-locked behind a single RESUME button). M 07-28: an
   "abandon = retreat" option would grant a mid-floor extract that the game
   never offers — quit-out in a bad spot would bank loot that should be at risk.
   The only exits from a run remain the real ones: die, or extract at a boss.
3. **Death is settled the frame it happens.** At `combat_result = -1` the
   checkpoint is deleted, `end_run(-1)` runs (mercy/clawback), and
   `save_game()` commits it — all BEFORE the defeat screen. Killing the app on
   the death screen changes nothing (the Draw handler skips its own
   `end_run(-1)` via `defeat_settled`).
4. **Mid-combat quits don't heal.** The checkpoint mirrors the player's LIVE
   HP/resources every turn (throttled watcher). Resume re-fights the room at
   the HP you had; enemies reset to full. Rage-quitting a fight is a net loss.
5. **Corrupt/stale checkpoint = forfeit,** never an escape: file deleted, hub
   notice shown. (Stale = player_name/run_count mismatch after a New Game
   reused the slot; also deleted outright when a New Game claims a slot.)

6. **Deterministic rewards (M 07-28: no loot re-rolls).** Every combat kill's
   reward block (gold, drops, runes, Devil's Pact bonus) and the boss
   egg/trinket rolls run on a seeded stream — `loot_room_seed(slot, salt)` =
   f(run_seed, floor, room, enemy spawn `drop_slot`) — with the live RNG
   restored after. Re-fighting a room after any quit yields IDENTICAL rewards;
   kill order can't reshuffle them (slot-keyed, and DoT kills share the
   direct-kill stream). Floor-map treasure/event/shrine rolls don't need
   seeding: the state watcher checkpoints them the same frame they resolve.

## Write points (07-28 revision — supersedes the 07-18 "no per-room writes"
clause; ANR downgraded to unconfirmed 07-23, file is ~2-4 KB, atomic writes
built). All writes go through `save_write_atomic` (tmp → parse-verify → rename).
- Floor-map arrival — every `obj_floor_controller` Create (covers run start,
  floor advance, return from combat).
- Floor-map state watcher — `obj_floor_controller` Step top: rooms cleared in
  place (treasure/event/shrine), gold, boons/curses, XP… signal-hash + 1s throttle.
- Combat live-HP watcher — `obj_combat_controller` Step top, same throttle,
  suspended once `combat_over`. **PATCH-ONLY** (`run_checkpoint_update_hp`):
  it rewrites just the HP/resource fields of the on-disk floor-entry
  checkpoint. A full re-serialize here would checkpoint gold/XP/items earned
  mid-fight against a still-uncleared room, and the resume's re-fight would
  earn them all a second time (dupe).
- Boss victory (extract popup opening) — writes with `extract_pending: true` and
  ALSO calls `save_game()` so boss-granted persistents (pet egg, Petra floor
  credit, banshee flag) survive a crash. Resume re-offers EXTRACT/CONTINUE on
  the floor map (`obj_floor_controller` popup, arm-then-confirm like combat's).
- Quit to Title mid-run (= ironman save & quit on PC) + `os_is_paused()`
  backgrounding — both via `run_checkpoint_write_now()` (skips writes once
  `combat_over` so a settled defeat/victory screen can't be resurrected).

## Delete points
`end_run()` (any result), the defeat frame, apply-on-resume, New Game claiming
the slot, corrupt/stale detection at load.

## Payload (run-scoped state; persistent state stays in the main save)
Identity/guards: resume_version, save_version, player_name, run_count.
Route: run_seed, current_floor, floor_rooms_cleared, current_room_index,
selected_dungeon, selected_ascendance, descent_active/floor, extract_pending.
(Floor maps regenerate deterministically from run_seed — never serialized.)
Progress: gold (add_gold mutates it live mid-run), current_run_gold/kills,
run_xp/level, pending_stat_points, run_stat_bonuses, run_current_hp,
run_souls/blood/preparation, run_bonus_max_hp.
Collections: carried_items, secured_items, consumable_inventory,
run_items_found, run_found_pets, run_trinkets, run_boons, run_curses,
run_honing, events_seen_this_run, inventory + player_loadout + player_traits
(equip/borrow can change mid-run).
Flags: second_wind_used, fortune_favor_used, blood_carry, gravewalker_used,
oathbreaker_hp, last_stand_used, gift_given, pet_treats_run, banshee_carried,
run_borrowed_ability/class, pending_fire_stacks, pending_ap_penalty,
gold_potion_bosses, loot_potion_bosses.
Persistent-scope but mid-run-mutating (main save is hub-stale during a dive):
rune_inventory, rune_dust, quests, total_kills, items_discovered.

## Key functions (scr_save.gml)
`run_checkpoint_file/write/write_now/peek/apply/delete`, `save_write_atomic`
(shared with save_game), `run_floor_advance` (single source for the boss
CONTINUE floor-advance — combat popup + floor-map resume popup both call it).
Resume flow: `load_game()` tail peeks → `global.resume_pending/resume_data` →
hub Step top modal gate + Draw_64 popup → apply → `rm_dungeon_floor`.
