# DESIGN_QUESTS_0925 — CONTRACTS: the quest / board rework

Status: **LOCKED by M 2026-09-29 (decisions in §9).** Was DRAFT 2026-09-25. Pulls §5.1 Contracts forward from P4 and folds in
M's 09-25 asks. Builds as the batch right after Bairc's Ledger. Nothing here is built yet.

M (09-25): *"right now they're blind click and farm mindless turn in for supplemental
income/resources. i want the bulletin board to feel more like a bounty and true quest system.
the quests need more dynamics like 'find me a weapon with XYZ stats' etc that adds a bit more
flavor. also choose your rewards for some gold/bonus xp on next run/item with random affixes or
hand authored item rewards for some."*

---

## 0. What exists and what is wrong

Two layers share one plumbing (`quest_tick` → `{id,status,progress}` in `global.quests`):
- **Authored catalog** (`quest_catalog`): 3 starter hunts + 21 gate favours (Friend / Companion /
  Lover per NPC). The gate favours are the bond system's currency and stay as they are.
- **Tavern Board** (`board_*`): procedural requests, 9 templates (cull, depth, bounty, haul,
  craft, flawless, swift, clean), urgent / special postings, paid reroll, run-end aging.

What is wrong, in M's words: every posting is *count N, redeem*. The player never reads the
text, never makes a choice, never carries anything specific, and the reward is always the same
shape (gold + dust + maybe a random item). Nothing on the board is a *story*.

## 1. The three surfaces (the board gets tabs)

| Tab | What it holds | Cadence |
|---|---|---|
| **BOUNTIES** | 3 wanted posters: a NAMED foe (elite with a fixed affix set, or a species with your Mark shown), a danger tier, a deadline, a reward preview | refill at run end, as today |
| **REQUESTS** | 3 asks with a *specific object*: "find me a weapon with XYZ", "bring 6 Cinder Marrow", "a Valuable worth 300g+", "a creature of the Drowned raised to Young Adult" | refill at run end; reroll stays |
| **STORIES** | 1 active chain per NPC (7 chains, 3–4 steps each), gated by bond tier; the current step shows here and in the Journal | advances on turn-in; never rots |

The existing 9 templates survive as the *body* of bounties and requests (a cull is now a bounty
poster with a name; a craft ask is now a request from Maren). Urgent and Special keep their rules.

## 2. Dynamic asks — the "Want" generator

A request is a *predicate on an object you hand over*. Zero new mechanics: it reads the item /
pet / reagent structs that already exist.

**Item wants** (`want.kind = "item"`): slot ∈ {weapon, ranged_weapon, chest, ring, …},
`rarity_min` 1–3, and **one or two of**: `stat_name` + `stat_min` (the base stat, e.g. "DEX 4+"),
`affix_stat` (from `global.affix_pool`: STR/DEX/CON/INT/WIS/CHA, bonus_max_hp, crit_*, dodge_flat,
gold_find, school_*), `elem` (a Flaming/Frostbound… elemental affix), `sockets_min`. The asker's
voice explains why ("Dorn: a blade with Frost on it - my brother's grave needs cooling").
Turn-in = pick the item in the shared item picker (`project_item_picker`); the item is consumed.
Reward scales with what you gave: **rarity above the ask pays +1 reward tier** (the Sacrifice
idea from §5.1, folded in). Generator guarantees the ask is *possible at the poster's Awakening*
(never asks for epic at A0, never asks for a school affix on a non-caster slot).

**Reagent wants**: `id` from `reagent_catalog` (vault_ash, cinder_marrow, rime_salt, void_silt) ×
`n` (3–8). **Valuable wants**: `gold_value_min` (150/300/600). **Creature wants** (Bairc / Petra):
"a creature whose habitat is X, at stage ≥ Y" — *not* consumed; it is shown, bond +2, and the
creature earns a **keepsake tag** (name shown on its report card). Ties the Ledger's habitat
model to the board.

**Bounties**: `target` = enemy NAME (species) + optional `affix` (Warded / Hasted / Thorned /
Vampiric / Twinned — the poster says so, and the next elite fight of that species in that
dungeon ROLLS that affix, guaranteed) + `dungeon`. Kill it = done. The Hunter's Mark tier shows on
the poster ("Mark II on this one - +5%").

## 3. Choose your reward (the pick-of-three)

At turn-in of any bounty or request, three cards; pick one:

| Card | Pays | Notes |
|---|---|---|
| **COIN** | gold = today's amount ×1.5 (+ the dust / chit the template already pays) | the safe pick |
| **A BOON FOR THE NEXT RUN** | one of: **+25% XP** next run · **+20% gold find** next run · **start the run with a random Boon** (from `boon_catalog`) · **+1 loot tier** on the next boss | armed in `global.next_run_boons[]`, consumed at run start (dungeon confirm), shown on the run-start banner and the run summary |
| **AN ITEM** | a rolled item at the poster's rarity (+1 if you over-delivered), **slot chosen from two** (the two shown are rolled from the ask's context: a weapon request pays weapons) | `drop_equipment` + `roll_affixes`, no new roller |

