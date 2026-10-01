# Tavern Board Requests — procedural, awakening-scaled, limited-time

**Parent:** PHASE4A_SPEC.md (quest layer), PHASE4C_SPEC.md (board UX).
**Design-locked 2026-07-05 via M's answers** (slots / expiry / templates / rewards / urgent model / chit redemption / challenge picks).
**Status:** BUILT 2026-07-05 (this doc is the as-built record).

---

## 1. Model

RNG-rolled request **definitions are generated and therefore persisted** — `global.board_requests`
(array of full def structs) + `global.board_seq` (id counter), unlike the code-authored
`quest_catalog()`. `quest_def()` consults the catalog first, then the board. State rows
(`{id,status,progress}`) share `global.quests`; a state row is pushed at generation and removed
when the request retires (turn-in or expiry), so saves stay lean. Board requests are **ephemeral**:
no Journal "Completed" history (the notice comes down off the board).

## 2. Board capacity & refresh

- Slots = `2 + (A>=1) + (A>=3) + (A>=5)` → 2/3/3/4/4/5 by highest unlocked Awakening.
- Refill runs at **every run end** (after expiry) and once on load/new-game (migration).
- **Urgent offers:** at A5 one urgent posting is always kept on the board (the 5th slot);
  from A2+ each normal refill has a **15%** chance to roll urgent instead.
- No-repeat guard: a refill rerolls (up to 8 tries) rather than posting a duplicate
  template+param already on the board.

## 3. Expiry (run-count clock)

- Normal requests post with **3 runs**; urgent with **1 run** ("THIS RUN ONLY").
- At `end_run` (any result): countdown ticks on every request **not yet fulfilled** —
  taken or not. Fulfilled-awaiting-turn-in never expires.
- Expired requests come off the board; if the player had taken it, a hub notice says so.

## 4. Templates (a = highest awakening 0–5, scale = 1 + 0.5a)

| key | objective | target | reward |
|---|---|---|---|
| `cull` (2x weight) | slay N of family F (wraith/construct/beast/fire/ice/undead; existing `kill_family` tick) | 6+2a | 60g×scale |
| `depth` | clear N floors at Awakening ≥ K (K=irandom(a); NEW tick `clear_floors_at`) | 2+min(a,2) | 80g×scale + (4+2a) dust |
| `bounty` | slay N bosses at Awakening ≥ K (NEW tick `boss_kill_at`) | 1–2 | 110g×scale + (6+2a) dust |
| `haul` | end a run (extract or clear) carrying ≥ 150×(1+a) gold (NEW run-end check `run_haul`) | 1 | 90g×scale |
| `craft` | socket N runes (existing `socket_rune` tick) | 2+min(a,2) | 70g×scale + (3+a) dust |
| `flawless` | win N fights taking 0 damage (NEW flag+tick `flawless_fight`) | 1+min(a,1) | 80g×scale + **1 Reforge Chit** |
| `swift` | slay a boss in ≤ T turns, T = max(4, 7−ceil(a/2)) (NEW tick `boss_swift`) | 1 | 90g×scale + **1 Reforge Chit** |
| `clean` | win N fights using no consumables (NEW flag+tick `clean_fight`) | 3 | 70g×scale + **1 Reforge Chit** |

- Item roll: **25%** of normal non-challenge requests additionally pay one
  `drop_equipment(drop_weights("vault", a))` item into the stash, disclosed on the note ("+ item").
- **Urgent:** 2× gold, **guaranteed** item roll (chit templates keep their chit too).
- Poster NPC is template-flavored (cull→Vex/Dorn/Sable, depth→Petra/Vael/Maren, bounty→Dorn/Petra,
  haul→Petra, craft→Maren, flawless/swift→Vex, clean→Sable) with an authored flavor line per template.
  No affinity payout (board pay is material; bonds go through the authored quests).

## 5. Threshold-tick trick (awakening/turn-count params)

`quest_tick` matches `obj_param` exactly, so "at Awakening ≥ K" defs store `obj_param=string(K)`
and the call site loops `k = 0..awk` ticking each `string(k)` (in `floor_clear_credit`, which
already receives the run's awakening). `boss_swift` inverts it: victory in n turns ticks
`k = n..12`, so a def with T ≥ n completes.

## 6. New combat-state flags

`player_took_damage` (any enemy-sourced HP loss: strike paths + DoT ticks) and
`used_consumable`, both reset at combat start, read at the victory block
(`flawless_fight` / `clean_fight`); `boss_swift` reads the intent turn counter at the
boss-victory site next to `floor_clear_credit`.

## 7. Reforge Chit (special reward)

`global.reforge_chits` (save-persisted counter). Redeemed at **Dorn** (new menu row):
opens the shared item picker (purpose `chit_reforge`, eligibility = affixed equipment),
confirm → the item's affixes are **rerolled at its same rarity/base** (drop-pipeline
`roll_affixes` + `apply_affixes_to_item` on a stripped copy). 1 chit per reroll.

## 8. UI

Board rows gain an expiry tag ("3 runs left" amber / "THIS RUN ONLY" red) and urgent
styling (red pin + URGENT name prefix). `journal_quest_reward_text` learns dust / "+ item" /
"+ Reforge Chit". Turn-in note lists everything granted.

## 9. Not built (deliberate)

- Paid board reroll; weekly/rotating specials; affinity drip on turn-in; board-request
  Completed history; per-family authored cull flavor variants (one line per template v1).