**Story chains** pay fixed: each step pays a small COIN + a dialogue beat; the **finale pays a
hand-authored named item** (see §5) *and* the chain's epithet / keepsake. No pick at the finale.

Urgent postings pay ×2 on the COIN card only (so urgency reads as "take the money").

## 4. Event-based experiences (contracts that happen mid-run)

Taking a bounty / request / story step can attach a **contract event** to the next run. Events
already spawn from `event_catalog` by floor; add 5 entries tagged `contract` that only enter the
pool while a matching contract is active, and a **floor-map marker** (a small seal on the room
node) so the player can route to it (§4.3 route preview later).

| Kind | The event | Ending(s) |
|---|---|---|
| **Escort** | an NPC's hireling waits in the room; joins as a temporary 2nd companion for the rest of the run (reuses the Seahorse Knight ally path: `knight_joined`, `combat_knight_act`) | survives to the exit = pay ×2; dies = the base pay and a bond line ("she was my cousin") |
| **Timed** | "the tide turns in N rounds": the contract's clock starts here; finish the dungeon within N combat rounds total | in time = +1 reward tier; late = base |
| **Choice** | a two-ending room written for the story step (e.g. Sable's: burn the letters or read them) | each ending sets `quest.choice`; the NPC's next line and the finale item variant read it |
| **Cache** | a request's object is *here* (the wanted weapon in a chest, guarded) | take it = the request completes on return |
| **Ambush** | a bounty's named foe finds *you* (elite fight with the poster's affix, no flee) | kill = done; the room is a guaranteed elite |

Escort hirelings: 7 (one per NPC), text + reuse of NPC sprite silhouettes → **no art**. They
cannot die permanently; "dies" = leaves the run.

## 5. Story chains (7, one per NPC) and the named items

Each chain: 3–4 steps, unlocked at Friend (tier 1), advancing only by turn-in, each step a
bounty / request / choice event in the NPC's voice, ending in a named elite (Nemesis-flavoured,
§5.2 later) or a Cache. Written as data (`story_catalog`), ~40 lines of text per chain.

Finale items (**7 hand-authored, rarity 3 "Storied", existing icons by slot, zero art**):
fixed affixes chosen for the NPC's theme + a lore line + `unique_desc` that reuses an existing
hook (e.g. Dorn's: "+1 armor per Reforge ingot spent this run" reads `run_honing`; Petra's: the
Signet's price mult at 8%; Bairc's: pets take −10% damage). Two of the seven have a **choice
variant** (the Choice ending flips one affix).

## 6. Board presentation

- Wanted-poster rows (88px, mobile rule): asker portrait (existing `spr_icon_npc_*`), title,
  the object line ("WANTED: a Frostbound blade, DEX 4+"), danger pips, deadline, and the three
  reward-card icons greyed until turn-in.
- Bond effect on the board: at Companion the asker sometimes **doubles** a card (a hint line);
  Lover chains get the choice variant for free.
- Journal Quests tab: story steps show as a rail with the current step lit; requests show the
  predicate and a ✓ when something in stash / pack already satisfies it (cheap scan).

## 7. Data and save

```
quest state row: { id, status, progress, step:0, choice:"", reward_pick:"" }        // additive
board request def: + want:{kind, slot, rarity_min, stat_name, stat_min, affix_stat, elem,
                            sockets_min, reagent, n, gold_value_min, habitat, stage_min}
                   + bounty:{target, affix, dungeon}
                   + contract:{kind, event_id}
global.next_run_boons = [ {kind, value} ]              // consumed at dungeon confirm
global.story = { <npc>: { step, choice, done } }        // 7 entries
```
Save: the three `scr_save` sites, additive, no version bump. Older postings without `want`
render as today.

## 8. Files, size, order

| Step | Where | Size |
|---|---|---|
| Want generator + predicate check + item-picker turn-in | scr_stats (board_build_template, quest_turn_in, new `want_*`) | M |
| Pick-of-three modal + next_run_boons + run-start consume + summary line | scr_ui, gc Step, scr_stats, dungeon confirm | M |
| Board tabs + poster rows + Journal rail | scr_ui (ui_draw_tavern_board, journal tab 1), gc Step | M |
| Contract events ×5 + floor marker + Escort via knight path | scr_stats event_catalog, obj_floor_controller, obj_combat_controller | M |
| Story chains ×7 + 7 Storied items | scr_stats data, gc Create item authoring | M (text-heavy) |

Total ≈ **L** (about the size of the Ledger batch). Build order as listed; each step is F5-able
alone. Ships after Bairc's Ledger.

## 9. Decisions (LOCKED by M, 2026-09-29)

1. Chains in v1: **all 7** NPCs.
2. Pick-of-three on **every** bounty/request. Urgent pays x2 on the COIN card only.
3. BOON card keeps "start the run with a random Boon".
4. Storied items at **rarity 4 with a true unique effect each** (7 new combat hooks, one per NPC).
5. Escort hirelings reuse the Knight ally math (lance strike + 45-frame act) as v1.
6. Requests **consume** the handed item (Sacrifice). Creature wants are shown, not consumed.
7. Bounty affix guarantee **overrides** the elite affix roll for that species in that dungeon.
